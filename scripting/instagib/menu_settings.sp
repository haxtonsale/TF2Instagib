// -------------------------------------------------------------------
void Menu_Settings(int client)
{
	if (AreClientCookiesCached(client)) {
		Menu menu = new Menu(Settings_Handler);
		
		menu.SetTitle("TF2Instagib %s", INSTAGIB_VERSION);
		
		if (g_ClientPrefs[client].MusicEnabled) {
			menu.AddItem("music:0", "Music: On");
		} else {
			menu.AddItem("music:1", "Music: Off");
		}
		
		int trans = g_ClientPrefs[client].ViewmodelAlpha;
		char str[64];
		
		FormatEx(str, sizeof(str), "Viewmodel Visibility: %i%%", RoundFloat(float(trans)/255.0*100.0));
		menu.AddItem("viewmodel", str);
		
		menu.Display(client, 60);
	}
}

// -------------------------------------------------------------------
public int Settings_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		
		if (StrContains(info, "music") != -1) {
			char exploded[2][64];
			
			ExplodeString(info, ":", exploded, sizeof(exploded), 64);
			
			SetClientCookie(param1, g_PrefMusic, exploded[1]);
			
			bool result = view_as<bool>(StringToInt(exploded[1]));
			g_ClientPrefs[param1].MusicEnabled = result;
			
			if (result) {
				CPrintToChat(param1, "%s You have enabled round music.", g_InstagibTag);
				g_ClientPrefs[param1].MusicEnabled = true;
			} else {
				CPrintToChat(param1, "%s You have disabled round music.", g_InstagibTag);
				g_ClientPrefs[param1].MusicEnabled = false;
				StopMusic(param1);
			}
		} else if (StrEqual(info, "viewmodel")) {
			CPrintToChat(param1, "%s Type %s/instagib viewmodel (0-255)%s to change weapon's transparency.", g_InstagibTag, g_Config.ChatColor_Highlight, g_Config.ChatColor);
		}
		
		Menu_Settings(param1);
	} else if (action == MenuAction_End) {
		delete menu;
	}
}