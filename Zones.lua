local H = HardcoreHUD

-- Simple Vanilla zones level ranges (not exhaustive, representative sample)
local zones = {
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

local function buildWindow()
  if H.zonesFrame then return end
  local f = CreateFrame("Frame", "HardcoreHUDZones", UIParent)
  H.zonesFrame = f
  f:SetSize(360, 420)
  f:SetPoint("CENTER")
  f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=6,right=6,top=6,bottom=6} })
  f:SetBackdropColor(0,0,0,0.85)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -10)
  title:SetText("Vanilla Zone Levels")

  local scroll = CreateFrame("ScrollFrame", "HardcoreHUDZonesScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 14)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, #zones * 20 + 20)
  scroll:SetScrollChild(content)

  local y = -4
  for i, z in ipairs(zones) do
    local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    line:SetText(string.format("%s  |  %s", z.name, z.range))
    y = y - 20
  end

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
  close:SetSize(120, 24)
  close:SetText("Close")
  close:SetScript("OnClick", function() f:Hide() end)
end

function H.ShowZonesWindow()
  buildWindow()
  if H.zonesFrame:IsShown() then H.zonesFrame:Hide() else H.zonesFrame:Show() end
end
