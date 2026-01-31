# Improved Guild Window

Enhanced guild management for World of Warcraft 1.12.1 (Turtle WoW).

<img width="1731" height="746" alt="ImprovedGuildWindow A" src="https://github.com/user-attachments/assets/c93831ec-2d1b-4c18-adc8-2459b6615b33" />

## Installation

1. Extract `ImprovedGuildWindow` folder to `World of Warcraft\Interface\AddOns\`
2. Restart WoW or type `/reload`
3. Open with `/igw` or set keybind: ESC → Key Bindings → Improved Guild Window

## Features

### Three View Modes
- **Guild Members** - Online members only, sorted by rank
- **Member Details** - All members with Last Online column
- **Guild Info** - Statistics and guild information (left panel)

### Options Menu
Click the "Options" button to customize:
- **Background Color** - Choose from 8 color themes
- **Window Opacity** - Adjust transparency (30%-100%)
- **Remember Windows** - Restore open panels between sessions
- **Allow Moving Side Windows** - Toggle lock/unlock for side panels
- **Default View** - Set which tab opens by default

### Advanced Search
Click "Advanced Search" for individual filters:
- Name, Public Note, and Officer Note search boxes
- All filters work together
- "Clear / Refresh" button resets and updates roster

### Member Details Panel (Right Side)
Click any member name to view:
- Full member information
- Edit public/officer notes (if permitted)
- Other Characters list (requires "Alt of [Name]" in player notes)
- Quick Whisper and Invite buttons

### Guild Info Panel (Left Side)
**Page 1:**
- Guild name and member count
- Message of the Day
- Guild information text

**Page 2:**
- Class distribution bar graph
- Level 60 count
- Top 5 zones (online members)
- Online officers list

**Page 3:**
- Max level crafters online (300+ skill)
- Grouped by profession (clickable names to whisper)
- Shows: Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring

### Sorting & Filtering
- Click column headers to sort
- Rank dropdown filter
- Show/Hide offline members toggle
- Settings persist per-tab

## Commands

- `/igw` - Toggle window
- `/igw show` - Show window  
- `/igw hide` - Hide window
- `/igw debug` - Show debug info

## Configuration

### Crafter Detection (Page 3)
Add profession info to character **public notes** for automatic detection on Guild Info Page 3.

**Supported formats:**
- `BS 300` or `Blacksmithing 300`
- `300 JC` or `300 Jewelcrafting`
- `Alchemy: 300` or `Alch 300`
- Multiple professions: `300 JC/300 LW`

**Supported abbreviations:**
- **Alchemy**: Alchemy, Alch, Alc
- **Blacksmithing**: Blacksmithing, Blacksmith, Smith, BS, B.S.
- **Enchanting**: Enchanting, Enchant, Ench, Enc
- **Engineering**: Engineering, Engineer, Eng, Engi
- **Jewelcrafting**: Jewelcrafting, Jewel, JC, J.C.
- **Leatherworking**: Leatherworking, Leather, LW, L.W.
- **Tailoring**: Tailoring, Tailor, Tail, TLR

Only shows characters with 300+ skill who are currently online. Click names to whisper.

### Officer Detection
Edit `OFFICER_RANK_THRESHOLD` in the .lua file (default: 2)
- 0 = Guild Master only
- 1 = Guild Master + first officer rank
- 2 = Guild Master + top 2 ranks (default)

### Alt Detection
Add "Alt of [MainName]" to character public notes for automatic detection.
Works bidirectionally - view any character to see their alts and main.

## Version

**2.1** - Latest release

### Changelog

**2.1**
- Added Guild Info Page 3: Max Level Crafters Online
- Displays crafters with 300+ skill (online only)
- 7 crafting professions: Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring
- Flexible profession detection (supports abbreviations and multiple formats)
- Clickable names to whisper crafters directly
- Reads from character public notes

**2.0**
- Complete visual overhaul with solid backgrounds
- Customizable colors (8 themes: Grey, Black, Blue, Brown, Green, Purple, Red, Cyan)
- Adjustable opacity per window (30-100%)
- Options menu with comprehensive settings
- Remember open windows between sessions
- Movable/lockable side panels option
- Choose default view tab
- Options window at 90% opacity
- Fixed color persistence across reloads

**1.10**
- Options window matched to main window size
- Updated options title

**1.9**
- Initial options menu implementation
- Basic visual and behavior settings

## Author

Olzon
