#!/usr/bin/env python3
"""Serve the disconnected preview on loopback, exposing only its own directory."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8766)
args = parser.parse_args()
root = Path(__file__).resolve().parent
class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")
        super().end_headers()
    def list_directory(self, path):
        self.send_error(404)
        return None

server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(PreviewHandler, directory=str(root)))
print(f'Swarmfront Team Console: http://127.0.0.1:{args.port}', flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
