// -------------------------------------------------------------------
void Menu_Main(int client)
{
	Menu menu = new Menu(MenuMain_Handler);
	
	menu.SetTitle("TF2Instagib v%s", INSTAGIB_VERSION);
	
	menu.AddItem("exit", "Exit");
	menu.AddItem("settings", "Settings");
	
	if (CheckCommandAccess(client, "forceround", ADMFLAG_CHEATS)) {
		menu.AddItem("forceround", "Force Special Round");
		menu.AddItem("reloadcfg", "Reload Config");
	}
	
	menu.AddItem("credits", "Credits");
	menu.ExitButton = false;
	menu.Display(client, 60);
}

void Credits(int client)
{
	Panel panel = new Panel();
	
	char igtext[128];
	FormatEx(igtext, sizeof(igtext), "TF2Instagib v%s", INSTAGIB_VERSION);
	panel.DrawText(igtext);
	panel.DrawText("Made by Haxton Sale (76561197999759379)");
	
	panel.DrawText(" ");
	
	panel.DrawText("Source code is available at");
	panel.DrawText("https://github.com/haxtonsale/TF2Instagib");
	
	panel.DrawItem("Back");
	
	panel.Send(client, Credits_Handler, 60);
	
	delete panel;
}

// -------------------------------------------------------------------
public int MenuMain_Handler(Menu menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(option, info, sizeof(info));
		
		if (StrEqual(info, "settings")) {
			Menu_Settings(client);
		} else if (StrEqual(info, "forceround")) {
			ClientCommand(client, "forceround");
		} else if (StrEqual(info, "credits")) {
			Credits(client);
		} else if (StrEqual(info, "reloadcfg")) {
			ClientCommand(client, "instagibcfg");
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
}

public int Credits_Handler(Menu menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select) {
		Menu_Main(client);
	}
}