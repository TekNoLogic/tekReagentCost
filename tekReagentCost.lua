
local myname, ns = ...

local ah_only = [[
	21884 21885 22452 22451 21886 22456 22457
]]
function ns.GetPrice(itemID)
	if not itemID then return end
	if ns.vendor[itemID] then return ns.vendor[itemID], -1 end
	local price = GetAuctionBuyout and GetAuctionBuyout(itemID)
	if ah_only:match(itemID) then return price, 1 end
	local craftedprice = ns.combineprices[itemID] or ns.bop_values[itemID]
	if price and craftedprice then return math.min(price, craftedprice), 1 end
	return price or craftedprice, 1
end


local origs = {}
local function OnTooltipSetItem(frame, ...)
	local name, link = frame:GetItem()
	local id = link and ns.ids[link]
	if id then
		if ns.combineprices[id] then
			frame:AddDoubleLine("Reagent cost:", ns.GS(ns.combineprices[id]))
		end
	end
	if origs[frame] then return origs[frame](frame, ...) end
end


for _,frame in pairs{GameTooltip, ItemRefTooltip} do
	origs[frame] = frame:GetScript("OnTooltipSetItem")
	frame:SetScript("OnTooltipSetItem", OnTooltipSetItem)
end
