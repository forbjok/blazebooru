export interface Tag {
  id: number;
  tag: string;
  alias_of_tag?: string;
  implied_tags: string[];
}

export interface UpdateTag {
  alias_of_tag?: string;
  add_implied_tags?: string[];
  remove_implied_tags?: string[];
}
