#!/bin/bash
set -e
# config.lua real é gerado pelo container canary no volume compartilhado.
until [ -f /srv/canary/config/config.lua ]; do echo "Aguardando config.lua..."; sleep 2; done
ln -sf /srv/canary/config/config.lua /srv/canary/config.lua

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
