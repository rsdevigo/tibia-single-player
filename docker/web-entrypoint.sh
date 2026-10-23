#!/bin/bash
set -e
# config.lua real é gerado pelo container canary no volume compartilhado.
until [ -f /srv/canary/config/config.lua ]; do echo "Aguardando config.lua..."; sleep 2; done
ln -sf /srv/canary/config/config.lua /srv/canary/config.lua

# O instalador do MyAAC só aceita IPs exatos listados em install/ip.txt (sem faixas).
# No Docker o cliente nunca chega como 127.0.0.1, então a lista vem de MYAAC_INSTALL_IPS.
if [ -d /var/www/html/install ]; then
  printf '127.0.0.1\n::1\n' > /var/www/html/install/ip.txt
  for ip in ${MYAAC_INSTALL_IPS:-}; do echo "$ip" >> /var/www/html/install/ip.txt; done
fi

# Persistência do config.local.php (gerado pelo instalador do MyAAC): cópia de backup em /persist,
# restaurada na subida. Sem symlink: o Apache precisa poder reescrever o arquivo.
mkdir -p /persist
[ -f /persist/config.local.php ] && cp /persist/config.local.php /var/www/html/config.local.php
chown -R www-data:www-data /var/www/html /persist
(while true; do
   f=/var/www/html/config.local.php
   if [ -f "$f" ] && ! cmp -s "$f" /persist/config.local.php; then cp "$f" /persist/config.local.php; fi
   sleep 5
 done) &

exec docker-php-entrypoint "$@"
