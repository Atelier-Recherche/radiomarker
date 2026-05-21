-- Exporte note Markdown Obsidian (liens #t= par marqueur) + MP3 si besoin.
-- Le .md n est PAS cree par File > Render seul : lance cette action apres le marquage.
-- Si tu as deja rendu en MP3 (meme dossier ou dernier RENDER_FILE), le script reutilise ce fichier.

local function get_script_dir()
    local source = debug.getinfo(1, "S").source
    local script_path = source:match("^@(.+)$")
    if not script_path then return nil end
    return script_path:match("^(.*)[/\\][^/\\]+$")
end

local script_dir = get_script_dir()
if not script_dir then
    reaper.ShowMessageBox("Impossible de determiner le dossier du script.", "Export Obsidian", 0)
    return
end

local sep = package.config:sub(1, 1)
local export_lib = dofile(script_dir .. sep .. "radiomarker_export.lua")

local project_name = export_lib.get_project_base_name()
local safe_base = export_lib.sanitize_filename(project_name)
local default_mp3_name = safe_base .. ".mp3"

local out_dir = export_lib.get_output_directory()
if not out_dir then
    return
end

local mp3_path, mp3_name = export_lib.resolve_mp3_for_export(out_dir, default_mp3_name)
local used_existing = mp3_path ~= nil

if not used_existing then
    mp3_path = export_lib.join_path(out_dir, default_mp3_name)
    mp3_name = default_mp3_name
    local ok_render, render_err = export_lib.render_project_to_file(mp3_path)
    if not ok_render then
        local last = export_lib.get_last_render_file()
        if last then
            mp3_path = last
            mp3_name = export_lib.basename(last)
            used_existing = true
        else
            reaper.ShowMessageBox(
                (render_err or "Echec du rendu MP3.") .. "\n\n" ..
                "Tu peux d abord faire File > Render, puis relancer cette action.\n" ..
                "Configure aussi File > Project render settings (MP3).",
                "Export Obsidian",
                0
            )
            return
        end
    end
end

local md_path = export_lib.md_path_for_mp3(mp3_path)
local markers = export_lib.collect_markers()
local md_content = export_lib.build_markdown_file(project_name, mp3_name, markers)

if not export_lib.write_utf8(md_path, md_content) then
    reaper.ShowMessageBox("Impossible d'ecrire:\n" .. md_path, "Export Obsidian", 0)
    return
end

local render_note = used_existing and "MP3 existant reutilise (pas de nouveau rendu).\n\n" or "MP3 rendu par ce script.\n\n"

reaper.ShowMessageBox(
    "Export termine.\n\n" ..
    render_note ..
    "MP3 :\n" .. mp3_path .. "\n\n" ..
    "Markdown :\n" .. md_path .. "\n\n" ..
    "Marqueurs : " .. tostring(#markers) .. "\n\n" ..
    "Copie les deux fichiers dans ton vault Obsidian (meme dossier que la note).",
    "Export Obsidian",
    0
)
