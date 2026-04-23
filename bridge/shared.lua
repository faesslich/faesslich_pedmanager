-- ── Framework Detection ─────────────────────────────────────────────────────

local esxState = GetResourceState('es_extended')
local qbState  = GetResourceState('qb-core')

if esxState ~= 'missing' then
    Config.Core = 'ESX'
    ESX = exports['es_extended']:getSharedObject()
elseif qbState ~= 'missing' then
    Config.Core = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()
end

local function GetPedCategory(model)
    return (model and model:sub(1, 4) == 'a_c_') and 'animal' or 'human'
end

local function IsCategoryAllowed(category)
    if category == 'animal' then return Config.ShowAnimalPeds ~= false end
    return Config.ShowHumanPeds ~= false
end

Config.PedLookup = {}
for _, ped in ipairs(Config.VanillaPeds or {}) do
    if IsCategoryAllowed(GetPedCategory(ped)) then
        Config.PedLookup[ped] = true
    end
end
for model, data in pairs(Config.CustomPeds or {}) do
    local category
    if type(data) == 'table' then
        category = data.category or GetPedCategory(model)
    else
        category = GetPedCategory(model)
    end
    if IsCategoryAllowed(category) then
        Config.PedLookup[model] = true
    end
end

-- ── Debug logging ───────────────────────────────────────────────────────────

function DebugMessage(str)
    if Config.Debug then
        print(('[faesslich_pedmanager] %s'):format(str))
    end
end

-- ── Locale helper ───────────────────────────────────────────────────────────
function L(key, ...)
    local lang = Config.Language or 'en'
    local LocaleTbl = Locale or {}
    local str = (LocaleTbl[lang] and LocaleTbl[lang][key])
        or (LocaleTbl['en'] and LocaleTbl['en'][key])
        or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

if not IsDuplicityVersion() then
    local _notifyProvider = nil

    local function DetectNotification()
        local cfg = Config.Notification
        if cfg and cfg ~= 'auto' then return cfg end

        -- Auto-detect: probe well-known notification resources
        local probes = {
            { res = 'ox_lib',         name = 'ox_lib'         },
            { res = 'okokNotify',     name = 'okokNotify'     },
            { res = 'wasabi_notify',  name = 'wasabi_notify'  },
            { res = 'mythic_notify',  name = 'mythic_notify'  },
            { res = 'pNotify',        name = 'pNotify'        },
            { res = 't-notify',       name = 't-notify'       },
        }
        for _, p in ipairs(probes) do
            if GetResourceState(p.res) == 'started' then
                return p.name
            end
        end

        if Config.Core == 'ESX'    then return 'esx'    end
        if Config.Core == 'QBCore' then return 'qbcore' end

        return 'gta'
    end

    -- ── Providers ───────────────────────────────────────────────────────

    local NotifyProviders = {}

    -- GTA native (fallback) ---------------------------------------------------
    NotifyProviders['gta'] = function()
        return {
            notify = function(msg, _nType)
                SetNotificationTextEntry('STRING')
                AddTextComponentString(msg)
                DrawNotification(false, false)
            end,
        }
    end

    -- ox_lib -------------------------------------------------------------------
    NotifyProviders['ox_lib'] = function()
        return {
            notify = function(msg, nType)
                lib.notify({
                    title       = L('notify_title'),
                    description = msg,
                    type        = nType or 'info',
                    position    = 'top',
                    duration    = 5000,
                    icon        = 'fas fa-user',
                })
            end,
        }
    end

    -- ESX ----------------------------------------------------------------------
    NotifyProviders['esx'] = function()
        return {
            notify = function(msg, _nType)
                if ESX and ESX.ShowNotification then
                    ESX.ShowNotification(msg)
                else
                    TriggerEvent('esx:showNotification', msg)
                end
            end,
        }
    end

    -- QBCore / QBox ------------------------------------------------------------
    NotifyProviders['qbcore'] = function()
        return {
            notify = function(msg, nType)
                local qbType = nType == 'info' and 'primary' or (nType or 'primary')
                if QBCore and QBCore.Functions and QBCore.Functions.Notify then
                    QBCore.Functions.Notify(msg, qbType, 5000)
                else
                    TriggerEvent('QBCore:Notify', msg, qbType, 5000)
                end
            end,
        }
    end

    -- okokNotify ---------------------------------------------------------------
    NotifyProviders['okokNotify'] = function()
        return {
            notify = function(msg, nType)
                exports['okokNotify']:Alert(L('notify_title'), msg, 5000, nType or 'info')
            end,
        }
    end

    -- mythic_notify ------------------------------------------------------------
    NotifyProviders['mythic_notify'] = function()
        return {
            notify = function(msg, nType)
                local mType = nType == 'info' and 'inform' or (nType or 'inform')
                exports['mythic_notify']:SendAlert(mType, msg, 5000)
            end,
        }
    end

    -- pNotify ------------------------------------------------------------------
    NotifyProviders['pNotify'] = function()
        return {
            notify = function(msg, nType)
                exports['pNotify']:SendNotification({
                    text    = msg,
                    type    = nType or 'info',
                    timeout = 5000,
                    layout  = 'topRight',
                })
            end,
        }
    end

    -- wasabi_notify ------------------------------------------------------------
    NotifyProviders['wasabi_notify'] = function()
        return {
            notify = function(msg, nType)
                exports['wasabi_notify']:notify(L('notify_title'), msg, 5000, nType or 'info')
            end,
        }
    end

    -- t-notify -----------------------------------------------------------------
    NotifyProviders['t-notify'] = function()
        return {
            notify = function(msg, nType)
                exports['t-notify']:Alert({
                    style   = nType or 'info',
                    message = msg,
                    duration = 5000,
                })
            end,
        }
    end

    -- custom (user-defined export) --------------------------------------------
    NotifyProviders['custom'] = function()
        local cfg = Config.CustomNotification
        if not cfg or not cfg.resource then
            error('[faesslich_pedmanager] Config.Notification = "custom" but Config.CustomNotification is not configured!')
        end
        local res = cfg.resource
        local exp = cfg.export or 'SendNotification'
        return {
            notify = function(msg, nType)
                exports[res][exp](msg, nType or 'info', 5000)
            end,
        }
    end

    -- ── Resolver ────────────────────────────────────────────────────────

    local function GetNotifyProvider()
        if _notifyProvider then return _notifyProvider end

        local system = DetectNotification()
        local factory = NotifyProviders[system]
        if not factory then
            DebugMessage('WARNING: Unknown notification system "' .. tostring(system) .. '" — falling back to GTA native')
            system = 'gta'
            factory = NotifyProviders['gta']
        end

        _notifyProvider = factory()
        DebugMessage('Notification system: ' .. system)
        return _notifyProvider
    end

    -- ── Public API ──────────────────────────────────────────────────────

    function ShowNotification(_title, msg, nType)
        GetNotifyProvider().notify(msg, nType or 'info')
    end

    RegisterNetEvent('faesslich_pedmanager:Notify', function(title, message, nType)
        ShowNotification(title, message, nType)
    end)

end
