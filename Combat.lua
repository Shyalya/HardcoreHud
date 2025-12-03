local H = HardcoreHUD

-- Critical HP warning
function H.BuildWarnings()
  local w = CreateFrame("Frame", nil, UIParent)
  H.warnHP = w
  w:SetSize(260, 60)
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
  ci:Hide()

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
  -- Center the trio and add spacing above the text
  local offsets = { -80, 0, 80 }
  for i=1,3 do
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(72, 72)
    icon:SetPoint("CENTER", UIParent, "CENTER", offsets[i], 230)
    icon:SetFrameStrata("FULLSCREEN_DIALOG")
    local texI = icon:CreateTexture(nil, "ARTWORK")
    texI:SetAllPoints(icon)
    texI:SetTexture("Interface/Icons/Ability_Rogue_FeignDeath")
    icon:Hide()
    H.eliteIcons[i] = icon
  end

  -- Unified danger text (elite or multi-aggro)
  local eliteText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  eliteText:SetText("Attention Danger Attention")
  eliteText:SetTextColor(1, 0.9, 0.2, 1)
  eliteText:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  eliteText:SetDrawLayer("OVERLAY")
  eliteText:Hide()
  H.EliteAttentionText = eliteText

  -- Damage spike / Time-to-Death bar
  HardcoreHUDDB.spike = HardcoreHUDDB.spike or { enabled = true, window = 5, maxDisplay = 10, warnThreshold = 3 }
  local spike = CreateFrame("StatusBar", nil, UIParent)
  spike:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  spike:SetSize(140, 10)
  spike:SetMinMaxValues(0, HardcoreHUDDB.spike.maxDisplay or 10)
  spike:SetValue(0)
  spike:SetPoint("TOP", UIParent, "TOP", 0, -120)
  spike:Hide()
  local sbg = spike:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints(spike)
  sbg:SetColorTexture(0,0,0,0.55)
  local stxt = spike:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  stxt:SetPoint("CENTER", spike, "CENTER")
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

function H.ShowCriticalHPWarning()
  if HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.criticalHP then
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
  H.warnHP:Hide()
  if H.critIcon then H.critIcon:Hide() end
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
if not H._spikeDriver then
  local drv = CreateFrame("Frame")
  H._spikeDriver = drv
  local accum = 0
  drv:SetScript("OnUpdate", function(_, dt)
    accum = accum + dt
    if accum < 0.2 then return end
    accum = 0
    local cfg = HardcoreHUDDB.spike
    if not (cfg and cfg.enabled) then if H.spikeFrame then H.spikeFrame:Hide() end return end
    if not H._spikeEvents or #H._spikeEvents == 0 then if H.spikeFrame then H.spikeFrame:Hide() end return end
    local win = cfg.window or 5
    local now = GetTime()
    local cutoff = now - win
    local total = 0
    for _,ev in ipairs(H._spikeEvents) do if ev.t >= cutoff then total = total + ev.a end end
    if total <= 0 then H.spikeFrame:Hide(); return end
    local dps = total / win
    local curHP = UnitHealth("player") or 0
    local ttd = dps > 0 and (curHP / dps) or cfg.maxDisplay or 10
    local maxDisp = cfg.maxDisplay or 10
    if ttd > maxDisp then ttd = maxDisp end
    local f = H.spikeFrame
    f:SetMinMaxValues(0, maxDisp)
    f:SetValue(ttd)
    -- Color: green >8, yellow >5, orange >3, red <=3
    local r,g,b
    if ttd > 8 then r,g,b = 0,1,0
    elseif ttd > 5 then r,g,b = 1,1,0
    elseif ttd > (cfg.warnThreshold or 3) then r,g,b = 1,0.5,0
    else r,g,b = 1,0.15,0 end
    f:SetStatusBarColor(r,g,b)
    f.text:SetText(string.format("TTD: %.1fs", ttd))
    f:Show()
    -- Pulse when critical (<= warnThreshold)
    if ttd <= (cfg.warnThreshold or 3) then
      f.pulseAcc = f.pulseAcc + dt
      local alpha = 0.55 + 0.45 * math.abs(math.sin(f.pulseAcc*6))
      f:SetAlpha(alpha)
    else
      f.pulseAcc = 0
      f:SetAlpha(1)
    end
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

function H.CheckSkull()
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false) then return end
  if not UnitExists("target") then H.skull:Hide(); if H.EliteAttentionText then H.EliteAttentionText:Hide() end; if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end; return end
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
    if H.EliteAttentionText then H.EliteAttentionText:Show() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  else
    H.skull:Hide()
    -- Hide visuals only if multi-aggro not active
    if not H._multiAggroActive then
      if H.EliteAttentionText then H.EliteAttentionText:Hide() end
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
  if H.EliteAttentionText then H.EliteAttentionText:SetText("Attention Danger Attention"); H.EliteAttentionText:Show() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  -- Optional debug output
  if HardcoreHUDDB.debugMultiAggro then
    local c=0; if type(attackers)=="table" then for _ in pairs(attackers) do c=c+1 end end
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
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
end

-- Multi-aggro detection
local attackers = {}
local WINDOW = 5 -- seconds to keep attacker GUIDs
local MULTI_UPDATE_INTERVAL = 0.5

local function prune(now)
  for guid, ts in pairs(attackers) do
    if now - ts > WINDOW then attackers[guid] = nil end
  end
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
      attackers[srcGUID] = now; prune(now); if HardcoreHUDDB.debugMultiAggro then local c=0; for _ in pairs(attackers) do c=c+1 end print("HardcoreHUD: CL event="..subevent.." attackers="..c) end; H.EvaluateMultiAggro()
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
  if H.EliteAttentionText then H.EliteAttentionText:SetText("Attention Danger Attention"); H.EliteAttentionText:Show() end
  if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Show() end end
  PlayMultiAggroSound()
  After(4.0, function()
    H._multiAggroActive=false
    if H.skull and H.skull:IsShown() then return end
    if H.EliteAttentionText then H.EliteAttentionText:Hide() end
    if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
  end)
end

-- Central evaluation (can be called from combat log or periodic OnUpdate)
function H.EvaluateMultiAggro()
  if not (HardcoreHUDDB.warnings and HardcoreHUDDB.warnings.enabled ~= false and HardcoreHUDDB.warnings.multiAggro) then return end
  local now = GetTime()
  prune(now)
  local count = 0
  for _ in pairs(attackers) do count = count + 1 end
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
        H.EvaluateMultiAggro()
      end
    end
  end)
end
