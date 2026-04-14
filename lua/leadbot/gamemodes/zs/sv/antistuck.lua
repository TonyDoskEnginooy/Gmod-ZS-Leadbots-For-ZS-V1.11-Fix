timer.Create("zombieNearDetector", 20, 0, function()
    if team.NumPlayers(TEAM_ZOMBIE) <= 0 then return end

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if bot:Team() ~= TEAM_ZOMBIE then continue end
        if bot:LBGetzomSkill() ~= 1 then continue end

        local controller = bot.ControllerBot
        if not controller then continue end
        if not controller.PosGen then continue end
        if IsValid(controller.Target) then continue end

        local botPos = bot:GetPos()
        local bestPos = controller.PosGen
        local bestDist = bestPos:DistToSqr(botPos)
        local foundEnts = ZSB.Util:FindEnts(bot)

        for _, ply in ipairs(foundEnts.near["player"]) do
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
        end
    end
end)

local stuckState = setmetatable({}, { __mode = "k" })

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

local leadbot_mapchanges = GetConVar("leadbot_mapchanges")

local LADDER_ESCAPE_DELAY = 1.2

local function GetPlayerHull(ply)
    if ply:Crouching() then
        return ply:GetHullDuck()
    end

    return ply:GetHull()
end

local function UpdateBotLadderEscapeState(ply, state)
    if not IsValid(ply) or not ply:IsBot() then
        if state then
            state.nextLadderEscape = 0
        end

        return false
    end

    if ply:GetMoveType() ~= MOVETYPE_LADDER then
        if state.nextLadderEscape > 0 then
            state.nextLadderEscape = 0
        end

        return false
    end

    local now = CurTime()
    local lowSpeed = ply:GetVelocity():Length2DSqr() <= 225

    if lowSpeed and state.nextLadderEscape == 0 then
        state.nextLadderEscape = now + LADDER_ESCAPE_DELAY
    elseif not lowSpeed and state.nextLadderEscape > 0 then
        state.nextLadderEscape = 0
    end

    if state.nextLadderEscape > 0 and state.nextLadderEscape <= now then
        local ladder = ZSB.GetPlayerActiveLadderData(ply)

        if IsValid(ladder) then
            ply:ExitLadder()
            ply:SetVelocity(ladder.normal * 300)
            state.nextLadderEscape = 0

            return true
        end

        return false
    end

    return true
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
            return fixedPos()
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
    controller.ForgetTarget = 0
    controller.NextStrafe = 0
    controller.NextJump = 0
end

local function AddStuckState(ply, pos)
    local state = stuckState[ply]

    if not state then
        stuckState[ply] = {
            lastPos = pos,
            outsideWorldCounter = 0,
            embeddedCounter = 0,
            stalledCounter = 0,
            nextLadderEscape = 0
        }

        return true
    end

    return false
end

local function ResetStuckState(ply)
    local state = stuckState[ply]

    if state then
        state.lastPos = ply:GetPos()
        state.outsideWorldCounter = 0
        state.embeddedCounter = 0
        state.stalledCounter = 0
        state.nextLadderEscape = 0
    end
end

local function MovePlyToFreeSpot(ply, controller)
    local freeSpot = FindNearbyFreeSpot(ply)

    if freeSpot then
        ply:SetPos(freeSpot + Vector(0, 0, 1))
    else
        if ply:Team() == TEAM_ZOMBIE then
            ply:Kill()
        end
    end

    if controller then
        ResetBotPath(controller)
    end

    return freeSpot != nil
end

timer.Create("botStuckDetector", 1, 0, function()
    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) or not bot:Alive() then
            stuckState[bot] = nil
            continue
        end

        if bot:IsFrozen() then continue end

        local pos = bot:GetPos()

        if AddStuckState(bot, pos) then
            continue
        end

        local state = stuckState[bot]

        if UpdateBotLadderEscapeState(bot, state) then
            state.lastPos = pos
            continue
        end

        local outsideWorld = not bot:IsInWorld()

        if outsideWorld then
            if state.outsideWorldCounter < 4 then
                state.outsideWorldCounter = state.outsideWorldCounter + 1
                continue
            end

            SendPlayerToRecoverySpawn(bot)
            ResetStuckState(bot)

            if not bot:IsBot() then
                continue
            end

            local controller = bot.GetController and bot:GetController() or bot.ControllerBot

            if IsValid(controller) then
                ResetBotPath(controller)
            end

            continue
        elseif outsideWorldCounter then
            state.outsideWorldCounter = 0 
        end

        local controller = bot.GetController and bot:GetController() or bot.ControllerBot

        if not IsValid(controller) then
            stuckState[bot] = nil
            continue
        end

        local movedSqr = pos:DistToSqr(state.lastPos)
        local speed2DSqr = bot:GetVelocity():Length2DSqr()
        local hasGoal = IsValid(controller.Target) or isvector(controller.PosGen)
        local embedded = IsPlayerEmbeddedAt(bot, pos)
        local stalled = hasGoal and speed2DSqr < 36 and movedSqr < 9

        state.lastPos = pos

        if embedded then
            state.embeddedCounter = state.embeddedCounter + 1
        elseif state.embeddedCounter then
            state.embeddedCounter = 0 
        end

        if stalled then
            state.stalledCounter = state.stalledCounter + 1
        elseif state.stalledCounter then
            state.stalledCounter = 0 
        end

        if state.embeddedCounter > 4 or state.stalledCounter > 4 then
            MovePlyToFreeSpot(bot, controller)
            ResetStuckState(bot)
        end
    end
end)

timer.Create("plyStuckDetector", 1, 0, function()
    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) or not ply:Alive() then
            stuckState[ply] = nil
            continue
        end

        local pos = ply:GetPos()

        if AddStuckState(ply, pos) then
            continue
        end

        local state = stuckState[ply]

        if ply:IsBot() and UpdateBotLadderEscapeState(ply, state) then
            state.lastPos = pos
            continue
        end

        local outsideWorld = not ply:IsInWorld()
        local embedded = IsPlayerEmbeddedAt(ply, pos)

        if outsideWorld then
            state.outsideWorldCounter = state.outsideWorldCounter + 1
        elseif state.outsideWorldCounter then
            state.outsideWorldCounter = 0 
        end

        if embedded then
            state.embeddedCounter = state.embeddedCounter + 1
        elseif state.embeddedCounter then
            state.embeddedCounter = 0 
        end

        if state.outsideWorldCounter > 4 then
            SendPlayerToRecoverySpawn(ply)
            ResetStuckState(ply)
        end

        if state.embeddedCounter > 5 then
            if not MovePlyToFreeSpot(ply) then
                SendPlayerToRecoverySpawn(ply)
            end
            ResetStuckState(ply)
        end
    end
end)