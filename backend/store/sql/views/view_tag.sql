CREATE VIEW view_tag
AS
SELECT
  t.id,
  t.tag,
  aot.tag AS alias_of_tag,
  array(SELECT tag FROM tag AS t1 JOIN unnest(t.implied_tag_ids) AS itid ON t1.id = itid) AS implied_tags
FROM tag AS t
LEFT JOIN tag AS aot ON aot.id = t.alias_of_tag_id;
