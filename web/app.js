#!/usr/bin/env node

// Node.js Standard Library
const os    = require("os");
const fs    = require("fs");
const path  = require("path");
const spawn = require("child_process").spawn;

// NPM Dependencies
const WebSocket = require("ws");

// Create WebSocket Server
const port = process.env.port || 2019;
const wss  = new WebSocket.Server({port},
  () => console.log("listening on ws://0.0.0.0:"+port));

// Create WebSocket Message Handler
wss.on("connection", ws => {
  ws.on("message", msg => {
    // Parse JSON WebSocket Message
    let data;
    try {
      data = JSON.parse(msg);
      console.log("recv", data);
    } catch (e) {
      console.error("error: unable to parse JSON");
      data = {type: "JSON_Error"};
    }

    // Route Requests
    switch (data.type) {
      case "request_synthesis":
        synthesize(ws, data);
        break;

      default:
        console.error("error: unrecognized data type:", data.type);
        break;
    }

    console.log("----");
  });
});

// Synthesis Request
async function synthesize(ws, data) {
  console.log("Recieved Synthesis Request...");

  // Generate a temp directory
  console.log("Generating temp directory...");
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "icestorm-server_"));
  console.log(tmpdir);

  try {
    // Save the files the the temp directory, then synthesize the HDL.
    console.log("Saving source files to temp directory...");
    for (let file of data.files) {
      console.log(file.name);
      fs.writeFileSync(`${tmpdir}/${file.name}`, file.body);
    }

    // Run the IceStorm toolchain flow
    console.log("Running IceStorm flow with Make...");
    const bitstream = await run_icestorm_make(tmpdir, data.top_module);

    // Send the compressed bitstream to the WebSocket client.
    ws.send(JSON.stringify({type: "bitstream", bitstream}));
  } catch (e) {
    console.error(e);
    console.error("error: unable to synthesize");
  } finally {
    // Purge temp directory
    console.log("Purging temp directory...", tmpdir);
    rmdir(tmpdir);
  }
}

function run_icestorm_make(dir, top_module) {
  // Spawn IceStorm + Make toolchain flow
  const args = [`BUILD_DIR=${dir}`, `TOP_MODULE=${top_module}`];
  const proc = spawn("make", args, {cwd: "./synthesis/"});

  // stdout/stderr logging
  const log = data => {
    const str = data.toString();
    process.stdout.write(str);
  };
  proc.stdout.setEncoding("utf-8");
  proc.stdout.on("data", log);
  proc.stderr.setEncoding("utf-8");
  proc.stderr.on("data", log);

  // Grab the compressed bitstream and return it via a Promise
  return new Promise(resolve => {
    proc.on("close", status => {
      console.log("make exit code = " + status);
      const bitstream = fs.readFileSync(`${dir}/out.bin.cbin`);
      resolve(bitstream);
    });
  });
}

// https://stackoverflow.com/a/32197381
function rmdir(path) {
  if (fs.existsSync(path)) {
    fs.readdirSync(path).forEach(function(file, index) {
      var curPath = path + "/" + file;
      if (fs.lstatSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(path);
  }
}