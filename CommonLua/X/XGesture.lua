if not Platform.switch then return end

DefineClass.XGestureWindow = {
	__parents = { "XWindow" },
	gesture_time = 300,
	tap_dist = 20*20, -- square of the tap max tap offset
	taps = false,
	last_gesture = false,
	swipe_dist = 50,
}

-- recognised gestures

-- tap - fast press and release without moving
-- swipe - fast move to left, right, top or bottom
-- drag - continuous move

-- parallel tap - tap simultaneously with two fingers
-- pinch/rotation/pan - pres two fingers to zoom, rotate and move

---
--- Initializes the `taps` table for the `XGestureWindow` class.
--- The `taps` table is used to store information about tap gestures detected by the window.
---
function XGestureWindow:Init()
	self.taps = {}
end

---
--- Counts the number of taps that have occurred within the gesture time window.
---
--- @param pos Vector2 The position of the current touch event.
--- @return integer The number of taps that have occurred within the gesture time window.
---
function XGestureWindow:TapCount(pos)
	local time = RealTime() - self.gesture_time
	for i = #self.taps, 1, -1 do
		local tap = self.taps[i]
		if tap.time - time < 0 then
			table.remove(self.taps[i])
		else
			if pos:Dist2D2(tap.pos) < self.tap_dist then
				table.remove(self.taps, i)
				return tap.count
			end
		end
	end
	return 0
end

---
--- Registers a tap gesture with the specified position and count.
---
--- @param pos Vector2 The position of the tap gesture.
--- @param count integer The number of taps in the gesture.
---
function XGestureWindow:RegisterTap(pos, count)
	self.taps[#self.taps + 1] = { pos = pos, time = RealTime(), count = count }
end

---
--- Handles the start of a touch event on the `XGestureWindow` class.
---
--- This function is called when a touch event begins on the window. It checks if the current touch event is part of a new gesture or an existing one, and sets up the necessary data structures to track the gesture.
---
--- If a new gesture is detected, a new `gesture` table is created with the start time, start position, and initial tap count. A real-time thread is also created to check for the end of the gesture time window.
---
--- The touch event is then added to the `gesture` table, and the `GestureTouch` function is called to handle any initial gesture processing.
---
--- @param id integer The unique identifier for the touch event.
--- @param pos Vector2 The initial position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
---
function XGestureWindow:OnTouchBegan(id, pos, touch)
	touch.start_pos = pos
	touch.start_time = RealTime()
	local gesture = self.last_gesture
	if not gesture or gesture.done or #gesture == 2 or RealTime() - gesture.start_time > self.gesture_time then
		-- new gesture
		gesture = { start_time = RealTime(), start_pos = pos, taps = self:TapCount(pos) + 1 }
		self.last_gesture = gesture
		CreateRealTimeThread(function()
			Sleep(self.gesture_time)
			if not gesture.done then
				self:GestureTime(gesture)
			end
		end)
	end
	touch.gesture = gesture
	gesture[#gesture + 1] = touch
	self:GestureTouch(gesture, touch)
	return "break"
end

---
--- Handles the movement of a touch event on the `XGestureWindow` class.
---
--- This function is called when a touch event moves on the window. It checks if the current touch event is part of an existing gesture, and if so, calls the appropriate gesture handling function based on the type of gesture.
---
--- If the gesture is a drag gesture, the `OnDragMove` function is called to handle the movement of the drag gesture.
--- If the gesture is not a tap gesture and does not have a defined type yet, the gesture type is set to "drag" and the `OnDragStart` function is called to handle the start of the drag gesture.
--- If the gesture has two touches and the gesture type is not "pinch", the gesture type is set to "pinch" and the `OnPinchStart` function is called to handle the start of the pinch gesture.
---
--- @param id integer The unique identifier for the touch event.
--- @param pos Vector2 The current position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XGestureWindow:OnTouchMoved(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureMove(gesture, touch)
	end
	return "break"
end

---
--- Handles the end of a touch event on the `XGestureWindow` class.
---
--- This function is called when a touch event ends on the window. It checks if the current touch event is part of an existing gesture, and if so, calls the `GestureRelease` function to handle the end of the gesture.
---
--- @param id integer The unique identifier for the touch event.
--- @param pos Vector2 The final position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XGestureWindow:OnTouchEnded(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureRelease(gesture, touch)
	end
	return "break"
end

---
--- Handles the cancellation of a touch event on the `XGestureWindow` class.
---
--- This function is called when a touch event is cancelled on the window. It checks if the current touch event is part of an existing gesture, and if so, calls the `GestureRelease` function to handle the end of the gesture.
---
--- @param id integer The unique identifier for the touch event.
--- @param pos Vector2 The final position of the touch event.
--- @param touch table The touch event data.
--- @return string "break" to indicate that the touch event has been handled.
function XGestureWindow:OnTouchCancelled(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureRelease(gesture, touch)
	end
	return "break"
end

---
--- Handles the gesture when there are two touches on the `XGestureWindow` class.
---
--- If the gesture type is "drag", this function will:
--- - Call `OnDragStop` to handle the end of the drag gesture
--- - Change the gesture type to "pinch"
--- - Call `OnPinchStart` to handle the start of the pinch gesture
--- - Call `UpdatePinch` to update the pinch gesture
---
--- @param gesture table The current gesture being handled
--- @param touch table The touch event data
function XGestureWindow:GestureTouch(gesture, touch)
	if #gesture == 2 then
		if gesture.type == "drag" then
			self:OnDragStop(gesture[1].start_pos, gesture)
			gesture.type = "pinch"
			self:OnPinchStart((gesture[1].start_pos + gesture[2].start_pos) / 2, gesture)
			self:UpdatePinch(gesture)
		end
	end
end

---
--- Handles the start of a gesture on the `XGestureWindow` class.
---
--- If the gesture has only one touch and the gesture type is not yet set, this function will:
--- - Set the gesture type to "drag"
--- - Call `OnDragStart` to handle the start of the drag gesture
---
--- @param gesture table The current gesture being handled
function XGestureWindow:GestureTime(gesture)
	if #gesture == 1 and not gesture.type then
		gesture.type = "drag"
		self:OnDragStart(gesture[1].start_pos, gesture)
	end
end

---
--- Handles the gesture movement on the `XGestureWindow` class.
---
--- If the gesture has only one touch and the gesture type is "drag", this function will:
--- - Call `OnDragMove` to handle the movement of the drag gesture
---
--- If the gesture has only one touch and the gesture type is not yet set, this function will:
--- - Set the gesture type to "drag"
--- - Call `OnDragStart` to handle the start of the drag gesture
---
--- If the gesture has two touches and the gesture type is not "pinch", this function will:
--- - Set the gesture type to "pinch"
--- - Call `OnPinchStart` to handle the start of the pinch gesture
--- - Call `UpdatePinch` to update the pinch gesture
---
--- @param gesture table The current gesture being handled
--- @param touch table The touch event data
function XGestureWindow:GestureMove(gesture, touch)
	local tap = touch.start_pos:Dist2D2(touch.pos) < self.tap_dist
	if #gesture == 1 then
		if gesture.type == "drag" then
			self:OnDragMove(touch.pos, gesture)
		elseif not tap and not gesture.type then
			gesture.type = "drag"
			self:OnDragStart(gesture.start_pos, gesture)
		end
	elseif #gesture == 2 and not tap then
		if gesture.type ~= "pinch" then
			gesture.type = "pinch"
			self:OnPinchStart((gesture[1].start_pos + gesture[2].start_pos) / 2, gesture)
		end
		self:UpdatePinch(gesture)
	end
end

---
--- Handles the end of a gesture on the `XGestureWindow` class.
---
--- If the gesture has only one touch and the gesture type is "drag", this function will:
--- - Call `OnDragEnd` to handle the end of the drag gesture
---
--- If the gesture has only one touch and the gesture type is not "drag", this function will:
--- - Check if the gesture is a tap (touch distance is less than `tap_dist`)
--- - If it is a tap, increment the tap count and call `OnTap` to handle the tap gesture
---
--- If the gesture has two touches and the gesture type is "pinch", this function will:
--- - Call `UpdatePinch` to update the pinch gesture
--- - Call `OnPinchEnd` to handle the end of the pinch gesture
---
--- If the gesture has two touches and the gesture type is not "pinch", and the gesture is a tap (touch distance is less than `tap_dist`), this function will:
--- - Call `OnParallelTap` to handle the parallel tap gesture
---
--- @param gesture table The current gesture being handled
--- @param touch table The touch event data
function XGestureWindow:GestureRelease(gesture, touch)
	local tap = touch.start_pos:Dist2D2(touch.pos) < self.tap_dist
	gesture.done = true
	if #gesture == 1 then
		if gesture.type == "drag" then
			self:OnDragEnd(touch.pos, gesture)
			return
		end
		assert(RealTime() - gesture.start_time < self.gesture_time and tap)
		self:RegisterTap(touch.pos, gesture.taps)
		self:OnTap(touch.pos, gesture)
	elseif #gesture == 2 then
		if gesture.type == "pinch" then
			self:UpdatePinch(gesture)
			self:OnPinchEnd(gesture)
		end
		if RealTime() - gesture.start_time < self.gesture_time and tap then
			self:OnParallelTap(gesture)
		end
	end
end

---
--- Updates the pinch gesture.
---
--- This function calculates the offset, zoom, and rotation of the pinch gesture and calls the corresponding event handlers.
---
--- @param gesture table The current gesture being handled
function XGestureWindow:UpdatePinch(gesture)
	-- offset
	self:OnPinchMove((gesture[1].pos - gesture[1].start_pos + gesture[2].pos - gesture[2].start_pos) / 2, gesture)
	-- zoom
	gesture.start_dist = gesture.start_dist or (gesture[1].start_pos:Dist2D(gesture[2].start_pos))
	self:OnPinchZoom(gesture[1].pos:Dist2D(gesture[2].pos) * 1000 / gesture.start_dist, gesture)
	-- rotate
	self:OnPinchRotate(CalcAngleBetween2D(
		gesture[1].start_pos - gesture[2].start_pos,
		gesture[1].pos - gesture[2].pos
	), gesture)
end


---
--- Handles the tap gesture event.
---
--- This function is called when a tap gesture is detected. It prints the tap position and the number of taps.
---
--- @param pos table The position of the tap gesture
--- @param gesture table The gesture object containing information about the tap
function XGestureWindow:OnTap(pos, gesture)
	print("tap", pos, gesture.taps)
end

---
--- Handles the start of a drag gesture.
---
--- This function is called when a drag gesture is detected. It can be used to perform any necessary setup or initialization for the drag gesture.
---
--- @param pos table The starting position of the drag gesture
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnDragStart(pos, gesture)
end

---
--- Handles the drag gesture movement.
---
--- This function is called when a drag gesture is detected and the user is moving their finger. It checks if the drag gesture is a horizontal or vertical swipe and calls the corresponding event handlers.
---
--- @param pos table The current position of the drag gesture
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnDragMove(pos, gesture)
	local offset = pos - gesture[1].start_pos
	if gesture.swipe then
		if gesture.swipe == "h" then
			self:OnHSwipeUpdate(offset:x(), gesture)
		end
		if gesture.swipe == "v" then
			self:OnVSwipeUpdate(offset:y(), gesture)
		end
	else
		if abs(offset:x()) > self.swipe_dist then
			gesture.swipe = "h"
			self:OnHSwipeStart(offset:x(), gesture)
		elseif abs(offset:y()) > self.swipe_dist then
			gesture.swipe = "v"
			self:OnVSwipeStart(offset:y(), gesture)
		end
	end
end

---
--- Handles the end of a drag gesture.
---
--- This function is called when a drag gesture is detected and the user has finished moving their finger. It checks if the drag gesture was a horizontal or vertical swipe and calls the corresponding event handlers.
---
--- @param pos table The final position of the drag gesture
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnDragEnd(pos, gesture)
	local offset = pos - gesture[1].start_pos
	if gesture.swipe then
		if gesture.swipe == "h" then
			self:OnHSwipeEnd(offset:x(), gesture, offset:x() * 1000 / (RealTime() - gesture.start_time + 1))
		end
		if gesture.swipe == "v" then
			self:OnVSwipeEnd(offset:y(), gesture, offset:y() * 1000 / (RealTime() - gesture.start_time + 1))
		end
	end
end

---
--- Handles the start of a horizontal swipe gesture.
---
--- This function is called when a horizontal swipe gesture is detected and the user has started moving their finger. It provides the initial offset of the swipe and the gesture object containing information about the drag.
---
--- @param offs number The initial horizontal offset of the swipe
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnHSwipeStart(offs, gesture)
end

---
--- Handles the update of a horizontal swipe gesture.
---
--- This function is called when a horizontal swipe gesture is detected and the user is moving their finger. It provides the current horizontal offset of the swipe and the gesture object containing information about the drag.
---
--- @param offs number The current horizontal offset of the swipe
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnHSwipeUpdate(offs, gesture)
end

---
--- Handles the end of a horizontal swipe gesture.
---
--- This function is called when a horizontal swipe gesture is detected and the user has finished moving their finger. It provides the final horizontal offset of the swipe, the gesture object containing information about the drag, and the swipe velocity.
---
--- @param offs number The final horizontal offset of the swipe
--- @param gesture table The gesture object containing information about the drag
--- @param velocity number The velocity of the horizontal swipe in pixels per second
function XGestureWindow:OnHSwipeEnd(offs, gesture)
end

---
--- Handles the start of a vertical swipe gesture.
---
--- This function is called when a vertical swipe gesture is detected and the user has started moving their finger. It provides the initial offset of the swipe and the gesture object containing information about the drag.
---
--- @param offs number The initial vertical offset of the swipe
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnVSwipeStart(offs, gesture)
end

---
--- Handles the update of a vertical swipe gesture.
---
--- This function is called when a vertical swipe gesture is detected and the user is moving their finger. It provides the current vertical offset of the swipe and the gesture object containing information about the drag.
---
--- @param offs number The current vertical offset of the swipe
--- @param gesture table The gesture object containing information about the drag
function XGestureWindow:OnVSwipeUpdate(offs, gesture)
end

---
--- Handles the end of a vertical swipe gesture.
---
--- This function is called when a vertical swipe gesture is detected and the user has finished moving their finger. It provides the final vertical offset of the swipe, the gesture object containing information about the drag, and the swipe velocity.
---
--- @param offs number The final vertical offset of the swipe
--- @param gesture table The gesture object containing information about the drag
--- @param velocity number The velocity of the vertical swipe in pixels per second
function XGestureWindow:OnVSwipeEnd(offs, gesture)
end

---
--- Handles a parallel tap gesture.
---
--- This function is called when a parallel tap gesture is detected. It provides the gesture object containing information about the tap.
---
--- @param gesture table The gesture object containing information about the tap
function XGestureWindow:OnParallelTap(gesture)
	print("parallel tap", gesture[1].pos)
end

---
--- Handles the start of a pinch gesture.
---
--- This function is called when a pinch gesture is detected and the user has started moving their fingers. It provides the gesture object containing information about the pinch.
---
--- @param gesture table The gesture object containing information about the pinch
function XGestureWindow:OnPinchStart(gesture)
	print("pinch start")
end

---
--- Handles the movement of a pinch gesture.
---
--- This function is called when a pinch gesture is detected and the user is moving their fingers. It provides the current offset of the pinch and the gesture object containing information about the pinch.
---
--- @param offset table The current offset of the pinch gesture
--- @param gesture table The gesture object containing information about the pinch
function XGestureWindow:OnPinchMove(offset, gesture)
	print("move", offset)
end

---
--- Handles the zoom of a pinch gesture.
---
--- This function is called when a pinch gesture is detected and the user is moving their fingers to zoom in or out. It provides the current zoom factor of the pinch gesture.
---
--- @param zoom number The current zoom factor of the pinch gesture
--- @param gesture table The gesture object containing information about the pinch
function XGestureWindow:OnPinchZoom(zoom, gesture)
	print("zoom", zoom)
end

---
--- Handles the rotation of a pinch gesture.
---
--- This function is called when a pinch gesture is detected and the user is moving their fingers to rotate. It provides the current rotation angle of the pinch gesture.
---
--- @param angle number The current rotation angle of the pinch gesture
--- @param gesture table The gesture object containing information about the pinch
function XGestureWindow:OnPinchRotate(angle, gesture)
	print("rotate", angle)
end

---
--- Handles the end of a pinch gesture.
---
--- This function is called when a pinch gesture is detected and the user has finished moving their fingers. It provides the gesture object containing information about the pinch.
---
--- @param gesture table The gesture object containing information about the pinch
function XGestureWindow:OnPinchEnd(gesture)
	print("pinch end")
end

--[[
function OnMsg.DesktopCreated()
	local win = XGestureWindow:new(terminal.desktop)
	win:SetPos(point20)
	win:SetSize(terminal.desktop:GetSize())
end
--]]
