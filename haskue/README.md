# Haskue in Chrome

This page runs `haskue.wasm` as a WASI command. The page uses
[`@bjorn3/browser_wasi_shim`](https://github.com/bjorn3/browser_wasi_shim) to
provide command-line arguments, CUE source through stdin, and stdout/stderr.

From the repository root, start a local HTTP server:

```sh
python3 -m http.server 8000 --bind 127.0.0.1
```

Then open this URL in Chrome:

<http://localhost:8000/haskue/>

Do not open `index.html` directly with a `file://` URL: browsers restrict module
and WebAssembly loading from local files. The example loads the WASI shim from
jsDelivr, so the first load requires an internet connection.
