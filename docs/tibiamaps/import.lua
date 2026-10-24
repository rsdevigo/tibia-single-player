-- Importa os marcadores do tibiamaps (https://github.com/tibiamaps/tibia-map-data, MIT) para o minimapa
-- do OTClient Redemption. O mapa em si é carregado pelo mod game_tibiamaps a cada entrada no jogo
-- (ver docs/tibiamaps/README.md): o minimap.otmm não guarda tiles importados por imagem.
--
-- Arquivo esperado: <pasta do OTClient>/data/tibiamaps/markers.json
-- Uso: na tela de login (deslogado), abra o terminal (Ctrl+T) e rode:  dofile('/tibiamaps/import.lua')
-- Deslogado porque os marcadores são gravados ao sair do jogo e sobrescreveriam a importação.

local DIR = '/tibiamaps/'
-- Os 20 ícones de marcador do Tibia, na ordem dos flag0..flag19 do OTClient.
local ICONS = {
	['checkmark'] = 0, ['?'] = 1, ['!'] = 2, ['star'] = 3, ['crossmark'] = 4,
	['cross'] = 5, ['mouth'] = 6, ['spear'] = 7, ['sword'] = 8, ['flag'] = 9,
	['lock'] = 10, ['bag'] = 11, ['skull'] = 12, ['$'] = 13, ['red up'] = 14,
	['red down'] = 15, ['red right'] = 16, ['red left'] = 17, ['up'] = 18, ['down'] = 19,
}

if g_game.isOnline() then
	print('tibiamaps: saia do jogo antes de importar (os marcadores são salvos ao deslogar e sobrescreveriam a importação).')
	return
end

if not g_resources.fileExists(DIR .. 'markers.json') then
	print('tibiamaps: não encontrei data/tibiamaps/markers.json.')
	return
end

-- Mantém os seus marcadores e acrescenta os do tibiamaps que não estiverem na mesma posição.
local settings = g_settings.getNode('Minimap') or {}
settings.flags = settings.flags or {}
local taken = {}
for _, flag in ipairs(settings.flags) do
	taken[string.format('%d,%d,%d', flag.position.x, flag.position.y, flag.position.z)] = true
end

local added = 0
for _, marker in ipairs(json.decode(g_resources.readFileContents(DIR .. 'markers.json'))) do
	local key = string.format('%d,%d,%d', marker.x, marker.y, marker.z)
	local icon = ICONS[marker.icon]
	if icon and not taken[key] then
		table.insert(settings.flags, {
			position = { x = marker.x, y = marker.y, z = marker.z },
			icon = icon,
			description = marker.description or '',
		})
		taken[key] = true
		added = added + 1
	end
end
g_settings.setNode('Minimap', settings)
g_settings.save()

print(string.format('tibiamaps: %d marcadores adicionados. Pode entrar no jogo.', added))
