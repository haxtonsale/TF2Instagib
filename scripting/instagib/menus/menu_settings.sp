// -------------------------------------------------------------------
void Menu_Settings(int client)
{
	if (AreClientCookiesCached(client)) {
		Menu menu = new Menu(Settings_Handler);
		
		menu.SetTitle("Settings");
		menu.AddItem("back", "Back");
		
		if (g_MusicEnabled) {
			if (g_ClientPrefs[client].MusicEnabled) {
				menu.AddItem("music:0", "Music: On");
			} else {
				menu.AddItem("music:1", "Music: Off");
			}
		}
		
		int trans = g_ClientPrefs[client].ViewmodelAlpha;
		char str[64];
		
		FormatEx(str, sizeof(str), "Viewmodel Visibility: %i%%", RoundFloat(float(trans)/255.0*100.0));
		menu.AddItem("viewmodel", str);
		
		menu.ExitButton = false;
		menu.Display(client, 60);
	}
}

// -------------------------------------------------------------------
public int Settings_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrEqual(info, "back")) {
			Menu_Main(param1);
		} else {
			if (StrContains(info, "music") != -1) {
				char exploded[2][64];
				
				ExplodeString(info, ":", exploded, sizeof(exploded), 64);
				
				SetClientCookie(param1, g_PrefMusic, exploded[1]);
				
				bool result = view_as<bool>(StringToInt(exploded[1]));
				g_ClientPrefs[param1].MusicEnabled = result;
				
				if (result) {
					InstagibPrintToChat(true, param1, "You have enabled round music.");
					g_ClientPrefs[param1].MusicEnabled = true;
				} else {
					InstagibPrintToChat(true, param1, "You have disabled round music.");
					g_ClientPrefs[param1].MusicEnabled = false;
					StopMusic(param1);
				}
			} else if (StrEqual(info, "viewmodel")) {
				InstagibPrintToChat(true, param1,  "Type {/instagib viewmodel (0-255)} to change weapon's transparency.");
			}
			
			Menu_Settings(param1);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
}