// -------------------------------------------------------------------
static char DefParticle[128];
static char HeadshotParticle[128];

static char DefSound[PLATFORM_MAX_PATH];
static char HeadshotSound[PLATFORM_MAX_PATH];

static float ExplRadius;
static float HeadshotExplRadius;

// -------------------------------------------------------------------
void SR_Explosions_Init()
{
	InstagibRound sr;
	NewInstagibRound(sr, "Directed by Michael Bay", "Players explode on death!");
	sr.MinPlayers = 8;
	sr.OnPlayerDeath = SR_Explosions_OnDeath;
	sr.OnDamageTaken = SR_Explosions_OnTakeDamage;
	
	SpecialRoundConfig_String(sr.Name, "ExplosionParticle", DefParticle, sizeof(DefParticle), "ExplosionCore_MidAir");
	SpecialRoundConfig_String(sr.Name, "ExplosionParticleHeadshot", HeadshotParticle, sizeof(HeadshotParticle), "ExplosionCore_MidAir");
	SpecialRoundConfig_String(sr.Name, "ExplosionSound", DefSound, sizeof(DefSound), "items/pumpkin_explode1.wav");
	SpecialRoundConfig_String(sr.Name, "ExplosionSoundHeadshot", HeadshotSound, sizeof(HeadshotSound), "items/pumpkin_explode1.wav");
	ExplRadius = SpecialRoundConfig_Float(sr.Name, "ExplosionRadius", 250.0);
	HeadshotExplRadius = SpecialRoundConfig_Float(sr.Name, "ExplosionRadiusHeadshot", 450.0);
	
	InstagibPrecacheSound(DefSound);
	InstagibPrecacheSound(HeadshotSound);
	
	SubmitInstagibRound(sr);
}

// -------------------------------------------------------------------
static void SR_Explosions_Explosion(int client, int victim, bool is_headshot = false)
{
	float vecOrigin[3];
	float range = ExplRadius;
	
	GetClientAbsOrigin(victim, vecOrigin);
	
	vecOrigin[2] += 50.0;
	
	if (is_headshot) {
		range = HeadshotExplRadius;
		
		Explosion(client, 1000.0, range, HeadshotParticle, HeadshotSound, vecOrigin);
	} else {
		Explosion(client, 800.0, range, DefParticle, DefSound, vecOrigin);
	} 
}

void Explosion(int activator, float damage, float radius, char[] particle, char[] sound, float origin[3])
{
	int ent = CreateEntityByName("tf_generic_bomb"), entshake = CreateEntityByName("env_shake");
	
	if (IsValidEntity(ent) && IsValidEntity(entshake))
	{
		SetEntPropFloat(ent, Prop_Data, "m_flDamage", damage);
		SetEntPropFloat(ent, Prop_Data, "m_flRadius", radius);
		SetEntPropString(ent, Prop_Data, "m_strExplodeParticleName", particle);
		SetEntPropString(ent, Prop_Data, "m_strExplodeSoundName", sound);
		SetEntProp(ent, Prop_Data, "m_nHealth", activator);

		SetEntPropFloat(entshake, Prop_Data, "m_Amplitude", damage / 64);
		SetEntPropFloat(entshake, Prop_Data, "m_Frequency", 12.0);
		SetEntPropFloat(entshake, Prop_Data, "m_Duration", 1.5);
		SetEntPropFloat(entshake, Prop_Data, "m_Radius", radius * 1.8);

		DispatchSpawn(ent);
		TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);

		DispatchSpawn(entshake);
		TeleportEntity(entshake, origin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entshake, "Enable");
		
		RequestFrame(Frame_Explosion, ent);
		RequestFrame(Frame_Shake, entshake);
	}
}

public void Frame_Explosion(int ent)
{
	if (IsValidEntity(ent)) {
		AcceptEntityInput(ent, "Detonate");
	}
}

public void Frame_Shake(int ent)
{
	if (IsValidEntity(ent)) {
		AcceptEntityInput(ent, "StartShake");
		RemoveEdict(ent);
	}
}

// -------------------------------------------------------------------
void SR_Explosions_OnDeath(Round_OnDeath_Data data)
{
	if (data.attacker > 0 && data.attacker <= MaxClients && data.victim != data.attacker) {
		SR_Explosions_Explosion(data.attacker, data.victim, data.customkill == TF_CUSTOM_HEADSHOT);
	}
}

Action SR_Explosions_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	char classname[128];
	GetEntityClassname(inflictor, classname, sizeof(classname));
	
	if (StrEqual(classname, "tf_generic_bomb") && victim > 0 && victim <= MaxClients) {
		int owner = GetEntProp(inflictor, Prop_Data, "m_nHealth");
		
		if (owner > 0 && owner <= MaxClients && IsClientInGame(owner)) {
			attacker = owner;
			
			if ((victim == owner) || (TF2_GetClientTeam(victim) == TF2_GetClientTeam(owner))) {
				damage = 0.0;
			}
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

