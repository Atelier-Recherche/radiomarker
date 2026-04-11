local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function get_name()
    local n = trim(reaper.GetExtState("RADIO_MARKER", "P1_NAME"))
    if n == "" then n = "Intervenant 1" end
    return n
end

local function color_from_ext(key, fallback)
    local hex = trim(reaper.GetExtState("RADIO_MARKER", key))
    if hex == "" then hex = fallback end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then hex = fallback end
    local v = tonumber(hex, 16) or tonumber(fallback, 16)
    local r = math.floor(v / 65536) % 256
    local g = math.floor(v / 256) % 256
    local b = v % 256
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

local txt = reaper.GetExtState("RADIO_MARKER", "P1_NOM")
local name = trim(txt)
if name == "" then
    name = "NOTE"
end
reaper.DeleteExtState("RADIO_MARKER", "P1_NOM", false)

local position = reaper.GetPlayPosition()
local color = color_from_ext("P1_NOM_COLOR", "FF8C00")
reaper.AddProjectMarker2(0, false, position, 0, get_name() .. "_" .. name, -1, color)
