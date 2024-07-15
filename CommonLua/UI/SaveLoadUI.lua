if FirstLoad then
	g_SaveGameObj = false
	g_SaveLoadThread = false
	
	g_CurrentSaveGameItemId = false
	g_SaveGameDescrThread = false
end

DefineClass.SaveLoadObject = {
	__parents = { "PropertyObject" },
	items = false,
	initialized = false,
}

---
--- Lists all savegames for the "savegame" tag.
---
--- @return boolean, table<string, table> err, list
---         If successful, returns false and a table of savegame metadata.
---         If an error occurs, returns true and an error message.
function SaveLoadObject:ListSavegames()
	return Savegame.ListForTag("savegame")
end

---
--- Saves the current game state with the provided name.
---
--- @param name string The name to use for the saved game.
--- @return boolean, string success, error_message
---         If successful, returns true and an empty string.
---         If an error occurs, returns false and an error message.
function SaveLoadObject:DoSavegame(name)
	return SaveGame(name, { save_as_last  = true })
end

---
--- Loads the game state from the savegame with the provided name.
---
--- @param name string The name of the savegame to load.
--- @return boolean, string success, error_message
---         If successful, returns true and an empty string.
---         If an error occurs, returns false and an error message.
function SaveLoadObject:DoLoadgame(name)
	return LoadGame(name, { save_as_last = true })
end

---
--- Waits for and retrieves a list of saved games.
---
--- This function populates the `items` table with metadata about the available saved games.
--- If there are no errors retrieving the saved game list, the `items` table will be populated
--- with an entry for each saved game, containing the display name, ID, save name, and metadata.
--- The `initialized` flag will also be set to `true` if it was not already.
---
--- @return nil
function SaveLoadObject:WaitGetSaveItems()
	local items = {}
	local err, list = self:ListSavegames()
	if not err then
		for _, v in ipairs(list) do
			local id = #items + 1
			items[id] = {
				text = v.displayname,
				id = id,
				savename = v.savename,
				metadata = v,
			}
		end
	end
	self.items = items
	if not self.initialized then
		self.initialized = true
	end
end

---
--- Removes an item from the `items` table by its ID.
---
--- This function iterates through the `items` table and removes the item with the specified `id`.
--- If any items have an ID greater than the removed item, their IDs are decremented to maintain the correct order.
---
--- @param id number The ID of the item to remove.
--- @return nil
function SaveLoadObject:RemoveItem(id)
	local items = self.items or empty_table
	for i = #items, 1, -1 do
		local item_id = items[i].id
		if item_id == id then
			table.remove(items, i)
		elseif item_id > id then
			items[i].id = item_id - 1
		end
	end
end

---
--- Calculates the default save name for a new savegame.
---
--- This function iterates through the `items` table, which contains metadata about the available saved games.
--- It looks for save names that start with the default "Savegame" text, and finds the highest numbered save name.
--- It then returns a new default save name in the format "Savegame (N)", where N is one higher than the highest number found.
--- If no numbered save names are found, it simply returns "Savegame".
---
--- @return string The default save name to use for a new savegame.
function SaveLoadObject:CalcDefaultSaveName()
	local default_text = _InternalTranslate(T(278399852865, "Savegame"))
	local items = self.items
	local max_num = 0
	for k, v in ipairs(items) do
		local text = v.text
		if string.match(text, "^" .. default_text) then
			local number = (text == default_text) and 1 or tonumber(string.match(text, "^" .. default_text .. "%s%((%d+)%)$") or 0)
			max_num = Max(max_num, number)
		end
	end
	if max_num > 0 then
		return default_text .. " (" .. max_num + 1 .. ")"
	end
	return default_text:trim_spaces()
end

---
--- Shows a popup dialog to enter a new savegame name.
---
--- This function is called when the user wants to create a new savegame. It displays a popup dialog
--- that allows the user to enter a name for the new savegame. If the user enters a valid name, the
--- `SaveLoadObject:Save()` function is called to save the game with the provided name.
---
--- @param host table The UI element that is hosting the savegame UI.
--- @param item table The savegame item that is being overwritten, or `nil` if creating a new savegame.
--- @return nil
function SaveLoadObject:ShowNewSavegameNamePopup(host, item)
	if not host:IsThreadRunning("rename") then
		host:CreateThread("rename", function(item)
			local caption = _InternalTranslate(T(808375213123, "Enter name:"))
			local savename = config.DefaultOverwriteSavegameAnswer and item and item.text or
				WaitInputText(nil, caption, item and item.text or self:CalcDefaultSaveName(), 32,
					function (name)
						if not name:match("%w") then
							return T(528136022504, "The save name must contain at least one letter or digit")
						end
				end)
			if savename then
				self:Save(item, savename)
			end
		end, item)
	end
end

---
--- Saves the game with the provided name.
---
--- This function is called when the user wants to save the game. It displays a confirmation dialog
--- if the user is overwriting an existing savegame, and then calls `SaveLoadObject:DoSavegame()` to
--- perform the actual save operation. If the save is successful, it closes any open menu dialogs.
--- If there is an error, it displays an error message box.
---
--- @param item table The savegame item that is being overwritten, or `nil` if creating a new savegame.
--- @param name string The name to use for the new savegame.
--- @return nil
function SaveLoadObject:Save(item, name)
	name = name:trim_spaces()
	if name and name ~= "" then
		g_SaveLoadThread = IsValidThread(g_SaveLoadThread) and g_SaveLoadThread or CreateRealTimeThread(function(name, item)
			local parent = GetPreGameMainMenu() or GetInGameMainMenu()
			local err, savename
			if item then
				if config.DefaultOverwriteSavegameAnswer or WaitQuestion(parent,
					T(824112417429, "Warning"),
					T{883071764117, "Are you sure you want to overwrite <savename>?", savename = '"' .. Untranslated(item.text) .. '"'},
					T(689884995409, "Yes"),
					T(782927325160, "No")) == "ok" then
					err = DeleteGame(item.savename)
				else
					return
				end
			end
			if not err or err == "File Not Found" then
				err, savename = self:DoSavegame(name)
			end
			if not err then
				CloseMenuDialogs()
			else
				CreateErrorMessageBox(err, "savegame", nil, parent, {savename = T{129666099950, '"<name>"', name = Untranslated(name)}, error_code = Untranslated(err)})
			end
		end, name, item)
	end
end

---
--- Loads the game from the provided savegame.
---
--- This function is called when the user wants to load a savegame. It displays a confirmation dialog
--- if the user is loading a savegame while having unsaved progress, and then calls `SaveLoadObject:DoLoadgame()`
--- to perform the actual load operation. If the load is successful, it closes any open menu dialogs.
--- If there is an error, it displays an error message box.
---
--- @param dlg table The dialog that triggered the load operation, or `nil` if not called from a dialog.
--- @param item table The savegame item that is being loaded.
--- @param skipAreYouSure boolean If `true`, skips the confirmation dialog and directly loads the savegame.
--- @return nil
function SaveLoadObject:Load(dlg, item, skipAreYouSure)
	if item then
		local savename = item.savename
		g_SaveLoadThread = IsValidThread(g_SaveLoadThread) and g_SaveLoadThread or CreateRealTimeThread(function(dlg, savename)
			local metadata = item.metadata
			local err
			local parent = GetPreGameMainMenu() or GetInGameMainMenu() or (dlg and dlg.parent) or terminal.desktop
			if metadata and not metadata.corrupt and not metadata.incompatible then
				local in_game = GameState.gameplay -- this might change during loading
				local res = config.DefaultLoadAnywayAnswer or (in_game and not skipAreYouSure) and
					WaitQuestion(parent, T(824112417429, "Warning"),
						T(927104451536, "Are you sure you want to load this savegame? Any unsaved progress will be lost."),
						T(689884995409, "Yes"), T(782927325160, "No"))
					or "ok"
				if res == "ok" then
					err = self:DoLoadgame(savename, metadata)
					if not err then
						CloseMenuDialogs()
					else
						ProjectSpecificLoadGameFailed(dlg)
					end
				end
			else
				err = metadata and metadata.incompatible and "incompatible" or "corrupt"
			end
			if err then
				-- parent might have been destroyed
				parent = GetPreGameMainMenu() or GetInGameMainMenu() or (dlg and dlg.parent) or terminal.desktop
				CreateErrorMessageBox(err, "loadgame", nil, parent, {name = '"' .. Untranslated(item.text) .. '"'})
			end
		end, dlg, savename)
	end
end

---
--- Deletes the specified savegame.
---
--- This function is called when the user wants to delete a savegame. It displays a confirmation dialog
--- and then calls `DeleteGame()` to perform the actual deletion. If the deletion is successful, it removes
--- the savegame item from the list, updates the UI, and sets the selection to the next item in the list.
--- If there is an error, it displays an error message box.
---
--- @param dlg table The dialog that triggered the delete operation.
--- @param list table The list of savegame items.
--- @return nil
function SaveLoadObject:Delete(dlg, list)
	local list = list or dlg:ResolveId("idList")
	if not list or not list.focused_item then return end
	local ctrl = list[list.focused_item]
	if not ctrl then return end
	local item = ctrl and ctrl.context
	if item then
		local savename = item.savename
		CreateRealTimeThread(function(dlg, item, savename)
			if WaitQuestion(dlg.parent, T(824112417429, "Warning"), T{912614823850, "Are you sure you want to delete the savegame <savename>?", savename = '"' .. Untranslated(item.text) .. '"'}, T(689884995409, "Yes"), T(782927325160, "No")) == "ok" then
				LoadingScreenOpen("idDeleteScreen", "delete savegame")
				local err = DeleteGame(savename)
				if not err then
					if g_CurrentSaveGameItemId == item.id then
						g_CurrentSaveGameItemId = false
						DeleteThread(g_SaveGameDescrThread)
						dlg.idDescription:SetVisible(false)
					end
					self:RemoveItem(item.id)
					list:Clear()
					ObjModified(self)
					list:DeleteThread("SetInitialSelection")
					list:SetSelection(Min(item.id, #list))
					LoadingScreenClose("idDeleteScreen", "delete savegame")
				else
					LoadingScreenClose("idDeleteScreen", "delete savegame")
					CreateErrorMessageBox("", "deletegame", nil, dlg.parent, {name = '"' .. item.text .. '"'})
				end
			end
		end, dlg, item, savename)
	end
end

---
--- Creates a new SaveLoadObject instance and returns it.
---
--- This function is used to create and initialize a new SaveLoadObject instance, which is then
--- assigned to the global variable `g_SaveGameObj`. The SaveLoadObject class is responsible for
--- managing the save/load functionality of the game.
---
--- @return table A new instance of the SaveLoadObject class.
---
function SaveLoadObjectCreateAndLoad()
	g_SaveGameObj = SaveLoadObject:new()
	return g_SaveGameObj
end

---
--- Handles the event when a savegame is deleted.
---
--- This function is called when a savegame is deleted. It notifies the `g_SaveGameObj` object that the
--- savegame data has been modified, so that it can update its internal state accordingly.
---
--- @param name string The name of the deleted savegame.
--- @return nil
---
function OnMsg.SavegameDeleted(name)
	ObjModified(g_SaveGameObj)
end

-- savegame description text

---
--- Sets the savegame description texts in the dialog.
---
--- This function is responsible for setting the various text elements in the savegame dialog, such as the
--- savegame title, playtime, timestamp, revision information, and any problems with the savegame.
---
--- @param dialog table The dialog object containing the savegame description elements.
--- @param data table The metadata for the savegame.
--- @param missing_dlcs string A comma-separated list of missing DLCs.
--- @param mods_string string A comma-separated list of active mods.
--- @param mods_missing boolean Whether there are missing mods.
--- @return nil
---
function SetSavegameDescriptionTexts(dialog, data, missing_dlcs, mods_string, mods_missing)
	local playtime = T(77, "Unknown")
	if data.playtime then
		local h, m, s = FormatElapsedTime(data.playtime, "hms")
		local hours = Untranslated(string.format("%02d", h))
		local minutes = Untranslated(string.format("%02d", m))
		playtime = T{7549, "<hours>:<minutes>", hours = hours, minutes = minutes}
	end
	if not dialog or dialog.window_state == "destroying" then return end
	dialog.idSavegameTitle:SetText(Untranslated(data.displayname))
	dialog.idPlaytime:SetText(T{614724487683, "Playtime <playtime>", playtime = playtime})
	
	if dialog.idTimestamp then
		dialog.idTimestamp:SetText(T(827551891632, "Saved At: ") .. Untranslated(os.date("%Y-%m-%d %H:%M", data.timestamp)))
	end
	
	if rawget(dialog, "idRevision") then 
		dialog.idRevision:SetText(T{220802271589, "Revision <lua_revision> - <assets_revision>", lua_revision = data.lua_revision, assets_revision = data.assets_revision or ""})
	end
	if rawget(dialog, "idMap") then 
		dialog.idMap:SetText(T{316316205743, "Map <map>", map = Untranslated(data.map)})
	end
	
	local problem_text = ""
	if data and data.corrupt then
		problem_text = T(384520518199, "Save file is corrupted!")
	elseif data and data.incompatible then
		problem_text = T(117116727535, "Please update the game to the latest version to load this savegame.")
	elseif missing_dlcs and missing_dlcs ~= "" then
		problem_text = T{309852317927, "Missing downloadable content: <dlcs>", dlcs = Untranslated(missing_dlcs)}
	elseif mods_missing then
		problem_text = T(196062882816, "There are missing mods!")
	elseif data.required_lua_revision and LuaRevision < data.required_lua_revision then
		problem_text = T(329542364773, "Unknown save file format!")
	elseif data.lua_revision < config.SupportedSavegameLuaRevision then
		problem_text = T(936146497756, "Deprecated save file format!")
	end
	dialog.idProblem:SetText(problem_text)
	
	if mods_string and mods_string ~= "" then
		dialog.idActiveMods:SetText(T{560410899617, "Active mods <value>",value = Untranslated(mods_string)})
	else
		dialog.idActiveMods:SetText("")
	end
	
	if GetUIStyleGamepad() then
		dialog.idDelInfo:SetVisible(false)
	else
		local del_hint = not data.new_save and T(173045065615, "DEL to delete. ") or T("")
		dialog.idDelInfo:SetText(del_hint)
	end
end

-- implement in project specific file
---
--- Handles the case when loading a game fails.
--- This function is an empty implementation and should be overridden in a project-specific file.
---
--- @param dialog table The dialog that was used to load the game.
---
function ProjectSpecificLoadGameFailed(dialog)
end

---
--- Handles the display of savegame description in the save/load UI dialog.
---
--- This function is responsible for fetching the savegame metadata, processing it, and updating the UI elements in the dialog to display the savegame details.
---
--- @param item table The savegame item that the description is being displayed for.
--- @param dialog table The save/load UI dialog.
---
function ShowSavegameDescription(item, dialog)
	if not item then return end
	if g_CurrentSaveGameItemId ~= item.id then
		g_CurrentSaveGameItemId = false
		DeleteThread(g_SaveGameDescrThread)
		g_SaveGameDescrThread = CreateRealTimeThread(function(item, dialog)
			Savegame.CancelLoad()
			
			local metadata = item.metadata
			
			if dialog.window_state == "destroying" then return end
			
			local description = dialog:ResolveId("idDescription")
			if description then
				description:SetVisible(false)
			end
			
			if config.SaveGameScreenshot then
				if IsValidThread(g_SaveScreenShotThread) then
					WaitMsg("SaveScreenShotEnd")
				end
				Sleep(210)
			end
			
			if dialog.window_state == "destroying" then return end
			g_CurrentSaveGameItemId = item.id
			
			-- we need to reload the meta from the disk in order to have the screenshot!
			local data = {}
			local err
			if not metadata then
				-- new save
				data.displayname = T(4182, "<<< New Savegame >>>")
				data.timestamp = os.time()
				data.playtime = GetCurrentPlaytime()
				data.new_save = true
				data.lua_revision = config.SupportedSavegameLuaRevision
				data.game_difficulty = GetGameDifficulty()
			else
				err = GetFullMetadata(metadata, "reload")
				if metadata.corrupt then
					data.corrupt = true
					data.displayname = T(6907, "Damaged savegame")
				elseif metadata.incompatible then
					data.incompatible = true
					data.displayname = T(8648, "Incompatible savegame")
				else
					data = table.copy(metadata)
					data.displayname = Untranslated(data.displayname)
					if Platform.developer then
						local savename = metadata.savename:match("(.*)%.savegame%.sav$")
						savename = savename:gsub("%+", " ")
						savename = savename:gsub("%%(%d%d)", function(hex_code)
							return string.char(tonumber("0x" .. hex_code))
						end)
						if savename ~= metadata.displayname then
							data.displayname = Untranslated(metadata.displayname .. " - " .. savename)
						end
						data.displayname = Untranslated(data.displayname)
					end
				end
			end
			
			local mods_list, mods_string, mods_missing
			local max_mods, more = 30
			if data.active_mods and #data.active_mods > 0 then
				mods_list = {}
				for _, mod in ipairs(data.active_mods) do
					--mod is a table, containing id, title, version and lua_revision or is just the id in older saves
					local local_mod = table.find_value(ModsLoaded, "id", mod.id or mod) or Mods[mod.id or mod]
					if #mods_list >= max_mods then
						more = true
						break
					end
					table.insert(mods_list, mod.title or (local_mod and local_mod.title))
					local is_blacklisted = GetModBlacklistedReason(mod.id)
					local is_deprecated = is_blacklisted and is_blacklisted == "deprecate"
					if not is_deprecated and (not local_mod or not table.find(AccountStorage.LoadMods, mod.id or mod)) then
						mods_missing = true
					end
				end
				mods_string = TList(mods_list, ", ")
				if more then
					mods_string = mods_string .. "<nbsp>..."
				end
			end
			
			local dlcs_list = {}
			for _, dlc in ipairs(data.dlcs or empty_table) do
				if not IsDlcAvailable(dlc.id) then
					dlcs_list[#dlcs_list + 1] = dlc.name
				end
			end
			
			SetSavegameDescriptionTexts(dialog, data, TList(dlcs_list), mods_string, mods_missing)
			
			if config.SaveGameScreenshot then
				local image = ""
				local forced_path = not metadata and g_TempScreenshotFilePath or false
				if not forced_path and Savegame._MountPoint then
					local images = io.listfiles(Savegame._MountPoint, "screenshot*.jpg", "non recursive")
					if #(images or "") > 0 then
						image = images[1]
					end
				elseif forced_path and io.exists(forced_path) then
					image = forced_path
				end
				
				local image_elem = dialog:ResolveId("idImage")
				if image_elem then
					if image ~= "" and not err then
						image_elem:SetImage(image)
					else
						image_elem:SetImage("UI/Common/placeholder.tga")
					end
				end
			end
			
			local description = dialog:ResolveId("idDescription")
			if description then
				description:SetVisible(true)
			end
		end, item, dialog)
	end
end