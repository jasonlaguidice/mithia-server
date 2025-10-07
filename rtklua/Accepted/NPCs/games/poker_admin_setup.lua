-- Poker Manager Setup Utility
-- Use this to assign managers and configure the poker system

PokerManagerSetup = {
    -- Add a new poker manager (run this as a GM/Admin)
    addManager = function(playerName, addedBy, canToggleNpc, canManageTables, canViewStats, canForceEndGames)
        addedBy = addedBy or "SYSTEM"
        canToggleNpc = canToggleNpc ~= false and 1 or 0
        canManageTables = canManageTables ~= false and 1 or 0
        canViewStats = canViewStats ~= false and 1 or 0
        canForceEndGames = canForceEndGames ~= false and 1 or 0

        -- Check if manager already exists
        local checkQuery = string.format("SELECT * FROM poker_managers WHERE player_name = '%s'", playerName)
        local existing = sql(checkQuery)

        if existing and #existing > 0 then
            print(string.format("Player %s is already a poker manager.", playerName))
            return false
        end

        -- Add new manager
        local insertQuery = string.format(
            "INSERT INTO poker_managers (player_name, can_toggle_npc, can_manage_tables, can_view_stats, can_force_end_games, added_by) VALUES ('%s', %d, %d, %d, %d, '%s')",
            playerName, canToggleNpc, canManageTables, canViewStats, canForceEndGames, addedBy
        )

        sql(insertQuery)
        print(string.format("Added %s as a poker manager.", playerName))
        return true
    end,

    -- Remove a poker manager
    removeManager = function(playerName)
        local deleteQuery = string.format("DELETE FROM poker_managers WHERE player_name = '%s'", playerName)
        sql(deleteQuery)
        print(string.format("Removed %s from poker managers.", playerName))
    end,

    -- List all poker managers
    listManagers = function()
        local query = "SELECT * FROM poker_managers ORDER BY created_at"
        local result = sql(query)

        if not result or #result == 0 then
            print("No poker managers found.")
            return
        end

        print("Poker Managers:")
        print("===============")
        for _, manager in ipairs(result) do
            print(string.format("Name: %s", manager.player_name))
            print(string.format("  Toggle NPC: %s | Manage Tables: %s | View Stats: %s | Force End Games: %s",
                manager.can_toggle_npc == 1 and "Yes" or "No",
                manager.can_manage_tables == 1 and "Yes" or "No",
                manager.can_view_stats == 1 and "Yes" or "No",
                manager.can_force_end_games == 1 and "Yes" or "No"
            ))
            print(string.format("  Added By: %s | Date: %s", manager.added_by, manager.created_at))
            print("")
        end
    end,

    -- Update manager permissions
    updateManagerPermissions = function(playerName, canToggleNpc, canManageTables, canViewStats, canForceEndGames)
        local checkQuery = string.format("SELECT * FROM poker_managers WHERE player_name = '%s'", playerName)
        local existing = sql(checkQuery)

        if not existing or #existing == 0 then
            print(string.format("Player %s is not a poker manager.", playerName))
            return false
        end

        canToggleNpc = canToggleNpc and 1 or 0
        canManageTables = canManageTables and 1 or 0
        canViewStats = canViewStats and 1 or 0
        canForceEndGames = canForceEndGames and 1 or 0

        local updateQuery = string.format(
            "UPDATE poker_managers SET can_toggle_npc = %d, can_manage_tables = %d, can_view_stats = %d, can_force_end_games = %d WHERE player_name = '%s'",
            canToggleNpc, canManageTables, canViewStats, canForceEndGames, playerName
        )

        sql(updateQuery)
        print(string.format("Updated permissions for poker manager %s.", playerName))
        return true
    end,

PokerAdminSetup = {
    -- Toggle poker NPC on/off
    togglePokerNPC = function()
        local currentQuery = "SELECT setting_value FROM poker_settings WHERE setting_name = 'npc_active'"
        local result = sql(currentQuery)
        local newStatus = "1"

        if result and #result > 0 and result[1].setting_value == "1" then
            newStatus = "0"
        end

        local updateQuery = string.format("UPDATE poker_settings SET setting_value = '%s' WHERE setting_name = 'npc_active'", newStatus)
        sql(updateQuery)

        print(string.format("Poker NPC is now %s", newStatus == "1" and "ACTIVE" or "INACTIVE"))
    end,

    -- Create a new poker table
    createTable = function(tableName, maxPlayers, smallBlind, bigBlind, minBuyin, maxBuyin)
        maxPlayers = maxPlayers or 6
        smallBlind = smallBlind or 1000
        bigBlind = bigBlind or 2000
        minBuyin = minBuyin or 20000
        maxBuyin = maxBuyin or 200000

        local query = string.format(
            "INSERT INTO poker_tables (table_name, max_players, small_blind, big_blind, min_buyin, max_buyin) VALUES ('%s', %d, %d, %d, %d, %d)",
            tableName, maxPlayers, smallBlind, bigBlind, minBuyin, maxBuyin
        )

        local success = pcall(function() sql(query) end)
        if success then
            print(string.format("Created poker table '%s' with blinds %d/%d", tableName, smallBlind, bigBlind))
        else
            print("Failed to create table. Table name may already exist.")
        end
    end,

    -- List all poker tables
    listTables = function()
        local query = "SELECT * FROM poker_tables ORDER BY id"
        local result = sql(query)

        if not result or #result == 0 then
            print("No poker tables found.")
            return
        end

        print("Poker Tables:")
        print("=============")
        for _, table in ipairs(result) do
            local playerCount = PokerAdminSetup.getTablePlayerCount(table.id)
            print(string.format(
                "ID: %d | Name: %s | Players: %d/%d | Blinds: %s/%s | Buy-in: %s-%s | Status: %s",
                table.id,
                table.table_name,
                playerCount,
                table.max_players,
                Tools.formatValue(table.small_blind),
                Tools.formatValue(table.big_blind),
                Tools.formatValue(table.min_buyin),
                Tools.formatValue(table.max_buyin),
                table.is_active == 1 and "Active" or "Inactive"
            ))
        end
    end,

    -- Get player count for a table
    getTablePlayerCount = function(tableId)
        local query = string.format(
            "SELECT COUNT(*) as count FROM poker_players p JOIN poker_games g ON p.game_id = g.id WHERE g.table_id = %d AND p.is_sitting_out = 0",
            tableId
        )
        local result = sql(query)
        return result and result[1] and result[1].count or 0
    end,

    -- Toggle table active status
    toggleTable = function(tableId)
        local query = string.format("SELECT table_name, is_active FROM poker_tables WHERE id = %d", tableId)
        local result = sql(query)

        if not result or #result == 0 then
            print("Table not found.")
            return
        end

        local table = result[1]
        local newStatus = table.is_active == 1 and 0 or 1

        local updateQuery = string.format("UPDATE poker_tables SET is_active = %d WHERE id = %d", newStatus, tableId)
        sql(updateQuery)

        print(string.format("Table '%s' is now %s", table.table_name, newStatus == 1 and "ACTIVE" or "INACTIVE"))
    end,

    -- View active games
    viewActiveGames = function()
        local query = [[
            SELECT g.id, t.table_name, g.game_state, g.pot_amount, g.current_player_turn,
                   COUNT(p.id) as player_count
            FROM poker_games g
            JOIN poker_tables t ON g.table_id = t.id
            LEFT JOIN poker_players p ON g.id = p.game_id AND p.is_sitting_out = 0
            WHERE g.game_state != 'finished'
            GROUP BY g.id
            ORDER BY g.id
        ]]

        local result = sql(query)

        if not result or #result == 0 then
            print("No active poker games found.")
            return
        end

        print("Active Poker Games:")
        print("===================")
        for _, game in ipairs(result) do
            print(string.format(
                "Game ID: %d | Table: %s | State: %s | Players: %d | Pot: %s | Turn: %s",
                game.id,
                game.table_name,
                game.game_state,
                game.player_count,
                Tools.formatValue(game.pot_amount or 0),
                game.current_player_turn or "None"
            ))
        end
    end,

    -- Force end a game (emergency use)
    forceEndGame = function(gameId)
        local query = string.format("SELECT * FROM poker_games WHERE id = %d", gameId)
        local result = sql(query)

        if not result or #result == 0 then
            print("Game not found.")
            return
        end

        -- Return chips to players
        local playersQuery = string.format("SELECT player_name, chip_count FROM poker_players WHERE game_id = %d", gameId)
        local players = sql(playersQuery)

        if players then
            for _, player in ipairs(players) do
                -- Add chips back to player account
                local updateQuery = string.format(
                    "UPDATE poker_accounts SET chip_balance = chip_balance + %d WHERE player_name = '%s'",
                    player.chip_count, player.player_name
                )
                sql(updateQuery)

                -- Log transaction
                local logQuery = string.format(
                    "INSERT INTO poker_transactions (player_name, transaction_type, amount, balance_before, balance_after, description) VALUES ('%s', 'cashout', %d, 0, 0, 'Force ended game refund')",
                    player.player_name, player.chip_count
                )
                sql(logQuery)
            end
        end

        -- Update game status
        local endQuery = string.format("UPDATE poker_games SET game_state = 'finished' WHERE id = %d", gameId)
        sql(endQuery)

        -- Clear table's current game
        local clearTableQuery = string.format("UPDATE poker_tables SET current_game_id = NULL WHERE current_game_id = %d", gameId)
        sql(clearTableQuery)

        print(string.format("Forced end of game %d. All chips returned to player accounts.", gameId))
    end,

    -- View player chip balances
    viewPlayerBalances = function(limit)
        limit = limit or 20

        local query = string.format([[
            SELECT player_name, chip_balance, total_deposited, total_withdrawn,
                   (total_deposited - total_withdrawn) as net_deposits
            FROM poker_accounts
            ORDER BY chip_balance DESC
            LIMIT %d
        ]], limit)

        local result = sql(query)

        if not result or #result == 0 then
            print("No poker accounts found.")
            return
        end

        print(string.format("Top %d Poker Player Balances:", limit))
        print("================================")
        for _, account in ipairs(result) do
            print(string.format(
                "%s: %s chips | Deposited: %s | Withdrawn: %s | Net: %s",
                account.player_name,
                Tools.formatValue(account.chip_balance),
                Tools.formatValue(account.total_deposited),
                Tools.formatValue(account.total_withdrawn),
                Tools.formatValue(account.net_deposits)
            ))
        end
    end,

    -- Set player chip balance (emergency use)
    setPlayerChips = function(playerName, amount)
        if amount < 0 then
            print("Chip amount cannot be negative.")
            return
        end

        -- Get current balance
        local query = string.format("SELECT chip_balance FROM poker_accounts WHERE player_name = '%s'", playerName)
        local result = sql(query)

        local currentBalance = 0
        if result and #result > 0 then
            currentBalance = result[1].chip_balance
        else
            -- Create account if it doesn't exist
            local createQuery = string.format("INSERT INTO poker_accounts (player_name, chip_balance) VALUES ('%s', %d)", playerName, amount)
            sql(createQuery)
            print(string.format("Created poker account for %s with %s chips.", playerName, Tools.formatValue(amount)))
            return
        end

        -- Update balance
        local updateQuery = string.format("UPDATE poker_accounts SET chip_balance = %d WHERE player_name = '%s'", amount, playerName)
        sql(updateQuery)

        -- Log transaction
        local transType = amount > currentBalance and "deposit" or "withdraw"
        local transAmount = math.abs(amount - currentBalance)
        local logQuery = string.format(
            "INSERT INTO poker_transactions (player_name, transaction_type, amount, balance_before, balance_after, description) VALUES ('%s', '%s', %d, %d, %d, 'Admin adjustment')",
            playerName, transType, transAmount, currentBalance, amount
        )
        sql(logQuery)

        print(string.format("Set %s's chip balance to %s (was %s).", playerName, Tools.formatValue(amount), Tools.formatValue(currentBalance)))
    end,

    -- Get poker system statistics
    getSystemStats = function(days)
        days = days or 7

        local query = string.format([[
            SELECT
                COUNT(DISTINCT player_name) as unique_players,
                SUM(CASE WHEN transaction_type = 'deposit' THEN amount ELSE 0 END) as total_deposits,
                SUM(CASE WHEN transaction_type = 'withdraw' THEN amount ELSE 0 END) as total_withdrawals,
                COUNT(*) as total_transactions
            FROM poker_transactions
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL %d DAY)
        ]], days)

        local result = sql(query)

        if not result or #result == 0 then
            print(string.format("No poker activity found in the last %d days.", days))
            return
        end

        local stats = result[1]

        -- Get current total chip balance
        local balanceQuery = "SELECT SUM(chip_balance) as total_chips FROM poker_accounts"
        local balanceResult = sql(balanceQuery)
        local totalChips = balanceResult and balanceResult[1] and balanceResult[1].total_chips or 0

        print(string.format("%d-Day Poker Statistics:", days))
        print("=========================")
        print(string.format("Unique Players: %d", stats.unique_players))
        print(string.format("Total Deposits: %s gold", Tools.formatValue(stats.total_deposits)))
        print(string.format("Total Withdrawals: %s gold", Tools.formatValue(stats.total_withdrawals)))
        print(string.format("Net Gold In System: %s", Tools.formatValue(stats.total_deposits - stats.total_withdrawals)))
        print(string.format("Total Chip Balance: %s chips", Tools.formatValue(totalChips)))
        print(string.format("Total Transactions: %d", stats.total_transactions))
    end,

    -- Show current poker settings
    showSettings = function()
        local query = "SELECT * FROM poker_settings ORDER BY setting_name"
        local result = sql(query)

        if not result or #result == 0 then
            print("No poker settings found.")
            return
        end

        print("Poker System Settings:")
        print("======================")
        for _, setting in ipairs(result) do
            print(string.format("%s: %s (%s)", setting.setting_name, setting.setting_value, setting.description or ""))
        end
    end,

    -- Update a setting
    updateSetting = function(settingName, newValue)
        local query = string.format("UPDATE poker_settings SET setting_value = '%s' WHERE setting_name = '%s'", newValue, settingName)
        local success = pcall(function() sql(query) end)

        if success then
            print(string.format("Updated %s to %s", settingName, newValue))
        else
            print("Failed to update setting. Check setting name.")
        end
    end
}

-- Example usage commands:
--
-- MANAGER SYSTEM:
-- Add a full-access manager:
-- PokerManagerSetup.addManager("PlayerName", "AdminName")
--
-- Add a manager with limited permissions:
-- PokerManagerSetup.addManager("PlayerName", "AdminName", true, false, true, false)
-- (can toggle NPC and view stats, but can't manage tables or force end games)
--
-- Remove a manager:
-- PokerManagerSetup.removeManager("PlayerName")
--
-- List all managers:
-- PokerManagerSetup.listManagers()
--
-- Update manager permissions:
-- PokerManagerSetup.updateManagerPermissions("PlayerName", true, true, true, false)
--
-- ADMIN FUNCTIONS (for system setup):
-- Toggle poker NPC:
-- PokerAdminSetup.togglePokerNPC()
--
-- Create a high stakes table:
-- PokerAdminSetup.createTable("High Stakes", 6, 5000, 10000, 100000, 1000000)
--
-- List all tables:
-- PokerAdminSetup.listTables()
--
-- Toggle table 1:
-- PokerAdminSetup.toggleTable(1)
--
-- View active games:
-- PokerAdminSetup.viewActiveGames()
--
-- Force end game 1:
-- PokerAdminSetup.forceEndGame(1)
--
-- View top player balances:
-- PokerAdminSetup.viewPlayerBalances(10)
--
-- Set player chips:
-- PokerAdminSetup.setPlayerChips("PlayerName", 50000)
--
-- Get 7-day stats:
-- PokerAdminSetup.getSystemStats(7)
--
-- Show settings:
-- PokerAdminSetup.showSettings()
--
-- Update setting:
-- PokerAdminSetup.updateSetting("turn_timeout_seconds", "45")