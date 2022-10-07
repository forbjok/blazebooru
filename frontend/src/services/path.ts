import type { Post } from "@/models/api/post";

export class PathService {
  make_image_path(post: Post) {
    return `/f/o/${post.hash}.${post.ext}`;
  }

  make_thumbnail_path(post: Post) {
    return `/f/t/${post.hash}.${post.tn_ext}`;
  }
}
