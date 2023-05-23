CREATE FUNCTION can_user_edit_post(
  IN p_post_id integer,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
BEGIN
  -- If user is some sort of admin, allow edit
  IF (SELECT rank FROM "user" WHERE id = p_user_id) > 0 THEN
    RETURN true;
  END IF;

  -- If user is the uploader of the post, allow edit
  IF p_user_id = (SELECT user_id FROM post WHERE id = p_post_id) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$BODY$;

-- Create update_post function
CREATE FUNCTION update_post(
  IN p_update_post update_post,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_can_edit boolean;
BEGIN
  -- Check if user is allowed to edit the post
  v_can_edit := can_user_edit_post(p_update_post.id, p_user_id);

  -- If user is allowed to edit, update post
  IF v_can_edit THEN
    UPDATE post
    SET
      title = p_update_post.title,
      description = p_update_post.description,
      source = p_update_post.source
    WHERE id = p_update_post.id;
  END IF;

  -- Update post tags
  PERFORM update_post_tags(p_update_post.id, p_update_post.add_tags, p_update_post.remove_tags, p_user_id, false);

  RETURN true;
END;
$BODY$;
