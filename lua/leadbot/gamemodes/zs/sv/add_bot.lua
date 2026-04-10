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

-- Cache cvars
local leadbot_names = GetConVar("leadbot_names")
local leadbot_models = GetConVar("leadbot_models")
local leadbot_name_prefix = GetConVar("leadbot_name_prefix")
local leadbot_strategy = GetConVar("leadbot_strategy")
local sv_cheats = GetConVar("sv_cheats")

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
    if LeadBot.PlayerColor == "default" then
        return "kleiner"
    end

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

    if LeadBot.PlayerColor == "default" then
        original_name = "kleiner"
        generated = "Kleiner"
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

    if LeadBot.PlayerColor ~= "default" then
        local botcolor = ColorRand()
        local botweaponcolor = ColorRand()

        color = Vector(botcolor.r / 255, botcolor.g / 255, botcolor.b / 255)
        weaponcolor = Vector(botweaponcolor.r / 255, botweaponcolor.g / 255, botweaponcolor.b / 255)
    else
        color = Vector(0.24, 0.34, 0.41)
    end

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
    local shootskill = math.random(4, 16)

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