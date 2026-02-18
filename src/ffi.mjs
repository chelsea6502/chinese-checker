export function getOrigin() {
  const loc = globalThis.location;
  if (!loc) return "";
  // Use the page URL's directory so this works on any subpath (e.g. GitHub Pages project pages)
  return new URL(".", loc.href).href.replace(/\/$/, "");
}
