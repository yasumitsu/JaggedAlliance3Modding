
---
--- Opens the pre-game main menu.
---
--- @param mode string|nil The mode to set the pre-game menu to.
--- @param context table|nil Additional context to pass to the pre-game menu.
---
function OpenPreGameMainMenu(mode, context)
	LoadingScreenOpen("idLoadingScreen", "pregame menu")
	ResetGameSession()
	local dlg = OpenDialog("PreGameMenu")
	if dlg and mode then
		dlg:SetMode(mode, context)
	end
	LoadingScreenClose("idLoadingScreen", "pregame menu")
	if ChangingMap then
		WaitMsg("ChangeMapDone")
	end
	
	TryConnectToServer()
	
	ChangeGameState("setpiece_playing", false) -- in case a setpiece was still playing due to some error
	
	Msg("PreGameMenuOpen")
end

---
--- Gets the pre-game main menu dialog.
---
--- @return Dialog|nil The pre-game main menu dialog, or nil if it doesn't exist.
---
function GetPreGameMainMenu()
	return GetDialog("PreGameMenu")
end

---
--- Resets the current game session, closing all dialogs and changing the map to an empty one.
---
function ResetGameSession()
	Msg("ResetGameSession")
	CloseAllDialogs()
	if GetMap() ~= "" then
		ChangeMap("")
	end
	DoneGame()
end

---
--- Opens the in-game main menu.
---
--- This function is responsible for opening the in-game main menu. It checks if a setpiece is currently playing, and if so, it returns without opening the menu. Otherwise, it checks if the pre-game menu is already open, and if so, it closes the in-game menu. If the in-game menu is not open, it opens the in-game menu dialog.
---
--- @return nil
---
function OpenIngameMainMenu()
	-- This menu usually opens on pressing "Escape" which is the same key used to skip setpieces.
	-- People spam the key and there is a short time window in which you can pause during the setpiece
	-- and break stuff.
	if IsSetpiecePlaying() then return end

	if not GameState.pregame_menu then
		local menu = GetInGameMainMenu()
		if menu then
			CloseIngameMainMenu()
		else
			Msg("InGameMenuOpen")
			return OpenDialog("InGameMenu")
		end
	end
end

---
--- Gets the in-game main menu dialog.
---
--- @return Dialog|nil The in-game main menu dialog, or nil if it doesn't exist.
---
function GetInGameMainMenu()
	return GetDialog("InGameMenu")
end

---
--- Closes the in-game main menu dialog.
---
--- This function is responsible for closing the in-game main menu dialog. It calls the `CloseDialog` function with the string "InGameMenu" to close the dialog.
---
--- @return nil
---
function CloseIngameMainMenu()
	CloseDialog("InGameMenu")
end

---
--- Closes any open menu dialogs.
---
--- This function checks if there is an open pre-game or in-game main menu dialog, and if so, closes it. It ensures the dialog is not already in the process of being destroyed before closing it.
---
--- @return nil
---
function CloseMenuDialogs()
	local menu = GetPreGameMainMenu() or GetInGameMainMenu()
	if menu and menu.window_state ~= "destroying" then
		CloseDialog(menu)
	end
end