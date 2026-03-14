FROM --platform=linux/amd64 ubuntu:24.04

# 1. Environment Dasar
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:1 \
    HOME=/root \
    USER=root

# 2. Instalasi Paket Sistem & Desktop (Digabung untuk efisiensi)
RUN apt update && apt install -y --no-install-recommends \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    sudo xterm vim net-tools curl wget git \
    dbus-x11 x11-utils x11-xserver-utils \
    software-properties-common \
    python3-pip nodejs npm \
    htop screen unzip zip \
    ca-certificates build-essential && \
    apt clean && rm -rf /var/lib/apt/lists/*

# 3. Instalasi Firefox (Versi Native .deb agar stabil di Docker)
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' > /etc/apt/preferences.d/mozilla-firefox && \
    apt update && apt install -y firefox

# 4. Setup Node.js Auth Proxy (Web Login Interface)
WORKDIR /app
RUN npm install express express-session body-parser http-proxy-middleware

RUN echo "const express = require('express'); \
const session = require('express-session'); \
const bodyParser = require('body-parser'); \
const { createProxyMiddleware } = require('http-proxy-middleware'); \
const app = express(); \
const port = process.env.PORT || 6080; \
const USERNAME = process.env.VNC_USER || 'admin'; \
const PASSWORD = process.env.VNC_PASS || 'admin123'; \
const htmlContent = \` \
<!DOCTYPE html><html lang='id'><head><title>Cloud VPS Desktop</title><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1'> \
<style> \
  body{background:#0f172a;color:#f8fafc;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;font-family:sans-serif} \
  .card{background:#1e293b;padding:2.5rem;border-radius:12px;box-shadow:0 20px 25px -5px rgba(0,0,0,0.5);width:320px;text-align:center;border:1px solid #334155} \
  input{width:100%;padding:12px;margin:10px 0;border-radius:6px;border:1px solid #475569;background:#0f172a;color:white;box-sizing:border-box;outline:none} \
  input:focus{border-color:#38bdf8} \
  button{width:100%;padding:12px;background:#0284c7;color:white;border:none;border-radius:6px;cursor:pointer;font-weight:bold;margin-top:10px} \
  button:hover{background:#0369a1} \
  h2{margin-top:0;font-weight:300;letter-spacing:1px} \
</style></head> \
<body><div class='card'><h2>VPS LOGIN</h2><form method='POST' action='/login'> \
<input type='text' name='username' placeholder='Username' required> \
<input type='password' name='password' placeholder='Password' required> \
<button type='submit'>MASUK</button></form></div></body></html>\`; \
app.use(bodyParser.urlencoded({ extended: true })); \
app.use(session({ secret: 'vnc-secret-key', resave: false, saveUninitialized: true })); \
app.post('/login', (req, res) => { \
    if (req.body.username === USERNAME && req.body.password === PASSWORD) { \
        req.session.authenticated = true; res.redirect('/'); \
    } else { res.send('Akses Ditolak! <a href=\"/login\">Kembali</a>'); } \
}); \
app.get('/login', (req, res) => res.send(htmlContent)); \
app.use((req, res, next) => { \
    if (req.session.authenticated || req.path === '/login') next(); \
    else res.redirect('/login'); \
}); \
app.use('/', createProxyMiddleware({ target: 'http://127.0.0.1:6081', ws: true })); \
app.listen(port, '0.0.0.0');" > server.js

# 5. Script Eksekusi Otomatis (Fix Display & DBus)
RUN echo '#!/bin/bash\n\
rm -rf /tmp/.X11-unix /tmp/.X*-lock\n\
mkdir -p ~/.vnc && echo "vncpass123" | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd\n\
dbus-daemon --system --fork > /dev/null 2>&1\n\
vncserver -kill :1 > /dev/null 2>&1 || true\n\
vncserver -localhost no -SecurityTypes VncAuth -PasswordFile ~/.vnc/passwd -geometry 1280x800 :1\n\
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 127.0.0.1:6081 &\n\
node server.js' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

EXPOSE 6080

CMD ["/app/entrypoint.sh"]
