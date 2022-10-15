-- Drop old functions
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION get_view_posts;

---- INDEXES ----

CREATE INDEX post_tag_tag_id_idx ON post_tag
  USING btree
  (tag_id ASC NULLS LAST);

---- FUNCTIONS ----

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
  v_no_tags boolean;
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

  v_no_tags := cardinality(v_tag_ids) = 0;

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
          AND (v_no_tags OR post_id IN (SELECT pt.post_id
                                    FROM post_tag AS pt
                                    WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                                      AND pt.tag_id = ANY(v_tag_ids))
          )
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
  v_no_tags boolean;
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

  v_no_tags := cardinality(v_tag_ids) = 0;

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
          AND (v_no_tags OR post_id IN (SELECT pt.post_id
                                    FROM post_tag AS pt
                                    WHERE pt.post_id BETWEEN v_last_id AND v_start_id
                                      AND pt.tag_id = ANY(v_tag_ids))
          )
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
  v_no_tags boolean;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM post_tag_id_cache LIMIT 0;
  END IF;

  v_no_tags := cardinality(v_tag_ids) = 0;

  RETURN QUERY
  SELECT p.*
  FROM post_tag_id_cache AS ptic
  JOIN view_post AS p ON p.id = ptic.post_id
  WHERE
    -- Only scan forward from the origin
    ptic.post_id <= p_start_id
    -- Reduce amount of posts to be scanned by filtering down
    -- to only post IDs that have at least one of the search tags.
    AND (v_no_tags OR ptic.post_id IN (SELECT pt.post_id
                                   FROM post_tag AS pt
                                   WHERE pt.post_id <= p_start_id
                                     AND pt.tag_id = ANY(v_tag_ids))
    )
    -- Post must have all the included tags
    AND ptic.tag_ids @> v_tag_ids
    -- Post must not have any of the excluded tags
    AND NOT ptic.tag_ids && v_exclude_tag_ids
  ORDER BY ptic.post_id DESC
  LIMIT p_limit;
END;
$BODY$ STABLE;
