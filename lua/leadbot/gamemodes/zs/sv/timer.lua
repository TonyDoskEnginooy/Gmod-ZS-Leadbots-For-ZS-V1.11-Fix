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
    Vector(24, 0, 18),
    Vector(-24, 0, 18),
    Vector(0, 24, 18),
    Vector(0, -24, 18),
    Vector(24, 24, 18),
    Vector(24, -24, 18),
    Vector(-24, 24, 18),
    Vector(-24, -24, 18),
    Vector(48, 0, 18),
    Vector(-48, 0, 18),
    Vector(0, 48, 18),
    Vector(0, -48, 18),
    Vector(0, 0, 72)
}

local function GetBotHull(bot)
    if bot:Crouching() then
        return bot:GetHullDuck()
    end

    return bot:GetHull()
end

local function IsBotEmbeddedAt(bot, pos)
    local mins, maxs = GetBotHull(bot)

    local tr = util.TraceHull({
        start = pos,
        endpos = pos,
        mins = mins,
        maxs = maxs,
        mask = MASK_PLAYERSOLID,
        filter = bot
    })

    return tr.Hit or tr.StartSolid or tr.AllSolid
end

local function FindNearbyFreeSpot(bot)
    local origin = bot:GetPos()

    for _, offset in ipairs(unstuckOffsets) do
        local candidate = origin + offset

        if not util.IsInWorld(candidate) then
            continue
        end

        if not IsBotEmbeddedAt(bot, candidate) then
            return candidate
        end
    end
end

local function ResetBotPath(controller)
    controller.Target = nil
    controller.PosGen = nil
    controller.LastSegmented = 0
    controller.NextCenter = 0
    controller.NextJump = 0
end

timer.Create("zombieStuckDetector", 1, 0, function()
    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) or not bot:Alive() then
            zombieStuckState[bot] = nil
            continue
        end

        if bot:IsFrozen() then continue end
        if bot:GetMoveType() == MOVETYPE_LADDER then continue end

        local controller = bot.GetController and bot:GetController() or bot.ControllerBot
        if not IsValid(controller) then
            zombieStuckState[bot] = nil
            continue
        end

        local now = CurTime()
        local pos = bot:GetPos()
        local state = zombieStuckState[bot]

        if not state then
            state = {
                lastPos = pos,
                embeddedSince = nil,
                stalledSince = nil
            }

            zombieStuckState[bot] = state
            continue
        end

        local movedSqr = pos:DistToSqr(state.lastPos)
        local speed2DSqr = bot:GetVelocity():Length2DSqr()
        local hasGoal = IsValid(controller.Target) or isvector(controller.PosGen)
        local embedded = IsBotEmbeddedAt(bot, pos)
        local stalled = hasGoal and speed2DSqr < 36 and movedSqr < 9

        if embedded then
            state.embeddedSince = state.embeddedSince or now
        else
            state.embeddedSince = nil
        end

        if stalled then
            state.stalledSince = state.stalledSince or now
        else
            state.stalledSince = nil
        end

        state.lastPos = pos

        local shouldUnstuck =
            (state.embeddedSince and now - state.embeddedSince >= 0.25)
            or (state.stalledSince and now - state.stalledSince >= 1.5)

        if not shouldUnstuck then
            continue
        end

        local freeSpot = FindNearbyFreeSpot(bot)

        if freeSpot then
            bot:SetPos(freeSpot + Vector(0, 0, 1))
            ResetBotPath(controller)
        else
            ResetBotPath(controller)

            if bot:Team() == TEAM_ZOMBIE then
                bot:Kill()
            end
        end

        state.lastPos = bot:GetPos()
        state.embeddedSince = nil
        state.stalledSince = nil
    end
end)