---- TABLES ----

-- Create comment table
CREATE TABLE comment
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  user_id integer,
  user_name text,
  comment text NOT NULL,

  PRIMARY KEY (id),

  FOREIGN KEY (user_id)
    REFERENCES "user" (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

-- Create post_comment table
CREATE TABLE post_comment (
  post_id integer NOT NULL,

  FOREIGN KEY (post_id)
    REFERENCES post (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
) INHERITS (comment);

---- TYPES ----

CREATE TYPE new_post_comment AS (
  post_id integer,
  comment text
);

---- FUNCTIONS ----

-- Create create_post_comment function
CREATE FUNCTION create_post_comment(
  IN p_comment new_post_comment,
  IN p_user_id integer
)
RETURNS post_comment
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_comment post_comment;
BEGIN
  -- Insert post
  INSERT INTO post_comment (
    user_id,
    user_name,
    post_id,
    comment
  )
  SELECT
    p_user_id, -- user_id
    (SELECT name FROM "user" WHERE id = p_user_id), -- user_name
    p_comment.post_id, -- post_id
    p_comment.comment -- comment
  RETURNING * INTO v_comment;

  RETURN v_comment;
END;
$BODY$;
