import os, subprocess, json, time, signal
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
        body { text-align:center; padding-top:100px; font-family:sans-serif; background:#121212; color:#e0e0e0; }
        .card { display:inline-block; background:#1e1e1e; padding:40px; border-radius:20px; width: 340px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); border: 1px solid #333; }
        h2 { color: #007bff; }
        input { padding:14px; width:90%; margin-bottom:20px; border-radius:8px; border:1px solid #333; background:#2a2a2a; color:white; }
        button { padding:14px; width:100%; background:#007bff; color:white; border:none; border-radius:8px; cursor:pointer; font-weight:bold; }
        .error { color:#ff4d4d; background: rgba(255, 77, 77, 0.1); padding: 10px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="card">
        <h2>VNC Access</h2>
        {% if error %} <div class="error">{{ error }}</div> {% endif %}
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">MASUK DESKTOP</button>
        </form>
    </div>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(LOGIN_HTML, error=request.args.get('error'))

@app.route('/login', methods=['POST'])
def login():
    user = request.form['username'].lower().strip()
    pwd = request.form['password'].strip()
    user_ip = request.headers.get('X-Forwarded-For', request.remote_addr).split(',')[0].strip()

    if not user.isalnum() or len(pwd) < 4:
        return redirect("/?error=Username/Password tidak valid!")

    user_home = os.path.join(SESSIONS_ROOT, user)
    cred_file = os.path.join(user_home, ".access_lock")

    # 1. VALIDASI DEVICE & PASSWORD
    if not os.path.exists(user_home):
        os.makedirs(user_home)
        with open(cred_file, "w") as f:
            json.dump({"ip": user_ip, "password": pwd}, f)
        subprocess.run(["useradd", "-d", user_home, user], check=False)
        subprocess.run(["chown", "-R", f"{user}:{user}", user_home])
    else:
        if os.path.exists(cred_file):
            with open(cred_file, "r") as f:
                data = json.load(f)
            if data['ip'] != user_ip:
                return redirect("/?error=Ditolak: Perangkat tidak dikenal!")
            if data['password'] != pwd:
                return redirect("/?error=Password salah!")

    # 2. PROSES PINDAH PORT (SWAP)
    # Jalankan VNC secara internal di port 5901
    subprocess.run(f"su - {user} -c 'vncserver -kill :1'", shell=True, capture_output=True)
    subprocess.Popen(f"su - {user} -c 'vncserver -localhost no -SecurityTypes None :1'", shell=True)
    
    # Tunggu sebentar biar VNC beneran up
    time.sleep(2)
    
    # Ambil alih port 8080 dengan Websockify (NoVNC)
    # Gunakan os.execv agar proses Flask berhenti dan diganti Websockify sepenuhnya
    os.execv('/usr/bin/websockify', ['websockify', '8080', 'localhost:5901', '--web', '/usr/share/novnc'])

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
