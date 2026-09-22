local L = Spy3.L

Spy3.ListLimit = 15
Spy3.RowHeight = 14
Spy3.TextHeight = 12
Spy3.WindowWidth = 160
Spy3.Scaling = 1.15
Spy3.BarTexture = [[Interface\RaidFrame\Raid-Bar-Hp-Fill]]
Spy3.ActiveTimeout = 30
Spy3.InactiveTimeout = 60

Spy3.NearbyList = {}
Spy3.ActiveList = {}
Spy3.InactiveList = {}
Spy3.ListAmountDisplayed = 0
Spy3.ButtonName = {}
Spy3.EnabledInZone = false
Spy3.PlayerData = {}
Spy3.StealthState = {}
Spy3.DetectionRegistered = false

local StealthSpellKind = {
	[1784] = "stealth",
	[1785] = "stealth",
	[1786] = "stealth",
	[1787] = "stealth",
	[5215] = "prowl",
	[6783] = "prowl",
	[9913] = "prowl",
}

-- type() is safe on a secret; comparisons and concatenation are not.
local function PlainString(value)
	if type(value) ~= "string" or not canaccessvalue(value) or value == "" then
		return nil
	end
	return value
end

local function PlainLevel(unit)
	local level = UnitLevel(unit)
	if type(level) ~= "number" or not canaccessvalue(level) or level < 1 then
		return nil
	end
	return level
end

SLASH_SPY31 = "/spy3"
SlashCmdList["SPY3"] = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "reset" then
		Spy3:ResetPositions()
	elseif msg == "test" then
		Spy3:AddTestData()
	end
end

function Spy3:ResetPositions()
	if InCombatLockdown() then
		return
	end
	Spy3DB.x = nil
	Spy3DB.y = nil
	Spy3.MainWindow:ClearAllPoints()
	Spy3.MainWindow:SetPoint("CENTER", UIParent)
	Spy3:PinTopLeft()
end

local EventFrame = CreateFrame("Frame")
local DetectionEvents = {
	"PLAYER_TARGET_CHANGED",
	"UPDATE_MOUSEOVER_UNIT",
	"NAME_PLATE_UNIT_ADDED",
	"UNIT_AURA",
}

function Spy3:UpdateDetectionEvents()
	if Spy3.EnabledInZone == Spy3.DetectionRegistered then
		return
	end
	Spy3.DetectionRegistered = Spy3.EnabledInZone
	for _, event in ipairs(DetectionEvents) do
		if Spy3.EnabledInZone then
			EventFrame:RegisterEvent(event)
		else
			EventFrame:UnregisterEvent(event)
		end
	end
end

function Spy3:Initialize()
	if Spy3.initialized then
		return
	end
	Spy3.initialized = true

	if type(Spy3DB) ~= "table" then
		Spy3DB = {}
	end

	Spy3:CreateMainWindow()

	EventFrame:RegisterEvent("ZONE_CHANGED")
	EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
	EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	C_Timer.NewTicker(10, function()
		Spy3:ManageExpirations()
	end)
end

EventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Spy3" then
			Spy3:Initialize()
		end
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
		Spy3:ZoneChanged()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if Spy3.ClearPending then
			Spy3:WipeLists()
		else
			Spy3:RefreshList()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		Spy3:DetectUnit("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		Spy3:DetectUnit("mouseover")
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		Spy3:DetectUnit(arg1)
	elseif event == "UNIT_AURA" then
		if not UnitOnTaxi("player") then
			Spy3:CheckUnitStealth(arg1)
		end
	end
end)
EventFrame:RegisterEvent("ADDON_LOADED")

function Spy3:ZoneChanged()
	local enabled = GetZoneText() ~= ""
	if enabled then
		local inInstance, instanceType = IsInInstance()
		if inInstance and (instanceType == "party" or instanceType == "raid") then
			enabled = false
		end
	end
	Spy3.EnabledInZone = enabled
	Spy3:UpdateDetectionEvents()
	if not InCombatLockdown() then
		Spy3.MainWindow:Show()
	end
	Spy3:RefreshList()
end

function Spy3:UnitListName(unit)
	local given, surname = UnitName(unit)
	given = PlainString(given)
	if not given then
		return nil
	end
	surname = PlainString(surname)
	if not surname then
		return given
	end
	return given..Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR..surname
end

function Spy3:DetectUnit(unit)
	if not UnitIsPlayer(unit) then
		return
	end
	local name = Spy3:UnitListName(unit)
	if not name then
		return
	end
	if not UnitIsEnemy("player", unit) then
		Spy3:RemoveDetected(name)
		return
	end

	local _, classFile = UnitClass(unit)
	local changed = Spy3:UpdatePlayerData(
		name,
		PlainString(classFile),
		PlainLevel(unit),
		PlainString(UnitRace(unit)),
		PlainString(GetGuildInfo(unit))
	)
	if not Spy3.EnabledInZone or UnitOnTaxi("player") then
		return
	end
	Spy3:AddDetected(name, time(), changed)
	Spy3:CheckUnitStealth(unit)
end

function Spy3:UnitStealthKind(unit)
	local unreadable = false
	for spellId, kind in pairs(StealthSpellKind) do
		if C_Secrets.ShouldSpellAuraBeSecret(spellId) then
			unreadable = true
		elseif C_UnitAuras.GetUnitAuraBySpellID(unit, spellId) then
			return kind
		end
	end
	-- A secret stealth aura cannot be queried, so the caller keeps the last alert.
	if unreadable then
		return false
	end
	if C_UnitAuras.GetAuraDataBySpellName(unit, L["Stealth"], "HELPFUL") then
		return "stealth"
	end
	if C_UnitAuras.GetAuraDataBySpellName(unit, L["Prowl"], "HELPFUL") then
		return "prowl"
	end
	return nil
end

function Spy3:CheckUnitStealth(unit)
	if not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then
		return
	end
	local name = Spy3:UnitListName(unit)
	if not name then
		return
	end
	local kind = Spy3:UnitStealthKind(unit)
	if kind == false then
		return
	end
	if not kind then
		Spy3.StealthState[name] = nil
		return
	end
	if Spy3.StealthState[name] == kind then
		return
	end
	Spy3.StealthState[name] = kind
	Spy3:AlertStealthOrProwl(kind, name)
end
