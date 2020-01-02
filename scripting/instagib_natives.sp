#include <sourcemod>
#include <instagib>

public void IG_OnMapConfigLoad()
{
	InstagibRound test;
	IG_InitializeSpecialRound(test, "Test Round", "Test Description");
	test.PointsPerKill = 2;
	test.RoundTime = 300;
	IG_SubmitSpecialRound(test);
}