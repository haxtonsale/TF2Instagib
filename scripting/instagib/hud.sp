// -------------------------------------------------------------------
static Handle HudSync;

// -------------------------------------------------------------------
void Hud_Init()
{
	HudSync = CreateHudSynchronizer();
	CreateTimer(0.10, Timer_DisplayHudText, _, TIMER_REPEAT);
}

// -------------------------------------------------------------------
public Action Timer_DisplayHudText(Handle timer)
{
	if (g_IsRoundActive) {
		float x = g_Config.HudTextX;
		float y = g_Config.HudTextY;
		
		int color[4];
		color[0] = g_Config.HudTextColor[0];
		color[1] = g_Config.HudTextColor[1];
		color[2] = g_Config.HudTextColor[2];
		color[3] = g_Config.HudTextColor[3];
		
		SetHudTextParams(x, y, 0.2, color[0], color[1], color[2], color[3], 0, 0.0, 0.0, 0.0);
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				char kills[64];
				
				kills = InstagibHudPlayerInfo(i);
				ShowSyncHudText(i, HudSync, "%s\n%s%s", kills, g_RoundHudTextFormatted, g_RoundTimeLeftFormatted);
			}
		}
	}

	return Plugin_Continue;
}