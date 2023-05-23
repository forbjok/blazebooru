CREATE FUNCTION delete_post(
  IN p_post_id integer,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_success boolean;
  v_tag_ids integer[];
BEGIN
  -- Update post
  UPDATE post
  SET is_deleted = true
  WHERE id = p_post_id
    AND user_id = p_user_id
  RETURNING true INTO v_success;

  IF NOT v_success THEN
    RETURN v_success;
  END IF;

  -- Get post tag IDs for later use
  SELECT tag_ids INTO v_tag_ids FROM post_tag_id_cache WHERE post_id = p_post_id;

  -- Delete post_tag_id_cache so that the post
  -- will no longer be scanned for tag matches
  DELETE FROM post_tag_id_cache
  WHERE post_id = p_post_id;

  -- Update search cache to reflect deleted post
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
  WHERE v_tag_ids @> tag_ids
    AND NOT v_tag_ids && exclude_tag_ids;

  RETURN v_success;
END;
$BODY$;
