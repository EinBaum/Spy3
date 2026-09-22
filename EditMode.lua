local L = Spy3.L

function Spy3:EditModeMinHeight()
	return math.max(48, Spy3.RowHeight * 3)
end

local function StopEditModeDrag(selection)
	selection:UnregisterEvent("PLAYER_REGEN_DISABLED")
	if not InCombatLockdown() then
		Spy3.MainWindow:StopMovingOrSizing()
		Spy3:PinTopLeft()
	end
	Spy3:SaveMainWindowPosition()
end

local function CreateSelection(frame)
	local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	selection:SetAllPoints(frame)
	selection:SetSystem({
		GetSystemName = function()
			return L["Spy3"]
		end,
	})
	selection:SetScript("OnMouseDown", function(self)
		if InCombatLockdown() then
			return
		end
		EditModeManagerFrame:ClearSelectedSystem()
		self:ShowSelected()
	end)
	selection:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then
			return
		end
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:StartMoving()
	end)
	selection:SetScript("OnDragStop", StopEditModeDrag)
	selection:SetScript("OnEvent", StopEditModeDrag)
	selection:Hide()
	return selection
end

function Spy3:OnEditModeEnter()
	Spy3.EditModeActive = true
	if not InCombatLockdown() then
		Spy3.MainWindow:Show()
	end
	Spy3.MainWindow.EditModeBackdrop:Show()
	Spy3:AutomaticallyResize()
	Spy3.EditModeSelection:ShowHighlighted()
end

function Spy3:OnEditModeExit()
	Spy3.EditModeActive = false
	Spy3.EditModeSelection:Hide()
	Spy3.MainWindow.EditModeBackdrop:Hide()
	if not InCombatLockdown() then
		Spy3.MainWindow:StopMovingOrSizing()
		Spy3:PinTopLeft()
		Spy3:AutomaticallyResize()
	end
	Spy3:SaveMainWindowPosition()
end

function Spy3:AttachEditMode()
	if Spy3.EditModeSelection then
		return
	end

	local frame = Spy3.MainWindow
	local backdrop = frame:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints(frame)
	backdrop:SetColorTexture(0, 0, 0, 0.45)
	backdrop:Hide()
	frame.EditModeBackdrop = backdrop

	Spy3.EditModeSelection = CreateSelection(frame)

	EditModeManagerFrame:HookScript("OnShow", function()
		Spy3:OnEditModeEnter()
	end)
	EditModeManagerFrame:HookScript("OnHide", function()
		Spy3:OnEditModeExit()
	end)
	hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
		local selection = Spy3.EditModeSelection
		if Spy3.EditModeActive and selection:IsSelected() then
			selection:ShowHighlighted()
		end
	end)

	if EditModeManagerFrame:IsShown() then
		Spy3:OnEditModeEnter()
	end
end

function Spy3:SetupEditMode()
	local loaded = C_AddOns.IsAddOnLoaded("Blizzard_EditMode")
	if not loaded then
		loaded = C_AddOns.LoadAddOn("Blizzard_EditMode")
	end
	if loaded then
		Spy3:AttachEditMode()
		return
	end

	local waiter = CreateFrame("Frame")
	waiter:RegisterEvent("ADDON_LOADED")
	waiter:SetScript("OnEvent", function(_, _, name)
		if name ~= "Blizzard_EditMode" then
			return
		end
		waiter:UnregisterAllEvents()
		waiter:SetScript("OnEvent", nil)
		Spy3:AttachEditMode()
	end)
end
