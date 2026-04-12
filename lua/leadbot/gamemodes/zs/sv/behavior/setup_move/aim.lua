ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

if SM._AimLoaded then
    return
end

SM._AimLoaded = true

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
    local aimSkill

    if leadbot_skill:GetInt() == 0 then
        aimSkill = 4
    elseif leadbot_skill:GetInt() == 1 then
        aimSkill = 8
    elseif leadbot_skill:GetInt() == 2 then
        aimSkill = 12
    elseif leadbot_skill:GetInt() == 4 then
        aimSkill = bot:LBGetShootSkill()
    else
        aimSkill = 16
    end

    if bot:Team() == TEAM_SURVIVORS then
        aimSkill = aimSkill + math.Clamp(math.floor(bot:LBGetShootSkill() * 0.15), 0, 3)

        if bot:LBGetSurvSkill() == 1 then
            aimSkill = aimSkill + 4
        end
    end

    if bot:Team() == TEAM_SURVIVORS and IsValid(controller.Target) then
        if strategy > 0 and not bot.freeRoam then
            return FrameTime() * (aimSkill / 2), FrameTime() * (aimSkill / 2)
        end

        return FrameTime() * aimSkill, FrameTime() * aimSkill
    end

    return FrameTime() * (aimSkill / 4), FrameTime() * (aimSkill / 4)
end

function SM.SetEyeAngles(bot, controller, currentGoal, moveAngles, lerp, lerpLook)
    if IsValid(controller.Target) then
        local aimPoint = ZSB.Util:GetCombatAimPoint(bot, controller.Target)

        if aimPoint and not bot:IsFrozen() then
            local targetLerp = lerp

            if bot:Team() == TEAM_SURVIVORS then
                local distanceSqr = bot:GetShootPos():DistToSqr(aimPoint)

                if distanceSqr <= 110 * 110 then
                    targetLerp = math.max(targetLerp, FrameTime() * 30)
                elseif distanceSqr <= 220 * 220 then
                    targetLerp = math.max(targetLerp, FrameTime() * 22)
                end
            end

            bot:SetEyeAngles(LerpAngle(targetLerp, bot:EyeAngles(), (aimPoint - bot:GetShootPos()):Angle()))
        end

        return
    end

    if currentGoal and moveAngles then
        if controller.LookAtTime > CurTime() and controller.LookAt then
            local lookAngles = LerpAngle(lerpLook, bot:EyeAngles(), controller.LookAt)
            if not bot:IsFrozen() then
                bot:SetEyeAngles(Angle(lookAngles.p, lookAngles.y, 0))
            end
        else
            local goalAngles = LerpAngle(lerpLook, bot:EyeAngles(), moveAngles)
            if not bot:IsFrozen() then
                bot:SetEyeAngles(Angle(goalAngles.p, goalAngles.y, 0))
            end
        end

        return
    end

    local campingAngles = GetCampingLookAngles(bot, controller.strategy)
    if campingAngles and not bot:IsFrozen() then
        bot:SetEyeAngles(campingAngles)
    end
end
