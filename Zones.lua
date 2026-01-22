local H = HardcoreHUD

-- Simple Vanilla zones level ranges (not exhaustive, representative sample)
local allZones = {
  { name = "Dun Morogh", range = "1-10" },
  { name = "Elwynn Forest", range = "1-10" },
  { name = "Tirisfal Glades", range = "1-10" },
  { name = "Durotar", range = "1-10" },
  { name = "Mulgore", range = "1-10" },
  { name = "Darkshore", range = "10-20" },
  { name = "Loch Modan", range = "10-20" },
  { name = "Westfall", range = "10-20" },
  { name = "Silverpine Forest", range = "10-20" },
  { name = "Barrens", range = "10-25" },
  { name = "Redridge Mountains", range = "15-25" },
  { name = "Stonetalon Mountains", range = "15-27" },
  { name = "Ashenvale", range = "18-30" },
  { name = "Duskwood", range = "18-30" },
  { name = "Hillsbrad Foothills", range = "20-30" },
  { name = "Wetlands", range = "20-30" },
  { name = "Thousand Needles", range = "25-35" },
  { name = "Alterac Mountains", range = "30-40" },
  { name = "Arathi Highlands", range = "30-40" },
  { name = "Desolace", range = "30-40" },
  { name = "Stranglethorn Vale", range = "30-45" },
  { name = "Badlands", range = "35-45" },
  { name = "Swamp of Sorrows", range = "35-45" },
  { name = "Hinterlands", range = "40-50" },
  { name = "Feralas", range = "40-50" },
  { name = "Tanaris", range = "40-50" },
  { name = "Searing Gorge", range = "43-50" },
  { name = "Felwood", range = "48-55" },
  { name = "Un'Goro Crater", range = "48-55" },
  { name = "Azshara", range = "48-55" },
  { name = "Blasted Lands", range = "50-58" },
  { name = "Burning Steppes", range = "50-58" },
  { name = "Western Plaguelands", range = "51-58" },
  { name = "Eastern Plaguelands", range = "53-60" },
  { name = "Winterspring", range = "55-60" },
}

local function parseRange(rangeStr)
  local a, b = string.match(rangeStr or "", "^(%d+)%-(%d+)$")
  if not a or not b then return nil, nil end
  return tonumber(a), tonumber(b)
end

local function zoneIntersectsLevelWindow(zoneRange, playerLevel)
  if not playerLevel then return false end
  local zmin, zmax = parseRange(zoneRange)
  if not zmin or not zmax then return false end
  local wmin = math.max(1, playerLevel - 3)
  local wmax = playerLevel + 3
  return not (zmax < wmin or zmin > wmax)
end

local function getFilteredZones()
  local level = UnitLevel("player")
  local filtered = {}
  for i, z in ipairs(allZones) do
    if zoneIntersectsLevelWindow(z.range, level) then
      table.insert(filtered, z)
    end
  end
  return filtered, level
end

local function buildWindow()
  if H.zonesFrame then return end
  local f = CreateFrame("Frame", "HardcoreHUDZones", UIParent)
  H.zonesFrame = f
  f:SetSize(360, 420)
  f:SetPoint("CENTER")
  H.SafeBackdrop(f, { bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} }, 0,0,0,0.85)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -10)
  title:SetText("Vanilla Zone Levels")

  local scroll = CreateFrame("ScrollFrame", "HardcoreHUDZonesScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 14)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 200)
  scroll:SetScrollChild(content)

  f._zonesContent = content
  f._zonesTitle = title

  local function refresh()
    local filtered, level = getFilteredZones()
    -- Clear previous rows if present
    if f._zoneRows then
      for _, row in ipairs(f._zoneRows) do
        row:Hide()
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
      end
    end
    f._zoneRows = {}
    -- Rebuild list
    local count = #filtered
    f._zonesContent:SetSize(300, count * 22 + 20)
    f._zonesTitle:SetText(string.format("Zones Near Your Level (%d)", level or 0))
    local y = -4
    -- Instances near zones (Vanilla brackets)
    local zoneInstances = {
      ["Durotar"] = { {name="Ragefire Chasm", range="13-18"} },
      ["Barrens"] = { {name="Wailing Caverns", range="17-24"}, {name="Razorfen Kraul", range="23-30"} },
      ["Westfall"] = { {name="Deadmines", range="17-26"} },
      ["Silverpine Forest"] = { {name="Shadowfang Keep", range="22-30"} },
      ["Stonetalon Mountains"] = { {name="Blackfathom Deeps", range="20-30"} },
      ["Badlands"] = { {name="Uldaman", range="35-45"} },
      ["Desolace"] = { {name="Maraudon", range="45-52"} },
      ["Swamp of Sorrows"] = { {name="Sunken Temple", range="50-54"} },
      ["Searing Gorge"] = { {name="Blackrock Depths", range="52-60"} },
      ["Burning Steppes"] = { {name="Blackrock Spire", range="55-60"} },
      ["Stranglethorn Vale"] = { {name="Zul'Farrak", range="44-54"} },
      ["Feralas"] = { {name="Dire Maul", range="55-60"} },
      ["Western Plaguelands"] = { {name="Stratholme", range="58-60"} },
      ["Eastern Plaguelands"] = { {name="Scholomance", range="58-60"} },
    }
    for i, z in ipairs(filtered) do
      -- Create a clickable/hoverable row button
      local row = CreateFrame("Button", nil, f._zonesContent)
      row:SetPoint("TOPLEFT", f._zonesContent, "TOPLEFT", 2, y)
      row:SetSize(280, 20)
      -- Text inside the row
      local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      txt:SetPoint("LEFT", row, "LEFT", 2, 0)
      txt:SetText(string.format("%s  |  %s", z.name, z.range))
      row.text = txt
      -- Tooltip on hover: show nearby instances and level brackets
      row:EnableMouse(true)
      row:SetScript("OnEnter", function(self)
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
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      table.insert(f._zoneRows, row)
      y = y - 22
    end
  end

  f._refreshZones = refresh

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
  close:SetSize(120, 24)
  close:SetText("Close")
  close:SetScript("OnClick", function() f:Hide() end)
end

function H.ShowZonesWindow()
  buildWindow()
  if H.zonesFrame._refreshZones then H.zonesFrame._refreshZones() end
  if H.zonesFrame:IsShown() then H.zonesFrame:Hide() else H.zonesFrame:Show() end
end
