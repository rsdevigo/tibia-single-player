# Cast Helper (config do bot do OTClient)

Automação inspirada no RTC Helper do Rubinot (healing, ferramentas, auto target/shooter), por classe
(Sorcerer, Druid, Paladin, Knight, Monk). Roda no **bot do OTClient Redemption** (`mods/game_bot`), como uma
config própria, sem depender do vBot e sem mexer no servidor. Alvo: protocolo 1511.

**Estado: esqueleto, NÃO TESTADO.** Ainda não foi carregado em um cliente real (não havia interpretador Lua nem
cliente logado ao escrever). Só o núcleo existe; as abas estão como placeholders.

## Instalar

1. Copie `bot/Cast_Helper/` para a pasta `bot/` do diretório de escrita do cliente (`g_resources.getWriteDir()`).
   O painel do Bot mostra esse caminho na mensagem "No configs found in ...".
2. No jogo, abra o painel do Bot, escolha a config `Cast_Helper` e ative.
3. Aba **Cast**: liga/desliga geral (hotkey padrão `Home`, mude em `storage.casthelper.hotkey`).

## Estrutura

- `_Loader.lua`: o bot só executa os `.lua` da raiz, então ele carrega `casthelper/*.lua` na ordem.
- `casthelper/core.lua`: detecção de classe, `casthelper.ready`/`casthelper.cast` (nível, mana, vocação e cooldown do spell), chave geral.
- `casthelper/healing.lua`: 3 regras de spell (palavras + HP% máximo, preset por classe) e poção de vida/mana
  automáticas. Aceita **todas** as poções de cura do servidor (12, de `small health potion` a `supreme health potion`),
  filtradas por classe e nível, usando a mais forte que estiver na mochila. A lista vem de
  `data/scripts/actions/items/potions.lua` do `canary-bots v2026.10.24.2`.
- `casthelper/foods.lua`: tabela das 133 comidas do servidor (id = valor), de `data/scripts/actions/items/foods.lua`.
- `casthelper/tools.lua`: aba Ferramentas.
  - **Autofood:** come quando a regeneração restante cai a 400 s ou menos, escolhendo a maior comida que cabe (o servidor
    recusa com "You are full" se regeneração + valor × 12 ≥ 1200). Druid sem comida na mochila conjura `exevo pan`.
  - **Change gold:** usa (com "Use with", a pilha como alvo; o uso simples é recusado pelo servidor) pilhas de exatamente 100 de gold e platinum (crystal não converte). Se o servidor responder "You cannot use this object.", pausa por 30 min (botão "Retomar Change gold" libera).
  - **Auto velocidade:** `utani hur` (Knight: `utani tempo hur`), só fora de PZ e sem haste. O `utamo tempo san` do
    Paladin não é padrão: ele pacifica e corta o dano por 10 s (conferido em `swift_foot.lua`).
  - **Auto reconnect:** liga/desliga a opção `autoReconnect` do próprio cliente; o bot para quando o personagem sai do jogo.
  - Comida e moedas só são achadas em **containers abertas**.
- `casthelper/combat.lua`: aba Ataque (**não testada no cliente**).
  - **Auto target:** os modos do RTC (botão alterna; não existe modo D). A, B, C, E, F e G seguem a descrição do RTC;
    os critérios numéricos são interpretação minha (constantes no topo de `combat.lua`):
    **A** mais próximo; **B** mais distante; **C** monstros com ≤ 50% de vida primeiro, o mais perto deles;
    **E** o de área mais densa (monstros a ≤ 2 sqm dele), desempate por menos vida; **F** entre os colados em você
    (≤ 2 sqm) o de menos vida; **G** idem, o de mais vida. Sem ninguém colado, F e G usam todos no alcance.
    Filtros "só atacar" e "nunca atacar" por nome (separados por vírgula, nome exato). Por padrão mantém o alvo até
    morrer ou sair do alcance; "Trocar de alvo" reavalia a cada 200 ms.
  - **Auto ataque:** 4 regras de magia (palavras, mínimo de monstros, alcance em volta do personagem) com preset por classe,
    avaliadas em ordem; magias de alvo (`exori ico`, `exori san`, strikes...) exigem o alvo atual dentro do alcance da
    magia. Só age com mana acima do mínimo (padrão 20%). Nível, mana, cooldown e magia não aprendida usam o mesmo
    `casthelper.ready` da aba Healing.
  - **Runas:** 3 regras (nome, mínimo de monstros, alcance em volta do alvo) usadas no alvo atual com `useWith`, a cada 2 s
    e fora do cooldown do grupo de ataque. Vêm ligadas só para Knight/EK (great fireball, sudden death, heavy magic missile);
    as outras classes têm as mesmas regras desligadas. Se o servidor recusar por level, a runa fica bloqueada por 10 min.
    Ids de `items.xml` do servidor; a runa precisa estar em uma container aberta ou no equipamento.
  - Não há Magic Wall nem ondas/feixes (dependem de direção) por enquanto.

## Notas de projeto

- `player:getVocation()` devolve o **clientid** do servidor (`data/XML/vocations.xml`): 1 Knight, 2 Paladin,
  3 Sorcerer, 4 Druid, 5 Monk; promovidos 11 EK, 12 RP, 13 MS, 14 ED, 15 Exalted Monk. Já o campo `vocations`
  da tabela de spells do gamelib usa o id interno (1 Sorcerer, 2 Druid, 3 Paladin, 4 Knight, 5 MS, 6 ED, 7 RP,
  8 EK, 9 Monk, 10 Exalted Monk); `core.lua` converte um no outro. (O `VocationNames` do gamelib segue o id interno,
  não o que o cliente recebe.)
- Textos da interface do bot ficam sem acento: o acento saiu quebrado no cliente.
- A tabela de spells do cliente (`gamelib/spells.lua`) foi comparada com `data/scripts/spells` do release
  `canary-bots v2026.10.24.2`: mesmas palavras; só `exori infir nia` e `exori mas nia` (monge) têm nível/mana diferentes.
- `exevo pan` é só de Druid: Sorcerer precisa de comida real. `exeta res` é só de Elite Knight.
- No Canary o spell precisa ser **aprendido** (comprado com o NPC); o nível não basta, e o servidor **não manda ao
  cliente** a lista de aprendidas (`modules.game_actionbar.spellListData` chega vazia, testado). Então o Helper descobre
  tentando: se o servidor responder "You need to learn this spell first.", o spell fica bloqueado por 30 min em
  `storage.casthelper.unlearned` (persiste ao fechar o cliente) e a mensagem aparece uma vez só. O botão
  "Tentar magias bloqueadas de novo" (aba Healing) libera na hora, por exemplo depois de aprender uma magia.
- O bot só expõe `pairs`, `ipairs`, `type`, `tostring`, `tonumber`, `math`, `table`, `string`, `pcall`, `setmetatable` e
  `os.time/clock/date/difftime`: não use `next`, `select`, `unpack` nem `error`.
