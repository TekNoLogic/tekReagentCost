
local SPELL_REAGENTS = _G.SPELL_REAGENTS:gsub("|n", "")
local buyprices = TEKRC_BUY
TEKRC_BUY = nil
local combineprices = {}


local function Print(...) ChatFrame1:AddMessage(string.join(" ", "|cFF33FF99tekReagentCost|r:", ...)) end


local function GS(cash)
	if not cash then return end
	cash = cash/100
	local g, s = floor(cash/100), floor(cash%100)
	if g > 0 then return string.format("|cffffd700%d.|cffc7c7cf%02d", g, s) else return string.format("|cffc7c7cf%d", s) end
end


local function GetPrice(itemID)
	if not itemID then return end
	if buyprices[itemID] then return buyprices[itemID], -1 end
	local price, craftedprice = GetAuctionBuyout and GetAuctionBuyout(itemID), combineprices[itemID]
	if price and craftedprice then return math.min(price, craftedprice), 1 end
	return price or craftedprice, 1
end


local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, addon)
	if addon == "Blizzard_TradeSkillUI" or addon == "tekReagentCost" and IsAddOnLoaded("Blizzard_TradeSkillUI") then self:HookTradeSkill() end
end)
f:RegisterEvent("ADDON_LOADED")


function f:HookTradeSkill()
	local orig = TradeSkillFrame_Update
	TradeSkillFrame_Update = function(...)
		local id = GetTradeSkillSelectionIndex()
		local cost, incomplete = 0
		for i=1,GetTradeSkillNumReagents(id) do
			local link = GetTradeSkillReagentItemLink(id, i)
			local _, _, count = GetTradeSkillReagentInfo(id, i)
			local itemid = tonumber((string.match(link, "item:(%d+):")))
			local price = GetPrice(itemid)
			cost = cost + (price or 0) * count
			if not price then incomplete = true end
		end
		TradeSkillReagentLabel:SetText(SPELL_REAGENTS.." "..(incomplete and "Incomplete price data" or GS(cost)))

		if not incomplete then
			local link = GetTradeSkillItemLink(id)
			local itemid = tonumber((string.match(link, "item:(%d+):")))
			combineprices[itemid] = cost
		end
		return orig(...)
	end
end

