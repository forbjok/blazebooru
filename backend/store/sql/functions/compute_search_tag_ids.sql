CREATE FUNCTION compute_search_tag_ids(
  IN p_tag_ids integer[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN (
    WITH RECURSIVE tags(id, alias_of_tag_id) AS (
      SELECT id, alias_of_tag_id
      FROM tag
      WHERE id = ANY(p_tag_ids)
      -- Resolve tag aliases
      UNION ALL
      SELECT t.id, t.alias_of_tag_id
      FROM tag AS t
      JOIN tags ON t.id = tags.alias_of_tag_id
    )
    CYCLE id
    SET is_cycle
    USING path

    SELECT array(
      SELECT DISTINCT id FROM tags
      WHERE NOT is_cycle AND alias_of_tag_id IS NULL
      ORDER BY id ASC
    )
  );
END;
$BODY$ STABLE;
