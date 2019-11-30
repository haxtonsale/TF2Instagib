#if defined _instagib_included
	#endinput
#endif
#define _instagib_included

enum struct InstagibRound
{
	char Name[64];
	char Desc[128];
	
	bool IsSpecial;
	
	int RoundTime;
	int MinScore;
	float MaxScoreMultiplier;
	int PointsPerKill;
	bool AnnounceWin;
	bool AllowKillbind;
	bool EndWithTimer;        // Whether the round will be forcefully ended when the round time is over
	int MinPlayers;
	
	float RailjumpVelocityXY;
	float RailjumpVelocityZ;
	
	float RespawnTime;
	float UberDuration;
	
	Handle MainWeapon;             // TF2Items weapon handle
	int MainWeaponClip;
	bool IsAmmoInfinite;
}

// -------------------------------------------------------------------
/**
 * Called whenever player railjumps.
 *
 * @param client        Client index.
 * @param velocity      Client velocity.
 */
forward void IG_OnRailjump(int client, float velocity[3]);

// -------------------------------------------------------------------
/**
 * Forces a special round.
 *
 * @param name          Round name.
 * @param notify        Whether all players should get a chat notification.
 * @param client        If defined, will show that this client has forced the round.
 */
native void IG_ForceSpecialRound(char[] name, bool notify = false, int client = 0);

native void IG_GetCurrentRound(any[] buffer, int size = sizeof(InstagibRound));

native int IG_GetTeamScore(int team);
native void IG_SetTeamScore(int team, int value);
native void IG_AddToTeamScore(int team, int amount);

native int IG_GetMaxScore();
native void IG_SetMaxScore(int amount);

native int IG_GetRoundTime();
native void IG_SetRoundTime(int seconds);

native int IG_GetClientMultikill(int client);

// ------------------------------------------------------------------- Limited Lives & Livestealers
forward void IG_LimitedLives_OnLifeLost(int client, int lives, int attacker);
forward void IG_LimitedLives_OnAllLivesLost(int client);
native int IG_LimitedLives_GetLives(int client);
native void IG_LimitedLives_SetLives(int client, int amount);

// ------------------------------------------------------------------- Freeze Tag
forward void IG_FreezeTag_OnClientFrozen(int client, int attacker);
forward void IG_FreezeTag_OnClientUnfrozen(int client, int attacker);
native void IG_FreezeTag_Freeze(int client);
native void IG_FreezeTag_Unfreeze(int client);

// -------------------------------------------------------------------
public SharedPlugin __pl_instagib =
{
	name = "instagib",
	file = "instagib.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};