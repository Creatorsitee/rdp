FROM --platform=linux/amd64 ubuntu:24.04

# 1. Setup Environment
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
# Silakan ganti 'rahasia123' dengan password pilihan Anda
ENV VNC_PASSWORD=rahasia123 

RUN apt update && apt install -y --no-install-recommends \
    sudo curl wget gpg git xfce4 xfce4-goodies \
    tigervnc-standalone-server novnc websockify \
    dbus-x11 x11-xserver-utils x11-utils x11-apps \
    arc-theme papirus-icon-theme \
    vim nano net-tools locales \
    && locale-gen en_US.UTF-8

# 2. Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt update && apt install -y google-chrome-stable

# 3. Install VS Code
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && apt update && apt install -y code

# 4. Install Node.js 20.x LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt install -y nodejs

# 5. Firefox (Mozilla PPA)
RUN apt install -y software-properties-common && add-apt-repository ppa:mozillateam/ppa -y \
    && echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox \
    && echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox \
    && echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox \
    && apt update && apt install -y firefox

# 6. Konfigurasi Keamanan VNC (Set Password)
RUN mkdir -p /root/.vnc \
    && echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd \
    && chmod 600 /root/.vnc/passwd

# 7. Pengaturan Tema (Agar Tampilan Menu Bagus/Modern)
RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml \
    && echo '<?xml version="1.0" encoding="UTF-8"?><channel name="xsettings" version="1.0"><property name="Net" type="empty"><property name="ThemeName" type="string" value="Arc-Darker"/><property name="IconThemeName" type="string" value="Papirus"/></property></channel>' > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

EXPOSE 5901
EXPOSE 6080

# 8. Script Startup dengan Otentikasi
CMD bash -c "\
    vncserver -localhost no -geometry 1280x800 :1 && \
    openssl req -new -subj '/C=ID/ST=Jakarta/L=Jakarta/O=IT/CN=Railway' -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
