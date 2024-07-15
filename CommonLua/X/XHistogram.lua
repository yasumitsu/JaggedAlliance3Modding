DefineClass.XHistogram = {
	__parents = {"XWindow"},

	type = "L",
	color = RGB(128, 128, 128),
	Background = RGB(255, 255, 255),
	value = false,
}

---
--- Sets the value of the XHistogram.
--- @param v any The new value to set.
---
function XHistogram:SetValue(v) 
	if self.value ~= v then
		UIL.Invalidate()
	end
	self.value = v
end

---
--- Draws the content of the XHistogram.
--- If the `value` property is set, it will draw a histogram using the `DrawHistogram` function with the `value`, `content_box`, and `color` properties.
---
function XHistogram:DrawContent()
	if self.value then
		DrawHistogram(self.value, self.content_box, self.color)
	end
end


DefineClass.HistogramPropertyObj = {
	__parents = {"PropertyObject"},

	properties = {
		{id = "lum", editor = "histogram", default = false,},
		{id = "lum_mean", editor = "number", default = 0, read_only = true, scale = 255, },
		{id = "pixels", editor = "number", default = 0, read_only = true, },
		{id = "r", editor = "histogram", default = false,},
		{id = "g", editor = "histogram", default = false,},
		{id = "b", editor = "histogram", default = false,},
	},
	update_thread = false,
	update_interval = 1000,
}

---
--- Returns the mean value of the luminance histogram.
--- @return number The mean value of the luminance histogram, or 0 if the luminance histogram is not available.
---
function HistogramPropertyObj:Getlum_mean()
	return self.lum and self.lum.mean or 0
end

---
--- Returns the number of pixels in the luminance histogram.
--- @return number The number of pixels in the luminance histogram, or 0 if the luminance histogram is not available.
---
function HistogramPropertyObj:Getpixels()
	return self.lum and self.lum.pixels or 0
end

if FirstLoad then
	g_HistogramEnabled = false
end

---
--- Toggles the histogram functionality.
--- If the histogram is not enabled, it creates a new `HistogramPropertyObj` instance and starts a real-time thread to update the histogram data.
--- If the histogram is already enabled, it retrieves the existing `HistogramPropertyObj` instance.
---
function GedToggleHistogram()
	ToggleHistogram()
end
---
--- Toggles the histogram functionality.
--- If the histogram is not enabled, it creates a new `HistogramPropertyObj` instance and starts a real-time thread to update the histogram data.
--- If the histogram is already enabled, it retrieves the existing `HistogramPropertyObj` instance.
---
function ToggleHistogram()
	if not g_HistogramEnabled then
		g_HistogramEnabled = HistogramPropertyObj:new({})
		g_HistogramEnabled.update_thread = CreateRealTimeThread(function()
			local self = g_HistogramEnabled
			while true do
				if GedObjects[self] then
					self.r, self.g, self.b, self.lum = AsyncBuildHistogram()
					ObjModified(self)
					Sleep(self.update_interval)
				else
					Sleep(2000)
				end
			end
		end)
	end
	GedProperties(g_HistogramEnabled)
end
