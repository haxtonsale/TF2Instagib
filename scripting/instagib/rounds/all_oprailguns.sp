// -------------------------------------------------------------------
void SR_OPRailguns_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "OP Railguns", "Railguns are now much more powerful!");
	sr.railjump_velXY_multi = 7.0;
	sr.railjump_velZ_multi = 4.0;
	sr.spawnuber_duration = 0.2;
	sr.main_weapon = SR_OPRailguns_CreateOPRailgun();
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
static Handle SR_OPRailguns_CreateOPRailgun()
{
	Handle hndl = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	
	TF2Items_SetClassname(hndl, "tf_weapon_revolver");
	TF2Items_SetItemIndex(hndl, 527);
	TF2Items_SetLevel(hndl, 1);
	TF2Items_SetQuality(hndl, 4);
	TF2Items_SetNumAttributes(hndl, 8);
	
	TF2Items_SetAttribute(hndl, 0, 397, 1.0);	// Bullets penetrate +1 enemies
	TF2Items_SetAttribute(hndl, 1, 303, -1.0);	// no reloads
	TF2Items_SetAttribute(hndl, 2, 2, 10.0);	// +900% damage bonus
	TF2Items_SetAttribute(hndl, 3, 106, 0.0);	// +100% more accurate
	TF2Items_SetAttribute(hndl, 4, 51, 1.0);	// Crits on headshot
	TF2Items_SetAttribute(hndl, 5, 305, -1.0);	// Fires tracer rounds
	TF2Items_SetAttribute(hndl, 6, 851, 2.0);	// i am speed
	if (g_Config.EnabledKillstreaks) {
		TF2Items_SetAttribute(hndl, 7, 2025, 1.0);	// killstreak
	}
	
	return hndl;
}