CREATE TYPE update_post AS (
  id integer,

  title text,
  description text,
  source text,
  add_tags text[],
  remove_tags text[]
);
