---- DROP ----
DROP FUNCTION get_tag_ids;
DROP FUNCTION resolve_and_validate_tags;
DROP FUNCTION initialize_search_cache;
DROP FUNCTION update_post_tags;
DROP FUNCTION calculate_pages;
DROP FUNCTION calculate_pages_reverse;
DROP FUNCTION calculate_last_page;
DROP FUNCTION get_view_posts;

DROP TABLE search_cache;

---- TABLES ----

-- Create search_cache table
CREATE UNLOGGED TABLE search_cache
(
  id serial NOT NULL,

  tag_ids integer[] NOT NULL,
  exclude_tag_ids integer[] NOT NULL,
  wildcard_tags text[] NOT NULL,
  wildcard_exclude_tags text[] NOT NULL,

  first_post_id integer NOT NULL,
  last_post_id integer NOT NULL,
  post_count integer NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (tag_ids, exclude_tag_ids, wildcard_tags, wildcard_exclude_tags)
);

-- Create search_cache_block table
CREATE UNLOGGED TABLE search_cache_block
(
  search_cache_id integer NOT NULL,
  block smallint NOT NULL,

  start_id integer NOT NULL,
  end_id integer NOT NULL,

  post_count integer NOT NULL,

  PRIMARY KEY (search_cache_id, block),

  FOREIGN KEY (search_cache_id)
    REFERENCES search_cache (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

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
$BODY$ STABLE PARALLEL SAFE;

-- Create get_wildcard_tags function
CREATE FUNCTION get_wildcard_tags(
  IN p_tags text[]
)
RETURNS text[]
LANGUAGE plpgsql

AS $BODY$
BEGIN
  RETURN array(SELECT REPLACE(t, '*', '%') FROM unnest(p_tags) AS t WHERE t LIKE '%*%');
END;
$BODY$ IMMUTABLE PARALLEL SAFE;

-- Create resolve_and_validate_tags function
CREATE FUNCTION resolve_and_validate_tags(
  IN p_tags text[],
  IN p_exclude_tags text[],
  OUT p_tag_ids integer[],
  OUT p_exclude_tag_ids integer[],
  OUT p_wildcard_tags text[],
  OUT p_wildcard_exclude_tags text[],
  OUT p_valid boolean
)
LANGUAGE plpgsql

AS $BODY$
BEGIN
  p_tag_ids := get_tag_ids(p_tags);
  p_exclude_tag_ids := get_tag_ids(p_exclude_tags);
  p_wildcard_tags := get_wildcard_tags(p_tags);
  p_wildcard_exclude_tags := get_wildcard_tags(p_exclude_tags);

  p_valid := NOT (icount(p_tag_ids) < icount(p_tag_ids) OR p_tag_ids && p_exclude_tag_ids);
END;
$BODY$ STABLE;

-- Create initialize_search_cache function
CREATE FUNCTION initialize_search_cache(
  IN p_tag_ids integer[],
  IN p_exclude_tag_ids integer[],
  IN p_wildcard_tags text[],
  IN p_wildcard_exclude_tags text[]
)
RETURNS VOID
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_search_cache_id integer;
  v_post_count integer;
  v_total_blocks smallint;
  v_block smallint;
  v_first_post_id integer;
  v_last_post_id integer;
  v_query text;
BEGIN
  -- Try to get cached search info
  SELECT id, post_count
  INTO v_search_cache_id, v_post_count
  FROM search_cache
  WHERE tag_ids = p_tag_ids
    AND exclude_tag_ids = p_exclude_tag_ids
    AND wildcard_tags = p_wildcard_tags
    AND wildcard_exclude_tags = p_wildcard_exclude_tags;

  IF v_search_cache_id IS NULL THEN
    INSERT INTO search_cache (
      tag_ids,
      exclude_tag_ids,
      wildcard_tags,
      wildcard_exclude_tags,
      first_post_id,
      last_post_id,
      post_count
    )
    VALUES (
      p_tag_ids, -- tags
      p_exclude_tag_ids, -- exclude_tags
      p_wildcard_tags, -- wildcard_tags
      p_wildcard_exclude_tags, -- wildcard_exclude_tags
      0, -- first_post_id
      0, -- last_post_id
      0 -- post_count
    )
    RETURNING id INTO v_search_cache_id;
  END IF;

  -- Determine total number of blocks
  v_total_blocks := (SELECT COALESCE(FLOOR(MAX(post_id)::real / 10000) + 1, 0)::smallint FROM post_tag_id_cache);

  v_query := $$
    -- Get total post count in search
    SELECT COALESCE(COUNT(*)::integer, 0)
    FROM post_tag_id_cache AS ptic
    JOIN post AS p ON p.id = ptic.post_id
    WHERE ptic.post_id >= $5 AND ptic.post_id < ($5 + 10000)
  $$;

  IF icount(p_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must have all the included tags
      AND ptic.tag_ids @> $1
    $$;
  END IF;

  IF icount(p_exclude_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && $2
    $$;
  END IF;

  IF cardinality(p_wildcard_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must match at least one tag matching each wildcard tag
      AND NOT EXISTS(SELECT * FROM unnest($3) AS wct WHERE NOT EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  IF cardinality(p_wildcard_exclude_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must not match any tag matching any wildcard exclude tag
      AND NOT EXISTS(SELECT * FROM unnest($4) AS wct WHERE EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  -- Calculate missing blocks
  FOR v_block IN (SELECT n::smallint
                  FROM generate_series(0, v_total_blocks - 1) AS n
                  WHERE NOT EXISTS(SELECT * FROM search_cache_block WHERE search_cache_id = v_search_cache_id AND block = n))
  LOOP
    v_first_post_id := (v_block * 10000);

    EXECUTE v_query
    INTO v_post_count
    USING
      p_tag_ids,
      p_exclude_tag_ids,
      p_wildcard_tags,
      p_wildcard_exclude_tags,
      v_first_post_id;

    INSERT INTO search_cache_block (
      search_cache_id,
      block,
      start_id,
      end_id,
      post_count
    )
    VALUES (
      v_search_cache_id,
      v_block,
      v_first_post_id,
      v_first_post_id + 9999,
      v_post_count
    );
  END LOOP;

  -- Update search cache
  UPDATE search_cache
  SET
    first_post_id = (SELECT COALESCE(MIN(block) * 10000, 0) FROM search_cache_block WHERE search_cache_id = v_search_cache_id AND post_count > 0),
    last_post_id = (SELECT COALESCE((MIN(block) + 1) * 10000, 0) FROM search_cache_block WHERE search_cache_id = v_search_cache_id AND post_count > 0),
    post_count = (SELECT SUM(post_count) FROM search_cache_block WHERE search_cache_id = v_search_cache_id)
  WHERE id = v_search_cache_id;
END;
$BODY$;

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
  v_new_tag_ids := (v_old_tag_ids | v_add_tag_ids) - v_remove_tag_ids;

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

  -- Delete affected search cache blocks
  DELETE FROM search_cache_block AS scb
  USING search_cache AS sc
  WHERE scb.search_cache_id = sc.id
    AND p_post_id BETWEEN scb.start_id AND scb.end_id;

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



-- Create calculate_pages function
-- Calculate the starting IDs of a range of pages,
-- optionally starting from an already known page.
CREATE FUNCTION calculate_pages(
  IN p_tags text[],
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
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_wildcard_tags text[];
  v_wildcard_exclude_tags text[];
  v_valid boolean;
  v_start_id integer;
  v_query text;
BEGIN
  SELECT *
  INTO v_tag_ids, v_exclude_tag_ids, v_wildcard_tags, v_wildcard_exclude_tags, v_valid
  FROM resolve_and_validate_tags(p_tags, p_exclude_tags);

  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_start_id := p_origin_page.start_id;
  ELSE
    v_start_id := (SELECT MAX(post_id) FROM post_tag_id_cache);
  END IF;

  v_query := $$
    SELECT array(
      SELECT (no, start_id)::page_info
      FROM (
        SELECT
          COALESCE($8, 1) + ROW_NUMBER() OVER () - 1 AS no,
          x.id AS start_id
        FROM (
          SELECT
            ptic.post_id AS id,
            ROW_NUMBER() OVER (ORDER BY ptic.post_id DESC) AS rn
          FROM post_tag_id_cache AS ptic
          JOIN post AS p ON p.id = ptic.post_id
          WHERE
            -- Only scan forward from start ID
            ptic.post_id <= $5
  $$;

  IF icount(v_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must have all the included tags
      AND ptic.tag_ids @> $1
    $$;
  END IF;

  IF icount(v_exclude_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && $2
    $$;
  END IF;

  IF cardinality(v_wildcard_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must match at least one tag matching each wildcard tag
      AND NOT EXISTS(SELECT * FROM unnest($3) AS wct WHERE NOT EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  IF cardinality(v_wildcard_exclude_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must not match any tag matching any wildcard exclude tag
      AND NOT EXISTS(SELECT * FROM unnest($4) AS wct WHERE EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  v_query := v_query || $$
          ORDER BY ptic.post_id DESC
          LIMIT $6 * $7 -- X pages at a time
        ) AS x
        WHERE MOD(x.rn - 1, $7) = 0
      ) AS x
      WHERE x.no > COALESCE($8, 0)
    );
  $$;

  EXECUTE v_query
  INTO v_pages
  USING
    v_tag_ids,
    v_exclude_tag_ids,
    v_wildcard_tags,
    v_wildcard_exclude_tags,
    v_start_id,
    p_page_count,
    p_posts_per_page,
    p_origin_page.no;

  RETURN v_pages;
END;
$BODY$ STABLE;

-- Create calculate_pages_reverse function
-- Like calculate_pages, but in reverse.
-- (Calculates previous pages)
CREATE FUNCTION calculate_pages_reverse(
  IN p_tags text[],
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
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_wildcard_tags text[];
  v_wildcard_exclude_tags text[];
  v_valid boolean;
  v_last_id integer;
  v_query text;
BEGIN
  SELECT *
  INTO v_tag_ids, v_exclude_tag_ids, v_wildcard_tags, v_wildcard_exclude_tags, v_valid
  FROM resolve_and_validate_tags(p_tags, p_exclude_tags);

  IF NOT v_valid THEN
    RETURN v_pages;
  END IF;

  IF p_origin_page.start_id IS NOT NULL THEN
    v_last_id := p_origin_page.start_id;
  END IF;

  v_query := $$
    SELECT array(
      SELECT (no, start_id)::page_info
      FROM (
        SELECT
          COALESCE($8, 0) - ROW_NUMBER() OVER () + 1 AS no,
          x.id AS start_id
        FROM (
          SELECT
            ptic.post_id AS id,
            ROW_NUMBER() OVER (ORDER BY ptic.post_id ASC) AS rn
          FROM post_tag_id_cache AS ptic
          JOIN post AS p ON p.id = ptic.post_id
          WHERE
            -- Only scan backwards from the origin
            ptic.post_id >= $5
  $$;

  IF icount(v_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Reduce amount of posts to be scanned by filtering down
      -- to only post IDs that have at least one of the search tags.
      AND ptic.post_id IN (SELECT pt.post_id
                           FROM post_tag AS pt
                           WHERE pt.post_id BETWEEN $6 AND $5
                             AND pt.tag_id = ANY($1))
      -- Post must have all the included tags
      AND ptic.tag_ids @> $1
    $$;
  END IF;

  IF icount(v_exclude_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && $2
    $$;
  END IF;

  IF cardinality(v_wildcard_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must match at least one tag matching each wildcard tag
      AND NOT EXISTS(SELECT * FROM unnest($3) AS wct WHERE NOT EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  IF cardinality(v_wildcard_exclude_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must not match any tag matching any wildcard exclude tag
      AND NOT EXISTS(SELECT * FROM unnest($4) AS wct WHERE EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  v_query := v_query || $$
          ORDER BY ptic.post_id ASC
          LIMIT (($6 + 1) * $7) -- X pages at a time
        ) AS x
        WHERE MOD(x.rn - 1, $7) = 0
      ) AS x
      WHERE x.no < $8
    );
  $$;

  EXECUTE v_query
  INTO v_pages
  USING
    v_tag_ids,
    v_exclude_tag_ids,
    v_wildcard_tags,
    v_wildcard_exclude_tags,
    v_last_id,
    p_page_count,
    p_posts_per_page,
    p_origin_page.no;

  RETURN v_pages;
END;
$BODY$;

-- Create calculate_last_page function
CREATE FUNCTION calculate_last_page(
  IN p_tags text[],
  IN p_exclude_tags text[],
  IN p_posts_per_page integer
)
RETURNS page_info
LANGUAGE plpgsql

AS $BODY$
DECLARE
  v_tag_ids integer[];
  v_exclude_tag_ids integer[];
  v_wildcard_tags text[];
  v_wildcard_exclude_tags text[];
  v_valid boolean;
  v_search_cache_id integer;
  v_first_post_id integer;
  v_post_count integer;
  v_page_count integer;
  v_query text;
  v_last_page_start_id integer;
BEGIN
  SELECT *
  INTO v_tag_ids, v_exclude_tag_ids, v_wildcard_tags, v_wildcard_exclude_tags, v_valid
  FROM resolve_and_validate_tags(p_tags, p_exclude_tags);

  IF NOT v_valid THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Make sure search cache is initialized
  PERFORM initialize_search_cache(v_tag_ids, v_exclude_tag_ids, v_wildcard_tags, v_wildcard_exclude_tags);

  -- Try to get cached search info
  SELECT id, first_post_id, post_count
  INTO v_search_cache_id, v_first_post_id, v_post_count
  FROM search_cache
  WHERE tag_ids = v_tag_ids
    AND exclude_tag_ids = v_exclude_tag_ids
    AND wildcard_tags = v_wildcard_tags
    AND wildcard_exclude_tags = v_wildcard_exclude_tags;

  -- If no posts exist in the search, return.
  IF v_post_count = 0 THEN
    RETURN (1, 0)::page_info;
  END IF;

  -- Calculate page count
  v_page_count := CEIL(v_post_count::real / p_posts_per_page);

  -- Calculate number of posts currently on last page
  v_post_count := MOD(v_post_count, p_posts_per_page);

  v_query := $$
    SELECT ptic.post_id
    FROM post_tag_id_cache AS ptic
    JOIN post AS p ON p.id = ptic.post_id
    WHERE
      ptic.post_id > $5
  $$;

  IF icount(v_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must have all the included tags
      AND ptic.tag_ids @> $1
    $$;
  END IF;

  IF icount(v_exclude_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && $2
    $$;
  END IF;

  IF cardinality(v_wildcard_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must match at least one tag matching each wildcard tag
      AND NOT EXISTS(SELECT * FROM unnest($3) AS wct WHERE NOT EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  IF cardinality(v_wildcard_exclude_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must not match any tag matching any wildcard exclude tag
      AND NOT EXISTS(SELECT * FROM unnest($4) AS wct WHERE EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  v_query := v_query || $$
    ORDER BY ptic.post_id ASC
    LIMIT 1
    OFFSET $6;
  $$;

  EXECUTE v_query
  INTO v_last_page_start_id
  USING
    v_tag_ids,
    v_exclude_tag_ids,
    v_wildcard_tags,
    v_wildcard_exclude_tags,
    v_first_post_id,
    p_posts_per_page;

  RETURN (v_page_count, v_last_page_start_id)::page_info;
END;
$BODY$;

-- Create get_view_posts function
CREATE FUNCTION get_view_posts(
  IN p_tags text[],
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
  v_wildcard_tags text[];
  v_wildcard_exclude_tags text[];
  v_valid boolean;
  v_query text;
BEGIN
  SELECT *
  INTO v_tag_ids, v_exclude_tag_ids, v_wildcard_tags, v_wildcard_exclude_tags, v_valid
  FROM resolve_and_validate_tags(p_tags, p_exclude_tags);

  IF NOT v_valid THEN
    RETURN;
  END IF;

  v_query := $$
    SELECT p.*
    FROM post_tag_id_cache AS ptic
    JOIN view_post AS p ON p.id = ptic.post_id
    WHERE
      -- Only scan forward from the origin
      ptic.post_id <= $5
  $$;

  IF icount(v_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must have all the included tags
      AND ptic.tag_ids @> $1
    $$;
  END IF;

  IF icount(v_exclude_tag_ids) > 0 THEN
    v_query := v_query || $$
      -- Post must not have any of the excluded tags
      AND NOT ptic.tag_ids && $2
    $$;
  END IF;

  IF cardinality(v_wildcard_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must match at least one tag matching each wildcard tag
      AND NOT EXISTS(SELECT * FROM unnest($3) AS wct WHERE NOT EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  IF cardinality(v_wildcard_exclude_tags) > 0 THEN
    v_query := v_query || $$
      -- Posts must not match any tag matching any wildcard exclude tag
      AND NOT EXISTS(SELECT * FROM unnest($4) AS wct WHERE EXISTS(SELECT * FROM unnest(p.tags) AS tag WHERE tag LIKE wct))
    $$;
  END IF;

  v_query := v_query || $$
    ORDER BY ptic.post_id DESC
    LIMIT $6;
  $$;

  RETURN QUERY
  EXECUTE v_query
  USING
    v_tag_ids,
    v_exclude_tag_ids,
    v_wildcard_tags,
    v_wildcard_exclude_tags,
    p_start_id,
    p_limit;
END;
$BODY$ STABLE;
