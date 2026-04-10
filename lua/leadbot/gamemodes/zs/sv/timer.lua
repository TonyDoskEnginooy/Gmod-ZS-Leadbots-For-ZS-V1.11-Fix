timer.Create("zombieNearDetector", 20, 0, function()
    if team.NumPlayers(TEAM_ZOMBIE) <= 0 then return end

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if bot:Team() ~= TEAM_ZOMBIE then continue end
        if bot:LBGetZomSkill() ~= 1 then continue end

        local controller = bot.ControllerBot
        if not controller then continue end
        if not controller.PosGen then continue end
        if IsValid(controller.Target) then continue end

        local botPos = bot:GetPos()
        local bestPos = controller.PosGen
        local bestDist = bestPos:DistToSqr(botPos)

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply:Team() ~= TEAM_SURVIVORS then continue end

            local plyPos = ply:GetPos()
            local dist = plyPos:DistToSqr(botPos)

            if dist < bestDist then
                bestDist = dist
                bestPos = plyPos
            end
        end

        if bestPos ~= controller.PosGen then
            controller.PosGen = bestPos
            controller.LastSegmented = CurTime() + 4000000
        end
    end
end)

timer.Create("zombieStuckDetector", 20, 0, function()
    if team.NumPlayers(TEAM_ZOMBIE) <= 0 then return end

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if bot:Team() ~= TEAM_ZOMBIE then continue end
        if bot:IsFrozen() then continue end
        if bot:GetVelocity():Length2DSqr() > 225 then continue end

        local controller = bot.ControllerBot
        if not controller then continue end

        local target = controller.Target
        local invalidTarget = not IsValid(target)
        local deadNonPlayerTarget = IsValid(target) and not target:IsPlayer() and target:Health() <= 0
        local unsupportedZombieClass = bot:GetZombieClass() > 3

        if invalidTarget or deadNonPlayerTarget or unsupportedZombieClass then
            bot:Kill()
        end
    end
end)