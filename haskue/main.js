import {
  ConsoleStdout,
  File,
  OpenFile,
  PreopenDirectory,
  WASI,
} from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/dist/index.js";

const source = document.querySelector("#source");
const output = document.querySelector("#output");
const runButton = document.querySelector("#run");
const encoder = new TextEncoder();

// Compile the wasm artifact once, then create a fresh instance for every
// invocation because a WASI command can run only once.
const modulePromise = fetch("./haskue.wasm")
  .then((response) => {
    if (!response.ok) {
      throw new Error(`Could not load haskue.wasm (${response.status})`);
    }
    return response.arrayBuffer();
  })
  .then(WebAssembly.compile);

function captureOutput() {
  const decoder = new TextDecoder();
  let text = "";

  return {
    fd: new ConsoleStdout((bytes) => {
      text += decoder.decode(bytes, { stream: true });
    }),
    finish() {
      return text + decoder.decode();
    },
  };
}

async function runHaskue() {
  runButton.disabled = true;
  output.textContent = "Running…";

  try {
    const stdout = captureOutput();
    const stderr = captureOutput();
    const fds = [
      new OpenFile(new File([])),
      stdout.fd,
      stderr.fd,
      new PreopenDirectory(".", [
        ["input.cue", new File(encoder.encode(source.value), { readonly: true })],
      ]),
    ];

    // This is equivalent to:
    //   haskue export input.cue --out json
    const wasi = new WASI(
      ["haskue", "export", "input.cue", "--out", "json"],
      [],
      fds,
      { debug: false },
    );
    const instance = await WebAssembly.instantiate(await modulePromise, {
      wasi_snapshot_preview1: wasi.wasiImport,
    });
    const exitCode = wasi.start(instance);
    const stdoutText = stdout.finish();
    const stderrText = stderr.finish();

    output.textContent =
      stdoutText || stderrText || `haskue exited with code ${exitCode}`;
  } catch (error) {
    output.textContent = error.stack || String(error);
  } finally {
    runButton.disabled = false;
  }
}

runButton.addEventListener("click", runHaskue);
runHaskue();
