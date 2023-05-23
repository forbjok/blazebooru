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

CREATE INDEX post_tag_tag_id_idx ON post_tag
  USING btree
  (tag_id ASC NULLS LAST);
