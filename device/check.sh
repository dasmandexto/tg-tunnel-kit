#!/data/data/com.termux/files/usr/bin/bash
# Диагностика туннеля. Запускать в Termux: bash check.sh
# Ничего не меняет — только смотрит и печатает.

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
info() { printf '  ..   %s\n' "$1"; }

echo "== Termux / окружение =="
info "пользователь: $(whoami)   (это ваш логин для ssh)"
command -v sshd     >/dev/null && ok "sshd установлен"     || bad "sshd нет: pkg install openssh"
command -v autossh  >/dev/null && ok "autossh установлен"  || bad "autossh нет: pkg install autossh"
command -v sv       >/dev/null && ok "termux-services есть" || info "termux-services нет (pkg install termux-services)"

echo
echo "== sshd на телефоне =="
if ss -tnlp 2>/dev/null | grep -q ':8022'; then
  ok "слушает 8022"
else
  bad "8022 не слушается — запустите: sshd"
fi
info "кастомный порт в конфиге: $(grep -i '^Port' "$PREFIX/etc/ssh/sshd_config" 2>/dev/null || echo 'нет (значит 8022)')"

echo
echo "== ключ и config =="
[[ -f ~/.ssh/id_ed25519 ]]     && ok "приватный ключ на месте" || bad "нет ~/.ssh/id_ed25519: ssh-keygen -t ed25519"
[[ -f ~/.ssh/config ]]         && ok "~/.ssh/config есть"     || bad "нет ~/.ssh/config"
[[ -f ~/.ssh/authorized_keys ]] && {
  perm=$(stat -c '%a' ~/.ssh/authorized_keys)
  [[ "$perm" == "600" ]] && ok "authorized_keys права 600" || bad "authorized_keys права $perm (нужно 600)"
} || info "authorized_keys нет (нужен, только если входящие подключения К телефону)"

echo
echo "== autossh-процесс =="
if pgrep -a autossh >/dev/null 2>&1; then
  ok "autossh запущен:"
  pgrep -a autossh | sed 's/^/       /'
else
  bad "autossh не запущен — sv-enable autossh"
fi
command -v sv >/dev/null && info "sv status autossh: $(sv status autossh 2>/dev/null || echo 'сервис не зарегистрирован')"

echo
echo "== wake-lock =="
dumpsys power 2>/dev/null | grep -qi 'termux' && ok "Termux держит wake-lock" \
  || info "не видно wake-lock — выполните: termux-wake-lock"

echo
echo "== проверка VPS-профиля из ~/.ssh/config =="
if [[ -f ~/.ssh/config ]]; then
  ssh -G vps-tunnel 2>/dev/null | grep -E '^(hostname|user|port) ' | sed 's/^/       /' \
    || bad "профиль vps-tunnel не читается"
fi

echo
echo "== доступность VPS по сети =="
host=$(ssh -G vps-tunnel 2>/dev/null | awk '/^hostname /{print $2}')
port=$(ssh -G vps-tunnel 2>/dev/null | awk '/^port /{print $2}')
if [[ -n "${host:-}" ]]; then
  if nc -z -w5 "$host" "${port:-22}" 2>/dev/null; then
    ok "VPS $host:${port:-22} отвечает"
  else
    bad "VPS $host:${port:-22} недоступен (сеть/фаервол)"
  fi
fi

echo
echo "Подсказки:"
echo "  - туннель не виден снаружи → GatewayPorts и фаервол на VPS"
echo "  - рвётся после сна         → termux-wake-lock + «Без ограничений» в батарее"
echo "  - подробный лог ssh        → ssh -v -p <TUNNEL_PORT> <login>@<VPS>"
