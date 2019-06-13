// -------------------------------------------------------------------
public int ForceRound_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select) {
		char info[256];
		
		menu.GetItem(param2, info, sizeof(info));
		
		InstagibForceRound(info, true, param1);
	} else if (action == MenuAction_End) {
		delete menu;
	}
}