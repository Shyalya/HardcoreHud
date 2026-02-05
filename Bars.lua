local H = HardcoreHUD

local FIVE = 5
local ENERGY_TICK = 2
local MANA_TICK = 2

local bars = {}
H.bars = bars

-- Safe power accessor: prefer `UnitPower` API, fall back to classic `UnitMana`/`UnitEnergy`/`UnitRage` when needed
local function GetUnitPowerAndMax(unit, pType)
  pType = pType or 0
  if UnitPower and UnitPowerMax then
    return (UnitPower(unit, pType) or 0), (UnitPowerMax(unit, pType) or 0)
  end
  if pType == 0 then
    if UnitMana and UnitManaMax then return (UnitMana(unit) or 0), (UnitManaMax(unit) or 0) end
  elseif pType == 1 then
    if UnitRage then return (UnitRage(unit) or 0), 100 end
  elseif pType == 3 then
    if UnitEnergy then return (UnitEnergy(unit) or 0), 100 end
  end
  return 0, 100
end

local function attachDrag(frame)
  if not frame then return end
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function()
    if H.root and H.root:IsMovable() then H.root:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function()
    if H.root then
      H.root:StopMovingOrSizing()
      local cx, cy = H.root:GetCenter()
      local px, py = UIParent:GetCenter()
      local x = cx - px
      local y = cy - py
      HardcoreHUDDB.pos = { x = x, y = y }
      H.root:ClearAllPoints()
      H.root:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
  end)
end

local function border(frame)
  H.SafeBackdrop(frame, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=3,right=3,top=3,bottom=3} }, 0,0,0,0.5)
end

local function getBarTexture()
  return "Interface/TargetingFrame/UI-StatusBar"
end

-- Thin 1px border around status bars
local function addThinBorder(frame)
  if not frame or frame._thinBorder then return end
  local lines = {}
  local function mk()
    local t = frame:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0,0,0,0.9)
    return t
  end
  lines.top = mk(); lines.bottom = mk(); lines.left = mk(); lines.right = mk()
  frame._thinBorder = lines
  -- initial placement; will be sized in ApplyLayout too
  lines.top:ClearAllPoints(); lines.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); lines.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); lines.top:SetHeight(1)
  lines.bottom:ClearAllPoints(); lines.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); lines.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); lines.bottom:SetHeight(1)
  lines.left:ClearAllPoints(); lines.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); lines.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); lines.left:SetWidth(1)
  lines.right:ClearAllPoints(); lines.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); lines.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); lines.right:SetWidth(1)
end

-- Robust check if player knows a spell (Wrath-compatible)
local function IsKnown(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  if IsSpellKnown and IsSpellKnown(id) then return true end
  -- Spellbook scan fallback
  local i = 1
  while true do
    local name = GetSpellBookItemName and GetSpellBookItemName(i, BOOKTYPE_SPELL) or nil
    if not name then break end
    local link = GetSpellLink and GetSpellLink(i, BOOKTYPE_SPELL) or nil
    if link then
      local found = link:match("spell:(%d+)")
      if found and tonumber(found) == id then return true end
    end
    i = i + 1
    if i > 300 then break end
  end
  return false
end

-- ============================================================================
-- Power Word: Shield Golden Border Tracking
-- Shows a golden border around HP bar that shrinks as the shield absorbs damage
-- ============================================================================
local PWS_SPELL_IDS = {
  [17] = 44,      -- Rank 1
  [592] = 88,     -- Rank 2
  [600] = 158,    -- Rank 3
  [3747] = 234,   -- Rank 4
  [6065] = 301,   -- Rank 5
  [6066] = 381,   -- Rank 6
  [10898] = 484,  -- Rank 7
  [10899] = 605,  -- Rank 8
  [10900] = 763,  -- Rank 9
  [10901] = 942,  -- Rank 10
}

-- Shield state tracking
H.shieldState = H.shieldState or {
  active = false,
  maxAbsorb = 0,
  currentAbsorb = 0,
  spellId = nil,
}

-- Known PW:S buff names in different locales
local PWS_BUFF_NAMES = {
  -- English
  ["Power Word: Shield"] = true,
  -- German
  ["Machtwort: Schild"] = true,
  -- French  
  ["Mot de pouvoir : Bouclier"] = true,
  -- Spanish
  ["Palabra de poder: escudo"] = true,
  -- Italian
  ["Parola del Potere: Scudo"] = true,
  -- Portuguese
  ["Palavra de Poder: Escudo"] = true,
}

-- Known "Weakened Soul" debuff names (indicates PW:S was applied)
local WEAKENED_SOUL_NAMES = {
  ["Weakened Soul"] = true,
  ["Geschw\195\164chte Seele"] = true,  -- German: Geschwächte Seele
  ["\195\130me affaiblie"] = true,  -- French: Âme affaiblie
  ["Alma debilitada"] = true,  -- Spanish
}

-- Get PW:S buff name (locale-safe via spell ID)
local function GetPWSBuffName()
  -- Try to get the name from any known PW:S spell ID
  -- Start with rank 1 (spell ID 17) which is most likely to be cached
  local tryOrder = {17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901}
  for _, spellId in ipairs(tryOrder) do
    local name = GetSpellInfo and GetSpellInfo(spellId)
    if name and name ~= "" then 
      -- Add to known names table for future lookups
      PWS_BUFF_NAMES[name] = true
      return name 
    end
  end
  return "Power Word: Shield" -- fallback for English clients
end

-- Check if player has PW:S and return the spell ID if found
local function GetActivePWSInfo()
  local pwsName = GetPWSBuffName()
  
  -- Debug: Show what buff name we're looking for
  if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
    print(string.format("[HardcoreHUD] Shield: Looking for buff named '%s'", tostring(pwsName)))
  end
  
  -- First scan: check buffs for PW:S
  for i = 1, 40 do
    -- Classic Era 1.15.x: UnitBuff returns fewer values than retail
    -- Classic: name, icon, count, debuffType, duration, expirationTime, unitCaster
    -- spellId is NOT returned in Classic Era!
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitBuff("player", i)
    if not name then break end
    
    -- Debug: Show all buffs being checked (only once per scan to reduce spam)
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield and i <= 5 then
      print(string.format("[HardcoreHUD] Shield: Checking buff[%d]='%s'", i, tostring(name)))
    end
    
    -- Check by exact name match from known table
    if PWS_BUFF_NAMES[name] then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S by exact name '%s' at index %d", name, i))
      end
      return true, 10901, expirationTime
    end
    
    -- Check by expected name from GetSpellInfo
    if name == pwsName then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S by spell name match at index %d", i))
      end
      return true, 10901, expirationTime
    end
    
    -- Also check for localized variants via pattern matching
    local lowerName = string.lower(name or "")
    
    -- English: "Power Word: Shield"
    if string.find(lowerName, "power word") and string.find(lowerName, "shield") then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S (English pattern) at index %d", i))
      end
      PWS_BUFF_NAMES[name] = true  -- Remember this name
      return true, 10901, expirationTime
    end
    
    -- German: "Machtwort: Schild"
    if string.find(lowerName, "machtwort") and string.find(lowerName, "schild") then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S (German) at index %d", i))
      end
      PWS_BUFF_NAMES[name] = true
      return true, 10901, expirationTime
    end
    
    -- French: "Mot de pouvoir : Bouclier"
    if string.find(lowerName, "mot de pouvoir") and string.find(lowerName, "bouclier") then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S (French) at index %d", i))
      end
      PWS_BUFF_NAMES[name] = true
      return true, 10901, expirationTime
    end
    
    -- Spanish: "Palabra de poder: escudo"
    if string.find(lowerName, "palabra de poder") and string.find(lowerName, "escudo") then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: FOUND PW:S (Spanish) at index %d", i))
      end
      PWS_BUFF_NAMES[name] = true
      return true, 10901, expirationTime
    end
  end
  
  -- Second scan: check if "Weakened Soul" debuff is present as a backup indicator
  -- If we have Weakened Soul, we SHOULD have PW:S (unless it just expired)
  for i = 1, 40 do
    local name = UnitDebuff("player", i)
    if not name then break end
    
    if WEAKENED_SOUL_NAMES[name] then
      -- Weakened Soul found - rescan buffs one more time for any absorb-type buff
      -- This catches cases where the buff name doesn't match our patterns
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: Found Weakened Soul debuff '%s' - PW:S should be active", name))
      end
      -- Don't return true here - we need the actual shield buff, not just Weakened Soul
      break
    end
    
    -- Also check patterns for Weakened Soul
    local lowerName = string.lower(name or "")
    if string.find(lowerName, "weakened soul") or string.find(lowerName, "geschw.*chte seele") or string.find(lowerName, "me affaiblie") then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: Found Weakened Soul (pattern) '%s'", name))
      end
      WEAKENED_SOUL_NAMES[name] = true  -- Remember this name
      break
    end
  end
  
  return false, nil, nil
end

-- Estimate initial absorb amount based on spell ID and player stats
local function EstimateShieldAbsorb(spellId)
  local baseAbsorb = PWS_SPELL_IDS[spellId] or 500
  -- In Classic, +healing affects PW:S at ~10% coefficient
  -- This is a rough estimate; actual value may vary
  local bonusHealing = 0
  if GetSpellBonusHealing then
    bonusHealing = GetSpellBonusHealing() or 0
  end
  -- Approximate coefficient for PW:S in Classic is around 10%
  local estimatedAbsorb = baseAbsorb + (bonusHealing * 0.1)
  return math.floor(estimatedAbsorb)
end

-- Build the golden shield border around HP bar
function H.BuildShieldBorder()
  if H.shieldBorder then return end
  if not bars.hp then return end
  
  local hp = bars.hp
  local borderWidth = 3  -- Golden border thickness
  
  -- Create container frame for shield border
  local shieldFrame = CreateFrame("Frame", nil, hp)
  shieldFrame:SetAllPoints(hp)
  shieldFrame:SetFrameLevel(hp:GetFrameLevel() + 10)
  H.shieldBorder = shieldFrame
  
  -- Create the 4 border textures (golden color: 1.0, 0.84, 0.0)
  local goldR, goldG, goldB = 1.0, 0.84, 0.0
  
  -- Left border (grows from bottom to top based on shield %)
  local left = shieldFrame:CreateTexture(nil, "OVERLAY")
  left:SetColorTexture(goldR, goldG, goldB, 0.9)
  left:SetWidth(borderWidth)
  left:ClearAllPoints()
  left:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", -borderWidth, 0)
  shieldFrame.left = left
  
  -- Right border (grows from bottom to top based on shield %)
  local right = shieldFrame:CreateTexture(nil, "OVERLAY")
  right:SetColorTexture(goldR, goldG, goldB, 0.9)
  right:SetWidth(borderWidth)
  right:ClearAllPoints()
  right:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", borderWidth, 0)
  shieldFrame.right = right
  
  -- Top border (only visible when shield is at 100%)
  local top = shieldFrame:CreateTexture(nil, "OVERLAY")
  top:SetColorTexture(goldR, goldG, goldB, 0.9)
  top:SetHeight(borderWidth)
  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", hp, "TOPLEFT", -borderWidth, borderWidth)
  top:SetPoint("TOPRIGHT", hp, "TOPRIGHT", borderWidth, borderWidth)
  shieldFrame.top = top
  
  -- Bottom border (always visible when shield is active)
  local bottom = shieldFrame:CreateTexture(nil, "OVERLAY")
  bottom:SetColorTexture(goldR, goldG, goldB, 0.9)
  bottom:SetHeight(borderWidth)
  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", -borderWidth, -borderWidth)
  bottom:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", borderWidth, -borderWidth)
  shieldFrame.bottom = bottom
  
  -- Inner glow effect (subtle golden overlay on the bar itself)
  local glow = hp:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints(hp)
  glow:SetColorTexture(goldR, goldG, goldB, 0.15)
  glow:SetBlendMode("ADD")
  shieldFrame.glow = glow
  
  -- Shield amount text (optional, shows remaining absorb)
  local shieldText = shieldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  shieldText:SetPoint("BOTTOM", hp, "TOP", 0, 4)
  shieldText:SetTextColor(goldR, goldG, goldB, 1)
  shieldFrame.text = shieldText
  
  -- Hide by default
  shieldFrame:Hide()
end

-- Update shield border visuals based on current shield state
function H.UpdateShieldBorder()
  if not H.shieldBorder then H.BuildShieldBorder() end
  if not H.shieldBorder or not bars.hp then return end
  
  local state = H.shieldState
  local frame = H.shieldBorder
  
  if not state.active or state.currentAbsorb <= 0 then
    frame:Hide()
    return
  end
  
  -- Calculate shield percentage
  local pct = state.maxAbsorb > 0 and (state.currentAbsorb / state.maxAbsorb) or 0
  if pct > 1 then pct = 1 end
  if pct < 0 then pct = 0 end
  
  local barHeight = bars.hp:GetHeight()
  local borderHeight = barHeight * pct
  
  -- Update left and right border heights (grow from bottom)
  frame.left:SetHeight(borderHeight)
  frame.right:SetHeight(borderHeight)
  
  -- Top border only visible above 95%
  if pct > 0.95 then
    frame.top:Show()
    frame.top:SetAlpha(0.9)
  else
    frame.top:Hide()
  end
  
  -- Bottom border always visible when shield active
  frame.bottom:Show()
  
  -- Adjust glow intensity based on shield %
  local glowAlpha = 0.08 + (pct * 0.12)  -- 0.08 to 0.20
  frame.glow:SetAlpha(glowAlpha)
  
  -- Update shield text
  if HardcoreHUDDB.shield and HardcoreHUDDB.shield.showText then
    frame.text:SetText(string.format("%d", state.currentAbsorb))
    frame.text:Show()
  else
    frame.text:Hide()
  end
  
  -- Pulse effect when shield is low (<25%)
  if pct < 0.25 then
    local pulse = 0.6 + 0.4 * math.abs(math.sin(GetTime() * 4))
    frame.left:SetAlpha(pulse)
    frame.right:SetAlpha(pulse)
    frame.bottom:SetAlpha(pulse)
  else
    frame.left:SetAlpha(0.9)
    frame.right:SetAlpha(0.9)
    frame.bottom:SetAlpha(0.9)
  end
  
  frame:Show()
end

-- Handle shield application/refresh
function H.OnShieldApplied(spellId)
  local state = H.shieldState
  local absorb = EstimateShieldAbsorb(spellId)
  state.active = true
  state.maxAbsorb = absorb
  state.currentAbsorb = absorb
  state.spellId = spellId
  H.UpdateShieldBorder()
end

-- Handle shield absorbing damage
function H.OnShieldAbsorb(amount)
  if not amount or amount <= 0 then return end
  local state = H.shieldState
  if not state.active then return end
  local before = state.currentAbsorb
  state.currentAbsorb = math.max(0, state.currentAbsorb - amount)
  -- Debug output
  if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
    print(string.format("[HardcoreHUD] Shield absorbed %d, was %d, now %d", amount, before, state.currentAbsorb))
  end
  if state.currentAbsorb <= 0 then
    -- Don't set active to false here - let UNIT_AURA handle buff removal
    -- Just clamp to 0
    state.currentAbsorb = 0
  end
  H.UpdateShieldBorder()
end

-- Handle shield removal
function H.OnShieldRemoved()
  local state = H.shieldState
  state.active = false
  state.currentAbsorb = 0
  state.maxAbsorb = 0
  state.spellId = nil
  H.UpdateShieldBorder()
end

-- Check current shield state (called on UNIT_AURA)
function H.CheckShieldState()
  local hasShield, spellId, expTime = GetActivePWSInfo()
  local state = H.shieldState
  
  -- Debug output
  if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
    print(string.format("[HardcoreHUD] CheckShieldState: hasShield=%s, spellId=%s, state.active=%s", 
      tostring(hasShield), tostring(spellId), tostring(state.active)))
  end
  
  if hasShield then
    if not state.active or state.spellId ~= spellId then
      -- New shield or refreshed
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] Shield: Applying new shield (spellId=%s)", tostring(spellId or 10901)))
      end
      H.OnShieldApplied(spellId or 10901)  -- Default to rank 10 if ID unknown
    end
    -- Shield still exists, keep it active
  else
    if state.active then
      -- Shield was removed (expired or fully absorbed)
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print("[HardcoreHUD] Shield: Removing shield (buff no longer present)")
      end
      H.OnShieldRemoved()
    end
  end
end

-- Event handler for shield tracking
-- Classic Era 1.15.x: Combat log args come directly via ... not CombatLogGetCurrentEventInfo()
local shieldEventFrame = CreateFrame("Frame")
shieldEventFrame:RegisterEvent("UNIT_AURA")
shieldEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
shieldEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
shieldEventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" then
      H.CheckShieldState()
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- Classic Era 1.15.x: Combat log structure is DIFFERENT from retail/wrath
    -- In Classic Era 1.15.x, the args come directly via ...
    -- Format varies - we need to handle multiple possible structures
    
    local args = {...}
    local numArgs = #args
    
    -- Debug: Always print raw args when shield debug is on
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
      local debugStr = "[HardcoreHUD] CL raw (" .. numArgs .. " args): "
      for i = 1, math.min(numArgs, 25) do
        debugStr = debugStr .. string.format("[%d]=%s ", i, tostring(args[i]))
      end
      print(debugStr)
    end
    
    -- Classic Era 1.15.x format - try to detect structure
    -- Some versions: timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
    -- Some versions may have hideCaster: timestamp, subEvent, hideCaster, srcGUID, ...
    
    local timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
    local payloadStart = 9  -- Where the damage/spell payload starts
    
    -- Check if args[3] looks like a GUID (starts with creature-, player-, etc.) or a boolean
    local arg3 = args[3]
    if type(arg3) == "boolean" or arg3 == nil or arg3 == false or arg3 == true then
      -- Has hideCaster field
      timestamp = args[1]
      subEvent = args[2]
      -- hideCaster = args[3]
      srcGUID = args[4]
      srcName = args[5]
      srcFlags = args[6]
      dstGUID = args[7]
      dstName = args[8]
      dstFlags = args[9]
      payloadStart = 10
    else
      -- No hideCaster field
      timestamp = args[1]
      subEvent = args[2]
      srcGUID = args[3]
      srcName = args[4]
      srcFlags = args[5]
      dstGUID = args[6]
      dstName = args[7]
      dstFlags = args[8]
      payloadStart = 9
    end
    
    local playerGUID = UnitGUID("player")
    if dstGUID ~= playerGUID then return end
    
    local absorbed = nil
    
    -- Only process shield absorption if shield is active
    if not H.shieldState or not H.shieldState.active then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        if subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SWING_MISSED" or subEvent == "SPELL_MISSED" then
          print(string.format("[HardcoreHUD] Shield NOT ACTIVE - skipping event %s (state=%s, active=%s)",
            tostring(subEvent), tostring(H.shieldState ~= nil), tostring(H.shieldState and H.shieldState.active)))
        end
      end
      return
    end
    
    -- Helper function to find absorbed value in args
    -- Scans from payloadStart to find the absorbed damage
    local function FindAbsorbedInDamageEvent(startIdx)
      -- For _DAMAGE events, structure is usually:
      -- amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
      -- absorbed is typically 6 positions after amount (at startIdx + 5)
      local absorbIdx = startIdx + 5
      local val = args[absorbIdx]
      if type(val) == "number" and val > 0 then
        return val, absorbIdx
      end
      -- Try alternative positions in case structure differs
      for offset = 4, 7 do
        local idx = startIdx + offset
        local v = args[idx]
        if type(v) == "number" and v > 0 then
          -- Verify it's likely absorbed by checking context
          -- (absorbed should come after school/resisted/blocked)
          return v, idx
        end
      end
      return nil, nil
    end
    
    local function FindAbsorbedInSpellDamageEvent(startIdx)
      -- For SPELL_DAMAGE, structure is:
      -- spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed
      -- absorbed is at startIdx + 8
      local absorbIdx = startIdx + 8
      local val = args[absorbIdx]
      if type(val) == "number" and val > 0 then
        return val, absorbIdx
      end
      -- Try scanning nearby positions
      for offset = 6, 10 do
        local idx = startIdx + offset
        local v = args[idx]
        if type(v) == "number" and v > 0 then
          return v, idx
        end
      end
      return nil, nil
    end
    
    if subEvent == "SWING_DAMAGE" then
      -- SWING_DAMAGE: amount, overkill, school, resisted, blocked, absorbed, ...
      absorbed = FindAbsorbedInDamageEvent(payloadStart)
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] SWING_DAMAGE (payload@%d): amount=%s, absorbed=%s", 
          payloadStart, tostring(args[payloadStart]), tostring(absorbed)))
      end
      
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "RANGE_DAMAGE" then
      -- SPELL_DAMAGE: spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed
      absorbed = FindAbsorbedInSpellDamageEvent(payloadStart)
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] %s (payload@%d): spellId=%s, spellName=%s, absorbed=%s", 
          tostring(subEvent), payloadStart, tostring(args[payloadStart]), tostring(args[payloadStart+1]), tostring(absorbed)))
      end
      
    elseif subEvent == "SWING_MISSED" then
      -- SWING_MISSED: missType, [isOffHand], [amountMissed]
      local missType = args[payloadStart]
      if missType == "ABSORB" then
        -- Amount absorbed is the next numeric value
        for i = payloadStart + 1, payloadStart + 3 do
          if type(args[i]) == "number" then
            absorbed = args[i]
            break
          end
        end
        if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
          print(string.format("[HardcoreHUD] SWING_MISSED ABSORB (payload@%d): absorbed=%s", 
            payloadStart, tostring(absorbed)))
        end
      end
      
    elseif subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED" or subEvent == "SPELL_PERIODIC_MISSED" then
      -- SPELL_MISSED: spellId, spellName, spellSchool, missType, [isOffHand], [amountMissed]
      local missType = args[payloadStart + 3]
      if missType == "ABSORB" then
        -- Amount absorbed is the next numeric value after missType
        for i = payloadStart + 4, payloadStart + 6 do
          if type(args[i]) == "number" then
            absorbed = args[i]
            break
          end
        end
        if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
          print(string.format("[HardcoreHUD] %s ABSORB (payload@%d): spellId=%s, absorbed=%s", 
            tostring(subEvent), payloadStart, tostring(args[payloadStart]), tostring(absorbed)))
        end
      end
      
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
      -- ENVIRONMENTAL_DAMAGE: envType, amount, overkill, school, resisted, blocked, absorbed
      local absorbIdx = payloadStart + 6
      absorbed = args[absorbIdx]
      if type(absorbed) ~= "number" then
        absorbed = FindAbsorbedInDamageEvent(payloadStart + 1)
      end
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] ENVIRONMENTAL_DAMAGE (payload@%d): envType=%s, absorbed=%s", 
          payloadStart, tostring(args[payloadStart]), tostring(absorbed)))
      end
    end
    
    -- Apply absorbed damage to shield tracking
    if absorbed and type(absorbed) == "number" and absorbed > 0 then
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] >>> Calling OnShieldAbsorb(%d) - shield before: %d", 
          absorbed, H.shieldState.currentAbsorb or 0))
      end
      H.OnShieldAbsorb(absorbed)
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        print(string.format("[HardcoreHUD] >>> Shield after absorb: %d", H.shieldState.currentAbsorb or 0))
      end
    end
    
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Check initial shield state
    C_Timer.After(0.5, function()
      H.CheckShieldState()
    end)
    -- Debug: Print shield tracking status on login
    C_Timer.After(1.0, function()
      if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.shield then
        local pwsName = GetPWSBuffName()
        print(string.format("[HardcoreHUD] Shield tracking initialized. Looking for buff: '%s'", tostring(pwsName)))
        print(string.format("[HardcoreHUD] Shield state: active=%s, currentAbsorb=%s, maxAbsorb=%s",
          tostring(H.shieldState and H.shieldState.active),
          tostring(H.shieldState and H.shieldState.currentAbsorb),
          tostring(H.shieldState and H.shieldState.maxAbsorb)))
      end
    end)
  end
end)

-- OnUpdate for smooth shield border animation
local shieldUpdateFrame = CreateFrame("Frame")
local shieldUpdateAcc = 0
shieldUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
  shieldUpdateAcc = shieldUpdateAcc + elapsed
  if shieldUpdateAcc >= 0.05 then  -- 20 FPS update
    shieldUpdateAcc = 0
    if H.shieldState and H.shieldState.active then
      H.UpdateShieldBorder()
    end
  end
end)

function H.ApplyBarTexture()
  if bars.hp then bars.hp:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar") end
  if bars.pow then bars.pow:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar") end
  if bars.targetHP then bars.targetHP:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar") end
  if bars.targetPow then bars.targetPow:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar") end
end

function H.BuildBars()
  if bars.hp then return end
  local w,h = HardcoreHUDDB.size.width, HardcoreHUDDB.size.height
  local root = H.root
  local barThickness = HardcoreHUDDB.layout and HardcoreHUDDB.layout.thickness or 12
  local barHeight = HardcoreHUDDB.layout and HardcoreHUDDB.layout.height or 200
  local gap = HardcoreHUDDB.layout and HardcoreHUDDB.layout.gap or 8
  local separation = HardcoreHUDDB.layout and HardcoreHUDDB.layout.separation or 140
  local centerOffsetY = HardcoreHUDDB.layout and HardcoreHUDDB.layout.centerOffsetY or 0

  -- Left: HP bar (vertical)
  local hp = CreateFrame("StatusBar", nil, root)
  bars.hp = hp
  hp:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  hp:SetMinMaxValues(0, UnitHealthMax("player"))
  hp:SetValue(UnitHealth("player"))
  hp:SetOrientation("VERTICAL")
  hp:SetSize(barThickness, barHeight)
  hp:SetPoint("RIGHT", root, "CENTER", -separation, centerOffsetY)
  hp:SetIgnoreParentAlpha(true)
  -- Override Hide() to keep HP bar always visible
  local originalHideHp = hp.Hide
  hp.Hide = function(self) end
  hp._OriginalHide = originalHideHp
  local hpText = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bars.hpText = hpText
  hpText:SetPoint("TOP", hp, "BOTTOM", 0, -14)
  hpText:SetJustifyH("CENTER")
  hpText:SetTextColor(0, 1, 0) -- green HP

  -- Left: Power bar below/alongside HP (vertical)
  local pow = CreateFrame("StatusBar", nil, root)
  bars.pow = pow
  pow:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  pow:SetMinMaxValues(0, UnitPowerMax("player", UnitPowerType("player")))
  pow:SetValue(UnitPower("player"))
  pow:SetOrientation("VERTICAL")
  pow:SetSize(barThickness, barHeight)
  pow:SetPoint("LEFT", hp, "RIGHT", gap, 0)
  pow:SetIgnoreParentAlpha(true)
  -- Override Hide() to keep Power bar always visible
  local originalHidePow = pow.Hide
  pow.Hide = function(self) end
  pow._OriginalHide = originalHidePow
  local powText = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bars.powText = powText
  powText:SetPoint("TOP", pow, "BOTTOM", 0, -18)
  powText:SetJustifyH("CENTER")

  -- Overlays on power bar: five-second (top-down) and tick (bottom-up)
  local fsFill = pow:CreateTexture(nil, "OVERLAY")
  bars.fsFill = fsFill
  local fsAlpha = (HardcoreHUDDB and HardcoreHUDDB.ticker and HardcoreHUDDB.ticker.fsOpacity) or 0.25
  local _colors = (HardcoreHUDDB and HardcoreHUDDB.colors) or { fiveSec = {1,0.8,0}, tick = {0.9,0.9,0.9}, hp = {0,0.8,0}, mana = {0,0.5,1}, energy = {1,0.85,0}, rage = {0.8,0.2,0.2} }
  local five = (_colors.fiveSec and _colors.fiveSec) or {1,0.8,0}
  fsFill:SetColorTexture(five[1] or 1, five[2] or 0.8, five[3] or 0, fsAlpha)
  if fsFill.SetBlendMode then fsFill:SetBlendMode("ADD") end
  fsFill:ClearAllPoints()
  fsFill:SetPoint("TOPLEFT", pow, "TOPLEFT")
  fsFill:SetPoint("TOPRIGHT", pow, "TOPRIGHT")
  fsFill:SetHeight(0)
  fsFill:Hide()

  local tickLine = pow:CreateTexture(nil, "OVERLAY")
  bars.tickFill = tickLine
  local tickc = (_colors.tick and _colors.tick) or {0.9,0.9,0.9}
  tickLine:SetColorTexture(tickc[1] or 0.9, tickc[2] or 0.9, tickc[3] or 0.9, 1.0)
  tickLine:ClearAllPoints()
  tickLine:SetPoint("BOTTOM", pow, "BOTTOM", 0, 0)
  tickLine:SetSize(pow:GetWidth(), 2)

  -- Add thin borders to player bars
  addThinBorder(hp)
  addThinBorder(pow)

  -- Legacy sink: a hidden tick StatusBar to satisfy any legacy references
  if not bars.tick then
    local legacyTick = CreateFrame("StatusBar", nil, root)
    bars.tick = legacyTick
    legacyTick:SetMinMaxValues(0,1)
    legacyTick:SetValue(0)
    legacyTick:Hide()
  end

  -- Combo points centered between bars
  local combo = CreateFrame("Frame", nil, root)
  bars.combo = combo
  -- Raise combo bar to reduce overlap with utility buttons
  combo:SetPoint("BOTTOM", root, "CENTER", 0, -20)
  combo:SetSize(w, 18)
  combo:SetFrameStrata("HIGH")
  combo:SetFrameLevel(root:GetFrameLevel()+20)
  bars.comboIcons = {}
  for i=1,5 do
    local t = combo:CreateTexture(nil, "ARTWORK")
    t:Hide()
    bars.comboIcons[i] = t
  end

  H.LayoutCombo()
  H.UpdateBarColors()
  -- Build shield border around HP bar (for PW:S tracking)
  H.BuildShieldBorder()
  -- allow dragging from bars and combo
  attachDrag(hp); attachDrag(pow)

  -- Right side: Target bars (vertical)
  local thp = CreateFrame("StatusBar", nil, root)
  bars.targetHP = thp
  thp:SetFrameStrata("HIGH")
  thp:SetAlpha(1)
  thp:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  thp:SetMinMaxValues(0, UnitHealthMax("target") or 1)
  thp:SetValue(UnitHealth("target") or 0)
  thp:SetOrientation("VERTICAL")
  thp:SetSize(barThickness, barHeight)
  thp:SetPoint("LEFT", root, "CENTER", separation, centerOffsetY)
  thp:SetStatusBarColor(1,0,0)
  local thpText = thp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bars.targetHPText = thpText
  thpText:SetPoint("TOP", thp, "BOTTOM", 0, -14)
  thpText:SetJustifyH("CENTER")
  thpText:SetTextColor(0, 1, 0) -- green HP

  local tpow = CreateFrame("StatusBar", nil, root)
  bars.targetPow = tpow
  tpow:SetFrameStrata("HIGH")
  tpow:SetAlpha(1)
  tpow:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  tpow:SetMinMaxValues(0, UnitPowerMax("target", UnitPowerType("target")) or 1)
  tpow:SetValue(UnitPower("target") or 0)
  tpow:SetOrientation("VERTICAL")
  tpow:SetSize(barThickness, barHeight)
  tpow:SetPoint("LEFT", thp, "RIGHT", gap, 0)
  tpow:SetStatusBarColor(1,0,0)
  local tpowText = tpow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bars.targetPowText = tpowText
  tpowText:SetPoint("TOP", tpow, "BOTTOM", 0, -18)
  tpowText:SetJustifyH("CENTER")

  -- Add thin borders to target bars
  addThinBorder(thp)
  addThinBorder(tpow)

  -- Class cooldowns panel positioned under potion/hearth buttons (left-aligned)
  local cds = CreateFrame("Frame", nil, root)
  bars.cds = cds
  cds:ClearAllPoints()
  if H.potionBtn then
    cds:SetPoint("TOPLEFT", H.potionBtn, "BOTTOMLEFT", 0, -6)
  else
    cds:SetPoint("TOP", bars.combo, "BOTTOM", 0, -6)
  end
  cds:SetSize(120, 40)
  cds:SetFrameStrata("HIGH")
  cds:SetFrameLevel(root:GetFrameLevel()+40)
  bars.cdIcons = {}
  -- Class cooldowns now fully handled by Utilities.lua (H.classCDButtons)
  -- Keep this list empty to avoid duplicate rows here.
  local spells = {}
  local x = 0
  for i,id in ipairs(spells) do
    local name, _, icon = GetSpellInfo(id)
    if name and IsKnown(id) then
      local b = CreateFrame("Button", nil, cds, "SecureActionButtonTemplate")
      b:SetSize(28,28)
      b:SetPoint("LEFT", cds, "LEFT", x, 0)
      b:SetFrameStrata("HIGH")
      b:SetFrameLevel(cds:GetFrameLevel()+i)
      b:EnableMouse(true)
      local tex = b:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints(b)
      tex:SetTexture(icon or "Interface/Icons/INV_Misc_QuestionMark")
      b:SetAttribute("type", "spell")
      b:SetAttribute("spell", name) -- use localized name for reliability
      -- Tooltip
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        local ok = pcall(function() GameTooltip:SetSpellByID(id) end)
        if not ok then
          GameTooltip:ClearLines(); GameTooltip:AddLine(name,1,1,1); GameTooltip:Show()
        end
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      bars.cdIcons[#bars.cdIcons+1] = { btn=b, id=id }
      x = x + 32
    end
  end
end

function H.ApplyLayout()
  if not bars.hp or not bars.pow or not bars.targetHP or not bars.targetPow then return end
  local t = HardcoreHUDDB.layout and HardcoreHUDDB.layout.thickness or 12
  local bh = HardcoreHUDDB.layout and HardcoreHUDDB.layout.height or 200
  local gap = HardcoreHUDDB.layout and HardcoreHUDDB.layout.gap or 8
  local sep = HardcoreHUDDB.layout and HardcoreHUDDB.layout.separation or 140
  local centerOffsetY = HardcoreHUDDB.layout and HardcoreHUDDB.layout.centerOffsetY or 0
  bars.hp:SetSize(t, bh)
  bars.hp:ClearAllPoints(); bars.hp:SetPoint("RIGHT", H.root, "CENTER", -sep, centerOffsetY)
  bars.pow:SetSize(t, bh)
  bars.pow:ClearAllPoints(); bars.pow:SetPoint("LEFT", bars.hp, "RIGHT", gap, 0)
  if bars.tickFill then bars.tickFill:SetWidth(bars.pow:GetWidth()) end
  bars.targetHP:SetSize(t, bh)
  bars.targetHP:ClearAllPoints(); bars.targetHP:SetPoint("LEFT", H.root, "CENTER", sep, centerOffsetY)
  bars.targetPow:SetSize(t, bh)
  bars.targetPow:ClearAllPoints(); bars.targetPow:SetPoint("LEFT", bars.targetHP, "RIGHT", gap, 0)
  if H.ApplyBarTexture then H.ApplyBarTexture() end

  -- widen text spacing to avoid overlap
  if bars.hpText then
    bars.hpText:ClearAllPoints()
    bars.hpText:SetPoint("TOPLEFT", bars.hp, "BOTTOMLEFT", 0, -16)
  end
  if bars.powText then
    bars.powText:ClearAllPoints()
    bars.powText:SetPoint("TOPLEFT", bars.pow, "BOTTOMLEFT", 0, -32)
  end
  if bars.targetHPText then
    bars.targetHPText:ClearAllPoints()
    bars.targetHPText:SetPoint("TOPRIGHT", bars.targetHP, "BOTTOMRIGHT", 0, -16)
  end
  if bars.targetPowText then
    bars.targetPowText:ClearAllPoints()
    bars.targetPowText:SetPoint("TOPRIGHT", bars.targetPow, "BOTTOMRIGHT", 0, -32)
  end
end

function H.ReanchorCooldowns()
  if not bars.cds then return end
  bars.cds:ClearAllPoints()
  if H.utilRow then
    bars.cds:SetPoint("TOP", H.utilRow, "BOTTOM", 0, -6)
  else
    bars.cds:SetPoint("CENTER", H.root, "CENTER", 0, -20)
  end
end

function H.LayoutCombo()
  local combo = bars.combo
  local w = combo:GetWidth()
  local spacing = 4
  local size = 18
  local total = size*5 + spacing*4
  local startX = (w-total)/2
  for i=1,5 do
    local t = bars.comboIcons[i]
    t:ClearAllPoints()
    t:SetPoint("LEFT", combo, "LEFT", startX + (i-1)*(size+spacing), 0)
    t:SetSize(size, size)
  end
end

local lastManaCast = 0
local inFive = false
local manaTickStart = GetTime()
local manaPaused = true
local haveManaCycle = false
local energyCycle = 0
local hpPulseAcc = 0

function H.UpdateBarColors()
  -- Defensive: ensure color tables exist and are numeric; fall back to defaults
  local colors = HardcoreHUDDB and HardcoreHUDDB.colors
  local hpCol = (colors and colors.hp) or {0, 0.8, 0}
  local manaCol = (colors and colors.mana) or {0, 0.5, 1}
  local energyCol = (colors and colors.energy) or {1, 0.85, 0}
  local rageCol = (colors and colors.rage) or {0.8, 0.2, 0.2}
  local tickCol = (colors and colors.tick) or {0.9, 0.9, 0.9}
  local pType = UnitPowerType and UnitPowerType("player") or 0
  local r,g,b
  if pType == 0 then r,g,b = unpack(manaCol)
  elseif pType == 1 then r,g,b = unpack(rageCol)
  elseif pType == 3 then r,g,b = unpack(energyCol)
  else r,g,b = 0.7,0.7,0.7 end
  if bars.pow and bars.pow.SetStatusBarColor then bars.pow:SetStatusBarColor(r or 0, g or 0, b or 0) end
  local hr,hg,hb = unpack(hpCol)
  if bars.hp and bars.hp.SetStatusBarColor then bars.hp:SetStatusBarColor(hr or 0, hg or 0, hb or 0) end
  if bars.tick and bars.tick.SetStatusBarColor then bars.tick:SetStatusBarColor(unpack(tickCol)) end
end

function H.UpdatePower()
  local pType = UnitPowerType("player")
  local cur, max = GetUnitPowerAndMax("player", pType)
  bars.pow:SetMinMaxValues(0, max or 1)
  bars.pow:SetValue(cur or 0)
  bars.powText:SetText((cur or 0).."/"..(max or 0))
  -- color player power text by type
  if pType == 0 then
    bars.powText:SetTextColor(0, 0.5, 1)
  elseif pType == 1 then
    bars.powText:SetTextColor(0.8, 0.2, 0.2)
  elseif pType == 3 then
    bars.powText:SetTextColor(1, 0.85, 0)
  else
    bars.powText:SetTextColor(0.9,0.9,0.9)
  end
  H.UpdateBarColors()
  -- overlay visibility
  local ph = H.bars.pow:GetHeight()
  if pType == 0 then
    if inFive then pcall(function() bars.fsFill:Show() end) else pcall(function() bars.fsFill:Hide() end) end
    if cur == UnitPowerMax("player",0) then
      manaPaused=true; haveManaCycle=false;
      if bars.tickFill then pcall(function() bars.tickFill:Hide() end) end
    else
      if bars.tickFill then pcall(function() bars.tickFill:Show() end) end
    end
  elseif pType == 3 then
    -- switching to energy: clear mana state and show tick overlay
    pcall(function() bars.fsFill:Hide() end)
    manaPaused = true; haveManaCycle = false
    if bars.tickFill then pcall(function() bars.tickFill:Show() end) end
  else
    pcall(function() bars.fsFill:Hide() end); if bars.tickFill then bars.tickFill:SetHeight(0) end
  end
end

function H.UpdateHealth()
  bars.hp:SetMinMaxValues(0, UnitHealthMax("player"))
  local cur = UnitHealth("player")
  bars.hp:SetValue(cur)
  local maxHP = UnitHealthMax("player")
  bars.hpText:SetText(cur.."/"..maxHP)
  local pct = (maxHP>0) and (cur/maxHP) or 0
  local r,g,b
  if pct >= 0.5 then
    -- Green (0,1,0) to Yellow (1,1,0) as HP drops 100%->50%
    local t = (1 - pct) / 0.5 -- 0 at 100%, 1 at 50%
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    r = t; g = 1; b = 0
    H.bars.hpPulseActive = false
  elseif pct >= 0.3 then
    -- Yellow (1,1,0) to Orange (1,0.5,0) between 50%->30%
    local t = (0.5 - pct) / 0.2 -- 0 at 50%, 1 at 30%
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    r = 1; g = 1 - (t * 0.5); b = 0
    H.bars.hpPulseActive = false
  elseif pct >= 0.15 then
    -- Static orange 30%->15%
    r,g,b = 1,0.5,0
    H.bars.hpPulseActive = false
  else
    -- Critical: pulsating red
    r,g,b = 1,0.15,0
    H.bars.hpPulseActive = true
  end
  bars.hp:SetStatusBarColor(r,g,b)
  bars.hpText:SetTextColor(r,g*0.9 + 0.1,b) -- slight variance for readability
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  local critThresh = HardcoreHUDDB.warnings.criticalThreshold or 0.20
  if HardcoreHUDDB.warnings.criticalHP and UnitHealth("player")/UnitHealthMax("player") <= critThresh then
    H.ShowCriticalHPWarning()
  else
    if H.HideCriticalHPWarning then H.HideCriticalHPWarning() end
  end
  -- Target updates
  if UnitExists("target") then
    bars.targetHP:SetMinMaxValues(0, UnitHealthMax("target"))
    local tcur = UnitHealth("target")
    bars.targetHP:SetValue(tcur)
    bars.targetHPText:SetText((tcur or 0).."/"..(UnitHealthMax("target") or 0))
    local tpType = UnitPowerType("target")
    local tcurPow, tmaxPow = GetUnitPowerAndMax("target", tpType)
    bars.targetPow:SetMinMaxValues(0, tmaxPow or 1)
    bars.targetPow:SetValue(tcurPow or 0)
    bars.targetPowText:SetText((tcurPow or 0).."/"..(tmaxPow or 0))
    -- color target power text by type
    if tpType == 0 then
      bars.targetPowText:SetTextColor(0, 0.5, 1)
    elseif tpType == 1 then
      bars.targetPowText:SetTextColor(0.8, 0.2, 0.2)
    elseif tpType == 3 then
      bars.targetPowText:SetTextColor(1, 0.85, 0)
    else
      bars.targetPowText:SetTextColor(0.9,0.9,0.9)
    end
  end
end

function H.UpdateTarget()
  -- Skip visibility updates during combat
  if InCombatLockdown() then
    return
  end
  
  -- combo points
  local class = select(2, UnitClass("player"))
  local pType = UnitPowerType("player")
  local isCat = class == "DRUID" and pType == 3
  local show = class == "ROGUE" or isCat
  local comboIcons = bars and bars.comboIcons
  if show and comboIcons then
    local cp = GetComboPoints and GetComboPoints("player", "target") or 0
    for i=1,5 do
      local t = comboIcons[i]
      if t then
        t:Show()
        if cp>0 and i<=cp then
          local ratio = (i-1)/4
          if t.SetColorTexture then t:SetColorTexture(1 - ratio, ratio, 0, 1) end
        else
          if t.SetColorTexture then t:SetColorTexture(0.35,0.35,0.35,0.7) end
        end
      end
    end
  else
    if comboIcons then
      for i=1,5 do if comboIcons[i] and comboIcons[i].Hide then pcall(function() comboIcons[i]:Hide() end) end end
    end
  end
  -- skull warning (guard if Combat.lua not yet loaded)
  if H.CheckSkull then H.CheckSkull() end

  -- target bars
  if UnitExists("target") and bars.targetHP and bars.targetPow then
    bars.targetHP:Show(); bars.targetPow:Show(); bars.targetHP:SetAlpha(1); bars.targetPow:SetAlpha(1)
    if bars.targetHP._thinBorder then for _,t in pairs(bars.targetHP._thinBorder) do if t and t.Show then t:Show() end end end
    if bars.targetPow._thinBorder then for _,t in pairs(bars.targetPow._thinBorder) do if t and t.Show then t:Show() end end end
    -- color by reaction: red hostile, yellow neutral, green friendly
    local reaction = UnitReaction("player","target")
    local tr, tg, tb = 1, 0, 0 -- default red
    if reaction then
      if reaction >= 5 then tr,tg,tb = 0, 1, 0 -- friendly
      elseif reaction == 4 then tr,tg,tb = 1, 0.9, 0 -- neutral
      else tr,tg,tb = 1, 0, 0 -- hostile
      end
    else
      -- fallback: use UnitIsFriend/Enemy
      if UnitIsFriend("player","target") then tr,tg,tb = 0,1,0 elseif UnitIsEnemy("player","target") then tr,tg,tb = 1,0,0 else tr,tg,tb = 1,0.9,0 end
    end
    bars.targetHP:SetStatusBarColor(tr,tg,tb)
    -- target power color by type
    local tpType = UnitPowerType("target")
    if tpType == 0 then
      bars.targetPow:SetStatusBarColor(0, 0.5, 1) -- mana blue
    elseif tpType == 1 then
      bars.targetPow:SetStatusBarColor(0.8, 0.2, 0.2) -- rage red
    elseif tpType == 3 then
      bars.targetPow:SetStatusBarColor(1, 0.85, 0) -- energy yellow
    else
      bars.targetPow:SetStatusBarColor(0.7,0.7,0.7)
    end
    bars.targetHP:SetMinMaxValues(0, UnitHealthMax("target") or 1)
    local tcur = UnitHealth("target") or 0
    bars.targetHP:SetValue(tcur)
    if bars.targetHPText then bars.targetHPText:SetText(tcur.."/"..(UnitHealthMax("target") or 0)) end
    local tpType = UnitPowerType("target")
    local tcurPow, tmaxPow = GetUnitPowerAndMax("target", tpType)
    bars.targetPow:SetMinMaxValues(0, tmaxPow or 1)
    local tpcur = tcurPow or 0
    bars.targetPow:SetValue(tpcur)
    if bars.targetPowText then
      bars.targetPowText:SetText(tpcur.."/"..(tmaxPow or 0))
      if tpType == 0 then
        bars.targetPowText:SetTextColor(0, 0.5, 1)
      elseif tpType == 1 then
        bars.targetPowText:SetTextColor(0.8, 0.2, 0.2)
      elseif tpType == 3 then
        bars.targetPowText:SetTextColor(1, 0.85, 0)
      else
        bars.targetPowText:SetTextColor(0.9,0.9,0.9)
      end
    end
  else
    if bars.targetHP then
      pcall(function() bars.targetHP:Hide() end)
      if bars.targetHP._thinBorder then
        for _,t in pairs(bars.targetHP._thinBorder) do if t and t.Hide then pcall(function() t:Hide() end) end end
      end
    end
    if bars.targetPow then
      pcall(function() bars.targetPow:Hide() end)
      if bars.targetPow._thinBorder then
        for _,t in pairs(bars.targetPow._thinBorder) do if t and t.Hide then pcall(function() t:Hide() end) end end
      end
    end
  end
end

-- OnUpdate driver for timers
local driver = CreateFrame("Frame")
local last = GetTime()
driver:SetScript("OnUpdate", function(_, dt)
  local now = GetTime()
  local accum = now - last; if accum<0.02 then return end; last=now
  local pType = UnitPowerType("player")
  -- live power refresh to ensure energy updates immediately
  do
    local cur, max = GetUnitPowerAndMax("player", pType)
    if bars.pow then
      bars.pow:SetMinMaxValues(0, max or 1)
      bars.pow:SetValue(cur or 0)
      if bars.powText then bars.powText:SetText((cur or 0).."/"..(max or 0)) end
    end
  end
  local curMana, maxMana = GetUnitPowerAndMax("player", 0)
  -- five second rule
  if pType == 0 and inFive then
    local rem = FIVE - (now - lastManaCast)
    if rem <= 0 then inFive=false; pcall(function() bars.fsFill:Hide() end); manaPaused = (curMana==maxMana); haveManaCycle=false else
      local h = H.bars.pow:GetHeight() * (rem / FIVE)
      bars.fsFill:SetHeight(h)
      pcall(function() bars.fsFill:Show() end)
    end
  end
  -- mana tick detection
  if pType == 0 and not inFive and not manaPaused then
    local prev = (bars._prevMana or curMana)
    if curMana > prev then
      local since = now - manaTickStart
      if not haveManaCycle or since >= 1.5 then manaTickStart = now; haveManaCycle=true end
    end
    bars._prevMana = curMana
    if haveManaCycle then
      local diff = now - manaTickStart
      if diff >= MANA_TICK then manaTickStart = manaTickStart + MANA_TICK; diff = diff - MANA_TICK end
      local y = H.bars.pow:GetHeight() * (diff / MANA_TICK)
      if bars.tickFill then bars.tickFill:ClearAllPoints(); bars.tickFill:SetPoint("BOTTOM", H.bars.pow, "BOTTOM", 0, y); bars.tickFill:Show() end
    end
  end
  -- energy tick
  if pType == 3 then
    -- reset cycle on energy change to keep sync
    local prevEnergy = bars._prevEnergy or UnitPower("player",3)
    local curEnergy = UnitPower("player",3)
    if curEnergy ~= prevEnergy then
      energyCycle = 0
    end
    bars._prevEnergy = curEnergy
    energyCycle = energyCycle + accum
    if energyCycle >= ENERGY_TICK then energyCycle = energyCycle - ENERGY_TICK end
    local y = H.bars.pow:GetHeight() * (energyCycle / ENERGY_TICK)
    if bars.tickFill then bars.tickFill:ClearAllPoints(); bars.tickFill:SetPoint("BOTTOM", H.bars.pow, "BOTTOM", 0, y); bars.tickFill:Show() end
  end

  -- update cooldown overlays
  if bars.cdIcons then
    for _,info in ipairs(bars.cdIcons) do
      local start, dur, enable = GetSpellCooldown(info.id)
      if enable == 1 and dur and dur > 0 then
        -- could add cooldown spiral via CooldownFrame if available; simple alpha pulse
        info.btn:SetAlpha(0.6)
      else
        info.btn:SetAlpha(1.0)
      end
      -- Emergency pulse (reuse emergency config from Utilities)
      if HardcoreHUDDB.emergency and HardcoreHUDDB.emergency.enabled then
        local hp = UnitHealth("player") or 0
        local hpMax = UnitHealthMax("player") or 1
        local ratio = hpMax>0 and hp/hpMax or 1
        if ratio <= (HardcoreHUDDB.emergency.hpThreshold or 0.5) then
          local s,d,e = GetSpellCooldown(info.id)
          local ready = (e == 1 and d == 0)
          if ready then
            if not info.btn._pulseBorder then
              local pb = info.btn:CreateTexture(nil, "OVERLAY")
              pb:SetTexture("Interface/Buttons/UI-ActionButton-Border")
              pb:SetBlendMode("ADD")
              pb:SetPoint("CENTER", info.btn, "CENTER")
              pb:SetSize(info.btn:GetWidth()*1.6, info.btn:GetHeight()*1.6)
              info.btn._pulseBorder = pb
            end
            local pulseA = 0.35 + 0.35 * math.abs(math.sin(now*6))
            info.btn._pulseBorder:SetAlpha(pulseA)
            pcall(function() info.btn._pulseBorder:Show() end)
          else
            if info.btn._pulseBorder then pcall(function() info.btn._pulseBorder:Hide() end) end
          end
        else
          if info.btn._pulseBorder then pcall(function() info.btn._pulseBorder:Hide() end) end
        end
      end
    end
  end
  -- HP pulse when critical (<15%)
  if H.bars.hpPulseActive then
    hpPulseAcc = hpPulseAcc + accum
    local alpha = 0.6 + 0.4 * math.abs(math.sin(hpPulseAcc * 5))
    if bars.hp then bars.hp:SetAlpha(alpha) end
    if bars.hpText then bars.hpText:SetAlpha(alpha + 0.2) end
  else
    if bars.hp and bars.hp:GetAlpha() < 1 then bars.hp:SetAlpha(1) end
    if bars.hpText and bars.hpText:GetAlpha() < 1 then bars.hpText:SetAlpha(1) end
    hpPulseAcc = 0
  end
end)

-- Mana spend detection
-- Event-driven 5s rule start (only after successful mana spend)
do
  local preCastMana = UnitPower("player",0) or 0
  local lastFiveStart = 0
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("UNIT_SPELLCAST_START")
  watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  watcher:RegisterEvent("UNIT_SPELLCAST_FAILED")
  watcher:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  watcher:RegisterEvent("UNIT_SPELLCAST_SENT") -- covers instants without START
  watcher:SetScript("OnEvent", function(_, event, unit)
    if unit ~= "player" then return end
    if UnitPowerType("player") ~= 0 then return end -- only mana caster
    if event == "UNIT_SPELLCAST_START" then
      -- Snapshot mana before cost is applied
      preCastMana = UnitPower("player",0) or preCastMana
    elseif event == "UNIT_SPELLCAST_SENT" then
      -- Instant casts may not fire START; snapshot here as early baseline
      preCastMana = UnitPower("player",0) or preCastMana
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      local post = UnitPower("player",0) or preCastMana
      local function BeginFiveSec()
        if GetTime() - lastFiveStart < 0.05 then return end -- prevent double triggers
        lastFiveStart = GetTime()
        lastManaCast = lastFiveStart
        inFive = true
        manaPaused = true
        haveManaCycle = false
        if bars.tickFill then
          bars.tickFill:ClearAllPoints()
          bars.tickFill:SetPoint("BOTTOM", bars.pow, "BOTTOM", 0, 0)
          bars.tickFill:SetHeight(2)
        end
        if bars.fsFill then
          local w = (bars.pow and bars.pow:GetWidth()) or bars.fsFill:GetWidth()
          bars.fsFill:SetWidth(w)
          bars.fsFill:Show()
        end
      end
      if post < preCastMana then
        BeginFiveSec()
        preCastMana = post
      else
        -- Delayed check (instant spells sometimes deduct after SUCCEEDED)
        C_Timer.After(0.05, function()
          local after = UnitPower("player",0) or post
          if after < preCastMana then BeginFiveSec() end
          preCastMana = after
        end)
      end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
      -- Do not start; refresh baseline
      preCastMana = UnitPower("player",0) or preCastMana
    end
  end)
end

-- Leveling Progress Tracker
function H.InitLevelingTracker()
  if H.levelingTracker then return end
  
  HardcoreHUDDB.leveling = HardcoreHUDDB.leveling or {
    enabled = true,
    showXPBar = true,
    showRate = true,
    showTimeToLevel = true,
    showRested = true,
    showSessionTime = true,
    fontSize = 11,
    pos = { x = 0, y = -350 }
  }
  
  -- Initialize or restore session data from SavedVariables
  -- Session persists across reloads but resets on fresh login (logout/disconnect)
  HardcoreHUDDB.leveling.session = HardcoreHUDDB.leveling.session or {}
  local session = HardcoreHUDDB.leveling.session
  
  -- Check if this is a fresh login or a reload
  -- Fresh login: session.wasLogout is true (set on PLAYER_LOGOUT)
  -- Reload: session.wasLogout is false/nil and session data exists
  local currentTime = time()  -- Real-world time
  local currentLevel = UnitLevel("player") or 1
  local currentXP = UnitXP("player") or 0
  
  -- Detect fresh login: either wasLogout flag is set, or no session data, or level changed
  local isFreshLogin = session.wasLogout == true 
                    or not session.lastUpdateTime 
                    or (session.currentLevel and session.currentLevel ~= currentLevel)
  
  if not isFreshLogin and session.lastUpdateTime then
    -- Restore session data (this is a /reload)
    H._sessionStartTime = GetTime() - (session.elapsedTime or 0)
    H._levelStartTime = GetTime() - (session.levelElapsedTime or 0)
    H._lastKnownXP = session.lastKnownXP or currentXP
    H._lastKnownLevel = session.lastKnownLevel or currentLevel
    H._lastKnownLevelMax = session.lastKnownLevelMax or UnitXPMax("player")
    -- Clear the logout flag since we restored
    session.wasLogout = false
  else
    -- Fresh login - start new session
    H._sessionStartTime = GetTime()
    H._levelStartTime = GetTime()  -- Time spent on this level starts now
    H._lastKnownXP = currentXP
    H._lastKnownLevel = currentLevel
    H._lastKnownLevelMax = UnitXPMax("player") or 1
    -- Clear logout flag
    session.wasLogout = false
  end
  
  local f = CreateFrame("Frame", "HardcoreHUDLevelingTracker", UIParent)
  H.levelingTracker = f
  f:SetSize(320, 65)
  f:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.leveling.pos.x or 0, HardcoreHUDDB.leveling.pos.y or -400)
  f:SetFrameStrata("HIGH")
  f:Hide()
  
  -- Simple background - minimal
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0, 0, 0, 0)  -- Transparent
  
  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
  title:SetText("LEVELING")
  title:SetTextColor(0.2, 0.8, 1, 1)
  if STANDARD_TEXT_FONT then title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE") end
  f.title = title
  
  -- Level text (on right)
  local levelText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  levelText:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
  levelText:SetText("Level: 1")
  levelText:SetTextColor(1, 0.84, 0, 1)
  if STANDARD_TEXT_FONT then levelText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE") end
  f.levelText = levelText
  
  -- XP Bar (clean and simple)
  local xpBar = CreateFrame("StatusBar", nil, f)
  xpBar:SetSize(320, 12)
  xpBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
  xpBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  xpBar:SetMinMaxValues(0, 100)
  xpBar:SetValue(50)
  xpBar:SetStatusBarColor(0.1, 0.6, 1, 0.9)
  
  -- XP Bar background
  local xpBg = xpBar:CreateTexture(nil, "BACKGROUND")
  xpBg:SetAllPoints(xpBar)
  xpBg:SetColorTexture(0.05, 0.05, 0.08, 0.9)
  f.xpBar = xpBar
  
  -- Rested XP overlay (orange texture)
  local restedOverlay = xpBar:CreateTexture(nil, "OVERLAY")
  restedOverlay:SetTexture("Interface/TargetingFrame/UI-StatusBar")
  restedOverlay:SetTexCoord(0, 1, 0, 1)  -- Prevent texture stretching
  restedOverlay:SetVertexColor(1.0, 0.5, 0.0, 0.7)  -- Orange
  restedOverlay:Hide()
  f.restedOverlay = restedOverlay
  
  -- Quest XP overlay (green texture)
  local questOverlay = xpBar:CreateTexture(nil, "OVERLAY")
  questOverlay:SetTexture("Interface/TargetingFrame/UI-StatusBar")
  questOverlay:SetTexCoord(0, 1, 0, 1)  -- Prevent texture stretching
  questOverlay:SetVertexColor(0.0, 1.0, 0.3, 0.6)  -- Green
  questOverlay:Hide()
  f.questOverlay = questOverlay
  
  -- XP Text (on bar)
  local xpText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  xpText:SetPoint("CENTER", xpBar, "CENTER", 0, 0)
  xpText:SetText("50%")
  xpText:SetTextColor(1, 1, 1, 1)
  if STANDARD_TEXT_FONT then xpText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE") end
  xpText:SetShadowColor(0, 0, 0, 0.8)
  xpText:SetShadowOffset(1, -1)
  f.xpText = xpText
  
  -- Info line (Session time)
  local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  info:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -38)
  info:SetText("Session: 0h 0m  |  Rested: 0%")
  info:SetTextColor(0.7, 0.9, 1, 0.8)
  local fontSize = HardcoreHUDDB.leveling.fontSize or 11
  if STANDARD_TEXT_FONT then info:SetFont(STANDARD_TEXT_FONT, fontSize, "") end
  f.info = info
  
  -- Make draggable
  local function onDragStart(self)
    if not HardcoreHUDDB.leveling.locked then
      self:StartMoving()
    end
  end
  
  local function onDragStop(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local px, py = UIParent:GetCenter()
    HardcoreHUDDB.leveling.pos.x = x - px
    HardcoreHUDDB.leveling.pos.y = y - py
  end
  
  f:SetMovable(true)
  f:SetUserPlaced(false)
  f:SetScript("OnMouseDown", onDragStart)
  f:SetScript("OnMouseUp", onDragStop)
  
  -- Update thread
  if not H._levelingUpdateFrame then
    local uf = CreateFrame("Frame")
    H._levelingUpdateFrame = uf
    local acc = 0
    uf:SetScript("OnUpdate", function(_, dt)
      acc = acc + dt
      if acc >= 0.5 then
        acc = 0
        H.UpdateLevelingTracker()
      end
    end)
  end
  
  -- Track XP gains for session rate calculation
  if not H._xpTrackingFrame then
    local xpf = CreateFrame("Frame")
    H._xpTrackingFrame = xpf
    
    -- Helper function to save session data to SavedVariables
    local function SaveSessionData(isLogout)
      if not HardcoreHUDDB.leveling then return end
      HardcoreHUDDB.leveling.session = HardcoreHUDDB.leveling.session or {}
      local session = HardcoreHUDDB.leveling.session
      session.elapsedTime = GetTime() - (H._sessionStartTime or GetTime())
      session.levelElapsedTime = GetTime() - (H._levelStartTime or GetTime())
      session.lastKnownXP = H._lastKnownXP
      session.lastKnownLevel = H._lastKnownLevel
      session.lastKnownLevelMax = H._lastKnownLevelMax
      session.currentLevel = UnitLevel("player")
      session.lastUpdateTime = time()  -- Real-world time
      -- Mark as logout so next load knows to reset session
      if isLogout then
        session.wasLogout = true
      end
    end
    
    xpf:RegisterEvent("PLAYER_XP_UPDATE")
    xpf:RegisterEvent("PLAYER_LEVEL_UP")
    xpf:RegisterEvent("PLAYER_LOGOUT")
    xpf:SetScript("OnEvent", function(self, event, ...)
      local currentXP = UnitXP("player") or 0
      local currentLevel = UnitLevel("player") or 1
      
      if event == "PLAYER_LOGOUT" then
        -- Save session data with logout flag
        SaveSessionData(true)
        return
      end
      
      if event == "PLAYER_LEVEL_UP" then
        -- Level up! Reset level timer
        H._levelStartTime = GetTime()
        H._lastKnownXP = currentXP
        H._lastKnownLevel = currentLevel
        H._lastKnownLevelMax = UnitXPMax("player") or 1
        SaveSessionData(false)
        if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.leveling then
          print(string.format("[HardcoreHUD] Level up! New level: %d", currentLevel))
        end
      elseif event == "PLAYER_XP_UPDATE" then
        -- Track XP changes
        H._lastKnownXP = currentXP
        H._lastKnownLevel = currentLevel
        H._lastKnownLevelMax = UnitXPMax("player") or 1
        SaveSessionData(false)
      end
    end)
    
    -- Also save periodically (every 30 seconds) in case of crash
    local saveAcc = 0
    xpf:SetScript("OnUpdate", function(_, dt)
      saveAcc = saveAcc + dt
      if saveAcc >= 30 then
        saveAcc = 0
        SaveSessionData(false)
      end
    end)
  end
end

function H.UpdateLevelingTracker()
  if not H.levelingTracker then return end
  if not HardcoreHUDDB.leveling.enabled then H.levelingTracker:Hide() return end
  
  local f = H.levelingTracker
  local level = UnitLevel("player")
  local xpCurrent = UnitXP("player") or 0
  local xpMax = UnitXPMax("player") or 0
  
  -- At max level, xpMax is 0 - hide the tracker or show "Max Level"
  if xpMax <= 0 then
    f.levelText:SetText(string.format("Level: %d (Max)", level))
    f.xpBar:SetValue(100)
    f.xpBar:SetStatusBarColor(0.8, 0.6, 0, 0.9)  -- Gold color for max level
    f.xpText:SetText("Max Level")
    f.questOverlay:Hide()
    f.restedOverlay:Hide()
    f.info:SetText("")
    f:Show()
    return
  end
  
  local xpPercent = (xpCurrent / xpMax) * 100
  
  f:Show()
  
  -- Level
  f.levelText:SetText(string.format("Level: %d", level))
  
  -- XP Bar - show/hide based on option
  local opts = HardcoreHUDDB.leveling
  if opts.showXPBar ~= false then
    -- Calculate completed quest XP
    -- IMPORTANT: Save and restore original quest selection to avoid interfering with QuestLog UI
    local originalSelection = GetQuestLogSelection and GetQuestLogSelection() or 0
    local questXP = 0
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
      local title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      if not isHeader and isComplete and isComplete > 0 then
        if SelectQuestLogEntry then SelectQuestLogEntry(i) end
        local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
        questXP = questXP + xp
      end
    end
    -- Restore original quest selection
    if originalSelection > 0 and SelectQuestLogEntry then
      SelectQuestLogEntry(originalSelection)
    end
    
    -- Set main XP bar (blue)
    f.xpBar:SetValue(xpPercent)
    f.xpBar:SetStatusBarColor(0.1, 0.6, 1, 0.9)
    
    -- Calculate positions for overlays based on bar dimensions
    local barWidth = 320  -- XP bar width from creation
    local barHeight = 12
    
    -- Hide rested XP overlay (not used)
    f.restedOverlay:Hide()
    
    -- Quest XP overlay (green) - starts where current XP ends
    local questPercent = math.min((questXP / xpMax) * 100, 100 - xpPercent)
    local questStartX = (xpPercent / 100) * barWidth
    local questWidth = (questPercent / 100) * barWidth
    
    if questXP > 0 and questPercent > 0 and questWidth > 1 then
      f.questOverlay:ClearAllPoints()
      f.questOverlay:SetPoint("LEFT", f.xpBar, "LEFT", questStartX, 0)
      f.questOverlay:SetSize(questWidth, barHeight)
      f.questOverlay:Show()
    else
      f.questOverlay:Hide()
    end
    
    f.xpText:SetText(string.format("%.0f%%", xpPercent))
    f.xpBar:Show()
    f.xpText:Show()
  else
    f.xpBar:Hide()
    f.restedOverlay:Hide()
    f.questOverlay:Hide()
    f.xpText:Hide()
  end
  
  -- Build info text based on enabled options
  local infoLines = {}
  
  -- Session time
  if opts.showSessionTime ~= false then
    local sessionTime = GetTime() - (H._sessionStartTime or GetTime())
    local sHours = math.floor(sessionTime / 3600)
    local sMins = math.floor((sessionTime % 3600) / 60)
    table.insert(infoLines, string.format("Session: %dh %dm", sHours, sMins))
  end
  
  -- Rested XP
  if opts.showRested ~= false then
    local restedXP = (GetXPExhaustion() or 0) / xpMax * 100
    table.insert(infoLines, string.format("Rested: %.0f%%", restedXP))
  end
  
  -- XP Rate (based on TOTAL current level XP / time on this level)
  -- Example: 5000/12000 XP after 2 hours = 2500 XP/h
  if opts.showRate ~= false then
    local levelElapsed = GetTime() - (H._levelStartTime or GetTime())
    -- Current XP on this level is the total XP earned this level
    local levelXP = xpCurrent  -- This IS the XP earned on this level
    if levelElapsed > 60 and levelXP > 0 then  -- Wait at least 1 min for accurate rate
      local xpPerHour = (levelXP / levelElapsed) * 3600
      table.insert(infoLines, string.format("Rate: %.0f/h", xpPerHour))
    elseif levelXP > 0 then
      table.insert(infoLines, string.format("Rate: %d XP", levelXP))
    else
      table.insert(infoLines, "Rate: --")
    end
  end
  
  -- Time to Level (based on current level XP rate)
  if opts.showTimeToLevel ~= false then
    local levelElapsed = GetTime() - (H._levelStartTime or GetTime())
    local levelXP = xpCurrent
    if levelElapsed > 60 and levelXP > 0 then  -- Need some data for TTL
      local xpPerSecond = levelXP / levelElapsed
      local remainingXP = xpMax - xpCurrent
      local secondsToLevel = remainingXP / xpPerSecond
      local hours = math.floor(secondsToLevel / 3600)
      local mins = math.floor((secondsToLevel % 3600) / 60)
      if hours > 0 then
        table.insert(infoLines, string.format("TTL: %dh %dm", hours, mins))
      else
        table.insert(infoLines, string.format("TTL: %dm", mins))
      end
    else
      table.insert(infoLines, "TTL: --")
    end
  end
  
  -- Show/hide info line based on whether there's content
  if #infoLines > 0 then
    f.info:SetText(table.concat(infoLines, "  |  "))
    f.info:Show()
  else
    f.info:Hide()
  end
end

function H.ToggleLevelingTracker()
  if not H.levelingTracker then H.InitLevelingTracker() end
  if H.levelingTracker:IsShown() then
    H.levelingTracker:Hide()
    HardcoreHUDDB.leveling.enabled = false
  else
    H.levelingTracker:Show()
    HardcoreHUDDB.leveling.enabled = true
    H.UpdateLevelingTracker()
  end
end
