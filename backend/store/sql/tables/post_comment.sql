CREATE TABLE post_comment (
  post_id integer NOT NULL,

  FOREIGN KEY (post_id)
    REFERENCES post (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
) INHERITS (comment);
