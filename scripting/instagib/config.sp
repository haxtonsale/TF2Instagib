// -------------------------------------------------------------------
KeyValues IGConfig;

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
	IGConfig = GetConfig();
	
	if (IGConfig != null) {
		IGConfig.JumpToKey("General");
		
		int alpha;
		int chatcolor1[3];
		int chatcolor2[3];
		IGConfig.GetColor("ChatColor_Default", chatcolor1[0], chatcolor1[1], chatcolor1[2], alpha);
		IGConfig.GetColor("ChatColor_Highlight", chatcolor2[0], chatcolor2[1], chatcolor2[2], alpha);
		
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
		
		g_Config.HudText_x = IGConfig.GetFloat("HudText_x", -1.0);
		g_Config.HudText_y = IGConfig.GetFloat("HudText_y", 0.78);
		IGConfig.GetColor("HudText_Color", g_Config.HudText_Color[0], g_Config.HudText_Color[1], g_Config.HudText_Color[2], g_Config.HudText_Color[3]);
		
		g_Config.MinPlayersForTDM = IGConfig.GetNum("MinPlayersForTDM", 12);
		g_Config.EnabledKillstreaks = view_as<bool>(IGConfig.GetNum("EnableKillstreaks", 1));
		g_Config.MinScore = IGConfig.GetNum("MinScore", 15);
		g_Config.RespawnTime = IGConfig.GetFloat("RespawnTime", 2.0);
		g_Config.UberDuration = IGConfig.GetFloat("UberDuration", 0.3);
		g_Config.SpecialRound_Chance = IGConfig.GetFloat("SpecialRound_Chance", 0.35);
		g_Config.MaxScoreMulti = IGConfig.GetFloat("MaxScorePlayerMultiplier", 2.75);
		g_Config.RailjumpVelXY = IGConfig.GetFloat("Railjump_VelocityMultiplier_XY", 2.9);
		g_Config.RailjumpVelZ = IGConfig.GetFloat("Railjump_VelocityMultiplier_Z", 3.2);
		
		IGConfig.Rewind();
		IGConfig.JumpToKey("Music");
		
		bool result = IGConfig.GotoFirstSubKey();
		
		if (result) {
			do {
				char name[256]; 
				IGConfig.GetSectionName(name, sizeof(name));
				
				char path[PLATFORM_MAX_PATH];
				IGConfig.GetString("Path", path, sizeof(path));
				
				int len = IGConfig.GetNum("Length");
				float volume = IGConfig.GetFloat("Volume");
				bool announce = view_as<bool>(IGConfig.GetNum("AnnounceInChat"));
				bool add_to_downloads = view_as<bool>(IGConfig.GetNum("AddToDownloads"));
				
				if (!StrEqual(path, "")) {
					AddMusic(path, name, len, add_to_downloads, announce, volume);
				}
			} while (IGConfig.GotoNextKey());
		}
	}
}

stock int SpecialRoundConfig_Num(const char[] round, const char[] key, int defvalue)
{
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		bool result = IGConfig.JumpToKey(round);
		
		if (result) {
			return IGConfig.GetNum(key, defvalue);
		}
	}
	
	return defvalue;
}

stock float SpecialRoundConfig_Float(const char[] round, const char[] key, float defvalue)
{
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		bool result = IGConfig.JumpToKey(round);
		
		if (result) {
			return IGConfig.GetFloat(key, defvalue);
		}
	}
	
	return defvalue;
}

stock void SpecialRoundConfig_String(const char[] round, const char[] key, char[] buffer, int maxlength, char[] defvalue)
{
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		bool result = IGConfig.JumpToKey(round);
		
		if (result) {
			IGConfig.GetString(key, buffer, maxlength, defvalue);
			return;
		}
	}
	
	strcopy(buffer, maxlength, defvalue);
}

// Overwrite some of the special round's properties through config
void SpecialRoundConfig_GetOverwrites(InstagibRound ig_round)
{
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		bool result = IGConfig.JumpToKey(ig_round.name);
		
		if (result) {
			ig_round.is_special = view_as<bool>(IGConfig.GetNum("IsSpecialRound", ig_round.is_special));
			ig_round.disable_achievements = view_as<bool>(IGConfig.GetNum("DisableAchievements", ig_round.disable_achievements));
			ig_round.ig_map_only = view_as<bool>(IGConfig.GetNum("InstagibMapOnly", ig_round.ig_map_only));
			
			ig_round.roundtype_flags = IGConfig.GetNum("RoundTypeFlags", ig_round.roundtype_flags);
			ig_round.round_time = IGConfig.GetNum("RoundLength", ig_round.round_time);
			ig_round.minscore = IGConfig.GetNum("MinScore", ig_round.minscore);
			ig_round.maxscore_multi = IGConfig.GetFloat("MaxScore_Multiplier", ig_round.maxscore_multi);
			ig_round.points_per_kill = IGConfig.GetNum("PointsForKill", ig_round.points_per_kill);
			ig_round.allow_killbind = view_as<bool>(IGConfig.GetNum("AllowKillbind", ig_round.allow_killbind));
			
			ig_round.railjump_velXY_multi = IGConfig.GetFloat("Railjump_VelocityMultiplier_XY", ig_round.railjump_velXY_multi);
			ig_round.railjump_velZ_multi = IGConfig.GetFloat("Railjump_VelocityMultiplier_Z", ig_round.railjump_velZ_multi);
			
			ig_round.respawn_time = IGConfig.GetFloat("RespawnTime", ig_round.respawn_time);
			ig_round.spawnuber_duration = IGConfig.GetFloat("UberDuration", ig_round.spawnuber_duration);
			
			ig_round.main_wep_clip = IGConfig.GetNum("MainWeapon_Clip", ig_round.main_wep_clip);
			ig_round.infinite_ammo = view_as<bool>(IGConfig.GetNum("InfiniteAmmo", ig_round.infinite_ammo));
			
			ig_round.min_players_tdm = IGConfig.GetNum("MinPlayers_TDM", ig_round.min_players_tdm);
			ig_round.min_players_ffa = IGConfig.GetNum("MinPlayers_FFA", ig_round.min_players_ffa);
		}
	}
}