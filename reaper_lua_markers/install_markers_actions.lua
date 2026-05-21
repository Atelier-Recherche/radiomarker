-- Installe automatiquement les scripts de marqueurs dans la liste d'actions Reaper.
-- A lancer via: ReaScript: Exécuter/éditer ReaScript (EEL2 ou Lua)..

local function get_script_dir()
    local source = debug.getinfo(1, "S").source
    local script_path = source:match("^@(.+)$")
    if not script_path then return nil end
    local dir = script_path:match("^(.*)[/\\][^/\\]+$")
    return dir
end

local function join_path(a, b)
    local sep = package.config:sub(1, 1)
    if a:sub(-1) == "/" or a:sub(-1) == "\\" then
        return a .. b
    end
    return a .. sep .. b
end

local silent = _G.RADIOMARKER_SILENT == true

local script_dir = get_script_dir()
if not script_dir then
    reaper.ShowMessageBox("Impossible de determiner le dossier du script.", "Install markers actions", 0)
    return
end

local files = {
    "p1_erreur.lua", "p1_citation.lua", "p1_note.lua", "p1_nommer.lua",
    "p2_erreur.lua", "p2_citation.lua", "p2_note.lua", "p2_nommer.lua",
    "p3_erreur.lua", "p3_citation.lua", "p3_note.lua", "p3_nommer.lua",
    "p4_erreur.lua", "p4_citation.lua", "p4_note.lua", "p4_nommer.lua",
    "export_markers_obsidian.lua"
}

local missing = {}
local installed = {}
local failed = {}

for i = 1, #files do
    local filename = files[i]
    local fullpath = join_path(script_dir, filename)

    if not reaper.file_exists(fullpath) then
        missing[#missing + 1] = filename
    else
        -- sectionID 0 = section principale (Main); retourne le command ID ou 0 si echec
        local cmd_id = reaper.AddRemoveReaScript(true, 0, fullpath, true)
        if cmd_id and cmd_id ~= 0 then
            installed[#installed + 1] = filename
        else
            failed[#failed + 1] = filename
        end
    end
end

local function join_lines(list)
    if #list == 0 then return "Aucun" end
    local out = {}
    for i = 1, #list do
        out[#out + 1] = "- " .. list[i]
    end
    return table.concat(out, "\n")
end

local message =
    "Installation terminee.\n\n" ..
    "Installes (" .. #installed .. "):\n" .. join_lines(installed) .. "\n\n" ..
    "Introuvables (" .. #missing .. "):\n" .. join_lines(missing) .. "\n\n" ..
    "Echecs (" .. #failed .. "):\n" .. join_lines(failed) .. "\n\n" ..
    "Ouvre ensuite la Liste des actions et cherche: p1_, p2_, p3_, p4_."

if not silent then
    reaper.ShowMessageBox(message, "Install markers actions", 0)
end
