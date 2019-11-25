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
	char displayname[256];
	displayname = GetMapName();
	
	bool is_map_payload;
	if (!strncmp(displayname, "pl_", 3) || !strncmp(displayname, "plr_", 4)) {
		is_map_payload = true;
	}
	
	int max = GetMaxEntities();
	for (int i = 1; i <= max; i++) {
		if (IsValidEntity(i)) {
			static char delet_this[][] = {
				"item_ammopack_full",
				"item_ammopack_medium",
				"item_ammopack_small",
				"item_healthkit_full",
				"item_healthkit_medium",
				"item_healthkit_small",
				"func_respawnroomvisualizer",
			};
			
			char classname[255];
			GetEntityClassname(i, classname, sizeof(classname));
			
			for (int j = 0; j < sizeof(delet_this); j++) {
				if (StrEqual(classname, delet_this[j])) {
					AcceptEntityInput(i, "Kill");
				}
			}
			
			if (StrEqual(classname, "func_regenerate")) { // Delet resupply lockers
				int model_index = GetEntPropEnt(i, Prop_Data, "m_hAssociatedModel");
				if (model_index > MaxClients && IsValidEntity(model_index))
					AcceptEntityInput(model_index, "Kill");
				
				AcceptEntityInput(i, "Kill");
			} else if (StrEqual(classname, "func_door")) { // Kill all doors
				char name[128];
				GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
				
				// Hardcode for koth_nucleus
				if (StrEqual(displayname, "koth_nucleus") && (StrEqual(name, "door_bridge") || StrEqual(name, "door_top") || StrEqual(name, "door_bottom") || StrEqual(name, "door_armleft") || StrEqual(name, "door_armright"))) {
					AcceptEntityInput(i, "Open");
				} else {
					AcceptEntityInput(i, "Open");
					AcceptEntityInput(i, "Kill");
				}
			} else if (StrEqual(classname, "trigger_capture_area")) { // Make it impossible to capture points
				SetVariantString("2 0");
				AcceptEntityInput(i, "SetTeamCanCap");
				SetVariantString("3 0");
				AcceptEntityInput(i, "SetTeamCanCap");
			} else if (MapRoundSetupTime() && StrEqual(classname, "team_round_timer")) { // Set setup time to 5 seconds
				SetVariantInt(5);
				AcceptEntityInput(i, "SetSetupTime");
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
	
	GameRules_SetProp("m_nHudType", (is_map_payload) ? 2 : 3);
	GameRules_SetProp("m_bPlayingRobotDestructionMode", true);
	
	SetupSpawnPoints();
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