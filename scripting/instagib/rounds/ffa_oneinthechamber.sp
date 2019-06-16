// -------------------------------------------------------------------
static Handle Gauntlet;

// -------------------------------------------------------------------
void SR_OITC_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "One in The Chamber", "You start with only one bullet! Kill players to get more ammo!");
	sr.roundtype_flags = ROUNDTYPE_FFA;
	sr.round_time = 300;
	sr.main_wep_clip = 1;
	sr.infinite_ammo = false;
	sr.maxscore_multi = 0.5;
	sr.respawn_time = 5.0;
	sr.min_players_ffa = 8;
	sr.on_start = SR_OITC_OnStart;
	sr.on_inv = SR_OITC_OnInv;
	sr.on_death = SR_OITC_OnDeath;
	
	Gauntlet = SR_OITC_CreateGauntlet();
	
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
static Handle SR_OITC_CreateGauntlet()
{
	Handle hndl = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hndl, "tf_weapon_shovel");
	TF2Items_SetItemIndex(hndl, 452);
	TF2Items_SetLevel(hndl, 42);
	TF2Items_SetQuality(hndl, 4);
	TF2Items_SetNumAttributes(hndl, 3);
	
	TF2Items_SetAttribute(hndl, 0, 6, 0.4);		// Faster firing speed
	TF2Items_SetAttribute(hndl, 1, 851, 1.9);	// i am speed
	TF2Items_SetAttribute(hndl, 2, 15, -1.0);	// no random crits
	
	return hndl;
}

void SR_OITC_OnStart()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientPlaying(i) && IsPlayerAlive(i)) {
			GiveWeapon(i, Gauntlet, false);
		}
	}
}

void SR_OITC_OnInv(int client)
{
	if (g_ClientSuicided[client]) {
		SR_OITC_AddAmmo(client, -1);
	}
	
	GiveWeapon(client, Gauntlet);
}

void SR_OITC_OnDeath(Round_OnDeath_Data data)
{
	if (data.attacker > 0 && data.attacker <= MaxClients && data.victim != data.attacker) {
		int amount = (data.customkill == TF_CUSTOM_HEADSHOT) ? 2 : 1;
		SR_OITC_AddAmmo(data.attacker, amount);
	}
}

static void SR_OITC_AddAmmo(int client, int amount)
{
	if (IsValidEntity(g_MainWeaponEnt[client])) {
		int ammo = GetEntProp(g_MainWeaponEnt[client], Prop_Data, "m_iClip1");
		
		SetEntProp(g_MainWeaponEnt[client], Prop_Data, "m_iClip1", ammo+amount);
	}
}