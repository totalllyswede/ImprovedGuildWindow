--[[
    IGW_Sync.lua
    Data synchronization module for ImprovedGuildWindow
    Uses SendAddonMessage/CHAT_MSG_ADDON to share data between addon users
]]

IGW_Sync = {}
IGW_Sync.VERSION = "1.0"
IGW_Sync.PREFIX = "IGW_SYNC"
IGW_Sync.PROTOCOL_VERSION = 1
IGW_Sync.debugEnabled = true  -- Debug messages on by default

-- Debug print helper
function IGW_Sync:DebugPrint(message)
    if self.debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("[IGW Debug] " .. message)
    end
end

-- Data storage
IGW_Sync.data = {
    announcements = {},    -- Guild announcements
    officerContacts = {},  -- Officer contact information
    guildBank = {},        -- Guild bank inventory (if tracked)
    raidSchedule = {},     -- Raid schedule (day -> {name, time})
    raidScheduleTimestamp = 0, -- Timestamp of last schedule update
    lastSync = 0,          -- Timestamp of last sync
    peers = {}             -- Other addon users online
}

-- Message types
IGW_Sync.MSG_TYPE = {
    HANDSHAKE = "HS",       -- Initial connection
    PING = "PING",          -- Keep-alive
    PONG = "PONG",          -- Ping response
    ANNOUNCEMENT = "ANN",   -- Guild announcement
    CLEAR_ANN = "CLRANN",   -- Clear all announcements (officers only)
    RAID_SCHEDULE = "RAID", -- Raid schedule update
    OFFICER_INFO = "OFC",   -- Officer contact update
    BANK_UPDATE = "BANK",   -- Guild bank inventory
    REQUEST_DATA = "REQ",   -- Request full data sync
    SYNC_DATA = "SYNC",     -- Full data sync response
    REQUEST_SCHEDULE = "REQSCHED",    -- Request raid schedule
    REQUEST_ANNOUNCEMENTS = "REQANN", -- Request announcements
    REQUEST_ALL = "REQALL"            -- Request all data
}

-- Initialize sync system
function IGW_Sync:Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Initializing...")
    
    -- Register addon message prefix (max 16 chars)
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.PREFIX)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Registered prefix: " .. self.PREFIX)
    end
    
    -- Register event handlers
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Events registered")
    
    -- Set up event handler
    self.frame:SetScript("OnEvent", IGW_Sync.OnEvent)
    
    -- Load saved data
    self:LoadData()
    
    -- Don't send handshake here - wait for PLAYER_ENTERING_WORLD
    -- This ensures we're in the world and guild roster is available
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Module initialized v" .. self.VERSION)
end

-- Event handler
function IGW_Sync.OnEvent(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        IGW_Sync:OnAddonMessage(prefix, message, channel, sender)
    elseif event == "GUILD_ROSTER_UPDATE" then
        IGW_Sync:DebugPrint("GUILD_ROSTER_UPDATE event received")
        IGW_Sync:OnGuildRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        IGW_Sync:DebugPrint("PLAYER_ENTERING_WORLD event received")
        IGW_Sync:OnPlayerEnteringWorld()
    end
end

-- Handle addon messages
function IGW_Sync:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.PREFIX then return end
    if sender == UnitName("player") then return end -- Ignore own messages
    
    IGW_Sync:DebugPrint("Received message from " .. sender .. ": " .. message)
    
    -- Decode message
    local msgType, data = self:DecodeMessage(message)
    if not msgType then 
        IGW_Sync:DebugPrint("Failed to decode message type")
        return 
    end
    
    IGW_Sync:DebugPrint("Message type: " .. msgType)
    
    -- Handle message by type
    if msgType == self.MSG_TYPE.HANDSHAKE then
        self:HandleHandshake(sender, data)
    elseif msgType == self.MSG_TYPE.PING then
        self:HandlePing(sender)
    elseif msgType == self.MSG_TYPE.PONG then
        self:HandlePong(sender)
    elseif msgType == self.MSG_TYPE.ANNOUNCEMENT then
        self:HandleAnnouncement(sender, data)
    elseif msgType == self.MSG_TYPE.CLEAR_ANN then
        self:HandleClearAnnouncements(sender, data)
    elseif msgType == self.MSG_TYPE.RAID_SCHEDULE then
        self:HandleRaidSchedule(sender, data)
    elseif msgType == self.MSG_TYPE.OFFICER_INFO then
        self:HandleOfficerInfo(sender, data)
    elseif msgType == self.MSG_TYPE.BANK_UPDATE then
        self:HandleBankUpdate(sender, data)
    elseif msgType == self.MSG_TYPE.REQUEST_DATA then
        self:HandleDataRequest(sender)
    elseif msgType == self.MSG_TYPE.SYNC_DATA then
        self:HandleSyncData(sender, data)
    elseif msgType == self.MSG_TYPE.REQUEST_SCHEDULE then
        self:HandleScheduleRequest(sender)
    elseif msgType == self.MSG_TYPE.REQUEST_ANNOUNCEMENTS then
        self:HandleAnnouncementsRequest(sender)
    elseif msgType == self.MSG_TYPE.REQUEST_ALL then
        self:HandleAllDataRequest(sender)
    end
end

-- Send message to guild
function IGW_Sync:SendMessage(msgType, data)
    local message = self:EncodeMessage(msgType, data)
    if message then
        IGW_Sync:DebugPrint("Sending message: " .. message)
        SendAddonMessage(self.PREFIX, message, "GUILD")
    end
end

-- Send message to specific player
function IGW_Sync:SendMessageTo(msgType, data, target)
    -- Note: WoW 1.12.1 doesn't support targeted addon messages
    -- Just send to GUILD and include target in data if needed
    IGW_Sync:DebugPrint("SendMessageTo called: type=" .. msgType .. ", target=" .. (target or "nil"))
    local message = self:EncodeMessage(msgType, data)
    if message then
        IGW_Sync:DebugPrint("Sending targeted message: " .. message)
        SendAddonMessage(self.PREFIX, message, "GUILD")
    end
end

-- Encode message (simple format: TYPE:DATA)
function IGW_Sync:EncodeMessage(msgType, data)
    if not msgType then return nil end
    
    local encoded = msgType
    if data then
        -- Convert table to string (simple serialization)
        local dataStr = self:SerializeData(data)
        if dataStr then
            encoded = encoded .. ":" .. dataStr
        end
    end
    
    -- Check message length (max 255 chars for addon messages)
    if string.len(encoded) > 255 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW Sync]|r Message too long, truncating")
        encoded = string.sub(encoded, 1, 255)
    end
    
    return encoded
end

-- Decode message
function IGW_Sync:DecodeMessage(message)
    if not message or message == "" then return nil, nil end
    
    local colonPos = string.find(message, ":")
    if not colonPos then
        return message, nil
    end
    
    local msgType = string.sub(message, 1, colonPos - 1)
    local dataStr = string.sub(message, colonPos + 1)
    local data = self:DeserializeData(dataStr)
    
    return msgType, data
end

-- Simple data serialization (key=value&key2=value2)
function IGW_Sync:SerializeData(data)
    if type(data) ~= "table" then
        return tostring(data)
    end
    
    local parts = {}
    for k, v in pairs(data) do
        local key = tostring(k)
        local value = tostring(v)
        -- No escaping - just use simple format
        table.insert(parts, key .. "=" .. value)
    end
    
    return table.concat(parts, "&")
end

-- Simple data deserialization
function IGW_Sync:DeserializeData(dataStr)
    if not dataStr or dataStr == "" then return nil end
    
    -- Check if it's a simple value (no & or =)
    if not string.find(dataStr, "&") and not string.find(dataStr, "=") then
        return dataStr
    end
    
    local data = {}
    local pairs = {}
    local currentPair = ""
    
    -- Split by & 
    for i = 1, string.len(dataStr) do
        local char = string.sub(dataStr, i, i)
        if char == "&" then
            table.insert(pairs, currentPair)
            currentPair = ""
        else
            currentPair = currentPair .. char
        end
    end
    if currentPair ~= "" then
        table.insert(pairs, currentPair)
    end
    
    -- Parse each key=value pair
    for _, pair in ipairs(pairs) do
        local eqPos = string.find(pair, "=")
        if eqPos then
            local key = string.sub(pair, 1, eqPos - 1)
            local value = string.sub(pair, eqPos + 1)
            data[key] = value
        end
    end
    
    return data
end

-- Handle handshake from peer
function IGW_Sync:HandleHandshake(sender, data)
    IGW_Sync:DebugPrint("HandleHandshake from " .. sender)
    
    -- Check if this is a new peer
    local isNewPeer = not self.data.peers[sender]
    
    -- Record peer
    self.data.peers[sender] = {
        version = data and data.version or "unknown",
        protocol = data and data.protocol or 0,
        lastSeen = time()
    }
    
    -- Show message for new peers
    if isNewPeer then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Connected to " .. sender)
        
        -- Send handshake response (only once for new peers)
        IGW_Sync:DebugPrint("Sending handshake response to " .. sender)
        self:SendMessageTo(self.MSG_TYPE.HANDSHAKE, {
            version = self.VERSION,
            protocol = self.PROTOCOL_VERSION
        }, sender)
    else
        -- Just update lastSeen for known peers
        IGW_Sync:DebugPrint("Updated lastSeen for known peer " .. sender)
        self.data.peers[sender].lastSeen = time()
    end
    
    -- Check if WE need data (regardless of whether sender is new or not)
    -- If we're missing schedule or announcements, request from this peer
    self:RequestDataFromPeer(sender)
end

-- Request data from a peer (used when we're new or missing data)
function IGW_Sync:RequestDataFromPeer(peerName)
    -- Only request if we're missing data
    local needsSchedule = not self.data.raidSchedule or self:IsScheduleEmpty()
    local needsAnnouncements = not self.data.announcements or table.getn(self.data.announcements) == 0
    
    -- Check if we already requested (to avoid spamming multiple peers)
    if not self.dataRequested then
        self.dataRequested = {}
    end
    
    if needsSchedule or needsAnnouncements then
        -- Only request from first available peer, not every peer
        if not self.dataRequested.schedule and needsSchedule then
            self.dataRequested.schedule = true
            self:SendDataRequest(peerName, "schedule")
        end
        
        if not self.dataRequested.announcements and needsAnnouncements then
            self.dataRequested.announcements = true
            self:SendDataRequest(peerName, "announcements")
        end
    end
end

-- Actually send the data request with delay
function IGW_Sync:SendDataRequest(peerName, dataType)
    -- Random delay 1-3 seconds to stagger requests
    local delay = 1 + math.random() * 2
    
    local requestFrame = CreateFrame("Frame")
    requestFrame.timer = delay
    requestFrame.peer = peerName
    requestFrame.dataType = dataType
    
    requestFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = self.timer - elapsed
        if self.timer <= 0 then
            if self.dataType == "schedule" then
                IGW_Sync:DebugPrint("Requesting schedule from " .. self.peer)
                IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.REQUEST_SCHEDULE, nil, self.peer)
            elseif self.dataType == "announcements" then
                IGW_Sync:DebugPrint("Requesting announcements from " .. self.peer)
                IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.REQUEST_ANNOUNCEMENTS, nil, self.peer)
            end
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Check if schedule is empty
function IGW_Sync:IsScheduleEmpty()
    if not self.data.raidSchedule then return true end
    
    local days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
    for _, day in ipairs(days) do
        if self.data.raidSchedule[day] then
            for i = 1, 2 do
                if self.data.raidSchedule[day][i] and 
                   self.data.raidSchedule[day][i].name and 
                   self.data.raidSchedule[day][i].name ~= "" then
                    return false
                end
            end
        end
    end
    return true
end

-- Handle ping
function IGW_Sync:HandlePing(sender)
    self:SendMessageTo(self.MSG_TYPE.PONG, nil, sender)
end

-- Handle pong
function IGW_Sync:HandlePong(sender)
    if self.data.peers[sender] then
        self.data.peers[sender].lastSeen = time()
    end
end

-- Schedule handshake on login
function IGW_Sync:ScheduleHandshake()
    IGW_Sync:DebugPrint("ScheduleHandshake called - waiting 3 seconds")
    -- Wait 3 seconds after login to send handshake
    self.handshakeTimer = 3
    self.handshakeFrame = CreateFrame("Frame")
    self.handshakeFrame:SetScript("OnUpdate", function(self, elapsed)
        IGW_Sync.handshakeTimer = IGW_Sync.handshakeTimer - elapsed
        if IGW_Sync.handshakeTimer <= 0 then
            IGW_Sync:DebugPrint("Timer expired - sending handshake now")
            IGW_Sync:SendHandshake()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Send handshake
function IGW_Sync:SendHandshake()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Sending handshake to guild...")
    IGW_Sync:DebugPrint("SendHandshake called - broadcasting to guild")
    self:SendMessage(self.MSG_TYPE.HANDSHAKE, {
        version = self.VERSION,
        protocol = self.PROTOCOL_VERSION
    })
    IGW_Sync:DebugPrint("Handshake broadcast complete")
end

-- Handle guild roster update
function IGW_Sync:OnGuildRosterUpdate()
    -- Clean up offline peers
    local now = time()
    for name, peer in pairs(self.data.peers) do
        if now - peer.lastSeen > 300 then -- 5 minutes timeout
            self.data.peers[name] = nil
        end
    end
end

-- Handle player entering world
function IGW_Sync:OnPlayerEnteringWorld()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Player entering world - will send handshake in 3 seconds")
    IGW_Sync:DebugPrint("PLAYER_ENTERING_WORLD event - scheduling handshake")
    self:ScheduleHandshake()
    
    -- After handshake, broadcast our schedule if we have one (after 5 seconds)
    -- This ensures everyone gets the latest schedule
    if not self:IsScheduleEmpty() then
        local broadcastTimer = 5
        local broadcastFrame = CreateFrame("Frame")
        broadcastFrame:SetScript("OnUpdate", function(self, elapsed)
            broadcastTimer = broadcastTimer - elapsed
            if broadcastTimer <= 0 then
                IGW_Sync:DebugPrint("Broadcasting our schedule to guild after login")
                local encoded = IGW_Sync:EncodeRaidSchedule(IGW_Sync.data.raidSchedule)
                local timestamp = IGW_Sync.data.raidScheduleTimestamp or 0
                IGW_Sync:SendMessage(IGW_Sync.MSG_TYPE.RAID_SCHEDULE, {
                    encoded = encoded,
                    timestamp = timestamp
                })
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

--[[
    PUBLIC API - Announcements
]]

-- Post announcement
function IGW_Sync:PostAnnouncement(message, priority)
    local announcement = {
        id = self:GenerateEventID(),
        message = message,
        priority = priority or "normal",
        author = UnitName("player"),
        timestamp = time()
    }
    
    table.insert(self.data.announcements, 1, announcement) -- Insert at beginning
    
    -- Keep only last 20 announcements
    while table.getn(self.data.announcements) > 20 do
        table.remove(self.data.announcements)
    end
    
    self:SaveData()
    self:SendMessage(self.MSG_TYPE.ANNOUNCEMENT, announcement)
    
    return announcement.id
end

-- Get announcements
function IGW_Sync:GetAnnouncements(limit)
    if limit and limit > 0 then
        local limited = {}
        for i = 1, math.min(limit, table.getn(self.data.announcements)) do
            table.insert(limited, self.data.announcements[i])
        end
        return limited
    end
    return self.data.announcements
end

-- Clear all announcements
function IGW_Sync:ClearAnnouncements()
    self.data.announcements = {}
    self:SaveData()
end

-- Clear all announcements guild-wide (officers only)
function IGW_Sync:ClearAnnouncementsGuildWide()
    -- Clear local announcements
    self:ClearAnnouncements()
    
    -- Broadcast clear command
    self:SendMessage(self.MSG_TYPE.CLEAR_ANN, { officer = UnitName("player") })
end

-- Handle clear announcements command
function IGW_Sync:HandleClearAnnouncements(sender, data)
    -- Clear local announcements
    self.data.announcements = {}
    self:SaveData()
    
    -- Show notification
    local officerName = data and data.officer or sender
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[IGW]|r " .. officerName .. " cleared all guild announcements")
    
    -- Refresh Page 5 if open
    if IGW and IGW.infoFrame and IGW.infoFrame.currentPage == 5 then
        IGW:UpdateEventsPage()
    end
end

-- Handle incoming announcement
function IGW_Sync:HandleAnnouncement(sender, data)
    if not data or not data.id then return end
    
    -- Check if already have this announcement
    for _, ann in ipairs(self.data.announcements) do
        if ann.id == data.id then
            return
        end
    end
    
    table.insert(self.data.announcements, 1, data)
    
    -- Keep only last 20
    while table.getn(self.data.announcements) > 20 do
        table.remove(self.data.announcements)
    end
    
    self:SaveData()
    
    -- Reset request flag since we now have data
    if self.dataRequested then
        self.dataRequested.announcements = false
    end
    
    -- Show notification
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Guild Announcement]|r " .. data.message)
    
    -- Check for new announcements (show notification button)
    if IGW and IGW.CheckForNewAnnouncements then
        IGW:CheckForNewAnnouncements()
    end
    
    -- Refresh Page 5 if it exists (regardless of visibility)
    if IGW and IGW.UpdateEventsPage then
        IGW:UpdateEventsPage()
    end
    
    -- Notify UI
    if IGW and IGW.RefreshGuildInfo then
        IGW:RefreshGuildInfo()
    end
end

--[[
    PUBLIC API - Raid Schedule
]]

-- Update raid schedule (officers only)
function IGW_Sync:UpdateRaidSchedule(schedule)
    IGW_Sync:DebugPrint("UpdateRaidSchedule called")
    
    -- Add timestamp to schedule
    local timestamp = time()
    
    self.data.raidSchedule = schedule
    self.data.raidScheduleTimestamp = timestamp
    self:SaveData()
    
    IGW_Sync:DebugPrint("Saved to local data, encoding for broadcast...")
    
    -- Encode schedule for transmission
    local encoded = self:EncodeRaidSchedule(schedule)
    IGW_Sync:DebugPrint("Encoded schedule: " .. encoded)
    
    -- Broadcast to guild with timestamp
    self:SendMessage(self.MSG_TYPE.RAID_SCHEDULE, { 
        encoded = encoded,
        timestamp = timestamp 
    })
    
    IGW_Sync:DebugPrint("Broadcast complete with timestamp: " .. timestamp)
end

-- Encode raid schedule to string (handles 2 raids per day)
-- Format: Day1:Raid1Name,Raid1Time:Raid2Name,Raid2Time;Day2:...
-- Uses simple character substitution to avoid special chars
function IGW_Sync:EncodeRaidSchedule(schedule)
    local parts = {}
    local days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
    
    for _, day in ipairs(days) do
        if schedule[day] and type(schedule[day]) == "table" then
            local dayParts = {}
            for raidNum = 1, 2 do
                if schedule[day][raidNum] and schedule[day][raidNum].name and schedule[day][raidNum].name ~= "" then
                    local name = schedule[day][raidNum].name or ""
                    local time = schedule[day][raidNum].time or ""
                    -- No escaping needed, just concatenate with comma
                    table.insert(dayParts, name .. "," .. time)
                else
                    table.insert(dayParts, "") -- Empty slot
                end
            end
            -- Only add day if it has at least one raid
            if dayParts[1] ~= "" or dayParts[2] ~= "" then
                table.insert(parts, day .. ":" .. table.concat(dayParts, ":"))
            end
        end
    end
    
    return table.concat(parts, ";")
end

-- Decode raid schedule from string
function IGW_Sync:DecodeRaidSchedule(encoded)
    if not encoded or encoded == "" then
        IGW_Sync:DebugPrint("DecodeRaidSchedule: empty input")
        return {}
    end
    
    IGW_Sync:DebugPrint("DecodeRaidSchedule: input = " .. encoded)
    
    local schedule = {}
    local days = {}
    
    -- Split by semicolon (days separator)
    local dayStart = 1
    while true do
        local semicolonPos = string.find(encoded, ";", dayStart)
        local dayStr
        if semicolonPos then
            dayStr = string.sub(encoded, dayStart, semicolonPos - 1)
            dayStart = semicolonPos + 1
        else
            dayStr = string.sub(encoded, dayStart)
        end
        
        if dayStr and dayStr ~= "" then
            IGW_Sync:DebugPrint("DecodeRaidSchedule: found day string = " .. dayStr)
            table.insert(days, dayStr)
        end
        
        if not semicolonPos then break end
    end
    
    IGW_Sync:DebugPrint("DecodeRaidSchedule: total days found = " .. table.getn(days))
    
    -- Parse each day
    for _, dayStr in ipairs(days) do
        local colonPos = string.find(dayStr, ":")
        if colonPos then
            local day = string.sub(dayStr, 1, colonPos - 1)
            local raidsStr = string.sub(dayStr, colonPos + 1)
            
            IGW_Sync:DebugPrint("DecodeRaidSchedule: parsing day = " .. day .. ", raidsStr = " .. raidsStr)
            
            -- Split raids by colon
            schedule[day] = {}
            local raidNum = 1
            local raidStart = 1
            
            while raidNum <= 2 do
                local nextColon = string.find(raidsStr, ":", raidStart)
                local raidStr
                
                if nextColon then
                    raidStr = string.sub(raidsStr, raidStart, nextColon - 1)
                    raidStart = nextColon + 1
                else
                    raidStr = string.sub(raidsStr, raidStart)
                end
                
                IGW_Sync:DebugPrint("DecodeRaidSchedule: raid #" .. raidNum .. " string = '" .. (raidStr or "nil") .. "'")
                
                if raidStr and raidStr ~= "" then
                    local commaPos = string.find(raidStr, ",")
                    if commaPos then
                        local name = string.sub(raidStr, 1, commaPos - 1)
                        local time = string.sub(raidStr, commaPos + 1)
                        IGW_Sync:DebugPrint("DecodeRaidSchedule: decoded raid = " .. name .. " @ " .. time)
                        schedule[day][raidNum] = { name = name, time = time }
                    else
                        IGW_Sync:DebugPrint("DecodeRaidSchedule: no comma found in raid string")
                    end
                end
                
                raidNum = raidNum + 1
                if not nextColon then break end
            end
        end
    end
    
    return schedule
end

-- Decode raid schedule from string
-- Handle incoming raid schedule update
function IGW_Sync:HandleRaidSchedule(sender, data)
    IGW_Sync:DebugPrint("HandleRaidSchedule called")
    IGW_Sync:DebugPrint("data type: " .. type(data))
    
    if type(data) == "table" then
        IGW_Sync:DebugPrint("data keys:")
        for k, v in pairs(data) do
            IGW_Sync:DebugPrint("  " .. k .. " = " .. tostring(v))
        end
    elseif type(data) == "string" then
        IGW_Sync:DebugPrint("data string value: " .. data)
    end
    
    if not data or not data.encoded then 
        IGW_Sync:DebugPrint("HandleRaidSchedule - no encoded data, data=" .. tostring(data))
        return 
    end
    
    IGW_Sync:DebugPrint("Received schedule from " .. sender .. ": " .. data.encoded)
    
    -- Decode the schedule
    IGW_Sync:DebugPrint("About to call DecodeRaidSchedule...")
    local success, schedule = pcall(function() 
        return self:DecodeRaidSchedule(data.encoded) 
    end)
    
    if not success then
        IGW_Sync:DebugPrint("ERROR in DecodeRaidSchedule: " .. tostring(schedule))
        return
    end
    
    IGW_Sync:DebugPrint("DecodeRaidSchedule returned, schedule type: " .. type(schedule))
    
    -- Check timestamp - only accept if newer than our current schedule
    local incomingTimestamp = tonumber(data.timestamp) or 0
    local currentTimestamp = tonumber(self.data.raidScheduleTimestamp) or 0
    
    IGW_Sync:DebugPrint("Incoming timestamp: " .. incomingTimestamp)
    IGW_Sync:DebugPrint("Current timestamp: " .. currentTimestamp)
    
    if incomingTimestamp <= currentTimestamp then
        IGW_Sync:DebugPrint("Ignoring older/same schedule from " .. sender)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Ignoring older raid schedule from " .. sender)
        return
    end
    
    -- Debug: Show what was decoded
    IGW_Sync:DebugPrint("Decoded schedule (newer):")
    if type(schedule) == "table" then
        local count = 0
        for day, raids in pairs(schedule) do
            count = count + 1
            IGW_Sync:DebugPrint("  " .. day .. ":")
            for raidNum, raid in pairs(raids) do
                IGW_Sync:DebugPrint("    [" .. raidNum .. "] " .. raid.name .. " @ " .. raid.time)
            end
        end
        IGW_Sync:DebugPrint("Total days in schedule: " .. count)
    else
        IGW_Sync:DebugPrint("Schedule is not a table!")
    end
    
    self.data.raidSchedule = schedule
    self.data.raidScheduleTimestamp = incomingTimestamp
    self:SaveData()
    
    -- Reset request flag since we now have data
    if self.dataRequested then
        self.dataRequested.schedule = false
    end
    
    IGW_Sync:DebugPrint("Schedule saved to self.data.raidSchedule")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r " .. sender .. " updated the raid schedule")
    
    -- Refresh Page 5 if it exists (regardless of visibility)
    if IGW and IGW.UpdateEventsPage then
        IGW_Sync:DebugPrint("Refreshing Page 5...")
        IGW:UpdateEventsPage()
    else
        IGW_Sync:DebugPrint("IGW or UpdateEventsPage not available")
    end
end

--[[
    PUBLIC API - Officer Contacts
]]

-- Update officer contact info
function IGW_Sync:UpdateOfficerContact(info)
    self.data.officerContacts[UnitName("player")] = {
        discord = info.discord,
        notes = info.notes,
        updated = time()
    }
    
    self:SaveData()
    self:SendMessage(self.MSG_TYPE.OFFICER_INFO, {
        player = UnitName("player"),
        info = self.data.officerContacts[UnitName("player")]
    })
end

-- Get officer contacts
function IGW_Sync:GetOfficerContacts()
    return self.data.officerContacts
end

-- Handle incoming officer info
function IGW_Sync:HandleOfficerInfo(sender, data)
    if not data or not data.player or not data.info then return end
    
    self.data.officerContacts[data.player] = data.info
    self:SaveData()
    
    -- Notify UI
    if IGW and IGW.RefreshGuildInfo then
        IGW:RefreshGuildInfo()
    end
end

--[[
    PUBLIC API - Guild Bank
]]

-- Update guild bank inventory
function IGW_Sync:UpdateBankItem(item, quantity)
    self.data.guildBank[item] = {
        quantity = quantity,
        updatedBy = UnitName("player"),
        updated = time()
    }
    
    self:SaveData()
    self:SendMessage(self.MSG_TYPE.BANK_UPDATE, {
        item = item,
        quantity = quantity
    })
end

-- Get guild bank inventory
function IGW_Sync:GetBankInventory()
    return self.data.guildBank
end

-- Handle incoming bank update
function IGW_Sync:HandleBankUpdate(sender, data)
    if not data or not data.item then return end
    
    self.data.guildBank[data.item] = {
        quantity = data.quantity or 0,
        updatedBy = sender,
        updated = time()
    }
    
    self:SaveData()
    
    -- Notify UI
    if IGW and IGW.RefreshGuildInfo then
        IGW:RefreshGuildInfo()
    end
end

--[[
    Data Request/Sync
]]

-- Request full data sync
function IGW_Sync:RequestDataSync()
    -- Rate limit: once per minute
    local now = time()
    if self.lastSyncRequest and (now - self.lastSyncRequest) < 60 then
        local waitTime = 60 - (now - self.lastSyncRequest)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW Sync]|r Please wait " .. waitTime .. " seconds before requesting sync again")
        return
    end
    
    self.lastSyncRequest = now
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Requesting data sync from all peers...")
    self:SendMessage(self.MSG_TYPE.REQUEST_DATA)
end

-- Handle data request
function IGW_Sync:HandleDataRequest(sender)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r " .. sender .. " requested data sync")
    
    -- Track pending sync responses
    if not self.pendingSyncResponses then
        self.pendingSyncResponses = {}
    end
    
    -- Create unique request ID (sender + timestamp)
    local requestId = sender .. "_" .. time()
    
    -- Add random delay 0-2 seconds to stagger responses
    local delay = math.random() * 2
    
    -- Create delayed response frame
    local responseFrame = CreateFrame("Frame")
    responseFrame.timer = 0
    responseFrame.requestId = requestId
    responseFrame.sender = sender
    
    self.pendingSyncResponses[requestId] = responseFrame
    
    responseFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = self.timer + elapsed
        
        if self.timer >= delay then
            -- Check if this request was already answered by someone else
            if IGW_Sync.pendingSyncResponses[self.requestId] then
                -- Send response
                IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.SYNC_DATA, { ack = "1" }, self.sender)
                
                -- Clean up
                IGW_Sync.pendingSyncResponses[self.requestId] = nil
                self:SetScript("OnUpdate", nil)
            else
                -- Request was already answered, cancel our response
                self:SetScript("OnUpdate", nil)
            end
        end
    end)
end

-- Handle sync data
function IGW_Sync:HandleSyncData(sender, data)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Sync completed with " .. sender)
    
    -- Update last sync timestamp
    self.data.lastSync = time()
    self:SaveData()
    
    -- Cancel all pending responses to this sync request
    -- (someone already responded, no need for everyone to respond)
    if self.pendingSyncResponses then
        for requestId, frame in pairs(self.pendingSyncResponses) do
            -- Cancel all pending responses
            if frame and frame.SetScript then
                frame:SetScript("OnUpdate", nil)
            end
            self.pendingSyncResponses[requestId] = nil
        end
    end
end

--[[
    Utility Functions
]]

-- Generate unique event ID
function IGW_Sync:GenerateEventID()
    local player = UnitName("player")
    local timestamp = time()
    local random = math.random(1000, 9999)
    return player .. "_" .. timestamp .. "_" .. random
end

-- Save data to SavedVariables
function IGW_Sync:SaveData()
    if not IGW_SyncDB then
        IGW_SyncDB = {}
    end
    
    IGW_SyncDB.announcements = self.data.announcements
    IGW_SyncDB.officerContacts = self.data.officerContacts
    IGW_SyncDB.guildBank = self.data.guildBank
    IGW_SyncDB.raidSchedule = self.data.raidSchedule
    IGW_SyncDB.raidScheduleTimestamp = self.data.raidScheduleTimestamp
    IGW_SyncDB.lastSync = self.data.lastSync
end

-- Load data from SavedVariables
function IGW_Sync:LoadData()
    if IGW_SyncDB then
        self.data.announcements = IGW_SyncDB.announcements or {}
        self.data.officerContacts = IGW_SyncDB.officerContacts or {}
        self.data.guildBank = IGW_SyncDB.guildBank or {}
        self.data.raidSchedule = IGW_SyncDB.raidSchedule or {}
        self.data.raidScheduleTimestamp = IGW_SyncDB.raidScheduleTimestamp or 0
        self.data.lastSync = IGW_SyncDB.lastSync or 0
    end
end

-- Get peer count
function IGW_Sync:GetPeerCount()
    local count = 0
    for _ in pairs(self.data.peers) do
        count = count + 1
    end
    return count
end

-- Get sync status
function IGW_Sync:GetSyncStatus()
    return {
        peers = self:GetPeerCount(),
        announcements = table.getn(self.data.announcements),
        lastSync = self.data.lastSync
    }
end

-- Handle request for raid schedule only
function IGW_Sync:HandleScheduleRequest(sender)
    IGW_Sync:DebugPrint("HandleScheduleRequest from " .. sender)
    -- Only respond if we have a non-empty schedule
    if not self:IsScheduleEmpty() then
        IGW_Sync:DebugPrint("Have schedule, will respond to " .. sender)
        -- Add small random delay (0-2 sec) to stagger responses
        local delay = math.random() * 2
        
        local responseFrame = CreateFrame("Frame")
        responseFrame.timer = delay
        responseFrame.sender = sender
        
        responseFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer - elapsed
            if self.timer <= 0 then
                -- Send our current schedule with timestamp
                local encoded = IGW_Sync:EncodeRaidSchedule(IGW_Sync.data.raidSchedule)
                local timestamp = IGW_Sync.data.raidScheduleTimestamp or 0
                IGW_Sync:DebugPrint("Sending schedule to " .. self.sender .. " with timestamp " .. timestamp)
                IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.RAID_SCHEDULE, {
                    encoded = encoded,
                    timestamp = timestamp
                }, self.sender)
                self:SetScript("OnUpdate", nil)
            end
        end)
    else
        IGW_Sync:DebugPrint("Schedule is empty, not responding")
    end
end

-- Handle request for announcements only
function IGW_Sync:HandleAnnouncementsRequest(sender)
    IGW_Sync:DebugPrint("HandleAnnouncementsRequest from " .. sender)
    -- Only respond if we have announcements
    if self.data.announcements and table.getn(self.data.announcements) > 0 then
        IGW_Sync:DebugPrint("Have " .. table.getn(self.data.announcements) .. " announcements, will respond")
        -- Add small random delay (0-2 sec) to stagger responses
        local delay = math.random() * 2
        
        local responseFrame = CreateFrame("Frame")
        responseFrame.timer = delay
        responseFrame.sender = sender
        
        responseFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer - elapsed
            if self.timer <= 0 then
                -- Send most recent announcement (they'll get others over time)
                local recent = IGW_Sync.data.announcements[1]
                if recent then
                    IGW_Sync:DebugPrint("Sending announcement to " .. self.sender)
                    IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.ANNOUNCEMENT, recent, self.sender)
                end
                self:SetScript("OnUpdate", nil)
            end
        end)
    else
        IGW_Sync:DebugPrint("No announcements, not responding")
    end
end

-- Handle request for all data
function IGW_Sync:HandleAllDataRequest(sender)
    -- Send both schedule and announcement with staggered timing
    local hasSchedule = not self:IsScheduleEmpty()
    local hasAnnouncements = self.data.announcements and table.getn(self.data.announcements) > 0
    
    if hasSchedule or hasAnnouncements then
        local delay = math.random() * 2
        
        local responseFrame = CreateFrame("Frame")
        responseFrame.timer = delay
        responseFrame.sender = sender
        responseFrame.hasSchedule = hasSchedule
        responseFrame.hasAnnouncements = hasAnnouncements
        responseFrame.sentSchedule = false
        
        responseFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer - elapsed
            if self.timer <= 0 then
                -- Send schedule first
                if self.hasSchedule and not self.sentSchedule then
                    local encoded = IGW_Sync:EncodeRaidSchedule(IGW_Sync.data.raidSchedule)
                    IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.RAID_SCHEDULE, {encoded = encoded}, self.sender)
                    self.sentSchedule = true
                    self.timer = 1 -- Wait 1 more second before sending announcement
                    return
                end
                
                -- Then send announcement
                if self.hasAnnouncements then
                    local recent = IGW_Sync.data.announcements[1]
                    if recent then
                        IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.ANNOUNCEMENT, recent, self.sender)
                    end
                end
                
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Create sync frame for event handling
local syncFrame = CreateFrame("Frame", "IGW_SyncFrame")
IGW_Sync.frame = syncFrame

-- Auto-initialize when loaded
syncFrame:RegisterEvent("ADDON_LOADED")
syncFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "ImprovedGuildWindow" then
        IGW_Sync:Initialize()
    end
end)
