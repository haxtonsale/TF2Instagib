// -------------------------------------------------------------------
void SR_TimeAttack_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Time Attack");
	sr.round_time = 180;
	sr.minscore = 322;
	sr.maxscore_multi = 0.0;
	sr.on_desc = SR_TimeAttack_Description;
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
void SR_TimeAttack_Description(char[] desc, int maxlength)
{
	FormatEx(desc, maxlength, "Get as much kills as you can in {%i} minutes!", g_CurrentRound.round_time/60);
}