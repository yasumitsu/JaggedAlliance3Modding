--- Defines a class for minimap objects.
---
--- The `MinimapObject` class is used to represent objects that are displayed on the game's minimap.
--- It has various properties that control the appearance and behavior of the minimap icon, such as the icon
--- image, color, size, and whether it rotates or not.
---
--- @class MinimapObject
--- @field minimap_icon string The filename of the icon image to be displayed on the minimap.
--- @field minimap_icon_ping string The filename of the icon image to be displayed when the object is "pinged" on the minimap.
--- @field minimap_icon_color table The color of the minimap icon.
--- @field minimap_icon_flags number Flags that control the behavior of the minimap icon.
--- @field minimap_icon_desaturation number The desaturation level of the minimap icon.
--- @field minimap_icon_zorder number The z-order of the minimap icon, used for sorting.
--- @field minimap_size number The size of the minimap icon.
--- @field minimap_color table The color of the minimap object.
--- @field minimap_arrow_icon string The filename of the arrow icon image to be displayed on the minimap.
--- @field minimap_arrow_icon_flags number Flags that control the behavior of the minimap arrow icon.
--- @field minimap_arrow_icon_color table The color of the minimap arrow icon.
--- @field minimap_rollover boolean Whether the minimap icon should display a rollover effect.
DefineClass.MinimapObject = 
{
	__parents = { "CObject" },
	minimap_icon = "",
	minimap_icon_ping = "",
	minimap_icon_color = const.clrWhite,
	minimap_icon_flags = 0,
	minimap_icon_desaturation = -1,
	minimap_icon_zorder = 0, -- no sorting
	minimap_size = 5000,
	minimap_color = const.clrWhite,
	minimap_arrow_icon = "",
	minimap_arrow_icon_flags = const.mifRotates,
	minimap_arrow_icon_color = const.clrWhite,
	minimap_rollover = false,
}

--- Returns whether the minimap icon for this object is visible on the minimap.
---
--- This function checks if the `minimap_icon` property of the `MinimapObject` is not an empty string. If it is not empty, the minimap icon for this object will be displayed on the minimap.
---
--- @return boolean Whether the minimap icon for this object is visible on the minimap.
function MinimapObject:VisibleOnMinimap()
	return self.minimap_icon ~= ""
end

--- Returns whether the minimap arrow icon for this object is visible on the minimap.
---
--- This function checks if the `minimap_arrow_icon` property of the `MinimapObject` is not an empty string. If it is not empty, the minimap arrow icon for this object will be displayed on the minimap.
---
--- @return boolean Whether the minimap arrow icon for this object is visible on the minimap.
function MinimapObject:VisibleArrowOnMinimap()
	return self.minimap_arrow_icon ~= ""
end

--- Returns the color of the minimap icon for this object.
---
--- @return table The color of the minimap icon.
function MinimapObject:GetMinimapIconColor()
	return self.minimap_icon_color
end

--- Deletes the minimap screenshot file when the map is done loading.
---
--- This function is called in response to the `DoneMap` message, which is triggered when the map has finished loading. It checks if the minimap screenshot file exists at the path "memoryscreenshot/minimap.tga", and if so, it deletes the file asynchronously using `AsyncFileDelete`. If there is an error deleting the file, it prints the error and the stack trace.
---
--- @return nil
function OnMsg.DoneMap()
	local filename = "memoryscreenshot/minimap.tga"
	if io.exists(filename) then
		local err = AsyncFileDelete(filename)
		if err then print(err, GetStack()) end
	end	
end

--- Prepares the minimap for the current map.
---
--- This function checks if the current map is a system map or an empty map, and returns if either of those conditions are true. Otherwise, it checks if a minimap image file exists for the current map, and if so, copies it to the "memoryscreenshot/minimap.tga" file. If the minimap image file does not exist, it calls the `WaitSaveMinimap` function to generate a new minimap screenshot.
--- Finally, it invalidates the minimap and sends a "MinimapReady" message.
---
--- @return nil
function PrepareMinimap()
	local map = GetMap()
	if mapdata.MapType == "system" or map == "" or string.find(map, "/__") then
		return
	end
	local map_filepath = map .. "minimap.tga"

	local filename = "memoryscreenshot/minimap.tga"
	if io.exists(filename) then
		local err = AsyncFileDelete(filename)
		if err then print(err) end
	end
	
	if io.exists(map_filepath) then
		local err = CopyFile(map_filepath, filename)
		if (err) then
			print("[Minimap] Copy existing image failed: " .. err)
		end
	else
		WaitSaveMinimap(filename, 100, config.MinimapScreenshotSize, MinimapOverrides:new())
	end
	InvalidateMinimap()
	Msg("MinimapReady")
end

if FirstLoad then
	g_SaveMinimapThread = false
end

---
--- Saves a minimap screenshot for the current map.
---
--- This function is responsible for capturing a screenshot of the minimap for the current map and saving it to the specified file path. It performs the following steps:
---
--- 1. Checks if there is an existing minimap saving operation in progress, and if so, asserts an error and returns.
--- 2. Retrieves the current map name, and returns if the map is empty or not set.
--- 3. Creates a new real-time thread to perform the minimap saving operation.
--- 4. Waits for the render mode to be in "scene" mode before proceeding.
--- 5. Sets up the minimap screenshot options, including the scale, file name, and any overrides.
--- 6. Suspends pass edits and deactivates the editor if it is active.
--- 7. Calculates the minimap size based on the terrain size and the specified scale.
--- 8. Pauses animations and the game, and sets up the camera and lighting for the minimap screenshot.
--- 9. Captures the minimap screenshot using `WaitCaptureScreenshot`.
--- 10. Restores the camera, lighting, and other settings to their previous state.
--- 11. Resumes animations, pass edits, and the editor (if it was active).
--- 12. Sends a "MinimapSaveEnd" message to indicate that the minimap saving operation is complete.
---
--- @param filename (string) The file path to save the minimap screenshot to.
--- @param scaleMinimap (number) The scale factor to apply to the minimap size.
--- @param forcedSize (number) The forced size of the minimap screenshot, overriding the calculated size.
--- @param overrides (MinimapOverrides) An optional table of overrides to apply to the rendering options.
--- @param editor (boolean) An optional flag indicating whether the minimap is being saved in the editor.
--- @return boolean True if the minimap saving operation was started successfully, false otherwise.
function SaveMinimap(filename, scaleMinimap, forcedSize, overrides, editor)
	if IsValidThread(g_SaveMinimapThread) then
		assert(false, "Minimap saving already in progress!")
		return false
	end
	local map = GetMap()
	if not map or map == "" then
		return false
	end
	g_SaveMinimapThread = CreateRealTimeThread(function()
		for i=1,5 do
			if WaitRenderMode("scene") then
				break
			end
		end
		if GetRenderMode() ~= "scene" then
			assert(false, "Minimap can be saved in scene mode only!")
			return
		end
		
		scaleMinimap = scaleMinimap or 100
		filename = filename or (map .. "minimap.tga")
		
		local options = {}
		Msg("MinimapSaveStart", options)

		local start = GetPreciseTicks()
		local t = start
		
		SuspendPassEdits("MinimapSave")
		
		local editor_mode
		if not editor and IsEditorActive() then
			editor_mode = true
			EditorDeactivate()
		end
		
		local twidth, theight = terrain.GetMapSize()
		local width = twidth/guim
		local height = theight/guim

		local minimapSizeX = (scaleMinimap*twidth)/(100*guim)
		local minimapSizeY = (scaleMinimap*theight)/(100*guim)
		
		if forcedSize then
			minimapSizeX = forcedSize
			minimapSizeY = forcedSize
		end
		
		PauseAnim()
		Pause("Minimap")
		local lightmodel = options.Lightmodel and LightmodelPresets[options.Lightmodel]
		lightmodel = lightmodel or LightmodelPresets.Minimap or LightmodelPresets.ArtPreview
		local old_lm = CurrentLightmodel[1]
		SetLightmodel(1, lightmodel, 0)
		
		local tmin, tmax
		if options.OrthoTop and options.OrthoBottom then
			tmax = options.OrthoTop
			tmin = options.OrthoBottom
		else
			local tavg
			tavg, tmin, tmax = terrain.GetAreaHeight()
			MapForEach("map", "CObject", function(o)
					if o:GetEntity() ~= "" and type(o:GetRadius()) == "number" then
						local pt, radius = o:GetBSphere()
						local maxz = pt:z() + radius
						if maxz > tmax then
							tmax = maxz
						end
					end
				end)
				
			tmax = (tmax / 10) * 10 + guim    -- 1m to compensate for the NearZ=1m
		end

		local farz = tmax - tmin
		local res_width, res_height = GetResolution()
		local aspect = guim*res_height/res_width
		local hr_values = {
			InterfaceInScreenshot = 0,
			OrthoTop = tmax,
			OrthoBottom = tmin,
			NearZ = self.OrthoTop or guim,
			FarZ = self.OrthoBottom or guim,
			Shadowmap = 0,
			EnablePostprocess = 0,
			RenderBillboards = 0,
			RenderParticles = 0,
			RenderSkinned = 0,
			ShowRTEnable = 0,
			EnableCloudsShadow = 0,
		}
		-- hr_values["SceneWidth"] = minimapSizeX
		-- hr_values["SceneHeight"] = minimapSizeY
		hr_values["OrthoX"] = width*aspect
		hr_values["OrthoYScale"] = aspect*height*1000/(width*guim)
		local save_hr_values = {}
		local NIL = {}
		for k,v in pairs(hr_values) do
			save_hr_values[k] = hr[k] or NIL
			hr[k] = v
		end
		if overrides then
			overrides:InitOptions()
		end
		-- switch to ortho expilictly at the end
		save_hr_values["Ortho"] = hr.Ortho
		hr_values["Ortho"] = 1
		hr.Ortho = 1
		
		WaitNextFrame(5)
		SetupViews()
		
		local cam_params = {GetCamera()}
		camera.Lock(1)
		cameraMax.Activate(1)
		local pos = point(twidth/2, theight/2, tmax)
		
		cameraMax.SetCamera(pos, pos + point(0, -1, -1000), 0)
		WaitNextFrame(2)
		--print("[Minimap] Render setup time " .. tostring(GetPreciseTicks() - t)) t = GetPreciseTicks()
		--print("[Minimap] Saving to ", filename, "..." )
		local src_box = false
		local err = WaitCaptureScreenshot(filename, {
			width = minimapSizeX,
			height = minimapSizeY,
			interface = false,
			src = src_box
		})
		if err then
			print("[Minimap] Write screenshot failed: " .. err)
		else
			--print("[Minimap] Write time " .. tostring(GetPreciseTicks() - t)) t = GetPreciseTicks()
		end
		
		-- these two MUST be restored before postprocessing is enabled back on by restoring hr.EnablePostprocess
		-- hr.SceneWidth = save_hr_values.SceneWidth
		-- hr.SceneHeight = save_hr_values.SceneHeight
		
		for k,_ in pairs(hr_values) do
			local v = save_hr_values[k]
			if v == NIL then
				hr[k] = nil
			else
				hr[k] = v
			end
		end
		
		WaitNextFrame(2)
		SetupViews()
		
		camera.Unlock(1)
		SetCamera(unpack_params(cam_params))

		if overrides then
			overrides:ClearOptions()
		end
		
		SetLightmodel(1, old_lm, 0)
		WaitNextFrame(1)
		
		Resume("Minimap")
		ResumeAnim()
		ResumePassEdits("MinimapSave")
		Msg("MinimapSaveEnd")
		
		if editor_mode then
			EditorActivate()
		end
		
		--print("[Minimap] Restore render setup time " .. tostring(GetPreciseTicks() - t))
		--print("[Minimap] Total time " .. tostring(GetPreciseTicks() - start))
	end)
	return true
end

---
--- Waits for the minimap saving process to complete.
--- This function performs the following steps:
--- 1. Decimate objects in ground detail class groups to reduce detail.
--- 2. Decimate particles in ground detail class groups to reduce detail.
--- 3. Decimate objects that are not needed for the screenshot.
--- 4. Save the minimap.
--- 5. Wait for the minimap saving process to complete.
--- 6. Restore the ground detail class group objects and particles to their original detail levels.
--- 7. Restore the objects that were not needed for the screenshot.
---
--- @param ... Additional arguments to pass to the SaveMinimap function.
--- @return boolean true if the minimap was saved successfully, false otherwise.
function WaitSaveMinimap(...)
	for i=1,#GroundDetailClassGroups do
		local group = GroundDetailClassGroups[i]
		DecimateObjects(group.classes, 0)
		local particles = type(group.particles) == "function" and group.particles() or group.particles
		DecimateParticles(particles, 0)
	end
	DecimateObjects(NotNeededForScreenshot, 0)
	SaveMinimap(...)
	WaitMinimapSaving()
	for i=1,#GroundDetailClassGroups do
		local group = GroundDetailClassGroups[i]
		DecimateObjects(group.classes, g_CurrentGroundDetailKeepPercent)
		local particles = type(group.particles) == "function" and group.particles() or group.particles
		DecimateParticles(particles, g_CurrentGroundDetailKeepPercent)
	end
	DecimateObjects(NotNeededForScreenshot, 100)
end

---
--- Waits for the minimap saving process to complete.
---
--- This function waits for the "MinimapSaveEnd" message to be received, indicating that the minimap saving process has completed. It does this by checking the validity of the `g_SaveMinimapThread` thread and waiting for the message to be received, with a timeout of 100 milliseconds.
---
--- @return nil
function WaitMinimapSaving()
	while IsValidThread(g_SaveMinimapThread) and not WaitMsg("MinimapSaveEnd", 100) do
	end
end

---
--- Defines a class `MinimapOverrides` that inherits from `CObject`.
--- This class is marked as `ingame = false`, which means it is not intended to be used in-game.
---
--- @class MinimapOverrides
--- @field __parents table The parent classes of this class.
--- @field ingame boolean Indicates whether this class is intended for in-game use.
DefineClass.MinimapOverrides =
{
	__parents = { "CObject" },
	ingame = false
}

---
--- Initializes the options for the MinimapOverrides class.
---
--- This function sets the following options:
--- - `hr.RenderCodeRenderables` is set to 0, which likely disables the rendering of certain code-related objects on the minimap.
--- - `hr.RenderSkinned` is set to 1, which likely enables the rendering of skinned objects on the minimap.
---
--- @function MinimapOverrides:InitOptions
--- @return nil
function MinimapOverrides:InitOptions()
	hr.RenderCodeRenderables=0
	hr.RenderSkinned=1
end

---
--- Clears the options for the MinimapOverrides class.
---
--- This function sets the `hr.RenderCodeRenderables` option to 1, which likely enables the rendering of certain code-related objects on the minimap.
---
--- @function MinimapOverrides:ClearOptions
--- @return nil
function MinimapOverrides:ClearOptions()
	hr.RenderCodeRenderables=1
end

if not Platform.developer then return end

---
--- Updates the minimaps for the specified maps.
---
--- This function creates a real-time thread that iterates through the provided list of maps, changes to each map, and waits for the minimap saving process to complete. If the minimap saving process fails for any map, the function returns.
---
--- @param maps table|nil A table of map names to update. If not provided, all maps will be updated.
--- @return nil
function UpdateMinimaps(maps)
	local thread = CreateRealTimeThread(function()
		maps = maps or ListMaps()
		local ide = IgnoreDebugErrors(true)
		print("STARTED")
		for i=1,#maps do
			local map = maps[i]
			printf("MAP %d/%d: %s", i, #maps, map)
			
			ChangeMap(map)
			
			if not WaitSaveMinimap() then
				print("FAILED")
				IgnoreDebugErrors(ide)
				return
			end
		end
		IgnoreDebugErrors(ide)
		print("FINISHED")
	end)
end
