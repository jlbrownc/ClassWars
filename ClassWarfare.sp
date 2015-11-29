#include <sourcemod>
#include <tf2_stocks>

#define PL_VERSION "0.3"

#define SIZE_OF_INT	2147483647

//This code is based on the Class Restrictions Mod from Tsunami: http://forums.alliedmods.net/showthread.php?t=73104

public Plugin:myinfo = {
	name = "Class Warfare", 
	author = "Tsunami,JonathanFlynn,Sound Fix by Phaiz,Notso", 
	description = "Class Vs Class", 
	version = PL_VERSION, 
	url = "https://github.com/NotsoPenguin/ClassWars"
}

static String:ClassNames[TFClassType][] =  { "", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" },
	TFClassType:ClassTypes[] = {TFClass_Unknown, TFClass_Scout, TFClass_Sniper, TFClass_Soldier, TFClass_DemoMan, TFClass_Medic, TFClass_Heavy, TFClass_Pyro, TFClass_Spy, TFClass_Engineer}

new Handle:g_AllowRedEngie,
	TFClassType:g_BlueClass,
	TFClassType:g_RedClass

public OnPluginStart() {
	CreateConVar("sm_classwarfare_version", PL_VERSION, "Class Warfare in TF2.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD)
	g_AllowRedEngie = CreateConVar("sm_classwarfare_disableredengie", "1", "Disable engineer to be picked on red")

	HookEvent("player_changeclass", Event_PlayerClass)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("teamplay_round_start", Event_RoundStart)
	HookEvent("teamplay_setup_finished", Event_SetupFinished)
	
	RegAdminCmd("sm_randomize", sm_Randomize, ADMFLAG_KICK, "Randomizes the classes!")
}

public OnMapStart() {
	ChooseClassRestrictions()
}

public Action sm_Randomize(int client, int args) {
	PrintToChatAll("\x03The classes have been randomized by an admin!")
	PrintCenterTextAll("%s%s%s%s", "Classes have been randomized! Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
	ChooseClassRestrictions()
	AssignPlayerClasses()
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")), 
	TFClassType:class = TFClassType:GetEventInt(event, "class")
	
	if (!IsValidClass(client, class)) {
		PrintCenterText(client, "\x03%s%s%s%s%s", ClassNames[class], " Is Not An Option This Round! It's Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
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
	g_BlueClass = ClassTypes[Math_GetRandomInt(1, 9)]
	if (GetConVarBool(g_AllowRedEngie)) 
		g_RedClass = ClassTypes[Math_GetRandomInt(1, 9)]
	else 
		g_RedClass = ClassTypes[Math_GetRandomInt(1, 8)]
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

stock Math_GetRandomInt(min, max) {
	new random = GetURandomInt()
	
	if (random == 0)
		random++
	
	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1
} 