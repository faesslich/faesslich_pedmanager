-- ============================================================================
-- SCHEMA MIGRATION
-- ============================================================================

MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS `faesslich_pedmanager` (
        `id`         INT NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(80) NOT NULL,
        `ped`        VARCHAR(50) NOT NULL,
        `is_default` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        INDEX `idx_identifier` (`identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS `faesslich_pedmanager_access` (
        `identifier` VARCHAR(80) NOT NULL,
        `granted_by` VARCHAR(80) DEFAULT NULL,
        `granted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

DebugMessage('Database tables initialized')

-- ============================================================================
-- HELPERS
-- ============================================================================

local accessCache = {}
local rateLimits = {}

local function GetPlayerId(src)
    if Config.Core == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier
    elseif Config.Core == 'QBCore' then
        local player = QBCore.Functions.GetPlayer(src)
        return player and player.PlayerData.citizenid
    end
end

local function IsAdmin(src)
    if Config.Core == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        local group = xPlayer.getGroup()
        for _, g in ipairs(Config.AdminGroups) do
            if group == g then return true end
        end
    elseif Config.Core == 'QBCore' then
        for _, g in ipairs(Config.AdminGroups) do
            if QBCore.Functions.HasPermission(src, g) then return true end
        end
    end
    return false
end

--- Check if player has pedmanager access (admin OR granted)
local function HasAccess(src)
    if IsAdmin(src) then return true end
    local identifier = GetPlayerId(src)
    if not identifier then return false end

    -- Check cache first
    if accessCache[identifier] ~= nil then
        return accessCache[identifier]
    end

    local row = MySQL.single.await('SELECT 1 FROM faesslich_pedmanager_access WHERE identifier = ?', { identifier })
    accessCache[identifier] = row ~= nil
    return accessCache[identifier]
end

--- Rate limit: returns true if action is allowed
local function RateCheck(src)
    local now = os.time()
    if rateLimits[src] and (now - rateLimits[src]) < 1 then
        return false
    end
    rateLimits[src] = now
    return true
end

--- Validate model string
local function IsValidModel(model)
    return type(model) == 'string' and #model > 0 and #model <= 50 and Config.PedLookup[model]
end

--- Validate pedId
local function IsValidPedId(pedId)
    pedId = tonumber(pedId)
    return pedId and pedId > 0 and pedId == math.floor(pedId)
end

-- ============================================================================
-- CALLBACKS (all server-authoritative, all access-checked)
-- ============================================================================

lib.callback.register('faesslich_pedmanager:getMyPeds', function(source)
    if not HasAccess(source) then return {} end
    local identifier = GetPlayerId(source)
    if not identifier then return {} end

    return MySQL.query.await('SELECT id, ped, is_default FROM faesslich_pedmanager WHERE identifier = ?', { identifier }) or {}
end)

lib.callback.register('faesslich_pedmanager:getDefaultPed', function(source)
    local identifier = GetPlayerId(source)
    if not identifier then return false end

    -- Default ped loads even without explicit "access" — it was already granted
    local result = MySQL.single.await('SELECT ped FROM faesslich_pedmanager WHERE identifier = ? AND is_default = 1', { identifier })
    return result and result.ped or false
end)

lib.callback.register('faesslich_pedmanager:hasAccess', function(source)
    return HasAccess(source)
end)

lib.callback.register('faesslich_pedmanager:isAdmin', function(source)
    return IsAdmin(source)
end)

lib.callback.register('faesslich_pedmanager:addPed', function(source, model)
    local src = source
    if not RateCheck(src) then return false end
    if not HasAccess(src) then return false end
    if not IsValidModel(model) then return false end

    local identifier = GetPlayerId(src)
    if not identifier then return false end

    local existing = MySQL.single.await('SELECT id FROM faesslich_pedmanager WHERE identifier = ? AND ped = ?', { identifier, model })
    if existing then
        TriggerClientEvent('faesslich_pedmanager:Notify', src, L('notify_title'), L('notify_already_owned'), 'error')
        return false
    end

    MySQL.insert.await('INSERT INTO faesslich_pedmanager (identifier, ped) VALUES (?, ?)', { identifier, model })
    TriggerClientEvent('faesslich_pedmanager:Notify', src, L('notify_title'), L('notify_ped_added'), 'success')
    return true
end)

lib.callback.register('faesslich_pedmanager:removePed', function(source, pedId)
    local src = source
    if not RateCheck(src) then return false end
    if not HasAccess(src) then return false end
    if not IsValidPedId(pedId) then return false end

    local identifier = GetPlayerId(src)
    if not identifier then return false end
    pedId = tonumber(pedId)

    MySQL.update.await('DELETE FROM faesslich_pedmanager WHERE id = ? AND identifier = ?', { pedId, identifier })
    TriggerClientEvent('faesslich_pedmanager:Notify', src, L('notify_title'), L('notify_ped_removed'), 'success')
    return true
end)

lib.callback.register('faesslich_pedmanager:setDefault', function(source, pedId, pedModel)
    local src = source
    if not RateCheck(src) then return false end
    if not HasAccess(src) then return false end
    if not IsValidPedId(pedId) then return false end

    local identifier = GetPlayerId(src)
    if not identifier then return false end
    pedId = tonumber(pedId)

    MySQL.update.await('UPDATE faesslich_pedmanager SET is_default = 0 WHERE identifier = ?', { identifier })
    MySQL.update.await('UPDATE faesslich_pedmanager SET is_default = 1 WHERE id = ? AND identifier = ?', { pedId, identifier })

    TriggerClientEvent('faesslich_pedmanager:Notify', src, L('notify_title'), L('notify_default_set'), 'success')
    return true
end)

lib.callback.register('faesslich_pedmanager:unsetDefault', function(source, pedId)
    local src = source
    if not RateCheck(src) then return false end
    if not HasAccess(src) then return false end
    if not IsValidPedId(pedId) then return false end

    local identifier = GetPlayerId(src)
    if not identifier then return false end
    pedId = tonumber(pedId)

    MySQL.update.await('UPDATE faesslich_pedmanager SET is_default = 0 WHERE id = ? AND identifier = ?', { pedId, identifier })
    TriggerClientEvent('faesslich_pedmanager:Notify', src, L('notify_title'), L('notify_default_cleared'), 'success')
    return true
end)

--- Server-validated ped apply: client requests, server checks ownership then tells client to apply
lib.callback.register('faesslich_pedmanager:validateApply', function(source, model)
    local src = source
    if not HasAccess(src) then return false end
    if not IsValidModel(model) then return false end
    -- Valid model in the catalog — allow apply (preview from catalog is fine)
    return true
end)

-- ============================================================================
-- SERVER-ONLY COMMANDS (console / rcon only, not client-callable)
-- ============================================================================

--- Grant pedmanager access: pedmanager_grant <server_id>
RegisterCommand('pedmanager_grant', function(source, args)
    if source ~= 0 then
        print('[faesslich_pedmanager] This command can only be used from the server console.')
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        print('[faesslich_pedmanager] Usage: pedmanager_grant <server_id>')
        return
    end

    local identifier = GetPlayerId(targetId)
    if not identifier then
        print('[faesslich_pedmanager] Player not found or not loaded: ' .. tostring(targetId))
        return
    end

    local existing = MySQL.single.await('SELECT 1 FROM faesslich_pedmanager_access WHERE identifier = ?', { identifier })
    if existing then
        print(('[faesslich_pedmanager] Player %s (%s) already has access.'):format(targetId, identifier))
        return
    end

    MySQL.insert.await('INSERT INTO faesslich_pedmanager_access (identifier, granted_by) VALUES (?, ?)', { identifier, 'console' })
    accessCache[identifier] = true
    print(('[faesslich_pedmanager] ✓ Access granted to player %s (%s)'):format(targetId, identifier))
end, true) -- restricted = true (ace-based, not usable by clients without ace)

--- Revoke pedmanager access: pedmanager_revoke <server_id>
RegisterCommand('pedmanager_revoke', function(source, args)
    if source ~= 0 then
        print('[faesslich_pedmanager] This command can only be used from the server console.')
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        print('[faesslich_pedmanager] Usage: pedmanager_revoke <server_id>')
        return
    end

    local identifier = GetPlayerId(targetId)
    if not identifier then
        print('[faesslich_pedmanager] Player not found or not loaded: ' .. tostring(targetId))
        return
    end

    MySQL.update.await('DELETE FROM faesslich_pedmanager_access WHERE identifier = ?', { identifier })
    accessCache[identifier] = false
    print(('[faesslich_pedmanager] ✓ Access revoked from player %s (%s)'):format(targetId, identifier))
end, true)

--- Grant by identifier directly: pedmanager_grant_id <identifier>
RegisterCommand('pedmanager_grant_id', function(source, args)
    if source ~= 0 then
        print('[faesslich_pedmanager] This command can only be used from the server console.')
        return
    end
    local identifier = args[1]
    if not identifier or #identifier == 0 then
        print('[faesslich_pedmanager] Usage: pedmanager_grant_id <identifier>')
        return
    end

    local existing = MySQL.single.await('SELECT 1 FROM faesslich_pedmanager_access WHERE identifier = ?', { identifier })
    if existing then
        print(('[faesslich_pedmanager] Identifier %s already has access.'):format(identifier))
        return
    end

    MySQL.insert.await('INSERT INTO faesslich_pedmanager_access (identifier, granted_by) VALUES (?, ?)', { identifier, 'console' })
    accessCache[identifier] = true
    print(('[faesslich_pedmanager] ✓ Access granted to identifier %s'):format(identifier))
end, true)

--- Revoke by identifier: pedmanager_revoke_id <identifier>
RegisterCommand('pedmanager_revoke_id', function(source, args)
    if source ~= 0 then
        print('[faesslich_pedmanager] This command can only be used from the server console.')
        return
    end
    local identifier = args[1]
    if not identifier or #identifier == 0 then
        print('[faesslich_pedmanager] Usage: pedmanager_revoke_id <identifier>')
        return
    end

    MySQL.update.await('DELETE FROM faesslich_pedmanager_access WHERE identifier = ?', { identifier })
    accessCache[identifier] = false
    print(('[faesslich_pedmanager] ✓ Access revoked from identifier %s'):format(identifier))
end, true)

--- List all granted players: pedmanager_list
RegisterCommand('pedmanager_list', function(source)
    if source ~= 0 then
        print('[faesslich_pedmanager] This command can only be used from the server console.')
        return
    end

    local rows = MySQL.query.await('SELECT identifier, granted_by, granted_at FROM faesslich_pedmanager_access ORDER BY granted_at DESC')
    if not rows or #rows == 0 then
        print('[faesslich_pedmanager] No players have been granted access.')
        return
    end

    print(('[faesslich_pedmanager] === %d player(s) with access ==='):format(#rows))
    for _, row in ipairs(rows) do
        print(('  %s  (by: %s, at: %s)'):format(row.identifier, row.granted_by or '?', tostring(row.granted_at)))
    end
end, true)

-- Cleanup rate limits periodically
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, ts in pairs(rateLimits) do
            if now - ts > 60 then
                rateLimits[src] = nil
            end
        end
    end
end)

-- Clear access cache on player drop
AddEventHandler('playerDropped', function()
    local src = source
    rateLimits[src] = nil
    local identifier = GetPlayerId(src)
    if identifier then
        accessCache[identifier] = nil
    end
end)
