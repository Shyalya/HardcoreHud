local addonName = ...
HardcoreHUD = HardcoreHUD or {}
local H = HardcoreHUD

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
f:SetPoint("CENTER", UIParent, "CENTER", HardcoreHUDDB.pos.x, HardcoreHUDDB.pos.y)
f:SetSize(HardcoreHUDDB.size.width, HardcoreHUDDB.size.height)
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
    local unit = ...; if unit == "player" then H.UpdatePower() end
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
    H.OnCombatLog(...)
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
  H.BuildWarnings()
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
