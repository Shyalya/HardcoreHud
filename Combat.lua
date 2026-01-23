local H = HardcoreHUD
local rc = LibStub("LibRangeCheck-3.0", true)  -- Get LibRangeCheck library

-- Critical HP warning
function H.BuildWarnings()
  local w = CreateFrame("Frame", nil, UIParent)
  H.warnHP = w
  w:SetSize(260, 60)
  -- EMA smoothing state
  local lossEMA = nil
  local alphaFast = 0.5  -- fast response under spikes
  local alphaSlow = 0.2  -- stable tracking under low damage
  w:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
  w:SetFrameStrata("FULLSCREEN_DIALOG")
  local t = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetText("Attention: Critical Health!")
  t:SetTextColor(1,0.2,0.2,1)
  t:SetPoint("CENTER")
  w:Hide()

  -- Big critical icon overlay (use health potion icon)
  local ci = CreateFrame("Frame", nil, UIParent)
  H.critIcon = ci
  ci:SetSize(72, 72)
  ci:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  ci:SetFrameStrata("FULLSCREEN_DIALOG")
  local cit = ci:CreateTexture(nil, "ARTWORK")
  cit:SetAllPoints(ci)
  cit:SetTexture("Interface/Icons/INV_Potion_54")

  -- Skull indicator near target frame
  local skull = CreateFrame("Frame", nil, UIParent)
  H.skull = skull
  skull:SetSize(32,32)
  skull:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  skull:SetFrameStrata("FULLSCREEN_DIALOG")
  local tex = skull:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(skull)
  tex:SetTexture("Interface/TargetingFrame/skull")
  skull:Hide()

  -- Elite icons (Feign Death) shown with elite warning: 3 side-by-side
  H.eliteIcons = {}
  for i=1,3 do
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER", UIParent, "CENTER", -48 + (i-1)*48, 160)
    icon:SetFrameStrata("FULLSCREEN_DIALOG")
    local texI = icon:CreateTexture(nil, "ARTWORK")
    texI:SetAllPoints(icon)
    texI:SetTexture("Interface/Icons/Ability_Rogue_FeignDeath")
    icon:Hide()
    H.eliteIcons[i] = icon
  end

  -- Unified danger text (elite or multi-aggro) on a dedicated high-strata frame
  local eliteTextFrame = CreateFrame("Frame", nil, UIParent)
  eliteTextFrame:SetSize(340, 40)
  eliteTextFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  eliteTextFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  eliteTextFrame:Hide()
  local eliteText = eliteTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  eliteText:SetPoint("CENTER", eliteTextFrame, "CENTER")
  eliteText:SetText("Attention Danger Attention")
  eliteText:SetTextColor(1, 0.9, 0.2, 1)
  -- Improve legibility: bold outline + subtle shadow
  if STANDARD_TEXT_FONT then eliteText:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE") end
  eliteText:SetShadowColor(0,0,0,0.85)
  eliteText:SetShadowOffset(1,-1)
  H.eliteTextFrame = eliteTextFrame
  H.EliteAttentionText = eliteText

  -- Damage spike / Time-to-Death bar
  HardcoreHUDDB.spike = HardcoreHUDDB.spike or { enabled = true, window = 5, maxDisplay = 30, warnThreshold = 3 }
  -- Integrate TTD into the main HP bar to reduce clutter
  local parentBar = (H.bars and H.bars.hp) or UIParent
  local spike = CreateFrame("StatusBar", nil, parentBar)
  spike:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  -- Stretch across the HP bar width as a thin overlay at the top
  spike:ClearAllPoints()
  spike:SetPoint("TOPLEFT", parentBar, "TOPLEFT", 0, 0)
  spike:SetPoint("TOPRIGHT", parentBar, "TOPRIGHT", 0, 0)
  spike:SetHeight(6)
  spike:SetMinMaxValues(0, HardcoreHUDDB.spike.maxDisplay or 10)
  spike:SetValue(0)
  -- Draw above the HP bar but below fullscreen dialogs
  spike:SetFrameStrata("HIGH")
  spike:Hide()
  local sbg = spike:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints(spike)
  sbg:SetColorTexture(0,0,0,0.55)
  local stxt = spike:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  stxt:SetPoint("BOTTOMRIGHT", spike, "TOPRIGHT", 0, 0)
  spike.text = stxt
  spike.pulseAcc = 0
  H.spikeFrame = spike

  -- Performance (Latency/FPS) warning
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  if HardcoreHUDDB.warnings.latency == nil then HardcoreHUDDB.warnings.latency = true end
  HardcoreHUDDB.warnings.latencyMS = HardcoreHUDDB.warnings.latencyMS or 800
  HardcoreHUDDB.warnings.fpsLow = HardcoreHUDDB.warnings.fpsLow or 20
  local perf = CreateFrame("Frame", nil, UIParent)
  perf:SetSize(340, 40)
  perf:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  local ptxt = perf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ptxt:SetPoint("CENTER")
  ptxt:SetText("Gefahr: verzögerte Reaktionen")
  ptxt:SetTextColor(1,0.4,0,1)
  perf.text = ptxt
  perf:Hide()
  H.perfWarn = perf

  -- Leash warning overlay (distance to target/enemy with timer)
  HardcoreHUDDB.warnings.leash = HardcoreHUDDB.warnings.leash or { enabled = true, distance = 31, sound = true, locked = false }
  if not HardcoreHUDDB.warnings.leash.pos then
    HardcoreHUDDB.warnings.leash.pos = { x = 0, y = 80 }
  end
  local leashFrame = CreateFrame("Frame", nil, UIParent)
  H.leashWarn = leashFrame
  leashFrame:SetSize(340, 80)
  local pos = HardcoreHUDDB.warnings.leash.pos
  leashFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
  leashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  leashFrame:Hide()
  
  -- Make draggable
  leashFrame:SetMovable(true)
  leashFrame:EnableMouse(true)
  leashFrame:SetClampedToScreen(true)
  leashFrame:RegisterForDrag("LeftButton")
  leashFrame:SetScript("OnDragStart", function(self)
    if not HardcoreHUDDB.warnings.leash.locked then
      self:StartMoving()
    end
  end)
  leashFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Calculate position relative to screen center for consistent saving
    local cx, cy = self:GetCenter()
    local px, py = UIParent:GetCenter()
    local x = cx - px
    local y = cy - py
    HardcoreHUDDB.warnings.leash.pos = { x = x, y = y }
    -- Reanchor to CENTER with saved offset
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end)
  
  -- Title text (hidden by default, shown only when unlocked for dragging)
  local leashTitle = leashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  leashTitle:SetPoint("TOP", leashFrame, "TOP", 0, -5)
  leashTitle:SetText("LEASH TRACKING")
  leashTitle:SetTextColor(1, 0.8, 0, 1)
  if STANDARD_TEXT_FONT then leashTitle:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE") end
  leashTitle:Hide()  -- Hidden by default
  leashFrame.title = leashTitle
  
  -- Progress bar (anchor to frame top when title is hidden)
  local leashBar = CreateFrame("StatusBar", nil, leashFrame)
  leashBar:SetSize(300, 16)
  leashBar:SetPoint("TOP", leashFrame, "TOP", 0, -5)  -- Anchor to frame, not title
  leashBar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
  leashBar:SetMinMaxValues(0, 100)
  leashBar:SetValue(50)
  leashBar:SetStatusBarColor(1, 0.5, 0, 1) -- Orange default
  
  -- Bar background
  local barBg = leashBar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(leashBar)
  barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
  
  -- Clean thin border (1px lines)
  local borderSize = 1
  local borderColor = {0.4, 0.4, 0.4, 1}
  local borders = {}
  borders[1] = leashBar:CreateTexture(nil, "OVERLAY")
  borders[1]:SetPoint("TOPLEFT", leashBar, "TOPLEFT", 0, 0)
  borders[1]:SetPoint("TOPRIGHT", leashBar, "TOPRIGHT", 0, 0)
  borders[1]:SetHeight(borderSize)
  borders[1]:SetColorTexture(unpack(borderColor))
  borders[2] = leashBar:CreateTexture(nil, "OVERLAY")
  borders[2]:SetPoint("BOTTOMLEFT", leashBar, "BOTTOMLEFT", 0, 0)
  borders[2]:SetPoint("BOTTOMRIGHT", leashBar, "BOTTOMRIGHT", 0, 0)
  borders[2]:SetHeight(borderSize)
  borders[2]:SetColorTexture(unpack(borderColor))
  borders[3] = leashBar:CreateTexture(nil, "OVERLAY")
  borders[3]:SetPoint("TOPLEFT", leashBar, "TOPLEFT", 0, 0)
  borders[3]:SetPoint("BOTTOMLEFT", leashBar, "BOTTOMLEFT", 0, 0)
  borders[3]:SetWidth(borderSize)
  borders[3]:SetColorTexture(unpack(borderColor))
  borders[4] = leashBar:CreateTexture(nil, "OVERLAY")
  borders[4]:SetPoint("TOPRIGHT", leashBar, "TOPRIGHT", 0, 0)
  borders[4]:SetPoint("BOTTOMRIGHT", leashBar, "BOTTOMRIGHT", 0, 0)
  borders[4]:SetWidth(borderSize)
  borders[4]:SetColorTexture(unpack(borderColor))
  
  leashFrame.bar = leashBar
  
  -- Stats text (distance + time)
  local leashStats = leashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leashStats:SetPoint("TOP", leashBar, "BOTTOM", 0, -6)
  leashFrame.stats = leashStats
  
  -- Leash icon
  local leashIcon = leashFrame:CreateTexture(nil, "ARTWORK")
  leashIcon:SetSize(32, 32)
  leashIcon:SetPoint("RIGHT", leashTitle, "LEFT", -12, 0)
  leashIcon:SetTexture("Interface/Icons/Spell_Misc_Chains")
  leashFrame.icon = leashIcon

  -- Range Display (simple distance to target)
  HardcoreHUDDB.warnings.rangeDisplay = HardcoreHUDDB.warnings.rangeDisplay or { enabled = true, fontSize = 24, locked = false }
  if not HardcoreHUDDB.warnings.rangeDisplay.pos then
    HardcoreHUDDB.warnings.rangeDisplay.pos = { x = 0, y = -140 }
  end
  local rangeFrame = CreateFrame("Frame", nil, UIParent)
  H.rangeDisplay = rangeFrame
  rangeFrame:SetSize(120, 50)
  local pos = HardcoreHUDDB.warnings.rangeDisplay.pos
  rangeFrame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
  rangeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  rangeFrame:Hide()
  
  -- Make draggable
  rangeFrame:SetMovable(true)
  rangeFrame:EnableMouse(true)
  rangeFrame:SetClampedToScreen(true)
  rangeFrame:RegisterForDrag("LeftButton")
  rangeFrame:SetScript("OnDragStart", function(self)
    if not HardcoreHUDDB.warnings.rangeDisplay.locked then
      self:StartMoving()
    end
  end)
  rangeFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local px, py = UIParent:GetCenter()
    local x = cx - px
    local y = cy - py
    HardcoreHUDDB.warnings.rangeDisplay.pos = { x = x, y = y }
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end)
  
  -- Range text (big display) - NO BACKGROUND
  local rangeText = rangeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  rangeText:SetPoint("CENTER", rangeFrame, "CENTER", 0, 5)
  rangeText:SetText("-- yd")
  rangeText:SetTextColor(1, 1, 1, 1)
  local fontSize = HardcoreHUDDB.warnings.rangeDisplay.fontSize or 24
  if STANDARD_TEXT_FONT then 
    rangeText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
  else
    rangeText:SetFont(GameFontNormal:GetFont(), fontSize, "OUTLINE")
  end
  rangeFrame.text = rangeText
  
  -- Range label
  local rangeLabel = rangeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rangeLabel:SetPoint("BOTTOM", rangeText, "TOP", 0, 2)
  rangeLabel:SetText("RANGE")
  rangeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
  rangeFrame.label = rangeLabel
end

-- Centralized spike/TTD visibility helper to honor alwaysShow
function H.UpdateSpikeVisibility()
  local cfg = HardcoreHUDDB.spike
  if not (cfg and cfg.enabled) then if H.spikeFrame then H.spikeFrame:Hide() end return end
  -- Only show in combat per request
  if H._inCombat then
    if H.spikeFrame then H.spikeFrame:Show() end
  else
    if H.spikeFrame then H.spikeFrame:Hide() end
  end
end

function H.ShowCriticalHPWarning()
  if HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.criticalHP then
    -- Suppress critical HP warning when dead or a ghost
    if (UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player")) then
      H.HideCriticalHPWarning()
      return
    end
    
    -- Suppress critical HP warning outside of combat
    if not InCombatLockdown or not InCombatLockdown() then
      H.HideCriticalHPWarning()
      return
    end
    
    -- Suppress critical HP warning in instances (dungeons/raids)
    local inInstance = IsInInstance and IsInInstance() or false
    if inInstance then
      H.HideCriticalHPWarning()
      return
    end
    
    if not H.warnHP then
      local w = CreateFrame("Frame", nil, UIParent)
      w:SetSize(1,1)
      w:SetPoint("CENTER")
      w:Hide()
      H.warnHP = w
    end
    H.warnHP:Show()
    if H.critIcon then H.critIcon:Show() end
  end
end

-- Latency/FPS updater (lightweight)
if not H._perfDriver then
  local pd = CreateFrame("Frame")
  H._perfDriver = pd
  local acc = 0
  pd:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 1.0 then return end
    acc = 0
    if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.latency) then
      if H.perfWarn then H.perfWarn:Hide() end
      return
    end
    local _,_,home,world = GetNetStats()
    local latency = math.max(home or 0, world or 0)
    local fps = GetFramerate() or 0
    local show = (latency >= (HardcoreHUDDB.warnings.latencyMS or 800)) or (fps > 0 and fps < (HardcoreHUDDB.warnings.fpsLow or 20))
    if show and H.perfWarn then
      -- Optionally adapt color based on which condition triggered
      local r,g,b = 1,0.4,0
      if fps > 0 and fps < (HardcoreHUDDB.warnings.fpsLow or 20) then r,g,b = 1,0.15,0 end
      H.perfWarn.text:SetText("Gefahr: verzögerte Reaktionen")
      H.perfWarn.text:SetTextColor(r,g,b,1)
      H.perfWarn:Show()
    elseif H.perfWarn then
      H.perfWarn:Hide()
    end
  end)
end
function H.HideCriticalHPWarning()
  if H.warnHP and H.warnHP.Hide then H.warnHP:Hide() end
  if H.critIcon then H.critIcon:Hide() end
  if H.UpdateCriticalOverlay then H.UpdateCriticalOverlay() end
end

-- Auto-hide critical HP warning when HP recovers above threshold
if not H._critHPDriver then
  local cf = CreateFrame("Frame")
  H._critHPDriver = cf
  cf:RegisterEvent("UNIT_HEALTH")
  cf:RegisterEvent("PLAYER_ENTERING_WORLD")
  cf:SetScript("OnEvent", function(_, event, unit)
    if unit and unit ~= "player" then return end
    if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.criticalHP) then return end
    -- Suppress display while dead/ghost
    if (UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player")) then
      H.HideCriticalHPWarning()
      return
    end
    local hp = UnitHealth("player") or 0
    local max = UnitHealthMax("player") or 1
    local ratio = max > 0 and (hp / max) or 1
    local thresh = (HardcoreHUDDB.warnings.criticalThreshold or 0.20)
    if ratio > thresh then
      H.HideCriticalHPWarning()
    end
  end)
end

local function PlayCriticalSound()
  -- Warsong/Arathi Flag Taken (Wrath path under Spells)
  PlaySoundFile("Sound\\Spells\\PVPFlagTaken.wav", "Master")
end

local function PlayMultiAggroSound()
  PlayCriticalSound()
end

local function PlayEliteSound()
  -- Raid warning sound
  PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
end

-- Spike updater frame (separate lightweight OnUpdate)
-- Continuous Time-to-Death estimator using HP loss rate
if not H._ttdDriver then
  local drv = CreateFrame("Frame")
  H._ttdDriver = drv
  local accum = 0
  local sampleAcc = 0
  H._hpSamples = H._hpSamples or {}
  drv:SetScript("OnUpdate", function(_, dt)
    accum = accum + dt
    sampleAcc = sampleAcc + dt
    local cfg = HardcoreHUDDB.spike
    if not (cfg and cfg.enabled) then if H.spikeFrame then H.spikeFrame:Hide() end return end
    -- Only operate while in combat; hide bar and skip when not
    if not H._inCombat then
      if H.spikeFrame then H.spikeFrame:Hide() end
      return
    end
    -- Sample HP at ~10 Hz to build a moving window
    if sampleAcc >= 0.1 then
      sampleAcc = 0
      local now = GetTime()
      local hp = UnitHealth("player") or 0
      table.insert(H._hpSamples, {t=now, hp=hp})
      -- trim to window
      local win = cfg.window or 5
      local cutoff = now - win
      local newIdx = 1
      for i=1,#H._hpSamples do
        if H._hpSamples[i].t >= cutoff then H._hpSamples[newIdx] = H._hpSamples[i]; newIdx = newIdx + 1 end
      end
      for i=newIdx,#H._hpSamples do H._hpSamples[i] = nil end
    end

    if accum < 0.2 then return end
    accum = 0
    if not H.spikeFrame then return end
    -- Compute average HP loss per second over window (ignore gains)
    local samples = H._hpSamples
    if not samples or #samples < 2 then H.spikeFrame:Show(); H.spikeFrame:SetValue(0); H.spikeFrame.text:SetText("TTD: --") return end
    local loss = 0
    for i=2,#samples do
      local delta = samples[i-1].hp - samples[i].hp
      if delta > 0 then loss = loss + delta end
    end
    local win = cfg.window or 5
    local dps = loss / win
    local curHP = UnitHealth("player") or 0
    local ttd
    if dps > 1e-3 then
      ttd = curHP / dps
    else
      ttd = (cfg.maxDisplay or 10)
    end
    local maxDisp = cfg.maxDisplay or 10
    local ttdUncapped = ttd
    local displayVal = ttdUncapped
    if displayVal > maxDisp then displayVal = maxDisp end
    local f = H.spikeFrame
    f:SetMinMaxValues(0, maxDisp)
    f:SetValue(displayVal)
    -- Color: green >8, yellow >5, orange >3, red <=3
    local r,g,b
    if ttdUncapped > 8 then r,g,b = 0,1,0
    elseif ttdUncapped > 5 then r,g,b = 1,1,0
    elseif ttdUncapped > (cfg.warnThreshold or 3) then r,g,b = 1,0.5,0
    else r,g,b = 1,0.15,0 end
    f:SetStatusBarColor(r,g,b)
    local text = string.format("TTD: %.1fs", ttdUncapped)
    if ttdUncapped > maxDisp then text = text .. "+" end
    f.text:SetText(text)
    f:Show()
    -- Pulse when critical (<= warnThreshold)
    if ttdUncapped <= (cfg.warnThreshold or 3) then
      f.pulseAcc = f.pulseAcc + 0.2
      local alpha = 0.55 + 0.45 * math.abs(math.sin(f.pulseAcc*6))
      f:SetAlpha(alpha)
    else
      f.pulseAcc = 0
      f:SetAlpha(1)
    end
  end)
end

-- Track player combat state to control TTD visibility and sampling
if not H._combatWatcher then
  local cw = CreateFrame("Frame")
  H._combatWatcher = cw
  cw:RegisterEvent("PLAYER_ENTERING_WORLD")
  cw:RegisterEvent("PLAYER_REGEN_DISABLED")
  cw:RegisterEvent("PLAYER_REGEN_ENABLED")
  cw:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      H._inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    elseif event == "PLAYER_REGEN_DISABLED" then
      H._inCombat = true
      -- Fresh window at combat start so motion begins promptly
      H._hpSamples = {}
    elseif event == "PLAYER_REGEN_ENABLED" then
      H._inCombat = false
      -- Clear samples and hide bar when leaving combat
      H._hpSamples = {}
      if H.spikeFrame then
        H.spikeFrame:SetValue(0)
        H.spikeFrame.text:SetText("TTD: --")
        H.spikeFrame:Hide()
      end
    end
    if H.UpdateSpikeVisibility then H.UpdateSpikeVisibility() end
  end)
end

-- Helper timer
local function After(sec, func)
  local f = CreateFrame("Frame")
  local acc = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc >= sec then self:SetScript("OnUpdate", nil); func() end
  end)
end

function H.TriggerCriticalHPTest()
  -- Force show for test regardless of DB toggles
  if H.warnHP then H.warnHP:Show() end
  if H.critIcon then H.critIcon:Show() end
  PlayCriticalSound()
  After(2.0, function()
    if H.warnHP then H.warnHP:Hide() end
    if H.critIcon then H.critIcon:Hide() end
  end)
end

function H.TriggerEliteSkullTest()
  -- Force show for test regardless of DB toggles
    if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.levelElite) then
      if H.skull then H.skull:Hide() end
      if H.EliteAttentionText then H.EliteAttentionText:Hide() end
      if H.eliteTextFrame then H.eliteTextFrame:Hide() end
      if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
      return
    end
    if H.skull then H.skull:Show() end
    if H.EliteAttentionText then H.EliteAttentionText:Show() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  PlayEliteSound()
  After(2.0, function()
    if H.skull then H.skull:Hide() end
    if H.EliteAttentionText then H.EliteAttentionText:Hide() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
  end)
end

-- Simulate Time-to-Death bar activity for testing
function H.TriggerTTDTest()
  HardcoreHUDDB.spike = HardcoreHUDDB.spike or { enabled = true, window = 5, maxDisplay = 30, warnThreshold = 3 }
  HardcoreHUDDB.spike.enabled = true
  -- Populate synthetic HP samples that decrease over the configured window
  local now = GetTime()
  local win = HardcoreHUDDB.spike.window or 5
  local steps = 10
  local stepDt = win / steps
  local cur = UnitHealth("player") or 3000
  local dropPerStep = math.max(1, math.floor((cur * 0.05) / steps)) -- ~5% HP over window
  H._hpSamples = {}
  for i=steps,0,-1 do
    table.insert(H._hpSamples, { t = now - (i * stepDt), hp = cur - (steps - i) * dropPerStep })
  end
  if H.spikeFrame then H.spikeFrame:Show() end
  print("HardcoreHUD: TTD test (synthetic samples) triggered")
end

function H.CheckSkull()
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false) then return end
  if not UnitExists("target") then H.skull:Hide(); if H.EliteAttentionText then H.EliteAttentionText:Hide() end; if H.eliteTextFrame then H.eliteTextFrame:Hide() end; if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end; return end
  local lvl = UnitLevel("target") or 0
  local my = UnitLevel("player") or 0
  local classif = UnitClassification("target") or ""
  local elite = (classif == "elite" or classif == "rareelite" or classif == "worldboss")
  local high = (lvl >= my + 2)
  
  -- Don't show elite warning in groups (elite quests/dungeons are expected)
  local inGroup = IsInGroup and IsInGroup() or false
  if inGroup then
    H.skull:Hide()
    if H.EliteAttentionText then H.EliteAttentionText:Hide() end
    if H.eliteTextFrame then H.eliteTextFrame:Hide() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
    return
  end
  
  -- Neue Bedingung: nur bei feindlichen Zielen (neutral/freundlich ausgeblendet)
  local reaction = UnitReaction("player","target")
  local hostile = false
  if reaction then
    -- Reaktion 1-3 = feindlich, 4 = neutral, 5+ = freundlich
    hostile = (reaction <= 3)
  else
    hostile = UnitIsEnemy("player","target") and not UnitIsFriend("player","target")
  end
  -- We only show skull/icons here if elite/high; multi-aggro handled in combat log
  if (HardcoreHUDDB.warnings.levelElite and hostile and (elite or high)) then
    H.skull:Show()
    if H.eliteTextFrame then H.eliteTextFrame:Show() end
    if H.EliteAttentionText then H.EliteAttentionText:Show() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  else
    H.skull:Hide()
    -- Hide visuals only if multi-aggro not active
    if not H._multiAggroActive then
      if H.EliteAttentionText then H.EliteAttentionText:Hide() end
      if H.eliteTextFrame then H.eliteTextFrame:Hide() end
      if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
    end
  end
end

-- Multi-aggro warning (simple heuristic using combat log not implemented here; placeholder toggled by slash)
function H.ShowMultiAggroWarning()
  -- Reuse elite danger visuals with unified text
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.multiAggro) then return end
  local wasActive = H._multiAggroActive
  H._multiAggroActive = true
  if H.EliteAttentionText then H.EliteAttentionText:SetText("Attention Danger Attention") end
  if H.eliteTextFrame then H.eliteTextFrame:Show() end
  if H.EliteAttentionText then H.EliteAttentionText:Show() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  -- Optional debug output
  if HardcoreHUDDB.debugMultiAggro then
    local c=0; if type(H.attackers)=="table" then for _ in pairs(H.attackers) do c=c+1 end end
    print("HardcoreHUD: Multi-aggro active ("..c.." attackers)")
  end
  if not wasActive then
    PlayMultiAggroSound()
  end
end

local function HideMultiAggroVisuals()
  H._multiAggroActive = false
  -- If skull (elite/high) still active, keep visuals; else hide
  if H.skull and H.skull:IsShown() then return end
  if H.EliteAttentionText then H.EliteAttentionText:Hide() end
  if H.eliteTextFrame then H.eliteTextFrame:Hide() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
end

-- Multi-aggro detection
-- Use addon table for attacker tracking so all functions share the same reference
H.attackers = H.attackers or {}
local WINDOW = 8 -- seconds to keep attacker GUIDs (extend to reduce flicker)
local MULTI_UPDATE_INTERVAL = 0.5

local function prune(now)
  for guid, ts in pairs(H.attackers) do
    if now - ts > WINDOW then H.attackers[guid] = nil end
  end
end

-- Lightweight threat-based fallback: add target/focus if they are hostile and targeting the player
local function ThreatFallbackTouch()
  local function addIfAggro(unit)
    if not UnitExists(unit) then return end
    local reaction = UnitReaction("player", unit)
    local hostile = false
    if reaction then hostile = (reaction <= 3) else hostile = UnitIsEnemy("player", unit) and not UnitIsFriend("player", unit) end
    if not hostile then return end
    if UnitExists(unit.."target") and UnitIsUnit(unit.."target", "player") then
      local guid = UnitGUID(unit)
      if guid then H.attackers[guid] = GetTime() end
    end
  end
  addIfAggro("target")
  addIfAggro("focus")
  addIfAggro("mouseover")
  -- Group-aware scans: party member targets and player's pet target
  for i=1,4 do addIfAggro("party"..i.."target") end
  addIfAggro("pettarget")
end

-- React to unit target changes to keep attackers populated when swapping targets
function H.OnUnitTarget(unit)
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.multiAggro) then return end
  ThreatFallbackTouch()
  H.EvaluateMultiAggro()
end

-- Threat list changes (Wrath): refresh attackers when unit threat updates
function H.OnThreatListUpdate(unit)
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.multiAggro) then return end
  ThreatFallbackTouch()
  H.EvaluateMultiAggro()
end

-- WotLK 3.3.5 combat log layout differs from modern; we take only first 8 meaningful args.
function H.OnCombatLog(...)
  local timestamp, subevent, hideCaster,
        srcGUID, srcName, srcFlags, srcFlags2,
        dstGUID, dstName, dstFlags, dstFlags2,
        p12,p13,p14,p15,p16,p17,p18,p19,p20 = ...
  if not subevent or not dstGUID then return end
  local playerGUID = UnitGUID("player")
  local now = GetTime()
  local isPlayerTarget = (dstGUID == playerGUID)
  -- Multi-aggro attackers tracking (only when player is target and source not player)
  if isPlayerTarget and srcGUID and srcGUID ~= playerGUID then
    -- Treat any hostile interaction against the player as an "attacker touch" within WINDOW seconds.
    if subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT" or subevent == "ENVIRONMENTAL_DAMAGE"
    or subevent == "SWING_MISSED" or subevent == "RANGE_MISSED" or subevent == "SPELL_MISSED" or subevent == "DAMAGE_SHIELD_MISSED"
    or subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" or subevent == "SPELL_AURA_REMOVED_DOSE"
    or subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS" then
      H.attackers[srcGUID] = now; prune(now); if HardcoreHUDDB.debugMultiAggro then local c=0; for _ in pairs(H.attackers) do c=c+1 end print("HardcoreHUD: CL event="..subevent.." attackers="..c) end; H.EvaluateMultiAggro()
    end
  end
  -- Damage spike accumulation
  if HardcoreHUDDB.spike and HardcoreHUDDB.spike.enabled and isPlayerTarget then
    local amount
    if subevent == "SWING_DAMAGE" then
      amount = p12
    elseif subevent == "ENVIRONMENTAL_DAMAGE" then
      amount = p13
    elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT" then
      -- amount index = 15 (spellId, spellName, spellSchool, amount,...)
      amount = p15
    end
    if amount and type(amount) == "number" and amount > 0 then
      H._spikeEvents = H._spikeEvents or {}
      table.insert(H._spikeEvents, { t = now, a = amount })
      -- prune window
      local win = HardcoreHUDDB.spike.window or 5
      local cutoff = now - win
      local evs = H._spikeEvents
      local newIdx = 1
      for i=1,#evs do
        if evs[i].t >= cutoff then evs[newIdx] = evs[i]; newIdx = newIdx + 1 end
      end
      for i=newIdx,#evs do evs[i] = nil end
    end
  end
end

-- Manual test helper
function H.TriggerMultiAggroTest()
  -- Force show for test regardless of DB toggles
  H._multiAggroActive = true
  if H.EliteAttentionText then H.EliteAttentionText:SetText("Attention Danger Attention") end
  if H.eliteTextFrame then H.eliteTextFrame:Show() end
  if H.EliteAttentionText then H.EliteAttentionText:Show() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  PlayMultiAggroSound()
  After(4.0, function()
    H._multiAggroActive=false
    if H.skull and H.skull:IsShown() then return end
    if H.EliteAttentionText then H.EliteAttentionText:Hide() end
    if H.eliteTextFrame then H.eliteTextFrame:Hide() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
  end)
end

-- Central evaluation (can be called from combat log or periodic OnUpdate)
function H.EvaluateMultiAggro()
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.multiAggro) then return end
  local now = GetTime()
  prune(now)
  local count = 0
  for _ in pairs(H.attackers) do count = count + 1 end
  local threshold = HardcoreHUDDB.warnings.multiAggroThreshold or 2
  if count >= threshold then
    H.ShowMultiAggroWarning()
  elseif count < threshold and H._multiAggroActive then
    HideMultiAggroVisuals()
  end
  if HardcoreHUDDB.debugMultiAggro then
    print("HardcoreHUD: eval attackers="..count.." threshold="..threshold)
  end
end

-- Periodic updater frame (helps catch attackers dropping off without new damage events)
if not H.multiAggroUpdateFrame then
  local uf = CreateFrame("Frame")
  H.multiAggroUpdateFrame = uf
  local acc = 0
  uf:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc >= MULTI_UPDATE_INTERVAL then
      acc = 0
      if H._multiAggroActive or (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.multiAggro) then
        -- Keep attackers fresh even when combat log is quiet
        ThreatFallbackTouch()
        H.EvaluateMultiAggro()
      end
    end
  end)
end

-- Initialize leash state tracking
H._leashState = H._leashState or {
  targetGUID = nil,
  startPosition = nil,   -- {x, y} where combat started
  lastHitTime = 0,       -- Time of last damaging hit on target
  combatStartTime = 0,   -- When combat started (timer starts here)
  timerDuration = 12,    -- Leash timer resets to 12 seconds on hit
  active = false,
}

-- COMBAT_LOG hook for tracking hits and resetting timer
local function OnCombatLogEvent()
  -- Classic Era uses CombatLogGetCurrentEventInfo()
  local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
  
  -- Only track events where player hits their current target
  local playerGUID = UnitGUID("player")
  local targetGUID = UnitGUID("target")
  
  if not playerGUID or not targetGUID then return end
  if sourceGUID ~= playerGUID then return end
  if destGUID ~= targetGUID then return end
  
  -- Valid hit events that should reset the leash timer
  local validEvents = {
    SPELL_DAMAGE = true,
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,  -- DoTs count too for leash
    SPELL_BUILDING_DAMAGE = true,
  }
  
  if not validEvents[eventType] then return end
  
  -- Reset the leash timer on successful hit
  local now = GetTime()
  H._leashState.lastHitTime = now
  H._leashState.targetGUID = targetGUID
  
  -- Debug output
  if HardcoreHUDDB.debug then
    print(string.format("[HardcoreHUD] Leash timer reset: hit %s with %s", destName or "target", eventType))
  end
end

-- Register combat log event
local leashCombatLogFrame = CreateFrame("Frame")
leashCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
leashCombatLogFrame:SetScript("OnEvent", function(self, event)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLogEvent()
  end
end)

-- Reset leash state when target changes or combat ends
local leashResetFrame = CreateFrame("Frame")
leashResetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
leashResetFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
leashResetFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
leashResetFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- Combat started! Start the timer NOW
    local now = GetTime()
    H._leashState.active = true
    H._leashState.combatStartTime = now
    H._leashState.lastHitTime = now  -- Initialize to combat start
    H._leashState.targetGUID = UnitGUID("target")
    -- Store start position
    local px, py = UnitPosition("player")
    if px and py then
      H._leashState.startPosition = { x = px, y = py }
    end
    if HardcoreHUDDB.debug then
      print("[HardcoreHUD] Combat started - Leash timer started!")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Combat ended, reset everything
    H._leashState.active = false
    H._leashState.targetGUID = nil
    H._leashState.startPosition = nil
    H._leashState.lastHitTime = 0
    H._leashState.combatStartTime = 0
    if H.leashWarn then H.leashWarn:Hide() end
  elseif event == "PLAYER_TARGET_CHANGED" then
    -- New target, reset start position but keep timer running
    H._leashState.startPosition = nil
    H._leashState.targetGUID = UnitGUID("target")
    -- Get new start position from current location
    local px, py = UnitPosition("player")
    if px and py then
      H._leashState.startPosition = { x = px, y = py }
    end
  end
end)

function H.CheckLeashDistance()
  -- Don't interfere with test mode
  if H._leashTestMode then
    return
  end
  
  -- Initialize if not set
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  HardcoreHUDDB.warnings.leash = HardcoreHUDDB.warnings.leash or { enabled = true, distance = 50, sound = true }
  
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.leash and HardcoreHUDDB.warnings.leash.enabled) then
    if H.leashWarn then H.leashWarn:Hide() end
    return
  end

  -- Check if target exists and is hostile
  if not UnitExists("target") or not UnitCanAttack("player", "target") then
    if H.leashWarn then H.leashWarn:Hide() end
    return
  end

  -- Only show during combat
  if not InCombatLockdown() then
    if H.leashWarn then H.leashWarn:Hide() end
    return
  end

  -- Show leash tracking
  if H.leashWarn then
    H.leashWarn:Show()
    
    -- Get configured leash distance (default 50 yards)
    local maxLeashDist = HardcoreHUDDB.warnings.leash.distance or 50
    
    -- Calculate distance from start position (where combat/pull started)
    local currentDistance = 0
    local px, py = UnitPosition("player")
    if px and py and H._leashState.startPosition then
      local sx, sy = H._leashState.startPosition.x, H._leashState.startPosition.y
      local dx = px - sx
      local dy = py - sy
      currentDistance = math.sqrt(dx*dx + dy*dy)
    end
    
    -- Calculate time since last hit
    local now = GetTime()
    local timeSinceHit = now - (H._leashState.lastHitTime or now)
    local timerRemaining = math.max(0, H._leashState.timerDuration - timeSinceHit)
    
    -- If no hit recorded yet, show full timer
    if H._leashState.lastHitTime == 0 then
      timerRemaining = H._leashState.timerDuration
    end
    
    -- Update bar
    if H.leashWarn.bar then
      H.leashWarn.bar:SetMinMaxValues(0, maxLeashDist)
      H.leashWarn.bar:SetValue(math.min(currentDistance, maxLeashDist))
      
      -- Color based on danger level
      local distRatio = currentDistance / maxLeashDist
      local timeRatio = timerRemaining / H._leashState.timerDuration
      local danger = math.max(distRatio, 1 - timeRatio)  -- Whichever is more dangerous
      
      local r, g, b
      if danger < 0.5 then
        r, g, b = 0, 1, 0  -- Green: safe
      elseif danger < 0.8 then
        r, g, b = 1, 1, 0  -- Yellow: caution
      else
        r, g, b = 1, 0, 0  -- Red: danger
      end
      H.leashWarn.bar:SetStatusBarColor(r, g, b)
    end
    
    -- Update stats text: distance / max | timer
    if H.leashWarn.stats then
      local timerText
      if timerRemaining > 0 then
        timerText = string.format("%.1fs", timerRemaining)
      else
        timerText = "EXPIRED!"
      end
      H.leashWarn.stats:SetText(string.format("%.1f / %d yd  |  %s", currentDistance, maxLeashDist, timerText))
    end
    
    -- Play warning sound when timer is about to expire
    if timerRemaining <= 3 and timerRemaining > 0 and HardcoreHUDDB.warnings.leash.sound then
      -- Only play once per second
      if not H._leashSoundTime or (now - H._leashSoundTime) > 1 then
        H._leashSoundTime = now
        if PlaySoundFile then
          PlaySoundFile("Sound/Interface/RaidWarning.wav", "Master")
        end
      end
    end
  end
end

-- Show Leash Display in test mode for positioning
function H.ShowLeashTest()
  if not H.leashWarn then return end
  
  -- Set test mode flag
  H._leashTestMode = true
  
  H.leashWarn:Show()
  -- Show title when in test/unlock mode
  if H.leashWarn.title then H.leashWarn.title:Show() end
  -- Reposition bar below title when title is shown
  if H.leashWarn.bar then
    H.leashWarn.bar:ClearAllPoints()
    H.leashWarn.bar:SetPoint("TOP", H.leashWarn.title, "BOTTOM", 0, -8)
    H.leashWarn.bar:SetValue(65)
    H.leashWarn.bar:SetStatusBarColor(1, 0.5, 0, 1)
  end
  if H.leashWarn.stats then
    H.leashWarn.stats:SetText("20m / 31m | 8s")
  end
  
  -- Hide after 10 seconds
  if H._leashTestTimer then
    H._leashTestTimer:Cancel()
  end
  H._leashTestTimer = C_Timer.NewTimer(10, function()
    H._leashTestMode = false
    -- Hide title and reposition bar
    if H.leashWarn and H.leashWarn.title then H.leashWarn.title:Hide() end
    if H.leashWarn and H.leashWarn.bar then
      H.leashWarn.bar:ClearAllPoints()
      H.leashWarn.bar:SetPoint("TOP", H.leashWarn, "TOP", 0, -5)
    end
    if H.leashWarn and not HardcoreHUDDB.warnings.leash.locked then
      H.leashWarn:Hide()
    end
    H._leashTestTimer = nil
  end)
end

-- Hide Leash Display test mode
function H.HideLeashTest()
  if not H.leashWarn then return end
  
  -- Cancel timer if active
  if H._leashTestTimer then
    H._leashTestTimer:Cancel()
    H._leashTestTimer = nil
  end
  
  H._leashTestMode = false
  -- Hide title and reposition bar for normal mode
  if H.leashWarn.title then H.leashWarn.title:Hide() end
  if H.leashWarn.bar then
    H.leashWarn.bar:ClearAllPoints()
    H.leashWarn.bar:SetPoint("TOP", H.leashWarn, "TOP", 0, -5)
  end
  H.leashWarn:Hide()
end

-- Show Range Display in test mode for positioning
function H.ShowRangeDisplayTest()
  if not H.rangeDisplay then return end
  H.rangeDisplay:Show()
  if H.rangeDisplay.text then
    H.rangeDisplay.text:SetText("25.0 yd")
    H.rangeDisplay.text:SetTextColor(1, 0.8, 0)  -- Orange
  end
end

-- Hide Range Display test mode
function H.HideRangeDisplayTest()
  if not H.rangeDisplay then return end
  if not H._debugRangeDisplay then
    H.rangeDisplay:Hide()
  end
end

-- Range Display updater (simple distance display to target)
function H.CheckRangeDisplay()
  if not H.rangeDisplay then
    return
  end
  
  -- ALWAYS enable range display by default (override old saved vars)
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  HardcoreHUDDB.warnings.rangeDisplay = HardcoreHUDDB.warnings.rangeDisplay or { enabled = true }
  HardcoreHUDDB.warnings.rangeDisplay.enabled = true  -- Force enabled
  
  -- Debug mode: show real distance
  if H._debugRangeDisplay then
    H.rangeDisplay:Show()
    if not UnitExists("target") then
      if H.rangeDisplay.text then
        H.rangeDisplay.text:SetText("No Target")
      end
      return
    end
    
    local distance = H.GetDistanceToTarget()
    if not distance then
      if H.rangeDisplay.text then
        H.rangeDisplay.text:SetText("Range: N/A")
      end
      return
    end
    
    if H.rangeDisplay.text then
      H.rangeDisplay.text:SetText(string.format("%.1f yd", distance))
      -- Color coding: <20y green, 20-30y orange, 30+y red
      if distance < 20 then
        H.rangeDisplay.text:SetTextColor(0.2, 1, 0.2)  -- Green
      elseif distance <= 30 then
        H.rangeDisplay.text:SetTextColor(1, 0.8, 0)    -- Orange
      else
        H.rangeDisplay.text:SetTextColor(1, 0.2, 0.2)  -- Red
      end
    end
    return
  end
  
  -- Normal mode: only show when enabled
  if not UnitExists("target") then
    H.rangeDisplay:Hide()
    return
  end
  
  local distance = H.GetDistanceToTarget()
  if not distance then
    H.rangeDisplay:Hide()
    return
  end
  
  -- Show range
  H.rangeDisplay:Show()
  if H.rangeDisplay.text then
    H.rangeDisplay.text:SetText(string.format("%.1f yd", distance))
    -- Color coding per requirements: <20y green, 20-30y orange, 30+y red
    if distance < 20 then
      H.rangeDisplay.text:SetTextColor(0.2, 1, 0.2)  -- Green: under 20yd
    elseif distance <= 30 then
      H.rangeDisplay.text:SetTextColor(1, 0.8, 0)    -- Orange: 20-30yd
    else
      H.rangeDisplay.text:SetTextColor(1, 0.2, 0.2)  -- Red: over 30yd
    end
  end
end

-- Get distance to target using LibRangeCheck-3.0
function H.GetDistanceToTarget()
  if not rc or not UnitExists("target") then return nil end
  
  local minRange, maxRange = rc:GetRange("target")
  
  if not minRange then return nil end
  
  -- Return the minimum range (actual distance)
  return minRange
end

-- Leash distance periodic updater
if not H._leashUpdateFrame then
  local lf = CreateFrame("Frame")
  H._leashUpdateFrame = lf
  local acc = 0
  lf:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc >= 0.25 then  -- Check 4 times per second
      acc = 0
      H.CheckLeashDistance()
      H.CheckRangeDisplay()
      H.CheckDangerousDebuffs()
    end
  end)
end

-- GTFO System (Get The F* Out - AoE/Danger warnings)
function H.InitGTFO()
  if H._gtfoInit then return end
  H._gtfoInit = true
  
  HardcoreHUDDB.gtfo = HardcoreHUDDB.gtfo or {
    enabled = true,
    highDamage = true,
    lowDamage = true,
    fallAlert = true,
    volume = 1.0,
    lastAlert = 0
  }
  
  -- Dangerous debuff types that indicate AoE/Environment damage
  H._dangerousDebuffs = {
    -- Fire/Burn effects
    ["Burning"] = "high",
    ["Immolate"] = "high",
    ["Rend"] = "high",
    ["Incinerate"] = "high",
    
    -- Poison effects
    ["Poison"] = "medium",
    ["Deadly Poison"] = "high",
    ["Crippling Poison"] = "medium",
    ["Wound Poison"] = "medium",
    
    -- Curse effects
    ["Curse of Weakness"] = "low",
    ["Curse of Elements"] = "low",
    ["Curse of Recklessness"] = "high",
    
    -- Disease effects
    ["Plague"] = "medium",
    ["Black Plague"] = "high",
    ["Cripple"] = "medium",
    
    -- Other dangerous effects
    ["Corruption"] = "medium",
    ["Fear"] = "high",
    ["Frost Armor"] = "low",
    ["Slow"] = "low",
    ["Bleed"] = "medium",
  }
  
  -- Track last alert time to prevent spam
  H._lastGTFOAlert = 0
end

function H.CheckDangerousDebuffs()
  if not (HardcoreHUDDB.gtfo and HardcoreHUDDB.gtfo.enabled) then return end
  
  -- Ensure initialization (fallback in case InitGTFO hasn't been called yet)
  if not H._lastGTFOAlert then H._lastGTFOAlert = 0 end
  if not H._dangerousDebuffs then H.InitGTFO() end
  
  local now = GetTime()
  if now - H._lastGTFOAlert < 0.5 then return end  -- Limit alerts to max 2/sec
  
  -- Check player debuffs
  local i = 1
  while true do
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId = UnitDebuff("player", i)
    if not name then break end
    
    local alertType = H._dangerousDebuffs[name]
    
    if alertType then
      -- Check if we should alert based on type
      local shouldAlert = false
      
      if alertType == "high" and HardcoreHUDDB.gtfo.highDamage then
        shouldAlert = true
      elseif (alertType == "medium" or alertType == "low") and HardcoreHUDDB.gtfo.lowDamage then
        shouldAlert = true
      end
      
      if shouldAlert then
        H.TriggerGTFOAlert(name, alertType)
        H._lastGTFOAlert = now
        return
      end
    end
    
    i = i + 1
  end
  
  -- Check for breath/fatigue warnings (drowning, fatigue zone)
  if HardcoreHUDDB.gtfo.fallAlert then
    for idx = 1, (MIRRORTIMER_NUMTIMERS or 3) do
      local timerName, timerValue, timerMax = GetMirrorTimerInfo(idx)
      if timerName and timerName ~= "" and timerName ~= "UNKNOWN" and timerValue and timerValue > 0 then
        if timerName == "BREATH" then
          H.TriggerGTFOAlert("DROWNING!", "fall")
          H._lastGTFOAlert = now
          break
        elseif timerName == "EXHAUSTION" then
          H.TriggerGTFOAlert("FATIGUE!", "fall")
          H._lastGTFOAlert = now
          break
        end
        -- Ignore FEIGNDEATH timer
      end
    end
  end
end

function H.TriggerGTFOAlert(debuffName, alertType)
  local volume = HardcoreHUDDB.gtfo.volume or 1.0
  
  -- Don't alert if volume is muted
  if volume <= 0 then return end
  
  -- Play different sounds based on alert type
  local soundFile
  if alertType == "high" or alertType == "fall" then
    -- High priority / Raid damage sound
    soundFile = "Sound\\Interface\\RaidWarning.wav"
  else
    -- Low priority / Environment damage sound
    soundFile = "Sound\\Interface\\Ignored_Alert.wav"
  end
  
  if soundFile then
    -- Note: WoW Classic PlaySoundFile doesn't support volume parameter
    -- Volume can be adjusted via Master channel or game settings
    PlaySoundFile(soundFile, "Master")
  end
  
  -- Visual feedback
  if H.gtfoFrame then
    H.gtfoFrame:Show()
    if H.gtfoFrame.text then
      H.gtfoFrame.text:SetText("GET OUT: " .. debuffName)
    end
  end
end

function H.BuildGTFOFrame()
  if H.gtfoFrame then return end
  
  local f = CreateFrame("Frame", nil, UIParent)
  H.gtfoFrame = f
  f:SetSize(320, 70)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:Hide()
  
  -- Dark semi-transparent background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0, 0, 0, 0.75)
  f.bg = bg
  
  -- Red glow border (inner)
  local glowSize = 4
  local glow = {}
  -- Top
  glow[1] = f:CreateTexture(nil, "BORDER")
  glow[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  glow[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  glow[1]:SetHeight(glowSize)
  glow[1]:SetColorTexture(0.9, 0.1, 0.1, 0.9)
  -- Bottom
  glow[2] = f:CreateTexture(nil, "BORDER")
  glow[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  glow[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  glow[2]:SetHeight(glowSize)
  glow[2]:SetColorTexture(0.9, 0.1, 0.1, 0.9)
  -- Left
  glow[3] = f:CreateTexture(nil, "BORDER")
  glow[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  glow[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  glow[3]:SetWidth(glowSize)
  glow[3]:SetColorTexture(0.9, 0.1, 0.1, 0.9)
  -- Right
  glow[4] = f:CreateTexture(nil, "BORDER")
  glow[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  glow[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  glow[4]:SetWidth(glowSize)
  glow[4]:SetColorTexture(0.9, 0.1, 0.1, 0.9)
  f.glow = glow
  
  -- Warning text
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", f, "CENTER", 0, 0)
  text:SetText("GET OUT!")
  text:SetTextColor(1, 0.2, 0.2, 1)
  if STANDARD_TEXT_FONT then text:SetFont(STANDARD_TEXT_FONT, 32, "OUTLINE") end
  text:SetShadowColor(0, 0, 0, 1)
  text:SetShadowOffset(2, -2)
  f.text = text
  
  -- Pulse animation (border glow pulsing)
  f._pulseAcc = 0
  f:SetScript("OnUpdate", function(self, dt)
    if not self:IsShown() then return end
    self._pulseAcc = (self._pulseAcc or 0) + dt
    
    -- Pulse the red border glow
    local pulse = 0.6 + 0.4 * math.sin(self._pulseAcc * 8)
    for _, g in ipairs(self.glow) do
      g:SetAlpha(pulse)
    end
    
    -- Subtle text pulse
    local textPulse = 0.85 + 0.15 * math.sin(self._pulseAcc * 8)
    self.text:SetAlpha(textPulse)
    
    -- Auto-hide after 2 seconds
    if self._pulseAcc > 2 then
      self:Hide()
      self._pulseAcc = 0
    end
  end)
end

function H.TestGTFOAlert(alertType)
  if not H.gtfoFrame then H.BuildGTFOFrame() end
  
  if alertType == "high" then
    H.TriggerGTFOAlert("TEST: HIGH DAMAGE", "high")
  elseif alertType == "low" then
    H.TriggerGTFOAlert("TEST: LOW DAMAGE", "low")
  elseif alertType == "fall" or alertType == "drown" then
    H.TriggerGTFOAlert("TEST: DROWNING", "fall")
  elseif alertType == "fatigue" then
    H.TriggerGTFOAlert("TEST: FATIGUE", "fall")
  end
end
