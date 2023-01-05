#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <cstrike>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

#define MODEL_SPRITE "materials/sprites/laserbeam.vmt"

/*
int g_DefaultColors[7][4] = { 
	{255,255,255,255}, {255,0,0,255}, {0,255,0,255}, {0,0,255,255}, {255,255,0,255}, {0,255,255,255}, {255,0,255,255} 
};
*/

int g_LastButtons[MAXPLAYERS+1];
float g_LastPos[MAXPLAYERS+1][3];
bool g_PaintOn[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "sm_paint (+USE Paint plugin)",
	author = "JustGo",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};


public void OnPluginStart()
{
	CreateConVar("sm_paint_version", PLUGIN_VERSION, "paint plugin.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public void OnClientPutInServer(int client)
{
	resetPaint(client);
}

public Action OnPlayerRunCmd(int client, int &buttons) {
	if ((buttons & IN_USE))
	{
		if (!(g_LastButtons[client] & IN_USE))
		{
			OnButtonPress(client);
		}
	}
	else if ((g_LastButtons[client] & IN_USE))
	{
		OnButtonRelease(client);
	}

	g_LastButtons[client] = buttons; 
	return Plugin_Continue;
}

public void OnButtonPress(int client) {
	if(canUsePaint(client)) {
		TraceEye(client, g_LastPos[client]);
		g_PaintOn[client] = true;
	}
}

public void OnButtonRelease(int client) {
	resetPaint(client);
}

public void OnClientDisconnect_Post(int client) {
	g_LastButtons[client] = 0;
}

public void OnMapStart() {
	PrecacheModel(MODEL_SPRITE);
	CreateTimer(0.1, Timer_Paint, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Paint(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(canUsePaint(i) && g_PaintOn[i]) {
			handlePainting(i);
		}
	}
	return Plugin_Handled;
}

public void handlePainting(int id) {
	float posEye[3];
	TraceEye(id, posEye);

	//int Color = GetRandomInt(0,6);

	if(GetVectorDistance(posEye, g_LastPos[id]) > 6.0) {
		CreateBeam(g_LastPos[id], posEye);
		g_LastPos[id][0] = posEye[0];
		g_LastPos[id][1] = posEye[1];
		g_LastPos[id][2] = posEye[2];
	}
}

/*
stock void LaserPaint(float start[3], float end[3], int color[4]) {
	TE_SetupBeamPoints(start, end, g_sprite, 0, 0, 0, 50.0, 2.0, 2.0, 10, 0.0, color, 0);
	TE_SendToAll();
}
*/

stock void CreateBeam(float start[3], float end[3])
{
	int ent = CreateEntityByName("env_beam");
	if (ent != -1)
	{
		TeleportEntity(ent, start, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(ent, MODEL_SPRITE);
		SetEntPropVector(ent, Prop_Data, "m_vecEndPos", end);
		DispatchKeyValue(ent, "targetname", "beam");
		DispatchKeyValue(ent, "rendercolor", "0 255 0");
		DispatchKeyValue(ent, "life", "60");
		char amt[32];
		Format(amt, sizeof(amt), "%i", 100);
		DispatchKeyValue(ent, "renderamt", amt);
		DispatchSpawn(ent);
		SetEntPropFloat(ent, Prop_Data, "m_fWidth", 2.0);
		SetEntPropFloat(ent, Prop_Data, "m_fEndWidth", 2.0);
		ActivateEntity(ent);
		AcceptEntityInput(ent, "TurnOn");
		SetEntitySelfDestruct(ent, 60.0);
	} 
}

// Thanks to Chaosxk
public void SetEntitySelfDestruct(int entity, float duration)
{
	char output[64]; 
	Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", duration);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
}

stock bool canUsePaint(int id) {
	if(!IsClientInGame(id))
		return false;

	if(!IsPlayerAlive(id))
		return false;

	if(!CheckCommandAccess(id, "sm_adminpaint", ADMFLAG_GENERIC))
		return false;

	return true;
}

void TraceEye(int client, float pos[3]) {
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(INVALID_HANDLE)) TR_GetEndPosition(pos, INVALID_HANDLE);
	return;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return (entity > MaxClients || !entity);
}

void resetPaint(int client) {
	g_PaintOn[client] = false;
	g_LastPos[client][0] = 0.0;
	g_LastPos[client][1] = 0.0;
	g_LastPos[client][2] = 0.0;
}