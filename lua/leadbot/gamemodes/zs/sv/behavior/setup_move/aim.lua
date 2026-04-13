ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

local leadbot_skill = GetConVar("leadbot_skill")

local function GetCampingLookAngles(bot, strategy)
    if bot:Team() ~= TEAM_SURVIVORS then return nil end
    if strategy < 1 or strategy > 3 then return nil end

    local campingSpotList = ZSB.Map:GetValue("campingSpotList")
    local eyeAngles = ZSB.Map:GetValue("eyeAngles")
    local position = bot:GetPos()

    if not istable(campingSpotList) or not isfunction(eyeAngles) then
        return nil
    end

    local campingSpot = campingSpotList[strategy]
    if not campingSpot then
        return nil
    end

    if position:DistToSqr(campingSpot) <= 5000 then
        return eyeAngles(
            strategy,
            math.random(-15, 15),
            math.random(-45, 45),
            math.random(-90, 90)
        )
    end

    return nil
end

function SM.GetAimLerp(bot, controller, strategy)
    local conVarSkill = leadbot_skill:GetInt()
    local aimSkill

    if conVarSkill == 0 then
        aimSkill = 4
    elseif conVarSkill == 1 then
        aimSkill = 8
    elseif conVarSkill == 2 then
        aimSkill = 12
    elseif conVarSkill == 4 then
        aimSkill = bot:LBGetshootSkill()
    else
        aimSkill = 16
    end

    if bot:Team() == TEAM_SURVIVORS then
        aimSkill = aimSkill + math.Clamp(math.floor(bot:LBGetshootSkill() * 0.15), 0, 3)

        if bot:LBGetsurvSkill() == 1 then
            aimSkill = aimSkill + 4
        end
    end

    local frameTime = FrameTime()

    if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
        if strategy > 0 and not bot.freeRoam then
            return frameTime * (aimSkill / 2), frameTime * (aimSkill / 2)
        end

        return frameTime * aimSkill, frameTime * aimSkill
    end

    return frameTime * (aimSkill / 4), frameTime * (aimSkill / 4)
end

function SM.SetEyeAngles(bot, controller, currentGoal, moveAngles, strategy)
    local now = CurTime()
    local isFrozen = bot:IsFrozen()
    local eyeAngles = bot:EyeAngles()
    local shootPos = bot:GetShootPos()
    local lerp, lerpLook = SM.GetAimLerp(bot, controller, strategy)

    if IsValid(controller.Target) then
        local aimPoint = ZSB.Util:GetCombatAimPoint(bot, controller.Target)

        if aimPoint and not isFrozen then
            local targetLerp = lerp

            if bot:Team() == TEAM_SURVIVORS then
                local distanceSqr = shootPos:DistToSqr(aimPoint)
                local recentThreatActive = controller.RecentCloseThreat == controller.Target
                    and (controller.RecentCloseThreatUntil or 0) > now

                if recentThreatActive then
                    targetLerp = math.max(targetLerp, FrameTime() * 34)
                elseif distanceSqr <= 90 * 90 then
                    targetLerp = math.max(targetLerp, FrameTime() * 26)
                elseif distanceSqr <= 180 * 180 then
                    targetLerp = math.max(targetLerp, FrameTime() * 20)
                elseif distanceSqr <= 260 * 260 then
                    targetLerp = math.max(targetLerp, FrameTime() * 16)
                end
            end

            bot:SetEyeAngles(LerpAngle(targetLerp, eyeAngles, (aimPoint - shootPos):Angle()))
        end

        return
    end

    if currentGoal and moveAngles then
        if controller.LookAtTime > now and controller.LookAt then
            local lookAngles = LerpAngle(lerpLook, eyeAngles, controller.LookAt)
            if not isFrozen then
                bot:SetEyeAngles(Angle(lookAngles.p, lookAngles.y, 0))
            end
        else
            local goalAngles = LerpAngle(lerpLook, eyeAngles, moveAngles)
            if not isFrozen then
                bot:SetEyeAngles(Angle(goalAngles.p, goalAngles.y, 0))
            end
        end

        return
    end

    local campingAngles = GetCampingLookAngles(bot, strategy)
    if campingAngles and not isFrozen then
        bot:SetEyeAngles(campingAngles)
    end
end