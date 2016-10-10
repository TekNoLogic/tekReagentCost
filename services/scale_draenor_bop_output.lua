
local myname, ns = ...


local TEMPORAL_CRYSTAL = 113588
local BASE_QUANTITIES = {
	[108257] = 8, -- Truesteel Ingot
	[108996] = 8, -- Alchemical Catalyst
	[109223] = 4, -- Healing Tonic
	[110611] = 8, -- Burnished Leather
	[111366] = 8, -- Gearspring Parts
	[111556] = 8, -- Hexweave Cloth
	[111603] = 4, -- Antiseptic Bandage
	[112377] = 8, -- War Paints
	[115524] = 8, -- Taladite Crystal
	[116979] = 4, -- Blackwater Anti-Venom
	[116981] = 4, -- Fire Ammonite Oil
}

-- Food!
for i=111433,111458 do BASE_QUANTITIES[i] = 4 end


-- Draenor's bind on pick reagent recipies have output that varies with skill
-- Most of them produce 4 or 8 items at or below 600 skill, scaling up to 10 or
-- 20 items at or above 700 skill.
local function ScaleOutput(level, base_qty)
	if level >= 700 then
		return base_qty * 2.5
	elseif level > 600 then
		return math.floor(base_qty + (level-600)/100*base_qty*1.5)
	else
		return base_qty
	end
end


-- Enchanting, of course, is unique because it makes fractured crystals that are
-- combined to make a whole crystal
local function ScaleEnchantingOutput(level)
	if level >= 700 then
		return 1
	elseif level > 600 then
		return (math.floor(3.99 + (level-600)/100*5) / 10)
	else
		return 3
	end
end


function ns.GetNumMade(index, id)
	local _, _, level = C_TradeSkillUI.GetTradeSkillLine()

	if BASE_QUANTITIES[id] then return ScaleOutput(level, BASE_QUANTITIES[id]) end
	if TEMPORAL_CRYSTAL == id then return ScaleEnchantingOutput(level) end

	return C_TradeSkillUI.GetRecipeNumItemsProduced(index)
end
