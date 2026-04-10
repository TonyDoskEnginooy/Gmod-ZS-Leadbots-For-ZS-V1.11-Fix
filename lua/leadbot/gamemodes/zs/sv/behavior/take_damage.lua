-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")

local function OnSurvivorBotHurt(aggressor, victimBot, hp, dmg)
    local controller = victimBot:GetController()
    local haveDifferentTeams = victimBot:Team() ~= aggressor:Team()

    --[[
    if victimBot:Health() <= 10 and ZSB.Util:Odds(10) then -- don't spam
        LeadBot.TalkToMe(aggressor, "help")
    end

    if not aggressor:IsNPC() and victimBot:Health() <= 40 and ZSB.Util:Odds(50) then -- don't spam
        LeadBot.TalkToMe(aggressor, "pain")
    end
    --]]

    if aggressor:IsNPC() or haveDifferentTeams then
        controller.Target = aggressor
        controller.ForgetTarget = CurTime() + 4
    end
end

local function OnZombieBotHurt(aggressor, victimBot, hp, dmg)
    local controller = victimBot:GetController()
    local distance = victimBot:GetPos():DistToSqr(controller.PosGen)
    local hurtDistance = victimBot:GetPos():DistToSqr(aggressor:GetPos())
    local haveDifferentTeams = victimBot:Team() ~= aggressor:Team()

    if not aggressor:IsNPC() and haveDifferentTeams and hurtDistance < distance then
        controller.PosGen = aggressor:GetPos()
        controller.LastSegmented = CurTime() + 5 
        controller.LookAtTime = CurTime() + 2

        if not aggressor:IsFrozen() then 
            controller.LookAt = (aggressor:GetPos() - victimBot:GetPos()):Angle()
        end
    end

    if IsValid(controller.Target) then
        local distance = victimBot:GetPos():DistToSqr(controller.Target:GetPos())

        if not aggressor:IsNPC() and haveDifferentTeams and distance > hurtDistance then
            controller.Target = aggressor
            controller.ForgetTarget = CurTime() + 4
        end
    end
end

function LeadBot.TakeDamage(aggressor, victimBot, hp, dmg)
    if not (aggressor:IsPlayer() or aggressor:IsNPC()) or not victimBot.Team or not aggressor.Team then
        return
    end

    if leadbot_cs:GetInt() >= 1 then
        if victimBot:Team() == TEAM_ZOMBIE and aggressor:Team() == TEAM_SURVIVORS then 
            local force = dmg:GetDamageForce()
            ZSB.playerCSSpeed = 1
            victimBot:SetVelocity(victimBot:GetVelocity() + (force / 4))
        end
    end

    if hp < dmg then return end

    --[[
    if ZSB.Util:Odds(50) and aggressor:IsPlayer() then
        LeadBot.TalkToMe(aggressor, "taunt")
    end
    --]]

    if victimBot:Team() == TEAM_SURVIVORS then 
        OnSurvivorBotHurt(aggressor, victimBot, hp, dmg)
    end

    if victimBot:Team() == TEAM_ZOMBIE then
        OnZombieBotHurt(aggressor, victimBot, hp, dmg)
    end
end