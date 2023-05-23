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
