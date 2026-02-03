-- IGW_GuildCalendarChannel.lua
-- Simple Calendar with Guild Broadcasting

IGWCalendar = IGWCalendar or {}
IGWCalendarDB = IGWCalendarDB or { events = {} }

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function say(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Calendar]|r " .. tostring(msg))
    end
end

-- Split string by colon, preserving empty fields (unlike gfind which skips them)
local function splitColon(str)
    local parts = {}
    local pos = 1
    while pos <= string.len(str) + 1 do
        local s, e = string.find(str, ":", pos, true)
        if s then
            table.insert(parts, string.sub(str, pos, s - 1))
            pos = e + 1
        else
            table.insert(parts, string.sub(str, pos))
            break
        end
    end
    return parts
end

-- Placeholder for empty fields so they survive transmission
local EMPTY = "_"
local function packField(val)
    if not val or val == "" then return EMPTY end
    return val
end
local function unpackField(val)
    if val == EMPTY then return "" end
    return val or ""
end

------------------------------------------------------------
-- Message Queue (throttled sender)
------------------------------------------------------------
local sendQueue = {}
local sendDelay = 0.5  -- seconds between messages
local sendActive = false

-- Incoming sync burst tracking
local syncSender = nil
local syncCount = 0
local syncTimeout = 2  -- seconds of silence before printing summary
local syncTimer = 0

-- Incoming DEL burst tracking
local delSender = nil
local delCount = 0
local delTimeout = 2
local delTimer = 0

-- Sync responder: rank-based delay before responding
local pendingSyncRequester = nil   -- who asked for sync
local pendingSyncDelay = 0         -- seconds remaining before we respond
local syncReplySeen = false        -- did a higher rank already reply?

-- Sync request cooldown (prevents spam)
local syncCooldown = 0             -- seconds remaining before next sync allowed
local SYNC_COOLDOWN_TIME = 5       -- minimum seconds between sync requests

local function enqueueMessage(msg)
    table.insert(sendQueue, msg)
    sendActive = true
end

local function processSendQueue()
    if table.getn(sendQueue) == 0 then
        sendActive = false
        return
    end
    local msg = table.remove(sendQueue, 1)
    if IGWCalendar.joined then
        SendChatMessage(msg, "CHANNEL", nil, IGWCalendar.channelId)
    end
end

------------------------------------------------------------
-- Permission System
------------------------------------------------------------
local function GetPlayerRankIndex(playerName)
    if not playerName then return 10 end -- Lowest rank if not found
    
    GuildRoster()
    local numMembers = GetNumGuildMembers(true)
    
    for i = 1, numMembers do
        local name, rank, rankIndex = GetGuildRosterInfo(i)
        if name == playerName then
            return rankIndex
        end
    end
    
    return 10 -- Not found, assume lowest rank
end

local function CanCreateEvents()
    local myRank = GetPlayerRankIndex(UnitName("player"))
    -- Top 3 ranks can create (rankIndex 0, 1, 2)
    return myRank <= 2
end

local function CanDeleteEvent(event)
    if not event then return false end
    
    local myRank = GetPlayerRankIndex(UnitName("player"))
    local creatorRank = GetPlayerRankIndex(event.created_by)
    
    -- Can delete if:
    -- 1. You created it, OR
    -- 2. Your rank is higher (lower rankIndex) than creator's rank
    return (event.created_by == UnitName("player")) or (myRank < creatorRank)
end

------------------------------------------------------------
-- Channel Management
------------------------------------------------------------
IGWCalendar.channelName = nil
IGWCalendar.channelId = nil
IGWCalendar.joined = false

function IGWCalendar:GetChannelName()
    local gName = GetGuildInfo("player")
    if not gName or gName == "" then return nil end
    local clean = string.gsub(gName, "[^%w]", "")
    return "IGWCal_" .. clean
end

function IGWCalendar:JoinChannel()
    if self.joined then return true end
    
    self.channelName = self:GetChannelName()
    if not self.channelName then return false end
    
    JoinChannelByName(self.channelName)
    
    local id = GetChannelName(self.channelName)
    if id and id > 0 then
        self.channelId = id
        self.joined = true
        say("Connected to channel: " .. self.channelName)
        return true
    end
    
    return false
end

function IGWCalendar:LeaveChannel()
    if not self.joined then return end
    if self.channelName then
        LeaveChannelByName(self.channelName)
        say("Left calendar channel")
    end
    self.channelId = nil
    self.joined = false
end

------------------------------------------------------------
-- Event Operations
------------------------------------------------------------
function IGWCalendar:AddEvent(title)
    local event_id = "event_" .. string.sub(UnitName("player"), 1, 8) .. "_" .. tostring(time())
    
    local event = {
        event_id = event_id,
        title = title,
        start_ts = time() + 3600,
        end_ts = time() + 7200,
        created_by = UnitName("player")
    }
    
    IGWCalendarDB.events[event_id] = event
    
    -- Broadcast
    local msg = "ADD:" .. event_id .. ":" .. title .. ":" .. tostring(event.start_ts) .. ":" .. tostring(event.end_ts)
    enqueueMessage(msg)
    
    return true
end

function IGWCalendar:AddEventWithTime(title, start_ts, duration_min, description, eventType)
    -- Check permissions
    if not CanCreateEvents() then
        say("You don't have permission to create events (Top 3 ranks only)")
        return false
    end
    
    local event_id = "event_" .. string.sub(UnitName("player"), 1, 8) .. "_" .. tostring(time())
    
    local end_ts = start_ts + (duration_min * 60)
    
    local event = {
        event_id = event_id,
        title = title,
        description = description or "",
        event_type = eventType or "Other",
        start_ts = start_ts,
        end_ts = end_ts,
        created_by = UnitName("player"),
        creator_rank = GetPlayerRankIndex(UnitName("player"))
    }
    
    IGWCalendarDB.events[event_id] = event
    
    -- Escape description for transmission (replace colons)
    local safeDesc = string.gsub(description or "", ":", ";;")
    
    -- Broadcast with timestamps, description, and type
    local msg = "ADD:" .. event_id .. ":" .. packField(title) .. ":" .. tostring(start_ts) .. ":" .. tostring(end_ts) .. ":" .. packField(UnitName("player")) .. ":" .. tostring(event.creator_rank) .. ":" .. packField(safeDesc) .. ":" .. packField(eventType or "Other")
    enqueueMessage(msg)
    
    return true
end

function IGWCalendar:DeleteEvent(event_id)
    local event = IGWCalendarDB.events[event_id]
    
    if not event then
        say("Event not found")
        return false
    end
    
    -- Check permissions
    if not CanDeleteEvent(event) then
        say("You don't have permission to delete this event")
        return false
    end
    
    IGWCalendarDB.events[event_id] = nil
    
    local msg = "DEL:" .. event_id
    enqueueMessage(msg)
    
    return true
end

function IGWCalendar:SyncEvents()
    if syncCooldown > 0 then
        say("Sync on cooldown, try again in " .. math.ceil(syncCooldown) .. "s")
        return
    end
    local msg = "SYNC:" .. UnitName("player")
    enqueueMessage(msg)
    syncCooldown = SYNC_COOLDOWN_TIME
    say("Sync requested")
end

------------------------------------------------------------
-- Message Handler
------------------------------------------------------------
function IGWCalendar:OnChannelMessage(message, sender)
    if sender == UnitName("player") then return end
    
    -- Parse: COMMAND:data:data
    local colonPos = string.find(message, ":")
    if not colonPos then return end
    
    local cmd = string.sub(message, 1, colonPos - 1)
    local data = string.sub(message, colonPos + 1)
    
    if cmd == "ADD" then
        local parts = splitColon(data)
        
        if parts[1] and parts[2] then
            local event_id = parts[1]
            local title = unpackField(parts[2])
            local start_ts = tonumber(parts[3]) or (time() + 3600)
            local end_ts = tonumber(parts[4]) or (start_ts + 3600)
            local creator = unpackField(parts[5]) or sender
            local creator_rank = tonumber(parts[6]) or 10
            local safeDesc = unpackField(parts[7])
            local description = string.gsub(safeDesc, ";;", ":")
            local eventType = unpackField(parts[8]) or "Other"
            if eventType == "" then eventType = "Other" end
            
            IGWCalendarDB.events[event_id] = {
                event_id = event_id,
                title = title,
                description = description,
                event_type = eventType,
                start_ts = start_ts,
                end_ts = end_ts,
                created_by = creator,
                creator_rank = creator_rank
            }
            
            -- Track burst: if same sender keep counting, reset timer
            if syncSender == sender then
                syncCount = syncCount + 1
                syncTimer = syncTimeout
            else
                -- Different sender or first message — flush any previous burst summary
                if syncSender and syncCount > 0 then
                    if syncCount == 1 then
                        say("Received 1 event from " .. syncSender)
                    else
                        say("Received " .. syncCount .. " events from " .. syncSender)
                    end
                end
                syncSender = sender
                syncCount = 1
                syncTimer = syncTimeout
            end
            
            if IGWCalendarUI and IGWCalendarUI.Refresh then
                IGWCalendarUI:Refresh()
            end
        end
        
    elseif cmd == "DEL" then
        IGWCalendarDB.events[data] = nil
        
        -- Burst tracking: accumulate, print summary after silence
        if delSender == sender then
            delCount = delCount + 1
            delTimer = delTimeout
        else
            if delSender and delCount > 0 then
                if delCount == 1 then
                    say("Deleted 1 event by " .. delSender)
                else
                    say("Deleted " .. delCount .. " events by " .. delSender)
                end
            end
            delSender = sender
            delCount = 1
            delTimer = delTimeout
        end
        
        if IGWCalendarUI and IGWCalendarUI.Refresh then
            IGWCalendarUI:Refresh()
        end
        
    elseif cmd == "SYNC_START" then
        -- data = target player name. Only that player clears their DB.
        if data == UnitName("player") then
            IGWCalendarDB.events = {}
            say("Syncing — clearing local events...")
        end
        
    elseif cmd == "SYNC" then
        -- data = requester name
        local requester = data
        -- Don't respond to your own sync request
        if requester == UnitName("player") then return end
        
        -- Set up rank-based delay: rank 0 = 0.5s, rank 1 = 1.0s, rank 2 = 1.5s, etc.
        local myRank = GetPlayerRankIndex(UnitName("player"))
        pendingSyncRequester = requester
        pendingSyncDelay = 0.5 + (myRank * 0.5)
        syncReplySeen = false
        
    elseif cmd == "SYNC_REPLY" then
        -- Format: SYNC_REPLY:targetPlayer:event_id:title:start:end:creator:rank:desc:type
        local parts = splitColon(data)
        
        local target = parts[1]
        
        -- If we were waiting to respond, a higher rank beat us — cancel
        if pendingSyncRequester then
            syncReplySeen = true
        end
        
        -- Only the targeted requester processes the event data
        if target == UnitName("player") then
            if parts[2] and parts[3] then
                local event_id = parts[2]
                local title = unpackField(parts[3])
                local start_ts = tonumber(parts[4]) or (time() + 3600)
                local end_ts = tonumber(parts[5]) or (start_ts + 3600)
                local creator = unpackField(parts[6]) or sender
                local creator_rank = tonumber(parts[7]) or 10
                local safeDesc = unpackField(parts[8])
                local description = string.gsub(safeDesc, ";;", ":")
                local eventType = unpackField(parts[9]) or "Other"
                if eventType == "" then eventType = "Other" end
                
                IGWCalendarDB.events[event_id] = {
                    event_id = event_id,
                    title = title,
                    description = description,
                    event_type = eventType,
                    start_ts = start_ts,
                    end_ts = end_ts,
                    created_by = creator,
                    creator_rank = creator_rank
                }
                
                -- Burst tracking for summary message
                if syncSender == sender then
                    syncCount = syncCount + 1
                    syncTimer = syncTimeout
                else
                    if syncSender and syncCount > 0 then
                        if syncCount == 1 then
                            say("Received 1 event from " .. syncSender)
                        else
                            say("Received " .. syncCount .. " events from " .. syncSender)
                        end
                    end
                    syncSender = sender
                    syncCount = 1
                    syncTimer = syncTimeout
                end
                
                if IGWCalendarUI and IGWCalendarUI.Refresh then
                    IGWCalendarUI:Refresh()
                end
            end
        end
    end
end

------------------------------------------------------------
-- Event Registration
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_CHANNEL")

-- Ticker: handles send queue throttle and incoming sync burst summary
local sendElapsed = 0
frame:SetScript("OnUpdate", function()
    local dt = arg1
    
    -- Send queue: fire one message every sendDelay seconds
    if sendActive then
        sendElapsed = sendElapsed + dt
        if sendElapsed >= sendDelay then
            sendElapsed = 0
            processSendQueue()
        end
    end
    
    -- Sync burst timeout: print summary after silence
    if syncSender and syncCount > 0 then
        syncTimer = syncTimer - dt
        if syncTimer <= 0 then
            if syncCount == 1 then
                say("Received 1 event from " .. syncSender)
            else
                say("Received " .. syncCount .. " events from " .. syncSender)
            end
            syncSender = nil
            syncCount = 0
        end
    end
    
    -- DEL burst timeout: print summary after silence
    if delSender and delCount > 0 then
        delTimer = delTimer - dt
        if delTimer <= 0 then
            if delCount == 1 then
                say("Deleted 1 event by " .. delSender)
            else
                say("Deleted " .. delCount .. " events by " .. delSender)
            end
            delSender = nil
            delCount = 0
        end
    end
    
    -- Sync request cooldown tick
    if syncCooldown > 0 then
        syncCooldown = syncCooldown - dt
        if syncCooldown < 0 then syncCooldown = 0 end
    end
    
    -- Sync responder: count down rank-based delay, fire if no higher rank replied
    if pendingSyncRequester then
        if syncReplySeen then
            -- A higher rank already responded, bail out
            pendingSyncRequester = nil
            pendingSyncDelay = 0
        else
            pendingSyncDelay = pendingSyncDelay - dt
            if pendingSyncDelay <= 0 then
                -- We're the highest rank online — send our events targeted to requester
                local requester = pendingSyncRequester
                pendingSyncRequester = nil
                
                -- Signal requester to clear their DB before receiving events
                enqueueMessage("SYNC_START:" .. requester)
                
                local count = 0
                for id, e in pairs(IGWCalendarDB.events) do
                    local creator_rank = e.creator_rank or 10
                    local safeDesc = string.gsub(e.description or "", ":", ";;")
                    local eventType = e.event_type or "Other"
                    local msg = "SYNC_REPLY:" .. requester .. ":" .. id .. ":" .. packField(e.title) .. ":" .. tostring(e.start_ts or 0) .. ":" .. tostring(e.end_ts or 0) .. ":" .. packField(e.created_by) .. ":" .. tostring(creator_rank) .. ":" .. packField(safeDesc) .. ":" .. packField(eventType)
                    enqueueMessage(msg)
                    count = count + 1
                end
                if count > 0 then
                    say("Sending " .. count .. " events to " .. requester .. "...")
                else
                    say("No events to send")
                end
            end
        end
    end
end)

frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        -- Only auto-join if calendar is explicitly enabled
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.calendarEnabled then
            local delay = CreateFrame("Frame")
            local elapsed = 0
            delay:SetScript("OnUpdate", function()
                elapsed = elapsed + arg1
                if elapsed >= 3 then
                    IGWCalendar:JoinChannel()
                    this:SetScript("OnUpdate", nil)
                end
            end)
        end
        
    elseif event == "CHAT_MSG_CHANNEL" then
        local message = arg1
        local sender = arg2
        local channelName = arg9
        
        if IGWCalendar.channelName and channelName then
            if string.lower(channelName) == string.lower(IGWCalendar.channelName) then
                IGWCalendar:OnChannelMessage(message, sender)
            end
        end
    end
end)

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------
SLASH_IGWCAL1 = "/igwcal"
SlashCmdList["IGWCAL"] = function(msg)
    local lower = string.lower(msg or "")
    
    if lower == "join" then
        IGWCalendar:JoinChannel()
        
    elseif lower == "sync" then
        IGWCalendar:SyncEvents()
        
    elseif string.sub(lower, 1, 3) == "add" then
        local title = string.sub(msg, 5)
        if title == "" then title = "Test Event" end
        IGWCalendar:AddEvent(title)
        
    elseif lower == "list" then
        local count = 0
        say("=== Events ===")
        for id, e in pairs(IGWCalendarDB.events) do
            count = count + 1
            say(count .. ". " .. (e.title or "?") .. " by " .. (e.created_by or "?"))
        end
        if count == 0 then say("No events") end
        
    elseif lower == "clear" then
        IGWCalendarDB.events = {}
        say("Events cleared")
        
    elseif lower == "status" then
        say("Channel: " .. (IGWCalendar.channelName or "nil"))
        say("Joined: " .. tostring(IGWCalendar.joined))
        local count = 0
        for _ in pairs(IGWCalendarDB.events) do count = count + 1 end
        say("Events: " .. count)
        
    else
        say("Commands: join | add <title> | list | sync | clear | status")
    end
end

------------------------------------------------------------
-- Wrappers for UI
------------------------------------------------------------
function IGWCalendar.NewEventId()
    return "event_" .. string.sub(UnitName("player"), 1, 8) .. "_" .. tostring(time())
end

say("Calendar loaded - /igwcal for commands")
