-- Cast Helper: aba Ataque. Auto target, magias de ataque por quantidade de monstros e runas (o Knight/EK usa runas).
-- Textos da interface sem acento (o acento saiu quebrado no cliente).

-- Runas do servidor (data/scripts/runes + items.xml, canary-bots v2026.10.24.2). level = nível mínimo para usar.
local RUNES = {
  ["heavy magic missile"] = { id = 3198, level = 25 },
  ["fireball"]            = { id = 3189, level = 27 },
  ["icicle"]              = { id = 3158, level = 28 },
  ["sudden death"]        = { id = 3155, level = 45 },
  ["explosion"]           = { id = 3200, level = 31 },
  ["great fireball"]      = { id = 3191, level = 30 },
  ["avalanche"]           = { id = 3161, level = 30 },
  ["stone shower"]        = { id = 3175, level = 28 },
  ["thunderstorm"]        = { id = 3202, level = 28 },
}

-- Magias que precisam do alvo atual (têm range no servidor): palavras -> alcance em sqm.
local TARGETED = {
  ["exori ico"] = 1, ["exori gran ico"] = 1, ["exori infir nia"] = 1, ["exori nia"] = 1,
  ["exori san"] = 4, ["exori con"] = 7, ["exori gran con"] = 7,
  ["exori flam"] = 3, ["exori vis"] = 3, ["exori frigo"] = 3, ["exori tera"] = 3,
}

-- { palavras, mínimo de monstros, alcance em sqm ao redor do personagem }. Nível e mana são checados em casthelper.ready.
local SPELL_PRESETS = {
  knight   = { { "exori mas", 3, 2 }, { "exori gran", 3, 1 }, { "exori", 2, 1 }, { "exori gran ico", 1, 1 } },
  paladin  = { { "exevo mas san", 3, 4 }, { "exori san", 1, 4 }, { "exori gran con", 1, 7 }, { "exori con", 1, 7 } },
  sorcerer = { { "exevo gran mas flam", 3, 5 }, { "exevo gran mas vis", 3, 5 }, { "exori flam", 1, 3 }, { "exori vis", 1, 3 } },
  druid    = { { "exevo gran mas tera", 3, 5 }, { "exevo gran mas frigo", 3, 5 }, { "exori frigo", 1, 3 }, { "exori tera", 1, 3 } },
  monk     = { { "exori mas nia", 3, 1 }, { "exori nia", 1, 1 }, { "exori infir nia", 1, 1 } },
}

-- { nome da runa, mínimo de monstros, alcance em sqm ao redor do alvo }. Só o Knight/EK vem com runas ligadas.
local RUNE_PRESET = { { "great fireball", 3, 3 }, { "sudden death", 1, 1 }, { "heavy magic missile", 1, 1 } }

local SPELL_SLOTS, RUNE_SLOTS = 4, 3
local RUNE_INTERVAL = 2000 -- as runas de ataque compartilham a exaustão de 2 s
local RUNE_RETRY_SECONDS = 10 * 60 -- sem level/magic level a runa fica bloqueada este tempo
local ATTACK_GROUP = 1

-- Modos de alvo do RTC (não existe modo D), na ordem em que o botão alterna. Menor pontuação ganha.
local TARGET_MODES = {
  { key = "A", label = "Modo A: mais proximo" },
  { key = "B", label = "Modo B: mais distante" },
  { key = "C", label = "Modo C: pouca vida perto" },
  { key = "E", label = "Modo E: pouca vida, area densa" },
  { key = "F", label = "Modo F: perto com menos vida" },
  { key = "G", label = "Modo G: perto com mais vida" },
}
local NEAR_RANGE = 2 -- "colado em voce": modos F e G só comparam a vida de quem está a até este alcance
local WOUNDED_PERCENT = 50 -- modo C: abaixo disto o monstro conta como "pouca vida"
local CROWD_RANGE = 2 -- modo E: conta os monstros a até este alcance do candidato

local function modeIndex(key)
  for i, m in ipairs(TARGET_MODES) do
    if m.key == key then return i end
  end
  return 1
end

local function applyPreset(cfg)
  local class = casthelper.class()
  cfg.spells, cfg.runes = {}, {}
  local spellPreset = SPELL_PRESETS[class] or {}
  for i = 1, SPELL_SLOTS do
    local p = spellPreset[i]
    cfg.spells[i] = { enabled = p ~= nil, words = p and p[1] or "", count = p and p[2] or 1, range = p and p[3] or 3 }
  end
  for i = 1, RUNE_SLOTS do
    local p = RUNE_PRESET[i]
    cfg.runes[i] = { enabled = class == "knight", name = p[1], count = p[2], range = p[3] }
  end
end

casthelper.config.combat = casthelper.config.combat or {}
local cfg = casthelper.config.combat
if not cfg.spells then
  applyPreset(cfg)
  cfg.target = { enabled = false, range = 7, mode = "A" }
  cfg.shooter = { enabled = false, minMana = 20 }
end

-- Campos do alvo adicionados depois (configs já salvas não os têm).
cfg.target.switchTarget = cfg.target.switchTarget or false
cfg.target.only = cfg.target.only or ""
cfg.target.skip = cfg.target.skip or ""

-- "rat, cave rat" -> { ["rat"] = true, ["cave rat"] = true }; vazio -> nil.
local function parseNames(text)
  local set, any = {}, false
  for name in text:gmatch("[^,]+") do
    name = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if name ~= "" then
      set[name] = true
      any = true
    end
  end
  return any and set or nil
end
local onlyNames, skipNames = parseNames(cfg.target.only), parseNames(cfg.target.skip)

local function clampNumber(text, fallback, min, max)
  local n = tonumber(text)
  if not n then return fallback end
  return math.max(min, math.min(max, math.floor(n)))
end

local function trim(text)
  return (text:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

-- UI
setDefaultTab("Ataque")

casthelper.addToggle("castHelperTarget", "Auto target", cfg.target.enabled, function(on) cfg.target.enabled = on end)
UI.Label("Escolhe o alvo pela prioridade abaixo (clique para trocar).")
UI.Label("Alcance (sqm):")
UI.TextEdit(tostring(cfg.target.range), function(_, text)
  cfg.target.range = clampNumber(text, cfg.target.range, 1, 8)
end)
local modeButton
modeButton = UI.Button(TARGET_MODES[modeIndex(cfg.target.mode)].label, function()
  local next = modeIndex(cfg.target.mode) % #TARGET_MODES + 1
  cfg.target.mode = TARGET_MODES[next].key
  modeButton:setText(TARGET_MODES[next].label)
end)
casthelper.addToggle("castHelperSwitchTarget", "Trocar de alvo", cfg.target.switchTarget, function(on)
  cfg.target.switchTarget = on
end)
UI.Label("Desligado: mantem o alvo ate morrer ou sair do alcance. Ligado: reavalia sempre.")
UI.Label("So atacar (nomes separados por virgula; vazio = todos):")
UI.TextEdit(cfg.target.only, function(_, text)
  cfg.target.only = text
  onlyNames = parseNames(text)
end)
UI.Label("Nunca atacar (nomes separados por virgula):")
UI.TextEdit(cfg.target.skip, function(_, text)
  cfg.target.skip = text
  skipNames = parseNames(text)
end)

UI.Separator()
casthelper.addToggle("castHelperShooter", "Auto ataque", cfg.shooter.enabled, function(on) cfg.shooter.enabled = on end)
UI.Label("Conjura quando ha monstros suficientes perto. Magia de alvo pede um alvo.")
UI.Label("Mana minima para atacar (%):")
UI.TextEdit(tostring(cfg.shooter.minMana), function(_, text)
  cfg.shooter.minMana = clampNumber(text, cfg.shooter.minMana, 0, 99)
end)

local spellWidgets, runeWidgets = {}, {}

local function refreshWidgets()
  for i, s in ipairs(cfg.spells) do
    local w = spellWidgets[i]
    w.words:setText(s.words)
    w.count:setText(tostring(s.count))
    w.range:setText(tostring(s.range))
    w.switch:setOn(s.enabled)
  end
  for i, r in ipairs(cfg.runes) do
    local w = runeWidgets[i]
    w.name:setText(r.name)
    w.count:setText(tostring(r.count))
    w.range:setText(tostring(r.range))
    w.switch:setOn(r.enabled)
  end
end

UI.Separator()
UI.Label("Magias (palavras / min. monstros / alcance)")
for i = 1, SPELL_SLOTS do
  local slot = cfg.spells[i]
  local w = {}
  w.words = UI.TextEdit(slot.words, function(_, text) slot.words = trim(text) end)
  w.count = UI.TextEdit(tostring(slot.count), function(_, text) slot.count = clampNumber(text, slot.count, 1, 20) end)
  w.range = UI.TextEdit(tostring(slot.range), function(_, text) slot.range = clampNumber(text, slot.range, 1, 8) end)
  w.switch = addSwitch("castHelperSpell" .. i, "Magia " .. i, function(widget)
    slot.enabled = not slot.enabled
    widget:setOn(slot.enabled)
  end)
  w.switch:setOn(slot.enabled)
  spellWidgets[i] = w
end

UI.Separator()
UI.Label("Runas (nome / min. monstros / alcance em volta do alvo)")
UI.Label("Nomes: heavy magic missile, fireball, icicle, sudden death, explosion, great fireball, avalanche, stone shower, thunderstorm")
for i = 1, RUNE_SLOTS do
  local slot = cfg.runes[i]
  local w = {}
  w.name = UI.TextEdit(slot.name, function(_, text) slot.name = trim(text) end)
  w.count = UI.TextEdit(tostring(slot.count), function(_, text) slot.count = clampNumber(text, slot.count, 1, 20) end)
  w.range = UI.TextEdit(tostring(slot.range), function(_, text) slot.range = clampNumber(text, slot.range, 0, 4) end)
  w.switch = addSwitch("castHelperRune" .. i, "Runa " .. i, function(widget)
    slot.enabled = not slot.enabled
    widget:setOn(slot.enabled)
  end)
  w.switch:setOn(slot.enabled)
  runeWidgets[i] = w
end

UI.Button("Preset da classe", function()
  applyPreset(cfg)
  refreshWidgets()
end)

-- Lógica
local function distance(a, b)
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

-- Monstros vivos na tela, com a posição guardada. Invocações do jogador não contam (isMonster só vale para monstros).
local function visibleMonsters()
  local list = {}
  local origin = player:getPosition()
  for _, c in ipairs(g_map.getSpectators(origin, false)) do
    if c:isMonster() and not c:isDead() and c:getHealthPercent() > 0 then
      local pos = c:getPosition()
      table.insert(list, { creature = c, pos = pos, dist = distance(origin, pos) })
    end
  end
  return list
end

local function countAround(monsters, center, range)
  local n = 0
  for _, m in ipairs(monsters) do
    if distance(center, m.pos) <= range then
      n = n + 1
    end
  end
  return n
end

-- Alvo atual, se for um monstro vivo.
local function currentTarget()
  local t = g_game.getAttackingCreature()
  if t and t:isMonster() and not t:isDead() then
    return t
  end
  return nil
end

-- Filtro por nome: "so atacar" (se preenchido) e "nunca atacar".
local function allowedByName(creature)
  local name = creature:getName():lower()
  if skipNames and skipNames[name] then return false end
  return onlyNames == nil or onlyNames[name] == true
end

-- Pontuação do candidato no modo escolhido (menor é melhor). A vida é em %, a distância vai até 8.
local function score(m, monsters, mode)
  local hp = m.creature:getHealthPercent()
  if mode == "B" then
    return -m.dist
  elseif mode == "C" then
    return (hp <= WOUNDED_PERCENT and 0 or 1000) + m.dist * 10 + hp / 100
  elseif mode == "E" then
    return -countAround(monsters, m.pos, CROWD_RANGE) * 10000 + hp * 10 + m.dist
  elseif mode == "F" then
    return hp * 10 + m.dist
  elseif mode == "G" then
    return -hp * 10 + m.dist
  end
  return m.dist
end

-- Nos modos F e G só concorrem os monstros colados em você (se houver algum); senão vale o mais perto.
local function inCandidateGroup(m, monsters, mode)
  if mode ~= "F" and mode ~= "G" then return true end
  for _, other in ipairs(monsters) do
    if other.dist <= NEAR_RANGE and other.dist <= cfg.target.range and allowedByName(other.creature) then
      return m.dist <= NEAR_RANGE
    end
  end
  return true
end

-- Auto target. Por padrão mantém o alvo atual até morrer ou sair do alcance; com "Trocar de alvo" reavalia a cada ciclo.
macro(200, function()
  if not casthelper.on() or not cfg.target.enabled or isInPz() then return end
  local current = currentTarget()
  if current and not cfg.target.switchTarget
    and distance(player:getPosition(), current:getPosition()) <= cfg.target.range then
    return
  end
  local monsters = visibleMonsters()
  local best, bestScore
  for _, m in ipairs(monsters) do
    if m.dist <= cfg.target.range and allowedByName(m.creature) and inCandidateGroup(m, monsters, cfg.target.mode) then
      local s = score(m, monsters, cfg.target.mode)
      if not bestScore or s < bestScore then
        best, bestScore = m, s
      end
    end
  end
  if best and best.creature ~= current then
    g_game.attack(best.creature)
  end
end)

-- Runa recusada por nível ("You do not have enough level." / "...magic level."): bloqueia esta runa por um tempo.
local runeBlocked = {}
local lastRune = nil
local lastRuneAt = 0

onTextMessage(function(mode, text)
  if lastRune and now - lastRune.at < 2000 and text:lower():find("level", 1, true) then
    runeBlocked[lastRune.name] = os.time() + RUNE_RETRY_SECONDS
  end
end)

local warnedRune = {}
local function useRune(rule, target)
  local rune = RUNES[rule.name]
  if not rune then
    if not warnedRune[rule.name] then
      warnedRune[rule.name] = true
      warn("Cast Helper: runa desconhecida: " .. rule.name)
    end
    return false
  end
  if player:getLevel() < rune.level or (runeBlocked[rule.name] and os.time() < runeBlocked[rule.name]) then
    return false
  end
  if not findItem(rune.id) then
    return false
  end
  lastRune = { name = rule.name, at = now }
  lastRuneAt = now
  useWith(rune.id, target)
  return true
end

-- Auto ataque: as magias vêm antes (na ordem), depois as runas. Só age com mana acima do mínimo.
macro(250, function()
  if not casthelper.on() or not cfg.shooter.enabled or isInPz() then return end
  if manapercent() < cfg.shooter.minMana then return end
  local monsters = visibleMonsters()
  if #monsters == 0 then return end
  local origin = player:getPosition()
  local target = currentTarget()

  for _, s in ipairs(cfg.spells) do
    if s.enabled and s.words ~= "" and countAround(monsters, origin, s.range) >= s.count then
      local reach = TARGETED[s.words]
      if not reach or (target and distance(origin, target:getPosition()) <= reach) then
        if casthelper.cast(s.words) then
          return
        end
      end
    end
  end

  if not target or now - lastRuneAt < RUNE_INTERVAL or modules.game_cooldown.isGroupCooldownIconActive(ATTACK_GROUP) then
    return
  end
  local targetPos = target:getPosition()
  for _, r in ipairs(cfg.runes) do
    if r.enabled and r.name ~= "" and countAround(monsters, targetPos, r.range) >= r.count then
      if useRune(r, target) then
        return
      end
    end
  end
end)
