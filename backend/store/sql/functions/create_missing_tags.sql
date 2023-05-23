CREATE FUNCTION create_missing_tags(
  IN p_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  INSERT INTO tag (tag)
    SELECT tag
    FROM unnest(p_tags) AS pt(tag)
    WHERE NOT EXISTS(SELECT * FROM tag AS t WHERE t.tag = pt.tag);
END;
$BODY$;
