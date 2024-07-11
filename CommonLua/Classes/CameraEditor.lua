if FirstLoad then
	s_CameraFadeThread = false
end

--- Deletes the camera fade thread if it exists.
---
--- This function is used to clean up the camera fade thread when it is no longer needed.
--- It checks if the `s_CameraFadeThread` variable is set, and if so, it deletes the thread
--- and sets the variable to `false`.
function DeleteCameraFadeThread()
	if s_CameraFadeThread then
		DeleteThread(s_CameraFadeThread)
		s_CameraFadeThread = false
	end
end

--- Deletes the camera fade thread if it exists and reverts the properties of the last camera.
---
--- This function is used to clean up the camera fade thread and revert the properties of the last camera
--- when the camera view is being closed. It first checks if the `s_CameraFadeThread` variable is set, and if so,
--- it deletes the thread and sets the variable to `false`. It then checks if a `last_camera` parameter is provided,
--- and if so, it calls the `RevertProperties()` method on that camera to revert its properties. Finally, it
--- unlocks the "CameraPreset" camera.
---
--- @param last_camera Camera The last camera that was being used, or `nil` if none.
function CameraShowClose(last_camera)
	DeleteCameraFadeThread()
	if last_camera then
		last_camera:RevertProperties()
	end	
	UnlockCamera("CameraPreset")
end

---
--- Switches the current camera to the specified camera.
---
--- This function is used to switch the current camera view to a different camera. It performs the following steps:
---
--- 1. If the current thread cannot yield, it creates a new real-time thread to execute the function and returns.
--- 2. If the editor is active, it clears the selection and adds the new camera to the selection.
--- 3. If an old camera is provided, it reverts the properties of the old camera, unless the new camera and old camera are set to flip to adjacent cameras.
--- 4. If an in-between callback is provided, it calls that callback.
--- 5. It applies the properties of the new camera, unless the "dont_lock" flag is set, and the new camera and old camera are set to flip to adjacent cameras.
---
--- @param camera Camera The new camera to switch to.
--- @param old_camera Camera The old camera to revert properties for.
--- @param in_between_callback function An optional callback to execute between the old and new camera.
--- @param dont_lock boolean An optional flag to prevent locking the camera.
--- @param ged table The GED (Game Editor) object, if available.
function SwitchToCamera(camera, old_camera, in_between_callback, dont_lock, ged)
	if not CanYield() then
		DeleteCameraFadeThread()
		s_CameraFadeThread = CreateRealTimeThread(function()
			SwitchToCamera(camera, old_camera, in_between_callback, dont_lock, ged)
		end)
		return
	end

	if IsEditorActive() then
		editor.ClearSel()
		editor.AddToSel({camera})
	end
	if old_camera then
		old_camera:RevertProperties(not(camera.flip_to_adjacent and old_camera.flip_to_adjacent))
	end
	if in_between_callback then
		in_between_callback()
	end
	camera:ApplyProperties(dont_lock, not(camera.flip_to_adjacent and old_camera.flip_to_adjacent), ged)
end

---
--- Shows a predefined camera by applying its properties.
---
--- @param id string The ID of the predefined camera to show.
function ShowPredefinedCamera(id)
	local cam = PredefinedCameras[id]
	if not cam then
		print("No such camera preset: ", id)
		return
	end
	CreateRealTimeThread(cam.ApplyProperties, cam, "dont_lock")
end

---
--- Sets the destination of the specified camera to the camera itself.
---
--- This function is used to set the destination of the specified camera to the camera itself. It is typically used in the context of the Game Editor (GED) to modify the properties of a selected camera.
---
--- @param ged table The GED (Game Editor) object, if available.
--- @param selected_camera Camera The camera to set the destination for.
function GedOpCreateCameraDest(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	selected_camera:SetDest(selected_camera)
	GedObjectModified(selected_camera)
end
---
--- Updates the properties of the specified camera in the Game Editor (GED).
---
--- This function is used to update the properties of a selected camera in the Game Editor (GED). It queries the properties of the camera and then notifies the GED that the object has been modified.
---
--- @param ged table The GED (Game Editor) object, if available.
--- @param selected_camera Camera The camera to update.


function GedOpUpdateCamera(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	selected_camera:QueryProperties()
	GedObjectModified(selected_camera)
end

---
--- Switches to the specified camera in the Game Editor (GED).
---
--- This function is used to switch the current camera view to the specified camera in the Game Editor (GED). It applies the properties of the selected camera and optionally locks the camera.
---
--- @param ged table The GED (Game Editor) object, if available.
--- @param selected_camera Camera The camera to switch to.
function GedOpViewMovement(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	SwitchToCamera(selected_camera, nil, nil, "don't lock")
end

---
--- Checks if the view movement is toggled in the Showcase dialog.
---
--- This function returns a boolean indicating whether the view movement is toggled in the Showcase dialog. It is used to determine the state of the view movement functionality in the Game Editor (GED).
---
--- @return boolean true if the view movement is toggled, false otherwise
function GedOpIsViewMovementToggled()
	return not not GetDialog("Showcase")
end

local function TakeCameraScreenshot(ged, path, sector, camera)
	if GetMapName() ~= camera.map then
		ChangeMap(camera.map)
	end
	
	camera:ApplyProperties()
	local oldInterfaceInScreenshot = hr.InterfaceInScreenshot
	hr.InterfaceInScreenshot = camera.interface and 1 or 0
	
	local image = string.format("%s/%s.png", path, sector)
	AsyncFileDelete(image)
	WaitNextFrame(3)
	local store = {}
	Msg("BeforeUpsampledScreenshot", store)
	WaitNextFrame()
	MovieWriteScreenshot(image, 0, 64, false, 3840, 2160)
	WaitNextFrame()
	Msg("AfterUpsampledScreenshot", store)
	
	hr.InterfaceInScreenshot = oldInterfaceInScreenshot
	camera:RevertProperties()
	return image
end

---
--- Takes screenshots of the specified camera(s) and saves them to the SubVersion repository.
---
--- This function is used to take screenshots of the specified camera(s) and save them to the SubVersion repository. It first creates a folder for the current campaign, then takes a screenshot for each camera and adds the files to the SubVersion repository.
---
--- @param ged table The GED (Game Editor) object, if available.
--- @param camera Camera|GedMultiSelectAdapter The camera or list of cameras to take screenshots for.
function GedOpTakeScreenshots(ged, camera)
	if not camera then return end
	
	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local sectors = campaign_presets[campaign] and campaign_presets[campaign].Sectors or empty_table
	local map_to_sector = {[false] = ""}
	for _, sector in ipairs(sectors) do
		if sector.Map then
			map_to_sector[sector.Map] = sector.Id
		end
	end
	
	local path = string.format("svnAssets/Source/UI/LoadingScreens/%s", campaign)
	local err = AsyncCreatePath(path)
	if err then
		local os_path = ConvertToOSPath(path)
		ged:ShowMessage("Error", string.format("Can't create '%s' folder!", os_path))
		return
	end
	local ok, result = SVNAddFile(path)
	if not ok then
		ged:ShowMessage("SVN Error", result)
	end
	
	StopAllHiding("CameraEditorScreenshots", 0, 0)
	local size = UIL.GetScreenSize()
	ChangeVideoMode(3840, 2160, 0, false, true)
	WaitChangeVideoMode()
	LockCamera("Screenshot")
	
	local images = {}
	if IsKindOf(camera, "Camera") then
		images[1] = TakeCameraScreenshot(ged, path, map_to_sector[camera.map], camera)
	else
		local cameras = IsKindOf(camera, "GedMultiSelectAdapter") and camera.__objects or camera
		table.sort(cameras, function(a, b) return a.map < b.map end)
		for _, cam in ipairs(cameras) do
			table.insert(images, TakeCameraScreenshot(ged, path, map_to_sector[cam.map], cam))
		end
	end

	UnlockCamera("Screenshot")
	ChangeVideoMode(size:x(), size:y(), 0, false, true)
	WaitChangeVideoMode()
	ResumeAllHiding("CameraEditorScreenshots")
	
	local ok, result = SVNAddFile(images)
	if not ok then
		ged:ShowMessage("SVN Error", result)
	end
	print("Taking screenshots and adding to SubVersion done.")
end

function OnMsg.GedOnEditorSelect(obj, selected, ged_editor)
	if obj and IsKindOf(obj, "Camera") and selected then 
		SwitchToCamera(obj, IsKindOf(ged_editor.selected_object, "Camera") and ged_editor.selected_object, nil, "don't lock", ged_editor)
	end
end

---
--- Unlocks the camera.
---
function GedOpUnlockCamera()
	camera.Unlock()
end

---
--- Activates the max camera.
---
function GedOpMaxCamera()
	cameraMax.Activate(1)
end

---
--- Activates the tactical camera.
---
function GedOpTacCamera()
	cameraTac.Activate(1)
end

---
--- Activates the RTS camera.
---
function GedOpRTSCamera()
	cameraRTS.Activate(1)
end

---
--- Saves all cameras.
---
--- This function saves all cameras to a file. The file is named "save all" and the reason for the save is "user request".
---
function GedOpSaveCameras()
	local class = _G["Camera"]
	class:SaveAll("save all", "user request")
end

---
--- Creates reference images for all cameras.
---
--- This function creates screenshots for all cameras defined in the "reference" preset and saves them to the "svnAssets/Tests/ReferenceImages" folder. The screenshots are taken at a resolution of 512x512 pixels.
---
--- The function first checks if it is running in a real-time thread, and if not, creates a new real-time thread to execute the function. This ensures that the function runs in a separate thread and does not block the main game loop.
---
--- The function then sets the mouse delta mode, light model, and video mode to the desired settings, and iterates through all the cameras in the "reference" preset. For each camera, it applies the camera properties, waits for 3 seconds, creates a screenshot, and then reverts the camera properties. The screenshots are saved with the camera ID as the file name.
---
--- Finally, the function resets the video mode and mouse delta mode, and prints a message indicating the number of reference images that were created.
---
function CreateReferenceImages()
	if not IsRealTimeThread() then
		CreateRealTimeThread(CreateReferenceImages)
		return
	end
	
	local folder = "svnAssets/Tests/ReferenceImages"
	local cameras = Presets.Camera["reference"]
	SetMouseDeltaMode(true)
	SetLightmodel(0, LightmodelPresets.ArtPreview, 0)
	local size = UIL.GetScreenSize()
	ChangeVideoMode(512, 512, 0, false, true)
	WaitChangeVideoMode()
	local created = 0
	for _, cam in ipairs(cameras) do
		if GetMapName() ~= cam.map then
			ChangeMap(cam.map)
		end
		cam:ApplyProperties()
		Sleep(3000)
		AsyncCreatePath(folder)
		local image = string.format("%s/%s.png", folder, cam.id)
		AsyncFileDelete(image)
		if not WriteScreenshot(image, 512, 512) then
			print(string.format("Failed to create screenshot '%s'", image))
		else
			created = created + 1
		end
		Sleep(300)
		cam:RevertProperties()
	end
	SetMouseDeltaMode(false)
	ChangeVideoMode(size:x(), size:y(), 0, false, true)
	WaitChangeVideoMode()
	print(string.format("Creating %d reference images in '%s' finished.", created, folder))
end

---
--- Returns a sorted list of cameras from the specified preset.
---
--- @param context table|nil The context to use for retrieving the cameras. If not provided, the "reference" preset is used.
--- @return table A sorted list of cameras from the specified preset.
---
function GetShowcaseCameras(context)
	local cameras = Presets.Camera[context and context.group or "reference"] or {}
	table.sort(cameras, function(a, b) 
		if a.map==b.map then		
			return a.order < b.order 
		else 
			return a.map<b.map 
		end	
	end)
	
	return cameras
end

---
--- Opens the Showcase dialog, which displays a set of cameras based on the provided context.
---
--- If the Showcase dialog is already open, it will be closed before opening a new one.
---
--- If an `obj` parameter is provided and it is a `Camera` object, the `group` property of the `context` table will be set to the `group` property of the `obj`.
--- If an `obj` parameter is provided and it is a table with at least one element, the `group` property of the `context` table will be set to the `group` property of the first element in the table.
---
--- @param root table The root object of the dialog.
--- @param obj table|nil The object that triggered the opening of the Showcase dialog.
--- @param context table|nil The context to use for the Showcase dialog. If not provided, a new context table will be created.
---
function OpenShowcase(root, obj, context)
	if GetDialog("Showcase") then
		CloseDialog("Showcase")
		return
	end
	
	if obj and IsKindOf(obj, "Camera") then
		local group = obj.group
		context = context or {}
		context.group = group
	elseif obj and type(obj)== "table" and next(obj) then
		local group = obj[1].group
		context = context or {}
		context.group = group
	end
	OpenDialog("Showcase", nil, context)	
end

function OnMsg.GameEnterEditor()
	CloseDialog("Showcase")
end

---
--- Checks if the Camera Editor is currently opened.
---
--- @return boolean true if the Camera Editor is opened, false otherwise
---
function IsCameraEditorOpened()
	local ged = FindGedApp("PresetEditor")
	if not ged then return end
	
	local sel = type(ged.selected_object) == "table" and ged.selected_object[1] or ged.selected_object
	
	return IsKindOf(sel, "Camera")
end
