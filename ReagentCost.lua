
-- Event handler frame, needs cleaned up
local f = CreateFrame("Frame")
f:SetScript("OnLoad", function() FRC_OnLoad() end)
f:SetScript("OnUpdate", function() FRC_OnUpdate(arg1) end)
f:SetScript("OnEvent", function() FRC_OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end)


------------------------------------------------------
-- ReagentCost.lua
------------------------------------------------------

FRC_Config = { };
FRC_Config.Enabled = true;
FRC_Config.MinProfitRatio = 0;
FRC_Config.MinProfitMoney = nil;
FRC_Config.AutoLoadPriceSource = nil;

FRC_ReagentLinks = { };

local MIN_SCANS = 35; -- times an item must be seen at auction to be considered a good sample (equates to 100% on our confidence scale)
local MIN_CONFIDENCE = 5; -- cutoff so we don't report items we have little data on as potentially profitable
local MIN_OVERRIDE_CONFIDENCE = 90; -- cutoff for trusting an item's market price versus the price of its components

-- Anti-freeze code borrowed from ReagentInfo (in turn, from Quest-I-On):
-- keeps WoW from locking up if we try to scan the tradeskill window too fast.
FRC_TradeSkillLock = { };
FRC_TradeSkillLock.NeedScan = false;
FRC_TradeSkillLock.Locked = false;
FRC_TradeSkillLock.EventTimer = 0;
FRC_TradeSkillLock.EventCooldown = 0;
FRC_TradeSkillLock.EventCooldownTime = 1;
FRC_CraftLock = { };
FRC_CraftLock.NeedScan = false;
FRC_CraftLock.Locked = false;
FRC_CraftLock.EventTimer = 0;
FRC_CraftLock.EventCooldown = 0;
FRC_CraftLock.EventCooldownTime = 1;

function FRC_CraftFrame_SetSelection(id)
	FRC_Orig_CraftFrame_SetSelection(id);

	if ( not id ) then
		return;
	end
	local name, rank, maxRank = GetCraftDisplaySkillLine();
	if not (name) then
		return;
	end
	local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(id);
	if ( trainingPointCost and trainingPointCost > 0 ) then
		return;
	end
	if ( craftType == "header" ) then
		return;
	end

	local costText;
	if (FRC_Config.Enabled) then
		local itemLink = GetCraftItemLink(id);
		if (itemLink == nil) then return; end
		local _, _, enchantLink = string.find(itemLink, "(enchant:%d+)");
		local _, _, itemID = string.find(itemLink, "item:(%d+)");
		if (itemID) then
			itemID = tonumber(itemID);
			identifier = itemID;
		elseif (enchantLink) then
			identifier = enchantLink;
		else
			GFWUtils.Print("ReagentCost: Can't parse link "..itemLink.." for recipe "..craftName);
			return;
		end

		local materialsTotal, confidenceScore = FRC_MaterialsCost(name, identifier);
		costText = GFWUtils.LtY("(Total cost: ");
		if (materialsTotal == nil) then
			costText = costText .. GFWUtils.Gray("Unknown [insufficient data]");
		else
			costText = costText .. GFWUtils.TextGSC(materialsTotal) ..GFWUtils.Gray(" Confidence: "..confidenceScore.."%");
		end
		costText = costText ..GFWUtils.LtY(")");

		CraftReagentLabel:SetText(SPELL_REAGENTS.." "..costText);
		CraftReagentLabel:Show();
	end

end

function FRC_TradeSkillFrame_SetSelection(id)
	FRC_Orig_TradeSkillFrame_SetSelection(id);

	if ( not id ) then
		return;
	end
	local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(id);
	if ( skillType == "header" ) then
		return;
	end
	local skillLineName, skillLineRank, skillLineMaxRank = GetTradeSkillLine();

	local costText;
	if (FRC_Config.Enabled) then
		local link = GetTradeSkillItemLink(id);
		if (link == nil) then return; end
		local _, _, itemID = string.find(link, "item:(%d+)");
		itemID = tonumber(itemID);

		local materialsTotal, confidenceScore = FRC_MaterialsCost(skillLineName, itemID);
		costText = GFWUtils.LtY("(Total cost: ");
		if (materialsTotal == nil) then
			costText = costText .. GFWUtils.Gray("Unknown [insufficient data]");
		else
			costText = costText .. GFWUtils.TextGSC(materialsTotal) ..GFWUtils.Gray(" Confidence: "..confidenceScore.."%");
		end
		costText = costText ..GFWUtils.LtY(")");

		TradeSkillReagentLabel:SetText(SPELL_REAGENTS.." "..costText);
		TradeSkillReagentLabel:Show();
	end

end

function FRC_TradeSkillFrame_Update()
	FRC_Orig_TradeSkillFrame_Update();

	FRC_ScanTradeSkill();
end

function FRC_CraftFrame_Update()
	FRC_Orig_CraftFrame_Update();

	FRC_ScanCraft();
end

function FRC_OnLoad()

	this:RegisterEvent("CRAFT_SHOW");
	this:RegisterEvent("CRAFT_UPDATE");
	this:RegisterEvent("TRADE_SKILL_SHOW");
	this:RegisterEvent("TRADE_SKILL_UPDATE");
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("VARIABLES_LOADED");

end

function FRC_OnUpdate(elapsed)
	-- If it's been more than a second since our last tradeskill update,
	-- we can allow the event to process again.
	FRC_TradeSkillLock.EventTimer = FRC_TradeSkillLock.EventTimer + elapsed;
	if (FRC_TradeSkillLock.Locked) then
		FRC_TradeSkillLock.EventCooldown = FRC_TradeSkillLock.EventCooldown + elapsed;
		if (FRC_TradeSkillLock.EventCooldown > FRC_TradeSkillLock.EventCooldownTime) then

			FRC_TradeSkillLock.EventCooldown = 0;
			FRC_TradeSkillLock.Locked = false;
		end
	end
	FRC_CraftLock.EventTimer = FRC_CraftLock.EventTimer + elapsed;
	if (FRC_CraftLock.Locked) then
		FRC_CraftLock.EventCooldown = FRC_CraftLock.EventCooldown + elapsed;
		if (FRC_CraftLock.EventCooldown > FRC_CraftLock.EventCooldownTime) then

			FRC_CraftLock.EventCooldown = 0;
			FRC_CraftLock.Locked = false;
		end
	end

	if (FRC_TradeSkillLock.NeedScan) then
		FRC_TradeSkillLock.NeedScan = false;
		FRC_ScanTradeSkill();
	end
	if (FRC_CraftLock.NeedScan) then
		FRC_CraftLock.NeedScan = false;
		FRC_ScanCraft();
	end
end

function FRC_OnEvent(event)

	if (event == "ADDON_LOADED" and (arg1 == "Blizzard_CraftUI" or IsAddOnLoaded("Blizzard_CraftUI"))) then
		if (FRC_Orig_CraftFrame_SetSelection == nil) then
			-- Overrides for displaying info in CraftFrame
			FRC_Orig_CraftFrame_SetSelection = CraftFrame_SetSelection;
			CraftFrame_SetSelection = FRC_CraftFrame_SetSelection;

			-- And for scanning, since it looks like doing it in event handlers is crashy/unreliable now.
			FRC_Orig_CraftFrame_Update = CraftFrame_Update;
			CraftFrame_Update = FRC_CraftFrame_Update;

			--GFWUtils.Print("ReagentCost CraftFrame hooks installed.");
		end
	end

	if (event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or IsAddOnLoaded("Blizzard_TradeSkillUI"))) then
		if (FRC_Orig_TradeSkillFrame_SetSelection == nil) then
			-- Overrides for displaying info in TradeSkillFrame
			FRC_Orig_TradeSkillFrame_SetSelection = TradeSkillFrame_SetSelection;
			TradeSkillFrame_SetSelection = FRC_TradeSkillFrame_SetSelection;

			-- And for scanning, since it looks like doing it in event handlers is crashy/unreliable now.
			FRC_Orig_TradeSkillFrame_Update = TradeSkillFrame_Update;
			TradeSkillFrame_Update = FRC_TradeSkillFrame_Update;

			--GFWUtils.Print("ReagentCost TradeSkillFrame hooks installed.");
		end
	end

	if ( event == "VARIABLES_LOADED" or event == "ADDON_LOADED" ) then

		if (FRC_Config == nil) then
			FRC_Config = {};
			FRC_Config.Enabled = true;
			FRC_Config.MinProfitRatio = 0;
		end
		return;
	end

	if ( event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" and FRC_Config.Enabled) then

		if (event == "CRAFT_SHOW" and GetCraftDisplaySkillLine() == nil) then
			-- Beast Training uses the CraftFrame; we can tell when it's up because it doesn't have a skill-level bar.
			-- We don't have anything to do in that case, so let's not try loading Auctioneer and stuff.
			return;
		end
	end

	if ( event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" ) then

		FRC_ScanTradeSkill();

	elseif ( event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" ) then

		FRC_ScanCraft();

	end

end

function FRC_ScanTradeSkill()
	if (not TradeSkillFrame or not TradeSkillFrame:IsVisible() or FRC_TradeSkillLock.Locked) then return; end
	-- This prevents further update events from being handled if we're already processing one.
	-- This is done to prevent the game from freezing under certain conditions.
	FRC_TradeSkillLock.Locked = true;

	local skillLineName, skillLineRank, skillLineMaxRank = GetTradeSkillLine();
	if not (skillLineName) then
		FRC_TradeSkillLock.NeedScan = true;
		return; -- apparently sometimes we're called too early, this is nil, and all hell breaks loose.
	end
	if (FRC_ReagentLinks == nil) then
		FRC_ReagentLinks = { };
	end
	if (FRC_ReagentLinks[skillLineName] == nil) then
		FRC_ReagentLinks[skillLineName] = { };
	end

	local realm = GetRealmName();
	local player = UnitName("player");
	if (FRC_KnownRecipes == nil) then
		FRC_KnownRecipes = {};
	end
	if (FRC_KnownRecipes[realm] == nil) then
		FRC_KnownRecipes[realm] = {};
	end
	if (FRC_KnownRecipes[realm][player] == nil) then
		FRC_KnownRecipes[realm][player] = {};
	end
	if (GetTradeSkillItemNameFilter() == nil and not TradeSkillFrameAvailableFilterCheckButton:GetChecked()) then
		-- only start from zero if we're sure the tradeskill window currently shows everything known
		FRC_KnownRecipes[realm][player][skillLineName] = {};
	end
	if (FRC_ItemInfoCache == nil) then
		FRC_ItemInfoCache = {};
	end
	for id = GetNumTradeSkills(), 1, -1 do
		-- loop from the bottom up, since the reagents we make for compound items are usually below the recipes that need them
		local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(id);
		if ( skillType ~= "header" ) then
			local itemLink = GetTradeSkillItemLink(id);
			if (itemLink == nil) then
				FRC_TradeSkillLock.NeedScan = true;
			else
				local numReagents = GetTradeSkillNumReagents(id);
				if (numReagents == nil) then
					FRC_TradeSkillLock.NeedScan = true;
					break;
				end

				local reagentInfo = {};
				for i=1, numReagents do
					local link = GetTradeSkillReagentItemLink(id, i);
					if (link == nil) then
						FRC_TradeSkillLock.NeedScan = true;
						break;
					else
						local _, _, reagentID = string.find(link, "item:(%d+)");
						reagentID = tonumber(reagentID);
						FRC_AddItemInfo(reagentID);

						local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(id, i);
						table.insert(reagentInfo, {id=reagentID, count=reagentCount});
					end
				end
				if (#reagentInfo > 0) then
					FRC_AddReagentInfo(skillLineName, skillName, itemLink, reagentInfo);
				end
			end
		end
	end

end

function FRC_ScanCraft()
	if (not CraftFrame or not CraftFrame:IsVisible() or FRC_CraftLock.Locked) then return; end
	-- This prevents further update events from being handled if we're already processing one.
	-- This is done to prevent the game from freezing under certain conditions.
	FRC_CraftLock.Locked = true;

	-- This is used only for Enchanting
	local skillLineName, rank, maxRank = GetCraftDisplaySkillLine();
	if not (skillLineName) then
		return; -- Hunters' Beast Training also uses the CraftFrame, but doesn't have a SkillLine.
	end
	if (FRC_ReagentLinks == nil) then
		FRC_ReagentLinks = { };
	end
	if (FRC_ReagentLinks[skillLineName] == nil) then
		FRC_ReagentLinks[skillLineName] = { };
	end

	local realm = GetRealmName();
	local player = UnitName("player");
	if (FRC_KnownRecipes == nil) then
		FRC_KnownRecipes = {};
	end
	if (FRC_KnownRecipes[realm] == nil) then
		FRC_KnownRecipes[realm] = {};
	end
	if (FRC_KnownRecipes[realm][player] == nil) then
		FRC_KnownRecipes[realm][player] = {};
	end
	if (GetCraftItemNameFilter() == nil and not CraftFrameAvailableFilterCheckButton:GetChecked()) then
		-- only start from zero if we're sure the craft window currently shows everything known
		FRC_KnownRecipes[realm][player][skillLineName] = {};
	end
	if (FRC_ItemInfoCache == nil) then
		FRC_ItemInfoCache = {};
	end
	for id = GetNumCrafts(), 1, -1 do
		if ( craftType ~= "header" ) then
			craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(id);
			local itemLink = GetCraftItemLink(id);
			if (itemLink == nil) then
				FRC_TradeSkillLock.NeedScan = true;
			else
				local numReagents = GetCraftNumReagents(id);
				if (numReagents == nil) then
					FRC_CraftLock.NeedScan = true;
					break;
				end

				local reagentInfo = {};
				for i=1, numReagents do
					local link = GetCraftReagentItemLink(id, i);
					if (link == nil) then
						FRC_CraftLock.NeedScan = true;
						break;
					else
						local _, _, reagentID = string.find(link, "item:(%d+)");
						reagentID = tonumber(reagentID);
						FRC_AddItemInfo(reagentID);

						local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(id, i);
						table.insert(reagentInfo, {id=reagentID, count=reagentCount});
					end
				end
				if (#reagentInfo > 0) then
					FRC_AddReagentInfo(skillLineName, craftName, itemLink, reagentInfo);
				end
			end
		end
	end
end

function FRC_AddReagentInfo(tradeskill, recipe, link, reagentInfo)
	local realm = GetRealmName();
	local player = UnitName("player");
	local identifier;

	local _, _, itemID = string.find(link, "item:(%d+)");
	local _, _, enchantLink = string.find(link, "(enchant:%d+)");
	if (itemID) then
		itemID = tonumber(itemID);
		FRC_AddItemInfo(itemID);
		identifier = itemID;
	elseif (enchantLink) then
		identifier = enchantLink;
	else
		GFWUtils.Print("ReagentCost: Can't parse link "..link.." for recipe "..recipe);
		return;
	end

	table.insert(FRC_KnownRecipes[realm][player][tradeskill], identifier);
	FRC_ReagentLinks[tradeskill][identifier] = { };
	FRC_ReagentLinks[tradeskill][identifier][recipe] = { };
	for _, reagent in pairs(reagentInfo) do
		table.insert(FRC_ReagentLinks[tradeskill][identifier][recipe], reagent);
	end
end

function FRC_AddItemInfo(itemID)
	if (FRC_ItemInfoCache[itemID] == nil) then
		local name, _, quality = GetItemInfo(itemID);
		FRC_ItemInfoCache[itemID] = { n=name, q=quality };
	end
end

function FRC_AdjustedCost(skillName, itemID)

	local itemPrice, itemConfidence = FRC_TypicalItemPrice(itemID);
	if (FRC_RecursiveItems == nil) then
		FRC_RecursiveItems = {};
	end
	if (FRC_RecursiveItems[itemID]) then
		FRC_RecursiveItems = nil;
		--GFWUtils.Print("recursion loop, aborting")
		return itemPrice, itemConfidence, false;
	else
		FRC_RecursiveItems[itemID] = 1;
	end

	-- don't calculate sub-reagent prices for the likes of alchemical transumutes
	-- (recipes that take one reagent also produced by the same skill and produce one other such reagent)
	if (FRC_ReagentLinks[skillName] and FRC_ReagentLinks[skillName][itemID]) then
		for recipe, reagentsList in pairs(FRC_ReagentLinks[skillName][itemID]) do
			if (table.getn(reagentsList) == 1 ) then
				local reagentInfo = reagentsList[1];
				if (reagentInfo.count == 1 and FRC_ReagentLinks[skillName][reagentInfo.id]) then
					--GFWUtils.Print("likely transmute, aborting recursion")
					return itemPrice, itemConfidence, false;
				end
			end
		end
	end

	-- for all other recipes, calculate total cost of reagents which might be produced by the same skill,
	-- and use that amount if it's more reliable.
	-- (e.g. engineering parts -> base reagents, bolts of cloth -> pieces of cloth)
	local subReagentsPrice, subReagentsConfidence = FRC_MaterialsCost(skillName, itemID);
	if (subReagentsPrice and subReagentsConfidence) then
		if (not (itemPrice and itemConfidence)) then
			return subReagentsPrice, subReagentsConfidence, true;
		end
		if (subReagentsConfidence >= itemConfidence and itemConfidence < MIN_OVERRIDE_CONFIDENCE and subReagentsPrice < itemPrice) then
			return subReagentsPrice, subReagentsConfidence, true;
		end
	end
	return itemPrice, itemConfidence, false;
end

function FRC_MaterialsCost(skillName, itemID)
	if (FRC_ReagentLinks[skillName] == nil) then
		return nil, nil;
	end
	if (FRC_ReagentLinks[skillName][itemID] == nil) then
		return nil, nil;
	end

	local pricesPerRecipe = {};
	for recipe in pairs(FRC_ReagentLinks[skillName][itemID]) do
		if (type(recipe) == "string") then
			local cost, confidence = FRC_MaterialsCostForRecipe(skillName, itemID, recipe);
			if (cost) then
				table.insert(pricesPerRecipe, {cost=cost, confidence=confidence});
			end
		end
	end
	if (table.getn(pricesPerRecipe) == 0) then
		return nil, nil;
	end

	local sortCost = function(a,b)
		return a.cost < b.cost;
	end
	local sortConfidence = function(a,b)
		return a.confidence > b.confidence;
	end
	table.sort(pricesPerRecipe, sortConfidence);
	table.sort(pricesPerRecipe, sortCost);

	return pricesPerRecipe[1].cost, pricesPerRecipe[1].confidence;

end

function FRC_MaterialsCostForRecipe(skillName, itemID, recipeName)
	local materialsTotal = 0;
	local totalConfidence = 0;
	local numAuctionReagents = 0;

	if (FRC_ReagentLinks[skillName] == nil) then
		return nil, nil;
	end
	if (FRC_ReagentLinks[skillName][itemID] == nil) then
		return nil, nil;
	end
	if (FRC_ReagentLinks[skillName][itemID][recipeName] == nil) then
		return nil, nil;
	end

	for _, reagentInfo in pairs(FRC_ReagentLinks[skillName][itemID][recipeName]) do
		local price, confidence = FRC_AdjustedCost(skillName, reagentInfo.id);
		if (price == nil) then
			return nil, nil; -- if any of the reagents is missing price info, we can't calculate a total.
		end
		materialsTotal = materialsTotal + (price * reagentInfo.count);
		if (confidence >= 0) then
			totalConfidence = totalConfidence + confidence;
			numAuctionReagents = numAuctionReagents + 1;
		end
	end
	local confidenceScore = math.floor(totalConfidence / numAuctionReagents);

	return materialsTotal, confidenceScore;

end

function FRC_TypicalItemPrice(itemID)
	if not itemID then return end
	if FRC_VendorBuyPrices[itemID] then return FRC_VendorBuyPrices[itemID], -1 end
	if GetAuctionBuyout then return GetAuctionBuyout(itemID), 1 end
end

function FRC_GetItemInfo(itemID)
	local name, link, quality = GetItemInfo(itemID);
	local isCached = (name ~= nil);
	if (name == nil and FRC_ItemInfoCache[itemID]) then
		name = FRC_ItemInfoCache[itemID].n;
		quality = FRC_ItemInfoCache[itemID].q;
		link = "item:"..itemID;
	end
	return name, link, quality, isCached;
end

function FRC_GetItemLink(itemID)
	local name, link, quality, isCached = FRC_GetItemInfo(itemID);
	if (string.find(link, "|c%x+|Hitem:[-%d:]+|h%[.-%]|h|r")) then
		return link;
	elseif (isCached) then
		local _, _, _, color = GetItemQualityColor(quality);
		local linkFormat = "%s|H%s|h[%s]|h|r";
		return string.format(linkFormat, color, link, name);
	else
		local _, _, _, color = GetItemQualityColor(quality);
		return color..name..FONT_COLOR_CODE_CLOSE;
	end
end
