-- Poker Game Logic and Hand Evaluation
-- Handles game flow, hand rankings, and showdown logic

PokerGameLogic = {
    -- Hand Rankings (0 = highest, 9 = lowest)
    HAND_RANKINGS = {
        ROYAL_FLUSH = 0,
        STRAIGHT_FLUSH = 1,
        FOUR_OF_A_KIND = 2,
        FULL_HOUSE = 3,
        FLUSH = 4,
        STRAIGHT = 5,
        THREE_OF_A_KIND = 6,
        TWO_PAIR = 7,
        PAIR = 8,
        HIGH_CARD = 9
    },

    -- Card values for comparison
    CARD_VALUES = {
        ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8,
        ["9"] = 9, ["T"] = 10, ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14
    },

    -- Main hand evaluation function
    evaluateHand = function(holeCards, communityCards)
        local allCards = {}

        -- Parse hole cards
        if holeCards and holeCards ~= "" then
            for card in holeCards:gmatch("([^,]+)") do
                if #card >= 2 then
                    table.insert(allCards, {rank = card:sub(1, 1), suit = card:sub(2, 2)})
                end
            end
        end

        -- Parse community cards
        if communityCards and communityCards ~= "" then
            for card in communityCards:gmatch("([^,]+)") do
                if #card >= 2 then
                    table.insert(allCards, {rank = card:sub(1, 1), suit = card:sub(2, 2)})
                end
            end
        end

        -- Find best 5-card hand from available cards
        return PokerGameLogic.findBestHand(allCards)
    end,

    findBestHand = function(cards)
        if #cards < 5 then
            return {ranking = PokerGameLogic.HAND_RANKINGS.HIGH_CARD, value = 0, description = "Insufficient cards"}
        end

        local bestHand = {ranking = PokerGameLogic.HAND_RANKINGS.HIGH_CARD, value = 0, cards = {}, description = "High card"}

        -- Try all possible 5-card combinations
        for i = 1, #cards - 4 do
            for j = i + 1, #cards - 3 do
                for k = j + 1, #cards - 2 do
                    for l = k + 1, #cards - 1 do
                        for m = l + 1, #cards do
                            local hand = {cards[i], cards[j], cards[k], cards[l], cards[m]}
                            local evaluation = PokerGameLogic.evaluatePokerHand(hand)

                            if PokerGameLogic.compareHands(evaluation, bestHand) > 0 then
                                bestHand = evaluation
                            end
                        end
                    end
                end
            end
        end

        return bestHand
    end,

    evaluatePokerHand = function(hand)
        -- Sort cards by rank value (high to low)
        table.sort(hand, function(a, b)
            return PokerGameLogic.CARD_VALUES[a.rank] > PokerGameLogic.CARD_VALUES[b.rank]
        end)

        local isFlush = PokerGameLogic.isFlush(hand)
        local isStraight, straightHigh = PokerGameLogic.isStraight(hand)
        local rankCounts = PokerGameLogic.getRankCounts(hand)

        -- Check for Royal Flush
        if isFlush and isStraight and straightHigh == 14 then
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.ROYAL_FLUSH,
                value = 14,
                cards = hand,
                description = "Royal Flush"
            }
        end

        -- Check for Straight Flush
        if isFlush and isStraight then
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.STRAIGHT_FLUSH,
                value = straightHigh,
                cards = hand,
                description = "Straight Flush, " .. PokerGameLogic.rankToString(straightHigh) .. " high"
            }
        end

        -- Check for Four of a Kind
        local fourKind = PokerGameLogic.findNOfAKind(rankCounts, 4)
        if fourKind then
            local kicker = PokerGameLogic.findKicker(rankCounts, fourKind, 1)
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.FOUR_OF_A_KIND,
                value = fourKind * 100 + kicker,
                cards = hand,
                description = "Four " .. PokerGameLogic.rankToString(fourKind) .. "s"
            }
        end

        -- Check for Full House
        local threeKind = PokerGameLogic.findNOfAKind(rankCounts, 3)
        local pair = PokerGameLogic.findNOfAKind(rankCounts, 2)
        if threeKind and pair then
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.FULL_HOUSE,
                value = threeKind * 100 + pair,
                cards = hand,
                description = PokerGameLogic.rankToString(threeKind) .. "s full of " .. PokerGameLogic.rankToString(pair) .. "s"
            }
        end

        -- Check for Flush
        if isFlush then
            local value = 0
            for i, card in ipairs(hand) do
                value = value + PokerGameLogic.CARD_VALUES[card.rank] * (100 ^ (5 - i))
            end
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.FLUSH,
                value = value,
                cards = hand,
                description = "Flush, " .. PokerGameLogic.rankToString(PokerGameLogic.CARD_VALUES[hand[1].rank]) .. " high"
            }
        end

        -- Check for Straight
        if isStraight then
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.STRAIGHT,
                value = straightHigh,
                cards = hand,
                description = "Straight, " .. PokerGameLogic.rankToString(straightHigh) .. " high"
            }
        end

        -- Check for Three of a Kind
        if threeKind then
            local kickers = PokerGameLogic.findKickers(rankCounts, threeKind, 2)
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.THREE_OF_A_KIND,
                value = threeKind * 10000 + kickers[1] * 100 + kickers[2],
                cards = hand,
                description = "Three " .. PokerGameLogic.rankToString(threeKind) .. "s"
            }
        end

        -- Check for Two Pair
        local pairs = PokerGameLogic.findAllPairs(rankCounts)
        if #pairs >= 2 then
            table.sort(pairs, function(a, b) return a > b end)
            local kicker = PokerGameLogic.findKicker(rankCounts, pairs[1], 1, pairs[2])
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.TWO_PAIR,
                value = pairs[1] * 10000 + pairs[2] * 100 + kicker,
                cards = hand,
                description = PokerGameLogic.rankToString(pairs[1]) .. "s and " .. PokerGameLogic.rankToString(pairs[2]) .. "s"
            }
        end

        -- Check for One Pair
        if pair then
            local kickers = PokerGameLogic.findKickers(rankCounts, pair, 3)
            return {
                ranking = PokerGameLogic.HAND_RANKINGS.PAIR,
                value = pair * 1000000 + kickers[1] * 10000 + kickers[2] * 100 + kickers[3],
                cards = hand,
                description = "Pair of " .. PokerGameLogic.rankToString(pair) .. "s"
            }
        end

        -- High Card
        local value = 0
        for i, card in ipairs(hand) do
            value = value + PokerGameLogic.CARD_VALUES[card.rank] * (100 ^ (5 - i))
        end
        return {
            ranking = PokerGameLogic.HAND_RANKINGS.HIGH_CARD,
            value = value,
            cards = hand,
            description = PokerGameLogic.rankToString(PokerGameLogic.CARD_VALUES[hand[1].rank]) .. " high"
        }
    end,

    -- Helper functions
    isFlush = function(hand)
        local suit = hand[1].suit
        for i = 2, #hand do
            if hand[i].suit ~= suit then
                return false
            end
        end
        return true
    end,

    isStraight = function(hand)
        local values = {}
        for _, card in ipairs(hand) do
            table.insert(values, PokerGameLogic.CARD_VALUES[card.rank])
        end
        table.sort(values, function(a, b) return a > b end)

        -- Check for regular straight
        for i = 1, 4 do
            if values[i] - values[i + 1] ~= 1 then
                -- Check for A-2-3-4-5 straight (wheel)
                if i == 1 and values[1] == 14 and values[2] == 5 and values[3] == 4 and values[4] == 3 and values[5] == 2 then
                    return true, 5 -- Ace-low straight, 5 high
                end
                return false, 0
            end
        end

        return true, values[1]
    end,

    getRankCounts = function(hand)
        local counts = {}
        for _, card in ipairs(hand) do
            local value = PokerGameLogic.CARD_VALUES[card.rank]
            counts[value] = (counts[value] or 0) + 1
        end
        return counts
    end,

    findNOfAKind = function(rankCounts, n)
        for rank, count in pairs(rankCounts) do
            if count == n then
                return rank
            end
        end
        return nil
    end,

    findAllPairs = function(rankCounts)
        local pairs = {}
        for rank, count in pairs(rankCounts) do
            if count == 2 then
                table.insert(pairs, rank)
            end
        end
        return pairs
    end,

    findKicker = function(rankCounts, excludeRank, count, excludeRank2)
        local kickers = {}
        for rank, rankCount in pairs(rankCounts) do
            if rank ~= excludeRank and rank ~= excludeRank2 then
                for i = 1, rankCount do
                    table.insert(kickers, rank)
                end
            end
        end
        table.sort(kickers, function(a, b) return a > b end)
        return kickers[1] or 0
    end,

    findKickers = function(rankCounts, excludeRank, count)
        local kickers = {}
        for rank, rankCount in pairs(rankCounts) do
            if rank ~= excludeRank then
                for i = 1, rankCount do
                    table.insert(kickers, rank)
                end
            end
        end
        table.sort(kickers, function(a, b) return a > b end)

        local result = {}
        for i = 1, math.min(count, #kickers) do
            table.insert(result, kickers[i])
        end
        return result
    end,

    compareHands = function(hand1, hand2)
        if hand1.ranking < hand2.ranking then
            return 1 -- hand1 wins
        elseif hand1.ranking > hand2.ranking then
            return -1 -- hand2 wins
        else
            -- Same ranking, compare values
            if hand1.value > hand2.value then
                return 1
            elseif hand1.value < hand2.value then
                return -1
            else
                return 0 -- tie
            end
        end
    end,

    rankToString = function(value)
        local ranks = {[2] = "2", [3] = "3", [4] = "4", [5] = "5", [6] = "6", [7] = "7", [8] = "8",
                      [9] = "9", [10] = "10", [11] = "Jack", [12] = "Queen", [13] = "King", [14] = "Ace"}
        return ranks[value] or tostring(value)
    end,

    -- Game flow functions
    advanceGameState = function(gameId)
        local gameData = PokerGameLogic.getGameData(gameId)
        local newState = ""

        if gameData.game_state == "preflop" then
            newState = "flop"
            PokerGameLogic.dealFlop(gameId)
        elseif gameData.game_state == "flop" then
            newState = "turn"
            PokerGameLogic.dealTurn(gameId)
        elseif gameData.game_state == "turn" then
            newState = "river"
            PokerGameLogic.dealRiver(gameId)
        elseif gameData.game_state == "river" then
            newState = "showdown"
            PokerGameLogic.doShowdown(gameId)
            return
        end

        PokerGameLogic.updateGameState(gameId, newState)
        PokerGameLogic.resetBettingRound(gameId)
        PokerGameLogic.startBettingRound(gameId, newState)
    end,

    dealFlop = function(gameId)
        local deck = PokerGameLogic.loadDeckState(gameId)
        table.remove(deck, 1) -- Burn card

        local flop = {}
        for i = 1, 3 do
            local card = table.remove(deck, 1)
            table.insert(flop, card.rank .. card.suit)
        end

        PokerGameLogic.setCommunityCards(gameId, table.concat(flop, ","))
        PokerGameLogic.saveDeckState(gameId, deck)
    end,

    dealTurn = function(gameId)
        local deck = PokerGameLogic.loadDeckState(gameId)
        local currentCards = PokerGameLogic.getCommunityCards(gameId)

        table.remove(deck, 1) -- Burn card
        local turnCard = table.remove(deck, 1)

        local newCards = currentCards .. "," .. turnCard.rank .. turnCard.suit
        PokerGameLogic.setCommunityCards(gameId, newCards)
        PokerGameLogic.saveDeckState(gameId, deck)
    end,

    dealRiver = function(gameId)
        local deck = PokerGameLogic.loadDeckState(gameId)
        local currentCards = PokerGameLogic.getCommunityCards(gameId)

        table.remove(deck, 1) -- Burn card
        local riverCard = table.remove(deck, 1)

        local newCards = currentCards .. "," .. riverCard.rank .. riverCard.suit
        PokerGameLogic.setCommunityCards(gameId, newCards)
        PokerGameLogic.saveDeckState(gameId, deck)
    end,

    doShowdown = function(gameId)
        local players = PokerGameLogic.getActivePlayers(gameId)
        local communityCards = PokerGameLogic.getCommunityCards(gameId)
        local gameData = PokerGameLogic.getGameData(gameId)

        if #players == 1 then
            -- Only one player left, they win
            local winner = players[1]
            PokerGameLogic.awardPot(gameId, winner.player_name, gameData.pot_amount)
            PokerGameLogic.endGame(gameId)
            return
        end

        -- Evaluate all hands
        local handEvaluations = {}
        for _, player in ipairs(players) do
            local hand = PokerGameLogic.evaluateHand(player.hole_cards, communityCards)
            hand.player_name = player.player_name
            hand.chip_count = player.chip_count
            table.insert(handEvaluations, hand)
        end

        -- Sort by hand strength (best first)
        table.sort(handEvaluations, function(a, b)
            return PokerGameLogic.compareHands(a, b) > 0
        end)

        -- Determine winners and split pots
        local winners = {handEvaluations[1]}
        for i = 2, #handEvaluations do
            if PokerGameLogic.compareHands(handEvaluations[1], handEvaluations[i]) == 0 then
                table.insert(winners, handEvaluations[i])
            else
                break
            end
        end

        -- Award pot
        local potPerWinner = math.floor(gameData.pot_amount / #winners)
        for _, winner in ipairs(winners) do
            PokerGameLogic.awardPot(gameId, winner.player_name, potPerWinner)
        end

        -- Show results to all players
        PokerGameLogic.showShowdownResults(gameId, handEvaluations, winners)
        PokerGameLogic.endGame(gameId)
    end,

    showShowdownResults = async(function(gameId, allHands, winners)
        local gameData = PokerGameLogic.getGameData(gameId)
        local communityCards = PokerGameLogic.getCommunityCards(gameId)

        local resultText = "=== SHOWDOWN RESULTS ===\n\n"
        resultText = resultText .. "Community Cards: " .. PokerGameLogic.formatCards(communityCards) .. "\n\n"

        -- Show all player hands
        for _, hand in ipairs(allHands) do
            local isWinner = false
            for _, winner in ipairs(winners) do
                if winner.player_name == hand.player_name then
                    isWinner = true
                    break
                end
            end

            resultText = resultText .. string.format("%s%s: %s - %s\n",
                isWinner and "🏆 " or "",
                hand.player_name,
                PokerGameLogic.formatCards(hand.player_name), -- Need to get actual hole cards
                hand.description
            )
        end

        if #winners == 1 then
            resultText = resultText .. string.format("\n%s wins %s chips!", winners[1].player_name, Tools.formatValue(gameData.pot_amount))
        else
            resultText = resultText .. string.format("\n%d-way split pot! Each winner gets %s chips.",
                #winners, Tools.formatValue(math.floor(gameData.pot_amount / #winners)))
        end

        -- Send results to all players at table
        local allPlayers = PokerGameLogic.getAllGamePlayers(gameId)
        for _, playerData in ipairs(allPlayers) do
            local player = Player(playerData.player_name)
            if player then
                local t = {graphic = convertGraphic(65, "monster"), color = 0}
                player.npcGraphic = t.graphic
                player.npcColor = t.color
                player:dialogSeq({t, resultText}, 0)
            end
        end
    end),

    -- Database interface functions (these would need to be implemented based on your specific DB structure)
    getGameData = function(gameId)
        local query = string.format("SELECT * FROM poker_games WHERE id = %d", gameId)
        local result = sql(query)
        return result and result[1]
    end,

    updateGameState = function(gameId, newState)
        local query = string.format("UPDATE poker_games SET game_state = '%s' WHERE id = %d", newState, gameId)
        sql(query)
    end,

    getCommunityCards = function(gameId)
        local query = string.format("SELECT community_cards FROM poker_games WHERE id = %d", gameId)
        local result = sql(query)
        return result and result[1] and result[1].community_cards or ""
    end,

    setCommunityCards = function(gameId, cards)
        local query = string.format("UPDATE poker_games SET community_cards = '%s' WHERE id = %d", cards, gameId)
        sql(query)
    end,

    loadDeckState = function(gameId)
        local query = string.format("SELECT deck_state FROM poker_games WHERE id = %d", gameId)
        local result = sql(query)
        if result and result[1] and result[1].deck_state then
            -- Parse deck from stored string format
            local deck = {}
            for card in result[1].deck_state:gmatch("([^,]+)") do
                if #card >= 2 then
                    table.insert(deck, {rank = card:sub(1, 1), suit = card:sub(2, 2)})
                end
            end
            return deck
        end
        return {}
    end,

    saveDeckState = function(gameId, deck)
        local deckString = ""
        for i, card in ipairs(deck) do
            if i > 1 then deckString = deckString .. "," end
            deckString = deckString .. card.rank .. card.suit
        end

        local query = string.format("UPDATE poker_games SET deck_state = '%s' WHERE id = %d", deckString, gameId)
        sql(query)
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
    end
}