CREATE TABLE search_cache
(
  id serial NOT NULL,

  tag_ids integer[] NOT NULL,
  exclude_tag_ids integer[] NOT NULL,

  post_count integer NOT NULL,
  first_post_id integer NOT NULL,
  last_page_post_ids integer[] NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (tag_ids, exclude_tag_ids)
);
