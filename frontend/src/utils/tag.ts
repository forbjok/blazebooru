export function normalize_tag(text: string): string {
  return (
    text
      .trim()
      .toLowerCase()
      // Remove control characters
      .replace(/\p{C}+/gu, "")
      // Collapse all blocks of whitespace to a single space
      .replace(/\s+/g, " ")
      // Remove whitespace immediately preceding or following a colon
      .replace(/(?<=:)\s+/g, "")
      .replace(/\s+(?=:)/g, "")
  );
}
