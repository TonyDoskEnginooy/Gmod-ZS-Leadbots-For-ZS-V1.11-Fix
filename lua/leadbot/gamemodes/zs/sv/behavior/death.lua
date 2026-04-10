local leadbot_hregen = GetConVar("leadbot_hregen")
local leadbot_cs = GetConVar("leadbot_cs")

local CHANGE_TO_NORMAL_ZOMBIE = {
    [1] = true,
    [9] = true,
    [11] = true
}

local HEIGHT_FIX = Vector(0, 0, -20)

local function UpdateZombieClass(victimBot)
    if not IsValid(victimBot) or victimBot:Team() ~= TEAM_ZOMBIE then return end

    local class = victimBot:GetZombieClass()

    if CHANGE_TO_NORMAL_ZOMBIE[class] then
        victimBot:SetZombieClass(1)
    end

    if not victimBot:IsOnGround() then
        victimBot:SetPos(victimBot:GetPos() + HEIGHT_FIX)
    end
end

function LeadBot.Death(aggressor, victimBot)
    if IsValid(victimBot) and victimBot:IsBot() and victimBot:Team() == TEAM_ZOMBIE then
        UpdateZombieClass(victimBot)

        timer.Simple(2.1, function()
            if IsValid(victimBot) then
                UpdateZombieClass(victimBot)
            end
        end)

        timer.Simple(2.6, function()
            if IsValid(victimBot) then
                UpdateZombieClass(victimBot)
            end
        end)
    end

    if aggressor ~= victimBot and IsValid(aggressor) then
        if leadbot_hregen:GetBool()
        and aggressor:IsPlayer()
        and aggressor:IsBot()
        and aggressor:Team() == TEAM_SURVIVORS
        and IsValid(victimBot)
        and victimBot:Team() == TEAM_ZOMBIE then
            local class = victimBot:GetZombieClass()
            local zombieClass = ZombieClasses and ZombieClasses[class]

            if zombieClass and zombieClass.Health then
                aggressor:SetHealth(aggressor:Health() + math.floor(zombieClass.Health / 10))
            end
        end

        if leadbot_cs:GetBool()
        and aggressor:IsPlayer()
        and aggressor:Team() == TEAM_ZOMBIE
        and IsValid(victimBot) then
            victimBot:EmitSound("npc/fast_zombie/fz_scream1.wav", CHAN_REPLACE)
        end
    end
end