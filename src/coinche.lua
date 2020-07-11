deal_guid = '4c4cab'
playing_zone_guid = '62af4a'

PLAYING_ZONE = nil
GAME_MACHINE = nil
THIS_IS_A_SAVED_GAME = false

TEAM1 = 'TEAM1'
TEAM2 = 'TEAM2'
TEAM_NAMES = {TEAM1='WhiteGreen', TEAM2='OrangePurple'}
PLAYERS_COLOR = {'White', 'Orange', 'Green', 'Purple'}
PLAYERS_TEAM = {White=TEAM1, Orange=TEAM2, Green=TEAM1, Purple=TEAM2}
FIRST_DEALER = 'White'
TEAMS_TRICKS_POS = {TEAM1={10.00, 3, -10.00}, TEAM2={-10.00, 3, -10.00}}
TEAMS_TRICKS_ROT = {TEAM1={0.00, 180.00, 180.00}, TEAM2={0.00, 270.00, 180.00}}
TEAMS_LAST_TRICKS_POS = {TEAM1={5.00, 3, -10.00}, TEAM2={-10.00, 3, -5.00}}
TEAMS_LAST_TRICKS_ROT = {TEAM1={0.00, 180.00, 0.00}, TEAM2={0.00, 270.00, 0.00}}
DEALER_POS = {White={10.00, 1.13, -14.00}, Orange={-14.00, 1.13, -10.00}, Green={-10.00, 1.13, 14.00}, Purple={14.00, 1.13, 10.00}}
DEALER_ROT = {White={0.00, 180.00, 0.00}, Orange={0.00, 270.00, 0.00}, Green={0.00, 0.00, 0.00}, Purple={0.00, 90.00, 0.00}}

SUITS = {'clubs', 'diamonds', 'hearts', 'spades'}
FACES = {'Ace', 'King', 'Queen', 'Jack', 'Ten', 'Nine', 'Eight', 'Seven'}
CARDS_FACE = {}
CARDS_SUIT = {}

SUIT_ORDER = {Ace=0, Ten=1, King=2, Queen=3, Jack=4, Nine=5, Eight=6, Seven=7}
SUIT_POINT_SCALE = {Ace=11, Ten=10, King=4, Queen=3, Jack=2, Nine=0, Eight=0, Seven=0}
TRUMP_ORDER = {Jack=0, Nine=1, Ace=2, Ten=3, King=4, Queen=5, Eight=6, Seven=7}
TRUMP_POINT_SCALE = {Jack=20, Nine=14, Ace=11, Ten=10, King=4, Queen=3, Eight=0, Seven=0}
CAPOT = 'CAPOT'
GENERAL = 'GENERAL'
ALLTRUMP = 'ALLTRUMP'
NOTRUMP = 'NOTRUMP'

--[[ Events callback --]]

function onLoad(save_state)
    UI.hide('contractPanel')
    UI.hide('teamNameInput')

    PLAYING_ZONE = getObjectFromGUID(playing_zone_guid)
    DEALER_TOKEN = getObjectFromGUID(deal_guid)
    makeButton(DEALER_TOKEN, 'Deal', 'startRound')

    checkSavedGameMarker()

    -- Init card face value table
    for _, suit in ipairs(SUITS) do
        for _, face in ipairs(FACES) do
            local card_name = face .. " of " .. suit
            CARDS_FACE[card_name] = face
            CARDS_SUIT[card_name] = suit
        end
    end

    -- Setup steam_name
    for _, player in ipairs(PLAYERS_COLOR) do
        local ui_id = 'biddingPlayer_' .. player
        UI.setAttribute(ui_id, 'text', sn(player) .. ' bid')
    end

    -- Init game engine
    if THIS_IS_A_SAVED_GAME and save_state != "" then
        local lua_state = JSON.decode(save_state)
        if pcall(function()
            GAME_MACHINE = GameStateMachine:newFromState(lua_state)
        end) then
            print("*** Saved game restored ***")
        else
            print("*** Error loading saved game. Sarting a new game engine ***")
        end
    end
    if GAME_MACHINE == nil then
        GAME_MACHINE = GameStateMachine:new(FIRST_DEALER)
        pcall(function() findDeck().shuffle() end)
    end
end

function checkSavedGameMarker()
    -- In this function, we leverage the fact that new games have a dealer
    -- token object without a name. We wait 5 seconds to setup the name of
    -- the token. However it will be already set on saved game.
    Wait.time(function()
        DEALER_TOKEN.setName("Dealer token")
    end, 5)

    -- This is run immediatly, hence only saved game will be flag as such.
    if DEALER_TOKEN.getName() == "Dealer token" then
        THIS_IS_A_SAVED_GAME = true
    end
end

function onSave()
    return JSON.encode(GAME_MACHINE:dumpState())
end

function onObjectEnterScriptingZone(zone, card)
    if card.tag == 'Card' then
        GAME_MACHINE:checkCardDrop(card)
    end
end

function onPlayerChangeColor(player)
    if player != 'Grey' then
        local ui_id = 'biddingPlayer_' .. player
        UI.setAttribute(ui_id, 'text', sn(player) .. ' bid')
    end
end

--[[ Small functions --]]

function sn(player)
    return (Player[player] and Player[player].steam_name) or player
end

function makeButton(obj, label, fcn)
    local params = {
        click_function = fcn,
        label = label,
        function_owner = Global,
        position = {0, 0.2, 0},
        rotation = {0, 0, 0},
        width = 550,
        height = 1200,
        font_size = 250,
    }
    obj.createButton(params)
end

function findDeck()
    local all_obj = getAllObjects()
    for _, obj in pairs(all_obj) do
        if obj.tag == 'Deck' and obj.getQuantity() == 32 then
            return obj
        end
    end
    broadcastToAll("Reconstitute the original 32 cards deck before dealing", 'Black')
    error("No 32 cards deck found in the game", 2)
end

--[[ UI callback --]]

function startRound()
    GAME_MACHINE:dealNewRound()
end

function setToggleGroupValue(player, value, id)
    local _, _, parent_id, value = string.find(id, '(%w+)_(%w+)')
    UI.setAttribute(parent_id, 'value', value)
end

function playContract(player, value, id)
    UI.hide('contractPanel')
    GAME_MACHINE:acceptContract()
end

function editTeamName(lua_player, value, id)
    local _, _, team = string.find(id, 'teamName_(%w+)')
    UI.setAttribute('teamNameInput', 'team', team)
    UI.setAttribute('teamNameInput', 'text', TEAM_NAMES[team])
    UI.show('teamNameInput')
    UI.setAttribute('teamNameInput', 'visibility', lua_player.color)
end

function commitTeamName(player, value, id)
    UI.hide('teamNameInput')
    local team = UI.getAttribute('teamNameInput', 'team')
    local team_name_id = "teamName_" .. team
    TEAM_NAMES[team] = value
    UI.setAttribute(team_name_id, 'text', value)
end

function unlockAllCard()
    local all_obj = getAllObjects()
    for _, obj in pairs(all_obj) do
        if obj.tag == 'Card' then
            obj.setLock(false)
        end
    end
end

function undoTrick()
    GAME_MACHINE:undoTrick()
end

function restartRound()
    GAME_MACHINE:restartRound()
end

function cancelRound()
    GAME_MACHINE:cancelRound()
end

function changeDealer()
    GAME_MACHINE:changeDealer()
end

function resetScores()
    GAME_MACHINE.game:resetScores()
end

function showContractUI()
    UI.show('contractPanel')
    UI.setAttribute('contractPanel', 'visibility', 'host')

    -- Ensure coherency between UI and underlying data
    function setToggleFromGroupValue(id_prefix)
        local group_value = UI.getAttribute(id_prefix, 'value')
        if group_value != nil then
            local id = id_prefix .. '_' .. group_value
            UI.setAttribute(id, 'isOn', true)
        end
    end
    setToggleFromGroupValue('biddingPlayer')
    setToggleFromGroupValue('contractSuite')
    setToggleFromGroupValue('contractLevel')
    setToggleFromGroupValue('coincheLevel')
end

function hideContractUI()
    UI.hide('contractPanel')
end

function earlyScoreFailedContract()
    GAME_MACHINE:earlyScoreFailedContract()
end

--[[ Coinche game objects --]]

GameStateMachine = {
    INVALID_STATE = 'invalid_state',
    CARD_DEALT = 'card_dealt',
    IN_FIRST_TRICK = 'in_first_trick',
    IN_ROUND = 'in_round',
    ROUND_FINISHED = 'round_finished',
}
function GameStateMachine:new(first_dealer)
    local obj = {
        game = CoincheGame:new(first_dealer),
        round = nil,
        trick = nil,
        state = self.ROUND_FINISHED,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end
function GameStateMachine:changeDealer()
    if self.state == self.ROUND_FINISHED then
        self.game:changeDealer()
    else
        print("Can only change dealer between rounds")
    end
end
function GameStateMachine:dealNewRound()
    if self.state == self.ROUND_FINISHED then
        printToAll("New round", 'Black')
        self.game:dealCards()
        showContractUI()
        self.state = self.CARD_DEALT
    else
        print("Can't deal while game is running")
    end
end
function GameStateMachine:restartRound()
    if self.state == self.IN_ROUND or self.state == self.IN_FIRST_TRICK then
        self.state = self.INVALID_STATE
        printToAll("Restarting round !", 'Black')
        self.round:dealAgain()
        self.state = self.CARD_DEALT
        self:acceptContract()
    else
        print("Can only restart a round when one is running")
    end
end
function GameStateMachine:cancelRound()
    if self.state != self.ROUND_FINISHED then
        for _=1,3 do self.game.dealer_iterator:next() end
        self.state = self.ROUND_FINISHED
        printToAll("Game state reset. Deal a new round.", 'Black')
    else
        print("Can't reset a finished round")
    end
end
function GameStateMachine:acceptContract()
    if self.state == self.CARD_DEALT or self.state == self.IN_FIRST_TRICK then
        self.state = self.INVALID_STATE
        local contract = self:getContractFromUI()
        self.round = self.game:startRound(contract)
        self:startTrick()
    else
        print("Can't change contract at this stage")
    end
end
function GameStateMachine:startTrick()
    self.state = self.INVALID_STATE
    self.trick = self.round:nextTrick()
    if self.round.trick_count == 1 then
        self.state = self.IN_FIRST_TRICK
    else
        self.state = self.IN_ROUND
    end
end
function GameStateMachine:scoreTrick(played_cards)
    self.state = self.INVALID_STATE
    local trick_winner = self.trick:computeWinner(played_cards)
    local trick_score = self.trick:computeScore(played_cards)
    round_finished = self.round:scoreTrick(trick_winner, trick_score, played_cards)

    -- Check if the trick finishes the round
    if round_finished then
        self:finishRound()
    else
        self:startTrick()
    end
end
function GameStateMachine:undoTrick()
    if self.state == self.IN_ROUND then
        self.state = self.INVALID_STATE
        if self.round:undoTrick() then
            self:startTrick()
        elseif self.round.trick_count == 1 then
            self.state = self.IN_FIRST_TRICK
        else
            self.state = self.IN_ROUND
        end
    else
        print("Can only undo tricks during a round")
    end
end
function GameStateMachine:earlyScoreFailedContract()
    if self.state == self.IN_ROUND or self.state == self.IN_FIRST_TRICK then
        if self.round:earlyCheckFailedContract() then
            self:finishRound()
        else
            print("Contract has not failed yet")
        end
    else
        print("Can only finish a round when in a round")
    end
end
function GameStateMachine:finishRound()
    self.state = self.INVALID_STATE
    self.game:scoreRound(self.round)
    self.game:moveDealerToken()
    self.state = self.ROUND_FINISHED
end
function GameStateMachine:getContractFromUI()
    local trump_mode = UI.getAttribute('contractSuite', 'value')
    local raw_level = UI.getAttribute('contractLevel', 'value')
    local coinch_level = tonumber(UI.getAttribute('coincheLevel', 'value'))
    local level
    local defending_level = -1
    local score

    if raw_level == CAPOT then
        level = CAPOT
        score = 250
    elseif raw_level == GENERAL then
        level = GENERAL
        score = 500
    else
        local base_level = tonumber(raw_level)
        score = tonumber(raw_level)
        if trump_mode == ALLTRUMP then
            level = math.floor(base_level * 248 / 162)
            level = math.max(level, 125)
            defending_level = 248 - level + 1
        elseif trump_mode == NOTRUMP then
            level = math.floor(base_level * 130 / 162)
            level = math.max(level, 66)
            defending_level = 130 - level + 1
        else
            level = math.max(base_level, 82)
            defending_level = 162 - level + 1
        end
    end

    score = score * 2^(coinch_level)

    local contract = {
        bidding_player = UI.getAttribute('biddingPlayer', 'value'),
        trump_mode = trump_mode,
        level = level,
        defending_level = defending_level,
        score = score,
    }

    printToAll("Contract by ".. sn(contract.bidding_player), 'Black')
    printToAll("  Suit: ".. contract.trump_mode, 'Black')
    printToAll("  Level: ".. contract.level, 'Black')
    if defending_level > 0 then
        printToAll("  Defending level: ".. contract.defending_level, 'Black')
    end
    printToAll("  Score: ".. contract.score, 'Black')

    return contract
end
function GameStateMachine:dumpState()
    save_state = {
        global_state = self.state,
        game_state = self.game:dumpState(),
    }
    if (self.state == self.IN_ROUND) or (self.state == self.IN_FIRST_TRICK) then
        save_state.round_state = self.round:dumpState()
    end
    return save_state
end
function GameStateMachine:newFromState(state)
    new_machine = self:new(FIRST_DEALER)
    new_machine.state = state.global_state
    new_machine.game = CoincheGame:newFromState(state.game_state)

    if new_machine.state == self.IN_ROUND or new_machine.state == self.IN_FIRST_TRICK then
        new_machine.round = CoincheRound:newFromState(state.round_state)
        new_machine:startTrick()
    end

    return new_machine
end
function GameStateMachine:checkCardDrop(card)
    if self.state == self.IN_FIRST_TRICK or self.state == self.IN_ROUND and not self.round:cardAlreadyPlayed(card) then
        -- Using coroutine to wait 1 frame for the dropped card to be register as "in the zone"
        Wait.time(function() card.setLock(true) end, 0.5)
        function checkCardDropCoroutine()
            coroutine.yield(0)
            -- Check if last card in zone finishes the trick
            trick_finished, played_cards = self.trick:checkFinished(self.round)
            if trick_finished then
                self:scoreTrick(played_cards)
            end
            -- Apparently, coroutine should return 1
            return 1
        end
        startLuaCoroutine(Global, 'checkCardDropCoroutine')
    end
end


CoincheGame = {}
function CoincheGame:new(first_dealer)
    local obj = {
        dealer_iterator = PlayerIterator:new(first_dealer),
        score_board = ScoreBoard:new(),
        cards_player = {},
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end
function CoincheGame:startRound(contract)
    local first_leader = self.dealer_iterator:peek_next()
    return CoincheRound:new(first_leader, self.cards_player, contract)
end
function CoincheGame:scoreRound(round)
    local winning_team = round:whichTeamWon()
    self.score_board:scoreRound(winning_team, round.contract.score)

    printToAll("Final round score:", 'Black')
    printToAll("  Contract level: ".. round.contract.level, 'Black')
    printToAll("  ".. TEAM_NAMES[TEAM1] ..": ".. round.scores[TEAM1] .." points", 'Black')
    printToAll("  ".. TEAM_NAMES[TEAM2] ..": ".. round.scores[TEAM2] .." points", 'Black')
    printToAll("  ".. TEAM_NAMES[winning_team] .." scored ".. round.contract.score .." points in this round", 'Black')
end
function CoincheGame:resetScores()
    self.score_board:resetScores()
end
function CoincheGame:moveDealerToken()
    local next_dealer = self.dealer_iterator:peek_next()
    DEALER_TOKEN.setRotation(DEALER_ROT[next_dealer])
    DEALER_TOKEN.setPositionSmooth(DEALER_POS[next_dealer], false, false)
end
function CoincheGame:dealCards()
    local deck = findDeck()
    local dealer = self.dealer_iterator:next()

    local cards_dealt_by_turns = {3, 2, 3}
    for _, cards_dealt in ipairs(cards_dealt_by_turns) do
        -- First card is dealt to the player after the dealer
        local player_iterator = PlayerIterator:new(dealer, 5)
        player_iterator:next()
        for player in player_iterator:iter() do
            deck.deal(cards_dealt, player)
        end
    end

    -- And assign cards to player.
    Wait.condition(
        function()
            for _, player in ipairs(PLAYERS_COLOR) do
                local player_hand = Player[player].getHandObjects()
                for _, card in ipairs(player_hand) do
                    self.cards_player[card.getName()] = player
                end
            end
        end,
        -- We wait for each player to have 8 cards
        function()
            for _, player in ipairs(PLAYERS_COLOR) do
                if #Player[player].getHandObjects() < 8 then
                    return false
                end
            end
            return true
        end
    )
end
function CoincheGame:changeDealer()
    self.dealer_iterator:next()
    self:moveDealerToken()
end
function CoincheGame:dumpState()
    return {
        next_dealer = self.dealer_iterator:peek_next(),
        score_board_state = self.score_board:dumpState(),
        cards_player = self.cards_player,
    }
end
function CoincheGame:newFromState(state)
    game = self:new(FIRST_DEALER)
    game.dealer_iterator = PlayerIterator:new(state.next_dealer)
    game.score_board:restoreState(state.score_board_state)
    game.cards_player = state.cards_player

    return game
end


CoincheRound = {}
function CoincheRound:new(first_leader, cards_player, contract)
    local obj = {
        next_leader = first_leader,
        contract = contract,
        cards_player = cards_player,
        trick_count = 0,
        cards_played = {},
        scores = {TEAM1=0, TEAM2=0},
        player_nb_tricks_won = {White=0, Orange=0, Green=0, Purple=0},
        team_nb_tricks_won = {TEAM1=0, TEAM2=0},
        previous_trick_cards = nil,
        previous_scoring_team = nil,
        trick_history = nil,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end
function CoincheRound:getCardPlayer(card)
    return self.cards_player[card.getName()]
end
function CoincheRound:cardAlreadyPlayed(card)
    return self.cards_played[card.getName()] != nil
end
function CoincheRound:nextTrick()
    self.trick_count = self.trick_count + 1
    broadcastToAll("Trick " .. self.trick_count .. ": " .. sn(self.next_leader) .. " start", self.next_leader)
    return CoincheTrick:new(self.next_leader, self.contract.trump_mode, self.trick_count)
end
function CoincheRound:scoreTrick(trick_winner, trick_score, played_cards)
    for _, card in pairs(played_cards) do
        self.cards_played[card.getName()] = true
    end

    local scoring_team = PLAYERS_TEAM[trick_winner]
    printToAll(sn(trick_winner) .." scored ".. trick_score .." points in this trick", trick_winner)

    self.scores[scoring_team] = self.scores[scoring_team] + trick_score
    self.player_nb_tricks_won[trick_winner] = self.player_nb_tricks_won[trick_winner] + 1
    self.team_nb_tricks_won[scoring_team] = self.team_nb_tricks_won[scoring_team] + 1

    local trick_undo = {
        played_cards = played_cards,
        score = trick_score,
        winner = trick_winner,
        scoring_team = scoring_team,
        next_leader = self.next_leader,
    }
    self.trick_history = trick_undo
    self.next_leader = trick_winner

    if self.trick_count < 8 then
        -- Quick wait because some sketchy grouping occurs on the last card dropped
        Wait.time(function() self:storeTrickCards(scoring_team, played_cards) end, 1)
    else
        -- Unlock cards of last trick. We wait for the last card lock coroutine
        Wait.time(function ()
            for _, card in pairs(played_cards) do
                card.setLock(false)
            end
        end, 1)
    end

    return self.trick_count >= 8
end
function CoincheRound:undoTrick()
     -- Early returns if can't undo trick
    if self.trick_count <= 1 then
        return false
    end
    if self.trick_history == nil then
        print("Can only undo last trick")
        return false
    end

    printToAll("Undoing last trick", 'Black')
    self.trick_count = self.trick_count - 2  -- Minus 2 because a +1 allready occured
    local trick = self.trick_history
    self.trick_history = nil
    self.previous_trick_cards = nil

    for player, card in pairs(trick.played_cards) do
        local player_hand_transform = Player[player].getHandTransform()
        card.setPosition(player_hand_transform.position)
        card.setRotation(player_hand_transform.rotation)
        self.cards_played[card.getName()] = nil
    end

    self.scores[trick.scoring_team] = self.scores[trick.scoring_team] - trick.score
    self.player_nb_tricks_won[trick.winner] = self.player_nb_tricks_won[trick.winner] + 1
    self.team_nb_tricks_won[trick.scoring_team] = self.team_nb_tricks_won[trick.scoring_team] - 1
    self.next_leader = trick.next_leader

    return true
end
function CoincheRound:whichTeamWon()
    local bidding_team = PLAYERS_TEAM[self.contract.bidding_player]
    local defending_team
    if bidding_team == TEAM1 then
        defending_team = TEAM2
    else
        defending_team = TEAM1
    end

    local winning_team
    if self.contract.level == CAPOT then
        if self.team_nb_tricks_won[bidding_team] == 8 then
            winning_team = bidding_team
        else
            winning_team = defending_team
        end
    elseif self.contract.level == GENERAL then
        if self.player_nb_tricks_won[self.contract.bidding_player] == 8 then
            winning_team = bidding_team
        else
            winning_team = defending_team
        end
    else
        local level_with_belote = self.contract.level
        if self:biddingTeamHasBelote() then
            level_with_belote = math.max(level_with_belote - 20, 82)
        end
        if self.scores[bidding_team] >= level_with_belote then
            winning_team = bidding_team
        else
            winning_team = defending_team
        end
    end

    if winning_team == bidding_team then
        broadcastToAll("Successful contract", 'Green')
    else
        broadcastToAll("Failed contract", 'Red')
    end

    return winning_team
end
function CoincheRound:earlyCheckFailedContract()
    local bidding_team = PLAYERS_TEAM[self.contract.bidding_player]
    local defending_team
    if bidding_team == TEAM1 then
        defending_team = TEAM2
    else
        defending_team = TEAM1
    end

    local contract_already_failed = false
    if self.contract.level == CAPOT then
        if self.team_nb_tricks_won[defending_team] > 0 then
            contract_already_failed = true
        end
    elseif self.contract.level == GENERAL then
        other_player_iterator = PlayerIterator:new(self.contract.bidding_player, 4)
        other_player_iterator:next()
        for player in other_player_iterator:iter() do
            if self.player_nb_tricks_won[player] > 0 then
                contract_already_failed = true
                break
            end
        end
    else
        local level_with_belote = self.contract.level
        if self:biddingTeamHasBelote() then
            level_with_belote = math.max(level_with_belote - 20, 82)
        end
        if self.scores[defending_team] >= self.contract.defending_level then
            contract_already_failed = true
        end
    end

    return contract_already_failed
end
function CoincheRound:biddingTeamHasBelote()
    local has_belote = false
    if self.contract.trump_mode != ALLTRUMP and self.contract.trump_mode != NOTRUMP then
        local trump_king = "King of " .. self.contract.trump_mode
        local trump_queen = "Queen of " .. self.contract.trump_mode
        local trump_king_holder = self.cards_player[trump_king]
        local trump_queen_holder = self.cards_player[trump_queen]

        local bidding_team = PLAYERS_TEAM[self.contract.bidding_player]
        local belote_holder_team = PLAYERS_TEAM[trump_king_holder]

        has_belote = (trump_king_holder == trump_queen_holder) and (belote_holder_team == bidding_team)
    end
    return has_belote
end
function CoincheRound:storeTrickCards(scoring_team, played_cards)
    if self.previous_trick_cards != nil then
        for _, card in pairs(self.previous_trick_cards) do
            if getObjectFromGUID(card.guid) != nil then
                card.setRotation(TEAMS_TRICKS_ROT[self.previous_scoring_team])
                card.setPosition(TEAMS_TRICKS_POS[self.previous_scoring_team])
            end
        end
    end

    local next_global_pos = TEAMS_LAST_TRICKS_POS[scoring_team]
    for player in PlayerIterator:new(self.trick_history.next_leader, 4):iter() do
        local card = played_cards[player]
        card.setLock(false)
        card.setRotation(TEAMS_LAST_TRICKS_ROT[scoring_team])
        card.setPosition(next_global_pos)
        -- The next card is placed relative the previous card
        next_global_pos = card.positionToWorld({2.00, 1.00, 0.00})
    end
    self.previous_trick_cards = played_cards
    self.previous_scoring_team = scoring_team
end
function CoincheRound:dealAgain()
    -- First give all card to one player
    local all_obj = getAllObjects()
    for _, obj in pairs(all_obj) do
        if obj.tag == 'Card' then
            obj.deal(1, FIRST_DEALER)
        elseif obj.tag == 'Deck' then
            for _ = 1,obj.getQuantity() do
                obj.deal(1, FIRST_DEALER)
            end
        end
    end

    -- Then give all card to it's respective player
    Wait.time(function ()
        local player_hand = Player[FIRST_DEALER].getHandObjects()
        for _, card in ipairs(player_hand) do
            local card_player = self:getCardPlayer(card)
            card.deal(1, card_player)
        end
    end, 1.2)
end
function CoincheRound:dumpState()
    return {
        next_leader = self.next_leader,
        contract = self.contract,
        cards_player = self.cards_player,
        trick_count = self.trick_count,
        cards_played = self.cards_played,
        scores = self.scores,
        player_nb_tricks_won = self.player_nb_tricks_won,
        team_nb_tricks_won = self.team_nb_tricks_won,
    }
end
function CoincheRound:newFromState(state)
    round = self:new(nil, nil)
    round.next_leader = state.next_leader
    round.contract = state.contract
    round.cards_player = state.cards_player
    round.trick_count = state.trick_count - 1  -- Minus 1 because of the call to nextTrick
    round.cards_played = state.cards_played
    round.scores = state.scores
    round.player_nb_tricks_won = state.player_nb_tricks_won
    round.team_nb_tricks_won = state.team_nb_tricks_won

    return round
end


CoincheTrick = {}
function CoincheTrick:new(leader, trump_mode, trick_number)
    local obj = {
        leader = leader,
        trump_mode = trump_mode,
        trick_number = trick_number,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end
function CoincheTrick:checkFinished(round)
    -- Get cards in play
    local played_cards = {}
    local card_count = 0
    local player_count = 0

    for _, obj in pairs(PLAYING_ZONE.getObjects()) do
        if obj.tag == 'Card' then
            local card = obj
            if not round:cardAlreadyPlayed(card) then
                local player = round:getCardPlayer(card)
                if played_cards[player] == nil then
                    player_count = player_count + 1
                end
                played_cards[player] = card
                card_count = card_count + 1
            end
        end
    end

    if card_count > 4 then
        broadcastToAll("To many cards on the table", 'Black')
    end

    local trick_is_done = (card_count == 4) and (player_count == 4)

    return trick_is_done, played_cards
end
function CoincheTrick:computeWinner(played_cards)
    local leader_card = played_cards[self.leader]
    local asked_suit = CARDS_SUIT[leader_card.getName()]

    -- Return value
    local winner = nil

    -- Check if check can be ruffed
    if self.trump_mode != NOTRUMP or self.trump_mode != ALLTRUMP or self.trump_mode != asked_suit then
        -- Gather trump cards
        local trump_cards = {}
        for player, card in pairs(played_cards) do
            local card_suit = CARDS_SUIT[card.getName()]
            if card_suit == self.trump_mode then
                trump_cards[player] = card
            end
        end

        -- If there is are trump cards, select a winner among them
        if next(trump_cards) != nil then
            winner = self:computeSuitWinner(trump_cards, TRUMP_ORDER)
        end
    end

    -- If there was no ruffing, the winner is selected among those who followed
    if winner == nil then
        -- Gather suit cards
        local suit_cards = {}
        for player, card in pairs(played_cards) do
            local card_suit = CARDS_SUIT[card.getName()]
            if card_suit == asked_suit then
                suit_cards[player] = card
            end
        end

        -- Selection of the suit order
        local suit_order
        if self.trump_mode == ALLTRUMP or self.trump_mode == asked_suit then
            suit_order = TRUMP_ORDER
        else
            suit_order = SUIT_ORDER
        end

        -- And select de the winner
        winner = self:computeSuitWinner(suit_cards, suit_order)
    end

    return winner
end
function CoincheTrick:computeSuitWinner(played_cards, order)
    local winner
    local winner_rank = 100
    for player, card in pairs(played_cards) do
        local card_face = CARDS_FACE[card.getName()]
        local player_rank = order[card_face]
        if player_rank < winner_rank then
            winner_rank = player_rank
            winner = player
        end
    end

    return winner
end
function CoincheTrick:computeScore(played_cards)
    local default_points_scale
    if self.trump_mode == ALLTRUMP then
        default_points_scale = TRUMP_POINT_SCALE
    else
        default_points_scale = SUIT_POINT_SCALE
    end

    local score = 0
    for _, card in pairs(played_cards) do
        local point_scale = default_points_scale
        local card_suit = CARDS_SUIT[card.getName()]
        local card_face = CARDS_FACE[card.getName()]
        if card_suit == self.trump_mode then
            point_scale = TRUMP_POINT_SCALE
        end
        score = score + point_scale[card_face]
    end

    if self.trick_number == 8 then
        score = score + 10
    end

    return score
end

--[[ Tools -]]

ScoreBoard = {}
function ScoreBoard:new()
    local obj = {
        scores = {TEAM1=0, TEAM2=0},
        row_height = 15,
        max_rows = 29,
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end
function ScoreBoard:scoreRound(winning_team, score)
    -- Here we do tedious manual navigation in the xml. Don't look.
    local current_table = UI.getXmlTable()

    self.scores[winning_team] = self.scores[winning_team] + score
    local team_id = (winning_team == TEAM1 and 1) or 2
    -- Navigation:   Scoreboard panel / Header table / Second row / Winning cell / Text
    local total_text = current_table[3].children[1].children[2].children[team_id].children[1]
    total_text.attributes.text = self.scores[winning_team]

    -- Navigation:    Scoreboard panel / Rounds table / Rows
    local rounds_rows = current_table[3].children[2].children
    if #rounds_rows >= self.max_rows then
        table.remove(rounds_rows, 1)
    end
    rounds_rows[#rounds_rows+1] = self:makeRoundRow(winning_team, score)

    UI.setXmlTable(current_table)
end
function ScoreBoard:makeRoundRow(winning_team, score)
    local team_id = (winning_team == TEAM1 and 1) or 2

    local row = {
        tag = 'Row',
        attributes = { preferredHeight=self.row_height },
        children = {
            { tag='Cell' },
            { tag='Cell' },
        },
    }
    local text = {
        tag = 'Text',
        attributes = { class='Text12', text=score },
    }

    row.children[team_id].children = { text }

    return row
end
function ScoreBoard:resetScores()
    self.scores = {TEAM1=0, TEAM2=0}

    local current_table = UI.getXmlTable()

    -- Reset totals
    local total_texts = current_table[3].children[1].children[2].children
    total_texts[1].children[1].attributes.text= 0
    total_texts[2].children[1].attributes.text= 0

    -- Reset rounds
    current_table[3].children[2].children = {}

    UI.setXmlTable(current_table)
end
function ScoreBoard:dumpState()
    local current_table = UI.getXmlTable()
    return {
        scores = {TEAM1=0, TEAM2=0},
        sb_header = current_table[3].children[1],
        sb_rounds = current_table[3].children[2],
    }
end
function ScoreBoard:restoreState(state)
    self.scores = state.scores
    -- We wait a little here tso that UI.getXmlTable() take into account
    -- the UI onLoad setup. If not we would revert changes.
    Wait.time(function()
        local current_table = UI.getXmlTable()
        current_table[3].children[1] = state.sb_header
        current_table[3].children[2] = state.sb_rounds
        UI.setXmlTable(current_table)
    end, 0.5)
end


PlayerIterator = {}
function PlayerIterator:new(first_player, limit)
    local first_player = first_player or FIRST_DEALER

    local first_index
    for index, color in ipairs(PLAYERS_COLOR) do
        if color == first_player then
            first_index = index
        end
    end

    local obj = {
        next_index = first_index,
        limit = limit,
        count = 0,
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end
function PlayerIterator:next()
    local next_player
    if self.limit == nil or self.count < self.limit then
        next_player = PLAYERS_COLOR[self.next_index]
        self.next_index = (self.next_index % 4) + 1
        self.count = self.count + 1
    end
    return next_player
end
function PlayerIterator:peek_next()
    return PLAYERS_COLOR[self.next_index]
end
function PlayerIterator:iter()
    return function() return self:next() end
end

function print_table(a_table)
    function recursive(x, path)
        for k,v in pairs(x) do
            key_path = path .. '/' .. k
            if type(v) == 'table' then
                recursive(v, key_path)
            else
                print(key_path, ' ', v)
            end
        end
    end

    if a_table == nil then
        print('nil')
    else
        recursive(a_table, '')
    end
end
