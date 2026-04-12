ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local SURVIVOR_ANCHOR_REACHED_DIST_SQR = 2500
local FREE_ROAM_RANDOM_MIN = 2.4
local FREE_ROAM_RANDOM_MAX = 4.8
local FREE_ROAM_PRESSURE_MIN = 1.6
local FREE_ROAM_PRESSURE_MAX = 2.8

local function GetSurvivorCampingSpot(strategy)
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")
    if not istable(campingSpotList) then return nil end

    return campingSpotList[strategy]
end

local function SetTimedGoal(controller, pos, minDelay, maxDelay, now)
    if not isvector(pos) then
        return false
    end

    controller.PosGen = pos
    controller.LastSegmented = (now or CurTime()) + math.Rand(minDelay, maxDelay)
    return true
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

    local seed = bot.LeadBot_PersonalitySeed or bot:EntIndex() or 1
    local timeBucket = math.floor((now or CurTime()) * 0.65)
    local index = ((seed + timeBucket) % #zombieList) + 1
    local target = zombieList[index]

    if not IsValid(target) then
        return nil
    end

    return target:GetPos()
end

local function GetSurvivorFallbackPos(bot, controller, strategy, now)
    if strategy == 2 then
        for _, candidate in RandomPairs(player.GetAll()) do
            if IsValid(candidate) and candidate ~= bot and candidate:Team() == TEAM_SURVIVORS and candidate:Alive() then
                return candidate:GetPos(), now + 10
            end
        end
    end

    if strategy == 3 then
        local zombiePos = GetDistributedZombiePressurePos(bot, now)

        if zombiePos then
            return zombiePos, now + math.Rand(FREE_ROAM_PRESSURE_MIN, FREE_ROAM_PRESSURE_MAX)
        end
    end

    return controller:FindSpot("random", { radius = 1000000 }), now + math.Rand(FREE_ROAM_RANDOM_MIN, FREE_ROAM_RANDOM_MAX)
end

function SC.MoveToSigil(bot, controller, strategy)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    local now = CurTime()

    if bot.freeRoam or strategy == 0 then
        local pressurePos = GetDistributedZombiePressurePos(bot, now)

        if pressurePos and (strategy == 3 or ZSB.Util:Odds(65)) then
            SetTimedGoal(controller, pressurePos, FREE_ROAM_PRESSURE_MIN, FREE_ROAM_PRESSURE_MAX, now)
            return
        end

        local randomPos = controller:FindSpot("random", { radius = 1000000 })
        SetTimedGoal(controller, randomPos, FREE_ROAM_RANDOM_MIN, FREE_ROAM_RANDOM_MAX, now)
        return
    end

    if strategy >= 1 and strategy <= 3 then
        local campingSpot = GetSurvivorCampingSpot(strategy)

        if campingSpot then
            local distance = bot:GetPos():DistToSqr(campingSpot)

            if distance <= SURVIVOR_ANCHOR_REACHED_DIST_SQR then
                controller.PosGen = nil
                controller.LastSegmented = now + 1
            else
                controller.PosGen = campingSpot
                controller.LastSegmented = now + 1
            end

            return
        end

        local fallbackPos, fallbackSegmentTime = GetSurvivorFallbackPos(bot, controller, strategy, now)
        controller.PosGen = fallbackPos
        controller.LastSegmented = fallbackSegmentTime
        return
    end
end
