-- Modules
if engine.ActiveGamemode() ~= "zombiesurvival" then return end

local _, moduleDirs = file.Find("leadbot/modules/*", "LUA")

for _, moduleDir in ipairs(moduleDirs) do
    local files = file.Find("leadbot/modules/" .. moduleDir .. "/cl_*.lua", "LUA")
    table.Add(files, file.Find("leadbot/modules/" .. moduleDir .. "/sh_*.lua", "LUA"))

    for _, fileName in ipairs(files) do
        include("leadbot/modules/" .. moduleDir .. "/" .. fileName)
    end
end

include("leadbot/gamemodes/zombiesurvival.lua")