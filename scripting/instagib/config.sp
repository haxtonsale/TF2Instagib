// -------------------------------------------------------------------
static KeyValues IGConfig;

// -------------------------------------------------------------------
KeyValues GetConfig()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "/configs/instagib.cfg");
	
	KeyValues kv = new KeyValues("Instagib");
	if (!kv.ImportFromFile(path)) {
		BuildPath(Path_SM, path, sizeof(path), "/configs/instagib.txt");
		if (!kv.ImportFromFile(path)) {
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
			strcopy(g_Config.ChatColorHighlight, sizeof(g_Config.ChatColorHighlight), ColorStr(rgb(chatcolor2[0], chatcolor2[1], chatcolor2[2])));
		} else {
			strcopy(g_Config.ChatColorHighlight, sizeof(g_Config.ChatColorHighlight), "\x01");
		}
		
		FormatEx(g_InstagibTag, sizeof(g_InstagibTag), "\x07E50000[Instagib]%s", g_Config.ChatColor);
		
		g_Config.HudTextX = IGConfig.GetFloat("HudText_x", -1.0);
		g_Config.HudTextY = IGConfig.GetFloat("HudText_y", 0.78);
		IGConfig.GetColor("HudText_Color", g_Config.HudTextColor[0], g_Config.HudTextColor[1], g_Config.HudTextColor[2], g_Config.HudTextColor[3]);
		
		g_Config.EnabledKillstreaks = view_as<bool>(IGConfig.GetNum("EnableKillstreaks", 1));
		g_Config.MinScore = IGConfig.GetNum("MinScore", 15);
		g_Config.RespawnTime = IGConfig.GetFloat("RespawnTime", 2.0);
		g_Config.UberDuration = IGConfig.GetFloat("UberDuration", 0.3);
		g_Config.SpecialRoundChance = IGConfig.GetFloat("SpecialRound_Chance", 0.35);
		g_Config.MaxScoreMulti = IGConfig.GetFloat("MaxScorePlayerMultiplier", 2.75);
		g_Config.RailjumpVelXY = IGConfig.GetFloat("Railjump_VelocityMultiplier_XY", 2.9);
		g_Config.RailjumpVelZ = IGConfig.GetFloat("Railjump_VelocityMultiplier_Z", 3.2);
		g_Config.EnabledBhop = view_as<bool>(IGConfig.GetNum("AutoBhop", 1));
		g_Config.BhopMaxSpeed = IGConfig.GetFloat("BhopMaxSpeed", 456.0);
		g_Config.MultikillInterval = IGConfig.GetFloat("MultikillInterval", 3.0);
		g_Config.InstantRespawn = view_as<bool>(IGConfig.GetNum("InstantRespawn", 0));
		g_Config.WebVersionCheck = view_as<bool>(IGConfig.GetNum("CheckInstagibVersion", 1));
		g_Config.WebMapConfigs = view_as<bool>(IGConfig.GetNum("DownloadOfficialMapConfigs", 1));
		
		g_CvarAirAccel.SetInt(IGConfig.GetNum("AirAcceleration", 30));
		
		if (g_Config.InstantRespawn) {
			g_CvarNoRespawnTimes.SetBool(true);
			g_CvarSpecFreezeTime.SetFloat(-1.0);
		} else {
			g_CvarNoRespawnTimes.RestoreDefault();
			g_CvarSpecFreezeTime.RestoreDefault();
		}
		
		IGConfig.Rewind();
		IGConfig.JumpToKey("Music");
		
		if (IGConfig.GotoFirstSubKey()) {
			do {
				char name[256]; 
				IGConfig.GetSectionName(name, sizeof(name));
				
				char path[PLATFORM_MAX_PATH];
				IGConfig.GetString("Path", path, sizeof(path));
				
				int len = IGConfig.GetNum("Length");
				float volume = IGConfig.GetFloat("Volume");
				bool announce = view_as<bool>(IGConfig.GetNum("AnnounceInChat"));
				
				if (path[0] != '\0') {
					AddMusic(path, name, len, announce, volume);
				}
			} while (IGConfig.GotoNextKey());
		}
		
		IGConfig.Rewind();
		if (IGConfig.JumpToKey("Multikills")) {
			if (IGConfig.GotoFirstSubKey()) {
				do {
					char name[32]; 
					IGConfig.GetSectionName(name, sizeof(name));
					
					char article[4];
					IGConfig.GetString("Article", article, sizeof(article));
					
					char color[16];
					IGConfig.GetString("Color", color, sizeof(color));
					
					char sound[PLATFORM_MAX_PATH];
					IGConfig.GetString("Sound", sound, sizeof(sound));
					
					int kills = IGConfig.GetNum("KillsRequired");
					bool announce = view_as<bool>(IGConfig.GetNum("AnnounceInChat"));
					
					NewMultikillTier(kills, announce, article, name, color, sound);
				} while (IGConfig.GotoNextKey());
			}
		}
	}
}

stock int SpecialRoundConfig_Num(const char[] round, const char[] key, int defvalue)
{
	g_MapConfig.kv.Rewind();
	if (g_MapConfig.kv.JumpToKey("Rounds")) {
		if (g_MapConfig.kv.JumpToKey(round)) {
			return g_MapConfig.kv.GetNum(key, defvalue);
		}
	}
	
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		
		if (IGConfig.JumpToKey(round)) {
			return IGConfig.GetNum(key, defvalue);
		}
	}
	
	return defvalue;
}

stock float SpecialRoundConfig_Float(const char[] round, const char[] key, float defvalue)
{
	g_MapConfig.kv.Rewind();
	if (g_MapConfig.kv.JumpToKey("Rounds")) {
		if (g_MapConfig.kv.JumpToKey(round)) {
			return g_MapConfig.kv.GetFloat(key, defvalue);
		}
	}
	
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		
		if (IGConfig.JumpToKey(round)) {
			return IGConfig.GetFloat(key, defvalue);
		}
	}
	
	return defvalue;
}

stock void SpecialRoundConfig_String(const char[] round, const char[] key, char[] buffer, int maxlength, char[] defvalue)
{
	g_MapConfig.kv.Rewind();
	if (g_MapConfig.kv.JumpToKey("Rounds")) {
		if (g_MapConfig.kv.JumpToKey(round)) {
			IGConfig.GetString(key, buffer, maxlength, defvalue);
			return;
		}
	}
	
	if (IGConfig != null) {
		IGConfig.Rewind();
		IGConfig.JumpToKey("Rounds");
		
		if (IGConfig.JumpToKey(round)) {
			IGConfig.GetString(key, buffer, maxlength, defvalue);
			return;
		}
	}
	
	strcopy(buffer, maxlength, defvalue);
}

void LoadRoundOverwrites(InstagibRound round, KeyValues kv, char[] key)
{
	if (kv.JumpToKey(key)) {
		round.RoundTime = kv.GetNum("RoundLength", round.RoundTime);
		round.MinScore = kv.GetNum("MinScore", round.MinScore);
		round.MaxScoreMultiplier = kv.GetFloat("MaxScore_Multiplier", round.MaxScoreMultiplier);
		round.PointsPerKill = kv.GetNum("PointsForKill", round.PointsPerKill);
		round.AllowKillbind = view_as<bool>(kv.GetNum("AllowKillbind", round.AllowKillbind));
		round.RailjumpVelocityXY = kv.GetFloat("Railjump_VelocityMultiplier_XY", round.RailjumpVelocityXY);
		round.RailjumpVelocityZ = kv.GetFloat("Railjump_VelocityMultiplier_Z", round.RailjumpVelocityZ);
		round.RespawnTime = kv.GetFloat("RespawnTime", round.RespawnTime);
		round.UberDuration = kv.GetFloat("UberDuration", round.UberDuration);
		round.MainWeaponClip = kv.GetNum("MainWeapon_Clip", round.MainWeaponClip);
		round.IsAmmoInfinite = view_as<bool>(kv.GetNum("InfiniteAmmo", round.IsAmmoInfinite));
		
		kv.GoBack();
	}
}

// Overwrite some of the special round's properties through config
void LoadConfigRoundOverwrites(InstagibRound ig_round)
{
	if (IGConfig != null) {
		IGConfig.Rewind();
		
		if (IGConfig.JumpToKey("Rounds")) {
			LoadRoundOverwrites(ig_round, IGConfig, "All Rounds");
			LoadRoundOverwrites(ig_round, IGConfig, ig_round.Name);
		}
	}
}