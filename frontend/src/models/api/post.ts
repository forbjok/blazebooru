export interface Post {
  id: number;
  created_at: string;
  user_name: string;
  title?: string;
  description?: string;
  filename: string;
  size: string;
  width: string;
  height: string;
  hash: string;
  ext: string;
  tn_ext: string;
  tags: string[];
}

export interface PostInfo {
  title?: string;
  description?: string;
  tags: string[];
}

export interface PaginationStats {
  max_id: number;
  count: number;
}
