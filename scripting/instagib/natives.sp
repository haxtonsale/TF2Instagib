// -------------------------------------------------------------------
static Handle FwRailjump;

// -------------------------------------------------------------------
void Natives_Init()
{
	CreateNative("IG_ForceSpecialRound", Native_ForceSpecial);
	CreateNative("IG_GetCurrentRound", Native_CurrentRound);
	
	CreateNative("IG_GetTeamScore", Native_GetTeamScore);
	CreateNative("IG_SetTeamScore", Native_SetTeamScore);
	CreateNative("IG_AddToTeamScore", Native_AddTeamScore);
	
	CreateNative("IG_GetMaxScore", Native_GetMaxScore);
	CreateNative("IG_SetMaxScore", Native_SetMaxScore);
	
	CreateNative("IG_GetClientLeaderboardsPlace", Native_GetFFAPlace);
	CreateNative("IG_GetClientFromLeaderboardsPlace", Native_GetFFAClient);
	
	CreateNative("IG_IsFFA", Native_IsFFA);
	
	FwRailjump = CreateGlobalForward("OnClientRailjump", ET_Ignore, Param_Cell, Param_Array);
}

// -------------------------------------------------------------------
void Forward_OnRailjump(int client, float velocity[3])
{
	Call_StartForward(FwRailjump);
	
	Call_PushCell(client);
	Call_PushArray(velocity, sizeof(velocity));
	
	Call_Finish();
}

public int Native_ForceSpecial(Handle plugin, int numParams)
{
	char roundname[256];
	
	GetNativeString(1, roundname, sizeof(roundname));
	
	bool notify = GetNativeCell(2);
	int client = GetNativeCell(3);
	
	return InstagibForceRound(roundname, notify, client);
}

public int Native_CurrentRound(Handle plugin, int numParams)
{
	int size = GetNativeCell(2);
	SetNativeArray(1, g_CurrentRound, size);
	
	return 1;
}

public int Native_GetTeamScore(Handle plugin, int numParams)
{
	TFTeam team = GetNativeCell(1);
	
	if (team < TFTeam_Red) {
		return 0;
	}
	
	return InstagibGetTeamScore(team);
}

public int Native_SetTeamScore(Handle plugin, int numParams)
{
	TFTeam team = GetNativeCell(1);
	int value = GetNativeCell(2);
	
	if (team < TFTeam_Red) {
		return 0;
	}
	
	SetScore(team, value);
	
	return 1;
}

public int Native_AddTeamScore(Handle plugin, int numParams)
{
	TFTeam team = GetNativeCell(1);
	int amount = GetNativeCell(2);
	
	if (team < TFTeam_Red) {
		return 0;
	}
	
	AddScore(team, amount);
	
	return 1;
}

public int Native_GetMaxScore(Handle plugin, int numParams)
{
	return g_MaxScore;
}

public int Native_SetMaxScore(Handle plugin, int numParams)
{
	int value = GetNativeCell(1);
	
	SetMaxScore(value);
	
	return 1;
}

public int Native_GetFFAPlace(Handle plugin, int numParams)
{
	if (!IsFFA()) {
		return -1;
	}
	
	int client = GetNativeCell(1);
	
	return FFA_GetLeaderboardPlace(client);
}

public int Native_GetFFAClient(Handle plugin, int numParams)
{
	if (!IsFFA()) {
		return -1;
	}
	
	int place = GetNativeCell(1);
	
	return FFA_GetLeaderboardPlayer(place);
}

public int Native_IsFFA(Handle plugin, int numParams)
{
	return IsFFA();
}
