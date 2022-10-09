-- Create tag table
CREATE TABLE tag
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tag text NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (tag)
);

SELECT manage_updated_at('tag'); -- Automatically manage updated_at

-- Create post_tag table
CREATE TABLE post_tag
(
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  post_id integer NOT NULL,
  tag_id integer NOT NULL,
  PRIMARY KEY (post_id, tag_id),
  FOREIGN KEY (post_id)
    REFERENCES post (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID,
  FOREIGN KEY (tag_id)
    REFERENCES tag (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

-- Update create_post function
DROP FUNCTION create_post;
CREATE OR REPLACE FUNCTION create_post(
  IN p_post new_post,
  IN p_tags text[]
)
RETURNS post
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_post post;
BEGIN
  -- Insert post
  INSERT INTO post (
    user_id,
    title,
    description,
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
    p_post.filename, -- filename
    p_post.size, -- size
    p_post.width, -- width
    p_post.height, -- height
    p_post.hash, -- hash
    p_post.ext, -- ext
    p_post.tn_ext -- tn_ext
  RETURNING * INTO v_post;

  -- Create non-existing tags
  INSERT INTO tag (tag)
    SELECT tag
    FROM unnest(p_tags) AS pt(tag)
    WHERE NOT EXISTS(SELECT * FROM tag AS t WHERE t.tag = pt.tag);

  -- Insert post tag links
  INSERT INTO post_tag (post_id, tag_id)
    SELECT v_post.id, id
    FROM tag WHERE tag = ANY(p_tags);

  RETURN v_post;
END;
$BODY$;

-- Update view_post view
CREATE OR REPLACE VIEW view_post
AS
SELECT
  p.id,
  p.created_at,
  u.name AS user_name,
  p.title,
  p.description,
  p.filename,
  p.size,
  p.width,
  p.height,
  p.hash,
  p.ext,
  p.tn_ext,
  (SELECT COALESCE(array_agg(t.tag), ARRAY[]::text[])
   FROM tag AS t
   JOIN post_tag AS pt ON pt.tag_id = t.id
   WHERE pt.post_id = p.id) AS tags
FROM post AS p
JOIN "user" AS u ON u.id = p.user_id;

-- Create search_view_posts function
CREATE OR REPLACE FUNCTION search_view_posts(
  IN p_include_tags text[],
  IN p_exclude_tags text[]
)
RETURNS SETOF view_post
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN QUERY
  SELECT p.*
  FROM view_post AS p
  WHERE
    -- Post must have all the included tags
    p.tags @> p_include_tags
    -- Post must not have any of the excluded tags
    AND NOT p.tags && p_exclude_tags;
END;
$BODY$;
