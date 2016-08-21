
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")
local PRIMAL_SPIRIT = 120945


local detailcost, detailauction
local edgecases = {
	[108257] = 8, -- Truesteel Ingot
	[108996] = 8, -- Alchemical Catalyst
	[109223] = 4, -- Healing Tonic
	[110611] = 8, -- Burnished Leather
	[111603] = 4, -- Antiseptic Bandage
	[111366] = 8, -- Gearspring Parts
	[111556] = 8, -- Hexweave Cloth
	[112377] = 8, -- War Paints
	[115524] = 8, -- Taladite Crystal
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

	local baseqty = edgecases[id]
	if baseqty then
		if level >= 700 then
			return baseqty * 2.5
		elseif level > 600 then
			return math.floor(baseqty + (level-600)/100*baseqty*1.5)
		else
			return baseqty
		end
	end

	return C_TradeSkillUI.GetRecipeNumItemsProduced(index)
end


function ns.GetRecipeCost(id)
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
		ns.combineprices["recipe:"..id] = cost

		if not has_primal_spirit then
			local link = C_TradeSkillUI.GetRecipeItemLink(id)
			local itemid = link and ns.ids[link]
			if itemid then
				ns.combineprices[itemid] = cost / (GetNumMade(id, itemid) or 1)
			end
		end
	end

	return cost, incomplete
end


local frames = {}
local function GetCostFrame(i)
	if frames[i] then return frames[i] end

	local f = i:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	f:SetPoint("LEFT", 2, 0)
	frames[i] = f
	return f
end


local function UpdateButton(butt, info)
	local text = GetCostFrame(butt)

	if info.type == "header" or info.type == "subheader" then
		text:Hide()
	else
		local cost, incomplete = ns.GetRecipeCost(info.recipeID)
		if incomplete then
			text:SetText(GRAY_FONT_COLOR_CODE.."--")
		else
			text:SetText(ns.GS(cost))
		end
		text:Show()
	end
end


local function UpdateDetailFrame()
	local id = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
	if not id then return end
	local cost, incomplete = ns.GetRecipeCost(id)

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
		local qty = GetNumMade(id, itemid) or 1
		detailauction:SetText(ns.GS(ahprice*qty))
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

	hooksecurefunc(TradeSkillFrame.DetailsFrame, "RefreshDisplay", UpdateDetailFrame)
	for i,butt in pairs(TradeSkillFrame.RecipeList.buttons) do
		hooksecurefunc(butt, "SetUp", UpdateButton)
	end
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
