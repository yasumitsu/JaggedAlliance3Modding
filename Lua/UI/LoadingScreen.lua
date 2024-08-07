DefineClass.ZuluBaseLoadingScreen = {
	__parents = { "BaseLoadingScreen" },
	MouseCursor = "UI/Cursors/Loading.tga",
}

DefineClass.ZuluLoadingScreen = {
	__parents = { "ZuluBaseLoadingScreen" },
	FadeOutTime = 300,
 	Background = RGB(0, 0, 0),
}

GameVar("g_LoadingHintsSeen",{})
GameVar("g_LoadingHintsNextIdx",1)

if FirstLoad then
	g_AutoClickLoadingScreenStart = Platform.developer and 1000 or false
	g_SplashScreen = "UI/SplashScreen"
	g_LoadingScreen = "UI/LoadingScreens/LoadingScreen"
	g_DefaultLoadingScreen = g_SplashScreen	
end	

function OnMsg.GameTestsBegin()
	g_AutoClickLoadingScreenStart = Platform.developer and 1
end

function OnMsg.GameTestsEnd()
	g_AutoClickLoadingScreenStart = Platform.developer and 1000 or false
end

--loading screen sync
table.insert(BlacklistedDialogClasses, "XZuluLoadingScreen")
local function OnLocalPlayerClicked()
	local dlg = GetDialog("XZuluLoadingScreen")
	if dlg then
		dlg.idStart:SetText(T(797976655881, "Ready"))
		dlg.idStart.idCheck:SetVisible(true)
		PlayFX("Loadingscreen","StartPopup")
	end
end
local function InitLSClickSync()
	if not IsInMultiplayerGame() then return end
	InitPlayersClickedSync("LoadingScreen", 
		function() --on done waiting
			--LoadingScreenClose sleeps, which can pause the event dispatcher, hence in sep thread
			CreateRealTimeThread(LoadingScreenClose, "idLoadedLoadingScreen", "sync")
		end,
		function(player_id) --on player clicked
			if player_id == netUniqueId then
				OnLocalPlayerClicked()
			end
		end)
end

---
--- Opens a loading screen for a specific sector.
---
--- @param id string The ID of the loading screen to open.
--- @param reason string The reason for opening the loading screen.
--- @param sector table The sector data.
--- @param metadata table Additional metadata for the loading screen.
---
function SectorLoadingScreenOpen(id, reason, sector, metadata)
	LoadingScreenOpen(id, reason, sector, metadata)
	InitLSClickSync()
	if not sector then return end
	
	local dlg = GetDialog("XZuluLoadingScreen")
end

---
--- Closes a sector loading screen.
---
--- @param id string The ID of the loading screen to close.
--- @param reason string The reason for closing the loading screen.
--- @param sector table The sector data.
---
function SectorLoadingScreenClose(id, reason, sector)	
	if sector then
		local dlg = GetDialog("XZuluLoadingScreen")
		if dlg then
			local context = dlg:GetContext()
			if not context.loaded then
				dlg:DeleteThread("loading anim")
				dlg:SetContext(SubContext(context, {loaded = true, hint = dlg.idHint:GetText()}))		
				dlg.idStart:SetText(T(517032475186, "Start"))
				dlg:SetMouseCursor("UI/Cursors/Cursor.tga")
				PlayFX("Loadingscreen","StartPopup")
				LoadingScreenOpen("idLoadedLoadingScreen", "loaded")
				if IsInMultiplayerGame() then
					if IsWaitingForPlayerToClick(netUniqueId, "LoadingScreen") then
						LoadingScreenOpen("idLoadedLoadingScreen", "sync")
					else
						OnLocalPlayerClicked() --in case ls wasn't up yet
					end
				end
			end
		end
	end	
	LoadingScreenClose(id, reason)
	Msg("SectorLoadingScreenClosed")
end

local old_LoadingScreenClose = LoadingScreenClose
---
--- Closes a loading screen and performs additional actions based on the reason for closing.
---
--- @param id string The ID of the loading screen to close.
--- @param reason string The reason for closing the loading screen.
---
function LoadingScreenClose(id, reason)
	if reason == "pregame menu" then
		g_DefaultLoadingScreen = g_LoadingScreen
		g_AutoClickLoadingScreenStart = false
	elseif reason == "loaded" then
		LocalPlayerClickedReady("LoadingScreen")
	end
	return old_LoadingScreenClose(id, reason)
end

g_SatelliteLoadingScreens = false
g_SatelliteLoadingScreens4k = false

---
--- Retrieves a random satellite loading screen from a given campaign folder.
---
--- @param campaign_folder string The path to the campaign folder containing the satellite loading screens.
--- @param b_4k boolean Whether to retrieve a 4K satellite loading screen.
--- @return string The path to the randomly selected satellite loading screen.
---
function GetSatelliteLoadingScreen(campaign_folder, b_4k)
	if not g_SatelliteLoadingScreens then
		local err, screens = AsyncListFiles(campaign_folder, "SatelliteView*")
		if err then return end
		
		g_SatelliteLoadingScreens  = g_SatelliteLoadingScreens or {}
		g_SatelliteLoadingScreens4k  = g_SatelliteLoadingScreens4k or {}
		for i, s in ipairs(screens) do
			local path, filename = SplitPath(s)
			local item = path .. filename
			if filename:ends_with(".4k") then
				g_SatelliteLoadingScreens4k[#g_SatelliteLoadingScreens4k + 1] = item
			else
				g_SatelliteLoadingScreens[#g_SatelliteLoadingScreens + 1] = item
			end
		end
	end
	local tbl = g_SatelliteLoadingScreens
	if b_4k and next(g_SatelliteLoadingScreens4k) then
		tbl = g_SatelliteLoadingScreens4k
	end
	return table.rand(tbl)
end

---
--- Retrieves the class name for a given loading screen ID.
---
--- @param id string The ID of the loading screen.
--- @return string The class name for the loading screen.
---
function LoadingScreenGetClassById(id)
	if id == "idSaveProfile" then
		return "BaseSavingScreen"
	elseif id == "idAutosaveScreen" then
		return "AutosaveScreen"
	elseif id == "idQuickSaveScreen" then
		return "QuickSaveScreen"
	end
	return "XZuluLoadingScreen"
end

---
--- Retrieves the loading screen parameters based on the provided metadata.
---
--- @param metadata table The metadata for the loading screen.
--- @param reason string The reason for the loading screen.
--- @return string The ID of the loading screen.
--- @return string The reason for the loading screen.
--- @return string The sector tip for the loading screen.
--- @return table The metadata for the loading screen.
---
function GetLoadingScreenParamsFromMetadata(metadata, reason)
	local id = metadata and metadata.satellite and "idSatelliteView" or "idLoadingSavegame"
	local tip = metadata and not metadata.satellite and metadata.sector
	return id, reason or "zulu load savegame", tip, metadata
end
