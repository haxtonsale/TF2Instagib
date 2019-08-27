// -------------------------------------------------------------------
#if defined RUN_TESTS
void Instagib_StartTests()
{
	SMTester_Start(true);
	
	SMTester_CreateNode("Instagib");
	
	SMTester_CreateNode("Utility");
	char text[256];
	SMTester_Assert("GetMapName", Test_GetMapName(text), _, "\"%s\" != \"koth_nucleus\"", text);
	SMTester_Assert("InstagibProcessString", Test_StringProcess(text), _, "Text was not processed correctly \"%s\"", text);
	
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
#endif