-- Export Markdown Obsidian a partir du fichier audio DEJA rendu (File > Render).
-- Ne relance pas le render (evite doublons et gel UI). Fait File > Render avant, puis cette action.

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

local function show_error(msg)
    reaper.ShowMessageBox(msg, "Export Obsidian", 0)
end

local mp3_path, mp3_name = export_lib.find_existing_audio(safe_base, default_mp3_name)

if not mp3_path then
    local default_dir = export_lib.get_render_directory()
    mp3_path, mp3_name = export_lib.prompt_audio_file(default_dir)
end

if not mp3_path then
    show_error(
        "Aucun fichier audio trouve.\n\n" ..
        "1. Fais d abord File > Render (vers D:\\... ou REAPER Media).\n" ..
        "2. Relance cette action : le .md sera cree a cote du MP3/WAV.\n\n" ..
        "Chemin render actuel (RENDER_FILE) :\n" ..
        (export_lib.get_render_target_path() or "(vide)")
    )
    return
end

local ok, err = export_lib.write_markdown_export(project_name, mp3_path, mp3_name, true)
if not ok then
    show_error(err)
end
