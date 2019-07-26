// -------------------------------------------------------------------
void Events_Init()
{
	HookEvent("player_death", Event_OnDeath);
	HookEvent("player_spawn", Event_OnSpawn);
	HookEvent("post_inventory_application", Event_Inventory);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_active", Event_OnRoundActive, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("teamplay_setup_finished", Event_SetupFinish, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_OnTeamChange);
	HookEvent("player_changeclass", Event_OnClassChange);
}

// -------------------------------------------------------------------
public void Event_OnRoundStart(Event event, const char[] name, bool dont_broadcast)
{
	RefreshRequiredEnts();
	
	delete g_RoundTimer;
	
	g_RoundTimeLeftFormatted = "";
	
	if (!g_IsWaitingForPlayers && GetRandomFloat() <= g_Config.SpecialRound_Chance) {
		GetRandomSpecialRound(g_CurrentRound);
	} else {
		GetDefaultRound(g_CurrentRound);
	}
	
	if (g_CurrentRound.is_special) {
		InstagibPrintToChatAll(true, "Special Round: {%s}!", g_CurrentRound.name);
		
		if (!StrEqual(g_CurrentRound.desc, "")) {
			InstagibPrintToChatAll(false, g_CurrentRound.desc);
		} else if (g_CurrentRound.on_desc != INVALID_FUNCTION) {
			// Custom description callback (if text needs to be formatted)
			char desc[128];
			
			Call_StartFunction(null, g_CurrentRound.on_desc);
			Call_PushStringEx(desc, sizeof(desc), SM_PARAM_COPYBACK, SM_PARAM_COPYBACK);
			Call_PushCell(sizeof(desc));
			Call_Finish();
			
			InstagibPrintToChatAll(false, desc);
		}
	}
	
	// Another loop through players, this time to give em uber and the main round weapon
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i) && IsPlayerAlive(i)) {
			InvulnClient(i, TFCondDuration_Infinite);
			TF2_RemoveAllWeapons(i);
			g_MainWeaponEnt[i] = GiveWeapon(i, g_CurrentRound.main_weapon);
		}
	}
	
	strcopy(g_RoundHudTextFormatted, sizeof(g_RoundHudTextFormatted), g_CurrentRound.name);
	
	if (g_CurrentRound.round_time) {
		g_RoundTimeLeft = g_CurrentRound.round_time;
		
		StrCat(g_RoundHudTextFormatted, sizeof(g_RoundHudTextFormatted), " | Time Left: ");
		FormatTime(g_RoundTimeLeftFormatted, sizeof(g_RoundTimeLeftFormatted), "%M:%S", g_RoundTimeLeft);
	}
	
	if (g_SteamTools) {
		Steam_SetGameDescription("Instagib");
	}
	
	g_CanRailjump = false;
}

public void Event_OnRoundActive(Event event, const char[] name, bool dont_broadcast)
{
	g_CanRailjump = true;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TF2_RemoveCondition(i, TFCond_Ubercharged);
		}
	}
	
	if (!g_MapHasRoundSetup) {
		InstagibStart();
	}
}

public void Event_OnSpawn(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFClassType class = view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_iClass"));
	
	// No outlines on spawn
	TF2_RemoveCondition(client, TFCond_SpawnOutline);
	
	// Force player class to be Soldier
	if (!(class == TFClass_Soldier || class == TFClass_Unknown)) {
		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", TFClass_Soldier);
		SetEntProp(client, Prop_Send, "m_iClass", TFClass_Soldier);
		TF2_RespawnPlayer(client);
		return;
	}
	
	InvulnClient(client, g_CurrentRound.spawnuber_duration);
	
	if (g_IsRoundActive && g_CurrentRound.on_spawn != INVALID_FUNCTION) {
		TFTeam team = view_as<TFTeam>(event.GetInt("team"));
		
		Call_StartFunction(null, g_CurrentRound.on_spawn);
		Call_PushCell(client);
		Call_PushCell(team);
		Call_Finish();
	}
}

public void Event_Inventory(Event event, const char[] name, bool dont_broadcast)
{
	RequestFrame(Frame_Inventory, GetClientOfUserId(event.GetInt("userid")));
}

public void Frame_Inventory(int client)
{
	if (IsClientInGame(client)) {
		g_MainWeaponEnt[client] = GiveWeapon(client, g_CurrentRound.main_weapon);
		
		if (g_IsRoundActive && g_CurrentRound.on_inv != INVALID_FUNCTION) {
			Call_StartFunction(null, g_CurrentRound.on_inv);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

public void Event_OnDeath(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_IsWaitingForPlayers) {
		return;
	}
	
	if (g_IsRoundActive) {
		if (g_CurrentRound.on_death != INVALID_FUNCTION) {
			Round_OnDeath_Data data;
			
			data.victim = client;
			data.attacker = attacker;
			data.customkill = event.GetInt("customkill");
			data.damagetype = event.GetInt("damagebits");
			data.assister = GetClientOfUserId(event.GetInt("assister"));
			data.penetrate_count = event.GetInt("playerpenetratecount");
			data.weaponid = event.GetInt("weaponid");
			data.stun_flags = event.GetInt("stun_flags");
			data.killstreak= event.GetInt("kill_streak_total");
			data.killstreak_victim = event.GetInt("kill_streak_victim");
			data.inflictor_entity = event.GetInt("inflictor_entindex");
			
			Call_StartFunction(null, g_CurrentRound.on_death);
			Call_PushArray(data, sizeof(Round_OnDeath_Data));
			Call_Finish();
		}
		
		if (attacker > 0 && attacker <= MaxClients && client != attacker) {
			g_Killcount[attacker]++;
			AddToClientMultikill(attacker);
			
			if (g_CurrentRound.points_per_kill) {
				TFTeam team = TF2_GetClientTeam(attacker);
				AddScore(team, g_CurrentRound.points_per_kill);
			}
		}
	}
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dont_broadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	int score = InstagibGetTeamScore(team);
	
	if (g_CurrentRound.announce_win && team != TFTeam_Unassigned) {
		AnnounceWin(team, _, score);
	}
	
	if (g_CurrentRound.on_end != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.on_end);
		Call_PushCell(team);
		Call_PushCell(score);
		Call_PushCell(g_RoundTimeLeft);
		Call_Finish();
	}
	
	StopMusic();
	ResetScore();
	g_IsRoundActive = false;
}

public Action Event_SetupFinish(Event event, const char[] name, bool dont_broadcast)
{
	if (g_MapHasRoundSetup) {
		InstagibStart();
	}
}

public Action Event_OnTeamChange(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (g_IsRoundActive && g_CurrentRound.on_team != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.on_team);
		Call_PushCell(client);
		Call_PushCell(team);
		Call_Finish();
	}
}

public Action Event_OnClassChange(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int class = event.GetInt("class");
	
	if (g_IsRoundActive && g_CurrentRound.on_class != INVALID_FUNCTION) {
		Call_StartFunction(null, g_CurrentRound.on_class);
		Call_PushCell(client);
		Call_PushCell(class);
		Call_Finish();
	}
}