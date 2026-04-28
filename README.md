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

1. Extract the `ImprovedGuildWindow` folder to your `Interface/AddOns` directory
2. Restart World of Warcraft or reload UI (`/reload`)
3. Open with `/igw` or `/improvedguildwindow`

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

## Technical Details

**Compatibility:** World of Warcraft 3.3.5 (Wrath of the Lich King)

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
