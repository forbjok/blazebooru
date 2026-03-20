-- Create index on post hash column
CREATE INDEX post_hash_idx ON post
  USING btree
  (hash ASC NULLS LAST, is_deleted ASC NULLS LAST);
