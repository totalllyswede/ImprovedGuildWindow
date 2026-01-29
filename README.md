# Improved Guild Window

Enhanced guild management for World of Warcraft 1.12.1 (Turtle WoW).

<img width="1731" height="746" alt="ImprovedGuildWindow A" src="https://github.com/user-attachments/assets/c93831ec-2d1b-4c18-adc8-2459b6615b33" />

## Installation

1. Extract `ImprovedGuildWindow` folder to `World of Warcraft\Interface\AddOns\`
2. Restart WoW or `/reload`
3. Set keybind: ESC > Key Bindings > Improved Guild Window (Shift+O recommended)
   
## Quick Start

**/igw to open window or set a Keybind in WoW settings
**Close:** ESC or click X

## Main Features

### Three Main Tabs
- **Guild Members** - Online members only, sorted by rank
- **Member Details** - All members with Last Online column
- **Guild Info** - Statistics and guild information (opens left panel)

### Advanced Search
Click "Advanced Search" to reveal individual search boxes:
- Name search
- Public note search  
- Officer note search
- All filters work together

**Clear / Refresh** button resets all filters and refreshes roster.

### Member Details Window (Right Panel)
Click any member to open:
- Full member information
- Edit public/officer notes (if permitted)
- Other Characters list (Alts need player notes for this to work ex. Alt of Olzon)
- Whisper and Invite buttons

### Guild Info Window (Left Panel)
**Page 1 - Overview:**
- Guild name and member count
- Message of the Day
- Guild information

**Page 2 - Statistics:**
- Class distribution (color-coded bar graph)
- Level 60 character count
- Top 5 zones (online members)
- Officers online list

Use arrow buttons (< >) to switch pages.

### Sorting & Filtering
- Click column headers to sort (▲/▼ indicator)
- Rank dropdown filter
- Show/Hide offline members toggle
- Per-tab default settings

### Quality of Life
- All windows draggable
- Positions saved between sessions
- Class-colored names
- Auto-updates on roster changes
- Companion windows close with main window

## Commands

- `/igw` - Toggle window
- `/igw show` - Show window
- `/igw hide` - Hide window
- `/igw debug` - Show debug info

## Configuration

### Officer Rank Detection
Edit `OFFICER_RANK_THRESHOLD` in the .lua file (default: 2)
- 0 = Guild Master only
- 1 = Guild Master + first officer rank
- 2 = Guild Master + top 2 officer ranks (default)

### Alt Detection
Searches public notes for "alt" + character name. Works bidirectionally:
- View main → shows all alts
- View alt → shows main + other alts

## Version

**1.8** - Latest stable release

### Recent Updates

**1.8**
- UI consistency improvements
- All tabs same size (120px) and properly aligned
- Guild Info button highlights when active
- Pagination buttons match tab button height
- Search boxes have proper text padding and height

**1.7**
- Advanced Search with individual column filters
- Enhanced Clear/Refresh button
- Bidirectional alt detection
- Rank-based officer detection (language-independent)
- Normalized window layering

**1.6**
- Guild Info pagination system (2 pages)
- Visual class distribution bar graph
- Enhanced statistics (Level 60s, Zones, Officers)

## Author

Olzon
