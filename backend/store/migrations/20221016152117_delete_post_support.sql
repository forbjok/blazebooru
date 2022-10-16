---- DROP OLD ----

DROP FUNCTION get_view_posts;
DROP VIEW view_post;

---- TABLES ----

-- Add is_deleted column to post
ALTER TABLE post
  ADD COLUMN is_deleted boolean NOT NULL DEFAULT false;

---- INDEXES ----

CREATE INDEX post_is_deleted_idx ON post
  USING btree
  (is_deleted ASC NULLS LAST);

---- VIEWS ----

-- Create view_post view
CREATE VIEW view_post
AS
SELECT
  p.id,
  p.created_at,
  p.user_id,
  u.name AS user_name,
  p.title,
  p.description,
  p.source,
  p.filename,
  p.size,
  p.width,
  p.height,
  p.hash,
  p.ext,
  p.tn_ext,
  p.tags
FROM post AS p
JOIN "user" AS u ON u.id = p.user_id
WHERE NOT is_deleted;

---- FUNCTIONS ----

-- Create get_view_posts function
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
  SELECT * INTO v_tag_ids, v_exclude_tag_ids, v_valid FROM resolve_and_validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM post_tag_id_cache LIMIT 0;
  END IF;

  -- Return different queries depending on whether
  -- there are tags specified or not.
  -- This should not be necessary, but IT IS,
  -- because for some reason it's slow as hell
  -- if you put an OR condition on the post ID
  -- filtering.
  IF icount(v_tag_ids) > 0 THEN
    RETURN QUERY
    SELECT p.*
    FROM post_tag_id_cache AS ptic
    JOIN view_post AS p ON p.id = ptic.post_id
    WHERE
      -- Only scan forward from the origin
      ptic.post_id <= p_start_id
      -- Reduce amount of posts to be scanned by filtering down
      -- to only post IDs that have at least one of the search tags.
      AND ptic.post_id IN (SELECT pt.post_id
                           FROM post_tag AS pt
                           WHERE pt.post_id <= p_start_id
                             AND pt.tag_id = ANY(v_tag_ids))
      -- Post must have all the included tags
      AND ptic.tag_ids @> v_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && v_exclude_tag_ids
    ORDER BY ptic.post_id DESC
    LIMIT p_limit;
  ELSE
    RETURN QUERY
    SELECT p.*
    FROM post_tag_id_cache AS ptic
    JOIN view_post AS p ON p.id = ptic.post_id
    WHERE
      -- Only scan forward from the origin
      ptic.post_id <= p_start_id
      -- Post must have all the included tags
      AND ptic.tag_ids @> v_tag_ids
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && v_exclude_tag_ids
    ORDER BY ptic.post_id DESC
    LIMIT p_limit;
  END IF;
END;
$BODY$ STABLE;

-- Create delete_post function
CREATE FUNCTION delete_post(
  IN p_post_id integer,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_success boolean;
  v_tag_ids integer[];
BEGIN
  -- Update post
  UPDATE post
  SET is_deleted = true
  WHERE id = p_post_id
    AND user_id = p_user_id
  RETURNING true INTO v_success;

  IF NOT v_success THEN
    RETURN v_success;
  END IF;

  -- Get post tag IDs for later use
  SELECT tag_ids INTO v_tag_ids FROM post_tag_id_cache WHERE post_id = p_post_id;

  -- Delete post_tag_id_cache so that the post
  -- will no longer be scanned for tag matches
  DELETE FROM post_tag_id_cache
  WHERE post_id = p_post_id;

  -- Update search cache to reflect deleted post
  UPDATE search_cache AS sc
  SET post_count = post_count - 1,
      first_post_id = (CASE WHEN p_post_id = first_post_id
                       THEN (SELECT COALESCE(MAX(post_id), 0)
                             FROM post_tag_id_cache AS ptic
                             WHERE ptic.tag_ids @> sc.tag_ids
                               AND NOT ptic.tag_ids && sc.exclude_tag_ids)
                       ELSE first_post_id
                       END),
      last_page_post_ids = (CASE WHEN (SELECT p_post_id BETWEEN MIN(id) AND MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN last_page_post_ids - p_post_id
                            ELSE last_page_post_ids
                            END)
  WHERE v_tag_ids @> tag_ids
    AND NOT v_tag_ids && exclude_tag_ids;

  RETURN v_success;
END;
$BODY$;
