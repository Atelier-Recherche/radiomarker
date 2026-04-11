local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function get_name()
    local name = trim(reaper.GetExtState("RADIO_MARKER", "P4_NAME"))
    if name == "" then name = "Intervenant 4" end
    return name
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

local position = reaper.GetPlayPosition()
local color = color_from_ext("P4_REF_COLOR", "FFFF00")
local label = get_name() .. "_CITATION"
reaper.AddProjectMarker2(0, false, position, 0, label, -1, color)
