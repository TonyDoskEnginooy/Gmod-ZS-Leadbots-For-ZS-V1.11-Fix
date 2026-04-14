if engine.ActiveGamemode() ~= "zombiesurvival" then return end

LeadBot = LeadBot or {}
LeadBot.NoNavMesh = LeadBot.NoNavMesh or {}
LeadBot.Models = LeadBot.Models or {}
LeadBot.Prefix = LeadBot.Prefix or ""

local function IncludeModuleFile(path, filename)
    if string.StartsWith(filename, "cl_") then
        AddCSLuaFile(path)
        return
    end

    include(path)

    if string.StartsWith(filename, "sh_") then
        AddCSLuaFile(path)
    end
end

local function IncludeModules()
    local _, moduleDirs = file.Find("leadbot/modules/*", "LUA")

    for _, dirName in ipairs(moduleDirs or {}) do
        local files = {}

        table.Add(files, file.Find("leadbot/modules/" .. dirName .. "/sv_*.lua", "LUA") or {})
        table.Add(files, file.Find("leadbot/modules/" .. dirName .. "/sh_*.lua", "LUA") or {})
        table.Add(files, file.Find("leadbot/modules/" .. dirName .. "/cl_*.lua", "LUA") or {})

        for _, fileName in ipairs(files) do
            IncludeModuleFile("leadbot/modules/" .. dirName .. "/" .. fileName, fileName)
        end
    end
end

local function IncludeMapOrGamemodeConfig()
    local gamemodeName = engine.ActiveGamemode()
    local gamemodePath = "leadbot/gamemodes/" .. gamemodeName .. ".lua"

    if file.Exists(gamemodePath, "LUA") then
        include(gamemodePath)
    end
end

AddCSLuaFile("leadbot/gamemodes/zombiesurvival.lua")
include("leadbot/gamemodes/zombiesurvival.lua")
IncludeModules()
IncludeMapOrGamemodeConfig()