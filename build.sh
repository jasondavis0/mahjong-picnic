#!/bin/zsh
# Builds the installable web app into ./docs from mahjong-picnic.html (the game source).
set -e
cd "$(dirname "$0")"
OUT=docs
mkdir -p "$OUT"

# Icons
sips -s format png -z 512 512 assets/icon.svg --out "$OUT/icon-512.png" >/dev/null
sips -s format png -z 192 192 assets/icon.svg --out "$OUT/icon-192.png" >/dev/null
sips -s format png -z 180 180 assets/icon.svg --out "$OUT/apple-touch-icon.png" >/dev/null

VERSION=$(date +%Y%m%d%H%M%S)

# Page
{
cat <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Mahjong Picnic">
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<link rel="icon" type="image/png" href="icon-192.png">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}</style>
</head><body>
EOF
cat mahjong-picnic.html
cat <<'EOF'
<script>if('serviceWorker' in navigator&&location.protocol==='https:'){addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}))}</script>
</body></html>
EOF
} > "$OUT/index.html"

# Manifest
cat > "$OUT/manifest.webmanifest" <<'EOF'
{
  "name": "Mahjong Picnic",
  "short_name": "Picnic",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#061d19",
  "theme_color": "#0a2f29",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
EOF

# Service worker: offline play. Page files are cached on install; fonts are cached the first time they load.
cat > "$OUT/sw.js" <<EOF
const CACHE = 'picnic-$VERSION';
const FILES = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES))); self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  if (url.origin === location.origin) {
    // network first for the page so updates arrive, cache when offline
    e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(k => k.put(e.request, c)); return r; })
      .catch(() => caches.match(e.request).then(r => r || caches.match('index.html'))));
  } else if (/fonts\.(googleapis|gstatic)\.com/.test(url.host)) {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const c = res.clone(); caches.open(CACHE).then(k => k.put(e.request, c)); return res; })));
  }
});
EOF

echo "Built $OUT/ (version $VERSION)"
ls -la "$OUT"
