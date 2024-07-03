---
--- Gets the map button with the specified ID.
---
--- @param id string The ID of the map button to retrieve.
--- @return XWindow|nil The map button with the specified ID, or `nil` if not found.
function XEditorGetMapButton(id)
	local buttons = XShortcutsTarget.idMapButtons
	return buttons and buttons[id]
end

---
--- Deletes all map buttons that were previously created.
---
function XEditorDeleteMapButtons()
	local buttons = XShortcutsTarget.idMapButtons
	if buttons then
		buttons:delete()
	end
end

---
--- Creates the map buttons in the XEditor UI.
---
--- This function is responsible for creating the map-related buttons in the XEditor UI, such as the "Open Map" and "Edit Map Data" buttons. It also creates the "Map variations" button if the ModdingToolsInUserMode config is not set.
---
--- The map buttons are created as children of the "idMapButtons" window, which is docked to the left side of the "idStatusBox" window.
---
--- @function XEditorCreateMapButtons
--- @return nil
function XEditorCreateMapButtons()
	XEditorDeleteMapButtons()
	
	local button_parent = XWindow:new({ IdNode = true, Id = "idMapButtons", Dock = "left" }, XShortcutsTarget.idStatusBox)
	
	-- Open map button
	local button = XTemplateSpawn("XEditorMapButton", button_parent)
	button:SetRolloverText("Open Map (F5)")
	button:SetIcon("CommonAssets/UI/Editor/Tools/ChangeMap")
	button.OnPress = function() XEditorChooseAndChangeMap() end
	
	-- Edit map data button
	local button = XTemplateSpawn("XEditorMapButton", button_parent)
	button:SetRolloverText("Edit Map Data")
	button:SetIcon("CommonAssets/UI/Editor/Tools/EditMapData")
	button.OnPress = function() mapdata:OpenEditor() end
	
	-- Map variations button
	if not config.ModdingToolsInUserMode then
		local button = XTemplateSpawn("XEditorMapButton", button_parent)
		button:SetId("idMapVariationsButton")
		button:SetRolloverAnchor("right")
		button:SetRolloverText("Map variations...")
		button:SetImage("CommonAssets/UI/Editor/ManageMapVariationButton")
		button:SetRows(2)
		button:SetRow(EditedMapVariation and 1 or 2)
		button:SetColumnsUse("abba")
		button:SetBackground(nil)
		button:SetRolloverBackground(nil)
		button:SetPressedBackground(nil)
		button.OnPress = function() XEditorOpenMapVariationsPopup() end
	end
	
	Msg("XWindowRecreated", button_parent)
end
