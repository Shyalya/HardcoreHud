local H = HardcoreHUD
HardcoreHUDDB = HardcoreHUDDB or {}
-- Ensure saved variables table exists before any access
HardcoreHUDDB = HardcoreHUDDB or {}
H.UtilitiesVersion = "2025-11-29b"
-- Print Utilities version at login to verify loaded file
do
  local vFrame = CreateFrame("Frame")
  vFrame:RegisterEvent("PLAYER_LOGIN")
  vFrame:SetScript("OnEvent", function()
    DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] UtilitiesVersion="..(H.UtilitiesVersion or "unknown"))
  end)
end

-- Safe backdrop helper: uses native SetBackdrop if available, otherwise creates a simple bg+border textures
function H.SafeBackdrop(frame, backdrop, r, g, b, a)
  if not frame then return end
  if frame.SetBackdrop then
    pcall(function()
      frame:SetBackdrop(backdrop)
      if frame.SetBackdropColor and r and g and b and a then frame:SetBackdropColor(r,g,b,a) end
    end)
    return
  end
  -- fallback: create a solid background texture and a thin border
  frame._hh_bg = frame._hh_bg or frame:CreateTexture(nil, "BACKGROUND")
  frame._hh_bg:SetDrawLayer("BACKGROUND", -1)
  frame._hh_bg:ClearAllPoints(); frame._hh_bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); frame._hh_bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  frame._hh_bg:SetTexture(backdrop and backdrop.bgFile or "Interface/Tooltips/UI-Tooltip-Background")
  if frame._hh_bg.SetVertexColor and r and g and b and a then frame._hh_bg:SetVertexColor(r,g,b,a) else frame._hh_bg:SetAlpha(a or 0.9) end
  -- thin border
  if not frame._hh_border then
    frame._hh_border = {}
    local function mk(side)
      local t = frame:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(0,0,0,0.9)
      frame._hh_border[side] = t
    end
    mk("top"); mk("bottom"); mk("left"); mk("right")
    frame._hh_border.top:ClearAllPoints(); frame._hh_border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); frame._hh_border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); frame._hh_border.top:SetHeight(1)
    frame._hh_border.bottom:ClearAllPoints(); frame._hh_border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); frame._hh_border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); frame._hh_border.bottom:SetHeight(1)
    frame._hh_border.left:ClearAllPoints(); frame._hh_border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); frame._hh_border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); frame._hh_border.left:SetWidth(1)
    frame._hh_border.right:ClearAllPoints(); frame._hh_border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); frame._hh_border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); frame._hh_border.right:SetWidth(1)
  end
end

-- Unified tooltip positioning: middle-right of the screen
function H.PositionTooltip()
  if not GameTooltip then return end
  GameTooltip:Hide()
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  GameTooltip:ClearAllPoints()
  -- Middle right edge, slight inward offset
  GameTooltip:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
end

-- Fallback unified tooltip for spells/items if other modules call H.ShowUnifiedTooltip
if not H.ShowUnifiedTooltip then
  function H.ShowUnifiedTooltip(frameOrNil, spellID)
    if not GameTooltip then return end
    -- Anchor to unified position without changing global defaults
    H.PositionTooltip()
    if spellID then
      local ok
      if GameTooltip.SetSpellByID then
        ok = pcall(function() GameTooltip:SetSpellByID(spellID) end)
      else
        -- Fallback: try to resolve name/link
        ok = false
        local nm = GetSpellInfo and select(1, GetSpellInfo(spellID))
        if nm then
          GameTooltip:ClearLines(); GameTooltip:AddLine(nm)
          ok = true
        end
      end
      if not ok then
        -- Last-resort: plain name
        local nm = GetSpellInfo and select(1, GetSpellInfo(spellID)) or ("Spell:"..tostring(spellID))
        GameTooltip:ClearLines(); GameTooltip:AddLine(nm)
      end
    end
    -- Some clients reset anchor after SetSpellByID; re-apply position
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
    GameTooltip:Show()
  end
end

-- Globally unify GameTooltip default anchor to prevent flicker back to cursor
-- Do NOT override global tooltip behavior; position only when our buttons request it

-- Pending secure attribute queue: if combat prevents SetAttribute, store and apply after regen
if not H.QueueSetAttribute then
  H._pendingAttributes = H._pendingAttributes or {}
  function H.QueueSetAttribute(frame, key, value)
    if not frame or not key then return end
    if not InCombatLockdown() then
      -- Handle special keys that aren't SetAttribute calls
      if key == "_propagateKeyboard" and frame.SetPropagateKeyboardInput then
        pcall(frame.SetPropagateKeyboardInput, frame, value)
        return
      end
      if frame.SetAttribute then pcall(frame.SetAttribute, frame, key, value) end
      return
    end
    H._pendingAttributes[frame] = H._pendingAttributes[frame] or {}
    H._pendingAttributes[frame][key] = value
  end
  function H.ApplyPendingAttributes()
    if not H._pendingAttributes then return end
    for frame, attrs in pairs(H._pendingAttributes) do
      if frame then
        for k, v in pairs(attrs) do
          -- Handle special keys that aren't SetAttribute calls
          if k == "_propagateKeyboard" and frame.SetPropagateKeyboardInput then
            pcall(frame.SetPropagateKeyboardInput, frame, v)
          elseif frame.SetAttribute then
            pcall(frame.SetAttribute, frame, k, v)
          end
        end
      end
    end
    H._pendingAttributes = {}
  end
  do
    local rf = CreateFrame("Frame")
    rf:RegisterEvent("PLAYER_REGEN_ENABLED")
    rf:RegisterEvent("PLAYER_LOGIN")
    rf:RegisterEvent("PLAYER_ENTERING_WORLD")
    rf:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        H.ApplyPendingAttributes()
      end
    end)
  end
end

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

-- Mana potion ranks (Classic + later). Highest rank should be used on button.
-- Explicit potency ordering instead of relying on itemID numeric value.
local MANA_POTION_RANKS = {
  [2455]  = 1,  -- Minor Mana Potion
  [3385]  = 2,  -- Lesser Mana Potion
  [3827]  = 3,  -- Mana Potion
  [6149]  = 4,  -- Greater Mana Potion
  [13443] = 5,  -- Superior Mana Potion
  [13444] = 6,  -- Major Mana Potion
  -- The following are not Classic-era but are harmless to include:
  [22832] = 7,  -- Super Mana Potion
  [33448] = 8,  -- Runic Mana Potion
  [18841] = 2,  -- Combat Mana Potion (situational)
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
    local function shouldSuppressReminders()
      return UnitIsDead and UnitIsDead("player")
    end
    if not HardcoreHUDDB or not HardcoreHUDDB.reminders or HardcoreHUDDB.reminders.enabled == false then return end
    if shouldSuppressReminders() then
      if H.reminderFrame then pcall(function() H.reminderFrame:Hide() end) end
      return
    end
    if event == "PLAYER_ENTERING_WORLD" then
      if H.InitReminders then H.InitReminders() end
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame and HardcoreHUDDB.reminders.enabled then pcall(function() H.reminderFrame:Show() end) end
    elseif event == "UNIT_AURA" then
      local unit = ...
      if unit == "player" then
        if shouldSuppressReminders() then if H.reminderFrame then pcall(function() H.reminderFrame:Hide() end) end; return end
        if H.UpdateReminders then H.UpdateReminders() end
     end
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- In combat, re-evaluate missing buffs; keep frame visible if enabled
      if shouldSuppressReminders() then if H.reminderFrame then pcall(function() H.reminderFrame:Hide() end) end; return end
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame and HardcoreHUDDB.reminders.enabled then pcall(function() H.reminderFrame:Show() end) end
    elseif event == "PLAYER_REGEN_ENABLED" then
      -- Out of combat, refresh once; visibility managed by UpdateReminders
      if shouldSuppressReminders() then if H.reminderFrame then pcall(function() H.reminderFrame:Hide() end) end; return end
      if H.UpdateReminders then H.UpdateReminders() end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      -- Older clients pass combat log args directly via ...
      local timestamp, subEvent, hideCaster,
            srcGUID, srcName, srcFlags, srcRaidFlags,
            destGUID, destName, destFlags, destRaidFlags,
            spellId = ...
      if subEvent == "SPELL_AURA_REMOVED" and destGUID == UnitGUID("player") then
        if shouldSuppressReminders() then if H.reminderFrame then H.reminderFrame:Hide() end; return end
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
        -- If still empty, hide to avoid showing a black box
        if H.reminderFrame then
          local count = (H.reminderFrame.icons and #H.reminderFrame.icons) or 0
          if count > 0 and HardcoreHUDDB.reminders and HardcoreHUDDB.reminders.enabled and not shouldSuppressReminders() then
            pcall(function() H.reminderFrame:Show() end)
          else
            pcall(function() H.reminderFrame:Hide() end)
          end
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

-- Safe bag iterator: returns true if iteration executed, false if container APIs missing.
local function SafeForEachBagSlot(fn)
  if not GetContainerNumSlots or not GetContainerItemID then return false end
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      fn(bag, slot)
    end
  end
  return true
end

local function SafeFindInBags(fn)
  if not GetContainerNumSlots or not GetContainerItemID then return nil end
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local a,b = fn(bag, slot)
      if a ~= nil then return a, b end
    end
  end
  return nil
end

-- Safe GetItemCooldown wrapper for clients that lack the API
-- In Classic Era, potions share a 2-minute cooldown category
-- GetItemCooldown may return enabled=0 for category cooldowns, but we can detect
-- active cooldowns by checking if start > 0 and duration > 1.5 (GCD threshold)
local function GetItemCooldownSafe(itemID)
  if not itemID then return 0, 0, 1 end
  if GetItemCooldown then
    local s, d, e = GetItemCooldown(itemID)
    -- Ensure we return valid numbers (some clients return nil)
    s = s or 0
    d = d or 0
    e = e or 0
    -- In Classic Era, 'enabled' can be 0 for items with shared cooldowns (potions)
    -- Detect active cooldown by checking start/duration values directly
    -- Duration > 1.5 distinguishes real cooldowns from GCD
    if s > 0 and d > 1.5 then
      -- There's a real cooldown running
      e = 1
    elseif e == 0 or e == nil then
      -- No cooldown or GCD only
      e = 1
    end
    return s, d, e
  end
  return 0, 0, 1
end

local function findHighestPotion()
  local bestBag, bestSlot, bestName, bestRank, bestID = nil,nil,nil,0,nil
  local iterOK = SafeForEachBagSlot(function(bag, slot)
    local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
    if itemID and HEAL_POTION_RANKS[itemID] then
      local rank = HEAL_POTION_RANKS[itemID]
      local name = GetItemInfo(itemID) or (GetContainerItemLink and GetContainerItemLink(bag,slot)) or "Healing Potion"
      if rank > bestRank then bestRank = rank; bestBag=bag; bestSlot=slot; bestName=name; bestID=itemID end
    end
  end)
  if not iterOK then
    -- Fallback: check known potion IDs via GetItemCount
    for id, rank in pairs(HEAL_POTION_RANKS) do
      local cnt = (GetItemCount and GetItemCount(id)) or 0
      if cnt > 0 and rank > bestRank then
        bestRank = rank; bestID = id; bestName = GetItemInfo(id) or "Healing Potion"; bestBag=nil; bestSlot=nil
      end
    end
  end
  return bestBag, bestSlot, bestName, bestID
end

local function findHighestManaPotion()
  local bestBag, bestSlot, bestName, bestRank, bestID = nil,nil,nil,0,nil
  local iterOK = SafeForEachBagSlot(function(bag, slot)
    local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
    if itemID and MANA_POTION_RANKS[itemID] then
      local rank = MANA_POTION_RANKS[itemID]
      local name = GetItemInfo(itemID) or (GetContainerItemLink and GetContainerItemLink(bag,slot)) or "Mana Potion"
      if rank > bestRank then bestRank = rank; bestBag=bag; bestSlot=slot; bestName=name; bestID=itemID end
    end
  end)
  if not iterOK then
    for id, rank in pairs(MANA_POTION_RANKS) do
      local cnt = (GetItemCount and GetItemCount(id)) or 0
      if cnt > 0 and rank > bestRank then
        bestRank = rank; bestID = id; bestName = GetItemInfo(id) or "Mana Potion"; bestBag=nil; bestSlot=nil
      end
    end
  end
  return bestBag, bestSlot, bestName, bestID
end

local function findHighestBandage()
  local bestName, bestID, bestRank
  local iterOK = SafeForEachBagSlot(function(bag, slot)
    local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
    if itemID and BANDAGE_RANKS[itemID] then
      local rank = BANDAGE_RANKS[itemID]
      if not bestRank or rank > bestRank then
        bestRank = rank
        bestID = itemID
        bestName = GetItemInfo(itemID) or (GetContainerItemLink and GetContainerItemLink(bag,slot)) or "Bandage"
      end
    end
  end)
  if not iterOK then
    for id, rank in pairs(BANDAGE_RANKS) do
      local cnt = (GetItemCount and GetItemCount(id)) or 0
      if cnt > 0 and (not bestRank or rank > bestRank) then
        bestRank = rank; bestID = id; bestName = GetItemInfo(id) or "Bandage"
      end
    end
  end
  return bestName, bestID
end

-- Helper to attach a robust spell tooltip (Wrath 3.3.5 compatible)
local function AttachSpellTooltip(btn, spellID)
  btn.spellID = spellID
  btn:EnableMouse(true)
  btn:RegisterForClicks("AnyUp")

  btn:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", btn, "TOPLEFT", -10, 5)
    
    -- Try to show the spell tooltip
    if spellID then
      if GameTooltip.SetSpellByID then
        pcall(function() GameTooltip:SetSpellByID(spellID) end)
      elseif GameTooltip.SetSpell then
        pcall(function() GameTooltip:SetSpell(spellID) end)
      else
        -- Fallback: try to get spell name and show it
        local spellName = GetSpellInfo(spellID)
        if spellName then
          pcall(function() GameTooltip:SetText(spellName) end)
        end
      end
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip:IsVisible() then GameTooltip:Hide() end
  end)
end

-- Helper to attach an item tooltip (by ID or name)
local function AttachItemTooltip(btn)
  btn:EnableMouse(true)
  btn:RegisterForClicks("AnyUp")
  btn:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    H.PositionTooltip()
    local id = self.itemID
    local itm = self.GetAttribute and self:GetAttribute("item") or nil

    if id then
      if GameTooltip.SetItemByID then
        pcall(function() GameTooltip:SetItemByID(id) end)
      elseif GameTooltip.SetHyperlink then
        pcall(function() GameTooltip:SetHyperlink("item:"..tostring(id)) end)
      else
        local name = GetItemInfo and GetItemInfo(id)
        if name then GameTooltip:ClearLines(); GameTooltip:AddLine(name) end
      end
    elseif itm then
      local linkStr
      if type(itm) == "string" then
        local idMatch = itm:match("item:%d+")
        if idMatch then
          linkStr = idMatch
        else
          local nameLink = select(2, GetItemInfo(itm))
          if nameLink then linkStr = nameLink end
        end
      end
      if not linkStr and self.itemID then
        linkStr = "item:"..tostring(self.itemID)
      end
      if linkStr and GameTooltip.SetHyperlink then
        pcall(function() GameTooltip:SetHyperlink(linkStr) end)
      elseif type(itm) == "string" then
        GameTooltip:SetText(itm)
      end
    end
    -- Position tooltip reliably to the right and a bit above
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", btn, "TOPLEFT", -10, 5)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() if GameTooltip and GameTooltip:IsVisible() then GameTooltip:Hide() end end)
end

function H.BuildUtilities()
  -- If already built, just rebuild sizes (don't create duplicates)
  if H._utilitiesBuilt then
    H.RebuildUtilityButtons()
    return
  end
  H._utilitiesBuilt = true
  
  -- Potion count and click-to-use
  local p = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.potionBtn = p
  -- Initial position - will be repositioned by RebuildUtilityButtons
  p:ClearAllPoints()
  p:SetPoint("CENTER", UIParent, "CENTER", 0, -200) -- Off-screen initially
  p:SetSize(28,28)
  if p.SetFrameStrata then p:SetFrameStrata("MEDIUM") end
  p:SetFrameLevel(100) -- Ensure it's on top
  if p.SetClampedToScreen then p:SetClampedToScreen(true) end
  p:Hide() -- Start hidden until RebuildUtilityButtons positions it
  local ptex = p:CreateTexture(nil, "ARTWORK")
  ptex:SetAllPoints(p)
  -- Use a healing potion-looking icon for the button default
  ptex:SetTexture("Interface/Icons/INV_Potion_54")
  p.icon = ptex
  local pDim = p:CreateTexture(nil, "OVERLAY")
  pDim:SetAllPoints(p)
  pDim:SetColorTexture(0,0,0,0.35)
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
  AttachItemTooltip(p)
  -- Button starts hidden, RebuildUtilityButtons will show it

  -- Mana potion button (separate from healing potion)
  local mp = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.manaBtn = mp
  -- Initial position - will be repositioned by RebuildUtilityButtons
  mp:ClearAllPoints()
  mp:SetPoint("CENTER", UIParent, "CENTER", 0, -200) -- Off-screen initially
  mp:SetSize(28,28)
  if mp.SetFrameStrata then mp:SetFrameStrata("MEDIUM") end
  mp:SetFrameLevel(100) -- Ensure it's on top
  if mp.SetClampedToScreen then mp:SetClampedToScreen(true) end
  mp:EnableMouse(true)
  mp:RegisterForClicks("AnyUp")
  mp:Hide() -- Start hidden until RebuildUtilityButtons positions it
  local mptex = mp:CreateTexture(nil, "ARTWORK")
  mptex:SetAllPoints(mp)
  mptex:SetTexture("Interface/Icons/INV_Potion_76")
  mp.icon = mptex
  local mpDim = mp:CreateTexture(nil, "OVERLAY")
  mpDim:SetAllPoints(mp)
  mpDim:SetColorTexture(0,0,0,0.35)
  mpDim:Hide()
  mp.dim = mpDim
  local mpCd = CreateFrame("Cooldown", nil, mp, "CooldownFrameTemplate")
  mpCd:SetAllPoints(mp)
  mpCd:Hide()
  mp.cooldown = mpCd
  local mpCnt = mp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mpCnt:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT")
  mp.countText = mpCnt
  local mpText = mp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mpText:SetPoint("CENTER", mp, "CENTER", 0, 0)
  if STANDARD_TEXT_FONT then mpText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
  mpText:SetShadowColor(0,0,0,1)
  mpText:SetShadowOffset(1,-1)
  mp.cdText = mpText
  mp:SetAttribute("type", "item")
  AttachItemTooltip(mp)
  -- Button starts hidden, RebuildUtilityButtons will show it
  
  -- Show/hide mana button.
  -- On official Classic this should be true for mana classes (e.g. Mage),
  -- but we also fall back to checking actual mana max to avoid timing issues
  -- where APIs briefly report 0 during login/loading.
  local manaClasses = { MAGE=true, PRIEST=true, WARLOCK=true, DRUID=true, PALADIN=true, SHAMAN=true }
  local function ShouldShowManaButton()
    local _, class = UnitClass("player")
    if class and manaClasses[class] then return true end
    local maxMana = UnitPowerMax and UnitPowerMax("player", 0) or 0
    return (maxMana and maxMana > 0) or false
  end
  H.ShouldShowManaButton = ShouldShowManaButton

  local function UpdateManaButtonVisibility()
    -- RebuildUtilityButtons will handle showing/positioning
    if H.RebuildUtilityButtons then
      pcall(function() H.RebuildUtilityButtons() end)
    end
  end
  local mpEvents = CreateFrame("Frame")
  mpEvents:RegisterEvent("PLAYER_LOGIN")
  mpEvents:RegisterEvent("UNIT_DISPLAYPOWER")
  mpEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
  mpEvents:RegisterEvent("UNIT_MAXPOWER")
  mpEvents:SetScript("OnEvent", function(_, evt, unit)
    if (evt == "UNIT_DISPLAYPOWER" or evt == "UNIT_MAXPOWER") and unit ~= "player" then return end
    UpdateManaButtonVisibility()
  end)

  -- Extra retries: Classic can report power/class late during initial load.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, UpdateManaButtonVisibility)
    C_Timer.After(2.0, UpdateManaButtonVisibility)
  end
  
  -- Bandage button (only show if First Aid is learned)
  local bdg = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.bandageBtn = bdg
  -- Initial position - will be repositioned by RebuildUtilityButtons
  bdg:ClearAllPoints()
  bdg:SetPoint("CENTER", UIParent, "CENTER", 0, -200) -- Off-screen initially
  bdg:SetSize(28,28)
  if bdg.SetFrameStrata then bdg:SetFrameStrata("MEDIUM") end
  if bdg.SetClampedToScreen then bdg:SetClampedToScreen(true) end
  bdg:Hide() -- Start hidden until RebuildUtilityButtons positions it
  local btex = bdg:CreateTexture(nil, "ARTWORK")
  btex:SetAllPoints(bdg)
  btex:SetTexture("Interface/Icons/INV_Misc_Bandage_Frostweave_Heavy")
  bdg.icon = btex
  local bDim = bdg:CreateTexture(nil, "OVERLAY")
  bDim:SetAllPoints(bdg)
  bDim:SetColorTexture(0,0,0,0.35)
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
  
  -- Check if player has First Aid profession (supports multiple locales)
  local function HasFirstAid()
    -- First try spell-based detection (works in all locales)
    -- Spell ID 3273 = "First Aid" passive skill
    if IsSpellKnown and IsSpellKnown(3273) then return true end
    if IsPlayerSpell and IsPlayerSpell(3273) then return true end
    
    -- Fallback: Check skill list with multiple locale names
    if not GetSkillLineInfo then return false end
    local firstAidNames = {
      ["First Aid"] = true,      -- English
      ["Erste Hilfe"] = true,    -- German
      ["Premiers soins"] = true, -- French
      ["Primeros auxilios"] = true, -- Spanish
      ["Primeiros Socorros"] = true, -- Portuguese
      ["Pronto Soccorso"] = true, -- Italian
      ["Первая помощь"] = true,  -- Russian
    }
    local i = 1
    while true do
      local skillName, _, _, skillRank, _ = GetSkillLineInfo(i)
      if not skillName then break end
      if firstAidNames[skillName] then return skillRank and skillRank > 0 end
      i = i + 1
    end
    return false
  end
  
  bdg._hasFirstAid = HasFirstAid()
  
  -- Visibility will be handled by RebuildUtilityButtons based on _hasFirstAid
  
  -- Hearthstone
  local hs = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  H.hearthBtn = hs
  -- Initial position - will be repositioned by RebuildUtilityButtons
  hs:ClearAllPoints()
  hs:SetPoint("CENTER", UIParent, "CENTER", 0, -200) -- Off-screen initially
  hs:SetSize(28,28)
  if hs.SetFrameStrata then hs:SetFrameStrata("MEDIUM") end
  if hs.SetClampedToScreen then hs:SetClampedToScreen(true) end
  hs:Hide() -- Start hidden until RebuildUtilityButtons positions it
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
  AttachItemTooltip(hs)
  -- Ensure the hearthstone button is visible immediately
  hs:Show()
  
  -- CRITICAL: Override Hide() to keep button always visible
  local originalHideHs = hs.Hide
  hs.Hide = function(self) end  -- Do nothing
  hs._OriginalHide = originalHideHs

  -- update counts
  local updater = CreateFrame("Frame")
  updater:RegisterEvent("BAG_UPDATE")
  updater:RegisterEvent("PLAYER_LOGIN")
  updater:RegisterEvent("SPELLS_CHANGED")
  updater:SetScript("OnEvent", function()
    -- Update First Aid status on every SPELLS_CHANGED event
    bdg._hasFirstAid = HasFirstAid()
    
    local bag, slot, name, itemID = findHighestPotion()
    if itemID then
      H.QueueSetAttribute(p, "item", "item:"..tostring(itemID))
      p.itemID = itemID
      local tex = select(10, GetItemInfo(itemID))
      if tex and p.icon then p.icon:SetTexture(tex) end
      if p.icon and p.icon.SetDesaturated then p.icon:SetDesaturated(false) end
      if p.dim then p.dim:Hide() end
      p:Show()
    else
      -- No healing potion found: show default icon dimmed
      H.QueueSetAttribute(p, "item", "")
      p.itemID = nil
      if p.icon then p.icon:SetTexture("Interface/Icons/INV_Potion_54") end
      if p.icon and p.icon.SetDesaturated then p.icon:SetDesaturated(true) end
      if p.dim then p.dim:Show() end
      p:Show()
    end
    local total = 0
    local iterOK = SafeForEachBagSlot(function(bag, slot)
      local id = GetContainerItemID and GetContainerItemID(bag,slot)
      if id and HEAL_POTION_RANKS[id] then
        local _,count = GetContainerItemInfo and GetContainerItemInfo(bag,slot)
        total = total + (count or 1)
      end
    end)
    if not iterOK then
      for id,_ in pairs(HEAL_POTION_RANKS) do
        total = total + ((GetItemCount and GetItemCount(id)) or 0)
      end
    end
    cnt:SetText(total)
    
    -- Bandage update
    local bname, bid = findHighestBandage()
    if bname and bid and bdg._hasFirstAid then
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
      H.QueueSetAttribute(bdg, "macrotext", useMacro)
      -- update icon to match the best bandage if info available
      local tex = select(10, GetItemInfo(bid))
      if tex and bdg.icon then bdg.icon:SetTexture(tex) end
      if bdg.icon and bdg.icon.SetDesaturated then bdg.icon:SetDesaturated(false) end
      if bdg.dim then bdg.dim:Hide() end
      local btotal = 0
      local iterOK2 = SafeForEachBagSlot(function(bag, slot)
        local id = GetContainerItemID and GetContainerItemID(bag,slot)
        if id == bid then
          local _,count = GetContainerItemInfo and GetContainerItemInfo(bag,slot)
          btotal = btotal + (count or 1)
        elseif id and BANDAGE_RANKS[id] and (BANDAGE_RANKS[id] < BANDAGE_RANKS[bid]) then
          local _,count = GetContainerItemInfo and GetContainerItemInfo(bag,slot)
          btotal = btotal + (count or 1)
        end
      end)
      if not iterOK2 then
        btotal = (GetItemCount and GetItemCount(bid)) or 0
        for id, rank in pairs(BANDAGE_RANKS) do
          if rank < (BANDAGE_RANKS[bid] or 0) then btotal = btotal + ((GetItemCount and GetItemCount(id)) or 0) end
        end
      end
      if bdg.countText then bdg.countText:SetText(btotal) end
      bdg:Show()
    else
      -- Hide bandage button if First Aid is not learned
      if not bdg._hasFirstAid then
        bdg:Hide()
      else
        -- Show bandage button with empty/dimmed state when no bandages are in bags
        bdg.itemID = nil
        H.QueueSetAttribute(bdg, "macrotext", "")
        if bdg.countText then bdg.countText:SetText(0) end
        -- Set a generic bandage icon and desaturate to indicate none available
        local tex = "Interface/Icons/INV_Misc_Bandage_Frostweave_Heavy"
        if bdg.icon then bdg.icon:SetTexture(tex) end
        if bdg.icon and bdg.icon.SetDesaturated then bdg.icon:SetDesaturated(true) end
        if bdg.dim then bdg.dim:Show() end
        bdg:Show()
      end
    end
    -- Mana potion update (scan + bind + dim when empty) - always show like HP potion
    if H.manaBtn then
      local _, _, _, mid = findHighestManaPotion()
      if mid then
        H.QueueSetAttribute(H.manaBtn, "item", "item:"..tostring(mid))
        H.manaBtn.itemID = mid
        local mtex = select(10, GetItemInfo(mid))
        if mtex and H.manaBtn.icon then H.manaBtn.icon:SetTexture(mtex) end
        if H.manaBtn.icon and H.manaBtn.icon.SetDesaturated then H.manaBtn.icon:SetDesaturated(false) end
        if H.manaBtn.dim then H.manaBtn.dim:Hide() end
        -- Show handled by RebuildUtilityButtons
      else
        -- No mana potion found: show default icon dimmed
        H.QueueSetAttribute(H.manaBtn, "item", "")
        H.manaBtn.itemID = nil
        if H.manaBtn.icon then H.manaBtn.icon:SetTexture("Interface/Icons/INV_Potion_76") end
        if H.manaBtn.icon and H.manaBtn.icon.SetDesaturated then H.manaBtn.icon:SetDesaturated(true) end
        if H.manaBtn.dim then H.manaBtn.dim:Show() end
        -- Show handled by RebuildUtilityButtons
      end

      local mtotal = 0
      -- Try bag-based iteration first
      if SafeForEachBagSlot then
        SafeForEachBagSlot(function(bag, slot)
          local id = GetContainerItemID and GetContainerItemID(bag,slot)
          if id and MANA_POTION_RANKS[id] then
            local _,count = GetContainerItemInfo and GetContainerItemInfo(bag,slot)
            mtotal = mtotal + (count or 1)
          end
        end)
      end
      -- If bag iteration found nothing, try GetItemCount fallback
      if mtotal == 0 then
        for id,_ in pairs(MANA_POTION_RANKS) do
          mtotal = mtotal + ((GetItemCount and GetItemCount(id)) or 0)
        end
      end
      if H.manaBtn.countText then H.manaBtn.countText:SetText(mtotal) end
    end
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.potions then
      DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] Potion count="..total)
    end
    -- Let RebuildUtilityButtons handle all visibility and positioning
    if H.RebuildUtilityButtons then 
      pcall(function() H.RebuildUtilityButtons() end)
    end
  end)
  -- Call updater immediately and again after delayed to ensure buttons are shown
  if updater:GetScript("OnEvent") then updater:GetScript("OnEvent")() end
  C_Timer.After(2, function() 
    if updater:GetScript("OnEvent") then 
      updater:GetScript("OnEvent")() 
      if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
    end 
  end)

  -- Utility row container spanning potion and hearth buttons
  local row = CreateFrame("Frame", nil, UIParent)
  H.utilRow = row
  row:SetSize((p:GetWidth() + hs:GetWidth() + bdg:GetWidth() + 12), math.max(p:GetHeight(), hs:GetHeight()))
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  row:Hide() -- Hide container frame so it doesn't block clicks on utility buttons

  -- Class cooldown buttons (only if spell learned)
  -- Guard against creating duplicates - check if already exists
  if H._classCDBuilt then
    return
  end
  H._classCDBuilt = true
  
  local class = select(2, UnitClass("player"))
  local cdsByClass = {
    WARRIOR = {871,12975,1719,2565}, -- Shield Wall, Last Stand, Recklessness, Shield Block
    ROGUE = {1856,5277,31224,2983}, -- Vanish, Evasion, Cloak of Shadows, Sprint
    MAGE = {45438,66,1953,122}, -- Ice Block, Invisibility, Blink, Frost Nova
    DRUID = {22812,61336,22842}, -- Barkskin, Survival Instincts, Frenzied Regeneration
    PALADIN = {642,498,633,1022,31884,853}, -- Divine Shield, Divine Protection, Lay on Hands, Hand of Protection, Avenging Wrath, Hammer of Justice
    HUNTER = {5384,19263,781}, -- Feign Death, Deterrence, Disengage
    WARLOCK = {18708,47891}, -- Fel Domination, Shadow Ward
    PRIEST = {47585,33206,586,8122}, -- Dispersion, Pain Suppression, Fade, Psychic Scream
    SHAMAN = {30823,2825,32182}, -- Shamanistic Rage, Bloodlust, Heroism
  }
  local spellList = cdsByClass[class] or {}
  local buttons = {}
  -- Place class cooldowns as a separate row below the utility row
  local anchorParent = H.utilRow or (H.bars and (H.bars.pow or H.bars.combo)) or UIParent
  local anchorY = -10  -- Reduced gap from -36 to -10
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
        b:ClearAllPoints();
        b:SetPoint("TOP", anchorParent, "BOTTOM", startX + (added-1)*32, anchorY)
        b:SetAttribute("type", "spell")
        b:SetAttribute("spell", name)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel(50 + added)
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
        b.spellID = spellID
        
        -- CRITICAL: Override Hide() to keep class cooldown buttons always visible
        local originalHideCooldown = b.Hide
        b.Hide = function(self) end  -- Do nothing
        b._OriginalHide = originalHideCooldown
        
        b:Show()
        buttons[#buttons+1] = b
      end
    end
  end
  -- Add racial cooldown as a utility-row button (Escape Artist, WotF, etc.)
  local function AddRacialUtility()
    if InCombatLockdown and InCombatLockdown() then
      H._pendingRacialBuild = true
      return
    end

    local race = select(2, UnitRace("player"))
    local racialSpellID
    -- Classic active racials
    if race == "Human" then racialSpellID = 20600 end -- Perception
    if race == "Dwarf" then racialSpellID = 20594 end -- Stoneform
    if race == "NightElf" then racialSpellID = 20580 end -- Shadowmeld
    if race == "Gnome" then racialSpellID = 20589 end -- Escape Artist
    if race == "Orc" then racialSpellID = 20572 end -- Blood Fury
    if race == "Tauren" then racialSpellID = 20549 end -- War Stomp
    if race == "Troll" then racialSpellID = 20554 end -- Berserking
    if race == "Scourge" or race == "Undead" then racialSpellID = 7744 end -- Will of the Forsaken

    -- TBC+ (safe to include; only shows if known)
    if not racialSpellID and race == "BloodElf" then racialSpellID = 28730 end -- Arcane Torrent
    if not racialSpellID and race == "Draenei" then racialSpellID = 28880 end -- Gift of the Naaru
    if not racialSpellID then return end

    -- Create the button even if spells are not fully loaded yet. We'll bind the
    -- secure spell attribute as soon as GetSpellInfo returns a name.
    local name, _, icon = (GetSpellInfo and GetSpellInfo(racialSpellID))
    if not icon and GetSpellTexture then icon = GetSpellTexture(racialSpellID) end
    if not icon or icon == "" then icon = "Interface/Icons/INV_Misc_QuestionMark" end

    local b = H.racialBtn
    if not (b and b.SetAttribute) then
      b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
      b:SetSize(28,28)
      if b.SetClampedToScreen then b:SetClampedToScreen(true) end
      b:SetFrameStrata("MEDIUM")
      b:SetFrameLevel(100)
      local it = b:CreateTexture(nil, "ARTWORK")
      it:SetAllPoints(b)
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
      H.racialBtn = b
      
      -- Show racial button immediately
      b:Show()
      
      -- CRITICAL: Override Hide() to keep button always visible
      local originalHideRacial = b.Hide
      b.Hide = function(self) end  -- Do nothing
      b._OriginalHide = originalHideRacial
    end

    b.spellID = racialSpellID
    if b.icon then b.icon:SetTexture(icon) end
    if b.icon and b.icon.SetDesaturated then b.icon:SetDesaturated(false) end
    if b.dim then b.dim:Hide() end

    -- Bind click-cast once we can resolve the localized name.
    if name and name ~= "" then
      H.QueueSetAttribute(b, "type", "spell")
      H.QueueSetAttribute(b, "spell", name)
      AttachSpellTooltip(b, racialSpellID)
      -- Explicitly ensure OnEnter is set in case AttachSpellTooltip failed or was overridden
      b:SetScript("OnEnter", function(self) 
        if GameTooltip and GameTooltip.SetOwner then
          H.PositionTooltip()
          if GameTooltip.SetSpellByID then 
             pcall(function() GameTooltip:SetSpellByID(racialSpellID) end)
          else
             GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
             H.PositionTooltip()
             GameTooltip:AddLine(name)
             GameTooltip:Show()
          end
          GameTooltip:Show()
        end
      end)
      b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    else
      -- Not ready yet; keep shown but not clickable until next retry.
      H._pendingRacialBuild = true
    end

    -- Place it to the RIGHT of mana pot if present (otherwise to the right of hearth).
    local rightAnchor = (H.manaBtn and H.manaBtn.IsShown and H.manaBtn:IsShown() and H.manaBtn) or H.hearthBtn
    if rightAnchor then
      b:ClearAllPoints(); b:SetPoint("LEFT", rightAnchor, "RIGHT", 8, 0)
    elseif H.potionBtn then
      b:ClearAllPoints(); b:SetPoint("LEFT", H.potionBtn, "RIGHT", 8, 0)
    else
      b:ClearAllPoints(); b:SetPoint("CENTER", UIParent, "CENTER", 120, -40)
    end
    b:Show()

    -- If the chosen anchor pushes the button off-screen (small resolutions / UI scale),
    -- fall back to a safe position.
    local px = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or nil
    local cx = (b.GetCenter and select(1, b:GetCenter())) or nil
    if px and cx and (cx < 10 or cx > (px - 10)) then
      if H.hearthBtn then
        b:ClearAllPoints(); b:SetPoint("RIGHT", H.hearthBtn, "LEFT", -8, 0)
      elseif H.potionBtn then
        b:ClearAllPoints(); b:SetPoint("LEFT", H.potionBtn, "RIGHT", 8, 0)
      else
        b:ClearAllPoints(); b:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
      end
      b:Show()
    end
    -- Use RebuildUtilityButtons for positioning (ReanchorUtilities is deprecated)
    if H.RebuildUtilityButtons then pcall(function() H.RebuildUtilityButtons() end) end
  end
  pcall(function() AddRacialUtility() end)

  -- Retry racial creation after spells load / changes (login timing on Classic)
  if not H._racialEventFrame then
    local rf = CreateFrame("Frame")
    H._racialEventFrame = rf
    rf:RegisterEvent("PLAYER_LOGIN")
    rf:RegisterEvent("PLAYER_ENTERING_WORLD")
    rf:RegisterEvent("SPELLS_CHANGED")
    rf:RegisterEvent("PLAYER_REGEN_ENABLED")
    rf:RegisterEvent("UNIT_AURA")
    rf:SetScript("OnEvent", function(self, event, ...)
      if event == "UNIT_AURA" then
        local unit = ...
        if unit ~= "player" then return end
      end
      if H._pendingRacialBuild and (not InCombatLockdown or not InCombatLockdown()) then
        H._pendingRacialBuild = nil
      end
      if H._pendingUtilityRebuild and (not InCombatLockdown or not InCombatLockdown()) then
        H._pendingUtilityRebuild = nil
        if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
      end
      if (not H.racialBtn) or (not H.racialBtn:IsShown()) or H._pendingRacialBuild then
        pcall(function() AddRacialUtility() end)
      end
    end)
  end
  H.classCDButtons = buttons

  -- Position utility buttons correctly after creation
  -- RebuildUtilityButtons will be called again after bag scan updates visibility
  pcall(function() 
    if H.RebuildUtilityButtons then 
      H.RebuildUtilityButtons() 
    end 
  end)

  -- Rebuild function for utilities (called from options when settings change)
  function H.RebuildUtilityButtons()
    if InCombatLockdown and InCombatLockdown() then
      H._pendingUtilityRebuild = true
      return
    end

    local buttonSize = (HardcoreHUDDB.utilities and HardcoreHUDDB.utilities.buttonSize) or 28
    local buttonGap = (HardcoreHUDDB.utilities and HardcoreHUDDB.utilities.buttonGap) or 8
    local independent = (HardcoreHUDDB.utilities and HardcoreHUDDB.utilities.independent) or false
    local offsetX = (HardcoreHUDDB.utilities and HardcoreHUDDB.utilities.offsetX) or 0
    local offsetY = (HardcoreHUDDB.utilities and HardcoreHUDDB.utilities.offsetY) or -36

    -- Update utility button sizes
    local utilButtons = { H.potionBtn, H.manaBtn, H.bandageBtn, H.hearthBtn, H.racialBtn }
    for _, btn in ipairs(utilButtons) do
      if btn then
        btn:SetSize(buttonSize, buttonSize)
      end
    end

    -- Update utility button gaps and positions
    -- Correctly center all visible buttons as a single group to prevent gaps
    -- Order: Bandage, HP-Pot, Mana-Pot, Hearth, Racial
    
    -- Determine which buttons should be visible (but don't show them yet!)
    local utilOrder = { H.bandageBtn, H.potionBtn, H.manaBtn, H.hearthBtn, H.racialBtn }
    local visible = {}
    for _, b in ipairs(utilOrder) do
      if b then
        -- Check if this button should be visible
        local shouldShow = true
        if b == H.bandageBtn and not H.bandageBtn._hasFirstAid then
          shouldShow = false
        end
        if shouldShow then
          table.insert(visible, b)
        end
      end
    end

    if #visible > 0 then
      local totalW = (#visible * buttonSize) + ((#visible - 1) * buttonGap)
      local startX = -(totalW / 2) + (buttonSize / 2)
      
      local anchorFrame = (H.bars and H.bars.combo) or (H.bars and H.bars.pow) or UIParent
      local anchorPt = "BOTTOM"
      local myPt = "TOP"
      local baseX = 0
      local baseY = -8
      
      if anchorFrame == UIParent then 
         anchorPt = "CENTER"; myPt = "CENTER"; baseY = -40 
      end
      
      if independent then
         anchorFrame = UIParent
         anchorPt = "CENTER"
         myPt = "CENTER"
         baseX = offsetX
         baseY = offsetY
      end

      -- First position all buttons, THEN show them (prevents flicker at old position)
      for i, btn in ipairs(visible) do
        btn:ClearAllPoints()
        local x = baseX + startX + ((i-1) * (buttonSize + buttonGap))
        btn:SetPoint(myPt, anchorFrame, anchorPt, x, baseY)
        btn:Show()  -- Show AFTER positioning
      end
    end


    -- Update CD button sizes and positioning
    if H.classCDButtons then
      local cdSize = buttonSize
      local cdGap = buttonGap
      local anchorParent = H.utilRow or (H.bars and (H.bars.pow or H.bars.combo)) or UIParent
      local baseOffsetY = independent and offsetY or -36
      local baseOffsetX = independent and offsetX or 0

      for idx, btn in ipairs(H.classCDButtons) do
        btn:SetSize(cdSize, cdSize)
        btn:ClearAllPoints()
        local xPos = baseOffsetX + (-((#H.classCDButtons * cdSize) / 2) + 15) + (idx-1) * (cdSize + cdGap)
        btn:SetPoint("TOP", anchorParent, "BOTTOM", xPos, baseOffsetY)
      end
    end
    
    -- Apply offset relative to the calculated CD bar position
    -- Note: independent offsets for utilities are handled in the block above.
    
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.utilities then
      DEFAULT_CHAT_FRAME:AddMessage("[HardcoreHUD] Utility buttons rebuilt: size=" ..buttonSize.. " gap=" ..buttonGap.. " independent=" ..(independent and "YES" or "NO"))
    end
  end

  -- Hide legacy Bars.lua cdIcons to avoid duplicate class cooldown rows
  if H.bars and H.bars.cdIcons then
    for _, info in ipairs(H.bars.cdIcons) do
      if info and info.btn and info.btn.Hide then pcall(function() info.btn:Hide() end) end
    end
  end

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
          if b.cdText then b.cdText:SetText(ShortTime(remain)); b.cdText:Show() end
          b:SetAlpha(1)
        else
          if b.cooldown then b.cooldown:Hide() end
          if b.cdText then b.cdText:Hide() end
          b:SetAlpha(1)
          if b.icon and b.icon.SetDesaturated then b.icon:SetDesaturated(false) end
          if b.dim then b.dim:Hide() end
        end
        -- Emergency pulse logic
        if HardcoreHUDDB.emergency and HardcoreHUDDB.emergency.enabled and EMERGENCY_SPELLS[b.spellID] then
          -- Suppress emergency pulse when dead, ghost, or UI panel is open
          local uiPanelOpen = false
          if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then uiPanelOpen = true end
          if GameMenuFrame and GameMenuFrame:IsShown() then uiPanelOpen = true end
          
          if (UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player")) or uiPanelOpen then
            if b._pulseBorder then b._pulseBorder:Hide() end
          else
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
      end
      -- Potion cooldown (spiral + dim + big number)
      -- In Classic Era, potions share a 2-minute category cooldown
      -- We check any known healing potion ID to get the shared cooldown state
      if H.potionBtn then
        local checkID = H.potionBtn.itemID
        -- Fallback: check a common potion ID if no specific item bound
        if not checkID then
          for id, _ in pairs(HEAL_POTION_RANKS) do
            if GetItemCount and GetItemCount(id) > 0 then checkID = id; break end
          end
        end
        local ps, pd, pe = 0, 0, 1
        if checkID then
          ps, pd, pe = GetItemCooldownSafe(checkID)
        end
        -- Detect active cooldown: duration > 1.5s (not just GCD) and remaining > 0
        local prem = 0
        local onCooldown = false
        if ps and pd and ps > 0 and pd > 1.5 then
          prem = (ps + pd) - GetTime()
          if prem > 0 then
            onCooldown = true
          end
        end
        if onCooldown and prem > 0 then
          if H.potionBtn.cooldown and H.potionBtn.cooldown.SetCooldown then 
            H.potionBtn.cooldown:SetCooldown(ps, pd)
            H.potionBtn.cooldown:Show() 
          end
          if H.potionBtn.icon and H.potionBtn.icon.SetDesaturated then H.potionBtn.icon:SetDesaturated(true) end
          if H.potionBtn.dim then H.potionBtn.dim:Show() end
          if H.potionBtn.cdText then H.potionBtn.cdText:SetText(ShortTime(prem)); H.potionBtn.cdText:Show() end
        else
          if H.potionBtn.cooldown then H.potionBtn.cooldown:Hide() end
          if H.potionBtn.cdText then H.potionBtn.cdText:SetText(""); H.potionBtn.cdText:Hide() end
          if H.potionBtn.icon and H.potionBtn.icon.SetDesaturated then H.potionBtn.icon:SetDesaturated(false) end
          if H.potionBtn.dim then H.potionBtn.dim:Hide() end
        end
      end
      -- Mana potion cooldown (spiral + dim + big number)
      -- Mana potions share the same 2-minute category cooldown as healing potions
      if H.manaBtn then
        local checkID = H.manaBtn.itemID
        -- Fallback: check a common mana potion ID if no specific item bound
        if not checkID then
          for id, _ in pairs(MANA_POTION_RANKS) do
            if GetItemCount and GetItemCount(id) > 0 then checkID = id; break end
          end
        end
        local ps, pd, pe = 0, 0, 1
        if checkID then
          ps, pd, pe = GetItemCooldownSafe(checkID)
        end
        -- Detect active cooldown: duration > 1.5s and remaining > 0
        local prem = 0
        local onCooldown = false
        if ps and pd and ps > 0 and pd > 1.5 then
          prem = (ps + pd) - GetTime()
          if prem > 0 then
            onCooldown = true
          end
        end
        if onCooldown and prem > 0 then
          if H.manaBtn.cooldown and H.manaBtn.cooldown.SetCooldown then 
            H.manaBtn.cooldown:SetCooldown(ps, pd)
            H.manaBtn.cooldown:Show() 
          end
          if H.manaBtn.icon and H.manaBtn.icon.SetDesaturated then H.manaBtn.icon:SetDesaturated(true) end
          if H.manaBtn.dim then H.manaBtn.dim:Show() end
          if H.manaBtn.cdText then H.manaBtn.cdText:SetText(ShortTime(prem)); H.manaBtn.cdText:Show() end
        else
          if H.manaBtn.cooldown then H.manaBtn.cooldown:Hide() end
          if H.manaBtn.cdText then H.manaBtn.cdText:SetText(""); H.manaBtn.cdText:Hide() end
          if H.manaBtn.icon and H.manaBtn.icon.SetDesaturated then H.manaBtn.icon:SetDesaturated(false) end
          if H.manaBtn.dim then H.manaBtn.dim:Hide() end
        end
      end
      -- Hearthstone cooldown (spiral + dim + big number)
      if H.hearthBtn then
        local checkID = H.hearthBtn.itemID or 6948 -- Hearthstone item ID
        local ps, pd, pe = GetItemCooldownSafe(checkID)
        -- Detect active cooldown: duration > 1.5s and remaining > 0
        local prem = 0
        local onCooldown = false
        if ps and pd and ps > 0 and pd > 1.5 then
          prem = (ps + pd) - GetTime()
          if prem > 0 then
            onCooldown = true
          end
        end
        if onCooldown and prem > 0 then
          if H.hearthBtn.cooldown and H.hearthBtn.cooldown.SetCooldown then 
            H.hearthBtn.cooldown:SetCooldown(ps, pd)
            H.hearthBtn.cooldown:Show() 
          end
          if H.hearthBtn.icon and H.hearthBtn.icon.SetDesaturated then H.hearthBtn.icon:SetDesaturated(true) end
          if H.hearthBtn.dim then H.hearthBtn.dim:Show() end
          if H.hearthBtn.cdText then H.hearthBtn.cdText:SetText(ShortTime(prem)); H.hearthBtn.cdText:Show() end
        else
          if H.hearthBtn.cooldown then H.hearthBtn.cooldown:Hide() end
          if H.hearthBtn.cdText then H.hearthBtn.cdText:SetText(""); H.hearthBtn.cdText:Hide() end
          if H.hearthBtn.icon and H.hearthBtn.icon.SetDesaturated then H.hearthBtn.icon:SetDesaturated(false) end
          if H.hearthBtn.dim then H.hearthBtn.dim:Hide() end
        end
      end
      -- Racial cooldown (utility row)
      if H.racialBtn and H.racialBtn.spellID then
        local s, d, e = GetSpellCooldown(H.racialBtn.spellID)
        s = s or 0; d = d or 0; e = e or 0
        local onCooldown = (e == 1 and d > 1.5 and s > 0)
        if onCooldown then
          local rem = (s + d) - GetTime(); if rem < 0 then rem = 0 end
          if H.racialBtn.cooldown and H.racialBtn.cooldown.SetCooldown then 
            H.racialBtn.cooldown:SetCooldown(s, d)
            H.racialBtn.cooldown:Show() 
          end
          if H.racialBtn.icon and H.racialBtn.icon.SetDesaturated then H.racialBtn.icon:SetDesaturated(true) end
          if H.racialBtn.dim then H.racialBtn.dim:Show() end
          if H.racialBtn.cdText then H.racialBtn.cdText:SetText(ShortTime(rem)); H.racialBtn.cdText:Show() end
        else
          if H.racialBtn.cooldown then H.racialBtn.cooldown:Hide() end
          if H.racialBtn.cdText then H.racialBtn.cdText:SetText(""); H.racialBtn.cdText:Hide() end
          if H.racialBtn.icon and H.racialBtn.icon.SetDesaturated then H.racialBtn.icon:SetDesaturated(false) end
          if H.racialBtn.dim then H.racialBtn.dim:Hide() end
        end
      end
      -- Bandage cooldown (spiral + dim + big number)
      -- Bandages have their own 60-second "Recently Bandaged" debuff cooldown
      if H.bandageBtn then
        local checkID = H.bandageBtn.itemID
        -- Fallback: check a common bandage ID if no specific item bound
        if not checkID then
          for id, _ in pairs(BANDAGE_RANKS) do
            if GetItemCount and GetItemCount(id) > 0 then checkID = id; break end
          end
        end
        local ps, pd, pe = 0, 0, 1
        if checkID then
          ps, pd, pe = GetItemCooldownSafe(checkID)
        end
        -- Detect active cooldown: duration > 1.5s and remaining > 0
        local prem = 0
        local onCooldown = false
        if ps and pd and ps > 0 and pd > 1.5 then
          prem = (ps + pd) - GetTime()
          if prem > 0 then
            onCooldown = true
          end
        end
        if onCooldown and prem > 0 then
          if H.bandageBtn.cooldown and H.bandageBtn.cooldown.SetCooldown then 
            H.bandageBtn.cooldown:SetCooldown(ps, pd)
            H.bandageBtn.cooldown:Show() 
          end
          if H.bandageBtn.icon and H.bandageBtn.icon.SetDesaturated then H.bandageBtn.icon:SetDesaturated(true) end
          if H.bandageBtn.dim then H.bandageBtn.dim:Show() end
          if H.bandageBtn.cdText then H.bandageBtn.cdText:SetText(ShortTime(prem)); H.bandageBtn.cdText:Show() end
        else
          if H.bandageBtn.cooldown then H.bandageBtn.cooldown:Hide() end
          if H.bandageBtn.cdText then H.bandageBtn.cdText:SetText(""); H.bandageBtn.cdText:Hide() end
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
      -- Just rebuild layout, don't recreate buttons
      -- The buttons already exist, we just need to reposition them
      if H.RebuildUtilityButtons then
        pcall(function() H.RebuildUtilityButtons() end)
      end
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
            local link = GetSpellLink and GetSpellLink(btn.spellID) or nil
            if link then
              local ok, res = pcall(function() GameTooltip:SetHyperlink(link) end)
              if not ok then
                GameTooltip:ClearLines(); GameTooltip:AddLine(link)
              end
              GameTooltip:Show()
            else
              local nm = GetSpellInfo and select(1, GetSpellInfo(btn.spellID)) or nil
              GameTooltip:ClearLines()
              if nm then GameTooltip:AddLine(nm,1,1,1) end
              if GetSpellDescription then
                local d = GetSpellDescription(btn.spellID)
                if d and d ~= "" then GameTooltip:AddLine(d,0.9,0.9,0.9,true) end
              end
              GameTooltip:Show()
            end
            if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.tooltips then
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

-- DEPRECATED: Use RebuildUtilityButtons() instead
-- This function is kept as a stub for backwards compatibility
function H.ReanchorUtilities()
  -- Redirect to RebuildUtilityButtons for consistent centered layout
  if H.RebuildUtilityButtons then
    H.RebuildUtilityButtons()
  end
end

-- Auto-reanchor utilities on common rebuild events
do
  local rf = CreateFrame("Frame")
  rf:RegisterEvent("PLAYER_LEVEL_UP")
  rf:RegisterEvent("PLAYER_ENTERING_WORLD")
  rf:RegisterEvent("SPELLS_CHANGED")
  rf:RegisterEvent("PLAYER_REGEN_ENABLED")
  rf:SetScript("OnEvent", function()
    if H._pendingReanchorUtilities and (not InCombatLockdown or not InCombatLockdown()) then
      H._pendingReanchorUtilities = nil
    end
    -- Use RebuildUtilityButtons instead of ReanchorUtilities for modern centered layout
    if H.RebuildUtilityButtons then 
      H.RebuildUtilityButtons()
    end
    -- Force mana button visible after any rebuild
    if H.manaBtn then
      pcall(function() H.manaBtn:Show() end)
    end
  end)
end

-- Disable mouse on HUD bars so camera drag isn’t blocked when locked
function H.SetHUDMouseEnabled(isLocked)
  -- When locked: disable mouse on non-interactive HUD bars; keep utility buttons clickable
  local enableBarsMouse = not isLocked
  if H.bars then
    if H.bars.hp and H.bars.hp.EnableMouse then H.bars.hp:EnableMouse(enableBarsMouse) end
    if H.bars.pow and H.bars.pow.EnableMouse then H.bars.pow:EnableMouse(enableBarsMouse) end
    if H.bars.targetHP and H.bars.targetHP.EnableMouse then H.bars.targetHP:EnableMouse(enableBarsMouse) end
    if H.bars.targetPow and H.bars.targetPow.EnableMouse then H.bars.targetPow:EnableMouse(enableBarsMouse) end
    if H.bars.fs and H.bars.fs.EnableMouse then H.bars.fs:EnableMouse(enableBarsMouse) end
    if H.bars.tick and H.bars.tick.EnableMouse then H.bars.tick:EnableMouse(enableBarsMouse) end
  end
  -- Also toggle root frame mouse so it doesn't intercept clicks when options are shown
  if H.root and H.root.EnableMouse then
    pcall(function() H.root:EnableMouse(enableBarsMouse) end)
  end
  -- Utility buttons should remain clickable; do not disable
  -- H.potionBtn, H.manaBtn, H.bandageBtn, H.hearthBtn remain enabled
end

-- Apply initial mouse behavior on login and after bars are built
do
  local mFrame = CreateFrame("Frame")
  mFrame:RegisterEvent("PLAYER_LOGIN")
  mFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  mFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  mFrame:RegisterEvent("UNIT_TARGET")
  mFrame:SetScript("OnEvent", function()
    local locked = HardcoreHUDDB and HardcoreHUDDB.lock -- use unified 'lock' key
    -- Prefer centralized lock application in Core if present
    if H.ApplyLock then H.ApplyLock() else
      if H.SetHUDMouseEnabled then H.SetHUDMouseEnabled(locked and true or false) end
    end
  end)
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
      "inner fire",
      -- Added core priest spirit buff (enUS + deDE)
      "divine spirit", "göttlicher wille",
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

-- ============================================================================
-- LOCALIZATION-SAFE SPELL ID TABLES (Classic Era 1.15.x)
-- Using Spell IDs instead of names for multi-language support (DE, FR, etc.)
-- ============================================================================
local CLASS_BUFF_SPELLS = {
  -- PALADIN
  RIGHTEOUS_FURY       = 25780,  -- Rank 1 (only rank in Classic)
  BLESSING_OF_KINGS    = 20217,  -- Rank 1
  BLESSING_OF_SANCTUARY = 20911, -- Rank 1
  BLESSING_OF_MIGHT    = 19740,  -- Rank 1
  BLESSING_OF_WISDOM   = 19742,  -- Rank 1
  -- PRIEST
  POWER_WORD_FORTITUDE = 1243,   -- Rank 1
  PRAYER_OF_FORTITUDE  = {21562, 21564},  -- Rank 1, Rank 2
  INNER_FIRE           = 588,    -- Rank 1
  DIVINE_SPIRIT        = 14752,  -- Rank 1
  PRAYER_OF_SPIRIT     = {27681, 27841},  -- Rank 1, Rank 2
  SHADOW_PROTECTION    = 976,    -- Rank 1
  PRAYER_OF_SHADOW     = {27683, 27685},  -- Rank 1, Rank 2
  -- DRUID
  MARK_OF_THE_WILD     = 1126,   -- Rank 1
  GIFT_OF_THE_WILD     = {21849, 21850},  -- Rank 1, Rank 2
  THORNS               = 467,    -- Rank 1
  -- MAGE
  ARCANE_INTELLECT     = 1459,   -- Rank 1
  ARCANE_BRILLIANCE    = {23028, 27127},  -- Rank 1, Rank 2
  MAGE_ARMOR           = 6117,   -- Rank 1
  ICE_ARMOR            = 7302,   -- Rank 1
  FROST_ARMOR          = 168,    -- Rank 1
  -- WARRIOR
  BATTLE_SHOUT         = 6673,   -- Rank 1
  -- SHAMAN
  LIGHTNING_SHIELD     = 324,    -- Rank 1
  WATER_SHIELD         = 24398,  -- (TBC+ but safe)
  -- WARLOCK
  DEMON_ARMOR          = 706,    -- Rank 1
  FEL_ARMOR            = 28176,  -- (TBC+ but safe)
  -- HUNTER
  ASPECT_OF_THE_HAWK   = 13165,  -- Rank 1
  ASPECT_OF_THE_MONKEY = 13163,
  -- ROGUE (no self-buffs typically)
}

-- Helper: Check if player has a buff by spell ID (works with any locale)
-- Supports single ID or table of IDs (for multi-rank spells)
local function PlayerHasBuffBySpellID(spellIDorTable)
  if not spellIDorTable then return false end
  
  -- Handle table of spell IDs (multiple ranks)
  if type(spellIDorTable) == "table" then
    for _, spellID in ipairs(spellIDorTable) do
      local spellName = GetSpellInfo and GetSpellInfo(spellID)
      if spellName then
        for i = 1, 40 do
          local buffName = UnitBuff("player", i)
          if not buffName then break end
          if buffName == spellName then return true end
        end
      end
    end
    return false
  end
  
  -- Single spell ID
  local spellName = GetSpellInfo and GetSpellInfo(spellIDorTable)
  if not spellName then return false end
  for i = 1, 40 do
    local buffName = UnitBuff("player", i)
    if not buffName then break end
    if buffName == spellName then return true end
  end
  return false
end

-- Helper: Check if player has ANY of a list of spell IDs as a buff
local function PlayerHasAnyBuffBySpellIDs(spellIDs)
  if not spellIDs then return false end
  for _, id in ipairs(spellIDs) do
    if PlayerHasBuffBySpellID(id) then return true end
  end
  return false
end

-- Helper: Check if player knows a spell by ID
local function IsSpellKnownByID(spellID)
  if not spellID then return false end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
  -- Fallback: check spellbook by localized name
  local spellName = GetSpellInfo and GetSpellInfo(spellID)
  if spellName and GetSpellBookItemName then
    local i = 1
    while true do
      local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
      if not name then break end
      if string.find(name, spellName, 1, true) then return true end
      i = i + 1
      if i > 300 then break end
    end
  end
  return false
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
      table.insert(buffs, "Divine Spirit")
    elseif class == "DRUID" then
      -- 1 Balance, 2 Feral, 3 Restoration
      table.insert(buffs, "Mark of the Wild")
      if treeIdx == 2 then table.insert(buffs, "Thorns") end
    elseif class == "MAGE" then
      table.insert(buffs, "Arcane Intellect")
      -- Prefer Mage Armor; fallback to Ice/Frost Armor
      table.insert(buffs, "Mage Armor")
      table.insert(buffs, "Ice Armor")
      table.insert(buffs, "Frost Armor")
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
  if rf.SetFrameStrata then rf:SetFrameStrata("MEDIUM") end
  H.SafeBackdrop(rf, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} }, 0,0,0,0.75)
  rf.text = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rf.text:SetPoint("TOPLEFT", rf, "TOPLEFT", 6, -6)
  rf.text:SetJustifyH("LEFT")
  -- Disable mouse/keyboard to prevent blocking game input
  rf:EnableMouse(false)
  rf:SetMouseClickEnabled(false)
  if rf.EnableKeyboard then rf:EnableKeyboard(false) end
  if rf.SetPropagateKeyboardInput then rf:SetPropagateKeyboardInput(true) end
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
    -- Combat-safe: skip ALL updates during combat to avoid taint on secure buttons
    local inCombat = InCombatLockdown()
    if inCombat then
      -- Schedule refresh after combat ends
      return
    end
    
    if not HardcoreHUDDB.reminders.enabled then
      pcall(function() rf:Hide() end)
      return
    end
      -- Safety: keep frame hidden until we know we have entries
      pcall(function() rf:Hide() end)

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
      local a,b = SafeFindInBags(function(bag, slot)
        local id = GetContainerItemID and GetContainerItemID(bag,slot)
        if not id then return nil end
        local name, _, _, _, _, itemType, itemSubType, _, _, texture = GetItemInfo(id)
        if not name then name = GetItemNameSafe(id, bag, slot) end
        local lname = string.lower(name or "")
        local isConsum = (itemType == "Consumable")
        local subtypeMatch = (itemSubType == subtype)
        if not subtypeMatch and subtype == "Food & Drink" then
          if string.find(lname, "food") or string.find(lname, "feast") or string.find(lname, "water") or string.find(lname, "drink") or string.find(lname, "bread") or string.find(lname, "fish") then
            subtypeMatch = true
          end
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
              return nil
            else
              return id, texture
            end
          else
            return id, texture
          end
        end
        return nil
      end)
      return a, b
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
              if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.reminders then
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
                  if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.reminders then
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
                if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.reminders then
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

    -- Check if player knows a spell (required before showing reminder buttons)
    local function IsSpellLearned(spellName)
      -- First try GetSpellInfo to get the spell ID
      local _, spellID = GetSpellInfo(spellName)
      if spellID and spellID > 0 then
        -- Try C_SpellBook.IsSpellKnown with numeric ID
        if C_SpellBook and C_SpellBook.IsSpellKnown then
          if pcall(C_SpellBook.IsSpellKnown, spellID) then
            return C_SpellBook.IsSpellKnown(spellID)
          end
        end
        -- Fallback to IsPlayerSpell with numeric ID
        if IsPlayerSpell and pcall(IsPlayerSpell, spellID) then
          return IsPlayerSpell(spellID)
        end
      end
      -- Fallback: check spellbook for the spell name (most reliable for Classic)
      if GetSpellBookItemName then
        local i = 1
        while true do
          local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
          if not name then break end
          if name == spellName then return true end
          -- Also check if name is in the spellbook (case-insensitive prefix match for rank variants)
          if string.find(name, spellName, 1, true) then return true end
          i = i + 1
          if i > 300 then break end
        end
      end
      return false
    end
    
    -- Helper to check if a profession skill is learned (First Aid, etc)
    local function IsSkillLearned(skillName)
      if not GetSkillLineInfo then return false end
      local line = 1
      while true do
        local name, _, _, cap = GetSkillLineInfo(line)
        if not name then break end
        if name == skillName then
          return cap and cap > 0
        end
        line = line + 1
        if line > 200 then break end
      end
      return false
    end

    -- Class self-buffs buttons (show only when missing and category enabled)
    -- NEW: Support both spell names (legacy) and spell IDs (localization-safe)
    local function AddSpellByID(spellID)
        if not spellID then return end
        -- Check if spell is known
        if not IsSpellKnownByID(spellID) then return end
        
        local name, _, tex = GetSpellInfo and GetSpellInfo(spellID)
        if not name then return end -- Spell doesn't exist
        if (not tex or tex == "") and GetSpellTexture then tex = GetSpellTexture(spellID) end
        if not tex or tex == "" then tex = "Interface/Icons/INV_Misc_QuestionMark" end
        table.insert(entries, {kind="spell", spell=name, texture=tex, label=name, spellID=spellID})
    end

    local function AddSpellIfKnown(spellName)
        -- CRITICAL: Only add the button if the player has actually learned this spell
        if not IsSpellLearned(spellName) then return end
        
        local name, _, tex = GetSpellInfo and GetSpellInfo(spellName)
        -- More reliable texture resolution: try GetSpellTexture when icon is nil
        if (not tex or tex == "") and GetSpellTexture then tex = GetSpellTexture(spellName) end
        -- If we reach here, spell is learned but GetSpellInfo returned nil (localized client)
        if not name then
          name = spellName
          if not tex or tex == "" then tex = "Interface/Icons/INV_Misc_QuestionMark" end
          table.insert(entries, {kind="spell", spell=name, texture=tex, label=name, unresolved=true})
        else
          table.insert(entries, {kind="spell", spell=name, texture=tex, label=name})
        end
    end
    -- From our ExpectedClassBuffs + core self-cast options
    local class = select(2, UnitClass("player"))
    local coreAdded = 0
    local presentAll = PlayerBuffNames()
    
    -- NEW: Localization-safe buff detection using Spell IDs
    local function HasAnyCoreBuffForClass(class, present)
      if class == "PALADIN" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.RIGHTEOUS_FURY) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_SANCTUARY) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_KINGS)
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_MIGHT)
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_WISDOM)
      elseif class == "PRIEST" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.POWER_WORD_FORTITUDE) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.PRAYER_OF_FORTITUDE)
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.INNER_FIRE) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.DIVINE_SPIRIT)
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.PRAYER_OF_SPIRIT)
      elseif class == "DRUID" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.MARK_OF_THE_WILD) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.GIFT_OF_THE_WILD) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.THORNS)
      elseif class == "MAGE" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ARCANE_INTELLECT) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ARCANE_BRILLIANCE)
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.MAGE_ARMOR) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ICE_ARMOR) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.FROST_ARMOR)
      elseif class == "WARRIOR" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BATTLE_SHOUT)
      elseif class == "SHAMAN" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.WATER_SHIELD) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.LIGHTNING_SHIELD)
      elseif class == "WARLOCK" then
        return PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.FEL_ARMOR) 
            or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.DEMON_ARMOR)
      end
      return false
    end
    
    -- PALADIN buffs (ID-based)
    if class == "PALADIN" and (cats.survival ~= false) then
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.RIGHTEOUS_FURY) then 
        AddSpellByID(CLASS_BUFF_SPELLS.RIGHTEOUS_FURY); coreAdded = coreAdded + 1 
      end
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
        if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_SANCTUARY) then
          AddSpellByID(CLASS_BUFF_SPELLS.BLESSING_OF_SANCTUARY); coreAdded = coreAdded + 1
        end
      else
        local hasSanctuary = PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_SANCTUARY)
        if not hasSanctuary and not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BLESSING_OF_KINGS) then
          AddSpellByID(CLASS_BUFF_SPELLS.BLESSING_OF_KINGS); coreAdded = coreAdded + 1
        end
      end
    -- PRIEST buffs (ID-based)
    elseif class == "PRIEST" and (cats.survival ~= false) then
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.POWER_WORD_FORTITUDE) 
         and not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.PRAYER_OF_FORTITUDE) then 
        AddSpellByID(CLASS_BUFF_SPELLS.POWER_WORD_FORTITUDE); coreAdded = coreAdded + 1 
      end
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.INNER_FIRE) then 
        AddSpellByID(CLASS_BUFF_SPELLS.INNER_FIRE); coreAdded = coreAdded + 1 
      end
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.DIVINE_SPIRIT) 
         and not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.PRAYER_OF_SPIRIT) then 
        AddSpellByID(CLASS_BUFF_SPELLS.DIVINE_SPIRIT); coreAdded = coreAdded + 1 
      end
    -- DRUID buffs (ID-based)
    elseif class == "DRUID" and (cats.survival ~= false) then
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.MARK_OF_THE_WILD) 
         and not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.GIFT_OF_THE_WILD) then 
        AddSpellByID(CLASS_BUFF_SPELLS.MARK_OF_THE_WILD); coreAdded = coreAdded + 1 
      end
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.THORNS) then 
        AddSpellByID(CLASS_BUFF_SPELLS.THORNS); coreAdded = coreAdded + 1 
      end
    -- MAGE buffs (ID-based)
    elseif class == "MAGE" and (cats.survival ~= false) then
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ARCANE_INTELLECT) 
         and not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ARCANE_BRILLIANCE) then 
        AddSpellByID(CLASS_BUFF_SPELLS.ARCANE_INTELLECT); coreAdded = coreAdded + 1 
      end
      local hasArmor = PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.MAGE_ARMOR) 
                    or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.ICE_ARMOR) 
                    or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.FROST_ARMOR)
      if not hasArmor then
        -- Prefer Mage Armor > Ice Armor > Frost Armor
        if IsSpellKnownByID(CLASS_BUFF_SPELLS.MAGE_ARMOR) then
          AddSpellByID(CLASS_BUFF_SPELLS.MAGE_ARMOR); coreAdded = coreAdded + 1
        elseif IsSpellKnownByID(CLASS_BUFF_SPELLS.ICE_ARMOR) then
          AddSpellByID(CLASS_BUFF_SPELLS.ICE_ARMOR); coreAdded = coreAdded + 1
        elseif IsSpellKnownByID(CLASS_BUFF_SPELLS.FROST_ARMOR) then
          AddSpellByID(CLASS_BUFF_SPELLS.FROST_ARMOR); coreAdded = coreAdded + 1
        end
      end
    -- WARRIOR buffs (ID-based)
    elseif class == "WARRIOR" and (cats.survival ~= false) then
      if not PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.BATTLE_SHOUT) then 
        AddSpellByID(CLASS_BUFF_SPELLS.BATTLE_SHOUT); coreAdded = coreAdded + 1 
      end
    -- SHAMAN buffs (ID-based)
    elseif class == "SHAMAN" and (cats.survival ~= false) then
      local hasShield = PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.WATER_SHIELD) 
                     or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.LIGHTNING_SHIELD)
      if not hasShield then 
        -- Prefer Water Shield if known, otherwise Lightning Shield
        if IsSpellKnownByID(CLASS_BUFF_SPELLS.WATER_SHIELD) then
          AddSpellByID(CLASS_BUFF_SPELLS.WATER_SHIELD); coreAdded = coreAdded + 1
        else
          AddSpellByID(CLASS_BUFF_SPELLS.LIGHTNING_SHIELD); coreAdded = coreAdded + 1
        end
      end
    -- WARLOCK buffs (ID-based)
    elseif class == "WARLOCK" and (cats.survival ~= false) then
      local hasArmor = PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.FEL_ARMOR) 
                    or PlayerHasBuffBySpellID(CLASS_BUFF_SPELLS.DEMON_ARMOR)
      if not hasArmor then 
        -- Prefer Fel Armor if known, otherwise Demon Armor
        if IsSpellKnownByID(CLASS_BUFF_SPELLS.FEL_ARMOR) then
          AddSpellByID(CLASS_BUFF_SPELLS.FEL_ARMOR); coreAdded = coreAdded + 1
        else
          AddSpellByID(CLASS_BUFF_SPELLS.DEMON_ARMOR); coreAdded = coreAdded + 1
        end
      end
    end
    
    -- Fallback: if detection found none, show canonical core buff buttons
    if (cats.survival ~= false) and coreAdded == 0 and not HasAnyCoreBuffForClass(class, presentAll) then
      if class == "PALADIN" then
        AddSpellByID(CLASS_BUFF_SPELLS.RIGHTEOUS_FURY)
        AddSpellByID(CLASS_BUFF_SPELLS.BLESSING_OF_KINGS)
      elseif class == "PRIEST" then
        AddSpellByID(CLASS_BUFF_SPELLS.POWER_WORD_FORTITUDE)
        AddSpellByID(CLASS_BUFF_SPELLS.INNER_FIRE)
      elseif class == "DRUID" then
        AddSpellByID(CLASS_BUFF_SPELLS.MARK_OF_THE_WILD)
        AddSpellByID(CLASS_BUFF_SPELLS.THORNS)
      elseif class == "MAGE" then
        AddSpellByID(CLASS_BUFF_SPELLS.ARCANE_INTELLECT)
        AddSpellByID(CLASS_BUFF_SPELLS.MAGE_ARMOR)
      elseif class == "WARRIOR" then
        AddSpellByID(CLASS_BUFF_SPELLS.BATTLE_SHOUT)
      elseif class == "SHAMAN" then
        AddSpellByID(CLASS_BUFF_SPELLS.LIGHTNING_SHIELD)
      elseif class == "WARLOCK" then
        AddSpellByID(CLASS_BUFF_SPELLS.DEMON_ARMOR)
      end
    end

    -- Layout buttons
    rf.btns = rf.btns or {}
    local size, pad = 28, 6
    local cols = 6
    local function ensure(i)
      if rf.btns[i] then return rf.btns[i] end
      -- Cannot create secure buttons during combat - return nil and skip
      if InCombatLockdown() then return nil end
      local b = CreateFrame("Button", nil, rf, "SecureActionButtonTemplate")
      b:SetSize(size, size)
      -- Ensure keyboard input is propagated through reminder buttons
      if b.EnableKeyboard then b:EnableKeyboard(false) end
      if b.SetPropagateKeyboardInput then
        b:SetPropagateKeyboardInput(true)
      end
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
          if link then
            local ok = pcall(function() GameTooltip:SetHyperlink(link) end)
            if not ok and GameTooltip.SetBagItem and self.bag and self.slot then
              GameTooltip:SetBagItem(self.bag, self.slot)
            elseif not ok then
              GameTooltip:SetText(name or (self.label or "Item"))
            end
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
      local attrItem = nil
      if GetItemInfo then
        local iname = GetItemInfo(id)
        if iname and iname ~= "" then attrItem = iname end
      end
      if not attrItem then attrItem = "item:"..tostring(id) end
      -- Direct SetAttribute is safe here - UpdateReminders exits early during combat
      b:SetAttribute("type", "item")
      b:SetAttribute("item", attrItem)
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
      -- Direct SetAttribute is safe here - UpdateReminders exits early during combat
      b:SetAttribute("type", "spell")
      b:SetAttribute("spell", name)
      -- Always target self for reminder buffs, regardless of current target
      b:SetAttribute("unit", "player")
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
        if b then  -- nil if created during combat
          place(b, shown)
          if e.kind == "item" then setItem(b, e.id, e.texture) else setSpell(b, e.spell, e.texture) end
          if not InCombatLockdown() then pcall(function() b:Show() end) end
        end
      end
    end
    -- hide the rest (combat-safe)
    if not InCombatLockdown() then
      for i=shown+1,(rf.btns and #rf.btns or 0) do if rf.btns[i] then pcall(function() rf.btns[i]:Hide() end) end end
    end

    -- Resize frame to fit buttons; hide if no entries
    if shown == 0 then
      if not InCombatLockdown() and rf.btns then
        for i=1,#rf.btns do pcall(function() rf.btns[i]:Hide() end) end
      end
      if not InCombatLockdown() then pcall(function() rf:Hide() end) end
      return
    end
    -- otherwise layout and show
    local rows = math.max(1, math.ceil(shown/cols))
    local w = 16 + math.min(shown, cols)*(size+pad) - pad
    local h = 16 + rows*(size+pad) - pad
    rf:SetSize(w, h)
    rf.text:SetText("")
    -- Ensure the reminder frame is shown when there are actionable entries (combat-safe)
    if not rf:IsShown() and not InCombatLockdown() then pcall(function() rf:Show() end) end
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.reminders then
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

  -- Debug command to check button positions
  SLASH_HHDBGBTNS1 = "/hhdbg"
  SlashCmdList["HHDBGBTNS"] = function()
    local function CheckBtn(name, btn)
      if not btn then
        print(name..": NIL")
        return
      end
      local shown = (btn.IsShown and btn:IsShown()) and "SHOWN" or "HIDDEN"
      local visible = (btn.IsVisible and btn:IsVisible()) and "VISIBLE" or "NOT_VISIBLE"
      local w, h = 0, 0
      if btn.GetSize then w, h = btn:GetSize() end
      local x, y = nil, nil
      if btn.GetCenter then x, y = btn:GetCenter() end
      local a = (btn.GetAlpha and btn:GetAlpha()) or 1
      local s = (btn.GetScale and btn:GetScale()) or 1
      local strata = (btn.GetFrameStrata and btn:GetFrameStrata()) or "?"
      local level = (btn.GetFrameLevel and btn:GetFrameLevel()) or 0
      local npts = (btn.GetNumPoints and btn:GetNumPoints()) or 0
      local p1, relTo, relPoint, offX, offY = nil, nil, nil, nil, nil
      if btn.GetPoint and npts and npts > 0 then
        p1, relTo, relPoint, offX, offY = btn:GetPoint(1)
      end
      local relName = "nil"
      if type(relTo) == "table" and relTo.GetName then
        relName = relTo:GetName() or "(anon)"
      end
      print(string.format(
        "%s: %s/%s alpha=%.2f scale=%.3f strata=%s lvl=%d size=%dx%d center=%s,%s points=%d p1=%s rel=%s rp=%s off=%s,%s",
        name, shown, visible, a or 1, s or 1, tostring(strata), level or 0, w or 0, h or 0,
        (x and string.format("%.1f", x) or "nil"),
        (y and string.format("%.1f", y) or "nil"),
        npts or 0,
        tostring(p1), tostring(relName), tostring(relPoint), tostring(offX), tostring(offY)
      ))
    end
    CheckBtn("potionBtn", H.potionBtn)
    CheckBtn("manaBtn", H.manaBtn)
    CheckBtn("bandageBtn", H.bandageBtn)
    CheckBtn("hearthBtn", H.hearthBtn)
    CheckBtn("racialBtn", H.racialBtn)
  end

  -- Debug command to force utility buttons to the center of the screen.
  -- This helps distinguish "off-screen/bad anchor" from "not rendering".
  SLASH_HHFORCE1 = "/hhforce"
  SlashCmdList["HHFORCE"] = function()
    -- Debug override: keep mana button visible even if not a mana class,
    -- otherwise it may get hidden again by normal visibility logic.
    H._forceShowManaBtn = true
    if C_Timer and C_Timer.After then
      C_Timer.After(10, function() H._forceShowManaBtn = nil end)
    end

    local function Force(btn, dx)
      if not btn then return end
      pcall(function()
        if btn.SetClampedToScreen then btn:SetClampedToScreen(true) end
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", UIParent, "CENTER", dx or 0, -40)
        if btn.SetAlpha then btn:SetAlpha(1) end
        if btn.SetScale then btn:SetScale(1) end
        if btn.SetFrameStrata then btn:SetFrameStrata("HIGH") end
        if btn.SetFrameLevel then btn:SetFrameLevel(200) end
        btn:Show()
      end)
    end
    Force(H.bandageBtn, -64)
    Force(H.potionBtn, -32)
    Force(H.hearthBtn, 0)
    Force(H.racialBtn, 32)
    Force(H.manaBtn, 64)
    print("[HardcoreHUD] Forced utility buttons to center. Use /hhdbg to inspect.")
  end

  -- Debug command to check shield tracking state
  -- Usage: /hhshield - show debug info
  --        /hhshield test - force show shield border for visual testing
  --        /hhshield off - hide test shield border
  SLASH_HHSHIELD1 = "/hhshield"
  SlashCmdList["HHSHIELD"] = function(args)
    args = args and string.lower(args) or ""
    
    -- Test mode: force show the shield border
    if args == "test" then
      print("[HardcoreHUD] Shield Border TEST MODE")
      
      -- Ensure shieldBorder is built
      if not H.shieldBorder then
        if H.BuildShieldBorder then
          H.BuildShieldBorder()
        end
      end
      
      if not H.shieldBorder then
        print("  ERROR: shieldBorder frame could not be created")
        print("  bars.hp exists:", H.bars and H.bars.hp and "YES" or "NO")
        return
      end
      
      -- Force activate shield state
      H.shieldState = H.shieldState or {}
      H.shieldState.active = true
      H.shieldState.maxAbsorb = 1000
      H.shieldState.currentAbsorb = 750  -- 75% shield
      H.shieldState.spellId = 10901
      
      -- Force update
      if H.UpdateShieldBorder then
        H.UpdateShieldBorder()
      end
      
      print("  Shield border should now be visible (75% shield)")
      print("  Frame shown:", H.shieldBorder:IsShown() and "YES" or "NO")
      if H.shieldBorder.left then print("  left shown:", H.shieldBorder.left:IsShown() and "YES" or "NO") end
      if H.shieldBorder.right then print("  right shown:", H.shieldBorder.right:IsShown() and "YES" or "NO") end
      if H.shieldBorder.bottom then print("  bottom shown:", H.shieldBorder.bottom:IsShown() and "YES" or "NO") end
      if H.shieldBorder.glow then print("  glow shown:", H.shieldBorder.glow:IsShown() and "YES" or "NO") end
      if H.shieldBorder.text then print("  text shown:", H.shieldBorder.text:IsShown() and "YES" or "NO") end
      return
    end
    
    -- Off mode: hide test shield border
    if args == "off" then
      print("[HardcoreHUD] Shield Border TEST MODE OFF")
      H.shieldState = H.shieldState or {}
      H.shieldState.active = false
      H.shieldState.currentAbsorb = 0
      H.shieldState.maxAbsorb = 0
      if H.UpdateShieldBorder then
        H.UpdateShieldBorder()
      end
      return
    end
    
    -- Default: show debug info
    print("[HardcoreHUD] Shield Tracking Debug:")
    print("  Use '/hhshield test' to force show the border")
    print("  Use '/hhshield off' to hide the test border")
    
    -- Check if shieldState exists
    if not H.shieldState then
      print("  shieldState: NIL (not initialized)")
    else
      print(string.format("  active: %s", tostring(H.shieldState.active)))
      print(string.format("  currentAbsorb: %s", tostring(H.shieldState.currentAbsorb)))
      print(string.format("  maxAbsorb: %s", tostring(H.shieldState.maxAbsorb)))
      print(string.format("  spellId: %s", tostring(H.shieldState.spellId)))
    end
    
    -- Check if shieldBorder frame exists
    if not H.shieldBorder then
      print("  shieldBorder frame: NIL")
    else
      print(string.format("  shieldBorder frame: %s", H.shieldBorder:IsShown() and "SHOWN" or "HIDDEN"))
      if H.shieldBorder.left then print(string.format("    left: %s", H.shieldBorder.left:IsShown() and "SHOWN" or "HIDDEN")) end
      if H.shieldBorder.right then print(string.format("    right: %s", H.shieldBorder.right:IsShown() and "SHOWN" or "HIDDEN")) end
      if H.shieldBorder.bottom then print(string.format("    bottom: %s", H.shieldBorder.bottom:IsShown() and "SHOWN" or "HIDDEN")) end
      if H.shieldBorder.glow then print(string.format("    glow: %s", H.shieldBorder.glow:IsShown() and "SHOWN" or "HIDDEN")) end
      if H.shieldBorder.text then print(string.format("    text: %s", H.shieldBorder.text:IsShown() and "SHOWN" or "HIDDEN")) end
    end
    
    -- Check bars.hp
    print(string.format("  bars.hp: %s", H.bars and H.bars.hp and "EXISTS" or "NIL"))
    
    -- List all current buffs to help find the PW:S buff name
    print("  Current buffs:")
    for i = 1, 40 do
      local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitBuff("player", i)
      if not name then break end
      print(string.format("    [%d] '%s' (caster=%s)", i, name, tostring(unitCaster)))
    end
    
    -- Manual check for shield
    if H.CheckShieldState then
      print("  Running CheckShieldState()...")
      H.CheckShieldState()
      print(string.format("  After check - active: %s", tostring(H.shieldState and H.shieldState.active)))
    end
  end

  -- Test/Debug Range Display directly
  SLASH_HHSHOWRANGE1 = "/hhshowrange"
  SlashCmdList["HHSHOWRANGE"] = function(args)
    if args and string.lower(args) == "off" then
      H._debugRangeDisplay = false
      print("[HardcoreHUD] Debug mode OFF")
      return
    end
    
    if H.rangeDisplay then
      print("[HardcoreHUD] Range Display Debug Mode ON")
      print("Current settings:")
      print("  warnings:", HardcoreHUDDB.warnings and "exists" or "nil")
      print("  warnings.enabled:", HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled or "nil")
      print("  rangeDisplay:", HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.rangeDisplay and "exists" or "nil")
      print("  rangeDisplay.enabled:", HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.rangeDisplay and HardcoreHUDDB.warnings.rangeDisplay.enabled or "nil")
      
      -- Enable it
      HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
      HardcoreHUDDB.warnings.enabled = true
      HardcoreHUDDB.warnings.rangeDisplay = HardcoreHUDDB.warnings.rangeDisplay or {}
      HardcoreHUDDB.warnings.rangeDisplay.enabled = true
      
      print("After enabling:")
      print("  warnings.enabled:", HardcoreHUDDB.warnings.enabled)
      print("  rangeDisplay.enabled:", HardcoreHUDDB.warnings.rangeDisplay.enabled)
      
      -- Set debug flag to prevent hiding
      H._debugRangeDisplay = true
      
      -- Force show it
      H.rangeDisplay:ClearAllPoints()
      H.rangeDisplay:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
      H.rangeDisplay:SetAlpha(1)
      H.rangeDisplay:SetScale(1)
      if H.rangeDisplay.SetFrameStrata then
        H.rangeDisplay:SetFrameStrata("HIGH")
      end
      if H.rangeDisplay.SetFrameLevel then
        H.rangeDisplay:SetFrameLevel(500)
      end
      H.rangeDisplay:Show()
      
      print("Use '/hhshowrange off' to disable debug mode")
    else
      print("[HardcoreHUD] Range Display frame not found!")
    end
  end

  -- Set Range Display Font Size
  SLASH_HHRANGEFONT1 = "/hhrangefont"
  SlashCmdList["HHRANGEFONT"] = function(args)
    local size = tonumber(args)
    if not size or size < 8 or size > 48 then
      print("[HardcoreHUD] Usage: /hhrangefont <8-48>")
      print("[HardcoreHUD] Current size:", HardcoreHUDDB.warnings.rangeDisplay.fontSize or 24)
      return
    end
    
    HardcoreHUDDB.warnings.rangeDisplay.fontSize = size
    if H.rangeDisplay and H.rangeDisplay.text then
      local fontPath = STANDARD_TEXT_FONT or GameFontNormal:GetFont()
      H.rangeDisplay.text:SetFont(fontPath, size, "OUTLINE")
      print("[HardcoreHUD] Range Display font size set to", size)
    end
  end

  -- Test/Debug Leash and Range Displays
  SLASH_HHTESTLEASH1 = "/hhtestleash"
  SlashCmdList["HHTESTLEASH"] = function()
    HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
    HardcoreHUDDB.warnings.leash = HardcoreHUDDB.warnings.leash or {}
    HardcoreHUDDB.warnings.rangeDisplay = HardcoreHUDDB.warnings.rangeDisplay or {}
    
    -- Enable both
    HardcoreHUDDB.warnings.enabled = true
    HardcoreHUDDB.warnings.leash.enabled = true
    HardcoreHUDDB.warnings.rangeDisplay.enabled = true
    
    print("[HardcoreHUD] Leash and Range Display enabled.")
    print("Leash config:", HardcoreHUDDB.warnings.leash.enabled)
    print("Range config:", HardcoreHUDDB.warnings.rangeDisplay.enabled)
    
    -- Debug: Check if frames exist
    print("Leash frame exists:", H.leashWarn and "YES" or "NO")
    print("Range frame exists:", H.rangeDisplay and "YES" or "NO")
    
    -- Try to show them if a target exists
    if H.CheckLeashDistance then H.CheckLeashDistance() end
    if H.CheckRangeDisplay then H.CheckRangeDisplay() end
    
    -- Additional debug output
    if H.rangeDisplay then
      print("Range frame visible:", H.rangeDisplay:IsShown() and "YES" or "NO")
      print("Range frame position:", H.rangeDisplay:GetPoint())
      print("Range frame size:", H.rangeDisplay:GetSize())
    end
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
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.ticker then
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
  
  -- List of secure button keys that cannot be shown/hidden during combat
  local secureButtonKeys = {
    potionBtn = true,
    manaBtn = true,
    bandageBtn = true,
    hearthBtn = true,
    racialBtn = true,
  }
  
  -- Check if a frame is a secure button that we manage
  local function isSecureButton(frame)
    if not frame or not H then return false end
    for key, _ in pairs(secureButtonKeys) do
      if H[key] and H[key] == frame then return true end
    end
    -- Also check class CD buttons
    if H.classCDButtons then
      for _, btn in ipairs(H.classCDButtons) do
        if btn == frame then return true end
      end
    end
    return false
  end
  
  local function applyProps(frame, shown)
    if not frame then return end
    
    -- Skip secure buttons during combat to avoid taint
    if InCombatLockdown() and isSecureButton(frame) then
      return
    end
    
    if shown then
      -- Special case: don't show bandage button if First Aid is not learned
      if frame == H.bandageBtn and H.bandageBtn._hasFirstAid == false then
        if not InCombatLockdown() then frame:Hide() end
        return
      end
      
      -- Always restore to full visibility with hardcoded good values
      -- Never rely on cached values as they can get corrupted
      if frame.SetAlpha then frame:SetAlpha(1) end
      if frame.SetScale then frame:SetScale(1) end
      if frame.SetFrameStrata then frame:SetFrameStrata("MEDIUM") end
      if frame.SetFrameLevel then frame:SetFrameLevel(100) end
      if frame.EnableMouse then frame:EnableMouse(true) end
      frame:Show()
      -- Clear any cached props
      prevProps[frame] = nil
    else
      -- Only hide HUD bars, not utility buttons - they should always remain visible
      if isSecureButton(frame) then
        -- Don't hide secure utility buttons at all - just skip them
        return
      end
      -- For non-secure frames (bars etc), just hide
      if frame.EnableMouse then frame:EnableMouse(false) end
      frame:Hide()
    end
  end

  local function SetHUDShown(shown)
    if not H.bars then return end
    local elems = {
      H.bars.hp, H.bars.pow, H.bars.targetHP, H.bars.targetPow,
      H.bars.combo,
      H.potionBtn, H.manaBtn, H.hearthBtn, H.bandageBtn, H.racialBtn, H.utilRow,
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
    "AtlasLootDefaultFrame",
    "AtlasLoot_GUI-Frame",
    "AtlasLootFrame",
    "AtlasLootPanels",
    "AtlasLootItemsFrame",
    "AtlasLoot_GUIMenu",
    -- NOTE: Removed many frames that briefly open during normal gameplay
    -- Only fullscreen/major UI windows should hide the HUD
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
  -- Do not auto-hide HUD when our own options window is opened; this allows
  -- users to see and reposition bars while adjusting settings.
  -- Instead, when the options frame is shown, make sure it is on top and
  -- temporarily disable HUD mouse handling so options remain fully interactive.
  if HardcoreHUDOptions and not HardcoreHUDOptions._HardcoreHUDHooked then
    HardcoreHUDOptions:HookScript("OnShow", function(self)
      -- Force options window to top and accept input
      if self.SetParent then pcall(self.SetParent, self, UIParent) end
      if self.SetFrameStrata then pcall(self.SetFrameStrata, self, "TOOLTIP") end
      if self.SetFrameLevel then pcall(self.SetFrameLevel, self, 32767) end
      if self.SetClampedToScreen then pcall(self.SetClampedToScreen, self, true) end
      if self.EnableMouse then pcall(self.EnableMouse, self, true) end
      if self.SetMovable then pcall(self.SetMovable, self, true) end
      -- Don't hide HUD or utility buttons - just make them non-interactive
      -- Skip during combat to avoid protected action errors
      if H and not InCombatLockdown() then
        local keys = { "potionBtn", "manaBtn", "bandageBtn", "hearthBtn", "racialBtn" }
        for _, k in ipairs(keys) do
          local f = H[k]
          if f and f.EnableMouse then
            pcall(function() f:EnableMouse(false) end)
          end
        end
      end
    end)
    HardcoreHUDOptions:HookScript("OnHide", function(self)
      -- Restore utility button mouse interaction
      -- Skip during combat to avoid protected action errors
      if H and not InCombatLockdown() then
        local keys = { "potionBtn", "manaBtn", "bandageBtn", "hearthBtn", "racialBtn" }
        for _, k in ipairs(keys) do
          local f = H[k]
          if f and f.EnableMouse then
            pcall(function() f:EnableMouse(true) end)
          end
        end
      end
      -- Restore HUD mouse behavior according to lock setting
      if H and H.SetHUDMouseEnabled then
        local locked = HardcoreHUDDB and HardcoreHUDDB.lock
        pcall(H.SetHUDMouseEnabled, locked and true or false)
      end
    end)
    HardcoreHUDOptions._HardcoreHUDHooked = true
  end
  -- In case Bars.lua created cdIcons separately, hide their buttons too
  function H._ApplyMapVisibilityToCDIcons(shown)
    -- Skip during combat - cdIcons may be secure
    if InCombatLockdown() then return end
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
  H.SafeBackdrop(simple, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} }, 0,0,0,0.88)
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
      local link = GetSpellLink and GetSpellLink(spellID) or nil
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
        if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.tooltips then
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
    if HardcoreHUDDB and type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.tooltips then
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
      if type(name) == "string" and string.upper(name) == "BREATH" and maxvalue and maxvalue > 0 then
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
      -- Normalize name (guard non-string values)
      local nm = (type(name) == "string") and string.upper(name) or nil
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

-- Thanks for Buff System - DISABLED
-- This feature has been disabled because DoEmote/SendChatMessage cause taint
-- and protected function errors in Classic Era. The WoW API does not allow
-- addons to send chat messages or emotes automatically without causing issues.
function H.InitThanksBuff()
  -- Feature disabled - do nothing
  -- The emote/chat APIs are protected and cause ADDON_ACTION_BLOCKED errors
  HardcoreHUDDB.thanksBuff = HardcoreHUDDB.thanksBuff or { enabled = false }
  HardcoreHUDDB.thanksBuff.enabled = false  -- Force disabled
end

-- ================= Auto-Logout on Inactivity (AFK Protection) ===================
-- Automatically logs out after X seconds of no activity to protect hardcore characters
do
  -- NOTE: HardcoreHUDDB.autoLogout is initialized later after ADDON_LOADED
  -- to respect SavedVariables. See the PLAYER_LOGIN event handler below.
  
  H._afkState = H._afkState or {
    lastActivity = GetTime(),
    warningShown = false,
    logoutPending = false,
  }
  
  -- Warning overlay frame
  local function BuildAFKWarningFrame()
    if H.afkWarningFrame then return end
    
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(400, 100)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(500)
    f:Hide()
    
    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0.1, 0, 0, 0.9)
    
    -- Red border (pulsing)
    local borderSize = 3
    local borders = {}
    borders[1] = f:CreateTexture(nil, "BORDER"); borders[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); borders[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); borders[1]:SetHeight(borderSize); borders[1]:SetColorTexture(1, 0.2, 0.2, 1)
    borders[2] = f:CreateTexture(nil, "BORDER"); borders[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); borders[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); borders[2]:SetHeight(borderSize); borders[2]:SetColorTexture(1, 0.2, 0.2, 1)
    borders[3] = f:CreateTexture(nil, "BORDER"); borders[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); borders[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); borders[3]:SetWidth(borderSize); borders[3]:SetColorTexture(1, 0.2, 0.2, 1)
    borders[4] = f:CreateTexture(nil, "BORDER"); borders[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); borders[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); borders[4]:SetWidth(borderSize); borders[4]:SetColorTexture(1, 0.2, 0.2, 1)
    f.borders = borders
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("⚠ AFK AUTO-LOGOUT ⚠")
    title:SetTextColor(1, 0.3, 0.3, 1)
    if STANDARD_TEXT_FONT then title:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE") end
    f.title = title
    
    -- Countdown text
    local countdown = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countdown:SetPoint("CENTER", f, "CENTER", 0, 0)
    countdown:SetText("Logout in 10s...")
    countdown:SetTextColor(1, 1, 1, 1)
    if STANDARD_TEXT_FONT then countdown:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE") end
    f.countdown = countdown
    
    -- Info text
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    info:SetText("Move or press any key to cancel")
    info:SetTextColor(0.7, 0.7, 0.7, 1)
    f.info = info
    
    -- Pulse animation
    f._pulseAcc = 0
    f:SetScript("OnUpdate", function(self, dt)
      if not self:IsShown() then return end
      self._pulseAcc = (self._pulseAcc or 0) + dt
      local pulse = 0.6 + 0.4 * math.sin(self._pulseAcc * 6)
      for _, b in ipairs(self.borders) do
        b:SetAlpha(pulse)
      end
    end)
    
    H.afkWarningFrame = f
  end
  
  -- Reset activity timer
  function H.ResetAFKTimer()
    H._afkState.lastActivity = GetTime()
    H._afkState.warningShown = false
    H._afkState.logoutPending = false
    if H.afkWarningFrame then
      H.afkWarningFrame:Hide()
    end
  end
  
  -- Activity detection events
  local activityFrame = CreateFrame("Frame")
  activityFrame:RegisterEvent("PLAYER_STARTED_MOVING")
  activityFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
  activityFrame:RegisterEvent("UNIT_SPELLCAST_START")
  activityFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  activityFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  activityFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  activityFrame:RegisterEvent("LOOT_OPENED")
  activityFrame:RegisterEvent("MERCHANT_SHOW")
  activityFrame:RegisterEvent("BANKFRAME_OPENED")
  activityFrame:RegisterEvent("MAIL_SHOW")
  activityFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
  activityFrame:RegisterEvent("TRADE_SHOW")
  activityFrame:RegisterEvent("QUEST_DETAIL")
  activityFrame:RegisterEvent("GOSSIP_SHOW")
  -- Combat events intentionally NOT registered - AFK logout runs even in combat for hardcore safety
  activityFrame:RegisterEvent("CHAT_MSG_SAY")
  activityFrame:RegisterEvent("CHAT_MSG_YELL")
  activityFrame:RegisterEvent("CHAT_MSG_PARTY")
  activityFrame:RegisterEvent("CHAT_MSG_GUILD")
  activityFrame:RegisterEvent("CHAT_MSG_WHISPER")
  activityFrame:RegisterEvent("PLAYER_LOGIN")
  activityFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  
  activityFrame:SetScript("OnEvent", function(self, event, unit, ...)
    -- Initialize autoLogout settings on login (after SavedVariables load)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
      HardcoreHUDDB.autoLogout = HardcoreHUDDB.autoLogout or {}
      if HardcoreHUDDB.autoLogout.enabled == nil then HardcoreHUDDB.autoLogout.enabled = false end  -- Default OFF for safety
      if HardcoreHUDDB.autoLogout.timeout == nil then HardcoreHUDDB.autoLogout.timeout = 30 end
      if HardcoreHUDDB.autoLogout.warningTime == nil then HardcoreHUDDB.autoLogout.warningTime = 10 end
      -- Reset activity timer on login
      H._afkState.lastActivity = GetTime()
      if HardcoreHUDDB.autoLogout.enabled then
        print("|cff00ff00[HardcoreHUD] AFK Auto-Logout active|r - " .. HardcoreHUDDB.autoLogout.timeout .. "s timeout")
      end
    end
    
    -- Filter unit events to player only
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_START" then
      if unit ~= "player" then return end
    end
    
    -- Reset on any activity
    H.ResetAFKTimer()
  end)
  
  -- Main AFK check loop
  local afkCheckFrame = CreateFrame("Frame")
  local checkAcc = 0
  afkCheckFrame:SetScript("OnUpdate", function(self, dt)
    checkAcc = checkAcc + dt
    if checkAcc < 0.5 then return end
    checkAcc = 0
    
    -- Ensure autoLogout table exists
    if not HardcoreHUDDB then return end
    local cfg = HardcoreHUDDB.autoLogout
    if not cfg or not cfg.enabled then
      -- Don't hide if we're in test mode
      if H._afkTestMode then return end
      if H.afkWarningFrame then H.afkWarningFrame:Hide() end
      return
    end
    
    -- Ensure lastActivity is set
    if not H._afkState or not H._afkState.lastActivity then
      H._afkState = H._afkState or {}
      H._afkState.lastActivity = GetTime()
      return
    end
    
    -- Don't trigger if dead/ghost
    if UnitIsDead("player") or UnitIsGhost("player") then
      H.ResetAFKTimer()
      return
    end
    
    local now = GetTime()
    local elapsed = now - (H._afkState.lastActivity or now)
    local timeout = cfg.timeout or 30
    local warningTime = cfg.warningTime or 10
    local remaining = timeout - elapsed
    
    -- Show warning
    if remaining <= warningTime and remaining > 0 then
      BuildAFKWarningFrame()
      if H.afkWarningFrame then
        H.afkWarningFrame:Show()
        H.afkWarningFrame.countdown:SetText(string.format("Logout in %.0fs...", remaining))
        H._afkState.warningShown = true
        
        -- Play warning sound once per second
        if not H._afkState.lastSoundTime or (now - H._afkState.lastSoundTime) >= 1 then
          H._afkState.lastSoundTime = now
          if PlaySoundFile then
            PlaySoundFile("Sound/Interface/RaidWarning.wav", "Master")
          end
        end
      end
    elseif remaining <= 0 and not H._afkState.logoutPending then
      -- Time's up - initiate logout
      H._afkState.logoutPending = true
      if H.afkWarningFrame then
        H.afkWarningFrame.countdown:SetText("Logging out NOW!")
      end
      print("|cffff0000[HardcoreHUD] AFK timeout - logging out!|r")
      -- Use Logout() function - starts 20 second logout timer
      if Logout then
        Logout()
      end
    end
  end)
  
  -- Slash command to toggle
  SLASH_HHAFK1 = "/hhafk"
  SlashCmdList["HHAFK"] = function(msg)
    local args = {}
    for t in string.gmatch(msg or "", "[^%s]+") do table.insert(args, t) end
    local cmd = string.lower(args[1] or "")
    
    if cmd == "on" then
      HardcoreHUDDB.autoLogout.enabled = true
      print("|cff00ff00[HardcoreHUD] AFK Auto-Logout ENABLED|r - " .. (HardcoreHUDDB.autoLogout.timeout or 30) .. "s timeout")
      H.ResetAFKTimer()
    elseif cmd == "off" then
      HardcoreHUDDB.autoLogout.enabled = false
      print("|cffff0000[HardcoreHUD] AFK Auto-Logout DISABLED|r")
      if H.afkWarningFrame then H.afkWarningFrame:Hide() end
    elseif cmd == "time" and tonumber(args[2]) then
      local t = tonumber(args[2])
      if t >= 10 and t <= 300 then
        HardcoreHUDDB.autoLogout.timeout = t
        print("[HardcoreHUD] AFK timeout set to " .. t .. " seconds")
      else
        print("[HardcoreHUD] Timeout must be between 10 and 300 seconds")
      end
    elseif cmd == "test" then
      -- Test the warning - set test mode flag to prevent auto-hide
      H._afkTestMode = true
      BuildAFKWarningFrame()
      if H.afkWarningFrame then
        H.afkWarningFrame:Show()
        H.afkWarningFrame.countdown:SetText("TEST - Logout in 5s...")
        print("[HardcoreHUD] Showing AFK warning (test mode - 5 seconds)")
        -- Play the warning sound
        if PlaySoundFile then
          PlaySoundFile("Sound/Interface/RaidWarning.wav", "Master")
        end
        C_Timer.After(5, function()
          H._afkTestMode = false
          if H.afkWarningFrame then H.afkWarningFrame:Hide() end
          print("[HardcoreHUD] Test complete")
        end)
      end
    else
      HardcoreHUDDB.autoLogout = HardcoreHUDDB.autoLogout or { enabled = true, timeout = 30, warningTime = 10 }
      local status = HardcoreHUDDB.autoLogout.enabled and "|cff00ff00ON|r" or "|cffff0000OFF|r"
      print("[HardcoreHUD] AFK Auto-Logout: " .. status)
      print("  /hhafk on - Enable auto-logout")
      print("  /hhafk off - Disable auto-logout")
      print("  /hhafk time <seconds> - Set timeout (10-300)")
      print("  /hhafk test - Test warning display")
      print("  Current timeout: " .. (HardcoreHUDDB.autoLogout.timeout or 30) .. "s")
    end
  end
end
