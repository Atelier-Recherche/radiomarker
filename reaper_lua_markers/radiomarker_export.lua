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
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

function M.get_project_base_name()
    local name = ""
    if reaper.GetProjectName then
        name = reaper.GetProjectName(0, "")
    end
    name = M.trim(name)
    if name == "" then name = "Untitled" end
    return name
end

function M.basename(path)
    local name = path:match("([^/\\]+)$")
    return name or path
end

function M.dirname(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    return dir or ""
end

function M.get_last_render_file()
    local path = reaper.GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
    path = M.trim(path)
    if path ~= "" and reaper.file_exists(path) then
        return path
    end
    return nil
end

-- MP3 deja present (export manuel ou rendu precedent) : evite un second render
function M.resolve_mp3_for_export(out_dir, mp3_name)
    local expected = M.join_path(out_dir, mp3_name)
    if reaper.file_exists(expected) then
        return expected, mp3_name
    end
    local last = M.get_last_render_file()
    if last then
        local base = M.basename(last)
        if base:lower():match("%.mp3$") or base:lower():match("%.wav$") or base:lower():match("%.flac$") then
            return last, base
        end
    end
    return nil, nil
end

function M.get_output_directory()
    local last = M.get_last_render_file()
    if last then
        local dir = M.dirname(last)
        if dir ~= "" then return dir end
    end
    local proj_path = reaper.GetProjectPathName(0, "")
    proj_path = M.trim(proj_path)
    if proj_path ~= "" then
        local dir = proj_path:match("^(.*)[/\\][^/\\]+$")
        if dir and dir ~= "" then
            return dir
        end
    end
    local ok, ret = reaper.GetUserInputs(
        "Export Radiomarker",
        1,
        "Dossier de sortie (chemin complet):,extrawidth=400",
        (reaper.GetResourcePath() or ""):gsub("/", sep)
    )
    if not ok then return nil end
    local dir = M.trim(ret)
    if dir == "" then return nil end
    return dir
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
    return (mp3_path:gsub("%.[^%.\\\/]+$", "") or mp3_path) .. ".md"
end

function M.render_project_to_file(output_path)
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", output_path, true)
    reaper.Main_OnCommand(42230, 0) -- Render project, recent settings, auto-close dialog
    local t0 = reaper.time_precise and reaper.time_precise() or 0
    if reaper.GetRenderState then
        while reaper.GetRenderState() ~= 0 do
            if reaper.time_precise and reaper.time_precise() - t0 > 3600 then
                return false, "Delai de rendu depasse."
            end
        end
    end
    local deadline = t0 + 120
    while not reaper.file_exists(output_path) do
        if reaper.time_precise and reaper.time_precise() > deadline then
            return false, "Fichier MP3 introuvable apres rendu. Verifie File > Project render settings (format MP3)."
        end
        if not reaper.time_precise then break end
    end
    if not reaper.file_exists(output_path) then
        return false, "Fichier MP3 introuvable apres rendu. Verifie File > Project render settings (format MP3)."
    end
    return true
end

return M
