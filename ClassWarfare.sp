#include <sourcemod>
#include <tf2_stocks>

#define PL_VERSION "0.4"

//This code is based on the Class Restrictions Mod from Tsunami: http://forums.alliedmods.net/showthread.php?t=73104

public Plugin:myinfo = {
	name = "Class Warfare", 
	author = "Tsunami,JonathanFlynn,Phaiz,Notso", 
	description = "Class Vs Class", 
	version = PL_VERSION, 
	url = "https://github.com/NotsoPenguin/ClassWars"
}

static String:ClassNames[TFClassType][] =  { "", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" }

new Handle:g_DisableRedEngie,
	TFClassType:g_BlueClass,
	TFClassType:g_RedClass
	
new g_FirstRound = true

public OnPluginStart() {
	CreateConVar("sm_classwarfare_version", PL_VERSION, "Class Warfare in TF2.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD)
	g_DisableRedEngie = CreateConVar("sm_classwarfare_disableredengie", "0", "Disable engineer to be picked on red")

	HookEvent("player_changeclass", Event_PlayerClass)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("teamplay_round_start", Event_RoundStart)
	HookEvent("teamplay_setup_finished", Event_SetupFinished)
	
	RegServerCmd("sm_randomize", sm_Randomize, "Randomizes the classes!")
}

public OnMapStart() {
	ChooseClassRestrictions()
	AssignPlayerClasses()
	PrintStatus()
}

public Action sm_Randomize(int args) {
	ChooseClassRestrictions()
	AssignPlayerClasses()
	PrintStatus()
	return Plugin_Handled
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")), 
	TFClassType:class = TFClassType:GetEventInt(event, "class")
	
	if (!IsValidClass(client, class)) {
		PrintCenterText(client, "%s%s%s%s%s", ClassNames[class], " Is Not An Option This Round! It's Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
		AssignValidClass(client)
	}
	
}
	
public Action:Event_SetupFinished(Handle:event, const String:name[], bool:dontBroadcast) {
	PrintStatus()
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	ChooseClassRestrictions()
	AssignPlayerClasses()
	PrintStatus()
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")),
	TFClassType:class = TFClassType:_:TF2_GetPlayerClass(client)
	
	if (!IsValidClass(client, class))	{
		AssignValidClass(client)
		TF2_RespawnPlayer(client)
	}
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")),
	TFClassType:class = TFClassType:_:TF2_GetPlayerClass(client)
	
	if (!IsValidClass(client, class)) {
		AssignValidClass(client)
		TF2_RespawnPlayer(client)
	}
}

bool:IsValidClass(client, TFClassType:class) {
	new TFTeam:team = TFTeam:TF2_GetClientTeam(client)
	if (team == TFTeam_Red) {
		if (class == g_RedClass) 
			return true
	} else if (class == g_BlueClass) 
			return true	
	
	return false
}

AssignPlayerClasses() {
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) {
			new TFClassType:class = TFClassType:_:TF2_GetPlayerClass(i)
			if (!IsValidClass(i, class)) {
				AssignValidClass(i)
				TF2_RegeneratePlayer(i)
				TF2_RespawnPlayer(i)
			}
		}
	}
}

ChooseClassRestrictions() {
	if (!g_FirstRound) {
		new numRedClasses = GetConVarBool(g_DisableRedEngie) ? 8 : 9
		
		new TFClassType:blueClasses[9],
			TFClassType:redClasses[numRedClasses]
		
		new blueCount = 1
		for (new i = 1; i <= 9; i++) {
			if (TFClassType:i != g_BlueClass) {
				blueClasses[blueCount] = TFClassType:i	
				blueCount++				
			}
		}
		
		new redCount = 1
		for (new i = 1; i <= numRedClasses; i++) {
			if (TFClassType:i != g_RedClass) {
				if (!(GetConVarBool(g_DisableRedEngie) && (TFClassType:i == TFClassType:TFClass_Engineer))) {	
					redClasses[redCount] = TFClassType:i
					redCount++				
				}
			}
		}
	
		g_BlueClass = blueClasses[GetRandomInt(1, 8)]
		g_RedClass = redClasses[GetRandomInt(1, numRedClasses-1)]
	} else {
		g_BlueClass = TFClassType:GetRandomInt(1, 8)
		g_RedClass = TFClassType:GetRandomInt(1, GetConVarBool(g_DisableRedEngie) ? 8 : 9)
		g_FirstRound = false
	}
}

AssignValidClass(client) {
	new TFTeam:team = TFTeam:TF2_GetClientTeam(client)
	if ((team == TFTeam:TFTeam_Unassigned) || (team == TFTeam:TFTeam_Spectator))
		return
	
	if (TF2_GetClientTeam(client) == TFTeam_Red) 
		TF2_SetPlayerClass(client, g_RedClass)
	else
		TF2_SetPlayerClass(client, g_BlueClass)
}

PrintStatus() {
	PrintCenterTextAll("%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
	PrintToChatAll("\x03%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
}