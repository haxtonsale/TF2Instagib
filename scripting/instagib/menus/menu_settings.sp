// -------------------------------------------------------------------
void Menu_Settings(int client)
{
	if (AreClientCookiesCached(client)) {
		Menu menu = new Menu(Settings_Handler);
		
		menu.SetTitle("Settings");
		menu.AddItem("back", "Back");
		
		if (g_MusicEnabled) {
			if (g_ClientPrefs[client].EnabledMusic) {
				menu.AddItem("music:0", "Music: On");
			} else {
				menu.AddItem("music:1", "Music: Off");
			}
		}
		
		int trans = g_ClientPrefs[client].ViewmodelAlpha;
		char str[64];
		
		FormatEx(str, sizeof(str), "Viewmodel Visibility: %i%%", RoundFloat(float(trans)/255.0*100.0));
		menu.AddItem("viewmodel", str);
		
		if (g_ClientPrefs[client].EnabledBhop) {
			menu.AddItem("bhop:0", "Auto Bhop: On");
		} else {
			menu.AddItem("bhop:1", "Auto Bhop: Off");
		}
		
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
				ExplodeString(info, ":", exploded, sizeof(exploded), exploded[]);
				
				g_PrefMusic.Set(param1, exploded[1]);
				
				bool result = view_as<bool>(StringToInt(exploded[1]));
				g_ClientPrefs[param1].EnabledMusic = result;
				
				if (result) {
					InstagibPrintToChat(true, param1, "You have enabled round music.");
					g_ClientPrefs[param1].EnabledMusic = true;
				} else {
					InstagibPrintToChat(true, param1, "You have disabled round music.");
					g_ClientPrefs[param1].EnabledMusic = false;
					StopMusic(param1);
				}
			} else if (StrEqual(info, "viewmodel")) {
				InstagibPrintToChat(true, param1,  "Type {/instagib viewmodel (0-255)} to change weapon's transparency.");
			} else if (StrContains(info, "bhop") != -1) {
				char exploded[2][64];
				ExplodeString(info, ":", exploded, sizeof(exploded), exploded[]);
				
				g_PrefBhop.Set(param1, exploded[1]);
				
				bool result = view_as<bool>(StringToInt(exploded[1]));
				g_ClientPrefs[param1].EnabledBhop = result;
				
				if (result) {
					InstagibPrintToChat(true, param1, "You have enabled Auto Bhop.");
					g_ClientPrefs[param1].EnabledBhop = true;
				} else {
					InstagibPrintToChat(true, param1, "You have disabled Auto Bhop.");
					g_ClientPrefs[param1].EnabledBhop = false;
				}
			}
			
			Menu_Settings(param1);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
}