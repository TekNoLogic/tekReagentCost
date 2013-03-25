
local myname, ns = ...

local tip = CreateFrame("GameTooltip")
tip:SetOwner(WorldFrame, "ANCHOR_NONE")

for i=1,30 do
	local left, right = tip:CreateFontString(), tip:CreateFontString()
	left:SetFontObject(GameFontNormal)
	right:SetFontObject(GameFontNormal)
	tip:AddFontStrings(left, right)
end


function ns.GetTradeSkillReagentItemLink(i, j)
	tip:ClearLines()
	tip:SetTradeSkillItem(i, j)
	local _, link = tip:GetItem()
	return link
end
