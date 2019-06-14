// -------------------------------------------------------------------
enum struct Prefs
{
	bool MusicEnabled;
	int ViewmodelAlpha;
}

Handle g_PrefMusic;
Handle g_PrefViewmodel;

Prefs g_ClientPrefs[MAXPLAYERS+1];

// -------------------------------------------------------------------
void Cookies_Init()
{
	g_PrefMusic = RegClientCookie("instagib_music", "Whether Instagib should play round music.", CookieAccess_Public);
	g_PrefViewmodel = RegClientCookie("instagib_viewmodel", "The transparency of Railgun viewmodel.", CookieAccess_Protected);
}

void GetClientCookies(int client)
{
	char musicstr[64];
	GetClientCookie(client, g_PrefMusic, musicstr, sizeof(musicstr));
	
	char viewmodel[64];
	GetClientCookie(client, g_PrefViewmodel, viewmodel, sizeof(viewmodel));
	
	if (musicstr[0] == '\0') {
		SetClientCookie(client, g_PrefMusic, "1");
		g_ClientPrefs[client].MusicEnabled = true;
	} else {
		g_ClientPrefs[client].MusicEnabled = view_as<bool>(StringToInt(musicstr));
	}
	
	if (viewmodel[0] == '\0') {
		SetClientCookie(client, g_PrefViewmodel, "255");
		g_ClientPrefs[client].ViewmodelAlpha = 255;
		
		if (IsValidEntity(g_MainWeaponEnt[client])) {
			SetEntityRenderColor(g_MainWeaponEnt[client], .a = 255);
		}
	} else {
		int alpha = StringToInt(viewmodel);
		g_ClientPrefs[client].ViewmodelAlpha = alpha;
		
		if (IsValidEntity(g_MainWeaponEnt[client])) {
			SetEntityRenderColor(g_MainWeaponEnt[client], .a = alpha);
		}
	}
}

// -------------------------------------------------------------------
public void OnClientCookiesCached(int client)
{
	GetClientCookies(client);
}
