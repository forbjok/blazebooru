-- Drop old functions
DROP FUNCTION update_post_tags;
DROP FUNCTION create_post;
DROP FUNCTION update_post;

---- TABLES ----

-- Create post_tag_change table
CREATE TABLE post_tag_change
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  post_id integer NOT NULL,
  user_id integer NOT NULL,
  tag_ids_added integer[],
  tag_ids_removed integer[],

  PRIMARY KEY (id)
);

---- FUNCTIONS ----

-- Create update_post_tags function
CREATE FUNCTION update_post_tags(
  IN p_post_id integer,
  IN p_add_tags text[],
  IN p_remove_tags text[],
  IN p_user_id integer,
  IN p_new_post boolean
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_add_tag_ids integer[];
  v_remove_tag_ids integer[];
  v_old_tag_ids integer[];
  v_new_tag_ids integer[];
BEGIN
  -- Create missing tags
  PERFORM create_missing_tags(p_add_tags);

  v_add_tag_ids := get_tag_ids(p_add_tags);
  v_remove_tag_ids := get_tag_ids(p_remove_tags);

  -- Retrieve old tags
  SELECT tag_ids INTO v_old_tag_ids
  FROM post_tag_id_cache
  WHERE post_id = p_post_id;

  -- Calculate new tags
  v_new_tag_ids := uniq(sort_asc(array(SELECT unnest(v_old_tag_ids || v_add_tag_ids)
                                       EXCEPT SELECT unnest(v_remove_tag_ids))));

  -- Add links for added tags to post
  INSERT INTO post_tag (post_id, tag_id)
    SELECT p_post_id, tag_id
    FROM unnest(v_add_tag_ids) AS tag_id
    ON CONFLICT(post_id, tag_id)
    DO NOTHING;

  -- Remove removed tag links for post
  DELETE FROM post_tag AS pt
  USING unnest(v_remove_tag_ids) AS rtid
  WHERE pt.post_id = p_post_id AND pt.tag_id = rtid;

  -- Update post tags
  UPDATE post
  SET tags = array(SELECT tag
                   FROM tag
                   WHERE id = ANY(v_new_tag_ids)
                   ORDER BY tag ASC)
  WHERE id = p_post_id;

  -- Update post_tag_id_cache
  UPDATE post_tag_id_cache
  SET tag_ids = v_new_tag_ids
  WHERE post_id = p_post_id;

  -- Update search cache to reflect added post
  UPDATE search_cache
  SET post_count = post_count + 1,
      first_post_id = (CASE WHEN p_post_id > first_post_id THEN p_post_id ELSE first_post_id END),
      last_page_post_ids = (CASE WHEN p_post_id < (SELECT MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN sort_asc(last_page_post_ids + p_post_id)
                            ELSE last_page_post_ids
                            END)
  WHERE v_new_tag_ids @> tag_ids
    AND NOT v_new_tag_ids && exclude_tag_ids
    AND (p_new_post OR (NOT v_old_tag_ids @> tag_ids) OR v_old_tag_ids && exclude_tag_ids);

  -- Update search cache to reflect removed post
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
  WHERE NOT p_new_post
    AND ((NOT v_new_tag_ids @> tag_ids) OR v_new_tag_ids && exclude_tag_ids)
    AND v_old_tag_ids @> tag_ids
    AND NOT v_old_tag_ids && exclude_tag_ids;

  -- Track tag changes
  INSERT INTO post_tag_change (
    post_id,
    user_id,
    tag_ids_added,
    tag_ids_removed
  ) VALUES (
    p_post_id,
    p_user_id,
    v_add_tag_ids,
    v_remove_tag_ids
  );
END;
$BODY$;

-- Create create_post function
CREATE FUNCTION create_post(
  IN p_post new_post,
  IN p_tags text[]
)
RETURNS integer
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_post_id integer;
BEGIN
  -- Insert post
  INSERT INTO post (
    user_id,
    title,
    description,
    source,
    filename,
    size,
    width,
    height,
    hash,
    ext,
    tn_ext
  )
  SELECT
    p_post.user_id, -- user_id
    p_post.title, -- title
    p_post.description, -- description
    p_post.source, -- source
    p_post.filename, -- filename
    p_post.size, -- size
    p_post.width, -- width
    p_post.height, -- height
    p_post.hash, -- hash
    p_post.ext, -- ext
    p_post.tn_ext -- tn_ext
  RETURNING id INTO v_post_id;

  -- Create post_tag_id_cache
  INSERT INTO post_tag_id_cache (post_id) VALUES (v_post_id);

  -- Add post tags
  PERFORM update_post_tags(v_post_id, p_tags, '{}', p_post.user_id, true);

  RETURN v_post_id;
END;
$BODY$;

-- Create update_post function
CREATE FUNCTION update_post(
  IN p_update_post update_post,
  IN p_user_id integer
)
RETURNS boolean
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_success boolean;
BEGIN
  -- Update post
  UPDATE post
  SET
    title = p_update_post.title,
    description = p_update_post.description,
    source = p_update_post.source
  WHERE id = p_update_post.id
    AND user_id = p_user_id
  RETURNING true INTO v_success;

  IF v_success THEN
    -- Update post tags
    PERFORM update_post_tags(p_update_post.id, p_update_post.add_tags, p_update_post.remove_tags, p_user_id, false);
  END IF;

  RETURN COALESCE(v_success, false);
END;
$BODY$;
