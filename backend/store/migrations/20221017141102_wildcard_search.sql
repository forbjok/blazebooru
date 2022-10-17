-- Drop old functions
DROP FUNCTION get_tag_ids;
DROP FUNCTION resolve_and_validate_tags;

---- FUNCTIONS ----

-- Create get_tag_ids function
CREATE FUNCTION get_tag_ids(
  IN p_tags text[]
)
RETURNS integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  -- Exclude wildcard tags as those need to be handled differently
  p_tags := array(SELECT t FROM unnest(p_tags) AS t WHERE t NOT LIKE '%*%');

  RETURN array(SELECT id FROM tag WHERE tag = ANY(p_tags) ORDER BY id ASC);
END;
$BODY$ STABLE;

-- Create get_wi_ids function
DROP FUNCTION IF EXISTS get_wildcard_tag_ids;
CREATE FUNCTION get_wildcard_tag_ids(
  IN p_tags text[]
)
RETURNS SETOF integer[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  p_tags := array(SELECT REPLACE(t, '*', '%') FROM unnest(p_tags) AS t WHERE t LIKE '%*%');

  RETURN QUERY
  SELECT array_agg(t.id)
  FROM tag AS t
  JOIN unnest(p_tags) AS wt ON t.tag LIKE wt
  GROUP BY wt;
END;
$BODY$ STABLE;

-- Create resolve_and_validate_tags function
CREATE FUNCTION resolve_and_validate_tags(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  OUT p_include_tag_ids integer[],
  OUT p_exclude_tag_ids integer[],
  OUT p_valid boolean
)
LANGUAGE plpgsql

AS $BODY$
BEGIN
  p_include_tag_ids := get_tag_ids(p_include_tags);
  p_exclude_tag_ids := get_tag_ids(p_exclude_tags);

  p_valid := NOT (icount(p_include_tag_ids) < cardinality(p_include_tags) OR p_include_tag_ids && p_exclude_tag_ids);
END;
$BODY$ STABLE;
