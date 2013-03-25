
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")


local function HookTradeSkill()
	local orig = TradeSkillFrame_Update
	TradeSkillFrame_Update = function(...)
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
			if itemid then ns.combineprices[itemid] = cost end
		end
		return orig(...)
	end
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
