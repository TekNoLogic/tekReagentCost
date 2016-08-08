
local myname, ns = ...


-- GameTooltip:SetRecipeReagentItem() breaks GameTooltip:GetItem() as of 7.0
-- So we need to do a little hackery to fix that.
-- THANKS BLIZZARD
local orig = GameTooltip.SetRecipeReagentItem
function GameTooltip:SetRecipeReagentItem(...)
	local link = C_TradeSkillUI.GetRecipeReagentItemLink(...)
	if link then return self:SetHyperlink(link) end
	return orig(self, ...)
end
