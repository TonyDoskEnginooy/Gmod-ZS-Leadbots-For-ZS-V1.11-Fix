-- The sinlge most important file in this project :)

local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local rawset = rawset
local SysTime = SysTime
local table_sort = table.sort
local string_format = string.format
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local print = print

ZSProfiler = ZSProfiler or {}

ZSProfiler.enabled = true
ZSProfiler.stats = ZSProfiler.stats or {}
ZSProfiler.zsbPatches = ZSProfiler.zsbPatches or {}
ZSProfiler.hookPatches = ZSProfiler.hookPatches or {}
ZSProfiler.zsbAttached = false
ZSProfiler.hooksAttached = false

local function StartsWithZS(name)
    return type(name) == "string" and string_sub(name, 1, 3) == "ZS_"
end

local function RecordStat(path, elapsed)
    local stat = ZSProfiler.stats[path]

    if stat then
        stat.calls = stat.calls + 1
        stat.total = stat.total + elapsed

        if elapsed > stat.max then
            stat.max = elapsed
        end

        return
    end

    ZSProfiler.stats[path] = {
        calls = 1,
        total = elapsed,
        max = elapsed
    }
end

local function MakeWrapper(record)
    return function(...)
        if not ZSProfiler.enabled then
            return record.original(...)
        end

        local startTime = SysTime()

        local r1, r2, r3, r4, r5, r6, r7, r8 = record.original(...)

        RecordStat(record.path, SysTime() - startTime)

        return r1, r2, r3, r4, r5, r6, r7, r8
    end
end

local function AddPatch(patchList, tbl, key, value, path)
    local record = {
        tableRef = tbl,
        key = key,
        original = value,
        path = path
    }

    record.wrapper = MakeWrapper(record)

    rawset(tbl, key, record.wrapper)
    patchList[#patchList + 1] = record
end

local function PatchTableRecursive(rootTable, rootPath, patchList, visited)
    if type(rootTable) ~= "table" or visited[rootTable] then
        return
    end

    visited[rootTable] = true

    for key, value in pairs(rootTable) do
        local valueType = type(value)
        local childPath = rootPath .. "." .. tostring(key)

        if valueType == "function" then
            AddPatch(patchList, rootTable, key, value, childPath)
        elseif valueType == "table" then
            PatchTableRecursive(value, childPath, patchList, visited)
        end
    end
end

local function RestorePatchList(patchList)
    for i = #patchList, 1, -1 do
        local record = patchList[i]

        if record.tableRef[record.key] == record.wrapper then
            rawset(record.tableRef, record.key, record.original)
        end

        patchList[i] = nil
    end
end

local function BuildRows(filterText)
    local rows = {}
    local normalizedFilter = nil

    if type(filterText) == "string" and filterText ~= "" then
        normalizedFilter = string_lower(filterText)
    end

    for path, stat in pairs(ZSProfiler.stats) do
        if not normalizedFilter or string_find(string_lower(path), normalizedFilter, 1, true) then
            rows[#rows + 1] = {
                path = path,
                calls = stat.calls,
                total = stat.total,
                avg = stat.total / stat.calls,
                max = stat.max
            }
        end
    end

    table_sort(rows, function(a, b)
        if a.total == b.total then
            return a.path < b.path
        end

        return a.total > b.total
    end)

    return rows
end

function ZSProfiler.Reset()
    ZSProfiler.stats = {}
end

function ZSProfiler.Print(filterText)
    local rows = BuildRows(filterText)

    print("======== ZS Profiler ========")
    print(string_format("%-70s %-10s %-14s %-14s %-14s", "Path", "Calls", "Total (ms)", "Avg (ms)", "Max (ms)"))

    for i = 1, #rows do
        local row = rows[i]

        print(string_format(
            "%-70s %-10d %-14.6f %-14.6f %-14.6f",
            row.path,
            row.calls,
            row.total * 1000,
            row.avg * 1000,
            row.max * 1000
        ))
    end

    print("=============================")
end

function ZSProfiler.AttachZSB()
    if ZSProfiler.zsbAttached then
        print("[ZSProfiler] ZSB profiler is already attached.")
        return
    end

    if type(ZSB) ~= "table" then
        print("[ZSProfiler] ZSB is not available.")
        return
    end

    PatchTableRecursive(ZSB, "ZSB", ZSProfiler.zsbPatches, {})
    ZSProfiler.zsbAttached = true

    print("[ZSProfiler] Attached profiler to ZSB.")
end

function ZSProfiler.DetachZSB()
    if not ZSProfiler.zsbAttached then
        print("[ZSProfiler] ZSB profiler is not attached.")
        return
    end

    RestorePatchList(ZSProfiler.zsbPatches)
    ZSProfiler.zsbAttached = false

    print("[ZSProfiler] Detached profiler from ZSB.")
end

function ZSProfiler.AttachHooks()
    if ZSProfiler.hooksAttached then
        print("[ZSProfiler] Hook profiler is already attached.")
        return
    end

    local allHooks = hook.GetTable()

    for eventName, eventHooks in pairs(allHooks) do
        if type(eventHooks) == "table" then
            for hookName, fn in pairs(eventHooks) do
                if StartsWithZS(hookName) and type(fn) == "function" then
                    AddPatch(
                        ZSProfiler.hookPatches,
                        eventHooks,
                        hookName,
                        fn,
                        "hook." .. tostring(eventName) .. "." .. tostring(hookName)
                    )
                end
            end
        end
    end

    ZSProfiler.hooksAttached = true

    print("[ZSProfiler] Attached profiler to ZS_ hooks.")
end

function ZSProfiler.DetachHooks()
    if not ZSProfiler.hooksAttached then
        print("[ZSProfiler] Hook profiler is not attached.")
        return
    end

    RestorePatchList(ZSProfiler.hookPatches)
    ZSProfiler.hooksAttached = false

    print("[ZSProfiler] Detached profiler from ZS_ hooks.")
end

function ZSProfiler.DetachAll()
    ZSProfiler.DetachHooks()
    ZSProfiler.DetachZSB()
end

function ZSProfiler.RescanZSB()
    ZSProfiler.DetachZSB()
    ZSProfiler.AttachZSB()
end

concommand.Add("leadbot_profiler_attach", function()
    ZSProfiler.AttachZSB()
end)

concommand.Add("leadbot_profiler_detach", function()
    ZSProfiler.DetachZSB()
end)

concommand.Add("leadbot_profiler_hooks_attach", function()
    ZSProfiler.AttachHooks()
end)

concommand.Add("leadbot_profiler_hooks_detach", function()
    ZSProfiler.DetachHooks()
end)

concommand.Add("leadbot_profiler_detach_all", function()
    ZSProfiler.DetachAll()
end)

concommand.Add("leadbot_profiler_reset", function()
    ZSProfiler.Reset()
    print("[ZSProfiler] Stats reset.")
end)

concommand.Add("leadbot_profiler_enable", function()
    ZSProfiler.enabled = true
    print("[ZSProfiler] Enabled.")
end)

concommand.Add("leadbot_profiler_disable", function()
    ZSProfiler.enabled = false
    print("[ZSProfiler] Disabled.")
end)

concommand.Add("leadbot_profiler_rescan", function()
    ZSProfiler.RescanZSB()
end)

concommand.Add("leadbot_profiler_print", function(_, _, args)
    ZSProfiler.Print(args and args[1] or nil)
end)