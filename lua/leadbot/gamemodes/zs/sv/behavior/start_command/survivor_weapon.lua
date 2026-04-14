ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

local SURVIVOR_CLOSE_RANGE_SQR = 220 * 220

local SURVIVOR_ROLE_DEFAULTS = {
    melee = {
        power = 5,
        closeBonus = 220,
        farBonus = -1000,
        panicBonus = 0,
        crowdBonus = 0,
        sustainBonus = 0,
        melee = true,
        slowFire = false
    },

    pistol = {
        power = 16,
        closeBonus = 20,
        farBonus = 35,
        panicBonus = 8,
        crowdBonus = -6,
        sustainBonus = 0,
        melee = false,
        slowFire = false
    },

    smg = {
        power = 34,
        closeBonus = 70,
        farBonus = 60,
        panicBonus = 24,
        crowdBonus = 34,
        sustainBonus = 20,
        melee = false,
        slowFire = false
    },

    shotgun = {
        power = 42,
        closeBonus = 110,
        farBonus = -35,
        panicBonus = 24,
        crowdBonus = 12,
        sustainBonus = -6,
        melee = false,
        slowFire = false
    },

    rifle = {
        power = 50,
        closeBonus = 35,
        farBonus = 95,
        panicBonus = -10,
        crowdBonus = -20,
        sustainBonus = -12,
        melee = false,
        slowFire = true
    }
}

local SURVIVOR_WEAPON_OVERRIDES = {
    weapon_zs_swissarmyknife = {
        role = "melee",
        power = 5,
        closeBonus = 240,
        farBonus = -1000,
        panicBonus = 0,
        crowdBonus = 0,
        sustainBonus = 0,
    },

    weapon_zs_battleaxe = {
        role = "pistol",
        power = 8,
        closeBonus = 260,
        farBonus = -1000,
        panicBonus = 0,
        crowdBonus = 0,
        sustainBonus = 0,
    },

    weapon_zs_peashooter = {
        role = "pistol",
        power = 10,
        closeBonus = 15,
        farBonus = 25,
        panicBonus = 4,
        crowdBonus = -10,
        sustainBonus = -2
    },

    weapon_zs_glock3 = {
        role = "pistol",
        power = 18,
        closeBonus = 20,
        farBonus = 40,
        panicBonus = 10,
        crowdBonus = -4,
        sustainBonus = 2
    },

    weapon_zs_deagle = {
        role = "pistol",
        power = 24,
        closeBonus = 28,
        farBonus = 55,
        panicBonus = 20,
        crowdBonus = -2,
        sustainBonus = -4
    },

    weapon_zs_magnum = {
        role = "pistol",
        power = 32,
        closeBonus = 45,
        farBonus = 65,
        panicBonus = 34,
        crowdBonus = 6,
        sustainBonus = -8
    },

    weapon_zs_uzi = {
        role = "smg",
        power = 36,
        closeBonus = 90,
        farBonus = 52,
        panicBonus = 30,
        crowdBonus = 46,
        sustainBonus = 34
    },

    weapon_zs_smg = {
        role = "smg",
        power = 42,
        closeBonus = 78,
        farBonus = 72,
        panicBonus = 30,
        crowdBonus = 40,
        sustainBonus = 28
    },

    weapon_zs_sweepershotgun = {
        role = "shotgun",
        power = 55,
        closeBonus = 110,
        farBonus = -25,
        panicBonus = 30,
        crowdBonus = 18,
        sustainBonus = -10
    },

    weapon_zs_crossbow = {
        role = "rifle",
        power = 65,
        closeBonus = 35,
        farBonus = 110,
        panicBonus = -10,
        crowdBonus = -20,
        sustainBonus = -12
    }    
}

local SURVIVOR_LOW_AMMO_THRESHOLDS = {
    pistol = 12,
    smg = 25,
    shotgun = 6,
    rifle = 4
}

local SURVIVOR_WEAPON_PROFILE_CACHE = {}
local SURVIVOR_MELEE_CLASS_CACHE = {}

local function GetWeaponPrimaryAmmoName(weapon)
    if not IsValid(weapon) then return nil end

    if weapon.Primary and weapon.Primary.Ammo and weapon.Primary.Ammo ~= "" and weapon.Primary.Ammo ~= "none" then
        return weapon.Primary.Ammo
    end

    local ammoType = weapon:GetPrimaryAmmoType()
    if ammoType and ammoType >= 0 and game.GetAmmoName then
        return game.GetAmmoName(ammoType)
    end

    return nil
end

local function IsMeleeWeaponClass(className)
    if not isstring(className) then
        return false
    end

    local cached = SURVIVOR_MELEE_CLASS_CACHE[className]
    if cached ~= nil then
        return cached
    end

    local classLower = string.lower(className)
    local isMelee = classLower:find("knife", 1, true)
        or classLower:find("crowbar", 1, true)
        or classLower:find("fists", 1, true)
        or classLower:find("machete", 1, true)
        or classLower:find("melee", 1, true)

    isMelee = isMelee and true or false
    SURVIVOR_MELEE_CLASS_CACHE[className] = isMelee

    return isMelee
end

local function GuessWeaponRole(className, ammoName)
    local classLower = string.lower(className or "")

    if IsMeleeWeaponClass(className) then
        return "melee"
    end

    if classLower:find("shotgun", 1, true) or ammoName == "Buckshot" then
        return "shotgun"
    end

    if classLower:find("smg", 1, true)
        or classLower:find("uzi", 1, true)
        or classLower:find("mp5", 1, true)
        or classLower:find("mac10", 1, true)
        or ammoName == "SMG1"
    then
        return "smg"
    end

    if classLower:find("rifle", 1, true)
        or classLower:find("crossbow", 1, true)
        or classLower:find("ar2", 1, true)
    then
        return "rifle"
    end

    if classLower:find("pistol", 1, true)
        or classLower:find("glock", 1, true)
        or classLower:find("deagle", 1, true)
        or classLower:find("magnum", 1, true)
        or classLower:find("revolver", 1, true)
        or classLower:find("peashooter", 1, true)
        or ammoName == "Pistol"
    then
        return "pistol"
    end

    return nil
end

local function CopyShallow(source)
    local copy = {}

    for key, value in pairs(source or {}) do
        copy[key] = value
    end

    return copy
end

local function BuildSurvivorWeaponProfile(weapon)
    if not IsValid(weapon) then return nil end

    local className = weapon:GetClass()
    local ammoName = GetWeaponPrimaryAmmoName(weapon)
    local cacheKey = className .. "|" .. tostring(ammoName or "")
    local cachedProfile = SURVIVOR_WEAPON_PROFILE_CACHE[cacheKey]

    if cachedProfile ~= nil then
        return cachedProfile or nil
    end

    local override = SURVIVOR_WEAPON_OVERRIDES[className]
    local role = override and override.role or GuessWeaponRole(className, ammoName)

    if not role then
        SURVIVOR_WEAPON_PROFILE_CACHE[cacheKey] = false
        return nil
    end

    local profile = CopyShallow(SURVIVOR_ROLE_DEFAULTS[role])

    for key, value in pairs(override or {}) do
        profile[key] = value
    end

    profile.role = role
    profile.className = className
    profile.ammoName = ammoName

    SURVIVOR_WEAPON_PROFILE_CACHE[cacheKey] = profile

    return profile
end

local function GetSurvivorThreatState(bot, foundEnts)
    local immediateCount = 0
    local closeCount = 0
    local pressureCount = 0
    local nearestDistSqr = math.huge
    local botPos = bot:GetPos()

    for _, ent in ipairs((foundEnts and foundEnts.area and foundEnts.area["player"]) or {}) do
        if IsValid(ent)
            and ent:Alive()
            and ent:Team() == TEAM_ZOMBIE
            and not ent:HasGodMode()
        then
            local distSqr = ent:GetPos():DistToSqr(botPos)

            if distSqr < nearestDistSqr then
                nearestDistSqr = distSqr
            end

            if distSqr <= 90 * 90 then
                immediateCount = immediateCount + 1
            end

            if distSqr <= 160 * 160 then
                closeCount = closeCount + 1
            end

            if distSqr <= 320 * 320 then
                pressureCount = pressureCount + 1
            end
        end
    end

    local panic = immediateCount >= 2
        or closeCount >= 3
        or nearestDistSqr <= 55 * 55

    local crowd = pressureCount >= 3
    local unsafeForSlowWeapon = immediateCount >= 1 or closeCount >= 2 or pressureCount >= 3

    return {
        immediateCount = immediateCount,
        closeCount = closeCount,
        pressureCount = pressureCount,
        nearestDistSqr = nearestDistSqr,
        panic = panic,
        crowd = crowd,
        unsafeForSlowWeapon = unsafeForSlowWeapon
    }
end

local function GetWeaponReserveAmmo(bot, weapon, profile)
    local ammoName = profile and profile.ammoName or GetWeaponPrimaryAmmoName(weapon)

    if not ammoName or ammoName == "" or ammoName == "none" then
        return 0
    end

    return bot:GetAmmoCount(ammoName)
end

local function GetSurvivorWeaponScore(bot, weapon, profile, distanceSqr, threat, activeWeapon)
    local clip = math.max(weapon:Clip1(), 0)
    local reserveAmmo = GetWeaponReserveAmmo(bot, weapon, profile)
    local totalAmmo = clip + reserveAmmo

    local isCloseRange = distanceSqr <= SURVIVOR_CLOSE_RANGE_SQR
    local isFarRange = distanceSqr >= 380 * 380
    local isVeryFarRange = distanceSqr >= 650 * 650
    local isCrossbow = profile.className == "weapon_zs_crossbow"

    local score = 0

    score = score + (profile.power or 0) * 10

    if isCloseRange then
        score = score + (profile.closeBonus or 0)
    else
        score = score + (profile.farBonus or 0)
    end

    if threat.immediateCount > 0 then
        score = score + (profile.panicBonus or 0) * threat.immediateCount
    end

    if threat.closeCount > 0 then
        score = score + (profile.panicBonus or 0) * 0.6 * threat.closeCount
    end

    if threat.crowd then
        score = score + (profile.crowdBonus or 0) * threat.pressureCount
    else
        score = score + (profile.crowdBonus or 0) * 0.25 * threat.pressureCount
    end

    local clipWeight = 2.5 + math.max((profile.panicBonus or 0) * 0.05, 0)
    if threat.crowd then
        clipWeight = clipWeight + math.max((profile.crowdBonus or 0) * 0.03, 0)
    end
    score = score + math.min(clip, 12) * clipWeight

    local reserveWeight = math.max(0.05, 0.35 + (profile.sustainBonus or 0) * 0.02)
    if threat.crowd then
        reserveWeight = reserveWeight * 1.35
    elseif threat.panic then
        reserveWeight = reserveWeight * 0.75
    end
    score = score + math.min(reserveAmmo, 90) * reserveWeight

    if profile.slowFire then
        if threat.unsafeForSlowWeapon then
            score = score
                - 120
                - threat.immediateCount * 90
                - threat.closeCount * 45
                - (threat.crowd and 80 or 0)
        elseif isCloseRange then
            score = score - 35
        else
            score = score + 20
        end
    end

    if clip <= 0 then
        score = score - 140

        if threat.panic then
            score = score - 80
        elseif isCloseRange then
            score = score - 40
        end
    elseif clip <= 1 then
        if threat.panic then
            score = score - 55
        elseif threat.crowd then
            score = score - 35
        end
    end

    if reserveAmmo <= 0 then
        score = score - 30 - math.max((profile.sustainBonus or 0) * 0.5, -10)
    end

    if totalAmmo <= 0 then
        score = score - 500
    end

    if isCrossbow then
        -- Reward the crossbow when the bot is actually safe and fighting at distance.
        if not threat.unsafeForSlowWeapon then
            score = score + 70
        end

        if not isCloseRange then
            score = score + 45
        end

        if isFarRange then
            score = score + 55
        end

        if isVeryFarRange then
            score = score + 35
        end

        if threat.pressureCount <= 1 then
            score = score + 35
        elseif threat.pressureCount == 2 then
            score = score + 10
        end

        if threat.immediateCount > 0 then
            score = score - 120
        end

        if threat.closeCount >= 2 then
            score = score - 90
        end

        if threat.crowd then
            score = score - 110
        end

        if clip > 0 then
            score = score + 25
        else
            score = score - 60
        end
    end

    if weapon == activeWeapon then
        score = score + 5
    end

    return score
end

local function HasUsableWeaponAmmo(bot, weapon, profile)
    if profile and profile.melee then
        return true
    end

    if not IsValid(weapon) then
        return false
    end

    if weapon:Clip1() > 0 then
        return true
    end

    return GetWeaponReserveAmmo(bot, weapon, profile) > 0
end

local function SelectBestSurvivorFirearm(bot, weapons, distanceSqr, foundEnts, activeWeapon)
    local threat = GetSurvivorThreatState(bot, foundEnts)

    local bestWeapon
    local bestScore = -math.huge

    for _, weapon in ipairs(weapons) do
        local profile = BuildSurvivorWeaponProfile(weapon)

        if profile and not profile.melee and HasUsableWeaponAmmo(bot, weapon, profile) then
            local score = GetSurvivorWeaponScore(bot, weapon, profile, distanceSqr, threat, activeWeapon)

            if not IsValid(bestWeapon) or score > bestScore then
                bestWeapon = weapon
                bestScore = score
            end
        end
    end

    if IsValid(bestWeapon) then
        bot:SelectWeapon(bestWeapon:GetClass())
        return true
    end

    return false
end

local function CountNearbyZombies(bot, foundEnts, maxDistSqr)
    local count = 0
    local botPos = bot:GetPos()

    for _, ent in ipairs(foundEnts.area["player"] or {}) do
        if IsValid(ent)
            and ent:Alive()
            and ent:Team() == TEAM_ZOMBIE
            and not ent:HasGodMode()
            and ent:GetPos():DistToSqr(botPos) <= maxDistSqr
        then
            count = count + 1
        end
    end

    return count
end

local function HasLowAmmoReserves(bot, weapons)
    local foundFirearm = false

    for _, weapon in ipairs(weapons) do
        local profile = BuildSurvivorWeaponProfile(weapon)

        if profile and not profile.melee then
            foundFirearm = true

            local reserveAmmo = GetWeaponReserveAmmo(bot, weapon, profile)
            local lowThreshold = SURVIVOR_LOW_AMMO_THRESHOLDS[profile.role] or 4

            if reserveAmmo > lowThreshold then
                return false
            end
        end
    end

    return foundFirearm
end

local function HasWeaponClass(weapons, className)
    for _, weapon in ipairs(weapons) do
        if IsValid(weapon) and weapon:GetClass() == className then
            return true
        end
    end

    return false
end

local function ShouldConserveAmmoWithKnife(bot, controller, foundEnts, distanceSqr, weapons)
    if bot:Team() ~= TEAM_SURVIVORS then return false end
    if not IsValid(controller.Target) or not controller.Target:IsPlayer() then return false end
    if controller.Target:Team() ~= TEAM_ZOMBIE then return false end
    if not HasWeaponClass(weapons, "weapon_zs_swissarmyknife") then return false end
    if not HasLowAmmoReserves(bot, weapons) then return false end
    if bot:Health() < 35 then return false end
    if CountNearbyZombies(bot, foundEnts, 160 * 160) > 1 then return false end

    return true
end

local function HasNoReserveFirearmAmmo(bot, weapons)
    for _, weapon in ipairs(weapons) do
        local profile = BuildSurvivorWeaponProfile(weapon)

        if profile and not profile.melee and GetWeaponReserveAmmo(bot, weapon, profile) > 0 then
            return false
        end
    end

    return true
end

local function SelectMeleeFallback(bot, weapons)
    if HasWeaponClass(weapons, "weapon_zs_swissarmyknife") then
        bot:SelectWeapon("weapon_zs_swissarmyknife")
        return true
    end

    local bestWeapon
    local bestPower = -math.huge

    for _, weapon in ipairs(weapons) do
        local profile = BuildSurvivorWeaponProfile(weapon)

        if profile and profile.melee and profile.power > bestPower then
            bestWeapon = weapon
            bestPower = profile.power
        end
    end

    if IsValid(bestWeapon) then
        bot:SelectWeapon(bestWeapon:GetClass())
        return true
    end

    return false
end

function SC.SelectSurvivorWeapon(bot, distanceSqr, controller, foundEnts, now)
    if controller.NextSelectSurvivorWeapon > now then return end

    controller.NextSelectSurvivorWeapon = now + math.Rand(0.7, 1.3)

    if bot:Team() ~= TEAM_SURVIVORS then
        controller.ConserveAmmoWithKnife = false
        return
    end

    local weapons = bot:GetWeapons()

    if SC.IsSurvivorBreakTarget(bot, controller.Target) then
        controller.ConserveAmmoWithKnife = false
        SelectMeleeFallback(bot, weapons)
        return
    end

    local activeWeapon = bot:GetActiveWeapon()
    local clip = IsValid(activeWeapon) and activeWeapon:Clip1() or 0
    local conserveAmmoWithKnife = ShouldConserveAmmoWithKnife(bot, controller, foundEnts, distanceSqr, weapons)

    controller.ConserveAmmoWithKnife = conserveAmmoWithKnife

    if (clip <= 0 and activeWeapon.GetClass and activeWeapon:GetClass() == "weapon_zs_swissarmyknife" and HasNoReserveFirearmAmmo(bot, weapons))
        or conserveAmmoWithKnife
    then
        SelectMeleeFallback(bot, weapons)
        return
    end

    if SelectBestSurvivorFirearm(bot, weapons, distanceSqr, foundEnts, activeWeapon) then
        return
    end

    SelectMeleeFallback(bot, weapons)
end
