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
	wait.minscore = 322;
	wait.maxscore_multi = 0.0;
	wait.is_special = false;
	SubmitInstagibRound(wait);
	
	InstagibRound tdm;
	NewInstagibRound(tdm, "Team Deathmatch");
	tdm.is_special = false;
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
	
	round.spawnuber_duration =   g_Config.UberDuration;
	round.railjump_velXY_multi = g_Config.RailjumpVelXY;
	round.railjump_velZ_multi =  g_Config.RailjumpVelZ;
	round.minscore =             g_Config.MinScore;
	round.maxscore_multi =       g_Config.MaxScoreMulti;
	round.main_weapon =          g_Weapon_Railgun;
	round.main_wep_clip =        32;
	round.infinite_ammo =        true;
	round.respawn_time =         g_Config.RespawnTime;
	round.points_per_kill =      1;
	round.is_special =           true;
	round.announce_win =         true;
	round.allow_killbind =       true;
	round.end_at_time_end =      true;
	
	round.on_start =       INVALID_FUNCTION;
	round.on_end =         INVALID_FUNCTION;
	round.on_spawn =       INVALID_FUNCTION;
	round.on_inv =         INVALID_FUNCTION;
	round.on_death =       INVALID_FUNCTION;
	round.on_attack =      INVALID_FUNCTION;
	round.on_desc =        INVALID_FUNCTION;
	round.on_ent_created = INVALID_FUNCTION;
	round.on_disconnect =  INVALID_FUNCTION;
	round.on_team =        INVALID_FUNCTION;
	round.on_class =       INVALID_FUNCTION;
	round.on_damage =      INVALID_FUNCTION;
	
	strcopy(round.name, sizeof(round.name), name);
	strcopy(round.desc, sizeof(round.desc), desc);
	
	buffer = round;
}

void SubmitInstagibRound(InstagibRound round)
{
	SpecialRoundConfig_GetOverwrites(round);
	
	if (round.is_special && SpecialRoundConfig_Num(round.name, "Disabled", 0)) {
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
	if (StrEqual(round.name, "")) {
		error = "Round.name must not be null.";
	} else if (round.main_weapon == null) {
		error = "Round.main_weapon must not be null.";
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
			
			bool enough_players = (playercount >= round.min_players);
			
			if (last_round != i && round.is_special && enough_players) {
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
	
	if (notify && round.is_special) {
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
		menu.AddItem(round.name, round.name);
	}
	
	int len = InstagibRounds.Length;
	for (int i = 1; i < len; i++) {
		InstagibRounds.GetArray(i, round);
		
		menu.AddItem(round.name, round.name);
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
	
	round.spawnuber_duration =   g_Config.UberDuration;
	round.railjump_velXY_multi = g_Config.RailjumpVelXY;
	round.railjump_velZ_multi =  g_Config.RailjumpVelZ;
	round.respawn_time =         g_Config.RespawnTime;
	
	SpecialRoundConfig_GetOverwrites(round);
	
	g_CurrentRound = round;
}