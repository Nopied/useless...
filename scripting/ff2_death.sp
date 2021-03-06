//////////////////////
//Table of contents://
////// Defines ///////
////// Events  ///////
///// Abilities //////
////// Timers  ///////
////// Stocks  ///////
//////////////////////

//////////// Plugin inits
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#undef REQUIRE_PLUGIN
#tryinclude <ff2_dynamic_defaults>
#tryinclude <morecolors>
#define REQUIRE_PLUGIN
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

public Plugin myinfo = {
	name	= "Freak Fortress 2: Deathreus Boss Pack",
	author	= "Deathreus",
	version = "1.5"
};



/////////////////////////////////////////
//Defines some terms used by the plugin//
/////////////////////////////////////////

#define IsEmptyString(%1) (%1[0]==0)
#define FAR_FUTURE 100000000.0

#define HUD_INTERVAL 0.2
#define HUD_LINGER 0.01
#define HUD_ALPHA 192
#define HUD_R_OK 255
#define HUD_G_OK 255
#define HUD_B_OK 255
#define HUD_R_ERROR 225
#define HUD_G_ERROR 64
#define HUD_B_ERROR 64

int BossTeam = view_as<int>(TFTeam_Blue);
int MercTeam = view_as<int>(TFTeam_Red);
int g_Boss;
int MJT_ButtonType;		// Shared between Magic Jump and Magic Teleport as 4th argument, or Jump Manager as 2nd

/* Rage_Wanker */
int WankerPissMode[MAXPLAYERS+1];						//1
int WankerAmmo[MAXPLAYERS+1];							//2

float WankerPissDuration[MAXPLAYERS+1]; 				//3

/* Rage_TheRock */
float RockRageDuration[MAXPLAYERS+1];					//1

/* Rage_Mine */
int FruitCanRemoveSentry[MAXPLAYERS+1];					//2
float FruitRageRange[MAXPLAYERS+1];						//1

/* Charge_RocketSpawn */
int RocketRequiredRage[MAXPLAYERS+1];					//8

float RocketCharge[MAXPLAYERS+1];						//1
float RocketCooldown[MAXPLAYERS+1];						//2
float RocketSpeed[MAXPLAYERS+1];						//3
float RocketDamage[MAXPLAYERS+1];						//6
float RocketStunTime[MAXPLAYERS+1];						//7

char RocketModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];		//4
char RocketParticle[MAXPLAYERS+1][PLATFORM_MAX_PATH];	//5

Handle chargeHUD = INVALID_HANDLE;

/* Heffe_Reincarn_Rapture */
#define MODEL_TRIGGER			"models/items/ammopack_small.mdl"

#define RAPTURE_STUN_DELAY		1.0
#define RAPTURE_BEAM_LENGTH		1000.0
#define RAPTURE_BEAM_MINS		{-50.0, -50.0, 0.0}
#define RAPTURE_BEAM_MAXS	 	{50.0, 50.0, 1000.0}

int RaptureIteration;					// 1
int RaptureBlindTime;					// 9
int g_Update[MAXPLAYERS+1];				// Internal
int g_Smoke;							// Internal
int g_Glow;								// Internal
int g_Laser;							// Internal

float RaptureTimer;						// 2
float RaptureRadius;					// 3
float RaptureVel;						// 4
float RaptureDmg;						// 5
float RaptureStunTime;					// 7
float RaptureDuration;					// 8
float RaptureSlayRatio;					// 10
float DiedRapture[MAXPLAYERS+1];		// Internal

char RapturePush[6];					// 6

/* Rage_Heffe */
#define SOUND_THUNDER 			"ambient/explosions/explode_9.wav"

int g_iSmiteNumber;						// 3
int g_iButtonType;						// 4
int g_SmokeSprite;						// Internal
int g_LightningSprite;					// Internal

float HeffeStunDuration;				// 2
float HeffeRange;						// 1

Handle heffeHUD = INVALID_HANDLE;

/* DOT_Heffe_Jump */
int FlapForce;							// 2

float HeffeUpdateHUD[MAXPLAYERS+1];		// Internal
float FlapDrain;						// 1
float FlapRate;							// 3

char FlapSound[PLATFORM_MAX_PATH];		// 4

bool g_bButtonPressed = false;			// Internal

Handle jumpHUD = INVALID_HANDLE;

/* Special_PocketMedic */
bool MedicJumpWeaponPreference[MAXPLAYERS+1];
bool MedicTeleWeaponPreference[MAXPLAYERS+1];

/* Rage_SkeleSummon */
int SkeleNumberOfSpawns[MAXPLAYERS+1];				// 1

/* Charge_MagicJump */			// Intended for gaining height
float MJ_ChargeTime[MAXPLAYERS+1];					// 1
float MJ_Cooldown[MAXPLAYERS+1];					// 2
float MJ_OnCooldownUntil[MAXPLAYERS+1];				// Internal, set by arg3
float MJ_CrouchOrAltFireDownSince[MAXPLAYERS+1];	// Internal

bool MJ_EmergencyReady[MAXPLAYERS+1];				// Internal

/* Charge_MegicTele */			// Intended for catching fast players
float MT_ChargeTime[MAXPLAYERS+1];					// 1
float MT_Cooldown[MAXPLAYERS+1];					// 2
float MT_OnCooldownUntil[MAXPLAYERS+1];				// Internal, set by arg3
float MT_CrouchOrAltFireDownSince[MAXPLAYERS+1];	// Internal

bool MT_EmergencyReady[MAXPLAYERS+1];				// Internal

/* Special_JumpManager */
int JM_ButtonType;									// 1

bool JM_AbilitySwitched[MAXPLAYERS+1];				// Internal

float WitchDoctorUpdateHUD[MAXPLAYERS+1];			// Internal

Handle witchdoctorHUD;

/* Special_SpellAttack */
float SS_CoolDown[MAXPLAYERS+1];					// 1

/* Rage_MLG */
float MLGRageTime;
bool enableMLG[MAXPLAYERS+1];

//////////// FF2 inits
public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);

	HookUserMessage(GetUserMessageId("PlayerJarated"), Event_Jarate);

	LoadTranslations("freak_fortress_2.phrases");
	LoadTranslations("ff2_1st_set.phrases");

	heffeHUD = CreateHudSynchronizer();
	jumpHUD = CreateHudSynchronizer();
	chargeHUD = CreateHudSynchronizer();
	witchdoctorHUD = CreateHudSynchronizer();
}

public void FF2_OnAbility2(int Boss, const char[] pluginName, const char[] abilityName, int iStatus)
{
	int iSlot = FF2_GetAbilityArgument(Boss, pluginName, abilityName, 0);
	if (!strcmp(abilityName, "rage_wanker"))
		Rage_Wanker(Boss);
	else if (!strcmp(abilityName, "rage_heffe"))
		Rage_Heffe(Boss, abilityName);
	else if (!strcmp(abilityName, "rage_therock"))
		Rage_TheRock(Boss);
	else if (!strcmp(abilityName, "rage_mine"))
		Rage_Mine(Boss);
	else if (!strcmp(abilityName, "rage_skelesummon"))
		Rage_SkeleSummon(Boss, abilityName);
	else if(!strcmp(abilityName, "charge_projectile"))
		Charge_RocketSpawn(Boss, iSlot, iStatus);
	else if(!strcmp(abilityName, "rage_mlg"))
		Rage_MLG(Boss, abilityName);
}



/////////////////////////////////////
//	Events start below this point  //
/////////////////////////////////////

public void OnMapStart()
{
	PrecacheModel(MODEL_TRIGGER, true);
	g_Laser = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_Smoke = PrecacheModel("materials/effects/fire_cloud1.vmt");
	g_Glow = PrecacheModel("sprites/yellowglow1.vmt", true);

	PrecacheSound(SOUND_THUNDER, true);
	g_SmokeSprite = PrecacheModel("sprites/steam1.vmt");
	g_LightningSprite = PrecacheModel("sprites/lgtning.vmt");
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	BossTeam = FF2_GetBossTeam();
	MercTeam = FF2_GetBossTeam()==3 ? 2 : 3;

	int iBoss;
	for(int iIndex = 0; (iBoss=GetClientOfUserId(FF2_GetBossUserId(iIndex)))>0; iIndex++)
	{
		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_wanker"))
		{
			WankerPissMode[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_wanker", 1) == 1;					// Jarate and bleed or just bleed, 0 = just bleed
			WankerAmmo[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_wanker", 2, 3);
			WankerPissDuration[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_wanker", 3, 10.0);		// Duration of bleed
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "heffe_reincarn_rapture"))
		{
			RaptureIteration = FF2_GetAbilityArgument(iIndex, this_plugin_name, "heffe_reincarn_rapture", 1, 15);			// Number of beams
			RaptureTimer = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 2, 0.2);			// Interval of beam spawns
			RaptureRadius = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 3, 800.0);		// Radius around boss to spawn the beams
			RaptureVel = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 4, 350.0);			// Push force to get them off the ground and start the move upwards
			RaptureDmg = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 5, 10.0);			// Damager per tick at it's peak, factored based on distance
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "heffe_reincarn_rapture", 6, RapturePush, 6);				// Push force of the beams
			RaptureStunTime = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 7, 1.0);		// Stun time, will be reapplied every 1 second(s)
			RaptureDuration = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 8, 8.0);		// Duration of stun and beams
			RaptureBlindTime = FF2_GetAbilityArgument(iIndex, this_plugin_name, "heffe_reincarn_rapture", 9, 10);			// Duration of visual screen effect
			RaptureSlayRatio = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 10, 0.95);	// How far they must be upwards before they are slayed outright

			g_Boss = iBoss;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_heffe"))
		{
			HeffeRange = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_heffe", 1);
			HeffeStunDuration = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_heffe", 2, 10.0);	// Stun duration; Recommended to keep this value since it works perfectly with the sound file
			g_iButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_heffe", 4, 2);				// Button type to use the ability; 1 = Secondary Fire, 2 = Reload, 3 = Special Attack

			SDKHook(iBoss, SDKHook_PreThink, Heffe_HUD);
			g_iSmiteNumber = 0;
			g_Boss = iBoss;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "dot_heffe_jump"))
		{
			FlapDrain = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "dot_heffe_jump", 1, 5.0);						// Amount of rage drained per second
			FlapForce = FF2_GetAbilityArgument(iIndex, this_plugin_name, "dot_heffe_jump", 2, 75);							// Force multiplier of the jump
			FlapRate =  GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "dot_heffe_jump", 3, 1.5);	// Time between flaps
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "dot_heffe_jump", 4, FlapSound, PLATFORM_MAX_PATH);		// Sound played on flap

			if(!IsEmptyString(FlapSound))
				PrecacheSound(FlapSound);

			CreateTimer(0.1, Timer_HeffeTick, iBoss, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			SDKHook(iBoss, SDKHook_PreThink, Heffe_HUD);
			HeffeUpdateHUD[iBoss] = GetEngineTime() + HUD_INTERVAL;
			g_bButtonPressed = false;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_therock"))
		{
			RockRageDuration[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_therock", 1, 20.0);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_mine"))
		{
			FruitRageRange[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_mine", 1, 325.0);
			FruitCanRemoveSentry[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_mine", 2) == 1;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_projectile"))
		{
			RocketCharge[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 1, 5.0);
			RocketCooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 2, 5.0);
			RocketSpeed[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 3, 1000.0);
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "charge_projectile", 4, RocketModel[iBoss], PLATFORM_MAX_PATH);
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "charge_projectile", 5, RocketParticle[iBoss], PLATFORM_MAX_PATH);
			RocketDamage[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 6, 40.0);
			RocketStunTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 7, 3.0);
			RocketRequiredRage[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_projectile", 8, 10);

			for (new i=1; i<=MaxClients; i++)
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeRocketDamage);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_pocketmedic"))
		{
			MedicJumpWeaponPreference[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_pocketmedic", 1) == 1;	// 0 = use melee, else use medigun
			MedicTeleWeaponPreference[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_pocketmedic", 2) == 1;	// 0 = use medigun, else use melee

			SDKHook(iBoss, SDKHook_WeaponCanSwitchToPost, WeaponSwitch);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_jumpmanager"))
		{
			JM_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_jumpmanager", 1);	// Button for activation, 1 = reload, 2 = special attack, 3 = secondary attack
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_jumpmanager", 2);		// Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			MJ_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 3);		// Time it takes to charge
			MJ_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 4);		// Time it takes to refresh
			MJ_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 5);	// Time before first use

			MT_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 6);		// Time it takes to charge
			MT_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 7);		// Time it takes to refresh
			MT_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 8);	// Time before first use

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "");
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_magicjump"))
		{
			MJ_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 1);		// Time it takes to charge
			MJ_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 2);		// Time it takes to refresh
			MJ_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 3);	// Time before first use
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_magicjump", 4);	// Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "");
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_magictele"))
		{
			MT_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 1);		// Time it takes to charge
			MT_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 2);		// Time it takes to refresh
			MT_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 3);	// Time before first use
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_magictele", 4);	// Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "");
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_spellattack"))
		{
			SS_CoolDown[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_spellattack", 1);

			for(int i=1; i<=MaxClients; i++)
			{
				if(IsClientInGame(i))
					SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_mlg"))
		{
			for(int i=1; i<=MaxClients; i++)
			{
				if(IsClientInGame(i))
					SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_norage"))
			SDKHook(iBoss, SDKHook_PreThink, NoRage_Think);
		if(FF2_HasAbility(iIndex, this_plugin_name, "special_noknockback"))
			SDKHook(iBoss, SDKHook_OnTakeDamage, NKBOnTakeDamage);

		SDKHook(iBoss, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
		CreateTimer(1.5, Timer_SwitchToSlot, iBoss);	// Delayed to ensure it overrides SpawnWeapon's switch
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		MJ_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
		MJ_EmergencyReady[iClient] = false;

		MT_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
		MT_EmergencyReady[iClient] = false;

		JM_AbilitySwitched[iClient] = false;

		SDKUnhook(iClient, SDKHook_StartTouch, OnRockTouch);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeRocketDamage);
		SDKUnhook(iClient, SDKHook_PreThink, NoRage_Think);
	}
}

public Action Event_PlayerDeath(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if (hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	int att_index = FF2_GetBossIndex(iAttacker);
	//int vic_index = FF2_GetBossIndex(iVictim);
	if (att_index != -1)
	{
		if(FF2_HasAbility(att_index, this_plugin_name, "special_teamkiller_multimelee"))		//Receive weapons on kill
		{
			if (GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(iAttacker, TFWeaponSlot_Melee))
			{
				TF2_RemoveWeaponSlot(iAttacker, TFWeaponSlot_Melee);
				int Weapon;
				switch (GetRandomInt(0,5))
				{
					case 0:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_bat", 325, 101, 5, "68 ; 2 ; 2 ; 3.0");
					case 1:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_bonesaw", 37, 101, 5, "68 ; 2 ; 2 ; 3.0");
					case 2:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_club", 232, 101, 5, "68 ; 2 ; 2 ; 3.0");
					case 3:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_bat", 452, 101, 5, "68 ; 2 ; 2 ; 3.0");
					case 4:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_fireaxe", 38, 101, 5, "68 ; 2 ; 2 ; 3.0");
					case 5:
						Weapon=SpawnWeapon(iAttacker, "tf_weapon_katana", 357, 101, 5, "68 ; 2 ; 2 ; 3.0");
				}
				SetEntPropEnt(iAttacker, Prop_Data, "m_hActiveWeapon", Weapon);
			}
		}
		if(FF2_HasAbility(att_index, this_plugin_name, "rage_therock"))
			SDKUnhook(iVictim, SDKHook_StartTouch, OnRockTouch);
	}
	else
	{
		if (GetClientTeam(iVictim)==BossTeam)
			SDKUnhook(iVictim, SDKHook_StartTouch, OnRockTouch);
	}
	if(DiedRapture[iVictim] > GetEngineTime())
	{
		SetEventString(hEvent, "weapon_logclassname", "alien_abduction");
		SetEventString(hEvent, "weapon", "merasmus_zap");

		Handle data;
		CreateDataTimer(0.01, Timer_DissolveRagdoll, data);
		WritePackCell(data, iVictim);
		WritePackCell(data, 0);
	}
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
		return Plugin_Continue;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int iCustom = hEvent.GetInt("custom");

	if(!IsValidClient(iClient, true) || !IsValidClient(iAttacker, true) || iClient == iAttacker)
		return Plugin_Continue;

	int Boss = FF2_GetBossIndex(iAttacker);
	if(FF2_HasAbility(Boss, this_plugin_name, "rage_mlg"))
	{
		if(MLGRageTime >= GetEngineTime())
		{
			// Debug("Headshot..?");
			iCustom = TF_CUSTOM_HEADSHOT;
			return Plugin_Changed;
		}
	}
	if(FF2_HasAbility(Boss, this_plugin_name, "special_mlgsounds"))
	{
		if(iCustom == TF_CUSTOM_HEADSHOT)
		{
			float position[3];
			GetEntPropVector(iAttacker, Prop_Send, "m_vecOrigin", position);

			char sound[PLATFORM_MAX_PATH];
			if (FF2_RandomSound("sound_headshot", sound, PLATFORM_MAX_PATH, Boss))
			{
				EmitSoundToAll(sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);
				EmitSoundToAll(sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);

				for (int enemy = 1; enemy < MaxClients; enemy++)
				{
					if (IsClientInGame(enemy) && enemy != iAttacker)
					{
						EmitSoundToClient(enemy, sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);
						EmitSoundToClient(enemy, sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_Jarate(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int iClient = BfReadByte(msg);
	int iVictim = BfReadByte(msg);
	if(IsValidClient(iVictim))
	{
		if(FF2_HasAbility(0, this_plugin_name, "rage_wanker"))
		{
			if (WankerPissMode[iClient])
			{
				CreateTimer(0.1, Timer_NoPiss, GetClientUserId(iVictim));
				WankerPissDuration[iClient] *= 2.0;
			}
			TF2_MakeBleed(iVictim, iClient, WankerPissDuration[iClient]);
		}
	}
}

public Action OnTakeRocketDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDmgType, int &iWeapon, float flDmgForce[3], float flDmgPosition[3], int DmgCustom)
{
	if (iAttacker<1 || iAttacker>MaxClients || !IsValidClient(iAttacker))
		return Plugin_Continue;

	int Boss = FF2_GetBossIndex(iAttacker);
	if (FF2_HasAbility(Boss, this_plugin_name, "charge_projectile"))
	{
		char strClassname[64];
		GetEntityClassname(iInflictor, strClassname, sizeof(strClassname));
		if (!strcmp(strClassname, "tf_projectile_rocket"))
			if (RocketStunTime[Boss] > 0.25)
				TF2_StunPlayer(iClient, RocketStunTime[Boss], 0.0, TF_STUNFLAGS_NORMALBONK, iAttacker);
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDamagetype, int &iWeapon, float flDamageForce[3], float flDamagePosition[3], int iDamageCustom)
{
	if (!IsValidClient(iAttacker) || GetClientTeam(iAttacker)!=BossTeam)
		return Plugin_Continue;
	int iBoss = FF2_GetBossIndex(iAttacker);

	if(FF2_HasAbility(iBoss, this_plugin_name, "special_spellattack"))
	{
		flDamage *= 0.2;
		return Plugin_Changed;
	}

	if(enableMLG[iAttacker] || MLGRageTime > GetGameTime())
	{
		char classname[50];
		GetEntityClassname(GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon"), classname, sizeof(classname));
		if(!StrContains(classname, "tf_weapon_sniperrifle"))
		{
			iDamageCustom|=TF_CUSTOM_HEADSHOT;
			iDamagetype|=DMG_CRIT;
			flDamage *= 15.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action:CheckEnvironmentalDamage(int iClient, int &iAttacker, int &iInflictor, float &flDmg, int &DmgType, int &iWep, float flDmgForce[3], float flDmgPos[3], int DmgCstm)
{
	if (!IsValidClient(iClient, true))
		return Plugin_Continue;

	if (iAttacker == 0 && iInflictor == 0 && (DmgType & DMG_FALL) != 0)
		return Plugin_Continue;

	// ignore damage from players
	if (iAttacker >= 1 && iAttacker <= MaxClients)
		return Plugin_Continue;

	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iClient));

	if (FF2_HasAbility(iBoss, this_plugin_name, "charge_magicjump") || FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager"))
	{
		if (flDmg > 50.0)
		{
			MJ_EmergencyReady[iClient] = true;
			MJ_OnCooldownUntil[iClient] = FAR_FUTURE;
		}
	}

	if (FF2_HasAbility(iBoss, this_plugin_name, "charge_magictele") || FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager"))
	{
		if (flDmg > 50.0)
		{
			MT_EmergencyReady[iClient] = true;
			MT_OnCooldownUntil[iClient] = FAR_FUTURE;
		}
	}

	return Plugin_Continue;
}

public Action NKBOnTakeDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDmgType, int &iWeapon, float flDmgForce[3], float flDmgPosition[3], int DmgCustom)
{
	if(!IsValidClient(iAttacker, true))
		return Plugin_Continue;

	if(IsValidClient(iClient, true, true))
	{
		iDmgType |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action WeaponSwitch(int iClient, int iWeapon)
{
	if(!MedicJumpWeaponPreference[iClient])
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee) == iWeapon)
			DD_SetDisabled(iClient, false, true, true, false);
	}else
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary) == iWeapon)
			DD_SetDisabled(iClient, false, true, true, false);
	}

	if(!MedicTeleWeaponPreference[iClient])
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary) == iWeapon)
			DD_SetDisabled(iClient, true, false, true, false);
	}else
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee) == iWeapon)
			DD_SetDisabled(iClient, true, false, true, false);
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float flVel[3], float flAngs[3], int &iWeapon, int &iIndex, int &iSlot)
{
	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iClient));

	if(!IsValidClient(iClient, true))
		return Plugin_Continue;

	if(FF2_HasAbility(iBoss, this_plugin_name, "rage_heffe") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		char Button;
		switch(g_iButtonType)
		{
			case 1: Button = IN_RELOAD;
			case 2: Button = IN_ATTACK3;
		}

		if(iButtons & Button && g_iSmiteNumber > 0)
		{
			float flPos1[3], flPos2[3], flDist;

			GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flPos1);
			for(int i=1; i<=MaxClients; i++)
			{
				if(IsValidClient(i) && IsClientInGame(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos2);
					flDist = GetVectorDistance(flPos1, flPos2);
					if (flDist < HeffeRange && GetClientTeam(i)!=BossTeam)
					{
						if(IsPlayerAlive(i))
						{
							PerformSmite(iClient, i);
							break;
						}
					}
				}
			}
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "dot_heffe_jump") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		if(iButtons & IN_ATTACK2)
		{
			if(!g_bButtonPressed)
			{
				g_bButtonPressed = true;
				CreateTimer(1.0, Timer_DrainTick, iClient, TIMER_REPEAT);
			}
			else g_bButtonPressed = false;
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		JM_Tick(iClient, iButtons, GetEngineTime());

		char Button;
		switch(JM_ButtonType)
		{
			case 1: Button = IN_RELOAD;
			case 2: Button = IN_ATTACK3;
			case 3: Button = IN_ATTACK2;
		}

		if(iButtons & Button)
		{
			if(!JM_AbilitySwitched[iClient])
				JM_AbilitySwitched[iClient] = true;
			else JM_AbilitySwitched[iClient] = false;
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "charge_magicjump") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		MJ_Tick(iClient, iButtons, GetEngineTime());
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "charge_magictele") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		MT_Tick(iClient, iButtons, GetEngineTime());
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "special_spellattack") && GetClientTeam(iClient) == BossTeam)
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		if(iButtons & IN_ATTACK)
		{
			if(GetEngineTime() >= SS_CoolDown[iClient])
			{
				ShootProjectile(iClient, "tf_projectile_spellfireball");
				SS_CoolDown[iClient] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iBoss, this_plugin_name, "special_spellattack", 1);

				float position[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, iBoss, 4))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}
			else iButtons &= ~IN_ATTACK;
		}
	}

	// if(MLGRageTime < GetEngineTime() || !enableMLG[iClient] || !IsPlayerAlive(iClient)) return Plugin_Continue;

	// if(iButtons & IN_ATTACK|IN_ATTACK2) AimThink(iClient);

	return Plugin_Continue;
}

public Action FF2_OnLoseLife(int Index)
{
	int userid = FF2_GetBossUserId(Index);
	int iClient = GetClientOfUserId(userid);
	if(Index == -1 || !IsValidEdict(iClient))
		return Plugin_Continue;

	if(FF2_HasAbility(Index, this_plugin_name, "heffe_reincarn_rapture"))
	{
		Handle data;
		CreateDataTimer(RaptureTimer, Timer_Abduction, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, iClient);
		WritePackCell(data, RaptureIteration);		   // iterations

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != BossTeam)
				PerformBlind(i, RaptureBlindTime);
		}

		TF2_AddCondition(iClient, TFCond_Ubercharged, RaptureDuration);
		TF2_StunPlayer(iClient, RaptureDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT);
	}

	return Plugin_Continue;
}



////////////////////////////////////////
//	Abilities start below this point  //
////////////////////////////////////////

void Rage_Wanker(int iClient)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));

	TF2_RemoveWeaponSlot(Boss, TFWeaponSlot_Secondary);
	if(!WankerPissMode[Boss])				//Whether it's jarate and bleed, or just bleed; 1 = just bleed
		SetEntPropEnt(Boss, Prop_Send, "m_hActiveWeapon", SpawnWeapon(Boss, "tf_weapon_jar", 58, 100, 5, "149 ; 15.0 ; 134 ; 12.0 ; 175 ; 15.0"));
		//149 - 15 second bleed
		//175 - 15 second jarate
		//134 - Applies particle of id 12
	else
		SetEntPropEnt(Boss, Prop_Send, "m_hActiveWeapon", SpawnWeapon(Boss, "tf_weapon_jar", 58, 100, 5, "149 ; 30.0 ; 134 ; 12.0"));
		//149 - 30 second bleed
		//134 - Applies particle of id 12
	SetAmmo(Boss, TFWeaponSlot_Secondary, WankerAmmo[Boss]);
}

void Rage_Heffe(int iClient, const char[] ability_name)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
	g_iSmiteNumber = FF2_GetAbilityArgument(iClient, this_plugin_name, ability_name, 3, 3);			// Number of available smite abilities per rage

	float flPos1[3], flPos2[3], flDist;

	GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", flPos1);
	TF2_StunPlayer(Boss, HeffeStunDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, Boss);
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i) && IsClientInGame(i) && IsPlayerAlive(i))
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos2);
			flDist = GetVectorDistance(flPos1, flPos2);
			if (flDist <= HeffeRange && GetClientTeam(i)!=BossTeam)
				TF2_StunPlayer(i, HeffeStunDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, Boss);
		}
	}
}

void Rage_TheRock(int iClient)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));

	if(GetClientTeam(Boss)==BossTeam)
	{
		SDKHook(Boss, SDKHook_StartTouch, OnRockTouch);
		TF2_AddCondition(Boss, TFCond_MegaHeal, RockRageDuration[Boss]);
		TF2_AddCondition(Boss, TFCond_SpeedBuffAlly, RockRageDuration[Boss]);
		CreateTimer(RockRageDuration[Boss], UnHook, Boss);
		SetEntProp(Boss, Prop_Send, "m_CollisionGroup", 2);
	}
}

void Rage_Mine(int iClient)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
	float flPos[3], flPos2[3], flDistance;

	GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", flPos);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!=BossTeam)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos2);
			flDistance = GetVectorDistance(flPos, flPos2);
			if (flDistance <= FruitRageRange[Boss] && GetClientTeam(i)!=BossTeam)
			{
				switch (GetRandomInt(1, 3))	// Removes players weapons, Primary has higher chance then Secondary, as what good would a Medic be if he lost his medigun?
				{
					case 1:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Secondary);
					case 2:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
					case 3:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
				}
				// Set's the players active weapon if the weapon they were using was removed
				if (GetPlayerWeaponSlot(i, 0) == -1 && GetPlayerWeaponSlot(i, 1) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Melee);
				else if (GetPlayerWeaponSlot(i, 1) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Primary);
				else if (GetPlayerWeaponSlot(i, 0) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Secondary);
			}
		}
	}
	int iSentry = FindEntityByClassname(iSentry, "obj_sentrygun");
	if(IsValidEntity(iSentry) && FruitCanRemoveSentry[Boss])
	{
		GetEntPropVector(iSentry, Prop_Send, "m_vecOrigin", flPos2);
		flDistance = GetVectorDistance(flPos, flPos2);
		if(flDistance <= FruitRageRange[Boss])
		{
			switch (GetRandomInt(1, 2))
			{
				case 2: AcceptEntityInput(iSentry, "Kill");
			}
		}
	}
}

void Rage_SkeleSummon(int iClient, const char[] ability_name)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
	SkeleNumberOfSpawns[Boss] = FF2_GetAbilityArgument(iClient, this_plugin_name, ability_name, 1);

	SDKHook(ShootProjectile(Boss, "tf_projectile_spellspawnhorde"), SDKHook_StartTouch, Projectile_Touch);
}

void Rage_MLG(int iClient, const char[] ability_name)
{
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
	MLGRageTime = GetEngineTime() + FF2_GetAbilityArgumentFloat(iClient, this_plugin_name, ability_name, 1);
	enableMLG[Boss]=true;
	SDKHook(Boss, SDKHook_PreThink, AimThink);
}

void Charge_RocketSpawn(int iClient, int iSlot, int iAction)	// Shamelessly stolen code from Friagram and EggMan
{
	float flZeroCharge = FF2_GetBossCharge(iClient, 0);
	int Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
	float flCharge = FF2_GetBossCharge(iClient, iSlot);
	if(flZeroCharge < RocketRequiredRage[Boss])
	{
		SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
		ShowSyncHudText(Boss, chargeHUD, "Requires at least %d Rage!", RocketRequiredRage[Boss]);
		return;
	}
	switch(iAction)
	{
		case 1:
		{
			SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			ShowSyncHudText(Boss, chargeHUD, "%t", "charge_cooldown", -RoundFloat(flCharge*10/RocketCharge[Boss]));
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			if(flCharge+1 < RocketCharge[Boss])
				FF2_SetBossCharge(iClient, iSlot, flCharge+1);
			else
				flCharge = RocketCharge[Boss];
			ShowSyncHudText(Boss, chargeHUD, "%t", "charge_status", RoundFloat(flCharge*100/RocketCharge[Boss]));
		}
		default:
		{
			if (flCharge <= 0.2)
			{
				SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(Boss, chargeHUD, "%t","charge_ready");
			}
			if (flCharge >= RocketCharge[Boss])
			{
				FF2_SetBossCharge(iClient, 0, flZeroCharge - RocketRequiredRage[Boss]);
				float pos[3], rot[3], vel[3];
				GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", pos);
				GetClientEyeAngles(Boss, rot);
				pos[2]+=63;

				int iProj = CreateEntityByName("tf_projectile_rocket");
				SetVariantInt(BossTeam);
				AcceptEntityInput(iProj, "TeamNum", -1, -1, 0);
				SetVariantInt(BossTeam);
				AcceptEntityInput(iProj, "SetTeam", -1, -1, 0);
				SetEntPropEnt(iProj, Prop_Send, "m_hOwnerEntity", Boss);

				vel[0] = Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*RocketSpeed[Boss];
				vel[1] = Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*RocketSpeed[Boss];
				vel[2] = Sine(DegToRad(rot[0]))*RocketSpeed[Boss];
				vel[2]*=-1;

				TeleportEntity(iProj, pos, rot, vel);
				SetEntProp(iProj, Prop_Send, "m_bCritical", 1);
				SetEntDataFloat(iProj, FindSendPropOffs("CTFProjectile_Rocket", "m_iDeflected") + 4, RocketDamage[Boss], true);
				DispatchSpawn(iProj);

				if(strlen(RocketModel[Boss]) > 5)
					SetEntityModel(iProj, RocketModel[Boss]);
				if(strlen(RocketParticle[Boss]) > 2)
					CreateTimer(15.0, RemoveEnt, EntIndexToEntRef(AttachParticle(iProj, RocketParticle[Boss], _, true)));

				char s[PLATFORM_MAX_PATH];
				if(FF2_RandomSound("sound_ability", s, PLATFORM_MAX_PATH, iClient, iSlot))
				{
					EmitSoundToAll(s, Boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Boss, pos, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(s, Boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Boss, pos, NULL_VECTOR, true, 0.0);

					for(int i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i != Boss)
						{
							EmitSoundToClient(i, s, Boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Boss, pos, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(i, s, Boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, Boss, pos, NULL_VECTOR, true, 0.0);
						}
				}

				Handle hData;
				CreateDataTimer(0.2, Timer_StartCD, hData);
				WritePackCell(hData, iClient);
				WritePackCell(hData, iSlot);
				WritePackFloat(hData, -RocketCooldown[Boss]);
				ResetPack(hData);
			}
		}
	}
}

/**
*Deprecated
*
*void Rage_Trixie(iClient)
*{
*	new Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
*	TF2_RemoveWeaponSlot(Boss, TFWeaponSlot_Primary);
*	SetEntPropEnt(Boss, Prop_Send, "m_hActiveWeapon", SpawnWeapon(Boss, "tf_weapon_flamethrower", 40, 100, 5, "138 ; 0.2 ; 137 ; 3 ; 5 ; 1.75 ; 356 ; 1"));
*		 138 - -80% damage against players
*		 137 - +200% damage against buildings
*		 356 - No airblast
*		 5 - 75% slower firing speed
*	SetAmmo(Boss, TFWeaponSlot_Primary,999);
*	if (GetClientTeam(Boss)==BossTeam)
*		CreateTimer(10.0, Timer_RemoveWeapon, GetClientUserId(Boss));
*}
*void Rage_BigMac(iClient)
*{
*	new Boss = GetClientOfUserId(FF2_GetBossUserId(iClient));
*	TF2_RemoveWeaponSlot(Boss, TFWeaponSlot_Primary);
*	SetEntPropEnt(Boss, Prop_Send, "m_hActiveWeapon", SpawnWeapon(Boss, "tf_weapon_minigun", 202, 100, 5, "138 ; 0.4 ; 137 ; 2 ; 5 ; 2 ; 54 ; 0.5 ; 87 ; 0.75 ; 75 ; 0.75"));
*		 138 - -60% damage against players
*		 137 - +100% damage against buildings
*		 5 - 100% slower firing speed
*		 54 - -50% move speed, move speed attributes don't seem to affect the boss
*		 87 - +25% faster spinup
*		 75 - -25% move speed while deployed
*	SetAmmo(Boss, TFWeaponSlot_Primary,999);
*	if (GetClientTeam(Boss)==BossTeam)
*		CreateTimer(7.0, Timer_RemoveWeapon, GetClientUserId(Boss));
*}
**/



/////////////////////////////////////
//	Timers start below this point  //
/////////////////////////////////////


/**
*Deprecated
*
*public Action:Timer_RemoveWeaponS(Handle:hTimer, any:iClient)
*{
*	if (IsValidClient(iClient)) TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);
*		 EquipPlayerWeapon(iClient, GetPlayerWeaponSlot(iClient, 2));
*}
*public Action:Timer_RemoveWeaponP(Handle:timer, any:iClient)
*{
*	if (IsValidClient(iClient)) TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);
*		 EquipPlayerWeapon(iClient, GetPlayerWeaponSlot(iClient, 2));
*}
**/

public Action Timer_ResetMoveType(Handle hTimer, any iClient) {
	if (IsValidClient(iClient) && (GetEntityMoveType(iClient)==MOVETYPE_FLY || GetEntityMoveType(iClient)==MOVETYPE_NONE))
		SetEntityMoveType(iClient, MOVETYPE_WALK);
}

public Action Timer_NoPiss(Handle hTimer, any iClient) {
	if (IsValidClient(iClient))
		TF2_RemoveCondition(iClient, TFCond_Jarated);
}

public Action RemoveEnt(Handle hTimer, any entid)
{
	int iEntity = EntRefToEntIndex(entid);
	if (IsValidEdict(iEntity))
	{
		if (iEntity > MaxClients)
			AcceptEntityInput(iEntity, "Kill");
	}
}

/*public Action Timer_SwitchToSlot(Handle hTimer, any iClient)
{
	if(IsValidClient(iClient, true))
		SwitchtoSlot(iClient, 2);
}*/

public Action UnHook(Handle hTimer, any Boss)
{
	if(IsValidClient(Boss))
	{
		SDKUnhook(Boss, SDKHook_StartTouch, OnRockTouch);
		SetEntProp(Boss, Prop_Send, "m_CollisionGroup", 5);
	}
}

public Action Timer_StartCD(Handle hTimer, Handle hData)
{
	int iClient = ReadPackCell(hData);
	int iSlot = ReadPackCell(hData);
	float flSee = ReadPackFloat(hData);
	FF2_SetBossCharge(iClient, iSlot, flSee);
}

public Action Timer_HeffeTick(Handle hTimer, any iClient)
{
	if(g_bButtonPressed)
	{
		int Boss = FF2_GetBossIndex(iClient);
		if((GetClientButtons(iClient) & IN_JUMP)/* && GetEngineTime() >= g_flFlapRate*/)	// Enforce a time limit between flaps
		{
			float flPos[3], flRot[3], flVel[3];
			GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flPos);
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", flVel);
			GetClientEyeAngles(iClient, flRot);

			flVel[0] += Cosine(DegToRad(flRot[0]))*Cosine(DegToRad(flRot[1]))*FlapForce;
			flVel[1] += Cosine(DegToRad(flRot[0]))*Sine(DegToRad(flRot[1]))*FlapForce;
			flVel[2] = (750.0+175.0*FlapForce/70);

			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVel);
			FlapRate =  GetEngineTime() + FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, "dot_heffe_jump", 2, 1.5);

			if(!IsEmptyString(FlapSound))
				EmitAmbientSound(FlapSound, flPos, iClient);
		}
	}

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action Timer_DrainTick(Handle hTimer, any iClient)
{
	int Boss = FF2_GetBossIndex(iClient);

	float flRage = FF2_GetBossCharge(Boss, 0);
	flRage -= FlapDrain;

	if (flRage < 0.0)
	{
		g_bButtonPressed = false;
		flRage = 0.0;
		PrintCenterText(iClient, "Out of rage!");
	}

	FF2_SetBossCharge(Boss, 0, flRage);

	if(!g_bButtonPressed)
		return Plugin_Stop;

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action Timer_Abduction(Handle hTimer, Handle pack)
{
	ResetPack(pack);

	int Boss = ReadPackCell(pack);
	int iIterations = ReadPackCell (pack);
	if (IsValidClient(Boss, true, true))
	{
		Abduct(Boss);

		if(--iIterations)
		{
			Handle data;
			CreateDataTimer(RaptureTimer, Timer_Abduction, data, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(data, Boss);
			WritePackCell(data, iIterations);		  // iterations
		}
	}
}

public Action Timer_RemovePod(Handle hTimer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Disable");

		CreateTimer(0.1, RemoveEnt, ref, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_RemoveRagdoll(Handle hTimer, any userid)
{
	int iVictim = GetClientOfUserId(userid);
	if(iVictim && IsClientInGame(iVictim))
	{
		int iRagdoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
		if (iRagdoll > MaxClients)
		{
			AcceptEntityInput(iRagdoll, "Kill");
		}
	}
}

public Action Timer_DissolveRagdoll(Handle hTimer, Handle pack)
{
	ResetPack(pack);
	int iVictim = GetClientOfUserId(ReadPackCell(pack));
	if(iVictim && IsClientInGame(iVictim))
	{
		int iRagdoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
		if (iRagdoll != -1)
		{
			Dissolve(iRagdoll, ReadPackCell(pack));
		}
	}
}

public Action Timer_SwitchToSlot(Handle hTimer, any iClient)
{
	if(IsValidClient(iClient, true))
		SwitchtoSlot(iClient, 2);
}



/////////////////////////////////////
//	Stocks start below this point  //
/////////////////////////////////////

public void NoRage_Think(iClient)
{
	int Boss = FF2_GetBossIndex(iClient);
	FF2_SetBossCharge(Boss, 0, 0.0);
}

public void Heffe_HUD(int iClient)
{
	if(GetClientButtons(iClient) & IN_SCORE)
		return;

	if (GetEngineTime() >= HeffeUpdateHUD[iClient])
	{
		if(g_iSmiteNumber > 0)
		{
			SetHudTextParams(-1.0, 0.62, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
			ShowSyncHudText(iClient, heffeHUD, "Smite number remaining: %d", g_iSmiteNumber);
		}

		int Boss = FF2_GetBossIndex(iClient);
		if(FF2_HasAbility(Boss, this_plugin_name, "dot_heffe_jump"))
		{
			SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
			ShowSyncHudText(iClient, jumpHUD, "Flying is %sabled, press Secondary Fire to toggle", g_bButtonPressed ? "En" : "Dis");
		}

		HeffeUpdateHUD[iClient] = GetEngineTime() + HUD_INTERVAL;
	}

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		SDKUnhook(iClient, SDKHook_PreThink, Heffe_HUD);
}

public Action OnRockTouch(int Boss, int iEntity)
{
	if(GetClientTeam(Boss) != BossTeam)
	{
		SDKUnhook(Boss, SDKHook_Touch, OnRockTouch);
		return;
	}

	static float origin[3], angles[3], targetpos[3];
	if(iEntity > 0 && iEntity <= MaxClients && IsClientInGame(iEntity) && IsPlayerAlive(iEntity) && GetClientTeam(iEntity)!=BossTeam)
	{
		GetClientEyeAngles(Boss, angles);
		GetClientEyePosition(Boss, origin);
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", targetpos);
		GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(angles, angles);
		SubtractVectors(targetpos, origin, origin);

		if(GetVectorDotProduct(origin, angles) > 0.0)
		{
			SDKHooks_TakeDamage(iEntity, Boss, Boss, 15.0, DMG_CRUSH|DMG_PREVENT_PHYSICS_FORCE|DMG_ALWAYSGIB);	// Make boss get credit for the kill
			FakeClientCommandEx(iEntity, "explode");
		}
	}
}

public void MJ_Tick(int iClient, int iButtons, float flTime)
{
	int Boss = FF2_GetBossIndex(iClient);
	if(FF2_HasAbility(Boss, this_plugin_name, "special_jumpmanager"))	// Prevent possible double up conflicts
		return;

	if (flTime >= MJ_OnCooldownUntil[iClient])
		MJ_OnCooldownUntil[iClient] = FAR_FUTURE;

	float flCharge = 0.0;
	if (MJ_OnCooldownUntil[iClient] == FAR_FUTURE)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (MJ_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE)
		{
			if (MJ_ChargeTime[iClient] <= 0.0)
				flCharge = 100.0;
			else
				flCharge = fmin((flTime - MJ_CrouchOrAltFireDownSince[iClient]) / MJ_ChargeTime[iClient], 1.0) * 100.0;
		}

		char Button;
		switch(MJT_ButtonType)
		{
			case 1: Button = IN_ATTACK2;
			case 2: Button = IN_RELOAD;
			case 3: Button = IN_ATTACK3;
		}

		// do we start the charging now?
		if (MJ_CrouchOrAltFireDownSince[iClient] == FAR_FUTURE && (iButtons & Button) != 0)
			MJ_CrouchOrAltFireDownSince[iClient] = flTime;

		// has key been released?
		if (MJ_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE && (iButtons & Button) == 0)
		{
			if (!IsInInvalidCondition(iClient))
			{
				MJ_OnCooldownUntil[iClient] = flTime + MJ_Cooldown[iClient];

				// taken from default_abilities, modified only lightly
				float position[3];
				float velocity[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
				GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", velocity);

				int spellbook = FindSpellBook(iClient);
				SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 4);
				SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
				FakeClientCommand(iClient, "use tf_weapon_spellbook");

				// for the sake of making this viable, I'm keeping an actual jump, but half the power of a standard jump
				if (MJ_EmergencyReady[iClient])
				{
					velocity[2] = (750 + (flCharge / 4) * 13.0) + 2000 * 0.75;
					MJ_EmergencyReady[iClient] = false;
				}
				else
				{
					velocity[2] = (750 + (flCharge / 4) * 13.0) * 0.5;
				}
				SetEntProp(iClient, Prop_Send, "m_bJumping", 1);
				velocity[0] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;
				velocity[1] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;

				TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, velocity);
				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_magjump", sound, PLATFORM_MAX_PATH, Boss))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (new enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}

			// regardless of outcome, cancel the charge.
			MJ_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
		}
	}

	// draw the HUD if it's time
	if (flTime >= WitchDoctorUpdateHUD[iClient])
	{
		if (!(GetClientButtons(iClient) & IN_SCORE))
		{
			if (MJ_EmergencyReady[iClient])
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "Super DUPER Jump ready! Press and release %s!", GetMJTButton());
			}
			else if (MJ_OnCooldownUntil[iClient] == FAR_FUTURE)
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is ready. %.0f percent charged.\nPress and release %s!", flCharge, GetMJTButton());
			}
			else
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is not ready. %.1f seconds remaining.", MJ_OnCooldownUntil[iClient] - flTime);
			}
		}

		WitchDoctorUpdateHUD[iClient] = flTime + HUD_INTERVAL;
	}
}

public void MT_Tick(int iClient, int iButtons, float flTime)
{
	int Boss = FF2_GetBossIndex(iClient);
	if(FF2_HasAbility(Boss, this_plugin_name, "special_jumpmanager"))	// Prevent possible double up conflicts
		return;

	if (flTime >= MT_OnCooldownUntil[iClient])
		MT_OnCooldownUntil[iClient] = FAR_FUTURE;

	float flCharge = 0.0;
	if (MT_OnCooldownUntil[iClient] == FAR_FUTURE)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (MT_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE)
		{
			if (MT_ChargeTime[iClient] <= 0.0)
				flCharge = 100.0;
			else
				flCharge = fmin((flTime - MT_CrouchOrAltFireDownSince[iClient]) / MT_ChargeTime[iClient], 1.0) * 100.0;
		}

		char Button;
		switch(MJT_ButtonType)
		{
			case 1: Button = IN_ATTACK2;
			case 2: Button = IN_RELOAD;
			case 3: Button = IN_ATTACK3;
		}

		// do we start the charging now?
		if (MT_CrouchOrAltFireDownSince[iClient] == FAR_FUTURE && (iButtons & Button) != 0)
			MT_CrouchOrAltFireDownSince[iClient] = flTime;

		// has key been released?
		if (MT_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE && (iButtons & Button) == 0)
		{
			if (!IsInInvalidCondition(iClient))
			{
				MT_OnCooldownUntil[iClient] = flTime + MT_Cooldown[iClient];

				int spellbook = FindSpellBook(iClient);
				SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 6);
				SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
				FakeClientCommand(iClient, "use tf_weapon_spellbook");

				// just because I can see this becoming an immediate problem, gonna add an emergency teleport
				if (MT_EmergencyReady[iClient])
				{
					if (DD_PerformTeleport(iClient, 2.0, _, true))
					{
						MT_EmergencyReady[iClient] = false;
					}
				}

				float position[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_magtele", sound, PLATFORM_MAX_PATH, Boss))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}

			// regardless of outcome, cancel the charge.
			MT_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
		}
	}

	// draw the HUD if it's time
	if (flTime >= WitchDoctorUpdateHUD[iClient])
	{
		if (!(GetClientButtons(iClient) & IN_SCORE))
		{
			if (MT_EmergencyReady[iClient])
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "EMERGENCY TELEPORT! Press and release %s!", GetMJTButton());
			}
			else if (MT_OnCooldownUntil[iClient] == FAR_FUTURE)
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is ready. %.0f percent charged.\nPress and release %s!", flCharge, GetMJTButton());
			}
			else
			{
				SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is not ready. %.1f seconds remaining.", MT_OnCooldownUntil[iClient] - flTime);
			}
		}

		WitchDoctorUpdateHUD[iClient] = flTime + HUD_INTERVAL;
	}
}

public void JM_Tick(int iClient, int iButtons, float flTime)
{
	if(!JM_AbilitySwitched[iClient])
	{
		if (flTime >= MJ_OnCooldownUntil[iClient])
			MJ_OnCooldownUntil[iClient] = FAR_FUTURE;

		float flCharge = 0.0;
		if (MJ_OnCooldownUntil[iClient] == FAR_FUTURE)
		{
			// get charge percent here, used by both the HUD and the actual jump
			if (MJ_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE)
			{
				if (MJ_ChargeTime[iClient] <= 0.0)
					flCharge = 100.0;
				else
					flCharge = fmin((flTime - MJ_CrouchOrAltFireDownSince[iClient]) / MJ_ChargeTime[iClient], 1.0) * 100.0;
			}

			char Button;
			switch(MJT_ButtonType)
			{
				case 1: Button = IN_ATTACK2;
				case 2: Button = IN_RELOAD;
				case 3: Button = IN_ATTACK3;
			}

			// do we start the charging now?
			if (MJ_CrouchOrAltFireDownSince[iClient] == FAR_FUTURE && (iButtons & Button) != 0)
				MJ_CrouchOrAltFireDownSince[iClient] = flTime;

			// has key been released?
			if (MJ_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE && (iButtons & Button) == 0)
			{
				if (!IsInInvalidCondition(iClient))
				{
					MJ_OnCooldownUntil[iClient] = flTime + MJ_Cooldown[iClient];

					// taken from default_abilities, modified only lightly
					int Boss = FF2_GetBossIndex(iClient);
					float position[3];
					float velocity[3];
					GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
					GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", velocity);

					int spellbook = FindSpellBook(iClient);
					SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 4);
					SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
					FakeClientCommand(iClient, "use tf_weapon_spellbook");

					// for the sake of making this viable, I'm keeping an actual jump, but half the power of a standard jump
					if (MJ_EmergencyReady[iClient])
					{
						velocity[2] = (750 + (flCharge / 4) * 13.0) + 2000 * 0.75;
						MJ_EmergencyReady[iClient] = false;
					}
					else
					{
						velocity[2] = (750 + (flCharge / 4) * 13.0) * 0.5;
					}
					SetEntProp(iClient, Prop_Send, "m_bJumping", 1);
					velocity[0] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;
					velocity[1] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;

					TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, velocity);
					char sound[PLATFORM_MAX_PATH];
					if (FF2_RandomSound("sound_magjump", sound, PLATFORM_MAX_PATH, Boss))
					{
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

						for (new enemy = 1; enemy < MaxClients; enemy++)
						{
							if (IsClientInGame(enemy) && enemy != iClient)
							{
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							}
						}
					}
				}

				// regardless of outcome, cancel the charge.
				MJ_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
			}
		}

		// draw the HUD if it's time
		if (flTime >= WitchDoctorUpdateHUD[iClient])
		{
			if (!(GetClientButtons(iClient) & IN_SCORE))
			{
				if (MJ_EmergencyReady[iClient])
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "Super DUPER Jump ready! Press and release %s!", GetMJTButton());
				}
				else if (MJ_OnCooldownUntil[iClient] == FAR_FUTURE)
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is ready. %.0f percent charged.\nPress and release %s!\nPress %s to change.", flCharge, GetMJTButton(), GetJMButton());
				}
				else
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is not ready. %.1f seconds remaining.\nPress %s to change.", MJ_OnCooldownUntil[iClient] - flTime, GetJMButton());
				}
			}

			WitchDoctorUpdateHUD[iClient] = flTime + HUD_INTERVAL;
		}
	}else
	{
		if (flTime >= MT_OnCooldownUntil[iClient])
			MT_OnCooldownUntil[iClient] = FAR_FUTURE;

		float flCharge = 0.0;
		if (MT_OnCooldownUntil[iClient] == FAR_FUTURE)
		{
			// get charge percent here, used by both the HUD and the actual jump
			if (MT_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE)
			{
				if (MT_ChargeTime[iClient] <= 0.0)
					flCharge = 100.0;
				else
					flCharge = fmin((flTime - MT_CrouchOrAltFireDownSince[iClient]) / MT_ChargeTime[iClient], 1.0) * 100.0;
			}

			char Button;
			switch(MJT_ButtonType)
			{
				case 1: Button = IN_ATTACK2;
				case 2: Button = IN_RELOAD;
				case 3: Button = IN_ATTACK3;
			}

			// do we start the charging now?
			if (MT_CrouchOrAltFireDownSince[iClient] == FAR_FUTURE && (iButtons & Button) != 0)
				MT_CrouchOrAltFireDownSince[iClient] = flTime;

			// has key been released?
			if (MT_CrouchOrAltFireDownSince[iClient] != FAR_FUTURE && (iButtons & Button) == 0)
			{
				if (!IsInInvalidCondition(iClient))
				{
					MT_OnCooldownUntil[iClient] = flTime + MT_Cooldown[iClient];

					int spellbook = FindSpellBook(iClient);
					SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 6);
					SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
					FakeClientCommand(iClient, "use tf_weapon_spellbook");

					// just because I can see this becoming an immediate problem, gonna add an emergency teleport
					if (MT_EmergencyReady[iClient])
					{
						if (DD_PerformTeleport(iClient, 2.0, _, true))
						{
							MT_EmergencyReady[iClient] = false;
						}
					}

					float position[3];
					GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

					int Boss = FF2_GetBossIndex(iClient);
					char sound[PLATFORM_MAX_PATH];
					if (FF2_RandomSound("sound_magtele", sound, PLATFORM_MAX_PATH, Boss))
					{
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

						for (int enemy = 1; enemy < MaxClients; enemy++)
						{
							if (IsClientInGame(enemy) && enemy != iClient)
							{
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							}
						}
					}
				}

				// regardless of outcome, cancel the charge.
				MT_CrouchOrAltFireDownSince[iClient] = FAR_FUTURE;
			}
		}

		// draw the HUD if it's time
		if (flTime >= WitchDoctorUpdateHUD[iClient])
		{
			if (!(GetClientButtons(iClient) & IN_SCORE))
			{
				if (MT_EmergencyReady[iClient])
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "EMERGENCY TELEPORT! Press and release %s!", GetMJTButton());
				}
				else if (MT_OnCooldownUntil[iClient] == FAR_FUTURE)
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is ready. %.0f percent charged.\nPress and release %s!\nPress %s to change.", flCharge, GetMJTButton(), GetJMButton());
				}
				else
				{
					SetHudTextParams(-1.0, 0.88, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is not ready. %.1f seconds remaining.\nPress %s to change.", MT_OnCooldownUntil[iClient] - flTime, GetJMButton());
				}
			}

			WitchDoctorUpdateHUD[iClient] = flTime + HUD_INTERVAL;
		}
	}
}

public void AimThink(iClient)
{
/*
	int iClosest = GetClosestClient(iClient);
	if(!IsValidClient(iClosest, true))
		return;

	float flClosestLocation[3], flClientEyePosition[3], flVector[3], flCamAngle[3];
	GetClientEyePosition(iClient, flClientEyePosition);

	GetClientAbsOrigin(iClosest, flClosestLocation);
	flClosestLocation[2] += 43;

	MakeVectorFromPoints(flClosestLocation, flClientEyePosition, flVector);

	GetVectorAngles(flVector, flCamAngle);
	flCamAngle[0] *= -1.0;
	flCamAngle[1] += 180.0;

	ClampAngle(flCamAngle);
	TeleportEntity(iClient, NULL_VECTOR, flCamAngle, NULL_VECTOR);
*/
	int iClosest = GetClosestClient(iClient);
	if(!IsValidClient(iClosest, true))
		return;

	LookAtClient(iClient, iClosest);

	PrintCenterText(iClient, "지속시간동안 저격소총으로 맞추면 무조건 헤드샷입니다.");

	if(GetEngineTime() >= MLGRageTime || FF2_GetRoundState() != 1)
	{
		enableMLG[iClient]=false;
		SDKUnhook(iClient, SDKHook_PreThink, AimThink);
	}
}

public void OnClientWeaponShootPosition(int client, float position[3])
{
	if(!IsValidClient(client)) return;

	if(enableMLG[client])
	{
		int iClosest = GetClosestClient(client);
		if(!IsValidClient(iClosest, true))
			return;

		/*
		float flClosestLocation[3], flClientEyePosition[3], flVector[3], flCamAngle[3];
		GetClientEyePosition(client, flClientEyePosition);

		GetClientAbsOrigin(iClosest, flClosestLocation);
		flClosestLocation[2] += 43;

		MakeVectorFromPoints(flClosestLocation, flClientEyePosition, flVector);

		GetVectorAngles(flVector, flCamAngle);
		flCamAngle[0] *= -1.0;
		flCamAngle[1] += 180.0;

		ClampAngle(flCamAngle);
		TeleportEntity(client, NULL_VECTOR, flCamAngle, NULL_VECTOR);
		*/
		LookAtClient(client, iClosest);
	}
}

stock void LookAtClient(int iClient, int iTarget)
{
	float fTargetPos[3]; float fTargetAngles[3]; float fClientPos[3]; float fFinalPos[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyePosition(iTarget, fTargetPos);
	GetClientEyeAngles(iTarget, fTargetAngles);

	float fVecFinal[3];
	AddInFrontOf(fTargetPos, fTargetAngles, 7.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);

	GetVectorAngles(fFinalPos, fFinalPos);
	TeleportEntity(iClient, NULL_VECTOR, fFinalPos, NULL_VECTOR);
}

stock void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
	float fVecView[3]; GetViewVector(fVecAngle, fVecView);

	fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
	fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
	fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
	fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
	fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

void Abduct(int iClient)
{
	float flPos[3];
	GetClientAbsOrigin(iClient, flPos);
	flPos[0] += GetRandomFloat(-RaptureRadius, RaptureRadius);
	flPos[1] += GetRandomFloat(-RaptureRadius, RaptureRadius);
	Handle TraceRay = TR_TraceRayEx(flPos, {90.0, 0.0, 0.0}, MASK_SHOT, RayType_Infinite);
	if (TR_DidHit(TraceRay))
	{
		TR_GetEndPosition(flPos, TraceRay);
		flPos[2] += 5.0;
	}
	else
	{
		flPos[2] -= 280.0;
	}
	CloseHandle(TraceRay);

	int trigger = CreateEntityByName("trigger_push");
	if(trigger != -1)
	{
		CreateTimer(RaptureDuration, Timer_RemovePod, EntIndexToEntRef(trigger), TIMER_FLAG_NO_MAPCHANGE);

		DispatchKeyValueVector(trigger, "origin", flPos);
		DispatchKeyValue(trigger, "speed", RapturePush);
		DispatchKeyValue(trigger, "StartDisabled", "0");
		DispatchKeyValue(trigger, "spawnflags", "1");
		DispatchKeyValueVector(trigger, "pushdir", {-90.0, 0.0, 0.0});
		DispatchKeyValue(trigger, "alternateticksfix", "0");
		DispatchSpawn(trigger);

		ActivateEntity(trigger);

		AcceptEntityInput(trigger, "Enable");

		SetEntityModel(trigger, MODEL_TRIGGER);

		SetEntPropVector(trigger, Prop_Send, "m_vecMins", RAPTURE_BEAM_MINS);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", RAPTURE_BEAM_MAXS);

		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

		SDKHook(trigger, SDKHook_StartTouch, OnStartTouchBeam);
		SDKHook(trigger, SDKHook_Touch, OnTouchBeam);
		SDKHook(trigger, SDKHook_EndTouch, OnEndTouchBeam);

		ProjectBeams(flPos, RaptureDuration, {255, 215, 0, 155});
	}
}

public Action OnStartTouchBeam(int brush, int entity)
{
	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) != BossTeam)
	{
		SetEntityGravity(entity, 0.001);

		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action OnEndTouchBeam(int brush, int entity)
{
	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity))
	{
		g_Update[entity] = 0;
		SetEntityGravity(entity, 1.0);
	}
	return Plugin_Continue;
}

public Action OnTouchBeam(int brush, int entity)
{
	static float lasthurtstun[MAXPLAYERS+1];
	static float flTime, flRatio;
	static float flClPos[3], flBeampos[3];

	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) != BossTeam)
	{
		flTime = GetEngineTime();
		if(lasthurtstun[entity] < flTime)
		{
			lasthurtstun[entity] = flTime + RAPTURE_STUN_DELAY;
			TF2_StunPlayer(entity, RaptureStunTime, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);

			GetClientAbsOrigin(entity, flClPos);
			GetEntPropVector(brush, Prop_Send, "m_vecOrigin", flBeampos);
			flRatio = GetVectorDistance(flClPos, flBeampos)/RAPTURE_BEAM_LENGTH;

			DiedRapture[entity] = flTime + 0.1;
			if(flRatio >= RaptureSlayRatio)
			{
				SDKHooks_TakeDamage(entity, g_Boss, g_Boss, 9001.0, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
			}
			else
			{
				SDKHooks_TakeDamage(entity, g_Boss, g_Boss, RaptureDmg * flRatio, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
			}
		}

		if(GetEntityFlags(entity) & FL_ONGROUND)
		{
			flClPos[0] = 0.0;
			flClPos[1] = 0.0;
			flClPos[2] = RaptureVel;

			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, flClPos);

			g_Update[entity] = 0;
		}
		else if(g_Update[entity] == 1)
		{
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, {0.0,0.0,0.0});
		}
		g_Update[entity]++;

		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action Projectile_Touch(int iProj, int iOther)
{
	int iClient = GetEntPropEnt(iProj, Prop_Send, "m_hOwnerEntity");
	char strClassname[11];
	if((GetEntityClassname(iOther, strClassname, 11) && StrEqual(strClassname, "worldspawn")) || (iOther > 0 && iOther <= MaxClients))
	{
		float flPos[3], flAng[3];
		GetEntPropVector(iProj, Prop_Data, "m_vecAbsOrigin", flPos);
		for (int i = 0; i <= SkeleNumberOfSpawns[iClient]; i++)
		{
			flAng[0] = GetRandomFloat(-500.0, 500.0);
			flAng[1] = GetRandomFloat(-500.0, 500.0);
			flAng[2] = GetRandomFloat(0.0, 25.0);

			int iTeam = GetClientTeam(iClient);
			int iSpell = CreateEntityByName("tf_projectile_spellspawnhorde");

			if(!IsValidEntity(iSpell))
				return Plugin_Continue;

			SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
			SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
			SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));

			SetVariantInt(iTeam);
			AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
			SetVariantInt(iTeam);
			AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0);

			DispatchSpawn(iSpell);
			TeleportEntity(iSpell, flPos, flAng, flAng);
		}
	}
	return Plugin_Continue;
}

stock int GetIndexOfWeaponSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	return (iWeapon > MaxClients && IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock RemoveWeapons(int iClient)
{
	if (IsValidClient(iClient, true, true))
	{
		if(GetPlayerWeaponSlot(iClient, 0) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);

		if(GetPlayerWeaponSlot(iClient, 1) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);

		if(GetPlayerWeaponSlot(iClient, 2) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Melee);

		SwitchtoSlot(iClient, TFWeaponSlot_Melee);
	}
}

stock SwitchtoSlot(int iClient, int iSlot)
{
	if (iSlot >= 0 && iSlot <= 5 && IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		char strClassname[64];
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && IsValidEdict(iWeapon) && GetEdictClassname(iWeapon, strClassname, sizeof(strClassname)))
		{
			FakeClientCommandEx(iClient, "use %s", strClassname);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		}
	}
}

void PerformBlind(int iClient, int iDuration)
{
	static UserMsg g_FadeUserMsgId = INVALID_MESSAGE_ID;
	if(g_FadeUserMsgId == INVALID_MESSAGE_ID)
	{
		g_FadeUserMsgId = GetUserMessageId("Fade");
	}

	int targets[2];
	targets[0] = iClient;

	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", iDuration);
		PbSetInt(message, "hold_time", iDuration);
		PbSetInt(message, "flags", 0x0002);
		PbSetColor(message, "clr", {255, 200, 0, 175});
	}
	else
	{
		BfWriteShort(message, 900);
		BfWriteShort(message, 900);
		BfWriteShort(message, 0x0002);
		BfWriteByte(message, 255);
		BfWriteByte(message, 200);
		BfWriteByte(message, 0);
		BfWriteByte(message, 175);
	}

	EndMessage();
}

void PerformSmite(int iClient, int iTarget)
{
	float flStart[3], flEnd[3], flCeil[3];
	GetClientAbsOrigin(iTarget, flEnd);
	flCeil = GetMapCeiling(flCeil);
	flEnd[2] -= 26; // increase y-axis by 26 to strike at player's chest instead of the ground

	// define where the lightning strike starts
	flStart[0] = flEnd[0] + GetRandomFloat(-500.0, 500.0);
	flStart[1] = flEnd[1] + GetRandomFloat(-500.0, 500.0);
	flStart[2] = flCeil[2];

	int iColor[4] = { 255, 255, 255, 255 };

	// define the direction of the sparks
	float flDir[3] = { 0.0, 0.0, 0.0 };

	TE_SetupBeamPoints(flStart, flEnd, g_LightningSprite, 0, 0, 0, 0.2, 20.0, 10.0, 0, 1.0, iColor, 3);
	TE_SendToAll();

	TE_SetupSparks(flEnd, flDir, 5000, 1000);
	TE_SendToAll();

	TE_SetupEnergySplash(flEnd, flDir, false);
	TE_SendToAll();

	TE_SetupSmoke(flEnd, g_SmokeSprite, 5.0, 10);
	TE_SendToAll();

	EmitAmbientSound(SOUND_THUNDER, flStart, iClient, SNDLEVEL_RAIDSIREN);

	SDKHooks_TakeDamage(iTarget, iClient, iClient, 9001.0, DMG_PREVENT_PHYSICS_FORCE, -1);
	PrintCenterText(iTarget, "Thou hast been smitten!");
	g_iSmiteNumber -= 1;
}

public void ProjectBeams(float flStart[3], float flDuration, const Color[4])
{
	float flEnd[3], flCeil[3];
	flCeil = GetMapCeiling(flCeil);

	flEnd[0] = flStart[0];
	flEnd[1] = flStart[1];
	flEnd[2] = flCeil[2];

	TE_SetupBeamPoints(flStart, flEnd, g_Laser, 0, 0, 0, flDuration, 50.0, 42.5, 0, 0.80, Color, 1);
	TE_SendToAll();
	flEnd[2] -= 2490.0;
	TE_SetupSmoke(flStart, g_Smoke, 30.0, 6);
	TE_SendToAll();
	TE_SetupGlowSprite(flStart, g_Glow, flDuration, 3.0, 235);
	TE_SendToAll();
}

float GetMapCeiling(float flPos[3])
{
	Handle hTrace = TR_TraceRayEx(flPos, {-90.0, 0.0, 0.0}, MASK_SHOT, RayType_Infinite);

	if (TR_DidHit(hTrace))
		TR_GetEndPosition(flPos, hTrace);
	else
		flPos[2] = 1500.0;

	return flPos;
}

stock int AttachParticle(int iEntity, char[] strParticleType, float flOffset = 0.0, bool bAttach = true)
{
	int Particle = CreateEntityByName("info_particle_system");

	char strName[128];
	float flPos[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPos);
	flPos[2] += flOffset;
	TeleportEntity(Particle, flPos, NULL_VECTOR, NULL_VECTOR);

	Format(strName, sizeof(strName), "target%i", iEntity);
	DispatchKeyValue(iEntity, "targetname", strName);

	DispatchKeyValue(Particle, "targetname", "tf2particle");
	DispatchKeyValue(Particle, "parentname", strName);
	DispatchKeyValue(Particle, "effect_name", strParticleType);
	DispatchSpawn(Particle);
	SetVariantString(strName);
	if (bAttach)
	{
		AcceptEntityInput(Particle, "SetParent", Particle, Particle, 0);
		SetEntPropEnt(Particle, Prop_Send, "m_hOwnerEntity", iEntity);
	}
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	return Particle;
}

stock bool IsValidClient(int iClient, bool bAlive = false, bool bTeam = false)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;

	if(bAlive && !IsPlayerAlive(iClient))
		return false;

	if(bTeam && GetClientTeam(iClient) != BossTeam)
		return false;

	return true;
}

stock int FindEntityByClassname2(int startEnt, const char[] strClassname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, strClassname);
}

stock int SpawnWeapon(int iClient, char[] strClassname, int iIndex, int iLevel, int iQuality, const char[] strAttribute = "", bool bShow = true)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null)
		return -1;
	TF2Items_SetClassname(hWeapon, strClassname);
	TF2Items_SetItemIndex(hWeapon, iIndex);
	TF2Items_SetLevel(hWeapon, iLevel);
	TF2Items_SetQuality(hWeapon, iQuality);
	char strAttributes[32][32];
	int count=ExplodeString(strAttribute, ";", strAttributes, 32, 32);
	if (count % 2)
		--count;
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i < count; i += 2)
		{
			int attrib = StringToInt(strAttributes[i]);
			if (!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", strAttributes[i], strAttributes[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}
			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(strAttributes[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	int iEntity = TF2Items_GiveNamedItem(iClient, hWeapon);
	delete hWeapon;
	EquipPlayerWeapon(iClient, iEntity);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
	if (!bShow)
	{
		SetEntProp(iEntity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.001);
	}
	return iEntity;
}

void SetAmmo(int iClient, int iSlot, int iAmmo)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (IsValidEntity(iWeapon))
	{
		int iOffset = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(iClient, iAmmoTable+iOffset, iAmmo, 4, true);
	}
}

void Dissolve(int iEnt, int iMode=3)
{
	int iDissolver = CreateEntityByName("env_entity_dissolver");
	if (iDissolver != -1)
	{
		char dname[12];
		FormatEx(dname, 12, "dis_%d", iEnt);

		DispatchKeyValue(iEnt, "targetname", dname);
		switch(iMode <0 ? GetRandomInt(0, 3) : iMode)	  //"0 ragdoll rises as it dissolves, 1 and 2 dissolve on ground, 3 is fast dissolve"
		{
			case 0: DispatchKeyValue(iDissolver, "dissolvetype", "0");
			case 1: DispatchKeyValue(iDissolver, "dissolvetype", "1");
			case 2: DispatchKeyValue(iDissolver, "dissolvetype", "2");
			default: DispatchKeyValue(iDissolver, "dissolvetype", "3");
		}
		DispatchKeyValue(iDissolver, "target", dname);
		AcceptEntityInput(iDissolver, "Dissolve");
		AcceptEntityInput(iDissolver, "kill");
	}
}

int ShootProjectile(int iClient, char strEntname[48] = "")
{
	float flAng[3]; // original
	float flPos[3]; // original
	GetClientEyeAngles(iClient, flAng);
	GetClientEyePosition(iClient, flPos);

	int iTeam = GetClientTeam(iClient);
	int iSpell = CreateEntityByName(strEntname);

	if(!IsValidEntity(iSpell))
		return -1;

	float flVel1[3];
	float flVel2[3];

	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);

	flVel1[0] = flVel2[0]*1100.0; //Speed of a tf2 rocket.
	flVel1[1] = flVel2[1]*1100.0;
	flVel1[2] = flVel2[2]*1100.0;

	SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iSpell, Prop_Send, "m_bCritical", (GetRandomInt(0, 100) <= 5)? 1 : 0, 1);
	SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));

	TeleportEntity(iSpell, flPos, flAng, NULL_VECTOR);

	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0);

	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, flVel1);

	return iSpell;
}

public bool IsInInvalidCondition(iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_Dazed) || TF2_IsPlayerInCondition(iClient, TFCond_Taunting) || GetEntityMoveType(iClient)==MOVETYPE_NONE;
}

stock float fmin(float n1, float n2)
{
	return n1 < n2 ? n1 : n2;
}

stock char GetJMButton()
{
	char strBuffer[18];
	switch(JM_ButtonType)
	{
		case 1: strBuffer = "Reload";
		case 2: strBuffer = "Special Attack";
		case 3: strBuffer = "Secondary Attack";
	}
	return strBuffer;
}

stock char GetMJTButton()
{
	char strBuffer[18];
	switch(MJT_ButtonType)
	{
		case 1: strBuffer = "Secondary Attack";
		case 2: strBuffer = "Reload";
		case 3: strBuffer = "Special Attack";
	}
	return strBuffer;
}

stock int FindSpellBook(int iClient)
{
	int spellbook = -1;
	while ((spellbook = FindEntityByClassname(spellbook, "tf_weapon_spellbook")) != -1)
	{
		if (IsValidEntity(spellbook) && GetEntPropEnt(spellbook, Prop_Send, "m_hOwnerEntity") == iClient)
			if(!GetEntProp(spellbook, Prop_Send, "m_bDisguiseWeapon"))
				return spellbook;
	}

	return -1;
}

public bool TraceEntityFilterPlayer(int iEntity, int contentsMask)
{
	return (iEntity > GetMaxClients() || !iEntity);
}

stock bool CylinderCollision(float cylinderOrigin[3], float colliderOrigin[3], float maxDistance, float zMin, float zMax)
{
	if (colliderOrigin[2] < zMin || colliderOrigin[2] > zMax)
		return false;

	static float tmpVec1[3];
	tmpVec1[0] = cylinderOrigin[0];
	tmpVec1[1] = cylinderOrigin[1];
	tmpVec1[2] = 0.0;
	static float tmpVec2[3];
	tmpVec2[0] = colliderOrigin[0];
	tmpVec2[1] = colliderOrigin[1];
	tmpVec2[2] = 0.0;

	return GetVectorDistance(tmpVec1, tmpVec2, true) <= maxDistance * maxDistance;
}

stock int GetClosestClient(int iClient)
{
	float fClientLocation[3], fEntityOrigin[3];
	GetClientAbsOrigin(iClient, fClientLocation);

	int iClosestEntity = -1;
	float fClosestDistance = -1.0;
	for(int i = 1; i < MaxClients; i++) if(IsValidClient(i))
	{
		if(GetClientTeam(i) != GetClientTeam(iClient) && IsPlayerAlive(i) && i != iClient)
		{
			GetClientAbsOrigin(i, fEntityOrigin);
			float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
			if((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
			{
				fClosestDistance = fEntityDistance;
				iClosestEntity = i;
			}
		}
	}
	return iClosestEntity;
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0]-=360.0;
	while(flAngles[0] < -89.0) flAngles[0]+=360.0;
	while(flAngles[1] > 180.0) flAngles[1]-=360.0;
	while(flAngles[1] <-180.0) flAngles[1]+=360.0;
}
