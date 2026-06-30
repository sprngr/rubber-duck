export function parseAge(input: string): number {
  const n = Number.parseInt(input, 10);
  if (Number.isNaN(n)) {
    throw new Error("invalid age");
  }
  return n;
}
