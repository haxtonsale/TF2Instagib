// -------------------------------------------------------------------
#define INSTAGIB_VERSION "1.0.0"

//#define DEBUG

// -------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <lesscolors>
#include <clientprefs>

#undef REQUIRE_EXTENSIONS
#include <steamtools>

// -------------------------------------------------------------------
#pragma semicolon 1
#pragma newdecls required

#define ROUNDTYPE_TDM (1 << 0)
#define ROUNDTYPE_FFA (1 << 1)

// -------------------------------------------------------------------
enum struct InstagibRound
{
	char name[64];
	char desc[128];
	
	bool is_special;
	bool disable_achievements;
	
	int roundtype_flags;
	int round_time;
	int minscore;
	float maxscore_multi;
	int points_per_kill;
	bool announce_win;
	bool allow_latespawn;
	bool allow_killbind;
	bool end_at_time_end;
	int min_players_tdm;
	int min_players_ffa;
	bool ig_map_only;
	
	float railjump_velXY_multi;
	float railjump_velZ_multi;
	
	float respawn_time;
	float spawnuber_duration;
	
	Handle main_weapon;
	int main_wep_clip;
	bool infinite_ammo;
	
	Round_OnStart on_start;
	Round_OnEnd on_end;
	Round_OnSpawn on_spawn;
	Round_OnPostInvApp on_inv;
	Round_OnDeath on_death;
	Round_OnTraceAttack on_attack;
	Round_OnEntityCreated on_ent_created;
	Round_OnDisconnect on_disconnect;
	Round_CustomDescription on_desc;
	Round_OnTeamChange on_team;
	Round_OnClassChange on_class;
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
	
	int MinPlayersForTDM;
	bool EnabledKillstreaks;
	int MinScore;
	float RespawnTime;
	float UberDuration;
	float SpecialRound_Chance;
}

typeset Round_OnEnd
{
	function void (TFTeam winner_team, int score, int time_left);
	function void (TFTeam winner_team, int score);
	function void (TFTeam winner_team);
}

typedef Round_OnStart = function void ();
typedef Round_OnSpawn = function void (int client, TFTeam team);
typedef Round_OnPostInvApp = function void (int client);
typedef Round_OnTraceAttack = function void (int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup);
typedef Round_CustomDescription = function void (char[] description,  int maxlength);
typedef Round_OnEntityCreated = function void (int ent, const char[] classname);
typedef Round_OnDisconnect = function void (int client);
typedef Round_OnRoundTimeEnd = function void ();
typedef Round_OnDeath = function void (Round_OnDeath_Data data);
typedef Round_OnTeamChange = function void (int client, TFTeam team);
typedef Round_OnClassChange = function void (int client, int class);

static bool IsLateLoad;
static ArrayList CachedSounds;

bool g_IsWaitingForPlayers;
bool g_IsRoundActive;
bool g_CanRailjump;
bool g_MapHasRoundSetup;
bool g_IsMapIG;

int g_RoundType = ROUNDTYPE_TDM;

InstagibRound g_CurrentRound;
int g_MaxScore;
int g_RoundTimeLeft;
char g_RoundTimeLeftFormatted[16];
char g_RoundHudTextFormatted[128];

int g_Killcount[MAXPLAYERS+1];
int g_MainWeaponEnt[MAXPLAYERS+1] = {-1, ...};
bool g_ClientSuicided[MAXPLAYERS+1];

int g_PDLogicEnt;
int g_GamerulesEnt;

Handle g_Weapon_Railgun;
Handle g_RoundTimer;

Config g_Config;
bool g_MusicEnabled = true;
bool g_FFAAllowed;

char g_InstagibTag[64];
ConVar g_cvar_FF;
bool g_SteamTools;

// -------------------------------------------------------------------
#include "instagib/config.sp"
#include "instagib/cookies.sp"
#include "instagib/music.sp"
#include "instagib/particles.sp"
#include "instagib/roundlogic.sp"
#include "instagib/events.sp"
#include "instagib/ffa.sp"
#include "instagib/rounds.sp"
#include "instagib/hud.sp"
#include "instagib/commands.sp"
#include "instagib/natives.sp"
#include "instagib/menu_forceround.sp"
#include "instagib/menu_settings.sp"

#include "instagib/rounds/all_explosions.sp"
#include "instagib/rounds/all_headshots.sp"
#include "instagib/rounds/all_oprailguns.sp"
#include "instagib/rounds/all_timeattack.sp"
#include "instagib/rounds/all_limitedlives.sp"
#include "instagib/rounds/ffa_oneinthechamber.sp"
#include "instagib/rounds/tdm_freezetag.sp"

// -------------------------------------------------------------------
public Plugin myinfo =
{
	name = "TF2Instagib",
	author = "Haxton Sale#3690",
	description = "Best action packed gamemode ever",
	version = INSTAGIB_VERSION,
	url = " "
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
	int ent;
	ent = TF2Items_GiveNamedItem(client, Weapon);
	
	if (is_railgun) {
		SetEntProp(ent, Prop_Data, "m_iClip1", g_CurrentRound.main_wep_clip);
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		
		if (AreClientCookiesCached(client)) {
			SetEntityRenderColor(ent, .a = g_ClientPrefs[client].ViewmodelAlpha);
		}
	}
	
	EquipPlayerWeapon(client, ent);
	
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

void AnnounceWin(TFTeam team = TFTeam_Unassigned, char[] point = "kills", int client = 0, int kills = 0) 
{
	if (client) {
		char clientstr[128];
		FormatEx(clientstr, sizeof(clientstr), "%s %s%N%s", g_InstagibTag, ColorStr(CGetTeamColor(client)), client, g_Config.ChatColor);
		
		if (!StrEqual(point, "")) {
			InstagibPrintToChatAll(true, "%s has won the round with {%i} %s!", clientstr, kills, point);
		} else {
			InstagibPrintToChatAll(true, "%s has won the round!", clientstr);
		}
		
		return;
	} else if (team >= TFTeam_Red) {
		char teamstr[128];
		
		teamstr = (team == TFTeam_Red) ? "\x07FF4040RED Team\x01" : "\x0799CCFFBLU Team\x01";
		
		if (!StrEqual(point, "") && kills > 0) {
			InstagibPrintToChatAll(true, "%s has won the round with {%i} %s!", teamstr, kills, point);
		} else {
			InstagibPrintToChatAll(true, "%s has won the round!", teamstr);
		}
		
		return;
	}
	
	InstagibPrintToChatAll(true, "Stalemate!");
}

void InstagibForceRoundEnd()
{
	if (IsFFA()) {
		FFA_UpdateLeaderboards();
		int winner = FFA_GetLeaderboardPlayer(1);
		
		if (g_Killcount[winner] > 0) {
			FFA_Win(winner);
		} else {
			Stalemate();
			AnnounceWin();
		}
	} else {
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
}

char InstagibHudPlayerInfo(int client)
{
	char str[64];
	
	if (g_Killcount[client]) {
		if (IsFFA()) {
			FormatEx(str, sizeof(str), "Kills: %i (%s Place)", g_Killcount[client], GetPlaceStr(FFA_GetLeaderboardPlace(client)));
		} else {
			FormatEx(str, sizeof(str), "Kills: %i", g_Killcount[client]);
		}
	}
	
	return str;
}

void InstagibRespawn(int client, float time)
{
	if ((g_MapHasRoundSetup || g_IsRoundActive) && g_CurrentRound.allow_latespawn) {
		CreateTimer(time, Timer_Respawn, client);
	}
}

void InstagibPrecacheSound(char[] sound)
{
	if (CachedSounds == null) {
		CachedSounds = new ArrayList(PLATFORM_MAX_PATH);
	} else if (CachedSounds.FindString(sound) != -1) {
		return;
	}
	
	PrecacheSound(sound);
	CachedSounds.PushString(sound);
}

void InstagibPrecache()
{
	if (CachedSounds != null) {
		int len = CachedSounds.Length;
		
		for (int i = 0; i < len; i++) {
			char sound[PLATFORM_MAX_PATH];
			CachedSounds.GetString(i, sound, sizeof(sound));
			
			PrecacheSound(sound);
		}
	}
	
	PrecacheMusic();
}

int InstagibGetTeamScore(TFTeam team)
{
	return (team == TFTeam_Red) ? GetEntProp(g_PDLogicEnt, Prop_Send, "m_nRedTargetPoints") : GetEntProp(g_PDLogicEnt, Prop_Send, "m_nBlueTargetPoints");
}

void InstagibStart()
{
	if (!g_IsWaitingForPlayers) {
		int count = GetActivePlayerCount();
		
		int score = g_CurrentRound.minscore + RoundFloat((count * g_CurrentRound.maxscore_multi));
		
		SetMaxScore(score);
		
		if (g_CurrentRound.round_time) {
			g_RoundTimer = CreateTimer(1.0, Timer_SecondTick, _, TIMER_REPEAT);
		}
		
		if (g_CurrentRound.on_start != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.on_start);
			Call_PushCell(score);
			Call_Finish();
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

void InstagibPrintToChat(bool tag, int client, const char[] format, any ...)
{
	char buffer1[512];
	char buffer2[256];
	
	if (tag) {
		FormatEx(buffer1, sizeof(buffer1), "%s %s", g_InstagibTag, format);
	} else {
		FormatEx(buffer1, sizeof(buffer1), "%s%s", g_Config.ChatColor, format);
	}
	
	ReplaceString(buffer1, sizeof(buffer1), "{", g_Config.ChatColor_Highlight);
	ReplaceString(buffer1, sizeof(buffer1), "}", g_Config.ChatColor);
	
	VFormat(buffer2, sizeof(buffer2), buffer1, 4);
	
	CPrintToChat(client, buffer2);
}

void InstagibPrintToChatAll(bool tag, const char[] format, any ...)
{
	char buffer1[512];
	char buffer2[256];
	
	if (tag) {
		FormatEx(buffer1, sizeof(buffer1), "%s %s", g_InstagibTag, format);
	} else {
		FormatEx(buffer1, sizeof(buffer1), "%s%s", g_Config.ChatColor, format);
	}
	
	ReplaceString(buffer1, sizeof(buffer1), "{", g_Config.ChatColor_Highlight);
	ReplaceString(buffer1, sizeof(buffer1), "}", g_Config.ChatColor);
	
	VFormat(buffer2, sizeof(buffer2), buffer1, 3);
	
	CPrintToChatAll(buffer2);
}

public void Frame_InstagibForceRoundEnd(any data)
{
	InstagibForceRoundEnd();
}

public void Frame_RailjumpParticles(ArrayStack data)
{
	float vecEnd[3];
	data.PopArray(vecEnd);
	int client = data.Pop();
	delete data;
	
	TE_SpawnParticle("Explosion_ShockWave_01", vecEnd);
	TE_AttachParticle(client, "rocketjump_smoke", PATTACH_POINT_FOLLOW, 5, _, TE_ToAllButOne, client);
	TE_AttachParticle(client, "rocketjump_smoke", PATTACH_POINT_FOLLOW, 6, _, TE_ToAllButOne, client);
}

// -------------------------------------------------------------------
public Action Timer_SecondTick(Handle timer)
{
	--g_RoundTimeLeft;
	
	FormatTime(g_RoundTimeLeftFormatted, sizeof(g_RoundTimeLeftFormatted), "%M:%S", g_RoundTimeLeft);
	
	if (g_RoundTimeLeft <= 0) {
		if (g_CurrentRound.end_at_time_end) {
			RequestFrame(Frame_InstagibForceRoundEnd);
		} else if (g_CurrentRound.on_end != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.on_end);
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
		InstagibPrintToChat(true, client, "Welcome to Instagib %s! \nType {/instagib} to open the settings.", INSTAGIB_VERSION);
	}
}

public Action Hook_TraceAttack(int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	if (attacker > 0 && attacker <= MaxClients) {
		damagetype |= DMG_BLAST; // Gib on kill
		
		if (g_IsRoundActive && g_CurrentRound.on_attack != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.on_attack);
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
	// No fall damage
	if (damagetype & DMG_FALL && damage < 100.0) {
		damage = 0.0;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public bool Trace_Railjump(int entity, int contentsMask, any client)
{
	if (entity == client) {
		return false;
	} else {
		return true;
	}
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
	LoadConfig();
	Cookies_Init();
	Commands_Init();
	
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
	
	CreateDefaultRailgun();
	Events_Init();
	FFA_Init();
	Rounds_Init();
	Hud_Init();
}

public void OnMapStart()
{
	RoundLogic_Init();
	InstagibPrecache();
	
	StopMusic();
	ResetScore();
	g_IsRoundActive = false;
	
	if (g_SteamTools) {
		Steam_SetGameDescription("Instagib");
	}
	
	char mapname[256];
	GetCurrentMap(mapname, sizeof(mapname));
	
	if (strncmp(mapname, "ig_", 3) == 0) {
		g_IsMapIG = true;
	}
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (StrEqual(classname, "info_target")) {
		char name[128];
		
		GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
		
		if (StrEqual(name, "instagib_nomusic")) {
			g_MusicEnabled = false;
		} else if (StrEqual(name, "instagib_ffa")) {
			g_FFAAllowed = true;
		}
	} else if (StrEqual(classname, "item_teamflag") || StrEqual(classname, "tf_ammo_pack")) {
		AcceptEntityInput(ent, "Kill");
	}
	
	if (ent > 0 && ent <= MaxClients) {
		SDKHook(ent, SDKHook_OnTakeDamageAlive, Hook_TakeDamage);
		SDKHook(ent, SDKHook_TraceAttack, Hook_TraceAttack);
	}
	
	if (g_IsRoundActive && g_CurrentRound.on_ent_created && g_CurrentRound.on_ent_created != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.on_ent_created);
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
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (StrEqual(weaponname, "tf_weapon_revolver")) {
		if (!g_IsRoundActive || g_CurrentRound.infinite_ammo) {
			SetEntProp(weapon, Prop_Data, "m_iClip1", g_CurrentRound.main_wep_clip+1);
		}
		
		// Railjump
		if (g_CanRailjump && (g_CurrentRound.railjump_velXY_multi > 0.0 || g_CurrentRound.railjump_velZ_multi > 0.0)) {
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
				boost[0] = vecSub[0] * g_CurrentRound.railjump_velXY_multi;
				boost[1] = vecSub[1] * g_CurrentRound.railjump_velXY_multi;
				boost[2] = 100.0  + vecSub[2] * g_CurrentRound.railjump_velZ_multi;
				
				AddVectors(vecVel, boost, vecVel);
				
				ArrayStack data = new ArrayStack(3);
				data.Push(client);
				data.PushArray(vecEnd);
				RequestFrame(Frame_RailjumpParticles, data);
				
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
				
				Forward_OnRailjump(client, vecVel);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (g_IsRoundActive && g_CurrentRound.on_disconnect != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.on_disconnect );
		Call_PushCell(client);
		Call_Finish();
	}
	
	g_Killcount[client] = 0;
	g_ClientSuicided[client] = false;
	g_MainWeaponEnt[client] = -1;
	
	if (IsFFA()) {
		FFA_UpdateLeaderboards();
	}
}

public void OnPluginEnd()
{
	Steam_SetGameDescription("Team Fortress");
	g_cvar_FF.RestoreDefault();
	
	GameRules_SetProp("m_nHudType", 0);
	GameRules_SetProp("m_bPlayingRobotDestructionMode", false);
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