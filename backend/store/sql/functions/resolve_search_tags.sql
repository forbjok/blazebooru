CREATE FUNCTION resolve_search_tags(
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

  p_include_tag_ids := compute_search_tag_ids(p_include_tag_ids);
  p_exclude_tag_ids := compute_search_tag_ids(p_exclude_tag_ids);
END;
$BODY$ STABLE;
