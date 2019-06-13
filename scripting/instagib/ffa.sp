// -------------------------------------------------------------------
static int Leaderboards[MAXPLAYERS+1][2];

// -------------------------------------------------------------------
void FFA_Init()
{
	g_cvar_FF = FindConVar("mp_friendlyfire");
	
	#if defined DEBUG
	g_FFAAllowed = true;
	#endif
}

void FFA_Enable()
{
	if (g_FFAAllowed) {
		g_RoundType = ROUNDTYPE_FFA;
		
		g_cvar_FF.SetInt(1);
		
		#if defined DEBUG
		PrintToServer("Enabled FFA");
		#endif
	}
}

void FFA_Disable()
{
	g_RoundType = ROUNDTYPE_TDM;
	
	g_cvar_FF.SetInt(0);
	
	#if defined DEBUG
	PrintToServer("Disabled FFA");
	#endif
}

bool IsFFA()
{
	return view_as<bool>((g_RoundType & ROUNDTYPE_FFA));
}

void FFA_SortLeaderboards()
{
	SortCustom2D(Leaderboards, sizeof(Leaderboards), Callback_SortLeaderboards);
}

void FFA_Win(int client)
{
	TFTeam team = TF2_GetClientTeam(client);
	ForceWin(team);
	
	TE_AttachParticle(client, "mini_fireworks", PATTACH_POINT_FOLLOW, 1);
	FFA_SpookAllButOne(client);
	
	if (g_CurrentRound.announce_win) {
		AnnounceWin(_, _, client, g_Killcount[client]);
	}
}

void FFA_UpdateLeaderboards()
{
	int topred;
	int topblue;
	
	for (int i = 1; i <= MaxClients; i++) {
		Leaderboards[i-1][0] = 0;
		Leaderboards[i-1][1] = 0;
		
		if (IsClientInGame(i) && IsClientPlaying(i)) {
			Leaderboards[i-1][0] = i;
			Leaderboards[i-1][1] = g_Killcount[i];
			
			TFTeam team = TF2_GetClientTeam(i);
			
			if (team == TFTeam_Red && g_Killcount[i] > topred) {
				SetScore(team, g_Killcount[i]);
				topred = g_Killcount[i];
			} else if (team == TFTeam_Blue && g_Killcount[i] > topblue) {
				SetScore(team, g_Killcount[i]);
				topblue = g_Killcount[i];
			}
			
			if (g_IsRoundActive && g_Killcount[i] >= g_MaxScore) {
				FFA_Win(i);
				
				g_IsRoundActive = false;
				
				return;
			}
		}
	}
	
	if (!topred) {
		SetScore(TFTeam_Red, 0);
	}
	
	if (!topblue) {
		SetScore(TFTeam_Blue, 0);
	}
	
	FFA_SortLeaderboards();
}

int FFA_GetLeaderboardPlace(int client)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (Leaderboards[i-1][0] == client) {
			return i;
		}
	}
	
	return -1;
}

int FFA_GetLeaderboardPlayer(int place)
{
	return Leaderboards[place-1][0];
}

void GetHudColor(int color[4], int place = 0)
{
	switch place do {
		case 1: color = {255, 215, 0, 140};
		case 2: color = {192, 192, 192, 140};
		case 3: color = {205, 127, 50, 140};
		default: {
			color[0] = g_Config.HudText_Color[0];
			color[1] = g_Config.HudText_Color[1];
			color[2] = g_Config.HudText_Color[2];
			color[3] = g_Config.HudText_Color[3];
		}
	}
}

char GetPlaceStr(int place)
{
	char placestr[32];
	
	int placemod = place%10;
	
	if (place > 9 && place < 20) {
		FormatEx(placestr, sizeof(placestr), "%ith", place);
	} else {
		switch placemod do {
			case 1: {
				FormatEx(placestr, sizeof(placestr), "%ist", place);
			}
			case 2: {
				FormatEx(placestr, sizeof(placestr), "%ind", place);
			}
			case 3: {
				FormatEx(placestr, sizeof(placestr), "%ird", place);
			}
			default:
				FormatEx(placestr, sizeof(placestr), "%ith", place);
		}
	}
	
	return placestr;
}

void FFA_SpookAllButOne(int client)
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && IsPlayerAlive(i) && (i != client)) {
			TF2_StunPlayer(i, 30.0, 5.0, TF_STUNFLAG_THIRDPERSON);
		}
	}
}

// -------------------------------------------------------------------
public int Callback_SortLeaderboards(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[1] > elem2[1]) {
		return -1;
	} else if (elem1[1] == elem2[1]) {
		return 0;
	} else {
		return 1;
	}
}