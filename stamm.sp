/**
 * -----------------------------------------------------
 * File        stamm.sp
 * Authors     David <popoklopsi> Ordnung
 * License     GPLv3
 * Web         http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * Copyright (C) 2012-2013 David <popoklopsi> Ordnung
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */

#pragma dynamic 131072



// Include Sourcemod API's
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <morecolors_stamm>
#include <autoexecconfig>
#include <regex>
#include <stringescape>

// Tf2
#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>

// Stamm Includes
#include "stamm/globals.sp"
#include "stamm/configlib.sp"
#include "stamm/levellib.sp"
#include "stamm/sqllib.sp"
#include "stamm/sqlback.sp"
#include "stamm/pointlib.sp"
#include "stamm/clientlib.sp"
#include "stamm/nativelib.sp"
#include "stamm/panellib.sp"
#include "stamm/eventlib.sp"
#include "stamm/featurelib.sp"
#include "stamm/otherlib.sp"

// Maybe include the updater if exists
#undef REQUIRE_PLUGIN
#include <updater>




// Use Semicolon
#pragma semicolon 1








// Plugin Information
public Plugin:myinfo =
{
	name = "Stamm",
	author = "Popoklopsi",
	version = g_sPluginVersionUpdate,
	description = "A powerful VIP Addon with a lot of features",
	url = "https://forums.alliedmods.net/showthread.php?t=142073"
};








// Add Natives and handle late load
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	nativelib_Start();
	
	g_bIsLate = late;
	
	return APLRes_Success;
}








// Finally it's loaded
public OnPluginStart()
{

	// Check the folders we need
	CheckStammFolders();



	// Fix color when Lightgreen isn't available
	if (!CColorAllowed(Color_Lightgreen))
	{
		if (CColorAllowed(Color_Lime))
		{
			CReplaceColor(Color_Lightgreen, Color_Lime);
		}
		else if (CColorAllowed(Color_Lightred))
		{
			CReplaceColor(Color_Lightgreen, Color_Lightred);
		}
		else if (CColorAllowed(Color_Olive))
		{
			CReplaceColor(Color_Lightgreen, Color_Olive);
		}
	}




	// Load stamm Translation 
	LoadTranslations("stamm.phrases");




	// Add start default point settings
	g_iPoints = 1;
	g_bHappyHourON = false;
	



	// Register Say Filter
	RegConsoleCmd("say", clientlib_CmdSay);



	// Register the Server Commands
	RegServerCmd("stamm_start_happyhour", otherlib_StartHappy, "Starts happy hour: stamm_start_happyhour <time> <factor>");
	RegServerCmd("stamm_stop_happyhour", otherlib_StopHappy, "Stops happy hour");

	RegServerCmd("stamm_feature_load", featurelib_Load, "Loads a feature: stamm_feature_load <basename>");
	RegServerCmd("stamm_feature_unload", featurelib_UnLoad, "Unloads a feature: stamm_feature_unload <basename>");
	RegServerCmd("stamm_feature_reload", featurelib_ReLoad, "Reloads a feature: stamm_feature_reload <basename>");

	RegServerCmd("stamm_feature_list", featurelib_List, "List all features.");

	RegServerCmd("stamm_convert_db", sqllib_convertDB, "Converts the stamm database to a file. stamm_convert_db <mysql>");





	// Command listener for load, reload and unload commands
	AddCommandListener(otherlib_commandListener);
	


	// Init. Stamm Components
	otherlib_saveGame();
	levellib_LoadLevels();
	configlib_CreateConfig();
	eventlib_Start();



	// check for morecolor support
	if (g_iGameID == GAME_CSGO)
	{
		g_bMoreColors = false;
	}
	else
	{
		g_bMoreColors = true;
	}

	

	// Create Hud Sync
	g_hHudSync = CreateHudSynchronizer();


	// No, it's not started, yet
	g_sPluginStarted = false;
}






// Handle Plugin End and Unload all features
public OnPluginEnd()
{
	for (new i=0; i < g_iFeatures; i++)
	{
		if (g_FeatureList[i][FEATURE_ENABLE])
		{
			// Unload all Features
			featurelib_UnloadFeature(g_FeatureList[i][FEATURE_HANDLE]);
		}
	}
}




// Also handle pause to avoid errors
public OnPluginPauseChange(bool:pause)
{
	if (pause)
	{
		// On Pause End Plugin
		OnPluginEnd();
	}
	else
	{
		// On unpause load all features again
		for (new i=0; i < g_iFeatures; i++)
		{
			if (g_FeatureList[i][FEATURE_ENABLE])
			{
				featurelib_loadFeature(g_FeatureList[i][FEATURE_HANDLE]);
			}
		}
	}
}




// Check the folders we need
public CheckStammFolders()
{
	// Strings
	decl String:oldFolder[PLATFORM_MAX_PATH + 1];
	decl String:oldFolder2[PLATFORM_MAX_PATH + 1];
	decl String:smFolder[PLATFORM_MAX_PATH + 1];
	decl String:CurrentDate[20];
	


	// Current time
	FormatTime(CurrentDate, sizeof(CurrentDate), "%d-%m-%y");
	
	// Build Path to the needed folders
	BuildPath(Path_SM, smFolder, sizeof(smFolder), "logs");
	BuildPath(Path_SM, oldFolder2, sizeof(oldFolder2), "stamm");
	BuildPath(Path_SM, oldFolder, sizeof(oldFolder), "Stamm");




	Format(g_sLogFile, sizeof(g_sLogFile), "%s/stamm_errors_(%s).log", smFolder, CurrentDate);
	Format(g_sDebugFile, sizeof(g_sDebugFile), "%s/stamm_debugs_(%s).log", smFolder, CurrentDate);




	// Check for old folder
	if (DirExists(oldFolder2) || DirExists(oldFolder))
	{
		LogToFile(g_sLogFile, "[ STAMM ] ATTENTION: Found Folder %s. Please move the folder levels inside to \"cfg/stamm\". Then delete it!", oldFolder2);
		PrintToServer("[ STAMM ] ATTENTION: Found Folder %s. Please move the folder levels inside to \"cfg/stamm\". Then delete it!", oldFolder2);
	}
}






// Configs are ready to use
public OnConfigsExecuted()
{
	// Load the Configs
	configlib_LoadConfig();



	// Add Auto Updater if exit and want
	if (LibraryExists("updater") && g_bAutoUpdate)
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	



	// No mapchange? Real load
	if (!g_sPluginStarted)
	{	
		// Start rest of stamm componants
		// They need the config
		sqllib_Start();
		pointlib_Start();
		sqllib_LoadDB();
	
		panellib_Start();
		

		// Get the database version
		sqlback_getDatabaseVersion();



		// Delete old Timers
		otherlib_checkTimer(pointlib_timetimer);
		otherlib_checkTimer(pointlib_showpointer);
		otherlib_checkTimer(otherlib_inftimer);
		otherlib_checkTimer(clientlib_olddelete);
		


		// get Time points? start timer
		if (g_iVipType == 3 || g_iVipType == 5 || g_iVipType == 6 ||  g_iVipType == 7)
		{
			pointlib_timetimer = CreateTimer((60.0*g_iTimePoint), pointlib_PlayerTime, _, TIMER_REPEAT);
		}
			

		// Show points some times
		if (g_iShowPoints) 
		{
			pointlib_showpointer = CreateTimer(float(g_iShowPoints), pointlib_PointShower, _, TIMER_REPEAT);
		}
		

		// Show information about stamm	
		if (g_fInfoTime > 0.0) 
		{
			otherlib_inftimer = CreateTimer(g_fInfoTime, otherlib_PlayerInfoTimer, _, TIMER_REPEAT);
		}


		// Delete old players
		if (g_iDelete) 
		{
			clientlib_olddelete = CreateTimer(36000.0, clientlib_deleteOlds, _, TIMER_REPEAT);
		}


		// Hud Text?
		if (g_iGameID == GAME_TF2 && g_bHudText)
		{
			CreateTimer(0.5, clientlib_ShowHudText, _, TIMER_REPEAT);
		}
	}
	


	// Download files and load them
	otherlib_PrepareFiles();
}






// Finally ready to start off
public stammStarted()
{	

	// no late load -> load all features added
	if (!g_bIsLate)
	{
		CreateTimer(0.5, featurelib_loadFeatures, -1);
	}
	else 
	{
		// Late loaded
		decl String:pathdir[PLATFORM_MAX_PATH + 1];
		decl String:buffer[PLATFORM_MAX_PATH + 1];

		new FileType:typs;



		// Path to the stamm plugins
		BuildPath(Path_SM, pathdir, sizeof(pathdir), "plugins/stamm");



		// Open the dir
		new Handle:dir = OpenDirectory(pathdir);



		// Valid dir?
		if (dir != INVALID_HANDLE)
		{
			// Read all files
			while (ReadDirEntry(dir, buffer, sizeof(buffer), typs))
			{
				// is it a file?
				if (typs == FileType_File)
				{
					// is it a .smx file?
					if (StrContains(buffer, ".smx", false) > 0)
					{
						// Load the feature
						ReplaceString(buffer, sizeof(buffer), ".smx", "", false);

						ServerCommand("sm plugins load stamm/%s", buffer);
					}
				}
			}

			// Close dir
			CloseHandle(dir);
		}



		// Load all features
		CreateTimer(2.0, featurelib_loadFeatures, -1);
	}




	// Print hint
	PrintToServer("Stamm started succesfully with %i Features and %i Levels", g_iFeatures, g_iLevels+g_iPLevels);




	// If debug, notice stamm started
	if (g_bDebug)
	{
		LogToFile(g_sDebugFile, "[ STAMM DEBUG ] Stamm successfully loaded");
	}


	// Start check timer
	CreateTimer(60.0, checkFeatures, _, TIMER_REPEAT);
}






// Check if features are valid
public Action:checkFeatures(Handle:timer, any:data)
{
	new current = 0;
	new Handle:runningPlugins[128] = INVALID_HANDLE;


	// Plugin Iterator
	new Handle:hIter = GetPluginIterator();



	// Loop
	while (MorePlugins(hIter) && current < 128)
	{
		new Handle:hPlugin = ReadPlugin(hIter);

		if (GetPluginStatus(hPlugin) == Plugin_Running)
		{
			// Set to running plugins
			runningPlugins[current] = hPlugin;
			current++;
		}
	}



	// Search for feature handle
	for (new i=0; i < g_iFeatures; i++)
	{
		new bool:found = false;

		for (new j=0; j < 128; j++)
		{
			if (runningPlugins[j] != INVALID_HANDLE && g_FeatureList[i][FEATURE_HANDLE] == runningPlugins[j])
			{
				found = true;

				break;
			}
		}

		// Plugin seems to be disabled
		if (!found)
		{
			g_FeatureList[i][FEATURE_ENABLE] = false;
		}
	}


	return Plugin_Continue;
}
