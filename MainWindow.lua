local L = Spy3.L

local function ClassColor(class)
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local c = class and colors[class]
	if c then
		return c.r, c.g, c.b
	end
	return 0.5, 0.5, 0.5
end

function Spy3:SetFontSize(fontString, size)
	local font, _, flags = fontString:GetFont()
	fontString:SetFont(font, size, flags)
end

local function AddBarEdge(parent, p1, p2, width, height)
	local edge = parent:CreateTexture(nil, "OVERLAY")
	edge:SetColorTexture(0, 0, 0, 1)
	edge:SetPoint(p1, parent, p1, 0, 0)
	edge:SetPoint(p2, parent, p2, 0, 0)
	if width then
		edge:SetWidth(width)
	end
	if height then
		edge:SetHeight(height)
	end
	return edge
end

local function SetRowBordersShown(row, shown)
	local alpha = shown and 1 or 0
	local bar = row.StatusBar
	bar.BorderBottom:SetAlpha(alpha)
	bar.BorderLeft:SetAlpha(alpha)
	bar.BorderRight:SetAlpha(alpha)
	if bar.BorderTop then
		bar.BorderTop:SetAlpha(alpha)
	end
end

function Spy3:SetupBar(row)
	row.StatusBar = CreateFrame("StatusBar", nil, row)
	row.StatusBar:SetAllPoints(row)
	row.StatusBar:EnableMouse(false)
	row.StatusBar:SetStatusBarTexture(Spy3.BarTexture)
	row.StatusBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.8)
	row.StatusBar:SetMinMaxValues(0, 100)
	row.StatusBar:SetValue(100)

	-- Interior rows skip a top edge so flush rows don't double the 1px separator.
	local bar = row.StatusBar
	bar.BorderBottom = AddBarEdge(bar, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	bar.BorderLeft = AddBarEdge(bar, "TOPLEFT", "BOTTOMLEFT", 1, nil)
	bar.BorderRight = AddBarEdge(bar, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	if row.id == 1 then
		bar.BorderTop = AddBarEdge(bar, "TOPLEFT", "TOPRIGHT", nil, 1)
	end

	local nameSize = math.max(Spy3.RowHeight * 0.75, Spy3.RowHeight - 3)
	local detailSize = math.max(Spy3.RowHeight * 0.65, Spy3.RowHeight - 12)

	row.LeftText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.LeftText:SetPoint("LEFT", bar, "LEFT", 2, 0)
	row.LeftText:SetJustifyH("LEFT")
	row.LeftText:SetHeight(Spy3.TextHeight)
	row.LeftText:SetTextColor(1, 1, 1, 1)
	row.LeftText:SetShadowColor(0, 0, 0, 1)
	row.LeftText:SetShadowOffset(1, -1)
	Spy3:SetFontSize(row.LeftText, nameSize)

	row.RightText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.RightText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
	row.RightText:SetJustifyH("RIGHT")
	row.RightText:SetTextColor(1, 1, 1, 1)
	row.RightText:SetShadowColor(0, 0, 0, 1)
	row.RightText:SetShadowOffset(1, -1)
	Spy3:SetFontSize(row.RightText, detailSize)
end

function Spy3:CreateRow(num)
	if Spy3.MainWindow.Rows[num] then
		return
	end

	local row = CreateFrame("Button", "Spy3_MainWindow_Bar"..num, Spy3.MainWindow, "SecureActionButtonTemplate")
	row:SetPoint("TOPLEFT", Spy3.MainWindow, "TOPLEFT", 0, -Spy3.RowHeight * (num - 1))
	row:SetHeight(Spy3.RowHeight)
	row:SetWidth(Spy3.MainWindow:GetWidth())
	row:RegisterForClicks("LeftButtonUp")
	row:SetAttribute("useOnKeyDown", false)
	row:SetAttribute("type1", "macro")
	row:SetAttribute("macrotext1", "")
	row.id = num
	row:EnableMouse(false)
	Spy3:SetupBar(row)

	-- Left click passes through to the secure row so /targetexact stays untainted.
	local overlay = CreateFrame("Frame", nil, Spy3.MainWindow)
	overlay:SetAllPoints(row)
	overlay:SetFrameLevel(row:GetFrameLevel() + 10)
	overlay:EnableMouse(false)
	overlay:SetPassThroughButtons("LeftButton")
	overlay:SetScript("OnEnter", function()
		Spy3:ShowTooltip(row, true)
	end)
	overlay:SetScript("OnLeave", function()
		Spy3:ShowTooltip(row, false)
	end)
	overlay:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			Spy3:ClearList()
		end
	end)
	row.Overlay = overlay

	Spy3.MainWindow.Rows[num] = row
	Spy3:BlankRow(num)
end

function Spy3:CreateMainWindow()
	if Spy3.MainWindow then
		return
	end

	local frame = CreateFrame("Frame", "Spy3_MainWindow", UIParent)
	frame:SetPoint("CENTER", UIParent)
	frame:SetHeight(Spy3.RowHeight)
	frame:SetWidth(Spy3.WindowWidth)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetScript("OnHide", function(self)
		if InCombatLockdown() then
			return
		end
		self:StopMovingOrSizing()
		Spy3:PinTopLeft()
	end)
	Spy3.MainWindow = frame

	frame.Counter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.Counter:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -4, 1)
	frame.Counter:SetJustifyH("RIGHT")
	frame.Counter:SetTextColor(1, 0.82, 0, 1)
	Spy3:SetFontSize(frame.Counter, Spy3.TextHeight)

	frame.Rows = {}
	for i = 1, Spy3.ListLimit do
		Spy3:CreateRow(i)
	end

	-- GetLeft/GetTop are in scaled space; scale before restoring the saved anchor.
	frame:SetScale(Spy3.Scaling)
	Spy3:RestoreMainWindowPosition()
	Spy3:SetupEditMode()
	Spy3:RefreshList()
end

function Spy3:SetBar(num, name, desc, class, opacity)
	local row = Spy3.MainWindow.Rows[num]
	row.StatusBar:SetValue(100)
	row.LeftText:SetText(name)
	row.RightText:SetText(desc)
	row.LeftText:SetWidth(row:GetWidth() - row.RightText:GetStringWidth() - 4)
	local r, g, b = ClassColor(class)
	row.StatusBar:SetStatusBarColor(r * 0.5, g * 0.5, b * 0.5, opacity)
	row.LeftText:SetTextColor(1, 1, 1, opacity)
	row.RightText:SetTextColor(1, 1, 1, opacity)
	SetRowBordersShown(row, true)
end

function Spy3:BlankRow(num)
	local row = Spy3.MainWindow.Rows[num]
	row.StatusBar:SetValue(0)
	row.LeftText:SetText("")
	row.RightText:SetText("")
	SetRowBordersShown(row, false)
end

-- StopMovingOrSizing anchors BOTTOMLEFT, so a later height change would grow upward.
function Spy3:PinTopLeft()
	if InCombatLockdown() then
		return
	end
	local frame = Spy3.MainWindow
	local left, top = frame:GetLeft(), frame:GetTop()
	if not left or not top then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

function Spy3:AutomaticallyResize()
	local detected = Spy3.ListAmountDisplayed
	if detected > Spy3.ListLimit then
		detected = Spy3.ListLimit
	end
	local height = 0.001
	if detected > 0 then
		height = detected * Spy3.RowHeight
	end
	if Spy3.EditModeActive then
		height = math.max(height, Spy3:EditModeMinHeight())
	end
	if InCombatLockdown() then
		return
	end
	local frame = Spy3.MainWindow
	if math.abs(frame:GetHeight() - height) < 0.01 then
		return
	end
	Spy3:PinTopLeft()
	frame:SetHeight(height)
end

function Spy3:SaveMainWindowPosition()
	Spy3DB.x = Spy3.MainWindow:GetLeft()
	Spy3DB.y = Spy3.MainWindow:GetTop()
end

function Spy3:RestoreMainWindowPosition()
	local x, y = Spy3DB.x, Spy3DB.y
	local frame = Spy3.MainWindow
	frame:ClearAllPoints()
	if not x or not y then
		frame:SetPoint("CENTER", UIParent)
	else
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	end
	frame:SetWidth(Spy3.WindowWidth)
	for i = 1, Spy3.ListLimit do
		frame.Rows[i]:SetWidth(Spy3.WindowWidth)
	end
	frame:SetHeight(Spy3.RowHeight)
	if not x or not y then
		Spy3:PinTopLeft()
	end
end

function Spy3:ShowTooltip(row, show)
	if not show then
		GameTooltip:Hide()
		return
	end
	local name = Spy3.ButtonName[row.id]
	if not name then
		return
	end
	GameTooltip:SetOwner(Spy3.MainWindow, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -CONTAINER_OFFSET_X - 13, CONTAINER_OFFSET_Y)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(name, 0.8, 0.3, 0.22)
	local data = Spy3.PlayerData[name]
	if data then
		if data.guild and data.guild ~= "" then
			GameTooltip:AddLine(data.guild, 1, 1, 1)
		end
		local details = ""
		if data.level then
			details = L["Level"].." "..data.level.." "
		end
		if data.race then
			details = details..data.race.." "
		end
		if data.class and L[data.class] then
			details = details..L[data.class]
		end
		if details ~= "" then
			GameTooltip:AddLine(details..L["Player"], 1, 1, 1)
		end
	end
	GameTooltip:Show()
end
