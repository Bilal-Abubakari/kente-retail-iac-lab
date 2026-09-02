#!/usr/bin/env python3
"""Kente Retail order-service — a deliberately tiny stand-in for the real thing.

It exists to prove the end-to-end pipeline: Terraform built the host, Ansible
configured it, and the per-environment config (including a Vault-managed DB
credential) was delivered here without any manual step. It reads all of its
configuration from the environment (systemd injects it via EnvironmentFile) and
serves a status page.

It never prints the DB password — only whether one was loaded — so the health
page itself can't leak the secret.
"""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ENV = os.environ.get("KENTE_ENV", "unknown")
PORT = int(os.environ.get("APP_PORT", "8080"))
DB_HOST = os.environ.get("DB_HOST", "")
DB_NAME = os.environ.get("DB_NAME", "")
DB_USER = os.environ.get("DB_USER", "")
DB_PASSWORD_LOADED = bool(os.environ.get("DB_PASSWORD"))


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, content_type="application/json"):
        payload = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, json.dumps({"status": "ok", "environment": ENV}))
            return
        status = {
            "service": "kente-order-service",
            "environment": ENV,
            "db_host": DB_HOST,
            "db_name": DB_NAME,
            "db_user": DB_USER,
            # The secret itself is never exposed — only proof it was delivered.
            "db_credential_loaded": DB_PASSWORD_LOADED,
        }
        self._send(200, json.dumps(status, indent=2) + "\n")

    def log_message(self, *args):
        pass  # keep the journal quiet


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
