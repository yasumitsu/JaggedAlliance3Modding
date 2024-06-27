local l_PreviousOpacities = {}
local l_PreviousInvisibleObjectHelpersEnabled = false
local l_PreviousVisibilities = {}

-- Show a selected object(s) without it's selection markers (outlines, contours, etc)
-- Override in game code for game-specific changes
---
--- Shows the selected object(s) without their selection markers (outlines, contours, etc).
--- This function is intended to be overridden in game-specific code for any game-specific changes.
---
--- @param current_selection table The list of objects to show without selection markers
---
function ShowWithoutSelectionMarkers(current_selection)
	for _, obj in ipairs(current_selection) do
		local parentObj = obj:GetParent()
		while parentObj do
			GameToolsShowObject(parentObj)
			parentObj = parentObj:GetParent()
		end
		GameToolsShowObject(obj)
	end
end

-- Restore (re-show) the selection markers of the selection object(s)
-- Override in game code for game-specific changes
---
--- Restores the selection markers (e.g. outlines, contours) of the given selection of objects.
--- This function is intended to be overridden in game-specific code for any game-specific changes.
---
--- @param current_selection table The list of objects to restore their selection markers
---
function RestoreSelectionMarkers(current_selection)
	if IsEditorActive() then
		for _, obj in ipairs(current_selection) do
			-- Show the editor handles of Light objects
			if IsKindOf(obj, "Light") then
				local opacity = l_PreviousOpacities[obj] or 100
				obj:SetOpacity(opacity)
			elseif IsKindOf(obj, "DecorStateFXObjectNoSound") then
				local visible = l_PreviousVisibilities[obj]
				if visible and visible > 0 then
					obj:SetEnumFlags(const.efVisible)
				end
			end
		end
	end
end

---
--- Returns the current selection of objects to be used for the isolated object screenshot.
--- If the editor is active, it returns the editor's selection. Otherwise, it returns the game's selection.
---
--- @return table The list of objects to be used for the isolated object screenshot
---
function GetIsolatedObjectScreenshotSelection()
	local is_editor = IsEditorActive()
	return is_editor and editor.GetSel() or Selection
end

-- Takes a screenshot of only the selected object(s) on black background
---
--- Takes a screenshot of only the selected object(s) on a black background.
---
--- This function is responsible for capturing a screenshot of the currently selected object(s) in isolation, with a black background. It handles various tasks such as:
--- - Checking if the editor is active and getting the appropriate selection
--- - Temporarily disabling certain rendering features to create a clean black background
--- - Hiding all objects except the selected ones
--- - Removing selection markers and editor highlights from the selected objects
--- - Locking the camera and capturing the screenshot
--- - Restoring the original rendering settings and object visibility
---
--- @param obj table|nil The object to capture, or nil to capture the current selection
---
function IsolatedObjectScreenshot(obj)
	-- Check if we're in the editor (or in-game)
	local is_editor = IsEditorActive()
	local selection = obj and { obj } or GetIsolatedObjectScreenshotSelection()
	if #(selection or "") == 0  then return end
	
	CreateRealTimeThread(function()
		local time_factor = GetTimeFactor()
		-- Stop the game time to avoid objects moving out of place
		SetTimeFactor(0)
		
		local isolated_features_off = {
			RenderBillboards = 0,
			RenderTerrain = 0,
			RenderSky = 0, -- Black sky and black horizon fog
			AutoExposureMode = 0, -- AutoExposure will cause the object to turn white when on a black background
			RenderClutter = 0,
			RenderRain = 0
		}

		table.change(hr, "IsolatedObjectScreenshot", isolated_features_off)
		
		PauseInfiniteLoopDetection("IsolatedObjectScreenshot")
		
		Msg("PreIsolatedObjectScreenshot")
		
		-- Hide all objects
		SuspendPassEdits("IsolatedObjectScreenshot", true)
		MapForEach("map", "attached", false, "CObject", nil, const.efVisible, function(obj)
			if not editor.HiddenManually[obj] then
				editor.HiddenManually[obj] = true
				GameToolsHideObject(obj)
			end
		end)
		
		local current_selection = table.copy(selection, not "deep")
		
		ShowWithoutSelectionMarkers(current_selection)
		
		if is_editor then
			-- Hide InvisibleObjects' helpers
			l_PreviousInvisibleObjectHelpersEnabled = InvisibleObjectHelpersEnabled
			SetInvisibleObjectHelpersEnabled(false)
		
			table.clear(l_PreviousOpacities)
			table.clear(l_PreviousVisibilities)
			
			for _, obj in ipairs(current_selection) do
				-- Remove the editor selection boxes and mouse hover highlight
				obj:ClearHierarchyGameFlags(const.gofEditorSelection | const.gofEditorHighlight)
				-- Hide the editor handles of Light objects
				if IsKindOf(obj, "Light") then
					l_PreviousOpacities[obj] = obj:GetOpacity()
					obj:SetOpacity(0)
				elseif IsKindOf(obj, "DecorStateFXObjectNoSound") then
					l_PreviousVisibilities[obj] = obj:GetEnumFlags(const.efVisible)
					obj:ClearEnumFlags(const.efVisible)
				end
			end
		end
		
		-- Hide lightmodel stars
		SetSceneParam(1, "StarsIntensity", 0)
		SetSceneParam(1, "StarsBlueTint", 0)
		SetSceneParam(1, "MilkyWayIntensity", 0)
		SetSceneParam(1, "MilkyWayBlueTint", 0)
		
		LockCamera("IsolatedObjectScreenshot")
		
		-- Wait a few frames for the renderer to apply the changes
		WaitNextFrame(5)
		
		local prefix = "SSAA"
		if #current_selection == 1 then
			prefix = prefix .. "_" .. current_selection[1].class .. "_"
		end
		local filename = GenerateScreenshotFilename(prefix, "AppData/")
		MovieWriteScreenshot(filename, 0, 64, false)
		print(filename)

		SetTimeFactor(time_factor)
		UnlockCamera("IsolatedObjectScreenshot")
		
		-- Restore renderer settings
		table.restore(hr, "IsolatedObjectScreenshot")
		
		-- Restore InvisibleObjects' helpers
		SetInvisibleObjectHelpersEnabled(l_PreviousInvisibleObjectHelpersEnabled)
		
		-- Restore lightmodel stars
		SetSceneParam(1, "StarsIntensity", CurrentLightmodel[1].stars_intensity)
		SetSceneParam(1, "StarsBlueTint", CurrentLightmodel[1].stars_blue_tint)
		SetSceneParam(1, "MilkyWayIntensity", CurrentLightmodel[1].mw_intensity)
		SetSceneParam(1, "MilkyWayBlueTint", CurrentLightmodel[1].mw_blue_tint)
		
		RestoreSelectionMarkers(current_selection)
		
		-- Show all hidden objects
		local hidden = editor.HiddenManually
		editor.HiddenManually = setmetatable({}, weak_keys_meta)
		for obj in pairs(hidden) do
			GameToolsShowObject(obj)
		end
		ResumePassEdits("IsolatedObjectScreenshot", true)
		
		ResumeInfiniteLoopDetection("IsolatedObjectScreenshot")
		
		if is_editor then
			editor.ClearSel()
			for _, obj in ipairs(current_selection) do
				-- Reselect the previous selections
				editor.AddObjToSel(obj)
			end
		end
		
		Msg("PostIsolatedObjectScreenshot")
	end)
end
