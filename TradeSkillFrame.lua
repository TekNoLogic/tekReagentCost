
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")
local PRIMAL_SPIRIT = 120945


local detailcost, detailauction
local edgecases = {
	[108257] = 4, -- Truesteel Ingot
	[108996] = 4, -- Alchemical Catalyst
	[109223] = 4, -- Healing Tonic
	[110611] = 4, -- Burnished Leather
	[111603] = 4, -- Antiseptic Bandage
	[111366] = 4, -- Gearspring Parts
	[111556] = 4, -- Hexweave Cloth
	[112377] = 4, -- War Paints
	[115524] = 4, -- Taladite Crystal
	[116979] = 4, -- Blackwater Anti-Venom
	[116981] = 4, -- Fire Ammonite Oil
}
for i=111433,111458 do edgecases[i] = 4 end -- Food!
local function GetNumMade(index, id)
	local _, _, level = C_TradeSkillUI.GetTradeSkillLine()

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

	return C_TradeSkillUI.GetRecipeNumItemsProduced(index)
end


local function GetReagentCost(id)
	local cost, incomplete, has_primal_spirit = 0
	local num = C_TradeSkillUI.GetRecipeNumReagents(id)
	if not num then return 0, true end

	for i=1,num do
		local link = C_TradeSkillUI.GetRecipeReagentItemLink(id, i)
		if link then
			local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(id, i)
			local itemid = ns.ids[link]
			if itemid == PRIMAL_SPIRIT then has_primal_spirit = true end
			local price = ns.GetPrice(itemid)
			cost = cost + (price or 0) * count
			if not price then incomplete = true end
		else incomplete = true end
	end

	if not incomplete then
		local link = C_TradeSkillUI.GetRecipeItemLink(id)
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
	local offset = FauxScrollFrame_GetOffset(TradeSkillFrame.RecipeList)

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
	local id = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
	if not id then return end
	local cost, incomplete = GetReagentCost(id)

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(id)
	if incomplete then
		detailcost:SetText(GRAY_FONT_COLOR_CODE.. "???")
	else
		if recipeInfo.skillType == "optimal" and recipeInfo.numSkillUps > 1 then
			local percost = cost / recipeInfo.numSkillUps
			detailcost:SetText(ns.GS(cost).." - "..ns.GS(percost).. " per skillup")
		else
			detailcost:SetText(ns.GS(cost))
		end
	end

	local link = C_TradeSkillUI.GetRecipeItemLink(id)
	local itemid = link and ns.ids[link]
	local ahprice = itemid and GetAuctionBuyout and GetAuctionBuyout(itemid)
	if ahprice then
		detailauction:SetText(ns.GS(ahprice))
	else
		detailauction:SetText(GRAY_FONT_COLOR_CODE.. "???")
	end
end

local function Init()
	local parent = TradeSkillFrame.DetailsFrame.Contents
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(1, 1)
	f:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -10, -67)
	f:SetScript("OnShow", UpdateDetailFrame)

	local auclabel = f:CreateFontString(nil, nil, "GameFontHighlightSmall")
	auclabel:SetPoint("BOTTOMRIGHT", f)
	auclabel:SetText("AH")

	local costlabel = f:CreateFontString(nil, nil, "GameFontHighlightSmall")
	costlabel:SetPoint("BOTTOMRIGHT", auclabel, "TOPRIGHT")
	costlabel:SetText("Cost")

	detailauction = f:CreateFontString(nil, nil, "GameFontNormalSmall")
	detailauction:SetPoint("TOPRIGHT", costlabel, "BOTTOMLEFT", -5, 0)

	detailcost = f:CreateFontString(nil, nil, "GameFontNormalSmall")
	detailcost:SetPoint("BOTTOMRIGHT", detailauction, "TOPRIGHT")

	hooksecurefunc(TradeSkillFrame.DetailsFrame, "RefreshDisplay", function()
		-- UpdateList()
		UpdateDetailFrame()
	end)
end


function ns.OnLoad()
	if IsAddOnLoaded("Blizzard_TradeSkillUI") then
		Init()
	else
		ns.RegisterEvent("ADDON_LOADED", function(event, addon)
			if addon == "Blizzard_TradeSkillUI" then
				Init()
				ns.UnregisterEvent("ADDON_LOADED")
				ns.ADDON_LOADED = nil
			end
		end)
	end
end
