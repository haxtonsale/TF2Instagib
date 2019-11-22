// -------------------------------------------------------------------
static ArrayList InstagibRounds;

static bool ForcedNextRound;
static InstagibRound NextRound;

// -------------------------------------------------------------------
void Rounds_Init()
{
	InstagibRounds = new ArrayList(sizeof(InstagibRound));
	
	InstagibRound wait;
	NewInstagibRound(wait, "Waiting For Players");
	wait.MinScore = 322;
	wait.MaxScoreMultiplier = 0.0;
	wait.IsSpecial = false;
	SubmitInstagibRound(wait);
	
	InstagibRound tdm;
	NewInstagibRound(tdm, "Team Deathmatch");
	tdm.IsSpecial = false;
	SubmitInstagibRound(tdm);
	
	g_CurrentRound = tdm;
	
	SR_Explosions_Init();
	SR_OPRailguns_Init();
	SR_TimeAttack_Init();
	SR_Lives_Init();
	SR_FreezeTag_Init();
}

// -------------------------------------------------------------------
void NewInstagibRound(InstagibRound buffer, char[] name, char[] desc = "")
{
	InstagibRound round;
	
	round.UberDuration = g_Config.UberDuration;
	round.RailjumpVelocityXY = g_Config.RailjumpVelXY;
	round.RailjumpVelocityZ = g_Config.RailjumpVelZ;
	round.MinScore = g_Config.MinScore;
	round.MaxScoreMultiplier = g_Config.MaxScoreMulti;
	round.MainWeapon = g_Weapon_Railgun;
	round.MainWeaponClip =  32;
	round.IsAmmoInfinite = true;
	round.RespawnTime = g_Config.RespawnTime;
	round.PointsPerKill = 1;
	round.IsSpecial = true;
	round.ShouldAnnounceWin = true;
	round.ShouldAllowKillbind = true;
	round.ShoudEndWithTimer = true;
	
	round.OnStart = INVALID_FUNCTION;
	round.OnEnd = INVALID_FUNCTION;
	round.OnPlayerSpawn = INVALID_FUNCTION;
	round.OnPostInvApp = INVALID_FUNCTION;
	round.OnPlayerDeath = INVALID_FUNCTION;
	round.OnTraceAttack = INVALID_FUNCTION;
	round.OnDescriptionPrint = INVALID_FUNCTION;
	round.OnEntCreated = INVALID_FUNCTION;
	round.OnPlayerDisconnect = INVALID_FUNCTION;
	round.OnTeamChange = INVALID_FUNCTION;
	round.OnClassChange = INVALID_FUNCTION;
	round.OnDamageTaken = INVALID_FUNCTION;
	
	strcopy(round.Name, sizeof(round.Name), name);
	strcopy(round.Desc, sizeof(round.Desc), desc);
	
	buffer = round;
}

void SubmitInstagibRound(InstagibRound round)
{
	SpecialRoundConfig_GetOverwrites(round);
	
	if (round.IsSpecial && SpecialRoundConfig_Num(round.Name, "Disabled", 0)) {
		return;
	}
	
	char error[256];
	if (CheckInstagibRoundForErrors(round, error)) {
		ThrowError(error);
	}
	
	InstagibRounds.PushArray(round); 
}

static bool CheckInstagibRoundForErrors(InstagibRound round, char error[256])
{
	if (StrEqual(round.Name, "")) {
		error = "Round.Name must not be null.";
	} else if (round.MainWeapon == null) {
		error = "Round.MainWeapon must not be null.";
	} else {
		return false;
	}
	
	return true;
}

void ForceRound(InstagibRound round)
{
	ForcedNextRound = true;
	NextRound = round;
}

void GetDefaultRound(InstagibRound buffer)
{
	if (!ForcedNextRound) {
		if (g_IsWaitingForPlayers) {
			InstagibRounds.GetArray(0, buffer);
		} else {
			InstagibRounds.GetArray(1, buffer);
		}
	} else {
		buffer = NextRound;
		ForcedNextRound = false;
	}
}

void GetRandomSpecialRound(InstagibRound buffer)
{
	if (!ForcedNextRound) {
		static int last_round;
		
		int len = InstagibRounds.Length;
		int playercount = GetActivePlayerCount();
		int count;
		int[] suitable_rounds = new int[len];
		
		for (int i = 2; i < len; i++) {
			InstagibRound round;
			InstagibRounds.GetArray(i, round);
			
			bool enough_players = (playercount >= round.MinPlayers);
			
			if (last_round != i && round.IsSpecial && enough_players) {
				suitable_rounds[count] = i;
				++count;
			}
		}
		
		if (!count) {
			GetDefaultRound(buffer);
		} else {
			int roll = GetRandomInt(0, count-1);
			InstagibRounds.GetArray(suitable_rounds[roll], buffer);
			last_round = suitable_rounds[roll];
		}
	} else {
		buffer = NextRound;
		ForcedNextRound = false;
	}
}

bool GetRound(char[] name, InstagibRound buffer)
{
	int len = InstagibRounds.Length;
	for (int i = 0; i < len; i++) {
		char name2[256];
		InstagibRounds.GetString(i, name2, sizeof(name2));
		
		if (StrEqual(name, name2, false)) {
			InstagibRounds.GetArray(i, buffer);
			return true;
		}
	}
	
	return false;
}

bool InstagibForceRound(char[] name, bool notify = false, int client = 0)
{
	InstagibRound round;
	
	if (!GetRound(name, round)) {
		return false;
	}
	
	if (notify && round.IsSpecial) {
		if (!client) {
			InstagibPrintToChatAll(true, "Special Round {%s} was forced!", name);
		} else {
			InstagibPrintToChatAll(true, "%N has forced the {%s} Special Round!", client, name);
		}
	}
	
	ForceRound(round);
	
	return true;
}

void Rounds_Menu(int client, char[] title, MenuHandler handler, bool display_all = false)
{
	Menu menu = new Menu(handler);
	
	menu.SetTitle(title);
	menu.AddItem("exit", "Exit");
	
	InstagibRound round;
	
	if (display_all) {
		InstagibRounds.GetArray(0, round);
		menu.AddItem(round.Name, round.Name);
	}
	
	int len = InstagibRounds.Length;
	for (int i = 1; i < len; i++) {
		InstagibRounds.GetArray(i, round);
		
		menu.AddItem(round.Name, round.Name);
	}
	
	menu.ExitButton = false;
	menu.Display(client, 60);
}

void Rounds_Reload()
{
	delete InstagibRounds;
	
	InstagibRound round;
	round = g_CurrentRound;
	
	Rounds_Init();
	
	round.UberDuration = g_Config.UberDuration;
	round.RailjumpVelocityXY = g_Config.RailjumpVelXY;
	round.RailjumpVelocityZ = g_Config.RailjumpVelZ;
	round.RespawnTime = g_Config.RespawnTime;
	
	SpecialRoundConfig_GetOverwrites(round);
	
	g_CurrentRound = round;
}