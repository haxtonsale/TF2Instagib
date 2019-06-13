// -------------------------------------------------------------------
#define CreatePdLogicString "{ \"origin\" \"0.0 0.0 0.0\"\"targetname\" \"pd_logic\"\"res_file\" \"resource/UI/HudObjectivePlayerDestruction.res\"\"red_respawn_time\" \"5\"\"prop_model_name\" \"models/flag/flag.mdl\"\"points_per_player\" \"5\"\"min_points\" \"10\"\"heal_distance\" \"300\"\"flag_reset_delay\" \"60\"\"finale_length\" \"0\"\"blue_respawn_time\" \"5\"\"classname\" \"tf_logic_player_destruction\"}"

public Action OnLevelInit(const char[] mapName, char mapEnts[2097152]) 
{
	StrCat(mapEnts, sizeof(mapEnts), CreatePdLogicString);
	
	#if defined DEBUG
	PrintToServer("Created tf_logic_player_destruction");
	#endif
	
	return Plugin_Changed;
}