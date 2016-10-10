
local myname, ns = ...


local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")


local detailcost, detailauction


function ns.GetRecipeCost(id)
	local cost, incomplete = 0
	local num = C_TradeSkillUI.GetRecipeNumReagents(id)
	if not num then return 0, true end

	local has_bound_reagents
	for i=1,num do
		local link = C_TradeSkillUI.GetRecipeReagentItemLink(id, i)
		if link then
			local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(id, i)
			local itemid = ns.ids[link]
			if ns.bound_reagents[itemid] then
				has_bound_reagents = true
			else
				local price = ns.GetPrice(itemid)
				cost = cost + (price or 0) * count
				if not price then incomplete = true end
			end
		else incomplete = true end
	end

	if not incomplete then
		ns.combineprices["recipe:"..id] = cost

		local link = C_TradeSkillUI.GetRecipeItemLink(id)
		local itemid = link and ns.ids[link]
		ns.has_bound_reagents[itemid] = has_bound_reagents
		if itemid then
			ns.combineprices[itemid] = cost / (ns.GetNumMade(id, itemid) or 1)
		end
	end

	return cost, incomplete
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
		local qty = ns.GetNumMade(id, itemid) or 1
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
