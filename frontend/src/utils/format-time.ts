import { format, parseJSON } from "date-fns";

export function formatTime(value: string) {
  const time = parseJSON(value);

  // If time is not this year, include full date with year
  return format(time, "MM/dd/yy (EEE) HH:mm:ss");
}
