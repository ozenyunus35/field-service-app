// Serves the Flutter web build the way GitHub Pages does, under /<repo>/.
import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";

const root = new URL("../build/web/", import.meta.url).pathname;
const base = process.env.PAGES_BASE_PATH ?? "/field-service-app";
const port = Number(process.env.PORT ?? 4174);
const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
  ".wasm": "application/wasm",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
};

const file = (p) => {
  try {
    return statSync(p).isDirectory() ? file(join(p, "index.html")) : p;
  } catch {
    return null;
  }
};

createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (!url.startsWith(base)) return res.writeHead(302, { location: base + "/" }).end();
  if (url === base) return res.writeHead(301, { location: base + "/" }).end();
  const rel = normalize(url.slice(base.length)).replace(/^(\.\.[/\\])+/, "");
  const hit = file(join(root, rel));
  if (!hit || !hit.startsWith(root)) return res.writeHead(404).end("Not found");
  res.writeHead(200, { "content-type": types[extname(hit)] ?? "application/octet-stream" });
  createReadStream(hit).pipe(res);
}).listen(port, () => console.log(`Serving build/web at http://localhost:${port}${base}/`));
