# IGW_Sync Scaling Analysis

## Current Behavior (Good ✅ and Concerns ⚠️)

### On Login / Player Joins
**What happens:**
1. Player logs in
2. After 3 seconds, sends ONE handshake to GUILD channel
3. All online addon users receive it
4. Each peer checks: "Is this a new peer?"
   - If YES → Send handshake response (also to GUILD)
   - If NO → Silently update lastSeen timestamp

**With 50 players:**
- Player A logs in → 1 handshake sent
- 49 existing players receive it
- 49 handshake responses sent back (because Player A is new to all of them)
- Player A receives 49 handshakes
- **Total: 50 messages** ✅ Linear scaling, happens once

### Announcements
**What happens:**
1. Officer posts announcement: `/igw announce <message>`
2. ONE message broadcast to GUILD
3. All addon users receive and store it (max 20 kept)

**With 50 players:**
- 1 announcement → 1 GUILD message
- All 50 players receive it
- **Total: 1 message** ✅ Efficient

### Sync Refresh (`/igw sync refresh`)
**What happens:**
1. Player runs command
2. ONE REQUEST_DATA message to GUILD
3. All peers receive request
4. **PROBLEM:** Each peer sends SYNC_DATA response to GUILD ⚠️

**With 50 players:**
- Player A requests sync
- 1 REQUEST_DATA sent
- 49 peers each send SYNC_DATA response
- **Total: 50 messages** ⚠️ All at once!

### Clear Announcements Guild-Wide
**What happens:**
1. Officer runs: `/igw clearann guild`
2. ONE CLEAR_ANN message to GUILD
3. All players clear their announcements

**With 50 players:**
- 1 message clears all
- **Total: 1 message** ✅ Efficient

### Peer Timeout Cleanup
**What happens:**
- Every GUILD_ROSTER_UPDATE event
- Checks all peers for 5-minute timeout
- Removes stale entries

**With 50 players:**
- Memory usage: ~50 peer entries (tiny)
- **No network traffic** ✅

---

## Potential Issues with Scale

### ⚠️ Issue #1: Sync Request Storm
**Problem:** When someone runs `/igw sync refresh`, all 49 other players respond immediately.

**Impact with 50 players:**
- 49 SYNC_DATA messages sent at once
- Could cause brief lag spike
- Currently SYNC_DATA contains only acknowledgment, but still wasteful

**Solutions:**
1. **Add random delay** (0-2 seconds) before responding to sync request
2. **Remove sync feature entirely** (not really needed since handshakes handle peer discovery)
3. **Rate limit** sync requests to once per minute

### ⚠️ Issue #2: Multiple Handshakes on Roster Update
**Problem:** GUILD_ROSTER_UPDATE fires frequently (every time someone joins/leaves, rank changes, etc.)

**Current behavior:** Only cleanup, no messages ✅

### ⚠️ Issue #3: Message Size Limit
**Current limit:** 255 characters per addon message (WoW 1.12.1)

**Current messages:**
- Handshake: ~20 chars ✅
- Announcement: Variable (user input) ⚠️ Could hit limit
- SYNC_DATA: ~10 chars ✅

**Risk:** Long announcements (>200 chars) might get truncated

---

## Recommendations

### High Priority Fixes

#### 1. Add Staggered Response to Sync Requests
```lua
function IGW_Sync:HandleDataRequest(sender)
    -- Random delay 0-2 seconds
    local delay = math.random() * 2
    CreateFrame("Frame"):SetScript("OnUpdate", function()
        this.timer = (this.timer or 0) + arg1
        if this.timer >= delay then
            IGW_Sync:SendMessageTo(IGW_Sync.MSG_TYPE.SYNC_DATA, { ack = "1" }, sender)
            this:SetScript("OnUpdate", nil)
        end
    end)
end
```

#### 2. Truncate Long Announcements
```lua
function IGW_Sync:PostAnnouncement(message, priority)
    -- Limit to 200 chars to stay under 255 limit with protocol overhead
    if string.len(message) > 200 then
        message = string.sub(message, 1, 197) .. "..."
    end
    -- ... rest of function
end
```

#### 3. Rate Limit Sync Requests
```lua
function IGW_Sync:RequestDataSync()
    local now = time()
    if self.lastSyncRequest and (now - self.lastSyncRequest) < 60 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW Sync]|r Please wait before requesting sync again")
        return
    end
    self.lastSyncRequest = now
    -- ... rest of function
end
```

### Medium Priority

#### 4. Consider Removing Sync Feature
- Peers are already discovered via handshakes
- Sync request doesn't actually transfer data anymore (events removed)
- Only sends acknowledgments
- **Recommendation:** Remove `/igw sync refresh` and SYNC_DATA entirely

#### 5. Add Message Deduplication
- Track message IDs for announcements
- Ignore duplicates (in case of message replay)

---

## Current Limits

| Metric | Current Value | Notes |
|--------|---------------|-------|
| Max message size | 255 chars | WoW 1.12.1 limit |
| Announcement history | 20 | Configurable |
| Peer timeout | 5 minutes | Reasonable |
| Handshake delay on login | 3 seconds | Prevents login spam |
| Messages per announcement | 1 | Efficient ✅ |
| Messages per sync request | N (# of peers) | Problem ⚠️ |

---

## Stress Test Scenarios

### Scenario 1: 10 players online, 5 log in at once
- 5 handshakes sent (staggered by 3 seconds each)
- Each gets 9 responses
- Total: 5 + (5 × 9) = 50 messages over 15 seconds
- **Result: Fine** ✅

### Scenario 2: 50 players online, officer posts announcement
- 1 announcement message
- 50 players receive it
- **Result: Perfect** ✅

### Scenario 3: 50 players online, someone runs sync refresh
- 1 REQUEST_DATA
- 49 SYNC_DATA responses **all at once**
- **Result: Potential lag spike** ⚠️

### Scenario 4: 50 players online, 10 log in simultaneously
- 10 handshakes sent (all after 3 second delay)
- Each gets 49 responses
- Total: 10 + (10 × 49) = 500 messages in ~1 second
- **Result: Could cause issues** ⚠️⚠️

---

## Conclusion

**Current system is mostly well-designed for scale**, but has two potential issues:

1. **Sync request responses** - All peers respond at once
2. **Mass login** - Many players logging in simultaneously could spam handshakes

**Recommended immediate fix:** Add random delay (0-2 seconds) to sync responses.

**Recommended long-term:** Remove sync feature entirely since it no longer serves a purpose after events were removed.
