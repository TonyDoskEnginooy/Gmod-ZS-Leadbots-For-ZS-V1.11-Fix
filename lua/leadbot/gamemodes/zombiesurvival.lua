-- This module is intended to run with ZS v1.11 Fix by Xalalau

if CLIENT then
    return
end

-- Gamemode configuration.
LeadBot.Gamemode = "zombiesurvival"
LeadBot.RespawnAllowed = true -- allows bots to respawn automatically when dead
LeadBot.PlayerColor = true -- disable this to get the default gmod style players
LeadBot.CheckNavMesh = true -- disable the nav mesh check
LeadBot.TeamPlay = true -- don't hurt players on the bots team
LeadBot.AFKBotOverride = false -- KEEP THIS FALSE OR ELSE CODE BREAKS!
LeadBot.SuicideAFK = false -- kill the player when entering/exiting afk
LeadBot.NoFlashlight = true -- disable flashlight being enabled in dark areas
LeadBot.Strategies = 3 -- how many strategies can the bot pick from

ZSB = {
    Map = {},
    Util = {},

    DEBUG = false,
    INTERMISSION = 1,
    INTERMISSION_FAKE_TIMER = 60,
    playerCSSpeed = 200
}

local HORDE_TIMER_NAME = "Hordes"
local INTERMISSION_TIMER_NAME = "INTERMISSION_MESSAGE"
local REAL_PLAYER_INITIAL_SPAWN_HOOK = "ZS_LeadBot_RealPlayerInitialSpawn"
local DEFAULT_INTERMISSION_SECONDS = 60

CreateConVar("leadbot_strategy", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enables the strategy system for newly created bots.")
CreateConVar("leadbot_names", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot names, separated by commas.")
CreateConVar("leadbot_models", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot models, separated by commas.")
CreateConVar("leadbot_name_prefix", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Bot name prefix")
CreateConVar("leadbot_minzombies", "1", {FCVAR_ARCHIVE}, "What percentage of players become zombies at the beginning.", 0, 100)

local leadbot_zchance = CreateConVar(
    "leadbot_zchance",
    "0",
    {FCVAR_ARCHIVE},
    "Whether players can spawn as zombies.",
    0,
    1
)

local leadbot_hordes = CreateConVar(
    "leadbot_hordes",
    "0",
    {FCVAR_ARCHIVE},
    "Whether to play horde mode instead of using quota.",
    0,
    1
)

CreateConVar("leadbot_hinfammo", "1", {FCVAR_ARCHIVE}, "Whether survivor bots should have infinite clip ammo.", 0, 1)
CreateConVar("leadbot_hregen", "1", {FCVAR_ARCHIVE}, "Whether survivor bots should heal when a survivor dies.", 0, 1)
CreateConVar("leadbot_zcheats", "0", {FCVAR_ARCHIVE}, "Whether zombie bots should cheat slightly.", 0, 1)
CreateConVar("leadbot_collision", "0", {FCVAR_ARCHIVE}, "Whether bots should collide with each other and others.", 0, 1)
CreateConVar("leadbot_knockback", "1", {FCVAR_ARCHIVE}, "Whether players should experience knockback.", 0, 1)

local leadbot_mapchanges = CreateConVar(
    "leadbot_mapchanges",
    "0",
    {FCVAR_ARCHIVE},
    "Whether certain map entities should be adjusted to reduce bot pathing issues.",
    0,
    1
)

CreateConVar("leadbot_cs", "0", {FCVAR_ARCHIVE}, "Whether to enable the Counter-Strike style experience.", 0, 1)
CreateConVar("leadbot_skill", "4", {FCVAR_ARCHIVE}, "Changes how good the bots' aim is. (4 = random)", 0, 4)

local zs_roundtime = GetConVar("zs_roundtime")
local zs_human_deadline = GetConVar("zs_human_deadline")

resource.AddFile("sound/intermission.mp3")

local function includeFilesInDir(dir)
    local files, dirs = file.Find(dir .. "/*", "LUA")

    for _, fileName in ipairs(files) do
        include(dir .. "/" .. fileName)
    end
end

local function resetIntermissionState()
    ZSB.INTERMISSION = 1
    ZSB.INTERMISSION_FAKE_TIMER = DEFAULT_INTERMISSION_SECONDS
end

local function createHordeTimers()
    timer.Create(HORDE_TIMER_NAME, DEFAULT_INTERMISSION_SECONDS, 0, function()
        RunConsoleCommand("leadbot_add", "1")
        ZSB.INTERMISSION = 0
    end)

    timer.Create(INTERMISSION_TIMER_NAME, 1, DEFAULT_INTERMISSION_SECONDS, function()
        PrintMessage(HUD_PRINTTALK, "Infection begins in " .. ZSB.INTERMISSION_FAKE_TIMER .. " Seconds!")
        ZSB.INTERMISSION_FAKE_TIMER = ZSB.INTERMISSION_FAKE_TIMER - 1
    end)
end

local function startHordeTimers()
    if not timer.Exists(HORDE_TIMER_NAME) or not timer.Exists(INTERMISSION_TIMER_NAME) then
        createHordeTimers()
    end

    resetIntermissionState()
    timer.Start(HORDE_TIMER_NAME)
    timer.Start(INTERMISSION_TIMER_NAME)
end

local function stopHordeTimers()
    if timer.Exists(HORDE_TIMER_NAME) then
        timer.Stop(HORDE_TIMER_NAME)
    end

    if timer.Exists(INTERMISSION_TIMER_NAME) then
        timer.Stop(INTERMISSION_TIMER_NAME)
    end

    resetIntermissionState()
end

local function shouldRedeemPlayerOnJoin()
    if leadbot_zchance:GetBool() then
        return false
    end

    if INFLICTION < 0.5 then
        return true
    end

    if not zs_roundtime or not zs_human_deadline then
        return false
    end

    return CurTime() <= (zs_roundtime:GetInt() * 0.5) and not zs_human_deadline:GetBool()
end

local function movePlayerToFixedSpawnIfNeeded(ply)
    if not leadbot_mapchanges:GetBool() then
        return
    end

    local fixedPos = ZSB.Map:GetValue("fixedPlayerSpawn")
    if fixedPos then
        ply:SetPos(fixedPos)
    end
end

function CmdKickBot(ply, _, args)
    if (IsValid(ply) and not ply:IsSuperAdmin()) or not args[1] then
        return
    end

    local query = args[1]

    if query == "all" then
        for _, bot in ipairs(player.GetBots()) do
            bot:Kick()
        end

        return
    end

    for _, bot in ipairs(player.GetBots()) do
        if string.find(bot:GetName(), query, 1, true) then
            bot:Kick()
            return
        end
    end
end

function CmdAddBot(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        return
    end

    local amount = math.max(1, math.floor(tonumber(args[1]) or 1))

    for i = 1, amount do
        timer.Simple(i * 0.1, function()
            LeadBot.AddBot()
        end)
    end
end

concommand.Add("leadbot_add", CmdAddBot, nil, "Adds a LeadBot")
concommand.Add("leadbot_kick", CmdKickBot, nil, "Kicks LeadBots. Use 'all' to kick every bot.")

include("zs/sv/map_handler.lua")
include("zs/sv/player_meta.lua")
include("zs/sv/util.lua")
include("zs/sv/timer.lua")
include("zs/sv/add_bot.lua")
includeFilesInDir("leadbot/gamemodes/zs/sv/behavior")
include("zs/sv/behavior_hook.lua")

cvars.AddChangeCallback("leadbot_quota", function(_, oldValue, newValue)
    oldValue = tonumber(oldValue)
    newValue = tonumber(newValue)

    if oldValue and newValue and oldValue > 0 and newValue < 1 then
        RunConsoleCommand("leadbot_kick", "all")
    end
end)

function ZSB.InitPostEntity()
    if leadbot_hordes:GetBool() then
        createHordeTimers()
    end

    ZSB.Map.Init()

    if timer.Exists("zombieNearDetector") then
        timer.Start("zombieNearDetector")
    end

    if timer.Exists("zombieStuckDetector") then
        timer.Start("zombieStuckDetector")
    end
end

hook.Add("PlayerInitialSpawn", REAL_PLAYER_INITIAL_SPAWN_HOOK, function(ply)
    if not IsValid(ply) or ply:IsBot() then
        return
    end

    if shouldRedeemPlayerOnJoin() then
        timer.Simple(2, function()
            if not IsValid(ply) then
                return
            end

            ply:Redeem()
            movePlayerToFixedSpawnIfNeeded(ply)
        end)
    end

    if leadbot_hordes:GetBool() and player.GetCount() == 1 then
        ply:EmitSound("intermission.mp3", CHAN_REPLACE)
        startHordeTimers()
        return
    end

    if not leadbot_hordes:GetBool() and player.GetCount() >= 1 then
        stopHordeTimers()
    end
end)
