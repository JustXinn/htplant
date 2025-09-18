-- === SCRIPT CORE FROM GITHUB ===
-- Script ini akan diambil dan dijalankan oleh main.lua
-- Konfigurasi diakses melalui variabel global 'config'

-- Pastikan konfigurasi tersedia
if not config then
    print("Error: Konfigurasi tidak ditemukan. Pastikan main.lua mengirimkannya dengan benar.")
    return
end

-- Gunakan konfigurasi dari main.lua
FarmWorlds = config.FarmWorlds
FarmWorldID = config.FarmWorldID

StorageWorld = config.StorageWorld
StorageWorldSeedID = config.StorageWorldSeedID
StorageWorldBlockID = config.StorageWorldBlockID

PackDropWorld = config.PackDropWorld
PackDropWorldID = config.PackDropWorldID

WebhookUrl = config.WebhookUrl
YourDiscordid = config.YourDiscordid

BlockID = config.BlockID
delayHarvest = config.delayHarvest
delayPlant = config.delayPlant

PlantAndHarvest = config.PlantAndHarvest
HTCollectBlockInWorld = config.HTCollectBlockInWorld
HTMoveToStorage = config.HTMoveToStorage

DropCustomItem = config.DropCustomItem
CustomItemID = config.CustomItemID
CustomItemDropCount = config.CustomItemDropCount

packname = config.packname
pricepack = config.pricepack
PackitemID = config.PackitemID
PackDropCount = config.PackDropCount

-- Ensure uppercase for consistency
StorageWorld = string.upper(StorageWorld)
StorageWorldSeedID = string.upper(StorageWorldSeedID)
StorageWorldBlockID = string.upper(StorageWorldBlockID)
PackDropWorld = string.upper(PackDropWorld)
PackDropWorldID = string.upper(PackDropWorldID)
FarmWorldID = string.upper(FarmWorldID)

-- Global variables for tracking
loopCount = 0
lastWebhookMessage = ""
currentFarmWorld = "" -- Ditambahkan di sini

-- Utility Functions
function GonWebhook(message)
    if WebhookUrl ~= "-" and message ~= lastWebhookMessage then
        local success, wh = pcall(Webhook.new, WebhookUrl)
        if not success or not wh then
            print("Failed to create webhook instance")
            return
        end

        wh.username = "Lennn x Mizz"
        wh.avatar_url = "https://media.discordapp.net/attachments/1213682057344061531/1418098582753640479/7012d6ea-21bf-49ce-bbf8-9c36eed1d5a0.jpg?ex=68cce2b9&is=68cb9139&hm=8664d1f34e53ec8e2876a84c75bdc78d8d3315f271bb6ac8347799d714ec3844&=&format=webp&width=870&height=960"
        wh.embed1.use = true
        wh.embed1.title = "Lennn x Mizz"
        wh.embed1.description = message

        local sendSuccess, err = pcall(function() wh:send() end)
        if not sendSuccess then
            print("Webhook send error: " .. tostring(err))
        else
            lastWebhookMessage = message
        end
    end
end

function join(worldName, doorId)
    local bot = getBot()
    if not bot or bot.status ~= BotStatus.online then
        print("Bot is offline, cannot join world")
        return false
    end

    sleep(3000)
    bot:warp(worldName, doorId)
    sleep(3000)

    local maxRetries = 3
    local retries = 0

    while bot:getWorld() and string.upper(bot:getWorld().name) ~= worldName and retries < maxRetries do
        print("Warp failed, retrying... (" .. (retries + 1) .. "/" .. maxRetries .. ")")
        sleep(2000)
        bot:warp(worldName, doorId)
        sleep(3000)
        retries = retries + 1
    end

    if bot:getWorld() and string.upper(bot:getWorld().name) ~= worldName then
        print("Failed to warp to " .. worldName .. " after " .. maxRetries .. " attempts")
        return false
    end

    return true
end

function harvest()
    local bot = getBot()
    if not bot then return false end
    
    local world = bot:getWorld()
    if not world then
        print("No world instance available for harvest")
        return false
    end

    bot.auto_collect = HTCollectBlockInWorld

    for _, tile in pairs(world:getTiles()) do
        if bot.status ~= BotStatus.online then
            return false
        end

        if tile.fg == BlockID + 1 and tile:canHarvest() then
            if not bot:isInTile(tile.x, tile.y) then
                local pathSuccess, err = pcall(function() bot:findPath(tile.x, tile.y) end)
                if not pathSuccess then
                    print("Pathfinding error: " .. tostring(err))
                end
                sleep(500)
            end

            if world:getTile(tile.x, tile.y).fg == BlockID + 1 then
                bot:hit(tile.x, tile.y)
                sleep(delayHarvest)
            end

            if world:getTile(tile.x, tile.y).fg == BlockID + 1 then
                bot:hit(tile.x, tile.y)
                sleep(delayHarvest)
            end

            sleep(300)
        end
    end
    return true
end

function collectSpecificItems(itemId)
    local bot = getBot()
    if not bot then return 0 end
    
    print("Starting collectSpecificItems for item ID: " .. tostring(itemId))

    local inventory = bot:getInventory()
    if not inventory then
        print("Error: No inventory instance available for collectSpecificItems")
        return 0
    end

    local world = bot:getWorld()
    if not world then
        print("Error: No world instance available for collectSpecificItems")
        return 0
    end

    local oldAutoCollect = bot.auto_collect
    bot.auto_collect = false

    local collectedCount = 0
    local objects = world:getObjects()

    if not objects then
        print("Warning: world:getObjects() returned nil")
        bot.auto_collect = oldAutoCollect
        return 0
    end

    print("Found " .. #objects .. " objects in world")

    for i, obj in pairs(objects) do
        if obj and obj.id and obj.oid then
            if obj.id == itemId then
                print("Attempting to collect specific object - OID: " .. obj.oid .. ", ID: " .. obj.id .. ", Count: " .. obj.count)

                local collectSuccess, err = pcall(function()
                    bot:collectObject(obj.oid, 1)
                end)

                if collectSuccess then
                    collectedCount = collectedCount + obj.count
                    print("Successfully collected object OID: " .. obj.oid .. " (Count: " .. obj.count .. ")")
                else
                    print("Failed to collect object OID: " .. obj.oid .. " - Error: " .. tostring(err))
                end

                sleep(200)
            end
        end

        if bot.status ~= BotStatus.online then
            print("Bot went offline during collection, stopping...")
            break
        end
    end

    bot.auto_collect = oldAutoCollect
    print("Restored auto_collect state to: " .. tostring(oldAutoCollect))
    print("Total items collected (specific): " .. collectedCount)

    return collectedCount
end

function plant()
    local bot = getBot()
    if not bot then return false end
    
    local seedId = BlockID + 1
    local inventory = bot:getInventory()
    local world = bot:getWorld()

    if not inventory or not world then
        print("Missing inventory or world instance for planting")
        return false
    end

    print("Checking seed inventory. Current seed count (" .. seedId .. "): " .. inventory:getItemCount(seedId))

    if inventory:getItemCount(seedId) <= 0 then
        print("No seeds available, going to storage to collect seeds.")
        if not join(StorageWorld, StorageWorldSeedID) then
            print("Failed to join storage world for seeds")
            return false
        end

        sleep(2000)

        print("Calling collectSpecificItems for seeds...")
        local collected = collectSpecificItems(seedId)
        print("collectSpecificItems returned: " .. collected)

        sleep(1000)

        local newSeedCount = inventory:getItemCount(seedId)
        print("Seed count after collection attempt: " .. newSeedCount)

        if newSeedCount <= 0 then
            print("Still no seeds available after visiting storage and attempting collection.")
            return false
        end
        print("Successfully collected seeds. Available count: " .. newSeedCount)
    end

    if not join(currentFarmWorld, FarmWorldID) then
        print("Failed to return to farm world")
        return false
    end

    local plantedCount = 0
    for _, tile in pairs(world:getTiles()) do
        if bot.status ~= BotStatus.online then
            return false
        end

        if tile.fg == 0 and inventory:getItemCount(seedId) > 0 then
            if not bot:isInTile(tile.x, tile.y) then
                local pathSuccess, err = pcall(function() bot:findPath(tile.x, tile.y) end)
                if not pathSuccess then
                    print("Pathfinding error during planting: " .. tostring(err))
                end
                sleep(300)
            end

            bot:place(tile.x, tile.y, seedId)
            sleep(delayPlant)
            plantedCount = plantedCount + 1

            if plantedCount >= 100 or inventory:getItemCount(seedId) <= 0 then
                break
            end
        end
    end

    print("Planted " .. plantedCount .. " seeds")
    return plantedCount > 0
end

function floats(idz)
    local bot = getBot()
    if not bot then return 0 end
    
    local floatCount = 0
    local world = bot:getWorld()
    if not world then return 0 end

    local objects = world:getObjects()
    if objects then
        for _, obj in pairs(objects) do
            if obj and obj.id == idz then
                floatCount = floatCount + obj.count
            end
        end
    end
    return floatCount
end

function DropItems()
    local bot = getBot()
    if not bot then return end
    
    local inventory = bot:getInventory()
    local world = bot:getWorld()

    if not inventory or not world then
        print("Missing inventory or world for DropItems")
        return
    end

    bot.auto_collect = false

    if HTCollectBlockInWorld and inventory:getItemCount(BlockID) > 0 then
        if not join(StorageWorld, StorageWorldBlockID) then
            print("Failed to join block storage")
            return
        end
        local blockCount = inventory:getItemCount(BlockID)
        while (inventory:getItemCount(BlockID) > 0) do
            if bot.status ~= BotStatus.online then return end
            sleep(1000)
            bot:drop(BlockID, inventory:getItemCount(BlockID))
            sleep(500)
            bot:moveRight(1)
        end
        GonWebhook("<:growbot:992058196439072770> Bot Name : " .. bot.name ..
                       "\n <a:World:997157064008810620> Current World : " .. world.name ..
                       "\n <a:online:1007062631787544666> Status : " .. tostring(bot.status) ..
                       "\n <:pepper_tree_seed:1012630107715797073> Dropped Block : " .. blockCount)
    end

    local seedThreshold = 50
    local seedId = BlockID + 1
    if inventory:getItemCount(seedId) > seedThreshold then
        local seedsToDrop = inventory:getItemCount(seedId) - seedThreshold
        if seedsToDrop > 0 then
            if not join(StorageWorld, StorageWorldSeedID) then
                print("Failed to join seed storage")
                return
            end
            sleep(500)
            bot:drop(seedId, seedsToDrop)
            sleep(500)
            bot:moveRight(1)
            GonWebhook("<:growbot:992058196439072770> Bot Name : " .. bot.name ..
                           "\n <a:World:997157064008810620> Current World : " .. world.name ..
                           "\n <a:online:1007062631787544666> Status : " .. tostring(bot.status) ..
                           "\n <:pepper_tree_seed:1012630107715797073> Dropped Seed : " .. seedsToDrop)
        end
    end

    while bot.gem_count > pricepack do
        if bot.status ~= BotStatus.online then return end
        bot:sendPacket(2, "action|buy\nitem|" .. packname)
        sleep(3000)
    end

    if inventory:getItemCount(PackitemID) > PackDropCount then
        if not join(PackDropWorld, PackDropWorldID) then
            print("Failed to join pack drop world")
            return
        end
        local packCount = inventory:getItemCount(PackitemID)
        while inventory:getItemCount(PackitemID) > PackDropCount do
            if bot.status ~= BotStatus.online then return end
            sleep(500)
            bot:drop(PackitemID, inventory:getItemCount(PackitemID) - PackDropCount)
            sleep(500)
            bot:moveLeft(1)
        end
        GonWebhook("<:growbot:992058196439072770> Bot Name : " .. bot.name ..
                       "\n <a:World:997157064008810620> Current World : " .. world.name ..
                       "\n <a:online:1007062631787544666> Status : " .. tostring(bot.status) ..
                       "\n <:gems:994218103032520724> Dropped Pack : " .. (packCount - PackDropCount))
    end

    if DropCustomItem and inventory:getItemCount(CustomItemID) > CustomItemDropCount then
        if not join(StorageWorld, StorageWorldBlockID) then
            print("Failed to join custom item storage")
            return
        end
        local customItemCount = inventory:getItemCount(CustomItemID)
        while inventory:getItemCount(CustomItemID) > CustomItemDropCount do
            if bot.status ~= BotStatus.online then return end
            sleep(500)
            bot:drop(CustomItemID, inventory:getItemCount(CustomItemID) - CustomItemDropCount)
            sleep(500)
            bot:moveLeft(1)
        end
        GonWebhook("<:growbot:992058196439072770> Bot Name : " .. bot.name ..
                       "\n <a:World:997157064008810620> Current World : " .. world.name ..
                       "\n <a:online:1007062631787544666> Status : " .. tostring(bot.status) ..
                       "\n <:custom_item:ID> Dropped Custom Item (" .. CustomItemID .. ") : " .. (customItemCount - CustomItemDropCount))
    end
end

function scanTree(id)
    local bot = getBot()
    if not bot then 
        print("No bot instance for scanTree")
        return { Ready = 0, Unready = 0 } 
    end
    
    local world = bot:getWorld()
    if not world then
        print("No world instance for scanTree")
        return { Ready = 0, Unready = 0 }
    end

    local countReady = 0
    local countUnready = 0
    for _, tile in pairs(world:getTiles()) do
        if tile.fg == id and tile:canHarvest() then
            countReady = countReady + 1
        elseif tile.fg == id and not tile:canHarvest() then
            countUnready = countUnready + 1
        end
    end
    return { Ready = countReady, Unready = countUnready }
end

function Reconnect(targetWorld, targetDoorId)
    local bot = getBot()
    if not bot then return false end
    
    if bot.status == BotStatus.online then
        print("Bot already online, no need to reconnect")
        return true
    end

    GonWebhook("<@" .. YourDiscordid .. ">" .. "\n<:growbot:992058196439072770> | Bot Name : " .. bot.name .. "\n<:mega:984686541383290940> | Information : Bot Is Offline Trying To Reconnect.... \n<:red_circle:987661002868936774> | Status : Offline ")

    local maxRetries = 5
    local retries = 0

    while bot.status ~= BotStatus.online and retries < maxRetries do
        local connectSuccess, err = pcall(function() bot:connect() end)
        if not connectSuccess then
            print("Connection error: " .. tostring(err))
        end
        sleep(10000)
        retries = retries + 1
    end

    if bot.status == BotStatus.online then
        GonWebhook("<@" .. YourDiscordid .. ">" .. "\n<:growbot:992058196439072770> | Bot Name : " .. bot.name .. "\n<:mega:984686541383290940> | Information : Bot Is Back Online\n<a:online:1007062631787544666> | Status : Online\n<a:World:997157064008810620>")
        if targetWorld and targetDoorId then
            return join(targetWorld, targetDoorId)
        end
        return true
    else
        print("Failed to reconnect after " .. maxRetries .. " attempts")
        return false
    end
end

-- Main Script Execution Logic (Dijalankan dari sini)
print("=== SCRIPT CORE DIMULAI ===")

local bot = getBot()
if not bot then
    print("Error: Could not get bot instance in core script.")
    return
end

print("Bot instance acquired: " .. tostring(bot.name))

local world = bot:getWorld()
local inventory = bot:getInventory()

-- Initial Reconnect Check
if #FarmWorlds > 0 then
    print("Performing initial reconnect check...")
    Reconnect(string.upper(FarmWorlds[1]), FarmWorldID)
end

-- Main Loop
while true do
    loopCount = loopCount + 1

    for i, farmWorldName in ipairs(FarmWorlds) do
        farmWorldName = string.upper(farmWorldName)
        currentFarmWorld = farmWorldName -- Update global variable

        GonWebhook("<:growbot:992058196439072770> Bot Name : " .. bot.name ..
                       "\n <a:World:997157064008810620> Current World : " .. tostring(farmWorldName) ..
                       "\n <a:online:1007062631787544666> Status : " .. tostring(bot.status) ..
                       "\n 🔁 Loop Count : " .. loopCount ..
                       "\n 🔄 Progress : Processing farm world " .. i .. "/" .. #FarmWorlds)

        if not Reconnect(farmWorldName, FarmWorldID) then
            print("Failed to reconnect, skipping to next iteration")
            goto continue
        end

        if not join(farmWorldName, FarmWorldID) then
            print("Failed to join farm world, skipping to next iteration")
            goto continue
        end

        if PlantAndHarvest then
            print("Entering Plant & Harvest Mode for " .. farmWorldName)

            local success = plant()
            if not success then
                print("Planting failed or no seeds, skipping to next world.")
                goto continue
            end

            success = harvest()
            if not success then
                print("Harvesting failed.")
                goto continue
            end

            DropItems()
        else
            print("Entering Harvest Only (HT) Mode for " .. farmWorldName)

            local success = harvest()
            if not success then
                print("Harvesting failed.")
                goto continue
            end

            if not HTCollectBlockInWorld and HTMoveToStorage then
                print("Moving to storage world after harvest...")
                if not join(StorageWorld, StorageWorldBlockID) then
                    print("Failed to move to storage world after harvest.")
                else
                    print("Successfully moved to storage world.")
                    sleep(2000)
                end
            end

            DropItems()
        end

        ::continue::
    end

    print("Completed all farm worlds. Loop count: " .. loopCount)
    sleep(5000)
end
