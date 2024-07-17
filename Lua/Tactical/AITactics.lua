MapVar("g_TacticalMap", false)

---
--- Calculates the path distances for a given unit and context.
---
--- @param unit table The unit for which to calculate the path distances.
--- @param context table The context for the path distance calculations.
--- @param disable_bias boolean Whether to disable the bias in the path distance calculations.
---
function AITacticCalcPathDistances(unit, context, disable_bias)
	context.apply_bias = not disable_bias

	-- make sure we have a distance to optimal - if there's no path use raw distance
	AICalcPathDistances(context)
	local cur_dest = GetPackedPosAndStance(unit)
	for _, dest in ipairs(context.destinations) do
		context.dest_dist[dest] = stance_pos_dist(context.best_dest, dest)
	end

	context.total_dist = stance_pos_dist(cur_dest, context.best_dest)
end

---
--- Selects the end turn policies for a given unit and context.
---
--- @param unit table The unit for which to select the end turn policies.
--- @param context table The context for the end turn policy selection.
--- @return table The end turn policies for the given unit and context.
---
function AITacticSelectEndTurnPolicies(unit, context)
	local archetype = unit:GetCurrentArchetype() -- take from "base" archetype ignoring the current (script) one
	if not archetype then return end
	for _, behavior in ipairs(archetype.Behaviors) do
		if behavior.Fallback and #(behavior.EndTurnPolicies or empty_table) > 0 then
			return behavior.EndTurnPolicies
		end
	end
	if archetype and #(archetype.EndTurnPolicies or empty_table) > 0 then
		return archetype.EndTurnPolicies
	end
end

---
--- Selects the signature actions for a given unit and context.
---
--- @param unit table The unit for which to select the signature actions.
--- @param context table The context for the signature action selection.
--- @return table The signature actions for the given unit and context.
---
function AITacticSelectSignatureActions(unit, context)	
	local archetype = unit:GetCurrentArchetype() -- take from "base" archetype ignoring the current (script) one
	if archetype and #(archetype.SignatureActions or empty_table) > 0 then
		return archetype.SignatureActions
	end
end

---
--- Generates an iterator that returns the individual area IDs from the given bitmask of areas.
---
--- @param areas number The bitmask of areas to iterate over.
--- @return function The iterator function that returns the individual area IDs.
---
function tac_area_ids(areas)
	if not g_TacticalMap then return empty_func end
	local bit = 0
	areas = areas or 0
	return function()
		while bit < 64 do
			local mask = shift(1, bit)
			bit = bit + 1
			if band(areas, mask) ~= 0 then
				return g_TacticalMap.individual_areas[bit] -- the list is base 1 so the +1 above matches the needs
			end
		end
	end
end

DefineClass.TacticalMap = {
	__parents = { "GameDynamicSpawnObject" },

	area_to_marker = false,
	area_to_positions = false,
	ppos_to_individual_area = false,
	id_to_individual_area = false, -- [id] = flag
	individual_areas = false,

	-- area assignment: [unit] = area(s)
	assigned_individual_areas = false,
	-- area assignment priority: [unit] = { [priority] = area(s) }
	assigned_area_priority = false,
	
	PriorityHigh = 1,
	PriorityMedium = 2,
	PriorityLow = 3,
}

---
--- Initializes the TacticalMap object by setting up various data structures to manage individual fight areas.
---
--- This function is called during the initialization of the TacticalMap object. It performs the following tasks:
---
--- 1. Initializes the `area_to_marker`, `area_to_positions`, `ppos_to_individual_area`, `individual_areas`, `id_to_individual_area`, `assigned_individual_areas`, and `assigned_area_priority` tables.
--- 2. Sets the position of the TacticalMap object to the center of the map.
--- 3. Iterates through all the map markers and registers the individual fight areas, storing their IDs and flags in the appropriate data structures.
---
--- @function TacticalMap:Init
--- @return nil
function TacticalMap:Init()
	self.area_to_marker = {}
	self.area_to_positions = {}
	self.ppos_to_individual_area = {}
	self.individual_areas = {}
	self.id_to_individual_area = {}
	self.assigned_individual_areas = {}
	self.assigned_area_priority = {}

	self:SetPos(point(terrain.GetMapSize()) / 2)

	local markers = MapGetMarkers()
	local bit = 0
	local seen = {}
	for _, marker in ipairs(markers) do
		if marker.FightAreaId ~= "" then
			if seen[marker.FightAreaId] then
				StoreErrorSource(marker, string.format("Marker Fight Area Id '%s' already in use, ignored", marker.FightAreaId))
			else
				seen[marker.FightAreaId] = true
				if bit >= 64 then
					StoreErrorSource(marker, string.format("Trying to register more than 64 Individual Fight Areas, Fight Area '%s' ignored", marker.FightAreaId))
				else
					local flag = shift(1, bit)
					self.id_to_individual_area[marker.FightAreaId] = flag
					self.individual_areas[bit + 1] = marker.FightAreaId
					self:RegisterIndividualArea(marker, marker.FightAreaId, marker.FightArea3d)
					bit = bit + 1
				end
			end
		end
	end
end

---
--- Assigns a unit to one or more individual fight areas, optionally with a priority.
---
--- @param unit Unit The unit to assign to the fight areas.
--- @param areas string|table The fight area ID or a table of fight area IDs to assign the unit to.
--- @param reset boolean If true, any existing area assignments for the unit will be cleared before the new assignments are made.
--- @param priority number The priority to assign to the fight area(s), between 1 (high) and 3 (low).
---
function TacticalMap:AssignUnit(unit, areas, reset, priority)
	if not areas then
		self.id_to_individual_area[unit] = nil
		self.assigned_area_priority[unit] = nil
		return
	end
	if type(areas) == "table" then
		for _, area in ipairs(areas) do
			self:AssignUnit(unit, area, reset, priority)
		end
		return
	end
	local flag = self.id_to_individual_area[areas] or 0
	self.assigned_individual_areas[unit] = bor(reset and 0 or self.assigned_individual_areas[unit] or 0, flag)
	if type(priority) == "number" then
		priority = Clamp(priority, self.PriorityHigh, self.PriorityLow)
		self.assigned_area_priority[unit] = self.assigned_area_priority[unit] or {}
		self.assigned_area_priority[unit][priority] = bor(reset and 0 or self.assigned_area_priority[unit][priority] or 0, flag)
	end
end

---
--- Returns the individual fight areas assigned to the given unit, optionally filtered by priority.
---
--- @param unit Unit The unit to get the assigned areas for.
--- @param priority number The priority to filter the assigned areas by, between 1 (high) and 3 (low).
--- @return table The individual fight area IDs assigned to the unit, filtered by priority if specified.
---
function TacticalMap:GetAssignedAreas(unit, priority)
	local areas = self.assigned_area_priority[unit]
	if areas and priority then
		areas = areas[priority]
	end
	return areas
end

---
--- Shows the individual fight areas assigned to the given unit for a specified duration.
---
--- @param unit Unit The unit to show the assigned areas for.
--- @param time number The duration in milliseconds to show the assigned areas for.
---
function TacticalMap:ShowAssignedArea(unit, time)
	time = time or 2000
	CreateRealTimeThread(function()
		local areas = self.assigned_individual_areas[unit]
		for id in tac_area_ids(areas) do
			local marker = self.area_to_marker[id]
			marker.ground_visuals = true
			marker:ShowArea()
		end
		Sleep(time)
		for id in tac_area_ids(areas) do
			local marker = self.area_to_marker[id]
			marker.ground_visuals = false
			marker:HideArea()
		end
	end)
end

---
--- Returns the individual fight areas assigned to the given unit.
---
--- @param unit Unit The unit to get the assigned areas for.
--- @return table The individual fight area IDs assigned to the unit.
---
function TacticalMap:GetUnitAreas(unit)
	local x, y, z = unit:GetPosXYZ()
	local pos = point_pack(x, y, z)
	return self.ppos_to_individual_area[pos] or 0
end

---
--- Returns the primary individual fight area the given unit is located in.
---
--- @param unit Unit The unit to get the primary area for.
--- @return number The ID of the primary individual fight area the unit is located in.
---
function TacticalMap:GetUnitPrimaryArea(unit)
	local x, y, z = unit:GetPosXYZ()
	local pos = point_pack(x, y, z)
	local areas = self.ppos_to_individual_area[pos] or 0
	local area, mindist
	for id in tac_area_ids(areas) do
		local marker = self.area_to_marker[id]
		local dist = unit:GetDist(marker)
		if not area or dist < mindist then
			area, mindist = id, dist
		end
	end
	return area
end

---
--- Returns a list of units located within the specified individual fight area.
---
--- @param area_id number The ID of the individual fight area to get units for.
--- @return table The list of units located within the specified area.
---
function TacticalMap:GetUnitsInArea(area_id)
	local units = {}
	for _, unit in ipairs(g_Units) do
		local x, y, z = unit:GetPosXYZ()
		local pos = point_pack(x, y, z)
		local areas = self.ppos_to_individual_area[pos] or 0
		for id in tac_area_ids(areas) do
			if id == area_id then
				units[#units + 1] = unit
				break
			end
		end
	end
	return units
end

---
--- Returns the nearest individual fight area ID to the given unit from the list of provided area IDs.
---
--- @param unit Unit The unit to find the nearest area for.
--- @param ... number The IDs of the individual fight areas to check.
--- @return number The ID of the nearest individual fight area to the unit.
---
function TacticalMap:GetNearestArea(unit, ...)
	local n = select("#", ...)
	local area, mindist
	for i = 1, n do
		local area_id = select(i, ...)
		local marker = self.area_to_marker[area_id]
		if marker then
			local dist = unit:GetDist(marker)
			if not area or dist < mindist then
				area, mindist = area_id, dist
			end
		end
	end
	return area
end

---
--- Counts the number of player and enemy units in each individual fight area.
---
--- @return table The number of player units in each area.
--- @return table The number of enemy units in each area.
---
function TacticalMap:CountUnitsInAreas()
	local player_units_in_area = {}
	local enemy_units_in_area = {}
	for _, unit in ipairs(g_Units) do
		local area = self:GetUnitPrimaryArea(unit)
		if area then
			if unit.team.player_team then
				player_units_in_area[area] = (player_units_in_area[area] or 0) + 1
			elseif unit.team.player_enemy then
				enemy_units_in_area[area] = (enemy_units_in_area[area] or 0) + 1
			end
		end
	end
	return player_units_in_area, enemy_units_in_area
end

---
--- Finds the optimal location for a unit within its assigned individual fight area.
---
--- @param unit Unit The unit to find the optimal location for.
--- @param context table The AI context containing information about the unit's destinations.
--- @return boolean True if an optimal location was found, false otherwise.
---
function TacticalMap:FindOptimalLocationInAssignedArea(unit, context)	
	local positions
	local assigned_area = self.assigned_individual_areas[unit] or 0
	local cur_pos = point_pack(unit:GetPos())	
	
	if assigned_area ~= 0 then
		local area = self.ppos_to_individual_area[cur_pos]
		if band(area, assigned_area) ~= 0 then
			-- already in one of the areas
			context.best_dest = GetPackedPosAndStance(unit)
			return true			
		end
		positions = {}		
		if self.assigned_area_priority[unit] then
			for p = self.PriorityHigh, self.PriorityLow do
				for id in tac_area_ids(self.assigned_area_priority[unit][p]) do
					local flag = self.id_to_individual_area[id]
					if band(assigned_area, flag) ~= 0 then
						positions = table.union(positions, self.area_to_positions[id])
					end
				end
				if #positions > 0 then break end
			end
		end
		if #positions == 0 then
			for id, flag in pairs(self.id_to_individual_area) do
				if band(assigned_area, flag) ~= 0 then
					positions = table.union(positions, self.area_to_positions[id])
				end
			end
		end
	end
	
	positions = positions or empty_table
	if #positions > 0 then
		local goto_pos = table.interaction_rand(positions, "Behavior")
		local x, y, z = point_unpack(goto_pos)
		context.best_dest = stance_pos_pack(x, y, z, StancesList.Standing)
		context.optimal_dest_in_assigned_area = true
		return true
	end
end

---
--- Enumerates the destinations within the assigned area for a given unit.
---
--- @param unit Unit The unit to enumerate destinations for.
--- @param context table The AI context containing information about the unit's destinations.
--- @return boolean True if destinations were found within the assigned area, false otherwise.
---
function TacticalMap:EnumDestsInAssignedArea(unit, context)
	AIFindDestinations(unit, context)
	
	local marker_area = self.assigned_individual_areas[unit] or 0
	if marker_area ~= 0 then
		local function dest_in_marker_filter(idx, dest, area)
			local x, y, z = stance_pos_unpack(dest)
			local ppos = point_pack(x, y, z)			
			return band(self.ppos_to_individual_area[ppos] or 0, area) ~= 0
		end
		
		if self.assigned_area_priority[unit] then
			for p = self.PriorityHigh, self.PriorityLow do
				local marker_areas = self.assigned_area_priority[unit][p] or 0
				if marker_areas ~= 0 then
					local dests = table.ifilter(context.destinations, dest_in_marker_filter, marker_areas)
					local all_dests = table.ifilter(context.all_destinations, dest_in_marker_filter, marker_areas)
					if #dests > 0 and #all_dests > 0 then
						context.destinations = dests
						context.all_destinations = all_dests
						return true
					end
				end
			end
		end
		
		local dests = table.ifilter(context.destinations, dest_in_marker_filter, marker_area)
		local all_dests = table.ifilter(context.all_destinations, dest_in_marker_filter, marker_area)
		if #dests > 0 and #all_dests > 0 then
			context.destinations = dests
			context.all_destinations = all_dests
			return true
		else
			context.assigned_area_unreachable = true
		end
	end
		
	return true
end

---
--- Saves the dynamic data related to assigned individual areas and area priorities for units.
---
--- @param data table The table to store the dynamic data in.
---
function TacticalMap:GetDynamicData(data)
	data.assigned_individual_areas = {}
	for unit, area in pairs(self.assigned_individual_areas) do
		if unit then
			data.assigned_individual_areas[unit:GetHandle()] = area
		end
	end
	
	data.assigned_area_priority = {}
	for unit, priorities in pairs(self.assigned_area_priority) do
		if unit then
			local handle = unit:GetHandle()
			for p = self.PriorityHigh, self.PriorityLow do
				local areas = priorities[p] or 0
				if areas ~= 0 then
					data.assigned_area_priority[handle] = data.assigned_area_priority[handle] or {}
					data.assigned_area_priority[handle][p] = areas
				end
			end
		end
	end
end

---
--- Restores the dynamic data related to assigned individual areas and area priorities for units.
---
--- @param data table The table containing the dynamic data to restore.
---
function TacticalMap:SetDynamicData(data)
	self.assigned_individual_areas = {}
	for handle, area in pairs(data.assigned_individual_areas) do
		local unit = HandleToObject[handle] or false
		self.assigned_individual_areas[unit] = area
	end
	
	self.assigned_area_priority = {}
	for handle, priorities in pairs(data.assigned_area_priority) do
		local unit = HandleToObject[handle] or false
		for p = self.PriorityHigh, self.PriorityLow do
			local areas = priorities[p] or 0
			if areas ~= 0 then
				self.assigned_area_priority[unit] = self.assigned_area_priority[unit] or {}
				self.assigned_area_priority[unit][p] = areas
			end
		end
	end
end

---
--- Registers an individual area on the tactical map.
---
--- @param marker table The marker object representing the area.
--- @param area number The ID of the area to register.
--- @param mode_3d boolean Whether to register the area in 3D mode.
---
function TacticalMap:RegisterIndividualArea(marker, area, mode_3d)
	local positions = marker:GetAreaPositions(true)
	local area_flag = self.id_to_individual_area[area]
	
	self.area_to_marker[area] = marker
	self.area_to_positions[area] = positions
	for _, ppos in ipairs(positions) do
		local x, y, z = SnapToPassSlabXYZ(point_unpack(ppos))
		if x then
			ppos = point_pack(x, y, z)
		end
		self.ppos_to_individual_area[ppos] = bor(self.ppos_to_individual_area[ppos] or 0, area_flag)
	end
	
	if mode_3d then
		local bbox = marker:GetBBox()
		local min, max = bbox:min():SetZ(0), bbox:max():SetZ(1000*guim)
		bbox = Extend(Extend(bbox, min), max)

		ForEachPassSlab(bbox, function(x, y, z, positions, ppos_to_individual_area, area_flag)
			local ppos = point_pack(x, y, z)
			ppos_to_individual_area[ppos] = bor(ppos_to_individual_area[ppos] or 0, area_flag)
		end, self.area_to_positions[area], self.ppos_to_individual_area, area_flag)
	end
end

local function InitTacticalMap()
	g_TacticalMap = g_TacticalMap or TacticalMap:new()
end

function OnMsg.EnterSector(game_start, load_game)
	if not load_game then
		InitTacticalMap()
	end
end

function OnMsg.CombatStart(dynamic_data)
	if not dynamic_data then 
		InitTacticalMap()
	end
end