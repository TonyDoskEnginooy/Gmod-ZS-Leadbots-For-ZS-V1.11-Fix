-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")
local leadbot_knockback = GetConVar("leadbot_knockback")
local leadbot_zcheats = GetConVar("leadbot_zcheats")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_quota = GetConVar("leadbot_quota")

-- The base ZS gamemode also uses class 1 as the reset/default state for humans.
local DEFAULT_CLASS_ID = 1

local RESET_TO_DEFAULT_CLASSES = {
    [9] = true,
    [11] = true
}

local ZOMBIE_CLASS_RULES = {
    early = {
        fallback = 1,
        classes = { 1, 5, 6, 7 }
    },
    mid = {
        fallback = 2,
        classes = { 1, 2, 3, 5, 6, 7, 8 }
    },
    late = {
        fallback = 4,
        classes = { 1, 2, 3, 4, 5, 6, 7, 8 },
        weighted = {
            { from = 12, classId = 2 },
            { from = 9, to = 11, classId = 4 }
        }
    }
}

local function HasEntries(list)
    return istable(list) and #list > 0
end

local function EnsureControllerState(controller)
    controller.ForgetTarget = controller.ForgetTarget or 0
    controller.LastSegmented = controller.LastSegmented or 0
    controller.NextJump = controller.NextJump or 0
    controller.NextCenter = controller.NextCenter or 0
    controller.nextStuckJump = controller.nextStuckJump or 0
    controller.strafeAngle = controller.strafeAngle or 1
end

local function GetInfliction()
    local infliction = tonumber(INFLICTION) or 0
    return math.Clamp(infliction, 0, 1)
end

local function GetZombieClassData(classId)
    return ZombieClasses and ZombieClasses[classId] or nil
end

local function CanUseZombieClass(classId)
    local classData = GetZombieClassData(classId)
    return classData ~= nil and GetInfliction() >= (classData.Threshold or 0)
end

local function GetZombieRuleSet()
    local infliction = GetInfliction()

    if infliction <= 0.5 then
        return ZOMBIE_CLASS_RULES.early
    end

    if infliction <= 0.75 then
        return ZOMBIE_CLASS_RULES.mid
    end

    return ZOMBIE_CLASS_RULES.late
end

local function StripHumanWeapons(bot)
    for _, weapon in ipairs(bot:GetWeapons()) do
        local weaponClass = weapon:GetClass()

        if weapons.IsBasedOn(weaponClass, "weapon_zs_base") then
            bot:StripWeapon(weaponClass)
        end
    end
end

local function SetKnockbackEnabled(bot)
    if leadbot_knockback:GetBool() then
        bot:RemoveEFlags(EFL_NO_DAMAGE_FORCES)
    else
        bot:AddEFlags(EFL_NO_DAMAGE_FORCES)
    end
end

local function PickZombieClass(bot)
    local ruleSet = GetZombieRuleSet()
    local currentClass = bot:GetZombieClass()

    -- Keep the original behavior of forcing some special classes back to a safe default.
    if not ruleSet.weighted and RESET_TO_DEFAULT_CLASSES[currentClass] then
        return ruleSet.fallback
    end

    local totalClasses = #ruleSet.classes
    local roll = math.random(1, totalClasses * 2)

    if ruleSet.weighted then
        for _, weightedRule in ipairs(ruleSet.weighted) do
            local maxRoll = weightedRule.to or math.huge

            if roll >= weightedRule.from and roll <= maxRoll then
                if CanUseZombieClass(weightedRule.classId) then
                    return weightedRule.classId
                end

                return ruleSet.fallback
            end
        end

        if RESET_TO_DEFAULT_CLASSES[currentClass] then
            return ruleSet.fallback
        end
    elseif roll > totalClasses then
        return ruleSet.fallback
    end

    local classId = ruleSet.classes[roll]

    if classId and CanUseZombieClass(classId) then
        return classId
    end

    return ruleSet.fallback
end

local function ApplyCounterStrikeZombieHealth(bot)
    timer.Simple(1, function()
        if not IsValid(bot) or bot:Team() ~= TEAM_ZOMBIE then return end

        bot:SetMaxHealth(1000)
        bot:SetHealth(1000)
    end)
end

local function SetRoamState(bot)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    if bot:Health() <= 50 or team.NumPlayers(TEAM_SURVIVORS) <= team.NumPlayers(TEAM_ZOMBIE) then
        bot.freeRoam = false
    end
end

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

local function KillLonelyHordeBot(bot)
    if leadbot_hordes:GetInt() >= 1 and bot:Team() == TEAM_SURVIVORS and leadbot_quota:GetInt() < 2 then
        bot:Kill()
    end
end

local function TraceIgnoringProps(startPos, endPos, controller, bot)
    return util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = function(ent)
            if ent == controller or ent == bot then
                return true
            end

            return IsValid(ent) and ent:GetClass() == "prop_physics"
        end
    })
end

local function ForgetInvalidTarget(controller)
    if not IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end
end

local function TargetEnemyDirectlyAhead(bot, controller)
    if IsValid(controller.Target) then return end

    for _, ent in ipairs(ents.FindInSphere(bot:GetShootPos() + bot:GetAimVector() * 50, 20)) do
        if IsValid(ent) and ent:IsPlayer() and ent ~= bot and ent:Team() ~= bot:Team() and ent:Alive() then
            controller.Target = ent
            controller.ForgetTarget = CurTime() + math.random(2, 6)
            return
        end
    end
end

local function RememberVisibleTarget(bot, controller)
    if not IsValid(controller.Target) then return end

    local feetOffset = Vector(0, 0, -29)
    local trace = TraceIgnoringProps(
        bot:GetPos() + feetOffset,
        bot:GetPos() + feetOffset + bot:GetForward() * 100000,
        controller,
        bot
    )

    if controller.ForgetTarget < CurTime() and trace.Entity == controller.Target then
        controller.ForgetTarget = CurTime() + 4
    end
end

local function IsEnemyCandidate(bot, ent)
    if not IsValid(ent) or ent == bot then return false end

    if ent:IsPlayer() then
        return ent:Alive() and ent:Team() ~= bot:Team()
    end

    return ent:IsNPC() and bot:Team() == TEAM_SURVIVORS
end

local function ShouldAvoidChemZombie(bot, ent)
    if not ent:IsPlayer() or bot:Team() ~= TEAM_SURVIVORS or not ent.GetZombieClass then
        return false
    end

    return ent:GetZombieClass() == 4 and (ZSB.Util:Odds(25) or ent:GetPos():DistToSqr(bot:GetPos()) <= 67500)
end

local function IsBetterTarget(bot, currentTarget, newTarget)
    if not IsValid(currentTarget) then
        return true
    end

    if bot:Team() == TEAM_SURVIVORS then
        return newTarget:GetPos():DistToSqr(bot:GetPos()) < currentTarget:GetPos():DistToSqr(bot:GetPos())
    end

    return newTarget:Health() < currentTarget:Health()
end

local function TrySetTarget(bot, controller, newTarget)
    if not IsEnemyCandidate(bot, newTarget) or ShouldAvoidChemZombie(bot, newTarget) then
        return false
    end

    if IsBetterTarget(bot, controller.Target, newTarget) then
        controller.Target = newTarget
        controller.ForgetTarget = CurTime() + math.random(2, 6)
        return true
    end

    return false
end

local function EvaluateCandidates(bot, controller, candidates)
    if not HasEntries(candidates) then return end

    local randomIndex = math.random(1, #candidates)
    local candidate = candidates[randomIndex]

    TrySetTarget(bot, controller, candidate)
end

local function TargetSpecialObstacle(bot, controller, obstacles)
    if bot:Team() ~= TEAM_ZOMBIE or not HasEntries(obstacles) then return end

    for _, ent in ipairs(obstacles) do
        if IsValid(ent)
            and not ent:IsWorld()
            and not ent:IsPlayer()
            and not ent:IsWeapon()
            and not (ent.IsLBot and ent:IsLBot())
            and ent:GetClass() ~= "predicted_viewmodel"
        then
            controller.Target = ent
            controller.ForgetTarget = CurTime() + math.random(2, 6)
            return
        end
    end
end

local function BreakRotatingDoor(bot, doors)
    if not HasEntries(doors) then return end

    local mapName = game.GetMap()
    if mapName ~= "zs_jail_v1" and mapName ~= "zs_placid" then return end

    local door = doors[math.random(1, #doors)]
    if IsValid(door) and door:GetClass() == "prop_door_rotating" then
        door:Fire("Break", bot, 0)
    end
end

local function ToggleMovingBrush(bot, movingBrushes)
    if not HasEntries(movingBrushes) then return end

    local movingBrush = movingBrushes[math.random(1, #movingBrushes)]
    if not IsValid(movingBrush) then return end

    if movingBrush:GetName() ~= "BunkerDoor" then
        movingBrush:Fire("Open", bot, 0)
    else
        movingBrush:Fire("Close", bot, 0)
    end
end

local function TargetBreakable(bot, controller, breakables)
    if not HasEntries(breakables) then return end

    local breakable = breakables[math.random(1, #breakables)]
    if not IsValid(breakable) or breakable:GetMaxHealth() <= 1 then return end

    local canSurvivorBreak = ZSB.Map:GetValue("survivorBreak", false)
    local canZombieBreak = ZSB.Map:GetValue("zombieBreakCheck", false)

    if (bot:Team() == TEAM_SURVIVORS and canSurvivorBreak) or (bot:Team() == TEAM_ZOMBIE and canZombieBreak) then
        controller.Target = breakable
        controller.ForgetTarget = CurTime() + math.random(2, 6)
    end
end

local function TargetPhysBox(bot, controller, physBoxes)
    if not HasEntries(physBoxes) then return end

    local physBox = physBoxes[math.random(1, #physBoxes)]
    if not IsValid(physBox) or physBox:GetMaxHealth() <= 1 then return end

    local survivorCanBreakBoxes = ZSB.Map:GetValue("survivorBoxBreak", false)
    if bot:Team() == TEAM_ZOMBIE or survivorCanBreakBoxes then
        controller.Target = physBox
        controller.ForgetTarget = CurTime() + math.random(2, 6)
    end
end

local function IsBoardModel(model)
    return model == "models/props_debris/wood_board04a.mdl"
        or model == "models/props_debris/wood_board05a.mdl"
        or model == "models/props_debris/wood_board06a.mdl"
end

local function IsIgnoredPropModel(model)
    return model == "models/props_c17/playground_carousel01.mdl"
        or model == "models/props_wasteland/prison_lamp001a.mdl"
end

local function TargetPhysicsProp(bot, controller, props)
    if not HasEntries(props) then return end

    local prop = props[math.random(1, #props)]
    if not IsValid(prop) or prop:GetMaxHealth() <= 1 then return end

    local zombieCanTargetProps = ZSB.Map:GetValue("zombiePropCheck", false)
    local model = prop:GetModel()
    if IsIgnoredPropModel(model) then return end

    local survivorCanTargetProp = bot:Team() == TEAM_SURVIVORS and prop:Health() <= 50 and not IsBoardModel(model)
    local zombieCanTargetProp = bot:Team() == TEAM_ZOMBIE and zombieCanTargetProps

    if (zombieCanTargetProp or survivorCanTargetProp) and zombieCanTargetProps then
        controller.Target = prop
        controller.ForgetTarget = CurTime() + math.random(2, 6)
        return
    end

    if bot:GetMoveType() == MOVETYPE_LADDER and (bot:Team() == TEAM_ZOMBIE or survivorCanTargetProp) and zombieCanTargetProps then
        controller.Target = prop
        controller.ForgetTarget = CurTime() + math.random(2, 6)
    end
end

local function BreakBreakableSurface(surfaces)
    if not HasEntries(surfaces) then return end

    local surface = surfaces[math.random(1, #surfaces)]
    if IsValid(surface) then
        surface:Fire("Break")
    end
end

local function TargetDynamicProp(controller, dynamicProps)
    if not HasEntries(dynamicProps) then return end

    local dynamicProp = dynamicProps[math.random(1, #dynamicProps)]
    if IsValid(dynamicProp) and dynamicProp:GetMaxHealth() > 1 then
        controller.Target = dynamicProp
        controller.ForgetTarget = CurTime() + math.random(2, 6)
    end
end

local function SelectSurvivorWeapon(bot, distanceSqr)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    local tier2 = GetConVar("zs_rewards_1"):GetInt()
    local tier3 = GetConVar("zs_rewards_3"):GetInt()
    local tier4 = GetConVar("zs_rewards_4"):GetInt()
    local activeWeapon = bot:GetActiveWeapon()
    local clip = IsValid(activeWeapon) and activeWeapon:Clip1() or 0

    if distanceSqr > 30000 then
        if bot:Frags() < tier2 then
            if bot:GetAmmoCount("Pistol") > 0 then
                bot:SelectWeapon("weapon_zs_battleaxe")
                bot:SelectWeapon("weapon_zs_peashooter")
            elseif clip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        elseif bot:Frags() < tier3 then
            if bot:GetAmmoCount("Pistol") > 0 then
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif clip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        else
            if bot:GetAmmoCount("SMG1") > 0 then
                bot:SelectWeapon("weapon_zs_uzi")
                bot:SelectWeapon("weapon_zs_smg")
            elseif bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then
                bot:SelectWeapon("weapon_zs_deagle")
                bot:SelectWeapon("weapon_zs_glock3")
                bot:SelectWeapon("weapon_zs_magnum")
            elseif clip <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end
        end

        return
    end

    if bot:Frags() < tier2 then
        if bot:GetAmmoCount("Pistol") > 0 then
            bot:SelectWeapon("weapon_zs_battleaxe")
            bot:SelectWeapon("weapon_zs_peashooter")
        elseif clip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
            bot:SelectWeapon("weapon_zs_swissarmyknife")
        end
    elseif bot:Frags() < tier3 then
        if bot:GetAmmoCount("Pistol") > 0 then
            bot:SelectWeapon("weapon_zs_deagle")
            bot:SelectWeapon("weapon_zs_glock3")
            bot:SelectWeapon("weapon_zs_magnum")
        elseif clip <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
            bot:SelectWeapon("weapon_zs_swissarmyknife")
        end
    elseif bot:Frags() < tier4 then
        if bot:GetAmmoCount("SMG1") > 0 then
            bot:SelectWeapon("weapon_zs_uzi")
            bot:SelectWeapon("weapon_zs_smg")
        elseif bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then
            bot:SelectWeapon("weapon_zs_deagle")
            bot:SelectWeapon("weapon_zs_glock3")
            bot:SelectWeapon("weapon_zs_magnum")
        elseif clip <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
            bot:SelectWeapon("weapon_zs_swissarmyknife")
        end
    else
        if bot:GetAmmoCount("Buckshot") > 0 then
            bot:SelectWeapon("weapon_zs_sweepershotgun")
        elseif bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") > 0 then
            bot:SelectWeapon("weapon_zs_uzi")
            bot:SelectWeapon("weapon_zs_smg")
        elseif bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") > 0 then
            bot:SelectWeapon("weapon_zs_deagle")
            bot:SelectWeapon("weapon_zs_glock3")
        elseif clip <= 0 and bot:GetAmmoCount("Buckshot") <= 0 and bot:GetAmmoCount("SMG1") <= 0 and bot:GetAmmoCount("Pistol") <= 0 then
            bot:SelectWeapon("weapon_zs_swissarmyknife")
        end
    end
end

local function MoveWithoutTarget(bot, controller, strategy)
    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        local sigil1 = ZSB.Map:GetValue("sigil1")
        local sigil2 = ZSB.Map:GetValue("sigil2")
        local sigil3 = ZSB.Map:GetValue("sigil3")

        local sigil1Valid = IsValid(sigil1)
        local sigil2Valid = IsValid(sigil2)
        local sigil3Valid = IsValid(sigil3)

        if bot.freeRoam or strategy == 0 then
            if bot:LBGetSurvSkill() == 0 then
                bot:SelectWeapon("weapon_zs_swissarmyknife")
            end

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

        if strategy == 1 then
            if sigil3Valid then
                local distance = bot:GetPos():DistToSqr(sigil3:GetPos())
                controller.PosGen = distance <= 2500 and nil or sigil3:GetPos()
                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end

                controller.PosGen = controller:FindSpot("random", { radius = 1000000 })
                controller.LastSegmented = CurTime() + 5
            end

            return
        end

        if strategy == 2 then
            if sigil2Valid then
                local distance = bot:GetPos():DistToSqr(sigil2:GetPos())
                controller.PosGen = distance <= 2500 and nil or sigil2:GetPos()
                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end

                for _, candidate in RandomPairs(player.GetAll()) do
                    if IsValid(candidate) and candidate:Team() == TEAM_SURVIVORS then
                        controller.PosGen = candidate:GetPos()
                        controller.LastSegmented = CurTime() + 10
                        break
                    end
                end
            end

            return
        end

        if strategy == 3 then
            if sigil1Valid then
                local distance = bot:GetPos():DistToSqr(sigil1:GetPos())
                controller.PosGen = distance <= 2500 and nil or sigil1:GetPos()
                controller.LastSegmented = CurTime() + 1
            else
                if bot:LBGetSurvSkill() == 0 then
                    bot:SelectWeapon("weapon_zs_swissarmyknife")
                end

                for _, candidate in RandomPairs(player.GetAll()) do
                    if IsValid(candidate) and candidate:Team() == TEAM_ZOMBIE and not candidate:HasGodMode() then
                        controller.PosGen = candidate:GetPos()
                        controller.LastSegmented = CurTime() + 10
                        break
                    end
                end
            end
        end

        return
    end

    if teamId == TEAM_ZOMBIE and team.NumPlayers(TEAM_SURVIVORS) > 0 then
        for _, candidate in RandomPairs(player.GetAll()) do
            if IsValid(candidate) and candidate:Team() == TEAM_SURVIVORS then
                controller.PosGen = candidate:GetPos()
                controller.LastSegmented = CurTime() + 1000000
                break
            end
        end
    end
end

local function UpdateGoalFromTarget(bot, controller)
    if not IsValid(controller.Target) then return end

    if (bot:IsPlayer() and controller.Target:IsPlayer() and bot:Team() ~= controller.Target:Team())
        or (bot:Team() == TEAM_SURVIVORS and controller.Target:IsNPC())
    then
        controller.PosGen = controller.Target:GetPos()
        controller.LastSegmented = CurTime() + 0.1
    end
end

function LeadBot.Spawn(bot)
    SetKnockbackEnabled(bot)

    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        -- This is a state reset, not a real survivor class system.
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        return
    end

    if teamId ~= TEAM_ZOMBIE then
        return
    end

    StripHumanWeapons(bot)

    if leadbot_cs:GetBool() then
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        ApplyCounterStrikeZombieHealth(bot)
        return
    end

    bot:SetZombieClass(PickZombieClass(bot))
end

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    EnsureControllerState(controller)

    KillLonelyHordeBot(bot)
    SetRoamState(bot)
    ApplyZombieCheats(bot)

    ForgetInvalidTarget(controller)
    TargetEnemyDirectlyAhead(bot, controller)
    RememberVisibleTarget(bot, controller)

    local foundEnts = ZSB.Util:FindEnts(bot)
    local facingPlayers = foundEnts.facing["player"]
    local nearPlayers = foundEnts.near["player"]

    EvaluateCandidates(bot, controller, facingPlayers)
    EvaluateCandidates(bot, controller, nearPlayers)

    TargetSpecialObstacle(bot, controller, foundEnts.near["predicted_viewmodel"])
    TargetBreakable(bot, controller, foundEnts.near["func_breakable"])
    TargetPhysBox(bot, controller, foundEnts.near["func_physbox"])
    TargetPhysicsProp(bot, controller, foundEnts.near["prop_physics"])
    TargetDynamicProp(controller, foundEnts.near["prop_dynamic"])

    BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])
    BreakBreakableSurface(foundEnts.near["func_breakable_surf"])
    ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if IsValid(controller.Target) then
        local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

        UpdateGoalFromTarget(bot, controller)
        SelectSurvivorWeapon(bot, distanceSqr)
    elseif not controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime() then
        MoveWithoutTarget(bot, controller, bot:LBGetStrategy())
    end
end
