// Stuff for getting the latest version straight from github

#define LATEST_RELEASE_URL "https://api.github.com/repos/haxtonsale/TF2Instagib/releases/latest"
#define MAP_CONFIGS_URL "https://api.github.com/repos/haxtonsale/TF2Instagib-MapConfigs/contents/"

void Web_GetLatestInstagibVersion()
{
	HTTPRequestHandle request = Steam_CreateHTTPRequest(HTTPMethod_GET, LATEST_RELEASE_URL);
	Steam_SetHTTPRequestHeaderValue(request, "Pragma", "no-cache");
	Steam_SetHTTPRequestHeaderValue(request, "Cache-Control", "no-cache");
	Steam_SetHTTPRequestNetworkActivityTimeout(request, 60);
	Steam_SendHTTPRequest(request, Web_GetLatestInstagibVersion_OnComplete);
}

void Web_GetMapConfigs()
{
	HTTPRequestHandle request = Steam_CreateHTTPRequest(HTTPMethod_GET, MAP_CONFIGS_URL);
	Steam_SetHTTPRequestHeaderValue(request, "Pragma", "no-cache");
	Steam_SetHTTPRequestHeaderValue(request, "Cache-Control", "no-cache");
	Steam_SetHTTPRequestNetworkActivityTimeout(request, 60);
	Steam_SendHTTPRequest(request, Web_GetMapConfigs_OnComplete);
}

public int Web_GetLatestInstagibVersion_OnComplete(HTTPRequestHandle HTTPRequest, bool requestSuccessful, HTTPStatusCode statusCode, int contextData)
{
	if (requestSuccessful && statusCode == HTTPStatusCode_OK)
	{
		int size = Steam_GetHTTPResponseBodySize(HTTPRequest);
		char[] response = new char[size];
		
		Steam_GetHTTPResponseBodyData(HTTPRequest, response, size);
		
		int tag_pos = StrContains(response, "\"tag_name\":");
		if (tag_pos != -1) {
			char version[16];
			CSubString(response, version, sizeof(version), tag_pos+12, 5);
			
			if (!StrEqual(INSTAGIB_VERSION, version)) {
				PrintToServer("This server is running an outdated version of TF2Instagib!\nGet TF2Instagib %s here: https://github.com/haxtonsale/TF2Instagib/releases/latest", version);
			}
		}
	}
	else
	{
		LogError("Failed to get latest Instagib version! (%i)", statusCode);
	}

	Steam_ReleaseHTTPRequest(HTTPRequest);
}

public int Web_GetMapConfigs_OnComplete(HTTPRequestHandle HTTPRequest, bool requestSuccessful, HTTPStatusCode statusCode, int contextData)
{
	if (requestSuccessful && statusCode == HTTPStatusCode_OK)
	{
		int size = Steam_GetHTTPResponseBodySize(HTTPRequest);
		char[] response = new char[size];
		
		Steam_GetHTTPResponseBodyData(HTTPRequest, response, size);
		
		int index = ReplaceStringEx(response, size, "\"download_url\":", "");
		while (index != -1) {
			char url[128];
			
			int len;
			while (response[++index] != '"') {
				url[len] = response[index];
				++len;
			}
			
			index = ReplaceStringEx(response, size, "\"download_url\":", "");
			
			PrintToServer(url);
		}
	}
	else
	{
		LogError("Failed to get map configs! (%i)", statusCode);
	}

	Steam_ReleaseHTTPRequest(HTTPRequest);
}