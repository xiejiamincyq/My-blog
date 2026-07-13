import { createServer } from "node:http";
import { createReadStream, existsSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const root = join(process.cwd(), "dist");
const port = Number(process.env.PORT || 4321);

const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".webp": "image/webp",
  ".xml": "application/xml; charset=utf-8",
};

function resolvePath(urlPath) {
  const decoded = decodeURIComponent(urlPath.split("?")[0]);
  const clean = normalize(decoded).replace(/^(\.\.[/\\])+/, "");
  const target = join(root, clean);
  if (existsSync(target) && statSync(target).isFile()) return target;
  if (existsSync(target) && statSync(target).isDirectory()) return join(target, "index.html");
  return join(root, "404.html");
}

createServer((req, res) => {
  const filePath = resolvePath(req.url || "/");
  if (!existsSync(filePath)) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }

  res.writeHead(filePath.endsWith("404.html") ? 404 : 200, {
    "Content-Type": types[extname(filePath)] || "application/octet-stream",
  });
  createReadStream(filePath).pipe(res);
}).listen(port, "127.0.0.1", () => {
  console.log(`Static preview running at http://127.0.0.1:${port}/`);
});
