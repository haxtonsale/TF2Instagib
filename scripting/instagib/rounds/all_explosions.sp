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
	
	SpecialRoundConfig_String(sr.name, "ExplosionSoundHeadshot", DefParticle, sizeof(DefParticle), "ExplosionCore_MidAir");
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
	
	TE_SpawnParticle(DefParticle, vecOrigin);
	
	if (is_headshot) {
		range = HeadshotExplRadius;
		
		TE_SpawnParticle(HeadshotParticle, vecOrigin);
		EmitSoundToAll(HeadshotSound, client);
		
		SR_Explosions_KillAllInRange(client, vecOrigin, range);
	} else {
		EmitSoundToAll(DefSound, client);
		
		SR_Explosions_KillAllInRange(client, vecOrigin, range);
	}
}

static void SR_Explosions_KillAllInRange(int client, float origin[3], float maxlen)
{
	TFTeam team = TF2_GetClientTeam(client);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i)) {
			
			if (!IsFFA && team == TF2_GetClientTeam(i)) {
				continue;
			} else {
				float pos[3];
				GetClientAbsOrigin(i, pos);
				
				float dist = GetVectorDistance(origin, pos);
				
				if (dist <= maxlen) {
					ArrayStack data = new ArrayStack();
					data.Push(i);
					data.Push(client);
					
					RequestFrame(SR_Explosions_KillAllInRange_Frame, data);
				}
			}
		}
	}
}

public void SR_Explosions_KillAllInRange_Frame(ArrayStack data)
{
	int client = data.Pop();
	int i = data.Pop();
	
	delete data;
	
	SDKHooks_TakeDamage(i, client, client, 3000.0, DMG_BLAST);
}



// -------------------------------------------------------------------
void SR_Explosions_OnDeath(Round_OnDeath_Data data)
{
	if (data.attacker > 0 && data.attacker <= MaxClients && data.victim != data.attacker) {
		SR_Explosions_Explosion(data.attacker, data.victim, data.customkill == TF_CUSTOM_HEADSHOT);
	}
}

