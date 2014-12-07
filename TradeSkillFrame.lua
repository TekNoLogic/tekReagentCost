
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")


local edgecases = {
	[108996] = 4,
	[111433] = 4,
	[111436] = 4,
	[111437] = 4,
	[111439] = 4,
	[111441] = 4,
	[111444] = 4,
	[111445] = 4,
	[111446] = 4,
	[111449] = 4,
	[111452] = 4,
	[111455] = 4,
	[111456] = 4,
	[111458] = 4,
}
local function GetNumMade(index, id)
	return edgecases[id] or GetTradeSkillNumMade(index)
end


local function HookTradeSkill()
	hooksecurefunc("TradeSkillFrame_Update", function()
		local id = GetTradeSkillSelectionIndex()
		local cost, incomplete = 0
		for i=1,GetTradeSkillNumReagents(id) do
			local link = ns.GetTradeSkillReagentItemLink(id, i)
			if link then
				local _, _, count = GetTradeSkillReagentInfo(id, i)
				local itemid = tonumber((string.match(link, "item:(%d+):")))
				local price = ns.GetPrice(itemid)
				cost = cost + (price or 0) * count
				if not price then incomplete = true end
			else incomplete = true end
		end

		local _, skillType, _, _, _, numSkillUps = GetTradeSkillInfo(id)
		if incomplete then
			TradeSkillReagentLabel:SetText(SPELL_REAGENTS.." Incomplete price data")
		else
			if skillType == "optimal" and numSkillUps > 1 then
				TradeSkillReagentLabel:SetText(
					SPELL_REAGENTS.." "..ns.GS(cost)..
					" - "..ns.GS(cost / numSkillUps).. " per skillup"
				)
			else
				TradeSkillReagentLabel:SetText(SPELL_REAGENTS.." ".. ns.GS(cost))
			end
		end

		if not incomplete then
			local link = GetTradeSkillItemLink(id)
			local itemid = link and tonumber((string.match(link, "item:(%d+):")))
			if itemid then
				ns.combineprices[itemid] = cost / (GetNumMade(id, itemid) or 1)
			end
		end
	end)
end


function ns.OnLoad()
	if IsAddOnLoaded("Blizzard_TradeSkillUI") then
		HookTradeSkill()
	else
		ns.RegisterEvent("ADDON_LOADED", function(event, addon)
			if addon == "Blizzard_TradeSkillUI" then
				HookTradeSkill()
				ns.UnregisterEvent("ADDON_LOADED")
				ns.ADDON_LOADED = nil
			end
		end)
	end
end
