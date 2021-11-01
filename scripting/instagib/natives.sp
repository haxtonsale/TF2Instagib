// -------------------------------------------------------------------
static Handle FwRailjump;
static Handle FwMapConfig;
static Handle FwLifeLost;
static Handle FwAllLivesLost;
static Handle FwFrozen;
static Handle FwUnfrozen;

// -------------------------------------------------------------------
void Natives_Init()
{
	CreateNative("IG_ForceSpecialRound", Native_ForceSpecial);
	
	CreateNative("IG_InitializeSpecialRound", Native_InitRound);
	CreateNative("IG_SubmitSpecialRound", Native_SubmitRound);
	
	CreateNative("IG_RoundConfig_Num", Native_ConfigNum);
	CreateNative("IG_RoundConfig_Float", Native_ConfigFloat);
	CreateNative("IG_RoundConfig_String", Native_ConfigString);
	
	CreateNative("IG_GetCurrentRound", Native_CurrentRound);
	
	CreateNative("IG_GetTeamScore", Native_GetTeamScore);
	CreateNative("IG_SetTeamScore", Native_SetTeamScore);
	CreateNative("IG_AddToTeamScore", Native_AddTeamScore);
	
	CreateNative("IG_GetMaxScore", Native_GetMaxScore);
	CreateNative("IG_SetMaxScore", Native_SetMaxScore);
	
	CreateNative("IG_GetRoundTime", Native_GetRoundTime);
	CreateNative("IG_SetRoundTime", Native_SetRoundTime);
	
	CreateNative("IG_GetClientMultikill", Native_GetMultikill);
	
	CreateNative("IG_LimitedLives_GetLives", Native_GetLives);
	CreateNative("IG_LimitedLives_SetLives", Native_SetLives);
	CreateNative("IG_FreezeTag_Freeze", Native_Freeze);
	CreateNative("IG_FreezeTag_Unfreeze", Native_Unfreeze);
	
	FwRailjump = CreateGlobalForward("IG_OnRailjump", ET_Ignore, Param_Cell, Param_Array);
	FwMapConfig = CreateGlobalForward("IG_OnMapConfigLoad", ET_Ignore);
	FwLifeLost = CreateGlobalForward("IG_LimitedLives_OnLifeLost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	FwAllLivesLost = CreateGlobalForward("IG_LimitedLives_OnAllLivesLost", ET_Ignore, Param_Cell);
	FwFrozen = CreateGlobalForward("IG_FreezeTag_OnClientFrozen", ET_Ignore, Param_Cell, Param_Cell);
	FwUnfrozen = CreateGlobalForward("IG_FreezeTag_OnClientUnfrozen", ET_Ignore, Param_Cell, Param_Cell);
}

// -------------------------------------------------------------------
void Forward_OnRailjump(int client, float velocity[3])
{
	Call_StartForward(FwRailjump);
	
	Call_PushCell(client);
	Call_PushArray(velocity, sizeof(velocity));
	
	Call_Finish();
}

void Forward_OnMapConfigLoad()
{
	Call_StartForward(FwMapConfig);
	
	Call_Finish();
}

void Forward_OnLifeLost(int client, int lives, int attacker)
{
	Call_StartForward(FwLifeLost);
	
	Call_PushCell(client);
	Call_PushCell(lives);
	Call_PushCell(attacker);
	
	Call_Finish();
}

void Forward_AllLivesLost(int client)
{
	Call_StartForward(FwAllLivesLost);
	
	Call_PushCell(client);
	
	Call_Finish();
}

void Forward_Frozen(int client, int attacker)
{
	Call_StartForward(FwFrozen);
	
	Call_PushCell(client);
	Call_PushCell(attacker);
	
	Call_Finish();
}

void Forward_Unfrozen(int client, int attacker)
{
	Call_StartForward(FwUnfrozen);
	
	Call_PushCell(client);
	Call_PushCell(attacker);
	
	Call_Finish();
}
// -------------------------------------------------------------------
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
	SetNativeArray(1, g_CurrentRound, sizeof(InstagibRound));

	return 0;
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
	
	return 0;
}

public int Native_GetRoundTime(Handle plugin, int numParams)
{
	return g_RoundTimeLeft;
}

public int Native_SetRoundTime(Handle plugin, int numParams)
{
	int amount = GetNativeCell(1);
	
	if (amount > 0) {
		g_RoundTimeLeft = amount;
	}
	
	return 0;
}

public int Native_GetMultikill(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	return (IsClientInGame(client)) ? GetClientMultikill(client) : -1;
}

public int Native_GetLives(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return SR_Lives_GetLives(client);
}

public int Native_SetLives(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	SR_Lives_SetLives(client, amount);
	
	return 0;
}

public int Native_Freeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	SR_FreezeTag_Freeze(client, false);
	Forward_Frozen(client, 0);
	
	return 0;
}

public int Native_Unfreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	SR_FreezeTag_Unfreeze(client);
	Forward_Unfrozen(client, 0);
	
	return 0;
}

public int Native_InitRound(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(2, name, sizeof(name));
	
	char desc[128];
	GetNativeString(3, desc, sizeof(desc));
	
	InstagibRound buffer;
	NewInstagibRound(buffer, name, desc, plugin);
	
	SetNativeArray(1, buffer, sizeof(buffer));
	
	return 0;
}

public int Native_SubmitRound(Handle plugin, int numParams)
{
	InstagibRound round;
	GetNativeArray(1, round, sizeof(round));
	
	SubmitInstagibRound(round);
	
	return 0;
}

public int Native_ConfigNum(Handle plugin, int numParams)
{
	char round[64];
	GetNativeString(1, round, sizeof(round));
	
	char key[128];
	GetNativeString(2, key, sizeof(key));
	
	return SpecialRoundConfig_Num(round, key, GetNativeCell(3));
}

public int Native_ConfigFloat(Handle plugin, int numParams)
{
	char round[64];
	GetNativeString(1, round, sizeof(round));
	
	char key[128];
	GetNativeString(2, key, sizeof(key));
	
	return view_as<int>(SpecialRoundConfig_Float(round, key, GetNativeCell(3)));
}

public int Native_ConfigString(Handle plugin, int numParams)
{
	char round[64];
	GetNativeString(1, round, sizeof(round));
	
	char key[128];
	GetNativeString(2, key, sizeof(key));
	
	char defvalue[128];
	GetNativeString(5, defvalue, sizeof(defvalue));
	
	char buffer[128];
	SpecialRoundConfig_String(round, key, buffer, sizeof(buffer), defvalue);
	
	SetNativeString(3, buffer, GetNativeCell(4));
	
	return 0;
}
