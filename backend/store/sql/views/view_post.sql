CREATE VIEW view_post
AS
SELECT
  p.id,
  p.created_at,
  p.user_id,
  u.name AS user_name,
  p.title,
  p.description,
  p.source,
  p.filename,
  p.size,
  p.width,
  p.height,
  p.hash,
  p.ext,
  p.tn_ext,
  p.tags
FROM post AS p
JOIN "user" AS u ON u.id = p.user_id
WHERE NOT is_deleted;
