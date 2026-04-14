ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local RANDOM_JUMP_MIN = 1
local RANDOM_JUMP_MAX = 2
local BOT_DUCK_DELAY = 0.25
local BOT_DUCK_AIM_DELAY_MIN = 1.5
local BOT_DUCK_AIM_DELAY_MAX = 8
local SURVIVOR_CROUCH_RECENT_THREAT_DISTANCE_SQR = 185 * 185
local SURVIVOR_CROUCH_PRESSURE_DISTANCE_SQR = 280 * 280

function SC.BreakRotatingDoor(bot, doors)
    if not ZSB.Util.HasEntries(doors) then return end

    local door = doors[math.random(1, #doors)]
    if IsValid(door) and door:GetClass() == "prop_door_rotating" then
        door:Fire("Break", "", 0, bot, bot)
    end
end

function SC.ToggleMovingBrush(bot, movingBrushes)
    if not ZSB.Util.HasEntries(movingBrushes) then return end

    local movingBrush = movingBrushes[math.random(1, #movingBrushes)]
    if not IsValid(movingBrush) then return end

    if movingBrush:GetName() ~= "BunkerDoor" then
        movingBrush:Fire("Open", bot, 0)
    else
        movingBrush:Fire("Close", bot, 0)
    end
end

function SC.BreakBreakableSurface(surfaces)
    if not ZSB.Util.HasEntries(surfaces) then return end

    local surface = surfaces[math.random(1, #surfaces)]
    if IsValid(surface) then
        surface:Fire("Break")
    end
end

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

local function ShouldUseCombatCrouch(bot, controller)
    if bot:Team() ~= TEAM_SURVIVORS
        or bot:IsFrozen()
        or not bot:IsOnGround()
        or not ZSB.Util.IsValidEnemyZombie(bot, controller.Target)
        or ZSB.Util.IsActiveSurvivorMelee(bot)
        or not ZSB.Util:GetSurvivorCrouchWeaponData(bot:GetActiveWeapon())
    then
        return false
    end

    local distanceSqr = bot:GetPos():DistToSqr(controller.Target:GetPos())
    local crouchRange = ZSB.Util:GetSurvivorCrouchRangeBand(distanceSqr)

    if not crouchRange then
        return false
    end

    if SC.GetRecentCloseThreat(controller) == controller.Target
        and distanceSqr <= SURVIVOR_CROUCH_RECENT_THREAT_DISTANCE_SQR
    then
        return false
    end

    if (controller.RetreatTotalThreats or 0) >= 4
        and distanceSqr <= SURVIVOR_CROUCH_PRESSURE_DISTANCE_SQR
    then
        return false
    end

    return true
end

local slowSqr = 20 * 20
function SC.HandleJump(bot, controller, currentGoal, now)
    local isJumpArea = AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)

    if controller.NextJump == 0
        or controller.NextRandomJump > now
        or controller.NextJump > now
        or isJumpArea
        or not bot:IsOnGround()
        or bot:IsFrozen()
    then
        return
    end

    local isPanicing = SC.GetRecentCloseThreat(controller) and true or false
    local speed2DSqr = bot:GetVelocity():Length2DSqr()

    if isPanicing then
        controller.NextJump = 0
    end

    if speed2DSqr <= slowSqr then
        local jumpChance = 0
        
        if controller.Target then
            if controller.RetreatTotalThreats == 0 then
                jumpChance = 10
            elseif controller.RetreatTotalThreats <= 3 then
                jumpChance = 15
            elseif controller.RetreatTotalThreats <= 6 then
                jumpChance = 30
            elseif controller.RetreatTotalThreats <= 9 then
                jumpChance = 60
            else
                jumpChance = 85
            end
        else
            jumpChance = 6
        end

        if math.random(1, 100) <= jumpChance then
            controller.NextJump = 0
            controller.NextRandomJump = now + math.Rand(RANDOM_JUMP_MIN, RANDOM_JUMP_MAX)
        end
    end
end

function SC.HandleCrouch(bot, controller, currentGoal, now)
    if controller.NextDuck >= now then
        if controller.RetreatTotalThreats > 3 or SC.GetRecentCloseThreat() then
            controller.NextJump = 0
            controller.NextDuckCheck = 0
        end

        return
    end

    if controller.NextDuckCheck >= now then return end

    if ShouldUseCombatCrouch(bot, controller) and math.random(1, 100) <= 35 then
        local delay = math.Rand(BOT_DUCK_AIM_DELAY_MIN, BOT_DUCK_AIM_DELAY_MAX)
        controller.NextDuck = now + delay
        controller.NextDuckCheck = now + delay
        return
    end

    controller.NextDuckCheck = now + BOT_DUCK_DELAY

    if AreaHasAttribute(currentGoal.area, NAV_MESH_CROUCH) then
        return
    end

    local crouchTrace = util.QuickTrace(
        bot:EyePos(),
        bot:GetForward() * 90 - (bot:GetViewOffsetDucked() * 3),
        bot
    )

    if IsValid(crouchTrace.Entity) then
        controller.NextDuck = now + BOT_DUCK_DELAY
        return
    end
end
