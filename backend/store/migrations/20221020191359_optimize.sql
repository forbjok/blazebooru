---- DROP OLD ----

DROP FUNCTION initialize_search_cache;
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION calculate_last_page;
DROP FUNCTION get_view_posts;

---- FUNCTIONS ----

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
    SELECT COALESCE(COUNT(*)::integer, 0), MAX(ptic.post_id), MIN(ptic.post_id)
    INTO v_post_count, v_first_post_id, v_last_post_id
    FROM post_tag_id_cache AS ptic
    WHERE
      -- Posts with fewer tags than the required tags cannot qualify
      icount(ptic.tag_ids) >= icount(p_tag_ids)
      -- Post must have all the included tags
      AND ptic.tag_ids @> p_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && p_exclude_tag_ids;

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
            ptic.post_id AS id,
            ROW_NUMBER() OVER (ORDER BY ptic.post_id DESC) AS rn
          FROM post_tag_id_cache AS ptic
          WHERE
            -- Only scan forward from start ID
            ptic.post_id <= v_start_id
            -- Reduce amount of posts to be scanned by filtering down
            -- to only post IDs that have at least one of the search tags.
            AND ptic.post_id IN (SELECT pt.post_id
                                 FROM post_tag AS pt
                                 WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                                   AND pt.tag_id = ANY(v_tag_ids))
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
  ELSE
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
            -- Posts with fewer tags than the required tags cannot qualify
            AND icount(ptic.tag_ids) >= icount(v_tag_ids)
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
            ptic.post_id AS id,
            ROW_NUMBER() OVER (ORDER BY ptic.post_id ASC) AS rn
          FROM post_tag_id_cache AS ptic
          WHERE
            -- Only scan backwards from the origin
            ptic.post_id >= v_last_id
            -- Reduce amount of posts to be scanned by filtering down
            -- to only post IDs that have at least one of the search tags.
            AND ptic.post_id IN (SELECT pt.post_id
                                 FROM post_tag AS pt
                                 WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                                   AND pt.tag_id = ANY(v_tag_ids))
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
  ELSE
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
            -- Posts with fewer tags than the required tags cannot qualify
            AND icount(ptic.tag_ids) >= icount(v_tag_ids)
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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN;
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
      -- Posts with fewer tags than the required tags cannot qualify
      AND icount(ptic.tag_ids) >= icount(v_tag_ids)
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
