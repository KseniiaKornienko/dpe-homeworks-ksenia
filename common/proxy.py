import base64
import hmac
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import ssl
import threading
from pathlib import Path
from settings import BASE, CONFIG, NODES, web_endpoints

ENDPOINTS = web_endpoints()
HOP_HEADERS = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
               "te", "trailer", "transfer-encoding", "upgrade", "content-length"}


def nominated_hop_headers(headers):
    return {name.strip().lower() for name in headers.get("Connection", "").split(",") if name.strip()}


def rewrite_links(data, public_host):
    for endpoint in ENDPOINTS.values():
        node = NODES[endpoint["role"]]
        for host in (node["host"], node["ip"]):
            old = f"http://{host}:{endpoint['port']}".encode()
            new = f"https://{public_host}:{endpoint['external_port']}".encode()
            data = data.replace(old, new)
    return data


def handler_for(endpoint, secret):
    expected = "Basic " + base64.b64encode((secret["username"] + ":" + secret["password"]).encode()).decode()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            print(f"{endpoint['external_port']} {self.command}", flush=True)

        def do_GET(self):
            if not hmac.compare_digest(self.headers.get("Authorization", ""), expected):
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Basic realm="ksenia-homework"')
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            request_host = self.headers.get("Host", "").partition(":")[0].lower()
            display_host = request_host if request_host in ("localhost", "127.0.0.1") else CONFIG["public_host"]
            upstream = http.client.HTTPConnection(endpoint["host"], endpoint["port"], timeout=30)
            try:
                request_hops = HOP_HEADERS | nominated_hop_headers(self.headers)
                headers = {k: v for k, v in self.headers.items()
                           if k.lower() not in request_hops | {"authorization", "host", "accept-encoding"}}
                headers["Host"] = f"{endpoint['host']}:{endpoint['port']}"
                upstream.request(self.command, self.path, headers=headers)
                response = upstream.getresponse()
                body = response.read()
                content_type = response.getheader("Content-Type", "")
                if self.command != "HEAD" and any(t in content_type for t in ("text/", "json", "javascript")):
                    body = rewrite_links(body, display_host)
                self.send_response(response.status)
                response_hops = HOP_HEADERS | nominated_hop_headers(response.headers)
                for key, value in response.getheaders():
                    if key.lower() in response_hops:
                        continue
                    if key.lower() == "location":
                        value = rewrite_links(value.encode(), display_host).decode()
                    self.send_header(key, value)
                length = response.getheader("Content-Length", "0") if self.command == "HEAD" else str(len(body))
                self.send_header("Content-Length", length)
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(body)
            except (OSError, http.client.HTTPException):
                self.send_error(502, "Upstream service unavailable")
            finally:
                upstream.close()

        do_HEAD = do_GET

        def do_POST(self):
            self.send_error(405, "Read-only proxy")

        do_PUT = do_POST
        do_DELETE = do_POST
        do_PATCH = do_POST
        do_OPTIONS = do_POST

    return Handler


def serve():
    private = Path(BASE) / "conf/hw2/web"
    secret = json.loads((private / "credentials.json").read_text())
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(private / "server.crt", private / "server.key")
    servers = []
    try:
        for endpoint in ENDPOINTS.values():
            server = ThreadingHTTPServer(("0.0.0.0", endpoint["external_port"]), handler_for(endpoint, secret))
            server.socket = context.wrap_socket(server.socket, server_side=True)
            servers.append(server)
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        ready = Path(BASE) / "pids/hw2/web-proxy.ready"
        ready.write_text(str(os.getpid()) + "\n")
        print("All 11 HTTPS web interfaces are listening", flush=True)
        threading.Event().wait()
    finally:
        for server in servers:
            server.server_close()


if __name__ == "__main__":
    serve()
