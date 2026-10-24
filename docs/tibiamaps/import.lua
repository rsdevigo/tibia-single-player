-- Importa o mapa completo e os marcadores do tibiamaps (https://github.com/tibiamaps/tibia-map-data, MIT)
-- para o minimapa do OTClient Redemption.
--
-- Arquivos esperados em <pasta do OTClient>/data/tibiamaps/: floor-00-map.png .. floor-15-map.png,
-- markers.json e este import.lua (ver docs/tibiamaps/README.md).
-- Uso: na tela de login (deslogado), abra o terminal (Ctrl+T) e rode:  dofile('/tibiamaps/import.lua')
-- Deslogado porque o minimapa e os marcadores são gravados ao sair do jogo e sobrescreveriam a importação.

local DIR = '/tibiamaps/'
-- Canto superior esquerdo das imagens por andar (bounds.json do tibiamaps).
local TOP_LEFT = { x = 31744, y = 30976 }
-- Os 20 ícones de marcador do Tibia, na ordem dos flag0..flag19 do OTClient.
local ICONS = {
	['checkmark'] = 0, ['?'] = 1, ['!'] = 2, ['star'] = 3, ['crossmark'] = 4,
	['cross'] = 5, ['mouth'] = 6, ['spear'] = 7, ['sword'] = 8, ['flag'] = 9,
	['lock'] = 10, ['bag'] = 11, ['skull'] = 12, ['$'] = 13, ['red up'] = 14,
	['red down'] = 15, ['red right'] = 16, ['red left'] = 17, ['up'] = 18, ['down'] = 19,
}

if g_game.isOnline() then
	print('tibiamaps: saia do jogo antes de importar (o minimapa é salvo ao deslogar e sobrescreveria a importação).')
	return
end

-- Mapa: soma as imagens ao que você já explorou (tiles já vistos não são alterados).
g_minimap.clean()
if g_resources.fileExists('/minimap.otmm') then
	g_minimap.loadOtmm('/minimap.otmm')
end
local floors = 0
for z = 0, 15 do
	local file = string.format('%sfloor-%02d-map.png', DIR, z)
	if g_resources.fileExists(file) and g_minimap.loadImage(file, { x = TOP_LEFT.x, y = TOP_LEFT.y, z = z }, 1.0) then
		floors = floors + 1
	end
end
g_minimap.saveOtmm('/minimap.otmm')

-- Marcadores: mantém os seus e acrescenta os do tibiamaps que não estiverem na mesma posição.
local settings = g_settings.getNode('Minimap') or {}
settings.flags = settings.flags or {}
local taken = {}
for _, flag in ipairs(settings.flags) do
	taken[string.format('%d,%d,%d', flag.position.x, flag.position.y, flag.position.z)] = true
end

local added = 0
if g_resources.fileExists(DIR .. 'markers.json') then
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
end
g_settings.setNode('Minimap', settings)
g_settings.save()

print(string.format('tibiamaps: %d andares importados, %d marcadores adicionados. Pode entrar no jogo.', floors, added))
