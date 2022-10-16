-- Drop old functions
DROP FUNCTION update_post_tags;
DROP FUNCTION resolve_and_validate_tags;
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION calculate_last_page;
DROP FUNCTION get_view_posts;

---- FUNCTIONS ----

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
  SELECT tag_ids INTO v_old_tag_ids
  FROM post_tag_id_cache
  WHERE post_id = p_post_id;

  -- Calculate new tags
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

  p_valid := NOT (icount(p_include_tag_ids) < cardinality(p_include_tags) OR p_include_tag_ids && p_exclude_tag_ids);
END;
$BODY$ STABLE;

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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
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

  -- Use different queries depending on whether
  -- there are tags specified or not.
  -- This should not be necessary, but IT IS,
  -- because for some reason it's slow as hell
  -- if you put an OR condition on the post ID
  -- filtering.
  IF icount(v_tag_ids) > 0 THEN
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
            -- Only scan forward from start ID
            post_id <= v_start_id
            -- Reduce amount of posts to be scanned by filtering down
            -- to only post IDs that have at least one of the search tags.
            AND post_id IN (SELECT pt.post_id
                            FROM post_tag AS pt
                            WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                              AND pt.tag_id = ANY(v_tag_ids))
            -- Post must have all the included tags
            AND tag_ids @> v_tag_ids
            -- Post must not have any of the excluded tags
            AND NOT tag_ids && v_exclude_tag_ids
          ORDER BY post_id DESC
          LIMIT LEAST(p_page_count * p_posts_per_page, v_post_count) -- X pages at a time
        ) AS x
        WHERE MOD(x.rn - 1, p_posts_per_page) = 0
      ) AS x
      WHERE x.no > COALESCE(p_origin_page.no, 0)
    );
  ELSE
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
            -- Only scan forward from start ID
            post_id <= v_start_id
            -- Post must have all the included tags
            AND tag_ids @> v_tag_ids
            -- Post must not have any of the excluded tags
            AND NOT tag_ids && v_exclude_tag_ids
          ORDER BY post_id DESC
          LIMIT LEAST(p_page_count * p_posts_per_page, v_post_count) -- X pages at a time
        ) AS x
        WHERE MOD(x.rn - 1, p_posts_per_page) = 0
      ) AS x
      WHERE x.no > COALESCE(p_origin_page.no, 0)
    );
  END IF;

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

  -- Use different queries depending on whether
  -- there are tags specified or not.
  -- This should not be necessary, but IT IS,
  -- because for some reason it's slow as hell
  -- if you put an OR condition on the post ID
  -- filtering.
  IF icount(v_tag_ids) > 0 THEN
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
            -- Only scan backwards from the origin
            post_id >= v_last_id
            -- Reduce amount of posts to be scanned by filtering down
            -- to only post IDs that have at least one of the search tags.
            AND post_id IN (SELECT pt.post_id
                            FROM post_tag AS pt
                            WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                              AND pt.tag_id = ANY(v_tag_ids))
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
  ELSE
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
            -- Only scan backwards from the origin
            post_id >= v_last_id
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
  END IF;

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
  IF icount(v_last_page_post_ids) < v_post_count THEN
    v_last_page_post_ids := v_last_page_post_ids | array(
      SELECT post_id
      FROM post_tag_id_cache
      WHERE
        post_id > (SELECT COALESCE(MAX(id), 0) FROM unnest(v_last_page_post_ids) AS id)
        -- Post must have all the included tags
        AND tag_ids @> v_tag_ids
        -- Post must not have any of the excluded tags
        AND NOT tag_ids && v_exclude_tag_ids
      ORDER BY post_id ASC
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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM post_tag_id_cache LIMIT 0;
  END IF;

  -- Return different queries depending on whether
  -- there are tags specified or not.
  -- This should not be necessary, but IT IS,
  -- because for some reason it's slow as hell
  -- if you put an OR condition on the post ID
  -- filtering.
  IF icount(v_tag_ids) > 0 THEN
    RETURN QUERY
    SELECT p.*
    FROM post_tag_id_cache AS ptic
    JOIN view_post AS p ON p.id = ptic.post_id
    WHERE
      -- Only scan forward from the origin
      ptic.post_id <= p_start_id
      -- Reduce amount of posts to be scanned by filtering down
      -- to only post IDs that have at least one of the search tags.
      AND ptic.post_id IN (SELECT pt.post_id
                           FROM post_tag AS pt
                           WHERE pt.post_id <= p_start_id
                             AND pt.tag_id = ANY(v_tag_ids))
      -- Post must have all the included tags
      AND ptic.tag_ids @> v_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && v_exclude_tag_ids
    ORDER BY ptic.post_id DESC
    LIMIT p_limit;
  ELSE
    RETURN QUERY
    SELECT p.*
    FROM post_tag_id_cache AS ptic
    JOIN view_post AS p ON p.id = ptic.post_id
    WHERE
      -- Only scan forward from the origin
      ptic.post_id <= p_start_id
      -- Post must have all the included tags
      AND ptic.tag_ids @> v_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && v_exclude_tag_ids
    ORDER BY ptic.post_id DESC
    LIMIT p_limit;
  END IF;
END;
$BODY$ STABLE;
