----- XPauseLayer

DefineClass.XPauseLayer = {
	__parents = { "XLayer" },
	properties = {
		{ category = "General", id = "keep_sounds", name = "Keep Sounds", editor = "bool", default = false },
		{ category = "General", id = "togglePauseDialog", name = "Toggle Pause Dialog", editor = "bool", default = true },
	},
	Dock = "ignore",
	HandleMouse = false,
}

---
--- Initializes the XPauseLayer.
--- When the layer is created, this function will be called to set up the pause state and show the pause dialog if configured.
---
--- @param self XPauseLayer
---
function XPauseLayer:Init()
	CreateRealTimeThread(function(self)
		if self.window_state ~= "destroying" then
			SetPauseLayerPause(true, self, self.keep_sounds)
			if self.togglePauseDialog then
				ShowPauseDialog(true)
			end
			ShowMouseCursor(self)
		end
	end, self)
end

---
--- Restores the game state after the pause layer has been removed.
--- This function is called when the XPauseLayer is being destroyed.
--- It resumes the game, hides the pause dialog if it was shown, and hides the mouse cursor.
---
--- @param self XPauseLayer
---
function XPauseLayer:Done()
	SetPauseLayerPause(false, self, self.keep_sounds)
	if self.togglePauseDialog then
		ShowPauseDialog(false)
	end
	HideMouseCursor(self)
end

--override in project specific file
---
--- Sets the pause state of the specified layer.
---
--- @param pause boolean Whether to pause or resume the layer.
--- @param layer XPauseLayer The layer to pause or resume.
--- @param keep_sounds boolean Whether to keep sounds playing while paused.
---
function SetPauseLayerPause(pause, layer, keep_sounds)
	if pause then
		Pause(layer, keep_sounds)
	else
		Resume(layer)
	end
end

---
--- Shows or hides the pause dialog.
---
--- @param bShow boolean Whether to show or hide the pause dialog.
---
function ShowPauseDialog(bShow)
	--implement in project specific file
end

----- XSuppressInputLayer

DefineClass.XSuppressInputLayer = {
	__parents = { "XLayer" },
	properties = {
		{ id = "SuppressTemporarily", editor = "bool", default = true, help = "If true, will suppress any input only for a short time" },
	},
	target = false,
	Dock = "ignore",
	HandleMouse = false,
}

local passthrough_events = {
	OnSystemSize = true,
	OnSystemActivate = true,
	OnSystemInactivate = true,
	OnSystemMinimize = true,
}

---
--- Initializes the XSuppressInputLayer.
--- This layer is used to temporarily suppress input events.
---
--- @param self XSuppressInputLayer The XSuppressInputLayer instance.
---
function XSuppressInputLayer:Init()
	local function stub_break(target, event)
		if not IsValidThread(SwitchControlQuestionThread) and not passthrough_events[event] then
			return "break"
		end
	end
	self.target = TerminalTarget:new{
		MouseEvent = stub_break,
		KeyboardEvent = stub_break,
		SysEvent = stub_break,
		XEvent = stub_break,
		terminal_target_priority = 10000000,
	}
	terminal.AddTarget(self.target)
end

---
--- Opens the XSuppressInputLayer and optionally suppresses input temporarily.
---
--- @param self XSuppressInputLayer The XSuppressInputLayer instance.
--- @param ... any Additional arguments passed to the Open method.
---
function XSuppressInputLayer:Open(...)
	XLayer.Open(self, ...)
	if self.SuppressTemporarily then
		self:CreateThread(function()
			Sleep(self:ResolveValue("SuppressTime") or 200)
			self:delete()
		end)
	end
end

---
--- Removes the TerminalTarget associated with the XSuppressInputLayer instance.
---
--- This function is called when the XSuppressInputLayer is closed or destroyed.
---
--- @param self XSuppressInputLayer The XSuppressInputLayer instance.
---
function XSuppressInputLayer:Done()
	terminal.RemoveTarget(self.target)
end


DefineClass.XShowMouseCursorLayer = {
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
}


---
--- Opens the XShowMouseCursorLayer and shows the mouse cursor.
---
--- @param self XShowMouseCursorLayer The XShowMouseCursorLayer instance.
--- @param ... any Additional arguments passed to the Open method.
---
--- @return any The return value of XLayer.Open(self, ...)
---
function XShowMouseCursorLayer:Open(...)
	ShowMouseCursor("XShowMouseCursorLayer")
	return XLayer.Open(self, ...)
end

---
--- Removes the TerminalTarget associated with the XShowMouseCursorLayer instance.
---
--- This function is called when the XShowMouseCursorLayer is closed or destroyed.
---
--- @param self XShowMouseCursorLayer The XShowMouseCursorLayer instance.
---
function XShowMouseCursorLayer:Done()
	HideMouseCursor("XShowMouseCursorLayer")
end

----- XHideInGameInterfaceLayer

DefineClass.XHideInGameInterfaceLayer = { 
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
}

---
--- Initializes the XHideInGameInterfaceLayer by hiding the in-game interface.
---
--- This function is called when the XHideInGameInterfaceLayer is created.
---
--- @param self XHideInGameInterfaceLayer The XHideInGameInterfaceLayer instance.
---
function XHideInGameInterfaceLayer:Init()
	ShowInGameInterface(false)
end

---
--- Restores the in-game interface when the XHideInGameInterfaceLayer is closed or destroyed.
---
--- This function is called when the XHideInGameInterfaceLayer is closed or destroyed.
---
--- @param self XHideInGameInterfaceLayer The XHideInGameInterfaceLayer instance.
---
function XHideInGameInterfaceLayer:Done()
	if GetInGameInterface() then
		ShowInGameInterface(true)
	end
end


----- XCameraLockLayer

DefineClass.XCameraLockLayer = { 
	__parents = { "XLayer" },
	properties = {
		{ category = "General", id = "lock_id", name = "LockId", editor = "text", default = false },
	},
	Dock = "ignore",
	HandleMouse = false,
}

---
--- Locks the camera to the specified lock ID or the layer instance itself.
---
--- This function is called when the XCameraLockLayer is opened.
---
--- @param self XCameraLockLayer The XCameraLockLayer instance.
---
function XCameraLockLayer:Open()
	LockCamera(self.lock_id or self)
	XLayer.Open(self)
end

---
--- Restores the camera lock when the XCameraLockLayer is closed or destroyed.
---
--- This function is called when the XCameraLockLayer is closed or destroyed.
---
--- @param self XCameraLockLayer The XCameraLockLayer instance.
---
function XCameraLockLayer:Done()
	UnlockCamera(self.lock_id or self)
end


----- XChangeCameraTypeLayer

local cameraTypes = { "cameraRTS", "cameraFly", "camera3p", "cameraMax", "cameraTac" }

DefineClass.XChangeCameraTypeLayer = {
	__parents = { "XLayer" },
	properties = {
		{ id = "CameraType", editor = "choice", default = "cameraMax", items = cameraTypes },
		{ id = "CameraClampZ",  editor = "number", default = 0,  },
		{ id = "CameraClampXY", editor = "number", default = 0,  },
	},
	Dock = "ignore",
	HandleMouse = false,
	
	old_camera = false,
	old_limits = false,
}

---
--- Initializes the XChangeCameraTypeLayer.
---
--- This function is called when the XChangeCameraTypeLayer is created.
---
--- It saves the current camera settings, applies the new camera clamp settings, and activates the new camera type.
---
--- @param self XChangeCameraTypeLayer The XChangeCameraTypeLayer instance.
---
function XChangeCameraTypeLayer:Init()
	self.old_camera = pack_params(GetCamera())
	self.old_limits = {}
	if self.CameraClampZ ~= 0 then
		self.old_limits.CameraMaxClampZ = hr.CameraMaxClampZ
		hr.CameraMaxClampZ = self.CameraClampZ
	end
	if self.CameraClampXY ~= 0 then
		self.old_limits.CameraMaxClampXY = hr.CameraMaxClampXY
		hr.CameraMaxClampXY = self.CameraClampXY
	end
	ForceUnlockCameraStart(self)
	_G[self.CameraType].Activate(1)
end

---
--- Restores the camera settings to the previous state when the XChangeCameraTypeLayer was initialized.
---
--- This function is called when the XChangeCameraTypeLayer is closed or destroyed.
---
--- It sets the camera back to the previous settings, unlocks the camera, and restores any camera clamp settings that were changed.
---
--- @param self XChangeCameraTypeLayer The XChangeCameraTypeLayer instance.
---
function XChangeCameraTypeLayer:Done()
	SetCamera(unpack_params(self.old_camera))
	ForceUnlockCameraEnd(self)
	for key, val in pairs(self.old_limits or empty_table) do
		hr[key] = val
	end
end


-- XMuteSounds

DefineClass.XMuteSounds = {
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
	properties = {
		{ id = "MuteAll", editor = "bool", default = false },
		{ id = "FadeTime", editor = "number", default = 500 },
		{ id = "AudioGroups", editor = "set", default = set(), items = PresetGroupsCombo("SoundTypePreset"), no_edit = PropGetter("MuteAll") },
	},
}

---
--- Applies or removes muting of audio groups.
---
--- If `apply` is true, mutes all audio groups specified by `self.AudioGroups` or all audio groups if `self.MuteAll` is true. If `apply` is false, restores the volume of the muted audio groups.
---
--- The muting is applied with a fade time specified by `self.FadeTime`.
---
--- @param self XMuteSounds The XMuteSounds instance.
--- @param apply boolean True to mute the audio groups, false to restore the volume.
--- @param time number (optional) The fade time in milliseconds. Defaults to `self.FadeTime`.
---
function XMuteSounds:ApplyMute(apply, time)
	local groups = self.MuteAll and PresetGroupNames("SoundTypePreset") or table.keys(self.AudioGroups, true)
	for _, group in ipairs(groups) do
		SetGroupVolumeReason(self, group, apply and 0, self.FadeTime)
	end
end

---
--- Opens the XMuteSounds layer and applies muting to the specified audio groups.
---
--- This function is called when the XMuteSounds layer is opened. It mutes all audio groups specified by `self.AudioGroups` or all audio groups if `self.MuteAll` is true, using the fade time specified by `self.FadeTime`.
---
--- @param self XMuteSounds The XMuteSounds instance.
---
function XMuteSounds:Open()
	self:ApplyMute(true)
	XLayer.Open(self)
end

---
--- Restores the volume of any audio groups that were muted by the `XMuteSounds:ApplyMute()` function.
---
--- This function is called when the `XMuteSounds` layer is closed, to undo any muting that was applied when the layer was opened.
---
--- @param self XMuteSounds The `XMuteSounds` instance.
---
function XMuteSounds:Done()
	self:ApplyMute(false)
end


----- XHROption

DefineClass.XHROption = {
	__parents = { "XWindow" },
	Dock = "ignore",
	properties = {
		{ category = "General", id = "Option", editor = "choice", default = "", items = function () return table.keys2(EnumEngineVars("hr."), true, "") end },
		{ category = "General", id = "Value", editor = function(self)
			return type(GetEngineVar("hr.", self.Option or "")) == "number" and "number" or "bool"
		end, default = false, scale = 1000 },
	},
}

---
--- Opens the XHROption window and applies any changes to the HR engine variables.
---
--- This function is called when the XHROption window is opened. It first sets the window to be invisible, then checks if the `Option` property is set. If it is, it updates the corresponding HR engine variable with the `Value` property, scaling the value if the engine variable is a number. Finally, it calls the `XWindow.Open()` function to open the window.
---
--- @param self XHROption The XHROption instance.
---
function XHROption:Open()
	self:SetVisible(false)
	if self.Option ~= "" then
		if type(GetEngineVar("hr.", self.Option or "")) == "number" then 
			table.change(hr, self, { [self.Option] = (self.Value or 0) / 1000.0 })
		else
			table.change(hr, self, { [self.Option] = self.Value })
		end
	end
	XWindow.Open(self)
end

---
--- Restores the HR engine variables to their previous state before the `XHROption:Open()` function was called.
---
--- This function is called when the `XHROption` window is closed, to undo any changes that were made to the HR engine variables when the window was opened.
---
--- @param self XHROption The `XHROption` instance.
---
function XHROption:Done()
	table.restore(hr, self, true)
end