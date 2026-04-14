ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local LARGE_RANDOM_SPOT_OPTIONS = { radius = 5000 }

local SURVIVOR_ANCHOR_REACHED_DIST_SQR = 2500

local SURVIVOR_FREE_ROAM_DISABLE_HP = 35
local SURVIVOR_FREE_ROAM_ENABLE_HP = 65
local SURVIVOR_FREE_ROAM_TEAM_MARGIN = 1

local zombieExplorationBuckets = {
    "func_breakable",
    "func_breakable_surf",
    "func_physbox",
    "prop_physics",
    "prop_dynamic",
    "prop_door_rotating",
    "func_movelinear"
}

function SC.SetRoamState(bot)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    if bot.freeRoam == nil then
        bot.freeRoam = true
    end

    local survivorCount = team.NumPlayers(TEAM_SURVIVORS)
    local zombieCount = team.NumPlayers(TEAM_ZOMBIE)

    if bot.freeRoam then
        if bot:Health() <= SURVIVOR_FREE_ROAM_DISABLE_HP
        or survivorCount <= zombieCount then
            bot.freeRoam = false
        end

        return
    end

    if bot:Health() >= SURVIVOR_FREE_ROAM_ENABLE_HP
    and survivorCount > (zombieCount + SURVIVOR_FREE_ROAM_TEAM_MARGIN) then
        bot.freeRoam = true
    end
end

local function GetExplorationEntPos(ent, referencePos)
    if not IsValid(ent) then
        return nil
    end

    if isvector(referencePos) and ent.NearestPoint then
        local ok, nearestPoint = pcall(ent.NearestPoint, ent, referencePos)

        if ok and isvector(nearestPoint) then
            return nearestPoint
        end
    end

    if ent.WorldSpaceCenter then
        local ok, worldCenter = pcall(ent.WorldSpaceCenter, ent)

        if ok and isvector(worldCenter) then
            return worldCenter
        end
    end

    if ent.OBBCenter and ent.LocalToWorld then
        local ok, localCenter = pcall(ent.OBBCenter, ent)

        if ok and isvector(localCenter) then
            local okWorld, worldCenter = pcall(ent.LocalToWorld, ent, localCenter)

            if okWorld and isvector(worldCenter) then
                return worldCenter
            end
        end
    end

    return ent:GetPos()
end

local function IsZombieExplorationEnt(bot, ent)
    if not IsValid(bot) or not IsValid(ent) then
        return false
    end

    local className = ent:GetClass()

    if SC.IsSimpleObstacleTarget(bot, ent) then
        return true
    end

    return className == "prop_door_rotating" or className == "func_movelinear"
end

local function GetRandomRoamPos(controller)
    return controller:FindSpot("random", { radius = 5000 })
end

local function TrySetZombieExplorationGoal(bot, controller)
    local foundEnts = ZSB.Util:FindEnts(bot)
    if not foundEnts then
        return false
    end

    if math.random(1, 100) <= 60 then
        controller.PosGen = GetRandomRoamPos(controller)
        return true
    else
        for _, scopeName in ipairs({ "facing", "area" }) do
            local scope = foundEnts[scopeName]

            if istable(scope) then
                for _, bucketName in RandomPairs(zombieExplorationBuckets) do
                    local bucket = scope[bucketName]

                    if istable(bucket) then
                        for _, ent in RandomPairs(bucket) do
                            if IsZombieExplorationEnt(bot, ent) then
                                local targetPos = GetExplorationEntPos(ent, bot:GetPos())

                                if isvector(targetPos) then
                                    controller.PosGen = targetPos
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

local function GetSurvivorCampingSpot(strategy)
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")
    if not istable(campingSpotList) then return nil end

    return campingSpotList[strategy]
end

local function GetDistributedZombiePressurePos(bot, now)
    local zombieList = {}

    for _, candidate in ipairs(player.GetAll()) do
        if IsValid(candidate)
        and candidate:Alive()
        and candidate:Team() == TEAM_ZOMBIE
        and not candidate:HasGodMode()
        then
            zombieList[#zombieList + 1] = candidate
        end
    end

    if #zombieList <= 0 then
        return nil
    end

    if #zombieList > 1 then
        table.sort(zombieList, function(a, b)
            return a:EntIndex() < b:EntIndex()
        end)
    end

    local seed = bot.LBConfig.personalitySeed or bot:EntIndex() or 1
    local timeBucket = math.floor((now or CurTime()) * 0.65)
    local index = ((seed + timeBucket) % #zombieList) + 1
    local target = zombieList[index]

    if not IsValid(target) then
        return nil
    end

    return target:GetPos()
end

local function GetRandomAliveSurvivorPos(bot)
    for _, candidate in RandomPairs(player.GetAll()) do
        if IsValid(candidate)
        and candidate ~= bot
        and candidate:Team() == TEAM_SURVIVORS
        and candidate:Alive()
        then
            return candidate:GetPos()
        end
    end

    return nil
end

local function ResolveSurvivorTargetPos(bot, controller, strategy, now)
    -- Free roam / no strategy: prefer zombie pressure, otherwise random roam.
    if strategy == 0 then
        local pressurePos = GetDistributedZombiePressurePos(bot, now)

        if pressurePos or ZSB.Util:Odds(50) then
            return pressurePos
        end

        return GetRandomRoamPos(controller)
    end

    -- Anchored survivor strategies.
    if strategy >= 1 and strategy <= 3 and ZSB.Util:Odds(10) then
        local campingSpot = GetSurvivorCampingSpot(strategy)

        if campingSpot then
            if bot:GetPos():DistToSqr(campingSpot) <= SURVIVOR_ANCHOR_REACHED_DIST_SQR then
                return nil
            end

            return campingSpot
        end
    end

    if strategy == 1 then
        local campingSpot = GetSurvivorCampingSpot(strategy)

        if ZSB.Util:Odds(35) then
            if campingSpot then
                if bot:GetPos():DistToSqr(campingSpot) <= SURVIVOR_ANCHOR_REACHED_DIST_SQR then
                    return nil
                end

                return campingSpot
            end
        else
            local survivorPos = GetRandomAliveSurvivorPos(bot)

            if survivorPos then
                return survivorPos
            end
        end
    elseif strategy == 2 then
        if ZSB.Util:Odds(70) then
            local survivorPos = GetRandomAliveSurvivorPos(bot)

            if survivorPos then
                return survivorPos
            end
        else
            return GetRandomRoamPos(controller)
        end
    elseif strategy == 3 then
        local zombiePos = GetDistributedZombiePressurePos(bot, now)

        if zombiePos then
            return zombiePos
        end
    end

    -- Fallback
    return GetRandomRoamPos(controller)
end

local function MoveSurvivorToSigil(bot, controller, strategy)
    if bot:Team() ~= TEAM_SURVIVORS then
        return nil
    end

    local now = CurTime()
    local targetPos = ResolveSurvivorTargetPos(bot, controller, strategy, now)

    controller.PosGen = targetPos
    return
end

local function MoveZombieToSurvivor(bot, controller, now)
    if bot:Team() ~= TEAM_ZOMBIE then return end

    for _, candidate in RandomPairs(player.GetAll()) do
        if IsValid(candidate)
        and candidate:Team() == TEAM_SURVIVORS
        and candidate:Alive()
        and not candidate:HasGodMode()
        then
            controller.PosGen = candidate:GetPos()
            break
        end
    end
end

local function MoveZombieToRandomSpot(controller, now)
    controller.PosGen = controller:FindSpot("random", LARGE_RANDOM_SPOT_OPTIONS)
end

function SC.MoveWithoutTarget(bot, controller, strategy)
    if controller.PosGen then return end

    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        MoveSurvivorToSigil(bot, controller, strategy)
    end

    if teamId == TEAM_ZOMBIE then
        local now = CurTime()

        if math.random(1, 100) <= 40 then
            if TrySetZombieExplorationGoal(bot, controller) then
                return
            end
        end

        if team.NumPlayers(TEAM_SURVIVORS) > 0 then
            MoveZombieToSurvivor(bot, controller, now)
        else
            MoveZombieToRandomSpot(controller, now)
        end
    end
end
