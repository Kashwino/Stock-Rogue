"""Package the engine compactly for static hosts and phone downloads.

Keeps each asset below common static-host file limits. The browser decompresses
the engine as a stream; gameplay code and the exported PCK are unchanged.
"""
from pathlib import Path
import gzip
import re

root = Path("build/web")
wasm = root / "index.wasm"
size = wasm.stat().st_size
(root / "index.wasm.gz").write_bytes(gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0))
loader = """
<script>
(() => {
  const originalFetch = window.fetch.bind(window);
  const engineURL = new URL('index.wasm', location.href);
  window.fetch = async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input), location.href);
    if (url.origin !== engineURL.origin || url.pathname !== engineURL.pathname) {
      return originalFetch(input, init);
    }
    if (!('DecompressionStream' in window)) {
      throw new Error('Please update your browser to play Stock Rogue.');
    }
    url.pathname += '.gz';
    const response = await originalFetch(url.href, init);
    if (!response.ok) throw new Error('The game engine could not download. Please reload.');
    return new Response(response.body.pipeThrough(new DecompressionStream('gzip')), {
      headers: { 'Content-Type': 'application/wasm', 'Content-Length': '__WASM_SIZE__' }
    });
  };
})();
</script>
""".replace("__WASM_SIZE__", str(size))
html_path = root / "index.html"
html = html_path.read_text()
marker = '<script src="index.js"></script>'
assert html.count(marker) == 1, "Godot HTML layout changed"
html_path.write_text(html.replace(marker, loader + marker))
worker = root / "index.service.worker.js"
if worker.exists():
    worker.write_text(worker.read_text().replace('"index.wasm"', '"index.wasm.gz"'))
wasm.unlink()
for path in root.iterdir():
    assert path.stat().st_size < 25 * 1024 * 1024, f"Static asset too large: {path.name}"
print(f"Web engine: {size:,} -> {(root / 'index.wasm.gz').stat().st_size:,} bytes")
