export function formatPrice(cents: number) {
  if (cents < 0) {
    throw new Error("Price cannot be negative");
  }
  return `$${(cents / 100).toFixed(2)}`;
}
