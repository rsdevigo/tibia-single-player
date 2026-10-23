# Servidor Canary + bots + cast, usando os binários pré-compilados do release.
# Os binários foram feitos com GCC 13.1 (exigem GLIBCXX_3.4.32): Ubuntu 22.04 não serve, 24.04 sim.
FROM ubuntu:24.04

ARG CANARY_BOTS_VERSION=v2026.09.01
ARG MAP_URL=https://github.com/opentibiabr/canary/releases/download/v3.4.1/otservbr.otbm

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl mariadb-client \
      libssl3t64 libcurl4t64 libluajit-5.1-2 libmariadb3 libreadline8t64 zlib1g \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/canary
ARG REL=https://github.com/1LineAtaTime/canary-bots-with-cast/releases/download/${CANARY_BOTS_VERSION}
RUN curl -fL "$REL/canary" -o canary \
 && curl -fL "$REL/libbot_engine.so" -o libbot_engine.so \
 && curl -fL "$REL/canary-bots-runtime-${CANARY_BOTS_VERSION}.tar.gz" | tar xz \
 && curl -fL "$MAP_URL" -o data-otservbr-global/world/otservbr.otbm \
 && tr -d '\r' < database/bots/import.sh > /tmp/import.sh && mv /tmp/import.sh database/bots/import.sh \
 && chmod +x canary

# Scripts próprios (ex.: !trade / !temple), carregados junto com os do datapack.
COPY docker/scripts/trade_area.lua data-otservbr-global/scripts/custom/trade_area.lua

COPY docker/sql/bot_missing_tables.sql /docker/bot_missing_tables.sql
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7171 7172
ENTRYPOINT ["/entrypoint.sh"]
