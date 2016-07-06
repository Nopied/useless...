#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <morecolors>
#include <freak_fortress_2>
#tryinclude <POTRY>

bool IsLastManStanding=false;
bool IsLastMan[MAXPLAYERS+1];

int top[3];
int BGMCount;
float timeleft;

Handle MusicKV;
Handle LastManData;
Handle DrawGameTimer; // Same FF2's DrawGameTimer.

float NoEnemyTime[MAXPLAYERS+1];

public Plugin:myinfo=
{
    name="Freak Fortress 2 : Deathmatch Mod",
    author="Nopied",
    description="....",
    version="0.1",
};

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
    HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_Pre);
    HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Pre);
    // TODO: pass 커맨드 구현.

    LoadTranslations("freak_fortress_2.phrases");
}

public void OnMapStart()
{
  if(MusicKV != INVALID_HANDLE)
  {
    CloseHandle(MusicKV);
    MusicKV=INVALID_HANDLE;
  }
  PrecacheMusic();
}

public Action OnRoundStart(Handle event, const char[] name, bool dont)
{
    CreateTimer(10.4, RoundStarted, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStarted(Handle timer)
{
    if(FF2_GetRoundState() != 1) return Plugin_Continue;

    if(CheckAlivePlayers() <= 2){ // TODO: 커스터마이즈
        CPrintToChatAll("{olive}[FF2]{default} {green}최소 %d명{default}이 있어야 타이머가 작동됩니다.", 2);
        return Plugin_Continue;
    }

    timeleft=float(CheckAlivePlayers()*15)+60.0;
    DrawGameTimer=CreateTimer(0.1, OnTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dont)
{
    int client=GetClientOfUserId(GetEventInt(event, "userid"));

    if(FF2_GetRoundState() == 1 && IsLastManStanding && !IsLastMan[client])
    {
        CreateTimer(0.1, BeLastMan);
    }
}

public Action OnRoundEnd(Handle event, const char[] name, bool dont)
{
    for(int client=1; client<=MaxClients; client++)
    {
        if(IsLastMan[client] || IsBoss(client)) // Lastman and bosses.
        {
            IsLastMan[client]=false;

            SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
            SDKUnhook(client, SDKHook_PreThinkPost, NoEnemyTimer);
        }
    }
    IsLastManStanding=false;
    if(DrawGameTimer!=INVALID_HANDLE) // What?
    {
        KillTimer(DrawGameTimer);
        DrawGameTimer=INVALID_HANDLE;
    }
    return Plugin_Continue;
}

public Action:OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if(!IsLastManStanding || FF2_GetRoundState() != 1)
    {
        SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage);
        return Plugin_Continue;
    }
    if(IsBoss(attacker) || !IsBoss(victim)) return Plugin_Continue;

    bool changed=false;
    if(IsValidEntity(weapon))
    {
        int boss=FF2_GetBossIndex(victim);
        char classname[60];
        float bossPosition[3];


        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", bossPosition);
        GetEntityClassname(weapon, classname, sizeof(classname));

        if(!StrContains(classname, "tf_weapon_knife") && !(damagecustom & TF_CUSTOM_BACKSTAB))
        {
            damagetype|=DMG_CRIT;
            damage=((float(FF2_GetBossMaxHealth(boss))*float(FF2_GetBossMaxLives(boss)))*0.06)/3.0;

            EmitSoundToClient(victim, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, bossPosition, _, false);
            EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, bossPosition, _, false);
            EmitSoundToClient(victim, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
            EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
            SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+2.0);
            SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime()+2.0);
            SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+2.0);

            int viewmodel=GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
            if(viewmodel>MaxClients && IsValidEntity(viewmodel) && TF2_GetPlayerClass(attacker)==TFClass_Spy)
            {
                int melee=GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
                int animation=41;
                switch(melee)
                {
                    case 225, 356, 423, 461, 574, 649, 1071:  //Your Eternal Reward, Conniver's Kunai, Saxxy, Wanga Prick, Big Earner, Spy-cicle, Golden Frying Pan
                    {
                        animation=15;
                    }
                    case 638:  //Sharp Dresser
                    {
                        animation=31;
                    }
                }
                SetEntProp(viewmodel, Prop_Send, "m_nSequence", animation);
            }

            if(!(FF2_GetFF2flags(attacker) & FF2FLAG_HUDDISABLED))
      			{
      				PrintHintText(attacker, "%t", "Backstab");
      			}
      			if(!(FF2_GetFF2flags(victim) & FF2FLAG_HUDDISABLED))
      			{
      				PrintHintText(victim, "%t", "Backstabbed");
      			}

            Handle BossKV=FF2_GetSpecialKV(boss);
            char playerName[64];
            char bossName[64];

            GetClientName(attacker, playerName, sizeof(playerName));
            KvRewind(BossKV);
            KvGetString(BossKV, "name", bossName, sizeof(bossName), "ERROR NAME");

            FF2_SetAbilityCooldown(boss, FF2_GetAbilityCooldown(boss)+12.0);

            CPrintToChatAll("{olive}[FF2]{default} %t", "Someone_do", playerName, "페이스스탭", bossName, RoundFloat(damage*(255.0/85.0)));
            CPrintToChatAll("{olive}[FF2]{default} %t", "ff2_slienced", RoundFloat(FF2_GetAbilityCooldown(boss)));
            return Plugin_Changed;
        }
        else if(!StrContains(classname, "tf_weapon_shotgun") && TF2_GetPlayerClass(attacker) == TFClass_Soldier)
        {
            float velocity[3];
            GetEntPropVector(victim, Prop_Data, "m_vecVelocity", velocity);
            velocity[2]+=650.0;
            TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);

            int explosion=CreateEntityByName("env_explosion");

            DispatchKeyValueFloat(explosion, "DamageForce", 0.0);
      		SetEntProp(explosion, Prop_Data, "m_iMagnitude", 0, 4);
      		SetEntProp(explosion, Prop_Data, "m_iRadiusOverride", 400, 4);
      		SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", attacker);
      		DispatchSpawn(explosion);

      		TeleportEntity(explosion, bossPosition, NULL_VECTOR, NULL_VECTOR);
      		AcceptEntityInput(explosion, "Explode");
      		AcceptEntityInput(explosion, "kill");
        }
        else if(!StrContains(classname, "tf_weapon_shotgun") && TF2_GetPlayerClass(attacker) == TFClass_Pyro)
        {
            TF2_IgnitePlayer(victim, attacker);
        }
        else if(!StrContains(classname, "tf_weapon_shovel") && TF2_GetPlayerClass(attacker) == TFClass_Soldier)
        {
          damage=((float(FF2_GetBossMaxHealth(boss))*float(FF2_GetBossMaxLives(boss)))*0.08)/3.0;
          damagetype|=DMG_CRIT;

          EmitSoundToClient(victim, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, bossPosition, _, false);
          EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, bossPosition, _, false);
          EmitSoundToClient(victim, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
          EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);

          Handle BossKV=FF2_GetSpecialKV(boss);
          char playerName[64];
          char bossName[64];

          GetClientName(attacker, playerName, sizeof(playerName));
          KvRewind(BossKV);
          KvGetString(BossKV, "name", bossName, sizeof(bossName), "ERROR NAME");

          CPrintToChatAll("{olive}[FF2]{default} %t", "Someone_do", playerName, "지면 마켓가든", bossName, RoundFloat(damage*(255.0/85.0)));
          return Plugin_Changed; //
        }

        if(damagetype & DMG_BULLET && !(TF2_GetPlayerClass(victim) == TFClass_Sniper || TF2_GetPlayerClass(victim) == TFClass_Heavy))
        {
          changed=true;
          damagetype|=DMG_PREVENT_PHYSICS_FORCE;
        }
    }
    return changed ? Plugin_Changed : Plugin_Continue;
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dont)
{
    if(FF2_GetRoundState() != 1 || IsBossTeam(GetClientOfUserId(GetEventInt(event, "userid"))) || GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
        return Plugin_Continue;

    if(!IsLastManStanding && CheckAlivePlayers() <= 1 && GetClientCount(true) > 2) // 라스트 맨 스탠딩
    {
        IsLastManStanding=true;
        int bosses[MAXPLAYERS+1];
        int topDamage[3];
        int totalDamage;
        int bossCount;

        for(int client=1; client<=MaxClients; client++)
        {
          if(!IsValidClient(client)) // for bossCount.
      			continue;
          else if(IsBoss(client) && IsPlayerAlive(client)){
            bosses[bossCount++]=client;
            continue;
          }
          else if(IsBossTeam(client)) // FF2_GetClientDamage(client)<=0 ||
            continue;
        }

    	for (int z = 1; z <= GetMaxClients(); z++)
    	{
    		if (IsClientInGame(z) && FF2_GetClientDamage(z) > FF2_GetClientDamage(top[0]))
    		{
                top[0] = z;
    			topDamage[0] = FF2_GetClientDamage(z);
    		}
    	}
    	for (int z = 1; z <= GetMaxClients(); z++)
    	{
    		if (IsClientInGame(z) && FF2_GetClientDamage(z) > FF2_GetClientDamage(top[1]) && z != top[0])
    		{
                top[1] = z;
    			topDamage[1] = FF2_GetClientDamage(z);
    		}
    	}
    	for (int z = 1; z <= GetMaxClients(); z++)
    	{
    		if (IsClientInGame(z) && FF2_GetClientDamage(z) > FF2_GetClientDamage(top[2]) && z != top[1] && z != top[0])
    		{
                top[2] = z;
    			topDamage[2] = FF2_GetClientDamage(z);
    		}
    	}

        for(int i; i<3; i++)
        {
            totalDamage+=topDamage[i];
        }

        int random=GetRandomInt(0, totalDamage);
        int winner;

        for(int i; i<3; i++) // OH this stupid code..
        {
            int tempDamage;
            for (int x=i; x>=0; x--)
            {
                tempDamage+=topDamage[x];
            }

            if(random > tempDamage)
                continue;
            winner=top[i];
            break;
        }

        CPrintToChatAll("{olive}[FF2]{default} 확률: %N - %.2f%% | %N - %.2f%% | %N - %.2f%%",
        top[0], float(topDamage[0])/float(totalDamage)*100.0,
        top[1], float(topDamage[1])/float(totalDamage)*100.0,
        top[2], float(topDamage[2])/float(totalDamage)*100.0
        );
        CPrintToChatAll("%N님이 {red}강력한 무기{default}를 흭득하셨습니다!",
        winner);
        PrintCenterTextAll("%N님이 보스와 최후의 결전을 치루게 됩니다!", winner);

        for(int i; i<bossCount; i++)
        {
            int boss=FF2_GetBossIndex(bosses[i]);
            int newhealth=7500/bossCount;

            if(FF2_GetBossHealth(boss) < newhealth){
                FF2_SetBossMaxHealth(boss, newhealth);
                FF2_SetBossHealth(boss, newhealth);
            }
            FF2_SetBossCharge(boss, 0, 0.0);
            FF2_SetBossLives(boss, 1);
            FF2_SetBossMaxLives(boss, 1);
            SDKHook(bosses[i], SDKHook_OnTakeDamage, OnTakeDamage);
        }

        IsLastMan[winner]=true;
        NoEnemyTime[winner]=GetGameTime()+10.0;
        SDKHook(winner, SDKHook_OnTakeDamage, OnTakeDamage);
        SDKHook(winner, SDKHook_PreThinkPost, NoEnemyTimer);
        timeleft=120.0;

        if(DrawGameTimer==INVALID_HANDLE)
            DrawGameTimer=CreateTimer(0.1, OnTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

        if(GetEventInt(event, "userid") == GetClientUserId(winner))
        {
            int forWinner=FindAnotherPerson(winner);

            LastManData=CreateDataPack(); // In this? data = winner | forWinner | team | IsAlive

            WritePackCell(LastManData, winner);
            WritePackCell(LastManData, forWinner);
            WritePackCell(LastManData, GetClientTeam(forWinner));

            if(IsPlayerAlive(forWinner))
            {
                WritePackCell(LastManData, 1);
                CreateTimer(0.4, BeLastMan);
                TF2_AddCondition(forWinner, TFCond_Bonked, 0.4);
            }
            else // Yeah. then it said. Not Alive.
            {
                WritePackCell(LastManData, 0);
                TF2_ChangeClientTeam(forWinner, TF2_GetClientTeam(winner));
                TF2_RespawnPlayer(forWinner);
            }
            ResetPack(LastManData);

            FF2_StartMusic(); // Call FF2_OnMusic
            FF2_LoadMusicData(MusicKV);
            return Plugin_Continue;
        }

        TF2_RespawnPlayer(winner);
        TF2_AddCondition(winner, TFCond_Ubercharged, 10.0);
        TF2_AddCondition(winner, TFCond_Stealthed, 10.0);
        TF2_AddCondition(winner, TFCond_SpeedBuffAlly, 10.0);
        GiveLastManWeapon(winner);

        SetEntProp(winner, Prop_Data, "m_takedamage", 0);
        SetEntProp(winner, Prop_Send, "m_CollisionGroup", 1);

        SetEntProp(winner, Prop_Send, "m_iHealth", GetEntProp(winner, Prop_Data, "m_iMaxHealth"));
        SetEntProp(winner, Prop_Data, "m_iHealth", GetEntProp(winner, Prop_Data, "m_iMaxHealth"));
        CreateTimer(10.0, LastManPassive, winner, TIMER_FLAG_NO_MAPCHANGE);

        FF2_SetServerFlags(FF2SERVERFLAG_ISLASTMAN|FF2SERVERFLAG_UNCHANGE_BOSSBGM_USER|FF2SERVERFLAG_UNCHANGE_BOSSBGM_SERVER);
        FF2_StartMusic(); // Call FF2_OnMusic
        FF2_LoadMusicData(MusicKV);
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

public Action OnTimer(Handle timer)
{
    if(FF2_GetRoundState() != 1 || timeleft < 0.0)
    {
        return Plugin_Stop;
    }
    Handle timeleftHUD=CreateHudSynchronizer();
    timeleft-=0.1;
    char timeDisplay[6];

	if(RoundFloat(timeleft)/60>9)
	{
		IntToString(time/60, timeDisplay, sizeof(timeDisplay));
	}
	else
	{
		Format(timeDisplay, sizeof(timeDisplay), "0%i", RoundFloat(timeleft)/60);
	}

	if(RoundFloat(timeleft)%60>9)
	{
		Format(timeDisplay, sizeof(timeDisplay), "%s:%i", timeDisplay, RoundFloat(timeleft)%60);
	}
	else
	{
		Format(timeDisplay, sizeof(timeDisplay), "%s:0%i", timeDisplay, RoundFloat(timeleft)%60);
	}

    if(timeleft<60.0)
    {
        Format(timeDisplay, sizeof(timeDisplay), "%.1f초", timeDisplay, timeleft));
    }

	SetHudTextParams(-1.0, 0.17, 0.15, 255, 255, 255, 255);
	for(new client; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			FF2_ShowSyncHudText(client, timeleftHUD, timeDisplay);
		}
	}

    switch(RoundFloat(timeleft))
	{
		case 300:
		{
            // if(IsSoundPrecached())
			EmitSoundToAll("vo/announcer_ends_5min.mp3");
		}
		case 120:
		{
			EmitSoundToAll("vo/announcer_ends_2min.mp3");
		}
		case 60:
		{
			EmitSoundToAll("vo/announcer_ends_60sec.mp3");
		}
		case 30:
		{
			EmitSoundToAll("vo/announcer_ends_30sec.mp3");
		}
		case 10:
		{
			EmitSoundToAll("vo/announcer_ends_10sec.mp3");
		}
		case 1, 2, 3, 4, 5:
		{
			decl String:sound[PLATFORM_MAX_PATH];
			Format(sound, PLATFORM_MAX_PATH, "vo/announcer_ends_%isec.mp3", time);
			EmitSoundToAll(sound);
		}
		case 0:
		{
            DrawGameTimer=INVALID_HANDLE;

            if(IsLastManStanding)
            {
                CPrintToChatAll("{olive}[FF2]{default} 제한시간이 끝나 보스가 승리합니다.");
                ForceTeamWin(FF2_GetBossTeam());
                return Plugin_Stop;
            }

            CPrintToChatAll("{olive}[FF2]{default} 제한시간이 끝나 보스가 승리합니다.");
            ForceTeamWin(FF2_GetBossTeam());
            // TODO: 다른 서든데스.
			return Plugin_Stop;
		}
    return Plugin_Continue;
}

public void NoEnemyTimer(int client)
{
  if(NoEnemyTime[client]>GetGameTime() && IsClientInGame(client) && IsPlayerAlive(client))
  {
    for(int target=1; target<=MaxClients; target++)
    {
      if(IsClientInGame(target) && IsPlayerAlive(target) && IsBossTeam(target))
      {
        float pos[3];
        float enemyPos[3];

        GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
        GetEntPropVector(target, Prop_Send, "m_vecOrigin", enemyPos);

        if(GetVectorDistance(pos, enemyPos) <= 150.0)
        {
          PushClientsApart(target, client);
          PrintCenterText(target, "라스트맨이 현재 무적상태이므로 잠시 동안 가까이 갈 수 없습니다.");
        }
      }
    }
  }
}

public Action BeLastMan(Handle timer)
{
    FF2_SetServerFlags(FF2SERVERFLAG_ISLASTMAN|FF2SERVERFLAG_UNCHANGE_BOSSBGM_USER|FF2SERVERFLAG_UNCHANGE_BOSSBGM_SERVER);
    if(!LastManData || !IsPackReadable(LastManData, 4))
    {
      Debug("LastManData is invalid! what!?!?");
      return Plugin_Continue;
    }
    int winner=ReadPackCell(LastManData);
    int client=ReadPackCell(LastManData);
    TFTeam team=view_as<TFTeam>(ReadPackCell(LastManData));
    bool alive=ReadPackCell(LastManData);

    TF2_RespawnPlayer(winner);
    TF2_AddCondition(winner, TFCond_Ubercharged, 10.0);
    TF2_AddCondition(winner, TFCond_Stealthed, 10.0);
    TF2_AddCondition(winner, TFCond_SpeedBuffAlly, 10.0);
    GiveLastManWeapon(winner);

    SetEntProp(winner, Prop_Data, "m_takedamage", 0);
    SetEntProp(winner, Prop_Send, "m_CollisionGroup", 1);

    SetEntProp(winner, Prop_Send, "m_iHealth", GetEntProp(winner, Prop_Data, "m_iMaxHealth"));
    SetEntProp(winner, Prop_Data, "m_iHealth", GetEntProp(winner, Prop_Data, "m_iMaxHealth"));
    CreateTimer(10.0, LastManPassive, winner, TIMER_FLAG_NO_MAPCHANGE);

    if(alive)
    {
        TF2_ChangeClientTeam(client, team);
    }
    else
    {
        TF2_ChangeClientTeam(client, TFTeam_Spectator);
        TF2_ChangeClientTeam(client, view_as<TFTeam>(team));
    }
    CloseLastmanData();
    return Plugin_Continue;
}

public Action LastManPassive(Handle timer, int client)
{
  SetEntProp(client, Prop_Data, "m_takedamage", 2);
  SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);
}

public void OnClientDisconnect(int client)
{
    if(IsLastMan[client] || IsBoss(client))
    {
        IsLastMan[client]=false;
        SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}


public Action FF2_OnMusic(char path[PLATFORM_MAX_PATH], float &time, char artist[80], char name[100], bool &notice, int client, int selected)
{
  if(IsLastManStanding && BGMCount)
  {
    int random=GetRandomInt(1, BGMCount);
    char tempItem[35];
    char tempPath[PLATFORM_MAX_PATH];
    char tempArtist[80];
    char tempName[100];

    if(!MusicKV || selected)
    {
      // Debug("MusicKV: %s, selected: %s", MusicKV ? "valid" : "Invalid", selected ? "true" : "false");
      return Plugin_Continue;
    }
    KvRewind(MusicKV);
    if(KvJumpToKey(MusicKV, "sound_bgm"))
    {
      Format(tempItem, sizeof(tempItem), "time%i", random);
      time=KvGetFloat(MusicKV, tempItem);

      Format(tempPath, sizeof(tempPath), "path%i", random);
      KvGetString(MusicKV, tempPath, tempPath, sizeof(tempPath));
      Format(path, sizeof(path), "%s", tempPath);

      Format(tempArtist, sizeof(tempArtist), "artist%i", random);
      KvGetString(MusicKV, tempArtist, tempArtist, sizeof(tempArtist));
      Format(artist, sizeof(artist), "%s", tempArtist);

      Format(tempName, sizeof(tempName), "name%i", random);
      KvGetString(MusicKV, tempName, tempName, sizeof(tempName));
      Format(name, sizeof(name), "%s", tempName);

      return Plugin_Changed;
    }
  }
  return Plugin_Continue;
}

stock int FindAnotherPerson(int Gclient)
{
    int count;
    int validTarget[MAXPLAYERS+1];

    for(int client=1; client<=MaxClients; client++)
    {
        if(IsValidClient(client) && client != Gclient && !IsBoss(client))
        {
            validTarget[count++]=client;
        }
    }

    if(!count)
    {
        return CreateFakeClient("sorry. I can't find target.");
    }
    return validTarget[GetRandomInt(0, count-1)];
}

stock void GiveLastManWeapon(int client)
{
  TF2_RemoveAllWeapons(client);

  switch(TF2_GetPlayerClass(client))
  {
    case TFClass_Scout:
    {
      SpawnWeapon(client, "tf_weapon_scattergun", 200, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 97 ; 0.4 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_pistol", 209, 0, 2, "2 ; 1.6 ; 97 ; 0.4 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_bat", 30667, 0, 2, "2 ; 4.0 ; 112 ; 1.0 ; 26 ; 150");
      // 2: 피해량 향상
      // 97: 재장전 향상
      // 6: 발사 속도 향상
    }
    case TFClass_Sniper:
    {
      SpawnWeapon(client, "tf_weapon_sniperrifle", 201, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 3.5 ; 390 ; 3.0");
      SpawnWeapon(client, "tf_weapon_smg", 203, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 2.5 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_club", 264, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 4.0 ; 112 ; 1.0 ; 26 ; 150");
      // 390: 헤드샷 보너스 데미지
    }
    case TFClass_Soldier:
    {
      SpawnWeapon(client, "tf_weapon_rocketlauncher", 205, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 2.5 ; 6 ; 0.4 ; 97 ; 0.4 ; 103 ; 1.2 ; 135 ; 1.3 ; 488 ; 1.0 ; 521 ; 2.0");
      SpawnWeapon(client, "tf_weapon_shotgun_soldier", 15016, 0, 2, "2 ; 2.0 ; 97 ; 0.4 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_shovel", 416, 0, 2, "2 ; 4.0 ; 112 ; 1.0 ; 26 ; 150");
      // 103: 투사체 비행속도 향상
      // 135: 로켓점프 피해량 감소
      // 488: 로켓 특화
      // 521: 연기
    }
    case TFClass_DemoMan:
    {
      SpawnWeapon(client, "tf_weapon_grenadelauncher", 206, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 671 ; 1.0 ; 103 ; 1.3 ; 135 ; 1.3 ; 6 ; 0.4 ; 97 ; 1.3");
      SpawnWeapon(client, "tf_weapon_pipebomblauncher", 207, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 6 ; 0.4 ; 97 ; 0.7");
      SpawnWeapon(client, "tf_weapon_sword", 132, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 2.2 ; 540 ; 1.0 ; 97 ; 0.4 ; 6 ; 0.4 ; 112 ; 1.0 ; 26 ; 150");
      // 540:아이랜더 효과로 추정됨..
      //changeMelee=false;
    }
    case TFClass_Medic:
    {
      SpawnWeapon(client, "tf_weapon_syringegun_medic", 36, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 17 ; 0.12 ; 97 ; 1.3");
      SpawnWeapon(client, "tf_weapon_medigun", 211, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 482 ; 4.0 ; 493 ; 4.0");
      SpawnWeapon(client, "tf_weapon_bonesaw", 1071, 0, 2, "2 ; 4.0 ; 17 ; 0.40 ; 112 ; 1.0 ; 26 ; 150");
      // 17: 적중 시 우버차지
      // 482: 오버힐 마스터리
      // 493: 힐 마스터리
    }
    case TFClass_Heavy:
    {
      SpawnWeapon(client, "tf_weapon_minigun", 202, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.3 ; 87 ; 0.6 ; 6 ; 1.1");
      SpawnWeapon(client, "tf_weapon_shotgun_hwg", 15016, 0, 2, "2 ; 2.3 ; 87 ; 0.4 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_fists", 1071, 0, 2, "2 ; 4.0 ; 112 ; 1.0 ; 26 ; 150");
      // 87: 미니건 돌리는 속도 증가
      //
    }
    case TFClass_Pyro:
    {
      SpawnWeapon(client, "tf_weapon_flamethrower", 208, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 3.0");
      SpawnWeapon(client, "tf_weapon_shotgun_pyro", 15016, 0, 2, "2 ; 2.2 ; 97 ; 0.4 ; 6 ; 0.4");
      SpawnWeapon(client, "tf_weapon_fireaxe", 38, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 178 ; 0.2 ; 112 ; 1.0 ; 26 ; 150");
      //changeMelee=false;
      // 178: 무기 바꾸는 속도 향상
    }
    case TFClass_Spy:
    {
      SpawnWeapon(client, "tf_weapon_revolver", 61, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 3.5 ; 51 ; 1.0 ; 390 ; 5.0");
      SpawnWeapon(client, "tf_weapon_knife", 194, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 3.0 ; 112 ; 1.0 ; 26 ; 150");
      int sapper = SpawnWeapon(client, "tf_weapon_sapper", 735, 0, 2, _);

      SetEntProp(sapper, Prop_Send, "m_iObjectType", 3);
      SetEntProp(sapper, Prop_Data, "m_iSubType", 3);
      SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
      SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
      SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
      SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);

      SpawnWeapon(client, "tf_weapon_invis", 30, 0, 2, "35 ; 1.8");
      // 51: 헤드샷 판정 가능
    }
    case TFClass_Engineer:
    {
      SpawnWeapon(client, "tf_weapon_sentry_revenge", 141, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 1.6 ; 97 ; 0.4 ; 6 ; 0.4 ; 136 ; 1.0");
      SpawnWeapon(client, "tf_weapon_wrench", 197, 0, 2, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 3.0 ; 124 ; 1.0 ; 343 ; 0.2 ; 344 ; 1.3 ; 464 ; 3.0 ; 112 ; 100.0 ; 286 ; 5.0 ; 287 ; 1.5 ; 80 ; 8.0 ; 26 ; 150");
      SpawnWeapon(client, "tf_weapon_laser_pointer", 140, 0, 2, _);
      SpawnWeapon(client, "tf_weapon_pda_engineer_build", 25, 0, 2, "351 ; 100.0 ; 344 ; 100.0 ; 345 ; 6.0");
      int pda = SpawnWeapon(client, "tf_weapon_builder", 28, 0, 2, _);
      SetEntProp(pda, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
      SetEntProp(pda, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
      SetEntProp(pda, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
      SetEntProp(pda, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
      SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 0, 2, _);
      //changeMelee=false;
      // 113: 금속 리젠
      // 80: 최대 금속량
      // 124: 미니 센트리 설정
      // 136: 센트리 복수
      // 286: 건물 체력
      // 287: 센트리 공격력
      // 343: 센트리 발사 속도
      // 344: 센트리 사정 거리
      // 464: 센트리 짓는 속도
    }
  }
/*  if(changeMelee)
    SpawnWeapon(client, "tf_weapon_bottle", 1071, 0, 1, "2027 ; 1 ; 2022 ; 1 ; 542 ; 1 ; 2 ; 4.0");
*/

}

void PrecacheMusic()
{
  char config[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, config, sizeof(config), "configs/ff2_lastman.cfg");

  if(!FileExists(config))
  {
    return;
  }
  if(MusicKV==INVALID_HANDLE)
  {
    BGMCount=0;
    MusicKV=CreateKeyValues("lastmanstanding");
    FileToKeyValues(MusicKV, config);
    KvRewind(MusicKV);
    if(!KvJumpToKey(MusicKV, "sound_bgm"))
    {
      LogMessage("No BGM found!");
      return;
    }

    char path[PLATFORM_MAX_PATH];
    char item[20];

    for(int i=1; ; i++)
    {
      Format(item, sizeof(item), "path%i", i);
      KvGetString(MusicKV, item, path, sizeof(path), "");

      if(!path[0]) break;

      char temp[PLATFORM_MAX_PATH];
      Format(temp, sizeof(temp), "sound/%s", path);

      if(!FileExists(temp, true))
      {
        LogMessage("파일이 감지되지 않아 path%i에서 검색을 멈췄습니다.", BGMCount);
        break;
      }
      AddFileToDownloadsTable(temp);
      PrecacheSound(path, true);

      BGMCount++;
    }
  }
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute="")
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2=0;
		for(int i=0; i<count; i+=2)
		{
			int attrib=StringToInt(attributes[i]);
			if(attrib==0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if(weapon==INVALID_HANDLE)
	{
		return -1;
	}
	int entity=TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock void CloseLastmanData()
{
    CloseHandle(LastManData);
}

stock bool IsValidClient(int client)
{
    return (0<client && client<=MaxClients && IsClientInGame(client));
}

stock int CheckAlivePlayers() // Without bosses. LOL
{
    int alive=0;

    for(int i=1; i<=MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && FF2_GetBossTeam() != GetClientTeam(i))
            alive++;
    }

    return alive;
}

stock int GetIndexOfWeaponSlot(int client, int slot)
{
	int weapon=GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == GetClientTeam(client);
}

stock PushClientsApart(int iClient1, int iClient2) // Copied from Chdata's Fixed Friendly Fire
{
    // SetEntProp(iClient1, Prop_Send, "m_CollisionGroup", 2);     // No collision with players and certain projectiles
    // SetEntProp(iClient2, Prop_Send, "m_CollisionGroup", 2);

    float vVel[3];

    float vOrigin1[3];
    float vOrigin2[3];

    GetEntPropVector(iClient1, Prop_Send, "m_vecOrigin", vOrigin1);
    GetEntPropVector(iClient2, Prop_Send, "m_vecOrigin", vOrigin2);

    MakeVectorFromPoints(vOrigin1, vOrigin2, vVel);
    NormalizeVector(vVel, vVel);
    ScaleVector(vVel, -300.0);               // Set to 15.0 for a black hole effect

    vVel[1] += 0.1;                         // This is just a safeguard for sm_tele
    vVel[2] = 0.0;                          // Negate upwards push. += 280.0; for extra upwards push (can have sort of a fan/vent effect)

    new iBaseVelocityOffset = FindSendPropOffs("CBasePlayer","m_vecBaseVelocity");
    SetEntDataVector(iClient1, iBaseVelocityOffset, vVel, true);
}

stock ForceTeamWin(int team)
{
	new entity=FindEntityByClassname2(-1, "team_control_point_master");
	if(!IsValidEntity(entity))
	{
		entity=CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetWinner");
}
