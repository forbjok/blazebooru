CREATE TABLE post
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id integer NOT NULL,
  title text,
  description text,
  source text,
  filename text NOT NULL,
  size integer NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  hash text NOT NULL,
  ext text NOT NULL,
  tn_ext text NOT NULL,
  tags text[] NOT NULL DEFAULT '{}',
  is_deleted boolean NOT NULL DEFAULT false,

  PRIMARY KEY (id),

  FOREIGN KEY (user_id)
    REFERENCES "user" (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);

SELECT manage_updated_at('post'); -- Automatically manage updated_at

CREATE INDEX post_is_deleted_idx ON post
  USING btree
  (is_deleted ASC NULLS LAST);
