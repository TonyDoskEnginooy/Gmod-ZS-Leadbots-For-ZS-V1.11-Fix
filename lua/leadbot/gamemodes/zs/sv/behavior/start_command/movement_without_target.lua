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
