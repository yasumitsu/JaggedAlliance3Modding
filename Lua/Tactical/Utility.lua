UndefineClass("CheckTime")
-- UI

table.iappend(XRollover.properties, {
	{ category = "Rollover", id = "RolloverTitle", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverDisabledTitle", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverHint", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverHintGamepad", editor = "text", default = "", translate = true, },
})

XGenerateGetSetFuncs(XRollover)

local prev_XPropControl_UpdatePropertyNames = XPropControl.UpdatePropertyNames
---
--- Updates the property names for the XPropControl.
--- This function overrides the default `UpdatePropertyNames` function to set the rollover title
--- for the property based on the property metadata.
---
--- @param prop_meta table The property metadata.
--- @return boolean The result of the previous `UpdatePropertyNames` function.
---
function XPropControl:UpdatePropertyNames(prop_meta)
	if prop_meta.help and editor ~= "help" then
		self:SetRolloverTitle(prop_meta.name or prop_meta.id)
	end
	return prev_XPropControl_UpdatePropertyNames(self, prop_meta)
end

function OnMsg.InitSatelliteView()
	BlinkStartButtonAndSatellite(false)
end

function OnMsg.ConflictEnd(sector)
	local campaignPreset = GetCurrentCampaignPreset()
	if not sector or not campaignPreset then return end
	local questVarState = gv_Quests["01_Landing"] and GetQuestVar("01_Landing", "TCE_InitialConflictLock")
	if sector.Id == campaignPreset.InitialSector and not TutorialHintsState.TravelPlaced and questVarState == "done" then
		BlinkStartButtonAndSatellite(true)
	end
end

---
--- Blinks the start button and satellite button in the game interface.
---
--- @param on boolean Whether to start or stop the blinking animation.
---
function BlinkStartButtonAndSatellite(on)
	local igi = GetInGameInterfaceModeDlg()
	local startBut = igi and igi:ResolveId("idStartButton")
	if not startBut then return end
	
	startBut:DeleteThread("blink")
	if not on then
		if startBut.idLargeText then
			startBut.idLargeText:SetTextStyle("HUDHeaderBigger")
		end
		return
	end

	startBut:CreateThread("blink", function()
		local textWnd = startBut.idLargeText
		local tick = 0
		while true do
			local startMenuOpen = startBut.desktop.modal_window
			startMenuOpen = startMenuOpen and startMenuOpen.Id == "idStartMenu" and startMenuOpen
			if startMenuOpen then
				local contentTemplate = startMenuOpen.idContent
				if contentTemplate then
					-- Prevents messing with the blink, and it only matters in sat view
					contentTemplate.RespawnOnContext = false
				end
				
				local satButton = startMenuOpen:ResolveId("actionToggleSatellite")
				if satButton and not satButton.rollover then
					local style = tick % 2 ~= 0 and "SatelliteContextMenuText" or "PDACursorHint"
					satButton:SetTextStyle(style)
					satButton:Invalidate()
				end
			end
			
			local textStyleButton = tick % 2 ~= 0 and "HUDHeaderBigger" or "MMButtonText"
			if startMenuOpen or startBut.rollover then textStyleButton = "HUDHeaderBigger" end
			textWnd:SetTextStyle(textStyleButton)
			
			tick = tick + 1
			Sleep(300)
		end
	end)
end

local prev_time
local prev_table
local prev_timeType
---
--- Gets the time as a table.
---
--- @param time number The time to get as a table.
--- @param real_time boolean Whether to use the real time or the campaign time.
--- @return table The time as a table.
---
function GetTimeAsTable(time, real_time)
	if prev_time ~= time or prev_timeType ~= real_time then
		prev_timeType = real_time
		prev_time = time
		prev_table = os.date(real_time and "*t" or "!*t", time)
	end
	return prev_table
end

---
--- Gets the campaign day based on the given time.
---
--- @param time number The time to get the campaign day for. If not provided, uses the current campaign time.
--- @return number The campaign day.
---
function GetCampaignDay(time)
	local t = time or Game.CampaignTime
	local campaignStartHour = GetTimeAsTable(Game.CampaignTimeStart).hour
	local campaignHour = (t - Game.CampaignTimeStart) / const.Scale.h
	return ((campaignHour + campaignStartHour) / 24) + 1
end

---
--- Gets the campaign week based on the given time.
---
--- @param time number The time to get the campaign week for. If not provided, uses the current campaign time.
--- @return number The campaign week.
---
function GetCampaignWeek(time)
	local campaignDays = GetCampaignDay(time)
	return (campaignDays / 7) + 1
end

local days = {
	T(815763551374, "SUN"),
	T(400037616455, "MON"),
	T(935033754448, "TUE"),
	T(101979463778, "WED"),
	T(441351859413, "THU"),
	T(653126156790, "FRI"),
	T(488038247478, "SAT"),
}

---
--- Gets the day of the month from the given time.
---
--- @param context_obj any The context object (unused).
--- @param time number The time to get the day of the month for. If not provided, uses the current campaign time.
--- @return number The day of the month.
---
TFormat.day = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return t and t.day or 1
end

---
--- Gets the day name from the given time.
---
--- @param context_obj any The context object (unused).
--- @param time number The time to get the day name for. If not provided, uses the current campaign time.
--- @return string The day name.
---
TFormat.day_name = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return days[t and t.wday or 1]
end

---
--- Gets the day name from the given day index.
---
--- @param context_obj any The context object (unused).
--- @param dayIdx number The day index to get the name for. If not provided, uses 1 (Sunday).
--- @return string The day name.
---
TFormat.day_name_number = function(context_obj, dayIdx)
	--%w - Weekday as decimal number (1 - 7; Sunday is 1)
	local actualDay = dayIdx and dayIdx + 1
	if dayIdx and dayIdx == 7 then
		dayIdx = 1
	elseif dayIdx then
		dayIdx = dayIdx + 1
	end
	
	return days[dayIdx or 1]
end

---
--- Multiplies two numbers and returns the result as a formatted string.
---
--- @param context_obj any The context object (unused).
--- @param m1 number The first number to multiply.
--- @param m2 number The second number to multiply.
--- @return string The formatted result of the multiplication.
---
function TFormat.Multiply(context_obj, m1, m2)
	local result = m1*m2
	return T{263297552624, "<result>", result = result}
end

---
--- Checks if the specified game rule is active.
---
--- @param ctx any The context object (unused).
--- @param rule_id string The ID of the game rule to check.
--- @return boolean True if the game rule is active, false otherwise.
---
function TFormat.IsGameRuleActive(ctx, rule_id)
	return IsGameRuleActive(rule_id)
end

---
--- Gets the damage range text for a given minimum and maximum damage value.
---
--- @param min number The minimum damage value.
--- @param max number The maximum damage value.
--- @return string The formatted damage range text.
---
function GetDamageRangeText(min, max)
	if min == max then
		return T{263148752783, "<min>", min = min}
	else
		return T{451168511282, "<minDamage>-<maxDamage>", minDamage = min, maxDamage = max}
	end
end

local months = {
	T(386097767149, "JAN"),
	T(496426864332, "FEB"),
	T(650065772304, "MAR"),
	T(732475195762, "APR"),
	T(807996486426, "MAY"),
	T(807327180752, "JUN"),
	T(396147045845, "JUL"),
	T(855339557928, "AUG"),
	T(560140242221, "SEP"),
	T(757023515681, "OCT"),
	T(542161812894, "NOV"),
	T(235231286112, "DEC")
}
---
--- Gets the month name for the given time.
---
--- @param context_obj any The context object (unused).
--- @param time number The time to get the month for. If not provided, uses the current campaign time.
--- @return string The month name.
---
TFormat.month = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return months[t and t.month or 1]
end

---
--- Gets the date in the system's date format.
---
--- @param context_obj any The context object (unused).
--- @param time number The time to get the date for. If not provided, uses the current campaign time.
--- @return string The formatted date.
---
TFormat.date = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	local month = string.format("%02d", t and t.month or 1)
	local day = string.format("%02d", t and t.day or 1)
	local year = tostring(t and t.year or 1)

	-- This is called in just one place, so its fine I guess.
	-- Might make sense to cache the format though.
	local systemDateFormat = GetDateTimeOrder()
	for i, unit in ipairs(systemDateFormat) do
		systemDateFormat[i] = "<u(" .. unit .. ")>"
	end
	systemDateFormat = table.concat(systemDateFormat, ".")
	return T{systemDateFormat, month = month, day = day, year = year}
end

---
--- Gets the date in the system's date format in month-day-year order.
---
--- @param context_obj any The context object (unused).
--- @param month number The month to format.
--- @param day number The day to format.
--- @param year number The year to format.
--- @return string The formatted date.
---
TFormat.date_mdy = function(context_obj, month, day, year)
	local systemDateFormat = GetDateTimeOrder()
	for i, unit in ipairs(systemDateFormat) do
		systemDateFormat[i] = "<u(" .. unit .. ")>"
	end
	systemDateFormat = table.concat(systemDateFormat, "-")
	return T{systemDateFormat, month = month, day = day, year = year}
end

---
--- Formats a time value as a string in the format "HH:MM".
---
--- @param context_obj any The context object (unused).
--- @param time number The time value to format, in milliseconds. If not provided, uses the current campaign time.
--- @return string The formatted time string.
---
TFormat.time = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	local mins = string.format("%02d", t.min)
	local hours = string.format("%02d", t.hour)
	return T{109987777732, "<hours>:<mins>", hours = Untranslated(hours), mins = Untranslated(mins) }
end

---
--- Formats a time value as a string in the format "MM:SS".
---
--- @param context_obj any The context object (unused).
--- @param time number The time value to format, in milliseconds.
--- @return string The formatted time string.
---
TFormat.timeSecs = function(context_obj, time)
	local minNum = time / 1000 / 60
	local mins = string.format("%01d", minNum)
	local secs = string.format("%02d", (time - minNum * 1000 * 60) / 1000)
	return T{537833878288, "<mins>:<secs>", mins = Untranslated(mins), secs = Untranslated(secs) }
end

---
--- Formats a time duration as a string in the format "DD:HH:MM" or "HH:MM" or "MM" depending on the duration.
---
--- @param context_obj any The context object (unused).
--- @param time number The time value to format, in seconds.
--- @return string The formatted time string.
---
TFormat.timeDuration = function(context_obj, time)
	-- Satellite time is stored in seconds, not milliseconds
	local minutes = time / 60
	local hours = minutes / 60
	local days = hours / 24
	if days > 0 then
		local hoursLeft = hours - days * 24
		if hoursLeft > 0 then
			return T{407759704918, "<days>D <hours>h", days = days, hours = hoursLeft}
		else
			return T{582737918674, "<days>D", days = days}
		end
	end
	if hours > 0 then
		local minutesLeft = minutes - hours * 60
		if minutesLeft > 0 then
			return T{310898452498, "<hours>h <minutes>m", hours = hours, minutes = minutesLeft}
		else
			return T{527198904622, "<hours>h", hours = hours}
		end
	else
		return T{880672979292, "<mins>m", mins = minutes}
	end
end

---
--- Formats a time value as a string representing the year.
---
--- @param context_obj any The context object (unused).
--- @param time number The time value to format, in milliseconds.
--- @return string The formatted year string.
---
TFormat.year = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return Untranslated(t.year)
end

---
--- Formats a monetary value as a string with a currency symbol.
---
--- @param context_obj any The context object (unused).
--- @param value number The monetary value to format.
--- @return string The formatted monetary value string.
---
TFormat.money = function(context_obj, value)
	if value >= 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{259741266711, --[[currency formatting negative]] "-$<money>", money = FormatNumber(abs(value), false)}
	end
end

---
--- Formats a monetary value as a string with a currency symbol.
---
--- @param context_obj any The context object (unused).
--- @param value number The monetary value to format.
--- @return string The formatted monetary value string.
---
TFormat.balanceDisplay = function(context_obj, value)
	if value >= 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{212953538446, --[[currency formatting negative]] "<red>-$<money></red>", money = FormatNumber(abs(value), false)}
	end
end

---
--- Formats a monetary value as a string with a rounded value.
---
--- @param context_obj any The context object (unused).
--- @param value number The monetary value to format.
--- @param granularity number The rounding granularity, defaults to 500.
--- @return string The formatted monetary value string.
---
TFormat.moneyRounded = function(context_obj, value, granularity)
	granularity = granularity or 500
	value = round(value, granularity)
	return T{729420047388, "~<money(value)>", value = value}
end

---
--- Formats a monetary value as a string with a positive, negative, or zero sign.
---
--- @param context_obj any The context object (unused).
--- @param value number The monetary value to format.
--- @return string The formatted monetary value string.
---
TFormat.moneyWithSign = function(context_obj, value)
	if value > 0 then
		return T{950883598077, --[[currency formatting positive with sign]] "+$<money>", money = FormatNumber(value, false)}
	elseif value == 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{464630604806, --[[currency formatting negative with sign]] "-$<money>", money = FormatNumber(abs(value), false)}
	end
end

---
--- Formats a monetary value as a string with a currency icon.
---
--- @param context_obj any The context object (unused).
--- @param value number The monetary value to format.
--- @return string The formatted monetary value string with a currency icon.
---
TFormat.moneyWithIcon = function(context_obj, value)
	return T{581847052427, --[[currency formatting]] "<money><image UI/SectorOperations/T_Icon_Money 2000>", money = FormatNumber(value, true)}
end

---
--- Formats a number as a string with a positive, negative, or zero sign.
---
--- @param context_obj any The context object (unused).
--- @param value number The number to format.
--- @return string The formatted number string with a sign.
---
TFormat.numberWithSign = function(context_obj, value)
	return FormatNumber(value, true)
end

--- Counts the number of elements in the provided context object.
---
--- @param context_obj any The context object to count the elements of.
--- @return number The number of elements in the context object.
---
TFormat.countCtx = function(context_obj)
	return context_obj and #context_obj
end

---
--- Formats a number as a string with an optional positive, negative, or zero sign.
---
--- @param value number The number to format.
--- @param withSign boolean Whether to include a sign (+ or -) in the formatted string.
--- @return string The formatted number string with an optional sign.
---
function FormatNumber(value, withSign)
	if not value then
		value = 0
	end

	local prefix = ""
	if withSign then
		if value > 0 then
			prefix = "+"
		end
	end
	
	return T{269645844644, "<prefix><value>", prefix = prefix, value = value}
end

--- Returns the display name of the operation associated with the provided context object.
---
--- @param context_obj table The context object containing the operation information.
--- @return string The display name of the operation, or "None" if no operation is provided.
---
TFormat.GetMercOperationText = function(context_obj)
	if context_obj and context_obj.Operation then
		return SectorOperations[context_obj.Operation].display_name
	else
		return T(601695937982, "None")
	end
end

--- Returns the display name of the provided sector, including the sector ID.
---
--- @param sector table|string The sector object or sector ID to get the display name for.
--- @return string The display name of the sector, including the sector ID.
function GetSectorName(sector)
	if not IsKindOf(sector, "SatelliteSector") then
		sector = ResolvePropObj(sector)
		sector = IsKindOf(sector, "SatelliteSector") and sector
	end

	if sector then
		return (sector.display_name or "").." ("..GetSectorId(sector)..")"
	end
	return ""
end

--- Returns the display name of the provided sector, including the sector ID.
---
--- @param context_obj table|string The context object or sector ID to get the display name for.
--- @return string The display name of the sector, including the sector ID.
TFormat.SectorName = function(context_obj, sector)
	if type(sector) == "string" then sector = gv_Sectors and gv_Sectors[sector] end
	sector = sector or context_obj
	return GetSectorName(sector)
end

--- Returns the sector ID for the provided sector object.
---
--- @param sector table The sector object to get the ID for.
--- @return string The sector ID, or `false` if no sector is provided.
function GetSectorId(sector)
	if not sector then return false end
	if sector.GroundSector then return Untranslated(sector.GroundSector) .. T(367876597727, --[[suffix added to ground sector to get the underground sector ID. For example, the sector under H3 will become H3U]] "U") end
	return Untranslated(sector.name)
end

--- Returns the sector ID for the provided sector ID.
---
--- @param context_obj table|string The context object or sector ID to get the sector ID for.
--- @param sectorId string The sector ID to get the sector ID for.
--- @return string The sector ID, or `false` if no sector is provided.
TFormat.SectorId = function(context_obj, sectorId)
	return GetSectorId(gv_Sectors and gv_Sectors[sectorId])
end

--- Returns the sector ID for the provided sector object, with the sector control color applied.
---
--- @param context_obj table|string The context object or sector ID to get the colored sector ID for.
--- @param sectorId string The sector ID to get the colored sector ID for.
--- @return string The colored sector ID, or `false` if no sector is provided.
TFormat.SectorIdColored = function(context_obj, sectorId)
	local sector
	if context_obj and context_obj.metadata and context_obj.metadata.sector then
		sector = {}
		sector.Side = context_obj.metadata.side
		sector.GroundSector = context_obj.metadata.ground_sector
		sector.name = sectorId
	else
		sector = gv_Sectors and gv_Sectors[sectorId]
	end
	if not sector then return false end
	local _, _, _, textColor = GetSectorControlColor(sector.Side)
	local sectorId = GetSectorId(sector)
	local concat = textColor .. sectorId .. "</color>"
	return T{concat}
end

---
--- Returns the sector ID for the provided sector object, with the sector control color applied.
---
--- @param context_obj table|string The context object or sector ID to get the colored sector ID for.
--- @param sectorId string The sector ID to get the colored sector ID for.
--- @return string The colored sector ID, or `false` if no sector is provided.
TFormat.SectorIdColored2 = function(context_obj, sectorId)
	local sector = gv_Sectors and gv_Sectors[sectorId]
	if not sector then return false end
	local _, textColor, _, _ = GetSectorControlColor(sector.Side)
	local sectorId = GetSectorId(sector)
	local concat = textColor .. sectorId .. "</color>"
	return T{concat}
end

---
--- Concatenates a list of sectors into a string, with an optional emphasis on the sector names.
---
--- @param context_obj table|string The context object or list of sectors to format.
--- @param list table The list of sectors to format.
--- @param emphasize boolean Whether to emphasize the sector names.
--- @return string The formatted list of sectors.
---
TFormat.SectorList = function(context_obj, list, emphasize)
	list = list or context_obj
	return ConcatListWithAnd(table.map(list, function(o)
		if emphasize then
			return T{962039320355, "<em><SectorName(sector)></em>", sector = gv_Sectors[o]}
		end
		return GetSectorName(gv_Sectors[o]);
	end))
end

---
--- Returns the militia count for the specified sector.
---
--- @param context_obj table|string The context object or sector ID to get the militia count for.
--- @param sector table The sector object to get the militia count for.
--- @return number The militia count for the specified sector.
---
TFormat.SectorMilitiaCount = function(context_obj, sector)
	if not context_obj and not sector then return 0 end
	return Untranslated(GetSectorMilitiaCount((sector or context_obj).Id))
end

---
--- Returns the total unit count for the provided context object.
---
--- @param context_obj table The context object containing the sectors to count units for.
--- @return number The total unit count for the provided context object.
---
TFormat.UnitsCountOnly = function (context_obj)
	if not context_obj then return 0 end

	local unitCount = 0
	for i, s in ipairs(context_obj) do
		if s.units then
			local count = #s.units
				unitCount = unitCount + count
		end
	end
	
	if unitCount > 0 then
		return T{429365736153, "<unitCount>", unitCount = unitCount }
	else
		return T(720023491189, "?")
	end
end

---
--- Formats a campaign time value into a human-readable string.
---
--- @param time number The time value to format.
--- @param in_days boolean|string Whether to format the time in days. If set to "all", the time will be formatted in days, hours, and minutes.
--- @return string The formatted time string.
---
function FormatCampaignTime(time, in_days)
	if in_days=="all" then -- XD XH XM
		local days = Max(0, time / const.Scale.day)
		local hours = Max(0, (time - days * const.Scale.day) / const.Scale.h)
		local mins = (time - (time / const.Scale.h) * const.Scale.h) / const.Scale.min
		if days == 0 then
			return T{211297072165, "<hours>H <mins>M", hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
		elseif mins == 0 then
			return T{457936384867, "<days>D <hours>H", days = days, hours = Untranslated(string.format("%02d", hours))}
		else
			return T{574423138475, "<days>D <hours>H <mins>M", days = days,hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
		end
	elseif in_days then -- XD || XH
		local days = Max(0, time / const.Scale.day)
		local hours = Max(0, (time - days * const.Scale.day) / const.Scale.h)
		if hours == 0 then
			return T{582737918674, "<days>D", days = days}
		end
		if days == 0 then
			return T{402839920108, "<hours>H", hours = hours}
		end
		
		return T{344180072111, "<days>D", days = days}
	else -- XH XM
		local hours = time / const.Scale.h
		local mins = (time - hours * const.Scale.h) / const.Scale.min
		return T{211297072165, "<hours>H <mins>M", hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
	end
end

-- Prediction magic
-- add already assigned units + merc that are newly added and are not with that profession/operation
---
--- Calculates the time left for an operation to be completed, taking into account any additional units that are being assigned to the operation.
---
--- @param merc table|nil The merc for which to calculate the operation time left. If not provided, the first unit in the `add_units` table will be used.
--- @param operation string The name of the operation.
--- @param context table A table containing additional context information, such as the sector, list of units to add, etc.
--- @return number The time left for the operation to be completed, in seconds.
---
function GetOperationTimeLeftAssign(merc, operation, context)
	if (not context or not next(context.add_units)) and not merc then
		return 0
	end	
	
	local operationPreset = SectorOperations[operation]
	local additional_units = context.add_units		
	if merc then 
		table.insert(additional_units, 1, merc)
	end
	local merc = merc or additional_units[1]
		
	local sector = context.sector or merc:GetSector()
	local sector_id = sector.Id

	if operation=="RAndR" then			
		return GetActorOperationTimeLeft(merc, "RAndR", "Restman")
	end
	
	if operation=="TrainMercs" then
		local teacher = context.list_as_prof=="Teacher" and merc
		if not teacher then
			local mercs = GetOperationProfessionalsGroupedByProfession(sector_id, "TrainMercs")
			local 	teachers = mercs["Teacher"] or mercs["Student"]
			teacher = teachers and teachers[1] or merc
		end	
		return GetActorOperationTimeLeft(teacher, "TrainMercs")
	end

	local already_assigned = GetOperationProfessionals(sector_id, operation,context.list_as_prof)
	if IsOperationHealing(operation) then
		local slowest
		if context.list_as_prof=="Patient" then
			for _, unit_data in ipairs(additional_units or empty_table) do
				slowest = Max(slowest or 0, GetPatientHealingTimeLeft(unit_data))
			end
		end
		for _, unit in ipairs(GetOperationProfessionals(sector_id, operation, "Patient")) do
			slowest = Max(slowest or 0, GetPatientHealingTimeLeft(unit))
		end
		return slowest
	end
	
	if operation == "RepairItems" then
		local queue = SectorOperationItems_GetItemsQueue(sector_id,"RepairItems")
		local min_time = SectorOperations["RepairItems"]:ResolveValue("min_time")
		if not next(queue) then 
			return min_time*const.Scale.h
		end
		
		local progress_per_tick = GetSumOperationStats(already_assigned, "Mechanical", operationPreset:ResolveValue("stat_multiplier"))					
		progress_per_tick = progress_per_tick + GetSumOperationStats(additional_units, "Mechanical", operationPreset:ResolveValue("stat_multiplier"))					
		local current_progress = operationPreset:ProgressCurrent(already_assigned[1] or merc, sector, "prediction") or 0
		local left_progress = operationPreset:ProgressCompleteThreshold(already_assigned[1] or merc, sector,"prediction") - current_progress
		local ticks_left = progress_per_tick>0 and Max(0,left_progress / progress_per_tick) or 0		
   
		return min_time*const.Scale.h + Max(ticks_left*const.Satellite.Tick, 0)
	end				
	
	--intel, militia, repairitems, craft some custom thatare not heal			
	-- get already assigned
	local progress_per_tick = 0
	for _, unit_data in ipairs(already_assigned or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data)
	end
	for _, unit_data in ipairs(additional_units or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data, "prediction")
	end
				
	if CheatEnabled("FastActivity") then
		progress_per_tick = progress_per_tick*100
	end

	local current_progress = operationPreset:ProgressCurrent(already_assigned[1] or merc, sector) or 0
	local left_progress = operationPreset:ProgressCompleteThreshold(already_assigned[1] or merc, sector) - current_progress
	local ticks_left = progress_per_tick>0 and left_progress / progress_per_tick or 0
	if left_progress > 0 then
		ticks_left = Max(ticks_left, 1)
	end
	return ticks_left*const.Satellite.Tick
end

-- merc
---
--- Calculates the remaining time for an operation to complete.
---
--- @param merc UnitData|Unit The unit performing the operation.
--- @param operation string The name of the operation.
--- @param context table Optional context information for the operation.
--- @return number The remaining time in seconds for the operation to complete.
function GetOperationTimeLeft(merc, operation, context)
	local operationPreset = SectorOperations[operation]

	if context and context.add_units and #context.add_units > 0 then	  		
		return GetOperationTimeLeftAssign(merc, operation, context)
	end

	-- not assigning / rollvoer,timeline, progress/
	if operation == "Arriving" then
		return operationPreset:ProgressCompleteThreshold(merc, false) - merc.arriving_progress
	end
	
	if operation == "Traveling" then
		return operationPreset:ProgressCompleteThreshold(merc, false) - merc.traveling_progress
	end
	
	if operation == "Idle" then
		return SatelliteUnitRestTimeRemaining(merc) or 0
	end

	if operation=="RAndR" then
		context = context or {}
		context.merc = merc
		return GetActorOperationTimeLeft(merc,"RAndR", "Restman")
	end
	
	-- healing
	if IsOperationHealing(operation) then
		context = context or {}
		context.merc = merc
		if context.all then
			context.list_as_prof = false -- slowlest
			return TreatWoundsTimeLeft(context,operation)
		else
			return TreatWoundsTimeLeft(context,operation)
		end
	end
	
	local sector =  context and context.sector or merc and merc:GetSector()
	local sector_id = sector and sector.Id
	if operation == "TrainMercs" then
		context = context or {}
		context.merc = merc		
		
		local mercs = GetOperationProfessionalsGroupedByProfession(sector_id, "TrainMercs")
		local 	students = mercs["Student"]
		local 	teachers = mercs["Teacher"]
		if not context.prediction and not next(students) then
			return 0
		end
		return GetActorOperationTimeLeft(teachers[1] or context.merc or students[1], "TrainMercs")
	end
	
	if operation == "RepairItems" then	
		local left_time = merc and  GetActorOperationTimeLeft(merc, "RepairItems","prediction") or 0
		local min_time = operationPreset:ResolveValue("min_time")
		
		local time = sector.started_operations and sector.started_operations["RepairItems"]
		if not time or type(time)~= "number" then
			time = Game.CampaignTime			
		end
		return Max(0,left_time) + Max(0,min_time*const.Scale.h	 - (Game.CampaignTime - time))
	end
	
	-- other operations
	local already_assigned = GetOperationProfessionals(sector_id, operation, context and context.list_prof)
	local progress_per_tick = 0
	for _, unit_data in ipairs(already_assigned or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data, "prediction")
	end
	if CheatEnabled("FastActivity") then
		progress_per_tick = progress_per_tick*100
	end
	local left_progress = operationPreset:ProgressCompleteThreshold(merc, sector, "prediction") - operationPreset:ProgressCurrent(merc, sector, "prediction")
	local ticks_left = progress_per_tick>0 and left_progress / progress_per_tick or 0
	return ticks_left*const.Satellite.Tick
end

---
--- Returns the estimated time remaining for a mercenary's current operation.
---
--- @param merc table The mercenary whose operation time is being calculated.
--- @param prediction boolean (optional) If true, the function will return the predicted time remaining, otherwise it will return the actual time remaining.
--- @return number The estimated time remaining for the mercenary's current operation, in seconds.
function GetOperationTimerETA(merc, prediction)
	local list_as_prof
	if IsPatient(merc) and not IsDoctor(merc) then
		list_as_prof = "Patient"
	end
	if merc.OperationProfession == "Student" then
		list_as_prof = "Student"
	end	

	return merc.Operation ~= "Idle" and GetOperationTimeLeft(merc, merc.Operation, {list_as_prof = list_as_prof, prediction = prediction})
end

---
--- Returns the estimated initial travel time for a mercenary's current operation.
---
--- @param merc table The mercenary whose operation time is being calculated.
--- @return number The estimated initial travel time for the mercenary's current operation, in seconds.
function GetOperationTimerInitialETA(merc)
	if merc.Operation == "Traveling" then
		local squad = merc.Squad and gv_Squads[merc.Squad]
		if squad then
			local breakdown = GetRouteInfoBreakdown(squad, squad.route)												
			local total = breakdown.total					
			return total.travelTime
		end
	end
	return GetOperationTimerETA(merc)
end

---
--- Returns a formatted string representing the remaining time on a mercenary's contract.
---
--- @param context_obj table The mercenary data object.
--- @return string The formatted remaining contract time, or "Expired" if the contract has expired.
---
TFormat.MercContractTime = function(context_obj)
	if not IsKindOfClasses(context_obj, "UnitData", "Unit") or not context_obj.HiredUntil then return "" end
	
	local remaining_time = context_obj.HiredUntil - Game.CampaignTime
	if remaining_time <= 0 then 
		return T(659003766070, "Expired")
	else 
		return FormatCampaignTime(remaining_time, "in_days")
	end
end

---
--- Returns the name of the other player in the current network game.
---
--- @return string The name of the other player, or an empty string if there is no other player.
---
TFormat.OtherPlayerName = function(context_obj)
	if not netInGame then return "" end
	if not netGamePlayers then return "" end
	
	for i, p in ipairs(netGamePlayers) do
		if p.id ~= netUniqueId then
			return Untranslated(p.name)
		end
	end
	
	return ""
end

---
--- Formats the given campaign time value as a string.
---
--- @param context_obj table The context object, not used.
--- @param value number The campaign time value to format.
--- @return string The formatted campaign time string.
---
TFormat.CampaignTime = function(context_obj, value)
	return FormatCampaignTime(value)
end

---
--- Returns a formatted string describing the Forgiving mode game rule.
---
--- The text returned will be different depending on the platform the game is running on.
---
--- @param context_obj table The context object, not used.
--- @return string The formatted Forgiving mode description.
---
TFormat.ForgivingModeText = function(context_obj)
	if Platform.ps5 or Platform.ps4 or g_TestUIPlatform == "ps4" or g_TestUIPlatform == "ps5" then
		return T(284695860080, --[[GameRuleDef ForgivingMode Playstation description]] 'Lowers the impact of attrition and makes it easier to recover from bad situations (faster healing and repair, better income).<newline><newline><flavor>You cannot unlock the "Ironman" trophy while Forgiving mode is enabled.</flavor><newline><newline><flavor>You can change this option at any time during gameplay.</flavor>')
	end
	
	return T(823257619450, --[[GameRuleDef ForgivingMode description]] 'Lowers the impact of attrition and makes it easier to recover from bad situations (faster healing and repair, better income).<newline><newline><flavor>You cannot unlock the "Ironman" achievement while Forgiving mode is enabled.</flavor><newline><newline><flavor>You can change this option at any time during gameplay.</flavor>')
end

table.insert(BlacklistedDialogClasses, "TacticalNotification")
table.insert(BlacklistedDialogClasses, "Intro")
table.insert(BlacklistedDialogClasses, "MPPauseHint")

local function lGetTacticalNotificationState()
	local dlg = GetDialog("TacticalNotification")
	if dlg then
		if dlg.state then return dlg.state, dlg end
		dlg.state = {}
		return dlg.state, dlg
	end
	return false
end

local function lTacticalNotificationRemoveExpired(state)
	local now = RealTime()
	for i, notify in pairs(state) do
		local endPoint = notify.start + notify.duration
		if notify.duration ~= -1 and now >= endPoint then
			state[i] = nil
		end
	end
	table.compact(state)
end

local function lUpdateTacticalNotificationShown(instant_hide)
	local state, dlg = lGetTacticalNotificationState()
	if not state then return end
	lTacticalNotificationRemoveExpired(state)

	dlg:DeleteThread("updater");
	local top, topPrio = false, false -- Smallest priority integer on top
	for i, notification in ipairs(state) do
		if not topPrio or notification.priority < topPrio then
			top = notification
			topPrio = notification.priority
		end
	end

	local currentlyPlaying = dlg:GetVisible()
	if top then
		dlg:SetMode(top.style or "red")
		local txtBox = dlg:ResolveId("idText")
		txtBox:SetText(top.text)

		if top.secondaryText then
			txtBox = dlg:ResolveId("idBottomText")
			txtBox:SetText(top.secondaryText)
		end

		if top.duration ~= -1 then
			dlg:CreateThread("updater", function()
				local endPoint = top.start + top.duration
				Sleep(endPoint - RealTime())
				DelayedCall(0, lUpdateTacticalNotificationShown)
			end)
		end

		if not currentlyPlaying then
			dlg:SetVisible(true)
			if top.combatLog then 
				CombatLog(top.combatLogType,top.text)
			end
		end

		return
	end

	-- not top (no notification active)
	if currentlyPlaying then
		dlg:SetVisible(false, instant_hide)
	end
end

---
--- Returns the text of the tactical notification with the given group or mode.
---
--- @param groupOrId string The group or mode of the tactical notification to get the text for.
--- @return string The text of the tactical notification, or nil if not found.
function GetTacticalNotificationText(groupOrId)
	local state = lGetTacticalNotificationState()
	for i, notify in ipairs(state) do
		if notify.mode == groupOrId or notify.group == groupOrId then
			return notify.text
		end
	end
end

---
--- Hides the tactical notification with the given group or mode.
---
--- @param groupOrId string The group or mode of the tactical notification to hide.
--- @param instant boolean If true, the notification will be hidden immediately. Otherwise, it will be hidden after its duration.
---
function HideTacticalNotification(groupOrId, instant)
	local state = lGetTacticalNotificationState()
	for i, notify in ipairs(state) do
		if notify.mode == groupOrId or notify.group == groupOrId then
			notify.start = 0
			notify.duration = 0
		end
	end
	lUpdateTacticalNotificationShown(instant)
end

local function lSetTacticalNotificationMode(mode, on)
	local dlg = GetDialog("TacticalNotification")
	if not dlg then return end
	if not dlg.orderMode then
		dlg.orderMode = {}
	end
	
	dlg.orderMode[mode] = on
	
	local setpieceOn = dlg.orderMode["setpiece"]
	local pdaOn = dlg.orderMode["pda"]
	
	if setpieceOn then
		dlg:SetDrawOnTop(true)
		dlg:SetZOrder(100)
		return
	end
	
	if pdaOn then
		dlg:SetDrawOnTop(false)
		dlg:SetZOrder(0)
		return
	end
	
	dlg:SetDrawOnTop(false)
	dlg:SetZOrder(1)
end

function OnMsg.WillStartSetpiece()
	lSetTacticalNotificationMode("setpiece", true)
end

function OnMsg.SetpieceDialogClosed()
	lSetTacticalNotificationMode("setpiece", false)
	if not cameraTac.IsActive() then
		print("setpiece left camera as not tac")
		cameraTac.Activate()
	end
end

function OnMsg.OpenPDA()
	lSetTacticalNotificationMode("pda", true)
end

function OnMsg.ClosePDA()
	lSetTacticalNotificationMode("pda", false)
end

function OnMsg.DoneMap()
	local tactNot = GetDialog("TacticalNotification")
	if tactNot then
		tactNot.FadeOutTime = 0
		tactNot:Close()
	end
end

--  mode - This is the id of a listitem tactical notifiction
--  keepVisible - Whether to keep the notification visible until the hide func is called
--  text - Can override the preset's text. Currently unused
--  context - for the text.
---
--- Shows a tactical notification dialog.
---
--- @param mode string The ID of the tactical notification to show.
--- @param keepVisible boolean Whether to keep the notification visible until the hide function is called.
--- @param text string Can override the preset's text. Currently unused.
--- @param context table For the text.
---
function ShowTacticalNotification(mode, keepVisible, text, context)
	if CheatEnabled("CombatUIHidden") then return end

	local state, dlg = lGetTacticalNotificationState()
	if not dlg then
		dlg = OpenDialog("TacticalNotification")
		lSetTacticalNotificationMode("setpiece", IsSetpiecePlaying())
		lSetTacticalNotificationMode("pda", GetDialog("PDADialogSatellite"))
		state = {}
		dlg.state = state
	end

	local startTime = RealTime()

	-- Check if already exists in state.
	if table.find(state, "mode", mode) and mode ~= "customText" then
		return
	end

	-- Add to list.
	local preset = Presets.TacticalNotification.Default[mode]
	assert(preset)
	text = text or preset.text
	local secondaryText = preset.secondaryText
	if context then
		text = Untranslated(_InternalTranslate(T{text, context}))
		secondaryText = secondaryText and Untranslated(_InternalTranslate(T{secondaryText, context}))
	end
	local newEntry = {
		mode = mode,
		group = preset.removalGroup,
		text = text,
		secondaryText = secondaryText,
		start = RealTime(),
		priority = preset.SortKey,
		duration = keepVisible and -1 or preset.duration or 0,
		style = preset.style,
		combatLog = preset.combatLog,
		combatLogType = preset.combatLogType
	}
	state[#state + 1] = newEntry

	lUpdateTacticalNotificationShown()
end

function OnMsg.TurnEnded()
	HideTacticalNotification("turn")
end

---
--- Shows a notification for the current player's turn.
--- This function is called when the turn ends to display a message indicating whose turn it is.
--- The message is displayed in the in-game interface dialog and fades out after 1 second.
---
--- @param none
--- @return none
---
function ShowTurnNotification()
	if CheatEnabled("CombatUIHidden") then return end

	local dlg = GetInGameInterfaceModeDlg()
	if not dlg then return end
	local idTurnText = dlg:ResolveId("idTurnText")
	if not idTurnText then return end
	
	if not netGamePlayers or #netGamePlayers < 2 then return end
	
	local currentTeamSide = g_Teams[g_CurrentTeam].side
	local playerName
	if currentTeamSide == "player1" then
		playerName = netGamePlayers[1].name
	elseif currentTeamSide == "player2" then
		playerName = netGamePlayers[2].name
	end
	
	idTurnText:SetText(T{845626429475, "<name>'s TURN", name = Untranslated(playerName)})
	idTurnText:SetVisible(true)
	-- Fast fingers
	idTurnText:DeleteThread("fadeOutThread")
	idTurnText:CreateThread("fadeOutThread", function(self) 
		Sleep(1000)
		self:SetVisible(false)
	end, idTurnText)
end

-- Squads and sectors

if FirstLoad then
	g_SquadsArray = false
	g_PlayerSquads = false
	g_PlayerAndMilitiaSquads = false
	g_MilitiaSquads = false
	g_EnemySquads =  false
end

---
--- Adds a squad to various lists based on the squad's side.
---
--- @param squad table The squad to add to the lists.
--- @return none
---
function AddSquadToLists(squad)
	table.insert(g_SquadsArray, squad)
	if (squad.Side == "enemy1" or squad.Side == "enemy2") then		
		g_EnemySquads[#g_EnemySquads + 1] = squad
	elseif (squad.Side == "player1" or squad.Side == "player2" or squad.Side == "ally") then
		if not squad.militia then
			g_PlayerSquads[#g_PlayerSquads + 1] = squad
		else	
			g_MilitiaSquads[#g_MilitiaSquads + 1] = squad
		end	
		g_PlayerAndMilitiaSquads[#g_PlayerAndMilitiaSquads + 1] = squad
	end
	AddSquadToSectorList(squad,squad.CurrentSector)
end

function RemoveSquadsFromLists(squad)
	table.remove_value(g_SquadsArray, squad)
	table.remove_value(g_PlayerSquads, squad)
	table.remove_value(g_PlayerAndMilitiaSquads, squad)
	table.remove_value(g_MilitiaSquads,squad)
	table.remove_value(g_EnemySquads,squad)
	RemoveSquadFromSectorList(squad)
end

function OnMsg.PreLoadSessionData()
	g_SquadsArray = {}
	g_PlayerSquads = {}
	g_PlayerAndMilitiaSquads = {}
	g_MilitiaSquads = {}
	g_EnemySquads = {}
	for id, squad in sorted_pairs(gv_Squads) do
		AddSquadToLists(squad)
	end
end

function OnMsg.NewGame()
	g_SquadsArray = {}
	g_PlayerSquads = {}
	g_PlayerAndMilitiaSquads = {}
	g_MilitiaSquads = {}
	g_EnemySquads = {}
end

---
--- Returns a list of player squads, optionally including militia squads.
---
--- @param include_militia boolean Whether to include militia squads in the returned list.
--- @return table A table containing the player squads, or an empty table if there are no player squads.
---
function GetPlayerMercSquads(include_militia)
	return include_militia and g_PlayerAndMilitiaSquads or g_PlayerSquads or empty_table
end

---
--- Returns a list of the IDs of all units that are part of the player's squads.
---
--- @return table A table containing the IDs of all units in the player's squads.
---
function GetHiredMercIds()
	local ids = {}
	for _, squad in ipairs(g_PlayerSquads) do
		table.iappend(ids, squad.units)
	end
	return ids
end

---
--- Returns whether there are any player squads.
---
--- @return boolean True if there are any player squads, false otherwise.
---
function AnyPlayerSquads()
	return next(g_PlayerSquads)	
end

---
--- Checks if there are any player squads in the specified sector.
---
--- @param sector_id string The ID of the sector to check.
--- @return boolean, Squad Whether there are any player squads in the sector, and the first one found.
---
function AnyPlayerSquadsInSector(sector_id)
	local sectorData = gv_Sectors[sector_id]
	for _, s in ipairs(g_PlayerSquads) do
		local squadSector = s.CurrentSector
		local squadSectorData = gv_Sectors[squadSector]
		local here = not sectorData or (squadSectorData and 
			(squadSector == sector_id or squadSectorData.GroundSector == sector_id or sectorData.GroundSector == squadSector))
		if here then return true, s end
	end
	return false
end

function TFormat.PlayerMercCount()
	return CountPlayerMercsInSquads()
end

---
--- Counts the number of player mercenaries in the player's squads.
---
--- @param affiliation? string The affiliation of the units to count. If not provided, all units are counted.
--- @param includeImp? boolean If true, include Imperial units in the count.
--- @return integer The number of player mercenaries in the player's squads.
---
function CountPlayerMercsInSquads(affiliation, includeImp)
	local count = 0
	for _, s in ipairs(g_PlayerSquads) do
		for i, u in ipairs(s.units) do
			local ud = gv_UnitData[u]
			local affiliated = (not affiliation or ud.Affiliation == affiliation)
			if not affiliated and includeImp then
				local template = UnitDataDefs[ud.class]
				affiliated = template and template.group == "IMP"
			end
			if ud and affiliated then
				count = count + 1
			end
		end
	end
	return count
end

---
--- Counts the total number of units across the given squads.
---
--- @param squads table A table of squads to count the units of.
--- @return integer The total number of units across the given squads.
---
function CountUnitsInSquads(squads)
	local count = 0
	for _, squad in ipairs(squads) do
		count = count + #squad.units
	end
	return count
end

---
--- Gets the militia squads in the given sector.
---
--- @param sector table The sector to get the militia squads for.
--- @return table The militia squads in the given sector.
---
function GetMilitiaSquads(sector)
	local squads = {}
	for _, squad in ipairs(g_MilitiaSquads) do
		if squad.CurrentSector == sector.Id then
			squads[#squads+1] = squad
		end
	end
	return squads
end

--player and allySquads
--enemySquads
--player and militia
--underground
---
--- Removes a squad from the sector list.
---
--- @param squad table The squad to remove from the sector list.
--- @param prev_sector_id string The previous sector ID of the squad.
---
function RemoveSquadFromSectorList(squad, prev_sector_id)
	prev_sector_id = prev_sector_id or squad.CurrentSector
	if not prev_sector_id then return end
	local prev_sector = gv_Sectors[prev_sector_id]
		
	table.remove_value(prev_sector.underground_squads, squad)
	table.remove_value(prev_sector.enemy_squads, squad)
	table.remove_value(prev_sector.ally_squads, squad)
	table.remove_value(prev_sector.militia_squads, squad)
	table.remove_value(prev_sector.ally_and_militia_squads, squad)
	table.remove_value(prev_sector.all_squads, squad)
	if prev_sector.GroundSector then
		local ground =  gv_Sectors[prev_sector.GroundSector]
		table.remove_value(ground.underground_squads, squad)
		table.remove_value(ground.all_squads, squad)
	end
end	

---
--- Adds a squad to the sector list.
---
--- @param squad table The squad to add to the sector list.
--- @param sector_id string The ID of the sector to add the squad to.
---
function AddSquadToSectorList(squad, sector_id)
	if not sector_id then return end
	local sector = gv_Sectors[sector_id]
	
	-- add to sector_lists
	sector.all_squads = sector.all_squads or {}
	assert(not table.find(sector.all_squads, squad))
	sector.all_squads[#sector.all_squads + 1] = squad
	if sector.GroundSector then
		local ground =  gv_Sectors[sector.GroundSector]
		ground.underground_squads = ground.underground_squads or {}
		ground.underground_squads[#ground.underground_squads + 1] = squad
		ground.all_squads = ground.all_squads or {}
		ground.all_squads[#ground.all_squads + 1] = squad
	end
	if (squad.Side == "player1" or squad.Side == "ally") then
		if not squad.militia then
			sector.ally_squads = sector.ally_squads  or {}
			sector.ally_squads[#sector.ally_squads + 1] = squad
		else	
			sector.militia_squads = sector.militia_squads  or {}
			sector.militia_squads[#sector.militia_squads + 1] = squad
		end	
		sector.ally_and_militia_squads =  sector.ally_and_militia_squads or {}
		sector.ally_and_militia_squads[#sector.ally_and_militia_squads + 1] = squad
	else -- Mirror behavior of GetSquadsInSector where non player squads are returned as enemy
		sector.enemy_squads = sector.enemy_squads or {}
		sector.enemy_squads[#sector.enemy_squads + 1] = squad
	end
end

---
--- Reindexes the elements in an array, moving the first element to the end.
---
--- @param array table The array to reindex.
--- @param first any The first element to move to the end.
--- @return table The reindexed array.
---
function SquadsReindexArray(array, first)
	local idx = table.find(array, first)
	if not idx or idx == 1 then return end
	for i=1, idx-1 do
		table.remove(array, 1)
		table.insert(array)
	end
	return array
end

---
--- Gets the allied and enemy squads in the specified sector.
---
--- @param sector_id string The ID of the sector to get the squads for.
--- @param excludeTravelling boolean (optional) If true, exclude squads that are travelling.
--- @param includeMilitia boolean (optional) If true, include militia squads.
--- @param excludeArriving boolean (optional) If true, exclude squads that are arriving.
--- @param excludeRetreating boolean (optional) If true, exclude squads that are retreating.
--- @return table, table The allied squads and enemy squads in the sector.
---
function GetSquadsInSector(sector_id, excludeTravelling, includeMilitia, excludeArriving, excludeRetreating)
	local sectorData = gv_Sectors[sector_id]
	-- in allmost all of calls only sector_id is passed, so precalc that result
	if sectorData and not excludeTravelling and not includeMilitia and not excludeArriving then
		return sectorData.ally_squads or empty_table, sectorData.enemy_squads or empty_table
	end
	
	-- Passing in no sector returns all squads
	local squadList = sectorData and sectorData.all_squads or g_SquadsArray
	
	local alliedSquads = {}
	local enemySquads = {}
	for i, s in ipairs(squadList) do
		if #s.units == 0 then goto continue end -- Squad being despawned
		if s.militia and not includeMilitia then goto continue end
		if s.arrival_squad and excludeArriving then goto continue end
		if excludeTravelling and IsSquadTravelling(s) then goto continue end
		if excludeTravelling and IsTraversingShortcut(s) then goto continue end
		if excludeRetreating and s.Retreat then goto continue end
		
		local squadSector = s.CurrentSector
		if not sectorData or squadSector == sector_id then
			if s.Side == "player1" or s.Side == "ally" then
				alliedSquads[#alliedSquads + 1] = s
			else
				enemySquads[#enemySquads + 1] = s
			end
		end
		::continue::
	end
	
	return alliedSquads, enemySquads
end

---
--- Combines the allied and enemy squads in the specified sector.
---
--- @param ... The same parameters as GetSquadsInSector.
--- @return table The combined list of allied and enemy squads in the sector.
---
function GetSquadsInSectorCombined(...)
	local newTable = {} -- We gotta copy cuz the return tables could be immutable/stateful
	local ally, enemy = GetSquadsInSector(...)
	table.iappend(newTable, ally)
	table.iappend(newTable, enemy)
	return newTable
end

--- Returns a list of all squads in the specified sector that are not militia.
---
--- @param sector The ID of the sector to get the squads for.
--- @return table The list of squads in the sector that are not militia.
function GetUngroupedSquadsInSector(sector)
	local squads = {}
	local sectorData = gv_Sectors[sector]
	for i, s in ipairs(g_SquadsArray) do
		if not s.militia then
			local squadSector = s.CurrentSector
			local squadSectorData = gv_Sectors[squadSector]
			if not sectorData or (squadSectorData and (squadSector == sector or squadSectorData.GroundSector == sector or sectorData.GroundSector == squadSector)) then
				squads[#squads + 1] = s
			end
		end
	end
	
	return squads
end

---
--- Returns a list of all mercenary units in the specified sector.
---
--- @param sector_id The ID of the sector to get the mercenary units for.
--- @return table The list of mercenary units in the sector.
---
function GetPlayerMercsInSector(sector_id)
	local mercs = {}
	local squads = GetSquadsInSector(sector_id)
	for i, s in ipairs(squads) do
		table.iappend(mercs, s.units)
	end
	return mercs
end

---
--- Returns a list of enemy squads in the specified sector.
---
--- @param sector The ID of the sector to get the enemy squads for.
--- @param ... Additional parameters to pass to GetSquadsInSector.
--- @return table The list of enemy squads in the sector.
---
function GetEnemiesInSector(sector, ...)
	local _, squads = GetSquadsInSector(sector, ...)
	if #squads == 0 and gv_Sectors[sector].conflict then
		return {{
			DisplayName = T(496804530535, "UNKNOWN ENEMIES"),
			units = false,
			Count = T(548893794472, "UNKNOWN STRENGTH")
		}}
	end
	return squads
end

---
--- Returns a list of all squads currently on the map for the current team.
---
--- @param references If true, the returned list will contain the actual squad objects instead of just their IDs.
--- @return table The list of squad IDs or squad objects currently on the map.
--- @return boolean Whether the current team is valid.
---
function GetSquadsOnMap(references)
	local team = GetCurrentTeam()
	if not team then return {}, false end
	local squads = {}
	for i, u in ipairs(team.units) do
		local squad = u:GetSatelliteSquad()
		if squad and not table.find(squads, squad.UniqueId) and not IsSquadTravelling(squad) and squad.CurrentSector == gv_CurrentSectorId then
			squads[#squads + 1] = squad.UniqueId
		end
	end
	table.sort(squads, function (a, b)
		return a > b
	end)
	if references then
		for i, s in ipairs(squads) do
			squads[i] = gv_Squads[s]
		end
	end
	return squads, team
end

---
--- Sorts a list of squads by their unique identifier.
---
--- @param squads table The list of squads to sort.
--- @return table The sorted list of squads.
---
function SortSquads(squads)
	table.sort(squads, function (a, b)
		return a.UniqueId < b.UniqueId
	end)
	
	return squads
end

---
--- Returns a list of all squads currently on the map for the current team.
---
--- @param references If true, the returned list will contain the actual squad objects instead of just their IDs.
--- @return table The list of squad IDs or squad objects currently on the map.
--- @return boolean Whether the current team is valid.
---
function GetSquadsOnMapUI()
	local team = GetCurrentTeam()
	if not team then return {}, false end
	
	local deadUnits = {}
	local squads = {}
	for i, u in ipairs(team.units) do
		-- Dead units retain a reference to which squad they were part in, but the squads dont link back to dead units.
		if u:IsDead() then
			local squadId = u.Squad;
			if not deadUnits[squadId] then deadUnits[squadId] = {} end
			table.insert(deadUnits[squadId], u)
		end
	
		-- Record all unique squads in the friendly combat team AKA all player controlled units on the map.
		local squad = IsValid(u) and u:GetSatelliteSquad()
		local squadHere = squad and squad.CurrentSector == gv_CurrentSectorId
		if squad and squadHere and not table.find(squads, squad.UniqueId) then
			squads[#squads + 1] = squad.UniqueId
		end
	end
	table.sort(squads, function (a, b)
		return a < b
	end)
	
	local squadsRefs = {}
	for i, s in ipairs(squads) do
		local squadObj = gv_Squads[s]
		local sId = squadObj.UniqueId
		local units = {}
		squadsRefs[#squadsRefs + 1] = 
		{
			Name = squadObj.Name,
			UniqueId = sId,
			units = units,
			image = squadObj.image,
			morale = MoraleLevelName[team.morale] or team.morale,
		}
		
		for i, u in ipairs(squadObj.units) do
			units[#units + 1] = g_Units[u]
		end
		for i, dUnit in ipairs(deadUnits[sId]) do
			units[#units + 1] = dUnit
		end
	end
	
	return squadsRefs
end

---
--- Returns a table of all units on the current map, filtered by the specified side.
---
--- @param enemy string The side to filter units by. Can be "enemy" or anything else to get player units.
--- @return table A table of units matching the specified side.
---
function GetCurrentMapUnits(enemy)
	return MapGet("map", "Unit", function(o, enemy)
		local squad = o:GetSatelliteSquad()
		local side = (o.team and o.team.side) or (squad and squad.Side) or (IsKindOf(o.spawner, "UnitMarker") and o.spawner.Side)
		if enemy == "enemy" then
			return (side == "enemy1" or side == "enemy2") and not o:IsDead() and not o:IsDefeatedVillain()
		else
			return side == "player1" and not o:IsDead()
		end
	end, enemy) or {}
end

---
--- Returns a table of all enemy units on the current map.
---
--- @return table A table of enemy units on the current map.
---
function GetCurrentMapPlayerUnits()
	return MapGet("map", "Unit", function(o)
		local squad = o:GetSatelliteSquad()
		local side = (o.team and o.team.side) or (squad and squad.Side) or (IsKindOf(o.spawner, "UnitMarker") and o.spawner.Side)
		return (side == "enemy1" or side == "enemy2") and not o:IsDead() and not o:IsDefeatedVillain()
	end) or {}
end

---
--- Groups a list of squads into a table of enemy mercenaries, optionally separating dead units.
---
--- @param squads table A list of squads to group.
--- @param separateDead boolean If true, dead units will be listed separately.
--- @return table A table of grouped enemy mercenaries.
---
function GroupEnemyMercs(squads, separateDead)
	local totalCount = 0
	local units = {}
	for i, s in ipairs(squads) do
		local shipmentPreset = false
		if (s.diamond_briefcase and gv_Sectors[s.CurrentSector].intel_discovered) or s.diamond_briefcase_dynamic then
			shipmentPreset = s.shipment_preset_id or "DiamondShipment"
			shipmentPreset = ShipmentPresets[shipmentPreset]
		end
	
		for _, u in ipairs(s.units or empty_table) do
			local data = gv_UnitData[u]
			if data then
				totalCount = totalCount + 1
				local is_dead = false
				local name = _InternalTranslate(data.Name)
				if separateDead and data.HitPoints == 0 then
					name = name .. "_dead"
					is_dead = true
				end
				
				local hasShipment = false
				if shipmentPreset and data:HasItem(shipmentPreset.item) then
					hasShipment = shipmentPreset.badge_icon
				end
				
				-- Count the units with the same name.
				if units[name] then
					local c = units[name].count
					units[name].count = c + 1
					local temps = units[name].templates
					temps[#temps + 1] = data
				else
					units[name] = {
						name = name,
						villain = data.villain,
						count = 1,
						template = data,
						DisplayName = data.Name,
						templates = { data },
						Side = s.Side,
						hasShipment = hasShipment,
						is_dead = separateDead and is_dead or false,
					}
				end
			end
		end
	end
	units = table.values(units) 
	table.sort(units, function(a, b)
		-- villain
		if a.villain and not b.villain then
			return true
		end	
		if b.villain and not a.villain then
			return false
		end	
		if a.count == b.count then
			return a.name<b.name
		end	
		-- count
		return a.count < b.count
	end)
	units.totalCount = totalCount
	return units
end

---
--- Returns a list of squads that are currently enroute to the specified sector.
---
--- @param sector string The sector to check for enroute squads.
--- @param side string The side of the squads to check, either "enemy1" or not "enemy1" (player).
--- @return table A table of squads that are enroute to the specified sector.
---
function GetSquadsEnroute(sector, side)
	local squads = side=="enemy1" and g_EnemySquads or g_PlayerSquads	

	local enroute = {}
	for i, s in ipairs(squads) do
		if not s.route then goto continue end
		if s.CurrentSector == sector then goto continue end
		
		local breakOut = false
		for _, rs in ipairs(s.route) do
			for __, sec in ipairs(rs) do
				if sec == sector then
					enroute[#enroute + 1] = s
					breakOut = true
					break
				end
			end
			if breakOut then break end
		end
		::continue::
	end
	
	return enroute
end

---
--- Returns a list of squads that are currently in the specified sector, optionally including militia and/or excluding enemy squads.
---
--- @param sector string The sector to check for squads.
--- @param includeMilitia boolean Whether to include militia squads.
--- @param get_enemies boolean Whether to return enemy squads instead of ally squads.
--- @param skip_retreat boolean Whether to skip squads that are retreating.
--- @param exclude_travelling boolean Whether to exclude squads that are travelling.
--- @return table A table of squads in the specified sector.
---
function GetGroupedSquads(sector, includeMilitia, get_enemies, skip_retreat, exclude_travelling)
	local squads = {}
	local joiningSquads = {}
	local satSquads = {}
	local ally, enemy = GetSquadsInSector(sector, exclude_travelling, includeMilitia)
	if get_enemies then
		satSquads = enemy
	else 
		satSquads = ally
	end
	
	for i, s in ipairs(satSquads) do
		if skip_retreat and s.Retreat then goto continue end
	
		squads[#squads + 1] = s
		
		::continue::
	end
	
	-- Add joining squads to squads, or as seperate squads
	--[[for i, s in ipairs(joiningSquads) do
		if not merge_joining then
			squads[#squads + 1] = s
		else
			local targetSquadIdx = table.find(squads, "UniqueId", s.joining_squad)
			-- If a sector filter is applied the squad joining will not be here.
			if targetSquadIdx then
				local targetSquad = squads[targetSquadIdx]
				for ii, m in ipairs(s.units) do
					targetSquad.units[#targetSquad.units + 1] = m
				end
			end
		end
	end]]
	
	table.sort(squads, function (a, b)
		return a.UniqueId < b.UniqueId
	end)
	
	return #squads > 0 and squads or false
end

---
--- Gets the total unit count of a squad, including any squads that are joining it.
---
--- @param squad_id string The ID of the squad to get the unit count for.
--- @return number The total number of units in the squad.
--- @return number The total number of units in the squad, including any joining squads.
---
function GetSquadUnitCountWithJoining(squad_id)
	local squad = gv_Squads[squad_id]
	if not squad then return end
	local unitCount = #squad.units
	local unitCountWithJoining = unitCount

	for i, s in ipairs(g_SquadsArray) do	
		if s.joining_squad == squad_id then
			unitCountWithJoining = unitCountWithJoining + #s.units
		end
	end

	return unitCount, unitCountWithJoining
end

---
--- Gets an array of unit data for the given units.
---
--- @param units table An array of unit IDs.
--- @return table An array of unit data for the given units.
---
function GetMercArrayUnitData(units)
	local curList = {}	
	for i, m in ipairs(units) do
		curList[#curList + 1] = gv_UnitData[m]
	end
	return curList
end

---
--- Checks if a given squad is an enemy squad.
---
--- @param squad_id string The ID of the squad to check.
--- @return boolean True if the squad is an enemy squad, false otherwise.
---
function IsEnemySquad(squad_id)
	local side = gv_Squads[squad_id] and gv_Squads[squad_id].Side
	return side == "enemy1" or side == "enemy2"
end

---
--- Splits a squad's units into smaller groups, each with a maximum of `const.Satellite.MercSquadMaxPeople` units.
---
--- @param squad table The squad to split into smaller groups.
--- @return table An array of smaller groups, each containing up to `const.Satellite.MercSquadMaxPeople` units.
---
function GetSquadMercsSplit(squad)
	local mercs = {}
	local curList = {}
	local units = squad.units
	for i, m in ipairs(units) do
		curList[#curList + 1] = m
		if #curList == const.Satellite.MercSquadMaxPeople then
			mercs[#mercs + 1] = curList
			curList = {}
		end
	end
	if #curList ~= 0 then
		mercs[#mercs + 1] = curList
	end
	
	return mercs
end

---
--- Formats a list of items into a text string, grouping them by their display name and showing the count for each group.
---
--- @param context_obj table An array of items to format.
--- @return string The formatted text string.
---
TFormat.ItemsGroupByTypeText = function(context_obj)
	if not context_obj then return end

	local countTable = {}
	for _, i in ipairs(context_obj) do
		if countTable[i.DisplayName] then
			countTable[i.DisplayName].count = countTable[i.DisplayName].count + 1
		else
			countTable[i.DisplayName] = { template = i, count = 1 }
		end
	end
		
	local textConstruct = T{""}
	for name, c in pairs(countTable) do
		if c.count > 1 then
			name = c.template.DisplayNamePlural
		end
		textConstruct = textConstruct .. T{800603753488, "<left><name><right><count><newline>", name = name, count = c.count}
	end
	
	return textConstruct
end

DefineClass.XZuluScroll = {
	__parents = { "XSleekScroll" },
	properties = {
		{ id = "BGColor", default = GameColors.DarkA, editor = "color" },
	},
	Image = false,
	src_rect = false,
	ThumbScale = point(350, 350)
}

---
--- Calculates the source rectangle for the image used by the XZuluScroll control.
---
--- If the `src_rect` property is not set, this function will measure the size of the image and set the `src_rect` property to a rectangle covering the entire image.
---
--- @return table The source rectangle for the image, in the format `{x, y, width, height}`.
---
function XZuluScroll:CalcSrcRect()
	if not self.src_rect then
		local w, h = UIL.MeasureImage(self.Image)
		self.src_rect = sizebox(0, 0, w, h)
	end
	return self.src_rect
end

---
--- Draws the background of the XZuluScroll control.
---
--- This function sets the background color of the control's content box to the value specified by the `BGColor` property.
---
--- @param self XZuluScroll The XZuluScroll instance.
---
function XZuluScroll:DrawBackground()
	local b = self.content_box
	UIL.DrawSolidRect(b, self.BGColor)
end

DefineClass.XTextLinger = {
	__parents = { "XText" },
	original = false,
	originalBox = false,
	time = false
}

---
--- Creates a new `XTextLinger` instance that is a clone of the provided `XText` instance.
---
--- The new `XTextLinger` instance will have the same text, text style, translation, margins, and padding as the original `XText` instance. The `UseClipBox` and `Clip` properties will be set to `false`, and the `HandleMouse` property will be set to `false`. The original `XText` instance's `content_box` will be stored in the `originalBox` property of the new `XTextLinger` instance.
---
--- @param originalXText XText The `XText` instance to clone.
--- @return XTextLinger The new `XTextLinger` instance.
---
function XTextLinger:Clone(originalXText)
	assert(IsKindOf(originalXText, "XText"))
	self:SetTranslate(originalXText.Translate)
	self:SetTextStyle(originalXText.TextStyle)
	self:SetText(originalXText.Text)
	self.original = originalXText
	
	self.UseClipBox = false
	self.Clip = false
	
	self:SetMargins(originalXText.Margins)
	self:SetPadding(originalXText.Padding)
	self:SetHandleMouse(false)

	self.originalBox = originalXText.content_box
	self:Invalidate()
end

---
--- Causes the `XTextLinger` instance to linger on the screen for a specified duration, fading out over a given time.
---
--- @param time number The duration in milliseconds that the `XTextLinger` instance should remain on the screen.
--- @param fadeOut number The duration in milliseconds over which the `XTextLinger` instance should fade out.
---
function XTextLinger:LingerFor(time, fadeOut)
	self.time = time
	self:AddInterpolation{
		id = "fade",
		type = const.intAlpha,
		startValue = 255,
		endValue = 0,
		duration = fadeOut,
		visible = true,
		start = GetPreciseTicks() + time,
		on_complete = function(self, int)
			if self.window_state == "destroying" then return end
			self:delete()
		end,
	}
end

---
--- Sets the content and bounding box of the `XTextLinger` instance to the original `XText` instance's content box.
---
--- This method is used to restore the original content box of the `XTextLinger` instance, which may have been modified during the cloning process.
---
--- @param self XTextLinger The `XTextLinger` instance to set the box for.
---
function XTextLinger:SetBox(...)
	if not self.originalBox then return end
	self.content_box = self.originalBox
	self.box = self.originalBox
end

---
--- Takes a subset of elements from a table.
---
--- @param table table The table to take elements from.
--- @param number number The number of elements to take from the beginning of the table.
--- @return table A new table containing the first `number` elements of the input table.
---
function TableTake(table, number)
	if #table <= number then return table end
	local subTable = {}
	for i=1, number do
		subTable[i] = table[i]
	end
	return subTable
end

DefineClass.XContextImage = {
	__parents = { "XImage", "XContextWindow" }
}

DefineClass.XContextFrame = {
	__parents = { "XFrame", "XContextWindow" }
}

DefineClass.StatusEffectIcon = {
	__parents = { "XContextImage" },
	HandleMouse = true,
	UseClipBox = false,
	RolloverTemplate = "RolloverGeneric",
	RolloverText = T(304252861693, "<Description>"),
	RolloverTitle = T(733545694003, "<DisplayName>"),
	ImageScale = point(750, 750),
	IdNode = true
}

---
--- Opens the `StatusEffectIcon` instance, setting the image to the `Icon` property of the `context` if it exists, and then calling the `Open` method of the `XContextWindow` class.
---
--- @param self StatusEffectIcon The `StatusEffectIcon` instance to open.
---
function StatusEffectIcon:Open()
	if self.context and self.context.Icon then self:SetImage(self.context.Icon) end
	XContextWindow.Open(self)
end

---
--- Checks if any attack interrupts are available for the given unit, target, and action.
---
--- @param unit Unit The unit performing the action.
--- @param target Unit The target of the action.
--- @param action table The action being performed.
--- @param target_dummy table The target dummy for the action.
--- @return boolean True if any attack interrupts are available, false otherwise.
---
function AnyAttackInterrupt(unit, target, action, target_dummy)
	if action and (action.id == "CancelShot" or action.id == "CancelShotCone") or not target then return false end
	
	if not unit:CallReactions_And("OnCheckInterruptAttackAvailable", target, action) then
		return false
	end
	
	-- Pindown type interrupt
	local target_dummies = { target_dummy or unit.target_dummy or unit }
	local any = unit:CheckProvokeOpportunityAttacks(action, "attack interrupt", target_dummies, true, "any")
	if any then
		return true
	end
	-- Overwatch type interrupt
	any = unit:CheckProvokeOpportunityAttacks(action, "attack reaction", target_dummies, true, "any")
	if any then
		return true
	end
	return false
end

---
--- Checks if there are any interrupts along the given path for the specified unit and action.
---
--- @param unit Unit The unit performing the action.
--- @param path table A table of positions representing the path.
--- @param allInterrupts boolean If true, checks for all interrupts, otherwise only checks for any interrupt.
--- @param action table The action being performed.
--- @return boolean|table True if there are any interrupts, false otherwise. If allInterrupts is true, returns a table of all interrupts.
---
function AnyInterruptsAlongPath(unit, path, allInterrupts, action)
	local gotoDummies = unit:GenerateTargetDummiesFromPath(path)
	
	local mask = unit:GetItemInSlot("Head", "GasMaskBase")
	local check_gas = (not mask or mask.Condition <= 0) and (next(g_SmokeObjs) ~= nil)
	local check_fire = next(g_Fire) ~= nil
	
	if check_gas or check_fire then
		local voxels = {}

		for i, dummy in ipairs(gotoDummies) do
			local _, headVoxel = unit:GetVisualVoxels(dummy.pos, dummy.stance, voxels)
			local smoke = g_SmokeObjs[headVoxel]
			if smoke and smoke:GetGasType() ~= "smoke" then
				if unit:GetDist(dummy.pos) < const.SlabSizeX / 2 then
					-- target dummies come in order of distance from the start, if we're already inside the gas there's no need to give off warnings
					break
				end
				return true
			end
			if 	AreVoxelsInFireRange(voxels) then
				if unit:GetDist(dummy.pos) < const.SlabSizeX / 2 then
					-- target dummies come in order of distance from the start, if we're already inside the gas there's no need to give off warnings
					break
				end
				return true
			end
		end
	end
	
	local interrupts = unit:CheckProvokeOpportunityAttacks(action or CombatActions.Move, "move", gotoDummies, true, allInterrupts and "all" or "any")
	if interrupts then
		return interrupts
	end
	return false
end

---
--- Checks if the given object is a mercenary unit.
---
--- @param o Unit|UnitData|UnitDataCompositeDef The object to check.
--- @return boolean True if the object is a mercenary unit, false otherwise.
---
function IsMerc(o)
	local id
	if IsKindOf(o, "Unit") then
		id = o.unitdatadef_id
	elseif IsKindOf(o, "UnitData") then
		id = o.class
	elseif IsKindOf(o, "UnitDataCompositeDef") then
		return o.IsMercenary
	end
	return id and UnitDataDefs[id].IsMercenary
end

---
--- Moves the camera to view the given object or position.
---
--- @param obj Unit|Object The object to view, or nil to view the given position.
--- @param pos Vector The position to view, if obj is nil.
---
function VME_ViewPos_Game(obj, pos)
	if IsValid(obj) then
		if IsKindOf(obj, "Unit") then
			ViewAndSelectObject(obj)
		else
			ViewObject(obj)
		end
	else
		ViewPos(pos)
	end
end

---
--- Gets the current UI target.
---
--- @return Unit|nil The current UI target, or nil if there is no valid target.
---
function GetCurrentUITarget()
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and IsKindOf(dlg, "IModeCombatAttackBase") and dlg.window_state ~= "destroying" then return dlg.target end
end

---
--- Gets the difference in height between two positions.
---
--- @param pos Vector The starting position.
--- @param d Vector The ending position.
--- @return number The absolute difference in height between the two positions.
---
function GetZDifference(pos, d)
	if not pos:IsValidZ() and not d:IsValidZ() then return 0 end
	local start_z = pos:z() or terrain.GetHeight(pos)
	local z = d:z() or terrain.GetHeight(d)
	local z_diff = abs(start_z - z)
	return z_diff
end

---
--- Places a shrinking object at the given position.
---
--- @param class string The class of the object to place.
--- @param time number The duration in milliseconds for the object to shrink.
--- @param pos Vector The position to place the object.
--- @param scale number The initial scale of the object, defaults to 100.
--- @param color ColorModifier The color modifier to apply to the object.
--- @param fx string The name of the FX to play when the object is placed.
---
--- @return Object The placed object.
---
function PlaceShrinkingObj(class, time, pos, scale, color, fx)
	local obj = PlaceObject(class)
	obj:SetPos(pos)
	obj:SetScale(scale or 100)
	if color then
		obj:SetColorModifier(color)
	end
	PlayFX(fx or "MoveCommand", "start", "Unit", false, pos)
	CreateGameTimeThread(function(o, time)
		local time_delta = 20
		local scale = obj:GetScale()
		local scale_delta = MulDivRound(time_delta, scale, time)
		while scale > 0 do
			Sleep(time_delta)
			scale = scale - scale_delta
			o:SetScale(scale > 0 and scale or 0)
		end
		DoneObject(o)
	end, obj, time)
end

---
--- Runs the given function when the specified window's layout is ready.
---
--- @param wnd table The window object.
--- @param func function The function to run when the window's layout is ready.
--- @param ... any Additional arguments to pass to the function.
---
function RunWhenXWindowIsReady(wnd, func, ...)
	if not wnd.layout_update then
		func(...)
	else
		local params = {...}
		local oldComplete = wnd.OnLayoutComplete
		wnd.OnLayoutComplete = function()
			wnd.OnLayoutComplete = oldComplete
			func(table.unpack(params))
			wnd:OnLayoutComplete()
		end
	end
end

--- Returns a formatted string representing the squad name.
---
--- @param context_obj table The context object containing the squad information.
--- @return string The formatted squad name.
TFormat.SquadName = function (context_obj)
	if not context_obj then return end
	if context_obj.militia then
		return T(121560205347, "MILITIA")
	end
	return T{788441578526, "<u(Name)>", context_obj}
end

---
--- Returns a formatted string representing the squad name with the appropriate color tag.
---
--- @param context_obj table The context object containing the squad information.
--- @return string The formatted squad name with color tag.
---
TFormat.SquadNameColored = function (context_obj)
	if not context_obj then return end
	local _, colorTag = GetSectorControlColor(context_obj.Side)
	if context_obj.militia then
		return T{481087267106, "<controlColor>MILITIA</color>", controlColor = colorTag}
	end
	return T{492224151656, "<controlColor><u(Name)></color>", Name = context_obj.Name, controlColor = colorTag}
end

if Platform.developer then
---
--- Draws a debug box representing the voxel bounding box for the given position and voxel range.
---
--- @param pos table The position to draw the voxel bounding box for.
--- @param voxel_range number The voxel range to use when calculating the bounding box.
---
function DebugDrawVoxelBBox(pos, voxel_range)
	local b = GetVoxelBBox(pos, voxel_range)
	local minx, miny = b:minxyz()
	local maxx, maxy = b:maxxyz()
	DbgAddBox(b, const.clrRed)
	DbgAddVector(point(minx, miny))
	DbgAddVector(point(minx, maxy))
	DbgAddVector(point(maxx, miny))
	DbgAddVector(point(maxx, maxy))
end
end

---
--- Returns the voxel bounding box for the given position and voxel range.
---
--- @param pos table The position to calculate the voxel bounding box for.
--- @param voxel_range number The voxel range to use when calculating the bounding box.
--- @param withZ boolean (optional) Whether to include the Z-axis in the bounding box.
--- @param dontSnap boolean (optional) Whether to snap the position to the nearest voxel.
--- @return table The voxel bounding box.
function GetVoxelBBox(pos, voxel_range, withZ, dontSnap)
	local x, y
	if dontSnap then
		x, y = pos:xy()
	else
		x, y = SnapToVoxel(pos:xyz())
	end
	local grow = (2 * (voxel_range or 0) + 1) * const.SlabSizeX / 2
	
	if withZ and pos:IsValidZ() then
		return box(x - grow, y - grow, pos:z() - grow, x + grow, y + grow, pos:z() + grow)
	else
		return box(x - grow, y - grow, x + grow, y + grow)
	end
end

---
--- Concatenates a list of items into a string, separating them with commas and using "and" for the last two items.
---
--- @param list table A list of items to concatenate.
--- @return string The concatenated string.
function ConcatListWithAnd(list)
	local output = T{""}
	for i, item in ipairs(list) do
		if i == #list then
			output = output .. item
		elseif i == #list - 1 then
			if #list > 2 then
				output = output .. item .. T(289661130557, ", and ")
			else
				output = output .. item .. T(103700051305, " and ")
			end
		else
			output = output .. item .. T(642697486575, ", ")
		end
	end
	return output
end

---
--- Calculates the maximum distance between any two player units.
---
--- @return number The maximum distance between any two player units.
function GetPlayerUnitsMaxDist()
	local max_dist = 0
	for i, team in ipairs(g_Teams) do
		if team.side == "player1" then
			for _, unit1 in ipairs(team.units) do
				for _, unit2 in ipairs(team.units) do
					if unit1 ~= unit2 then
						max_dist = Max(max_dist, unit1:GetDist2D(unit2))
					end
				end
			end
		end
	end
	return max_dist
end

DefineClass.XPopupSnapToWidth = {
	__parents = { "XPopup" },
	width_wnd = false
}

---
--- Sets the box dimensions of the XPopupSnapToWidth object, ensuring the popup does not exceed the bounds of its parent window.
---
--- @param x number The x-coordinate of the popup.
--- @param y number The y-coordinate of the popup.
--- @param width number The width of the popup.
--- @param height number The height of the popup.
function XPopupSnapToWidth:SetBox(x, y, width, height)
	if self.width_wnd then
		local b = self.width_wnd.content_box
		if x < b:minx() then
			x = b:minx()
		end
		if x + width > b:maxx() then
			x = b:maxx() - width
		end
	end
	XPopup.SetBox(self, x, y, width, height)
end

---
--- Gets the first unit in the voxel at the specified position.
---
--- @param pos table|nil The position to check. If not provided, the cursor position is used.
--- @return Unit|nil The first unit in the voxel, or nil if no unit is found.
function GetUnitInVoxel(pos)
	local cursorPos = pos or GetCursorPos()

	return MapGetFirst(GetVoxelBBox(cursorPos), "Unit", function (o, cursorZ)
		if not o:IsDead() then 
			if not o.visible then return end
			local x, y, z = o:GetPosXYZ()
			return (not z and not cursorZ) or z == cursorZ
		end
	end, cursorPos:z())
end

---
--- Invokes a shortcut action on the specified host object.
---
--- @param self table The object invoking the shortcut action.
--- @param actionName string The name of the action to invoke.
--- @param host table|nil The host object for the action. If not provided, `XShortcutsTarget` is used.
--- @param checkState boolean|nil If true, the function will check the action state and only invoke the action if it is "enabled".
--- @return boolean|string True if the action was invoked successfully, or an error message if the action could not be invoked.
function InvokeShortcutAction(self, actionName, host, checkState)
	host = host or XShortcutsTarget
	if not host then return end
	local action = host:ActionById(actionName)
	if not action then return end
		
	if checkState then
		local state, err = action:ActionState(host)
		if state and state ~= "enabled" then return err end
	end

	host:OnAction(action, self)
end

---
--- Gets the action state for the specified shortcut action.
---
--- @param actionName string The name of the action to check.
--- @param host table|nil The host object for the action. If not provided, `XShortcutsTarget` is used.
--- @return string|nil The state of the action, or `nil` if the action could not be found.
function GetShortcutActionState(actionName, host)
	host = host or XShortcutsTarget
	if not host then return end
	local action = host:ActionById(actionName)
	if not action then return end
	
	return action:ActionState(host)
end

---
--- Gets the time remaining until the next guardpost spawn in the given sector.
---
--- @param sector table The sector object.
--- @return number|nil The time remaining until the next guardpost spawn, or `nil` if there is no guardpost or the spawn time is not available.
function GetSectorTimer(sector)
	local gp = sector.Guardpost and sector.guardpost_obj
	if gp then
		local time = gp and gp.next_spawn_time and gp.next_spawn_time - Game.CampaignTime
		return time and time > 0 and time < const.Satellite.GuardPostShowTimer and time
	
	else
		-- this counter may be used for debug purposes at some point
		--[[local _, enemy_squads = GetSquadsInSector(sector.Id, "excludeTravelling")
		for _, squad in ipairs(enemy_squads) do
			if squad.wait_in_sector then
				return Max(squad.wait_in_sector - Game.CampaignTime, 0)
			end
		end]]
	end
end

-- function TFormat.ShortcutButton(ctx, actionName, altShortcut)
-- function TFormat.ShortcutButton(ctx, keyboardShortcut, gamepadShortcut)
---
--- Formats a shortcut button for display.
---
--- @param ctx table The context object.
--- @param arg1 string|table The action name or a table containing the keyboard and gamepad shortcuts.
--- @param arg2 string The gamepad shortcut.
--- @return string The formatted shortcut button, or an empty string if no shortcut is available.
function TFormat.ShortcutButton(ctx, arg1, arg2)
	if not arg1 then return false end
	if arg2 and type(arg1) == "string" and type(arg2) == "string" then arg1 = { arg1, arg2 } end
	return GetShortcutButtonT(arg1) or ""
end

---
--- Formats a gamepad shortcut name for display.
---
--- @param context_obj table The context object.
--- @param shortcut string The gamepad shortcut.
--- @return string The formatted gamepad shortcut name, or "<negative>Unassigned</negative>" if no shortcut is available.
function TFormat.GamepadShortcutName(context_obj, shortcut)
	if not shortcut or shortcut == "" then
		return T(879415238341, "<negative>Unassigned</negative>")
	end
	local buttons = SplitShortcut(shortcut)
	for i, button in ipairs(buttons) do
		if GetAccountStorageOptionValue("GamepadSwapTriggers") then
			if button == "LeftTrigger" then
				button = "RightTrigger"
			elseif button == "RightTrigger" then
				button = "LeftTrigger"
			end
		end
	
		buttons[i] = const.TagLookupTable[button] or GetPlatformSpecificImageTag(button) or "?"
	end
	return Untranslated(table.concat(buttons))
end

local lDisplayKeyOverrides = {
	["Escape"] = T(939588806542, "ESC"),
	["Enter"] =  T(122085236350, "ENT"),
	["Insert"] = T(442527171248, "INS")
}
 
---
--- Formats a shortcut button for display.
---
--- @param action string|table The action name or a table containing the keyboard and gamepad shortcuts.
--- @return string The formatted shortcut button, or an empty string if no shortcut is available.
function GetShortcutButtonT(action)
	local shortcut1 = false
	local shortcutGamepad = false
	if type(action) == "string" then
		local shortcuts = GetShortcuts(action)
		if not shortcuts then return false end
		shortcut1 = shortcuts[1]
		shortcutGamepad = shortcuts[3]
	elseif IsKindOf(action, "XAction") then
		shortcut1 = action.ActionShortcut
		shortcutGamepad = action.ActionGamepad
	elseif type(action) == "table" then
		shortcut1 = action[1]
		shortcutGamepad = action[2]
	end
	
	if GetUIStyleGamepad() then
		if #(shortcutGamepad or "") == 0 then return false end
		
		local buttons = SplitShortcut(shortcutGamepad)
		for i, button in ipairs(buttons) do
			if GetAccountStorageOptionValue("GamepadSwapTriggers") then
				if button == "LeftTrigger" then
					button = "RightTrigger"
				elseif button == "RightTrigger" then
					button = "LeftTrigger"
				end
			end
			buttons[i] = button
		end
		
		for i, button in ipairs(buttons) do
			button = const.ShortenedButtonNames[button] or button
			buttons[i] = TLookupTag("<"..button..">") or "?"
		end
		
		return Untranslated(table.concat(buttons))
	else
		if #(shortcut1 or "") == 0 then return false end
		local buttons = SplitShortcut(shortcut1)
		for i, button in ipairs(buttons) do
			buttons[i] = lDisplayKeyOverrides[button] or KeyNames[VKStrNamesInverse[button]] or Untranslated(button)
		end	
		return T{116208420630, "<key>", key = table.concat(buttons, "-")}
	end
end

---
--- Formats a boolean value as a string.
---
--- @param context_obj any The context object (unused).
--- @param val boolean The boolean value to format.
--- @return string The formatted boolean value as a string.
function TFormat.Bool(context_obj, val)
	return Untranslated(tostring(not not val))
end

if FirstLoad then
	g_ZuluMessagePopup = false
	NewGameObj = false
	NewGameObjOriginal = {difficulty = "Normal", game_rules = {}, settings = { HintsEnabled = true }, campaign_name = "", campaignId = "HotDiamonds"}
	
	MouseButtonImagesInText = {
		-- Add zulu specific images
		["MouseL"] = "UI/Icons/left_click.tga",
		["MouseR"] = "UI/Icons/right_click.tga",
		["MouseM"] = "UI/Icons/middle_click.tga",
		["MouseX1"] = "UI/Icons/button_3.tga",
		["MouseX1"] = "UI/Icons/button_4.tga",
		["MouseX2"] = "UI/Icons/button_5.tga",
		["MouseWheelFwd"] = "UI/Icons/scroll_up.tga",
		["MouseWheelBack"] = "UI/Icons/scroll_down.tga",
	}
end

AppendClass.GameRuleDef = {	
	properties = {
		{ id = "advanced", name = "Advanced", category = "General",help = "Advanced game rule", editor = "bool", default = false}
	}
}

function OnMsg.DataLoaded()
	ForEachPreset("GameRuleDef", function(rule)
		if rule.init_as_active then
			NewGameObjOriginal.game_rules[rule.id] = true
		end
	end)	
end

-- This modal steals mouse focus only when appropriate.
-- Project ZOrder Legend (Things that are spawned in desktop only)
-- 0: Tactical Notifications when PDA is open
-- 99: InGameMenu
-- 99: SetpieceDlg
-- 100: Tactical Notifications during setpiece
-- 100: Floor Display
-- 1000: ZuluMessageDialog
-- 1000000000: Loading Screen

DefineClass.ZuluModalDialog = {
	__parents = { "XDialog" },
	properties = {
		{ id = "GamepadVirtualCursor", editor = "bool", default = false }
	},
	
	HandleMouse = true,
}

--- Opens a ZuluModalDialog and manages its state.
---
--- This function is responsible for:
--- - Locking the camera when the dialog is opened
--- - Adding the dialog to the global g_ZuluMessagePopup table
--- - Setting the GamepadVirtualCursor property on the dialog
--- - Disabling/enabling the mouse via gamepad based on the GamepadVirtualCursor property
--- - Calling the base XDialog:Open() function to actually open the dialog
--- - Sending a "ZuluMessagePopup" message when the dialog is opened
---
--- @param self ZuluModalDialog The dialog instance being opened
--- @param ... Any additional arguments to pass to the base XDialog:Open() function
function ZuluModalDialog:Open(...)
	LockCamera(self)
	
	if not g_ZuluMessagePopup then g_ZuluMessagePopup = {} end
	g_ZuluMessagePopup[#g_ZuluMessagePopup + 1] = self
	
	SetEnabledMouseViaGamepad(self.GamepadVirtualCursor, self)
	SetDisableMouseViaGamepad(not self.GamepadVirtualCursor, self)
	
	XDialog.Open(self, ...)
	Msg("ZuluMessagePopup", "open")
end

---
--- Closes a ZuluModalDialog and manages its state.
---
--- This function is responsible for:
--- - Unlocking the camera when the dialog is closed
--- - Removing the dialog from the global g_ZuluMessagePopup table
--- - Disabling/enabling the mouse via gamepad based on the GamepadVirtualCursor property
--- - Calling the base XDialog:Done() function to actually close the dialog
--- - Sending a "ZuluMessagePopup" message when the dialog is closed
---
--- @param self ZuluModalDialog The dialog instance being closed
--- @param ... Any additional arguments to pass to the base XDialog:Done() function
function ZuluModalDialog:Done(...)
	UnlockCamera(self)
	XDialog.Done(self, ...)
	
	if g_ZuluMessagePopup then
		table.remove_value(g_ZuluMessagePopup, self)
		if not next(g_ZuluMessagePopup) then g_ZuluMessagePopup = false end
	end
	Msg("ZuluMessagePopup", "close")

	SetEnabledMouseViaGamepad(false, self)
	SetDisableMouseViaGamepad(false, self)
end

function OnMsg.ZuluMessagePopup()
	ObjModified("layerButton")
	ObjModified("pda_tab")
end

---
--- Checks if the ZuluModalDialog is currently visible and not in the process of being destroyed.
---
--- @param self ZuluModalDialog The dialog instance to check.
--- @param pt table A table containing the x and y coordinates of a point.
--- @return boolean True if the dialog is visible and not being destroyed, false otherwise.
---
function ZuluModalDialog:MouseInWindow(pt)
	return self:IsVisible() and self.window_state ~= "destroying"
end

---
--- Handles the mouse position event for the ZuluModalDialog.
---
--- This function is called when the mouse position changes within the dialog. It
--- simply forwards the event to the base XDialog:OnMousePos() function and
--- returns "break" to indicate that the event has been handled.
---
--- @param self ZuluModalDialog The dialog instance.
--- @param ... Any additional arguments passed to the base function.
--- @return string "break" to indicate the event has been handled.
---
function ZuluModalDialog:OnMousePos(...)
	XDialog.OnMousePos(self, ...)
	return "break"
end

---
--- Handles the mouse button down event for the ZuluModalDialog.
---
--- This function is called when a mouse button is pressed within the dialog. It
--- forwards the event to the base XDialog:OnMouseButtonDown() function and
--- returns "break" to indicate that the event has been handled.
---
--- @param self ZuluModalDialog The dialog instance.
--- @param pt table A table containing the x and y coordinates of the mouse pointer.
--- @param button string The name of the mouse button that was pressed ("L", "M", or "R").
--- @return string "break" to indicate the event has been handled.
---
function ZuluModalDialog:OnMouseButtonDown(pt, button)
	XDialog.OnMouseButtonDown(self, pt, button)
	if RolloverWin and button == "M" then return end -- More info
	return "break"
end

---
--- Handles the mouse button up event for the ZuluModalDialog.
---
--- This function is called when a mouse button is released within the dialog. It
--- forwards the event to the base XDialog:OnMouseButtonUp() function and
--- returns "break" to indicate that the event has been handled.
---
--- @param self ZuluModalDialog The dialog instance.
--- @param pt table A table containing the x and y coordinates of the mouse pointer.
--- @param button string The name of the mouse button that was released ("L", "M", or "R").
--- @return string "break" to indicate the event has been handled.
---
function ZuluModalDialog:OnMouseButtonUp(pt, button)
	XDialog.OnMouseButtonUp(self, pt, button)
	if RolloverWin and button == "M" then return end
	return "break"
end

---
--- Handles keyboard shortcuts for the ZuluModalDialog.
---
--- This function is called when a keyboard shortcut is triggered within the dialog. It
--- first checks if the shortcut starts with a '+' character, which indicates a modifier
--- key. If so, it returns without further processing.
---
--- Next, it calls the base XDialog:OnShortcut() function to handle the shortcut. If
--- that function returns "break", this function also returns "break" to indicate the
--- event has been handled.
---
--- If the shortcut corresponds to an action with an ID starting with "DE_" or equal to
--- "idBugReport", it calls the XShortcutsTarget:OnShortcut() function to handle the
--- action.
---
--- Finally, if the shortcut corresponds to the "rolloverMoreInfo" action, this function
--- returns without further processing.
---
--- @param self ZuluModalDialog The dialog instance.
--- @param shortcut string The name of the keyboard shortcut that was triggered.
--- @param ... Any additional arguments passed to the base function.
--- @return string "break" to indicate the event has been handled.
---
function ZuluModalDialog:OnShortcut(shortcut, ...)
	if string.sub(shortcut, 1, 1) == "+" then return end 

	local result = XDialog.OnShortcut(self, shortcut, ...)
	if result == "break" then return result end
	
	local action = XShortcutsTarget:ActionByShortcut(shortcut, ...)
	if action and action.ActionId and (action.ActionId:sub(1, 3) == "DE_" or action.ActionId=="idBugReport") then
		XShortcutsTarget:OnShortcut(shortcut, ...)
	end

	-- Special exception :P
	if action and action.ActionId == "rolloverMoreInfo" then
		return
	end
	
	return "break"
end

---
--- Called when the ZuluModalDialog loses focus.
--- Refreshes the popup focus after a short delay.
---
function ZuluModalDialog:OnSetFocus()
	DelayedCall(0, RefreshPopupFocus)
end

---
--- Called when the ZuluModalDialog loses focus.
--- Refreshes the popup focus after a short delay.
---
function ZuluModalDialog:OnKillFocus()
	DelayedCall(0, RefreshPopupFocus)
end

---
--- Sets the visibility of the ZuluModalDialog instance and refreshes the popup focus after a short delay.
---
--- @param self ZuluModalDialog The dialog instance.
--- @param ... Any additional arguments passed to the base function.
---
function ZuluModalDialog:SetVisibleInstant(...)
	XDialog.SetVisibleInstant(self, ...)
	DelayedCall(0, RefreshPopupFocus)
end

---
--- Refreshes the popup focus after a short delay.
---
--- This function is responsible for ensuring that the topmost popup in the `g_ZuluMessagePopup` table has focus. It first finds the topmost popup that is within the desktop, then sets the focus to that popup if the current focus is not already within that popup.
---
--- @param desktop table The desktop object.
--- @param g_ZuluMessagePopup table A table of popup objects.
---
function RefreshPopupFocus()
	if #(g_ZuluMessagePopup or empty_table) == 0 then return end
	
	local desktop = terminal.desktop
	local top, topZ = false, 0
	for i, popup in ipairs(g_ZuluMessagePopup) do
		if desktop and
		  popup:IsWithin(desktop) and
		  (not top or popup.ZOrder > topZ or popup.ZOrder == topZ) then
			top = popup
			topZ = popup.ZOrder
		end
	end

	local currentFocus = desktop.keyboard_focus
	if top and (not currentFocus or not currentFocus:IsWithin(top)) then
		top:SetFocus()
	end
end

---
--- Returns a list of environment effects for the specified sector.
---
--- If the sector is underground, the function returns a list containing the `Underground` environment effect.
---
--- If a sector ID is provided, the function returns a list containing the weather and time of day environment effects for that sector.
---
--- If no sector ID is provided, the function returns a list of all environment effects that are currently active in the game state.
---
--- @param sectorId string|nil The ID of the sector to get environment effects for. If not provided, the current sector ID is used.
--- @return table A list of environment effect presets.
---
function GetEnvironmentEffects(sectorId)
	if IsSectorUnderground(sectorId or gv_CurrentSectorId) then
		return { GameStateDefs.Underground }
	end
	
	if sectorId then
		local weather = GetCurrentSectorWeather(sectorId) or "ClearSky"
		local weatherPreset = GameStateDefs[weather]
		
		local tod = (Game and Game.Campaign and Game.CampaignTime) and CalculateTimeOfDay(Game.CampaignTime) or "Day"
		local todPreset = GameStateDefs[tod]
		
		return { weatherPreset, todPreset }
	end

	local effects = {}
	return ForEachPreset("GameStateDef", function(preset, group, effects)
		if #effects < 2 and GameState[preset.id] and preset.Icon and not table.find(effects, preset) then
			effects[#effects + 1] = preset
		end
	end, effects)
end

---
--- Formats the environment effects for the current game state as a string of hyperlinked display names.
---
--- @return string A formatted string of environment effect display names.
---
function TFormat.EnvironmentEffects()
	local effects = GetEnvironmentEffects()
	local str = false
	for i, ef in ipairs(effects) do
		local hLink = "<hyperlink " .. ef.id .. ">" .. _InternalTranslate(ef:GetDisplayName()) .. "</hyperlink>"
		if str then
			str = str .. " / " .. hLink
		else
			str = hLink
		end
	end
	return Untranslated(str)
end

---
--- Counts the number of player-owned Points of Interest (POIs) in the game.
---
--- @param ctx table The context object, which may contain additional information about the POIs.
--- @param poiName string The name of the POI to count.
--- @return number The number of player-owned POIs with the given name.
---
function TFormat.OwnedPOI(ctx, poiName)
	local count = 0
	for i, s in pairs(gv_Sectors) do
		if s[poiName] and s.Side == "player1" then
			count = count + 1
		end
	end
	return count
end

-- temp, but possibly not
SyncCheck_NetSyncEventDispatch = return_true
SyncCheck_InGameInterfaceMode = return_true

---
--- Determines whether the hash log should be reset on a map change.
---
--- @return boolean Always returns false, indicating that the hash log should not be reset on a map change.
---
function ShouldResetHashLogOnMapChange()
	return false
end

---
--- Formats the mercenary's nationality flag image for display.
---
--- @param context_obj table The context object, which may contain information about the mercenary's nationality.
--- @return string The HTML image tag for the mercenary's nationality flag, or an empty string if the nationality is not found.
---
function TFormat.MercFlagImage(context_obj)
	if not context_obj or not context_obj.Nationality then return "" end
	local nationalityPreset = Presets.MercNationalities.Default[context_obj.Nationality]
	if nationalityPreset.Icon then
		return Untranslated("<image " .. nationalityPreset.Icon .. ">")
	end
	return ""
end

---
--- Calculates a percentage of a given stat value.
---
--- @param context_obj table The context object that contains the stat value.
--- @param stat string The name of the stat to retrieve.
--- @param percent number The percentage to calculate.
--- @return number The calculated percentage of the stat value.
---
function TFormat.StatPercent(context_obj, stat, percent)
	local statAmount = ResolveValue(context_obj, stat)
	if not statAmount then statAmount = ResolveValue(context_obj, "unit", stat) end
	if not statAmount then return end
	
	local result = MulDivRound(statAmount, percent, 100)
	return result
end

-- Expected an array of arrays in which the first element is the weight and the second is the item.
---
--- Selects a random item from a weighted list.
---
--- @param weights table An array of arrays, where the first element is the weight and the second element is the item.
--- @param seed number (optional) A seed value for the random number generator.
--- @return any The randomly selected item from the weighted list.
---
function GetWeightedRandom(weights, seed)
	local totalPool = 0
	for i, weight in ipairs(weights) do
		totalPool = totalPool + weight[1]
	end

	local rand = BraidRandom(seed or AsyncRand(), totalPool) + 1
	
	for i, weight in ipairs(weights) do
		rand = rand - weight[1]
		if rand <= 0 then
			return weight[2]
		end
	end
end

DefineClass.UnitFloatingText = {
	__parents = { "XFloatingText" },
	interpolate_opacity = true,
	default_spot = "Headstatic",
	
	pushUpExtra = 20,
}

---
--- Offsets the box of a UnitFloatingText object based on the context object and other game state.
---
--- @param x number The x-coordinate of the box.
--- @param y number The y-coordinate of the box.
--- @return number, number The adjusted x and y coordinates of the box.
---
function UnitFloatingText:OffsetBox(x, y)
	if not self.context then return x, y end
	
	local extraPush = self.pushUpExtra
	local minPushUp = extraPush
	if not IsKindOf(self.context, "Unit") then
		minPushUp = 80
	end
	
	if IsSetpiecePlaying() then
		return x, y - extraPush
	end
	
	local igi = GetInGameInterfaceModeDlg()
	if igi and IsKindOf(igi, "IModeCombatAttackBase") and igi.crosshair and igi.crosshair.context and igi.crosshair.context.target == self.context then
		return x, y - igi.crosshair.box:sizey() / 2
	end
	
	local unitBadges = g_Badges[self.context]
	if not unitBadges then return x, y end
	
	-- Find the badge with the highest Y (lowest since Y axis is negative up)
	local highestY = false
	for i, b in ipairs(unitBadges) do
		if b and b.ui and b.ui.visible then
			local badgeUI = b.ui
			
			-- Wait layout
			while badgeUI.box == empty_box do
				Sleep(1)
			end
			
			local badgeMin = badgeUI.box:miny()
			if not highestY then
				highestY = badgeMin
			else
				highestY = Min(badgeMin, highestY)
			end
		end
	end
	if not highestY then highestY = 0 end

	local push = highestY - minPushUp
	return x, y + push
end

--- Recalculates the bounding box for the floating text.
---
--- This function calculates the width, height, and position of the floating text box based on the text content, margins, and scaling. It then sets the box dimensions using the `SetBox` method.
---
--- @param self UnitFloatingText The instance of the `UnitFloatingText` class.
--- @return nil
function UnitFloatingText:RecalculateBox()
	local width, height = self:Measure(self.MaxWidth, self.MaxHeight)
	local minx, miny, maxx, maxy = self:GetEffectiveMargins()
	local xLoc = -(width / 2) + minx
	local yLoc = -height + miny
	
	height = height + -yLoc
	xLoc, yLoc = self:OffsetBox(xLoc, yLoc)
	
	local x1, y1, x2, y2 = ScaleXY(self.scale, self.Padding:xyxy())
	self:SetBox(xLoc - x1, yLoc - y1, width + maxx + x1 + x2, height + maxy + y1 + y2, false)
end

DefineClass.CantAttackFloatingText = {
	__parents = { "XFloatingText" },
	TextStyle = "FloatingTextError",
	exclusive = true,
	stagger_spawn = false,
	exclusive_discard = true
}

--- Checks if an attack action is impossible for the given unit.
---
--- This function checks if the given unit can perform the specified attack action. It first checks if the unit has a combat action in progress and if the action is interruptable. It then retrieves the UI state and attack weapons for the action, and checks if the unit can attack the target using the `CanAttack` method. If the action is enabled, the function returns the attack status and the reason if the attack is not possible. Otherwise, it returns the UI state and the error message.
---
--- @param unit table The unit performing the attack action.
--- @param action table The attack action to be performed.
--- @param args table Optional arguments for the attack action.
--- @return string The attack status, either "enabled" or "disabled".
--- @return string The reason why the attack is not possible, if applicable.
function CheckImpossibleAttack(unit, action, args)
	if HasCombatActionInProgress(unit) and not unit.interruptable then 
		return false 
	end
	
	args = args or {}
	local state, err = action:GetUIState({unit}, args)

	local weapon = action:GetAttackWeapons(unit)
	local canAttack, reason = unit:CanAttack(
		args.target,
		weapon, action,
		args and args.aim,
		args and args.goto_pos,
		nil,
		args.free_aim
	)
	reason = reason or not canAttack and T(138935217566, "Action not possible")
	
	if state == "enabled" then
		return canAttack and "enabled" or "disabled", reason
	end
	
	return state, err
end

--- Checks if an attack action is impossible for the given unit and reports the error if it is.
---
--- This function checks if the given unit can perform the specified attack action. It first checks if the unit has a combat action in progress and if the action is interruptable. It then retrieves the UI state and attack weapons for the action, and checks if the unit can attack the target using the `CanAttack` method. If the action is enabled, the function returns the attack status and the reason if the attack is not possible. Otherwise, it reports the error and returns the UI state and the error message.
---
--- @param unit table The unit performing the attack action.
--- @param action table The attack action to be performed.
--- @param args table Optional arguments for the attack action.
--- @return string The attack status, either "enabled" or "disabled".
--- @return string The reason why the attack is not possible, if applicable.
function CheckAndReportImpossibleAttack(unit, action, args)
	if HasCombatActionInProgress(unit) and not unit.interruptable then 
		return false 
	end
	
	args = args or empty_table
	local state, err = action:GetUIState({unit}, args)

	local weapon = action:GetAttackWeapons(unit)
	local canAttack, reason = unit:CanAttack(
		args.target,
		weapon, action,
		args and args.aim,
		args and args.goto_pos,
		nil,
		args.free_aim
	)
	reason = reason or not canAttack and T(138935217566, "Action not possible")
	if reason then ReportAttackError(IsValid(args.target) and args.target or unit, reason) end
	
	if state == "enabled" then
		return canAttack and "enabled" or "disabled"
	end
	ReportAttackError(IsValid(args.target) and args.target or unit, err or T(818027394095, "Action not available."))
	return state
end

--- Displays a floating error text on the screen when an attack action is not possible.
---
--- This function is used to report an error message when an attack action cannot be performed. It creates a custom floating text object and displays it on the screen, either near the target object or at the terrain cursor if the target is off-screen. The error message is also logged to the combat log.
---
--- @param obj table The object (unit or position) associated with the failed attack action.
--- @param err string The error message to be displayed.
function ReportAttackError(obj, err)
	local floatingErr = _InternalTranslate(err, {["flavor"] = "<color FloatingTextError>"})
	local front, pt = GameToScreen(IsPoint(obj) and obj or obj:GetPos())
	if not front or not terminal.desktop.box:PointInside(pt) then
		CreateCustomFloatingText(XTemplateSpawn("CantAttackFloatingText", GetDialog("FloatingTextDialog")), GetTerrainCursor(), floatingErr	)
	else
		CreateCustomFloatingText(XTemplateSpawn("CantAttackFloatingText", GetDialog("FloatingTextDialog")), obj, floatingErr	)
	end
	CombatLog("short", err)
end

--- Finds the unit that is currently bandaging the given downed unit.
---
--- @param downedUnit table The downed unit to find the bandaging unit for.
--- @return table|boolean The unit that is bandaging the downed unit, or false if no unit is bandaging it.
function FindBandagingUnit(downedUnit)
	if not downedUnit:IsDowned() then return end
	local allies = GetAllAlliedUnits(downedUnit)
	for i, ally in ipairs(allies) do
		if ally:GetBandageTarget() == downedUnit then
			return ally
		end
	end
	return false
end

--- Checks if the game is paused by the game logic.
---
--- This function checks if the game is paused and if the pause is not an active pause (e.g. during a cutscene). It also checks if certain dialogs are not open, such as the PDA dialog, deployment screen, or radio banter dialog.
---
--- @return boolean true if the game is paused by the game logic, false otherwise
function IsPausedByGameLogic()
	return (IsPaused() and not IsActivePaused()) and not (GetDialog("PDADialogSatellite") or gv_Deployment or GetDialog("RadioBanterDialog") or GetDialog("FullscreenGameDialogs"))
end

-- Used by UI to delay certain animations and actions until after various gameplay interruptions.
--- Checks if there are any player control stoppers that would prevent the player from taking actions.
---
--- This function checks for various conditions that would prevent the player from taking actions, such as open dialogs, setpieces playing, repositioning phases, and paused game logic. It returns true if any of these conditions are met, indicating that player control is stopped.
---
--- @param params table Optional parameters:
---   - skip_pause (boolean): If true, skips checking for paused game logic.
--- @return boolean true if there are any player control stoppers, false otherwise.
function AnyPlayerControlStoppers(params)
	if GetDialog("ConversationDialog") then return true end
	if IsSetpiecePlaying() then return true end
	if IsRepositionPhase() then return true end
	if GetDialog("PopupNotification") then return true end
	
	if not params or not params.skip_pause then
		if IsPausedByGameLogic() then return true end
	end
end

--- Waits for any player control stoppers to be cleared before allowing the player to take actions.
---
--- This function checks for various conditions that would prevent the player from taking actions, such as open dialogs, setpieces playing, repositioning phases, and paused game logic. It waits for these conditions to be cleared before returning.
---
--- @param params table Optional parameters:
---   - skip_setpiece (boolean): If true, skips checking for setpieces playing.
---   - skip_popup (boolean): If true, skips checking for popup notifications.
---   - no_coop_pause (boolean): If true, skips checking for paused game logic in co-op mode.
--- @return boolean true if there were any player control stoppers, false otherwise.
function WaitPlayerControl(params)
	local anyStoppersAtAll = false
	local anyStoppers = true
	while anyStoppers do
		anyStoppers = false
		if GetDialog("ConversationDialog") then
			anyStoppers = true
			WaitMsg("CloseConversationDialog", 100)
		end
		if GetDialog("CoopMercsManagement") then
			anyStoppers = true
			Sleep(500)
		end
		if not params or not params.skip_setpiece then
			if IsSetpiecePlaying() then
				anyStoppers = true
				WaitMsg("SetpieceDialogClosed", 100)
			end
		end
		while IsRepositionPhase() and not IsSetpiecePlaying() do
			anyStoppers = true
			WaitMsg("RepositionEnd", 100)
		end
		if not params or not params.skip_popup then
			while GetDialog("PopupNotification") do
				anyStoppers = true
				local popupNot = GetDialog("PopupNotification")
				WaitMsg(popupNot, 100)
			end
		end
		if IsPausedByGameLogic() and (not params or not params.no_coop_pause or IsCampaignPausedByRemotePlayerOnly()) then
			anyStoppers = true
		end
		if anyStoppers then
			Sleep(1000) -- The above interruptors can spawn another interruptor.
			anyStoppersAtAll = true
		end
	end
	return anyStoppersAtAll
end

--- Finds a text style in the `TextStyles` table that matches the given font name and color.
---
--- @param fontName string The name of the font to search for.
--- @param color table The color to search for.
--- @return string|table If no matching text style is found, returns the string "create a new one", otherwise returns a table of matching text style IDs.
function FindTextStyle(fontName, color)
	local results = {}
	for i, t in pairs(TextStyles) do
		local nameTranslated = _InternalTranslate(t.TextFont)
		if nameTranslated == fontName and t.TextColor == color then
			results[#results + 1] = t.id
		end
	end
	return #results == 0 and "create a new one" or results
end

--- Finds a list of duplicate text styles in the `TextStyles` table.
---
--- This function compares all text styles in the `TextStyles` table, excluding those in the "Common" and "Zulu Old" groups, as well as any styles containing the word "droid". It checks for styles that have the same translated font name, text color, rollover text color, shadow type and color, and disabled text color and rollover text color.
---
--- @return table A table of strings, where each string represents a pair of duplicate text style IDs.
--- @return number The number of duplicate text styles found.
function FindDuplicateTextStyles()
	local duplicate = {}
	local dedupePair = {}
	for i, t in pairs(TextStyles) do
		for i2, t2 in pairs(TextStyles) do
			local nameTranslated = _InternalTranslate(t.TextFont)
			local nameTranslated2 = _InternalTranslate(t2.TextFont)
			if
				t.group ~= "Common" and t2.group ~= "Common" and
				t.group ~= "Zulu Old" and t2.group ~= "Zulu Old" and
				not string.find(nameTranslated, "droid") and not string.find(nameTranslated2, "droid") and
				i ~= i2 and
				nameTranslated == nameTranslated2 and
				t.TextColor == t2.TextColor and
				t.RolloverTextColor == t2.RolloverTextColor and
				t.ShadowType == t2.ShadowType and t.ShadowColor == t2.ShadowColor and
				t.DisabledTextColor == t2.DisabledTextColor and 
				t.DisabledRolloverTextColor == t2.DisabledRolloverTextColor then
				
				if not dedupePair[t.id] or not dedupePair[t.id][t2.id] then
					duplicate[#duplicate + 1] = t.id .. " is like " .. t2.id
				end
				
				if not dedupePair[t.id] then dedupePair[t.id] = {} end
				dedupePair[t.id][t2.id] = true
				
				if not dedupePair[t2.id] then dedupePair[t2.id] = {} end
				dedupePair[t2.id][t.id] = true
			end
		end
	end
	return duplicate, #duplicate
end

DefineClass.ZuluContextMenu = {
	__parents = { "XPopup", "XDrawCache", "XActionsHost" },
	
	RefreshInterval = 1000,
	MinWidth = 200,
	
	Background = GameColors.B,
	FocusedBackground = GameColors.B,
	BackgroundRectGlowSize = 1,
	BackgroundRectGlowColor = GameColors.A,
	
	BorderColor = GameColors.A,
	FocusedBorderColor = GameColors.A,
	BorderWidth = 2,
	ChildAnchorType = false,
	
	applied_virtual_cursor_disable = false
}

--- Initializes the ZuluContextMenu class.
---
--- This function is called when a new instance of the ZuluContextMenu class is created.
--- It checks if the ZuluMouseViaGamepadDisableReasons table exists and if the "context-menu" reason is not already in the table.
--- If the condition is met, it sets the mouse cursor to be disabled via gamepad and stores a flag indicating that the virtual cursor has been applied.
function ZuluContextMenu:Init()
	if not ZuluMouseViaGamepadDisableReasons or not table.find(ZuluMouseViaGamepadDisableReasons, "context-menu") then
		SetDisableMouseViaGamepad(true, "context-menu")
		self.applied_virtual_cursor_disable = true
	end
end

--- Finalizes the ZuluContextMenu instance.
---
--- This function is called when the ZuluContextMenu instance is being destroyed.
--- It checks if the virtual mouse cursor was disabled during the ZuluContextMenu:Init() function,
--- and if so, it re-enables the mouse cursor via gamepad.
function ZuluContextMenu:Done()
	if self.applied_virtual_cursor_disable then
		SetDisableMouseViaGamepad(false, "context-menu")
	end
end

--- Opens the ZuluContextMenu instance.
---
--- This function is called when the ZuluContextMenu instance needs to be opened. It performs the following actions:
--- - If the `RefreshInterval` property is set, it creates a thread that periodically calls the `UpdateRolloverContent` function to update the content of the context menu.
--- - It calls the `Open` function of the `XPopup` class to open the context menu.
--- - If the context menu's parent is an `XPopup` instance and it has a `ChildAnchorType` property set, it sets the anchor type of the current context menu to match the parent's anchor type.
--- - It sets the mouse cursor to the "Pda_Cursor.tga" cursor if the "PDADialogSatellite" dialog is visible, or to the default cursor otherwise.
function ZuluContextMenu:Open()
	if self.RefreshInterval then
		self:CreateThread("UpdateRolloverContent", function(self)
			while true do
				Sleep(self.RefreshInterval)
				self:UpdateRolloverContent()
			end
		end, self)
	end
	XPopup.Open(self)
	local popparent = self.popup_parent 
	if IsKindOf(popparent, "XPopup") and popparent.ChildAnchorType then
		self:SetAnchorType(popparent.ChildAnchorType)
	end
	local pda = gv_SatelliteView and GetDialog("PDADialogSatellite")
	pda = pda and pda.visible
	self:SetMouseCursor(pda and "UI/Cursors/Pda_Cursor.tga" or const.DefaultMouseCursor)
end

--- Updates the rollover content of the ZuluContextMenu instance.
---
--- This function is called to update the content of the context menu when the rollover content needs to be refreshed.
--- It retrieves the "idContent" property of the ZuluContextMenu instance and calls the "OnContextUpdate" function on it, passing the "context" property as an argument.
---
--- @function ZuluContextMenu:UpdateRolloverContent
--- @return nil
function ZuluContextMenu:UpdateRolloverContent()
	local content = rawget(self, "idContent")
	if content then
		content:OnContextUpdate(content.context)
	end
end

---
--- Calculates the custom anchor position for the ZuluContextMenu instance based on the provided anchor position and the safe area.
---
--- This function is used to determine the appropriate position for the context menu when it is opened. It takes into account the margins of the context menu and the safe area of the screen to ensure the menu is displayed within the safe area.
---
--- @param x (number) The x-coordinate of the anchor position.
--- @param y (number) The y-coordinate of the anchor position.
--- @param width (number) The width of the context menu.
--- @param height (number) The height of the context menu.
--- @param anchor (table) The anchor position, represented as a table with `minx`, `miny`, `maxx`, and `maxy` properties.
--- @return number, number, number, number The calculated x, y, width, and height of the context menu.
function ZuluContextMenu:GetCustomAnchor(x, y, width, height, anchor)
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	-- right
	x = anchor:maxx() + margins_x1
	y = anchor:miny() - margins_y1	
	self.ChildAnchorType = "right"
	--left
	if x + 2*width + margins_x2 > safe_area_x2 then
		x = anchor:minx() - width - margins_x2 --move to left side
		self.ChildAnchorType = "left"
	end
	return x, y, width, height
end


DefineClass.AutoFitText = {
	__parents = { "XText" },
	WordWrap = false,
	properties = {
		{ id = "SafeSpace", editor = "number", default = 0 }
	}
}

--- Updates the measure of the AutoFitText instance.
---
--- This function is called to update the measure of the AutoFitText instance. It sets the scale of the AutoFitText instance to the scale of its parent, and then calls the `XText.UpdateMeasure` function with the provided arguments.
---
--- @function AutoFitText:UpdateMeasure
--- @param ... (any) The arguments to pass to the `XText.UpdateMeasure` function.
--- @return any The return value of the `XText.UpdateMeasure` function.
function AutoFitText:UpdateMeasure(...)
	self.scale = self.parent.scale
	return XText.UpdateMeasure(self, ...)
end

---
--- Updates the measure of the AutoFitText instance.
---
--- This function is called to update the measure of the AutoFitText instance. It sets the scale of the AutoFitText instance to the scale of its parent, and then calls the `XText.UpdateMeasure` function with the provided arguments.
---
--- @param max_width (number) The maximum width available for the text.
--- @param max_height (number) The maximum height available for the text.
--- @return number, number The calculated width and height of the text.
function AutoFitText:Measure(max_width, max_height)
	self.scale = self.parent.scale
	self.content_measure_width = max_width
	self.content_measure_height = max_height
	
	if self.WordWrap then
		self:UpdateDrawCache(max_width, max_height, true)
	else
		self:UpdateDrawCache(9999999, max_height, true)
	end
	
	local scaleDiff = 1000
	local sizeNeeded = self.text_width + ScaleXY(self.scale, self.SafeSpace)
	local height = Clamp(self.text_height, self.font_height, max_height)
	local redoMeasure = false
	if sizeNeeded > max_width then
		scaleDiff = MulDivRound(max_width, 1000, sizeNeeded)
		redoMeasure = self.HAlign == "center" or self.HAlign == "right"
	end
	self.ScaleModifier = point(scaleDiff, scaleDiff)
	self.scale = point(ScaleXY(self.parent.scale, self.ScaleModifier:xy()))
	if redoMeasure then self:UpdateDrawCache(max_width, max_height, true) end
	return self.text_width, height
end

DefineClass.XTextWithStyleBasedOnSize = {
	__parents = { "XText" },
	properties = {
		{ editor = "text", id = "TextStyleSmall", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true }
	}
}

---
--- Measures the size of the text in the `XTextWithStyleBasedOnSize` instance, adjusting the text style if the text is too large to fit the maximum width.
---
--- @param max_width (number) The maximum width available for the text.
--- @param max_height (number) The maximum height available for the text.
--- @return number, number The calculated width and height of the text.
function XTextWithStyleBasedOnSize:Measure(max_width, max_height)
	self:SetTextStyle(self.TextStyle)
	
	local text = _InternalTranslate(self.Text, self.context)
	local break_candidate = utf8.FindNextLineBreakCandidate(text, 1)
	local largestBreakSize = false
	while break_candidate and break_candidate <= #text + 1 do
		local breakSize = UIL.MeasureText(text, self:GetFontId(), 1, break_candidate - 1)
		largestBreakSize = Max(largestBreakSize or 0, breakSize)
		break_candidate = utf8.FindNextLineBreakCandidate(text, break_candidate)
	end
	if largestBreakSize and largestBreakSize > max_width then
		self:SetTextStyle(self.TextStyleSmall)
	end
	
	return XText.Measure(self, max_width, max_height)
end

---
--- Returns a table of enemy squad definitions, optionally excluding the "Test Encounters" group.
---
--- @param excl_test (boolean) If true, excludes enemy squads from the "Test Encounters" group.
--- @return table A table of enemy squad definitions.
function EnemySquadsComboItems(excl_test) 
	if excl_test then
		local res = {}
		for _, squad in pairs(EnemySquadDefs) do
			if squad.group ~= "Test Encounters" then 
				table.insert(res, squad)
			end
		end
		return res
	end
	return table.keys(EnemySquadDefs, true)
end

---
--- Returns a table of persistent session IDs for all unit data definitions.
---
--- @return table A table of persistent session IDs.
function GetPersistentSessionIds()
	local res = {}
	for _, unitT in pairs(UnitDataDefs) do 
		if unitT.PersistentSessionId then
			table.insert(res, unitT.PersistentSessionId)
		end
	end
	return res
end

---
--- Modifies a base value by a difficulty value.
---
--- @param diff_value number The difficulty value to modify the base value by.
--- @return number The modified base value.
function PercentModifyByDifficulty(diff_value)
	local baseValDiffPerc = 100
	if type(diff_value) == "number" then 
		baseValDiffPerc = baseValDiffPerc + diff_value
	end
		
	return baseValDiffPerc 
end

-- Dirty fix for std popups until we get out own.
StdDialog.ZOrder = 100

---
--- Updates the mouse cursor based on the current mouse position and the active modal window.
---
--- @param pt table|nil The current mouse position, or nil to use the last known position.
--- @return table|false The target object under the mouse cursor, or false if the mouse is captured by another object.
function XDesktop:UpdateCursor(pt)
	pt = pt or self.last_mouse_pos
	if not pt then return end
	local target, cursor = self.modal_window:GetMouseTarget(pt)
	target = target or self.modal_window
	if self.mouse_capture and target ~= self.mouse_capture then
		cursor = self.mouse_capture:GetMouseCursor()
		target = false
	end
	local pda = gv_SatelliteView and GetDialog("PDADialogSatellite")
	pda = pda and pda.visible and pda
	local curr_cursor = pda and pda.mouse_cursor or cursor or const.DefaultMouseCursor
	if prev_cursor ~= curr_cursor then
		SetUIMouseCursor(curr_cursor)
		Msg("MouseCursor", curr_cursor)
		prev_cursor = curr_cursor
	end
	return target
end

local oldRestoreFocus = XDesktop.RestoreFocus
---
--- Restores the focus to the desktop after a modal window is closed.
---
--- This function overrides the default `XDesktop:RestoreFocus` function to also
--- call `RefreshPopupFocus()` after the original function is called. This ensures
--- that the focus is properly restored to the desktop and any open popup windows
--- are also updated.
---
--- @param self XDesktop The XDesktop instance.
--- @param ... Any additional arguments passed to the original `RestoreFocus` function.
---
function XDesktop:RestoreFocus(...)
	oldRestoreFocus(self, ...)
	RefreshPopupFocus()
end

if FirstLoad then
TermsInText = false
end

---
--- Formats a game term by checking if it exists in the default game term preset. If the term exists, it returns the translated term name wrapped in an HTML `<em>` tag. If the term does not exist, it returns the term with a message indicating that the preset is missing.
---
--- @param context_obj table The context object, which is not used in this function.
--- @param word string The game term to format.
--- @return string The formatted game term.
---
function TFormat.GameTerm(context_obj, word)
	if not word then
		print("no game term specified in tag!")
		return
	end

	if not TermsInText then TermsInText = {} end
	if not TermsInText[word] then
		TermsInText[#TermsInText + 1] = word
		TermsInText[word] = word
	end
	
	local terms = Presets.GameTerm.Default
	if terms[word] then
		return T{961635936261, "<em><TermName></em>", TermName = terms[word].Name }
	end
	return Untranslated(word .. "(GameTerm preset missing)")
end

---
--- Formats an additional game term by checking if it exists in the default game term preset. If the term exists, it returns an empty string. If the term does not exist, it returns the term with a message indicating that the preset is missing.
---
--- @param context_obj table The context object, which is not used in this function.
--- @param word string The game term to format.
--- @return string The formatted game term.
---
function TFormat.AdditionalTerm(context_obj, word)
	if not word then
		print("no game term specified in tag!")
		return
	end

	if not TermsInText then TermsInText = {} end
	if not TermsInText[word] then
		TermsInText[#TermsInText + 1] = word
		TermsInText[word] = word
	end
	
	local terms = Presets.GameTerm.Default
	if terms[word] then
		return ""
	end
	return Untranslated(word .. "(GameTerm preset missing)")
end


--- Retrieves a list of all game terms found in the provided text.
---
--- @param text string The text to search for game terms.
--- @return table A table containing all unique game terms found in the text.
function GetGameTermsInText(text)
	if not TermsInText then TermsInText = {} end
	table.clear(TermsInText)
	_InternalTranslate(text)
	return table.copy(TermsInText)
end

DefineClass.TermClarifyingRollover = {
	__parents = { "XRolloverWindow", "XContextWindow" },
	ContextUpdateOnOpen = true,
	
	termUI = false
}

---
--- Updates the context of the TermClarifyingRollover UI element by retrieving a list of game terms found in the text content of the idContent.idText control, and then displaying those terms.
---
--- @param self TermClarifyingRollover The TermClarifyingRollover instance.
--- @return table A table containing all unique game terms found in the text.
function TermClarifyingRollover:OnContextUpdate()
	local textControl = self and self.idContent and self.idContent.idText
	local terms = textControl and GetGameTermsInText(textControl.Text) or empty_table
	self:ShowTerms(terms)
	return terms
end

---
--- Calculates the position and size of the TermClarifyingRollover UI element based on the provided anchor and safe area constraints.
---
--- @param self TermClarifyingRollover The TermClarifyingRollover instance.
--- @param x number The initial x-coordinate of the UI element.
--- @param y number The initial y-coordinate of the UI element.
--- @param width number The initial width of the UI element.
--- @param height number The initial height of the UI element.
--- @param anchor table The anchor rectangle to position the UI element relative to.
--- @return number, number, number, number The calculated x, y, width, and height of the UI element.
function TermClarifyingRollover:GetCustomAnchor(x, y, width, height, anchor)
	if self.context and self.context.control and self.context.control.bottomAnchor then
		return self:GetBottomAnchor(x, y, width, height, anchor)
	end

	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())

	local termWidth = (self.termUI and self.termUI.measure_width or 0)
	x = anchor:minx() + ((anchor:maxx() - anchor:minx()) - (width + termWidth))/2
	y = anchor:miny() - height - margins_y2
	
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	if self.termUI then
		--local dock = x < safe_area_x1 and "right" or "left" bad idea
		local dock = "right"
		if self.termUI.Dock ~= dock then
			self.termUI:SetDock(dock)
		end
		if dock == "right" then
			x = x + termWidth
		end
	end
	
	return x, y, width, height
end

---
--- Calculates the position and size of the TermClarifyingRollover UI element based on the provided anchor and safe area constraints.
---
--- @param self TermClarifyingRollover The TermClarifyingRollover instance.
--- @param x number The initial x-coordinate of the UI element.
--- @param y number The initial y-coordinate of the UI element.
--- @param width number The initial width of the UI element.
--- @param height number The initial height of the UI element.
--- @param anchor table The anchor rectangle to position the UI element relative to.
--- @return number, number, number, number The calculated x, y, width, and height of the UI element.
function TermClarifyingRollover:GetBottomAnchor(x, y, width, height, anchor)
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())

	local termWidth = (self.termUI and self.termUI.measure_width or 0)

	x = anchor:minx() + ((anchor:maxx() - anchor:minx()) - (width + termWidth))/2
	y = anchor:maxy() + margins_y2
	
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	if self.termUI then
		local dockX = x < safe_area_x1 and "right" or "left"
		if self.termUI.Dock ~= dockX then
			self.termUI:SetDock(dockX)
		end
		if dockX == "right" then
			x = x + termWidth
		end
		
		if  y + height + margins_y2 > safe_area_y2 then
			y = anchor:miny() - height - margins_y2
			self.idContent:SetVAlign("bottom")
		else
			self.idContent:SetVAlign("top")
		end
		
	end
	
	return x, y, width, height
end

DefineClass.PDATermClarifyingRollover = {
	__parents = { "PDARolloverClass", "TermClarifyingRollover" },
}

function PDATermClarifyingRollover.Open(self)
	PDARolloverClass.Open(self)
	self:OnContextUpdate(self.context, "open")
end

---
--- Shows the terms in the TermClarifyingRollover UI element.
---
--- @param self TermClarifyingRollover The TermClarifyingRollover instance.
--- @param terms table The list of terms to display.
---
function TermClarifyingRollover:ShowTerms(terms)
	local ctx = SubContext(self.context, { terms = terms })
	if not self.termUI then
		local clarification = XTemplateSpawn("RolloverTermClarification", self, ctx)
		clarification:Open()
		self.termUI = clarification
	end

	self.termUI.idContent:SetContext(ctx)
	if #terms == 0 then
		self.termUI:SetVisible(false)
	end
end

---
--- Closes the TermClarifyingRollover UI element when the TermClarifyingRollover instance is deleted.
---
--- @param self TermClarifyingRollover The TermClarifyingRollover instance.
---
function TermClarifyingRollover:OnDelete()
	if self.termUI and self.termUI.window_state ~= "destroying" then
		self.termUI:Close()
	end
end

---
--- Converts a number representing a timestamp to a formatted date and time string.
---
--- @param number number The timestamp to convert.
--- @param real_time boolean Whether the timestamp represents real-time or game-time.
--- @return string The formatted date and time string.
---
function numberToTimeDate(number, real_time)
	if type(number) ~= "number" and real_time then 
		number = os.time()
	end
	local osDateFormat = GetDateTimeOrder()
	local saveTimeAsTable = GetTimeAsTable(number, real_time)
	
	local saveTime = string.format("%02d", saveTimeAsTable.hour)  .. ":" .. string.format("%02d", saveTimeAsTable.min)
	local saveDate = {}
	for i, unit in ipairs(osDateFormat) do
		saveDate[i] = saveTimeAsTable[unit]
	end
	saveDate = table.concat(saveDate, "/")
	local finalTimeDate = saveTime .. " " .. saveDate
	return finalTimeDate
end

---
--- Resolves the value of a specified parameter for a given status effect.
---
--- @param context_obj table The context object that has the status effect.
--- @param effect string The name of the status effect.
--- @param param string The name of the parameter to resolve.
--- @return number The resolved value of the parameter.
---
function TFormat.StatusEffectParam(context_obj, effect, param)
	local effect = g_Classes[effect]
	if not effect then return Untranslated("Couldn't find effect ".. effect) end
	local val = effect:ResolveValue(param) or 0
	return val
end

local SaveStatesT = {
	Exploration = T(995350103389, "Exploration"),
	TurnEnd = T(987479599419, "Turn <number> End"),
	Turn = T(214899348072, "Turn <number>"),
	CombatEnd = T(399785668141, "Combat End"),
	CombatStart = T(742715930390, "Combat Start"),
	NewDay = T(763044143109, "New Day"),
	SectorEnter = T(874301202187, "Sector Enter"),
	ExitGame = T(184190822120, "Exit Game"),
	Ending = T(658082619539, "Ending"),
}

---
--- Returns the save state string for the given state and turn number.
---
--- @param state string The name of the save state.
--- @param saveStateTurnNumber number The turn number for the save state.
--- @return string The formatted save state string.
---
function GetSaveState(state, saveStateTurnNumber)
	if SaveStatesT[state] then
		return T{SaveStatesT[state], number = saveStateTurnNumber}
	end
		
	return T(831373652255, "Satellite")
end
---
--- Returns the specialization name for the given mercenary.
---
--- @param context_obj table The mercenary object.
--- @return string The specialization name.
---
function TFormat.MercClass(context_obj)
	local specName = Presets.MercSpecializations.Default
	specName = context_obj and specName[context_obj.Specialization]
	specName = specName and specName.name
	return specName
end

if FirstLoad then
g_RolloverShowMoreInfo = false
g_RolloverShowMoreInfoFakeRollover = false
end

local energyEffects = {
	"WellRested"
}

RedEnergyEffects = {
	"Tired",
	"Exhausted",
	"Unconscious"
}

local noEnergyEffect = T(102280983313, "Normal")

---
--- Returns the energy status effect for the given mercenary object.
---
--- @param context_obj table The mercenary object.
--- @return string The energy status effect.
---
function TFormat.EnergyStatusEffect(context_obj)
	-- Check for red
	for i, ef in ipairs(RedEnergyEffects) do
		if context_obj:HasStatusEffect(ef) then
			if g_Classes[ef]:ResolveValue("ap_loss") then
				return T{648417490486, "<error><EffectName></error> (<ApValue>AP)", EffectName = g_Classes[ef].DisplayName, ApValue = g_Classes[ef]:ResolveValue("ap_loss")}
			else
				return T{753249704554, "<error><EffectName></error>", EffectName = g_Classes[ef].DisplayName}
			end
		end
	end
	
	-- Check for effect
	for i, ef in ipairs(energyEffects) do
		if context_obj:HasStatusEffect(ef) then
			if g_Classes[ef]:ResolveValue("ap_gain") then
				return T{213633160729, "<effectName> (+<apValue>AP)", effectName = g_Classes[ef].DisplayName, apValue = g_Classes[ef]:ResolveValue("ap_gain")}
			else
				return g_Classes[ef].DisplayName
			end
		end
	end
	
	return noEnergyEffect
end

---
--- Returns the formatted text for a mercenary's morale level.
---
--- @param context_obj table The mercenary object.
--- @return string The formatted morale text.
---
function TFormat.MercMoraleText(context_obj)
	local personalMorale = context_obj:GetPersonalMorale()
	return MoraleLevelName[personalMorale] .. ( personalMorale ~= 0 and T{450959430309, " (<apValue>AP)", apValue = personalMorale > 0 and (Untranslated("+") .. personalMorale) or personalMorale} or "")
end

---
--- Generates a dynamic "More Info" button text based on whether more information is available and whether it is currently being shown.
---
--- @return string The formatted "More Info" button text.
---
function TFormat.MoreInfoDynamic()
	return T(998024303154, "[<ShortcutButton('rolloverMoreInfo')>] ") ..
		(g_RolloverShowMoreInfo and T(917639413507, "Hide Info") or T(979175068963, "More Info"))
end

---
--- Checks if more information is available for the given context.
---
--- @param context table The context object to check for more information.
--- @return boolean True if more information is available, false otherwise.
---
function HasMoreInfo(context)
	if not context then return false end
	if g_RolloverShowMoreInfoFakeRollover then
		return true
	end
	local moreInfo
	if context.termUI and context.termUI.context.terms then
		moreInfo = #context.termUI.context.terms > 0
	else
		moreInfo = context:ResolveId("idMoreInfo")
		if not moreInfo then
			local content = context:ResolveId("idContent")
			moreInfo = content and content:ResolveId("idMoreInfo")
		end
	end
	return not not moreInfo
end

date_format_cache = {}

---
--- Generates a date format string based on the system date format, excluding a specified date unit.
---
--- @param to_remove string (optional) The date unit to exclude from the generated format string. If not provided, no units will be removed.
--- @return string The generated date format string.
---
function GetDateFormat(to_remove)
	to_remove = to_remove or "don't remove anything"
	if date_format_cache[to_remove] then return date_format_cache[to_remove] end

	-- Prepare date formats used through the PDA.
	local systemDateFormat = GetDateTimeOrder()
	local dateFormat = {}
	for i, unit in ipairs(systemDateFormat) do
		if unit ~= to_remove then
			dateFormat[#dateFormat + 1] = "<" .. unit .. "(t)>"
		end
	end

	date_format_cache[to_remove] = table.concat(dateFormat, " ")
	return date_format_cache[to_remove]
end

---
--- Generates a date format string based on the system date format, excluding the year.
---
--- @param context table The context object.
--- @param time number The time to format.
--- @return string The formatted date string.
---
function TFormat.DateFormatted(context, time)
	return T{GetDateFormat("year"), t = time}
end

---
--- Generates a date format string based on the system date format, including the year.
---
--- @param context table The context object.
--- @param time number The time to format.
--- @return string The formatted date string.
---
function TFormat.DateFormattedIncludingYear(context, time)
	return T{GetDateFormat(), t = time}
end

local neverGuilty = { "Psycho", "StressManagement", "Optimist", "Drunk", "TheGrim" }
local superstitious = { "Spiritual", "GloryHog", "Pessimist", "Nazdarovya" }
local neverProud = { "OldDog", "TheGrim" } 
local prideful = { "Spiritual", "GloryHog", "BunsPerk", "BuildingConfidence" } 
---
--- Applies a "Conscience_Proud" or "Conscience_Guilty" status effect to player mercs in the current sector, based on their existing status effects.
---
--- @param applyEffect string Either "positive" or "negative" to apply the corresponding status effect.
---
function ApplyGuiltyOrRighteousEffect(applyEffect)
	assert(gv_CurrentSectorId)
	assert(applyEffect)
	
	local mercs = GetPlayerMercsInSector(gv_CurrentSectorId)
	if gv_SatelliteView then
		mercs = table.map(mercs, function(oId) return gv_UnitData[oId] end)
	else
		mercs = table.map(mercs, function(oId) return g_Units[oId] end)
	end
	
	for i, merc in ipairs(mercs) do
		local effectType = applyEffect == "positive" and "Conscience_Proud" or "Conscience_Guilty"
		
		for _, effect in ipairs(applyEffect == "positive" and neverProud or neverGuilty) do
			if merc:HasStatusEffect(effect) then
				effectType = false
				break
			end
		end
		
		if effectType then
			for _, effect in ipairs(applyEffect == "positive" and prideful or superstitious) do
				if merc:HasStatusEffect(effect) then
					effectType = applyEffect == "positive" and "Conscience_Righteous" or "Conscience_Sinful"
					break
				end
			end
		end
		
		if effectType then
			merc:AddStatusEffect(effectType)
		end
	end
end

---
--- Checks if all units in the given group are neutral.
---
--- @param group string The group to check for neutral units.
--- @return boolean True if all units in the group are neutral, false otherwise.
---
function AllUnitsOfGroupAreNeutral(group)
	local anyOfGroup = false
	for i, u in ipairs(g_Units) do
		if u:IsInGroup(group) then
			anyOfGroup = true
			if IsPlayerEnemy(u) then
				return false
			end
		end
	end
	return anyOfGroup
end

-- Used for tracking one time UI animations such as
-- when an event or UI elements shows up for the first time.
-- Also for tracking UI animation start times
GameVar("UIAnimationsShown", function() return {} end)

---
--- Checks if the specified animation has been shown before.
---
--- @param id string The unique identifier of the animation.
--- @return boolean True if the animation has been shown before, false otherwise.
---
function WasAnimationShown(id)
	return not not UIAnimationsShown[id]
end

---
--- Marks the specified animation as having been shown before.
---
--- @param id string The unique identifier of the animation.
---
function AnimationWasShown(id)
	UIAnimationsShown[id] = true
end

---
--- Resets the flag indicating that the specified animation has been shown before.
---
--- @param id string The unique identifier of the animation to reset.
---
function AnimationShownReset(id)
	UIAnimationsShown[id] = false
end

---
--- Returns the nick name of the specified unit.
---
--- @param context_obj any The context object.
--- @param id number The ID of the unit.
--- @return string The nick name of the unit, or nil if the unit is not a mercenary.
---
function TFormat.Nick(context_obj, id)
	local merc = gv_UnitData[id]
	if IsMerc(merc) then
		return merc.Nick
	end
end

---
--- Returns the name of the specified combat task definition.
---
--- @param context_obj any The context object.
--- @param id number The ID of the combat task definition.
--- @return string The name of the combat task definition, or nil if the definition is not found.
---
function TFormat.CombatTask(context_obj, id)
	local def = CombatTaskDefs[id]
	if def then
		return def.name
	end
end

---
--- Returns the display name of the specified quest.
---
--- @param context_obj any The context object.
--- @param id number The ID of the quest.
--- @return string The display name of the quest, or nil if the quest is not found.
---
function TFormat.Quest(context_obj, id)
	local def = Quests[id]
	if def then
		return def.DisplayName
	end
end

DefineClass.XWindowWithRolloverFX = {
	__parents = { "XContextWindow" }
}

---
--- Handles the rollover effect for the window.
---
--- @param rollover boolean Whether the window is in a rollover state.
---
function XWindowWithRolloverFX:OnSetRollover(rollover)
	if rollover then PlayFX("buttonRollover", "start") end
end

DefineClass.RespawningButton = {
	__parents = { "XButton", "XContentTemplate" }

}

---
--- Handles the shortcut key press for the RespawningButton.
---
--- @param ... any Any additional arguments passed to the shortcut handler.
---
function RespawningButton:OnShortcut(...)
	XButton.OnShortcut(self, ...)
end

ForbiddenShortcutKeys = {
	Lwin = true,
	Rwin = true,
	Menu = true,
	MouseL = true,
	MouseR = true,
	Enter = true,
}

---
--- Converts a difficulty string to a numeric value.
---
--- @param diff string The difficulty string to convert.
--- @param wisdom boolean Whether to use the wisdom difficulty presets.
--- @return number The numeric value of the difficulty.
---
function DifficultyToNumber(diff, wisdom)
	if type(diff) == "number" then 
		assert(false, "The difficulty should be of type string.")
		return diff 
	end
	local entry = wisdom and table.find_value(const.DifficultyPresetsWisdomMarkersNew, "id", diff) or table.find_value(const.DifficultyPresetsNew, "id", diff)
	if entry then
		return entry.value
	elseif tonumber(diff) then
		return tonumber(diff) -- Edge case in conversion to new values, some were leftover and converted to string
	else
		assert(false, "This difficulty is non-existent.")
		return 0
	end
end

---
--- Checks if two axis-aligned bounding boxes (AABBs) intersect.
---
--- @param boxOne table The first AABB, represented as a table with `minx`, `miny`, `maxx`, and `maxy` fields.
--- @param boxTwo table The second AABB, represented as a table with `minx`, `miny`, `maxx`, and `maxy` fields.
--- @return boolean True if the two AABBs intersect, false otherwise.
---
function BoxIntersectsBox(boxOne, boxTwo)
	return boxTwo:minx() < boxOne:maxx() and
		boxOne:minx() < boxTwo:maxx() and
		boxTwo:miny() < boxOne:maxy() and
		boxOne:miny() < boxTwo:maxy()
end

---
--- Returns a new point with the maximum coordinates of the given point and the provided maximum value.
---
--- @param po point The point to get the maximum coordinates from.
--- @param max number The maximum value to use.
--- @return point A new point with the maximum coordinates.
---
function PointMax(po, max)
	return point(Max(po:x(), max), Max(po:y(), max))
end

---
--- Returns a new point with the minimum coordinates of the given point and the provided minimum value.
---
--- @param po point The point to get the minimum coordinates from.
--- @param min number The minimum value to use.
--- @return point A new point with the minimum coordinates.
---
function PointMin(po, min)
	return point(Min(po:x(), min), Min(po:y(), min))
end

DefineClass.ZuluFrameProgress = {
	__parents = { "XFrameProgress" },
	ProgressClip = true
}

---
--- Checks if the given side is a player side.
---
--- @param side string The side to check.
--- @return boolean True if the side is a player side, false otherwise.
---
function IsPlayerSide(side)
	return side == "player1" or side == "player2"
end

---
--- Checks if the given side is an enemy side.
---
--- @param side string The side to check.
--- @return boolean True if the side is an enemy side, false otherwise.
---
function IsEnemySide(side)
	return side == "enemy1" or side == "enemy2" or side == "enemyNeutral"
end

local commonGetShortcuts = GetShortcuts
---
--- Gets the shortcuts for the given action ID.
---
--- @param action_id string The action ID to get the shortcuts for.
--- @return table|nil The shortcuts for the given action ID, or nil if none are found.
---
function GetShortcuts(action_id)
	local shortcuts = commonGetShortcuts(action_id)
	if shortcuts then
		for i, sh in ipairs(shortcuts) do
			if sh == "" then
				shortcuts[i] = false
			end
		end
	end
	return shortcuts
end

---
--- Opens the start button in the game's UI.
---
--- This function tries to find the start button in various UI dialogs, such as the PDA dialog, the satellite dialog, and the in-game interface mode dialog. If the start button is found and visible, it is pressed.
---
--- @return nil
function OpenStartButton()
	local startBut

	local satDiag = GetDialog("PDADialogSatellite")
	satDiag = satDiag and satDiag.idContent
	
	local pda = GetDialog("PDADialog")
	pda = pda and pda.idContent
	local browser = pda and pda.idBrowserContent
	pda = browser or pda
	
	local inventoryUI = GetDialog("FullscreenGameDialogs")

	if pda then
		startBut = pda:ResolveId("idStartButton")
	elseif inventoryUI then
		startBut = inventoryUI.idStartButton
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	elseif satDiag then
		-- Don't allow opening of the command menu while selecting a travel destination.
		-- This is doable via gamepad and steals the focus away.
		if g_SatelliteUI and g_SatelliteUI.travel_mode then return end
	
		startBut = satDiag:ResolveId("idStartButton")
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	else
		local igi = GetInGameInterfaceModeDlg()
		startBut = igi and igi:ResolveId("idStartButton")
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	end

	if not startBut or not startBut:IsVisible() then return end
	startBut:OnPress()
end

---
--- Inverts a given percentage value.
---
--- @param context_obj any The context object (unused).
--- @param value number The percentage value to invert.
--- @return number The inverted percentage value.
---
function TFormat.PercentInvert(context_obj, value)
	if not value then return 0 end
	return 100 - value
end

-- Version of this command that works with the Unit class and our voxel system
---
--- Teleports a group of actors near a destination actor within a specified radius.
---
--- @param state table The current game state.
--- @param Actors string The name of the actors to teleport.
--- @param DestinationActor string The name of the destination actor.
--- @param Radius number The radius around the destination actor to teleport the actors within.
--- @param Face boolean Whether the actors should face the destination actor after teleporting.
--- @return nil
function SetpieceTeleportNear:Exec(state, Actors, DestinationActor, Radius, Face)
	if Actors == "" or DestinationActor=="" then return end
	
	local ptCenter = GetWeightPos(DestinationActor)
	local ptActors = GetWeightPos(Actors)
	local base_angle = #DestinationActor > 0 and DestinationActor[1]:GetAngle()
	
	if ptCenter:Dist(ptActors) < Radius * guim then return end
	
	local radiusBbox = GetVoxelBBox(ptCenter, Radius, "with_z")
	local dest_pos = false
	ForEachPassSlab(radiusBbox, function(x, y, z)
		if z == ptCenter:z() and not IsOccupiedExploration(nil, x, y, z) then
			local p = point(x, y, z)
			if not dest_pos or IsCloser(p, ptCenter, dest_pos) then
				dest_pos = p
			end
		end
	end)
	if not dest_pos then return end
	
	if not ptActors:IsValidZ() then
		ptActors = ptActors:SetTerrainZ()
	end

	local base_angle = #Actors > 0 and Actors[1]:GetAngle()
	for _, actor in ipairs(Actors) do
		local pos = actor:GetVisualPos()
		local offset = Rotate(pos - ptActors, actor:GetAngle() - base_angle)
		local dest = actor:GetPos() + offset		
		actor:SetAcceleration(0)
		actor:SetPos(dest_pos, 0)
		if IsKindOf(actor, "Unit") then
			actor:SetTargetDummy(false)
		end
		if Face then
			actor:Face(ptCenter)
		end
	end
end

---
--- Handles the action of going to a sub-menu.
---
--- @param self table The current object.
--- @param host table The host object.
--- @param source table The source object.
--- @param ... any Additional arguments.
---
--- @return nil
function GoToSubMenu_OnAction(self, host, source, ...)
	if self:ActionState() == "enabled" then
		local subMenuList = host:ResolveId("idSubMenu"):ResolveId("idScrollArea")
		if subMenuList then
			subMenuList:SelectFirstValidItem()
		end
	end
end

---
--- Checks the action state of the GoToSubMenu function.
---
--- @param self table The current object.
--- @param host table The host object.
---
--- @return string The action state, either "enabled" or "disabled".
function GoToSubMenu_ActionState(self, host)
	local dlg = GetDialog(terminal.desktop.keyboard_focus)
	local focusOnMMButton = dlg.Id == "idMainMenuButtonsContent" 
	return focusOnMMButton and "enabled" or "disabled"
end

-- Used for quests or custom stuff where the player has to pick a merc.
---
--- Opens a dialog to allow the user to choose a merc.
---
--- @param text string The text to display in the dialog header.
---
--- @return table The selected merc.
function UIChooseMerc(text)
	assert(CanYield())
	local dlg = OpenDialog("MercSelectionDialog", GetInGameInterface())
	dlg.idHeaderText:SetText(text)
	return dlg:Wait()
end

DefineConstInt("Default", "InteractionActionProgressBarTime", 1500, false, "The time it takes for the interaction progress bar to fill up in milliseconds")

---
--- Spawns a progress bar UI element that fills up over time.
---
--- @param time number The duration of the progress bar in milliseconds.
--- @param text string The text to display on the progress bar.
---
--- @return table The spawned progress bar UI element.
function SpawnProgressBar(time, text)
	local bar = XTemplateSpawn("InteractionProgressBar", GetInGameInterface())
	bar.idBar:SetTimeProgress(GameTime(), GameTime() + time, true)
	bar:Open()
	bar:CreateThread("after", function()
		Sleep(time + 10)
		bar:Close()
	end)
	return bar;
end

---
--- Closes the options choice submenu.
---
--- @param ui table The UI object.
---
function CloseOptionsChoiceSubmenu(ui)
	local dialog = GetDialog(ui):ResolveId("idSubSubContent")
	local choiceProp = GetDialogModeParam(dialog)
	if choiceProp then
		if choiceProp.idImgBcgrSelected then 
			choiceProp.idImgBcgrSelected:SetVisible(false)
		end
		choiceProp.isExpanded = false
	end
	dialog:SetMode("empty")
	GetDialog(ui):ResolveId("idSubMenu"):ResolveId("idScrollArea"):SetMouseScroll(true)
end

---
--- Returns the translated display name of the current campaign.
---
--- @return string The translated campaign name.
function GetCampaignNameTranslated()
	local campaign = DefaultCampaign or "HotDiamonds"											
	local dName = CampaignPresets[campaign] and CampaignPresets[campaign].DisplayName
	local campaignName = _InternalTranslate(dName)
	return campaignName
end

local function RecreateTags()
const.TagLookupTable["ButtonASmall"]   = GetPlatformSpecificImageTag("ButtonA", 650) 
const.TagLookupTable["ButtonBSmall"]   = GetPlatformSpecificImageTag("ButtonB", 650) 
const.TagLookupTable["ButtonYSmall"]   = GetPlatformSpecificImageTag("ButtonY", 650) 
const.TagLookupTable["ButtonXSmall"]   = GetPlatformSpecificImageTag("ButtonX", 650)

const.TagLookupTable["ButtonAHold"]   = T{944700099636, "<img>(Hold)",img = GetPlatformSpecificImageTag("ButtonA") }
const.TagLookupTable["ButtonASmallHold"]   = T{944700099636, "<img>(Hold)",img = GetPlatformSpecificImageTag("ButtonA", 650) }
end

function OnMsg.OnControllerTypeChanged()
	RecreateTags()
end

OnMsg.XInputInitialized = RecreateTags

RecreateTags()

-- Requirements are for these to be the same size as other gamepad buttons. (219357)
local smallerButtons = {
	["rsup"] = true,
	["rsdown"] = true,
	["rsright"] = true,
	["rsleft"] = true,
	
	["lsup"] = true,
	["lsdown"] = true,
	["lsright"] = true,
	["lsleft"] = true,
}


local commonGetPlatformSpecificImageTag = GetPlatformSpecificImageTag
---
--- Returns a platform-specific image tag for the given button and optional scale.
---
--- @param btn string The name of the button.
--- @param scale number The scale of the image tag (optional).
--- @return string The platform-specific image tag.
function GetPlatformSpecificImageTag(btn, scale)
	if smallerButtons[btn] and not scale then
		scale = 516
	end

	return commonGetPlatformSpecificImageTag(btn, scale)
end
RecreateButtonsTagLookupTable()

---
--- Finds a set of free passable positions around a given position.
---
--- @param pos table The starting position, as a table with x, y, and z fields.
--- @param count number The number of positions to find.
--- @param max_radius number The maximum radius to search within.
--- @param seed number A seed value for the random number generator.
--- @return table A list of positions, as tables with x, y, and z fields.
---
function DbgFindFreePassPositions(pos, count, max_radius, seed)
	local result = {}
	local x0, y0, z0 = VoxelToWorld(WorldToVoxel(pos))
	local result = {}

	for i = 1 + (sqrt(count) - 1) / 2, max_radius do
		local r = i * const.SlabSizeX
		ForEachPassSlab(box(x0 - r, y0 - r, 0, x0 + r + 1, y0 + r + 1, 100000), function(x, y, z, result)
			local p = point_pack(x, y, z)
			if not result[p] and CanDestlock(point(x,y,z), 1) then
				table.insert(result, p)
				result[p] = true
			end
		end, result)
		if #result >= count then
			local list = {}
			for i = 1, count do
				local idx
				idx, seed = BraidRandom(seed, #result)
				idx = idx + 1
				list[i] = point(point_unpack(result[idx]))
				result[idx] = result[#result]
				result[#result] = nil
			end
			return list
		end
	end
end

local dbgStartExplorationSpamGuard = false
---
--- Starts the debug exploration mode, which allows testing the exploration logic.
---
--- @param map string (optional) The name of the map to use for the exploration test. If not provided, the current map will be used.
--- @param units table (optional) A table of unit names to use as the player's party. If not provided, a default party of "Ivan", "Vicki", and "Buns" will be used.
---
function DbgStartExploration(map, units)
	DbgStopCombat()
	if map and map ~= GetMapName() then
		CreateRealTimeThread(function(map, units)
			ChangeMap(map)
			DbgStartExploration(map, units)
		end, map, units)
		return
	end
	
	if not mapdata.GameLogic then
		print("This map doesn't have game logic enabled, therefore you cannot test on it.")
		return
	end
	
	if dbgStartExplorationSpamGuard and RealTime() - dbgStartExplorationSpamGuard < 50 then
		return
	end
	
	dbgStartExplorationSpamGuard = RealTime()

	-- link debug exploration to satellite sector
	if not HasGameSession() then
		NewGameSession(nil, {KeepUnitData = true})
	end
	local dbg_sector = next(gv_Sectors)
	if not dbg_sector then
		print("No available sector in gv_Sectors to use as a test.")
		return
	end
	gv_Sectors[dbg_sector].Map = map or GetMapName()
	gv_CurrentSectorId = dbg_sector
	g_TestExploration = true
		
	local party = units or { "Ivan", "Vicki", "Buns" }
	local p = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local pts = DbgFindFreePassPositions(p, #party, 20, xxhash(p))
	if not pts then
		print("Can't find passable point.")
		return
	end
	SetupTeamsFromMap()
	local player1_team = table.find_value(g_Teams, "side", "player1")
	for i, class in ipairs(party) do
		gv_UnitData[class] = CreateUnitData(class, class, 0)
		local unit = g_Units[class] or SpawnUnit(class, class, pts[i])
		SendUnitToTeam(unit, player1_team)
	end

	CreateNewSatelliteSquad({Side = "player1", CurrentSector = dbg_sector, Name = "GAMETEST"},party, 14, 1234567)

	if not g_Exploration then StartExploration() end
	if not g_AmbientLifeSpawn then
		AmbientLifeToggle()
	end
	gv_InitialHiringDone = true
	Msg("DbgStartExploration")
end

function OnMsg.CanSaveGameQuery(query)
	query.test_exploration = g_TestExploration or nil
end

--- Removes the villain status from a given unit.
---
--- This function is used to reset the villain status of a unit, including its villain, villain_defeated, immortal, DefeatBehavior, and invulnerable properties. It also ensures that the unit's command is set to "Idle" if it was previously set to "VillainDefeat".
---
--- @param boss table The unit data for the boss unit.
function MakeUnitNonVillain(boss)
	local bossUnit = not gv_SatelliteView and g_Units[boss.session_id]
	if bossUnit then
		bossUnit.villain = false
		bossUnit.villain_defeated = false
		bossUnit.immortal = false
		bossUnit.DefeatBehavior = false
		bossUnit.invulnerable = false
		
		if bossUnit.command == "VillainDefeat" then
			bossUnit:SetCommand("Idle")
		end
	end
	
	local bossUD = gv_UnitData[boss.session_id]
	if bossUD then
		bossUD.villain = false
		bossUD.villain_defeated = false
		bossUD.immortal = false
		bossUD.DefeatBehavior = false
	end
	
	-- ughhh just in case
	if boss ~= bossUD and boss ~= bossUnit then
		boss.villain = false
		boss.villain_defeated = false
		boss.immortal = false
		boss.DefeatBehavior = false
	end
end

--- Finds the nearest parent window of the given class, traversing up the window hierarchy.
---
--- This function is used to find the nearest parent window of the specified class, starting from the given window and traversing up the window hierarchy. If the window has a `popup_parent` property, it will be checked first, otherwise the `parent` property will be checked.
---
--- @param win table The window to start the search from.
--- @param class string The class to search for.
--- @return table|nil The nearest parent window of the specified class, or `nil` if not found.
function GetParentOfKindPopupAware(win, class)
	while win and not IsKindOf(win, class) do
		if win.popup_parent then
			win = win.popup_parent
		else
			win = win.parent
		end
	end
	return win
end

-- Disable button pressing using Enter.
-- It's weird and prevents the dev console from opening.
local old = XButton.OnShortcut
--- Overrides the default behavior of the `XButton` class's `OnShortcut` method to prevent the "Enter" key from triggering the developer console.
---
--- This function is called when a shortcut key is pressed on the `XButton` instance. If the shortcut is the "Enter" key, and the button is not part of the "DeveloperInterface" window hierarchy, the function will return without calling the original `OnShortcut` method. Otherwise, it will call the original `OnShortcut` method with the provided arguments.
---
--- @param shortcut string The name of the shortcut key that was pressed.
--- @param source table The object that triggered the shortcut.
--- @param ... any Additional arguments passed to the `OnShortcut` method.
--- @return any The return value of the original `OnShortcut` method, if it was called.
function XButton:OnShortcut(shortcut, source, ...)
	if shortcut == "Enter" then
		if not Platform.developer or not GetParentOfKindPopupAware(self, "DeveloperInterface") then
			return
		end
	end
	return old(self, shortcut, source, ...)
end

DefineClass.XContextWindowVisibleReasons = {
	__parents = { "XContextWindow" },
	
	visible_reasons = false
}

--- Initializes the `visible_reasons` table for the `XContextWindowVisibleReasons` class.
---
--- The `visible_reasons` table is used to track the visibility state of the window for different reasons. By default, the `"logic"` reason is set to `true`, indicating that the window should be visible based on the application's logic.
---
--- @param self table The `XContextWindowVisibleReasons` instance.
function XContextWindowVisibleReasons:Init()
	self.visible_reasons = {
		["logic"] = true
	}
end

--- Sets the visibility of the window based on the specified visibility reason.
---
--- This method updates the `visible_reasons` table to reflect the new visibility state for the specified reason. It then checks if all visibility reasons are `true`, and sets the overall visibility of the window accordingly.
---
--- @param self table The `XContextWindowVisibleReasons` instance.
--- @param visible boolean The new visibility state.
--- @param reason string (optional) The reason for the visibility change. Defaults to `"logic"`.
--- @param instant boolean (optional) If `true`, the visibility change will be instant, without any animation.
--- @return boolean The new visibility state of the window.
function XContextWindowVisibleReasons:SetVisible(visible, reason, instant)
	reason = reason or "logic"
	if self.visible_reasons[reason] == visible then return end
	
	self.visible_reasons[reason] = visible
	local show = true
	for reason, v in pairs(self.visible_reasons) do
		if not v then
			show = false
			break
		end
	end
	
	if show == self.visible then return end
	return XContextWindow.SetVisible(self, visible, instant)
end

table.insert(XFitContent.properties, { id = "UseMeasureCache", editor = "bool", default = true })

-- Optimized version of XFitContent's UpdateMeasure that uses
-- a cache to reduce remeasures
local one = point(1000, 1000)
---
--- Optimized version of `XFitContent`'s `UpdateMeasure` that uses a cache to reduce remeasures.
---
--- This function is responsible for updating the measure of an `XFitContent` control, taking into account the specified maximum width and height. It uses a cache to avoid unnecessary remeasures, improving performance.
---
--- @param self table The `XFitContent` instance.
--- @param max_width number The maximum width available for the control.
--- @param max_height number The maximum height available for the control.
--- @return none
function XFitContent:UpdateMeasure(max_width, max_height)
	if not self.measure_update then return end
	local fit = self.Fit
	if fit == "none"  then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	
	if self.cached_data and self.UseMeasureCache then
		-- Check if the cache is still valid
		local cached_data = self.cached_data
		local chMW = cached_data[1]
		local chMH = cached_data[2]
		local chFit = cached_data[3]
		if chMW == max_width and chMH == max_height and chFit == fit then
			local scaleX = cached_data[4]
			local scaleY = cached_data[5]
		
			self:SetScaleModifier(point(scaleX, scaleX))
			XControl.UpdateMeasure(self, max_width, max_height)
			return
		end
	end
	
	for _, child in ipairs(self) do
		child:SetOutsideScale(one)
	end
	self.scale = one
	XControl.UpdateMeasure(self, 1000000, 1000000)
	local content_width, content_height = ScaleXY(self.parent.scale, self.measure_width, self.measure_height)
	assert(content_width > 0 and content_height > 0)
	if content_width == 0 or content_height == 0 then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	if fit == "smallest" or fit == "largest" then
		local space_is_wider = max_width * content_height >= max_height * content_width
		fit = space_is_wider == (fit == "largest") and "width" or "height"
	end
	local scale_x = max_width * 1000 / content_width
	local scale_y = max_height * 1000 / content_height
	if fit == "width" then
		scale_y = scale_x
	elseif fit == "height" then
		scale_x = scale_y
	end
	self:SetScaleModifier(point(scale_x, scale_y))
	XControl.UpdateMeasure(self, max_width, max_height)
	
	self.cached_data = {
		max_width,
		max_height,
		self.Fit,
		scale_x,
		scale_y
	}
end

---
--- Sets the test gamepad UI platform.
---
--- @param platform string The platform to set the test gamepad UI to.
---
function SetTestGamepadUIPlatform(platform)
	ChangeGamepadUIStyle({ false })
	g_PCActiveControllerType = false
	g_TestUIPlatform = platform
	RecreateButtonsTagLookupTable()
	UpdateActiveControllerType()
	ChangeGamepadUIStyle({ true })
end

DefineClass.XTextButtonZulu = {
	__parents = { "XTextButton" }
}

---
--- Sets the selected state of the XTextButtonZulu control.
---
--- @param selected boolean Whether the button should be selected or not.
---
function XTextButtonZulu:SetSelected(selected)
	if selected then
		self:SetFocus(true)
	end

	if not selected and self.state == "pressed-out" then
		self:OnButtonUp(false, true)
	end
end

---
--- Checks if the XTextButtonZulu control is selectable.
---
--- @return boolean Whether the button is selectable or not.
---
function XTextButtonZulu:IsSelectable()
	return self:GetEnabled()
end

---
--- Sets the rollover state of the XTextButtonZulu control.
---
--- @param rollover boolean Whether the button is in a rollover state or not.
---
function XTextButtonZulu:OnSetRollover(rollover)
	XTextButton.OnSetRollover(self, rollover)
	if not rollover and self.state == "pressed-out" then
		self:OnButtonUp(false, true)
	end
end

---
--- Inverts the direction of the PDA thumbstick controls based on the user's preference.
---
--- @param shortcut string The input shortcut to be inverted.
--- @return string The inverted shortcut.
---
function GetInvertPDAThumbsShortcut(shortcut)
	local shrct = shortcut
	if GetAccountStorageOptionValue("InvertPDAThumbs") then
		local leftIdx = table.find(XInput.LeftThumbDirectionButtons, shrct)
		local rightIdx = table.find(XInput.RightThumbDirectionButtons, shrct)
		if leftIdx then
			shrct = XInput.RightThumbDirectionButtons[leftIdx]
		elseif rightIdx then
			shrct = XInput.LeftThumbDirectionButtons[rightIdx]
		end
	end
	return shrct
end	

local commonActionHostOnShortcut = XActionsHost.OnShortcut
---
--- Invokes the common OnShortcut handler, but first checks if the shortcut is a TouchPad click and remaps it to the Back button if so. It also inverts the PDA thumbstick controls based on the user's preference.
---
--- @param shortcut string The input shortcut.
--- @param source any The source of the shortcut.
--- @param ... any Additional arguments passed to the common OnShortcut handler.
--- @return any The result of the common OnShortcut handler.
---
function XActionsHost:OnShortcut(shortcut, source, ...)	
	if shortcut == "+TouchPadClick" then shortcut = "+Back"
	elseif shortcut == "TouchPadClick" then shortcut = "Back"
	elseif shortcut == "-TouchPadClick" then shortcut = "-Back" end

	shortcut = GetInvertPDAThumbsShortcut(shortcut)
	
	return commonActionHostOnShortcut(self, shortcut, source, ...)
end

local commonIsCtrlButtonPressed = XInput.IsCtrlButtonPressed
---
--- Checks if a gamepad control button is pressed, taking into account the user's preference to swap the left and right triggers.
---
--- @param id number The controller ID.
--- @param shortcut string The input shortcut to check.
--- @param ... any Additional arguments to pass to the common IsCtrlButtonPressed function.
--- @return boolean True if the control button is pressed, false otherwise.
---
function XInput.IsCtrlButtonPressed(id, shortcut, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if shortcut == "LeftTrigger" then
			shortcut = "RightTrigger"
		elseif shortcut == "RightTrigger" then
			shortcut = "LeftTrigger"
		end
	end
	return commonIsCtrlButtonPressed(id, shortcut, ...)
end

local commonXInputShortcut = XInputShortcut
---
--- Checks if a gamepad control button is pressed, taking into account the user's preference to swap the left and right triggers.
---
--- @param button string The input shortcut to check.
--- @param controller_id number The controller ID.
--- @return boolean True if the control button is pressed, false otherwise.
---
function XInputShortcut(button, controller_id)
	if not GetAccountStorageOptionValue("GamepadSwapTriggers") then
		return commonXInputShortcut(button, controller_id)
	end
	
	if button == "LeftTrigger" then
		button = "RightTrigger"
	elseif button == "RightTrigger" then
		button = "LeftTrigger"
	end
	return commonXInputShortcut(button, controller_id)
end

local commonGetPlatformSpecificImageName = GetPlatformSpecificImageName
---
--- Gets the platform-specific image name for the given button, taking into account the user's preference to swap the left and right triggers.
---
--- @param button string The input button.
--- @param ... any Additional arguments to pass to the common GetPlatformSpecificImageName function.
--- @return string The platform-specific image name.
---
function GetPlatformSpecificImageName(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImageName(button, ...)
end

local commonGetPlatformSpecificImagePath = GetPlatformSpecificImagePath
---
--- Gets the platform-specific image path for the given button, taking into account the user's preference to swap the left and right triggers.
---
--- @param button string The input button.
--- @param ... any Additional arguments to pass to the common GetPlatformSpecificImagePath function.
--- @return string The platform-specific image path.
---
function GetPlatformSpecificImagePath(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImagePath(button, ...)
end

local commonGetPlatformSpecificImageTag = GetPlatformSpecificImageTag
---
--- Gets the platform-specific image tag for the given button, taking into account the user's preference to swap the left and right triggers.
---
--- @param button string The input button.
--- @param ... any Additional arguments to pass to the common GetPlatformSpecificImageTag function.
--- @return string The platform-specific image tag.
---
function GetPlatformSpecificImageTag(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImageTag(button, ...)
end

if FirstLoad then
CheckForConflictingBinding_Checked = false
end

function OnMsg.AccountStorageLoaded()
	CheckForConflictingBinding_Checked = false
end

function OnMsg.ShortcutsReloaded()
	if not CheckForConflictingBinding_Checked then
		CheckForConflictingBinding()
		CheckForConflictingBinding_Checked = true
	end
end

---
--- Checks for conflicting key bindings in the game's options and resolves them.
---
--- This function is called when the game's shortcuts are reloaded, such as after a game update.
--- It checks all the key bindings defined in the options and looks for any conflicts where two
--- different actions are bound to the same key. If any conflicts are found, it will automatically
--- unbind the conflicting keys and display a message to the player informing them of the changes.
---
--- @return nil
---
function CheckForConflictingBinding()
	if not Platform.desktop then return end

	local optionsObj = OptionsObj or OptionsCreateAndLoad()
	local optionEntries = optionsObj:GetProperties()
	local bindings = table.ifilter(optionEntries, function(_, o) return o.category == "Keybindings" end)

	local conflicts = {}
	for _, binding1 in ipairs(bindings) do
		local shortcutsFor1 = optionsObj[binding1.id] or empty_table
	
		for _, binding2 in ipairs(bindings) do
			if binding1 == binding2 then goto continue end
			if binding1.id == binding2.id then goto continue end
			
			-- Check if using the same shortcut.
			local shortcutsFor2 = optionsObj[binding2.id] or empty_table
			local conflictingShortcut = false
			for _, sh1 in ipairs(shortcutsFor1) do
				for _, sh2 in ipairs(shortcutsFor2) do
					conflictingShortcut = sh1 == sh2
					if conflictingShortcut then break end
				end
			end
				
			if not conflictingShortcut then goto continue end
			if not EnabledInModes(binding1.mode, binding2.mode) then goto continue end
			
			-- Collect conflicting bindings.
			-- (there are actions with duplicate ids sp we use ids)
			local binding1Id = binding1.id
			local binding2Id = binding2.id
			
			local existInReverse = conflicts[binding2Id]
			if existInReverse and table.find(existInReverse, binding1Id) then goto continue end
			
			local conflictListForMe = conflicts[binding1Id] or {}
			conflicts[binding1Id] = conflictListForMe
			if table.find(conflictListForMe, binding2Id) then goto continue end
			conflictListForMe[#conflictListForMe + 1] = binding2Id
			
			::continue::
		end
	end
	
	local unboundShortcuts = {}
	for con, conList in pairs(conflicts) do
		local data1 = table.ifilter(bindings, function(_, o) return o.id == con end)
		local defs1 = {}
		for i, d in ipairs(data1) do
			table.iappend(defs1, d.default)
		end
		local shortcutsFor1 = optionsObj[con] or empty_table
	
		for i, con2 in ipairs(conList) do
			-- Find which one of the two is the default binding (if any)
			local data2 = table.ifilter(bindings, function(_, o) return o.id == con2 end)
			local defs2 = {}
			for i, d in ipairs(data2) do
				table.iappend(defs2, d.default)
			end
			local shortcutsFor2 = optionsObj[con2] or empty_table
			
			local defaultIs1, defaultIs2 = false, false
			for _, sh1 in ipairs(shortcutsFor1) do
				for _, sh2 in ipairs(shortcutsFor2) do
					if sh1 == sh2 then
						defaultIs1 = not not table.find(defs1, sh1)
						defaultIs2 = not not table.find(defs2, sh2)
						break
					end
				end
			end
			
			if (defaultIs1 and not defaultIs2) or (defaultIs2 and not defaultIs1) then
				if defaultIs1 then
					unboundShortcuts[#unboundShortcuts + 1] = con
					optionsObj:SetProperty(con, {""})
				else
					unboundShortcuts[#unboundShortcuts + 1] = con2
					optionsObj:SetProperty(con2, {""})
				end
			end
		end
	end
	
	local unboundActionsDisplayNames = {}
	for i, sh in ipairs(unboundShortcuts) do
		local binding = table.find_value(bindings, "id", sh)
		unboundActionsDisplayNames[#unboundActionsDisplayNames + 1] = binding.name
	end
	
	if #unboundActionsDisplayNames > 0 then
		optionsObj:SaveToTables()
		ReloadShortcuts()
	
		local popupText = T{515533608396, "A game update has added new key bindings that conflict with your personalized bindings. The new key bindings have been removed.<newline>To assign buttons to these new actions go to the Keybindings section in the Options menu and look for the following: <newline><newline><actions>",
			actions = table.concat(unboundActionsDisplayNames, ", ")
		}
		CreateMessageBox(terminal.desktop, T(498221418682, "Information"), popupText)
	end
end

if FirstLoad then
ui_TimeSinceTurnStarted = false
ui_SuppressNextEndTurnAnimation = false
ui_EndTurnAnimationDuration = 500

ui_FastForwardButtonAnimationStarted = false
ui_FastForwardButtonShown = false
ui_FastForwardButtonSlideDownAfter = 3000
end

function OnMsg.TurnStart(team)
	if ui_SuppressNextEndTurnAnimation then
		ui_SuppressNextEndTurnAnimation = false
		return
	end

	local teamData = g_Teams[team]
	if teamData and teamData.player_team then
		ui_TimeSinceTurnStarted = GetPreciseTicks()
		ui_FastForwardButtonAnimationStarted = false
	elseif not ui_FastForwardButtonAnimationStarted then -- Reset animation on player turn only.
		ui_FastForwardButtonAnimationStarted = GetPreciseTicks()
	end
	ObjModified("EndTurnAnimation")
end

function OnMsg.RepositionEnd()
	ui_TimeSinceTurnStarted = GetPreciseTicks()
	ObjModified("EndTurnAnimation")
	ui_SuppressNextEndTurnAnimation = true
end

---
--- Checks if the end turn animation has passed.
---
--- @return boolean true if the end turn animation has passed, false otherwise
function HasEndTurnAnimationPassed() -- pepega
	if not ui_TimeSinceTurnStarted then return true end
	--if ui_FastForwardButtonAnimationStarted then return false end
	if GetPreciseTicks() - ui_TimeSinceTurnStarted > ui_EndTurnAnimationDuration then return true end
	return false
end

---
--- Checks if the game's in-game menu blur rect should be shown.
---
--- The blur rect is used to provide a blurred background for certain in-game dialogs.
--- This function checks if any of the specified dialogs are currently open, and returns
--- true if the blur rect should be shown, false otherwise.
---
--- @return boolean true if the blur rect should be shown, false otherwise
function ShowInGameMenuBlurRect()
	if GetDialog("PDADialog") then return false end
	if GetDialog("PDADialogSatellite") then return false end
	if GetDialog("ConversationDialog") then return false end
	if GetDialog("FullscreenGameDialogs") then return false end
	return true
end

---
--- Calculates the target rect for an end turn animation window.
---
--- This function is called when the layout of the end turn animation window is complete.
--- It calculates the target rect for the window, which is used to animate the window
--- to the bottom of the screen.
---
--- @param interp The interpolation object for the animation.
--- @param window The end turn animation window.
---
function EndTurnAnimationOnLayoutComplete(interp, window)
	local dlg = GetDialog(window)
	local bottom = dlg.box:maxy()
	local distanceToBottomFromMe = bottom - window.box:miny()
	
	interp.targetRect = sizebox(0, distanceToBottomFromMe, 1000, 1000)
end

---
--- Checks if a status effect has expired on a target.
---
--- This function checks if the duration of a status effect has been exceeded, and removes the effect from the target if it has.
---
--- @param effect The status effect to check.
--- @param target The target of the status effect.
--- @param timer The timer used to track the start time of the effect.
---
function Conscience_CheckExpiration(effect, target, timer)
	local duration = effect:ResolveValue("days")
	local startTime = effect:ResolveValue(timer) or 0

	local dayStarted = GetTimeAsTable(startTime)
	dayStarted = dayStarted and dayStarted.day

	local dayNow = GetTimeAsTable(Game.CampaignTime)
	dayNow = dayNow and dayNow.day

	-- Intentionally check if days have passed calendar, and not time wise.
	if dayNow - dayStarted >= duration then
		target:RemoveStatusEffect(effect.class)
	end
end

---
--- Applies a modifier to a data table, adding the specified value to the `mod_add` field.
--- If the `modifiers` field exists in the data table, a new modifier entry is added with the
--- specified effect class, value, display name, and meta text.
---
--- @param effect The status effect that is applying the modifier.
--- @param data The data table to apply the modifier to.
--- @param value The value to add to the `mod_add` field.
--- @param text The display name for the modifier (optional).
--- @param meta_text Additional meta text for the modifier (optional).
---
function ApplyCthModifier_Add(effect, data, value, text, meta_text)
	data.mod_add = data.mod_add + value
	if data.modifiers then
		data.modifiers[#data.modifiers + 1] = {
			id = effect.class, 
			value = value,
			name = text or effect.DisplayName, 
			metaText = meta_text,
		}
	end
end

---
--- Converts a table of constant values into a combo box list.
---
--- This function takes a table of constant values and converts it into a list of key-value pairs suitable for use in a combo box UI element.
---
--- @param constList The table of constant values to convert.
--- @return A table of key-value pairs representing the combo box list.
---
function ConstCategoryToCombo(constList)
	local res = {}
	for k,v in pairs(constList) do
		res[#res+1] = { k, v }
	end
	table.sortby_field(res, 2)
	return table.map(res, 1)
end

---
--- Iterates over all presets of the specified class that are related to the current campaign.
---
--- This function iterates over all presets of the specified class and calls the provided function for each preset that is related to the current campaign. The function will be called with the following arguments:
---
--- - `preset`: The preset object.
--- - `group`: The group that the preset belongs to.
--- - `...`: Any additional arguments passed to the function.
---
--- If the function returns the string `"break"`, the iteration will be stopped and the function will return the additional arguments passed to it.
---
--- @param class The class of the presets to iterate over.
--- @param func The function to call for each preset.
--- @param ... Any additional arguments to pass to the function.
--- @return The additional arguments passed to the function, or nil if the iteration was stopped.
---
function ForEachPresetInCampaign(class, func, ...)
	class = g_Classes[class] or class
	class = class.PresetClass or class.class
	for group_index, group in ipairs(Presets[class]) do
		for preset_index, preset in ipairs(group) do
			local id = preset.id
			local presetCampaign = preset.campaign
			if not presetCampaign then
				assert(presetCampaign, "TODO: (maybe no assert just treat them as true)Do not use this function for non-campaign related presets.")
				return ...
			end
			local campaignRelated = preset.campaign == "<all>" or GetCurrentCampaignPreset().id == preset.campaign
			if (id == "" or group[id] == preset) and not preset.Obsolete and campaignRelated then
				if func(preset, group, ...) == "break" then
					return ...
				end
			end
		end
	end
	return ...
end

---
--- Iterates over all presets of the specified class that are related to the current campaign and belong to the specified group.
---
--- This function iterates over all presets of the specified class that belong to the specified group and calls the provided function for each preset that is related to the current campaign. The function will be called with the following arguments:
---
--- - `preset`: The preset object.
--- - `group`: The group that the preset belongs to.
--- - `...`: Any additional arguments passed to the function.
---
--- If the function returns the string `"break"`, the iteration will be stopped and the function will return the additional arguments passed to it.
---
--- @param class The class of the presets to iterate over.
--- @param group The group of the presets to iterate over.
--- @param func The function to call for each preset.
--- @param ... Any additional arguments to pass to the function.
--- @return The additional arguments passed to the function, or nil if the iteration was stopped.
---
function ForEachPresetInCampaignAndGroup(class, group, func, ...)
	if type(class) == "table" then
		class = class.PresetClass or class.class
	end
	group = (Presets[class] or empty_table)[group]
	for preset_index, preset in ipairs(group) do
		local campaignRelated = preset.campaign == "<all>" or GetCurrentCampaignPreset().id == preset.campaign
		if group[preset.id] == preset and not preset.Obsolete and campaignRelated then
			if func(preset, group, ...) == "break" then
				return ...
			end
		end
	end
	return ...
end

---
--- Iterates over all presets of the specified class that are related to the current campaign and returns an array of those presets.
---
--- This function iterates over all presets of the specified class that are related to the current campaign and calls the provided function for each preset. The function will be called with the following arguments:
---
--- - `preset`: The preset object.
--- - `group`: The group that the preset belongs to.
--- - `presets`: The array to add the preset to.
--- - `func`: The function to call for each preset (optional).
--- - `...`: Any additional arguments passed to the function.
---
--- If the function returns `true`, the preset will be added to the `presets` array. If no function is provided, all presets will be added to the array.
---
--- @param class The class of the presets to iterate over.
--- - `func` The function to call for each preset (optional).
--- - `...` Any additional arguments to pass to the function.
--- @return The array of presets related to the current campaign.
---
function PresetsInCampaignArray(class, func, ...)
	return ForEachPresetInCampaign(class, function(preset, group, presets, func, ...)
		if not func or func(preset, group, ...) then
			presets[#presets + 1] = preset
		end
	end, {}, func, ...)
end

---
--- Iterates over all presets of the specified class that are related to the current campaign and returns an array of those presets.
---
--- This function iterates over all presets of the specified class that are related to the current campaign and calls the provided function for each preset. The function will be called with the following arguments:
---
--- - `preset`: The preset object.
--- - `group`: The group that the preset belongs to.
--- - `presets`: The array to add the preset to.
--- - `func`: The function to call for each preset (optional).
--- - `...`: Any additional arguments passed to the function.
---
--- If the function returns `true`, the preset will be added to the `presets` array. If no function is provided, all presets will be added to the array.
---
--- @param class The class of the presets to iterate over.
--- @param input_group The group of the presets to iterate over.
--- @param func The function to call for each preset (optional).
--- @param ... Any additional arguments to pass to the function.
--- @return The array of presets related to the current campaign.
---
function PresetsGroupInCampaignArray(class, input_group, func, ...)
	return ForEachPresetInCampaignAndGroup(class, input_group, function(preset, group, presets, func, ...)
		if not func or func(preset, group, ...) then
			presets[#presets + 1] = preset
		end
	end, {}, func, ...)
end