# Фаервол на VPS

Открывать нужно **только** порт туннеля (в комплекте — `2222/tcp`).
Порт `22` (SSH самого VPS) оставьте как есть, порт телефона (`8022`) наружу не выставляется.

## ufw

```bash
sudo ufw allow 22/tcp        # SSH на VPS
sudo ufw allow 2222/tcp      # туннель к телефону
sudo ufw enable
sudo ufw status verbose
```

## ВАЖНО: облачная панель провайдера

У Hetzner, DigitalOcean, AWS, Oracle и др. есть **свой** фаервол
(security group / firewall rules), независимый от ufw. Если порт не открыт там,
`sudo ss -tnlp | grep 2222` покажет «LISTEN», а снаружи всё равно будет таймаут.

Проверка снаружи:

```bash
nc -vz <VPS_HOST> 2222
```

## Рекомендация вместо открытого порта

Если не нужен прямой доступ, оставьте `GatewayPorts no` и заходите через jump-host —
тогда порт 2222 вообще не виден из интернета:

```bash
ssh -L 8022:localhost:2222 tunnel@<VPS_HOST>     # одно окно держится
ssh -p 8022 <PHONE_LOGIN>@localhost              # в другом терминале
```

## Дополнительная защита (по желанию)

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

fail2ban при `GatewayPorts clientspecified` заметит перебор на порту 2222 и
забанит IP. Правило для SSH уже есть в стандартной поставке.
