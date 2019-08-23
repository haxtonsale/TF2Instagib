// -------------------------------------------------------------------
#if defined RUN_TESTS
void Instagib_StartTests()
{
	ServerCommand("sv_cheats 1");
	SMTester_Start(0, false);
	
	SMTester_CreateNode("Instagib");
	
	SMTester_CreateNode("Utility");
	char text[256];
	SMTester_Assert("GetMapName", Test_GetMapName(text), _, "\"%s\" != \"koth_nucleus\"", text);
	SMTester_Assert("InstagibProcessString", Test_StringProcess(text), _, "Text was not processed correctly \"%s\"", text);
	
	SMTester_GoBack();
	SMTester_CreateNode("Gameplay");
	
	SMTester_CreateNode("General");
	SMTester_Async("Round Score");
	//SMTester_Async("Round Win");
	//SMTester_Async("Round Win at round time end");
	//SMTester_Async("Stalemate at round time end");
	Test_GeneralTests(0);
	
	SMTester_GoBack();
	SMTester_CreateNode("Directed by Michael Bay");
	//SMTester_Async("Explosion kills");
	
	SMTester_GoBack();
	SMTester_CreateNode("Limited Lives/Lifestealers");
	//SMTester_Async("Life lost");
	//SMTester_Async("Life gained");
	//SMTester_Async("Lives lost on team change");
	//SMTester_Async("Lives lost on disconnect");
	
	SMTester_GoBack();
	SMTester_CreateNode("Freeze Tag");
	//SMTester_Async("Player Freeze");
	//SMTester_Async("Player Unfreeze");
	//SMTester_Async("Freeze Tag Round Win");
	//SMTester_Async("Freeze Tag Stalemate");
	
	SMTester_Finish();
}

static bool Test_GetMapName(char[] buffer)
{
	strcopy(buffer, 256, GetMapName());
	
	if (StrEqual(buffer, "koth_nucleus")) {
		return true;
	}
	
	return false;
}

static bool Test_StringProcess(char[] buffer)
{
	InstagibProcessString(true, "Normal text {Highligthed text} Normal text again", buffer, 256);
	
	char should_be[256];
	FormatEx(should_be, sizeof(should_be), "%s Normal text %sHighligthed text%s Normal text again", g_InstagibTag, g_Config.ChatColor_Highlight, g_Config.ChatColor);
	
	if (StrEqual(buffer, should_be)) {
		return true;
	}
	
	return false;
}

void Test_GeneralTests(int phase)
{
	switch (phase) {
		case 0: {
			ServerCommand("bot -count 8");
			ServerCommand("forceround Team Deathmatch");
		}
	}
}
#endif