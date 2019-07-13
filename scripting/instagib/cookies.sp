// -------------------------------------------------------------------
enum struct Prefs
{
	bool EnabledMusic;
	int ViewmodelAlpha;
	bool EnabledBhop;
}

Handle g_PrefMusic;
Handle g_PrefViewmodel;
Handle g_PrefBhop;

Prefs g_ClientPrefs[MAXPLAYERS+1];

// -------------------------------------------------------------------
void Cookies_Init()
{
	g_PrefMusic = RegClientCookie("instagib_music", "Whether Instagib should play round music.", CookieAccess_Public);
	g_PrefViewmodel = RegClientCookie("instagib_viewmodel", "The transparency of Railgun viewmodel.", CookieAccess_Public);
	g_PrefBhop = RegClientCookie("instagib_bhop", "Whether you have bhop enabled.", CookieAccess_Public);
}

void GetClientCookies(int client)
{
	char musicstr[64];
	GetClientCookie(client, g_PrefMusic, musicstr, sizeof(musicstr));
	
	char viewmodel[64];
	GetClientCookie(client, g_PrefViewmodel, viewmodel, sizeof(viewmodel));
	
	char bhop[64];
	GetClientCookie(client, g_PrefBhop, bhop, sizeof(bhop));
	
	if (musicstr[0] == '\0') {
		SetClientCookie(client, g_PrefMusic, "1");
		g_ClientPrefs[client].EnabledMusic = true;
	} else {
		g_ClientPrefs[client].EnabledMusic = view_as<bool>(StringToInt(musicstr));
	}
	
	if (viewmodel[0] == '\0') {
		SetClientCookie(client, g_PrefViewmodel, "255");
		g_ClientPrefs[client].ViewmodelAlpha = 255;
		
		if (IsValidEntity(g_MainWeaponEnt[client])) {
			SetEntityRenderColor(g_MainWeaponEnt[client], .a = 255);
		}
	} else {
		int alpha = StringToInt(viewmodel);
		
		if (alpha < 0) {
			alpha = 0;
		} else if (alpha > 255) {
			alpha = 255;
		}
		
		g_ClientPrefs[client].ViewmodelAlpha = alpha;
		
		if (IsValidEntity(g_MainWeaponEnt[client])) {
			SetEntityRenderColor(g_MainWeaponEnt[client], .a = alpha);
		}
	}
	
	if (bhop[0] == '\0') {
		SetClientCookie(client, g_PrefBhop, "1");
		g_ClientPrefs[client].EnabledBhop = true;
	} else {
		g_ClientPrefs[client].EnabledBhop = view_as<bool>(StringToInt(bhop));
	}
}

// -------------------------------------------------------------------
public void OnClientCookiesCached(int client)
{
	GetClientCookies(client);
}
