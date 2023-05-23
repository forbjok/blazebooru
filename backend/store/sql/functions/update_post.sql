CREATE FUNCTION update_post(
  IN p_update_post update_post,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_success boolean;
BEGIN
  -- Update post
  UPDATE post
  SET
    title = p_update_post.title,
    description = p_update_post.description,
    source = p_update_post.source
  WHERE id = p_update_post.id
    AND user_id = p_user_id
  RETURNING true INTO v_success;

  IF v_success THEN
    -- Update post tags
    PERFORM update_post_tags(p_update_post.id, p_update_post.add_tags, p_update_post.remove_tags, p_user_id, false);
  END IF;

  RETURN COALESCE(v_success, false);
END;
$BODY$;
