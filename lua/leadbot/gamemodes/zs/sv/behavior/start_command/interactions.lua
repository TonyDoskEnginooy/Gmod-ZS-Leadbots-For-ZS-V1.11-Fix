ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local STUCK_JUMP_MIN = 0.35
local STUCK_JUMP_MAX = 0.85
local RANDOM_JUMP_MIN = 1.8
local RANDOM_JUMP_MAX = 10

function SC.BreakRotatingDoor(bot, doors)
    if not SC.HasEntries(doors) then return end

    local door = doors[math.random(1, #doors)]
    if IsValid(door) and door:GetClass() == "prop_door_rotating" then
        door:Fire("Break", "", 0, bot, bot)
    end
end

function SC.ToggleMovingBrush(bot, movingBrushes)
    if not SC.HasEntries(movingBrushes) then return end

    local movingBrush = movingBrushes[math.random(1, #movingBrushes)]
    if not IsValid(movingBrush) then return end

    if movingBrush:GetName() ~= "BunkerDoor" then
        movingBrush:Fire("Open", bot, 0)
    else
        movingBrush:Fire("Close", bot, 0)
    end
end

function SC.BreakBreakableSurface(surfaces)
    if not SC.HasEntries(surfaces) then return end

    local surface = surfaces[math.random(1, #surfaces)]
    if IsValid(surface) then
        surface:Fire("Break")
    end
end

local function AreaHasAttribute(area, attribute)
    return area ~= nil and area:IsValid() and area:HasAttributes(attribute)
end

function SC.HandleJump(bot, controller, currentGoal, now)
    local isJumpArea = AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)

    if not (controller.NextJump ~= 0 or controller.NextRandomJump < now)
        or AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP)
        or not bot:IsOnGround()
        or bot:IsFrozen()
        or bot:Crouching()
    then
        return
    end

    local speed2DSqr = bot:GetVelocity():Length2DSqr()
    local hasTarget = IsValid(controller.Target)

    if controller.NextJump ~= 0 then
        if AreaHasAttribute(currentGoal.area, NAV_MESH_JUMP) then
            return
        end

        if controller.NextJump < now then
            local isJumpGoal = currentGoal.type > 1 or isJumpArea
            if isJumpGoal then
                controller.NextJump = 0
            end
        end
    end

    if controller.NextRandomJump < now then
        controller.NextRandomJump = now + math.Rand(RANDOM_JUMP_MIN, RANDOM_JUMP_MAX)

        if speed2DSqr >= 140 * 140 then
            local jumpChance = hasTarget and 24 or 10

            if math.random(1, 100) <= jumpChance then
                controller.NextJump = 0
                controller.NextStrafe = 0
            end
        end
    end
end

function SC.HandleCrouch(bot, controller, currentGoal, now)
    local crouchTrace = util.QuickTrace(
        bot:EyePos(),
        bot:GetForward() * 90 - (bot:GetViewOffsetDucked() * 3),
        bot
    )

    if AreaHasAttribute(currentGoal.area, NAV_MESH_CROUCH)
        or IsValid(crouchTrace.Entity)
    then
        controller.NextDuck = now + 0.1
    end
end