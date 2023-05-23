CREATE TABLE post_tag_id_cache
(
  post_id integer NOT NULL,
  tag_ids integer[] NOT NULL DEFAULT '{}',

  PRIMARY KEY (post_id),

  FOREIGN KEY (post_id)
    REFERENCES post (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);
