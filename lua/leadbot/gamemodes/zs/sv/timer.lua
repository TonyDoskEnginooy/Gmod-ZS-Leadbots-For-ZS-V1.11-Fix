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

local zombieStuckState = setmetatable({}, { __mode = "k" })

local unstuckOffsets = {
    Vector(0, 0, 18),
    Vector(0, 0, 36),
    Vector(24, 0, 0),
    Vector(-24, 0, 0),
    Vector(0, 24, 0),
    Vector(0, -24, 0),
    Vector(48, 0, 0),
    Vector(-48, 0, 0),
    Vector(0, 48, 0),
    Vector(0, -48, 0)
}

local function FindNearbyFreeSpot(bot)
    local origin = bot:GetPos()
    local mins, maxs = bot:OBBMins(), bot:OBBMaxs()

    for _, offset in ipairs(unstuckOffsets) do
        local candidate = origin + offset

        if util.IsInWorld(candidate) then
            local tr = util.TraceHull({
                start = candidate,
                endpos = candidate,
                mins = mins,
                maxs = maxs,
                mask = MASK_PLAYERSOLID,
                filter = bot
            })

            if not tr.Hit then
                return candidate
            end
        end
    end
end

timer.Create("zombieStuckDetector", 1, 0, function()
    if team.NumPlayers(TEAM_ZOMBIE) <= 0 then return end

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) or not bot:Alive() then continue end
        if bot:Team() ~= TEAM_ZOMBIE then continue end
        if bot:IsFrozen() then continue end
        if bot:GetMoveType() == MOVETYPE_LADDER then continue end

        local controller = bot.GetController and bot:GetController() or bot.ControllerBot
        if not IsValid(controller) then continue end

        local pos = bot:GetPos()

        if controller.IsTraversingStairs == true or ((controller.LastStairTime or 0) + 0.45 > CurTime()) then
            local state = zombieStuckState[bot]

            if state then
                state.lastPos = pos
                state.stuckSince = CurTime()
            end

            continue
        end
        local state = zombieStuckState[bot]

        if not state then
            zombieStuckState[bot] = {
                lastPos = pos,
                stuckSince = CurTime()
            }
            continue
        end

        local movedSqr = pos:DistToSqr(state.lastPos)
        state.lastPos = pos

        local goalPos = nil

        if IsValid(controller.Target) then
            goalPos = controller.Target:GetPos()
        elseif isvector(controller.PosGen) then
            goalPos = controller.PosGen
        end

        local hasGoal = isvector(goalPos) and pos:DistToSqr(goalPos) > 10000

        if not hasGoal then
            state.stuckSince = CurTime()
            continue
        end

        if movedSqr >= 64 then
            state.stuckSince = CurTime()
            continue
        end

        if CurTime() - state.stuckSince < 3 then
            continue
        end

        local freeSpot = FindNearbyFreeSpot(bot)

        if freeSpot then
            bot:SetPos(freeSpot)

            controller.Target = nil
            controller.PosGen = nil
            controller.LastSegmented = 0
        else
            bot:Kill()
        end

        state.lastPos = bot:GetPos()
        state.stuckSince = CurTime()
    end
end)