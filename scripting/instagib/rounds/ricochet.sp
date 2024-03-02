static int MaxBounces;

static int numBounces[2048];

static char ProjectileBounceSound[PLATFORM_MAX_PATH];

void SR_Ricochet_Init()
{
	InstagibRound round;
	
	// Fills the round array with default and config values
	IG_InitializeSpecialRound(round, "Ricochet", "Railguns now shoot ricocheting projectiles!");

	// Replace revolver to syringegun
	round.MainWeapon = CustomRoundRicochet_MainWeapon();

	round.OnEntCreated = CustomRoundRicochet_OnEntCreated;
	
	SpecialRoundConfig_String(round.Name, "ProjectileBounceSound", ProjectileBounceSound, sizeof(ProjectileBounceSound), "weapons/crossbow/bolt_fly4.wav");
	InstagibPrecacheSound(ProjectileBounceSound);

	// How many times should projectile bounce off from walls?
	MaxBounces = SpecialRoundConfig_Num(round.Name, "Bounces", 8);
	
	// Add the round to the list of Special Rounds. It can't be edited or removed after this.
	SubmitInstagibRound(round);
}

static Handle CustomRoundRicochet_MainWeapon()
{
	Handle hndl = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);

	TF2Items_SetClassname(hndl, "tf_weapon_shotgun_building_rescue");
	TF2Items_SetItemIndex(hndl, 527); //997
	TF2Items_SetLevel(hndl, 1);
	TF2Items_SetQuality(hndl, 4);
	TF2Items_SetNumAttributes(hndl, 9);

	TF2Items_SetAttribute(hndl, 0, 5, 1.5);     // slower firing speed
	TF2Items_SetAttribute(hndl, 1, 303, -1.0);  // no reloads
	TF2Items_SetAttribute(hndl, 2, 2, 10.0);	// +900% damage bonus
	TF2Items_SetAttribute(hndl, 3, 106, 0.0);   // +100% more accurate
	TF2Items_SetAttribute(hndl, 4, 51, 1.0);	// Crits on headshot
	TF2Items_SetAttribute(hndl, 5, 305, -1.0);  // Fires tracer rounds
	TF2Items_SetAttribute(hndl, 6, 851, 2.0);   // i am speed
	TF2Items_SetAttribute(hndl, 7, 103, 1.5);   // make projectile faster
	if (g_Config.EnabledKillstreaks) {
		TF2Items_SetAttribute(hndl, 8, 2025, 1.0);  // killstreak
	}
	return hndl;
}

public void CustomRoundRicochet_OnEntCreated(int iEntity, const char[] strClassname)
{
	if(StrEqual(strClassname, "tf_projectile_arrow"))
	{
		numBounces[iEntity] = 0;
		SDKHook(iEntity, SDKHook_StartTouch, Hook_OnStartTouch);
	}
}

public Action Hook_OnStartTouch(int iEntity, int iOther)
{
	if (iOther > 0 && iOther <= MaxClients)
		return Plugin_Continue;

	if (numBounces[iEntity] >= MaxBounces)
		return Plugin_Continue;

	SDKHook(iEntity, SDKHook_Touch, Hook_OnTouch);
	return Plugin_Handled;
}

public Action Hook_OnTouch(int iEntity)
{
	float vecOrigin[3], vecAngles[3], vecVelocity[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vecAngles);
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", vecVelocity);

	Handle Trace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilter_IgnoreEntity, iEntity);

	if (TR_GetSurfaceFlags(Trace) & SURF_SKY) 
	{
		CloseHandle(Trace);
		SDKUnhook(iEntity, SDKHook_Touch, Hook_OnTouch);
		return Plugin_Handled;
	}

	float vecNormal[3];
	TR_GetPlaneNormal(Trace, vecNormal);
	Trace.Close();
	
	float dotProduct = GetVectorDotProduct(vecNormal, vecVelocity);
	
	ScaleVector(vecNormal, dotProduct);
	ScaleVector(vecNormal, 2.0);
	
	float vecBounceVec[3];
	SubtractVectors(vecVelocity, vecNormal, vecBounceVec);
	
	float vecNewAngles[3];
	GetVectorAngles(vecBounceVec, vecNewAngles);
	
	EmitSoundToAll(ProjectileBounceSound, iEntity);
	TeleportEntity(iEntity, NULL_VECTOR, vecNewAngles, vecBounceVec);

	numBounces[iEntity]++;

	SDKUnhook(iEntity, SDKHook_Touch, Hook_OnTouch);
	return Plugin_Handled;
}

public bool TraceEntityFilter_IgnoreEntity(int entity, int mask, any data)
{
	return (entity != data);
}