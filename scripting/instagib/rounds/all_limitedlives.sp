// -------------------------------------------------------------------
static int MaxLives;
static int PlayerLives[MAXPLAYERS+1];
static TFTeam OriginalTeam[MAXPLAYERS+1];
static Handle HudSync;

static bool AnnouncedWin; // To prevent multiple win announcements if the final kill was penetrating

// -------------------------------------------------------------------
void SR_Lives_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Limited Lives");
	sr.round_time = 300;
	sr.allow_latespawn = false;
	sr.minscore = 322; // dynamic
	sr.points_per_kill = 0;
	sr.announce_win = false;
	sr.end_at_time_end = false;
	sr.announce_win = false;
	sr.min_players_tdm = 2;
	sr.min_players_ffa = 2;
	
	sr.on_start = SR_Lives_OnStart;
	sr.on_end = SR_Lives_OnEnd;
	sr.on_death = SR_Lives_OnDeath;
	sr.on_disconnect = SR_Lives_OnDisconnect;
	sr.on_team = SR_Lives_OnTeamChange;
	sr.on_desc = SR_Lives_Description;
	
	MaxLives = SpecialRoundConfig_Num(sr.name, "Lives", 5);
	
	HudSync = CreateHudSynchronizer();
	
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
static void SR_Lives_CheckWinConditions()
{
	if (IsFFA()) {
		int top_player[2];
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				if (PlayerLives[i] > top_player[1]) {
					top_player[0] = i;
					top_player[1] = PlayerLives[i];
				}
			}
		}
		
		FFA_Win(top_player[0]);
		AnnounceWin(_, "lives remaining", top_player[0], top_player[1]);
		
	} else {
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
				AnnounceWin(TFTeam_Blue, "lives remaining", _, blue_lives);
				
				AnnouncedWin = true;
			} else if (!blue_lives) {
				ForceWin(TFTeam_Red);
				AnnounceWin(TFTeam_Red, "lives remaining", _, red_lives);
				
				AnnouncedWin = true;
			}
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
	
	float div = float(lives)/float(MaxLives);
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
 
void SR_Lives_OnDeath(Round_OnDeath_Data data)
{
	int client = data.victim;
	
	--PlayerLives[client];
	
	if (PlayerLives[client] > 0) {
		CreateTimer(g_CurrentRound.respawn_time, Timer_Respawn, client);
	}
	
	SR_Lives_CheckWinConditions();
}

void SR_Lives_OnDisconnect(int client)
{
	PlayerLives[client] = 0;
	SR_Lives_CheckWinConditions();
}

void SR_Lives_OnEnd(TFTeam winner_team, int score)
{
	if (score == -1) { // score = -1 if the round time had ran out and end_at_time_end == false
		int red_lives;
		int blue_lives;
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				TFTeam team = TF2_GetClientTeam(i);
				
				if (team == TFTeam_Red) {
					red_lives += PlayerLives[i];
				} else {
					blue_lives += PlayerLives[i];
				}
			}
		}
		
		if (blue_lives > red_lives) {
			ForceWin(TFTeam_Blue);
			AnnounceWin(TFTeam_Blue, "lives remaining", _, blue_lives);
		} else if (red_lives > blue_lives) {
			ForceWin(TFTeam_Red);
			AnnounceWin(TFTeam_Red, "lives remaining", _, red_lives);
		} else {
			Stalemate();
			AnnounceWin();
		}
	}
	
	for (int i = 1; i <= MaxClients; i++) {
		PlayerLives[i] = 0;
	}
}

void SR_Lives_OnTeamChange(int client, TFTeam team)
{
	PlayerLives[client] = 0;
	SR_Lives_CheckWinConditions();
}

void SR_Lives_Description(char[] desc, int maxlength)
{
	FormatEx(desc, maxlength, "%sYou only have %s%i%s lives! Make them count!", g_Config.ChatColor, g_Config.ChatColor_Highlight, MaxLives, g_Config.ChatColor);
}

public Action SR_Lives_DisplayHudText(Handle timer)
{
	if (g_IsRoundActive) {
		int color[3];
		
		for (int i = 1; i <= MaxClients; i++) {
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