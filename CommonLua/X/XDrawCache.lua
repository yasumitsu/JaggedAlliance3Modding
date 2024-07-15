DefineClass.XDrawCache = {
	__parents = { "XWindow" },
	draw_stream_start = false,
	draw_stream_end = false,
	draw_last_frame = false
}

--- Invalidates the draw cache for this XDrawCache object.
--- This function clears the draw stream start index and then calls the `Invalidate` function of the parent `XWindow` class.
--- This ensures that the next call to `DrawWindow` will re-draw the entire window contents.
function XDrawCache:Invalidate()
	self.draw_stream_start = false
	XWindow.Invalidate(self)
end

local UIL = UIL
---
--- Draws the window contents, updating the draw stream to track the current state.
--- If the draw stream has not changed since the last frame, the function will return early without redrawing.
--- Otherwise, it will redraw the entire window contents and update the draw stream indexes.
---
--- @param clip_box table|nil The clipping box to use for drawing, or nil to draw the entire window.
---
function XDrawCache:DrawWindow(clip_box)
	local last_frame, sstart, send = UIL.CopyDrawStream(self.draw_last_frame, self.draw_stream_start, self.draw_stream_end)
	self.draw_last_frame = last_frame
	if sstart then -- if the copy was successful, keep the indexes as we will need them the next frame.
		self.draw_stream_start = sstart
		self.draw_stream_end = send
		return
	end
	self.draw_stream_start = UIL.GetDrawStreamOffset()
	XWindow.DrawWindow(self, clip_box)
	self.draw_stream_end = UIL.GetDrawStreamOffset()
end

DefineClass.XDrawCacheDialog = {
	__parents = { "XDialog", "XDrawCache" },
}

DefineClass.XDrawCacheContextWindow = {
	__parents = { "XContextWindow", "XDrawCache" },
}