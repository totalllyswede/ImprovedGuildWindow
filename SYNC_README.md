# IGW Sync Module Documentation

## Overview

The IGW_Sync module enables real-time data synchronization between guild members using the ImprovedGuildWindow addon. It uses WoW's `SendAddonMessage` API to share events, announcements, and other guild data.

## Features

### 1. Guild Events
- Create, update, and delete guild events
- Automatically syncs events to all addon users
- Shows upcoming raids, dungeons, PvP events
- Officers can manage events through UI

### 2. Guild Announcements
- Post announcements visible to all addon users
- Shows recent announcements in Guild Info panel
- Automatic notification when new announcements arrive
- Keeps last 20 announcements

### 3. Officer Contact Information
- Officers can share Discord/contact info
- Automatically syncs to all guild members
- Shows in Guild Info panel

### 4. Guild Bank Tracking (Optional)
- Track guild bank inventory
- Sync item quantities between officers
- Show what materials are available

### 5. Peer Detection
- Automatically detects other addon users
- Shows how many guild members have addon
- Maintains connection list

## Installation

The sync module is automatically loaded with ImprovedGuildWindow v3.2+.

**Files:**
- `IGW_Sync.lua` - Core sync module
- `IGW_SyncUI_Example.lua` - Example UI integration (reference only)

**SavedVariables:**
- `IGW_SyncDB` - Stores synced data between sessions

## API Reference

### Events

#### Add Event
```lua
local eventID = IGW_Sync:AddEvent({
    name = "MC Raid",
    timestamp = os.time({year=2025, month=4, day=15, hour=19, min=0}),
    description = "Weekly Molten Core clear",
    type = "raid" -- optional
})
```

#### Update Event
```lua
IGW_Sync:UpdateEvent(eventID, {
    description = "MC Raid - Need more healers!"
})
```

#### Delete Event
```lua
IGW_Sync:DeleteEvent(eventID)
```

#### Get Events
```lua
-- Get all events
local events = IGW_Sync:GetEvents()

-- Get upcoming events (limit to 5)
local upcoming = IGW_Sync:GetUpcomingEvents(5)

-- Event structure:
-- {
--   id = "PlayerName_1234567890_1234",
--   name = "MC Raid",
--   timestamp = 1234567890,
--   description = "Weekly clear",
--   creator = "PlayerName",
--   created = 1234567890
-- }
```

### Announcements

#### Post Announcement
```lua
IGW_Sync:PostAnnouncement("Guild meeting tonight at 8pm!", "important")
```

#### Get Announcements
```lua
-- Get last 5 announcements
local announcements = IGW_Sync:GetAnnouncements(5)

-- Announcement structure:
-- {
--   id = "unique_id",
--   message = "Guild meeting tonight!",
--   priority = "normal", -- or "important"
--   author = "PlayerName",
--   timestamp = 1234567890
-- }
```

### Officer Contacts

#### Update Contact Info
```lua
IGW_Sync:UpdateOfficerContact({
    discord = "Username#1234",
    notes = "Main raid leader"
})
```

#### Get All Contacts
```lua
local contacts = IGW_Sync:GetOfficerContacts()
-- Returns: { PlayerName = { discord = "...", notes = "...", updated = timestamp } }
```

### Guild Bank

#### Update Item Quantity
```lua
IGW_Sync:UpdateBankItem("Core Leather", 250)
```

#### Get Inventory
```lua
local inventory = IGW_Sync:GetBankInventory()
-- Returns: { ItemName = { quantity = 250, updatedBy = "PlayerName", updated = timestamp } }
```

### Utility Functions

#### Get Sync Status
```lua
local status = IGW_Sync:GetSyncStatus()
-- Returns: { peers = 5, events = 3, announcements = 2, lastSync = timestamp }
```

#### Get Peer Count
```lua
local count = IGW_Sync:GetPeerCount()
```

#### Request Data Sync
```lua
IGW_Sync:RequestDataSync()
```

## Slash Commands

Add these to your addon's slash command handler:

### Check Sync Status
```
/igw sync status
```
Shows connected peers, event count, announcement count, last sync time.

### Post Announcement
```
/igw announce Your message here
```
Broadcasts announcement to all addon users.

### Request Sync
```
/igw sync refresh
```
Requests full data sync from other addon users.

## UI Integration Example

### Add Events Page to Guild Info

```lua
function IGW:CreateGuildInfoPage5()
    if not IGW_Sync then return end
    
    -- Get upcoming events
    local events = IGW_Sync:GetUpcomingEvents(5)
    
    -- Display events
    for _, event in ipairs(events) do
        -- Show event.name, event.timestamp, event.description
    end
    
    -- Get announcements
    local announcements = IGW_Sync:GetAnnouncements(3)
    
    -- Display announcements
    for _, ann in ipairs(announcements) do
        -- Show ann.message, ann.author, ann.timestamp
    end
end
```

See `IGW_SyncUI_Example.lua` for complete implementation.

## How It Works

### Message Protocol

The sync module uses a simple text-based protocol:

**Format:** `TYPE:key1=value1&key2=value2`

**Message Types:**
- `HS` - Handshake (initial connection)
- `PING/PONG` - Keep-alive
- `EVTA` - Add event
- `EVTU` - Update event
- `EVTD` - Delete event
- `ANN` - Announcement
- `OFC` - Officer contact info
- `BANK` - Guild bank update
- `REQ` - Request data sync
- `SYNC` - Full data sync

### Data Flow

1. **Player A creates event** → `IGW_Sync:AddEvent()`
2. **Event saved locally** → `IGW_SyncDB.events`
3. **Message broadcast** → `SendAddonMessage("IGW_SYNC", "EVTA:name=MC Raid&...", "GUILD")`
4. **Player B receives** → `CHAT_MSG_ADDON` event
5. **Event added to Player B's data** → `IGW_SyncDB.events`
6. **UI updated** → `IGW:RefreshGuildInfo()`

### Security Considerations

**What's Safe:**
- Events, announcements, contact info
- Guild bank inventory (officers only)
- Public guild information

**What to Avoid:**
- DKP values (should be officer-only)
- Private/sensitive information
- Account credentials
- Personal details

### Performance

**Message Limits:**
- Max 255 characters per message
- Rate limited by WoW client
- Large data sets split into multiple messages

**Best Practices:**
- Keep event descriptions under 100 characters
- Limit announcements to 150 characters
- Use officer whispers for sensitive data
- Batch updates when possible

## Troubleshooting

### No Peers Connected
- Verify addon is loaded: `/igw sync status`
- Check if others have addon installed
- Try `/reload` to reinitialize
- Wait 10 seconds after login for handshake

### Events Not Syncing
- Check addon message prefix is registered
- Verify `IGW_SyncDB` exists in SavedVariables
- Try manual sync: `/igw sync refresh`
- Check for Lua errors: `/console scriptErrors 1`

### Data Loss
- Data is saved in `IGW_SyncDB`
- Survives `/reload` and logout
- Manual backup: Copy `SavedVariables/ImprovedGuildWindow.lua`

## Future Enhancements

Planned features:
- Raid signup system
- Loot wishlist sharing
- DKP integration
- Attunement tracking
- Consumable tracking
- Encrypted officer channels

## Version History

**v1.0** (Current)
- Event creation and syncing
- Guild announcements
- Officer contacts
- Guild bank tracking
- Peer detection
- Basic UI integration

## Support

For bugs or feature requests, contact the addon author or post in guild Discord.

## License

Part of ImprovedGuildWindow addon by Olzon.
