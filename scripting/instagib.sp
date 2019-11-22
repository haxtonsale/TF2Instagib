// -------------------------------------------------------------------
#define INSTAGIB_VERSION "1.6.0"

#define TF2_MAXPLAYERS 32
//#define DEBUG
//#define RUN_TESTS
#define GAME_DESCRIPTION "TF2Instagib v" ... INSTAGIB_VERSION

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <lesscolors>
#include <clientprefs>

#if defined DEBUG
#include <profiler>
#endif

#if defined RUN_TESTS
#include <smtester>
#endif

#undef REQUIRE_EXTENSIONS
#include <steamtools>

#pragma semicolon 1
#pragma newdecls required

// -------------------------------------------------------------------
enum struct InstagibRound
{
	char Name[64];
	char Desc[128];
	
	bool IsSpecial;
	
	int RoundTime;
	int MinScore;
	float MaxScoreMultiplier;
	int PointsPerKill;
	bool ShouldAnnounceWin;
	bool ShouldAllowKillbind;
	bool ShoudEndWithTimer;       // Whether the round will be forcefully ended when the round time is over
	int MinPlayers;
	
	float RailjumpVelocityXY;
	float RailjumpVelocityZ;
	
	float RespawnTime;
	float UberDuration;
	
	Handle MainWeapon;
	int MainWeaponClip;
	bool IsAmmoInfinite;
	
	Round_OnStart OnStart;
	Round_OnEnd OnEnd;
	Round_OnSpawn OnPlayerSpawn;
	Round_OnPostInvApp OnPostInvApp;
	Round_OnDeath OnPlayerDeath;
	Round_OnTraceAttack OnTraceAttack;
	Round_OnEntityCreated OnEntCreated;
	Round_OnDisconnect OnPlayerDisconnect;
	Round_OnTeamChange OnTeamChange;
	Round_OnClassChange OnClassChange;
	Round_OnTakeDamage OnDamageTaken;
	Round_CustomDescription OnDescriptionPrint;
}

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

enum struct Config
{
	char ChatColor[16];
	char ChatColor_Highlight[16];
	
	float HudText_x;
	float HudText_y;
	int HudText_Color[4];
	
	bool EnabledKillstreaks;
	int MinScore;
	float RespawnTime;
	float UberDuration;
	float SpecialRound_Chance;
	float MaxScoreMulti;
	float RailjumpVelXY;
	float RailjumpVelZ;
	
	bool EnabledBhop;
	float BhopMaxSpeed;
	
	int MultikillInterval;
	
	bool InstantRespawn;
	
	bool WebVersionCheck;
	bool WebMapConfigs;
}

typedef Round_OnStart =           function void ();
typedef Round_OnEnd =             function void (TFTeam winner_team, int score, int time_left);
typedef Round_OnSpawn =           function void (int client, TFTeam team);
typedef Round_OnPostInvApp =      function void (int client);
typedef Round_OnTraceAttack =     function void (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup);
typedef Round_CustomDescription = function void (char[] description,  int maxlength);
typedef Round_OnEntityCreated =   function void (int ent, const char[] classname);
typedef Round_OnDisconnect =      function void (int client);
typedef Round_OnRoundTimeEnd =    function void ();
typedef Round_OnDeath =           function void (Round_OnDeath_Data data);
typedef Round_OnTeamChange =      function void (int client, TFTeam team);
typedef Round_OnClassChange =     function void (int client, int class);
typedef Round_OnTakeDamage =      function Action (int victim, int &attacker, int &inflictor, float &damage, int &damagetype);

static bool IsLateLoad;
static ArrayList CachedSounds;

bool g_IsWaitingForPlayers;
bool g_IsRoundActive;
bool g_CanRailjump;
bool g_MapHasRoundSetup;

InstagibRound g_CurrentRound;
int g_MaxScore;
int g_RoundTimeLeft;
char g_RoundTimeLeftFormatted[16];
char g_RoundHudTextFormatted[128];

int g_Killcount[TF2_MAXPLAYERS+1];
int g_MainWeaponEnt[TF2_MAXPLAYERS+1] = {-1, ...};

int g_PDLogicEnt;
int g_GamerulesEnt;

Handle g_Weapon_Railgun;
Handle g_RoundTimer;
ConVar g_CvarAirAccel;
ConVar g_CvarNoRespawnTimes;
ConVar g_CvarSpecFreezeTime;

Config g_Config;

char g_InstagibTag[64];
bool g_SteamTools;

// -------------------------------------------------------------------
#include "instagib/config.sp"
#include "instagib/cookies.sp"
#include "instagib/particles.sp"
#include "instagib/roundlogic.sp"
#include "instagib/events.sp"
#include "instagib/rounds.sp"
#include "instagib/hud.sp"
#include "instagib/commands.sp"
#include "instagib/natives.sp"
#include "instagib/bhop.sp"
#include "instagib/multikill.sp"
#include "instagib/mapconfig.sp"
#include "instagib/music.sp"
#include "instagib/web.sp"
#include "instagib/tests.sp"
#include "instagib/menus/menu_forceround.sp"
#include "instagib/menus/menu_settings.sp"
#include "instagib/menus/menu_main.sp"

#include "instagib/rounds/explosions.sp"
#include "instagib/rounds/oprailguns.sp"
#include "instagib/rounds/timeattack.sp"
#include "instagib/rounds/limitedlives.sp"
#include "instagib/rounds/freezetag.sp"

// -------------------------------------------------------------------
public Plugin myinfo =
{
	name = "TF2Instagib",
	author = "Haxton Sale",
	description = "Best action packed gamemode ever",
	version = INSTAGIB_VERSION,
	url = "https://github.com/haxtonsale/TF2Instagib"
};

// -------------------------------------------------------------------
void CreateDefaultRailgun()
{
	delete g_Weapon_Railgun;
	
	g_Weapon_Railgun = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	
	TF2Items_SetClassname(g_Weapon_Railgun, "tf_weapon_revolver");
	TF2Items_SetItemIndex(g_Weapon_Railgun, 527);
	TF2Items_SetLevel(g_Weapon_Railgun, 1);
	TF2Items_SetQuality(g_Weapon_Railgun, 4);
	TF2Items_SetNumAttributes(g_Weapon_Railgun, 9);
	
	TF2Items_SetAttribute(g_Weapon_Railgun, 0, 397, 1.0);	// Bullets penetrate +1 enemies
	TF2Items_SetAttribute(g_Weapon_Railgun, 1, 303, -1.0);	// no reloads
	TF2Items_SetAttribute(g_Weapon_Railgun, 2, 2, 10.0);	// +900% damage bonus
	TF2Items_SetAttribute(g_Weapon_Railgun, 3, 5, 2.9);		// Slower firing speed
	TF2Items_SetAttribute(g_Weapon_Railgun, 4, 106, 0.1);	// +90% more accurate
	TF2Items_SetAttribute(g_Weapon_Railgun, 5, 51, 1.0);	// Crits on headshot
	TF2Items_SetAttribute(g_Weapon_Railgun, 6, 305, -1.0);	// Fires tracer rounds
	TF2Items_SetAttribute(g_Weapon_Railgun, 7, 851, 1.9);	// i am speed
	if (g_Config.EnabledKillstreaks) {
		TF2Items_SetAttribute(g_Weapon_Railgun, 8, 2025, 1.0);	// killstreak
	}
}

int GiveWeapon(int client, Handle Weapon, bool is_railgun = true)
{
	int ent = TF2Items_GiveNamedItem(client, Weapon);
	
	if (IsValidEntity(ent)) {
		if (is_railgun) {
			SetEntProp(ent, Prop_Data, "m_iClip1", g_CurrentRound.MainWeaponClip);
			SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
			
			if (AreClientCookiesCached(client)) {
				SetEntityRenderColor(ent, .a = g_ClientPrefs[client].ViewmodelAlpha);
			}
		}
		
		if (IsClientInGame(client) && IsClientPlaying(client) && IsPlayerAlive(client)) {
			EquipPlayerWeapon(client, ent);
		}
	}
	
	return ent;
}

void InvulnClient(int client, float duration)
{
	if (IsClientInGame(client)) {
		TF2_AddCondition(client, TFCond_Ubercharged, duration);
	}
}

bool IsClientPlaying(int client)
{
	return (TF2_GetClientTeam(client) >= TFTeam_Red);
}

void AnnounceWin(TFTeam team = TFTeam_Unassigned, char[] point = "kills", int points = 0) 
{
	char str[128];
	
	if (team >= TFTeam_Red) {
		str = (team == TFTeam_Red) ? "\x07FF4040RED Team\x01" : "\x0799CCFFBLU Team\x01";
	} else {
		InstagibPrintToChatAll(true, "Stalemate!");
		return;
	}
	
	if (!StrEqual(point, "") && points > 0) {
		InstagibPrintToChatAll(true, "%s has won the round with {%i} %s!", str, points, point);
	} else {
		InstagibPrintToChatAll(true, "%s has won the round!", str);
	}
}

void InstagibForceRoundEnd()
{
	int red = GetEntProp(g_PDLogicEnt, Prop_Send, "m_nRedTargetPoints");
	int blue = GetEntProp(g_PDLogicEnt, Prop_Send, "m_nBlueTargetPoints");
	
	if (red > blue) {
		ForceWin(TFTeam_Red);
	} else if (blue > red) {
		ForceWin(TFTeam_Blue);
	} else {
		Stalemate();
		AnnounceWin();
	}
}

char InstagibHudPlayerInfo(int client)
{
	char str[64];
	
	if (g_Killcount[client]) {
		FormatEx(str, sizeof(str), "Kills: %i", g_Killcount[client]);
	}
	
	return str;
}

/*
 * Precaches a sound and adds it to the CachedSounds array
 * All sounds in the CachedSounds array will be precached on every map start
 * (useful if instagib is played for more than one map)
 */
void InstagibPrecacheSound(const char[] sound)
{
	if (CachedSounds == null) {
		CachedSounds = new ArrayList(PLATFORM_MAX_PATH);
	} else if (CachedSounds.FindString(sound) != -1) {
		return;
	}
	
	PrecacheSound(sound);
	CachedSounds.PushString(sound);
	
	char sound_copy[PLATFORM_MAX_PATH];
	strcopy(sound_copy, sizeof(sound_copy), sound);
	
	FormatEx(sound_copy, sizeof(sound_copy), "sound/%s", sound);
	AddFileToDownloadsTable(sound_copy);
}

void InstagibPrecache()
{
	if (CachedSounds != null) {
		int len = CachedSounds.Length;
		
		for (int i = 0; i < len; i++) {
			char sound[PLATFORM_MAX_PATH];
			CachedSounds.GetString(i, sound, sizeof(sound));
			
			PrecacheSound(sound);
			
			Format(sound, sizeof(sound), "sound/%s", sound);
			AddFileToDownloadsTable(sound);
		}
	}
}

int InstagibGetTeamScore(TFTeam team)
{
	return (team == TFTeam_Red) ? GetEntProp(g_PDLogicEnt, Prop_Send, "m_nRedTargetPoints") : GetEntProp(g_PDLogicEnt, Prop_Send, "m_nBlueTargetPoints");
}

void InstagibStart()
{
	if (!g_IsWaitingForPlayers) {
		int count = GetActivePlayerCount();
		
		int score = g_CurrentRound.MinScore + RoundFloat(float(count) * g_CurrentRound.MaxScoreMultiplier);
		
		SetMaxScore(score);
		
		if (g_CurrentRound.RoundTime) {
			g_RoundTimer = CreateTimer(1.0, Timer_SecondTick, _, TIMER_REPEAT);
		}
		
		if (g_CurrentRound.OnStart != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.OnStart);
			Call_PushCell(score);
			Call_Finish();
		}
		
		PlayRandomMusic();
		
		InstagibPrintToChatAll(true, "The round has started!");
	}
	
	CreateTimer(g_Config.UberDuration, Timer_RemoveUber, _, TIMER_FLAG_NO_MAPCHANGE);
	g_IsRoundActive = true;
}

int GetActivePlayerCount()
{
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i)) {
			++count;
		}
	}
	
	return count;
}

/*
 * Applies default color to text, Highlights text surrounded by brackets, 
 * adds an [Instagib] tag before the message if the tag param is true.
 */
void InstagibProcessString(bool tag, const char[] format, char[] buffer, int maxlen)
{
	if (tag) {
		FormatEx(buffer, maxlen, "%s %s", g_InstagibTag, format);
	} else {
		FormatEx(buffer, maxlen, "%s%s", g_Config.ChatColor, format);
	}
	
	ReplaceString(buffer, maxlen, "{", g_Config.ChatColor_Highlight);
	ReplaceString(buffer, maxlen, "}", g_Config.ChatColor);
}

void InstagibPrintToChat(bool tag, int client, const char[] format, any ...)
{
	char buffer1[512];
	char buffer2[256];
	
	InstagibProcessString(tag, format, buffer1, sizeof(buffer1));
	
	VFormat(buffer2, sizeof(buffer2), buffer1, 4);
	
	CPrintToChat(client, buffer2);
}

void InstagibPrintToChatAll(bool tag, const char[] format, any ...)
{
	char buffer1[512];
	char buffer2[256];
	
	InstagibProcessString(tag, format, buffer1, sizeof(buffer1));
	
	VFormat(buffer2, sizeof(buffer2), buffer1, 3);
	
	CPrintToChatAll(buffer2);
}

void CheckForInstagibEnts()
{
	int ent = FindEntityByClassname(-1, "info_target");
	
	while (ent != -1) {
		char name[128];
		GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
		
		if (StrEqual(name, "instagib_nomusic")) {
			g_MapConfig.IsMusicDisabled = true;
		}
		
		ent = FindEntityByClassname(ent+1, "info_target");
	}
}

char GetMapName()
{
	char mapname[256];
	char displayname[256];
	GetCurrentMap(mapname, sizeof(mapname));
	GetMapDisplayName(mapname, displayname, sizeof(displayname));
	
	return displayname;
}

public void Frame_RailjumpParticles(ArrayStack data)
{
	float vecEnd[3];
	data.PopArray(vecEnd);
	int client = data.Pop();
	delete data;
	
	TE_SpawnParticle("Explosion_ShockWave_01", vecEnd);
	TE_AttachParticle(client, "rocketjump_smoke", PATTACH_POINT_FOLLOW, 5, _, TE_ToAllButOne, client); // Left foot smoke
	TE_AttachParticle(client, "rocketjump_smoke", PATTACH_POINT_FOLLOW, 6, _, TE_ToAllButOne, client); // Right foot smoke
}

// -------------------------------------------------------------------
public Action Timer_SecondTick(Handle timer)
{
	--g_RoundTimeLeft;
	
	FormatTime(g_RoundTimeLeftFormatted, sizeof(g_RoundTimeLeftFormatted), "%M:%S", g_RoundTimeLeft);
	
	if (g_RoundTimeLeft <= 0) {
		if (g_CurrentRound.ShoudEndWithTimer) {
			InstagibForceRoundEnd();
		} else if (g_CurrentRound.OnEnd != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.OnEnd);
			Call_PushCell(TFTeam_Unassigned);
			Call_PushCell(-1);
			Call_PushCell(g_RoundTimeLeft);
			Call_Finish();
		}
		
		g_RoundTimer = null;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action Timer_Respawn(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsPlayerAlive(client)) {
		TF2_RespawnPlayer(client);
	}
}

public Action Timer_WelcomeMessage(Handle timer, int client)
{
	if (IsClientInGame(client)) {
		InstagibPrintToChat(true, client, "Welcome to TF2Instagib v%s! \nType {/instagib} to open the menu.", INSTAGIB_VERSION);
	}
}

public Action Timer_RemoveUber(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TF2_RemoveCondition(i, TFCond_Ubercharged);
		}
	}
}

public Action Hook_TraceAttack(int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	if (attacker > 0 && attacker <= MaxClients) {
		damagetype |= DMG_BLAST; // Gib on kill
		
		if (g_IsRoundActive && g_CurrentRound.OnTraceAttack != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.OnTraceAttack);
			Call_PushCell(victim);
			Call_PushCellRef(attacker);
			Call_PushCellRef(inflictor);
			Call_PushFloatRef(damage);
			Call_PushCellRef(damagetype);
			Call_PushCellRef(ammotype);
			Call_PushCell(hitbox);
			Call_PushCell(hitgroup);
			Call_Finish();
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Hook_TakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	Action action;
	
	if (g_IsRoundActive && g_CurrentRound.OnDamageTaken != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.OnDamageTaken);
		Call_PushCell(victim);
		Call_PushCellRef(attacker);
		Call_PushCellRef(inflictor);
		Call_PushFloatRef(damage);
		Call_PushCellRef(damagetype);
		Call_Finish(action);
	}
	
	if (damagetype & DMG_FALL && damage < 200.0) {
		damage = 0.0;
		
		action = Plugin_Changed;
	}
	
	return action;
}

public bool Trace_Railjump(int entity, int contentsMask, any client)
{
	return entity != client;
}

// -------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	IsLateLoad = late;
	Natives_Init();
	RegPluginLibrary("instagib");
	MarkNativeAsOptional("Steam_SetGameDescription");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateTimer(1.0, Timer_MultikillTick, _, TIMER_REPEAT);
	g_CvarAirAccel = FindConVar("sv_airaccelerate");
	g_CvarNoRespawnTimes = FindConVar("mp_disable_respawn_times");
	g_CvarSpecFreezeTime = FindConVar("spec_freeze_time");
	
	LoadConfig();
	Cookies_Init();
	Commands_Init();
	CreateDefaultRailgun();
	Events_Init();
	Rounds_Init();
	Hud_Init();
	
	if (IsLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientConnected(i)) {
				GetClientCookies(i);
			}
			
			if (IsClientInGame(i)) {
				SDKHook(i, SDKHook_OnTakeDamageAlive, Hook_TakeDamage);
				SDKHook(i, SDKHook_TraceAttack, Hook_TraceAttack);
			}
		}
		
		if (LibraryExists("SteamTools")) {
			g_SteamTools = true;
		}
		
		InstagibPrintToChatAll(true, "Late Load! Restarting the round...");
		Stalemate();
	}
	
	if (g_SteamTools) {
		if (g_Config.WebVersionCheck) {
			Web_GetLatestInstagibVersion();
		}
		
		if (g_Config.WebMapConfigs) {
			Web_GetMapConfigs();
		}
	}
}

public void OnMapStart()
{
	RoundLogic_Init();
	InstagibPrecache();
	PrecacheModel("models/props_halloween/ghost_no_hat.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat_red.mdl");
	PrecacheModel("models/items/ammopack_large.mdl"); // For map config editor
	
	StopMusic();
	ResetScore();
	g_IsRoundActive = false;
	
	if (g_SteamTools) {
		Steam_SetGameDescription("Instagib");
	}
	
	char mapname[256];
	char displayname[256];
	GetCurrentMap(mapname, sizeof(mapname));
	GetMapDisplayName(mapname, displayname, sizeof(displayname));
	
	CheckForInstagibEnts();
	LoadMapConfig(displayname);
	ClearParticleCache();
	
	#if defined RUN_TESTS
	Instagib_StartTests();
	#endif
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (StrEqual(classname, "item_teamflag")) {
		AcceptEntityInput(ent, "Kill");
	}
	
	if (ent > 0 && ent <= MaxClients) {
		SDKHook(ent, SDKHook_OnTakeDamageAlive, Hook_TakeDamage);
		SDKHook(ent, SDKHook_TraceAttack, Hook_TraceAttack);
	}
	
	if (g_IsRoundActive && g_CurrentRound.OnEntCreated != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.OnEntCreated);
		Call_PushCell(ent);
		Call_PushString(classname);
		Call_Finish();
	}
}

public void OnEntityDestroyed(int ent)
{
	if (ent > 0 && ent <= MaxClients) {
		SDKUnhook(ent, SDKHook_OnTakeDamageAlive, Hook_TakeDamage);
		SDKUnhook(ent, SDKHook_TraceAttack, Hook_TraceAttack);
	}
}

public void OnClientPutInServer(int client)
{
	PlayMusicToLateClient(client);
	
	CreateTimer(5.0, Timer_WelcomeMessage, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void TF2_OnWaitingForPlayersStart()
{
	g_IsWaitingForPlayers = true;
	g_RoundTimeLeft = 0;
	
	delete g_RoundTimer;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_IsWaitingForPlayers = false;
	g_IsRoundActive = false; // Limited lives fix
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (StrEqual(weaponname, "tf_weapon_revolver")) {
		if (!g_IsRoundActive || g_CurrentRound.IsAmmoInfinite && IsValidEntity(weapon)) {
			SetEntProp(weapon, Prop_Data, "m_iClip1", g_CurrentRound.MainWeaponClip+1);
		}
		
		// Railjump
		if (g_CanRailjump && (g_CurrentRound.RailjumpVelocityXY > 0.0 || g_CurrentRound.RailjumpVelocityZ > 0.0)) {
			float vecStart[3];
			float vecDir[3];
			float vecEnd[3];
			float vecSub[3];
			float vecLen;
			
			// Maximum length of a ray that would trigger a railjump
			static const float maxLen = 175.0;
			
			GetClientEyePosition(client, vecStart);
			GetClientEyeAngles(client, vecDir);
			
			Handle trace = TR_TraceRayFilterEx(vecStart, vecDir, MASK_SHOT | CONTENTS_GRATE, RayType_Infinite, Trace_Railjump, client);
			TR_GetEndPosition(vecEnd, trace);
			
			SubtractVectors(vecStart, vecEnd, vecSub);
			vecLen = GetVectorLength(vecSub);
			
			if (vecDir[0] > 20.0 && vecLen < maxLen) {
				float vecVel[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
				
				float boost[3];
				boost[0] = vecSub[0] * g_CurrentRound.RailjumpVelocityXY;
				boost[1] = vecSub[1] * g_CurrentRound.RailjumpVelocityXY;
				boost[2] = 100.0  + vecSub[2] * g_CurrentRound.RailjumpVelocityZ;
				
				AddVectors(vecVel, boost, vecVel);
				
				ArrayStack data = new ArrayStack(3);
				data.Push(client);
				data.PushArray(vecEnd);
				RequestFrame(Frame_RailjumpParticles, data);
				
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
				
				Forward_OnRailjump(client, vecVel);
			}
			
			delete trace;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (g_IsRoundActive && g_CurrentRound.OnPlayerDisconnect != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.OnPlayerDisconnect);
		Call_PushCell(client);
		Call_Finish();
	}
	
	g_Killcount[client] = 0;
	g_MainWeaponEnt[client] = -1;
}

public void OnPluginEnd()
{
	Steam_SetGameDescription(GAME_DESCRIPTION);
	
	GameRules_SetProp("m_nHudType", 0);
	GameRules_SetProp("m_bPlayingRobotDestructionMode", false);
	
	g_CvarAirAccel.RestoreDefault();
	g_CvarNoRespawnTimes.RestoreDefault();
	g_CvarSpecFreezeTime.RestoreDefault();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "SteamTools", false)) {
		g_SteamTools = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "SteamTools", false)) {
		g_SteamTools = false;
		Steam_SetGameDescription("Team Fortress");
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int index, Handle &hItem)
{
	static char shouldblock[][] = {
		"tf_weapon_rocketlauncher",
		"tf_weapon_rocketlauncher_directhit",
		"tf_weapon_particle_cannon",
		"tf_weapon_rocketlauncher_airstrike",
		"tf_weapon_shotgun_soldier",
		"tf_weapon_shotgun",
		"tf_weapon_buff_item",
		"tf_weapon_raygun",
		"tf_weapon_parachute",
		"tf_weapon_shovel",
		"saxxy",
		"tf_weapon_katana"
	};
	
	for (int i = 0; i < sizeof(shouldblock); i++) {
		if (StrEqual(classname, shouldblock[i])) {
			return Plugin_Handled;
		}
	}
	
	if (index == 133 || index == 444) { // Boots
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}