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
const wasmUrl = new URL("./haskue.wasm", import.meta.url);
let moduleState = "loading";

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

function wasmError(name, message, cause, details = {}) {
  const error = new Error(message);
  error.name = name;
  error.cause = cause;
  Object.assign(error, details);
  return error;
}

async function loadWasmModule() {
  let response;

  try {
    response = await fetch(wasmUrl);
  } catch (error) {
    moduleState = "failed";
    throw wasmError(
      "WasmNetworkError",
      "The WebAssembly download could not be started.",
      error,
    );
  }

  if (!response.ok) {
    moduleState = "failed";
    throw wasmError(
      "WasmHttpError",
      `The server returned HTTP ${response.status} ${response.statusText}.`,
      null,
      { status: response.status },
    );
  }

  let bytes;
  try {
    bytes = await response.arrayBuffer();
  } catch (error) {
    moduleState = "failed";
    throw wasmError(
      "WasmNetworkError",
      "The WebAssembly download was interrupted before it completed.",
      error,
    );
  }

  moduleState = "compiling";
  if (runButton.disabled) {
    output.textContent = "Compiling WebAssembly…";
  }

  try {
    const module = await WebAssembly.compile(bytes);
    moduleState = "ready";
    return module;
  } catch (error) {
    moduleState = "failed";
    throw wasmError(
      "WasmCompileError",
      "The WebAssembly file was downloaded but could not be compiled.",
      error,
    );
  }
}

// Compile the wasm artifact once, then create a fresh instance for every
// invocation because a WASI command can run only once.
const modulePromise = loadWasmModule();

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

function errorDetails(error) {
  if (!error.cause) {
    return error.message;
  }

  return `${error.cause.name}: ${error.cause.message}`;
}

function formatError(error) {
  if (error.name === "WasmNetworkError") {
    const browserStatus = navigator.onLine ? "online" : "offline";
    return [
      "Unable to load Haskue WebAssembly.",
      "",
      error.message,
      "Check your network connection and reload the page. If the problem continues, try another network or temporarily disable any VPN or content blocker.",
      "",
      `Resource: ${wasmUrl.href}`,
      `Browser network status: ${browserStatus}`,
      `Details: ${errorDetails(error)}`,
    ].join("\n");
  }

  if (error.name === "WasmHttpError") {
    return [
      "Unable to load Haskue WebAssembly.",
      "",
      error.message,
      "The file may be temporarily unavailable. Reload the page and try again.",
      "",
      `Resource: ${wasmUrl.href}`,
    ].join("\n");
  }

  if (error.name === "WasmCompileError") {
    return [
      "Unable to start Haskue WebAssembly.",
      "",
      error.message,
      "Try updating your browser or opening the page in another browser.",
      "",
      `Details: ${errorDetails(error)}`,
    ].join("\n");
  }

  return error.stack || String(error);
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
  runLabel.textContent = moduleState === "ready" ? "Running" : "Loading";
  output.dataset.state = "running";
  output.textContent =
    moduleState === "ready" ? "Running…" : "Loading WebAssembly…";

  try {
    const module = await modulePromise;
    runLabel.textContent = "Running";
    output.textContent = "Running…";

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
    const instance = await WebAssembly.instantiate(module, {
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
    output.textContent = formatError(error);
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
