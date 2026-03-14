import os, subprocess, json
from flask import Flask, request, render_template_string, redirect

app = Flask(__name__)
SESSIONS_ROOT = "/home/sessions"

LOGIN_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>Railway Secure Desktop</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { text-align:center; padding-top:100px; font-family:'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background:#121212; color:#e0e0e0; }
        .card { display:inline-block; background:#1e1e1e; padding:40px; border-radius:20px; width: 340px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); border: 1px solid #333; }
        h2 { margin-bottom: 25px; color: #007bff; }
        input { padding:14px; width:90%; margin-bottom:20px; border-radius:8px; border:1px solid #333; background:#2a2a2a; color:white; }
        button { padding:14px; width:100%; background:#007bff; color:white; border:none; border-radius:8px; cursor:pointer; font-weight:bold; transition: 0.3s; }
        button:hover { background:#0056b3; }
        .error { color:#ff4d4d; background: rgba(255, 77, 77, 0.1); padding: 10px; border-radius: 5px; margin-bottom: 20px; font-size: 14px; }
        .footer { color:#666; font-size:12px; margin-top:25px; line-height: 1.5; }
    </style>
</head>
<body>
    <div class="card">
        <h2>VNC Access</h2>
        {% if error %} <div class="error">{{ error }}</div> {% endif %}
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="Username Baru/Lama" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">MASUK DESKTOP</button>
        </form>
        <div class="footer">
            Sistem Keamanan: <br>
            <b>[IP Device Lock + Password]</b><br>
            Username akan dikunci pada login pertama.
        </div>
    </div>
</body>
</html>
'''

active_sessions = {}

@app.route('/')
def index():
    return render_template_string(LOGIN_HTML, error=request.args.get('error'))

@app.route('/login', methods=['POST'])
def login():
    user = request.form['username'].lower().strip()
    pwd = request.form['password'].strip()
    # Deteksi IP di belakang Proxy Railway
    user_ip = request.headers.get('X-Forwarded-For', request.remote_addr).split(',')[0].strip()

    if not user.isalnum() or len(pwd) < 4:
        return redirect("/?error=Username/Password tidak valid!")

    user_home = os.path.join(SESSIONS_ROOT, user)
    cred_file = os.path.join(user_home, ".access_lock")

    if not os.path.exists(user_home):
        # DAFTAR USER BARU
        os.makedirs(user_home)
        with open(cred_file, "w") as f:
            json.dump({"ip": user_ip, "password": pwd}, f)
        subprocess.run(["useradd", "-d", user_home, user], check=False)
        subprocess.run(["chown", "-R", f"{user}:{user}", user_home])
    else:
        # VALIDASI USER LAMA
        if os.path.exists(cred_file):
            with open(cred_file, "r") as f:
                data = json.load(f)
            if data['ip'] != user_ip:
                return redirect("/?error=Ditolak: Perangkat tidak dikenal!")
            if data['password'] != pwd:
                return redirect("/?error=Password salah!")

    # START SESSION
    if user not in active_sessions:
        port_idx = len(active_sessions) + 1
        vnc_port, web_port = 5900 + port_idx, 6080 + port_idx
        subprocess.run(f"su - {user} -c 'vncserver -kill :1'", shell=True, capture_output=True)
        # SecurityTypes None karena auth sudah di handle Flask
        subprocess.Popen(f"su - {user} -c 'vncserver -localhost no -SecurityTypes None :1'", shell=True)
        subprocess.Popen(f"websockify -D {web_port} localhost:{vnc_port}", shell=True)
        active_sessions[user] = web_port

    return redirect(f"http://{request.host.split(':')[0]}:{active_sessions[user]}/vnc.html")

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
