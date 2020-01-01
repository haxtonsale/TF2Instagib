// -------------------------------------------------------------------
enum struct MultikillTier
{
	int kills;
	bool announce;
	char article[4];
	char name[32];
	char color[16];
	char sound[PLATFORM_MAX_PATH];
}

static float LastKill[TF2_MAXPLAYERS+1];
static int MultikillCount[TF2_MAXPLAYERS+1];
static ArrayList MultikillTiers;

// -------------------------------------------------------------------
void NewMultikillTier(int kills_required, bool announce, char[] article, char[] name, char[] color, char[] sound)
{
	if (MultikillTiers == null) {
		MultikillTiers = new ArrayList(sizeof(MultikillTier));
	}
	
	MultikillTier tier;
	
	tier.kills = kills_required;
	tier.announce = announce;
	strcopy(tier.article, sizeof(tier.article), article);
	strcopy(tier.name, sizeof(tier.name), name);
	strcopy(tier.color, sizeof(tier.color), color);
	strcopy(tier.sound, sizeof(tier.sound), sound);
	
	if (sound[0] != '\0') {
		InstagibPrecacheSound(sound);
	}
	
	MultikillTiers.PushArray(tier);
}

int GetClientMultikill(int client)
{
	if (GetEngineTime() - LastKill[client] >= g_Config.MultikillInterval) {
		MultikillCount[client] = 0;
	}
	
	return MultikillCount[client];
}

void AddToClientMultikill(int client)
{
	if (GetEngineTime() - LastKill[client] >= g_Config.MultikillInterval) {
		MultikillCount[client] = 0;
	}
	
	++MultikillCount[client];
	LastKill[client] = GetEngineTime();
	
	for (int i = MultikillTiers.Length-1; i >= 0; i--) {
		MultikillTier tier;
		MultikillTiers.GetArray(i, tier);
		
		if (MultikillCount[client] == tier.kills) {
			InstagibPrintToChat(true, client, "\x07%s%s!", tier.color, tier.name);
			
			if (tier.sound[0] != '\0') {
				EmitSoundToClient(client, tier.sound);
			}
			
			for (int j = 1; tier.announce && j <= MaxClients; j++) {
				if (IsClientInGame(j) && j != client) {
					InstagibPrintToChat(true, j, "%N got %s \x07%s%s!", client, tier.article, tier.color, tier.name);
				}
			}
			
			break;
		}
	}
}