# TF2Instagib

Instagib gamemode for Team Fortress 2 with special rounds and other neat stuff.

## Build status
Linux |
--- |
[![Build Status](https://travis-ci.com/haxtonsale/TF2Instagib.svg?branch=master)](https://travis-ci.com/haxtonsale/TF2Instagib)

## Required Extensions
* [TF2Items](https://builds.limetech.io/?project=tf2items)

## Optional Extensions
* [SteamTools](https://builds.limetech.io/?p=steamtools)

## Creating custom Special Rounds
Quick rundown with a code example:
```c
#include <sourcemod>
#include <instagib>

public void IG_OnMapConfigLoad()
{
	InstagibRound round;
	
	// Fills the round array with default and config values
	IG_InitializeSpecialRound(round, "Round Name", "Round Description");
	
	// Each kill will give 2 points instead of 1
	round.PointsPerKill = 2;
	
	// Limit the round time to 5 minutes
	round.RoundTime = 300;
	
	// Add a callback function that will be called only when this special round starts
	round.OnStart = CustomRound_OnStart;
	
	// Add a callback function that will be called every time a player spawns
	round.OnPlayerSpawn = CustomRound_OnSpawn;
	
	// Add the round to the list of Special Rounds. It can't be edited or removed after this.
	IG_SubmitSpecialRound(round);
} 

public void CustomRound_OnStart()
{
	PrintToServer("The round has started");
}

public void CustomRound_OnSpawn(int client, TFTeam team)
{
	PrintToServer("Player %N has spawned", client);
}
```
Check out [instagib.inc](https://github.com/haxtonsale/TF2Instagib/blob/master/scripting/include/instagib.inc) for all available round properties and callbacks.

