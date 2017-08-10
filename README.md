
# Erlang Poker Machine-Learning

This is an application that uses statistical data collected over time to predict outcomes in Texas Hold'em matches. It provides a CLI interface that prompts the user to fill the card in his/her hand and table for each round, and whenever the user won or lost each match. This information is stored and queried using [Eresye](http://sourceforge.net/projects/eresye/), a rule-based knowledge management engine, and the probabilities of occurrence for each card per round, along with the probability of winning or losing the match with the current cards, are recalculated at the end of every match and organized into a decision tree. At each round, the probability of getting a good hand and win the match is read from the Decision tree and printed to the user, suggesting him to either raise, call or fold.

The entire application and the state-less decision tree classifier are fully implemented in Erlang, in the file 'poker.erl'. A trained model containing the history of matches and ranked hands is also provided ('storage' file), so you can start testing the application immediately.

[You can find more info about the implementation of this app on my blog](https://edduarte.com/erlang-poker-ml/).
