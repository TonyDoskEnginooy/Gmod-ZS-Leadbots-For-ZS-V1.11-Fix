ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

if SC._MovementWithoutTargetLoaded then
    return
end

SC._MovementWithoutTargetLoaded = true

local function IsSurvivorMeleeWeapon(weapon)
    if not IsValid(weapon) then
        return false
    end

    local className = string.lower(weapon:GetClass() or "")

    return className == "weapon_zs_swissarmyknife"
        or className:find("knife", 1, true)
        or className:find("axe", 1, true)
        or className:find("crowbar", 1, true)
        or className:find("fists", 1, true)
        or className:find("machete", 1, true)
        or className:find("melee", 1, true)
end

local function GetWeaponReserveAmmo(bot, weapon)
    if not IsValid(bot) or not IsValid(weapon) then
        return 0
    end

    if weapon.Primary and weapon.Primary.Ammo and weapon.Primary.Ammo ~= "" and weapon.Primary.Ammo ~= "none" then
        return bot:GetAmmoCount(weapon.Primary.Ammo) or 0
    end

    local ammoType = weapon:GetPrimaryAmmoType()
    if ammoType and ammoType >= 0 then
        return bot:GetAmmoCount(ammoType) or 0
    end

    return 0
end

local function SelectSurvivorRoamingWeapon(bot)
    if bot:Team() ~= TEAM_SURVIVORS then
        return
    end

    local activeWeapon = bot:GetActiveWeapon()
    if IsValid(activeWeapon) and not IsSurvivorMeleeWeapon(activeWeapon) then
        return
    end

    local fallbackWeapon

    for _, weapon in ipairs(bot:GetWeapons()) do
        if IsValid(weapon) and not IsSurvivorMeleeWeapon(weapon) then
            if weapon:Clip1() > 0 or GetWeaponReserveAmmo(bot, weapon) > 0 then
                bot:SelectWeapon(weapon:GetClass())
                return
            end

            if not IsValid(fallbackWeapon) then
                fallbackWeapon = weapon
            end
        end
    end

    if IsValid(fallbackWeapon) then
        bot:SelectWeapon(fallbackWeapon:GetClass())
    end
end

local zombieExplorationBuckets = {
    "func_breakable",
    "func_breakable_surf",
    "func_physbox",
    "prop_physics",
    "prop_dynamic",
    "prop_door_rotating",
    "func_movelinear"
}

local function GetExplorationEntPos(ent, referencePos)
    if not IsValid(ent) then
        return nil
    end

    if isvector(referencePos) and ent.NearestPoint then
        local ok, nearestPoint = pcall(ent.NearestPoint, ent, referencePos)

        if ok and isvector(nearestPoint) then
            return nearestPoint
        end
    end

    if ent.WorldSpaceCenter then
        local ok, worldCenter = pcall(ent.WorldSpaceCenter, ent)

        if ok and isvector(worldCenter) then
            return worldCenter
        end
    end

    if ent.OBBCenter and ent.LocalToWorld then
        local ok, localCenter = pcall(ent.OBBCenter, ent)

        if ok and isvector(localCenter) then
            local okWorld, worldCenter = pcall(ent.LocalToWorld, ent, localCenter)

            if okWorld and isvector(worldCenter) then
                return worldCenter
            end
        end
    end

    return ent:GetPos()
end

local function IsZombieExplorationEnt(bot, ent)
    if not IsValid(bot) or not IsValid(ent) then
        return false
    end

    local className = ent:GetClass()

    if SC.IsSimpleObstacleTarget(bot, ent) then
        return true
    end

    return className == "prop_door_rotating" or className == "func_movelinear"
end

local function TrySetZombieExplorationGoal(bot, controller)
    local foundEnts = ZSB.Util:FindEnts(bot)
    if not foundEnts then
        return false
    end

    for _, scopeName in ipairs({ "facing", "area" }) do
        local scope = foundEnts[scopeName]

        if istable(scope) then
            for _, bucketName in RandomPairs(zombieExplorationBuckets) do
                local bucket = scope[bucketName]

                if istable(bucket) then
                    for _, ent in RandomPairs(bucket) do
                        if IsZombieExplorationEnt(bot, ent) then
                            local targetPos = GetExplorationEntPos(ent, bot:GetPos())

                            if isvector(targetPos) then
                                controller.PosGen = targetPos
                                controller.LastSegmented = CurTime() + 6
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

function SC.MoveWithoutTarget(bot, controller, strategy)
    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        SelectSurvivorRoamingWeapon(bot)

        local sigil1 = ZSB.Map:GetValue("sigil1")
        local sigil2 = ZSB.Map:GetValue("sigil2")
        local sigil3 = ZSB.Map:GetValue("sigil3")

        local sigil1Valid = IsValid(sigil1)
        local sigil2Valid = IsValid(sigil2)
        local sigil3Valid = IsValid(sigil3)

        if bot.freeRoam or strategy == 0 then

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

    if teamId == TEAM_ZOMBIE then
        if math.random(1, 100) <= 40 then
            if TrySetZombieExplorationGoal(bot, controller) then
                return
            end
        end

        if team.NumPlayers(TEAM_SURVIVORS) > 0 then
            for _, candidate in RandomPairs(player.GetAll()) do
                if IsValid(candidate) and candidate:Team() == TEAM_SURVIVORS then
                    controller.PosGen = candidate:GetPos()
                    controller.LastSegmented = CurTime() + 1000000
                    break
                end
            end
        else
            controller.PosGen = controller:FindSpot("random", { radius = 1000000 })
            controller.LastSegmented = CurTime() + 1000000
        end
    end
end
