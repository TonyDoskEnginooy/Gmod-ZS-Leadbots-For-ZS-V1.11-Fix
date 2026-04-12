local function includeStartCommandModule(fileName)
    include("start_command/" .. fileName)
end

includeStartCommandModule("shared.lua")
includeStartCommandModule("zombie_targeting.lua")
includeStartCommandModule("zombie_prop_throw.lua")
includeStartCommandModule("map_interactions.lua")
includeStartCommandModule("movement_to_sigil.lua")
includeStartCommandModule("movement_without_target.lua")
includeStartCommandModule("combat_buttons.lua")
includeStartCommandModule("survival_weapon_selection.lua")

local SC = ZSB.StartCommand

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    SC.EnsureControllerState(controller)
    SC.KillLonelyHordeBot(bot)
    SC.ForgetInvalidTarget(bot, controller)

    local foundEnts = ZSB.Util:FindEnts(bot)

    SC.ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if bot:Team() == TEAM_SURVIVORS then
        SC.SetRoamState(bot)
        SC.AcquireTemperamentTarget(bot, controller, foundEnts)

        if IsValid(controller.Target) then
            local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

            SC.SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen or controller.LastSegmented < CurTime() then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy())
        end
    end

    if bot:Team() == TEAM_ZOMBIE then
        SC.ApplyZombieCheats(bot)
        SC.BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])
        SC.BreakBreakableSurface(foundEnts.near["func_breakable_surf"])
        SC.AcquireTemperamentTarget(bot, controller, foundEnts)

        if IsValid(controller.Target) then
            SC.TryThrowNearbyProp(bot, controller, foundEnts)
            SC.UpdateGoalFromTarget(bot, controller)
        elseif not controller.PosGen or controller.LastSegmented < CurTime() then
            SC.MoveWithoutTarget(bot, controller, bot:LBGetStrategy())
        end
    end

    local buttons = SC.BuildActionButtons(bot, controller)

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end
