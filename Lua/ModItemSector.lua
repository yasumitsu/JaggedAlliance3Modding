if not config.Mods then return end

DefineClass.ModItemSector =  {
	__parents = { "ModItemUsingFiles" },
	
	EditorName = "Satellite sector",
	EditorSubmenu = "Campaign & Maps",
	Documentation = "Allows for the creation of new satellite sectors and maps for them, or the modification of existing ones.\n\nSave your changes in the map editor using Ctrl-S.",
	DocumentationLink = "Docs/ModTools/index.md.html",
	TestDescription = "Starts the selected campaign of the sector and teleports you to the sector.",
	
	properties = {
		{ id = "mapName", default = false, no_edit = true, editor = "text" },
		{ category = "Satellite Sector", id = "campaignId", name = "Campaign", editor = "choice", default = false, items = function(self) return PresetsCombo("CampaignPreset") end,
			validate = function(self, new_campaignId) return self:IsDuplicateMap(new_campaignId, self.sectorId) end },
		{ category = "Satellite Sector", id = "sectorId", name = "Sector", editor = "combo", default = false, items = function(self) return GetCampaignSectorsIds(self) end, items_allow_tags = true, no_edit = function(self) return not CampaignPresets[self.campaignId] end,
			validate = function(self, new_sectorId) return ValidateSectorId(new_sectorId, "allow_underground") or self:IsDuplicateMap(self.campaignId, new_sectorId) end },
		{ category = "Satellite Sector", id = "btn", editor = "buttons",
			buttons = {
				{ name = "Edit map", func = "EditMap", is_hidden = function(self) return self:ShouldHideProp() or self:ShouldHideMapButton("edit") end},
				{ name = "Close map editor", func = "CloseMapEditor", is_hidden = function(self) return self:ShouldHideProp() or self:ShouldHideMapButton("close") end},
			}
		},
		{ category = "Satellite Sector", id = "SatelliteSectorObj", name = "Satellite sector", default = false, editor = "nested_obj", auto_expand = true, 
			base_class = "SatelliteSector", default = false, no_edit = function(self) return self:ShouldHideProp() end },
		{ id = "name", default = false, editor = false },
	},
}

--- Called when a new ModItemSector is created in the editor.
---
--- This function generates a unique map name for the new ModItemSector and creates a new map folder with the "EmptyMap" template.
---
--- If the ModItemSector is being pasted, this function simply returns without doing anything.
--- Otherwise, it iterates through all ModItemCampaignPreset mod items and sets the campaignId property of the ModItemSector to the id of the first ModItemCampaignPreset found.
---
--- @param parent table The parent object of the ModItemSector.
--- @param ged table The GED (Graphical Editor Definition) object associated with the ModItemSector.
--- @param is_paste boolean Indicates whether the ModItemSector is being pasted or not.
function ModItemSector:OnEditorNew(parent, ged, is_paste)
	self:GenerateMapName()
	self:CreateMapFolder("EmptyMap")

	if is_paste then return end
	self.mod:ForEachModItem("ModItemCampaignPreset", function(modItem)
		self.campaignId = modItem.id
	end)
end

---
--- Returns a description of the ModItemSector based on whether a sector ID is set.
---
--- If no sector ID is set, the description will be "SatelliteSector". Otherwise, the description will be the sector ID.
---
--- @return string The description of the ModItemSector.
function ModItemSector:ModItemDescription()
	if not self.sectorId then
		return "SatelliteSector"
	else
		return self.sectorId
	end
end

---
--- Checks if the ModItemSector is in read-only mode.
---
--- @return boolean true if the ModItemSector is in read-only mode, false otherwise
function ModItemSector:IsReadOnly()
	return editor.IsModdingEditor()
end

---
--- Returns a warning message if the ModItemSector is in an invalid state.
---
--- If the ModItemSector has a campaignId and sectorId set, this function checks if the ModItemSector is dirty or if the associated campaign preset does not contain a sector with the same map as the SatelliteSectorObj. If either of these conditions is true, it returns a warning message indicating that the mod item should be saved to add the sector to the campaign preset.
---
--- @return string|nil The warning message, or nil if no warning is needed.
function ModItemSector:GetWarning()
	if self.campaignId and self.sectorId then
		local campaignSectors = CampaignPresets[self.campaignId] and CampaignPresets[self.campaignId].Sectors
		if self:IsDirty() or not campaignSectors or (self.SatelliteSectorObj and not table.find(campaignSectors, "Map", self.SatelliteSectorObj.Map)) then
			return "Save the mod item to add the sector in the campaign preset."
		end
	end
end

---
--- Returns an error message if the ModItemSector is in an invalid state.
---
--- This function checks the following conditions:
--- - If the `campaignId` and `sectorId` properties are empty, it returns an error message indicating that they should not be empty.
--- - If the `SatelliteSectorObj` is `nil`, it checks if the associated campaign preset contains a sector with the same `sectorId`. If not, it returns an error message indicating that the satellite sector is missing.
--- - If the map data file (`mapdata.lua`) does not exist in the mod item's folder, it returns an error message indicating that the map data is missing.
--- - If the `SatelliteSectorObj` has a `GroundSector` property, it checks if the ground sector exists in the campaign preset. If not, it returns an error message indicating that the ground sector is missing.
---
--- @return string|nil The error message, or `nil` if no error is found.
function ModItemSector:GetError()
	if self:ShouldHideProp() then
		return "Campaign and Sector ID should not be empty!"
	end
	
	local satSectorObj = self.SatelliteSectorObj
	
	if not satSectorObj then
		local campaignPreset = CampaignPresets[self.campaignId]
		local existingCampaignSector = campaignPreset and table.find_value(campaignPreset.Sectors, "Id", self.sectorId)
		if not existingCampaignSector then
			return string.format("Missing Satellite sector for %s", self.sectorId)
		end
	end
	
	local mapPath = self:GetFolderPathOS()
	if not io.exists(mapPath .. "mapdata.lua") then
		return string.format("Missing map data for the mod item in '%s'", mapPath)
	end
	
	if satSectorObj and satSectorObj.GroundSector then
		if not self:IsDuplicateMap(self.campaignId, satSectorObj.GroundSector) and not DoesSectorExist(self.campaignId, satSectorObj.GroundSector) then
			return string.format("There is no ground sector '%s' for this underground sector '%s'", satSectorObj.GroundSector, self.sectorId)
		end
	end
end

---
--- Determines whether the map button should be hidden based on the current state of the editor.
---
--- @param btnType string The type of map button, either "edit" or "close".
--- @return boolean True if the button should be hidden, false otherwise.
---
function ModItemSector:ShouldHideMapButton(btnType)
	if IsChangingMap() then return true end
	if btnType == "edit" then
		return editor.IsModdingEditor()
	elseif btnType == "close" then
		return not editor.IsModdingEditor()
	end
end

---
--- This function is called after the `ModItemSector` object is loaded. It updates the properties of the `SatelliteSectorObj` associated with the `ModItemSector` object.
---
--- Specifically, it:
--- - Makes a deep copy of the `properties` table of the `SatelliteSectorObj`.
--- - Iterates through the copied `properties` table and sets the `editor` property to `"text"` and the `read_only` property to `true` for any property with an `id` of `"Map"`.
--- - Assigns the updated `properties` table back to the `SatelliteSectorObj`.
---
--- This ensures that the `Map` property of the `SatelliteSectorObj` is displayed as read-only text in the editor.
---
function ModItemSector:PostLoad()	
	if self.SatelliteSectorObj then
		local newProperties = table.copy(self.SatelliteSectorObj.properties, "deep")
		for _, prop in ipairs(newProperties) do
			if prop.id == "Map" then
				prop.editor = "text"
				prop.read_only = true
			end
		end
		self.SatelliteSectorObj.properties = newProperties
	end
end

---
--- This function is called when a property of the `ModItemSector` object is set in the editor.
---
--- If the `prop_id` is either `"sectorId"` or `"campaignId"`, this function:
--- - Sets the `g_WeatherZones` global variable to `false`.
--- - Creates a new real-time thread that calls the `UpdateCampaignSector` function with the `prop_id`, `old_value`, and `ged` arguments.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged table The Ged (Game Editor) object associated with the property.
---
function ModItemSector:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "sectorId" or prop_id == "campaignId" then
		g_WeatherZones = false
		CreateRealTimeThread(function() self:UpdateCampaignSector(prop_id, old_value, ged) end)
	end
end

---
--- This function determines whether the `ModItemSector` object should hide a property.
---
--- If the `campaignId` property is `nil` or an empty string, the function returns `true`, indicating that the property should be hidden.
---
--- If the `sectorId` property is `nil` or an empty string, the function returns `true`, indicating that the property should be hidden.
---
--- @function ModItemSector:ShouldHideProp
--- @return boolean Whether the property should be hidden
function ModItemSector:ShouldHideProp()
	if not self.campaignId or self.campaignId == "" then
		return true
	end
	
	if not self.sectorId or self.sectorId == "" then
		return true
	end
end

---
--- This function opens the Ged (Game Editor) satellite sector editor and selects the satellite sector associated with the `ModItemSector` object.
---
--- If the `ChangingMap` global variable is `true`, the function returns without doing anything.
---
--- If the `SatelliteSectorObj` property of the `ModItemSector` object is `nil`, the function shows a warning message to the user.
---
--- Otherwise, the function creates a new real-time thread that performs the following steps:
--- 1. If the editor is in modding mode, it stops the modding editor and calls `ObjModified` on the `ModItemSector` object.
--- 2. It calls `PreSelectSectorInEditor` with the `ModItemSector` object as an argument to select the satellite sector in the editor.
---
--- @param socket table The socket object associated with the editor.
---
function ModItemSector:EditMap(root, prop_id, ged)
	CreateRealTimeThread(editor.StartModdingEditor, self, self:GetMapName())
end

---
--- Stops the modding editor and returns to the mod map.
---
--- @param root table The root object of the editor.
--- @param prop_id string The ID of the property that was set.
--- @param ged table The Ged (Game Editor) object associated with the property.
---
function ModItemSector:CloseMapEditor(root, prop_id, ged)
	editor.StopModdingEditor("return to mod map")
end

local function PreSelectSectorInEditor(modItemSector)
	-- not game or different campaign will cause the creation of new campaign automatically
	if not Game or not next(gv_Sectors) or modItemSector.campaignId ~= Game.Campaign then
		ProtectedModsReloadItems(nil, "force_reload")
		QuickStartCampaign(modItemSector.campaignId or "HotDiamonds", {difficulty = "Normal"}, modItemSector.sectorId or "A1")
	end
	
	OpenGedSatelliteSectorEditor()
	WaitMsg("GedOpened", 5000)
	SelectEditorSatelliteSector({ modItemSector.SatelliteSectorObj })
	UpdateGedSatelliteSectorEditorSel()
end

---
--- Opens the Ged (Game Editor) satellite sector editor and selects the satellite sector associated with the `ModItemSector` object.
---
--- If the `ChangingMap` global variable is `true`, the function returns without doing anything.
---
--- If the `SatelliteSectorObj` property of the `ModItemSector` object is `nil`, the function shows a warning message to the user.
---
--- Otherwise, the function creates a new real-time thread that performs the following steps:
--- 1. If the editor is in modding mode, it stops the modding editor and calls `ObjModified` on the `ModItemSector` object.
--- 2. It calls `PreSelectSectorInEditor` with the `ModItemSector` object as an argument to select the satellite sector in the editor.
---
--- @param socket table The socket object associated with the editor.
---
function ModItemSector:POpenGedSatelliteSectorEditor(socket)
	if ChangingMap then return end
	
	if not self.SatelliteSectorObj then
		socket:ShowMessage("Warning", "No satellite sector created.")
	end
	
	CreateRealTimeThread(function()
		if editor.IsModdingEditor() then
			editor.StopModdingEditor("return to mod map")
			ObjModified(self)
			PreSelectSectorInEditor(self)
		else
			PreSelectSectorInEditor(self)
		end
	end)
end

--- Generates a unique map name for the ModItemSector object.
---
--- The generated map name is stored in the `mapName` property of the ModItemSector object.
---
--- @param self ModItemSector The ModItemSector object.
function ModItemSector:GenerateMapName()
	self.mapName = ModDef.GenerateId()
end

--- Returns the map name of the ModItemSector object.
---
--- @return string The map name of the ModItemSector object.
function ModItemSector:GetMapName()
	return self.mapName
end

---
--- Returns a message to be displayed in the editor's status bar when the ModItemSector object is saved.
---
--- @param self ModItemSector The ModItemSector object.
--- @return string The status bar message.
function ModItemSector:GetEditorMessage()
	return string.format("Saved in mod: %s", Literal(self.mod.title)) -- appears in editor's status bar
end

---
--- Saves the map associated with the ModItemSector object.
---
--- This function calls the `XEditorSaveMap()` function to save the map.
---
function ModItemSector:SaveMap()
	XEditorSaveMap()
end

--- Returns the full OS file path for the map associated with the ModItemSector object.
---
--- The path is constructed by combining the mod's content path and the map name.
---
--- @param self ModItemSector The ModItemSector object.
--- @return string The full OS file path for the map.
function ModItemSector:GetFolderPathOS()
	return string.format("%sMaps/%s/", self.mod.content_path, self:GetMapName())
end

--- Adds the ModItemSector object to the current campaign after saving.
---
--- This function is called after the ModItemSector object is saved to ensure it is properly added to the current campaign.
---
--- @param self ModItemSector The ModItemSector object.
function ModItemSector:PostSave(...)
	self:AddToCampaign()
end

---
--- Tests the ModItemSector object.
---
--- This function performs the following steps:
--- 1. Checks if there are any errors associated with the ModItemSector object. If there are errors, it displays a message to the user and returns.
--- 2. Displays a warning message to the user, asking if they want to continue with the test. The test will create a new game campaign and teleport the user to the created map, and any unsaved changes will be lost.
--- 3. If the user confirms, it creates a new real-time thread to perform the following actions:
---    - Reloads all mod items, forcing a reload.
---    - Starts a new campaign with the ModItemSector's campaign ID and the "Normal" difficulty, and teleports the user to the ModItemSector's sector ID.
---
--- @param self ModItemSector The ModItemSector object.
--- @param ged EditorGUI The EditorGUI object.
function ModItemSector:TestModItem(ged)
	if self:GetError() then
		ged:ShowMessage("Message", "Resolve related errors before testing this mod item.")
		return
	end
	
	local question = ged:WaitQuestion(
		"Warning", 
		"The test will create a new game campaign and teleport you to the created map.\nAny unsaved changes will be lost. Do you want to continue?", 
		"Yes", 
		"No")
	if question == "ok" then
		CreateRealTimeThread(function()
			ProtectedModsReloadItems(nil, "force_reload")
			QuickStartCampaign(self.campaignId, {difficulty = "Normal"}, self.sectorId)
		end)
	end
end

--- Called when the ModItemSector is loaded. Performs the following actions:
---
--- 1. Calls the `PostLoad()` function to perform any post-load initialization.
--- 2. Adds the ModItemSector to the current campaign.
--- 3. Calls the `OnModLoad()` function of the base `ModItem` class.
function ModItemSector:OnModLoad()
	self:PostLoad()
	self:AddToCampaign()
	ModItem.OnModLoad(self)
end

---
--- Called when the ModItemSector is unloaded. Performs the following actions:
---
--- 1. Removes the ModItemSector from the current campaign.
--- 2. Calls the `OnModUnload()` function of the base `ModItem` class.
function ModItemSector:OnModUnload()
	self:RemoveFromCampaign()
	ModItem.OnModUnload(self)
end


---
--- Creates a new SatelliteSector object, either by cloning an existing one or creating a new one.
---
--- @param cloneFrom SatelliteSector The SatelliteSector object to clone from, or nil to create a new one.
--- @return SatelliteSector The created SatelliteSector object.
---
function ModItemSector:CreateSatelliteSector(cloneFrom)
	local satObj = cloneFrom and cloneFrom:Clone() or SatelliteSector:new()
	satObj.generated = false
	satObj.modId = self.mod.id
	satObj.bidirectionalRoadApply = true
	satObj.bidirectionalBlockApply = true
	self.SatelliteSectorObj = satObj
	ParentTableModified(satObj, self, "recursive")
	self:PostLoad()
end

---
--- Cleans up the session data for a given sector and campaign.
---
--- If the current game's campaign matches the provided campaign ID, this function will:
--- 1. Delete the session campaign object for the given sector ID using `DeleteSessionCampaignObject`.
--- 2. Create a new session campaign object for the sector using the corresponding sector data from the campaign preset, and add it to the `gv_Sectors` table using `CreateSessionCampaignObject`.
---
--- @param sectorId string The ID of the sector to clean up.
--- @param campaignId string The ID of the campaign to clean up.
---
function ModItemSector:CleanSessionData(sectorId, campaignId)
	if next(gv_Sectors) and Game and Game.Campaign == campaignId then
		DeleteSessionCampaignObject({ Id = sectorId }, SatelliteSector, gv_Sectors)
		CreateSessionCampaignObject(table.find_value(CampaignPresets[campaignId].Sectors, "Id", sectorId), SatelliteSector, gv_Sectors, "Sectors")
	end
end

if FirstLoad then
	OriginalSatSectorsReplaced = {}
end

---
--- Adds the ModItemSector to the current campaign.
---
--- If the sector ID and campaign ID are set, this function will:
--- 1. Check if the sector already exists in the campaign preset. If so, it will replace the existing sector with the ModItemSector's SatelliteSectorObj, or update the existing sector's properties.
--- 2. If the sector does not exist, it will add the ModItemSector's SatelliteSectorObj to the campaign preset's Sectors table.
--- 3. It will then call the RoundOutSectors() function on the campaign preset to ensure the sector list is valid.
---
--- @function ModItemSector:AddToCampaign
--- @return nil
function ModItemSector:AddToCampaign()
	if not self.sectorId or not self.campaignId then return end -- the user hasn't filled in the campaign/sector yet
	
	local campaignPreset = CampaignPresets[self.campaignId]
	if not campaignPreset then return end

	local existingSectorIdx = table.find(campaignPreset.Sectors or empty_table, "Id", self.sectorId)
	if existingSectorIdx then
		if self.campaignId == "HotDiamonds" and not campaignPreset.Sectors[existingSectorIdx].modId then
			--before replacing original sat sectors - save them in case we remove the moditems replacing them.
			OriginalSatSectorsReplaced[self.sectorId] = campaignPreset.Sectors[existingSectorIdx]:Clone()
		end
	
		if self.SatelliteSectorObj then
			campaignPreset.Sectors[existingSectorIdx] = self.SatelliteSectorObj
		else
			local existingSector = campaignPreset.Sectors[existingSectorIdx]
			existingSector.modId = self.mod.id
			existingSector.Map = self:GetMapName()
			existingSector.Id = self.sectorId
		end
	elseif self.SatelliteSectorObj then
		campaignPreset.Sectors = table.create_add(campaignPreset.Sectors, self.SatelliteSectorObj)
	else
		campaignPreset.Sectors = table.create_add(
			campaignPreset.Sectors,
			SatelliteSector:new{
				template_key = "Sectors",
				Map = self:GetMapName(),
				Id = self.sectorId,
				modId = self.mod.id,
				generated = false
			}
		)
	end
	campaignPreset:RoundOutSectors()
end

---
--- Removes the ModItemSector from the specified campaign.
---
--- If the sector ID and campaign ID are set, this function will:
--- 1. Check if the sector exists in the campaign preset. If so, it will remove the sector from the campaign preset's Sectors table.
--- 2. It will then call the RoundOutSectors() function on the campaign preset to ensure the sector list is valid.
--- 3. If the campaign ID is "HotDiamonds" and the original satellite sector data was saved, it will restore the original satellite sector.
---
--- @param campaignId (optional) The ID of the campaign to remove the sector from. If not provided, it will use the ModItemSector's campaignId.
--- @param sectorId (optional) The ID of the sector to remove. If not provided, it will use the ModItemSector's sectorId.
--- @return nil
function ModItemSector:RemoveFromCampaign(campaignId, sectorId)
	campaignId = campaignId or self.campaignId
	sectorId = sectorId or self.sectorId 

	local campaignPreset = CampaignPresets[campaignId]
	if not campaignPreset then return end
	
	local idx = table.find(campaignPreset.Sectors, "Id", sectorId)
	local satSectorData = campaignPreset.Sectors[idx]
	if satSectorData and satSectorData.modId then
		table.remove(campaignPreset.Sectors, idx)
		campaignPreset:RoundOutSectors()
		self:CleanSessionData(sectorId, campaignId)
		
		if campaignId == "HotDiamonds" and OriginalSatSectorsReplaced[sectorId] then
			--restore original sat sector
			local idx = table.find(campaignPreset.Sectors, "Id", sectorId)
			if idx then
				campaignPreset.Sectors[idx] = OriginalSatSectorsReplaced[sectorId]
			end
		end
	end
end

---
--- Copies the map files from the specified map to the current ModItemSector's map folder.
---
--- If the current ModItemSector has a valid map folder, this function will:
--- 1. Delete all files inside the map folder if there are any.
--- 2. If a mapToCopy is specified, it will copy all the files from the original map folder to the current ModItemSector's map folder.
--- 3. If the current map is the same as the ModItemSector's map, it will force a map reload.
---
--- @param mapToCopy (optional) The name of the map to copy files from. If not provided, no files will be copied.
--- @param ged The GameEditorData object.
--- @return nil
function ModItemSector:CopyMapFiles(mapToCopy, ged)
	if not mapToCopy or mapToCopy == "" then
		return
	end	
	
	local folderPath = self:GetFolderPathOS()
	if not io.exists(folderPath) then
		return
	end
	
	local originalMapDataPreset = mapToCopy and MapData[mapToCopy]
	local originalMapFolder = mapToCopy and originalMapDataPreset and originalMapDataPreset:GetSaveFolder()

	--delete all files inside if there are any
	local err, oldMapFiles = AsyncListFiles(folderPath, '*', 'recursive')
	if not err and folderPath ~= originalMapFolder then
		for _, mapFile in ipairs(oldMapFiles) do
			AsyncDeletePath(ConvertToOSPath(mapFile))
		end
	end
	
	if mapToCopy then
		if not io.exists(originalMapFolder .. "mapdata.lua") then -- the original map is not mounted
			err = MountMap(originalMapDataPreset.id)
			if err then
				ModLogF(true, "Failed to mount map %s. Reason: %s", originalMapDataPreset.id, err)
			else
				--err = AsyncUnpack(string.format("Packs/Maps/%s.hpk", originalMapDataPreset.id), folderPath)
				--if err then print(err) end
			end
		end
		
		-- copy files from the original map
		local mapFiles
		err, mapFiles = AsyncListFiles(originalMapFolder)
		
		if err or not originalMapFolder then
			ged:ShowMessage("Message", "Unable to copy the map data - an empty map will be created.")
			self:CopyMapFiles("EmptyMap", ged)
			return
		end
		
		for _, mapFile in ipairs(mapFiles) do
			local dir, file, ext = SplitPath(mapFile)
			err = AsyncCopyFile(mapFile, folderPath .. file .. ext, "raw")
			if err then
				ModLogF(true, "Failed to copy file: %s. Reason: %s", mapFile, err)
			end
		end
	end
	
	if CurrentMap == self:GetMapName() then
		ChangeMap(CurrentMap) -- force reload map if currently loaded
	end
end

--- Creates a new folder for the ModItemSector.
-- This function creates a new folder on the file system for the ModItemSector. The path of the new folder is determined by the `GetFolderPathOS()` function.
-- @function ModItemSector:CreateMapFolder
-- @return nil
function ModItemSector:CreateMapFolder()
	local newPathInMod = self:GetFolderPathOS()
	AsyncCreatePath(newPathInMod)
end

--- Deletes the map folder associated with the ModItemSector.
-- This function deletes the map folder associated with the ModItemSector. It first checks if a map data preset exists for the map name, and if so, deletes it. It then deletes the map folder path using AsyncDeletePath.
-- @function ModItemSector:DeleteMapFolder
-- @return nil
function ModItemSector:DeleteMapFolder()
	local mapName = self:GetMapName()
	local mapDataPreset = MapData[mapName]
	if mapDataPreset then
		mapDataPreset:delete()
	end
	local mapFolderPath = self:GetFolderPathOS()
	AsyncDeletePath(mapFolderPath)
end

--- Deletes the map folder associated with the ModItemSector.
-- This function is called when the ModItemSector is deleted from the editor. It first checks if the current map is the map associated with this ModItemSector, and if so, stops the modding editor and returns to the mod map. It then deletes the map folder associated with this ModItemSector by calling the `DeleteMapFolder()` function, and removes the ModItemSector from the campaign by calling the `RemoveFromCampaign()` function.
-- @function ModItemSector:OnEditorDelete
-- @param mod the mod object
-- @param ged the game editor object
-- @return nil
function ModItemSector:OnEditorDelete(mod, ged)
	if self.sectorId and self.campaignId and self:GetMapName() == CurrentMap then
		editor.StopModdingEditor("return to mod map")
	end
	self:DeleteMapFolder()
	self:RemoveFromCampaign()
end

---
--- Copies the satellite sector data for the current ModItemSector.
---
--- If a `copyFrom` parameter is provided, it will copy the data from the specified map. Otherwise, it will try to find the satellite sector data for the current `sectorId` in the campaign preset.
---
--- If the satellite sector data is found, it creates a new `SatelliteSectorObj` and sets its `Id` and `Map` properties. It then marks the `root` object and the current `ModItemSector` as modified.
---
--- @param ged The game editor object.
--- @param copyFrom (optional) The name of the map to copy the satellite sector data from.
--- @return The name of the map that was copied, or `nil` if an error occurred.
function ModItemSector:CopySatelliteSectorData(ged, copyFrom)
	local campaignPreset = CampaignPresets[self.campaignId]
	local satelliteSectorData
	if copyFrom then
		satelliteSectorData = table.find_value(campaignPreset.Sectors, "Map", copyFrom)
		if not satelliteSectorData then
			return copyFrom
		end
	else
		satelliteSectorData = table.find_value(campaignPreset.Sectors, "Id", self.sectorId)
		if not satelliteSectorData then
			ged:ShowMessage("Message", string.format("Unable to copy satellite sector data of %s", self.sectorId))
			return 
		end
	end
	
	self:CreateSatelliteSector(satelliteSectorData)
	
	self.SatelliteSectorObj.Id = self.sectorId
	self.SatelliteSectorObj.Map = self:GetMapName()
	ObjModified(ged:ResolveObj("root"))
	ObjModified(self)
	return satelliteSectorData and satelliteSectorData.Map
end

---
--- Updates the campaign sector data for the ModItemSector.
---
--- This function is called when the campaign ID or sector ID of the ModItemSector is changed. It performs the following actions:
---
--- 1. If the campaign ID is changed, it removes the ModItemSector from the old campaign and sets the sector ID and satellite sector object to false if the new campaign ID is nil.
--- 2. If the sector ID is changed, it removes the ModItemSector from the old campaign and sets the satellite sector object to false if the new sector ID is nil.
--- 3. If the property should not be hidden, it checks if the sector exists in the campaign. If not, it prompts the user to either copy an existing map or create an empty map.
--- 4. If the map already exists, it prompts the user to either overwrite the existing map or just update the campaign ID or sector ID.
--- 5. Finally, it calls the `UpdateSectorData()` function to update the mod item ID, map, and rename the map folder and ID in the `mapdata.lua` file.
---
--- @param prop_id the property ID that was changed
--- @param old_value the old value of the property
--- @param ged the game editor object
--- @return nil
function ModItemSector:UpdateCampaignSector(prop_id, old_value, ged)
	local newValue = self[prop_id]

	if prop_id == "campaignId" and old_value then
		self:RemoveFromCampaign(old_value, self.sectorId)
		if not newValue then
			self.sectorId = false
			self.SatelliteSectorObj = false
		end
	elseif prop_id == "sectorId" and old_value then
		self:RemoveFromCampaign(self.campaignId, old_value)
		if not newValue then
			self.SatelliteSectorObj = false
		end
	end
	
	
	if self:ShouldHideProp() then return end
	
	local isMapFound = DoesSectorExist(self.campaignId, self.sectorId)
	
	if not old_value and (not self.SatelliteSectorObj or not self.SatelliteSectorObj.Map) then --1. first time selecting sector 
		if isMapFound then --1.1. found map
			local res = ged:WaitQuestion(
				"Copy Map",
				string.format("Copy the existing map of %s?", self.sectorId),
				"Yes",
				"No, add an empty map"
			)
			
			if res == "ok" then --1.1.1. copy existing map
				local mapName = self:CopySatelliteSectorData(ged)
				self:CopyMapFiles(mapName, ged)
			else --1.1.2. create empty map
				self:CopyMapFiles("EmptyMap", ged)
				self:CreateSatelliteSector()
			end
		else --1.2 existing map not found
			local mapToCopy = ged:WaitListChoice(GetAllGameMaps(), "Copy an existing sector map?")
			if mapToCopy then --1.2.1. copy from existing map
				local mapName = self:CopySatelliteSectorData(ged, mapToCopy)
				self:CopyMapFiles(mapName, ged)
			else --1.2.2. create empty map
				self:CopyMapFiles("EmptyMap", ged)
				self:CreateSatelliteSector()
			end
		end
	else --2. map already created, but user wants to change campaignId or sectorId
		if isMapFound then --2.1. found existing map
			local res = ged:WaitQuestion(
				"Copy Map",
				string.format("Copy the existing map of '%s'? This will overwrite the current map and satellite sector data.", self.campaignId .. "_" .. self.sectorId),
				"Yes, overwrite",
				string.format("No, just update %s to %s", prop_id, newValue)
			)
			
			if res == "ok" then --2.1.1. copy from existing map and override all exisitng data so far
				local mapName = self:CopySatelliteSectorData(ged)
				self:CopyMapFiles(mapName, ged)
			end
		end
	end
	self:UpdateSectorData(self.campaignId, self.sectorId, old_value, prop_id)
end

--- Updates the mod item id, map and renames the map folder and the id in mapdata.lua
---
--- Updates the sector data, including the map name and ID, for a ModItemSector object.
---
--- @param newCampaignId string The new campaign ID for the sector.
--- @param newSectorId string The new sector ID for the sector.
--- @param oldVal any The old value of the property being updated.
--- @param propId string The ID of the property being updated.
---
function ModItemSector:UpdateSectorData(newCampaignId, newSectorId, oldVal, propId)
	local newValue = self[propId]
		
	if self.SatelliteSectorObj then
		self.SatelliteSectorObj.Id = self.sectorId
		self.SatelliteSectorObj.Map = self:GetMapName()
	
		if self.SatelliteSectorObj.Id and self.SatelliteSectorObj.Id:ends_with("_Underground") then
			self.SatelliteSectorObj.GroundSector = self.SatelliteSectorObj.Id:gsub("_Underground", "")
		else
			self.SatelliteSectorObj.GroundSector = false
		end
	end
	
	local mapData
	local fenv = LuaValueEnv{
		DefineMapData = function(data)
			local mapName = self:GetMapName()
			local mapDataPreset = MapData[mapName]
			if mapDataPreset then
				mapDataPreset:delete()
			end
			 mapData = MapDataPreset:new(data)
		end,
	}
	
	if newValue then
		local ok, def = pdofile(self:GetFolderPathOS() .. "mapdata.lua", fenv)
		if ok then
			local newId = self:GetMapName()
			local newModMapPath = self:GetFolderPathOS()
			
			mapData.id = newId
			mapData.ModMapPath = newModMapPath
			mapData.Comment = string.format("Sector %s (%s)", self.sectorId, self.campaignId) -- for MapData editor
			mapData.DisplayName = Untranslated(mapData.Comment) -- for display in the editor's status bar
			self:CleanDevPropsFromMapData(mapData)
			mapData:Register()
			mapData:PostLoad()
			mapData:Save()
		end
	end
	ObjModified(self)
	ObjModified(self.SatelliteSectorObj)
end

--- Removes development-related properties from the provided MapData object.
---
--- This function is used to clean up the MapData object before registering and saving it.
---
--- @param data MapData The MapData object to clean up.
function ModItemSector:CleanDevPropsFromMapData(data)
	data.Author = nil
	data.ScriptingAuthor = nil
	data.Status = nil
	data.SoundStatus = nil
	data.ScriptingStatus = nil
	data.SaveEntityList = nil
end

--- Checks if a sector with the given campaign ID and sector ID already exists in the mod.
---
--- @param campaignId string The campaign ID to check for.
--- @param sectorId string The sector ID to check for.
--- @param mod ModItemBase The mod to check in. Defaults to the current mod.
--- @return boolean|string True if no duplicate is found, or a string error message if a duplicate is found.
function ModItemSector:IsDuplicateMap(campaignId, sectorId, mod)
	mod = mod or self.mod
	if not campaignId or not sectorId then return false end
	return mod:ForEachModItem("ModItemSector", function(mod_item)
		if mod_item ~= self and mod_item.campaignId == campaignId and mod_item.sectorId == sectorId then
			return string.format("The sector %s for campaign %s already exists in your mod!", sectorId, campaignId)
		end
	end)
end

--- Returns a table of affected resources for the current ModItemSector.
---
--- This function checks if the current ModItemSector belongs to the "HotDiamonds" campaign and has a sector ID that starts with a capital letter followed by a number. If so, it creates a new ModResourcePreset object with the campaign ID, sector ID, class, and editor name, and returns it in a table.
---
--- @return table The table of affected resources for the current ModItemSector.
function ModItemSector:GetAffectedResources()
	if self.campaignId and self.sectorId and self.campaignId == "HotDiamonds" and string.find(self.sectorId, "^[A-Z][0-9]+") then
		local affected_resources = {}
		table.insert(affected_resources, ModResourcePreset:new({
			mod = self.mod,
			Class = self.class,
			Id = string.format("%s_%s", self.campaignId, self.sectorId),
			ClassDisplayName = self.EditorName,
		}))
		
		return affected_resources
	end
	
	return empty_table
end

---
--- Applies bi-directional links for the roads and block travel properties of the satellite sector object associated with this `ModItemSector` instance.
---
--- If the `SatelliteSectorObj` has the `bidirectionalRoadApply` property set, this function will call `SatelliteSectorSetDirectionsProp` with the "Roads" property and the "session_update_only" mode.
---
--- If the `SatelliteSectorObj` has the `bidirectionalBlockApply` property set, this function will call `SatelliteSectorSetDirectionsProp` with the "BlockTravel" property and the "session_update_only" mode.
---
function ModItemSector:ApplyBiDirectionalLinks()
	if self.SatelliteSectorObj and self.SatelliteSectorObj.bidirectionalRoadApply then
		SatelliteSectorSetDirectionsProp(self.SatelliteSectorObj, "Roads", "session_update_only")
	end
	
	if self.SatelliteSectorObj and self.SatelliteSectorObj.bidirectionalBlockApply then
		SatelliteSectorSetDirectionsProp(self.SatelliteSectorObj, "BlockTravel", "session_update_only")
	end
end

--loading save or starting new game will apply all bidirectional links after the gv_Sectors have been created
function OnMsg.PreLoadSessionData()
	ModsApplyBiDirectionalLinks()
end

function OnMsg.InitSessionCampaignObjects()
	ModsApplyBiDirectionalLinks()
end

--------------------------------------------
-------------Helper functions---------------
--------------------------------------------

---
--- Applies bi-directional links for the roads and block travel properties of the satellite sector objects associated with all ModItemSector instances in the ModsLoaded table.
---
--- If a ModItemSector's SatelliteSectorObj has the `bidirectionalRoadApply` property set, this function will call `SatelliteSectorSetDirectionsProp` with the "Roads" property and the "session_update_only" mode.
---
--- If a ModItemSector's SatelliteSectorObj has the `bidirectionalBlockApply` property set, this function will call `SatelliteSectorSetDirectionsProp` with the "BlockTravel" property and the "session_update_only" mode.
---
--- This function is called in the `OnMsg.PreLoadSessionData` and `OnMsg.InitSessionCampaignObjects` events to apply the bi-directional links after the gv_Sectors have been created.
---
function ModsApplyBiDirectionalLinks()
	for _, mod in ipairs(ModsLoaded) do
		mod:ForEachModItem("ModItemSector", function(item)
			item:ApplyBiDirectionalLinks()
		end)
	end
end

---
--- Gets a list of all satellite sector IDs in the current campaign.
---
--- @param obj ModItemSector The ModItemSector instance to get the campaign sectors for.
--- @return table A table of sector ID information, with each entry containing the following fields:
---   - value: The sector ID string
---   - name: The sector ID string
---   - combo_text: The sector ID string with additional information about the sector, formatted for display in a combo box.
---
function GetCampaignSectorsIds(obj)
	local sectors = GetSatelliteSectors(nil, CampaignPresets[obj.campaignId])
	local sectorIdsCombo = {}
	for _, sector in ipairs(sectors) do
		local id = sector.Id
		local emptyText = sector.generated and "(empty)" or ""
		local noMap = not MapData[sector.Map] and "(no map)" or ""
		table.insert(sectorIdsCombo, { value = id, name = id, combo_text = string.format("%s<right><alpha 156>\t%s %s", id, emptyText, noMap) })
	end
	return sectorIdsCombo
end

---
--- Checks if a sector with the given campaign ID and sector ID exists in the game.
---
--- @param campaignId string The ID of the campaign to check for the sector.
--- @param sectorId string The ID of the sector to check.
--- @return boolean|string If the sector exists, returns the map name for the sector. If the sector does not exist, returns `false`.
---
function DoesSectorExist(campaignId, sectorId)
	local campaignPreset = campaignId and CampaignPresets[campaignId]
	local foundSector = campaignPreset and table.find_value(campaignPreset.Sectors, "Id", sectorId)
	if foundSector and foundSector.Map and foundSector.Map ~= "" then
		return foundSector.Map
	else
		return false
	end
end

---
--- Validates a sector ID string to ensure it follows the expected format.
---
--- @param value string The sector ID string to validate.
--- @param allow_underground boolean If true, allows the sector ID to have an "_Underground" suffix.
--- @return boolean|string If the sector ID is valid, returns true. If the sector ID is invalid, returns an error message describing the expected format.
---
function ValidateSectorId(value, allow_underground)
	local normal_match = string.match(value, "^%u%u?%-?%d%d?$")
	local underground_match = string.match(value, "^%u%u?%-?%d%d?_Underground$")
	return not (normal_match or allow_underground and underground_match) and
		string.format("Sector ID format is incorrect. It needs to follow the pattern:\n'[upper case sector letter][optional upper case sector letter to indicate going into negatives in the grid][optional symbol '-' to indicate going into negatives in the grid][digit][optional digit]%s'",
			allow_underground and "[optional symbols '_Underground']" or "")
end

---
--- Gets a list of files in the folder associated with this ModItemSector instance.
---
--- @return table A list of file paths for the files in the folder associated with this ModItemSector instance.
---
function ModItemSector:GetFilesList()
	local path = self:GetFolderPathOS()
	local files_list = io.listfiles(path, "*")
	return files_list
end

---
--- Resolves any conflicts that may arise when pasting a satellite sector into the mod.
---
--- @param ged table The GUI event dispatcher object.
--- @param skip_msg boolean If true, skips displaying any conflict resolution messages.
--- @return boolean True if the sector conflict was resolved successfully, false otherwise.
---
function ModItemSector:ResolveSectorConflictOnPaste(ged, skip_msg)
	local mod = self.mod
	
	local dup = self:IsDuplicateMap(self.campaignId, self.sectorId, mod)
	local initial_sector = self.sectorId
	if dup then
		local sectorList = GetCampaignSectorsIds(self)
		local association_list = {}
		local trimmed_sectors = {}
		for _, sector_combo in ipairs(sectorList) do
			association_list[sector_combo.combo_text] = sector_combo
			table.insert(trimmed_sectors, sector_combo.combo_text)
		end
		
		if not skip_msg  and CanYield() then
			while dup do
				local confirm_text = dup .. "\n\nDo you want to change the copy to another sector?"
				local response = ged:WaitQuestion("Paste Satellite Sector", confirm_text, "Change sector", "Cancel")
				if response == "cancel" then
					return false
				else
					local new_sector = ged:WaitListChoice(trimmed_sectors, "Pick sector:")
					if new_sector == "cancel" or not new_sector then return false end
					self.sectorId = association_list[new_sector].value
					self.ChangedSectorOnPaste = initial_sector
					dup = self:IsDuplicateMap(self.campaignId, self.sectorId, mod)
				end
			end
		else
			return false
		end
	end
	return true
end

---
--- Resolves any conflicts that may arise when pasting a satellite sector into the mod.
---
--- @param ged table The GUI event dispatcher object.
--- @return table A table containing the previous sector ID, or nil if the paste was cancelled.
---
function ModItemSector:ResolvePasteFilesConflicts(ged)
	if not self.CopyFiles then return end
	
	local prev_sector = self.sectorId
	
	-- pick new folder name
	local existing_sectors = {}
	self.mod:ForEachModItem("ModItemSector", function(mod_item)
		existing_sectors[mod_item.mapName] = mod_item
	end)
	while existing_sectors[self.mapName] and existing_sectors[self.mapName] ~= self do
		self:GenerateMapName()
	end
	self:CreateMapFolder()
	
	-- resolve duplicate sector (either user picks valid one, or the paste file data are cleared
	local res = self:ResolveSectorConflictOnPaste(ged, false)
	if not res then
		self.sectorId = false
		self.SatelliteSectorObj = false
		self.CopyFiles = false
		ModLogF(string.format("Satellite Sector <%s> already exists in mod <%s>! Created empty sector, instead.", prev_sector, self.mod.id))
		self.CopyFiles = {}
		return
	end
	
	local firstfilename = self.CopyFiles[1].filename
	local prev_os_path = firstfilename:match("^(" .. self.CopyFiles.mod_content_path .. "Maps/[^/]*/)")
	for _, file in ipairs(self.CopyFiles) do
		file.filename = file.filename:gsub(prev_os_path, self:GetFolderPathOS())
	end
	
	if self.ChangedSectorOnPaste  then
		prev_sector = self.ChangedSectorOnPaste
		self.ChangedSectorOnPaste = nil
	end
	
	return { prev_sector = prev_sector }
end

---
--- Called after files have been pasted into the mod.
--- Updates the sector data for the pasted sector.
---
--- @param changes_meta table A table containing the previous sector ID, or nil if the paste was cancelled.
---
function ModItemSector:OnAfterPasteFiles(changes_meta)
	local prev_sector = changes_meta and changes_meta.prev_sector or self.sectorId
	self:UpdateSectorData(self.campaignId, self.sectorId, prev_sector, "sectorId")
end