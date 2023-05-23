CREATE FUNCTION manage_updated_at(_tbl regclass)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION set_updated_at()', _tbl);
END;
$BODY$;

CREATE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql

AS $BODY$
BEGIN
  IF (NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at) THEN
    NEW.updated_at := CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$BODY$;
