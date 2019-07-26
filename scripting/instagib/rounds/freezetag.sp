// -------------------------------------------------------------------
static bool ShouldBeFrozen[MAXPLAYERS+1] = {true, ...};
static bool IsClientFrozen[MAXPLAYERS+1];
static Handle UnfreezeTimer[MAXPLAYERS+1];
static float UnfreezeAfter;

static float ClientVecOnDeath[MAXPLAYERS+1][3][3];

static bool AnnouncedWin; // To prevent multiple win announcements if the final kill was penetrating

// -------------------------------------------------------------------
void SR_FreezeTag_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Freeze Tag", "Freeze enemies using your Railgun!\nShoot at your allies to free them!");
	sr.round_time = 300;
	sr.minscore = 322; // dynamic
	sr.maxscore_multi = 0.0;
	sr.points_per_kill = 0;
	sr.allow_killbind = false;
	sr.announce_win = false;
	sr.min_players = 6;
	sr.ig_map_only = true;
	
	sr.on_start = SR_FreezeTag_OnStart;
	sr.on_attack = SR_FreezeTag_OnAttack;
	sr.on_spawn = SR_FreezeTag_OnSpawn;
	sr.on_death = SR_FreezeTag_OnDeath;
	sr.on_ent_created = SR_FreezeTag_OnEntCreated;
	sr.on_disconnect = SR_FreezeTag_OnDisconnect;
	sr.on_end = SR_FreezeTag_OnEnd;
	sr.on_team = SR_FreezeTag_OnTeamSwitch;
	sr.on_class = SR_FreezeTag_OnClassSwitch;
	sr.on_inv = SR_FreezeTag_OnLoadout;
	
	UnfreezeAfter = SpecialRoundConfig_Float(sr.name, "FreezeLength", 60.0);
	
	InstagibPrecacheSound("physics/glass/glass_impact_bullet1.wav");
	InstagibPrecacheSound("physics/glass/glass_impact_bullet2.wav");
	InstagibPrecacheSound("physics/glass/glass_impact_bullet3.wav");
	InstagibPrecacheSound("physics/glass/glass_impact_bullet4.wav");
	
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
void SR_FreezeTag_CheckWinConditions()
{
	if (g_IsRoundActive) {
		int red_players;
		int blue_players;
		
		int red_frozen;
		int blue_frozen;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsClientPlaying(i) && IsPlayerAlive(i)) {
				TFTeam team = TF2_GetClientTeam(i);
				if (IsClientFrozen[i]) {
					if (team == TFTeam_Red) {
						++red_frozen;
					} else {
						++blue_frozen;
					}
				}
				
				if (team == TFTeam_Red) {
					++red_players;
				} else {
					++blue_players;
				}
			}
		}
		
		if (red_players > blue_players) {
			SetMaxScore(red_players+1);
		} else {
			SetMaxScore(blue_players+1);
		}
		
		SetScore(TFTeam_Red, blue_frozen);
		SetScore(TFTeam_Blue, red_frozen);
		
		if (!AnnouncedWin) {
			if (red_frozen >= red_players) {
				ForceWin(TFTeam_Blue);
				AnnounceWin(TFTeam_Blue, "");
				
				AnnouncedWin = true;
			} else if (blue_frozen >= blue_players) {
				ForceWin(TFTeam_Red);
				AnnounceWin(TFTeam_Red, "");
				
				AnnouncedWin = true;
			}
		}
	}
}

static void SR_FreezeTag_Effect(int client)
{
	static char sounds[4][PLATFORM_MAX_PATH] = {
		"physics/glass/glass_impact_bullet1.wav",
		"physics/glass/glass_impact_bullet2.wav",
		"physics/glass/glass_impact_bullet3.wav",
		"physics/glass/glass_impact_bullet4.wav"
	};
	
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	
	vecOrigin[2] += 50.0;
	
	TE_SpawnParticle("xms_snowburst", vecOrigin);
	
	EmitSoundToAll(sounds[GetRandomInt(0, sizeof(sounds)-1)], .volume = 0.5);
}

void SR_FreezeTag_Freeze(int client, bool teleport)
{
	if (IsClientInGame(client) && IsClientPlaying(client)) {
		if (teleport) {
			TeleportEntity(client, ClientVecOnDeath[client][0], ClientVecOnDeath[client][1], NULL_VECTOR);
		}
		
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntityRenderColor(client, 80, 80, 255, 125);
		
		SR_FreezeTag_Effect(client);
		
		if ((UnfreezeTimer[client] != null || UnfreezeTimer[client] != INVALID_HANDLE)) {
			delete UnfreezeTimer[client];
		}
		
		UnfreezeTimer[client] = CreateTimer(UnfreezeAfter, SR_FreezeTag_AutoUnfreeze, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	IsClientFrozen[client] = true;
	SR_FreezeTag_CheckWinConditions();
}

void SR_FreezeTag_Unfreeze(int client)
{
	delete UnfreezeTimer[client];
	
	if (IsClientFrozen[client]) {
		if (IsClientInGame(client) && IsClientPlaying(client) && IsPlayerAlive(client)) {
			SetEntityMoveType(client, MOVETYPE_WALK);
			
			if (IsValidEntity(g_MainWeaponEnt[client])) {
				SetEntProp(g_MainWeaponEnt[client], Prop_Data, "m_iClip1", g_CurrentRound.main_wep_clip);
			}
			
			SetEntityRenderColor(client, 255, 255, 255, 255);
			
			SR_FreezeTag_Effect(client);
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ClientVecOnDeath[client][2]);
		}
		
		IsClientFrozen[client] = false;
		SR_FreezeTag_CheckWinConditions();
	}
}
// -------------------------------------------------------------------
public void SR_FreezeTag_Frame_Unfreeze(int client)
{
	SR_FreezeTag_Unfreeze(client);
}

public void SR_FreezeTag_Frame_Respawn(int client)
{
	TF2_RespawnPlayer(client);
}

void SR_FreezeTag_OnStart()
{
	for (int i = 1; i <= MaxClients; i++) {
		ShouldBeFrozen[i] = false;
	}
	
	AnnouncedWin = false;
	SR_FreezeTag_CheckWinConditions();
}

void SR_FreezeTag_OnAttack(int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	TFTeam team1 = TF2_GetClientTeam(victim);
	TFTeam team2 = TF2_GetClientTeam(attacker);
	
	if (team1 == team2) {
		if (IsClientFrozen[victim]) {
			SR_FreezeTag_Unfreeze(victim);
			
			Forward_Unfrozen(victim, attacker);
		}
	} else {
		if (IsClientFrozen[victim]) {
			damage = 0.0;
		} else {
			GetEntPropVector(victim, Prop_Data, "m_vecVelocity", ClientVecOnDeath[victim][2]);
			
			damagetype &= ~DMG_BLAST;
		}
	}
}

void SR_FreezeTag_OnSpawn(int client, TFTeam team)
{
	// Freeze the client if they were not present during the round start
	if (ShouldBeFrozen[client]) {
		SR_FreezeTag_Freeze(client, false);
		ShouldBeFrozen[client] = false;
	} else if (IsClientFrozen[client]) {
		SR_FreezeTag_Freeze(client, true);
	}
}

void SR_FreezeTag_OnLoadout(int client)
{
	if (IsClientFrozen[client] && IsValidEntity(g_MainWeaponEnt[client])) {
		SetEntProp(g_MainWeaponEnt[client], Prop_Data, "m_iClip1", 0);
	}
}
 
void SR_FreezeTag_OnDeath(Round_OnDeath_Data data)
{
	if (data.attacker > 0 && data.attacker <= MaxClients) {
		GetClientAbsOrigin(data.victim, ClientVecOnDeath[data.victim][0]);
		GetClientAbsAngles(data.victim, ClientVecOnDeath[data.victim][1]);
		
		IsClientFrozen[data.victim] = true;
		RequestFrame(SR_FreezeTag_Frame_Respawn, data.victim);
		
		Forward_Frozen(data.victim, data.attacker);
	} else {
		ShouldBeFrozen[data.victim] = true;
		
		Forward_Frozen(data.victim, 0);
	}
 }
 
void SR_FreezeTag_OnEntCreated(int ent, const char[] classname)
{
	if (StrEqual(classname, "tf_ragdoll")) {
		RemoveEntity(ent);
	}
}

public Action SR_FreezeTag_AutoUnfreeze(Handle timer, int client)
{
	if (IsClientInGame(client)) {
		UnfreezeTimer[client] = null;
		RequestFrame(SR_FreezeTag_Frame_Unfreeze, client);
		
		Forward_Unfrozen(client, 0);
	}
}

void SR_FreezeTag_OnDisconnect(int client)
{
	SR_FreezeTag_CheckWinConditions();
	IsClientFrozen[client] = false;
	ShouldBeFrozen[client] = true;
	
	ClientVecOnDeath[client][2][0] = 0.0;
	ClientVecOnDeath[client][2][1] = 0.0;
	ClientVecOnDeath[client][2][2] = 0.0;
}

void SR_FreezeTag_OnEnd(TFTeam winner_team, int score, int time_left)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i)) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
		
		IsClientFrozen[i] = false;
		
		delete UnfreezeTimer[i];
	}
}

void SR_FreezeTag_OnTeamSwitch(int client, TFTeam team)
{
	ShouldBeFrozen[client] = true;
}

void SR_FreezeTag_OnClassSwitch(int client, int class)
{
	ShouldBeFrozen[client] = true;
}