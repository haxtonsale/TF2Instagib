// -------------------------------------------------------------------
void SR_Headshots_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Headshots Only", "Railgun's fire rate is increased, but you can only kill with headshots!");
	sr.RoundTime = 180;
	sr.MinPlayers = 6;
	sr.MainWeapon = SR_Headshots_Railgun();
	
	sr.OnTraceAttack = SR_Headshots_OnAttack;
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
static Handle SR_Headshots_Railgun()
{
	Handle hndl = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	
	TF2Items_SetClassname(hndl, "tf_weapon_revolver");
	TF2Items_SetItemIndex(hndl, 527);
	TF2Items_SetLevel(hndl, 1);
	TF2Items_SetQuality(hndl, 4);
	TF2Items_SetNumAttributes(hndl, 8);
	
	TF2Items_SetAttribute(hndl, 0, 397, 1.0);   // Bullets penetrate +1 enemies
	TF2Items_SetAttribute(hndl, 1, 303, -1.0);  // no reloads
	TF2Items_SetAttribute(hndl, 2, 2, 10.0);    // +900% damage bonus
	TF2Items_SetAttribute(hndl, 3, 106, 0.0);   // +100% more accurate
	TF2Items_SetAttribute(hndl, 4, 51, 1.0);    // Crits on headshot
	TF2Items_SetAttribute(hndl, 5, 305, -1.0);  // Fires tracer rounds
	TF2Items_SetAttribute(hndl, 6, 851, 2.0);   // i am speed
	if (g_Config.EnabledKillstreaks) {
		TF2Items_SetAttribute(hndl, 7, 2025, 1.0);  // killstreak
	}
	
	return hndl;
}

void SR_Headshots_OnAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (hitbox != 0) {
		damage = 0.0;
	}
}

