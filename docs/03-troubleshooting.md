# Диагностика: типовые ошибки и что они значат

Проверяйте по порядку: телефон → VPS → клиент.

---

## На телефоне

### `sshd: command not found`
Пакет не установлен.
```bash
pkg install openssh
```

### `sshd` запущен, но `ss -tnlp | grep 8022` пусто
- перезапустите: `pkill sshd; sshd`
- проверьте конфиг на кастомный порт: `grep -i '^Port' $PREFIX/etc/ssh/sshd_config`
- порт по умолчанию в Termux — **8022**, не 22.

### `Permission denied (publickey)`
- ключ клиента не попал в `~/.ssh/authorized_keys` на телефоне;
- неверные права: нужно `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys`;
- в `sshd_config` стоит `PubkeyAuthentication no` — исправьте на `yes`.

### `Permission denied (password)` при включённом `PasswordAuthentication no`
Ожидаемо: вы просите пароль, сервер его запретил. Используйте ключ.

### Туннель живёт минуту и умирает
Не выполнен `termux-wake-lock` или не отключена оптимизация батареи Android.
Проверьте: **Настройки → Приложения → Termux → Батарея → Без ограничений**.

### `Warning: remote port forwarding failed for listen port 2222`
Порт 2222 на VPS уже занят (часто — «завис» предыдущий туннель).
```bash
# на VPS:
sudo ss -tnlp | grep 2222
sudo pkill -f 'sshd: tunnel'
```

### autossh выходит сразу после старта
Не выставлен `AUTOSSH_GATETIME=0`. В Termux это обязательно.

---

## На VPS

### `sshd -T | grep -i allowtcpforwarding` → `no`
Правьте `/etc/ssh/sshd_config.d/10-tunnel.conf`, затем:
```bash
sudo sshd -t && sudo systemctl restart sshd
```

### Порт 2222 слушает только на 127.0.0.1
Это норма при `GatewayPorts no`. Либо заходите через `ssh -L`, либо ставьте
`GatewayPorts clientspecified` (и помните о рисках — см. `docs/02-alternatives.md`).

### `Permission denied (publickey)` для пользователя `tunnel`
- ключ телефона не в `/home/tunnel/.ssh/authorized_keys`;
- права: `chown -R tunnel:tunnel ~tunnel/.ssh`, `chmod 600 authorized_keys`.

### `User tunnel not allowed because shell /usr/sbin/nologin is not executable`
Это **не** ошибка для туннеля, но если сервер отказывает совсем — добавьте в
`sshd_config`:
```
Match User tunnel
    ForceCommand /bin/false
```
и уберите `nologin` из `passwd` для этой учётки.

### Не открывается порт снаружи
- фаервол: `sudo ufw status`, правило для 2222;
- облачная панель провайдера (security group) часто отдельная от ufw;
- `GatewayPorts` не включён.

---

## На клиенте

### `Connection refused` при `ssh -p 2222 login@vps`
Туннель не поднят. На телефоне: `pgrep -a autossh`, `sv status autossh`.
Если пусто — `sv-enable autossh` и `termux-wake-lock`.

### `Host key verification failed`
Сменился ключ хоста (частая ситуация после пересоздания VPS):
```bash
ssh-keygen -R '[<VPS_HOST>]:2222'
```

### Соединение есть, но «виснет» без приглашения
Вероятно, туннель ведёт на порт, где не sshd телефона. Проверьте на телефоне:
`ss -tnlp | grep 8022`, и что проброс `-R 2222:localhost:8022` указывает на 8022.

### Туннель пропадает при переключении Wi-Fi ↔ LTE
Нормально: меняется исходящий интерфейс. autossh поднимет заново; ускорить —
уменьшить `ServerAliveInterval` до 15 и добавить `AUTOSSH_POLL=15`.

---

## Быстрый чек-лист здоровья

```bash
# на телефоне
pgrep -a autossh
ss -tnlp | grep 8022
sv status autossh

# на VPS
sudo ss -tnlp | grep 2222
sshd -T | grep -E 'allowtcpforwarding|gatewayports'

# с клиента
ssh -v -p 2222 <PHONE_LOGIN>@<VPS_HOST>       # -v покажет, где именно спотыкается
```

`ssh -v` — главный инструмент: он печатает каждый шаг (DNS, TCP, key exchange,
аутентификация, запрос порта) и сразу показывает этап сбоя.
