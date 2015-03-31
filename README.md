
# Poker Machine Learning

This is an application developed in Erlang that uses statistical data collected over time to predict outcomes in Texas Hold'em matches.

It works by prompting the user to fill the card in hand and table for each round, and whenever the user won or lost each match. This information is stored to a local file, and the probabilities of occurrence for each card per round, along with the probability of winning or losing the match with the current cards, are recalculated at the end of every match and organized into a Decision tree. At each round, the probability of getting a good hand and win the match is read from the Decision tree and printed to the user, suggesting him to either raise, call or fold.

The application is implemented in the file 'poker.erl'. A trained model containing the history of matches and ranked hands is also provided as the 'storage' file, so you can test the application with more accurate predictions than the ones obtained from an empty history.

This application is separated in three modules:
- a main module, which uses [Eresye](http://sourceforge.net/projects/eresye/), a rule-based knowledge management engine, to store Texas Hold'em rules and hand rankings;
- a history module, which stores the number of occurrences and the ranking of hands;
- a tree module, that implements the decision tree and the probability calculation methods.

## Preliminaries

A match is considered a result of seven cards that occurred throughout four rounds. A ranked hand is a specific set of cards that have a specific rank, namely: 1. Royal Flush; 2. Straight Flush; 3. Four Of A Kind; 4. Full House; 5. Flush; 6. Straight; 7. Three Of A Kind; 8. Two Pair; 9. Pair; 10. High Card.

The four rounds are numbered from 0 to 3:
- Round 0: when the user is given 2 cards
- Round 1: when the first, second and third cards on the table are shown
- Round 2: when the fourth card on the table is shown
- Round 3: when the fifth card on the table is shown

With this, we consider that is possible to raise, call or fold between the four rounds, hence, three phases of betting.
In this implementation, draws / split results are not considered, so as to not influence the collected probabilities of winning or losing by reducing both.

## Main module

The main module uses the rule-based engine Eresye to store variables per match and Texas Hold'em hand rankings. For each match, the user is prompted to input:
- the 7 cards that are visible to the user;
- the current pot value;
- the final result of the game ('won' or 'lost').

Some additional inputs can be used at any time:
- "reset": discards the current match inputs and starts again from round 0;
- "close": saves the current history data into a local file 'storage' and closes the application.

The current match data is only committed to history at the end of the match, so a "reset" will discard the current match.

When prompting for a card, two inputs are required: the suit and the value. Inputted cards are then structured as {card, ID, Suit, Value} and compared with ranked hands in Eresye. The ID value is randomly attributed using the method 'random:uniform()', and is used to ensure that the card will not be compared with itself during comparisons with Eresye's rules.



## Decision tree module

The decision tree module implements a Decision tree where each node corresponds to a round, and each round has 3 branches pointing to 3 child nodes. Each branch and node stores, respectively:
- branch1 - Expected profit on Raise; node1 - Raise value
- branch2 - Expected profit on Fold; node2 - Fold value
- branch3 - Expected profit on Call; node3 - Call value

Because the probability of winning (PWin) varies according to the user's hand and the current round, this decision tree is built at the end of each round, and the expected profits are calculated as such:

![Formula 1](/img/formula1.png?raw=true "Expected profit on Raise")

![Formula 2](/img/formula2.png?raw=true "Expected profit on Fold")

![Formula 3](/img/formula3.png?raw=true "Expected profit on Call")

BetsDoneByPlayer is the total value of bets done by the user to that point, or in other words, the number of chips the user placed in the pot.

PWin can be calculated using the History module and its Bayesian network (see below), where we can obtain the number of victories attained with the CurrentHand, but also the possible hands that can be obtained in future rounds knowing the CurrentHand. So:

![Formula 4](/img/pwin.png?raw=true "PWin")

Once all of the expected profits are calculated, the action that the user should take corresponds to the one that has the higher expected profit.



## History module

The history module is a data history, implemented using an alternative Eresye engine (different from the one used in the main module). Essentially, using Eresye allows the usage of insertion and query within a single variable that does not need to be passed along functions, something that would otherwise be impossible to do in native Erlang. In addition, the query implementation of Eresye enables the retrieval of tuples without knowing all of its data, using the wildcard '_' (underscore).

The data in storage is structured as:

- {round_number, current_ranked_hand, previous_round_ranked_hand, number_of_occurrences}: assuming R as the current round and R as the next round, we can calculate the probability of obtaining a ranked hand Y knowing that the user currently has a ranked hand X;

- {won/lost, current_ranked_hand, number_of_occurrences}: the number of times the user won or lost with a specific ranked hand;

- {total, number_of_total_matches}: the total number of matches that were played with the application.

By storing the history on the local file 'storage', we have a continually trained model, persistent between different application sessions.

The prediction of outcomes is based on conditional probabilities per round. For example, for the following match...
- Round 0 = High Card
- Round 1 = Pair
- Round 2 = Pair
- Round 3 = Two Pair

... the conditional probability for each round is calculated as follows, in pseudo-code:
- Total = query(total, _)
- Round 0 -> P(Pair | HighCard) = query(round1, pair, highCard, _) / Total
- Round 1 -> P(Pair | Pair) = query(round2, pair, pair, _) / Total
- Round 2 -> P(TwoPair | Pair) = query(round3, twoPair, pair, _) / Total





