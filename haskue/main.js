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
const runLabel = document.querySelector(".run-label");
const outputFormat = document.querySelector("#output-format");
const operationInputs = document.querySelectorAll('input[name="operation"]');
const encoder = new TextEncoder();

const operations = {
  cue: {
    args: ["haskue", "eval", "input.cue"],
    label: "CUE",
  },
  json: {
    args: ["haskue", "export", "input.cue", "--out", "json"],
    label: "JSON",
  },
  yaml: {
    args: ["haskue", "export", "input.cue", "--out", "yaml"],
    label: "YAML",
  },
};

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

function selectedOperation() {
  const selected = document.querySelector('input[name="operation"]:checked');
  return operations[selected.value];
}

function updateOutputFormat() {
  outputFormat.textContent = selectedOperation().label;
}

async function runHaskue() {
  if (runButton.disabled) {
    return;
  }

  const operation = selectedOperation();

  runButton.disabled = true;
  operationInputs.forEach((input) => {
    input.disabled = true;
  });
  runButton.setAttribute("aria-busy", "true");
  runLabel.textContent = "Running";
  output.dataset.state = "running";
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

    const wasi = new WASI(operation.args, [], fds, { debug: false });
    const instance = await WebAssembly.instantiate(await modulePromise, {
      wasi_snapshot_preview1: wasi.wasiImport,
    });
    const exitCode = wasi.start(instance);
    const stdoutText = stdout.finish();
    const stderrText = stderr.finish();

    output.textContent =
      stdoutText || stderrText || `haskue exited with code ${exitCode}`;
    output.dataset.state = exitCode === 0 ? "success" : "error";
  } catch (error) {
    output.dataset.state = "error";
    output.textContent = error.stack || String(error);
  } finally {
    runButton.disabled = false;
    operationInputs.forEach((input) => {
      input.disabled = false;
    });
    runButton.removeAttribute("aria-busy");
    runLabel.textContent = "Run";
  }
}

runButton.addEventListener("click", runHaskue);
operationInputs.forEach((input) => {
  input.addEventListener("change", updateOutputFormat);
});
source.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
    event.preventDefault();
    runHaskue();
  }
});
updateOutputFormat();
runHaskue();
