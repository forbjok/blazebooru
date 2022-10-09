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

-- Update search_view_posts function
DROP FUNCTION search_view_posts;
CREATE OR REPLACE FUNCTION search_view_posts(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_offset integer,
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
    -- Post must have all the included tags
    tags @> p_include_tags
    -- Post must not have any of the excluded tags
    AND NOT tags && p_exclude_tags
  ORDER BY id DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$BODY$;

-- Create search_view_posts_stats function
CREATE OR REPLACE FUNCTION search_view_posts_count(
  IN p_include_tags text[],
  IN p_exclude_tags text[]
)
RETURNS integer
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_valid boolean;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN 0;
  END IF;

  IF cardinality(p_include_tags) = 0 AND cardinality(p_exclude_tags) = 0 THEN
    RETURN (SELECT reltuples FROM pg_class where relname = 'post');
  END IF;

  RETURN (
    SELECT COALESCE(COUNT(*)::integer, 0)
    FROM view_post
    WHERE
      -- Post must have all the included tags
      tags @> p_include_tags
      -- Post must not have any of the excluded tags
      AND NOT tags && p_exclude_tags
  );
END;
$BODY$;
