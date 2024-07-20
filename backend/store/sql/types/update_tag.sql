CREATE TYPE update_tag AS (
  add_aliases text[],
  remove_aliases text[],
  add_implied_tags text[],
  remove_implied_tags text[]
);
