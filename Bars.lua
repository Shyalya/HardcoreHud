local H = HardcoreHUD

local FIVE = 5
local ENERGY_TICK = 2
local MANA_TICK = 2

local bars = {}
H.bars = bars

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
      local p,_,rp,x,y = H.root:GetPoint()
      HardcoreHUDDB.pos = { x=x, y=y }
    end
  end)
end

local function border(frame)
  frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=3,right=3,top=3,bottom=3} })
  frame:SetBackdropColor(0,0,0,0.5)
  frame:SetBackdropBorderColor(0.6,0.6,0.6,1)
end

local function getBarTexture()
  return "Interface/TargetingFrame/UI-StatusBar"
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

  -- Left: HP bar (vertical)
  local hp = CreateFrame("StatusBar", nil, root)
  bars.hp = hp
  hp:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
  hp:SetMinMaxValues(0, UnitHealthMax("player"))
  hp:SetValue(UnitHealth("player"))
  hp:SetOrientation("VERTICAL")
  hp:SetSize(barThickness, barHeight)
  hp:SetPoint("RIGHT", root, "CENTER", -separation, 0)
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
  local powText = pow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bars.powText = powText
  powText:SetPoint("TOP", pow, "BOTTOM", 0, -18)
  powText:SetJustifyH("CENTER")

  -- Overlays on power bar: five-second (top-down) and tick (bottom-up)
  local fsFill = pow:CreateTexture(nil, "OVERLAY")
  bars.fsFill = fsFill
  local fsAlpha = (HardcoreHUDDB.ticker and HardcoreHUDDB.ticker.fsOpacity) or 0.25
  fsFill:SetColorTexture(HardcoreHUDDB.colors.fiveSec[1], HardcoreHUDDB.colors.fiveSec[2], HardcoreHUDDB.colors.fiveSec[3], fsAlpha)
  if fsFill.SetBlendMode then fsFill:SetBlendMode("ADD") end
  fsFill:ClearAllPoints()
  fsFill:SetPoint("TOPLEFT", pow, "TOPLEFT")
  fsFill:SetPoint("TOPRIGHT", pow, "TOPRIGHT")
  fsFill:SetHeight(0)
  fsFill:Hide()

  local tickLine = pow:CreateTexture(nil, "OVERLAY")
  bars.tickFill = tickLine
  tickLine:SetColorTexture(HardcoreHUDDB.colors.tick[1], HardcoreHUDDB.colors.tick[2], HardcoreHUDDB.colors.tick[3], 1.0)
  tickLine:ClearAllPoints()
  tickLine:SetPoint("BOTTOM", pow, "BOTTOM", 0, 0)
  tickLine:SetSize(pow:GetWidth(), 2)

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
  thp:SetPoint("LEFT", root, "CENTER", separation, 0)
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
  local spells = {}
  local class = select(2, UnitClass("player"))
  -- Avoid duplicates: Rogue CDs are provided by Utilities.lua; skip here
  if class == "ROGUE" then spells = { } -- handled by Utilities
  elseif class == "DRUID" then spells = { 1850, 22812 } -- Dash, Barkskin
  elseif class == "WARRIOR" then spells = { 871, 1719 } -- Shield Wall, Recklessness
  elseif class == "MAGE" then spells = { 45438, 120 } -- Ice Block, Cone of Cold placeholder
  end
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
  bars.hp:SetSize(t, bh)
  bars.hp:ClearAllPoints(); bars.hp:SetPoint("RIGHT", H.root, "CENTER", -sep, 0)
  bars.pow:SetSize(t, bh)
  bars.pow:ClearAllPoints(); bars.pow:SetPoint("LEFT", bars.hp, "RIGHT", gap, 0)
  bars.targetHP:SetSize(t, bh)
  bars.targetHP:ClearAllPoints(); bars.targetHP:SetPoint("LEFT", H.root, "CENTER", sep, 0)
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
  local pType = UnitPowerType("player")
  local r,g,b
  if pType == 0 then r,g,b = unpack(HardcoreHUDDB.colors.mana)
  elseif pType == 1 then r,g,b = unpack(HardcoreHUDDB.colors.rage)
  elseif pType == 3 then r,g,b = unpack(HardcoreHUDDB.colors.energy)
  else r,g,b = 0.7,0.7,0.7 end
  bars.pow:SetStatusBarColor(r,g,b)
  local hr,hg,hb = unpack(HardcoreHUDDB.colors.hp)
  bars.hp:SetStatusBarColor(hr,hg,hb)
  bars.tick:SetStatusBarColor(unpack(HardcoreHUDDB.colors.tick))
end

function H.UpdatePower()
  local pType = UnitPowerType("player")
  local cur, max
  if pType == 0 then
    cur = UnitMana("player"); max = UnitManaMax("player")
  elseif pType == 1 then
    cur = UnitPower("player",1); max = UnitPowerMax("player",1)
  elseif pType == 3 then
      cur = UnitPower("player",3); max = UnitPowerMax("player",3)
  else
    -- fallback for other types
    cur = UnitPower("player") or 0; max = UnitPowerMax("player") or 100
  end
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
    if inFive then bars.fsFill:Show() else bars.fsFill:Hide() end
    if cur == UnitPowerMax("player",0) then manaPaused=true; haveManaCycle=false; if bars.tickFill then bars.tickFill:SetHeight(0) end end
  elseif pType == 3 then
    -- switching to energy: clear mana state and show tick overlay
    bars.fsFill:Hide()
    manaPaused = true; haveManaCycle = false
    if bars.tickFill then bars.tickFill:Show() end
  else
    bars.fsFill:Hide(); if bars.tickFill then bars.tickFill:SetHeight(0) end
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
    local tcurPow, tmaxPow
    if tpType == 0 then
      tcurPow = UnitMana("target"); tmaxPow = UnitManaMax("target")
    elseif tpType == 1 then
      tcurPow = UnitPower("target",1); tmaxPow = UnitPowerMax("target",1)
    elseif tpType == 3 then
      tcurPow = UnitPower("target",3); tmaxPow = UnitPowerMax("target",3)
    else
      tcurPow = UnitPower("target") or 0; tmaxPow = UnitPowerMax("target") or 100
    end
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
  -- combo points
  local class = select(2, UnitClass("player"))
  local pType = UnitPowerType("player")
  local isCat = class == "DRUID" and pType == 3
  local show = class == "ROGUE" or isCat
  if show then
    local cp = GetComboPoints("player", "target") or 0
    for i=1,5 do
      local t = bars.comboIcons[i]
      t:Show()
      if cp>0 and i<=cp then
        local ratio = (i-1)/4
        t:SetColorTexture(1 - ratio, ratio, 0, 1)
      else
        t:SetColorTexture(0.35,0.35,0.35,0.7)
      end
    end
  else
    for i=1,5 do bars.comboIcons[i]:Hide() end
  end
  -- skull warning (guard if Combat.lua not yet loaded)
  if H.CheckSkull then H.CheckSkull() end

  -- target bars
  if UnitExists("target") and bars.targetHP and bars.targetPow then
    bars.targetHP:Show(); bars.targetPow:Show(); bars.targetHP:SetAlpha(1); bars.targetPow:SetAlpha(1)
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
    local tcurPow, tmaxPow
    if tpType == 0 then
      tcurPow = UnitMana("target"); tmaxPow = UnitManaMax("target")
    elseif tpType == 1 then
      tcurPow = UnitPower("target",1); tmaxPow = UnitPowerMax("target",1)
    elseif tpType == 3 then
        tcurPow = UnitPower("target",3); tmaxPow = UnitPowerMax("target",3)
    else
      tcurPow = UnitPower("target") or 0; tmaxPow = UnitPowerMax("target") or 100
    end
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
    if bars.targetHP then bars.targetHP:Hide() end
    if bars.targetPow then bars.targetPow:Hide() end
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
    local cur, max
    if pType == 0 then
      cur = UnitMana("player"); max = UnitManaMax("player")
    elseif pType == 1 then
      cur = UnitPower("player",1); max = UnitPowerMax("player",1)
    elseif pType == 3 then
      cur = UnitPower("player",3); max = UnitPowerMax("player",3)
    else
      cur = UnitPower("player") or 0; max = UnitPowerMax("player") or 100
    end
    if bars.pow then
      bars.pow:SetMinMaxValues(0, max or 1)
      bars.pow:SetValue(cur or 0)
      if bars.powText then bars.powText:SetText((cur or 0).."/"..(max or 0)) end
    end
  end
  local curMana = UnitPower("player",0)
  local maxMana = UnitPowerMax("player",0)
  -- five second rule
  if pType == 0 and inFive then
    local rem = FIVE - (now - lastManaCast)
    if rem <= 0 then inFive=false; bars.fsFill:Hide(); manaPaused = (curMana==maxMana); haveManaCycle=false else
      local h = H.bars.pow:GetHeight() * (rem / FIVE)
      bars.fsFill:SetHeight(h)
      bars.fsFill:Show()
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
      if bars.tickFill then bars.tickFill:ClearAllPoints(); bars.tickFill:SetPoint("BOTTOM", H.bars.pow, "BOTTOM", 0, y) end
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
    if bars.tickFill then bars.tickFill:ClearAllPoints(); bars.tickFill:SetPoint("BOTTOM", H.bars.pow, "BOTTOM", 0, y) end
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
            info.btn._pulseBorder:Show()
          else
            if info.btn._pulseBorder then info.btn._pulseBorder:Hide() end
          end
        else
          if info.btn._pulseBorder then info.btn._pulseBorder:Hide() end
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
