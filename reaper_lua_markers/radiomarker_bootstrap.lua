-- Charge au demarrage REAPER via Scripts/__startup.lua (installeur Radiomarker).
-- Enregistre les actions puis synchronise podcast_4pistes.html, sans popups de succes.

_G.RADIOMARKER_SILENT = true

local source = debug.getinfo(1, "S").source
local script_path = source:match("^@(.+)$")
if not script_path then
    _G.RADIOMARKER_SILENT = nil
    return
end

local dir = script_path:match("^(.*)[/\\][^/\\]+$")
if not dir then
    _G.RADIOMARKER_SILENT = nil
    return
end

local sep = package.config:sub(1, 1)
local install_path = dir .. sep .. "install_markers_actions.lua"
local sync_path = dir .. sep .. "sync_html_command_map.lua"

local ok, err = pcall(function()
    dofile(install_path)
    dofile(sync_path)
end)

_G.RADIOMARKER_SILENT = nil

if not ok then
    reaper.ShowMessageBox("Radiomarker (demarrage): " .. tostring(err), "Radiomarker", 0)
end
