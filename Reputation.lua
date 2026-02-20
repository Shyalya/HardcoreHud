local H = HardcoreHUD

-- ============================================================================
-- Reputation Tracker
-- Tracks reputation progress and calculates mobs needed for next standing
-- ============================================================================

-- Reputation standings and their point ranges
local REP_STANDINGS = {
  { name = "Hated",      minRep = -42000, maxRep = -6001 },
  { name = "Hostile",    minRep = -6000,  maxRep = -3001 },
  { name = "Unfriendly", minRep = -3000,  maxRep = -1 },
  { name = "Neutral",    minRep = 0,      maxRep = 2999 },
  { name = "Friendly",   minRep = 3000,   maxRep = 5999 },
  { name = "Honored",    minRep = 6000,   maxRep = 11999 },
  { name = "Revered",    minRep = 12000,  maxRep = 20999 },
  { name = "Exalted",    minRep = 21000,  maxRep = 42000 },
}

-- Common Classic Era reputation factions with their mob rep values
-- Format: [factionName] = { factionID = id, mobs = { {name, rep}, ... }, items = { {name, rep, stackSize}, ... } }
local FACTION_DATA = {
  ["Timbermaw Hold"] = {
    factionID = 576,
    mobRep = 10, -- Standard mob gives ~10 rep (Winterfall/Deadwood)
    mobs = {
      { name = "Deadwood Furbolg", rep = 10 },
      { name = "Winterfall Furbolg", rep = 10 },
    },
    turnins = {
      { name = "Deadwood Headdress Feather (5x)", rep = 50 },
      { name = "Winterfall Spirit Beads (5x)", rep = 50 },
    }
  },
  ["Argent Dawn"] = {
    factionID = 529,
    mobRep = 10,
    mobs = {
      { name = "Undead in Plaguelands", rep = 10 },
      { name = "Scourge in Scholomance", rep = 10 },
      { name = "Scourge in Stratholme", rep = 15 },
    },
    turnins = {
      { name = "Bone Fragments (30x)", rep = 25 },
      { name = "Crypt Fiend Parts (30x)", rep = 25 },
      { name = "Dark Iron Scraps (30x)", rep = 25 },
      { name = "Scourgestones", rep = 25 },
    }
  },
  ["Thorium Brotherhood"] = {
    factionID = 59,
    mobRep = 0, -- Rep from turnins only
    mobs = {},
    turnins = {
      { name = "Dark Iron Ore (10x)", rep = 75 },
      { name = "Fiery Core", rep = 500 },
      { name = "Lava Core", rep = 500 },
    }
  },
  ["Cenarion Circle"] = {
    factionID = 609,
    mobRep = 10,
    mobs = {
      { name = "Twilight Cultist (Silithus)", rep = 10 },
      { name = "AQ20/40 Mobs", rep = 10 },
    },
    turnins = {
      { name = "Twilight Text (10x)", rep = 100 },
      { name = "Encrypted Twilight Text (10x)", rep = 500 },
    }
  },
  ["Hydraxian Waterlords"] = {
    factionID = 749,
    mobRep = 25,
    mobs = {
      { name = "Molten Core Trash", rep = 25 },
      { name = "MC Bosses (through Honored)", rep = 100 },
    },
    turnins = {}
  },
  ["Zandalar Tribe"] = {
    factionID = 270,
    mobRep = 10,
    mobs = {
      { name = "ZG Trash", rep = 5 },
      { name = "ZG Bosses", rep = 100 },
    },
    turnins = {
      { name = "Bijou", rep = 75 },
      { name = "Coin Sets (3x)", rep = 25 },
    }
  },
  ["Brood of Nozdormu"] = {
    factionID = 910,
    mobRep = 100,
    mobs = {
      { name = "AQ40 Trash/Bosses", rep = 100 },
    },
    turnins = {}
  },
  ["Wintersaber Trainers"] = {
    factionID = 589,
    mobRep = 0,
    mobs = {},
    turnins = {
      { name = "Quest: Frostsaber Provisions", rep = 50 },
      { name = "Quest: Winterfall Intrusion", rep = 50 },
      { name = "Quest: Rampaging Giants", rep = 50 },
    }
  },
  ["Bloodsail Buccaneers"] = {
    factionID = 87,
    mobRep = 25,
    mobs = {
      { name = "Booty Bay Bruiser", rep = 25 },
      { name = "Booty Bay NPCs", rep = 5 },
    },
    turnins = {}
  },
  ["Darkmoon Faire"] = {
    factionID = 909,
    mobRep = 0,
    mobs = {},
    turnins = {
      { name = "Darkmoon Faire Tickets", rep = 50 },
      { name = "Decks (Beasts/Elementals/etc)", rep = 25 },
    }
  },
}

-- Get faction list for dropdown
function H.GetReputationFactionList()
  local list = {}
  for name, _ in pairs(FACTION_DATA) do
    table.insert(list, name)
  end
  table.sort(list)
  return list
end

-- Capital substring list for detection
local CAPITAL_SUBSTRINGS = { "stormwind", "ironforge", "darnassus", "gadgetzan", "orgrimmar", "thunder bluff", "undercity", "silvermoon", "ratchet" }

function H.IsCapital(name)
  if not name then return false end
  local n = string.lower(name)
  for _, sub in ipairs(CAPITAL_SUBSTRINGS) do
    if string.find(n, sub, 1, true) then return true end
  end
  return false
end

-- Get all tracked factions from the character's reputation panel
function H.GetCharacterFactions()
  local factions = {}
  local numFactions = GetNumFactions() or 0
  for i = 1, numFactions do
    local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i)
    if name and not isHeader then
      factions[name] = {
        index = i,
        standingID = standingID,
        barMin = barMin,
        barMax = barMax,
        barValue = barValue,
        isWatched = isWatched,
      }
    end
  end
  return factions
end

-- Get current reputation info for a faction
function H.GetReputationInfo(factionName)
  local numFactions = GetNumFactions() or 0
  for i = 1, numFactions do
    local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i)
    if name == factionName then
      local standingName = GetText("FACTION_STANDING_LABEL" .. standingID, UnitSex("player"))
      local currentRep = barValue - barMin
      local maxRep = barMax - barMin
      return {
        name = factionName,
        standingID = standingID,
        standingName = standingName or "Unknown",
        currentRep = currentRep,
        maxRep = maxRep,
        totalRep = barValue,
        barMin = barMin,
        barMax = barMax,
      }
    end
  end
  return nil
end

-- Calculate mobs needed to reach next standing
function H.CalculateMobsNeeded(factionName, repPerMob)
  local info = H.GetReputationInfo(factionName)
  if not info then return nil end
  
  if info.standingID >= 8 then
    -- Already Exalted
    return {
      current = info.currentRep,
      max = info.maxRep,
      repNeeded = 0,
      mobsNeeded = 0,
      standingName = info.standingName,
      nextStanding = "Exalted (Max)",
      isExalted = true,
    }
  end
  
  repPerMob = repPerMob or 10
  local repNeeded = info.maxRep - info.currentRep
  local mobsNeeded = math.ceil(repNeeded / repPerMob)
  
  local nextStanding = REP_STANDINGS[info.standingID + 1]
  
  return {
    current = info.currentRep,
    max = info.maxRep,
    repNeeded = repNeeded,
    mobsNeeded = mobsNeeded,
    standingName = info.standingName,
    standingID = info.standingID,
    nextStanding = nextStanding and nextStanding.name or "Unknown",
    isExalted = false,
    repPerMob = repPerMob,
  }
end

-- Initialize Reputation Tracker UI
function H.InitReputationTracker()
  if H.reputationTracker then return end
  
  HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {
    enabled = false,
    selectedFaction = "Timbermaw Hold",
    customRepPerMob = 10,
    showBar = true,
    showMobsNeeded = true,
    showRepPerMob = true,
    showCapital = true,
    locked = false,
    pos = { x = 200, y = -350 },
  }
  
  local opts = HardcoreHUDDB.reputation
  
  local f = CreateFrame("Frame", "HardcoreHUDReputationTracker", UIParent)
  H.reputationTracker = f
  f:SetSize(280, 75)
  f:SetPoint("CENTER", UIParent, "CENTER", opts.pos.x or 200, opts.pos.y or -350)
  f:SetFrameStrata("HIGH")
  f:Hide()
  
  -- Background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0, 0, 0, 0.6)
  f.bg = bg
  
  -- Thin border
  local function addBorder(frame)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    t:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 1, -1)
    t:SetColorTexture(0.3, 0.3, 0.3, 1)
    local b = frame:CreateTexture(nil, "BORDER")
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, 1)
    b:SetColorTexture(0.3, 0.3, 0.3, 1)
    local l = frame:CreateTexture(nil, "BORDER")
    l:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1)
    l:SetWidth(1)
    l:SetColorTexture(0.3, 0.3, 0.3, 1)
    local r = frame:CreateTexture(nil, "BORDER")
    r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
    r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    r:SetWidth(1)
    r:SetColorTexture(0.3, 0.3, 0.3, 1)
  end
  addBorder(f)
  
  -- Title/Faction Name
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
  title:SetText("REPUTATION")
  title:SetTextColor(0.8, 0.6, 1, 1)  -- Purple-ish for reputation
  if STANDARD_TEXT_FONT then title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE") end
  f.title = title
  
  -- Faction Name
  local factionText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  factionText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  factionText:SetText("Timbermaw Hold")
  factionText:SetTextColor(1, 0.84, 0, 1)  -- Gold
  if STANDARD_TEXT_FONT then factionText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE") end
  f.factionText = factionText
  
  -- Rep Bar
  local repBar = CreateFrame("StatusBar", nil, f)
  repBar:SetSize(268, 14)
  repBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -24)
  repBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  repBar:SetMinMaxValues(0, 100)
  repBar:SetValue(50)
  repBar:SetStatusBarColor(0.6, 0.2, 0.8, 0.9)  -- Purple
  
  local repBarBg = repBar:CreateTexture(nil, "BACKGROUND")
  repBarBg:SetAllPoints(repBar)
  repBarBg:SetColorTexture(0.08, 0.02, 0.1, 0.9)
  f.repBar = repBar
  
  -- Standing Text (on bar)
  local standingText = repBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  standingText:SetPoint("LEFT", repBar, "LEFT", 4, 0)
  standingText:SetText("Friendly")
  standingText:SetTextColor(1, 1, 1, 1)
  if STANDARD_TEXT_FONT then standingText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE") end
  f.standingText = standingText
  
  -- Rep Progress Text (on bar, right side)
  local repText = repBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  repText:SetPoint("RIGHT", repBar, "RIGHT", -4, 0)
  repText:SetText("1234 / 6000")
  repText:SetTextColor(1, 1, 1, 1)
  if STANDARD_TEXT_FONT then repText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE") end
  f.repText = repText
  
  -- Mobs Needed Info
  local mobsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  mobsText:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -44)
  mobsText:SetText("~450 mobs to Honored (10 rep/mob)")
  mobsText:SetTextColor(0.9, 0.8, 1, 0.9)
  if STANDARD_TEXT_FONT then mobsText:SetFont(STANDARD_TEXT_FONT, 10, "") end
  f.mobsText = mobsText
  
  -- Additional Info (turnins etc)
  local infoText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  infoText:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -58)
  infoText:SetText("")
  infoText:SetTextColor(0.7, 0.7, 0.7, 0.8)
  if STANDARD_TEXT_FONT then infoText:SetFont(STANDARD_TEXT_FONT, 9, "") end
  f.infoText = infoText

  -- Capital runecloth requirement text
  local capitalText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  capitalText:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -74)
  capitalText:SetText("")
  capitalText:SetTextColor(0.8, 0.7, 1, 0.95)
  if STANDARD_TEXT_FONT then capitalText:SetFont(STANDARD_TEXT_FONT, 9, "") end
  f.capitalText = capitalText
  
  -- Make draggable
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not HardcoreHUDDB.reputation.locked then
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local px, py = UIParent:GetCenter()
    HardcoreHUDDB.reputation.pos.x = x - px
    HardcoreHUDDB.reputation.pos.y = y - py
  end)
  
  -- Tooltip on hover
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Reputation Tracker", 1, 1, 1)
    GameTooltip:AddLine("Drag to move (when unlocked)", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Use /hh to select faction and settings", 0.7, 0.7, 0.7)
    
    -- Show faction-specific turnin info
    local factionName = HardcoreHUDDB.reputation.selectedFaction
    local factionData = FACTION_DATA[factionName]
    if factionData and factionData.turnins and #factionData.turnins > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Turn-ins:", 1, 0.84, 0)
      for _, turnin in ipairs(factionData.turnins) do
        GameTooltip:AddLine(string.format("  %s: +%d rep", turnin.name, turnin.rep), 0.6, 0.8, 0.6)
      end
    end
    
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)
  
  -- Update timer
  if not H._repUpdateFrame then
    local uf = CreateFrame("Frame")
    H._repUpdateFrame = uf
    local acc = 0
    uf:SetScript("OnUpdate", function(_, dt)
      acc = acc + dt
      if acc >= 1.0 then
        acc = 0
        H.UpdateReputationTracker()
      end
    end)
  end
  
  -- Track rep changes and AUTO-DETECT rep per mob
  if not H._repEventFrame then
    local ef = CreateFrame("Frame")
    H._repEventFrame = ef
    ef:RegisterEvent("UPDATE_FACTION")
    ef:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
    ef:SetScript("OnEvent", function(self, event, msg, ...)
      if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" and msg then
        -- Debug: print the raw message so we can see what format it has
        if HardcoreHUDDB.reputation and HardcoreHUDDB.reputation.debug then
          print("|cffff00ffREP DEBUG:|r " .. msg)
        end
        
        -- Parse the rep gain message - try multiple patterns
        local faction, amount
        
        -- Pattern 1: "Reputation with <faction> increased by <amount>."
        faction, amount = string.match(msg, "Reputation with (.+) increased by (%d+)")
        
        -- Pattern 2: "Your reputation with <faction> has increased by <amount>."
        if not faction then
          faction, amount = string.match(msg, "reputation with (.+) has increased by (%d+)")
        end
        
        -- Pattern 3: German - "Euer Ansehen beim/bei der <faction> hat sich um <amount> verbessert/erhöht"
        if not faction then
          faction, amount = string.match(msg, "Ansehen bei[md]? ?e?r? (.+) hat sich um (%d+)")
        end
        
        -- Pattern 4: German alternate - "Ruf bei <faction>"
        if not faction then
          faction, amount = string.match(msg, "Ruf bei[md]? ?e?r? (.+) hat sich um (%d+)")
        end
        
        -- Pattern 5: Very flexible - just find any number and assume it's rep
        if not amount then
          amount = string.match(msg, "(%d+)")
          -- Try to get faction from the message
          if not faction then
            -- Look for text between "with" and "increased/has"
            faction = string.match(msg, "with (.+) increased")
            if not faction then faction = string.match(msg, "with (.+) has") end
            if not faction then faction = string.match(msg, "bei[md]? ?e?r? (.+) hat") end
          end
        end
        
        -- Clean up faction name (remove trailing "hat sich", etc.)
        if faction then
          faction = string.gsub(faction, " hat sich.*", "")
          faction = string.gsub(faction, " increased.*", "")
          faction = string.gsub(faction, " has.*", "")
          faction = string.trim and string.trim(faction) or faction:match("^%s*(.-)%s*$")
        end
        
        if amount then
          amount = tonumber(amount)
          if amount and amount > 0 then
            -- Store the detected rep value
            HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
            HardcoreHUDDB.reputation.detectedRep = HardcoreHUDDB.reputation.detectedRep or {}
            
            -- Get tracked faction
            local trackedFaction = HardcoreHUDDB.reputation.selectedFaction or ""
            
            -- Check if the message is about our tracked faction
            -- Use case-insensitive comparison
            local msgLower = string.lower(msg)
            local trackedLower = string.lower(trackedFaction)
            
            if string.find(msgLower, trackedLower, 1, true) then
              -- This message is about our tracked faction!
              HardcoreHUDDB.reputation.lastDetectedRep = amount
              HardcoreHUDDB.reputation.autoDetected = true
              
              -- Store for this faction
              if faction then
                HardcoreHUDDB.reputation.detectedRep[faction] = amount
              end
              HardcoreHUDDB.reputation.detectedRep[trackedFaction] = amount
              
              -- Show notification only once (first detection) or if debug is on
              if not HardcoreHUDDB.reputation._notifiedThisSession then
                HardcoreHUDDB.reputation._notifiedThisSession = true
                print(string.format("|cff8060ffHardcoreHUD:|r Detected %d rep/kill for %s", amount, trackedFaction))
              end
            elseif faction then
              -- Store for other factions too
              HardcoreHUDDB.reputation.detectedRep[faction] = amount
            end
          end
        end
      end
      
      -- Immediate update on rep change
      H.UpdateReputationTracker()
    end)
  end
end

-- Update Reputation Tracker
function H.UpdateReputationTracker()
  if not H.reputationTracker then return end
  if not HardcoreHUDDB.reputation or not HardcoreHUDDB.reputation.enabled then
    H.reputationTracker:Hide()
    return
  end
  
  local f = H.reputationTracker
  local opts = HardcoreHUDDB.reputation
  local factionName = opts.selectedFaction or "Timbermaw Hold"
  local repPerMob = opts.customRepPerMob or 10
  local isAutoDetected = false
  
  -- PRIORITY 1: Use auto-detected rep value if available for this faction
  if opts.lastDetectedRep and opts.autoDetected then
    repPerMob = opts.lastDetectedRep
    isAutoDetected = true
  -- PRIORITY 2: Check if we have a stored detected value for this faction
  elseif opts.detectedRep then
    for storedFaction, storedRep in pairs(opts.detectedRep) do
      if string.find(storedFaction, factionName, 1, true) or string.find(factionName, storedFaction, 1, true) then
        repPerMob = storedRep
        isAutoDetected = true
        break
      end
    end
  end
  
  -- PRIORITY 3: Fall back to faction data defaults (but these may be wrong)
  if not isAutoDetected then
    local factionData = FACTION_DATA[factionName]
    if factionData and factionData.mobRep and factionData.mobRep > 0 then
      repPerMob = factionData.mobRep
    end
  end
  
  -- Calculate mobs needed
  local calc = H.CalculateMobsNeeded(factionName, repPerMob)
  if not calc then
    f.factionText:SetText(factionName)
    f.standingText:SetText("Not Found")
    f.repText:SetText("N/A")
    f.repBar:SetValue(0)
    f.mobsText:SetText("Faction not in your reputation panel")
    f.infoText:SetText("")
    f:Show()
    return
  end
  
  f:Show()
  
  -- Update faction name
  f.factionText:SetText(factionName)
  
  -- If this is a capital, show only Runecloth turn-in requirements (no mobs)
  if H.IsCapital(factionName) then
    -- Update basic rep display
    f.standingText:SetText(calc.standingName)
    local percent = calc.max > 0 and (calc.current / calc.max * 100) or 100
    f.repBar:SetValue(percent)
    f.repText:SetText(string.format("%d / %d", calc.current, calc.max))

    -- Capital runecloth calculation
    local repNeeded = calc.repNeeded
    if repNeeded <= 0 then
      if f.capitalText then f.capitalText:SetText("Hauptstadt: Bereits maximale Stufe") end
      f.mobsText:SetText("")
      f.infoText:SetText("")
      return
    end
    local repPerTurnin = 50
    local race = string.lower((UnitRace and UnitRace("player") or "") or "")
    local isHuman = (string.find(race, "human") or string.find(race, "mensch")) and true or false
    local clothPerTurnin = isHuman and 55 or 60
    local turninsNeeded = math.ceil(repNeeded / repPerTurnin)
    local clothNeeded = turninsNeeded * clothPerTurnin
    if f.capitalText then
      f.capitalText:SetText(string.format("%d Runenstoff (~%d Abgaben à %d Ruf) für %s", clothNeeded, turninsNeeded, repPerTurnin, factionName))
    end
    f.mobsText:SetText("")
    f.infoText:SetText("")
    return
  end
  
  -- Color based on standing
  local colors = {
    [1] = {0.8, 0.2, 0.2}, -- Hated (red)
    [2] = {0.9, 0.4, 0.2}, -- Hostile (orange-red)
    [3] = {0.9, 0.6, 0.2}, -- Unfriendly (orange)
    [4] = {0.9, 0.9, 0.2}, -- Neutral (yellow)
    [5] = {0.2, 0.8, 0.2}, -- Friendly (green)
    [6] = {0.2, 0.6, 0.9}, -- Honored (blue)
    [7] = {0.6, 0.2, 0.8}, -- Revered (purple)
    [8] = {1.0, 0.84, 0}, -- Exalted (gold)
  }
  local info = H.GetReputationInfo(factionName)
  local standingID = (calc and calc.standingID) or (info and info.standingID) or 4
  local color = colors[standingID] or {0.6, 0.2, 0.8}
  -- Debug output when enabled
  if HardcoreHUDDB.reputation and HardcoreHUDDB.reputation.debug then
    local si = tostring(info and info.standingID or "nil")
    local cs = tostring(calc and calc.standingID or "nil")
    print(string.format("|cffffcc00REP DEBUG:|r %s standingID(info)=%s standingID(calc)=%s color=%.2f,%.2f,%.2f", factionName, si, cs, color[1], color[2], color[3]))
  end
  f.repBar:SetStatusBarColor(color[1], color[2], color[3], 0.9)

  -- Ensure the standing label and bar value are updated when switching factions.
  -- Previously the bar retained the last faction's percentage and label.
  local standingName = (calc and calc.standingName) and calc.standingName or "Unknown"
  f.standingText:SetText(standingName)
  local percent = 100
  if calc and calc.max and calc.max > 0 then
    percent = (calc.current / calc.max) * 100
  end
  f.repBar:SetValue(percent)
  
  -- Update rep text
  f.repText:SetText(string.format("%d / %d", calc.current, calc.max))
  
  -- Update mobs needed text
  if calc.isExalted then
    f.mobsText:SetText("|cff00ff00Exalted! Max reputation reached.|r")
    f.infoText:SetText("")
  else
    if repPerMob > 0 then
      -- Show if value is auto-detected or manual
      local repSource = isAutoDetected and "|cff00ff00auto|r" or "|cffaaaaaa?|r"
      f.mobsText:SetText(string.format("|cffffcc00~%d|r mobs to |cff00ff00%s|r (%d rep/mob %s)", 
        calc.mobsNeeded, calc.nextStanding, repPerMob, repSource))
    else
      f.mobsText:SetText(string.format("%d rep needed to |cff00ff00%s|r", 
        calc.repNeeded, calc.nextStanding))
    end
    
    -- Show hint if not auto-detected
    local factionData = FACTION_DATA[factionName]
    if not isAutoDetected then
      f.infoText:SetText("|cffaaaaaa(Kill a mob to auto-detect rep)|r")
    elseif factionData and factionData.turnins and #factionData.turnins > 0 then
      local turnin = factionData.turnins[1]
      local turninsNeeded = math.ceil(calc.repNeeded / turnin.rep)
      f.infoText:SetText(string.format("or ~%d x %s", turninsNeeded, turnin.name))
    else
      f.infoText:SetText("")
    end
  end

  -- Ensure the capital text is only shown when the selected faction is a capital.
  -- Previously we always scanned and showed a separate capital summary which caused
  -- Runecloth info to appear even when a non-capital faction (e.g. Argent Dawn)
  -- was selected. Clear the field for non-capital selections.
  if f.capitalText then f.capitalText:SetText("") end
end

-- Toggle visibility
function H.ToggleReputationTracker()
  if not H.reputationTracker then H.InitReputationTracker() end
  
  HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
  
  if H.reputationTracker:IsShown() then
    H.reputationTracker:Hide()
    HardcoreHUDDB.reputation.enabled = false
    print("HardcoreHUD: Reputation tracker OFF")
  else
    H.reputationTracker:Show()
    HardcoreHUDDB.reputation.enabled = true
    H.UpdateReputationTracker()
    print("HardcoreHUD: Reputation tracker ON")
  end
end

-- Set tracked faction
function H.SetTrackedFaction(factionName)
  HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
  HardcoreHUDDB.reputation.selectedFaction = factionName
  
  -- Reset auto-detection for the new faction
  HardcoreHUDDB.reputation.lastDetectedRep = nil
  HardcoreHUDDB.reputation.autoDetected = false
  
  -- Check if we have a stored detected value for this faction
  if HardcoreHUDDB.reputation.detectedRep then
    for storedFaction, storedRep in pairs(HardcoreHUDDB.reputation.detectedRep) do
      if string.find(storedFaction, factionName, 1, true) or string.find(factionName, storedFaction, 1, true) then
        HardcoreHUDDB.reputation.lastDetectedRep = storedRep
        HardcoreHUDDB.reputation.autoDetected = true
        print(string.format("|cff8060ffHardcoreHUD:|r Using previously detected %d rep/kill for %s", storedRep, factionName))
        break
      end
    end
  end
  
  -- Fall back to faction data default
  if not HardcoreHUDDB.reputation.autoDetected then
    local factionData = FACTION_DATA[factionName]
    if factionData and factionData.mobRep then
      HardcoreHUDDB.reputation.customRepPerMob = factionData.mobRep
    end
  end
  
  H.UpdateReputationTracker()
  print(string.format("HardcoreHUD: Now tracking %s reputation", factionName))
end

-- Set custom rep per mob
function H.SetRepPerMob(rep)
  HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
  HardcoreHUDDB.reputation.customRepPerMob = rep or 10
  H.UpdateReputationTracker()
end

-- Get available faction data
function H.GetFactionData()
  return FACTION_DATA
end
