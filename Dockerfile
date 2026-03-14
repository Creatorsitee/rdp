FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Update & Install Core Desktop & Dependencies
RUN apt update && apt install -y --no-install-recommends \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify \
    sudo xterm vim net-tools curl wget git tzdata dbus-x11 \
    python3 python3-pip python3-flask software-properties-common \
    gnupg apt-transport-https ca-certificates \
    && add-apt-repository ppa:mozillateam/ppa -y \
    && apt update && apt install -y firefox

# 2. Install Google Chrome (Versi Terbaru)
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
    && apt update && apt install -y google-chrome-stable

# 3. Install VS Code
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg \
    && install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg \
    && echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && rm -f packages.microsoft.gpg \
    && apt update && apt install -y code

# 4. Install Node.js & NPM (Versi 20.x LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt install -y nodejs

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup directory data (Wajib di-mount ke Railway Volume ke /home/sessions)
RUN mkdir -p /home/sessions
WORKDIR /app

COPY manager.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["./entrypoint.sh"]
