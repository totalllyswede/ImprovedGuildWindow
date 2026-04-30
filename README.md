# Improved Guild Window

A comprehensive guild management addon for World of Warcraft 3.3.5 (Wrath of the Lich King).

## Features

### Main Roster Window
- **Three Viewing Modes:**
  - **Member Details** - Comprehensive member information with notes and officer notes
  - **Detailed View** - Member details including date joined and timezone
  - **Guild Members** - Quick overview of all guild members
  
- **Advanced Filtering:**
  - Filter by rank
  - Filter by region (Americas, Europe, Oceania, Asia)
  - Search by name, note, or officer note
  - Show/hide offline members
  - Show/hide alts (members with "alt" in their rank name)

- **Sorting:**
  - Sort by name, level, class, rank, zone, or last online
  - Ascending/descending order

- **Color-Coded Display:**
  - Class colors for member names
  - Online/offline status indicators
  - Custom background colors and opacity

### Guild Info Panel (Left Side Window)
A 4-page information panel with guild statistics and tools:

**Page 1 - Guild Overview**
- Guild name and member counts (excluding alts)
- Alt member count (members with "alt" in rank)
- Message of the Day (MOTD)
- Guild Information text

**Page 2 - Class Distribution**
- Visual bar graphs showing class distribution
- Separate section for level 80 characters
- Color-coded by class

**Page 3 - Crafters**
- List of guild members with professions
- Organized by profession type
- Clickable names to whisper crafters

**Page 4 - Suggested Dungeons**
- Dynamic dungeon suggestions based on online member levels
- Color-coded by player's level:
  - Green: Perfect fit for your level
  - Yellow: Close fit (within 3 levels)
  - Red: Too low level
  - Gray: Too high level
- Shows number of guild members in level range
- Abbreviated dungeon names for better readability

### Member Details Panel (Right Side Window)
When clicking on a member, shows:
- Character name, level, race, and class
- Guild rank
- Current zone/location
- Public note (editable if you have permissions)
- Officer note (editable if you have permissions)
- Last online time

### Keybindings
- Toggle main window: Configurable keybind (default: not set)
- Access via: ESC → Key Bindings → Improved Guild Window

## Installation

### Method 1: Git Addons Manager (Recommended)

If you're using a Git-based addon manager:

1. Add this repository to your addon manager
2. The addon will automatically install to your `Interface/AddOns` directory
3. Restart World of Warcraft or reload UI with `/reload`
4. Type `/igw` to open the addon

### Method 2: Manual Installation

1. **Download** the latest release (ImprovedGuildWindow.zip)
2. **Extract** the zip file - you should see a folder named `ImprovedGuildWindow`
3. **Locate** your WoW installation directory:
   - **Windows:** `C:\Program Files (x86)\World of Warcraft\_classic_\` or your custom installation path
   - **Mac:** `/Applications/World of Warcraft/_classic_/`
   - **Linux:** Typically `~/.wine/drive_c/Program Files (x86)/World of Warcraft/_classic_/`
4. **Navigate** to the `Interface\AddOns` folder inside your WoW directory
   - Full path example: `C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns`
5. **Copy** the `ImprovedGuildWindow` folder into the `AddOns` directory
6. **Verify** the structure looks like this:
   ```
   Interface/AddOns/ImprovedGuildWindow/
   ├── Bindings.xml
   ├── IGW_Sync.lua
   ├── IGW_SyncUI_Example.lua
   ├── ImprovedGuildWindow.lua
   ├── ImprovedGuildWindow.toc
   └── README.md
   ```
7. **Launch** World of Warcraft (or `/reload` if already running)
8. **Verify** installation:
   - At character selection, click "AddOns" button (bottom-left)
   - Look for "Improved Guild Window" in the list
   - Make sure it's checked/enabled
9. **Open** the addon with `/igw` or `/improvedguildwindow`

### Troubleshooting Installation

**Addon not appearing in game?**
- Verify the folder name is exactly `ImprovedGuildWindow` (no extra spaces or characters)
- Check that `ImprovedGuildWindow.toc` is present in the folder
- Make sure you're looking in the correct WoW installation (Classic/WotLK, not Retail)
- Try deleting `Cache` and `WTF` folders (backup your settings first!)

**Addon listed but won't load?**
- Check the addon list at character selection - ensure it's enabled
- Look for error messages when logging in
- Verify all files were extracted (should have 6 files)
- Make sure your game version is 3.3.5 (WotLK)

## Usage

### Commands
- `/igw` or `/improvedguildwindow` - Toggle main window
- `/igw clear` - Clear all filters and reset view
- `/igw refresh` - Refresh guild roster data

### Interface
- **Left Click** on member - View detailed information in right panel
- **Clear/Refresh Button** - Reset all filters and refresh data
- **Tab Buttons** - Switch between viewing modes
- **Guild Info Button** - Toggle left information panel
- **Options Button** - Access addon settings

### Settings
Configure various options including:
- Background colors and opacity
- Window movement permissions
- Display preferences
- Filter defaults
- **Smart Notifications** - Get notified when:
  - Officers log in
  - Crafters with professions in notes log in
  - Guild members are in your current area (when you enter a new zone)

### Smart Notifications
Receive helpful chat notifications to stay connected with your guild:

- **Officer Login** - Get notified when officers log in: `[GuildName] Officer PlayerName is now online`
- **Crafter Online** - Know when crafters are available: `[GuildName] PlayerName (Alchemy) is now online`
  - Automatically detects professions in member notes (Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring)
- **Members in Zone** - See who's in your area when you enter a new zone:
  - Single member: `[GuildName] PlayerName is in Stormwind`
  - Multiple members: `[GuildName] 5 guild members are in Stormwind`
  - Only triggers once per zone entry (no spam)

All notifications can be toggled on/off individually in the Options menu.

## Technical Details

**Compatibility:** World of Warcraft 3.3.5 (Wrath of the Lich King)

**Performance Optimizations:**
- Frame pooling system (reuses UI frames instead of recreating them)
- Event throttling (roster updates limited to once per second)
- Conditional updates (only updates visible windows)
- Zone notifications event-driven via ZONE_CHANGED_NEW_AREA
- Optimized for guilds of any size with minimal memory footprint

**Migration from 1.12.1:**
This addon was originally designed for WoW 1.12.1 (Vanilla) and has been fully migrated to 3.3.5 with the following major updates:
- Event handler signatures updated (arg1/arg2 → named parameters)
- Script handlers changed from `this` to `self`
- UIDropDownMenu API parameter order corrected
- FauxScrollFrame implementation updated for 3.3.5
- TOC interface version updated to 30300
- All deprecated APIs replaced with 3.3.5 equivalents

**Note:** The sync functionality (IGW_Sync.lua) is disabled in this version.

## Credits

Originally created for WoW 1.12.1 (Vanilla)
Migrated to 3.3.5 (WotLK) by Claude (Anthropic)

## License

This addon is provided as-is for World of Warcraft 3.3.5 servers.

## Version

3.3.5 - Full WotLK compatibility release
