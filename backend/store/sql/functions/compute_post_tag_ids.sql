CREATE FUNCTION compute_post_tag_ids(
  IN p_tag_ids integer[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN (
    WITH RECURSIVE tags(id, alias_of_tag_id, implied_tag_ids) AS (
      SELECT id, alias_of_tag_id, implied_tag_ids
      FROM tag
      WHERE id = ANY(p_tag_ids)
      -- Resolve tag aliases and implied tags
      UNION ALL
      SELECT t.id, t.alias_of_tag_id, t.implied_tag_ids
      FROM tag AS t
      JOIN tags ON t.id = tags.alias_of_tag_id OR t.id = ANY(tags.implied_tag_ids)
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
