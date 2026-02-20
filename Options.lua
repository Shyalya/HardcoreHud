local H = HardcoreHUD

function H.BuildOptions()
  -- Options GUI
  local f = CreateFrame("Frame", "HardcoreHUDOptions", UIParent)
  H.optionsFrame = f
  -- Ensure options window draws above all HUD elements and absorbs clicks
  if f.SetFrameStrata then f:SetFrameStrata("FULLSCREEN_DIALOG") end
  f:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 100)
  -- Ensure warnings table defaults exist so tests work out-of-the-box
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  if HardcoreHUDDB.warnings.enabled == nil then HardcoreHUDDB.warnings.enabled = true end
  if HardcoreHUDDB.warnings.criticalHP == nil then HardcoreHUDDB.warnings.criticalHP = true end
  if HardcoreHUDDB.warnings.levelElite == nil then HardcoreHUDDB.warnings.levelElite = true end
  if HardcoreHUDDB.warnings.multiAggro == nil then HardcoreHUDDB.warnings.multiAggro = true end
  f:SetSize(860, 520)
  f:SetPoint("CENTER")
  H.SafeBackdrop(f, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} }, 0,0,0,0.8)
  f:Hide()
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("HardcoreHUD Options")

  -- Tabbed sub-menu: sidebar buttons + content panels
  local sidebar = CreateFrame("Frame", nil, f)
  sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  sidebar:SetSize(170, f:GetHeight()-96)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 60)

  local function makeTabButton(name, text, y)
    local b = CreateFrame("Button", name, sidebar, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -y)
    b:SetSize(160, 24)
    b:SetText(text)
    return b
  end

  local btnLayout   = makeTabButton("HardcoreHUDTabLayout", "Layout", 0)
  local btnWarnings = makeTabButton("HardcoreHUDTabWarnings", "Warnings", 32)
  local btnRemind   = makeTabButton("HardcoreHUDTabReminders", "Reminders", 64)
  local btnAdvanced = makeTabButton("HardcoreHUDTabAdvanced", "Advanced", 96)
  local btnUtilities = makeTabButton("HardcoreHUDTabUtilities", "Utilities", 128)
  local btnTargetMarks = makeTabButton("HardcoreHUDTabTargetMarks", "Target Marks", 160)
  local btnLeveling = makeTabButton("HardcoreHUDTabLeveling", "Leveling", 192)
  local btnReputation = makeTabButton("HardcoreHUDTabReputation", "Reputation", 224)

  local function makePanel()
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints(content)
    p:Hide()
    return p
  end

  -- Safe checkbutton factory: try to create with provided template, fallback to a simple styled CheckButton
  local function SafeCheckButton(name, parent, template)
    if not name or not parent then return CreateFrame("CheckButton", nil, parent) end
    local ok, btn = pcall(CreateFrame, "CheckButton", name, parent, template)
    if ok and btn then return btn end
    local b = CreateFrame("CheckButton", name, parent)
    b:SetSize(20,20)
    if b.SetFrameStrata then b:SetFrameStrata("HIGH") end
    -- Use Blizzard checkbox textures when available
    if b.SetNormalTexture then b:SetNormalTexture("Interface/Buttons/UI-CheckBox-Up") end
    if b.SetPushedTexture then b:SetPushedTexture("Interface/Buttons/UI-CheckBox-Down") end
    if b.SetHighlightTexture then b:SetHighlightTexture("Interface/Buttons/UI-CheckBox-Highlight") end
    if b.SetCheckedTexture then 
      local tex = b:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
      -- Ensure the checked texture is created and can be shown/hidden
      if tex and tex.SetTexture then
        tex:SetTexture("Interface/Buttons/UI-CheckBox-Check")
      end
    end
    -- Override SetChecked to ensure texture visibility is updated
    local originalSetChecked = b.SetChecked
    b.SetChecked = function(self, checked)
      if originalSetChecked then originalSetChecked(self, checked) end
      local checkedTex = self:GetCheckedTexture()
      if checkedTex then
        if checked then
          checkedTex:Show()
        else
          checkedTex:Hide()
        end
      end
    end
    -- Create a named FontString to mimic the usual template behavior
    local txtName = name.."Text"
    if not _G[txtName] then
      -- Create a small invisible clickable label button to emulate template behavior
      local lbl = CreateFrame("Button", txtName.."Click", b)
      lbl:SetSize(220, 20)
      lbl:SetPoint("LEFT", b, "RIGHT", 6, 0)
      -- Ensure label sits above parent backdrop: use high strata and level
      pcall(function()
        if lbl.SetFrameStrata then lbl:SetFrameStrata("FULLSCREEN_DIALOG") end
        local baseLevel = (b.GetFrameLevel and b.GetFrameLevel(b)) or 0
        if lbl.SetFrameLevel then lbl:SetFrameLevel(baseLevel + 50) end
      end)
      lbl:EnableMouse(true)
      -- Ensure keyboard input is not blocked by checkbox labels
      if lbl.EnableKeyboard then lbl:EnableKeyboard(false) end
      if lbl.SetPropagateKeyboardInput then lbl:SetPropagateKeyboardInput(true) end
      local fs = lbl:CreateFontString(txtName, "ARTWORK", "GameFontNormal")
      fs:SetPoint("LEFT", lbl, "LEFT", 0, 0)
      fs:SetJustifyH("LEFT")
      lbl:SetScript("OnClick", function() pcall(function() b:Click() end) end)
    end
    return b
  end

  local panelLayout   = makePanel()
  local panelWarnings = makePanel()
  local panelRemind   = makePanel()
  local panelAdvanced = makePanel()
  local panelUtilities = makePanel()
  local panelTargetMarks = makePanel()
  local panelLeveling = makePanel()
  local panelReputation = makePanel()

  -- Advanced panel: create two column containers to avoid overflow
  local advLeft = CreateFrame("Frame", nil, panelAdvanced)
  advLeft:SetPoint("TOPLEFT", panelAdvanced, "TOPLEFT", 0, 0)
  advLeft:SetPoint("BOTTOM", panelAdvanced, "BOTTOM", 0, 0)
  advLeft:SetWidth(math.floor((content:GetWidth() or 680) / 2) - 12)

  local advRight = CreateFrame("Frame", nil, panelAdvanced)
  advRight:SetPoint("TOPLEFT", advLeft, "TOPRIGHT", 24, 0)
  advRight:SetPoint("BOTTOMRIGHT", panelAdvanced, "BOTTOMRIGHT", 0, 0)

  local function showPanel(p)
    panelLayout:Hide(); panelWarnings:Hide(); panelRemind:Hide(); panelAdvanced:Hide(); panelUtilities:Hide(); panelTargetMarks:Hide(); panelLeveling:Hide(); panelReputation:Hide()
    p:Show()
  end
  btnLayout:SetScript("OnClick", function() showPanel(panelLayout) end)
  btnWarnings:SetScript("OnClick", function() showPanel(panelWarnings) end)
  btnRemind:SetScript("OnClick", function() showPanel(panelRemind) end)
  btnAdvanced:SetScript("OnClick", function() showPanel(panelAdvanced) end)
  btnUtilities:SetScript("OnClick", function() showPanel(panelUtilities) end)
  btnTargetMarks:SetScript("OnClick", function() showPanel(panelTargetMarks) end)
  btnLeveling:SetScript("OnClick", function() showPanel(panelLeveling) end)
  btnReputation:SetScript("OnClick", function() showPanel(panelReputation) end)
  showPanel(panelLayout)
  
  -- Hide range display test when options frame closes
  f:SetScript("OnHide", function()
    if H.HideRangeDisplayTest then H.HideRangeDisplayTest() end
  end)

  -- Thickness slider (left column)
  -- Layout panel controls
  local thickness = CreateFrame("Slider", "HardcoreHUDThicknessSlider", panelLayout, "OptionsSliderTemplate")
  thickness:SetPoint("TOPLEFT", panelLayout, "TOPLEFT", 20, -8)
  thickness:SetMinMaxValues(6, 32)
  thickness:SetValueStep(1)
  thickness:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.thickness or 12)
  if _G[thickness:GetName().."Low"] then _G[thickness:GetName().."Low"]:SetText("6") end
  if _G[thickness:GetName().."High"] then _G[thickness:GetName().."High"]:SetText("32") end
  if _G[thickness:GetName().."Text"] then _G[thickness:GetName().."Text"]:SetText("Thickness") end
  thickness:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.thickness = val
    H.ApplyLayout()
  end)

  
  local height = CreateFrame("Slider", "HardcoreHUDHeightSlider", panelLayout, "OptionsSliderTemplate")
  height:ClearAllPoints()
  height:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -34)
  height:SetMinMaxValues(120, 320)
  height:SetValueStep(10)
  height:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.height or 200)
  if _G[height:GetName().."Low"] then _G[height:GetName().."Low"]:SetText("120") end
  if _G[height:GetName().."High"] then _G[height:GetName().."High"]:SetText("320") end
  if _G[height:GetName().."Text"] then _G[height:GetName().."Text"]:SetText("Height") end
  height:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.height = val
    H.ApplyLayout()
  end)
  -- Separation slider
  local sep = CreateFrame("Slider", "HardcoreHUDSeparationSlider", panelLayout, "OptionsSliderTemplate")
  sep:ClearAllPoints()
  sep:SetPoint("TOPLEFT", height, "BOTTOMLEFT", 0, -34)
  sep:SetMinMaxValues(80, 240)
  sep:SetValueStep(10)
  sep:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.separation or 140)
  if _G[sep:GetName().."Low"] then _G[sep:GetName().."Low"]:SetText("80") end
  if _G[sep:GetName().."High"] then _G[sep:GetName().."High"]:SetText("240") end
  if _G[sep:GetName().."Text"] then _G[sep:GetName().."Text"]:SetText("Separation from Center") end
  sep:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.separation = val
    H.ApplyLayout()
  end)

  -- Vertical separation slider will be added after Multi-Aggro slider is defined

  -- Warnings panel controls - LEFT COLUMN (Checkboxes)
  local warnEnable = SafeCheckButton("HardcoreHUDWarnEnable", panelWarnings, "OptionsCheckButtonTemplate")
  warnEnable:ClearAllPoints()
  warnEnable:SetPoint("TOPLEFT", panelWarnings, "TOPLEFT", 0, -8)
  HardcoreHUDDB.warnings.enabled = (HardcoreHUDDB.warnings.enabled ~= false)
  warnEnable:SetChecked(HardcoreHUDDB.warnings.enabled)
  if _G[warnEnable:GetName().."Text"] then _G[warnEnable:GetName().."Text"]:SetText("Warnings Enabled") end
  warnEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.enabled = self:GetChecked()
    print("HardcoreHUD: Warnings "..(HardcoreHUDDB.warnings.enabled and "ON" or "OFF"))
    if not HardcoreHUDDB.warnings.enabled then
      if H.HideCriticalHPWarning then H.HideCriticalHPWarning() end
      if H.skull then H.skull:Hide() end
      if H.EliteAttentionText then H.EliteAttentionText:Hide() end
      if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
    else
      if H.CheckSkull then H.CheckSkull() end
      if H.EvaluateMultiAggro then H.EvaluateMultiAggro() end
    end
  end)
  
  local crit = SafeCheckButton("HardcoreHUDCritWarn", panelWarnings, "OptionsCheckButtonTemplate")
  crit:ClearAllPoints()
  crit:SetPoint("TOPLEFT", warnEnable, "BOTTOMLEFT", 0, -8)
  crit:SetChecked(HardcoreHUDDB.warnings.criticalHP)
  if _G[crit:GetName().."Text"] then _G[crit:GetName().."Text"]:SetText("Critical HP Warning") end
  crit:SetScript("OnClick", function(self) HardcoreHUDDB.warnings.criticalHP = self:GetChecked() end)

  if HardcoreHUDDB.warnings.criticalOverlayEnabled == nil then HardcoreHUDDB.warnings.criticalOverlayEnabled = true end
  local critOverlay = SafeCheckButton("HardcoreHUDCritOverlay", panelWarnings, "OptionsCheckButtonTemplate")
  critOverlay:ClearAllPoints()
  critOverlay:SetPoint("TOPLEFT", crit, "BOTTOMLEFT", 0, -8)
  critOverlay:SetChecked(HardcoreHUDDB.warnings.criticalOverlayEnabled ~= false)
  if _G[critOverlay:GetName().."Text"] then _G[critOverlay:GetName().."Text"]:SetText("Critical HP Red Pulse") end
  critOverlay:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.criticalOverlayEnabled = self:GetChecked()
    if H.UpdateCriticalOverlay then H.UpdateCriticalOverlay() end
  end)

  local skull = SafeCheckButton("HardcoreHUDSkullWarn", panelWarnings, "OptionsCheckButtonTemplate")
  skull:ClearAllPoints()
  skull:SetPoint("TOPLEFT", critOverlay, "BOTTOMLEFT", 0, -8)
  skull:SetChecked(HardcoreHUDDB.warnings.levelElite)
  if _G[skull:GetName().."Text"] then _G[skull:GetName().."Text"]:SetText("Elite/+2 Level Skull") end
  skull:SetScript("OnClick", function(self) HardcoreHUDDB.warnings.levelElite = self:GetChecked(); H.CheckSkull() end)

  local perf = SafeCheckButton("HardcoreHUDPerfWarn", panelWarnings, "OptionsCheckButtonTemplate")
  perf:ClearAllPoints()
  perf:SetPoint("TOPLEFT", skull, "BOTTOMLEFT", 0, -8)
  HardcoreHUDDB.warnings.latency = (HardcoreHUDDB.warnings.latency ~= false)
  perf:SetChecked(HardcoreHUDDB.warnings.latency)
  if _G[perf:GetName().."Text"] then _G[perf:GetName().."Text"]:SetText("Latency/FPS Warning") end
  perf:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.latency = self:GetChecked()
    if not HardcoreHUDDB.warnings.latency and H.perfWarn then H.perfWarn:Hide() end
  end)

  HardcoreHUDDB.warnings.leash = HardcoreHUDDB.warnings.leash or { enabled = true, distance = 50, sound = true }
  local leashEnable = SafeCheckButton("HardcoreHUDLeashEnable", panelWarnings, "OptionsCheckButtonTemplate")
  leashEnable:ClearAllPoints()
  leashEnable:SetPoint("TOPLEFT", perf, "BOTTOMLEFT", 0, -8)
  leashEnable:SetChecked(HardcoreHUDDB.warnings.leash.enabled ~= false)
  if _G[leashEnable:GetName().."Text"] then _G[leashEnable:GetName().."Text"]:SetText("Leash Warning") end
  leashEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.leash.enabled = self:GetChecked()
    if not HardcoreHUDDB.warnings.leash.enabled and H.leashWarn then H.leashWarn:Hide() end
  end)

  local rangeEnable = SafeCheckButton("HardcoreHUDRangeEnable", panelWarnings, "OptionsCheckButtonTemplate")
  rangeEnable:ClearAllPoints()
  rangeEnable:SetPoint("TOPLEFT", leashEnable, "BOTTOMLEFT", 0, -8)
  rangeEnable:SetChecked(HardcoreHUDDB.warnings.rangeDisplay.enabled ~= false)
  if _G[rangeEnable:GetName().."Text"] then _G[rangeEnable:GetName().."Text"]:SetText("Range Display") end
  rangeEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.rangeDisplay.enabled = self:GetChecked()
    if not HardcoreHUDDB.warnings.rangeDisplay.enabled and H.rangeDisplay then H.rangeDisplay:Hide() end
  end)

  -- RIGHT COLUMN (Sliders & GTFO) - starts at top right
  -- Critical HP threshold slider
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  if HardcoreHUDDB.warnings.criticalThreshold == nil then HardcoreHUDDB.warnings.criticalThreshold = 0.20 end
  local critThresh = CreateFrame("Slider", "HardcoreHUDCritThreshold", panelWarnings, "OptionsSliderTemplate")
  critThresh:ClearAllPoints()
  critThresh:SetPoint("TOPLEFT", panelWarnings, "TOPLEFT", 200, -8)
  critThresh:SetMinMaxValues(0.15, 0.50)
  critThresh:SetValueStep(0.01)
  if critThresh.SetObeyStepOnDrag then critThresh:SetObeyStepOnDrag(true) end
  if _G[critThresh:GetName().."Low"] then _G[critThresh:GetName().."Low"]:SetText("15%") end
  if _G[critThresh:GetName().."High"] then _G[critThresh:GetName().."High"]:SetText("50%") end
  if _G[critThresh:GetName().."Text"] then _G[critThresh:GetName().."Text"]:SetText("Critical HP Threshold") end
  critThresh:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.warnings.criticalThreshold = val
    if H.UpdateHealth then H.UpdateHealth() end
  end)

  -- Leash distance slider
  local leashDist = CreateFrame("Slider", "HardcoreHUDLeashDistance", panelWarnings, "OptionsSliderTemplate")
  leashDist:ClearAllPoints()
  leashDist:SetPoint("TOPLEFT", critThresh, "BOTTOMLEFT", 0, -20)
  leashDist:SetMinMaxValues(30, 60)
  leashDist:SetValueStep(1)
  leashDist:SetValue(HardcoreHUDDB.warnings.leash.distance or 50)
  if _G[leashDist:GetName().."Low"] then _G[leashDist:GetName().."Low"]:SetText("30y") end
  if _G[leashDist:GetName().."High"] then _G[leashDist:GetName().."High"]:SetText("60y") end
  if _G[leashDist:GetName().."Text"] then _G[leashDist:GetName().."Text"]:SetText("Leash Distance") end
  leashDist:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.warnings.leash.distance = val
  end)

  -- GTFO System - label and controls
  local gtfoLabel = panelWarnings:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  gtfoLabel:SetPoint("TOPLEFT", leashDist, "BOTTOMLEFT", 0, -20)
  gtfoLabel:SetText("GTFO - Danger Alerts")
  gtfoLabel:SetDrawLayer("OVERLAY")

  HardcoreHUDDB.gtfo = HardcoreHUDDB.gtfo or { enabled = true, highDamage = true, lowDamage = true, fallAlert = true, volume = 1.0 }
  
  local gtfoEnable = SafeCheckButton("HardcoreHUDGTFOEnable", panelWarnings, "OptionsCheckButtonTemplate")
  gtfoEnable:ClearAllPoints()
  gtfoEnable:SetPoint("TOPLEFT", gtfoLabel, "BOTTOMLEFT", 0, -8)
  gtfoEnable:SetChecked(HardcoreHUDDB.gtfo.enabled ~= false)
  if _G[gtfoEnable:GetName().."Text"] then _G[gtfoEnable:GetName().."Text"]:SetText("Enable GTFO") end
  gtfoEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.gtfo.enabled = self:GetChecked()
    if not H._gtfoInit then H.InitGTFO() end
  end)

  local gtfoHigh = SafeCheckButton("HardcoreHUDGTFOHigh", panelWarnings, "OptionsCheckButtonTemplate")
  gtfoHigh:ClearAllPoints()
  gtfoHigh:SetPoint("TOPLEFT", gtfoEnable, "BOTTOMLEFT", 0, -8)
  gtfoHigh:SetChecked(HardcoreHUDDB.gtfo.highDamage ~= false)
  if _G[gtfoHigh:GetName().."Text"] then _G[gtfoHigh:GetName().."Text"]:SetText("High Damage Alerts") end
  gtfoHigh:SetScript("OnClick", function(self)
    HardcoreHUDDB.gtfo.highDamage = self:GetChecked()
  end)

  local gtfoLow = SafeCheckButton("HardcoreHUDGTFOLow", panelWarnings, "OptionsCheckButtonTemplate")
  gtfoLow:ClearAllPoints()
  gtfoLow:SetPoint("TOPLEFT", gtfoHigh, "BOTTOMLEFT", 0, -8)
  gtfoLow:SetChecked(HardcoreHUDDB.gtfo.lowDamage ~= false)
  if _G[gtfoLow:GetName().."Text"] then _G[gtfoLow:GetName().."Text"]:SetText("Low Damage Alerts") end
  gtfoLow:SetScript("OnClick", function(self)
    HardcoreHUDDB.gtfo.lowDamage = self:GetChecked()
  end)

  local gtfoFall = SafeCheckButton("HardcoreHUDGTFOFall", panelWarnings, "OptionsCheckButtonTemplate")
  gtfoFall:ClearAllPoints()
  gtfoFall:SetPoint("TOPLEFT", gtfoLow, "BOTTOMLEFT", 0, -8)
  gtfoFall:SetChecked(HardcoreHUDDB.gtfo.fallAlert ~= false)
  if _G[gtfoFall:GetName().."Text"] then _G[gtfoFall:GetName().."Text"]:SetText("Fall/Drowning Alerts") end
  gtfoFall:SetScript("OnClick", function(self)
    HardcoreHUDDB.gtfo.fallAlert = self:GetChecked()
  end)

  -- Drowning alert threshold slider (when to show "DROWNING!" warning)
  if HardcoreHUDDB.gtfo.breathThreshold == nil then HardcoreHUDDB.gtfo.breathThreshold = 50 end
  local gtfoBreath = CreateFrame("Slider", "HardcoreHUDGTFOBreathThreshold", panelWarnings, "OptionsSliderTemplate")
  gtfoBreath:ClearAllPoints()
  gtfoBreath:SetPoint("TOPLEFT", gtfoFall, "BOTTOMLEFT", 0, -18)
  gtfoBreath:SetMinMaxValues(10, 90)
  gtfoBreath:SetValueStep(5)
  gtfoBreath:SetValue(HardcoreHUDDB.gtfo.breathThreshold or 50)
  if _G[gtfoBreath:GetName().."Low"] then _G[gtfoBreath:GetName().."Low"]:SetText("10%") end
  if _G[gtfoBreath:GetName().."High"] then _G[gtfoBreath:GetName().."High"]:SetText("90%") end
  if _G[gtfoBreath:GetName().."Text"] then _G[gtfoBreath:GetName().."Text"]:SetText("Drowning Alert at " .. math.floor(HardcoreHUDDB.gtfo.breathThreshold or 50) .. "% breath") end
  gtfoBreath:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.gtfo.breathThreshold = val
    if _G[self:GetName().."Text"] then _G[self:GetName().."Text"]:SetText("Drowning Alert at " .. math.floor(val) .. "% breath") end
  end)

  -- GTFO Volume slider
  local gtfoVol = CreateFrame("Slider", "HardcoreHUDGTFOVolume", panelWarnings, "OptionsSliderTemplate")
  gtfoVol:ClearAllPoints()
  gtfoVol:SetPoint("TOPLEFT", gtfoBreath, "BOTTOMLEFT", 0, -18)
  gtfoVol:SetMinMaxValues(0, 1)
  gtfoVol:SetValueStep(0.1)
  gtfoVol:SetValue(HardcoreHUDDB.gtfo.volume or 1.0)
  if _G[gtfoVol:GetName().."Low"] then _G[gtfoVol:GetName().."Low"]:SetText("0%") end
  if _G[gtfoVol:GetName().."High"] then _G[gtfoVol:GetName().."High"]:SetText("100%") end
  if _G[gtfoVol:GetName().."Text"] then _G[gtfoVol:GetName().."Text"]:SetText("GTFO Volume") end
  gtfoVol:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.gtfo.volume = val
  end)

  -- Test buttons
  local testHighBtn = CreateFrame("Button", nil, panelWarnings, "UIPanelButtonTemplate")
  testHighBtn:SetSize(80, 22)
  testHighBtn:SetPoint("TOPLEFT", gtfoVol, "BOTTOMLEFT", 0, -18)
  testHighBtn:SetText("Test High")
  testHighBtn:SetScript("OnClick", function()
    if not H.gtfoFrame then H.BuildGTFOFrame() end
    H.TestGTFOAlert("high")
  end)

  local testLowBtn = CreateFrame("Button", nil, panelWarnings, "UIPanelButtonTemplate")
  testLowBtn:SetSize(80, 22)
  testLowBtn:SetPoint("LEFT", testHighBtn, "RIGHT", 8, 0)
  testLowBtn:SetText("Test Low")
  testLowBtn:SetScript("OnClick", function()
    if not H.gtfoFrame then H.BuildGTFOFrame() end
    H.TestGTFOAlert("low")
  end)

  local testFallBtn = CreateFrame("Button", nil, panelWarnings, "UIPanelButtonTemplate")
  testFallBtn:SetSize(80, 22)
  testFallBtn:SetPoint("LEFT", testLowBtn, "RIGHT", 8, 0)
  testFallBtn:SetText("Test Fall")
  testFallBtn:SetScript("OnClick", function()
    if not H.gtfoFrame then H.BuildGTFOFrame() end
    H.TestGTFOAlert("fall")
  end)

  -- (Rounded and texture options removed)

  -- HUD lock/move controls
  -- Multi-aggro threshold slider (2-5)
  -- Vertical separation (offset from center Y) — place directly under Separation
  local sepY = CreateFrame("Slider", "HardcoreHUDCenterOffsetY", panelLayout, "OptionsSliderTemplate")
  sepY:ClearAllPoints()
  sepY:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -34)
  sepY:SetMinMaxValues(-200, 200)
  sepY:SetValueStep(5)
  sepY:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.centerOffsetY or 0)
  if _G[sepY:GetName().."Low"] then _G[sepY:GetName().."Low"]:SetText("-200") end
  if _G[sepY:GetName().."High"] then _G[sepY:GetName().."High"]:SetText("200") end
  if _G[sepY:GetName().."Text"] then _G[sepY:GetName().."Text"]:SetText("Vertical Offset from Center") end
  sepY:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.centerOffsetY = math.floor(val+0.5)
    H.ApplyLayout()
  end)

  -- Multi-aggro threshold slider (left column) — place under Vertical Offset
  local multi = CreateFrame("Slider", "HardcoreHUDMultiAggroSlider", panelLayout, "OptionsSliderTemplate")
  multi:ClearAllPoints()
  multi:SetPoint("TOPLEFT", sepY, "BOTTOMLEFT", 0, -34)
  multi:SetMinMaxValues(2,5)
  multi:SetValueStep(1)
  multi:SetValue(HardcoreHUDDB.warnings.multiAggroThreshold or 2)
  if _G[multi:GetName().."Low"] then _G[multi:GetName().."Low"]:SetText("2") end
  if _G[multi:GetName().."High"] then _G[multi:GetName().."High"]:SetText("5") end
  if _G[multi:GetName().."Text"] then _G[multi:GetName().."Text"]:SetText("Multi-Aggro Threshold") end
  multi:SetScript("OnValueChanged", function(self,val)
    HardcoreHUDDB.warnings.multiAggroThreshold = math.floor(val+0.5)
    print("HardcoreHUD: Multi-aggro threshold = "..HardcoreHUDDB.warnings.multiAggroThreshold)
  end)

  -- Lock HUD Checkbox (layout section - moved to right column)
  local lock = SafeCheckButton("HardcoreHUDLock", panelLayout, "InterfaceOptionsCheckButtonTemplate")
  lock:ClearAllPoints()
  lock:SetPoint("TOPLEFT", panelLayout, "TOPLEFT", 280, -20)
  lock:SetSize(24,24)
  lock:SetChecked(HardcoreHUDDB.lock ~= false)
  H.lockCheckbox = lock
  local function forceCheckVisual()
    if not H.lockCheckbox then return end
    local isLocked = HardcoreHUDDB.lock == true
    H.lockCheckbox:SetChecked(isLocked)
    local ct = H.lockCheckbox.GetCheckedTexture and H.lockCheckbox:GetCheckedTexture()
    if ct then
      ct:SetAlpha(isLocked and 1 or 0)
      if isLocked then ct:Show() else ct:Hide() end
    end
  end
  if _G[lock:GetName().."Text"] then _G[lock:GetName().."Text"]:SetText("Lock HUD (disable drag)") end
  lock:SetScript("OnClick", function(self)
    local isLocked = self:GetChecked()
    HardcoreHUDDB.lock = isLocked
    if H.ApplyLock then H.ApplyLock() end
    H.root:SetMovable(not isLocked)
    if H.SetHUDMouseEnabled then H.SetHUDMouseEnabled(isLocked) end
    if isLocked then
      H.root:EnableMouse(false)
      print("HardcoreHUD: HUD locked")
    else
      H.root:EnableMouse(true)
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
      -- reattach drag to child bars
      if H.bars then
        if H.bars.hp then H.bars.hp:RegisterForDrag("LeftButton") end
        if H.bars.pow then H.bars.pow:RegisterForDrag("LeftButton") end
        if H.bars.targetHP then H.bars.targetHP:RegisterForDrag("LeftButton") end
        if H.bars.targetPow then H.bars.targetPow:RegisterForDrag("LeftButton") end
      end
      print("HardcoreHUD: HUD unlocked, drag to move")
    end
  end)

  -- Lock Range Display checkbox (under Lock HUD)
  -- Ensure rangeDisplay table exists before creating checkbox
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  HardcoreHUDDB.warnings.rangeDisplay = HardcoreHUDDB.warnings.rangeDisplay or { enabled = true, locked = false }
  
  local rangeLock = SafeCheckButton("HardcoreHUDRangeLock", panelLayout, "InterfaceOptionsCheckButtonTemplate")
  rangeLock:ClearAllPoints()
  rangeLock:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -8)
  rangeLock:SetSize(24,24)
  rangeLock:SetChecked(HardcoreHUDDB.warnings.rangeDisplay.locked == true)
  if _G[rangeLock:GetName().."Text"] then _G[rangeLock:GetName().."Text"]:SetText("Lock Range Display") end
  rangeLock:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.rangeDisplay.locked = self:GetChecked()
    if HardcoreHUDDB.warnings.rangeDisplay.locked then
      -- Locked: hide test display
      if H.HideRangeDisplayTest then H.HideRangeDisplayTest() end
      print("HardcoreHUD: Range Display locked")
    else
      -- Unlocked: show test display for positioning
      if H.ShowRangeDisplayTest then H.ShowRangeDisplayTest() end
      print("HardcoreHUD: Range Display unlocked - drag to move")
    end
  end)

  -- Lock Target Marks checkbox
  local tmLock = SafeCheckButton("HardcoreHUDTargetMarksLock", panelLayout, "InterfaceOptionsCheckButtonTemplate")
  tmLock:ClearAllPoints()
  tmLock:SetPoint("TOPLEFT", rangeLock, "BOTTOMLEFT", 0, -8)
  tmLock:SetSize(24,24)
  tmLock:SetChecked(HardcoreHUDDB.targetMarks.locked == true)
  if _G[tmLock:GetName().."Text"] then _G[tmLock:GetName().."Text"]:SetText("Lock Target Markers") end
  tmLock:SetScript("OnClick", function(self)
    HardcoreHUDDB.targetMarks.locked = self:GetChecked()
    print("HardcoreHUD: Target mark bar "..(self:GetChecked() and "LOCKED" or "UNLOCKED"))
  end)

  -- Lock Leveling Tracker checkbox
  local lvLock = SafeCheckButton("HardcoreHUDLevelingLock", panelLayout, "InterfaceOptionsCheckButtonTemplate")
  lvLock:ClearAllPoints()
  lvLock:SetPoint("TOPLEFT", tmLock, "BOTTOMLEFT", 0, -8)
  lvLock:SetSize(24,24)
  lvLock:SetChecked(HardcoreHUDDB.leveling.locked == true)
  if _G[lvLock:GetName().."Text"] then _G[lvLock:GetName().."Text"]:SetText("Lock Leveling Tracker") end
  lvLock:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.locked = self:GetChecked()
    print("HardcoreHUD: Leveling tracker "..(self:GetChecked() and "LOCKED" or "UNLOCKED"))
  end)
  
  -- Lock Leash Display checkbox
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  HardcoreHUDDB.warnings.leash = HardcoreHUDDB.warnings.leash or { enabled = true, locked = false }
  
  local leashLock = SafeCheckButton("HardcoreHUDLeashLock", panelLayout, "InterfaceOptionsCheckButtonTemplate")
  leashLock:ClearAllPoints()
  leashLock:SetPoint("TOPLEFT", lvLock, "BOTTOMLEFT", 0, -8)
  leashLock:SetSize(24,24)
  leashLock:SetChecked(HardcoreHUDDB.warnings.leash.locked == true)
  if _G[leashLock:GetName().."Text"] then _G[leashLock:GetName().."Text"]:SetText("Lock Leash Display") end
  leashLock:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.leash.locked = self:GetChecked()
    if HardcoreHUDDB.warnings.leash.locked then
      -- Locked: hide test display
      if H.HideLeashTest then H.HideLeashTest() end
      print("HardcoreHUD: Leash Display locked")
    else
      -- Unlocked: show test display for positioning
      if H.ShowLeashTest then H.ShowLeashTest() end
      print("HardcoreHUD: Leash Display unlocked - drag to move")
    end
  end)

  -- Initial sync to ensure checkbox reflects DB on first build
  if HardcoreHUDDB.lock == nil then HardcoreHUDDB.lock = true end
  lock:SetChecked(true)
  if H.SetHUDMouseEnabled then H.SetHUDMouseEnabled(true) end

  -- Keep checkbox in sync on options frame show
  f:SetScript("OnShow", function()
    lock:SetChecked(true)
    forceCheckVisual()
    -- one-frame deferred ensure visual checked state updates
    f._lockSyncDone = false
    f:SetScript("OnUpdate", function(self)
      if self._lockSyncDone then self:SetScript("OnUpdate", nil); return end
      lock:SetChecked(true)
      forceCheckVisual()
      self._lockSyncDone = true
    end)
  end)

-- Expose a sync helper for other modules
function H.SyncLockCheckbox()
  if H.lockCheckbox and HardcoreHUDDB then
    local isLocked = HardcoreHUDDB.lock == true
    H.lockCheckbox:SetChecked(isLocked)
    local ct = H.lockCheckbox.GetCheckedTexture and H.lockCheckbox:GetCheckedTexture()
    if ct then
      ct:SetAlpha(isLocked and 1 or 0)
      if isLocked then ct:Show() else ct:Hide() end
    end
  end
end

  -- Action buttons (right column)
  -- Reminders/Tests panel right-side tools move under Reminders panel
  local center = CreateFrame("Button", nil, panelRemind, "UIPanelButtonTemplate")
  center:ClearAllPoints()
  center:SetPoint("TOPLEFT", panelRemind, "TOPLEFT", 0, -12)
  center:SetSize(170, 24)
  center:SetText("Center HUD")
  center:SetFrameStrata("FULLSCREEN_DIALOG")
  center:SetFrameLevel(panelRemind:GetFrameLevel()+1)
  center:SetScript("OnClick", function()
    HardcoreHUDDB.pos = { x = 0, y = -150 }
    H.root:ClearAllPoints()
    H.root:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x, HardcoreHUDDB.pos.y)
    print("HardcoreHUD: HUD centered")
  end)

  -- Test buttons for warnings (placed under warning toggles)
  local testsLabel = panelRemind:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  testsLabel:ClearAllPoints()
  testsLabel:SetPoint("TOPLEFT", center, "BOTTOMLEFT", 0, -20)
  testsLabel:SetText("Warning Tests")
  testsLabel:SetDrawLayer("OVERLAY")

  local testCrit = CreateFrame("Button", nil, panelRemind, "UIPanelButtonTemplate")
  testCrit:ClearAllPoints()
  testCrit:SetPoint("TOPLEFT", testsLabel, "BOTTOMLEFT", 0, -10)
  testCrit:SetSize(150, 24)
  testCrit:SetText("Test Critical Health")
  testCrit:SetFrameStrata("FULLSCREEN_DIALOG")
  testCrit:SetFrameLevel(panelRemind:GetFrameLevel()+1)
  testCrit:SetScript("OnClick", function()
    print("HardcoreHUD: Test Critical clicked")
    if H.TriggerCriticalHPTest then H.TriggerCriticalHPTest() else print("HardcoreHUD: TriggerCriticalHPTest missing") end
  end)
  testCrit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Play critical health warning")
    GameTooltip:Show()
  end)
  testCrit:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local testElite = CreateFrame("Button", nil, panelRemind, "UIPanelButtonTemplate")
  testElite:ClearAllPoints()
  testElite:SetPoint("TOPLEFT", testCrit, "BOTTOMLEFT", 0, -12)
  testElite:SetSize(150, 24)
  testElite:SetText("Test Elite/+2 Skull")
  testElite:SetFrameStrata("FULLSCREEN_DIALOG")
  testElite:SetFrameLevel(panelRemind:GetFrameLevel()+1)
  testElite:SetScript("OnClick", function()
    print("HardcoreHUD: Test Elite clicked")
    if H.TriggerEliteSkullTest then H.TriggerEliteSkullTest() else print("HardcoreHUD: TriggerEliteSkullTest missing") end
  end)
  testElite:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show elite skull + attention text")
    GameTooltip:Show()
  end)
  testElite:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local testMulti = CreateFrame("Button", nil, panelRemind, "UIPanelButtonTemplate")
  testMulti:ClearAllPoints()
  testMulti:SetPoint("TOPLEFT", testElite, "BOTTOMLEFT", 0, -12)
  testMulti:SetSize(150, 24)
  testMulti:SetText("Test Multi-Aggro")
  testMulti:SetFrameStrata("FULLSCREEN_DIALOG")
  testMulti:SetFrameLevel(panelRemind:GetFrameLevel()+1)
  testMulti:SetScript("OnClick", function()
    print("HardcoreHUD: Test Multi-Aggro clicked")
    if H.TriggerMultiAggroTest then H.TriggerMultiAggroTest() else print("HardcoreHUD: TriggerMultiAggroTest missing") end
  end)
  testMulti:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Simulate multi-aggro danger warning")
    GameTooltip:Show()
  end)
  testMulti:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Removed Test TTD Bar button; TTD is always enabled and visible in combat

  -- Buff/Consumable reminder toggle
  local remind = SafeCheckButton("HardcoreHUDBuffRemind", panelRemind, "OptionsCheckButtonTemplate")
  remind:ClearAllPoints()
  -- Anchor within Reminders panel under tests label to avoid cross-panel dependency
  remind:SetPoint("TOPLEFT", testMulti, "BOTTOMLEFT", 0, -18)
  HardcoreHUDDB.reminders = HardcoreHUDDB.reminders or { enabled = true }
  HardcoreHUDDB.reminders.categories = HardcoreHUDDB.reminders.categories or { food=true, flask=true, survival=true }
  remind:SetChecked(HardcoreHUDDB.reminders.enabled)
  if _G[remind:GetName().."Text"] then _G[remind:GetName().."Text"]:SetText("Buff/Food/Flask Reminder") end
  remind:SetScript("OnClick", function(self)
    HardcoreHUDDB.reminders.enabled = self:GetChecked()
    if HardcoreHUDDB.reminders.enabled then
      if H.InitReminders then H.InitReminders() end
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame then H.reminderFrame:Show() end
    else
      if H.reminderFrame then H.reminderFrame:Hide() end
    end
  end)

  -- Reminder category toggles (move to right column to relieve middle)
  local remCatLabel = panelRemind:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  remCatLabel:SetPoint("TOPLEFT", remind, "BOTTOMLEFT", 0, -20)
  remCatLabel:SetText("Reminder Categories")
  remCatLabel:SetDrawLayer("OVERLAY")

  -- Only keep Core Buffs toggle; Food/Flask removed per request
  local rCore = SafeCheckButton("HardcoreHUDRemindCore", panelRemind, "OptionsCheckButtonTemplate")
  rCore:SetPoint("TOPLEFT", remCatLabel, "BOTTOMLEFT", 0, -8)
  rCore:SetChecked(HardcoreHUDDB.reminders.categories.survival)
  if _G[rCore:GetName().."Text"] then _G[rCore:GetName().."Text"]:SetText("Core Buffs: Fortitude/Mark/Kings") end
  rCore:SetFrameStrata("FULLSCREEN_DIALOG")
  rCore:SetFrameLevel(panelRemind:GetFrameLevel()+1)
  rCore:SetScript("OnClick", function(self)
    HardcoreHUDDB.reminders.categories.survival = self:GetChecked()
    if H.UpdateReminders then H.UpdateReminders() end
  end)

  -- Thanks for Buff System - DISABLED
  -- This feature has been permanently disabled because SendChatMessage/DoEmote
  -- cause ADDON_ACTION_BLOCKED errors in Classic Era. The WoW API protects
  -- these functions and addons cannot use them without causing taint.
  HardcoreHUDDB.thanksBuff = HardcoreHUDDB.thanksBuff or { enabled = false }
  HardcoreHUDDB.thanksBuff.enabled = false  -- Force disabled to prevent errors

  -- Emergency CDs pulse toggle
  HardcoreHUDDB.emergency = HardcoreHUDDB.emergency or { enabled = true, hpThreshold = 0.50 }
  -- Advanced panel controls
  local emEnable = SafeCheckButton("HardcoreHUDEmergencyEnable", advLeft, "OptionsCheckButtonTemplate")
  emEnable:ClearAllPoints()
  emEnable:SetPoint("TOPLEFT", advLeft, "TOPLEFT", 0, -8)
  emEnable:SetChecked(HardcoreHUDDB.emergency.enabled)
  if _G[emEnable:GetName().."Text"] then _G[emEnable:GetName().."Text"]:SetText("Notfall-CD Puls") end
    if _G[emEnable:GetName().."Text"] then _G[emEnable:GetName().."Text"]:SetText("Emergency CD Pulse") end
  emEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.emergency.enabled = self:GetChecked()
    print("HardcoreHUD: Emergency pulse "..(HardcoreHUDDB.emergency.enabled and "ON" or "OFF"))
  end)

  -- Drowning protection: blue pulse overlay toggle + threshold
  HardcoreHUDDB.breath = HardcoreHUDDB.breath or { enabled = true }
  if HardcoreHUDDB.breath.secondsThreshold == nil then HardcoreHUDDB.breath.secondsThreshold = 20 end
  -- remove deprecated percentage threshold to avoid confusion
  HardcoreHUDDB.breath.threshold = nil
  local breathEnable = SafeCheckButton("HardcoreHUDBreathEnable", advLeft, "OptionsCheckButtonTemplate")
  breathEnable:ClearAllPoints()
  breathEnable:SetPoint("TOPLEFT", emEnable, "BOTTOMLEFT", 0, -16)
  breathEnable:SetChecked(HardcoreHUDDB.breath.enabled ~= false)
  if _G[breathEnable:GetName().."Text"] then _G[breathEnable:GetName().."Text"]:SetText("Drowning Protection (blue pulse)") end
  breathEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.breath.enabled = self:GetChecked()
    print("HardcoreHUD: Drowning protection "..(HardcoreHUDDB.breath.enabled and "ON" or "OFF"))
    if H.UpdateBreathWarning then H.UpdateBreathWarning() end
  end)

  -- Target Cast Bar toggle
  HardcoreHUDDB.castbar = HardcoreHUDDB.castbar or { enabled = true }
  local castEnable = SafeCheckButton("HardcoreHUDCastBarEnable", advLeft, "OptionsCheckButtonTemplate")
  castEnable:ClearAllPoints()
  castEnable:SetPoint("TOPLEFT", breathEnable, "BOTTOMLEFT", 0, -16)
  castEnable:SetChecked(HardcoreHUDDB.castbar.enabled ~= false)
  if _G[castEnable:GetName().."Text"] then _G[castEnable:GetName().."Text"]:SetText("Target Cast Bar") end
  castEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.castbar.enabled = self:GetChecked()
    print("HardcoreHUD: Target Cast Bar "..(HardcoreHUDDB.castbar.enabled and "ON" or "OFF"))
    if H.UpdateTargetCastBarVisibility then H.UpdateTargetCastBarVisibility() end
  end)

  local breathThresh = CreateFrame("Slider", "HardcoreHUDBreathThreshold", advLeft, "OptionsSliderTemplate")
  breathThresh:ClearAllPoints()
  breathThresh:SetPoint("TOPLEFT", castEnable, "BOTTOMLEFT", 0, -18)
  breathThresh:SetMinMaxValues(5, 60)
  breathThresh:SetValueStep(5)
  if breathThresh.SetObeyStepOnDrag then breathThresh:SetObeyStepOnDrag(true) end
  breathThresh:SetValue(HardcoreHUDDB.breath.secondsThreshold or 20)
  if _G[breathThresh:GetName().."Low"] then _G[breathThresh:GetName().."Low"]:SetText("5s") end
  if _G[breathThresh:GetName().."High"] then _G[breathThresh:GetName().."High"]:SetText("60s") end
  if _G[breathThresh:GetName().."Text"] then _G[breathThresh:GetName().."Text"]:SetText("Breath Warning Time (sec)") end
  breathThresh:SetScript("OnValueChanged", function(self, val)
    val = math.floor(val + 0.5)
    HardcoreHUDDB.breath.secondsThreshold = val
    print("HardcoreHUD: Breath time threshold = "..val.."s")
    if H.UpdateBreathWarning then H.UpdateBreathWarning() end
  end)

  -- Emergency HP threshold slider
  local emHP = CreateFrame("Slider", "HardcoreHUDEmergencyHPSlider", advLeft, "OptionsSliderTemplate")
  emHP:ClearAllPoints()
  emHP:SetPoint("TOPLEFT", breathThresh, "BOTTOMLEFT", 0, -34)
  emHP:SetMinMaxValues(0.15, 0.90)
  emHP:SetValueStep(0.05)
  -- Older client builds (e.g. 3.3.5) lack SetObeyStepOnDrag; guard it
  if emHP.SetObeyStepOnDrag then emHP:SetObeyStepOnDrag(true) end
  emHP:SetValue(HardcoreHUDDB.emergency.hpThreshold or 0.50)
  if _G[emHP:GetName().."Low"] then _G[emHP:GetName().."Low"]:SetText("15%") end
  if _G[emHP:GetName().."High"] then _G[emHP:GetName().."High"]:SetText("90%") end
  if _G[emHP:GetName().."Text"] then _G[emHP:GetName().."Text"]:SetText("Pulse Threshold HP") end
  emHP:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.emergency.hpThreshold = val
    print("HardcoreHUD: Emergency HP threshold = "..math.floor(val*100+0.5).."%")
  end)

  -- OOM Soon (mana) blue pulse
  HardcoreHUDDB.oom = HardcoreHUDDB.oom or { enabled = true, threshold = 0.25 }
  local oomEnable = SafeCheckButton("HardcoreHUDOOMEnable", advLeft, "OptionsCheckButtonTemplate")
  oomEnable:SetPoint("TOPLEFT", emHP, "BOTTOMLEFT", 0, -24)
  oomEnable:SetChecked(HardcoreHUDDB.oom.enabled ~= false)
  if _G[oomEnable:GetName().."Text"] then _G[oomEnable:GetName().."Text"]:SetText("OOM Soon (mana) Blue Pulse") end
  oomEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.oom.enabled = self:GetChecked()
    print("HardcoreHUD: OOM pulse "..(HardcoreHUDDB.oom.enabled and "ON" or "OFF"))
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay(true) end
  end)

  local oomThr = CreateFrame("Slider", "HardcoreHUDOOMThreshold", advLeft, "OptionsSliderTemplate")
  oomThr:SetPoint("TOPLEFT", oomEnable, "BOTTOMLEFT", 0, -18)
  oomThr:SetMinMaxValues(0.05, 0.60)
  oomThr:SetValueStep(0.01)
  if oomThr.SetObeyStepOnDrag then oomThr:SetObeyStepOnDrag(true) end
  oomThr:SetValue(HardcoreHUDDB.oom.threshold or 0.25)
  if _G[oomThr:GetName().."Low"] then _G[oomThr:GetName().."Low"]:SetText("5%") end
  if _G[oomThr:GetName().."High"] then _G[oomThr:GetName().."High"]:SetText("60%") end
  if _G[oomThr:GetName().."Text"] then _G[oomThr:GetName().."Text"]:SetText("OOM Threshold (%)") end
  oomThr:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.oom.threshold = val
    print("HardcoreHUD: OOM threshold = "..math.floor((val or 0)*100+0.5).."%")
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay(true) end
  end)

  -- Suppress when recovery available (potions/spells)
  if HardcoreHUDDB.oom.considerRecovery == nil then HardcoreHUDDB.oom.considerRecovery = true end
  local oomConsider = SafeCheckButton("HardcoreHUDOOMConsiderRecovery", advLeft, "OptionsCheckButtonTemplate")
  oomConsider:SetPoint("TOPLEFT", oomThr, "BOTTOMLEFT", 0, -10)
  oomConsider:SetChecked(HardcoreHUDDB.oom.considerRecovery ~= false)
  if _G[oomConsider:GetName().."Text"] then _G[oomConsider:GetName().."Text"]:SetText("Suppress if recovery ready") end
  oomConsider:SetScript("OnClick", function(self)
    HardcoreHUDDB.oom.considerRecovery = self:GetChecked()
    print("HardcoreHUD: OOM suppression by recovery "..(HardcoreHUDDB.oom.considerRecovery and "ON" or "OFF"))
    if H.UpdateOOMOverlay then H.UpdateOOMOverlay(true) end
  end)

  -- Trackers (Interrupt & Dispel)
  HardcoreHUDDB.trackers = HardcoreHUDDB.trackers or { interruptEnabled = true, interruptSound = true, showInterruptButton = true, dispelEnabled = true, dispelSound = false }
  local intrEnable = SafeCheckButton("HardcoreHUDInterruptEnable", advRight, "OptionsCheckButtonTemplate")
  intrEnable:ClearAllPoints()
  intrEnable:SetPoint("TOPLEFT", advRight, "TOPLEFT", 0, -8)
  intrEnable:SetChecked(HardcoreHUDDB.trackers.interruptEnabled ~= false)
  if _G[intrEnable:GetName().."Text"] then _G[intrEnable:GetName().."Text"]:SetText("Interrupt Tracker (glow)") end
  intrEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.trackers.interruptEnabled = self:GetChecked()
    print("HardcoreHUD: Interrupt tracker "..(HardcoreHUDDB.trackers.interruptEnabled and "ON" or "OFF"))
    if H.EvaluateInterruptState then H.EvaluateInterruptState(false) end
  end)

  local intrSound = SafeCheckButton("HardcoreHUDInterruptSound", advRight, "OptionsCheckButtonTemplate")
  intrSound:SetPoint("TOPLEFT", intrEnable, "BOTTOMLEFT", 0, -8)
  intrSound:SetChecked(HardcoreHUDDB.trackers.interruptSound ~= false)
  if _G[intrSound:GetName().."Text"] then _G[intrSound:GetName().."Text"]:SetText("Interrupt Sound") end
  intrSound:SetScript("OnClick", function(self)
    HardcoreHUDDB.trackers.interruptSound = self:GetChecked()
    print("HardcoreHUD: Interrupt sound "..(HardcoreHUDDB.trackers.interruptSound and "ON" or "OFF"))
  end)

  local intrBtn = SafeCheckButton("HardcoreHUDInterruptButtonToggle", advRight, "OptionsCheckButtonTemplate")
  intrBtn:SetPoint("TOPLEFT", intrSound, "BOTTOMLEFT", 0, -8)
  intrBtn:SetChecked(HardcoreHUDDB.trackers.showInterruptButton ~= false)
  if _G[intrBtn:GetName().."Text"] then _G[intrBtn:GetName().."Text"]:SetText("Show Interrupt Button") end
  intrBtn:SetScript("OnClick", function(self)
    HardcoreHUDDB.trackers.showInterruptButton = self:GetChecked()
    print("HardcoreHUD: Interrupt button "..(HardcoreHUDDB.trackers.showInterruptButton and "ON" or "OFF"))
    if H.cast and H.cast.interruptButton then
      if HardcoreHUDDB.trackers.showInterruptButton then pcall(H.cast.interruptButton.Show, H.cast.interruptButton) else pcall(H.cast.interruptButton.Hide, H.cast.interruptButton) end
    end
  end)

  local dispEnable = SafeCheckButton("HardcoreHUDDispelEnable", advRight, "OptionsCheckButtonTemplate")
  dispEnable:SetPoint("TOPLEFT", intrBtn, "BOTTOMLEFT", 0, -16)
  dispEnable:SetChecked(HardcoreHUDDB.trackers.dispelEnabled ~= false)
  if _G[dispEnable:GetName().."Text"] then _G[dispEnable:GetName().."Text"]:SetText("Dispel Highlight (self)") end
  dispEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.trackers.dispelEnabled = self:GetChecked()
    print("HardcoreHUD: Dispel highlight "..(HardcoreHUDDB.trackers.dispelEnabled and "ON" or "OFF"))
    if H.UpdateDispelHighlight then H.UpdateDispelHighlight() end
  end)

  local dispSound = SafeCheckButton("HardcoreHUDDispelSound", advRight, "OptionsCheckButtonTemplate")
  dispSound:SetPoint("TOPLEFT", dispEnable, "BOTTOMLEFT", 0, -8)
  dispSound:SetChecked(HardcoreHUDDB.trackers.dispelSound == true)
  if _G[dispSound:GetName().."Text"] then _G[dispSound:GetName().."Text"]:SetText("Dispel Sound") end
  dispSound:SetScript("OnClick", function(self)
    HardcoreHUDDB.trackers.dispelSound = self:GetChecked()
    print("HardcoreHUD: Dispel sound "..(HardcoreHUDDB.trackers.dispelSound and "ON" or "OFF"))
  end)

  -- Audio Cues
  HardcoreHUDDB.audio = HardcoreHUDDB.audio or { enabled = true }
  if HardcoreHUDDB.audio.critHP == nil then HardcoreHUDDB.audio.critHP = true end
  if HardcoreHUDDB.audio.breath == nil then HardcoreHUDDB.audio.breath = true end
  if HardcoreHUDDB.audio.castFinish == nil then HardcoreHUDDB.audio.castFinish = true end
  if HardcoreHUDDB.audio.castInterrupted == nil then HardcoreHUDDB.audio.castInterrupted = true end
  if HardcoreHUDDB.audio.oom == nil then HardcoreHUDDB.audio.oom = true end

  local audioEnable = SafeCheckButton("HardcoreHUDAudioEnable", advRight, "OptionsCheckButtonTemplate")
  audioEnable:SetPoint("TOPLEFT", dispSound, "BOTTOMLEFT", 0, -16)
  audioEnable:SetChecked(HardcoreHUDDB.audio.enabled ~= false)
  if _G[audioEnable:GetName().."Text"] then _G[audioEnable:GetName().."Text"]:SetText("Audio Cues Enabled") end
  audioEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.enabled = self:GetChecked()
    print("HardcoreHUD: Audio cues "..(HardcoreHUDDB.audio.enabled and "ON" or "OFF"))
  end)

  local audioCrit = SafeCheckButton("HardcoreHUDAudioCritHP", advRight, "OptionsCheckButtonTemplate")
  audioCrit:SetPoint("TOPLEFT", audioEnable, "BOTTOMLEFT", 0, -8)
  audioCrit:SetChecked(HardcoreHUDDB.audio.critHP ~= false)
  if _G[audioCrit:GetName().."Text"] then _G[audioCrit:GetName().."Text"]:SetText("Critical HP Sound") end
  audioCrit:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.critHP = self:GetChecked()
  end)

  local audioBreath = SafeCheckButton("HardcoreHUDAudioBreath", advRight, "OptionsCheckButtonTemplate")
  audioBreath:SetPoint("TOPLEFT", audioCrit, "BOTTOMLEFT", 0, -8)
  audioBreath:SetChecked(HardcoreHUDDB.audio.breath ~= false)
  if _G[audioBreath:GetName().."Text"] then _G[audioBreath:GetName().."Text"]:SetText("Breath Threshold Sound") end
  audioBreath:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.breath = self:GetChecked()
  end)

  local audioFinish = SafeCheckButton("HardcoreHUDAudioCastFinish", advRight, "OptionsCheckButtonTemplate")
  audioFinish:SetPoint("TOPLEFT", audioBreath, "BOTTOMLEFT", 0, -8)
  audioFinish:SetChecked(HardcoreHUDDB.audio.castFinish ~= false)
  if _G[audioFinish:GetName().."Text"] then _G[audioFinish:GetName().."Text"]:SetText("Cast Finish Sound") end
  audioFinish:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.castFinish = self:GetChecked()
  end)

  local audioInterrupt = SafeCheckButton("HardcoreHUDAudioCastInterrupted", advRight, "OptionsCheckButtonTemplate")
  audioInterrupt:SetPoint("TOPLEFT", audioFinish, "BOTTOMLEFT", 0, -8)
  audioInterrupt:SetChecked(HardcoreHUDDB.audio.castInterrupted ~= false)
  if _G[audioInterrupt:GetName().."Text"] then _G[audioInterrupt:GetName().."Text"]:SetText("Cast Interrupted Sound") end
  audioInterrupt:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.castInterrupted = self:GetChecked()
  end)

  local audioOOM = SafeCheckButton("HardcoreHUDAudioOOM", advRight, "OptionsCheckButtonTemplate")
  audioOOM:SetPoint("TOPLEFT", audioInterrupt, "BOTTOMLEFT", 0, -8)
  audioOOM:SetChecked(HardcoreHUDDB.audio.oom ~= false)
  if _G[audioOOM:GetName().."Text"] then _G[audioOOM:GetName().."Text"]:SetText("OOM Sound") end
  audioOOM:SetScript("OnClick", function(self)
    HardcoreHUDDB.audio.oom = self:GetChecked()
  end)

  -- ====== UTILITIES PANEL ======
  -- Initialize utilities layout settings
  HardcoreHUDDB.utilities = HardcoreHUDDB.utilities or {}
  if HardcoreHUDDB.utilities.buttonSize == nil then HardcoreHUDDB.utilities.buttonSize = 28 end
  if HardcoreHUDDB.utilities.buttonGap == nil then HardcoreHUDDB.utilities.buttonGap = 8 end
  if HardcoreHUDDB.utilities.independent == nil then HardcoreHUDDB.utilities.independent = false end
  if HardcoreHUDDB.utilities.offsetX == nil then HardcoreHUDDB.utilities.offsetX = 0 end
  if HardcoreHUDDB.utilities.offsetY == nil then HardcoreHUDDB.utilities.offsetY = -36 end

  -- Button Size Slider
  local utilButtonSize = CreateFrame("Slider", "HardcoreHUDUtilButtonSize", panelUtilities, "OptionsSliderTemplate")
  utilButtonSize:SetPoint("TOPLEFT", panelUtilities, "TOPLEFT", 20, -8)
  utilButtonSize:SetMinMaxValues(20, 48)
  utilButtonSize:SetValueStep(2)
  utilButtonSize:SetValue(HardcoreHUDDB.utilities.buttonSize)
  if _G[utilButtonSize:GetName().."Low"] then _G[utilButtonSize:GetName().."Low"]:SetText("20") end
  if _G[utilButtonSize:GetName().."High"] then _G[utilButtonSize:GetName().."High"]:SetText("48") end
  if _G[utilButtonSize:GetName().."Text"] then _G[utilButtonSize:GetName().."Text"]:SetText("Button Size") end
  utilButtonSize:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.utilities.buttonSize = val
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
  end)

  -- Button Gap Slider
  local utilButtonGap = CreateFrame("Slider", "HardcoreHUDUtilButtonGap", panelUtilities, "OptionsSliderTemplate")
  utilButtonGap:ClearAllPoints()
  utilButtonGap:SetPoint("TOPLEFT", utilButtonSize, "BOTTOMLEFT", 0, -34)
  utilButtonGap:SetMinMaxValues(2, 20)
  utilButtonGap:SetValueStep(1)
  utilButtonGap:SetValue(HardcoreHUDDB.utilities.buttonGap)
  if _G[utilButtonGap:GetName().."Low"] then _G[utilButtonGap:GetName().."Low"]:SetText("2") end
  if _G[utilButtonGap:GetName().."High"] then _G[utilButtonGap:GetName().."High"]:SetText("20") end
  if _G[utilButtonGap:GetName().."Text"] then _G[utilButtonGap:GetName().."Text"]:SetText("Button Gap") end
  utilButtonGap:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.utilities.buttonGap = val
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
  end)

  -- Independent Position Toggle
  local utilIndependent = SafeCheckButton("HardcoreHUDUtilIndependent", panelUtilities, "OptionsCheckButtonTemplate")
  utilIndependent:ClearAllPoints()
  utilIndependent:SetPoint("TOPLEFT", utilButtonGap, "BOTTOMLEFT", 0, -20)
  utilIndependent:SetChecked(HardcoreHUDDB.utilities.independent == true)
  if _G[utilIndependent:GetName().."Text"] then _G[utilIndependent:GetName().."Text"]:SetText("Independent Position") end
  utilIndependent:SetScript("OnClick", function(self)
    HardcoreHUDDB.utilities.independent = self:GetChecked()
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
    print("HardcoreHUD: Utility buttons "..(HardcoreHUDDB.utilities.independent and "INDEPENDENT" or "LINKED to health bar"))
  end)

  -- X Offset Slider (when independent)
  local utilOffsetX = CreateFrame("Slider", "HardcoreHUDUtilOffsetX", panelUtilities, "OptionsSliderTemplate")
  utilOffsetX:ClearAllPoints()
  utilOffsetX:SetPoint("TOPLEFT", utilIndependent, "BOTTOMLEFT", 0, -20)
  utilOffsetX:SetMinMaxValues(-500, 500)
  utilOffsetX:SetValueStep(5)
  utilOffsetX:SetValue(HardcoreHUDDB.utilities.offsetX)
  if _G[utilOffsetX:GetName().."Low"] then _G[utilOffsetX:GetName().."Low"]:SetText("-500") end
  if _G[utilOffsetX:GetName().."High"] then _G[utilOffsetX:GetName().."High"]:SetText("500") end
  if _G[utilOffsetX:GetName().."Text"] then _G[utilOffsetX:GetName().."Text"]:SetText("X Offset (Left/Right)") end
  utilOffsetX:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.utilities.offsetX = val
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
  end)

  -- Y Offset Slider (when independent)
  local utilOffsetY = CreateFrame("Slider", "HardcoreHUDUtilOffsetY", panelUtilities, "OptionsSliderTemplate")
  utilOffsetY:ClearAllPoints()
  utilOffsetY:SetPoint("TOPLEFT", utilOffsetX, "BOTTOMLEFT", 0, -34)
  utilOffsetY:SetMinMaxValues(-400, 400)
  utilOffsetY:SetValueStep(5)
  utilOffsetY:SetValue(HardcoreHUDDB.utilities.offsetY)
  if _G[utilOffsetY:GetName().."Low"] then _G[utilOffsetY:GetName().."Low"]:SetText("-400") end
  if _G[utilOffsetY:GetName().."High"] then _G[utilOffsetY:GetName().."High"]:SetText("400") end
  if _G[utilOffsetY:GetName().."Text"] then _G[utilOffsetY:GetName().."Text"]:SetText("Y Offset (Down/Up)") end
  utilOffsetY:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.utilities.offsetY = val
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
  end)

  -- Reset Button for Utilities
  local utilReset = CreateFrame("Button", nil, panelUtilities, "UIPanelButtonTemplate")
  utilReset:ClearAllPoints()
  utilReset:SetPoint("TOPLEFT", utilOffsetY, "BOTTOMLEFT", 0, -20)
  utilReset:SetSize(150, 24)
  utilReset:SetText("Reset to Defaults")
  utilReset:SetScript("OnClick", function()
    HardcoreHUDDB.utilities.buttonSize = 28
    HardcoreHUDDB.utilities.buttonGap = 8
    HardcoreHUDDB.utilities.independent = false
    HardcoreHUDDB.utilities.offsetX = 0
    HardcoreHUDDB.utilities.offsetY = -36
    utilButtonSize:SetValue(28)
    utilButtonGap:SetValue(8)
    utilIndependent:SetChecked(false)
    utilOffsetX:SetValue(0)
    utilOffsetY:SetValue(-36)
    if H.RebuildUtilityButtons then H.RebuildUtilityButtons() end
    print("HardcoreHUD: Utility buttons reset to defaults")
  end)

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:ClearAllPoints()
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 20)
  close:SetSize(140, 26)
  close:SetText("Close")
  close:SetScript("OnClick", function() f:Hide() end)

  -- TTD configuration removed from options; use fixed defaults
  HardcoreHUDDB.spike = HardcoreHUDDB.spike or {}
  HardcoreHUDDB.spike.enabled = true
  HardcoreHUDDB.spike.window = 5
  HardcoreHUDDB.spike.warnThreshold = 3
  HardcoreHUDDB.spike.maxDisplay = 30

  -- 5-second rule overlay opacity (left column, placed after TTD sliders)
  HardcoreHUDDB.ticker = HardcoreHUDDB.ticker or { enabled = true }
  if HardcoreHUDDB.ticker.fsOpacity == nil then HardcoreHUDDB.ticker.fsOpacity = 0.25 end
  local fsOpacity = CreateFrame("Slider", "HardcoreHUDFiveSecOpacity", panelLayout, "OptionsSliderTemplate")
  fsOpacity:ClearAllPoints()
  -- Anchor fsOpacity under multi (layout related)
  fsOpacity:SetPoint("TOPLEFT", multi, "BOTTOMLEFT", 0, -34)
  fsOpacity:SetMinMaxValues(0.05, 0.80)
  fsOpacity:SetValueStep(0.05)
  fsOpacity:SetValue(HardcoreHUDDB.ticker.fsOpacity)
  if _G[fsOpacity:GetName().."Low"] then _G[fsOpacity:GetName().."Low"]:SetText("5%") end
  if _G[fsOpacity:GetName().."High"] then _G[fsOpacity:GetName().."High"]:SetText("80%") end
  if _G[fsOpacity:GetName().."Text"] then _G[fsOpacity:GetName().."Text"]:SetText("5s Overlay Opacity") end
  fsOpacity:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.ticker.fsOpacity = val
    if H.bars and H.bars.fsFill and HardcoreHUDDB.colors and HardcoreHUDDB.colors.fiveSec then
      local r,g,b = HardcoreHUDDB.colors.fiveSec[1], HardcoreHUDDB.colors.fiveSec[2], HardcoreHUDDB.colors.fiveSec[3]
      H.bars.fsFill:SetColorTexture(r,g,b,val)
      if H.bars.fsFill.SetBlendMode then H.bars.fsFill:SetBlendMode("ADD") end
    end
  end)

  -- Remove "Always Show TTD" option; TTD shows in combat by design

  -- Minimap button to open options (created in Core.Init for reliability)

  -- Minimal slash options remain
  SLASH_HARDCOREHUD1 = "/hardhud"
  SLASH_HARDCOREHUD2 = "/hh"
  SlashCmdList["HARDCOREHUD"] = function(msg)
    local a = {}; for t in string.gmatch(msg, "[^%s]+") do table.insert(a,t) end
    local cmd = string.lower(a[1] or "help")
    if cmd == "help" or cmd == "options" or cmd == "" then
      if H.optionsFrame then
        if H.optionsFrame:IsShown() then
          H.optionsFrame:Hide()
        else
          H.optionsFrame:Show()
        end
      end
      return
    end
    if cmd == "help" then
      print("HardcoreHUD:")
      print("/hardhud width <n> | height <n>")
      print("/hardhud color hp|mana|energy|rage r g b")
      print("/hardhud lock | unlock")
      print("/hardhud warn critical on|off | skull on|off")
      print("/hardhud testoom | testhp - Test overlays")
    elseif cmd == "testoom" then
      if not H.oomOverlay then H.InitOOMOverlay() end
      if H.oomOverlay then
        H.oomOverlay._pulse.active = true
        local ok, err = pcall(function() H.oomOverlay:Show() end)
        if ok then
          print("OOM overlay shown - hiding in 3 seconds")
          C_Timer.After(3, function()
            H.oomOverlay._pulse.active = false
            pcall(function() H.oomOverlay:Hide() end)
          end)
        else
          print("OOM overlay Show() failed:", err)
        end
      else
        print("OOM overlay failed to initialize")
      end
    elseif cmd == "testhp" then
      if not H.critOverlay then H.InitCriticalOverlay() end
      if H.critOverlay then
        local ok, err = pcall(function() H.critOverlay:Show() end)
        if ok then
          print("Critical HP overlay shown - hiding in 3 seconds")
          C_Timer.After(3, function() pcall(function() H.critOverlay:Hide() end) end)
        else
          print("Critical HP overlay Show() failed:", err)
        end
      else
        print("Critical HP overlay failed to initialize")
      end
    elseif cmd == "width" and tonumber(a[2]) then
      local w = tonumber(a[2]); HardcoreHUDDB.size.width=w; H.root:SetWidth(w); H.bars.hp:SetWidth(w); H.bars.pow:SetWidth(w); if H.bars.fs then H.bars.fs:SetWidth(w) end; if H.bars.tick then H.bars.tick:SetWidth(w) end; H.LayoutCombo()
    elseif cmd == "height" and tonumber(a[2]) then
      local h = tonumber(a[2]); HardcoreHUDDB.size.height=h; H.root:SetHeight(h); H.bars.hp:SetHeight(h); H.bars.pow:SetHeight(h)
    elseif cmd == "color" and a[2] and a[3] and a[4] and a[5] then
      local key = string.lower(a[2]); local r,g,b = tonumber(a[3]), tonumber(a[4]), tonumber(a[5])
      if HardcoreHUDDB.colors[key] then HardcoreHUDDB.colors[key] = {r,g,b}; H.UpdateBarColors() else print("Unknown color key") end
    elseif cmd == "lock" then H.root:SetMovable(false); print("Locked")
      elseif cmd == "lock" then H.root:SetMovable(false); print("HUD locked")
    elseif cmd == "unlock" then H.root:SetMovable(true); print("Unlocked")
      elseif cmd == "unlock" then H.root:SetMovable(true); print("HUD unlocked")
    elseif cmd == "warn" and a[2] == "enable" and a[3] then
      HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
      HardcoreHUDDB.warnings.enabled = (a[3] == "on")
      print("Warnings: "..((HardcoreHUDDB.warnings.enabled ~= false) and "ON" or "OFF"))
      if HardcoreHUDDB.warnings.enabled == false then
        -- Hide any active warning visuals immediately
        if H.HideCriticalHPWarning then H.HideCriticalHPWarning() end
        if H.skull then H.skull:Hide() end
        if H.EliteAttentionText then H.EliteAttentionText:Hide() end
        if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
      end
    elseif cmd == "warn" and a[2] == "critical" and a[3] then
      HardcoreHUDDB.warnings.criticalHP = (a[3] == "on"); print("Critical HP warn: "..(HardcoreHUDDB.warnings.criticalHP and "ON" or "OFF"))
      HardcoreHUDDB.warnings.criticalHP = (a[3] == "on"); print("Critical HP warning: "..(HardcoreHUDDB.warnings.criticalHP and "ON" or "OFF"))
    elseif cmd == "warn" and a[2] == "skull" and a[3] then
      HardcoreHUDDB.warnings.levelElite = (a[3] == "on"); print("Skull warn: "..(HardcoreHUDDB.warnings.levelElite and "ON" or "OFF"))
      HardcoreHUDDB.warnings.levelElite = (a[3] == "on"); print("Elite/+2 skull: "..(HardcoreHUDDB.warnings.levelElite and "ON" or "OFF"))
    elseif cmd == "warn" and a[2] == "perf" and a[3] then
      HardcoreHUDDB.warnings.latency = (a[3] == "on")
      print("Perf warn: "..(HardcoreHUDDB.warnings.latency and "ON" or "OFF"))
      if not HardcoreHUDDB.warnings.latency and H.perfWarn then H.perfWarn:Hide() end
    elseif cmd == "remind" and a[2] and (a[2]=="on" or a[2]=="off") then
      HardcoreHUDDB.reminders = HardcoreHUDDB.reminders or {}
      HardcoreHUDDB.reminders.enabled = (a[2]=="on")
      print("HardcoreHUD: Reminders "..(HardcoreHUDDB.reminders.enabled and "ON" or "OFF"))
      if not HardcoreHUDDB.reminders.enabled and H.reminderFrame then H.reminderFrame:Hide() end
      if HardcoreHUDDB.reminders.enabled and H.InitReminders then H.InitReminders() end
    elseif cmd == "remind" and a[2] == "test" then
      if H.InitReminders then H.InitReminders() end
      if H.UpdateReminders then H.UpdateReminders() end
      if H.reminderFrame then H.reminderFrame:Show() end
      print("HardcoreHUD: reminder test triggered")
    elseif cmd == "remind" and a[2] == "print" then
      if H.InitReminders then H.InitReminders() end
      if H.UpdateReminders then H.UpdateReminders() end
      if H and H.DebugListReminders then H.DebugListReminders() end
    elseif cmd == "debug" and a[2] == "reminders" and a[3] then
      HardcoreHUDDB.debug = HardcoreHUDDB.debug or {}
      HardcoreHUDDB.debug.reminders = (a[3]=="on")
      print("HardcoreHUD: reminders debug="..(HardcoreHUDDB.debug.reminders and "ON" or "OFF"))
    elseif cmd == "debug" and a[2] == "potions" and a[3] then
      HardcoreHUDDB.debug = HardcoreHUDDB.debug or {}
      HardcoreHUDDB.debug.potions = (a[3]=="on")
      print("HardcoreHUD: potions debug="..(HardcoreHUDDB.debug.potions and "ON" or "OFF"))
    elseif cmd == "debug" and a[2] == "utilversion" then
      print("HardcoreHUD: UtilitiesVersion="..(HardcoreHUD.UtilitiesVersion or "unknown"))
    elseif cmd == "zones" then
      if H.ShowZonesWindow then H.ShowZonesWindow() else print("HardcoreHUD: Zones window not available") end
    elseif cmd == "debug" and a[2] == "multiaggro" and a[3] then
      HardcoreHUDDB.debugMultiAggro = (a[3] == "on")
      print("HardcoreHUD: debugMultiAggro="..(HardcoreHUDDB.debugMultiAggro and "ON" or "OFF"))
    elseif cmd == "tooltip" and a[2] == "simple" and a[3] then
      HardcoreHUDDB.tooltip = HardcoreHUDDB.tooltip or {}
      HardcoreHUDDB.tooltip.simple = (a[3] == "on")
      print("HardcoreHUD: simple tooltip="..(HardcoreHUDDB.tooltip.simple and "ON" or "OFF"))
    elseif cmd == "debug" and a[2] == "tooltips" and a[3] then
      HardcoreHUDDB.debug = HardcoreHUDDB.debug or {}
      HardcoreHUDDB.debug.tooltips = (a[3] == "on")
      print("HardcoreHUD: tooltip debug="..(HardcoreHUDDB.debug.tooltips and "ON" or "OFF"))
    elseif cmd == "rep" or cmd == "reputation" then
      -- Toggle reputation tracker
      if H.ToggleReputationTracker then
        H.ToggleReputationTracker()
      else
        print("HardcoreHUD: Reputation tracker not available")
      end
    elseif cmd == "rep" and a[2] == "debug" then
      -- Toggle rep debug mode
      HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
      HardcoreHUDDB.reputation.debug = not HardcoreHUDDB.reputation.debug
      print("HardcoreHUD: Rep debug = " .. (HardcoreHUDDB.reputation.debug and "ON" or "OFF"))
      if HardcoreHUDDB.reputation.debug then
        print("HardcoreHUD: Kill a mob to see raw rep message")
      end
    elseif cmd == "rep" and a[2] == "reset" then
      -- Reset detected rep values
      HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or {}
      HardcoreHUDDB.reputation.lastDetectedRep = nil
      HardcoreHUDDB.reputation.autoDetected = false
      HardcoreHUDDB.reputation.detectedRep = {}
      print("HardcoreHUD: Rep detection reset. Kill a mob to re-detect.")
      if H.UpdateReputationTracker then H.UpdateReputationTracker() end
    elseif cmd == "rep" and a[2] then
      -- Set faction: /hh rep <faction name>
      local factionName = table.concat(a, " ", 2)
      if H.SetTrackedFaction then
        H.SetTrackedFaction(factionName)
      end
    elseif cmd == "emergency" and a[2] and (a[2] == "on" or a[2] == "off") then
      HardcoreHUDDB.emergency = HardcoreHUDDB.emergency or { enabled = true, hpThreshold = 0.50 }
      HardcoreHUDDB.emergency.enabled = (a[2] == "on")
      print("HardcoreHUD: emergency pulse="..(HardcoreHUDDB.emergency.enabled and "ON" or "OFF"))
      if HardcoreHUDEmergencyEnable then HardcoreHUDEmergencyEnable:SetChecked(HardcoreHUDDB.emergency.enabled) end
    elseif cmd == "emergency" and a[2] == "hp" and a[3] and tonumber(a[3]) then
      local v = tonumber(a[3])
      if v > 0 and v <= 1 then
        HardcoreHUDDB.emergency = HardcoreHUDDB.emergency or { enabled = true, hpThreshold = 0.50 }
        HardcoreHUDDB.emergency.hpThreshold = v
        print("HardcoreHUD: emergency hpThreshold="..math.floor(v*100+0.5).."%")
        if HardcoreHUDEmergencyHPSlider then HardcoreHUDEmergencyHPSlider:SetValue(v) end
      else
        print("HardcoreHUD: /hardhud emergency hp <0.15-0.90>")
      end
    else
      print("/hardhud help")
    end
  end

  -- Target Marks Panel
  HardcoreHUDDB.targetMarks = HardcoreHUDDB.targetMarks or { enabled = true, locked = false, pos = { x = 0, y = -280 } }
  
  local tmTitle = panelTargetMarks:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  tmTitle:SetPoint("TOPLEFT", panelTargetMarks, "TOPLEFT", 0, -8)
  tmTitle:SetText("Target Mark Bar")

  local tmToggle = SafeCheckButton("HardcoreHUDTargetMarksToggle", panelTargetMarks, "OptionsCheckButtonTemplate")
  tmToggle:ClearAllPoints()
  tmToggle:SetPoint("TOPLEFT", tmTitle, "BOTTOMLEFT", 0, -16)
  tmToggle:SetChecked(HardcoreHUDDB.targetMarks.enabled ~= false)
  if _G[tmToggle:GetName().."Text"] then _G[tmToggle:GetName().."Text"]:SetText("Show Target Mark Bar") end
  tmToggle:SetScript("OnClick", function(self)
    local isChecked = self:GetChecked()
    HardcoreHUDDB.targetMarks.enabled = isChecked
    if not H.targetMarkBar then H.InitTargetMarkBar() end
    if isChecked then
      H.targetMarkBar:Show()
      print("HardcoreHUD: Target mark bar ON")
    else
      H.targetMarkBar:Hide()
      print("HardcoreHUD: Target mark bar OFF")
    end
  end)
  tmToggle:SetFrameStrata("FULLSCREEN_DIALOG")
  tmToggle:SetFrameLevel(panelTargetMarks:GetFrameLevel()+1)

  local tmDesc = panelTargetMarks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tmDesc:SetPoint("TOPLEFT", tmToggle, "BOTTOMLEFT", 0, -20)
  tmDesc:SetText("Mark your target with raid markers (Star, Circle, Diamond, etc)\nDrag the bar to reposition it\nButtons available in combat")
  tmDesc:SetTextColor(0.7, 0.7, 0.7, 1)
  tmDesc:SetJustifyH("LEFT")

  -- Leveling Panel
  HardcoreHUDDB.leveling = HardcoreHUDDB.leveling or { enabled = true, locked = false, pos = { x = 0, y = -400 }, showXPBar = true, showRate = true, showTimeToLevel = true, showRested = true, showSessionTime = true }
  
  local lvTitle = panelLeveling:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  lvTitle:SetPoint("TOPLEFT", panelLeveling, "TOPLEFT", 0, -8)
  lvTitle:SetText("Leveling Tracker")

  local lvToggle = SafeCheckButton("HardcoreHUDLevelingToggle", panelLeveling, "OptionsCheckButtonTemplate")
  lvToggle:ClearAllPoints()
  lvToggle:SetPoint("TOPLEFT", lvTitle, "BOTTOMLEFT", 0, -16)
  lvToggle:SetChecked(HardcoreHUDDB.leveling.enabled ~= false)
  if _G[lvToggle:GetName().."Text"] then _G[lvToggle:GetName().."Text"]:SetText("Show Leveling Tracker") end
  lvToggle:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.enabled = self:GetChecked()
    if not H.levelingTracker then H.InitLevelingTracker() end
    if self:GetChecked() then
      H.levelingTracker:Show()
      print("HardcoreHUD: Leveling tracker ON")
    else
      H.levelingTracker:Hide()
      print("HardcoreHUD: Leveling tracker OFF")
    end
  end)

  -- Show options
  local lvXPBar = SafeCheckButton("HardcoreHUDLevelingXPBar", panelLeveling, "OptionsCheckButtonTemplate")
  lvXPBar:ClearAllPoints()
  lvXPBar:SetPoint("TOPLEFT", lvToggle, "BOTTOMLEFT", 0, -12)
  lvXPBar:SetChecked(HardcoreHUDDB.leveling.showXPBar ~= false)
  if _G[lvXPBar:GetName().."Text"] then _G[lvXPBar:GetName().."Text"]:SetText("Show XP Bar") end
  lvXPBar:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.showXPBar = self:GetChecked()
    if H.UpdateLevelingTracker then H.UpdateLevelingTracker() end
  end)

  local lvRate = SafeCheckButton("HardcoreHUDLevelingRate", panelLeveling, "OptionsCheckButtonTemplate")
  lvRate:ClearAllPoints()
  lvRate:SetPoint("TOPLEFT", lvXPBar, "BOTTOMLEFT", 0, -10)
  lvRate:SetChecked(HardcoreHUDDB.leveling.showRate ~= false)
  if _G[lvRate:GetName().."Text"] then _G[lvRate:GetName().."Text"]:SetText("Show XP/Hour Rate") end
  lvRate:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.showRate = self:GetChecked()
    if H.UpdateLevelingTracker then H.UpdateLevelingTracker() end
  end)

  local lvTime = SafeCheckButton("HardcoreHUDLevelingTime", panelLeveling, "OptionsCheckButtonTemplate")
  lvTime:ClearAllPoints()
  lvTime:SetPoint("TOPLEFT", lvRate, "BOTTOMLEFT", 0, -10)
  lvTime:SetChecked(HardcoreHUDDB.leveling.showTimeToLevel ~= false)
  if _G[lvTime:GetName().."Text"] then _G[lvTime:GetName().."Text"]:SetText("Show Time to Level") end
  lvTime:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.showTimeToLevel = self:GetChecked()
    if H.UpdateLevelingTracker then H.UpdateLevelingTracker() end
  end)

  local lvRested = SafeCheckButton("HardcoreHUDLevelingRested", panelLeveling, "OptionsCheckButtonTemplate")
  lvRested:ClearAllPoints()
  lvRested:SetPoint("TOPLEFT", lvTime, "BOTTOMLEFT", 0, -10)
  lvRested:SetChecked(HardcoreHUDDB.leveling.showRested ~= false)
  if _G[lvRested:GetName().."Text"] then _G[lvRested:GetName().."Text"]:SetText("Show Rested XP") end
  lvRested:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.showRested = self:GetChecked()
    if H.UpdateLevelingTracker then H.UpdateLevelingTracker() end
  end)

  local lvSession = SafeCheckButton("HardcoreHUDLevelingSession", panelLeveling, "OptionsCheckButtonTemplate")
  lvSession:ClearAllPoints()
  lvSession:SetPoint("TOPLEFT", lvRested, "BOTTOMLEFT", 0, -10)
  lvSession:SetChecked(HardcoreHUDDB.leveling.showSessionTime ~= false)
  if _G[lvSession:GetName().."Text"] then _G[lvSession:GetName().."Text"]:SetText("Show Session Time") end
  lvSession:SetScript("OnClick", function(self)
    HardcoreHUDDB.leveling.showSessionTime = self:GetChecked()
    if H.UpdateLevelingTracker then H.UpdateLevelingTracker() end
  end)

  local lvDesc = panelLeveling:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lvDesc:SetPoint("TOPLEFT", lvSession, "BOTTOMLEFT", 0, -16)
  lvDesc:SetText("Displays XP progress, leveling speed, and time to level\nSelect which information to display\nDrag to reposition or lock position")
  lvDesc:SetTextColor(0.7, 0.7, 0.7, 1)
  lvDesc:SetJustifyH("LEFT")
  
  -- ============================================================================
  -- Reputation Panel
  -- ============================================================================
  HardcoreHUDDB.reputation = HardcoreHUDDB.reputation or { 
    enabled = false, 
    selectedFaction = "Timbermaw Hold", 
    customRepPerMob = 10,
    locked = false,
    pos = { x = 200, y = -350 }
  }
  
  local repTitle = panelReputation:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  repTitle:SetPoint("TOPLEFT", panelReputation, "TOPLEFT", 0, -8)
  repTitle:SetText("Reputation Tracker")
  
  -- Toggle checkbox
  local repToggle = SafeCheckButton("HardcoreHUDRepToggle", panelReputation, "OptionsCheckButtonTemplate")
  repToggle:ClearAllPoints()
  repToggle:SetPoint("TOPLEFT", repTitle, "BOTTOMLEFT", 0, -16)
  repToggle:SetChecked(HardcoreHUDDB.reputation.enabled == true)
  if _G[repToggle:GetName().."Text"] then _G[repToggle:GetName().."Text"]:SetText("Show Reputation Tracker") end
  repToggle:SetScript("OnClick", function(self)
    HardcoreHUDDB.reputation.enabled = self:GetChecked()
    if not H.reputationTracker then H.InitReputationTracker() end
    if self:GetChecked() then
      H.reputationTracker:Show()
      H.UpdateReputationTracker()
      print("HardcoreHUD: Reputation tracker ON")
    else
      H.reputationTracker:Hide()
      print("HardcoreHUD: Reputation tracker OFF")
    end
  end)
  
  -- Lock checkbox
  local repLock = SafeCheckButton("HardcoreHUDRepLock", panelReputation, "OptionsCheckButtonTemplate")
  repLock:ClearAllPoints()
  repLock:SetPoint("TOPLEFT", repToggle, "BOTTOMLEFT", 0, -10)
  repLock:SetChecked(HardcoreHUDDB.reputation.locked == true)
  if _G[repLock:GetName().."Text"] then _G[repLock:GetName().."Text"]:SetText("Lock Position") end
  repLock:SetScript("OnClick", function(self)
    HardcoreHUDDB.reputation.locked = self:GetChecked()
  end)
  
  -- Faction Selection Label
  local repFactionLabel = panelReputation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  repFactionLabel:SetPoint("TOPLEFT", repLock, "BOTTOMLEFT", 0, -20)
  repFactionLabel:SetText("Select Faction:")
  repFactionLabel:SetTextColor(1, 0.84, 0, 1)
  
  -- Faction Dropdown: build from character factions + common capitals (avoid duplicates)
  local factionsMap = {}
  -- Add factions the character currently has
  local charFactions = H.GetCharacterFactions and H.GetCharacterFactions() or {}
  for name, _ in pairs(charFactions) do factionsMap[name] = true end

  -- Do not add hardcoded capital names here. Only include factions the character
  -- actually has or those present in `FACTION_DATA` to avoid showing non-existent
  -- entries (e.g. "Exodar" on clients without that reputation).

  -- Also add known special factions from FACTION_DATA so defaults remain selectable
  for k, _ in pairs(H.GetFactionData and H.GetFactionData() or {}) do factionsMap[k] = true end

  -- Convert map to sorted array
  local factions = {}
  for name, _ in pairs(factionsMap) do table.insert(factions, name) end
  table.sort(factions)
  
  -- Dropdown-style selector (compact): shows current selection and opens a popup list
  local dropdown = CreateFrame("Button", "HardcoreHUDRepDropdown", panelReputation, "UIPanelButtonTemplate")
  dropdown:SetPoint("TOPLEFT", repFactionLabel, "BOTTOMLEFT", 0, -8)
  dropdown:SetSize(220, 22)
  dropdown:SetText(HardcoreHUDDB.reputation.selectedFaction or "Select Faction")

  local dropdownFrame = CreateFrame("Frame", "HardcoreHUDRepDropdownFrame", panelReputation)
  dropdownFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -6)
  dropdownFrame:SetSize(220, 200)
  dropdownFrame:Hide()

  -- Close dropdown when clicking outside
  dropdownFrame:SetScript("OnHide", function(self)
    -- nothing for now
  end)

  -- Populate dropdown with faction names (re-use `factions` array)
  for i, factionName in ipairs(factions) do
    local btn = CreateFrame("Button", nil, dropdownFrame, "UIPanelButtonTemplate")
    btn:SetSize(208, 20)
    btn:SetPoint("TOPLEFT", dropdownFrame, "TOPLEFT", 6, -((i-1) * 22))
    btn:SetText(factionName)
    btn:SetScript("OnClick", function()
      HardcoreHUDDB.reputation.selectedFaction = factionName
      dropdown:SetText(factionName)
      dropdownFrame:Hide()
      if H.SetTrackedFaction then H.SetTrackedFaction(factionName) end
      if H.UpdateReputationTracker then H.UpdateReputationTracker() end
    end)
  end

  dropdown:SetScript("OnClick", function(self)
    if dropdownFrame:IsShown() then dropdownFrame:Hide() else dropdownFrame:Show() end
  end)

  -- Close button for the dropdown
  local closeBtn = CreateFrame("Button", nil, dropdownFrame, "UIPanelButtonTemplate")
  closeBtn:SetSize(208, 20)
  closeBtn:SetPoint("BOTTOMLEFT", dropdownFrame, "BOTTOMLEFT", 6, 6)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function() dropdownFrame:Hide() end)
  
  -- Rep per mob slider (right column)
  local repPerMobLabel = panelReputation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  repPerMobLabel:SetPoint("TOPLEFT", panelReputation, "TOPLEFT", 280, -60)
  repPerMobLabel:SetText("Rep per Mob (Custom):")
  
  local repPerMobSlider = CreateFrame("Slider", "HardcoreHUDRepPerMobSlider", panelReputation, "OptionsSliderTemplate")
  repPerMobSlider:ClearAllPoints()
  repPerMobSlider:SetPoint("TOPLEFT", repPerMobLabel, "BOTTOMLEFT", 0, -16)
  repPerMobSlider:SetMinMaxValues(1, 100)
  repPerMobSlider:SetValueStep(1)
  repPerMobSlider:SetValue(HardcoreHUDDB.reputation.customRepPerMob or 10)
  if _G[repPerMobSlider:GetName().."Low"] then _G[repPerMobSlider:GetName().."Low"]:SetText("1") end
  if _G[repPerMobSlider:GetName().."High"] then _G[repPerMobSlider:GetName().."High"]:SetText("100") end
  if _G[repPerMobSlider:GetName().."Text"] then _G[repPerMobSlider:GetName().."Text"]:SetText("Rep/Mob: " .. (HardcoreHUDDB.reputation.customRepPerMob or 10)) end
  repPerMobSlider:SetScript("OnValueChanged", function(self, val)
    val = math.floor(val)
    HardcoreHUDDB.reputation.customRepPerMob = val
    if _G[self:GetName().."Text"] then _G[self:GetName().."Text"]:SetText("Rep/Mob: " .. val) end
    if H.UpdateReputationTracker then H.UpdateReputationTracker() end
  end)
  
  -- Info text
  local repInfo = panelReputation:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  repInfo:SetPoint("TOPLEFT", repPerMobSlider, "BOTTOMLEFT", 0, -30)
  repInfo:SetWidth(240)
  repInfo:SetText("The tracker shows how many mobs you need to kill to reach the next reputation standing.\n\nFaction default rep values are used automatically, but you can override with the slider above.\n\nHover over the tracker in-game to see turn-in options.")
  repInfo:SetTextColor(0.7, 0.7, 0.7, 1)
  repInfo:SetJustifyH("LEFT")
  
  local repDesc = panelReputation:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  repDesc:SetPoint("BOTTOMLEFT", panelReputation, "BOTTOMLEFT", 0, 10)
  repDesc:SetText("Tip: Type /hh rep or /hh reputation to toggle the tracker")
  repDesc:SetTextColor(0.5, 0.5, 0.5, 1)
  repDesc:SetJustifyH("LEFT")

  -- Register with Blizzard Interface Options on PLAYER_LOGIN
  local regFrame = CreateFrame("Frame")
  regFrame:RegisterEvent("PLAYER_LOGIN")
  regFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
      -- Set frame properties for Interface Options
      f.name = "HardcoreHUD"
      f.parent = nil
      f.okay = function() end
      f.cancel = function() end
      f.default = function()
        print("HardcoreHUD: Reset to defaults (not implemented)")
      end
      f.refresh = function() end
      
      -- Try registration
      if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(f)
        print("HardcoreHUD: Registered with Interface Options")
      else
        print("HardcoreHUD: Classic Interface Options API not available - use /hh to open options")
      end
      
      self:UnregisterEvent("PLAYER_LOGIN")
    end
  end)
end
