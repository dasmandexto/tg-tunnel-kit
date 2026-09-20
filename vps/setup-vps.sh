#!/usr/bin/env bash
# Настройка VPS для приёма SSH-туннеля от вашего телефона.
# Запускать на VPS: sudo bash setup-vps.sh
# Idempotent: повторный запуск ничего не ломает.
set -euo pipefail

# ---------- ЗАМЕНИТЕ ПЛЕЙСХОЛДЕРЫ ----------
TUNNEL_USER="${TUNNEL_USER:-tunnel}"        # служебный пользователь
TUNNEL_PORT="${TUNNEL_PORT:-2222}"          # порт, ведущий к телефону
SSHD_SNIPPET="/etc/ssh/sshd_config.d/10-tunnel.conf"
# ------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите через sudo." >&2
  exit 1
fi

echo "== 1/5: пользователь ${TUNNEL_USER} =="
if id "${TUNNEL_USER}" &>/dev/null; then
  echo "уже существует"
else
  useradd -m -s /usr/sbin/nologin "${TUNNEL_USER}"
  echo "создан"
fi

echo "== 2/5: каталог ключей =="
install -d -m 700 -o "${TUNNEL_USER}" -g "${TUNNEL_USER}" "/home/${TUNNEL_USER}/.ssh"
touch "/home/${TUNNEL_USER}/.ssh/authorized_keys"
chown "${TUNNEL_USER}:${TUNNEL_USER}" "/home/${TUNNEL_USER}/.ssh/authorized_keys"
chmod 600 "/home/${TUNNEL_USER}/.ssh/authorized_keys"
echo "готово: /home/${TUNNEL_USER}/.ssh/authorized_keys"

echo "== 3/5: sshd (AllowTcpForwarding / GatewayPorts) =="
mkdir -p /etc/ssh/sshd_config.d
cat > "${SSHD_SNIPPET}" <<EOF
# Добавлено tg-tunnel-kit. Проброс портов для пользователя туннеля.
AllowTcpForwarding yes
# clientspecified: порт открывается на интерфейсах, которые назовёт клиент.
# Замените на "no", если хотите доступ только через ssh -L (безопаснее).
GatewayPorts clientspecified
EOF
if sshd -t; then
  systemctl restart sshd
  echo "sshd перезапущен"
else
  echo "КОНФИГ С ОШИБКОЙ — откатываю ${SSHD_SNIPPET}" >&2
  rm -f "${SSHD_SNIPPET}"
  exit 1
fi

echo "== 4/5: фаервол =="
if command -v ufw &>/dev/null; then
  ufw allow "${TUNNEL_PORT}/tcp" || true
  echo "ufw: разрешён ${TUNNEL_PORT}/tcp (не забудьте про панель провайдера!)"
else
  echo "ufw нет. Откройте ${TUNNEL_PORT}/tcp вручную (iptables / панель хостинга)."
fi

echo "== 5/5: что осталось сделать =="
cat <<EOF

Готово. Дальше:

1. С телефона покажите публичный ключ:   cat ~/.ssh/id_ed25519.pub
2. Вставьте его на VPS в файл:
     /home/${TUNNEL_USER}/.ssh/authorized_keys
   Ограничив строку префиксом (образец — vps/authorized_keys.example):
     restrict,port-forwarding,permitlisten="${TUNNEL_PORT}" <ключ> device-tunnel
3. С телефона поднимите туннель:
     autossh -M 0 -N vps-tunnel -R ${TUNNEL_PORT}:localhost:8022
4. Проверьте с VPS:
     ssh -p ${TUNNEL_PORT} <PHONE_LOGIN>@localhost     # PHONE_LOGIN = whoami в Termux

Проверка настроек sshd:  sshd -T | grep -E 'allowtcpforwarding|gatewayports'
EOF
