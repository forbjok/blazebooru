CREATE FUNCTION create_user(
  IN p_user new_user
)
RETURNS "user"
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_user "user";
BEGIN
  -- Insert user
  INSERT INTO "user" (
    name,
    password_hash
  )
  SELECT
    p_user.name, -- name
    p_user.password_hash -- password_hash
  RETURNING * INTO v_user;

  RETURN v_user;
END;
$BODY$;
