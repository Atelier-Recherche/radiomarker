-- Exporte le projet en MP3 fusionne + note Markdown Obsidian (liens #t= par marqueur).
-- Prerequis : File > Project render settings configure en MP3 (une fois).

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
local mp3_name = safe_base .. ".mp3"
local md_name = safe_base .. ".md"

local out_dir = export_lib.get_output_directory()
if not out_dir then
    return
end

local mp3_path = export_lib.join_path(out_dir, mp3_name)
local md_path = export_lib.join_path(out_dir, md_name)

local ok_render, render_err = export_lib.render_project_to_file(mp3_path)
if not ok_render then
    reaper.ShowMessageBox(
        (render_err or "Echec du rendu MP3.") .. "\n\n" ..
        "Configure File > Project render settings (MP3, mixdown/master).",
        "Export Obsidian",
        0
    )
    return
end

local markers = export_lib.collect_markers()
local md_content = export_lib.build_markdown_file(project_name, mp3_name, markers)

if not export_lib.write_utf8(md_path, md_content) then
    reaper.ShowMessageBox("Impossible d'ecrire:\n" .. md_path, "Export Obsidian", 0)
    return
end

reaper.ShowMessageBox(
    "Export termine.\n\n" ..
    "MP3 :\n" .. mp3_path .. "\n\n" ..
    "Markdown :\n" .. md_path .. "\n\n" ..
    "Marqueurs : " .. tostring(#markers) .. "\n\n" ..
    "Copie les deux fichiers dans ton vault Obsidian (meme dossier que la note).",
    "Export Obsidian",
    0
)
