if not config.Mods then
	DefineClass.ModItem = {}
	DefineClass.ModDef = {}
	DefineClass.ModItemPreset = { __parents = {"ModItem"} }
	function ModsLoadCode() end
	function ModsReloadDefs() end
	function ModsLoadLocTables() end
	function ModsReloadItems() end
	function DefineModItemPreset() end
	function DefineModItemCompositeObject() end
end

---
--- Opens the pre-game main menu.
---
function OpenPreGameMainMenu()
end

---
--- Gets the pre-game main menu.
---
--- @return table The pre-game main menu.
---
function GetPreGameMainMenu()
end

---
--- Opens the in-game main menu.
---
function OpenIngameMainMenu()
end

---
--- Gets the in-game main menu.
---
--- @return table The in-game main menu.
---
function GetInGameMainMenu()
end

---
--- Closes the in-game main menu.
---
function CloseIngameMainMenu()
end
function OpenPreGameMainMenu() end
function GetPreGameMainMenu() end
function OpenIngameMainMenu() end
function GetInGameMainMenu() end
function CloseIngameMainMenu() end

---
--- Prompts the user to confirm quitting the game, and if confirmed, quits the game.
---
--- @param parent table The parent object for the confirmation dialog.
---
function QuitGame(parent)
	parent = parent or terminal.desktop
	CreateRealTimeThread(function(parent)
		if WaitQuestion(parent, T(1000859, "Quit game?"), T(1000860, "Are you sure you want to exit the game?"), T(147627288183, "Yes"), T(1139, "No")) == "ok" then
			Msg("QuitGame")
			quit()
		end
	end, parent)
end

ToggleSoundDebug = empty_func
ToggleListenerUpdate = empty_func
DbgHideTerrainGrid = empty_func
DbgShowTerrainGrid = empty_func
SuspendFileSystemChanged = empty_func
ResumeFileSystemChanged = empty_func
NetPauseUpdateHash = empty_func
NetResumeUpdateHash = empty_func

if FirstLoad then
	FileSystemChangedFiles = false
end