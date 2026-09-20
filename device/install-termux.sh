#!/data/data/com.termux/files/usr/bin/bash
# Установка tуннеля на телефоне (Termux).
# Запускать В TERMUX, от обычного пользователя (без sudo — его тут нет).
set -euo pipefail

# ---------- ЗАМЕНИТЕ ПЛЕЙСХОЛДЕРЫ ----------
VPS_HOST="${VPS_HOST:-your-vps.domain}"
VPS_PORT="${VPS_PORT:-22}"
TUNNEL_USER="${TUNNEL_USER:-tunnel}"
TUNNEL_PORT="${TUNNEL_PORT:-2222}"
# ------------------------------------------

echo "== 1/5: пакеты =="
pkg update -y
pkg install -y openssh autossh termux-services

echo "== 2/5: ключ =="
if [[ -f ~/.ssh/id_ed25519 ]]; then
  echo "ключ уже есть, не трогаю"
else
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -t ed25519 -N "" -C "device-tunnel" -f ~/.ssh/id_ed25519
fi

echo "== 3/5: ~/.ssh/config =="
cat > ~/.ssh/config <<EOF
Host vps-tunnel
    HostName ${VPS_HOST}
    User ${TUNNEL_USER}
    Port ${VPS_PORT}
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ExitOnForwardFailure yes
EOF
chmod 600 ~/.ssh/config

echo "== 4/5: сервис termux-services =="
SVC="\$PREFIX/var/service/autossh"
mkdir -p "${SVC}"
cat > "${SVC}/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
export AUTOSSH_GATETIME=0
export AUTOSSH_POLL=30
exec autossh -M 0 -N vps-tunnel -R ${TUNNEL_PORT}:localhost:8022
EOF
chmod +x "${SVC}/run"
echo "создан ${SVC}/run (пока не включён)"

echo "== 5/5: что осталось =="
cat <<EOF

1. Покажите ЭТОТ ключ и добавьте его на VPS в
     /home/${TUNNEL_USER}/.ssh/authorized_keys
   (вдохновляйтесь образцом vps/authorized_keys.example):
$(cat ~/.ssh/id_ed25519.pub)

2. Убедитесь, что sshd в Termux запущен:
     sshd && ss -tnlp | grep 8022

3. Включите туннель и запретите Android усыплять Termux:
     sv-enable autossh
     termux-wake-lock
   И в настройках Android: Приложения → Termux → Батарея → «Без ограничений».

4. Проверьте с VPS:
     ssh -p ${TUNNEL_PORT} \$(whoami)@localhost

Диагностика: bash check.sh
EOF
