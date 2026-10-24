#!/bin/bash
set -euo pipefail
cd /srv/canary

: "${DB_HOST:=db}" "${DB_USER:=canary}" "${DB_PASS:=canary}" "${DB_NAME:=canary}"
: "${SERVER_IP:=127.0.0.1}" "${BOT_PLAYERS_ONLINE:=100}"
# Versão do cliente gravada no MyAAC; acompanha o protocolo do servidor (Canary v3.6.1 = 15.11).
: "${MYAAC_CLIENT_VERSION:=1511}"
# Endereço que o MyAAC usa para consultar o status: o nome do serviço do servidor no compose.
: "${MYAAC_STATUS_IP:=canary}"

# config.lua fica em volume (/srv/canary/config) para persistir edições manuais.
# As chaves abaixo vêm das variáveis de ambiente e são reaplicadas a cada subida
# (no CasaOS as variáveis são editadas pela interface); as demais chaves não são tocadas.
mkdir -p config
if [ ! -f config/config.lua ]; then
  cp config.lua.dist config/config.lua
  # Padrões para single player, só na criação (depois vale o que estiver no arquivo):
  # - sem PvP e sem gangues de bots emboscando o jogador real;
  # - quests de acesso liberadas (só para jogadores reais: bots não passam pelo onLogin);
  # - premium grátis (não há quem pague) e viagens de barco/tapete sem custo;
  # - livestream em qualquer level (o padrão exige 200 para ser assistido);
  # - bosses com 70% da vida (pensados para times; aqui é você + bots);
  # - bots aceitam as ofertas do jogador no mercado a cada 5-15 min (padrão 15-45).
  sed -i -E \
    -e 's|^(worldType\s*=\s*)"[a-z-]+"|\1"no-pvp"|' \
    -e 's|^(botGangTargetPlayers\s*=\s*)true.*|\1false|' \
    -e 's|^(toggleFreeQuest\s*=\s*)false|\1true|' \
    -e 's|^(freePremium\s*=\s*)false|\1true|' \
    -e 's|^(toggleTravelsFree\s*=\s*)false|\1true|' \
    -e 's|^(livestreamCasterMinLevel\s*=\s*)[0-9]+|\10|' \
    -e 's|^(rateBossHealth\s*=\s*)[0-9.]+|\10.7|' \
    -e 's|^(botMarketAcceptIntervalMinSec\s*=\s*)[0-9]+|\1300|' \
    -e 's|^(botMarketAcceptIntervalMaxSec\s*=\s*)[0-9]+|\1900|' \
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

# Configurações do MyAAC que dependem deste empacotamento (a tabela só existe depois do instalador):
# - client: versão do cliente (usada no login.php e nas páginas);
# - status_ip: de onde o site consulta o status. O instalador grava 127.0.0.1, que dentro do
#   container web é ele mesmo; o servidor é alcançado pelo nome do serviço na rede do compose.
set_myaac() {
  if [ -n "$(q "SELECT id FROM myaac_settings WHERE name='core' AND \`key\`='$1'")" ]; then
    q "UPDATE myaac_settings SET value='$2' WHERE name='core' AND \`key\`='$1'"
  else
    q "INSERT INTO myaac_settings (name, \`key\`, value) VALUES ('core', '$1', '$2')"
  fi
}
if [ -n "$(q "SHOW TABLES LIKE 'myaac_settings'")" ]; then
  set_myaac client "${MYAAC_CLIENT_VERSION}"
  set_myaac status_ip "${MYAAC_STATUS_IP}"
fi

exec ./canary
