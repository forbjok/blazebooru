CREATE TYPE update_tag AS (
  alias_of_tag text,
  add_implied_tags text[],
  remove_implied_tags text[]
);
