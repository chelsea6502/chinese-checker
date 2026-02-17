export function getOrigin() {
  return globalThis.location?.origin ?? "";
}
