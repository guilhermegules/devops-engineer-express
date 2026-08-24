from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import subprocess


class EnvHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path
        if path == '/conf/env':
            self._handle_list_env()
        elif path.startswith('/env/'):
            self._handle_set_env()
        else:
            self.send_response(404)
            self.end_headers()

    def _handle_list_env(self):
        env_vars = dict(os.environ)
        body = '\n'.join(f"{k}={v}" for k, v in env_vars.items())
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(body.encode())

    def _handle_set_env(self):
        path = self.path
        parts = path.split('/')
        if len(parts) >= 4:
            name = parts[2]
            value = parts[3]
            os.environ[name] = value
            subprocess.run(['export', f'{name}={value}'], shell=True)
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(f"Env var {name}={value} set".encode())
        else:
            self.send_response(400)
            self.end_headers()


if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), EnvHandler)
    print("Server running on http://0.0.0.0:8080")
    server.serve_forever()