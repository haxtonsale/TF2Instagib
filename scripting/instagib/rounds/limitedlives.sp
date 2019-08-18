// -------------------------------------------------------------------
static int MaxLives;
static int PlayerLives[TF2_MAXPLAYERS+1];
static TFTeam OriginalTeam[TF2_MAXPLAYERS+1];
static Handle HudSync;

static bool AnnouncedWin; // To prevent multiple win announcements if the final kill was penetrating

static bool IsLifestealers;
static int StartingLSLives; // Starting life count for Lifestealers

// -------------------------------------------------------------------
void SR_Lives_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Limited Lives");
	sr.round_time = 300;
	sr.minscore = 322; // dynamic
	sr.points_per_kill = 0;
	sr.announce_win = false;
	sr.end_at_time_end = false;
	sr.min_players = 2;
	
	sr.on_start = SR_Lives_OnStart;
	sr.on_end = SR_Lives_OnEnd;
	sr.on_spawn = SR_Lives_OnSpawn;
	sr.on_inv = SR_Lives_OnInventory;
	sr.on_death = SR_Lives_OnDeath;
	sr.on_disconnect = SR_Lives_OnDisconnect;
	sr.on_team = SR_Lives_OnTeamChange;
	sr.on_desc = SR_Lives_Description;
	
	MaxLives = SpecialRoundConfig_Num(sr.name, "Lives", 5);
	SubmitInstagibRound(sr);
	
	strcopy(sr.name, sizeof(sr.name), "Lifestealers");
	sr.round_time = 240;
	sr.on_start = SR_Lifesteal_OnStart;
	sr.on_desc = SR_Lifesteal_Description;
	
	StartingLSLives = SpecialRoundConfig_Num(sr.name, "Lives", 3);
	SubmitInstagibRound(sr);
	
	HudSync = CreateHudSynchronizer();
	
	for (int i = 1; i <= 7; i++) {
		char sound[PLATFORM_MAX_PATH];
		FormatEx(sound, sizeof(sound), "vo/halloween_boo%i.mp3", i);
		
		InstagibPrecacheSound(sound);
	}
}

// -------------------------------------------------------------------
static void SR_Lives_CheckWinConditions()
{
	int red_lives;
	int blue_lives;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TFTeam team = TF2_GetClientTeam(i);
			
			if (team == TFTeam_Red && PlayerLives[i] >= 0) {
				red_lives += PlayerLives[i];
			} else if (team == TFTeam_Blue && PlayerLives[i] >= 0) {
				blue_lives += PlayerLives[i];
			}
		}
	}
	
	SetScore(TFTeam_Red, red_lives);
	SetScore(TFTeam_Blue, blue_lives);
	
	if (!AnnouncedWin) {
		if (!red_lives) {
			ForceWin(TFTeam_Blue);
			AnnounceWin(TFTeam_Blue, "lives remaining", blue_lives);
			
			AnnouncedWin = true;
		} else if (!blue_lives) {
			ForceWin(TFTeam_Red);
			AnnounceWin(TFTeam_Red, "lives remaining", red_lives);
			
			AnnouncedWin = true;
		}
	}
}

static void SR_Lives_GetLivesColor(int lives, int &r, int &g, int &b)
{
	static int colors[10][3] = {
		{255, 0, 0},
		{255, 55, 0},
		{255, 80, 0},
		{255, 105, 0},
		{255, 255, 0},
		{105, 255, 0},
		{80, 255, 0},
		{55, 255, 0},
		{27, 255, 0},
		{0, 255, 0},
	};
	
	if (IsLifestealers && lives > StartingLSLives) {
		lives = StartingLSLives;
	}
	
	float div = float(lives)/float((IsLifestealers) ? StartingLSLives : MaxLives);
	int rounded = RoundToFloor(div*10.0);
	
	if (rounded > 1) {
		r = colors[rounded-1][0];
		g = colors[rounded-1][1];
		b = colors[rounded-1][2];
	} else {
		r = colors[0][0];
		g = colors[0][1];
		b = colors[0][2];
	}
}

// -------------------------------------------------------------------
void SR_Lives_OnStart()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i) && !IsPlayerAlive(i)) {
			TF2_RespawnPlayer(i);
		}
	}
 	
	int red_lives;
	int blue_lives;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			TFTeam team = TF2_GetClientTeam(i);
			
			if (team == TFTeam_Red) {
				red_lives += MaxLives;
			} else {
				blue_lives += MaxLives;
			}
			
			PlayerLives[i] = MaxLives;
			OriginalTeam[i] = team;
		}
	}
	
	if (red_lives > blue_lives) {
		SetMaxScore(red_lives+1);
	} else {
		SetMaxScore(blue_lives+1);
	}
	
	AnnouncedWin = false;
	
	CreateTimer(0.10, SR_Lives_DisplayHudText, _, TIMER_REPEAT);
	SR_Lives_CheckWinConditions();
}

void SR_Lives_OnSpawn(int client, TFTeam team)
{
	// Turn people with no lives to ghosts.
	if (PlayerLives[client] <= 0 && IsClientPlaying(client)) {
		TF2_AddCondition(client, TFCond_HalloweenGhostMode);
	}
}

void SR_Lives_OnInventory(int client)
{
	if (PlayerLives[client] <= 0 && IsClientPlaying(client)) {
		TF2_RemoveWeaponSlot(client, 0);
	}
}
 
void SR_Lives_OnDeath(Round_OnDeath_Data data)
{
	int client = data.victim;
	
	--PlayerLives[client];
	Forward_OnLifeLost(client, PlayerLives[client], data.attacker);
	
	if (IsLifestealers && data.attacker > 0 && data.attacker <= MaxClients && data.attacker != client) {
		++PlayerLives[data.attacker];
	}
	
	if (PlayerLives[client] <= 0) {
		InstagibPrintToChat(true, client, "You have run out of lives!");
		Forward_AllLivesLost(client);
	}
	
	SR_Lives_CheckWinConditions();
}

void SR_Lives_OnDisconnect(int client)
{
	PlayerLives[client] = 0;
	SR_Lives_CheckWinConditions();
}

void SR_Lives_OnEnd(TFTeam winner_team, int score, int time_left)
{
	if (score == -1) { // score = -1 if the round time had ran out and end_at_time_end == false
		int red_lives;
		int blue_lives;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				TFTeam team = TF2_GetClientTeam(i);
				
				if (team == TFTeam_Red && PlayerLives[i] >= 0) {
					red_lives += PlayerLives[i];
				} else if (team == TFTeam_Blue && PlayerLives[i] >= 0) {
					blue_lives += PlayerLives[i];
				}
			}
		}
		
		if (blue_lives > red_lives) {
			ForceWin(TFTeam_Blue);
			AnnounceWin(TFTeam_Blue, "lives remaining", blue_lives);
			
			AnnouncedWin = true;
		} else if (red_lives > blue_lives) {
			ForceWin(TFTeam_Red);
			AnnounceWin(TFTeam_Red, "lives remaining", red_lives);
			
			AnnouncedWin = true;
		} else {
			Stalemate();
			AnnounceWin();
		}
	} else {
		for (int i = 1; i <= MaxClients; i++) {
			PlayerLives[i] = 0;
		}
		
		IsLifestealers = false;
	}
}

void SR_Lives_OnTeamChange(int client, TFTeam team)
{
	PlayerLives[client] = 0;
	SR_Lives_CheckWinConditions();
}

void SR_Lives_Description(char[] desc, int maxlength)
{
	FormatEx(desc, maxlength, "You only have {%i} lives! Make them count!", MaxLives);
}

public Action SR_Lives_DisplayHudText(Handle timer)
{
	if (g_IsRoundActive) {
		for (int i = 1; i <= MaxClients; i++) {
			int color[3];
			if (IsClientInGame(i)) {
				SR_Lives_GetLivesColor(PlayerLives[i], color[0], color[1], color[2]);
				
				SetHudTextParams(0.275, 0.795, 0.2, color[0], color[1], color[2], 255, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(i, HudSync, "Lives: ❤%i", PlayerLives[i]);
			}
		}
		
		return Plugin_Continue;
	} else {
		return Plugin_Stop;
	}
}

// -------------------------------------------------------------------
void SR_Lifesteal_OnStart()
{
	IsLifestealers = true;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i) && !IsPlayerAlive(i)) {
			TF2_RespawnPlayer(i);
		}
	}
	
	int red_lives;
	int blue_lives;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			TFTeam team = TF2_GetClientTeam(i);
			
			if (team == TFTeam_Red) {
				red_lives += StartingLSLives;
			} else {
				blue_lives += StartingLSLives;
			}
			
			PlayerLives[i] = StartingLSLives;
			OriginalTeam[i] = team;
		}
	}
	
	SetMaxScore(red_lives+blue_lives);
	
	AnnouncedWin = false;
	
	CreateTimer(0.10, SR_Lives_DisplayHudText, _, TIMER_REPEAT);
	SR_Lives_CheckWinConditions();
}

void SR_Lifesteal_Description(char[] desc, int maxlength)
{
	FormatEx(desc, maxlength, "You start with {%i} lives! Killing an enemy will give you {1} life!", StartingLSLives);
}