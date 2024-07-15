if FirstLoad then
	LoadingScreenTipsRate = 10000
	LoadingScreenLog = {}
end	

LoadingScreenOrgSize = point(1920, 1080)

local lsprintf = CreatePrint{
	--"loading screen",
	format = "printf",
	timestamp = true,
}

---
--- Returns the class name for the loading screen dialog with the given ID.
---
--- @param id string The ID of the loading screen dialog.
--- @return string The class name for the loading screen dialog.
function LoadingScreenGetClassById(id)
	if id == "idSaveProfile" then
		return "BaseSavingScreen"
	elseif id == "idAutosaveScreen" then
		return "AutosaveScreen"
	elseif id == "idQuickSaveScreen" then
		return "QuickSaveScreen"
	end
	return "XLoadingScreen"
end

---
--- Returns the most recent loading screen dialog, excluding the account storage dialog if requested.
---
--- @param exceptAccountStorage boolean If true, the account storage dialog will be excluded from the result.
--- @return Dialog The most recent loading screen dialog, or nil if none exists.
function GetLoadingScreenDialog(exceptAccountStorage)
	local dlg = GetDialog(LoadingScreenLog[#LoadingScreenLog])
	if exceptAccountStorage and dlg then
		if not dlg.context or dlg.context.id ~= "idSaveProfile" then
			return dlg
		end
	else
		return dlg
	end
end

local function LoadingScreenCreate(class, id, reason, info_text, metadata)
	lsprintf("Creating: class = %s, id = %s, reason = %s", class, tostring(id), tostring(reason))
	table.insert(LoadingScreenLog, class)
	local dlg = OpenDialog(class, nil, {id = id,reason = reason, info_text = info_text, metadata = metadata}, reason)
	--[[
	-- the saving animation cannot be implemented using a transition effect
	if dlg.saving and rawget(dlg, "idSavingAnim") then
		dlg.idSavingAnim:CreateTransition{
			keeprender = true,
			fadeIn = 500,
			fadeOut = 1000,
			angle = 360, angleRevert = true, angleTime = 1000,
			srcangle = 0,
			time = 500000,
		}
	end
	--]]
	if dlg.game_blocking then
		Pause(dlg)
		LockCamera(dlg)
		ChangeGameState("loading", true)
		if info_text and rawget(dlg, "idInfoText") then
			dlg.idInfoText:SetText(info_text)
		end
		local atTips = dlg.show_tips and (rawget(dlg, "idTips") or rawget(dlg, "idContainer") and rawget(dlg.idContainer, "idTips"))
		if atTips and tips.InitTips() then
			local last_tip_id = 0
			local selected_tips = {}
			for i = 1, 5 do
				local tip, id
				repeat
					tip, id = tips.GetNextTip()
				until id ~= last_tip_id
				last_tip_id = id
				selected_tips[#selected_tips + 1] = _InternalTranslate(tip)
			end
			dlg:CreateThread(function()
				local idx = 1
				while true do
					atTips:SetText(Untranslated(selected_tips[idx]))
					idx = (idx + 1) > #selected_tips and 1 or (idx + 1)
					Sleep(LoadingScreenTipsRate)
				end
			end)
		end
	end
	dlg.clock_opened = GetClock()
	return dlg
end

---
--- Executes a function while the loading screen is open.
---
--- @param id string The ID of the loading screen to open.
--- @param reason string The reason for opening the loading screen.
--- @param func function The function to execute while the loading screen is open.
--- @return any The result of the executed function.
function LoadingScreenExecute(id, reason, func)
	LoadingScreenOpen(id, reason)
	local result = func()
	LoadingScreenClose(id, reason)
	return result
end

---
--- Opens a loading screen dialog with the specified ID and reason.
---
--- @param id string The ID of the loading screen to open.
--- @param reason string The reason for opening the loading screen.
--- @param first_tip string The first tip to display on the loading screen.
--- @param metadata table Optional metadata to pass to the loading screen.
---
function LoadingScreenOpen(id, reason, first_tip, metadata)
	assert(IsRealTimeThread(), "The loading screen requires a real time thread")
	lsprintf("Opening %s, reason = %s", tostring(id), tostring(reason))
	local class = LoadingScreenGetClassById(id)
	if not class then
		assert(false, "No loading screen class matches " .. tostring(id))
		return
	end
	local dlg = GetDialog(class)
	if dlg and dlg.window_state == "closing" then
		local modifier = dlg:FindModifier("fade")
		if modifier then
			modifier.on_complete = function() end
		end
		dlg:delete()
		dlg = nil
	end
	dlg = dlg or LoadingScreenCreate(class, id, reason, first_tip, metadata)
	dlg:AddOpenReason(reason)
	lsprintf("Opened %s, reason = %s", tostring(id), tostring(reason))
	if dlg.game_blocking then
		WaitNextFrame(5) -- wait for UI to be rendered
	end
end

---
--- Closes a loading screen dialog with the specified ID and reason.
---
--- @param id string The ID of the loading screen to close.
--- @param reason string The reason for closing the loading screen.
---
function LoadingScreenClose(id, reason)
	lsprintf("Closing %s, reason = %s", tostring(id), tostring(reason))
	local class = LoadingScreenGetClassById(id)
	local dlg = class and GetDialog(class)
	if not dlg then
		lsprintf("Closing %s cancelled, no dialog", tostring(id))
		return
	end
	
	if not dlg:GetOpenReasons()[reason] then
		print("Trying to close a Loading/Saving screen with id/reason that aren't used for opening: " .. tostring(reason))
		print("Active reasons:", table.concat(table.keys2(dlg:GetOpenReasons()), " "))
		lsprintf("Closing %s cancelled, no reason", tostring(id))
		return
	end
	
	if dlg:RemoveOpenReason(reason) then -- return true in case we should close the dialog
		lsprintf("Closing %s, no reasons left", tostring(id))
		-- add the reason back to make sure LoadingScreenOpen doesn't try to open the same dialog
		dlg:AddOpenReason(reason)
		local parent_thread = CurrentThread()
		local game_blocking = dlg.game_blocking
		CreateRealTimeThread(function()
			while dlg.clock_opened == 0 do
				Sleep(17)
			end
			
			local clock_closed = dlg.clock_opened
			if dlg.saving then
				clock_closed = clock_closed + 3141
			elseif game_blocking then
				clock_closed = clock_closed + (dlg.close_delay or 1200)
			end
			lsprintf("Closing %s, waiting clock", tostring(id))
			while GetClock() - clock_closed < 0 do
				Sleep(30)
			end
			
			-- check if we still need to close the dialog
			lsprintf("Closing %s, checking for reopen", tostring(id))
			if dlg:RemoveOpenReason(reason) then
				lsprintf("Closing %s, final closing", tostring(id))
				if game_blocking then
					-- if there are other loading screens opened at the moment, don't bother with the render mode, the last one will take care
					local dlgs = ListDialogs()
					local unblock = true
					for i = 1, #dlgs do
						local d = GetDialog(dlgs[i])
						if d ~= dlg and d:IsKindOf("BaseLoadingScreen") and d.game_blocking then
							unblock = false
							break
						end
					end
					if unblock and GetMap() ~= "" then
						if not dlg.saving then
							WaitNextFrame(3) 
							SetupViews()
						end
					end
					ChangeGameState("loading", not unblock)
					UnlockCamera(dlg)
					Resume(dlg)
				end
				--assert(next(dlg.ids_and_reasons) == nil, "Loading screen reopened too soon after being closed! Please use a single screen that encompasses both operations!")
				-- Recheck again if we should close: while waiting for "scene" render mode above, someone could have closed it
				if not next(dlg:GetOpenReasons()) then
					-- Give a chance to those who want to open something before the loading screen closes
					Msg("LoadingScreenPreClose")
					WaitNextFrame()
					
					-- Recheck again if we should close: while waiting above, someone could have added a new open reason
					if not next(dlg:GetOpenReasons()) then
						if dlg.window_state ~= "destroying" then
							dlg:Close("final")
							table.remove_entry(LoadingScreenLog, class)
						end
						lsprintf("Closed %s, reason = %s", tostring(id), tostring(reason))
					end
				end
				if next(dlg:GetOpenReasons()) then
					lsprintf("Cancelled closing, we have a new reason to live", next(dlg:GetOpenReasons()))
				end
			end
			if game_blocking then
				Wakeup(parent_thread)
			end
		end)
		if game_blocking then
			WaitWakeup()
		end
	end
end

DefineClass.BaseLoadingScreen = {
	__parents = { "XDialog" },
	properties = {
		{ category = "LoadingScreen", id = "game_blocking", editor = "bool", default = true, },
	},
	clock_opened = 0,
	close_delay = false,
	saving = false,
	show_tips = true,
	ZOrder = 1000000000,
	MouseCursor = "CommonAssets/UI/waitcursor.tga",
	HandleMouse = true,
	image = "UI/SplashScreen.tga",
	transparent = false,
	FocusOnOpen = "",
}

---
--- Opens the loading screen dialog.
---
--- @param self BaseLoadingScreen
--- @param ... any
--- @return void
function BaseLoadingScreen:Open(...)
	XDialog.Open(self, ...)
	ShowMouseCursor("Loading screen")
	if self.game_blocking then
		self:SetModal()
		self:SetFocus()
	end
	if self.transparent then
		self:SetMouseCursor(false)
		self.HandleMouse = false
		self.ChildrenHandleMouse = false
	end
	if rawget(self, "idImage") then
		self.idImage:SetImage(self.image)
	end
end

---
--- Handles keyboard shortcuts for the BaseLoadingScreen class.
---
--- @param self BaseLoadingScreen
--- @param shortcut string The keyboard shortcut that was triggered.
--- @param source any The source of the keyboard shortcut.
--- @param ... any Additional arguments.
--- @return string "continue" if the bug reporter shortcut was triggered, "break" if the game is blocking and no message boxes are open, otherwise nil.
---
function BaseLoadingScreen:OnShortcut(shortcut, source, ...)
	if (Platform.publisher or Platform.developer) and shortcut == "Ctrl-F1" then
		return "continue" -- allow bug reporter
	end
	if self.game_blocking and not AreMessageBoxesOpen() then
		return "break"
	end
end

---
--- Closes the loading screen dialog.
---
--- @param self BaseLoadingScreen
--- @param result string The result of closing the dialog, either "final" or nil.
--- @return void
function BaseLoadingScreen:Close(result)
	if result == "final" then
		HideMouseCursor("Loading screen")
		XWindow.Close(self)
	end
end

DefineClass.BaseSavingScreen = {
	__parents = { "BaseLoadingScreen" },
	saving = true,
	game_blocking = false,
	image = false,
	transparent = true,
}

---
--- Gets the currently open loading screen dialog with the given ID.
---
--- @param id string The ID of the loading screen dialog to get.
--- @return boolean true if a loading screen dialog with the given ID is open, false otherwise.
---
function GetOpenLoadingScreen(id)
	local class = LoadingScreenGetClassById(id)
	return class and GetDialog(class) and true or false
end

---
--- Draws a splash screen image that fills the entire screen.
---
--- This function is a stub that should be redefined per project. It is called before the initialization of the classes system, so it can only use pure UIL calls.
---
--- It mimics the behavior of the bink player by stretching the image to fill the entire screen, without measuring the image size (which can fail in some cases). It uses a 16:9 aspect ratio for the image.
---
--- @return void
function DrawSplashScreen()
	-- stub, redefine per project
	-- ATTN: this is called before the initialization of the classes system, only use pure UIL calls
	-- mimic the bink player behavior, stretch full screen
	-- do not measure the image size, because in some cases this fails, use 16:9 image
	local screen = UIL.GetScreenSize()
	local size = ScaleToFit(LoadingScreenOrgSize, screen, not "clip")
	
	local pos = (screen - size) / 2
	local rc = box(pos, pos + size)
	UIL.DrawSolidRect(box(point20, screen), RGB(0,0,0))
	UIL.DrawImage("UI/SplashScreen.tga", rc)
end

DefineClass.XLoadingScreenClass =
{
	__parents = { "BaseLoadingScreen" },
	FadeOutTime = 300,
 	Background = RGB(0, 0, 0),
}

g_LoadingScreens = {
	"UI/SplashScreen.tga",
}

if FirstLoad then
	g_FirstLoadingScreen = true
end

---
--- Opens the XLoadingScreenClass dialog.
---
--- If this is the first load, the splash screen image "UI/SplashScreen.tga" is used. Otherwise, a random image from the `g_LoadingScreens` table is used.
---
--- @param ... any Additional arguments to pass to the `BaseLoadingScreen:Open()` function.
---
function XLoadingScreenClass:Open(...)
	self.image = g_FirstLoadingScreen and "UI/SplashScreen.tga" or table.rand(g_LoadingScreens)
	g_FirstLoadingScreen = false
	BaseLoadingScreen.Open(self, ...)
end

---
--- Returns the currently open game blocking loading screen dialog, if any.
---
--- @return BaseLoadingScreen|nil The currently open game blocking loading screen dialog, or nil if none is open.
function GetGameBlockingLoadingScreen()
	for _, d in pairs(Dialogs) do
		if d and IsKindOf(d, "BaseLoadingScreen") and d.game_blocking then
			return d
		end
	end
end

---
--- Waits for any game blocking loading screens to close.
---
--- This function will block until all game blocking loading screens have been closed.
---
--- @return nil
function WaitLoadingScreenClose() -- only checks for game blocking loading screens
	while GetGameBlockingLoadingScreen() do
		WaitNextFrame()
	end
end

--[[
--test cases

function SST_CloseAndReopen()
	CreateRealTimeThread(function()
		LoadingScreenOpen("idSavingScreen")
		Sleep(1000) -- write something
		LoadingScreenClose("idSavingScreen")
		assert(GetOpenLoadingScreen("idSavingScreen"))
		Sleep(3000)
		assert(GetOpenLoadingScreen("idSavingScreen"))
		LoadingScreenOpen("idSavingScreen")
		Sleep(1000)
		LoadingScreenClose("idSavingScreen")
		Sleep(499)
		assert(GetOpenLoadingScreen("idSavingScreen")) -- should stay for 500 ms after the last 'Close'
		Sleep(2)
		assert(not GetOpenLoadingScreen("idSavingScreen")) -- and still be closed properly (more than 4 seconds have passed since it has been opened)
	end)
end

function SST_OpenCloseAndChangeMap(map)
	CreateRealTimeThread(function()
		LoadingScreenOpen("idSavingScreen", "test")
		Sleep(1000) -- write something
		LoadingScreenClose("idSavingScreen", "test")
		print("changing map, the saving screen should disappear in ~3 sec")
		ChangeMap(map)
	end)
end

--]]