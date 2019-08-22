#if defined _smtester_included
	#endinput
#endif
#define _smtester_included

#include <profiler>

static int g_CurrentNode = -1;

static int g_Tests;
static int g_Fails;

static int g_AllowedFails;
static bool g_ExitOnFinish;

static Handle g_Profiler;

stock void SMTester_Start(int allowed_fails = 0, bool exit_on_finish = false)
{
	g_CurrentNode = -1;
	g_Tests = 0;
	g_Fails = 0;
	delete g_Profiler;
	
	PrintToServer(" ");
	
	g_AllowedFails = allowed_fails;
	g_ExitOnFinish = exit_on_finish;
	
	g_Profiler = CreateProfiler();
	StartProfiling(g_Profiler);
}

stock void SMTester_CreateNode(const char[] name)
{
	++g_CurrentNode;
	PrintToServer("%s%s", GetPadding(), name);
	++g_CurrentNode;
}

stock bool SMTester_GoBack(int times = 1)
{
	g_CurrentNode -= 2*times;
}

stock void Assert(const char[] name, any value, any expect = true)
{
	++g_Tests;
	
	if (value != expect) {
		++g_Fails;
		
		PrintToServer("%s(-) %s: Expected %i, got %i", GetPadding(), name, value, expect);
	} else {
		PrintToServer("%s(+) %s", GetPadding(), name);
	}
}

stock void SMTester_Finish()
{
	StopProfiling(g_Profiler);
	
	PrintToServer("\n%i %s passing (%ims)", g_Tests - g_Fails, g_Tests - g_Fails == 1 ? "test" : "tests", RoundFloat(GetProfilerTime(g_Profiler)*1000.0));
	
	if (g_Fails) {
		PrintToServer("%i %s failing", g_Fails, g_Fails == 1 ? "test" : "tests");
	}
	
	PrintToServer(" ");
	
	if (g_Fails > g_AllowedFails) {
		Exit(1);
		SetFailState("%i Failed %s", g_Fails, g_Fails == 1 ? "Test" : "Tests");
	} else {
		Exit(0);
	}
}

static stock char GetPadding()
{
	char padding[256];
	
	for (int i = 0; i < g_CurrentNode; i++) {
		Format(padding, sizeof(padding), "    %s", padding);
	}
	
	return padding;
}

// Lame workaround because i can't exit srcds with code 0 through sm
static stock void Exit(int code)
{
	if (g_ExitOnFinish) {
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "/logs/test_result.txt");
		
		Handle file = OpenFile(path, "w");
		char codestr[16];
		IntToString(code, codestr, sizeof(codestr));
		WriteFileString(file, codestr, false);
		delete file;
		
		ServerCommand("exit");
	}
}