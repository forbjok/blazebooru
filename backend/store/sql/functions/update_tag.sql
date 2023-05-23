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
