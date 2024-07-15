DefineClass.SplashScreen = {
	__parents = {"XDialog"},
	Background = RGB(0, 0, 0),
	HandleMouse = true,
	MouseCursor = const.DefaultMouseCursor,
}

--- Initializes the SplashScreen class.
---
--- This function creates a new XAspectWindow instance with the ID "idContent" and sets its Fit property to "FitInSafeArea". The XAspectWindow is added as a child of the SplashScreen instance.
---
--- @method Init
--- @return nil
function SplashScreen:Init()
	XAspectWindow:new({
		Id = "idContent",
		Fit = "FitInSafeArea",
	}, self)
end

--- Handles the mouse button down event for the SplashScreen.
---
--- If the left mouse button is pressed, the SplashScreen is closed.
---
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was pressed.
--- @return string "break" to indicate the event has been handled.
function SplashScreen:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:Close()
	end
	return "break"
end

--- Handles keyboard shortcuts for the SplashScreen.
---
--- If the "ButtonB" or "Escape" shortcut is received, the SplashScreen is closed and the event is handled.
--- Otherwise, the default XDialog.OnShortcut implementation is called.
---
--- @param shortcut string The name of the keyboard shortcut that was triggered.
--- @param source table The source of the keyboard shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, otherwise nil.
function SplashScreen:OnShortcut(shortcut, source, ...)
	if shortcut == "ButtonB" or shortcut == "Escape" then
		self:Close()
		return "break"
	end
	XDialog.OnShortcut(self, shortcut, source, ...)
end

DefineClass.XSplashImage = {
	__parents = { "SplashScreen" },
	Id = "idXSplashScreenImage",
}

--- Initializes the XSplashImage class.
---
--- This function creates a new XImage instance with the ID "idImage" and sets its properties to display the image specified in the `image` field of the XSplashImage instance. The image is centered both horizontally and vertically, and is scaled to fit the smallest dimension. The image is faded in and out over the time specified by the `fadeInTime` and `fadeOutTime` fields, respectively.
---
--- After the image is displayed, a new thread is created that waits for the `fadeInTime`, then the `time` field, then fades out the image and closes the XSplashImage instance.
---
--- @method Init
--- @return nil
function XSplashImage:Init()
	XImage:new({
		Id = "idImage",
		Image = self.image,
		HAlign = "center",
		VAlign = "center",
		ImageFit = "smallest",
		FadeInTime = self.fadeInTime,
		FadeOutTime = self.fadeOutTime,
	}, self.idContent)
	self:CreateThread("wait", function()
		Sleep(self.fadeInTime)
		Sleep(self.time)
		self.idImage:Close()
		Sleep(self.fadeOutTime)
		self:Close()
	end)
end

DefineClass.XSplashMovie = {
	__parents = {"SplashScreen"},
	Id = "idXSplashScreenMovie",
}

--- Initializes the XSplashMovie class.
---
--- This function creates a new XVideo instance with the ID "idMovie" and sets its properties to display the video specified in the `movie` field of the XSplashMovie instance. The video is set to play automatically and when the video ends, the XSplashMovie instance is closed.
---
--- @method Init
--- @return nil
function XSplashMovie:Init()
	local video = XVideo:new({
		Id = "idMovie",
		ZOrder = -1,
		FileName = self.movie,
		Sound = self.movie,
	}, self.idContent)
	video:SetAutoPlay(true)
	video.OnEnd = function()
		self:Close()
	end
end

---
--- Creates a new XSplashImage instance and displays it on the screen.
---
--- @param image string The image to display in the splash screen.
--- @param fadeInTime number The time in seconds for the image to fade in.
--- @param fadeOutTime number The time in seconds for the image to fade out.
--- @param time number The time in seconds to display the image.
--- @param aspect number The aspect ratio of the image.
--- @return XSplashImage The created XSplashImage instance.
---
function SplashImage(image, fadeInTime, fadeOutTime, time, aspect)
	local dlg = XSplashImage:new({
		image = image,
		fadeInTime = fadeInTime,
		fadeOutTime = fadeOutTime,
		time = time,
		aspect = aspect,
	}, terminal.desktop)
	dlg:Open()
	return dlg
end
---
--- Creates a new XSplashMovie instance and displays it on the screen.
---
--- @param movie string The video file to display in the splash screen.
--- @param aspect number The aspect ratio of the video.
--- @return XSplashMovie The created XSplashMovie instance.
---
function SplashMovie(movie, aspect)
	local dlg = XSplashMovie:new({movie = movie, aspect = aspect}, terminal.desktop)
	dlg:Open()
	return dlg
end

DefineClass.XSplashText = {
	__parents = { "SplashScreen" },
	Id = "idXSplashScreenText",
}

---
--- Initializes a new XSplashText instance, which displays text on the splash screen.
---
--- @param self XSplashText The XSplashText instance being initialized.
---
function XSplashText:Init()
	XText:new({
		Id = "idText",
		
		Text = self.text,
		TextStyle = self.style,
		Translate = true,
		
		TextHAlign = "center",
		HAlign = "center",
		VAlign = "center",
		Margins = box(300, 0, 300, 0),
		
		FadeInTime = self.fadeInTime,
		FadeOutTime = self.fadeOutTime,
	}, self.idContent)
	XText:new({
		Id = "idGamepad",
	
		TextStyle = self.style,
		Translate = true,

		HAlign = "right",
		VAlign = "bottom",
		
		Margins = box(0, 0, 80, 80),
		
		ContextUpdateOnOpen = true,
		OnContextUpdate = function(self)
			self:SetVisible(GetUIStyleGamepad())
		end,

	}, self.idContent, "GamepadUIStyleChanged")
	self.idGamepad:SetText(T(296331304655, "<style SkipHint><ButtonB> Skip</style>"))
	
	self:CreateThread("wait", function()
		Sleep(self.fadeInTime)
		Sleep(self.time)
		self.idGamepad:Close()
		self.idText:Close()
		Sleep(self.fadeOutTime)
		self:Close()
	end)
end

---
--- Displays a splash screen with the given text, style, fade in/out times, and duration.
---
--- @param text string The text to display on the splash screen.
--- @param style table The text style to use for the splash screen text.
--- @param fadeInTime number The duration in seconds for the splash screen text to fade in.
--- @param fadeOutTime number The duration in seconds for the splash screen text to fade out.
--- @param time number The duration in seconds for the splash screen to be displayed.
--- @return XSplashText The created XSplashText instance.
function SplashText(text, style, fadeInTime, fadeOutTime, time)
	local dlg = XSplashText:new({
		style = style,
		fadeInTime = fadeInTime,
		fadeOutTime = fadeOutTime,
		time = time,
	}, terminal.desktop)
	dlg:Open()
	dlg.idText:SetText(text)
	return dlg
end