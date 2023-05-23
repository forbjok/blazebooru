CREATE FUNCTION get_tag_ids(
  IN p_tags text[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN array(SELECT id FROM tag WHERE tag = ANY(p_tags) ORDER BY id ASC);
END;
$BODY$ STABLE;
