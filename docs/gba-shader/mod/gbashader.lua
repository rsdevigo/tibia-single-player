-- Registra o shader 'Map - HD' (gbashader.frag: suavização de bordas) e o aplica ao mapa ao entrar no jogo.
-- Ctrl+Shift+G liga/desliga. O estado fica salvo nas configurações do cliente.

local NAME = 'Map - HD'
local HOTKEY = 'Ctrl+Shift+G'
local SETTING = 'gbashader'

local enabled = true

local function apply()
	local map = modules.game_interface and modules.game_interface.getMapPanel()
	if map then
		map:setShader(enabled and NAME or 'Default')
	end
end

local function toggle()
	enabled = not enabled
	g_settings.set(SETTING, enabled)
	apply()
	g_logger.info('gbashader: ' .. (enabled and 'ligado' or 'desligado'))
end

function init()
	enabled = g_settings.getBoolean(SETTING, true)
	g_shaders.createFragmentShader(NAME, '/mods/gbashader/gbashader.frag', false)
	g_shaders.setupMapShader(NAME)
	g_keyboard.bindKeyDown(HOTKEY, toggle)
	connect(g_game, { onGameStart = apply })
	if g_game.isOnline() then
		apply()
	end
end

function terminate()
	g_keyboard.unbindKeyDown(HOTKEY)
	disconnect(g_game, { onGameStart = apply })
	if g_game.isOnline() then
		local map = modules.game_interface and modules.game_interface.getMapPanel()
		if map then
			map:setShader('Default')
		end
	end
end
