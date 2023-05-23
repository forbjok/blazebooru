CREATE FUNCTION refresh_refresh_token(
  IN p_token uuid,
  IN p_ip inet
)
RETURNS refresh_refresh_token_result
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_refresh_token refresh_token;
  v_result refresh_refresh_token_result;
BEGIN
  SELECT * INTO v_refresh_token
  FROM refresh_token
  WHERE token = p_token;

  -- Check if exists
  IF v_refresh_token IS NULL THEN
    RETURN NULL;
  END IF;

  -- Check if already used
  IF v_refresh_token.used THEN
    PERFORM invalidate_session(v_refresh_token.session);
    RETURN NULL;
  END IF;

  -- Check if expired
  IF v_refresh_token.expires_at < CURRENT_TIMESTAMP THEN
    RETURN NULL;
  END IF;

  -- Mark token as used
  UPDATE refresh_token
  SET used = true, used_ip = p_ip
  WHERE id = v_refresh_token.id;

  -- Generate new refresh token
  INSERT INTO refresh_token (session, user_id, created_ip)
  VALUES (v_refresh_token.session, v_refresh_token.user_id, p_ip)
  RETURNING token, session, user_id INTO v_result;

  -- Return result
  RETURN v_result;
END;
$BODY$;
