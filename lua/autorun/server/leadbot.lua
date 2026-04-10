if engine.ActiveGamemode() ~= "zombiesurvival" then return end

LeadBot = LeadBot or {}
LeadBot.NoNavMesh = LeadBot.NoNavMesh or {}
LeadBot.Models = LeadBot.Models or {}

--[[-----

CONFIG START CONFIG START
CONFIG START CONFIG START
CONFIG START CONFIG START

--]]-----

-- Name Prefix
LeadBot.Prefix = LeadBot.Prefix or ""

--[[-----

CONFIG END CONFIG END
CONFIG END CONFIG END
CONFIG END CONFIG END

--]]-----

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
            local path = "leadbot/modules/" .. dirName .. "/" .. fileName
            IncludeModuleFile(path, fileName)
        end
    end
end

local function IncludeMapConfig()
    local mapName = game.GetMap()
    local mapFiles = file.Find("leadbot/gamemodes/" .. mapName .. ".lua", "LUA")

    if mapFiles and mapFiles[1] then
        include("leadbot/gamemodes/" .. mapName .. ".lua")
    end
end

-- Load the base gamemode integration once.
include("leadbot/gamemodes/zombiesurvival.lua")

-- Load optional modules.
IncludeModules()

-- Load optional map-specific overrides.
IncludeMapConfig()