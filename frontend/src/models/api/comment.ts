export interface Comment {
  id: number;
  created_at: string;
  updated_at: string;
  user_id: number;
  user_name: string;
  comment: string;
}

export interface NewPostComment {
  comment: string;
}
