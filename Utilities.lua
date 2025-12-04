local H = HardcoreHUD
HardcoreHUDDB = HardcoreHUDDB or {}
-- Ensure saved variables table exists before any access
HardcoreHUDDB = HardcoreHUDDB or {}
H.UtilitiesVersion = "2025-11-29b"

-- Healing potion itemIDs (Wrath 3.3.5 common)
-- Healing potion ranks (Wrath 3.3.5). Highest rank should be used on button.
-- Explicit potency ordering instead of relying on itemID numeric value.
local HEAL_POTION_RANKS = {
  [118]   = 1,  -- Minor Healing Potion
  [858]   = 2,  -- Lesser Healing Potion
  [929]   = 3,  -- Healing Potion
  [1710]  = 4,  -- Greater Healing Potion
  [3928]  = 5,  -- Superior Healing Potion
  [13446] = 6,  -- Major Healing Potion
  [22829] = 7,  -- Super Healing Potion
  [33447] = 8,  -- Runic Healing Potion
}
-- Ensure reminders react to aura changes and combat transitions so icons reappear when buffs expire in combat.
if not H._reminderEvents then
  H._reminderEvents = CreateFrame("Frame", nil, UIParent)
  H._reminderEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
  H._reminderEvents:RegisterEvent("UNIT_AURA")
  H._reminderEvents:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
  H._reminderEvents:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leaving combat
  H._reminderEvents:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  H._reminderEvents:SetScript("OnEvent", function(self, event, ...)
    if not HardcoreHUDDB or not HardcoreHUDDB.reminders or HardcoreHUDDB.reminders.enabled == false then return end
    if event == "PLAYER_ENTERING_WORLD" then
      if H.InitReminders then H.InitReminders() end
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame and HardcoreHUDDB.reminders.enabled then H.reminderFrame:Show() end
    elseif event == "UNIT_AURA" then
      local unit = ...
      if unit == "player" then
        if H.UpdateReminders then H.UpdateReminders() end
      end
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- In combat, re-evaluate missing buffs; keep frame visible if enabled
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame and HardcoreHUDDB.reminders.enabled then H.reminderFrame:Show() end
    elseif event == "PLAYER_REGEN_ENABLED" then
      -- Out of combat, refresh once; visibility managed by UpdateReminders
      if H.UpdateReminders then H.UpdateReminders() end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      -- Older clients pass combat log args directly via ...
      local timestamp, subEvent, hideCaster,
            srcGUID, srcName, srcFlags, srcRaidFlags,
            destGUID, destName, destFlags, destRaidFlags,
            spellId = ...
      if subEvent == "SPELL_AURA_REMOVED" and destGUID == UnitGUID("player") then
        -- Refresh reminders immediately; if no icons are present, force a rebuild.
        if H.UpdateReminders then H.UpdateReminders() end
        local empty = false
        if H.reminderFrame and H.reminderFrame.icons then
          local count = #H.reminderFrame.icons
          empty = (not count or count == 0)
        end
        if empty and H.InitReminders then
          H.InitReminders()
          if H.UpdateReminders then H.UpdateReminders() end
        end
        if H.reminderFrame and HardcoreHUDDB.reminders and HardcoreHUDDB.reminders.enabled then
          H.reminderFrame:Show()
        end
      end
    end
  end)
end

-- First Aid bandages (Wrath 3.3.5)
local BANDAGE_RANKS = {
  [1251]  = 1,  -- Linen Bandage
  [2581]  = 2,  -- Heavy Linen Bandage
  [3530]  = 3,  -- Wool Bandage
  [3531]  = 4,  -- Heavy Wool Bandage
  [6450]  = 5,  -- Silk Bandage
  [6451]  = 6,  -- Heavy Silk Bandage
  [8544]  = 7,  -- Mageweave Bandage
  [8545]  = 8,  -- Heavy Mageweave Bandage
  [14529] = 9,  -- Runecloth Bandage
  [14530] = 10, -- Heavy Runecloth Bandage
  [21990] = 11, -- Netherweave Bandage
  [21991] = 12, -- Heavy Netherweave Bandage
  [34721] = 13, -- Frostweave Bandage
  [34722] = 14, -- Heavy Frostweave Bandage
}

local function findHighestPotion()
  local bestBag, bestSlot, bestName, bestRank, bestID = nil,nil,nil,0,nil
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local itemID = GetContainerItemID(bag, slot)
      if itemID and HEAL_POTION_RANKS[itemID] then
        local rank = HEAL_POTION_RANKS[itemID]
        local name = GetItemInfo(itemID) or GetContainerItemLink(bag,slot) or "Healing Potion"
        if rank > bestRank then bestRank = rank; bestBag=bag; bestSlot=slot; bestName=name; bestID=itemID end
      end
    end
  end
  return bestBag, bestSlot, bestName, bestID
end

local function findHighestBandage()
  local bestName, bestID, bestRank
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local itemID = GetContainerItemID(bag, slot)
      if itemID and BANDAGE_RANKS[itemID] then
        local rank = BANDAGE_RANKS[itemID]
        if not bestRank or rank > bestRank then
          bestRank = rank
          bestID = itemID
          bestName = GetItemInfo(itemID) or GetContainerItemLink(bag,slot) or "Bandage"
        end
      end
    end
  end
  return bestName, bestID
end

-- Helper to attach a robust spell tooltip (Wrath 3.3.5 compatible)
local function AttachSpellTooltip(btn, spellID)
  btn.spellID = spellID
  btn:EnableMouse(true)
  btn:SetFrameStrata("HIGH")
  btn:RegisterForClicks("AnyUp")
  btn:SetFrameLevel((btn:GetParent() and btn:GetParent():GetFrameLevel() or 10) + 5)

  local function FindSpellBookIndex(id)
    local i = 1
    while true do
      local link = GetSpellLink(i, "spell")
      if not link then break end
      local found = link:match("spell:(%d+)")
      if found and tonumber(found) == id then return i end
      i = i + 1
      if i > 300 then break end
    end
    return nil
  end

  btn:SetScript("OnEnter", function(self)
    if H.ShowUnifiedTooltip then H.ShowUnifiedTooltip(self, self.spellID) end
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip:IsVisible() then GameTooltip:Hide() end
  end)
end

function H.BuildUtilities()
  -- Potion count and click-to-use
  local p = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.potionBtn = p
  -- Place utilities below the combo bar, above the cooldown bar
  if H.bars and H.bars.combo then
    p:ClearAllPoints()
    p:SetPoint("TOP", H.bars.combo, "BOTTOM", -20, -8)
  elseif H.bars and H.bars.pow then
    p:ClearAllPoints()
    p:SetPoint("TOP", H.bars.pow, "BOTTOM", -20, -8)
  else
    p:ClearAllPoints()
    p:SetPoint("CENTER", UIParent, "CENTER", -20, -40)
  end
  p:SetSize(28,28)
  if p.SetFrameStrata then p:SetFrameStrata("HIGH") end
  local ptex = p:CreateTexture(nil, "ARTWORK")
  ptex:SetAllPoints(p)
  -- Use a healing potion-looking icon for the button default
  ptex:SetTexture("Interface/Icons/INV_Potion_54")
  p.icon = ptex
  local pDim = p:CreateTexture(nil, "OVERLAY")
  pDim:SetAllPoints(p)
  pDim:SetColorTexture(0,0,0,0.55)
  pDim:Hide()
  p.dim = pDim
  pDim:SetAllPoints(p)
  pDim:SetColorTexture(0,0,0,0.55)
  pDim:Hide()
  p.dim = pDim
  local pCd = CreateFrame("Cooldown", nil, p, "CooldownFrameTemplate")
  pCd:SetAllPoints(p)
  pCd:Hide()
  p.cooldown = pCd
  local cnt = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cnt:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT")
  H.potionCount = cnt
  local pText = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pText:SetPoint("CENTER", p, "CENTER", 0, 0)
  if STANDARD_TEXT_FONT then pText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
  pText:SetShadowColor(0,0,0,1)
  pText:SetShadowOffset(1,-1)
  p.cdText = pText
  p:SetAttribute("type", "item")
  
  -- Bandage button (self-use via macro)
  local bdg = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.bandageBtn = bdg
  if H.bars and H.bars.combo then
    bdg:ClearAllPoints()
    bdg:SetPoint("TOP", H.bars.combo, "BOTTOM", -52, -8)
  elseif H.bars and H.bars.pow then
    bdg:ClearAllPoints()
    bdg:SetPoint("TOP", H.bars.pow, "BOTTOM", -52, -8)
  else
    bdg:ClearAllPoints()
    bdg:SetPoint("CENTER", UIParent, "CENTER", -72, -40)
  end
  bdg:SetSize(28,28)
  if bdg.SetFrameStrata then bdg:SetFrameStrata("HIGH") end
  local btex = bdg:CreateTexture(nil, "ARTWORK")
  btex:SetAllPoints(bdg)
  btex:SetTexture("Interface/Icons/INV_Misc_Bandage_Frostweave_Heavy")
  bdg.icon = btex
  local bDim = bdg:CreateTexture(nil, "OVERLAY")
  bDim:SetColorTexture(0,0,0,0.55)
  bDim:Hide()
  bdg.dim = bDim
  local bCd = CreateFrame("Cooldown", nil, bdg, "CooldownFrameTemplate")
  bCd:SetAllPoints(bdg)
  bCd:Hide()
  bdg.cooldown = bCd
  local bCount = bdg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bCount:SetPoint("BOTTOMRIGHT", bdg, "BOTTOMRIGHT")
  bdg.countText = bCount
  local bText = bdg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bText:SetPoint("CENTER", bdg, "CENTER", 0, 0)
  if STANDARD_TEXT_FONT then bText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
  bText:SetShadowOffset(1,-1)
  bdg.cdText = bText
  bdg:SetAttribute("type", "macro")
  -- Hearthstone
  local hs = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.hearthBtn = hs
  if H.bars and H.bars.combo then
    hs:ClearAllPoints()
    hs:SetPoint("TOP", H.bars.combo, "BOTTOM", 20, -8)
  elseif H.bars and H.bars.pow then
    hs:ClearAllPoints()
    hs:SetPoint("TOP", H.bars.pow, "BOTTOM", 20, -8)
  else
    hs:ClearAllPoints()
    hs:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
  end
  hs:SetSize(28,28)
  if hs.SetFrameStrata then hs:SetFrameStrata("HIGH") end
  local hst = hs:CreateTexture(nil, "ARTWORK")
  hst:SetAllPoints(hs)
  hst:SetTexture("Interface/Icons/INV_Misc_Rune_01")
  hs.icon = hst
  local hDim = hs:CreateTexture(nil, "OVERLAY")
  hDim:SetAllPoints(hs)
  hDim:SetColorTexture(0,0,0,0.55)
  hDim:Hide()
  hs.dim = hDim
  local hCd = CreateFrame("Cooldown", nil, hs, "CooldownFrameTemplate")
  hCd:SetAllPoints(hs)
  hCd:Hide()
  hs.cooldown = hCd
  local hText = hs:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hText:SetPoint("CENTER", hs, "CENTER", 0, 0)
  if STANDARD_TEXT_FONT then hText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
  hText:SetShadowColor(0,0,0,1)
  hText:SetShadowOffset(1,-1)
  hs.cdText = hText
  hs:SetAttribute("type", "item")
  hs:SetAttribute("item", "Hearthstone")
  hs.itemID = 6948

  -- update counts
  local updater = CreateFrame("Frame")
  updater:RegisterEvent("BAG_UPDATE")
  updater:RegisterEvent("PLAYER_LOGIN")
  updater:SetScript("OnEvent", function()
    local bag, slot, name, itemID = findHighestPotion()
    if name then p:SetAttribute("item", name); p.itemID = itemID end
    local total = 0
    for bag=0,4 do
      local slots = GetContainerNumSlots(bag) or 0
      for slot=1,slots do
        local id = GetContainerItemID(bag,slot)
        if id and HEAL_POTION_RANKS[id] then
          local _,count = GetContainerItemInfo(bag,slot)
          total = total + (count or 1)
        end
      end
    end
    cnt:SetText(total)
    -- Bandage update
    local bname, bid = findHighestBandage()
    if bname and bid then
      bdg.itemID = bid
      local useMacro
      -- Prefer ID-based macro to avoid locale/cache issues
      useMacro = "/use [@player] item:"..tostring(bid)
      -- Fallback to name if needed
      if not useMacro or useMacro == "" then
        local cleanName = bname
        if string.find(cleanName, "|Hitem:") then
          local bracket = string.match(cleanName, "|h%[(.-)%]|h")
          if bracket then cleanName = bracket end
        end
        useMacro = "/use [@player] "..cleanName
      end
      bdg:SetAttribute("macrotext", useMacro)
      -- update icon to match the best bandage if info available
      local tex = select(10, GetItemInfo(bid))
      if tex and bdg.icon then bdg.icon:SetTexture(tex) end
      local btotal = 0
      for bag=0,4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot=1,slots do
          local id = GetContainerItemID(bag,slot)
          if id == bid then
            local _,count = GetContainerItemInfo(bag,slot)
            btotal = btotal + (count or 1)
          elseif id and BANDAGE_RANKS[id] and (BANDAGE_RANKS[id] < BANDAGE_RANKS[bid]) then
            local _,count = GetContainerItemInfo(bag,slot)
            btotal = btotal + (count or 1)
          end
        end
      end
      if bdg.countText then bdg.countText:SetText(btotal) end
      bdg:Show()
    else
      -- Always show bandage button even when none are in bags
      bdg.itemID = nil
      bdg:SetAttribute("macrotext", "")
      if bdg.countText then bdg.countText:SetText(0) end
      -- Set a generic bandage icon and desaturate to indicate none available
      local tex = "Interface/Icons/INV_Misc_Bandage_Frostweave_Heavy"
      if bdg.icon then bdg.icon:SetTexture(tex) end
      if bdg.icon and bdg.icon.SetDesaturated then bdg.icon:SetDesaturated(true) end
      if bdg.dim then bdg.dim:Show() end
      bdg:Show()
    end
    if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.potions then
      DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] Potion count="..total)
    end
  end)
  -- Delayed first update (item info cache)
  C_Timer.After(2, function() if updater:GetScript("OnEvent") then updater:GetScript("OnEvent")() end end)

  -- Utility row container spanning potion and hearth buttons
  local row = CreateFrame("Frame", nil, UIParent)
  H.utilRow = row
  row:SetSize((p:GetWidth() + hs:GetWidth() + bdg:GetWidth() + 12), math.max(p:GetHeight(), hs:GetHeight()))
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)

  -- Class cooldown buttons (only if spell learned)
  local class = select(2, UnitClass("player"))
  local cdsByClass = {
    WARRIOR = {871,12975,1719,2565}, -- Shield Wall, Last Stand, Recklessness, Shield Block
    ROGUE = {1856,5277,31224,2983}, -- Vanish, Evasion, Cloak of Shadows, Sprint
    MAGE = {45438,66,1953}, -- Ice Block, Invisibility, Blink
    DRUID = {22812,61336,22842}, -- Barkskin, Survival Instincts, Frenzied Regeneration
    PALADIN = {642,498,633,1022,31884}, -- Divine Shield, Divine Protection, Lay on Hands, Hand of Protection, Avenging Wrath
    HUNTER = {5384,19263,781}, -- Feign Death, Deterrence, Disengage
    WARLOCK = {18708,47891}, -- Fel Domination, Shadow Ward
    PRIEST = {47585,33206,586,8122}, -- Dispersion, Pain Suppression, Fade, Psychic Scream
    SHAMAN = {30823,2825,32182}, -- Shamanistic Rage, Bloodlust, Heroism
  }
  local spellList = cdsByClass[class] or {}
  local buttons = {}
  local anchorY = -46 -- place below potion/hearth row
  local anchorParent = H.bars and H.bars.combo or UIParent
  local startX = -((#spellList * 30) / 2) + 15
  local function IsKnown(id)
    -- Direct APIs first
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    -- Fallback: match by spell NAME (handles rank differences)
    local targetName = GetSpellInfo and select(1, GetSpellInfo(id)) or nil
    if not targetName or targetName == "" then
      -- As a last resort, try to resolve via spellbook link id
      local i = 1
      while true do
        local name = GetSpellBookItemName and GetSpellBookItemName(i, BOOKTYPE_SPELL) or nil
        if not name then break end
        local link = GetSpellLink(i, BOOKTYPE_SPELL)
        if link then
          local found = link:match("spell:(%d+)")
          if found and tonumber(found) == id then return true end
        end
        i = i + 1
        if i > 300 then break end
      end
      return false
    end
    -- Scan spellbook for any rank of the targetName
    -- Some servers append ranks in the name (e.g., "Name (Rank 2)")
    local i = 1
    while true do
      local name = GetSpellBookItemName and GetSpellBookItemName(i, BOOKTYPE_SPELL) or nil
      if not name then break end
      if name == targetName then return true end
      -- Prefix/substring match to tolerate appended rank text
      if targetName and name and string.find(name, targetName, 1, true) then return true end
      i = i + 1
      if i > 300 then break end
    end
    return false
  end
  local added = 0
  for i, spellID in ipairs(spellList) do
    if IsKnown(spellID) then
      local name, _, icon = GetSpellInfo(spellID)
      if name then
        local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        b:SetSize(28,28)
        -- Position using sequential index of added buttons to avoid gaps/overlaps
        added = added + 1
        b:SetPoint("TOP", anchorParent, "BOTTOM", startX + (added-1)*32, anchorY)
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", name)
        b:SetFrameStrata("HIGH")
        b:SetFrameLevel(70 + added)
        b:SetHitRectInsets(0,0,0,0)
        local it = b:CreateTexture(nil, "ARTWORK")
        it:SetAllPoints(b)
        it:SetTexture(icon)
        b.icon = it
        -- Darken overlay when on cooldown for better visibility
        local dim = b:CreateTexture(nil, "OVERLAY")
        dim:SetAllPoints(b)
        dim:SetColorTexture(0,0,0,0.55)
        dim:Hide()
        b.dim = dim
        -- Blizzard cooldown spiral
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints(b)
        cd:Hide()
        b.cooldown = cd
        -- Big, outlined countdown text
        local cdText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cdText:ClearAllPoints()
        cdText:SetPoint("CENTER", b, "CENTER", 0, 0)
        if STANDARD_TEXT_FONT then cdText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
        cdText:SetShadowColor(0,0,0,1)
        cdText:SetShadowOffset(1,-1)
        b.cdText = cdText
        AttachSpellTooltip(b, spellID)
        buttons[#buttons+1] = b
      end
    end
  end
  -- Add racial cooldown button (e.g., Will of the Forsaken for Undead)
  local function AddRacial()
    local race = select(2, UnitRace("player"))
    local racialSpellID
    if race == "Scourge" or race == "Undead" then racialSpellID = 7744 end -- Will of the Forsaken
    -- Add more as needed
    if racialSpellID and IsKnown(racialSpellID) then
      local name, _, icon = GetSpellInfo(racialSpellID)
      if name then
        local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        b:SetSize(28,28)
        -- place after existing buttons
        local idx = #buttons + 1
        b:SetPoint("TOP", anchorParent, "BOTTOM", startX + (idx-1)*32, anchorY)
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", name)
        b:SetFrameStrata("HIGH")
        b:SetFrameLevel(70 + idx)
        local it = b:CreateTexture(nil, "ARTWORK")
        it:SetAllPoints(b)
        it:SetTexture(icon)
        b.icon = it
        local dim = b:CreateTexture(nil, "OVERLAY")
        dim:SetAllPoints(b)
        dim:SetColorTexture(0,0,0,0.55)
        dim:Hide()
        b.dim = dim
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints(b); cd:Hide(); b.cooldown = cd
        local cdText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cdText:SetPoint("CENTER", b, "CENTER", 0, 0)
        if STANDARD_TEXT_FONT then cdText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
        cdText:SetShadowColor(0,0,0,1); cdText:SetShadowOffset(1,-1)
        b.cdText = cdText
        b.spellID = racialSpellID
        AttachSpellTooltip(b, racialSpellID)
        buttons[#buttons+1] = b
      end
    end
  end
  AddRacial()
  H.classCDButtons = buttons

  -- Emergency CD configuration (pulsing border when ready & HP below threshold)
  HardcoreHUDDB.emergency = HardcoreHUDDB.emergency or { enabled = true, hpThreshold = 0.50 }
  local EMERGENCY_SPELLS = {
    [871]=true,    -- Shield Wall
    [12975]=true,  -- Last Stand
    [2565]=true,   -- Shield Block
    [5277]=true,   -- Evasion
    [31224]=true,  -- Cloak of Shadows
    [1856]=true,   -- Vanish (escape)
    [642]=true,    -- Divine Shield
    [498]=true,    -- Divine Protection
    [47585]=true,  -- Dispersion
    [33206]=true,  -- Pain Suppression
    [22812]=true,  -- Barkskin
    [61336]=true,  -- Survival Instincts
    [30823]=true,  -- Shamanistic Rage
    [19263]=true,  -- Deterrence
    [45438]=true,  -- Ice Block
    [18708]=true,  -- Fel Domination (utility)
  }

  local pulseAccum = 0

  -- Cooldown updater
  if not H._cdUpdateFrame then
    local uf = CreateFrame("Frame")
    H._cdUpdateFrame = uf
    -- helper for compact time display
    local function ShortTime(t)
      if t >= 90 then return string.format("%dm", math.floor((t+30)/60)) end
      return string.format("%.0f", t)
    end
    uf:SetScript("OnUpdate", function(_, elapsed)
      pulseAccum = pulseAccum + elapsed
      for _, b in ipairs(H.classCDButtons or {}) do
        local start, duration, enabled = GetSpellCooldown(b.spellID)
        if enabled == 1 and duration and duration > 0 and start and start > 0 then
          local remain = (start + duration) - GetTime()
          if remain < 0 then remain = 0 end
          if b.cooldown and duration > 0.1 then b.cooldown:SetCooldown(start, duration); b.cooldown:Show() end
          if b.icon and b.icon.SetDesaturated then b.icon:SetDesaturated(true) end
          if b.dim then b.dim:Show() end
          b.cdText:SetText(ShortTime(remain))
          b.cdText:Show()
          b:SetAlpha(1)
        else
          if b.cooldown then b.cooldown:Hide() end
          b.cdText:Hide(); b:SetAlpha(1)
          if b.icon and b.icon.SetDesaturated then b.icon:SetDesaturated(false) end
          if b.dim then b.dim:Hide() end
        end
        -- Emergency pulse logic
        if HardcoreHUDDB.emergency and HardcoreHUDDB.emergency.enabled and EMERGENCY_SPELLS[b.spellID] then
          local hp = UnitHealth("player") or 0
            local hpMax = UnitHealthMax("player") or 1
            local ratio = hpMax>0 and (hp/hpMax) or 1
            if ratio <= (HardcoreHUDDB.emergency.hpThreshold or 0.5) then
              local s,d,e = GetSpellCooldown(b.spellID)
              local ready = (e == 1 and d == 0)
              if ready then
                if not b._pulseBorder then
                  local pb = b:CreateTexture(nil, "OVERLAY")
                  pb:SetTexture("Interface/Buttons/UI-ActionButton-Border")
                  pb:SetBlendMode("ADD")
                  pb:SetPoint("CENTER", b, "CENTER")
                  pb:SetSize(b:GetWidth()*1.6, b:GetHeight()*1.6)
                  b._pulseBorder = pb
                end
                local a = 0.35 + 0.35 * math.abs(math.sin(pulseAccum*6))
                b._pulseBorder:SetAlpha(a)
                b._pulseBorder:Show()
              else
                if b._pulseBorder then b._pulseBorder:Hide() end
              end
            else
              if b._pulseBorder then b._pulseBorder:Hide() end
            end
        end
      end
      -- Potion cooldown (spiral + dim + big number)
      if H.potionBtn and H.potionBtn.itemID then
        local ps, pd, pe = GetItemCooldown(H.potionBtn.itemID)
        if pe == 1 and pd and pd > 0 and ps and ps > 0 then
          local prem = (ps + pd) - GetTime()
          if prem < 0 then prem = 0 end
          if H.potionBtn.cooldown then H.potionBtn.cooldown:SetCooldown(ps, pd); H.potionBtn.cooldown:Show() end
          if H.potionBtn.icon and H.potionBtn.icon.SetDesaturated then H.potionBtn.icon:SetDesaturated(true) end
          if H.potionBtn.dim then H.potionBtn.dim:Show() end
          if H.potionBtn.cdText then H.potionBtn.cdText:SetText(ShortTime(prem)); H.potionBtn.cdText:Show() end
        else
          if H.potionBtn.cooldown then H.potionBtn.cooldown:Hide() end
          if H.potionBtn.cdText then H.potionBtn.cdText:Hide() end
          if H.potionBtn.icon and H.potionBtn.icon.SetDesaturated then H.potionBtn.icon:SetDesaturated(false) end
          if H.potionBtn.dim then H.potionBtn.dim:Hide() end
        end
      end
      -- Hearthstone cooldown (spiral + dim + big number)
      if H.hearthBtn and H.hearthBtn.itemID then
        local ps, pd, pe = GetItemCooldown(H.hearthBtn.itemID)
        if pe == 1 and pd and pd > 0 and ps and ps > 0 then
          local prem = (ps + pd) - GetTime()
          if prem < 0 then prem = 0 end
          if H.hearthBtn.cooldown then H.hearthBtn.cooldown:SetCooldown(ps, pd); H.hearthBtn.cooldown:Show() end
          if H.hearthBtn.icon and H.hearthBtn.icon.SetDesaturated then H.hearthBtn.icon:SetDesaturated(true) end
          if H.hearthBtn.dim then H.hearthBtn.dim:Show() end
          if H.hearthBtn.cdText then H.hearthBtn.cdText:SetText(ShortTime(prem)); H.hearthBtn.cdText:Show() end
        else
          if H.hearthBtn.cooldown then H.hearthBtn.cooldown:Hide() end
          if H.hearthBtn.cdText then H.hearthBtn.cdText:Hide() end
          if H.hearthBtn.icon and H.hearthBtn.icon.SetDesaturated then H.hearthBtn.icon:SetDesaturated(false) end
          if H.hearthBtn.dim then H.hearthBtn.dim:Hide() end
        end
      end
      -- Bandage cooldown (spiral + dim + big number)
      if H.bandageBtn and H.bandageBtn.itemID then
        local ps, pd, pe = GetItemCooldown(H.bandageBtn.itemID)
        if pe == 1 and pd and pd > 0 and ps and ps > 0 then
          local prem = (ps + pd) - GetTime()
          if prem < 0 then prem = 0 end
          if H.bandageBtn.cooldown then H.bandageBtn.cooldown:SetCooldown(ps, pd); H.bandageBtn.cooldown:Show() end
          if H.bandageBtn.icon and H.bandageBtn.icon.SetDesaturated then H.bandageBtn.icon:SetDesaturated(true) end
          if H.bandageBtn.dim then H.bandageBtn.dim:Show() end
          if H.bandageBtn.cdText then H.bandageBtn.cdText:SetText(ShortTime(prem)); H.bandageBtn.cdText:Show() end
        else
          if H.bandageBtn.cooldown then H.bandageBtn.cooldown:Hide() end
          if H.bandageBtn.cdText then H.bandageBtn.cdText:Hide() end
          if H.bandageBtn.icon and H.bandageBtn.icon.SetDesaturated then H.bandageBtn.icon:SetDesaturated(false) end
          if H.bandageBtn.dim then H.bandageBtn.dim:Hide() end
        end
      end
    end)
  end

  -- Refresh when new spells learned
  if not H._cdEventFrame then
    local ef = CreateFrame("Frame")
    H._cdEventFrame = ef
    ef:RegisterEvent("PLAYER_LOGIN")
    ef:RegisterEvent("SPELLS_CHANGED")
    ef:RegisterEvent("PLAYER_TALENT_UPDATE")
    ef:SetScript("OnEvent", function()
      -- Rebuild buttons
      for _, b in ipairs(H.classCDButtons or {}) do b:Hide() end
      H.classCDButtons = nil
      -- Re-run build utilities fragment for class cds only
      -- (Avoid rebuilding potion/hearth; just the cooldown segment)
      local oldButtons = {}
      local rebuilt = {}
      local newButtons = {}
      local newList = cdsByClass[select(2, UnitClass("player"))] or {}
      local startX2 = -((#newList * 30) / 2) + 15
      local ap = H.bars and H.bars.combo or UIParent
      for i, sid in ipairs(newList) do
        if IsKnown(sid) then
          local nm, _, ic = GetSpellInfo(sid)
          if nm then
            local nb = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
            nb:SetSize(28,28)
            -- Use sequential index for rebuilt buttons to avoid gaps
            local idx = #newButtons + 1
            nb:SetPoint("TOP", ap, "BOTTOM", startX2 + (idx-1)*32, anchorY)
            nb:SetAttribute("type", "spell")
            nb:SetAttribute("spell", nm)
            nb:SetFrameStrata("HIGH")
            nb:SetFrameLevel(70 + idx)
            nb:SetHitRectInsets(0,0,0,0)
            local nt = nb:CreateTexture(nil, "ARTWORK")
            nt:SetAllPoints(nb)
            nt:SetTexture(ic)
            nb.icon = nt
            local dim = nb:CreateTexture(nil, "OVERLAY")
            dim:SetAllPoints(nb)
            dim:SetColorTexture(0,0,0,0.55)
            dim:Hide()
            nb.dim = dim
            local cd = CreateFrame("Cooldown", nil, nb, "CooldownFrameTemplate")
            cd:SetAllPoints(nb)
            cd:Hide()
            nb.cooldown = cd
            local ct = nb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ct:ClearAllPoints()
            ct:SetPoint("CENTER", nb, "CENTER", 0, 0)
            if STANDARD_TEXT_FONT then ct:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
            ct:SetShadowColor(0,0,0,1)
            ct:SetShadowOffset(1,-1)
            nb.cdText = ct
            AttachSpellTooltip(nb, sid)
            newButtons[#newButtons+1] = nb
          end
        end
      end
      H.classCDButtons = newButtons
    end)
  end

  -- Fallback hover scanner (ensures tooltip even if OnEnter blocked)
  if not H._hoverScan then
    local scan = CreateFrame("Frame")
    H._hoverScan = scan
    local accum = 0
    scan:SetScript("OnUpdate", function(_, elapsed)
      accum = accum + elapsed
      if accum < 0.15 then return end
      accum = 0
      if not H.classCDButtons then return end
      local hoveredAny = false
      for _, btn in ipairs(H.classCDButtons) do
        if btn:IsVisible() and MouseIsOver(btn) then
          hoveredAny = true
          if not GameTooltip:IsOwned(btn) then
            GameTooltip:Hide()
            GameTooltip:SetOwner(btn, "ANCHOR_CURSOR")
            local link = GetSpellLink(btn.spellID)
            if link then
              GameTooltip:SetHyperlink(link)
              GameTooltip:Show()
            else
              local nm = GetSpellInfo(btn.spellID)
              GameTooltip:ClearLines()
              if nm then GameTooltip:AddLine(nm,1,1,1) end
              if GetSpellDescription then
                local d = GetSpellDescription(btn.spellID)
                if d and d ~= "" then GameTooltip:AddLine(d,0.9,0.9,0.9,true) end
              end
              GameTooltip:Show()
            end
            if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.tooltips then
              DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] HoverScan tooltip for spellID="..btn.spellID)
            end
          end
        end
      end
      if not hoveredAny and GameTooltip:IsVisible() then
        local owner = GameTooltip:GetOwner()
        local ownedByCD = false
        if owner then
          for _, btn in ipairs(H.classCDButtons) do if owner == btn then ownedByCD = true break end end
        end
        if ownedByCD then GameTooltip:Hide() end
      end
    end)
  end
end

-- ================= Buff / Consumable Reminders ===================
-- English-only client support
local reminderCategories = {
  FOOD = {
    label = "Food",
    patterns = {
      string.lower("Well Fed"),
      "well-fed",
      "wellfed",
    },
  },
  -- Consider satisfied if any flask present OR at least two elixirs present
  FLASK_PATTERNS = { string.lower("flask") },
  ELIXIR_PATTERNS = { string.lower("elixir") },
  -- Survival: any present passes (enUS)
  SURVIVAL = {
    label = "Core Buffs",
    patterns = {
      "fortitude",
      "mark of the wild", "gift of the wild",
      "blessing of kings",
    }
  },
}

-- ================= Whitelist Support (names-only, IDs optional) =================
-- SavedVariables: HardcoreHUDDB.whitelist.{foodNames, elixirNames, flaskNames}
do
  HardcoreHUDDB.whitelist = HardcoreHUDDB.whitelist or {}
  local WL = HardcoreHUDDB.whitelist
  WL.foodNames = WL.foodNames or {}
  WL.elixirNames = WL.elixirNames or {}
  WL.flaskNames = WL.flaskNames or {}
  -- Blacklist for items that should never be suggested (enUS)
  HardcoreHUDDB.blacklist = HardcoreHUDDB.blacklist or {}
  local BL = HardcoreHUDDB.blacklist
  BL.itemNames = BL.itemNames or {}
  BL.itemSpellPatterns = BL.itemSpellPatterns or {}
  BL.itemIDs = BL.itemIDs or {}

  -- Seed food names from provided cooking list (drinks are harmless; skipped by spell check)
  local seedFoods = {
    "Dragonbreath Chili",
    "Heavy Kodo Stew",
    "Spider Sausage",
    "Barbecued Buzzard Wing",
    "Carrion Surprise",
    "Giant Clam Scorcho",
    "Hot Wolf Ribs",
    "Jungle Stew",
    "Mithril Head Trout",
    "Mystery Stew",
    "Roast Raptor",
    "Rockscale Cod",
    "Goldthorn Tea",
    "Sagefish Delight",
    "Soothing Turtle Bisque",
    "Seafarer's Swig",
    "Springsocket Eel",
    "Heavy Crocolisk Stew",
    "Tasty Lion Steak",
    "Black Coffee",
    "Curiously Tasty Omelet",
    "Goblin Deviled Clams",
    "Hot Lion Chops",
    "Lean Wolf Steak",
    "Crocolisk Gumbo",
    "Big Bear Steak",
    "Gooey Spider Cake",
    "Lean Venison",
    "Succulent Pork Ribs",
    "Bristle Whisker Catfish",
    -- Second list (higher-skill classics)
    "Dark Iron Fish and Chips",
    "Deviate Feast",
    "Malistar's Revenge",
    "Molten Skullfish",
    "Stratholme Saperavi",
    "Lobster Roll",
    "Felstone Grog",
    "Baked Salmon",
    "Lobster Stew",
    "Mightfish Steak",
    "Protein Shake",
    "Sauteed Plated Armorfish",
    "Suspicious Stew",
    "Charred Bear Kabobs",
    "Juicy Bear Burger",
    "Nightfin Soup",
    "Poached Sunscale Salmon",
    "Grilled Squid",
    "Hot Smoked Bass",
    "Bone Meal",
    "Crestfall Crab Taco",
    "Clamlette Magnifique",
    "Cooked Glossy Mightfish",
    "Filet of Redgill",
    "Monster Omelet",
    "Spiced Chili Crab",
    "Spotted Yellowtail",
    "Tender Wolf Steak",
    "Undermine Clam Chowder",
  }
  for _, n in ipairs(seedFoods) do WL.foodNames[string.lower(n)] = true end

  -- Seed common Battle Elixirs (enUS) for whitelist
  local seedElixirs = {
    -- Classic/TBC/Wrath common battle elixirs
    "Arcane Elixir",
    "Greater Arcane Elixir",
    "Elixir of the Mongoose",
    "Elixir of Brute Force",
    "Elixir of Dazzling Light",
    "Elixir of Demonslaying",
    "Elixir of Greater Firepower",
    "Elixir of Shadow Power",
    "Elixir of Giants",
    "Elixir of Greater Agility",
    "Elixir of Frost Power",
    "Elixir of Agility",
    "Elixir of Ogre's Strength",
    "Elixir of Lesser Agility",
    "Elixir of Minor Agility",
    "Elixir of Lion's Strength",
    "Elixir of Pure Arcane Power",
  }
  for _, n in ipairs(seedElixirs) do WL.elixirNames[string.lower(n)] = true end

  -- Seed common Guardian Elixirs (enUS)
  local seedGuardianElixirs = {
    "Elixir of Whirling Wind",
    "Elixir of the Sages",
    "Elixir of Superior Defense",
    "Gift of Arthas",
    "Elixir of Greater Intellect",
    "Elixir of Greater Defense",
    "Major Troll's Blood Elixir",
    "Elixir of Fortitude",
    "Elixir of Defense",
    "Strong Troll's Blood Elixir",
    "Elixir of Wisdom",
    "Elixir of Minor Fortitude",
    "Weak Troll's Blood Elixir",
    "Elixir of Minor Defense",
  }
  for _, n in ipairs(seedGuardianElixirs) do WL.elixirNames[string.lower(n)] = true end

  -- Seed blacklist from provided screenshots (enUS)
  local seedBlacklistNames = {
    -- Utility/irrelevant detection/invisibility/vision/parley/catseye/etc.
    "Elixir of Iron Diplomacy",
    "Elixir of Valorous Diplomacy",
    "Elixir of Virtuous Diplomacy",
    "Elixir of Woodland Diplomacy",
    "Greater Catseye Elixir",
    "Catseye Elixir",
    "Elixir of Luring",
    "Elixir of Detect Demon",
    "Elixir of Detect Undead",
    "Elixir of Dream Vision",
    "Oil of Immolation",
    "Pirate's Parley",
    "Elixir of Detect Lesser Invisibility",
    "Elixir of Water Breathing",
    "Elixir of Water Walking",
    "Elixir of Greater Water Breathing",
  }
  for _, n in ipairs(seedBlacklistNames) do BL.itemNames[string.lower(n)] = true end
  -- Spell text patterns that indicate utility elixirs we should ignore
  local seedBlacklistSpells = {
    "water breathing",
    "waterbreathing",
    "breathe water",
    "allows the imbiber to breathe water",
    "water walking",
    "walk on water",
    "detect undead",
    "detect demon",
    "lesser invisibility",
    "dream vision",
    "catseye",
    "immolation",
    "parley",
    "diplomacy",
  }
  for _, p in ipairs(seedBlacklistSpells) do BL.itemSpellPatterns[p] = true end

  -- Seed blacklist by itemID (hard block even if name/spell is missing)
  local seedBlacklistIDs = {
    5996, -- Elixir of Water Breathing
    9154, -- Elixir of Detect Undead
    9233, -- Elixir of Detect Demon
    9197, -- Elixir of Dream Vision
    10592, -- Catseye Elixir
    8956, -- Oil of Immolation
    3387, -- Elixir of Detect Lesser Invisibility
    3823, -- Potion of Lesser Invisibility (utility)
    8827, -- Elixir of Water Walking
    -- Add more known utility IDs here as needed
  }
  for _, id in ipairs(seedBlacklistIDs) do BL.itemIDs[id] = true end

  -- Helper API
  function H.IsWhitelistedFood(name)
    if not name or name == "" then return false end
    local wl = HardcoreHUDDB and HardcoreHUDDB.whitelist and HardcoreHUDDB.whitelist.foodNames
    return wl and wl[string.lower(name)] or false
  end

  function H.AddWhitelistName(kind, name)
    if not HardcoreHUDDB.whitelist or not name or name == "" then return end
    local key = string.lower(name)
    if kind == "food" then HardcoreHUDDB.whitelist.foodNames[key] = true
    elseif kind == "elixir" then HardcoreHUDDB.whitelist.elixirNames[key] = true
    elseif kind == "flask" then HardcoreHUDDB.whitelist.flaskNames[key] = true
    end
  end

  function H.RemoveWhitelistName(kind, name)
    if not HardcoreHUDDB.whitelist or not name or name == "" then return end
    local key = string.lower(name)
    if kind == "food" then HardcoreHUDDB.whitelist.foodNames[key] = nil
    elseif kind == "elixir" then HardcoreHUDDB.whitelist.elixirNames[key] = nil
    elseif kind == "flask" then HardcoreHUDDB.whitelist.flaskNames[key] = nil
    end
  end
end

local function PlayerBuffNames()
  local present = {}
  for i=1,40 do
    local name = UnitBuff("player", i)
    if not name then break end
    present[name] = true
  end
  return present
end

-- Exact-name well fed detection support (more reliable than substrings)
local wellFedNames = {
  ["Well Fed"] = true,
  ["Well-Fed"] = true,
  ["Wellfed"] = true,
}

local function PlayerHasWellFed()
  local i = 1
  while true do
    local name = UnitBuff("player", i)
    if not name then break end
    if wellFedNames[name] then return true end
    i = i + 1
  end
  return false
end

local function HasPattern(present, patterns)
  for buffName,_ in pairs(present) do
    local lower = string.lower(buffName)
    for _,pat in ipairs(patterns) do
      if string.find(lower, pat) then return true end
    end
  end
  return false
end

-- Helper available outside of MissingCategories: check if any player buff
-- loosely matches a single pattern string (case-insensitive)
local function PresentHasAnyPattern(present, pat)
  local p = string.lower(pat)
  for buffName,_ in pairs(present) do
    if string.find(string.lower(buffName), p) then return true end
  end
  return false
end

local function MissingCategories()
  local missing = {}
  local present = PlayerBuffNames()
  local cats = (HardcoreHUDDB.reminders and HardcoreHUDDB.reminders.categories) or { food=true, flask=true, survival=true }
  
  -- Helper: bag scans for consumables (enUS client)
  local TYPE_CONSUMABLE   = "Consumable"
  local SUB_FOOD_DRINK    = "Food & Drink"
  local SUB_FLASK         = "Flask"
  local SUB_ELIXIR        = "Elixir"
  local function BagHasFood()
    for bag=0,4 do
      local slots = GetContainerNumSlots(bag) or 0
      for slot=1,slots do
        local id = GetContainerItemID(bag,slot)
        if id then
          local _, _, _, _, _, itemType, itemSubType = GetItemInfo(id)
          if itemType == TYPE_CONSUMABLE then
            if itemSubType == SUB_FOOD_DRINK then return true end
          end
        end
      end
    end
    return false
  end
  local function BagHasFlaskOrElixir()
    for bag=0,4 do
      local slots = GetContainerNumSlots(bag) or 0
      for slot=1,slots do
        local id = GetContainerItemID(bag,slot)
        if id then
          local _, _, _, _, _, itemType, itemSubType = GetItemInfo(id)
          if itemType == TYPE_CONSUMABLE then
            if itemSubType == SUB_FLASK or itemSubType == SUB_ELIXIR then return true end
          end
        end
      end
    end
    return false
  end
  
  -- Food
  -- Food: use exact-name check first (PlayerHasWellFed); fallback to patterns
  local hasWellFed = PlayerHasWellFed() or HasPattern(present, reminderCategories.FOOD.patterns)
  if cats.food and not hasWellFed then
    if BagHasFood() then table.insert(missing, reminderCategories.FOOD.label) end
  end
  -- Flask or dual elixirs: require either one Flask OR >=2 Elixir buffs (supports de-DE)
  local hasFlask = false
  local elixirCount = 0
  for buffName,_ in pairs(present) do
    local l = string.lower(buffName)
    for _,fp in ipairs(reminderCategories.FLASK_PATTERNS) do if string.find(l, fp) then hasFlask = true break end end
    for _,ep in ipairs(reminderCategories.ELIXIR_PATTERNS) do if string.find(l, ep) then elixirCount = elixirCount + 1; break end end
  end
  if cats.flask and not hasFlask and elixirCount < 2 then
    if BagHasFlaskOrElixir() then table.insert(missing, "Flask/Elixirs") end
  end
  -- Survival core buff (any present passes)
  local hasSurvival = HasPattern(present, reminderCategories.SURVIVAL.patterns)
  if cats.survival and not hasSurvival then table.insert(missing, reminderCategories.SURVIVAL.label) end
  
  -- Class-specific self-buffs (spec-aware where relevant)
  local function ExpectedClassBuffs()
    local class = select(2, UnitClass("player"))
    local buffs = {}
    -- Simple spec detection: pick tab with highest points
    local function DominantTree()
      if not GetTalentTabInfo then return 1 end
      local best, idx = -1, 1
      for i=1,3 do
        local _, _, points = GetTalentTabInfo(i)
        points = points or 0
        if points > best then best = points; idx = i end
      end
      return idx, best
    end
    local treeIdx = select(1, DominantTree())
    if class == "PALADIN" then
      -- 1 Holy, 2 Protection, 3 Retribution
      if treeIdx == 2 then
        table.insert(buffs, "Blessing of Sanctuary")
        table.insert(buffs, "Righteous Fury")
      elseif treeIdx == 3 then
        table.insert(buffs, "Blessing of Kings")
      else
        table.insert(buffs, "Blessing of Kings")
      end
    elseif class == "WARRIOR" then
      -- 1 Arms, 2 Fury, 3 Protection
      table.insert(buffs, "Battle Shout")
      if treeIdx == 3 then table.insert(buffs, "Commanding Shout") end
    elseif class == "PRIEST" then
      -- 1 Discipline, 2 Holy, 3 Shadow
      table.insert(buffs, "Power Word: Fortitude")
      if treeIdx ~= 3 then table.insert(buffs, "Inner Fire") end
    elseif class == "DRUID" then
      -- 1 Balance, 2 Feral, 3 Restoration
      table.insert(buffs, "Mark of the Wild")
      if treeIdx == 2 then table.insert(buffs, "Thorns") end
    elseif class == "MAGE" then
      table.insert(buffs, "Arcane Intellect")
    elseif class == "HUNTER" then
      table.insert(buffs, "Aspect") -- any Aspect
    elseif class == "WARLOCK" then
      table.insert(buffs, "Fel Armor")
      table.insert(buffs, "Demon Armor")
    elseif class == "ROGUE" then
      table.insert(buffs, "Poison") -- weapon poison present
    elseif class == "SHAMAN" then
      -- 1 Elemental, 2 Enhancement, 3 Restoration
      if treeIdx == 2 then table.insert(buffs, "Lightning Shield") else table.insert(buffs, "Water Shield") end
    end
    return buffs
  end
  local function HasAnyPattern(present, pat)
    for buffName,_ in pairs(present) do
      local l = string.lower(buffName)
      if string.find(l, string.lower(pat)) then return true end
    end
    return false
  end
  local function MissingClassBuffs()
    local want = ExpectedClassBuffs()
    local miss = {}
    for _,pat in ipairs(want) do
      if not HasAnyPattern(present, pat) then table.insert(miss, pat) end
    end
    return miss
  end
  local classMiss = MissingClassBuffs()
  for _,m in ipairs(classMiss) do table.insert(missing, m) end
  return missing
end

function H.InitReminders()
  HardcoreHUDDB.reminders = HardcoreHUDDB.reminders or { enabled = true }
  HardcoreHUDDB.reminders.categories = HardcoreHUDDB.reminders.categories or { food=true, flask=true, survival=true }
  -- Allow quickly disabling food/elixir suggestions if desired
  if HardcoreHUDDB.reminders.disableFoodElixir == nil then
    HardcoreHUDDB.reminders.disableFoodElixir = false
  end
  -- If disabled, also turn off the flask category to avoid confusion
  if HardcoreHUDDB.reminders.disableFoodElixir then
    HardcoreHUDDB.reminders.categories.flask = false
  end
  if H.reminderFrame then return end
  local rf = CreateFrame("Frame", nil, UIParent)
  rf:SetSize(160, 60)
  -- Anchor below the power bar when available; otherwise near top center
  if H.bars and H.bars.pow then
    rf:SetPoint("TOP", H.bars.pow, "BOTTOM", 0, -20)
  else
    rf:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
  if rf.SetFrameStrata then rf:SetFrameStrata("DIALOG") end
  rf:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
  rf:SetBackdropColor(0,0,0,0.75)
  rf.text = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rf.text:SetPoint("TOPLEFT", rf, "TOPLEFT", 6, -6)
  rf.text:SetJustifyH("LEFT")
  rf:EnableMouse(true)
  rf:Hide()
  H.reminderFrame = rf

  -- Event-driven updates so reminders reflect buffs expiring in combat
  if not rf.eventDriver then
    local ed = CreateFrame("Frame")
    rf.eventDriver = ed
    ed:RegisterEvent("PLAYER_LOGIN")
    ed:RegisterEvent("PLAYER_ENTERING_WORLD")
    ed:RegisterEvent("UNIT_AURA")
    ed:RegisterEvent("PLAYER_TALENT_UPDATE")
    ed:RegisterEvent("SPELLS_CHANGED")
    ed:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
    ed:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leaving combat
    ed:RegisterEvent("PLAYER_ALIVE")
    ed:RegisterEvent("PLAYER_UNGHOST")
    ed:SetScript("OnEvent", function(_, event, unit)
      -- Update on any aura change; don't filter by unit to keep it responsive
      if H.UpdateReminders then H.UpdateReminders() end
    end)
  end

    local function UpdateReminders()
    if not HardcoreHUDDB.reminders.enabled then rf:Hide(); return end
      -- Safety: keep frame hidden until we know we have entries
      rf:Hide()

    -- Build actionable entries (items and self-buffs)
    local entries = {}
    local cats = HardcoreHUDDB.reminders.categories or {}
    -- Disable Flask/Elixirs category entirely per user request
    cats.flask = false
    -- Disable Food category per user request
    cats.food = false

    -- Helpers: find items in bags
    local function GetItemNameSafe(id, bag, slot)
      local name = GetItemInfo(id)
      if not name and GetContainerItemLink and bag ~= nil and slot ~= nil then
        local link = GetContainerItemLink(bag, slot)
        if link then
          local bracket = string.match(link, "|h%[(.-)%]|h")
          if bracket and bracket ~= "" then name = bracket end
        end
      end
      return name
    end
    local function FirstItemBySubtype(subtype)
      for bag=0,4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot=1,slots do
          local id = GetContainerItemID(bag,slot)
          if id then
            local name, _, _, _, _, itemType, itemSubType, _, _, texture = GetItemInfo(id)
            if not name then name = GetItemNameSafe(id, bag, slot) end
            local lname = string.lower(name or "")
            local isConsum = (itemType == "Consumable")
            local subtypeMatch = (itemSubType == subtype)
            -- Name-based fallback when item info not cached yet
            if not subtypeMatch and subtype == "Food & Drink" then
              if string.find(lname, "food") or string.find(lname, "feast") or string.find(lname, "water") or string.find(lname, "drink") or string.find(lname, "bread") or string.find(lname, "fish") then
                subtypeMatch = true
              end
              -- Spell-text heuristic: treat items with eating effects as food
              if not subtypeMatch and GetItemSpell then
                local sp = GetItemSpell(id)
                local lsp = string.lower(sp or "")
                if lsp ~= "" then
                  local isDrink = string.find(lsp, "drink") or string.find(lsp, "drinking") or string.find(lsp, "beverage")
                  local isFood = string.find(lsp, "eat") or string.find(lsp, "eating") or string.find(lsp, "restores health") or string.find(lsp, "well fed")
                  if isFood and not isDrink then subtypeMatch = true end
                end
              end
            elseif not subtypeMatch and (subtype == "Flask" or subtype == "Elixir") then
              if string.find(lname, string.lower(subtype)) then subtypeMatch = true end
            end
            if isConsum and subtypeMatch then
              if subtype == "Food & Drink" then
                local sp = GetItemSpell and GetItemSpell(id)
                if sp and string.find(string.lower(sp), "drink") then
                  -- skip drinks
                else
                  -- Prefer whitelisted foods, but fall back to any food item
                  if H.IsWhitelistedFood(name) then
                    return id, texture
                  else
                    return id, texture
                  end
                end
              else
                return id, texture
              end
            end
          end
        end
      end
      return nil
    end
    local function IsUtilityElixirName(lname, itemID)
      lname = lname or ""
      local function containsWaterUtility(s)
        if not s or s == "" then return false end
        s = string.lower(s)
        return string.find(s, "water breathing") or string.find(s, "waterbreathing")
            or string.find(s, "water walking") or string.find(s, "waterwalking")
      end
      -- Check by item name
      if containsWaterUtility(lname) then return true end
      -- Check by item spell (tooltip Use: line)
      if itemID and GetItemSpell then
        local sp = GetItemSpell(itemID)
        if containsWaterUtility(sp or "") then return true end
      end
      return false
    end
    local function AllItemsBySubtype(subtype, limit)
      local found = {}
      for bag=0,4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot=1,slots do
          local id = GetContainerItemID(bag,slot)
          if id then
            local name, _, _, _, _, itemType, itemSubType, _, _, texture = GetItemInfo(id)
            if not name then name = GetItemNameSafe(id, bag, slot) end
            local lname = string.lower(name or "")
            local isConsum = (itemType == "Consumable")
            local subtypeMatch = (itemSubType == subtype)
            if not subtypeMatch and subtype == "Food & Drink" then
              if string.find(lname, "food") or string.find(lname, "feast") or string.find(lname, "water") or string.find(lname, "drink") or string.find(lname, "bread") or string.find(lname, "fish") then
                subtypeMatch = true
              end
              -- Spell-text heuristic: treat items with eating effects as food
              if not subtypeMatch and GetItemSpell then
                local sp = GetItemSpell(id)
                local lsp = string.lower(sp or "")
                if lsp ~= "" then
                  local isDrink = string.find(lsp, "drink") or string.find(lsp, "drinking") or string.find(lsp, "beverage")
                  local isFood = string.find(lsp, "eat") or string.find(lsp, "eating") or string.find(lsp, "restores health") or string.find(lsp, "well fed")
                  if isFood and not isDrink then subtypeMatch = true end
                end
              end
            elseif not subtypeMatch and (subtype == "Flask" or subtype == "Elixir") then
              if string.find(lname, string.lower(subtype)) then subtypeMatch = true end
            end
            -- Global blacklist: skip items by name, spell text patterns, or itemID (use HardcoreHUDDB.blacklist)
            local function isBlacklisted()
              local BL = HardcoreHUDDB and HardcoreHUDDB.blacklist
              if not BL then return false end
              if BL.itemNames and lname and lname ~= "" and BL.itemNames[lname] then return true end
              if BL.itemIDs and id and BL.itemIDs[id] then return true end
              if GetItemSpell and BL.itemSpellPatterns then
                local sp = GetItemSpell(id)
                if sp and sp ~= "" then
                  local lsp = string.lower(sp)
                  for pat,_ in pairs(BL.itemSpellPatterns) do
                    if string.find(lsp, pat) then return true end
                  end
                end
              end
              return false
            end
            local function IsEligibleElixirBySpell(itemID)
              -- Prefer explicit classification; fallback to whitelist names if available
              local name = GetItemInfo(itemID)
              local wl = HardcoreHUDDB and HardcoreHUDDB.whitelist and HardcoreHUDDB.whitelist.elixirNames
              if wl and name and wl[string.lower(name)] then return true end
              if not GetItemSpell then return false end
              local sp = GetItemSpell(itemID)
              if not sp or sp == "" then return false end
              local lsp = string.lower(sp)
              if string.find(lsp, "battle elixir") or string.find(lsp, "guardian elixir") then return true end
              return false
            end

            if isConsum and subtypeMatch then
              local wasBlacklisted = isBlacklisted()
              local isUtility = (subtype == "Elixir") and IsUtilityElixirName(lname, id)
              local eligibleElixir = (subtype ~= "Elixir") or IsEligibleElixirBySpell(id)
              if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.reminders then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("[HardcoreHUD] Scan %s id=%s name=%s util=%s eligible=%s blacklisted=%s",
                  tostring(subtype), tostring(id), tostring(name), tostring(isUtility), tostring(eligibleElixir), tostring(wasBlacklisted)))
              end
              if subtype == "Elixir" and (isUtility or wasBlacklisted or not eligibleElixir) then
                -- Skip utility elixirs like Water Breathing/Walking
              else
              if subtype == "Food & Drink" then
                local sp = GetItemSpell and GetItemSpell(id)
                if sp and string.find(string.lower(sp), "drink") then
                  -- skip drinks
                else
                  -- Include any food; whitelist is optional preference
                  table.insert(found, {id=id, texture=texture})
                  if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.reminders then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("[HardcoreHUD] Added candidate %s id=%s", tostring(subtype), tostring(id)))
                  end
                  if limit and #found >= limit then return found end
                end
              else
                if isBlacklisted() then
                  -- skip globally blacklisted items
                else
                  if subtype == "Elixir" and not IsEligibleElixirBySpell(id) then
                    -- skip non-battle/guardian elixirs
                  else
                table.insert(found, {id=id, texture=texture})
                if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.reminders then
                  DEFAULT_CHAT_FRAME:AddMessage(string.format("[HardcoreHUD] Added candidate %s id=%s", tostring(subtype), tostring(id)))
                end
                if limit and #found >= limit then return found end
                  end
                end
              end
              end
            end
          end
        end
      end
      return found
    end

    local function IsBlacklistedItem(id, name)
      if not HardcoreHUDDB or not HardcoreHUDDB.blacklist then return false end
      local BL = HardcoreHUDDB.blacklist
      local lname = string.lower(name or (GetItemInfo(id) or ""))
      if BL.itemNames and lname ~= "" and BL.itemNames[lname] then return true end
      if GetItemSpell and BL.itemSpellPatterns then
        local sp = GetItemSpell(id)
        if sp and sp ~= "" then
          local lsp = string.lower(sp)
          for pat,_ in pairs(BL.itemSpellPatterns) do
            if string.find(lsp, pat) then return true end
          end
        end
      end
      return false
    end

    -- Food disabled: do nothing

    -- Flask/Elixirs disabled: do nothing

    -- Class self-buffs buttons (show only when missing and category enabled)
    local function AddSpellIfKnown(spellName)
      local name, _, tex = GetSpellInfo(spellName)
      -- More reliable texture resolution: try GetSpellTexture when icon is nil
      if not tex or tex == "" then
        if GetSpellTexture then tex = GetSpellTexture(spellName) end
      end
      if name then table.insert(entries, {kind="spell", spell=name, texture=tex, label=name}) end
    end
    -- From our ExpectedClassBuffs + core self-cast options
    local class = select(2, UnitClass("player"))
    local coreAdded = 0
    local presentAll = PlayerBuffNames()
    local function HasAnyCoreBuffForClass(class, present)
      local function has(pat)
        return PresentHasAnyPattern(present, pat)
      end
      if class == "PALADIN" then
        return has("Righteous Fury") or has("Blessing of Sanctuary") or has("Blessing of Kings")
      elseif class == "PRIEST" then
        return has("Power Word: Fortitude") or has("Inner Fire")
      elseif class == "DRUID" then
        return has("Mark of the Wild") or has("Gift of the Wild") or has("Thorns")
      elseif class == "MAGE" then
        return has("Arcane Intellect")
      elseif class == "WARRIOR" then
        return has("Battle Shout")
      elseif class == "SHAMAN" then
        return has("Water Shield") or has("Lightning Shield")
      elseif class == "WARLOCK" then
        return has("Fel Armor") or has("Demon Armor")
      end
      return false
    end
    if class == "PALADIN" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Righteous Fury") then AddSpellIfKnown("Righteous Fury"); coreAdded = coreAdded + 1 end
      -- Only suggest ONE Paladin blessing at a time: Sanctuary for Prot, Kings otherwise
      local function DominantTree()
        if not GetTalentTabInfo then return 1 end
        local best, idx = -1, 1
        for i=1,3 do
          local _, _, points = GetTalentTabInfo(i); points = points or 0
          if points > best then best = points; idx = i end
        end
        return idx
      end
      local tree = DominantTree()
      if tree == 2 then
        if not PresentHasAnyPattern(present, "Blessing of Sanctuary") then
          AddSpellIfKnown("Blessing of Sanctuary"); coreAdded = coreAdded + 1
        end
      else
        -- If Sanctuary is already active, do NOT suggest Kings (solo cannot stack)
        local hasSanctuary = PresentHasAnyPattern(present, "Blessing of Sanctuary")
        if not hasSanctuary and not PresentHasAnyPattern(present, "Blessing of Kings") then
          AddSpellIfKnown("Blessing of Kings"); coreAdded = coreAdded + 1
        end
      end
    elseif class == "PRIEST" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Power Word: Fortitude") then AddSpellIfKnown("Power Word: Fortitude"); coreAdded = coreAdded + 1 end
      if not PresentHasAnyPattern(present, "Inner Fire") then AddSpellIfKnown("Inner Fire"); coreAdded = coreAdded + 1 end
    elseif class == "DRUID" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Mark of the Wild") and not PresentHasAnyPattern(present, "Gift of the Wild") then AddSpellIfKnown("Mark of the Wild"); coreAdded = coreAdded + 1 end
      if not PresentHasAnyPattern(present, "Thorns") then AddSpellIfKnown("Thorns"); coreAdded = coreAdded + 1 end
    elseif class == "MAGE" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Arcane Intellect") then AddSpellIfKnown("Arcane Intellect"); coreAdded = coreAdded + 1 end
    elseif class == "WARRIOR" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Battle Shout") then AddSpellIfKnown("Battle Shout"); coreAdded = coreAdded + 1 end
    elseif class == "SHAMAN" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Water Shield") and not PresentHasAnyPattern(present, "Lightning Shield") then AddSpellIfKnown("Water Shield"); coreAdded = coreAdded + 1 end
    elseif class == "WARLOCK" and (cats.survival ~= false) then
      local present = PlayerBuffNames()
      if not PresentHasAnyPattern(present, "Fel Armor") and not PresentHasAnyPattern(present, "Demon Armor") then AddSpellIfKnown("Demon Armor"); coreAdded = coreAdded + 1 end
    end
    -- Fallback: if detection found none, show canonical core buff buttons so user can apply them
    if (cats.survival ~= false) and coreAdded == 0 and not HasAnyCoreBuffForClass(class, presentAll) then
      if class == "PALADIN" then
        AddSpellIfKnown("Righteous Fury"); AddSpellIfKnown("Blessing of Kings")
      elseif class == "PRIEST" then
        AddSpellIfKnown("Power Word: Fortitude"); AddSpellIfKnown("Inner Fire")
      elseif class == "DRUID" then
        AddSpellIfKnown("Mark of the Wild"); AddSpellIfKnown("Thorns")
      elseif class == "MAGE" then
        AddSpellIfKnown("Arcane Intellect")
      elseif class == "WARRIOR" then
        AddSpellIfKnown("Battle Shout")
      elseif class == "SHAMAN" then
        AddSpellIfKnown("Water Shield")
      elseif class == "WARLOCK" then
        AddSpellIfKnown("Demon Armor")
      end
    end

    -- Layout buttons
    rf.btns = rf.btns or {}
    local size, pad = 28, 6
    local cols = 6
    local function ensure(i)
      if rf.btns[i] then return rf.btns[i] end
      local b = CreateFrame("Button", nil, rf, "SecureActionButtonTemplate")
      b:SetSize(size, size)
      b.bg = b:CreateTexture(nil, "BACKGROUND")
      b.bg:SetAllPoints()
      b.bg:SetColorTexture(0.45, 0.05, 0.05, 0.85)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
      b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
      b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if self.kind == "item" and self.itemID then
          local name, link = GetItemInfo(self.itemID)
          if link and GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink(link)
          elseif GameTooltip.SetBagItem and self.bag and self.slot then
            GameTooltip:SetBagItem(self.bag, self.slot)
          else
            GameTooltip:SetText(name or (self.label or "Item"))
          end
        elseif self.kind == "spell" and self.spell then
          -- On 3.3.5, SetSpell expects a spellbook slot; use simple text
          GameTooltip:SetText(self.spell)
        end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      rf.btns[i] = b
      return b
    end

    local function place(b, i)
      local row = math.floor((i-1)/cols)
      local col = (i-1)%cols
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", rf, "TOPLEFT", 8 + col*(size+pad), -8 - row*(size+pad))
    end

      local shown = 0
    local function setItem(b, id, tex)
      b.kind = "item"; b.itemID = id; b.spell = nil; b.spellID=nil
      -- Resolve a reliable texture; avoid nil which renders as black
      local resolvedTex = tex
      if not resolvedTex or resolvedTex == "" then
        resolvedTex = (GetItemIcon and GetItemIcon(id))
      end
      if not resolvedTex or resolvedTex == "" then
        -- Try bag scan to fetch texture when item cache isn't ready
        for bag=0,4 do
          local slots = GetContainerNumSlots(bag) or 0
          for slot=1,slots do
            local iid = GetContainerItemID(bag, slot)
            if iid == id then
              local _, _, tex2 = GetContainerItemInfo(bag, slot)
              if tex2 and tex2 ~= "" then resolvedTex = tex2; break end
            end
          end
          if resolvedTex then break end
        end
      end
      if not resolvedTex or resolvedTex == "" then
        resolvedTex = "Interface/Icons/INV_Misc_QuestionMark"
      end
      if not resolvedTex or resolvedTex == "" then resolvedTex = "Interface/Icons/INV_Misc_QuestionMark" end
      b.icon:SetTexture(resolvedTex)
      if not InCombatLockdown() then
        b:SetAttribute("type", "item"); b:SetAttribute("item", "item:"..tostring(id))
      end
      if GetItemCount then b.count:SetText(GetItemCount(id)) else b.count:SetText("") end
    end
    local function setSpell(b, name, tex)
      b.kind = "spell"; b.itemID = nil; b.spell = name
      -- Fallback to question mark if texture missing to avoid black icon
      local resolvedTex = tex
      if not resolvedTex or resolvedTex == "" then
        -- Try to resolve via GetSpellTexture by name
        if GetSpellTexture and name then
          local t = GetSpellTexture(name)
          if t and t ~= "" then resolvedTex = t end
        end
        if not resolvedTex or resolvedTex == "" then
          resolvedTex = "Interface/Icons/INV_Misc_QuestionMark"
        end
      end
      b.icon:SetTexture(resolvedTex)
      if not InCombatLockdown() then
        b:SetAttribute("type", "spell"); b:SetAttribute("spell", name)
      end
      b.count:SetText("")
    end

    for _,e in ipairs(entries) do
      local skip = false
      if e.kind == "item" and e.id then
        local _, _, _, _, _, itemType, itemSubType = GetItemInfo(e.id)
        if itemType == "Consumable" and (itemSubType == "Elixir" or itemSubType == "Food & Drink") then
          skip = true
        end
      end
      if not skip then
        shown = shown + 1
        local b = ensure(shown)
        place(b, shown)
        if e.kind == "item" then setItem(b, e.id, e.texture) else setSpell(b, e.spell, e.texture) end
        b:Show()
      end
    end
    -- hide the rest
    for i=shown+1,(rf.btns and #rf.btns or 0) do if rf.btns[i] then rf.btns[i]:Hide() end end

    -- Resize frame to fit buttons; hide if no entries
    if shown == 0 then
      if rf.btns then for i=1,#rf.btns do rf.btns[i]:Hide() end end
      rf:Hide(); return
    end
    -- otherwise layout and show
    local rows = math.max(1, math.ceil(shown/cols))
    local w = 16 + math.min(shown, cols)*(size+pad) - pad
    local h = 16 + rows*(size+pad) - pad
    rf:SetSize(w, h)
    rf.text:SetText("")
    -- Ensure the reminder frame is shown when there are actionable entries
    if not rf:IsShown() then rf:Show() end
    if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.reminders then
      local miss = MissingCategories(); DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] Missing: "..table.concat(miss, ", "))
    end
  end

  -- Lightweight periodic refresh to catch edge cases
  if not rf.refreshDriver then
    local rd = CreateFrame("Frame")
    rf.refreshDriver = rd
    local acc = 0
    rd:SetScript("OnUpdate", function(_, dt)
      acc = acc + dt
      if acc >= 0.5 then
        acc = 0
        if H.UpdateReminders then H.UpdateReminders() end
      end
    end)
  end
  H.UpdateReminders = UpdateReminders

  -- Debug printer to list missing items to chat
  function H.DebugListReminders()
    local missing = MissingCategories()
    if #missing == 0 then
      print("HardcoreHUD: No reminders missing")
    else
      print("HardcoreHUD: Missing -> "..table.concat(missing, ", "))
    end
  end

  -- Slash command to print current player buff names (for locale debugging)
  SLASH_HARDCOREHUDBUFFS1 = "/hhbuffs"
  SlashCmdList["HARDCOREHUDBUFFS"] = function()
    local present = {}
    for i=1,40 do
      local name = UnitBuff("player", i)
      if not name then break end
      table.insert(present, name)
    end
    table.sort(present)
    print("HardcoreHUD: Player buffs -> "..table.concat(present, ", "))
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UNIT_AURA")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:RegisterEvent("BAG_UPDATE")
  ev:RegisterEvent("PLAYER_TALENT_UPDATE")
  ev:RegisterEvent("SPELLS_CHANGED")
  ev:SetScript("OnEvent", function(_,e,u)
    -- Some clients/servers send varying unit names; cheap to just update
    UpdateReminders()
  end)
  H._reminderEvents = ev

  -- Periodic fallback (in case events missed)
  local elapsed = 0
  rf:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed > 20 then elapsed = 0; UpdateReminders() end
  end)
  -- Immediate first evaluation
  if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
    C_Timer.After(1, UpdateReminders)
  else
    -- 3.3.5 clients do not have C_Timer; run once immediately
    UpdateReminders()
  end

  -- Tooltip: show category rules
  rf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Buff Reminders", 1,1,1)
    GameTooltip:AddLine(" ")
    local cats = HardcoreHUDDB.reminders.categories or {}
    -- Food/Elixirs tooltips disabled per user request
    if cats.survival then GameTooltip:AddLine("Core Buffs", 0.9,0.9,0.9) end
    GameTooltip:Show()
  end)
  rf:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Auto-init after utilities build
H.InitReminders()

-- ================= 5-Second Rule & Mana Tick Ticker ===================
do
  -- Defensive saved variable initialization (handles cases where saved value became nil or non-table)
  if not HardcoreHUDDB then HardcoreHUDDB = {} end
  if type(HardcoreHUDDB.ticker) ~= "table" then
    HardcoreHUDDB.ticker = { enabled = true }
  elseif HardcoreHUDDB.ticker.enabled == nil then
    -- Preserve existing table but ensure key exists
    HardcoreHUDDB.ticker.enabled = true
  end
  local tickerFrame = CreateFrame("Frame")
  H._manaTickerDriver = tickerFrame
  local lastCastTime = 0
  local lastTickTime = 0
  local TICK_INTERVAL = 2
  local FIVE_RULE = 5
  local lastMana = 0

  local function UsingMana()
    local pType = select(2, UnitPowerType("player"))
    return pType == "MANA"
  end

  local function EnsureBars()
    if not H.bars then H.bars = H.bars or {} end
    -- Intentionally do not create standalone 5s/tick bars anymore.
    -- The five-second rule and mana tick are now visualized as overlays
    -- on the power bar in Bars.lua (fsFill/tickFill). Keeping this
    -- function lightweight preserves existing call sites without
    -- spawning extra UI elements.
  end

  local function StartFiveSecondRule()
    lastCastTime = GetTime()
    EnsureBars()
    if H.bars.fs then H.bars.fs:Show() end
    if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.ticker then
      DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] 5s rule started")
    end
  end

  local pendingManaCheck = false
  local function RegisterManaCost(event, ...)
    if not UsingMana() then return end
    if event == "PLAYER_LOGIN" then
      lastMana = UnitPower("player",0)
      return
    end
    if event == "UNIT_SPELLCAST_START" then
      local unit = ...
      if unit == "player" then
        lastMana = UnitPower("player",0) -- snapshot before cost
      end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      local unit = ...
      if unit == "player" then
        pendingManaCheck = true -- evaluate on next update after mana actually deducted
      end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
      local unit = ...
      if unit == "player" then
        -- Do not start rule; ensure we refresh lastMana baseline
        lastMana = UnitPower("player",0)
      end
    end
  end

  tickerFrame:RegisterEvent("PLAYER_LOGIN")
  tickerFrame:RegisterEvent("UNIT_SPELLCAST_START")
  tickerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  tickerFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
  tickerFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  tickerFrame:SetScript("OnEvent", RegisterManaCost)

  tickerFrame:SetScript("OnUpdate", function(_, elapsed)
    local cfg = (HardcoreHUDDB and HardcoreHUDDB.ticker)
    if not (cfg and cfg.enabled) then return end
    if not UsingMana() then
      if H.bars.fs then H.bars.fs:Hide() end
      if H.bars.tick then H.bars.tick:Hide() end
      return
    end
    local now = GetTime()
    EnsureBars()
    -- Mana decrease detection (covers instants without START)
    local currentMana = UnitPower("player",0)
    if pendingManaCheck then
      -- Only start if mana actually decreased
      if currentMana < lastMana then StartFiveSecondRule() end
      pendingManaCheck = false
      lastMana = currentMana
    elseif currentMana < lastMana - 0 then -- any drop
      StartFiveSecondRule()
      lastMana = currentMana
    elseif currentMana > lastMana then
      -- regen or gain
      lastMana = currentMana
    end
    -- 5 second rule progress
    local since = now - lastCastTime
    if since <= FIVE_RULE then
      if H.bars.fs then
        H.bars.fs:SetMinMaxValues(0, FIVE_RULE)
        H.bars.fs:SetValue(since)
        H.bars.fs:Show()
      end
    else
      if H.bars.fs then H.bars.fs:Hide() end
    end
    -- Mana tick countdown (display time remaining to next tick)
    if now - lastTickTime >= TICK_INTERVAL then
      lastTickTime = now
    end
    local tickRemain = TICK_INTERVAL - (now - lastTickTime)
    if tickRemain < 0 then tickRemain = 0 end
    if H.bars.tick then
      H.bars.tick:SetMinMaxValues(0, TICK_INTERVAL)
      H.bars.tick:SetValue(TICK_INTERVAL - tickRemain)
      H.bars.tick:Show()
    end
  end)
end

-- ================= Map Visibility Controller ===================
do
  local prevProps = {}
  local function applyProps(frame, shown)
    if not frame then return end
    if shown then
      local p = prevProps[frame]
      if p then
        if frame.SetAlpha then frame:SetAlpha(p.alpha or 1) end
        if frame.SetFrameStrata and p.strata then frame:SetFrameStrata(p.strata) end
        if frame.EnableMouse then frame:EnableMouse(true) end
        if frame.SetScale and p.scale then frame:SetScale(p.scale) end
      end
      frame:Show()
    else
      -- store previous visual props and then hide strongly
      if not prevProps[frame] then
        prevProps[frame] = {
          alpha = (frame.GetAlpha and frame:GetAlpha()) or 1,
          strata = (frame.GetFrameStrata and frame:GetFrameStrata()) or nil,
          scale = (frame.GetScale and frame:GetScale()) or 1,
        }
      end
      if frame.SetAlpha then frame:SetAlpha(0) end
      if frame.SetFrameStrata then frame:SetFrameStrata("LOW") end
      if frame.EnableMouse then frame:EnableMouse(false) end
       -- extra safety: shrink scale to near-zero to avoid bleed-through
       if frame.SetScale then frame:SetScale(0.0001) end
      frame:Hide()
    end
  end

  local function SetHUDShown(shown)
    if not H.bars then return end
    local elems = {
      H.bars.hp, H.bars.pow, H.bars.targetHP, H.bars.targetPow,
      H.bars.combo,
      H.potionBtn, H.hearthBtn, H.bandageBtn, H.utilRow,
      H.bars.cds,
    }
    for _, f in ipairs(elems) do applyProps(f, shown) end
    -- Also hide any class cooldown buttons created by Utilities (parented to UIParent)
    if H.classCDButtons then
      for _, b in ipairs(H.classCDButtons) do
        applyProps(b, shown)
      end
    end
  end

  -- Generalized visibility controller: hide HUD when large UI windows are open
  local visWatcher = CreateFrame("Frame")
  local accum = 0
  HardcoreHUDDB.visibility = HardcoreHUDDB.visibility or {}
  local cfg = HardcoreHUDDB.visibility
  cfg.hideWhenShown = cfg.hideWhenShown or {
    "WorldMapFrame",
    "HardcoreHUDOptions",
    "AtlasLootDefaultFrame",
    "AtlasLoot_GUI-Frame",
    "AtlasLootFrame",
    "AtlasLootPanels",
    "AtlasLootItemsFrame",
    "AtlasLoot_GUIMenu",
    "QuestLogFrame",
    "SpellBookFrame",
    "CharacterFrame",
    "TradeSkillFrame",
    "MerchantFrame",
    "AuctionFrame",
    "FriendsFrame",
    "PVPFrame",
    "TalentFrame",
    "ClassTrainerFrame",
    "MailFrame",
    "GuildFrame",
    "PetStableFrame",
  }

  local function AnyFrameShown()
    for _, name in ipairs(cfg.hideWhenShown) do
      local f = _G[name]
      if f and f:IsShown() then return true end
    end
    return false
  end

  local lastShown = nil
  local function Evaluate()
    local shown = AnyFrameShown()
    if shown ~= lastShown then
      lastShown = shown
      SetHUDShown(not shown)
    end
  end

  visWatcher:SetScript("OnUpdate", function(_, dt)
    accum = accum + dt
    if accum < 0.2 then return end
    accum = 0
    Evaluate()
  end)

  -- Also hook explicit show/hide for WorldMap if available
  if _G.WorldMapFrame and not _G.WorldMapFrame._HardcoreHUDHooked then
    _G.WorldMapFrame:HookScript("OnShow", function() SetHUDShown(false) end)
    _G.WorldMapFrame:HookScript("OnHide", function() SetHUDShown(true) end)
    _G.WorldMapFrame._HardcoreHUDHooked = true
  end
  -- Explicit hook for options window so HUD never steals clicks over it
  if HardcoreHUDOptions and not HardcoreHUDOptions._HardcoreHUDHooked then
    HardcoreHUDOptions:HookScript("OnShow", function()
      SetHUDShown(false)
    end)
    HardcoreHUDOptions:HookScript("OnHide", function()
      SetHUDShown(true)
    end)
    HardcoreHUDOptions._HardcoreHUDHooked = true
  end
  -- In case Bars.lua created cdIcons separately, hide their buttons too
  function H._ApplyMapVisibilityToCDIcons(shown)
    if H.bars and H.bars.cdIcons then
      for _, info in ipairs(H.bars.cdIcons) do
        if info and info.btn then if shown then info.btn:Show() else info.btn:Hide() end end
      end
    end
  end
  -- Wrap SetHUDShown to also apply cdIcons visibility
  local _prevSetHUDShown = SetHUDShown
  SetHUDShown = function(shown)
    _prevSetHUDShown(shown)
    H._ApplyMapVisibilityToCDIcons(shown)
    if H.breathFrame then
      if shown then H.breathFrame:Show() else H.breathFrame:Hide() end
    end
    if H.spikeFrame then
      if shown then H.spikeFrame:Show() else H.spikeFrame:Hide() end
    end
    -- Do NOT force-show the reminder frame to avoid border flicker.
    -- When re-showing HUD, let UpdateReminders decide visibility based on entries.
    if H.reminderFrame then
      if not shown then
        H.reminderFrame:Hide()
      else
        if H.UpdateReminders then H.UpdateReminders() end
      end
    end
  end
  -- Initial evaluate to sync
  Evaluate()
end

-- Unified tooltip logic and simple fallback
if not H.ShowUnifiedTooltip then
  local simple = CreateFrame("Frame", "HardcoreHUDSimpleTooltip", UIParent)
  simple:SetSize(220, 60)
  simple:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
  simple:SetBackdropColor(0,0,0,0.88)
  simple.text1 = simple:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  simple.text1:SetPoint("TOPLEFT", simple, "TOPLEFT", 8, -8)
  simple.text1:SetJustifyH("LEFT")
  simple.text2 = simple:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  simple.text2:SetPoint("TOPLEFT", simple.text1, "BOTTOMLEFT", 0, -4)
  simple.text2:SetWidth(204)
  simple.text2:SetJustifyH("LEFT")
  simple:Hide()
  H.SimpleTooltip = simple

  function H.ShowUnifiedTooltip(owner, spellID)
    local name = GetSpellInfo(spellID)
    local desc = GetSpellDescription and GetSpellDescription(spellID)
    local useSimple = HardcoreHUDDB and HardcoreHUDDB.tooltip and HardcoreHUDDB.tooltip.simple
    if not useSimple and GameTooltip and GameTooltip.SetOwner then
      GameTooltip:Hide()
      GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
      local ok = false
      local link = GetSpellLink(spellID)
      if link then ok = pcall(function() GameTooltip:SetHyperlink(link) end) end
      if not ok then ok = pcall(function() GameTooltip:SetHyperlink("spell:"..spellID) end) end
      if not ok then
        GameTooltip:ClearLines()
        if name then GameTooltip:AddLine(name,1,1,1) end
        if desc and desc ~= "" then GameTooltip:AddLine(desc,0.9,0.9,0.9,true) end
        GameTooltip:Show()
        ok = true
      end
      if ok and GameTooltip:IsVisible() then
        if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.tooltips then
          DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] GameTooltip shown for spellID="..spellID)
        end
        return
      end
    end
    -- Simple fallback
    simple:ClearAllPoints()
    simple:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    simple.text1:SetText(name or ("Spell "..spellID))
    simple.text2:SetText(desc or "")
    local h = 30 + (desc and desc ~= "" and math.min(60, simple.text2:GetStringHeight()+8) or 0)
    simple:SetHeight(h)
    simple:Show()
    if HardcoreHUDDB and HardcoreHUDDB.debug and HardcoreHUDDB.debug.tooltips then
      DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] SimpleTooltip used for spellID="..spellID)
    end
  end
end

-- ================= Enhanced Breath (Ertrinken) Timer ===================
do
  HardcoreHUDDB.breath = HardcoreHUDDB.breath or { enabled = true, warnThreshold = 10 }
  local bf = CreateFrame("StatusBar", nil, UIParent)
  bf:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  bf:SetSize(120, 12)
  bf:SetMinMaxValues(0, 1)
  bf:SetValue(0)
  bf:SetPoint("TOP", H.bars and H.bars.combo or UIParent, "BOTTOM", 0, -70)
  bf:SetFrameStrata("FULLSCREEN_DIALOG")
  bf:Hide()
  bf.bg = bf:CreateTexture(nil, "BACKGROUND")
  bf.bg:SetAllPoints(bf)
  bf.bg:SetColorTexture(0,0,0,0.55)
  local txt = bf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  txt:SetPoint("CENTER", bf, "CENTER")
  bf.text = txt
  H.breathFrame = bf
  local pulseAcc = 0

  local function FindBreath()
    for i=1, (MIRRORTIMER_NUMTIMERS or 3) do
      local name, text, value, maxvalue, scale, paused, label = GetMirrorTimerInfo(i)
      if name and string.upper(name) == "BREATH" and maxvalue and maxvalue > 0 then
        return value, maxvalue, (paused == 1)
      end
    end
    return nil
  end

  local function ColorFor(rem)
    local warn = HardcoreHUDDB.breath.warnThreshold or 10
    if rem <= warn then
      -- transition to red
      return 1, 0.2, 0.2
    elseif rem <= warn*1.8 then
      return 1, 0.8, 0
    else
      return 0, 0.5, 1
    end
  end

  local elapsedAcc = 0
  bf:SetScript("OnUpdate", function(_, dt)
    elapsedAcc = elapsedAcc + dt
    if elapsedAcc < 0.15 then return end
    elapsedAcc = 0
    if not (HardcoreHUDDB.breath and HardcoreHUDDB.breath.enabled) then bf:Hide(); return end
    local value, maxvalue, paused = FindBreath()
    if not value then bf:Hide(); return end
    if paused then bf:Hide(); return end
    -- In MirrorTimer API value typically counts down (ms). Safeguard by clamping.
    local remainSec = math.max(0, math.floor((value/1000) + 0.5))
    bf:SetMinMaxValues(0, maxvalue/1000)
    bf:SetValue(value/1000)
    local r,g,b = ColorFor(remainSec)
    bf:SetStatusBarColor(r,g,b)
    bf.text:SetText("Atem: "..remainSec.."s")
    bf:Show()
    -- Warning pulse under threshold
    local warn = HardcoreHUDDB.breath.warnThreshold or 10
    if remainSec <= warn then
      pulseAcc = pulseAcc + dt
      local alpha = 0.55 + 0.45 * math.abs(math.sin(pulseAcc*5))
      bf:SetAlpha(alpha)
    else
      bf:SetAlpha(1)
      pulseAcc = 0
    end
  end)

  -- Event-driven reliability using Mirror Timer events
  if not H._breathEvents then
    local ev = CreateFrame("Frame")
    H._breathEvents = ev
    ev:RegisterEvent("MIRROR_TIMER_START")
    ev:RegisterEvent("MIRROR_TIMER_STOP")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, e, name)
      -- Normalize name
      local nm = name and string.upper(name) or nil
      if e == "PLAYER_ENTERING_WORLD" then
        local v,m,p = FindBreath()
        if v and m and not p and HardcoreHUDDB.breath and HardcoreHUDDB.breath.enabled then bf:Show() else bf:Hide() end
      elseif e == "MIRROR_TIMER_START" and nm == "BREATH" then
        if HardcoreHUDDB.breath and HardcoreHUDDB.breath.enabled then bf:Show() end
      elseif e == "MIRROR_TIMER_STOP" and nm == "BREATH" then
        bf:Hide()
      end
    end)
  end
end
