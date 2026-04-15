local mapName = game.GetMap()

ZSB.Map.default = {
    survivorBreak = false,
    survivorBoxBreak = false,
    zombiePropCheck = true,
    zombieBreakCheck = true,
    removePropDoorRotating = false,
    removeFuncDoorRotating = false,
    removeFuncUseableladder = false,
    removeFuncBreakable = false,
    removeFuncPhysbox = false,
    removeFuncPhysboxFilter = function(...) end,
    removeFuncBreakableFilter = function(...) end,
    forceEnableMotion = false,
    removePropPhysicsList = { -- Is it really needed on all maps?
        ["models/combine_apc.mdl"] = true,
        ["models/props_junk/vent001.mdl"] = true,
        ["models/props/cs_militia/refrigerator01.mdl"] = true
    },
    botBarrierList = {},
    campingSpotList= {},
    fixedPlayerSpawn = function(...) end,
    fixedZombieSpawn = function(...) end,
    eyeAngles = function(...) end
}

-- campingSpotList and eyeAngles need 3 entries each, they are the base of the map strategies
ZSB.Map.handler = {
    zs_overandunderground_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        removeFuncPhysboxFilter = function(v)
            local modelName = v:GetModel()
            return modelName == "*170" or modelName == "*169" or modelName == "*35" or modelName == "*34" or modelName == "*71" or modelName == "*22" 
        end,
        removePropPhysicsList = table.Merge({
            ["models/props_debris/metal_panel01a.mdl"] = true
        }, ZSB.Map.default.removePropPhysicsList),
        campingSpotList = { Vector(-490.96, 3106.96, -55.96), Vector(-42.84, 2375.03, 80.03), Vector(-102.80, 3071.96, 216.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + doorVar, 90 + doorVar, 315 + openVar })[strategy], 0) end
    },
    zs_embassy = {
        survivorBreak = true,
        survivorBoxBreak = true,
        removeFuncBreakable = true,
        removeFuncPhysbox = true,
        removeFuncPhysboxFilter = function(v) return v:Health() > 1 end,
        campingSpotList = { Vector(383.91, -1092.83, 122.03), Vector(-278.96, -1260.96, 280.03), Vector(1148.92, -1234.33, 280.02) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 90 + hallVar, 270 + doorVar })[strategy], 0) end
    },
    zs_buntshot = {
        survivorBreak = true,
        zombiePropCheck = false,
        campingSpotList = { Vector(336.74, 726.40, -375.64), Vector(297.20, 840.50, -375.96), Vector(-1071.96, -915.18, -167.64) },
        fixedPlayerSpawn = function() return Vector(550.256470 + math.random(-25, 25), -595.521240 + math.random(-25, 25), -203.968750) end,
        fixedZombieSpawn = function() return Vector(550.256470 + math.random(-25, 25), -595.521240 + math.random(-25, 25), -203.968750) end,
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + hallVar, 180 + hallVar, 270 + hallVar })[strategy], 0) end
    },
    zs_termites_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        forceEnableMotion = true,
        campingSpotList = { Vector(207.74, 152.17, 8.03), Vector(16.58, 175.96, 200.03), Vector(211.73, 175.96, 200.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + doorVar, 270 + doorVar, 270 + doorVar })[strategy], 0) end
    },
    zs_pub = {
        survivorBreak = true,
        zombieBreakCheck = false,
        removeFuncBreakable = true,
        campingSpotList = { Vector(-648.74, 298.96, 41.03), Vector(-411.03, -45.96, 196.03), Vector(-750.57, 451.99, 196.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 135 + openVar, 270 + hallVar })[strategy], 0) end
    },
    zs_bog_shityhouse = {
        survivorBreak = true,
        campingSpotList = { Vector(-800.40, 1085.99, 177.03), Vector(-758.03, 890.73, 177.03), Vector(-802.42, 802.33, 178.33) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 180 + doorVar, 180 + doorVar, 270 + doorVar })[strategy], 0) end
    },
    zs_ancient_castle_opt = {
        survivorBreak = true,
        campingSpotList = { Vector(187.44, 2143.96, 73.03), Vector(-670.90, 656.01, 73.03), Vector(-73.24, 2143.96, 73.39) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 90 + doorVar, 270 + doorVar })[strategy], 0) end
    },
    zs_deadblock_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        campingSpotList = { Vector(900.19, -821.84, 72.03), Vector(1104.31, 1027.96, 81.03), Vector(1023.69, 2019.71, -54.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 270 + hallVar, 180 + hallVar })[strategy], 0) end
    },
    zs_gu_frostbite_v2 = {
        survivorBreak = true,
        campingSpotList = { Vector(-1181.79, 720.03, 458.78), Vector(-1434.27, 181.03, 212.03), Vector(-1190.61, 176.03, 213.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 90 + hallVar, 90 + doorVar })[strategy], 0) end
    },
    zs_house_outbreak_b2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        campingSpotList = { Vector(-112.03, -141.96, -107.96), Vector(-173.72, -141.96, -107.96), Vector(-231.96, -141.96, -107.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 45 + openVar, 90 + hallVar, 90 + doorVar })[strategy], 0) end
    },
    zs_imashouse_b2 = {
        survivorBreak = true,
        removePropPhysicsList = table.Merge({
            ["models/props_debris/wood_board04a.mdl"] = true
        }, ZSB.Map.default.removePropPhysicsList),
        campingSpotList = { Vector(257.78, 704.61, 55.03), Vector(-250.97, 967.96, -80.96), Vector(-16.03, 114.03, -216.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 135 + openVar, 270 + doorVar, 270 + hallVar })[strategy], 0) end
    },
    zs_port_v5 = {
        zombiePropCheck = false,
        campingSpotList = { Vector(-1267.96, 2268.49, -1131.96), Vector(791.22, 2359.96, -1015.96), Vector(145.95, 2538.18, -1141.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + doorVar, 270 + hallVar, 0 + doorVar })[strategy], 0) end
    },
    zs_bunkerhouse = {
        zombiePropCheck = false,
        campingSpotList = { Vector(200.51, 607.97, 8.03), Vector(-679.96, 602.92, -135.96), Vector(-272.03, 465.92, -543.69) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 180 + hallVar, 0 + doorVar, 270 + doorVar })[strategy], 0) end
    },
    zs_ascent = {
        zombieBreakCheck = false,
        campingSpotList = { Vector(-991.96, 991.96, -55.46), Vector(-33.28, -10.53, 10.16), Vector(38.76, 3.00, 8.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + doorVar, 180 + hallVar, 315 + openVar })[strategy], 0) end
    },
    zs_nastierhouse_v3 = {
        zombieBreakCheck = false,
        campingSpotList = { Vector(-295.97, -1042.08, -887.96), Vector(281.12, -1383.96, -887.96), Vector(-231.97, -993.60, -1015.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + hallVar, 90 + doorVar, 0 + hallVar })[strategy], 0) end
    },
    zs_jail_v1 = {
        removePropDoorRotating = false,
        removeFuncPhysbox = true,
        campingSpotList = { Vector(-32.02, 387.61, 152.03), Vector(-96.16, 2086.96, 8.03), Vector(-367.96, -1343.25, 8.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + hallVar, 270 + hallVar, 180 + hallVar })[strategy], 0) end
    },
    zs_placid = {
        removePropDoorRotating = false,
        campingSpotList = { Vector(-4351.96, 32.03, 76.03), Vector(-3832.02, 292.06, 212.74), Vector(-4067.96, 24.03, 212.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 45 + openVar, 180 + hallVar, 45 + openVar })[strategy], 0) end
    },
    zs_lila_panic_v3 = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-1167.96, -879.03, -263.96), Vector(-1150.79, -480.03, -263.96), Vector(1244.16, -1199.63, 14.63) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 180 + hallVar, 270 + hallVar, 0 + openVar })[strategy], 0) end
    },
    zs_house_number_23 = {
        removeFuncBreakable = true,
        removeFuncPhysbox = true,
        campingSpotList = { Vector(534.03, 26.83, 216.03), Vector(938.99, -365.96, 216.03), Vector(586.66, -469.42, 216.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + doorVar, 90 + doorVar, 0 + hallVar })[strategy], 0) end
    },
    zs_mall_dl = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-1750.00, 224.03, -1375.96), Vector(-2520.03, 1086.48, -1375.96), Vector(-2235.70, 512.01, -1583.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + doorVar, 180 + hallVar, 90 + hallVar })[strategy], 0) end
    },
    zs_fen = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-127.91, 18.03, 144.03), Vector(167.96, 361.54, 144.03), Vector(-503.96, 367.21, 144.97) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + doorVar, 180 + doorVar, 90 + doorVar })[strategy], 0) end
    },
    zs_the_pub_beta1 = {
        removeFuncPhysbox = true,
        removeFuncPhysboxFilter = function(v) return v:GetModel() == "*46" or v:GetModel() == "*47" end,
        campingSpotList = { Vector(375.96, 1338.85, 136.03), Vector(-346.06, 896.03, 136.03), Vector(3254.96, -3183.96, 1.10) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 135 + openVar, 90 + doorVar, 180 + hallVar })[strategy], 0) end
    },
    zs_panic_house_v2 = {
        removePropPhysicsList = table.Merge({
            ["models/props_debris/wood_board06a.mdl"] = true
        }, ZSB.Map.default.removePropPhysicsList),
        campingSpotList = { Vector(-852.89, -354.96, 44.42), Vector(-848.92, 241.24, -336.70), Vector(-978.40, -106.28, -88.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + doorVar, 0 + hallVar, 90 + doorVar })[strategy], 0) end
    },
    zs_snow = {
        botBarrierList = {
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(-125.453964, 250.133347, -293.968750),
                ang = Angle(0, 90, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(-224.436020, 1804.177734, -551.968750),
                ang = Angle(0, 90, 0)
            }
        },
        campingSpotList = { Vector(-432.84, 948.03, -607.96), Vector(174.03, 980.48, -597.03), Vector(-545.53, 1121.32, -223.96) },
        fixedPlayerSpawn = function() return Vector(-566.444092 + math.random(-25, 25), 1023.660217 + math.random(-25, 25), -38.856033) end,
        fixedZombieSpawn = function() return Vector(-154.754593 + math.random(-25, 25), 1325.260010 + math.random(-25, 25), -571.968750) end,
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + doorVar, 112.5 + hallVar, 90 + hallVar })[strategy], 0) end
    },
    zs_nastyhouse_v3 = {
        campingSpotList = { Vector(173.97, 301.98, -248.66), Vector(18.03, -46.96, -115.96), Vector(207.96, -46.96, -115.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 135 + openVar, 45 + openVar, 270 + doorVar })[strategy], 0) end
    },
    zs_villagehouse = {
        campingSpotList = { Vector(-523.96, 575.96, -167.96), Vector(343.96, 767.96, 72.03), Vector(106.20, 767.96, 72.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 225 + openVar, 315 + openVar })[strategy], 0) end
    },
    zs_afterseven_b = {
        campingSpotList = { Vector(896.54, -211.91, -135.69), Vector(967.56, -1371.96, -311.61), Vector(1535.96, -1011.66, -311.58) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 180 + hallVar, 90 + doorVar, 180 + hallVar })[strategy], 0) end
    },
    zs_alexg_motel_v2 = {
        campingSpotList = { Vector(262.04, 359.97, 8.03), Vector(-615.99, -254.95, 8.03), Vector(-615.96, -260.33, 136.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 0 + hallVar, 0 + hallVar, 270 + hallVar })[strategy], 0) end
    },
    zs_bog_pubremakev1 = {
        campingSpotList = { Vector(-752.00, -17.13, 249.03), Vector(-392.03, 383.52, 249.03), Vector(-442.03, 249.96, 249.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + doorVar, 180 + doorVar, 90 + hallVar })[strategy], 0) end
    },
    zs_citadel_b4 = {
        campingSpotList = { Vector(526.29, -1739.57, 1029.03), Vector(1016.00, 850.96, 1173.03), Vector(520.07, -2320.17, 830.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 270 + hallVar, 90 + hallVar })[strategy], 0) end
    },
    zs_clav_maze = {
        campingSpotList = { Vector(-148.47, -1243.99, 8.03), Vector(-440.25, -1454.92, 9.73), Vector(-700.41, 479.96, 8.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 180 + hallVar, 90 + hallVar })[strategy], 0) end
    },
    zs_clav_wall = {
        campingSpotList = { Vector(-80.03, -1453.78, 19.74), Vector(1007.96, 1391.96, 29.85), Vector(150.42, -1033.06, 12.82) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 225 + openVar, 180 + hallVar })[strategy], 0) end
    },
    zs_coasthouse = {
        campingSpotList = { Vector(-97.21, 167.99, 264.03), Vector(-759.96, -87.85, 392.38), Vector(-331.66, 167.96, 392.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + doorVar, 0 + hallVar, 270 + hallVar })[strategy], 0) end,
        removeFuncBreakable = true,
        removeFuncBreakableFilter = function(v)
            local modelName = v:GetModel()
            return modelName == "*5" or modelName == "*6" or modelName == "*7"
        end,
    },
    zs_lakefront_alpha = {
        campingSpotList = { Vector(1463.96, 1879.96, 14.03), Vector(1248.63, 1820.72, 14.03), Vector(1090.03, 1819.96, 14.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 315 + openVar, 270 + hallVar, 225 + openVar })[strategy], 0) end
    },
    zs_nastiesthouse_v3 = {
        campingSpotList = { Vector(2666.04, 4905.45, 23.00), Vector(4124.91, 5464.47, 72.38), Vector(3746.71, 5485.47, -71.61) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 90 + hallVar, 270 + hallVar })[strategy], 0) end
    },
    zs_nastyvillage = {
        campingSpotList = { Vector(-217.02, 70.78, 62.03), Vector(-875.09, -741.29, 64.51), Vector(435.10, -255.88, 38.13) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 270 + hallVar, 0 + doorVar, 180 + doorVar })[strategy], 0) end
    },
    zs_prc_wurzel_v2 = {
        campingSpotList = { Vector(803.99, -149.60, 276.03), Vector(383.24, -975.96, 276.03), Vector(783.96, -979.96, 664.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 135 + openVar, 90 + hallVar, 180 + hallVar })[strategy], 0) end
    },
    zs_raunchierhouse_v2 = {
        campingSpotList = { Vector(-311.96, -224.03, 8.03), Vector(95.96, -743.99, 8.03), Vector(-152.03, -863.96, 152.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 135 + openVar, 135 + openVar, 315 + openVar })[strategy], 0) end
    },
    zs_raunchyhouse_v3 = {
        campingSpotList = { Vector(2926.27, -2578.03, -431.96), Vector(3142.96, -2577.03, -431.96), Vector(2800.65, -3041.97, -431.96) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 225 + openVar, 270 + hallVar })[strategy], 0) end
    },
    zs_residentevil2v2 = {
        campingSpotList = { Vector(1103.56, 994.45, 280.01), Vector(-386.79, -175.98, 280.03), Vector(-387.19, -175.96, 456.03) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + hallVar, 90 + hallVar, 270 + doorVar })[strategy], 0) end
    },
    zs_uglyfort = {
        survivorBreak = true,
        survivorBoxBreak = true,
        campingSpotList = { Vector(1653.56, 1082.45, 64.01), Vector(1730, 1337, 224), Vector(219, 1402, 80) },
        eyeAngles = function(strategy, doorVar, hallVar, openVar) return Angle(0, ({ 90 + openVar, 90 + hallVar, 270 + openVar })[strategy], 0) end,
        botBarrierList = {
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1090, 1279, 176),
                ang = Angle(0, 90, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(961, 1150, 176),
                ang = Angle(0, 180, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1280, 1150, 176),
                ang = Angle(0, 180, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1090, 962, 176),
                ang = Angle(0, 90, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1090, 1279, 15),
                ang = Angle(0, 90, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(961, 1150, 15),
                ang = Angle(0, 180, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1280, 1150, 15),
                ang = Angle(0, 180, 0)
            },
            {
                model = "models/props_c17/fence03a.mdl",
                pos = Vector(1090, 962, 15),
                ang = Angle(0, 90, 0)
            },
        },
    }
}

ZSB.Map.current = ZSB.Map.handler[mapName] or {}

function ZSB.Map:GetValue(key, default, ...)
    local currentValue = self.current[key]

    if currentValue ~= nil then
        return currentValue
    end

    if default ~= nil then
        return default
    end

    local fallbackValue = ZSB.Map.default[key]

    if isfunction(fallbackValue) then
        return fallbackValue(...)
    end

    return fallbackValue
end

function ZSB.Map:SetValue(key, value)
    self.current[key] = value
end

local function RemoveFromMap(key, class, entList, filter)
    if not ZSB.Map:GetValue(key) then
        return
    end

    for _, ent in ipairs(entList or ents.FindByClass(class)) do
        if not filter or filter(ent) then
            ent:Remove()
        end
    end
end

local function RemovePropPhysicsByModel(entList)
    local removePropPhysicsList = ZSB.Map:GetValue("removePropPhysicsList")

    for _, prop in ipairs(entList or ents.FindByClass("prop_physics")) do
        local modelName = prop:GetModel()

        if modelName and removePropPhysicsList[modelName] then
            prop:Remove()
        end
    end
end

local function CreateBotBarriers()
    -- for k,v in ipairs(ents.FindByModel("ModeHere")) do
    --     v:Remove()
    -- end

    local botBarrierList = ZSB.Map:GetValue("botBarrierList")

    for _, botBarrier in ipairs(botBarrierList) do
        local barrierLeadBot = ents.Create("prop_physics")

        if IsValid(barrierLeadBot) then
            barrierLeadBot:SetModel(botBarrier.model)
            barrierLeadBot:SetPos(botBarrier.pos)
            barrierLeadBot:SetAngles(botBarrier.ang)
            barrierLeadBot:Spawn()
            barrierLeadBot:Fire("DisableMotion")
        end
    end
end

local function CreateBotCampingSpots()
    local campingSpotList = ZSB.Map:GetValue("campingSpotList")

    for index, pos in ipairs(campingSpotList) do
        local sigil = ents.Create("prop_dynamic")

        if IsValid(sigil) then
            sigil:SetModel("models/dav0r/buttons/button.mdl")
            sigil:SetPos(pos)
            sigil:SetNoDraw(ZSB.DEBUG)
            sigil:Spawn()
            sigil:Fire("DisableMotion")

            ZSB.Map:SetValue("sigil" .. index, sigil)
        end
    end
end

function ZSB.Map.Init()
    local currentMapName = game.GetMap()

    ZSB.Map.current = ZSB.Map.handler[currentMapName] or {}

    local mapChangesCVar = GetConVar("leadbot_mapchanges")

    if not mapChangesCVar or mapChangesCVar:GetInt() < 1 then
        return
    end

    RemoveFromMap("removeFuncDoorRotating", "func_door_rotating")
    RemoveFromMap("removePropDoorRotating", "prop_door_rotating")
    RemoveFromMap("removeFuncUseableladder", "func_useableladder")

    local funcPhysboxFilter = ZSB.Map:GetValue("removeFuncPhysboxFilter")

    RemoveFromMap("removeFuncPhysbox", "func_physbox", nil, funcPhysboxFilter)
    
    local funcBreakableFilter = ZSB.Map:GetValue("removeFuncBreakableFilter")
    
    RemoveFromMap("removeFuncBreakable", "func_breakable", nil, funcBreakableFilter)

    local propPhysicsEnts = ents.FindByClass("prop_physics")

    RemovePropPhysicsByModel(propPhysicsEnts)

    if ZSB.Map:GetValue("forceEnableMotion") then
        for _, physbox in ipairs(funcPhysboxEnts) do
            physbox:Fire("EnableMotion")
        end

        for _, prop in ipairs(propPhysicsEnts) do
            prop:Fire("EnableMotion")
        end
    end

    CreateBotBarriers()
    --CreateBotCampingSpots()
end