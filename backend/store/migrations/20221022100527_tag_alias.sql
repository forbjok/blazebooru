---- DROP OLD ----

DROP FUNCTION resolve_and_validate_tags;
DROP FUNCTION update_post_tags;
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION calculate_last_page;
DROP FUNCTION get_view_posts;

---- TYPES ----

CREATE TYPE update_tag AS (
  alias_of_tag text,
  add_implied_tags text[],
  remove_implied_tags text[]
);

---- TABLES ----

-- Add alias_of_tag_id column to tag
ALTER TABLE tag
  ADD COLUMN alias_of_tag_id integer REFERENCES tag(id);

-- Add implied_tag_ids column to tag
ALTER TABLE tag
  ADD COLUMN implied_tag_ids integer[] NOT NULL DEFAULT '{}';

---- VIEWS ----

-- Create view_tag view
CREATE VIEW view_tag
AS
SELECT
  t.id,
  t.tag,
  aot.tag AS alias_of_tag,
  array(SELECT tag FROM tag AS t1 JOIN unnest(t.implied_tag_ids) AS itid ON t1.id = itid) AS implied_tags
FROM tag AS t
LEFT JOIN tag AS aot ON aot.id = t.alias_of_tag_id;

---- FUNCTIONS ----

-- Create compute_post_tag_ids function
CREATE FUNCTION compute_post_tag_ids(
  IN p_tag_ids integer[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN (
    WITH RECURSIVE tags(id, alias_of_tag_id, implied_tag_ids) AS (
      SELECT id, alias_of_tag_id, implied_tag_ids
      FROM tag
      WHERE id = ANY(p_tag_ids)
      -- Resolve tag aliases and implied tags
      UNION ALL
      SELECT t.id, t.alias_of_tag_id, t.implied_tag_ids
      FROM tag AS t
      JOIN tags ON t.id = tags.alias_of_tag_id OR t.id = ANY(tags.implied_tag_ids)
    )
    CYCLE id
    SET is_cycle
    USING path

    SELECT array(
      SELECT DISTINCT id FROM tags
      WHERE NOT is_cycle AND alias_of_tag_id IS NULL
      ORDER BY id ASC
    )
  );
END;
$BODY$ STABLE;

-- Create compute_search_tag_ids function
CREATE FUNCTION compute_search_tag_ids(
  IN p_tag_ids integer[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN (
    WITH RECURSIVE tags(id, alias_of_tag_id) AS (
      SELECT id, alias_of_tag_id
      FROM tag
      WHERE id = ANY(p_tag_ids)
      -- Resolve tag aliases
      UNION ALL
      SELECT t.id, t.alias_of_tag_id
      FROM tag AS t
      JOIN tags ON t.id = tags.alias_of_tag_id
    )
    CYCLE id
    SET is_cycle
    USING path

    SELECT array(
      SELECT DISTINCT id FROM tags
      WHERE NOT is_cycle AND alias_of_tag_id IS NULL
      ORDER BY id ASC
    )
  );
END;
$BODY$ STABLE;

-- Create resolve_and_validate_tags function
CREATE FUNCTION resolve_search_tags(
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

  p_valid := NOT (icount(p_include_tag_ids) < cardinality(p_include_tags) OR p_include_tag_ids && p_exclude_tag_ids);

  p_include_tag_ids := compute_search_tag_ids(p_include_tag_ids);
  p_exclude_tag_ids := compute_search_tag_ids(p_exclude_tag_ids);
END;
$BODY$ STABLE;

-- Create update_post_tags function
CREATE FUNCTION update_post_tags(
  IN p_post_id integer,
  IN p_add_tags text[],
  IN p_remove_tags text[],
  IN p_user_id integer,
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
  v_old_tag_ids := array(SELECT tag_id FROM post_tag AS pt WHERE pt.post_id = p_post_id ORDER BY tag_id ASC);

  -- Compute new tags
  v_new_tag_ids := (v_old_tag_ids | v_add_tag_ids) - v_remove_tag_ids;

  -- Add links for added tags to post
  INSERT INTO post_tag (post_id, tag_id)
    SELECT p_post_id, tag_id
    FROM unnest(v_add_tag_ids) AS tag_id
    ON CONFLICT(post_id, tag_id)
    DO NOTHING;

  -- Remove removed tag links for post
  DELETE FROM post_tag AS pt
  USING unnest(v_remove_tag_ids) AS rtid
  WHERE pt.post_id = p_post_id AND pt.tag_id = rtid;

  -- Update post tags
  UPDATE post
  SET tags = array(SELECT tag
                   FROM tag
                   WHERE id = ANY(v_new_tag_ids)
                   ORDER BY tag ASC)
  WHERE id = p_post_id;

  v_old_tag_ids := compute_post_tag_ids(v_old_tag_ids);
  v_new_tag_ids := compute_post_tag_ids(v_new_tag_ids);

  -- Update post_tag_id_cache
  UPDATE post_tag_id_cache
  SET tag_ids = v_new_tag_ids
  WHERE post_id = p_post_id;

  -- Update search cache to reflect added post
  UPDATE search_cache
  SET post_count = post_count + 1,
      first_post_id = (CASE WHEN p_post_id > first_post_id THEN p_post_id ELSE first_post_id END),
      last_page_post_ids = (CASE WHEN p_post_id < (SELECT MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN last_page_post_ids | p_post_id
                            ELSE last_page_post_ids
                            END)
  WHERE v_new_tag_ids @> tag_ids
    AND NOT v_new_tag_ids && exclude_tag_ids
    AND (p_new_post OR (NOT v_old_tag_ids @> tag_ids) OR v_old_tag_ids && exclude_tag_ids);

  -- Update search cache to reflect removed post
  UPDATE search_cache AS sc
  SET post_count = post_count - 1,
      first_post_id = (CASE WHEN p_post_id = first_post_id
                       THEN (SELECT COALESCE(MAX(post_id), 0)
                             FROM post_tag_id_cache AS ptic
                             WHERE ptic.tag_ids @> sc.tag_ids
                               AND NOT ptic.tag_ids && sc.exclude_tag_ids)
                       ELSE first_post_id
                       END),
      last_page_post_ids = (CASE WHEN (SELECT p_post_id BETWEEN MIN(id) AND MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN last_page_post_ids - p_post_id
                            ELSE last_page_post_ids
                            END)
  WHERE NOT p_new_post
    AND ((NOT v_new_tag_ids @> tag_ids) OR v_new_tag_ids && exclude_tag_ids)
    AND v_old_tag_ids @> tag_ids
    AND NOT v_old_tag_ids && exclude_tag_ids;

  -- Track tag changes
  INSERT INTO post_tag_change (
    post_id,
    user_id,
    tag_ids_added,
    tag_ids_removed
  ) VALUES (
    p_post_id,
    p_user_id,
    v_add_tag_ids,
    v_remove_tag_ids
  );
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
  v_post_count integer;
  v_start_id integer;
  v_last_id integer;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_search_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids);

  SELECT post_count, first_post_id, last_page_post_ids[1]
  INTO v_post_count, v_start_id, v_last_id
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
          ptic.post_id AS id,
          ROW_NUMBER() OVER (ORDER BY ptic.post_id DESC) AS rn
        FROM post_tag_id_cache AS ptic
        WHERE
          -- Only scan forward from start ID
          ptic.post_id <= v_start_id
          -- Post must have all the included tags
          AND ptic.tag_ids @> v_tag_ids
          -- Post must not have any of the excluded tags
          AND NOT ptic.tag_ids && v_exclude_tag_ids
        ORDER BY ptic.post_id DESC
        LIMIT LEAST(p_page_count * p_posts_per_page, v_post_count) -- X pages at a time
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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_search_tags(p_include_tags, p_exclude_tags);
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
          ptic.post_id AS id,
          ROW_NUMBER() OVER (ORDER BY ptic.post_id ASC) AS rn
        FROM post_tag_id_cache AS ptic
        WHERE
          -- Only scan backwards from the origin
          ptic.post_id >= v_last_id
          -- Post must have all the included tags
          AND ptic.tag_ids @> v_tag_ids
          -- Post must not have any of the excluded tags
          AND NOT ptic.tag_ids && v_exclude_tag_ids
        ORDER BY ptic.post_id ASC
        LIMIT ((p_page_count + 1) * p_posts_per_page) -- X pages at a time
      ) AS x
      WHERE MOD(x.rn - 1, p_posts_per_page) = 0
    ) AS x
    WHERE x.no < p_origin_page.no
  );

  RETURN v_pages;
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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_search_tags(p_include_tags, p_exclude_tags);
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
  IF icount(v_last_page_post_ids) < v_post_count THEN
    v_last_page_post_ids := v_last_page_post_ids | array(
      SELECT ptic.post_id
      FROM post_tag_id_cache AS ptic
      WHERE
        ptic.post_id > (SELECT COALESCE(MAX(id), 0) FROM unnest(v_last_page_post_ids) AS id)
        -- Posts with fewer tags than the required tags cannot qualify
        AND icount(ptic.tag_ids) >= icount(v_tag_ids)
        -- Post must have all the included tags
        AND ptic.tag_ids @> v_tag_ids
        -- Post must not have any of the excluded tags
        AND NOT ptic.tag_ids && v_exclude_tag_ids
      ORDER BY ptic.post_id ASC
      LIMIT p_posts_per_page - icount(v_last_page_post_ids)
    );

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
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_search_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.*
  FROM post_tag_id_cache AS ptic
  JOIN view_post AS p ON p.id = ptic.post_id
  WHERE
    -- Only scan forward from the origin
    ptic.post_id <= p_start_id
    -- Posts with fewer tags than the required tags cannot qualify
    AND icount(ptic.tag_ids) >= icount(v_tag_ids)
    -- Post must have all the included tags
    AND ptic.tag_ids @> v_tag_ids
    -- Post must not have any of the excluded tags
    AND NOT ptic.tag_ids && v_exclude_tag_ids
  ORDER BY ptic.post_id DESC
  LIMIT p_limit;
END;
$BODY$ STABLE;

-- Create can_user_edit_tag function
CREATE FUNCTION can_user_edit_tag(
  IN p_tag_id integer,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
BEGIN
  -- If user is some sort of admin, allow edit
  IF (SELECT rank FROM "user" WHERE id = p_user_id) > 0 THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$BODY$;

-- Create update_tag function
CREATE FUNCTION update_tag(
  IN p_tag_id integer,
  IN p_update_tag update_tag,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_old_alias_of_tag_id integer;
  v_new_alias_of_tag_id integer;
  v_add_implied_tag_ids integer[];
  v_remove_implied_tag_ids integer[];
  v_old_implied_tag_ids integer[];
  v_new_implied_tag_ids integer[];
  v_affected_tag_ids integer[];
BEGIN
  IF NOT can_user_edit_tag(p_tag_id, p_user_id) THEN
    RETURN false;
  END IF;

  v_add_implied_tag_ids := get_tag_ids(p_update_tag.add_implied_tags);
  v_remove_implied_tag_ids := get_tag_ids(p_update_tag.remove_implied_tags);

  -- Retrieve old alias and implied tag ids
  SELECT alias_of_tag_id, implied_tag_ids
  INTO v_old_alias_of_tag_id, v_old_implied_tag_ids
  FROM tag
  WHERE id = p_tag_id;

  -- Get new alias of tag id
  v_new_alias_of_tag_id := (get_tag_ids(ARRAY[p_update_tag.alias_of_tag]))[1];

  -- Compute new implied tag ids
  v_new_implied_tag_ids := (v_old_implied_tag_ids | v_add_implied_tag_ids) - v_remove_implied_tag_ids;

  -- Update tag
  UPDATE tag
  SET alias_of_tag_id = v_new_alias_of_tag_id,
      implied_tag_ids = v_new_implied_tag_ids
  WHERE id = p_tag_id;

  v_affected_tag_ids := '{}';

  v_old_alias_of_tag_id := COALESCE(v_old_alias_of_tag_id, p_tag_id);
  v_new_alias_of_tag_id := COALESCE(v_new_alias_of_tag_id, p_tag_id);
  IF v_new_alias_of_tag_id <> v_old_alias_of_tag_id THEN
    v_affected_tag_ids := v_affected_tag_ids | v_old_alias_of_tag_id | v_new_alias_of_tag_id;
  END IF;

  IF v_new_implied_tag_ids <> v_old_implied_tag_ids THEN
    v_affected_tag_ids := v_affected_tag_ids + p_tag_id | v_old_implied_tag_ids | v_new_implied_tag_ids;
  END IF;

  IF icount(v_affected_tag_ids) > 0 THEN
    v_affected_tag_ids := v_affected_tag_ids | compute_post_tag_ids(v_affected_tag_ids);

    -- Update pre-calculated post tag ID cache
    UPDATE post_tag_id_cache AS ptic
    SET tag_ids = compute_post_tag_ids(array(SELECT tag_id FROM post_tag AS pt WHERE pt.post_id = ptic.post_id))
    WHERE tag_ids && v_affected_tag_ids;

    -- Delete cached searches affected by alias change
    DELETE FROM search_cache
    WHERE tag_ids && v_affected_tag_ids
       OR exclude_tag_ids && v_affected_tag_ids;
  END IF;

  RETURN true;
END;
$BODY$;
