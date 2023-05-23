CREATE TABLE comment
(
  id serial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  user_id integer,
  user_name text,
  comment text NOT NULL,

  PRIMARY KEY (id),

  FOREIGN KEY (user_id)
    REFERENCES "user" (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
    NOT VALID
);
