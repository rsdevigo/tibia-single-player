# AGENTS.md

## Objetivo
Empacotar o servidor [rsdevigo/canary-bots](https://github.com/rsdevigo/canary-bots) (branch `canary-3.6.1`)
em Docker para rodar no CasaOS, como servidor local de Tibia single player. Ele é um fork do
[canary-bots-with-cast](https://github.com/1LineAtaTime/canary-bots-with-cast) (OpenTibiaBR Canary + jogadores-bot)
com merge do Canary **v3.6.1 (cliente 15.11)** e o cast removido em favor do livestream do Canary.

Este repositório **não contém o código do servidor**: só o empacotamento (Dockerfile, compose, entrypoint).
Mudanças no jogo/servidor vão para o `rsdevigo/canary-bots`; o release dele (tag `v*`, workflow `release.yml`)
publica `canary`, `libbot_engine.so` e `canary-bots-runtime-<tag>.tar.gz`, que o `Dockerfile` daqui baixa.

## Arquitetura
- `Dockerfile` — baixa do release `CANARY_BOTS_REPO`/`CANARY_BOTS_VERSION` o `canary`, `libbot_engine.so` e o tarball
  de runtime, mais o mapa `otservbr.otbm` do Canary v3.6.1 (é o mesmo arquivo desde a v3.4.1: o release do Canary
  copia o mapa do anterior; mudam só house/monster/npc.xml, que vêm no tarball). Base `ubuntu:24.04`: os binários são
  compilados nela (GCC 13) e só dependem de libc/libstdc++ (o resto é estático, via vcpkg).
- `docker/entrypoint.sh` — gera `config.lua` na primeira vez e reaplica a cada subida as chaves vindas do ambiente
  (`mysql*`, `ip`, `botPlayersOnline`), espera o MariaDB, importa `schema.sql` + `database/bots/import.sh` se o banco
  estiver vazio, aplica `database/bots/00_bot_schema.sql` a cada subida (só `CREATE TABLE IF NOT EXISTS`), corrige
  uma vez o `db_version` de bancos antigos (62 → 56, ver abaixo), grava `core.client` no MyAAC e executa `./canary`.
- Padrões single player aplicados só ao criar o `config.lua`: `worldType = "no-pvp"`, `botGangTargetPlayers = false`
  e `toggleFreeQuest = true` (free quests só valem para jogadores reais: bots entram por `internalPlaceCreature` e não
  disparam `onLogin`).
- `docker/scripts/trade_area.lua` (copiado para `data-otservbr-global/scripts/custom/`): `!trade` leva à área de NPCs
  de troca do mapa custom (~995,1030,6, sem acesso pelo mapa principal) e `!temple` volta ao templo.
- `docker-compose.yml` — serviços `db` (MariaDB 10.11, utf8mb3), `canary` e `web`.
- `.env.example` — variáveis; copie para `.env`.

## Fatos do servidor (rsdevigo/canary-bots)
- Banco: MySQL/MariaDB, charset `utf8mb3`, banco `canary`. `schema.sql` deixa o banco na versão 58 (Canary v3.6.1).
- Tabelas dos bots ficam em `database/bots/00_bot_schema.sql`, fora da numeração de migrações do Canary (a antiga
  `62.lua` do fork colidiria com as futuras do upstream). Bancos criados com o fork antigo estão em `db_version` 62:
  o entrypoint volta para 56 uma vez, e o Canary reaplica 57/58 (idempotentes).
- `libbot_engine.so` deve ficar no mesmo diretório de `canary`.
- `config.lua` vem de `config.lua.dist`; chaves `mysql*`, `ip`, `botPlayersOnline` (padrão 500). Chaves `bot*`
  novas/renomeadas exigem rebuild do fork; valores mudam com `/cavebot _global reloadconfig`.
- Conta admin padrão `@god` (senha padrão publicada no README/release upstream — **trocar após o 1º login**).
- Livestream (do Canary): o jogador transmite com `!livestream on` (senha opcional com `!livestream password, ...`);
  o espectador loga com a conta `@livestream` e a senha da transmissão. Bots não podem ser assistidos.
- Cliente: OTClient Redemption, **protocolo 1511**; ver `docs/client-README.md` (cópia do README do fork).
- Portas Canary: 7171 (login) e 7172 (game). O login do cliente passa pelo MyAAC (serviço `web`, `WEB_PORT`).

## Pontos em aberto / não verificados
- Não testado com o cliente 15.11: login, jogo, `/party` com bots, livestream via `login.php`.
- Contas de jogador: criar pelo MyAAC (site).
- Migração de um banco existente (fork antigo → v3.6.1) não foi testada com dados reais: fazer backup antes.

## Convenções
- Responder e comentar em português (pt-BR).
- Nunca commitar `.env` ou `data/`.
- Mudou a versão do servidor? Crie a tag no `rsdevigo/canary-bots`, espere o release e altere `CANARY_BOTS_VERSION`
  (o nome do tarball segue `canary-bots-runtime-<versão>.tar.gz`).
- Testar com `docker compose build && docker compose up` e acompanhar `docker compose logs -f canary`.

## Deploy no CasaOS
O Custom Install do CasaOS não faz `build:` nem lê `.env`, por isso há um compose próprio em `casaos/docker-compose.yml`.
- `.github/workflows/build.yml` publica `ghcr.io/rsdevigo/tibia-single-player` e `-web` (`:latest` no main, `:vX` em tags, só amd64).
  Os pacotes do GHCR nascem privados: tornar públicos uma vez em GitHub → Packages → Package settings.
- Instalar: Apps → Custom Install → Import, colar `casaos/docker-compose.yml`, trocar `SERVER_IP` e senhas (DB_PASS = MARIADB_PASSWORD).
- Variáveis editadas depois na interface: `SERVER_IP`, `BOT_PLAYERS_ONLINE`, `DB_*` e `MYAAC_INSTALL_IPS` valem na próxima subida
  (o entrypoint reaplica essas chaves no `config.lua`). `MARIADB_*` só valem na 1ª inicialização do banco.
- Atualizar: novo push/tag gera imagem; no CasaOS, atualizar o app (ou trocar a tag da imagem).
- Ícone: `casaos/icon.png` servido via jsDelivr.
- Alternativa sem registry: clonar no CasaOS e `docker compose up -d --build` com `.env` (`DATA_DIR=/DATA/AppData/tibia-single-player`).

## MyAAC (serviço `web`)
- `Dockerfile.web`: `php:8.2-apache` + MyAAC `MYAAC_VERSION` (1.9.5) + `login.php` e `plugins/` (worldmap) clonados do
  `rsdevigo/canary-bots` na tag `CANARY_BOTS_VERSION`. O `login.php` trata a conta `@livestream` (nenhuma versão do
  MyAAC faz isso: o livestream do Canary só responde no login antigo pela porta 7171).
- O cliente OTClient faz login por HTTP (`login.php`, protocolo 1511, `httpLogin = true`), então o `web` é **necessário**, não opcional.
- `core.client` do MyAAC (versão do cliente) é gravado pelo entrypoint do `canary` a cada subida (`MYAAC_CLIENT_VERSION`, padrão 1511).
- Porta: `WEB_PORT` (padrão 8080 → 80 do container). No `init.lua` do cliente use `http://SERVER_IP:8080/login.php`, porta 8080 (ver `docs/init.lua.example`).
- Primeiro acesso: abrir `http://SERVER_IP:8080/install`, informar servidor `/srv/canary`, banco `db` / `canary` / usuário e senha do `.env`.
- Instalador do MyAAC só aceita IPs exatos de `install/ip.txt`; o `web-entrypoint.sh` o regera a cada subida com localhost + `MYAAC_INSTALL_IPS`. Descobrir o IP visto pelo Apache em `docker compose logs web` (1ª coluna do access log).
- `config.local.php` é copiado (não movido, nem symlink: o Apache precisa reescrevê-lo durante o instalador) para `${DATA_DIR}/myaac` por um loop no `docker/web-entrypoint.sh`. Uploads/imagens do MyAAC não persistem.
- Assets `Tibia.dat/.spr` (CipSoft) não são distribuídos: ver `docs/client-README.md`.
- `Dockerfile.web` corrige o `load_config_lua` do MyAAC 1.9.5: chave `false` com comentário na mesma linha (`x = false -- ...`) dava erro 500 em todo o site e no `login.php`.
- O quickstart Docker do Canary (`docker/quickstart/myaac/bootstrap.php` no upstream) instala o MyAAC sem o `/install`; possível melhoria futura.
