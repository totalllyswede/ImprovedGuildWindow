-- IGW_GuildCalendarWindow.lua
-- Simple Calendar GUI for WoW 1.12.1

IGWCalendarUI = IGWCalendarUI or {}
local UI = IGWCalendarUI

local frame
local rows = {}
local selectedEventId = nil
local scrollOffset = 0
local visibleRows = 12  -- Start with 12 (form hidden), changes to 8 when form shown
local updatingScrollbar = false  -- Prevent recursion

local MAX_ROWS = 14  -- Maximum rows that can be created
local ROW_H = 22

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function say(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Calendar]|r " .. tostring(msg))
    end
end

local function GetPlayerRankIndex(playerName)
    if not playerName then return 10 end
    
    GuildRoster()
    local numMembers = GetNumGuildMembers(true)
    
    for i = 1, numMembers do
        local name, rank, rankIndex = GetGuildRosterInfo(i)
        if name == playerName then
            return rankIndex
        end
    end
    
    return 10
end

local function CanDeleteEvent(event)
    if not event then return false end
    
    local myRank = GetPlayerRankIndex(UnitName("player"))
    local creatorRank = event.creator_rank or GetPlayerRankIndex(event.created_by)
    
    return (event.created_by == UnitName("player")) or (myRank < creatorRank)
end

local function getTheme()
    local bg = { r = 0.15, g = 0.15, b = 0.15 }
    local op = 0.95

    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
        bg = ImprovedGuildWindowDB.bgColor
    end
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.opacity then
        op = ImprovedGuildWindowDB.opacity
    end

    return bg, op
end

local function applyTheme()
    local bg, op = getTheme()
    if frame and frame.bgTexture then
        frame.bgTexture:SetTexture(bg.r, bg.g, bg.b, op)
    end
    if monthViewFrame and monthViewFrame.bgTexture then
        monthViewFrame.bgTexture:SetTexture(bg.r, bg.g, bg.b, op)
    end
end

local function sortedEvents()
    if not IGWCalendarDB or not IGWCalendarDB.events then return {} end

    local list = {}
    for id, e in pairs(IGWCalendarDB.events) do
        if e then
            table.insert(list, { id = id, e = e })
        end
    end

    table.sort(list, function(a, b)
        local at = tonumber(a.e.start_ts) or 0
        local bt = tonumber(b.e.start_ts) or 0
        if at == bt then
            return tostring(a.id) < tostring(b.id)
        end
        return at < bt
    end)

    return list
end

local function refreshList()
    if not frame or not frame:IsVisible() then return end

    local list = sortedEvents()
    local now = time()
    
    -- Clamp scroll offset
    local maxOffset = math.max(0, table.getn(list) - visibleRows)
    if scrollOffset > maxOffset then
        scrollOffset = maxOffset
    end
    if scrollOffset < 0 then
        scrollOffset = 0
    end
    
    -- Update scrollbar
    if frame.scrollBar then
        if table.getn(list) > visibleRows then
            frame.scrollBar:Show()
            -- Update scrollbar position (with recursion guard)
            local scrollRange = maxOffset
            if scrollRange > 0 and not updatingScrollbar then
                updatingScrollbar = true
                local thumbPos = scrollOffset / scrollRange
                frame.scrollBar:SetValue(thumbPos)
                updatingScrollbar = false
            end
        else
            frame.scrollBar:Hide()
        end
    end

    for i = 1, MAX_ROWS do
        local row = rows[i]
        
        -- Show/hide rows based on visibleRows
        if i > visibleRows then
            row:Hide()
        else
            local listIndex = i + scrollOffset
            local it = list[listIndex]

        if it then
            local e = it.e
            row.event_id = it.id
            
            -- Get event type color
            local typeColors = {
                ["Raid"] = "|cFFFF0000",
                ["Dungeon"] = "|cFF00FF00",
                ["PvP"] = "|cFFFF8800",
                ["Guild Event"] = "|cFF00FFFF",
                ["Meeting"] = "|cFFFFFF00",
                ["Social"] = "|cFFFF00FF",
                ["Other"] = "|cFFFFFFFF"
            }
            local typeColor = typeColors[e.event_type] or "|cFFFFFFFF"
            local typeTag = "[" .. (e.event_type or "Other") .. "]"
            
            row.title:SetText(typeColor .. typeTag .. "|r " .. tostring(e.title or "(no title)"))
            
            -- Parse date/time into separate columns
            local dayOfWeek = "?"
            local dateStr = "?"
            local timeStr = "?"
            if e.start_ts and e.start_ts > 0 then
                local dt = date("*t", e.start_ts)
                if dt then
                    local days = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
                    dayOfWeek = days[dt.wday] or "?"
                    dateStr = string.format("%04d-%02d-%02d", dt.year, dt.month, dt.day)
                    timeStr = string.format("%02d:%02d", dt.hour, dt.min)
                end
            end
            
            row.dayCol:SetText(dayOfWeek)
            row.dateCol:SetText(dateStr)
            row.timeCol:SetText(timeStr)
            
            -- Calculate time until event and status
            local statusText = ""
            local statusColor = "|cFFFFFFFF"
            if e.start_ts and e.start_ts > 0 then
                local timeUntil = e.start_ts - now
                local endTime = e.end_ts or (e.start_ts + 3600)
                
                if now >= e.start_ts and now <= endTime then
                    -- Event is happening now
                    statusText = "|cFF00FF00[NOW]|r"
                elseif now > endTime then
                    -- Event is past
                    statusText = "|cFF888888[Past]|r"
                else
                    -- Event is upcoming
                    statusColor = "|cFFFFFF00"
                    if timeUntil < 3600 then
                        -- Less than 1 hour
                        local mins = math.floor(timeUntil / 60)
                        statusText = statusColor .. "in " .. mins .. "m|r"
                    elseif timeUntil < 86400 then
                        -- Less than 1 day
                        local hours = math.floor(timeUntil / 3600)
                        local mins = math.floor(math.mod(timeUntil, 3600) / 60)
                        statusText = statusColor .. "in " .. hours .. "h " .. mins .. "m|r"
                    else
                        -- More than 1 day
                        local days = math.floor(timeUntil / 86400)
                        local hours = math.floor(math.mod(timeUntil, 86400) / 3600)
                        statusText = statusColor .. "in " .. days .. "d " .. hours .. "h|r"
                    end
                end
            end
            
            row.status:SetText(statusText)
            row.creator:SetText(tostring(e.created_by or "?"))

            if selectedEventId == it.id then
                row:SetBackdropColor(0.3, 0.3, 0.4, 1)
            else
                row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            end

            row:Show()
        else
            row.event_id = nil
            row:Hide()
        end
        end  -- Close the if i > visibleRows else block
    end  -- Close the for loop
end  -- Close the refreshList function

------------------------------------------------------------
-- Calendar Picker Dialog
------------------------------------------------------------
local function createCalendarPicker(parentFrame)
    local picker = CreateFrame("Frame", nil, parentFrame)
    picker:SetWidth(250)
    picker:SetHeight(260)
    picker:SetFrameStrata("FULLSCREEN")
    picker:SetFrameLevel(100)
    picker:SetPoint("TOPLEFT", parentFrame.dateBox, "BOTTOMLEFT", 0, -5)
    picker:Hide()
    
    picker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    picker:SetBackdropColor(0, 0, 0, 0.95)
    picker:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Current displayed month/year
    local currentMonth = tonumber(date("%m"))
    local currentYear = tonumber(date("%Y"))
    
    -- Layout constants (matches month view rhythm)
    local colSpacing = 33      -- column stride
    local colWidth = 29        -- button/cell width
    local marginLeft = 18      -- left margin
    local headerY = -12        -- month/year header top offset
    local dayHeaderY = -32     -- day-of-week headers top offset
    local gridStartY = -48     -- grid top offset (below day headers)
    
    -- Month/Year header (centered, fixed width so nav buttons stay put)
    local header = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", picker, "TOP", 0, headerY)
    header:SetWidth(160)
    header:SetJustifyH("CENTER")
    
    -- Nav buttons: fixed inset from edges, vertically aligned with header
    local prevBtn = CreateFrame("Button", nil, picker)
    prevBtn:SetPoint("TOPLEFT", picker, "TOPLEFT", 35, headerY + 2)
    prevBtn:SetWidth(20)
    prevBtn:SetHeight(20)
    prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    
    local nextBtn = CreateFrame("Button", nil, picker)
    nextBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -35, headerY + 2)
    nextBtn:SetWidth(20)
    nextBtn:SetHeight(20)
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    
    -- Day-of-week headers (S M T W T F S) — same column positions as the grid
    local dayNames = {"S", "M", "T", "W", "T", "F", "S"}
    for i = 0, 6 do
        local dh = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dh:SetPoint("TOPLEFT", picker, "TOPLEFT", marginLeft + i * colSpacing, dayHeaderY)
        dh:SetWidth(colWidth)
        dh:SetJustifyH("CENTER")
        dh:SetText(dayNames[i + 1])
    end
    
    -- Day buttons (7 cols x 6 rows) — same column positions as headers
    local dayButtons = {}
    for row = 0, 5 do
        for col = 0, 6 do
            local btn = CreateFrame("Button", nil, picker)
            btn:SetPoint("TOPLEFT", picker, "TOPLEFT", marginLeft + col * colSpacing, gridStartY - row * colSpacing)
            btn:SetWidth(colWidth)
            btn:SetHeight(colWidth)
            
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.text = btnText
            
            btn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16
            })
            btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            
            btn:SetScript("OnEnter", function()
                this:SetBackdropColor(0.3, 0.3, 0.4, 1)
            end)
            btn:SetScript("OnLeave", function()
                this:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            end)
            
            table.insert(dayButtons, btn)
        end
    end
    
    local function updateCalendar()
        local monthNames = {"January", "February", "March", "April", "May", "June", 
                           "July", "August", "September", "October", "November", "December"}
        header:SetText(monthNames[currentMonth] .. " " .. currentYear)
        
        -- Get first day of month (0=Sun .. 6=Sat)
        local firstDay = tonumber(date("%w", time({year=currentYear, month=currentMonth, day=1})))
        local daysInMonth = tonumber(date("%d", time({year=currentYear, month=currentMonth+1, day=0})))
        
        -- Clear all buttons
        for i, btn in ipairs(dayButtons) do
            btn.text:SetText("")
            btn:Hide()
            btn:SetScript("OnClick", nil)
        end
        
        -- Fill in days — index into flat array: firstDay + day (1-based, matches month view)
        for day = 1, daysInMonth do
            local btnIndex = firstDay + day
            if btnIndex <= 42 then
                local btn = dayButtons[btnIndex]
                btn.text:SetText(tostring(day))
                btn:Show()
                
                local dayValue = day
                btn:SetScript("OnClick", function()
                    local dateStr = string.format("%04d-%02d-%02d", currentYear, currentMonth, dayValue)
                    parentFrame.dateBox:SetText(dateStr)
                    picker:Hide()
                end)
            end
        end
    end
    
    prevBtn:SetScript("OnClick", function()
        currentMonth = currentMonth - 1
        if currentMonth < 1 then
            currentMonth = 12
            currentYear = currentYear - 1
        end
        updateCalendar()
    end)
    
    nextBtn:SetScript("OnClick", function()
        currentMonth = currentMonth + 1
        if currentMonth > 12 then
            currentMonth = 1
            currentYear = currentYear + 1
        end
        updateCalendar()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", picker, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() picker:Hide() end)
    
    updateCalendar()
    parentFrame.calendarPicker = picker
end

------------------------------------------------------------
-- Actions
------------------------------------------------------------
local function doSync()
    if IGWCalendar and IGWCalendar.SyncEvents then
        IGWCalendar:SyncEvents()
        refreshList()
    end
end

local function doDeleteSelected()
    if not selectedEventId then
        say("Select an event first")
        return
    end

    if IGWCalendar and IGWCalendar.DeleteEvent then
        IGWCalendar:DeleteEvent(selectedEventId)
        selectedEventId = nil
        scrollOffset = 0  -- Reset scroll to top
        refreshList()
    end
end

local function doAddEvent()
    if not frame then return end
    
    local title = frame.titleBox:GetText()
    if not title or title == "" then
        say("Title required")
        return
    end

    -- Get event type
    local eventType = "Other"
    if frame.typeDropdown and frame.typeDropdown.selectedType then
        eventType = frame.typeDropdown.selectedType
    end

    -- Parse date (YYYY-MM-DD)
    local dateStr = frame.dateBox:GetText()
    local _, _, year, month, day = string.find(dateStr, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    
    if not year or not month or not day then
        say("Date must be YYYY-MM-DD format")
        return
    end

    -- Parse time (HH:MM)
    local timeStr = frame.timeBox:GetText()
    local _, _, hour, min = string.find(timeStr, "^(%d%d):(%d%d)$")
    
    if not hour or not min then
        say("Time must be HH:MM format")
        return
    end

    -- Parse duration
    local duration = tonumber(frame.durationBox:GetText())
    if not duration or duration <= 0 then
        say("Duration must be a positive number")
        return
    end

    -- Get description
    local description = frame.descBox:GetText() or ""

    -- Convert to timestamp
    local timestamp = time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = 0
    })

    if not timestamp or timestamp <= 0 then
        say("Invalid date/time")
        return
    end

    if IGWCalendar and IGWCalendar.AddEventWithTime then
        IGWCalendar:AddEventWithTime(title, timestamp, duration, description, eventType)
        frame.titleBox:SetText("")
        frame.descBox:SetText("")
        scrollOffset = 0  -- Reset scroll to top
        refreshList()
        if monthViewFrame then
            refreshMonthView()
        end
    end
end

------------------------------------------------------------
-- Window Creation
------------------------------------------------------------
function UI:CreateWindow()
    if frame then return end

    frame = CreateFrame("Frame", "IGW_GuildCalendarFrame", UIParent)
    frame:SetWidth(600)
    frame:SetHeight(450)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(50)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Register with ESC key handler
    table.insert(UISpecialFrames, "IGW_GuildCalendarFrame")
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
    bgTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
    frame.bgTexture = bgTexture
    applyTheme()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "IGW_GuildCalendarFrame")
    end

    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOP", frame, "TOP", 0, 0)
    titleBar:SetWidth(frame:GetWidth() - 40)
    titleBar:SetHeight(40)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Title text
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", frame, "TOP", 0, -18)
    titleText:SetText("Guild Calendar")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Add Event Section (initially hidden)
    local addEventFrame = CreateFrame("Frame", nil, frame)
    addEventFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -50)
    addEventFrame:SetWidth(600)
    addEventFrame:SetHeight(140)
    addEventFrame:Hide()
    frame.addEventFrame = addEventFrame

    local yOffset = -10

    local addHeader = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addHeader:SetPoint("TOPLEFT", addEventFrame, "TOPLEFT", 20, yOffset)
    addHeader:SetText("Add Event:")

    yOffset = yOffset - 22

    -- Title input
    local titleLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleLabel:SetPoint("TOPLEFT", addEventFrame, "TOPLEFT", 20, yOffset)
    titleLabel:SetText("Title:")

    local titleBox = CreateFrame("EditBox", nil, addEventFrame)
    titleBox:SetPoint("LEFT", titleLabel, "RIGHT", 10, 0)
    titleBox:SetWidth(200)
    titleBox:SetHeight(20)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(35)
    titleBox:SetFrameStrata("DIALOG")
    titleBox:SetFrameLevel(frame:GetFrameLevel() + 5)
    titleBox:SetFontObject(GameFontHighlightSmall)
    titleBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    titleBox:SetBackdropColor(0, 0, 0, 0.8)
    titleBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    titleBox:SetTextInsets(6, 6, 0, 0)
    titleBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    titleBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    frame.titleBox = titleBox

    -- Event Type dropdown (same line as title)
    local typeLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("LEFT", titleBox, "RIGHT", 15, 0)
    typeLabel:SetText("Type:")

    local typeDropdown = CreateFrame("Button", "IGWCalTypeDropdown", addEventFrame)
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", 5, 0)
    typeDropdown:SetWidth(100)
    typeDropdown:SetHeight(20)
    typeDropdown:SetFrameStrata("DIALOG")
    typeDropdown:SetFrameLevel(frame:GetFrameLevel() + 5)
    typeDropdown:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    typeDropdown:SetBackdropColor(0, 0, 0, 0.8)
    typeDropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    typeDropdown:EnableMouse(true)
    
    local typeText = typeDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeText:SetPoint("LEFT", typeDropdown, "LEFT", 6, 0)
    typeText:SetText("Raid")
    typeDropdown.text = typeText
    typeDropdown.selectedType = "Raid"
    
    local typeArrow = typeDropdown:CreateTexture(nil, "ARTWORK")
    typeArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    typeArrow:SetPoint("RIGHT", typeDropdown, "RIGHT", -3, 0)
    typeArrow:SetWidth(12)
    typeArrow:SetHeight(12)
    
    -- Dropdown menu
    local typeMenu = CreateFrame("Frame", nil, typeDropdown)
    typeMenu:SetWidth(100)
    typeMenu:SetHeight(140)
    typeMenu:SetFrameStrata("FULLSCREEN")
    typeMenu:SetFrameLevel(110)
    typeMenu:SetPoint("TOPLEFT", typeDropdown, "BOTTOMLEFT", 0, -2)
    typeMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    typeMenu:SetBackdropColor(0, 0, 0, 0.95)
    typeMenu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    typeMenu:Hide()
    
    local eventTypes = {
        {name = "Raid", color = "|cFFFF0000"},
        {name = "Dungeon", color = "|cFF00FF00"},
        {name = "PvP", color = "|cFFFF8800"},
        {name = "Guild Event", color = "|cFF00FFFF"},
        {name = "Meeting", color = "|cFFFFFF00"},
        {name = "Social", color = "|cFFFF00FF"},
        {name = "Other", color = "|cFFFFFFFF"}
    }
    
    local menuButtons = {}
    for i, typeData in ipairs(eventTypes) do
        local btn = CreateFrame("Button", nil, typeMenu)
        btn:SetWidth(92)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", typeMenu, "TOPLEFT", 4, -4 - ((i-1) * 18))
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("LEFT", btn, "LEFT", 5, 0)
        btnText:SetText(typeData.color .. typeData.name .. "|r")
        btn.text = btnText
        
        -- Capture values in closure
        local typeName = typeData.name
        local typeColor = typeData.color
        
        btn:SetScript("OnEnter", function()
            this:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})
            this:SetBackdropColor(0.3, 0.3, 0.4, 1)
        end)
        btn:SetScript("OnLeave", function()
            this:SetBackdrop(nil)
        end)
        btn:SetScript("OnClick", function()
            typeDropdown.selectedType = typeName
            typeText:SetText(typeColor .. typeName .. "|r")
            typeMenu:Hide()
        end)
        
        table.insert(menuButtons, btn)
    end
    
    typeDropdown:SetScript("OnClick", function()
        if typeMenu:IsVisible() then
            typeMenu:Hide()
        else
            typeMenu:Show()
        end
    end)
    
    frame.typeDropdown = typeDropdown

    yOffset = yOffset - 22

    -- Date input
    local dateLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateLabel:SetPoint("TOPLEFT", addEventFrame, "TOPLEFT", 20, yOffset)
    dateLabel:SetText("Date:")

    local dateBox = CreateFrame("EditBox", nil, addEventFrame)
    dateBox:SetPoint("LEFT", dateLabel, "RIGHT", 10, 0)
    dateBox:SetWidth(85)
    dateBox:SetHeight(20)
    dateBox:SetAutoFocus(false)
    dateBox:SetMaxLetters(10)
    dateBox:SetText("2025-02-01")
    dateBox:SetFrameStrata("DIALOG")
    dateBox:SetFrameLevel(frame:GetFrameLevel() + 5)
    dateBox:SetFontObject(GameFontHighlightSmall)
    dateBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    dateBox:SetBackdropColor(0, 0, 0, 0.8)
    dateBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dateBox:SetTextInsets(6, 6, 0, 0)
    dateBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    dateBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    frame.dateBox = dateBox

    -- Calendar picker button
    local calBtn = CreateFrame("Button", nil, addEventFrame)
    calBtn:SetPoint("LEFT", dateBox, "RIGHT", 3, 0)
    calBtn:SetWidth(18)
    calBtn:SetHeight(18)
    calBtn:SetFrameStrata("DIALOG")
    calBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
    calBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    calBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    calBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    calBtn:SetScript("OnClick", function()
        if not frame.calendarPicker then
            createCalendarPicker(frame)
        end
        if frame.calendarPicker:IsVisible() then
            frame.calendarPicker:Hide()
        else
            frame.calendarPicker:Show()
        end
    end)

    -- Time input
    local timeLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("LEFT", calBtn, "RIGHT", 15, 0)
    timeLabel:SetText("Time:")

    local timeBox = CreateFrame("EditBox", nil, addEventFrame)
    timeBox:SetPoint("LEFT", timeLabel, "RIGHT", 5, 0)
    timeBox:SetWidth(50)
    timeBox:SetHeight(20)
    timeBox:SetAutoFocus(false)
    timeBox:SetMaxLetters(5)
    timeBox:SetText("20:00")
    timeBox:SetFrameStrata("DIALOG")
    timeBox:SetFrameLevel(frame:GetFrameLevel() + 5)
    timeBox:SetFontObject(GameFontHighlightSmall)
    timeBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    timeBox:SetBackdropColor(0, 0, 0, 0.8)
    timeBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    timeBox:SetTextInsets(6, 6, 0, 0)
    timeBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    timeBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    frame.timeBox = timeBox

    -- Duration input
    local durationLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("LEFT", timeBox, "RIGHT", 15, 0)
    durationLabel:SetText("Dur(m):")

    local durationBox = CreateFrame("EditBox", nil, addEventFrame)
    durationBox:SetPoint("LEFT", durationLabel, "RIGHT", 5, 0)
    durationBox:SetWidth(40)
    durationBox:SetHeight(20)
    durationBox:SetAutoFocus(false)
    durationBox:SetMaxLetters(4)
    durationBox:SetText("60")
    durationBox:SetFrameStrata("DIALOG")
    durationBox:SetFrameLevel(frame:GetFrameLevel() + 5)
    durationBox:SetFontObject(GameFontHighlightSmall)
    durationBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    durationBox:SetBackdropColor(0, 0, 0, 0.8)
    durationBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    durationBox:SetTextInsets(6, 6, 0, 0)
    durationBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    durationBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    frame.durationBox = durationBox

    yOffset = yOffset - 27

    -- Description input
    local descLabel = addEventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", addEventFrame, "TOPLEFT", 20, yOffset)
    descLabel:SetText("Desc:")

    local descFrame = CreateFrame("Frame", nil, addEventFrame)
    descFrame:SetPoint("LEFT", descLabel, "RIGHT", 10, 0)
    descFrame:SetWidth(460)
    descFrame:SetHeight(35)
    descFrame:SetFrameStrata("DIALOG")
    descFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    descFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    descFrame:SetBackdropColor(0, 0, 0, 0.8)
    descFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local descBox = CreateFrame("EditBox", nil, descFrame)
    descBox:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 8, -8)
    descBox:SetWidth(445)
    descBox:SetHeight(25)
    descBox:SetMultiLine(true)
    descBox:SetAutoFocus(false)
    descBox:SetMaxLetters(108)
    descBox:SetFontObject(GameFontHighlightSmall)
    descBox:SetFrameStrata("DIALOG")
    descBox:SetFrameLevel(frame:GetFrameLevel() + 6)
    descBox:EnableMouse(true)
    descBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    frame.descBox = descBox

    yOffset = yOffset - 30

    -- Add Event button (moved up, no Hide button)
    local addBtn = CreateFrame("Button", nil, addEventFrame, "UIPanelButtonTemplate")
    addBtn:SetPoint("TOPLEFT", addEventFrame, "TOPLEFT", 20, yOffset)
    addBtn:SetWidth(100)
    addBtn:SetHeight(22)
    addBtn:SetText("Add Event")
    addBtn:SetScript("OnClick", function()
        doAddEvent()
        -- Hide add event frame after adding
        frame.addEventFrame:Hide()
        frame.toggleAddBtn:SetText("Add Event")
        visibleRows = 12  -- Restore to 12 rows
        -- Reposition event list
        frame.listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
        frame.headerFrame:SetPoint("TOPLEFT", frame.listHeader, "BOTTOMLEFT", 0, -10)
        for i = 1, MAX_ROWS do
            if i == 1 then
                rows[i]:SetPoint("TOPLEFT", frame.headerFrame, "BOTTOMLEFT", 0, -2)
            end
        end
        -- Resize scrollbar
        if frame.scrollBar then
            frame.scrollBar:SetHeight(visibleRows * (ROW_H + 2))
        end
        refreshList()
    end)

    yOffset = yOffset - 30

    -- Event List Header (starts at top, no divider)
    local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
    listHeader:SetText("Events:")
    frame.listHeader = listHeader

    -- Add Event toggle button (40px from "Events:")
    local toggleAddBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleAddBtn:SetPoint("LEFT", listHeader, "RIGHT", 40, 0)
    toggleAddBtn:SetWidth(80)
    toggleAddBtn:SetHeight(22)
    toggleAddBtn:SetText("Add Event")
    
    toggleAddBtn:SetScript("OnClick", function()
        if frame.addEventFrame:IsVisible() then
            -- Hide add event frame
            frame.addEventFrame:Hide()
            this:SetText("Add Event")
            visibleRows = 12  -- 12 rows when form hidden
            -- Move list back up
            listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
            frame.headerFrame:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -10)
            for i = 1, MAX_ROWS do
                if i == 1 then
                    rows[i]:SetPoint("TOPLEFT", frame.headerFrame, "BOTTOMLEFT", 0, -2)
                end
            end
            -- Resize scrollbar
            if frame.scrollBar then
                frame.scrollBar:SetHeight(visibleRows * (ROW_H + 2))
            end
        else
            -- Show add event frame
            frame.addEventFrame:Show()
            this:SetText("Hide")
            visibleRows = 8  -- 8 rows when form shown
            -- Move list down
            listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -190)
            frame.headerFrame:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -10)
            for i = 1, MAX_ROWS do
                if i == 1 then
                    rows[i]:SetPoint("TOPLEFT", frame.headerFrame, "BOTTOMLEFT", 0, -2)
                end
            end
            -- Resize scrollbar
            if frame.scrollBar then
                frame.scrollBar:SetHeight(visibleRows * (ROW_H + 2))
            end
        end
        refreshList()
    end)
    frame.toggleAddBtn = toggleAddBtn

    -- Sync button
    local syncBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    syncBtn:SetPoint("LEFT", toggleAddBtn, "RIGHT", 10, 0)
    syncBtn:SetWidth(80)
    syncBtn:SetHeight(22)
    syncBtn:SetText("Sync")
    syncBtn:SetScript("OnClick", doSync)

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", syncBtn, "RIGHT", 10, 0)
    deleteBtn:SetWidth(80)
    deleteBtn:SetHeight(22)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", doDeleteSelected)

    -- Event list rows (start higher up without divider)
    
    -- Column headers (positioned relative to listHeader with more spacing)
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -10)
    headerFrame:SetWidth(frame:GetWidth() - 60)  -- Reduced width for scrollbar
    headerFrame:SetHeight(18)
    headerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16
    })
    headerFrame:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
    frame.headerFrame = headerFrame
    
    -- Mouse wheel scrolling on header
    headerFrame:EnableMouseWheel(true)
    headerFrame:SetScript("OnMouseWheel", function()
        if arg1 > 0 then
            scrollOffset = scrollOffset - 1
            if scrollOffset < 0 then scrollOffset = 0 end
        else
            scrollOffset = scrollOffset + 1
        end
        refreshList()
    end)
    
    local headerEvent = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerEvent:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
    headerEvent:SetWidth(150)
    headerEvent:SetJustifyH("LEFT")
    headerEvent:SetText("|cFFFFFF00Event|r")
    
    local headerDay = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerDay:SetPoint("LEFT", headerEvent, "RIGHT", 5, 0)
    headerDay:SetWidth(35)
    headerDay:SetJustifyH("LEFT")
    headerDay:SetText("|cFFFFFF00Day|r")
    
    local headerDate = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerDate:SetPoint("LEFT", headerDay, "RIGHT", 5, 0)
    headerDate:SetWidth(75)
    headerDate:SetJustifyH("LEFT")
    headerDate:SetText("|cFFFFFF00Date|r")
    
    local headerTime = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerTime:SetPoint("LEFT", headerDate, "RIGHT", 5, 0)
    headerTime:SetWidth(50)
    headerTime:SetJustifyH("LEFT")
    headerTime:SetText("|cFFFFFF00Server Time|r")
    
    local headerUntil = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerUntil:SetPoint("LEFT", headerTime, "RIGHT", 5, 0)
    headerUntil:SetWidth(80)
    headerUntil:SetJustifyH("LEFT")
    headerUntil:SetText("|cFFFFFF00Time Until|r")
    
    local headerBy = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerBy:SetPoint("LEFT", headerUntil, "RIGHT", 5, 0)
    headerBy:SetWidth(80)
    headerBy:SetJustifyH("LEFT")
    headerBy:SetText("|cFFFFFF00Added By|r")
    
    -- Standard scrollbar (positioned to the right of the event list, inside window)
    local scrollBar = CreateFrame("Slider", nil, frame)
    scrollBar:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", 20, -10)  -- Left padding +4, lowered 10px
    scrollBar:SetWidth(16)
    scrollBar:SetHeight(visibleRows * (ROW_H + 2))
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(0.1)
    
    -- Scrollbar textures
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    scrollBar:SetBackdropColor(0, 0, 0, 0.5)
    
    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumb:SetWidth(16)
    thumb:SetHeight(24)
    scrollBar:SetThumbTexture(thumb)
    
    scrollBar:SetScript("OnValueChanged", function()
        if updatingScrollbar then return end  -- Prevent recursion
        local list = sortedEvents()
        local maxOffset = math.max(0, table.getn(list) - visibleRows)
        scrollOffset = math.floor(arg1 * maxOffset + 0.5)
        refreshList()
    end)
    
    scrollBar:Hide()
    frame.scrollBar = scrollBar
    
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(frame:GetWidth() - 60)  -- Reduced width for scrollbar
        row:SetHeight(ROW_H)
        if i == 1 then
            row:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -2)
        else
            row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2)
        end
        
        row:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true,
            tileSize = 16
        })
        row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

        row:SetScript("OnEnter", function()
            if row.event_id then
                this:SetBackdropColor(0.2, 0.2, 0.3, 0.8)
                
                -- Show tooltip with description
                local e = IGWCalendarDB.events[row.event_id]
                if e and e.description and e.description ~= "" then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    GameTooltip:SetText(e.title or "Event", 1, 1, 1)
                    GameTooltip:AddLine(e.description, nil, nil, nil, 1)
                    GameTooltip:Show()
                end
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if row.event_id then
                if selectedEventId == row.event_id then
                    this:SetBackdropColor(0.3, 0.3, 0.4, 1)
                else
                    this:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
                end
            end
        end)
        row:SetScript("OnClick", function()
            if row.event_id then
                selectedEventId = row.event_id
                refreshList()
            end
        end)
        
        -- Mouse wheel scrolling
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function()
            if arg1 > 0 then
                -- Scroll up
                scrollOffset = scrollOffset - 1
                if scrollOffset < 0 then scrollOffset = 0 end
            else
                -- Scroll down
                scrollOffset = scrollOffset + 1
            end
            refreshList()
        end)

        -- Title (Event column)
        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("LEFT", row, "LEFT", 5, 0)
        title:SetWidth(150)
        title:SetJustifyH("LEFT")
        row.title = title

        -- Day of week column
        local dayCol = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dayCol:SetPoint("LEFT", title, "RIGHT", 5, 0)
        dayCol:SetWidth(35)
        dayCol:SetJustifyH("LEFT")
        row.dayCol = dayCol

        -- Date column
        local dateCol = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dateCol:SetPoint("LEFT", dayCol, "RIGHT", 5, 0)
        dateCol:SetWidth(75)
        dateCol:SetJustifyH("LEFT")
        row.dateCol = dateCol

        -- Time column
        local timeCol = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeCol:SetPoint("LEFT", dateCol, "RIGHT", 5, 0)
        timeCol:SetWidth(50)
        timeCol:SetJustifyH("LEFT")
        row.timeCol = timeCol

        -- Status (time until / NOW / Past)
        local status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("LEFT", timeCol, "RIGHT", 5, 0)
        status:SetWidth(80)
        status:SetJustifyH("LEFT")
        row.status = status

        -- Creator
        local creator = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        creator:SetPoint("LEFT", status, "RIGHT", 5, 0)
        creator:SetWidth(80)
        creator:SetJustifyH("LEFT")
        row.creator = creator

        row:Hide()
        rows[i] = row
    end

    -- Switch to Guild Window button (same row as Sync/Delete)
    local guildBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    guildBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 10, 0)
    guildBtn:SetWidth(192)
    guildBtn:SetHeight(22)
    guildBtn:SetText("Switch to Guild Window")
    guildBtn:SetScript("OnClick", function()
        -- Hide calendar windows
        if IGWCalendarUI and IGWCalendarUI.Hide then
            IGWCalendarUI:Hide()
        end
        -- Open main IGW window via global entry point
        if IGW_ToggleWindow then
            IGW_ToggleWindow()
        end
    end)

    -- Help text
    local helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    helpText:SetText("|cFFFFFF00Click to select  •  Delete removes event  •  Sync gets updates|r")
end

------------------------------------------------------------
-- Month View Calendar Window
------------------------------------------------------------
local monthViewFrame
local currentViewMonth
local currentViewYear
local dayFrames = {}

local function refreshMonthView()
    if not monthViewFrame or not monthViewFrame:IsVisible() then return end
    
    local monthNames = {"January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December"}
    monthViewFrame.monthHeader:SetText(monthNames[currentViewMonth] .. " " .. currentViewYear)
    
    -- Get first day of month and days in month
    local firstDay = tonumber(date("%w", time({year=currentViewYear, month=currentViewMonth, day=1})))
    local daysInMonth = tonumber(date("%d", time({year=currentViewYear, month=currentViewMonth+1, day=0})))
    
    -- Get all events for this month
    local monthEvents = {}
    for id, e in pairs(IGWCalendarDB.events) do
        if e.start_ts then
            local dt = date("*t", e.start_ts)
            if dt and dt.year == currentViewYear and dt.month == currentViewMonth then
                local day = dt.day
                if not monthEvents[day] then
                    monthEvents[day] = {}
                end
                table.insert(monthEvents[day], e)
            end
        end
    end
    
    -- Sort events by time for each day
    for day, events in pairs(monthEvents) do
        table.sort(events, function(a, b) return (a.start_ts or 0) < (b.start_ts or 0) end)
    end
    
    -- Clear all day frames and hide them
    for i = 1, 42 do
        dayFrames[i].dayNum:SetText("")
        dayFrames[i].eventText:SetText("")
        dayFrames[i]:SetBackdropColor(0.1, 0.1, 0.15, 0.7)
        dayFrames[i]:Hide()
    end
    
    -- Fill in days — only these frames get shown
    for day = 1, daysInMonth do
        local frameIndex = firstDay + day
        if frameIndex <= 42 then
            local dayFrame = dayFrames[frameIndex]
            dayFrame:Show()
            dayFrame.dayNum:SetText(tostring(day))
            
            -- Show color-coded dots (up to 3, earliest events first)
            local events = monthEvents[day]
            if events and table.getn(events) > 0 then
                dayFrame:SetBackdropColor(0.2, 0.2, 0.3, 0.9)
                local typeColors = {
                    ["Raid"] = "|cFFFF0000",
                    ["Dungeon"] = "|cFF00FF00",
                    ["PvP"] = "|cFFFF8800",
                    ["Guild Event"] = "|cFF00FFFF",
                    ["Meeting"] = "|cFFFFFF00",
                    ["Social"] = "|cFFFF00FF",
                    ["Other"] = "|cFFFFFFFF"
                }
                local dots = ""
                local limit = math.min(table.getn(events), 3)
                for i = 1, limit do
                    local color = typeColors[events[i].event_type] or "|cFFFFFFFF"
                    dots = dots .. color .. "•|r"
                end
                dayFrame.eventText:SetText(dots)
            end
        end
    end
end

local function createMonthView()
    if monthViewFrame then return end
    
    monthViewFrame = CreateFrame("Frame", "IGWMonthViewFrame", UIParent)
    monthViewFrame:SetWidth(300)
    monthViewFrame:SetHeight(294)
    monthViewFrame:SetPoint("TOPRIGHT", frame, "TOPLEFT", -10, 0)
    monthViewFrame:SetFrameStrata("DIALOG")
    monthViewFrame:SetMovable(true)
    monthViewFrame:EnableMouse(true)
    monthViewFrame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    monthViewFrame:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Background texture matching main window theme
    local mvBgTexture = monthViewFrame:CreateTexture(nil, "BACKGROUND")
    mvBgTexture:SetPoint("TOPLEFT", monthViewFrame, "TOPLEFT", 11, -12)
    mvBgTexture:SetPoint("BOTTOMRIGHT", monthViewFrame, "BOTTOMRIGHT", -12, 11)
    local bgColor = {r = 0.15, g = 0.15, b = 0.15}
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
        bgColor = ImprovedGuildWindowDB.bgColor
    end
    local opacity = 0.95
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.opacity then
        opacity = ImprovedGuildWindowDB.opacity
    end
    mvBgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, opacity)
    monthViewFrame.bgTexture = mvBgTexture
    
    -- Register with ESC key handler
    table.insert(UISpecialFrames, "IGWMonthViewFrame")
    
    -- Title bar for dragging (matches main calendar window)
    local titleBar = CreateFrame("Frame", nil, monthViewFrame)
    titleBar:SetPoint("TOP", monthViewFrame, "TOP", 0, 0)
    titleBar:SetWidth(monthViewFrame:GetWidth() - 40)
    titleBar:SetHeight(24)
    titleBar:SetFrameLevel(monthViewFrame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() monthViewFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() monthViewFrame:StopMovingOrSizing() end)

    -- Month/Year header (fixed width, centered — so nav buttons stay put regardless of month name)
    local monthHeader = monthViewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    monthHeader:SetPoint("TOP", monthViewFrame, "TOP", 0, -20)
    monthHeader:SetWidth(152)
    monthHeader:SetJustifyH("CENTER")
    monthViewFrame.monthHeader = monthHeader
    
    -- Previous month button (fixed position, symmetric with next)
    local prevBtn = CreateFrame("Button", nil, monthViewFrame)
    prevBtn:SetPoint("TOPLEFT", monthViewFrame, "TOPLEFT", 50, -14)
    prevBtn:SetWidth(24)
    prevBtn:SetHeight(24)
    prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    prevBtn:SetScript("OnClick", function()
        currentViewMonth = currentViewMonth - 1
        if currentViewMonth < 1 then
            currentViewMonth = 12
            currentViewYear = currentViewYear - 1
        end
        refreshMonthView()
    end)
    
    -- Next month button (fixed position, symmetric with prev)
    local nextBtn = CreateFrame("Button", nil, monthViewFrame)
    nextBtn:SetPoint("TOPRIGHT", monthViewFrame, "TOPRIGHT", -50, -14)
    nextBtn:SetWidth(24)
    nextBtn:SetHeight(24)
    nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    nextBtn:SetScript("OnClick", function()
        currentViewMonth = currentViewMonth + 1
        if currentViewMonth > 12 then
            currentViewMonth = 1
            currentViewYear = currentViewYear + 1
        end
        refreshMonthView()
    end)
    
    -- Day headers (S M T W T F S)
    local dayNames = {"S", "M", "T", "W", "T", "F", "S"}
    local dayHeaderY = -42
    for i = 1, 7 do
        local dayHeader = monthViewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dayHeader:SetPoint("TOPLEFT", monthViewFrame, "TOPLEFT", 20 + (i-1) * 38, dayHeaderY)
        dayHeader:SetWidth(34)
        dayHeader:SetJustifyH("CENTER")
        dayHeader:SetText(dayNames[i])
    end
    
    -- Day grid (7 cols x 6 rows)
    local startY = -58
    for row = 0, 5 do
        for col = 0, 6 do
            local index = row * 7 + col + 1
            local dayFrame = CreateFrame("Frame", nil, monthViewFrame)
            dayFrame:SetPoint("TOPLEFT", monthViewFrame, "TOPLEFT", 20 + col * 38, startY - row * 38)
            dayFrame:SetWidth(34)
            dayFrame:SetHeight(34)
            dayFrame:SetBackdrop({
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            dayFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.7)
            dayFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            
            -- Day number
            local dayNum = dayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            dayNum:SetPoint("TOPLEFT", dayFrame, "TOPLEFT", 3, -3)
            dayFrame.dayNum = dayNum
            
            -- Event indicators (small dots)
            local eventText = dayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            eventText:SetPoint("BOTTOM", dayFrame, "BOTTOM", 0, 4)
            eventText:SetWidth(27)
            eventText:SetJustifyH("CENTER")
            dayFrame.eventText = eventText
            
            dayFrames[index] = dayFrame
        end
    end
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, monthViewFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", monthViewFrame, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function()
        monthViewFrame:Hide()
    end)
    
    monthViewFrame:Hide()
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function UI:Toggle()
    if not frame then
        self:CreateWindow()
    end
    
    if frame:IsVisible() then
        frame:Hide()
        if monthViewFrame then
            monthViewFrame:Hide()
        end
    else
        -- Initialize and show month view if needed
        if not monthViewFrame then
            local today = date("*t")
            currentViewMonth = today.month
            currentViewYear = today.year
            createMonthView()
        end
        
        applyTheme()
        frame:Show()
        refreshList()
        
        if monthViewFrame then
            monthViewFrame:Show()
            refreshMonthView()
        end
    end
end

function UI:Show()
    if not frame then
        self:CreateWindow()
    end
    
    -- Initialize and show month view
    if not monthViewFrame then
        local today = date("*t")
        currentViewMonth = today.month
        currentViewYear = today.year
        createMonthView()
    end
    
    applyTheme()
    frame:Show()
    refreshList()
    
    if monthViewFrame then
        monthViewFrame:Show()
        refreshMonthView()
    end
end

function UI:Hide()
    if frame then
        frame:Hide()
    end
    if monthViewFrame then
        monthViewFrame:Hide()
    end
end

function UI:Refresh()
    refreshList()
    if monthViewFrame then
        refreshMonthView()
    end
end

function UI:ApplyTheme(r, g, b, opacity)
    if frame and frame.bgTexture then
        frame.bgTexture:SetTexture(r, g, b, opacity)
    end
    if monthViewFrame and monthViewFrame.bgTexture then
        monthViewFrame.bgTexture:SetTexture(r, g, b, opacity)
    end
end
