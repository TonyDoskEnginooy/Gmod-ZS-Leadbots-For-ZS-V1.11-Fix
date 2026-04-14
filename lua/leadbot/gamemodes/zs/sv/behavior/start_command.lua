local leadbot_zcheats = GetConVar("leadbot_zcheats")

local function includeSCModule(fileName)
    include("start_command/" .. fileName)
end

includeSCModule("attack.lua")
includeSCModule("buttons.lua")
includeSCModule("interactions.lua")
includeSCModule("exploration.lua")
includeSCModule("shared.lua")
includeSCModule("survivor_destruction.lua")
includeSCModule("survivor_weapon.lua")
includeSCModule("target.lua")
includeSCModule("zombie_destruction.lua")
includeSCModule("zombie_prop_throw.lua")

ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local function ApplyZombieCheats(bot)
    if bot:Team() ~= TEAM_ZOMBIE or not leadbot_zcheats:GetBool() then return end

    local zombieClass = bot:GetZombieClass()

    if zombieClass == 8 then
        bot:Freeze(false)
    end

    if (zombieClass == 3 or zombieClass == 5) and ZombieClasses and ZombieClasses[zombieClass] then
        GAMEMODE:SetPlayerSpeed(bot, ZombieClasses[zombieClass].Speed)
    end
end

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    local now = CurTime()
    local teamId = bot:Team()

    if controller.Path then
        local segments = controller.Path:GetAllSegments()
        
        if segments then
            local currentGoal = controller.PosGen and segments[controller.CurSegmentIndex] or nil

            if currentGoal then
                SC.HandleJump(bot, controller, currentGoal, now)
                SC.HandleCrouch(bot, controller, currentGoal, now)
            end
        end
    end

    SC.ForgetInvalidTarget(bot, controller)

    local foundEnts = ZSB.Util:FindEnts(bot)

    SC.ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])
    --SC.BreakBreakableSurface(foundEnts.near["func_breakable_surf"])

    if teamId == TEAM_SURVIVORS then
        SC.SetRoamState(bot)

        if not IsValid(controller.Target) or controller.ForgetTarget < now then
            if math.random(1, 100) <= 85 then
                SC.AcquireTemperamentTarget(bot, controller, foundEnts, now)
            else
                SC.AcquireSurvivorBreakTarget(bot, controller, foundEnts)
            end
        end

        if IsValid(controller.Target) then
            local botPos = bot:GetPos()
            local targetPos = controller.Target:GetPos()
            local distanceSqr = targetPos:DistToSqr(botPos)

            SC.SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts, now)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy(), foundEnts)
        end
    elseif teamId == TEAM_ZOMBIE then
        ApplyZombieCheats(bot)
        SC.BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])

        if not IsValid(controller.Target) or controller.ForgetTarget < now  then
            if math.random(1, 100) <= 60 then
                SC.AcquireTemperamentTarget(bot, controller, foundEnts, now)
            else
                SC.AcquireZombieBreakTarget(bot, controller, foundEnts)
            end
        end

        if IsValid(controller.Target) then
            SC.TryThrowNearbyProp(bot, controller, foundEnts)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy(), foundEnts)
        end
    end

    local buttons = SC.BuildActionButtons(bot, controller)

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end
