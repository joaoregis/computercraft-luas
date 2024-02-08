-- Define os periféricos e variáveis necessárias
local imbuement_chamber = peripheral.wrap("ars_nouveau:imbuement_chamber_0")
local pedestals = {
    left = peripheral.wrap("ars_nouveau:arcane_pedestal_3"),
    right = peripheral.wrap("ars_nouveau:arcane_pedestal_5"),
    back = peripheral.wrap("ars_nouveau:arcane_pedestal_4")
}
local chest_input = peripheral.wrap("minecraft:chest_1")
local chest_output = peripheral.wrap("minecraft:barrel_1")
local buffer_chest = peripheral.wrap("sophisticatedstorage:chest_1")

-- Flag para indicar se uma receita está em andamento
local isCraftingInProgress = false
local currentRecipeResult = nil

local recipes = {
    ["ars_nouveau:fire_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:flint_and_steel",
            "minecraft:torch",
            "minecraft:gunpowder",
        },
        key_item = "minecraft:gunpowder"
    },
    ["ars_nouveau:water_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:kelp",
            "minecraft:snow_block",
            "minecraft:water_bucket",
        },
        key_item = "minecraft:kelp"
    },
    ["ars_nouveau:abjuration_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:fermented_spider_eye",
            "minecraft:milk_bucket",
            "minecraft:sugar",
        },
        key_item = "minecraft:sugar"
    },
    ["ars_nouveau:conjuration_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:book",
            "ars_nouveau:wilden_horn",
            "ars_nouveau:starbuncle_shards",
        },
        key_item = "minecraft:book"
    },
    ["ars_nouveau:air_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:feather",
            "minecraft:arrow",
            "ars_nouveau:wilden_wing",
        },
        key_item = "minecraft:feather"
    },
    ["ars_nouveau:earth_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:dirt",
            "minecraft:wheat_seeds",
            "minecraft:iron_ingot",
        },
        key_item = "minecraft:wheat_seeds"
    },
    ["ars_nouveau:manipulation_essence"] = {
        ingredients = {
            "ars_nouveau:source_gem",
            "minecraft:stone_button",
            "minecraft:clock",
            "minecraft:redstone",
        },
        key_item = "minecraft:redstone"
    }
}

local ENABLE_LOGGING_TO_FILE = false
local function logToFile(message)
    if not ENABLE_LOGGING_TO_FILE then
        print(message)
        return
    end

    local file = fs.open("output.txt", "a")
    if file then
        file.writeLine(message)
        file.close()
        print(message)
    else
        print("Nao foi possivel abrir o arquivo de log.")
    end
end

-- Verifica se o baú de entrada contém o key_item para alguma receita
local function checkForKeyItem()
    local items = chest_input.list()
    for recipeResult, recipe in pairs(recipes) do
        for slot, item in pairs(items) do
            if item.name == recipe.key_item then
                logToFile("Key item encontrado para a receita: " .. recipeResult)
                return recipeResult, slot
            end
        end
    end
    return nil
end

local function setupCrafting(recipeResult)
    local recipe = recipes[recipeResult]

    -- Inicializar lista de pedidos dos pedestais
    local pedestalOrder = { "left", "right", "back" }

    -- Primeiro, transfere os ingredientes comuns do buffer_chest para os pedestais
    local itemsBuffer = buffer_chest.list()
    for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient ~= "ars_nouveau:source_gem" and ingredient ~= recipe.key_item then
            for slot, item in pairs(itemsBuffer) do
                if item.name == ingredient then
                    local pedestal = pedestals[table.remove(pedestalOrder, 1)]
                    buffer_chest.pushItems(peripheral.getName(pedestal), slot, 1)
                    logToFile("Item " ..
                        ingredient .. " movido do buffer para o pedestal " .. peripheral.getName(pedestal))
                    break
                end
            end
        end
    end

    -- Em seguida, transfere o key_item do chest_input para um pedestal
    local itemsInput = chest_input.list()
    for slot, item in pairs(itemsInput) do
        if item.name == recipe.key_item then
            local pedestal = pedestals[table.remove(pedestalOrder, 1)]
            chest_input.pushItems(peripheral.getName(pedestal), slot, 1)
            logToFile("Key item " .. item.name .. " movido para o pedestal " .. peripheral.getName(pedestal))
            break
        end
    end

    -- Por último, transfere a source_gem para a imbuement chamber
    for slot, item in pairs(itemsInput) do
        if item.name == "ars_nouveau:source_gem" then
            chest_input.pushItems(peripheral.getName(imbuement_chamber), slot, 1)
            logToFile("Source Gem movida para a Imbuement Chamber")
            break
        end
    end

    isCraftingInProgress = true
    currentRecipeResult = recipeResult
end


-- Funçao para verificar se o crafting foi concluído
local function isCraftingDone(expectedResult)
    local item = imbuement_chamber.getItemDetail(1)
    if item and item.name == expectedResult then
        logToFile("Crafting concluído para: " .. expectedResult)
        isCraftingInProgress = false -- Garante que o estado seja atualizado
        return true
    end
    return false
end

-- Funçao para finalizar o crafting
local function finishCrafting()
    logToFile("Finalizando o processo de crafting...")

    -- Retorna os itens reutilizáveis para o buffer
    for pedestalName, pedestal in pairs(pedestals) do
        local item = pedestal.getItemDetail(1)
        if item then
            if item.name ~= recipes[currentRecipeResult].key_item then
                -- Retorna itens comuns ao buffer
                pedestal.pushItems(peripheral.getName(buffer_chest), 1, 1)
                logToFile("Item " .. item.name .. " retornado ao buffer do pedestal: " .. pedestalName)
            else
                -- Move o key_item para o baú de saída
                pedestal.pushItems(peripheral.getName(chest_output), 1, 1)
                logToFile("Key item " .. item.name .. " movido para o bau de saida.")
            end
        end
    end

    -- Move o produto final para o baú de saída
    local itemDetail = imbuement_chamber.getItemDetail(1)
    if itemDetail and itemDetail.count > 0 then
        imbuement_chamber.pushItems(peripheral.getName(chest_output), 1, itemDetail.count)
        logToFile("Produto final " .. itemDetail.name .. " movido para o bau de saida.")
    else
        logToFile("Nenhum produto final encontrado na Imbuement Chamber.")
    end


    currentRecipeResult = nil
    isCraftingInProgress = false
end

-- Loop principal
while true do
    if not isCraftingInProgress then
        local recipeResult, keyItemSlot = checkForKeyItem()
        if recipeResult then
            currentRecipeResult = recipeResult
            logToFile("Iniciando o processo de crafting para: " .. recipeResult)
            setupCrafting(recipeResult)
        end
    end

    if isCraftingInProgress then
        logToFile("Current recipe result: " .. currentRecipeResult)
        if isCraftingDone(currentRecipeResult) then
            finishCrafting()
        end
    end

    sleep(1)
end
