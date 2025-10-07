-- Blackjack Dealer NPC
-- Features: Hit, Stand, Double Down, Split Pairs, Surrender
-- GTA V dealer rules with dealer advantage
-- Gold betting system with bank management

BlackjackDealer = {
    click = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }
        player.npcGraphic = t.graphic
        player.npcColor = t.color
        player.dialogType = 0
        player.lastClick = npc.ID

        -- Check if bank has enough gold
        local bankData = BlackjackDealer.getBankData()
        if not bankData.is_active then
            player:dialogSeq({t, "The blackjack table is currently closed. Please come back later."}, 0)
            return
        end

        if bankData.bank_gold < bankData.minimum_bank then
            player:dialogSeq({t, "The house bank is too low to operate. Please inform a manager."}, 0)
            return
        end

        -- Check if player is manager
        local isManager = BlackjackDealer.isManager(player.name)
        local options = {"Play Blackjack", "Check Bank Status"}

        if isManager then
            table.insert(options, "Add Gold to Bank")
            table.insert(options, "View Statistics")
        end

        table.insert(options, "Leave")

        local choice = player:menuString("Welcome to the Blackjack table! What would you like to do?", options)

        if choice == "Play Blackjack" then
            BlackjackDealer.startGame(player, npc)
        elseif choice == "Check Bank Status" then
            BlackjackDealer.showBankStatus(player, npc)
        elseif choice == "Add Gold to Bank" and isManager then
            BlackjackDealer.addGoldToBank(player, npc)
        elseif choice == "View Statistics" and isManager then
            BlackjackDealer.viewStatistics(player, npc)
        end
    end),

    -- Get bank data from database
    getBankData = function()
        local query = "SELECT * FROM blackjack_bank WHERE npc_identifier = 'blackjack_dealer' LIMIT 1"
        local result = sql(query)
        if result and #result > 0 then
            return result[1]
        else
            return {bank_gold = 0, minimum_bank = 100000, max_bet = 100000, min_bet = 10000, is_active = false}
        end
    end,

    -- Update bank gold amount
    updateBankGold = function(newAmount)
        local query = string.format("UPDATE blackjack_bank SET bank_gold = %d WHERE npc_identifier = 'blackjack_dealer'", newAmount)
        sql(query)
    end,

    -- Check if player is manager
    isManager = function(playerName)
        local query = string.format("SELECT * FROM blackjack_managers WHERE player_name = '%s' AND can_add_gold = 1", playerName)
        local result = sql(query)
        return result and #result > 0
    end,

    -- Start blackjack game
    startGame = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }
        player.npcGraphic = t.graphic
        player.npcColor = t.color

        local bankData = BlackjackDealer.getBankData()

        -- Choose bet amount
        local betOptions = {}
        local betAmounts = {}

        for bet = bankData.min_bet, bankData.max_bet, 10000 do
            if player.money >= bet and bankData.bank_gold >= bet * 2 then -- Ensure bank can pay double (for blackjack)
                table.insert(betOptions, string.format("%s Gold", Tools.formatValue(bet)))
                table.insert(betAmounts, bet)
            end
        end

        if #betOptions == 0 then
            player:dialogSeq({t, "You don't have enough gold to place a bet, or the house bank is too low."}, 0)
            return
        end

        table.insert(betOptions, "Cancel")

        local betChoice = player:menuString("How much would you like to bet?", betOptions)

        if betChoice == "Cancel" then
            return
        end

        local betAmount = betAmounts[betChoice] or 0
        if betAmount == 0 then
            return
        end

        -- Start the actual game
        BlackjackDealer.playGame(player, npc, betAmount)
    end),

    -- Main game logic
    playGame = async(function(player, npc, betAmount)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        -- Initialize game state
        local gameState = {
            deck = BlackjackDealer.createDeck(),
            playerHands = {{}}, -- Support for splitting
            dealerHand = {},
            currentHandIndex = 1,
            betAmounts = {betAmount},
            doubled = {false},
            surrendered = {false},
            finished = {false}
        }

        -- Shuffle deck
        BlackjackDealer.shuffleDeck(gameState.deck)

        -- Remove bet from player
        player:removeGold(betAmount)

        -- Deal initial cards
        table.insert(gameState.playerHands[1], BlackjackDealer.dealCard(gameState.deck))
        table.insert(gameState.dealerHand, BlackjackDealer.dealCard(gameState.deck))
        table.insert(gameState.playerHands[1], BlackjackDealer.dealCard(gameState.deck))
        table.insert(gameState.dealerHand, BlackjackDealer.dealCard(gameState.deck)) -- Dealer hole card

        -- Show initial cards (dealer shows only first card)
        local dealerShowCard = BlackjackDealer.cardToString(gameState.dealerHand[1])
        local playerCards = BlackjackDealer.handToString(gameState.playerHands[1])
        local playerValue = BlackjackDealer.getHandValue(gameState.playerHands[1])

        -- Check for player blackjack
        if playerValue == 21 then
            BlackjackDealer.handleBlackjack(player, npc, gameState)
            return
        end

        -- Main game loop for each hand (handles splits)
        for handIndex = 1, #gameState.playerHands do
            if not gameState.surrendered[handIndex] then
                gameState.currentHandIndex = handIndex
                BlackjackDealer.playHand(player, npc, gameState, handIndex)
            end
        end

        -- Dealer plays
        BlackjackDealer.dealerPlay(gameState)

        -- Resolve all hands
        BlackjackDealer.resolveGame(player, npc, gameState)
    end),

    -- Play individual hand (supports splitting)
    playHand = async(function(player, npc, gameState, handIndex)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        while not gameState.finished[handIndex] do
            local currentHand = gameState.playerHands[handIndex]
            local handValue = BlackjackDealer.getHandValue(currentHand)

            if handValue > 21 then
                gameState.finished[handIndex] = true
                break
            end

            local handStr = BlackjackDealer.handToString(currentHand)
            local dealerShowCard = BlackjackDealer.cardToString(gameState.dealerHand[1])

            local handDisplay = ""
            if #gameState.playerHands > 1 then
                handDisplay = string.format("Hand %d: ", handIndex)
            end

            local options = {"Hit", "Stand"}

            -- Double down option (only on first two cards and not after split)
            if #currentHand == 2 and not gameState.doubled[handIndex] then
                if player.money >= gameState.betAmounts[handIndex] then
                    table.insert(options, "Double Down")
                end
            end

            -- Surrender option (only on first hand with first two cards)
            if #currentHand == 2 and handIndex == 1 and not gameState.surrendered[handIndex] then
                table.insert(options, "Surrender")
            end

            -- Split option (only if two cards of same rank and player has money)
            if #currentHand == 2 and currentHand[1].rank == currentHand[2].rank then
                if player.money >= gameState.betAmounts[handIndex] then
                    table.insert(options, "Split Pair")
                end
            end

            local choice = player:menuSeq(
                string.format("%sYour cards: %s (Value: %d)\nDealer shows: %s\n\nWhat would you like to do?",
                handDisplay, handStr, handValue, dealerShowCard),
                options,
                {}
            )

            if choice == 1 then -- Hit
                table.insert(currentHand, BlackjackDealer.dealCard(gameState.deck))
            elseif choice == 2 then -- Stand
                gameState.finished[handIndex] = true
            elseif options[choice] == "Double Down" then
                player:removeGold(gameState.betAmounts[handIndex])
                gameState.betAmounts[handIndex] = gameState.betAmounts[handIndex] * 2
                gameState.doubled[handIndex] = true
                table.insert(currentHand, BlackjackDealer.dealCard(gameState.deck))
                gameState.finished[handIndex] = true
            elseif options[choice] == "Surrender" then
                gameState.surrendered[handIndex] = true
                gameState.finished[handIndex] = true
                -- Return half bet
                player:addGold(math.floor(gameState.betAmounts[handIndex] / 2))
            elseif options[choice] == "Split Pair" then
                BlackjackDealer.splitHand(player, gameState, handIndex)
                -- Deal new cards to each split hand
                table.insert(gameState.playerHands[handIndex], BlackjackDealer.dealCard(gameState.deck))
                table.insert(gameState.playerHands[#gameState.playerHands], BlackjackDealer.dealCard(gameState.deck))
            end
        end
    end),

    -- Handle splitting pairs
    splitHand = function(player, gameState, handIndex)
        local originalHand = gameState.playerHands[handIndex]
        local newHand = {originalHand[2]} -- Second card goes to new hand
        gameState.playerHands[handIndex] = {originalHand[1]} -- First card stays

        table.insert(gameState.playerHands, newHand)
        table.insert(gameState.betAmounts, gameState.betAmounts[handIndex])
        table.insert(gameState.doubled, false)
        table.insert(gameState.surrendered, false)
        table.insert(gameState.finished, false)

        -- Remove additional bet
        player:removeGold(gameState.betAmounts[handIndex])
    end,

    -- Handle blackjack (natural 21)
    handleBlackjack = async(function(player, npc, gameState)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local dealerValue = BlackjackDealer.getHandValue(gameState.dealerHand)
        local payout = 0

        if dealerValue == 21 then
            -- Push - return bet
            player:addGold(gameState.betAmounts[1])
            player:dialogSeq({t, "Both you and dealer have blackjack! It's a push. Your bet is returned."}, 0)
            BlackjackDealer.logTransaction(player.name, gameState.betAmounts[1], "push", 0,
                BlackjackDealer.handToString(gameState.playerHands[1]), BlackjackDealer.handToString(gameState.dealerHand))
        else
            -- Player blackjack wins 3:2
            payout = math.floor(gameState.betAmounts[1] * 2.5)
            player:addGold(payout)

            local bankData = BlackjackDealer.getBankData()
            BlackjackDealer.updateBankGold(bankData.bank_gold - (payout - gameState.betAmounts[1]))

            player:dialogSeq({t, string.format("Blackjack! You win %s gold!", Tools.formatValue(payout))}, 0)
            BlackjackDealer.logTransaction(player.name, gameState.betAmounts[1], "blackjack", payout,
                BlackjackDealer.handToString(gameState.playerHands[1]), BlackjackDealer.handToString(gameState.dealerHand))
        end
    end),

    -- Dealer plays according to GTA V rules (hits on soft 17)
    dealerPlay = function(gameState)
        while true do
            local dealerValue = BlackjackDealer.getHandValue(gameState.dealerHand)
            local isSoft = BlackjackDealer.isSoftHand(gameState.dealerHand)

            -- GTA V rules: Dealer hits on soft 17, stands on hard 17
            if dealerValue > 17 then
                break
            elseif dealerValue == 17 and not isSoft then
                break
            else
                table.insert(gameState.dealerHand, BlackjackDealer.dealCard(gameState.deck))
            end
        end
    end,

    -- Resolve all hands and payouts
    resolveGame = async(function(player, npc, gameState)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local dealerValue = BlackjackDealer.getHandValue(gameState.dealerHand)
        local dealerBusted = dealerValue > 21
        local totalPayout = 0
        local bankData = BlackjackDealer.getBankData()

        local results = {}

        for handIndex = 1, #gameState.playerHands do
            if not gameState.surrendered[handIndex] then
                local playerValue = BlackjackDealer.getHandValue(gameState.playerHands[handIndex])
                local playerBusted = playerValue > 21
                local betAmount = gameState.betAmounts[handIndex]
                local payout = 0
                local result = ""

                if playerBusted then
                    result = "loss"
                    -- Player loses bet (already removed)
                elseif dealerBusted then
                    result = "win"
                    payout = betAmount * 2 -- Return bet + winnings
                    totalPayout = totalPayout + payout
                elseif playerValue > dealerValue then
                    result = "win"
                    payout = betAmount * 2
                    totalPayout = totalPayout + payout
                elseif playerValue == dealerValue then
                    result = "push"
                    payout = betAmount -- Return bet only
                    totalPayout = totalPayout + payout
                else
                    result = "loss"
                    -- Player loses bet
                end

                if payout > 0 then
                    player:addGold(payout)
                end

                table.insert(results, {hand = handIndex, result = result, payout = payout, bet = betAmount})

                -- Log transaction
                BlackjackDealer.logTransaction(player.name, betAmount, result, payout,
                    BlackjackDealer.handToString(gameState.playerHands[handIndex]),
                    BlackjackDealer.handToString(gameState.dealerHand))
            end
        end

        -- Update bank
        local totalBetsLost = 0
        for _, result in ipairs(results) do
            if result.result == "loss" then
                totalBetsLost = totalBetsLost + result.bet
            elseif result.result == "win" then
                totalBetsLost = totalBetsLost - (result.payout - result.bet)
            end
        end

        BlackjackDealer.updateBankGold(bankData.bank_gold + totalBetsLost)

        -- Show results
        local resultText = string.format("Dealer cards: %s (Value: %d)\n\n",
            BlackjackDealer.handToString(gameState.dealerHand), dealerValue)

        for _, result in ipairs(results) do
            local handDisplay = ""
            if #gameState.playerHands > 1 then
                handDisplay = string.format("Hand %d: ", result.hand)
            end

            local playerValue = BlackjackDealer.getHandValue(gameState.playerHands[result.hand])
            resultText = resultText .. string.format("%sYour cards: %s (Value: %d) - %s\n",
                handDisplay, BlackjackDealer.handToString(gameState.playerHands[result.hand]),
                playerValue, string.upper(result.result))
        end

        player:dialogSeq({t, resultText}, 0)
    end),

    -- Card and deck management functions
    createDeck = function()
        local deck = {}
        local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
        local ranks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}
        local values = {11, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10}

        for _, suit in ipairs(suits) do
            for i, rank in ipairs(ranks) do
                table.insert(deck, {suit = suit, rank = rank, value = values[i]})
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

    dealCard = function(deck)
        return table.remove(deck, 1)
    end,

    getHandValue = function(hand)
        local value = 0
        local aces = 0

        for _, card in ipairs(hand) do
            if card.rank == "A" then
                aces = aces + 1
                value = value + 11
            else
                value = value + card.value
            end
        end

        -- Adjust for aces
        while value > 21 and aces > 0 do
            value = value - 10
            aces = aces - 1
        end

        return value
    end,

    isSoftHand = function(hand)
        local value = 0
        local aces = 0

        for _, card in ipairs(hand) do
            if card.rank == "A" then
                aces = aces + 1
                value = value + 11
            else
                value = value + card.value
            end
        end

        return aces > 0 and value <= 21
    end,

    cardToString = function(card)
        return card.rank .. " of " .. card.suit
    end,

    handToString = function(hand)
        local cardStrings = {}
        for _, card in ipairs(hand) do
            table.insert(cardStrings, BlackjackDealer.cardToString(card))
        end
        return table.concat(cardStrings, ", ")
    end,

    -- Manager functions
    addGoldToBank = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local amount = player:inputSeq(
            "How much gold would you like to add to the bank?",
            "Amount:",
            "Adding " .. (amount or "0") .. " gold to bank.",
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

        player:removeGold(amount)
        local bankData = BlackjackDealer.getBankData()
        BlackjackDealer.updateBankGold(bankData.bank_gold + amount)

        player:dialogSeq({t, string.format("Added %s gold to the bank. New bank total: %s gold.",
            Tools.formatValue(amount), Tools.formatValue(bankData.bank_gold + amount))}, 0)
    end),

    showBankStatus = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local bankData = BlackjackDealer.getBankData()
        local status = bankData.is_active and "Active" or "Inactive"

        player:dialogSeq({t, string.format(
            "Bank Status: %s\nBank Gold: %s\nMinimum Bank: %s\nBet Range: %s - %s gold",
            status, Tools.formatValue(bankData.bank_gold), Tools.formatValue(bankData.minimum_bank),
            Tools.formatValue(bankData.min_bet), Tools.formatValue(bankData.max_bet))}, 0)
    end),

    viewStatistics = async(function(player, npc)
        local t = {
            graphic = convertGraphic(npc.look, "monster"),
            color = npc.lookColor
        }

        local query = [[
            SELECT
                COUNT(*) as total_games,
                SUM(CASE WHEN result = 'win' OR result = 'blackjack' THEN 1 ELSE 0 END) as player_wins,
                SUM(CASE WHEN result = 'loss' THEN 1 ELSE 0 END) as house_wins,
                SUM(bet_amount) as total_wagered,
                SUM(CASE WHEN result = 'loss' THEN bet_amount ELSE 0 END) -
                SUM(CASE WHEN result = 'win' THEN bet_amount WHEN result = 'blackjack' THEN bet_amount * 1.5 ELSE 0 END) as house_profit
            FROM blackjack_transactions
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ]]

        local result = sql(query)
        if result and #result > 0 then
            local stats = result[1]
            player:dialogSeq({t, string.format(
                "7-Day Statistics:\nTotal Games: %d\nPlayer Wins: %d\nHouse Wins: %d\nTotal Wagered: %s\nHouse Profit: %s",
                stats.total_games, stats.player_wins, stats.house_wins,
                Tools.formatValue(stats.total_wagered), Tools.formatValue(stats.house_profit))}, 0)
        end
    end),

    -- Log transaction to database
    logTransaction = function(playerName, betAmount, result, payout, playerHand, dealerHand)
        local query = string.format(
            "INSERT INTO blackjack_transactions (player_name, bet_amount, result, payout, player_hand, dealer_hand) VALUES ('%s', %d, '%s', %d, '%s', '%s')",
            playerName, betAmount, result, payout, playerHand, dealerHand
        )
        sql(query)
    end
}