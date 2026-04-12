ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local FALLBACK_TEMPERAMENT = {
    name = "rusher",
    flankBias = 0.15,
    moveSpeedMul = 1.0
}

local function GetTemperament(bot)
    return bot.LeadBot_Temperament or FALLBACK_TEMPERAMENT
end

function SM.ApplyTemperamentMovement(bot, controller, mv)
    if bot:Team() ~= TEAM_ZOMBIE then return end
    if not IsValid(controller.Target) or not controller.Target:IsPlayer() then return end

    local temperament = GetTemperament(bot)
    local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

    if temperament.name == "flanker" then
        if distanceSqr > 6000 and distanceSqr < 100000 then
            local side = controller.strafeAngle == 1 and 750 or -750
            mv:SetSideSpeed(side)
        end
    elseif temperament.name == "drifter" then
        local rhythm = math.floor(CurTime() * 2 + (bot.LeadBot_PersonalitySeed or 0)) % 4

        if rhythm == 0 then
            mv:SetForwardSpeed(800)
        elseif rhythm == 1 then
            mv:SetSideSpeed(controller.strafeAngle == 1 and 350 or -350)
        end
    elseif temperament.name == "berserker" then
        if distanceSqr < 160000 then
            mv:SetForwardSpeed(1400)
        end
    elseif temperament.name == "rusher" then
        mv:SetForwardSpeed(1200 * temperament.moveSpeedMul)
    end
end
