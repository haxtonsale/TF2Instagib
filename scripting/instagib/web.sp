// -------------------------------------------------------------------
static char[] GetMessage(Handle HTTPRequest)
{
	int size;
	SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);

	char[] response = new char[size];
	SteamWorks_GetHTTPResponseBodyData(HTTPRequest, response, size);
	
	int index = ReplaceStringEx(response, size, "\"message\":", "");
	
	char message[256];
	int len;
	while (response[++index] != '"') {
		message[len] = response[index];
		++len;
	}
	
	return message;
}

#define LATEST_RELEASE_URL "https://api.github.com/repos/haxtonsale/TF2Instagib/releases/latest"
#define MAP_CONFIGS_URL "https://api.github.com/repos/haxtonsale/TF2Instagib-MapConfigs/contents"

static void InitializeRequest(Handle request)
{
	char token[64];
	g_CvarGitHubToken.GetString(token, sizeof(token));
	
	SteamWorks_SetHTTPRequestHeaderValue(request, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(request, "Cache-Control", "no-cache");
	
	if (token[0] != '\0') {
		Format(token, sizeof(token), "token %s", token);
		SteamWorks_SetHTTPRequestHeaderValue(request, "Authorization", token);
	}
	
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 60);
}

void Web_GetLatestInstagibVersion()
{
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, LATEST_RELEASE_URL);
	InitializeRequest(request);
	SteamWorks_SetHTTPCallbacks(request, Web_GetLatestInstagibVersion_OnComplete);
	SteamWorks_SendHTTPRequest(request);
}

void Web_GetMapConfigs()
{
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, MAP_CONFIGS_URL);
	InitializeRequest(request);
	SteamWorks_SetHTTPCallbacks(request, Web_GetMapConfigs_OnComplete);
	SteamWorks_SendHTTPRequest(request);
}

void Web_DownloadMapConfig(const char[] url)
{
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	InitializeRequest(request);
	
	char name[128];
	int index = StrContains(url, ".cfg");
	int offset = index;
	while (url[offset] != '/') {
		--offset;
	}
	
	CSubString(url, name, sizeof(name), ++offset, index-offset-1);
	
	ArrayStack map_name = new ArrayStack(128);
	map_name.PushString(name);
	
	SteamWorks_SetHTTPCallbacks(request, Web_DownloadMapConfig_OnComplete);
	SteamWorks_SetHTTPRequestContextValue(request, map_name);
	SteamWorks_SendHTTPRequest(request);
}

public int Web_GetLatestInstagibVersion_OnComplete(Handle HTTPRequest, bool failure, bool success, EHTTPStatusCode statusCode, int contextData)
{
	if (success && statusCode == k_EHTTPStatusCode200OK) {
		int size;
		SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);

		char[] response = new char[size];
		SteamWorks_GetHTTPResponseBodyData(HTTPRequest, response, size);
		
		int index = ReplaceStringEx(response, size, "\"tag_name\":", "");
		if (index != -1) {
			char version[16];
			int len;
			while (response[++index] != '"') {
				version[len] = response[index];
				++len;
			}
			
			char version_exploded[3][8];
			int version_num[3];
			ExplodeString(version, ".", version_exploded, sizeof(version_exploded), sizeof(version_exploded[]));
			
			char running_version_exploded[3][8];
			int running_version_num[3];
			ExplodeString(INSTAGIB_VERSION, ".", running_version_exploded, sizeof(running_version_exploded), sizeof(running_version_exploded[]));
			
			for (int i = 0; i < 3; i++) {
				version_num[i] = StringToInt(version_exploded[i]);
				running_version_num[i] = StringToInt(running_version_exploded[i]);
			}
			
			bool outdated;
			if (version_num[0] > running_version_num[0]) {
				PrintToServer("\nNew MAJOR TF2Instagib update is available!");
				outdated = true;
			} else if (version_num[0] == running_version_num[0] && version_num[1] > running_version_num[1]) {
				PrintToServer("\nNew TF2Instagib update is available!");
				outdated = true;
			} else if (version_num[0] == running_version_num[0] && version_num[1] == running_version_num[1] && version_num[2] > running_version_num[2]) {
				PrintToServer("\nNew MINOR TF2Instagib update is available!");
				outdated = true;
			}
			
			if (outdated) {
				index = ReplaceStringEx(response, size, "\"body\":", "");
				if (index != -1) {
					char changelog[2048];
					len = 0;
					while (response[++index] != '"' && len < sizeof(changelog)) {
						changelog[len] = response[index];
						++len;
					}
					
					ReplaceString(changelog, sizeof(changelog), "**", "    *");
					ReplaceString(changelog, sizeof(changelog), "\\n", "\n");
					ReplaceString(changelog, sizeof(changelog), "\\r", "");
					
					PrintToServer(changelog);
				}
				
				
				PrintToServer("Get TF2Instagib v%s here: https://github.com/haxtonsale/TF2Instagib/releases/latest\n", version);
			}
		}
	} else {
		LogError("Failed to get latest Instagib version! (%i)\n%s", statusCode, GetMessage(HTTPRequest));
	}
	
	delete HTTPRequest;

	return 0;
}

public int Web_GetMapConfigs_OnComplete(Handle HTTPRequest, bool failure, bool success, EHTTPStatusCode statusCode, int contextData)
{
	if (!success && statusCode == k_EHTTPStatusCode200OK) {
		int size;
		SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);

		char[] response = new char[size];
		SteamWorks_GetHTTPResponseBodyData(HTTPRequest, response, size);
		
		int index = ReplaceStringEx(response, size, "\"download_url\":", "");
		while (index != -1) {
			char url[128];
			
			int len;
			while (response[++index] != '"') {
				url[len] = response[index];
				++len;
			}
			
			index = ReplaceStringEx(response, size, "\"download_url\":", "");
			
			Web_DownloadMapConfig(url);
		}
	} else {
		LogError("Failed to get map configs! (%i)\n%s", statusCode, GetMessage(HTTPRequest));
	}
	
	delete HTTPRequest;

	return 0;
}

public int Web_DownloadMapConfig_OnComplete(Handle HTTPRequest, bool failure, bool success,  EHTTPStatusCode statusCode, ArrayStack data)
{
	CreateMapConfigFolder();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "/configs/instagib_maps/official");
	if (!DirExists(path)) {
		CreateDirectory(path, FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_EXEC | FPERM_O_READ | FPERM_G_EXEC);
	}
	
	if (!success && statusCode == k_EHTTPStatusCode200OK) {
		char name[128];
		data.PopString(name, sizeof(name));
		delete data;
		
		BuildPath(Path_SM, path, sizeof(path), "configs/instagib_maps/official/%s.cfg", name);
		
		SteamWorks_WriteHTTPResponseBodyToFile(HTTPRequest, path);
		
		if (!g_MapConfig.SpawnPoints.Length && StrEqual(GetMapName(), name)) {
			LoadMapConfig(name);
		}
	} else {
		LogError("Failed to download the map config! (%i)\n%s", statusCode, GetMessage(HTTPRequest));
	}
	
	delete HTTPRequest;

	return 0;
}
