-- Cache cvars
local leadbot_hregen = GetConVar("leadbot_hregen")
local leadbot_cs = GetConVar("leadbot_cs")

local function UpdateZombieClass(victimBot)
    if not IsValid(victimBot) then return end

    local curZombieClass = victimBot:GetZombieClass()
    local changeToNormalZombie = {
        [1] = true,
        [9] = true,
        [11] = true
    }   

    if changeToNormalZombie[curZombieClass] then 
        victimBot:SetZombieClass(1)
    end

    if not victimBot:IsOnGround() then 
        local pos = victimBot:GetPos()
        local heightFix = Vector(0, 0, -20)

        victimBot:SetPos(pos + heightFix)
    end
end

function LeadBot.Death(aggressor, victimBot)
    if victimBot:IsBot() and victimBot:Alive() and victimBot:Team() == TEAM_ZOMBIE then
        local curZombieClass = victimBot:GetZombieClass()

        UpdateZombieClass(victimBot)

        -- Second wind stopper 1
        timer.Simple(2.1, function()
            UpdateZombieClass(victimBot)
        end)

        -- Second wind stopper 2
        timer.Simple(2.6, function()
            UpdateZombieClass(victimBot)
        end)
    end

    if aggressor ~= victimBot then
        if leadbot_hregen:GetInt() >= 1 then
            if aggressor:IsPlayer() and aggressor:IsBot() and aggressor:Team() == TEAM_SURVIVORS then
                local class = victimBot:GetZombieClass()
                local newHP = ZombieClasses[class].Health / 10

                aggressor:SetHealth(aggressor:Health() + math.floor(newHP) )
            end
        end

        if leadbot_cs:GetInt() >= 1 then 
            if aggressor:IsPlayer() and aggressor:Team() == TEAM_ZOMBIE then 
                victimBot:EmitSound("npc/fast_zombie/fz_scream1.wav", CHAN_REPLACE)
            end
        end
    end
end