# AGENTS.md

## Objetivo
Empacotar o servidor [canary-bots-with-cast](https://github.com/1LineAtaTime/canary-bots-with-cast)
(fork do OpenTibiaBR Canary com jogadores-bot e sistema de cast) em Docker para rodar no CasaOS,
como servidor local de Tibia single player.

Este repositório **não contém o código do servidor**: só o empacotamento (Dockerfile, compose, entrypoint).

## Arquitetura
- `Dockerfile` — baixa do release do GitHub (`CANARY_BOTS_VERSION`) o `canary`, `libbot_engine.so`
  e o tarball de runtime, mais o mapa `otservbr.otbm` do Canary upstream v3.4.1 (último release antes do commit base ded10949d, de 2026-02-20; nenhum arquivo de mapa mudou entre eles). Base: `ubuntu:24.04`
  (22.04 falha: o binário pede GLIBCXX_3.4.32, do GCC 13; a 24.04 atende e tem glibc >= 2.35).
- `docker/entrypoint.sh` — gera `config.lua` na primeira vez e reaplica a cada subida as chaves vindas do ambiente (`mysql*`, `ip`, `botPlayersOnline`),
  espera o MariaDB, importa `schema.sql` + `database/bots/import.sh` se o banco estiver vazio, e executa `./canary`.
- `docker-compose.yml` — serviços `db` (MariaDB 10.11, utf8mb3) e `canary`.
- `.env.example` — variáveis; copie para `.env`.

## Fatos do projeto upstream
- Banco: MySQL/MariaDB, charset `utf8mb3`, banco `canary`.
- `libbot_engine.so` deve ficar no mesmo diretório de `canary`.
- `config.lua` vem de `config.lua.dist`; chaves `mysql*`, `ip`, `botPlayersOnline` (padrão 500). Chaves `bot*`
  novas/renomeadas exigem rebuild; valores mudam com `/cavebot _global reloadconfig`.
- Conta admin padrão `@god` (senha padrão publicada no README/release upstream — **trocar após o 1º login**).
- Cast: login com conta `@cast` sem senha; jogador usa `/cast on` / `/cast off`. Requer `deployment/web/login.php` (MyAAC).
- Cliente: OTClient Redemption (protocolo 13+); ver `deployment/client/README.md` no upstream.
- Portas Canary: 7171 (login) e 7172 (game). O login do cliente passa pelo MyAAC (serviço `web`, `WEB_PORT`).

## Pontos em aberto / não verificados
- Os nomes dos pacotes `lib*` no Dockerfile não foram testados num build real.
- Se `import.sh` não aceitar `DB_HOST`, ajustar o entrypoint (ver o script em `database/bots/`).
- Contas de jogador: criar pelo MyAAC (site).
- O upstream também tem `docker/` próprio (`Dockerfile.x86`, `docker-compose.yml`); alternativa se o release falhar.

## Convenções
- Responder e comentar em português (pt-BR).
- Nunca commitar `.env` ou `data/`.
- Mudou versão do upstream? Altere `CANARY_BOTS_VERSION` (o nome do tarball segue `canary-bots-runtime-<versão>.tar.gz`).
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
- `Dockerfile.web`: `php:8.2-apache` + MyAAC `MYAAC_VERSION` (1.9.5) + `login.php` e `plugins/` (worldmap) clonados do fork na tag `CANARY_BOTS_VERSION`.
- O cliente OTClient faz login por HTTP (`login.php`, protocolo 1500, `httpLogin = true`), então o `web` é **necessário**, não opcional.
- Porta: `WEB_PORT` (padrão 8080 → 80 do container). No `init.lua` do cliente use `http://SERVER_IP:8080/login.php`, porta 8080 (ver `deployment/client/README.md` do fork).
- Primeiro acesso: abrir `http://SERVER_IP:8080/install`, informar servidor `/srv/canary`, banco `db` / `canary` / usuário e senha do `.env`.
  O MyAAC deve importar o schema próprio sem conflitar com o do Canary (não verificado).
- Instalador do MyAAC só aceita IPs exatos de `install/ip.txt`; o `web-entrypoint.sh` o regera a cada subida com localhost + `MYAAC_INSTALL_IPS`. Descobrir o IP visto pelo Apache em `docker compose logs web` (1ª coluna do access log).
- `config.local.php` é copiado (não movido, nem symlink: o Apache precisa reescrevê-lo durante o instalador) para `${DATA_DIR}/myaac` por um loop no `docker/web-entrypoint.sh`. Uploads/imagens do MyAAC não persistem.
- Assets `Tibia.dat/.spr` (CipSoft) não são distribuídos: ver `deployment/client/README.md` no fork.
- Tudo do serviço `web` está não testado (extensões PHP, instalação, symlink de config.lua).
