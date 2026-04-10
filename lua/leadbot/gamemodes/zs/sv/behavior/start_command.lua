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

local TARGET_LOAD = setmetatable({}, { __mode = "k" })
local NEXT_TARGET_LOAD_REFRESH = 0

local FALLBACK_ZOMBIE_TEMPERAMENT = {
    name = "rusher",
    loadPenalty = 60,
    holdBonus = 220,
    imperfection = 30,
    preferWeak = 1.0,
    obstacleBias = 0,
    flankBias = 0.15,
    moveSpeedMul = 1.0
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

local function ForgetInvalidTarget(controller)
    if not IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
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

local function GetZombieTemperament(bot)
    return bot.LeadBot_ZombieTemperament or FALLBACK_ZOMBIE_TEMPERAMENT
end

local function ClearTargetLoad()
    for ent in pairs(TARGET_LOAD) do
        TARGET_LOAD[ent] = nil
    end
end

local function RefreshTargetLoad()
    if NEXT_TARGET_LOAD_REFRESH > CurTime() then return end

    ClearTargetLoad()

    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply.IsLBot and ply:IsLBot() then
            local controller = ply:GetController()

            if IsValid(controller) and IsValid(controller.Target) then
                TARGET_LOAD[controller.Target] = (TARGET_LOAD[controller.Target] or 0) + 1
            end
        end
    end

    NEXT_TARGET_LOAD_REFRESH = CurTime() + 0.2
end

local function StableNoise(bot, ent, magnitude)
    local bucket = math.floor(CurTime() * 1.5)
    local seed = (bot.LeadBot_PersonalitySeed or 1) * 0.013 + ent:EntIndex() * 0.173 + bucket * 0.071
    return math.sin(seed * 23.417) * magnitude
end

local function GetDistanceScore(distanceSqr)
    if distanceSqr <= 2500 then
        return 260
    elseif distanceSqr <= 22500 then
        return 180
    elseif distanceSqr <= 90000 then
        return 100
    elseif distanceSqr <= 250000 then
        return 20
    end

    return -80
end

local function ScoreZombieEnemyTarget(bot, controller, target, sourceTag)
    if not IsEnemyCandidate(bot, target) or ShouldAvoidChemZombie(bot, target) then
        return nil
    end

    local temperament = GetZombieTemperament(bot)
    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local score = 0

    if target:IsPlayer() then
        score = score + 1350
        score = score + math.Clamp((100 - target:Health()) * temperament.preferWeak * 1.5, 0, 180)
    elseif target:IsNPC() then
        score = score + 900
    end

    score = score + GetDistanceScore(distanceSqr)

    if sourceTag == "facing_player" then
        score = score + 220
    end

    if target == controller.Target then
        score = score + temperament.holdBonus
    end

    local load = TARGET_LOAD[target] or 0

    if target == controller.Target and load > 0 then
        load = load - 1
    end

    score = score - (load * temperament.loadPenalty)
    score = score + StableNoise(bot, target, temperament.imperfection)

    return score
end

local function IsIgnoredPropModel(model)
    return model == "models/props_c17/playground_carousel01.mdl"
        or model == "models/props_wasteland/prison_lamp001a.mdl"
end

local function IsBoardModel(model)
    return model == "models/props_debris/wood_board04a.mdl"
        or model == "models/props_debris/wood_board05a.mdl"
        or model == "models/props_debris/wood_board06a.mdl"
end

local function IsSimpleObstacleTarget(bot, ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    if class == "func_breakable" or class == "func_physbox" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    if class == "prop_physics" then
        if not ent.GetMaxHealth or ent:GetMaxHealth() <= 1 then
            return false
        end

        local model = ent:GetModel()

        return not IsIgnoredPropModel(model) and not IsBoardModel(model)
    end

    if class == "prop_dynamic" then
        return ent.GetMaxHealth and ent:GetMaxHealth() > 1
    end

    return false
end

local function ScoreZombieObstacleTarget(bot, controller, target)
    if not IsSimpleObstacleTarget(bot, target) then
        return nil
    end

    local temperament = GetZombieTemperament(bot)
    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())
    local score = 140 + temperament.obstacleBias + GetDistanceScore(distanceSqr)

    if target == controller.Target then
        score = score + math.floor(temperament.holdBonus * 0.4)
    end

    if IsValid(controller.Target) and (controller.Target:IsPlayer() or controller.Target:IsNPC()) then
        score = score - 450
    end

    score = score + StableNoise(bot, target, math.floor(temperament.imperfection * 0.4))

    return score
end

local function ConsiderBestTarget(bot, controller, state, list, sourceTag, scorer)
    if not HasEntries(list) then return end

    for _, ent in ipairs(list) do
        if IsValid(ent) then
            local score = scorer(bot, controller, ent, sourceTag)

            if score and score > state.bestScore then
                state.bestScore = score
                state.bestTarget = ent
            end
        end
    end
end

local function AcquireTemperamentTarget(bot, controller, foundEnts)
    RefreshTargetLoad()

    local state = {
        bestScore = -math.huge,
        bestTarget = nil
    }

    ConsiderBestTarget(bot, controller, state, foundEnts.facing["player"], "facing_player", ScoreZombieEnemyTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["player"], "near_player", ScoreZombieEnemyTarget)
    ConsiderBestTarget(bot, controller, state, foundEnts.near["npc"], "near_npc", ScoreZombieEnemyTarget)

    if not IsValid(state.bestTarget) then
        ConsiderBestTarget(bot, controller, state, foundEnts.near["func_breakable"], "func_breakable", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["func_physbox"], "func_physbox", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_physics"], "prop_physics", ScoreZombieObstacleTarget)
        ConsiderBestTarget(bot, controller, state, foundEnts.near["prop_dynamic"], "prop_dynamic", ScoreZombieObstacleTarget)
    end

    if IsValid(state.bestTarget) then
        controller.Target = state.bestTarget
        controller.ForgetTarget = CurTime() + 0.9
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

local function BreakBreakableSurface(surfaces)
    if not HasEntries(surfaces) then return end

    local surface = surfaces[math.random(1, #surfaces)]
    if IsValid(surface) then
        surface:Fire("Break")
    end
end

local function GetRewardThreshold(index)
    local thresholdCvar = GetConVar("zs_rewards_" .. index .. "_threshold")
    if thresholdCvar then
        return thresholdCvar:GetInt()
    end

    local legacyCvar = GetConVar("zs_rewards_" .. index)
    return legacyCvar and legacyCvar:GetInt() or 0
end

local function HasWeaponClass(bot, className)
    return IsValid(bot:GetWeapon(className))
end

local function SelectMeleeFallback(bot)
    if HasWeaponClass(bot, "weapon_zs_swissarmyknife") then
        bot:SelectWeapon("weapon_zs_swissarmyknife")
        return true
    end

    return false
end

local function HasNoReserveFirearmAmmo(bot)
    return bot:GetAmmoCount("Pistol") <= 0
        and bot:GetAmmoCount("SMG1") <= 0
        and bot:GetAmmoCount("Buckshot") <= 0
end


local function HasLowAmmoReserves(bot)
    return bot:GetAmmoCount("Pistol") <= 12
        and bot:GetAmmoCount("SMG1") <= 20
        and bot:GetAmmoCount("Buckshot") <= 4
end

local function CountNearbyZombies(bot, foundEnts, maxDistSqr)
    local count = 0

    for _, ent in ipairs(foundEnts.area["player"] or {}) do
        if IsValid(ent)
            and ent:Alive()
            and ent:Team() == TEAM_ZOMBIE
            and not ent:HasGodMode()
            and ent:GetPos():DistToSqr(bot:GetPos()) <= maxDistSqr
        then
            count = count + 1
        end
    end

    return count
end

local function ShouldConserveAmmoWithKnife(bot, controller, foundEnts, distanceSqr)
    if bot:Team() ~= TEAM_SURVIVORS then return false end
    if not IsValid(controller.Target) or not controller.Target:IsPlayer() then return false end
    if controller.Target:Team() ~= TEAM_ZOMBIE then return false end
    if not HasWeaponClass(bot, "weapon_zs_swissarmyknife") then return false end
    if not HasLowAmmoReserves(bot) then return false end
    if distanceSqr > 300 * 300 then return false end

    return CountNearbyZombies(bot, foundEnts, 350 * 350) == 1
end

local function SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts)
    if bot:Team() ~= TEAM_SURVIVORS then return end

    local tier2 = GetRewardThreshold(1)
    local tier3 = GetRewardThreshold(3)
    local tier4 = GetRewardThreshold(4)

    local activeWeapon = bot:GetActiveWeapon()
    local clip = IsValid(activeWeapon) and activeWeapon:Clip1() or 0

    if clip <= 0 and HasNoReserveFirearmAmmo(bot) or ShouldConserveAmmoWithKnife(bot, controller, foundEnts, distanceSqr) then
        SelectMeleeFallback(bot)
        return
    end

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

local function IsCombatTarget(bot, target)
    if not IsValid(target) or target == bot then
        return false
    end

    if target:IsPlayer() then
        return target:Alive()
            and target:Team() ~= bot:Team()
            and not target:HasGodMode()
    end

    return target:IsNPC() and bot:Team() == TEAM_SURVIVORS
end

local function HasClearShot(bot, controller, target)
    local targetPos = target:IsPlayer() and target:EyePos() or target:WorldSpaceCenter()

    local aimDir = (targetPos - bot:GetShootPos()):GetNormalized()
    if bot:GetAimVector():Dot(aimDir) < 0.85 then
        return false
    end

    local tr = util.TraceLine({
        start = bot:GetShootPos(),
        endpos = targetPos,
        filter = {bot, controller}
    })

    return tr.Entity == target
end

local function IsKnifeActive(bot)
    local weapon = bot:GetActiveWeapon()
    return IsValid(weapon) and weapon:GetClass() == "weapon_zs_swissarmyknife"
end

local function ShouldPressAttack(bot, controller)
    local target = controller.Target
    if not IsValid(target) then
        return false
    end

    local distanceSqr = bot:GetPos():DistToSqr(target:GetPos())

    if bot:Team() == TEAM_SURVIVORS then
        if not IsCombatTarget(bot, target) then
            return false
        end

        if IsKnifeActive(bot) then
            return distanceSqr <= 95 * 95 and HasClearShot(bot, controller, target)
        end

        return HasClearShot(bot, controller, target)
    end

    if bot:Team() == TEAM_ZOMBIE then
        if IsCombatTarget(bot, target) then
            return distanceSqr <= 22500
        end

        if IsSimpleObstacleTarget(bot, target) then
            return distanceSqr <= 10000
        end
    end

    return false
end

local function BuildActionButtons(bot, controller)
    local buttons = IN_SPEED
    local weapon = bot:GetActiveWeapon()
    local target = controller.Target

    if IsValid(weapon) then
        local clip1 = weapon:Clip1()
        local maxClip1 = weapon:GetMaxClip1()

        if clip1 == 0 or (not IsValid(target) and maxClip1 > 0 and clip1 <= maxClip1 / 2) then
            buttons = bit.bor(buttons, IN_RELOAD)
        end
    end

    if ShouldPressAttack(bot, controller) then
        buttons = bit.bor(buttons, IN_ATTACK)
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos or bot:GetPos()
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-30, ang.y, 0)
        else
            controller.LookAt = Angle(30, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = bit.bor(buttons, IN_FORWARD)
    end

    if controller.NextDuck and controller.NextDuck > CurTime() then
        buttons = bit.bor(buttons, IN_DUCK)
    elseif controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1
        buttons = bit.bor(buttons, IN_JUMP)
    end

    if not bot:IsOnGround() and controller.NextJump and controller.NextJump > CurTime() then
        buttons = bit.bor(buttons, IN_DUCK)
    end

    return buttons
end

function LeadBot.StartCommand(bot, cmd)
    local controller = bot:GetController()
    if not IsValid(controller) then return end

    EnsureControllerState(controller)

    KillLonelyHordeBot(bot)
    SetRoamState(bot)
    ApplyZombieCheats(bot)

    ForgetInvalidTarget(controller)

    local foundEnts = ZSB.Util:FindEnts(bot)
    AcquireTemperamentTarget(bot, controller, foundEnts)

    BreakRotatingDoor(bot, foundEnts.near["prop_door_rotating"])
    BreakBreakableSurface(foundEnts.near["func_breakable_surf"])
    ToggleMovingBrush(bot, foundEnts.near["func_movelinear"])

    if IsValid(controller.Target) then
        local distanceSqr = controller.Target:GetPos():DistToSqr(bot:GetPos())

        UpdateGoalFromTarget(bot, controller)
        SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts)
    elseif not controller.PosGen or bot:GetPos():DistToSqr(controller.PosGen) < 1000 or controller.LastSegmented < CurTime() then
        MoveWithoutTarget(bot, controller, bot:LBGetStrategy())
    end

    local buttons = BuildActionButtons(bot, controller)

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end
