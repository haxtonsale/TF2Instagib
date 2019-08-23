#if defined _smtester_included
	#endinput
#endif
#define _smtester_included

// TODO: Add documentation lol

#include <profiler>

static int g_AllowedFails;
static bool g_ExitOnFinish;
static bool g_ShouldFinishOnResolve;

static ArrayList g_Tasks; 
static StringMap g_AsyncTasks;
static Profiler g_Profiler;

enum SMTester_TaskType
{
	TaskType_Node,
	TaskType_GoBack,
	TaskType_Assert,
	TaskType_AsyncAssert_Pending,
	TaskType_AsyncAssert_TimedOut,
	TaskType_AsyncAssert_Finished,
}

enum struct SMTester_Task
{
	SMTester_TaskType type;
	char name[64];
	any expect;
	
	any result;
	char reject_reason[256];
}

stock void SMTester_Start(int allowed_fails = 0, bool exit_on_finish = false)
{
	g_AllowedFails = allowed_fails;
	g_ExitOnFinish = exit_on_finish;
	
	g_Tasks = new ArrayList(sizeof(SMTester_Task));
	g_AsyncTasks = new StringMap();
	
	g_Profiler = new Profiler();
	g_Profiler.Start();
}

stock void SMTester_CreateNode(const char[] name)
{
	SMTester_Task task;
	task.type = TaskType_Node;
	strcopy(task.name, sizeof(task.name), name);
	
	g_Tasks.PushArray(task);
}

stock bool SMTester_GoBack(int times = 1)
{
	SMTester_Task task;
	task.type = TaskType_GoBack;
	task.result = times;
	
	g_Tasks.PushArray(task);
}

stock void SMTester_Assert(const char[] name, any value, any expect = true, const char[] reject_reason = "", any ...)
{
	SMTester_Task task;
	task.type = TaskType_Assert;
	task.expect = expect;
	task.result = value;
	strcopy(task.name, sizeof(task.name), name);
	
	char reject[256];
	VFormat(reject, sizeof(reject), reject_reason, 5);
	strcopy(task.reject_reason, sizeof(task.reject_reason), reject);
	
	g_Tasks.PushArray(task);
}

// name must be unique.
stock void SMTester_Async(const char[] name, any expect = true, float timeout = 120.0)
{
	SMTester_Task task;
	task.type = TaskType_AsyncAssert_Pending;
	strcopy(task.name, sizeof(task.name), name);
	task.expect = expect;
	
	int index = g_Tasks.PushArray(task);
	g_AsyncTasks.SetValue(name, index);
	CreateTimer(timeout, SMTester_Timer_AsyncTimeout, index);
}

stock void SMTester_AsyncAssert(const char[] name, any result, const char[] reject_reason = "", any ...)
{
	int index;
	if (g_AsyncTasks.GetValue(name, index)) {
		SMTester_Task task;
		g_Tasks.GetArray(index, task);
		task.type = TaskType_AsyncAssert_Finished;
		task.result = result;
		
		char reject[256];
		VFormat(reject, sizeof(reject), reject_reason, 4);
		strcopy(task.reject_reason, sizeof(task.reject_reason), reject);
		
		g_Tasks.SetArray(index, task);
		g_AsyncTasks.Remove(name);
		
		CheckTasks();
	}
}

stock void SMTester_Finish()
{
	int tests;
	int fails;
	int currentnode = -1;
	
	if (!g_ShouldFinishOnResolve) {
		int len = g_Tasks.Length;
		for (int i = 0; i < len; i ++) {
			SMTester_Task task;
			g_Tasks.GetArray(i, task);
			
			if (task.type == TaskType_AsyncAssert_Pending) {
				g_ShouldFinishOnResolve = true;
				return;
			}
		}
	}
	
	PrintToServer("\nTest results: %i fails allowed", g_AllowedFails);
	
	int len = g_Tasks.Length;
	for (int i = 0; i < len; i ++) {
		SMTester_Task task;
		g_Tasks.GetArray(i, task);
		
		switch (task.type) {
			case (TaskType_Node): {
				++currentnode;
				PrintToServer("%s%s", GetPadding(currentnode), task.name);
				++currentnode;
			}
			
			case (TaskType_GoBack): {
				currentnode -= task.result*2;
			}
			
			case (TaskType_Assert): {
				++tests;
				
				if (task.result != task.expect) {
					++fails;
					
					char reject_msg[256];
					if (task.reject_reason[0] != '\0') {
						strcopy(reject_msg, sizeof(reject_msg), task.reject_reason);
					} else {
						FormatEx(reject_msg, sizeof(reject_msg), "Expected %i, got %i", task.expect, task.result);
					}
					
					PrintToServer("%s(-) %s: %s", GetPadding(currentnode), task.name, reject_msg);
				} else {
					PrintToServer("%s(+) %s", GetPadding(currentnode), task.name);
				}
			}
			
			case (TaskType_AsyncAssert_TimedOut): {
				++tests;
				++fails;
				
				PrintToServer("%s(-) %s: Timed out", GetPadding(currentnode), task.name);
			}
			
			case (TaskType_AsyncAssert_Finished): {
				++tests;
				
				if (task.result != task.expect) {
					++fails;
					
					char reject_msg[64];
					if (task.reject_reason[0] != '\0') {
						strcopy(reject_msg, sizeof(reject_msg), task.reject_reason);
					} else {
						FormatEx(reject_msg, sizeof(reject_msg), "Expected %i, got %i", task.expect, task.result);
					}
					
					PrintToServer("%s(-) %s: %s", GetPadding(currentnode), task.name, reject_msg);
				} else {
					PrintToServer("%s(+) %s", GetPadding(currentnode), task.name);
				}
			}
		}
	}
	
	g_Profiler.Stop();
	
	PrintToServer("\n%i %s passing (%ims)", tests - fails, tests - fails == 1 ? "test" : "tests", RoundFloat(g_Profiler.Time*1000.0));
	
	if (fails) {
		PrintToServer("%i %s failing", fails, fails == 1 ? "test" : "tests");
	}
	
	PrintToServer(" ");
	
	if (fails > g_AllowedFails) {
		Exit(1);
		SetFailState("%i Failed %s", fails, fails == 1 ? "Test" : "Tests");
	} else {
		Exit(0);
	}
	
	delete g_Tasks;
	delete g_AsyncTasks;
	delete g_Profiler;
}

static stock char GetPadding(int nodes)
{
	char padding[256];
	
	for (int i = 0; i < nodes; i++) {
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

static stock void CheckTasks()
{
	if (g_ShouldFinishOnResolve) {
		int len = g_Tasks.Length;
		for (int i = 0; i < len; i ++) {
			SMTester_Task task;
			g_Tasks.GetArray(i, task);
			
			// If we still have pending tasks, finish when all of them are finished/timed out
			if (task.type == TaskType_AsyncAssert_Pending) {
				return;
			}
		}
		SMTester_Finish();
	}
}

public Action SMTester_Timer_AsyncTimeout(Handle timer, int index)
{
	if (g_Tasks != null) {
		SMTester_Task task;
		g_Tasks.GetArray(index, task);
		if (task.type != TaskType_AsyncAssert_Finished) {
			task.type = TaskType_AsyncAssert_TimedOut;
			g_Tasks.SetArray(index, task);
			
			CheckTasks();
		}
	}
}