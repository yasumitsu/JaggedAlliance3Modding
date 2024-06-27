if FirstLoad then
	g_PhotoMode = false
	PhotoModeObj = false

	-- Used in PP_Rebuild
	g_PhotoFilter = false 
	g_PhotoFilterData = false
end

---
--- Opens the Photo Mode dialog.
---
function PhotoModeDialogOpen() -- override in project
	OpenDialog("PhotoMode")
end

local function ActivateFreeCamera()
	Msg("PhotoModeFreeCameraActivated")
	--table.change(hr, "FreeCamera", { FarZ = 1500000 })
	local _, _, camType, zoom, properties, fov = GetCamera()
	PhotoModeObj.initialCamera = {
		camType = camType,
		zoom = zoom,
		properties = properties,
		fov = fov
	}
	cameraFly.Activate(1)
	cameraFly.DisableStickMovesChange()
	if g_MouseConnected then
		SetMouseDeltaMode(true)
	end
end

local function DeactivateFreeCamera()
	if g_MouseConnected then
		SetMouseDeltaMode(false)
	end
	cameraFly.EnableStickMovesChange()
	local current_pos, current_look_at = GetCamera()
	if config.PhotoMode_FreeCameraPositionChange then
		SetCamera(current_pos, current_look_at, PhotoModeObj.initialCamera.camType, PhotoModeObj.initialCamera.zoom, PhotoModeObj.initialCamera.properties, PhotoModeObj.initialCamera.fov)
	end
	PhotoModeObj.initialCamera = false
	Msg("PhotoModeFreeCameraDeactivated")
end

---
--- Ends the Photo Mode session, restoring the game state to its previous condition.
---
--- This function is responsible for the following actions:
--- - Saves the current Photo Mode state
--- - Deactivates any active photo filters
--- - Resets the global Photo Mode state variables
--- - Restores the game's light model, depth of field, and color grading to their pre-Photo Mode values
--- - Rebuilds the post-processing pipeline
--- - Sends a "PhotoModeEnd" message
---
--- @function PhotoModeEnd
--- @return nil
function PhotoModeEnd()
	if PhotoModeObj then
		CreateMapRealTimeThread(function()
			PhotoModeObj:Save()
		end)
	end
	if g_PhotoFilter and g_PhotoFilter.deactivate then
		g_PhotoFilter.deactivate(g_PhotoFilter.filter, g_PhotoFilterData)
	end
	g_PhotoMode = false
	g_PhotoFilter = false
	g_PhotoFilterData = false
	--restore from initial values
	table.restore(hr, "photo_mode")
	--rebuild the postprocess
	PP_Rebuild()
	--restore lightmodel
	SetLightmodel(1, PhotoModeObj.preStoredVisuals.lightmodel, 0)
	table.insert(PhotoModeObj.preStoredVisuals.dof_params, 0)
	SetDOFParams(unpack_params(PhotoModeObj.preStoredVisuals.dof_params))
	SetGradingLUT(1, ResourceManager.GetResourceID(PhotoModeObj.preStoredVisuals.LUT:GetResourcePath()), 0, 0)
	Msg("PhotoModeEnd")
end

---
--- Applies the specified photo mode properties to the game's rendering.
---
--- This function is responsible for the following actions:
--- - Deactivates any active photo filters
--- - Applies the specified photo filter, if one is set
--- - Sets various scene parameters based on the photo mode properties, such as fog density, bloom strength, exposure, auto-exposure key bias, vignette, color saturation, and depth of field
--- - Activates or deactivates the free camera mode based on the photo mode properties
--- - Sets the camera's field of view based on the photo mode properties
--- - Toggles the photo frame display based on the photo mode properties
--- - Sets the color grading lookup table (LUT) based on the photo mode properties
---
--- @param pm_object The photo mode object containing the properties to apply
--- @param prop_id The ID of the property to apply
--- @return nil
function PhotoModeApply(pm_object, prop_id)
	if prop_id == "filter" then
		if g_PhotoFilter and g_PhotoFilter.deactivate then
			g_PhotoFilter.deactivate(g_PhotoFilter.filter, g_PhotoFilterData)
		end
		local filter = PhotoFilterPresetMap[pm_object.filter]
		if filter and filter.shader_file ~= "" then
			g_PhotoFilterData = {}
			if filter.activate then
				filter.activate(filter, g_PhotoFilterData)
			end
			g_PhotoFilter = filter:GetShaderDescriptor()
		else
			g_PhotoFilter = false
			g_PhotoFilterData = false
		end
		if not filter then
			pm_object:SetProperty("filter", pm_object.filter) --revert to default filter
		end
		PP_Rebuild()
	elseif prop_id == "fogDensity" then
		SetSceneParam(1, "FogGlobalDensity", pm_object.fogDensity, 0, 0)
	elseif prop_id == "bloomStrength" then
		SetSceneParamVector(1, "Bloom", 0, pm_object.bloomStrength, 0, 0)
	elseif prop_id == "exposure" then
		SetSceneParam(1, "GlobalExposure",  pm_object.exposure, 0, 0)
	elseif prop_id == "ae_key_bias" then
		SetSceneParam(1, "AutoExposureKeyBias",  pm_object.ae_key_bias, 0, 0)
	elseif prop_id == "vignette" then
		SetSceneParamFloat(1, "VignetteDarkenOpacity", (1.0 * pm_object.vignette) / pm_object:GetPropertyMetadata("vignette").scale, 0, 0)
	elseif prop_id == "colorSat" then
		SetSceneParam(1, "Desaturation", -pm_object.colorSat, 0, 0)
	elseif prop_id == "depthOfField" or prop_id == "focusDepth" or prop_id == "defocusStrength" then
		local detail = 3
		local focus_depth = Lerp(hr.NearZ, hr.FarZ, pm_object.focusDepth ^ detail, 100 ^ detail)
		local dof = Lerp(0, hr.FarZ - hr.NearZ, pm_object.depthOfField ^ detail, 100 ^ detail)
		local strength = sqrt(pm_object.defocusStrength * 100)
		SetDOFParams(
			strength, 
			Max(focus_depth - dof / 3, hr.NearZ), 
			Max(focus_depth - dof / 6, hr.NearZ),
			strength,
			Min(focus_depth + dof / 3, hr.FarZ), 
			Min(focus_depth + dof * 2 / 3, hr.FarZ),
			0)
	elseif prop_id == "freeCamera" then
		if pm_object.freeCamera then
			ActivateFreeCamera()
		else
			DeactivateFreeCamera()
		end
		return -- don't send Msg 
	elseif prop_id == "fov" then
		camera.SetAutoFovX(1, 0, pm_object.fov, 16, 9)
	elseif prop_id == "frame" then
		pm_object:ToggleFrame()
	elseif prop_id == "LUT" then
		if pm_object.LUT == "None" then
			SetGradingLUT(1, ResourceManager.GetResourceID(pm_object.preStoredVisuals.LUT:GetResourcePath()), 0, 0)
		else
			SetGradingLUT(1, ResourceManager.GetResourceID(GradingLUTs[pm_object.LUT]:GetResourcePath()), 0, 0)
		end
	end
	Msg("PhotoModePropertyChanged")
end

---
--- Takes a screenshot in photo mode.
---
--- @param frame_duration number The duration of the screenshot in seconds.
--- @param max_frame_duration number The maximum duration of the screenshot in seconds.
function PhotoModeDoTakeScreenshot(frame_duration, max_frame_duration)
	local hideUIWindow
	if not config.PhotoMode_DisablePhotoFrame and PhotoModeObj.photoFrame then
		table.change(hr, "photo_mode_frame_screenshot", {
			InterfaceInScreenshot = true,
		})
		hideUIWindow = GetDialog("PhotoMode").idHideUIWindow
		hideUIWindow:SetVisible(false)
	end
	PhotoModeObj.shotNum = PhotoModeObj.shotNum or 0
	frame_duration = frame_duration or 0
	
	local folder = "AppPictures/"
	local proposed_name = string.format("Screenshot%04d.png", PhotoModeObj.shotNum)
	if io.exists(folder .. proposed_name) then
		local files = io.listfiles(folder, "Screenshot*.png")
		for i = 1, #files do
			PhotoModeObj.shotNum = Max(PhotoModeObj.shotNum, tonumber(string.match(files[i], "Screenshot(%d+)%.png") or 0))
		end
		PhotoModeObj.shotNum = PhotoModeObj.shotNum + 1
		proposed_name = string.format("Screenshot%04d.png", PhotoModeObj.shotNum)
	end
	local width, height = GetResolution()
	WaitNextFrame(3)
	LockCamera("Screenshot")
	if frame_duration == 0 and hr.TemporalGetType() ~= "none" then
		MovieWriteScreenshot(folder .. proposed_name, frame_duration, 1, frame_duration, width, height)
	else
		local quality = Lerp(128, 128, frame_duration, max_frame_duration)
		MovieWriteScreenshot(folder .. proposed_name, frame_duration, quality, frame_duration, width, height)
	end
	UnlockCamera("Screenshot")
	PhotoModeObj.shotNum = PhotoModeObj.shotNum + 1
	local file_path = ConvertToOSPath(folder .. proposed_name)
	Msg("PhotoModeScreenshotTaken", file_path)
	if Platform.steam and IsSteamAvailable() then
		SteamAddScreenshotToLibrary(file_path, "", width, height)
	end
	if hideUIWindow then
		hideUIWindow:SetVisible(true)
		table.restore(hr, "photo_mode_frame_screenshot")
	end
end

---
--- Takes a screenshot in photo mode.
---
--- @param frame_duration number The duration of the screenshot in seconds.
--- @param max_frame_duration number The maximum duration of the screenshot in seconds.
function PhotoModeTake(frame_duration, max_frame_duration)
	if IsValidThread(PhotoModeObj.shotThread) then return end
	PhotoModeObj.shotThread = CreateMapRealTimeThread(function()
		if Platform.console then
			local photoModeDlg = GetDialog("PhotoMode")
			local hideUIWindow = photoModeDlg.idHideUIWindow
			hideUIWindow:SetVisible(false)

			local err
			if Platform.xbox then
				err = AsyncXboxTakeScreenshot()
			elseif Platform.playstation then
				err = AsyncPlayStationTakeScreenshot()
			else
				err = "Not supported!"
			end
			if err then
				CreateErrorMessageBox(err, "photo mode")
			end
			hideUIWindow:SetVisible(true)
			photoModeDlg:ToggleUI(true) -- fix prop selection
		else  
			PhotoModeDoTakeScreenshot(frame_duration, max_frame_duration)
		end
		Sleep(1000) -- Prevent screenshot spamming
	end, frame_duration, max_frame_duration)
end

---
--- Begins the photo mode by creating a new `PhotoModeObject` instance, restoring its initial values from the `AccountStorage.PhotoMode` if available, or resetting the properties to the current lightmodel. It also stores the current camera parameters and sets up the necessary changes to the rendering pipeline for photo mode.
---
--- @return PhotoModeObject The created `PhotoModeObject` instance.
---
function PhotoModeBegin()
	local obj = PhotoModeObject:new()
	obj:StoreInitialValues()
	local props = obj:GetProperties()
	if AccountStorage.PhotoMode then
		for _, prop in ipairs(props) do
			local value = AccountStorage.PhotoMode[prop.id]
			if value ~= nil then --false could be a valid value
				obj:SetProperty(prop.id, value)
			end
		end
	else
		-- set initial values from current lightmodel
		obj:ResetProperties()
	end
	obj.prev_camera = pack_params(GetCamera())
	PhotoModeObj = obj

	Msg("PhotoModeBegin")
	g_PhotoMode = true
	table.change(hr, "photo_mode", {
		InterfaceInScreenshot = false,
		LODDistanceModifier = Max(hr.LODDistanceModifier, 200),
		DistanceModifier = Max(hr.DistanceModifier, 100),
		ObjectLODCapMin = Min(hr.ObjectLODCapMin, 0),
		EnablePostProcDOF = 1,
		Anisotropy = 4,
	})

	return obj
end

function OnMsg.AfterLightmodelChange()
	if g_PhotoMode and GetTimeFactor() ~= 0 then
		--in photo mode in resumed state
		local lm_name = CurrentLightmodel[1].id or ""
		PhotoModeObj.preStoredVisuals.lightmodel = lm_name ~= "" and lm_name or CurrentLightmodel[1]
	end
end

---
--- Returns a table of available photo filters.
---
--- The table contains entries with the following structure:
--- 
--- {
---     value = <string>, -- the unique identifier of the photo filter
---     text = <string>   -- the display name of the photo filter
--- }
--- 
---
--- The photo filters are retrieved by iterating over all `PhotoFilterPreset` presets.
---
--- @return table<table>
---
function GetPhotoModeFilters()
	local filters = {}
	ForEachPreset("PhotoFilterPreset", function(preset, group, filters)
		filters[#filters + 1] = { value = preset.id, text = preset.display_name }
	end, filters)
	
	return filters
end

---
--- Returns a table of available photo frames.
---
--- The table contains entries with the following structure:
--- 
--- {
---     value = <string>, -- the unique identifier of the photo frame
---     text = <string>   -- the display name of the photo frame
--- }
---
--- The photo frames are retrieved by iterating over all `PhotoFramePreset` presets.
---
--- @return table<table>
---
function GetPhotoModeFrames()
	local frames = {}
	ForEachPreset("PhotoFramePreset", function(preset, group, frames)
		frames[#frames + 1] = { value = preset.id, text = preset:GetName()}
	end, frames)
	
	return frames
end

---
--- Returns a table of available photo LUTs (Look-Up Tables).
---
--- The table contains entries with the following structure:
--- 
--- {
---     value = <string>, -- the unique identifier of the photo LUT
---     text = <string>   -- the display name of the photo LUT
--- }
---
--- The photo LUTs are retrieved by iterating over all `GradingLUTSource` presets that are in the "PhotoMode" group or are marked as a mod item.
---
--- @return table<table>
---
function GetPhotoModeLUTs()
	local LUTs = {}
	LUTs[#LUTs + 1] = { value = "None", text = T(1000973, "None")}
	ForEachPreset("GradingLUTSource", function(preset)
		if preset.group == "PhotoMode" or preset:IsModItem() then 
			LUTs[#LUTs + 1] = { value = preset.id, text = preset:GetDisplayName()}
		end
	end, LUTs)
	
	return LUTs
end

---
--- Returns the appropriate step value for a photo mode property slider based on whether the user is using a gamepad or mouse.
---
--- @param gamepad_val number The step value to use when the user is using a gamepad.
--- @param mouse_val number The step value to use when the user is using a mouse.
--- @return number The appropriate step value for the photo mode property slider.
---
function PhotoModeGetPropStep(gamepad_val, mouse_val)
	return GetUIStyleGamepad() and gamepad_val or mouse_val
end

---
--- Defines the properties and behavior of the PhotoModeObject class, which is used to manage the photo mode functionality in the game.
---
--- The PhotoModeObject class inherits from the PropertyObject class, and defines a set of properties that can be adjusted by the player to customize the appearance of the in-game camera and scene.
---
--- The class provides methods to store and restore the initial visual state of the game, apply changes to the properties, reset the properties to their default values, and save the current state to the player's account storage.
---
--- @class PhotoModeObject
--- @field preStoredVisuals table The initial visual state of the game, including the current lightmodel, depth of field parameters, and color grading LUT.
--- @field shotNum boolean Indicates whether a screenshot has been taken.
--- @field shotThread boolean The thread that is responsible for taking a screenshot.
--- @field initialCamera boolean The initial camera state before entering photo mode.
--- @field photoFrame boolean Indicates whether a photo frame is currently applied.
--- @property freeCamera boolean Determines whether the camera is in free camera mode.
--- @property filter string The currently selected photo filter.
--- @property frameDuration number The duration of the motion blur effect.
--- @property vignette number The strength of the vignette effect.
--- @property exposure number The exposure level of the scene.
--- @property ae_key_bias number The auto-exposure key bias.
--- @property fogDensity number The density of the fog in the scene.
--- @property depthOfField number The strength of the depth of field effect.
--- @property focusDepth number The depth at which the scene is in focus.
--- @property defocusStrength number The strength of the defocus effect.
--- @property bloomStrength number The strength of the bloom effect.
--- @property colorSat number The saturation level of the scene.
--- @property fov number The field of view of the camera.
--- @property frame string The currently selected photo frame.
--- @property LUT string The currently selected color grading LUT.
DefineClass.PhotoModeObject = {
	__parents = {"PropertyObject"},
	properties =
	{
		{ name = T(335331914221, "Free Camera"), id = "freeCamera", editor = "bool", default = false, dont_save = true, },
		{ name = T(915562435389, "Photo Filter"), id = "filter", editor = "choice", default = "None", items = GetPhotoModeFilters, no_edit = not not config.PhotoMode_DisablePhotoFilter}, -- enabled when config.DisablePhotoFilter doesn't exist
		{ name = T(650173703450, "Motion Blur"), id = "frameDuration", editor = "number", slider = true, default = 0, min = 0, max = 100, step = function() return PhotoModeGetPropStep(5, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = true},
		{ name = T(281819101205, "Vignette"), id = "vignette", editor = "number", slider = true, default = 0, min = 0, max = 255, scale = 255, step = function() return PhotoModeGetPropStep(10, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(394842812741, "Exposure"), id = "exposure", editor = "number", slider = true, default = 0, min = -200, max = 200, step = function() return PhotoModeGetPropStep(20, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = function(obj) return hr.AutoExposureMode == 1 end, },
		{ name = T(394842812741, "Exposure"), id = "ae_key_bias", editor = "number", slider = true, default = 0, min = -3000000, max = 3000000, step = function() return PhotoModeGetPropStep(100000, 10000) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = function(obj) return hr.AutoExposureMode == 0 end, },
		{ name = T(764862486527, "Fog Density"), id = "fogDensity", editor = "number", slider = true, default = 0, min = 0, max = 1000, step = function() return PhotoModeGetPropStep(50, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(493626846649, "Depth of Field"), id = "depthOfField", editor = "number", slider = true, default = 100, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF },
		{ name = T(775319101921, "Focus Depth"), id = "focusDepth", editor = "number", slider = true, default = 0, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF},
		{ name = T(194124087753, "Defocus Strength"), id = "defocusStrength", editor = "number", slider = true, default = 10, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF },
		{ name = T(462459069592, "Bloom Strength"), id = "bloomStrength", editor = "number", slider = true, default = 0, min = 0, max = 100, step = function() return PhotoModeGetPropStep(5,1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableBloomStrength}, -- enabled when config.DisableBloomStrength doesn't exist
		{ name = T(265619974713, "Saturation"), id = "colorSat", editor = "number", slider = true, default = 0, min = -100, max = 100, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(3451, "FOV"), id = "fov", editor = "number", default = const.DefaultCameraRTS and const.DefaultCameraRTS.FovX or 90*60, slider = true, min = 20*60, max = 120*60, scale = 60, step = function() return PhotoModeGetPropStep(300, 10) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(985831418702, "Photo Frame"), id = "frame", editor = "choice", default = "None", items = GetPhotoModeFrames, no_edit = not not config.PhotoMode_DisablePhotoFrame }, -- enabled when config.DisablePhotoFrame doesn't exist
		{ name = T(970914453104, "Color Grading"), id = "LUT", editor = "choice", default = "None", items = GetPhotoModeLUTs, no_edit = not not config.PhotoMode_DisablePhotoLUTs }, -- enabled when config.PhotoMode_DisablePhotoLUTs doesn't exist
	},
	preStoredVisuals = false,
	shotNum = false,
	shotThread = false,
	initialCamera = false,
	photoFrame = false,
}

---
--- Stores the initial values of the PhotoMode object, including the current lightmodel, DOF parameters, and LUT.
---
--- This function is used to save the initial state of the PhotoMode object, so that it can be restored later when the PhotoMode is resumed.
---
--- @function PhotoModeObject:StoreInitialValues
--- @return nil
function PhotoModeObject:StoreInitialValues()
	self.preStoredVisuals = {}
	local lm_name = CurrentLightmodel[1].id or ""
	self.preStoredVisuals.lightmodel = self.preStoredVisuals.lightmodel or (lm_name ~= "" and lm_name or CurrentLightmodel[1])
	self.preStoredVisuals.dof_params = self.preStoredVisuals.dof_params or { GetDOFParams() }
	local lut_name = CurrentLightmodel[1].grading_lut or "Default"
	self.preStoredVisuals.LUT = self.preStoredVisuals.LUT or (GradingLUTs[lut_name] or GradingLUTs["Default"])
end

---
--- Sets a property of the PhotoModeObject and applies the change.
---
--- @param id string The ID of the property to set.
--- @param value any The new value for the property.
--- @return boolean Whether the property was successfully set.
function PhotoModeObject:SetProperty(id, value)
	local ret = PropertyObject.SetProperty(self, id, value)
	PhotoModeApply(self, id)
	return ret
end

---
--- Resets the properties of the PhotoModeObject to their default values.
---
--- This function sets the following properties to their default values:
--- - `fogDensity`: Set to the `fog_density` value of the current lightmodel.
--- - `bloomStrength`: Set to the `pp_bloom_strength` value of the current lightmodel.
--- - `exposure`: Set to the `exposure` value of the current lightmodel.
--- - `ae_key_bias`: Set to the `ae_key_bias` value of the current lightmodel.
--- - `colorSat`: Set to the negative of the `desaturation` value of the current lightmodel.
--- - `vignette`: Set to the `vignette_darken_opacity` value of the current lightmodel, scaled by the `vignette` property metadata scale.
---
--- Additionally, the `photoFrame` property is set to `false`.
---
--- @function PhotoModeObject:ResetProperties
--- @return nil
function PhotoModeObject:ResetProperties()
	for i, prop in ipairs(self:GetProperties()) do
		if not prop.dont_save then
			self:SetProperty(prop.id, nil)
		end
	end
	self:SetProperty("fogDensity", CurrentLightmodel[1].fog_density)
	self:SetProperty("bloomStrength", CurrentLightmodel[1].pp_bloom_strength)
	self:SetProperty("exposure", CurrentLightmodel[1].exposure)
	self:SetProperty("ae_key_bias", CurrentLightmodel[1].ae_key_bias)
	self:SetProperty("colorSat", -CurrentLightmodel[1].desaturation)
	self:SetProperty("vignette", floatfloor(CurrentLightmodel[1].vignette_darken_opacity * self:GetPropertyMetadata("vignette").scale))

	self.photoFrame = false
end

---
--- Saves the current state of the PhotoModeObject to the account storage.
---
--- This function iterates through the properties of the PhotoModeObject and
--- saves the non-`dont_save` properties to the `AccountStorage.PhotoMode` table.
--- The `AccountStorage` is then saved to disk.
---
--- @function PhotoModeObject:Save
--- @return nil
function PhotoModeObject:Save()
	AccountStorage.PhotoMode = {}
	local storage_table = AccountStorage.PhotoMode
	for _, prop in ipairs(self:GetProperties()) do
		if not prop.dont_save then
			local value = self:GetProperty(prop.id)
			storage_table[prop.id] = value
		end
	end
	SaveAccountStorage(5000)
end

---
--- Pauses the PhotoModeObject.
---
--- This function calls the global `Pause` function and pauses the PhotoModeObject.
---
--- @function PhotoModeObject:Pause
--- @return nil
function PhotoModeObject:Pause()
	Pause(self)
end

---
--- Resumes the PhotoModeObject and restores the pre-stored visuals if the current lightmodel is different.
---
--- This function first calls the global `Resume` function to resume the PhotoModeObject. It then checks if the current lightmodel is different from the pre-stored lightmodel in `PhotoModeObj.preStoredVisuals`. If the lightmodels are different, it calls `SetLightmodel` to set the lightmodel to the pre-stored value.
---
--- @function PhotoModeObject:Resume
--- @param force boolean (optional) - If true, the function will resume the PhotoModeObject regardless of its current state.
--- @return nil
function PhotoModeObject:Resume(force)
	Resume(self)
	local lm_name = CurrentLightmodel[1].id or ""
	if (lm_name ~= "" and lm_name or CurrentLightmodel[1]) ~= PhotoModeObj.preStoredVisuals.lightmodel then
		SetLightmodel(1, PhotoModeObj.preStoredVisuals.lightmodel, 0)
	end
end

---
--- Deactivates the free camera mode of the PhotoModeObject.
---
--- This function checks if the PhotoModeObject has a free camera enabled, and if so, sets the "freeCamera" property to `nil` to deactivate it.
---
--- @function PhotoModeObject:DeactivateFreeCamera
--- @return nil
function PhotoModeObject:DeactivateFreeCamera()
	if PhotoModeObj.freeCamera then
		self:SetProperty("freeCamera", nil)
	end
end

---
--- Toggles the visibility of the photo frame in the PhotoMode dialog.
---
--- This function checks if the PhotoMode is disabled. If not, it retrieves the PhotoMode dialog and the current photo frame property. If the frame is set to "None", it hides the frame window and sets the `photoFrame` property to `false`. Otherwise, it shows the frame window and sets the frame image based on the `PhotoFramePresetMap`. If the frame preset does not have a valid frame file, it hides the frame window and sets the `photoFrame` property to `false`. Finally, it respawns the content of the scroll area in the dialog.
---
--- @function PhotoModeObject:ToggleFrame
--- @return nil
function PhotoModeObject:ToggleFrame()
	if config.PhotoMode_DisablePhotoFrame then return end
	local dlg = GetDialog("PhotoMode")
	if dlg and dlg.idFrameWindow then
		local frameName = self:GetProperty("frame")
		if frameName == "None" then
			dlg.idFrameWindow:SetVisible(false)
			self.photoFrame = false
		else
			dlg.idFrameWindow:SetVisible(true)
			local photoFramePreset = PhotoFramePresetMap[frameName]
			if not photoFramePreset then
				self:SetProperty("frame", "None")
				dlg.idFrameWindow:SetVisible(false)
				self.photoFrame = false
				dlg.idScrollArea:RespawnContent()
			elseif not photoFramePreset.frame_file then
				self.photoFrame = false
				dlg.idFrameWindow:SetVisible(false)
			else
				self.photoFrame = true
				dlg.idFrameWindow.idFrame:SetImage(photoFramePreset.frame_file)
			end
		end
	end
end