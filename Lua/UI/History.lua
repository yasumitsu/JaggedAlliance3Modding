GameVar("gv_HistoryOccurences", {})
--[[
	{
		id = "string", 	#id of the HistoryOccurence preset
		time = number 	#time when the HistoryOccurence is received (Game.CampaignTime)
		context = {}		#context for repeatable events
	}
]]

-- Occurences are sorted by game time

---
--- Logs a history occurrence with the given preset ID and context.
---
--- @param presetId string The ID of the history occurrence preset.
--- @param context table The context for the history occurrence.
---
function LogHistoryOccurence(presetId, context)
	if not HistoryOccurences[presetId] or not HistoryOccurences[presetId]:IsRelatedToCurrentCampaign() then return end
	local function MergeWith(idx, occurence)
		local context = gv_HistoryOccurences[idx].context
		if type(context) ~= "table" then
			gv_HistoryOccurences[idx].context = {}
			gv_HistoryOccurences[idx].context[1] = context
			gv_HistoryOccurences[idx].context[2] = occurence.context
		else
			table.insert(gv_HistoryOccurences[idx].context, occurence.context)
		end
	end
	
	local occurence = {
		id = presetId,
		time = Game.CampaignTime,
		context = context
	}
	local mergeableOccurence = presetId == "MercHire" or presetId == "MercContractExpired" or presetId == "MercContractExtended" or presetId == "ActivityFinished"
	for idx, occ in ipairs(mergeableOccurence and gv_HistoryOccurences or empty_table) do
		if occ.id == occurence.id and occ.time == occurence.time then
			MergeWith(idx, occurence)
			return
		end
	end
	gv_HistoryOccurences[#gv_HistoryOccurences+1] = occurence
end

---
--- Returns a list of weeks that have history occurrences.
---
--- @return table A table of weeks that have history occurrences.
---
function GetWeeksWithOccurences()
	local weeks = {}
	for i = #gv_HistoryOccurences, 1, -1 do
		local week = GetCampaignWeek(gv_HistoryOccurences[i].time)
		if not weeks[#weeks] or weeks[#weeks] ~= week then
			weeks[#weeks+1] = week
		end
	end
	return weeks
end

-- week: optional filter by week
---
--- Returns a list of days that have history occurrences, optionally filtered by week.
---
--- @param week number The week to filter by, or nil to return all days.
--- @return table A table of days that have history occurrences.
---
function GetDaysWithOccurences(week)
	local days = {}
	for i = #gv_HistoryOccurences, 1, -1 do
		if not week or GetCampaignWeek(gv_HistoryOccurences[i].time) == week then
			local day = GetCampaignDay(gv_HistoryOccurences[i].time)
			if not days[#days] or days[#days] ~= day then
				days[#days+1] = day
			end
		end
	end
	return days
end

---
--- Returns a list of history occurrences that happened on the specified day.
---
--- @param day number The campaign day to filter the history occurrences by.
--- @return table A table of history occurrences that happened on the specified day.
---
function GetOccurencesByDay(day)
	local occurences = {}
	for i = #gv_HistoryOccurences, 1, -1 do
		local d = GetCampaignDay(gv_HistoryOccurences[i].time)
		if d == day then
			occurences[#occurences+1] = gv_HistoryOccurences[i]
		end
	end
	return occurences
end

-- for non repeatable occurences
---
--- Evaluates the conditions for history occurrences that are not repeatable and have not yet occurred. If the conditions are met, a new history occurrence is added to the `gv_HistoryOccurences` table.
---
--- @param interval number The interval in milliseconds between evaluating each history occurrence condition.
---
function HistoryOccurenceConditionEvaluation(interval)
	local historyPresets = PresetsInCampaignArray("HistoryOccurence")
	local n = #historyPresets

	for i, preset in ipairs(historyPresets) do
		if not preset.repeatable and not gv_HistoryOccurences[preset.id] and preset.conditions and #preset.conditions > 0 and EvalConditionList(preset.conditions, preset, {}) then
			local occurence = {
				id = preset.id,
				time = Game.CampaignTime,
				context = false
			}
			gv_HistoryOccurences[#gv_HistoryOccurences+1] = occurence
			gv_HistoryOccurences[preset.id] = true -- save also with key for easier lookup
			ObjModified(gv_HistoryOccurences)
		end
		if interval > 0 then
			Sleep((i+1)*interval/n - i*interval/n)
		end
	end
end

-- Not sure if this is correct. Don't we want to evaluate also in SatView.
local HistoryOccurenceEvaluationInterval = 1000
---
--- Periodically evaluates the conditions for history occurrences that are not repeatable and have not yet occurred. If the conditions are met, a new history occurrence is added to the `gv_HistoryOccurences` table.
---
--- @param interval number The interval in milliseconds between evaluating each history occurrence condition.
---
MapGameTimeRepeat("HistoryOccurenceConditionEvaluation", HistoryOccurenceEvaluationInterval, function()
	if mapdata.GameLogic and HasGameSession() and not IsSetpiecePlaying() then
		HistoryOccurenceConditionEvaluation(HistoryOccurenceEvaluationInterval)
	end	
end)

DefineClass.PDAHistoryClass = {
	__parents = { "XDialog" },
	
	selectedDay = false
}

---
--- Opens the PDA history dialog and selects the last day with a history occurrence.
---
function PDAHistoryClass:Open()
	XDialog.Open(self)
	local history_entries = #gv_HistoryOccurences
	if history_entries > 0 then
		local entry = gv_HistoryOccurences[history_entries]
		local lastDay = GetCampaignDay(entry.time)
		self:SelectDay(lastDay)
	end
	self:HighlightLabels()
end

---
--- Selects the specified day in the PDA history dialog and scrolls the history rows to display the selected day.
---
--- @param day number The day to select in the PDA history dialog.
---
function PDAHistoryClass:SelectDay(day)
	if day == self.selectedDay then return end
	
	local oldDay = self.selectedDay
	self.selectedDay = day
	
	local historyRows = self:ResolveId("idHistoryRows")
	local dayWindow = historyRows:ResolveId("idDay" .. day)
	
	if GetUIStyleGamepad() and day ~= 1 and (not oldDay or day < oldDay) then
		local childBox = dayWindow.box
		local childOffset = childBox:miny() + historyRows.content_box:sizey()
		local offsetY = historyRows.PendingOffsetY
		offsetY = offsetY - historyRows.content_box:maxy() + childOffset
		historyRows:ScrollTo(0, offsetY)
	else
		historyRows:ScrollIntoView(dayWindow)
	end
	self:HighlightLabels()
end

DefineClass.PDAQuestsHistoryDayButtonClass = {
	__parents = { "XContextWindow" }
}

---
--- Highlights the labels in the PDA history dialog to indicate the currently selected day.
---
--- This function is responsible for updating the visual appearance of the day labels and history rows to reflect the currently selected day in the PDA history dialog.
---
--- It performs the following tasks:
--- - Iterates through the week labels and sets the appropriate visual style for the selected day's label.
--- - Creates a thread to set the selection in the week label list to the index of the selected day.
--- - Iterates through the history rows and sets the appropriate visual style for the selected day's row.
---
--- @param self PDAHistoryClass The instance of the PDAHistoryClass.
---
function PDAHistoryClass:HighlightLabels()
	local selectedButtonIndex = 1
	local weeks = self:ResolveId("idWeeks")
	for i, dayLabel in ipairs(weeks) do
		if not IsKindOf(dayLabel, "PDAQuestsHistoryDayButtonClass") then goto continue end
	
		local button = dayLabel:ResolveId("idButton")
		local icon = dayLabel:ResolveId("idIcon")
		if dayLabel.context == self.selectedDay then
			button:SetToggled(true)
			button:SetTextStyle("PDAQuests_LabelInversed")
			icon:SetImage("UI/PDA/Quest/bullet_selected")
			selectedButtonIndex = i
		else
			button:SetToggled(false)
			button:SetTextStyle("PDAQuests_Label")
			icon:SetImage("UI/PDA/Quest/bullet")
		end
		
		::continue::
	end
	
	self:DeleteThread("select-in-list")
	self:CreateThread("select-in-list", function()
		if weeks.window_state == "destroying" then return end
		weeks:SetSelection(selectedButtonIndex)
	end)
	
	local historyRows = self:ResolveId("idHistoryRows")
	for i = 1, #historyRows do -- for each day
		local virtualContent = historyRows[i]
		local dayWindow = virtualContent[1]
		if dayWindow then
			local bullet = dayWindow:ResolveId("idDayBullet")
			local backgroundWindow = dayWindow:ResolveId("idDayBackground")
			local dayText = dayWindow:ResolveId("idDayText")
			
			if dayWindow.context.day == self.selectedDay then
				bullet:SetImage("UI/PDA/Quest/bullet_selected")
				backgroundWindow:SetBackground(RGBA(88, 92, 68, 125))
				dayText:SetTextStyle("PDAQuestTitleInfo")
			else
				bullet:SetImage("UI/PDA/Quest/bullet")
				backgroundWindow:SetBackground(RGBA(0, 0, 0, 0))
				dayText:SetTextStyle("PDAQuestSection")
			end
		end
	end
end