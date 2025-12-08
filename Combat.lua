local H = HardcoreHUD

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
