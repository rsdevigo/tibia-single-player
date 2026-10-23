-- !trade: leva à área de NPCs de compra/venda do mapa custom (Rashid, djinns, Lootmonger, Battlemart...).
-- !temple: volta ao templo da cidade do personagem.
-- Copiado para data-otservbr-global/scripts/custom/ pelo Dockerfile (não existe no fork).
-- A área custom não tem acesso a partir do mapa principal; os NPCs ficam em x 984-1004, y 1019-1037, andar 6.

local config = {
	-- Centro da busca por um piso livre (ajuste com /pos se cair num lugar ruim).
	tradeCenter = Position(995, 1030, 6),
	searchRadius = 6,
}

local function isFree(position)
	local tile = Tile(position)
	if not tile or not tile:isWalkable() then
		return false
	end
	local creature = tile:getTopCreature()
	return not creature
end

local function findFreeTile(center, radius)
	for r = 0, radius do
		for dx = -r, r do
			for dy = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r then
					local position = Position(center.x + dx, center.y + dy, center.z)
					if isFree(position) then
						return position
					end
				end
			end
		end
	end
	return nil
end

local function canTeleport(player)
	if player:isPzLocked() or player:getCondition(CONDITION_INFIGHT, CONDITIONID_DEFAULT) then
		player:sendCancelMessage("You can't use this while in fight.")
		return false
	end
	return true
end

local function teleport(player, destination)
	player:getPosition():sendMagicEffect(CONST_ME_POFF)
	player:teleportTo(destination)
	destination:sendMagicEffect(CONST_ME_TELEPORT)
end

local trade = TalkAction("!trade")

function trade.onSay(player, words, param)
	if not canTeleport(player) then
		return true
	end
	local destination = findFreeTile(config.tradeCenter, config.searchRadius)
	if not destination then
		player:sendCancelMessage("The trade area is not available right now.")
		return true
	end
	teleport(player, destination)
	return true
end

trade:groupType("normal")
trade:register()

local temple = TalkAction("!temple")

function temple.onSay(player, words, param)
	if not canTeleport(player) then
		return true
	end
	teleport(player, player:getTown():getTemplePosition())
	return true
end

temple:groupType("normal")
temple:register()
