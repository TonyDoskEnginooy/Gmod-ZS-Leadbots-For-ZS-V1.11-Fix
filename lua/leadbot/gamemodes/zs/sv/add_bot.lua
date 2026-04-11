local defaultBotNames = {
    alyx = "Alyx Vance",
    kleiner = "BuizBuben241",
    breen = "Dr. Wallace Breen",
    gman = "The G-Man",
    odessa = "Odessa Cubbage",
    eli = "Eli Vance",
    monk = "Father Grigori",
    mossman = "Judith Mossman",
    mossmanarctic = "Bushe",
    barney = "Barney Calhoun",

    dod_american = "Boldier",
    dod_german = "German Soldier",

    css_swat = "GIGN",
    css_leet = "Elite Crew",
    css_arctic = "Artic Avengers",
    css_urban = "SEAL Team Six",
    css_riot = "GSG-9",
    css_gasmask = "SAS",
    css_phoenix = "Phoenix Connexion",
    css_guerilla = "Guerilla Warfare",

    hostage01 = "Art",
    hostage02 = "Sandro",
    hostage03 = "Vance",
    hostage04 = "Cohrt",

    police = "Civil Protection",
    policefem = "Civil Erection",

    chell = "Chell",

    combine = "Combine Soldier",
    combineprison = "Combine Prison Guard",
    combineelite = "Bony Bosk Benginooy",
    stripped = "Stripped Combine Soldier",

    zombie = "Zombie",
    zombiefast = "Fast Zombie",
    zombine = "Zombine",
    corpse = "Corpse",
    charple = "Charple",
    skeleton = "BiversRox",

    male01 = "Dan",
    male02 = "Ted",
    male03 = "Joe",
    male04 = "Eric",
    male05 = "Tart",
    male06 = "Mandro",
    male07 = "Mike",
    male08 = "Dance",
    male09 = "Erdin",
    male10 = "Van",
    male11 = "Fed",
    male12 = "Poe",
    male13 = "Deric",
    male14 = "Fart",
    male15 = "Candro",
    male16 = "Like",
    male17 = "Prance",
    male18 = "Ferdin",
    female01 = "Joey",
    female02 = "Kanisha",
    female03 = "Kim",
    female04 = "Chau",
    female05 = "Naomi",
    female06 = "Lakeetra",
    female07 = "Boey",
    female08 = "Latisha",
    female09 = "Jim",
    female10 = "Chow",
    female11 = "Satochi",
    female12 = "LackEatTra",

    medic01 = "Pan",
    medic02 = "Bed",
    medic03 = "Loe",
    medic04 = "Pric",
    medic05 = "Bart",
    medic06 = "Fandro",
    medic07 = "Pike",
    medic08 = "Lance",
    medic09 = "Sherdin",
    medic10 = "Moey",
    medic11 = "Moqueefa",
    medic12 = "Tim",
    medic13 = "Cow",
    medic14 = "Natsuke",
    medic15 = "Lackee",

    refugee01 = "Led",
    refugee02 = "Leric",
    refugee03 = "Landro",
    refugee04 = "Yance",
}

local ZOMBIE_TEMPERAMENTS = {
    {
        name = "rusher",
        weight = 30,
        loadPenalty = 55,
        holdBonus = 240,
        imperfection = 25,
        preferWeak = 1.2,
        obstacleBias = 0,
        flankBias = 0.10,
        moveSpeedMul = 1.08
    },
    {
        name = "flanker",
        weight = 20,
        loadPenalty = 190,
        holdBonus = 150,
        imperfection = 45,
        preferWeak = 0.9,
        obstacleBias = -30,
        flankBias = 0.95,
        moveSpeedMul = 1.00
    },
    {
        name = "breaker",
        weight = 15,
        loadPenalty = 110,
        holdBonus = 170,
        imperfection = 35,
        preferWeak = 0.8,
        obstacleBias = 170,
        flankBias = 0.25,
        moveSpeedMul = 0.98
    },
    {
        name = "drifter",
        weight = 20,
        loadPenalty = 240,
        holdBonus = 90,
        imperfection = 95,
        preferWeak = 0.7,
        obstacleBias = 40,
        flankBias = 0.55,
        moveSpeedMul = 0.92
    },
    {
        name = "berserker",
        weight = 15,
        loadPenalty = 20,
        holdBonus = 300,
        imperfection = 20,
        preferWeak = 1.4,
        obstacleBias = -60,
        flankBias = 0.05,
        moveSpeedMul = 1.12
    }
}

-- Cache cvars
local leadbot_names = GetConVar("leadbot_names")
local leadbot_models = GetConVar("leadbot_models")
local leadbot_name_prefix = GetConVar("leadbot_name_prefix")
local leadbot_strategy = GetConVar("leadbot_strategy")
local sv_cheats = GetConVar("sv_cheats")

local function PickZombieTemperament()
    local totalWeight = 0

    for _, temperament in ipairs(ZOMBIE_TEMPERAMENTS) do
        totalWeight = totalWeight + temperament.weight
    end

    local roll = math.Rand(0, totalWeight)

    for _, temperament in ipairs(ZOMBIE_TEMPERAMENTS) do
        roll = roll - temperament.weight

        if roll <= 0 then
            return table.Copy(temperament)
        end
    end

    return table.Copy(ZOMBIE_TEMPERAMENTS[1])
end

local function EnsureZombieTemperament(bot)
    if bot.LeadBot_ZombieTemperament then return end

    bot.LeadBot_ZombieTemperament = PickZombieTemperament()
    bot.LeadBot_PersonalitySeed = math.Rand(1, 100000)
end

local function SplitCSV(str)
    local values = {}

    for _, value in ipairs(string.Split(str or "", ",")) do
        value = string.Trim(value)
        if value ~= "" then
            values[#values + 1] = value
        end
    end

    return values
end

local function NormalizeModelName(modelName)
    if not modelName or modelName == "" then return nil end
    return player_manager.TranslateToPlayerModelName(modelName) or modelName
end

local function GetConfiguredModelPool()
    local models = {}
    local seen = {}

    for _, value in ipairs(SplitCSV(leadbot_models and leadbot_models:GetString() or "")) do
        local modelName = NormalizeModelName(value)
        if modelName and not seen[modelName] then
            seen[modelName] = true
            models[#models + 1] = modelName
        end
    end

    return models
end

local function GetDefaultModelPool()
    local models = {}
    local seen = {}

    for _, value in pairs(player_manager.AllValidModels()) do
        local modelName = NormalizeModelName(value)
        if modelName and not seen[modelName] then
            seen[modelName] = true
            models[#models + 1] = modelName
        end
    end

    return models
end

local function IsModelNameTaken(modelName)
    if not modelName or modelName == "" then return false end

    local modelNameLower = string.lower(modelName)
    local defaultName = defaultBotNames[modelNameLower]
    local defaultNameLower = defaultName and string.lower(defaultName) or nil

    for _, ply in ipairs(player.GetBots()) do
        local nick = string.lower(ply:Nick())

        if ply.OriginalName == modelName then
            return true
        end

        if nick == modelNameLower then
            return true
        end

        if defaultNameLower and nick == defaultNameLower then
            return true
        end
    end

    return false
end

local function PickModelFromPool(pool, preferUnused)
    if #pool == 0 then return nil end

    if preferUnused then
        local available = {}

        for _, modelName in ipairs(pool) do
            if not IsModelNameTaken(modelName) then
                available[#available + 1] = modelName
            end
        end

        if #available > 0 then
            return table.Random(available)
        end
    end

    return table.Random(pool)
end

local function GetRandomModelName(preferUnused)
    local pool = GetConfiguredModelPool()
    if #pool == 0 then
        pool = GetDefaultModelPool()
    end

    return PickModelFromPool(pool, preferUnused) or "kleiner"
end

local function FormatBotName(modelName)
    local resolvedName = string.lower(modelName or "leadbot")
    resolvedName = defaultBotNames[resolvedName] or resolvedName

    local pathParts = string.Split(resolvedName, "/")
    resolvedName = pathParts[#pathParts]

    local nameParts = string.Split(resolvedName, " ")
    for i, part in ipairs(nameParts) do
        if part ~= "" then
            nameParts[i] = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        end
    end

    return table.concat(nameParts, " ")
end

local function ForceNavGeneration()
    if not LeadBot.CheckNavMesh then return end
    if game.SinglePlayer() then return end
    if navmesh.IsLoaded() then return end

    if sv_cheats and sv_cheats:GetInt() == 1 then
        RunConsoleCommand("nav_analyze")
        RunConsoleCommand("nav_generate")
    else
        ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
    end
end

local function GetBotName()
    local generated
    local original_name

    local customNames = SplitCSV(leadbot_names and leadbot_names:GetString() or "")
    if #customNames > 0 then
        generated = table.Random(customNames)
    else
        original_name = GetRandomModelName(true)
        generated = FormatBotName(original_name)
    end

    generated = (leadbot_name_prefix and leadbot_name_prefix:GetString() or "") .. (generated or "Leadbot")

    return LeadBot.Prefix .. generated, original_name
end

local function GetBotModel()
    return GetRandomModelName(false)
end

local function GetBotColors()
    local color = Vector(-1, -1, -1)
    local weaponcolor = Vector(0.30, 1.80, 2.10)

    local botcolor = ColorRand()
    local botweaponcolor = ColorRand()

    color = Vector(botcolor.r / 255, botcolor.g / 255, botcolor.b / 255)
    weaponcolor = Vector(botweaponcolor.r / 255, botweaponcolor.g / 255, botweaponcolor.b / 255)

    return color, weaponcolor
end

function LeadBot.AddBotOverride(bot)
    if math.random(1, 2) == 1 then
        timer.Simple(math.random(1, 4), function()
            if IsValid(bot) then
                LeadBot.TalkToMe(bot, "join")
            end
        end)
    end
end

function LeadBot.AddBotControllerOverride(bot, controller)
end

function LeadBot.AddBot()
    if player.GetCount() >= game.MaxPlayers() then
        MsgN("[LeadBot] Player limit reached!")
        return
    end

    ForceNavGeneration()

    local name, original_name = GetBotName()
    local model = original_name or GetBotModel()
    local color, weaponcolor = GetBotColors()
    local strategy = 0
    local survskill = math.random(0, 1)
    local zomskill = math.random(0, 1)
    local shootskill = survskill == 1 and math.random(8, 14) or math.random(4, 12)

    local bot = player.CreateNextBot(name)
    if not IsValid(bot) then
        MsgN("[LeadBot] Unable to create bot!")
        return
    end

    if leadbot_strategy and leadbot_strategy:GetBool() then
        strategy = math.random(0, LeadBot.Strategies)
    end

    bot.freeRoam = true

    bot.LeadBot_Config = {
        model = model,
        color = color,
        weaponcolor = weaponcolor,
        strategy = strategy,
        survskill = survskill,
        zomskill = zomskill,
        shootskill = shootskill
    }

    bot.BotStrategy = strategy
    bot.OriginalName = original_name

    EnsureZombieTemperament(bot)

    local controller = ents.Create("leadbot_navigator")
    if IsValid(controller) then
        bot.ControllerBot = controller
        controller:Spawn()
        controller:SetOwner(bot)
        LeadBot.AddBotControllerOverride(bot, controller)
    else
        bot.ControllerBot = nil
        MsgN("[LeadBot] Unable to create leadbot_navigator!")
    end

    LeadBot.AddBotOverride(bot)
end