// Local production-output verification only; not a deployment server.
// Usage: node tool/serve_web.mjs build/web 3088
import http from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import {resolve, sep, extname} from 'node:path';

const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 3088);
const types = {'.html':'text/html; charset=utf-8', '.js':'text/javascript',
  '.mjs':'text/javascript', '.json':'application/json', '.png':'image/png',
  '.wasm':'application/wasm', '.woff2':'font/woff2', '.ttf':'font/ttf',
  '.otf':'font/otf', '.css':'text/css', '.svg':'image/svg+xml'};
http.createServer(async (request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) {
    response.writeHead(405); response.end(); return;
  }
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let path = resolve(root, '.' + pathname);
    if (path !== root && !path.startsWith(root + sep)) {
      response.writeHead(403); response.end(); return;
    }
    if ((await stat(path)).isDirectory()) path = resolve(path, 'index.html');
    const data = await readFile(path);
    response.writeHead(200, {'Content-Type': types[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': 'no-cache', 'X-Content-Type-Options': 'nosniff'});
    response.end(request.method === 'HEAD' ? undefined : data);
  } catch {
    response.writeHead(404); response.end('Not found');
  }
}).listen(port, '127.0.0.1', () => console.log('Sky Hopper local preview: http://127.0.0.1:' + port));
