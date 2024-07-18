if FirstLoad then
	GedBuildingRulesEditor = false
end

MapVar("VolumeBuildings", false)
MapVar("VolumeBuildingsMeta", {})

MapVar("g_BuildingRulesContainer", false)
---
--- Returns the list of building rules defined in the game.
---
--- If no building rules container exists, it creates a new one. If multiple containers exist, it keeps only the first one and deletes the rest.
---
--- @return table The list of building rules
---
function GetBuildingRules()
	if not g_BuildingRulesContainer then
		local t = MapGet("detached", "BuildingRulesContainer")
		
		if t and #t > 1 then
			--like in highlander, there can be only one
			for i = #t, 2, -1 do
				DoneObject(t[i])
				t[i] = nil
			end
		end
		
		g_BuildingRulesContainer = t and t[1] or PlaceObject("BuildingRulesContainer")
	end
	g_BuildingRulesContainer.contents = g_BuildingRulesContainer.contents or {}
	return g_BuildingRulesContainer.contents
end

DefineClass.BuildingRulesContainer = {
	__parents = { "Object" },
	flags = { gofPermanent = true, efWalkable = false, efCollision = false, efApplyToGrids = false },
	properties = {
		{ id = "contents", editor = "objects", default = false },
	},
}

DefineClass.BuildingRule = {
	__parents = { "StripObjectProperties", }, --object, so it gets saved on map
	flags = { gofPermanent = true },
	properties = {
		{ category = "General", id = "name", name = "Name", editor = "text", default = "BuildingRule", },
	}
}

DefineClass.ForbidSameBuilding = {
	__parents = { "BuildingRule", },
	properties = {
		{ id = "room_names", editor = "string_list", default = false, help = "Rooms in this list should not appear in the same building."},
	},
	
	name = "ForbidSameBuildingRule",
}

---
--- Creates a new ForbidSameBuilding rule and adds it to the list of building rules.
---
--- @param socket table The socket object that triggered this function
--- @param obj table The ForbidSameBuilding object that was created
---
function GedOpNewForbidRule(socket, obj)
	local rules = GetBuildingRules()
	table.insert(rules, PlaceObject("ForbidSameBuilding"))
	ObjModified(rules)
end

---
--- Opens the Ged Building Rules Editor application.
---
--- This function creates a new real-time thread to open the Ged Building Rules Editor application. If the application is not already open, it will create a new instance of the application and pass the current building rules to it. If the application is already open, it will do nothing.
---
--- @function OpenGedBuildingRulesEditor
--- @return nil
function OpenGedBuildingRulesEditor()
	CreateRealTimeThread(function()
		if not GedBuildingRulesEditor or not IsValid(GedBuildingRulesEditor) then
			GedBuildingRulesEditor = OpenGedApp("GedBuildingRulesEditor", GetBuildingRules()) or false
		end
	end)
end

---
--- Closes the Ged Building Rules Editor application.
---
--- This function checks if the GedBuildingRulesEditor object is valid, and if so, sends the "rfnClose" message to it to close the application. It then sets the GedBuildingRulesEditor variable to false.
---
--- @function CloseGedBuildingRulesEditor
--- @return nil
function CloseGedBuildingRulesEditor()
	if GedBuildingRulesEditor then
		GedBuildingRulesEditor:Send("rfnClose")
		GedBuildingRulesEditor = false
	end
end

function OnMsg.SaveMap()
	if g_BuildingRulesContainer and #g_BuildingRulesContainer.contents <= 0 then
		DoneObject(g_BuildingRulesContainer)
		g_BuildingRulesContainer = false
		--no longer hooked to the correct obj
		CloseGedBuildingRulesEditor()
	end
end

function OnMsg.ChangeMap()
	CloseGedBuildingRulesEditor()
end

---
--- Removes duplicate elements from the given table.
---
--- @param t table The table to remove duplicates from.
--- @return table The table with duplicates removed.
function table.clear_duplicates(t)
	local passed = {}
	for i = #t, 1, -1 do
		if passed[t[i]] then
			table.remove(t, i)
		else
			passed[t[i]] = true
		end
	end
	
	return t
end

---
--- Returns a table of ForbidSameBuilding rules from the given set of building rules.
---
--- @param rules table The set of building rules to extract the ForbidSameBuilding rules from.
--- @return table The table of ForbidSameBuilding rules.
function GetForbidRules(rules)
	rules = rules or GetBuildingRules()
	local forbidRules = {}
	for i = 1, #rules do
		local r = rules[i]
		if IsKindOf(r, "ForbidSameBuilding") then
			table.insert(forbidRules, r)
		end
	end
	
	return forbidRules
end

---
--- Returns a table of room names that are forbidden to be adjacent to the given room, based on the provided set of ForbidSameBuilding rules.
---
--- @param room table The room to get the forbidden adjacent rooms for.
--- @param forbidRules table The set of ForbidSameBuilding rules to use.
--- @return table The table of room names that are forbidden to be adjacent to the given room.
function GetForbiddenRoomsForRoom(room, forbidRules)
	forbidRules = forbidRules or GetForbidRules()
	
	local forbidden = {}
	for i = 1, #forbidRules do
		local r = forbidRules[i]
		local pass = {}
		local add = false
		for j = 1, #(r.room_names or "") do
			local n = r.room_names[j]
			if n == room.name then
				add = true
			else
				table.insert(pass, n)
			end
		end
		if add then
			table.iappend(forbidden, pass)
		end
	end
	
	return table.clear_duplicates(forbidden)
end

---
--- Returns a table of room names that are forbidden to be adjacent to any room in the given building, based on the provided set of ForbidSameBuilding rules.
---
--- @param bld table The building to get the forbidden adjacent rooms for.
--- @param forbidRules table The set of ForbidSameBuilding rules to use.
--- @return table The table of room names that are forbidden to be adjacent to any room in the given building.
function GetForbiddenRoomsForBuilding(bld, forbidRules)
	forbidRules = forbidRules or GetForbidRules()

	local forbidden = {}
	ForEachRoomInBuilding(bld, function(room, forbidRules, forbidden)
		table.iappend(forbidden, GetForbiddenRoomsForRoom(room, forbidRules))
	end, forbidRules, forbidden)
	
	return table.clear_duplicates(forbidden)
end

---
--- Appends the list of rooms that are forbidden to be adjacent to the given room, based on the provided set of ForbidSameBuilding rules, to the given rules table.
---
--- @param room table The room to get the forbidden adjacent rooms for.
--- @param forbidRules table The set of ForbidSameBuilding rules to use.
--- @param rules table The table to append the forbidden rooms to.
--- @return table The updated table of forbidden rooms, with duplicates removed.
function AppendForbidRulesForRoom(room, forbidRules, rules)
	table.iappend(rules, GetForbiddenRoomsForRoom(room, forbidRules))
	return table.clear_duplicates(rules)
end

local valid_adjacency_sides = {
	"North",
	"West",
	"South",
	"East",
	"Roof",
	"Floor",
}

local function hasProperAdjacentSide(sides)
	for i = 1, #sides do
		local s = sides[i]
		if table.find(valid_adjacency_sides, s) then
			return true
		end
	end
	
	return false
end
local voxelSizeZ = const.SlabSizeZ or 0
---
--- Builds the data for all volume buildings in the game world.
---
--- This function processes all rooms in the game world and groups them into volume buildings based on their adjacency. It also calculates various metadata about the buildings, such as the minimum and maximum floor levels, and whether the top floor is a roof.
---
--- The function first iterates through all rooms, creating new buildings or merging rooms into existing buildings based on their adjacency. It then calls the `BuildingsPostProcess()` function to finalize the building data.
---
--- @return nil
function BuildBuildingsData()
	Msg("BuildBuildingsData", VolumeBuildings)
	local oldVolumeBuildings = VolumeBuildings
	VolumeBuildings = {}
	local allRooms = MapGet("map", "Room")
	local forbidRules = GetForbidRules()
	local passed2 = {}
	for i, r in ipairs(allRooms) do
		if passed2[r] then
			goto continue
		end
		passed2[r] = true
		local newBuilding
		local queue = {}
		if not table.find(VolumeBuildings, r.building) then
			r.building = false
		end
			
		for _, room in ipairs(r.adjacent_rooms or empty_table) do
			local data = r.adjacent_rooms[room]
			if hasProperAdjacentSide(data[2]) then
				queue[room] = data
			end
		end
		
		local function InjectOneSidedAdjacency(r, ar)
			if not r.building and ar.building and table.find(VolumeBuildings, ar.building) then
				--adjacents already have a new bld, inject into that
				local fr = GetForbiddenRoomsForBuilding(ar.building, forbidRules)
				local is_forbidden = table.find(fr, r.name)
				if not is_forbidden then
					local bld = ar.building
					bld[r.floor] = bld[r.floor] or {}
					r.building = bld
					table.insert(bld[r.floor], r)
					AppendForbidRulesForRoom(r, forbidRules, fr)
				end
			end
			if r.building and ar.building and ar.building ~= r.building and table.find(VolumeBuildings, ar.building) then
				--merge buildings, this won't work with forbid rules very well, but noone uses them anyway
				--it may produce a single split building due to a room in the middle being forbidden
				local new_bld = ar.building
				local old_bld = r.building
				local is_old_bld_empty = true
				local fr = GetForbiddenRoomsForBuilding(new_bld, forbidRules)
				ForEachRoomInBuilding(old_bld, function(room_in_old_bld)
					local is_forbidden = table.find(fr, room_in_old_bld.name)
					if not is_forbidden then
						local flr = room_in_old_bld.floor
						new_bld[flr] = new_bld[flr] or {}
						table.insert(new_bld[flr], room_in_old_bld)
						table.remove_entry(old_bld[flr], room_in_old_bld)
						room_in_old_bld.building = new_bld
						AppendForbidRulesForRoom(room_in_old_bld, forbidRules, fr)
					else
						is_old_bld_empty = false
					end
				end)
				
				if is_old_bld_empty then
					table.remove_entry(VolumeBuildings, old_bld)
				end
			end
		end

		if r:HasRoof() and r.roof_box and r.roof_type == "Flat" then
			--check for volumes that are adjacent to this volume's roof
			local rb = r.roof_box
			local b = rb:grow(0, 0, Max((voxelSizeZ + 1) - rb:sizez(), 0))
			EnumVolumes(b, function(ar)
				if ar ~= r and not queue[ar] then
					queue[ar] = true
					InjectOneSidedAdjacency(r, ar)
				end
			end)
		end
		
		if r:IsRoofOnly() and #(r.adjacent_rooms or "") <= 0 and r.size:z() <= 0 then
			--sepcial case for roofs sticking out of buildings
			--zero height box will miss adjacency on the sides
			local b = r.box:grow(1, 1, 1)
			EnumVolumes(b, function(ar)
				if ar ~= r and not queue[ar] then
					local ib = IntersectRects(b, ar.box)
					if ib:sizex() > 1 or ib:sizey() > 1 then
						queue[ar] = true
						InjectOneSidedAdjacency(r, ar)
					end
				end
			end)
		end
		
		if not r.building then
			newBuilding = {[r.floor] = {r}}
			table.insert(VolumeBuildings, newBuilding)
			r.building = newBuilding
		else
			newBuilding = r.building
		end
		
		local forbidden = GetForbiddenRoomsForBuilding(newBuilding, forbidRules)
		
		local adjRoom = next(queue)
		local passed = {}
		while adjRoom do
			queue[adjRoom] = nil
			passed[adjRoom] = true
			if not passed2[adjRoom] then
				local is_forbidden = table.find(forbidden, adjRoom.name)
				if not is_forbidden then
					if adjRoom.building ~= newBuilding then
						passed2[adjRoom] = true
						adjRoom.building = newBuilding
						newBuilding[adjRoom.floor] = newBuilding[adjRoom.floor] or {}
						table.insert(newBuilding[adjRoom.floor], adjRoom)
						AppendForbidRulesForRoom(adjRoom, forbidRules, forbidden)
						for _, room in ipairs(adjRoom.adjacent_rooms) do
							if not passed[room] then
								local data = adjRoom.adjacent_rooms[room]
								if hasProperAdjacentSide(data[2]) then
									queue[room] = adjRoom.adjacent_rooms[room]
								end
							end
						end
					end
				end
			elseif adjRoom ~= r and adjRoom.building ~= r.building then
				--this happens when we see a room for the first time but it has already passed;
				--last time it happened it was due asymetrical adjacency caused by the hack above;
				assert(false, "This should probably not happen")
			end
			adjRoom = next(queue)
		end
		
		::continue::
	end
	
	BuildingsPostProcess()
	Msg("VolumeBuildingsRebuilt", VolumeBuildings, oldVolumeBuildings)
end

---
--- Processes the volume buildings after they have been built.
--- This function iterates through all the volume buildings and calculates the minimum and maximum floor levels for each building.
--- It also determines if the top-most rooms in each building are roof-only rooms.
---
--- @param none
--- @return none
---
function BuildingsPostProcess()
	VolumeBuildingsMeta = {}
	local t = VolumeBuildingsMeta
	for i = 1, #VolumeBuildings do
		local bld = VolumeBuildings[i]
		t[bld] = {minFloor = max_int, maxFloor = min_int}
		
		ForEachRoomInBuilding(bld, function(r)
			local floor = r.floor
			t[bld].minFloor = Min(t[bld].minFloor, floor)
			t[bld].maxFloor = Max(t[bld].maxFloor, floor)
			t[bld][floor] = t[bld][floor] or {box = box()}
			t[bld][floor].box = Extend(t[bld][floor].box, r.box)
			
			--determine if it has visible floor
			if r.floor_mat ~= "none" and (not t[bld].firstFloorWithFloor or floor < t[bld].firstFloorWithFloor) then
				--local has_floor = r.floor_mat ~= "none"
				t[bld].firstFloorWithFloor = Min(t[bld].firstFloorWithFloor, floor)
			end
		end)
		
		local allTopRoomsAreRoof = true
		local maxFloor = t[bld].maxFloor
		ForEachRoomInBuilding(bld, function(r)
			if r.floor == maxFloor and not r:IsRoofOnly() then
				allTopRoomsAreRoof = false
			end
		end)
		t[bld].maxFloorIsRoof = allTopRoomsAreRoof
	end
end

---
--- Processes the rooms after the volume buildings have been built.
--- This function iterates through all the rooms and checks which walls are visible for each room.
--- It also checks for fully invisible roofs, which can cause problems with visibility and are hard to find manually.
---
--- @param none
--- @return none
---
function RoomsPostProcess()
	--check and see whether any wall is fully invisible so we can omit hide/show events for it later on
	MapForEach("map", "Room", function(r)
		r.visible_walls = { total = 0 }
		
		for side, wall in pairs(r.spawned_walls) do
			local any_visible = #(r.spawned_windows and r.spawned_windows[side] or "") > 0 or #(r.spawned_doors and r.spawned_doors[side] or "") > 0
			
			if not any_visible then
				for i = 1, #wall do
					if IsValid(wall[i]) and wall[i].isVisible then
						any_visible = true
						break
					end
				end
			end
			r.visible_walls[side] = any_visible
			r.visible_walls.total = r.visible_walls.total + (any_visible and 1 or 0)
		end
		
		if Platform.developer then
			--check for fully invisible roofs, they cause problems with visibility and are hard to find manually
			if r:HasRoofSet() then
				local has_visible = false
				local objs = r.roof_objs
				for i = 1, #(objs or "") do
					if IsValid(objs[i]) and objs[i].isVisible then
						has_visible = true
						break
					end
				end
				
				if not has_visible then
					print("<color 255 0 0>Room '" .. r.name .. "' has roof set but no pieces of it are visible!</color>")
				end
			end
		end
	end)
	-- after we know which walls are visible for each room
	MapForEach("map", "Room", function(r)
		r.adjacent_rooms_per_side = {} -- this data is for planA wall visibility, it's basically a more convenient data structure for runtime checks
		local ars = r.adjacent_rooms
		for _, ar in ipairs(ars or empty_table) do
			local data = ars[ar]
			if r.visible_walls.total >= 1 then  -- only acknowledge rooms that have at least 1 visible wall
				local sides = data[2]
				for i = 1, #sides do
					r.adjacent_rooms_per_side[sides[i]] = r.adjacent_rooms_per_side[sides[i]] or {}
					table.insert(r.adjacent_rooms_per_side[sides[i]], ar)
				end
			end
		end
	end)
end

function OnMsg.SlabVisibilityComputeDone()
	DelayedCall(0, RoomsPostProcess)
end

---
--- Iterates over all rooms in a building and calls the provided function for each room.
---
--- @param bld table The building to iterate over.
--- @param func function The function to call for each room.
--- @param ... any Additional arguments to pass to the function.
---
function ForEachRoomInBuilding(bld, func, ...)
	for floor, t in pairs(bld) do
		for i = 1, #t do
			func(t[i], ...)
		end
	end
end

function OnMsg.PreSaveMap()
	EnumVolumes(function(room)
		local ignore = room.ignore_zulu_invisible_wall_logic or room.outside_border
		for _, side_windows in pairs(room.spawned_windows) do
			local empty_idxes = {}
			for i, window in ipairs(side_windows) do
				if not window then
					table.insert(empty_idxes, i)
				else
					if ignore or window:IsInvulnerable() then
						window.AttachLight = false
					end
				end
			end
			for i = #empty_idxes, 1, -1 do
				table.remove(side_windows, empty_idxes[i])
			end
		end
		for _, side_doors in pairs(room.spawned_doors) do
			for _, door in ipairs(side_doors) do
				if ignore then
					door.AttachLight = false
					door.enabled = false
				end
				-- Fixup
				if not ignore and door:IsInvulnerable() then
					door.enabled = true
				end
			end
		end
	end)
end

function OnMsg.NewMapLoaded()
	EnumVolumes(function(room)
		if room.ignore_zulu_invisible_wall_logic then
			for _, side_doors in pairs(room.spawned_doors) do
				for _, door in ipairs(side_doors) do
					door.enabled = false
				end
			end
		end
	end)
end

---
--- Debugs and visualizes the buildings in the VolumeBuildings table.
--- This function iterates through the VolumeBuildings table and adds debug vectors
--- between the positions of the buildings in each floor.
---
--- If no buildings are found on a floor, a single debug vector is added at the
--- last building's position.
---
--- @function DbgShowBuildings
--- @return nil
function DbgShowBuildings()
	for i = 1, #VolumeBuildings do
		local bld = VolumeBuildings[i]
		local last = false
		local showed_something = false
		for floor, t in pairs(bld) do
			for i = 1, #t do
				if last then
					DbgAddVector(last:GetPos(), t[i]:GetPos() - last:GetPos())
					showed_something = true
				end
				last = t[i]
			end
		end
		if not showed_something then
			DbgAddVector(last:GetPos())
		end
	end
end