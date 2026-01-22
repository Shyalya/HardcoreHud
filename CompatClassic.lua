-- Compatibility shims for Classic WoW 1.15.8
local H = HardcoreHUD or {}

-- Provide UnitPower/UnitPowerMax/UnitPowerType wrappers if missing
if not UnitPower then
  -- Classic uses UnitMana/UnitManaMax, UnitEnergy, UnitRage; map common indices
  function UnitPower(unit, powerType)
    powerType = powerType or 0
    if powerType == 0 then return (UnitMana and UnitMana(unit)) or 0 end
    if powerType == 1 then return UnitRage and UnitRage(unit) or 0 end
    if powerType == 3 then return UnitEnergy and UnitEnergy(unit) or 0 end
    return 0
  end
end

if not UnitPowerMax then
  function UnitPowerMax(unit, powerType)
    powerType = powerType or 0
    if powerType == 0 then return UnitManaMax and UnitManaMax(unit) or 0 end
    if powerType == 1 then return 100 end
    if powerType == 3 then return 100 end
    return 0
  end
end

if not UnitPowerType then
  function UnitPowerType(unit)
    -- Return both numeric type and token string to match modern API usage
    -- Heuristic: if UnitMana exists and non-nil, consider mana (0)
    if UnitMana then
      return 0, "MANA"
    end
    -- Attempt to detect energy/rage by class fallback (best-effort)
    local _, class = UnitClass and UnitClass(unit) or nil
    if class == "ROGUE" or class == "DRUID" then
      return 3, "ENERGY"
    elseif class == "WARRIOR" or class == "DRUID" then
      return 1, "RAGE"
    end
    return 0, "MANA"
  end
end

-- Tooltip spell/item by ID fallbacks
if not GameTooltip.SetSpellByID then
  function GameTooltip:SetSpellByID(id)
    if not id then return end
    local name = GetSpellInfo and select(1, GetSpellInfo(id))
    if name then
      self:ClearLines()
      self:AddLine(name)
      if GetSpellDescription then
        local d = GetSpellDescription(id)
        if d and d ~= "" then self:AddLine(d, 0.9,0.9,0.9, true) end
      end
      self:Show()
    end
  end
end

if not GameTooltip.SetItemByID then
  function GameTooltip:SetItemByID(id)
    if not id then return end
    local link = GetItemLink and GetItemLink(id)
    if not link then
      -- Try GetItemInfo name then hyperlink
      local name = GetItemInfo and GetItemInfo(id)
      if name then link = "item:"..tostring(id) end
    end
    if link and self.SetHyperlink then
      self:SetHyperlink(link)
      self:Show()
    elseif link then
      self:ClearLines(); self:AddLine(link); self:Show()
    end
  end
end

-- Safe GetItemIcon fallback
if not GetItemIcon then
  function GetItemIcon(id)
    local info = GetItemInfo and {GetItemInfo(id)}
    if info and info[10] then return info[10] end
    return "Interface/Icons/INV_Misc_QuestionMark"
  end
end

-- Safe GetSpellDescription stub
if not GetSpellDescription then
  function GetSpellDescription(id)
    return nil
  end
end

-- Ensure global export
HardcoreHUD = HardcoreHUD or H

-- Runtime API availability reporter (helps debugging in Classic client)
do
  local rf = CreateFrame("Frame")
  rf:RegisterEvent("PLAYER_LOGIN")
  rf:SetScript("OnEvent", function()
    local msgs = {}
    local function a(k, v) msgs[#msgs+1] = string.format("%s=%s", k, tostring(v)) end
    a("UnitPower_native", tostring(rawget(_G, "UnitPower") ~= nil))
    a("UnitPowerMax_native", tostring(rawget(_G, "UnitPowerMax") ~= nil))
    a("UnitPowerType_native", tostring(rawget(_G, "UnitPowerType") ~= nil))
    a("GetItemIcon_native", tostring(rawget(_G, "GetItemIcon") ~= nil))
    a("SetSpellByID_native", tostring(GameTooltip and GameTooltip.SetSpellByID ~= nil))
    a("SetItemByID_native", tostring(GameTooltip and GameTooltip.SetItemByID ~= nil))
    a("GetSpellDescription_native", tostring(rawget(_G, "GetSpellDescription") ~= nil))
    local out = "HardcoreHUD Compat: " .. table.concat(msgs, ", ")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(out) else print(out) end
  end)
end
