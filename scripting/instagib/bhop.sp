// -------------------------------------------------------------------
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_Config.EnabledBhop && g_ClientPrefs[client].EnabledBhop) {
		if ((buttons & IN_JUMP) && GetEntityFlags(client) & FL_ONGROUND) {
			float vecVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
			
			// Limit bhop speed
			float magnitude = SquareRoot(vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1]);
			if (magnitude > g_Config.BhopMaxSpeed) {
				vecVel[0] = vecVel[0] * g_Config.BhopMaxSpeed / magnitude;
				vecVel[1] = vecVel[1] * g_Config.BhopMaxSpeed / magnitude;
			}
			
			vecVel[2] = 267.0;
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
		}
	}
	
	return Plugin_Continue;
}
