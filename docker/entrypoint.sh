#!/bin/bash
set -euo pipefail
cd /srv/canary

: "${DB_HOST:=db}" "${DB_USER:=canary}" "${DB_PASS:=canary}" "${DB_NAME:=canary}"
: "${SERVER_IP:=127.0.0.1}" "${BOT_PLAYERS_ONLINE:=100}"
# Versão do cliente gravada no MyAAC; acompanha o protocolo do servidor (Canary v3.6.1 = 15.11).
: "${MYAAC_CLIENT_VERSION:=1511}"

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
    -e 's|^(botGangTargetPlayers\s*=\s*)true.*|\1false|' \
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

# Tabelas de runtime dos bots (só CREATE TABLE IF NOT EXISTS): a cada subida, para bancos antigos
# receberem tabelas novas do canary-bots.
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < database/bots/00_bot_schema.sql

# Bancos criados com o canary-bots-with-cast (v2026.09.01) ficaram em db_version 62 pela migração
# 62.lua do fork, que saiu da numeração do Canary. Volta uma vez para 56 para o Canary aplicar as
# migrações 57/58 do v3.6.1 (ambas checam se já foram aplicadas). Não roda de novo: depois disso a
# versão fica em 58 ou mais.
if [ "$(q "SELECT value FROM server_config WHERE config='db_version'")" = "62" ] \
   && [ ! -f data-otservbr-global/migrations/62.lua ]; then
  echo "db_version 62 (migração antiga do fork): voltando para 56 para aplicar as migrações do Canary."
  q "UPDATE server_config SET value='56' WHERE config='db_version'"
fi

# MyAAC: versão do cliente (usada no login.php e nas páginas). Só existe depois do instalador.
if [ -n "$(q "SHOW TABLES LIKE 'myaac_settings'")" ]; then
  if [ -n "$(q "SELECT id FROM myaac_settings WHERE name='core' AND \`key\`='client'")" ]; then
    q "UPDATE myaac_settings SET value='${MYAAC_CLIENT_VERSION}' WHERE name='core' AND \`key\`='client'"
  else
    q "INSERT INTO myaac_settings (name, \`key\`, value) VALUES ('core', 'client', '${MYAAC_CLIENT_VERSION}')"
  fi
fi

exec ./canary
