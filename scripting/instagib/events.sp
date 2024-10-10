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
	if (!g_IsWaitingForPlayers && GetRandomFloat() <= g_Config.SpecialRoundChance) {
		GetRandomSpecialRound(g_CurrentRound);
	} else {
		GetDefaultRound(g_CurrentRound);
	}

	RefreshRequiredEnts();
	
	delete g_RoundTimer;
	
	g_RoundTimeLeftFormatted = "";

	g_WinnerAnnounced = false;

	if (g_CurrentRound.IsSpecial) {
		InstagibPrintToChatAll(true, "Special Round: {%s}!", g_CurrentRound.Name);
		
		if (!StrEqual(g_CurrentRound.Desc, "")) {
			InstagibPrintToChatAll(false, g_CurrentRound.Desc);
		} else if (g_CurrentRound.OnDescriptionPrint != INVALID_FUNCTION) {
			// Custom description callback (if text needs to be formatted)
			char desc[128];
			
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnDescriptionPrint);
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
			if (!g_CurrentRound.HasClass(TF2_GetPlayerClass(i))) {
				TF2_SetPlayerClass(i, g_CurrentRound.GetRandomClass());
				TF2_RegeneratePlayer(i);
			}
			g_MainWeaponEnt[i] = GiveWeapon(i, g_CurrentRound.MainWeapon);
			
			if (g_CurrentRound.FreeForAll) {
				TF2_ChangeClientTeam(i, g_CurrentRound.FreeForAllTeam)
			}
		}
	}
	
	strcopy(g_RoundHudTextFormatted, sizeof(g_RoundHudTextFormatted), g_CurrentRound.Name);
	
	if (g_CurrentRound.RoundTime) {
		g_RoundTimeLeft = g_CurrentRound.RoundTime;
		
		StrCat(g_RoundHudTextFormatted, sizeof(g_RoundHudTextFormatted), " | Time Left: ");
		FormatTime(g_RoundTimeLeftFormatted, sizeof(g_RoundTimeLeftFormatted), "%M:%S", g_RoundTimeLeft);
	}
	
	if (g_CurrentRound.FreeForAll) {
		g_CvarFriendlyFire.SetInt(1)
	} else {
		g_CvarFriendlyFire.SetInt(0)
	}

	if (g_SteamWorks) {
		SteamWorks_SetGameDescription(GAME_DESCRIPTION);
	}
	
	g_CanRailjump = false;
}

public void Event_OnRoundActive(Event event, const char[] name, bool dont_broadcast)
{
	g_CanRailjump = true;
	
	CreateTimer(g_Config.UberDuration, Timer_RemoveUber, _, TIMER_FLAG_NO_MAPCHANGE);
	
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
	
	// Force player class
	if (!g_CurrentRound.HasClass(class)) {
		TFClassType randomclass = g_CurrentRound.GetRandomClass();

		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", randomclass);
		SetEntProp(client, Prop_Send, "m_iClass", randomclass);
		TF2_RespawnPlayer(client);
		
		if (g_CurrentRound.FreeForAll) {
			TF2_ChangeClientTeam(client, g_CurrentRound.FreeForAllTeam);
		}
	}
	
	InvulnClient(client, g_CurrentRound.UberDuration);

	if (g_IsRoundActive && g_CurrentRound.OnPlayerSpawn != INVALID_FUNCTION) {
		TFTeam team = view_as<TFTeam>(event.GetInt("team"));
		
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnPlayerSpawn);
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
		g_MainWeaponEnt[client] = GiveWeapon(client, g_CurrentRound.MainWeapon);
		
		if (g_IsRoundActive && g_CurrentRound.OnPostInvApp != INVALID_FUNCTION) {
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnPostInvApp);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

public void Event_OnDeath(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	char username[32];
	
	if (!g_Config.InstantRespawn && g_IsRoundActive) {
		CreateTimer(g_CurrentRound.RespawnTime, Timer_Respawn, client);
	}
	
	if (g_IsWaitingForPlayers) {
		return;
	}
	
	if (g_IsRoundActive) {
		if (g_CurrentRound.OnPlayerDeath != INVALID_FUNCTION) {
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
			
			Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnPlayerDeath);
			Call_PushArray(data, sizeof(Round_OnDeath_Data));
			Call_Finish();
		}
		
		if (attacker > 0 && attacker <= MaxClients && client != attacker) {
			g_Killcount[attacker]++;
			AddToClientMultikill(attacker);
			
			if (g_CurrentRound.PointsPerKill) {
				TFTeam team = TF2_GetClientTeam(attacker);
				AddScore(team, g_CurrentRound.PointsPerKill);
			}

			#if defined DEBUG
				PrintToServer("Kills %.i for player %.i", g_Killcount[attacker], attacker);
			#endif

			if (g_CurrentRound.FreeForAll) {
				if (g_Killcount[attacker] > g_MaximumKillcount) {
					g_MaximumKillcount = g_Killcount[attacker];
					SetScore(g_CurrentRound.FreeForAllTeam, g_MaximumKillcount);
				}

				if (g_Killcount[attacker] >= g_MaxScore && !g_WinnerAnnounced) {
					#if defined DEBUG
						PrintToServer("Player %.i is winner %.i", attacker, g_Killcount[attacker]);
					#endif
					g_WinnerAnnounced = true;
					GetClientName(attacker, username, 32);
					ScrambleTeams();
					ForceWin(g_CurrentRound.FreeForAllTeam);
					AnnounceWin(g_CurrentRound.FreeForAllTeam, username, g_Killcount[attacker])
				}
			}
		}
	}
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dont_broadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	int score = InstagibGetTeamScore(team);
	
	if (g_CurrentRound.AnnounceWin && team != TFTeam_Unassigned) {
		AnnounceWin(team, _, score);
	}
	
	if (g_CurrentRound.OnEnd != INVALID_FUNCTION) {
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnEnd);
		Call_PushCell(team);
		Call_PushCell(score);
		Call_PushCell(g_RoundTimeLeft);
		Call_Finish();
	}
	
	StopMusic();
	ResetScore();

	if (g_CurrentRound.FreeForAll) {
		ScrambleTeams();
	} 

	g_IsRoundActive = false;
}

public Action Event_SetupFinish(Event event, const char[] name, bool dont_broadcast)
{
	if (g_MapHasRoundSetup) {
		InstagibStart();
		
		int max = GetMaxEntities();
		for (int i = 1; i <= max; i++) {
			if (IsValidEntity(i)) {
				char classname[255];
				GetEntityClassname(i, classname, sizeof(classname));
				
				if (StrEqual(classname, "team_round_timer")) {
					AcceptEntityInput(i, "Pause");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_OnTeamChange(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (g_IsRoundActive && g_CurrentRound.OnTeamChange != INVALID_FUNCTION) {
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnTeamChange);
		Call_PushCell(client);
		Call_PushCell(team);
		Call_Finish();
	}
	return Plugin_Continue;
}

public Action Event_OnClassChange(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int class = event.GetInt("class");
	
	if (g_IsRoundActive && g_CurrentRound.OnClassChange != INVALID_FUNCTION) {
		Call_StartFunction(g_CurrentRound.OwnerPlugin, g_CurrentRound.OnClassChange);
		Call_PushCell(client);
		Call_PushCell(class);
		Call_Finish();
	}
	return Plugin_Continue;
}