if FirstLoad then
	g_TempScreenshotFilePath = false
	g_SaveScreenShotThread = false
end

---
--- Gets the parameters for the savegame screenshot.
---
--- @return number width The width of the screenshot.
--- @return number height The height of the screenshot.
--- @return table src The source rectangle for the screenshot.
function GetSavegameScreenshotParams()
	local screen_sz = UIL.GetScreenSize()
	local screen_w, screen_h = screen_sz:x(), screen_sz:y()
	local src = box(point20, screen_sz)
	return MulDivRound(Savegame.ScreenshotHeight, src:sizex(), src:sizey()), Savegame.ScreenshotHeight, src
end

---
--- Waits for the current screenshot to be captured and saved.
---
--- This function creates a new real-time thread that captures a savegame screenshot,
--- waits for it to complete, and then sends a "SaveScreenShotEnd" message.
--- If a previous screenshot capture thread is still running, it waits for that thread to complete
--- before starting a new one.
---
--- @return string file_path The path of the captured screenshot file.
---
function WaitCaptureCurrentScreenshot()
	while IsValidThread(g_SaveScreenShotThread) do
		WaitMsg("SaveScreenShotEnd")
	end
	g_SaveScreenShotThread = CreateRealTimeThread(function()
		local _, file_path = WaitCaptureSavegameScreenshot(config.MemoryScreenshotSize and "memoryscreenshot/" or "AppData/")
		g_TempScreenshotFilePath = file_path
		if g_TempScreenshotFilePath then
			ResourceManager.OnFileChanged(g_TempScreenshotFilePath)
		end
		WaitNextFrame(2)
		Msg("SaveScreenShotEnd")
	end)
	while IsValidThread(g_SaveScreenShotThread) do
		WaitMsg("SaveScreenShotEnd") -- Sent multiple times by the thread.
	end
end

if FirstLoad then
ScreenShotHiddenDialogs = {}
end

---
--- Captures a savegame screenshot and waits for it to complete.
---
--- This function creates a new real-time thread that captures a savegame screenshot,
--- waits for it to complete, and then sends a "SaveScreenShotEnd" message.
--- If a previous screenshot capture thread is still running, it waits for that thread to complete
--- before starting a new one.
---
--- @param path string The path to save the screenshot file to.
--- @return string, string The error (if any) and the file path of the captured screenshot.
---
function WaitCaptureSavegameScreenshot(path)
	local width, height, src = GetSavegameScreenshotParams()
	local _, filename, ext = SplitPath(Savegame.ScreenshotName)
	local file_path = string.format("%s%s%dx%d%s", path, filename, width, height, ext)
	table.change(hr, "Savegame_BackgroundBlur", {
		EnablePostProcScreenBlur = 0
	})

	-- if we're under a loading screen, take a screenshot of the scene without any UI
	-- otherwise, hide just some dialogs

	table.iclear(ScreenShotHiddenDialogs)
	local screenshotWithUI = config.ScreenshotsWithUI or false
	if GetLoadingScreenDialog() then
		screenshotWithUI = false
	else
		for dlg_id, dialog in pairs(Dialogs or empty_table) do
			if dialog.HideInScreenshots then
				dialog:SetVisible(false, true)
				table.insert(ScreenShotHiddenDialogs, dialog)
			end
		end
	end

	Msg("SaveScreenShotStart")
	WaitNextFrame(2)
	local err = WaitCaptureScreenshot(file_path, {
		interface = screenshotWithUI, 
		width = width, height = height, 
		src = src
	})
	
	for dlg_id, dialog in ipairs(ScreenShotHiddenDialogs) do
		dialog:SetVisible(true, true)
	end
	table.iclear(ScreenShotHiddenDialogs)
	
	if table.changed(hr, "Savegame_BackgroundBlur") then
		table.restore(hr, "Savegame_BackgroundBlur")
	end
	Msg("SaveScreenShotEnd")
	return err, file_path
end
