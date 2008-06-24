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
			if (FRC_PriceSource and not IsAddOnLoaded(FRC_PriceSource)) then
				costText = costText .. GFWUtils.Gray("["..FRC_PriceSource.." not loaded]");
			else
				costText = costText .. GFWUtils.Gray("Unknown [insufficient data]");
			end
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
			if (FRC_PriceSource and not IsAddOnLoaded(FRC_PriceSource)) then
				costText = costText .. GFWUtils.Gray("["..FRC_PriceSource.." not loaded]");
			else
				costText = costText .. GFWUtils.Gray("Unknown [insufficient data]");
			end
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
	
	FRC_GetPriceSource();
	
	-- Register Slash Commands
	SLASH_FRC1 = "/reagentcost";
	SLASH_FRC2 = "/rc";
	SlashCmdList["FRC"] = function(msg)
		FRC_ChatCommandHandler(msg);
	end

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
		FRC_GetPriceSource();
		return;
	end
	
	if ( event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" and FRC_Config.Enabled) then
	
		if (event == "CRAFT_SHOW" and GetCraftDisplaySkillLine() == nil) then
			-- Beast Training uses the CraftFrame; we can tell when it's up because it doesn't have a skill-level bar.
			-- We don't have anything to do in that case, so let's not try loading Auctioneer and stuff.
			return;		
		end
		
		FRC_GetPriceSource();
		if ( FRC_PriceSource == nil) then
			GFWUtils.Print("ReagentCost: missing required dependency. Can't find a compatible auction pricing addon.");
			return;
		end
		FRC_LoadPriceSourceIfNeeded();
	end

	if ( event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" ) then

		FRC_ScanTradeSkill();
		
	elseif ( event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" ) then
	
		FRC_ScanCraft();
		
	end

end

function FRC_ChatCommandHandler(msg)

	if (FRC_PriceSource == nil) then
		GFWUtils.Print("ReagentCost is installed but non-functional; can't find a compatible auction pricing addon.");
		return;
	end

	-- Print Help
	if ( msg == "help" ) or ( msg == "" ) then
		local version = GetAddOnMetadata("GFW_ReagentCost", "Version");
		GFWUtils.Print("Fizzwidget Reagent Cost "..version..":");
		GFWUtils.Print("/reagentcost (or /rc) <command>");
		GFWUtils.Print("- "..GFWUtils.Hilite("help").." - Print this helplist.");
		GFWUtils.Print("- "..GFWUtils.Hilite("status").." - Check current settings.");
		GFWUtils.Print("- "..GFWUtils.Hilite("reset").." - Reset to default settings.");
		GFWUtils.Print("- "..GFWUtils.Hilite("on").." | "..GFWUtils.Hilite("off").." - Toggle displaying info in tradeskill windows.");
		if (FRC_PriceSourceIsLoadOnDemand) then
			GFWUtils.Print("- "..GFWUtils.Hilite("autoload on").." | "..GFWUtils.Hilite("off").." - Control whether to automatically load "..FRC_PriceSource.." when showing tradeskill windows.");
		end
		GFWUtils.Print("- "..GFWUtils.Hilite("report [<skillname>]").." - Output a list of the most profitable tradeskill items you can make. (Or only those produced through <skillname>.)");
		GFWUtils.Print("- "..GFWUtils.Hilite("minprofit <number>").." - When reporting, only show items whose estimated profit is <number> or greater. (In copper, so 1g == 10000.)");
		GFWUtils.Print("- "..GFWUtils.Hilite("minprofit <number>%").." - When reporting, only show items whose estimated profit exceeds its cost of materials by <number> percent or more.");
		return;
	end

	if (msg == "version") then
		local version = GetAddOnMetadata("GFW_ReagentCost", "Version");
		GFWUtils.Print("Fizzwidget Reagent Cost "..version);
		return;
	end
		
	-- Check Status
	if ( msg == "status" ) then
		if (FRC_Config.Enabled) then
			GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("is").." displaying materials cost in tradeskill windows.");
			if (FRC_Config.AutoLoadPriceSource) then
				GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("will").." automatically load Auctioneer to show prices in tradeskill windows.");
			else
				GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("will not").." automatically load Auctioneer; prices will not be shown in tradeskill windows until Auctioner is loaded some other way.");
			end
		else
			GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("is not").." displaying materials cost in tradeskill windows.");
		end
		if (FRC_Config.MinProfitMoney == nil) then
			GFWUtils.Print("Reports will only include items whose estimated profit exceeds materials cost by "..GFWUtils.Hilite(FRC_Config.MinProfitRatio.."%").." or more.");
		else
			GFWUtils.Print("Reports will only include items whose estimated profit is "..GFWUtils.TextGSC(FRC_Config.MinProfitMoney).." or greater.");
		end
		return;
	end

	-- Reset Variables
	if ( msg == "reset" ) then
		FRC_Config.Enabled = true;
		FRC_Config.MinProfitRatio = 0;
		FRC_Config.MinProfitMoney = nil;
		GFWUtils.Print("Reagent Cost configuration reset.");
		FRC_ChatCommandHandler("status");
		return;
	end
	
	-- Turn trade info gathering on
	if ( msg == "on" ) then
		FRC_Config.Enabled = true;
		GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("is").." displaying materials cost in tradeskill windows.");
		return;
	end
	
	-- Turn trade info gathering Off
	if ( msg == "off" ) then
		FRC_Config.Enabled = false;
		GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("is not").." displaying materials cost in tradeskill windows.");
		return;
	end

	if ( msg == "autoload on" ) then
		FRC_Config.AutoLoadPriceSource = true;
		GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("will").." automatically load Auctioneer to show prices in tradeskill windows.");
		return;
	end
	if ( msg == "autoload off" ) then
		FRC_Config.AutoLoadPriceSource = nil;
		GFWUtils.Print("Reagent Cost "..GFWUtils.Hilite("will not").." automatically load Auctioneer; prices will not be shown in tradeskill windows until Auctioner is loaded some other way.");
		return;
	end

	local _, _, cmd, args = string.find(msg, "(%w+) *(.*)");
	if ( cmd == "minprofit" ) then

		local _, _, number, isPercent = string.find(msg, "minprofit (-*%d+)(%%*)");
		if (number == nil) then
			GFWUtils.Print("Usage: "..GFWUtils.Hilite("/rc minprofit <number>[%]"));
			return;
		end
		if (isPercent == "%") then
			FRC_Config.MinProfitRatio = tonumber(number);
			FRC_Config.MinProfitMoney = nil;
			GFWUtils.Print("Reports will only include items whose estimated profit exceeds materials cost by "..GFWUtils.Hilite(FRC_Config.MinProfitRatio.."%").." or more.");
		else
			FRC_Config.MinProfitRatio = nil;
			FRC_Config.MinProfitMoney = tonumber(number);
			GFWUtils.Print("Reports will only include items whose estimated profit is "..GFWUtils.TextGSC(FRC_Config.MinProfitMoney).." or greater.");
		end
		return;
	end

	if ( cmd == "reagents" or cmd == "report" ) then
		
		FRC_LoadPriceSourceIfNeeded(true);
		
		-- check second arg
		local _, _, arg1, moreArgs = string.find(args, "(%w+) *(.*)");
		local scope = "toon";
		if (arg1 == "all") then
			scope = "realm";
			args = moreArgs;
		elseif (arg1 == "allrealms") then
			scope = "all";
			args = moreArgs;
		end
		
		-- parse skill names from args
		local mySkills = { };
		if (args and args ~= "") then
			for word in string.gmatch(args, "[^%s]+") do
				local niceWord = string.upper(string.sub(word, 1, 1))..string.sub(word, 2);
				table.insert(mySkills, niceWord);
			end
		end
		
		-- if no args, use the skills this character knows
		if (table.getn(mySkills) == 0) then
			for skillIndex = 1, GetNumSkillLines() do
				local skillName, _, _, _, _, _, _, isAbandonable = GetSkillLineInfo(skillIndex);
				if (isAbandonable) then
					table.insert(mySkills, skillName);
				end
			end
		end
		
		local printList;
		if (cmd == "report") then
			printList = FRC_ReportForSkill;
		elseif (cmd == "reagents") then
			printList = FRC_ListAllReagents;
		end
		for _, skillName in pairs(mySkills) do
			printList(skillName, scope);
		end
		
		return;
	end
	
	local linksFound;
	FRC_LoadPriceSourceIfNeeded(true);
	for itemLink in string.gmatch(msg, "(|c%x+|Hitem:[-%d:]+|h%[.-%]|h|r)") do
		linksFound = true;
		local _, _, itemID = string.find(itemLink, "item:([-%d]+)");
		itemID = tonumber(itemID);
		
		local found = false;
		for skillName, skillTable in pairs(FRC_ReagentLinks) do
			if (skillTable[itemID]) then
				for recipe, reagentList in pairs(skillTable[itemID]) do
					
					-- differentiate cases where an item can be made by multiple recipes
					-- by checking to see if the name of the recipe matches the name of the item
					if (string.find(itemLink, "%["..recipe.."%]")) then
						GFWUtils.Print(itemLink.." ("..skillName.."):");
					else
						GFWUtils.Print(itemLink.." ("..skillName.." - "..recipe.."):");
					end
					found = true;
					for _, reagentInfo in pairs(reagentList) do
						if (type(reagentInfo) == "table") then
							local price, confidence, isAdjusted = FRC_GetAdjustedCost(skillName, reagentInfo.id);						
							local adjustedText, confidenceText;
							if (isAdjusted) then
								adjustedText = "(based on component prices)";
							else
								adjustedText = "";
							end
							if (confidence < 0) then
								confidenceText = "from vendor";
							else
								confidenceText = confidence.."%"
							end
							local _, link = GetItemInfo(reagentInfo.id);
							if (not link) then
								link = string.format("[#%d]", reagentInfo.id);
							end
							if (price) then
								GFWUtils.Print(GFWUtils.Hilite(reagentInfo.count.."x ")..link..": "..GFWUtils.TextGSC(price * reagentInfo.count)..GFWUtils.Gray(" ("..confidenceText..") ")..adjustedText);
							else
								GFWUtils.Print(GFWUtils.Hilite(reagentInfo.count.."x ")..link..": No price data");
							end
						end
					end
			
					local itemPrice, itemConfidence = FRC_TypicalItemPrice(itemID);
					local materialsCost, matsConfidence = FRC_MaterialsCostForRecipe(skillName, itemID, recipe);
					local profit = itemPrice - materialsCost;
					local profitText;
					if (profit > 0) then
						profitText = "profit ".. GFWUtils.TextGSC(profit);
					elseif (profit == 0) then
						profitText = GFWUtils.Hilite("(break-even)");
					else
						profitText = GFWUtils.Red("loss ").. GFWUtils.TextGSC(math.abs(profit));
					end
					if (materialsCost) then
						GFWUtils.Print("Total materials: "..GFWUtils.TextGSC(materialsCost)..GFWUtils.Gray("("..matsConfidence..")"));
					else
						GFWUtils.Print("Total materials: data not available for one or more reagents");
					end
					if (itemPrice) then
						GFWUtils.Print("Auction price: "..GFWUtils.TextGSC(itemPrice)..GFWUtils.Gray("("..itemConfidence..")").."; "..profitText);
					else
						GFWUtils.Print("Auction price: data not available");
					end
				end
			end
		end
		if (not found) then
			GFWUtils.Print(itemLink.." not found in tradeskill data.");
		end
	end
	
	-- If we get down to here, we got bad input.
	if (not linksFound) then
		FRC_ChatCommandHandler("help");
	end
end

function FRC_ListAllReagents(skillName, scope)
	local itemsTable = FRC_ReagentLinks[skillName];
	if (itemsTable == nil) then
		if (ReagentData == nil) then
			GFWUtils.Print("Nothing for "..GFWUtils.Hilite(skillName)..".");
		elseif (ReagentData['reversegathering'][skillName]) then
			-- do nothing; don't want to barf errors about gathering skills...
		elseif (ReagentData['reverseprofessions'][skillName]) then
			GFWUtils.Print("ReagentCost doesn't have information on "..GFWUtils.Hilite(skillName)..". Please open your "..GFWUtils.Hilite(skillName).." window before requesting a report.");
		else
			GFWUtils.Print(GFWUtils.Hilite(skillName).." is not a known profession.");
		end
	else
		local realm = GetRealmName();
		local player = UnitName("player");
		for anItem, recipesTable in pairs(itemsTable) do
			for recipe, reagentList in pairs(recipesTable) do
				local known;
				if (scope == "toon") then
					if (FRC_KnownRecipes and FRC_KnownRecipes[realm] and FRC_KnownRecipes[realm][player]) then
						for skillLine, items in pairs(FRC_KnownRecipes[realm][player]) do
							if (GFWTable.KeyOf(items, anItem)) then
								known = true;
								break;
							end
						end
					end
				elseif (scope == "realm") then
					if (FRC_KnownRecipes and FRC_KnownRecipes[realm]) then
						for player, skillLines in pairs(FRC_KnownRecipes[realm]) do
							for skillLine, items in pairs(skillLine) do
								if (GFWTable.KeyOf(items, anItem)) then
									known = true;
									break;
								end
							end
						end				
					end
				else
					known = true;
				end				
		
				if (known) then
					local itemString;
					if (type(anItem) == "number") then
						itemString = FRC_GetItemLink(anItem)..": ";
					else
						itemString = recipe..": ";
					end
					for _, aReagent in pairs(reagentsTable) do
						itemString = itemString.. aReagent.count .. "x" .. aReagent.id .. ", ";
					end
					itemString = string.gsub(itemString, ", $", "");
					GFWUtils.Print(itemString);
				end
			end
		end
	end
end

function FRC_ReportForSkill(skillName, scope)
	local knownItems = 0;
	local reliableItems = 0;
	local shownItems = 0;
	local itemsTable = FRC_ReagentLinks[skillName];
	
	if (itemsTable == nil) then
		if (ReagentData == nil) then
			GFWUtils.Print("Nothing for "..GFWUtils.Hilite(skillName)..".");
		elseif (ReagentData['reversegathering'][skillName]) then
			-- do nothing; don't want to barf errors about gathering skills...
			if (skillName == ReagentData['gathering']['mining']) then
				-- ...except for Mining, which is also a production skill as far as we're concerned.
				GFWUtils.Print("ReagentCost doesn't have information on "..GFWUtils.Hilite(skillName)..". Please open your "..GFWUtils.Hilite(skillName).." window before requesting a report.");
			end
		elseif (ReagentData['reverseprofessions'][skillName]) then
			GFWUtils.Print("ReagentCost doesn't have information on "..GFWUtils.Hilite(skillName)..". Please open your "..GFWUtils.Hilite(skillName).." window before requesting a report.");
		else
			GFWUtils.Print(GFWUtils.Hilite(skillName).." is not a known profession.");
		end
		return;
	end
	
	local reportTable = { }; -- separate report for each skill

	-- first, build a table that includes current Auctioneer prices for composite items
	local realm = GetRealmName();
	local player = UnitName("player");
	for anItem in pairs(itemsTable) do
		local known;
		if (scope == "toon") then
			if (FRC_KnownRecipes and FRC_KnownRecipes[realm] and FRC_KnownRecipes[realm][player]) then
				for skillLine, items in pairs(FRC_KnownRecipes[realm][player]) do
					if (GFWTable.KeyOf(items, anItem)) then
						known = true;
						break;
					end
				end
			end
		elseif (scope == "realm") then
			if (FRC_KnownRecipes and FRC_KnownRecipes[realm]) then
				for player, skillLines in pairs(FRC_KnownRecipes[realm]) do
					for skillLine, items in pairs(skillLine) do
						if (GFWTable.KeyOf(items, anItem)) then
							known = true;
							break;
						end
					end
				end				
			end
		else
			known = true;
		end				

		if (known and type(anItem) == "number") then
			-- it's an item, not an enchant (which isn't auctionable, and thus doesn't have a price to compare)
			local itemID = anItem;
			for recipe in pairs(FRC_ReagentLinks[skillName][itemID]) do
				knownItems = knownItems + 1;
				local itemPrice, itemConfidence = FRC_TypicalItemPrice(itemID);
				local materialsCost, matsConfidence = FRC_MaterialsCostForRecipe(skillName, itemID, recipe);
	
				if (itemConfidence == nil) then itemConfidence = 0; end
				if (matsConfidence == nil) then matsConfidence = 0; end
	
				if (itemConfidence >= MIN_CONFIDENCE and matsConfidence >= MIN_CONFIDENCE) then
					reliableItems = reliableItems + 1;
					local profit = itemPrice - materialsCost;
					local itemLink = FRC_GetItemLink(itemID);
					table.insert(reportTable, {link=itemLink, recipe=recipe, matsCost=materialsCost, matsConf=matsConfidence, itemPrice=itemPrice, itemConf=itemConfidence, profit=profit});
				end
			end
		end
	end
	

	if (knownItems == 0) then 
		GFWUtils.Print("ReagentCost doesn't know of any items you can make with "..GFWUtils.Hilite(skillName)..". Please open your "..GFWUtils.Hilite(skillName).." window before requesting a report.");
		return;
	end
	
	if (reliableItems == 0) then 
		GFWUtils.Print("None of the "..GFWUtils.Hilite(knownItems).." items you can make with "..GFWUtils.Hilite(skillName).." have reliable auction price data. (They may not be tradeable.)");
		return;
	end
	
	GFWUtils.Print("Most profitable recipes for "..GFWUtils.Hilite(skillName)..":");

	if (reliableItems > 1) then
		table.sort(reportTable, FRC_SortProfit);
	end
	
	-- and report those that meet our minimum requirements
	for _, reportInfo in pairs(reportTable) do
		if (FRC_Config.MinProfitRatio and (reportInfo.profit / reportInfo.matsCost * 100) >= FRC_Config.MinProfitRatio) then
			shownItems = shownItems + 1;
			FRC_PrintReportLine(reportInfo);
		elseif (FRC_Config.MinProfitMoney and reportInfo.profit >= FRC_Config.MinProfitMoney) then
			shownItems = shownItems + 1;
			FRC_PrintReportLine(reportInfo);
		end
	end
	GFWUtils.Print(GFWUtils.Hilite(knownItems).." recipes known, "..GFWUtils.Hilite(reliableItems).." with auction data, "..GFWUtils.Hilite(shownItems).." above profit threshold.");

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

function FRC_SortProfit(a, b)
	-- sort by ratio or actual amount based on which we're using as cutoff
	if (FRC_Config.MinProfitRatio) then
		return (a.profit / a.matsCost) > (b.profit / b.matsCost);
	else
		return a.profit > b.profit;
	end
end

function FRC_PrintReportLine(reportInfo)
	local reportLine;
	if (string.find(reportInfo.link, "%["..reportInfo.recipe.."%]")) then
		reportLine = reportInfo.link..": ";
	else
		reportLine = reportInfo.link.." ("..reportInfo.recipe.."): ";
	end
	reportLine = reportLine .."mats ".. GFWUtils.TextGSC(reportInfo.matsCost) ..GFWUtils.Gray(" ("..reportInfo.matsConf.."%)")..", "
	reportLine = reportLine .."AH ".. GFWUtils.TextGSC(reportInfo.itemPrice) ..GFWUtils.Gray(" ("..reportInfo.itemConf.."%)")..", "
	if (reportInfo.profit >= 0) then
		reportLine = reportLine .."profit ".. GFWUtils.TextGSC(reportInfo.profit);
	else
		reportLine = reportLine ..GFWUtils.Red("loss ").. GFWUtils.TextGSC(reportInfo.profit);
	end
	GFWUtils.Print(reportLine);
end

function FRC_GetAdjustedCost(skillName, itemID)
	FRC_RecursiveItems = nil;
	return FRC_AdjustedCost(skillName, itemID);
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
	if (itemID == nil) then
		return nil;
	end
	
	-- we keep our own price data on tradeskill ingredients bought from vendors
	-- (e.g. thread, flux, dye, vials)
	if (FRC_VendorPrices[itemID]) then
		return FRC_VendorPrices[itemID].b, -1;
	end
	
	if (not FRC_LoadPriceSourceIfNeeded(true)) then return nil; end
	
	local priceFunction = FRC_PriceFunctions[FRC_PriceSource];
	if (priceFunction) then
		return priceFunction(itemID);
	else
		error("ReagentCost: price function for "..FRC_PriceSource.." missing.",2);
		return nil; 
	end
end

function FRC_AucAdvancedItemPrice(itemID)
	
	if not (AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue) then
		GFWUtils.PrintOnce(GFWUtils.Red("ReagentCost error:").." missing expected Auctioneer API; can't calculate item prices.", 5);
		return nil, nil;
	end
	
	local value, count = AucAdvanced.API.GetMarketValue(itemID);
	local sellToVendorPrice;
	if (GetSellValue) then
	 	sellToVendorPrice = GetSellValue(itemID);
	end
	
	if (value) then
		return value, math.floor(math.min(count, MIN_SCANS) / MIN_SCANS * 100); 
	elseif (sellToVendorPrice) then
		return sellToVendorPrice * 3, 0;	-- generally a good guess for auction price if we don't have real auction data
	else
		return nil, 0;
	end
end

function FRC_AuctioneerItemPrice(itemID)
	local getUsableMedian, getHistoricalMedian, getVendorSellPrice, getVendorBuyPrice;
	if (Auctioneer and Auctioneer.Statistic) then
		getUsableMedian = Auctioneer.Statistic.GetUsableMedian;
		getHistoricalMedian = Auctioneer.Statistic.GetItemHistoricalMedianBuyout;
	end
	if (Auctioneer and Auctioneer.API) then
		getVendorSellPrice = Auctioneer.API.GetVendorSellPrice;
	end
	if (not (getUsableMedian and getHistoricalMedian)) then
		GFWUtils.PrintOnce(GFWUtils.Red("ReagentCost error:").." missing expected Auctioneer API; can't calculate item prices.", 5);
		return nil, nil;
	end
	
	local itemKey = itemID..":0:0";
	local medianPrice, medianCount = getUsableMedian(itemKey);
	if (medianPrice == nil) then
		medianPrice, medianCount = getHistoricalMedian(itemKey);
	end
	if (medianCount == nil) then medianCount = 0 end
			
	if (medianCount == 0 or medianPrice == nil) then
		local sellToVendorPrice = 0;
		if (getVendorSellPrice) then
			sellToVendorPrice = getVendorSellPrice(itemID) or 0;
		end
		if (sellToVendorPrice == 0 and FRC_VendorPrices[itemID]) then
			sellToVendorPrice = FRC_VendorPrices[itemID].s;
		end
		return sellToVendorPrice * 3, 0; -- generally a good guess for auction price if we don't have real auction data
	else
		return medianPrice, math.floor(math.min(medianCount, MIN_SCANS) / MIN_SCANS * 100); 
	end
end

-- TODO: update KC_Items import, check whether it can use just itemID
function FRC_KCItemPrice(itemLink)
	local itemCode = KC_Common:GetCode(itemLink);
	local seen, avgstack, min, bidseen, bid, buyseen, buy = KC_Auction:GetItemData(itemCode);
	local _, _, itemID  = string.find(itemLink, ".Hitem:(%d+):%d+:%d+:%d+.h%[[^]]+%].h");
	itemID = tonumber(itemID) or 0;
	
	local buyFromVendorPrice = 0;
	local sellToVendorPrice = 0;
	if (FRC_VendorPrices[itemID]) then
		buyFromVendorPrice = FRC_VendorPrices[itemID].b;
		sellToVendorPrice = FRC_VendorPrices[itemID].s;
	end
	if (sellToVendorPrice == 0 and KC_SellValue) then
		sellToVendorPrice = (KC_Common:GetItemPrices(itemCode) or 0);
	end
	
	--DevTools_Dump({itemLink=itemLink, itemID=itemID, buy=buy, buyseen=buyseen, buyFromVendorPrice=buyFromVendorPrice, sellToVendorPrice=sellToVendorPrice});

	if (buyFromVendorPrice and buyFromVendorPrice > 0) then
		return buyFromVendorPrice, -1; -- FRC_VendorPrices lists only the primarily-vendor-bought tradeskill items
	elseif (buy and buy > 0) then
		return buy, math.floor((math.min(buyseen, MIN_SCANS) / MIN_SCANS) * 1000) / 10;
	elseif (sellToVendorPrice and sellToVendorPrice > 0) then
		return sellToVendorPrice * 3, 0; -- generally a good guess for auction price if we don't have real auction data
	else
		GFWUtils.DebugLog(itemLink.." not found in KC_Auction or vendor-reagent prices list");
		return nil, 0;
	end
end

-- TODO: replace AuctionMatrix import with AuctionSync
function FRC_AuctionMatrixItemPrice(itemLink)
	local _, _, itemID, itemName  = string.find(itemLink, ".Hitem:(%d+):%d+:%d+:%d+.h%[([^]]+)%].h");
	local buyFromVendorPrice = 0;
	local sellToVendorPrice = 0;
	itemID = tonumber(itemID) or 0;
	if (FRC_VendorPrices[itemID]) then
		buyFromVendorPrice = FRC_VendorPrices[itemID].b;
		sellToVendorPrice = FRC_VendorPrices[itemID].s;
	end
		
	local buyout, times, storeStack;
	if (itemName and itemName ~= "" and AMDB[itemName]) then
		buyout = tonumber(AM_GetMedian(itemName, "abuyout"));
		if (buyout == nil) then
			buyout = tonumber(AuctionMatrix_GetData(itemName, "abuyout"));
		end
		times = tonumber(AuctionMatrix_GetData(itemName, "times"));
		storeStack = tonumber(AuctionMatrix_GetData(itemName, "stack"));
		if (sellToVendorPrice == 0) then
			sellToVendorPrice = tonumber(AuctionMatrix_GetData(itemName, "vendor"));
		end
	end

	--DevTools_Dump({itemLink=itemLink, buyout=buyout, times=times, buyFromVendorPrice=buyFromVendorPrice, sellToVendorPrice=sellToVendorPrice});
		
	if (buyFromVendorPrice and buyFromVendorPrice > 0) then
		return buyFromVendorPrice, -1; -- FRC_VendorPrices lists only the primarily-vendor-bought tradeskill items
	elseif (buyout and times and buyout > 0) then
		local buyoutForOne = buyout;
		if (storeStack and storeStack > 0) then
			buyoutForOne = math.floor(buyout/storeStack);
		end
		return buyoutForOne, math.floor((math.min(times, MIN_SCANS) / MIN_SCANS) * 1000) / 10;
	elseif (sellToVendorPrice and sellToVendorPrice > 0) then
		return sellToVendorPrice * 3, 0; -- generally a good guess for auction price if we don't have real auction data
	end
	
	GFWUtils.DebugLog(itemLink.." not found in AuctionMatrix or vendor-reagent prices list");
	return nil, 0;
end

-- TODO: check whether WoWEcon can use just itemID
function FRC_WOWEcon_PriceModItemPrice(itemLink)
    local medianPrice, medianCount, serverData = WOWEcon_GetAuctionPrice_ByLink(itemLink);
    if (medianCount == nil) then
		medianCount = 0;
	end
        
	local _, _, itemID  = string.find(itemLink, ".Hitem:(%d+):%d+:%d+:%d+.h%[[^]]+%].h");
	itemID = tonumber(itemID) or 0;
			
	local buyFromVendorPrice = 0;
	local sellToVendorPrice = 0;
	if (FRC_VendorPrices[itemID]) then
		buyFromVendorPrice = FRC_VendorPrices[itemID].b;
		sellToVendorPrice = FRC_VendorPrices[itemID].s;
	end
			
	if (sellToVendorPrice == 0) then
		sellToVendorPrice = WOWEcon_GetVendorPrice_ByLink(itemLink);
	end
			
	if (sellToVendorPrice == nil) then sellToVendorPrice = 0 end
			
	if (buyFromVendorPrice > 0) then
		return buyFromVendorPrice, -1; -- FRC_VendorPrices lists only the primarily-vendor-bought tradeskill items
	elseif (medianCount == 0 or medianPrice == nil) then
		return sellToVendorPrice * 3, 0; -- generally a good guess for auction price if we don't have real auction data
	else
		return medianPrice, math.floor((math.min(medianCount, MIN_SCANS) / MIN_SCANS) * 1000) / 10;
	end
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

FRC_PriceFunctions = {
	["auc-advanced"] = FRC_AucAdvancedItemPrice,
	["Auctioneer"] = FRC_AuctioneerItemPrice,
--	["KC_Items"] = FRC_KCItemPrice,
--	["AuctionMatrix"] = FRC_AuctionMatrixItemPrice,
--	["WOWEcon_PriceMod"] = FRC_WOWEcon_PriceModItemPrice,
};

function FRC_GetPriceSource()
	if (not FRC_PriceSource) then
		for addon in pairs(FRC_PriceFunctions) do 
			local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(addon);
			if (loadable or IsAddOnLoaded(addon)) then
				FRC_PriceSource = addon;
				break;
			end
		end
	end
end

function FRC_LoadPriceSourceIfNeeded(needed)
	if (needed or FRC_Config.AutoLoadPriceSource) then
		if (FRC_PriceSource) then
			if (not IsAddOnLoaded(FRC_PriceSource)) then
				local loaded, reason = LoadAddOn(FRC_PriceSource);
				if (not loaded) then
					GFWUtils.Print(string.format("Can't load %s: %s", FRC_PriceSource, reason));
					return false;
				end
			end
			return true;
		else
			error("FRC_PriceSource == nil");
		end
	end
end