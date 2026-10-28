-- Cast Helper: aba Ferramentas (autofood, change gold, haste, auto reconnect).
-- Textos da interface sem acento (o acento saiu quebrado no cliente).

local ITEM_GOLD, ITEM_PLATINUM = 3031, 3035 -- crystal coin (3043) nao converte para nada
local MAX_REGENERATION = 1200 -- o servidor recusa a comida ("You are full") se regeneracao + valor * 12 >= 1200
local EAT_BELOW = 400 -- come quando a regeneracao restante (s) cair a este valor

local HASTE_PRESETS = { knight = "utani tempo hur" }
local DEFAULT_HASTE = "utani hur" -- o utamo tempo san do Paladin pacifica e corta o dano por 10 s, fica so manual

casthelper.config.tools = casthelper.config.tools or {}
local cfg = casthelper.config.tools
if not cfg.food then
  cfg.food = { enabled = true }
  cfg.gold = { enabled = true }
  cfg.haste = { enabled = false, words = HASTE_PRESETS[casthelper.class()] or DEFAULT_HASTE }
end

-- Percorre todos os itens das containers abertas; fn(item) retorna true para parar.
local function eachContainerItem(fn)
  for _, container in pairs(g_game.getContainers()) do
    for _, item in ipairs(container:getItems()) do
      if fn(item) then
        return true
      end
    end
  end
  return false
end

-- Maior comida (por valor) que cabe sem encher, ou nil.
local function pickFood(regeneration)
  local best, bestValue = nil, 0
  eachContainerItem(function(item)
    local value = casthelper.FOODS[item:getId()]
    if value and value > bestValue and regeneration + value * 12 < MAX_REGENERATION then
      best, bestValue = item, value
    end
  end)
  return best
end

local addToggle = casthelper.addToggle

-- UI
setDefaultTab("Ferramentas")

addToggle("castHelperFood", "Autofood", cfg.food.enabled, function(on) cfg.food.enabled = on end)
UI.Label("Come a maior comida que cabe quando a regeneracao baixa.")
if casthelper.class() == "druid" then
  UI.Label("Sem comida na mochila, conjura com exevo pan.")
end

UI.Separator()
addToggle("castHelperGold", "Change gold", cfg.gold.enabled, function(on) cfg.gold.enabled = on end)
UI.Label("Converte pilhas de 100 moedas (gold e platinum).")

UI.Separator()
addToggle("castHelperHaste", "Auto velocidade", cfg.haste.enabled, function(on) cfg.haste.enabled = on end)
UI.Label("Magia de velocidade:")
UI.TextEdit(cfg.haste.words, function(_, text)
  cfg.haste.words = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
end)

UI.Separator()
-- O bot para quando o personagem sai do jogo; quem reconecta e a opcao do proprio cliente (tela de personagens).
addToggle("castHelperReconnect", "Auto reconnect", g_settings.getBoolean("autoReconnect", false), function(on)
  g_settings.set("autoReconnect", on)
end)
UI.Label("Opcao do cliente: reconecta pela tela de personagens.")

-- Logica
macro(2000, function()
  if not casthelper.on() or not cfg.food.enabled then return end
  local regeneration = player:getRegenerationTime()
  if regeneration > EAT_BELOW then return end
  local food = pickFood(regeneration)
  if food then
    g_game.use(food)
  elseif casthelper.class() == "druid" then
    casthelper.cast("exevo pan")
  end
end)

-- O servidor (change_gold.lua) so converte a pilha de exatamente 100 (tamanho maximo da pilha de moedas).
-- Se ele recusar ("You cannot use this object."), o Change gold fica pausado por GOLD_RETRY_SECONDS em vez de
-- repetir a mensagem a cada ciclo; o botao abaixo libera na hora.
local GOLD_RETRY_SECONDS = 30 * 60
local lastGoldUse = 0

onTextMessage(function(mode, text)
  if now - lastGoldUse < 2000 and text:lower():find("cannot use this object", 1, true) then
    cfg.gold.pausedUntil = os.time() + GOLD_RETRY_SECONDS
  end
end)

UI.Button("Retomar Change gold", function()
  cfg.gold.pausedUntil = nil
end)

macro(1500, function()
  if not casthelper.on() or not cfg.gold.enabled then return end
  if cfg.gold.pausedUntil and os.time() < cfg.gold.pausedUntil then return end
  eachContainerItem(function(item)
    local id = item:getId()
    if (id == ITEM_GOLD or id == ITEM_PLATINUM) and item:getCount() == 100 then
      lastGoldUse = now
      -- Moeda e multiuso no cliente ("Use with ..."): o servidor recusa o uso simples, entao usa a pilha com ela mesma de alvo.
      useWith(item, item)
      return true
    end
  end)
end)

macro(500, function()
  if not casthelper.on() or not cfg.haste.enabled or cfg.haste.words == "" then return end
  if hasHaste() or isInPz() then return end
  casthelper.cast(cfg.haste.words)
end)
