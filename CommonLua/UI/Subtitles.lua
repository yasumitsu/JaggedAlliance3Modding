DefineClass.XSubtitles =
{
	__parents = { "XDialog" },
}

--- Sets the text of the subtitles dialog.
---
--- @param text string The text to display in the subtitles dialog.
function XSubtitles:SetSubtitles(text)
	self.idText:SetText(text)
end
-----------------------------------------------------
MapVar("g_SubtitlesThread", false)

--- Shows subtitles on the screen for a given duration.
---
--- @param text string The text to display in the subtitles dialog.
--- @param duration number The duration in seconds to display the subtitles.
--- @param delay number (optional) The delay in seconds before showing the subtitles.
function ShowSubtitles(text, duration, delay)
	if g_SubtitlesThread then HideSubtitles() end

	local dlg = OpenDialog("XSubtitles")
	g_SubtitlesThread = CreateMapRealTimeThread(function()
		if delay then 
			Sleep(delay)
		end
		dlg:SetSubtitles(text)
		Sleep(duration)
		CloseDialog("XSubtitles")
		g_SubtitlesThread = false
	end)
end

--- Hides the subtitles dialog and stops the subtitles thread.
---
--- This function is used to hide the subtitles dialog and stop the subtitles thread that was created by the `ShowSubtitles` function. It deletes the thread associated with the `g_SubtitlesThread` variable and closes the "XSubtitles" dialog.
function HideSubtitles()
	DeleteThread(g_SubtitlesThread)
	g_SubtitlesThread = false
	CloseDialog("XSubtitles")
end