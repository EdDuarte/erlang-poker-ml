
-module(poker).
-export([start/0, pair/3, twoPair/5, threeOfAKind/4, fourOfAKind/5, fullHouse/6, straight/6, flush/6, royalFlush/6, compareHands/3]).


% To print debug messages, use c(poker, {d, debug}) when compiling
-ifdef(debug).
    -define(DBG(Str, Args), io:format(Str, Args)).
-else.
    -define(DBG(Str, Args), ok).
-endif.

%%% ==============================================================================================
%%%                                              MAIN
%%% ==============================================================================================

% Card  format: {card, UniqueID, Suit, Value}
%     Suit  = spades, clubs, hearts or diamonds
%     Value = 2..10, Jack, Queen, King or Ace
% Hand  format: {hand, Hand Type}
%     Hand Type  = highCard, pair, twoPair, threeOfAKind, fourOfAKind,
%                  fullHouse, straight, flush, straightFlush or royalFlush

start() ->
    ?DBG("[DEBUG-MAIN] Starting Poker application...~n",[]),
    eresye:start(main),
    startHistory(),
    reset().

reset() ->
    clear(),
    InitialPot = askPot(false),
    menu(InitialPot, 0, 0, 1).

clear() ->
    eresye:stop(main), % clears the KB for a new match
    eresye:start(main),
    lists:foreach(fun(X) -> eresye:add_rule(main, {?MODULE, X}) end,
    [
        compareHands,
        royalFlush,
        fullHouse,
        flush,
        straight,
        fourOfAKind,
        threeOfAKind,
        twoPair,
        pair
    ]),
    eresye:assert(main, {hand, highCard}).



%% :::::::::::::::::::::::::::::: Menu ::::::::::::::::::::::::::::::
menu(Pot, PlayerTotalBets, RoundNo, Counter) ->
    case (RoundNo) of
        0 -> io:format("~s CARD IN YOUR HAND~n", [getOrdinal(Counter)]);
        _ -> io:format("~s CARD IN THE TABLE~n", [getOrdinal(Counter)])
    end,
    io:format("(write 'reset' at any time to start again from round 0)~n"),
    io:format("(write 'close' at any time to close the application)~n"),
    NewCounter = Counter + 1,

    {ok, [Suit]} =  io:fread("Suit : ","~a"),
    case (Suit) of
        close -> saveStorage(), exit(poker);
        reset -> reset();
        _ ->
            {ok, [Value]} = io:fread("Value: ","~s"),
            case (Value) of
                close -> saveStorage(), exit(poker);
                reset -> reset();
                _ ->
                    case (validate(Suit, Value)) of
                        {true, true} ->
                            addCard(Suit, Value),
                            case ({RoundNo, NewCounter}) of % detect end of each round
                                {0, 3} ->
                                    addHistory(0),
                                    NewPlayerTotalBets = doProbabilities(Pot, PlayerTotalBets, 0),
                                    CurrentPot = askPot(true),
                                    menu(CurrentPot, NewPlayerTotalBets, 1, 1);
                                {1, 4} ->
                                    addHistory(1),
                                    NewPlayerTotalBets = doProbabilities(Pot, PlayerTotalBets, 1),
                                    CurrentPot = askPot(true),
                                    menu(CurrentPot, NewPlayerTotalBets, 2, 4);
                                {2, 5} ->
                                    addHistory(2),
                                    NewPlayerTotalBets = doProbabilities(Pot, PlayerTotalBets, 2),
                                    CurrentPot = askPot(true),
                                    menu(CurrentPot, NewPlayerTotalBets, 3, 5);
                                {3, 6} ->
                                    addHistory(3),
                                    doProbabilities(Pot, PlayerTotalBets, 3),
                                    menuEnd();
                                _ -> menu(Pot, PlayerTotalBets, RoundNo, NewCounter)
                            end;
                        _ ->
                            io:format("ERROR! One of the inserted values was invalid! Please try again!~n"),
                            menu(Pot, PlayerTotalBets, RoundNo, Counter)
                    end
            end
    end.

menuEnd() ->
    io:format("FINAL RESULT~n", []),
    io:format("(write 'reset' at any time to start again from round 0)~n"),
    io:format("(write 'close' at any time to close the application)~n"),
    {ok, [Status]} = io:fread("Result ('won' or 'lost'): ","~a"),
    case (Status) of
        won -> addVictoryToHistory(hd(getCurrentHands())), addHistoryFinal(), reset();
        lost -> addDefeatToHistory(hd(getCurrentHands())), addHistoryFinal(), reset();
        close -> saveStorage(), exit(poker);
        reset -> reset();
        _ -> io:format("Invalid answer! Try again!~n"), menuEnd()
    end.

askPot(IsCurrent) ->
    case (IsCurrent) of
        true -> S = "Current Pot Value: ";
        false -> S = "Initial Pot Value: "
    end,
    {ok, [Pot]} = io:fread(S,"~s"),
    case (Pot) of
        "close" -> saveStorage(), exit(poker);
        "reset" -> reset();
        _ -> {ConvertedValue, []} = string:to_integer(Pot), ConvertedValue
    end.


%% ::::::::::::::::::::::::::::: Addition ::::::::::::::::::::::::::::
addCard(Suit, Value) ->
    eresye:assert(main, {card, random:uniform(), Suit, Value}).

addHistory(0) ->
    timer:sleep(2000), % allow rules to process
    CurrentHand = hd(getCurrentHands()),
    eresye:assert(main, {history, 0, CurrentHand, none});

addHistory(RoundNo) ->
    [{_, _, Last_Hand, _}] = eresye:query_kb(main, {history, RoundNo-1, '_', '_'}),
    timer:sleep(2000), % allow rules to process
    CurrentHand = hd(getCurrentHands()),
    eresye:assert(main, {history, RoundNo, CurrentHand, Last_Hand}).

addHistoryFinal() ->
    [addHandToHistory(RoundNo, CurrentHand, LastHand) || {history, RoundNo, CurrentHand, LastHand} <- eresye:query_kb(main, {history, '_', '_', '_'}), RoundNo=/=0],
    incrementNumberOfMatches().

getCurrentHands() ->
    HandList = eresye:query_kb(main, {hand, '_'}),
    ?DBG("[DEBUG-MAIN] Currently stored hands:~p~n", [HandList]),
    HandList.



%% :::::::::::::::::::::::::::: Validation :::::::::::::::::::::::::::
validate(Suit, Value) ->
    {validateSuit(Suit), validateValue(Value)}.

validateSuit(Suit)
when Suit=:=spades orelse Suit=:=hearts orelse Suit=:=clubs orelse Suit=:=diamonds -> true;
validateSuit(_) -> false.

validateValue(Value) ->
    case (string:to_integer(Value)) of
        {ConvertedValue, []} -> validateNumberValue(ConvertedValue);
        {error, no_integer} -> validateFigureValue(list_to_atom(Value))
    end.
validateNumberValue(V) when V>=2, V=<10 -> true;
validateNumberValue(_) -> false.
validateFigureValue(V) when V=:=jack orelse V=:=queen orelse V=:=king orelse V=:=ace -> true;
validateFigureValue(_) -> false.



%% ::::::::::::::::::::::::::::::: Rules :::::::::::::::::::::::::::::::
pair(Engine,
    {card, ID1, Suit1, SameValue},
    {card, ID2, Suit2, SameValue})
when ID1=/=ID2 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Pair!~n",[]),
    eresye:assert(Engine, {hand, pair}).

straight(Engine,
    {card, ID1, Suit1, Value1},
    {card, ID2, Suit2, Value2},
    {card, ID3, Suit3, Value3},
    {card, ID4, Suit4, Value4},
    {card, ID5, Suit5, Value5})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4, ID1=/=ID5,
     ID2=/=ID3, ID2=/=ID4, ID2=/=ID5,
     ID3=/=ID4, ID3=/=ID5,
     ID4=/=ID5 ->
    case (string:to_integer(Value1)) of
        {CV1, []} -> NValue1 = CV1;
        {error, no_integer} -> NValue1 = Value1
    end,
    case (string:to_integer(Value2)) of
        {CV2, []} -> NValue2 = CV2;
        {error, no_integer} -> NValue2 = Value2
    end,
    case (string:to_integer(Value3)) of
        {CV3, []} -> NValue3 = CV3;
        {error, no_integer} -> NValue3 = Value3
    end,
    case (string:to_integer(Value4)) of
        {CV4, []} -> NValue4 = CV4;
        {error, no_integer} -> NValue4 = Value4
    end,
    case (string:to_integer(Value5)) of
        {CV5, []} -> NValue5 = CV5;
        {error, no_integer} -> NValue5 = Value5
    end,
    case (isStraight([NValue1, NValue2, NValue3, NValue4, NValue5])) of
        true ->
            ?DBG("[DEBUG-MAIN] Current cards make a Straight!~n",[]),
            eresye:assert(Engine, {hand, straight});
        false -> false
    end.

royalFlush(Engine,
    {card, ID1, SameSuit, ace},
    {card, ID2, SameSuit, king},
    {card, ID3, SameSuit, queen},
    {card, ID4, SameSuit, jack},
    {card, ID5, SameSuit, 10})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4, ID1=/=ID5,
     ID2=/=ID3, ID2=/=ID4, ID2=/=ID5,
     ID3=/=ID4, ID3=/=ID5,
     ID4=/=ID5 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Royal Flush!~n",[]),
    eresye:assert(Engine, {hand, royalFlush}).

flush(Engine,
    {card, ID1, Suit1, _},
    {card, ID2, Suit2, _},
    {card, ID3, Suit3, _},
    {card, ID4, Suit4, _},
    {card, ID5, Suit5, _})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4, ID1=/=ID5,
     ID2=/=ID3, ID2=/=ID4, ID2=/=ID5,
     ID3=/=ID4, ID3=/=ID5,
     ID4=/=ID5,
     Suit1=:=Suit2, Suit2=:=Suit3, Suit3=:=Suit4, Suit4=:=Suit5 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Flush!~n",[]),
    eresye:assert(Engine, {hand, flush}).

twoPair(Engine,
    {card, ID1, Suit1, SameValue1},
    {card, ID2, Suit2, SameValue1},
    {card, ID3, Suit3, SameValue2},
    {card, ID4, Suit4, SameValue2})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4,
     ID2=/=ID3, ID2=/=ID4,
     ID3=/=ID4 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Two Pair!~n",[]),
    eresye:assert(Engine, {hand, twoPair}).

threeOfAKind(Engine,
    {card, ID1, Suit1, SameValue},
    {card, ID2, Suit2, SameValue},
    {card, ID3, Suit3, SameValue})
when ID1=/=ID2, ID1=/=ID3,
     ID2=/=ID3 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Three of a kind!~n",[]),
    eresye:assert(Engine, {hand, threeOfAKind}).

fourOfAKind(Engine,
    {card, ID1, Suit1, SameValue},
    {card, ID2, Suit2, SameValue},
    {card, ID3, Suit3, SameValue},
    {card, ID4, Suit4, SameValue})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4,
     ID2=/=ID3, ID2=/=ID4,
     ID3=/=ID4 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Four of a Kind!~n",[]),
    eresye:assert(Engine, {hand, fourOfAKind}).

fullHouse(Engine,
    {card, ID1, _, Value1},
    {card, ID2, _, Value2},
    {card, ID3, _, Value3},
    {card, ID4, _, Value4},
    {card, ID5, _, Value5})
when ID1=/=ID2, ID1=/=ID3, ID1=/=ID4, ID1=/=ID5,
     ID2=/=ID3, ID2=/=ID4, ID2=/=ID5,
     ID3=/=ID4, ID3=/=ID5,
     ID4=/=ID5,
     Value1 =:= Value2, Value2=:=Value3,
     Value4 =:= Value5 ->
    ?DBG("[DEBUG-MAIN] Current cards make a Full House!~n",[]),
    eresye:assert(Engine, {hand, fullHouse}).

isStraight(["jack", "queen", "king", "ace"]) ->
    true;
isStraight(["jack", "queen", "king"]) ->
    true;
isStraight(["jack", "queen"]) ->
    true;
isStraight(["jack"]) ->
    true;
isStraight([H1, H2, H3, H4, H5]) ->
    case H1 of
        "ace" -> false;
        "jack" -> false;
        "queen" -> false;
        "king" -> false;
        10 -> isStraight([H2, H3, H4, H5]);
        _ -> checkStraightNumbersOnly(H1, [H2, H3, H4, H5])
    end;
isStraight(_) ->
    false.

checkStraightNumbersOnly(LastNumber, [H]) when is_number(H) ->
    LastNumber+1=:=H;
checkStraightNumbersOnly(LastNumber, [H|T]) when is_number(H) ->
    case (LastNumber+1=:=H) of
        true -> checkStraightNumbersOnly(H, T);
        false -> false
    end;
checkStraightNumbersOnly(10, L) ->
    isStraight(L); % last number was 10 and there are still cards to check (must be figures)
checkStraightNumbersOnly(_, _) ->
    false.



%% :::::::::::::::::::::::::: Hand Comparisson :::::::::::::::::::::::::
% The functions below cycle every stored hand in the engine in order
% to look for the best possible hand with the current available cards.%
% NOTE: Hand Comparisson is also a rule of the Main rules engine
compareHands(Engine, {hand, royalFlush}, {hand, Type2})
when Type2=/=royalFlush ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, royalFlush]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, straightFlush}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, straightFlush]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, fourOfAKind}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, fourOfAKind]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, fullHouse}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind, Type2=/=fullHouse ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, fullHouse]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, straight}, {hand, flush}) ->
    ?DBG("[DEBUG-MAIN] Current cards make a Straight Flush!~n",[]),
    eresye:retract(Engine, {hand, flush}),
    eresye:retract(Engine, {hand, straight}),
    eresye:assert(Engine, {hand, straightFlush});

compareHands(Engine, {hand, flush}, {hand, straight}) ->
    ?DBG("[DEBUG-MAIN] Current cards make a Straight Flush!~n",[]),
    eresye:retract(Engine, {hand, flush}),
    eresye:retract(Engine, {hand, straight}),
    eresye:assert(Engine, {hand, straightFlush});

compareHands(Engine, {hand, flush}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind, Type2=/=fullHouse, Type2=/=flush, Type2=/=straight ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, flush]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, straight}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind, Type2=/=fullHouse, Type2=/=flush, Type2=/=straight ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, straight]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, threeOfAKind}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind, Type2=/=fullHouse, Type2=/=flush, Type2=/=straight, Type2=/=threeOfAKind ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, threeOfAKind]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, twoPair}, {hand, Type2})
when Type2=/=royalFlush, Type2=/=straightFlush, Type2=/=fourOfAKind, Type2=/=fullHouse, Type2=/=flush, Type2=/=straight, Type2=/=threeOfAKind, Type2=/=twoPair ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [Type2, twoPair]),
    eresye:retract(Engine, {hand, Type2});

compareHands(Engine, {hand, pair}, {hand, highCard}) ->
    ?DBG("[DEBUG-MAIN] Retracting ~p from engine in preference of ~p!~n", [highCard, pair]),
    eresye:retract(Engine, {hand, highCard}).



getOrdinal(1) -> "FIRST";
getOrdinal(2) -> "SECOND";
getOrdinal(3) -> "THIRD";
getOrdinal(4) -> "FOURTH";
getOrdinal(5) -> "FIFTH".










%%% ==============================================================================================
%%%                                            HISTORY
%%% ==============================================================================================

% Round format: {Round Number (0..3), Hand Type, Hand from Last Round, Number of Occurences}
%     Round 0: the two cards in the player's hand
%     Round 1: the first three cards in the table
%     Round 2: the forth card in the table
%     Round 3: the fifth card in the table
% Result format: {Status (won / lost), Hand Type, Number of Occurences}



startHistory() ->
    ?DBG("[DEBUG-HISTORY] Starting History...~n",[]),
    eresye:start(history),
    readStorage(),
    case (length(eresye:query_kb(history, {total, '_'}))) of
        0 -> eresye:assert(history, {total, 0});
        _ -> ok
    end.



%% :::::::::::::::::::::::::::::: Storage :::::::::::::::::::::::::::::
% Reads the last saved data from a file and add it to the engine
readStorage() ->
    ?DBG("[DEBUG-HISTORY] Reading stored history...~n",[]),
    {ok, FILE} = file:open("storage", [read]),
    readStorage(FILE),
    file:close(FILE).
readStorage(FILE) ->
    case (file:read_line(FILE)) of
        {ok, StringLine} ->
            % ?DBG("[DEBUG-HISTORY] Read the line '~p'~n",[StringLine]),
            {ok, Tokens, _} = erl_scan:string(StringLine ++ "."),
            % ?DBG("[DEBUG-HISTORY] Tokens detected '~p'~n",[Tokens]),
            {ok, TUPLE} = erl_parse:parse_term(Tokens),
            eresye:assert(history, TUPLE),
            readStorage(FILE);
        eof ->
            done;
        {error, Reason} ->
            io:format("[HISTORY] An error occurred while reading the storage file. Reason: ~p~n", Reason)
    end.

% Saves the current data in the engine into a file
saveStorage() ->
    ?DBG("[DEBUG-HISTORY] Saving stored history...~n",[]),
    {ok, FILE} = file:open("storage", [write]),
    saveStorage(FILE, eresye:get_kb(history)),
    file:close(FILE).
saveStorage(File, List) ->
    file:write_file(File, lists:foreach(fun(E) ->
        ?DBG("[DEBUG-HISTORY] ~p~n", [E]),
        io:fwrite(File, "~p\n", [E])
    end, List)).



%% ::::::::::::::::::::::::::::: Addition ::::::::::::::::::::::::::::
% Increments the total amount of matches played
incrementNumberOfMatches() ->
    case (eresye:query_kb(history, {total, '_'})) of
        [{_, Num}] ->
            eresye:retract(history, {total, Num}),
            NewNum = Num + 1;
        [] ->
            NewNum = 1
    end,
    eresye:assert(history, {total, NewNum}).

% Adds or increments the specified hand at the specified round number
addHandToHistory(RoundNo, {hand, HandType}, {hand, LastHandType}) ->
    ?DBG("[DEBUG-HISTORY] Round ~p: has a ~p knowing that the player had a ~p in the last round~n", [RoundNo, HandType, LastHandType]),
    case (eresye:query_kb(history, {RoundNo, HandType, LastHandType, '_'})) of
        [{_, _, _, NoOccurrences}] ->
            eresye:retract(history, {RoundNo, HandType, LastHandType, NoOccurrences}),
            NewNoOccurrences = NoOccurrences + 1;
        [] ->
            NewNoOccurrences = 1
    end,
    eresye:assert(history, {RoundNo, HandType, LastHandType, NewNoOccurrences}).

% Increments the specified hand that made the player win
addVictoryToHistory({hand, HandType}) ->
    ?DBG("[DEBUG-HISTORY] Won with hand ~p~n", [HandType]),
    addAux(won, HandType).

% Increments the specified hand that made the player lose
addDefeatToHistory({hand, HandType}) ->
    ?DBG("[DEBUG-HISTORY] Lost with hand ~p~n", [HandType]),
    addAux(lost, HandType).

addAux(A, B) ->
    case (eresye:query_kb(history, {A, B, '_'})) of
        [{_, _, NoOccurrences}] ->
            eresye:retract(history, {A, B, NoOccurrences}),
            NewNoOccurrences = NoOccurrences + 1;
        [] ->
            NewNoOccurrences = 1
    end,
    eresye:assert(history, {A, B, NewNoOccurrences}).



%% :::::::::::::::::::::::::::: Retrieval :::::::::::::::::::::::::::
% Retrieves the total number of finished matches recorded
getTotal() ->
    % length([B || {A, B, _} <- eresye:get_kb(history), A=:=won orelse A=:=lost]).
    [{total, Num}] = eresye:query_kb(history, {total, '_'}),
    Num.

% Retrieves the number of times the specified HandType showed up at the specified RoundNo,
% KNOWING THAT the specified PreviousHandType showed up in the round before
getOccurences(RoundNo, HandType, PreviousHandType) when RoundNo>=0, RoundNo=<3 ->
    List = [NoOccurrences || {_, _, _, NoOccurrences} <- eresye:query_kb(history, {RoundNo, HandType, PreviousHandType, '_'})],
    case (List) of
        [] -> 0;
        _ -> hd(List)
    end.

% Retrieves a list of obtained hands (and the number of times that occured) at the
% specified round KNOWING THAT the player currently has the specified card
getPossibleHands(RoundNo, CurrentHandType) ->
    [{Hand, NoOccurrences} || {_, Hand, _, NoOccurrences} <- eresye:query_kb(history, {RoundNo, '_', CurrentHandType, '_'})].

% Retrieves the number victories accomplished with the specific hand type
getNumberOfWins(HandType) ->
    List = [X || {_, _, X} <- eresye:query_kb(history, {won, HandType, '_'})],
    case (length(List)) of
        0 -> 0;
        _ -> lists:foldl(fun(X, Sum) -> X + Sum end, 0, List)
    end.

% Retrieves the number losses accomplished with the specific hand type
getNumberOfDefeats(HandType) ->
    List = [X || {_, _, X} <- eresye:query_kb(history, {lost, HandType, '_'})],
    case (length(List)) of
        0 -> 0;
        _ -> lists:foldl(fun(X, Sum) -> X + Sum end, 0, List)
    end.








%%% ==============================================================================================
%%%                                         DECISION TREE
%%% ==============================================================================================

% A new tree is always constructed for every new round (which means a new Probability of Winning)
buildTree(Pot, PlayerTotalBet, PWin) ->
    T = spawn(fun()-> tree(none) end),
    T ! {add, action, none, none},
        % RaisedValues = lists:seq(100, 5000),
        % lists:foreach(fun(X) ->
            T ! {add, raise, ((Pot + 1000) * PWin), action},
        % end, RaisedValues),
        T ! {add, fold, (-PlayerTotalBet), action},
        T ! {add, call, (PWin * Pot), action},
    T.



%% ::::::::::::::::::::::::::::: Probability ::::::::::::::::::::::::::::
doProbabilities(Pot, PlayerTotalBet, RoundNo) ->
    {hand, CurrentHandType} = hd(getCurrentHands()),
    PWin = pWin(RoundNo, CurrentHandType),
    T = buildTree(Pot, PlayerTotalBet, PWin),
    T ! {self(), solve},
    receive
        {Action, EstimatedProfit, _} ->
            Total = getTotal(),
            io:format("~n+------ PROBABILITIES --------------------------------------------~n"),
            io:format("| Current hand: ~p~n", [CurrentHandType]),
            io:format("| Winning with current hand: ~p~n", [PWin]),
            PossibleList = [{HandType, NoOccurrences/Total} ||
                    {HandType, NoOccurrences} <- getPossibleHands(RoundNo+1, CurrentHandType)],
            io:format("| Possible Hands for next round: ~w~n", [PossibleList]),
            case (Action) of
                raise ->
                    io:format("| RAISE 1000 for aproximate profit of ~p~n", [trunc(EstimatedProfit)]),
                    NewPlayerTotalBet = PlayerTotalBet + 1000;
                call ->
                    io:format("| CHECK for aproximate profit of ~p~n", [trunc(EstimatedProfit)]),
                    NewPlayerTotalBet = PlayerTotalBet;
                fold ->
                    io:format("| FOLD and lose aproximately ~p~n", [trunc(EstimatedProfit)]),
                    NewPlayerTotalBet = PlayerTotalBet
            end,
            io:format("+-----------------------------------------------------------------~n")
    end,
    NewPlayerTotalBet.



% Probability of winning with a specific hand at the specified round
pWin(RoundNo, CurrentHandType) ->
    Total = getTotal(),
    List = [((PossibleHandOccurences/Total) * (getNumberOfWins(PossibleHand)/Total)) ||
                {PossibleHand, PossibleHandOccurences} <- getPossibleHands(RoundNo+1, CurrentHandType)],
    getNumberOfWins(CurrentHandType)/Total + lists:foldl(fun(X, Sum) -> X + Sum end, 0, List).



%% ::::::::::::::::::::::: Internal Tree Functions ::::::::::::::::::::::
tree(Tree) ->
    receive
        {add, Node, Edge, Parent} ->
            NewTree = add(Tree, Node, Edge, Parent),
            tree(NewTree);
        {PID, solve} ->
            PID ! calc(Tree),
            tree(Tree)
    end.


add(none, Node, Edge, _) -> {Node, Edge, []}; % 1st node
add({Parent, P_Edge, L}, Node, Edge, Parent) -> {Parent, P_Edge, [{Node, Edge, []}|L]}; % we find the parent node and insert the new node
add({Root, R_Edge, []}, _, _, _) -> {Root, R_Edge, []}; % recursion stop when the parent node is not found
add({Root, R_Edge, L}, Node, Edge, Parent) -> {Root, R_Edge, lists:map(fun(N) -> add(N, Node, Edge, Parent) end, L)}. % we try to insert the node in all subtrees


calc({action, none, [H|T]}) -> maxProfit(H, T).

maxProfit(MAX, []) -> MAX;
maxProfit({A, AProfit, AList}, [{_, BProfit, _}|T]) when AProfit >= BProfit ->
    maxProfit({A, AProfit, AList}, T);
maxProfit(_, [{B, BProfit, BList}|T]) ->
    maxProfit({B, BProfit, BList}, T).