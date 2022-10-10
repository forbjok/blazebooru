import type { Post } from "@/models/api/post";

export function make_image_path(post: Post) {
  return `/f/o/${post.hash}.${post.ext}`;
}

export function make_thumbnail_path(post: Post) {
  return `/f/t/${post.hash}.${post.tn_ext}`;
}
