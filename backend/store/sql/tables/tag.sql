CREATE TABLE tag
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tag text NOT NULL,
  alias_of_tag_id integer REFERENCES tag(id),
  implied_tag_ids integer[] NOT NULL DEFAULT '{}',

  PRIMARY KEY (id),
  UNIQUE (tag)
);

SELECT manage_updated_at('tag'); -- Automatically manage updated_at
