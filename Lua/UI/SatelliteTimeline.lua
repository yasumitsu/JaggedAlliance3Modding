GameVar("gv_Timeline", function() return {} end)
if FirstLoad then
g_SatTimelineUI = false
end

function OnMsg.NewGame()
	gv_Timeline = {}
end

local lMapPrecision = 10 -- Map space is multiplied by this number to increase precision when zooming in.
local lTimelineMaxTime = 7 -- Days (Segments)
local lDefaultTimeScale, lTimeScaleDownscaleEventCount = 7, 5
local lSegmentWidth, lSegmentHeight = 70 * lMapPrecision, 45
local lBottomLineHeight, lBottomLineColorDay, lBottomLineColorNight = 6, RGB(106, 96, 68), RGB(68, 96, 106)
local lSegmentSpacing = 0
local lMapWidth = (lTimelineMaxTime + 1) * lSegmentWidth
local lTimescales = { 1, 4, 7 }
local lTimescaleDownThreshold = 5
local lEventFrequencyDedupe = const.Scale.h * 3
local lInteractionExtendAbove = 40
local lEphemeralEvents = { 
	["travelling-temp"] = true, 
	["activity-temp"] = true,
}

DefineClass.SatelliteTimeline = {
	__parents = { "XMap" },
	
	translation_modId = 2,
	scale_modId = 3,
	
	MinWidth = 495,
	MaxWidth = 495,
	MinHeight = 45,
	MaxHeight = 45,
	map_size = point(lMapWidth, 45),
	
	HAlign = "center",
	VAlign = "center",
	
	day_sections = false,
	map_rect = false,

	bottom_line_rects = false,
	bottom_line_rect_color = false,
	bottom_line_icons = false,
	
	lock_on_rect = false,

	time_scale_days = lDefaultTimeScale,
	time_scale = 1000,
	max_zoom = 10000,
	
	icons_created = false,
	future_event = false,
	rollover_icon = false,
	preview = false, 
	
	paused_color = false,
}

---
--- Initializes the SatelliteTimeline UI element.
---
--- This function sets up the day sections, map rect, and bottom line elements for the SatelliteTimeline.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
---
function SatelliteTimeline:Init()
	local day_sections = {}
	local pen = 0 -- Section width is the size at 1x scale. Def. 7 days
	for i = 1, lTimelineMaxTime + 1 do -- Add one section as a buffer.
		local t = XTemplateSpawn("SatelliteTimelineLabelContainer", self)
		t.PosX = pen
		t:SetWidth(lSegmentWidth)
		t:SetHeight(45)
		
		day_sections[#day_sections + 1] = {
			box = sizebox(pen, 0, lSegmentWidth, lSegmentHeight),
			color = 0,
			text = t
		}
		pen = pen + lSegmentWidth;
	end
	self.day_sections = day_sections
	self.map_rect = sizebox(0, 0, self.map_size)
	
	self.bottom_line_rects = {}
	self.bottom_line_rect_color = {}
	self.bottom_line_icons = {}
end

---
--- Opens the SatelliteTimeline UI element.
---
--- This function sets up the future event icon, opens the XMap, refreshes the events, and sets the SatelliteTimeline as the global g_SatTimelineUI.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
---
function SatelliteTimeline:Open()
	local futureEventIcon = self:ResolveId("node")
	futureEventIcon = futureEventIcon and futureEventIcon.idTimelineFutureEvent
	futureEventIcon = futureEventIcon or XTemplateSpawn("SatelliteTimelineIconBase", self.parent)
	futureEventIcon:SetAsEvent(false)
	self.future_event = futureEventIcon

	XMap.Open(self)
	self:RefreshEvents() -- Will call SetTimescale, SetMapZoom, SyncToTime
	g_SatTimelineUI = self
end

---
--- Removes the SatelliteTimeline UI element from the global g_SatTimelineUI.
---
--- This function is called when the SatelliteTimeline is deleted, and sets the global g_SatTimelineUI to false.
---
function SatelliteTimeline:OnDelete()
	g_SatTimelineUI = false
end

-- Return the point in time that is 0 on the timeline.
local function lGetTimeOrigin(raw)
	local startTime = GetCurrentCampaignPreset()
	startTime = startTime and startTime.starting_timestamp or 0
	-- Convert origin to start of its day, to align the day segments
	startTime = (startTime / const.Scale.day) * const.Scale.day
	return startTime
end

---
--- Gets the current X position on the timeline based on the current game time.
---
--- @param scale number The scale factor to apply to the timeline.
--- @return number The current X position on the timeline.
---
function SatelliteTimeline:GetTimeWiseCurrentX(scale)
	local currentTime = Game and Game.CampaignTime or 0
	local startTime = lGetTimeOrigin()
	local segmentSize = MulDivRound(lSegmentWidth, scale or 1000, 1000)
	local currentDayX = MulDivRound((currentTime - startTime), lSegmentWidth, const.Scale.day)
	return self.box:minx() - MulDivRound(currentDayX, scale, 1000)
end

-- Is called when the UI is resized and by RefreshEvents
---
--- Sets the timescale of the SatelliteTimeline UI element.
---
--- @param daysToShow number The number of days to show on the timeline.
--- @param noInterp boolean If true, disables interpolation when setting the map zoom.
---
function SatelliteTimeline:SetTimescale(daysToShow, noInterp)
	local timeScale = MulDivRound(1000, lDefaultTimeScale, daysToShow)
	self.time_scale = timeScale - (timeScale % 100)
	local calculatedScale = MulDivRound(self.parent.scale:x(), self.time_scale, 1000)

	self:SetMapZoom(calculatedScale / lMapPrecision, noInterp and 0 or 200)
	self.time_scale_days = daysToShow
	self:SyncToTime("skip_scroll")
	self:Invalidate()
end

-- Is called every satellite tick and by SetTimescale
---
--- Synchronizes the SatelliteTimeline UI element to the current game time.
---
--- This function is responsible for updating the visual representation of the timeline, including the day sections, the bottom line, and the lock-on indicator. It also checks for expired events and triggers a refresh if necessary.
---
--- @param skip_scroll boolean If true, the function will not update the map scroll position.
---
function SatelliteTimeline:SyncToTime(skip_scroll)
	if not gv_SatelliteView then return end
	if not self.current_scale then return end
	local currentTime = Game and Game.CampaignTime or 0
	local startTime = lGetTimeOrigin()

	local currentX = self:GetTimeWiseCurrentX(self.current_scale)
	if not skip_scroll then self:SetMapScroll(currentX, 0, 0) end

	local dayStart = startTime / const.Scale.day
	local dayCurrent = currentTime / const.Scale.day
	
	local dayCurrentTimestamp = dayCurrent * const.Scale.day
	local firstSegmentX = lSegmentWidth * (dayCurrent - dayStart)
	local pen = firstSegmentX
	local lineSectionSize = lSegmentWidth
	for i, s in ipairs(self.day_sections) do
		s.box = sizebox(pen, 0, lSegmentWidth, lSegmentHeight)
		s.color = GetColorWithAlpha(GameColors.D, (dayCurrent + i) % 2 ~= 0 and 50 or 0)
		if s.text.PosX ~= pen then
			s.text.PosX = pen
			s.text:InvalidateLayout()
		end

		local text
		if self.time_scale_days <= 4 then
			text = T{143462819539, "<month(t)> <day(t)>", t = dayCurrentTimestamp + (i - 1) * const.Scale.day}
		else
			text = T{398256878817, "<day(t)>", t = dayCurrentTimestamp + (i - 1) * const.Scale.day}
		end

		s.text:SetText(text)
		
		local separatorSize = MulDivRound(2, 1000, self.current_scale)
		s.separatorOne = sizebox(pen - separatorSize / 2, lSegmentHeight - 10, separatorSize, lSegmentHeight + 1)
		
		pen = pen + lSegmentWidth
	end
	self.map_rect = box(firstSegmentX, 0, pen, self.map_size:y())
	
	local firstSegment = self.day_sections[1]
	local lastSegment = self.day_sections[#self.day_sections]
	table.clear(self.bottom_line_rects)
	self.bottom_line_rect_color[1] = RGB(106, 96, 68)
	self.bottom_line_rects[1] = box(
		firstSegment.box:minx(),
		lSegmentHeight - lBottomLineHeight,
		lastSegment.box:maxx(),
		lSegmentHeight + 1
	)
	
	currentTime = currentTime + const.Satellite.Tick
	local firstEvent = gv_Timeline[1]
	if firstEvent and currentTime > firstEvent.due then
		self:RefreshEvents()
	end
	
--[[	local lockTime = gv_Timeline.lock_on
	if lockTime and currentTime >= lockTime then
		SetCampaignSpeed(0, "UI")
		gv_Timeline.lock_on = false
		lockTime = false
	end]]
		
	local firstSegment = self.day_sections[1]
	local lockTime = g_SatTimelineUI and g_SatTimelineUI.preview
	if lockTime then
		local x = MulDivRound((lockTime - startTime), lSegmentWidth, const.Scale.day)
		local relativeX = x
		self.lock_on_rect = box(firstSegment.box:minx(), lSegmentHeight - lBottomLineHeight, relativeX, lSegmentHeight + 1)
	else
		self.lock_on_rect = false
	end
end

-- Is called a new event is added or when the first event expires by SyncToTime.
-- Note that this does call SyncToTime (via SetTimescale) back but it shouldn't create an infinite loop as
-- refresh events clears expired events.
---
--- Refreshes the events displayed in the Satellite Timeline UI.
--- This function is responsible for managing the display of events, including:
--- - Handling expired events
--- - Combining events that are close together in time
--- - Adjusting the time scale to fit the number of events
--- - Displaying a "future event" icon for events beyond the current time scale
---
--- @param self SatelliteTimeline The SatelliteTimeline instance
function SatelliteTimeline:RefreshEvents()
	if not self.icons_created then self.icons_created = {} end
	
	local nowTime = Game.CampaignTime + const.Satellite.Tick
	local timeScaleToCount, timeScaleToActualTime = {}, {}
	for i, area in ipairs(lTimescales) do
		timeScaleToCount[area] = 0
		timeScaleToActualTime[area] = nowTime + (area) * const.Scale.day
	end
	
	local eventIdx, lastEventTime = 1, false
	local eventsCombined = false
	local expiredEvents, anyEphemeralEvents = false, false
	local eventsPastScale = {}
	local ephemeralEventInScale = false
	for i, event in ipairs(gv_Timeline) do
		local ephemeral = lEphemeralEvents[event.id]
		local eventDue = event.due
		if not ephemeral and eventDue <= nowTime then
			expiredEvents = true
			goto continue
		end
		
		anyEphemeralEvents = anyEphemeralEvents or ephemeral
		
		-- Events following ephemeral events as ephemeral themselves to prevent grouping with them.
		if self.icons_created[eventIdx - 1] then
			local lastEventIcon = self.icons_created[eventIdx - 1]
			ephemeral = ephemeral or lEphemeralEvents[lastEventIcon.event.id]
		end
		
		local eventWasCombined = false
		if lastEventTime and abs(eventDue - lastEventTime) < lEventFrequencyDedupe and not ephemeral then
			if not eventsCombined then eventsCombined = {} end
			eventsCombined[#eventsCombined + 1] = event
			
			lastEventTime = eventDue
			eventWasCombined = true
		end
	
		-- Count event in all timescales
		for timeArea, actualTime in pairs(timeScaleToActualTime) do
			if eventDue <= actualTime then
				if not ephemeralEventInScale and ephemeral then ephemeralEventInScale = timeArea end
			
				if not eventWasCombined then
					timeScaleToCount[timeArea] = timeScaleToCount[timeArea] + 1
				end
			else
				if not eventsPastScale[timeArea] then eventsPastScale[timeArea] = {} end
				local pastScaleArr = eventsPastScale[timeArea]
				pastScaleArr[#pastScaleArr + 1] = event
			end
		end
		
		if eventWasCombined then goto continue end
		
		-- If there are any queued combined events, and this one isn't combined
		-- then set the last icon as a combination icon.
		if eventsCombined then
			local lastEventIcon = self.icons_created[eventIdx - 1]
			lastEventIcon:SetCombinedEvents(eventsCombined)
		end

		local icon = false
		if self.icons_created[eventIdx] then
			icon = self.icons_created[eventIdx]
		else
			icon = XTemplateSpawn("SatelliteTimelineIcon", self)
			icon:Open()
			self.icons_created[eventIdx] = icon
		end
		icon:SetAsEvent(event, eventsCombined)
		eventIdx = eventIdx + 1
		lastEventTime = eventDue
		eventsCombined = false
		
		::continue::
	end
	
	-- Add any combined events added by the last cycle.
	if eventsCombined then
		local lastEventIcon = self.icons_created[eventIdx - 1]
		lastEventIcon:SetCombinedEvents(eventsCombined)
		eventsCombined = false
	end
	
	-- Cleanup events that have passed.
	if expiredEvents then
		local hireEventPassed = false
		local nonEphemeralEventPassed = false
		for i, ev in ipairs(gv_Timeline) do
			if ev.due < nowTime then
				hireEventPassed = hireEventPassed or ev.typ == "hire"
				nonEphemeralEventPassed = nonEphemeralEventPassed or not lEphemeralEvents[ev.id]
				gv_Timeline[i] = nil
			end
		end
		table.compact(gv_Timeline)
		
		if hireEventPassed then
			PlayFX("TimelineEventContractExpire", "start")
		elseif nonEphemeralEventPassed then
			PlayFX("TimelineEventPassed", "start")
		end
	end
	
	-- Fade out non ephemeral events, if any ephemeral are present.
	for i, icon in ipairs(self.icons_created) do
		local event = icon.event
		if anyEphemeralEvents then
			local ephemeral = lEphemeralEvents[event.id]
			icon:SetTransparency(ephemeral and 0 or 200)
		elseif icon.Transparency ~= 0 then
			icon:SetTransparency(0)
		end
	end
	
	-- Hide passed event's UI.
	for i = eventIdx, #self.icons_created do
		self.icons_created[i]:SetAsEvent(false)
	end

	-- Start from the biggest time range and go down if there are too many events
	local bestArea = 7
	for i = 1, #lTimescales do
		local area = lTimescales[i]
		local count = timeScaleToCount[area]
		if count >= lTimeScaleDownscaleEventCount then
			local previousArea = lTimescales[i - 1] or lTimescales[1]
			local previousCount = timeScaleToCount[previousArea]
			if previousCount > 2 then
				bestArea = previousArea
			end
			break
		end
	end
	
	-- Make sure prediction events are shown
	if ephemeralEventInScale and ephemeralEventInScale > bestArea then
		bestArea = ephemeralEventInScale
	end

	if bestArea ~= self.time_scale_days then
		self:SetTimescale(bestArea)
	end
	
	local eventsPastArea = eventsPastScale[bestArea]
	self.future_event:SetAsEvent(eventsPastArea and eventsPastArea[1])
	if eventsPastArea and #eventsPastArea > 1 then
		self.future_event:SetCombinedEvents(eventsPastArea, "future")
	end
	
	self.future_event.icon:SetImage("UI/Icons/SateliteView/icon_timeline")
	self.future_event.inner_icon:SetVisible(true)
	self.future_event.inner_icon:SetImage("UI/Icons/SateliteView/future_events")
end

function OnMsg.StartSatelliteGameplay()
	if g_SatTimelineUI and g_SatTimelineUI.window_state == "open" then
		g_SatTimelineUI:SyncToTime()
	end
end

function OnMsg.SatelliteTick()
	if g_SatTimelineUI and g_SatTimelineUI.window_state == "open" then
		g_SatTimelineUI:SyncToTime()
	end
end

--- Called when the layout of the SatelliteTimeline UI element is complete.
-- If the size of the UI element has changed, the timescale is updated to fit the new size.
-- Otherwise, the zoom level of any child UI elements is updated to match the new zoom level.
function SatelliteTimeline:OnLayoutComplete()
	if self.last_box ~= self.box then
		self:SetTimescale(self.time_scale_days, true)
		self.last_box = self.box
	else
		-- Children's UpdateZoom needs to be ran after layout.
		for _, win in ipairs(self) do
			if win.UpdateZoom then
				win:UpdateZoom(self.last_scale, self.current_scale, 0)
			end
		end
	end
end

---
--- Sets the map scroll position.
---
--- @param transX number The horizontal scroll position.
--- @param transY number The vertical scroll position.
--- @param time number The duration of the scroll animation in milliseconds.
---
function SatelliteTimeline:SetMapScroll(transX, transY, time)
	-- Clamp to map bounds.
	local scale = UIL.GetParam(self.scale_modId, "end")
	local win_box = self.box
	transY = win_box:miny() -- No scrolling in the Y dimension
	UIL.SetParam(self.translation_modId, transX, transY, time or 100)
end

---
--- Sets the map zoom level.
---
--- @param scale number The new zoom scale.
--- @param time number The duration of the zoom animation in milliseconds.
--- @param origin_pos table|nil The position around which to zoom, if nil the current center is used.
---
function SatelliteTimeline:SetMapZoom(scale, time, origin_pos)
	local current_scale = UIL.GetParam(self.scale_modId)
	
	scale = Clamp(scale, 1, self:GetScaledMaxZoom())
	time = 0--time or 100
	
	local currentX = self:GetTimeWiseCurrentX(scale)
	CreateRealTimeThread(function()
		WaitNextFrame()
		UIL.SetParam(self.scale_modId, scale, self.scale:y(), time)
		if not origin_pos then
			self:SetMapScroll(currentX, 0, time)
		end
	end)

	self.last_scale = current_scale
	self.current_scale = scale
	for _, win in ipairs(self) do
		if win.UpdateZoom then
			win:UpdateZoom(current_scale, scale, time)
		end
	end
end

---
--- Draws the content of the SatelliteTimeline UI element.
---
--- This function is responsible for rendering the various visual elements that make up the SatelliteTimeline, such as the map background, day sections, bottom line rectangles, and the lock-on rectangle.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
---
function SatelliteTimeline:DrawContent()
	UIL.DrawSolidRect(self.map_rect, GameColors.A)
	for i, section in ipairs(self.day_sections) do
		UIL.DrawSolidRect(section.box, section.color)
	end
	if self.bottom_line_rects then
		for i, rect in ipairs(self.bottom_line_rects) do
			local color = self.bottom_line_rect_color[i] or 0
			UIL.DrawSolidRect(rect, color)
		end
	end
	
	if self.paused_color then
		UIL.DrawSolidRect(self.map_rect, self.paused_color)
	end
	
	if self.lock_on_rect then UIL.DrawSolidRect(self.lock_on_rect, GameColors.L) end
	for i, section in ipairs(self.day_sections) do
		if section.separatorOne then
			UIL.DrawSolidRect(section.separatorOne, GameColors.D)
		end
		if section.separatorTwo then
			UIL.DrawSolidRect(section.separatorTwo, GameColors.D)
		end
	end
end

---
--- Handles mouse button down events on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
--- @param pt table The mouse position.
--- @param button number The mouse button that was pressed.
---
function SatelliteTimeline:OnMouseButtonDown(pt, button)
end

---
--- Handles the end of scrolling on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
---
function SatelliteTimeline:ScrollStop()
end

---
--- Handles mouse button up events on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
--- @param pt table The mouse position.
--- @param button number The mouse button that was released.
---
function SatelliteTimeline:OnMouseButtonUp(pt, button)
end

---
--- Handles mouse position events on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
--- @param pt table The mouse position.
---
function SatelliteTimeline:OnMousePos(pt)
end

---
--- Handles mouse wheel forward events on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
--- @param pos number The mouse wheel position.
---
function SatelliteTimeline:OnMouseWheelForward(pos)
end

---
--- Handles mouse wheel back events on the SatelliteTimeline UI element.
---
--- @param self SatelliteTimeline The SatelliteTimeline instance.
--- @param pos number The mouse wheel position.
---
function SatelliteTimeline:OnMouseWheelBack(pos)
end
function SatelliteTimeline:OnMouseButtonDown(pt, button)end
function SatelliteTimeline:ScrollStop()end
function SatelliteTimeline:OnMouseButtonUp(pt, button)end
function SatelliteTimeline:OnMousePos(pt)end
function SatelliteTimeline:OnMouseWheelForward(pos)end
function SatelliteTimeline:OnMouseWheelBack(pos)end

local function lTimelineAddedEventFXPlay()
	PlayFX("TimelineEventAdded", "start")
end

local dbgTimeline = false
---
--- Adds a new event to the timeline.
---
--- @param id string The unique identifier for the event.
--- @param due number The due date for the event.
--- @param typ string The type of the event.
--- @param context any Additional context information for the event.
---
function AddTimelineEvent(id, due, typ, context)
	assert(due)
	if dbgTimeline then
		print("add timeline", id, due, typ, context)
	end	
	local existingIdx = table.find(gv_Timeline, "id", id)
	if existingIdx then
		-- Move lock on to new due
		local event = gv_Timeline[existingIdx]
		if event then
			if gv_Timeline.lock_on == event.due then
				gv_Timeline.lock_on = due
			end
		end
		table.remove(gv_Timeline, existingIdx)
	end

	gv_Timeline[#gv_Timeline + 1] = { id = id, due = due, typ = typ, context = context }
	table.sortby_field(gv_Timeline, "due")
	
	-- Operation events spam this so we need to throttle
	if not lEphemeralEvents[id] then DelayedCall(50, lTimelineAddedEventFXPlay) end
	
	if g_SatTimelineUI and g_SatTimelineUI.window_state == "open" then
		g_SatTimelineUI:RefreshEvents()
	end
end

---
--- Removes a timeline event from the global timeline.
---
--- @param id string The unique identifier for the event to remove.
---
function RemoveTimelineEvent(id)
	local existingIdx = table.find(gv_Timeline, "id", id)
	if dbgTimeline then
		print("rem timeline", id)
	end	
	if existingIdx then
		-- Remove lock on if event is removed
		local event = gv_Timeline[existingIdx]
		if event then
			if gv_Timeline.lock_on == event.due then
				gv_Timeline.lock_on = false
			end
			if g_SatTimelineUI and g_SatTimelineUI.rollover_icon and 
				g_SatTimelineUI.rollover_icon.event == event then
				g_SatTimelineUI.rollover_icon:OnSetRollover(false)
			end
		end
		table.remove(gv_Timeline, existingIdx)
	end
	
	if g_SatTimelineUI and g_SatTimelineUI.window_state == "open" then
		g_SatTimelineUI:RefreshEvents()
	end
end

function OnMsg.NewDay()
	if g_SatTimelineUI and g_SatTimelineUI.window_state == "open" then
		g_SatTimelineUI:RefreshEvents()
	end
end

local function lUpdateUnitContract(merc_id)
	local ud = gv_UnitData[merc_id]
	if ud and ud.HiredUntil then
		AddTimelineEvent("merc-contract-" .. merc_id, ud.HiredUntil, "hire", merc_id)
	end
end

OnMsg.MercHired = lUpdateUnitContract

function OnMsg.UnitAssignedToSquad(_, merc_id)
	lUpdateUnitContract(merc_id)
end

function OnMsg.UnitJoinedPlayerSquad(_, merc_id)
	lUpdateUnitContract(merc_id)
end

function OnMsg.UnitUpdateTimelineContractEvent(merc_id)
	lUpdateUnitContract(merc_id)
end

function OnMsg.MercHireStatusChanged(unitData, old, new)
	local merc_id = unitData.session_id
	if new ~= "Hired" then
		RemoveTimelineEvent("merc-contract-" .. merc_id)
		RemoveTimelineEvent("unit-activity-" .. merc_id)
		RemoveTimelineEvent("sector-activity-idle-" .. merc_id)
	end
end

---
--- Retrieves the unique identifier for an operation event on the satellite timeline.
---
--- @param ud table The unit data for the operation.
--- @param operation string The operation ID.
--- @return string The unique identifier for the operation event.
--- @return boolean Whether the event is a personal event for the unit.
function GetOperationEventId(ud, operation)
	if not ud then return end
	local sector = ud:GetSector()
	if not sector then return end
	local sectorId = sector and sector.Id
	local eventId = false
	local is_personal_event = true
	if operation == "Idle" then
		eventId = "sector-activity-idle-" .. ud.session_id
	elseif operation == "Arriving" then
		eventId = "unit-activity-" .. ud.session_id
	elseif operation == "RAndR" then
		eventId = "sector-activity-randr-" .. ud.session_id
	else
		eventId = "sector-activity-" .. sectorId .. "-" .. operation
		is_personal_event = false
	end
	return eventId, is_personal_event
end

function OnMsg.OperationTimeUpdated(ud, operation)
	local sector = ud:GetSector()
	if not sector then return end
	
	local sectorId = sector and sector.Id
	local eventId, is_personal_event = GetOperationEventId(ud, operation)

	RemoveTimelineEvent(eventId)
	local is_operation_started = 
		operation == "Idle" or operation == "Traveling" or operation == "Arriving" or
		sector and sector.started_operations and sector.started_operations[operation]

	if not is_operation_started then
		return
	end	
	local timeLeft = GetOperationTimeLeft(ud, operation, {all = not is_personal_event})
	if timeLeft <= 0 or operation=="Traveling" then return end
	local ctx = { operationId = operation, sectorId = sectorId, uId = ud.session_id }
	AddTimelineEvent(eventId, Game.CampaignTime + timeLeft, "operation", ctx)
end

local function lOperationChangedUpdateEvent(ud, previousOperation, _,prev_prof, interrupted)
	local squad = gv_Squads[ud.Squad]
	if not squad then return end
	
	local operation = ud.Operation
	if operation == "Arriving" then
		local timeLeft = GetOperationTimeLeft(ud, operation)
		timeLeft = timeLeft and Game.CampaignTime + timeLeft
		if not timeLeft then return end
		
		local sessionId = ud.session_id
		local sectorId = squad.CurrentSector
		local id = "unit-activity-" .. sessionId
		local ctx = { operationId = operation, sectorId = sectorId, uId = sessionId }
		AddTimelineEvent(id, timeLeft, "operation", ctx)
	else			
		local previousOperationId = previousOperation and previousOperation.id
		local sectorId = squad.CurrentSector
		
		-- Update event for the old operation.
		local previousTimelineId, is_prev_personal = GetOperationEventId(ud, previousOperationId)
		if previousOperationId == "Idle" or previousOperationId == "RAndR" then	
			RemoveTimelineEvent(previousTimelineId)
		elseif previousOperationId ~= "Traveling" and previousOperationId ~= "Arriving" then
			local mercs = GetOperationProfessionals(sectorId, previousOperationId)
			if next(mercs) then
				local previousTimeLeft = GetOperationTimeLeft(mercs[1], previousOperationId, {prediction = true, all = true})
				if previousTimeLeft <= 0 or (interrupted and is_prev_personal) then
					RemoveTimelineEvent(previousTimelineId)
				else
					local ctx = { operationId = previousOperationId, sectorId = sectorId }
					AddTimelineEvent(previousTimelineId, Game.CampaignTime + previousTimeLeft, "operation", ctx)
				end
				RecalcOperationETAs(gv_Sectors[sectorId],previousOperationId)
			else
				RemoveTimelineEvent(previousTimelineId)
			end	
		end
		
		-- Add event for new operation
		local operation = ud.Operation
		local id, is_personal = GetOperationEventId(ud, operation)
		local timeLeft = GetOperationTimeLeft(ud, operation, {all = not is_personal})
		if timeLeft <=0 or operation == "Traveling" then 
			RemoveTimelineEvent(id)
			return
		end
		
		timeLeft = timeLeft and Game.CampaignTime + timeLeft
		if timeLeft then
			local ctx = { operationId = operation, sectorId = sectorId, uId = ud.session_id }
			AddTimelineEvent(id, timeLeft, "operation", ctx)
		end
	end	
end
OnMsg.OperationChanged = lOperationChangedUpdateEvent

function OnMsg.UnitTiredAdded(unit)
	local ud = gv_UnitData[unit.session_id]
	if ud.Operation == "Idle" then
		lOperationChangedUpdateEvent(ud, SectorOperations.Idle)
	end
end

function OnMsg.UnitTiredRemoved(unit)
	local ud = gv_UnitData[unit.session_id]
	if ud.Operation == "Idle" then
		lOperationChangedUpdateEvent(ud, SectorOperations.Idle)
	end
end

-- Squad started traveling, unpause (unless pause option is set)
function OnMsg.SquadStartedTravelling(squad)
	if not gv_SatelliteView then return end
	if GetAccountStorageOptionValue("PauseSquadMovement") then return end

	local player_squad = IsPlayer1Squad(squad)
	if not player_squad or SquadCantMove(squad) then return end

	ResumeCampaignTime("UI")
end

function OnMsg.TempOperationStarted(operationId) -- OperationChanged
	if not GetAccountStorageOptionValue("PauseOperationStart") then
		if gv_SatelliteView and operationId ~= "Idle" then
			ResumeCampaignTime("UI")
		end
	end
end

function OnMsg.OperationCompleted(operation, mercs, sector)
	if GetAccountStorageOptionValue("PauseActivityDone") then
		PauseCampaignTime("UI")
	end
	PlayFX("OperationCompleted", "start")
end

function OnMsg.ConflictStart(sector_id)
	if GetAccountStorageOptionValue("AutoPauseConflict") then
		PauseCampaignTime("UI")
	end
end

function OnMsg.UnitTiredLevelAdded(unit, value)
	if gv_SatelliteView and IsMerc(unit) and value > 0 then
		local actor = "short"
		if GetAccountStorageOptionValue("PauseActivityDone") then
			actor = "important"
			if value < 2 then
				PauseCampaignTime("UI")	
			end
		end
		
		if value == 1 then 			
			CombatLog(actor, T{488444599414, --[[CharacterEffectCompositeDef Tired AddEffectText]] "<em><DisplayName></em> is tired", DisplayName = unit.Nick})
		elseif value  == 2 then
			CombatLog(actor, T{264384902433, --[[CharacterEffectCompositeDef Exhausted AddEffectText]] "<em><DisplayName></em> is exhausted", DisplayName = unit.Nick})
		end

	end
end


function OnMsg.UnitTiredLevelRemoved(unit, value)
	if gv_SatelliteView and IsMerc(unit) and value >= 0 then
		local actor = "short"
		if GetAccountStorageOptionValue("PauseActivityDone") then			
			actor = "important"
			if value == 0 then 
				PauseCampaignTime("UI")
			end
		end
		
		if value == 0 then
			CombatLog(actor, T{869182514521, --[[CharacterEffectCompositeDef Tired RemoveEffectText]] "<em><DisplayName></em> is no longer tired", DisplayName = unit.Nick})
		elseif value == 1 then
			CombatLog(actor, T{377164938786, --[[CharacterEffectCompositeDef Exhausted RemoveEffectText]] "<em><DisplayName></em> is no longer exhausted", DisplayName = unit.Nick})
		end
	end
end

function OnMsg.MercContractExpired()
	if GetAccountStorageOptionValue("PauseActivityDone") then
		PauseCampaignTime("UI")
	end
end

function OnMsg.BobbyRayShopShipmentArrived(shipment_details)
	if GetAccountStorageOptionValue("PauseActivityDone") then
		PauseCampaignTime("UI")
	end
end

local function lSquadTravelEventUpdate(squad)
	if squad.Side ~= "player1" and not squad.diamond_briefcase_dynamic then return end

	local timeTaken = GetTotalRouteTravelTime(squad.CurrentSector, squad.route, squad)
	if timeTaken and timeTaken ~= 0 then
		local waitTime = squad.wait_in_sector
		if waitTime then
			waitTime = waitTime - Game.CampaignTime
			timeTaken = timeTaken + waitTime
		end
		AddTimelineEvent("travelling-" .. squad.UniqueId, Game.CampaignTime + timeTaken, squad.diamond_briefcase and "diamond-travel" or "travel", squad.UniqueId)
		for _,unit in ipairs(squad.units) do
			local unit_data = gv_UnitData[unit]
			if unit_data.Operation=="Traveling"then
				unit_data.OperationInitialETA = unit_data.OperationInitialETA + (waitTime or 0)
			end	
		end		
	end
end

OnMsg.SquadStartedTravelling = lSquadTravelEventUpdate
OnMsg.SquadWaitInSectorChanged = lSquadTravelEventUpdate

function OnMsg.SquadStoppedTravelling(squad)
	RemoveTimelineEvent("travelling-" .. squad.UniqueId)
end

function OnMsg.SquadFinishedTraveling(squad)
	RemoveTimelineEvent("travelling-" .. squad.UniqueId)
end

function OnMsg.SquadDespawned(squad_id)
	RemoveTimelineEvent("travelling-" .. squad_id)
	RemoveTimelineEvent("squad-attack-" .. squad_id)
end

function OnMsg.SquadTeleported(squad)
	RemoveTimelineEvent("travelling-" .. squad.UniqueId)
end

local function lSquadTravelConflictUpdate(sector_id)
	local squads, enemySquads = GetSquadsInSector(sector_id)
	
	for i = 1, #squads + #enemySquads do
		local s = i > #squads and enemySquads[i - #squads] or squads[i]
		if IsSquadTravelling(s, "skip_tick") then
			lSquadTravelEventUpdate(s)
		else
			RemoveTimelineEvent("travelling-" .. s.UniqueId)
		end
	end
end

OnMsg.ConflictStart = lSquadTravelConflictUpdate
OnMsg.ConflictEnd = lSquadTravelConflictUpdate

function OnMsg.TravelModeChanged(newMode)
	if not newMode then
		RemoveTimelineEvent("travelling-temp")
	end
end

function OnMsg.NewDay()
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.Mine and sector.mine_work_days then
			local daysMineWorked = sector.mine_work_days
			local daysStartDepleting = GetSectorDepletionTime(sector)
			if daysStartDepleting - daysMineWorked == 1 then
				local depletionDays = const.Satellite.MineDepletingDays
				local timeLeftDays = (daysStartDepleting + depletionDays) - daysMineWorked
				AddTimelineEvent("mine_deplete_" .. id, Game.CampaignTime + timeLeftDays * const.Scale.day, "mine_deplete", id)
				Msg("MineDepleteStart", id)
				local popupHost = GetDialog("PDADialog")
				popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
				local text = T{407092530644, "Mine in <em><SectorName(sector)></em> is running dry and profits have started to decrease. They will continue to fall in the coming days and will eventually drop to <MinePercentAtDepleted()>%.", sector = sector}
				CreateMessageBox(popupHost, T(228475661057, "Attention"), text, T(413525748743, "Ok"))
				NetSyncEvent("SetCampaignSpeed", 0, "UI")
			end
		end
	end
end

function OnMsg.SectorSideChanged(sector_id)
	local sector = gv_Sectors[sector_id]
	if sector.Mine and sector.mine_work_days then
		if sector.Side == "player1" then
			local daysMineWorked = sector.mine_work_days
			local daysStartDepleting = GetSectorDepletionTime(sector)
			if daysMineWorked > daysStartDepleting then
				local depletionDays = const.Satellite.MineDepletingDays
				local timeLeftDays = (daysStartDepleting + depletionDays) - sector.mine_work_days
				if timeLeftDays > 0 then
					AddTimelineEvent("mine_deplete_" .. sector_id, Game.CampaignTime + timeLeftDays * const.Scale.day, "mine_deplete", sector_id)
				end
			end
		else
			RemoveTimelineEvent("mine_deplete_" .. sector_id)
		end
	end
end

--[[
local function lGuardpostPreparedAttackUpdate(guardpostObj)
	local sectorFrom = guardpostObj.SectorId
	local sector = gv_Sectors[sectorFrom]
	if sector.Side == "player1" then
		RemoveTimelineEvent("guardpost-attack-" .. sectorFrom)
		return
	end
	
	local timeOfAttack = guardpostObj.next_spawn_time
	if timeOfAttack then
		AddTimelineEvent("guardpost-attack-" .. sectorFrom, timeOfAttack, "guardpost", sectorFrom)
	end
end]]

--[[OnMsg.GuardpostAttackPrepared = lGuardpostPreparedAttackUpdate
function OnMsg.SectorSideChanged(sector_id)
	local sector = gv_Sectors[sector_id]
	if sector.Guardpost then
		local guardpostObj = sector.guardpost_obj
		lGuardpostPreparedAttackUpdate(guardpostObj)
	end
end
]]
local function lGuardpostTravelEventUpdate(squad)
	if not squad.guardpost then return end
	local timeTaken = GetTotalRouteTravelTime(squad.CurrentSector, squad.route, squad)
	if timeTaken and timeTaken ~= 0 then
		local waitTime = squad.wait_in_sector
		if waitTime then
			waitTime = waitTime - Game.CampaignTime
			timeTaken = timeTaken + waitTime
		end
		AddTimelineEvent("travelling-" .. squad.UniqueId, Game.CampaignTime + timeTaken, "guardpost-travel", squad.UniqueId)
		for _,unit in ipairs(squad.units) do
			local unit_data = gv_UnitData[unit]
			if unit_data.Operation=="Traveling"then
				unit_data.OperationInitialETA = unit_data.OperationInitialETA + (waitTime or 0)
			end	
		end		
	end
end

OnMsg.SquadStartedTravelling = lGuardpostTravelEventUpdate
OnMsg.SquadWaitInSectorChanged = lGuardpostTravelEventUpdate

--------------------------------------------------------------------------------------------------

---- WARNING: HORRIBLE HACKS, DO NOT ATTEMPT AT HOME ----

---
--- Sets the bounding box of the SatelliteTimeline window and extends the interaction box upward to allow the overflowing part of the icons to be clickable.
---
--- @param x number The x-coordinate of the bounding box.
--- @param y number The y-coordinate of the bounding box.
--- @param width number The width of the bounding box.
--- @param height number The height of the bounding box.
function SatelliteTimeline:SetBox(x, y, width, height)
	XMap.SetBox(self, x, y, width, height)

	-- Ok, now we need to extend the interaction box of everyone upward
	-- to allow the overflowing part of the icons to be clickable.
	local _, scaledExtension = ScaleXY(self.scale, 0, lInteractionExtendAbove)
	local parent = self
	while parent do
		local b = parent.box
		parent.interaction_box = box(
			b:minx(),
			b:miny() - scaledExtension,
			b:maxx(),
			b:maxy()
		)
		if parent.Id == "idTimelineContainer" then break end
		parent = parent.parent
	end
end

DefineClass.XMapWindowTimeline = {
	__parents = { "XMapWindow" }
}

---
--- Updates the zoom of the XMapWindowTimeline window.
---
--- If the window's `ScaleWithMap` property is true, the modifier is removed and the function returns.
---
--- Otherwise, an interpolation is added to the window that scales the window's clip box to a target size of 1000x1000, while keeping the original Y scale. This is likely done to ensure the window's contents remain visible and clickable after a zoom change.
---
--- @param prevZoom number The previous zoom level.
--- @param newZoom number The new zoom level.
--- @param time number The time over which the zoom change occurs.
---
function XMapWindowTimeline:UpdateZoom(prevZoom, newZoom, time)
	if self.ScaleWithMap then
		self:RemoveModifier("reverse-zoom")
		return
	end
	
	self:AddInterpolation({
		id = "reverse-zoom",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = function(modifier, window)
			modifier.originalRect = sizebox(self.PosX, self.PosY, newZoom, self.parent.scale:y()) -- reverse only X scale.
			modifier.targetRect = sizebox(self.PosX, self.PosY, 1000, 1000)
		end,
		duration = 0
	})
end

DefineClass.TimelineDayNightIcon = {
	__parents = { "XMapObject", "XMapWindowTimeline" },
	image = false,
	ScaleWithMap = false,
	HandleMouse = false,
	HAlign = "center",
	VAlign = "top",
	ZOrder = 0
}

---
--- Initializes the TimelineDayNightIcon object.
---
--- This function creates an XImage object as the `image` property of the TimelineDayNightIcon, sets its clip and clip box properties to false, and sets the width and height of the TimelineDayNightIcon to 15 pixels.
---
--- @param self TimelineDayNightIcon The TimelineDayNightIcon object being initialized.
---
function TimelineDayNightIcon:Init()
	local icon = XTemplateSpawn("XImage", self)
	icon.Clip = false
	icon.UseClipBox = false
	self.image = icon
	self:SetWidth(15)
	self:SetHeight(15)
end

DefineClass.SatelliteTimelineIconBase = {
	__parents = { "XContextWindow", "XWindowWithRolloverFX" },
	
	event = false,
	otherEvents = false,
	
	icon = false,
	selFrame = false,
	inner_icon = false,
	
	MouseCursor = "UI/Cursors/Pda_Hand.tga",
	HandleMouse = true,
	
	ellipsis = false,

	rolloverData = false,
	Shape = "InRhombus",
	
	RolloverTemplate = "TimelineRollover",
	RolloverText = Untranslated("placeholder"), -- Rollover opening logic checks for this
	RolloverAnchor = "center-top",
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(0, 0, 0, 23),
	
	MultipleEventsText = T(128199945253, "Multiple Events <style HeaderButton>(<count>)</style>")
}

---
--- Initializes the SatelliteTimelineIconBase object.
---
--- This function creates an XImage object as the `selFrame` property of the SatelliteTimelineIconBase, sets its clip and clip box properties to false, and sets the image fit, margins, vertical alignment, minimum and maximum height, and visibility. It also creates an XImage object as the `icon` property of the SatelliteTimelineIconBase, sets its clip and clip box properties to false, and sets the image fit, margins, vertical alignment, minimum and maximum height. Finally, it creates an XImage object as the `inner_icon` property of the SatelliteTimelineIconBase, sets its clip and clip box properties to false, and sets the image fit, margins, vertical alignment, and horizontal alignment.
---
--- @param self SatelliteTimelineIconBase The SatelliteTimelineIconBase object being initialized.
---
function SatelliteTimelineIconBase:Init()
	local selFrame = XTemplateSpawn("XImage", self)
	selFrame.Clip = false
	selFrame.UseClipBox = false
	selFrame.ImageFit = "scale-down"
	selFrame.Margins = box(-1, -2, 0, 0)
	selFrame.VAlign = "top"
	selFrame.HAlign = "center"
	selFrame.MinHeight = 44
	selFrame.MaxHeight = 44
	selFrame.Visible = false
	selFrame:SetImage("UI/Icons/SateliteView/timeline_selection")
	self.selFrame = selFrame
	
	local icon = XTemplateSpawn("XImage", self)
	icon.Clip = false
	icon.UseClipBox = false
	icon.ImageFit = "scale-down"
	icon.Margins = box(0, 0, 0, 0)
	icon.VAlign = "top"
	icon.MinHeight = 40
	icon.MaxHeight = 40
	self.icon = icon
	
	local iicon = XTemplateSpawn("XImage", icon)
	iicon.Clip = false
	iicon.UseClipBox = false
	iicon.ImageFit = "scale-down"
	iicon.Margins = box(0, 0, 0, 0)
	iicon.VAlign = "center"
	iicon.HAlign = "center"
	self.inner_icon = iicon
end

---
--- Handles the mouse button down event for a SatelliteTimelineIconBase object.
---
--- When the left mouse button is clicked on the icon, this function will:
--- - Center the satellite UI scroll on the map location associated with the event
--- - Blink the sector window associated with the event's context
--- - Blink the sector window associated with the squad or unit associated with the event's context
---
--- When the right mouse button is clicked on the icon, this function will:
--- - Call the OnClick function associated with the event's type, if it exists
---
--- @param self SatelliteTimelineIconBase The SatelliteTimelineIconBase object that received the mouse button down event.
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was clicked ("L" for left, "R" for right).
--- @return string If the right mouse button was clicked and an OnClick function was called, this will return "break" to stop further processing of the event.
---
function SatelliteTimelineIconBase:OnMouseButtonDown(pt, button)
	local event = self.event
	local eventData = SatelliteTimelineEvents[event.typ]
	if not event or not eventData then return end
	if button == "L" then
		local mapLoc = eventData:GetMapLocation(event.context)
		if mapLoc then
			g_SatelliteUI:CenterScrollOn(mapLoc:x(), mapLoc:y(), 300)
		end
		
		local sector = gv_Sectors[event.context]
		if sector then
			SectorWindowBlink(sector)
		end
		local squad = gv_Squads[event.context]
		if squad then
			local sector = gv_Sectors[squad.CurrentSector]
			if sector then
				SectorWindowBlink(sector)
			end
		end
		local unit = gv_UnitData[event.context]
		if unit then
			local squad = gv_Squads[unit.Squad]
			if squad and squad.CurrentSector then
				SectorWindowBlink(gv_Sectors[squad.CurrentSector])
			end
		end
	elseif button == "R" then
		local _, onClickFunc = eventData:OnClick(self.event)
		if onClickFunc then
			onClickFunc()
			return "break"
		end
	end
end

---
--- Sets the SatelliteTimelineIconBase object as an event.
---
--- @param event table The event data to be displayed.
--- @param isCombined boolean Whether the event is part of a combined event.
---
function SatelliteTimelineIconBase:SetAsEvent(event, isCombined)
	self:SetVisible(not not event)
	if not event then
		return
	end
	
--[[	local selected = gv_Timeline.lock_on
	self.selFrame:SetVisible(selected == event.due)]]
	self.selFrame:SetVisible(false)
	
	if event == self.event and isCombined == not not self.otherEvents then
		return
	end

	self.event = event
	self.otherEvents = false
	local origin = lGetTimeOrigin()
	local dueTime = event.due
	if self.map then
		self:SetPos(MulDivRound((dueTime - origin), lSegmentWidth, const.Scale.day), 0)
	end

	local innerIcon = false
	local typ = event.typ
	local eventData = SatelliteTimelineEvents[typ]
	if eventData then
		local ctx = event.context
		local icon, innerIcon = eventData:GetIcon(ctx)
		self.icon:SetImage(icon or "UI/Icons/SateliteView/icon_timeline")
		self.inner_icon:SetVisible(innerIcon)
		self.inner_icon:SetImage(innerIcon)

		local descText, titleText, hintText = eventData:GetDescriptionText(event.context)
		titleText = titleText or eventData.Title
		hintText = hintText or eventData.Hint
		
		local textCtx = eventData:GetTextContext(ctx)
		self.RolloverTitle = T{titleText, textCtx}
		self.RolloverHint = hintText
		
		local mercs = type(ctx)=="table" and ctx.mercs or eventData:GetAssociatedMercs(ctx)
		if type(mercs) == "string" then mercs = { mercs } end
		self.rolloverData = {{ 
			typ = typ,
			texts = {
				T{descText, textCtx}
			},
			mercs = mercs
		}}
	else
		self.icon:SetImage("UI/Icons/SateliteView/icon_timeline")
		self.inner_icon:SetVisible(false)
		self.RolloverTitle = false
		self.RolloverHint = false
		self.rolloverData = {{ 
			typ = "",
			texts = { Untranslated("Event type \"" .. typ .. "\" has no data definition") }
		}}
	end
end

---
--- Sets the combined events for the SatelliteTimelineIcon.
--- This function groups events of the same type together, and combines their texts and associated mercs.
---
--- @param otherEvents table A list of other events to combine with the main event.
--- @param futureEvent boolean Whether the combined events include a future event.
---
function SatelliteTimelineIconBase:SetCombinedEvents(otherEvents, futureEvent)
	if not table.find(otherEvents, self.event) then -- add main event to list
		table.insert(otherEvents, 1, self.event)
	end

	self.otherEvents = otherEvents
	
	-- Events of the same type are grouped together, and their texts and mercs
	-- are grouped together
	local eventGrouping = {}
	for i, ev in ipairs(otherEvents) do
		local evTyp = ev.typ
		local evData = evTyp and SatelliteTimelineEvents[evTyp]
		if not evData then goto continue end -- Unknown event
		
		local groupEvTyp = evTyp
		
		-- Special grouping per operation for the operation event type,
		-- instead of grouping all operations into one event.
		if evTyp == "operation"  then
			groupEvTyp = groupEvTyp .. ev.context.operationId
		end
		
		local currentGroup = table.find_value(eventGrouping, "groupTyp", groupEvTyp)
		
		local ctx = ev.context
		local associatedMercs = type(ctx)=="table" and ctx.mercs or  evData:GetAssociatedMercs(ctx)
		local ungroup = false
		-- Events which show an explicit left/right side of associated mercs are not to be grouped with other events.
		if associatedMercs and associatedMercs.leftSide and associatedMercs.rightSide then
			ungroup = true
		end
		
		-- Start new group if needed
		local texts = currentGroup and currentGroup.texts
		local mercs = currentGroup and currentGroup.mercs
		if not currentGroup or ungroup then
			texts = {}
			mercs = {}
			currentGroup = {
				typ = evTyp,
				texts = texts,
				mercs = mercs,
				groupTyp = groupEvTyp
			}
			eventGrouping[#eventGrouping + 1] = currentGroup
		end

		-- Add texts and mercs to it
		local textCtx = evData:GetTextContext(ctx)
		texts[#texts + 1] = "- " .. T{evData:GetDescriptionText(ctx), textCtx}
		
		if futureEvent then
			local dueTime = ev.due
			local timeLeft = dueTime - Game.CampaignTime
			local text = texts[#texts]
			texts[#texts] = text .. T{832020243764, " (<timeLeft>)", timeLeft = FormatCampaignTime(timeLeft, "all")}
		end
		
		if associatedMercs then
			if type(associatedMercs) == "string" then -- Single merc
				mercs[#mercs + 1] = associatedMercs
			elseif associatedMercs.leftSide and associatedMercs.rightSide then -- Left/Right merc split
				currentGroup.mercs = associatedMercs
			else -- Merc list
				table.iappend(mercs, associatedMercs)
			end
		end
		
		::continue::
	end
	self.rolloverData = eventGrouping
	if futureEvent then
		eventGrouping.futureEvent = true
	end
	
	self.RolloverHint = false
	self.RolloverText = Untranslated("placeholder")--table.concat(texts, "\n")
	
	local allSameType = #eventGrouping == 1
	local firstEventData = allSameType and SatelliteTimelineEvents[eventGrouping[1].typ]
	if allSameType and firstEventData then -- Show event icon rather than generic multiple icon if all same type
		local eventContext = otherEvents[1].context
		
		local _, titleText = firstEventData:GetDescriptionText(eventContext)
		titleText = titleText or firstEventData.Title
		
		local textCtx = firstEventData:GetTextContext(eventContext)
		self.RolloverTitle = T{847931418802, "<Title> <style HeaderButton>(<count>)</style>",
			Title = T{titleText, textCtx},
			count = #otherEvents
		}
	
		local icon, innerIcon = firstEventData:GetIcon(eventContext)
		self.icon:SetImage(icon or "UI/Icons/SateliteView/icon_timeline")
		self.inner_icon:SetVisible(innerIcon)
		self.inner_icon:SetImage(innerIcon)
		return
	end
	
	self.RolloverTitle = T{self.MultipleEventsText, count = #otherEvents}
	self.icon:SetImage("UI/Icons/SateliteView/icon_timeline")
	self.inner_icon:SetImage("UI/Icons/SateliteView/multiple_events")
	self.inner_icon:SetVisible(true)
end

---
--- Creates a rollover window for the SatelliteTimelineIconBase object.
---
--- @param gamepad boolean Whether the rollover is being displayed on a gamepad.
--- @param context table A table containing information about the event, other events, and rollover data.
--- @param pos table The position of the rollover window.
--- @return table The created rollover window.
function SatelliteTimelineIconBase:CreateRolloverWindow(gamepad, context, pos)
	context = {
		event = self.event,
		otherEvents = self.otherEvents,
		rolloverData = self.rolloverData,
	}
	return XContextWindow.CreateRolloverWindow(self, gamepad, context, pos)
end

DefineClass.SatelliteTimelineIcon = {
	__parents = { "SatelliteTimelineIconBase", "XMapWindowTimeline", "XMapRolloverable", "XMapObject" },
	ScaleWithMap = false,
	
	HAlign = "center",
	VAlign = "top",
	
	bottom_line_points = false,
	custom_clip = false,
	

	ChildrenHandleMouse = true,
	
	RolloverOffset = box(0, 0, 0, 26)
}

---
--- Initializes the SatelliteTimelineIcon object.
---
--- This function sets the width and height of the SatelliteTimelineIcon object, and adds an interpolation animation to push the object up by 3 pixels.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object being initialized.
---
function SatelliteTimelineIcon:Init()
	self:SetWidth(45)
	self:SetHeight(45)
	
	self:AddInterpolation({
		id = "PushUp",
		type = const.intRect,
		duration = 0,
		originalRect = sizebox(0, 3, 1000, 1000),
		targetRect = sizebox(0, 0, 1000, 1000),
		interpolate_clip = false
	})
end

---
--- Sets the box dimensions and custom clipping region for the SatelliteTimelineIcon.
---
--- This function sets the width, height, and position of the SatelliteTimelineIcon object. It also sets a custom clipping region for the icon based on the map's interaction box. Additionally, it sets the `bottom_line_points` property to a table containing two points that define a line at the bottom of the icon.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object being updated.
--- @param x number The x-coordinate of the icon's position.
--- @param y number The y-coordinate of the icon's position.
--- @param width number The width of the icon.
--- @param height number The height of the icon.
---
function SatelliteTimelineIcon:SetBox(x, y, width, height)
	XMapWindowTimeline.SetBox(self, x, y, width, height)

	local mapInteractionBox = self.map.interaction_box
	self.custom_clip = mapInteractionBox
	
	local a = point(x + width / 2, y + height - 5)
	local b = point(x + width / 2, y + height)
	self.bottom_line_points = { a, b }
end

---
--- Draws the window for the SatelliteTimelineIcon object, respecting a custom clipping region.
---
--- This function first checks if a custom clipping region has been set for the SatelliteTimelineIcon object. If a custom clipping region exists, it pushes that clipping region onto the UI stack, calls the `XMapWindowTimeline.DrawWindow()` function to draw the window, and then pops the clipping region off the stack.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object whose window is being drawn.
---
function SatelliteTimelineIcon:DrawWindow()
	if not self.custom_clip then return end
	UIL.PushClipRect(self.custom_clip)
	XMapWindowTimeline.DrawWindow(self, self.custom_clip)
	UIL.PopClipRect()
end

-- Custom implemented to have the check in screen space
-- in order to have InRhombus work despite the map stretching on the X axis.
---
--- Checks if a given point is within the window of the SatelliteTimelineIcon.
---
--- This function takes a point in map coordinates and checks if it is within the interaction box of the SatelliteTimelineIcon, after transforming the point to screen coordinates. It uses the `InRhombus` function to perform the check, which takes into account the map's stretching on the X axis.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object.
--- @param pt point The point in map coordinates to check.
--- @return boolean True if the point is within the icon's window, false otherwise.
---
function SatelliteTimelineIcon:PointInWindow(pt)
	local map = self.map

	local screenPt = map:MapToScreenPt(pt)

	local screenB = self:GetInterpolatedBox(false, self.interaction_box)
	screenB = map:MapToScreenBox(screenB)
	
	return pt.InRhombus(screenPt, screenB)
end

---
--- Handles the rollover event for a SatelliteTimelineIcon object.
---
--- This function is called when the rollover state of a SatelliteTimelineIcon object changes. It performs the following actions:
---
--- - Sets the campaign speed to 0 if the rollover is true, and restores the campaign speed if the rollover is false.
--- - Updates the preview state of the SatelliteTimelineUI based on the event associated with the SatelliteTimelineIcon.
--- - Updates the rollover_icon state of the SatelliteTimelineUI to the current SatelliteTimelineIcon.
--- - Synchronizes the timeline UI to the current time and invalidates the UI to force a redraw.
--- - Sets the visibility of the selection frame based on the preview state.
--- - If the event type is "guardpost", it shows or hides the guard post route on the sector associated with the event.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object whose rollover state has changed.
--- @param rollover boolean True if the rollover is active, false otherwise.
---
function SatelliteTimelineIcon:OnSetRollover(rollover)
	SatelliteTimelineIconBase.OnSetRollover(self, rollover)

	SetCampaignSpeed(rollover and 0, GetUICampaignPauseReason("Timeline"))
	 
	local event = self.event
	if not event then return end
	g_SatTimelineUI.preview = rollover and event.due or false
	g_SatTimelineUI.rollover_icon = rollover and self or false
	local timelineUI = self.map
	timelineUI:SyncToTime() -- Update line, in case is paused
	timelineUI:Invalidate() -- Force redraw
	self.selFrame:SetVisible(g_SatTimelineUI.preview == event.due)
	
	if event.typ == "guardpost" then
		local sector = gv_Sectors[event.context]
		SectorRolloverShowGuardpostRoute(rollover and sector)
	end
end

---
--- Creates a rollover window for the SatelliteTimelineIcon.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object.
--- @param gamepad boolean Whether the rollover is being created for a gamepad.
--- @param context table A table containing the event, other events, and rollover data for the SatelliteTimelineIcon.
--- @param pos point The position of the rollover window.
--- @return table The created rollover window.
---
function SatelliteTimelineIcon:CreateRolloverWindow(gamepad, context, pos)
	context = {
		event = self.event,
		otherEvents = self.otherEvents,
		rolloverData = self.rolloverData,
	}
	return XMapRolloverable.CreateRolloverWindow(self, gamepad, context, pos)
end

---
--- Sets up the map safe area for a SatelliteTimelineIcon window.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object.
--- @param wnd XWindow The window to set up the map safe area for.
---
function SatelliteTimelineIcon:SetupMapSafeArea(wnd)
	wnd.GetAnchor = function()
		return self:ResolveRolloverAnchor(wnd.context)
	end
end

---
--- Draws the bottom line content for the SatelliteTimelineIcon.
---
--- @param self SatelliteTimelineIcon The SatelliteTimelineIcon object.
---
function SatelliteTimelineIcon:DrawContent()
	if self.bottom_line_points then
		UIL.DrawLineAntialised(6, self.bottom_line_points[1], self.bottom_line_points[2], GameColors.F)
	end
end

DefineClass.SatelliteTimelineLabel = {
	__parents = { "XLabel" },
	TextStyle = "PDATimelineLabel",
	HAlign = "left",
	VAlign = "bottom",
	Translate = true,
	Clip = false,
	UseClipBox = false,
	Margins = box(2, 0, 0, lBottomLineHeight)
}

DefineClass.SatelliteTimelineLabelContainer = {
	__parents = { "XMapWindowTimeline" },
	label = false,

	ScaleWithMap = false,
	HAlign = "left",
	VAlign = "top",
}

---
--- Initializes the SatelliteTimelineLabelContainer object.
---
--- This function creates a new SatelliteTimelineLabel object and assigns it to the label field of the SatelliteTimelineLabelContainer.
---
--- @param self SatelliteTimelineLabelContainer The SatelliteTimelineLabelContainer object.
---
function SatelliteTimelineLabelContainer:Init()
	self.label = XTemplateSpawn("SatelliteTimelineLabel", self)
end

---
--- Sets the text of the SatelliteTimelineLabel associated with the SatelliteTimelineLabelContainer.
---
--- @param self SatelliteTimelineLabelContainer The SatelliteTimelineLabelContainer object.
--- @param text string The text to set on the SatelliteTimelineLabel.
---
function SatelliteTimelineLabelContainer:SetText(text)
	self.label:SetText(text)
end