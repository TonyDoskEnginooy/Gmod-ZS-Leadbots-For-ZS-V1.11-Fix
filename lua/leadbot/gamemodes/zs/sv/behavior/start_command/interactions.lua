ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local RANDOM_JUMP_MIN = 1
local RANDOM_JUMP_MAX = 2
local BOT_DUCK_DELAY = 0.25

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
        local jumpChance = controller.Target and 38 or 25
        
        if math.random(1, 100) <= jumpChance then
            controller.NextJump = 0
            controller.NextRandomJump = now + math.Rand(RANDOM_JUMP_MIN, RANDOM_JUMP_MAX)
        end
    end
end

function SC.HandleCrouch(bot, controller, currentGoal, now)
    if controller.NextDuck >= now then return end
    if controller.NextDuckCheck >= now then return end
    
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