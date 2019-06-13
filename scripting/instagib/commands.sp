// -------------------------------------------------------------------
void Commands_Init()
{
	RegConsoleCmd("kill", Command_BlockSuicide);
	RegConsoleCmd("explode", Command_BlockSuicide);
	RegConsoleCmd("instagib", Command_Settings);
	
	RegAdminCmd("forceround", Command_ForceRound, ADMFLAG_CHEATS);
}

// -------------------------------------------------------------------
public Action Command_BlockSuicide(int client, int args)
{
	return (!g_CurrentRound.allow_killbind) ? Plugin_Handled : Plugin_Continue;
}

public Action Command_Settings(int client, int args)
{
	if (args > 0) {
		char arg1[256];
		
		GetCmdArg(1, arg1, sizeof(arg1));
		
		if (StrEqual(arg1, "viewmodel", false)) {
			char arg2[128];
			
			GetCmdArg(2, arg2, sizeof(arg2));
			
			int value = StringToInt(arg2);
			
			if (value < 0 || value > 255 || args < 2) {
				CPrintToChat(client, "%s Usage: %s/instagib viewmodel (0-255)", g_InstagibTag, g_Config.ChatColor_Highlight);
			} else {
				SetClientCookie(client, g_PrefViewmodel, arg2);
				g_ClientPrefs[client].ViewmodelAlpha = value;
				
				SetEntityRenderColor(g_MainWeaponEnt[client], .a = value);
				
				CPrintToChat(client, "%s Weapon's alpha was set to %i.", g_InstagibTag, value);
			}
			
			return Plugin_Handled;
		}
	}
	
	Menu_Settings(client);
	
	return Plugin_Handled;
}

public Action Command_ForceRound(int client, int args)
{
	if (!args) {
		Rounds_Menu(client, "Select a Round", ForceRound_Handler);
	} else {
		char argstr[128];
		
		GetCmdArgString(argstr, sizeof(argstr));
		
		bool result = InstagibForceRound(argstr, true, client);
		
		if (!result) {
			CPrintToChat(client, "%s Round \"%s\" was not found!", g_InstagibTag, argstr);
		}
	}
	
	return Plugin_Handled;
}