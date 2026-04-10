-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")

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

local function OnSurvivorBotHurt(aggressor, victimBot)
    local controller = victimBot:GetController()
    if not controller then return end

    if aggressor:IsNPC() or AreDifferentTeams(victimBot, aggressor) then
        controller.Target = aggressor
        controller.ForgetTarget = CurTime() + 4
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

function LeadBot.TakeDamage(aggressor, victimBot, hp, dmgInfo)
    if not IsValid(victimBot) or not IsValidAggressor(aggressor) then return end

    local damage = dmgInfo:GetDamage()

    if leadbot_cs:GetBool()
    and aggressor:IsPlayer()
    and victimBot:Team() == TEAM_ZOMBIE
    and aggressor:Team() == TEAM_SURVIVORS then
        local force = dmgInfo:GetDamageForce()

        ZSB.playerCSSpeed = 1
        victimBot:SetVelocity(victimBot:GetVelocity() + (force / 4))
    end

    if hp <= damage then return end

    if victimBot:Team() == TEAM_SURVIVORS then
        OnSurvivorBotHurt(aggressor, victimBot)
    elseif victimBot:Team() == TEAM_ZOMBIE then
        OnZombieBotHurt(aggressor, victimBot)
    end
end