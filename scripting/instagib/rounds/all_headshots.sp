// -------------------------------------------------------------------
void SR_Headshots_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Headshots Only", "Players can only be killed on headshots!");
	sr.round_time = 210;
	sr.on_attack = SR_Headshots_OnAttack;
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
void SR_Headshots_OnAttack(int victim, int &attacker, int &inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	if (hitbox != 0) {
		damage = 0.0;
	}
}