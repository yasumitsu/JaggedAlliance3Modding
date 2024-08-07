if config.ModdingToolsInUserMode then return end

if FirstLoad then
	LocalStorage.XEditorFindAndReplaceToolMaps = LocalStorage.XEditorFindAndReplaceToolMaps or {}
end

DefineClass.XEditorFindAndReplaceObjects = {
	__parents = { "XEditorTool" },
	
	properties = {
		persisted_setting = true,
		{ id = "FindClass", name = "Find Class", editor = "choice", default = "",
			items = function() return XEditorPlaceableObjectsCombo end,
		},
		{ id = "ReplaceClass", name = "Replace Class", editor = "choice", default = "",
			items = function() return XEditorPlaceableObjectsCombo end,
		},
		{ id = "ScanButton", editor = "buttons", buttons = { { name = "Scan all maps", func = "Scan" } } },
		{ id = "Filter", name = "Map filter", editor = "text", default = "", name_on_top = true,
			persisted_setting = false, translate = false,
		},
		{ id = "Maps", editor = "text_picker", default = empty_table, multiple = true,
		  filter_by_prop = "Filter",
			items = function(self)
				return LocalStorage.XEditorFindAndReplaceToolMaps
			end,
		  virtual_items = true,
		},
		{ id = "ReplaceButton", editor = "buttons", buttons = { { name = "Replace", func = "Replace" } } }
	},
	
	ToolTitle = "Find and replace object",
	Description = {
		"Scans all maps for objects of a class and lets you replace them with a new class.",
	},
	ActionSortKey = "4",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceMultipleObject.tga",
	ActionShortcut = "Ctrl-F",
	ToolSection = "Misc",
}

---
--- Counts the number of occurrences of a pattern in a string.
---
--- @param base string The input string to search.
--- @param pattern string The pattern to search for.
--- @return number The number of occurrences of the pattern in the input string.
function CountSubStr(base, pattern)
	if not base or not pattern then return 0 end

	return select(2, string.gsub(base, pattern, ""))
end

---
--- Cleans up the XEditorFindAndReplaceToolMaps table and saves the local storage when the XEditorFindAndReplaceObjects tool is done.
---
--- This function is called when the XEditorFindAndReplaceObjects tool is finished with its operations. It checks if the "ScanThread" is still running, and if so, it clears the XEditorFindAndReplaceToolMaps table and saves the local storage.
---
--- @function XEditorFindAndReplaceObjects:Done
--- @return nil
function XEditorFindAndReplaceObjects:Done()
	if self:IsThreadRunning("ScanThread") then
		LocalStorage.XEditorFindAndReplaceToolMaps = {}
		SaveLocalStorage()
	end
end

---
--- Scans a map for objects of a given class and adds the map name and count of objects to the XEditorFindAndReplaceToolMaps table.
---
--- @param map_name string The name of the map to scan.
--- @param obj_class string The class of objects to search for.
--- @return nil
function XEditorFindAndReplaceObjects:ScanAndAddMap(map_name, obj_class)
	local maps = LocalStorage.XEditorFindAndReplaceToolMaps
	
	table.insert(maps,
		{
			text = string.format("<left>%s<right>%s", map_name, "Scanning..."),
			value = map_name
		}
	)
	self:SetProperty("Maps", { map_name })
	
	-- Update the UI
	ObjModified(self)

	local err, ini = AsyncFileToString("Maps/" .. map_name .. "/objects.lua")
	local count = CountSubStr(ini, string.format("PlaceObj%%('%s'", obj_class))
	count = count + CountSubStr(ini, string.format("p%%(\"%s\"", obj_class))
	
	if count and count > 0 then
		local last = maps[#maps]
		last.text = string.format("<left>%s<right><color 0 190 255>%s", map_name, count)
		last.count = count
	else
		table.remove(maps, #maps)
	end	
end

---
--- Scans all maps in the game and adds the map name and count of objects of the specified class to the XEditorFindAndReplaceToolMaps table.
---
--- This function is called when the user wants to scan the maps for a specific class of objects. It iterates through all the maps, calls the ScanAndAddMap function for each map, and then sets the Maps property with the last map in the XEditorFindAndReplaceToolMaps table.
---
--- @param self XEditorFindAndReplaceObjects The instance of the XEditorFindAndReplaceObjects class.
--- @param prop_id string The ID of the property that triggered this function.
--- @param socket EditorSocket The socket that triggered this function.
--- @return nil
function XEditorFindAndReplaceObjects:Scan(self, prop_id, socket)
	local obj_class = self:GetProperty("FindClass")
	if not obj_class or obj_class == "" then socket:ShowMessage("Error", "Please select a class to search for.") return end
	
	local maps = ListMaps()
	LocalStorage.XEditorFindAndReplaceToolMaps = {}
	
	self:DeleteThread("ScanThread")
	self:CreateThread("ScanThread", function()
		for _, map_name in ipairs(maps) do
			self:ScanAndAddMap(map_name, obj_class)
		end
		
		local maps_length = #LocalStorage.XEditorFindAndReplaceToolMaps
		if maps_length > 0 then 
			self:SetProperty("Maps", { LocalStorage.XEditorFindAndReplaceToolMaps[maps_length].value })
		else
			self:SetProperty("Maps", {})
		end
		
		ObjModified(self)
		SaveLocalStorage()
	end)	
end

---
--- Replaces all instances of a specified class with a new class in the selected maps.
---
--- This function is called when the user wants to replace all instances of a class with a new class across multiple maps. It first checks if the necessary properties are set, then prompts the user for confirmation before performing the replacement. It iterates through the selected maps, changes the current map if necessary, performs the replacement, saves the map, and updates the UI to reflect the changes.
---
--- @param self XEditorFindAndReplaceObjects The instance of the XEditorFindAndReplaceObjects class.
--- @param prop_id string The ID of the property that triggered this function.
--- @param socket EditorSocket The socket that triggered this function.
--- @return boolean True if the replacement was successful, false otherwise.
function XEditorFindAndReplaceObjects:Replace(self, prop_id, socket)
	local chosen_maps = self:GetProperty("Maps")
	local maps_length = #chosen_maps
	
	local old_class = self:GetProperty("FindClass")
	local replace_class = self:GetProperty("ReplaceClass")
	
	if not chosen_maps or type(chosen_maps) ~= "table" or #chosen_maps == 0 then socket:ShowMessage("Error", "Please select map(s).") return end
	if not old_class or old_class == "" or not replace_class or replace_class == "" then socket:ShowMessage("Error", "Please select a class to search for and a class to replace with.") return end
	
	local others_text = ""
	if maps_length > 1 then
		others_text = string.format(" and %s others", maps_length - 1)
	end
	
	local message = string.format("Loop through the selected maps (%s%s) \nand replace all \"%s\" with \"%s\"?\n\nThe maps will be saved automatically.", chosen_maps[1], others_text, old_class, replace_class)
	if socket:WaitQuestion("Replace All",	message, "Yes", "No") ~= "ok" then
		return false
	end
	
	local changes = #chosen_maps > 0
	if changes and IsEditorActive() then
		EditorDeactivate()
	end
	
	for idx, map_name in ipairs(chosen_maps) do	
		if map_name ~= GetMapName() then
			ChangeMap(map_name)
		end
		
		ReplaceAll(old_class, replace_class)
		SaveMap("no backup")
		
		local map_idx = table.find(LocalStorage.XEditorFindAndReplaceToolMaps, "value", map_name)
		if map_idx then
			local item = LocalStorage.XEditorFindAndReplaceToolMaps[map_idx]
			local done_text = string.format("Done (%d)", item.count)
			
			item.text = string.format("<left>%s<right><color 0 255 30>%s", map_name, done_text)
			ObjModified(self)
			SaveLocalStorage()
		end
	end
	
	if changes and not IsEditorActive() then
		EditorActivate()
	end
end

--- Handles the behavior when the "FindClass" property is set in the XEditorFindAndReplaceObjects.
---
--- If the "FindClass" property is empty, the XEditorFindAndReplaceToolMaps table is cleared and the "Maps" property is set to an empty table.
---
--- If a "FindClass" value is set and there are less than 2 items in the XEditorFindAndReplaceToolMaps table, or a "ScanThread" is currently running, the "ScanThread" is deleted, the XEditorFindAndReplaceToolMaps table is cleared, and the current map name is added to the table.
---
--- The XEditorFindAndReplaceObjects is marked as modified and the LocalStorage is saved.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged any The GED object associated with the property.
function XEditorFindAndReplaceObjects:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id ~= "FindClass" then return end
	
	local value = self:GetProperty("FindClass")
	if not value or value == "" then
		LocalStorage.XEditorFindAndReplaceToolMaps = {}
		self:SetProperty("Maps", {})
	elseif self:IsThreadRunning("ScanThread") or #LocalStorage.XEditorFindAndReplaceToolMaps < 2 then
		self:DeleteThread("ScanThread")
		LocalStorage.XEditorFindAndReplaceToolMaps = {}
		self:ScanAndAddMap(GetMapName(), value)
	end	
	
	ObjModified(self)
	SaveLocalStorage()
end

--- Handles the behavior when a map item is double-clicked in the "Maps" property picker.
---
--- This creates a new "ReplaceThread" thread that calls the `Replace` method with the current object and the socket passed to this method.
---
--- @param prop_id string The ID of the property that was double-clicked.
--- @param item_id any The ID of the item that was double-clicked.
--- @param socket any The socket associated with the double-click event.
function XEditorFindAndReplaceObjects:OnPickerItemDoubleClicked(prop_id, item_id, socket)
	if prop_id ~= "Maps" then return end
	
	-- Thread needed to use socket:WaitQuestion()
	self:CreateThread("ReplaceThread", function()
		self:Replace(self, nil, socket)
	end)
end
