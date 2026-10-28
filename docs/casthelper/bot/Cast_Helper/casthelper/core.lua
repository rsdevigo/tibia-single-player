-- Cast Helper: núcleo. Detecção de classe, checagem de spells, chave geral e hotkey.
-- Roda no contexto do bot do OTClient (macro, storage, hotkey, player, etc. são globais aqui).

casthelper = {}

-- player:getVocation() devolve o clientid do servidor (data/XML/vocations.xml), não o id interno:
-- 1 Knight, 2 Paladin, 3 Sorcerer, 4 Druid, 5 Monk; promovidos 11 EK, 12 RP, 13 MS, 14 ED, 15 Exalted Monk.
-- O campo vocations da tabela SpellInfo do gamelib usa o id interno (1 Sorcerer ... 10 Exalted Monk).
local CLIENT_VOCATIONS = {
  [1]  = { class = "knight",   spellVoc = 4,  promoted = false },
  [2]  = { class = "paladin",  spellVoc = 3,  promoted = false },
  [3]  = { class = "sorcerer", spellVoc = 1,  promoted = false },
  [4]  = { class = "druid",    spellVoc = 2,  promoted = false },
  [5]  = { class = "monk",     spellVoc = 9,  promoted = false },
  [11] = { class = "knight",   spellVoc = 8,  promoted = true },
  [12] = { class = "paladin",  spellVoc = 7,  promoted = true },
  [13] = { class = "sorcerer", spellVoc = 5,  promoted = true },
  [14] = { class = "druid",    spellVoc = 6,  promoted = true },
  [15] = { class = "monk",     spellVoc = 10, promoted = true },
}

local function vocationInfo()
  return CLIENT_VOCATIONS[player:getVocation()]
end

-- Classe base do personagem ("sorcerer", "druid", "paladin", "knight", "monk") ou nil se não reconhecida.
function casthelper.class()
  local info = vocationInfo()
  return info and info.class
end

-- true se o personagem já tem a promoção (Master Sorcerer, Elite Knight, ...).
function casthelper.promoted()
  local info = vocationInfo()
  return info ~= nil and info.promoted
end

-- Classes que lançam magias de dano/cura por mana (usam poção de mana, não de vida, como cura principal).
function casthelper.isCaster()
  local c = casthelper.class()
  return c == "sorcerer" or c == "druid"
end

local SPELLS = modules.gamelib.SpellInfo["Default"]
local spellByWords = {}
for _, data in pairs(SPELLS) do
  spellByWords[data.words] = data
end

-- Dados do spell (tabela do gamelib) pelas palavras, ou nil.
function casthelper.spellData(words)
  return spellByWords[words:lower()]
end

local warned = {}
local lastCast = nil
local RETRY_SECONDS = 30 * 60

-- No Canary o spell precisa ser aprendido com o NPC (o nível não basta) e o servidor não manda ao cliente a lista
-- de magias aprendidas (modules.game_actionbar.spellListData chega vazia). Então só dá para descobrir tentando:
-- se o servidor recusar ("You need to learn this spell first."), o spell fica bloqueado em
-- storage.casthelper.unlearned (guardado em os.time, sobrevive ao fechar o cliente) e é tentado de novo depois de
-- RETRY_SECONDS, caso o personagem tenha aprendido. casthelper.clearUnlearned() libera tudo na hora.
local function isUnlearned(words)
  local retryAt = casthelper.config.unlearned[words]
  return retryAt ~= nil and os.time() < retryAt
end

function casthelper.clearUnlearned()
  casthelper.config.unlearned = {}
end

-- true se o spell pode ser lançado agora: existe, é da vocação, nível, mana e cooldown (ícone e grupo).
-- Spell desconhecido para o cliente retorna false (o canCast do vBot retorna true e deixa passar).
function casthelper.ready(words)
  local data = casthelper.spellData(words)
  if not data then
    if not warned[words] then
      warned[words] = true
      warn("Cast Helper: spell desconhecido para o cliente: " .. words)
    end
    return false
  end
  if player:getLevel() < data.level or player:getMana() < data.mana then
    return false
  end
  local info = vocationInfo()
  if not info or not table.find(data.vocations, info.spellVoc) then
    return false
  end
  if isUnlearned(data.words) then
    return false
  end
  if modules.game_cooldown.isCooldownIconActive(data.id) then
    return false
  end
  for groupId in pairs(data.group) do
    if modules.game_cooldown.isGroupCooldownIconActive(groupId) then
      return false
    end
  end
  return true
end

-- Lança o spell se estiver pronto. Retorna true se enviou.
function casthelper.cast(words)
  if not casthelper.ready(words) then
    return false
  end
  lastCast = { words = words:lower(), at = now }
  say(words)
  return true
end

onTextMessage(function(mode, text)
  if lastCast and now - lastCast.at < 2000 and text:lower():find("learn this spell", 1, true) then
    casthelper.config.unlearned[lastCast.words] = os.time() + RETRY_SECONDS
  end
end)

-- Configuração persistente (por perfil do cliente, via storage do bot).
storage.casthelper = storage.casthelper or {}
casthelper.config = storage.casthelper
if casthelper.config.enabled == nil then casthelper.config.enabled = false end
casthelper.config.hotkey = casthelper.config.hotkey or "Home"
casthelper.config.unlearned = casthelper.config.unlearned or {}

-- Chave geral: as abas só agem se isto for true.
function casthelper.on()
  return casthelper.config.enabled and g_game.isOnline()
end

-- Chave com estado visual: addToggle(id, texto, ligado, aoMudar(ligado)).
function casthelper.addToggle(id, text, enabled, onChange)
  local switch = addSwitch(id, text, function(widget)
    enabled = not enabled
    widget:setOn(enabled)
    onChange(enabled)
  end)
  switch:setOn(enabled)
  return switch
end

-- Aba principal.
setDefaultTab("Cast")
local classNames = {
  sorcerer = "Sorcerer", druid = "Druid", paladin = "Paladin", knight = "Knight", monk = "Monk",
}
local className = classNames[casthelper.class()] or "desconhecida"
UI.Label("Cast Helper - classe: " .. className .. (casthelper.promoted() and " (promovido)" or ""))

local master = addSwitch("castHelperMaster", "Cast Helper ligado [" .. casthelper.config.hotkey .. "]", function(widget)
  casthelper.config.enabled = not casthelper.config.enabled
  widget:setOn(casthelper.config.enabled)
end)
master:setOn(casthelper.config.enabled)

hotkey(casthelper.config.hotkey, "", function()
  casthelper.config.enabled = not casthelper.config.enabled
  master:setOn(casthelper.config.enabled)
end, nil, true)
