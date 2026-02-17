local addonName = ...
HardcoreHUD = HardcoreHUD or {}
local H = HardcoreHUD

-- IMPORTANT: SavedVariables are NOT loaded yet at this point!
-- They will be available after ADDON_LOADED fires for this addon.
-- We create an empty table here as fallback, but the real data comes later.
HardcoreHUDDB = HardcoreHUDDB or {}

-- ADDON_LOADED handler to properly restore saved positions
local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")
addonLoadedFrame:SetScript("OnEvent", function(self, event, loadedAddon)
  if loadedAddon ~= "HardcoreHud" then return end
  
  -- NOW SavedVariables are loaded - restore root frame position
  if H.root and HardcoreHUDDB.pos then
    H.root:ClearAllPoints()
    H.root:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x or 0, HardcoreHUDDB.pos.y or -150)
  end
  
  -- Ensure utilities table exists with saved values preserved
  HardcoreHUDDB.utilities = HardcoreHUDDB.utilities or {}
  
  self:UnregisterEvent("ADDON_LOADED")
end)

-- Target Cast Bar implementation
function H.InitTargetCastBar()
  H.cast = H.cast or {}
  if H.cast.targetBar then return end
  local root = H.root or UIParent
  -- Use a simple frame with a texture that we resize bottom->top,
  -- mirroring the existing 5-second overlay behavior exactly.
  local bar = CreateFrame("Frame", "HardcoreHUDTargetCastBar", root)
  bar:SetSize((H.bars and H.bars.hp and H.bars.hp:GetWidth()) or 300, 14)
  bar:SetAlpha(0.85)
  bar:Hide()
  -- Position: below target HP bar if present; else under root
  if H.bars and H.bars.targetHP then
    -- Overlay target HP bar like the 5s timer
    bar:ClearAllPoints()
    bar:SetAllPoints(H.bars.targetHP)
    if bar.SetFrameStrata then bar:SetFrameStrata("HIGH") end
    bar:SetFrameLevel((H.bars.targetHP:GetFrameLevel() or 0) + 5)
  else
    bar:SetPoint("CENTER", root, "CENTER", 0, -190)
  end
  -- Fill texture (bottom-to-top), additive blend, uses full bar height
  local fill = bar:CreateTexture(nil, "OVERLAY")
  fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  fill:SetBlendMode("ADD")
  fill:SetVertexColor(1.0, 0.75, 0.1, 0.9)
  fill:ClearAllPoints()
  fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  fill:SetHeight(0) -- start empty at bottom
  -- Spark
  local spark = bar:CreateTexture(nil, "OVERLAY")
  spark:SetSize(20, 30)
  spark:SetTexture("Interface/CastingBar/UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  -- Texts
  local spell = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  spell:SetPoint("LEFT", bar, "LEFT", 6, 0)
  spell:SetText("")
  local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  timeText:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
  timeText:SetText("")
  H.cast.targetBar = bar
  H.cast.fill = fill
  H.cast.spark = spark
  H.cast.spell = spell
  H.cast.timeText = timeText
  H.cast._timer = 0
  H.cast._endTime = 0
  H.cast._channel = false

  -- Interrupt tracker visuals: red pulsing overlay over the cast area
  local glow = bar:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints(bar)
  glow:SetColorTexture(1, 0.2, 0.2, 0) -- start hidden
  H.cast.interruptGlow = glow
  H.cast._intrPulse = { t = 0, speed = 3.0, minA = 0.15, maxA = 0.45, active = false }
  -- Update pulsing if active
  bar:HookScript("OnUpdate", function(_, elapsed)
    local p = H.cast and H.cast._intrPulse
    if p and p.active and H.cast and H.cast.interruptGlow then
      p.t = (p.t + elapsed * p.speed) % (2*math.pi)
      local a = p.minA + (p.maxA - p.minA) * (0.5 + 0.5 * math.sin(p.t))
      H.cast.interruptGlow:SetColorTexture(1, 0.2, 0.2, a)
    end
  end)

  -- Secure interrupt button (optional): attempts to cast your interrupt
  local btn
  if CreateFrame then
    btn = CreateFrame("Button", "HardcoreHUDInterruptButton", bar, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    btn:SetSize(22, 22)
    btn:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 10, 10)
    btn:RegisterForClicks("AnyUp")
    btn:SetAlpha(0) -- hidden by default; fade in when active
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface/Icons/Ability_Kick")
    btn.icon = icon
    H.cast.interruptButton = btn
    H.cast._btnPulse = { t = 0, speed = 6.0 }
    btn:SetScript("OnUpdate", function(self, elapsed)
      if not self:IsShown() then return end
      local s = H.cast and H.cast._btnPulse
      if not s then return end
      s.t = (s.t + elapsed * s.speed) % (2*math.pi)
      local a = 0.5 + 0.5 * math.abs(math.sin(s.t))
      self:SetAlpha(a)
    end)
  end
end

function H.UpdateTargetCastBarVisibility()
  if not H.cast or not H.cast.targetBar then return end
  if HardcoreHUDDB and HardcoreHUDDB.castbar and HardcoreHUDDB.castbar.enabled then
    -- no-op; visibility managed by events
  else
    pcall(H.cast.targetBar.Hide, H.cast.targetBar)
  end
end

local function setCastProgress(startMS, endMS, isChannel, notInterruptible)
  if not H.cast or not H.cast.targetBar then return end
  H.cast._channel = isChannel or false
  H.cast._startTime = startMS / 1000
  H.cast._endTime = endMS / 1000
  local duration = H.cast._endTime - H.cast._startTime
  -- Start empty; texture height grows from bottom
  if H.cast.fill then H.cast.fill:SetHeight(0) end
  pcall(H.cast.targetBar.Show, H.cast.targetBar)
  pcall(H.cast.targetBar.SetScript, H.cast.targetBar, "OnUpdate", function(self, elapsed)
    local now = GetTime()
    local dur = H.cast._endTime - H.cast._startTime
    -- Grow from bottom: progress is elapsed time since start
    local prog = (now - H.cast._startTime)
    if prog < 0 then prog = 0 end
    if prog > dur then prog = dur end
    local frac = (dur > 0) and (prog / dur) or 0
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    -- Adjust fill texture height to full parent height proportion
    if H.cast.fill then
      local fullH = (H.bars and H.bars.targetHP and H.bars.targetHP:GetHeight()) or self:GetHeight()
      H.cast.fill:SetHeight(frac * fullH)
    end
    H.cast.timeText:SetText(string.format("%.1fs", math.max(0, (H.cast._endTime - now))))
    -- Spark position (bottom to top)
    local h = self:GetHeight()
    local y = frac * h
    H.cast.spark:ClearAllPoints()
    H.cast.spark:SetPoint("CENTER", self, "BOTTOM", 0, y)
    if now >= H.cast._endTime then
      -- Snap to full before hiding so it visually reaches the top
      if H.cast.fill then
        local fullH = (H.bars and H.bars.targetHP and H.bars.targetHP:GetHeight()) or self:GetHeight()
        H.cast.fill:SetHeight(fullH)
      end
      H.cast.spark:ClearAllPoints()
      H.cast.spark:SetPoint("CENTER", self, "TOP", 0, 0)
      pcall(self.SetScript, self, "OnUpdate", nil)
      pcall(self.Hide, self)
      -- stop interrupt highlight
      if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
      if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
      if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
    end
  end)
  -- Evaluate interrupt state for this cast
  if H.EvaluateInterruptState then H.EvaluateInterruptState(notInterruptible) end
end

function H.HandleTargetCastEvent(event, unit)
  if unit ~= "target" then return end
  if not HardcoreHUDDB or not HardcoreHUDDB.castbar or not HardcoreHUDDB.castbar.enabled then return end
  if not H.cast or not H.cast.targetBar then H.InitTargetCastBar() end
  if event == "UNIT_SPELLCAST_START" then
    -- Classic Era: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible
    local name, _, _, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo("target")
    if name and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
      H.cast.spell:SetText(name)
      H.cast._spellName = name
      setCastProgress(startTimeMS, endTimeMS, false, notInterruptible)
    end
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
    if H.cast and H.cast.targetBar then pcall(H.cast.targetBar.SetScript, H.cast.targetBar, "OnUpdate", nil); pcall(H.cast.targetBar.Hide, H.cast.targetBar) end
    if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
    if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
    if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
    -- Audio cues: cast finished / interrupted
    if HardcoreHUDDB.audio and HardcoreHUDDB.audio.enabled then
      if event == "UNIT_SPELLCAST_STOP" and HardcoreHUDDB.audio.castFinish then
        if PlaySoundFile then PlaySoundFile("Sound/Interface/MapPing.wav") end
      elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") and HardcoreHUDDB.audio.castInterrupted then
        if PlaySoundFile then PlaySoundFile("Sound/Interface/Ignored_Alert.wav") end
      end
    end
  elseif event == "UNIT_SPELLCAST_DELAYED" then
    local name, _, _, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo("target")
    if name and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
      H.cast.spell:SetText(name)
      H.cast._spellName = name
      setCastProgress(startTimeMS, endTimeMS, false, notInterruptible)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    local name, _, _, startTimeMS, endTimeMS, _, _, notInterruptible = UnitChannelInfo("target")
    if name and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
      H.cast.spell:SetText(name)
      H.cast._spellName = name
      setCastProgress(startTimeMS, endTimeMS, true, notInterruptible)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
    local name, _, _, startTimeMS, endTimeMS, _, _, notInterruptible = UnitChannelInfo("target")
    if name and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
      H.cast.spell:SetText(name)
      H.cast._spellName = name
      setCastProgress(startTimeMS, endTimeMS, true, notInterruptible)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if H.cast and H.cast.targetBar then pcall(H.cast.targetBar.SetScript, H.cast.targetBar, "OnUpdate", nil); pcall(H.cast.targetBar.Hide, H.cast.targetBar) end
    if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
    if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
    if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
  end
end

-- Event frame for target cast bar
do
  if not H._castEvents then
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_TARGET_CHANGED")
    ef:RegisterEvent("UNIT_SPELLCAST_START")
    ef:RegisterEvent("UNIT_SPELLCAST_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ef:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ef:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    ef:SetScript("OnEvent", function(_, event, unit)
      if event == "PLAYER_TARGET_CHANGED" then
        -- Refresh state when target changes
        if HardcoreHUDDB and HardcoreHUDDB.castbar and HardcoreHUDDB.castbar.enabled then
          local name, _, _, sMS, eMS, _, _, notInterruptible = UnitCastingInfo("target")
          if not name then name, _, _, sMS, eMS, _, _, notInterruptible = UnitChannelInfo("target") end
          if name and sMS and eMS and type(sMS) == "number" and type(eMS) == "number" then
            if not H.cast or not H.cast.targetBar then H.InitTargetCastBar() end
            H.cast.spell:SetText(name)
            H.cast._spellName = name
            setCastProgress(sMS, eMS, UnitChannelInfo("target") ~= nil, notInterruptible)
          else
            if H.cast and H.cast.targetBar then pcall(H.cast.targetBar.SetScript, H.cast.targetBar, "OnUpdate", nil); pcall(H.cast.targetBar.Hide, H.cast.targetBar) end
            if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
            if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
            if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
          end
        else
          if H.cast and H.cast.targetBar then pcall(H.cast.targetBar.Hide, H.cast.targetBar) end
          if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
          if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
          if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
        end
      else
        H.HandleTargetCastEvent(event, unit)
      end
    end)
    H._castEvents = ef
  end
end

-- Interrupt capability detection and tracker
HardcoreHUDDB.trackers = HardcoreHUDDB.trackers or { interruptEnabled = true, interruptSound = true, showInterruptButton = true, dispelEnabled = true, dispelSound = false }

local function SpellKnown(spellId)
  if IsSpellKnown then return IsSpellKnown(spellId) end
  if IsPlayerSpell then return IsPlayerSpell(spellId) end
  return true -- best-effort fallback
end

local InterruptCandidates = {
  ROGUE   = { {id=1766,  icon="Interface/Icons/Ability_Kick",                 name=(GetSpellInfo and GetSpellInfo(1766)) or "Kick" } },
  WARRIOR = { {id=6552,  icon="Interface/Icons/INV_Gauntlets_04",             name=(GetSpellInfo and GetSpellInfo(6552)) or "Pummel" } },
  MAGE    = { {id=2139,  icon="Interface/Icons/Spell_Frost_IceShock",         name=(GetSpellInfo and GetSpellInfo(2139)) or "Counterspell" } },
  SHAMAN  = { {id=57994, icon="Interface/Icons/Spell_Nature_Cyclone",         name=(GetSpellInfo and GetSpellInfo(57994)) or "Wind Shear" },
              {id=8042,  icon="Interface/Icons/Spell_Nature_EarthShock",      name=(GetSpellInfo and GetSpellInfo(8042)) or "Earth Shock" } },
  PALADIN = { {id=853,   icon="Interface/Icons/Spell_Holy_SealOfMight",       name=(GetSpellInfo and GetSpellInfo(853)) or "Hammer of Justice" } },
  PRIEST  = { {id=15487, icon="Interface/Icons/Spell_Shadow_ImpPhaseShift",   name=(GetSpellInfo and GetSpellInfo(15487)) or "Silence" } },
  WARLOCK = { {id=19647, icon="Interface/Icons/Spell_Shadow_MindRot",         name=(GetSpellInfo and GetSpellInfo(19647)) or "Spell Lock" } },
  DRUID   = { {id=16979, icon="Interface/Icons/Ability_Hunter_Pet_Bear",      name=(GetSpellInfo and GetSpellInfo(16979)) or "Feral Charge" } },
  HUNTER  = { },
}

local function ChooseInterrupt()
  local _, class = UnitClass("player")
  local list = InterruptCandidates[class or ""] or {}
  for _, sp in ipairs(list) do
    if SpellKnown(sp.id) then return sp end
  end
  return list[1] -- fallback, may not be known
end

function H.InitInterruptTracker()
  H.cast = H.cast or {}
  if not H.cast.targetBar then H.InitTargetCastBar() end
  H.cast._lastInterruptToken = nil
  -- Configure interrupt button spell/icon
  local sp = ChooseInterrupt()
    if H.cast.interruptButton and sp then
    H.cast.interruptButton.icon:SetTexture(sp.icon)
    H.QueueSetAttribute(H.cast.interruptButton, "type", "spell")
    H.QueueSetAttribute(H.cast.interruptButton, "spell", sp.name or sp.id)
  end
end

local function SpellReady(spellId)
  if not GetSpellCooldown then return true end
  local start, duration, enabled = GetSpellCooldown(spellId)
  if not start or start == 0 then return true end
  return (start + duration - GetTime()) <= 0
end

function H.EvaluateInterruptState(notInterruptible)
  if not HardcoreHUDDB.trackers or not HardcoreHUDDB.trackers.interruptEnabled then
    if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
    if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
    if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
    return
  end
  local active = true
  if notInterruptible == true then active = false end
  if not UnitExists("target") or not H.cast or not H.cast.targetBar:IsShown() then active = false end
  if active then
    if H.cast._intrPulse then H.cast._intrPulse.active = true end
    -- Play sound once per cast token
    if HardcoreHUDDB.trackers.interruptSound then
      local token = (H.cast._spellName or "?") .. tostring(H.cast._endTime or 0)
      if token ~= H.cast._lastInterruptToken then
        H.cast._lastInterruptToken = token
        if PlaySoundFile then PlaySoundFile("Sound/Interface/RaidWarning.wav") end
      end
    end
    -- Show button if configured and ready
    if H.cast.interruptButton and (HardcoreHUDDB.trackers.showInterruptButton ~= false) then
      local sp = ChooseInterrupt()
      if sp then
      H.cast.interruptButton.icon:SetTexture(sp.icon)
      H.QueueSetAttribute(H.cast.interruptButton, "spell", sp.name or sp.id)
        -- only show if spell is likely known/ready
        if SpellKnown(sp.id) and SpellReady(sp.id) then
          pcall(function() H.cast.interruptButton:Show() end)
        else
          pcall(function() H.cast.interruptButton:Hide() end)
        end
      else
        pcall(function() H.cast.interruptButton:Hide() end)
      end
    end
  else
    if H.cast and H.cast.interruptGlow then H.cast.interruptGlow:SetColorTexture(1,0.2,0.2,0) end
    if H.cast and H.cast._intrPulse then H.cast._intrPulse.active = false end
    if H.cast and H.cast.interruptButton then pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
  end
end

-- Dispel highlight on player when a dispellable debuff is present
local DispelByClass = {
  PALADIN = { Magic=true, Poison=true, Disease=true },
  PRIEST  = { Magic=true, Disease=true },
  SHAMAN  = { Poison=true, Disease=true },
  DRUID   = { Curse=true, Poison=true },
  MAGE    = { Curse=true },
  WARLOCK = { Magic=true }, -- via pet; best-effort
}

function H.InitDispelHighlight()
  H.dispel = H.dispel or {}
  if H.dispel.frame then return end
  local anchor = (H.bars and H.bars.hp) or H.root or UIParent
  local f = CreateFrame("Frame", nil, anchor)
  f:SetAllPoints(anchor)
  f:SetFrameStrata("FULLSCREEN")
  f:SetFrameLevel((anchor:GetFrameLevel() or 0) + 50)
  local tex = f:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(f)
  tex:SetColorTexture(0.1, 1.0, 0.6, 0) -- teal/green
  f.tex = tex
  f:Hide()
  H.dispel.frame = f
  H.dispel._pulse = { t=0, speed=2.5, minA=0.12, maxA=0.40, active=false }
  f:SetScript("OnUpdate", function(self, elapsed)
    local p = H.dispel._pulse
    if p and p.active then
      p.t = (p.t + elapsed * p.speed) % (2*math.pi)
      local a = p.minA + (p.maxA - p.minA) * (0.5 + 0.5 * math.sin(p.t))
      self.tex:SetColorTexture(0.1, 1.0, 0.6, a)
    end
  end)

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UNIT_AURA")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function(_, evt, unit)
    if evt == "UNIT_AURA" and unit ~= "player" then return end
    H.UpdateDispelHighlight()
  end)
  H.dispel.ev = ev
end

local function PlayerCanDispelType(dt)
  local _, class = UnitClass("player")
  local map = DispelByClass[class or ""]
  return map and map[dt] or false
end

function H.UpdateDispelHighlight()
  if not HardcoreHUDDB.trackers or not HardcoreHUDDB.trackers.dispelEnabled then
    if H.dispel and H.dispel.frame then H.dispel.frame:Hide() end
    if H.dispel and H.dispel._pulse then H.dispel._pulse.active = false end
    return
  end
  local found = false
  for i=1, 40 do
    local name, _, _, _, debuffType = UnitDebuff("player", i)
    if not name then break end
    if debuffType and PlayerCanDispelType(debuffType) then
      found = true
      break
    end
  end
  if found then
    if not H.dispel or not H.dispel.frame then H.InitDispelHighlight() end
    if H.dispel then
      H.dispel._pulse.active = true
      pcall(function() H.dispel.frame:Show() end)
      if HardcoreHUDDB.trackers.dispelSound and not H.dispel._played then
        H.dispel._played = true
        if PlaySoundFile then PlaySoundFile("Sound/Interface/AlarmClockWarning3.wav") end
      end
    end
  else
    if H.dispel then
      H.dispel._pulse.active = false
      if H.dispel.frame then pcall(function() H.dispel.frame:Hide() end) end
      H.dispel._played = false
    end
  end
end

-- Audio defaults expansion
HardcoreHUDDB.audio = HardcoreHUDDB.audio or { enabled = true }
if HardcoreHUDDB.audio.critHP == nil then HardcoreHUDDB.audio.critHP = true end
if HardcoreHUDDB.audio.breath == nil then HardcoreHUDDB.audio.breath = true end
if HardcoreHUDDB.audio.castFinish == nil then HardcoreHUDDB.audio.castFinish = true end
if HardcoreHUDDB.audio.castInterrupted == nil then HardcoreHUDDB.audio.castInterrupted = true end
if HardcoreHUDDB.audio.oom == nil then HardcoreHUDDB.audio.oom = true end

-- Drowning (breath) warning: blue pulsing fullscreen overlay
HardcoreHUDDB.breath = HardcoreHUDDB.breath or { enabled = true }

function H.InitBreathWarning()
  if H.breathOverlay then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN")
  f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 200)
  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(f)
  tex:SetColorTexture(0.2, 0.5, 1.0, 0) -- start transparent; blue
  f.tex = tex
  f:Hide()
  H.breathOverlay = f

  -- driver for pulsing alpha when active
  f._pulse = { t = 0, speed = 2.0, minA = 0.15, maxA = 0.45 }
  f:SetScript("OnUpdate", function(self, elapsed)
    local p = self._pulse; p.t = (p.t + elapsed * p.speed) % (2*math.pi)
    local a = p.minA + (p.maxA - p.minA) * (0.5 + 0.5 * math.sin(p.t))
    self.tex:SetColorTexture(0.2, 0.5, 1.0, a)
  end)

  -- event frame to track mirror timers (BREATH)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("MIRROR_TIMER_START")
  ev:RegisterEvent("MIRROR_TIMER_STOP")
  ev:RegisterEvent("MIRROR_TIMER_PAUSE")
  ev:SetScript("OnEvent", function(_, evt)
    if evt == "MIRROR_TIMER_START" or evt == "MIRROR_TIMER_PAUSE" then
      H.UpdateBreathWarning()
    elseif evt == "MIRROR_TIMER_STOP" then
      H.HideBreathWarning()
    end
  end)
  H.breathEventFrame = ev

  -- lightweight poller to catch threshold crossings without relying on events
  if not H._breathPoll then
    local poll = CreateFrame("Frame")
    poll._acc = 0
    poll:SetScript("OnUpdate", function(self, elapsed)
      self._acc = self._acc + elapsed
      if self._acc >= 0.2 then
        self._acc = 0
        H.UpdateBreathWarning()
      end
    end)
    H._breathPoll = poll
  end
end

function H.HideBreathWarning()
  if H.breathOverlay then H.breathOverlay:Hide() end
end

function H.UpdateBreathWarning()
  if not HardcoreHUDDB.breath or not HardcoreHUDDB.breath.enabled then
    H.HideBreathWarning(); return
  end
  -- Scan a fixed, safe range of mirror timers (usually 3)
  local found = false
  local remaining, total
  for idx = 1, 3 do
    local name, _, value, maxValue, scale, paused = GetMirrorTimerInfo(idx)
    if name and name == "BREATH" then
      -- Some clients report ms; treat consistently as seconds fraction
      remaining = value
      total = maxValue
      found = true
      break
    end
  end
  if not found or not total or total <= 0 then H.HideBreathWarning(); return end
  -- Normalize to seconds if values look like milliseconds
  local remainingSec = remaining
  local totalSec = total
  if totalSec > 1000 then
    remainingSec = remainingSec / 1000
    totalSec = totalSec / 1000
  end
  -- Trigger when remaining time is at or below 20 seconds (explicit request)
  local triggerSec = (HardcoreHUDDB.breath.secondsThreshold or 20)
  if remainingSec <= triggerSec then
    if not H.breathOverlay then H.InitBreathWarning() end
    if H.breathOverlay and not H.breathOverlay:IsShown() then
      pcall(function() H.breathOverlay:Show() end)
      if HardcoreHUDDB.audio and HardcoreHUDDB.audio.enabled and HardcoreHUDDB.audio.breath then
        if PlaySoundFile then PlaySoundFile("Sound/Interface/MapPing.wav") end
      end
    elseif H.breathOverlay then
      pcall(function() H.breathOverlay:Show() end)
    end
  else
    H.HideBreathWarning()
  end
end

-- Ensure breath warning is initialized with HUD
if H.InitBreathWarning then H.InitBreathWarning() end

-- Critical HP red pulsing overlay
HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
if HardcoreHUDDB.warnings.criticalOverlayEnabled == nil then HardcoreHUDDB.warnings.criticalOverlayEnabled = true end

-- Shield (PW:S) tracking defaults
HardcoreHUDDB.shield = HardcoreHUDDB.shield or { enabled = true, showText = false }

-- Warnings system defaults
if HardcoreHUDDB.warnings.enabled == nil then HardcoreHUDDB.warnings.enabled = true end

-- Leash tracking defaults
if HardcoreHUDDB.warnings.leash == nil then HardcoreHUDDB.warnings.leash = { enabled = true, distance = 50, sound = true } end

-- Range display defaults
if HardcoreHUDDB.warnings.rangeDisplay == nil then HardcoreHUDDB.warnings.rangeDisplay = { enabled = true, talentBonus = 0 } end

function H.InitCriticalOverlay()
  if H.critOverlay then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN")
  f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 210)
  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints(f)
  tex:SetColorTexture(1.0, 0.15, 0.1, 0) -- red
  f.tex = tex
  f:Hide()
  H.critOverlay = f

  f._pulse = { t = 0, speed = 1.75, minA = 0.20, maxA = 0.55 }
  f:SetScript("OnUpdate", function(self, elapsed)
    local p = self._pulse; p.t = (p.t + elapsed * p.speed) % (2*math.pi)
    local a = p.minA + (p.maxA - p.minA) * (0.5 + 0.5 * math.sin(p.t))
    self.tex:SetColorTexture(1.0, 0.15, 0.1, a)
  end)

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UNIT_HEALTH")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function(_, evt, unit)
    if evt == "PLAYER_ENTERING_WORLD" or unit == "player" then
      H.UpdateCriticalOverlay()
    end
  end)
  H.critEventFrame = ev
end

function H.HideCriticalOverlay()
  if H.critOverlay then pcall(function() H.critOverlay:Hide() end) end
end

function H.UpdateCriticalOverlay()
  if not HardcoreHUDDB.warnings or not HardcoreHUDDB.warnings.criticalOverlayEnabled then
    H.HideCriticalOverlay(); return
  end
  if not UnitExists("player") then H.HideCriticalOverlay(); return end
  local hp = UnitHealth("player")
  local maxhp = UnitHealthMax("player")
  if not maxhp or maxhp <= 0 then H.HideCriticalOverlay(); return end
  local pct = hp / maxhp
  local thresh = (HardcoreHUDDB.warnings.criticalThreshold or 0.20)
  if pct <= thresh and (HardcoreHUDDB.warnings.enabled ~= false) and (HardcoreHUDDB.warnings.criticalHP ~= false) then
    if not H.critOverlay then H.InitCriticalOverlay() end
    if H.critOverlay and not H.critOverlay:IsShown() then
      local ok, err = pcall(function() H.critOverlay:Show() end)
      if not ok and HardcoreHUDDB.debug then print("HardcoreHUD CritHP Show error:", err) end
      if HardcoreHUDDB.audio and HardcoreHUDDB.audio.enabled and HardcoreHUDDB.audio.critHP then
        if PlaySoundFile then PlaySoundFile("Sound/Interface/AlarmClockWarning2.wav") end
      end
    elseif H.critOverlay then
      local ok, err = pcall(function() H.critOverlay:Show() end)
      if not ok and HardcoreHUDDB.debug then print("HardcoreHUD CritHP Show error:", err) end
    end
  else
    H.HideCriticalOverlay()
  end
end

-- Ensure critical overlay is initialized
if H.InitCriticalOverlay then H.InitCriticalOverlay() end

-- SavedVariables defaults
HardcoreHUDDB = HardcoreHUDDB or {
  pos = { x = 0, y = -150 },
  size = { width = 220, height = 28 },
  layout = { thickness = 12, height = 200, separation = 140, gap = 8 },
  colors = {
    hp = {0, 0.8, 0},
    mana = {0, 0.5, 1},
    energy = {1, 0.85, 0},
    rage = {0.8, 0.2, 0.2},
    fiveSec = {1, 0.8, 0},
    tick = {0.9, 0.9, 0.9},
  },
  warnings = { criticalHP = true, multiAggro = true, levelElite = true, multiAggroThreshold = 2 },
  audio = { enabled = true },
  gtfo = { enabled = true, highDamage = true, lowDamage = true, fallAlert = true, volume = 1.0, lastAlert = 0 },
  thanksBuff = { enabled = false, onlyOutsideGroup = true, message = "Thanks for the buff!" },
  targetMarks = { enabled = true, locked = false, pos = { x = 0, y = -280 } },
  leveling = { enabled = true, locked = false, pos = { x = 0, y = -400 }, showXPBar = true, showRate = true, showTimeToLevel = true, showRested = true, showSessionTime = true },
  lock = true,
}
-- Ensure defaults exist when upgrading from older SavedVariables
if HardcoreHUDDB.lock == nil then HardcoreHUDDB.lock = true end
if HardcoreHUDDB.gtfo == nil then HardcoreHUDDB.gtfo = { enabled = true, highDamage = true, lowDamage = true, fallAlert = true, volume = 1.0, lastAlert = 0 } end
if HardcoreHUDDB.thanksBuff == nil then HardcoreHUDDB.thanksBuff = { enabled = false, onlyOutsideGroup = true, message = "Thanks for the buff!" } end
if HardcoreHUDDB.targetMarks == nil then HardcoreHUDDB.targetMarks = { enabled = true, locked = false, pos = { x = 0, y = -280 } } end
if HardcoreHUDDB.leveling == nil then HardcoreHUDDB.leveling = { enabled = true, locked = false, pos = { x = 0, y = -400 }, showXPBar = true, showRate = true, showTimeToLevel = true, showRested = true, showSessionTime = true } end

local f = CreateFrame("Frame", addonName.."Frame", UIParent)
H.root = f
-- CRITICAL: Override Hide() and SetShown() to keep HUD bars always visible
local originalHideRoot = f.Hide
local originalSetShown = f.SetShown
f.Hide = function(self) 
  -- Allow hiding if manually toggled via minimap menu
  if HardcoreHUDDB.manuallyHidden then
    originalHideRoot(self)
  end
end
f.SetShown = function(self, shown) 
  if not shown and not HardcoreHUDDB.manuallyHidden then 
    return 
  end 
  originalSetShown(self, shown) 
end
f._OriginalHide = originalHideRoot
f._OriginalSetShown = originalSetShown
-- Ensure frame stays visible by preventing UIParent fade
f:SetIgnoreParentAlpha(true)
-- CRITICAL: Force frame to stay visible via OnUpdate hook
f:SetScript("OnUpdate", function(self)
  -- Don't force visibility if manually hidden
  if HardcoreHUDDB.manuallyHidden then
    return
  end
  
  if not self:IsShown() then
    self:Show()
  end
  if self:GetAlpha() < 1 then
    self:SetAlpha(1)
  end
  -- Re-parent to WorldFrame if UIParent is hidden (happens when char window opens)
  if UIParent and not UIParent:IsShown() and self:GetParent() == UIParent then
    self:SetParent(WorldFrame or UIParent)
  elseif UIParent and UIParent:IsShown() and self:GetParent() ~= UIParent then
    self:SetParent(UIParent)
  end
end)
-- Guard missing position defaults
HardcoreHUDDB.pos = HardcoreHUDDB.pos or { x = 0, y = -150 }
f:ClearAllPoints()
f:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x or 0, HardcoreHUDDB.pos.y or -150)
HardcoreHUDDB.size = HardcoreHUDDB.size or { width = 420, height = 220 }
f:SetSize(HardcoreHUDDB.size.width or 420, HardcoreHUDDB.size.height or 220)
f:SetClampedToScreen(true)
f:EnableMouse(not HardcoreHUDDB.lock)
-- Expand hit rect so clicking near the bars drags the root
f:SetHitRectInsets(-200, -200, -220, -20)
f:RegisterForDrag("LeftButton")
f:SetMovable(not HardcoreHUDDB.lock)
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local cx, cy = self:GetCenter()
  local px, py = UIParent:GetCenter()
  local x = cx - px
  local y = cy - py
  HardcoreHUDDB.pos = { x = x, y = y }
  self:ClearAllPoints()
  self:SetPoint("CENTER", UIParent, "CENTER", x, y)
end)

-- Event hub
local ev = CreateFrame("Frame")
local function TryRegister(frame, evname)
  if not frame or not evname then return end
  pcall(function() frame:RegisterEvent(evname) end)
end
TryRegister(ev, "PLAYER_LOGIN")
TryRegister(ev, "PLAYER_ENTERING_WORLD")
TryRegister(ev, "PLAYER_REGEN_DISABLED")
TryRegister(ev, "PLAYER_REGEN_ENABLED")
TryRegister(ev, "UNIT_POWER")
TryRegister(ev, "UNIT_MAXPOWER")
TryRegister(ev, "UNIT_ENERGY")
TryRegister(ev, "UNIT_RAGE")
TryRegister(ev, "UNIT_MANA")
TryRegister(ev, "UNIT_DISPLAYPOWER")
TryRegister(ev, "UNIT_HEALTH")
TryRegister(ev, "UNIT_MAXHEALTH")
TryRegister(ev, "PLAYER_TARGET_CHANGED")
TryRegister(ev, "UNIT_COMBO_POINTS")
TryRegister(ev, "COMBAT_LOG_EVENT_UNFILTERED")
TryRegister(ev, "UNIT_TARGET")
TryRegister(ev, "UNIT_THREAT_LIST_UPDATE")
TryRegister(ev, "BAG_UPDATE_COOLDOWN")
TryRegister(ev, "BAG_UPDATE")
TryRegister(ev, "SPELLS_CHANGED")
TryRegister(ev, "SPELL_UPDATE_COOLDOWN")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    -- CRITICAL: Restore saved position from SavedVariables (now loaded)
    if H.root and HardcoreHUDDB.pos then
      H.root:ClearAllPoints()
      H.root:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x or 0, HardcoreHUDDB.pos.y or -150)
    end
    H.Init()
    H.UpdateAll()
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay(true) end
    if H.InitTargetMarkBar then H.InitTargetMarkBar() end
    if H.targetMarkBar and HardcoreHUDDB.targetMarks and HardcoreHUDDB.targetMarks.enabled then H.targetMarkBar:Show() end
    if H.InitLevelingTracker then H.InitLevelingTracker() end
    if H.levelingTracker and HardcoreHUDDB.leveling and HardcoreHUDDB.leveling.enabled then H.levelingTracker:Show() end
    if H.InitReputationTracker then H.InitReputationTracker() end
    if H.reputationTracker and HardcoreHUDDB.reputation and HardcoreHUDDB.reputation.enabled then H.reputationTracker:Show(); H.UpdateReputationTracker() end
    if H.InitThanksBuff then H.InitThanksBuff() end
    if H.InitGTFO then H.InitGTFO() end
    if H.BuildGTFOFrame then H.BuildGTFOFrame() end
    -- Session time is now managed by InitLevelingTracker (persists across reloads)
    -- Rebuild utility buttons to apply saved position
    if H.RebuildUtilityButtons then
      C_Timer.After(0.1, function()
        if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
      end)
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Start of combat
    H._combatStartTime = GetTime()
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- End of combat - hide leash bar
    if H.leashWarn then H.leashWarn:Hide() end
    H._combatStartTime = nil
  elseif event == "UNIT_POWER" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_ENERGY" or event == "UNIT_RAGE" or event == "UNIT_MANA" then
    local unit = ...
    if unit == "player" then
      H.UpdatePower()
      if H.UpdateOOMOverlay then H.UpdateOOMOverlay() end
    elseif unit == "target" then
      H.UpdateTarget()
    end
  elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    local unit = ...;
    if unit == "player" then
      H.UpdateHealth()
    elseif unit == "target" then
      H.UpdateTarget()
    end
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_COMBO_POINTS" then
    H.UpdateTarget()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if H.OnCombatLog then H.OnCombatLog(...) end
  elseif event == "UNIT_TARGET" then
    local unit = ...
    if H.OnUnitTarget then H.OnUnitTarget(unit) end
  elseif event == "UNIT_THREAT_LIST_UPDATE" then
    local unit = ...
    if H.OnThreatListUpdate then H.OnThreatListUpdate(unit) end
  elseif event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE" or event == "SPELLS_CHANGED" or event == "SPELL_UPDATE_COOLDOWN" then
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay() end
  end
end)

function H.Init()
  H.BuildBars()
  if H.InitTargetCastBar then H.InitTargetCastBar() end
  if H.InitInterruptTracker then H.InitInterruptTracker() end
  if H.InitDispelHighlight then H.InitDispelHighlight() end
  if H.InitOOMOverlay then H.InitOOMOverlay() end
  if H.BuildWarnings then
    H.BuildWarnings()
  else
    -- Defer a few frames in case Combat.lua loaded late due to client caching
    local triesW = 0
    local defW = CreateFrame("Frame")
    defW:SetScript("OnUpdate", function(self)
      triesW = triesW + 1
      if H.BuildWarnings then H.BuildWarnings(); self:SetScript("OnUpdate", nil); return end
      if triesW > 10 then
        print("HardcoreHUD: BuildWarnings missing; skipping warnings build")
        self:SetScript("OnUpdate", nil)
      end
    end)
  end
  if H.BuildUtilities then
    H.BuildUtilities()
  else
    -- Defer a few frames in case Utilities.lua loaded late due to syntax caching
    local tries = 0
    local def = CreateFrame("Frame")
    def:SetScript("OnUpdate", function(self)
      tries = tries + 1
      if H.BuildUtilities then H.BuildUtilities(); self:SetScript("OnUpdate", nil); return end
      if tries > 10 then
        print("HardcoreHUD: BuildUtilities missing; skipping utilities build")
        self:SetScript("OnUpdate", nil)
      end
    end)
  end
  H.BuildOptions()
  local post = CreateFrame("Frame")
  post:SetScript("OnUpdate", function(self)
    if H.ApplyLayout then H.ApplyLayout() end
    if H.ApplyBarTexture then H.ApplyBarTexture() end
    if H.UpdateAll then H.UpdateAll() end
    if H.ReanchorCooldowns then H.ReanchorCooldowns() end
    if H.ApplyLock then H.ApplyLock() end
    if H.SyncLockCheckbox then H.SyncLockCheckbox() end
    self:SetScript("OnUpdate", nil)
  end)
  -- Create minimap button (do not wait for options frame to exist)
  if Minimap and not _G["HardcoreHUDMiniMap"] then
    local mm = CreateFrame("Button", "HardcoreHUDMiniMap", Minimap)
    mm:SetSize(20,20)
    mm:SetFrameStrata("HIGH")
    mm:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local tex = mm:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(mm)
    tex:SetTexture("Interface/Icons/INV_Shield_04")
    -- Right-click dropdown menu
    local menu = CreateFrame("Frame", "HardcoreHUDMiniMapMenu", UIParent, "UIDropDownMenuTemplate")
    local function ToggleHUD()
      -- Use special flag to allow hiding via menu
      if H.root:IsShown() then
        HardcoreHUDDB.manuallyHidden = true
        if H.root._OriginalHide then
          H.root._OriginalHide(H.root)
        end
      else
        HardcoreHUDDB.manuallyHidden = false
        H.root:Show()
      end
    end
    local function ToggleLock()
      HardcoreHUDDB.lock = not HardcoreHUDDB.lock
      if H.ApplyLock then H.ApplyLock() end
      if H.SyncLockCheckbox then H.SyncLockCheckbox() end
    end
    local function OpenZones()
      if H.ShowZonesWindow then
        H.ShowZonesWindow()
      else
        print("HardcoreHUD: Zones window not available")
      end
    end
    local function ToggleWarnings()
      HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
      local currentlyOn = (HardcoreHUDDB.warnings.enabled ~= false)
      HardcoreHUDDB.warnings.enabled = not currentlyOn
      local nowOn = (HardcoreHUDDB.warnings.enabled ~= false)
      print("HardcoreHUD: Warnings "..(nowOn and "ON" or "OFF"))
      if not nowOn then
        if H.HideCriticalHPWarning then H.HideCriticalHPWarning() end
        if H.skull then H.skull:Hide() end
        if H.EliteAttentionText then H.EliteAttentionText:Hide() end
        if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
      else
        -- Re-evaluate skull based on current target when turning on
        if H.CheckSkull then H.CheckSkull() end
      end
    end
    local function initMenu(self, level)
      local info
      info = UIDropDownMenu_CreateInfo(); info.text = (H.root:IsShown() and "Hide HUD" or "Show HUD"); info.func = ToggleHUD; UIDropDownMenu_AddButton(info)
      info = UIDropDownMenu_CreateInfo(); info.text = (HardcoreHUDDB.lock and "Unlock HUD" or "Lock HUD"); info.func = ToggleLock; UIDropDownMenu_AddButton(info)
      local warnOn = (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false)
      info = UIDropDownMenu_CreateInfo(); info.text = (warnOn and "Disable Warnings" or "Enable Warnings"); info.func = ToggleWarnings; UIDropDownMenu_AddButton(info)
      info = UIDropDownMenu_CreateInfo(); info.text = "Zone List (Vanilla)"; info.func = OpenZones; UIDropDownMenu_AddButton(info)
    end
    UIDropDownMenu_Initialize(menu, initMenu, "MENU")
    mm:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        ToggleDropDownMenu(1, nil, menu, "cursor", 3, -3)
      else
        if H.SyncLockCheckbox then H.SyncLockCheckbox() end
        if HardcoreHUDOptions:IsShown() then HardcoreHUDOptions:Hide() else HardcoreHUDOptions:Show() end
        if H.SyncLockCheckbox then H.SyncLockCheckbox() end
      end
    end)
  end
end

-- OOM soon (mana) overlay anchored to mana bar
HardcoreHUDDB.oom = HardcoreHUDDB.oom or { enabled = true, threshold = 0.25 }

-- Mana recovery sources by class/race (best-effort IDs across client versions)
local RecoverySpellsByClass = {
  MAGE   = { 12051 },   -- Evocation
  DRUID  = { 29166 },   -- Innervate
  PRIEST = { 34433 },   -- Shadowfiend
}
local RecoverySpellsByRace = {
  BLOODELF = { 28730, 25046, 50613 }, -- Arcane Torrent variants
}

local function IsSpellReadyForPlayer(spellId)
  if not spellId then return false end
  if IsPlayerSpell and not IsPlayerSpell(spellId) then return false end
  if not GetSpellCooldown then return true end
  local s, d = GetSpellCooldown(spellId)
  if not s or s == 0 then return true end
  return (s + d - GetTime()) <= 0
end

local function PlayerHasManaRecoveryReady()
  local _, class = UnitClass("player")
  local race = select(2, UnitRace("player"))
  local list = {}
  if class and RecoverySpellsByClass[class] then
    for _, id in ipairs(RecoverySpellsByClass[class]) do table.insert(list, id) end
  end
  if type(race) == "string" and RecoverySpellsByRace[string.upper(race)] then
    for _, id in ipairs(RecoverySpellsByRace[string.upper(race)]) do table.insert(list, id) end
  end
  for _, id in ipairs(list) do
    if IsSpellReadyForPlayer(id) then return true end
  end
  return false
end

local function FindReadyManaPotion()
  if not GetContainerNumSlots or not GetContainerItemID or not GetItemCooldown then return nil end
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag)
    if slots then
      for slot=1,slots do
        local itemID = GetContainerItemID(bag, slot)
        if itemID then
          local name = GetItemInfo and GetItemInfo(itemID)
          if name and string.find(string.lower(name), "mana") and string.find(string.lower(name), "potion") then
            local start, duration = GetItemCooldown(itemID)
            if not start or start == 0 or (start + duration - GetTime()) <= 0 then
              return itemID
            end
          end
        end
      end
    end
  end
  return nil
end

function H.InitOOMOverlay()
  if H.oomOverlay then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN")
  f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 205)
  local tex = f:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(f)
  tex:SetColorTexture(0.2, 0.6, 1.0, 0)
  f.tex = tex
  f:Hide()
  H.oomOverlay = f
  f._pulse = { t=0, speed=2.2, minA=0.15, maxA=0.45, active=false }
  f:SetScript("OnUpdate", function(self, elapsed)
    local p = self._pulse
    if p and p.active then
      p.t = (p.t + elapsed * p.speed) % (2*math.pi)
      local a = p.minA + (p.maxA - p.minA) * (0.5 + 0.5 * math.sin(p.t))
      self.tex:SetColorTexture(0.2, 0.6, 1.0, a)
    end
  end)
  -- lightweight poller to catch threshold crossings even without events
  if not H._oomPoll then
    local poll = CreateFrame("Frame")
    poll._acc = 0
    poll:SetScript("OnUpdate", function(self, elapsed)
      self._acc = self._acc + elapsed
      if self._acc >= 0.3 then
        self._acc = 0
        if H.UpdateOOMOverlay then H.UpdateOOMOverlay() end
      end
    end)
    H._oomPoll = poll
  end
end

function H.UpdateOOMOverlay(force)
  -- Only show OOM warning during combat
  if not InCombatLockdown or not InCombatLockdown() then
    if H.oomOverlay then
      pcall(function() H.oomOverlay:Hide() end)
      H.oomOverlay._pulse.active = false
    end
    return
  end
  
  if not HardcoreHUDDB.oom or HardcoreHUDDB.oom.enabled == false then
    if H.oomOverlay then
      pcall(function() H.oomOverlay:Hide() end)
      H.oomOverlay._pulse.active = false
    end
    return
  end
  local ptype = UnitPowerType and UnitPowerType("player") or 1
  if ptype ~= 0 then -- only mana
    if H.oomOverlay then
      pcall(function() H.oomOverlay:Hide() end)
      H.oomOverlay._pulse.active = false
    end
    return
  end
  local cur = (UnitPower and UnitPower("player", 0)) or (UnitMana and UnitMana("player")) or 0
  local max = (UnitPowerMax and UnitPowerMax("player", 0)) or (UnitManaMax and UnitManaMax("player")) or 0
  if not max or max <= 0 then
    if H.oomOverlay then
      pcall(function() H.oomOverlay:Hide() end)
      H.oomOverlay._pulse.active = false
    end
    return
  end
  local pct = cur / max
  local thr = HardcoreHUDDB.oom.threshold or 0.25
  local considerRecovery = (HardcoreHUDDB.oom.considerRecovery ~= false)
  local readyPotion = FindReadyManaPotion()
  local recoveryReady = considerRecovery and PlayerHasManaRecoveryReady() or false
  local noRecovery = (not readyPotion) and (not recoveryReady)
  local shouldShow = (pct <= thr) and (considerRecovery and noRecovery or true)
  -- Also surface a separate clickable mana potion button (does not replace healing potion)
  -- Note: manaBtn visibility is handled by RebuildUtilityButtons in Utilities.lua
  -- Only update the texture/item binding here, not visibility
  if H.manaBtn then
    if pct <= thr and readyPotion then
      H.manaBtn.itemID = readyPotion
      local itemName = GetItemInfo and GetItemInfo(readyPotion)
      local attrVal = itemName and itemName or ("item:"..tostring(readyPotion))
      if H.manaBtn.SetAttribute then H.QueueSetAttribute(H.manaBtn, "item", attrVal) end
      if H.manaBtn.icon and GetItemIcon then H.manaBtn.icon:SetTexture(GetItemIcon(readyPotion) or "Interface/Icons/INV_Potion_76") end
    end
  end
  if shouldShow then
    if not H.oomOverlay then H.InitOOMOverlay() end
    if H.oomOverlay and not H.oomOverlay:IsShown() then
      H.oomOverlay._pulse.active = true
      local ok, err = pcall(function() H.oomOverlay:Show() end)
      if not ok and HardcoreHUDDB.debug then print("HardcoreHUD OOM Show error:", err) end
      if HardcoreHUDDB.audio and HardcoreHUDDB.audio.enabled and HardcoreHUDDB.audio.oom then
        if PlaySoundFile then PlaySoundFile("Sound/Interface/MapPing.wav") end
      end
    elseif H.oomOverlay then
      H.oomOverlay._pulse.active = true
      local ok, err = pcall(function() H.oomOverlay:Show() end)
      if not ok and HardcoreHUDDB.debug then print("HardcoreHUD OOM Show error:", err) end
    end
  else
    if type(HardcoreHUDDB.debug) == "table" and HardcoreHUDDB.debug.oom then
      if pct > thr then
        print(string.format("HardcoreHUD OOM: pct=%.2f above thr=%.2f", pct, thr))
      elseif considerRecovery and readyPotion then
        print("HardcoreHUD OOM: suppressed (mana potion ready)")
      elseif considerRecovery and recoveryReady then
        print("HardcoreHUD OOM: suppressed (recovery spell ready)")
      else
        print("HardcoreHUD OOM: suppressed (overlay disabled or unknown)")
      end
    end
    if H.oomOverlay then
      H.oomOverlay._pulse.active = false
      pcall(function() H.oomOverlay:Hide() end)
    end
  end
end

function H.UpdateAll()
  H.UpdatePower(); H.UpdateHealth(); H.UpdateTarget()
end

-- Lock/Unlock HUD dragging based on DB
function H.ApplyLock()
  -- Don't apply lock/unlock during combat - defer it
  if InCombatLockdown and InCombatLockdown() then
    H._pendingLockUpdate = true
    return
  end
  
  local locked = HardcoreHUDDB and HardcoreHUDDB.lock
  if H.root then
    pcall(function() H.root:EnableMouse(not locked) end)
    pcall(function() H.root:SetMovable(not locked) end)
    if not locked then
      H.root:RegisterForDrag("LeftButton")
      H.root:SetScript("OnDragStart", function(self) self:StartMoving() end)
      H.root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local px, py = UIParent:GetCenter()
        local x = cx - px
        local y = cy - py
        HardcoreHUDDB.pos = { x = x, y = y }
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)
      end)
    else
      H.root:RegisterForDrag()
    end
  end
  if H.bars then
    local b = H.bars
    if b.hp then pcall(function() b.hp:EnableMouse(not locked) end) end
    if b.pow then pcall(function() b.pow:EnableMouse(not locked) end) end
    if b.targetHP then pcall(function() b.targetHP:EnableMouse(not locked) end) end
    if b.targetPow then pcall(function() b.targetPow:EnableMouse(not locked) end) end
    if not locked then
      if b.hp then b.hp:RegisterForDrag("LeftButton") end
      if b.pow then b.pow:RegisterForDrag("LeftButton") end
      if b.targetHP then b.targetHP:RegisterForDrag("LeftButton") end
      if b.targetPow then b.targetPow:RegisterForDrag("LeftButton") end
    else
      if b.hp then b.hp:RegisterForDrag() end
      if b.pow then b.pow:RegisterForDrag() end
      if b.targetHP then b.targetHP:RegisterForDrag() end
      if b.targetPow then b.targetPow:RegisterForDrag() end
    end
  end
end

-- Handle deferred lock updates after combat
do
  local lockFrame = CreateFrame("Frame")
  lockFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  lockFrame:SetScript("OnEvent", function()
    if H._pendingLockUpdate then
      H._pendingLockUpdate = nil
      if H.ApplyLock then H.ApplyLock() end
    end
    -- Re-update OOM overlay now that we're out of combat
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay() end
    -- Re-update target bars now that we're out of combat
    if H.UpdateTarget then H.UpdateTarget() end
  end)
end

-- Fallback: Zones window builder if Zones.lua didn't load
if not H.ShowZonesWindow then
  local zones = {
    { name = "Dun Morogh", range = "1-10", side = "Alliance" },
    { name = "Elwynn Forest", range = "1-10", side = "Alliance" },
    { name = "Tirisfal Glades", range = "1-10", side = "Horde" },
    { name = "Durotar", range = "1-10", side = "Horde" },
    { name = "Mulgore", range = "1-10", side = "Horde" },
    { name = "Darkshore", range = "10-20", side = "Alliance" },
    { name = "Loch Modan", range = "10-20", side = "Alliance" },
    { name = "Westfall", range = "10-20", side = "Alliance" },
    { name = "Silverpine Forest", range = "10-20", side = "Horde" },
    { name = "Barrens", range = "10-25", side = "Contested" },
    { name = "Redridge Mountains", range = "15-25", side = "Alliance" },
    { name = "Stonetalon Mountains", range = "15-27", side = "Contested" },
    { name = "Ashenvale", range = "18-30", side = "Contested" },
    { name = "Duskwood", range = "18-30", side = "Alliance" },
    { name = "Hillsbrad Foothills", range = "20-30", side = "Contested" },
    { name = "Wetlands", range = "20-30", side = "Alliance" },
    { name = "Thousand Needles", range = "25-35", side = "Contested" },
    { name = "Alterac Mountains", range = "30-40", side = "Contested" },
    { name = "Arathi Highlands", range = "30-40", side = "Contested" },
    { name = "Desolace", range = "30-40", side = "Contested" },
    { name = "Stranglethorn Vale", range = "30-45", side = "Contested" },
    { name = "Badlands", range = "35-45", side = "Contested" },
    { name = "Swamp of Sorrows", range = "35-45", side = "Contested" },
    { name = "Hinterlands", range = "40-50", side = "Contested" },
    { name = "Feralas", range = "40-50", side = "Contested" },
    { name = "Tanaris", range = "40-50", side = "Contested" },
    { name = "Searing Gorge", range = "43-50", side = "Contested" },
    { name = "Felwood", range = "48-55", side = "Contested" },
    { name = "Un'Goro Crater", range = "48-55", side = "Contested" },
    { name = "Azshara", range = "48-55", side = "Contested" },
    { name = "Blasted Lands", range = "50-58", side = "Contested" },
    { name = "Burning Steppes", range = "50-58", side = "Contested" },
    { name = "Western Plaguelands", range = "51-58", side = "Contested" },
    { name = "Eastern Plaguelands", range = "53-60", side = "Contested" },
    { name = "Winterspring", range = "55-60", side = "Contested" },
  }
  -- Instances near each zone with level brackets
  local zoneInstances = {
    ["Durotar"] = { {name="Ragefire Chasm", range="13-18"} },
    ["Barrens"] = { {name="Wailing Caverns", range="17-24"}, {name="Razorfen Kraul", range="23-30"} },
    ["Westfall"] = { {name="Deadmines", range="17-26"} },
    ["Tirisfal Glades"] = { {name="Scarlet Monastery", range="26-45"} },
    ["Silverpine Forest"] = { {name="Shadowfang Keep", range="22-30"} },
    ["Stonetalon Mountains"] = { {name="Blackfathom Deeps", range="20-30"} },
    ["Desolace"] = { {name="Maraudon", range="45-52"} },
    ["Badlands"] = { {name="Uldaman", range="35-45"} },
    ["Swamp of Sorrows"] = { {name="Sunken Temple", range="50-54"} },
    ["Searing Gorge"] = { {name="Blackrock Depths", range="52-60"} },
    ["Burning Steppes"] = { {name="Blackrock Spire", range="55-60"} },
    ["Stranglethorn Vale"] = { {name="Zul'Farrak", range="44-54"} },
    ["Feralas"] = { {name="Dire Maul", range="55-60"} },
    ["Eastern Plaguelands"] = { {name="Scholomance", range="58-60"} },
    ["Western Plaguelands"] = { {name="Stratholme", range="58-60"} },
  }
  local function buildWindow()
    if H.zonesFrame then return end
    local f = CreateFrame("Frame", "HardcoreHUDZones", UIParent)
    H.zonesFrame = f
    f:SetSize(300, 380)
    f:SetPoint("CENTER")
    H.SafeBackdrop(f, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} }, 0,0,0,0.85)
    f:Hide()
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("Vanilla Zone Levels")
    local scroll = CreateFrame("ScrollFrame", "HardcoreHUDZonesScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 12)
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    local function parseRange(r)
      local a,b = string.match(r, "(%d+)%-(%d+)")
      a = tonumber(a); b = tonumber(b); return a or 0, b or 0
    end
    local function rebuild()
      local level = UnitLevel("player") or 1
      local minL = level - 3
      local maxL = level + 3
      local filtered = {}
      for _, z in ipairs(zones) do
        local lo, hi = parseRange(z.range)
        if hi >= minL and lo <= maxL then
          table.insert(filtered, z)
        end
      end
      local rows = math.max(#filtered, 1)
      local contentWidth = 260
      local contentHeight = rows * 20 + 20
      content:SetSize(contentWidth, contentHeight)
      -- shrink/expand frame height to fit filtered rows (with min/max bounds)
      local minH, maxH = 180, 380
      local newH = math.min(math.max(contentHeight + 60, minH), maxH)
      f:SetHeight(newH)
      -- clear previous fonts: recreate content frame
      for i = content:GetNumRegions(), 1, -1 do end
      local y = -4
      for _, z in ipairs(filtered) do
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        line:SetText(string.format("%s  |  %s", z.name, z.range))
        if z.side == "Alliance" then
          line:SetTextColor(0, 0.6, 1)
        elseif z.side == "Horde" then
          line:SetTextColor(0.9, 0.2, 0.2)
        else
          line:SetTextColor(1, 0.85, 0)
        end
        -- Tooltip on hover: show nearby instances and level brackets
        line:EnableMouse(true)
        line:SetScript("OnEnter", function(self)
          local inst = zoneInstances[z.name]
          if not inst or #inst == 0 then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:AddLine("Nearby Instances", 1, 0.92, 0.2)
          for _, info in ipairs(inst) do
            GameTooltip:AddLine(string.format("%s  (%s)", info.name, info.range), 0.9, 0.9, 0.9)
          end
          GameTooltip:Show()
        end)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y = y - 20
      end
      if #filtered == 0 then
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -4)
        line:SetText("No recommended zones for your level")
      end
    end
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    close:SetSize(120, 24)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnShow", function() rebuild() end)
  end
  function H.ShowZonesWindow()
    buildWindow()
    if H.zonesFrame:IsShown() then H.zonesFrame:Hide() else H.zonesFrame:Show() end
  end
end

-- Target Mark Button Bar (for raid marking)
function H.InitTargetMarkBar()
  if H.targetMarkBar then return end
  
  HardcoreHUDDB.targetMarks = HardcoreHUDDB.targetMarks or { enabled = true, pos = { x = 0, y = -280 } }
  
  -- Main frame - sleek horizontal bar
  local bar = CreateFrame("Frame", "HardcoreHUDTargetMarkBar", UIParent)
  bar:SetSize(280, 42)
  bar:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.targetMarks.pos.x, HardcoreHUDDB.targetMarks.pos.y)
  bar:SetFrameStrata("HIGH")
  
  -- Gradient background (dark with subtle shine)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
  
  -- Top highlight line
  local topLine = bar:CreateTexture(nil, "ARTWORK")
  topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  topLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  topLine:SetHeight(1)
  topLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Bottom highlight line
  local botLine = bar:CreateTexture(nil, "ARTWORK")
  botLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  botLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  botLine:SetHeight(1)
  botLine:SetColorTexture(0.1, 0.1, 0.1, 0.6)
  
  -- Left border
  local leftBorder = bar:CreateTexture(nil, "ARTWORK")
  leftBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  leftBorder:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  leftBorder:SetWidth(1)
  leftBorder:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Right border
  local rightBorder = bar:CreateTexture(nil, "ARTWORK")
  rightBorder:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
  rightBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  rightBorder:SetWidth(1)
  rightBorder:SetColorTexture(0.3, 0.3, 0.3, 0.8)
  
  bar:Hide()
  H.targetMarkBar = bar
  
  -- Target marks: 1=Star, 2=Circle, 3=Diamond, 4=Triangle, 5=Moon, 6=Square, 7=X, 8=Skull
  local marks = {
    { name = "Star", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_1" },
    { name = "Circle", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_2" },
    { name = "Diamond", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_3" },
    { name = "Triangle", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_4" },
    { name = "Moon", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_5" },
    { name = "Square", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_6" },
    { name = "X", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_7" },
    { name = "Skull", icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_8" },
  }
  
  H.targetMarkButtons = {}
  
  for i, mark in ipairs(marks) do
    local btn = CreateFrame("Button", "HardcoreHUDMark"..i, bar, "SecureActionButtonTemplate")
    btn:SetSize(32, 32)
    btn:SetPoint("TOPLEFT", bar, "TOPLEFT", 4 + (i-1)*34, 5)
    
    -- Button background - transparent so icons show through
    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints(btn)
    btnBg:SetColorTexture(0.05, 0.05, 0.05, 0.3)
    btn.btnBg = btnBg
    
    -- Icon - colored square with mark symbol
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(mark.icon)
    icon:SetVertexColor(1, 1, 1, 1)
    btn.icon = icon
    
    -- Button border - darker frame
    local btnBorder = btn:CreateTexture(nil, "OVERLAY")
    btnBorder:SetAllPoints(btn)
    btnBorder:SetTexture("Interface/Buttons/UI-Slot-Button")
    btnBorder:SetVertexColor(0.3, 0.3, 0.3, 0.8)
    btn.border = btnBorder
    
    -- Highlight on hover
    btn:SetScript("OnEnter", function(self)
      btnBg:SetColorTexture(0.3, 0.3, 0.3, 0.6)
      btnBorder:SetVertexColor(1, 0.84, 0, 1)
      icon:SetVertexColor(1, 1, 1, 1)  -- Brighter on hover
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(mark.name, 1, 1, 1)
      GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function(self)
      btnBg:SetColorTexture(0.05, 0.05, 0.05, 0.3)
      btnBorder:SetVertexColor(0.3, 0.3, 0.3, 0.8)
      icon:SetVertexColor(1, 1, 1, 1)  -- Back to normal
      GameTooltip:Hide()
    end)
    
    -- Set secure attribute for marking
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/tm " .. i)
    
    H.targetMarkButtons[i] = btn
  end
  
  -- Make bar draggable
  local function onDragStart(self)
    if not HardcoreHUDDB.targetMarks.locked then
      self:StartMoving()
    end
  end
  
  local function onDragStop(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local px, py = UIParent:GetCenter()
    HardcoreHUDDB.targetMarks.pos.x = x - px
    HardcoreHUDDB.targetMarks.pos.y = y - py
  end
  
  bar:SetMovable(true)
  bar:SetUserPlaced(false)
  bar:SetScript("OnMouseDown", onDragStart)
  bar:SetScript("OnMouseUp", onDragStop)
end

-- Toggle Target Mark Bar visibility
function H.ToggleTargetMarkBar()
  if not H.targetMarkBar then H.InitTargetMarkBar() end
  if H.targetMarkBar:IsShown() then
    H.targetMarkBar:Hide()
    HardcoreHUDDB.targetMarks.enabled = false
  else
    H.targetMarkBar:Show()
    HardcoreHUDDB.targetMarks.enabled = true
  end
end