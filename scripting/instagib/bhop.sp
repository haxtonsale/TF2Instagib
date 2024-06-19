// -------------------------------------------------------------------
static int ClientHoldingJumpFor[TF2_MAXPLAYERS+1]; // For how much frames has client been holding his jump button

// -------------------------------------------------------------------
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (buttons & IN_JUMP) {
		if (GetEntityFlags(client) & FL_ONGROUND) {
			float vecVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
			
			vecVel[2] = 267.0;
			
			if (ClientHoldingJumpFor[client] > 0 && ClientHoldingJumpFor[client] <= 4 && g_Config.ManualBhop) {
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel); // Manual bhop with speed boost :)
			} else if (g_Config.AutoBhop && g_ClientPrefs[client].AutoBhop) { 
				// Limit auto bhop speed
				float magnitude = SquareRoot(vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1]);
				if (magnitude > g_Config.BhopMaxSpeed) {
					vecVel[0] = vecVel[0] * g_Config.BhopMaxSpeed / magnitude;
					vecVel[1] = vecVel[1] * g_Config.BhopMaxSpeed / magnitude;
				}
				
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVel);
			}
		}
		
		++ClientHoldingJumpFor[client];
	} else if (ClientHoldingJumpFor[client]) {
		ClientHoldingJumpFor[client] = 0;
	}
	
	return Plugin_Continue;
}
