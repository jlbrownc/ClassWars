#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>

#define PL_VERSION "0.5.1"

//This code is based on the Class Restrictions Mod from Tsunami: http://forums.alliedmods.net/showthread.php?t=73104

public Plugin:myinfo =  {
	name = "Class Warfare", 
	author = "Tsunami,JonathanFlynn,Phaiz,Notso", 
	description = "Class Vs Class", 
	version = PL_VERSION, 
	url = "https://github.com/NotsoPenguin/ClassWars"
}

static String:ClassNames[TFClassType][] =  { "", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" }

new g_NumWeaponsAllowed = 13, 
String:WeaponClasses[][64] =  {
	//Scout
	"tf_weapon_jar_milk", 
	"tf_weapon_lunchbox_drink", 
	"tf_weapon_cleaver", 
	//Soldier
	"tf_weapon_buff_item", 
	"tf_wearable",  //Mantreads & Gunboats & Booties & Razorback & Cozy Camper
	"tf_weapon_parachute", 
	//Demo	
	"tf_wearable_demoshield", 
	//Heavy
	"tf_weapon_lunchbox", 
	//Medic
	"tf_weapon_crossbow", 
	//Sniper
	"tf_weapon_compound_bow", 
	"tf_weapon_jar", 
	//Spy
	"tf_weapon_pda_spy", 
	"tf_weapon_invis", 
}

new Handle:g_DisableRedEngie, 
Handle:g_MeleeRoundChance, 
TFClassType:g_BlueClass, 
TFClassType:g_RedClass, 
g_MeleeRound = false, 
g_LastRoundFull


public OnPluginStart() {
	CreateConVar("sm_classwarfare_version", PL_VERSION, "Class Warfare in TF2.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD)
	g_DisableRedEngie = CreateConVar("sm_classwarfare_disableredengie", "0", "Disable engineer to be picked on red")
	g_MeleeRoundChance = CreateConVar("sm_classwarfare_medieval_chance", "0.05", "Percent Chance for a round to be melee only", _, true, 0.00, true, 1.00)
	HookEvent("player_changeclass", Event_PlayerClass)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("teamplay_round_start", Event_RoundStart)
	HookEvent("teamplay_setup_finished", Event_SetupFinished)
	HookEvent("post_inventory_application", Event_Resupply)
	HookEvent("teamplay_round_win", Event_RoundOver)
	RegServerCmd("sm_randomize", sm_Randomize, "Randomizes the classes!")
	
	AutoExecConfig(true, "classwarfare");
}

//////////////////////////
//////////Events//////////
//////////////////////////

public OnMapStart() {
	SetupMeleeRound()
	ChooseClassRestrictions()
	AssignPlayerClasses()
	PrintStatus()
}

public Action sm_Randomize(int args) {
	SetupMeleeRound()
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
	SetupMeleeRound()
	ChooseClassRestrictions()
	AssignPlayerClasses()
	PrintStatus()
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid")), 
	TFClassType:class = TFClassType:_:TF2_GetPlayerClass(client)
	if (!IsValidClass(client, class)) {
		AssignValidClass(client)
		TF2_RespawnPlayer(client)
	}
}

public Event_Resupply(Handle:event, const String:name[], bool:dontBroadcast) {
	if (g_MeleeRound) {
		new client = GetClientOfUserId(GetEventInt(event, "userid")), 
		weapon = GetPlayerWeaponSlot(client, 2)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon)
		StripWeapons(client)		
	}
}

public Event_RoundOver(Handle:event, const String:name[], bool:dontBroadcast) {
	if (GetEventInt(event, "full_round") == 1) {
		g_LastRoundFull = true
	}
}


//////////////////////////////////
//////////Class Choosing//////////
/////////////////////////////////
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

TFClassType:ChooseClass(ArrayList:blockedClasses) {
	new ArrayList:allowedClasses = new ArrayList()
	for (new class = 1; class <= 9; class++) {
		new isAllowed = true
		for (new blocked = 0; blocked < blockedClasses.Length; blocked++) {
			if (class == blockedClasses.Get(blocked)) {
				isAllowed = false
			}
		}
		if (isAllowed) {
			allowedClasses.Push(class)
		}
	}
	return allowedClasses.Get(GetRandomInt(0, allowedClasses.Length - 1))
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

ChooseClassRestrictions() {
	new ArrayList:blockedRedClasses = new ArrayList()
	new ArrayList:blockedBlueClasses = new ArrayList()
	
	//Players don't play the same classes again
	//Even after team switch
	if (!g_LastRoundFull) {
		blockedRedClasses.Push(g_RedClass)
		blockedBlueClasses.Push(g_BlueClass)
	} else {
		blockedRedClasses.Push(g_BlueClass)
		blockedBlueClasses.Push(g_RedClass)
	}
	g_LastRoundFull = false
	
	//Disable red engineer.
	if (GetConVarBool(g_DisableRedEngie)) {
		blockedRedClasses.Push(TFClass_Engineer)
	}
	
	new TFClassType:g_NewRedClass = ChooseClass(blockedRedClasses)
	
	//Prevent the same matchup as last time.
	if (g_NewRedClass == g_BlueClass) {
		blockedBlueClasses.Push(g_RedClass)
	}
	
	g_RedClass = g_NewRedClass
	g_BlueClass = ChooseClass(blockedBlueClasses)
}

////////////////////////////////
//////////Melee Rounds//////////
///////////////////////////////
StripWeapons(client) {
	if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client)) {
		new isAllowed = false
		decl String:class[64]
		for (new slot = 0; slot <= 5; slot++) {
			new weapon = GetPlayerWeaponSlot(client, slot)
			isAllowed = false
			if (weapon != -1 && slot != 2) {
				for (new i = 0; i < g_NumWeaponsAllowed; i++) {
					GetEdictClassname(weapon, class, sizeof(class))
					if (StrEqual(class, WeaponClasses[i])) {
						isAllowed = true
					}
				}
				if (!isAllowed) {
					TF2_RemoveWeaponSlot(client, slot)
				}
			}
		}
	}
}

SetupMeleeRound() {
	if (GetRandomFloat(0.00, 1.00) <= GetConVarFloat(g_MeleeRoundChance)) {
		g_MeleeRound = true
		for (new client = 1; client <= MaxClients; client++) {
			StripWeapons(client)
		}
	} else {
		g_MeleeRound = false
	}
}

PrintStatus() {
	if (g_MeleeRound) {
		PrintCenterTextAll("%s%s%s%s", "This is Medieval Mode Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
		PrintToChatAll("\x04%s%s%s%s", "This is Medieval Mode Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
	} else {
		PrintCenterTextAll("%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
		PrintToChatAll("\x04%s%s%s%s", "This is Class Warfare: Red ", ClassNames[g_RedClass], " vs Blue ", ClassNames[g_BlueClass])
	}
}