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
