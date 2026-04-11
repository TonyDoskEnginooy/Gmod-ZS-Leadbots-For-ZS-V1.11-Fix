-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")
local leadbot_knockback = GetConVar("leadbot_knockback")

-- The base ZS gamemode also uses class 1 as the reset/default state for humans.
local DEFAULT_CLASS_ID = 1

local RESET_TO_DEFAULT_CLASSES = {
    [9] = true
}

local ZOMBIE_CLASS_WEIGHTS = {
    early = {
        [1] = 72,
        [5] = 18,
        [6] = 10,
        [7] = 8
    },
    mid = {
        [1] = 20,
        [2] = 24,
        [3] = 10,
        [5] = 18,
        [6] = 8,
        [7] = 10,
        [8] = 6
    },
    late = {
        [1] = 10,
        [2] = 20,
        [3] = 18,
        [4] = 18,
        [5] = 12,
        [6] = 4,
        [7] = 6,
        [8] = 12
    }
}

local TEMPERAMENT_CLASS_MULTIPLIERS = {
    rusher = {
        [1] = 1.20,
        [2] = 1.10,
        [3] = 1.05,
        [4] = 0.95,
        [5] = 0.95,
        [6] = 0.85,
        [7] = 0.90,
        [8] = 0.90
    },
    flanker = {
        [1] = 0.70,
        [2] = 1.35,
        [3] = 0.95,
        [4] = 0.85,
        [5] = 1.25,
        [6] = 1.10,
        [7] = 1.25,
        [8] = 1.05
    },
    breaker = {
        [1] = 1.35,
        [2] = 0.85,
        [3] = 1.20,
        [4] = 1.30,
        [5] = 0.85,
        [6] = 0.70,
        [7] = 0.75,
        [8] = 1.15
    },
    drifter = {
        [1] = 0.85,
        [2] = 1.05,
        [3] = 1.00,
        [4] = 0.95,
        [5] = 1.20,
        [6] = 1.15,
        [7] = 1.20,
        [8] = 1.15
    },
    berserker = {
        [1] = 0.95,
        [2] = 1.40,
        [3] = 1.15,
        [4] = 1.10,
        [5] = 1.30,
        [6] = 0.90,
        [7] = 1.20,
        [8] = 1.00
    }
}

local CLASS_POPULATION_PENALTY = {
    [1] = 0.16,
    [2] = 0.30,
    [3] = 0.28,
    [4] = 0.35,
    [5] = 0.24,
    [6] = 0.40,
    [7] = 0.40,
    [8] = 0.32
}

local EMPTY_CLASS_BONUS = 1.25
local SAME_CLASS_REPEAT_PENALTY = 0.60

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

local function GetZombieStage()
    local infliction = GetInfliction()

    if infliction <= 0.5 then
        return "early"
    end

    if infliction <= 0.75 then
        return "mid"
    end

    return "late"
end

local function GetZombieTemperamentName(bot)
    local temperament = bot.LeadBot_ZombieTemperament
    return temperament and temperament.name or "rusher"
end

local function GetTemperamentClassMultiplier(bot, classId)
    local temperamentName = GetZombieTemperamentName(bot)
    local temperamentWeights = TEMPERAMENT_CLASS_MULTIPLIERS[temperamentName]

    if not temperamentWeights then
        return 1
    end

    return temperamentWeights[classId] or 1
end

local function GetAliveZombieClassCount(classId, ignoreBot)
    local count = 0

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= ignoreBot
            and IsValid(ply)
            and ply:Alive()
            and ply:Team() == TEAM_ZOMBIE
            and ply.GetZombieClass
            and ply:GetZombieClass() == classId
        then
            count = count + 1
        end
    end

    return count
end

local function ApplyPressureBias(weight, classId, infliction, humanCount)
    if humanCount <= 2 then
        if classId == 2 or classId == 4 or classId == 5 then
            weight = weight * 1.25
        elseif classId == 6 or classId == 7 then
            weight = weight * 0.45
        end
    elseif infliction >= 0.75 then
        if classId == 3 or classId == 4 or classId == 8 then
            weight = weight * 1.15
        elseif classId == 6 or classId == 7 then
            weight = weight * 0.60
        end
    elseif infliction >= 0.5 then
        if classId == 2 or classId == 5 then
            weight = weight * 1.10
        end
    end

    return weight
end

local function GetFallbackZombieClass(stage)
    if stage == "late" then
        if CanUseZombieClass(4) then
            return 4
        end

        if CanUseZombieClass(2) then
            return 2
        end

        if CanUseZombieClass(3) then
            return 3
        end

        return DEFAULT_CLASS_ID
    end

    if stage == "mid" and CanUseZombieClass(2) then
        return 2
    end

    return DEFAULT_CLASS_ID
end

local function BuildWeightedZombiePool(bot)
    local stage = GetZombieStage()
    local stageWeights = ZOMBIE_CLASS_WEIGHTS[stage]
    local infliction = GetInfliction()
    local humanCount = team.NumPlayers(TEAM_SURVIVORS)
    local currentClass = bot:GetZombieClass()
    local totalWeight = 0
    local entries = {}

    for classId, baseWeight in pairs(stageWeights) do
        if CanUseZombieClass(classId) and not RESET_TO_DEFAULT_CLASSES[classId] then
            local weight = baseWeight

            weight = weight * GetTemperamentClassMultiplier(bot, classId)
            weight = ApplyPressureBias(weight, classId, infliction, humanCount)

            local population = GetAliveZombieClassCount(classId, bot)
            local populationPenalty = CLASS_POPULATION_PENALTY[classId] or 0.25

            weight = weight / (1 + population * populationPenalty)

            if population == 0 then
                weight = weight * EMPTY_CLASS_BONUS
            end

            if currentClass == classId then
                weight = weight * SAME_CLASS_REPEAT_PENALTY
            end

            if weight > 0 then
                totalWeight = totalWeight + weight
                entries[#entries + 1] = {
                    classId = classId,
                    weight = weight
                }
            end
        end
    end

    return entries, totalWeight, stage
end

local function PickWeightedZombieClass(entries, totalWeight, fallbackClassId)
    if totalWeight <= 0 or #entries <= 0 then
        return fallbackClassId
    end

    local roll = math.Rand(0, totalWeight)

    for _, entry in ipairs(entries) do
        roll = roll - entry.weight
        if roll <= 0 then
            return entry.classId
        end
    end

    return entries[#entries].classId
end

local function PickZombieClass(bot)
    local currentClass = bot:GetZombieClass()

    if RESET_TO_DEFAULT_CLASSES[currentClass] then
        return DEFAULT_CLASS_ID
    end

    local entries, totalWeight, stage = BuildWeightedZombiePool(bot)
    local fallbackClassId = GetFallbackZombieClass(stage)

    return PickWeightedZombieClass(entries, totalWeight, fallbackClassId)
end

local function StripHumanWeapons(bot)
    for _, weapon in ipairs(bot:GetWeapons()) do
        local weaponClass = weapon:GetClass()

        if weapons.IsBasedOn(weaponClass, "weapon_zs_base") or weaponClass == "weapon_zs_swissarmyknife" then
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

local function ApplyCounterStrikeZombieHealth(bot)
    timer.Simple(1, function()
        if not IsValid(bot) or bot:Team() ~= TEAM_ZOMBIE then return end

        bot:SetMaxHealth(1000)
        bot:SetHealth(1000)
    end)
end

local function ClampColorVector(vec, fallback)
    if not isvector(vec) then
        return fallback
    end

    return Vector(
        math.Clamp(vec.x, 0, 1),
        math.Clamp(vec.y, 0, 1),
        math.Clamp(vec.z, 0, 1)
    )
end

local function ApplySurvivorLateAppearance(bot)
    -- Run after the gamemode finishes its own spawn/model logic.
    timer.Simple(0.1, function()
        if not IsValid(bot) or bot:Team() ~= TEAM_SURVIVORS then
            return
        end

        local modelName = bot.LBGetModel and bot:LBGetModel() or nil
        if isstring(modelName) and modelName ~= "" then
            local translatedModel = player_manager.TranslatePlayerModel(modelName)
            if isstring(translatedModel) and translatedModel ~= "" then
                bot:SetModel(translatedModel)
                bot:SetNWString("LeadBot_AvatarModel", translatedModel)
            end
        end

        if bot.LBGetColor then
            local playerColor = ClampColorVector(bot:LBGetColor(), Vector(0, 0, 0))
            local weaponColor = ClampColorVector(bot:LBGetColor(true), Vector(0, 0, 0))

            bot:SetPlayerColor(playerColor)
            bot:SetWeaponColor(weaponColor)
            bot:SetNWVector("LeadBot_AvatarColor", playerColor)
        end
    end)
end

function LeadBot.Spawn(bot)
    SetKnockbackEnabled(bot)

    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        -- This is a state reset, not a real survivor class system.
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        ApplySurvivorLateAppearance(bot)
        return
    end

    if teamId ~= TEAM_ZOMBIE then
        return
    end

    StripHumanWeapons(bot)

    local preservedZombieClass = bot.LeadBot_PreserveZombieClass
    if preservedZombieClass then
        -- Keep special revive classes for a single spawn only.
        bot.LeadBot_PreserveZombieClass = nil
        bot:SetZombieClass(preservedZombieClass)
        return
    end

    if leadbot_cs:GetBool() then
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        ApplyCounterStrikeZombieHealth(bot)
        return
    end

    bot:SetZombieClass(PickZombieClass(bot))
end