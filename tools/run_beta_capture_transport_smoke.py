#!/usr/bin/env python3
"""Exercise the actual Godot uploader with a lost/failed response and a retry."""
import gzip
import hashlib
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading

project = Path(__file__).resolve().parents[1]
calls = []

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        assert self.path == "/v1/beta-captures"
        assert self.headers["Authorization"] == "Bearer local-beta-smoke"
        body = self.rfile.read(int(self.headers["Content-Length"]))
        digest = hashlib.sha256(body).hexdigest()
        assert self.headers["X-Capture-SHA256"] == digest
        capture = json.loads(gzip.decompress(body))
        calls.append((capture["capture_id"], digest))
        response = json.dumps({"ok": len(calls) > 1, "capture_id": capture["capture_id"], "sha256": digest}).encode()
        self.send_response(503 if len(calls) == 1 else 200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix="sf-beta-transport-") as directory:
        run = Path(directory)
        for child in project.iterdir():
            if child.name not in ("project.godot", ".git", ".godot"):
                (run / child.name).symlink_to(child, target_is_directory=child.is_dir())
        cache = Path(os.environ["SF_BETA_GODOT_CACHE"])
        (run / ".godot").symlink_to(cache, target_is_directory=True)
        config = (project / "project.godot").read_text().replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="BetaCaptureTransportChecks-' + run.name + '"')
        (run / "project.godot").write_text(config)
        env = dict(os.environ, SF_BETA_SMOKE_URL=f"http://127.0.0.1:{server.server_port}/v1")
        subprocess.run([os.environ["GODOT_BIN"], "--headless", "--path", str(run), "--script",
            "res://tools/beta_capture_transport_smoke_test.gd", "--", "--beta-capture"], env=env, check=True, timeout=150)
    assert len(calls) == 2 and calls[0] == calls[1], calls
    print("BETA_CAPTURE_TRANSPORT_RUNNER_PASS: identical recording retried")
finally:
    print("HTTP fixture requests:", len(calls))
    server.shutdown()
    server.server_close()
