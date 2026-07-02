#!/usr/bin/env python3
"""
NutriPlan – lokaler Proxy-Server
Starten: Doppelklick auf start.bat
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import json, os, socket, traceback

PORT = 8080
DIR  = os.path.dirname(os.path.abspath(__file__))
HF_HOST = 'router.huggingface.co'

try:
    import requests as _req
    USE_REQUESTS = True
except ImportError:
    USE_REQUESTS = False

def _udp_dns_resolve(hostname, dns_ip='8.8.8.8', dns_port=53):
    import struct, random
    trans_id = random.randint(0, 65535)
    header   = struct.pack('>HHHHHH', trans_id, 0x0100, 1, 0, 0, 0)
    question = b''.join(bytes([len(p)]) + p.encode() for p in hostname.split('.'))
    question += b'\x00' + struct.pack('>HH', 1, 1)
    packet   = header + question
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5)
    try:
        sock.sendto(packet, (dns_ip, dns_port))
        resp = sock.recv(512)
    finally:
        sock.close()
    offset = 12
    while resp[offset] != 0:
        offset += resp[offset] + 1
    offset += 5
    answer_count = struct.unpack('>H', resp[6:8])[0]
    for _ in range(answer_count):
        if resp[offset] & 0xC0 == 0xC0:
            offset += 2
        else:
            while resp[offset] != 0:
                offset += resp[offset] + 1
            offset += 1
        rtype, _, _, rdlen = struct.unpack('>HHIH', resp[offset:offset+10])
        offset += 10
        if rtype == 1 and rdlen == 4:
            return '.'.join(str(b) for b in resp[offset:offset+4])
        offset += rdlen
    return None


def _nslookup_resolve(hostname, dns_server=None):
    import subprocess, re
    cmd = ['nslookup', hostname]
    if dns_server:
        cmd.append(dns_server)
    label = 'nslookup({})'.format(dns_server or 'System')
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        print('  {} Ausgabe:\n{}'.format(label, r.stdout))
        all_ips = re.findall(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b', r.stdout)
        skip = {dns_server} if dns_server else set()
        candidates = [ip for ip in all_ips
                      if ip not in skip
                      and not ip.startswith('127.')
                      and not ip.startswith('192.168.')
                      and not ip.startswith('10.')
                      and not ip.startswith('172.16.')
                      and not ip.startswith('0.')]
        if candidates:
            print('  {}: {} -> {}'.format(label, hostname, candidates[0]))
            return candidates[0]
        print('  {}: keine verwertbare IP gefunden.'.format(label))
    except Exception as e:
        print('  {} fehlgeschlagen: {}'.format(label, e))
    return None


def _doh_via_ip_resolve(hostname):
    import urllib.request, ssl
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode    = ssl.CERT_NONE
    endpoints = [
        ('Cloudflare-IP', 'https://1.1.1.1/dns-query?name={}&type=A'.format(hostname)),
        ('Google-IP',     'https://8.8.8.8/resolve?name={}&type=A'.format(hostname)),
    ]
    for name, url in endpoints:
        try:
            req = urllib.request.Request(url, headers={'Accept': 'application/dns-json'})
            with urllib.request.urlopen(req, timeout=8, context=ctx) as r:
                data = json.loads(r.read())
            for a in data.get('Answer', []):
                if a.get('type') == 1:
                    ip = a.get('data', '').strip()
                    if ip:
                        print('  DoH-IP ({}): {} -> {}'.format(name, hostname, ip))
                        return ip
        except Exception as e:
            print('  DoH-IP {} fehlgeschlagen: {}'.format(name, e))
    return None


def _dnspython_resolve(hostname):
    try:
        import dns.resolver
        resolver = dns.resolver.Resolver(configure=False)
        resolver.nameservers = ['8.8.8.8', '1.1.1.1']
        resolver.timeout = 5
        resolver.lifetime = 10
        try:
            answers = resolver.resolve(hostname, 'A')
            ip = answers[0].to_text()
            print('  dnspython IPv4: {} -> {}'.format(hostname, ip))
            return ('ipv4', ip)
        except Exception:
            pass
        try:
            answers = resolver.resolve(hostname, 'AAAA')
            ip = answers[0].to_text()
            print('  dnspython IPv6: {} -> {}'.format(hostname, ip))
            return ('ipv6', ip)
        except Exception as e:
            print('  dnspython IPv6 fehlgeschlagen: {}'.format(e))
        try:
            answers = resolver.resolve(hostname, 'HTTPS')
            for rdata in answers:
                s = rdata.to_text()
                print('  dnspython HTTPS-Record: {}'.format(s))
                import re
                m = re.search(r'ipv4hint=([\d.,]+)', s)
                if m:
                    ip = m.group(1).split(',')[0].strip()
                    print('  dnspython HTTPS ipv4hint: {} -> {}'.format(hostname, ip))
                    return ('ipv4', ip)
                m = re.search(r'ipv6hint=([0-9a-f:,]+)', s)
                if m:
                    ip = m.group(1).split(',')[0].strip()
                    print('  dnspython HTTPS ipv6hint: {} -> {}'.format(hostname, ip))
                    return ('ipv6', ip)
        except Exception as e:
            print('  dnspython HTTPS-Record fehlgeschlagen: {}'.format(e))
    except ImportError:
        print('  dnspython nicht installiert - bitte start.bat neu starten')
    except Exception as e:
        print('  dnspython fehlgeschlagen: {}'.format(e))
    return None


def _patch_dns():
    try:
        socket.gethostbyname(HF_HOST)
        print('  DNS: System-DNS funktioniert')
        return
    except Exception:
        pass

    print('  DNS: System-DNS blockiert {} - versuche Bypass ...'.format(HF_HOST))
    result = _dnspython_resolve(HF_HOST)

    if not result:
        print('  DNS-Aufloesung fehlgeschlagen. Pruefe Antivirus/Firewall.')
        return

    proto, ip = result
    _orig = socket.getaddrinfo
    if proto == 'ipv6':
        def _patched(host, port, family=0, type=0, proto=0, flags=0):
            if host == HF_HOST:
                return [(socket.AF_INET6, socket.SOCK_STREAM, 6, '', (ip, port or 443, 0, 0))]
            return _orig(host, port, family, type, proto, flags)
    else:
        def _patched(host, port, family=0, type=0, proto=0, flags=0):
            if host == HF_HOST:
                return [(socket.AF_INET, socket.SOCK_STREAM, 6, '', (ip, port or 443))]
            return _orig(host, port, family, type, proto, flags)
    socket.getaddrinfo = _patched
    print('  DNS-Bypass aktiv ({}) OK'.format(proto.upper()))


_patch_dns()


def hf_call_curl(token, payload):
    import subprocess, tempfile, os
    url = 'https://{}/v1/chat/completions'.format(HF_HOST)
    body_str = json.dumps(payload)

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as f:
        f.write(body_str)
        tmpfile = f.name

    try:
        cmd = [
            'curl.exe', '-s', '-k',
            '--doh-url', 'https://cloudflare-dns.com/dns-query',
            '-X', 'POST', url,
            '-H', 'Authorization: Bearer {}'.format(token),
            '-H', 'Content-Type: application/json',
            '--data', '@{}'.format(tmpfile),
            '--max-time', '120',
            '-w', '\n__STATUS__%{http_code}',
        ]
        r = subprocess.run(cmd, capture_output=True, timeout=125)
        out = r.stdout.decode('utf-8', errors='replace')
        stderr = r.stderr.decode('utf-8', errors='replace')
        if '__STATUS__' in out:
            body_part, status = out.rsplit('__STATUS__', 1)
            code = int(status.strip())
            if code == 0:
                print('  curl Status 0 - Verbindungsfehler.')
                print('  curl stderr: {}'.format(stderr[:400]))
                raise Exception('curl Verbindungsfehler: {}'.format(stderr[:300]))
            print('  curl Status {}'.format(code))
            return code, body_part.encode('utf-8')
        raise Exception('curl fehlgeschlagen (exit {}): {}'.format(r.returncode, stderr[:300]))
    finally:
        try:
            os.unlink(tmpfile)
        except Exception:
            pass


def hf_call(token, payload):
    url     = 'https://{}/v1/chat/completions'.format(HF_HOST)
    headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer {}'.format(token)}
    body    = json.dumps(payload).encode('utf-8')

    try:
        return hf_call_curl(token, payload)
    except Exception as curl_err:
        print('  curl fehlgeschlagen ({}) - Fallback auf requests ...'.format(curl_err))

    if USE_REQUESTS:
        r = _req.post(url, data=body, headers=headers, timeout=120, verify=False)
        return r.status_code, r.content
    else:
        import urllib.request, urllib.error
        req = urllib.request.Request(url, data=body, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return 200, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()


class Handler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        status = args[1] if len(args) > 1 else ''
        print('  [{:6}] {:<22} {}'.format(self.command, self.path, status))

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        path = self.path.split('?')[0]
        if path == '/ping':
            self._json_response(200, b'{"ok":true}')
            return
        fp = os.path.join(DIR, 'index.html') if path in ('/', '/index.html') \
             else os.path.join(DIR, path.lstrip('/'))
        try:
            with open(fp, 'rb') as f:
                data = f.read()
            self.send_response(200)
            if fp.endswith('.html'):
                self.send_header('Content-Type', 'text/html; charset=utf-8')
            elif fp.endswith('.json'):
                self.send_header('Content-Type', 'application/json; charset=utf-8')
            elif fp.endswith('.js'):
                self.send_header('Content-Type', 'application/javascript; charset=utf-8')
            elif fp.endswith('.png'):
                self.send_header('Content-Type', 'image/png')
            self.end_headers()
            self.wfile.write(data)
        except FileNotFoundError:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found')

    def do_POST(self):
        try:
            if self.path != '/api/hf':
                self.send_response(404)
                self.end_headers()
                return

            length = int(self.headers.get('Content-Length', 0))
            raw    = self.rfile.read(length)
            data   = json.loads(raw)
            token  = data.pop('_token', '').strip()

            if not token:
                self._json_response(400,
                    json.dumps({'error': 'Kein HuggingFace-Token angegeben.'}).encode())
                return

            print('  HF Modell: {}'.format(data.get('model', '?')))

            try:
                code, result = hf_call(token, data)
                print('  {}  Status {}  ({} Bytes)'.format(
                    'OK' if code == 200 else 'ERR', code, len(result)))
                self._json_response(code, result)
            except Exception as e:
                print('  HF-Fehler: {}'.format(e))
                traceback.print_exc()
                self._json_response(500, json.dumps({'error': str(e)}).encode())

        except Exception as e:
            print('  Server-Fehler: {}'.format(e))
            traceback.print_exc()
            try:
                self._json_response(500, json.dumps({'error': str(e)}).encode())
            except Exception:
                pass

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin',  '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def _json_response(self, code, body):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self._cors()
        self.end_headers()
        self.wfile.write(body)


class ThreadedServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


if __name__ == '__main__':
    if USE_REQUESTS:
        import urllib3
        urllib3.disable_warnings()

    server = ThreadedServer(('0.0.0.0', PORT), Handler)
    print()
    print('  NutriPlan laeuft auf  http://127.0.0.1:{}'.format(PORT))
    import socket as _sock
    try:
        s = _sock.socket(_sock.AF_INET, _sock.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        local_ip = s.getsockname()[0]
        s.close()
        print('  iPhone/iPad:  http://{}:{}'.format(local_ip, PORT))
        print('  (iPhone muss im selben WLAN sein)')
    except Exception:
        print('  iPhone: IP-Adresse unbekannt - bitte manuell pruefen')
    print('  Browser: http://127.0.0.1:{}'.format(PORT))
    print('  Beenden: Strg+C')
    print()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nServer gestoppt.')
