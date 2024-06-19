#if defined _instagib_included
	#endinput
#endif
#define _instagib_included

#include <tf2>

enum struct Round_OnDeath_Data
{
	int victim;
	int attacker;
	int assister;
	int penetrate_count;
	int customkill;
	int damagetype;
	int weaponid;
	int stun_flags;
	int killstreak;
	int killstreak_victim;
	int inflictor_entity;
}

enum struct InstagibRound
{
	char Name[64];
	char Desc[128];
	Handle OwnerPlugin;
	
	bool IsSpecial;
	int RoundTime;
	int MinScore;
	float MaxScoreMultiplier;
	int PointsPerKill;
	bool AnnounceWin;
	bool AllowKillbind;
	bool EndWithTimer;       // Whether the round will be forcefully ended when the round time is over
	int MinPlayers;
	float RespawnTime;
	float UberDuration;
	float RailjumpVelocityXY;
	float RailjumpVelocityZ;
	bool AllowTraces;
	TFClassType Class;
	
	Handle MainWeapon;
	int MainWeaponClip;
	bool IsAmmoInfinite;
	
	Function OnStart;
	Function OnEnd;
	Function OnPlayerSpawn;
	Function OnPostInvApp;
	Function OnPlayerDeath;
	Function OnTraceAttack;
	Function OnEntCreated;
	Function OnPlayerDisconnect;
	Function OnTeamChange;
	Function OnClassChange;
	Function OnDamageTaken;
	Function OnDescriptionPrint;
}

typedef Round_OnStart =           function void ();
typedef Round_OnEnd =             function void (TFTeam winner_team, int score, int time_left);
typedef Round_OnSpawn =           function void (int client, TFTeam team);
typedef Round_OnPostInvApp =      function void (int client);
typedef Round_OnTraceAttack =     function void (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup);
typedef Round_CustomDescription = function void (char[] description,  int maxlength);
typedef Round_OnEntityCreated =   function void (int ent, const char[] classname);
typedef Round_OnDisconnect =      function void (int client);
typedef Round_OnDeath =           function void (Round_OnDeath_Data data);
typedef Round_OnTeamChange =      function void (int client, TFTeam team);
typedef Round_OnClassChange =     function void (int client, int class);
typedef Round_OnTakeDamage =      function Action (int victim, int &attacker, int &inflictor, float &damage, int &damagetype);

// -------------------------------------------------------------------
/**
 * Called whenever player railjumps.
 *
 * @param client        Client index.
 * @param velocity      Client velocity.
 */
forward void IG_OnRailjump(int client, float velocity[3]);

/**
 * Called when TF2Instagib has finished loading the map config.
 * You should create new Special Rounds only in this function.
 */
forward void IG_OnMapConfigLoad();

// -------------------------------------------------------------------
/**
 * Forces a special round.
 *
 * @param name          Round name.
 * @param notify        Whether all players should get a chat notification.
 * @param client        If defined, will show that this client has forced the round.
 */
native void IG_ForceSpecialRound(char[] name, bool notify = false, int client = 0);

native void IG_InitializeSpecialRound(any[] round, char[] name, char[] desc = "");
native void IG_SubmitSpecialRound(any[] round);

native int IG_RoundConfig_Num(const char[] round, const char[] key, int defvalue);
native float IG_RoundConfig_Float(const char[] round, const char[] key, float defvalue);
native void IG_RoundConfig_String(const char[] round, const char[] key, char[] buffer, int maxlength, char[] defvalue);

native void IG_GetCurrentRound(any[] buffer);

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

#if !defined REQUIRE_PLUGIN
public __pl_instagib_SetNTVOptional()
{
	MarkNativeAsOptional("IG_ForceSpecialRound");
	
	MarkNativeAsOptional("IG_InitializeSpecialRound");
	MarkNativeAsOptional("IG_SubmitSpecialRound");
	
	MarkNativeAsOptional("IG_RoundConfig_Num");
	MarkNativeAsOptional("IG_RoundConfig_Float");
	MarkNativeAsOptional("IG_RoundConfig_String");
	
	MarkNativeAsOptional("IG_GetCurrentRound");
	
	MarkNativeAsOptional("IG_GetTeamScore");
	MarkNativeAsOptional("IG_SetTeamScore");
	MarkNativeAsOptional("IG_AddToTeamScore");
	
	MarkNativeAsOptional("IG_GetMaxScore");
	MarkNativeAsOptional("IG_SetMaxScore");
	
	MarkNativeAsOptional("IG_GetRoundTime");
	MarkNativeAsOptional("IG_SetRoundTime");
	
	MarkNativeAsOptional("IG_GetClientMultikill");
	
	MarkNativeAsOptional("IG_LimitedLives_GetLives");
	MarkNativeAsOptional("IG_LimitedLives_SetLives");
	
	MarkNativeAsOptional("IG_FreezeTag_Freeze");
	MarkNativeAsOptional("IG_FreezeTag_Unfreeze");
}
#endif