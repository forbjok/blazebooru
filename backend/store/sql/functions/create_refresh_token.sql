CREATE FUNCTION create_refresh_token(
  IN p_user_id integer,
  IN p_ip inet
)
RETURNS create_refresh_token_result
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_new_token uuid;
  v_session bigint;
BEGIN
  v_session := nextval('refresh_token_session_seq');

  -- Generate new refresh token with new session
  INSERT INTO refresh_token (session, user_id, created_ip)
  VALUES (v_session, p_user_id, p_ip)
  RETURNING token INTO v_new_token;

  -- Return new token
  RETURN (v_new_token, v_session);
END;
$BODY$;
