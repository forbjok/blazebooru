CREATE FUNCTION can_user_edit_tag(
  IN p_tag_id integer,
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

  RETURN false;
END;
$BODY$;
