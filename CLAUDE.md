# CLAUDE.md

@AGENTS.md

## Notas para o Claude
- Idioma: pt-BR.
- Escopo: apenas empacotamento Docker. Não há código do servidor aqui; para alterar o jogo, trabalhe no
  `rsdevigo/canary-bots` (branch `canary-3.6.1`) e publique um release (tag `v*`).
- Mudanças de Dockerfile/entrypoint só contam como testadas depois de um `docker compose build && up` real.
- Antes de afirmar detalhes do upstream (portas, chaves do config, scripts), confira no repositório/release em vez de assumir.
