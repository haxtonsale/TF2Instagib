// -------------------------------------------------------------------
enum struct SpawnPoint
{
	TFTeam team;
	float pos[3];
	float rotation;
}

enum struct MapConfig
{
	KeyValues kv;
	bool IsMusicDisabled;
	ArrayList SpawnPoints;
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

MapConfig g_MapConfig;

// -------------------------------------------------------------------
void LoadMapConfig(const char[] mapname)
{
	delete g_MapConfig.kv;
	delete g_MapConfig.SpawnPoints;
	g_MapConfig.IsMusicDisabled = false;
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "/configs/instagib_maps/%s.cfg", mapname);
	
	if (g_MapConfig.kv == null) {
		g_MapConfig.kv = new KeyValues("Instagib Map Config");
	}
	
	if (g_MapConfig.kv.ImportFromFile(path)) {
		ReloadMapConfigKeyValues();
	} else {
		delete g_MapConfig.kv;
	}
}

void ReloadMapConfigKeyValues()
{
	if (g_MapConfig.kv == null) {
		return;
	}
	
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
				
				if (g_MapConfig.SpawnPoints == null)
					g_MapConfig.SpawnPoints = new ArrayList(sizeof(SpawnPoint));
				
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
	if (g_MapConfig.kv == null) {
		return;
	}
	
	g_MapConfig.kv.Rewind();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "/configs/instagib_maps/%s.cfg", GetMapName());
	g_MapConfig.kv.ExportToFile(path);
}

void CreateSpawnPoint(TFTeam team, float pos[3], float rotation)
{
	if (g_MapConfig.kv == null) {
		g_MapConfig.SpawnPoints = new ArrayList(sizeof(SpawnPoint));
		g_MapConfig.kv = new KeyValues("Instagib Map Config");
		g_MapConfig.kv.SetNum("Disable Music", 0);
	}
	
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
		DispatchSpawn(ent);
		TeleportEntity(ent, pos, ang, NULL_VECTOR);
	}
}

void DeleteSpawnPoint(TFTeam team, float pos[3])
{
	if (g_MapConfig.kv == null) {
		return;
	}
	
	g_MapConfig.kv.Rewind();
	g_MapConfig.kv.JumpToKey("Instagib Map Config");
	g_MapConfig.kv.JumpToKey("Spawn Points");
	if (g_MapConfig.kv.GotoFirstSubKey(false)) {
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
	if (g_MapConfig.SpawnPoints == null || !g_MapConfig.SpawnPoints.Length) {
		return;
	}
	
	int max = GetMaxEntities();
	for (int i = 1; i <= max; i++) {
		if (IsValidEntity(i)) {
			char classname[255];
			GetEntityClassname(i, classname, sizeof(classname));
			
			if (StrEqual(classname, "info_player_teamspawn")) {
				AcceptEntityInput(i, "Kill");
			}
		}
	}
	
	int len = g_MapConfig.SpawnPoints.Length;
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
			DispatchSpawn(ent);
			TeleportEntity(ent, pos, ang, NULL_VECTOR);
		}
	}
	
	RequestFrame(Frame_RespawnAll);
}

public void Frame_RespawnAll(any data)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			TF2_RespawnPlayer(i);
		}
	}
}

// -------------------------------------------------------------------
void ToggleEditMode(int client)
{
	static bool in_editmode;
	
	if (!in_editmode) {
		in_editmode = true;
		
		int max = GetMaxEntities();
		for (int i = 1; i <= max; i++) {
			if (IsValidEntity(i)) {
				char classname[255];
				GetEntityClassname(i, classname, sizeof(classname));
				
				if (StrEqual(classname, "info_player_teamspawn")) {
					int ent  = CreateEntityByName("prop_dynamic_override");
					if (ent) {
						float pos[3];
						float ang[3];
						
						GetEntPropVector(i, Prop_Data, "m_vecOrigin", pos);
						GetEntPropVector(i, Prop_Data, "m_angAbsRotation", ang);
						
						char name[128];
						FormatEx(name, sizeof(name), "INSTAGIB_SPAWNPOINT:%i", i);
						SetEntPropString(ent, Prop_Data, "m_iName", name);
						
						SetEntityModel(ent, "models/items/ammopack_large.mdl");
						SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
						SetEntityRenderColor(ent, GetEntProp(i, Prop_Data, "m_iTeamNum") == 2 ? 255 : 0, 0, GetEntProp(i, Prop_Data, "m_iTeamNum") == 2 ? 0 : 255);
						
						SetEntProp(ent, Prop_Data, "m_nSolidType", 0x0004 | 0x0008);
						
						DispatchSpawn(ent);
						TeleportEntity(ent, pos, ang, NULL_VECTOR);
					}
				}
			}
		}
		
		Panel_EditMode(client);
	} else {
		in_editmode = false;
		
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
}

void Panel_EditMode(int client)
{
	int red_spawns;
	int blue_spawns;
	
	int max = GetMaxEntities();
	for (int i = 1; i <= max; i++) {
		if (IsValidEntity(i)) {
			char classname[255];
			GetEntityClassname(i, classname, sizeof(classname));
			
			if (StrEqual(classname, "info_player_teamspawn")) {
				if (GetEntProp(i, Prop_Data, "m_iTeamNum") == 2) {
					++red_spawns;
				} else {
					++blue_spawns;
				}
			}
		}
	}

	Panel panel = new Panel();
	panel.DrawText("Map Config Editor");
	panel.DrawItem("Exit");
	
	panel.DrawText(" ");
	panel.DrawItem(g_MapConfig.IsMusicDisabled ? "Disable Music: Yes" : "Disable Music: No");
	
	panel.DrawText(" ");
	char text[255];
	FormatEx(text, sizeof(text), "Create RED Spawn (%i)", red_spawns);
	panel.DrawItem(text);
	FormatEx(text, sizeof(text), "Create BLU Spawn (%i)", blue_spawns);
	panel.DrawItem(text);
	
	panel.DrawText(" ");
	panel.DrawItem("Delete Spawn");
	panel.DrawItem("Export to .cfg");
	
	panel.Send(client, Panel_EditMode_Handler, 300);
	
	delete panel;
}

public int Panel_EditMode_Handler(Menu menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select) {
		switch (option) {
			case EditMode_Exit: {
				ToggleEditMode(client);
			}
			
			case EditMode_ToggleMusic: {
				g_MapConfig.IsMusicDisabled = !g_MapConfig.IsMusicDisabled;
				g_MapConfig.kv.Rewind();
				g_MapConfig.kv.SetNum("Disable Music", view_as<int>(g_MapConfig.IsMusicDisabled));
				InstagibPrintToChat(true, client, "%s music.", g_MapConfig.IsMusicDisabled ? "Disabled" : "Enabled");
			}
			
			case EditMode_CreateRed: {
				float pos[3];
				float ang[3];
				GetClientAbsOrigin(client, pos);
				GetClientEyeAngles(client, ang);
				
				CreateSpawnPoint(TFTeam_Red, pos, ang[1]);
				InstagibPrintToChat(true, client, "Created RED spawn point at {%.2f %.2f %.2f}.", pos[0], pos[1], pos[2]);
				ToggleEditMode(client);
				ToggleEditMode(client);
			}
			
			case EditMode_CreateBlue: {
				float pos[3];
				float ang[3];
				GetClientAbsOrigin(client, pos);
				GetClientEyeAngles(client, ang);
				
				CreateSpawnPoint(TFTeam_Blue, pos, ang[1]);
				InstagibPrintToChat(true, client, "Created BLU spawn point at {%.2f %.2f %.2f}.", pos[0], pos[1], pos[2]);
				ToggleEditMode(client);
				ToggleEditMode(client);
			}
			
			case EditMode_Delete: {
				float origin[3];
				float angles[3]; 
				GetClientEyePosition(client, origin);
				GetClientEyeAngles(client, angles);
				
				Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_ALL, RayType_Infinite, Trace_Railjump, client);
				if (TR_DidHit(trace)) {
					int ent = TR_GetEntityIndex(trace);
					
					char classname[128];
					GetEntityClassname(ent, classname, sizeof(classname));
					
					if (StrEqual(classname, "prop_dynamic")) {
						char name[128];
						GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
						
						if (StrContains(name, "INSTAGIB_SPAWNPOINT") == 0) {
							char exploded[2][64];
							ExplodeString(name, ":", exploded, sizeof(exploded), sizeof(exploded[]));
							
							int spawn_ent = StringToInt(exploded[1]);
							
							float pos[3];
							GetEntPropVector(spawn_ent, Prop_Data, "m_vecOrigin", pos);
							
							DeleteSpawnPoint(view_as<TFTeam>(GetEntProp(spawn_ent, Prop_Data, "m_iTeamNum")), pos);
							InstagibPrintToChat(true, client, "Deleted spawn point at {%.2f %.2f %.2f}.", pos[0], pos[1], pos[2]);
							
							AcceptEntityInput(ent, "Kill");
							AcceptEntityInput(spawn_ent, "Kill");
						}
					}
				}
				
				delete trace;
			}
			
			case EditMode_Export: {
				char path[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, path, sizeof(path), "/configs/instagib_maps/");
			
				SaveMapConfig();
				InstagibPrintToChat(true, client, "Map config for {%s} has been exported to {%s}.", GetMapName(), path);
			}
			
		}
		
		if (option != EditMode_Exit) {
			Panel_EditMode(client);
		}
	}
}