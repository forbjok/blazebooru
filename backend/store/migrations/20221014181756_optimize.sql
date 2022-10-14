-- Drop old functions
DROP FUNCTION update_post_tags;
DROP FUNCTION create_post;
DROP FUNCTION update_post;
DROP FUNCTION filter_tags;
DROP FUNCTION validate_tags;
DROP FUNCTION initialize_search_cache;
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION get_view_posts;
DROP FUNCTION calculate_last_page;

-- Drop old tables
DROP TABLE search_cache;

---- TABLES ----

-- Create post_tag_id_cache table
CREATE TABLE post_tag_id_cache
(
  post_id integer NOT NULL,
  tag_ids integer[] NOT NULL DEFAULT '{}',

  PRIMARY KEY (post_id),

  FOREIGN KEY (post_id)
    REFERENCES post (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

-- Create search_cache table
CREATE TABLE search_cache
(
  id serial NOT NULL,

  tag_ids integer[] NOT NULL,
  exclude_tag_ids integer[] NOT NULL,

  post_count integer NOT NULL,
  first_post_id integer NOT NULL,
  last_page_post_ids integer[] NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (tag_ids, exclude_tag_ids)
);

---- MIGRATE ----

-- Create post_tag_id_cache records for existing posts
INSERT INTO post_tag_id_cache (post_id, tag_ids)
SELECT
  id,
  array(SELECT pt.tag_id FROM post_tag AS pt WHERE pt.post_id = p.id ORDER BY pt.tag_id ASC)
FROM post AS p;

---- FUNCTIONS ----

-- Create update_post_tags function
CREATE FUNCTION update_post_tags(
  IN p_post_id integer,
  IN p_add_tags text[],
  IN p_remove_tags text[],
  IN p_new_post boolean
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_add_tag_ids integer[];
  v_remove_tag_ids integer[];
  v_old_tag_ids integer[];
  v_new_tag_ids integer[];
BEGIN
  -- Create missing tags
  PERFORM create_missing_tags(p_add_tags);

  v_add_tag_ids := get_tag_ids(p_add_tags);
  v_remove_tag_ids := get_tag_ids(p_remove_tags);

  -- Retrieve old tags
  SELECT tag_ids INTO v_old_tag_ids FROM post_tag_id_cache WHERE post_id = p_post_id;

  -- Calculate new tags
  v_new_tag_ids := uniq(sort_asc(array(SELECT unnest(v_old_tag_ids || v_add_tag_ids) EXCEPT SELECT unnest(v_remove_tag_ids))));

  -- Add links for added tags to post
  INSERT INTO post_tag (post_id, tag_id)
    SELECT p_post_id, tag_id
    FROM unnest(v_add_tag_ids) AS tag_id
    ON CONFLICT(post_id, tag_id)
    DO NOTHING;

  -- Remove removed tag links for post
  DELETE FROM post_tag AS pt
  USING unnest(v_remove_tag_ids) AS rtid
  WHERE pt.tag_id = rtid;

  -- Update post tags
  UPDATE post SET tags = array(SELECT tag FROM tag WHERE id = ANY(v_new_tag_ids) ORDER BY tag ASC) WHERE id = p_post_id;

  -- Update post_tag_id_cache
  UPDATE post_tag_id_cache
  SET tag_ids = v_new_tag_ids
  WHERE post_id = p_post_id;

  -- Update search cache to reflect added post
  UPDATE search_cache
  SET post_count = post_count + 1,
      first_post_id = (CASE WHEN p_post_id > first_post_id THEN p_post_id ELSE first_post_id END),
      last_page_post_ids = (CASE WHEN p_post_id < (SELECT MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN sort_asc(last_page_post_ids + p_post_id)
                            ELSE last_page_post_ids
                            END)
  WHERE v_new_tag_ids @> tag_ids
    AND NOT v_new_tag_ids && exclude_tag_ids
    AND (p_new_post OR (NOT v_old_tag_ids @> tag_ids) OR v_old_tag_ids && exclude_tag_ids);

  -- Update search cache to reflect removed post
  UPDATE search_cache
  SET post_count = post_count - 1,
      last_page_post_ids = (CASE WHEN (SELECT p_post_id BETWEEN MIN(id) AND MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN last_page_post_ids - p_post_id
                            ELSE last_page_post_ids
                            END)
  WHERE NOT p_new_post
    AND ((NOT v_new_tag_ids @> tag_ids) OR v_new_tag_ids && exclude_tag_ids)
    AND v_old_tag_ids @> tag_ids
    AND NOT v_old_tag_ids && exclude_tag_ids;
END;
$BODY$;

-- Create create_post function
CREATE FUNCTION create_post(
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
    source,
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
    p_post.source, -- source
    p_post.filename, -- filename
    p_post.size, -- size
    p_post.width, -- width
    p_post.height, -- height
    p_post.hash, -- hash
    p_post.ext, -- ext
    p_post.tn_ext -- tn_ext
  RETURNING id INTO v_post_id;

  -- Create post_tag_id_cache
  INSERT INTO post_tag_id_cache (post_id) VALUES (v_post_id);

  -- Add post tags
  PERFORM update_post_tags(v_post_id, p_tags, '{}', true);

  RETURN v_post_id;
END;
$BODY$;

-- Create update_post function
CREATE FUNCTION update_post(
  IN p_update_post update_post,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_success boolean;
BEGIN
  -- Update post
  UPDATE post
  SET
    title = p_update_post.title,
    description = p_update_post.description,
    source = p_update_post.source
  WHERE id = p_update_post.id
    AND user_id = p_user_id
  RETURNING true INTO v_success;

  IF v_success THEN
    -- Update post tags
    PERFORM update_post_tags(p_update_post.id, p_update_post.add_tags, p_update_post.remove_tags, false);
  END IF;

  RETURN COALESCE(v_success, false);
END;
$BODY$;

-- Create get_tag_ids function
CREATE FUNCTION get_tag_ids(
  IN p_tags text[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN array(SELECT id FROM tag WHERE tag = ANY(p_tags) ORDER BY id ASC);
END;
$BODY$ STABLE;

-- Create resolve_and_validate_tags function
CREATE FUNCTION resolve_and_validate_tags(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  OUT p_include_tag_ids integer[],
  OUT p_exclude_tag_ids integer[],
  OUT p_valid boolean
)
LANGUAGE plpgsql

AS $BODY$
BEGIN
  p_include_tag_ids := get_tag_ids(p_include_tags);
  p_exclude_tag_ids := get_tag_ids(p_exclude_tags);

  p_valid := NOT (cardinality(p_include_tag_ids) < cardinality(p_include_tags) OR p_include_tag_ids && p_exclude_tag_ids);
END;
$BODY$ STABLE;

-- Create initialize_search_cache function
CREATE FUNCTION initialize_search_cache(
  IN p_tag_ids integer[],
  IN p_exclude_tag_ids integer[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_post_count integer;
  v_first_post_id integer;
  v_last_post_id integer;
BEGIN
  -- Try to get cached search info
  SELECT post_count INTO v_post_count
  FROM search_cache
  WHERE tag_ids = p_tag_ids
    AND exclude_tag_ids = p_exclude_tag_ids;

  IF v_post_count IS NULL THEN
    -- Get total post count in search
    SELECT COALESCE(COUNT(*)::integer, 0), MAX(post_id), MIN(post_id)
    INTO v_post_count, v_first_post_id, v_last_post_id
    FROM post_tag_id_cache
    WHERE
      -- Post must have all the included tags
      tag_ids @> p_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT tag_ids && p_exclude_tag_ids;

    -- If there are 0 posts in the search, return immediately.
    IF v_post_count = 0 THEN
      RETURN;
    END IF;

    INSERT INTO search_cache (
      tag_ids,
      exclude_tag_ids,
      post_count,
      first_post_id,
      last_page_post_ids
    )
    VALUES (
      p_tag_ids, -- tags
      p_exclude_tag_ids, -- exclude_tags
      v_post_count, -- post_count
      v_first_post_id, -- first_post_id
      ARRAY[v_last_post_id] -- last_page_post_ids
    );
  END IF;
END;
$BODY$;

-- Create calculate_pages function
-- Calculate the starting IDs of a range of pages,
-- optionally starting from an already known page.
CREATE FUNCTION calculate_pages(
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
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_valid boolean;
  v_start_id integer;
  v_last_id integer;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids);

  SELECT first_post_id, last_page_post_ids[1]
  INTO v_start_id, v_last_id
  FROM search_cache
  WHERE tag_ids = v_tag_ids
    AND exclude_tag_ids = v_exclude_tag_ids;

  -- If no posts exist in the search, return.
  IF v_start_id IS NULL THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_start_id := p_origin_page.start_id;
  END IF;

  v_pages := array(
    SELECT (no, start_id)::page_info
    FROM (
      SELECT
        COALESCE(p_origin_page.no, 1) + ROW_NUMBER() OVER () - 1 AS no,
        x.id AS start_id
      FROM (
        SELECT
          post_id AS id,
          ROW_NUMBER() OVER (ORDER BY post_id DESC) AS rn
        FROM post_tag_id_cache
        WHERE
          -- Only search IDs between first first and last post ID for this search
          post_id BETWEEN v_last_id AND v_start_id
          -- Post must have all the included tags
          AND tag_ids @> v_tag_ids
          -- Post must not have any of the excluded tags
          AND NOT tag_ids && v_exclude_tag_ids
        ORDER BY post_id DESC
        LIMIT (p_page_count * p_posts_per_page) -- X pages at a time
      ) AS x
      WHERE MOD(x.rn - 1, p_posts_per_page) = 0
    ) AS x
    WHERE x.no > COALESCE(p_origin_page.no, 0)
  );

  RETURN v_pages;
END;
$BODY$;

-- Create calculate_pages_reverse function
-- Like calculate_pages, but in reverse.
-- (Calculates previous pages)
CREATE FUNCTION calculate_pages_reverse(
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
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_valid boolean;
  v_start_id integer;
  v_last_id integer;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids);

  SELECT first_post_id, last_page_post_ids[1]
  INTO v_start_id, v_last_id
  FROM search_cache
  WHERE tag_ids = v_tag_ids
    AND exclude_tag_ids = v_exclude_tag_ids;

  -- If no posts exist in the search, return.
  IF v_start_id IS NULL THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_last_id := p_origin_page.start_id;
  END IF;

  v_pages := array(
    SELECT (no, start_id)::page_info
    FROM (
      SELECT
        COALESCE(p_origin_page.no, 0) - ROW_NUMBER() OVER () + 1 AS no,
        x.id AS start_id
      FROM (
        SELECT
          post_id AS id,
          ROW_NUMBER() OVER (ORDER BY post_id ASC) AS rn
        FROM post_tag_id_cache
        WHERE
          -- Only search IDs between first first and last post ID for this search
          post_id BETWEEN v_last_id AND v_start_id
          -- Post must have all the included tags
          AND tag_ids @> v_tag_ids
          -- Post must not have any of the excluded tags
          AND NOT tag_ids && v_exclude_tag_ids
        ORDER BY post_id ASC
        LIMIT ((p_page_count + 1) * p_posts_per_page) -- X pages at a time
      ) AS x
      WHERE MOD(x.rn - 1, p_posts_per_page) = 0
    ) AS x
    WHERE x.no < p_origin_page.no
  );

  RETURN v_pages;
END;
$BODY$;

-- Create get_view_posts function
CREATE FUNCTION get_view_posts(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_start_id integer,
  IN p_limit integer
)
RETURNS SETOF view_post
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_valid boolean;
  v_last_id integer;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM post_tag_id_cache LIMIT 0;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids);

  SELECT last_page_post_ids[1] INTO v_last_id
  FROM search_cache
  WHERE tag_ids = v_tag_ids
    AND exclude_tag_ids = v_exclude_tag_ids;

  -- If no posts exist in the search, return.
  IF v_last_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.*
  FROM view_post AS p
  JOIN post_tag_id_cache AS ptic ON ptic.post_id = p.id
  WHERE
    p.id BETWEEN v_last_id AND p_start_id
    -- Post must have all the included tags
    AND ptic.tag_ids @> v_tag_ids
    -- Post must not have any of the excluded tags
    AND NOT ptic.tag_ids && v_exclude_tag_ids
  ORDER BY p.id DESC
  LIMIT p_limit;
END;
$BODY$;

-- Create calculate_last_page function
CREATE FUNCTION calculate_last_page(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer
)
RETURNS page_info
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_valid boolean;
  v_post_count integer;
  v_page_count integer;
  v_last_page_start_id integer;
  v_last_page_post_ids integer[];
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids);

  -- Try to get cached search info
  SELECT post_count, last_page_post_ids
  INTO v_post_count, v_last_page_post_ids
  FROM search_cache
  WHERE tag_ids = v_tag_ids
    AND exclude_tag_ids = v_exclude_tag_ids;

  -- If no posts exist in the search, return.
  IF v_post_count IS NULL THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Calculate page count
  v_page_count := CEIL(v_post_count::real / p_posts_per_page);

  -- Calculate number of posts currently on last page
  v_post_count := MOD(v_post_count, p_posts_per_page);

  -- If necessary, get additional last page posts
  IF cardinality(v_last_page_post_ids) < v_post_count THEN
    v_last_page_post_ids := uniq(sort_asc(v_last_page_post_ids + array(
      SELECT post_id
      FROM post_tag_id_cache
      WHERE
        post_id > (SELECT COALESCE(MAX(id), 0) FROM unnest(v_last_page_post_ids) AS id)
        -- Post must have all the included tags
        AND tag_ids @> v_tag_ids
        -- Post must not have any of the excluded tags
        AND NOT tag_ids && v_exclude_tag_ids
      ORDER BY post_id ASC
      LIMIT p_posts_per_page - cardinality(v_last_page_post_ids)
    )));

    -- Update search cache with posts
    UPDATE search_cache
    SET last_page_post_ids = v_last_page_post_ids
    WHERE tag_ids = v_tag_ids
      AND exclude_tag_ids = v_exclude_tag_ids;
  END IF;

  -- Get last page start ID
  v_last_page_start_id := v_last_page_post_ids[v_post_count];

  RETURN (v_page_count, v_last_page_start_id)::page_info;
END;
$BODY$;
