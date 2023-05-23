CREATE FUNCTION get_view_posts(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_start_id integer,
  IN p_limit integer
)
RETURNS SETOF view_post
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_valid boolean;
BEGIN
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_search_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.*
  FROM post_tag_id_cache AS ptic
  JOIN view_post AS p ON p.id = ptic.post_id
  WHERE
    -- Only scan forward from the origin
    ptic.post_id <= p_start_id
    -- Posts with fewer tags than the required tags cannot qualify
    AND icount(ptic.tag_ids) >= icount(v_tag_ids)
    -- Post must have all the included tags
    AND ptic.tag_ids @> v_tag_ids
    -- Post must not have any of the excluded tags
    AND NOT ptic.tag_ids && v_exclude_tag_ids
  ORDER BY ptic.post_id DESC
  LIMIT p_limit;
END;
$BODY$ STABLE;
