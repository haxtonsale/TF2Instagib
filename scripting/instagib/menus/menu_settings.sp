// -------------------------------------------------------------------
void Menu_Settings(int client)
{
	if (AreClientCookiesCached(client)) {
		Menu menu = new Menu(Settings_Handler);
		
		menu.SetTitle("Settings");
		menu.AddItem("back", "Back");
		
		if (!g_MapConfig.IsMusicDisabled) {
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
public int Settings_Handler(Menu menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(option, info, sizeof(info));
		
		if (StrEqual(info, "back")) {
			Menu_Main(client);
		} else {
			if (StrContains(info, "music") != -1) {
				char exploded[2][64];
				ExplodeString(info, ":", exploded, sizeof(exploded), sizeof(exploded[]));
				
				g_PrefMusic.Set(client, exploded[1]);
				
				bool result = view_as<bool>(StringToInt(exploded[1]));
				g_ClientPrefs[client].EnabledMusic = result;
				
				if (result) {
					InstagibPrintToChat(true, client, "You have enabled round music.");
					g_ClientPrefs[client].EnabledMusic = true;
				} else {
					InstagibPrintToChat(true, client, "You have disabled round music.");
					g_ClientPrefs[client].EnabledMusic = false;
					StopMusic(client);
				}
			} else if (StrEqual(info, "viewmodel")) {
				InstagibPrintToChat(true, client,  "Type {/instagib viewmodel (0-255)} to change weapon's transparency.");
			} else if (StrContains(info, "bhop") != -1) {
				char exploded[2][64];
				ExplodeString(info, ":", exploded, sizeof(exploded), sizeof(exploded[]));
				
				g_PrefBhop.Set(client, exploded[1]);
				
				bool result = view_as<bool>(StringToInt(exploded[1]));
				g_ClientPrefs[client].EnabledBhop = result;
				
				if (result) {
					InstagibPrintToChat(true, client, "You have enabled Auto Bhop.");
					g_ClientPrefs[client].EnabledBhop = true;
				} else {
					InstagibPrintToChat(true, client, "You have disabled Auto Bhop.");
					g_ClientPrefs[client].EnabledBhop = false;
				}
			}
			
			Menu_Settings(client);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
}