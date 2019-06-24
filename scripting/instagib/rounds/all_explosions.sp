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
	sr.min_players_tdm = 8;
	sr.min_players_ffa = 4;
	sr.on_death = SR_Explosions_OnDeath;
	sr.on_damage = SR_Explosions_OnTakeDamage;
	
	SpecialRoundConfig_String(sr.name, "ExplosionParticle", DefParticle, sizeof(DefParticle), "ExplosionCore_MidAir");
	SpecialRoundConfig_String(sr.name, "ExplosionParticleHeadshot", HeadshotParticle, sizeof(HeadshotParticle), "ExplosionCore_MidAir");
	SpecialRoundConfig_String(sr.name, "ExplosionSound", DefSound, sizeof(DefSound), "items/pumpkin_explode1.wav");
	SpecialRoundConfig_String(sr.name, "ExplosionSoundHeadshot", HeadshotSound, sizeof(HeadshotSound), "items/pumpkin_explode1.wav");
	ExplRadius = SpecialRoundConfig_Float(sr.name, "ExplosionRadius", 250.0);
	HeadshotExplRadius = SpecialRoundConfig_Float(sr.name, "ExplosionRadiusHeadshot", 450.0);
	
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
	int ent = CreateEntityByName("tf_generic_bomb");
	
	if (IsValidEntity(ent))
	{
		SetEntPropFloat(ent, Prop_Data, "m_flDamage", damage);
		SetEntPropFloat(ent, Prop_Data, "m_flRadius", radius);
		SetEntPropString(ent, Prop_Data, "m_strExplodeParticleName", particle);
		SetEntPropString(ent, Prop_Data, "m_strExplodeSoundName", sound);
		SetEntProp(ent, Prop_Data, "m_nHealth", activator);
		DispatchSpawn(ent);
		TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
		
		RequestFrame(Frame_Explosion, ent);
	}
}

public void Frame_Explosion(int ent)
{
	if (IsValidEntity(ent)) {
		AcceptEntityInput(ent, "Detonate");
	}
}

// -------------------------------------------------------------------
void SR_Explosions_OnDeath(Round_OnDeath_Data data)
{
	if (data.attacker > 0 && data.attacker <= MaxClients && data.victim != data.attacker) {
		SR_Explosions_Explosion(data.attacker, data.victim, data.customkill == TF_CUSTOM_HEADSHOT);
	}
}

Action SR_Explosions_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
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

