// -------------------------------------------------------------------
enum struct SpawnPoint
{
	TFTeam team;
	float pos[3];
	float rotation;
}

enum
{
	EditMode_Exit = 1,
	EditMode_ToggleMusic,
	EditMode_CreateRed,
	EditMode_CreateBlue,
	EditMode_Delete,
	EditMode_Export,
}

// -------------------------------------------------------------------
void CreateMapConfigFolder()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps");
	
	if (!DirExists(path)) {
		CreateDirectory(path, FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_EXEC | FPERM_O_READ | FPERM_G_EXEC);
	}
}

void LoadMapConfig(const char[] mapname)
{
	delete g_MapConfig.kv;
	delete g_MapConfig.SpawnPoints;
	g_MapConfig.IsMusicDisabled = false;
	
	g_MapConfig.SpawnPoints = new ArrayList(sizeof(SpawnPoint));
	g_MapConfig.kv = new KeyValues("Instagib Map Config");
	g_MapConfig.kv.SetNum("Disable Music", 0);
	CreateMapConfigFolder();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps/%s.cfg", mapname);
	if (!g_MapConfig.kv.ImportFromFile(path)) {
		// Look for a more generic map configs (e.g. koth_.cfg and koth_coalplant.cfg will work for koth_coalplant_b8)
		if (ParseDirForMapConfig("configs/instagib_maps", mapname, path)) {
			g_MapConfig.kv.ImportFromFile(path);
		} else {
			// Check for the map config in instagib_maps/official
			BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps/official/%s.cfg", mapname);
			if (!g_MapConfig.kv.ImportFromFile(path)) {
				// Look for a more generic map configs in instagib_maps/official
				ParseDirForMapConfig("configs/instagib_maps/official", mapname, path);
				g_MapConfig.kv.ImportFromFile(path);
			}
		}
	}
	
	ReloadMapConfigKeyValues();
}

bool ParseDirForMapConfig(const char[] path, const char[] mapname, char cfgpath[PLATFORM_MAX_PATH])
{
	char folderpath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, folderpath, sizeof(folderpath), path);
	DirectoryListing list = OpenDirectory(folderpath);
	
	if (list) {
		int returnstrlen;
		char returnstr[PLATFORM_MAX_PATH];
		char filename[PLATFORM_MAX_PATH];
		while (list.GetNext(filename, sizeof(filename))) {
			if (StrContains(filename, ".cfg") != -1) {
				char filename2[PLATFORM_MAX_PATH];
				CSubString(filename, filename2, sizeof(filename2), 0, strlen(filename)-4);
				
				int mapnamelen = strlen(mapname);
				if (mapnamelen > returnstrlen && StrContains(mapname, filename2) > -1) {
					BuildPath(Path_SM, returnstr, sizeof(returnstr), "%s/%s", path, mapname);
					returnstrlen = mapnamelen;
				}
			}
		}
		
		if (returnstrlen) {
			cfgpath = returnstr;
			return true;
		}
	}
	
	return false;
}

void ReloadMapConfigKeyValues()
{
	g_MapConfig.kv.Rewind();
	g_MapConfig.IsMusicDisabled = view_as<bool>(g_MapConfig.kv.GetNum("Disable Music"));
	if (g_MapConfig.kv.JumpToKey("Spawn Points", false)) {
		if (g_MapConfig.kv.GotoFirstSubKey(false)) {
			do {
				SpawnPoint spawn;
				
				spawn.rotation = g_MapConfig.kv.GetFloat(NULL_STRING);
				char name[255];
				char data[4][32];
				g_MapConfig.kv.GetSectionName(name, sizeof(name));
				ExplodeString(name, " ", data, sizeof(data), sizeof(data[]));
				
				spawn.team = StrEqual(data[0], "red") ? TFTeam_Red : TFTeam_Blue;
				spawn.pos[0] = StringToFloat(data[1]);
				spawn.pos[1] = StringToFloat(data[2]);
				spawn.pos[2] = StringToFloat(data[3]);
				
				if (g_MapConfig.SpawnPoints == null) {
					g_MapConfig.SpawnPoints = new ArrayList(sizeof(SpawnPoint));
				}
				
				g_MapConfig.SpawnPoints.PushArray(spawn);
				
				#if defined DEBUG
				PrintToServer("Loaded Spawn Point (%.1f %.1f %.1f) [%.1f]", spawn.pos[0], spawn.pos[1], spawn.pos[2], spawn.rotation);
				#endif
			} while (g_MapConfig.kv.GotoNextKey(false));
		}
	}
}

void SaveMapConfig()
{
	g_MapConfig.kv.Rewind();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps/%s.cfg", GetMapName());
	g_MapConfig.kv.ExportToFile(path);
}

void CreateSpawnPoint(TFTeam team, float pos[3], float rotation)
{
	SpawnPoint spawn;
	spawn.team = team;
	spawn.pos[0] = pos[0];
	spawn.pos[1] = pos[1];
	spawn.pos[2] = pos[2];
	spawn.rotation = rotation;
	
	g_MapConfig.SpawnPoints.PushArray(spawn);
	g_MapConfig.kv.Rewind();
	g_MapConfig.kv.JumpToKey("Instagib Map Config");
	g_MapConfig.kv.JumpToKey("Spawn Points", true);
	
	char section[128];
	FormatEx(section, sizeof(section), "%s %.2f %.2f %.2f", team == TFTeam_Red ? "red" : "blue", pos[0], pos[1], pos[2]);
	g_MapConfig.kv.SetFloat(section, rotation);
	
	int ent  = CreateEntityByName("info_player_teamspawn");
	if (ent) {
		float ang[3];
		ang[1] = rotation;
		
		SetVariantInt(view_as<int>(team));
		AcceptEntityInput(ent, "SetTeam");
		DispatchKeyValue(ent, "targetname", "INSTAGIB_SPAWNPOINT");
		DispatchSpawn(ent);
		TeleportEntity(ent, pos, ang, NULL_VECTOR);
	}
}

void DeleteSpawnPoint(TFTeam team, float pos[3])
{
	g_MapConfig.kv.Rewind();
	if (g_MapConfig.kv.JumpToKey("Spawn Points") && g_MapConfig.kv.GotoFirstSubKey(false)) {
		do {
			char name[255];
			char data[4][32];
			g_MapConfig.kv.GetSectionName(name, sizeof(name));
			ExplodeString(name, " ", data, sizeof(data), sizeof(data[]));
			
			int rounded_pos[3];
			TFTeam spawn_team = StrEqual(data[0], "red") ? TFTeam_Red : TFTeam_Blue;
			rounded_pos[0] = RoundFloat(StringToFloat(data[1]));
			rounded_pos[1] = RoundFloat(StringToFloat(data[2]));
			rounded_pos[2] = RoundFloat(StringToFloat(data[3]));
			
			if (team == spawn_team && rounded_pos[0] == RoundFloat(pos[0]) && rounded_pos[1] == RoundFloat(pos[1]) && rounded_pos[2] == RoundFloat(pos[2])) {
				g_MapConfig.kv.GoBack();
				g_MapConfig.kv.DeleteKey(name);
				break;
			}
		} while (g_MapConfig.kv.GotoNextKey(false));
	}
}

void SetupSpawnPoints()
{
	int len = g_MapConfig.SpawnPoints.Length;
	if (!len) {
		return;
	}
	
	int spawnpoint = INVALID_ENT_REFERENCE;
	while ((spawnpoint = FindEntityByClassname(spawnpoint, "info_player_teamspawn")) != INVALID_ENT_REFERENCE) {
		RemoveEntity(spawnpoint);
	}
	
	for (int i = 0; i < len; i++) {
		SpawnPoint spawn;
		g_MapConfig.SpawnPoints.GetArray(i, spawn);
		
		int ent  = CreateEntityByName("info_player_teamspawn");
		if (ent) {
			float pos[3];
			float ang[3];
			pos[0] = spawn.pos[0];
			pos[1] = spawn.pos[1];
			pos[2] = spawn.pos[2];
			ang[1] = spawn.rotation;
			
			SetVariantInt(view_as<int>(spawn.team));
			AcceptEntityInput(ent, "SetTeam");
			DispatchKeyValue(ent, "targetname", "INSTAGIB_SPAWNPOINT");
			DispatchSpawn(ent);
			TeleportEntity(ent, pos, ang, NULL_VECTOR);
		}
	}
	
	RequestFrame(Frame_RespawnAll);
}

void CreateSpawnPointEnts()
{
	int spawnpoint = INVALID_ENT_REFERENCE;
	while ((spawnpoint = FindEntityByClassname(spawnpoint, "info_player_teamspawn")) != INVALID_ENT_REFERENCE) {
		char name[128];
		GetEntPropString(spawnpoint, Prop_Data, "m_iName", name, sizeof(name));
		
		if (StrContains(name, "INSTAGIB_SPAWNPOINT") == 0) {
			int ent  = CreateEntityByName("prop_dynamic_override");
			if (ent) {
				float pos[3];
				float ang[3];
				
				GetEntPropVector(spawnpoint, Prop_Data, "m_vecOrigin", pos);
				GetEntPropVector(spawnpoint, Prop_Data, "m_angAbsRotation", ang);
				
				FormatEx(name, sizeof(name), "INSTAGIB_SPAWNPOINT:%i", spawnpoint);
				SetEntPropString(ent, Prop_Data, "m_iName", name);
				
				SetEntityModel(ent, "models/items/ammopack_large.mdl");
				SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
				SetEntityRenderColor(ent, GetEntProp(spawnpoint, Prop_Data, "m_iTeamNum") == 2 ? 255 : 0, 0, GetEntProp(spawnpoint, Prop_Data, "m_iTeamNum") == 2 ? 0 : 255);
				
				SetEntProp(ent, Prop_Data, "m_nSolidType", 0x0004 | 0x0008);
				
				DispatchSpawn(ent);
				TeleportEntity(ent, pos, ang, NULL_VECTOR);
			}
		}
	}
}

void ClearSpawnPointEnts()
{
	int max = GetMaxEntities();
	for (int i = 1; i <= max; i++) {
		if (IsValidEntity(i)) {
			char classname[255];
			GetEntityClassname(i, classname, sizeof(classname));
			
			if (StrEqual(classname, "prop_dynamic")) {
				char name[128];
				GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
				
				if (StrContains(name, "INSTAGIB_SPAWNPOINT") == 0) {
					AcceptEntityInput(i, "Kill");
				}
			}
		}
	}
}

void ReloadSpawnPointEnts()
{
	ClearSpawnPointEnts();
	CreateSpawnPointEnts();
}

// Overwrite some of the special round's properties through the map config
void LoadMapRoundOverwrites(InstagibRound ig_round)
{
	g_MapConfig.kv.Rewind();
	if (g_MapConfig.kv.JumpToKey("Rounds")) {
		LoadRoundOverwrites(ig_round, g_MapConfig.kv, "All Rounds");
		LoadRoundOverwrites(ig_round, g_MapConfig.kv, ig_round.Name);
	}
}

public void Frame_RespawnAll(any data)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TF2_RespawnPlayer(i);
			InvulnClient(i, TFCondDuration_Infinite);
		}
	}
}

// -------------------------------------------------------------------
void ToggleEditMode(int client)
{
	static bool in_editmode;
	
	if (!in_editmode) {
		in_editmode = true;
		CreateSpawnPointEnts();
		Panel_EditMode(client);
	} else {
		in_editmode = false;
		ClearSpawnPointEnts();
	}
}