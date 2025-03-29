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

local function ForceNavGeneration()
    if LeadBot.CheckNavMesh and not game.SinglePlayer() and not navmesh.IsLoaded() then
        if GetConVar("sv_cheats"):GetInt() == 1 then
            RunConsoleCommand("nav_analyze")
            RunConsoleCommand("nav_generate")
        else
            ErrorNoHalt("There is no navmesh! Generate one using \"nav_generate\"!\n")
        end
    end
end

local function GetBotName()
    local original_name

    if leadbot_names:GetString() ~= "" then
        generated = table.Random(string.Split(leadbot_names:GetString(), ","))
    elseif leadbot_models:GetString() == "" then
        local name, _ = table.Random(player_manager.AllValidModels())
        local translate = player_manager.TranslateToPlayerModelName(name)
        name = translate

        for _, ply in ipairs(player.GetBots()) do
            if ply.OriginalName == name or string.lower(ply:Nick()) == name or defaultBotNames[name] and ply:Nick() == defaultBotNames[name] then
                name = ""
            end
        end

        if name == "" then
            local i = 0
            while name == "" do
                i = i + 1
                local str = player_manager.TranslateToPlayerModelName(table.Random(player_manager.AllValidModels()))
                for _, ply in ipairs(player.GetBots()) do
                    if ply.OriginalName == str or string.lower(ply:Nick()) == str or defaultBotNames[str] and ply:Nick() == defaultBotNames[str] then
                        str = ""
                    end
                end

                if str == "" and i < #player_manager.AllValidModels() then continue end
                name = str
            end
        end

        original_name = name
        name = string.lower(name)
        name = defaultBotNames[name] or name

        local name_Generated = string.Split(name, "/")
        name_Generated = name_Generated[#name_Generated]
        name_Generated = string.Split(name_Generated, " ")

        for i, namestr in ipairs(name_Generated) do
            name_Generated[i] = string.upper(string.sub(namestr, 1, 1)) .. string.sub(namestr, 2)
        end

        name_Generated = table.concat(name_Generated, " ")
        generated = name_Generated
    end

    if LeadBot.PlayerColor == "default" then
        generated = "Kleiner"
    end

    generated = leadbot_name_prefix:GetString() .. generated

    local name = LeadBot.Prefix .. generated

    return name, original_name
end

local function GetBotModel()
    local model = ""

    if LeadBot.PlayerColor ~= "default" then
        if model == "" then
            if leadbot_models:GetString() ~= "" then
                model = table.Random(string.Split(leadbot_models:GetString(), ","))
            else
                model = player_manager.TranslateToPlayerModelName(table.Random(player_manager.AllValidModels()))
            end
        end
    else
        model = "kleiner"
    end

    return model
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
            LeadBot.TalkToMe(bot, "join")
        end)
    end
end

function LeadBot.AddBotControllerOverride(bot, controller)
end

function LeadBot.AddBot()
    if player.GetCount() == game.MaxPlayers() then
        MsgN("[LeadBot] Player limit reached!")
        return
    end

    ForceNavGeneration()

    local generated = "Leadbot #" .. #player.GetBots() + 1
    local name, original_name = GetBotName()
    local model = original_name or GetBotModel()
    local color, weaponcolor = GetBotColors()
    local strategy = 0
    local survskill = math.random(0, 1)
    local zomskill = math.random(0, 1)
    local shootskill = math.random(4, 16)

    local bot = player.CreateNextBot(name)

    if !IsValid(bot) then
        MsgN("[LeadBot] Unable to create bot!")
        return
    end

    if leadbot_strategy:GetBool() then
        strategy = math.random(0, LeadBot.Strategies)
    end

    bot.freeRoam = true
    bot.LeadBot_Config = { model, color, weaponcolor, strategy, survskill, zomskill, shootskill }

    -- for legacy purposes, will be removed soon when gamemodes are updated
    bot.BotStrategy = strategy
    bot.OriginalName = original_name
    bot.ControllerBot = ents.Create("leadbot_navigator")
    bot.ControllerBot:Spawn()
    bot.ControllerBot:SetOwner(bot)
    LeadBot.AddBotOverride(bot)
    LeadBot.AddBotControllerOverride(bot, bot.ControllerBot)
end