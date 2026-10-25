-- Carrega o mapa completo do tibiamaps (data/tibiamaps/floor-XX-map.png) no minimapa a cada entrada no jogo.
-- Precisa ser a cada sessão: o OTClient só grava no minimap.otmm os blocos "vistos" pelo personagem, e
-- g_minimap.loadImage não marca os blocos como vistos, então o mapa importado não sobrevive ao logout.
-- Os tiles que você já explorou têm prioridade (loadImage não sobrescreve tiles vistos).

local DIR = '/tibiamaps/'
-- Canto superior esquerdo das imagens por andar (bounds.json do tibiamaps).
local TOP_LEFT = { x = 31744, y = 30976 }

local function loadFloors()
	if not g_game.isOnline() then
		return
	end
	local floors = 0
	for z = 0, 15 do
		local file = string.format('%sfloor-%02d-map.png', DIR, z)
		if g_resources.fileExists(file) and g_minimap.loadImage(file, { x = TOP_LEFT.x, y = TOP_LEFT.y, z = z }, 1.0) then
			floors = floors + 1
		end
	end
	g_logger.info(string.format('tibiamaps: %d andares carregados no minimapa', floors))
end

-- O mapa do Cyclopedia (Cyclopedia.loadMap) faz g_minimap.clean() e recarrega só o minimap.otmm, apagando as
-- imagens importadas. Envolvemos a função para recarregá-las logo depois.
local cyclopediaLoadMap = nil

local function hookCyclopedia()
	local cyclopedia = modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
	if cyclopediaLoadMap or not cyclopedia or not cyclopedia.loadMap then
		return
	end
	cyclopediaLoadMap = cyclopedia.loadMap
	cyclopedia.loadMap = function(...)
		local result = cyclopediaLoadMap(...)
		loadFloors()
		return result
	end
end

local function unhookCyclopedia()
	local cyclopedia = modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
	if cyclopediaLoadMap and cyclopedia then
		cyclopedia.loadMap = cyclopediaLoadMap
	end
	cyclopediaLoadMap = nil
end

function onGameStart()
	hookCyclopedia()
	-- Espera o game_minimap, que no próprio onGameStart limpa o minimapa e carrega o minimap.otmm.
	scheduleEvent(loadFloors, 1000)
end

function init()
	connect(g_game, { onGameStart = onGameStart })
	if g_game.isOnline() then
		onGameStart()
	end
end

function terminate()
	disconnect(g_game, { onGameStart = onGameStart })
	unhookCyclopedia()
end
