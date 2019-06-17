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
	tdm.roundtype_flags = ROUNDTYPE_TDM;
	tdm.is_special = false;
	SubmitInstagibRound(tdm);
	
	InstagibRound ffa;
	NewInstagibRound(ffa, "Free For All");
	ffa.roundtype_flags = ROUNDTYPE_FFA;
	ffa.is_special = false;
	SubmitInstagibRound(ffa);
	
	g_CurrentRound = tdm;
	
	SR_Explosions_Init();
	SR_Headshots_Init();
	SR_OPRailguns_Init();
	SR_TimeAttack_Init();
	SR_Lives_Init();
	SR_OITC_Init();
	SR_FreezeTag_Init();
}

// -------------------------------------------------------------------
void NewInstagibRound(InstagibRound buffer, char[] name, char[] desc = "")
{
	InstagibRound round;
	
	round.spawnuber_duration = g_Config.UberDuration;
	round.railjump_velXY_multi = 2.9;
	round.railjump_velZ_multi = 3.2;
	round.minscore = g_Config.MinScore;
	round.maxscore_multi = 2.3;
	round.main_weapon = g_Weapon_Railgun;
	round.roundtype_flags = ROUNDTYPE_TDM | ROUNDTYPE_FFA;
	round.main_wep_clip = 32;
	round.infinite_ammo = true;
	round.respawn_time = g_Config.RespawnTime;
	round.points_per_kill = 1;
	round.is_special = true;
	round.announce_win = true;
	round.allow_latespawn = true;
	round.allow_killbind = true;
	round.end_at_time_end = true;
	
	round.on_start = INVALID_FUNCTION;
	round.on_end = INVALID_FUNCTION;
	round.on_spawn = INVALID_FUNCTION;
	round.on_inv = INVALID_FUNCTION;
	round.on_death = INVALID_FUNCTION;
	round.on_attack = INVALID_FUNCTION;
	round.on_desc = INVALID_FUNCTION;
	round.on_ent_created = INVALID_FUNCTION;
	round.on_disconnect = INVALID_FUNCTION;
	round.on_team = INVALID_FUNCTION;
	round.on_class = INVALID_FUNCTION;
	round.on_damage = INVALID_FUNCTION;
	
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
	} else if (!round.roundtype_flags) {
		error = "Round.roundtype_flags must not be 0.";
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

void GetDefaultRound(InstagibRound buffer, int roundtype_flags)
{
	if (!ForcedNextRound) {
		if (g_IsWaitingForPlayers) {
			InstagibRounds.GetArray(0, buffer);
		} else if (roundtype_flags & ROUNDTYPE_FFA) {
			InstagibRounds.GetArray(2, buffer);
		} else {
			InstagibRounds.GetArray(1, buffer);
		}
	} else {
		buffer = NextRound;
		ForcedNextRound = false;
	}
}

void GetRandomSpecialRound(InstagibRound buffer, int roundtype_flags)
{
	if (!ForcedNextRound) {
		static int last_round;
		
		int len = InstagibRounds.Length;
		int playercount = GetActivePlayerCount();
		int count;
		int[] suitable_rounds = new int[len];
		
		for (int i = 3; i < len; i++) {
			InstagibRound round;
			InstagibRounds.GetArray(i, round);
			
			bool enough_players = (!IsFFA() && playercount >= round.min_players_tdm) || (IsFFA() && playercount >= round.min_players_ffa);
			bool suitable_map = !round.ig_map_only || (round.ig_map_only && g_IsMapIG);
			
			if (last_round != i && round.is_special && suitable_map && enough_players) {
				if (roundtype_flags & round.roundtype_flags) {
					suitable_rounds[count] = i;
					++count;
				}
			}
		}
		
		if (!count) {
			GetDefaultRound(buffer, roundtype_flags);
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
	
	InstagibRound round;
	
	if (display_all) {
		InstagibRounds.GetArray(0, round);
		menu.AddItem(round.name, round.name);
	}
	
	int len = InstagibRounds.Length;
	for (int i = 1; i < len; i++) {
		InstagibRounds.GetArray(i, round);
		
		if (g_RoundType & round.roundtype_flags) {
			menu.AddItem(round.name, round.name);
		}
	}
	
	menu.Display(client, 60);
}