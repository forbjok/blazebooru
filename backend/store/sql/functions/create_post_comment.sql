CREATE FUNCTION create_post_comment(
  IN p_comment new_post_comment,
  IN p_user_id integer
)
RETURNS post_comment
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_comment post_comment;
BEGIN
  -- Insert post
  INSERT INTO post_comment (
    user_id,
    user_name,
    post_id,
    comment
  )
  SELECT
    p_user_id, -- user_id
    (SELECT name FROM "user" WHERE id = p_user_id), -- user_name
    p_comment.post_id, -- post_id
    p_comment.comment -- comment
  RETURNING * INTO v_comment;

  RETURN v_comment;
END;
$BODY$;
