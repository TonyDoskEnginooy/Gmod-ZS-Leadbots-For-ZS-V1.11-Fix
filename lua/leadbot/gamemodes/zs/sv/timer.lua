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

local plyStuckState = setmetatable({}, { __mode = "k" })

local leadbot_mapchanges = GetConVar("leadbot_mapchanges")

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

local function GetPlayerHull(ply)
    if ply:Crouching() then
        return ply:GetHullDuck()
    end

    return ply:GetHull()
end

local function IsPlayerEmbeddedAt(ply, pos)
    local mins, maxs = GetPlayerHull(ply)

    local tr = util.TraceHull({
        start = pos,
        endpos = pos,
        mins = mins,
        maxs = maxs,
        mask = MASK_PLAYERSOLID,
        filter = ply
    })

    return tr.Hit or tr.StartSolid or tr.AllSolid
end

local function FindNearbyFreeSpotFromOrigin(ply, origin)
    for _, offset in ipairs(unstuckOffsets) do
        local candidate = origin + offset

        if not util.IsInWorld(candidate) then
            continue
        end

        if not IsPlayerEmbeddedAt(ply, candidate) then
            return candidate
        end
    end
end

local function FindNearbyFreeSpot(ply)
    return FindNearbyFreeSpotFromOrigin(ply, ply:GetPos())
end

local function GetRecoverySpawn(ply)
    if leadbot_mapchanges:GetBool() then
        local spawnGetterName = ply:Team() == TEAM_ZOMBIE and "fixedZombieSpawn" or "fixedPlayerSpawn"
        local fixedPos = ZSB.Map:GetValue(spawnGetterName)

        if isvector(fixedPos) then
            return fixedPos
        end
    end

    if GAMEMODE and GAMEMODE.PlayerSelectSpawn then
        local spawnEnt = GAMEMODE:PlayerSelectSpawn(ply)

        if IsValid(spawnEnt) then
            return spawnEnt:GetPos()
        end
    end
end

local function SendPlayerToRecoverySpawn(ply)
    local spawnPos = GetRecoverySpawn(ply)

    if not isvector(spawnPos) then
        return false
    end

    local freeSpot = FindNearbyFreeSpotFromOrigin(ply, spawnPos) or spawnPos
    ply:SetPos(freeSpot + Vector(0, 0, 1))

    return true
end

local function ResetBotPath(controller)
    controller.Target = nil
    controller.PosGen = nil
    controller.LastSegmented = 0
    controller.NextCenter = 0
    controller.NextJump = 0
end

local function addPlyStuckState(ply, pos)
    local state = plyStuckState[ply]

    if not state then
        state = {
            lastPos = pos,
            embeddedSince = nil,
            stalledSince = nil,
            counter = 0
        }

        plyStuckState[ply] = state
        return true
    end

    return false
end

timer.Create("plyStuckDetector", 1, 0, function()
    -- Bots are also ply
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then
            plyStuckState[ply] = nil
            continue
        end

        local pos = ply:GetPos()

        if addPlyStuckState(ply, pos) then
            continue
        end

        local state = plyStuckState[ply]

        local outsideWorld = not ply:IsInWorld()
        local embedded = IsPlayerEmbeddedAt(ply, pos)

        if outsideWorld or embedded then
            if state.counter < 4 then
                state.counter = state.counter + 1
                continue
            end

            local movedToSpawn = SendPlayerToRecoverySpawn(ply)
            plyStuckState[ply] = nil

            if not ply:IsBot() then
                continue
            end

            local earlyController = ply.GetController and ply:GetController() or ply.ControllerBot
            if IsValid(earlyController) then
                ResetBotPath(earlyController)
            end

            if movedToSpawn then
                pos = ply:GetPos()
            end
        end

        if not ply:IsBot() then
            continue
        end

        if ply:IsFrozen() then continue end
        if ply:GetMoveType() == MOVETYPE_LADDER then continue end

        local controller = ply.GetController and ply:GetController() or ply.ControllerBot
        if not IsValid(controller) then
            plyStuckState[ply] = nil
            continue
        end

        local now = CurTime()
        local movedSqr = pos:DistToSqr(state.lastPos)
        local speed2DSqr = ply:GetVelocity():Length2DSqr()
        local hasGoal = IsValid(controller.Target) or isvector(controller.PosGen)
        embedded = IsPlayerEmbeddedAt(ply, pos)
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
            if state.counter then
                state.counter = 0
            end

            continue
        elseif state.counter < 4 then
            state.counter = state.counter + 1
            continue
        end

        local freeSpot = FindNearbyFreeSpot(ply)

        if freeSpot then
            ply:SetPos(freeSpot + Vector(0, 0, 1))
            ResetBotPath(controller)
        else
            ResetBotPath(controller)

            if ply:Team() == TEAM_ZOMBIE then
                ply:Kill()
            end
        end

        state.lastPos = ply:GetPos()
        state.embeddedSince = nil
        state.stalledSince = nil
        state.counter = 0
    end
end)