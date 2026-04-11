local function includeStartCommandModule(fileName)
    include("start_command/" .. fileName)
end

includeStartCommandModule("shared.lua")
includeStartCommandModule("zombie_targeting.lua")
includeStartCommandModule("zombie_prop_throw.lua")
includeStartCommandModule("map_interactions.lua")
includeStartCommandModule("movement_without_target.lua")
includeStartCommandModule("combat_buttons.lua")
includeStartCommandModule("survival_weapon_selection.lua")

local SC = ZSB.StartCommand

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    SC.EnsureControllerState(controller)

    SC.KillLonelyHordeBot(bot)
    SC.SetRoamState(bot)
    SC.ApplyZombieCheats(bot)

    SC.ForgetInvalidTarget(controller)

    local foundEnts = ZSB.Util:FindEnts(bot)
    SC.AcquireTemperamentTarget(bot, controller, foundEnts)

    SC.BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])
    SC.BreakBreakableSurface(foundEnts.near["func_breakable_surf"])
    SC.ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if IsValid(controller.Target) then
        local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

        SC.UpdateGoalFromTarget(bot, controller)
        SC.SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts)
        SC.TryThrowNearbyProp(bot, controller, foundEnts)
    elseif not controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime() then
        SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy())
    end

    local buttons = SC.BuildActionButtons(bot, controller)

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end
