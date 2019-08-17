// -------------------------------------------------------------------
enum struct Prefs
{
	bool EnabledMusic;
	int ViewmodelAlpha;
	bool EnabledBhop;
}

Cookie g_PrefMusic;
Cookie g_PrefViewmodel;
Cookie g_PrefBhop;

Prefs g_ClientPrefs[MAXPLAYERS+1];

// -------------------------------------------------------------------
void Cookies_Init()
{
	g_PrefMusic = new Cookie("instagib_music", "Whether Instagib should play round music.", CookieAccess_Public);
	g_PrefViewmodel = new Cookie("instagib_viewmodel", "The transparency of Railgun viewmodel.", CookieAccess_Public);
	g_PrefBhop = new Cookie("instagib_bhop", "Whether you have auto bhop enabled.", CookieAccess_Public);
}

void GetClientCookies(int client)
{
	char musicstr[64];
	g_PrefMusic.Get(client, musicstr, sizeof(musicstr));
	
	char viewmodel[64];
	g_PrefViewmodel.Get(client, viewmodel, sizeof(viewmodel));
	
	char bhop[64];
	g_PrefBhop.Get(client, bhop, sizeof(bhop));
	
	if (musicstr[0] == '\0') {
		g_PrefMusic.Set(client, "1");
		g_ClientPrefs[client].EnabledMusic = true;
	} else {
		g_ClientPrefs[client].EnabledMusic = view_as<bool>(StringToInt(musicstr));
	}
	
	if (viewmodel[0] == '\0') {
		g_PrefViewmodel.Set(client, "255");
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
		g_PrefBhop.Set(client, "1");
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
