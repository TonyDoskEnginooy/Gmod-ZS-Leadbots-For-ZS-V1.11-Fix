if engine.ActiveGamemode() == "zombiesurvival" then     
    --if game.SinglePlayer() or CLIENT then return end

    LeadBot = {}
    LeadBot.NoNavMesh = {}
    LeadBot.Models = {} -- Models, leave as {} if random is desired

    --[[-----

    CONFIG START CONFIG START
    CONFIG START CONFIG START
    CONFIG START CONFIG START

    --]]-----

    -- Name Prefix

    LeadBot.Prefix = ""

    --[[-----

    CONFIG END CONFIG END
    CONFIG END CONFIG END
    CONFIG END CONFIG END

    --]]-----
    include("leadbot/gamemodes/zombiesurvival.lua")

    -- Modules

    local _, dir = file.Find("leadbot/modules/*", "LUA")

    for k, v in pairs(dir) do
        local f = table.Add(file.Find("leadbot/modules/" .. v .. "/sv_*.lua", "LUA"), file.Find("leadbot/modules/" .. v .. "/sh_*.lua", "LUA"))
        f = table.Add(f, file.Find("leadbot/modules/" .. v .. "/cl_*.lua", "LUA"))
        for i, o in pairs(f) do
            local path = "leadbot/modules/" .. v .. "/" .. o

            if string.StartWith(o, "cl_") then
                AddCSLuaFile(path)
            else
                include(path)
                if string.StartWith(o, "sh_") then
                    AddCSLuaFile(path)
                end
            end
        end
    end

    -- Configs

    local map = game.GetMap()
    local gamemodeName = engine.ActiveGamemode()

    if file.Find("leadbot/gamemodes/" .. map .. ".lua", "LUA")[1] then
        include("leadbot/gamemodes/" .. map .. ".lua")
    elseif file.Find("leadbot/gamemodes/" .. gamemodeName .. ".lua", "LUA")[1] then
        print("including " .. "leadbot/gamemodes/" .. gamemodeName .. ".lua")
        include("leadbot/gamemodes/" .. gamemodeName .. ".lua")
    end
end