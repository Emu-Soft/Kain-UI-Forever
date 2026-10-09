local addonName, KUI = ...

local PATCH_NOTES = {
	{
		version = "1.0.298",
		sections = {
			{ title = "Changed", items = {
				"The download now has the version number in its name, so WowUp shows which version you have.",
			} },
		},
	},
	{

		version = "1.0.297",
		sections = {
			{ title = "Fixed", items = {
				"Cast By: your own buffs keep showing your name after a /reload.",
			} },
		},
	},
	{
		version = "1.0.291",
		sections = {
			{ title = "Fixed", items = {
				"Names with accented letters, like Bóbsson, now show properly in /kui snapshot instead of as question marks.",
				"Long Recent Allies notes, error reports and links no longer cut an accented letter in half.",
				"Wowhead search and K-Targeter's suggestions treat accented capitals and small letters the same (É and é).",
				"Copy chat: a message whose colour never ends no longer turns every line after it the same colour.",
			} },
		},
	},
	{
		version = "1.0.286",
		sections = {
			{ title = "Changed", items = {
				"The guild inviter starter macro is now called Guild Inviter. If you already have it under its old name, it keeps working; delete it and type /kui installmacros to get the new one.",
			} },
		},
	},
	{
		version = "1.0.285",
		sections = {
			{ title = "Changed", items = {
				"K-UI: Forever can be installed and kept up to date with WowUp, straight from its GitHub page, without a compatibility warning.",
			} },
		},
	},
	{
		version = "1.0.284",
		sections = {
			{ title = "Changed", items = {
				"New versions of K-UI: Forever are now published on GitHub, each with its own download and a list of what's changed.",
			} },
		},
	},
	{
		version = "1.0.283",
		sections = {
			{ title = "New", items = {
				"Easier bug reports: the addon now keeps a note of any errors it runs into, and /kui snapshot includes them, along with your game version, where you are and which other addons you're running. If something goes wrong, type /kui snapshot, copy what it shows and send it. No extra addon needed.",
				"/kui clearerrors empties that list once you've sent it.",
			} },
		},
	},
	{
		version = "1.0.277",
		sections = {
			{ title = "New", items = {
				"Wowhead search: hover an item, spell or quest and press Ctrl+Shift+W to get a Wowhead search link for it, ready to copy. You can change the key under Key Bindings > AddOns > K-UI: Forever.",
			} },
		},
	},
	{
		version = "1.0.271",
		sections = {
			{ title = "Fixed", items = {
				"Cast By no longer forgets who buffed you when you take a boat, zeppelin or anything else with a loading screen.",
			} },
		},
	},
	{
		version = "1.0.270",
		sections = {
			{ title = "Fixed", items = {
				"Cast By keeps showing who buffed you after they've gone out of range, and when they refresh the buff.",
			} },
		},
	},
	{
		version = "1.0.269",
		sections = {
			{ title = "New", items = {
				"Type /kui help to see a list of every command and what it does.",
			} },
			{ title = "Changed", items = {
				"Behind-the-scenes troubleshooting commands are now hidden, so the list of commands is short and clear.",
			} },
		},
	},
	{
		version = "1.0.268",
		sections = {
			{ title = "Fixed", items = {
				"Cast By: buffs from players outside your group now show who cast them, even if you hover over the buff after they've moved on.",
			} },
		},
	},
	{
		version = "1.0.266",
		sections = {
			{ title = "New", items = {
				"Quest items sparkle: things you need for a quest, like items to pick up or objects to click, now sparkle so they're easy to spot. This is always on.",
				"To make the sparkle show, the glowing outline the game draws around creatures and objects when you hover over them is switched off.",
			} },
		},
	},
	{
		version = "1.0.265",
		sections = {
			{ title = "New", items = {
				"The addon has its own icon in the game's AddOns list, and appears there as \"K-UI: Forever\" in the K-Mods group.",
			} },
		},
	},
	{
		version = "1.0.264",
		sections = {
			{ title = "Changed", items = {
				"The patch notes now say which version each change arrived in.",
			} },
		},
	},
	{
		version = "1.0.263",
		sections = {
			{ title = "New", items = {
				"Screenshot on level up: tick it in the User Interface section and the game takes a screenshot a moment after you level up, so you've got a picture of every milestone. They're saved to your World of Warcraft Screenshots folder.",
			} },
		},
	},
	{
		version = "1.0.262",
		sections = {
			{ title = "Improved", items = {
				"The XP bar's tooltip now opens from the left end of the bar, and the bar is easier to hover over.",
			} },
		},
	},
	{
		version = "1.0.261",
		sections = {
			{ title = "Improved", items = {
				"Smarter XP per hour: hold Shift over the XP bar under your portrait to see four numbers: your XP per hour while killing, your XP per hour including the time spent travelling between areas, the XP you're getting from quests, and an overall estimate that your time to level is based on.",
				"It now looks at your last 30 minutes rather than your whole session, so it catches up quickly when you change what you're doing.",
				"Quest hand-ins no longer make it jump: their XP is spread out over half an hour instead of counting as one huge burst.",
				"Breaks of more than 5 minutes barely count, so stepping away doesn't wreck the estimate.",
				"The estimate leans towards your real pace, travel included, so your time to level is closer to what actually happens.",
				"The tooltip also shows how much of this session's XP came from quests.",
			} },
		},
	},
	{
		version = "1.0.260",
		sections = {
			{ title = "Changed", items = {
				"\"Unlock minimap elements\" now starts switched off on a new character, like every other option.",
			} },
		},
	},
	{
		version = "1.0.256",
		sections = {
			{ title = "Changed", items = {
				"The patch notes now open from the blue gem in the bottom-left corner of the settings. It lights up when you hover over it.",
			} },
		},
	},
	{
		version = "1.0.255",
		sections = {
			{ title = "New", items = {
				"Patch notes: a window listing what's changed in each version.",
				"Version number: the settings show which version you're running, in the bottom-right corner.",
			} },
		},
	},
	{
		version = "1.0.254",
		sections = {
			{ title = "New", items = {
				"Notes on Recent Allies: right-click someone in the Recent Allies list and choose \"Set Note\". Your note shows when you hover over them, and all your characters can see it.",
				"The Social window (friends and Recent Allies) can now be dragged around when \"Enable Global Dragging\" is on.",
			} },
		},
	},
	{
		version = "1.0.251",
		sections = {
			{ title = "New", items = {
				"Movable social button: tick \"Unlock Social Button\" in the Chat section, then drag the friends button above your chat anywhere you like. Friend pop-ups follow it. Use \"Reset social button position\" to put it back.",
			} },
		},
	},
	{
		version = "1.0.247",
		sections = {
			{ title = "Fixed", items = {
				"Bag icon: the backpack icon no longer shrinks or disappears after looting or selling.",
			} },
		},
	},
	{
		version = "1.0.243",
		sections = {
			{ title = "Settings window", items = {
				"A fresh look: the border is gone, with decorative filigree in two corners and softly rounded edges on the others.",
				"The blue gem in the top-right corner is now the close button. It lights up when you hover over it. Esc still closes the window too.",
			} },
		},
	},
	{
		version = "1.0.239",
		sections = {
			{ title = "Settings window", items = {
				"Tidier layout: the columns sit closer together and nothing runs off the right-hand edge.",
			} },
		},
	},
	{
		version = "1.0.238",
		sections = {
			{ title = "Changed", items = {
				"Square minimap: the hidden box of addon minimap buttons (right-click the minimap) now only comes with \"Square Minimap\", not with \"Detach minimap elements\".",
				"Help icons now only appear where they tell you something the option's name doesn't.",
			} },
		},
	},
	{
		version = "1.0.237",
		sections = {
			{ title = "Fixed", items = {
				"Chat in dungeons: chat no longer stops showing messages during fights in dungeons. Chat extras (coloured timestamps, short channel names like [1], clickable web links and emoji) now pause inside dungeons and raids, and come back as soon as you leave.",
			} },
		},
	},
	{
		version = "1.0.235",
		sections = {
			{ title = "Settings window", items = {
				"The weather and zoom sliders show their current value on its own line.",
			} },
		},
	},
	{
		version = "1.0.234",
		sections = {
			{ title = "Settings window", items = {
				"The grey help text under options has been replaced by small \"i\" icons. Hover over one to read what that option does.",
			} },
		},
	},
	{
		version = "1.0.232",
		sections = {
			{ title = "New", items = {
				"XP per hour: hover over the XP bar under your portrait and hold Shift to see how much XP you're earning per hour, how long until you level, and how much you've earned this session. Type /kui xpreset to start counting again (handy after a break).",
			} },
		},
	},
	{
		version = "1.0.229",
		sections = {
			{ title = "Improved", items = {
				"Class trainers: with \"Grow right\" tooltips on, a skill's details only pop up when you hover over its icon, so they no longer cover the list while you read it.",
			} },
		},
	},
	{
		version = "1.0.215",
		sections = {
			{ title = "Fixed", items = {
				"The weather and zoom slider handles no longer slip off the end of their bar after a reload.",
			} },
		},
	},
	{
		version = "1.0.213",
		sections = {
			{ title = "Fixed", items = {
				"Turning every minimap option off gives you Blizzard's normal minimap back, exactly as it was.",
			} },
		},
	},
	{
		version = "1.0.207",
		sections = {
			{ title = "Settings window", items = {
				"\"Snap to elements\" moved to the top-right corner of the settings.",
			} },
		},
	},
	{
		version = "1.0.206",
		sections = {
			{ title = "New", items = {
				"Addon minimap buttons are tidied into a box: right-click the minimap to open it. It opens beside the minimap's bottom-left corner.",
			} },
		},
	},
	{
		version = "1.0.204",
		sections = {
			{ title = "Fixed", items = {
				"The loot window no longer flashes up empty before it fills.",
			} },
		},
	},
	{
		version = "1.0.199",
		sections = {
			{ title = "Changed", items = {
				"The mail icon keeps its own spot on screen instead of moving with the zone bar.",
			} },
		},
	},
	{
		version = "1.0.198",
		sections = {
			{ title = "Fixed", items = {
				"Opening the Spellbook with Global Dragging on no longer causes an error, and micro menu changes made in combat wait until the fight ends.",
			} },
		},
	},
	{
		version = "1.0.196",
		sections = {
			{ title = "New", items = {
				"The Legacy Tree window can be dragged with Global Dragging, and its tooltips follow your mouse.",
			} },
		},
	},
	{
		version = "1.0.193",
		sections = {
			{ title = "Improved", items = {
				"If your saved settings ever get damaged, the addon repairs them when you log in.",
			} },
		},
	},
	{
		version = "1.0.192",
		sections = {
			{ title = "Fixed", items = {
				"Far fewer errors at moments when the game restricts addons, like boss fights.",
			} },
		},
	},
	{
		version = "1.0.185",
		sections = {
			{ title = "Fixed", items = {
				"The Up arrow in chat brings back every message you've sent, not just commands.",
			} },
		},
	},
	{
		version = "1.0.184",
		sections = {
			{ title = "Improved", items = {
				"Tooltips for buffs and debuffs on nameplates follow your mouse.",
			} },
		},
	},
	{
		version = "1.0.183",
		sections = {
			{ title = "Fixed", items = {
				"The day/night indicator stays where you put it when you hide and show the interface (Alt+Z).",
			} },
		},
	},
	{
		version = "1.0.181",
		sections = {
			{ title = "New", items = {
				"With \"Unlock minimap elements\" on, the mail icon can be moved.",
			} },
		},
	},
	{
		version = "1.0.175",
		sections = {
			{ title = "Improved", items = {
				"The guild/dungeon difficulty badge remembers a separate spot for the round and the square minimap.",
			} },
		},
	},
	{
		version = "1.0.174",
		sections = {
			{ title = "New", items = {
				"With \"Unlock minimap elements\" on, the day/night indicator can be moved on the square minimap.",
			} },
		},
	},
	{
		version = "1.0.164",
		sections = {
			{ title = "New", items = {
				"Square Minimap: a square map with a metal border and a soft shadow inside the edge. (Its look was fine-tuned up to 1.0.190.)",
			} },
		},
	},
	{
		version = "1.0.163",
		sections = {
			{ title = "Fixed", items = {
				"Loot roll windows no longer end up off the screen. Drag a roll, or the marker, to choose where they appear.",
			} },
		},
	},
	{
		version = "1.0.162",
		sections = {
			{ title = "New", items = {
				"The XP bar shows a gold marker where your rested XP starts.",
			} },
		},
	},
	{
		version = "1.0.160",
		sections = {
			{ title = "New", items = {
				"Group Finder shows which zone each listed player is in.",
				"With \"Unlock minimap elements\" on, the guild/dungeon difficulty badge can be moved.",
			} },
		},
	},
	{
		version = "1.0.158",
		sections = {
			{ title = "Improved", items = {
				"Cast By: buff and debuff tooltips show who cast them on your target and party members too, not just on you. Since 1.0.148 the name is in the caster's class colour, and since 1.0.149 it's remembered even after they leave or you reload.",
			} },
		},
	},
	{
		version = "1.0.145",
		sections = {
			{ title = "Fixed", items = {
				"Tooltips for corpses are tidier and no longer come up too wide.",
			} },
		},
	},
	{
		version = "1.0.136",
		sections = {
			{ title = "Improved", items = {
				"Tooltips inside trainer windows follow your mouse.",
			} },
		},
	},
	{
		version = "1.0.133",
		sections = {
			{ title = "Improved", items = {
				"Without RestedXP Guides installed, its options in the settings are greyed out, and hovering over them tells you why.",
			} },
		},
	},
	{
		version = "1.0.128",
		sections = {
			{ title = "Improved", items = {
				"While \"Toggle Objective Tracker\" hides Blizzard's quest tracker, you can't click it by accident.",
			} },
		},
	},
	{
		version = "1.0.127",
		sections = {
			{ title = "Improved", items = {
				"Camp items and crafting stations (forges, campfires, workbenches and so on) show their tooltip in your chosen spot, while signposts and chests show theirs at your mouse. (More camp items were added in 1.0.146.)",
			} },
		},
	},
	{
		version = "1.0.118",
		sections = {
			{ title = "Fixed", items = {
				"\"Toggle Objective Tracker\" hides Blizzard's quest tracker without causing errors.",
			} },
		},
	},
	{
		version = "1.0.114",
		sections = {
			{ title = "Improved", items = {
				"Importing the profile now also loads a matching RestedXP Guides profile, on new characters too.",
			} },
		},
	},
	{
		version = "1.0.111",
		sections = {
			{ title = "Improved", items = {
				"With \"Grow right\" tooltips on, tooltips for items and spells on your action bars show in your chosen spot.",
			} },
		},
	},
	{
		version = "1.0.110",
		sections = {
			{ title = "Changed", items = {
				"The thin health bar under tooltips is gone.",
			} },
		},
	},
	{
		version = "before",
		heading = "Before version 1.0.106",
		sections = {
			{ title = "Minimap", items = {
				"The zone bar (zone name and clock above the minimap) can be split off from the minimap and moved on its own.",
				"The minimap can be pushed partly off the edge of the screen, so you can line it up exactly where you want it.",
			} },
			{ title = "Tooltips", items = {
				"Grow Right: tooltips always appear in the same spot, growing to the right, so they don't jump around or cover other things. Unlock it in the Tooltips section to choose the spot.",
				"Cast By: buff and debuff tooltips show who cast them.",
			} },
			{ title = "Chat", items = {
				"Enhance Chat: timestamps, short channel names, clickable web links, a copy-chat button, hidden scroll bars, and the Up arrow to bring back messages you've sent. The chat window can also be moved partly off the edge of the screen.",
				"The copy-chat window shows your chat in normal reading order: oldest at the top, newest at the bottom.",
				"Emoji: type codes like :smile: in chat, or pick one from the little face button by the chat box. There are over 1,500 to choose from, and the button can be moved.",
			} },
			{ title = "Bags, loot and vendors", items = {
				"Hide any of the bag slots, including the keyring, and the bag bar's background art.",
				"Auto-sell grey items and auto-repair at vendors, optionally using guild money when you're allowed to.",
				"Fast loot: loots everything as soon as you open a corpse.",
				"Loot roll windows can be dragged wherever you like.",
			} },
			{ title = "Windows and menus", items = {
				"Enable Global Dragging: move the Character, Spellbook and Talents, Map and Quest Log, bags, professions, quest, vendor and calendar windows by their title bar. Type /kui resetdrag to put them all back.",
				"Micro menu: hide any of the small menu buttons in the bottom-right corner, or the whole menu.",
			} },
			{ title = "Questing", items = {
				"K-Key: talk to NPCs from the keyboard. Number keys pick dialogue options and quest rewards, and Space accepts quests, moves quest text along and picks the first option. Space never accepts things you'd want to think about, like summons, duels or group invites. Type /kkey for more.",
			} },
			{ title = "Action bars and macros", items = {
				"Weapon Swap Macro Helper: drag your weapons into the slots at the top of these settings to get a one-click weapon swap macro.",
				"Macro icons: when choosing an icon for a macro, hover over any icon to see its name, or search for one by name.",
				"Handy starter macros are added for you: a coin flip, skull and cross raid markers, and a guild inviter.",
				"K-Targeter: a macro called \"K-Targeter\" that always targets whatever your tracked quest needs next, whether that's the creature to kill or the person to hand it in to. Put it on an action bar once; it updates itself as you quest (/kt for its options).",
			} },
			{ title = "Graphics, camera and nameplates", items = {
				"Contrast: recommended contrast and brightness settings, with a button to put yours back.",
				"Weather Intensity and Max zoom distance sliders.",
				"Plater style: makes Blizzard's nameplates look like the popular Plater addon. Untick it to get your own nameplate settings back.",
			} },
			{ title = "XP bar", items = {
				"An XP bar under your portrait, with the option to hide Blizzard's XP bar.",
			} },
			{ title = "RestedXP Guides", items = {
				"Convert Arrow Output shows the guide arrow's distance in metres instead of yards.",
				"Toggle Objective Tracker hides Blizzard's quest tracker while the guide is showing, so you can focus on the guide. /rxp toggle switches between them.",
			} },
			{ title = "Setting up", items = {
				"Kain's preset: sets every option the recommended way, in one click.",
				"Import Kain-UI Profile: sets up the recommended screen layout and switches on the extra action bars.",
				"Snap to elements: when you move things, they snap neatly into line with each other, and an alignment grid appears while you're arranging.",
				"Every option starts switched off on a new character, so you only get the changes you choose. Kain's preset is there if you'd like the recommended setup in one click.",
			} },
			{ title = "Handy commands", items = {
				"/rl reloads your interface.",
				"/flip (or /coin) flips a coin as an emote everyone nearby can see. Target someone first to flip for them. (Very rarely, it lands on its edge.)",
				"/kui factoryreset confirm erases all of this addon's settings and starts you fresh, in case anything ever gets into a muddle. It can't be undone.",
			} },
		},
	},
}

local function BuildNotesText()
	local out = {}
	for i, release in ipairs(PATCH_NOTES) do
		if i > 1 then out[#out + 1] = "" end
		out[#out + 1] = "|cffffd100" .. (release.heading or ("Version " .. release.version)) .. "|r"
		for _, section in ipairs(release.sections) do
			out[#out + 1] = ""
			out[#out + 1] = "|cffffd100" .. section.title .. "|r"
			for _, item in ipairs(section.items) do
				out[#out + 1] = "  -  " .. item
			end
		end
	end
	return table.concat(out, "\n")
end

local BORDER_GREY = { 0.45, 0.45, 0.45, 1 }
local BORDER_LIT = { 0.85, 0.85, 0.85, 1 }

local function AddGreyBorder(frame)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		frame:SetBackdropBorderColor(unpack(BORDER_GREY))
	end
end

local notesFrame

local function BuildNotesFrame()
	local f = CreateFrame("Frame", "KainUIForeverPatchNotesFrame", UIParent, "BackdropTemplate")
	f:SetSize(520, 440)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	AddGreyBorder(f)
	if f.SetBackdropColor then f:SetBackdropColor(0.05, 0.05, 0.06, 0.95) end
	f:Hide()
	table.insert(UISpecialFrames, "KainUIForeverPatchNotesFrame")

	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 14, -12)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	title:SetText("Patch notes")

	local close = CreateFrame("Button", nil, f, "BackdropTemplate")
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -10, -10)
	AddGreyBorder(close)
	if close.SetBackdropColor then close:SetBackdropColor(0, 0, 0, 0.6) end
	local x = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	x:SetPoint("CENTER", 0, 1)
	x:SetText("x")
	close:SetScript("OnEnter", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(BORDER_LIT)) end end)
	close:SetScript("OnLeave", function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(BORDER_GREY)) end end)
	close:SetScript("OnClick", function() f:Hide() end)

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(BORDER_GREY[1], BORDER_GREY[2], BORDER_GREY[3], 0.6)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", 12, -40)
	line:SetPoint("TOPRIGHT", -12, -40)

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -50)
	scroll:SetPoint("BOTTOMRIGHT", -34, 14)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(460, 10)
	scroll:SetScrollChild(content)
	local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT")
	text:SetWidth(460)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetSpacing(3)
	text:SetText(BuildNotesText())

	f:SetScript("OnShow", function()
		local h = text:GetStringHeight()
		if type(h) == "number" and h > 0 then content:SetHeight(h + 10) end
	end)
	f.text = text
	return f
end

function KUI:TogglePatchNotes()
	notesFrame = notesFrame or BuildNotesFrame()
	notesFrame:SetShown(not notesFrame:IsShown())
	if notesFrame:IsShown() then notesFrame:Raise() end
end

function KUI:GetPatchNotesText()
	return BuildNotesText()
end

local HELP_COMMANDS = {
	{ "/kui", "Open the settings." },
	{ "/kui help", "Show this list." },
	{ "/kui snapshot", "Everything needed for a bug report: your settings, any errors from this addon, and your other addons. Copy it and send it." },
	{ "/kui clearerrors", "Empty the list of errors in /kui snapshot (after you've sent it)." },
	{ "/kui resetdrag", "Put windows you've dragged back where they started." },
	{ "/kui resetlootroll", "Put loot roll windows back in their normal place." },
	{ "/kui zonebarreset", "Put the zone bar back in its starting spot." },
	{ "/kui xpreset", "Start counting XP per hour again (handy after a break)." },
	{ "/kui installmacros", "Add the starter macros again." },
	{ "/kui weaponswap", "Rebuild the weapon swap macro." },
	{ "/kui linksoff", "Switch Enhance Chat off straight away, if chat ever misbehaves." },
	{ "/kui factoryreset confirm", "Erase all of this addon's settings and start fresh. Can't be undone." },
	{ "/kainuiemoji on", "Show emoji in chat. /kainuiemoji off hides them." },
	{ "/kainuiemoji list", "List every emoji code you can type, like :smile:." },
	{ "/kkey", "K-Key options: talking to NPCs with the keyboard." },
	{ "/kt", "K-Targeter options: the macro that targets what your quest needs." },
	{ "/rl", "Reload your interface." },
	{ "/flip", "Flip a coin as an emote (also /coin)." },
}
local HELP_FOOTER = "Anywhere /kui is shown, /kainui works too."

local HELP_COMMAND_WIDTH = 170
local HELP_TEXT_WIDTH = 290
local HELP_ROW_GAP = 6

local helpFrame

local function BuildHelpFrame()
	local f = CreateFrame("Frame", "KainUIForeverHelpFrame", UIParent, "BackdropTemplate")
	f:SetSize(520, 440)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	AddGreyBorder(f)
	if f.SetBackdropColor then f:SetBackdropColor(0.05, 0.05, 0.06, 0.95) end
	f:Hide()
	table.insert(UISpecialFrames, "KainUIForeverHelpFrame")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Commands")

	local close = CreateFrame("Button", nil, f, "BackdropTemplate")
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -10, -10)
	AddGreyBorder(close)
	if close.SetBackdropColor then close:SetBackdropColor(0, 0, 0, 0.6) end
	local x = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	x:SetPoint("CENTER", 0, 1)
	x:SetText("x")
	close:SetScript("OnEnter", function(btn) if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(unpack(BORDER_LIT)) end end)
	close:SetScript("OnLeave", function(btn) if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(unpack(BORDER_GREY)) end end)
	close:SetScript("OnClick", function() f:Hide() end)

	local head1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head1:SetPoint("TOPLEFT", 16, -44)
	head1:SetText("Command")
	local head2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head2:SetPoint("TOPLEFT", 16 + HELP_COMMAND_WIDTH + 12, -44)
	head2:SetText("What it does")
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(BORDER_GREY[1], BORDER_GREY[2], BORDER_GREY[3], 0.6)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", 12, -62)
	line:SetPoint("TOPRIGHT", -12, -62)

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -70)
	scroll:SetPoint("BOTTOMRIGHT", -34, 14)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(HELP_COMMAND_WIDTH + 12 + HELP_TEXT_WIDTH, 10)
	scroll:SetScrollChild(content)

	local rows = {}
	for i, entry in ipairs(HELP_COMMANDS) do
		local cmd = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cmd:SetWidth(HELP_COMMAND_WIDTH)
		cmd:SetJustifyH("LEFT")
		cmd:SetText(entry[1])
		local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		desc:SetWidth(HELP_TEXT_WIDTH)
		desc:SetJustifyH("LEFT")
		desc:SetText(entry[2])
		rows[i] = { cmd = cmd, desc = desc }
	end
	local footer = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetWidth(HELP_COMMAND_WIDTH + 12 + HELP_TEXT_WIDTH)
	footer:SetJustifyH("LEFT")
	footer:SetText(HELP_FOOTER)

	local function Layout()
		local y = 0
		for _, row in ipairs(rows) do
			row.cmd:ClearAllPoints()
			row.cmd:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
			row.desc:ClearAllPoints()
			row.desc:SetPoint("TOPLEFT", content, "TOPLEFT", HELP_COMMAND_WIDTH + 12, -y)
			local h1 = row.cmd:GetStringHeight() or 0
			local h2 = row.desc:GetStringHeight() or 0
			if type(h1) ~= "number" then h1 = 0 end
			if type(h2) ~= "number" then h2 = 0 end
			y = y + math.max(h1, h2, 12) + HELP_ROW_GAP
		end
		footer:ClearAllPoints()
		footer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(y + 6))
		content:SetHeight(y + 30)
	end
	f:SetScript("OnShow", Layout)
	f.rows = rows
	return f
end

function KUI:ToggleHelp()
	helpFrame = helpFrame or BuildHelpFrame()
	helpFrame:SetShown(not helpFrame:IsShown())
	if helpFrame:IsShown() then helpFrame:Raise() end
end

function KUI:GetHelpCommands()
	return HELP_COMMANDS
end

function KUI:GetNotesVersion()
	return PATCH_NOTES[1] and PATCH_NOTES[1].version or "?"
end

function KUI:GetAddonVersion()
	local v = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
		or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
	return type(v) == "string" and v or "?"
end
