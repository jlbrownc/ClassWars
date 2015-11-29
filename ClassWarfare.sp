//TODO Say how many more people are required to call a vote
//TODO Admin command to force vote
//TODO Admin command to force randomize
//TODO show votes on screen
//TODO remove vote and add command so it can be integraded with vote plugin?!!!!!!!!!!!!!!!!!!!!!!!

#include <sourcemod>
#include <tf2_stocks>

#define PL_VERSION "0.3"

#define SIZE_OF_INT		2147483647

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
	Handle:g_StartVoteReq,
	Handle:g_VotePassReq,
	TFClassType:g_BlueClass,
	TFClassType:g_RedClass,
	bool:g_ClientVotes[30],
	bool:g_ClientStartVote[30]

public OnPluginStart() {
	CreateConVar("sm_classwarfare_version", PL_VERSION, "Class Warfare in TF2.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD)
	g_AllowRedEngie = CreateConVar("sm_classwarfare_allowredengie", "1", "Allow engineer to be picked on red")
	g_StartVoteReq = CreateConVar("sm_classwarfare_startvotereq", "0.15", "The percentage of votes required to initiate a vote", _, true, 0.01, true, 1.0)
	g_VotePassReq = CreateConVar("sm_classwarfare_votepassreq", "0.75", "The percentage of votes required for a vote to pass", _, true, 0.01, true, 1.0)
	
	HookEvent("player_changeclass", Event_PlayerClass)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_team", Event_PlayerTeam)
	HookEvent("teamplay_round_start", Event_RoundStart)
	HookEvent("teamplay_setup_finished", Event_SetupFinished)
	
	RegConsoleCmd("sm_randomize", sm_Randomize)
}

public Action sm_Randomize(int client, int args) {
	if (!client)
		return Plugin_Handled
		
	PrintToChatAll("\x03%N has voted to re choose the classes!", client)
	g_ClientStartVote[client] = true
	
	new count = 0
	for (new i = 1; i <= MaxClients; i++){
		if (g_ClientStartVote[i])
			count++
	}
	if ((count / GetClientCount(true)) >= GetConVarFloat(g_StartVoteReq)) {
		PrintToChatAll("\x03A vote to randomize the classes has started!")
		InitiateVote()
	}
	return Plugin_Handled
}

public MenuHandler1(Handle:menu, MenuAction:action, param1, param2) {
	switch(action){
		case (MenuAction_Select): {
			PrintToServer("Item Selected!")
			char info[5]
			GetMenuItem(menu, param2, info, sizeof(info))
			if (StrEqual(info, "yes")) {
				PrintToServer("Selected %s", info)
				g_ClientVotes[param1] = true	
			}
		}
		case(MenuAction_Cancel): {
			
		}
		case(MenuAction_End): {
			PrintToServer("Menu Ended!")
			new count = 0
			for (new client = 1; client <= MaxClients; client++) {
				if (g_ClientVotes[client]) {
					count++
				}
			}
			PrintToServer("Counts: %d Clients: %d Convar: %f ", count, GetClientCount(), GetConVarFloat(g_VotePassReq))
			if ((count / GetClientCount())  >= GetConVarFloat(g_VotePassReq)) {
				PrintToChatAll("\x03Vote Passed classes are being randomized!")				
				ChooseClassRestrictions()
				PrintStatus()
				for (new client = 1; client <= MaxClients; client++) {
					if (IsClientConnected(client)) {
						TF2_RespawnPlayer(client)
					}
				}
				for (new i = 1; i <= MaxClients; i++) {
					g_ClientVotes[i] = false
					g_ClientStartVote[i] = false					
				}
			}else {
				PrintToChatAll("\0x3Vote has failed!")	
			}
		}
	}
}

public InitiateVote() {
	new Handle:menu = CreateMenu(MenuHandler1, MENU_ACTIONS_DEFAULT)
	SetMenuTitle(menu, "Do you want to randomize the classes?")
	AddMenuItem(menu, "yes", "Yes")
	AddMenuItem(menu, "no", "No")
	SetMenuExitButton(menu, false)
	for (new client = 1; client <= MaxClients; client++) {
		if (IsClientConnected(client)) {
			DisplayMenu(menu, client, 15)
		}
	}
}

//Timer to reset votes

public OnMapStart()
	ChooseClassRestrictions()

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")), 
	TFClassType:class = TFClassType:GetEventInt(event, "class")
	
	if (!IsValidClass(client, class)) {
		PrintCenterText(client, "%s%s%s%s%s", ClassNames[class], " Is Not An Option This Round! It's Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
		PrintToChat(client, "%s%s%s%s%s", ClassNames[class], " Is Not An Option This Round! It's Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
		AssignValidClass(client)
	}
	
}
	
public Action:Event_SetupFinished(Handle:event, const String:name[], bool:dontBroadcast)
	PrintStatus()

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

PrintStatus() {
	PrintCenterTextAll("%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
	PrintToChatAll("%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
}

AssignPlayerClasses() {
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsClientConnected(i)) {
			new TFClassType:class = TFClassType:_:TF2_GetPlayerClass(i)
			if (IsClientConnected(i) && (!IsValidClass(i, class))) {
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

stock Math_GetRandomInt(min, max) {
	new random = GetURandomInt()
	
	if (random == 0)
		random++
	
	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1
} 