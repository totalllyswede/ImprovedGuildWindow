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
  - Whisper and Invite buttons
  - Professional dividers separating sections
- **Guild Info Window**: Left-side companion window with guild statistics
  - Guild name and member counts
  - Class distribution
  - Message of the Day
  - Guild information text
  - Opens via "< Guild Info" button (red arrow indicator)

### Filtering & Sorting
- **Search Box**: Filter by name, class, rank, note, or officer note
- **Rank Filter**: Dropdown to filter by specific guild rank
- **Sortable Columns**: Click any column header to sort
  - Name, Level, Class, Rank, Note, Officer Note, Last Online
  - Sort direction indicator (▲/▼)
- **Show Offline Toggle**: Filter online/offline members
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

**1.4** - Stable release with per-tab defaults and companion windows

## Changelog

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
