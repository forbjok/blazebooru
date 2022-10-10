ALTER TABLE post
  ADD COLUMN tags text[] NOT NULL DEFAULT '{}'::text[];

-- Create generate_post_tags function
CREATE OR REPLACE FUNCTION generate_post_tags(
  IN p_post_id integer
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  UPDATE post AS p
  SET tags = (SELECT COALESCE(array_agg(t.tag), ARRAY[]::text[])
              FROM tag AS t
              JOIN post_tag AS pt ON pt.tag_id = t.id
              WHERE pt.post_id = p.id)
  WHERE p.id = p_post_id;
END;
$BODY$;

-- Create generate_post_tags function
CREATE OR REPLACE FUNCTION create_missing_tags(
  IN p_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  INSERT INTO tag (tag)
    SELECT tag
    FROM unnest(p_tags) AS pt(tag)
    WHERE NOT EXISTS(SELECT * FROM tag AS t WHERE t.tag = pt.tag);
END;
$BODY$;

-- Create update_post_tags function
CREATE OR REPLACE FUNCTION update_post_tags(
  IN p_post_id integer,
  IN p_add_tags text[],
  IN p_remove_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  -- Create missing tags
  PERFORM create_missing_tags(p_add_tags);

  -- Add links for added tags to post
  INSERT INTO post_tag (post_id, tag_id)
    SELECT p_post_id, id
    FROM tag WHERE tag = ANY(p_add_tags)
    ON CONFLICT(post_id, tag_id)
    DO NOTHING;

  -- Remove removed tag links for post
  DELETE FROM post_tag AS pt
  USING tag AS t
  WHERE t.id = pt.tag_id
    AND t.tag = ANY(p_remove_tags);

  -- Regenerate cached tags column on post
  -- (used for faster tag-based searches)
  PERFORM generate_post_tags(p_post_id);
END;
$BODY$;

-- Update create_post function
DROP FUNCTION create_post;
CREATE OR REPLACE FUNCTION create_post(
  IN p_post new_post,
  IN p_tags text[]
)
RETURNS integer
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_post_id integer;
BEGIN
  -- Insert post
  INSERT INTO post (
    user_id,
    title,
    description,
    filename,
    size,
    width,
    height,
    hash,
    ext,
    tn_ext
  )
  SELECT
    p_post.user_id, -- user_id
    p_post.title, -- title
    p_post.description, -- description
    p_post.filename, -- filename
    p_post.size, -- size
    p_post.width, -- width
    p_post.height, -- height
    p_post.hash, -- hash
    p_post.ext, -- ext
    p_post.tn_ext -- tn_ext
  RETURNING id INTO v_post_id;

  -- Add post tags
  PERFORM update_post_tags(v_post_id, p_tags, '{}');

  RETURN v_post_id;
END;
$BODY$;

-- Update view_post view
CREATE OR REPLACE VIEW view_post
AS
SELECT
  p.id,
  p.created_at,
  u.name AS user_name,
  p.title,
  p.description,
  p.filename,
  p.size,
  p.width,
  p.height,
  p.hash,
  p.ext,
  p.tn_ext,
  p.tags
FROM post AS p
JOIN "user" AS u ON u.id = p.user_id;

-- Create filter_tags function
CREATE OR REPLACE FUNCTION filter_tags(
  IN p_tags text[]
)
RETURNS text[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN (SELECT COALESCE(array_agg(tag), '{}') FROM tag WHERE tag = ANY(p_tags));
END;
$BODY$;

-- Create validate_tags function
CREATE OR REPLACE FUNCTION validate_tags(
  INOUT p_include_tags text[],
  INOUT p_exclude_tags text[],
  OUT p_valid boolean
)
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_include_tags text[];
BEGIN
  v_include_tags := filter_tags(p_include_tags);
  p_exclude_tags := filter_tags(p_exclude_tags);

  p_valid := NOT (cardinality(v_include_tags) < cardinality(p_include_tags) OR v_include_tags && p_exclude_tags);
  p_include_tags := v_include_tags;
END;
$BODY$;

-- Create page_info type
CREATE TYPE page_info AS (no integer, start_id integer);

-- Drop deprecated functions
DROP FUNCTION search_view_posts;

-- Create calculate_pages function
-- Calculate the starting IDs of a range of pages,
-- optionally starting from an already known page.
CREATE OR REPLACE FUNCTION calculate_pages(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer,
  IN p_page_count integer,
  IN p_origin_page page_info
)
RETURNS page_info[]
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_pages page_info[];
  v_valid boolean;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  SELECT
    array_agg((x.no, x.start_id)::page_info) INTO v_pages
  FROM (
    SELECT
      COALESCE(p_origin_page.no, 0) + ROW_NUMBER() OVER () AS no,
      x.id AS start_id
    FROM (
      SELECT
        id,
        ROW_NUMBER() OVER () AS rn
      FROM view_post
      WHERE
        -- Start from origin page
        (p_origin_page IS NULL OR id < p_origin_page.start_id)
        -- Post must have all the included tags
        AND tags @> p_include_tags
        -- Post must not have any of the excluded tags
        AND NOT tags && p_exclude_tags
      ORDER BY id DESC
      LIMIT (p_page_count * p_posts_per_page) -- X pages at a time
    ) AS x
    WHERE MOD(x.rn - 1, p_posts_per_page) = 0
  ) AS x;

  RETURN v_pages;
END;
$BODY$;

-- Update get_view_posts function
CREATE OR REPLACE FUNCTION get_view_posts(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_start_id integer,
  IN p_limit integer
)
RETURNS SETOF view_post
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_valid boolean;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM view_post LIMIT 0;
  END IF;

  RETURN QUERY
  SELECT *
  FROM view_post
  WHERE
    id <= p_start_id
    -- Post must have all the included tags
    AND tags @> p_include_tags
    -- Post must not have any of the excluded tags
    AND NOT tags && p_exclude_tags
  ORDER BY id DESC
  LIMIT p_limit;
END;
$BODY$;

-- Create search_view_posts_stats function
CREATE OR REPLACE FUNCTION calculate_last_page(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer
)
RETURNS page_info
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_valid boolean;
  v_post_count integer;
  v_page_count integer;
  v_last_page_start_id integer;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN (1, 0)::page_info;
  END IF;

  IF cardinality(p_include_tags) = 0 AND cardinality(p_exclude_tags) = 0 THEN
    v_post_count := (SELECT reltuples FROM pg_class where relname = 'post');
  ELSE
    -- Get total post count in search
    SELECT COALESCE(COUNT(*)::integer, 0) INTO v_post_count
    FROM view_post
    WHERE
      -- Post must have all the included tags
      tags @> p_include_tags
      -- Post must not have any of the excluded tags
      AND NOT tags && p_exclude_tags;
  END IF;

  v_page_count := CEIL(v_post_count / p_posts_per_page);
  v_last_page_start_id := v_post_count - (v_page_count * p_posts_per_page);

  RETURN (v_page_count, v_last_page_start_id)::page_info;
END;
$BODY$;
