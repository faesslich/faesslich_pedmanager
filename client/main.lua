local isNuiOpen = false

local function IsPlayerLoaded()
    if Config.Core == 'ESX' then
        return ESX.IsPlayerLoaded()
    elseif Config.Core == 'QBCore' then
        return LocalPlayer.state.isLoggedIn
    end
    return false
end

-- Apply a ped model to the player (client-side only, validated by server before calling)
local function ApplyPedModel(model)
    if not model or model == '' then return end
    local hash = joaat(model)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do
        Wait(100)
        timeout = timeout + 100
        if timeout > 5000 then
            DebugMessage('Model load timeout: ' .. model)
            return
        end
    end

    local ped = PlayerPedId()
    local armour = GetPedArmour(ped)

    SetPlayerModel(PlayerId(), hash)
    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)
    SetModelAsNoLongerNeeded(hash)

    SetEntityMaxHealth(newPed, 200)
    SetEntityHealth(newPed, 200)
    SetPedArmour(newPed, armour)
end

-- Reset to default skin
local function ResetPlayerPed()
    if Config.Core == 'ESX' then
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
            local isMale = skin.sex == 0
            TriggerEvent('skinchanger:loadDefaultModel', isMale, function()
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin2)
                    TriggerEvent('skinchanger:loadSkin', skin2)
                end)
            end)
        end)
    elseif Config.Core == 'QBCore' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    end
end

-- Load default ped on join
local function LoadDefaultPed()
    local ped = lib.callback.await('faesslich_pedmanager:getDefaultPed', false)
    if ped then
        ApplyPedModel(ped)
    end
end

-- Build available peds list for NUI
local function GetPedCategory(model)
    return (model and model:sub(1, 4) == 'a_c_') and 'animal' or 'human'
end

local function IsCategoryAllowed(category)
    if category == 'animal' then return Config.ShowAnimalPeds ~= false end
    return Config.ShowHumanPeds ~= false
end

local function BuildAvailablePeds()
    local peds = {}
    for model, data in pairs(Config.CustomPeds or {}) do
        local image, category
        if type(data) == 'table' then
            image    = data.image
            category = data.category or GetPedCategory(model)
        else
            image    = data
            category = GetPedCategory(model)
        end
        if IsCategoryAllowed(category) then
            peds[#peds + 1] = {
                model    = model,
                image    = image,
                custom   = true,
                category = category,
            }
        end
    end
    for _, model in ipairs(Config.VanillaPeds or {}) do
        local category = GetPedCategory(model)
        if IsCategoryAllowed(category) then
            peds[#peds + 1] = {
                model    = model,
                image    = ('https://docs.fivem.net/peds/%s.webp'):format(model),
                custom   = false,
                category = category,
            }
        end
    end
    return peds
end

-- Build merged locale dictionary for the NUI (English base + active language overlay)
local function BuildLocaleStrings()
    local lang = Config.Language or 'en'
    local merged = {}

    if Locale and Locale['en'] then
        for k, v in pairs(Locale['en']) do merged[k] = v end
    end
    if Locale and lang ~= 'en' and Locale[lang] then
        for k, v in pairs(Locale[lang]) do merged[k] = v end
    end

    return merged, lang
end

-- Open NUI (access-checked on server)
local function OpenPedManager()
    if not IsPlayerLoaded() then return end

    local hasAccess = lib.callback.await('faesslich_pedmanager:hasAccess', false)
    if not hasAccess then
        ShowNotification(L('notify_title'), L('notify_no_access'), 'error')
        return
    end

    local myPeds = lib.callback.await('faesslich_pedmanager:getMyPeds', false)
    local available = BuildAvailablePeds()
    local isAdmin = lib.callback.await('faesslich_pedmanager:isAdmin', false)
    local localeStrings, localeLang = BuildLocaleStrings()

    SetNuiFocus(true, true)
    isNuiOpen = true

    -- Push locale first so the UI renders translated on first frame
    SendNUIMessage({ action = 'setLocale', data = { strings = localeStrings, language = localeLang } })

    SendNUIMessage({
        action = 'openPedManager',
        data = {
            visible = true,
            myPeds = myPeds or {},
            availablePeds = available,
            isAdmin = isAdmin,
        }
    })
end

local function ClosePedManager()
    if not isNuiOpen then return end
    SetNuiFocus(false, false)
    isNuiOpen = false
    SendNUIMessage({ action = 'openPedManager', data = { visible = false } })
end

-- Command
RegisterCommand('pedmanager', function()
    OpenPedManager()
end, false)

-- Helper: send updated myPeds to NUI
local function SendMyPedsToNui()
    local myPeds = lib.callback.await('faesslich_pedmanager:getMyPeds', false)
    SendNUIMessage({ action = 'updateMyPeds', data = myPeds or {} })
end

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(_, cb)
    ClosePedManager()
    cb('ok')
end)

RegisterNUICallback('applyPed', function(data, cb)
    cb('ok')
    if not data.model then return end
    CreateThread(function()
        local allowed = lib.callback.await('faesslich_pedmanager:validateApply', false, data.model)
        if allowed then
            ApplyPedModel(data.model)
        end
    end)
end)

RegisterNUICallback('resetPed', function(_, cb)
    cb('ok')
    CreateThread(function()
        ResetPlayerPed()
    end)
end)

RegisterNUICallback('setDefaultPed', function(data, cb)
    cb('ok')
    CreateThread(function()
        local id = tonumber(data.id)
        local model = data.model
        if id and model then
            lib.callback.await('faesslich_pedmanager:setDefault', false, id, model)
            SendMyPedsToNui()
        end
    end)
end)

RegisterNUICallback('unsetDefaultPed', function(data, cb)
    cb('ok')
    CreateThread(function()
        local id = tonumber(data.id)
        if id then
            lib.callback.await('faesslich_pedmanager:unsetDefault', false, id)
            SendMyPedsToNui()
        end
    end)
end)

RegisterNUICallback('removePed', function(data, cb)
    cb('ok')
    CreateThread(function()
        local id = tonumber(data.id)
        if id then
            lib.callback.await('faesslich_pedmanager:removePed', false, id)
            SendMyPedsToNui()
        end
    end)
end)

RegisterNUICallback('addPed', function(data, cb)
    cb('ok')
    CreateThread(function()
        if data.model then
            lib.callback.await('faesslich_pedmanager:addPed', false, data.model)
            SendMyPedsToNui()
        end
    end)
end)

RegisterNUICallback('refreshMyPeds', function(_, cb)
    cb('ok')
    CreateThread(function()
        SendMyPedsToNui()
    end)
end)

-- Load default ped on player load
if Config.Core == 'ESX' then
    RegisterNetEvent('esx:playerLoaded', function()
        Wait(1000)
        LoadDefaultPed()
    end)
elseif Config.Core == 'QBCore' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        Wait(1000)
        LoadDefaultPed()
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() and IsPlayerLoaded() then
        LoadDefaultPed()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClosePedManager()
        ResetPlayerPed()
    end
end)
