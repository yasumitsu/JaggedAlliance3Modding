DefineClass.XSetpieceDlg = {
	__parents = { "XDialog" }, 
	ZOrder = 99,
	HandleMouse = true,
	
	skippable = true,
	openedAt = false,
	skipDelay = 250,
	
	setpiece = false,
	setpiece_seed = 0,
	testMode = false,
	triggerUnits = false,
	extra_params = false,
	setpieceInstance = false,
	
	fadeDlg = false,
	lifecycle_thread = false,
	skipping_setpiece = false,
}

---
--- Initializes the XSetpieceDlg class.
---
--- @param parent table The parent dialog.
--- @param context table The context for the setpiece dialog, containing the following fields:
---   - setpiece: string The name of the setpiece to be played.
---   - testMode: boolean Whether the setpiece is in test mode.
---   - triggerUnits: boolean Whether to trigger units.
---   - extra_params: table Additional parameters for the setpiece.
---
--- @return void
function XSetpieceDlg:Init(parent, context)
	self.setpiece     = context and context.setpiece or "MoveTest"
	self.testMode     = context and context.testMode
	self.triggerUnits = context and context.triggerUnits
	self.extra_params = context and context.extra_params or empty_table
	assert(Setpieces[self.setpiece].TakePlayerControl) -- setpieces that don't take control from the player should be run directly via StartSetpiece in a game time thread
	--this is only semi sync when called from entersector rtt..
	NetUpdateHash("SetpieceStateStart")
	ChangeGameState("setpiece_playing", true)
end

---
--- Opens the XSetpieceDlg dialog and sets up the skip hint text.
--- Also starts a game time thread to handle the lifecycle of the dialog.
---
--- @param ... any Additional arguments passed to XDialog.Open
--- @return void
function XSetpieceDlg:Open(...)
	XDialog.Open(self, ...)
	self.openedAt = GameTime()
	
	if rawget(self, "idSkipHint") then
		if GetUIStyleGamepad(nil, self) then
			self.idSkipHint:SetText(T(576896503712, "<ButtonB> Skip"))
		else
			self.idSkipHint:SetText(T(696052205292, "<style SkipHint>Escape: Skip</style>")) -- no icon for Esc button
		end
	end
	
	self.lifecycle_thread = CreateGameTimeThread(XSetpieceDlg.Lifecycle, self)
end

DefineClass.XMovieBlackBars = {
	__parents = {"XDialog"},
	top = false,
	bottom = false
}

---
--- Opens the XMovieBlackBars dialog and creates the black bar controls.
---
--- This function opens the XMovieBlackBars dialog and calls the CreateBlackBarControls
--- function to create the black bar controls that frame the content of the dialog.
---
--- @return void
function XMovieBlackBars:Open()
	XDialog.Open(self)
	self:CreateBlackBarControls()
end

--- Creates the black bar controls for the XMovieBlackBars dialog.
---
--- This function creates four XWindow controls that are used as black bars
--- to frame the content of the dialog. The bars are positioned on the
--- top, bottom, left, and right sides of the dialog, and their size is
--- adjusted to maintain a 16:9 aspect ratio.
---
--- @return void
function XMovieBlackBars:CreateBlackBarControls()
	local top = XTemplateSpawn("XWindow", self)
	top:SetDock("top")
	top:SetBackground(RGBA(0, 0, 0, 255))
	top:Open()
	top.scale = point(1000, 1000)
	top.SetOutsideScale = empty_func
	self.top = top
	
	local bottom = XTemplateSpawn("XWindow", self)
	bottom:SetDock("bottom")
	bottom:SetBackground(RGBA(0, 0, 0, 255))
	bottom:Open()
	bottom.scale = point(1000, 1000)
	bottom.SetOutsideScale = empty_func
	self.bottom = bottom
	
	local left = XTemplateSpawn("XWindow", self)
	left:SetDock("left")
	left:SetBackground(RGBA(0, 0, 0, 255))
	left:Open()
	left.scale = point(1000, 1000)
	left.SetOutsideScale = empty_func
	self.left = left
	
	local right = XTemplateSpawn("XWindow", self)
	right:SetDock("right")
	right:SetBackground(RGBA(0, 0, 0, 255))
	right:Open()
	right.scale = point(1000, 1000)
	right.SetOutsideScale = empty_func
	self.right = right
end

--- Sets the black bar controls to be displayed on the left and right sides of the dialog.
---
--- This function sets the visibility and docking properties of the black bar controls
--- to display them on the left and right sides of the dialog, rather than the top and
--- bottom. This is used to maintain a 16:9 aspect ratio when the dialog size does not
--- match the 16:9 ratio.
---
--- @return void
function XMovieBlackBars:SetBarsOnSides()
	self.left:SetDock("left")
	self.right:SetDock("right")
	self.top:SetDock(false)
	self.bottom:SetDock(false)
	self.top:SetVisible(false)
	self.bottom:SetVisible(false)
	self.left:SetVisible(true)
	self.right:SetVisible(true)
end

--- Sets the black bar controls to be displayed on the top and bottom of the dialog.
---
--- This function sets the visibility and docking properties of the black bar controls
--- to display them on the top and bottom of the dialog, rather than the left and
--- right sides. This is used to maintain a 16:9 aspect ratio when the dialog size does not
--- match the 16:9 ratio.
---
--- @return void
function XMovieBlackBars:SetBarsTopBottom()
	self.left:SetDock(false)
	self.right:SetDock(false)
	self.top:SetDock("top")
	self.bottom:SetDock("bottom")
	self.left:SetVisible(false)
	self.right:SetVisible(false)
	self.top:SetVisible(true)
	self.bottom:SetVisible(true)
end

--- Sets the layout space for the black bar controls to maintain a 16:9 aspect ratio.
---
--- This function calculates the appropriate size and position of the black bar controls
--- to maintain a 16:9 aspect ratio within the given layout space. It determines whether
--- the black bars should be displayed on the sides or the top/bottom of the dialog
--- based on the aspect ratio of the layout space.
---
--- @param x number The x-coordinate of the layout space.
--- @param y number The y-coordinate of the layout space.
--- @param width number The width of the layout space.
--- @param height number The height of the layout space.
--- @return boolean True if the layout space was successfully set, false otherwise.
function XMovieBlackBars:SetLayoutSpace(x, y, width, height)
	local targetRatio = MulDivRound(16, 100, 9) -- 16:9
	local aspectWidth = width
	local aspectHeight = MulDivRound(width, 100, targetRatio)
	if aspectHeight > height then
		-- wider than 16:9 - strips on the sides
		aspectWidth = MulDivRound(height, targetRatio, 100)
		local blackBarWidth = (width - aspectWidth) / 2
		local blackBarWidth = Max(blackBarWidth, 100)
		self.left:SetMinWidth(blackBarWidth)
		self.right:SetMinWidth(blackBarWidth)
		self.left:SetMinHeight(height)
		self.right:SetMinHeight(height)
		self:SetBarsOnSides()
	else
		-- narrower than 16:9 - strips on top/bottom
		aspectWidth = MulDivRound(height, targetRatio, 100)
		aspectHeight = MulDivRound(aspectWidth, 100, targetRatio)
		local blackBarHeight = (height - aspectHeight) / 2
		blackBarHeight = Max(blackBarHeight, 100)
		self.top:SetMinWidth(width)
		self.bottom:SetMinWidth(width)
		self.top:SetMinHeight(blackBarHeight)
		self.bottom:SetMinHeight(blackBarHeight)
		self:SetBarsTopBottom()
	end
	
	return XWindow.SetLayoutSpace(self, x, y, width, height)
end


function OnMsg.Autorun()
	NetSyncEvents.SetPieceDoneWaitingLS = SetPieceDoneWaitingLS
end

--- Notifies that the setpiece is done waiting for the loading screen to close.
---
--- This function is called when the setpiece is ready to continue after the loading
--- screen has closed. It is used to synchronize the setpiece progress across
--- multiplayer clients.
function SetPieceDoneWaitingLS()
	Msg("SetPieceDoneWaitingLS")
end

--- Closes the loading game loading screen.
---
--- This function is used to close the loading game loading screen, which is a
--- Zulu-specific implementation. It is likely called when the loading screen
--- is no longer needed, such as when the game has finished loading.
function CloseLoadGameLoadingScreen()
	-- zulu specific code moved to zulu
end

---
--- Handles the lifecycle of an XSetpieceDlg, including starting the setpiece, waiting for its completion, and performing cleanup.
---
--- This function is responsible for the following tasks:
--- - Closes the loading game loading screen
--- - Starts the setpiece and notifies that it has started
--- - Hides UI elements, locks the camera, and displays black bars
--- - Waits for the loading screen to close, or synchronizes the setpiece completion across multiplayer clients
--- - Spawns a child window to hold the setpiece UI
--- - Starts the setpiece and waits for its completion
--- - Restores the camera and game state after the setpiece has ended
--- - Performs cleanup and closes the XSetpieceDlg
---
--- @param self XSetpieceDlg The instance of the XSetpieceDlg
function XSetpieceDlg:Lifecycle()
	CloseLoadGameLoadingScreen()
	
	local setpiece = Setpieces[self.setpiece]
	Msg("SetpieceStarting", setpiece)
	OnSetpieceStarted(setpiece)
	local camera = { GetCamera() }
	
	-- Hide UI, black bars, lock camera
	XTemplateSpawn("XCameraLockLayer", self):Open()
	XHideDialogs:new({Id = "idHideDialogs", LeaveDialogIds = self:HasMember("LeaveDialogsOpen") and self.LeaveDialogsOpen or false}, self):Open()
	local blackbars = XTemplateSpawn("XMovieBlackBars", self)
	blackbars:SetId("BlackBars")
	blackbars:Open()

	if not netInGame or table.count(netGamePlayers) <= 1 then
		WaitLoadingScreenClose()
	else
		if NetIsHost() then
			local dlg = GetLoadingScreenDialog()
			if dlg then
				WaitLoadingScreenClose()
			end
			
			NetSyncEvent("SetPieceDoneWaitingLS")
		end
		WaitMsg("SetPieceDoneWaitingLS", 60000)
	end
	NetUpdateHash("XSetpieceDlg:Lifecycle_Starting")

	-- Interface spawned by the setpiece should be in this child, which is
	-- below the letterboxing window.
	local uiChildren = XTemplateSpawn("XWindow", self)
	uiChildren:SetId("idSetpieceUI")
	uiChildren:Open()
	uiChildren:SetZOrder(0)
	
	self.setpieceInstance = StartSetpiece(self.setpiece, self.testMode, self.setpiece_seed, self.triggerUnits, unpack_params(self.extra_params))
	Msg("SetpieceStarted", setpiece)
	
	self:WaitSetpieceCompletion()
	Msg("SetpieceEnding", setpiece)
	
	local skipHint = rawget(self, "idSkipHint")
	if skipHint then skipHint:Close() end
	
	if setpiece.RestoreCamera then
		SetCamera(unpack_params(camera))
	else
		SetupInitialCamera()
	end

	NetUpdateHash("SetpieceStateDone")
	ChangeGameState("setpiece_playing", false)
	sprocall(EndSetpiece, self.setpiece)
	Msg("SetpieceEnded", setpiece) -- this releases control when executing sequential effects, any sleeps in gametimes after this are prone to never exiting due to game getting paused
	
	-- some deinitialization (e.g. restoring Ambient Life unit positions) is done at SetpieceEnded
	-- wait several frames to make sure nothing from that is seen on screen
	WaitNextFrame(7)
	self:Close() -- must be before EndSetpiece and the Msg, so IsSetpiecePlaying returns false during their execution
end

---
--- Returns the fade window for the XSetpieceDlg.
--- If the fade window doesn't exist, it creates a new one and returns it.
---
--- @return XWindow The fade window for the XSetpieceDlg.
function XSetpieceDlg:GetFadeWin()
	if not self.fadeDlg then
		local fadeWin = XWindow:new({
			Visible = false,
			Background = RGBA(0, 0, 0, 255),
			AddInterpolation = function(self, int, idx)
				if not int then return end
				int.flags = (int.flags or 0) | const.intfGameTime
				return XWindow.AddInterpolation(self, int, idx)
			end,
		}, self)
		fadeWin:Open()
		self.fadeDlg = fadeWin
	end
	return self.fadeDlg
end

---
--- Fades out the XSetpieceDlg by making the fade window visible with a fade-in animation.
---
--- If the `skipping_setpiece` flag is set, this function will return without doing anything to avoid messing up the fade out screen created by the skipping logic.
---
--- @param fadeOutTime number The duration of the fade-out animation in seconds.
---
function XSetpieceDlg:FadeOut(fadeOutTime)
	if self.skipping_setpiece then return end -- don't mess up the fade out screen created by the skipping logic
	
	local fade_win = self:GetFadeWin()
	local fade_time = fadeOutTime
	if fade_time > 0 then
		if fade_win:GetVisible() then return end -- game is already faded out, nothing to do
		fade_win.FadeInTime = fade_time
		fade_win:SetVisible(true)
		Sleep(fade_time)
	else
		fade_win:SetVisible(true, "instant")
	end
end

---
--- Fades in the XSetpieceDlg by making the fade window visible with a fade-out animation.
---
--- If the `skipping_setpiece` flag is set, this function will return without doing anything to avoid messing up the fade out screen created by the skipping logic.
---
--- @param fadeInDelay number The delay before the fade-in animation starts, in seconds.
--- @param fadeInTime number The duration of the fade-in animation in seconds.
---
function XSetpieceDlg:FadeIn(fadeInDelay, fadeInTime)
	if self.skipping_setpiece then return end -- don't mess up the fade out screen created by the skipping logic
	
	local fade_win = self:GetFadeWin()
	fade_win.FadeOutTime = fadeInTime
	fade_win:SetVisible(true, "instant")
	Sleep(fadeInDelay or self.fadeOutDelay)
	fade_win:SetVisible(false)
	Sleep(fade_win.FadeOutTime)
end

---
--- Waits for the setpiece instance to be started, then waits for the setpiece to complete.
---
--- This function is used to ensure that the setpiece has fully completed before continuing execution.
---
--- @param self XSetpieceDlg The instance of the XSetpieceDlg object.
---
function XSetpieceDlg:WaitSetpieceCompletion()
	while not self.setpieceInstance do
		WaitMsg("SetpieceStarted", 300)
	end
	self.setpieceInstance:WaitCompletion()
end

---
--- Skips the given setpiece instance.
---
--- @param setpieceInstance table The setpiece instance to skip.
---
function SkipSetpiece(setpieceInstance)
	setpieceInstance:Skip()
end

---
--- Handles keyboard shortcuts and input for the XSetpieceDlg.
---
--- This function is called when a keyboard shortcut or input is detected while the XSetpieceDlg is open. It checks various conditions to determine if the input should be used to skip the current setpiece.
---
--- @param self XSetpieceDlg The instance of the XSetpieceDlg object.
--- @param shortcut string The name of the keyboard shortcut that was detected.
--- @param source string The source of the input (e.g. "keyboard", "gamepad").
--- @param ... any Additional arguments passed with the input.
--- @return string|nil If the input should be "broken" (i.e. not processed further), returns "break"; otherwise, returns nil.
---
function XSetpieceDlg:OnShortcut(shortcut, source, ...)
	if GameTime() - self.openedAt < self.skipDelay then return "break" end
	if RealTime() - terminal.activate_time < self.skipDelay then return "break" end
	if rawget(self, "skip_input_done") then return end
	
	if rawget(self, "idSkipHint") and not self.idSkipHint:GetVisible() then
		self.idSkipHint:SetVisible(true)
		return "break"
	end
	if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return end
	if self.skippable and self.setpieceInstance and (not IsRecording() or shortcut == "Escape") then
		local skipHint = rawget(self, "idSkipHint")
		if skipHint then 
			skipHint:SetVisible(false)
		end
		rawset(self, "skip_input_done", true)
		SkipSetpiece(self.setpieceInstance)
		return "break"
	end
end

---
--- Skips any setpieces that are currently playing.
---
--- This function checks if the "XSetpieceDlg" dialog is open, and if so, it skips the current setpiece instance. It then waits for the setpiece to complete and the "SetpieceEnded" message to be received.
---
--- @return nil
---
function SkipAnySetpieces()
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		if dlg.setpieceInstance then
			dlg.setpieceInstance:Skip()
			dlg:WaitSetpieceCompletion()
			while GameState.setpiece_playing do
				WaitMsg("SetpieceEnded", 100)
			end
		end
	end
end

---
--- Checks if a setpiece is currently playing.
---
--- @return boolean true if a setpiece is playing, false otherwise
---
function IsSetpiecePlaying()
	return GameState.setpiece_playing
end

---
--- Checks if the XSetpieceDlg is in test mode.
---
--- @return boolean true if the XSetpieceDlg is in test mode, false otherwise
---
function IsSetpieceTestMode()
	local dlg = GetDialog("XSetpieceDlg")
	return dlg and dlg.testMode
end

---
--- Waits for the currently playing setpiece to complete.
---
--- This function checks if the "XSetpieceDlg" dialog is open, and if so, it waits for the setpiece to complete and the "SetpieceEnded" message to be received.
---
--- @return nil
---
function WaitPlayingSetpiece()
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		dlg:Wait()
	end
end

function OnMsg.SetpieceStarted()
	ObjModified("setpiece_observe")
end

function OnMsg.SetpieceDialogClosed()
	ObjModified("setpiece_observe")
end

---
--- Records a movie of a setpiece.
---
--- @param id string The ID of the setpiece to record.
--- @param duration number The duration of the movie in seconds.
--- @param quality number The quality of the movie, from 0 to 100.
--- @param shutter number The shutter speed of the movie, from 0 to 100.
---
--- @return nil
---
function MovieRecordSetpiece(id, duration, quality, shutter)
	quality = quality or 64
	shutter = shutter or 0
	OpenDialog("XSetpieceDlg", false, {setpiece = id }) 
	RecordMovie(id .. ".tga", 0, 60, duration, quality, shutter, function() return not IsSetpiecePlaying() end)
end