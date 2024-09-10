local mapName = game.GetMap()

ZSBots.defaultMapValues = {
    survivorBreak = false,
    survivorBoxBreak = false,
    zombiePropCheck = true,
    zombieBreakCheck = true,
    removePropDoorRotating = true,
    removeFuncDoorRotating = true,
    removeFuncUseableladder = true,
    removeFuncBreakable = false,
    removeFuncPhysbox = false,
    removeFuncPhysboxFilter = function() end,
    forceEnableMotion = false,
    removePropPhysicsList = {
        ["models/combine_apc.mdl"] = true,
        ["models/props_junk/vent001.mdl"] = true,
        ["models/props/cs_militia/refrigerator01.mdl"] = true
    },
    botBarrierList = {},
    sigil3Valid = false,
    sigil2Valid = false,
    sigil1Valid = false,
    campingSpotList= {},
}

ZSBots.mapHandler = {
    zs_overandunderground_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        removeFuncPhysboxFilter = function(v)
            local modelName = v:GetModel()
            return modelName == "*170" or modelName == "*169" or modelName == "*35" or modelName == "*34" or modelName == "*71" or modelName == "*22" 
        end,
        removePropPhysicsList = table.Add({
            ["models/props_debris/metal_panel01a.mdl"] = true
        }, ZSBots.defaultMapValues.removePropPhysicsList),
        campingSpotList = { Vector(-490.96, 3106.96, -55.96), Vector(-42.84, 2375.03, 80.03), Vector(-102.80, 3071.96, 216.03) }
    },
    zs_embassy = {
        survivorBreak = true,
        survivorBoxBreak = true,
        removeFuncBreakable = true,
        removeFuncPhysbox = true,
        removeFuncPhysboxFilter = function(v) return v:Health() > 1 end,
        campingSpotList = { Vector(383.91, -1092.83, 122.03), Vector(-278.96, -1260.96, 280.03), Vector(1148.92, -1234.33, 280.02) }
    },
    zs_buntshot = {
        survivorBreak = true,
        zombiePropCheck = false,
        campingSpotList = { Vector(336.74, 726.40, -375.64), Vector(297.20, 840.50, -375.96), Vector(-1071.96, -915.18, -167.64) }
    },
    zs_termites_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        forceEnableMotion = true,
        campingSpotList = { Vector(207.74, 152.17, 8.03), Vector(16.58, 175.96, 200.03), Vector(211.73, 175.96, 200.03) }
    },
    zs_pub = {
        survivorBreak = true,
        zombieBreakCheck = false,
        removeFuncBreakable = true,
        campingSpotList = { Vector(-648.74, 298.96, 41.03), Vector(-411.03, -45.96, 196.03), Vector(-750.57, 451.99, 196.03) }
    },
    zs_bog_shityhouse = {
        survivorBreak = true,
        campingSpotList = { Vector(-800.40, 1085.99, 177.03), Vector(-758.03, 890.73, 177.03), Vector(-802.42, 802.33, 178.33) }
    },
    zs_ancient_castle_opt = {
        survivorBreak = true,
        campingSpotList = { Vector(187.44, 2143.96, 73.03), Vector(-670.90, 656.01, 73.03), Vector(-73.24, 2143.96, 73.39) }
    },
    zs_deadblock_v2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        campingSpotList = { Vector(900.19, -821.84, 72.03), Vector(1104.31, 1027.96, 81.03), Vector(1023.69, 2019.71, -54.96) }
    },
    zs_gu_frostbite_v2 = {
        survivorBreak = true,
        campingSpotList = { Vector(-1181.79, 720.03, 458.78), Vector(-1434.27, 181.03, 212.03), Vector(-1190.61, 176.03, 213.03) }
    },
    zs_house_outbreak_b2 = {
        survivorBreak = true,
        removeFuncBreakable = true,
        campingSpotList = { Vector(-112.03, -141.96, -107.96), Vector(-173.72, -141.96, -107.96), Vector(-231.96, -141.96, -107.96) }
    },
    zs_imashouse_b2 = {
        survivorBreak = true,
        removePropPhysicsList = table.Add({
            ["models/props_debris/wood_board04a.mdl"] = true
        }, ZSBots.defaultMapValues.removePropPhysicsList),
        campingSpotList = { Vector(257.78, 704.61, 55.03), Vector(-250.97, 967.96, -80.96), Vector(-16.03, 114.03, -216.96) }
    },
    zs_port_v5 = {
        zombiePropCheck = false,
        campingSpotList = { Vector(-1267.96, 2268.49, -1131.96), Vector(791.22, 2359.96, -1015.96), Vector(145.95, 2538.18, -1141.96) }
    },
    zs_bunkerhouse = {
        zombiePropCheck = false,
        campingSpotList = { Vector(200.51, 607.97, 8.03), Vector(-679.96, 602.92, -135.96), Vector(-272.03, 465.92, -543.69) }
    },
    zs_ascent = {
        zombieBreakCheck = false,
        campingSpotList = { Vector(-991.96, 991.96, -55.46), Vector(-33.28, -10.53, 10.16), Vector(38.76, 3.00, 8.03) }
    },
    zs_nastierhouse_v3 = {
        zombieBreakCheck = false,
        campingSpotList = { Vector(-295.97, -1042.08, -887.96), Vector(281.12, -1383.96, -887.96), Vector(-231.97, -993.60, -1015.96) }
    },
    zs_jail_v1 = {
        removePropDoorRotating = false,
        removeFuncPhysbox = true,
        campingSpotList = { Vector(-32.02, 387.61, 152.03), Vector(-96.16, 2086.96, 8.03), Vector(-367.96, -1343.25, 8.03) }
    },
    zs_placid = {
        removePropDoorRotating = false,
        campingSpotList = { Vector(-4351.96, 32.03, 76.03), Vector(-3832.02, 292.06, 212.74), Vector(-4067.96, 24.03, 212.03) }
    },
    zs_lila_panic_v3 = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-1167.96, -879.03, -263.96), Vector(-1150.79, -480.03, -263.96), Vector(1244.16, -1199.63, 14.63) }
    },
    zs_house_number_23 = {
        removeFuncBreakable = true,
        removeFuncPhysbox = true,
        campingSpotList = { Vector(534.03, 26.83, 216.03), Vector(938.99, -365.96, 216.03), Vector(586.66, -469.42, 216.03) }
    },
    zs_mall_dl = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-1750.00, 224.03, -1375.96), Vector(-2520.03, 1086.48, -1375.96), Vector(-2235.70, 512.01, -1583.96) }
    },
    zs_fen = {
        removeFuncBreakable = true,
        campingSpotList = { Vector(-127.91, 18.03, 144.03), Vector(167.96, 361.54, 144.03), Vector(-503.96, 367.21, 144.97) }
    },
    zs_the_pub_beta1 = {
        removeFuncPhysbox = true,
        removeFuncPhysboxFilter = function(v) return v:GetModel() == "*46" or v:GetModel() == "*47" end,
        campingSpotList = { Vector(375.96, 1338.85, 136.03), Vector(-346.06, 896.03, 136.03), Vector(3254.96, -3183.96, 1.10) }
    },
    zs_panic_house_v2 = {
        removePropPhysicsList = table.Add({
            ["models/props_debris/wood_board06a.mdl"] = true
        }, ZSBots.defaultMapValues.removePropPhysicsList),
        campingSpotList = { Vector(-852.89, -354.96, 44.42), Vector(-848.92, 241.24, -336.70), Vector(-978.40, -106.28, -88.96) }
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
        campingSpotList = { Vector(-432.84, 948.03, -607.96), Vector(174.03, 980.48, -597.03), Vector(-545.53, 1121.32, -223.96) }
    },
    zs_nastyhouse_v3 = {
        campingSpotList = { Vector(173.97, 301.98, -248.66), Vector(18.03, -46.96, -115.96), Vector(207.96, -46.96, -115.96) }
    },
    zs_villagehouse = {
        campingSpotList = { Vector(-523.96, 575.96, -167.96), Vector(343.96, 767.96, 72.03), Vector(106.20, 767.96, 72.03) }
    },
    zs_afterseven_b = {
        campingSpotList = { Vector(896.54, -211.91, -135.69), Vector(967.56, -1371.96, -311.61), Vector(1535.96, -1011.66, -311.58) }
    },
    zs_alexg_motel_v2 = {
        campingSpotList = { Vector(262.04, 359.97, 8.03), Vector(-615.99, -254.95, 8.03), Vector(-615.96, -260.33, 136.03) }
    },
    zs_bog_pubremakev1 = {
        campingSpotList = { Vector(-752.00, -17.13, 249.03), Vector(-392.03, 383.52, 249.03), Vector(-442.03, 249.96, 249.03) }
    },
    zs_citadel_b4 = {
        campingSpotList = { Vector(526.29, -1739.57, 1029.03), Vector(1016.00, 850.96, 1173.03), Vector(520.07, -2320.17, 830.03) }
    },
    zs_clav_maze = {
        campingSpotList = { Vector(-148.47, -1243.99, 8.03), Vector(-440.25, -1454.92, 9.73), Vector(-700.41, 479.96, 8.03) }
    },
    zs_clav_wall = {
        campingSpotList = { Vector(-80.03, -1453.78, 19.74), Vector(1007.96, 1391.96, 29.85), Vector(150.42, -1033.06, 12.82) }
    },
    zs_coasthouse = {
        campingSpotList = { Vector(-97.21, 167.99, 264.03), Vector(-759.96, -87.85, 392.38), Vector(-331.66, 167.96, 392.03) }
    },
    zs_lakefront_alpha = {
        campingSpotList = { Vector(1463.96, 1879.96, 14.03), Vector(1248.63, 1820.72, 14.03), Vector(1090.03, 1819.96, 14.03) }
    },
    zs_nastiesthouse_v3 = {
        campingSpotList = { Vector(2666.04, 4905.45, 23.00), Vector(4124.91, 5464.47, 72.38), Vector(3746.71, 5485.47, -71.61) }
    },
    zs_nastyvillage = {
        campingSpotList = { Vector(-217.02, 70.78, 62.03), Vector(-875.09, -741.29, 64.51), Vector(435.10, -255.88, 38.13) }
    },
    zs_prc_wurzel_v2 = {
        campingSpotList = { Vector(803.99, -149.60, 276.03), Vector(383.24, -975.96, 276.03), Vector(783.96, -979.96, 664.03) }
    },
    zs_raunchierhouse_v2 = {
        campingSpotList = { Vector(-311.96, -224.03, 8.03), Vector(95.96, -743.99, 8.03), Vector(-152.03, -863.96, 152.03) }
    },
    zs_raunchyhouse_v3 = {
        campingSpotList = { Vector(2926.27, -2578.03, -431.96), Vector(3142.96, -2577.03, -431.96), Vector(2800.65, -3041.97, -431.96) }
    },
    zs_residentevil2v2 = {
        campingSpotList = { Vector(1103.56, 994.45, 280.01), Vector(-386.79, -175.98, 280.03), Vector(-387.19, -175.96, 456.03) }
    }
}

ZSBots.currentMap = ZSBots.mapHandler[mapName] or {}

function ZSBots:GetMapValue(key)
    if self.currentMap[key] then
        return self.currentMap[key]
    else
        return ZSBots.defaultMapValues[key]
    end
end

function ZSBots:SetMapValue(key, value)
    self.currentMap[key] = value
end

local function RemoveFromMap(key, class, entTab, filter)
    if ZSBots:GetMapValue(key) then
        for k, v in ipairs(entTab or ents.FindByClass(class)) do
            if not filter or filter(v) then
                v:Remove()
            end
        end
    end
end

local function CreateBotBarriers()
    local botBarrierList = ZSBots:GetMapValue("botBarrierList")

    for k, botBarrier in ipairs(botBarrierList) do
        local barrierLeadBot = ents.Create("prop_physics")
        barrierLeadBot:SetModel(botBarrier.model)
        barrierLeadBot:SetPos(botBarrier.pos)
        barrierLeadBot:SetAngles(botBarrier.ang)
        barrierLeadBot:Spawn()
        barrierLeadBot:Fire("DisableMotion")
    end
end

local function CreateBotCampingSpots()
    local campingSpotList = ZSBots:GetMapValue("campingSpotList")

    for k, pos in ipairs(campingSpotList) do
        local sigil = ents.Create("prop_dynamic")
        sigil:SetModel("models/dav0r/buttons/button.mdl")
        sigil:SetPos(pos)
        sigil:SetNoDraw(ZSBots.testing)
        sigil:Spawn()
        sigil:Fire("DisableMotion")

        ZSBots:SetMapValue("sigil" .. k , sigil)
    end
end

local function InitMap()
    if GetConVar("leadbot_mapchanges"):GetInt() >= 1 then 
        RemoveFromMap("removeFuncDoorRotating", "func_door_rotating")
        RemoveFromMap("removePropDoorRotating", "prop_door_rotating")
        RemoveFromMap("removeFuncUseableladder", "func_useableladder")
        RemoveFromMap("removeFuncBreakable", "func_breakable")

        local funcPhysboxEnts = ents.FindByClass("func_physbox")
        local funcPhysboxFilter = ZSBots:GetMapValue("removeFuncPhysboxFilter")

        RemoveFromMap("removeFuncPhysbox", "func_physbox", funcPhysboxEnts, funcPhysboxFilter)

        local propPhysicsEnts = ents.FindByClass("prop_physics")

        RemoveFromMap("removerop_physics", "func_physbox", funcPhysboxEnts, funcPhysboxFilter)

        local removePropPhysicsList = ZSBots:GetMapValue("removePropPhysicsList")

        local countPropPhysicsRemovals = table.Count(removePropPhysicsList)

        for k, v in ipairs(propPhysicsEnts) do
            if removePropPhysicsList[v] then
                v:Remove()
                countPropPhysicsRemovals = countPropPhysicsRemovals - 1
            end

            if countPropPhysicsRemovals == 0 then
                break
            end
        end

        if ZSBots:GetMapValue("forceEnableMotion") then
            for k, v in ipairs(funcPhysboxEnts) do
                v:Fire("EnableMotion")
            end
            for k, v in ipairs(propPhysicsEnts) do
                v:Fire("EnableMotion")
            end
        end

        CreateBotBarriers()
        CreateBotCampingSpots()
    end 
end

hook.Add("InitPostEntity", "initializeZSMap", function()
	InitMap()
end)
