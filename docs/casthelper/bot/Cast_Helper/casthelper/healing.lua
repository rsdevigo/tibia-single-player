-- Cast Helper: aba Healing. Spell healing por % de HP e poções de vida/mana automáticas.
-- Textos da interface sem acento (o acento saiu quebrado no cliente).

-- Poções de cura do servidor (data/scripts/actions/items/potions.lua + nomes de items.xml, canary-bots v2026.10.24.2).
-- hp/mp = média da cura; level/vocs = restrição de uso (vocs vazio = qualquer classe). Todas entram no modo automático.
local POTIONS = {
  { id = 7876,  name = "small health potion",     hp = 75,   mp = 0,   level = 0,   vocs = {} },
  { id = 266,   name = "health potion",           hp = 150,  mp = 0,   level = 0,   vocs = {} },
  { id = 268,   name = "mana potion",             hp = 0,    mp = 100, level = 0,   vocs = {} },
  { id = 236,   name = "strong health potion",    hp = 300,  mp = 0,   level = 50,  vocs = { "paladin", "knight", "monk" } },
  { id = 237,   name = "strong mana potion",      hp = 0,    mp = 150, level = 50,  vocs = {} },
  { id = 238,   name = "great mana potion",       hp = 0,    mp = 200, level = 80,  vocs = { "sorcerer", "druid", "paladin", "monk" } },
  { id = 239,   name = "great health potion",     hp = 500,  mp = 0,   level = 80,  vocs = { "knight" } },
  { id = 7642,  name = "great spirit potion",     hp = 300,  mp = 150, level = 80,  vocs = { "paladin", "monk" } },
  { id = 7643,  name = "ultimate health potion",  hp = 750,  mp = 0,   level = 130, vocs = { "knight" } },
  { id = 23373, name = "ultimate mana potion",    hp = 0,    mp = 500, level = 130, vocs = { "sorcerer", "druid" } },
  { id = 23374, name = "ultimate spirit potion",  hp = 500,  mp = 300, level = 130, vocs = { "paladin", "monk" } },
  { id = 23375, name = "supreme health potion",   hp = 1000, mp = 0,   level = 200, vocs = { "knight" } },
}

-- Presets iniciais por classe: { palavras, % de HP }. O nível e a mana são checados em casthelper.ready.
local PRESETS = {
  paladin  = { { "exura gran", 50 }, { "exura", 80 } },
  knight   = { { "exura gran ico", 35 }, { "exura ico", 65 } },
  druid    = { { "exura vita", 40 }, { "exura gran", 60 }, { "exura", 80 } },
  sorcerer = { { "exura vita", 40 }, { "exura gran", 60 }, { "exura", 80 } },
  monk     = { { "exura gran", 45 }, { "exura", 75 } },
}

local SPELL_SLOTS = 3
local POTION_INTERVAL = 1000 -- as poções compartilham a exaustão de cura

local function applyPreset(cfg)
  local preset = PRESETS[casthelper.class()] or {}
  cfg.spells = {}
  for i = 1, SPELL_SLOTS do
    local p = preset[i]
    cfg.spells[i] = { enabled = p ~= nil, words = p and p[1] or "", hp = p and p[2] or 50 }
  end
end

casthelper.config.healing = casthelper.config.healing or {}
local cfg = casthelper.config.healing
if not cfg.spells then
  applyPreset(cfg)
  cfg.hpPotion = { enabled = true, percent = 60 }
  cfg.mpPotion = { enabled = true, percent = 40 }
end

local function clampPercent(text, fallback)
  local n = tonumber(text)
  if not n then return fallback end
  return math.max(1, math.min(99, math.floor(n)))
end

-- Poções que o personagem pode usar (classe e nível), da mais forte para a mais fraca, para o campo hp ou mp.
local function usablePotions(field)
  local class, level = casthelper.class(), player:getLevel()
  local list = {}
  for _, p in ipairs(POTIONS) do
    if p[field] > 0 and level >= p.level and (#p.vocs == 0 or table.find(p.vocs, class)) then
      table.insert(list, p)
    end
  end
  table.sort(list, function(a, b) return a[field] > b[field] end)
  return list
end

-- UI
setDefaultTab("Healing")
UI.Label("Spell healing (palavras / HP% maximo)")

local spellWidgets = {}
local function refreshSpellWidgets()
  for i = 1, SPELL_SLOTS do
    local s, w = cfg.spells[i], spellWidgets[i]
    w.words:setText(s.words)
    w.hp:setText(tostring(s.hp))
    w.switch:setOn(s.enabled)
  end
end

for i = 1, SPELL_SLOTS do
  local slot = cfg.spells[i]
  local w = {}
  w.words = UI.TextEdit(slot.words, function(_, text)
    slot.words = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  end)
  w.hp = UI.TextEdit(tostring(slot.hp), function(_, text)
    slot.hp = clampPercent(text, slot.hp)
  end)
  w.switch = addSwitch("castHelperHeal" .. i, "Spell " .. i, function(widget)
    slot.enabled = not slot.enabled
    widget:setOn(slot.enabled)
  end)
  w.switch:setOn(slot.enabled)
  spellWidgets[i] = w
end

UI.Button("Preset da classe", function()
  applyPreset(cfg)
  refreshSpellWidgets()
end)

-- Magias que o servidor recusou ("aprenda primeiro") ficam bloqueadas por 30 min; use depois de aprender uma.
UI.Button("Tentar magias bloqueadas de novo", function()
  casthelper.clearUnlearned()
end)

UI.Separator()
UI.Label("Pocoes (usa a mais forte que voce tem)")

UI.Label("Pocao de vida: usar abaixo de HP%")
UI.TextEdit(tostring(cfg.hpPotion.percent), function(_, text)
  cfg.hpPotion.percent = clampPercent(text, cfg.hpPotion.percent)
end)
local hpSwitch = addSwitch("castHelperHpPotion", "Pocao de vida", function(widget)
  cfg.hpPotion.enabled = not cfg.hpPotion.enabled
  widget:setOn(cfg.hpPotion.enabled)
end)
hpSwitch:setOn(cfg.hpPotion.enabled)

UI.Label("Pocao de mana: usar abaixo de MP%")
UI.TextEdit(tostring(cfg.mpPotion.percent), function(_, text)
  cfg.mpPotion.percent = clampPercent(text, cfg.mpPotion.percent)
end)
local mpSwitch = addSwitch("castHelperMpPotion", "Pocao de mana", function(widget)
  cfg.mpPotion.enabled = not cfg.mpPotion.enabled
  widget:setOn(cfg.mpPotion.enabled)
end)
mpSwitch:setOn(cfg.mpPotion.enabled)

-- Lógica
-- Spell: as regras de menor HP% vêm primeiro (cura mais urgente).
macro(100, function()
  if not casthelper.on() then return end
  local hp = player:getHealthPercent()
  local rules = {}
  for _, s in ipairs(cfg.spells) do
    if s.enabled and s.words ~= "" and hp <= s.hp then
      table.insert(rules, s)
    end
  end
  table.sort(rules, function(a, b) return a.hp < b.hp end)
  for _, s in ipairs(rules) do
    if casthelper.cast(s.words) then
      return
    end
  end
end)

local lastPotion = 0
local function drink(field)
  for _, p in ipairs(usablePotions(field)) do
    if findItem(p.id) then
      useWith(p.id, player)
      lastPotion = now
      return true
    end
  end
  return false
end

macro(100, function()
  if not casthelper.on() or now - lastPotion < POTION_INTERVAL then return end
  if cfg.hpPotion.enabled and player:getHealthPercent() <= cfg.hpPotion.percent and drink("hp") then
    return
  end
  if cfg.mpPotion.enabled and manapercent() <= cfg.mpPotion.percent then
    drink("mp")
  end
end)
