-- Enable intarray extension
CREATE EXTENSION intarray;

-- Create functions for automatically managing updated_at
CREATE FUNCTION manage_updated_at(_tbl regclass)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION set_updated_at()', _tbl);
END;
$BODY$;

CREATE FUNCTION set_updated_at()
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

---- TABLES ----

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
  source text,
  filename text NOT NULL,
  size integer NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  hash text NOT NULL,
  ext text NOT NULL,
  tn_ext text NOT NULL,
  tags text[] NOT NULL DEFAULT '{}',

  PRIMARY KEY (id),

  FOREIGN KEY (user_id)
    REFERENCES "user" (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

SELECT manage_updated_at('post'); -- Automatically manage updated_at

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

-- Create refresh_token table
CREATE TABLE refresh_token
(
  id bigserial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  token uuid NOT NULL DEFAULT gen_random_uuid(),
  session bigint NOT NULL,
  user_id integer NOT NULL,
  created_ip inet NOT NULL,
  expires_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP + '30 days'::interval),

  used boolean NOT NULL DEFAULT false,
  used_ip inet,

  PRIMARY KEY (id),
  UNIQUE (token)
);

SELECT manage_updated_at('refresh_token'); -- Automatically manage updated_at

-- Create search_cache table
CREATE TABLE search_cache
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  tags text[] NOT NULL,
  exclude_tags text[] NOT NULL,

  post_count integer NOT NULL,
  first_post_id integer NOT NULL,
  last_page_post_ids integer[] NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (tags, exclude_tags)
);

SELECT manage_updated_at('search_cache'); -- Automatically manage updated_at

---- INDEXES ----

-- Create indexes
CREATE INDEX refresh_token_token_idx ON refresh_token
  USING btree
  (token ASC NULLS LAST);

CREATE INDEX refresh_token_session_idx ON refresh_token
  USING btree
  (session ASC NULLS LAST);

---- SEQUENCES ----

-- Create refresh token session sequence
CREATE SEQUENCE refresh_token_session_seq AS bigint;

---- TYPES ----

CREATE TYPE new_post AS (
  user_id integer,
  title text,
  description text,
  source text,
  filename text,
  size integer,
  width integer,
  height integer,
  hash text,
  ext text,
  tn_ext text
);

CREATE TYPE update_post AS (
  id integer,

  title text,
  description text,
  source text,
  add_tags text[],
  remove_tags text[]
);

CREATE TYPE new_user AS (
  name text,
  password_hash text
);

CREATE TYPE create_refresh_token_result AS (token uuid, session bigint);

CREATE TYPE refresh_refresh_token_result AS (token uuid, session bigint, user_id integer);

CREATE TYPE page_info AS (no integer, start_id integer);

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
JOIN "user" AS u ON u.id = p.user_id;

---- FUNCTIONS ----

-- Create create_user function
CREATE FUNCTION create_user(
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

-- Create create_missing_tags function
CREATE FUNCTION create_missing_tags(
  IN p_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
BEGIN
  INSERT INTO tag (tag)
    SELECT tag
    FROM unnest(p_tags) AS pt(tag)
    WHERE NOT EXISTS(SELECT * FROM tag AS t WHERE t.tag = pt.tag);
END;
$BODY$;

-- Create update_post_tags function
CREATE FUNCTION update_post_tags(
  IN p_post_id integer,
  IN p_add_tags text[],
  IN p_remove_tags text[],
  IN p_new_post boolean
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_old_tags text[];
  v_new_tags text[];
BEGIN
  -- Create missing tags
  PERFORM create_missing_tags(p_add_tags);

  -- Retrieve old tags
  SELECT tags INTO v_old_tags FROM post WHERE id = p_post_id;

  -- Calculate new tags
  v_new_tags := array(SELECT unnest(v_old_tags || p_add_tags) EXCEPT SELECT unnest(p_remove_tags));

  -- Update post tags
  UPDATE post SET tags = v_new_tags WHERE id = p_post_id;

  -- Add links for added tags to post
  INSERT INTO post_tag (post_id, tag_id)
    SELECT p_post_id, id
    FROM tag WHERE tag = ANY(p_add_tags)
    ON CONFLICT(post_id, tag_id)
    DO NOTHING;

  -- Remove removed tag links for post
  DELETE FROM post_tag AS pt
  USING tag AS t
  WHERE t.id = pt.tag_id
    AND t.tag = ANY(p_remove_tags);

  -- Update search cache to reflect added post
  UPDATE search_cache
  SET post_count = post_count + 1,
      first_post_id = (CASE WHEN p_post_id > first_post_id THEN p_post_id ELSE first_post_id END),
      last_page_post_ids = (CASE WHEN p_post_id < (SELECT MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN sort_asc(last_page_post_ids + p_post_id)
                            ELSE last_page_post_ids
                            END)
  WHERE v_new_tags @> tags
    AND NOT v_new_tags && exclude_tags
    AND (p_new_post OR (NOT v_old_tags @> tags) OR v_old_tags && exclude_tags);

  -- Update search cache to reflect removed post
  UPDATE search_cache
  SET post_count = post_count - 1,
      last_page_post_ids = (CASE WHEN (SELECT p_post_id BETWEEN MIN(id) AND MAX(id) FROM unnest(last_page_post_ids) AS id)
                            THEN last_page_post_ids - p_post_id
                            ELSE last_page_post_ids
                            END)
  WHERE NOT p_new_post
    AND ((NOT v_new_tags @> tags) OR v_new_tags && exclude_tags)
    AND v_old_tags @> tags
    AND NOT v_old_tags && exclude_tags;
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

  -- Add post tags
  PERFORM update_post_tags(v_post_id, p_tags, '{}', true);

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
    PERFORM update_post_tags(p_update_post.id, p_update_post.add_tags, p_update_post.remove_tags, false);
  END IF;

  RETURN COALESCE(v_success, false);
END;
$BODY$;

-- Create filter_tags function
CREATE FUNCTION filter_tags(
  IN p_tags text[]
)
RETURNS text[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN array(SELECT tag FROM tag WHERE tag = ANY(p_tags));
END;
$BODY$;

-- Create validate_tags function
CREATE FUNCTION validate_tags(
  INOUT p_include_tags text[],
  INOUT p_exclude_tags text[],
  OUT p_valid boolean
)
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_include_tags text[];
BEGIN
  v_include_tags := filter_tags(p_include_tags);
  p_exclude_tags := filter_tags(p_exclude_tags);

  p_valid := NOT (cardinality(v_include_tags) < cardinality(p_include_tags) OR v_include_tags && p_exclude_tags);
  p_include_tags := v_include_tags;
END;
$BODY$;

-- Create initialize_search_cache function
CREATE FUNCTION initialize_search_cache(
  IN p_include_tags text[],
  IN p_exclude_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_post_count integer;
  v_first_post_id integer;
  v_last_post_id integer;
BEGIN
  -- Try to get cached search info
  SELECT post_count INTO v_post_count
  FROM search_cache
  WHERE tags = p_include_tags
    AND exclude_tags = p_exclude_tags;

  IF NOT EXISTS(SELECT * FROM search_cache
                WHERE tags = p_include_tags
                  AND exclude_tags = p_exclude_tags)
  THEN
    -- Get total post count in search
    SELECT COALESCE(COUNT(*)::integer, 0), MAX(id), MIN(id)
    INTO v_post_count, v_first_post_id, v_last_post_id
    FROM view_post
    WHERE
      -- Post must have all the included tags
      tags @> p_include_tags
      -- Post must not have any of the excluded tags
      AND NOT tags && p_exclude_tags;

    -- If there are 0 posts in the search, return immediately.
    IF v_post_count = 0 THEN
      RETURN;
    END IF;

    INSERT INTO search_cache (
      tags,
      exclude_tags,
      post_count,
      first_post_id,
      last_page_post_ids
    )
    VALUES (
      p_include_tags, -- tags
      p_exclude_tags, -- exclude_tags
      v_post_count, -- post_count
      v_first_post_id, -- first_post_id
      ARRAY[v_last_post_id] -- last_page_post_ids
    );
  END IF;
END;
$BODY$;

-- Create calculate_pages function
-- Calculate the starting IDs of a range of pages,
-- optionally starting from an already known page.
CREATE FUNCTION calculate_pages(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer,
  IN p_page_count integer,
  IN p_origin_page page_info
)
RETURNS page_info[]
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_pages page_info[];
  v_valid boolean;
  v_start_id integer;
  v_last_id integer;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(p_include_tags, p_exclude_tags);

  SELECT first_post_id, last_page_post_ids[1]
  INTO v_start_id, v_last_id
  FROM search_cache
  WHERE tags = p_include_tags
    AND exclude_tags = p_exclude_tags;

  -- If no posts exist in the search, return.
  IF v_start_id IS NULL THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_start_id := p_origin_page.start_id;
  END IF;

  v_pages := array(
    SELECT (no, start_id)::page_info
    FROM (
      SELECT
        COALESCE(p_origin_page.no, 1) + ROW_NUMBER() OVER () - 1 AS no,
        x.id AS start_id
      FROM (
        SELECT
          id,
          ROW_NUMBER() OVER (ORDER BY id DESC) AS rn
        FROM view_post
        WHERE
          -- Only search IDs between first first and last post ID for this search
          id BETWEEN v_last_id AND v_start_id
          -- Post must have all the included tags
          AND tags @> p_include_tags
          -- Post must not have any of the excluded tags
          AND NOT tags && p_exclude_tags
        ORDER BY id DESC
        LIMIT (p_page_count * p_posts_per_page) -- X pages at a time
      ) AS x
      WHERE MOD(x.rn - 1, p_posts_per_page) = 0
    ) AS x
    WHERE x.no > COALESCE(p_origin_page.no, 0)
  );

  RETURN v_pages;
END;
$BODY$;

-- Create calculate_pages_reverse function
-- Like calculate_pages, but in reverse.
-- (Calculates previous pages)
CREATE FUNCTION calculate_pages_reverse(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer,
  IN p_page_count integer,
  IN p_origin_page page_info
)
RETURNS page_info[]
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_pages page_info[];
  v_valid boolean;
  v_start_id integer;
  v_last_id integer;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(p_include_tags, p_exclude_tags);

  SELECT first_post_id, last_page_post_ids[1]
  INTO v_start_id, v_last_id
  FROM search_cache
  WHERE tags = p_include_tags
    AND exclude_tags = p_exclude_tags;

  -- If no posts exist in the search, return.
  IF v_start_id IS NULL THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_last_id := p_origin_page.start_id;
  END IF;

  v_pages := array(
    SELECT (no, start_id)::page_info
    FROM (
      SELECT
        COALESCE(p_origin_page.no, 0) - ROW_NUMBER() OVER () + 1 AS no,
        x.id AS start_id
      FROM (
        SELECT
          id,
          ROW_NUMBER() OVER (ORDER BY id ASC) AS rn
        FROM view_post
        WHERE
          -- Only search IDs between first first and last post ID for this search
          id BETWEEN v_last_id AND v_start_id
          -- Post must have all the included tags
          AND tags @> p_include_tags
          -- Post must not have any of the excluded tags
          AND NOT tags && p_exclude_tags
        ORDER BY id ASC
        LIMIT ((p_page_count + 1) * p_posts_per_page) -- X pages at a time
      ) AS x
      WHERE MOD(x.rn - 1, p_posts_per_page) = 0
    ) AS x
    WHERE x.no < p_origin_page.no
  );

  RETURN v_pages;
END;
$BODY$;

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
  v_valid boolean;
  v_last_id integer;
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN QUERY SELECT * FROM view_post LIMIT 0;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(p_include_tags, p_exclude_tags);

  SELECT last_page_post_ids[1] INTO v_last_id
  FROM search_cache
  WHERE tags = p_include_tags
    AND exclude_tags = p_exclude_tags;

  -- If no posts exist in the search, return.
  IF v_last_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT *
  FROM view_post
  WHERE
    id BETWEEN v_last_id AND p_start_id
    -- Post must have all the included tags
    AND tags @> p_include_tags
    -- Post must not have any of the excluded tags
    AND NOT tags && p_exclude_tags
  ORDER BY id DESC
  LIMIT p_limit;
END;
$BODY$;

-- Create calculate_last_page function
CREATE FUNCTION calculate_last_page(
  IN p_include_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer
)
RETURNS page_info
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_valid boolean;
  v_post_count integer;
  v_page_count integer;
  v_last_page_start_id integer;
  v_last_page_post_ids integer[];
BEGIN
  SELECT * INTO p_include_tags, p_exclude_tags, v_valid FROM validate_tags(p_include_tags, p_exclude_tags);
  IF NOT v_valid THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(p_include_tags, p_exclude_tags);

  -- Try to get cached search info
  SELECT post_count, last_page_post_ids
  INTO v_post_count, v_last_page_post_ids
  FROM search_cache
  WHERE tags = p_include_tags
    AND exclude_tags = p_exclude_tags;

  -- If no posts exist in the search, return.
  IF v_post_count IS NULL THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Calculate page count
  v_page_count := CEIL(v_post_count::real / p_posts_per_page);

  -- Calculate number of posts currently on last page
  v_post_count := MOD(v_post_count, p_posts_per_page);

  -- If necessary, get additional last page posts
  IF cardinality(v_last_page_post_ids) < v_post_count THEN
    v_last_page_post_ids := uniq(sort_asc(v_last_page_post_ids + array(
      SELECT id
      FROM view_post
      WHERE
        id > (SELECT COALESCE(MAX(id), 0) FROM unnest(v_last_page_post_ids) AS id)
        -- Post must have all the included tags
        AND tags @> p_include_tags
        -- Post must not have any of the excluded tags
        AND NOT tags && p_exclude_tags
      ORDER BY id ASC
      LIMIT p_posts_per_page - cardinality(v_last_page_post_ids)
    )));

    -- Update search cache with posts
    UPDATE search_cache
    SET last_page_post_ids = v_last_page_post_ids
    WHERE tags = p_include_tags
      AND exclude_tags = p_exclude_tags;
  END IF;

  -- Get last page start ID
  v_last_page_start_id := v_last_page_post_ids[v_post_count];

  RETURN (v_page_count, v_last_page_start_id)::page_info;
END;
$BODY$;

CREATE FUNCTION create_refresh_token(
  IN p_user_id integer,
  IN p_ip inet
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
  INSERT INTO refresh_token (session, user_id, created_ip)
  VALUES (v_session, p_user_id, p_ip)
  RETURNING token INTO v_new_token;

  -- Return new token
  RETURN (v_new_token, v_session);
END;
$BODY$;

-- Create invalidate_session function
CREATE FUNCTION invalidate_session(
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
CREATE FUNCTION refresh_refresh_token(
  IN p_token uuid,
  IN p_ip inet
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
    PERFORM invalidate_session(v_refresh_token.session);
    RETURN NULL;
  END IF;

  -- Check if expired
  IF v_refresh_token.expires_at < CURRENT_TIMESTAMP THEN
    RETURN NULL;
  END IF;

  -- Mark token as used
  UPDATE refresh_token
  SET used = true, used_ip = p_ip
  WHERE id = v_refresh_token.id;

  -- Generate new refresh token
  INSERT INTO refresh_token (session, user_id, created_ip)
  VALUES (v_refresh_token.session, v_refresh_token.user_id, p_ip)
  RETURNING token, session, user_id INTO v_result;

  -- Return result
  RETURN v_result;
END;
$BODY$;
