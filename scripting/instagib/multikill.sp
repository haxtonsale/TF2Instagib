// -------------------------------------------------------------------
static int MultikillTimer[MAXPLAYERS+1];
static int MultikillCount[MAXPLAYERS+1];

// -------------------------------------------------------------------
public Action Timer_MultikillTick(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (MultikillTimer[i] > 0) {
			MultikillTimer[i] -= 1;
		} else if (MultikillCount[i] > 0){
			MultikillCount[i] = 0;
		}
	}
}

int GetClientMultikill(int client)
{
	return MultikillCount[client];
}

void AddToClientMultikill(int client)
{
	++MultikillCount[client];
	MultikillTimer[client] = g_Config.MultikillInterval;
	
	switch (MultikillCount[client]) {
		case 2:
			AnnounceMultikill(client, "\x07FF4747Double Kill!", false);
		case 3:
			AnnounceMultikill(client, "\x07F02222Triple Kill!");
		case 4:
			AnnounceMultikill(client, "\x07F75F19Multi Kill!");
		case 5:
			AnnounceMultikill(client, "\x07F7A619Mega Kill!");
		case 6:
			AnnounceMultikill(client, "\x07FFDB0DUltra Kill!", _, "an");
		case 10:
			AnnounceMultikill(client, "\x07FF0000MONSTER KILL!");
	}
}

void AnnounceMultikill(int client, char[] text, bool announce = true, char[] article = "a")
{
	InstagibPrintToChat(true, client, text);
	
	for (int i = 1; announce && i <= MaxClients; i++) {
		if (IsClientInGame(i) && i != client) {
			InstagibPrintToChat(true, i, "%N got %s %s", client, article, text);
		}
	}
}