// -------------------------------------------------------------------
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
				char name[128];
				GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
				
				if (StrContains(name, "INSTAGIB_SPAWNPOINT") == 0) {
					if (GetEntProp(i, Prop_Data, "m_iTeamNum") == 2) {
						++red_spawns;
					} else {
						++blue_spawns;
					}
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
	
	panel.Send(client, Panel_EditMode_Handler, -1);
	
	delete panel;
}

// -------------------------------------------------------------------
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
			}
			
			case EditMode_CreateBlue: {
				float pos[3];
				float ang[3];
				GetClientAbsOrigin(client, pos);
				GetClientEyeAngles(client, ang);
				
				CreateSpawnPoint(TFTeam_Blue, pos, ang[1]);
				InstagibPrintToChat(true, client, "Created BLU spawn point at {%.2f %.2f %.2f}.", pos[0], pos[1], pos[2]);
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
							
							AcceptEntityInput(spawn_ent, "Kill");
						}
					}
				}
				
				delete trace;
			}
			
			case EditMode_Export: {
				char path[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps/");
			
				SaveMapConfig();
				InstagibPrintToChat(true, client, "Map config for {%s} has been exported to {%s}.", GetMapName(), path);
			}
			
		}
		
		if (option != EditMode_Exit) {
			ReloadSpawnPointEnts();
			Panel_EditMode(client);
		}
	}
}