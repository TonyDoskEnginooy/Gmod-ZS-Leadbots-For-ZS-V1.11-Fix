local leadbot_hregen = GetConVar("leadbot_hregen")
local leadbot_cs = GetConVar("leadbot_cs")

local CHANGE_TO_NORMAL_ZOMBIE = {
    [1] = true
}

local NORMAL_ZOMBIE_CLASS = 1
local TORSO_ZOMBIE_CLASS = 9
local TORSO_HEIGHT_FIX = Vector(0, 0, -20)

local function GetSecondWindTimerName(bot)
    return bot:UniqueID() .. "secondwind"
end

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

local function TryTauntOnKill(victim, aggressor)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if not IsValid(aggressor) or not aggressor:IsPlayer() or not aggressor:IsLBot() then return end
    if aggressor == victim or aggressor:Team() == victim:Team() then return end
    if type(LeadBot) ~= "table" or type(LeadBot.TryTalkToMe) ~= "function" then return end

    timer.Simple(0, function()
        if not IsValid(aggressor) then return end

        if IsValid(victim)
        and victim:Team() == TEAM_ZOMBIE
        and timer.Exists(GetSecondWindTimerName(victim)) then
            return
        end

        if victim:Team() == TEAM_SURVIVORS then
            if ZSB.Util:Odds(70) then
                LeadBot.TryTalkToMe(aggressor, "taunt")
            end
            return
        end

        if ZSB.Util:Odds(50) then
            LeadBot.TryTalkToMe(aggressor, "taunt")
        end
    end)
end

function LeadBot.Death(victim, aggressor)
    if IsValid(victim) and victim:IsBot() and victim:Team() == TEAM_ZOMBIE then
        PreserveTorsoRespawn(victim)
        ResetZombieClassIfNeeded(victim)
        ApplyTorsoHeightFix(victim)

        timer.Simple(2.1, function()
            if IsValid(victim) then
                ApplyTorsoHeightFix(victim)
            end
        end)

        timer.Simple(2.6, function()
            if IsValid(victim) then
                ApplyTorsoHeightFix(victim)
            end
        end)
    end

    if aggressor ~= victim and IsValid(aggressor) and IsValid(victim) then
        TryTauntOnKill(victim, aggressor)

        if leadbot_hregen:GetBool()
        and aggressor:IsPlayer()
        and aggressor:IsBot()
        and aggressor:Team() == TEAM_SURVIVORS
        and victim:Team() == TEAM_ZOMBIE then
            local class = victim:GetZombieClass()
            local zombieClass = ZombieClasses and ZombieClasses[class]

            if zombieClass and zombieClass.Health then
                aggressor:SetHealth(aggressor:Health() + math.floor(zombieClass.Health / 10))
            end
        end

        if leadbot_cs:GetBool()
        and aggressor:IsPlayer()
        and aggressor:Team() == TEAM_ZOMBIE then
            victim:EmitSound("npc/fast_zombie/fz_scream1.wav", CHAN_REPLACE)
        end
    end
end
