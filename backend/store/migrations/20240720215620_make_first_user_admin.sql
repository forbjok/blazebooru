DROP FUNCTION create_user;

CREATE FUNCTION create_user(
  IN p_user new_user
)
RETURNS "user"
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_user "user";
  v_rank smallint;
BEGIN
  -- If there are no existing users,
  -- make the new one a giga-admin.
  IF NOT EXISTS(SELECT * FROM "user") THEN
    v_rank := 9001;
  ELSE
    v_rank := 0;
  END IF;

  -- Insert user
  INSERT INTO "user" (
    name,
    password_hash,
    rank
  )
  SELECT
    p_user.name, -- name
    p_user.password_hash, -- password_hash
    v_rank
  RETURNING * INTO v_user;

  RETURN v_user;
END;
$BODY$;
