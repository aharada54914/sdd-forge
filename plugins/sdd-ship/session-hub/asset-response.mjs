export function assetResponse(path, assets) {
  const name = path === '/hub' || path === '/hub/' ? 'hub.html' : path.startsWith('/hub/') ? path.slice(5) : '';
  if (!Object.hasOwn(assets, name)) return null;
  const type = name.endsWith('.html') ? 'text/html' : name.endsWith('.css') ? 'text/css' : 'text/javascript';
  return new Response(assets[name], { headers: { 'Content-Type':type + '; charset=utf-8', 'Cache-Control':'private, no-store', 'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer',
    'Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'self'; form-action 'self'" } });
}
