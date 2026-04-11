util.AddNetworkString("botVoiceStart")

LeadBot.VoicePreset = LeadBot.VoicePreset or {}
LeadBot.VoiceModels = LeadBot.VoiceModels or {}

local convar
local VOICE_CHANNEL = CHAN_VOICE or CHAN_AUTO
local VOICE_SOUND_LEVEL = 95
local VOICE_VOLUME = 1
local VOICE_DSP = 1
local BOT_VOICE_MAX_DISTANCE = 700
local BOT_VOICE_MAX_DISTANCE_SQR = BOT_VOICE_MAX_DISTANCE * BOT_VOICE_MAX_DISTANCE

local VOICE_TYPE_FALLBACKS = {
    join = {"join"},
    taunt = {"taunt"},
    help = {"help", "pain"},
    downed = {"downed", "help", "pain"},
    pain = {"pain", "help"}
}

local VOICE_TYPE_COOLDOWNS = {
    join = 0,
    taunt = 2.75,
    help = 6,
    downed = 0.75,
    pain = 2.25
}

local GLOBAL_VOICE_COOLDOWN = 0.85

local function GetAvailableVoicePresetNames()
    local names = table.GetKeys(LeadBot.VoicePreset)
    table.sort(names)
    return names
end

local function BuildVoicePresetHelpText()
    local names = GetAvailableVoicePresetNames()

    if #names == 0 then
        return [[Voice Preset.
Options are:
- "random"
- ""]]
    end

    return [[Voice Preset.
Options are:
- "random"
- "]] .. table.concat(names, [["
- "]]) .. [["
- ""]]
end

local function GetBotVoiceKey(ply)
    if not IsValid(ply) or not ply.IsLBot or not ply:IsLBot(true) then
        return nil
    end

    local voiceCvarValue = convar and convar:GetString() or "random"

    if voiceCvarValue == "" then
        return nil
    end

    if voiceCvarValue ~= "random" then
        if LeadBot.VoicePreset[voiceCvarValue] then
            return voiceCvarValue
        end

        return "metropolice"
    end

    if not ply.LeadBot_Voice then
        local botName = ply:Nick()
        local mappedVoice = LeadBot.VoiceModels[botName]

        if mappedVoice and LeadBot.VoicePreset[mappedVoice] then
            ply.LeadBot_Voice = mappedVoice
        else
            local _, randomVoiceKey = table.Random(LeadBot.VoicePreset)
            ply.LeadBot_Voice = randomVoiceKey or "metropolice"
        end
    end

    if not LeadBot.VoicePreset[ply.LeadBot_Voice] then
        ply.LeadBot_Voice = "metropolice"
    end

    return ply.LeadBot_Voice
end

local function CanListenerReceiveBotVoice(listener, talker)
    if not IsValid(listener) or not listener:IsPlayer() then return false end
    if not IsValid(talker) or not talker:IsPlayer() then return false end

    local canHear = hook.Call("PlayerCanHearPlayersVoice", gmod.GetGamemode(), listener, talker)
    if not canHear then
        return false
    end

    local listenerPos = listener:GetPos()
    local talkerPos = talker:GetPos()
    if not listenerPos or not talkerPos then
        return false
    end

    local maxDistanceSqr = BOT_VOICE_MAX_DISTANCE_SQR or (700 * 700)
    local distanceSqr = listenerPos:DistToSqr(talkerPos)

    if not distanceSqr then
        return false
    end

    return distanceSqr <= maxDistanceSqr
end


local function GetVoiceListeners(talker)
    local listeners = {}

    for _, listener in ipairs(player.GetAll()) do
        if CanListenerReceiveBotVoice(listener, talker) then
            listeners[#listeners + 1] = listener
        end
    end

    return listeners
end

local function BuildVoiceRecipientFilter(listeners)
    local filter = RecipientFilter()

    for _, listener in ipairs(listeners) do
        if IsValid(listener) then
            filter:AddPlayer(listener)
        end
    end

    return filter
end

local function ResolveVoiceType(voiceKey, voiceType)
    if not voiceType then
        return nil
    end

    local preset = LeadBot.VoicePreset[voiceKey]
    if not preset then
        return nil
    end

    for _, candidateType in ipairs(VOICE_TYPE_FALLBACKS[voiceType] or {voiceType}) do
        local lines = preset[candidateType]

        if istable(lines) and #lines > 0 then
            return candidateType
        end
    end

    return nil
end

local function GetVoiceLine(voiceKey, resolvedType)
    if not resolvedType then
        return ""
    end

    local preset = LeadBot.VoicePreset[voiceKey]
    if not preset then
        return ""
    end

    local lines = preset[resolvedType]
    if not istable(lines) or #lines == 0 then
        return ""
    end

    return string.Trim(table.Random(lines) or "")
end

local function CanPlayVoiceType(ply, resolvedType)
    local curTime = CurTime()

    if (ply.LeadBotNextVoiceTime or 0) > curTime then
        return false
    end

    ply.LeadBotNextVoiceByType = ply.LeadBotNextVoiceByType or {}

    return (ply.LeadBotNextVoiceByType[resolvedType] or 0) <= curTime
end

local function MarkVoiceCooldowns(ply, resolvedType, duration)
    local curTime = CurTime()
    local lockout = math.max(duration or 0, GLOBAL_VOICE_COOLDOWN)

    ply.LeadBotNextVoiceTime = curTime + lockout
    ply.LeadBotNextVoiceByType = ply.LeadBotNextVoiceByType or {}
    ply.LeadBotNextVoiceByType[resolvedType] = curTime + math.max(lockout, VOICE_TYPE_COOLDOWNS[resolvedType] or 0)
end

local function EmitVoiceState(listeners, ply, duration)
    net.Start("botVoiceStart")
        net.WriteEntity(ply)
        net.WriteFloat(math.max(duration or 0, 0))
    net.Send(listeners)
end

function LeadBot.TalkToMe(ply, voiceType)
    if not IsValid(ply) or not ply.IsLBot or not ply:IsLBot(true) then
        return false
    end

    local voiceKey = GetBotVoiceKey(ply)
    if not voiceKey then
        return false
    end

    local resolvedType = ResolveVoiceType(voiceKey, voiceType)
    if not resolvedType then
        return false
    end

    if not CanPlayVoiceType(ply, resolvedType) then
        return false
    end

    local listeners = GetVoiceListeners(ply)
    if #listeners == 0 then
        return false
    end

    local soundPath = GetVoiceLine(voiceKey, resolvedType)
    if soundPath == "" then
        return false
    end

    local filter = BuildVoiceRecipientFilter(listeners)
    local pitch = math.random(95, 105)
    local duration = SoundDuration(soundPath) or 0

    MarkVoiceCooldowns(ply, resolvedType, duration)
    ply:EmitSound(soundPath, VOICE_SOUND_LEVEL, pitch, VOICE_VOLUME, VOICE_CHANNEL, 0, VOICE_DSP, filter)
    EmitVoiceState(listeners, ply, duration)

    return true
end

function LeadBot.TryTalkToMe(ply, voiceType)
    return LeadBot.TalkToMe(ply, voiceType)
end

-- Valve Games

if IsMounted("cstrike") then
    LeadBot.VoicePreset["css"] = {}
    LeadBot.VoicePreset["css"]["join"] = {"bot/its_a_party.wav", "bot/oh_boy2.wav", "bot/whoo.wav"}
    LeadBot.VoicePreset["css"]["taunt"] = {"bot/do_not_mess_with_me.wav", "bot/i_am_dangerous.wav", "bot/i_am_on_fire.wav", "bot/i_wasnt_worried_for_a_minute.wav", "bot/nice2.wav", "bot/owned.wav", "bot/made_him_cry.wav", "bot/they_never_knew_what_hit_them.wav", "bot/who_wants_some_more.wav", "bot/whos_the_man.wav", "bot/yea_baby.wav", "bot/wasted_him.wav"}
    LeadBot.VoicePreset["css"]["help"] = {"bot/help.wav", "bot/i_could_use_some_help.wav", "bot/i_could_use_some_help_over_here.wav", "bot/im_in_trouble.wav", "bot/need_help.wav", "bot/need_help2.wav", "bot/the_actions_hot_here.wav"}
    LeadBot.VoicePreset["css"]["downed"] = LeadBot.VoicePreset["css"]["help"]
end

-- Citizens

LeadBot.VoicePreset["male"] = {}
LeadBot.VoicePreset["male"]["join"] = {"vo/npc/male01/hi01.wav", "vo/npc/male01/hi02.wav", "vo/npc/male01/yeah02.wav", "vo/npc/male01/squad_reinforce_single04.wav", "vo/npc/male01/squad_affirm06.wav", "vo/npc/male01/readywhenyouare01.wav", "vo/npc/male01/okimready03.wav", "vo/npc/male01/letsgo02.wav"}
LeadBot.VoicePreset["male"]["taunt"] = {"vo/coast/odessa/male01/nlo_cheer03.wav", "vo/npc/male01/gotone02.wav", "vo/npc/male01/likethat.wav", "vo/npc/male01/nice01.wav", "vo/npc/male01/question17.wav", "vo/npc/male01/yeah02.wav", "vo/npc/male01/vquestion01.wav"}
LeadBot.VoicePreset["male"]["pain"] = {"vo/npc/male01/help01.wav", "vo/npc/male01/startle01.wav", "vo/npc/male01/startle02.wav", "vo/npc/male01/uhoh.wav"}

LeadBot.VoicePreset["female"] = {}
LeadBot.VoicePreset["female"]["join"] = {"vo/npc/female01/hi01.wav", "vo/npc/female01/hi02.wav", "vo/npc/female01/yeah02.wav", "vo/npc/female01/squad_reinforce_single04.wav", "vo/npc/female01/squad_affirm06.wav", "vo/npc/female01/readywhenyouare01.wav", "vo/npc/female01/okimready03.wav", "vo/npc/female01/letsgo02.wav"}
LeadBot.VoicePreset["female"]["taunt"] = {"vo/coast/odessa/female01/nlo_cheer03.wav", "vo/npc/female01/gotone02.wav", "vo/npc/female01/likethat.wav", "vo/npc/female01/nice01.wav", "vo/npc/female01/question17.wav", "vo/npc/female01/yeah02.wav", "vo/npc/female01/vquestion01.wav"}
LeadBot.VoicePreset["female"]["pain"] = {"vo/npc/female01/help01.wav", "vo/npc/female01/startle01.wav", "vo/npc/female01/startle02.wav", "vo/npc/female01/uhoh.wav"}

-- Main Characters

LeadBot.VoicePreset["alyx"] = {}
LeadBot.VoicePreset["alyx"]["join"] = {"vo/npc/alyx/al_excuse03.wav", "vo/npc/alyx/getback01.wav", "vo/npc/alyx/lookout01.wav", "vo/npc/alyx/getback02.wav"}
LeadBot.VoicePreset["alyx"]["taunt"] = {"vo/npc/alyx/al_excuse03.wav", "vo/npc/alyx/lookout01.wav", "vo/npc/alyx/lookout03.wav", "vo/npc/alyx/brutal02.wav", "vo/npc/alyx/youreload02.wav"}
LeadBot.VoicePreset["alyx"]["pain"] = {"vo/npc/alyx/gasp03.wav", "vo/npc/alyx/ohgod01.wav", "vo/npc/alyx/ohno_startle01.wav"}

LeadBot.VoicePreset["barney"] = {}
LeadBot.VoicePreset["barney"]["join"] = {"vo/npc/barney/ba_ohyeah.wav", "vo/npc/barney/ba_yell.wav", "vo/npc/barney/ba_bringiton.wav"}
LeadBot.VoicePreset["barney"]["taunt"] = {"vo/npc/barney/ba_downyougo.wav", "vo/npc/barney/ba_losttouch.wav", "vo/npc/barney/ba_yell.wav", "vo/npc/barney/ba_getaway.wav"}
LeadBot.VoicePreset["barney"]["help"] = {"vo/npc/barney/ba_no01.wav", "vo/npc/barney/ba_no02.wav", "vo/npc/barney/ba_damnit.wav"}

LeadBot.VoicePreset["grigori"] = {}
LeadBot.VoicePreset["grigori"]["join"] = {"vo/ravenholm/monk_death07.wav", "vo/ravenholm/exit_nag02.wav", "vo/ravenholm/engage04.wav", "vo/ravenholm/engage05.wav", "vo/ravenholm/engage06.wav", "vo/ravenholm/engage07.wav", "vo/ravenholm/engage08.wav", "vo/ravenholm/engage09.wav"}
LeadBot.VoicePreset["grigori"]["taunt"] = {"vo/ravenholm/madlaugh01.wav", "vo/ravenholm/madlaugh02.wav", "vo/ravenholm/madlaugh03.wav", "vo/ravenholm/madlaugh04.wav", "vo/ravenholm/monk_kill01.wav", "vo/ravenholm/monk_kill02.wav", "vo/ravenholm/monk_kill03.wav", "vo/ravenholm/monk_kill04.wav", "vo/ravenholm/monk_kill05.wav", "vo/ravenholm/monk_kill06.wav", "vo/ravenholm/monk_kill07.wav", "vo/ravenholm/monk_kill08.wav", "vo/ravenholm/monk_kill09.wav", "vo/ravenholm/firetrap_vigil.wav"}
LeadBot.VoicePreset["grigori"]["pain"] = {"vo/ravenholm/monk_pain12.wav", "vo/ravenholm/monk_rant13.wav", "vo/ravenholm/monk_pain06.wav", "vo/ravenholm/engage08.wav"}

-- Enemies

LeadBot.VoicePreset["metropolice"] = {}
LeadBot.VoicePreset["metropolice"]["join"] = {"npc/metropolice/vo/lookingfortrouble.wav", "npc/metropolice/vo/pickupthecan1.wav", "npc/metropolice/vo/youwantamalcomplianceverdict.wav", "npc/metropolice/vo/unitisonduty10-8.wav", "npc/metropolice/vo/unitis10-8standingby.wav", "npc/metropolice/vo/readytoamputate.wav", "npc/metropolice/vo/prepareforjudgement.wav", "npc/metropolice/vo/readytoprosecutefinalwarning.wav"}
LeadBot.VoicePreset["metropolice"]["taunt"] = {"npc/metropolice/vo/finalverdictadministered.wav", "npc/metropolice/vo/firstwarningmove.wav", "npc/metropolice/vo/isaidmovealong.wav", "npc/metropolice/vo/nowgetoutofhere.wav", "npc/metropolice/vo/pickupthecan2.wav", "npc/metropolice/vo/pickupthecan3.wav", "npc/metropolice/vo/putitinthetrash1.wav", "npc/metropolice/vo/putitinthetrash2.wav", "npc/metropolice/vo/suspectisbleeding.wav", "npc/metropolice/vo/thisisyoursecondwarning.wav"}
LeadBot.VoicePreset["metropolice"]["pain"] = {"npc/metropolice/vo/11-99officerneedsassistance.wav", "npc/metropolice/vo/wehavea10-108.wav", "npc/metropolice/vo/runninglowonverdicts.wav", "npc/metropolice/pain4.wav"}

-- Player Config

LeadBot.VoiceModels["Alyx Vance"] = "alyx"
LeadBot.VoiceModels["BuizBuben241"] = "male"
LeadBot.VoiceModels["Dr. Wallace Breen"] = "male"
LeadBot.VoiceModels["The G-Man"] = "male"
LeadBot.VoiceModels["Odessa Cubbage"] = "male"
LeadBot.VoiceModels["Eli Vance"] = "male"
LeadBot.VoiceModels["Father Grigori"] = "grigori"
LeadBot.VoiceModels["Judith Mossman"] = "female"
LeadBot.VoiceModels["Bushe"] = "female"
LeadBot.VoiceModels["Barney Calhoun"] = "barney"

LeadBot.VoiceModels["Magnusson"] = "male"

LeadBot.VoiceModels["Boldier"] = "male"
LeadBot.VoiceModels["German Soldier"] = "male"

LeadBot.VoiceModels["GIGN"] = "css"
LeadBot.VoiceModels["Elite Crew"] = "css"
LeadBot.VoiceModels["Artic Avengers"] = "css"
LeadBot.VoiceModels["SEAL Team Six"] = "css"
LeadBot.VoiceModels["GSG-9"] = "css"
LeadBot.VoiceModels["SAS"] = "css"
LeadBot.VoiceModels["Phoenix Connexion"] = "css"
LeadBot.VoiceModels["Guerilla Warfare"] = "css"
LeadBot.VoiceModels["Cohrt"] = "male"

LeadBot.VoiceModels["Chell"] = "female"

LeadBot.VoiceModels["Civil Protection"] = "metropolice"
LeadBot.VoiceModels["Civil Erection"] = "metropolice"
LeadBot.VoiceModels["Combine Soldier"] = "metropolice"
LeadBot.VoiceModels["Combine Prison Guard"] = "metropolice"
LeadBot.VoiceModels["Bony Bosk Benginooy"] = "metropolice"
LeadBot.VoiceModels["Stripped Combine Soldier"] = "metropolice"

LeadBot.VoiceModels["Zombie"] = "css"
LeadBot.VoiceModels["Fast Zombie"] = "css"
LeadBot.VoiceModels["Zombine"] = "css"
LeadBot.VoiceModels["Corpse"] = "css"
LeadBot.VoiceModels["Charple"] = "css"
LeadBot.VoiceModels["BiversRox"] = "css"

LeadBot.VoiceModels["Van"] = "male"
LeadBot.VoiceModels["Pan"] = "male"
LeadBot.VoiceModels["Ted"] = "male"
LeadBot.VoiceModels["Joe"] = "male"
LeadBot.VoiceModels["Eric"] = "male"
LeadBot.VoiceModels["Art"] = "male"
LeadBot.VoiceModels["Sandro"] = "male"
LeadBot.VoiceModels["Mike"] = "male"
LeadBot.VoiceModels["Vance"] = "male"
LeadBot.VoiceModels["Erdin"] = "male"
LeadBot.VoiceModels["Dan"] = "male"
LeadBot.VoiceModels["Fed"] = "male"
LeadBot.VoiceModels["Bed"] = "male"
LeadBot.VoiceModels["Led"] = "male"
LeadBot.VoiceModels["Poe"] = "male"
LeadBot.VoiceModels["Deric"] = "male"
LeadBot.VoiceModels["Pric"] = "male"
LeadBot.VoiceModels["Leric"] = "male"
LeadBot.VoiceModels["Tart"] = "male"
LeadBot.VoiceModels["Fart"] = "male"
LeadBot.VoiceModels["Bart"] = "male"
LeadBot.VoiceModels["Mandro"] = "male"
LeadBot.VoiceModels["Candro"] = "male"
LeadBot.VoiceModels["Fandro"] = "male"
LeadBot.VoiceModels["Landro"] = "male"
LeadBot.VoiceModels["Like"] = "male"
LeadBot.VoiceModels["Pike"] = "male"
LeadBot.VoiceModels["Dance"] = "male"
LeadBot.VoiceModels["Prance"] = "male"
LeadBot.VoiceModels["Yance"] = "male"
LeadBot.VoiceModels["Lance"] = "male"
LeadBot.VoiceModels["Ferdin"] = "male"
LeadBot.VoiceModels["Sherdin"] = "male"
LeadBot.VoiceModels["Joey"] = "female"
LeadBot.VoiceModels["Kanisha"] = "female"
LeadBot.VoiceModels["Kim"] = "female"
LeadBot.VoiceModels["Chau"] = "female"
LeadBot.VoiceModels["Naomi"] = "female"
LeadBot.VoiceModels["Lakeetra"] = "female"
LeadBot.VoiceModels["Boey"] = "female"
LeadBot.VoiceModels["Moey"] = "female"
LeadBot.VoiceModels["Kanisha"] = "female"
LeadBot.VoiceModels["Jim"] = "female"
LeadBot.VoiceModels["Tim"] = "female"
LeadBot.VoiceModels["Chow"] = "female"
LeadBot.VoiceModels["Cow"] = "female"
LeadBot.VoiceModels["Naomi"] = "female"
LeadBot.VoiceModels["Satochi"] = "female"
LeadBot.VoiceModels["Natsuke"] = "female"
LeadBot.VoiceModels["LackEatTra"] = "female"
LeadBot.VoiceModels["Moqueefa"] = "female"
LeadBot.VoiceModels["Latisha"] = "female"
LeadBot.VoiceModels["Lackee"] = "female"

local function EnsureVoiceAlias(voiceKey, targetType, sourceType)
    local preset = LeadBot.VoicePreset[voiceKey]
    if not preset then
        return
    end

    local target = preset[targetType]
    if istable(target) and #target > 0 then
        return
    end

    local source = preset[sourceType]
    if istable(source) and #source > 0 then
        preset[targetType] = table.Copy(source)
    end
end

local function FinalizeVoicePresets()
    local presetNames = table.GetKeys(LeadBot.VoicePreset)

    for _, voiceKey in ipairs(presetNames) do
        EnsureVoiceAlias(voiceKey, "help", "pain")
        EnsureVoiceAlias(voiceKey, "downed", "help")
        EnsureVoiceAlias(voiceKey, "downed", "pain")
        EnsureVoiceAlias(voiceKey, "pain", "help")
    end
end

FinalizeVoicePresets()

convar = CreateConVar(
    "leadbot_voice",
    "random",
    {FCVAR_ARCHIVE},
    BuildVoicePresetHelpText()
)
