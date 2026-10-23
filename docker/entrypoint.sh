#!/bin/bash
set -euo pipefail
cd /srv/canary

: "${DB_HOST:=db}" "${DB_USER:=canary}" "${DB_PASS:=canary}" "${DB_NAME:=canary}"
: "${SERVER_IP:=127.0.0.1}" "${BOT_PLAYERS_ONLINE:=100}"

# config.lua fica em volume (/srv/canary/config) para persistir edições manuais.
# As chaves abaixo vêm das variáveis de ambiente e são reaplicadas a cada subida
# (no CasaOS as variáveis são editadas pela interface); as demais chaves não são tocadas.
mkdir -p config
if [ ! -f config/config.lua ]; then
  cp config.lua.dist config/config.lua
  # Padrões para single player, só na criação (depois vale o que estiver no arquivo):
  # sem PvP, sem gangues de bots emboscando o jogador real e com quests de acesso liberadas
  # (free quests só valem para jogadores reais: bots não passam pelo onLogin).
  sed -i -E \
    -e 's|^(worldType\s*=\s*)"[a-z-]+"|\1"no-pvp"|' \
    -e 's|^(botGangTargetPlayers\s*=\s*)true|\1false|' \
    -e 's|^(toggleFreeQuest\s*=\s*)false|\1true|' \
    config/config.lua
fi
sed -i -E \
  -e "s|^(mysqlHost\s*=).*|\1 \"${DB_HOST}\"|" \
  -e "s|^(mysqlUser\s*=).*|\1 \"${DB_USER}\"|" \
  -e "s|^(mysqlPass\s*=).*|\1 \"${DB_PASS}\"|" \
  -e "s|^(mysqlDatabase\s*=).*|\1 \"${DB_NAME}\"|" \
  -e "s|^(ip\s*=).*|\1 \"${SERVER_IP}\"|" \
  -e "s|^(botPlayersOnline\s*=).*|\1 ${BOT_PLAYERS_ONLINE}|" \
  config/config.lua
ln -sf config/config.lua config.lua

echo "Aguardando o banco..."
until mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" --silent; do sleep 2; done


q() { mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -Nse "$1"; }

# Schema do Canary (só se ainda não existir)...
if [ -z "$(q "SHOW TABLES LIKE 'accounts'")" ]; then
  echo "Importando schema.sql..."
  mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < schema.sql
fi

# ...e seed dos bots (conta 65000), verificado separadamente para poder repetir se falhar.
if [ "$(q "SELECT COUNT(*) FROM accounts WHERE id=65000")" = "0" ]; then
  echo "Importando bots..."
  (cd database/bots && DB_HOST="$DB_HOST" DB_USER="$DB_USER" DB_PASS="$DB_PASS" DB_NAME="$DB_NAME" bash import.sh)
fi

# Tabelas que o fork usa mas não cria (idempotente; roda a cada subida para corrigir bancos antigos).
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /docker/bot_missing_tables.sql

exec ./canary
