-- Blackjack Manager Setup Utility
-- Use this to add/remove managers and configure the blackjack system

BlackjackManagerSetup = {
    -- Add a new manager (run this as a GM/Admin)
    addManager = function(playerName, addedBy)
        addedBy = addedBy or "SYSTEM"

        -- Check if manager already exists
        local checkQuery = string.format("SELECT * FROM blackjack_managers WHERE player_name = '%s'", playerName)
        local existing = sql(checkQuery)

        if existing and #existing > 0 then
            print(string.format("Player %s is already a blackjack manager.", playerName))
            return false
        end

        -- Add new manager
        local insertQuery = string.format(
            "INSERT INTO blackjack_managers (player_name, can_add_gold, can_view_stats, added_by) VALUES ('%s', 1, 1, '%s')",
            playerName, addedBy
        )

        sql(insertQuery)
        print(string.format("Added %s as a blackjack manager.", playerName))
        return true
    end,

    -- Remove a manager
    removeManager = function(playerName)
        local deleteQuery = string.format("DELETE FROM blackjack_managers WHERE player_name = '%s'", playerName)
        sql(deleteQuery)
        print(string.format("Removed %s from blackjack managers.", playerName))
    end,

    -- List all managers
    listManagers = function()
        local query = "SELECT player_name, can_add_gold, can_view_stats, added_by, created_at FROM blackjack_managers"
        local result = sql(query)

        if not result or #result == 0 then
            print("No blackjack managers found.")
            return
        end

        print("Blackjack Managers:")
        print("==================")
        for _, manager in ipairs(result) do
            print(string.format("Name: %s | Add Gold: %s | View Stats: %s | Added By: %s | Date: %s",
                manager.player_name,
                manager.can_add_gold == 1 and "Yes" or "No",
                manager.can_view_stats == 1 and "Yes" or "No",
                manager.added_by,
                manager.created_at
            ))
        end
    end,

    -- Set bank gold amount (emergency use)
    setBankGold = function(amount)
        if amount < 0 then
            print("Bank gold cannot be negative.")
            return false
        end

        local updateQuery = string.format("UPDATE blackjack_bank SET bank_gold = %d WHERE npc_identifier = 'blackjack_dealer'", amount)
        sql(updateQuery)
        print(string.format("Set blackjack bank gold to %s.", Tools.formatValue(amount)))
        return true
    end,

    -- Toggle bank active status
    toggleBankStatus = function()
        local currentQuery = "SELECT is_active FROM blackjack_bank WHERE npc_identifier = 'blackjack_dealer'"
        local result = sql(currentQuery)

        if not result or #result == 0 then
            print("Blackjack bank not found.")
            return
        end

        local currentStatus = result[1].is_active
        local newStatus = currentStatus == 1 and 0 or 1

        local updateQuery = string.format("UPDATE blackjack_bank SET is_active = %d WHERE npc_identifier = 'blackjack_dealer'", newStatus)
        sql(updateQuery)

        print(string.format("Blackjack bank is now %s.", newStatus == 1 and "ACTIVE" or "INACTIVE"))
    end,

    -- Set betting limits
    setBettingLimits = function(minBet, maxBet)
        if minBet <= 0 or maxBet <= 0 or minBet > maxBet then
            print("Invalid betting limits. Min must be positive and less than max.")
            return false
        end

        local updateQuery = string.format(
            "UPDATE blackjack_bank SET min_bet = %d, max_bet = %d WHERE npc_identifier = 'blackjack_dealer'",
            minBet, maxBet
        )
        sql(updateQuery)

        print(string.format("Set betting limits: Min %s, Max %s gold.", Tools.formatValue(minBet), Tools.formatValue(maxBet)))
        return true
    end,

    -- Show current bank configuration
    showBankConfig = function()
        local query = "SELECT * FROM blackjack_bank WHERE npc_identifier = 'blackjack_dealer'"
        local result = sql(query)

        if not result or #result == 0 then
            print("Blackjack bank not found.")
            return
        end

        local bank = result[1]
        print("Blackjack Bank Configuration:")
        print("============================")
        print(string.format("Bank Gold: %s", Tools.formatValue(bank.bank_gold)))
        print(string.format("Minimum Bank: %s", Tools.formatValue(bank.minimum_bank)))
        print(string.format("Min Bet: %s", Tools.formatValue(bank.min_bet)))
        print(string.format("Max Bet: %s", Tools.formatValue(bank.max_bet)))
        print(string.format("Status: %s", bank.is_active == 1 and "ACTIVE" or "INACTIVE"))
        print(string.format("Last Updated: %s", bank.updated_at))
    end,

    -- Clear all transaction history (use with caution)
    clearTransactionHistory = function()
        local deleteQuery = "DELETE FROM blackjack_transactions"
        sql(deleteQuery)
        print("Cleared all blackjack transaction history.")
    end,

    -- Get recent transaction summary
    getRecentStats = function(days)
        days = days or 7

        local query = string.format([[
            SELECT
                COUNT(*) as total_games,
                SUM(CASE WHEN result = 'win' OR result = 'blackjack' THEN 1 ELSE 0 END) as player_wins,
                SUM(CASE WHEN result = 'loss' THEN 1 ELSE 0 END) as house_wins,
                SUM(CASE WHEN result = 'push' THEN 1 ELSE 0 END) as pushes,
                SUM(bet_amount) as total_wagered,
                SUM(CASE WHEN result = 'loss' THEN bet_amount ELSE 0 END) -
                SUM(CASE WHEN result = 'win' THEN bet_amount WHEN result = 'blackjack' THEN bet_amount * 1.5 ELSE 0 END) as house_profit,
                AVG(bet_amount) as avg_bet
            FROM blackjack_transactions
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL %d DAY)
        ]], days)

        local result = sql(query)

        if not result or #result == 0 or result[1].total_games == 0 then
            print(string.format("No blackjack games found in the last %d days.", days))
            return
        end

        local stats = result[1]
        print(string.format("%d-Day Blackjack Statistics:", days))
        print("==========================")
        print(string.format("Total Games: %d", stats.total_games))
        print(string.format("Player Wins: %d (%.1f%%)", stats.player_wins, (stats.player_wins / stats.total_games) * 100))
        print(string.format("House Wins: %d (%.1f%%)", stats.house_wins, (stats.house_wins / stats.total_games) * 100))
        print(string.format("Pushes: %d (%.1f%%)", stats.pushes, (stats.pushes / stats.total_games) * 100))
        print(string.format("Total Wagered: %s", Tools.formatValue(stats.total_wagered)))
        print(string.format("House Profit: %s", Tools.formatValue(stats.house_profit)))
        print(string.format("Average Bet: %s", Tools.formatValue(math.floor(stats.avg_bet))))

        if stats.total_wagered > 0 then
            local houseEdge = (stats.house_profit / stats.total_wagered) * 100
            print(string.format("House Edge: %.2f%%", houseEdge))
        end
    end
}

-- Example usage (run these commands as a GM/Admin):
--
-- Add a manager:
-- BlackjackManagerSetup.addManager("PlayerName", "AdminName")
--
-- Remove a manager:
-- BlackjackManagerSetup.removeManager("PlayerName")
--
-- List all managers:
-- BlackjackManagerSetup.listManagers()
--
-- Set bank gold to 1 million:
-- BlackjackManagerSetup.setBankGold(1000000)
--
-- Toggle bank on/off:
-- BlackjackManagerSetup.toggleBankStatus()
--
-- Set betting limits (10k min, 100k max):
-- BlackjackManagerSetup.setBettingLimits(10000, 100000)
--
-- Show current configuration:
-- BlackjackManagerSetup.showBankConfig()
--
-- Get 7-day statistics:
-- BlackjackManagerSetup.getRecentStats(7)