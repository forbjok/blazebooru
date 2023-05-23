CREATE TABLE post_tag_change
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  post_id integer NOT NULL,
  user_id integer NOT NULL,
  tag_ids_added integer[],
  tag_ids_removed integer[],

  PRIMARY KEY (id)
);
