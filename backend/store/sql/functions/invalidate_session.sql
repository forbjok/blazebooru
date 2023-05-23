CREATE FUNCTION invalidate_session(
  IN p_session bigint
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
    UPDATE refresh_token
    SET used = true
    WHERE session = p_session;
END;
$BODY$;
