// -------------------------------------------------------------------
void Menu_ForceRound(int client, char[] title)
{
	Menu menu = new Menu(ForceRound_Handler);
	
	menu.SetTitle(title);
	menu.AddItem("exit", "Exit");
	
	FillMenuWithRoundNames(menu);
	
	menu.ExitButton = false;
	menu.Display(client, 60);
}

// -------------------------------------------------------------------
public int ForceRound_Handler(Menu menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_Select) {
		char info[256];
		
		menu.GetItem(option, info, sizeof(info));
		
		if (!StrEqual(info, "exit")) {
			InstagibForceRound(info, true, client);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}