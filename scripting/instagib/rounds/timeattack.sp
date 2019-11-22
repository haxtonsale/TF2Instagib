// -------------------------------------------------------------------
void SR_TimeAttack_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Time Attack");
	sr.RoundTime = 180;
	sr.MinScore = 322;
	sr.MaxScoreMultiplier = 0.0;
	sr.OnDescriptionPrint = SR_TimeAttack_Description;
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
void SR_TimeAttack_Description(char[] Desc, int maxlength)
{
	FormatEx(Desc, maxlength, "Get as much kills as you can in {%i} minutes!", g_CurrentRound.RoundTime/60);
}