# Improved Guild Window

An enhanced guild management window for World of Warcraft 1.12.1 (Turtle WoW).

## Features

### Core Functionality
- Clean, draggable guild management interface
- **Shift+O** keybind to toggle window
- Saves window position and sort preferences between sessions
- Independent of default guild window
- Two-tab interface with default sorting per tab

### Guild Roster Display
- **Guild Members Tab**: Shows online members only, sorted by rank (descending)
- **Member Details Tab**: Shows all members, sorted by rank (descending)
- Class-colored names
- Level, class, rank, note, and officer note columns
- Shows member count (online / total)

### Companion Windows
- **Member Details Window**: Right-side popup showing detailed member info
  - Name, Level, Class, Rank, Zone, Status
  - Public and Officer notes (clickable to edit)
  - **Alt Detection**: Automatically finds and displays alts
    - Searches public notes for "alt" + player name
    - Shows comma-separated list of detected alts
    - Hidden when no alts are found
  - Whisper and Invite to Group buttons
  - Professional dividers separating sections
- **Guild Info Window**: Left-side companion window with guild statistics
  - **Page 1**: Guild overview
    - Guild name and total member count
    - Message of the Day
    - Guild information text
  - **Page 2**: Statistics and analytics
    - Color-coded class distribution bar graph
    - Level 60 character count
    - Top 5 zones where online members are located
    - Officers Online list
  - Navigation arrows at bottom to switch between pages
  - Opens via "< Guild Info" button (red arrow indicator)

### Filtering & Sorting
- **Search Box**: Filter by name, class, rank, note, or officer note
- **Advanced Search**: Toggleable individual column filters
  - Name search box
  - Note (public) search box
  - Officer Note search box
  - All filters work together (AND logic)
  - Toggle visibility with "Advanced Search" button
- **Rank Filter**: Dropdown to filter by specific guild rank
- **Sortable Columns**: Click any column header to sort
  - Name, Level, Class, Rank, Note, Officer Note, Last Online
  - Sort direction indicator (▲/▼)
- **Show Offline Toggle**: Filter online/offline members
- **Enhanced Refresh**: Clears all search boxes and resets filters
- **Per-tab Defaults**: Each tab resets to optimal default view when switched

### Note Editing
- **Public Notes**: Click member row or note field in details window
- **Officer Notes**: Click officer note label or field in details window
- Simple popup dialogs for quick edits
- Respects guild permissions (CanEditPublicNote, CanEditOfficerNote)

### Interface Design
- Centered main navigation tabs (Guild Members / Member Details)
- Guild Info button in bottom-left corner with left-pointing arrow
- Professional horizontal dividers in companion windows
- 5px gaps between windows for cohesive layout
- Consistent 0.95 background opacity
- All windows close together when main window closes

## Installation

1. Extract the `ImprovedGuildWindow` folder to your WoW addons directory:
   - `World of Warcraft\Interface\AddOns\`

2. Restart WoW or reload UI with `/reload`

## Usage

### Opening the Window

- **Keybind**: Go to ESC > Key Bindings > scroll to "Improved Guild Window" section and bind a key (Shift+O recommended)
- **Slash Commands**:
  - `/igw` - Toggle window
  - `/igw show` - Show window
  - `/igw hide` - Hide window

### Window Features

- **Draggable**: Click and drag the title bar to move any window
- **Persistent**: Window positions and preferences saved between sessions
- **Close Button**: Click X in top-right corner to close
- **ESC Key Support**: Press ESC to close windows progressively

### Tab Navigation

- **Guild Members Tab**: Quick view of online members by rank
  - Shows only online members
  - Sorted by rank (descending: Initiate → Officer → Guild Master)
  - Perfect for seeing who's available now
  
- **Member Details Tab**: Full roster management view
  - Shows all members (online and offline)
  - Sorted by rank (descending)
  - Includes Last Online column for activity tracking

### Companion Windows

- **Member Details**: Click any member row to open detailed info panel
  - View/edit public and officer notes
  - Quick whisper or invite
  - Positioned to the right of main window
  
- **Guild Info**: Click "< Guild Info" button to open statistics panel
  - View guild overview and class distribution
  - See MOTD and guild information
  - Positioned to the left of main window

## Version

**1.7** - Stable release with Advanced Search and improvements

## Changelog

### 1.7
- **Advanced Search**: Toggleable row with individual column filters
  - Name, Note (public), and Officer Note search boxes
  - All filters work together with AND logic
  - Toggle visibility with "Advanced Search" button
- **Enhanced Refresh Button**: Now clears all search boxes and resets filters
- **Bidirectional Alt Detection**: Shows all related characters
  - Viewing main shows alts
  - Viewing alt shows main and other alts
  - Creates complete character network
- **Rank-Based Officer Detection**: Uses rank index instead of rank names
  - Configurable `OFFICER_RANK_THRESHOLD` constant (default: 2)
  - Works with any guild structure/language
- **Improved Labels**: "Alts" renamed to "Other Characters"
- **Normalized Z-Depth**: All windows use MEDIUM strata for proper layering

### 1.6
- **Guild Info Pagination**: Two-page system with navigation arrows
  - Page 1: Guild overview (Name, Total Members, MOTD, Guild Info)
  - Page 2: Statistics (Class Distribution, Level 60s, Zones, Officers Online)
- **Visual Class Distribution**: Color-coded bar graph using class colors
- **Enhanced Statistics**:
  - Level 60 character count
  - Top 5 zones where online members are located
  - Officers Online list (Guild Master, Officer, Officer-Alt ranks)
- **Improved Alt Detection**: Exact word matching prevents false matches
  - "Nar" no longer matches "Nargaron"
- **UI Refinements**: Optimized spacing on page 2 to fit all content

### 1.5
- **Alt Detection**: Member Details window now shows detected alts
  - Searches public notes for "alt" + player name
  - Auto-hides section when no alts found
- **UI Improvements**:
  - Opens to Guild Members tab by default
  - Member count shows "X Online | Y Total"
  - Invite button renamed to "Invite to Group"
  - Officer Note section hidden for non-officers
  - Full-width dividers in companion windows
- **Bug Fixes**:
  - Improved scroll behavior to prevent over-scrolling
  - Better handling of empty sections

### 1.4
- **Per-tab defaults**: Each tab now has default sorting and offline visibility
  - Guild Members tab: Sorts by Rank (descending), shows only online members
  - Member Details tab: Sorts by Rank (descending), shows all members
- **Companion windows**: Member Details and Guild Info windows
- **UI improvements**: Centered tabs, professional dividers, reduced window gaps
- Improved SavedVariables safety checks throughout

### 1.3
- Fixed: SavedVariables initialization errors
- Added safety checks for ImprovedGuildWindowDB access
- Prevents nil value errors on sorting, filtering, and position saving

### 1.2
- Fixed background opacity
- Layout constants system
- Different row heights per tab
- Improved spacing calculations

### 1.0
- Initial stable release

## Author

Olzon
