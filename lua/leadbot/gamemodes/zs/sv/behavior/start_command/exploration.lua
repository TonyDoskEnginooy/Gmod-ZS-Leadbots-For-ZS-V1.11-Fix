ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local LARGE_RANDOM_SPOT_OPTIONS = { radius = 5000 }

local SURVIVOR_ANCHOR_REACHED_DIST_SQR = 2500
local SURVIVOR_SIGIL_GROUP_RADIUS_SQR = 300 * 300
local SURVIVOR_SIGIL_STRATEGY_BIAS = 150 * 150
local SURVIVOR_DANGER_MEDIUM_ZOMBIE_RATIO = 2 / 12
local SURVIVOR_DANGER_FALLBACK_ZOMBIE_RATIO = 3 / 12

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

function SC.GetSurvivorDangerStage()
    local survivorCount = team.NumPlayers(TEAM_SURVIVORS)
    local zombieCount = team.NumPlayers(TEAM_ZOMBIE)
    local totalPlayers = survivorCount + zombieCount

    if totalPlayers <= 0 then
        return 0, zombieCount, survivorCount
    end

    local zombieRatio = zombieCount / totalPlayers

    if zombieRatio >= SURVIVOR_DANGER_FALLBACK_ZOMBIE_RATIO then
        return 2, zombieCount, survivorCount
    end

    if zombieRatio >= SURVIVOR_DANGER_MEDIUM_ZOMBIE_RATIO then
        return 1, zombieCount, survivorCount
    end

    return 0, zombieCount, survivorCount
end

local function HasSigilSpots()
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")

    return istable(campingSpotList) and #campingSpotList > 0
end

function SC.ShouldFallbackToSigil(bot)
    if not IsValid(bot) or bot:Team() ~= TEAM_SURVIVORS or not HasSigilSpots() then
        return false
    end

    local dangerStage = SC.GetSurvivorDangerStage()

    return dangerStage >= 2
end

local function ClearSigilFallback(controller)
    if not IsValid(controller) then
        return
    end

    controller.SigilFallbackActive = false
    controller.SigilFallbackPos = nil
end

local function CountNearbyAliveSurvivors(bot, targetPos)
    local nearbyCount = 0

    for _, candidate in ipairs(player.GetAll()) do
        if IsValid(candidate)
        and candidate:Alive()
        and candidate:Team() == TEAM_SURVIVORS
        and candidate:GetPos():DistToSqr(targetPos) <= SURVIVOR_SIGIL_GROUP_RADIUS_SQR
        then
            nearbyCount = nearbyCount + 1
        end
    end

    return nearbyCount
end

function SC.SetRoamState(bot)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    if bot.freeRoam == nil then
        bot.freeRoam = true
    end

    local dangerStage, zombieCount, survivorCount = SC.GetSurvivorDangerStage()

    if dangerStage >= 1 then
        bot.freeRoam = false
        return
    end

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

    if ZSB.Util.IsSimpleObstacleTarget(bot, ent) then
        return true
    end

    return className == "prop_door_rotating" or className == "func_movelinear"
end

function SC.GetRandomRoamPos(controller)
    return controller:FindSpot("random", { radius = 5000 })
end

local function TrySetZombieExplorationGoal(bot, controller)
    local foundEnts = ZSB.Util:FindEnts(bot)
    if not foundEnts then
        return false
    end

    if math.random(1, 100) <= 60 then
        controller.PosGen = SC.GetRandomRoamPos(controller)
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
    local timeBucket = math.floor(now * 0.65)
    local index =  math.floor(((seed + timeBucket) % #zombieList) + 1)
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

        return SC.GetRandomRoamPos(controller)
    end

    -- Home
    if strategy >= 1 and strategy <= 3 and ZSB.Util:Odds(12) then
        local campingSpot = GetSurvivorCampingSpot(strategy)

        if campingSpot then
            if bot:GetPos():DistToSqr(campingSpot) <= SURVIVOR_ANCHOR_REACHED_DIST_SQR then
                return nil
            end

            return campingSpot
        end
    end

    -- Prefer exploration
    if strategy == 1 then
        if ZSB.Util:Odds(70) then
            return SC.GetRandomRoamPos(controller)
        else
            local survivorPos = GetRandomAliveSurvivorPos(bot)

            if survivorPos then
                return survivorPos
            end
        end
    -- Prefer support
    elseif strategy == 2 then
        if ZSB.Util:Odds(70) then
            local survivorPos = GetRandomAliveSurvivorPos(bot)

            if survivorPos then
                return survivorPos
            end
        else
            local zombiePos = GetDistributedZombiePressurePos(bot, now)

            if zombiePos then
                return zombiePos
            end
        end
    -- Prefer attacking
    elseif strategy == 3 then
        if ZSB.Util:Odds(70) then
            local zombiePos = GetDistributedZombiePressurePos(bot, now)

            if zombiePos then
                return zombiePos
            end
        else
            return SC.GetRandomRoamPos(controller)
        end
    end

    -- Fallback
    return SC.GetRandomRoamPos(controller)
end

local function GetDangerSigilPos(bot, strategy)
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")

    if not istable(campingSpotList) or #campingSpotList <= 0 then
        return nil
    end

    local bestPos
    local bestScore = math.huge
    local strategyIndex = strategy >= 1 and strategy <= #campingSpotList and strategy or nil

    for index, candidatePos in ipairs(campingSpotList) do
        if isvector(candidatePos) then
            local score = bot:GetPos():DistToSqr(candidatePos)
            local nearbySurvivors = CountNearbyAliveSurvivors(bot, candidatePos)

            score = score + nearbySurvivors * SURVIVOR_SIGIL_GROUP_RADIUS_SQR
            -- I'm adding the survivals to the weight because I want people spliting between the sigils

            if strategyIndex == index then
                score = score - SURVIVOR_SIGIL_STRATEGY_BIAS
            end

            if score < bestScore then
                bestScore = score
                bestPos = candidatePos
            end
        end
    end

    return bestPos
end

function SC.MoveSurvivorToSigil(bot, controller, strategy, now)
    if controller.NextMoveSurvivorToSigil > now then return controller.PosGen end

    controller.NextMoveSurvivorToSigil = now + 0.33

    if bot:Team() ~= TEAM_SURVIVORS then
        return nil
    end

    if SC.ShouldFallbackToSigil(bot) then
        local sigilPos = GetDangerSigilPos(bot, strategy)
        if isvector(sigilPos) then
            controller.PosGen = sigilPos
            controller.SigilFallbackActive = true
            controller.SigilFallbackPos = sigilPos
            return sigilPos
        end
    end

    ClearSigilFallback(controller)

    local now = CurTime()
    local targetPos = ResolveSurvivorTargetPos(bot, controller, strategy, now)

    controller.PosGen = targetPos
    return targetPos
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
    local now = CurTime()

    if teamId == TEAM_SURVIVORS then
        SC.MoveSurvivorToSigil(bot, controller, strategy, now)
    end

    if teamId == TEAM_ZOMBIE then
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
