
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")
local PRIMAL_SPIRIT = 120945


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
	[111556] = 4,
}
local function GetNumMade(index, id)
	local _, level = GetTradeSkillLine()

	-- Temporal Crystal is a unique snowflake
	if id == 113588 then
		if level >= 700 then
			return 1
		elseif level > 600 then
			return (math.floor(3.99 + (level-600)/100*5) / 10)
		else
			return 3
		end
	end

	if edgecases[id] then
		if level >= 700 then
			return 10
		elseif level > 600 then
			return math.floor(4.99 + (level-600)/100*5)
		else
			return 4
		end
	end

	return GetTradeSkillNumMade(index)
end


local function GetReagentCost(id)
	local cost, incomplete, has_primal_spirit = 0
	for i=1,GetTradeSkillNumReagents(id) do
		local link = ns.GetTradeSkillReagentItemLink(id, i)
		if link then
			local _, _, count = GetTradeSkillReagentInfo(id, i)
			local itemid = ns.ids[link]
			if itemid == PRIMAL_SPIRIT then has_primal_spirit = true end
			local price = ns.GetPrice(itemid)
			cost = cost + (price or 0) * count
			if not price then incomplete = true end
		else incomplete = true end
	end

	if not incomplete then
		local link = GetTradeSkillItemLink(id)
		local itemid = link and ns.ids[link]
		if itemid and not has_primal_spirit then
			ns.combineprices[itemid] = cost / (GetNumMade(id, itemid) or 1)
		end
	end

	return cost, incomplete
end


local frames = {}
local function GetCostFrame(i)
	if frames[i] then return frames[i] end

	local butt = _G["TradeSkillSkill"..i]
	local f = butt:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	f:SetPoint("LEFT", 2, 0)
	frames[i] = f
	return f
end


local function UpdateList()
	local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)

	local filtered = TradeSkillFilterBar:IsShown()
	local numShown = TRADE_SKILLS_DISPLAYED - (filtered and 1 or 0)

	for i=1,numShown do
		local skillIndex = i + offset
		local _, skillType = GetTradeSkillInfo(skillIndex)

		local buttonIndex = i + (filtered and 1 or 0)
		local text = GetCostFrame(buttonIndex)

		if skillType == "header" or skillType == "subheader" then
			text:Hide()
		else
			local cost, incomplete = GetReagentCost(skillIndex)
			if incomplete then
				text:SetText(GRAY_FONT_COLOR_CODE.."--")
			else
				text:SetText(ns.GS(cost))
			end
			text:Show()
		end
	end

end


local function UpdateDetailFrame()
	local id = GetTradeSkillSelectionIndex()
	local cost, incomplete = GetReagentCost(GetTradeSkillSelectionIndex())

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
end

local function HookTradeSkill()
	hooksecurefunc("TradeSkillFrame_Update", function()
		UpdateList()
		UpdateDetailFrame()
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
