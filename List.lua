local L = Spy3.L

local function SortedNearby()
	local order = {}
	for player, first in pairs(Spy3.NearbyList) do
		order[#order + 1] = { player = player, time = first }
	end
	-- First-seen order, so a combat-frozen macro stays on the same row.
	table.sort(order, function(a, b)
		if a.time == b.time then
			return a.player < b.player
		end
		return a.time < b.time
	end)
	return order
end

function Spy3:RowVisual(player)
	local data = Spy3.PlayerData[player]
	local level = "??"
	local class = "UNKNOWN"
	if data then
		if data.level then
			level = data.level
		end
		if data.class then
			class = data.class
		end
	end
	local description = tostring(level)
	if L[class] then
		description = description.." "..L[class]
	end
	local opacity = 1
	if Spy3.InactiveList[player] then
		opacity = 0.7
	end
	return description, class, opacity
end

function Spy3:PaintRow(i, player, stale)
	local description, class, opacity = Spy3:RowVisual(player)
	if stale then
		opacity = 0.45
	end
	Spy3:SetBar(i, player, description, class, opacity)
	Spy3.ButtonName[i] = player
	if not stale then
		return
	end
	local row = Spy3.MainWindow.Rows[i]
	row.LeftText:SetTextColor(1, 0.4, 0.4, 1)
	row.RightText:SetTextColor(1, 0.4, 0.4, 1)
end

function Spy3:BindRow(i, player)
	local row = Spy3.MainWindow.Rows[i]
	row:SetAttribute("macrotext1", "/targetexact "..player)
	row.boundName = player
end

function Spy3:SetRowMouse(i, enabled)
	local row = Spy3.MainWindow.Rows[i]
	row:EnableMouse(enabled)
	row.Overlay:EnableMouse(enabled)
end

function Spy3:ShowPlayer(i, player)
	Spy3:PaintRow(i, player, false)
	Spy3:BindRow(i, player)
	Spy3:SetRowMouse(i, true)
end

function Spy3:ReleaseRow(i)
	local row = Spy3.MainWindow.Rows[i]
	row:SetAttribute("macrotext1", "")
	row.boundName = nil
	Spy3.ButtonName[i] = nil
	Spy3:BlankRow(i)
	Spy3:SetRowMouse(i, false)
end

function Spy3:RefreshListFree(order)
	local shown = #order
	if shown > Spy3.ListLimit then
		shown = Spy3.ListLimit
	end
	for i = 1, Spy3.ListLimit do
		if i <= shown then
			Spy3:ShowPlayer(i, order[i].player)
		else
			Spy3:ReleaseRow(i)
		end
	end
	Spy3.ListAmountDisplayed = shown
end

-- A secure row cannot retarget in combat. Keep its label on boundName.
function Spy3:RefreshListCombat(order)
	local present = {}
	for i = 1, #order do
		present[order[i].player] = true
	end

	local lockedSlot = {}
	local lockedName = {}
	for i = 1, Spy3.ListLimit do
		local row = Spy3.MainWindow.Rows[i]
		if row.boundName and row:IsMouseEnabled() then
			lockedSlot[i] = true
			lockedName[row.boundName] = true
			Spy3:PaintRow(i, row.boundName, not present[row.boundName])
		end
	end

	local filled = {}
	local slot = 1
	for i = 1, #order do
		local player = order[i].player
		if not lockedName[player] then
			while slot <= Spy3.ListLimit and lockedSlot[slot] do
				slot = slot + 1
			end
			if slot > Spy3.ListLimit then
				break
			end
			Spy3:PaintRow(slot, player, false)
			Spy3.MainWindow.Rows[slot].Overlay:EnableMouse(true)
			filled[slot] = true
			slot = slot + 1
		end
	end

	for i = 1, Spy3.ListLimit do
		if not lockedSlot[i] and not filled[i] then
			local row = Spy3.MainWindow.Rows[i]
			Spy3:BlankRow(i)
			Spy3.ButtonName[i] = nil
			row.Overlay:EnableMouse(false)
		end
	end
end

function Spy3:RefreshList()
	local order = SortedNearby()
	local counter = Spy3.MainWindow.Counter
	if #order > 0 then
		counter:SetText(tostring(#order))
		counter:Show()
	else
		counter:Hide()
	end

	if InCombatLockdown() then
		Spy3:RefreshListCombat(order)
	else
		Spy3:RefreshListFree(order)
	end
	Spy3:AutomaticallyResize()
end

function Spy3:ManageExpirations()
	local expired = false
	local currentTime = time()
	for player, seen in pairs(Spy3.ActiveList) do
		if (currentTime - seen) > Spy3.ActiveTimeout then
			Spy3.InactiveList[player] = seen
			Spy3.ActiveList[player] = nil
			expired = true
		end
	end
	for player, seen in pairs(Spy3.InactiveList) do
		if (currentTime - seen) > Spy3.InactiveTimeout then
			Spy3.InactiveList[player] = nil
			Spy3.NearbyList[player] = nil
			expired = true
		end
	end
	if expired then
		Spy3:RefreshList()
	end
end

function Spy3:WipeLists()
	Spy3.ClearPending = nil
	Spy3.NearbyList = {}
	Spy3.ActiveList = {}
	Spy3.InactiveList = {}
	Spy3.StealthState = {}
	Spy3.ListAmountDisplayed = 0
	Spy3:RefreshList()
end

-- Secure rows cannot be rebuilt in combat, so the wipe waits for PLAYER_REGEN_ENABLED.
function Spy3:ClearList()
	if InCombatLockdown() then
		Spy3.ClearPending = true
		return
	end
	Spy3:WipeLists()
end

function Spy3:RemoveDetected(name)
	Spy3.PlayerData[name] = nil
	Spy3.StealthState[name] = nil
	if not Spy3.NearbyList[name] then
		return
	end
	Spy3.NearbyList[name] = nil
	Spy3.ActiveList[name] = nil
	Spy3.InactiveList[name] = nil
	Spy3:RefreshList()
end

function Spy3:UpdatePlayerData(name, class, level, race, guild)
	local data = Spy3.PlayerData[name]
	local changed = not data
	if not data then
		data = { name = name }
		Spy3.PlayerData[name] = data
	end
	if class and data.class ~= class then
		data.class = class
		changed = true
	end
	if level and data.level ~= level then
		data.level = level
		changed = true
	end
	if race and data.race ~= race then
		data.race = race
		changed = true
	end
	if guild and data.guild ~= guild then
		data.guild = guild
		changed = true
	end
	return changed
end

function Spy3:AlertStealthOrProwl(kind, player)
	local prefix = L["StealthWarning"]
	if kind == "prowl" then
		prefix = L["ProwlWarning"]
	end
	UIErrorsFrame:AddMessage(prefix..player, 1, 1, 1, 1, UIERRORS_HOLD_TIME)
end

function Spy3:AddDetected(player, timestamp, changed)
	if not Spy3.NearbyList[player] then
		Spy3.ClearPending = nil
		Spy3.NearbyList[player] = timestamp
		Spy3.ActiveList[player] = timestamp
		Spy3.InactiveList[player] = nil
		Spy3:RefreshList()
	elseif not Spy3.ActiveList[player] then
		Spy3.ActiveList[player] = timestamp
		Spy3.InactiveList[player] = nil
		Spy3:RefreshList()
	else
		Spy3.ActiveList[player] = timestamp
		if changed then
			Spy3:RefreshList()
		end
	end
end

function Spy3:AddTestData()
	local fakes = {
		{ name = "Bigslam Skullcrusher", class = "WARRIOR", level = 60, race = "Orc" },
		{ name = "Holyfist Brightblade", class = "PALADIN", level = 60, race = "Human" },
		{ name = "Beastmaster Ironshot", class = "HUNTER", level = 59, race = "Dwarf" },
		{ name = "Sneakattack Shadowstep", class = "ROGUE", level = 60, race = "Night Elf" },
		{ name = "Mendwell Gravetide", class = "PRIEST", level = 58, race = "Undead" },
		{ name = "Totemic Stormhoof", class = "SHAMAN", level = 60, race = "Tauren" },
		{ name = "Frostfire Sparkcoil", class = "MAGE", level = 57, race = "Gnome" },
		{ name = "Felhunter Darktusk", class = "WARLOCK", level = 60, race = "Troll" },
		{ name = "Barkskin Oakenshade", class = "DRUID", level = 56, race = "Night Elf" },
		{ name = "Mystery Unknown", class = "UNKNOWN", level = 58, race = "Unknown" },
	}
	local now = time()
	for _, f in ipairs(fakes) do
		local changed = Spy3:UpdatePlayerData(f.name, f.class, f.level, f.race, "Test Guild")
		Spy3:AddDetected(f.name, now, changed)
	end
	Spy3:AlertStealthOrProwl("stealth", "Sneakattack Shadowstep")
end
