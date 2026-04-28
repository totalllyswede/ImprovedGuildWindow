-- Improved Guild Window for WoW 1.12.1 / Turtle WoW
-- Author: Travis

local IGW = {}
IGW.VERSION = "3.1"

-- Global function for keybind (must be defined early)
function ImprovedGuildWindow_Toggle()
    if IGW and IGW.ToggleWindow then
        IGW:ToggleWindow()
    end
end

local frame
local rosterData = {}
local displayedMembers = {}
local sortColumn = "name"
local sortAscending = true
local filterText = ""
local filterRank = -1
local showOffline = true
local currentTab = "details"

-- Configuration: Officer rank threshold
-- rankIndex: 0=Guild Master, 1-9=other ranks
-- Members with rankIndex <= this value are considered "officers"
-- Default: 2 (includes Guild Master and top 2 officer ranks)
local OFFICER_RANK_THRESHOLD = 2

-- Check if current player is an officer
function IGW:IsOfficer()
    local playerName = UnitName("player")
    for i = 1, GetNumGuildMembers(true) do
        local name, rank, rankIndex = GetGuildRosterInfo(i)
        if name == playerName then
            return rankIndex <= OFFICER_RANK_THRESHOLD
        end
    end
    return false
end

-- Timezone lookup table
local TIMEZONES = {
    PST = "PST (UTC-8)",
    PDT = "PDT (UTC-7)",
    MST = "MST (UTC-7)",
    MDT = "MDT (UTC-6)",
    CST = "CST (UTC-6)",
    CDT = "CDT (UTC-5)",
    EST = "EST (UTC-5)",
    EDT = "EDT (UTC-4)",
    GMT = "GMT (UTC+0)",
    UTC = "UTC (UTC+0)",
    CET = "CET (UTC+1)",
    EET = "EET (UTC+2)",
    MSK = "MSK (UTC+3)",
    IST = "IST (UTC+5:30)",
    JST = "JST (UTC+9)",
    AEST = "AEST (UTC+10)",
    NZST = "NZST (UTC+12)"
}

-- Dungeon details database
local DUNGEON_DETAILS = {
    ["Ragefire Chasm"] = {
        location = "Orgrimmar",
        faction = "Horde",
        description = "Volcanic caverns beneath Orgrimmar infested with troggs. The Burning Blade cult has taken refuge in the fiery depths, threatening Durotar's sovereignty.",
        bosses = "Taragaman the Hungerer, Jergosh the Invoker",
        notable = "Cloth, Fire resist gear"
    },
    ["The Deadmines"] = {
        location = "Westfall",
        faction = "Alliance",
        description = "Abandoned gold mine claimed by the Defias Brotherhood. Edwin VanCleef and his brigands use the labyrinth as their base of operations against Stormwind.",
        bosses = "Edwin VanCleef, Sneed, Mr. Smite",
        notable = "Cruel Barb, Smite's Hammer"
    },
    ["Wailing Caverns"] = {
        location = "Northern Barrens",
        faction = "Neutral",
        description = "Druid Naralex's vision of restoring the Barrens turned into a nightmare. The caverns are now twisted by corruption, home to deviant creatures and the sleeping Naralex.",
        bosses = "Lady Anacondra, Lord Pythas, Mutanus",
        notable = "Armor of the Fang set, Glowing Lizardscale Cloak"
    },
    ["Stockades"] = {
        location = "Stormwind City",
        faction = "Alliance",
        description = "Stormwind's high-security prison has been overrun by rioting inmates. The violent criminals have taken control and must be stopped.",
        bosses = "Bazil Thredd, Dextren Ward",
        notable = "Prison variety loot"
    },
    ["Blackfathom Deeps"] = {
        location = "Ashenvale",
        faction = "Neutral",
        description = "Ancient temple once dedicated to Elune, lost beneath the sea during the Sundering. Twilight's Hammer cultists now protect an Old God's cherished creature within.",
        bosses = "Gelihast, Lady Sarevess, Aku'mai",
        notable = "Blackfathom Mana Oil, Strike of the Hydra"
    },
    ["SM-Graveyard"] = {
        location = "Tirisfal Glades",
        faction = "Neutral",
        description = "The Scarlet Crusade's burial grounds, now haunted by the very undead they fought. Zealots and restless spirits guard the graveyard.",
        bosses = "Interrogator Vishas, Bloodmage Thalnos",
        notable = "Scarlet gear, good XP"
    },
    ["Gnomeregan"] = {
        location = "Dun Morogh",
        faction = "Alliance",
        description = "Once a marvel of gnomish engineering, now a radioactive nightmare. Troggs and crazed leper gnomes infest the irradiated halls of this fallen city.",
        bosses = "Mekgineer Thermaplugg, Crowd Pummeler 9-60",
        notable = "Electrocutioner Leg, Triprunner Dungarees"
    },
    ["SM-Library"] = {
        location = "Tirisfal Glades",
        faction = "Neutral",
        description = "Repository of the Scarlet Crusade's knowledge and magical artifacts. Fanatical zealots guard tomes of forgotten lore.",
        bosses = "Arcanist Doan, Houndmaster Loksey",
        notable = "Illusionary Rod, Hypnotic Blade"
    },
    ["Razorfen Kraul"] = {
        location = "Southern Barrens",
        faction = "Neutral",
        description = "Sacred quilboar den built where the demigod Agamaggan fell. Massive thorn vines twist through the underground warren.",
        bosses = "Charlga Razorflank, Agathelos",
        notable = "Corpsemaker, Razorfen Spaulders"
    },
    ["SM-Armory"] = {
        location = "Tirisfal Glades",
        faction = "Neutral",
        description = "Training grounds where the Scarlet Crusade forges its warriors. Herod the Bully oversees brutal combat drills.",
        bosses = "Herod the Bully",
        notable = "Ravager, Scarlet Leggings"
    },
    ["SM-Cathedral"] = {
        location = "Tirisfal Glades",
        faction = "Neutral",
        description = "Grand cathedral and seat of Scarlet power. High Inquisitor Whitemane and Commander Mograine lead the fanatic crusade.",
        bosses = "High Inquisitor Whitemane, Scarlet Commander Mograine",
        notable = "Whitemane's Chapeau, Mograine's Might"
    },
    ["Uldaman"] = {
        location = "Badlands",
        faction = "Neutral",
        description = "Ancient titan vault holding arcane secrets from ages past. Troggs, dwarves, and powerful stone constructs guard the depths.",
        bosses = "Archaedas, Ironaya, Galgann Firehammer",
        notable = "The Rockpounder, Archaedic Stone"
    },
    ["Razorfen Downs"] = {
        location = "Southern Barrens",
        faction = "Neutral",
        description = "Quilboar city overtaken by the Scourge and undead forces. Amnennar the Coldbringer raises an army of death.",
        bosses = "Amnennar the Coldbringer, Tuten'kash",
        notable = "Shoulder of the Fallen Crusader, Ebon Vise"
    },
    ["Maraudon"] = {
        location = "Desolace",
        faction = "Neutral",
        description = "Burial place of Zaetar, son of Cenarius, where Princess Theradras grieves. Centaurs and noxious elementals fill the corrupted caverns.",
        bosses = "Princess Theradras, Celebras, Noxxion",
        notable = "Blackstone Ring, Nature Resist gear"
    },
    ["Zul'Farrak"] = {
        location = "Tanaris",
        faction = "Neutral",
        description = "Ancient troll city of the Sandfury tribe, buried in desert sands. Rumors tell of an ancient creature sleeping within that threatens all of Tanaris.",
        bosses = "Chief Ukorz Sandscalp, Gahz'rilla",
        notable = "Sul'thraze, Lifeforce Dirk"
    },
    ["Sunken Temple"] = {
        location = "Swamp of Sorrows",
        faction = "Neutral",
        description = "Temple of Atal'Hakkar, built by exiled Gurubashi priests attempting to summon Hakkar. The cursed temple now lies sunken in the swamp.",
        bosses = "Avatar of Hakkar, Shade of Eranikus",
        notable = "Drakestone, Eranikus' Fang"
    },
    ["Blackrock Depths"] = {
        location = "Blackrock Mountain",
        faction = "Neutral",
        description = "Smoldering fortress city of the Dark Iron dwarves deep within Blackrock Mountain. Emperor Dagran Thaurissan rules from his throne of fire.",
        bosses = "Emperor Dagran Thaurissan, General Angerforge",
        notable = "Hand of Justice, Ironfoe"
    },
    ["Dire Maul West"] = {
        location = "Feralas",
        faction = "Neutral",
        description = "Overgrown gardens of the ancient night elf city Eldre'Thalas. Prince Tortheldrin and his corrupted guards haunt the ruins.",
        bosses = "Tendris Warpwood, Immol'thar, Prince Tortheldrin",
        notable = "Warpwood Binding, Dreadmist Belt"
    },
    ["Dire Maul East"] = {
        location = "Feralas",
        faction = "Neutral",
        description = "Demon-infested eastern wing of the fallen Kaldorei city. Satyr and imps swarm the corrupted halls.",
        bosses = "Alzzin the Wildshaper, Isalien",
        notable = "Felhide Cap, Energized Chestplate"
    },
    ["LBRS"] = {
        location = "Blackrock Mountain",
        faction = "Neutral",
        description = "Lower levels of Blackrock Spire controlled by the Dark Horde. Orcs and their allies prepare for war in the shadowy halls.",
        bosses = "General Drakkisath, War Master Voone",
        notable = "Truestrike Shoulders, Dal'Rend's set"
    },
    ["Dire Maul North"] = {
        location = "Feralas",
        faction = "Neutral",
        description = "Northern wing ruled by King Gordok and his ogre clan. Adventurers seek tribute runs for powerful buffs.",
        bosses = "King Gordok, Cho'Rush the Observer",
        notable = "Tribute buffs, Ogre Tannin"
    },
    ["Scholomance"] = {
        location = "Western Plaguelands",
        faction = "Neutral",
        description = "Former school of necromancy transformed into a Scourge stronghold. Darkmaster Gandling conducts dark experiments in the cursed halls.",
        bosses = "Darkmaster Gandling, Ras Frostwhisper",
        notable = "Deathbone set, Necromancy books"
    },
    ["Stratholme"] = {
        location = "Eastern Plaguelands",
        faction = "Neutral",
        description = "Once-proud city now torn between Scourge and Scarlet Crusade forces. Baron Rivendare commands the undead from the plagued streets.",
        bosses = "Baron Rivendare, Ramstein, Balnazzar",
        notable = "Deathcharger's Reins, Runeblade of Baron Rivendare"
    },
    ["UBRS"] = {
        location = "Blackrock Mountain",
        faction = "Neutral",
        description = "Upper reaches of Blackrock Spire where General Drakkisath commands. The black dragonflight maintains a powerful presence.",
        bosses = "General Drakkisath, Rend Blackhand",
        notable = "Tier 0 upgrades, Dalrend's Sacred Charge"
    }
}

-- Dungeon loading screen textures
local DUNGEON_TEXTURES = {
    ["Ragefire Chasm"] = "Interface\\Glues\\LoadingScreens\\LoadScreenRFC",
    ["The Deadmines"] = "Interface\\Glues\\LoadingScreens\\LoadScreenDeadmines",
    ["Wailing Caverns"] = "Interface\\Glues\\LoadingScreens\\LoadScreenWailingCaverns",
    ["Stockades"] = "Interface\\Glues\\LoadingScreens\\LoadScreenStockades",
    ["Blackfathom Deeps"] = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackfathomDeeps",
    ["Gnomeregan"] = "Interface\\Glues\\LoadingScreens\\LoadScreenGnomeregan",
    ["Razorfen Kraul"] = "Interface\\Glues\\LoadingScreens\\LoadScreenRazorfenKraul",
    ["SM-Graveyard"] = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
    ["SM-Library"] = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
    ["SM-Armory"] = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
    ["SM-Cathedral"] = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery",
    ["Uldaman"] = "Interface\\Glues\\LoadingScreens\\LoadScreenUldaman",
    ["Razorfen Downs"] = "Interface\\Glues\\LoadingScreens\\LoadScreenRazorfenDowns",
    ["Maraudon"] = "Interface\\Glues\\LoadingScreens\\LoadScreenMaraudon",
    ["Zul'Farrak"] = "Interface\\Glues\\LoadingScreens\\LoadScreenZulFarrak",
    ["Sunken Temple"] = "Interface\\Glues\\LoadingScreens\\LoadScreenSunkenTemple",
    ["Blackrock Depths"] = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackrockDepths",
    ["Dire Maul West"] = "Interface\\Glues\\LoadingScreens\\LoadScreenDireMaul",
    ["Dire Maul East"] = "Interface\\Glues\\LoadingScreens\\LoadScreenDireMaul",
    ["Dire Maul North"] = "Interface\\Glues\\LoadingScreens\\LoadScreenDireMaul",
    ["LBRS"] = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackrockSpire",
    ["UBRS"] = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackrockSpire",
    ["Scholomance"] = "Interface\\Glues\\LoadingScreens\\LoadScreenScholomance",
    ["Stratholme"] = "Interface\\Glues\\LoadingScreens\\LoadScreenStratholme"
}

-- Dungeon full display names
local DUNGEON_FULL_NAMES = {
    ["SM-Graveyard"] = "Scarlet Monastery - Graveyard",
    ["SM-Library"] = "Scarlet Monastery - Library",
    ["SM-Armory"] = "Scarlet Monastery - Armory",
    ["SM-Cathedral"] = "Scarlet Monastery - Cathedral",
    ["LBRS"] = "Lower Blackrock Spire",
    ["UBRS"] = "Upper Blackrock Spire"
}

-- Default loading screen for dungeons without custom backgrounds
local DEFAULT_LOADING_SCREEN = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor"

-- Timezone to region mapping
local TIMEZONE_REGIONS = {
    -- Americas
    PST = "Americas",
    PDT = "Americas",
    MST = "Americas",
    MDT = "Americas",
    CST = "Americas",
    CDT = "Americas",
    EST = "Americas",
    EDT = "Americas",
    -- Oceania
    AEST = "Oceania",
    NZST = "Oceania",
    -- Europe
    GMT = "Europe",
    UTC = "Europe",
    CET = "Europe",
    EET = "Europe",
    -- Asia
    MSK = "Asia",
    IST = "Asia",
    JST = "Asia"
}




-- Fixed background opacity (v1.2)
local IGW_BG_OPACITY = 0.95

-- Layout constants
local FILTER_ROW_TOP_Y        = -50   -- where the first filter row starts
local FILTER_ROW_HEIGHT       = 30    -- height of a single filter row
local FILTER_ROW_GAP          = 5     -- spacing between filter rows
local FILTER_ROWS             = 2     -- number of filter rows (second row reserved for future options)
local FILTER_EXTRA_SPACING    = 0     -- extra space under filter rows (reserved for future options)
local HEADER_BASE_OFFSET_Y    = 10    -- gap between filters and column headers

-- Row heights
local ROW_HEIGHT_DEFAULT = 20
local ROW_HEIGHT_DETAILS = 25  -- +5px only on Member Details tab

-- Visible rows
local VISIBLE_ROWS_GUILD = 13    -- Guild Members tab (show 1 fewer row)
local VISIBLE_ROWS_DETAILS = 11  -- Member Details tab



local function IGW_GetHeaderTopY()
    return FILTER_ROW_TOP_Y
        - (FILTER_ROW_HEIGHT * FILTER_ROWS)
        - (FILTER_ROW_GAP * (FILTER_ROWS - 1))
        - FILTER_EXTRA_SPACING
        - HEADER_BASE_OFFSET_Y
end

-- Race detection from officer note (first character(s) followed by dash)
local function IGW_GetRace(officerNote)
    if not officerNote or officerNote == "" then return "" end
    
    -- Check for 2-character codes first (Ta-, He-, Go-, Hu-, NE-, Dw-, Un-)
    local firstTwo = string.sub(officerNote, 1, 2)
    local thirdChar = string.sub(officerNote, 3, 3)
    
    if thirdChar == "-" then
        if firstTwo == "Ta" then return "Tauren"
        elseif firstTwo == "He" or firstTwo == "HE" then return "High Elf"
        elseif firstTwo == "Go" then return "Goblin"
        elseif firstTwo == "Hu" or firstTwo == "HU" then return "Human"
        elseif firstTwo == "NE" then return "Night Elf"
        elseif firstTwo == "Dw" or firstTwo == "DW" then return "Dwarf"
        elseif firstTwo == "Un" or firstTwo == "UN" then return "Undead"
        elseif firstTwo == "Gn" or firstTwo == "GN" then return "Gnome"
        elseif firstTwo == "Or" or firstTwo == "OR" then return "Orc"
        elseif firstTwo == "Tr" or firstTwo == "TR" then return "Troll"
        end
    end
    
    -- Check for single char + dash (backwards compatibility)
    local firstChar = string.sub(officerNote, 1, 1)
    local secondChar = string.sub(officerNote, 2, 2)
    
    if secondChar ~= "-" then
        return "" -- No dash found, return empty
    end
    
    if firstChar == "N" then return "Night Elf"
    elseif firstChar == "D" then return "Dwarf"
    elseif firstChar == "H" then return "Human"
    elseif firstChar == "T" then return "Troll"
    elseif firstChar == "O" then return "Orc"
    elseif firstChar == "G" then return "Gnome"
    elseif firstChar == "U" then return "Undead"
    else return ""
    end
end

-- Faction based on race
local function IGW_GetFaction(race)
    if race == "" then return "" end
    
    if race == "Night Elf" or race == "Dwarf" or race == "Human" or race == "Gnome" or race == "High Elf" then
        return "Alliance"
    elseif race == "Troll" or race == "Tauren" or race == "Orc" or race == "Undead" or race == "Goblin" then
        return "Horde"
    else
        return ""
    end
end

-- Keybinding strings (shown in ESC > Key Bindings)
BINDING_HEADER_IMPROVEDGUILDWINDOW = "Improved Guild Window"
BINDING_NAME_IMPROVEDGUILDWINDOW_TOGGLE = "Toggle Window"


-- ESC-close support (WoW closes frames listed in UISpecialFrames before opening the game menu)
local function IGW_AddToSpecialFrames(frameName, toFront)
    if not frameName or frameName == "" then return end
    if not UISpecialFrames then UISpecialFrames = {} end

    -- remove duplicates
    for i = table.getn(UISpecialFrames), 1, -1 do
        if UISpecialFrames[i] == frameName then
            table.remove(UISpecialFrames, i)
        end
    end

    if toFront then
        table.insert(UISpecialFrames, 1, frameName)
    else
        table.insert(UISpecialFrames, frameName)
    end
end

-- Class color lookup
local CLASS_COLORS = {
    ["Warrior"] = {r=0.78, g=0.61, b=0.43},
    ["Paladin"] = {r=0.96, g=0.55, b=0.73},
    ["Hunter"] = {r=0.67, g=0.83, b=0.45},
    ["Rogue"] = {r=1.0, g=0.96, b=0.41},
    ["Priest"] = {r=1.0, g=1.0, b=1.0},
    ["Shaman"] = {r=0.0, g=0.44, b=0.87},
    ["Mage"] = {r=0.41, g=0.8, b=0.94},
    ["Warlock"] = {r=0.58, g=0.51, b=0.79},
    ["Druid"] = {r=1.0, g=0.49, b=0.04}
}

-- Initialize saved variables
function IGW:OnLoad()
    -- Note: At this point, SavedVariables are NOT yet loaded
    -- We'll initialize them in OnPlayerLogin when they're available
    self:RegisterEvents()
    
    -- Register slash commands
    SLASH_IGW1 = "/igw"
    SLASH_IGW2 = "/improvedguildwindow"
    SlashCmdList["IGW"] = function(msg)
        IGW:HandleSlashCommand(msg)
    end
    
    SLASH_IGWDEBUG1 = "/igwdebug"
    SlashCmdList["IGWDEBUG"] = function(msg)
        if IGW_Sync then
            IGW_Sync.debugEnabled = not IGW_Sync.debugEnabled
            if IGW_Sync.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Debug messages enabled")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Debug messages disabled")
            end
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Improved Guild Window loaded!|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Set keybind in ESC > Key Bindings > Improved Guild Window|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Or use /igw to open|r")
end

-- Initialize SavedVariables and create frame (called after PLAYER_LOGIN when SavedVariables are loaded)
function IGW:InitializeSavedVariables()
    if not ImprovedGuildWindowDB then
        ImprovedGuildWindowDB = {
            position = {},
            width = 650,
            height = 500,
            sortColumn = "name",
            sortAscending = true,
            showOffline = true,
            opacity = 1.0,
            bgColor = {r = 0.15, g = 0.15, b = 0.15}  -- Default dark grey
        }
    end
    
    -- Ensure bgColor exists (for existing saved variables)
    if not ImprovedGuildWindowDB.bgColor then
        ImprovedGuildWindowDB.bgColor = {r = 0.15, g = 0.15, b = 0.15}
    end
    
    -- Load saved opacity or use default
    IGW_BG_OPACITY = ImprovedGuildWindowDB.opacity or 0.95

    sortColumn = ImprovedGuildWindowDB.sortColumn or "name"
    sortAscending = ImprovedGuildWindowDB.sortAscending
    if sortAscending == nil then sortAscending = true end
    
    -- If rememberSorting is off, reset to defaults
    if ImprovedGuildWindowDB.rememberSorting == false then
        sortColumn = "name"
        sortAscending = true
    end
    
    showOffline = ImprovedGuildWindowDB.showOffline
    if showOffline == nil then showOffline = true end
    
    -- NOW create the main frame with SavedVariables loaded
    self:CreateMainFrame()
end

-- Create the main window frame
function IGW:CreateMainFrame()
    -- Ensure DB exists (should have been initialized by now)
    if not ImprovedGuildWindowDB then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000ERROR: ImprovedGuildWindowDB not initialized!|r")
        return
    end
    
    -- Don't create if already exists
    if frame then
        return
    end
    
    -- Main frame
    frame = CreateFrame("Frame", "ImprovedGuildWindowFrame", UIParent)
    IGW_AddToSpecialFrames("ImprovedGuildWindowFrame", false)
    frame:SetWidth(ImprovedGuildWindowDB.width or 650)
    frame:SetHeight(ImprovedGuildWindowDB.height or 500)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(20)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Background (border only, solid texture added separately)
    frame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Create solid background texture (inside the border)
    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
    bgTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
    -- Use saved color or default to dark grey
    local bgColor = {r = 0.15, g = 0.15, b = 0.15}
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
        bgColor = ImprovedGuildWindowDB.bgColor
    end
    bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
    frame.bgTexture = bgTexture
    
    -- Title bar for dragging
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    titleBar:SetHeight(30)
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        IGW:SavePosition()
    end)
    
    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    title:SetText(GetGuildInfo("player") or "Guild Window")
    frame.titleText = title
    
    -- Close button (with 5px padding)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    closeBtn:SetScript("OnClick", function()
        -- Save window states if remember is enabled
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows then
            ImprovedGuildWindowDB.windowStates = {
                detailsOpen = IGW.detailsFrame and IGW.detailsFrame:IsVisible() or false,
                infoOpen = IGW.infoFrame and IGW.infoFrame:IsVisible() or false
            }
        end
        frame:Hide()
        -- Close details window when main window closes
        if IGW.detailsFrame then
            IGW.detailsFrame:Hide()
        end
        if IGW.infoFrame then
            IGW.infoFrame:Hide()
            -- Un-highlight Guild Info button
            frame.tab4:SetBackdropColor(0.2, 0.2, 0.2, 1)
            frame.tab4Text:SetTextColor(0.7, 0.7, 0.7)
        end
        -- Close options window
        if IGW.optionsFrame then
            IGW.optionsFrame:Hide()
        end
    end)
    
    -- New Guild Announcements button (top left corner)
    local announcementBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    announcementBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -15)
    announcementBtn:SetWidth(160)
    announcementBtn:SetHeight(22)
    announcementBtn:SetText("New Guild Announcements")
    announcementBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    announcementBtn:Hide() -- Hidden by default
    
    -- Glow/highlight effect
    announcementBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    announcementBtn:SetBackdropColor(0.2, 0.6, 1, 0.3)
    announcementBtn:SetBackdropBorderColor(0.4, 0.8, 1, 1)
    
    announcementBtn:SetScript("OnClick", function()
        -- Open guild info window (page 5 removed)
        IGW:ToggleGuildInfoWindow()
        this:Hide()
    end)
    
    frame.announcementBtn = announcementBtn
    
    -- Options button (standard button, anchored to left of close button)
    local optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)  -- 2px gap from close button
    optionsBtn:SetWidth(65)
    optionsBtn:SetHeight(20)
    optionsBtn:SetText("Options")
    optionsBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    
    optionsBtn:SetScript("OnClick", function()
        IGW:ToggleOptionsWindow()
    end)
    -- Filter section
    self:CreateFilterSection()
    
    -- Column headers
    self:CreateColumnHeaders()
    
    -- Scroll frame for roster
    self:CreateRosterScrollFrame()
    
    -- Tabs
    self:CreateTabs()
    
    -- Member count - position above tabs, below roster
    local memberCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memberCount:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 45)
    memberCount:SetText("0 Online | 0 Total")
    frame.memberCount = memberCount
    
    -- Restore saved position or set default
    if ImprovedGuildWindowDB.position and ImprovedGuildWindowDB.position.point then
        frame:SetPoint(
            ImprovedGuildWindowDB.position.point,
            UIParent,
            ImprovedGuildWindowDB.position.point,
            ImprovedGuildWindowDB.position.x or 0,
            ImprovedGuildWindowDB.position.y or 0
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Initialize with Guild Members tab (details)
    self:UpdateColumnHeaders("details")
end

-- Create filter section
function IGW:CreateFilterSection()
    local filterFrame = CreateFrame("Frame", nil, frame)
filterFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, FILTER_ROW_TOP_Y)
filterFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, FILTER_ROW_TOP_Y)
filterFrame:SetHeight(FILTER_ROW_HEIGHT)

-- Second filter row frame (Advanced Search row)
local filterFrame2 = CreateFrame("Frame", nil, frame)
filterFrame2:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -FILTER_ROW_GAP)
filterFrame2:SetPoint("TOPRIGHT", filterFrame, "BOTTOMRIGHT", 0, -FILTER_ROW_GAP)
filterFrame2:SetHeight(FILTER_ROW_HEIGHT)
-- Frame always visible, search boxes toggle
frame.filterFrame2 = filterFrame2

-- Advanced Search toggle button (on filterFrame2, left side)
local advSearchBtn = CreateFrame("Button", nil, filterFrame2, "UIPanelButtonTemplate")
advSearchBtn:SetPoint("LEFT", filterFrame2, "LEFT", 0, 0)
advSearchBtn:SetWidth(120)
advSearchBtn:SetHeight(22)
advSearchBtn:SetText("Advanced Search")
advSearchBtn:SetScript("OnClick", function()
    if frame.advSearchNote:IsVisible() then
        frame.advSearchNote:Hide()
        frame.advSearchOfficerNote:Hide()
        frame.advSearchNoteLabel:Hide()
        frame.advSearchOfficerNoteLabel:Hide()
    else
        frame.advSearchNote:Show()
        frame.advSearchOfficerNote:Show()
        frame.advSearchNoteLabel:Show()
        frame.advSearchOfficerNoteLabel:Show()
    end
end)
frame.advSearchBtn = advSearchBtn

-- Advanced Search filters (name, note, officer note)
local filterWidth = 100
local filterGap = 15

-- Helper function to create search box
local function CreateAdvancedSearchBox(parent, label, xOffset, filterKey)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    labelText:SetText(label .. ":")
    labelText:Hide() -- Hidden by default
    
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
    editBox:SetWidth(filterWidth)
    editBox:SetHeight(22)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    editBox:SetBackdropColor(0, 0, 0, 0.8)
    editBox:SetTextInsets(6, 6, 0, 0)  -- Add left/right padding for text
    editBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if type(text) == "string" then
            frame.advancedFilters[filterKey] = string.lower(text)
        else
            frame.advancedFilters[filterKey] = ""
        end
        IGW:UpdateRosterDisplay()
    end)
    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    editBox:Hide() -- Hidden by default
    
    return editBox, labelText
end

-- Initialize advanced filters table
frame.advancedFilters = {
    note = "",
    officernote = "",
    region = ""
}

-- Create search boxes (removed name field)
local xPos = 130 -- Start after button

local noteBox, noteLabel = CreateAdvancedSearchBox(filterFrame2, "Note", xPos, "note")
frame.advSearchNote = noteBox
frame.advSearchNoteLabel = noteLabel

xPos = xPos + 35 + filterWidth + filterGap

local officerNoteBox, officerNoteLabel = CreateAdvancedSearchBox(filterFrame2, "Officer Note", xPos, "officernote")
frame.advSearchOfficerNote = officerNoteBox
frame.advSearchOfficerNoteLabel = officerNoteLabel

xPos = xPos + 80 + filterWidth + filterGap

-- (Region dropdown moved to main filter bar)

    
    -- Evenly space 4 filter elements across the filter bar
    local filterBarWidth = 590  -- Match main window width
    
    -- Search label and box (element 1)
    local searchLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    searchLabel:SetText("Search:")
    
    -- Search editbox
    local searchBox = CreateFrame("EditBox", nil, filterFrame)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
    searchBox:SetWidth(120)
    searchBox:SetHeight(22)
    searchBox:SetFontObject(GameFontNormal)
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    searchBox:SetBackdropColor(0, 0, 0, 0.8)
    searchBox:SetTextInsets(6, 6, 0, 0)  -- Add left/right padding for text
    searchBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if type(text) == "string" then
            filterText = string.lower(text)
        else
            filterText = ""
        end
        IGW:UpdateRosterDisplay()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    frame.searchBox = searchBox
    
    -- Rank filter label (element 2 - positioned at 1/4 mark + 30px)
    local rankLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetPoint("LEFT", filterFrame, "LEFT", filterBarWidth * 0.25 + 30, 0)
    rankLabel:SetText("Rank:")
    
    -- Rank dropdown
    local rankDropdown = CreateFrame("Button", "IGW_RankDropdown", filterFrame, "UIDropDownMenuTemplate")
    rankDropdown:SetPoint("LEFT", rankLabel, "RIGHT", -15, -2)
    UIDropDownMenu_SetWidth(rankDropdown, 100)
    UIDropDownMenu_SetText(rankDropdown, "All Ranks")
    
    UIDropDownMenu_Initialize(rankDropdown, function()
        local info = {}
        info.text = "All Ranks"
        info.value = -1
        info.func = function()
            filterRank = -1
            UIDropDownMenu_SetText(rankDropdown, "All Ranks")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Add guild ranks
        -- GuildControlGetRankName uses 1-based (1=GM, 2=next, etc)
        -- GetGuildRosterInfo returns 0-based rankIndex (0=GM, 1=next, etc)
        -- So we need to store value as i-1 to match GetGuildRosterInfo
        for i = 1, GuildControlGetNumRanks() do
            local rankName = GuildControlGetRankName(i)
            local rankValue = i - 1  -- Convert to 0-based for matching
            info = {}
            info.text = rankName
            info.value = rankValue
            info.func = function()
                filterRank = rankValue
                UIDropDownMenu_SetText(rankDropdown, rankName)
                IGW:UpdateRosterDisplay()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Region dropdown (element 3 - positioned at 1/2 mark + 40px)
    local regionLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    regionLabel:SetPoint("LEFT", filterFrame, "LEFT", filterBarWidth * 0.5 + 40, 2)
    regionLabel:SetText("Region:")
    
    local regionDropdown = CreateFrame("Frame", "IGW_RegionDropdown", filterFrame, "UIDropDownMenuTemplate")
    regionDropdown:SetPoint("LEFT", regionLabel, "RIGHT", -15, -2)
    UIDropDownMenu_SetWidth(regionDropdown, 90)
    UIDropDownMenu_SetText(regionDropdown, "All")
    frame.regionDropdown = regionDropdown
    
    UIDropDownMenu_Initialize(regionDropdown, function()
        local info = {}
        
        -- All option
        info.text = "All"
        info.value = ""
        info.func = function()
            frame.advancedFilters.region = ""
            UIDropDownMenu_SetText(regionDropdown, "All")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Americas
        info = {}
        info.text = "Americas"
        info.value = "Americas"
        info.func = function()
            frame.advancedFilters.region = "Americas"
            UIDropDownMenu_SetText(regionDropdown, "Americas")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Oceania
        info = {}
        info.text = "Oceania"
        info.value = "Oceania"
        info.func = function()
            frame.advancedFilters.region = "Oceania"
            UIDropDownMenu_SetText(regionDropdown, "Oceania")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Europe
        info = {}
        info.text = "Europe"
        info.value = "Europe"
        info.func = function()
            frame.advancedFilters.region = "Europe"
            UIDropDownMenu_SetText(regionDropdown, "Europe")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        -- Asia
        info = {}
        info.text = "Asia"
        info.value = "Asia"
        info.func = function()
            frame.advancedFilters.region = "Asia"
            UIDropDownMenu_SetText(regionDropdown, "Asia")
            IGW:UpdateRosterDisplay()
        end
        UIDropDownMenu_AddButton(info)
    end)
    
    -- Refresh button (on advanced search row, aligned right)
    local refreshBtn = CreateFrame("Button", nil, filterFrame2, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("RIGHT", filterFrame2, "RIGHT", 0, 0)
    refreshBtn:SetWidth(100)
    refreshBtn:SetHeight(22)
    refreshBtn:SetText("Clear / Refresh")
    refreshBtn:SetScript("OnClick", function()
        -- Clear legacy search box
        if frame.searchBox then
            frame.searchBox:SetText("")
        end
        filterText = ""
        
        -- Clear advanced search boxes
        if frame.advSearchNote then
            frame.advSearchNote:SetText("")
        end
        if frame.advSearchOfficerNote then
            frame.advSearchOfficerNote:SetText("")
        end
        if frame.regionDropdown then
            frame.advancedFilters.region = ""
            UIDropDownMenu_SetText(frame.regionDropdown, "All")
        end
        if frame.advancedFilters then
            frame.advancedFilters.name = ""
            frame.advancedFilters.note = ""
            frame.advancedFilters.officernote = ""
        end
        
        -- Reset rank filter to "All Ranks"
        filterRank = -1
        if rankDropdown then
            UIDropDownMenu_SetText(rankDropdown, "All Ranks")
        end
        
        -- Reset sorting to default
        sortColumn = "rank"
        sortAscending = false
        
        -- Update header arrows
        if frame.headerButtons then
            for _, btn in ipairs(frame.headerButtons) do
                if btn.column == sortColumn then
                    btn.arrow:SetText(sortAscending and "^" or "v")
                else
                    btn.arrow:SetText("")
                end
            end
        end
        
        -- Refresh guild roster
        GuildRoster()
        IGW:UpdateRosterDisplay()
    end)
    
    -- Show Offline checkbox (element 4 - positioned at 3/4 mark + 65px, aligned with search text)
    local offlineCheck = CreateFrame("CheckButton", "IGW_OfflineCheck", filterFrame, "UICheckButtonTemplate")
    offlineCheck:SetPoint("LEFT", filterFrame, "LEFT", filterBarWidth * 0.75 + 65, 0)
    offlineCheck:SetWidth(24)
    offlineCheck:SetHeight(24)
    offlineCheck:SetChecked(showOffline)
    
    local offlineLabel = offlineCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offlineLabel:SetPoint("LEFT", offlineCheck, "RIGHT", 0, 0)
    offlineLabel:SetText("Show Offline")
    
    offlineCheck:SetScript("OnClick", function()
        showOffline = this:GetChecked() == 1
        if ImprovedGuildWindowDB then
            ImprovedGuildWindowDB.showOffline = showOffline
        end
        IGW:UpdateRosterDisplay()
    end)
    
    frame.offlineCheck = offlineCheck
end

-- Create column headers
function IGW:CreateColumnHeaders()
    local headerFrame = CreateFrame("Frame", nil, frame)
    local headerTopY = IGW_GetHeaderTopY()
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, headerTopY)
    headerFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, headerTopY)
local headerTopY = IGW_GetHeaderTopY()
headerFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -90)
    headerFrame:SetHeight(20)
    
    frame.headerFrame = headerFrame
    frame.headerButtons = {}
    
    -- Initial headers will be set by UpdateColumnHeaders
end

-- Create roster scroll frame
function IGW:CreateRosterScrollFrame()
    -- Create scroll frame with FauxScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "IGW_RosterScroll", frame, "FauxScrollFrameTemplate")
    local headerTopY = IGW_GetHeaderTopY()
-- Scroll starts below the header row (20px header + ~5px breathing room)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, headerTopY - 25)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 50)
    scrollFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- In 3.3.5, FauxScrollFrame template creates a ScrollBar child automatically
    -- We just need to set up the update callback
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT_DEFAULT, IGW.UpdateRosterDisplay)
    end)
    
    -- Create row frames as children of main frame
    local rows = {}
    for i = 1, 15 do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(590)
        row:SetHeight(ROW_HEIGHT_DEFAULT)
        row:SetFrameLevel(frame:GetFrameLevel() + 2)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        
        -- Position relative to main frame, accounting for scroll frame position
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, (headerTopY - 30) - (i-1) * ROW_HEIGHT_DEFAULT)
        
        -- Name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("LEFT", row, "LEFT", 5, 0)
        name:SetWidth(105)
        name:SetJustifyH("LEFT")
        row.name = name
        
        -- Level
        local level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        level:SetPoint("LEFT", row, "LEFT", 115, 0)
        level:SetWidth(35)
        level:SetJustifyH("CENTER")
        row.level = level
        
        -- Class (reuse for rank in roster view)
        local class = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        class:SetPoint("LEFT", row, "LEFT", 155, 0)
        class:SetWidth(85)
        class:SetJustifyH("LEFT")
        row.class = class
        
        -- Race
        local race = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        race:SetPoint("LEFT", row, "LEFT", 245, 0)
        race:SetWidth(75)
        race:SetJustifyH("LEFT")
        row.race = race
        
        -- Faction
        local faction = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        faction:SetPoint("LEFT", row, "LEFT", 325, 0)
        faction:SetWidth(50)
        faction:SetJustifyH("LEFT")
        row.faction = faction
        
        -- Rank (reuse for note in roster view) - shifted right
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rank:SetPoint("LEFT", row, "LEFT", 380, 0)
        rank:SetWidth(85)
        rank:SetJustifyH("LEFT")
        row.rank = rank
        
        -- Note (reuse for officer note in roster view)
        local note = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        note:SetPoint("LEFT", row, "LEFT", 355, 0)
        note:SetWidth(105)
        note:SetJustifyH("LEFT")
        row.note = note
        
        -- Officer Note (reuse for last online in roster view)
        local officerNote = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        officerNote:SetPoint("LEFT", row, "LEFT", 465, 0)
        officerNote:SetWidth(75)
        officerNote:SetJustifyH("LEFT")
        row.officerNote = officerNote
        
        -- Click to show member details
        row:SetScript("OnClick", function()
            if row.memberIndex then
                IGW:ShowMemberDetails(row.memberIndex)
            end
        end)
        
        table.insert(rows, row)
    end
    
    frame.rosterRows = rows
    frame.rosterScroll = scrollFrame
end

-- Create tabs at bottom of window
function IGW:CreateTabs()
    local tabHeight = 25
    
    -- All 4 tabs evenly distributed across bottom
    local tabWidth = 120
    local tabGap = 10
    
    -- Calculate positions for 4 evenly spaced tabs
    local windowWidth = 620  -- Main window width
    local totalTabWidth = (tabWidth * 4)
    local totalGapSpace = windowWidth - totalTabWidth
    local gapSize = totalGapSpace / 5  -- 5 gaps: left, between tabs (3), right
    
    -- Tab 4: Guild Info (far left, evenly spaced)
    local tab4 = CreateFrame("Button", nil, frame)
    tab4:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", gapSize, 15)
    tab4:SetWidth(tabWidth)
    tab4:SetHeight(tabHeight)
    tab4:SetFrameLevel(frame:GetFrameLevel() + 1)

    tab4:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab4:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab4:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local tab4Text = tab4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab4Text:SetPoint("CENTER", tab4, "CENTER", 0, 0)
    tab4Text:SetText("|cFFFF0000<|r Guild Info")  -- Red left arrow before text
    tab4Text:SetTextColor(0.7, 0.7, 0.7)

    tab4:SetScript("OnClick", function()
        IGW:ToggleGuildInfoWindow()
    end)
    
    -- Tab 1: Guild Members
    local tab1 = CreateFrame("Button", nil, frame)
    tab1:SetPoint("LEFT", tab4, "RIGHT", gapSize, 0)
    tab1:SetWidth(tabWidth)
    tab1:SetHeight(tabHeight)
    tab1:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for tab
    tab1:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab1:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab1:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local tab1Text = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab1Text:SetPoint("CENTER", tab1, "CENTER", 0, 0)
    tab1Text:SetText("Guild Members")
    
    tab1:SetScript("OnClick", function()
        IGW:SwitchTab("details")
    end)
    
    -- Tab 2: Notes & Rank
    local tab2 = CreateFrame("Button", nil, frame)
    tab2:SetPoint("LEFT", tab1, "RIGHT", gapSize, 0)
    tab2:SetWidth(tabWidth)
    tab2:SetHeight(tabHeight)
    tab2:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for tab
    tab2:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab2:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab2:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local tab2Text = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab2Text:SetPoint("CENTER", tab2, "CENTER", 0, 0)
    tab2Text:SetText("Notes & Rank")
    
    tab2:SetScript("OnClick", function()
        IGW:SwitchTab("roster")
    end)
    
    -- Tab 3: Detailed View
    local tab3 = CreateFrame("Button", nil, frame)
    tab3:SetPoint("LEFT", tab2, "RIGHT", gapSize, 0)
    tab3:SetWidth(tabWidth)
    tab3:SetHeight(tabHeight)
    tab3:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for tab
    tab3:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
    tab3:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local tab3Text = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab3Text:SetPoint("CENTER", tab3, "CENTER", 0, 0)
    tab3Text:SetText("Detailed View")
    
    tab3:SetScript("OnClick", function()
        IGW:SwitchTab("detailed")
    end)

    frame.tab1 = tab1
    frame.tab2 = tab2
    frame.tab3 = tab3
    frame.tab1Text = tab1Text
    frame.tab2Text = tab2Text
    frame.tab3Text = tab3Text
    frame.tab4 = tab4
    frame.tab4Text = tab4Text
end

-- Switch between tabs
function IGW:SwitchTab(tabName)
    currentTab = tabName
    
    if tabName == "details" then
        -- Activate Guild Members tab (tab1)
        frame.tab1:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab2:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab1Text:SetTextColor(1, 1, 1)
        frame.tab2Text:SetTextColor(0.7, 0.7, 0.7)
        frame.tab3Text:SetTextColor(0.7, 0.7, 0.7)
        
        -- Set default sorting (only if not remembering)
        if not ImprovedGuildWindowDB or ImprovedGuildWindowDB.rememberSorting == false then
            sortColumn = "rank"
            sortAscending = false  -- Descending
        end
        
        -- Hide offline by default
        showOffline = false
        if frame.offlineCheck then
            frame.offlineCheck:SetChecked(false)
        end
        
        -- Show details columns
        IGW:UpdateColumnHeaders("details")
    elseif tabName == "roster" then
        -- Activate Notes & Rank tab (tab2)
        frame.tab1:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab2:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab3:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab1Text:SetTextColor(0.7, 0.7, 0.7)
        frame.tab2Text:SetTextColor(1, 1, 1)
        frame.tab3Text:SetTextColor(0.7, 0.7, 0.7)
        
        -- Set default sorting (only if not remembering)
        if not ImprovedGuildWindowDB or ImprovedGuildWindowDB.rememberSorting == false then
            sortColumn = "rank"
            sortAscending = false  -- Descending
        end
        
        -- Show offline on this tab (use saved preference)
        showOffline = (ImprovedGuildWindowDB and ImprovedGuildWindowDB.showOffline ~= false)
        if frame.offlineCheck then
            frame.offlineCheck:SetChecked(showOffline)
        end
        
        -- Show roster columns
        IGW:UpdateColumnHeaders("roster")
    elseif tabName == "detailed" then
        -- Activate Detailed View tab (tab3)
        frame.tab1:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab2:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab3:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab1Text:SetTextColor(0.7, 0.7, 0.7)
        frame.tab2Text:SetTextColor(0.7, 0.7, 0.7)
        frame.tab3Text:SetTextColor(1, 1, 1)
        
        -- Set default sorting (only if not remembering)
        if not ImprovedGuildWindowDB or ImprovedGuildWindowDB.rememberSorting == false then
            sortColumn = "name"
            sortAscending = true
        end
        
        -- Show all members including offline
        showOffline = true
        if frame.offlineCheck then
            frame.offlineCheck:SetChecked(true)
        end
        
        -- Show detailed view columns
        IGW:UpdateColumnHeaders("detailed")
    end
    
    -- Update header arrows to show current sort state
    if frame.headerButtons then
        for _, btn in ipairs(frame.headerButtons) do
            if btn.column == sortColumn then
                btn.arrow:SetText(sortAscending and "^" or "v")
            else
                btn.arrow:SetText("")
            end
        end
    end
    
    IGW:UpdateRosterDisplay()
end

-- Update column headers based on tab
function IGW:UpdateColumnHeaders(tabName)
    -- Hide all existing header buttons
    if frame.headerButtons then
        for _, btn in ipairs(frame.headerButtons) do
            btn:Hide()
        end
    end
    
    frame.headerButtons = {}
    
    local headers
    if tabName == "roster" then
headers = {
    {text = "Name",         width = 95,  column = "name"},
    {text = "Level",        width = 55,  column = "level"},
    {text = "Rank",         width = 80,  column = "rank"},
    {text = "Note",         width = 140, column = "note"},        -- narrowed
    {text = "Officer Note", width = 140, column = "officernote"}, -- narrowed
    {text = "Last Online",  width = 80,  column = "lastonline"}
}
    elseif tabName == "detailed" then
        headers = {
            {text = "Name", width = 140, column = "name"},
            {text = "Level", width = 60, column = "level"},
            {text = "Rank", width = 120, column = "rank"},
            {text = "Date Joined", width = 110, column = "datejoined"},
            {text = "Time Zone", width = 190, column = "timezone"}
        }
    else
        headers = {
            {text = "Name", width = 110, column = "name"},
            {text = "Level", width = 60, column = "level"},
            {text = "Class", width = 75, column = "class"},
            {text = "Race", width = 75, column = "race"},
            {text = "A/H", width = 50, column = "faction"},
            {text = "Location", width = 145, column = "zone"},
            {text = "Rank", width = 85, column = "rank"}
        }
    end
    
    local headerFrame = frame.headerFrame
    local xPos = 0
    for _, header in ipairs(headers) do
        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetPoint("LEFT", headerFrame, "LEFT", xPos, 0)
        btn:SetWidth(header.width)
        btn:SetHeight(20)
        
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 5, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -15, 0)
        text:SetJustifyH("LEFT")
        text:SetText(header.text)
        
        -- Sort arrow
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        arrow:SetJustifyH("RIGHT")
        arrow:SetText("")
        btn.arrow = arrow
        btn.column = header.column
        
        btn:SetScript("OnClick", function()
            IGW:SortRoster(this.column)
        end)
        
        -- Highlight on hover
        btn:SetScript("OnEnter", function()
            text:SetTextColor(1, 1, 0)
        end)
        btn:SetScript("OnLeave", function()
            text:SetTextColor(1, 1, 1)
        end)
        
        if header.column == sortColumn then
            arrow:SetText(sortAscending and "^" or "v")
        end
        
        btn:Show()
        xPos = xPos + header.width
        
        table.insert(frame.headerButtons, btn)
    end

    -- Keep row columns aligned with header columns
    self:ApplyRowLayout(tabName, headers)
end

-- Apply header-aligned column positions and widths to roster rows (keeps headers + data perfectly lined up)
function IGW:ApplyRowLayout(tabName, headers)
    if not frame or not frame.rosterRows or not headers then return end

    -- Build x positions for each header column
    local xPos = 0
    local colX = {}
    local colW = {}
    for _, h in ipairs(headers) do
        colX[h.column] = xPos
        colW[h.column] = h.width
        xPos = xPos + h.width
    end

    for _, row in ipairs(frame.rosterRows) do
        -- Ensure everything is left-justified for a clean grid
        row.name:SetJustifyH("LEFT")
        row.level:SetJustifyH("LEFT")
        row.class:SetJustifyH("LEFT")
        row.race:SetJustifyH("LEFT")
        row.faction:SetJustifyH("LEFT")
        row.rank:SetJustifyH("LEFT")
        row.note:SetJustifyH("LEFT")
        row.officerNote:SetJustifyH("LEFT")

        if tabName == "roster" then
            -- Member Details tab uses: name, level, (rank -> row.class), (note -> row.rank),
            -- (officer note -> row.note), (last online -> row.officerNote)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", colX["name"] + 5, 0)
            row.name:SetWidth(colW["name"] - 10)

            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row, "LEFT", colX["level"] + 5, 0)
            row.level:SetWidth(colW["level"] - 10)

            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row, "LEFT", colX["rank"] + 5, 0)
            row.class:SetWidth(colW["rank"] - 10)

            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row, "LEFT", colX["note"] + 5, 0)
            row.rank:SetWidth(colW["note"] - 10)

            row.note:ClearAllPoints()
            row.note:SetPoint("LEFT", row, "LEFT", colX["officernote"] + 5, 0)
            row.note:SetWidth(colW["officernote"] - 10)

            row.officerNote:ClearAllPoints()
            row.officerNote:SetPoint("LEFT", row, "LEFT", colX["lastonline"] + 5, 0)
            row.officerNote:SetWidth(colW["lastonline"] - 10)
        elseif tabName == "detailed" then
            -- Detailed View tab uses: name, level, (rank -> row.class), (datejoined -> row.rank),
            -- (timezone -> row.note)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", colX["name"] + 5, 0)
            row.name:SetWidth(colW["name"] - 10)

            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row, "LEFT", colX["level"] + 5, 0)
            row.level:SetWidth(colW["level"] - 10)

            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row, "LEFT", colX["rank"] + 5, 0)
            row.class:SetWidth(colW["rank"] - 10)

            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row, "LEFT", colX["datejoined"] + 5, 0)
            row.rank:SetWidth(colW["datejoined"] - 10)

            row.note:ClearAllPoints()
            row.note:SetPoint("LEFT", row, "LEFT", colX["timezone"] + 5, 0)
            row.note:SetWidth(colW["timezone"] - 10)

            -- Not used in this view
            row.officerNote:SetText("")
            row.race:SetText("")
            row.faction:SetText("")
        else
            -- Guild Members tab uses: name, level, class, race, faction, (location -> row.rank), (rank -> row.note)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", colX["name"] + 5, 0)
            row.name:SetWidth(colW["name"] - 10)

            row.level:ClearAllPoints()
            row.level:SetPoint("LEFT", row, "LEFT", colX["level"] + 5, 0)
            row.level:SetWidth(colW["level"] - 10)

            row.class:ClearAllPoints()
            row.class:SetPoint("LEFT", row, "LEFT", colX["class"] + 5, 0)
            row.class:SetWidth(colW["class"] - 10)

            row.race:ClearAllPoints()
            row.race:SetPoint("LEFT", row, "LEFT", colX["race"] + 5, 0)
            row.race:SetWidth(colW["race"] - 10)

            row.faction:ClearAllPoints()
            row.faction:SetPoint("LEFT", row, "LEFT", colX["faction"] + 5, 0)
            row.faction:SetWidth(colW["faction"] - 10)

            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row, "LEFT", colX["zone"] + 5, 0)
            row.rank:SetWidth(colW["zone"] - 10)

            row.note:ClearAllPoints()
            row.note:SetPoint("LEFT", row, "LEFT", colX["rank"] + 5, 0)
            row.note:SetWidth(colW["rank"] - 10)

            -- Not used in this view
            row.officerNote:SetText("")
        end
    end
end

-- Show officer note edit dialog
function IGW:ShowOfficerNoteEdit(index, memberName)
    -- Use default WoW dialog
    SetGuildRosterSelection(index)
    StaticPopup_Show("SET_GUILDOFFICERNOTE")
end

-- Show public note edit dialog
function IGW:ShowPublicNoteEdit(index, memberName)
    -- Use default WoW dialog
    SetGuildRosterSelection(index)
    StaticPopup_Show("SET_GUILDPLAYERNOTE")
end

-- Show member details window
function IGW:ShowMemberDetails(index)
    local member = rosterData[index]
    if not member then return end
    
    -- Create details frame if it doesn't exist
    if not IGW.detailsFrame then
        local df = CreateFrame("Frame", "IGW_DetailsFrame", UIParent)
        IGW_AddToSpecialFrames("IGW_DetailsFrame", true)
        df:SetWidth(250)
        df:SetHeight(frame:GetHeight())
        df:SetFrameStrata("HIGH")
        df:SetFrameLevel(30)
        -- Only allow moving if setting is enabled
        df:SetMovable((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        df:EnableMouse(true)
        df:SetClampedToScreen(true)
        df:Hide()
        
        -- Background (border only, solid texture added separately)
        df:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        df:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local dfBgTexture = df:CreateTexture(nil, "BACKGROUND")
        dfBgTexture:SetPoint("TOPLEFT", df, "TOPLEFT", 11, -12)
        dfBgTexture:SetPoint("BOTTOMRIGHT", df, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        dfBgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        df.bgTexture = dfBgTexture
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, df)
        titleBar:SetPoint("TOPLEFT", df, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", df, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(df:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function()
            if df:IsMovable() then
                df:StartMoving()
            end
        end)
        titleBar:SetScript("OnDragStop", function()
            if df:IsMovable() then
                df:StopMovingOrSizing()
            end
        end)
        
        -- Title text
        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Member Details")
        df.title = title
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, df, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", df, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(df:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function()
            df:Hide()
        end)
        
        -- Content area
        local yOffset = -50
        local leftX = 20
        
        -- Name
        local nameLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        nameLabel:SetText("Name:")
        
        local nameValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameValue:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameValue:SetText("")
        df.nameValue = nameValue
        
        yOffset = yOffset - 20
        
        -- Level & Class
        local levelLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        levelLabel:SetText("Level:")
        
        local levelValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 10, 0)
        levelValue:SetText("")
        df.levelValue = levelValue
        
        local classValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        classValue:SetPoint("LEFT", levelValue, "RIGHT", 10, 0)
        classValue:SetText("")
        df.classValue = classValue
        
        yOffset = yOffset - 20
        
        -- Rank
        local rankLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        rankLabel:SetText("Rank:")
        
        local rankValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rankValue:SetPoint("LEFT", rankLabel, "RIGHT", 10, 0)
        rankValue:SetText("")
        df.rankValue = rankValue
        
        yOffset = yOffset - 20
        
        -- Zone
        local zoneLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        zoneLabel:SetText("Zone:")
        
        local zoneValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        zoneValue:SetPoint("LEFT", zoneLabel, "RIGHT", 10, 0)
        zoneValue:SetWidth(150)
        zoneValue:SetJustifyH("LEFT")
        zoneValue:SetText("")
        df.zoneValue = zoneValue
        
        yOffset = yOffset - 20
        
        -- Online status
        local onlineLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        onlineLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        onlineLabel:SetText("Status:")
        
        local onlineValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        onlineValue:SetPoint("LEFT", onlineLabel, "RIGHT", 10, 0)
        onlineValue:SetText("")
        df.onlineValue = onlineValue
        
        yOffset = yOffset - 20
        
        -- Date Joined
        local dateJoinedLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dateJoinedLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        dateJoinedLabel:SetText("Date Joined:")
        
        local dateJoinedValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dateJoinedValue:SetPoint("LEFT", dateJoinedLabel, "RIGHT", 10, 0)
        dateJoinedValue:SetText("")
        df.dateJoinedValue = dateJoinedValue
        
        yOffset = yOffset - 20
        
        -- Time Zone
        local timeZoneLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeZoneLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        timeZoneLabel:SetText("Time Zone:")
        
        local timeZoneValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timeZoneValue:SetPoint("LEFT", timeZoneLabel, "RIGHT", 10, 0)
        timeZoneValue:SetText("")
        df.timeZoneValue = timeZoneValue
        
        -- Faction icon (top right, above divider)
        local factionIcon = df:CreateTexture(nil, "ARTWORK")
        factionIcon:SetWidth(48)
        factionIcon:SetHeight(48)
        factionIcon:SetPoint("TOPRIGHT", df, "TOPRIGHT", -12, -40)
        factionIcon:Hide() -- Hidden by default
        df.factionIcon = factionIcon
        
        yOffset = yOffset - 30
        
        -- Divider 1 (after status info)
        local div1 = df:CreateTexture(nil, "ARTWORK")
        div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div1:SetPoint("TOP", df, "TOP", 36, yOffset)
        div1:SetWidth(300)
        div1:SetHeight(16)
        df.div1 = div1
        
        yOffset = yOffset - 16

-- Public Note
local noteLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
noteLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
noteLabel:SetText("Public Note:")
df.noteLabel = noteLabel

-- Make heading clickable
local noteLabelBtn = CreateFrame("Button", nil, df)
noteLabelBtn:SetPoint("TOPLEFT", noteLabel, "TOPLEFT", -2, 2)
noteLabelBtn:SetPoint("BOTTOMRIGHT", noteLabel, "BOTTOMRIGHT", 2, -2)
noteLabelBtn:SetFrameLevel(df:GetFrameLevel() + 1)
noteLabelBtn:SetScript("OnClick", function()
    if df.memberIndex and (not CanEditPublicNote or CanEditPublicNote()) then
        IGW:ShowPublicNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 18

local noteValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
noteValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
noteValue:SetWidth(210)
noteValue:SetJustifyH("LEFT")
noteValue:SetText("")
df.noteValue = noteValue

local noteValueBtn = CreateFrame("Button", nil, df)
noteValueBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX - 2, yOffset + 2)
noteValueBtn:SetWidth(214)
noteValueBtn:SetHeight(40)
noteValueBtn:SetFrameLevel(df:GetFrameLevel() + 1)
noteValueBtn:SetScript("OnClick", function()
    if df.memberIndex and (not CanEditPublicNote or CanEditPublicNote()) then
        IGW:ShowPublicNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 48

-- Officer Note (clickable label)
local officerNoteLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
officerNoteLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
officerNoteLabel:SetText("Officer Note:")
df.officerNoteLabel = officerNoteLabel

-- Make label clickable
local officerNoteLabelBtn = CreateFrame("Button", nil, df)
officerNoteLabelBtn:SetPoint("TOPLEFT", officerNoteLabel, "TOPLEFT", -2, 2)
officerNoteLabelBtn:SetPoint("BOTTOMRIGHT", officerNoteLabel, "BOTTOMRIGHT", 2, -2)
officerNoteLabelBtn:SetFrameLevel(df:GetFrameLevel() + 1)
officerNoteLabelBtn:SetScript("OnClick", function()
    if df.memberIndex and CanEditOfficerNote() then
        IGW:ShowOfficerNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 18

-- Officer Note Value (clickable)
local officerNoteValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
officerNoteValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
officerNoteValue:SetWidth(210)
officerNoteValue:SetJustifyH("LEFT")
officerNoteValue:SetText("")
df.officerNoteValue = officerNoteValue

local officerNoteValueBtn = CreateFrame("Button", nil, df)
officerNoteValueBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX - 2, yOffset + 2)
officerNoteValueBtn:SetWidth(214)
officerNoteValueBtn:SetHeight(40)
officerNoteValueBtn:SetFrameLevel(df:GetFrameLevel() + 1)
officerNoteValueBtn:SetScript("OnClick", function()
    if df.memberIndex and CanEditOfficerNote() then
        IGW:ShowOfficerNoteEdit(df.memberIndex, df.memberName)
    end
end)

yOffset = yOffset - 48

        -- Divider 2 (after officer notes)
        local div2 = df:CreateTexture(nil, "ARTWORK")
        div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div2:SetPoint("TOP", df, "TOP", 36, yOffset)
        div2:SetWidth(300)
        div2:SetHeight(16)
        df.div2 = div2
        
        yOffset = yOffset - 16

        -- Whisper + Invite buttons (even spacing)
local buttonYGap = 8
local buttonGap = 10
local whisperWidth = 80
local inviteWidth = 120
local buttonHeight = 22

local whisperBtn = CreateFrame("Button", nil, df, "UIPanelButtonTemplate")
whisperBtn:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
whisperBtn:SetWidth(whisperWidth)
whisperBtn:SetHeight(buttonHeight)
whisperBtn:SetFrameLevel(df:GetFrameLevel() + 1)
whisperBtn:SetText("Whisper")
whisperBtn:SetScript("OnClick", function()
    if df.memberName then
        ChatFrame_OpenChat("/w " .. df.memberName .. " ", DEFAULT_CHAT_FRAME)
    end
end)
df.whisperBtn = whisperBtn

local inviteBtn = CreateFrame("Button", nil, df, "UIPanelButtonTemplate")
inviteBtn:SetPoint("LEFT", whisperBtn, "RIGHT", buttonGap, 0)
inviteBtn:SetWidth(inviteWidth)
inviteBtn:SetHeight(buttonHeight)
inviteBtn:SetFrameLevel(df:GetFrameLevel() + 1)
inviteBtn:SetText("Invite to Group")
inviteBtn:SetScript("OnClick", function()
    if df.memberName then
        InviteByName(df.memberName)
    end
end)
df.inviteBtn = inviteBtn

yOffset = yOffset - (buttonHeight + buttonYGap)

        -- Divider 3 (after buttons)
        local div3 = df:CreateTexture(nil, "ARTWORK")
        div3:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        div3:SetPoint("TOP", df, "TOP", 36, yOffset)
        div3:SetWidth(300)
        div3:SetHeight(16)
        df.div3 = div3
        
        yOffset = yOffset - 16
        
        -- Alts section
        local altsLabel = df:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        altsLabel:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        altsLabel:SetText("Other Characters:")
        df.altsLabel = altsLabel
        
        yOffset = yOffset - 18
        
        local altsValue = df:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        altsValue:SetPoint("TOPLEFT", df, "TOPLEFT", leftX, yOffset)
        altsValue:SetWidth(210)
        altsValue:SetJustifyH("LEFT")
        altsValue:SetText("—")
        df.altsValue = altsValue

        IGW.detailsFrame = df
    end
    
    -- Populate with member data
    local df = IGW.detailsFrame
    df.memberIndex = index
    df.memberName = member.name
    df.memberData = member  -- Store full member data
    
    -- Set values
    df.nameValue:SetText(member.name or "Unknown")
    
    -- Get race from officer note
    local race = IGW_GetRace(member.officernote or "")
    
    -- Get class color
    local color = CLASS_COLORS[member.class] or {r=1, g=1, b=1}
    local classColorCode = string.format("|cFF%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    
    -- Build level display: "Level Race Class" with class colored
    local levelText = tostring(member.level or "?")
    if race ~= "" then
        levelText = levelText .. " " .. race
    end
    levelText = levelText .. " " .. classColorCode .. (member.class or "") .. "|r"
    
    df.levelValue:SetText(levelText)
    
    -- Clear the separate class field (now included in levelValue)
    df.classValue:SetText("")
    
    df.rankValue:SetText(member.rank or "")
    df.zoneValue:SetText(member.zone or "Unknown")
    
    -- Online status
    if member.online then
        df.onlineValue:SetTextColor(0, 1, 0)
        df.onlineValue:SetText("Online")
    else
        df.onlineValue:SetTextColor(0.5, 0.5, 0.5)
        df.onlineValue:SetText("Offline")
    end
    
    -- Date Joined and Time Zone (extract from officer note)
    -- Format: RaceCode-MMDDYYTTT or just MMDDYYTTT (if no race code) or just TT (timezone only)
    -- Example: O-030125PST or 030125PST or O-030125 (no timezone) or O-PST (just timezone)
    local dateJoined = "—"
    local timeZone = "—"
    local officerNote = member.officernote or ""
    
    -- First try to find 6 digits + 3 letters (date with timezone)
    local _, _, dateStr, tzStr = string.find(officerNote, "(%d%d%d%d%d%d)(%a%a%a)")
    
    -- If no timezone found with date, try to find just 6 digits (date only)
    if not dateStr then
        _, _, dateStr = string.find(officerNote, "(%d%d%d%d%d%d)")
    end
    
    -- If still no timezone found, try to find just 3 letters (timezone only)
    if not tzStr then
        -- Look for 3 consecutive letters that match a known timezone
        for tz, _ in pairs(TIMEZONES) do
            if string.find(officerNote, tz) then
                tzStr = tz
                break
            end
        end
    end
    
    if dateStr then
        -- Parse MMDDYY
        local month = string.sub(dateStr, 1, 2)
        local day = string.sub(dateStr, 3, 4)
        local year = string.sub(dateStr, 5, 6)
        
        -- Format as MM/DD/YY
        dateJoined = month .. "/" .. day .. "/" .. year
    end
    
    -- Look up timezone full name if we have one
    if tzStr then
        timeZone = TIMEZONES[tzStr] or tzStr
    end
    
    df.dateJoinedValue:SetText(dateJoined)
    df.timeZoneValue:SetText(timeZone)
    
    -- Faction icon
    local faction = IGW_GetFaction(race)
    if faction == "Alliance" then
        df.factionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
        df.factionIcon:Show()
    elseif faction == "Horde" then
        df.factionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
        df.factionIcon:Show()
    else
        df.factionIcon:Hide() -- No faction data
    end
    
    df.noteValue:SetText(member.note or "")
    
    -- Officer note (only if can view)
    if CanViewOfficerNote() then
        df.officerNoteLabel:Show()
        df.officerNoteValue:Show()
        df.officerNoteValue:SetText(member.officernote or "")
    else
        -- Hide officer note section when user can't view
        df.officerNoteLabel:Hide()
        df.officerNoteValue:Hide()
    end
    
    -- Find alts: bidirectional detection
    -- 1. Find characters with "alt of [current player]"
    -- 2. If current player is an alt, find the main and all other alts
    local alts = {}
    local searchName = string.lower(member.name or "")
    local mainCharacter = nil
    
    -- Helper function to check for exact name match with word boundaries
    local function hasExactNameMatch(note, name)
        if string.find(note, "^" .. name .. "[%s%p]") or  -- Start of string
           string.find(note, "[%s%p]" .. name .. "$") or  -- End of string
           string.find(note, "[%s%p]" .. name .. "[%s%p]") or  -- Middle
           note == name then  -- Exact match only
            return true
        end
        return false
    end
    
    -- Check if current character is an alt (has "alt of X" in their note)
    if member.note then
        local currentNote = string.lower(member.note)
        if string.find(currentNote, "alt") then
            -- Extract main character name from note
            for _, guildMember in ipairs(rosterData) do
                if guildMember.name ~= member.name then
                    local testName = string.lower(guildMember.name)
                    if hasExactNameMatch(currentNote, testName) then
                        mainCharacter = guildMember.name
                        break
                    end
                end
            end
        end
    end
    
    -- If we found a main character, search for all alts of that main
    if mainCharacter then
        local mainNameLower = string.lower(mainCharacter)
        
        -- Add the main character to the list
        table.insert(alts, mainCharacter)
        
        -- Find all other alts of this main
        for _, guildMember in ipairs(rosterData) do
            if guildMember.name ~= member.name and guildMember.note then
                local note = string.lower(guildMember.note)
                if string.find(note, "alt") and hasExactNameMatch(note, mainNameLower) then
                    table.insert(alts, guildMember.name)
                end
            end
        end
    else
        -- Current character is the main, find their alts
        for _, guildMember in ipairs(rosterData) do
            if guildMember.name ~= member.name and guildMember.note then
                local note = string.lower(guildMember.note)
                if string.find(note, "alt") and hasExactNameMatch(note, searchName) then
                    table.insert(alts, guildMember.name)
                end
            end
        end
    end
    
    -- Display alts
    if table.getn(alts) > 0 then
        df.altsLabel:Show()
        df.altsValue:Show()
        df.div3:Show()
        df.altsValue:SetText(table.concat(alts, ", "))
    else
        -- Hide alts section when no alts found
        df.altsLabel:Hide()
        df.altsValue:Hide()
        df.div3:Hide()
    end
    -- Position to the right of main window with 5px gap, same top alignment
    df:ClearAllPoints()
    df:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
    df:SetHeight(frame:GetHeight())

    df:Show()
end

-- Update opacity of windows
function IGW:UpdateOpacity()
    -- Background opacity is fixed in v1.2
    local opacity = IGW_BG_OPACITY

    if frame then
        frame:SetBackdropColor(0, 0, 0, opacity)
    end

    if IGW.detailsFrame then
        IGW.detailsFrame:SetBackdropColor(0, 0, 0, opacity)
    end
end

-- Save window position

function IGW:SavePosition()
    if not ImprovedGuildWindowDB then return end
    local point, _, _, x, y = frame:GetPoint()
    ImprovedGuildWindowDB.position = {
        point = point,
        x = x,
        y = y
    }
end

-- Register events
function IGW:RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "PLAYER_LOGIN" then
            IGW:OnPlayerLogin()
        elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
            IGW:UpdateGuildData()
        end
    end)
end

-- Handle player login
function IGW:OnPlayerLogin()
    -- Initialize SavedVariables and create main frame now that SavedVariables are loaded
    self:InitializeSavedVariables()
    
    if IsInGuild() then
        GuildRoster()
    end
end

-- Update guild data
function IGW:UpdateGuildData()
    rosterData = {}
    local numMembers = GetNumGuildMembers(true)
    
    -- Update window title with guild name
    if frame and frame.titleText then
        local guildName = GetGuildInfo("player")
        if guildName then
            frame.titleText:SetText(guildName)
        end
    end
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        
        -- Get last online time (years, months, days, hours)
        local yearsOffline, monthsOffline, daysOffline, hoursOffline = GetGuildRosterLastOnline(i)
        
        table.insert(rosterData, {
            name = name,
            rank = rank,
            rankIndex = rankIndex,
            level = level,
            class = class,
            zone = zone,
            note = note,
            officernote = officernote,
            online = online,
            status = status,
            yearsOffline = yearsOffline,
            monthsOffline = monthsOffline,
            daysOffline = daysOffline,
            hoursOffline = hoursOffline
        })
    end
    
    self:UpdateRosterDisplay()
    if IGW.infoFrame and IGW.infoFrame:IsVisible() then
        IGW:UpdateGuildInfoWindow()
    end
end

-- Sort roster
function IGW:SortRoster(column)
    if sortColumn == column then
        sortAscending = not sortAscending
    else
        sortColumn = column
        -- Level defaults to descending (high to low), others ascending
        sortAscending = (column ~= "level")
    end
    
    if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberSorting ~= false then
        ImprovedGuildWindowDB.sortColumn = sortColumn
        ImprovedGuildWindowDB.sortAscending = sortAscending
    end
    
    -- Update header arrows
    if frame.headerButtons then
        for _, btn in ipairs(frame.headerButtons) do
            if btn.column == sortColumn then
                btn.arrow:SetText(sortAscending and "^" or "v")
            else
                btn.arrow:SetText("")
            end
        end
    end
    
    self:UpdateRosterDisplay()
end

-- Filter and display roster
function IGW:UpdateRosterDisplay()
    if not frame or not frame:IsVisible() then return end
    if not frame.rosterRows or not frame.rosterScroll then return end
    
    displayedMembers = {}
    
    -- Filter members
    for i, member in ipairs(rosterData) do
        local show = true
        
        -- Text filter (legacy search box)
        if filterText ~= "" then
            local searchIn = string.lower(member.name or "") .. 
                           string.lower(member.class or "") .. 
                           string.lower(member.rank or "") .. 
                           string.lower(member.note or "") .. 
                           string.lower(member.officernote or "")
            if not string.find(searchIn, filterText, 1, true) then
                show = false
            end
        end
        
        -- Advanced filters (individual column searches)
        if show and frame.advancedFilters then
            if show and frame.advancedFilters.note ~= "" then
                local noteSearch = string.lower(member.note or "")
                if not string.find(noteSearch, frame.advancedFilters.note, 1, true) then
                    show = false
                end
            end
            
            if show and frame.advancedFilters.officernote ~= "" then
                local officerNoteSearch = string.lower(member.officernote or "")
                if not string.find(officerNoteSearch, frame.advancedFilters.officernote, 1, true) then
                    show = false
                end
            end
            
            -- Region filter (based on timezone)
            if show and frame.advancedFilters.region ~= "" then
                local officerNote = member.officernote or ""
                local _, _, tzStr = string.find(officerNote, "%d%d%d%d%d%d(%a%a%a)")
                local memberRegion = tzStr and TIMEZONE_REGIONS[tzStr] or nil
                if memberRegion ~= frame.advancedFilters.region then
                    show = false
                end
            end
        end
        
        -- Offline filter
        if show and not showOffline then
            if not member.online then
                show = false
            end
        end
        
        -- Rank filter
        if show and filterRank >= 0 then
            if member.rankIndex ~= filterRank then
                show = false
            end
        end
        
        if show then
            table.insert(displayedMembers, {
                index = i,
                data = member
            })
        end
    end
    
    -- Sort members
    table.sort(displayedMembers, function(a, b)
        local aVal, bVal
        
        if sortColumn == "name" then
            aVal = a.data.name or ""
            bVal = b.data.name or ""
        elseif sortColumn == "level" then
            aVal = a.data.level or 0
            bVal = b.data.level or 0
        elseif sortColumn == "class" then
            aVal = a.data.class or ""
            bVal = b.data.class or ""
        elseif sortColumn == "rank" then
            aVal = a.data.rankIndex or 0
            bVal = b.data.rankIndex or 0
        elseif sortColumn == "note" then
            aVal = a.data.note or ""
            bVal = b.data.note or ""
        elseif sortColumn == "officernote" then
            aVal = a.data.officernote or ""
            bVal = b.data.officernote or ""
        elseif sortColumn == "lastonline" or sortColumn == "online" then
            -- Sort by time offline (online first, then by how long offline)
            if a.data.online and b.data.online then
                aVal = 0
                bVal = 0
            elseif a.data.online then
                aVal = 0  -- Online = 0 (most recent)
                bVal = 999999  -- Offline = large number
            elseif b.data.online then
                aVal = 999999
                bVal = 0
            else
                -- Both offline, calculate time in hours
                local aHours = (a.data.yearsOffline or 0) * 8760 + 
                              (a.data.monthsOffline or 0) * 730 + 
                              (a.data.daysOffline or 0) * 24 + 
                              (a.data.hoursOffline or 0)
                local bHours = (b.data.yearsOffline or 0) * 8760 + 
                              (b.data.monthsOffline or 0) * 730 + 
                              (b.data.daysOffline or 0) * 24 + 
                              (b.data.hoursOffline or 0)
                aVal = aHours
                bVal = bHours
            end
        elseif sortColumn == "zone" then
            aVal = a.data.zone or ""
            bVal = b.data.zone or ""
        elseif sortColumn == "race" then
            local aRace = IGW_GetRace(a.data.officernote or "")
            local bRace = IGW_GetRace(b.data.officernote or "")
            aVal = aRace
            bVal = bRace
        elseif sortColumn == "faction" then
            local aRace = IGW_GetRace(a.data.officernote or "")
            local bRace = IGW_GetRace(b.data.officernote or "")
            local aFaction = IGW_GetFaction(aRace)
            local bFaction = IGW_GetFaction(bRace)
            aVal = aFaction
            bVal = bFaction
        elseif sortColumn == "datejoined" then
            -- Extract date directly from officer note (no main fallback)
            local _, _, aDateStr = string.find(a.data.officernote or "", "(%d%d%d%d%d%d)")
            local _, _, bDateStr = string.find(b.data.officernote or "", "(%d%d%d%d%d%d)")
            
            -- Convert MMDDYY to YYMMDD for proper sorting (newest first when descending)
            if aDateStr then
                local aMonth = string.sub(aDateStr, 1, 2)
                local aDay = string.sub(aDateStr, 3, 4)
                local aYear = string.sub(aDateStr, 5, 6)
                aVal = aYear .. aMonth .. aDay
            else
                aVal = "999999"  -- No date = sort to end
            end
            if bDateStr then
                local bMonth = string.sub(bDateStr, 1, 2)
                local bDay = string.sub(bDateStr, 3, 4)
                local bYear = string.sub(bDateStr, 5, 6)
                bVal = bYear .. bMonth .. bDay
            else
                bVal = "999999"  -- No date = sort to end
            end
        elseif sortColumn == "timezone" then
            -- Extract timezone from officer note (can be with or without date)
            local _, _, aTzStr = string.find(a.data.officernote or "", "%d%d%d%d%d%d(%a%a%a)")
            local _, _, bTzStr = string.find(b.data.officernote or "", "%d%d%d%d%d%d(%a%a%a)")
            
            -- If not found with date, try standalone timezone
            if not aTzStr then
                local aOfficerNote = a.data.officernote or ""
                for tz, _ in pairs(TIMEZONES) do
                    if string.find(aOfficerNote, tz) then
                        aTzStr = tz
                        break
                    end
                end
            end
            if not bTzStr then
                local bOfficerNote = b.data.officernote or ""
                for tz, _ in pairs(TIMEZONES) do
                    if string.find(bOfficerNote, tz) then
                        bTzStr = tz
                        break
                    end
                end
            end
            
            aVal = aTzStr or "zzz"  -- No timezone = sort to end
            bVal = bTzStr or "zzz"
        end
        
        if sortAscending then
            return aVal < bVal
        else
            return aVal > bVal
        end
    end)
    
    -- Update scroll frame
    local numDisplayed = table.getn(displayedMembers)
    
    -- Update FauxScrollFrame
    local rowHeight = (currentTab == "roster" or currentTab == "detailed") and ROW_HEIGHT_DETAILS or ROW_HEIGHT_DEFAULT
    local maxRows = (currentTab == "roster" or currentTab == "detailed") and VISIBLE_ROWS_DETAILS or VISIBLE_ROWS_GUILD
    
    -- Ensure we don't have more scroll range than needed
    -- If we have fewer items than visible rows, no scrolling needed
    local scrollItems = numDisplayed
    if numDisplayed <= maxRows then
        scrollItems = maxRows  -- Set to maxRows to disable scrolling
    end
    
    FauxScrollFrame_Update(frame.rosterScroll, scrollItems, maxRows, rowHeight)
    local offset = FauxScrollFrame_GetOffset(frame.rosterScroll)
    
    -- Safety clamp: ensure offset doesn't exceed valid range
    local maxOffset = math.max(0, numDisplayed - maxRows)
    if offset > maxOffset then
        offset = maxOffset
    end
    

    local headerTopY = IGW_GetHeaderTopY()
    -- Display rows with offset
    for i = 1, 14 do
        local row = frame.rosterRows[i]



        local maxRows = (currentTab == "roster" or currentTab == "detailed") and VISIBLE_ROWS_DETAILS or VISIBLE_ROWS_GUILD
        if i > maxRows then
            row:Hide()
        end
        -- Only show fewer rows on Notes & Rank or Detailed View tabs
        if (currentTab == "roster" or currentTab == "detailed") and i > VISIBLE_ROWS_DETAILS then
            row:Hide()
        end
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, (headerTopY - 30) - (i-1) * rowHeight)
        local dataIndex = offset + i
        if dataIndex <= numDisplayed and not ((currentTab == "roster" or currentTab == "detailed") and i > VISIBLE_ROWS_DETAILS) then
            local member = displayedMembers[dataIndex].data
            local index = displayedMembers[dataIndex].index
            
            -- Debug first few rows
            
            if currentTab == "roster" then
                -- Roster view columns: Name, Level, Rank, Note, Officer Note, Last Online
                
                -- Hide Race and Faction (not used in this view)
                row.race:SetText("")
                row.faction:SetText("")
                
                -- Store member data for button callbacks
                row.memberData = member
                
                -- Name (without offline tag)
                row.name:SetText(member.name or "")
                if member.online then
                    row.name:SetTextColor(1, 1, 1)
                else
                    row.name:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Level
                row.level:SetText(member.level)
                row.level:SetTextColor(1, 1, 1)
                
                -- Rank (using class field)
                row.class:SetText(member.rank or "")
                row.class:SetTextColor(1, 1, 1)
                
                -- Note (using rank field)
                row.rank:SetText(member.note or "")
                row.rank:SetTextColor(1, 1, 1)
                
                -- Officer Note (using note field)
                if CanViewOfficerNote() then
                    row.note:SetText(member.officernote or "")
                else
                    row.note:SetText("")
                end
                row.note:SetTextColor(1, 1, 1)
                
                -- Last Online (using officerNote field)
                if member.online then
                    row.officerNote:SetText("Online")
                    row.officerNote:SetTextColor(0, 1, 0)
                else
                    -- Format last online time
                    local lastOnlineText = ""
                    local isOldOffline = false
                    
                    if member.yearsOffline and member.yearsOffline > 0 then
                        lastOnlineText = member.yearsOffline .. "y ago"
                        isOldOffline = true
                    elseif member.monthsOffline and member.monthsOffline >= 2 then
                        lastOnlineText = member.monthsOffline .. "m ago"
                        isOldOffline = true
                    elseif member.monthsOffline and member.monthsOffline > 0 then
                        lastOnlineText = member.monthsOffline .. "m ago"
                    elseif member.daysOffline and member.daysOffline > 0 then
                        lastOnlineText = member.daysOffline .. "d ago"
                    elseif member.hoursOffline and member.hoursOffline > 0 then
                        lastOnlineText = member.hoursOffline .. "h ago"
                    else
                        lastOnlineText = "Recently"
                    end
                    
                    row.officerNote:SetText(lastOnlineText)
                    if isOldOffline then
                        row.officerNote:SetTextColor(1, 0, 0)  -- Red for 2+ months
                    else
                        row.officerNote:SetTextColor(0.5, 0.5, 0.5)  -- Gray
                    end
                end
            elseif currentTab == "detailed" then
                -- Detailed View columns: Name, Level, Rank, Date Joined, Time Zone
                
                -- Name (without offline tag)
                row.name:SetText(member.name or "")
                if member.online then
                    row.name:SetTextColor(1, 1, 1)
                else
                    row.name:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Level
                row.level:SetText(member.level)
                row.level:SetTextColor(1, 1, 1)
                
                -- Rank (using class field)
                row.class:SetText(member.rank or "")
                row.class:SetTextColor(1, 1, 1)
                
                -- Extract Date Joined and Time Zone from officer note (timezone can be standalone)
                local dateJoined = "—"
                local timeZone = "—"
                local officerNote = member.officernote or ""
                local _, _, dateStr, tzStr = string.find(officerNote, "(%d%d%d%d%d%d)(%a%a%a)")
                if not dateStr then
                    _, _, dateStr = string.find(officerNote, "(%d%d%d%d%d%d)")
                end
                
                -- If still no timezone found, try to find just 3 letters (timezone only)
                if not tzStr then
                    for tz, _ in pairs(TIMEZONES) do
                        if string.find(officerNote, tz) then
                            tzStr = tz
                            break
                        end
                    end
                end
                
                if dateStr then
                    local month = string.sub(dateStr, 1, 2)
                    local day = string.sub(dateStr, 3, 4)
                    local year = string.sub(dateStr, 5, 6)
                    dateJoined = month .. "/" .. day .. "/" .. year
                end
                
                if tzStr then
                    timeZone = TIMEZONES[tzStr] or tzStr
                end
                
                -- Date Joined (using rank field)
                row.rank:SetText(dateJoined)
                row.rank:SetTextColor(1, 1, 1)
                
                -- Time Zone (using note field)
                row.note:SetText(timeZone)
                row.note:SetTextColor(1, 1, 1)
                
                -- Hide race and faction fields
                row.race:SetText("")
                row.faction:SetText("")
                row.officerNote:SetText("")
            else
                -- Guild Members view columns: Name, Level, Class, Location, Rank
                
                -- Name
                local nameText = member.name
                row.name:SetText(nameText)
                if member.online then
                    row.name:SetTextColor(1, 1, 1)
                else
                    row.name:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Level
                row.level:SetText(member.level)
                row.level:SetTextColor(1, 1, 1)
                
                -- Class with color
                local color = CLASS_COLORS[member.class] or {r=1, g=1, b=1}
                row.class:SetTextColor(color.r, color.g, color.b)
                row.class:SetText(member.class or "")
                
                -- Race
                local race = IGW_GetRace(member.officernote or "")
                row.race:SetText(race)
                row.race:SetTextColor(1, 1, 1)
                
                -- Faction
                local faction = IGW_GetFaction(race)
                if faction == "Alliance" then
                    row.faction:SetTextColor(0.2, 0.5, 1) -- Blue
                    row.faction:SetText("A")
                elseif faction == "Horde" then
                    row.faction:SetTextColor(1, 0.2, 0.2) -- Red
                    row.faction:SetText("H")
                else
                    row.faction:SetText("") -- Blank for unknown
                end
                
                -- Location (use rank field for display)
                if member.online then
                    row.rank:SetText(member.zone or "Unknown")
                    row.rank:SetTextColor(1, 1, 1)
                else
                    row.rank:SetText("Offline")
                    row.rank:SetTextColor(0.5, 0.5, 0.5)
                end
                
                -- Rank (use note field for display)
                row.note:SetText(member.rank or "")
                row.note:SetTextColor(1, 1, 1)
                
                -- Hide officer note field (not used in this view)
                row.officerNote:SetText("")
            end
            
            row.memberIndex = index
            row.memberName = member.name
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Update member count with online and total
    local onlineCount = 0
    local totalMembers = table.getn(rosterData)
    
    for _, m in ipairs(rosterData) do
        if m.online then
            onlineCount = onlineCount + 1
        end
    end
    
    if frame.memberCount then
        frame.memberCount:SetText(string.format("%d Online | %d Total", onlineCount, totalMembers))
    end
end

-- Toggle window visibility
-- Handle slash commands
function IGW:HandleSlashCommand(msg)
    msg = string.lower(msg or "")
    
    if msg == "" then
        -- No arguments, just toggle window
        self:ToggleWindow()
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /igw - Toggle guild window")
        DEFAULT_CHAT_FRAME:AddMessage("  /igw help - Show this help")
        DEFAULT_CHAT_FRAME:AddMessage("  /igw sync - Show sync status")
        DEFAULT_CHAT_FRAME:AddMessage("  /igw sync refresh - Rescan for addon users")
        DEFAULT_CHAT_FRAME:AddMessage("  /igwdebug - Toggle sync debug messages")
    elseif msg == "sync" or msg == "sync status" then
        -- Show sync status
        if IGW_Sync then
            local status = IGW_Sync:GetSyncStatus()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Status:")
            DEFAULT_CHAT_FRAME:AddMessage("  Peers online: " .. status.peers)
            DEFAULT_CHAT_FRAME:AddMessage("  Announcements: " .. status.announcements)
            
            -- Show schedule status
            local hasSchedule = not IGW_Sync:IsScheduleEmpty()
            DEFAULT_CHAT_FRAME:AddMessage("  Raid schedule: " .. (hasSchedule and "Loaded" or "Empty"))
            
            -- Show peer list
            if status.peers > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  Connected to:")
                for name, peer in pairs(IGW_Sync.data.peers) do
                    DEFAULT_CHAT_FRAME:AddMessage("    " .. name .. " (v" .. peer.version .. ")")
                end
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
        end
    elseif msg == "sync refresh" or msg == "rescan" then
        -- Rescan for peers
        if IGW_Sync then
            IGW_Sync:SendHandshake()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync]|r Rescanning for addon users...")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
        end
    elseif msg == "debug" then
        -- Toggle debug (alternative to /igwdebug)
        if IGW_Sync then
            IGW_Sync.debugEnabled = not IGW_Sync.debugEnabled
            if IGW_Sync.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Debug messages enabled")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Debug messages disabled")
            end
        end
    else
        -- Unknown command, just toggle window
        self:ToggleWindow()
    end
end

function IGW:ToggleWindow()
    if frame:IsVisible() then
        frame:Hide()
        -- Save window states if remember is enabled
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows then
            ImprovedGuildWindowDB.windowStates = {
                detailsOpen = IGW.detailsFrame and IGW.detailsFrame:IsVisible() or false,
                infoOpen = IGW.infoFrame and IGW.infoFrame:IsVisible() or false
            }
        end
        -- Close details window when main window closes
        if IGW.detailsFrame then
            IGW.detailsFrame:Hide()
        end
        -- Close guild info window when main window closes
        if IGW.infoFrame then
            IGW.infoFrame:Hide()
        end
        -- Close raid schedule editor when main window closes
        if IGW.raidScheduleDialog then
            IGW.raidScheduleDialog:Hide()
        end
        -- Close announcement dialog when main window closes
        if IGW.announcementDialog then
            IGW.announcementDialog:Hide()
        end
    else
        if IsInGuild() then
            GuildRoster()
            -- Use saved default tab or fall back to "details"
            local defaultTab = "details"
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.defaultTab then
                defaultTab = ImprovedGuildWindowDB.defaultTab
            end
            self:SwitchTab(defaultTab)
            frame:Show()
            self:UpdateRosterDisplay()
            
            -- Check for new announcements
            self:CheckForNewAnnouncements()
            
            -- Restore remembered windows if enabled
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows and ImprovedGuildWindowDB.windowStates then
                if ImprovedGuildWindowDB.windowStates.detailsOpen and IGW.detailsFrame then
                    IGW.detailsFrame:Show()
                end
                if ImprovedGuildWindowDB.windowStates.infoOpen and IGW.infoFrame then
                    IGW:ToggleGuildInfoWindow()
                end
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000You are not in a guild.|r")
        end
    end
end

-- Update Guild Info window contents
function IGW:UpdateGuildInfoWindow()
    if not IGW.infoFrame then return end
    local gf = IGW.infoFrame

    -- Guild name
    local guildName = GetGuildInfo("player") or "Guild"
    if gf.guildNameText then
        gf.guildNameText:SetText(guildName)
    end

    -- Total members (use rosterData if populated, otherwise query API)
    local total = 0
    -- Count guild members (excluding alts) and alts separately
    local totalMembers = 0
    local totalAlts = 0
    if rosterData and table.getn(rosterData) > 0 then
        for _, member in ipairs(rosterData) do
            local rank = string.lower(member.rank or "")
            if string.find(rank, "alt") then
                totalAlts = totalAlts + 1
            else
                totalMembers = totalMembers + 1
            end
        end
    else
        totalMembers = GetNumGuildMembers(true) or 0
    end
    if gf.totalMembersText then
        gf.totalMembersText:SetText("Guild Members: " .. totalMembers)
    end
    if gf.totalAltsText then
        gf.totalAltsText:SetText("Guild Member Alts: " .. totalAlts)
    end

    -- MOTD
    local motd = ""
    if GetGuildRosterMOTD then
        motd = GetGuildRosterMOTD() or ""
    end
    if motd == "" then motd = "—" end
    if gf.motdValue then
        gf.motdValue:SetText(motd)
    end

    -- Guild Information (public guild info text)
    local infoText = ""
    if GetGuildInfoText then
        infoText = GetGuildInfoText() or ""
    end
    if infoText == "" then infoText = "—" end
    if gf.infoValue then
        gf.infoValue:SetText(infoText)
    end
    
    -- Class distribution (from rosterData) - Bar Graph
    -- Clear existing bars
    if gf.classBars then
        for _, bar in ipairs(gf.classBars) do
            bar.frame:Hide()
        end
        gf.classBars = {}
    end
    
    local counts = {}
    local maxCount = 0
    for _, m in ipairs(rosterData or {}) do
        if m and m.class then
            counts[m.class] = (counts[m.class] or 0) + 1
            if counts[m.class] > maxCount then
                maxCount = counts[m.class]
            end
        end
    end

    local entries = {}
    for cls, c in pairs(counts) do
        table.insert(entries, {cls=cls, c=c})
    end
    table.sort(entries, function(a,b)
        if a.c == b.c then
            return a.cls < b.cls
        end
        return a.c > b.c
    end)

    -- Create bars
    local barHeight = 12
    local barGap = 2
    local maxBarWidth = 180
    local yOffset = 0
    
    for i, e in ipairs(entries) do
        if i > 10 then break end -- Limit to top 10 classes
        
        local barFrame = CreateFrame("Frame", nil, gf.classBarsContainer)
        barFrame:SetPoint("TOPLEFT", gf.classBarsContainer, "TOPLEFT", 0, yOffset)
        barFrame:SetHeight(barHeight)
        
        -- Calculate bar width based on count
        local barWidth = maxCount > 0 and (e.c / maxCount) * maxBarWidth or 0
        barFrame:SetWidth(barWidth)
        
        -- Bar background with class color
        local color = CLASS_COLORS[e.cls] or {r=0.5, g=0.5, b=0.5}
        local barBg = barFrame:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(barFrame)
        barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barBg:SetVertexColor(color.r, color.g, color.b, 0.8)
        
        -- Label (class name and count)
        local label = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", barFrame, "LEFT", 3, 0)
        label:SetText(string.format("%s: %d", e.cls, e.c))
        label:SetTextColor(1, 1, 1)
        
        table.insert(gf.classBars, {frame=barFrame, bg=barBg, label=label})
        
        yOffset = yOffset - (barHeight + barGap)
    end
    
    -- Level 60 Class distribution - Bar Graph
    -- Clear existing bars
    if gf.class60Bars then
        for _, bar in ipairs(gf.class60Bars) do
            bar.frame:Hide()
        end
        gf.class60Bars = {}
    end
    
    local counts60 = {}
    local maxCount60 = 0
    for _, m in ipairs(rosterData or {}) do
        if m and m.class and m.level == 60 then
            counts60[m.class] = (counts60[m.class] or 0) + 1
            if counts60[m.class] > maxCount60 then
                maxCount60 = counts60[m.class]
            end
        end
    end

    local entries60 = {}
    for cls, c in pairs(counts60) do
        table.insert(entries60, {cls=cls, c=c})
    end
    table.sort(entries60, function(a,b)
        if a.c == b.c then
            return a.cls < b.cls
        end
        return a.c > b.c
    end)

    -- Create level 60 bars
    local barHeight60 = 12
    local barGap60 = 2
    local maxBarWidth60 = 180
    local yOffset60 = 0
    
    for i, e in ipairs(entries60) do
        if i > 10 then break end -- Limit to top 10 classes
        
        local barFrame = CreateFrame("Frame", nil, gf.class60BarsContainer)
        barFrame:SetPoint("TOPLEFT", gf.class60BarsContainer, "TOPLEFT", 0, yOffset60)
        barFrame:SetHeight(barHeight60)
        
        -- Calculate bar width based on count
        local barWidth = maxCount60 > 0 and (e.c / maxCount60) * maxBarWidth60 or 0
        barFrame:SetWidth(barWidth)
        
        -- Bar background with class color
        local color = CLASS_COLORS[e.cls] or {r=0.5, g=0.5, b=0.5}
        local barBg = barFrame:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(barFrame)
        barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barBg:SetVertexColor(color.r, color.g, color.b, 0.8)
        
        -- Label (class name and count)
        local label = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", barFrame, "LEFT", 3, 0)
        label:SetText(string.format("%s: %d", e.cls, e.c))
        label:SetTextColor(1, 1, 1)
        
        table.insert(gf.class60Bars, {frame=barFrame, bg=barBg, label=label})
        
        yOffset60 = yOffset60 - (barHeight60 + barGap60)
    end
    
    -- Officers Online (uses OFFICER_RANK_THRESHOLD configuration)
    local onlineOfficers = {}
    for _, m in ipairs(rosterData or {}) do
        if m and m.online and m.rankIndex ~= nil then
            -- rankIndex: 0=Guild Master, 1-9=other ranks
            if m.rankIndex <= OFFICER_RANK_THRESHOLD then
                table.insert(onlineOfficers, m.name)
            end
        end
    end
    
    local officersText = ""
    if table.getn(onlineOfficers) > 0 then
        table.sort(onlineOfficers)
        officersText = table.concat(onlineOfficers, "\n")
    else
        officersText = "No officers online"
    end
    
    if gf.officersValue then
        gf.officersValue:SetText(officersText)
    end
end

-- Update Page 3 - Crafters
function IGW:UpdateCraftersPage()
    if not IGW.infoFrame then return end
    local gf = IGW.infoFrame
    local content = gf.craftersContent
    if not content then return end
    
    -- Clear existing content
    local children = {content:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Parse crafters from public notes (300+ skill level only)
    local crafters = {}
    for _, m in ipairs(rosterData or {}) do
        if m and m.name and m.note then
            local noteUpper = string.upper(m.note)
            
            -- Profession search patterns with abbreviations (crafting professions only)
            local professions = {
                {name="Alchemy", patterns={"ALCHEMY", "ALCH", "ALC"}},
                {name="Blacksmithing", patterns={"BLACKSMITHING", "BLACKSMITH", "SMITH", "BS", "B%.S%."}},
                {name="Enchanting", patterns={"ENCHANTING", "ENCHANT", "ENCH", "ENC"}},
                {name="Engineering", patterns={"ENGINEERING", "ENGINEER", "ENG", "ENGI"}},
                {name="Jewelcrafting", patterns={"JEWELCRAFTING", "JEWEL", "JC", "J%.C%."}},
                {name="Leatherworking", patterns={"LEATHERWORKING", "LEATHER", "LW", "L%.W%."}},
                {name="Tailoring", patterns={"TAILORING", "TAILOR", "TAIL", "TLR"}}
            }
            
            for _, prof in ipairs(professions) do
                for _, pattern in ipairs(prof.patterns) do
                    local skill = nil
                    -- Try pattern: ProfessionName 300 or ProfessionName: 300
                    local _, _, skill1 = string.find(noteUpper, pattern .. "%s*:?%s*(%d+)")
                    -- Try pattern: 300 ProfessionName
                    local _, _, skill2 = string.find(noteUpper, "(%d+)%s*" .. pattern)
                    
                    skill = skill1 or skill2
                    
                    if skill then
                        local skillNum = tonumber(skill)
                        -- Only include online players with 300+ skill
                        if skillNum and skillNum >= 300 and m.online then
                            -- Check if we already added this profession for this player
                            local alreadyAdded = false
                            for _, existing in ipairs(crafters) do
                                if existing.name == m.name and existing.prof == prof.name then
                                    alreadyAdded = true
                                    break
                                end
                            end
                            
                            if not alreadyAdded then
                                table.insert(crafters, {
                                    name = m.name,
                                    prof = prof.name,
                                    skill = skillNum,
                                    online = true
                                })
                            end
                            break -- Found this profession, skip other patterns for it
                        end
                    end
                end
            end
        end
    end
    
    -- Group by profession
    local professionGroups = {}
    for _, crafter in ipairs(crafters) do
        if not professionGroups[crafter.prof] then
            professionGroups[crafter.prof] = {}
        end
        table.insert(professionGroups[crafter.prof], crafter)
    end
    
    -- Sort each profession group alphabetically by name
    for prof, group in pairs(professionGroups) do
        table.sort(group, function(a, b)
            return a.name < b.name
        end)
    end
    
    -- Sort professions alphabetically
    local sortedProfs = {}
    for prof, _ in pairs(professionGroups) do
        table.insert(sortedProfs, prof)
    end
    table.sort(sortedProfs)
    
    -- Define all 7 crafting professions in order
    local allProfessions = {
        "Alchemy", "Blacksmithing", "Enchanting", 
        "Engineering", "Jewelcrafting", "Leatherworking", 
        "Tailoring"
    }
    
    -- Display all professions with fixed spacing
    local yOffset = 0
    local sectionHeight = 50 -- Height per profession section (title + 2 rows + gap)
    
    for _, prof in ipairs(allProfessions) do
        local group = professionGroups[prof] or {} -- Use empty table if no crafters
        
        -- Profession subtitle (centered)
        local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        subtitle:SetPoint("TOP", content, "TOP", 0, yOffset)
        subtitle:SetWidth(210)
        subtitle:SetJustifyH("CENTER")
        subtitle:SetTextColor(1, 1, 1) -- White color
        subtitle:SetText(prof)
        yOffset = yOffset - 18
        
        -- Display up to 6 crafters in 2 lines (3 per line, clickable)
        for line = 1, 2 do
            local startIdx = (line - 1) * 3 + 1
            local lineMembers = {}
            
            for i = startIdx, math.min(startIdx + 2, table.getn(group)) do
                table.insert(lineMembers, group[i])
            end
            
            if table.getn(lineMembers) > 0 then
                -- Create container for this line
                local lineContainer = CreateFrame("Frame", nil, content)
                lineContainer:SetPoint("TOP", content, "TOP", 0, yOffset)
                lineContainer:SetWidth(210)
                lineContainer:SetHeight(14)
                
                -- Calculate actual text widths using a temporary FontString
                local tempText = lineContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                local totalWidth = 0
                local buttonWidths = {}
                
                for _, member in ipairs(lineMembers) do
                    tempText:SetText(member.name)
                    local nameWidth = tempText:GetStringWidth() + 1 -- Reduced from +2 to +1
                    table.insert(buttonWidths, nameWidth)
                    totalWidth = totalWidth + nameWidth
                end
                tempText:Hide() -- Hide temporary text
                
                -- Add comma widths (", " spacing)
                if table.getn(lineMembers) > 1 then
                    tempText:SetText(", ")
                    local commaWidth = tempText:GetStringWidth()
                    totalWidth = totalWidth + ((table.getn(lineMembers) - 1) * commaWidth)
                end
                
                -- Starting position (centered)
                local xOffset = -(totalWidth / 2)
                
                -- Create clickable buttons for each name
                for idx, member in ipairs(lineMembers) do
                    -- Capture member name in local variable to avoid closure issues
                    local memberName = member.name
                    
                    local nameBtn = CreateFrame("Button", nil, lineContainer)
                    nameBtn:SetPoint("LEFT", lineContainer, "LEFT", xOffset + 105, 0)
                    nameBtn:SetWidth(buttonWidths[idx])
                    nameBtn:SetHeight(14)
                    
                    local nameText = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nameText:SetAllPoints(nameBtn)
                    nameText:SetJustifyH("LEFT")
                    nameText:SetText(string.format("|cFF00FF00%s|r", memberName))
                    
                    nameBtn:SetScript("OnClick", function()
                        ChatFrameEditBox:SetText("/w " .. memberName .. " ")
                        ChatFrameEditBox:Show()
                        ChatFrameEditBox:SetFocus()
                    end)
                    
                    nameBtn:SetScript("OnEnter", function()
                        nameText:SetText(string.format("|cFFFFFF00%s|r", memberName)) -- Yellow on hover
                    end)
                    
                    nameBtn:SetScript("OnLeave", function()
                        nameText:SetText(string.format("|cFF00FF00%s|r", memberName)) -- Green normally
                    end)
                    
                    xOffset = xOffset + buttonWidths[idx]
                    
                    -- Add comma after name (except last one)
                    if idx < table.getn(lineMembers) then
                        local comma = lineContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        comma:SetPoint("LEFT", lineContainer, "LEFT", xOffset + 105, 0)
                        comma:SetText("|cFF00FF00, |r")
                        tempText:SetText(", ")
                        xOffset = xOffset + tempText:GetStringWidth()
                    end
                end
            end
            
            yOffset = yOffset - 14
        end
        
        -- Gap after each profession
        yOffset = yOffset - 6
    end
end

-- Show dungeon details dialog
-- UpdateDungeonsPage - Display dungeon recommendations
function IGW:UpdateDungeonsPage()
    local gf = IGW.infoFrame
    if not gf or not gf.dungeonsContent then return end
    
    local content = gf.dungeonsContent
    
    -- Clear existing dungeon entries
    local children = {content:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
    end
    
    -- Get online members' levels
    local onlineLevels = {}
    for _, m in ipairs(rosterData or {}) do
        if m and m.online and m.level then
            table.insert(onlineLevels, m.level)
        end
    end
    
    if table.getn(onlineLevels) == 0 then
        local noData = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noData:SetPoint("TOP", content, "TOP", 0, -20)
        noData:SetWidth(210)
        noData:SetJustifyH("CENTER")
        noData:SetText("No members online")
        noData:SetTextColor(0.7, 0.7, 0.7)
        return
    end
    
    -- Calculate average level of online members
    local totalLevel = 0
    for _, lvl in ipairs(onlineLevels) do
        totalLevel = totalLevel + lvl
    end
    local avgLevel = totalLevel / table.getn(onlineLevels)
    
    -- Dungeon database with level ranges (Turtle WoW) - shortened names
    local dungeons = {
        {name = "Ragefire Chasm", minLevel = 13, maxLevel = 18, location = "Orgrimmar", faction = "Horde", description = "A lava-filled cavern beneath Orgrimmar, home to Trogg invaders and fire cultists."},
        {name = "Deadmines", minLevel = 17, maxLevel = 24, location = "Westfall", faction = "Alliance", description = "A network of tunnels beneath Westfall controlled by the Defias Brotherhood."},
        {name = "Wailing Caverns", minLevel = 17, maxLevel = 24, location = "The Barrens", faction = "Both", description = "A corrupted underground oasis in the Barrens with deviate creatures."},
        {name = "Stockades", minLevel = 22, maxLevel = 30, location = "Stormwind", faction = "Alliance", description = "A high-security prison in Stormwind where dangerous criminals are held."},
        {name = "Blackfathom Deeps", minLevel = 22, maxLevel = 31, location = "Ashenvale", faction = "Both", description = "A former temple now overrun by the Twilight's Hammer cult."},
        {name = "SM: Graveyard", minLevel = 27, maxLevel = 36, location = "Tirisfal Glades", faction = "Both", description = "Scarlet Monastery: Graveyard - The burial grounds corrupted by the undead."},
        {name = "Gnomeregan", minLevel = 29, maxLevel = 38, location = "Dun Morogh", faction = "Both", description = "The irradiated gnomish city, now overrun by troggs and malfunctioning machines."},
        {name = "SM: Library", minLevel = 32, maxLevel = 39, location = "Tirisfal Glades", faction = "Both", description = "Scarlet Monastery: Library - Repository of Scarlet Crusade knowledge."},
        {name = "Razorfen Kraul", minLevel = 32, maxLevel = 42, location = "The Barrens", faction = "Both", description = "An ancient quilboar stronghold with death speaker cultists."},
        {name = "SM: Armory", minLevel = 40, maxLevel = 45, location = "Tirisfal Glades", faction = "Both", description = "Scarlet Monastery: Armory - Training grounds of the Scarlet Crusade."},
        {name = "SM: Cathedral", minLevel = 40, maxLevel = 45, location = "Tirisfal Glades", faction = "Both", description = "Scarlet Monastery: Cathedral - The heart of Scarlet Crusade power."},
        {name = "Uldaman", minLevel = 40, maxLevel = 51, location = "Badlands", faction = "Both", description = "An ancient titan vault filled with troggs and earthen constructs."},
        {name = "Razorfen Downs", minLevel = 42, maxLevel = 44, location = "The Barrens", faction = "Both", description = "A quilboar burial ground corrupted by the Scourge."},
        {name = "Maraudon", minLevel = 45, maxLevel = 55, location = "Desolace", faction = "Both", description = "A vast cavern complex beneath Desolace with centaur and elemental forces."},
        {name = "Zul'Farrak", minLevel = 46, maxLevel = 56, location = "Tanaris", faction = "Both", description = "An ancient troll city in Tanaris filled with sandfury trolls."},
        {name = "Sunken Temple", minLevel = 50, maxLevel = 60, location = "Swamp of Sorrows", faction = "Both", description = "Temple of Atal'Hakkar - An ancient troll temple dedicated to the blood god."},
        {name = "BRD", minLevel = 52, maxLevel = 60, location = "Blackrock Mountain", faction = "Both", description = "Blackrock Depths - A massive Dark Iron dwarf city within Blackrock Mountain."},
        {name = "DM: West", minLevel = 55, maxLevel = 60, location = "Feralas", faction = "Both", description = "Dire Maul West - Ancient elven ruins overrun by ogres."},
        {name = "DM: East", minLevel = 55, maxLevel = 60, location = "Feralas", faction = "Both", description = "Dire Maul East - Ancient elven ruins overrun by ogres."},
        {name = "LBRS", minLevel = 55, maxLevel = 60, location = "Blackrock Mountain", faction = "Both", description = "Lower Blackrock Spire - Orc stronghold within Blackrock Mountain."},
        {name = "DM: North", minLevel = 58, maxLevel = 60, location = "Feralas", faction = "Both", description = "Dire Maul North - Ancient elven ruins with the Tribute Run."},
        {name = "Scholomance", minLevel = 58, maxLevel = 60, location = "Western Plaguelands", faction = "Both", description = "A school of necromancy run by the Scourge."},
        {name = "Stratholme", minLevel = 58, maxLevel = 60, location = "Eastern Plaguelands", faction = "Both", description = "A city destroyed by the Scourge with Living and Undead sides."},
        {name = "UBRS", minLevel = 55, maxLevel = 60, location = "Blackrock Mountain", faction = "Both", description = "Upper Blackrock Spire - Stronghold of the Blackrock orcs."}
    }
    
    -- Score each dungeon based on how well it fits the online levels
    for _, dungeon in ipairs(dungeons) do
        local score = 0
        for _, lvl in ipairs(onlineLevels) do
            if lvl >= dungeon.minLevel and lvl <= dungeon.maxLevel then
                score = score + 1
            end
        end
        dungeon.score = score
        dungeon.coverage = table.getn(onlineLevels) > 0 and (score / table.getn(onlineLevels)) or 0
    end
    
    -- Sort by minimum level ascending
    table.sort(dungeons, function(a, b)
        return a.minLevel < b.minLevel
    end)
    
    -- Display up to 22 dungeons with at least 4 players
    local yOffset = -10
    local displayed = 0
    
    -- Get current player's level
    local playerLevel = UnitLevel("player")
    
    for i, dungeon in ipairs(dungeons) do
        if displayed >= 22 then break end
        if dungeon.score >= 4 then  -- Only show dungeons with at least 4 matching members
            -- Create clickable button
            local dungeonBtn = CreateFrame("Button", nil, content)
            dungeonBtn:SetPoint("TOP", content, "TOP", 0, yOffset)
            dungeonBtn:SetWidth(210)
            dungeonBtn:SetHeight(16)
            
            -- Create text for the button
            local btnText = dungeonBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("LEFT", dungeonBtn, "LEFT", 0, 0)
            btnText:SetWidth(210)
            btnText:SetJustifyH("LEFT")
            dungeonBtn:SetFontString(btnText)
            
            -- Color based on player level vs dungeon range
            local colorCode = "|cFFFFFFFF"  -- White (default)
            if playerLevel >= dungeon.minLevel and playerLevel <= dungeon.maxLevel then
                colorCode = "|cFF00FF00"  -- Green (perfect fit)
            elseif playerLevel >= dungeon.minLevel - 3 and playerLevel <= dungeon.maxLevel + 3 then
                colorCode = "|cFFFFFF00"  -- Yellow (close fit)
            elseif playerLevel < dungeon.minLevel then
                colorCode = "|cFFFF4040"  -- Red (too low)
            else
                colorCode = "|cFF808080"  -- Gray (too high)
            end
            
            -- Format player count text
            local playerText = dungeon.score == 1 and "1 Online" or string.format("%d Online", dungeon.score)
            
            btnText:SetText(string.format("%s%s|r (%d-%d) - |cFF666666%s|r", 
                colorCode, dungeon.name, dungeon.minLevel, dungeon.maxLevel, playerText))
            
            -- Highlight on hover
            local highlight = dungeonBtn:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints()
            highlight:SetTexture(1, 1, 1, 0.1)
            dungeonBtn:SetHighlightTexture(highlight)
            
            -- Store dungeon info directly on the button
            dungeonBtn.dungeonName = dungeon.name
            dungeonBtn.minLevel = dungeon.minLevel
            dungeonBtn.maxLevel = dungeon.maxLevel
            dungeonBtn.score = dungeon.score
            
            -- Dungeon details dialog removed - buttons are now display-only
            
            yOffset = yOffset - 18  -- Increased spacing between dungeons
            displayed = displayed + 1
        end
    end
    
    if displayed == 0 then
        local noSuggestions = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noSuggestions:SetPoint("TOP", content, "TOP", 0, -20)
        noSuggestions:SetWidth(210)
        noSuggestions:SetJustifyH("CENTER")
        noSuggestions:SetText("No suitable dungeons found")
        noSuggestions:SetTextColor(0.7, 0.7, 0.7)
    end
end



-- Show dungeon details dialog
-- Page 3 - Guild Events & Calendar

-- Toggle Guild Info window (left-side companion window; empty for now)

-- Mark announcements as read
function IGW:MarkAnnouncementsAsRead()
    if IGW_Sync and IGW_Sync.data and IGW_Sync.data.announcements then
        -- Store the timestamp of the last announcement
        if table.getn(IGW_Sync.data.announcements) > 0 then
            local lastAnn = IGW_Sync.data.announcements[1] -- Most recent
            local lastTimestamp = tonumber(lastAnn.timestamp) or 0
            local savedTimestamp = tonumber(ImprovedGuildWindowDB.lastReadAnnouncement) or 0
            
            if savedTimestamp < lastTimestamp then
                ImprovedGuildWindowDB.lastReadAnnouncement = lastTimestamp
            end
        end
        
        -- Hide the notification button
        if frame and frame.announcementBtn then
            frame.announcementBtn:Hide()
        end
    end
end

-- Check for new announcements
function IGW:CheckForNewAnnouncements()
    if not frame or not frame.announcementBtn then return end
    if not IGW_Sync or not IGW_Sync.data or not IGW_Sync.data.announcements then
        frame.announcementBtn:Hide()
        return
    end
    
    -- Check if there are any announcements newer than last read
    local hasNew = false
    local lastRead = tonumber(ImprovedGuildWindowDB.lastReadAnnouncement) or 0
    
    for _, ann in ipairs(IGW_Sync.data.announcements) do
        if ann.timestamp and tonumber(ann.timestamp) and tonumber(ann.timestamp) > lastRead then
            hasNew = true
            break
        end
    end
    
    -- Show/hide button based on new announcements
    if hasNew and frame:IsVisible() then
        frame.announcementBtn:Show()
    else
        frame.announcementBtn:Hide()
    end
end

function IGW:ToggleGuildInfoWindow()
    if not frame then return end

    -- Create if needed
    if not IGW.infoFrame then
        local gf = CreateFrame("Frame", "IGW_GuildInfoFrame", UIParent)
        IGW_AddToSpecialFrames("IGW_GuildInfoFrame", true)
        gf:SetWidth(250)
        gf:SetHeight(frame:GetHeight())
        gf:SetFrameStrata("HIGH")
        gf:SetFrameLevel(30)
        -- Only allow moving if setting is enabled
        gf:SetMovable((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        gf:EnableMouse(true)
        gf:SetClampedToScreen(true)
        gf:Hide()

        -- Background (border only, solid texture added separately)
        gf:SetBackdrop({
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
        gf:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local gfBgTexture = gf:CreateTexture(nil, "BACKGROUND")
        gfBgTexture:SetPoint("TOPLEFT", gf, "TOPLEFT", 11, -12)
        gfBgTexture:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        gfBgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        gf.bgTexture = gfBgTexture
        
-- Title bar
        local titleBar = CreateFrame("Frame", nil, gf)
        titleBar:SetPoint("TOPLEFT", gf, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", gf, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(gf:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() 
            if gf:IsMovable() then
                gf:StartMoving() 
            end
        end)
        titleBar:SetScript("OnDragStop", function() 
            if gf:IsMovable() then
                gf:StopMovingOrSizing() 
            end
        end)

        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Guild Info")
        gf.title = title

        local closeBtn = CreateFrame("Button", nil, gf, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", gf, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(gf:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function() gf:Hide() end)


-- Content area
local content = CreateFrame("Frame", nil, gf)
content:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 20)
gf.content = content

-- Guild name (large, centered)
local guildNameText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
guildNameText:SetPoint("TOP", content, "TOP", 0, 0)
guildNameText:SetJustifyH("CENTER")
guildNameText:SetText("Guild")
gf.guildNameText = guildNameText

-- Guild Members (excluding alts)
local totalMembersText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
totalMembersText:SetPoint("TOP", guildNameText, "BOTTOM", 0, -10)
totalMembersText:SetJustifyH("CENTER")
totalMembersText:SetText("Guild Members: 0")
gf.totalMembersText = totalMembersText

-- Guild Member Alts (members with "alt" in rank)
local totalAltsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
totalAltsText:SetPoint("TOP", totalMembersText, "BOTTOM", 0, -5)
totalAltsText:SetJustifyH("CENTER")
totalAltsText:SetText("Guild Member Alts: 0")
gf.totalAltsText = totalAltsText

-- Divider 1 (after member counts)
local div1 = content:CreateTexture(nil, "ARTWORK")
div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
div1:SetPoint("TOP", totalAltsText, "BOTTOM", 36, -6)
div1:SetWidth(300)
div1:SetHeight(16)

-- MOTD
local motdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
motdLabel:SetPoint("TOP", div1, "BOTTOM", -36, -6)
motdLabel:SetJustifyH("CENTER")
motdLabel:SetText("Message of the Day")
gf.motdLabel = motdLabel

local motdValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
motdValue:SetPoint("TOP", motdLabel, "BOTTOM", 0, -6)
motdValue:SetWidth(210)
motdValue:SetJustifyH("CENTER")
motdValue:SetText("—")
gf.motdValue = motdValue

-- Divider 2 (after MOTD)
local div2 = content:CreateTexture(nil, "ARTWORK")
div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
div2:SetPoint("TOP", motdValue, "BOTTOM", 36, -6)
div2:SetWidth(300)
div2:SetHeight(16)

-- Guild Information
local infoLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
infoLabel:SetPoint("TOP", div2, "BOTTOM", -36, -6)
infoLabel:SetJustifyH("CENTER")
infoLabel:SetText("Guild Information")
gf.infoLabel = infoLabel

local infoValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
infoValue:SetPoint("TOP", infoLabel, "BOTTOM", 0, -6)
infoValue:SetWidth(210)
infoValue:SetJustifyH("CENTER")
infoValue:SetText("—")
gf.infoValue = infoValue

-- Page 2 content frame (hidden by default)
local content2 = CreateFrame("Frame", nil, gf)
content2:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content2:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 50)
content2:Hide()
gf.content2 = content2

-- Page 2 - Class Distribution
local classLabel = content2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classLabel:SetPoint("TOP", content2, "TOP", 0, 0)
classLabel:SetJustifyH("CENTER")
classLabel:SetText("Class Distribution")
classLabel:SetTextColor(1, 1, 1)
gf.classLabel = classLabel

-- Container for class bars (reduced height)
local classBarsContainer = CreateFrame("Frame", nil, content2)
classBarsContainer:SetPoint("TOP", classLabel, "BOTTOM", 0, -4)
classBarsContainer:SetWidth(210)
classBarsContainer:SetHeight(120)
gf.classBarsContainer = classBarsContainer

-- Store bars for updating
gf.classBars = {}

-- Divider before Level 60 Class Distribution
local page2Div1 = content2:CreateTexture(nil, "ARTWORK")
page2Div1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
page2Div1:SetPoint("TOP", classBarsContainer, "BOTTOM", 36, -8)
page2Div1:SetWidth(300)
page2Div1:SetHeight(16)

-- Level 60 Class Distribution
local class60Label = content2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
class60Label:SetPoint("TOP", page2Div1, "BOTTOM", -36, -4)
class60Label:SetJustifyH("CENTER")
class60Label:SetText("Level 60 Class Distribution")
class60Label:SetTextColor(1, 1, 1)
gf.class60Label = class60Label

-- Container for level 60 class bars
local class60BarsContainer = CreateFrame("Frame", nil, content2)
class60BarsContainer:SetPoint("TOP", class60Label, "BOTTOM", 0, -4)
class60BarsContainer:SetWidth(210)
class60BarsContainer:SetHeight(120)
gf.class60BarsContainer = class60BarsContainer

-- Store bars for updating
gf.class60Bars = {}

-- Divider before Officers
local page2Div2 = content2:CreateTexture(nil, "ARTWORK")
page2Div2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
page2Div2:SetPoint("TOP", class60BarsContainer, "BOTTOM", 36, -8)
page2Div2:SetWidth(300)
page2Div2:SetHeight(16)

-- Officers Online
local officersLabel = content2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
officersLabel:SetPoint("TOP", page2Div2, "BOTTOM", -36, -4)
officersLabel:SetJustifyH("CENTER")
officersLabel:SetText("Officers Online")
officersLabel:SetTextColor(1, 1, 1)
gf.officersLabel = officersLabel

local officersValue = content2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
officersValue:SetPoint("TOP", officersLabel, "BOTTOM", 0, -4)
officersValue:SetWidth(210)
officersValue:SetJustifyH("CENTER")
officersValue:SetText("—")
gf.officersValue = officersValue


-- Page 3 content frame (hidden by default)
local content3 = CreateFrame("Frame", nil, gf)
content3:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content3:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 50)
content3:Hide()
gf.content3 = content3

-- Page 3 - Max Level Crafters Online
local craftersTitle = content3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
craftersTitle:SetPoint("TOP", content3, "TOP", 0, 0)
craftersTitle:SetJustifyH("CENTER")
craftersTitle:SetText("Max Level Crafters Online")
gf.craftersTitle = craftersTitle

-- Instruction text (green)
local instructionText = content3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
instructionText:SetPoint("TOP", craftersTitle, "BOTTOM", 0, -6)
instructionText:SetJustifyH("CENTER")
instructionText:SetTextColor(0, 1, 0) -- Green
instructionText:SetText("Click Player to Whisper")

-- Fixed content area for crafters (not scrollable, centered)
local craftersContent = CreateFrame("Frame", nil, content3)
craftersContent:SetPoint("TOP", instructionText, "BOTTOM", 0, -6)
craftersContent:SetWidth(210)
craftersContent:SetPoint("BOTTOM", content3, "BOTTOM", 0, 50)
gf.craftersContent = craftersContent

-- Page 4 content frame (hidden by default)
local content4 = CreateFrame("Frame", nil, gf)
content4:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content4:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 50)
content4:Hide()
gf.content4 = content4

-- Page 4 - Suggested Dungeons
local dungeonsTitle = content4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dungeonsTitle:SetPoint("TOP", content4, "TOP", 0, 0)
dungeonsTitle:SetJustifyH("CENTER")
dungeonsTitle:SetText("Suggested Dungeons")
dungeonsTitle:SetTextColor(1, 1, 1)
gf.dungeonsTitle = dungeonsTitle

local dungeonsInstruction = content4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dungeonsInstruction:SetPoint("TOP", dungeonsTitle, "BOTTOM", 0, -4)
dungeonsInstruction:SetWidth(210)
dungeonsInstruction:SetJustifyH("CENTER")
dungeonsInstruction:SetText("Based on online guild members' levels")
dungeonsInstruction:SetTextColor(0.8, 0.8, 0.8)
gf.dungeonsInstruction = dungeonsInstruction

-- Container for dungeons (no scroll, shows all matching)
local dungeonsContent = CreateFrame("Frame", nil, content4)
dungeonsContent:SetPoint("TOPLEFT", dungeonsInstruction, "BOTTOMLEFT", 0, -8)
dungeonsContent:SetPoint("TOPRIGHT", dungeonsInstruction, "BOTTOMRIGHT", 0, -8)
dungeonsContent:SetPoint("BOTTOM", content4, "BOTTOM", 0, 50)
gf.dungeonsContent = dungeonsContent

-- Page 5 content frame (hidden by default)
local content5 = CreateFrame("Frame", nil, gf)
content5:SetPoint("TOPLEFT", gf, "TOPLEFT", 20, -50)
content5:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -20, 50)
content5:Hide()
gf.content5 = content5

-- Page 5 will be populated by IGW:UpdateEventsPage()
gf.eventsScrollFrame = nil
gf.eventsContent = nil

-- Pagination buttons at bottom (match tab button styling)
local buttonHeight = 25  -- Match tab button height
local prevBtn = CreateFrame("Button", nil, gf, "UIPanelButtonTemplate")
prevBtn:SetPoint("BOTTOMLEFT", gf, "BOTTOMLEFT", 15, 15)
prevBtn:SetWidth(30)
prevBtn:SetHeight(buttonHeight)
prevBtn:SetText("<")
prevBtn:SetScript("OnClick", function()
    if gf.currentPage == 2 then
        gf.currentPage = 1
        gf.content:Show()
        gf.content2:Hide()
        gf.content3:Hide()
        gf.content4:Hide()
        gf.pageIndicator:SetText("Page 1 / 4")
    elseif gf.currentPage == 3 then
        gf.currentPage = 2
        gf.content:Hide()
        gf.content2:Show()
        gf.content3:Hide()
        gf.content4:Hide()
        gf.pageIndicator:SetText("Page 2 / 4")
    elseif gf.currentPage == 4 then
        gf.currentPage = 3
        gf.content:Hide()
        gf.content2:Hide()
        gf.content3:Show()
        gf.content4:Hide()
        IGW:UpdateCraftersPage()
        gf.pageIndicator:SetText("Page 3 / 4")
    end
end)
gf.prevBtn = prevBtn

local nextBtn = CreateFrame("Button", nil, gf, "UIPanelButtonTemplate")
nextBtn:SetPoint("BOTTOMRIGHT", gf, "BOTTOMRIGHT", -15, 15)
nextBtn:SetWidth(30)
nextBtn:SetHeight(buttonHeight)
nextBtn:SetText(">")
nextBtn:SetScript("OnClick", function()
    if gf.currentPage == 1 then
        gf.currentPage = 2
        gf.content:Hide()
        gf.content2:Show()
        gf.content3:Hide()
        gf.content4:Hide()
        gf.pageIndicator:SetText("Page 2 / 4")
    elseif gf.currentPage == 2 then
        gf.currentPage = 3
        gf.content:Hide()
        gf.content2:Hide()
        gf.content3:Show()
        gf.content4:Hide()
        IGW:UpdateCraftersPage()
        gf.pageIndicator:SetText("Page 3 / 4")
    elseif gf.currentPage == 3 then
        gf.currentPage = 4
        gf.content:Hide()
        gf.content2:Hide()
        gf.content3:Hide()
        gf.content4:Show()
        IGW:UpdateDungeonsPage()
        gf.pageIndicator:SetText("Page 4 / 4")
    end
end)
gf.nextBtn = nextBtn

-- Page indicator (vertically centered with buttons)
local pageIndicator = gf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pageIndicator:SetPoint("BOTTOM", gf, "BOTTOM", 0, 15 + (buttonHeight / 2))
pageIndicator:SetText("Page 1 / 4")
gf.pageIndicator = pageIndicator

-- Initialize to page 1
gf.currentPage = 1

        IGW.infoFrame = gf
    end

    local gf = IGW.infoFrame
    if gf:IsVisible() then
        gf:Hide()
        -- Un-highlight tab4 button
        frame.tab4:SetBackdropColor(0.2, 0.2, 0.2, 1)
        frame.tab4Text:SetTextColor(0.7, 0.7, 0.7)
    else
        gf:ClearAllPoints()
        gf:SetPoint("TOPRIGHT", frame, "TOPLEFT", -5, 0)
        gf:SetHeight(frame:GetHeight())
        -- Highlight tab4 button
        frame.tab4:SetBackdropColor(0.5, 0.5, 0.5, 1)
        frame.tab4Text:SetTextColor(1, 1, 1)
        -- Update texture with saved color and opacity
        if gf.bgTexture then
            local bgColor = {r = 0.15, g = 0.15, b = 0.15}
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
                bgColor = ImprovedGuildWindowDB.bgColor
            end
            gf.bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, IGW_BG_OPACITY)
        end
        IGW:UpdateGuildInfoWindow()
            gf:Show()
    end
end

-- Toggle Options window
function IGW:ToggleOptionsWindow()
    if not frame then return end
    
    -- Create if needed
    if not IGW.optionsFrame then
        local of = CreateFrame("Frame", "IGW_OptionsFrame", UIParent)
        of:SetWidth(650)  -- Same width as main window
        of:SetHeight(500)  -- Same height as main window
        of:SetFrameStrata("DIALOG")
        of:SetFrameLevel(50)
        of:SetMovable(true)
        of:EnableMouse(true)
        of:SetClampedToScreen(true)
        of:Hide()
        
        -- Add to special frames for ESC key support
        IGW_AddToSpecialFrames("IGW_OptionsFrame", true)
        
        -- Border first
        of:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        of:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local bgTexture = of:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetPoint("TOPLEFT", of, "TOPLEFT", 11, -12)
        bgTexture:SetPoint("BOTTOMRIGHT", of, "BOTTOMRIGHT", -12, 11)
        -- Use saved color or default to dark grey, always 90% opaque for options
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 0.9)
        of.bgTexture = bgTexture
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, of)
        titleBar:SetPoint("TOPLEFT", of, "TOPLEFT", 12, -12)
        titleBar:SetPoint("TOPRIGHT", of, "TOPRIGHT", -12, -12)
        titleBar:SetHeight(30)
        titleBar:SetFrameLevel(of:GetFrameLevel() + 1)
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() of:StartMoving() end)
        titleBar:SetScript("OnDragStop", function() of:StopMovingOrSizing() end)
        
        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("Improved Guild Window - Options")
        
        local closeBtn = CreateFrame("Button", nil, of, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", of, "TOPRIGHT", -10, -10)
        closeBtn:SetFrameLevel(of:GetFrameLevel() + 2)
        closeBtn:SetScript("OnClick", function() of:Hide() end)
        
        -- Content area
        local content = CreateFrame("Frame", nil, of)
        content:SetPoint("TOPLEFT", of, "TOPLEFT", 20, -50)
        content:SetPoint("BOTTOMRIGHT", of, "BOTTOMRIGHT", -20, 20)
        of.content = content
        
        local yOffset = 0
        
        -- Visual Settings Section
        local visualHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        visualHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        visualHeader:SetText("Visual Settings")
        yOffset = yOffset - 25
        
        -- Opacity Slider
        local opacityLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        opacityLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        opacityLabel:SetText("Window Opacity:")
        
        local opacitySlider = CreateFrame("Slider", "IGW_OpacitySlider", content, "OptionsSliderTemplate")
        opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -10)
        opacitySlider:SetWidth(300)
        opacitySlider:SetHeight(15)
        opacitySlider:SetMinMaxValues(0.3, 1.0)
        opacitySlider:SetValueStep(0.05)
        opacitySlider:SetValue(IGW_BG_OPACITY)
        getglobal("IGW_OpacitySliderLow"):SetText("30%")
        getglobal("IGW_OpacitySliderHigh"):SetText("100%")
        getglobal("IGW_OpacitySliderText"):SetText(string.format("%.0f%%", IGW_BG_OPACITY * 100))
        
        opacitySlider:SetScript("OnValueChanged", function()
            local value = this:GetValue()
            getglobal("IGW_OpacitySliderText"):SetText(string.format("%.0f%%", value * 100))
            -- Will be applied on save
        end)
        of.opacitySlider = opacitySlider
        
        -- Color options label (to the right of slider, moved up)
        local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        colorLabel:SetPoint("LEFT", opacitySlider, "RIGHT", 40, 30)
        colorLabel:SetText("Background Color:")
        
        -- Define 8 color options
        local colorOptions = {
            {r = 0.15, g = 0.15, b = 0.15, name = "Dark Grey"},     -- Default
            {r = 0.05, g = 0.05, b = 0.05, name = "Black"},
            {r = 0.1, g = 0.1, b = 0.2, name = "Dark Blue"},
            {r = 0.2, g = 0.15, b = 0.1, name = "Dark Brown"},
            {r = 0.15, g = 0.2, b = 0.15, name = "Dark Green"},
            {r = 0.2, g = 0.1, b = 0.15, name = "Dark Purple"},
            {r = 0.2, g = 0.15, b = 0.15, name = "Dark Red"},
            {r = 0.1, g = 0.15, b = 0.15, name = "Dark Cyan"}
        }
        
        -- Current selected color (default to first option)
        of.selectedColor = 1
        
        -- Create clickable color boxes
        local colorBoxes = {}
        for i, color in ipairs(colorOptions) do
            local box = CreateFrame("Button", nil, content)
            box:SetPoint("LEFT", colorLabel, "BOTTOMLEFT", (i-1) * 32, -30)
            box:SetWidth(30)
            box:SetHeight(30)
            
            -- Store color info on box
            box.colorName = color.name
            box.colorIndex = i
            
            -- Border first
            box:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            box:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            
            -- Background color (inset to stay within border)
            local bgTex = box:CreateTexture(nil, "BACKGROUND")
            bgTex:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
            bgTex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
            bgTex:SetTexture(color.r, color.g, color.b, 1)
            box.bgTex = bgTex
            
            -- Selection indicator (white border when selected)
            box.selected = false
            
            box:SetScript("OnClick", function()
                -- Deselect all
                for j, b in ipairs(colorBoxes) do
                    b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                    b.selected = false
                end
                -- Select this one
                this:SetBackdropBorderColor(1, 1, 1, 1)
                this.selected = true
                of.selectedColor = this.colorIndex
            end)
            
            box:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:SetText(this.colorName)
                GameTooltip:Show()
            end)
            
            box:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            
            colorBoxes[i] = box
        end
        
        -- Preselect the saved color or default to first
        local savedColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            savedColor = ImprovedGuildWindowDB.bgColor
        end
        local selectedIndex = 1
        for i, color in ipairs(colorOptions) do
            -- Compare with small tolerance for floating point
            local rMatch = math.abs(color.r - savedColor.r) < 0.01
            local gMatch = math.abs(color.g - savedColor.g) < 0.01
            local bMatch = math.abs(color.b - savedColor.b) < 0.01
            if rMatch and gMatch and bMatch then
                selectedIndex = i
                break
            end
        end
        colorBoxes[selectedIndex]:SetBackdropBorderColor(1, 1, 1, 1)
        colorBoxes[selectedIndex].selected = true
        of.selectedColor = selectedIndex
        
        of.colorOptions = colorOptions
        of.colorBoxes = colorBoxes
        
        yOffset = yOffset - 65
        
        -- Divider
        local divider1 = content:CreateTexture(nil, "ARTWORK")
        divider1:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        divider1:SetPoint("TOP", content, "TOP", 103, yOffset)
        divider1:SetWidth(830)
        divider1:SetHeight(16)
        yOffset = yOffset - 30
        
        -- Window Behavior Section
        local behaviorHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        behaviorHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        behaviorHeader:SetText("Window Behavior")
        yOffset = yOffset - 25
        
        -- Remember Open Windows Checkbox
        local rememberWindowsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        rememberWindowsCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        rememberWindowsCheck:SetWidth(24)
        rememberWindowsCheck:SetHeight(24)
        rememberWindowsCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberWindows) or false)
        
        local rememberWindowsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rememberWindowsLabel:SetPoint("LEFT", rememberWindowsCheck, "RIGHT", 5, 0)
        rememberWindowsLabel:SetText("Remember which windows are open")
        
        of.rememberWindowsCheck = rememberWindowsCheck
        yOffset = yOffset - 25
        
        -- Allow Moving Side Windows Checkbox
        local allowMoveSideCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        allowMoveSideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        allowMoveSideCheck:SetWidth(24)
        allowMoveSideCheck:SetHeight(24)
        allowMoveSideCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.allowMoveSideWindows) or false)
        
        local allowMoveSideLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        allowMoveSideLabel:SetPoint("LEFT", allowMoveSideCheck, "RIGHT", 5, 0)
        allowMoveSideLabel:SetText("Allow moving side windows (Member Details / Guild Info)")
        
        of.allowMoveSideCheck = allowMoveSideCheck
        yOffset = yOffset - 25
        
        -- Show Offline by Default Checkbox
        local showOfflineDefaultCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        showOfflineDefaultCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        showOfflineDefaultCheck:SetWidth(24)
        showOfflineDefaultCheck:SetHeight(24)
        showOfflineDefaultCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.showOffline ~= false))
        
        local showOfflineDefaultLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        showOfflineDefaultLabel:SetPoint("LEFT", showOfflineDefaultCheck, "RIGHT", 5, 0)
        showOfflineDefaultLabel:SetText("Show offline members by default (Member Details tab)")
        
        of.showOfflineDefaultCheck = showOfflineDefaultCheck
        yOffset = yOffset - 25
        
        -- Remember Sorting Checkbox
        local rememberSortingCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        rememberSortingCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        rememberSortingCheck:SetWidth(24)
        rememberSortingCheck:SetHeight(24)
        rememberSortingCheck:SetChecked((ImprovedGuildWindowDB and ImprovedGuildWindowDB.rememberSorting ~= false))
        
        local rememberSortingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rememberSortingLabel:SetPoint("LEFT", rememberSortingCheck, "RIGHT", 5, 0)
        rememberSortingLabel:SetText("Remember sorting (column and direction)")
        
        of.rememberSortingCheck = rememberSortingCheck
        yOffset = yOffset - 30
        
        -- Divider
        local divider2 = content:CreateTexture(nil, "ARTWORK")
        divider2:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
        divider2:SetPoint("TOP", content, "TOP", 103, yOffset)
        divider2:SetWidth(830)
        divider2:SetHeight(16)
        yOffset = yOffset - 25
        
        -- Default View Section
        local defaultViewHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        defaultViewHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        defaultViewHeader:SetText("Default View")
        yOffset = yOffset - 25
        
        -- Default Tab Label
        local defaultTabLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        defaultTabLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        defaultTabLabel:SetText("Default tab on open:")
        yOffset = yOffset - 25
        
        -- Radio Buttons for Default Tab
        local guildMembersRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        guildMembersRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        guildMembersRadio:SetWidth(20)
        guildMembersRadio:SetHeight(20)
        
        local guildMembersLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        guildMembersLabel:SetPoint("LEFT", guildMembersRadio, "RIGHT", 5, 0)
        guildMembersLabel:SetText("Guild Members (online only)")
        
        yOffset = yOffset - 25
        
        local memberDetailsRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        memberDetailsRadio:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
        memberDetailsRadio:SetWidth(20)
        memberDetailsRadio:SetHeight(20)
        
        local memberDetailsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        memberDetailsLabel:SetPoint("LEFT", memberDetailsRadio, "RIGHT", 5, 0)
        memberDetailsLabel:SetText("Notes & Rank (all members)")
        
        -- Set initial radio button states
        local defaultTab = (ImprovedGuildWindowDB and ImprovedGuildWindowDB.defaultTab) or "details"
        if defaultTab == "details" then
            guildMembersRadio:SetChecked(true)
            memberDetailsRadio:SetChecked(false)
        elseif defaultTab == "detailed" then
            -- If set to detailed view, default to guild members for now (no radio option yet)
            guildMembersRadio:SetChecked(true)
            memberDetailsRadio:SetChecked(false)
        else
            guildMembersRadio:SetChecked(false)
            memberDetailsRadio:SetChecked(true)
        end
        
        -- Radio button scripts
        guildMembersRadio:SetScript("OnClick", function()
            guildMembersRadio:SetChecked(true)
            memberDetailsRadio:SetChecked(false)
        end)
        
        memberDetailsRadio:SetScript("OnClick", function()
            guildMembersRadio:SetChecked(false)
            memberDetailsRadio:SetChecked(true)
        end)
        
        of.guildMembersRadio = guildMembersRadio
        of.memberDetailsRadio = memberDetailsRadio
        
        -- Save Button
        local saveBtn = CreateFrame("Button", nil, of, "UIPanelButtonTemplate")
        saveBtn:SetPoint("BOTTOM", of, "BOTTOM", 0, 15)
        saveBtn:SetWidth(100)
        saveBtn:SetHeight(25)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            IGW:SaveOptions()
            of:Hide()
        end)
        
        IGW.optionsFrame = of
    end
    
    local of = IGW.optionsFrame
    if of:IsVisible() then
        of:Hide()
    else
        -- Update background color before showing
        if of.bgTexture then
            local bgColor = {r = 0.15, g = 0.15, b = 0.15}
            if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
                bgColor = ImprovedGuildWindowDB.bgColor
            end
            of.bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 0.9)
        end
        -- Anchor top of options window to top of main window
        of:ClearAllPoints()
        of:SetPoint("TOP", frame, "TOP", 0, 0)
        of:Show()
    end
end


-- Save Options from settings window
function IGW:SaveOptions()
    local of = IGW.optionsFrame
    if not of then return end
    
    -- Initialize DB if it doesn't exist
    if not ImprovedGuildWindowDB then
        ImprovedGuildWindowDB = {}
    end
    
    -- Save opacity
    local opacityValue = of.opacitySlider:GetValue()
    IGW_BG_OPACITY = opacityValue
    ImprovedGuildWindowDB.opacity = opacityValue
    
    -- Apply opacity and color to all windows immediately
    local selectedColor = of.colorOptions and of.colorOptions[of.selectedColor or 1]
    if selectedColor then
        if frame and frame.bgTexture then
            frame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        if IGW.detailsFrame and IGW.detailsFrame.bgTexture then
            IGW.detailsFrame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        if IGW.infoFrame and IGW.infoFrame.bgTexture then
            IGW.infoFrame.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, opacityValue)
        end
        -- Apply to options window (always 90% opaque)
        if of and of.bgTexture then
            of.bgTexture:SetTexture(selectedColor.r, selectedColor.g, selectedColor.b, 0.9)
        end
        
        -- Save background color
        ImprovedGuildWindowDB.bgColor = {r = selectedColor.r, g = selectedColor.g, b = selectedColor.b}
    end
    
    -- Save remember windows setting
    ImprovedGuildWindowDB.rememberWindows = of.rememberWindowsCheck:GetChecked() == 1
    
    -- Save allow moving side windows setting
    ImprovedGuildWindowDB.allowMoveSideWindows = of.allowMoveSideCheck:GetChecked() == 1
    
    -- Apply movable state to side windows immediately
    if IGW.detailsFrame then
        IGW.detailsFrame:SetMovable(ImprovedGuildWindowDB.allowMoveSideWindows)
    end
    if IGW.infoFrame then
        IGW.infoFrame:SetMovable(ImprovedGuildWindowDB.allowMoveSideWindows)
    end
    
    -- Save show offline default setting and apply immediately
    ImprovedGuildWindowDB.showOffline = of.showOfflineDefaultCheck:GetChecked() == 1
    showOffline = ImprovedGuildWindowDB.showOffline
    if frame and frame.offlineCheck then
        frame.offlineCheck:SetChecked(showOffline)
    end
    
    -- Save remember sorting setting
    ImprovedGuildWindowDB.rememberSorting = of.rememberSortingCheck:GetChecked() == 1
    
    -- Save which windows are currently open (if remember is enabled)
    if ImprovedGuildWindowDB.rememberWindows then
        ImprovedGuildWindowDB.windowStates = {
            detailsOpen = IGW.detailsFrame and IGW.detailsFrame:IsVisible() or false,
            infoOpen = IGW.infoFrame and IGW.infoFrame:IsVisible() or false
        }
    end
    
    -- Save default tab
    if of.guildMembersRadio:GetChecked() then
        ImprovedGuildWindowDB.defaultTab = "details"
    else
        ImprovedGuildWindowDB.defaultTab = "roster"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Options saved!|r")
end


-- Slash command
SLASH_IMPROVEDGUILDWINDOW1 = "/igw"
SLASH_IMPROVEDGUILDWINDOW2 = "/improvedguild"
SlashCmdList["IMPROVEDGUILDWINDOW"] = function(msg)
    msg = string.lower(msg or "")
    
    -- Sync status command
    if msg == "sync status" then
        if not IGW_Sync then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
            return
        end
        
        local status = IGW_Sync:GetSyncStatus()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW Sync Status]|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Connected peers: " .. status.peers)
        DEFAULT_CHAT_FRAME:AddMessage("  Announcements: " .. status.announcements)
        if status.lastSync > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  Last sync: " .. date("%c", status.lastSync))
        end
        
        -- Show peer details
        if IGW_Sync.data and IGW_Sync.data.peers then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Peer Details:|r")
            local now = time()
            for name, peer in pairs(IGW_Sync.data.peers) do
                local secondsAgo = now - (peer.lastSeen or 0)
                DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " (v" .. (peer.version or "?") .. ") - seen " .. secondsAgo .. "s ago")
            end
        end
        return
    end
    
    -- Sync refresh command
    if msg == "sync refresh" then
        if not IGW_Sync then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
            return
        end
        
        IGW_Sync:RequestDataSync()
        return
    end
    
    -- Announce command
    if string.sub(msg, 1, 8) == "announce" then
        if not IGW_Sync then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
            return
        end
        
        local message = string.sub(msg, 10) -- Skip "announce "
        if message and message ~= "" then
            IGW_Sync:PostAnnouncement(message, "normal")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Announcement sent to guild")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Usage: /igw announce <message>")
        end
        return
    end
    
    -- Clear announcements command (local only)
    if msg == "clear announcements" or msg == "clearann" then
        if not IGW_Sync then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
            return
        end
        
        IGW_Sync:ClearAnnouncements()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r All announcements cleared (local only)")
        
        -- Refresh Page 5 if it's open
        if IGW.infoFrame and IGW.infoFrame.currentPage == 5 then
            IGW:UpdateEventsPage()
        end
        return
    end
    
    -- Clear announcements guild-wide (officers only)
    if msg == "clearann guild" or msg == "clear announcements guild" then
        if not IGW_Sync then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Sync module not loaded")
            return
        end
        
        -- Check if player is an officer
        if not IGW:IsOfficer() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r This command is only available to officers")
            return
        end
        
        IGW_Sync:ClearAnnouncementsGuildWide()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Guild-wide announcement clear broadcast sent")
        
        -- Refresh Page 5 if it's open
        if IGW.infoFrame and IGW.infoFrame.currentPage == 5 then
            IGW:UpdateEventsPage()
        end
        return
    end
    
    -- Standard commands
    if msg == "" or msg == "show" or msg == "toggle" then
        IGW:ToggleWindow()
    elseif msg == "hide" then
        frame:Hide()
    elseif msg == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("=== IGW Debug Info ===")
        DEFAULT_CHAT_FRAME:AddMessage("Total roster data: " .. table.getn(rosterData))
        DEFAULT_CHAT_FRAME:AddMessage("Current filterRank: " .. filterRank)
        DEFAULT_CHAT_FRAME:AddMessage("Num ranks: " .. GuildControlGetNumRanks())
        
        -- Count members by rank
        local rankCounts = {}
        for i = 0, 9 do rankCounts[i] = 0 end
        for i, m in ipairs(rosterData) do
            if m.rankIndex then
                rankCounts[m.rankIndex] = (rankCounts[m.rankIndex] or 0) + 1
            end
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("Members per rank:")
        for i = 1, GuildControlGetNumRanks() do
            local rankName = GuildControlGetRankName(i)
            local rankIdx = i - 1
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s (idx %d): %d members", 
                rankName, rankIdx, rankCounts[rankIdx] or 0))
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("First 5 members:")
        for i = 1, math.min(5, table.getn(rosterData)) do
            local m = rosterData[i]
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: rank=%s, rankIndex=%s", 
                m.name or "nil", m.rank or "nil", tostring(m.rankIndex or "nil")))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Improved Guild Window Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("/igw - Toggle window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw show - Show window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw hide - Hide window")
        DEFAULT_CHAT_FRAME:AddMessage("/igw debug - Show debug info")
        DEFAULT_CHAT_FRAME:AddMessage("/igw sync status - Show sync status")
        DEFAULT_CHAT_FRAME:AddMessage("/igw sync refresh - Request data sync")
        DEFAULT_CHAT_FRAME:AddMessage("/igw announce <msg> - Post guild announcement")
        DEFAULT_CHAT_FRAME:AddMessage("/igw clearann - Clear all announcements (local)")
        DEFAULT_CHAT_FRAME:AddMessage("/igw clearann guild - Clear guild announcements (officers)")
    end
end

-- Update Page 5 - Announcements & Addon Users
function IGW:UpdateEventsPage()
    if not IGW_Sync then return end
    if not IGW.infoFrame or not IGW.infoFrame.content5 then return end
    
    local content5 = IGW.infoFrame.content5
    
    -- Mark announcements as read only when page is visible
    if IGW.infoFrame:IsVisible() and IGW.infoFrame.currentPage == 5 then
        self:MarkAnnouncementsAsRead()
    end
    
    -- Clear existing content
    if content5.children then
        for _, child in ipairs(content5.children) do
            child:Hide()
        end
    end
    content5.children = {}
    
    local yOffset = -10
    
    -- Sync status
    local status = IGW_Sync:GetSyncStatus()
    local statusText = content5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", content5, "TOP", 0, yOffset)
    statusText:SetWidth(220)
    statusText:SetTextColor(0.7, 0.7, 0.7)
    statusText:SetText(status.peers .. " addon users online")
    table.insert(content5.children, statusText)
    yOffset = yOffset - 15
    
    -- Title: Recent Announcements
    local annTitle = content5:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    annTitle:SetPoint("TOP", content5, "TOP", 0, yOffset)
    annTitle:SetWidth(220)
    annTitle:SetText("Recent Announcements")
    annTitle:SetTextColor(1, 0.82, 0)
    table.insert(content5.children, annTitle)
    yOffset = yOffset - 14
    
    -- Get recent announcements (only 1 newest)
    local announcements = IGW_Sync:GetAnnouncements(1)
    
    if table.getn(announcements) == 0 then
        local noAnn = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noAnn:SetPoint("TOP", content5, "TOP", 0, yOffset)
        noAnn:SetWidth(220)
        noAnn:SetText("No recent announcements")
        noAnn:SetTextColor(0.6, 0.6, 0.6)
        table.insert(content5.children, noAnn)
        yOffset = yOffset - 12
    else
        local ann = announcements[1]
        
        -- Author and time
        local annHeader = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        annHeader:SetPoint("TOP", content5, "TOP", 0, yOffset)
        annHeader:SetWidth(220)
        annHeader:SetText(ann.author .. " - " .. date("%m/%d", ann.timestamp))
        annHeader:SetTextColor(0.7, 0.7, 1)
        table.insert(content5.children, annHeader)
        yOffset = yOffset - 11
        
        -- Message (truncate to 120 chars for compactness)
        local message = ann.message
        if string.len(message) > 120 then
            message = string.sub(message, 1, 117) .. "..."
        end
        
        local annMsg = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        annMsg:SetPoint("TOP", content5, "TOP", 0, yOffset)
        annMsg:SetWidth(220)
        annMsg:SetText(message)
        annMsg:SetTextColor(1, 1, 1)
        table.insert(content5.children, annMsg)
        
        -- Fixed space for announcement (120 chars = ~3 lines * 11px)
        yOffset = yOffset - 33
    end
    
    yOffset = yOffset - 8
    
    -- Title: Raid Schedule
    local raidTitle = content5:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidTitle:SetPoint("TOP", content5, "TOP", 0, yOffset)
    raidTitle:SetWidth(220)
    raidTitle:SetText("Raid Schedule")
    raidTitle:SetTextColor(1, 0.82, 0)
    table.insert(content5.children, raidTitle)
    yOffset = yOffset - 14
    
    -- Get raid schedule from sync data
    local raidSchedule = {}
    if IGW_Sync.data and IGW_Sync.data.raidSchedule then
        -- Make sure it's a table, not a string
        if type(IGW_Sync.data.raidSchedule) == "table" then
            raidSchedule = IGW_Sync.data.raidSchedule
        end
    end
    
    -- Days of the week
    local days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
    
    for _, day in ipairs(days) do
        local raids = raidSchedule[day]
        
        -- Day name
        local dayText = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dayText:SetPoint("TOP", content5, "TOP", 0, yOffset)
        dayText:SetWidth(220)
        dayText:SetJustifyH("LEFT")
        dayText:SetText(day .. ":")
        dayText:SetTextColor(0.9, 0.9, 0.5)
        table.insert(content5.children, dayText)
        yOffset = yOffset - 12
        
        -- Show up to 2 raids per day
        local hasRaids = false
        if raids then
            for raidNum = 1, 2 do
                if raids[raidNum] and raids[raidNum].name and raids[raidNum].name ~= "" then
                    hasRaids = true
                    local raidInfo = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    raidInfo:SetPoint("TOP", content5, "TOP", 5, yOffset)
                    raidInfo:SetWidth(215)
                    raidInfo:SetJustifyH("LEFT")
                    
                    local text = "  " .. raids[raidNum].name
                    if raids[raidNum].time and raids[raidNum].time ~= "" then
                        text = text .. " @ " .. raids[raidNum].time
                    end
                    raidInfo:SetText(text)
                    raidInfo:SetTextColor(0.8, 1, 0.8)
                    table.insert(content5.children, raidInfo)
                    yOffset = yOffset - 11
                else
                    -- Reserve space even for empty raid slots
                    yOffset = yOffset - 11
                end
            end
        else
            -- No raids for this day, reserve space for 2 empty slots
            yOffset = yOffset - 22
        end
        
        -- If no raids, show "No raid scheduled"
        if not hasRaids then
            local noRaid = content5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noRaid:SetPoint("TOP", content5, "TOP", 5, yOffset + 22)
            noRaid:SetWidth(215)
            noRaid:SetJustifyH("LEFT")
            noRaid:SetText("  No raid scheduled")
            noRaid:SetTextColor(0.5, 0.5, 0.5)
            table.insert(content5.children, noRaid)
        end
        
        yOffset = yOffset - 2 -- Small gap between days
    end
    
    -- Edit button for officers only
    if self:IsOfficer() then
        yOffset = yOffset - 10
        local editBtn = CreateFrame("Button", nil, content5, "UIPanelButtonTemplate")
        editBtn:SetWidth(100)
        editBtn:SetHeight(20)
        editBtn:SetPoint("TOP", content5, "TOP", -55, yOffset)
        editBtn:SetText("Edit Schedule")
        editBtn:SetScript("OnClick", function()
            IGW:ShowRaidScheduleEditor()
        end)
        table.insert(content5.children, editBtn)
        
        local announceBtn = CreateFrame("Button", nil, content5, "UIPanelButtonTemplate")
        announceBtn:SetWidth(100)
        announceBtn:SetHeight(20)
        announceBtn:SetPoint("TOP", content5, "TOP", 55, yOffset)
        announceBtn:SetText("Announce")
        announceBtn:SetScript("OnClick", function()
            IGW:ShowAnnouncementDialog()
        end)
        table.insert(content5.children, announceBtn)
    end
end


-- Show raid schedule editor dialog
function IGW:ShowRaidScheduleEditor()
    if not IGW_Sync then return end
    
    -- Create dialog if needed
    if not self.raidScheduleDialog then
        local dialog = CreateFrame("Frame", "IGW_RaidScheduleDialog", UIParent)
        dialog:SetWidth(450)
        dialog:SetHeight(660)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG")
        
        -- Match main window background style
        dialog:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        dialog:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture (inside the border)
        local bgTexture = dialog:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetPoint("TOPLEFT", dialog, "TOPLEFT", 11, -12)
        bgTexture:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 11)
        
        -- Use saved color or default to dark grey
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 1)
        
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", function() this:StartMoving() end)
        dialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        
        -- Close on Escape key
        dialog:EnableKeyboard(true)
        dialog:SetScript("OnKeyDown", function()
            if arg1 == "ESCAPE" then
                this:Hide()
            end
        end)
        
        -- Title
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", dialog, "TOP", 0, -20)
        title:SetText("Edit Raid Schedule")
        
        -- Instruction text
        local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instructions:SetPoint("TOP", title, "BOTTOM", 0, -8)
        instructions:SetText("Up to 2 raids per day")
        instructions:SetTextColor(0.7, 0.7, 0.7)
        
        -- Format example
        local example = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        example:SetPoint("TOP", instructions, "BOTTOM", 0, -5)
        example:SetText("Example: MC   8pm ST")
        example:SetTextColor(0.5, 0.8, 0.5)
        
        -- Create scroll frame for days
        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog)
        scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -80)
        scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -35, 60)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(400)
        scrollChild:SetHeight(650)
        scrollFrame:SetScrollChild(scrollChild)
        
        -- Scrollbar
        local scrollBar = CreateFrame("Slider", nil, scrollFrame)
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 15, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 15, 16)
        scrollBar:SetWidth(16)
        scrollBar:SetOrientation("VERTICAL")
        scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        scrollBar:SetMinMaxValues(0, 250)
        scrollBar:SetValueStep(20)
        scrollBar:SetValue(0)
        scrollBar:SetScript("OnValueChanged", function()
            scrollFrame:SetVerticalScroll(this:GetValue())
        end)
        
        -- Helper function to filter characters
        local function FilterText(text, allowedChars)
            -- Remove disallowed characters: ; : ,
            text = string.gsub(text, "[;:,]", "")
            return text
        end
        
        -- Day inputs
        local days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
        dialog.inputs = {}
        dialog.allInputs = {} -- Flat list for tab navigation
        local yOffset = -10
        
        for dayIndex, day in ipairs(days) do
            -- Day label (centered)
            local label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("TOP", scrollChild, "TOP", 0, yOffset)
            label:SetText(day)
            label:SetTextColor(1, 0.82, 0)
            yOffset = yOffset - 18
            
            dialog.inputs[day] = {}
            
            -- Two raids per day
            for raidNum = 1, 2 do
                -- Container for this raid's inputs (for centering)
                local raidLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                raidLabel:SetPoint("TOP", scrollChild, "TOP", -105, yOffset - 3)
                raidLabel:SetText("Raid " .. raidNum .. ":")
                raidLabel:SetTextColor(0.7, 0.7, 0.7)
                
                -- Raid name input (centered)
                local nameInput = CreateFrame("EditBox", nil, scrollChild)
                nameInput:SetWidth(120)
                nameInput:SetHeight(20)
                nameInput:SetPoint("TOP", scrollChild, "TOP", -25, yOffset)
                nameInput:SetAutoFocus(false)
                nameInput:SetMaxLetters(30)
                
                -- Backdrop for name input
                nameInput:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                nameInput:SetBackdropColor(0.1, 0.1, 0.1, 1)
                nameInput:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                
                -- Font for input
                nameInput:SetFontObject(GameFontHighlightSmall)
                nameInput:SetTextInsets(5, 5, 0, 0)
                
                -- Character filtering
                nameInput:SetScript("OnTextChanged", function()
                    local text = this:GetText()
                    local filtered = FilterText(text)
                    if text ~= filtered then
                        this:SetText(filtered)
                    end
                end)
                
                -- Tab navigation and shortcuts
                nameInput:SetScript("OnTabPressed", function()
                    local nextInput = dialog.allInputs[this.tabIndex + 1]
                    if nextInput then
                        nextInput:SetFocus()
                    end
                end)
                nameInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
                nameInput:SetScript("OnEnterPressed", function() 
                    local nextInput = dialog.allInputs[this.tabIndex + 1]
                    if nextInput then
                        nextInput:SetFocus()
                    else
                        this:ClearFocus()
                    end
                end)
                nameInput:SetScript("OnEditFocusGained", function()
                    this:SetBackdropBorderColor(0.8, 0.8, 1, 1)
                    this:HighlightText()
                end)
                nameInput:SetScript("OnEditFocusLost", function()
                    this:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    this:HighlightText(0, 0)
                end)
                
                -- Time input (centered next to name)
                local timeInput = CreateFrame("EditBox", nil, scrollChild)
                timeInput:SetWidth(80)
                timeInput:SetHeight(20)
                timeInput:SetPoint("LEFT", nameInput, "RIGHT", 10, 0)
                timeInput:SetAutoFocus(false)
                timeInput:SetMaxLetters(15)
                
                -- Backdrop for time input
                timeInput:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                timeInput:SetBackdropColor(0.1, 0.1, 0.1, 1)
                timeInput:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                
                -- Font for input
                timeInput:SetFontObject(GameFontHighlightSmall)
                timeInput:SetTextInsets(5, 5, 0, 0)
                
                -- Character filtering
                timeInput:SetScript("OnTextChanged", function()
                    local text = this:GetText()
                    local filtered = FilterText(text)
                    if text ~= filtered then
                        this:SetText(filtered)
                    end
                end)
                
                -- Tab navigation and shortcuts
                timeInput:SetScript("OnTabPressed", function()
                    local nextInput = dialog.allInputs[this.tabIndex + 1]
                    if nextInput then
                        nextInput:SetFocus()
                    end
                end)
                timeInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
                timeInput:SetScript("OnEnterPressed", function() 
                    local nextInput = dialog.allInputs[this.tabIndex + 1]
                    if nextInput then
                        nextInput:SetFocus()
                    else
                        this:ClearFocus()
                    end
                end)
                timeInput:SetScript("OnEditFocusGained", function()
                    this:SetBackdropBorderColor(0.8, 0.8, 1, 1)
                    this:HighlightText()
                end)
                timeInput:SetScript("OnEditFocusLost", function()
                    this:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    this:HighlightText(0, 0)
                end)
                
                dialog.inputs[day][raidNum] = {
                    name = nameInput,
                    time = timeInput
                }
                
                -- Add to flat list for tab navigation
                table.insert(dialog.allInputs, nameInput)
                nameInput.tabIndex = table.getn(dialog.allInputs)
                table.insert(dialog.allInputs, timeInput)
                timeInput.tabIndex = table.getn(dialog.allInputs)
                
                yOffset = yOffset - 23
            end
            
            yOffset = yOffset - 8
        end
        
        -- Save button
        local saveBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        saveBtn:SetWidth(70)
        saveBtn:SetHeight(22)
        saveBtn:SetPoint("BOTTOM", dialog, "BOTTOM", -110, 20)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            IGW:SaveRaidSchedule()
            dialog:Hide()
        end)
        
        -- Clear Schedule button
        local clearBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        clearBtn:SetWidth(100)
        clearBtn:SetHeight(22)
        clearBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 20)
        clearBtn:SetText("Clear Schedule")
        clearBtn:SetScript("OnClick", function()
            -- Clear all inputs
            for day, raids in pairs(dialog.inputs) do
                for raidNum, controls in pairs(raids) do
                    controls.name:SetText("")
                    controls.time:SetText("")
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Schedule cleared (not saved yet)")
        end)
        
        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetWidth(70)
        cancelBtn:SetHeight(22)
        cancelBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 110, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            dialog:Hide()
        end)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -5, -5)
        
        dialog:Hide()
        self.raidScheduleDialog = dialog
    end
    
    -- Populate with current schedule
    local schedule = {}
    if IGW_Sync.data and IGW_Sync.data.raidSchedule and type(IGW_Sync.data.raidSchedule) == "table" then
        schedule = IGW_Sync.data.raidSchedule
    end
    
    for day, raids in pairs(self.raidScheduleDialog.inputs) do
        for raidNum, controls in pairs(raids) do
            if schedule[day] and type(schedule[day]) == "table" and schedule[day][raidNum] then
                controls.name:SetText(schedule[day][raidNum].name or "")
                controls.time:SetText(schedule[day][raidNum].time or "")
            else
                controls.name:SetText("")
                controls.time:SetText("")
            end
        end
    end
    
    self.raidScheduleDialog:Show()
end

-- Save raid schedule
function IGW:SaveRaidSchedule()
    if not IGW_Sync or not self.raidScheduleDialog then return end
    
    local schedule = {}
    
    for day, raids in pairs(self.raidScheduleDialog.inputs) do
        schedule[day] = {}
        
        for raidNum, controls in pairs(raids) do
            local raidName = controls.name:GetText()
            local time = controls.time:GetText()
            
            -- Only save if raid name is not empty
            if raidName and raidName ~= "" then
                schedule[day][raidNum] = {
                    name = raidName,
                    time = time or ""
                }
            end
        end
    end
    
    -- Save and broadcast
    IGW_Sync:UpdateRaidSchedule(schedule)
    
    -- Refresh Page 5 if open
    if IGW.infoFrame and IGW.infoFrame.currentPage == 5 then
        IGW:UpdateEventsPage()
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Raid schedule updated and broadcast to guild")
end

-- Show announcement dialog
function IGW:ShowAnnouncementDialog()
    if not IGW_Sync then return end
    
    -- Create dialog if needed
    if not self.announcementDialog then
        local dialog = CreateFrame("Frame", "IGW_AnnouncementDialog", UIParent)
        dialog:SetWidth(350)
        dialog:SetHeight(250)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG")
        
        -- Match main window background style
        dialog:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        dialog:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Create solid background texture
        local bgTexture = dialog:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetPoint("TOPLEFT", dialog, "TOPLEFT", 11, -12)
        bgTexture:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 11)
        
        local bgColor = {r = 0.15, g = 0.15, b = 0.15}
        if ImprovedGuildWindowDB and ImprovedGuildWindowDB.bgColor then
            bgColor = ImprovedGuildWindowDB.bgColor
        end
        bgTexture:SetTexture(bgColor.r, bgColor.g, bgColor.b, 1)
        
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", function() this:StartMoving() end)
        dialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        
        -- Close on Escape
        dialog:EnableKeyboard(true)
        dialog:SetScript("OnKeyDown", function()
            if arg1 == "ESCAPE" then
                this:Hide()
            end
        end)
        
        -- Title
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", dialog, "TOP", 0, -20)
        title:SetText("Guild Announcement")
        
        -- Instruction
        local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instructions:SetPoint("TOP", title, "BOTTOM", 0, -8)
        instructions:SetText("Max 255 characters")
        instructions:SetTextColor(0.7, 0.7, 0.7)
        
        -- Multi-line text input (ScrollFrame with EditBox)
        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog)
        scrollFrame:SetPoint("TOP", instructions, "BOTTOM", 0, -10)
        scrollFrame:SetWidth(310)
        scrollFrame:SetHeight(90)
        
        -- Backdrop for text area
        scrollFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        scrollFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)
        scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        
        -- Enable mouse on scrollframe so clicking anywhere focuses editbox
        scrollFrame:EnableMouse(true)
        scrollFrame:SetScript("OnMouseDown", function()
            dialog.editBox:SetFocus()
        end)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetWidth(300)
        editBox:SetHeight(200)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(255)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetTextInsets(5, 5, 5, 5)
        
        scrollFrame:SetScrollChild(editBox)
        
        -- Make editbox usable
        editBox:SetScript("OnEscapePressed", function() 
            this:ClearFocus() 
        end)
        editBox:SetScript("OnEditFocusGained", function()
            scrollFrame:SetBackdropBorderColor(0.8, 0.8, 1, 1)
            this:HighlightText(0, 0)
        end)
        editBox:SetScript("OnEditFocusLost", function()
            scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end)
        
        dialog.editBox = editBox
        
        -- Send button
        local sendBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        sendBtn:SetWidth(80)
        sendBtn:SetHeight(22)
        sendBtn:SetPoint("BOTTOM", dialog, "BOTTOM", -85, 20)
        sendBtn:SetText("Send")
        sendBtn:SetScript("OnClick", function()
            local text = dialog.editBox:GetText()
            if text and text ~= "" then
                if IGW_Sync then
                    IGW_Sync:PostAnnouncement(text)
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r Announcement sent to guild")
                    dialog.editBox:SetText("")
                    dialog:Hide()
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[IGW]|r Please enter an announcement")
            end
        end)
        
        -- Clear All button
        local clearAllBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        clearAllBtn:SetWidth(80)
        clearAllBtn:SetHeight(22)
        clearAllBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 20)
        clearAllBtn:SetText("Clear All")
        clearAllBtn:SetScript("OnClick", function()
            if IGW_Sync then
                IGW_Sync:ClearAnnouncementsGuildWide()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[IGW]|r All announcements cleared")
            end
        end)
        
        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetWidth(80)
        cancelBtn:SetHeight(22)
        cancelBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 85, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            dialog:Hide()
        end)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -5, -5)
        
        dialog:Hide()
        self.announcementDialog = dialog
    end
    
    -- Clear previous text
    self.announcementDialog.editBox:SetText("")
    self.announcementDialog:Show()
end

-- Global entry point for other addon files (e.g. calendar switching back)
function IGW_ToggleWindow()
    IGW:ToggleWindow()
end

-- Initialize addon
IGW:OnLoad()

-- Keybind note: Users can set Shift+O in Key Bindings menu under "Improved Guild Window"