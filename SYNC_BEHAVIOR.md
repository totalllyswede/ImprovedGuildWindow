# Guild Sync - Current Behavior

## When Does Sync Happen?

### Automatic Sync Events

#### 1. **On Login / Zone Change**
**Event:** `PLAYER_ENTERING_WORLD`
**What Happens:**
- Waits 3 seconds
- Sends a handshake to the guild
- Broadcasts: "Hi, I'm online with version X.X"
- Other addon users respond with their own handshake
- Result: You discover who else has the addon

**What Gets Synced:**
- ❌ Raid schedule - NOT automatically sent
- ❌ Announcements - NOT automatically sent
- ✅ Peer list - You see who has the addon

#### 2. **When Officer Updates Raid Schedule**
**Trigger:** Officer clicks "Save" in the Edit Schedule dialog
**What Happens:**
- Officer's client encodes the schedule
- Broadcasts to entire guild via addon message
- All guild members with the addon receive it
- Everyone's local schedule updates immediately
- Page 5 auto-refreshes if open

**What Gets Synced:**
- ✅ Complete raid schedule for all 7 days
- ✅ All raid names and times
- ❌ Announcements - not affected

#### 3. **When Officer Posts Announcement**
**Trigger:** Officer clicks "Send" in the Announce dialog
**What Happens:**
- Creates announcement with ID, timestamp, author, message
- Broadcasts to entire guild
- All members receive and store (up to 20 most recent)
- Page 5 auto-refreshes if open

**What Gets Synced:**
- ✅ New announcement
- ❌ Raid schedule - not affected

#### 4. **When Officer Clears Announcements**
**Trigger:** Officer clicks "Clear All"
**What Happens:**
- Broadcasts clear command to guild
- All members clear their local announcements
- Page 5 auto-refreshes if open

**What Gets Synced:**
- ✅ Clear command (empties everyone's announcements)
- ❌ Raid schedule - not affected

### What Does NOT Auto-Sync

#### ❌ Historical Data on Login
**Current Behavior:**
- When you log in, you send a handshake
- You DON'T automatically request the raid schedule
- You DON'T automatically request announcements

**Result:**
- New member logs in → No schedule until next officer update
- New member logs in → No announcements until next officer post

**Why This Design?**
- Prevents login flood (200 people logging in = no massive data burst)
- Officers can update on demand
- Schedule changes infrequently anyway

#### ❌ Peer-to-Peer Schedule Requests
**What Happens:**
- Members cannot request schedule from each other
- Only officers can broadcast schedule updates
- No "sync from another player" mechanism

**Why This Design?**
- Prevents conflicting schedules
- Single source of truth (officer's latest save)
- Simpler logic, no conflict resolution needed

#### ❌ Periodic Background Sync
**What Doesn't Happen:**
- No automatic "check if my data is current" polling
- No "resync every 5 minutes" mechanism
- No background keepalive messages

**Why This Design?**
- Reduces network traffic
- Schedule/announcements are low-priority data
- Updates happen when officers change things

## Current Workflow Examples

### Scenario 1: New Member Joins Guild
1. New member installs addon
2. Logs in → Sends handshake
3. Existing members respond → Peer list populated
4. **Raid schedule: EMPTY** (until next officer update)
5. **Announcements: EMPTY** (until next officer post)

**To Get Current Data:**
- Ask officer to click "Save" in Edit Schedule (re-broadcasts)
- Wait for next scheduled announcement

### Scenario 2: Officer Updates Schedule
1. Officer opens Page 5 → "Edit Schedule"
2. Changes Monday MC from 8pm to 7pm
3. Clicks "Save"
4. **ALL guild members with addon:** Schedule updates instantly
5. Page 5 refreshes if they're viewing it

### Scenario 3: Multiple Officers
1. Officer A saves schedule at 5:00pm
2. Officer B opens editor at 5:05pm
3. Officer B sees Officer A's changes (last saved version)
4. Officer B makes different changes
5. Officer B clicks "Save"
6. **Everyone gets Officer B's version** (last-write-wins)

### Scenario 4: Guild Announcement
1. Officer posts "Raid canceled tonight"
2. All members receive it instantly
3. Shows on Page 5 for everyone
4. Stored locally (up to 20 announcements)

## Data Persistence

### What Gets Saved to Disk
✅ Raid schedule (saved in `IGW_SyncDB.raidSchedule`)
✅ Announcements (saved in `IGW_SyncDB.announcements`)
✅ Peer list (saved in `IGW_SyncDB.peers`)

### What Happens After /reload or Relog
✅ Your saved raid schedule persists
✅ Your saved announcements persist
✅ Your peer list persists (but gets cleaned up if peers offline >1hr)
✅ Handshake sent again to update peer status

## Summary Table

| Event | Handshake | Raid Schedule | Announcements |
|-------|-----------|---------------|---------------|
| Player login | ✅ Sent | ❌ Not sent | ❌ Not sent |
| Officer saves schedule | ❌ | ✅ Broadcast | ❌ |
| Officer posts announcement | ❌ | ❌ | ✅ Broadcast |
| Officer clears announcements | ❌ | ❌ | ✅ Clear command |
| Guild roster update | 🔄 Cleanup | ❌ | ❌ |

## Key Design Principles

1. **Push, Not Pull** - Officers push updates, members don't pull
2. **Event-Driven** - Sync happens when data changes, not on schedule
3. **Last-Write-Wins** - No conflict resolution, latest update wins
4. **Lazy Loading** - Don't sync data until it's needed
5. **Low Traffic** - Minimize messages to avoid guild chat spam

## Future Enhancement Ideas (Optional)

### Could Add:
- "Request Schedule" button for new members
- Officer command to re-broadcast schedule
- Show "last updated" timestamp on Page 5
- "Sync All Data" button in settings

### Probably Don't Need:
- Automatic periodic sync (current design is fine)
- Conflict resolution (last-write-wins is simple and works)
- Version tracking (not worth the complexity)
