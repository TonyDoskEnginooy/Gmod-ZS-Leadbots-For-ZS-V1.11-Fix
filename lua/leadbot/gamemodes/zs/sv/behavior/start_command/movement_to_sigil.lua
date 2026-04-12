ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local SURVIVOR_ANCHOR_REACHED_DIST_SQR = 2500

local function GetSurvivorCampingSpot(strategy)
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")
    if not istable(campingSpotList) then return nil end

    return campingSpotList[strategy]
end

local function GetSurvivorFallbackPos(bot, controller, strategy)
    if strategy == 2 then
        for _, candidate in RandomPairs(player.GetAll()) do
            if IsValid(candidate) and candidate ~= bot and candidate:Team() == TEAM_SURVIVORS and candidate:Alive() then
                return candidate:GetPos(), CurTime() + 10
            end
        end
    end

    if strategy == 3 then
        for _, candidate in RandomPairs(player.GetAll()) do
            if IsValid(candidate) and candidate:Team() == TEAM_ZOMBIE and candidate:Alive() and not candidate:HasGodMode() then
                return candidate:GetPos(), CurTime() + 10
            end
        end
    end

    return controller:FindSpot("random", { radius = 1000000 }), CurTime() + 5
end

function SC.MoveToSigil(bot, controller, strategy)
    if not bot:Team() == TEAM_SURVIVORS then return end

    if bot.freeRoam or strategy == 0 then
        if strategy <= 2 then
            controller.PosGen = controller:FindSpot("random", { radius = 1000000 })
            controller.LastSegmented = CurTime() + 1000000
        elseif team.NumPlayers(TEAM_ZOMBIE) > 0 then
            for _, candidate in RandomPairs(player.GetAll()) do
                if IsValid(candidate) and candidate:Team() == TEAM_ZOMBIE and not candidate:HasGodMode() and candidate:Alive() then
                    controller.PosGen = candidate:GetPos()
                    controller.LastSegmented = CurTime() + 10
                    break
                end
            end
        else
            controller.PosGen = controller:FindSpot("random", { radius = 1000000 })
            controller.LastSegmented = CurTime() + 1000000
        end

        return
    end

    if strategy >= 1 and strategy <= 3 then
        local campingSpot = GetSurvivorCampingSpot(strategy)

        if campingSpot then
            local distance = bot:GetPos():DistToSqr(campingSpot)

            if distance <= SURVIVOR_ANCHOR_REACHED_DIST_SQR then
                controller.PosGen = nil
                controller.LastSegmented = CurTime() + 1
            else
                print(strategy, campingSpot)
                controller.PosGen = campingSpot
                controller.LastSegmented = CurTime() + 1
            end

            return
        end

        local fallbackPos, fallbackSegmentTime = GetSurvivorFallbackPos(bot, controller, strategy)
        controller.PosGen = fallbackPos
        controller.LastSegmented = fallbackSegmentTime
        return
    end
end