// -------------------------------------------------------------------
#if defined RUN_TESTS
void Instagib_StartTests()
{
	ServerCommand("sv_cheats 1");
	SMTester_Start(0, true);
	
	SMTester_CreateNode("Instagib");
	
	SMTester_CreateNode("Utility");
	char text[256];
	SMTester_Assert("GetMapName", Test_GetMapName(text), _, "\"%s\" != \"koth_nucleus\"", text);
	SMTester_Assert("InstagibProcessString", Test_StringProcess(text), _, "Text was not processed correctly \"%s\"", text);
	
	SMTester_GoBack();
	SMTester_CreateNode("Gameplay");
	
	SMTester_CreateNode("General");
	SMTester_Async("Round score");
	SMTester_Async("Round win");
	SMTester_Async("Round win at round time end");
	SMTester_Async("Stalemate at round time end");
	Test_GameplayTests(0);
	
	SMTester_GoBack();
	SMTester_CreateNode("Directed by Michael Bay");
	//SMTester_Async("Explosion kill");
	
	SMTester_GoBack();
	SMTester_CreateNode("Limited Lives/Lifestealers");
	//SMTester_Async("Life lost");
	//SMTester_Async("Life gained");
	//SMTester_Async("Lives lost on team change");
	//SMTester_Async("Lives lost on disconnect");
	
	SMTester_GoBack();
	SMTester_CreateNode("Freeze Tag");
	//SMTester_Async("Player freeze");
	//SMTester_Async("Player unfreeze");
	//SMTester_Async("Freeze Tag win");
	//SMTester_Async("Freeze Tag stalemate");
	
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

void Test_GameplayTests(int phase)
{
	switch (phase) {
		case 0: {
			ServerCommand("bot -team blu -name blue");
			ServerCommand("bot -team red -name red");
			
			CreateTimer(36.0, Test_Timer_Test, 1);
		}
		
		case 1: {
			ServerCommand("bot_teleport red 285.732239 -727.817627 -27.968681 0.455397 -178.448944 0.000000");
			ServerCommand("bot_teleport blue 62.127514 -733.871948 -27.968681 -0.091083 -178.266785 0.000000");
			RequestFrame(Test_Frame_Test, 2);
		}
		
		case 2: {
			ServerCommand("bot_forceattack 1");
			RequestFrame(Test_Frame_Test, 3);
		}
		
		case 3: {
			ServerCommand("bot_forceattack 0");
			RequestFrame(Test_Frame_Test, 4);
		}
		
		case 4: {
			ServerCommand("forceround Time Attack");
			ServerCommand("mp_forcewin");
			CreateTimer(21.0, Test_Timer_Test, 5);
		}
		
		case 5: {
			ServerCommand("forceround Time Attack");
			ServerCommand("bot_teleport red 285.732239 -727.817627 -27.968681 0.455397 -178.448944 0.000000");
			ServerCommand("bot_teleport blue 62.127514 -733.871948 -27.968681 -0.091083 -178.266785 0.000000");
			g_RoundTimeLeft = 2;
			RequestFrame(Test_Frame_Test, 6);
		}
		
		case 6: {
			ServerCommand("bot_forceattack 1");
			RequestFrame(Test_Frame_Test, 7);
		}
		
		case 7: {
			ServerCommand("bot_forceattack 0");
			CreateTimer(20.0, Test_Timer_Test, 8);
		}
		
		case 8: {
			g_RoundTimeLeft = 2;
			//CreateTimer(1.0, Test_Timer_Test, 10);
		}
	}
}

public Action Test_Timer_Test(Handle timer, int phase)
{
	Test_GameplayTests(phase);
}

public void Test_Frame_Test(any phase)
{
	Test_GameplayTests(phase);
}
#endif