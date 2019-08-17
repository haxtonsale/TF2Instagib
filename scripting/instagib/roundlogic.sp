// -------------------------------------------------------------------
void RoundLogic_Init()
{
	RefreshRequiredEnts();
	
	g_MapHasRoundSetup = MapRoundSetupTime() > 0;
}

// -------------------------------------------------------------------
void ResetScore()
{
	for (int i = 1; i <= MaxClients; i++) {
		g_Killcount[i] = 0;
	}
	
	SetScore(TFTeam_Red, 0);
	SetScore(TFTeam_Blue, 0);
}

void RefreshRequiredEnts()
{
	char mapname[256];
	char displayname[256];
	GetCurrentMap(mapname, sizeof(mapname));
	GetMapDisplayName(mapname, displayname, sizeof(displayname));
	
	bool isMapPayload;
	if (!strncmp(displayname, "pl_", 3) || !strncmp(displayname, "plr_", 4)) {
		isMapPayload = true;
	}
	
	if (!g_IsMapIG) {
		int max = GetMaxEntities();
		for (int i = 1; i <= max; i++) {
			if (IsValidEntity(i)) {
				char classname[255];
				GetEntityClassname(i, classname, sizeof(classname));
				
				if (StrEqual(classname, "func_respawnroomvisualizer") || StrEqual(classname, "trigger_capture_area")) {
					AcceptEntityInput(i, "Kill");
				} else if (StrEqual(classname, "func_door")) {
					AcceptEntityInput(i, "Open");
				} else if (StrEqual(classname, "trigger_multiple")) {
					SetEntPropFloat(i, Prop_Data, "m_flWait", -1.0); // Leave all opened doors open. This will fuck up something else that's for sure
				} else if (StrEqual(classname, "team_round_timer")) {
					SetVariantInt(5);
					AcceptEntityInput(i, "SetSetupTime");
				}
			}
		}
	}
	
	g_PDLogicEnt = FindEntityByClassname(-1, "tf_logic_player_destruction");
	g_GamerulesEnt = FindEntityByClassname(-1, "tf_gamerules");
	
	if (g_PDLogicEnt == -1) {
		g_PDLogicEnt = CreateEntityByName("tf_logic_player_destruction");
		SetEntProp(g_PDLogicEnt, Prop_Data, "m_nMinPoints", 10);
		SetEntPropFloat(g_PDLogicEnt, Prop_Data, "m_flFinaleLength", 0.0); // No dumb PD round finale timer
		DispatchSpawn(g_PDLogicEnt);
	}
	
	if (g_GamerulesEnt == -1) {
		g_GamerulesEnt = CreateEntityByName("tf_gamerules");
		DispatchSpawn(g_GamerulesEnt);
	}
	
	GameRules_SetProp("m_nHudType", (isMapPayload) ? 2 : 3);
	GameRules_SetProp("m_bPlayingRobotDestructionMode", true);
}

int MapRoundSetupTime()
{
	int ent = FindEntityByClassname(-1, "team_round_timer");
	
	return (ent != -1) ? GetEntProp(ent, Prop_Data, "m_nSetupTimeLength") : 0;
}

void SetMaxScore(int score)
{
	SetEntProp(g_PDLogicEnt, Prop_Data, "m_nMaxPoints", score);
	
	SetScore(TFTeam_Red, 0);
	SetScore(TFTeam_Blue, 0);
	
	g_MaxScore = score;
}

void AddScore(TFTeam team, int points)
{
	char input[32];
	
	input = (team == TFTeam_Red) ? "ScoreRedPoints" : "ScoreBluePoints";
	
	if (points < 0) {
		int score = InstagibGetTeamScore(team);
		
		SetScore(team, score+points);
	} else {
		SetVariantInt(1);
		while (points) {
			--points;
			AcceptEntityInput(g_PDLogicEnt, input);
		}
	}
}

void SetScore(TFTeam team, int points)
{
	char input[32];
	
	input = (team == TFTeam_Red) ? "m_nRedTargetPoints" : "m_nBlueTargetPoints";
	
	SetEntProp(g_PDLogicEnt, Prop_Send, input, points-1);
	AddScore(team, 1); // Add 1 point for the neat effect
}

void ForceWin(TFTeam team)
{
	int count = GetActivePlayerCount();
	
	if (count) {
		int flags = GetCommandFlags("mp_forcewin");
		SetCommandFlags("mp_forcewin", flags & ~FCVAR_CHEAT ); 
		ServerCommand("mp_forcewin %i", team);
	}
}

void Stalemate()
{
	ForceWin(TFTeam_Unassigned);
}