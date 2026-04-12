-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")

local HELP_DAMAGE_THRESHOLD = 18
local PAIN_DAMAGE_THRESHOLD = 8
local LOW_HEALTH_THRESHOLD = 35
local CLOSE_THREAT_DISTANCE_SQR = 225 * 225
local CLOSE_THREAT_STICK_TIME = 1.1

local SC = ZSB and ZSB.StartCommand

local function IsValidAggressor(ent)
    return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC())
end

local function AreDifferentTeams(victimBot, aggressor)
    return aggressor:IsPlayer() and victimBot:Team() ~= aggressor:Team()
end

local function GetController(victimBot)
    local controller = victimBot:GetController()

    if not controller or not controller.PosGen then
        return nil
    end

    return controller
end

local function MarkRecentSurvivorThreat(victimBot, controller, aggressor)
    if type(SC) ~= "table" then return end
    if not isfunction(SC.IsZombiePlayerEnemy) or not isfunction(SC.SetRecentCloseThreat) then return end
    if not SC.IsZombiePlayerEnemy(victimBot, aggressor) then return end
    if victimBot:GetPos():DistToSqr(aggressor:GetPos()) > CLOSE_THREAT_DISTANCE_SQR then return end

    SC.SetRecentCloseThreat(controller, aggressor, CLOSE_THREAT_STICK_TIME)
end

local function OnSurvivorBotHurt(aggressor, victimBot)
    local controller = victimBot:GetController()
    if not controller then return end

    if (aggressor:IsNPC() or AreDifferentTeams(victimBot, aggressor))
    and not (aggressor:IsPlayer() and aggressor:HasGodMode())
    and ZSB.Util:CanPerceiveTarget(victimBot, aggressor) then
        controller.Target = aggressor
        controller.ForgetTarget = CurTime() + 4
        controller.PosGen = aggressor:GetPos()
        controller.LastSegmented = CurTime() + 0.1
        controller.LookAt = (aggressor:WorldSpaceCenter() - victimBot:GetShootPos()):Angle()
        controller.LookAtTime = CurTime() + 0.2

        MarkRecentSurvivorThreat(victimBot, controller, aggressor)
    end
end

local function OnZombieBotHurt(aggressor, victimBot)
    local controller = GetController(victimBot)
    if not controller then return end

    if not aggressor:IsNPC() and AreDifferentTeams(victimBot, aggressor) then
        local victimPos = victimBot:GetPos()
        local aggressorPos = aggressor:GetPos()

        local pathDistance = victimPos:DistToSqr(controller.PosGen)
        local hurtDistance = victimPos:DistToSqr(aggressorPos)

        if hurtDistance < pathDistance then
            controller.PosGen = aggressorPos
            controller.LastSegmented = CurTime() + 5
            controller.LookAtTime = CurTime() + 2

            if not aggressor:IsFrozen() then
                controller.LookAt = (aggressorPos - victimPos):Angle()
            end
        end

        if IsValid(controller.Target) then
            local targetDistance = victimPos:DistToSqr(controller.Target:GetPos())

            if targetDistance > hurtDistance then
                controller.Target = aggressor
                controller.ForgetTarget = CurTime() + 4
            end
        end
    end
end

local function CanUseBotVoice(victimBot)
    return type(LeadBot) == "table" and type(LeadBot.TryTalkToMe) == "function" and IsValid(victimBot) and victimBot:IsLBot()
end

local function TryPainVoice(victimBot, damage)
    if not CanUseBotVoice(victimBot) then return end
    if damage < PAIN_DAMAGE_THRESHOLD then return end

    local chance = damage >= HELP_DAMAGE_THRESHOLD and 55 or 35
    if ZSB.Util:Odds(chance) then
        LeadBot.TryTalkToMe(victimBot, "pain")
    end
end

local function TryHelpVoice(victimBot, postDamageHealth, damage)
    if not CanUseBotVoice(victimBot) then return end
    if victimBot:Team() ~= TEAM_SURVIVORS then return end

    if postDamageHealth <= LOW_HEALTH_THRESHOLD or damage >= HELP_DAMAGE_THRESHOLD then
        local chance = postDamageHealth <= LOW_HEALTH_THRESHOLD and 75 or 45
        if ZSB.Util:Odds(chance) then
            LeadBot.TryTalkToMe(victimBot, "help")
            return
        end
    end

    TryPainVoice(victimBot, damage)
end

local function TryDownedVoice(victimBot, hp, damage, dmgInfo)
    if not CanUseBotVoice(victimBot) then return end
    if victimBot:Team() ~= TEAM_SURVIVORS then return end
    if hp > damage then return end
    if dmgInfo:IsExplosionDamage() or dmgInfo:IsFallDamage() then return end
    if hp - damage <= -35 then return end

    LeadBot.TryTalkToMe(victimBot, "downed")
end

function LeadBot.TakeDamage(aggressor, victimBot, hp, dmgInfo)
    if not IsValid(victimBot) then return end

    local damage = dmgInfo:GetDamage()

    if hp <= damage then
        TryDownedVoice(victimBot, hp, damage, dmgInfo)
    else
        TryHelpVoice(victimBot, hp - damage, damage)
    end

    if not IsValidAggressor(aggressor) then return end

    if leadbot_cs:GetBool()
    and aggressor:IsPlayer()
    and victimBot:Team() == TEAM_ZOMBIE
    and aggressor:Team() == TEAM_SURVIVORS then
        local force = dmgInfo:GetDamageForce()

        ZSB.playerCSSpeed = 1
        victimBot:SetVelocity(victimBot:GetVelocity() + (force / 4))
    end

    if hp <= damage then
        return
    end

    if victimBot:Team() == TEAM_SURVIVORS then
        OnSurvivorBotHurt(aggressor, victimBot)
    elseif victimBot:Team() == TEAM_ZOMBIE then
        OnZombieBotHurt(aggressor, victimBot)
    end
end
