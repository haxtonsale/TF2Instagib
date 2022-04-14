// -------------------------------------------------------------------
enum struct MusicData
{
	char path[PLATFORM_MAX_PATH];
	char name[256];
	int length;
	float volume;
	bool announce;
}

static ArrayList InstagibMusic;
static bool IsMusicPlaying;
static MusicData CurrentMusic;
static Handle MusicTimer;

// -------------------------------------------------------------------
void AddMusic(const char[] path, char[] name, int length, bool announce, float volume = 1.0)
{
	if (InstagibMusic == null) {
		InstagibMusic = new ArrayList(sizeof(MusicData));
	}
	
	MusicData data;
	
	strcopy(data.path, sizeof(data.path), path);
	strcopy(data.name, sizeof(data.name), name);
	data.length = length;
	data.volume = volume;
	data.announce = announce;
	
	InstagibMusic.PushArray(data);
	
	InstagibPrecacheSound(path);
}

void AnnounceMusicAll(char[] name)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (g_ClientPrefs[i].EnabledMusic) {
			InstagibPrintToChat(true, i, "♫ Now Playing ♫\n%s", name);
		}
	}
}

void AnnounceMusic(int client, char[] name)
{
	InstagibPrintToChat(true, client, "♫ Now Playing ♫\n%s", name);
}

void PlayRandomMusic()
{
	if (InstagibMusic != null && !g_MapConfig.IsMusicDisabled) {
		static int CurrentMusicIndex = -1;

		if (IsMusicPlaying) {
			StopMusic();
		}
		
		int len = InstagibMusic.Length;
		
		MusicData data;
		
		// Don't repeat songs :)
		if (len > 1) {
			int count;
			int[] suitable_music = new int[len];
			for (int i = 0; i < len; i++) {
				if (i != CurrentMusicIndex || len == 1) {
					suitable_music[count] = i;
					++count;
				}
			}
			
			int roll = GetRandomInt(0, count-1);
			InstagibMusic.GetArray(suitable_music[roll], data);
			
			CurrentMusicIndex = suitable_music[roll];
		} else {
			InstagibMusic.GetArray(0, data);
		}
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && g_ClientPrefs[i].EnabledMusic) {
				EmitSoundToClient(i, data.path, _, SNDCHAN_AUTO, .volume = data.volume);
			}
		}
		
		IsMusicPlaying = true;
		CurrentMusic = data;
		
		MusicTimer = CreateTimer(float(data.length)+5.0, Timer_CycleMusic, _, TIMER_FLAG_NO_MAPCHANGE);
		
		AnnounceMusicAll(data.name);
	}
}

void PlayMusicToLateClient(int client)
{
	if (g_ClientPrefs[client].EnabledMusic && InstagibMusic != null && IsClientInGame(client) && !g_MapConfig.IsMusicDisabled && IsMusicPlaying) {
		EmitSoundToClient(client, CurrentMusic.path, _, SNDCHAN_AUTO, .volume = CurrentMusic.volume);
		AnnounceMusic(client, CurrentMusic.name);
	}
}

void StopMusic(int client = 0)
{
	if (IsMusicPlaying) {
		if (!client) {
			delete MusicTimer;
		}
		
		if (!client) {
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i)) {
					StopSound(i, SNDCHAN_AUTO, CurrentMusic.path);
				}
			}
			
			IsMusicPlaying = false;
		} else {
			StopSound(client, SNDCHAN_AUTO, CurrentMusic.path);
		}
	}
}

// -------------------------------------------------------------------
public Action Timer_CycleMusic(Handle timer)
{
	if (IsMusicPlaying) {
		MusicTimer = null;
		
		StopMusic();
		PlayRandomMusic();
	}
	return Plugin_Continue;
}
