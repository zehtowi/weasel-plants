ESX = nil
Instance = {Started = false, Plants = {}, ClosePlants = {}}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
    TriggerServerEvent("weasel-plants:requestFullSync") -- request a full sync on startup
end)


RegisterNetEvent("weasel-plants:plantSeed") -- Triggered when item is used from linden_inventory
AddEventHandler("weasel-plants:plantSeed", function(item) 
    local type = 0
    for i = 1, #Config.Plants, 1 do
        if Config.Plants[i].Seed == item.name then
            type = i
            break
        end
    end
    if type == 0 then
        if Config.Debub then
            print("Unable to find type for seed "..item.name)
        end
        return
    end
    Citizen.Wait(500)
    TriggerEvent("mythic_progbar:client:progress", {
        name = "plant_seed",
        duration = 10000,
        label = "Planting Seed",
        useWhileDead = false,
        canCancel = false,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = "amb@world_human_gardener_plant@male@base",
            anim = "base",
        }
    }, function(status)
        if not status then
            plantSeed(type)
        end
    end)
end)

RegisterNetEvent("weasel-plants:addPlant") -- addPLant will add a plant to the table
AddEventHandler("weasel-plants:addPlant", function(plant)
    Instance.Plants[plant.ID] = plant
end)

RegisterNetEvent("weasel-plants:removePlant") -- RemovePlant will remvoe a plant with a matching id from table and delete its object
AddEventHandler("weasel-plants:removePlant", function(index)
    if Instance.Plants[index] ~= nil and Instance.Plants[index].Object ~= nil then
        DeleteObject(Instance.Plants[index].Object)
    end
    Instance.Plants[index] = nil
end)

RegisterNetEvent("weasel-plants:sync") -- sync will just sync 1 plant and delete its object
AddEventHandler("weasel-plants:sync", function(plant)
    if Instance.Plants[plant.ID] ~= nil and Instance.Plants[plant.ID].Object ~= nil then
        DeleteObject(Instance.Plants[plant.ID].Object)
    end
    Instance.Plants[plant.ID] = plant
end)

RegisterNetEvent("weasel-plants:fullSync") -- full sync will overwrite the Plants table and start the main loop
AddEventHandler("weasel-plants:fullSync", function(plants)
    Instance.Plants = plants
    mainLoop()
end)

AddEventHandler('onResourceStop', function(resourceName) -- delete all objects when the resource stops
    for i, v in pairs(Instance.Plants) do
        if Instance.Plants[i].Object ~= nil then
            DeleteObject(Instance.Plants[i].Object)
        end
    end
end)


closeLoop = function() -- close loop, for performance find plants that are close and add them to clsoe plants every 3 secounds
    Citizen.CreateThread(function() 
        while true do
            Citizen.Wait(3000)
            local coords = GetEntityCoords(GetPlayerPed(-1))
            for i, v in pairs(Instance.Plants) do
                if not Instance.Plants[i] then
                    break
                end

                
                local dist = #(Instance.Plants[i].Coords - coords)
                if dist <= 100 then
                    if not Instance.Plants[i].Close then
                        Instance.Plants[i].Close = true
                        table.insert( Instance.ClosePlants, {index = i, updated = false} )
                    end
                    Instance.Plants[i].ClosePlantIndex = #Instance.ClosePlants
                elseif Instance.Plants[i].ClosePlantndex then
                    table.remove(Instance.ClosePlants, Instance.Plants[i].ClosePlantIndex) 
                    Instance.Plants[i].ClosePlantIndex = nil
                end
            end
        end
    end)
end

mainLoop = function() -- the main loop 
    if Instance.Started then return end -- if main loop already started dont start it again
    Instance.Started = true -- set main loop as started

    closeLoop()

    Citizen.CreateThread(function() 
        while true do
            Wait(0)
            local needsUpdate = false
            local toUpdate = {}
            if Instance.ClosePlants and #Instance.ClosePlants > 0 then
                local coords = GetEntityCoords(GetPlayerPed(-1))
                for i = 1, #Instance.ClosePlants, 1 do
                    if not Instance.Plants[Instance.ClosePlants[i].index] then
                        table.remove( Instance.ClosePlants, i )
                        break
                    end
                    local dist = #(Instance.Plants[Instance.ClosePlants[i].index].Coords - coords)

                    if dist > 100 then -- if we are far remove it
                        Instance.Plants[Instance.ClosePlants[i].index].Close = false
                        table.remove( Instance.ClosePlants, i )
                        break
                    end

                    if dist <= Config.DrawDistance then
                        if Instance.Plants[Instance.ClosePlants[i].index].Object == nil then -- If there is no object for the plant create one
                            
                            addObject(Instance.ClosePlants[i].index)
                            if not Instance.ClosePlants[i].updated then
                                
                                table.insert( toUpdate, Instance.Plants[Instance.ClosePlants[i].index].ID)
                                if not needsUpdate then needsUpdate = true end
                                Instance.ClosePlants[i].updated = true
                            end
                        end
                    else
                        if Instance.Plants[Instance.ClosePlants[i].index].Object ~= nil then -- If there is a object for the plant delete it
                            DeleteObject(Instance.Plants[Instance.ClosePlants[i].index].Object)
                            Instance.Plants[Instance.ClosePlants[i].index].Object = nil
                        end
                    end
                    
                    if dist <= 1.5 and not Instance.Plants[Instance.ClosePlants[i].index].Harvesting then
                        DrawMarker(27, Instance.Plants[Instance.ClosePlants[i].index].Coords.x, 
                        Instance.Plants[Instance.ClosePlants[i].index].Coords.y, 
                        Instance.Plants[Instance.ClosePlants[i].index].Coords.z-0.95, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 50, false, true, 2, nil, nil, false)

                        if dist <= 0.7 then
                            local infoLoc = vector3(Instance.Plants[Instance.ClosePlants[i].index].Coords.x, 
                            Instance.Plants[Instance.ClosePlants[i].index].Coords.y, Instance.Plants[Instance.ClosePlants[i].index].Coords.z-0.15)

                            DrawText3D(Instance.Plants[Instance.ClosePlants[i].index].Coords, 
                            "Stage ~g~"..Instance.Plants[Instance.ClosePlants[i].index].Stage.."~w~/"..#Config.Plants[Instance.Plants[Instance.ClosePlants[i].index].Type].Stages)

                            DrawText3D(infoLoc, "Press [~g~E~w~] to harvest")
                            if IsControlJustReleased(0, 153) then
                                local done = false
                                Instance.Plants[Instance.ClosePlants[i].index].Harvesting = true
                                TriggerEvent("mythic_progbar:client:progress", {
                                    name = "harvesting_Plant",
                                    duration = 10000,
                                    label = "Harvesting plant",
                                    useWhileDead = false,
                                    canCancel = false,
                                    controlDisables = {
                                        disableMovement = true,
                                        disableCarMovement = true,
                                        disableMouse = false,
                                        disableCombat = true,
                                    },
                                    animation = {
                                        animDict = "amb@world_human_gardener_plant@male@base",
                                        anim = "base",
                                    }
                                }, function(status)
                                    if not status then
                                        TriggerServerEvent("weasel-plants:harvestPlant", Instance.ClosePlants[i].index)  -- trigger the server event to harvest a plant   
                                    end
                                    done = true 
                                end)
                                while not done do Wait(0) end
                            end
                        end
                    end 
                end
                if needsUpdate then
                    TriggerServerEvent("weasel-plants:updatePlants", toUpdate)
                end
            end
        end
    end)
end

Citizen.CreateThread(function()                     --farmers market
    while true do
        Wait(0)
        local location      = GetEntityCoords(GetPlayerPed(-1))
        local dist          = #(location - Config.FarmersMarketSelling)
        if dist <= 1 then text='[~g~E~s~] '.. "Farmer's Market Selling"
            if IsControlJustPressed(0, 38) then
                Wait(10)
                TriggerServerEvent('weasel-plants:sell')
            end
        else text = "Farmer's Market Selling" end
        if dist <= 2 then DrawText3D(Config.FarmersMarketSelling, text) end
        if dist <= 4 then
            DrawMarker(2, Config.FarmersMarketSelling.x, Config.FarmersMarketSelling.y, Config.FarmersMarketSelling.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 30, 150, 30, 222, false, false, false, true, false, false, false)
        end
    end
end)
