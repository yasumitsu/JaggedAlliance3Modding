DefineClass.SectorEvent = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "Conditions", name = "Conditions", editor = "nested_list", base_class = "Condition", default = false, help = "Conditions to check before executing the effects" },
		{ id = "SequentialEffects", name = "Execute Effects Sequentially", help = "Whether effects should wait for each other when executing in order.", editor = "bool", default = false, },
		{ id = "Effects",    name = "Effects",    editor = "nested_list", base_class = "Effect", default = false, help =  "Effects to execute, depending of trigger and conditions result" },
		{ id = "Trigger",    name = "Trigger",    editor = "dropdownlist", items = { "once", "always", }, default = "once", help = "If set to once, the effects will be executed only once for the current game session"},
	},
}

---
--- Executes the effects of a SectorEvent, taking into account the event's trigger and conditions.
---
--- @param context table The context for executing the effects, containing the sector ID.
--- @param event_idx number The index of the event being executed.
--- @param wait boolean Whether to wait for sequential effects to complete.
---
function SectorEvent:ExecuteEffects(context, event_idx, wait)
	local sector = gv_Sectors[context.sector_id]
	if sector.ExecutedEvents and sector.ExecutedEvents[event_idx] and self.Trigger == "once" then
		return
	end
	if self.Effects and EvalConditionList(self.Conditions, self, context) then
		sector.ExecutedEvents = sector.ExecutedEvents or {}
		sector.ExecutedEvents[event_idx] = true
		if self.SequentialEffects then
			if wait then
				WaitExecuteSequentialEffects(self.Effects, "Simple", self, context)
			else
				ExecuteSequentialEffects(self.Effects, "Simple", self, context)
			end
		else
			ExecuteEffectList(self.Effects, self, context)
		end
	end
end

---
--- Checks if there are any errors in the SectorEvent.
---
--- This function checks if the SectorEvent has any issues, specifically if it has a `PlaySetpiece` effect attached to an `SE_OnEnterMapVisual` event, and the effects are not set to execute sequentially.
---
--- @return string|nil The error message if an issue is found, or `nil` if no issues are detected.
---
function SectorEvent:GetError()
	if self.class == "SE_OnEnterMapVisual" and not self.SequentialEffects then
		for _, effect in ipairs(self.Effects) do
			if effect.class == "PlaySetpiece" then
				return "Setpiece effects attached on SE_OnEnterMapVisual should be executed sequentially."
			end
		end
	end
end

---
--- Executes the sector events of the specified class for the given sector.
---
--- @param event_class string The class of the sector events to execute.
--- @param sector_id number The ID of the sector to execute the events for.
--- @param wait boolean Whether to wait for sequential effects to complete.
---
function NetEvents.ExecuteSectorEvents(event_class, sector_id, wait)
	ExecuteSectorEvents(event_class, sector_id, wait)
end

---
--- Executes the sector events of the specified class for the given sector.
---
--- @param event_class string The class of the sector events to execute.
--- @param sector_id number The ID of the sector to execute the events for.
--- @param wait boolean Whether to wait for sequential effects to complete.
---
function ExecuteSectorEvents(event_class, sector_id, wait)
	assert(not wait or CanYield(), "Waiting for ExecuteSectorEvents can only happen in a thread")
	local sector = gv_Sectors[sector_id]
	local context = {sector_id = sector_id}
	for i, event in ipairs(sector.Events or empty_table) do
		if event.class == event_class then
			event:ExecuteEffects(context, i, wait)
		end
	end
end

DefineClass.SE_OnEnterMap = { __parents = { "SectorEvent", } } -- load sector map during the loading screen
DefineClass.SE_OnEnterMapVisual  = { __parents = { "SectorEvent", } } -- load sector map visuals after the loading screen
DefineClass.SE_OnSatelliteExplore = { __parents = { "SectorEvent", } } -- explore sector with no defined map
DefineClass.SE_OnSquadReachSectorCenter = { __parents = { "SectorEvent", } } -- when a player squad reaches the sector center in satellite
DefineClass.SE_OnTick = { __parents = { "SectorEvent", } }
DefineClass.SE_OnLoyaltyChange = { __parents = { "SectorEvent", } }
DefineClass.SE_OnSideChange = { __parents = { "SectorEvent", } }
DefineClass.SE_PlayerControl = { __parents = { "SectorEvent", } }
DefineClass.SE_OnConflictStarted = { __parents = { "SectorEvent", } }
DefineClass.SE_OnEnterWarningState = { __parents = { "SectorEvent", } }
DefineClass.SE_PreChangeMap = { __parents = { "SectorEvent", } }

function OnMsg.LoyaltyChanged(city_id, loyalty, change)
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.City == city_id then
			ExecuteSectorEvents("SE_OnLoyaltyChange", id)
			ObjModified(sector)
		end
	end
end