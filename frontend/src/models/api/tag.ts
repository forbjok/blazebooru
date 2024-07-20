export interface Tag {
  id: number;
  tag: string;
  alias_of_tag?: string;
  aliases: string[];
  implied_tags: string[];
}

export interface UpdateTag {
  add_aliases?: string[];
  remove_aliases?: string[];
  add_implied_tags?: string[];
  remove_implied_tags?: string[];
}
