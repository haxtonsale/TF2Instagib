// -------------------------------------------------------------------
#if defined RUN_TESTS
void Instagib_StartTests()
{
	SMTester_Start(0, false);
	Assert("GetMapName", Test_GetMapName());
	Assert("InstagibProcessString", Test_StringProcess());
	Instagib_EndTests();
}

void Instagib_EndTests()
{
	SMTester_Finish();
}

static bool Test_GetMapName()
{
	char name[256];
	name = GetMapName();
	
	if (StrEqual(name, "koth_nucleus")) {
		return true;
	}
	
	return false;
}

static bool Test_StringProcess()
{
	char buffer[128];
	InstagibProcessString(true, "Normal text {Highligthed text} Normal text again", buffer, sizeof(buffer));
	
	char should_be[256];
	FormatEx(should_be, sizeof(should_be), "%s Normal text %sHighligthed text%s Normal text again", g_InstagibTag, g_Config.ChatColor_Highlight, g_Config.ChatColor);
	
	if (StrEqual(buffer, should_be)) {
		return true;
	}
	
	return false;
}
#endif