/**
 * Block Maker v4.01 - SourceMod Port
 * Original by Necro (AMX Mod X)
 * Ported to SourceMod for Counter-Strike: Source
 *
 * Preserves original behavior: models, logic, effects, file format compatibility
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "blockmaker"
#define PLUGIN_VERSION "4.01"
#define PLUGIN_AUTHOR "Necro (SM Port)"
#define BM_ADMIN_FLAG ADMFLAG_CUSTOM1  // flag 'o', change as needed

// ============== CONSTANTS ==============
#define MAX_BLOCKS 24
#define MAXPLAYERS_CONST 65
#define MAX_SCORE_ENTRIES 15

static const float SNAP_DISTANCE = 10.0;

// Block sizes
enum {
    SIZE_NORMAL = 0,
    SIZE_SMALL,
    SIZE_LARGE
};

// Axes
enum {
    AXIS_X = 0,
    AXIS_Y,
    AXIS_Z
};

// Block scale factors
static const float SCALE_SMALL = 0.25;
static const float SCALE_NORMAL = 1.0;
static const float SCALE_LARGE = 2.0;

// Block types
enum {
    BM_PLATFORM = 0,    // A
    BM_BHOP,            // B
    BM_DAMAGE,          // C
    BM_HEALER,          // D
    BM_NOFALLDAMAGE,    // I
    BM_ICE,             // J
    BM_TRAMPOLINE,      // G
    BM_SPEEDBOOST,      // H
    BM_INVINCIBILITY,   // E
    BM_STEALTH,         // F
    BM_DEATH,           // K
    BM_NUKE,            // L
    BM_CAMOUFLAGE,      // M
    BM_LOWGRAVITY,      // N
    BM_FIRE,            // O
    BM_SLAP,            // P
    BM_RANDOM,          // Q
    BM_HONEY,           // R
    BM_BARRIER_CT,      // S
    BM_BARRIER_T,       // T
    BM_BOOTSOFSPEED,    // U
    BM_GLASS,           // V
    BM_BHOP_NOSLOW,     // W
    BM_AUTOBHOP        // X
};

// Teleport/Timer types
enum {
    TELEPORT_START = 0,
    TELEPORT_END,
    TIMER_START,
    TIMER_END
};

// Block Render types (prefixed to avoid SourceMod RenderMode conflict)
enum {
    BM_RENDER_NORMAL = 0,
    BM_RENDER_GLOWSHELL,
    BM_RENDER_TRANSCOLOR,
    BM_RENDER_TRANSALPHA,
    BM_RENDER_TRANSWHITE
};

enum {
    CONFIRM_DELETE_ALL = 0,
    CONFIRM_DELETE_TELE,
    CONFIRM_DELETE_TIMERS,
    CONFIRM_LOAD
};

int g_ConfirmAction[MAXPLAYERS_CONST];

// ============== STRINGS ==============
static const char PREFIX[] = "[BM] ";

static const char BLOCK_CLASSNAME[] = "bm_block";
static const char SPRITE_CLASSNAME[] = "bm_sprite";
static const char TELEPORT_START_CLASSNAME[] = "bm_teleport_start";
static const char TELEPORT_END_CLASSNAME[] = "bm_teleport_end";
static const char TIMER_CLASSNAME[] = "bm_timer";

// Block name translation keys (actual display names are in translations/blockmaker.phrases.txt)
static const char g_szBlockTransKeys[MAX_BLOCKS][] = {
    "Block_Platform", "Block_Bunnyhop", "Block_Damage", "Block_Healer",
    "Block_NoFallDamage", "Block_Ice", "Block_Trampoline", "Block_SpeedBoost",
    "Block_Invincibility", "Block_Stealth", "Block_Death", "Block_Nuke",
    "Block_Camouflage", "Block_LowGravity", "Block_Fire", "Block_Slap",
    "Block_Random", "Block_Honey", "Block_CTBarrier", "Block_TBarrier",
    "Block_BootsOfSpeed", "Block_Glass", "Block_BhopNoSlow", "Block_AutoBhop"
};

// Save IDs for file format compatibility
static const int g_BlockSaveIds[MAX_BLOCKS] = {
    'A', 'B', 'C', 'D', 'I', 'J', 'G', 'H', 'E', 'F',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X'
};

static const int TELEPORT_SAVE_ID = '*';
static const int TIMER_SAVE_ID = '&';

// Random block pool
static const int g_RandomBlocks[] = {
    BM_INVINCIBILITY, BM_STEALTH, BM_DEATH, BM_CAMOUFLAGE,
    BM_SLAP, BM_BOOTSOFSPEED, BM_AUTOBHOP
};

// Block models
static const char g_szDefaultBlockModels[MAX_BLOCKS][] = {
    "models/blockmaker/bm_block_platform.mdl",
    "models/blockmaker/bm_block_bhop.mdl",
    "models/blockmaker/bm_block_damage.mdl",
    "models/blockmaker/bm_block_healer.mdl",
    "models/blockmaker/bm_block_nofalldamage.mdl",
    "models/blockmaker/bm_block_ice.mdl",
    "models/blockmaker/bm_block_trampoline.mdl",
    "models/blockmaker/bm_block_speedboost.mdl",
    "models/blockmaker/bm_block_invincibility.mdl",
    "models/blockmaker/bm_block_stealth.mdl",
    "models/blockmaker/bm_block_death.mdl",
    "models/blockmaker/bm_block_nuke.mdl",
    "models/blockmaker/bm_block_camouflage.mdl",
    "models/blockmaker/bm_block_lowgravity.mdl",
    "models/blockmaker/bm_block_fire.mdl",
    "models/blockmaker/bm_block_slap.mdl",
    "models/blockmaker/bm_block_random.mdl",
    "models/blockmaker/bm_block_honey.mdl",
    "models/blockmaker/bm_block_barrier_ct.mdl",
    "models/blockmaker/bm_block_barrier_t.mdl",
    "models/blockmaker/bm_block_bootsofspeed.mdl",
    "models/blockmaker/bm_block_glass.mdl",
    "models/blockmaker/bm_block_bhop_noslow.mdl",
    "models/blockmaker/bm_block_autobhop.mdl"
};

// Sounds
static const char SND_NUKE_EXPLOSION[] = "blockmaker/weapons/c4_explode1.wav";
static const char SND_FIRE_FLAME[] = "blockmaker/ambience/flameburst1.wav";
static const char SND_INVINCIBLE[] = "blockmaker/warcraft3/divineshield.wav";
static const char SND_CAMOUFLAGE[] = "blockmaker/warcraft3/antend.wav";
static const char SND_STEALTH[] = "blockmaker/warcraft3/levelupcaster.wav";
static const char SND_BOOTSOFSPEED[] = "blockmaker/warcraft3/purgetarget1.wav";
static const char SND_AUTOBHOP[] = "blockmaker/boing.wav";
static const char SND_TELEPORT[] = "blockmaker/warcraft3/blinkarrival.wav";

// Sprites/materials for teleports
static const char MAT_TELEPORT_START[] = "sprites/blockmaker/flare6.vmt";
static const char MAT_TELEPORT_END[] = "sprites/blockmaker/bm_teleport_end.vmt";

// Timer models
static const char TIMER_MODEL_START[] = "models/blockmaker/bm_timer_start.mdl";
static const char TIMER_MODEL_END[] = "models/blockmaker/bm_timer_end.mdl";

// Block dimensions (for AXIS_Z = flat block on ground)
static const float BLOCK_MINS_Z[3] = {-32.0, -32.0, -4.0};
static const float BLOCK_MAXS_Z[3] = { 32.0,  32.0,  4.0};
static const float BLOCK_MINS_X[3] = {-4.0, -32.0, -32.0};
static const float BLOCK_MAXS_X[3] = { 4.0,  32.0,  32.0};
static const float BLOCK_MINS_Y[3] = {-32.0, -4.0, -32.0};
static const float BLOCK_MAXS_Y[3] = { 32.0,  4.0,  32.0};

static const float TELEPORT_Z_OFFSET = 36.0;
static const float TIMER_MINS[3] = {-8.0, -8.0,  0.0};
static const float TIMER_MAXS[3] = { 8.0,  8.0, 60.0};

// ============== GLOBAL VARIABLES ==============
// Block models (can be overridden by config)
char g_szBlockModels[MAX_BLOCKS][256];

// Block rendering properties
int g_Render[MAX_BLOCKS];
int g_Red[MAX_BLOCKS];
int g_Green[MAX_BLOCKS];
int g_Blue[MAX_BLOCKS];
int g_Alpha[MAX_BLOCKS];

// CVARs
ConVar g_cvTelefrags;
ConVar g_cvFireDamage;
ConVar g_cvDamageAmount;
ConVar g_cvHealAmount;
ConVar g_cvInvincibleTime;
ConVar g_cvInvincibleCooldown;
ConVar g_cvStealthTime;
ConVar g_cvStealthCooldown;
ConVar g_cvCamouflageTime;
ConVar g_cvCamouflageCooldown;
ConVar g_cvNukeCooldown;
ConVar g_cvRandomCooldown;
ConVar g_cvBootsOfSpeedTime;
ConVar g_cvBootsOfSpeedCooldown;
ConVar g_cvAutoBhopTime;
ConVar g_cvAutoBhopCooldown;
ConVar g_cvTeleportSound;

// File path for saving/loading
char g_szSaveFile[PLATFORM_MAX_PATH];

// Per-player variables
int g_BlockSize[MAXPLAYERS_CONST];
int g_SelectedBlockType[MAXPLAYERS_CONST];
int g_TeleportStart[MAXPLAYERS_CONST];
int g_iLastAimedBlock[MAXPLAYERS_CONST];
int g_StartTimer[MAXPLAYERS_CONST];
int g_Grabbed[MAXPLAYERS_CONST];
int g_MeasureBlock1[MAXPLAYERS_CONST];
int g_MeasureBlock2[MAXPLAYERS_CONST];
int g_LongJumpDistance[MAXPLAYERS_CONST];
int g_LongJumpAxis[MAXPLAYERS_CONST];

bool g_bSnapping[MAXPLAYERS_CONST];
bool g_bNoFallDamage[MAXPLAYERS_CONST];
bool g_bOnIce[MAXPLAYERS_CONST];
float g_fIceVelocity[MAXPLAYERS_CONST][3];
bool g_bNoSlowDown[MAXPLAYERS_CONST];
bool g_bLowGravity[MAXPLAYERS_CONST];
bool g_bOnFire[MAXPLAYERS_CONST];
bool g_bAutoBhop[MAXPLAYERS_CONST];
bool g_bAdminGodmode[MAXPLAYERS_CONST];
bool g_bAdminNoclip[MAXPLAYERS_CONST];
bool g_bHasTimer[MAXPLAYERS_CONST];

float g_fSnappingGap[MAXPLAYERS_CONST];
float g_fGrabLength[MAXPLAYERS_CONST];
float g_fGrabOffset[MAXPLAYERS_CONST][3];
float g_fNextHealTime[MAXPLAYERS_CONST];
float g_fNextDamageTime[MAXPLAYERS_CONST];
float g_fNextFireTime[MAXPLAYERS_CONST];
float g_fInvincibleNextUse[MAXPLAYERS_CONST];
float g_fInvincibleTimeOut[MAXPLAYERS_CONST];
float g_fStealthNextUse[MAXPLAYERS_CONST];
float g_fStealthTimeOut[MAXPLAYERS_CONST];
float g_fTrampolineTimeout[MAXPLAYERS_CONST];
float g_fSpeedBoostTimeOut[MAXPLAYERS_CONST];
ArrayList g_ArrowYaws; // per-block last arrow yaw for speedboost

float g_fNukeNextUse[MAXPLAYERS_CONST];
float g_fCamouflageNextUse[MAXPLAYERS_CONST];
float g_fCamouflageTimeOut[MAXPLAYERS_CONST];
float g_fRandomNextUse[MAXPLAYERS_CONST];
float g_fBootsOfSpeedTimeOut[MAXPLAYERS_CONST];
float g_fBootsOfSpeedNextUse[MAXPLAYERS_CONST];
float g_fAutoBhopTimeOut[MAXPLAYERS_CONST];
float g_fAutoBhopNextUse[MAXPLAYERS_CONST];
float g_fTimerTime[MAXPLAYERS_CONST];
float g_fLastTeleport[MAXPLAYERS_CONST];
int g_iLastButtons[MAXPLAYERS_CONST];
float g_fMeasurePos1[MAXPLAYERS_CONST][3];
float g_fMeasurePos2[MAXPLAYERS_CONST][3];

char g_szCamouflageOldModel[MAXPLAYERS_CONST][128];

// Timer scoreboard
float g_fScoreTimes[MAX_SCORE_ENTRIES];
char g_szScoreNames[MAX_SCORE_ENTRIES][64];
char g_szScoreSteamIds[MAX_SCORE_ENTRIES][64];

// Entity tracking (using ArrayList since we can't use classnames directly on prop_dynamic)
ArrayList g_BlockEntities;          // entity refs
ArrayList g_BlockTypes;             // block type per entity
ArrayList g_BlockSprites;           // sprite entity ref per block
ArrayList g_BlockRandomType;        // random block type per entity
ArrayList g_BlockSizes;             // size per block (SIZE_*)
ArrayList g_BlockAxes;              // axis per block (AXIS_*)
ArrayList g_BlockOrigins;           // float[3] origin per block (for recreate on restart)
ArrayList g_TeleportStartEnts;      // teleport start entity refs
ArrayList g_TeleportEndEnts;        // teleport end entity refs  
ArrayList g_TeleportLinks;          // linked entity ref (start->end, end->start)
ArrayList g_TeleportStartPos;       // float[3] start positions (for recreate)
ArrayList g_TeleportEndPos;         // float[3] end positions (for recreate)
ArrayList g_TimerEntities;          // timer entity refs
ArrayList g_TimerTypes;             // TIMER_START or TIMER_END
ArrayList g_TimerLinks;             // linked timer entity ref
ArrayList g_TimerOrigins;           // float[3] origins (for recreate)
ArrayList g_TimerAngles;            // float[3] angles (for recreate)

// Beam sprite
int g_BeamSprite;
int g_HaloSprite;

// Bhop block timer handles
Handle g_hBhopSolidTimer[2049];     // entity index -> timer handle for making solid again
float g_fBlockFireSoundTime[2049];  // per-entity next fire sound time

// ============== PLUGIN INFO ==============
public Plugin myinfo = {
    name = "Block Maker",
    author = PLUGIN_AUTHOR,
    description = "Create obstacle courses with various block types",
    version = PLUGIN_VERSION,
    url = ""
};

// ============== FORWARDS ==============
public void OnPluginStart()
{
    LoadTranslations("blockmaker.phrases");
    
    // Register CVARs
    g_cvTelefrags = CreateConVar("bm_telefrags", "1", "Players near teleport exit die if someone comes through");
    g_cvFireDamage = CreateConVar("bm_firedamageamount", "20.0", "Damage per half-second on fire block");
    g_cvDamageAmount = CreateConVar("bm_damageamount", "5.0", "Damage per half-second on damage block");
    g_cvHealAmount = CreateConVar("bm_healamount", "1.0", "HP per half-second on healing block");
    g_cvInvincibleTime = CreateConVar("bm_invincibletime", "20.0", "Duration of invincibility");
    g_cvInvincibleCooldown = CreateConVar("bm_invinciblecooldown", "60.0", "Cooldown for invincibility block");
    g_cvStealthTime = CreateConVar("bm_stealthtime", "20.0", "Duration of stealth");
    g_cvStealthCooldown = CreateConVar("bm_stealthcooldown", "60.0", "Cooldown for stealth block");
    g_cvCamouflageTime = CreateConVar("bm_camouflagetime", "20.0", "Duration of camouflage");
    g_cvCamouflageCooldown = CreateConVar("bm_camouflagecooldown", "60.0", "Cooldown for camouflage block");
    g_cvNukeCooldown = CreateConVar("bm_nukecooldown", "60.0", "Cooldown for nuke block");
    g_cvRandomCooldown = CreateConVar("bm_randomcooldown", "30.0", "Cooldown for random block");
    g_cvBootsOfSpeedTime = CreateConVar("bm_bootsofspeedtime", "20.0", "Duration of boots of speed");
    g_cvBootsOfSpeedCooldown = CreateConVar("bm_bootsofspeedcooldown", "60.0", "Cooldown for boots of speed");
    g_cvAutoBhopTime = CreateConVar("bm_autobhoptime", "20.0", "Duration of auto bhop");
    g_cvAutoBhopCooldown = CreateConVar("bm_autobhopcooldown", "60.0", "Cooldown for auto bhop");
    g_cvTeleportSound = CreateConVar("bm_teleportsound", "1", "Teleporters make sound");
    
    AutoExecConfig(true, "blockmaker");
    
    // Register commands
    RegConsoleCmd("sm_bm", Cmd_ShowMainMenu, "Open Block Maker menu");
    RegConsoleCmd("say", Cmd_Say);
    RegAdminCmd("sm_bmgrab", Cmd_Grab, ADMFLAG_GENERIC, "Grab a block");
    RegAdminCmd("sm_bmrelease", Cmd_Release, ADMFLAG_GENERIC, "Release a block");
    RegConsoleCmd("+bmgrab", Cmd_Grab);
    RegConsoleCmd("-bmgrab", Cmd_Release);
    
    // Hook events
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // Create ArrayLists
    g_BlockEntities = new ArrayList();
    g_BlockTypes = new ArrayList();
    g_BlockSprites = new ArrayList();
    g_ArrowYaws = new ArrayList();
    g_BlockRandomType = new ArrayList();
    g_BlockSizes = new ArrayList();
    g_BlockAxes = new ArrayList();
    g_BlockOrigins = new ArrayList(3);
    g_TeleportStartEnts = new ArrayList();
    g_TeleportEndEnts = new ArrayList();
    g_TeleportLinks = new ArrayList();
    g_TeleportStartPos = new ArrayList(3);
    g_TeleportEndPos = new ArrayList(3);
    g_TimerEntities = new ArrayList();
    g_TimerTypes = new ArrayList();
    g_TimerLinks = new ArrayList();
    g_TimerOrigins = new ArrayList(3);
    g_TimerAngles = new ArrayList(3);
    
    // Init score times
    for (int i = 0; i < MAX_SCORE_ENTRIES; i++) {
        g_fScoreTimes[i] = 999999.9;
        g_szScoreNames[i][0] = '\0';
        g_szScoreSteamIds[i][0] = '\0';
    }
    
    // Init bhop timers
    for (int i = 0; i < 2049; i++) {
        g_hBhopSolidTimer[i] = null;
        g_fBlockFireSoundTime[i] = 0.0;
    }
    
    // Build save path
    char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));
    BuildPath(Path_SM, g_szSaveFile, sizeof(g_szSaveFile), "data/blockmaker/%s.bm", szMap);
    
    // Create blockmaker data directory
    char szDir[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szDir, sizeof(szDir), "data/blockmaker");
    if (!DirExists(szDir)) {
        CreateDirectory(szDir, 511);
    }
    
    // Late load support
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            OnClientPutInServer(i);
            if (IsPlayerAlive(i)) {
                SDKHook(i, SDKHook_PreThink, OnPreThink);
                SDKHook(i, SDKHook_PostThink, OnPostThink);
            }
        }
    }
}

public void OnMapStart()
{
    // Set block models to defaults
    for (int i = 0; i < MAX_BLOCKS; i++) {
        strcopy(g_szBlockModels[i], sizeof(g_szBlockModels[]), g_szDefaultBlockModels[i]);
        g_Render[i] = BM_RENDER_NORMAL;
        g_Red[i] = 255;
        g_Green[i] = 255;
        g_Blue[i] = 255;
        g_Alpha[i] = 255;
    }
    
    // Setup default rendering
    SetupBlockRendering(BM_INVINCIBILITY, BM_RENDER_GLOWSHELL, 255, 255, 255, 16);
    SetupBlockRendering(BM_STEALTH, BM_RENDER_TRANSWHITE, 255, 255, 255, 100);
    SetupBlockRendering(BM_GLASS, BM_RENDER_TRANSALPHA, 255, 255, 255, 50);
    
    // Precache models
    for (int i = 0; i < MAX_BLOCKS; i++) {
        if (FileExists(g_szBlockModels[i], true)) {
            PrecacheModel(g_szBlockModels[i], true);
        }
        // Try small and large variants
        char szSmall[256], szLarge[256];
        GetBlockModelSmall(szSmall, sizeof(szSmall), g_szBlockModels[i]);
        GetBlockModelLarge(szLarge, sizeof(szLarge), g_szBlockModels[i]);
        if (FileExists(szSmall, true)) PrecacheModel(szSmall, true);
        if (FileExists(szLarge, true)) PrecacheModel(szLarge, true);
    }
    
    if (FileExists(TIMER_MODEL_START, true)) PrecacheModel(TIMER_MODEL_START, true);
    if (FileExists(TIMER_MODEL_END, true)) PrecacheModel(TIMER_MODEL_END, true);
    
    // Precache sounds
    char szSoundPath[256];
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_INVINCIBLE);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_INVINCIBLE, true);
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_CAMOUFLAGE);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_CAMOUFLAGE, true);
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_STEALTH);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_STEALTH, true);
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_BOOTSOFSPEED);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_BOOTSOFSPEED, true);
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_AUTOBHOP);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_AUTOBHOP, true);
    
    Format(szSoundPath, sizeof(szSoundPath), "sound/%s", SND_TELEPORT);
    if (FileExists(szSoundPath, true)) PrecacheSound(SND_TELEPORT, true);
    
    PrecacheSound(SND_NUKE_EXPLOSION, true);
    PrecacheSound(SND_FIRE_FLAME, true);
    
    // Precache beam sprite
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
    g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt", true);
    PrecacheModel("sprites/blockmaker/trampoline.vmt", true);
    PrecacheModel("sprites/blockmaker/speedboost.vmt", true);
    PrecacheModel("sprites/blockmaker/fire.vmt", true);
    PrecacheModel(MAT_TELEPORT_START, true);
    PrecacheModel(MAT_TELEPORT_END, true);
    
    // ============== DOWNLOAD TABLE ==============
    // Block models (normal, small, large variants)
    char szDL[256];
    for (int i = 0; i < MAX_BLOCKS; i++) {
        AddModelToDownloadsTable(g_szDefaultBlockModels[i]);
        
        char szSmallDL[256], szLargeDL[256];
        GetBlockModelSmall(szSmallDL, sizeof(szSmallDL), g_szDefaultBlockModels[i]);
        GetBlockModelLarge(szLargeDL, sizeof(szLargeDL), g_szDefaultBlockModels[i]);
        AddModelToDownloadsTable(szSmallDL);
        AddModelToDownloadsTable(szLargeDL);
    }
    
    // Timer models
    AddModelToDownloadsTable(TIMER_MODEL_START);
    AddModelToDownloadsTable(TIMER_MODEL_END);
    
    // Sprites (vmt + vtf)
    AddFileToDownloadsTable("materials/sprites/blockmaker/trampoline.vmt");
    AddFileToDownloadsTable("materials/sprites/blockmaker/trampoline.vtf");
    AddFileToDownloadsTable("materials/sprites/blockmaker/speedboost.vmt");
    AddFileToDownloadsTable("materials/sprites/blockmaker/speedboost.vtf");
    AddFileToDownloadsTable("materials/sprites/blockmaker/fire.vmt");
    AddFileToDownloadsTable("materials/sprites/blockmaker/fire.vtf");
    AddFileToDownloadsTable("materials/sprites/blockmaker/flare6.vmt");
    AddFileToDownloadsTable("materials/sprites/blockmaker/flare6.vtf");
    AddFileToDownloadsTable("materials/sprites/blockmaker/bm_teleport_end.vmt");
    AddFileToDownloadsTable("materials/sprites/blockmaker/bm_teleport_end.vtf");
    
    // Block model materials (vmt + vtf)
    static const char g_szBlockMaterialNames[][] = {
        "platform", "bhop", "damage", "healer", "nofalldamage", "ice",
        "trampoline", "speedboost", "invincibility", "stealth", "death", "nuke",
        "camouflage", "lowgravity", "fire", "slap", "random", "honey",
        "barrier_ct", "barrier_t", "bootsofspeed", "glass", "bhop_noslow", "autobhop"
    };
    for (int i = 0; i < sizeof(g_szBlockMaterialNames); i++) {
        char szMatVmt[256], szMatVtf[256];
        Format(szMatVmt, sizeof(szMatVmt), "materials/blockmaker/%s.vmt", g_szBlockMaterialNames[i]);
        Format(szMatVtf, sizeof(szMatVtf), "materials/blockmaker/%s.vtf", g_szBlockMaterialNames[i]);
        if (FileExists(szMatVmt, true)) AddFileToDownloadsTable(szMatVmt);
        if (FileExists(szMatVtf, true)) AddFileToDownloadsTable(szMatVtf);
    }
    
    // Timer model materials (vmt + vtf)
    static const char g_szTimerMaterialNames[][] = {
        "start", "end", "sides", "button"
    };
    for (int i = 0; i < sizeof(g_szTimerMaterialNames); i++) {
        char szMatVmt[256], szMatVtf[256];
        Format(szMatVmt, sizeof(szMatVmt), "materials/blockmaker/timer/%s.vmt", g_szTimerMaterialNames[i]);
        Format(szMatVtf, sizeof(szMatVtf), "materials/blockmaker/timer/%s.vtf", g_szTimerMaterialNames[i]);
        if (FileExists(szMatVmt, true)) AddFileToDownloadsTable(szMatVmt);
        if (FileExists(szMatVtf, true)) AddFileToDownloadsTable(szMatVtf);
    }
    
    // Sounds
    Format(szDL, sizeof(szDL), "sound/%s", SND_NUKE_EXPLOSION); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_FIRE_FLAME); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_INVINCIBLE); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_CAMOUFLAGE); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_STEALTH); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_BOOTSOFSPEED); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_AUTOBHOP); AddFileToDownloadsTable(szDL);
    Format(szDL, sizeof(szDL), "sound/%s", SND_TELEPORT); AddFileToDownloadsTable(szDL);
    
    // Clear entity lists
    g_BlockEntities.Clear();
    g_BlockTypes.Clear();
    g_BlockSprites.Clear();
    g_ArrowYaws.Clear();
    g_BlockRandomType.Clear();
    g_BlockSizes.Clear();
    g_BlockAxes.Clear();
    g_BlockOrigins.Clear();
    g_TeleportStartEnts.Clear();
    g_TeleportEndEnts.Clear();
    g_TeleportLinks.Clear();
    g_TeleportStartPos.Clear();
    g_TeleportEndPos.Clear();
    g_TimerEntities.Clear();
    g_TimerTypes.Clear();
    g_TimerLinks.Clear();
    g_TimerOrigins.Clear();
    g_TimerAngles.Clear();
    
    for (int i = 0; i < 2049; i++) {
        g_hBhopSolidTimer[i] = null;
        g_fBlockFireSoundTime[i] = 0.0;
    }
    
    // Build save path for current map
    char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));
    BuildPath(Path_SM, g_szSaveFile, sizeof(g_szSaveFile), "data/blockmaker/%s.bm", szMap);
    
    // Load blocks from file
    CreateTimer(1.0, Timer_LoadBlocks);
    
    // Create the game frame timer for block effects
    CreateTimer(0.1, Timer_BlockEffects, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    
    // Arrow rotation timer for speedboost blocks
    CreateTimer(0.1, Timer_UpdateArrows, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
    g_bSnapping[client] = true;
    g_fSnappingGap[client] = 0.0;
    g_bNoFallDamage[client] = false;
    g_bAdminGodmode[client] = false;
    g_bAdminNoclip[client] = false;
    g_LongJumpDistance[client] = 240;
    g_LongJumpAxis[client] = AXIS_X;
    g_SelectedBlockType[client] = BM_PLATFORM;
    g_BlockSize[client] = SIZE_NORMAL;
    g_Grabbed[client] = INVALID_ENT_REFERENCE;
    g_TeleportStart[client] = INVALID_ENT_REFERENCE;
    g_StartTimer[client] = INVALID_ENT_REFERENCE;
    g_MeasureBlock1[client] = INVALID_ENT_REFERENCE;
    g_MeasureBlock2[client] = INVALID_ENT_REFERENCE;
    
    ResetPlayerEffects(client);
    
    SDKHook(client, SDKHook_PreThink, OnPreThink);
    SDKHook(client, SDKHook_PostThink, OnPostThink);
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    if (g_Grabbed[client] != INVALID_ENT_REFERENCE) {
        int ent = EntRefToEntIndex(g_Grabbed[client]);
        if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
            SetEntProp(ent, Prop_Data, "m_iHammerID", 0); // clear grabbed flag
        }
        g_Grabbed[client] = INVALID_ENT_REFERENCE;
    }
}

// ============== RESET FUNCTIONS ==============
void ResetPlayerEffects(int client)
{
    g_iLastAimedBlock[client] = -1;
    g_fInvincibleTimeOut[client] = 0.0;
    g_fInvincibleNextUse[client] = 0.0;
    g_fStealthTimeOut[client] = 0.0;
    g_fStealthNextUse[client] = 0.0;
    g_fCamouflageTimeOut[client] = 0.0;
    g_fCamouflageNextUse[client] = 0.0;
    g_fNukeNextUse[client] = 0.0;
    g_bOnFire[client] = false;
    g_fRandomNextUse[client] = 0.0;
    g_fBootsOfSpeedTimeOut[client] = 0.0;
    g_fBootsOfSpeedNextUse[client] = 0.0;
    g_fAutoBhopTimeOut[client] = 0.0;
    g_fAutoBhopNextUse[client] = 0.0;
    g_fNextHealTime[client] = 0.0;
    g_fNextDamageTime[client] = 0.0;
    g_fNextFireTime[client] = 0.0;
    g_fTrampolineTimeout[client] = 0.0;
    g_fSpeedBoostTimeOut[client] = 0.0;
    g_bOnIce[client] = false;
    g_bNoSlowDown[client] = false;
    g_bAutoBhop[client] = false;
    g_bNoFallDamage[client] = false;
    g_bLowGravity[client] = false;
    g_bHasTimer[client] = false;
    g_iLastButtons[client] = 0;
    g_fIceVelocity[client][0] = 0.0;
    g_fIceVelocity[client][1] = 0.0;
    g_fIceVelocity[client][2] = 0.0;
    g_fLastTeleport[client] = 0.0;
    g_szCamouflageOldModel[client][0] = '\0';
    
    if (IsClientInGame(client)) {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
        SetEntityRenderFx(client, RENDERFX_NONE);
        SetEntProp(client, Prop_Data, "m_takedamage", 2); // DAMAGE_YES
        SetEntityGravity(client, 1.0);
        SetEntPropFloat(client, Prop_Data, "m_flFriction", 1.0); // reset ice friction
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
}

// ============== EVENTS ==============
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients) {
        ResetPlayerEffects(client);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            ResetPlayerEffects(i);
        }
    }
    
    // Check if entities were wiped (mp_restartgame or game restart)
    // If we had blocks tracked but the first one is now invalid, all were cleaned up
    bool bEntitiesWiped = false;
    if (g_BlockEntities.Length > 0) {
        int entRef = g_BlockEntities.Get(0);
        int ent = EntRefToEntIndex(entRef);
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent)) {
            bEntitiesWiped = true;
        }
    } else if (g_TeleportStartEnts.Length > 0) {
        int entRef = g_TeleportStartEnts.Get(0);
        int ent = EntRefToEntIndex(entRef);
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent)) {
            bEntitiesWiped = true;
        }
    } else if (g_TimerEntities.Length > 0) {
        int entRef = g_TimerEntities.Get(0);
        int ent = EntRefToEntIndex(entRef);
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent)) {
            bEntitiesWiped = true;
        }
    }
    
    if (bEntitiesWiped) {
        // Entities wiped by mp_restartgame - recreate from memory
        int numBlocks = g_BlockTypes.Length;
        int numTele = g_TeleportStartPos.Length;
        int numTimers = g_TimerEntities.Length;
        
        // Save block data (flat arrays: origins stored as x,y,z,x,y,z,...)
        int[] savedBType = new int[numBlocks];
        int[] savedBSize = new int[numBlocks];
        int[] savedBAxis = new int[numBlocks];
        float[] savedBOrig = new float[numBlocks * 3];
        for (int i = 0; i < numBlocks; i++) {
            savedBType[i] = g_BlockTypes.Get(i);
            savedBSize[i] = g_BlockSizes.Get(i);
            savedBAxis[i] = g_BlockAxes.Get(i);
            float tmp[3];
            g_BlockOrigins.GetArray(i, tmp, 3);
            savedBOrig[i*3] = tmp[0]; savedBOrig[i*3+1] = tmp[1]; savedBOrig[i*3+2] = tmp[2];
        }
        
        // Save teleport data
        float[] savedTStart = new float[numTele * 3];
        float[] savedTEnd = new float[numTele * 3];
        for (int i = 0; i < numTele; i++) {
            float tmp[3];
            g_TeleportStartPos.GetArray(i, tmp, 3);
            savedTStart[i*3] = tmp[0]; savedTStart[i*3+1] = tmp[1]; savedTStart[i*3+2] = tmp[2];
            g_TeleportEndPos.GetArray(i, tmp, 3);
            savedTEnd[i*3] = tmp[0]; savedTEnd[i*3+1] = tmp[1]; savedTEnd[i*3+2] = tmp[2];
        }
        
        // Save timer data
        int[] savedTmType = new int[numTimers];
        float[] savedTmOrig = new float[numTimers * 3];
        float[] savedTmAng = new float[numTimers * 3];
        for (int i = 0; i < numTimers; i++) {
            savedTmType[i] = g_TimerTypes.Get(i);
            float tmp[3];
            g_TimerOrigins.GetArray(i, tmp, 3);
            savedTmOrig[i*3] = tmp[0]; savedTmOrig[i*3+1] = tmp[1]; savedTmOrig[i*3+2] = tmp[2];
            g_TimerAngles.GetArray(i, tmp, 3);
            savedTmAng[i*3] = tmp[0]; savedTmAng[i*3+1] = tmp[1]; savedTmAng[i*3+2] = tmp[2];
        }
        
        // Clear all tracking
        g_BlockEntities.Clear(); g_BlockTypes.Clear(); g_BlockSprites.Clear();
        g_ArrowYaws.Clear();
        g_BlockRandomType.Clear(); g_BlockSizes.Clear(); g_BlockAxes.Clear(); g_BlockOrigins.Clear();
        g_TeleportStartEnts.Clear(); g_TeleportEndEnts.Clear(); g_TeleportLinks.Clear();
        g_TeleportStartPos.Clear(); g_TeleportEndPos.Clear();
        g_TimerEntities.Clear(); g_TimerTypes.Clear(); g_TimerLinks.Clear();
        g_TimerOrigins.Clear(); g_TimerAngles.Clear();
        
        for (int i = 1; i <= MaxClients; i++) {
            g_TeleportStart[i] = INVALID_ENT_REFERENCE;
            g_StartTimer[i] = INVALID_ENT_REFERENCE;
            g_bHasTimer[i] = false;
        }
        
        // Recreate blocks
        for (int i = 0; i < numBlocks; i++) {
            float orig[3];
            orig[0] = savedBOrig[i*3]; orig[1] = savedBOrig[i*3+1]; orig[2] = savedBOrig[i*3+2];
            CreateBlockEntity(0, savedBType[i], orig, savedBAxis[i], savedBSize[i]);
        }
        
        // Recreate teleports
        for (int i = 0; i < numTele; i++) {
            float sPos[3], ePos[3];
            sPos[0] = savedTStart[i*3]; sPos[1] = savedTStart[i*3+1]; sPos[2] = savedTStart[i*3+2];
            ePos[0] = savedTEnd[i*3]; ePos[1] = savedTEnd[i*3+1]; ePos[2] = savedTEnd[i*3+2];
            CreateTeleportEntity(0, TELEPORT_START, sPos);
            CreateTeleportEntity(0, TELEPORT_END, ePos);
        }
        
        // Recreate timers (find start/end pairs)
        for (int i = 0; i < numTimers; i++) {
            if (savedTmType[i] == TIMER_START) {
                for (int j = 0; j < numTimers; j++) {
                    if (savedTmType[j] == TIMER_END) {
                        float sOrig[3], sAng[3], eOrig[3], eAng[3];
                        sOrig[0] = savedTmOrig[i*3]; sOrig[1] = savedTmOrig[i*3+1]; sOrig[2] = savedTmOrig[i*3+2];
                        sAng[0] = savedTmAng[i*3]; sAng[1] = savedTmAng[i*3+1]; sAng[2] = savedTmAng[i*3+2];
                        eOrig[0] = savedTmOrig[j*3]; eOrig[1] = savedTmOrig[j*3+1]; eOrig[2] = savedTmOrig[j*3+2];
                        eAng[0] = savedTmAng[j*3]; eAng[1] = savedTmAng[j*3+1]; eAng[2] = savedTmAng[j*3+2];
                        CreateTimerEntity(0, TIMER_START, sOrig, sAng);
                        CreateTimerEntity(0, TIMER_END, eOrig, eAng);
                        savedTmType[j] = -1;
                        break;
                    }
                }
            }
        }
        
        return;
    }
    
    // Re-solidify all bhop blocks
    for (int i = 0; i < g_BlockEntities.Length; i++) {
        int entRef = g_BlockEntities.Get(i);
        int ent = EntRefToEntIndex(entRef);
        if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
            int blockType = g_BlockTypes.Get(i);
            if (blockType == BM_BHOP || blockType == BM_BHOP_NOSLOW || blockType == BM_BARRIER_CT || blockType == BM_BARRIER_T) {
                SetEntProp(ent, Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
                SetEntProp(ent, Prop_Send, "m_nSolidType", 6);
                ApplyBlockRendering(ent, blockType);
            }
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients && IsClientInGame(client)) {
        if (g_bAdminGodmode[client]) {
            SetEntProp(client, Prop_Data, "m_takedamage", 0);
        }
        if (g_bAdminNoclip[client]) {
            SetEntityMoveType(client, MOVETYPE_NOCLIP);
        }
        ResetPlayerEffects(client);
    }
}

// ============== PRETHINK / POSTTHINK ==============
public void OnPreThink(int client)
{
    if (!IsClientInGame(client)) return;
    
    // Show block type being aimed at
    if (IsPlayerAlive(client)) {
        int ent = GetClientAimEntity(client, 320.0);
        int blockIdx;
        if (ent > 0 && IsBlockEntity(ent, blockIdx)) {
            if (ent != g_iLastAimedBlock[client]) {
                g_iLastAimedBlock[client] = ent;
                int blockType = g_BlockTypes.Get(blockIdx);
                char szBN[64]; Format(szBN, sizeof(szBN), "%T", g_szBlockTransKeys[blockType], client);
                PrintHintTextSilent(client, "%T", "Hint_BlockType", client, szBN);
            }
        } else {
            g_iLastAimedBlock[client] = -1;
        }
    }
    
    if (!IsPlayerAlive(client)) return;
    
    // Low gravity check - reset when on ground
    if (g_bLowGravity[client]) {
        if (GetEntityFlags(client) & FL_ONGROUND) {
            SetEntityGravity(client, 1.0);
            g_bLowGravity[client] = false;
        }
    }
    
    // Ice sliding effect - preserve velocity to simulate low friction (bypasses sv_friction)
    if (g_bOnIce[client]) {
        SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
        
        int flags = GetEntityFlags(client);
        if (flags & FL_ONGROUND) {
            float vel[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
            
            // Blend: keep most of stored velocity, counteracting engine friction
            // Factor 0.85 = simulates ~0.15 friction ratio (like original AMX)
            float newVel[3];
            newVel[0] = g_fIceVelocity[client][0] * 0.85 + vel[0] * 0.15;
            newVel[1] = g_fIceVelocity[client][1] * 0.85 + vel[1] * 0.15;
            newVel[2] = vel[2]; // don't affect vertical
            
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
            
            g_fIceVelocity[client][0] = newVel[0];
            g_fIceVelocity[client][1] = newVel[1];
            g_fIceVelocity[client][2] = 0.0;
        } else {
            // Airborne - just track current velocity
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fIceVelocity[client]);
        }
    }
    
    // No slow down: remove stamina after jump
    if (g_bNoSlowDown[client]) {
        SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
    }
    
    // Keep player invisible during stealth (engine resets on weapon switch)
    if (GetGameTime() < g_fStealthTimeOut[client]) {
        int r, g, b, a;
        GetEntityRenderColor(client, r, g, b, a);
        if (a != 0) {
            SetEntityRenderMode(client, RENDER_TRANSCOLOR);
            SetEntityRenderColor(client, 255, 255, 255, 0);
        }
    }
    
    // Boots of speed: ~400 movement speed via LaggedMovement
    if (GetGameTime() < g_fBootsOfSpeedTimeOut[client]) {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.6);
    }
    
    // Trace down to detect blocks beneath player
    float pOrigin[3], pMins[3];
    GetClientAbsOrigin(client, pOrigin);
    GetClientMins(client, pMins);
    
    // Calculate feet position
    float feetZ = pOrigin[2] + pMins[2];
    
    // Check center + 4 corners for block detection (5 points)
    static const float s_offsets[5][2] = {
        {0.0, 0.0},       // center
        {-16.0, 16.0},    // corners
        {16.0, 16.0},
        {16.0, -16.0},
        {-16.0, -16.0}
    };
    
    int iDetectedBlock = -1;
    int iDetectedBlockLong = -1;
    
    for (int i = 0; i < 5; i++) {
        float start[3], end[3];
        start[0] = pOrigin[0] + s_offsets[i][0];
        start[1] = pOrigin[1] + s_offsets[i][1];
        start[2] = feetZ;
        end[0] = start[0];
        end[1] = start[1];
        end[2] = feetZ - 2.0;
        
        TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
        if (TR_DidHit()) {
            int hitEnt = TR_GetEntityIndex();
            int blockIdx;
            if (hitEnt > 0 && hitEnt != iDetectedBlock && IsBlockEntity(hitEnt, blockIdx)) {
                int blockType = g_BlockTypes.Get(blockIdx);
                HandleBlockAction(client, hitEnt, blockIdx, blockType);
                iDetectedBlock = hitEnt;
            }
        }
        
        // Longer trace for trampoline, no fall damage, ice, bhop noslow
        end[2] = feetZ - 20.0;
        TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
        if (TR_DidHit()) {
            int hitEnt = TR_GetEntityIndex();
            int blockIdx;
            if (hitEnt > 0 && hitEnt != iDetectedBlockLong && IsBlockEntity(hitEnt, blockIdx)) {
                int blockType = g_BlockTypes.Get(blockIdx);
                HandleBlockActionLong(client, blockType);
                iDetectedBlockLong = hitEnt;
            }
        }
    }
    
    // Display timer running HUD and buff timeleft
    float fTime = GetGameTime();
    
    if (g_bHasTimer[client]) {
        float fElapsed = fTime - g_fTimerTime[client];
        int iMins = RoundToFloor(fElapsed / 60.0);
        float fSecs = fElapsed - (iMins * 60.0);
        char szTimerHud[64];
        Format(szTimerHud, sizeof(szTimerHud), "Time: %s%d:%s%.2f",
            (iMins < 10 ? "0" : ""), iMins,
            (fSecs < 10.0 ? "0" : ""), fSecs);
        SetHudTextParams(-1.0, 0.01, 0.25, 255, 255, 0, 255);
        ShowHudText(client, 3, "%s", szTimerHud);
    }
    
    // Display buff timeleft
    char szText[256] = "";
    bool bShowText = false;
    char szLine[64];
    
    float fTLInv = g_fInvincibleTimeOut[client] - fTime;
    float fTLSte = g_fStealthTimeOut[client] - fTime;
    float fTLCam = g_fCamouflageTimeOut[client] - fTime;
    float fTLBos = g_fBootsOfSpeedTimeOut[client] - fTime;
    float fTLAbh = g_fAutoBhopTimeOut[client] - fTime;
    
    if (fTLInv >= 0.0) {
        Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_Invincible", client, fTLInv);
        StrCat(szText, sizeof(szText), szLine);
        bShowText = true;
    }
    if (fTLSte >= 0.0) {
        Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_Stealth", client, fTLSte);
        StrCat(szText, sizeof(szText), szLine);
        bShowText = true;
    }
    if (fTLCam >= 0.0) {
        int team = GetClientTeam(client);
        if (team == CS_TEAM_CT)
            Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_CamoT", client, fTLCam);
        else
            Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_CamoCT", client, fTLCam);
        StrCat(szText, sizeof(szText), szLine);
        bShowText = true;
    }
    if (fTLBos >= 0.0) {
        Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_BootsOfSpeed", client, fTLBos);
        StrCat(szText, sizeof(szText), szLine);
        bShowText = true;
    }
    if (fTLAbh >= 0.0) {
        Format(szLine, sizeof(szLine), "%T: %.1f\n", "Hud_AutoBhop", client, fTLAbh);
        StrCat(szText, sizeof(szText), szLine);
        bShowText = true;
    }
    
    if (bShowText) {
        SetHudTextParams(-1.0, 0.84, 0.25, 10, 30, 200, 255);
        ShowHudText(client, 2, "%s", szText);
    }
    
    // Handle grabbed entity movement
    if (g_Grabbed[client] != INVALID_ENT_REFERENCE) {
        int grabbed = EntRefToEntIndex(g_Grabbed[client]);
        if (grabbed != INVALID_ENT_REFERENCE && IsValidEntity(grabbed)) {
            MoveGrabbedEntity(client, grabbed);
        } else {
            g_Grabbed[client] = INVALID_ENT_REFERENCE;
        }
        
        // Handle attack/attack2 while grabbing
        int buttons = GetClientButtons(client);
        // Block primary attack while grabbing
        if (buttons & IN_ATTACK) {
            buttons &= ~IN_ATTACK;
            SetEntProp(client, Prop_Data, "m_nButtons", buttons);
        }
    }
}

public void OnPostThink(int client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;
    
    // Keep resetting fall velocity while no fall damage is active
    // The flag is cleared by OnTakeDamage when actual fall damage occurs,
    // or when player touches ground without taking damage
    if (g_bNoFallDamage[client]) {
        if (GetEntityFlags(client) & FL_ONGROUND) {
            // Safely on ground, clear the flag
            g_bNoFallDamage[client] = false;
        }
    }
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (victim > 0 && victim <= MaxClients) {
        // Check invincibility
        if (GetGameTime() < g_fInvincibleTimeOut[victim]) {
            return Plugin_Handled;
        }
        
        // Check admin godmode
        if (g_bAdminGodmode[victim]) {
            return Plugin_Handled;
        }
        
        // No fall damage protection
        if (damagetype & DMG_FALL) {
            // Check if flag was already set by OnPreThink
            if (g_bNoFallDamage[victim]) {
                g_bNoFallDamage[victim] = false;
                return Plugin_Handled;
            }
            
            // Direct trace check - OnPreThink may not have run yet when landing
            // Trace downward from player feet to detect NoFallDamage block
            if (IsClientInGame(victim) && IsPlayerAlive(victim)) {
                float origin[3], mins[3];
                GetClientAbsOrigin(victim, origin);
                GetClientMins(victim, mins);
                
                // Check center + 4 offsets beneath feet
                float offsets[5][2];
                offsets[0][0] = 0.0;    offsets[0][1] = 0.0;
                offsets[1][0] = -12.0;  offsets[1][1] = 12.0;
                offsets[2][0] = 12.0;   offsets[2][1] = 12.0;
                offsets[3][0] = 12.0;   offsets[3][1] = -12.0;
                offsets[4][0] = -12.0;  offsets[4][1] = -12.0;
                
                for (int p = 0; p < 5; p++) {
                    float start[3], end[3];
                    start[0] = origin[0] + offsets[p][0];
                    start[1] = origin[1] + offsets[p][1];
                    start[2] = origin[2] + mins[2];
                    end[0] = start[0];
                    end[1] = start[1];
                    end[2] = start[2] - 32.0;
                    
                    TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_NoPlayers, victim);
                    if (TR_DidHit()) {
                        int hitEnt = TR_GetEntityIndex();
                        int blockIdx;
                        if (hitEnt > 0 && IsBlockEntity(hitEnt, blockIdx)) {
                            int blockType = g_BlockTypes.Get(blockIdx);
                            if (blockType == BM_NOFALLDAMAGE) {
                                return Plugin_Handled;
                            }
                        }
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

// ============== BLOCK ACTIONS ==============
void HandleBlockAction(int client, int ent, int blockIdx, int blockType)
{
    switch (blockType) {
        case BM_HEALER: ActionHeal(client);
        case BM_DAMAGE: ActionDamage(client);
        case BM_INVINCIBILITY: ActionInvincible(client, false);
        case BM_STEALTH: ActionStealth(client, false);
        case BM_TRAMPOLINE: ActionTrampoline(client);
        case BM_SPEEDBOOST: ActionSpeedBoost(client);
        case BM_DEATH: ActionDeath(client);
        case BM_NUKE: ActionNuke(client, false);
        case BM_LOWGRAVITY: ActionLowGravity(client);
        case BM_CAMOUFLAGE: ActionCamouflage(client, false);
        case BM_FIRE: ActionFire(client, ent);
        case BM_SLAP: ActionSlap(client);
        case BM_RANDOM: ActionRandom(client, blockIdx);
        case BM_HONEY: ActionHoney(client);
        case BM_BOOTSOFSPEED: ActionBootsOfSpeed(client, false);
        case BM_AUTOBHOP: ActionAutoBhop(client, false);
        case BM_ICE: ActionOnIce(client);
        case BM_NOFALLDAMAGE: ActionNoFallDamage(client);
    }
}

void HandleBlockActionLong(int client, int blockType)
{
    switch (blockType) {
        case BM_TRAMPOLINE: ActionTrampoline(client);
        case BM_NOFALLDAMAGE: ActionNoFallDamage(client);
        case BM_ICE: ActionOnIce(client);
        case BM_BHOP_NOSLOW: ActionNoSlowDown(client);
    }
}

void ActionDamage(int client)
{
    float fTime = GetGameTime();
    if (fTime >= g_fNextDamageTime[client]) {
        if (GetClientHealth(client) > 0) {
            float amount = g_cvDamageAmount.FloatValue;
            SDKHooks_TakeDamage(client, 0, 0, amount, DMG_CRUSH);
        }
        g_fNextDamageTime[client] = fTime + 0.5;
    }
}

void ActionHeal(int client)
{
    float fTime = GetGameTime();
    if (fTime >= g_fNextHealTime[client]) {
        int hp = GetClientHealth(client);
        int amount = RoundToFloor(g_cvHealAmount.FloatValue);
        int sum = hp + amount;
        if (sum < 100)
            SetEntityHealth(client, sum);
        else
            SetEntityHealth(client, 100);
        g_fNextHealTime[client] = fTime + 0.5;
    }
}

void ActionInvincible(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (fTime >= g_fInvincibleNextUse[client] || overrideTimer) {
        float fTimeout = g_cvInvincibleTime.FloatValue;
        
        g_fInvincibleTimeOut[client] = fTime + fTimeout;
        g_fInvincibleNextUse[client] = fTime + fTimeout + g_cvInvincibleCooldown.FloatValue;
        
        CreateTimer(fTimeout, Timer_InvincibleRemove, GetClientUserId(client));
        
        if (fTime >= g_fStealthTimeOut[client]) {
            SetEntityRenderFx(client, RENDERFX_DISTORT);
            SetEntityRenderColor(client, 255, 255, 255, 200);
        }
        
        EmitSoundToAll(SND_INVINCIBLE, client);
    } else {
        PrintHintTextSilent(client, "%T", "Hint_InvincibilityCD", client, g_fInvincibleNextUse[client] - fTime);
    }
}

void ActionStealth(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (fTime >= g_fStealthNextUse[client] || overrideTimer) {
        float fTimeout = g_cvStealthTime.FloatValue;
        
        CreateTimer(fTimeout, Timer_StealthRemove, GetClientUserId(client));
        
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);
        SetEntityRenderColor(client, 255, 255, 255, 0);
        
        EmitSoundToAll(SND_STEALTH, client);
        
        g_fStealthTimeOut[client] = fTime + fTimeout;
        g_fStealthNextUse[client] = fTime + fTimeout + g_cvStealthCooldown.FloatValue;
    } else {
        PrintHintTextSilent(client, "%T", "Hint_StealthCD", client, g_fStealthNextUse[client] - fTime);
    }
}

void ActionTrampoline(int client)
{
    float fTime = GetGameTime();
    if (fTime >= g_fTrampolineTimeout[client]) {
        float velocity[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
        velocity[2] = 500.0;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
        g_fTrampolineTimeout[client] = fTime + 0.5;
    }
}

void ActionSpeedBoost(int client)
{
    float fTime = GetGameTime();
    if (fTime >= g_fSpeedBoostTimeOut[client]) {
        float eyeAng[3], velocity[3];
        GetClientEyeAngles(client, eyeAng);
        GetAngleVectors(eyeAng, velocity, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(velocity, 800.0);
        velocity[2] = 260.0;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
        g_fSpeedBoostTimeOut[client] = fTime + 0.5;
    }
}

void ActionNoFallDamage(int client)
{
    g_bNoFallDamage[client] = true;
}

void ActionOnIce(int client)
{
    if (!g_bOnIce[client]) {
        g_bOnIce[client] = true;
        // Initialize stored velocity from current
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fIceVelocity[client]);
    }
    // Keep refreshing the ice-off timer - fires 0.15s after leaving ice block
    CreateTimer(0.15, Timer_NotOnIce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

void ActionDeath(int client)
{
    if (GetGameTime() >= g_fInvincibleTimeOut[client] && !g_bAdminGodmode[client]) {
        SDKHooks_TakeDamage(client, 0, 0, 10000.0, DMG_GENERIC);
    }
}

void ActionNuke(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (IsPlayerAlive(client) && (fTime >= g_fNukeNextUse[client] || overrideTimer)) {
        int playerTeam = GetClientTeam(client);
        
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                if (IsPlayerAlive(i)) {
                    int team = GetClientTeam(i);
                    if ((team == CS_TEAM_T && playerTeam == CS_TEAM_CT) || (team == CS_TEAM_CT && playerTeam == CS_TEAM_T)) {
                        SDKHooks_TakeDamage(i, client, client, 10000.0, DMG_BLAST);
                    }
                }
                // Screen fade for all players
                Handle msg = StartMessageOne("Fade", i);
                if (msg != null) {
                    BfWriteShort(msg, 1024);  // duration
                    BfWriteShort(msg, 1024);  // hold
                    BfWriteShort(msg, 0x0001); // FFADE_IN
                    BfWriteByte(msg, 255);    // r
                    BfWriteByte(msg, 255);    // g
                    BfWriteByte(msg, 255);    // b
                    BfWriteByte(msg, 255);    // a
                    EndMessage();
                }
            }
        }
        
        EmitSoundToAll(SND_NUKE_EXPLOSION);
        g_fNukeNextUse[client] = fTime + g_cvNukeCooldown.FloatValue;
        
        char szName[64];
        GetClientName(client, szName, sizeof(szName));
        
        char szNukeMsg[128];
        if (playerTeam == CS_TEAM_T) {
            Format(szNukeMsg, sizeof(szNukeMsg), "%T", "Nuke_CT", LANG_SERVER, szName);
        } else {
            Format(szNukeMsg, sizeof(szNukeMsg), "%T", "Nuke_T", LANG_SERVER, szName);
        }
        PrintCenterTextAll("%s", szNukeMsg);
    } else {
        PrintHintTextSilent(client, "%T", "Hint_NukeCD", client, g_fNukeNextUse[client] - fTime);
    }
}

void ActionCamouflage(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (fTime >= g_fCamouflageNextUse[client] || overrideTimer) {
        float fTimeout = g_cvCamouflageTime.FloatValue;
        
        char szModel[64];
        GetClientModel(client, szModel, sizeof(szModel));
        strcopy(g_szCamouflageOldModel[client], sizeof(g_szCamouflageOldModel[]), szModel);
        
        int team = GetClientTeam(client);
        if (team == CS_TEAM_T)
            SetEntityModel(client, "models/player/ct_urban.mdl");
        else
            SetEntityModel(client, "models/player/t_leet.mdl");
        
        EmitSoundToAll(SND_CAMOUFLAGE, client);
        CreateTimer(fTimeout, Timer_CamouflageRemove, GetClientUserId(client));
        
        g_fCamouflageTimeOut[client] = fTime + fTimeout;
        g_fCamouflageNextUse[client] = fTime + fTimeout + g_cvCamouflageCooldown.FloatValue;
    } else {
        PrintHintTextSilent(client, "%T", "Hint_CamouflageCD", client, g_fCamouflageNextUse[client] - fTime);
    }
}

void ActionLowGravity(int client)
{
    SetEntityGravity(client, 0.25);
    g_bLowGravity[client] = true;
}

void ActionFire(int client, int ent)
{
    float fTime = GetGameTime();
    if (fTime >= g_fNextFireTime[client]) {
        int hp = GetClientHealth(client);
        if (hp > 0 && GetGameTime() >= g_fInvincibleTimeOut[client] && !g_bAdminGodmode[client]) {
            float amount = g_cvFireDamage.FloatValue / 10.0;
            float newAmount = float(hp) - amount;
            if (newAmount > 0.0)
                SetEntityHealth(client, RoundToFloor(newAmount));
            else
                SDKHooks_TakeDamage(client, 0, 0, amount, DMG_BURN);
            
            // Set player on fire briefly
            IgniteEntity(client, 0.5);
        }
        
        // Fire sound per-block cooldown
        if (IsValidEntity(ent) && ent < 2049) {
            if (fTime >= g_fBlockFireSoundTime[ent]) {
                EmitSoundToAll(SND_FIRE_FLAME, ent, _, _, _, 0.6);
                g_fBlockFireSoundTime[ent] = fTime + 0.75;
            }
        }
        
        g_fNextFireTime[client] = fTime + 0.05;
    }
}

void ActionSlap(int client)
{
    // Random horizontal direction + massive upward launch
    float vel[3];
    vel[0] = GetRandomFloat(-500.0, 500.0);
    vel[1] = GetRandomFloat(-500.0, 500.0);
    vel[2] = 1000.0;
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
    
    char slapSnd[64];
    FormatEx(slapSnd, sizeof(slapSnd), "player/damage%d.wav", GetRandomInt(1, 3));
    EmitSoundToAll(slapSnd, client);
    
    char szSlapMsg[64];
    Format(szSlapMsg, sizeof(szSlapMsg), "%T", "Slap_Message", client);
    PrintCenterText(client, "%s", szSlapMsg);
}

void ActionRandom(int client, int blockIdx)
{
    float fTime = GetGameTime();
    if (fTime >= g_fRandomNextUse[client]) {
        int randomBlockType = g_BlockRandomType.Get(blockIdx);
        
        switch (randomBlockType) {
            case BM_INVINCIBILITY: ActionInvincible(client, true);
            case BM_STEALTH: ActionStealth(client, true);
            case BM_DEATH: ActionDeath(client);
            case BM_CAMOUFLAGE: ActionCamouflage(client, true);
            case BM_SLAP: ActionSlap(client);
            case BM_BOOTSOFSPEED: ActionBootsOfSpeed(client, true);
            case BM_AUTOBHOP: ActionAutoBhop(client, true);
        }
        
        g_fRandomNextUse[client] = fTime + g_cvRandomCooldown.FloatValue;
        
        // Set to another random type
        int randNum = GetRandomInt(0, sizeof(g_RandomBlocks) - 1);
        g_BlockRandomType.Set(blockIdx, g_RandomBlocks[randNum]);
    } else {
        PrintHintTextSilent(client, "%T", "Hint_RandomCD", client, g_fRandomNextUse[client] - fTime);
    }
}

void ActionHoney(int client)
{
    SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 50.0);
    CreateTimer(0.1, Timer_NotInHoney, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

void ActionBootsOfSpeed(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (fTime >= g_fBootsOfSpeedNextUse[client] || overrideTimer) {
        float fTimeout = g_cvBootsOfSpeedTime.FloatValue;
        
        CreateTimer(fTimeout, Timer_BootsOfSpeedRemove, GetClientUserId(client));
        EmitSoundToAll(SND_BOOTSOFSPEED, client);
        
        g_fBootsOfSpeedTimeOut[client] = fTime + fTimeout;
        g_fBootsOfSpeedNextUse[client] = fTime + fTimeout + g_cvBootsOfSpeedCooldown.FloatValue;
    } else {
        PrintHintTextSilent(client, "%T", "Hint_BootsCD", client, g_fBootsOfSpeedNextUse[client] - fTime);
    }
}

void ActionNoSlowDown(int client)
{
    g_bNoSlowDown[client] = true;
    CreateTimer(0.1, Timer_SlowDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

void ActionAutoBhop(int client, bool overrideTimer)
{
    float fTime = GetGameTime();
    if (fTime >= g_fAutoBhopNextUse[client] || overrideTimer) {
        float fTimeout = g_cvAutoBhopTime.FloatValue;
        
        CreateTimer(fTimeout, Timer_AutoBhopRemove, GetClientUserId(client));
        g_bAutoBhop[client] = true;
        EmitSoundToAll(SND_AUTOBHOP, client);
        
        g_fAutoBhopTimeOut[client] = fTime + fTimeout;
        g_fAutoBhopNextUse[client] = fTime + fTimeout + g_cvAutoBhopCooldown.FloatValue;
    } else {
        PrintHintTextSilent(client, "%T", "Hint_AutoBhopCD", client, g_fAutoBhopNextUse[client] - fTime);
    }
}

// ============== EFFECT REMOVAL TIMERS ==============
public Action Timer_InvincibleRemove(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        if (GetGameTime() >= g_fStealthTimeOut[client]) {
            SetEntityRenderFx(client, RENDERFX_NONE);
            SetEntityRenderColor(client, 255, 255, 255, 255);
            SetEntityRenderMode(client, RENDER_NORMAL);
        }
    }
    return Plugin_Stop;
}

public Action Timer_StealthRemove(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client)) {
        if (GetGameTime() >= g_fInvincibleTimeOut[client]) {
            SetEntityRenderMode(client, RENDER_NORMAL);
            SetEntityRenderColor(client, 255, 255, 255, 255);
            SetEntityRenderFx(client, RENDERFX_NONE);
        } else {
            SetEntityRenderFx(client, RENDERFX_DISTORT);
            SetEntityRenderColor(client, 255, 255, 255, 200);
        }
    }
    return Plugin_Stop;
}

public Action Timer_NotOnIce(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client) && g_bOnIce[client]) {
        g_bOnIce[client] = false;
        g_fIceVelocity[client][0] = 0.0;
        g_fIceVelocity[client][1] = 0.0;
        g_fIceVelocity[client][2] = 0.0;
    }
    return Plugin_Stop;
}

public Action Timer_CamouflageRemove(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client)) {
        if (strlen(g_szCamouflageOldModel[client]) > 0) {
            SetEntityModel(client, g_szCamouflageOldModel[client]);
        }
    }
    return Plugin_Stop;
}

public Action Timer_NotInHoney(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 250.0);
        // Boots of speed 2x handled by PreThink if still active
    }
    return Plugin_Stop;
}

public Action Timer_BootsOfSpeedRemove(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
    return Plugin_Stop;
}

public Action Timer_SlowDown(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && client <= MaxClients) {
        g_bNoSlowDown[client] = false;
    }
    return Plugin_Stop;
}

public Action Timer_AutoBhopRemove(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client > 0 && client <= MaxClients) {
        g_bAutoBhop[client] = false;
    }
    return Plugin_Stop;
}

// ============== BHOP BLOCK SOLID TIMERS ==============
public Action Timer_BhopSolidNot(Handle timer, int entRef)
{
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
        SetEntProp(ent, Prop_Data, "m_nSolidType", 0); // SOLID_NONE
        SetEntProp(ent, Prop_Send, "m_nSolidType", 0);
        SetEntityRenderMode(ent, RENDER_TRANSADD);
        SetEntityRenderColor(ent, 255, 255, 255, 25);
        g_hBhopSolidTimer[ent] = CreateTimer(1.0, Timer_BhopSolid, entRef);
    }
    return Plugin_Stop;
}

public Action Timer_BhopSolid(Handle timer, int entRef)
{
    int ent = EntRefToEntIndex(entRef);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
        SetEntProp(ent, Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
        SetEntProp(ent, Prop_Send, "m_nSolidType", 6);
        int blockIdx;
        if (IsBlockEntity(ent, blockIdx)) {
            int blockType = g_BlockTypes.Get(blockIdx);
            ApplyBlockRendering(ent, blockType);
        }
        g_hBhopSolidTimer[ent] = null;
    }
    return Plugin_Stop;
}

// ============== TELEPORT LOGIC ==============
public Action Timer_BlockEffects(Handle timer)
{
    // Teleport detection
    for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
        int startRef = g_TeleportStartEnts.Get(i);
        int startEnt = EntRefToEntIndex(startRef);
        if (startEnt == INVALID_ENT_REFERENCE || !IsValidEntity(startEnt)) continue;
        
        int endRef = g_TeleportLinks.Get(i);
        int endEnt = EntRefToEntIndex(endRef);
        if (endEnt == INVALID_ENT_REFERENCE || !IsValidEntity(endEnt)) continue;
        
        float startOrigin[3];
        GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startOrigin);
        
        for (int c = 1; c <= MaxClients; c++) {
            if (!IsClientInGame(c) || !IsPlayerAlive(c)) continue;
            
            float pOrigin[3];
            GetClientAbsOrigin(c, pOrigin);
            
            float dist = GetVectorDistance(pOrigin, startOrigin);
            if (dist < 64.0 && GetGameTime() - g_fLastTeleport[c] > 1.0) {
                g_fLastTeleport[c] = GetGameTime();
                ActionTeleport(c, endEnt);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_UpdateArrows(Handle timer)
{
    float detectRange = 200.0;
    
    for (int i = 0; i < g_BlockEntities.Length; i++) {
        if (g_BlockTypes.Get(i) != BM_SPEEDBOOST) continue;
        
        int blockEnt = EntRefToEntIndex(g_BlockEntities.Get(i));
        if (blockEnt == INVALID_ENT_REFERENCE || !IsValidEntity(blockEnt)) continue;
        
        float blockPos[3];
        GetEntPropVector(blockEnt, Prop_Send, "m_vecOrigin", blockPos);
        
        // Find nearest alive player
        int nearestClient = -1;
        float nearestDist = detectRange;
        for (int c = 1; c <= MaxClients; c++) {
            if (!IsClientInGame(c) || !IsPlayerAlive(c)) continue;
            float pPos[3];
            GetClientAbsOrigin(c, pPos);
            float dx = pPos[0] - blockPos[0];
            float dy = pPos[1] - blockPos[1];
            float dist = SquareRoot(dx * dx + dy * dy);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearestClient = c;
            }
        }
        
        if (nearestClient == -1 || nearestDist < 1.0) continue;
        
        // Calculate yaw from block center to player
        float pPos[3], dir[3], dirAng[3];
        GetClientAbsOrigin(nearestClient, pPos);
        dir[0] = pPos[0] - blockPos[0];
        dir[1] = pPos[1] - blockPos[1];
        dir[2] = 0.0;
        GetVectorAngles(dir, dirAng);
        float newYaw = dirAng[1] + 270.0;
        if (newYaw >= 360.0) newYaw -= 360.0;
        
        // Check if yaw changed enough
        float oldYaw = g_ArrowYaws.Get(i);
        float yawDiff = FloatAbs(newYaw - oldYaw);
        if (yawDiff > 180.0) yawDiff = 360.0 - yawDiff;
        if (yawDiff < 5.0) continue;
        
        // Kill old sprite
        int oldRef = g_BlockSprites.Get(i);
        if (oldRef != INVALID_ENT_REFERENCE) {
            int oldEnt = EntRefToEntIndex(oldRef);
            if (oldEnt != INVALID_ENT_REFERENCE && IsValidEntity(oldEnt)) {
                AcceptEntityInput(oldEnt, "Kill");
            }
        }
        
        // Create new sprite with updated angle
        int blockSize = g_BlockSizes.Get(i);
        float fSprScale = 1.0;
        if (blockSize == SIZE_SMALL) fSprScale = 0.25;
        else if (blockSize == SIZE_LARGE) fSprScale = 2.0;
        
        int newSprite = CreateEntityByName("env_sprite_oriented");
        if (newSprite != -1) {
            DispatchKeyValue(newSprite, "model", "sprites/blockmaker/speedboost.vmt");
            DispatchKeyValue(newSprite, "rendermode", "5");
            DispatchKeyValue(newSprite, "spawnflags", "1");
            DispatchKeyValue(newSprite, "renderamt", "255");
            char szSc[16];
            FloatToString(fSprScale, szSc, sizeof(szSc));
            DispatchKeyValue(newSprite, "scale", szSc);
            DispatchKeyValue(newSprite, "rendercolor", "255 255 255");
            DispatchSpawn(newSprite);
            
            float sprPos[3], sprAng[3];
            sprPos[0] = blockPos[0]; sprPos[1] = blockPos[1]; sprPos[2] = blockPos[2] + 4.1;
            sprAng[0] = -90.0; sprAng[1] = newYaw; sprAng[2] = 0.0;
            TeleportEntity(newSprite, sprPos, sprAng, NULL_VECTOR);
            g_BlockSprites.Set(i, EntIndexToEntRef(newSprite));
        }
        g_ArrowYaws.Set(i, newYaw);
    }
    
    return Plugin_Continue;
}

void ActionTeleport(int client, int endEnt)
{
    float endOrigin[3];
    GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", endOrigin);
    
    // Telefrags
    if (g_cvTelefrags.IntValue > 0) {
        for (int i = 1; i <= MaxClients; i++) {
            if (i != client && IsClientInGame(i) && IsPlayerAlive(i)) {
                float pOrigin[3];
                GetClientAbsOrigin(i, pOrigin);
                if (GetVectorDistance(pOrigin, endOrigin) < 48.0) {
                    ForcePlayerSuicide(i);
                }
            }
        }
    }
    
    // Preserve velocity, flip Z to upward
    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
    velocity[2] = FloatAbs(velocity[2]);
    
    // Teleport to destination
    TeleportEntity(client, endOrigin, NULL_VECTOR, velocity);
    
    if (g_cvTeleportSound.IntValue > 0) {
        EmitSoundToAll(SND_TELEPORT, client);
    }
}

// ============== TIMER (COURSE TIMER) ==============
void ActionTimerCheck(int client)
{
    float origin[3];
    GetClientAbsOrigin(client, origin);
    
    bool bNearStart = false;
    bool bNearEnd = false;
    
    for (int i = 0; i < g_TimerEntities.Length; i++) {
        int entRef = g_TimerEntities.Get(i);
        int ent = EntRefToEntIndex(entRef);
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent)) continue;
        
        float entOrigin[3];
        GetEntPropVector(ent, Prop_Data, "m_vecOrigin", entOrigin);
        
        if (GetVectorDistance(origin, entOrigin) < 100.0) {
            int timerType = g_TimerTypes.Get(i);
            if (timerType == TIMER_START) bNearStart = true;
            if (timerType == TIMER_END) bNearEnd = true;
        }
    }
    
    if (bNearStart && bNearEnd) {
        if (g_bHasTimer[client])
            TimerStop(client);
        else
            TimerStart(client);
    } else if (bNearStart) {
        TimerStart(client);
    } else if (bNearEnd) {
        TimerStop(client);
    }
}

void TimerStart(int client)
{
    if (IsPlayerAlive(client)) {
        g_fTimerTime[client] = GetGameTime();
        if (g_bHasTimer[client]) {
            PrintToChat(client, "%s%T", PREFIX, "Timer_Restarted", client);
        } else {
            g_bHasTimer[client] = true;
            PrintToChat(client, "%s%T", PREFIX, "Timer_Started", client);
        }
    }
}

void TimerStop(int client)
{
    if (!g_bHasTimer[client]) return;
    g_bHasTimer[client] = false;
    
    char szName[64];
    GetClientName(client, szName, sizeof(szName));
    
    float fTime = GetGameTime() - g_fTimerTime[client];
    int mins = RoundToFloor(fTime / 60.0);
    float fSecs = fTime - (mins * 60.0);
    
    char szTime[32];
    Format(szTime, sizeof(szTime), "%s%d:%s%.3f",
        (mins < 10 ? "0" : ""), mins,
        (fSecs < 10.0 ? "0" : ""), fSecs);
    
    PrintToChatAll("%s%T", PREFIX, "Timer_Completed", LANG_SERVER, szName, szTime);
    
    TimerCheckScoreboard(client, fTime);
}

void TimerCheckScoreboard(int client, float fTime)
{
    char szName[64], szSteamId[64];
    GetClientName(client, szName, sizeof(szName));
    GetClientAuthId(client, AuthId_Steam2, szSteamId, sizeof(szSteamId));
    
    for (int i = 0; i < MAX_SCORE_ENTRIES; i++) {
        if (fTime < g_fScoreTimes[i]) {
            int pos = i;
            while (!StrEqual(g_szScoreSteamIds[pos], szSteamId) && pos < MAX_SCORE_ENTRIES - 1) {
                pos++;
            }
            
            for (int j = pos; j > i; j--) {
                strcopy(g_szScoreSteamIds[j], sizeof(g_szScoreSteamIds[]), g_szScoreSteamIds[j-1]);
                strcopy(g_szScoreNames[j], sizeof(g_szScoreNames[]), g_szScoreNames[j-1]);
                g_fScoreTimes[j] = g_fScoreTimes[j-1];
            }
            
            strcopy(g_szScoreSteamIds[i], sizeof(g_szScoreSteamIds[]), szSteamId);
            strcopy(g_szScoreNames[i], sizeof(g_szScoreNames[]), szName);
            g_fScoreTimes[i] = fTime;
            
            if (i == 0)
                PrintToChatAll("%s%T", PREFIX, "Timer_Fastest", LANG_SERVER, szName);
            else
                PrintToChatAll("%s%T", PREFIX, "Timer_Rank", LANG_SERVER, szName, i + 1);
            
            break;
        }
        
        if (StrEqual(g_szScoreSteamIds[i], szSteamId)) break;
    }
}

// ============== BLOCK ENTITY OPERATIONS ==============
int CreateBlockEntityInternal(int client, int blockType, float origin[3], int axis, int size, bool bTrack, int &outSpriteRef)
{
    outSpriteRef = INVALID_ENT_REFERENCE;

    int ent = CreateEntityByName("prop_dynamic_override");
    if (ent == -1) return -1;
    
    // Determine model
    char szModel[256];
    float fScale;
    
    switch (size) {
        case SIZE_SMALL: {
            GetBlockModelSmall(szModel, sizeof(szModel), g_szBlockModels[blockType]);
            fScale = SCALE_SMALL;
        }
        case SIZE_LARGE: {
            GetBlockModelLarge(szModel, sizeof(szModel), g_szBlockModels[blockType]);
            fScale = SCALE_LARGE;
        }
        default: {
            strcopy(szModel, sizeof(szModel), g_szBlockModels[blockType]);
            fScale = SCALE_NORMAL;
        }
    }
    
    // Check if model exists, fallback to normal
    if (!FileExists(szModel, true)) {
        strcopy(szModel, sizeof(szModel), g_szBlockModels[blockType]);
        if (!FileExists(szModel, true)) {
            strcopy(szModel, sizeof(szModel), g_szDefaultBlockModels[BM_PLATFORM]);
        }
        fScale = SCALE_NORMAL;
    }
    
    DispatchKeyValue(ent, "model", szModel);
    DispatchKeyValue(ent, "solid", "6"); // SOLID_VPHYSICS
    DispatchSpawn(ent);
    ActivateEntity(ent);
    
    // Set angles based on axis
    float angles[3];
    switch (axis) {
        case AXIS_X: { angles[0] = 90.0; angles[1] = 0.0; angles[2] = 0.0; }
        case AXIS_Y: { angles[0] = 90.0; angles[1] = 0.0; angles[2] = 90.0; }
        case AXIS_Z: { angles[0] = 0.0; angles[1] = 0.0; angles[2] = 0.0; }
    }
    
    // Set mins/maxs based on axis and scale
    // SOLID_VPHYSICS uses the model's collision mesh, which rotates with the entity
    float mins[3], maxs[3];
    switch (axis) {
        case AXIS_X: {
            mins[0] = BLOCK_MINS_X[0]; mins[1] = BLOCK_MINS_X[1]; mins[2] = BLOCK_MINS_X[2];
            maxs[0] = BLOCK_MAXS_X[0]; maxs[1] = BLOCK_MAXS_X[1]; maxs[2] = BLOCK_MAXS_X[2];
        }
        case AXIS_Y: {
            mins[0] = BLOCK_MINS_Y[0]; mins[1] = BLOCK_MINS_Y[1]; mins[2] = BLOCK_MINS_Y[2];
            maxs[0] = BLOCK_MAXS_Y[0]; maxs[1] = BLOCK_MAXS_Y[1]; maxs[2] = BLOCK_MAXS_Y[2];
        }
        default: {
            mins[0] = BLOCK_MINS_Z[0]; mins[1] = BLOCK_MINS_Z[1]; mins[2] = BLOCK_MINS_Z[2];
            maxs[0] = BLOCK_MAXS_Z[0]; maxs[1] = BLOCK_MAXS_Z[1]; maxs[2] = BLOCK_MAXS_Z[2];
        }
    }
    
    // Apply scale to non-thin dimensions
    for (int i = 0; i < 3; i++) {
        if (mins[i] != 4.0 && mins[i] != -4.0) mins[i] *= fScale;
        if (maxs[i] != 4.0 && maxs[i] != -4.0) maxs[i] *= fScale;
    }
    
    // Apply properties (VPhysics solid)
    SetEntProp(ent, Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
    SetEntProp(ent, Prop_Send, "m_nSolidType", 6);

    TeleportEntity(ent, origin, angles, NULL_VECTOR);
    
    // Snapping
    if (client > 0 && client <= MaxClients) {
        DoSnapping(client, ent, origin, mins, maxs);
        TeleportEntity(ent, origin, angles, NULL_VECTOR);
    }
    
    // Setup rendering
    ApplyBlockRendering(ent, blockType);
    
    // Setup random block type
    int randomType = BM_DEATH;
    if (blockType == BM_RANDOM) {
        int randNum = GetRandomInt(0, sizeof(g_RandomBlocks) - 1);
        randomType = g_RandomBlocks[randNum];
    }
    
    // Track entity
    int entRef = EntIndexToEntRef(ent);
    if (bTrack) {
        g_BlockEntities.Push(entRef);
        g_BlockTypes.Push(blockType);
        g_BlockSprites.Push(INVALID_ENT_REFERENCE);
        g_ArrowYaws.Push(0.0);
        g_BlockRandomType.Push(randomType);
        g_BlockSizes.Push(size);
        g_BlockAxes.Push(axis);
        g_BlockOrigins.PushArray(origin, 3);
    }
    
    // Hook touch for bhop blocks
    if (blockType == BM_BHOP || blockType == BM_BHOP_NOSLOW || blockType == BM_BARRIER_CT || blockType == BM_BARRIER_T) {
        SDKHook(ent, SDKHook_Touch, OnBlockTouch);
    }
    
    // Set classname for identification
    DispatchKeyValue(ent, "targetname", BLOCK_CLASSNAME);
    
    // Create visual sprite effects for certain block types
    int spriteRef = CreateBlockSprite(ent, blockType, size);
    if (spriteRef != INVALID_ENT_REFERENCE) {
        if (bTrack) {
            int idx = g_BlockEntities.FindValue(entRef);
            if (idx != -1) {
                g_BlockSprites.Set(idx, spriteRef);
            }
        } else {
            outSpriteRef = spriteRef;
        }
    }

    return ent;
}

int CreateBlockEntity(int client, int blockType, float origin[3], int axis, int size)
{
    int spriteRef;
    return CreateBlockEntityInternal(client, blockType, origin, axis, size, true, spriteRef);
}

public void OnBlockTouch(int ent, int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
    
    int blockIdx;
    if (!IsBlockEntity(ent, blockIdx)) return;
    
    int blockType = g_BlockTypes.Get(blockIdx);
    
    if (blockType == BM_BHOP || blockType == BM_BARRIER_CT || blockType == BM_BARRIER_T || blockType == BM_BHOP_NOSLOW) {
        if (g_hBhopSolidTimer[ent] != null) return;
        
        int team = GetClientTeam(client);
        
        if (blockType == BM_BARRIER_CT && team == CS_TEAM_T) {
            // Make not solid immediately for T
            Timer_BhopSolidNot(null, EntIndexToEntRef(ent));
        } else if (blockType == BM_BARRIER_T && team == CS_TEAM_CT) {
            // Make not solid immediately for CT
            Timer_BhopSolidNot(null, EntIndexToEntRef(ent));
        } else if (blockType == BM_BHOP || blockType == BM_BHOP_NOSLOW) {
            CreateTimer(0.1, Timer_BhopSolidNot, EntIndexToEntRef(ent));
        }
    }
}

int CreateBlockSprite(int parentEnt, int blockType, int size = SIZE_NORMAL)
{
    // Determine sprite model and color based on block type
    char szSprite[128];
    int r, g, b, a;
    float fScale = 0.25;
    bool bCreate = false;
    bool bOriented = false; // Use env_sprite_oriented instead of env_sprite
    
    switch (blockType) {
        case BM_FIRE: {
            szSprite = "sprites/blockmaker/fire.vmt";
            r = 255; g = 255; b = 255; a = 255;
            switch (size) {
                case SIZE_SMALL: fScale = 0.25;
                case SIZE_LARGE: fScale = 2.0;
                default:         fScale = 1.0;
            }
            bCreate = true;
            bOriented = true;
        }
        case BM_TRAMPOLINE: {
            szSprite = "sprites/blockmaker/trampoline.vmt";
            r = 255; g = 255; b = 255; a = 255;
            // Scale sprite to match block size
            switch (size) {
                case SIZE_SMALL: fScale = 0.25;
                case SIZE_LARGE: fScale = 2.0;
                default:         fScale = 1.0;
            }
            bCreate = true;
            bOriented = true;
        }
        case BM_SPEEDBOOST: {
            szSprite = "sprites/blockmaker/speedboost.vmt";
            r = 255; g = 255; b = 255; a = 255;
            switch (size) {
                case SIZE_SMALL: fScale = 0.25;
                case SIZE_LARGE: fScale = 2.0;
                default:         fScale = 1.0;
            }
            bCreate = true;
            bOriented = true;
        }
    }
    
    if (!bCreate) return INVALID_ENT_REFERENCE;
    
    int sprite;
    if (bOriented) {
        sprite = CreateEntityByName("env_sprite_oriented");
    } else {
        if (!FileExists(szSprite, true)) return INVALID_ENT_REFERENCE;
        sprite = CreateEntityByName("env_sprite");
    }
    if (sprite == -1) return INVALID_ENT_REFERENCE;
    
    DispatchKeyValue(sprite, "model", szSprite);
    // Trampoline: rendermode 2 (TransTexture), Speedboost/Fire: rendermode 5 (Additive)
    if (bOriented && (blockType == BM_SPEEDBOOST || blockType == BM_FIRE)) {
        DispatchKeyValue(sprite, "rendermode", "5");
    } else {
        DispatchKeyValue(sprite, "rendermode", bOriented ? "2" : "5");
    }
    DispatchKeyValue(sprite, "spawnflags", "1");
    
    char szRenderAmt[8];
    IntToString(a, szRenderAmt, sizeof(szRenderAmt));
    DispatchKeyValue(sprite, "renderamt", szRenderAmt);
    
    char szScale[16];
    FloatToString(fScale, szScale, sizeof(szScale));
    DispatchKeyValue(sprite, "scale", szScale);
    
    char szColor[32];
    Format(szColor, sizeof(szColor), "%d %d %d", r, g, b);
    DispatchKeyValue(sprite, "rendercolor", szColor);
    DispatchKeyValue(sprite, "framerate", "10");
    
    DispatchSpawn(sprite);
    
    // Get block's ACTUAL world position
    float entPos[3];
    GetEntPropVector(parentEnt, Prop_Send, "m_vecOrigin", entPos);
    
    // Position and orient the sprite
    float spritePos[3], spriteAng[3];
    spritePos[0] = entPos[0];
    spritePos[1] = entPos[1];
    spritePos[2] = entPos[2];
    spriteAng[0] = 0.0; spriteAng[1] = 0.0; spriteAng[2] = 0.0;
    
    if (bOriented) {
        spritePos[2] += 4.1;
        spriteAng[0] = -90.0;
    } else {
        spritePos[2] += 8.0;
    }
    
    TeleportEntity(sprite, spritePos, spriteAng, NULL_VECTOR);
    
    // Parent after positioning (skip speedboost - position/angle updated every frame)
    if (blockType != BM_SPEEDBOOST) {
        SetVariantString("!activator");
        AcceptEntityInput(sprite, "SetParent", parentEnt, sprite, 0);
    }
    
    return EntIndexToEntRef(sprite);
}

bool DeleteBlockEntity(int ent)
{
    int blockIdx;
    if (!IsBlockEntity(ent, blockIdx)) return false;
    
    // Remove sprite if any
    int spriteRef = g_BlockSprites.Get(blockIdx);
    if (spriteRef != INVALID_ENT_REFERENCE) {
        int sprite = EntRefToEntIndex(spriteRef);
        if (sprite != INVALID_ENT_REFERENCE && IsValidEntity(sprite)) {
            AcceptEntityInput(sprite, "Kill");
        }
    }
    
    // Remove from tracking arrays
    g_BlockEntities.Erase(blockIdx);
    g_BlockTypes.Erase(blockIdx);
    g_BlockSprites.Erase(blockIdx);
    g_ArrowYaws.Erase(blockIdx);
    g_BlockRandomType.Erase(blockIdx);
    g_BlockSizes.Erase(blockIdx);
    g_BlockAxes.Erase(blockIdx);
    g_BlockOrigins.Erase(blockIdx);
    
    // Remove bhop timer
    if (ent < 2049) g_hBhopSolidTimer[ent] = null;
    
    // Delete entity
    AcceptEntityInput(ent, "Kill");
    return true;
}

// ============== TELEPORT CREATION ==============
int CreateTeleportEntity(int client, int teleType, float origin[3])
{
    // Create invisible prop_dynamic for tracking (supports trace/aim/Kill)
    int ent = CreateEntityByName("prop_dynamic_override");
    if (ent == -1) return -1;
    
    DispatchKeyValue(ent, "model", g_szDefaultBlockModels[BM_PLATFORM]);
    DispatchKeyValue(ent, "disableshadows", "1");
    
    if (teleType == TELEPORT_START)
        DispatchKeyValue(ent, "targetname", TELEPORT_START_CLASSNAME);
    else
        DispatchKeyValue(ent, "targetname", TELEPORT_END_CLASSNAME);
    
    DispatchSpawn(ent);
    ActivateEntity(ent);
    
    // Make prop invisible but traceable (SOLID_BBOX for trace, COLLISION_GROUP_DEBRIS = no player collision)
    SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
    SetEntityRenderColor(ent, 0, 0, 0, 0);
    SetEntProp(ent, Prop_Data, "m_nSolidType", 2); // SOLID_BBOX
    SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1); // COLLISION_GROUP_DEBRIS
    
    // Bbox for trace hits
    float mins[3] = {-16.0, -16.0, -16.0};
    float maxs[3] = {16.0, 16.0, 16.0};
    SetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
    SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);
    SetEntPropVector(ent, Prop_Send, "m_vecMins", mins);
    SetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxs);
    
    TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
    
    // Create visible sprite parented to the prop
    int sprite = CreateEntityByName("env_sprite");
    if (sprite != -1) {
        if (teleType == TELEPORT_START)
            DispatchKeyValue(sprite, "model", MAT_TELEPORT_START);
        else
            DispatchKeyValue(sprite, "model", MAT_TELEPORT_END);
        
        DispatchKeyValue(sprite, "rendermode", "5");
        DispatchKeyValue(sprite, "renderamt", "200");
        DispatchKeyValue(sprite, "rendercolor", "255 255 255");
        DispatchKeyValue(sprite, "scale", "1.0");
        DispatchKeyValue(sprite, "framerate", "15.0");
        DispatchKeyValue(sprite, "spawnflags", "1");
        DispatchKeyValue(sprite, "targetname", SPRITE_CLASSNAME);
        DispatchSpawn(sprite);
        TeleportEntity(sprite, origin, NULL_VECTOR, NULL_VECTOR);
        
        SetVariantString("!activator");
        AcceptEntityInput(sprite, "SetParent", ent, sprite, 0);
    }
    
    if (teleType == TELEPORT_START) {
        // If player already had a start, remove it
        if (client > 0 && g_TeleportStart[client] != INVALID_ENT_REFERENCE) {
            int oldEnt = EntRefToEntIndex(g_TeleportStart[client]);
            if (oldEnt != INVALID_ENT_REFERENCE && IsValidEntity(oldEnt)) {
                AcceptEntityInput(oldEnt, "Kill");
            }
        }
        g_TeleportStart[client] = EntIndexToEntRef(ent);
    } else {
        // Link with start
        if (g_TeleportStart[client] != INVALID_ENT_REFERENCE) {
            int startEnt = EntRefToEntIndex(g_TeleportStart[client]);
            if (startEnt != INVALID_ENT_REFERENCE && IsValidEntity(startEnt)) {
                // Track the pair
                g_TeleportStartEnts.Push(g_TeleportStart[client]);
                g_TeleportEndEnts.Push(EntIndexToEntRef(ent));
                g_TeleportLinks.Push(EntIndexToEntRef(ent));
                
                // Store positions for recreate on restart
                float startPos[3];
                GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startPos);
                g_TeleportStartPos.PushArray(startPos, 3);
                g_TeleportEndPos.PushArray(origin, 3);
                
                g_TeleportStart[client] = INVALID_ENT_REFERENCE;
                
                // Set cooldown so admin doesn't get teleported immediately
                if (client > 0)
                    g_fLastTeleport[client] = GetGameTime();
            }
        } else {
            AcceptEntityInput(ent, "Kill");
            return -1;
        }
    }
    
    return ent;
}

// ============== TIMER CREATION ==============
int CreateTimerEntity(int client, int timerType, float origin[3], float angles[3] = {0.0, 0.0, 0.0})
{
    char szModel[256];
    if (timerType == TIMER_START)
        strcopy(szModel, sizeof(szModel), TIMER_MODEL_START);
    else
        strcopy(szModel, sizeof(szModel), TIMER_MODEL_END);
    
    if (!FileExists(szModel, true))
        strcopy(szModel, sizeof(szModel), g_szDefaultBlockModels[BM_PLATFORM]);
    
    int ent = CreateEntityByName("prop_dynamic_override");
    if (ent == -1) return -1;
    
    DispatchKeyValue(ent, "model", szModel);
    DispatchKeyValue(ent, "targetname", TIMER_CLASSNAME);
    DispatchSpawn(ent);
    ActivateEntity(ent);
    
    SetEntProp(ent, Prop_Data, "m_nSolidType", 2);
    float mins[3], maxs[3];
    mins[0] = TIMER_MINS[0]; mins[1] = TIMER_MINS[1]; mins[2] = TIMER_MINS[2];
    maxs[0] = TIMER_MAXS[0]; maxs[1] = TIMER_MAXS[1]; maxs[2] = TIMER_MAXS[2];
    SetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
    SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);
    
    TeleportEntity(ent, origin, angles, NULL_VECTOR);
    
    int entRef = EntIndexToEntRef(ent);
    
    if (timerType == TIMER_START) {
        if (client > 0 && g_StartTimer[client] != INVALID_ENT_REFERENCE) {
            int old = EntRefToEntIndex(g_StartTimer[client]);
            if (old != INVALID_ENT_REFERENCE && IsValidEntity(old)) {
                AcceptEntityInput(old, "Kill");
                // Remove from tracking
                int idx = g_TimerEntities.FindValue(g_StartTimer[client]);
                if (idx != -1) {
                    g_TimerEntities.Erase(idx);
                    g_TimerTypes.Erase(idx);
                    g_TimerLinks.Erase(idx);
                    g_TimerOrigins.Erase(idx);
                    g_TimerAngles.Erase(idx);
                }
            }
        }
        g_TimerEntities.Push(entRef);
        g_TimerTypes.Push(TIMER_START);
        g_TimerLinks.Push(INVALID_ENT_REFERENCE);
        g_TimerOrigins.PushArray(origin, 3);
        g_TimerAngles.PushArray(angles, 3);
        if (client > 0) g_StartTimer[client] = entRef;
    } else {
        if (client > 0 && g_StartTimer[client] != INVALID_ENT_REFERENCE) {
            g_TimerEntities.Push(entRef);
            g_TimerTypes.Push(TIMER_END);
            g_TimerLinks.Push(g_StartTimer[client]);
            g_TimerOrigins.PushArray(origin, 3);
            g_TimerAngles.PushArray(angles, 3);
            
            // Link start to end
            int startIdx = g_TimerEntities.FindValue(g_StartTimer[client]);
            if (startIdx != -1) {
                g_TimerLinks.Set(startIdx, entRef);
            }
            
            if (client > 0) g_StartTimer[client] = INVALID_ENT_REFERENCE;
        } else {
            AcceptEntityInput(ent, "Kill");
            return -1;
        }
    }
    
    return ent;
}

// ============== GRAB SYSTEM ==============
public Action Cmd_Grab(int client, int args)
{
    if (!IsAdmin(client)) return Plugin_Handled;
    
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    
    if (!TR_DidHit()) return Plugin_Handled;
    
    int ent = TR_GetEntityIndex();
    if (ent < 1 || !IsValidEntity(ent)) return Plugin_Handled;
    
    float hitPos[3];
    TR_GetEndPosition(hitPos);
    g_fGrabLength[client] = GetVectorDistance(eyePos, hitPos);
    
    int blockIdx;
    bool isBlock = IsBlockEntity(ent, blockIdx);
    bool isTele = IsTeleportEntity(ent);
    bool isTimerEnt = IsTimerEntity(ent);
    
    if (!isBlock && !isTele && !isTimerEnt) return Plugin_Handled;
    
    // Calculate grab offset
    float entOrigin[3];
    GetEntPropVector(ent, Prop_Data, "m_vecOrigin", entOrigin);
    
    g_fGrabOffset[client][0] = entOrigin[0] - hitPos[0];
    g_fGrabOffset[client][1] = entOrigin[1] - hitPos[1];
    g_fGrabOffset[client][2] = entOrigin[2] - hitPos[2];
    
    g_Grabbed[client] = EntIndexToEntRef(ent);
    
    return Plugin_Handled;
}

public Action Cmd_Release(int client, int args)
{
    if (g_Grabbed[client] != INVALID_ENT_REFERENCE) {
        g_Grabbed[client] = INVALID_ENT_REFERENCE;
    }
    return Plugin_Handled;
}

void MoveGrabbedEntity(int client, int ent)
{
    float eyePos[3], eyeAng[3], fwd[3], moveTo[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);
    
    moveTo[0] = eyePos[0] + fwd[0] * g_fGrabLength[client] + g_fGrabOffset[client][0];
    moveTo[1] = eyePos[1] + fwd[1] * g_fGrabLength[client] + g_fGrabOffset[client][1];
    moveTo[2] = eyePos[2] + fwd[2] * g_fGrabLength[client] + g_fGrabOffset[client][2];
    
    // Snapping for blocks
    int blockIdx;
    if (IsBlockEntity(ent, blockIdx)) {
        float mins[3], maxs[3];
        GetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
        GetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);
        DoSnapping(client, ent, moveTo, mins, maxs);
    }
    
    TeleportEntity(ent, moveTo, NULL_VECTOR, NULL_VECTOR);
    
    // Update stored teleport positions for round restart
    if (IsTeleportEntity(ent)) {
        int entRef = EntIndexToEntRef(ent);
        for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
            if (g_TeleportStartEnts.Get(i) == entRef) {
                g_TeleportStartPos.SetArray(i, moveTo, 3);
                break;
            }
            if (g_TeleportEndEnts.Get(i) == entRef) {
                g_TeleportEndPos.SetArray(i, moveTo, 3);
                break;
            }
        }
    }
    
    // Sync unparented speedboost sprite position
    int blockIdx2;
    if (IsBlockEntity(ent, blockIdx2)) {
        g_BlockOrigins.SetArray(blockIdx2, moveTo, 3);
        if (g_BlockTypes.Get(blockIdx2) == BM_SPEEDBOOST) {
            int spriteRef = g_BlockSprites.Get(blockIdx2);
            if (spriteRef != INVALID_ENT_REFERENCE) {
                int arrowEnt = EntRefToEntIndex(spriteRef);
                if (arrowEnt != INVALID_ENT_REFERENCE && IsValidEntity(arrowEnt)) {
                    float sprPos[3];
                    sprPos[0] = moveTo[0]; sprPos[1] = moveTo[1]; sprPos[2] = moveTo[2] + 4.1;
                    TeleportEntity(arrowEnt, sprPos, NULL_VECTOR, NULL_VECTOR);
                }
            }
        }
    }
    
    // Handle jump (push further) and duck (pull closer) while grabbing
    int buttons = GetClientButtons(client);
    if (buttons & IN_JUMP) {
        g_fGrabLength[client] += 2.0;
    }
    if (buttons & IN_DUCK && g_fGrabLength[client] > 72.0) {
        g_fGrabLength[client] -= 2.0;
    }
    
    // Attack2 = delete while grabbing
    if (buttons & IN_ATTACK2) {
        int bIdx;
        if (IsBlockEntity(ent, bIdx)) {
            DeleteBlockEntity(ent);
            g_Grabbed[client] = INVALID_ENT_REFERENCE;
        }
    }
}

// ============== SNAPPING ==============
void DoSnapping(int client, int ent, float moveTo[3], float mins[3], float maxs[3])
{
    if (!g_bSnapping[client]) return;
    
    float snapDist = SNAP_DISTANCE + g_fSnappingGap[client];
    float bestDist = 9999.9;
    int bestBlock = -1;
    int bestFace = -1;
    
    for (int face = 0; face < 6; face++) {
        float start[3], end[3];
        start[0] = moveTo[0]; start[1] = moveTo[1]; start[2] = moveTo[2];
        end[0] = moveTo[0]; end[1] = moveTo[1]; end[2] = moveTo[2];
        
        switch (face) {
            case 0: { start[0] += mins[0]; end[0] = start[0] - snapDist; }
            case 1: { start[0] += maxs[0]; end[0] = start[0] + snapDist; }
            case 2: { start[1] += mins[1]; end[1] = start[1] - snapDist; }
            case 3: { start[1] += maxs[1]; end[1] = start[1] + snapDist; }
            case 4: { start[2] += mins[2]; end[2] = start[2] - snapDist; }
            case 5: { start[2] += maxs[2]; end[2] = start[2] + snapDist; }
        }
        
        TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_SnapBlock, ent);
        if (TR_DidHit()) {
            int hit = TR_GetEntityIndex();
            int blockIdx;
            if (hit > 0 && IsBlockEntity(hit, blockIdx)) {
                float hitPos[3];
                TR_GetEndPosition(hitPos);
                float dist = GetVectorDistance(start, hitPos);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestBlock = hit;
                    bestFace = face;
                }
            }
        }
    }
    
    if (bestBlock > 0 && IsValidEntity(bestBlock)) {
        float bOrigin[3], bMins[3], bMaxs[3];
        GetEntPropVector(bestBlock, Prop_Data, "m_vecOrigin", bOrigin);
        GetEntPropVector(bestBlock, Prop_Data, "m_vecMins", bMins);
        GetEntPropVector(bestBlock, Prop_Data, "m_vecMaxs", bMaxs);
        
        moveTo[0] = bOrigin[0]; moveTo[1] = bOrigin[1]; moveTo[2] = bOrigin[2];
        
        float gap = g_fSnappingGap[client];
        switch (bestFace) {
            case 0: moveTo[0] += (bMaxs[0] + maxs[0]) + gap;
            case 1: moveTo[0] += (bMins[0] + mins[0]) - gap;
            case 2: moveTo[1] += (bMaxs[1] + maxs[1]) + gap;
            case 3: moveTo[1] += (bMins[1] + mins[1]) - gap;
            case 4: moveTo[2] += (bMaxs[2] + maxs[2]) + gap;
            case 5: moveTo[2] += (bMins[2] + mins[2]) - gap;
        }
    }
}

// ============== TRACE FILTERS ==============
public bool TraceFilter_NoPlayers(int entity, int contentsMask, int client)
{
    return entity != client && (entity < 1 || entity > MaxClients);
}

public bool TraceFilter_SnapBlock(int entity, int contentsMask, int excludeEnt)
{
    return entity != excludeEnt && entity > MaxClients;
}

// ============== RENDERING ==============
void SetupBlockRendering(int blockType, int renderType, int red, int green, int blue, int alpha)
{
    g_Render[blockType] = renderType;
    g_Red[blockType] = red;
    g_Green[blockType] = green;
    g_Blue[blockType] = blue;
    g_Alpha[blockType] = alpha;
}

void ApplyBlockRendering(int ent, int blockType)
{
    switch (g_Render[blockType]) {
        case BM_RENDER_GLOWSHELL: {
            SetEntityRenderFx(ent, RENDERFX_DISTORT);
            SetEntityRenderColor(ent, g_Red[blockType], g_Green[blockType], g_Blue[blockType], g_Alpha[blockType]);
        }
        case BM_RENDER_TRANSCOLOR: {
            SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
            SetEntityRenderColor(ent, g_Red[blockType], g_Green[blockType], g_Blue[blockType], g_Alpha[blockType]);
        }
        case BM_RENDER_TRANSALPHA: {
            SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
            SetEntityRenderColor(ent, g_Red[blockType], g_Green[blockType], g_Blue[blockType], g_Alpha[blockType]);
        }
        case BM_RENDER_TRANSWHITE: {
            SetEntityRenderMode(ent, RENDER_TRANSADD);
            SetEntityRenderColor(ent, g_Red[blockType], g_Green[blockType], g_Blue[blockType], g_Alpha[blockType]);
        }
        default: {
            SetEntityRenderMode(ent, RENDER_NORMAL);
            SetEntityRenderColor(ent, 255, 255, 255, 255);
            SetEntityRenderFx(ent, RENDERFX_NONE);
        }
    }
}

// ============== ENTITY IDENTIFICATION ==============
bool IsBlockEntity(int ent, int &blockIdx)
{
    if (!IsValidEntity(ent)) return false;
    int entRef = EntIndexToEntRef(ent);
    blockIdx = g_BlockEntities.FindValue(entRef);
    return (blockIdx != -1);
}

bool IsTeleportEntity(int ent)
{
    if (!IsValidEntity(ent)) return false;
    char szName[64];
    GetEntPropString(ent, Prop_Data, "m_iName", szName, sizeof(szName));
    return (StrEqual(szName, TELEPORT_START_CLASSNAME) || StrEqual(szName, TELEPORT_END_CLASSNAME));
}

bool IsTimerEntity(int ent)
{
    if (!IsValidEntity(ent)) return false;
    char szName[64];
    GetEntPropString(ent, Prop_Data, "m_iName", szName, sizeof(szName));
    return StrEqual(szName, TIMER_CLASSNAME);
}

// ============== HELPER FUNCTIONS ==============

void PrintHintTextSilent(int client, const char[] format, any ...)
{
    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 3);
    PrintHintText(client, buffer);
    StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
}

int GetClientAimEntity(int client, float maxDist)
{
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    
    if (!TR_DidHit()) return -1;
    
    float hitPos[3];
    TR_GetEndPosition(hitPos);
    if (GetVectorDistance(eyePos, hitPos) > maxDist) return -1;
    
    return TR_GetEntityIndex();
}

bool IsAdmin(int client)
{
    return (GetUserFlagBits(client) & BM_ADMIN_FLAG) != 0 || (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0;
}

void GetBlockModelSmall(char[] buffer, int maxlen, const char[] model)
{
    strcopy(buffer, maxlen, model);
    ReplaceString(buffer, maxlen, ".mdl", "_small.mdl");
}

void GetBlockModelLarge(char[] buffer, int maxlen, const char[] model)
{
    strcopy(buffer, maxlen, model);
    ReplaceString(buffer, maxlen, ".mdl", "_large.mdl");
}

void AddModelToDownloadsTable(const char[] model)
{
    if (!FileExists(model, true)) return;
    
    AddFileToDownloadsTable(model);
    
    // Add associated model files (.dx80.vtx, .dx90.vtx, .sw.vtx, .vvd, .phy)
    static const char g_szModelExts[][] = {
        ".dx80.vtx",
        ".dx90.vtx",
        ".sw.vtx",
        ".vvd",
        ".phy"
    };
    
    char szBase[256], szFile[256];
    strcopy(szBase, sizeof(szBase), model);
    ReplaceString(szBase, sizeof(szBase), ".mdl", "");
    
    for (int i = 0; i < sizeof(g_szModelExts); i++) {
        Format(szFile, sizeof(szFile), "%s%s", szBase, g_szModelExts[i]);
        if (FileExists(szFile, true))
            AddFileToDownloadsTable(szFile);
    }
}

// ============== MENUS ==============
public Action Cmd_Say(int client, int args)
{
    char szText[32];
    GetCmdArgString(szText, sizeof(szText));
    StripQuotes(szText);
    TrimString(szText);
    
    if (StrEqual(szText, "/bm", false)) {
        ShowMainMenu(client);
        return Plugin_Handled;
    }
    if (StrEqual(szText, "/bm15", false)) {
        ShowTimerScoreboard(client);
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action Cmd_ShowMainMenu(int client, int args)
{
    ShowMainMenu(client);
    return Plugin_Handled;
}

void ShowMainMenu(int client)
{
    char szItem[128];
    Menu menu = new Menu(Handle_MainMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Main", client);
    menu.SetTitle(szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_BlockMenu", client); menu.AddItem("block", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TeleportMenu", client); menu.AddItem("tele", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TimerMenu", client); menu.AddItem("timer", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_MeasureTool", client); menu.AddItem("measure", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_LongJump", client); menu.AddItem("longjump", szItem);
    Format(szItem, sizeof(szItem), "%T", g_bAdminNoclip[client] ? "Item_NoclipOn" : "Item_NoclipOff", client); menu.AddItem("noclip", szItem);
    Format(szItem, sizeof(szItem), "%T", g_bAdminGodmode[client] ? "Item_GodmodeOn" : "Item_GodmodeOff", client); menu.AddItem("godmode", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_Options", client); menu.AddItem("options", szItem);
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_MainMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "block")) ShowBlockMenu(client);
    else if (StrEqual(szInfo, "tele")) ShowTeleportMenu(client);
    else if (StrEqual(szInfo, "timer")) ShowTimerMenu(client);
    else if (StrEqual(szInfo, "measure")) ShowMeasureMenu(client);
    else if (StrEqual(szInfo, "longjump")) ShowLongJumpMenu(client);
    else if (StrEqual(szInfo, "noclip")) { ToggleNoclip(client); ShowMainMenu(client); }
    else if (StrEqual(szInfo, "godmode")) { ToggleGodmode(client); ShowMainMenu(client); }
    else if (StrEqual(szInfo, "options")) { ShowOptionsMenu(client); }
    
    return 0;
}

void ShowBlockMenu(int client)
{
    char szItem[128], szBlockName[64], szSizeName[32];
    Menu menu = new Menu(Handle_BlockMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Block", client);
    menu.SetTitle(szItem);
    
    Format(szBlockName, sizeof(szBlockName), "%T", g_szBlockTransKeys[g_SelectedBlockType[client]], client);
    Format(szItem, sizeof(szItem), "%T", "Item_BlockType", client, szBlockName);
    menu.AddItem("type", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_CreateBlock", client); menu.AddItem("create", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_ConvertBlock", client); menu.AddItem("convert", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteBlock", client); menu.AddItem("delete", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_RotateBlock", client); menu.AddItem("rotate", szItem);
    
    switch (g_BlockSize[client]) {
        case SIZE_SMALL: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Small", client);
        case SIZE_NORMAL: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Normal", client);
        case SIZE_LARGE: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Large", client);
    }
    Format(szItem, sizeof(szItem), "%T", "Item_BlockSize", client, szSizeName);
    menu.AddItem("size", szItem);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_BlockMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) { ShowMainMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "type")) ShowBlockSelectionMenu(client);
    else if (StrEqual(szInfo, "create")) { CreateBlockAiming(client); ShowBlockMenu(client); }
    else if (StrEqual(szInfo, "convert")) { ConvertBlockAiming(client); ShowBlockMenu(client); }
    else if (StrEqual(szInfo, "delete")) { DeleteBlockAiming(client); ShowBlockMenu(client); }
    else if (StrEqual(szInfo, "rotate")) { RotateBlockAiming(client); ShowBlockMenu(client); }
    else if (StrEqual(szInfo, "size")) { ChangeBlockSize(client); ShowBlockMenu(client); }
    
    return 0;
}

void ShowBlockSelectionMenu(int client)
{
    char szTitle[128];
    Menu menu = new Menu(Handle_BlockSelection);
    Format(szTitle, sizeof(szTitle), "%T\n ", "Menu_BlockSelection", client);
    menu.SetTitle(szTitle);
    
    // Add all block types - SourceMod auto-paginates with Next/Back
    for (int i = 0; i < MAX_BLOCKS; i++) {
        char szNum[8], szName[64];
        IntToString(i, szNum, sizeof(szNum));
        Format(szName, sizeof(szName), "%T", g_szBlockTransKeys[i], client);
        menu.AddItem(szNum, szName);
    }
    
    menu.ExitButton = true;
    // Jump to the page containing the currently selected block type
    int startItem = (g_SelectedBlockType[client] / 7) * 7;
    menu.DisplayAt(client, startItem, MENU_TIME_FOREVER);
}

public int Handle_BlockSelection(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel) { ShowBlockMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[8];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    int blockType = StringToInt(szInfo);
    
    if (blockType >= 0 && blockType < MAX_BLOCKS) {
        g_SelectedBlockType[client] = blockType;
        char szName[64];
        Format(szName, sizeof(szName), "%T", g_szBlockTransKeys[blockType], client);
        PrintToChat(client, "%s%T", PREFIX, "Block_TypeSet", client, szName);
    }
    
    // Return to block menu after selection
    ShowBlockMenu(client);
    return 0;
}

void ShowTeleportMenu(int client)
{
    char szItem[128];
    Menu menu = new Menu(Handle_TeleportMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Teleport", client);
    menu.SetTitle(szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TeleStart", client); menu.AddItem("start", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TeleDest", client); menu.AddItem("end", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_SwapStartDest", client); menu.AddItem("swap", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteTeleport", client); menu.AddItem("delete", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_ShowPath", client); menu.AddItem("show", szItem);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_TeleportMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) { ShowMainMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "start")) { CreateTeleportAiming(client, TELEPORT_START); }
    else if (StrEqual(szInfo, "end")) { CreateTeleportAiming(client, TELEPORT_END); }
    else if (StrEqual(szInfo, "swap")) { SwapTeleportAiming(client); }
    else if (StrEqual(szInfo, "delete")) { DeleteTeleportAiming(client); }
    else if (StrEqual(szInfo, "show")) { ShowTeleportPath(client); }
    
    ShowTeleportMenu(client);
    return 0;
}

void ShowTimerMenu(int client)
{
    char szItem[128];
    Menu menu = new Menu(Handle_TimerMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Timer", client);
    menu.SetTitle(szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TimerStart", client); menu.AddItem("start", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_TimerEnd", client); menu.AddItem("end", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_SwapStartEnd", client); menu.AddItem("swap", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteTimer", client); menu.AddItem("delete", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_RotateTimer", client); menu.AddItem("rotate", szItem);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_TimerMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) { ShowMainMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "start")) { CreateTimerAiming(client, TIMER_START); }
    else if (StrEqual(szInfo, "end")) { CreateTimerAiming(client, TIMER_END); }
    else if (StrEqual(szInfo, "swap")) { SwapTimerAiming(client); }
    else if (StrEqual(szInfo, "delete")) { DeleteTimerAiming(client); }
    else if (StrEqual(szInfo, "rotate")) { RotateTimerAiming(client); }
    
    ShowTimerMenu(client);
    return 0;
}

void ShowMeasureMenu(int client)
{
    char szItem[128];
    Menu menu = new Menu(Handle_MeasureMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Measure", client);
    menu.SetTitle(szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_SelectPos1", client); menu.AddItem("sel1", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_SelectPos2", client); menu.AddItem("sel2", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_MeasureDist", client); menu.AddItem("measure", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_ShowBeam", client); menu.AddItem("show", szItem);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_MeasureMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) { ShowMainMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "sel1")) {
        int ent = GetClientAimEntity(client, 9999.0);
        if (ent > 0 && IsValidEntity(ent)) {
            GetEntPropVector(ent, Prop_Data, "m_vecOrigin", g_fMeasurePos1[client]);
            g_MeasureBlock1[client] = EntIndexToEntRef(ent);
            PrintToChat(client, "%s%T", PREFIX, "Position1_Set", client);
        }
    }
    else if (StrEqual(szInfo, "sel2")) {
        int ent = GetClientAimEntity(client, 9999.0);
        if (ent > 0 && IsValidEntity(ent)) {
            GetEntPropVector(ent, Prop_Data, "m_vecOrigin", g_fMeasurePos2[client]);
            g_MeasureBlock2[client] = EntIndexToEntRef(ent);
            PrintToChat(client, "%s%T", PREFIX, "Position2_Set", client);
        }
    }
    else if (StrEqual(szInfo, "measure")) {
        if (g_MeasureBlock1[client] != INVALID_ENT_REFERENCE && g_MeasureBlock2[client] != INVALID_ENT_REFERENCE) {
            float dist = GetVectorDistance(g_fMeasurePos1[client], g_fMeasurePos2[client]);
            PrintToChat(client, "%s%T", PREFIX, "Measure_Distance", client, dist);
            PrintToChat(client, "%s%T", PREFIX, "Measure_XYZ", client,
                FloatAbs(g_fMeasurePos2[client][0] - g_fMeasurePos1[client][0]),
                FloatAbs(g_fMeasurePos2[client][1] - g_fMeasurePos1[client][1]),
                FloatAbs(g_fMeasurePos2[client][2] - g_fMeasurePos1[client][2]));
        } else {
            PrintToChat(client, "%s%T", PREFIX, "Select_Both", client);
        }
    }
    else if (StrEqual(szInfo, "show")) {
        if (g_MeasureBlock1[client] != INVALID_ENT_REFERENCE && g_MeasureBlock2[client] != INVALID_ENT_REFERENCE) {
            TE_SetupBeamPoints(g_fMeasurePos1[client], g_fMeasurePos2[client], g_BeamSprite, g_HaloSprite, 0, 1, 5.0, 3.0, 3.0, 0, 0.0, {0,255,0,255}, 0);
            TE_SendToAll();
        }
    }
    
    ShowMeasureMenu(client);
    return 0;
}

void ShowLongJumpMenu(int client)
{
    char szItem[128], szSizeName[32];
    Menu menu = new Menu(Handle_LongJumpMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_LongJump", client,
        g_LongJumpDistance[client], g_LongJumpAxis[client] == AXIS_X ? "X" : "Y");
    menu.SetTitle(szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DistUp", client); menu.AddItem("up", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_CreateLJ", client); menu.AddItem("create", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DistDown", client); menu.AddItem("down", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteBlock", client); menu.AddItem("delete", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_RotateAxis", client); menu.AddItem("rotate", szItem);
    
    switch (g_BlockSize[client]) {
        case SIZE_SMALL: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Small", client);
        case SIZE_NORMAL: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Normal", client);
        case SIZE_LARGE: Format(szSizeName, sizeof(szSizeName), "%T", "Size_Large", client);
    }
    Format(szItem, sizeof(szItem), "%T", "Item_BlockSize", client, szSizeName);
    menu.AddItem("size", szItem);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_LongJumpMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) { ShowMainMenu(client); return 0; }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "up")) { if (g_LongJumpDistance[client] < 300) g_LongJumpDistance[client]++; }
    else if (StrEqual(szInfo, "down")) { if (g_LongJumpDistance[client] > 200) g_LongJumpDistance[client]--; }
    else if (StrEqual(szInfo, "create")) { LongJumpCreate(client); }
    else if (StrEqual(szInfo, "delete")) { DeleteBlockAiming(client); }
    else if (StrEqual(szInfo, "rotate")) { g_LongJumpAxis[client] = (g_LongJumpAxis[client] == AXIS_X) ? AXIS_Y : AXIS_X; }
    else if (StrEqual(szInfo, "size")) { ChangeBlockSize(client); }
    
    ShowLongJumpMenu(client);
    return 0;
}

void ShowOptionsMenu(int client)
{
    char szItem[128];
    Menu menu = new Menu(Handle_OptionsMenu);
    Format(szItem, sizeof(szItem), "%T\n ", "Menu_Options", client);
    menu.SetTitle(szItem);
    
    char szOnOff[16];
    Format(szOnOff, sizeof(szOnOff), "%T", g_bSnapping[client] ? "ON" : "OFF", client);
    Format(szItem, sizeof(szItem), "%T", "Item_Snapping", client, szOnOff);
    menu.AddItem("snap", szItem);
    
    Format(szItem, sizeof(szItem), "%T", "Item_SnappingGap", client, g_fSnappingGap[client]);
    menu.AddItem("gap", szItem);
    
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteAllBlocks", client); menu.AddItem("delblocks", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteAllTele", client); menu.AddItem("deltele", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_DeleteAllTimers", client); menu.AddItem("deltimers", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_Save", client); menu.AddItem("save", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_Load", client); menu.AddItem("load", szItem);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_OptionsMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
        ShowMainMenu(client);
        return 0;
    }
    if (action != MenuAction_Select) return 0;
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "snap")) { g_bSnapping[client] = !g_bSnapping[client]; }
    else if (StrEqual(szInfo, "gap")) {
        g_fSnappingGap[client] += 4.0;
        if (g_fSnappingGap[client] > 40.0) g_fSnappingGap[client] = 0.0;
    }
    else if (StrEqual(szInfo, "delblocks")) { ShowConfirmMenu(client, CONFIRM_DELETE_ALL); return 0; }
    else if (StrEqual(szInfo, "deltele")) { ShowConfirmMenu(client, CONFIRM_DELETE_TELE); return 0; }
    else if (StrEqual(szInfo, "deltimers")) { ShowConfirmMenu(client, CONFIRM_DELETE_TIMERS); return 0; }
    else if (StrEqual(szInfo, "save")) { SaveBlocks(client); }
    else if (StrEqual(szInfo, "load")) { ShowConfirmMenu(client, CONFIRM_LOAD); return 0; }
    
    ShowOptionsMenu(client);
    return 0;
}

// ============== CONFIRMATION DIALOGS ==============
void ShowConfirmMenu(int client, int confirmAction)
{
    g_ConfirmAction[client] = confirmAction;
    
    char szTitle[256], szItem[64];
    Menu menu = new Menu(Handle_ConfirmMenu);
    
    switch (confirmAction) {
        case CONFIRM_DELETE_ALL: Format(szTitle, sizeof(szTitle), "%T\n ", "Menu_Confirm_DeleteBlocks", client);
        case CONFIRM_DELETE_TELE: Format(szTitle, sizeof(szTitle), "%T\n ", "Menu_Confirm_DeleteTele", client);
        case CONFIRM_DELETE_TIMERS: Format(szTitle, sizeof(szTitle), "%T\n ", "Menu_Confirm_DeleteTimers", client);
        case CONFIRM_LOAD: Format(szTitle, sizeof(szTitle), "%T\n ", "Menu_Confirm_Load", client);
    }
    menu.SetTitle(szTitle);
    
    Format(szItem, sizeof(szItem), "%T", "Item_Yes", client); menu.AddItem("yes", szItem);
    Format(szItem, sizeof(szItem), "%T", "Item_No", client); menu.AddItem("no", szItem);
    
    menu.ExitBackButton = false;
    menu.Display(client, 15);
}

public int Handle_ConfirmMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; return 0; }
    if (action != MenuAction_Select) {
        ShowOptionsMenu(client);
        return 0;
    }
    
    char szInfo[32];
    menu.GetItem(item, szInfo, sizeof(szInfo));
    
    if (StrEqual(szInfo, "yes")) {
        switch (g_ConfirmAction[client]) {
            case CONFIRM_DELETE_ALL: DeleteAllBlocks(client);
            case CONFIRM_DELETE_TELE: DeleteAllTeleports(client);
            case CONFIRM_DELETE_TIMERS: DeleteAllTimers(client);
            case CONFIRM_LOAD: LoadBlocks(client);
        }
    } else {
        PrintToChat(client, "%s%T", PREFIX, "Action_Cancelled", client);
    }
    
    ShowOptionsMenu(client);
    return 0;
}

// ============== DELETE ALL TIMERS ==============
void DeleteAllTimers(int client)
{
    int count = 0;
    for (int i = g_TimerEntities.Length - 1; i >= 0; i--) {
        int entRef = g_TimerEntities.Get(i);
        int ent = EntRefToEntIndex(entRef);
        if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
            AcceptEntityInput(ent, "Kill");
            count++;
        }
    }
    g_TimerEntities.Clear();
    g_TimerTypes.Clear();
    g_TimerLinks.Clear();
    g_TimerOrigins.Clear();
    g_TimerAngles.Clear();
    
    // Reset player timers
    for (int i = 1; i <= MaxClients; i++) {
        g_bHasTimer[i] = false;
        g_StartTimer[i] = INVALID_ENT_REFERENCE;
    }
    
    PrintToChat(client, "%s%T", PREFIX, "Timer_Deleted_Count", client, count);
}

// ============== BLOCK OPERATIONS ==============
void CreateBlockAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    float eyePos[3], eyeAng[3], hitPos[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    if (!TR_DidHit()) return;
    TR_GetEndPosition(hitPos);
    
    hitPos[2] += 4.0; // offset above surface
    
    CreateBlockEntity(client, g_SelectedBlockType[client], hitPos, AXIS_Z, g_BlockSize[client]);
}

void ConvertBlockAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int ent = GetClientAimEntity(client, 320.0);
    int blockIdx;
    if (ent < 1 || !IsBlockEntity(ent, blockIdx)) return;
    
    float origin[3], angles[3];
    GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
    GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
    
    // Determine axis from angles
    int axis = AXIS_Z;
    if (angles[0] == 90.0 && angles[2] == 0.0) axis = AXIS_X;
    else if (angles[0] == 90.0 && angles[2] == 90.0) axis = AXIS_Y;
    
    // Determine size from tracked data
    int size = g_BlockSizes.Get(blockIdx);
    
    DeleteBlockEntity(ent);
    CreateBlockEntity(client, g_SelectedBlockType[client], origin, axis, size);
}

void DeleteBlockAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int ent = GetClientAimEntity(client, 320.0);
    int blockIdx;
    if (ent > 0 && IsBlockEntity(ent, blockIdx)) {
        DeleteBlockEntity(ent);
    }
}

void RotateBlockAiming(int client)
{
    if (!IsAdmin(client)) return;

    int ent = GetClientAimEntity(client, 320.0);
    int blockIdx;
    if (ent < 1 || !IsBlockEntity(ent, blockIdx)) return;

    int blockType = g_BlockTypes.Get(blockIdx);

    // Blocks with billboard sprites can't be rotated
    if (blockType == BM_FIRE || blockType == BM_SPEEDBOOST || blockType == BM_TRAMPOLINE) {
        char szBNR[64]; Format(szBNR, sizeof(szBNR), "%T", g_szBlockTransKeys[blockType], client);
        PrintToChat(client, "%s%T", PREFIX, "Block_NoRotate", client, szBNR);
        return;
    }

    // Read current state
    float origin[3];
    GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);

    int size = g_BlockSizes.Get(blockIdx);
    int axis = g_BlockAxes.Get(blockIdx);

    // Next axis: Z -> X -> Y -> Z
    int newAxis = AXIS_Z;
    if (axis == AXIS_Z) newAxis = AXIS_X;
    else if (axis == AXIS_X) newAxis = AXIS_Y;
    else newAxis = AXIS_Z;

    // Kill old sprite (if any) but KEEP the block index
    int spriteRef = g_BlockSprites.Get(blockIdx);
    if (spriteRef != INVALID_ENT_REFERENCE) {
        int sprite = EntRefToEntIndex(spriteRef);
        if (sprite != INVALID_ENT_REFERENCE && IsValidEntity(sprite)) {
            AcceptEntityInput(sprite, "Kill");
        }
        g_BlockSprites.Set(blockIdx, INVALID_ENT_REFERENCE);
    }

    // Kill old entity
    if (ent < 2049) g_hBhopSolidTimer[ent] = null;
    AcceptEntityInput(ent, "Kill");

    // Recreate with new axis (do NOT push new array entries)
    int newSpriteRef;
    int newEnt = CreateBlockEntityInternal(client, blockType, origin, newAxis, size, false, newSpriteRef);
    if (newEnt == -1) return;

    g_BlockEntities.Set(blockIdx, EntIndexToEntRef(newEnt));
    g_BlockAxes.Set(blockIdx, newAxis);
    if (newSpriteRef != INVALID_ENT_REFERENCE) {
        g_BlockSprites.Set(blockIdx, newSpriteRef);
    }
}

void ChangeBlockSize(int client)
{
    switch (g_BlockSize[client]) {
        case SIZE_SMALL: g_BlockSize[client] = SIZE_NORMAL;
        case SIZE_NORMAL: g_BlockSize[client] = SIZE_LARGE;
        case SIZE_LARGE: g_BlockSize[client] = SIZE_SMALL;
    }
}

void ToggleGodmode(int client)
{
    if (!IsAdmin(client)) return;
    g_bAdminGodmode[client] = !g_bAdminGodmode[client];
    if (g_bAdminGodmode[client])
        SetEntProp(client, Prop_Data, "m_takedamage", 0);
    else
        SetEntProp(client, Prop_Data, "m_takedamage", 2);
}

void ToggleNoclip(int client)
{
    if (!IsAdmin(client)) return;
    g_bAdminNoclip[client] = !g_bAdminNoclip[client];
    SetEntityMoveType(client, g_bAdminNoclip[client] ? MOVETYPE_NOCLIP : MOVETYPE_WALK);
}

void LongJumpCreate(int client)
{
    if (!IsAdmin(client)) return;
    
    float hitPos[3], eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    if (!TR_DidHit()) return;
    TR_GetEndPosition(hitPos);
    hitPos[2] += 4.0;
    
    float fDist = float(g_LongJumpDistance[client]) / 2.0;
    float fHalfWidth = 32.0 * ((g_BlockSize[client] == SIZE_SMALL) ? SCALE_SMALL : (g_BlockSize[client] == SIZE_LARGE) ? SCALE_LARGE : SCALE_NORMAL);
    
    int axis = g_LongJumpAxis[client];
    
    float origin1[3], origin2[3];
    origin1[0] = hitPos[0]; origin1[1] = hitPos[1]; origin1[2] = hitPos[2];
    origin2[0] = hitPos[0]; origin2[1] = hitPos[1]; origin2[2] = hitPos[2];
    
    origin1[axis] -= (fDist + fHalfWidth);
    origin2[axis] += (fDist + fHalfWidth);
    
    CreateBlockEntity(client, BM_PLATFORM, origin1, AXIS_Z, g_BlockSize[client]);
    CreateBlockEntity(client, BM_PLATFORM, origin2, AXIS_Z, g_BlockSize[client]);
}

void SwapTeleportAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int pairIdx = GetNearestTeleportPair(client);
    if (pairIdx == -1) {
        PrintToChat(client, "%s%T", PREFIX, "No_Teleport_Nearby", client);
        return;
    }
    
    int startEnt = EntRefToEntIndex(g_TeleportStartEnts.Get(pairIdx));
    int endEnt = EntRefToEntIndex(g_TeleportEndEnts.Get(pairIdx));
    
    if (startEnt != INVALID_ENT_REFERENCE && endEnt != INVALID_ENT_REFERENCE) {
        float startPos[3], endPos[3];
        GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startPos);
        GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", endPos);
        
        TeleportEntity(startEnt, endPos, NULL_VECTOR, NULL_VECTOR);
        TeleportEntity(endEnt, startPos, NULL_VECTOR, NULL_VECTOR);
        
        g_TeleportStartPos.SetArray(pairIdx, endPos, 3);
        g_TeleportEndPos.SetArray(pairIdx, startPos, 3);
        
        PrintToChat(client, "%s%T", PREFIX, "Teleport_Swapped", client);
    }
}

void SwapTimerAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int ent = GetClientAimEntity(client, 9999.0);
    if (ent < 1) return;
    
    int entRef = EntIndexToEntRef(ent);
    for (int i = 0; i < g_TimerEntities.Length; i++) {
        if (g_TimerEntities.Get(i) == entRef) {
            int linkRef = g_TimerLinks.Get(i);
            int linkEnt = EntRefToEntIndex(linkRef);
            int thisEnt = EntRefToEntIndex(entRef);
            
            if (linkEnt != INVALID_ENT_REFERENCE && thisEnt != INVALID_ENT_REFERENCE) {
                float pos1[3], pos2[3];
                GetEntPropVector(thisEnt, Prop_Data, "m_vecOrigin", pos1);
                GetEntPropVector(linkEnt, Prop_Data, "m_vecOrigin", pos2);
                
                TeleportEntity(thisEnt, pos2, NULL_VECTOR, NULL_VECTOR);
                TeleportEntity(linkEnt, pos1, NULL_VECTOR, NULL_VECTOR);
                
                // Swap stored origins
                int linkIdx = g_TimerEntities.FindValue(linkRef);
                if (linkIdx != -1) {
                    g_TimerOrigins.SetArray(i, pos2, 3);
                    g_TimerOrigins.SetArray(linkIdx, pos1, 3);
                }
                
                PrintToChat(client, "%s%T", PREFIX, "Timer_Swapped", client);
            }
            return;
        }
    }
}

void RotateTimerAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int ent = GetClientAimEntity(client, 9999.0);
    if (ent < 1) return;
    
    int entRef = EntIndexToEntRef(ent);
    int idx = g_TimerEntities.FindValue(entRef);
    if (idx == -1) return;
    
    float angles[3];
    GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
    angles[1] += 90.0;
    if (angles[1] >= 360.0) angles[1] -= 360.0;
    TeleportEntity(ent, NULL_VECTOR, angles, NULL_VECTOR);
    g_TimerAngles.SetArray(idx, angles, 3);
    PrintToChat(client, "%s%T", PREFIX, "Timer_Rotated", client);
}

void CreateTeleportAiming(int client, int teleType)
{
    if (!IsAdmin(client)) return;
    
    float hitPos[3], eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    if (!TR_DidHit()) return;
    TR_GetEndPosition(hitPos);
    hitPos[2] += TELEPORT_Z_OFFSET;
    
    CreateTeleportEntity(client, teleType, hitPos);
}

void DeleteTeleportAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int pairIdx = GetNearestTeleportPair(client);
    if (pairIdx == -1) {
        PrintToChat(client, "%s%T", PREFIX, "No_Teleport_Nearby", client);
        return;
    }
    
    int startRef = g_TeleportStartEnts.Get(pairIdx);
    int endRef = g_TeleportEndEnts.Get(pairIdx);
    
    int startEnt = EntRefToEntIndex(startRef);
    int endEnt = EntRefToEntIndex(endRef);
    
    if (startEnt != INVALID_ENT_REFERENCE && IsValidEntity(startEnt))
        AcceptEntityInput(startEnt, "Kill");
    if (endEnt != INVALID_ENT_REFERENCE && IsValidEntity(endEnt))
        AcceptEntityInput(endEnt, "Kill");
    
    g_TeleportStartEnts.Erase(pairIdx);
    g_TeleportEndEnts.Erase(pairIdx);
    g_TeleportLinks.Erase(pairIdx);
    g_TeleportStartPos.Erase(pairIdx);
    g_TeleportEndPos.Erase(pairIdx);
    
    PrintToChat(client, "%s%T", PREFIX, "Teleport_Deleted", client);
}

void ShowTeleportPath(int client)
{
    int pairIdx = GetNearestTeleportPair(client);
    if (pairIdx == -1) {
        PrintToChat(client, "%s%T", PREFIX, "No_Teleport_Nearby", client);
        return;
    }
    
    int startEnt = EntRefToEntIndex(g_TeleportStartEnts.Get(pairIdx));
    int endEnt = EntRefToEntIndex(g_TeleportEndEnts.Get(pairIdx));
    
    if (startEnt != INVALID_ENT_REFERENCE && endEnt != INVALID_ENT_REFERENCE) {
        float startPos[3], endPos[3];
        GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startPos);
        GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", endPos);
        
        TE_SetupBeamPoints(startPos, endPos, g_BeamSprite, g_HaloSprite, 0, 1, 5.0, 3.0, 3.0, 0, 0.0, {255,255,255,255}, 0);
        TE_SendToAll();
        
        float dist = GetVectorDistance(startPos, endPos);
        PrintToChat(client, "%s%T", PREFIX, "Teleport_Path", client, dist);
    }
}

// Find nearest teleport pair to where player is aiming (within 256 units of aim hit point)
int GetNearestTeleportPair(int client)
{
    float eyePos[3], eyeAng[3], aimPos[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    if (TR_DidHit()) {
        TR_GetEndPosition(aimPos);
    } else {
        // Fallback: 500 units ahead
        float fwd[3];
        GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);
        aimPos[0] = eyePos[0] + fwd[0] * 500.0;
        aimPos[1] = eyePos[1] + fwd[1] * 500.0;
        aimPos[2] = eyePos[2] + fwd[2] * 500.0;
    }
    
    float bestDist = 256.0;
    int bestIdx = -1;
    
    for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
        int startEnt = EntRefToEntIndex(g_TeleportStartEnts.Get(i));
        int endEnt = EntRefToEntIndex(g_TeleportEndEnts.Get(i));
        
        if (startEnt != INVALID_ENT_REFERENCE && IsValidEntity(startEnt)) {
            float pos[3];
            GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", pos);
            float dist = GetVectorDistance(aimPos, pos);
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
            }
        }
        if (endEnt != INVALID_ENT_REFERENCE && IsValidEntity(endEnt)) {
            float pos[3];
            GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", pos);
            float dist = GetVectorDistance(aimPos, pos);
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
            }
        }
    }
    
    return bestIdx;
}

void CreateTimerAiming(int client, int timerType)
{
    if (!IsAdmin(client)) return;
    
    float hitPos[3], eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    TR_TraceRayFilter(eyePos, eyeAng, MASK_SOLID, RayType_Infinite, TraceFilter_NoPlayers, client);
    if (!TR_DidHit()) return;
    TR_GetEndPosition(hitPos);
    
    CreateTimerEntity(client, timerType, hitPos);
}

void DeleteTimerAiming(int client)
{
    if (!IsAdmin(client)) return;
    
    int ent = GetClientAimEntity(client, 9999.0);
    if (ent < 1) return;
    
    int entRef = EntIndexToEntRef(ent);
    for (int i = 0; i < g_TimerEntities.Length; i++) {
        if (g_TimerEntities.Get(i) == entRef) {
            // Find and delete linked timer too
            int linkRef = g_TimerLinks.Get(i);
            
            // Delete linked
            int linkIdx = g_TimerEntities.FindValue(linkRef);
            if (linkIdx != -1) {
                int linkEnt = EntRefToEntIndex(linkRef);
                if (linkEnt != INVALID_ENT_REFERENCE && IsValidEntity(linkEnt))
                    AcceptEntityInput(linkEnt, "Kill");
                g_TimerEntities.Erase(linkIdx);
                g_TimerTypes.Erase(linkIdx);
                g_TimerLinks.Erase(linkIdx);
                g_TimerOrigins.Erase(linkIdx);
                g_TimerAngles.Erase(linkIdx);
                // Adjust i if needed
                if (linkIdx < i) i--;
            }
            
            // Delete this one
            int thisEnt = EntRefToEntIndex(entRef);
            if (thisEnt != INVALID_ENT_REFERENCE && IsValidEntity(thisEnt))
                AcceptEntityInput(thisEnt, "Kill");
            if (i < g_TimerEntities.Length) {
                g_TimerEntities.Erase(i);
                g_TimerTypes.Erase(i);
                g_TimerLinks.Erase(i);
                g_TimerOrigins.Erase(i);
                g_TimerAngles.Erase(i);
            }
            
            PrintToChat(client, "%s%T", PREFIX, "Timer_Deleted_Single", client);
            return;
        }
    }
}

void DeleteAllBlocks(int client)
{
    if (!IsAdmin(client)) return;
    
    int count = g_BlockEntities.Length;
    for (int i = g_BlockEntities.Length - 1; i >= 0; i--) {
        int entRef = g_BlockEntities.Get(i);
        int ent = EntRefToEntIndex(entRef);
        if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
            // Delete sprite
            int spriteRef = g_BlockSprites.Get(i);
            if (spriteRef != INVALID_ENT_REFERENCE) {
                int sprite = EntRefToEntIndex(spriteRef);
                if (sprite != INVALID_ENT_REFERENCE && IsValidEntity(sprite))
                    AcceptEntityInput(sprite, "Kill");
            }
            AcceptEntityInput(ent, "Kill");
        }
    }
    g_BlockEntities.Clear();
    g_BlockTypes.Clear();
    g_BlockSprites.Clear();
    g_ArrowYaws.Clear();
    g_BlockRandomType.Clear();
    g_BlockSizes.Clear();
    g_BlockAxes.Clear();
    g_BlockOrigins.Clear();
    
    char szName[64];
    GetClientName(client, szName, sizeof(szName));
    PrintToChatAll("%s%T", PREFIX, "Deleted_All_Blocks", LANG_SERVER, szName, count);
}

void DeleteAllTeleports(int client)
{
    if (!IsAdmin(client)) return;
    
    int count = g_TeleportStartEnts.Length;
    for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
        int startEnt = EntRefToEntIndex(g_TeleportStartEnts.Get(i));
        int endEnt = EntRefToEntIndex(g_TeleportEndEnts.Get(i));
        if (startEnt != INVALID_ENT_REFERENCE && IsValidEntity(startEnt)) AcceptEntityInput(startEnt, "Kill");
        if (endEnt != INVALID_ENT_REFERENCE && IsValidEntity(endEnt)) AcceptEntityInput(endEnt, "Kill");
    }
    g_TeleportStartEnts.Clear();
    g_TeleportEndEnts.Clear();
    g_TeleportLinks.Clear();
    g_TeleportStartPos.Clear();
    g_TeleportEndPos.Clear();
    
    for (int i = 1; i <= MaxClients; i++)
        g_TeleportStart[i] = INVALID_ENT_REFERENCE;
    
    char szName[64];
    GetClientName(client, szName, sizeof(szName));
    PrintToChatAll("%s%T", PREFIX, "Deleted_All_Teleports", LANG_SERVER, szName, count);
}

void ShowTimerScoreboard(int client)
{
    char szBuffer[2048];
    char szMapName[64];
    GetCurrentMap(szMapName, sizeof(szMapName));
    
    int len = 0;
    len += Format(szBuffer[len], sizeof(szBuffer) - len, "<html><body style='background:#1a1a2e;color:white;font-family:monospace;'>");
    len += Format(szBuffer[len], sizeof(szBuffer) - len, "<h2>Top 15 Climbers - %s</h2>", szMapName);
    len += Format(szBuffer[len], sizeof(szBuffer) - len, "<table border=1 cellpadding=4><tr><th>#</th><th>Player</th><th>Time</th></tr>");
    
    for (int i = 0; i < MAX_SCORE_ENTRIES; i++) {
        if (g_fScoreTimes[i] >= 999999.0) {
            len += Format(szBuffer[len], sizeof(szBuffer) - len, "<tr><td>%d</td><td>-</td><td>-</td></tr>", i+1);
        } else {
            int mins = RoundToFloor(g_fScoreTimes[i] / 60.0);
            float fSecs = g_fScoreTimes[i] - (mins * 60.0);
            len += Format(szBuffer[len], sizeof(szBuffer) - len, "<tr><td>%d</td><td>%s</td><td>%s%d:%s%.3f</td></tr>",
                i+1, g_szScoreNames[i],
                (mins < 10 ? "0" : ""), mins,
                (fSecs < 10.0 ? "0" : ""), fSecs);
        }
    }
    
    len += Format(szBuffer[len], sizeof(szBuffer) - len, "</table></body></html>");
    
    ShowMOTDPanel(client, "Top 15 Climbers", szBuffer, MOTDPANEL_TYPE_TEXT);
}

// ============== SAVE / LOAD (compatible with original .bm format) ==============
void SaveBlocks(int client)
{
    if (!IsAdmin(client)) return;
    
    File file = OpenFile(g_szSaveFile, "wt");
    if (file == null) {
        PrintToChat(client, "%s%T", PREFIX, "Save_Failed", client);
        return;
    }
    
    int blockCount = 0, teleCount = 0, timerCount = 0;
    char szData[128];
    
    // Save blocks
    for (int i = 0; i < g_BlockEntities.Length; i++) {
        int entRef = g_BlockEntities.Get(i);
        int ent = EntRefToEntIndex(entRef);
        if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent)) continue;
        
        int blockType = g_BlockTypes.Get(i);
        float origin[3], angles[3];
        GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
        GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);

        int size = g_BlockSizes.Get(i);
        
        Format(szData, sizeof(szData), "%c %f %f %f %f %f %f %d",
            g_BlockSaveIds[blockType],
            origin[0], origin[1], origin[2],
            angles[0], angles[1], angles[2], size);
        file.WriteLine(szData);
        blockCount++;
    }
    
    // Save teleports
    for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
        int startEnt = EntRefToEntIndex(g_TeleportStartEnts.Get(i));
        int endEnt = EntRefToEntIndex(g_TeleportEndEnts.Get(i));
        if (startEnt == INVALID_ENT_REFERENCE || endEnt == INVALID_ENT_REFERENCE) continue;
        
        float startPos[3], endPos[3];
        GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startPos);
        GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", endPos);
        
        Format(szData, sizeof(szData), "%c %f %f %f %f %f %f",
            TELEPORT_SAVE_ID,
            startPos[0], startPos[1], startPos[2],
            endPos[0], endPos[1], endPos[2]);
        file.WriteLine(szData);
        teleCount++;
    }
    
    // Save timers (in pairs: start then end)
    for (int i = 0; i < g_TimerEntities.Length; i++) {
        int timerType = g_TimerTypes.Get(i);
        if (timerType != TIMER_END) continue;
        
        int endRef = g_TimerEntities.Get(i);
        int startRef = g_TimerLinks.Get(i);
        
        int endEnt = EntRefToEntIndex(endRef);
        int startEnt = EntRefToEntIndex(startRef);
        if (startEnt == INVALID_ENT_REFERENCE || endEnt == INVALID_ENT_REFERENCE) continue;
        
        float startPos[3], startAng[3], endPos[3], endAng[3];
        GetEntPropVector(startEnt, Prop_Data, "m_vecOrigin", startPos);
        GetEntPropVector(startEnt, Prop_Data, "m_angRotation", startAng);
        GetEntPropVector(endEnt, Prop_Data, "m_vecOrigin", endPos);
        GetEntPropVector(endEnt, Prop_Data, "m_angRotation", endAng);
        
        Format(szData, sizeof(szData), "%c %f %f %f %f %f %f",
            TIMER_SAVE_ID, startPos[0], startPos[1], startPos[2], startAng[0], startAng[1], startAng[2]);
        file.WriteLine(szData);
        
        Format(szData, sizeof(szData), "%c %f %f %f %f %f %f",
            TIMER_SAVE_ID, endPos[0], endPos[1], endPos[2], endAng[0], endAng[1], endAng[2]);
        file.WriteLine(szData);
        timerCount++;
    }
    
    delete file;
    
    char szName[64];
    GetClientName(client, szName, sizeof(szName));
    PrintToChatAll("%s%T", PREFIX, "Save_Success", LANG_SERVER, szName, blockCount, teleCount, timerCount);
}

public Action Timer_LoadBlocks(Handle timer)
{
    LoadBlocks(0);
    return Plugin_Stop;
}

void LoadBlocks(int client)
{
    if (client > 0 && !IsAdmin(client)) return;
    
    if (!FileExists(g_szSaveFile)) {
        if (client > 0)
            PrintToChat(client, "%s%T", PREFIX, "No_Save_File", client);
        return;
    }
    
    // Delete existing blocks/teleports/timers
    if (client > 0) {
        // Clear without notification
        for (int i = g_BlockEntities.Length - 1; i >= 0; i--) {
            int entRef = g_BlockEntities.Get(i);
            int ent = EntRefToEntIndex(entRef);
            if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent)) {
                int spriteRef = g_BlockSprites.Get(i);
                if (spriteRef != INVALID_ENT_REFERENCE) {
                    int sprite = EntRefToEntIndex(spriteRef);
                    if (sprite != INVALID_ENT_REFERENCE && IsValidEntity(sprite))
                        AcceptEntityInput(sprite, "Kill");
                }
                AcceptEntityInput(ent, "Kill");
            }
        }
        g_BlockEntities.Clear(); g_BlockTypes.Clear(); g_BlockSprites.Clear();
        g_ArrowYaws.Clear(); g_BlockRandomType.Clear(); g_BlockSizes.Clear(); g_BlockAxes.Clear(); g_BlockOrigins.Clear();
        
        for (int i = 0; i < g_TeleportStartEnts.Length; i++) {
            int s = EntRefToEntIndex(g_TeleportStartEnts.Get(i));
            int e = EntRefToEntIndex(g_TeleportEndEnts.Get(i));
            if (s != INVALID_ENT_REFERENCE && IsValidEntity(s)) AcceptEntityInput(s, "Kill");
            if (e != INVALID_ENT_REFERENCE && IsValidEntity(e)) AcceptEntityInput(e, "Kill");
        }
        g_TeleportStartEnts.Clear(); g_TeleportEndEnts.Clear(); g_TeleportLinks.Clear(); g_TeleportStartPos.Clear(); g_TeleportEndPos.Clear();
        
        for (int i = 0; i < g_TimerEntities.Length; i++) {
            int t = EntRefToEntIndex(g_TimerEntities.Get(i));
            if (t != INVALID_ENT_REFERENCE && IsValidEntity(t)) AcceptEntityInput(t, "Kill");
        }
        g_TimerEntities.Clear(); g_TimerTypes.Clear(); g_TimerLinks.Clear(); g_TimerOrigins.Clear(); g_TimerAngles.Clear();
    }
    
    File file = OpenFile(g_szSaveFile, "rt");
    if (file == null) return;
    
    int blockCount = 0, teleCount = 0, timerCount = 0;
    char szLine[256];
    bool bTimerStart = true;
    float vTimerOrigin[3], vTimerAngles[3];
    
    while (file.ReadLine(szLine, sizeof(szLine))) {
        TrimString(szLine);
        if (strlen(szLine) < 2) continue;
        
        char szParts[8][32];
        ExplodeString(szLine, " ", szParts, 8, 32);
        
        int typeChar = szParts[0][0];
        float v1[3], v2[3];
        v1[0] = StringToFloat(szParts[1]);
        v1[1] = StringToFloat(szParts[2]);
        v1[2] = StringToFloat(szParts[3]);
        v2[0] = StringToFloat(szParts[4]);
        v2[1] = StringToFloat(szParts[5]);
        v2[2] = StringToFloat(szParts[6]);
        int size = StringToInt(szParts[7]);
        
        // Determine block type from save ID
        if (typeChar == TELEPORT_SAVE_ID) {
            // Create teleport pair
            CreateTeleportEntity(0, TELEPORT_START, v1);
            CreateTeleportEntity(0, TELEPORT_END, v2);
            teleCount++;
        } else if (typeChar == TIMER_SAVE_ID) {
            if (bTimerStart) {
                vTimerOrigin[0] = v1[0]; vTimerOrigin[1] = v1[1]; vTimerOrigin[2] = v1[2];
                vTimerAngles[0] = v2[0]; vTimerAngles[1] = v2[1]; vTimerAngles[2] = v2[2];
                bTimerStart = false;
            } else {
                CreateTimerEntity(0, TIMER_START, vTimerOrigin, vTimerAngles);
                CreateTimerEntity(0, TIMER_END, v1, v2);
                bTimerStart = true;
                timerCount++;
            }
        } else {
            // Find block type
            int blockType = -1;
            for (int i = 0; i < MAX_BLOCKS; i++) {
                if (g_BlockSaveIds[i] == typeChar) {
                    blockType = i;
                    break;
                }
            }
            
            if (blockType >= 0) {
                // Determine axis from angles (v2 = angles for blocks)
                int axis = AXIS_Z;
                if (v2[0] == 90.0 && v2[1] == 0.0 && v2[2] == 0.0) axis = AXIS_X;
                else if (v2[0] == 90.0 && v2[1] == 0.0 && v2[2] == 90.0) axis = AXIS_Y;
                
                CreateBlockEntity(0, blockType, v1, axis, size);
                blockCount++;
            }
        }
    }
    
    delete file;
    
    if (client > 0) {
        char szName[64];
        GetClientName(client, szName, sizeof(szName));
        PrintToChatAll("%s%T", PREFIX, "Load_Success", LANG_SERVER, szName, blockCount, teleCount, timerCount);
    } else {
        LogMessage("%sLoaded %d blocks, %d teleports, %d timers from file", PREFIX, blockCount, teleCount, timerCount);
    }
}

// ============== AUTO BHOP ==============
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsPlayerAlive(client)) return Plugin_Continue;
    
    // Auto bhop
    if (g_bAutoBhop[client] && (buttons & IN_JUMP)) {
        if (!(GetEntityFlags(client) & FL_ONGROUND)) {
            buttons &= ~IN_JUMP;
        }
    }
    
    // Timer activation via +use (E key) near timer entities - only on key press
    if ((buttons & IN_USE) && !(g_iLastButtons[client] & IN_USE)) {
        ActionTimerCheck(client);
    }
    g_iLastButtons[client] = buttons;
    
    return Plugin_Continue;
}
