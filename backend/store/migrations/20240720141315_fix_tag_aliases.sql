DROP FUNCTION update_tag;

CREATE FUNCTION update_tag(
  IN p_tag_id integer,
  IN p_update_tag update_tag,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_add_alias_ids integer[];
  v_remove_alias_ids integer[];
  v_old_alias_ids integer[];
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

  -- Retrieve implied tag ids
  SELECT implied_tag_ids
  INTO v_old_implied_tag_ids
  FROM tag
  WHERE id = p_tag_id;

  -- Compute new implied tag ids
  v_new_implied_tag_ids := (v_old_implied_tag_ids | v_add_implied_tag_ids) - v_remove_implied_tag_ids;

  -- Update tag
  UPDATE tag
  SET implied_tag_ids = v_new_implied_tag_ids
  WHERE id = p_tag_id;

  -- Get ids of removed aliases
  v_remove_alias_ids := get_tag_ids(p_update_tag.remove_aliases);

  IF cardinality(p_update_tag.add_aliases) > 0 THEN
    -- Create missing tags for added aliases
    PERFORM create_missing_tags(p_update_tag.add_aliases);

    -- Retrieve old alias ids
    SELECT COALESCE(array_agg(id), '{}')
    INTO v_old_alias_ids
    FROM tag
    WHERE alias_of_tag_id = p_tag_id;

    -- Get ids of added aliases
    v_add_alias_ids := get_tag_ids(p_update_tag.add_aliases) - v_old_alias_ids - v_remove_alias_ids;

    -- Set alias_of_tag_id for added aliases
    UPDATE tag
    SET alias_of_tag_id = p_tag_id
    WHERE id = ANY(v_add_alias_ids);

    -- Set any aliases of added aliases to be aliases of this tag
    UPDATE tag
    SET alias_of_tag_id = p_tag_id
    WHERE alias_of_tag_id = ANY(v_add_alias_ids);
  END IF;

  IF icount(v_remove_alias_ids) > 0 THEN
    -- Get actual alias ids that will be removed
    SELECT array_agg(id)
    INTO v_remove_alias_ids
    FROM tag
    WHERE alias_of_tag_id = p_tag_id AND id = ANY(v_remove_alias_ids);

    -- Clear alias_of_tag_id of removed aliases
    UPDATE tag
    SET alias_of_tag_id = NULL
    WHERE id = ANY(v_remove_alias_ids);
  END IF;

  v_affected_tag_ids := v_add_alias_ids || v_remove_alias_ids;

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
