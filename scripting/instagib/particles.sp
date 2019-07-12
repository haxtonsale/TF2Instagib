// -------------------------------------------------------------------
enum ParticleAttachment_t
{
	PATTACH_ABSORIGIN = 0,			// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,		// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,			// Create at a custom origin, but don't follow
	PATTACH_POINT,					// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW,			// Create on attachment point, and update to follow the entity
	
	PATTACH_WORLDORIGIN,			// Used for control points that don't attach to an entity
	PATTACH_ROOTBONE_FOLLOW, 		// Create at the root bone of the entity, and update to follow
}

enum TE_AttachParticle_SendTo
{
	TE_ToAll = 0,
	TE_ToOne,
	TE_ToAllButOne
}

static StringMap CachedParticles;

// -------------------------------------------------------------------
void TE_SpawnParticle(char[] particle_name, float vecOrigin[3], float vecStart[3] = NULL_VECTOR, float vecAngles[3] = NULL_VECTOR) 
{
	int strindx = FindParticle(particle_name);
	
	TE_Start("TFParticleEffect");
	TE_WriteNum("m_iParticleSystemIndex", strindx);
	
	TE_WriteFloat("m_vecOrigin[0]", vecOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vecOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vecOrigin[2]);
	
	TE_WriteFloat("m_vecStart[0]", vecStart[0]);
	TE_WriteFloat("m_vecStart[1]", vecStart[1]);
	TE_WriteFloat("m_vecStart[2]", vecStart[2]);
	
	TE_WriteVector("m_vecAngles", vecAngles); // doesn't do shit?
	
	TE_SendToAll();
}

void TE_AttachParticle(int entity, char[] particle_name, ParticleAttachment_t attachtype, int attachpoint, bool reset = false, TE_AttachParticle_SendTo sendto = TE_ToAll, int client = 0) 
{
	int strindx = FindParticle(particle_name);
	
	TE_Start("TFParticleEffect");
	TE_WriteNum("m_iParticleSystemIndex", strindx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", view_as<int>(attachtype));
	TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
	TE_WriteNum("m_bResetParticles", view_as<int>(reset));
	
	if (sendto == TE_ToAll) {
		TE_SendToAll();
	} else if (sendto == TE_ToOne) {
		TE_SendToClient(client);
	} else if (sendto == TE_ToAllButOne) {
		int count;
		int[] clients = new int[MaxClients];
		
		for (int i = 1; i <= MaxClients; i++) {
			if (i != client && IsClientInGame(i)) {
				clients[count] = i;
				++count;
			}
		}
		
		TE_Send(clients, count);
	}
}

// -------------------------------------------------------------------
int FindParticle(char[] particle_name, bool after_precache = false)
{
	if (CachedParticles == null) {
		CachedParticles = new StringMap();
	}
	
	int cached;
	if (CachedParticles.GetValue(particle_name, cached)) {
		return cached;
	}
	
	int StringTableIndex = FindStringTable("ParticleEffectNames");
	int StringTableNumStrings = GetStringTableNumStrings(StringTableIndex);
	
	int strindx = -1;
	
	for (int i = 0; i < StringTableNumStrings; i++) {
		char name[256];
		ReadStringTable(StringTableIndex, i, name, sizeof(name));
		
		if (StrEqual(particle_name, name, false)) {
			strindx = i;
			break;
		}
	}
	
	if (strindx == -1) {
		if (!after_precache) {
			PrecacheParticleSystem(particle_name);
			strindx = FindParticle(particle_name, true);
		} else {
			LogError("Couldn't find particle %s", particle_name);
			return 0;
		}
	}
	
	CachedParticles.SetValue(particle_name, strindx);
	return strindx;
}

// -------------------------------------------------------------------
// yoinked from some alliedmodders thread, don't remember which one
stock int PrecacheParticleSystem(const char[] particleSystem)
{
    static int particleEffectNames = INVALID_STRING_TABLE;

    if (particleEffectNames == INVALID_STRING_TABLE) {
        if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
            return INVALID_STRING_INDEX;
        }
    }

    int index = FindStringIndex2(particleEffectNames, particleSystem);
    if (index == INVALID_STRING_INDEX) {
        int numStrings = GetStringTableNumStrings(particleEffectNames);
        if (numStrings >= GetStringTableMaxStrings(particleEffectNames)) {
            return INVALID_STRING_INDEX;
        }
        
        AddToStringTable(particleEffectNames, particleSystem);
        index = numStrings;
    }
    
    return index;
}

stock int FindStringIndex2(int tableidx, const char[] str)
{
    char buf[1024];
    
    int numStrings = GetStringTableNumStrings(tableidx);
    for (int i=0; i < numStrings; i++) {
        ReadStringTable(tableidx, i, buf, sizeof(buf));
        
        if (StrEqual(buf, str)) {
            return i;
        }
    }
    
    return INVALID_STRING_INDEX;
}
