const base = import.meta.env.BASE_URL.replace(/\/?$/, "/");

export function sitePath(path = "/") {
  const cleanPath = path.replace(/^\//, "");
  return `${base}${cleanPath}`;
}
