-- Helpers export Markdown Obsidian (charge via dofile depuis export_markers_obsidian.lua)

local M = {}

local sep = package.config:sub(1, 1)

function M.join_path(a, b)
    if a:sub(-1) == "/" or a:sub(-1) == "\\" then
        return a .. b
    end
    return a .. sep .. b
end

function M.trim(s)
    if type(s) ~= "string" then return "" end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Plusieurs API Reaper renvoient (retval bool, string) en Lua
function M.reaper_string(first, second)
    if type(second) == "string" then return second end
    if type(first) == "string" then return first end
    return ""
end

function M.sanitize_filename(name)
    local s = M.trim(name)
    if s == "" then s = "Untitled" end
    s = s:gsub('[%\\/:%*%?"<>|]', "_")
    s = s:gsub("%s+$", "")
    if s == "" then s = "Untitled" end
    return s
end

function M.format_mmss(seconds)
    local t = math.max(0, math.floor(seconds + 0.5))
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

-- Parse "YYYY-MM-DD HH:MM:SS" depuis le nom du projet
function M.parse_project_start_datetime(project_name)
    local y, mo, d, h, mi, s = project_name:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
    if not y then return nil end
    return {
        year = tonumber(y),
        month = tonumber(mo),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(mi),
        sec = tonumber(s)
    }
end

function M.format_absolute_time(start_parts, offset_seconds)
    if not start_parts then return nil end
    local t = math.max(0, math.floor(offset_seconds + 0.5))
    local total = start_parts.hour * 3600 + start_parts.min * 60 + start_parts.sec + t
    local h = math.floor(total / 3600) % 24
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

function M.marker_label(name)
    local n = M.trim(name)
    if n == "" then return "marqueur" end
    local _, _, suffix = n:find("_([^_]+)$")
    if suffix and suffix ~= "" then
        return suffix:gsub("_", " ")
    end
    return n
end

function M.collect_markers()
    local markers = {}
    local idx = 0
    while true do
        local retval, isrgn, pos, rgnend, name, markidx, color
        if reaper.EnumProjectMarkers3 then
            retval, isrgn, pos, rgnend, name, markidx, color = reaper.EnumProjectMarkers3(0, idx)
        else
            retval, isrgn, pos, rgnend, name, markidx = reaper.EnumProjectMarkers2(0, idx)
        end
        if retval == 0 then break end
        if not isrgn then
            markers[#markers + 1] = {
                pos = pos,
                name = name or "",
                index = markidx
            }
        end
        idx = idx + 1
    end
    table.sort(markers, function(a, b) return a.pos < b.pos end)
    return markers
end

function M.build_obsidian_link(mp3_basename, pos_seconds, start_parts, marker_name)
    local sec = math.max(0, math.floor(pos_seconds))
    local rel = M.format_mmss(sec)
    local label = M.marker_label(marker_name)
    local link = string.format("[[%s#t=%d|%s]]", mp3_basename, sec, rel)
    local abs = M.format_absolute_time(start_parts, sec)
    if abs then
        return link .. "\\[" .. abs .. "] " .. label
    end
    return link .. " " .. label
end

function M.build_markdown_body(mp3_basename, project_name, markers)
    local start_parts = M.parse_project_start_datetime(project_name)
    local lines = {}
    lines[#lines + 1] = string.format("![[%s]]", mp3_basename)
    lines[#lines + 1] = ""
    if #markers == 0 then
        lines[#lines + 1] = "_Aucun marqueur dans le projet._"
        lines[#lines + 1] = ""
    else
        for i = 1, #markers do
            local m = markers[i]
            lines[#lines + 1] = M.build_obsidian_link(mp3_basename, m.pos, start_parts, m.name)
            lines[#lines + 1] = ""
        end
    end
    return table.concat(lines, "\n")
end

local function yaml_scalar(s)
    if s:find("[%s:#\"'&*?|>\\[\\]{}]") or s:find("^[%d%-]") then
        return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
    end
    return s
end

function M.build_markdown_file(project_name, mp3_basename, markers)
    local header = table.concat({
        "---",
        "audio_file: " .. yaml_scalar(mp3_basename),
        "audio_start_time: " .. yaml_scalar(project_name),
        "---",
        ""
    }, "\n")
    return header .. M.build_markdown_body(mp3_basename, project_name, markers)
end

function M.api_available(name)
    if reaper.APIExists then
        return reaper.APIExists(name)
    end
    return reaper[name] ~= nil
end

function M.get_project_base_name()
    local name = ""
    if M.api_available("GetProjectName") then
        name = M.reaper_string(reaper.GetProjectName(0, ""))
    end
    name = M.trim(name)
    if name == "" then name = "Untitled" end
    return name
end

-- Dossier du projet (RPP enregistre) ; API selon version REAPER
function M.get_project_directory()
    if M.api_available("GetProjectPathName") then
        local path = M.trim(M.reaper_string(reaper.GetProjectPathName(0, "")))
        if path ~= "" then
            local dir = path:match("^(.*)[/\\][^/\\]+$")
            if dir and dir ~= "" then return dir end
            return path
        end
    end
    if M.api_available("GetProjectPath") then
        return M.trim(M.reaper_string(reaper.GetProjectPath("")))
    end
    return ""
end

function M.basename(path)
    local name = path:match("([^/\\]+)$")
    return name or path
end

function M.dirname(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    return dir or ""
end

M.AUDIO_EXTENSIONS = { "mp3", "wav", "flac", "ogg", "m4a", "aiff", "aif" }

function M.is_audio_file(path)
    if not path or path == "" then return false end
    local ext = path:match("%.([^.\\/]+)$")
    if not ext then return false end
    ext = ext:lower()
    for i = 1, #M.AUDIO_EXTENSIONS do
        if ext == M.AUDIO_EXTENSIONS[i] then return true end
    end
    return false
end

function M.get_render_target_path()
    local path = M.trim(M.reaper_string(reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)))
    if path == "" then return nil end
    return path
end

-- REAPER peut ecrire dans un sous-dossier (ex. .../uio.rpp.mp3/uio.mp3)
function M.resolve_audio_path(path, base_name)
    if not path or path == "" then return nil end
    path = M.trim(path)
    if reaper.file_exists(path) and M.is_audio_file(path) then
        return path
    end
    if reaper.file_exists(path) then
        for i = 1, #M.AUDIO_EXTENSIONS do
            local ext = M.AUDIO_EXTENSIONS[i]
            local inner = M.join_path(path, base_name .. "." .. ext)
            if reaper.file_exists(inner) and M.is_audio_file(inner) then
                return inner
            end
        end
    end
    return nil
end

function M.get_last_render_file(base_name)
    local target = M.get_render_target_path()
    if not target then return nil end
    return M.resolve_audio_path(target, base_name or "")
end

function M.get_render_directory()
    if M.api_available("GetSetProjectInfo_String") then
        local d = M.trim(M.reaper_string(reaper.GetSetProjectInfo_String(0, "RENDER_DIRECTORY", "", false)))
        if d ~= "" then return d end
    end
    local target = M.get_render_target_path()
    if target then
        local dir = M.dirname(target)
        if dir ~= "" then return dir end
    end
    return M.get_project_directory()
end

function M.get_search_directories(base_name)
    local dirs = {}
    local seen = {}
    local function add(d)
        d = M.trim(d)
        if d == "" or seen[d] then return end
        seen[d] = true
        dirs[#dirs + 1] = d
    end
    local last = M.get_last_render_file(base_name or "")
    if last then add(M.dirname(last)) end
    local target = M.get_render_target_path()
    if target then
        add(M.dirname(target))
        add(target)
    end
    add(M.get_render_directory())
    add(M.get_project_directory())
    return dirs
end

function M.prompt_audio_file(default_dir)
    if not reaper.GetUserFileNameForRead then return nil, nil end
    local initial = default_dir or ""
    if initial ~= "" and initial:sub(-1) ~= "/" and initial:sub(-1) ~= "\\" then
        initial = initial .. sep
    end
    local ok, file = reaper.GetUserFileNameForRead(
        "mp3,wav,flac,ogg,m4a,aiff,aif",
        "Selectionner le fichier audio rendu",
        initial
    )
    file = M.trim(M.reaper_string(ok, file))
    if file == "" then return nil, nil end
    if reaper.file_exists(file) and M.is_audio_file(file) then
        return file, M.basename(file)
    end
    return nil, nil
end

function M.find_audio_in_directory(dir, base_name)
    for i = 1, #M.AUDIO_EXTENSIONS do
        local ext = M.AUDIO_EXTENSIONS[i]
        local p = M.join_path(dir, base_name .. "." .. ext)
        if reaper.file_exists(p) then
            return p, M.basename(p)
        end
    end
    return nil, nil
end

-- Cherche l audio rendu (File > Render) : RENDER_FILE d abord, puis dossiers render REAPER
function M.find_existing_audio(base_name, default_mp3_name)
    local target = M.get_render_target_path()
    if target then
        local resolved = M.resolve_audio_path(target, base_name)
        if resolved then
            return resolved, M.basename(resolved)
        end
    end

    local last = M.get_last_render_file(base_name)
    if last then
        return last, M.basename(last)
    end

    local dirs = M.get_search_directories(base_name)
    for i = 1, #dirs do
        local path, name = M.find_audio_in_directory(dirs[i], base_name)
        if path then return path, name end
        path = M.resolve_audio_path(dirs[i], base_name)
        if path then return path, M.basename(path) end
    end

    return nil, nil
end

function M.write_utf8(path, content)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- Render projet vers path (format MP3 via reglages render du projet)
function M.md_path_for_mp3(mp3_path)
    local i = mp3_path:find("%.[^%.\\/]+$")
    if i then
        return mp3_path:sub(1, i - 1) .. ".md"
    end
    return mp3_path .. ".md"
end

function M.write_markdown_export(project_name, mp3_path, mp3_name, used_existing)
    local md_path = M.md_path_for_mp3(mp3_path)
    local markers = M.collect_markers()
    local md_content = M.build_markdown_file(project_name, mp3_name, markers)
    if not M.write_utf8(md_path, md_content) then
        return false, "Impossible d'ecrire:\n" .. md_path
    end
    local render_note = used_existing and "Audio existant reutilise (pas de nouveau rendu).\n\n"
        or "Audio rendu par ce script.\n\n"
    reaper.ShowMessageBox(
        "Export termine.\n\n" ..
        render_note ..
        "Audio :\n" .. mp3_path .. "\n\n" ..
        "Markdown :\n" .. md_path .. "\n\n" ..
        "Marqueurs : " .. tostring(#markers) .. "\n\n" ..
        "Copie les deux fichiers dans ton vault Obsidian (meme dossier que la note).",
        "Export Obsidian",
        0
    )
    return true
end

return M
