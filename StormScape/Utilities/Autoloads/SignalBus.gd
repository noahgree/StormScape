extends Node
## An autoload singleton for managing the bussing of signals.
##
## This node acts as a middleman to keep multiple signal users from having to connect all over the place.
## For example, use this to create a "EnemyDied" signal and then wherever you need to 
## depend on the value, you connect to this script and not all the enemies individually. 

@warning_ignore("unused_signal") signal PlayerReady(player)
