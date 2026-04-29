local api = require("api")

-- [[ LOAD STATIC DATA ]] --
local buffDB = {}
local dbLoaded, staticData = pcall(require, "/Combat_Log_pro/static_buff_list")
if dbLoaded and staticData then
    buffDB = staticData
    api.Log:Info("[CLP] Static Buff Database Loaded.")
end

local skillTypesLoaded, skillTypesData = pcall(require, "/Combat_Log_pro/skill_damage_types")
if skillTypesLoaded and skillTypesData then
    api.Log:Info("[CLP] Skill damage type database loaded.")
else
    api.Log:Info("[CLP] WARNING: skill_damage_types.lua failed to load. Using fallback table.")
end

local skillDataLoaded, SKILL_DATA = pcall(require, "/Combat_Log_pro/skill_data")
if skillDataLoaded and SKILL_DATA then
    api.Log:Info("[CLP] Skill data database loaded.")
else
    SKILL_DATA = {}
    api.Log:Info("[CLP] WARNING: skill_data.lua failed to load.")
end

local combosLoaded, SKILL_COMBOS = pcall(require, "/Combat_Log_pro/skill_combos")
if combosLoaded and SKILL_COMBOS then
    api.Log:Info("[CLP] Skill combos database loaded.")
else
    SKILL_COMBOS = {}
    api.Log:Info("[CLP] WARNING: skill_combos.lua failed to load.")
end

local addon = {
    name = "CombatLogPro",
    author = "Cydaphex",
    desc = "Combat Log with separated heal tracking and debuff scanner",
    version = "1.0.0" -- patch 243 API integration
}

-- [[ COMPATIBILITY PATCH ]] --
if LINE_HEIGHT == nil then LINE_HEIGHT = 16 end

-- ============================================================================
--  CC DATABASE & CONFIGURATION
-- ============================================================================

local ccList = {
    'Snare', 'Tripped', 'Stun', 'Impaled', 'Sleep', 'Sleeping', 'Fear', 'Petrification',
    'Poison Stun', 'Deep Freeze', 'Tripped (Strong)', 'Deep Sleep', 'Slow',
    'Freeze Up', "Alliance Soldier's Pull", 'Freeze of Evil Spirit', 'Freeze',
    'Bubble Trap', 'Wave Meteor Strike Hit', "Red Dragon's Wind Gust",
    'Hell Spear', 'Petrified', 'Dazed', 'Splashdown Bubble',
    'Strong Telekinesis', 'Telekinesis', 'Silence', "Alkaran's Curse",
    'Meteor Impact', 'Pulled', 'Disarmed', 'Horrorshow', 'Petrified Taunt',
    "Karim's Shackle", 'Shockstep Effect', "Agrax's Snare", 'Steel Trap',
    'Hammer Smash', 'Ice Wall', 'Earthen Grip', "Phantasm's Wail",
    "Ecktom's Shackle", 'Ice Shard', 'Bestial Leap', 'Explosive Ice',
    'Dizziness', 'Unconscious', 'Ice Shock', "Alexander's Powerful Freeze",
    "Trap!", 'Ice', 'Lava Trap Explosion', 'Howl of Terror', 'Eternal Silence',
    'Mana Force', 'Shock', 'Poor Landing', 'Paralyzed', 'Wraith Rooted',
    "Lost Tribe's Shockwave", 'Control', 'Lassitude', 'Shackle', 'Charm', 'Charmed',
    'Alarm Call', 'Distressed', 'Dissonance', 'Startling Strain'
}

local CC_DB = {}
for _, name in ipairs(ccList) do CC_DB[name] = true end

-- Non-combat buff/debuff filter (scanner + combat log ignores these)
-- Exact names (case-insensitive)
local IGNORE_BUFFS_RAW = {
    -- Rest / death
    "Clear Mind", "Rebirth Trauma", "Nui's Consolation", "Returning", "Regeneration",
    -- Food/drink (overflow from pattern misses)
    "Ouch, Hot!", "Ouch! Hot!", "Ouch!", "Hot!", "Well Fed", "Overfed",
    "Indigestion", "Rested", "Honey Mead", "Bubble Tea",
    "Hearty Meat", "Hearty Breakfast", "Hearty Soup", "Hearty Seed Soup",
    "Tangy Soda", "Tangy Liquor", "Refreshment", "Satiated", "Satiety",
    "Imperial Sausage", "Meatball Kebab", "Rib Kebab", "Sirloin Kebab",
    "Roast Meatballs", "Roast Ribs", "Roast Sirloin", "Sweet Golden Soup",
    "Smoked Ribs", "Golden Bacon", "Royal Ham", "Porcine Delight",
    "Jujube Juice", "Jujube Sparkling Wine", "Mysterious Wine", "Rum Runner",
    "Red Wine Vinegar", "Fruit Punch", "Milk Chocolate", "Milked Up",
    "Feast of Arcane Grace", "Feast of Noble Blessings",
    -- Movement / utility cooldowns
    "Dash", "Power Dash", "Double-Time", "Run!",
    "Glider Cooldown", "Glider CD", "Dash Cooldown",
    "Overachieving", "Portal Cooldown", "Recalled",
    "Pack Carrier", "Carrying a Trade Pack", "Overburdened",
    "Dawdling", "Meditation", "Play Dead",
    -- Equip passives
    "Equip Shield", "Equip Dual Weapons", "Equip Two-Handed Weapon",
    "Equip Dive Helmet", "Equip Swimfins",
    -- Vocation / profession
    "Good Day to Work", "Vocation Hastener Scroll", "Vocational Tonic",
    "Fishing for a Compliment", "Anyfin is Possible", "Barter $auce",
    "So Basalty", "Stainless Steal", "Martial Arts and Crafts",
    "Grain Reaper", "Transformative Farmer", "Foremost Forager",
    "Pickaxe Percussionist", "Wild Trout Clout", "Darns It All",
    "Krilling It", "Can Be Abrasive", "Truly Cathletic",
    "Needs Calf-eine", "Wool Sheared", "Bored Sheep", "Hungry Sheep",
    -- XP / loot / misc passive
    "Wayfarer", "XP Boost Potion", "Elixir of Greed", "Mischievous",
    "Luke's Helping Hand", "Daru Blessing", "Grand Loot Macaron",
    -- Swimming / diving / exploration
    "Desert Fox's Gaze", "Abyssal Archaeologist",
    "Increases Continental Dialect Proficiency",
    -- Ship / vehicle
    "Rowing", "Lowering Anchor",
    -- Honor / titles
    "ArcheMaster", "Enlightened ArcheMaster", "Grand Master",
    "The Professional", "Expert Cutpurse", "Victory Delegate",
    -- Territory blessings (specific)
    "Andrion II's Blessing", "Andrion II's Protection",
    "Amarendra IV's Blessing", "Amarendra IV's Protection",
    "Morpheus's Blessing", "Morpheus's Protection",
    -- Non-combat debuffs
    "Hangover", "Headache", "Preparing Glider",
    "Flight Speed Boost Cooldown", "Twilight Stealth Cooldown",
    "Wind Winner Disabled", "All Spooked Out",
    "Rough Sea Winds", "Unable to Shear",
}
local IGNORE_LOOKUP = {}
for _, name in ipairs(IGNORE_BUFFS_RAW) do
    IGNORE_LOOKUP[string.lower(name)] = true
end

-- Patterns that catch broad categories by keyword (lowercase)
local IGNORE_PATTERNS = {
    -- Food / drink / regen
    "food buff", "cuisine", "stew", "soup", "kebab",
    "rank %d+ food", "level %d+ effect",
    "hp recovery", "mp recovery", "mana recovery",
    "health regen", "mana regen", "hp regen", "mp regen",
    -- Gear set bonuses (Celestial/Epic/Divine/etc. Cloth/Leather/Plate Armor)
    "cloth armor", "leather armor", "plate armor",
    "cloth set", "leather set", "plate set",
    -- God/faction energy buffs (Kyprosa's Energy, Eanna's Incarnation, etc.)
    "'s energy", "'s incarnation",
    -- Zone/territory blessings
    "hero's blessing", "work permit",
    -- Equip passives
    "equip ",
    -- Glider / flight
    "glider", "fuel injection", "crystal wings", "dragon wings",
    "flaming pinion", "pinion",
    -- Costumes / merchant
    "dawnsdrop costume", "merchant's costume",
    -- Honor / military ranks
    "goblet of honor", "rank %d+ soldier", "rank %d+ knight",
    -- Spellbooks / runes
    "spellbook:", "blessed rune:", "combined rune",
    -- Ship / sailing
    "unfurl", "forewind", "mainsail", "foresail",
    -- Vocation
    "vocational", "vocation ",
    -- Potions (minor)
    "minor healing potion", "minor mana potion",
}

local isIgnoredCache = {}
local function IsIgnoredBuff(name)
    local cached = isIgnoredCache[name]
    if cached ~= nil then return cached end
    local lower = string.lower(name)
    local result = false
    if IGNORE_LOOKUP[lower] then
        result = true
    else
        for _, pat in ipairs(IGNORE_PATTERNS) do
            if string.find(lower, pat) then result = true; break end
        end
    end
    isIgnoredCache[name] = result
    return result
end

local CONFIG = {
    LIVE_WIDTH = 400,
    LIVE_HEIGHT = 480,
    HIST_WIDTH = 850,
    HIST_HEIGHT = 500,
    SIDEBAR_WIDTH = 230,
    BUTTON_WIDTH = 180,
    VISIBLE_ROWS_HIST = 22,
    VISIBLE_ROWS_LIVE = 24,
    SESSIONS_VISIBLE = 12,
    LINE_HEIGHT = 18,
    COMBAT_WAIT = 4000,
    DOT_WAIT = 3000,
    COL_OUT_NRM = "Orange",
    COL_OUT_CRIT = "Red",
    COL_INCOMING = "Orange",
    COL_HEAL = "Green",
    COL_CC   = "Purple",
    SCAN_FREQ = 200,        -- debuff/buff scanner interval in ms (100=fast, 200=default, 500=low)
    ENABLE_SCANNER = true,
    SHOW_TIMESTAMP = true,
    TIME_OFFSET = -6,
    DEBUG_UNITINFO  = false, -- set true once to probe UnitInfo magic field names
    DEBUG_EVENTS    = false, -- set true once to discover chat debuff event name
    DEBUG_HITTYPE   = false, -- set true to log raw args for negated hit events (DODGE/BLOCK/MISS/PARRY)
    DUMP_BUFFS      = false, -- set true once to dump all player buffs to file (activate while Zeal is up)
    DEBUG_PARSE     = false, -- set true to dump all ParseCombatMessage fields to file
    SCAN_TARGET_BUFFS = false, -- set true to continuously log target buffs/debuffs to file (no duplicates)
    SCAN_PLAYER_BUFFS = false, -- set true to continuously log buffs/debuffs applied to player (no duplicates)
    LOG_UNKNOWN_INCOMING = false, -- log first occurrence of each incoming ability to incoming_abilities.txt; notify in live log if unclassified
    FILTER_STATIC_SHOCK = true, -- hide sessions where the only damage is passive procs (Electric Shock, etc.)
    DEBUG_LOG_EVENTS    = false, -- set true to dump all event params to Combat_Log_pro/event_log.txt
    DEBUG_ZERO_HITS     = false, -- set true to dump target buff names on unexplained 0-damage hits (find mount/glider buff names)
}

local PALETTE = {
    Yellow = {1, 1, 0, 1}, Red = {1, 0, 0, 1}, Green = {0, 1, 0, 1},
    Cyan = {0, 1, 1, 1}, Blue = {0.3, 0.3, 1, 1}, White = {1, 1, 1, 1},
    Orange = {1, 0.5, 0, 1}, Purple = {0.8, 0.3, 1, 1}, Black = {0, 0, 0, 1},
    WarmRed = {1, 0.65, 0, 1},      -- normal outgoing hit (neon amber-orange)
    SkyBlue = {0, 1, 1, 1},           -- skill/ability name lines (pure cyan/neon)
}
local PALETTE_KEYS = {"Yellow", "Red", "Green", "Cyan", "Blue", "White", "Orange", "Purple"}

local COL_HEADER  = {0.1, 0.1, 0.1, 1.0} 
local COL_SIDEBAR = {0.15, 0.15, 0.15, 0.95} 
local COL_BODY    = {0, 0, 0, 0.7} 
local COL_LOG_BG  = {0, 0, 0, 1.0} 
local COL_BTN_RED = {0.6, 0.2, 0.2, 1.0}

-- ============================================================================
--  VARIABLES & STATE
-- ============================================================================

local wLive, wHistory, wOptions, wButton
local liveLabels, historyLabels = {}, {}
local sessionButtons = {}
local lblSessionCount, liveTitleLabel, liveBodyWidget 
local isMinimized = false

local lblWVal, lblHVal, lblOffVal, lblScanFreqVal, btnScanToggle, btnTimeToggle

local liveBuffer, displayBuffer, masterBuffer, allSessions = {}, {}, {}, {}
local currentSessionLogs, sessionByTarget = {}, {}
local logScrollOffset, sessionScrollOffset = 0, 0
local viewingMode = "LIVE"
local liveLayoutDirty = true  -- set true when window dimensions change; RebuildLiveLabels skips layout when false

local activeDots = {} 
local fightData = { outgoing = {}, incoming = {} }
local healData = { done = {}, received = {} }
local healSessionByTarget = {}
local timeSinceLastAction = 0 
local inCombat = false
local PLAYER_NAME = "Unknown" 
local nameCheckTimer = 0 

local activeDebuffsCache = {}
local activeCCSessions = {}
local buffNameCache = {}
local buffEffectCache = {}      -- buff_id -> parsed effect flags (invincible, spellShield, etc.)
local playerBuffStackCache = {} -- buffName -> stack count, refreshed each scanner tick

-- Buff names (exact, case-insensitive) that grant invincibility from mount/glider abilities.
-- Tooltip text matching often misses these since their descriptions vary.
-- Add more here after inspecting buffs in-game with SCAN_TARGET_BUFFS = true.
local KNOWN_INVINCIBLE_BUFF_NAMES = {
    ["dash"]              = true,  -- mount Dash ability (most mounts)
    ["gliding"]           = true,  -- glider deployment / glider flight state
    ["aerial evasion"]    = true,  -- glider evasion skill
    ["glider deployment"] = true,  -- glider launch animation window
    ["launch"]            = true,  -- glider launch
    ["takeoff"]           = true,  -- some glider launch variants
}

-- Buff names applied by the game when a mock duel (mock fight) concludes.
local DUEL_END_BUFF_NAMES = {
    ["mock fight win"] = true,
    ["mock fight end"] = true,
}
local lastTargetID = nil
local scannerTimer = 0
local lastTargetBuffCount = -1  -- used to skip re-scan when buff count unchanged

-- Buff scanner state (SCAN_TARGET_BUFFS)
local seenBuffIds = {}
local buffScanLoaded = false
local buffScanFile = "Combat_Log_pro/target_buffs.txt"

-- Player buff/debuff scanner state (SCAN_PLAYER_BUFFS)
local seenPlayerBuffIds = {}
local playerBuffScanLoaded = false
local playerBuffScanFile = "Combat_Log_pro/player_buffs.txt"

-- Incoming ability logger state (LOG_UNKNOWN_INCOMING)
local seenIncomingSkills = {}
local incomingSkillLoaded = false
local incomingSkillFile = "Combat_Log_pro/incoming_abilities.txt"

-- Last cast skill from SPELLCAST_SUCCEEDED (patch 243+) for pre-classification
local lastPlayerCast = nil

-- Event debug log (written to file when DEBUG_LOG_EVENTS = true)
local eventLogFile = "Combat_Log_pro/event_log.txt"
local eventLogLines = {}
local function LogEventToFile(event, args)
    local parts = { tostring(api.Time:GetUiMsec()) .. " " .. tostring(event) }
    for i, v in ipairs(args) do
        table.insert(parts, "  [" .. i .. "] " .. tostring(v))
    end
    table.insert(eventLogLines, table.concat(parts, "\n"))
    -- Write periodically (don't call File:Write every single event)
    if #eventLogLines >= 10 then
        local existing = api.File:Read(eventLogFile) or {}
        if type(existing) ~= "table" then existing = {} end
        for _, line in ipairs(eventLogLines) do
            table.insert(existing, line)
        end
        pcall(function() api.File:Write(eventLogFile, existing) end)
        eventLogLines = {}
    end
end
-- Skill currently being cast (set on SPELLCAST_START, cleared on SPELLCAST_SUCCEEDED/STOP)
local currentCast = nil
-- Whether the target is currently targeting the player (updated by TARGET_TO_TARGET_CHANGED)
local targetIsTargetingPlayerLive = false

-- Target buff effect cache (updated by scanner, read by combat handler)
local targetBuffEffects = {
    invincible = false,
    spellShieldPct = 0,   -- e.g. 200 for Glenn's Spell Shield
    runeConvertPct = 0,   -- e.g. 3.5 for Zena Basta
    runeConvertName = nil, -- buff name for display
    dmgShield = false,     -- damage absorb shield active
    dmgShieldMax = 0,      -- max absorb amount
    dmgShieldName = nil,   -- buff name
}

-- Zeal tracking (buff_id 495)
local zealActive    = false
local zealStartTime = nil
local fightZealTime = 0

-- ParseCombatMessage availability check (done once at load, not per event)
local _parseCombatMessage = ParseCombatMessage
local _parseAvailable = (type(_parseCombatMessage) == "function")

-- Timer State
local BASE_SECONDS_OF_DAY = 0
local BASE_APP_MSEC = 0
local TIME_INITIALIZED = false
local cachedTimestamp = "[..:..:..] "  -- updated once per OnUpdate tick
local frameNow = 0                     -- api.Time:GetUiMsec() cached per frame

-- Settings & Position Persistence
local SETTINGS_FILE = "Combat_Log_pro/settings.txt"
local savedSettings = {}

local function LoadSavedSettings()
    local data = api.File:Read(SETTINGS_FILE)
    if data and type(data) == "table" then
        savedSettings = data
        if data.liveW    then CONFIG.LIVE_WIDTH  = data.liveW    end
        if data.liveH    then CONFIG.LIVE_HEIGHT = data.liveH    end
        if data.scanFreq then CONFIG.SCAN_FREQ   = data.scanFreq end
    end
end

local function SaveSettings()
    local s = {}
    if wButton then
        local x, y = wButton:GetOffset()
        s.btnX = x
        s.btnY = y
    end
    if wLive then
        local x, y = wLive:GetOffset()
        s.liveX = x
        s.liveY = y
    end
    s.liveW    = CONFIG.LIVE_WIDTH
    s.liveH    = CONFIG.LIVE_HEIGHT
    s.scanFreq = CONFIG.SCAN_FREQ
    pcall(function() api.File:Write(SETTINGS_FILE, s) end)
end

local dotSkills = {
    -- Actual DoT debuffs that tick over time
    ["Electric Shock"] = true, ["Conflagration"] = true, ["Burning"] = true,
    ["Poison"] = true, ["Bleed"] = true, ["Bleeding"] = true,
    ["Deep Wound"] = true, ["Venom"] = true, ["Curse"] = true,
    -- Removed: Meteor Strike (AoE hit), Toxic Shot (direct), Piercing Shot (direct),
    -- Stalker's Mark (debuff), Summon Crows (channeled AoE), Flame Barrier (reactive)
}

-- Skill damage type table: authoritative data from game JSON (skill_damage_types.lua),
-- merged with supplemental entries for custom content, procs, and DoT debuff names.
local SKILL_DAMAGE_TYPES = skillTypesLoaded and skillTypesData or {}

-- Maps skill name -> skill tree name, used to infer observed trees from combat log.
local SKILL_TO_TREE = {
    -- Battlerage
    ["Triple Slash"]       = "Battlerage", ["Charge"]             = "Battlerage",
    ["Whirlwind Slash"]    = "Battlerage", ["Sunder Earth"]       = "Battlerage",
    ["Precision Strike"]   = "Battlerage", ["Tiger Strike"]       = "Battlerage",
    ["Behind Enemy Lines"] = "Battlerage", ["Swordfall"]          = "Battlerage",
    ["Shadowsmite"]        = "Battlerage",
    -- Witchcraft
    ["Earthen Grip"]       = "Witchcraft", ["Enervate"]           = "Witchcraft",
    ["Focal Concussion"]   = "Witchcraft", ["Dahuta's Breath"]    = "Witchcraft",
    -- Defense
    ["Shield Slam"]        = "Defense",    ["Bull Rush"]          = "Defense",
    ["Ollo's Hammer"]      = "Defense",    ["Shield Throw"]       = "Defense",
    -- Auramancy
    ["Comet's Boon"]       = "Auramancy",  ["Vicious Implosion"]  = "Auramancy",
    ["Crushing Grasp"]     = "Auramancy",  ["Abyssal Wave"]       = "Auramancy",
    -- Shadowplay
    ["Rapid Strike"]       = "Shadowplay", ["Overwhelm"]          = "Shadowplay",
    ["Wallop"]             = "Shadowplay", ["Stalker's Mark"]     = "Shadowplay",
    ["Toxic Shot"]         = "Shadowplay", ["Pin Down"]           = "Shadowplay",
    ["Throw Dagger"]       = "Shadowplay", ["Venom Blades"]       = "Shadowplay",
    -- Archery
    ["Charged Bolt"]       = "Archery",    ["Piercing Shot"]      = "Archery",
    ["Endless Arrows"]     = "Archery",    ["Boneyard"]           = "Archery",
    ["Concussive Arrow"]   = "Archery",    ["Missile Rain"]       = "Archery",
    ["Snipe"]              = "Archery",    ["Hunting Pack"]       = "Archery",
    ["Blazing Arrow"]      = "Archery",    ["Double Recurve"]     = "Archery",
    -- Sorcery
    ["Flamebolt"]          = "Sorcery",    ["Freezing Arrow"]     = "Sorcery",
    ["Arc Lightning"]      = "Sorcery",    ["Freezing Earth"]     = "Sorcery",
    ["Searing Rain"]       = "Sorcery",    ["Chain Lightning"]    = "Sorcery",
    ["Flame Barrier"]      = "Sorcery",    ["Meteor Strike"]      = "Sorcery",
    ["Gods' Whip"]         = "Sorcery",    ["Serpent Strike"]     = "Sorcery",
    -- Occultism
    ["Mana Stars"]         = "Occultism",  ["Mana Force"]         = "Occultism",
    ["Hell Spear"]         = "Occultism",  ["Hell Spears"]        = "Occultism",
    ["Absorb Lifeforce"]   = "Occultism",  ["Summon Crows"]       = "Occultism",
    ["Crippling Mire"]     = "Occultism",  ["Summon Wraith"]      = "Occultism",
    ["Death's Vengeance"]  = "Occultism",  ["Cursed Thorns"]      = "Occultism",
    -- Songcraft
    ["Critical Discord"]   = "Songcraft",  ["Dissonance"]         = "Songcraft",
    -- Vitalism
    ["Holy Bolt"]          = "Vitalism",   ["Antithesis"]         = "Vitalism",
    ["Skewer"]             = "Vitalism",
    -- Malediction (custom server)
    ["Malicious Binding"]  = "Malediction", ["Crashing Waves"]   = "Malediction",
    ["Serpent Glare"]      = "Malediction", ["Blazing Ward"]      = "Malediction",
}

-- SKILL_COMBOS loaded from skill_combos.lua at the top of this file.


-- Skills with their own backstab bonus (on top of the player's passive backattack stat).
-- Auto-populated from SKILL_DATA (skill_data.lua, generated from aa-classic.com JSON).
-- formula: the "Backstabbing..." sentence from the skill description.
-- stealth: additional % damage bonus when caster is Stealthed (from in-game observation, not in JSON).
local SKILL_BACKSTAB_BONUSES = {}
do
    local STEALTH_OVERRIDES = {
        ["Shadowsmite"] = 98,  -- observed in-game: +98% when Stealthed
    }
    for name, info in pairs(SKILL_DATA) do
        if info.backstab then
            SKILL_BACKSTAB_BONUSES[name] = { formula = info.backstab, stealth = STEALTH_OVERRIDES[name] }
        end
    end
    -- Fallback if skill_data.lua failed to load
    if not skillDataLoaded then
        SKILL_BACKSTAB_BONUSES["Shadowsmite"]  = { formula = "Backstabbing adds Physical Damage equal to 400% of Melee Attack.", stealth = 98 }
        SKILL_BACKSTAB_BONUSES["Rapid Strike"] = { formula = "Backstabbing increases Melee Critical Rate +50%." }
        SKILL_BACKSTAB_BONUSES["Pin Down"]     = { formula = "Backstabbing inflicts Bleeding on the target." }
    end
end

-- Supplemental entries are now included directly in skill_damage_types.lua (SUPPLEMENTAL section).

-- Auto-learned cache: when a skill not in the table is inferred from mitigation,
-- the result is cached here so subsequent hits are consistent.
local skillTypeCache = {}

-- Short display labels for damage type tags in log lines
local TYPE_SHORT = { Magic="Magic", Physical="Phys", Melee="Melee", Ranged="Ranged", Spell="Magic" }

-- ============================================================================
--  HELPER FUNCTIONS
-- ============================================================================

local function GetTimestamp()
    return cachedTimestamp
end

local function RefreshTimestamp(nowMsec)
    frameNow = nowMsec
    if not TIME_INITIALIZED then cachedTimestamp = "[..:..:..] "; return end
    local elapsedSec = (nowMsec - BASE_APP_MSEC) / 1000
    local totalSec = (BASE_SECONDS_OF_DAY + elapsedSec + (CONFIG.TIME_OFFSET * 3600)) % 86400
    if totalSec < 0 then totalSec = totalSec + 86400 end
    local h = math.floor(totalSec / 3600)
    local m = math.floor((totalSec % 3600) / 60)
    local s = math.floor(totalSec % 60)
    cachedTimestamp = string.format("[%02d:%02d:%02d] ", h, m, s)
end

local function GetSafeColor(colorName)
    if colorName and PALETTE[colorName] then return PALETTE[colorName] end
    return PALETTE["White"] 
end

local function CreateBackdrop(parent, color, layer)
    if not color or type(color) ~= "table" then color = {0, 0, 0, 1} end
    local bg = parent:CreateColorDrawable(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1, layer or "background")
    bg:AddAnchor("TOPLEFT", parent, 0, 0)
    bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
    return bg
end

local function Truncate(str, limit)
    if #str > limit then return string.sub(str, 1, limit) .. ".." end
    return str
end

local function MakeDraggable(dragHandle, parentWindow, onDragStop)
    dragHandle:EnableDrag(true)
    dragHandle:SetHandler("OnDragStart", function(self)
        if api.Input:IsShiftKeyDown() then
            parentWindow:StartMoving()
            api.Cursor:ClearCursor()
            if CURSOR_PATH and CURSOR_PATH.MOVE then
                api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
            end
        end
    end)
    dragHandle:SetHandler("OnDragStop", function(self)
        parentWindow:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        if onDragStop then onDragStop() end
    end)
end

local function GetNextColorName(currentName)
    local idx = 1
    for i, name in ipairs(PALETTE_KEYS) do
        if name == currentName then idx = i break end
    end
    idx = idx + 1
    if idx > #PALETTE_KEYS then idx = 1 end
    return PALETTE_KEYS[idx]
end

-- Fills target-side snapshot fields from a UnitInfo table + ModifierInfo table
local function ApplyTargetSnapshot(snap, tInfo, tModInfo)
    tInfo    = tInfo    or {}
    tModInfo = tModInfo or {}
    snap.targetDefense   = tonumber(tInfo.armor                       or 0)
    snap.targetResist    = tonumber(tInfo.magic_resist                or 0)
    snap.targetArmorPct  = tonumber(tInfo.armor_percentage            or 0)
    snap.targetResistPct = tonumber(tInfo.magic_resist_percentage     or 0)
    snap.targetDodge     = tonumber(tInfo.dodge_rate                  or 0)
    snap.targetBlock     = tonumber(tInfo.block_rate                  or 0)
    snap.targetParry     = tonumber(tInfo.melee_parry_rate            or 0)
    snap.targetToughness = tonumber(tInfo.battle_resist               or 0)
    snap.targetIncomingMeleeMul  = tonumber(tInfo.incoming_melee_damage_mul   or 0)
    snap.targetIncomingSpellMul  = tonumber(tInfo.incoming_spell_damage_mul   or 0)
    snap.targetIncomingRangedMul = tonumber(tInfo.incoming_ranged_damage_mul  or 0)
    snap.targetIncomingMeleeVal  = tonumber(tInfo.incoming_melee_damage_val   or 0)
    snap.targetIncomingSpellVal  = tonumber(tInfo.incoming_spell_damage_val   or 0)
    snap.targetIncomingRangedVal = tonumber(tInfo.incoming_ranged_damage_val  or 0)
end

-- Attempts to get target UnitInfo: tries GetUnitInfoById first (works off-target),
-- falls back to UnitInfo("target") if the ID-based call returns no useful data.
local function GetTargetInfo(unitID)
    local numID = tonumber(unitID)
    local ok, tInfo = pcall(function() return api.Unit:GetUnitInfoById(numID) end)
    if ok and tInfo and (tonumber(tInfo.armor_percentage or 0) > 0 or tonumber(tInfo.magic_resist_percentage or 0) > 0) then
        return tInfo
    end
    local ok2, tInfo2 = pcall(function() return api.Unit:UnitInfo("target") end)
    if ok2 then return tInfo2 end
    return {}
end

local function GetOrCreateOutgoing(unitID, targetName, now)
    local existing = fightData.outgoing[unitID]
    if existing then
        -- If snapshot was empty on creation (target not selected at fight start), retry now
        if not existing.snapshotComplete then
            local tInfo = GetTargetInfo(unitID)
            tInfo = tInfo or {}
            if tonumber(tInfo.armor_percentage or 0) > 0 or tonumber(tInfo.magic_resist_percentage or 0) > 0 then
                local okM, tModInfo = pcall(function() return api.Unit:UnitModifierInfo("target") end)
                if not okM then tModInfo = {} end
                ApplyTargetSnapshot(existing.statSnapshot, tInfo, tModInfo)
                if not existing.targetGS then existing.targetGS = tonumber(tInfo.gear_score) or nil end
                if not existing.targetClass then
                    local okC, cls = pcall(function() return api.Ability:GetUnitClassName("target") end)
                    if not okC or not cls or cls == "" or cls:lower() == "pending" then
                        okC, cls = pcall(function() return api.Unit:UnitClass("target") end)
                    end
                    if okC and cls and cls ~= "" and cls:lower() ~= "pending" then existing.targetClass = tostring(cls) end
                end
                if not existing.targetMaxHp then
                    local okH, mhp = pcall(function() return api.Unit:UnitMaxHealth("target") end)
                    if okH and mhp then existing.targetMaxHp = tonumber(mhp) or nil end
                end
                existing.snapshotComplete = true
            end
        end
        return existing
    end

    local ok1, playerInfo = pcall(function() return api.Unit:UnitInfo("player") end)
    if not ok1 then playerInfo = {} end
    playerInfo = playerInfo or {}

    local targetInfo = GetTargetInfo(unitID)
    targetInfo = targetInfo or {}
    local ok2b, targetModInfo = pcall(function() return api.Unit:UnitModifierInfo("target") end)
    if not ok2b then targetModInfo = {} end
    targetModInfo = targetModInfo or {}

    local ok3, tHp    = pcall(function() return api.Unit:UnitHealth("target") end)
    if not ok3 then tHp = nil end
    local ok4, tMaxHp = pcall(function() return api.Unit:UnitMaxHealth("target") end)
    if not ok4 then tMaxHp = nil end
    local ok5, tClass = pcall(function() return api.Ability:GetUnitClassName("target") end)
    if not ok5 or not tClass or tClass == "" or tClass:lower() == "pending" then
        ok5, tClass = pcall(function() return api.Unit:UnitClass("target") end)
        if not ok5 then tClass = nil end
    end
    if tClass and tClass:lower() == "pending" then tClass = nil end

    -- patch 243+: zone group and targeting info
    local okZ, zoneGroup = pcall(function() return api.Unit:GetCurrentZoneGroup() end)
    if not okZ then zoneGroup = nil end
    local okTU, targetIsTargetingPlayer = pcall(function()
        return api.Unit:TargetUnit("target") == "player"
    end)
    if not okTU then targetIsTargetingPlayer = false end

    local snap = {
        playerPhysPen        = tonumber(playerInfo.ignore_armor      or 0),
        playerMagicPen       = tonumber(playerInfo.magic_penetration  or 0),
        playerMeleeHit       = tonumber(playerInfo.melee_success_rate or 100),
        playerSpellHit       = tonumber(playerInfo.spell_success_rate or 100),
        playerMeleeCritRate  = tonumber(playerInfo.melee_critical_rate  or 0),
        playerSpellCritRate  = tonumber(playerInfo.spell_critical_rate  or 0),
        playerMeleeCritBonus = tonumber(playerInfo.melee_critical_bonus or 50),
        playerSpellCritBonus = tonumber(playerInfo.spell_critical_bonus or 50),
        playerBackstabMelee  = tonumber(playerInfo.backattack_melee_damage_mul  or 0),
        playerBackstabRanged = tonumber(playerInfo.backattack_ranged_damage_mul or 0),
        playerBackstabSpell  = tonumber(playerInfo.backattack_spell_damage_mul  or 0),
        zoneGroup            = zoneGroup,                -- zone group at fight start (patch 243+)
        targetIsTargetingPlayer = targetIsTargetingPlayer, -- was target targeting player? (patch 243+)
        -- target fields filled by helper below
    }
    ApplyTargetSnapshot(snap, targetInfo, targetModInfo)

    if CONFIG.DEBUG_UNITINFO then
        -- Probe every numeric UnitInfo field through GetSkillsetNameById to find
        -- which fields hold the three skillset IDs (check both player and target).
        local function probeSkillsets(info)
            local found = {}
            for k, v in pairs(info or {}) do
                local n = tonumber(v)
                if n and n > 0 and n < 100 then
                    local ok, name = pcall(function() return api.Ability:GetSkillsetNameById(n) end)
                    if ok and name and name ~= "" then
                        found[k] = tostring(n) .. " -> " .. tostring(name)
                    end
                end
            end
            return found
        end
        local lines = {}
        local function dump(label, tbl)
            table.insert(lines, "=== " .. label .. " ===")
            for k, v in pairs(tbl or {}) do
                table.insert(lines, "  " .. tostring(k) .. " = " .. tostring(v))
            end
        end
        dump("player_UnitInfo",          playerInfo)
        dump("player_skillset_probe",    probeSkillsets(playerInfo))
        dump("target_UnitInfo",          targetInfo)
        dump("target_skillset_probe",    probeSkillsets(targetInfo))
        dump("target_UnitModInfo",       targetModInfo)
        pcall(function() api.File:Write("Combat_Log_pro/unitinfo_dump.txt", table.concat(lines, "\n")) end)
        api.Log:Info("[CLP] DEBUG_UNITINFO dump written to Combat_Log_pro/unitinfo_dump.txt")
        CONFIG.DEBUG_UNITINFO = false  -- dump once per reload
    end

    local hasData = (snap.targetArmorPct > 0 or snap.targetResistPct > 0)

    fightData.outgoing[unitID] = {
        name             = targetName,
        targetClass      = (tClass and tClass ~= "") and tostring(tClass) or nil,
        targetGS         = tonumber(targetInfo.gear_score) or nil,
        targetMaxHp      = tonumber(tMaxHp) or nil,
        skills           = {},
        skillTypes       = {},  -- skill -> "Melee"/"Ranged"/"Magic"
        hitCounts        = {},
        defends          = {},
        misses           = {},
        physDmg          = 0,
        magicDmg         = 0,
        rangedDmg        = 0,
        physAbsorbed     = 0,
        magicAbsorbed    = 0,
        rangedAbsorbed   = 0,
        physHits         = 0,
        magicHits        = 0,
        rangedHits       = 0,
        -- Raw pre-mitigation damage from COMBAT_MSG arg[11] (exact, no estimation)
        rawPhysDmg       = 0,
        rawMagicDmg      = 0,
        rawRangedDmg     = 0,
        startTime        = now,
        lastUpdate       = now,
        snapshotComplete = hasData,
        statSnapshot     = snap,
        -- Observed skill trees (inferred from skills used during combat)
        observedTrees    = {},  -- tree name -> true
        -- Buff effect tracking
        appliedDebuffs   = {},  -- skill -> true, for all 0-damage actions on this target
        invincibleSkills = {},  -- skill -> count
        spellShieldDmg   = 0,  -- magic dmg dealt into spell shield
        spellShieldHealed = 0, -- HP healed to target via spell shield
        runeConvertDmg   = 0,  -- dmg that healed target via rune
        runeConvertPct   = 0,  -- rune % (for summary display)
        runeConvertName  = nil,
        dmgShields       = {},    -- { name -> { max, rawDmg } }
        backstabHits     = 0,
        backstabDmg      = 0,
        backstabSkillHits = {},  -- { skillName -> count } for skills with their own BS bonus
        comboHits        = 0,
        comboBonusDmg    = 0,
        comboSkills      = {},   -- { skillName -> { hits, bonusDmg } }
    }
    return fightData.outgoing[unitID]
end

-- ============================================================================
--  UI UPDATE & RENDER
-- ============================================================================

local function RebuildLiveLabels()
    if not wLive or not liveBodyWidget then return end
    -- Layout pass: only runs when dimensions changed (resize buttons or first call).
    if liveLayoutDirty then
        liveLayoutDirty = false
        wLive:SetExtent(CONFIG.LIVE_WIDTH, CONFIG.LIVE_HEIGHT)
        local bodyHeight = CONFIG.LIVE_HEIGHT - 30
        CONFIG.VISIBLE_ROWS_LIVE = math.floor((bodyHeight - 20) / CONFIG.LINE_HEIGHT)
        for i = 1, 50 do
            if i <= CONFIG.VISIBLE_ROWS_LIVE then
                local lbl = liveLabels[i]
                if not lbl then
                    lbl = liveBodyWidget:CreateChildWidget("label", "LiveLbl"..i, 0, true)
                    lbl:AddAnchor("TOPLEFT", liveBodyWidget, 10, 10 + ((i-1) * CONFIG.LINE_HEIGHT))
                    lbl:SetLimitWidth(true)
                    if lbl.style then
                        lbl.style:SetAlign(ALIGN.LEFT)
                        lbl.style:SetShadow(true)
                        lbl.style:SetEllipsis(true)
                    end
                    liveLabels[i] = lbl
                end
                lbl:SetExtent(CONFIG.LIVE_WIDTH - 20, CONFIG.LINE_HEIGHT)
                lbl:Show(true)
            else
                if liveLabels[i] then liveLabels[i]:Show(false) end
            end
        end
    end
    -- Text pass: always runs, updates visible label text and color.
    local startIdx = #liveBuffer - CONFIG.VISIBLE_ROWS_LIVE + 1
    if startIdx < 1 then startIdx = 1 end
    local lblIdx = 1
    for i = startIdx, #liveBuffer do
        local e = liveBuffer[i]
        if liveLabels[lblIdx] and liveLabels[lblIdx]:IsVisible() then
            local timeStr = ""
            if CONFIG.SHOW_TIMESTAMP and e.time then
                timeStr = e.time
            end
            liveLabels[lblIdx]:SetText(timeStr .. e.text)
            if liveLabels[lblIdx].style then liveLabels[lblIdx].style:SetColor(e.r, e.g, e.b, 1) end
        end
        lblIdx = lblIdx + 1
    end
end

local function UpdateHistoryDisplay()
    if not wHistory or not wHistory:IsVisible() then return end
    local totalLines = #displayBuffer
    local maxOffset = totalLines - CONFIG.VISIBLE_ROWS_HIST
    if maxOffset < 0 then maxOffset = 0 end
    if logScrollOffset > maxOffset then logScrollOffset = maxOffset end
    if logScrollOffset < 0 then logScrollOffset = 0 end
    for i = 1, CONFIG.VISIBLE_ROWS_HIST do
        local dataIndex = logScrollOffset + i
        local entry = displayBuffer[dataIndex]
        local lbl = historyLabels[i]
        if entry then
            local timeStr = ""
            if CONFIG.SHOW_TIMESTAMP and entry.time then
                timeStr = entry.time
            end
            lbl:SetText(timeStr .. entry.text)
            if lbl.style then lbl.style:SetColor(entry.r, entry.g, entry.b, 1) end
        else
            lbl:SetText("")
        end
    end
end

-- ============================================================================
--  LOGGING ENGINE
-- ============================================================================

local liveRebuildDirty = false
local histDisplayDirty = false
local lastLiveRebuildTime = 0

local function TrimBuffer(buf, maxSize)
    -- Batch trim: only fires when 50% over limit, so a 1000-entry buffer trims once
    -- per 500 inserts instead of every 200. Keeps the newest maxSize entries.
    if #buf > maxSize + math.floor(maxSize * 0.5) then
        local start = #buf - maxSize + 1
        local trimmed = {}
        for i = start, #buf do trimmed[#trimmed + 1] = buf[i] end
        return trimmed
    end
    return buf
end

local function LogEntry(text, r, g, b, meta)
    local entry = { text = text, r = r, g = g, b = b, time = GetTimestamp() }
    if meta then for k, v in pairs(meta) do entry[k] = v end end
    liveBuffer[#liveBuffer + 1] = entry
    liveBuffer = TrimBuffer(liveBuffer, 50)
    masterBuffer[#masterBuffer + 1] = entry
    masterBuffer = TrimBuffer(masterBuffer, 1000)
    if viewingMode == "LIVE" then
        displayBuffer[#displayBuffer + 1] = entry
        displayBuffer = TrimBuffer(displayBuffer, 1000)
        local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
        if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
        histDisplayDirty = true
    end
    -- Throttle live label rebuild: mark dirty, rebuild at most every 50ms
    liveRebuildDirty = true
    local nowMs = api.Time:GetUiMsec()
    if nowMs - lastLiveRebuildTime >= 50 then
        lastLiveRebuildTime = nowMs
        liveRebuildDirty = false
        RebuildLiveLabels()
    end
end

-- Split a long line into wrapped lines at word boundaries.
-- Wrap width is computed dynamically from the live label width (~7.2px per char avg font).
local function WrapLines(text, indent)
    local wrapWidth = math.max(40, math.floor((CONFIG.LIVE_WIDTH - 30) / 7.2))
    if #text <= wrapWidth then return { text } end
    indent = indent or "  "
    local lines = {}
    local remaining = text
    while #remaining > wrapWidth do
        local cut = wrapWidth
        -- Walk back to find a space to break on
        while cut > 1 and remaining:sub(cut, cut) ~= " " do cut = cut - 1 end
        if cut <= 1 then cut = wrapWidth end  -- no space found, hard cut
        table.insert(lines, remaining:sub(1, cut))
        remaining = indent .. remaining:sub(cut + 1)
    end
    if #remaining > 0 then table.insert(lines, remaining) end
    return lines
end

local function RecordLogForTarget(unitID, unitName, text, r, g, b, meta)
    if not text then return end
    timeSinceLastAction = 0
    local ts = GetTimestamp()
    local isSummary = meta and meta.logType == "summary"
    local histEntry = { text = text, r = r, g = g, b = b, time = ts }
    if meta then for k, v in pairs(meta) do histEntry[k] = v end end
    -- Summary lines go to session logs only — not the main live log or history stream
    if not isSummary then
        masterBuffer[#masterBuffer + 1] = histEntry
        masterBuffer = TrimBuffer(masterBuffer, 1000)
        if viewingMode == "LIVE" then
            displayBuffer[#displayBuffer + 1] = histEntry
            displayBuffer = TrimBuffer(displayBuffer, 1000)
            local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
            if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
            histDisplayDirty = true
        end
        liveBuffer[#liveBuffer + 1] = { text = text, r = r, g = g, b = b, time = ts }
        liveBuffer = TrimBuffer(liveBuffer, 50)
        liveRebuildDirty = true
        local nowMs = api.Time:GetUiMsec()
        if nowMs - lastLiveRebuildTime >= 50 then
            lastLiveRebuildTime = nowMs
            liveRebuildDirty = false
            RebuildLiveLabels()
        end
    end
    table.insert(currentSessionLogs, histEntry)
    if not sessionByTarget[unitID] then
        sessionByTarget[unitID] = { name = unitName, logs = {} }
    end
    table.insert(sessionByTarget[unitID].logs, histEntry)
end

local function RecordHealLog(key, displayName, text, r, g, b, meta)
    if not text then return end
    local ts = GetTimestamp()
    -- History and session: store original unwrapped text
    local histEntry = { text = text, r = r, g = g, b = b, time = ts }
    if meta then for k, v in pairs(meta) do histEntry[k] = v end end
    masterBuffer[#masterBuffer + 1] = histEntry
    masterBuffer = TrimBuffer(masterBuffer, 1000)
    if viewingMode == "LIVE" then
        displayBuffer[#displayBuffer + 1] = histEntry
        displayBuffer = TrimBuffer(displayBuffer, 1000)
        local maxOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST
        if logScrollOffset >= (maxOffset - 5) or logScrollOffset < 0 then logScrollOffset = maxOffset end
        histDisplayDirty = true
    end
    if not healSessionByTarget[key] then
        healSessionByTarget[key] = { name = displayName, logs = {} }
    end
    table.insert(healSessionByTarget[key].logs, histEntry)
    -- Live display: single line, SetEllipsis handles any overflow
    liveBuffer[#liveBuffer + 1] = { text = text, r = r, g = g, b = b, time = ts }
    liveBuffer = TrimBuffer(liveBuffer, 50)
    liveRebuildDirty = true
    local nowMs = api.Time:GetUiMsec()
    if nowMs - lastLiveRebuildTime >= 50 then
        lastLiveRebuildTime = nowMs
        liveRebuildDirty = false
        RebuildLiveLabels()
    end
end

-- ============================================================================
--  SCROLLING & SESSION LIST
-- ============================================================================

local function ScrollLogUp() logScrollOffset = logScrollOffset - 5; if logScrollOffset < 0 then logScrollOffset = 0 end; UpdateHistoryDisplay() end
local function ScrollLogDown() 
    local totalLines = #displayBuffer; local maxOffset = totalLines - CONFIG.VISIBLE_ROWS_HIST; if maxOffset < 0 then maxOffset = 0 end
    logScrollOffset = logScrollOffset + 5; if logScrollOffset > maxOffset then logScrollOffset = maxOffset end; UpdateHistoryDisplay() 
end
local function UpdateSessionList()
    if lblSessionCount then lblSessionCount:SetText("Saved: " .. #allSessions) end
    if not wHistory:IsVisible() then return end
    local totalSessions = #allSessions
    local maxScroll = totalSessions - CONFIG.SESSIONS_VISIBLE
    if maxScroll < 0 then maxScroll = 0 end
    if sessionScrollOffset > maxScroll then sessionScrollOffset = maxScroll end
    if sessionScrollOffset < 0 then sessionScrollOffset = 0 end
    local startIdx = totalSessions - CONFIG.SESSIONS_VISIBLE - sessionScrollOffset + 1
    if startIdx < 1 then startIdx = 1 end
    local btnIdx = 1
    for i = startIdx, startIdx + CONFIG.SESSIONS_VISIBLE - 1 do
        local session = allSessions[i]
        local btn = sessionButtons[btnIdx]
        if btn then
            if session then
                local prefix, r, g, b
                if session.isHeal then
                    prefix = "[Heal] "
                    r, g, b = 0, 1, 0
                elseif session.isIncoming then
                    prefix = "[In] "
                    r, g, b = 1, 0.3, 0.3
                else
                    prefix = "[Out] "
                    r, g, b = 0, 1, 1
                end
                local shortName = Truncate(session.targetName, 14)
                local stat = session.totalDmg or session.totalHeal or 0
                if stat > 0 then shortName = shortName .. " (" .. stat .. ")" end
                btn:SetText(string.format("#%d %s%s", i, prefix, shortName))
                btn:SetTextColor(r, g, b, 1); btn:Show(true); btn:Raise(); btn.sessionIndex = i
            else btn:Show(false) end
        end
        btnIdx = btnIdx + 1
    end
end
local function ScrollSession(delta) if delta > 0 then sessionScrollOffset = sessionScrollOffset + 1 else sessionScrollOffset = sessionScrollOffset - 1 end; UpdateSessionList() end
local function ClearAll()
    liveBuffer = {}; masterBuffer = {}; displayBuffer = {}; allSessions = {}
    currentSessionLogs = {}; sessionByTarget = {}; healSessionByTarget = {}
    fightData = { outgoing = {}, incoming = {} }; healData = { done = {}, received = {} }
    activeDots = {}; activeCCSessions = {}; sessionScrollOffset = 0; logScrollOffset = 0
    for i = 1, #liveLabels do liveLabels[i]:SetText("") end
    UpdateHistoryDisplay(); UpdateSessionList(); LogEntry("--- History Cleared ---", 1, 1, 0)
end

-- ============================================================================
--  COMBAT & SCANNER LOGIC
-- ============================================================================

-- Infer damage type from skill table, cache, or mitigation ratio
-- Returns "Melee", "Ranged", "Magic", "Physical", or "Spell"
local function InferDamageType(upAct, skill, absDmg, absorbed, snap)
    -- 1. Manual override table (highest priority).
    --    Normalize smart-apostrophes (U+2019) to ASCII in case game sends them.
    local lookup = skill:gsub("\xe2\x80\x99", "'")
    if SKILL_DAMAGE_TYPES[lookup] then return SKILL_DAMAGE_TYPES[lookup] end

    -- 2. Auto-learned cache from previous hits
    if skillTypeCache[skill] then return skillTypeCache[skill] end

    -- 3. Auto-attacks: actionType is reliable for these
    if string.find(upAct, "MELEE") then return "Melee" end
    if string.find(upAct, "RANGED") then return "Ranged" end

    -- 4. SPELL_DAMAGE / SPELL_DOT_DAMAGE: compare actual mitigation to pen-adjusted armor% vs resist%.
    --    Guard: only infer if we have real stat data for the target — if both are 0 the
    --    comparison is always a tie and would wrongly return "Physical" for magic skills.
    if snap and absorbed > 0 and absDmg > 0 then
        local armorPct  = (snap.targetArmorPct  or 0) / 100
        local resistPct = (snap.targetResistPct or 0) / 100

        if armorPct > 0 or resistPct > 0 then
            local raw    = absDmg + absorbed
            local mitPct = absorbed / raw
            local tDef   = snap.targetDefense or 0
            local tRes   = snap.targetResist  or 0
            local pPen   = snap.playerPhysPen  or 0
            local mPen   = snap.playerMagicPen or 0

            -- Pen-adjusted armor %
            local penAdjArmor = armorPct
            if tDef > 0 and armorPct > 0 and armorPct < 1 then
                local C = tDef * (1 - armorPct) / armorPct
                if pPen >= tDef then penAdjArmor = 0
                elseif pPen > 0 then
                    local effDef = tDef - pPen
                    penAdjArmor = effDef / (effDef + C)
                end
            end

            -- Pen-adjusted resist %
            local penAdjResist = resistPct
            if tRes > 0 and resistPct > 0 and resistPct < 1 then
                local C = tRes * (1 - resistPct) / resistPct
                if mPen >= tRes then penAdjResist = 0
                elseif mPen > 0 then
                    local effRes = tRes - mPen
                    penAdjResist = effRes / (effRes + C)
                end
            end

            local result = (math.abs(mitPct - penAdjArmor) <= math.abs(mitPct - penAdjResist))
                and "Physical" or "Magic"
            skillTypeCache[skill] = result
            return result
        end
    end

    -- No usable mitigation data — fall back to actionType keyword
    if string.find(upAct, "SPELL") then return "Magic" end
    if string.find(upAct, "MELEE") then return "Melee" end
    return "Physical"
end

-- Return the current stack count of a named buff on the player.
-- Reads from playerBuffStackCache, which is refreshed every scanner tick.
-- Returns 0 if the buff is not active, 1+ for the actual stack count.
local function GetPlayerBuffStacks(buffName)
    return playerBuffStackCache[buffName] or 0
end

local function FinishFight()
    if not inCombat then return end
    inCombat = false
    -- Flush any buffered event log lines to file
    if CONFIG.DEBUG_LOG_EVENTS and #eventLogLines > 0 then
        local existing = api.File:Read(eventLogFile) or {}
        if type(existing) ~= "table" then existing = {} end
        for _, line in ipairs(eventLogLines) do table.insert(existing, line) end
        pcall(function() api.File:Write(eventLogFile, existing) end)
        eventLogLines = {}
    end
    liveTitleLabel:SetText("Combat Log [Idle]")
    if liveTitleLabel.style then liveTitleLabel.style:SetColor(0.7, 0.7, 0.7, 1) end

    -- Print Outgoing Damage Stats
    for id, data in pairs(fightData.outgoing) do
        -- Filter: skip sessions where only passive procs dealt damage
        local PROC_ONLY_SKILLS = { ["Electric Shock"] = true }
        local skipOutgoing = false
        if CONFIG.FILTER_STATIC_SHOCK then
            local skillCount = 0
            local onlyProcs = true
            for skill, _ in pairs(data.skills or {}) do
                skillCount = skillCount + 1
                if not PROC_ONLY_SKILLS[skill] then onlyProcs = false end
            end
            if skillCount > 0 and onlyProcs then skipOutgoing = true end
        end

        if not skipOutgoing then
        local tName = data.name or "Target"
        local snap = data.statSnapshot or {}
        local targetingStr = snap.targetIsTargetingPlayer and " [↔]" or ""
        RecordLogForTarget(id, tName, "--- OUTGOING: " .. tName .. targetingStr .. " ---", 0, 1, 1, { logType = "summary" })
        local infoParts = {}
        -- Only show class for player targets (GS > 0); mobs always return generic
        -- archetypes ("mage", "warrior") which are meaningless for NPCs.
        if data.targetClass and data.targetGS and data.targetGS > 0 then
            table.insert(infoParts, "Class: " .. data.targetClass)
        end
        if data.targetGS    then table.insert(infoParts, "GS: " .. data.targetGS) end
        if data.targetMaxHp then table.insert(infoParts, "HP: " .. data.targetMaxHp) end
        if #infoParts > 0 then
            RecordLogForTarget(id, tName, "  " .. table.concat(infoParts, " | "), 0.7, 0.7, 0.7, { logType = "summary" })
        end

        local totalDmg = 0
        for skill, dmg in pairs(data.skills or {}) do
            local sType = (data.skillTypes or {})[skill]
            local typeTag = sType and (" [" .. (TYPE_SHORT[sType] or sType) .. "]") or ""
            RecordLogForTarget(id, tName, "  > " .. skill .. ": " .. dmg .. typeTag, 1, 1, 1, { logType = "summary" })
            totalDmg = totalDmg + dmg
        end

        local duration = 1
        if data.startTime and data.lastUpdate then
            duration = (data.lastUpdate - data.startTime) / 1000
            if duration < 1 then duration = 1 end
        end

        -- Raw totals needed by both the totalDmg block and the snap/mitigation block below
        local meleeDmg  = data.physDmg   or 0
        local meleeAbs  = data.physAbsorbed or 0
        local rangedDmg = data.rangedDmg or 0
        local rangedAbs = data.rangedAbsorbed or 0
        local magicDmg  = data.magicDmg  or 0
        local magicAbs  = data.magicAbsorbed or 0
        local rawPhys   = (data.rawPhysDmg   or 0) > 0 and (data.rawPhysDmg   or 0) or meleeDmg  + meleeAbs
        local rawRanged = (data.rawRangedDmg  or 0) > 0 and (data.rawRangedDmg or 0) or rangedDmg + rangedAbs
        local rawMagic  = (data.rawMagicDmg   or 0) > 0 and (data.rawMagicDmg  or 0) or magicDmg  + magicAbs
        local hasExactRaw = (data.rawPhysDmg or 0) + (data.rawRangedDmg or 0) + (data.rawMagicDmg or 0) > 0
        local rawGrandTotal = rawPhys + rawRanged + rawMagic

        if totalDmg > 0 then
            local dps = totalDmg / duration
            local totalAbs = data.totalAbsorbed or 0

            local typeCount = 0
            if meleeDmg  > 0 then typeCount = typeCount + 1 end
            if rangedDmg > 0 then typeCount = typeCount + 1 end
            if magicDmg  > 0 then typeCount = typeCount + 1 end

            -- Only show per-type lines when more than one type was used
            if typeCount > 1 then
                if meleeDmg > 0 then
                    local mitigated = rawPhys - meleeDmg
                    local mitPct = rawPhys > 0 and (mitigated / rawPhys * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Melee: %d dealt | %d mitigated (%.1f%%) | %d raw", meleeDmg, mitigated, mitPct, rawPhys),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
                if rangedDmg > 0 then
                    local mitigated = rawRanged - rangedDmg
                    local mitPct = rawRanged > 0 and (mitigated / rawRanged * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Ranged: %d dealt | %d mitigated (%.1f%%) | %d raw", rangedDmg, mitigated, mitPct, rawRanged),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
                if magicDmg > 0 then
                    local mitigated = rawMagic - magicDmg
                    local mitPct = rawMagic > 0 and (mitigated / rawMagic * 100) or 0
                    RecordLogForTarget(id, tName,
                        string.format("  Magic: %d dealt | %d mitigated (%.1f%%) | %d raw", magicDmg, mitigated, mitPct, rawMagic),
                        0.9, 0.7, 0.5, { logType = "summary" })
                end
            end

            local totalMitigated = rawGrandTotal - totalDmg
            local exactTag = hasExactRaw and "" or " (est)"
            local totalLine
            if rawGrandTotal > totalDmg then
                local mitPct = rawGrandTotal > 0 and (totalMitigated / rawGrandTotal * 100) or 0
                totalLine = string.format("  Total DMG: %d raw%s | %d mitigated (%.1f%%) | %d dealt (%.0f DPS | %.1fs)",
                    rawGrandTotal, exactTag, totalMitigated, mitPct, totalDmg, dps, duration)
            else
                totalLine = string.format("  Total DMG: %d dealt (%.0f DPS | %.1fs)", totalDmg, dps, duration)
            end
            RecordLogForTarget(id, tName, totalLine, 0.7, 0.7, 0.7, { logType = "summary" })
            if sessionByTarget[id] then
                sessionByTarget[id].isOutgoing = true
                sessionByTarget[id].dps = dps
                sessionByTarget[id].totalDmg = totalDmg
                sessionByTarget[id].duration = duration
                sessionByTarget[id].totalAbsorbed = totalAbs
            end
        end

        -- Defend / Miss summary
        local defendList, missList = {}, {}
        local totalMissedDmg = 0
        local skills_dm = data.skills or {}
        local hitCounts_dm = data.hitCounts or {}

        for sk, cnt in pairs(data.defends or {}) do
            local avg = (skills_dm[sk] and hitCounts_dm[sk] and hitCounts_dm[sk] > 0)
                        and (skills_dm[sk] / hitCounts_dm[sk]) or 0
            totalMissedDmg = totalMissedDmg + avg * cnt
            table.insert(defendList, cnt .. "x " .. sk)
        end
        for sk, cnt in pairs(data.misses or {}) do
            local avg = (skills_dm[sk] and hitCounts_dm[sk] and hitCounts_dm[sk] > 0)
                        and (skills_dm[sk] / hitCounts_dm[sk]) or 0
            totalMissedDmg = totalMissedDmg + avg * cnt
            table.insert(missList, cnt .. "x " .. sk)
        end
        if #defendList > 0 then
            RecordLogForTarget(id, tName, "  Defended: " .. table.concat(defendList, ", "), 0.55, 0.55, 0.55, { logType = "summary" })
        end
        if #missList > 0 then
            RecordLogForTarget(id, tName, "  Missed:   " .. table.concat(missList, ", "), 0.55, 0.55, 0.55, { logType = "summary" })
        end
        if totalMissedDmg > 0 then
            local missedDps = duration > 0 and (totalMissedDmg / duration) or 0
            RecordLogForTarget(id, tName,
                string.format("  Lost to defend/miss: %d dmg (%.0f DPS)", math.floor(totalMissedDmg), missedDps),
                0.55, 0.55, 0.55, { logType = "summary" })
        end

        -- Mitigation & pen estimates (per damage type)
        local snap = data.statSnapshot
        if snap then
            local physPct  = (snap.targetArmorPct  or 0) / 100
            local magicPct = (snap.targetResistPct or 0) / 100
            local mitColor = { 0.5, 0.8, 1 }

            -- Toughness (PvP only — applied first, before armor/resist)
            local toughness = snap.targetToughness or 0
            if toughness > 0 and data.targetGS then
                local toughPct = toughness / (toughness + 8000) * 100
                local toughLost = math.floor(rawGrandTotal * toughPct / 100)
                RecordLogForTarget(id, tName,
                    string.format("  Toughness: %d (%.1f%% reduction) | Lost ~%d dmg before armor/resist",
                        toughness, toughPct, toughLost),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
            end
            local penColor = { 0.4, 1, 0.4 }

            -- Use exact raw damage from COMBAT_MSG arg[11] when available,
            -- fall back to dealt+absorbed estimate when arg[11] was zero/missing.
            -- rawPhys/rawRanged/rawMagic/hasExactRaw already defined above in totalDmg block
            local rawMeleeRanged = rawPhys + rawRanged

            local tDef = snap.targetDefense  or 0
            local tRes = snap.targetResist   or 0
            local pPen = snap.playerPhysPen  or 0
            local mPen = snap.playerMagicPen or 0

            -- Toughness applies first (PvP only), so armor/resist only sees the post-toughness portion
            local toughFrac = toughness > 0 and data.targetGS and (toughness / (toughness + 8000)) or 0
            local postToughMeleeRanged = rawMeleeRanged * (1 - toughFrac)
            local postToughMagic       = rawMagic       * (1 - toughFrac)

            -- Pen-adjusted armor %
            local penAdjPhysPct = physPct
            local physPenBonus = 0
            if tDef > 0 and physPct > 0 and physPct < 1 then
                local C = tDef * (1 - physPct) / physPct
                if pPen >= tDef then penAdjPhysPct = 0
                elseif pPen > 0 then
                    local effDef = tDef - pPen
                    penAdjPhysPct = effDef / (effDef + C)
                end
                if postToughMeleeRanged > 0 and penAdjPhysPct < physPct then
                    physPenBonus = postToughMeleeRanged * (physPct - penAdjPhysPct)
                end
            end

            -- Pen-adjusted resist %
            local penAdjMagicPct = magicPct
            local magicPenBonus = 0
            if tRes > 0 and magicPct > 0 and magicPct < 1 then
                local C = tRes * (1 - magicPct) / magicPct
                if mPen >= tRes then penAdjMagicPct = 0
                elseif mPen > 0 then
                    local effRes = tRes - mPen
                    penAdjMagicPct = effRes / (effRes + C)
                end
                if postToughMagic > 0 and penAdjMagicPct < magicPct then
                    magicPenBonus = postToughMagic * (magicPct - penAdjMagicPct)
                end
            end

            -- With exact raw data: mitigated = raw - dealt (no estimation needed for total)
            -- Armor/resist formulas still use snapshot percentages for pen calculations
            local estArmorLost = hasExactRaw
                and math.max(0, postToughMeleeRanged - (data.physDmg or 0) - (data.rangedDmg or 0))
                or  (postToughMeleeRanged > 0 and (postToughMeleeRanged * penAdjPhysPct) or 0)
            local estMagicLost = hasExactRaw
                and math.max(0, postToughMagic - (data.magicDmg or 0))
                or  (postToughMagic > 0 and (postToughMagic * penAdjMagicPct) or 0)

            -- Physical block: defense + pen + avoidance (melee & ranged share armor)
            if rawMeleeRanged > 0 then
                local physLabel = (rawPhys > 0 and rawRanged > 0) and "Phys/Ranged"
                               or (rawRanged > 0)                  and "Ranged"
                               or                                      "Phys"
                local armorMitStr = estArmorLost > 0
                    and string.format(" | Lost %d dmg", math.floor(estArmorLost)) or ""
                RecordLogForTarget(id, tName,
                    string.format("  %s def: %d (%.1f%% base | %.1f%% eff)%s",
                        physLabel, tDef, snap.targetArmorPct or 0, penAdjPhysPct * 100, armorMitStr),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                -- Phys pen + bonus
                local physPenStr = string.format("  %s pen: %d", physLabel, pPen)
                if physPenBonus > 0 then
                    local physPenDps = duration > 0 and (physPenBonus / duration) or 0
                    physPenStr = physPenStr .. string.format(" | Gained +%d dmg (+%.0f DPS)", math.floor(physPenBonus), physPenDps)
                end
                RecordLogForTarget(id, tName, physPenStr, penColor[1], penColor[2], penColor[3], { logType = "summary" })
                -- Avoidance
                local dodge = snap.targetDodge or 0
                local block = snap.targetBlock or 0
                local parry = snap.targetParry or 0
                if dodge > 0 or block > 0 or parry > 0 then
                    RecordLogForTarget(id, tName,
                        string.format("  Dodge: %.1f%% | Block: %.1f%% | Parry: %.1f%%", dodge, block, parry),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                -- Hit rate (melee and ranged share the same stat)
                local meleeHit = snap.playerMeleeHit or 100
                if meleeHit < 99.9 then
                    local hitLabel = (rawPhys > 0 and rawRanged > 0) and "Melee/Ranged"
                                  or (rawRanged > 0)                  and "Ranged"
                                  or                                      "Melee"
                    RecordLogForTarget(id, tName,
                        string.format("  %s hit rate: %.1f%%", hitLabel, meleeHit),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end

            -- Magic block: resist + pen
            if rawMagic > 0 then
                local magicMitStr = estMagicLost > 0
                    and string.format(" | Lost %d dmg", math.floor(estMagicLost)) or ""
                RecordLogForTarget(id, tName,
                    string.format("  Magic res: %d (%.1f%% base | %.1f%% eff)%s",
                        tRes, snap.targetResistPct or 0, penAdjMagicPct * 100, magicMitStr),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                -- Magic pen + bonus
                local magicPenStr = string.format("  Magic pen: %d", mPen)
                if magicPenBonus > 0 then
                    local magicPenDps = duration > 0 and (magicPenBonus / duration) or 0
                    magicPenStr = magicPenStr .. string.format(" | Gained +%d dmg (+%.0f DPS)", math.floor(magicPenBonus), magicPenDps)
                end
                RecordLogForTarget(id, tName, magicPenStr, penColor[1], penColor[2], penColor[3], { logType = "summary" })
                -- Magic hit rate
                local spellHit = snap.playerSpellHit or 100
                if spellHit < 99.9 then
                    RecordLogForTarget(id, tName,
                        string.format("  Magic hit rate: %.1f%%", spellHit),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end

            -- Incoming damage modifiers — zero out types not actually used so unused types are silently skipped
            local imm = rawPhys   > 0 and (snap.targetIncomingMeleeMul  or 0) or 0
            local imr = rawRanged > 0 and (snap.targetIncomingRangedMul or 0) or 0
            local ims = rawMagic  > 0 and (snap.targetIncomingSpellMul  or 0) or 0
            local imv = rawPhys   > 0 and (snap.targetIncomingMeleeVal  or 0) or 0
            local irv = rawRanged > 0 and (snap.targetIncomingRangedVal or 0) or 0
            local isv = rawMagic  > 0 and (snap.targetIncomingSpellVal  or 0) or 0
            local modParts = {}
            if imm ~= 0 then table.insert(modParts, string.format("Melee %+.1f%%", imm)) end
            if imr ~= 0 then table.insert(modParts, string.format("Ranged %+.1f%%", imr)) end
            if ims ~= 0 then table.insert(modParts, string.format("Magic %+.1f%%", ims)) end
            if imv ~= 0 then table.insert(modParts, string.format("Melee %+d/hit", imv)) end
            if irv ~= 0 then table.insert(modParts, string.format("Ranged %+d/hit", irv)) end
            if isv ~= 0 then table.insert(modParts, string.format("Magic %+d/hit", isv)) end
            if #modParts > 0 then
                RecordLogForTarget(id, tName,
                    "  Modifiers: " .. table.concat(modParts, " | "),
                    mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
            end

        end

        if data.ccDurations then
            for ccName, dur in pairs(data.ccDurations) do
                local c = GetSafeColor(CONFIG.COL_CC)
                RecordLogForTarget(id, tName, string.format("  > %s: %.1fs", ccName, dur), c[1], c[2], c[3], { logType = "summary" })
            end
        end

        -- Zeal summary
        local finalZealTime = fightZealTime
        if zealActive and zealStartTime then
            finalZealTime = finalZealTime + (api.Time:GetUiMsec() - zealStartTime)
        end
        local zealDmg  = data.zealDmg  or 0
        local zealHits = data.zealHits or 0
        local zealExtraDmg = data.zealExtraDmg or 0
        if zealExtraDmg > 0 and duration > 0 then
            local zealExtraDps = zealExtraDmg / duration
            local zealColor = { 0.85, 0.4, 1 }
            RecordLogForTarget(id, tName,
                string.format("  [Z] Zeal crits: +%d bonus dmg (+%.0f DPS)",
                    zealExtraDmg, zealExtraDps),
                zealColor[1], zealColor[2], zealColor[3], { logType = "summary" })
        end

        -- Combo summary
        local comboHits     = data.comboHits or 0
        local comboBonusDmg = data.comboBonusDmg or 0
        if comboHits > 0 then
            local comboDps = duration > 0 and (comboBonusDmg / duration) or 0
            local comboSkills = data.comboSkills or {}
            local skillList = {}
            for sName, info in pairs(comboSkills) do
                skillList[#skillList+1] = { name=sName, info=info }
            end
            table.sort(skillList, function(a, b) return a.info.bonusDmg > b.info.bonusDmg end)
            local numSkills = #skillList
            local header = numSkills == 1
                and "  Skill Comboed:"
                or  string.format("  Skills Comboed x%d:", numSkills)
            RecordLogForTarget(id, tName,
                string.format("%s ~%d bonus dmg (%.0f DPS)",
                    header, math.floor(comboBonusDmg), comboDps),
                1, 0.8, 0.2, { logType = "summary" })
            for _, entry in ipairs(skillList) do
                local info = entry.info
                local skillDps = duration > 0 and (info.bonusDmg / duration) or 0
                local condTag = info.cond and (" [" .. info.cond .. (info.pct and (" +" .. info.pct .. "%") or "") .. "]") or ""
                local hitStr = info.hits > 1 and (" x" .. info.hits) or ""
                local bonusStr = info.bonusDmg > 0
                    and string.format(" | ~%d bonus (+%d DPS)", math.floor(info.bonusDmg), math.floor(skillDps))
                    or ""
                RecordLogForTarget(id, tName,
                    string.format("    %s%s%s%s",
                        info.skillName, condTag, hitStr, bonusStr),
                    1, 0.8, 0.2, { logType = "summary" })
            end
        end

        -- Backstab summary
        local snap = data.statSnapshot
        local bsMelee  = snap and ((snap.playerBackstabMelee  or 0) / 10) or 0
        local bsRanged = snap and ((snap.playerBackstabRanged or 0) / 10) or 0
        local bsSpell  = snap and ((snap.playerBackstabSpell  or 0) / 10) or 0
        local bsHits = data.backstabHits or 0
        if bsHits > 0 then
            local bsDmg = data.backstabDmg or 0
            local bsDps = duration > 0 and (bsDmg / duration) or 0
            local totalHits = 0
            for _, cnt in pairs(data.hitCounts or {}) do totalHits = totalHits + cnt end
            local bsPct = totalHits > 0 and (bsHits / totalHits * 100) or 0
            RecordLogForTarget(id, tName,
                string.format("  Backstab: %d hits (%.0f%%) | %d dmg (%.0f DPS)",
                    bsHits, bsPct, math.floor(bsDmg), bsDps),
                0.8, 0.5, 1, { logType = "summary" })
        end
        if bsMelee > 0 or bsRanged > 0 or bsSpell > 0 then
            local parts = {}
            if bsMelee  > 0 then parts[#parts+1] = string.format("Melee +%.1f%%",  bsMelee)  end
            if bsRanged > 0 then parts[#parts+1] = string.format("Ranged +%.1f%%", bsRanged) end
            if bsSpell  > 0 then parts[#parts+1] = string.format("Spell +%.1f%%",  bsSpell)  end
            RecordLogForTarget(id, tName,
                "  Backstab passive: " .. table.concat(parts, " | "),
                0.8, 0.5, 1, { logType = "summary" })
        end
        local bsSkillHits = data.backstabSkillHits
        if bsSkillHits then
            local parts = {}
            for sName, cnt in pairs(bsSkillHits) do
                local info = SKILL_BACKSTAB_BONUSES[sName]
                local label = info and info.formula or "?"
                if info and info.stealth then
                    label = label .. string.format(" +%d%% stealth", info.stealth)
                end
                parts[#parts+1] = string.format("%s x%d (%s)", sName, cnt, label)
            end
            if #parts > 0 then
                RecordLogForTarget(id, tName,
                    "  Backstab skill bonus: " .. table.concat(parts, ", "),
                    0.8, 0.5, 1, { logType = "summary" })
            end
        end

        -- Invincibility summary
        local invSkills = data.invincibleSkills or {}
        local invList = {}
        for sk, cnt in pairs(invSkills) do
            table.insert(invList, cnt .. "x " .. sk)
        end
        if #invList > 0 then
            RecordLogForTarget(id, tName,
                "  [Invincible] Eaten: " .. table.concat(invList, ", "),
                0.6, 0.2, 0.2, { logType = "summary" })
        end

        -- Spell Shield summary
        local ssDmg = data.spellShieldDmg or 0
        local ssHealed = data.spellShieldHealed or 0
        if ssHealed > 0 then
            RecordLogForTarget(id, tName,
                string.format("  [Spell Shield] %d magic dmg healed target for %d HP", ssDmg, ssHealed),
                1, 0.3, 0.3, { logType = "summary" })
        end

        -- Rune conversion summary
        local runeHealed = data.runeConvertDmg or 0
        if runeHealed > 0 then
            local runeName = data.runeConvertName or "Rune"
            local runePct = data.runeConvertPct or 0
            RecordLogForTarget(id, tName,
                string.format("  [%s] %.1f%% conversion healed target for %d HP", runeName, runePct, runeHealed),
                1, 0.5, 0.3, { logType = "summary" })
        end

        -- Damage shield summary
        for shName, shData in pairs(data.dmgShields or {}) do
            local shStr
            if shData.max > 0 then
                shStr = string.format("  [%s] Absorbed up to %d | %d raw dmg hit while active", shName, shData.max, shData.rawDmg)
            else
                shStr = string.format("  [%s] Active | %d raw dmg hit while active", shName, shData.rawDmg)
            end
            RecordLogForTarget(id, tName, shStr, 0.5, 0.8, 1, { logType = "summary" })
        end

        end -- skipOutgoing
    end

    -- Reset Zeal state for next fight
    zealActive    = false
    zealStartTime = nil
    fightZealTime = 0

    -- Print Incoming Damage Stats (no heals mixed in)
    for name, data in pairs(fightData.incoming) do
        RecordLogForTarget(name, name, "--- INCOMING: " .. name .. " ---", 1, 0, 0, { logType = "summary" })

        local totalDmg = 0
        for skill, dmg in pairs(data.skills or {}) do
            RecordLogForTarget(name, name, "  < " .. skill .. ": " .. dmg, 1, 0.5, 0.5, { logType = "summary" })
            totalDmg = totalDmg + dmg
        end
        if totalDmg > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local totalAbs = data.totalAbsorbed or 0
            local totalLine
            if totalAbs > 0 then
                local rawTotal = totalDmg + totalAbs
                local absPct = rawTotal > 0 and (totalAbs / rawTotal * 100) or 0
                totalLine = string.format("  Total DMG: %d raw | %d absorbed (%.1f%%) | %d taken (%.1fs)",
                    rawTotal, totalAbs, absPct, totalDmg, duration)
            else
                totalLine = string.format("  Total DMG: %d taken (%.1fs)", totalDmg, duration)
            end
            RecordLogForTarget(name, name, totalLine, 1, 0.3, 0.3, { logType = "summary" })
            if sessionByTarget[name] then
                sessionByTarget[name].totalDmg = totalDmg
                sessionByTarget[name].duration = duration
                sessionByTarget[name].totalAbsorbed = totalAbs
            end

            local defSnap = data.defSnap
            if defSnap then
                local rawPhys        = (data.physDmg   or 0) + (data.physAbsorbed   or 0)
                local rawRanged      = (data.rangedDmg  or 0) + (data.rangedAbsorbed or 0)
                local rawMagic       = (data.magicDmg  or 0) + (data.magicAbsorbed  or 0)
                local rawMeleeRanged = rawPhys + rawRanged
                local mitColor       = { 0.5, 0.8, 1 }

                if rawMeleeRanged > 0 then
                    RecordLogForTarget(name, name,
                        string.format("  Your armor: %d (%.1f%% base)", defSnap.armor, defSnap.armorPct),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                if rawMagic > 0 then
                    RecordLogForTarget(name, name,
                        string.format("  Your magic res: %d (%.1f%% base)", defSnap.resist, defSnap.resistPct),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
                if defSnap.toughness > 0 then
                    RecordLogForTarget(name, name,
                        string.format("  Your Toughness: %d", defSnap.toughness),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end

                if rawMeleeRanged > 0 then
                    local dodge = defSnap.dodge or 0
                    local block = defSnap.block or 0
                    local parry = defSnap.parry or 0
                    if dodge > 0 or block > 0 or parry > 0 then
                        RecordLogForTarget(name, name,
                            string.format("  Your dodge: %.1f%% | Block: %.1f%% | Parry: %.1f%%", dodge, block, parry),
                            mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                    end
                end

                -- Incoming damage mods (condensed)
                local imm = rawPhys   > 0 and (defSnap.incomingMeleeMul  or 0) or 0
                local imr = rawRanged > 0 and (defSnap.incomingRangedMul or 0) or 0
                local ims = rawMagic  > 0 and (defSnap.incomingSpellMul  or 0) or 0
                local imv = rawPhys   > 0 and (defSnap.incomingMeleeVal  or 0) or 0
                local irv = rawRanged > 0 and (defSnap.incomingRangedVal or 0) or 0
                local isv = rawMagic  > 0 and (defSnap.incomingSpellVal  or 0) or 0
                local modParts = {}
                if imm ~= 0 then table.insert(modParts, string.format("Melee %+.1f%%", imm)) end
                if imr ~= 0 then table.insert(modParts, string.format("Ranged %+.1f%%", imr)) end
                if ims ~= 0 then table.insert(modParts, string.format("Magic %+.1f%%", ims)) end
                if imv ~= 0 then table.insert(modParts, string.format("Melee %+d/hit", imv)) end
                if irv ~= 0 then table.insert(modParts, string.format("Ranged %+d/hit", irv)) end
                if isv ~= 0 then table.insert(modParts, string.format("Magic %+d/hit", isv)) end
                if #modParts > 0 then
                    RecordLogForTarget(name, name,
                        "  Modifiers: " .. table.concat(modParts, " | "),
                        mitColor[1], mitColor[2], mitColor[3], { logType = "summary" })
                end
            end
        end

        if sessionByTarget[name] then sessionByTarget[name].isIncoming = true end
    end

    -- Healing Done Summary (separate green sessions)
    local c = GetSafeColor(CONFIG.COL_HEAL)
    for targetName, data in pairs(healData.done) do
        local key = "done_" .. targetName
        RecordHealLog(key, targetName, "--- HEALED: " .. targetName .. " ---", c[1], c[2], c[3], { logType = "summary" })
        local totalHeal = 0
        for skill, amount in pairs(data.skills) do
            RecordHealLog(key, targetName, "  + " .. skill .. ": " .. amount, c[1], c[2], c[3], { logType = "summary" })
            totalHeal = totalHeal + amount
        end
        if totalHeal > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local hps = totalHeal / duration
            if healSessionByTarget[key] then
                healSessionByTarget[key].totalHeal = totalHeal
                healSessionByTarget[key].hps = hps
                healSessionByTarget[key].duration = duration
            end
            RecordHealLog(key, targetName, string.format("  Total: %d (%.0f HPS | %.1fs)", totalHeal, hps, duration), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
            local hSnap = data.healSnap
            if hSnap then
                local statParts = {}
                if hSnap.healCritRate > 0 then
                    table.insert(statParts, string.format("Crit %.1f%% (+%.0f%%)", hSnap.healCritRate, hSnap.healCritBonus))
                end
                if hSnap.healMul ~= 0 then
                    table.insert(statParts, string.format("Heal power %+.1f%%", hSnap.healMul))
                end
                if hSnap.castingTime < 99 then
                    table.insert(statParts, string.format("Cast time %.0f%% of base", hSnap.castingTime))
                end
                if #statParts > 0 then
                    RecordHealLog(key, targetName, "  [Heal Stats] " .. table.concat(statParts, " | "), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
                end
            end
        end
    end

    -- Healing Received Summary (separate green sessions)
    for sourceName, data in pairs(healData.received) do
        local key = "recv_" .. sourceName
        RecordHealLog(key, sourceName, "--- HEALED BY: " .. sourceName .. " ---", c[1], c[2], c[3], { logType = "summary" })
        local totalHeal = 0
        for skill, amount in pairs(data.skills) do
            RecordHealLog(key, sourceName, "  + " .. skill .. ": " .. amount, c[1], c[2], c[3], { logType = "summary" })
            totalHeal = totalHeal + amount
        end
        if totalHeal > 0 then
            local duration = 1
            if data.startTime and data.lastUpdate then
                duration = (data.lastUpdate - data.startTime) / 1000
                if duration < 1 then duration = 1 end
            end
            local hps = totalHeal / duration
            if healSessionByTarget[key] then
                healSessionByTarget[key].totalHeal = totalHeal
                healSessionByTarget[key].hps = hps
                healSessionByTarget[key].duration = duration
            end
            RecordHealLog(key, sourceName, string.format("  Total: %d (%.0f HPS | %.1fs)", totalHeal, hps, duration), c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
            local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
            if okP and pInfo then
                local incomingHealMul = tonumber(pInfo.incoming_heal_mul or 0)
                if incomingHealMul ~= 0 then
                    RecordHealLog(key, sourceName,
                        string.format("  [Heal received mod] %+.1f%%", incomingHealMul),
                        c[1]*0.7, c[2]*0.7, c[3]*0.7, { logType = "summary" })
                end
            end
        end
    end

    LogEntry("---------------------------", 0.5, 0.5, 0.5)

    -- Save damage sessions
    local timeStr = GetTimestamp()
    local savedCount = 0
    for id, data in pairs(sessionByTarget) do
        -- Filter: skip proc-only sessions from history
        local PROC_ONLY_SKILLS = { ["Electric Shock"] = true }
        local skipSave = false
        if CONFIG.FILTER_STATIC_SHOCK and data.logs and #data.logs > 0 then
            local allProcs = true
            for _, entry in ipairs(data.logs) do
                if entry.skill and not PROC_ONLY_SKILLS[entry.skill] then allProcs = false; break end
            end
            if allProcs then skipSave = true end
        end
        if not skipSave and #data.logs > 0 then
            table.insert(allSessions, {
                time = timeStr, targetName = data.name, logs = data.logs,
                isIncoming = data.isIncoming, isOutgoing = data.isOutgoing,
                dps = data.dps or 0, totalDmg = data.totalDmg or 0,
                duration = data.duration or 0, totalAbsorbed = data.totalAbsorbed or 0
            })
            savedCount = savedCount + 1
        end
    end

    -- Save heal sessions
    for id, data in pairs(healSessionByTarget) do
        if #data.logs > 0 then
            local isDone = string.sub(id, 1, 5) == "done_"
            local isRecv = string.sub(id, 1, 5) == "recv_"
            table.insert(allSessions, {
                time = timeStr, targetName = data.name, logs = data.logs,
                isHeal = true, isHealDone = isDone, isHealReceived = isRecv,
                totalHeal = data.totalHeal or 0, hps = data.hps or 0, duration = data.duration or 0
            })
            savedCount = savedCount + 1
        end
    end

    -- Cap session history to prevent unbounded memory growth (batch copy, avoids O(n) shifts)
    if #allSessions > 100 then
        local trimmed = {}
        local start = #allSessions - 100 + 1
        for i = start, #allSessions do trimmed[#trimmed + 1] = allSessions[i] end
        allSessions = trimmed
    end

    if savedCount > 0 then sessionScrollOffset = 0; UpdateSessionList() end
    currentSessionLogs = {}; sessionByTarget = {}; healSessionByTarget = {}
    fightData = { outgoing = {}, incoming = {} }; healData = { done = {}, received = {} }
    activeDots = {}; activeCCSessions = {}
    -- Prune activeDebuffsCache: keep only current target and player, discard old unit entries
    local keepPlayer = api.Unit:GetUnitId("player")
    local keepTarget = api.Unit:GetUnitId("target")
    for uid in pairs(activeDebuffsCache) do
        if uid ~= keepPlayer and uid ~= keepTarget then
            activeDebuffsCache[uid] = nil
        end
    end
end

local function ScanUnitDebuffs(unitTag)
    if not CONFIG.ENABLE_SCANNER then return end
    local unitID = api.Unit:GetUnitId(unitTag)
    if not unitID then return end
    if not activeDebuffsCache[unitID] then activeDebuffsCache[unitID] = {} end
    if not activeCCSessions[unitID] then activeCCSessions[unitID] = {} end
    
    local count = api.Unit:UnitDeBuffCount(unitTag) or 0
    local currentScan = {}
    
    for i = 1, count do
        local debuff = api.Unit:UnitDeBuff(unitTag, i)
        if debuff and debuff.buff_id then
            local dName = "Unknown"
            if buffDB[debuff.buff_id] then dName = buffDB[debuff.buff_id]
            elseif buffNameCache[debuff.buff_id] then dName = buffNameCache[debuff.buff_id]
            else
                local tooltip = api.Ability.GetBuffTooltip(debuff.buff_id, debuff.buff_id)
                if tooltip and tooltip.name then dName = tooltip.name elseif debuff.name then dName = debuff.name end
                buffNameCache[debuff.buff_id] = dName
            end
            
            if dName ~= "Unknown" and not IsIgnoredBuff(dName) then
                currentScan[dName] = true
                if not activeDebuffsCache[unitID][dName] then
                    -- Scanner extends combat if already fighting, but never starts it
                    if inCombat then
                        timeSinceLastAction = 0
                    end

                    local duration = debuff.timeLeft or 0
                    local durStr = "Active"
                    if duration > 0 then durStr = string.format("%.1fs", duration/1000) end
                    local targetName = api.Unit:GetUnitNameById(unitID) or unitTag
                    local isCC = CC_DB[dName]
                    if not isCC then
                        local lower = string.lower(dName)
                        if string.find(lower, "sleep") or string.find(lower, "trip") or string.find(lower, "fear") then isCC = true end
                    end
                    local c = GetSafeColor(isCC and CONFIG.COL_CC or CONFIG.COL_OUT_NRM)
                    if unitTag == "player" then
                        if not activeCCSessions[unitID] or not activeCCSessions[unitID][dName] then
                            LogEntry(string.format("[Debuff] %s: Applied to YOU (%s)", dName, durStr), c[1], c[2], c[3])
                        end
                    else
                        if not activeCCSessions[unitID][dName] then
                            RecordLogForTarget(unitID, targetName, string.format("[Debuff] %s (%s)", dName, durStr), c[1], c[2], c[3])
                            activeCCSessions[unitID][dName] = api.Time:GetUiMsec()
                        end
                    end
                end
            end
        end
    end
    
    for oldBuff, startTime in pairs(activeCCSessions[unitID]) do
        if not currentScan[oldBuff] then
            local totalDur = (api.Time:GetUiMsec() - startTime) / 1000
            local c = GetSafeColor(CONFIG.COL_CC)
            local tName = api.Unit:GetUnitNameById(unitID) or unitTag
            if unitTag ~= "player" then
                RecordLogForTarget(unitID, tName, string.format("[Debuff] %s: Ended (%.1fs)", oldBuff, totalDur), c[1], c[2], c[3])
                local outData = GetOrCreateOutgoing(unitID, tName, api.Time:GetUiMsec())
                if not outData.ccDurations then outData.ccDurations = {} end
                local prev = outData.ccDurations[oldBuff] or 0
                outData.ccDurations[oldBuff] = prev + totalDur
                outData.lastUpdate = api.Time:GetUiMsec()
            end
            activeCCSessions[unitID][oldBuff] = nil
        end
    end
    activeDebuffsCache[unitID] = currentScan
end

-- === EVENT HANDLER ===
local function OnLiveEvent(self, event, ...)
    local args = { ... }; if #args == 0 and arg then args = arg end
    if event == "COMBAT_MSG" then
        -- patch 243+: dump all event args to chat for debugging
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        local unitID = tostring(args[1] or "0")
        local actionType = tostring(args[2] or "")
        local sourceName = tostring(args[3] or "Unknown")
        local targetName = tostring(args[4] or "Unknown")
        local skill = tostring(args[6] or "Attack")
        -- Normalize auto-attack skill names before early-exit checks
        if skill == "HEALTH" or skill == "Attack" then
            skill = string.find(actionType, "RANGED") and "Ranged Attack" or "Auto Attack"
        end

        if not skill or skill == "nil" then return end
        if IsIgnoredBuff(skill) then return end

        -- Defer string.upper until after early exits (saves work on filtered events)
        local upAct = string.upper(actionType)
        local missSubType = string.upper(tostring(args[5] or ""))
        local hitType = tostring(args[10] or "HIT")
        local upHit = string.upper(hitType)
        local damage = tonumber(args[8] or 0)
        -- arg[11] = raw pre-mitigation damage (before armor/resist/toughness)
        local rawDamage = tonumber(args[11] or 0)

        -- Heal detection
        local isHeal = false
        if string.find(upHit, "HEAL") or upHit == "HOT" then isHeal = true end
        if string.find(upAct, "HEAL") or upAct == "HOT" then isHeal = true end

        local absDmg = math.abs(damage)
        local now = frameNow  -- cached by OnUpdate, avoids GetUiMsec() per event

        -- HEALS: route to separate tracking, never trigger combat
        if isHeal and absDmg > 0 then
            local c = GetSafeColor(CONFIG.COL_HEAL)
            if sourceName == PLAYER_NAME then
                RecordHealLog("done_" .. targetName, targetName, string.format("+ %s -> %s: %d", skill, targetName, absDmg), c[1], c[2], c[3],
                    { logType = "heal", skill = skill, source = sourceName, target = targetName, damage = absDmg })
                if inCombat then
                    if not healData.done[targetName] then
                        local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                        if not okP then pInfo = {} end
                        healData.done[targetName] = {
                            skills = {}, startTime = now, lastUpdate = now,
                            healSnap = {
                                healMul       = tonumber(pInfo.heal_mul            or 0),
                                healCritRate  = tonumber(pInfo.heal_critical_rate  or 0),
                                healCritBonus = tonumber(pInfo.heal_critical_bonus or 50),
                                castingTime   = tonumber(pInfo.casting_time        or 100),
                            },
                        }
                    end
                    healData.done[targetName].skills[skill] = (healData.done[targetName].skills[skill] or 0) + absDmg
                    healData.done[targetName].lastUpdate = now
                end
            elseif targetName == PLAYER_NAME then
                RecordHealLog("recv_" .. sourceName, sourceName, string.format("+ %s from %s: %d", skill, sourceName, absDmg), c[1], c[2], c[3],
                    { logType = "heal", skill = skill, source = sourceName, target = targetName, damage = absDmg })
                if inCombat then
                    if not healData.received[sourceName] then healData.received[sourceName] = { skills = {}, startTime = now, lastUpdate = now } end
                    healData.received[sourceName].skills[skill] = (healData.received[sourceName].skills[skill] or 0) + absDmg
                    healData.received[sourceName].lastUpdate = now
                end
            end
            return
        end

        -- Defend / Miss detection (outgoing hits negated by target)
        -- args[5] sub-type distinguishes DODGE/BLOCK/MISS/PARRY within MELEE_MISSED events
        local isDefend = (missSubType == "BLOCK" or missSubType == "PARRY"
                       or string.find(upHit, "DEFEND") ~= nil or string.find(upAct, "DEFEND") ~= nil
                       or string.find(upHit, "PARRI")  ~= nil or string.find(upAct, "PARRI")  ~= nil)
        local isMiss   = (missSubType == "MISS" or missSubType == "DODGE" or missSubType == "EVADE"
                       or (missSubType == "" and (
                           string.find(upHit, "MISS")  ~= nil or string.find(upAct, "MISS")  ~= nil
                        or string.find(upHit, "EVADE") ~= nil or string.find(upAct, "EVADE") ~= nil
                        or string.find(upHit, "DODGE") ~= nil or string.find(upAct, "DODGE") ~= nil)))
        local isImmune = (missSubType == "IMMUNE"
                       or string.find(upHit, "IMMUN") ~= nil or string.find(upAct, "IMMUN") ~= nil
                       or string.find(upHit, "INVINCIB") ~= nil or string.find(upAct, "INVINCIB") ~= nil)

        if (isDefend or isMiss or isImmune) and sourceName == PLAYER_NAME and targetName ~= PLAYER_NAME and targetName ~= "Unknown" and unitID ~= "0" then
            timeSinceLastAction = 0
            if not inCombat then
                inCombat = true
                lastTargetBuffCount = -1  -- force buff effects re-scan on combat start
                liveTitleLabel:SetText("Combat Log [COMBAT]")
                if liveTitleLabel.style then liveTitleLabel.style:SetColor(1, 0, 0, 1) end
            end
            local outData = GetOrCreateOutgoing(unitID, targetName, now)
            outData.lastUpdate = now
            local label, verb
            if     isImmune               then label = "!Immune!"   verb = "immune"
            elseif missSubType == "BLOCK"  then label = "!Blocked"  verb = "blocked"
            elseif missSubType == "PARRY"  then label = "!Parried"  verb = "parried"
            elseif missSubType == "DODGE"  then label = "!Evaded"   verb = "evaded"
            elseif missSubType == "EVADE"  then label = "!Evaded"   verb = "evaded"
            elseif isDefend               then label = "!Defended"  verb = "blocked"
            else                               label = "!Missed"    verb = "missed"
            end
            local sc = PALETTE.SkyBlue
            local missColor = isImmune and { 1, 0.4, 0.1 } or { 0.55, 0.55, 0.55 }
            RecordLogForTarget(unitID, targetName,
                string.format("%s: %s", skill, targetName),
                sc[1], sc[2], sc[3],
                { logType = "miss", skill = skill, source = sourceName, target = targetName, missType = label })
            RecordLogForTarget(unitID, targetName, label, missColor[1], missColor[2], missColor[3], nil)
            if isImmune then
                outData.invincibleSkills[skill] = (outData.invincibleSkills[skill] or 0) + 1
            elseif isDefend then
                outData.defends[skill] = (outData.defends[skill] or 0) + 1
            else
                outData.misses[skill] = (outData.misses[skill] or 0) + 1
            end
            return
        end

        -- Parse absorb data (only for non-heal combat events)
        local absorbed = 0
        local parseOk, parseResult = false, nil
        if _parseAvailable then
            parseOk, parseResult = true, _parseCombatMessage(actionType, unpack(args, 5))
        end
        if parseOk and parseResult then
            if parseResult.reduced then
                absorbed = math.abs(tonumber(parseResult.reduced) or 0)
            end
            -- MELEE_DAMAGE (auto attacks): args[8] is unreliable — sometimes 0, sometimes the
            -- absorbed amount. Always prefer parseResult.damage for auto attacks when available.
            if parseResult.damage and (absDmg == 0 or skill == "Auto Attack") then
                absDmg = math.abs(tonumber(parseResult.damage) or 0)
            end
            -- hitType for auto attacks is in parseResult, not args[10]
            if parseResult.hitType and tonumber(args[10]) ~= nil then
                upHit = string.upper(tostring(parseResult.hitType))
            end
        end

        -- DEBUG: dump all ParseCombatMessage fields to file so we can see what the game reports
        if CONFIG.DEBUG_PARSE and parseOk and parseResult and absDmg > 0 then
            local dumpLines = {}
            table.insert(dumpLines, string.format("-- act=%s src=%s tgt=%s skill=%s dmg=%d", actionType, sourceName, targetName, skill, absDmg))
            local ok, err = pcall(function()
                for k, v in pairs(parseResult) do
                    table.insert(dumpLines, string.format("  %s = %s", tostring(k), tostring(v)))
                end
            end)
            if not ok then table.insert(dumpLines, "  (pairs failed: " .. tostring(err) .. ")") end
            -- Also dump raw args
            for i, v in ipairs(args) do
                table.insert(dumpLines, string.format("  args[%d] = %s", i, tostring(v)))
            end
            table.insert(dumpLines, "")
            local ok2, existing = pcall(function() return api.File:Read("Combat_Log_pro/parse_dump.txt") end)
            local prev = (ok2 and existing and existing ~= "") and (existing .. "\n") or ""
            pcall(function() api.File:Write("Combat_Log_pro/parse_dump.txt", prev .. table.concat(dumpLines, "\n")) end)
        end

        -- COMBAT: damage or CC from COMBAT_MSG also triggers combat (backup for game event)
        -- Player-initiated 0-damage actions are handled by UNIT_COMBAT_STATE_CHANGED
        local isCC = CC_DB[skill] ~= nil
        local isPlayerAction = (sourceName == PLAYER_NAME and targetName ~= PLAYER_NAME and targetName ~= "Unknown")
        local isCombatTrigger = (absDmg > 0) or isCC or isPlayerAction
        if not isCombatTrigger then return end
        if sourceName ~= PLAYER_NAME and targetName ~= PLAYER_NAME then return end

        timeSinceLastAction = 0
        if not inCombat then
            inCombat = true
            liveTitleLabel:SetText("Combat Log [COMBAT]")
            if liveTitleLabel.style then liveTitleLabel.style:SetColor(1, 0, 0, 1) end
        end

        if sourceName == PLAYER_NAME then
            local outData = GetOrCreateOutgoing(unitID, targetName, now)
            outData.lastUpdate = now

            -- Infer damage type from mitigation ratio (physical vs magic)
            local dmgTag = InferDamageType(upAct, skill, absDmg, absorbed, outData.statSnapshot)
            local isMagicHit = (dmgTag == "Magic" or dmgTag == "Spell")
            local isRangedTag = (dmgTag == "Ranged")
            local dmgLabel = TYPE_SHORT[dmgTag] or dmgTag

            if absDmg > 0 then
                outData.skills[skill] = (outData.skills[skill] or 0) + absDmg
                outData.hitCounts[skill] = (outData.hitCounts[skill] or 0) + 1
                outData.skillTypes[skill] = dmgTag
                outData.totalAbsorbed = (outData.totalAbsorbed or 0) + absorbed
                -- Track physical/ranged/magic split for mitigation estimates
                if isMagicHit then
                    outData.magicDmg      = (outData.magicDmg      or 0) + absDmg
                    outData.magicAbsorbed = (outData.magicAbsorbed  or 0) + absorbed
                    outData.magicHits     = (outData.magicHits      or 0) + 1
                    if rawDamage > 0 then
                        outData.rawMagicDmg = (outData.rawMagicDmg or 0) + rawDamage
                    end
                elseif isRangedTag then
                    outData.rangedDmg     = (outData.rangedDmg      or 0) + absDmg
                    outData.rangedAbsorbed= (outData.rangedAbsorbed or 0) + absorbed
                    outData.rangedHits    = (outData.rangedHits     or 0) + 1
                    if rawDamage > 0 then
                        outData.rawRangedDmg = (outData.rawRangedDmg or 0) + rawDamage
                    end
                else
                    outData.physDmg       = (outData.physDmg        or 0) + absDmg
                    outData.physAbsorbed  = (outData.physAbsorbed   or 0) + absorbed
                    outData.physHits      = (outData.physHits        or 0) + 1
                    if rawDamage > 0 then
                        outData.rawPhysDmg = (outData.rawPhysDmg or 0) + rawDamage
                    end
                end

                -- Spell Shield: magic damage heals target
                if isMagicHit and targetBuffEffects.spellShieldPct > 0 then
                    local rawMagicHit = absDmg + absorbed
                    local healed = math.floor(rawMagicHit * targetBuffEffects.spellShieldPct / 100)
                    outData.spellShieldDmg = (outData.spellShieldDmg or 0) + rawMagicHit
                    outData.spellShieldHealed = (outData.spellShieldHealed or 0) + healed
                end

                -- Rune conversion: % of all damage heals target
                if targetBuffEffects.runeConvertPct > 0 then
                    local rawHit = absDmg + absorbed
                    local runeHealed = math.floor(rawHit * targetBuffEffects.runeConvertPct / 100)
                    outData.runeConvertDmg = (outData.runeConvertDmg or 0) + runeHealed
                    outData.runeConvertPct = targetBuffEffects.runeConvertPct
                    outData.runeConvertName = targetBuffEffects.runeConvertName
                end

                -- Damage shield: track damage dealt while any absorb shield is up
                if targetBuffEffects.dmgShield then
                    local rawHit = absDmg + absorbed
                    local shName = targetBuffEffects.dmgShieldName or "Damage Shield"
                    if not outData.dmgShields[shName] then
                        outData.dmgShields[shName] = { max = targetBuffEffects.dmgShieldMax, rawDmg = 0 }
                    end
                    outData.dmgShields[shName].rawDmg = outData.dmgShields[shName].rawDmg + rawHit
                    if targetBuffEffects.dmgShieldMax > outData.dmgShields[shName].max then
                        outData.dmgShields[shName].max = targetBuffEffects.dmgShieldMax
                    end
                end

            end

            if isCC then
                local c = GetSafeColor(CONFIG.COL_CC)
                RecordLogForTarget(unitID, targetName, string.format("%s (CC): Hit", skill), c[1], c[2], c[3],
                    { logType = "cc", skill = skill, source = sourceName, target = targetName })
            elseif dotSkills[skill] then
                local key = unitID .. "_" .. skill
                if not activeDots[key] then
                    activeDots[key] = { target = targetName, skill = skill, dmg = 0, hits = 0, start = now, timer = 0 }
                else
                    activeDots[key].start = now
                    activeDots[key].timer = 0
                end
                activeDots[key].dmg = activeDots[key].dmg + absDmg
                activeDots[key].hits = activeDots[key].hits + 1
                local c = GetSafeColor(CONFIG.COL_OUT_NRM)
                outData.skillTypes[skill] = dmgTag
                local sc = PALETTE.SkyBlue
                RecordLogForTarget(unitID, targetName,
                    string.format("%s (DoT): %s", skill, targetName),
                    sc[1], sc[2], sc[3],
                    { logType = "dot", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed })
                RecordLogForTarget(unitID, targetName,
                    absorbed > 0
                        and string.format("[%s] %d (%d absorbed)", dmgLabel, absDmg, absorbed)
                        or  string.format("[%s] %d", dmgLabel, absDmg),
                    c[1], c[2], c[3], nil)
            elseif absDmg > 0 then
                local isCrit     = string.find(upHit, "CRITICAL")  ~= nil
                local isBackstab = string.find(upHit, "BACKSTAB")  ~= nil
                                or string.find(upAct, "BACKSTAB")  ~= nil
                local bsSkillInfo = isBackstab and SKILL_BACKSTAB_BONUSES[skill] or nil
                if isBackstab then
                    outData.backstabHits = (outData.backstabHits or 0) + 1
                    outData.backstabDmg  = (outData.backstabDmg  or 0) + absDmg
                    if bsSkillInfo then
                        outData.backstabSkillHits = outData.backstabSkillHits or {}
                        outData.backstabSkillHits[skill] = (outData.backstabSkillHits[skill] or 0) + 1
                    end
                end
                local c
                if zealActive and isCrit then
                    c = { 1, 0.3, 1, 1 }  -- bright purple for zeal crits only
                else
                    c = isCrit and GetSafeColor(CONFIG.COL_OUT_CRIT) or GetSafeColor(CONFIG.COL_OUT_NRM)
                end
                local hitDisplay = isCrit and "Critical" or "HIT"
                -- Line 1: skill + target (backstab annotation here)
                local bsTag = isBackstab and (bsSkillInfo and " [BS+]" or " [BS]") or ""
                local skillLine = string.format("%s: %s%s", skill, targetName, bsTag)
                -- Line 2: damage type + number + hit info (+ Zeal bonus if applicable)
                local dmgLine
                if zealActive then
                    outData.zealHits = (outData.zealHits or 0) + 1
                    if isCrit then
                        local snap = outData.statSnapshot
                        local critBonus = snap and (snap.playerSpellCritBonus or snap.playerMeleeCritBonus or 50) or 50
                        local zealBonus = math.floor(absDmg * 75 / (225 + critBonus))
                        outData.zealExtraDmg = (outData.zealExtraDmg or 0) + zealBonus
                        dmgLine = absorbed > 0
                            and string.format("[%s] %d (%s|%d absorbed) [Zeal +%d]", dmgLabel, absDmg, hitDisplay, absorbed, zealBonus)
                            or  string.format("[%s] %d (%s) [Zeal +%d]", dmgLabel, absDmg, hitDisplay, zealBonus)
                    else
                        dmgLine = absorbed > 0
                            and string.format("[%s] %d (%s|%d absorbed)", dmgLabel, absDmg, hitDisplay, absorbed)
                            or  string.format("[%s] %d (%s)", dmgLabel, absDmg, hitDisplay)
                    end
                else
                    dmgLine = absorbed > 0
                        and string.format("[%s] %d (%s|%d absorbed)", dmgLabel, absDmg, hitDisplay, absorbed)
                        or  string.format("[%s] %d (%s)", dmgLabel, absDmg, hitDisplay)
                end
                -- Combo detection: build labels, log separately after damage line
                local isSynergy = parseOk and parseResult and parseResult.synergy == true
                local comboLabels = {}
                local totalBonus = 0
                if isSynergy then
                    local comboConds = SKILL_COMBOS[skill]
                    if comboConds then
                        for _, entry in ipairs(comboConds) do
                            local cond     = entry.cond
                            local pct      = entry.pct
                            local effect   = entry.effect
                            local selfbuff = entry.selfbuff
                            local matched = false
                            local matchName = nil
                            if cond then
                                local dotKey = unitID .. "_" .. cond
                                if activeDots[dotKey] ~= nil
                                or (activeDebuffsCache[unitID] and activeDebuffsCache[unitID][cond]) then
                                    matched = true; matchName = cond
                                end
                            elseif selfbuff then
                                matched = true; matchName = selfbuff
                            end
                            if matched then
                                local effectivePct = pct
                                if selfbuff and pct then
                                    local stacks = GetPlayerBuffStacks(selfbuff)
                                    if stacks > 1 then effectivePct = pct * stacks end
                                end
                                local label
                                if effectivePct then
                                    local pct = effectivePct
                                    local bonus = math.floor(absDmg * pct / (100 + pct))
                                    totalBonus = totalBonus + bonus
                                    label = effect
                                        and string.format("%s +%d%% (+%d) | %s", matchName, pct, bonus, effect)
                                        or  string.format("%s +%d%% (+%d)", matchName, pct, bonus)
                                    -- key by skill+condition so different combo triggers stay separate
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=pct, hits=1, bonusDmg=bonus }
                                    else
                                        sk.hits = sk.hits + 1
                                        sk.bonusDmg = sk.bonusDmg + bonus
                                        sk.pct = pct  -- update to latest (stack count can vary)
                                    end
                                elseif effect then
                                    label = matchName .. " | " .. effect
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=nil, hits=1, bonusDmg=0 }
                                    else
                                        sk.hits = sk.hits + 1
                                    end
                                else
                                    label = matchName
                                    local csKey = skill .. "|" .. matchName
                                    local sk = outData.comboSkills[csKey]
                                    if not sk then
                                        outData.comboSkills[csKey] = { skillName=skill, cond=matchName, pct=nil, hits=1, bonusDmg=0 }
                                    else
                                        sk.hits = sk.hits + 1
                                    end
                                end
                                table.insert(comboLabels, label)
                            end
                        end
                    end
                    if #comboLabels > 0 then
                        outData.comboHits = (outData.comboHits or 0) + 1
                        outData.comboBonusDmg = (outData.comboBonusDmg or 0) + totalBonus
                    end
                end
                local sc = PALETTE.SkyBlue
                local cc = { 0.75, 0.5, 1 }  -- soft purple for combo lines
                RecordLogForTarget(unitID, targetName, skillLine, sc[1], sc[2], sc[3],
                    { logType = "outgoing", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed, hitType = hitType })
                RecordLogForTarget(unitID, targetName, dmgLine, c[1], c[2], c[3], nil)
                if isSynergy then
                    if #comboLabels > 0 then
                        local header = #comboLabels == 1 and "Skill Comboed:" or string.format("Skills Comboed x%d:", #comboLabels)
                        RecordLogForTarget(unitID, targetName, header, cc[1], cc[2], cc[3], { logType = "combo" })
                        for _, lbl in ipairs(comboLabels) do
                            RecordLogForTarget(unitID, targetName, lbl, cc[1], cc[2], cc[3], nil)
                        end
                    else
                        RecordLogForTarget(unitID, targetName, "Skill Comboed", cc[1], cc[2], cc[3], { logType = "combo" })
                    end
                end
            elseif isPlayerAction then
                if targetBuffEffects.invincible then
                    -- Skill eaten by invincibility (detected via buff scanner)
                    outData.invincibleSkills[skill] = (outData.invincibleSkills[skill] or 0) + 1
                    local sc = PALETTE.SkyBlue
                    RecordLogForTarget(unitID, targetName,
                        string.format("%s: %s", skill, targetName),
                        sc[1], sc[2], sc[3],
                        { logType = "invincible", skill = skill, source = sourceName, target = targetName })
                    RecordLogForTarget(unitID, targetName, "!Immune!", 1, 0.4, 0.1, nil)
                else
                    -- 0-damage player action (Fear, Sleep, debuff opener, etc.)
                    outData.appliedDebuffs[skill] = true
                    local c = GetSafeColor("Cyan")
                    RecordLogForTarget(unitID, targetName, string.format("%s -> %s", skill, targetName), c[1], c[2], c[3],
                        { logType = "cc", skill = skill, source = sourceName, target = targetName })
                    -- Debug: dump target buff names so we can identify unknown invincibility buffs
                    if CONFIG.DEBUG_ZERO_HITS then
                        local n = api.Unit:UnitBuffCount("target") or 0
                        local parts = {}
                        for i = 1, n do
                            local b = api.Unit:UnitBuff("target", i)
                            if b and b.buff_id then
                                local bname = buffNameCache[b.buff_id] or ("id:" .. b.buff_id)
                                table.insert(parts, bname)
                            end
                        end
                        local buffStr = #parts > 0 and table.concat(parts, ", ") or "none"
                        api.Log:Info(string.format("[DEBUG_ZERO_HITS] %s hit %s for 0 | target buffs: %s", skill, targetName, buffStr))
                    end
                end
            end

        elseif targetName == PLAYER_NAME then
            if not fightData.incoming[sourceName] then
                local okP, pInfo = pcall(function() return api.Unit:UnitInfo("player") end)
                if not okP then pInfo = {} end
                fightData.incoming[sourceName] = {
                    skills = {}, startTime = now, lastUpdate = now,
                    physDmg = 0, magicDmg = 0, rangedDmg = 0,
                    physAbsorbed = 0, magicAbsorbed = 0, rangedAbsorbed = 0,
                    physHits = 0, magicHits = 0, rangedHits = 0,
                    defSnap = {
                        armor            = tonumber(pInfo.armor                      or 0),
                        armorPct         = tonumber(pInfo.armor_percentage           or 0),
                        resist           = tonumber(pInfo.magic_resist               or 0),
                        resistPct        = tonumber(pInfo.magic_resist_percentage    or 0),
                        dodge            = tonumber(pInfo.dodge_rate                 or 0),
                        block            = tonumber(pInfo.block_rate                 or 0),
                        parry            = tonumber(pInfo.melee_parry_rate           or 0),
                        toughness        = tonumber(pInfo.battle_resist              or 0),
                        incomingMeleeMul = tonumber(pInfo.incoming_melee_damage_mul  or 0),
                        incomingSpellMul = tonumber(pInfo.incoming_spell_damage_mul  or 0),
                        incomingRangedMul= tonumber(pInfo.incoming_ranged_damage_mul or 0),
                        incomingMeleeVal = tonumber(pInfo.incoming_melee_damage_val  or 0),
                        incomingSpellVal = tonumber(pInfo.incoming_spell_damage_val  or 0),
                        incomingRangedVal= tonumber(pInfo.incoming_ranged_damage_val or 0),
                    },
                }
            else
                fightData.incoming[sourceName].lastUpdate = now
            end
            if absDmg > 0 then
                -- Infer damage type for incoming hits using our own defense stats
                local incSnap = fightData.incoming[sourceName].defSnap
                local incInferSnap = incSnap and {
                    targetArmorPct = incSnap.armorPct or 0,
                    targetResistPct = incSnap.resistPct or 0,
                    targetDefense = incSnap.armor or 0,
                    targetResist = incSnap.resist or 0,
                    playerPhysPen = 0, playerMagicPen = 0,
                } or nil
                local incTag = InferDamageType(upAct, skill, absDmg, absorbed, incInferSnap)
                local incLabel = TYPE_SHORT[incTag] or incTag
                local incIsMagic = (incTag == "Magic" or incTag == "Spell")
                local incIsRanged = (incTag == "Ranged")

                -- Log first occurrence of each incoming skill to file
                if CONFIG.LOG_UNKNOWN_INCOMING then
                    -- Load seen skills from file on first use
                    if not incomingSkillLoaded then
                        incomingSkillLoaded = true
                        local ok, existing = pcall(function() return api.File:Read(incomingSkillFile) end)
                        if ok and existing then
                            for s in string.gmatch(existing, "skill=([^\n]+)\n?") do
                                seenIncomingSkills[s] = true
                            end
                        end
                    end
                    if not seenIncomingSkills[skill] then
                        seenIncomingSkills[skill] = true
                        local isKnown = SKILL_DAMAGE_TYPES[skill] ~= nil
                        local confidence = absorbed > 0 and "inferred" or "no-mitigation-data"
                        local entry = string.format("[%s] type=%s skill=%s source=%s action=%s confidence=%s",
                            isKnown and "KNOWN" or "NEW", incTag, skill, sourceName, actionType, confidence)
                        local prev = ""
                        local ok2, existing2 = pcall(function() return api.File:Read(incomingSkillFile) end)
                        if ok2 and existing2 and existing2 ~= "" then prev = existing2 end
                        local append = prev ~= "" and (prev .. "\n" .. entry) or entry
                        pcall(function() api.File:Write(incomingSkillFile, append) end)
                        if not isKnown then
                            LogEntry(string.format("[New] %s from %s = %s", skill, sourceName, incTag), 1, 0.7, 0.2)
                        end
                    end
                end
                if incIsMagic then
                    fightData.incoming[sourceName].magicDmg      = (fightData.incoming[sourceName].magicDmg      or 0) + absDmg
                    fightData.incoming[sourceName].magicAbsorbed = (fightData.incoming[sourceName].magicAbsorbed  or 0) + absorbed
                    fightData.incoming[sourceName].magicHits     = (fightData.incoming[sourceName].magicHits      or 0) + 1
                elseif incIsRanged then
                    fightData.incoming[sourceName].rangedDmg      = (fightData.incoming[sourceName].rangedDmg      or 0) + absDmg
                    fightData.incoming[sourceName].rangedAbsorbed = (fightData.incoming[sourceName].rangedAbsorbed or 0) + absorbed
                    fightData.incoming[sourceName].rangedHits     = (fightData.incoming[sourceName].rangedHits     or 0) + 1
                else
                    fightData.incoming[sourceName].physDmg      = (fightData.incoming[sourceName].physDmg      or 0) + absDmg
                    fightData.incoming[sourceName].physAbsorbed = (fightData.incoming[sourceName].physAbsorbed  or 0) + absorbed
                    fightData.incoming[sourceName].physHits     = (fightData.incoming[sourceName].physHits      or 0) + 1
                end
                fightData.incoming[sourceName].skills[skill] = (fightData.incoming[sourceName].skills[skill] or 0) + absDmg
                fightData.incoming[sourceName].totalAbsorbed = (fightData.incoming[sourceName].totalAbsorbed or 0) + absorbed
                local c = GetSafeColor(CONFIG.COL_INCOMING)
                local incHitDisplay = string.find(tostring(hitType):upper(), "CRITICAL") and "Critical" or "HIT"
                local sc = PALETTE.SkyBlue
                RecordLogForTarget(sourceName, sourceName,
                    string.format("< %s from %s", skill, sourceName),
                    sc[1], sc[2], sc[3],
                    { logType = "incoming", skill = skill, source = sourceName, target = targetName, damage = absDmg, absorbed = absorbed, hitType = hitType })
                RecordLogForTarget(sourceName, sourceName,
                    absorbed > 0
                        and string.format("[%s] %d (%s|%d absorbed)", incLabel, absDmg, incHitDisplay, absorbed)
                        or  string.format("[%s] %d (%s)", incLabel, absDmg, incHitDisplay),
                    c[1], c[2], c[3], nil)
            elseif isCC then
                local c = GetSafeColor(CONFIG.COL_CC)
                RecordLogForTarget(sourceName, sourceName, string.format("< %s (CC) from %s", skill, sourceName), c[1], c[2], c[3],
                    { logType = "cc", skill = skill, source = sourceName, target = targetName })
            end
        end

    elseif event == "UNIT_COMBAT_STATE_CHANGED" then
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        -- args[1] = boolean (true=entering, false=leaving), args[2] = unitId (string)
        local enteringCombat = args[1]
        local unitId = tostring(args[2] or "")
        local playerId = tostring(api.Unit:GetUnitId("player") or "")
        if unitId == playerId then
            if enteringCombat == true then
                if not inCombat then
                    inCombat = true
                    timeSinceLastAction = 0
                    liveTitleLabel:SetText("Combat Log [COMBAT]")
                    if liveTitleLabel.style then liveTitleLabel.style:SetColor(1, 0, 0, 1) end
                end
            else
                -- Game says combat ended - give DOT_WAIT room for trailing DoT ticks
                -- before FinishFight closes the session.
                if inCombat then
                    local waitAfterCombatEnd = CONFIG.COMBAT_WAIT - CONFIG.DOT_WAIT
                    if waitAfterCombatEnd < 0 then waitAfterCombatEnd = 0 end
                    timeSinceLastAction = waitAfterCombatEnd
                end
            end
        end

    elseif event == "TARGET_CHANGED" then
        -- patch 243+: instant target update instead of waiting for 200ms scan tick
        local currentTgtID = api.Unit:GetUnitId("target")
        if currentTgtID ~= lastTargetID then
            lastTargetID = currentTgtID
            if currentTgtID then activeDebuffsCache[currentTgtID] = {} end
            lastTargetBuffCount = -1  -- force buff effects re-scan on next tick
        end
        -- Immediately rescan buffs/debuffs on the new target
        ScanUnitDebuffs("player")
        ScanUnitDebuffs("target")

    elseif event == "SPELLCAST_SUCCEEDED" then
        -- patch 243+: fires when a cast-time skill completes (before the COMBAT_MSG damage event).
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        -- Attempt to cache the skill name (arg layout TBD; try common positions)
        local castSkill = tostring(args[2] or args[1] or "")
        if castSkill ~= "" and castSkill ~= "0" then
            lastPlayerCast = castSkill
        end
        currentCast = nil  -- cast finished, clear in-progress state

    elseif event == "SPELLCAST_START" then
        -- patch 243+: fires when the player begins casting a cast-time skill.
        -- arg[1]=skill name, arg[2]=cast time ms, arg[3]="player", arg[4]=false
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        local castSkill = tostring(args[1] or "")
        if castSkill ~= "" and castSkill ~= "0" then
            currentCast = castSkill
            lastPlayerCast = castSkill  -- cache here since SUCCEEDED only returns "player"
        end

    elseif event == "SPELLCAST_STOP" then
        -- patch 243+: fires when a cast is cancelled or interrupted.
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        local interrupted = currentCast
        currentCast = nil
        lastPlayerCast = nil
        -- Log the interrupt in the live feed if we were mid-fight
        if inCombat and interrupted and interrupted ~= "" then
            local c = GetSafeColor("Orange")
            LogEntry("!! Cast interrupted: " .. interrupted, c[1], c[2], c[3])
        end

    elseif event == "TARGET_TO_TARGET_CHANGED" then
        -- patch 243+: fires when what your target is targeting changes.
        -- Update the live targeting flag used at fight-start snapshot time.
        if CONFIG.DEBUG_LOG_EVENTS then
            LogEventToFile(event, args)
        end
        local okTU, targeting = pcall(function()
            return api.Unit:TargetUnit("target")
        end)
        targetIsTargetingPlayerLive = (okTU and targeting == "player")
        -- Also update any active outgoing session for the current target so
        -- the summary reflects the live state rather than just the fight-start snapshot.
        local currentTgt = api.Unit:GetUnitId("target")
        if currentTgt and fightData.outgoing[tostring(currentTgt)] then
            local snap = fightData.outgoing[tostring(currentTgt)].statSnapshot
            if snap then snap.targetIsTargetingPlayer = targetIsTargetingPlayerLive end
        end
    end
end

local function OnLiveUpdate(self, dt)
    local elapsed = dt
    if elapsed < 1 then elapsed = elapsed * 1000 end
    local now = api.Time:GetUiMsec()

    -- Update cached timestamp once per frame (used by all log entry functions)
    RefreshTimestamp(now)

    -- Flush any throttled live label rebuild / history display update
    if (liveRebuildDirty or histDisplayDirty) and (now - lastLiveRebuildTime) >= 50 then
        lastLiveRebuildTime = now
        if liveRebuildDirty then
            liveRebuildDirty = false
            RebuildLiveLabels()
        end
        if histDisplayDirty then
            histDisplayDirty = false
            UpdateHistoryDisplay()
        end
    end

    -- === TIME INITIALIZATION ===
    if not TIME_INITIALIZED then
        local t = api.Time:GetLocalTime()
        if t then
            if type(t) == "table" then
                local h = tonumber(t.hour or t.Hour) or 0
                local m = tonumber(t.minute or t.Minute) or 0
                local s = tonumber(t.second or t.Second) or 0
                BASE_SECONDS_OF_DAY = (h * 3600) + (m * 60) + s
                BASE_APP_MSEC = now
                TIME_INITIALIZED = true
            elseif type(t) == "number" or type(t) == "string" then
                local tVal = tonumber(t)
                if tVal and tVal > 0 then
                    BASE_SECONDS_OF_DAY = tVal % 86400
                    BASE_APP_MSEC = now
                    TIME_INITIALIZED = true
                end
            end
        end
    end
    
    if PLAYER_NAME == "Unknown" then
        nameCheckTimer = nameCheckTimer + elapsed
        if nameCheckTimer > 1000 then
            nameCheckTimer = 0
            local myName = api.Unit:UnitName("player")  -- patch 243+: simpler than GetUnitId+GetUnitNameById
            if not myName or myName == "" then
                local myId = api.Unit:GetUnitId("player")
                myName = api.Unit:GetUnitNameById(myId)
            end
            if myName and myName ~= "" then PLAYER_NAME = myName; LogEntry("[System] Player Name Detected: " .. PLAYER_NAME, 0, 1, 0) end
        end
    end
    
    scannerTimer = scannerTimer + elapsed
    if scannerTimer > CONFIG.SCAN_FREQ then
        scannerTimer = 0
        -- Target-ID change is now handled instantly by TARGET_CHANGED event (patch 243+).
        -- Poll here as fallback in case the event is not fired (e.g. on older builds).
        local currentTgtID = api.Unit:GetUnitId("target")
        if currentTgtID ~= lastTargetID then
            lastTargetID = currentTgtID
            if currentTgtID then activeDebuffsCache[currentTgtID] = {} end
            lastTargetBuffCount = -1  -- force buff effects re-scan on next tick
        end
        if inCombat then ScanUnitDebuffs("player"); ScanUnitDebuffs("target") end

        -- Scan target buffs for combat-affecting effects (invincibility, spell shield, runes)
        -- Target buff effects scan (invincibility, spell shield, rune, damage shield).
        -- Skip if buff count unchanged since last scan — avoids redundant API calls.
        local tgtBuffCount = api.Unit:UnitBuffCount("target") or 0
        if tgtBuffCount ~= lastTargetBuffCount then
            lastTargetBuffCount = tgtBuffCount
            targetBuffEffects.invincible = false
            targetBuffEffects.spellShieldPct = 0
            targetBuffEffects.runeConvertPct = 0
            targetBuffEffects.runeConvertName = nil
            targetBuffEffects.dmgShield = false
            targetBuffEffects.dmgShieldMax = 0
            targetBuffEffects.dmgShieldName = nil
            for i = 1, tgtBuffCount do
                local b = api.Unit:UnitBuff("target", i)
                if b and b.buff_id then
                    -- Use buffEffectCache to avoid re-parsing tooltip text per buff_id
                    local fx = buffEffectCache[b.buff_id]
                    if fx == nil then
                        fx = {}
                        local tt = api.Ability:GetBuffTooltip(b.buff_id)
                        local name = tt and tt.name or ""
                        local desc = tt and (tt.desc or tt.description or tt.text or tt.info) or ""
                        local combined = string.lower(name .. " " .. desc)
                        buffNameCache[b.buff_id] = name

                        -- Invincibility: tooltip text patterns
                        if (string.find(combined, "immun") and
                           (string.find(combined, "all damage") or string.find(combined, "all attacks") or
                            string.find(combined, "immune to all") or string.find(combined, "immune to damage") or
                            string.find(combined, "immune to incoming")))
                           or string.find(combined, "invincib")
                           or string.find(combined, "cannot receive damage")
                           or string.find(combined, "cannot take damage")
                           or string.find(combined, "damage immunity")
                           or string.find(combined, "impervious to damage")
                           or string.find(combined, "negates all damage")
                           or (string.find(combined, "shadowsong") and string.find(combined, "resists all damage")) then
                            fx.invincible = true
                        end
                        -- Invincibility: known mount/glider buff names (tooltip may not mention immunity)
                        if not fx.invincible and KNOWN_INVINCIBLE_BUFF_NAMES[string.lower(name)] then
                            fx.invincible = true
                        end
                        if string.find(combined, "spell shield") or
                           (string.find(combined, "convert") and string.find(combined, "magic") and string.find(combined, "health")) then
                            fx.spellShieldPct = tonumber(string.match(desc, "(%d+)%%")) or 0
                        end
                        if string.find(combined, "rune") and string.find(combined, "convert") and string.find(combined, "received damage") then
                            local pct = tonumber(string.match(desc, "(%d[%d%.]*)%%")) or 0
                            if pct > 0 then fx.runeConvertPct = pct; fx.runeConvertName = name end
                        end
                        if string.find(combined, "absorb") and string.find(combined, "damage") and
                           not string.find(combined, "absorb.-lifeforce") then
                            local maxAbs = string.match(desc, "absorbs%s+up%s+to%s+([%d,]+)")
                                        or string.match(desc, "absorbs%s+([%d,]+)")
                            if maxAbs then
                                local val = tonumber(string.gsub(maxAbs, ",", "")) or 0
                                if val > 0 then fx.dmgShield = true; fx.dmgShieldMax = val; fx.dmgShieldName = name end
                            end
                        end
                        buffEffectCache[b.buff_id] = fx
                    end
                    -- Apply cached flags
                    if fx.invincible    then targetBuffEffects.invincible = true end
                    if fx.spellShieldPct and fx.spellShieldPct > 0 then targetBuffEffects.spellShieldPct = fx.spellShieldPct end
                    if fx.runeConvertPct and fx.runeConvertPct > 0 then
                        targetBuffEffects.runeConvertPct  = fx.runeConvertPct
                        targetBuffEffects.runeConvertName = fx.runeConvertName
                    end
                    if fx.dmgShield then
                        targetBuffEffects.dmgShield    = true
                        targetBuffEffects.dmgShieldMax  = fx.dmgShieldMax or 0
                        targetBuffEffects.dmgShieldName = fx.dmgShieldName
                    end
                end
            end
        end

        -- Zeal uptime + duel-end detection (both scan player buffs while in combat)
        -- Also refreshes playerBuffStackCache so GetPlayerBuffStacks() reads a cached value
        -- instead of calling UnitBuff() again inside the combat event handler.
        do
            local nowMs = api.Time:GetUiMsec()
            local wasZeal = zealActive
            zealActive = false
            local bc = api.Unit:UnitBuffCount("player") or 0
            local newStackCache = {}
            for i = 1, bc do
                local b = api.Unit:UnitBuff("player", i)
                if b and b.buff_id then
                    -- Zeal check (by known ID)
                    if b.buff_id == 495 then zealActive = true end
                    -- Name resolution (needed for duel-end check and stack cache)
                    local bname = buffDB[b.buff_id] or buffNameCache[b.buff_id]
                    if not bname then
                        local ok, tt = pcall(function() return api.Ability:GetBuffTooltip(b.buff_id) end)
                        if ok and tt and tt.name then bname = tt.name; buffNameCache[b.buff_id] = bname end
                    end
                    if bname then
                        -- Populate stack cache (used by GetPlayerBuffStacks in combat handler)
                        newStackCache[bname] = math.max(1, tonumber(b.stack or b.count or 1))
                        -- Duel-end check
                        if inCombat and DUEL_END_BUFF_NAMES[string.lower(bname)] then
                            playerBuffStackCache = newStackCache
                            FinishFight()
                            break
                        end
                    end
                end
            end
            playerBuffStackCache = newStackCache
            if inCombat then
                if zealActive and not wasZeal then
                    zealStartTime = nowMs
                elseif not zealActive and wasZeal and zealStartTime then
                    fightZealTime = fightZealTime + (nowMs - zealStartTime)
                    zealStartTime = nil
                end
            end
        end

        if CONFIG.DUMP_BUFFS then
            CONFIG.DUMP_BUFFS = false
            local buffData = {}
            local count = api.Unit:UnitBuffCount("player") or 0
            for i = 1, count do
                local b = api.Unit:UnitBuff("player", i)
                if b then buffData[i] = b end
            end
            api.File:Write("Combat_Log_pro/buff_dump.txt", buffData)
            LogEntry(string.format("[DUMP] %d player buffs written to buff_dump.txt", count), 0, 1, 0)
        end

        -- Continuous target buff/debuff scanner
        if CONFIG.SCAN_TARGET_BUFFS then
            -- Load previously logged buff IDs from file on first run
            if not buffScanLoaded then
                buffScanLoaded = true
                local ok, existing = pcall(function() return api.File:Read(buffScanFile) end)
                if ok and existing then
                    for id in string.gmatch(existing, "%[(%d+)%]") do
                        seenBuffIds[tonumber(id)] = true
                    end
                end
            end

            local tgtId = api.Unit:GetUnitId("target")
            if tgtId and tgtId ~= "0" then
                local newEntries = {}
                local tgtName = api.Unit:GetUnitNameById(tgtId) or "Unknown"

                -- Scan buffs
                local buffCount = api.Unit:UnitBuffCount("target") or 0
                for i = 1, buffCount do
                    local b = api.Unit:UnitBuff("target", i)
                    if b and b.buff_id and not seenBuffIds[b.buff_id] then
                        seenBuffIds[b.buff_id] = true
                        local tooltip = api.Ability:GetBuffTooltip(b.buff_id)
                        local name = (tooltip and tooltip.name) or "Unknown"
                        local desc = tooltip and (tooltip.desc or tooltip.description or tooltip.text or tooltip.info) or ""
                        if desc then
                            desc = string.gsub(desc, "\r", "")
                            desc = string.gsub(desc, "\n", " ")
                        end
                        table.insert(newEntries, string.format("[BUFF] [%d] %s (on %s): %s", b.buff_id, name, tgtName, desc))
                    end
                end

                -- Scan debuffs
                local debuffCount = api.Unit:UnitDeBuffCount("target") or 0
                for i = 1, debuffCount do
                    local d = api.Unit:UnitDeBuff("target", i)
                    if d and d.buff_id and not seenBuffIds[d.buff_id] then
                        seenBuffIds[d.buff_id] = true
                        local tooltip = api.Ability:GetBuffTooltip(d.buff_id)
                        local name = (tooltip and tooltip.name) or "Unknown"
                        local desc = tooltip and (tooltip.desc or tooltip.description or tooltip.text or tooltip.info) or ""
                        if desc then
                            desc = string.gsub(desc, "\r", "")
                            desc = string.gsub(desc, "\n", " ")
                        end
                        table.insert(newEntries, string.format("[DEBUFF] [%d] %s (on %s): %s", d.buff_id, name, tgtName, desc))
                    end
                end

                -- Append new entries to file
                if #newEntries > 0 then
                    local prev = ""
                    local ok, existing = pcall(function() return api.File:Read(buffScanFile) end)
                    if ok and existing then prev = existing end
                    local append = table.concat(newEntries, "\n")
                    if prev ~= "" then append = prev .. "\n" .. append end
                    pcall(function() api.File:Write(buffScanFile, append) end)
                    LogEntry(string.format("[Buff Scan] +%d new entries written", #newEntries), 0.5, 0.8, 1)
                end
            end
        end

        -- Continuous player buff/debuff scanner
        if CONFIG.SCAN_PLAYER_BUFFS then
            if not playerBuffScanLoaded then
                playerBuffScanLoaded = true
                local ok, existing = pcall(function() return api.File:Read(playerBuffScanFile) end)
                if ok and existing then
                    for id in string.gmatch(existing, "%[(%d+)%]") do
                        seenPlayerBuffIds[tonumber(id)] = true
                    end
                end
            end

            local newEntries = {}

            local buffCount = api.Unit:UnitBuffCount("player") or 0
            for i = 1, buffCount do
                local b = api.Unit:UnitBuff("player", i)
                if b and b.buff_id and not seenPlayerBuffIds[b.buff_id] then
                    seenPlayerBuffIds[b.buff_id] = true
                    local tooltip = api.Ability:GetBuffTooltip(b.buff_id)
                    local name = (tooltip and tooltip.name) or "Unknown"
                    local desc = tooltip and (tooltip.desc or tooltip.description or tooltip.text or tooltip.info) or ""
                    if desc then
                        desc = string.gsub(desc, "\r", "")
                        desc = string.gsub(desc, "\n", " ")
                    end
                    table.insert(newEntries, string.format("[BUFF] [%d] %s: %s", b.buff_id, name, desc))
                end
            end

            local debuffCount = api.Unit:UnitDeBuffCount("player") or 0
            for i = 1, debuffCount do
                local d = api.Unit:UnitDeBuff("player", i)
                if d and d.buff_id and not seenPlayerBuffIds[d.buff_id] then
                    seenPlayerBuffIds[d.buff_id] = true
                    local tooltip = api.Ability:GetBuffTooltip(d.buff_id)
                    local name = (tooltip and tooltip.name) or "Unknown"
                    local desc = tooltip and (tooltip.desc or tooltip.description or tooltip.text or tooltip.info) or ""
                    if desc then
                        desc = string.gsub(desc, "\r", "")
                        desc = string.gsub(desc, "\n", " ")
                    end
                    table.insert(newEntries, string.format("[DEBUFF] [%d] %s: %s", d.buff_id, name, desc))
                end
            end

            if #newEntries > 0 then
                local prev = ""
                local ok, existing = pcall(function() return api.File:Read(playerBuffScanFile) end)
                if ok and existing then prev = existing end
                local append = table.concat(newEntries, "\n")
                if prev ~= "" then append = prev .. "\n" .. append end
                pcall(function() api.File:Write(playerBuffScanFile, append) end)
                LogEntry(string.format("[Player Scan] +%d new entries written", #newEntries), 0.5, 1, 0.5)
            end
        end

    end
    
    if inCombat then
        timeSinceLastAction = timeSinceLastAction + elapsed
        local currentTimeoutLimit = CONFIG.COMBAT_WAIT 
        local tId = api.Unit:GetUnitId("target")
        local targetDead = false

        local hp = api.Unit:UnitHealth("target")
        if tId and tId ~= "0" and (not hp or hp <= 0) then targetDead = true end

        if targetDead then
             -- Only shorten timeout if no other active outgoing targets
             local hasOtherTargets = false
             for id, _ in pairs(fightData.outgoing) do
                 if tostring(id) ~= tostring(tId) then hasOtherTargets = true; break end
             end
             currentTimeoutLimit = hasOtherTargets and CONFIG.COMBAT_WAIT or 2000
        elseif tId and activeCCSessions[tId] and next(activeCCSessions[tId]) ~= nil then
             currentTimeoutLimit = 10000 
             for buffName, startTime in pairs(activeCCSessions[tId]) do
                 if (now - startTime) > 45000 then activeCCSessions[tId][buffName] = nil end
             end
        end

        if timeSinceLastAction >= currentTimeoutLimit then FinishFight() end
    end

    for key, data in pairs(activeDots) do
        data.timer = (data.timer or 0) + elapsed
        if data.timer >= CONFIG.DOT_WAIT then
            LogEntry(string.format("[Total] %s (%s): %d (%d hits)", data.skill, data.target, data.dmg, data.hits), 1, 0.6, 0)
            activeDots[key] = nil
        end
    end
end

-- ============================================================================
--  OPTIONS WINDOW (UI REDESIGN & CENTERED)
-- ============================================================================

local function CreateOptionsWindow()
    wOptions = api.Interface:CreateEmptyWindow("OpWin", "UIParent")
    wOptions:Show(false); wOptions:SetExtent(380, 560); wOptions:AddAnchor("CENTER", "UIParent", 0, 0); MakeDraggable(wOptions, wOptions)
    
    CreateBackdrop(wOptions, {0.05, 0.05, 0.05, 0.95})
    
    local opTitleBar = wOptions:CreateChildWidget("emptywidget", "TBar", 0, true)
    opTitleBar:AddAnchor("TOPLEFT", wOptions, 0, 0); opTitleBar:AddAnchor("TOPRIGHT", wOptions, 0, 0); opTitleBar:SetHeight(30)
    CreateBackdrop(opTitleBar, COL_HEADER)
    
    local opTitle = opTitleBar:CreateChildWidget("label", "T", 0, true)
    opTitle:SetText("CLP Configuration"); opTitle:AddAnchor("CENTER", opTitleBar, 0, 0)
    if opTitle.style then opTitle.style:SetFontSize(16) end; MakeDraggable(opTitleBar, wOptions)

    -- === SECTION 1: WINDOW SIZE ===
    local lblSec1 = wOptions:CreateChildWidget("label", "Sec1", 0, true)
    lblSec1:SetText("Window Size")
    lblSec1:AddAnchor("TOP", wOptions, 0, 45)
    if lblSec1.style then lblSec1.style:SetColor(0.5, 0.8, 1, 1); lblSec1.style:SetAlign(ALIGN.CENTER) end

    -- Width Control
    local btnWDec = wOptions:CreateChildWidget("button", "WDec", 0, true); btnWDec:SetText("-"); btnWDec:SetExtent(30, 24); btnWDec:AddAnchor("TOPLEFT", wOptions, 80, 75)
    lblWVal = wOptions:CreateChildWidget("label", "LWV", 0, true); lblWVal:SetText("W: " .. CONFIG.LIVE_WIDTH); lblWVal:SetExtent(100, 24); lblWVal:AddAnchor("LEFT", btnWDec, "RIGHT", 5, 0); if lblWVal.style then lblWVal.style:SetAlign(ALIGN.CENTER) end
    local btnWInc = wOptions:CreateChildWidget("button", "WInc", 0, true); btnWInc:SetText("+"); btnWInc:SetExtent(30, 24); btnWInc:AddAnchor("LEFT", lblWVal, "RIGHT", 5, 0)
    
    -- Height Control
    local btnHDec = wOptions:CreateChildWidget("button", "HDec", 0, true); btnHDec:SetText("-"); btnHDec:SetExtent(30, 24); btnHDec:AddAnchor("TOPLEFT", wOptions, 80, 105)
    lblHVal = wOptions:CreateChildWidget("label", "LHV", 0, true); lblHVal:SetText("H: " .. CONFIG.LIVE_HEIGHT); lblHVal:SetExtent(100, 24); lblHVal:AddAnchor("LEFT", btnHDec, "RIGHT", 5, 0); if lblHVal.style then lblHVal.style:SetAlign(ALIGN.CENTER) end
    local btnHInc = wOptions:CreateChildWidget("button", "HInc", 0, true); btnHInc:SetText("+"); btnHInc:SetExtent(30, 24); btnHInc:AddAnchor("LEFT", lblHVal, "RIGHT", 5, 0)

    btnWDec:SetHandler("OnClick", function() CONFIG.LIVE_WIDTH = math.max(300, CONFIG.LIVE_WIDTH - 20); lblWVal:SetText("W: " .. CONFIG.LIVE_WIDTH); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)
    btnWInc:SetHandler("OnClick", function() CONFIG.LIVE_WIDTH = math.min(800, CONFIG.LIVE_WIDTH + 20); lblWVal:SetText("W: " .. CONFIG.LIVE_WIDTH); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)
    btnHDec:SetHandler("OnClick", function() CONFIG.LIVE_HEIGHT = math.max(200, CONFIG.LIVE_HEIGHT - 20); lblHVal:SetText("H: " .. CONFIG.LIVE_HEIGHT); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)
    btnHInc:SetHandler("OnClick", function() CONFIG.LIVE_HEIGHT = math.min(800, CONFIG.LIVE_HEIGHT + 20); lblHVal:SetText("H: " .. CONFIG.LIVE_HEIGHT); liveLayoutDirty = true; RebuildLiveLabels(); SaveSettings() end)

    -- === SECTION 2: FEATURES ===
    local lblSec2 = wOptions:CreateChildWidget("label", "Sec2", 0, true)
    lblSec2:SetText("Features")
    lblSec2:AddAnchor("TOP", wOptions, 0, 150)
    if lblSec2.style then lblSec2.style:SetColor(0.5, 0.8, 1, 1); lblSec2.style:SetAlign(ALIGN.CENTER) end

    -- Scanner Toggle
    btnScanToggle = wOptions:CreateChildWidget("button", "ScanTog", 0, true)
    btnScanToggle:SetText(CONFIG.ENABLE_SCANNER and "Scan Debuffs: ON" or "Scan Debuffs: OFF")
    btnScanToggle:SetExtent(240, 24); btnScanToggle:AddAnchor("TOP", wOptions, 0, 180)
    btnScanToggle:SetTextColor(CONFIG.ENABLE_SCANNER and 0 or 1, CONFIG.ENABLE_SCANNER and 1 or 0, 0, 1)
    btnScanToggle:SetHandler("OnClick", function() 
        CONFIG.ENABLE_SCANNER = not CONFIG.ENABLE_SCANNER
        btnScanToggle:SetText(CONFIG.ENABLE_SCANNER and "Scan Debuffs: ON" or "Scan Debuffs: OFF")
        btnScanToggle:SetTextColor(CONFIG.ENABLE_SCANNER and 0 or 1, CONFIG.ENABLE_SCANNER and 1 or 0, 0, 1)
    end)

    -- Timestamp Toggle
    btnTimeToggle = wOptions:CreateChildWidget("button", "TimeTog", 0, true)
    btnTimeToggle:SetText(CONFIG.SHOW_TIMESTAMP and "Timestamps: ON" or "Timestamps: OFF")
    btnTimeToggle:SetExtent(240, 24); btnTimeToggle:AddAnchor("TOP", wOptions, 0, 210)
    btnTimeToggle:SetTextColor(CONFIG.SHOW_TIMESTAMP and 0 or 1, CONFIG.SHOW_TIMESTAMP and 1 or 0, 0, 1)
    btnTimeToggle:SetHandler("OnClick", function() 
        CONFIG.SHOW_TIMESTAMP = not CONFIG.SHOW_TIMESTAMP
        btnTimeToggle:SetText(CONFIG.SHOW_TIMESTAMP and "Timestamps: ON" or "Timestamps: OFF")
        btnTimeToggle:SetTextColor(CONFIG.SHOW_TIMESTAMP and 0 or 1, CONFIG.SHOW_TIMESTAMP and 1 or 0, 0, 1)
        RebuildLiveLabels(); UpdateHistoryDisplay()
    end)

    -- Static Shock Filter Toggle
    btnSSFilterToggle = wOptions:CreateChildWidget("button", "SSFiltTog", 0, true)
    btnSSFilterToggle:SetText(CONFIG.FILTER_STATIC_SHOCK and "Filter Electric Shock Spam: ON" or "Filter Electric Shock Spam: OFF")
    btnSSFilterToggle:SetExtent(240, 24); btnSSFilterToggle:AddAnchor("TOP", wOptions, 0, 240)
    btnSSFilterToggle:SetTextColor(CONFIG.FILTER_STATIC_SHOCK and 0 or 1, CONFIG.FILTER_STATIC_SHOCK and 1 or 0, 0, 1)
    btnSSFilterToggle:SetHandler("OnClick", function()
        CONFIG.FILTER_STATIC_SHOCK = not CONFIG.FILTER_STATIC_SHOCK
        btnSSFilterToggle:SetText(CONFIG.FILTER_STATIC_SHOCK and "Filter Electric Shock Spam: ON" or "Filter Electric Shock Spam: OFF")
        btnSSFilterToggle:SetTextColor(CONFIG.FILTER_STATIC_SHOCK and 0 or 1, CONFIG.FILTER_STATIC_SHOCK and 1 or 0, 0, 1)
    end)

    -- Time Offset Control
    local btnOffDec = wOptions:CreateChildWidget("button", "OffDec", 0, true); btnOffDec:SetText("-"); btnOffDec:SetExtent(30, 24); btnOffDec:AddAnchor("TOPLEFT", wOptions, 80, 270)
    lblOffVal = wOptions:CreateChildWidget("label", "OffVal", 0, true); lblOffVal:SetText("Offset: " .. CONFIG.TIME_OFFSET .. "h"); lblOffVal:SetExtent(100, 24); lblOffVal:AddAnchor("LEFT", btnOffDec, "RIGHT", 5, 0); if lblOffVal.style then lblOffVal.style:SetAlign(ALIGN.CENTER) end
    local btnOffInc = wOptions:CreateChildWidget("button", "OffInc", 0, true); btnOffInc:SetText("+"); btnOffInc:SetExtent(30, 24); btnOffInc:AddAnchor("LEFT", lblOffVal, "RIGHT", 5, 0)

    btnOffDec:SetHandler("OnClick", function() CONFIG.TIME_OFFSET = CONFIG.TIME_OFFSET - 1; lblOffVal:SetText("Offset: " .. CONFIG.TIME_OFFSET .. "h"); RebuildLiveLabels(); UpdateHistoryDisplay() end)
    btnOffInc:SetHandler("OnClick", function() CONFIG.TIME_OFFSET = CONFIG.TIME_OFFSET + 1; lblOffVal:SetText("Offset: " .. CONFIG.TIME_OFFSET .. "h"); RebuildLiveLabels(); UpdateHistoryDisplay() end)

    -- Scan Frequency Control (ms between each debuff/buff scanner tick)
    local btnSFDec = wOptions:CreateChildWidget("button", "SFDec", 0, true); btnSFDec:SetText("-"); btnSFDec:SetExtent(30, 24); btnSFDec:AddAnchor("TOPLEFT", wOptions, 80, 300)
    lblScanFreqVal = wOptions:CreateChildWidget("label", "SFVal", 0, true); lblScanFreqVal:SetText("Scan: " .. CONFIG.SCAN_FREQ .. "ms"); lblScanFreqVal:SetExtent(100, 24); lblScanFreqVal:AddAnchor("LEFT", btnSFDec, "RIGHT", 5, 0); if lblScanFreqVal.style then lblScanFreqVal.style:SetAlign(ALIGN.CENTER) end
    local btnSFInc = wOptions:CreateChildWidget("button", "SFInc", 0, true); btnSFInc:SetText("+"); btnSFInc:SetExtent(30, 24); btnSFInc:AddAnchor("LEFT", lblScanFreqVal, "RIGHT", 5, 0)

    btnSFDec:SetHandler("OnClick", function() CONFIG.SCAN_FREQ = math.max(100, CONFIG.SCAN_FREQ - 50); lblScanFreqVal:SetText("Scan: " .. CONFIG.SCAN_FREQ .. "ms"); SaveSettings() end)
    btnSFInc:SetHandler("OnClick", function() CONFIG.SCAN_FREQ = math.min(1000, CONFIG.SCAN_FREQ + 50); lblScanFreqVal:SetText("Scan: " .. CONFIG.SCAN_FREQ .. "ms"); SaveSettings() end)

    -- === SECTION 3: COLORS ===
    local lblSec3 = wOptions:CreateChildWidget("label", "Sec3", 0, true)
    lblSec3:SetText("Color Theme")
    lblSec3:AddAnchor("TOP", wOptions, 0, 340)
    if lblSec3.style then lblSec3.style:SetColor(0.5, 0.8, 1, 1); lblSec3.style:SetAlign(ALIGN.CENTER) end

    local function CreateColorOption(id, label, configKey, yOffset)
        local l = wOptions:CreateChildWidget("label", "CL"..id, 0, true); l:SetText(label); l:AddAnchor("TOPLEFT", wOptions, 40, yOffset); l:SetExtent(140, 24)
        local b = wOptions:CreateChildWidget("button", "CB"..id, 0, true); b:SetText(CONFIG[configKey]); b:SetExtent(120, 24); b:AddAnchor("LEFT", l, "RIGHT", 20, 0)
        local c = GetSafeColor(CONFIG[configKey]); b:SetTextColor(c[1], c[2], c[3], 1)
        b:SetHandler("OnClick", function() local nextCol = GetNextColorName(CONFIG[configKey]); CONFIG[configKey] = nextCol; b:SetText(nextCol); local nc = GetSafeColor(nextCol); b:SetTextColor(nc[1], nc[2], nc[3], 1) end)
        return b
    end

    CreateColorOption(1, "Outgoing Dmg", "COL_OUT_NRM", 370)
    CreateColorOption(2, "Critical Hits", "COL_OUT_CRIT", 400)
    CreateColorOption(3, "Incoming Dmg", "COL_INCOMING", 430)
    CreateColorOption(4, "Healing", "COL_HEAL", 460)
    CreateColorOption(5, "CC Effects", "COL_CC", 490)
    
    local btnClose = wOptions:CreateChildWidget("button", "Close", 0, true); btnClose:SetText("Done"); btnClose:SetExtent(120, 30); btnClose:AddAnchor("BOTTOM", wOptions, 0, -20)
    btnClose:SetHandler("OnClick", function() wOptions:Show(false) end)
end

local function Load()
    local myId = api.Unit:GetUnitId("player")
    PLAYER_NAME = api.Unit:GetUnitNameById(myId)
    if not PLAYER_NAME or PLAYER_NAME == "" then PLAYER_NAME = "Unknown" end

    BASE_SECONDS_OF_DAY = 0
    BASE_APP_MSEC = 0
    TIME_INITIALIZED = false
    LoadSavedSettings()

    -- === SMALL TOGGLE BUTTON (always visible, Shift+Drag to move) ===
    wButton = api.Interface:CreateEmptyWindow("CLPBtn", "UIParent")
    wButton:Show(true)
    wButton:SetExtent(50, 24)
    if savedSettings.btnX then
        wButton:AddAnchor("TOPLEFT", "UIParent", savedSettings.btnX, savedSettings.btnY)
    else
        wButton:AddAnchor("LEFT", "UIParent", 20, -100)
    end
    CreateBackdrop(wButton, {0.15, 0.15, 0.15, 0.9})

    local toggleBtn = wButton:CreateChildWidget("button", "Toggle", 0, true)
    toggleBtn:AddAnchor("TOPLEFT", wButton, 0, 0)
    toggleBtn:AddAnchor("BOTTOMRIGHT", wButton, 0, 0)
    toggleBtn:SetText("CLP")
    toggleBtn:SetTextColor(0, 1, 0, 1)
    MakeDraggable(toggleBtn, wButton, SaveSettings)

    -- === LIVE LOG WINDOW (detached, toggled by button or X) ===
    wLive = api.Interface:CreateEmptyWindow("LiveWin", "UIParent")
    wLive:Show(true)
    wLive:SetExtent(CONFIG.LIVE_WIDTH, CONFIG.LIVE_HEIGHT)
    if savedSettings.liveX then
        wLive:AddAnchor("TOPLEFT", "UIParent", savedSettings.liveX, savedSettings.liveY)
    else
        wLive:AddAnchor("LEFT", "UIParent", 80, 0)
    end
    MakeDraggable(wLive, wLive, SaveSettings)

    local liveHeader = wLive:CreateChildWidget("emptywidget", "lHeader", 0, true)
    liveHeader:AddAnchor("TOPLEFT", wLive, 0, 0)
    liveHeader:AddAnchor("TOPRIGHT", wLive, 0, 0)
    liveHeader:SetHeight(30)
    CreateBackdrop(liveHeader, COL_HEADER)
    MakeDraggable(liveHeader, wLive, SaveSettings)

    liveTitleLabel = liveHeader:CreateChildWidget("label", "Title", 0, true)
    liveTitleLabel:AddAnchor("LEFT", liveHeader, 10, 0)
    liveTitleLabel:SetExtent(200, 20)
    liveTitleLabel:SetText("Combat Log [Idle]")
    if liveTitleLabel.style then liveTitleLabel.style:SetAlign(ALIGN.LEFT); liveTitleLabel.style:SetColor(0.7, 0.7, 0.7, 1) end
    MakeDraggable(liveTitleLabel, wLive, SaveSettings)

    local btnHide = liveHeader:CreateChildWidget("button", "btnHide", 0, true)
    btnHide:AddAnchor("RIGHT", liveHeader, -5, 0)
    btnHide:SetExtent(24, 24)
    btnHide:SetText("X")
    btnHide:SetHandler("OnClick", function()
        wLive:Show(false)
        isMinimized = true
        toggleBtn:SetTextColor(0.5, 0.5, 0.5, 1)
    end)

    local btnOp = liveHeader:CreateChildWidget("button", "btnOp", 0, true)
    btnOp:AddAnchor("RIGHT", btnHide, "LEFT", -5, 0)
    btnOp:SetExtent(60, 24)
    btnOp:SetText("Options")
    btnOp:SetHandler("OnClick", function() if not wOptions then CreateOptionsWindow() end; wOptions:Show(not wOptions:IsVisible()) end)

    local btnHist = liveHeader:CreateChildWidget("button", "btnHist", 0, true)
    btnHist:AddAnchor("RIGHT", btnOp, "LEFT", -5, 0)
    btnHist:SetExtent(60, 24)
    btnHist:SetText("History")
    btnHist:SetHandler("OnClick", function() wHistory:Show(not wHistory:IsVisible()); UpdateHistoryDisplay(); UpdateSessionList() end)

    liveBodyWidget = wLive:CreateChildWidget("emptywidget", "lBody", 0, true)
    liveBodyWidget:AddAnchor("TOPLEFT", liveHeader, "BOTTOMLEFT", 0, 0)
    liveBodyWidget:AddAnchor("BOTTOMRIGHT", wLive, 0, 0)
    CreateBackdrop(liveBodyWidget, COL_BODY)
    MakeDraggable(liveBodyWidget, wLive, SaveSettings)
    RebuildLiveLabels()

    -- Toggle button click handler (set after wLive exists)
    toggleBtn:SetHandler("OnClick", function()
        if wLive:IsVisible() then
            wLive:Show(false)
            isMinimized = true
            toggleBtn:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            wLive:Show(true)
            isMinimized = false
            toggleBtn:SetTextColor(0, 1, 0, 1)
        end
    end)

    -- === HISTORY WINDOW ===
    wHistory = api.Interface:CreateEmptyWindow("HistWin", "UIParent")
    wHistory:Show(false)
    wHistory:SetExtent(CONFIG.HIST_WIDTH, CONFIG.HIST_HEIGHT)
    wHistory:AddAnchor("CENTER", "UIParent", 0, 0)

    local histHeader = wHistory:CreateChildWidget("emptywidget", "hHeader", 0, true)
    histHeader:AddAnchor("TOPLEFT", wHistory, 0, 0)
    histHeader:AddAnchor("TOPRIGHT", wHistory, 0, 0)
    histHeader:SetHeight(30)
    CreateBackdrop(histHeader, COL_HEADER)
    MakeDraggable(histHeader, wHistory)
    local histTitle = histHeader:CreateChildWidget("label", "hTitle", 0, true)
    histTitle:SetText("Session History")
    histTitle:AddAnchor("CENTER", histHeader, 0, 0)
    if histTitle.style then histTitle.style:SetFontSize(15) end
    MakeDraggable(histTitle, wHistory)
    local btnClose = histHeader:CreateChildWidget("button", "close", 0, true)
    btnClose:AddAnchor("RIGHT", histHeader, -5, 0)
    btnClose:SetExtent(30, 24)
    btnClose:SetText("X")
    btnClose:SetHandler("OnClick", function() wHistory:Show(false) end)

    local histSidebar = wHistory:CreateChildWidget("emptywidget", "hSide", 0, true)
    histSidebar:AddAnchor("TOPLEFT", histHeader, "BOTTOMLEFT", 0, 0)
    histSidebar:SetExtent(CONFIG.SIDEBAR_WIDTH, CONFIG.HIST_HEIGHT - 30)
    CreateBackdrop(histSidebar, COL_SIDEBAR)
    histSidebar:EnableDrag(true)
    histSidebar:SetHandler("OnMouseWheel", function(self, d) ScrollSession(d) end)

    lblSessionCount = histSidebar:CreateChildWidget("label", "lblCount", 0, true)
    lblSessionCount:SetText("Saved: 0")
    lblSessionCount:AddAnchor("TOP", histSidebar, 0, 5)
    if lblSessionCount.style then lblSessionCount.style:SetAlign(ALIGN.CENTER); lblSessionCount.style:SetColor(0.6, 0.6, 0.6, 1) end

    local btnLive = histSidebar:CreateChildWidget("button", "btnLive", 0, true)
    btnLive:AddAnchor("TOP", histSidebar, 0, 30)
    btnLive:SetExtent(CONFIG.BUTTON_WIDTH, 30)
    btnLive:SetText(">> LIVE LOG <<")
    btnLive:SetHandler("OnClick", function() viewingMode = "LIVE"; displayBuffer = {}; for _,v in ipairs(masterBuffer) do table.insert(displayBuffer, v) end; logScrollOffset = #displayBuffer - CONFIG.VISIBLE_ROWS_HIST; if logScrollOffset < 0 then logScrollOffset = 0 end; UpdateHistoryDisplay() end)

    for i = 1, CONFIG.SESSIONS_VISIBLE do
        local btn = histSidebar:CreateChildWidget("button", "SessBtn"..i, 0, true)
        btn:SetExtent(CONFIG.BUTTON_WIDTH, 24)
        btn:AddAnchor("TOP", histSidebar, 0, 70 + ((i-1)*28))
        btn:SetText("")
        btn:Show(false)
        btn:SetHandler("OnClick", function(self)
            local sess = allSessions[self.sessionIndex]
            if not sess then return end
            viewingMode = "ARCHIVE"
            displayBuffer = sess.logs
            logScrollOffset = math.max(0, #displayBuffer - CONFIG.VISIBLE_ROWS_HIST)
            UpdateHistoryDisplay()
        end)
        btn:SetHandler("OnMouseWheel", function(self, d) ScrollSession(d) end)
        sessionButtons[i] = btn
    end

    local btnClear = histSidebar:CreateChildWidget("button", "btnClear", 0, true)
    btnClear:AddAnchor("BOTTOM", histSidebar, 0, -10)
    btnClear:SetExtent(CONFIG.BUTTON_WIDTH, 24)
    btnClear:SetText("CLEAR ALL")
    if btnClear.style then btnClear.style:SetColor(COL_BTN_RED[1], COL_BTN_RED[2], COL_BTN_RED[3], 1) end
    btnClear:SetHandler("OnClick", ClearAll)
    local btnSessUp = histSidebar:CreateChildWidget("button", "btnSUp", 0, true)
    btnSessUp:AddAnchor("TOPRIGHT", histSidebar, -5, 70)
    btnSessUp:SetExtent(24, 40)
    btnSessUp:SetText("^")
    btnSessUp:SetHandler("OnClick", function() ScrollSession(1) end)
    local btnSessDown = histSidebar:CreateChildWidget("button", "btnSDown", 0, true)
    btnSessDown:AddAnchor("BOTTOMRIGHT", histSidebar, -5, -40)
    btnSessDown:SetExtent(24, 40)
    btnSessDown:SetText("v")
    btnSessDown:SetHandler("OnClick", function() ScrollSession(-1) end)

    local histBody = wHistory:CreateChildWidget("emptywidget", "hBody", 0, true)
    histBody:AddAnchor("TOPLEFT", histSidebar, "TOPRIGHT", 0, 0)
    histBody:AddAnchor("BOTTOMRIGHT", wHistory, 0, 0)
    CreateBackdrop(histBody, COL_LOG_BG)
    for i = 1, CONFIG.VISIBLE_ROWS_HIST do
        local btn = histBody:CreateChildWidget("label", "HL"..i, 0, true)
        btn:SetExtent(CONFIG.HIST_WIDTH - CONFIG.SIDEBAR_WIDTH - 30, CONFIG.LINE_HEIGHT)
        btn:AddAnchor("TOPLEFT", histBody, 20, 10 + ((i-1) * CONFIG.LINE_HEIGHT))
        if btn.SetLimitWidth then btn:SetLimitWidth(true) end
        if btn.style then
            btn.style:SetAlign(ALIGN.LEFT)
            btn.style:SetShadow(true)
            btn.style:SetEllipsis(true)
        end
        historyLabels[i] = btn
    end
    local btnUp = histBody:CreateChildWidget("button", "bUp", 0, true)
    btnUp:AddAnchor("TOPRIGHT", histBody, -5, 5)
    btnUp:SetExtent(24, 40)
    btnUp:SetText("^")
    btnUp:SetHandler("OnClick", ScrollLogUp)
    local btnDown = histBody:CreateChildWidget("button", "bDown", 0, true)
    btnDown:AddAnchor("BOTTOMRIGHT", histBody, -5, -5)
    btnDown:SetExtent(24, 40)
    btnDown:SetText("v")
    btnDown:SetHandler("OnClick", ScrollLogDown)
    histBody:EnableDrag(true)
    histBody:SetHandler("OnMouseWheel", function(self, d) if d>0 then ScrollLogUp() else ScrollLogDown() end end)

    -- Events on the always-visible button so combat tracking works when log is hidden
    wButton:SetHandler("OnEvent", OnLiveEvent)
    wButton:SetHandler("OnUpdate", OnLiveUpdate)
    wButton:RegisterEvent("COMBAT_MSG")
    wButton:RegisterEvent("UNIT_COMBAT_STATE_CHANGED")
    wButton:RegisterEvent("TARGET_CHANGED")           -- patch 243+: instant target tracking
    wButton:RegisterEvent("TARGET_TO_TARGET_CHANGED") -- patch 243+: live enemy-targeting-player state
    wButton:RegisterEvent("SPELLCAST_START")          -- patch 243+: cast began
    wButton:RegisterEvent("SPELLCAST_SUCCEEDED")      -- patch 243+: cast completed
    wButton:RegisterEvent("SPELLCAST_STOP")           -- patch 243+: cast interrupted/cancelled
    LogEntry("CombatLogPro v46.0 Loaded (" .. PLAYER_NAME .. ")", 0, 1, 0)
end

local function Unload()
    SaveSettings()
    if wButton then wButton:Show(false); wButton = nil end
    if wLive then wLive:Show(false); wLive = nil end
    if wHistory then wHistory:Show(false); wHistory = nil end
    if wOptions then wOptions:Show(false); wOptions = nil end
end

addon.OnLoad = Load; addon.OnUnload = Unload; return addon
