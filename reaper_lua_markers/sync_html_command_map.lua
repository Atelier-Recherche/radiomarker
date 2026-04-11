-- Synchronise automatiquement les Command IDs Reaper vers podcast_4pistes.html
-- Usage: lancer ce script depuis Reaper apres install_markers_actions.lua

local function get_script_dir()
    local source = debug.getinfo(1, "S").source
    local script_path = source:match("^@(.+)$")
    if not script_path then return nil end
    return script_path:match("^(.*)[/\\][^/\\]+$")
end

local function join_path(a, b)
    local sep = package.config:sub(1, 1)
    if a:sub(-1) == "/" or a:sub(-1) == "\\" then
        return a .. b
    end
    return a .. sep .. b
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, content)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function command_id_for_script(path)
    -- section 0 = Main
    local cmd = reaper.AddRemoveReaScript(true, 0, path, true)
    if not cmd or cmd == 0 then
        return nil
    end
    local named = reaper.ReverseNamedCommandLookup(cmd)
    if not named or named == "" then
        return tostring(cmd) -- fallback si commande non nommee
    end
    -- Selon versions/configs, le prefixe "_" peut manquer. On le force.
    if named:match("^RS") then
        named = "_" .. named
    end
    return named
end

local script_dir = get_script_dir()
if not script_dir then
    reaper.ShowMessageBox("Impossible de determiner le dossier du script.", "Sync HTML command map", 0)
    return
end

local project_dir = script_dir:match("^(.*)[/\\]reaper_lua_markers$")
if not project_dir then
    reaper.ShowMessageBox("Le script doit rester dans le dossier reaper_lua_markers.", "Sync HTML command map", 0)
    return
end

local html_path = join_path(project_dir, "podcast_4pistes.html")
if not reaper.file_exists(html_path) then
    reaper.ShowMessageBox("Fichier HTML introuvable:\n" .. html_path, "Sync HTML command map", 0)
    return
end

local files = {
    P1_NOM = "p1_nommer.lua",
    P1_ERR = "p1_erreur.lua",
    P1_REF = "p1_citation.lua",
    P2_NOM = "p2_nommer.lua",
    P2_ERR = "p2_erreur.lua",
    P2_REF = "p2_citation.lua",
    P3_NOM = "p3_nommer.lua",
    P3_ERR = "p3_erreur.lua",
    P3_REF = "p3_citation.lua",
    P4_NOM = "p4_nommer.lua",
    P4_ERR = "p4_erreur.lua",
    P4_REF = "p4_citation.lua"
}

local map = {}
local missing = {}

for key, filename in pairs(files) do
    local fullpath = join_path(script_dir, filename)
    if not reaper.file_exists(fullpath) then
        missing[#missing + 1] = filename
    else
        local cmd_id = command_id_for_script(fullpath)
        if not cmd_id then
            missing[#missing + 1] = filename .. " (ID introuvable)"
        else
            map[key] = cmd_id
        end
    end
end

if next(map) == nil then
    reaper.ShowMessageBox("Aucun Command ID resolu. Lance d'abord l'installateur.", "Sync HTML command map", 0)
    return
end

local html = read_file(html_path)
if not html then
    reaper.ShowMessageBox("Impossible de lire le HTML.", "Sync HTML command map", 0)
    return
end

local new_block = table.concat({
    "const commandMap = {",
    string.format('            P1_NOM: "%s",', map.P1_NOM or ""),
    string.format('            P1_ERR: "%s",', map.P1_ERR or ""),
    string.format('            P1_REF: "%s",', map.P1_REF or ""),
    string.format('            P2_NOM: "%s",', map.P2_NOM or ""),
    string.format('            P2_ERR: "%s",', map.P2_ERR or ""),
    string.format('            P2_REF: "%s",', map.P2_REF or ""),
    string.format('            P3_NOM: "%s",', map.P3_NOM or ""),
    string.format('            P3_ERR: "%s",', map.P3_ERR or ""),
    string.format('            P3_REF: "%s",', map.P3_REF or ""),
    string.format('            P4_NOM: "%s",', map.P4_NOM or ""),
    string.format('            P4_ERR: "%s",', map.P4_ERR or ""),
    string.format('            P4_REF: "%s"', map.P4_REF or ""),
    "        };"
}, "\n")

local updated, count = html:gsub("const%s+commandMap%s*=%s*%b{}%s*;", new_block, 1)
if count == 0 then
    reaper.ShowMessageBox("Bloc commandMap introuvable dans podcast_4pistes.html.", "Sync HTML command map", 0)
    return
end

if not write_file(html_path, updated) then
    reaper.ShowMessageBox("Impossible d'ecrire le HTML.\nFerme le fichier dans l'editeur puis reessaie.", "Sync HTML command map", 0)
    return
end

local report = "Synchronisation terminee.\nHTML mis a jour:\n" .. html_path
if #missing > 0 then
    report = report .. "\n\nElements manquants:\n- " .. table.concat(missing, "\n- ")
end
reaper.ShowMessageBox(report, "Sync HTML command map", 0)
