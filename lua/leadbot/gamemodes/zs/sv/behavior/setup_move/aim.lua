ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local leadbot_skill = GetConVar("leadbot_skill")

local CAMPING_LOOK_DISTANCE = 1200
local CAMPING_LOOK_DISTANCE_SQR = CAMPING_LOOK_DISTANCE * CAMPING_LOOK_DISTANCE

local cachedCampingSpotList
local cachedCampingEyeAngles
local cachedAimSkill = {}
local cachedChosenEyeAnges = {}
local hasValidCampingData = true

local function RefreshCampingCache()
    if cachedCampingSpotList then return end

    cachedCampingSpotList = ZSB.Map:GetValue("campingSpotList")
    cachedCampingEyeAngles = ZSB.Map:GetValue("eyeAngles")

    if not istable(cachedCampingSpotList) or not isfunction(cachedCampingEyeAngles) then
        hasValidCampingData = false
    end
end

local function GetCampingLookAngles(bot, strategy, now)
    if bot:Team() ~= TEAM_SURVIVORS then return nil end
    if strategy < 1 or strategy > 3 then return nil end

    RefreshCampingCache()

    if not hasValidCampingData then
        return nil
    end

    local position = bot:GetPos()
    local campingSpot = cachedCampingSpotList[strategy]

    if not campingSpot then
        return nil
    end

    if not cachedChosenEyeAnges.next or cachedChosenEyeAnges.next < now then
        cachedChosenEyeAnges = {}
        cachedChosenEyeAnges.next = now + 15
    end

    if cachedChosenEyeAnges[bot] then
        return cachedChosenEyeAnges[bot]
    end

    if position:DistToSqr(campingSpot) <= CAMPING_LOOK_DISTANCE_SQR then
        cachedChosenEyeAnges[bot] = cachedCampingEyeAngles(
            strategy,
            math.random(-15, 15),
            math.random(-45, 45),
            math.random(-90, 90)
        )

        return cachedChosenEyeAnges[bot]
    end
end

local function GetAimSkill(bot, team, now)
    if not cachedAimSkill.next or cachedAimSkill.next < now then
        cachedAimSkill = {}
        cachedAimSkill.next = now + 300
    end

    if cachedAimSkill[bot] then
        return cachedAimSkill[bot]
    end

    local shootSkill = bot:LBGetshootSkill()
    local skillMode = leadbot_skill:GetInt()

    local aimSkill

    if skillMode == 0 then
        aimSkill = 2
    elseif skillMode == 1 then
        aimSkill = 4.5
    elseif skillMode == 2 then
        aimSkill = 7
    elseif skillMode == 4 then
        aimSkill = shootSkill
    else
        aimSkill = 4.5
    end

    if team == TEAM_SURVIVORS then
        aimSkill = aimSkill + math.Clamp(math.floor(shootSkill * 0.15), 0, 3)

        if bot:LBGetsurvSkill() == 1 then
            aimSkill = aimSkill + 2
        end
    end

    cachedAimSkill[bot] = aimSkill

    return aimSkill
end

local function GetAimLerp(bot, controller, strategy, hasTarget, frameTime, now)
    local team = bot:Team()
    local aimSkill = GetAimSkill(bot, team, now)
    local multiplier

    if team == TEAM_SURVIVORS then
        
        if hasTarget and strategy > 0 then
            multiplier = 0.75
        else
            if bot.freeRoam then
                multiplier = 0.55
            else
                multiplier = 0.65
            end
        end
    else
        multiplier = 0.6
    end

    return frameTime * (aimSkill * multiplier)
end

function SM.SetEyeAngles(bot, controller, currentGoal, moveAngles, strategy)
    local isFrozen = bot:IsFrozen()

    if isFrozen then return end

    local now = CurTime()
    local eyeAngles = bot:EyeAngles()
    local shootPos = bot:GetShootPos()
    local hasTarget = IsValid(controller.Target)
    local frameTime = FrameTime()
    local lerpValue = GetAimLerp(bot, controller, strategy, frameTime, frameTime, now)

    if hasTarget then
        if controller.NextAimPoint < now then
            local aimPoint = ZSB.Util:GetCombatAimPoint(bot, controller.Target)
            controller.AimPoint = aimPoint
            controller.NextAimPoint = now + 0.1
        end

        if controller.AimPoint then
            if bot:Team() == TEAM_SURVIVORS then
                local recentThreatActive = controller.RecentCloseThreat == controller.Target
                    and (controller.RecentCloseThreatUntil or 0) > now

                if recentThreatActive then
                    local aimSkill = GetAimSkill(bot, team, now)
                    lerpValue = frameTime * (aimSkill * 0.8)
                end
            end

            bot:SetEyeAngles(LerpAngle(lerpValue, eyeAngles, (controller.AimPoint - shootPos):Angle()))
        end

        return
    end

    if currentGoal and moveAngles then
        if controller.LookAt.x == eyeAngles.x and controller.LookAt.y == eyeAngles.y then
            return
        end

        local lookAng
        if controller.LookAtTime > now and controller.LookAt then
            lookAng = controller.LookAt
        else
            lookAng = moveAngles
        end

        local angs = LerpAngle(lerpValue, eyeAngles, lookAng)
        bot:SetEyeAngles(Angle(angs.p, angs.y, 0))

        return
    end

    local campingAngles = GetCampingLookAngles(bot, strategy, now)
    if campingAngles then
        if eyeAngles == campingAngles then
            return
        end

        local angs = LerpAngle(lerpValue, eyeAngles, campingAngles)
        bot:SetEyeAngles(angs)
    end
end