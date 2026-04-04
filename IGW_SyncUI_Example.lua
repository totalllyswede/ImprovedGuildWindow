--[[
    IGW_SyncUI.lua
    Example UI integration for IGW_Sync module
    
    This file shows how to integrate the sync module into Guild Info pages
    Add this code to ImprovedGuildWindow.lua to enable sync features
]]

-- EXAMPLE: Guild Info Page 5 - Events & Announcements

function IGW:CreateGuildInfoPage5()
    if not IGW_Sync then return end
    
    local page = self.infoPages[5]
    if not page then return end
    
    -- Clear existing content
    if page.content then
        for _, child in ipairs({page.content:GetChildren()}) do
            child:Hide()
        end
    end
    
    -- Create content frame if needed
    if not page.content then
        page.content = CreateFrame("Frame", nil, page)
        page.content:SetAllPoints(page)
    end
    
    local content = page.content
    local yOffset = -10
    
    -- Sync status
    local status = IGW_Sync:GetSyncStatus()
    local statusText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", content, "TOP", 0, yOffset)
    statusText:SetWidth(220)
    statusText:SetTextColor(0.7, 0.7, 0.7)
    statusText:SetText(status.peers .. " addon users online")
    yOffset = yOffset - 25
    
    -- Title: Upcoming Events
    local eventsTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eventsTitle:SetPoint("TOP", content, "TOP", 0, yOffset)
    eventsTitle:SetWidth(220)
    eventsTitle:SetText("Upcoming Events")
    eventsTitle:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 20
    
    -- Get upcoming events
    local events = IGW_Sync:GetUpcomingEvents(5)
    
    if table.getn(events) == 0 then
        local noEvents = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noEvents:SetPoint("TOP", content, "TOP", 0, yOffset)
        noEvents:SetWidth(220)
        noEvents:SetText("No upcoming events")
        noEvents:SetTextColor(0.6, 0.6, 0.6)
        yOffset = yOffset - 20
    else
        for _, event in ipairs(events) do
            -- Event name
            local eventName = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            eventName:SetPoint("TOP", content, "TOP", 0, yOffset)
            eventName:SetWidth(220)
            eventName:SetText(event.name or "Unnamed Event")
            eventName:SetTextColor(1, 1, 1)
            yOffset = yOffset - 15
            
            -- Event time
            local eventTime = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            eventTime:SetPoint("TOP", content, "TOP", 0, yOffset)
            eventTime:SetWidth(220)
            eventTime:SetText(date("%m/%d %I:%M %p", event.timestamp))
            eventTime:SetTextColor(0.5, 1, 0.5)
            yOffset = yOffset - 15
            
            -- Event description
            if event.description then
                local eventDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                eventDesc:SetPoint("TOP", content, "TOP", 0, yOffset)
                eventDesc:SetWidth(220)
                eventDesc:SetText(event.description)
                eventDesc:SetTextColor(0.8, 0.8, 0.8)
                yOffset = yOffset - 15
            end
            
            yOffset = yOffset - 5 -- Space between events
        end
    end
    
    yOffset = yOffset - 10
    
    -- Title: Recent Announcements
    local annTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    annTitle:SetPoint("TOP", content, "TOP", 0, yOffset)
    annTitle:SetWidth(220)
    annTitle:SetText("Recent Announcements")
    annTitle:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 20
    
    -- Get recent announcements
    local announcements = IGW_Sync:GetAnnouncements(3)
    
    if table.getn(announcements) == 0 then
        local noAnn = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noAnn:SetPoint("TOP", content, "TOP", 0, yOffset)
        noAnn:SetWidth(220)
        noAnn:SetText("No recent announcements")
        noAnn:SetTextColor(0.6, 0.6, 0.6)
    else
        for _, ann in ipairs(announcements) do
            -- Author and time
            local annHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            annHeader:SetPoint("TOP", content, "TOP", 0, yOffset)
            annHeader:SetWidth(220)
            annHeader:SetText(ann.author .. " - " .. date("%m/%d", ann.timestamp))
            annHeader:SetTextColor(0.7, 0.7, 1)
            yOffset = yOffset - 15
            
            -- Message
            local annMsg = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            annMsg:SetPoint("TOP", content, "TOP", 0, yOffset)
            annMsg:SetWidth(220)
            annMsg:SetText(ann.message)
            annMsg:SetTextColor(1, 1, 1)
            yOffset = yOffset - (15 * math.ceil(string.len(ann.message) / 40)) -- Estimate lines
            
            yOffset = yOffset - 5
        end
    end
    
    -- Add Event button (officers only)
    if self:IsOfficer() then
        yOffset = yOffset - 10
        local addEventBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        addEventBtn:SetWidth(120)
        addEventBtn:SetHeight(22)
        addEventBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
        addEventBtn:SetText("Add Event")
        addEventBtn:SetScript("OnClick", function()
            IGW:ShowAddEventDialog()
        end)
    end
end

-- Add Event Dialog
function IGW:ShowAddEventDialog()
    if not IGW_Sync then return end
    
    -- Create dialog if needed
    if not self.addEventDialog then
        local dialog = CreateFrame("Frame", "IGW_AddEventDialog", UIParent)
        dialog:SetWidth(300)
        dialog:SetHeight(250)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        dialog:SetBackdropColor(0, 0, 0, 1)
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", function() this:StartMoving() end)
        dialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        
        -- Title
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", dialog, "TOP", 0, -20)
        title:SetText("Add Guild Event")
        
        -- Event Name
        local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -50)
        nameLabel:SetText("Event Name:")
        
        local nameInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        nameInput:SetWidth(240)
        nameInput:SetHeight(20)
        nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 5, -5)
        nameInput:SetAutoFocus(false)
        dialog.nameInput = nameInput
        
        -- Event Date/Time
        local timeLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", -5, -10)
        timeLabel:SetText("Date/Time (MM/DD HH:MM):")
        
        local timeInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        timeInput:SetWidth(240)
        timeInput:SetHeight(20)
        timeInput:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 5, -5)
        timeInput:SetAutoFocus(false)
        dialog.timeInput = timeInput
        
        -- Description
        local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descLabel:SetPoint("TOPLEFT", timeInput, "BOTTOMLEFT", -5, -10)
        descLabel:SetText("Description:")
        
        local descInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        descInput:SetWidth(240)
        descInput:SetHeight(20)
        descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 5, -5)
        descInput:SetAutoFocus(false)
        dialog.descInput = descInput
        
        -- Create button
        local createBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        createBtn:SetWidth(80)
        createBtn:SetHeight(22)
        createBtn:SetPoint("BOTTOM", dialog, "BOTTOM", -45, 20)
        createBtn:SetText("Create")
        createBtn:SetScript("OnClick", function()
            local name = dialog.nameInput:GetText()
            local timeStr = dialog.timeInput:GetText()
            local desc = dialog.descInput:GetText()
            
            if name == "" then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Event name required")
                return
            end
            
            -- Parse time (simple MM/DD HH:MM format)
            local month, day, hour, min = string.match(timeStr, "(%d+)/(%d+)%s+(%d+):(%d+)")
            if not month then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Invalid time format")
                return
            end
            
            -- Create timestamp (simple approximation)
            local currentYear = tonumber(date("%Y"))
            local timestamp = os.time({
                year = currentYear,
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min)
            })
            
            -- Create event
            IGW_Sync:AddEvent({
                name = name,
                timestamp = timestamp,
                description = desc
            })
            
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Event created and broadcast to guild")
            
            -- Clear inputs
            dialog.nameInput:SetText("")
            dialog.timeInput:SetText("")
            dialog.descInput:SetText("")
            
            -- Close dialog
            dialog:Hide()
            
            -- Refresh page
            if IGW.currentInfoPage == 5 then
                IGW:CreateGuildInfoPage5()
            end
        end)
        
        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetWidth(80)
        cancelBtn:SetHeight(22)
        cancelBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 45, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            dialog:Hide()
        end)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -5, -5)
        
        dialog:Hide()
        self.addEventDialog = dialog
    end
    
    self.addEventDialog:Show()
end

--[[
    EXAMPLE USAGE IN SLASH COMMANDS
]]

-- Add sync commands to existing slash handler
-- Place this in your existing SLASH_IGW1 handler

-- /igw sync status
if arg1 == "sync" and arg2 == "status" then
    if not IGW_Sync then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
        return
    end
    
    local status = IGW_Sync:GetSyncStatus()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync Status]|r")
    DEFAULT_CHAT_FRAME:AddMessage("  Connected peers: " .. status.peers)
    DEFAULT_CHAT_FRAME:AddMessage("  Events: " .. status.events)
    DEFAULT_CHAT_FRAME:AddMessage("  Announcements: " .. status.announcements)
    if status.lastSync > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  Last sync: " .. date("%c", status.lastSync))
    end
    return
end

-- /igw announce <message>
if arg1 == "announce" then
    if not IGW_Sync then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
        return
    end
    
    local message = string.gsub(arg, "^announce%s+", "")
    if message and message ~= "" then
        IGW_Sync:PostAnnouncement(message, "normal")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Announcement sent to guild")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Usage: /igw announce <message>")
    end
    return
end

-- /igw sync refresh
if arg1 == "sync" and arg2 == "refresh" then
    if not IGW_Sync then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
        return
    end
    
    IGW_Sync:RequestDataSync()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Requesting sync from peers...")
    return
end
