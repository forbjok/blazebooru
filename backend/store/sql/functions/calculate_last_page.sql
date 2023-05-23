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
