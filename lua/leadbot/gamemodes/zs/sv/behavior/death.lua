local leadbot_hregen = GetConVar("leadbot_hregen")
local leadbot_cs = GetConVar("leadbot_cs")

local CHANGE_TO_NORMAL_ZOMBIE = {
    [1] = true
}

local NORMAL_ZOMBIE_CLASS = 1
local TORSO_ZOMBIE_CLASS = 9
local TORSO_HEIGHT_FIX = Vector(0, 0, -20)

local function PreserveTorsoRespawn(victimBot)
    if not IsValid(victimBot) or victimBot:Team() ~= TEAM_ZOMBIE then return end
    if victimBot:GetZombieClass() ~= TORSO_ZOMBIE_CLASS then return end

    -- Preserve the torso class for the next spawn triggered by SecondWind.
    victimBot.LeadBot_PreserveZombieClass = TORSO_ZOMBIE_CLASS
end

local function ResetZombieClassIfNeeded(victimBot)
    if not IsValid(victimBot) or victimBot:Team() ~= TEAM_ZOMBIE then return end

    local class = victimBot:GetZombieClass()
    if CHANGE_TO_NORMAL_ZOMBIE[class] then
        victimBot:SetZombieClass(NORMAL_ZOMBIE_CLASS)
    end
end

local function ApplyTorsoHeightFix(victimBot)
    if not IsValid(victimBot) or victimBot:Team() ~= TEAM_ZOMBIE then return end
    if victimBot:GetZombieClass() ~= TORSO_ZOMBIE_CLASS then return end
    if victimBot:IsOnGround() then return end

    victimBot:SetPos(victimBot:GetPos() + TORSO_HEIGHT_FIX)
end

function LeadBot.Death(victimBot, aggressor)
    if IsValid(victimBot) and victimBot:IsBot() and victimBot:Team() == TEAM_ZOMBIE then
        PreserveTorsoRespawn(victimBot)
        ResetZombieClassIfNeeded(victimBot)
        ApplyTorsoHeightFix(victimBot)

        timer.Simple(2.1, function()
            if IsValid(victimBot) then
                ApplyTorsoHeightFix(victimBot)
            end
        end)

        timer.Simple(2.6, function()
            if IsValid(victimBot) then
                ApplyTorsoHeightFix(victimBot)
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
