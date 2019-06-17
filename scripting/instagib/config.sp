// -------------------------------------------------------------------
KeyValues GetConfig()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "/configs/instagib.cfg");
	
	KeyValues kv = new KeyValues("Instagib");
	bool success = kv.ImportFromFile(path);
	
	if (!success) {
		BuildPath(Path_SM, path, sizeof(path), "/configs/instagib.txt");
		success = kv.ImportFromFile(path);
		
		if (!success) {
			LogError("Couldn't find %s!", path);
			delete kv;
		}
	}
	
	return kv;
}

void LoadConfig()
{
	KeyValues kv = GetConfig();
	
	if (kv != null) {
		kv.JumpToKey("General");
		
		int alpha;
		int chatcolor1[3];
		int chatcolor2[3];
		kv.GetColor("ChatColor_Default", chatcolor1[0], chatcolor1[1], chatcolor1[2], alpha);
		kv.GetColor("ChatColor_Highlight", chatcolor2[0], chatcolor2[1], chatcolor2[2], alpha);
		
		if (chatcolor1[0] + chatcolor1[1] + chatcolor1[2] > 0) {
			strcopy(g_Config.ChatColor, sizeof(g_Config.ChatColor), ColorStr(rgb(chatcolor1[0], chatcolor1[1], chatcolor1[2])));
		} else {
			strcopy(g_Config.ChatColor, sizeof(g_Config.ChatColor), "\x01");
		}
		
		if (chatcolor2[0] + chatcolor2[1] + chatcolor2[2] > 0) {
			strcopy(g_Config.ChatColor_Highlight, sizeof(g_Config.ChatColor_Highlight), ColorStr(rgb(chatcolor2[0], chatcolor2[1], chatcolor2[2])));
		} else {
			strcopy(g_Config.ChatColor_Highlight, sizeof(g_Config.ChatColor_Highlight), "\x01");
		}
		
		FormatEx(g_InstagibTag, sizeof(g_InstagibTag), "\x07E50000[Instagib]%s", g_Config.ChatColor);
		
		g_Config.HudText_x = kv.GetFloat("HudText_x", -1.0);
		g_Config.HudText_y = kv.GetFloat("HudText_y", 0.78);
		kv.GetColor("HudText_Color", g_Config.HudText_Color[0], g_Config.HudText_Color[1], g_Config.HudText_Color[2], g_Config.HudText_Color[3]);
		
		g_Config.MinPlayersForTDM = kv.GetNum("MinPlayersForTDM", 12);
		g_Config.EnabledKillstreaks = view_as<bool>(kv.GetNum("EnableKillstreaks", 1));
		g_Config.MinScore = kv.GetNum("MinScore", 15);
		g_Config.RespawnTime = kv.GetFloat("RespawnTime", 2.0);
		g_Config.UberDuration = kv.GetFloat("UberDuration", 0.3);
		g_Config.SpecialRound_Chance = kv.GetFloat("SpecialRound_Chance", 0.35);
		
		kv.Rewind();
		kv.JumpToKey("Music");
		
		bool result = kv.GotoFirstSubKey();
		
		if (result) {
			do {
				char name[256]; 
				kv.GetSectionName(name, sizeof(name));
				
				char path[PLATFORM_MAX_PATH];
				kv.GetString("Path", path, sizeof(path));
				
				int len = kv.GetNum("Length");
				float volume = kv.GetFloat("Volume");
				bool announce = view_as<bool>(kv.GetNum("AnnounceInChat"));
				bool add_to_downloads = view_as<bool>(kv.GetNum("AddToDownloads"));
				
				if (!StrEqual(path, "")) {
					AddMusic(path, name, len, add_to_downloads, announce, volume);
				}
			} while (kv.GotoNextKey());
		}
	}
	
	delete kv;
}

stock int SpecialRoundConfig_Num(const char[] round, const char[] key, int defvalue)
{
	KeyValues kv = GetConfig();
	
	if (kv != null) {
		kv.JumpToKey("Rounds");
		bool result = kv.JumpToKey(round);
		
		if (result) {
			return kv.GetNum(key, defvalue);
		}
	}
	
	return defvalue;
}

stock float SpecialRoundConfig_Float(const char[] round, const char[] key, float defvalue)
{
	KeyValues kv = GetConfig();
	
	if (kv != null) {
		kv.JumpToKey("Rounds");
		bool result = kv.JumpToKey(round);
		
		if (result) {
			return kv.GetFloat(key, defvalue);
		}
	}
	
	return defvalue;
}

stock void SpecialRoundConfig_String(const char[] round, const char[] key, char[] buffer, int maxlength, char[] defvalue)
{
	KeyValues kv = GetConfig();
	
	if (kv != null) {
		kv.JumpToKey("Rounds");
		bool result = kv.JumpToKey(round);
		
		if (result) {
			kv.GetString(key, buffer, maxlength, defvalue);
			return;
		}
	}
	
	strcopy(buffer, maxlength, defvalue);
}

// Overwrite some of the special round's properties through config
void SpecialRoundConfig_GetOverwrites(InstagibRound ig_round)
{
	KeyValues kv = GetConfig();
	
	if (kv != null) {
		kv.JumpToKey("Rounds");
		bool result = kv.JumpToKey(ig_round.name);
		
		if (result) {
			ig_round.is_special = view_as<bool>(kv.GetNum("IsSpecialRound", ig_round.is_special));
			ig_round.disable_achievements = view_as<bool>(kv.GetNum("DisableAchievements", ig_round.disable_achievements));
			ig_round.ig_map_only = view_as<bool>(kv.GetNum("InstagibMapOnly", ig_round.ig_map_only));
			
			ig_round.roundtype_flags = kv.GetNum("RoundTypeFlags", ig_round.roundtype_flags);
			ig_round.round_time = kv.GetNum("RoundLength", ig_round.round_time);
			ig_round.minscore = kv.GetNum("MinScore", ig_round.minscore);
			ig_round.maxscore_multi = kv.GetFloat("MaxScore_Multiplier", ig_round.maxscore_multi);
			ig_round.points_per_kill = kv.GetNum("PointsForKill", ig_round.points_per_kill);
			ig_round.allow_killbind = view_as<bool>(kv.GetNum("AllowKillbind", ig_round.allow_killbind));
			
			ig_round.railjump_velXY_multi = kv.GetFloat("Railjump_VelocityMultiplier_XY", ig_round.railjump_velXY_multi);
			ig_round.railjump_velZ_multi = kv.GetFloat("Railjump_VelocityMultiplier_Z", ig_round.railjump_velZ_multi);
			
			ig_round.respawn_time = kv.GetFloat("RespawnTime", ig_round.respawn_time);
			ig_round.spawnuber_duration = kv.GetFloat("UberDuration", ig_round.spawnuber_duration);
			
			ig_round.main_wep_clip = kv.GetNum("MainWeapon_Clip", ig_round.main_wep_clip);
			ig_round.infinite_ammo = view_as<bool>(kv.GetNum("InfiniteAmmo", ig_round.infinite_ammo));
			
			ig_round.min_players_tdm = kv.GetNum("MinPlayers_TDM", ig_round.min_players_tdm);
			ig_round.min_players_ffa = kv.GetNum("MinPlayers_FFA", ig_round.min_players_ffa);
		}
	}
}