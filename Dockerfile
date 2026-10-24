# Servidor Canary (v3.6.1, cliente 15.11) + bots, usando os binários do release do rsdevigo/canary-bots.
# Os binários são compilados no Ubuntu 24.04 (GCC 13) e só dependem de libc/libstdc++: o resto vem
# estático do vcpkg. Ubuntu 22.04 não serve (GLIBCXX_3.4.32).
FROM ubuntu:24.04

ARG CANARY_BOTS_REPO=rsdevigo/canary-bots
ARG CANARY_BOTS_VERSION=v2026.10.24.1
# O mapa principal não vem no tarball de runtime. É o mesmo arquivo desde a v3.4.1 (o release do
# Canary copia o mapa do release anterior); mudam só house/monster/npc.xml, que vêm no tarball.
ARG MAP_URL=https://github.com/opentibiabr/canary/releases/download/v3.6.1/otservbr.otbm

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl mariadb-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/canary
ARG REL=https://github.com/${CANARY_BOTS_REPO}/releases/download/${CANARY_BOTS_VERSION}
RUN curl -fL "$REL/canary" -o canary \
 && curl -fL "$REL/libbot_engine.so" -o libbot_engine.so \
 && curl -fL "$REL/canary-bots-runtime-${CANARY_BOTS_VERSION}.tar.gz" | tar xz \
 && curl -fL "$MAP_URL" -o data-otservbr-global/world/otservbr.otbm \
 && tr -d '\r' < database/bots/import.sh > /tmp/import.sh && mv /tmp/import.sh database/bots/import.sh \
 && chmod +x canary

# Scripts próprios (ex.: !trade / !temple), carregados junto com os do datapack.
COPY docker/scripts/trade_area.lua data-otservbr-global/scripts/custom/trade_area.lua

COPY docker/entrypoint.sh /entrypoint.sh
# Remove CR caso o arquivo venha de um checkout no Windows (core.autocrlf).
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 7171 7172
ENTRYPOINT ["/entrypoint.sh"]
