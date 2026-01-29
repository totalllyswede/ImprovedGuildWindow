-- Improved Guild Window for WoW 1.12.1 / Turtle WoW
-- Author: Travis

local IGW = {}
IGW.VERSION = "2.0"
local frame
local rosterData = {}
local displayedMembers = {}
local sortColumn = "name"
local sortAscending = true
local filterText = ""
local filterRank = -1
local showOffline = true
local currentTab = "details"

-- Configuration: Officer rank threshold
-- rankIndex: 0=Guild Master, 1-9=other ranks
-- Members with rankIndex <= this value are considered "officers"
-- Default: 2 (includes Guild Master and top 2 officer ranks)
local OFFICER_RANK_THRESHOLD = 2



-- Fixed background opacity (v1.2)
local IGW_BG_OPACITY = 0.95

-- Layout constants
local FILTER_ROW_TOP_Y        = -50   -- where the first filter row starts
local FILTER_ROW_HEIGHT       = 30    -- height of a single filter row
local FILTER_ROW_GAP          = 5     -- spacing between filter rows
local FILTER_ROWS             = 2     -- number of filter rows (second row reserved for future options)
local FILTER_EXTRA_SPACING    = 0     -- extra space under filter rows (reserved for future options)
local HEADER_BASE_OFFSET_Y    = 10    -- gap between filters and column headers

-- Row heights
local ROW_HEIGHT_DEFAULT = 20
local ROW_HEIGHT_DETAILS = 25  -- +5px only on Member Details tab

-- Visible rows
local VISIBLE_ROWS_GUILD = 13    -- Guild Members tab (show 1 fewer row)
local VISIBLE_ROWS_DETAILS = 11  -- Member Details tab



local function IGW_GetHeaderTopY()
    return FILTER_ROW_TOP_Y
        - (FILTER_ROW_HEIGHT * FILTER_ROWS)
        - (FILTER_ROW_GAP * (FILTER_ROWS - 1))
        - FILTER_EXTRA_SPACING
        - HEADER_BASE_OFFSET_Y
end

-- Keybinding strings (shown in ESC > Key Bindings)
BINDING_HEADER_IMPROVEDGUILDWINDOW = "Improved Guild Window"
BINDING_NAME_IMPROVEDGUILDWINDOW_TOGGLE = "Toggle Window"


-- ESC-close support (WoW closes frames listed in UISpecialFrames before opening the game menu)
local function IGW_AddToSpecialFrames(frameName, toFront)
    if not frameName or frameName == "" then return end
    if not UISpecialFrames then UISpecialFrames = {} end

    -- remove duplicates
    for i = table.getn(UISpecialFrames), 1, -1 do
        if UISpecialFrames[i] == frameName then
            table.remove(UISpecialFrames, i)
        end
    end

    if toFront then
        table.insert(UISpecialFrames, 1, frameName)
    else
        table.insert(UISpecialFrames, frameName)
    end
end

-- Class color lookup
local CLASS_COLORS = {
    ["Warrior"] = {r=0.78, g=0.61, b=0.43},
    ["Paladin"] = {r=0.96, g=0.55, b=0.73},
    ["Hunter"] = {r=0.67, g=0.83, b=0.45},
    ["Rogue"] = {r=1.0, g=0.96, b=0.41},
    ["Priest"] = {r=1.0, g=1.0, b=1.0},
    ["Shaman"] = {r=0.0, g=0.44, b=0.87},
    ["Mage"] = {r=0.41, g=0.8, b=0.94},
    ["Warlock"] = {r=0.58, g=0.51, b=0.79},
    ["Druid"] = {r=1.0, g=0.49, b=0.04}
}

-- Initialize saved variables
function IGW:OnLoad()
    -- Note: At this point, SavedVariables are NOT yet loaded
    -- We'll initialize them in OnPlayerLogin when they're available
    self:RegisterEvents()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Improved Guild Window loaded!|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Set keybind in ESC > Key Bindings > Improved Guild Window|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Or use /igw to open|r")
end

-- Initialize SavedVariables and create frame (called after PLAYER_LOGIN when SavedVariables are loaded)
function IGW:InitializeSavedVariables()
    if not ImprovedGuildWindowDB then
        ImprovedGuildWindowDB = {
            position = {},
            width = 650,
            height = 500,
            sortColumn = "name",
            sortAscending = true,
            showOffline = true,
            opacity = 1.0,
            bgColor = {r = 0.15, g = 0.15, b = 0.15}  -- Default dark grey
        }
    end
    
    -- Ensure bgColor exists (for existing saved variables)
    if not ImprovedGuildWindowDB.bgColor then
        ImprovedGuildWindowDB.bgColor = {r = 0.15, g = 0.15, b = 0.15}
    end
    
    -- Load saved opacity or use default
    IGW_BG_OPACITY = ImprovedGuildWindowDB.opacity or 0.95

    sortColumn = ImprovedGuildWindowDB.sortColumn or "name"
    sortAscending = ImprovedGuildWindowDB.sortAscending
    if sortAscending == nil then sortAscending = true end
    showOffline = ImprovedGuildWindowDB.showOffline
    if showOffline == nil then showOffline = true end
    
    -- NOW create the main frame with SavedVariables loaded
    self:CreateMainFrame()
end

-- Create the main window frame
function IGW:CreateMainFrame()
    -- Ensure DB exists (should have been initialized by now)
    if not ImprovedGuildWindowDB then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000ERROR: ImprovedGuildWindowDB not initialized!|r")
        return
    end
    
    -- Don't create if already exists
    if frame then
        return
    end
    
    -- Main frame
    frame = CreateFrame("Frame", "ImprovedGuildWindowFrame", UIParent)
    IGW_AddToSpecialFrames("ImprovedGuildWindowFrame", false)
    frame:SetWidth(ImprovedGuildWindowDB.width or 650)
    frame:SetHeight(ImprovedGuildWindowDB.height or 500)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Background (border only, solid texture added separately)
    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Create solid background texture (inside the border)
    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
    bgTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
    -- Use saved color or default to dark grey
    local bgColor = {r = 0.15, g = 0.15, b = 0.15}
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
        bgColor = ImprovedGuildWindowDB.bgColor
    end
    bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
    frame.bgTexture = bgTexture
    
    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    titleBar:SetHeight(30)
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        IGW:SavePosition()
    end)
    
    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    title:SetText(GetGuildInfo("player") or "Guild Window")
    frame.titleText = title
    
    -- Close button (with 5px padding)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        -- Close details window when main window closes
        if IGW.detailsFrame then
            IGW.detailsFrame:Hide()
        end
        if IGW.infoFrame then
            IGW.infoFrame:Hide()
            -- Un-highlight Guild Info button
            frame.tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
            frame.tab3Text:SetTextColor(0.7, 0.7, 0.7)
        end
        -- Close options window
        if IGW.optionsFrame then
            IGW.optionsFrame:Hide()
        end
    end)
    
    -- Options button (standard button, anchored to left of close button)
    local optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)  -- 2px gap from close button
    optionsBtn:SetWidth(65)
    optionsBtn:SetHeight(20)
    optionsBtn:SetText("Options")
    optionsBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    
    optionsBtn:SetScript("OnClick", function()
        IGW:ToggleOptionsWindow()
    end)
    -- Filter section
    self:CreateFilterSection()
    
    -- Column headers
    self:CreateColumnHeaders()
    
    -- Scroll frame for roster
    self:CreateRosterScrollFrame()
    
    -- Tabs
    self:CreateTabs()
    
    -- Member count - position above tabs, below roster
    local memberCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memberCount:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 45)
    memberCount:SetText("0 Online | 0 Total")
    frame.memberCount = memberCount
    
    -- Restore saved position or set default
    if ImprovedGuildWindowDB.position and ImprovedGuildWindowDB.position.point then
        frame:SetPoint(
            ImprovedGuildWindowDB.position.point,
            UIParent,
            ImprovedGuildWindowDB.position.point,
            ImprovedGuildWindowDB.position.x or 0,
            ImprovedGuildWindowDB.position.y or 0
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Initialize with Guild Members tab (details)
    self:UpdateColumnHeaders("details")
end

-- Create filter section
function IGW:CreateFilterSection()
    local filterFrame = CreateFrame("Frame", nil, frame)
filterFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, FILTER_ROW_TOP_Y)
filterFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, FILTER_ROW_TOP_Y)
filterFrame:SetHeight(FILTER_ROW_HEIGHT)

-- Second filter row frame (Advanced Search row)
local filterFrame2 = CreateFrame("Frame", nil, frame)
filterFrame2:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -FILTER_ROW_GAP)
filterFrame2:SetPoint("TOPRIGHT", filterFrame, "BOTTOMRIGHT", 0, -FILTER_ROW_GAP)
filterFrame2:SetHeight(FILTER_ROW_HEIGHT)
-- Frame always visible, search boxes toggle
frame.filterFrame2 = filterFrame2

-- Advanced Search toggle button (on filterFrame2, left side)
local advSearchBtn = CreateFrame("Button", nil, filterFrame2, "UIPanelButtonTemplate")
advSearchBtn:SetPoint("LEFT", filterFrame2, "LEFT", 0, 0)
advSearchBtn:SetWidth(120)
advSearchBtn:SetHeight(22)
advSearchBtn:SetText("Advanced Search")
advSearchBtn:SetScript("OnClick", function()
    if frame.advSearchName:IsVisible() then
        frame.advSearchName:Hide()
        frame.advSearchNote:Hide()
        frame.advSearchOfficerNote:Hide()
        frame.advSearchNameLabel:Hide()
        frame.advSearchNoteLabel:Hide()
        frame.advSearchOfficerNoteLabel:Hide()
    else
        frame.advSearchName:Show()
        frame.advSearchNote:Show()
        frame.advSearchOfficerNote:Show()
        frame.advSearchNameLabel:Show()
        frame.advSearchNoteLabel:Show()
        frame.advSearchOfficerNoteLabel:Show()
    end
end)
frame.advSearchBtn = advSearchBtn

-- Advanced Search filters (name, note, officer note)
local filterWidth = 100
local filterGap = 15

-- Helper function to create search box
local function CreateAdvancedSearchBox(parent, label, xOffset, filterKey)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    labelText:SetText(label .. ":")
    labelText:Hide() -- Hidden by default
    
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
    editBox:SetWidth(filterWidth)
    editBox:SetHeight(22)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    editBox:SetBackdropColor(0, 0, 0, 0.8)
    editBox:SetTextInsets(6, 6, 0, 0)  -- Add left/right padding for text
    editBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if type(text) == "string" then
            frame.advancedFilters[filterKey] = string.lower(text)
        else
            frame.advancedFilters[filterKey] = ""
        end
        IGW:UpdateRosterDisplay()
    end)
    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    editBox:Hide() -- Hidden by default
    
    return editBox, labelText
end

-- Initialize advanced filters table
frame.advancedFilters = {
    name = "",
    note = "",
    officernote = ""
}

-- Create search boxes
local xPos = 130 -- Start after button
local nameBox, nameLabel = CreateAdvancedSearchBox(filterFrame2, "Name", xPos, "name")
frame.advSearchName = nameBox
frame.advSearchNameLabel = nameLabel

xPos = xPos + 40 + filterWidth + filterGap

local noteBox, noteLabel = CreateAdvancedSearchBox(filterFrame2, "Note", xPos, "note")
frame.advSearchNote = noteBox
frame.advSearchNoteLabel = noteLabel

xPos = xPos + 35 + filterWidth + filterGap

local officerNoteBox, officerNoteLabel = CreateAdvancedSearchBox(filterFrame2, "Officer Note", xPos, "officernote")
frame.advSearchOfficerNote = officerNoteBox
frame.advSearchOfficerNoteLabel = officerNoteLabel

    
    -- Search label
    local searchLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    searchLabel:SetText("Search:")
    
    -- Search editbox
    local searchBox = CreateFrame("EditBox", nil, filterFrame)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
    searchBox:SetWidth(150)
    searchBox:SetHeight(22)
    searchBox:SetFontObject(GameFontNormal)
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    searchBox:SetBackdropColor(0, 0, 0, 0.8)
    searchBox:SetTextInsets(6, 6, 0, 0)  -- Add left/right padding for text
    searchBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if type(text) == "string" then
            filterText = string.lower(text)
        else
            filterText = ""
        end
        IGW:UpdateRosterDisplay()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    frame.searchBox = searchBox
    
    -- Rank filter label
    local rankLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("LEFT", searchBox, "RIGHT", 20, 0)
    rankLabel:SetText("Rank:")
    
    -- Rank dropdown
    local rankDropdown = CreateFrame("Button", "IGW_RankDropdown", filterFrame, "UIDropDownMenuTemplate")
    rankDropdown:SetPoint("LEFT", rankLabel, "RIGHT", -15, -2)
    UIDropDownMenu_SetWidth(100, rankDropdown)
    UIDropDownMenu_SetText("All Ranks", rankDropdown)
    
    UIDropDownMenu_Initialize(rankDropdown, function()
        local info = {}
        info.text = "All Ranks"
        info.value = -1
        info.func = function()
            filterRank = -1
            UIDropDownMenu_SetText("All Ranks", rankDropdown)
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Add guild ranks
        -- GuildControlGetRankName uses 1-based (1=GM, 2=next, etc)
        -- GetGuildRosterInfo returns 0-based rankIndex (0=GM, 1=next, etc)
        -- So we need to store value as i-1 to match GetGuildRosterInfo
        for i = 1, GuildControlGetNumRanks() do
            local rankName = GuildControlGetRankName(i)
            local rankValue = i - 1  -- Convert to 0-based for matching
            info = {}
            info.text = rankName
            info.value = rankValue
            info.func = function()
                filterRank = rankValue
                UIDropDownMenu_SetText(rankName, rankDropdown)
                IGW:UpdateRosterDisplay()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("RIGHT", filterFrame, "RIGHT", -110, 0)
    refreshBtn:SetWidth(100)
    refreshBtn:SetHeight(22)
    refreshBtn:SetText("Clear / Refresh")
    refreshBtn:SetScript("OnClick", function()
        -- Clear legacy search box
        if frame.searchBox then
            frame.searchBox:SetText("")
        end
        filterText = ""
        
        -- Clear advanced search boxes
        if frame.advSearchName then
            frame.advSearchName:SetText("")
        end
        if frame.advSearchNote then
            frame.advSearchNote:SetText("")
        end
        if frame.advSearchOfficerNote then
            frame.advSearchOfficerNote:SetText("")
        end
        if frame.advancedFilters then
            frame.advancedFilters.name = ""
            frame.advancedFilters.note = ""
            frame.advancedFilters.officernote = ""
        end
        
        -- Reset rank filter to "All Ranks"
        filterRank = -1
        if rankDropdown then
            UIDropDownMenu_SetText("All Ranks", rankDropdown)
        end
        
        -- Refresh guild roster
        GuildRoster()
        IGW:UpdateRosterDisplay()
    end)
    
    -- Show Offline checkbox
    local offlineCheck = CreateFrame("CheckButton", "IGW_OfflineCheck", filterFrame, "UICheckButtonTemplate")
    offlineCheck:SetPoint("RIGHT", filterFrame, "RIGHT", -10, 0)
    offlineCheck:SetWidth(24)
    offlineCheck:SetHeight(24)
    offlineCheck:SetChecked(showOffline)
    
    local offlineLabel = offlineCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offlineLabel:SetPoint("RIGHT", offlineCheck, "LEFT", 0, 0)
    offlineLabel:SetText("Show Offline")
    
    offlineCheck:SetScript("OnClick", function()
        showOffline = this:GetChecked() == 1
        if ImprovedGuildWindowDB then
            ImprovedGuildWindowDB.showOffline = showOffline
        end
        IGW:UpdateRosterDisplay()
    end)
    
    frame.offlineCheck = offlineCheck
end

-- Create column headers
function IGW:CreateColumnHeaders()
    local headerFrame = CreateFrame("Frame", nil, frame)
    local headerTopY = IGW_GetHeaderTopY()
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, headerTopY)
    headerFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, headerTopY)
local headerTopY = IGW_GetHeaderTopY()
headerFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -90)
    headerFrame:SetHeight(20)
    
    frame.headerFrame = headerFrame
    frame.headerButtons = {}
    
    -- Initial headers will be set by UpdateColumnHeaders
end

-- Create roster scroll frame
function IGW:CreateRosterScrollFrame()
    -- Create scroll frame with FauxScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "IGW_RosterScroll", frame, "FauxScrollFrameTemplate")
    local headerTopY = IGW_GetHeaderTopY()
-- Scroll starts below the header row (20px header + ~5px breathing room)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, headerTopY - 25)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 50)
    scrollFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Set up scroll behavior
    scrollFrame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(15, function() IGW:UpdateRosterDisplay() end)
    end)
    
    -- Create row frames as children of main frame
    local rows = {}
    for i = 1, 15 do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(590)
        row:SetHeight(ROW_HEIGHT_DEFAULT)
        row:SetFrameLevel(frame:GetFrameLevel() + 2)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        
        -- Position relative to main frame, accounting for scroll frame position
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, (headerTopY - 30) - (i-1) * ROW_HEIGHT_DEFAULT)
        
        -- Name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("LEFT", row, "LEFT", 5, 0)
        name:SetWidth(105)
        name:SetJustifyH("LEFT")
        row.name = name
        
        -- Level
        local level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        level:SetPoint("LEFT", row, "LEFT", 115, 0)
        level:SetWidth(35)
        level:SetJustifyH("CENTER")
        row.level = level
        
        -- Class (reuse for rank in roster view)
        local class = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        class:SetPoint("LEFT", row, "LEFT", 155, 0)
        class:SetWidth(85)
        class:SetJustifyH("LEFT")
        row.class = class
        
        -- Rank (reuse for note in roster view)
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rank:SetPoint("LEFT", row, "LEFT", 245, 0)
        rank:SetWidth(105)
        rank:SetJustifyH("LEFT")
        row.rank = rank
        
        -- Note (reuse for officer note in roster view)
        local note = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        note:SetPoint("LEFT", row, "LEFT", 355, 0)
        note:SetWidth(105)
        note:SetJustifyH("LEFT")
        row.note = note
        
        -- Officer Note (reuse for last online in roster view)
        local officerNote = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        officerNote:SetPoint("LEFT", row, "LEFT", 465, 0)
        officerNote:SetWidth(75)
        officerNote:SetJustifyH("LEFT")
        row.officerNote = officerNote
        
        -- Click to show member details
        row:SetScript("OnClick", function()
            if row.memberIndex then
                IGW:ShowMemberDetails(row.memberIndex)
            end
        end)
        
        table.insert(rows, row)
    end
    
    frame.rosterRows = rows
    frame.rosterScroll = scrollFrame
end

-- Create tabs at bottom of window
function IGW:CreateTabs()
    local tabHeight = 25
    
    -- Main tabs (Guild Members and Member Details) - centered
    local tabWidth = 120
    local tabGap = 10
    
    -- Calculate center position for main tabs only (tab1 and tab2)
    local totalMainTabWidth = (tabWidth * 2) + tabGap
    local startX = -(totalMainTabWidth / 2) + (tabWidth / 2)
    
    -- Tab 1: Guild Members
    local tab1 = CreateFrame("Button", nil, frame)
    tab1:SetPoint("BOTTOM", frame, "BOTTOM", startX, 15)
    tab1:SetWidth(tabWidth)
    tab1:SetHeight(tabHeight)
    tab1:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for tab
    tab1:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab1:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab1:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local tab1Text = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab1Text:SetPoint("CENTER", tab1, "CENTER", 0, 0)
    tab1Text:SetText("Guild Members")
    
    tab1:SetScript("OnClick", function()
        IGW:SwitchTab("details")
    end)
    
    -- Tab 2: Member Details
    local tab2 = CreateFrame("Button", nil, frame)
    tab2:SetPoint("LEFT", tab1, "RIGHT", tabGap, 0)
    tab2:SetWidth(tabWidth)
    tab2:SetHeight(tabHeight)
    tab2:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for tab
    tab2:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab2:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab2:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local tab2Text = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab2Text:SetPoint("CENTER", tab2, "CENTER", 0, 0)
    tab2Text:SetText("Member Details")
    
    tab2:SetScript("OnClick", function()
        IGW:SwitchTab("roster")
    end)
    
    -- Tab 3: Guild Info (far left of window)
    local tab3 = CreateFrame("Button", nil, frame)
    tab3:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
    tab3:SetWidth(tabWidth)
    tab3:SetHeight(tabHeight)
    tab3:SetFrameLevel(frame:GetFrameLevel() + 1)

    tab3:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab3:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local tab3Text = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab3Text:SetPoint("CENTER", tab3, "CENTER", 0, 0)
    tab3Text:SetText("|cFFFF0000<|r Guild Info")  -- Red left arrow before text
    tab3Text:SetTextColor(0.7, 0.7, 0.7)

    tab3:SetScript("OnClick", function()
        IGW:ToggleGuildInfoWindow()
    end)

    frame.tab1 = tab1
    frame.tab2 = tab2
    frame.tab1Text = tab1Text
    frame.tab2Text = tab2Text
    frame.tab3 = tab3
    frame.tab3Text = tab3Text
end

-- Switch between tabs
function IGW:SwitchTab(tabName)
    currentTab = tabName
    
    if tabName == "details" then
        -- Activate Guild Members tab (tab1)
        frame.tab1:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab2:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab1Text:SetTextColor(1, 1, 1)
        frame.tab2Text:SetTextColor(0.7, 0.7, 0.7)
        
        -- Set default sorting
        sortColumn = "rank"
        sortAscending = false  -- Descending
        
        -- Hide offline by default
        showOffline = false
        if frame.offlineCheck then
            frame.offlineCheck:SetChecked(false)
        end
        
        -- Show details columns
        IGW:UpdateColumnHeaders("details")
    else
        -- Activate Member Details tab (tab2)
        frame.tab1:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab2:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab1Text:SetTextColor(0.7, 0.7, 0.7)
        frame.tab2Text:SetTextColor(1, 1, 1)
        
        -- Set default sorting
        sortColumn = "rank"
        sortAscending = false  -- Descending
        
        -- Show offline on this tab
        showOffline = true
        if frame.offlineCheck then
            frame.offlineCheck:SetChecked(true)
        end
        
        -- Show roster columns
        IGW:UpdateColumnHeaders("roster")
    end
    
    IGW:UpdateRosterDisplay()
end

-- Update column headers based on tab
function IGW:UpdateColumnHeaders(tabName)
    -- Hide all existing header buttons
    if frame.headerButtons then
        for _, btn in ipairs(frame.headerButtons) do
            btn:Hide()
        end
    end
    
    frame.headerButtons = {}
    
    local headers
    if tabName == "roster" then
headers = {
    {text = "Name",         width = 95,  column = "name"},
    {text = "Level",        width = 55,  column = "level"},
    {text = "Rank",         width = 80,  column = "rank"},
    {text = "Note",         width = 140, column = "note"},        -- narrowed
    {text = "Officer Note", width = 140, column = "officernote"}, -- narrowed
    {text = "Last Online",  width = 80,  column = "lastonline"}
}
    else
        headers = {
            {text = "Name", width = 110, column = "name"},
            {text = "Level", width = 60, column = "level"},
            {text = "Class", width = 75, column = "class"},
            {text = "Location", width = 190, column = "zone"},
            {text = "Rank", width = 135, column = "rank"}
        }
    end
    
    local headerFrame = frame.headerFrame
    local xPos = 0
    for _, header in ipairs(headers) do
        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetPoint("LEFT", headerFrame, "LEFT", xPos, 0)
        btn:SetWidth(header.width)
        btn:SetHeight(20)
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -15, 0)
        text:SetJustifyH("LEFT")
        text:SetText(header.text)
        
        -- Sort arrow
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        arrow:SetJustifyH("RIGHT")
        arrow:SetText("")
        btn.arrow = arrow
        btn.column = header.column
        
        btn:SetScript("OnClick", function()
            IGW:SortRoster(this.column)
        end)
        
        -- Highlight on hover
        btn:SetScript("OnEnter", function()
            text:SetTextColor(1, 1, 0)
        end)
        btn:SetScript("OnLeave", function()
            text:SetTextColor(1, 1, 1)
        end)
        
        if header.column == sortColumn then
            arrow:SetText(sortAscending and "^" or "v")
        end
        
        btn:Show()
        xPos = xPos + header.width
        
        table.insert(frame.headerButtons, btn)
    end

    -- Keep row columns aligned with header columns
    self:ApplyRowLayout(tabName, headers)
end

-- Apply header-aligned column positions and widths to roster rows (keeps headers + data perfectly lined up)
function IGW:ApplyRowLayout(tabName, headers)
    if not frame or not frame.rosterRows or not headers then return end

    -- Build x positions for each header column
    local xPos = 0
    local colX = {}
    local colW = {}
    for _, h in ipairs(headers) do
        colX[h.column] = xPos
        colW[h.column] = h.width
        xPos = xPos + h.width
    end

    for _, row in ipairs(frame.rosterRows) do
        -- Ensure everything is left-justified for a clean grid
        row.name:SetJustifyH("LEFT")
        row.level:SetJustifyH("LEFT")
        row.class:SetJustifyH("LEFT")
        row.rank:SetJustifyH("LEFT")
        row.note:SetJustifyH("LEFT")
        row.officerNote:SetJustifyH("LEFT")

        if tabName == "roster" then
            -- Member Details tab uses: name, level, (rank -> row.class), (note -> row.rank),
            -- (officer note -> row.note), (last online -> row.officerNote)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", colX["name"] + 5, 0)
            row.name:SetWidth(colW["name"] - 10)

            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row, "LEFT", colX["level"] + 5, 0)
            row.level:SetWidth(colW["level"] - 10)

            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row, "LEFT", colX["rank"] + 5, 0)
            row.class:SetWidth(colW["rank"] - 10)

            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row, "LEFT", colX["note"] + 5, 0)
            row.rank:SetWidth(colW["note"] - 10)

            row.note:ClearAllPoints()
            row.note:SetPoint("LEFT", row, "LEFT", colX["officernote"] + 5, 0)
            row.note:SetWidth(colW["officernote"] - 10)

            row.officerNote:ClearAllPoints()
            row.officerNote:SetPoint("LEFT", row, "LEFT", colX["lastonline"] + 5, 0)
            row.officerNote:SetWidth(colW["lastonline"] - 10)
        else
            -- Guild Members tab uses: name, level, class, (location -> row.rank), (rank -> row.note)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", colX["name"] + 5, 0)
            row.name:SetWidth(colW["name"] - 10)

            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row, "LEFT", colX["level"] + 5, 0)
            row.level:SetWidth(colW["level"] - 10)

            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row, "LEFT", colX["class"] + 5, 0)
            row.class:SetWidth(colW["class"] - 10)

            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row, "LEFT", colX["zone"] + 5, 0)
            row.rank:SetWidth(colW["zone"] - 10)

            row.note:ClearAllPoints()
            row.note:SetPoint("LEFT", row, "LEFT", colX["rank"] + 5, 0)
            row.note:SetWidth(colW["rank"] - 10)

            -- Not used in this view
            row.officerNote:SetText("")
        end
    end
end

-- Show officer note edit dialog
function IGW:ShowOfficerNoteEdit(index, memberName)
    local dialog = StaticPopupDialogs["IGW_EDIT_OFFICER_NOTE"]
    if not dialog then
        StaticPopupDialogs["IGW_EDIT_OFFICER_NOTE"] = {
            text = "Edit Officer Note for %s",
            button1 = "Save",
            button2 = "Cancel",
            hasEditBox = 1,
            maxLetters = 31,
            OnAccept = function()
                local text = getglobal(this:GetParent():GetName().."EditBox"):GetText()
                GuildRosterSetOfficerNote(this:GetParent().data, text)
            end,
            OnShow = function()
                getglobal(this:GetName().."EditBox"):SetText(this.currentNote or "")
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        dialog = StaticPopupDialogs["IGW_EDIT_OFFICER_NOTE"]
    end
    
    local popup = StaticPopup_Show("IGW_EDIT_OFFICER_NOTE", memberName)
    if popup then
        popup.data = index
        popup.currentNote = rosterData[index].officernote or ""
    end
end

-- Show public note edit dialog
function IGW:ShowPublicNoteEdit(index, memberName)
    local dialog = StaticPopupDialogs["IGW_EDIT_PUBLIC_NOTE"]
    if not dialog then
        StaticPopupDialogs["IGW_EDIT_PUBLIC_NOTE"] = {
            text = "Edit Public Note for %s",
            button1 = "Save",
            button2 = "Cancel",
            hasEditBox = 1,
            maxLetters = 31,
            OnAccept = function()
                local text = getglobal(this:GetParent():GetName().."EditBox"):GetText()
                GuildRosterSetPublicNote(this:GetParent().data, text)
            end,
            OnShow = function()
                getglobal(this:GetName().."EditBox"):SetText(this.currentNote or "")
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        dialog = StaticPopupDialogs["IGW_EDIT_PUBLIC_NOTE"]
    end

    local popup = StaticPopup_Show("IGW_EDIT_PUBLIC_NOTE", memberName)
    if popup then
        popup.data = index
        popup.currentNote = rosterData[index].note or ""
    end
end

-- Show member details window
function IGW:ShowMemberDetails(index)
    local member = rosterData[index]
    if not member then return end
    
    -- Create details frame if it doesn't exist
    if not IGW.detailsFrame then
        local df = CreateFrame("Frame", "IGW_DetailsFrame", UIParent)
        IGW_AddToSpecialFrames("IGW_DetailsFrame", true)
        df:SetWidth(250)
        df:SetHeight(frame:GetHeight())
        df:SetFrameStrata("MEDIUM")
        df:SetFrameLevel(10)
        -- Only allow moving if setting is enabled
        df:SetMovable((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        df:EnableMouse(true)
        df:SetClampedToScreen(true)
        df:Hide()
        
        -- Background (border only, solid texture added separately)
        df:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        df:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local dfBgTexture = df:CreateTexture(nil, "BACKGROUND")
        dfBgTexture:SetPoint("TOPLEFT", df, "TOPLEFT", 11, -12)
        dfBgTexture:SetPoint("BOTTOMRIGHT", df, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        dfBgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        df.bgTexture = dfBgTexture
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, df)
        titleBar:SetPoint("TOPLEFT", df, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", df, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(df:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function()
            if df:IsMovable() then
                df:StartMoving()
            end
        end)
        titleBar:SetScript("OnDragStop", function()
            if df:IsMovable() then
                df:StopMovingOrSizing()
            end
        end)
        
        -- Title text
        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Member Details")
        df.title = title
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, df, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", df, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(df:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function()
            df:Hide()
        end)
        
        -- Content area
        local yOffset = -50
        local leftX = 20
        
        -- Name
        local nameLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        nameLabel:SetText("Name:")
        
        local nameValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameValue:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameValue:SetText("")
        df.nameValue = nameValue
        
        yOffset = yOffset - 25
        
        -- Level & Class
        local levelLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        levelLabel:SetText("Level:")
        
        local levelValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 10, 0)
        levelValue:SetText("")
        df.levelValue = levelValue
        
        local classValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        classValue:SetPoint("LEFT", levelValue, "RIGHT", 10, 0)
        classValue:SetText("")
        df.classValue = classValue
        
        yOffset = yOffset - 25
        
        -- Rank
        local rankLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        rankLabel:SetText("Rank:")
        
        local rankValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rankValue:SetPoint("LEFT", rankLabel, "RIGHT", 10, 0)
        rankValue:SetText("")
        df.rankValue = rankValue
        
        yOffset = yOffset - 25
        
        -- Zone
        local zoneLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        zoneLabel:SetText("Zone:")
        
        local zoneValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        zoneValue:SetPoint("LEFT", zoneLabel, "RIGHT", 10, 0)
        zoneValue:SetWidth(150)
        zoneValue:SetJustifyH("LEFT")
        zoneValue:SetText("")
        df.zoneValue = zoneValue
        
        yOffset = yOffset - 25
        
        -- Online status
        local onlineLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        onlineLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        onlineLabel:SetText("Status:")
        
        local onlineValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        onlineValue:SetPoint("LEFT", onlineLabel, "RIGHT", 10, 0)
        onlineValue:SetText("")
        df.onlineValue = onlineValue
        
        yOffset = yOffset - 30
        
        -- Divider 1 (after status info)
        local div1 = df:CreateTexture(nil, "ARTWORK")
        div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div1:SetPoint("TOP", df, "TOP", 36, yOffset)
        div1:SetWidth(300)
        div1:SetHeight(16)
        df.div1 = div1
        
        yOffset = yOffset - 16

-- Public Note
local noteLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
noteLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
noteLabel:SetText("Public Note:")
df.noteLabel = noteLabel

-- Make heading clickable
local noteLabelBtn = CreateFrame("Button", nil, df)
noteLabelBtn:SetPoint("TOPLEFT", noteLabel, "TOPLEFT", -2, 2)
noteLabelBtn:SetPoint("BOTTOMRIGHT", noteLabel, "BOTTOMRIGHT", 2, -2)
noteLabelBtn:SetFrameLevel(df:GetFrameLevel() + 1)
noteLabelBtn:SetScript("OnClick", function()
    if df.memberIndex and (not CanEditPublicNote or CanEditPublicNote()) then
        IGW:ShowPublicNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 18

local noteValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
noteValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
noteValue:SetWidth(210)
noteValue:SetJustifyH("LEFT")
noteValue:SetText("")
df.noteValue = noteValue

local noteValueBtn = CreateFrame("Button", nil, df)
noteValueBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX - 2, yOffset + 2)
noteValueBtn:SetWidth(214)
noteValueBtn:SetHeight(40)
noteValueBtn:SetFrameLevel(df:GetFrameLevel() + 1)
noteValueBtn:SetScript("OnClick", function()
    if df.memberIndex and (not CanEditPublicNote or CanEditPublicNote()) then
        IGW:ShowPublicNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 48

-- Officer Note (clickable label)
local officerNoteLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
officerNoteLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
officerNoteLabel:SetText("Officer Note:")
df.officerNoteLabel = officerNoteLabel

-- Make label clickable
local officerNoteLabelBtn = CreateFrame("Button", nil, df)
officerNoteLabelBtn:SetPoint("TOPLEFT", officerNoteLabel, "TOPLEFT", -2, 2)
officerNoteLabelBtn:SetPoint("BOTTOMRIGHT", officerNoteLabel, "BOTTOMRIGHT", 2, -2)
officerNoteLabelBtn:SetFrameLevel(df:GetFrameLevel() + 1)
officerNoteLabelBtn:SetScript("OnClick", function()
    if df.memberIndex and CanEditOfficerNote() then
        IGW:ShowOfficerNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 18

-- Officer Note Value (clickable)
local officerNoteValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
officerNoteValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
officerNoteValue:SetWidth(210)
officerNoteValue:SetJustifyH("LEFT")
officerNoteValue:SetText("")
df.officerNoteValue = officerNoteValue

local officerNoteValueBtn = CreateFrame("Button", nil, df)
officerNoteValueBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX - 2, yOffset + 2)
officerNoteValueBtn:SetWidth(214)
officerNoteValueBtn:SetHeight(40)
officerNoteValueBtn:SetFrameLevel(df:GetFrameLevel() + 1)
officerNoteValueBtn:SetScript("OnClick", function()
    if df.memberIndex and CanEditOfficerNote() then
        IGW:ShowOfficerNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 48

        -- Divider 2 (after officer notes)
        local div2 = df:CreateTexture(nil, "ARTWORK")
        div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div2:SetPoint("TOP", df, "TOP", 36, yOffset)
        div2:SetWidth(300)
        div2:SetHeight(16)
        df.div2 = div2
        
        yOffset = yOffset - 16

        -- Whisper + Invite buttons (even spacing)
local buttonYGap = 8
local buttonGap = 10
local whisperWidth = 80
local inviteWidth = 120
local buttonHeight = 22

local whisperBtn = CreateFrame("Button", nil, df, "UIPanelButtonTemplate")
whisperBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
whisperBtn:SetWidth(whisperWidth)
whisperBtn:SetHeight(buttonHeight)
whisperBtn:SetFrameLevel(df:GetFrameLevel() + 1)
whisperBtn:SetText("Whisper")
whisperBtn:SetScript("OnClick", function()
    if df.memberName then
        ChatFrame_OpenChat("/w " .. df.memberName .. " ", DEFAULT_CHAT_FRAME)
    end
end)
df.whisperBtn = whisperBtn

local inviteBtn = CreateFrame("Button", nil, df, "UIPanelButtonTemplate")
inviteBtn:SetPoint("LEFT", whisperBtn, "RIGHT", buttonGap, 0)
inviteBtn:SetWidth(inviteWidth)
inviteBtn:SetHeight(buttonHeight)
inviteBtn:SetFrameLevel(df:GetFrameLevel() + 1)
inviteBtn:SetText("Invite to Group")
inviteBtn:SetScript("OnClick", function()
    if df.memberName then
        InviteByName(df.memberName)
    end
end)
df.inviteBtn = inviteBtn

yOffset = yOffset - (buttonHeight + buttonYGap)

        -- Divider 3 (after buttons)
        local div3 = df:CreateTexture(nil, "ARTWORK")
        div3:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div3:SetPoint("TOP", df, "TOP", 36, yOffset)
        div3:SetWidth(300)
        div3:SetHeight(16)
        df.div3 = div3
        
        yOffset = yOffset - 16
        
        -- Alts section
        local altsLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        altsLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        altsLabel:SetText("Other Characters:")
        df.altsLabel = altsLabel
        
        yOffset = yOffset - 18
        
        local altsValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        altsValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        altsValue:SetWidth(210)
        altsValue:SetJustifyH("LEFT")
        altsValue:SetText("—")
        df.altsValue = altsValue

        IGW.detailsFrame = df
    end
    
    -- Populate with member data
    local df = IGW.detailsFrame
    df.memberIndex = index
    df.memberName = member.name
    
    -- Set values
    df.nameValue:SetText(member.name or "Unknown")
    df.levelValue:SetText(tostring(member.level or "?"))
    
    -- Class with color
    local color = CLASS_COLORS[member.class] or {r=1, g=1, b=1}
    df.classValue:SetTextColor(color.r, color.g, color.b)
    df.classValue:SetText(member.class or "")
    
    df.rankValue:SetText(member.rank or "")
    df.zoneValue:SetText(member.zone or "Unknown")
    
    -- Online status
    if member.online then
        df.onlineValue:SetTextColor(0, 1, 0)
        df.onlineValue:SetText("Online")
    else
        df.onlineValue:SetTextColor(0.5, 0.5, 0.5)
        df.onlineValue:SetText("Offline")
    end
    
    df.noteValue:SetText(member.note or "")
    
    -- Officer note (only if can view)
    if CanViewOfficerNote() then
        df.officerNoteLabel:Show()
        df.officerNoteValue:Show()
        df.officerNoteValue:SetText(member.officernote or "")
    else
        -- Hide officer note section when user can't view
        df.officerNoteLabel:Hide()
        df.officerNoteValue:Hide()
    end
    
    -- Find alts: bidirectional detection
    -- 1. Find characters with "alt of [current player]"
    -- 2. If current player is an alt, find the main and all other alts
    local alts = {}
    local searchName = string.lower(member.name or "")
    local mainCharacter = nil
    
    -- Helper function to check for exact name match with word boundaries
    local function hasExactNameMatch(note, name)
        if string.find(note, "^" .. name .. "[%s%p]") or  -- Start of string
           string.find(note, "[%s%p]" .. name .. "$") or  -- End of string
           string.find(note, "[%s%p]" .. name .. "[%s%p]") or  -- Middle
           note == name then  -- Exact match only
            return true
        end
        return false
    end
    
    -- Check if current character is an alt (has "alt of X" in their note)
    if member.note then
        local currentNote = string.lower(member.note)
        if string.find(currentNote, "alt") then
            -- Extract main character name from note
            for _, guildMember in ipairs(rosterData) do
                if guildMember.name ~= member.name then
                    local testName = string.lower(guildMember.name)
                    if hasExactNameMatch(currentNote, testName) then
                        mainCharacter = guildMember.name
                        break
                    end
                end
            end
        end
    end
    
    -- If we found a main character, search for all alts of that main
    if mainCharacter then
        local mainNameLower = string.lower(mainCharacter)
        
        -- Add the main character to the list
        table.insert(alts, mainCharacter)
        
        -- Find all other alts of this main
        for _, guildMember in ipairs(rosterData) do
            if guildMember.name ~= member.name and guildMember.note then
                local note = string.lower(guildMember.note)
                if string.find(note, "alt") and hasExactNameMatch(note, mainNameLower) then
                    table.insert(alts, guildMember.name)
                end
            end
        end
    else
        -- Current character is the main, find their alts
        for _, guildMember in ipairs(rosterData) do
            if guildMember.name ~= member.name and guildMember.note then
                local note = string.lower(guildMember.note)
                if string.find(note, "alt") and hasExactNameMatch(note, searchName) then
                    table.insert(alts, guildMember.name)
                end
            end
        end
    end
    
    -- Display alts
    if table.getn(alts) > 0 then
        df.altsLabel:Show()
        df.altsValue:Show()
        df.div3:Show()
        df.altsValue:SetText(table.concat(alts, ", "))
    else
        -- Hide alts section when no alts found
        df.altsLabel:Hide()
        df.altsValue:Hide()
        df.div3:Hide()
    end
    -- Position to the right of main window with 5px gap, same top alignment
    df:ClearAllPoints()
    df:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
    df:SetHeight(frame:GetHeight())

    df:Show()
end

-- Update opacity of windows
function IGW:UpdateOpacity()
    -- Background opacity is fixed in v1.2
    local opacity = IGW_BG_OPACITY

    if frame then
        frame:SetBackdropColor(0, 0, 0, opacity)
    end

    if IGW.detailsFrame then
        IGW.detailsFrame:SetBackdropColor(0, 0, 0, opacity)
    end
end

-- Save window position

function IGW:SavePosition()
    if not ImprovedGuildWindowDB then return end
    local point, _, _, x, y = frame:GetPoint()
    ImprovedGuildWindowDB.position = {
        point = point,
        x = x,
        y = y
    }
end

-- Register events
function IGW:RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "PLAYER_LOGIN" then
            IGW:OnPlayerLogin()
        elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
            IGW:UpdateGuildData()
        end
    end)
end

-- Handle player login
function IGW:OnPlayerLogin()
    -- Initialize SavedVariables and create main frame now that SavedVariables are loaded
    self:InitializeSavedVariables()
    
    if IsInGuild() then
        GuildRoster()
    end
end

-- Update guild data
function IGW:UpdateGuildData()
    rosterData = {}
    local numMembers = GetNumGuildMembers(true)
    
    -- Update window title with guild name
    if frame and frame.titleText then
        local guildName = GetGuildInfo("player")
        if guildName then
            frame.titleText:SetText(guildName)
        end
    end
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        
        -- Get last online time (years, months, days, hours)
        local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
        
        table.insert(rosterData, {
            name = name,
            rank = rank,
            rankIndex = rankIndex,
            level = level,
            class = class,
            zone = zone,
            note = note,
            officernote = officernote,
            online = online,
            status = status,
            yearsOffline = yearsOffline,
            monthsOffline = monthsOffline,
            daysOffline = daysOffline,
            hoursOffline = hoursOffline
        })
    end
    
    self:UpdateRosterDisplay()
    if IGW.infoFrame and IGW.infoFrame:IsVisible() then
        IGW:UpdateGuildInfoWindow()
    end
end

-- Sort roster
function IGW:SortRoster(column)
    if sortColumn == column then
        sortAscending = not sortAscending
    else
        sortColumn = column
        sortAscending = true
    end
    
    if ImprovedGuildWindowDB then
        ImprovedGuildWindowDB.sortColumn = sortColumn
        ImprovedGuildWindowDB.sortAscending = sortAscending
    end
    
    -- Update header arrows
    if frame.headerButtons then
        for _, btn in ipairs(frame.headerButtons) do
            if btn.column == sortColumn then
                btn.arrow:SetText(sortAscending and "^" or "v")
            else
                btn.arrow:SetText("")
            end
        end
    end
    
    self:UpdateRosterDisplay()
end

-- Filter and display roster
function IGW:UpdateRosterDisplay()
    if not frame or not frame:IsVisible() then return end
    if not frame.rosterRows or not frame.rosterScroll then return end
    
    displayedMembers = {}
    
    -- Filter members
    for i, member in ipairs(rosterData) do
        local show = true
        
        -- Text filter (legacy search box)
        if filterText ~= "" then
            local searchIn = string.lower(member.name or "") .. 
                           string.lower(member.class or "") .. 
                           string.lower(member.rank or "") .. 
                           string.lower(member.note or "") .. 
                           string.lower(member.officernote or "")
            if not string.find(searchIn, filterText, 1, true) then
                show = false
            end
        end
        
        -- Advanced filters (individual column searches)
        if show and frame.advancedFilters then
            if frame.advancedFilters.name ~= "" then
                local nameSearch = string.lower(member.name or "")
                if not string.find(nameSearch, frame.advancedFilters.name, 1, true) then
                    show = false
                end
            end
            
            if show and frame.advancedFilters.note ~= "" then
                local noteSearch = string.lower(member.note or "")
                if not string.find(noteSearch, frame.advancedFilters.note, 1, true) then
                    show = false
                end
            end
            
            if show and frame.advancedFilters.officernote ~= "" then
                local officerNoteSearch = string.lower(member.officernote or "")
                if not string.find(officerNoteSearch, frame.advancedFilters.officernote, 1, true) then
                    show = false
                end
            end
        end
        
        -- Offline filter
        if show and not showOffline then
            if not member.online then
                show = false
            end
        end
        
        -- Rank filter
        if show and filterRank >= 0 then
            if member.rankIndex ~= filterRank then
                show = false
            end
        end
        
        if show then
            table.insert(displayedMembers, {
                index = i,
                data = member
            })
        end
    end
    
    -- Sort members
    table.sort(displayedMembers, function(a, b)
        local aVal, bVal
        
        if sortColumn == "name" then
            aVal = a.data.name or ""
            bVal = b.data.name or ""
        elseif sortColumn == "level" then
            aVal = a.data.level or 0
            bVal = b.data.level or 0
        elseif sortColumn == "class" then
            aVal = a.data.class or ""
            bVal = b.data.class or ""
        elseif sortColumn == "rank" then
            aVal = a.data.rankIndex or 0
            bVal = b.data.rankIndex or 0
        elseif sortColumn == "note" then
            aVal = a.data.note or ""
            bVal = b.data.note or ""
        elseif sortColumn == "officernote" then
            aVal = a.data.officernote or ""
            bVal = b.data.officernote or ""
        elseif sortColumn == "lastonline" or sortColumn == "online" then
            -- Sort by time offline (online first, then by how long offline)
            if a.data.online and b.data.online then
                aVal = 0
                bVal = 0
            elseif a.data.online then
                aVal = 0  -- Online = 0 (most recent)
                bVal = 999999  -- Offline = large number
            elseif b.data.online then
                aVal = 999999
                bVal = 0
            else
                -- Both offline, calculate time in hours
                local aHours = (a.data.yearsOffline or 0) * 8760 + 
                              (a.data.monthsOffline or 0) * 730 + 
                              (a.data.daysOffline or 0) * 24 + 
                              (a.data.hoursOffline or 0)
                local bHours = (b.data.yearsOffline or 0) * 8760 + 
                              (b.data.monthsOffline or 0) * 730 + 
                              (b.data.daysOffline or 0) * 24 + 
                              (b.data.hoursOffline or 0)
                aVal = aHours
                bVal = bHours
            end
        elseif sortColumn == "zone" then
            aVal = a.data.zone or ""
            bVal = b.data.zone or ""
        end
        
        if sortAscending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)
    
    -- Update scroll frame
    local numDisplayed = table.getn(displayedMembers)
    
    -- Update FauxScrollFrame
    local rowHeight = (currentTab == "roster") and ROW_HEIGHT_DETAILS or ROW_HEIGHT_DEFAULT
    local maxRows = (currentTab == "roster") and VISIBLE_ROWS_DETAILS or VISIBLE_ROWS_GUILD
    
    -- Ensure we don't have more scroll range than needed
    -- If we have fewer items than visible rows, no scrolling needed
    local scrollItems = numDisplayed
    if numDisplayed <= maxRows then
        scrollItems = maxRows  -- Set to maxRows to disable scrolling
    end
    
    FauxScrollFrame_Update(frame.rosterScroll, scrollItems, maxRows, rowHeight)
    local offset = FauxScrollFrame_GetOffset(frame.rosterScroll)
    
    -- Safety clamp: ensure offset doesn't exceed valid range
    local maxOffset = math.max(0, numDisplayed - maxRows)
    if offset > maxOffset then
        offset = maxOffset
    end
    

    local headerTopY = IGW_GetHeaderTopY()
    -- Display rows with offset
    for i = 1, 14 do
        local row = frame.rosterRows[i]



        local maxRows = (currentTab == "roster") and VISIBLE_ROWS_DETAILS or VISIBLE_ROWS_GUILD
        if i > maxRows then
            row:Hide()
        end
        -- Only show fewer rows on Member Details tab
        if currentTab == "roster" and i > VISIBLE_ROWS_DETAILS then
            row:Hide()
        end
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, (headerTopY - 30) - (i-1) * rowHeight)
        local dataIndex = offset + i
        if dataIndex <= numDisplayed and not (currentTab == "roster" and i > VISIBLE_ROWS_DETAILS) then
            local member = displayedMembers[dataIndex].data
            local index = displayedMembers[dataIndex].index
            
            -- Debug first few rows
            
            if currentTab == "roster" then
                -- Roster view columns: Name, Level, Rank, Note, Officer Note, Last Online
                
                -- Name (without offline tag)
                row.name:SetText(member.name or "")
                if member.online then
                    row.name:SetTextColor(1, 1, 1)
                else
                    row.name:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Level
                row.level:SetText(member.level)
                row.level:SetTextColor(1, 1, 1)
                
                -- Rank (using class field)
                row.class:SetText(member.rank or "")
                row.class:SetTextColor(1, 1, 1)
                
                -- Note (using rank field)
                row.rank:SetText(member.note or "")
                row.rank:SetTextColor(1, 1, 1)
                
                -- Officer Note (using note field)
                if CanViewOfficerNote() then
                    row.note:SetText(member.officernote or "")
                else
                    row.note:SetText("")
                end
                row.note:SetTextColor(1, 1, 1)
                
                -- Last Online (using officerNote field)
                if member.online then
                    row.officerNote:SetText("Online")
                    row.officerNote:SetTextColor(0, 1, 0)
                else
                    -- Format last online time
                    local lastOnlineText = ""
                    local isOldOffline = false
                    
                    if member.yearsOffline and member.yearsOffline > 0 then
                        lastOnlineText = member.yearsOffline .. "y ago"
                        isOldOffline = true
                    elseif member.monthsOffline and member.monthsOffline >= 2 then
                        lastOnlineText = member.monthsOffline .. "m ago"
                        isOldOffline = true
                    elseif member.monthsOffline and member.monthsOffline > 0 then
                        lastOnlineText = member.monthsOffline .. "m ago"
                    elseif member.daysOffline and member.daysOffline > 0 then
                        lastOnlineText = member.daysOffline .. "d ago"
                    elseif member.hoursOffline and member.hoursOffline > 0 then
                        lastOnlineText = member.hoursOffline .. "h ago"
                    else
                        lastOnlineText = "Recently"
                    end
                    
                    row.officerNote:SetText(lastOnlineText)
                    if isOldOffline then
                        row.officerNote:SetTextColor(1, 0, 0)  -- Red for 2+ months
                    else
                        row.officerNote:SetTextColor(0.5, 0.5, 0.5)  -- Gray
                    end
                end
            else
                -- Guild Members view columns: Name, Level, Class, Location, Rank
                -- Name
                local nameText = member.name
                row.name:SetText(nameText)
                if member.online then
                    row.name:SetTextColor(1, 1, 1)
                else
                    row.name:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Level
                row.level:SetText(member.level)
                row.level:SetTextColor(1, 1, 1)
                
                -- Class with color
                local color = CLASS_COLORS[member.class] or {r=1, g=1, b=1}
                row.class:SetTextColor(color.r, color.g, color.b)
                row.class:SetText(member.class or "")
                
                -- Location (use rank field for display)
                if member.online then
                    row.rank:SetText(member.zone or "Unknown")
                    row.rank:SetTextColor(1, 1, 1)
                else
                    row.rank:SetText("Offline")
                    row.rank:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Rank (use note field for display)
                row.note:SetText(member.rank or "")
                row.note:SetTextColor(1, 1, 1)
                
                -- Hide officer note field (not used in this view)
                row.officerNote:SetText("")
            end
            
            row.memberIndex = index
            row.memberName = member.name
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Update member count with online and total
    local onlineCount = 0
    local totalMembers = table.getn(rosterData)
    
    for _, m in ipairs(rosterData) do
        if m.online then
            onlineCount = onlineCount + 1
        end
    end
    
    if frame.memberCount then
        frame.memberCount:SetText(string.format("%d Online | %d Total", onlineCount, totalMembers))
    end
end

-- Toggle window visibility
function IGW:ToggleWindow()
    if frame:IsVisible() then
        frame:Hide()
        -- Save window states if remember is enabled
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows then
            ImprovedGuildWindowDB.windowStates = {
                detailsOpen = IGW.detailsFrame and IGW.detailsFrame:IsVisible() or false,
                infoOpen = IGW.infoFrame and IGW.infoFrame:IsVisible() or false
            }
        end
        -- Close details window when main window closes
        if IGW.detailsFrame then
            IGW.detailsFrame:Hide()
        end
        -- Close guild info window when main window closes
        if IGW.infoFrame then
            IGW.infoFrame:Hide()
        end
    else
        if IsInGuild() then
            GuildRoster()
            -- Use saved default tab or fall back to "details"
            local defaultTab = "details"
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.defaultTab then
                defaultTab = ImprovedGuildWindowDB.defaultTab
            end
            self:SwitchTab(defaultTab)
            frame:Show()
            self:UpdateRosterDisplay()
            
            -- Restore remembered windows if enabled
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows and ImprovedGuildWindowDB.windowStates then
                if ImprovedGuildWindowDB.windowStates.detailsOpen and IGW.detailsFrame then
                    IGW.detailsFrame:Show()
                end
                if ImprovedGuildWindowDB.windowStates.infoOpen and IGW.infoFrame then
                    IGW:ToggleGuildInfoWindow()
                end
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000You are not in a guild.|r")
        end
    end
end

-- Global function for keybind
function ImprovedGuildWindow_Toggle()
    IGW:ToggleWindow()
end
-- Update Guild Info window contents
function IGW:UpdateGuildInfoWindow()
    if not IGW.infoFrame then return end
    local gf = IGW.infoFrame

    -- Guild name
    local guildName = GetGuildInfo("player") or "Guild"
    if gf.guildNameText then
        gf.guildNameText:SetText(guildName)
    end

    -- Total members (use rosterData if populated, otherwise query API)
    local total = 0
    if rosterData and table.getn(rosterData) > 0 then
        total = table.getn(rosterData)
    else
        total = GetNumGuildMembers(true) or 0
    end
    if gf.totalMembersText then
        gf.totalMembersText:SetText("Total Members: " .. total)
    end

    -- MOTD
    local motd = ""
    if GetGuildRosterMOTD then
        motd = GetGuildRosterMOTD() or ""
    end
    if motd == "" then motd = "—" end
    if gf.motdValue then
        gf.motdValue:SetText(motd)
    end

    -- Guild Information (public guild info text)
    local infoText = ""
    if GetGuildInfoText then
        infoText = GetGuildInfoText() or ""
    end
    if infoText == "" then infoText = "—" end
    if gf.infoValue then
        gf.infoValue:SetText(infoText)
    end
    
    -- Class distribution (from rosterData) - Bar Graph
    -- Clear existing bars
    if gf.classBars then
        for _, bar in ipairs(gf.classBars) do
            bar.frame:Hide()
        end
        gf.classBars = {}
    end
    
    local counts = {}
    local maxCount = 0
    for _, m in ipairs(rosterData or {}) do
        if m and m.class then
            counts[m.class] = (counts[m.class] or 0) + 1
            if counts[m.class] > maxCount then
                maxCount = counts[m.class]
            end
        end
    end

    local entries = {}
    for cls, c in pairs(counts) do
        table.insert(entries, {cls=cls, c=c})
    end
    table.sort(entries, function(a,b)
        if a.c == b.c then
            return a.cls < b.cls
        end
        return a.c > b.c
    end)

    -- Create bars
    local barHeight = 12
    local barGap = 2
    local maxBarWidth = 180
    local yOffset = 0
    
    for i, e in ipairs(entries) do
        if i > 10 then break end -- Limit to top 10 classes
        
        local barFrame = CreateFrame("Frame", nil, gf.classBarsContainer)
        barFrame:SetPoint("TOPLEFT", gf.classBarsContainer, "TOPLEFT", 0, yOffset)
        barFrame:SetHeight(barHeight)
        
        -- Calculate bar width based on count
        local barWidth = maxCount > 0 and (e.c / maxCount) * maxBarWidth or 0
        barFrame:SetWidth(barWidth)
        
        -- Bar background with class color
        local color = CLASS_COLORS[e.cls] or {r=0.5, g=0.5, b=0.5}
        local barBg = barFrame:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(barFrame)
        barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barBg:SetVertexColor(color.r, color.g, color.b, 0.8)
        
        -- Label (class name and count)
        local label = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", barFrame, "LEFT", 3, 0)
        label:SetText(string.format("%s: %d", e.cls, e.c))
        label:SetTextColor(1, 1, 1)
        
        table.insert(gf.classBars, {frame=barFrame, bg=barBg, label=label})
        
        yOffset = yOffset - (barHeight + barGap)
    end
    
    -- Level 60 count
    local level60Count = 0
    for _, m in ipairs(rosterData or {}) do
        if m and m.level == 60 then
            level60Count = level60Count + 1
        end
    end
    if gf.level60Value then
        gf.level60Value:SetText(tostring(level60Count))
    end
    
    -- Zone distribution (online members only)
    local zoneCounts = {}
    for _, m in ipairs(rosterData or {}) do
        if m and m.online and m.zone and m.zone ~= "" then
            zoneCounts[m.zone] = (zoneCounts[m.zone] or 0) + 1
        end
    end
    
    local zoneEntries = {}
    for zone, count in pairs(zoneCounts) do
        table.insert(zoneEntries, {zone=zone, count=count})
    end
    table.sort(zoneEntries, function(a,b)
        if a.count == b.count then
            return a.zone < b.zone
        end
        return a.count > b.count
    end)
    
    local zoneLines = {}
    local maxZones = 5
    for i, e in ipairs(zoneEntries) do
        if i > maxZones then break end
        table.insert(zoneLines, string.format("%s: %d", e.zone, e.count))
    end
    local zoneText = table.concat(zoneLines, "\n")
    if zoneText == "" then
        zoneText = "No members online"
    end
    
    if gf.zonesValue then
        gf.zonesValue:SetText(zoneText)
    end
    
    -- Officers Online (uses OFFICER_RANK_THRESHOLD configuration)
    local onlineOfficers = {}
    for _, m in ipairs(rosterData or {}) do
        if m and m.online and m.rankIndex ~= nil then
            -- rankIndex: 0=Guild Master, 1-9=other ranks
            if m.rankIndex <= OFFICER_RANK_THRESHOLD then
                table.insert(onlineOfficers, m.name)
            end
        end
    end
    
    local officersText = ""
    if table.getn(onlineOfficers) > 0 then
        table.sort(onlineOfficers)
        officersText = table.concat(onlineOfficers, "\n")
    else
        officersText = "No officers online"
    end
    
    if gf.officersValue then
        gf.officersValue:SetText(officersText)
    end
end



-- Toggle Guild Info window (left-side companion window; empty for now)
function IGW:ToggleGuildInfoWindow()
    if not frame then return end

    -- Create if needed
    if not IGW.infoFrame then
        local gf = CreateFrame("Frame", "IGW_GuildInfoFrame", UIParent)
        IGW_AddToSpecialFrames("IGW_GuildInfoFrame", true)
        gf:SetWidth(250)
        gf:SetHeight(frame:GetHeight())
        gf:SetFrameStrata("MEDIUM")
            gf:SetFrameLevel(10)
        -- Only allow moving if setting is enabled
        gf:SetMovable((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        gf:EnableMouse(true)
        gf:SetClampedToScreen(true)
        gf:Hide()

        -- Background (border only, solid texture added separately)
        gf:SetBackdrop({
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
        gf:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local gfBgTexture = gf:CreateTexture(nil, "BACKGROUND")
        gfBgTexture:SetPoint("TOPLEFT", gf, "TOPLEFT", 11, -12)
        gfBgTexture:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        gfBgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        gf.bgTexture = gfBgTexture
        
-- Title bar
        local titleBar = CreateFrame("Frame", nil, gf)
        titleBar:SetPoint("TOPLEFT", gf, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", gf, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(gf:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() 
            if gf:IsMovable() then
                gf:StartMoving() 
            end
        end)
        titleBar:SetScript("OnDragStop", function() 
            if gf:IsMovable() then
                gf:StopMovingOrSizing() 
            end
        end)

        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Guild Info")
        gf.title = title

        local closeBtn = CreateFrame("Button", nil, gf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", gf, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(gf:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function() gf:Hide() end)


-- Content area
local content = CreateFrame("Frame", nil, gf)
content:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 20)
gf.content = content

-- Guild name (large, centered)
local guildNameText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guildNameText:SetPoint("TOP", content, "TOP", 0, 0)
guildNameText:SetJustifyH("CENTER")
guildNameText:SetText("Guild")
gf.guildNameText = guildNameText

-- Total members
local totalMembersText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
totalMembersText:SetPoint("TOP", guildNameText, "BOTTOM", 0, -10)
totalMembersText:SetJustifyH("CENTER")
totalMembersText:SetText("Total Members: 0")
gf.totalMembersText = totalMembersText

-- Divider 1 (after total members)
local div1 = content:CreateTexture(nil, "ARTWORK")
div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
div1:SetPoint("TOP", totalMembersText, "BOTTOM", 36, -12)
div1:SetWidth(300)
div1:SetHeight(16)

-- MOTD
local motdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
motdLabel:SetPoint("TOP", div1, "BOTTOM", -36, -10)
motdLabel:SetJustifyH("CENTER")
motdLabel:SetText("Message of the Day")
gf.motdLabel = motdLabel

local motdValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
motdValue:SetPoint("TOP", motdLabel, "BOTTOM", 0, -6)
motdValue:SetWidth(210)
motdValue:SetJustifyH("CENTER")
motdValue:SetText("—")
gf.motdValue = motdValue

-- Divider 2 (after MOTD)
local div2 = content:CreateTexture(nil, "ARTWORK")
div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
div2:SetPoint("TOP", motdValue, "BOTTOM", 36, -12)
div2:SetWidth(300)
div2:SetHeight(16)

-- Guild Information
local infoLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
infoLabel:SetPoint("TOP", div2, "BOTTOM", -36, -10)
infoLabel:SetJustifyH("CENTER")
infoLabel:SetText("Guild Information")
gf.infoLabel = infoLabel

local infoValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
infoValue:SetPoint("TOP", infoLabel, "BOTTOM", 0, -6)
infoValue:SetWidth(210)
infoValue:SetJustifyH("CENTER")
infoValue:SetText("—")
gf.infoValue = infoValue

-- Page 2 content frame (hidden by default)
local content2 = CreateFrame("Frame", nil, gf)
content2:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content2:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 50)
content2:Hide()
gf.content2 = content2

-- Page 2 - Class Distribution
local classLabel = content2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
classLabel:SetPoint("TOP", content2, "TOP", 0, 0)
classLabel:SetJustifyH("CENTER")
classLabel:SetText("Class Distribution")
gf.classLabel = classLabel

-- Container for class bars (reduced height)
local classBarsContainer = CreateFrame("Frame", nil, content2)
classBarsContainer:SetPoint("TOP", classLabel, "BOTTOM", 0, -8)
classBarsContainer:SetWidth(210)
classBarsContainer:SetHeight(120)
gf.classBarsContainer = classBarsContainer

-- Store bars for updating
gf.classBars = {}

-- Divider
local page2Div1 = content2:CreateTexture(nil, "ARTWORK")
page2Div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
page2Div1:SetPoint("TOP", classBarsContainer, "BOTTOM", 36, -8)
page2Div1:SetWidth(300)
page2Div1:SetHeight(16)

-- Level 60s Count
local level60Label = content2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
level60Label:SetPoint("TOP", page2Div1, "BOTTOM", -36, -8)
level60Label:SetJustifyH("CENTER")
level60Label:SetText("Level 60 Characters")
gf.level60Label = level60Label

local level60Value = content2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
level60Value:SetPoint("TOP", level60Label, "BOTTOM", 0, -4)
level60Value:SetWidth(210)
level60Value:SetJustifyH("CENTER")
level60Value:SetText("—")
gf.level60Value = level60Value

-- Divider
local page2Div2 = content2:CreateTexture(nil, "ARTWORK")
page2Div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
page2Div2:SetPoint("TOP", level60Value, "BOTTOM", 36, -8)
page2Div2:SetWidth(300)
page2Div2:SetHeight(16)

-- Current Zones
local zonesLabel = content2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
zonesLabel:SetPoint("TOP", page2Div2, "BOTTOM", -36, -8)
zonesLabel:SetJustifyH("CENTER")
zonesLabel:SetText("Current Zones (Online)")
gf.zonesLabel = zonesLabel

local zonesValue = content2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
zonesValue:SetPoint("TOP", zonesLabel, "BOTTOM", 0, -4)
zonesValue:SetWidth(210)
zonesValue:SetJustifyH("CENTER")
zonesValue:SetText("—")
gf.zonesValue = zonesValue

-- Divider
local page2Div3 = content2:CreateTexture(nil, "ARTWORK")
page2Div3:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
page2Div3:SetPoint("TOP", zonesValue, "BOTTOM", 36, -8)
page2Div3:SetWidth(300)
page2Div3:SetHeight(16)

-- Officers Online
local officersLabel = content2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
officersLabel:SetPoint("TOP", page2Div3, "BOTTOM", -36, -8)
officersLabel:SetJustifyH("CENTER")
officersLabel:SetText("Officers Online")
gf.officersLabel = officersLabel

local officersValue = content2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
officersValue:SetPoint("TOP", officersLabel, "BOTTOM", 0, -4)
officersValue:SetWidth(210)
officersValue:SetJustifyH("CENTER")
officersValue:SetText("—")
gf.officersValue = officersValue

-- Pagination buttons at bottom (match tab button styling)
local buttonHeight = 25  -- Match tab button height
local prevBtn = CreateFrame("Button", nil, gf, "UIPanelButtonTemplate")
prevBtn:SetPoint("BOTTOMLEFT", gf, "BOTTOMLEFT", 15, 15)
prevBtn:SetWidth(30)
prevBtn:SetHeight(buttonHeight)
prevBtn:SetText("<")
prevBtn:SetScript("OnClick", function()
    if gf.currentPage == 2 then
        gf.currentPage = 1
        gf.content:Show()
        gf.content2:Hide()
        gf.pageIndicator:SetText("Page 1 / 2")
    end
end)
gf.prevBtn = prevBtn

local nextBtn = CreateFrame("Button", nil, gf, "UIPanelButtonTemplate")
nextBtn:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -15, 15)
nextBtn:SetWidth(30)
nextBtn:SetHeight(buttonHeight)
nextBtn:SetText(">")
nextBtn:SetScript("OnClick", function()
    if gf.currentPage == 1 then
        gf.currentPage = 2
        gf.content:Hide()
        gf.content2:Show()
        gf.pageIndicator:SetText("Page 2 / 2")
    end
end)
gf.nextBtn = nextBtn

-- Page indicator (vertically centered with buttons)
local pageIndicator = gf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pageIndicator:SetPoint("BOTTOM", gf, "BOTTOM", 0, 15 + (buttonHeight / 2))
pageIndicator:SetText("Page 1 / 2")
gf.pageIndicator = pageIndicator

-- Initialize to page 1
gf.currentPage = 1

        IGW.infoFrame = gf
    end

    local gf = IGW.infoFrame
    if gf:IsVisible() then
        gf:Hide()
        -- Un-highlight tab3 button
        frame.tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab3Text:SetTextColor(0.7, 0.7, 0.7)
    else
        gf:ClearAllPoints()
        gf:SetPoint("TOPRIGHT", frame, "TOPLEFT", -5, 0)
        gf:SetHeight(frame:GetHeight())
        -- Highlight tab3 button
        frame.tab3:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab3Text:SetTextColor(1, 1, 1)
        -- Update texture with saved color and opacity
        if gf.bgTexture then
            local bgColor = {r = 0.15, g = 0.15, b = 0.15}
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
                bgColor = ImprovedGuildWindowDB.bgColor
            end
            gf.bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        end
        IGW:UpdateGuildInfoWindow()
            gf:Show()
    end
end

-- Toggle Options window
function IGW:ToggleOptionsWindow()
    if not frame then return end
    
    -- Create if needed
    if not IGW.optionsFrame then
        local of = CreateFrame("Frame", "IGW_OptionsFrame", UIParent)
        of:SetWidth(650)  -- Same width as main window
        of:SetHeight(500)  -- Same height as main window
        of:SetFrameStrata("DIALOG")
        of:SetFrameLevel(100)
        of:SetMovable(true)
        of:EnableMouse(true)
        of:SetClampedToScreen(true)
        of:Hide()
        
        -- Add to special frames for ESC key support
        IGW_AddToSpecialFrames("IGW_OptionsFrame", true)
        
        -- Border first
        of:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        of:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local bgTexture = of:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetPoint("TOPLEFT", of, "TOPLEFT", 11, -12)
        bgTexture:SetPoint("BOTTOMRIGHT", of, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey, always 90% opaque for options
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 0.9)
        of.bgTexture = bgTexture
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, of)
        titleBar:SetPoint("TOPLEFT", of, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", of, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(of:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() of:StartMoving() end)
        titleBar:SetScript("OnDragStop", function() of:StopMovingOrSizing() end)
        
        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Improved Guild Window - Options")
        
        local closeBtn = CreateFrame("Button", nil, of, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", of, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(of:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function() of:Hide() end)
        
        -- Content area
        local content = CreateFrame("Frame", nil, of)
        content:SetPoint("TOPLEFT", of, "TOPLEFT", 20, -50)
        content:SetPoint("BOTTOMRIGHT", of, "BOTTOMRIGHT", -20, 20)
        of.content = content
        
        local yOffset = 0
        
        -- Visual Settings Section
        local visualHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        visualHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        visualHeader:SetText("Visual Settings")
        yOffset = yOffset - 30
        
        -- Opacity Slider
        local opacityLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        opacityLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        opacityLabel:SetText("Window Opacity:")
        
        local opacitySlider = CreateFrame("Slider", "IGW_OpacitySlider", content, "OptionsSliderTemplate")
        opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -10)
        opacitySlider:SetWidth(300)
        opacitySlider:SetHeight(15)
        opacitySlider:SetMinMaxValues(0.3, 1.0)
        opacitySlider:SetValueStep(0.05)
        opacitySlider:SetValue(IGW_BG_OPACITY)
        getglobal("IGW_OpacitySliderLow"):SetText("30%")
        getglobal("IGW_OpacitySliderHigh"):SetText("100%")
        getglobal("IGW_OpacitySliderText"):SetText(string.format("%.0f%%", IGW_BG_OPACITY * 100))
        
        opacitySlider:SetScript("OnValueChanged", function()
            local value = this:GetValue()
            getglobal("IGW_OpacitySliderText"):SetText(string.format("%.0f%%", value * 100))
            -- Will be applied on save
        end)
        of.opacitySlider = opacitySlider
        
        -- Color options label (to the right of slider, moved up)
        local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        colorLabel:SetPoint("LEFT", opacitySlider, "RIGHT", 40, 30)
        colorLabel:SetText("Background Color:")
        
        -- Define 8 color options
        local colorOptions = {
            {r = 0.15, g = 0.15, b = 0.15, name = "Dark Grey"},     -- Default
            {r = 0.05, g = 0.05, b = 0.05, name = "Black"},
            {r = 0.1, g = 0.1, b = 0.2, name = "Dark Blue"},
            {r = 0.2, g = 0.15, b = 0.1, name = "Dark Brown"},
            {r = 0.15, g = 0.2, b = 0.15, name = "Dark Green"},
            {r = 0.2, g = 0.1, b = 0.15, name = "Dark Purple"},
            {r = 0.2, g = 0.15, b = 0.15, name = "Dark Red"},
            {r = 0.1, g = 0.15, b = 0.15, name = "Dark Cyan"}
        }
        
        -- Current selected color (default to first option)
        of.selectedColor = 1
        
        -- Create clickable color boxes
        local colorBoxes = {}
        for i, color in ipairs(colorOptions) do
            local box = CreateFrame("Button", nil, content)
            box:SetPoint("LEFT", colorLabel, "BOTTOMLEFT", (i-1) * 32, -30)
            box:SetWidth(30)
            box:SetHeight(30)
            
            -- Store color info on box
            box.colorName = color.name
            box.colorIndex = i
            
            -- Border first
            box:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            box:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            
            -- Background color (inset to stay within border)
            local bgTex = box:CreateTexture(nil, "BACKGROUND")
            bgTex:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
            bgTex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
            bgTex:SetTexture(color.r, color.g, color.b, 1)
            box.bgTex = bgTex
            
            -- Selection indicator (white border when selected)
            box.selected = false
            
            box:SetScript("OnClick", function()
                -- Deselect all
                for j, b in ipairs(colorBoxes) do
                    b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                    b.selected = false
                end
                -- Select this one
                this:SetBackdropBorderColor(1, 1, 1, 1)
                this.selected = true
                of.selectedColor = this.colorIndex
            end)
            
            box:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetText(this.colorName)
                GameTooltip:Show()
            end)
            
            box:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            
            colorBoxes[i] = box
        end
        
        -- Preselect the saved color or default to first
        local savedColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            savedColor = ImprovedGuildWindowDB.bgColor
        end
        local selectedIndex = 1
        for i, color in ipairs(colorOptions) do
            -- Compare with small tolerance for floating point
            local rMatch = math.abs(color.r - savedColor.r) < 0.01
            local gMatch = math.abs(color.g - savedColor.g) < 0.01
            local bMatch = math.abs(color.b - savedColor.b) < 0.01
            if rMatch and gMatch and bMatch then
                selectedIndex = i
                break
            end
        end
        colorBoxes[selectedIndex]:SetBackdropBorderColor(1, 1, 1, 1)
        colorBoxes[selectedIndex].selected = true
        of.selectedColor = selectedIndex
        
        of.colorOptions = colorOptions
        of.colorBoxes = colorBoxes
        
        yOffset = yOffset - 65
        
        -- Divider
        local divider1 = content:CreateTexture(nil, "ARTWORK")
        divider1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        divider1:SetPoint("TOP", content, "TOP", 103, yOffset)
        divider1:SetWidth(830)
        divider1:SetHeight(16)
        yOffset = yOffset - 30
        
        -- Window Behavior Section
        local behaviorHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        behaviorHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        behaviorHeader:SetText("Window Behavior")
        yOffset = yOffset - 30
        
        -- Remember Open Windows Checkbox
        local rememberWindowsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        rememberWindowsCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        rememberWindowsCheck:SetWidth(24)
        rememberWindowsCheck:SetHeight(24)
        rememberWindowsCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows) or false)
        
        local rememberWindowsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rememberWindowsLabel:SetPoint("LEFT", rememberWindowsCheck, "RIGHT", 5, 0)
        rememberWindowsLabel:SetText("Remember which windows are open")
        
        of.rememberWindowsCheck = rememberWindowsCheck
        yOffset = yOffset - 30
        
        -- Allow Moving Side Windows Checkbox
        local allowMoveSideCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        allowMoveSideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        allowMoveSideCheck:SetWidth(24)
        allowMoveSideCheck:SetHeight(24)
        allowMoveSideCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        
        local allowMoveSideLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        allowMoveSideLabel:SetPoint("LEFT", allowMoveSideCheck, "RIGHT", 5, 0)
        allowMoveSideLabel:SetText("Allow moving side windows (Member Details / Guild Info)")
        
        of.allowMoveSideCheck = allowMoveSideCheck
        yOffset = yOffset - 40
        
        -- Divider
        local divider2 = content:CreateTexture(nil, "ARTWORK")
        divider2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        divider2:SetPoint("TOP", content, "TOP", 103, yOffset)
        divider2:SetWidth(830)
        divider2:SetHeight(16)
        yOffset = yOffset - 30
        
        -- Default View Section
        local defaultViewHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        defaultViewHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        defaultViewHeader:SetText("Default View")
        yOffset = yOffset - 30
        
        -- Default Tab Label
        local defaultTabLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        defaultTabLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        defaultTabLabel:SetText("Default tab on open:")
        yOffset = yOffset - 25
        
        -- Radio Buttons for Default Tab
        local guildMembersRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        guildMembersRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        guildMembersRadio:SetWidth(20)
        guildMembersRadio:SetHeight(20)
        
        local guildMembersLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildMembersLabel:SetPoint("LEFT", guildMembersRadio, "RIGHT", 5, 0)
        guildMembersLabel:SetText("Guild Members (online only)")
        
        yOffset = yOffset - 25
        
        local memberDetailsRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        memberDetailsRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        memberDetailsRadio:SetWidth(20)
        memberDetailsRadio:SetHeight(20)
        
        local memberDetailsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        memberDetailsLabel:SetPoint("LEFT", memberDetailsRadio, "RIGHT", 5, 0)
        memberDetailsLabel:SetText("Member Details (all members)")
        
        -- Set initial radio button states
        local defaultTab = (ImprovedGuildWindowDB and ImprovedGuildWindowDB.defaultTab) or "details"
        if defaultTab == "details" then
            guildMembersRadio:SetChecked(true)
            memberDetailsRadio:SetChecked(false)
        else
            guildMembersRadio:SetChecked(false)
            memberDetailsRadio:SetChecked(true)
        end
        
        -- Radio button scripts
        guildMembersRadio:SetScript("OnClick", function()
            guildMembersRadio:SetChecked(true)
            memberDetailsRadio:SetChecked(false)
        end)
        
        memberDetailsRadio:SetScript("OnClick", function()
            guildMembersRadio:SetChecked(false)
            memberDetailsRadio:SetChecked(true)
        end)
        
        of.guildMembersRadio = guildMembersRadio
        of.memberDetailsRadio = memberDetailsRadio
        
        -- Save Button
        local saveBtn = CreateFrame("Button", nil, of, "UIPanelButtonTemplate")
        saveBtn:SetPoint("BOTTOM", of, "BOTTOM", 0, 15)
        saveBtn:SetWidth(100)
        saveBtn:SetHeight(25)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            IGW:SaveOptions()
            of:Hide()
        end)
        
        IGW.optionsFrame = of
    end
    
    local of = IGW.optionsFrame
    if of:IsVisible() then
        of:Hide()
    else
        -- Update background color before showing
        if of.bgTexture then
            local bgColor = {r = 0.15, g = 0.15, b = 0.15}
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
                bgColor = ImprovedGuildWindowDB.bgColor
            end
            of.bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 0.9)
        end
        -- Anchor top of options window to top of main window
        of:ClearAllPoints()
        of:SetPoint("TOP", frame, "TOP", 0, 0)
        of:Show()
    end
end


-- Save Options from settings window
function IGW:SaveOptions()
    local of = IGW.optionsFrame
    if not of then return end
    
    -- Initialize DB if it doesn't exist
    if not ImprovedGuildWindowDB then
        ImprovedGuildWindowDB = {}
    end
    
    -- Save opacity
    local opacityValue = of.opacitySlider:GetValue()
    IGW_BG_OPACITY = opacityValue
    ImprovedGuildWindowDB.opacity = opacityValue
    
    -- Apply opacity and color to all windows immediately
    local selectedColor = of.colorOptions and of.colorOptions[of.selectedColor or 1]
    if selectedColor then
        if frame and frame.bgTexture then
            frame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        if IGW.detailsFrame and IGW.detailsFrame.bgTexture then
            IGW.detailsFrame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        if IGW.infoFrame and IGW.infoFrame.bgTexture then
            IGW.infoFrame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        -- Apply to options window (always 90% opaque)
        if of and of.bgTexture then
            of.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, 0.9)
        end
        
        -- Save background color
        ImprovedGuildWindowDB.bgColor = {r = selectedColor.r, g = selectedColor.g, b = selectedColor.b}
    end
    
    -- Save remember windows setting
    ImprovedGuildWindowDB.rememberWindows = of.rememberWindowsCheck:GetChecked() == 1
    
    -- Save allow moving side windows setting
    ImprovedGuildWindowDB.allowMoveSideWindows = of.allowMoveSideCheck:GetChecked() == 1
    
    -- Apply movable state to side windows immediately
    if IGW.detailsFrame then
        IGW.detailsFrame:SetMovable(ImprovedGuildWindowDB.allowMoveSideWindows)
    end
    if IGW.infoFrame then
        IGW.infoFrame:SetMovable(ImprovedGuildWindowDB.allowMoveSideWindows)
    end
    
    -- Save which windows are currently open (if remember is enabled)
    if ImprovedGuildWindowDB.rememberWindows then
        ImprovedGuildWindowDB.windowStates = {
            detailsOpen = IGW.detailsFrame and IGW.detailsFrame:IsVisible() or false,
            infoOpen = IGW.infoFrame and IGW.infoFrame:IsVisible() or false
        }
    end
    
    -- Save default tab
    if of.guildMembersRadio:GetChecked() then
        ImprovedGuildWindowDB.defaultTab = "details"
    else
        ImprovedGuildWindowDB.defaultTab = "roster"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Options saved!|r")
end


-- Slash command
SLASH_IMPROVEDGUILDWINDOW1 = "/igw"
SLASH_IMPROVEDGUILDWINDOW2 = "/improvedguild"
SlashCmdList["IMPROVEDGUILDWINDOW"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "" or msg == "show" or msg == "toggle" then
        IGW:ToggleWindow()
    elseif msg == "hide" then
        frame:Hide()
    elseif msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("=== IGW Debug Info ===")
        DEFAULT_CHAT_FRAME:AddMessage("Total roster data: " .. table.getn(rosterData))
        DEFAULT_CHAT_FRAME:AddMessage("Current filterRank: " .. filterRank)
        DEFAULT_CHAT_FRAME:AddMessage("Num ranks: " .. GuildControlGetNumRanks())
        
        -- Count members by rank
        local rankCounts = {}
        for i = 0, 9 do rankCounts[i] = 0 end
        for i, m in ipairs(rosterData) do
            if m.rankIndex then
                rankCounts[m.rankIndex] = (rankCounts[m.rankIndex] or 0) + 1
            end
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("Members per rank:")
        for i = 1, GuildControlGetNumRanks() do
            local rankName = GuildControlGetRankName(i)
            local rankIdx = i - 1
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s (idx %d): %d members", 
                rankName, rankIdx, rankCounts[rankIdx] or 0))
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("First 5 members:")
        for i = 1, math.min(5, table.getn(rosterData)) do
            local m = rosterData[i]
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: rank=%s, rankIndex=%s", 
                m.name or "nil", m.rank or "nil", tostring(m.rankIndex or "nil")))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Improved Guild Window Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("/igw - Toggle window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw show - Show window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw hide - Hide window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw debug - Show debug info")
    end
end

-- Initialize addon
IGW:OnLoad()

-- Keybind note: Users can set Shift+O in Key Bindings menu under "Improved Guild Window"