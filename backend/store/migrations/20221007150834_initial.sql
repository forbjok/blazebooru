-- Create functions for automatically managing updated_at
CREATE OR REPLACE FUNCTION manage_updated_at(_tbl regclass)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION set_updated_at()', _tbl);
END;
$BODY$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql

AS $BODY$
BEGIN
  IF (NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at) THEN
    NEW.updated_at := CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$BODY$;

-- Create user table
CREATE TABLE "user"
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  name text NOT NULL,
  password_hash text NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (name)
);

SELECT manage_updated_at('user'); -- Automatically manage updated_at

-- Create post table
CREATE TABLE post
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id integer NOT NULL,
  title text,
  description text,
  filename text NOT NULL,
  size integer NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  hash text NOT NULL,
  ext text NOT NULL,
  tn_ext text NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (user_id)
    REFERENCES "user" (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

SELECT manage_updated_at('post'); -- Automatically manage updated_at

-- Create types
CREATE TYPE new_post AS (
  user_id integer,
  title text,
  description text,
  filename text,
  size integer,
  width integer,
  height integer,
  hash text,
  ext text,
  tn_ext text
);

CREATE TYPE new_user AS (
  name text,
  password_hash text
);

-- Create create_post function
CREATE OR REPLACE FUNCTION create_post(
  IN p_post new_post
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

  RETURN v_post;
END;
$BODY$;


-- Create create_user function
CREATE OR REPLACE FUNCTION create_user(
  IN p_user new_user
)
RETURNS "user"
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_user "user";
BEGIN
  -- Insert user
  INSERT INTO "user" (
    name,
    password_hash
  )
  SELECT
    p_user.name, -- name
    p_user.password_hash -- password_hash
  RETURNING * INTO v_user;

  RETURN v_user;
END;
$BODY$;

-- Create view_post view
CREATE VIEW view_post
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
  p.tn_ext
FROM post AS p
INNER JOIN "user" AS u ON u.id = p.user_id;

---- REFRESH TOKEN ----

-- Create refresh_token table
CREATE TABLE refresh_token
(
  id bigserial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  token uuid NOT NULL DEFAULT gen_random_uuid(),
  session bigint NOT NULL,
  used boolean NOT NULL DEFAULT false,
  expires_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP + '30 days'::interval),
  claims text NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (token)
);

SELECT manage_updated_at('refresh_token'); -- Automatically manage updated_at

-- Create indexes
CREATE INDEX refresh_token_token_idx ON refresh_token
  USING btree
  (token ASC NULLS LAST);

CREATE INDEX refresh_token_session_idx ON refresh_token
  USING btree
  (session ASC NULLS LAST);

-- Create refresh token session sequence
CREATE SEQUENCE refresh_token_session_seq AS bigint;

-- Create types
CREATE TYPE create_refresh_token_result AS (token uuid, session bigint);
CREATE TYPE refresh_refresh_token_result AS (token uuid, session bigint, claims text);

-- Create create_refresh_token function
CREATE OR REPLACE FUNCTION create_refresh_token(
  IN p_claims text
)
RETURNS create_refresh_token_result
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_new_token uuid;
  v_session bigint;
BEGIN
  v_session := nextval('refresh_token_session_seq');

  -- Generate new refresh token with new session
  INSERT INTO refresh_token (session, claims)
  VALUES (v_session, p_claims)
  RETURNING token INTO v_new_token;

  -- Return new token
  RETURN (v_new_token, v_session);
END;
$BODY$;

-- Create invalidate_session function
CREATE OR REPLACE FUNCTION invalidate_session(
  IN p_session bigint
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
    UPDATE refresh_token
    SET used = true
    WHERE session = p_session;
END;
$BODY$;

-- Create refresh_refresh_token function
CREATE OR REPLACE FUNCTION refresh_refresh_token(
  IN p_token uuid
)
RETURNS refresh_refresh_token_result
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_refresh_token refresh_token;
  v_result refresh_refresh_token_result;
BEGIN
  SELECT * INTO v_refresh_token
  FROM refresh_token
  WHERE token = p_token;

  -- Check if exists
  IF v_refresh_token IS NULL THEN
    RETURN NULL;
  END IF;

  -- Check if already used
  IF v_refresh_token.used THEN
    SELECT invalidate_session(v_refresh_token.session);
    RETURN NULL;
  END IF;

  -- Check if expired
  IF v_refresh_token.expires_at < CURRENT_TIMESTAMP THEN
    RETURN NULL;
  END IF;

  -- Mark token as used
  UPDATE refresh_token
  SET used = true
  WHERE id = v_refresh_token.id;

  -- Generate new refresh token
  INSERT INTO refresh_token (session, claims)
  VALUES (v_refresh_token.session, v_refresh_token.claims)
  RETURNING token, session, claims INTO v_result;

  -- Return result
  RETURN v_result;
END;
$BODY$;
