local addonName = ...
HardcoreHUD = HardcoreHUD or {}
local H = HardcoreHUD
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
end

function H.UpdateTargetCastBarVisibility()
  if not H.cast or not H.cast.targetBar then return end
  if HardcoreHUDDB and HardcoreHUDDB.castbar and HardcoreHUDDB.castbar.enabled then
    -- no-op; visibility managed by events
  else
    H.cast.targetBar:Hide()
  end
end

local function setCastProgress(startMS, endMS, isChannel)
  if not H.cast or not H.cast.targetBar then return end
  H.cast._channel = isChannel or false
  H.cast._startTime = startMS / 1000
  H.cast._endTime = endMS / 1000
  local duration = H.cast._endTime - H.cast._startTime
  -- Start empty; texture height grows from bottom
  if H.cast.fill then H.cast.fill:SetHeight(0) end
  H.cast.targetBar:Show()
  H.cast.targetBar:SetScript("OnUpdate", function(self, elapsed)
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
      self:SetScript("OnUpdate", nil)
      self:Hide()
    end
  end)
end

function H.HandleTargetCastEvent(event, unit)
  if unit ~= "target" then return end
  if not HardcoreHUDDB or not HardcoreHUDDB.castbar or not HardcoreHUDDB.castbar.enabled then return end
  if not H.cast or not H.cast.targetBar then H.InitTargetCastBar() end
  if event == "UNIT_SPELLCAST_START" then
    local name, _, _, _, startTimeMS, endTimeMS = UnitCastingInfo("target")
    if name and startTimeMS and endTimeMS then
      H.cast.spell:SetText(name)
      setCastProgress(startTimeMS, endTimeMS, false)
    end
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
    if H.cast and H.cast.targetBar then H.cast.targetBar:SetScript("OnUpdate", nil); H.cast.targetBar:Hide() end
  elseif event == "UNIT_SPELLCAST_DELAYED" then
    local name, _, _, _, startTimeMS, endTimeMS = UnitCastingInfo("target")
    if name and startTimeMS and endTimeMS then
      H.cast.spell:SetText(name)
      setCastProgress(startTimeMS, endTimeMS, false)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    local name, _, _, _, startTimeMS, endTimeMS = UnitChannelInfo("target")
    if name and startTimeMS and endTimeMS then
      H.cast.spell:SetText(name)
      setCastProgress(startTimeMS, endTimeMS, true)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
    local name, _, _, _, startTimeMS, endTimeMS = UnitChannelInfo("target")
    if name and startTimeMS and endTimeMS then
      H.cast.spell:SetText(name)
      setCastProgress(startTimeMS, endTimeMS, true)
    end
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    if H.cast and H.cast.targetBar then H.cast.targetBar:SetScript("OnUpdate", nil); H.cast.targetBar:Hide() end
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
          local name, _, _, _, sMS, eMS = UnitCastingInfo("target")
          if not name then name, _, _, _, sMS, eMS = UnitChannelInfo("target") end
          if name and sMS and eMS then
            if not H.cast or not H.cast.targetBar then H.InitTargetCastBar() end
            H.cast.spell:SetText(name)
            setCastProgress(sMS, eMS, UnitChannelInfo("target") ~= nil)
          else
            if H.cast and H.cast.targetBar then H.cast.targetBar:SetScript("OnUpdate", nil); H.cast.targetBar:Hide() end
          end
        else
          if H.cast and H.cast.targetBar then H.cast.targetBar:Hide() end
        end
      else
        H.HandleTargetCastEvent(event, unit)
      end
    end)
    H._castEvents = ef
  end
end

-- Ensure SavedVariables table exists before first access
HardcoreHUDDB = HardcoreHUDDB or {}

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
    if H.breathOverlay then H.breathOverlay:Show() end
  else
    H.HideBreathWarning()
  end
end

-- Ensure breath warning is initialized with HUD
if H.InitBreathWarning then H.InitBreathWarning() end

-- Critical HP red pulsing overlay
HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
if HardcoreHUDDB.warnings.criticalOverlayEnabled == nil then HardcoreHUDDB.warnings.criticalOverlayEnabled = true end

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
  if H.critOverlay then H.critOverlay:Hide() end
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
    if H.critOverlay then H.critOverlay:Show() end
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
  lock = true,
}
-- Ensure defaults exist when upgrading from older SavedVariables
if HardcoreHUDDB.lock == nil then HardcoreHUDDB.lock = true end

local f = CreateFrame("Frame", addonName.."Frame", UIParent)
H.root = f
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
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p,_,rp,x,y = self:GetPoint(); HardcoreHUDDB.pos = { x=x, y=y } end)

-- Event hub
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UNIT_POWER")
ev:RegisterEvent("UNIT_MAXPOWER")
ev:RegisterEvent("UNIT_ENERGY")
ev:RegisterEvent("UNIT_RAGE")
ev:RegisterEvent("UNIT_MANA")
ev:RegisterEvent("UNIT_DISPLAYPOWER")
ev:RegisterEvent("UNIT_HEALTH")
ev:RegisterEvent("UNIT_MAXHEALTH")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UNIT_COMBO_POINTS")
ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ev:RegisterEvent("UNIT_TARGET")
ev:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    H.Init()
    H.UpdateAll()
  elseif event == "UNIT_POWER" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_ENERGY" or event == "UNIT_RAGE" or event == "UNIT_MANA" then
    local unit = ...
    if unit == "player" then
      H.UpdatePower()
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
  end
end)

function H.Init()
  H.BuildBars()
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
  -- Create minimap button
  if Minimap and HardcoreHUDOptions and not _G["HardcoreHUDMiniMap"] then
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
      local shown = H.root:IsShown()
      if shown then H.root:Hide() else H.root:Show() end
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

function H.UpdateAll()
  H.UpdatePower(); H.UpdateHealth(); H.UpdateTarget()
end

-- Lock/Unlock HUD dragging based on DB
function H.ApplyLock()
  local locked = HardcoreHUDDB and HardcoreHUDDB.lock
  if H.root then
    H.root:EnableMouse(not locked)
    H.root:SetMovable(not locked)
    if not locked then
      H.root:RegisterForDrag("LeftButton")
      H.root:SetScript("OnDragStart", function(self) self:StartMoving() end)
      H.root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p,_,rp,x,y = self:GetPoint()
        HardcoreHUDDB.pos = { x=x, y=y }
      end)
    else
      H.root:RegisterForDrag()
    end
  end
  if H.bars then
    local b = H.bars
    if b.hp then b.hp:EnableMouse(not locked) end
    if b.pow then b.pow:EnableMouse(not locked) end
    if b.targetHP then b.targetHP:EnableMouse(not locked) end
    if b.targetPow then b.targetPow:EnableMouse(not locked) end
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
  local function buildWindow()
    if H.zonesFrame then return end
    local f = CreateFrame("Frame", "HardcoreHUDZones", UIParent)
    H.zonesFrame = f
    f:SetSize(300, 380)
    f:SetPoint("CENTER")
    f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} })
    f:SetBackdropColor(0,0,0,0.85)
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
