-- Poker Dealer NPC
-- Facilitates player vs player poker games with account management
-- Features: Texas Hold'em, Account system, Auto re-popup, Turn management

PokerDealer = {
    activePopups = {}, -- Track active popups for re-sending
    gameTimers = {}, -- Track turn timers

    click = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }
        player.npcGraphic = t.graphic
        player.npcColor = t.color
        player.dialogType = 0
        player.lastClick = npc.ID

        -- Check if NPC is active
        if not PokerDealer.isNPCActive() then
            player:dialogSeq({t, "The poker room is currently closed. Please come back later."}, 0)
            return
        end

        local account = PokerDealer.getPlayerAccount(player.name)
        local isManager = PokerDealer.isManager(player.name)
        local options = {"Manage Account", "Join Table", "View Tables"}

        -- Add manager options if player is a poker manager
        if isManager then
            table.insert(options, "Manager Options")
        end

        table.insert(options, "Leave")

        local choice = player:menuString("Welcome to the Poker Room! What would you like to do?", options)

        if choice == "Manage Account" then
            PokerDealer.manageAccount(player, npc)
        elseif choice == "Join Table" then
            PokerDealer.joinTable(player, npc)
        elseif choice == "View Tables" then
            PokerDealer.viewTables(player, npc)
        elseif choice == "Manager Options" and isManager then
            PokerDealer.managerOptions(player, npc)
        end
    end),

    -- Account Management System
    manageAccount = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local account = PokerDealer.getPlayerAccount(player.name)

        local options = {"Deposit Gold", "Withdraw Chips", "Check Balance"}
        table.insert(options, "Back")

        local choice = player:menuString(
            string.format("Poker Account Management\nCurrent Chip Balance: %s\n\nWhat would you like to do?",
            Tools.formatValue(account.chip_balance)), options)

        if choice == "Deposit Gold" then
            PokerDealer.depositGold(player, npc, account)
        elseif choice == "Withdraw Chips" then
            PokerDealer.withdrawChips(player, npc, account)
        elseif choice == "Check Balance" then
            PokerDealer.showAccountInfo(player, npc, account)
        elseif choice == "Back" then
            PokerDealer.click(player, npc)
        end
    end),

    depositGold = async(function(player, npc, account)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local amount = player:inputSeq(
            "How much gold would you like to convert to poker chips? (1 gold = 1 chip)",
            "Amount:",
            "Converting " .. (amount or "0") .. " gold to chips.",
            {},
            {}
        )

        amount = tonumber(amount)
        if not amount or amount <= 0 then
            player:dialogSeq({t, "Invalid amount entered."}, 0)
            return
        end

        if player.money < amount then
            player:dialogSeq({t, "You don't have enough gold."}, 0)
            return
        end

        -- Process deposit
        player:removeGold(amount)
        PokerDealer.updateChipBalance(player.name, account.chip_balance + amount)
        PokerDealer.logTransaction(player.name, "deposit", amount, account.chip_balance, account.chip_balance + amount, "Gold to chips conversion")

        player:dialogSeq({t, string.format("Successfully converted %s gold to poker chips!\nNew chip balance: %s",
            Tools.formatValue(amount), Tools.formatValue(account.chip_balance + amount))}, 0)
    end),

    withdrawChips = async(function(player, npc, account)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        -- Check if player is in an active game
        if PokerDealer.isPlayerInGame(player.name) then
            player:dialogSeq({t, "You cannot withdraw chips while in an active poker game. Please leave the table first."}, 0)
            return
        end

        local amount = player:inputSeq(
            string.format("How many chips would you like to convert to gold? (1 chip = 1 gold)\nAvailable chips: %s",
            Tools.formatValue(account.chip_balance)),
            "Amount:",
            "Converting " .. (amount or "0") .. " chips to gold.",
            {},
            {}
        )

        amount = tonumber(amount)
        if not amount or amount <= 0 then
            player:dialogSeq({t, "Invalid amount entered."}, 0)
            return
        end

        if account.chip_balance < amount then
            player:dialogSeq({t, "You don't have enough chips."}, 0)
            return
        end

        -- Process withdrawal
        player:addGold(amount)
        PokerDealer.updateChipBalance(player.name, account.chip_balance - amount)
        PokerDealer.logTransaction(player.name, "withdraw", amount, account.chip_balance, account.chip_balance - amount, "Chips to gold conversion")

        player:dialogSeq({t, string.format("Successfully converted %s chips to gold!\nRemaining chip balance: %s",
            Tools.formatValue(amount), Tools.formatValue(account.chip_balance - amount))}, 0)
    end),

    showAccountInfo = async(function(player, npc, account)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        -- Get recent transaction history
        local query = string.format(
            "SELECT * FROM poker_transactions WHERE player_name = '%s' ORDER BY created_at DESC LIMIT 5",
            player.name
        )
        local transactions = sql(query)

        local historyText = ""
        if transactions and #transactions > 0 then
            historyText = "\n\nRecent Transactions:\n"
            for _, trans in ipairs(transactions) do
                historyText = historyText .. string.format("• %s: %s chips (%s)\n",
                    string.upper(trans.transaction_type),
                    Tools.formatValue(trans.amount),
                    trans.created_at:sub(1, 10)
                )
            end
        end

        player:dialogSeq({t, string.format(
            "Poker Account Information\n\nCurrent Balance: %s chips\nTotal Deposited: %s gold\nTotal Withdrawn: %s gold\nAccount Created: %s%s",
            Tools.formatValue(account.chip_balance),
            Tools.formatValue(account.total_deposited),
            Tools.formatValue(account.total_withdrawn),
            account.created_at:sub(1, 10),
            historyText
        )}, 0)
    end),

    -- Table Management
    joinTable = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local account = PokerDealer.getPlayerAccount(player.name)
        if account.chip_balance < 20000 then -- Min buyin check
            player:dialogSeq({t, "You need at least 20,000 chips to join a poker table. Please deposit more gold first."}, 0)
            return
        end

        -- Check if already in a game
        if PokerDealer.isPlayerInGame(player.name) then
            player:dialogSeq({t, "You are already seated at a poker table."}, 0)
            return
        end

        local tables = PokerDealer.getAvailableTables()
        local tableOptions = {}

        for _, table in ipairs(tables) do
            local currentPlayers = PokerDealer.getTablePlayerCount(table.id)
            table.insert(tableOptions, string.format("%s (%d/%d players) - Blinds: %s/%s",
                table.table_name, currentPlayers, table.max_players,
                Tools.formatValue(table.small_blind), Tools.formatValue(table.big_blind)))
        end

        if #tableOptions == 0 then
            player:dialogSeq({t, "No poker tables are currently available."}, 0)
            return
        end

        table.insert(tableOptions, "Cancel")

        local choice = player:menuString("Select a poker table to join:", tableOptions)

        if choice <= #tables then
            PokerDealer.joinSpecificTable(player, npc, tables[choice])
        end
    end),

    joinSpecificTable = async(function(player, npc, tableData)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local account = PokerDealer.getPlayerAccount(player.name)

        -- Ask for buyin amount
        local buyinAmount = player:inputSeq(
            string.format("Enter your buy-in amount (Min: %s, Max: %s chips):",
            Tools.formatValue(tableData.min_buyin), Tools.formatValue(tableData.max_buyin)),
            "Buy-in amount:",
            "Buying in for " .. (buyinAmount or "0") .. " chips.",
            {},
            {}
        )

        buyinAmount = tonumber(buyinAmount)
        if not buyinAmount or buyinAmount < tableData.min_buyin or buyinAmount > tableData.max_buyin then
            player:dialogSeq({t, "Invalid buy-in amount."}, 0)
            return
        end

        if account.chip_balance < buyinAmount then
            player:dialogSeq({t, "You don't have enough chips for this buy-in."}, 0)
            return
        end

        -- Join the table
        if PokerDealer.addPlayerToTable(player.name, tableData.id, buyinAmount) then
            PokerDealer.updateChipBalance(player.name, account.chip_balance - buyinAmount)
            PokerDealer.logTransaction(player.name, "buyin", buyinAmount, account.chip_balance, account.chip_balance - buyinAmount, "Table buy-in")

            player:dialogSeq({t, string.format("Successfully joined %s with %s chips!\nWaiting for more players or next hand to begin...",
                tableData.table_name, Tools.formatValue(buyinAmount))}, 0)

            -- Check if we can start a game
            PokerDealer.checkStartGame(tableData.id)
        else
            player:dialogSeq({t, "Failed to join table. It may be full."}, 0)
        end
    end),

    viewTables = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local tables = PokerDealer.getAllTables()
        local tableInfo = "Active Poker Tables:\n\n"

        for _, table in ipairs(tables) do
            local currentPlayers = PokerDealer.getTablePlayerCount(table.id)
            local gameState = PokerDealer.getTableGameState(table.id)

            tableInfo = tableInfo .. string.format(
                "%s\n• Players: %d/%d\n• Blinds: %s/%s\n• Status: %s\n• Buy-in: %s - %s\n\n",
                table.table_name,
                currentPlayers,
                table.max_players,
                Tools.formatValue(table.small_blind),
                Tools.formatValue(table.big_blind),
                gameState or "Waiting",
                Tools.formatValue(table.min_buyin),
                Tools.formatValue(table.max_buyin)
            )
        end

        player:dialogSeq({t, tableInfo}, 0)
    end),

    -- Game Management and Turn System
    startGame = function(tableId)
        local players = PokerDealer.getTablePlayers(tableId)
        if #players < 2 then
            return false
        end

        -- Create new game
        local gameId = PokerDealer.createNewGame(tableId, players)
        if gameId then
            PokerDealer.dealPreflop(gameId)
            PokerDealer.startBettingRound(gameId, "preflop")
            return true
        end
        return false
    end,

    dealPreflop = function(gameId)
        local game = PokerDealer.getGameData(gameId)
        local players = PokerDealer.getGamePlayers(gameId)

        -- Create and shuffle deck
        local deck = PokerDealer.createDeck()
        PokerDealer.shuffleDeck(deck)

        -- Deal hole cards to each player
        for _, player in ipairs(players) do
            local card1 = table.remove(deck, 1)
            local card2 = table.remove(deck, 1)
            local holeCards = card1.rank .. card1.suit .. "," .. card2.rank .. card2.suit

            PokerDealer.setPlayerHoleCards(gameId, player.player_name, holeCards)
        end

        -- Save deck state
        PokerDealer.saveDeckState(gameId, deck)

        -- Post blinds
        PokerDealer.postBlinds(gameId)
    end,

    startBettingRound = function(gameId, round)
        PokerDealer.updateGameState(gameId, round)

        local firstPlayer = PokerDealer.getFirstPlayerToAct(gameId, round)
        if firstPlayer then
            PokerDealer.setCurrentTurn(gameId, firstPlayer)
            PokerDealer.showPlayerOptions(gameId, firstPlayer)
        end
    end,

    showPlayerOptions = async(function(gameId, playerName)
        local player = Player(playerName)
        if not player then return end

        local gameData = PokerDealer.getGameData(gameId)
        local playerData = PokerDealer.getPlayerGameData(gameId, playerName)
        local communityCards = PokerDealer.getCommunityCards(gameId)

        -- Clear any existing popup timer
        if PokerDealer.gameTimers[gameId .. "_" .. playerName] then
            PokerDealer.gameTimers[gameId .. "_" .. playerName] = nil
        end

        local t = {
            graphic = convertGraphic(65, "monster"), -- Poker dealer graphic
            color = 0
        }
        player.npcGraphic = t.graphic
        player.npcColor = t.color
        player.dialogType = 0

        -- Build display text
        local displayText = PokerDealer.buildGameDisplay(gameData, playerData, communityCards)

        -- Get available actions
        local actions = PokerDealer.getAvailableActions(gameData, playerData)

        -- Store popup info for re-sending
        PokerDealer.activePopups[playerName] = {
            gameId = gameId,
            displayText = displayText,
            actions = actions,
            startTime = os.time()
        }

        -- Show popup with actions
        local choice = player:menuString(displayText, actions)

        -- Clear popup tracker
        PokerDealer.activePopups[playerName] = nil

        -- Process action
        PokerDealer.processPlayerAction(gameId, playerName, actions[choice] or "timeout", choice)
    end),

    -- Re-popup system for accidentally closed windows
    startPopupTimer = function(playerName)
        local popupData = PokerDealer.activePopups[playerName]
        if not popupData then return end

        -- Set timer to re-show popup after 5 seconds
        local timerId = playerName .. "_popup_retry"

        Timer(5000, function() -- 5 second delay
            local currentPopup = PokerDealer.activePopups[playerName]
            if currentPopup and currentPopup.startTime == popupData.startTime then
                -- Popup is still active, re-show it
                local player = Player(playerName)
                if player then
                    PokerDealer.showPlayerOptions(currentPopup.gameId, playerName)
                end
            end
        end, timerId)
    end,

    buildGameDisplay = function(gameData, playerData, communityCards)
        local display = string.format("=== POKER TABLE ===\n\n")

        -- Show pot
        display = display .. string.format("POT: %s chips\n\n", Tools.formatValue(gameData.pot_amount))

        -- Show community cards if any
        if communityCards and communityCards ~= "" then
            display = display .. "Community Cards: " .. PokerDealer.formatCards(communityCards) .. "\n\n"
        end

        -- Show player's hole cards
        if playerData.hole_cards then
            display = display .. "Your Cards: " .. PokerDealer.formatCards(playerData.hole_cards) .. "\n\n"
        end

        -- Show current bet info
        display = display .. string.format("Current Bet: %s chips\n", Tools.formatValue(gameData.current_bet))
        display = display .. string.format("Your Chips: %s\n", Tools.formatValue(playerData.chip_count))

        if playerData.current_bet > 0 then
            display = display .. string.format("Your Bet This Round: %s chips\n", Tools.formatValue(playerData.current_bet))
        end

        display = display .. "\nWhat would you like to do?"

        return display
    end,

    getAvailableActions = function(gameData, playerData)
        local actions = {}
        local callAmount = gameData.current_bet - playerData.current_bet

        -- Fold (always available unless all-in)
        if not playerData.is_all_in then
            table.insert(actions, "Fold")
        end

        -- Check/Call
        if callAmount == 0 then
            table.insert(actions, "Check")
        elseif callAmount > 0 then
            if callAmount >= playerData.chip_count then
                table.insert(actions, "Call All-In (" .. Tools.formatValue(playerData.chip_count) .. ")")
            else
                table.insert(actions, "Call (" .. Tools.formatValue(callAmount) .. ")")
            end
        end

        -- Bet/Raise (if player has chips beyond call amount)
        if playerData.chip_count > callAmount and not playerData.is_all_in then
            if gameData.current_bet == 0 then
                table.insert(actions, "Bet")
            else
                table.insert(actions, "Raise")
            end
        end

        return actions
    end,

    processPlayerAction = async(function(gameId, playerName, action, choiceIndex)
        local gameData = PokerDealer.getGameData(gameId)
        local playerData = PokerDealer.getPlayerGameData(gameId, playerName)

        if action == "Fold" then
            PokerDealer.foldPlayer(gameId, playerName)
        elseif action == "Check" then
            -- No additional bet needed
        elseif action:find("Call") then
            local callAmount = gameData.current_bet - playerData.current_bet
            PokerDealer.addPlayerBet(gameId, playerName, callAmount)
        elseif action == "Bet" or action == "Raise" then
            PokerDealer.handleBetRaise(gameId, playerName, action)
            return -- Will handle next player in bet function
        end

        -- Move to next player
        PokerDealer.nextPlayer(gameId)
    end),

    handleBetRaise = async(function(gameId, playerName, action)
        local player = Player(playerName)
        if not player then return end

        local gameData = PokerDealer.getGameData(gameId)
        local playerData = PokerDealer.getPlayerGameData(gameId, playerName)
        local callAmount = gameData.current_bet - playerData.current_bet
        local minRaise = gameData.current_bet == 0 and gameData.big_blind or gameData.current_bet * 2

        local t = {
            graphic = convertGraphic(65, "monster"),
            color = 0
        }
        player.npcGraphic = t.graphic
        player.npcColor = t.color

        local betAmount = player:inputSeq(
            string.format("Enter %s amount (Min: %s, Max: %s chips):",
            action:lower(),
            Tools.formatValue(math.max(minRaise, callAmount + gameData.big_blind)),
            Tools.formatValue(playerData.chip_count)),
            "Amount:",
            "Betting " .. (betAmount or "0") .. " chips.",
            {},
            {}
        )

        betAmount = tonumber(betAmount)
        if betAmount and betAmount > 0 and betAmount <= playerData.chip_count then
            PokerDealer.addPlayerBet(gameId, playerName, betAmount)
            PokerDealer.updateCurrentBet(gameId, playerData.current_bet + betAmount)
        end

        PokerDealer.nextPlayer(gameId)
    end),

    -- Utility Functions
    getPlayerAccount = function(playerName)
        local query = string.format("SELECT * FROM poker_accounts WHERE player_name = '%s'", playerName)
        local result = sql(query)

        if not result or #result == 0 then
            -- Create new account
            local insertQuery = string.format("INSERT INTO poker_accounts (player_name) VALUES ('%s')", playerName)
            sql(insertQuery)
            return {player_name = playerName, chip_balance = 0, total_deposited = 0, total_withdrawn = 0, created_at = os.date("%Y-%m-%d %H:%M:%S")}
        end

        return result[1]
    end,

    updateChipBalance = function(playerName, newBalance)
        local query = string.format("UPDATE poker_accounts SET chip_balance = %d WHERE player_name = '%s'", newBalance, playerName)
        sql(query)
    end,

    logTransaction = function(playerName, transType, amount, balanceBefore, balanceAfter, description)
        local query = string.format(
            "INSERT INTO poker_transactions (player_name, transaction_type, amount, balance_before, balance_after, description) VALUES ('%s', '%s', %d, %d, %d, '%s')",
            playerName, transType, amount, balanceBefore, balanceAfter, description or ""
        )
        sql(query)
    end,

    isNPCActive = function()
        local query = "SELECT setting_value FROM poker_settings WHERE setting_name = 'npc_active'"
        local result = sql(query)
        return result and #result > 0 and result[1].setting_value == "1"
    end,

    isPlayerInGame = function(playerName)
        local query = string.format("SELECT * FROM poker_players WHERE player_name = '%s' AND is_sitting_out = 0", playerName)
        local result = sql(query)
        return result and #result > 0
    end,

    getAvailableTables = function()
        local query = "SELECT * FROM poker_tables WHERE is_active = 1"
        local result = sql(query)
        return result or {}
    end,

    getAllTables = function()
        local query = "SELECT * FROM poker_tables"
        local result = sql(query)
        return result or {}
    end,

    getTablePlayerCount = function(tableId)
        local query = string.format("SELECT COUNT(*) as count FROM poker_players p JOIN poker_games g ON p.game_id = g.id WHERE g.table_id = %d AND p.is_sitting_out = 0", tableId)
        local result = sql(query)
        return result and result[1] and result[1].count or 0
    end,

    getTableGameState = function(tableId)
        local query = string.format("SELECT game_state FROM poker_games WHERE table_id = %d AND game_state != 'finished' ORDER BY id DESC LIMIT 1", tableId)
        local result = sql(query)
        return result and result[1] and result[1].game_state or "Waiting for players"
    end,

    createDeck = function()
        local deck = {}
        local suits = {"h", "d", "c", "s"} -- hearts, diamonds, clubs, spades
        local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"}

        for _, suit in ipairs(suits) do
            for _, rank in ipairs(ranks) do
                table.insert(deck, {rank = rank, suit = suit})
            end
        end

        return deck
    end,

    shuffleDeck = function(deck)
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end,

    formatCards = function(cardString)
        if not cardString or cardString == "" then return "None" end

        local cards = {}
        for card in cardString:gmatch("([^,]+)") do
            if #card >= 2 then
                local rank = card:sub(1, 1)
                local suit = card:sub(2, 2)
                local suitName = ({h = "♥", d = "♦", c = "♣", s = "♠"})[suit] or suit
                table.insert(cards, rank .. suitName)
            end
        end
        return table.concat(cards, " ")
    end,

    -- Check if player is manager
    isManager = function(playerName)
        local query = string.format("SELECT * FROM poker_managers WHERE player_name = '%s'", playerName)
        local result = sql(query)
        return result and #result > 0
    end,

    -- Check specific manager permissions
    hasManagerPermission = function(playerName, permission)
        local query = string.format("SELECT %s FROM poker_managers WHERE player_name = '%s'", permission, playerName)
        local result = sql(query)
        return result and #result > 0 and result[1][permission] == 1
    end,

    -- Manager Functions
    managerOptions = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local options = {}

        -- Check permissions and add appropriate options
        if PokerDealer.hasManagerPermission(player.name, "can_toggle_npc") then
            table.insert(options, "Toggle NPC On/Off")
        end

        if PokerDealer.hasManagerPermission(player.name, "can_manage_tables") then
            table.insert(options, "Manage Tables")
        end

        if PokerDealer.hasManagerPermission(player.name, "can_view_stats") then
            table.insert(options, "View Statistics")
        end

        if PokerDealer.hasManagerPermission(player.name, "can_force_end_games") then
            table.insert(options, "View/End Games")
        end

        table.insert(options, "Back")

        if #options == 1 then -- Only "Back" option
            player:dialogSeq({t, "You don't have any manager permissions."}, 0)
            return
        end

        local choice = player:menuString("Poker Manager Options:", options)

        if choice == "Toggle NPC On/Off" then
            PokerDealer.toggleNPCStatus()
            local status = PokerDealer.isNPCActive() and "ACTIVE" or "INACTIVE"
            player:dialogSeq({t, "Poker NPC is now " .. status}, 0)
        elseif choice == "Manage Tables" then
            PokerDealer.manageTables(player, npc)
        elseif choice == "View Statistics" then
            PokerDealer.viewManagerStats(player, npc)
        elseif choice == "View/End Games" then
            PokerDealer.manageGames(player, npc)
        elseif choice == "Back" then
            PokerDealer.click(player, npc)
        end
    end),

    toggleNPCStatus = function()
        local currentQuery = "SELECT setting_value FROM poker_settings WHERE setting_name = 'npc_active'"
        local result = sql(currentQuery)
        local newStatus = "1"

        if result and #result > 0 and result[1].setting_value == "1" then
            newStatus = "0"
        end

        local updateQuery = string.format("UPDATE poker_settings SET setting_value = '%s' WHERE setting_name = 'npc_active'", newStatus)
        sql(updateQuery)
    end,

    manageTables = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local options = {"View All Tables", "Toggle Table Status", "Back"}
        local choice = player:menuString("Table Management:", options)

        if choice == "View All Tables" then
            PokerDealer.showDetailedTables(player, npc)
        elseif choice == "Toggle Table Status" then
            PokerDealer.toggleTableStatus(player, npc)
        elseif choice == "Back" then
            PokerDealer.managerOptions(player, npc)
        end
    end),

    toggleTableStatus = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local tables = PokerDealer.getAllTables()
        local tableOptions = {}

        for _, table in ipairs(tables) do
            local status = table.is_active == 1 and "Active" or "Inactive"
            table.insert(tableOptions, string.format("%s (%s)", table.table_name, status))
        end

        if #tableOptions == 0 then
            player:dialogSeq({t, "No poker tables found."}, 0)
            return
        end

        table.insert(tableOptions, "Cancel")

        local choice = player:menuString("Select table to toggle:", tableOptions)

        if choice <= #tables then
            local table = tables[choice]
            local newStatus = table.is_active == 1 and 0 or 1

            local updateQuery = string.format("UPDATE poker_tables SET is_active = %d WHERE id = %d", newStatus, table.id)
            sql(updateQuery)

            player:dialogSeq({t, string.format("Table '%s' is now %s", table.table_name, newStatus == 1 and "ACTIVE" or "INACTIVE")}, 0)
        end
    end),

    showDetailedTables = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local tables = PokerDealer.getAllTables()
        local tableInfo = "Detailed Table Information:\n\n"

        for _, table in ipairs(tables) do
            local currentPlayers = PokerDealer.getTablePlayerCount(table.id)
            local gameState = PokerDealer.getTableGameState(table.id)

            tableInfo = tableInfo .. string.format(
                "ID: %d | %s\n• Players: %d/%d\n• Blinds: %s/%s\n• Status: %s (%s)\n• Buy-in: %s - %s\n\n",
                table.id,
                table.table_name,
                currentPlayers,
                table.max_players,
                Tools.formatValue(table.small_blind),
                Tools.formatValue(table.big_blind),
                table.is_active == 1 and "Active" or "Inactive",
                gameState or "Waiting",
                Tools.formatValue(table.min_buyin),
                Tools.formatValue(table.max_buyin)
            )
        end

        player:dialogSeq({t, tableInfo}, 0)
    end),

    viewManagerStats = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        -- Get 7-day statistics
        local query = [[
            SELECT
                COUNT(DISTINCT player_name) as unique_players,
                SUM(CASE WHEN transaction_type = 'deposit' THEN amount ELSE 0 END) as total_deposits,
                SUM(CASE WHEN transaction_type = 'withdraw' THEN amount ELSE 0 END) as total_withdrawals,
                COUNT(*) as total_transactions
            FROM poker_transactions
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ]]

        local result = sql(query)
        local stats = result and result[1]

        -- Get current total chip balance
        local balanceQuery = "SELECT SUM(chip_balance) as total_chips FROM poker_accounts"
        local balanceResult = sql(balanceQuery)
        local totalChips = balanceResult and balanceResult[1] and balanceResult[1].total_chips or 0

        -- Get active games count
        local gamesQuery = "SELECT COUNT(*) as active_games FROM poker_games WHERE game_state != 'finished'"
        local gamesResult = sql(gamesQuery)
        local activeGames = gamesResult and gamesResult[1] and gamesResult[1].active_games or 0

        local statsText = "7-Day Poker Statistics:\n\n"
        if stats then
            statsText = statsText .. string.format(
                "Unique Players: %d\nTotal Deposits: %s gold\nTotal Withdrawals: %s gold\nNet Gold In System: %s\nTotal Chip Balance: %s chips\nTotal Transactions: %d\nActive Games: %d",
                stats.unique_players,
                Tools.formatValue(stats.total_deposits),
                Tools.formatValue(stats.total_withdrawals),
                Tools.formatValue(stats.total_deposits - stats.total_withdrawals),
                Tools.formatValue(totalChips),
                stats.total_transactions,
                activeGames
            )
        else
            statsText = statsText .. "No activity found in the last 7 days."
        end

        player:dialogSeq({t, statsText}, 0)
    end),

    manageGames = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local options = {"View Active Games", "Force End Game", "Back"}
        local choice = player:menuString("Game Management:", options)

        if choice == "View Active Games" then
            PokerDealer.showActiveGames(player, npc)
        elseif choice == "Force End Game" then
            PokerDealer.forceEndGameManager(player, npc)
        elseif choice == "Back" then
            PokerDealer.managerOptions(player, npc)
        end
    end),

    showActiveGames = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

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
            player:dialogSeq({t, "No active poker games found."}, 0)
            return
        end

        local gamesText = "Active Poker Games:\n\n"
        for _, game in ipairs(result) do
            gamesText = gamesText .. string.format(
                "Game ID: %d | Table: %s\nState: %s | Players: %d\nPot: %s | Turn: %s\n\n",
                game.id,
                game.table_name,
                game.game_state,
                game.player_count,
                Tools.formatValue(game.pot_amount or 0),
                game.current_player_turn or "None"
            )
        end

        player:dialogSeq({t, gamesText}, 0)
    end),

    forceEndGameManager = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local gameId = player:inputSeq(
            "Enter the Game ID to force end (WARNING: This will return all chips to player accounts):",
            "Game ID:",
            "Ending game " .. (gameId or "0"),
            {},
            {}
        )

        gameId = tonumber(gameId)
        if not gameId or gameId <= 0 then
            player:dialogSeq({t, "Invalid game ID entered."}, 0)
            return
        end

        -- Check if game exists
        local query = string.format("SELECT * FROM poker_games WHERE id = %d AND game_state != 'finished'", gameId)
        local result = sql(query)

        if not result or #result == 0 then
            player:dialogSeq({t, "Game not found or already finished."}, 0)
            return
        end

        local confirm = player:menuSeq(
            string.format("Are you sure you want to force end game %d? This will return all chips to player accounts.", gameId),
            {"Yes, Force End", "Cancel"},
            {}
        )

        if confirm == 1 then
            PokerDealer.forceEndGame(gameId)
            player:dialogSeq({t, string.format("Game %d has been force ended. All chips returned to player accounts.", gameId)}, 0)
        end
    end),

    forceEndGame = function(gameId)
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
                    "INSERT INTO poker_transactions (player_name, transaction_type, amount, balance_before, balance_after, description) VALUES ('%s', 'cashout', %d, 0, 0, 'Manager force ended game refund')",
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
    end
}