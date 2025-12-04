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
  f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} })
  f:SetBackdropColor(0,0,0,0.8)
  f:Hide()
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("HardcoreHUD Options")

  -- Column containers for cleaner layout
  local leftCol = CreateFrame("Frame", nil, f)
  leftCol:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -50)
  leftCol:SetSize(260, f:GetHeight()-100)
  local middleCol = CreateFrame("Frame", nil, f)
  middleCol:SetPoint("TOP", f, "TOP", 0, -50)
  middleCol:SetSize(260, f:GetHeight()-100)
  local rightCol = CreateFrame("Frame", nil, f)
  rightCol:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -50)
  rightCol:SetSize(260, f:GetHeight()-100)
  -- Ensure columns have proper hit testing and draw order
  leftCol:EnableMouse(false)
  middleCol:EnableMouse(false)
  -- Enable mouse on right column so its buttons receive clicks
  rightCol:EnableMouse(true)
  leftCol:SetFrameStrata("MEDIUM")
  middleCol:SetFrameStrata("MEDIUM")
  -- Make right column draw at same strata/level to avoid overlaying left/middle
  -- Match options frame strata so right-column buttons sit on the same window
  rightCol:SetFrameStrata("FULLSCREEN_DIALOG")
  rightCol:SetFrameLevel(f:GetFrameLevel()+10)

  -- Thickness slider (left column)
  local thickness = CreateFrame("Slider", "HardcoreHUDThicknessSlider", f, "OptionsSliderTemplate")
  thickness:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 20, 0)
  thickness:SetMinMaxValues(6, 32)
  thickness:SetValueStep(1)
  thickness:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.thickness or 12)
  if _G[thickness:GetName().."Low"] then _G[thickness:GetName().."Low"]:SetText("6") end
  if _G[thickness:GetName().."High"] then _G[thickness:GetName().."High"]:SetText("32") end
  if _G[thickness:GetName().."Text"] then _G[thickness:GetName().."Text"]:SetText("Dicke") end
    if _G[thickness:GetName().."Text"] then _G[thickness:GetName().."Text"]:SetText("Thickness") end
  thickness:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.thickness = val
    H.ApplyLayout()
  end)

  
  local height = CreateFrame("Slider", "HardcoreHUDHeightSlider", f, "OptionsSliderTemplate")
  height:ClearAllPoints()
  height:SetPoint("TOPLEFT", thickness, "BOTTOMLEFT", 0, -34)
  height:SetMinMaxValues(120, 320)
  height:SetValueStep(10)
  height:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.height or 200)
  if _G[height:GetName().."Low"] then _G[height:GetName().."Low"]:SetText("120") end
  if _G[height:GetName().."High"] then _G[height:GetName().."High"]:SetText("320") end
  if _G[height:GetName().."Text"] then _G[height:GetName().."Text"]:SetText("Höhe") end
    if _G[height:GetName().."Text"] then _G[height:GetName().."Text"]:SetText("Height") end
  height:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.height = val
    H.ApplyLayout()
  end)
  -- Separation slider
  local sep = CreateFrame("Slider", "HardcoreHUDSeparationSlider", f, "OptionsSliderTemplate")
  sep:ClearAllPoints()
  sep:SetPoint("TOPLEFT", height, "BOTTOMLEFT", 0, -34)
  sep:SetMinMaxValues(80, 240)
  sep:SetValueStep(10)
  sep:SetValue(HardcoreHUDDB.layout and HardcoreHUDDB.layout.separation or 140)
  if _G[sep:GetName().."Low"] then _G[sep:GetName().."Low"]:SetText("80") end
  if _G[sep:GetName().."High"] then _G[sep:GetName().."High"]:SetText("240") end
  if _G[sep:GetName().."Text"] then _G[sep:GetName().."Text"]:SetText("Abstand zur Mitte") end
    if _G[sep:GetName().."Text"] then _G[sep:GetName().."Text"]:SetText("Separation from Center") end
  sep:SetScript("OnValueChanged", function(self, val)
    HardcoreHUDDB.layout = HardcoreHUDDB.layout or {}
    HardcoreHUDDB.layout.separation = val
    H.ApplyLayout()
  end)

  -- Warning master + toggles (middle column)
  -- Master enable warnings
  local warnEnable = CreateFrame("CheckButton", "HardcoreHUDWarnEnable", f, "OptionsCheckButtonTemplate")
  warnEnable:ClearAllPoints()
  warnEnable:SetPoint("TOPLEFT", middleCol, "TOPLEFT", 0, 0)
  HardcoreHUDDB.warnings.enabled = (HardcoreHUDDB.warnings.enabled ~= false)
  warnEnable:SetChecked(HardcoreHUDDB.warnings.enabled)
  if _G[warnEnable:GetName().."Text"] then _G[warnEnable:GetName().."Text"]:SetText("Warnings Enabled") end
  warnEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.enabled = self:GetChecked()
    print("HardcoreHUD: Warnings "..(HardcoreHUDDB.warnings.enabled and "ON" or "OFF"))
    if not HardcoreHUDDB.warnings.enabled then
      if H.HideCriticalHPWarning then H.HideCriticalHPWarning() end
    lock:SetPoint("TOPLEFT", critThresh, "BOTTOMLEFT", 0, -18)
      if H.EliteAttentionText then H.EliteAttentionText:Hide() end
      if H.eliteIcons then for _,ic in ipairs(H.eliteIcons) do ic:Hide() end end
    else
      if H.CheckSkull then H.CheckSkull() end
      if H.EvaluateMultiAggro then H.EvaluateMultiAggro() end
    end
  end)
  local crit = CreateFrame("CheckButton", "HardcoreHUDCritWarn", f, "OptionsCheckButtonTemplate")
  crit:ClearAllPoints()
  crit:SetPoint("TOPLEFT", warnEnable, "BOTTOMLEFT", 0, -18)
  crit:SetChecked(HardcoreHUDDB.warnings.criticalHP)
  if _G[crit:GetName().."Text"] then _G[crit:GetName().."Text"]:SetText("Kritische HP Warnung") end
    if _G[crit:GetName().."Text"] then _G[crit:GetName().."Text"]:SetText("Critical HP Warning") end
  crit:SetScript("OnClick", function(self) HardcoreHUDDB.warnings.criticalHP = self:GetChecked() end)

  local skull = CreateFrame("CheckButton", "HardcoreHUDSkullWarn", f, "OptionsCheckButtonTemplate")
  skull:ClearAllPoints()
  skull:SetPoint("TOPLEFT", crit, "BOTTOMLEFT", 0, -18)
  skull:SetChecked(HardcoreHUDDB.warnings.levelElite)
  if _G[skull:GetName().."Text"] then _G[skull:GetName().."Text"]:SetText("Elite/+2 Level Totenkopf") end
    if _G[skull:GetName().."Text"] then _G[skull:GetName().."Text"]:SetText("Elite/+2 Level Skull") end
  skull:SetScript("OnClick", function(self) HardcoreHUDDB.warnings.levelElite = self:GetChecked(); H.CheckSkull() end)

  -- Latency/FPS warning toggle (performance)
  local perf = CreateFrame("CheckButton", "HardcoreHUDPerfWarn", f, "OptionsCheckButtonTemplate")
  perf:ClearAllPoints()
  perf:SetPoint("TOPLEFT", skull, "BOTTOMLEFT", 0, -18)
  HardcoreHUDDB.warnings.latency = (HardcoreHUDDB.warnings.latency ~= false)
  perf:SetChecked(HardcoreHUDDB.warnings.latency)
  if _G[perf:GetName().."Text"] then _G[perf:GetName().."Text"]:SetText("Latenz/FPS Warnung") end
    if _G[perf:GetName().."Text"] then _G[perf:GetName().."Text"]:SetText("Latency/FPS Warning") end
  perf:SetScript("OnClick", function(self)
    HardcoreHUDDB.warnings.latency = self:GetChecked()
    if not HardcoreHUDDB.warnings.latency and H.perfWarn then H.perfWarn:Hide() end
    print("HardcoreHUD: perf warning "..(HardcoreHUDDB.warnings.latency and "ON" or "OFF"))
  end)

  -- Critical HP threshold slider
  HardcoreHUDDB.warnings = HardcoreHUDDB.warnings or {}
  if HardcoreHUDDB.warnings.criticalThreshold == nil then HardcoreHUDDB.warnings.criticalThreshold = 0.20 end
  local critThresh = CreateFrame("Slider", "HardcoreHUDCritThreshold", f, "OptionsSliderTemplate")
  critThresh:ClearAllPoints()
  -- Move Critical HP Threshold to the right column below reminder categories
  critThresh:SetPoint("TOPLEFT", rCore, "BOTTOMLEFT", 0, -34)
  critThresh:SetMinMaxValues(0.15, 0.50)
  critThresh:SetValueStep(0.01)
  if critThresh.SetObeyStepOnDrag then critThresh:SetObeyStepOnDrag(true) end
  if _G[critThresh:GetName().."Low"] then _G[critThresh:GetName().."Low"]:SetText("15%") end
  if _G[critThresh:GetName().."High"] then _G[critThresh:GetName().."High"]:SetText("50%") end
  if _G[critThresh:GetName().."Text"] then _G[critThresh:GetName().."Text"]:SetText("Critical HP Threshold") end
  critThresh:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.warnings.criticalThreshold = val
    print("HardcoreHUD: Critical HP threshold = "..math.floor(val*100+0.5).."%")
    if H.UpdateHealth then H.UpdateHealth() end
  end)

  -- (Rounded and texture options removed)

  -- HUD lock/move controls
  -- Multi-aggro threshold slider (2-5)
  -- Multi-aggro threshold slider (left column under separation)
  local multi = CreateFrame("Slider", "HardcoreHUDMultiAggroSlider", f, "OptionsSliderTemplate")
  multi:ClearAllPoints()
  multi:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -34)
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

  -- (moved Five-second rule opacity slider below TTD sliders to avoid nil anchor)

  local lock = CreateFrame("CheckButton", "HardcoreHUDLock", f, "InterfaceOptionsCheckButtonTemplate")
  lock:ClearAllPoints()
  -- Return Lock HUD to middle column under performance toggle
  lock:SetPoint("TOPLEFT", perf, "BOTTOMLEFT", 0, -18)
  lock:SetSize(24,24)
  lock:SetChecked(true)
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
  if _G[lock:GetName().."Text"] then _G[lock:GetName().."Text"]:SetText("HUD sperren (Drag deaktivieren)") end
    if _G[lock:GetName().."Text"] then _G[lock:GetName().."Text"]:SetText("Lock HUD (disable drag)") end
  lock:SetScript("OnClick", function(self)
    local isLocked = self:GetChecked()
    HardcoreHUDDB.lock = isLocked
    if H.ApplyLock then H.ApplyLock() end
    H.root:SetMovable(not isLocked)
    if isLocked then
      H.root:EnableMouse(false)
      print("HardcoreHUD: HUD locked")
    else
      H.root:EnableMouse(true)
      H.root:RegisterForDrag("LeftButton")
      H.root:SetScript("OnDragStart", function(self) self:StartMoving() end)
      H.root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p,_,rp,x,y = self:GetPoint()
        HardcoreHUDDB.pos = { x=x, y=y }
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

  -- Initial sync to ensure checkbox reflects DB on first build
  if HardcoreHUDDB.lock == nil then HardcoreHUDDB.lock = true end
  lock:SetChecked(true)

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
  local center = CreateFrame("Button", nil, rightCol, "UIPanelButtonTemplate")
  center:ClearAllPoints()
  center:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, 0)
  center:SetSize(170, 24)
  center:SetText("HUD zentrieren")
    center:SetText("Center HUD")
  center:SetFrameStrata("FULLSCREEN_DIALOG")
  center:SetFrameLevel(rightCol:GetFrameLevel()+1)
  center:SetScript("OnClick", function()
    HardcoreHUDDB.pos = { x = 0, y = -150 }
    H.root:ClearAllPoints()
    H.root:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x, HardcoreHUDDB.pos.y)
    print("HardcoreHUD: HUD centered")
  end)

  -- Test buttons for warnings (placed under warning toggles)
  local testsLabel = rightCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  testsLabel:ClearAllPoints()
  testsLabel:SetPoint("TOPLEFT", center, "BOTTOMLEFT", 0, -24)
  testsLabel:SetText("Warning Tests")
  testsLabel:SetDrawLayer("OVERLAY")

  local testCrit = CreateFrame("Button", nil, rightCol, "UIPanelButtonTemplate")
  testCrit:ClearAllPoints()
  testCrit:SetPoint("TOPLEFT", testsLabel, "BOTTOMLEFT", 0, -8)
  testCrit:SetSize(150, 24)
  testCrit:SetText("Test Critical Health")
  testCrit:SetFrameStrata("FULLSCREEN_DIALOG")
  testCrit:SetFrameLevel(rightCol:GetFrameLevel()+1)
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

  local testElite = CreateFrame("Button", nil, rightCol, "UIPanelButtonTemplate")
  testElite:ClearAllPoints()
  testElite:SetPoint("TOPLEFT", testCrit, "BOTTOMLEFT", 0, -10)
  testElite:SetSize(150, 24)
  testElite:SetText("Test Elite/+2 Skull")
  testElite:SetFrameStrata("FULLSCREEN_DIALOG")
  testElite:SetFrameLevel(rightCol:GetFrameLevel()+1)
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

  local testMulti = CreateFrame("Button", nil, rightCol, "UIPanelButtonTemplate")
  testMulti:ClearAllPoints()
  testMulti:SetPoint("TOPLEFT", testElite, "BOTTOMLEFT", 0, -10)
  testMulti:SetSize(150, 24)
  testMulti:SetText("Test Multi-Aggro")
  testMulti:SetFrameStrata("FULLSCREEN_DIALOG")
  testMulti:SetFrameLevel(rightCol:GetFrameLevel()+1)
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
  local remind = CreateFrame("CheckButton", "HardcoreHUDBuffRemind", f, "OptionsCheckButtonTemplate")
  remind:ClearAllPoints()
  remind:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -18)
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
  local remCatLabel = rightCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  remCatLabel:SetPoint("TOPLEFT", testMulti, "BOTTOMLEFT", 0, -20)
  remCatLabel:SetText("Reminder Categories")
  remCatLabel:SetDrawLayer("OVERLAY")

  -- Only keep Core Buffs toggle; Food/Flask removed per request
  local rCore = CreateFrame("CheckButton", "HardcoreHUDRemindCore", rightCol, "OptionsCheckButtonTemplate")
  rCore:SetPoint("TOPLEFT", remCatLabel, "BOTTOMLEFT", 0, -8)
  rCore:SetChecked(HardcoreHUDDB.reminders.categories.survival)
  if _G[rCore:GetName().."Text"] then _G[rCore:GetName().."Text"]:SetText("Core Buffs: Fortitude/Mark/Kings") end
  rCore:SetFrameStrata("FULLSCREEN_DIALOG")
  rCore:SetFrameLevel(rightCol:GetFrameLevel()+1)
  rCore:SetScript("OnClick", function(self)
    HardcoreHUDDB.reminders.categories.survival = self:GetChecked()
    if H.UpdateReminders then H.UpdateReminders() end
  end)

  -- Emergency CDs pulse toggle
  HardcoreHUDDB.emergency = HardcoreHUDDB.emergency or { enabled = true, hpThreshold = 0.50 }
  local emEnable = CreateFrame("CheckButton", "HardcoreHUDEmergencyEnable", f, "OptionsCheckButtonTemplate")
  emEnable:ClearAllPoints()
  emEnable:SetPoint("TOPLEFT", remind, "BOTTOMLEFT", 0, -20)
  emEnable:SetChecked(HardcoreHUDDB.emergency.enabled)
  if _G[emEnable:GetName().."Text"] then _G[emEnable:GetName().."Text"]:SetText("Notfall-CD Puls") end
    if _G[emEnable:GetName().."Text"] then _G[emEnable:GetName().."Text"]:SetText("Emergency CD Pulse") end
  emEnable:SetScript("OnClick", function(self)
    HardcoreHUDDB.emergency.enabled = self:GetChecked()
    print("HardcoreHUD: Emergency pulse "..(HardcoreHUDDB.emergency.enabled and "ON" or "OFF"))
  end)

  -- Emergency HP threshold slider
  local emHP = CreateFrame("Slider", "HardcoreHUDEmergencyHPSlider", f, "OptionsSliderTemplate")
  emHP:ClearAllPoints()
  -- Move emergency HP slider to left column under multi slider
  emHP:ClearAllPoints()
  emHP:SetPoint("TOPLEFT", multi, "BOTTOMLEFT", 0, -28)
  emHP:SetMinMaxValues(0.15, 0.90)
  emHP:SetValueStep(0.05)
  -- Older client builds (e.g. 3.3.5) lack SetObeyStepOnDrag; guard it
  if emHP.SetObeyStepOnDrag then emHP:SetObeyStepOnDrag(true) end
  emHP:SetValue(HardcoreHUDDB.emergency.hpThreshold or 0.50)
  if _G[emHP:GetName().."Low"] then _G[emHP:GetName().."Low"]:SetText("15%") end
  if _G[emHP:GetName().."High"] then _G[emHP:GetName().."High"]:SetText("90%") end
  if _G[emHP:GetName().."Text"] then _G[emHP:GetName().."Text"]:SetText("Puls-Schwelle HP") end
    if _G[emHP:GetName().."Text"] then _G[emHP:GetName().."Text"]:SetText("Pulse Threshold HP") end
  emHP:SetScript("OnValueChanged", function(self,val)
    val = tonumber(string.format("%.2f", val))
    HardcoreHUDDB.emergency.hpThreshold = val
    print("HardcoreHUD: Emergency HP threshold = "..math.floor(val*100+0.5).."%")
  end)

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:ClearAllPoints()
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 20)
  close:SetSize(140, 26)
  close:SetText("Schließen")
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
  local fsOpacity = CreateFrame("Slider", "HardcoreHUDFiveSecOpacity", f, "OptionsSliderTemplate")
  fsOpacity:ClearAllPoints()
  -- With TTD sliders removed, anchor fsOpacity under emHP
  fsOpacity:SetPoint("TOPLEFT", emHP, "BOTTOMLEFT", 0, -68)
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
  SlashCmdList["HARDCOREHUD"] = function(msg)
    local a = {}; for t in string.gmatch(msg, "[^%s]+") do table.insert(a,t) end
    local cmd = string.lower(a[1] or "help")
    if cmd == "help" then
      print("HardcoreHUD:")
      print("/hardhud width <n> | height <n>")
      print("/hardhud color hp|mana|energy|rage r g b")
      print("/hardhud lock | unlock")
      print("/hardhud warn critical on|off | skull on|off")
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
end
