// -------------------------------------------------------------------
#define INSTAGIB_VERSION "1.6.2"

#define TF2_MAXPLAYERS 100
//#define DEBUG
//#define RUN_TESTS
#define GAME_DESCRIPTION "Instagib v" ... INSTAGIB_VERSION

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <lesscolors>
#include <clientprefs>
#include <instagib>

#if defined DEBUG
#include <profiler>
#endif

#if defined RUN_TESTS
#include <smtester>
#endif

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

// -------------------------------------------------------------------
enum
{
	SOLID_NONE		= 0,	// no solid model
	SOLID_BSP		= 1,	// a BSP tree
	SOLID_BBOX		= 2,	// an AABB
	SOLID_OBB		= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW	= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM	= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS	= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
}

enum struct Config
{
	char ChatColor[16];
	char ChatColorHighlight[16];
	
	float HudTextX;
	float HudTextY;
	int HudTextColor[4];
	
	bool EnabledKillstreaks;
	int MinScore;
	float RespawnTime;
	float UberDuration;
	float SpecialRoundChance;
	float MaxScoreMulti;
	bool InstantRespawn;
	float MultikillInterval;
	float RailjumpVelXY;
	float RailjumpVelZ;
	bool AutoBhop;
	bool ManualBhop;
	float BhopMaxSpeed;
	
	bool WebVersionCheck;
	bool WebMapConfigs;
}

enum struct MapConfig
{
	KeyValues kv;
	ArrayList SpawnPoints;
	bool IsMusicDisabled;
}

enum struct Prefs
{
	bool EnabledMusic;
	int ViewmodelAlpha;
	bool AutoBhop;
}

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
Prefs g_ClientPrefs[TF2_MAXPLAYERS+1];

int g_PDLogicEnt;
int g_GamerulesEnt;
int g_LaserModel;

Handle g_Weapon_Railgun;
Handle g_RoundTimer;
ConVar g_CvarAirAccel;
ConVar g_CvarNoRespawnTimes;
ConVar g_CvarSpecFreezeTime;
ConVar g_CvarGitHubToken;

Cookie g_PrefMusic;
Cookie g_PrefViewmodel;
Cookie g_PrefBhop;

Config g_Config;
MapConfig g_MapConfig;

char g_InstagibTag[64];
bool g_SteamWorks;

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
#include "instagib/menus/menu_mapconfig.sp"

#include "instagib/rounds/explosions.sp"
#include "instagib/rounds/oprailguns.sp"
#include "instagib/rounds/timeattack.sp"
#include "instagib/rounds/limitedlives.sp"
#include "instagib/rounds/freezetag.sp"
#include "instagib/rounds/headshots.sp"
#include "instagib/rounds/ricochet.sp"

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
	
	TF2Items_SetAttribute(g_Weapon_Railgun, 0, 397, 1.0);   // Bullets penetrate +1 enemies
	TF2Items_SetAttribute(g_Weapon_Railgun, 1, 303, -1.0);  // no reloads
	TF2Items_SetAttribute(g_Weapon_Railgun, 2, 2, 10.0);    // +900% damage bonus
	TF2Items_SetAttribute(g_Weapon_Railgun, 3, 5, 2.9);     // Slower firing speed
	TF2Items_SetAttribute(g_Weapon_Railgun, 4, 106, 0.1);   // +90% more accurate
	TF2Items_SetAttribute(g_Weapon_Railgun, 5, 51, 1.0);    // Crits on headshot
	TF2Items_SetAttribute(g_Weapon_Railgun, 7, 851, 1.9);   // i am speed
	if (g_Config.EnabledKillstreaks) {
		TF2Items_SetAttribute(g_Weapon_Railgun, 8, 2025, 1.0);  // killstreak
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

char[] InstagibHudPlayerInfo(int client)
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
	
	PrecacheModel("models/props_halloween/ghost_no_hat.mdl");
	PrecacheModel("models/props_halloween/ghost_no_hat_red.mdl");
	PrecacheModel("models/items/ammopack_large.mdl"); // For map config editor
	
	g_LaserModel = PrecacheModel("materials/sprites/laserbeam.vmt");
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
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnStart);
			Call_PushCell(score);
			Call_Finish();
		}
		
		int ent = FindEntityByClassname(-1, "team_round_timer");
		if (ent > -1) {
			AcceptEntityInput(ent, "Pause");
		}
		
		PlayRandomMusic();
		
		InstagibPrintToChatAll(true, "The round has started!");
	}
	
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
	
	ReplaceString(buffer, maxlen, "{", g_Config.ChatColorHighlight);
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

char[] GetMapName()
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
		if (g_CurrentRound.EndWithTimer) {
			InstagibForceRoundEnd();
		} else if (g_CurrentRound.OnEnd != INVALID_FUNCTION) {
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnEnd);
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
	return Plugin_Continue;
}

public Action Timer_WelcomeMessage(Handle timer, int client)
{
	if (IsClientInGame(client)) {
		InstagibPrintToChat(true, client, "Welcome to Instagib v" ... INSTAGIB_VERSION ... "! \nType {/instagib} to open the menu.");
	}
	return Plugin_Continue;
}

public Action Timer_RemoveUber(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TF2_RemoveCondition(i, TFCond_Ubercharged);
		}
	}
	return Plugin_Continue;
}

public Action Hook_TraceAttack(int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	if (attacker > 0 && attacker <= MaxClients) {
		damagetype |= DMG_BLAST; // Gib on kill
		
		if (g_IsRoundActive && g_CurrentRound.OnTraceAttack != INVALID_FUNCTION) {
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnTraceAttack);
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
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnDamageTaken);
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
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_CvarAirAccel = FindConVar("sv_airaccelerate");
	g_CvarNoRespawnTimes = FindConVar("mp_disable_respawn_times");
	g_CvarSpecFreezeTime = FindConVar("spec_freeze_time");
	g_CvarGitHubToken = CreateConVar("instagib_github_auth", "", "Authentication token for GitHub API (https://github.com/settings/tokens)", FCVAR_PROTECTED);
	
	LoadConfig();
	Cookies_Init();
	Commands_Init();
	CreateDefaultRailgun();
	Events_Init();
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
		
		if (LibraryExists("SteamWorks")) {
			g_SteamWorks = true;
		}
		
		InstagibPrintToChatAll(true, "Late Load! Restarting the round...");
		Stalemate();
	}
	
	if (g_SteamWorks) {
		SteamWorks_SetGameDescription(GAME_DESCRIPTION);
		
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
	char mapname[256];
	char displayname[256];
	GetCurrentMap(mapname, sizeof(mapname));
	GetMapDisplayName(mapname, displayname, sizeof(displayname));
	
	LoadMapConfig(displayname);
	RoundLogic_Init();
	Rounds_Init(); // Only create rounds after all configs are loaded
	Forward_OnMapConfigLoad();
	
	InstagibPrecache();
	CheckForInstagibEnts();
	ClearParticleCache();
	StopMusic();
	ResetScore();
	g_IsRoundActive = false;
	
	if (g_SteamWorks) {
		SteamWorks_SetGameDescription(GAME_DESCRIPTION);
	}
	
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
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnEntCreated);
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
	if (StrEqual(weaponname, "tf_weapon_revolver") || StrEqual(weaponname, "tf_weapon_shotgun_building_rescue")) {
		if (!g_IsRoundActive || g_CurrentRound.IsAmmoInfinite && IsValidEntity(weapon)) {
			SetEntProp(weapon, Prop_Data, "m_iClip1", g_CurrentRound.MainWeaponClip+1);
		}

		float vecStart[3];
		float vecDir[3];
		float vecEnd[3];

		GetClientEyePosition(client, vecStart);
		GetClientEyeAngles(client, vecDir);

		Handle trace = TR_TraceRayFilterEx(vecStart, vecDir, MASK_SHOT | CONTENTS_GRATE, RayType_Infinite, Trace_Railjump, client);
		TR_GetEndPosition(vecEnd, trace);
		
		// Railjump
		if (g_CanRailjump && (g_CurrentRound.RailjumpVelocityXY > 0.0 || g_CurrentRound.RailjumpVelocityZ > 0.0)) {
			float vecSub[3];
			float vecLen;
			
			// Maximum length of a ray that would trigger a railjump
			static const float maxLen = 175.0;
			
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
		}

		delete trace;

		if (g_CurrentRound.AllowTraces) {
			vecStart[2] -= 10.0;

			int color[4] = {0, 0, 0, 255};
			if (TF2_GetClientTeam(client) == TFTeam_Red) {
				color[0] = 255;
			} else {
				color[2] = 255;
			}

			for (int i = 0; i < 4; i++) {
				TE_SetupBeamPoints(vecStart, vecEnd, g_LaserModel, 0, 0, 0, 0.5, 0.1, 2.0, 0, 0.1, color, 3);
				TE_SendToAll(i * 0.25);

				color[3] /= 2;
			}
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if (g_IsRoundActive && g_CurrentRound.OnPlayerDisconnect != INVALID_FUNCTION) {
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnPlayerDisconnect);
		Call_PushCell(client);
		Call_Finish();
	}
	
	g_Killcount[client] = 0;
	g_MainWeaponEnt[client] = -1;
}

public void OnPluginEnd()
{
	if (g_SteamWorks) {
		SteamWorks_SetGameDescription("Team Fortress");
	}
	
	GameRules_SetProp("m_nHudType", 0);
	GameRules_SetProp("m_bPlayingRobotDestructionMode", false);
	
	g_CvarAirAccel.RestoreDefault();
	g_CvarNoRespawnTimes.RestoreDefault();
	g_CvarSpecFreezeTime.RestoreDefault();
	
	InstagibPrintToChatAll(true, "The plugin has been unloaded! Restarting the round...");
	Stalemate();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "SteamWorks", false)) {
		g_SteamWorks = true;
		SteamWorks_SetGameDescription(GAME_DESCRIPTION);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "SteamWorks", false)) {
		g_SteamWorks = false;
		SteamWorks_SetGameDescription("Team Fortress");
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int index, Handle &hItem)
{
	static char shouldblock[][] = {
		"tf_weapon_",	// Any Weapons
		"tf_wearable_",	// Wearable Weapons
		"saxxy",		// All-Class Melee Weapons
	};
	
	for (int i = 0; i < sizeof(shouldblock); i++) {
		if (StrContains(classname, shouldblock[i]) != -1) {
			return Plugin_Handled;
		}
	}
	
	if (index == 133 || index == 444 || index == 405 || index == 608) { // Boots
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}

