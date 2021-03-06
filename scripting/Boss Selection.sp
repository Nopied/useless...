#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <clientprefs>

/*

참고사항: BossQueue가 -1 이하일 경우, 보스 안함이 설정된 상태.
테스트가 필요함.

*/

#define PLUGIN_VERSION "2.1"
#define MAX_NAME 126

int g_iChatCommand;

char Incoming[MAXPLAYERS+1][64];
char g_strChatCommand[42][50]; // 이 말은 즉슨.. 42개 이상의 커맨드를 등록하면 이 플러그인은 터진다.

Handle g_hBossCookie;
Handle g_hBossQueue;
Handle g_hCvarChatCommand;
// Handle g_hCvarLanguage;

public Plugin:myinfo = {
	name = "Freak Fortress 2: Boss Selection EX",
	description = "Allows players select their bosses by /ff2boss (Need 1.10.6+)",
	author = "Nopied◎",
	version = PLUGIN_VERSION,
};

public void OnPluginStart()
{
	int version[3];
	FF2_GetFF2Version(version);
	if(version[0]==1 && (version[1]<10 || (version[1]==10 && version[2]<6)))
	{
		SetFailState("This version of FF2 Boss Selection requires at least FF2 v1.10.6!");
	}

	g_hCvarChatCommand = CreateConVar("ff2_bossselection_chatcommand", "ff2boss,boss,보스,보스선택");
	// g_hCvarLanguage = CreateConVar("ff2_bossselection_default", "en");

	AddCommandListener(Listener_Say, "say");
	AddCommandListener(Listener_Say, "say_team");

	RegConsoleCmd("ff2_boss", Command_SetMyBoss, "Set my boss");
	RegConsoleCmd("ff2boss", Command_SetMyBoss, "Set my boss");
	RegConsoleCmd("boss", Command_SetMyBoss, "Set my boss");

	g_hBossCookie  = RegClientCookie("BossCookie", "Bosses name", CookieAccess_Protected);
// 	g_hBossQueue = RegClientCookie("QueuePoint", "", CookieAccess_Protected);

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("ff2_boss_selection");

	ChangeChatCommand();
}

public void Cvar_ChatCommand_Changed(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	ChangeChatCommand();
}

public void OnMapStart()
{
	ChangeChatCommand();
}

void ChangeChatCommand()
{
	g_iChatCommand = 0;

	char cvarV[MAX_NAME];
	GetConVarString(g_hCvarChatCommand, cvarV, sizeof(cvarV));

	for (int i=0; i<ExplodeString(cvarV, ",", g_strChatCommand, sizeof(g_strChatCommand), sizeof(g_strChatCommand[])); i++)
	{
		LogMessage("[FF2boss] Added chat command: %s", g_strChatCommand[i]);
		g_iChatCommand++;
	}
}

public Action Listener_Say(int client, const char[] command, int argc)
{
	if(!IsValidClient(client)) return Plugin_Continue;

	char strChat[100];
	char temp[2][64];
	GetCmdArgString(strChat, sizeof(strChat));

	int start;

	if(strChat[start] == '"') start++;
	if(strChat[start] == '!' || strChat[start] == '/') start++;
	strChat[sizeof(strChat)-1] = '\0';
	ExplodeString(strChat, " ", temp, 2, 64, true);


	for (int i=0; i<=g_iChatCommand; i++)
	{
		if(StrEqual(temp[0], g_iChatCommand[i], true))
		{
			if(temp[1][0]!='\0')
			{
				CheckBossName(client, temp[1]);
				return Plugin_Handled;
			} // !보스 (ㅁㄴㅁㄴㅁ)
			Command_SetMyBoss(client, 0);
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action FF2_OnAddQueuePoints(add_points[MAXPLAYERS+1])
{
		char CookieV[MAX_NAME];
		int queuepoints;

		for (int client=1; client<=MaxClients; client++)
		{
			if(IsValidClient(client) && !IsBoss(client))
			{
				GetClientCookie(client, g_hBossQueue, CookieV, sizeof(CookieV));
				StringToInt(CookieV, queuepoints);
				if(queuepoints >= 0)
				{
					LogMessage("이 클라이언트는 %d의 대기포인트를 저장해놓은 상태.", queuepoints);
					add_points[client]=0;
				}
			}
		}
		return Plugin_Changed;
}


public void OnClientPutInServer(client)
{
	char CookieV[MAX_NAME];

	if(!AreClientCookiesCached(client))
	{
		SetClientCookie(client, g_hBossCookie, "");
		IntToString(-1, CookieV, sizeof(CookieV));
		SetClientCookie(client, g_hBossQueue, CookieV);
	}
	else
	{
		GetClientCookie(client, g_hBossCookie, CookieV, sizeof(CookieV));

		strcopy(Incoming[client], sizeof(Incoming[]), CookieV);
	}
}

public Action Command_SetMyBoss(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "ff2boss_ingame_only");
		return Plugin_Handled;
	}

	if (!CheckCommandAccess(client, "ff2_boss", 0, true))
	{
		ReplyToCommand(client, "[SM] %t", "ff2boss_noaccess");
		return Plugin_Handled;
	}

	// char spclName[MAX_NAME];
	// Handle BossKV;
	char CookieV[MAX_NAME];
	int queuepoints;

	if(args)
	{
		char bossName[64];
		GetCmdArgString(bossName, sizeof(bossName));

		CheckBossName(client, bossName);
/*
		for (new i = 0; (BossKV=FF2_GetSpecialKV(i,true)); i++)
		{
			if (KvGetNum(BossKV, "blocked",0)) continue;
			if (KvGetNum(BossKV, "hidden",0)) continue;
			KvGetString(BossKV, "name", spclName, sizeof(spclName));

			if(StrContains(bossName, spclName, false)!=-1)
			{
				strcopy(Incoming[client], sizeof(Incoming[]), spclName);

				CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
				return Plugin_Handled;
			}

			KvGetString(BossKV, "filename", spclName, sizeof(spclName));
			if(StrContains(bossName, spclName, false)!=-1)
			{
				KvGetString(BossKV, "name", spclName, sizeof(spclName));
				strcopy(Incoming[client], sizeof(Incoming[]), spclName);

				CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
				return Plugin_Handled;
			}
		}
		CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossnotfound");
*/
		return Plugin_Handled;
	}

	GetClientCookie (client, g_hBossCookie, CookieV, sizeof(CookieV));
	char s[MAX_NAME];

	Handle dMenu = CreateMenu(Command_SetMyBossH);

	if(StrEqual(CookieV, ""))
	{
		Format(s, sizeof(s), "%t", "ff2boss_random_option");
		SetMenuTitle(dMenu, "%t", "ff2boss_title", s);
	}
	else
	{
//		GetClientCookie(client, g_hBossQueue, CookieV, sizeof(CookieV));
		StringToInt(CookieV, queuepoints);

		Format(s, sizeof(s), queuepoints>=0 ? "%s" : "%t", queuepoints>=0 ? Incoming[client] : "ff2boss_none_1");
		SetMenuTitle(dMenu, "%t", "ff2boss_title", s);
	}

	Format(s, sizeof(s), "%t", "ff2boss_random_option");
	AddMenuItem(dMenu, "Random Boss", s);
	Format(s, sizeof(s), "%t", "ff2boss_none_1");
	AddMenuItem(dMenu, "None", s, ITEMDRAW_DISABLED);


	for (int i=0; (BossKV=FF2_GetSpecialKV(i,true)); i++)
	{
		if (KvGetNum(BossKV, "blocked",0)) continue;
		if (KvGetNum(BossKV, "hidden",0)) continue;
		KvGetString(BossKV, "name", spclName, 64);
		AddMenuItem(dMenu,spclName,spclName);
	}
	SetMenuExitButton(dMenu, true);
	DisplayMenu(dMenu, client, 90);
	return Plugin_Handled;
}


public Command_SetMyBossH(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}

		case MenuAction_Select:
		{
			char CookieV[MAX_NAME];
			switch(param2)
			{
				case 0:
				{
					Incoming[param1] = "";

					SetClientCookie(param1, g_hBossCookie, Incoming[param1]);
					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_randomboss");

				//	GetClientCookie(param1, g_hBossQueue, CookieV, sizeof(CookieV));
				//	LogMessage("client index: %d, g_hBossQueue: %s", param1, CookieV);
				// 	QueuePointRestore(param1);
				}
				case 1:
				{
					int queuepoints;
					queuepoints = FF2_GetQueuePoints(param1);

					IntToString(queuepoints, CookieV, sizeof(CookieV));
			//		SetClientCookie(param1, g_hBossQueue, CookieV);
					FF2_SetQueuePoints(param1, -1);

					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_none");
				}
				default:
				{
					char ForLog[MAX_NAME];
					GetMenuItem(menu, param2, ForLog, sizeof(ForLog));
					LogMessage("선택한 보스 이름: %s", ForLog);

					GetMenuItem(menu, param2, Incoming[param1], sizeof(Incoming[]));

					SetClientCookie(param1, g_hBossCookie, Incoming[param1]);
					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_bossselected", Incoming[param1]);

				//	QueuePointRestore(param1);

		//			GetClientCookie(param1, g_hBossQueue, CookieV, sizeof(CookieV));
	//		LogMessage("client index: %d, g_hBossQueue: %s", param1, CookieV);
				}
			}
		}
	}
}

stock void CheckBossName(int client, const char[] bossName)
{
	Handle BossKV;
	char spclName[MAX_NAME];

	for (new i = 0; (BossKV=FF2_GetSpecialKV(i,true)); i++)
	{
		if (KvGetNum(BossKV, "blocked",0)) continue;
		if (KvGetNum(BossKV, "hidden",0)) continue;
		KvGetString(BossKV, "name", spclName, sizeof(spclName));

		if(StrContains(bossName, spclName, false)!=-1)
		{
			strcopy(Incoming[client], sizeof(Incoming[]), spclName);
			SetClientCookie(client, g_hBossCookie, Incoming[client]);

			CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
			return;
		}

		KvGetString(BossKV, "filename", spclName, sizeof(spclName));
		if(StrContains(bossName, spclName, false)!=-1)
		{
			KvGetString(BossKV, "name", spclName, sizeof(spclName));
			strcopy(Incoming[client], sizeof(Incoming[]), spclName);
			SetClientCookie(client, g_hBossCookie, Incoming[client]);

			CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
			return;
		}
	}
	CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossnotfound");
}


public Action FF2_OnSpecialSelected(boss, &SpecialNum, char[] SpecialName, bool preset)
{
	if(preset) return Plugin_Continue;

	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if (!boss && !StrEqual(Incoming[client], ""))
	{
		strcopy(SpecialName, sizeof(Incoming[]), Incoming[client]);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock bool IsValidClient(client)
{
	return (0 < client && client < MaxClients && IsClientInGame(client));
}
/*
void QueuePointRestore(int client)
{
	char CookieV[MAX_NAME];
	int queuepoints; GetClientCookie(client, g_hBossQueue, CookieV, sizeof(CookieV));
	StringToInt(CookieV, queuepoints);

	if (!IsValidClient(client) || !(queuepoints >= 0)) return;

	FF2_SetQueuePoints(client, queuepoints);

	IntToString(-1, CookieV, sizeof(CookieV));
	SetClientCookie(client, g_hBossQueue, CookieV);

	CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2_queue_restored");
}
*/

stock bool IsBoss(int client)
{
	return (FF2_GetBossIndex(client) != -1);
}

stock int GetClientQueueCookie(int client)
{
	char CookieV[MAX_NAME];
	GetClientCookie(client, )
}
