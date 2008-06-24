------------------------------------------------------
Fizzwidget Reagent Cost
by Gazmik Fizzwidget
http://fizzwidget.com/reagentcost
gazmik@fizzwidget.com
------------------------------------------------------

Once I'd enhanced my (already quite impressive, might I add) Enchant Seller gadget with the ability to estimate and report a total cost of materials for each enchantment, I knew I had to do the same for practitioners of other professions. After all, enchanters aren't the only crafters who'd benefit from a good helping of Goblin business sense!

Not only will this gizmo keep you informed on the current market price of the materials for all your trade skill recipes, it'll also help you choose which items are most profitable to produce for sale! Go make yourself some gold... and remember to tell the mount vendor Gazmik sent ya!

------------------------------------------------------

INSTALLATION: Put this folder into your World Of Warcraft/Interface/AddOns folder and launch WoW. You'll also need one of Auctioneer (http://www.auctioneeraddon.com), KC_Items (http://kaelcycle.wowinterface.com/), or AuctionMatrix (http://ui.worldofwar.net/ui.php?id=821) installed, if you haven't already. Also having ReagentData (http://www.tarys.com/reagents/) will help in some cases, but it isn't required.

USAGE: 
	- Your tradeskill windows will now display an estimated total cost of materials above the listing of required reagents for each recipe. The current market value of each reagent is calculated based on your auction scan data -- so, as is often the case with auction scanners, the more often you scan the AH, the more reliable your data will be. (A "confidence" percentage score is included in gray next to totals so you can get an idea of how reliable the auction data for a particular set of reagents is.) Auction price is only used for reagents not commonly sold by vendors; since it'd be silly to go looking for (for example) thread, vials, or flux at auction instead of buying from a vendor, the vendor price is used when totaling the cost of such reagents.
	- By typing `/reagentcost report`, you can get a list of all the items your tradeskills can produce ranked by estimated profitability, so you can see which items are worth making and selling on the AH and which (if you're not needing to make them for skill-ups) you might be better off selling the reagents for. By default, this list only includes items for which you have at least a minimal amount of auction data, and only items that can be auctioned for at least a break-even price. See "Chat Commands" below for options. (You'll notice the report also includes precentages in gray: this is the same "confidence" score as in the tradeskill windows.)

CHAT COMMANDS:
/reagentcost (or /rc) <command>
	- `help` - Print this helplist.
	- `status` - Check current settings.
	- `reset` - Reset to default settings.
	- `on|off` - Toggle displaying info in tradeskill windows.
	- `report [<skillname>]` - Output a list of the most profitable tradeskill items you can make. (Or only those produced through *skillname*.)
	- `minprofit <number>` - When reporting, only show items whose estimated profit is *number* or greater. (In copper, so 1g == 10000.)
	- `minprofit <number>%` - When reporting, only show items whose estimated profit exceeds its cost of materials by *number* percent or more.

------------------------------------------------------
VERSION HISTORY

v. 2.1.2 - 2007/09/13
- ReagentCost now supports the preview release of Auctioneer Advanced as a price data source. (Auctioneer 4.x is still supported as well.)
- Streamlined code for keeping track of addons that provide auction price data.
- Fixed some errors in `/rc report` and `/rc [item link]` output.

v. 2.1.1 - 2007/07/20
- Fixed errors caused by changes to the TradeSkill/Craft APIs in WoW Patch 2.1.
- Fixed an issue where we'd store incorrect info for recipe reagents, resulting in errors once we tried to display price data for them.
- Added support for the Ace [AddonLoader][] -- when that addon is present, ReagentCost won't be loaded until needed (when you show a tradeskill window or type `/rc`).
[AddonLoader]: http://www.wowace.com/wiki/AddonLoader

v. 2.1 - 2007/05/22
- Updated TOC for WoW Patch 2.1.

v. 2.0.2 - 2007/01/15
- Updated TOC to indicate compatibility with WoW Patch 2.0.5 and the Burning Crusade release.

v. 2.0.1 - 2006/12/07
- Fixed an error that occured on loading.

v. 2.0 - 2006/12/05
- Updated for compatibility with WoW 2.0 (and the Burning Crusade Closed Beta).
- Requires a WoW 2.0 compatible version of Auctioneer. (Support for other auction data source is pending, as I haven't had 2.0-compatible versions of them to test against yet.)

See http://www.fizzwidget.com/notes/reagentcost/ for older release notes.
