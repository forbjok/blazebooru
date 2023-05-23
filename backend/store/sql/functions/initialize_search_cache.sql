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
