// -------------------------------------------------------------------
static KeyValues IGConfig;

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
		
		FormatEx(g_InstagibTag, sizeof(g_InstagibTag), "\x07E50000[TF2Instagib]%s", g_Config.ChatColor);
		
		g_Config.HudText_x = IGConfig.GetFloat("HudText_x", -1.0);
		g_Config.HudText_y = IGConfig.GetFloat("HudText_y", 0.78);
		IGConfig.GetColor("HudText_Color", g_Config.HudText_Color[0], g_Config.HudText_Color[1], g_Config.HudText_Color[2], g_Config.HudText_Color[3]);
		
		g_Config.EnabledKillstreaks =  view_as<bool>(IGConfig.GetNum("EnableKillstreaks", 1));
		g_Config.MinScore =            IGConfig.GetNum("MinScore", 15);
		g_Config.RespawnTime =         IGConfig.GetFloat("RespawnTime", 2.0);
		g_Config.UberDuration =        IGConfig.GetFloat("UberDuration", 0.3);
		g_Config.SpecialRound_Chance = IGConfig.GetFloat("SpecialRound_Chance", 0.35);
		g_Config.MaxScoreMulti =       IGConfig.GetFloat("MaxScorePlayerMultiplier", 2.75);
		g_Config.RailjumpVelXY =       IGConfig.GetFloat("Railjump_VelocityMultiplier_XY", 2.9);
		g_Config.RailjumpVelZ =        IGConfig.GetFloat("Railjump_VelocityMultiplier_Z", 3.2);
		g_Config.EnabledBhop =         view_as<bool>(IGConfig.GetNum("AutoBhop", 1));
		g_Config.BhopMaxSpeed =        IGConfig.GetFloat("BhopMaxSpeed", 456.0);
		g_Config.MultikillInterval =   IGConfig.GetNum("MultikillInterval", 3);
		g_Config.InstantRespawn =      view_as<bool>(IGConfig.GetNum("InstantRespawn", 0));
		g_Config.WebVersionCheck =     view_as<bool>(IGConfig.GetNum("CheckInstagibVersion", 1));
		g_Config.WebMapConfigs =       view_as<bool>(IGConfig.GetNum("DownloadOfficialMapConfigs", 1));
		
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
				
				if (!StrEqual(path, "")) {
					AddMusic(path, name, len, announce, volume);
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
		bool result = IGConfig.JumpToKey(ig_round.Name);
		
		if (result) {
			ig_round.IsSpecial = view_as<bool>(IGConfig.GetNum("IsSpecialRound", ig_round.IsSpecial));
			ig_round.RoundTime = IGConfig.GetNum("RoundLength", ig_round.RoundTime);
			ig_round.MinScore = IGConfig.GetNum("MinScore", ig_round.MinScore);
			ig_round.MaxScoreMultiplier = IGConfig.GetFloat("MaxScore_Multiplier", ig_round.MaxScoreMultiplier);
			ig_round.PointsPerKill = IGConfig.GetNum("PointsForKill", ig_round.PointsPerKill);
			ig_round.ShouldAllowKillbind = view_as<bool>(IGConfig.GetNum("AllowKillbind", ig_round.ShouldAllowKillbind));
			ig_round.RailjumpVelocityXY = IGConfig.GetFloat("Railjump_VelocityMultiplier_XY", ig_round.RailjumpVelocityXY);
			ig_round.RailjumpVelocityZ = IGConfig.GetFloat("Railjump_VelocityMultiplier_Z", ig_round.RailjumpVelocityZ);
			ig_round.RespawnTime = IGConfig.GetFloat("RespawnTime", ig_round.RespawnTime);
			ig_round.UberDuration = IGConfig.GetFloat("UberDuration", ig_round.UberDuration);
			ig_round.MainWeaponClip = IGConfig.GetNum("MainWeapon_Clip", ig_round.MainWeaponClip);
			ig_round.IsAmmoInfinite = view_as<bool>(IGConfig.GetNum("InfiniteAmmo", ig_round.IsAmmoInfinite));
			ig_round.MinPlayers = IGConfig.GetNum("MinPlayers", ig_round.MinPlayers);
		}
	}
}