export function normalize_tag(text: string): string {
  return (
    text
      .trim()
      .toLowerCase()
      // Collapse all blocks of whitespace to a single space
      .replace(/\s+/g, " ")
      // Remove characters that are not allowed
      .replace(/[^a-z:\d\s]+/g, "")
      // Remove whitespace immediately preceding or following a colon
      .replace(/(?<=:)\s+/g, "")
      .replace(/\s+(?=:)/g, "")
  );
}
