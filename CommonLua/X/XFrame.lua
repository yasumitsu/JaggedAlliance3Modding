DefineClass.XFrame = {
	__parents = { "XControl" },
	
	properties = {
		{ category = "Image", id = "Image", name = "Frame image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "ImageScale", name = "Frame scale", editor = "point2d", default = point(1000, 1000), invalidate = true, lock_ratio = true, },
		{ category = "Image", id = "FrameBox", name = "Frame box", editor = "padding", default = box(0, 0, 0, 0), invalidate = true, },
		{ category = "Image", id = "Rows", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Columns", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Row", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "Column", editor = "number", default = 1, invalidate = true, },
		{ category = "Image", id = "TileFrame", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "SqueezeX", editor = "bool", default = true, invalidate = true, },
		{ category = "Image", id = "SqueezeY", editor = "bool", default = true, invalidate = true, },
		{ category = "Image", id = "TransparentCenter", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipX", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "FlipY", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "Desaturation", editor = "number", default = 0, min = 0, max = 255, slider = true, invalidate = true, },
	},
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	HandleMouse = false,
	image_id = const.InvalidResourceID,
	image_obj = false,
}

--- Initializes the XFrame object by setting the image property.
---
--- This function is called during the initialization of the XFrame object.
--- It sets the image property of the XFrame object to the value of the `Image` property,
--- and forces the image to be reloaded, even if it has not changed.
---
--- @function XFrame:Init
--- @return nil
function XFrame:Init()
	self:SetImage(self.Image, true)
end

--- Releases the reference to the image object and sets it to false.
---
--- This function is called when the XFrame object is being destroyed or
--- when the image property is changed. It ensures that the image object
--- is properly released to free up resources.
---
--- @function XFrame:Done
--- @return nil
function XFrame:Done()
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
end

local InvalidResourceID = const.InvalidResourceID
--- Sets the image of the XFrame object.
---
--- This function is used to set the image of the XFrame object. It checks if the image has changed and if so, it releases the reference to the previous image object and loads the new image. If the image fails to load, it prints a warning message.
---
--- @param image string|nil The path to the image file to be set. If `nil`, the image is cleared.
--- @param force boolean If `true`, the image is reloaded even if it has not changed.
--- @return nil
function XFrame:SetImage(image, force)
	if self.Image == (image or "") and not force then return end	
	self.Image = image or nil

	self:DeleteThread("LoadImage")
	if (self.Image or "") == "" then
		return
	end
	
	if self.image_obj ~= false then
		self.image_obj:ReleaseRef()
		self.image_obj = false
	end
	
	self.image_id = ResourceManager.GetResourceID(self.Image)
	if self.image_id == InvalidResourceID then
		printf("once", "Could not load image %s!", self.Image or "")
		return
	end
	
	self.image_obj = ResourceManager.GetResource(self.image_id)
	if self.image_obj then
		self:InvalidateMeasure()
		self:Invalidate()
	else
		self:CreateThread("LoadImage", function(self)
			self.image_obj = AsyncGetResource(self.image_id)
			self:InvalidateMeasure()
			self:Invalidate()
		end, self)
	end
end

--- Measures the size of the XFrame object based on the preferred width and height.
---
--- This function is used to calculate the final width and height of the XFrame object. It takes into account the size of the image associated with the XFrame, and adjusts the width and height accordingly if the SqueezeX and SqueezeY properties are not set.
---
--- @param preferred_width number The preferred width of the XFrame.
--- @param preferred_height number The preferred height of the XFrame.
--- @return number, number The final width and height of the XFrame.
function XFrame:Measure(preferred_width, preferred_height)
	local width, height = XControl.Measure(self, preferred_width, preferred_height)
	if self.image_id ~= InvalidResourceID and (not self.SqueezeX or not self.SqueezeY) then
		local image_width, image_height = ResourceManager.GetMetadataTextureSizeXY(self.image_id)
		image_width, image_height = ScaleXY(self.scale, ScaleXY(self.ImageScale, (image_width or 0) / self.Columns, (image_height or 0) / self.Rows))
		if not self.SqueezeX then
			width = Max(image_width, width)
		end
		if not self.SqueezeY then
			height = Max(image_height, height)
		end
	end
	return width, height
end

local UIL = UIL
local rgbWhite = RGB(255, 255, 255)
---
--- Draws the background of the XFrame object.
---
--- This function is responsible for rendering the background of the XFrame object, which includes the image associated with the XFrame. It calculates the appropriate color and desaturation level for the image, and then uses the UIL.DrawFrame function to render the image within the XFrame's bounds.
---
--- If the XFrame does not have an associated image, this function will call the DrawBackground function of the parent XControl class instead.
---
--- @param self XFrame The XFrame object whose background is being drawn.
function XFrame:DrawBackground()
	if self.image_id ~= InvalidResourceID then
		local color = self:CalcBackground()
		if GetAlpha(color) == 0 then return end
		local desaturation = UIL.GetDesaturation()
		UIL.SetDesaturation(self.Desaturation)
		UIL.SetColor(color)
		local scaleX, scaleY = ScaleXY(self.scale, self.ImageScale:xy())
		UIL.DrawFrame(self.image_id, self.box, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			self.FrameBox, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
		UIL.SetColor(rgbWhite)
		UIL.SetDesaturation(desaturation)
	else
		XControl.DrawBackground(self)
	end
end


----- XFrameProgress

local PushClipRect = UIL.PushClipRect
local PopClipRect = UIL.PopClipRect

DefineClass.XFrameProgress = {
	__parents = { "XFrame", "XProgress" },
	properties = {
		{ category = "Image", id = "ProgressImage", name = "Progress frame image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "ProgressFrameBox", name = "Progress frame box", editor = "padding", default = box(0, 0, 0, 0), invalidate = true, },
		{ category = "Image", id = "ProgressTileFrame", editor = "bool", default = false, invalidate = true, },
		{ category = "Image", id = "SeparatorImage", name = "Separator Image", editor = "ui_image", default = "", invalidate = true, },
		{ category = "Image", id = "SeparatorOffset", name = "Separator Offset", editor = "number", default = 0, invalidate = true, },
	},
	SqueezeY = false,
	separator_x = 0,
	separator_y = 0,
	TimeProgressInt = false,
}

---
--- Initializes an XFrameProgress object.
---
--- This function creates a new XFrame object as a child of the XFrameProgress object, and sets up its properties and behavior. The XFrame object is responsible for rendering the progress bar within the XFrameProgress.
---
--- The XFrame object has a custom DrawBackground function that clips the progress bar to the appropriate size based on the parent XFrameProgress's progress value. It also has a custom DrawContent function that renders a separator image between the progress bar and the XFrameProgress's content.
---
--- @param self XFrameProgress The XFrameProgress object being initialized.
--- @param parent table The parent object of the XFrameProgress.
--- @param context table The context in which the XFrameProgress is being initialized.
function XFrameProgress:Init(parent, context)
	local progress = XFrame:new({
		Id = "idProgress",
		HAlign = self.ProgressClip and "stretch" or "left",
		VAlign = "center",
		SqueezeY = false,
		DrawBackground = function(self)
			local clip = self.parent.ProgressClip and not self.TimeProgressInt
			if clip then
				local parent = self.parent
				local progress, max_progress = parent.Progress, Max(1, parent.MaxProgress)
				local min = ScaleXY(self.scale, parent.MinProgressSize)
				local min_x, min_y = self.content_box:minxyz()
				local width, height = self.content_box:sizexyz()
				if parent.Horizontal then
					local clip_width = (max_progress == 0) and min or min + (width - min) * progress / max_progress
					PushClipRect(min_x, min_y, min_x + clip_width, min_y + height, true)
				else
					local clip_height = (max_progress == 0) and min or min + (height - min) * progress / max_progress
					PushClipRect(min_x, min_y + height - clip_height, min_x + width, min_y + height, true)
				end
			end
			XFrame.DrawBackground(self)
			if clip then
				PopClipRect()
			end
		end,
		DrawContent = function(self)
			local parent = self.parent
			local image = parent.SeparatorImage
			if image ~= "" then
				local separator_x, separator_y = parent.separator_x, parent.separator_y
				local b = self.box
				local scale_x, scale_y = self.scale:xy()
				local offset = parent.SeparatorOffset * scale_x / 1000
				local rect
				local progressRatio = MulDivRound(parent.Progress, 1000, parent.MaxProgress)
				if parent.Horizontal then
					local w = MulDivRound(b:sizex(), progressRatio, 1000)
					b = sizebox(b:minx(), b:miny(), w, b:sizey())
					local right_spill = offset - ((parent.measure_width - self.measure_width) * scale_x / 1000)
					right_spill = Max(right_spill, 0)
					rect = box(Max(b:minx(), b:maxx() - separator_x - offset) + offset, b:miny(), Max(b:minx() + offset, b:maxx() - right_spill), b:maxy())
				else
					local h = MulDivRound(b:sizey(), progressRatio, 1000)
					b = sizebox(b:minx(), b:miny(), b:sizex(), h)
					local up_spill = offset - (b:miny() * scale_y / 1000)
					up_spill = Max(up_spill, 0)
					rect = box(b:minx(), Min(b:maxy() - offset, b:miny() + up_spill), b:maxx(), Min(b:maxy(), b:miny() + separator_y + offset) - offset)
				end
				UIL.DrawImage(image, rect, box(0, 0, separator_x, separator_y))
			end
		end,
	}, self, context)
	progress:SetImage(self.ProgressImage)
	progress:SetFrameBox(self.ProgressFrameBox)
	progress:SetTileFrame(self.ProgressTileFrame)
end

LinkPropertyToChild(XFrameProgress, "ProgressImage", "idProgress", "Image")
LinkPropertyToChild(XFrameProgress, "ProgressFrameBox", "idProgress", "FrameBox")
LinkPropertyToChild(XFrameProgress, "ProgressTileFrame", "idProgress", "TileFrame")

---
--- Sets whether the progress bar should be displayed horizontally or vertically.
---
--- @param h boolean Whether the progress bar should be horizontal (true) or vertical (false).
---
function XFrameProgress:SetHorizontal(h)
	self.Horizontal = h
	local progress = self.idProgress
	if self.ProgressClip then
		progress:SetHAlign(h and "stretch" or "center")
		progress:SetVAlign(h and "center" or "stretch")
	else
		progress:SetHAlign(h and "left" or "center")
		progress:SetVAlign(h and "center" or "bottom")
	end
	progress:SetSqueezeY(not h)
	progress:SetSqueezeX(h)
	self:SetSqueezeY(not h)
	self:SetSqueezeX(h)
	self:InvalidateMeasure()
end

---
--- Sets the separator image for the progress bar.
---
--- @param image string|boolean The image to use as the separator, or false to disable the separator.
---
function XFrameProgress:SetSeparatorImage(image)
	image = image or false
	if self.SeparatorImage ~= image then
		self.SeparatorImage = image
		self.separator_x, self.separator_y = UIL.MeasureImage(image)
		self:Invalidate()
	end
end

---
--- Overrides the `OnPropUpdate` method of the `XProgress` class.
---
--- This method is called when a property of the `XFrameProgress` object is updated. If the `TimeProgressInt` property is not set, it delegates the property update to the `XProgress.OnPropUpdate` method.
---
--- @param context table The context object associated with the property update.
--- @param prop_meta table The metadata of the property that was updated.
--- @param value any The new value of the property.
---
function XFrameProgress:OnPropUpdate(context, prop_meta, value)
	if not self.TimeProgressInt then
		XProgress.OnPropUpdate(self, context, prop_meta, value)
	end
end

---
--- Sets the time progress of the progress bar.
---
--- @param start_time number The start time of the progress bar.
--- @param end_time number The end time of the progress bar.
--- @param bGameTime boolean Whether the time progress should be based on game time or real time.
---
function XFrameProgress:SetTimeProgress(start_time, end_time, bGameTime)
	local prev = self.TimeProgressInt
	if prev and prev.start == start_time and prev.duration + prev.start == end_time and
		not bGameTime == not IsFlagSet(prev.flags or 0, const.intfGameTime) then
		-- setting the same time progress
		return
	end
	self.idProgress:RemoveModifier(prev)
	self.TimeProgressInt = nil
	if start_time and end_time then
		self.TimeProgressInt = {
			id = "TimeProgressBar",
			type = const.intRect,
			OnLayoutComplete = IntRectTopLeftRelative,
			OnWindowMove = IntRectTopLeftRelative,
			targetRect = sizebox(0, 0, 0, 100),
			originalRect = sizebox(0, 0, 100, 100),
			duration = end_time - start_time,
			start = start_time,
			interpolate_clip = self.UseClipBox and const.interpolateClipOnly or true,
			flags = const.intfInverse + (bGameTime and const.intfGameTime or 0),
		}
		self.idProgress:AddInterpolation(self.TimeProgressInt)
		self:SetMaxProgress(100)
		self:SetProgress(100)
	end
end