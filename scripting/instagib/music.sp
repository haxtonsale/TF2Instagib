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

#define MUSIC_ANNOUNCEMENT "%s ♫ Now Playing ♫\n%s"

// -------------------------------------------------------------------
void AddMusic(char[] path, char[] name, int length, bool add_to_downloads, bool announce, float volume = 1.0)
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
	
	if (add_to_downloads) {
		AddFileToDownloadsTable(path);
	}
	
	InstagibMusic.PushArray(data);
}

void PrecacheMusic()
{
	if (InstagibMusic != null && g_MusicEnabled) {
		int len = InstagibMusic.Length;
		
		for (int i = 0; i < len; i++) {
			MusicData data;
			InstagibMusic.GetArray(i, data);
			
			PrecacheSound(data.path);
		}
	}
}

void AnnounceMusicAll(char[] name)
{
	CPrintToChatAll(MUSIC_ANNOUNCEMENT, g_InstagibTag, name);
}

void AnnounceMusic(int client, char[] name)
{
	CPrintToChat(client, MUSIC_ANNOUNCEMENT, g_InstagibTag, name);
}

void PlayRandomMusic()
{
	if (InstagibMusic != null && g_MusicEnabled) {
		if (IsMusicPlaying) {
			StopMusic();
		}
		
		int len = InstagibMusic.Length;
		
		MusicData data;
		InstagibMusic.GetArray(GetRandomInt(0, len-1), data);
		
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && g_ClientPrefs[i].MusicEnabled) {
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
	if (g_ClientPrefs[client].MusicEnabled && InstagibMusic != null && IsClientInGame(client) && g_MusicEnabled && IsMusicPlaying) {
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
}
