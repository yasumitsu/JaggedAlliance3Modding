local function FlavorAnimsCombo()
	local states = GetStates("Male")
	table.insert(states, 1, "")
	return states
end

DefineClass.WaypointMarker = {
	__parents = {"GridMarker"},
	properties =
	{
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "Waypoint", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes", no_edit = true },
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes", no_edit = true },
		{ category = "Marker", id = "Color",      name = "Color", editor = "color", default = RGB(255, 255, 0)},
		{ category = "Flavor", id = "FlavorAnim", name = "Animation", editor = "dropdownlist", items = FlavorAnimsCombo, default = "" },
	},
	EditorRolloverText = "Sequence of points to move between",
	EditorIcon = "CommonAssets/UI/Icons/refresh repost retweet.tga",
	recalc_area_on_pass_rebuild = false,
}

--- Filters a list of markers to only include WaypointMarker instances that have a valid position.
---
--- @param m table The marker to check.
--- @param group string The group the marker belongs to.
--- @return boolean True if the marker is a valid WaypointMarker, false otherwise.
marker_group_filter = function(m, group) return IsKindOf(m, "WaypointMarker") and m:IsValidPos() end

--- Initializes a new WaypointMarker instance.
---
--- This function sets the initial groups for the WaypointMarker and assigns a group number ID.
---
--- @param self WaypointMarker The WaypointMarker instance being initialized.
function WaypointMarker:Init()
	local init_groups = {"Waypoint"}
	self:SetGroups(init_groups)
	self:SetGroupNumberId(init_groups)
end

--- Removes the WaypointMarker from the map and updates the IDs of any other markers in the same group that have an ID greater than the current marker's ID.
---
--- This function is called when the WaypointMarker is deleted from the editor. It ensures that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence.
---
--- @param self WaypointMarker The WaypointMarker instance being deleted.
function WaypointMarker:OnDelete()
	if self.Groups and #self.Groups > 0 then
		self:AddToIndicesAfter(-1)
	end
end

--- Removes the WaypointMarker from the map and updates the IDs of any other markers in the same group that have an ID greater than the current marker's ID.
---
--- This function is called when the WaypointMarker is deleted from the editor. It ensures that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence.
---
--- @param self WaypointMarker The WaypointMarker instance being deleted.
function WaypointMarker:EditorCallbackDelete()
	self:OnDelete()
	GridMarker.EditorCallbackDelete(self)
end

--- Removes the WaypointMarker from the map and updates the IDs of any other markers in the same group that have an ID greater than the current marker's ID.
---
--- This function is called when the WaypointMarker is deleted from the editor. It ensures that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence.
---
--- @param self WaypointMarker The WaypointMarker instance being deleted.
function WaypointMarker:OnEditorDelete()
	self:OnDelete()
end

--- Called when a property of the WaypointMarker is changed in the editor.
---
--- This function is responsible for updating the group number ID of the marker when the "Groups" property is changed. It ensures that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence.
---
--- @param self WaypointMarker The WaypointMarker instance being modified.
--- @param prop string The name of the property that was changed.
--- @param old_value table The previous value of the "Groups" property.
--- @param ged table The editor GUI element associated with the property change.
--- @param multi boolean Indicates whether the property change is part of a multi-object edit.
function WaypointMarker:OnEditorSetProperty(prop, old_value, ged, multi)
	if prop ~= "Groups" then return end
	if multi then return end
	if old_value and #old_value > 0 then
		self:AddToIndicesAfter(-1, old_value[1])
	end
	self:SetGroupNumberId(self.Groups, "current marker on map")
end

--- Sets the group number ID of the WaypointMarker.
---
--- This function is responsible for setting the ID of the WaypointMarker based on the number of markers in the same group. If the `current_marker_on_map` parameter is true, the ID will be set to the current count of markers in the group. Otherwise, the ID will be set to the current count plus one.
---
--- @param self WaypointMarker The WaypointMarker instance.
--- @param groups table The groups the marker belongs to.
--- @param current_marker_on_map boolean Indicates whether the marker is the current one being placed on the map.
function WaypointMarker:SetGroupNumberId(groups, current_marker_on_map)
	local cnt = MapCountMarkers("GridMarker", groups[1], marker_group_filter)
	self.ID = tostring(current_marker_on_map and cnt or cnt + 1)
end

--- Clones the WaypointMarker and updates the IDs of any other markers in the same group that have an ID greater than the current marker's ID.
---
--- This function is called when the WaypointMarker is cloned in the editor. It ensures that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence.
---
--- @param self WaypointMarker The WaypointMarker instance being cloned.
--- @param marker WaypointMarker The cloned WaypointMarker instance.
--- @return boolean False if the WaypointMarker does not belong to any groups.
function WaypointMarker:EditorCallbackClone(marker)
	GridMarker.EditorCallbackClone(self, marker)
	if not self.Groups or #self.Groups == 0 then
		return false
	end
	marker:AddToIndicesAfter(1)
	self:SetID(tostring(tonumber(marker.ID) + 1))
end

--- Called when the WaypointMarker is moved in the editor.
---
--- This function is responsible for updating the drawn paths for any groups that the marker belongs to after the marker has been moved.
---
--- @param self WaypointMarker The WaypointMarker instance being moved.
function WaypointMarker:EditorCallbackMove()
	GridMarker.EditorCallbackMove(self)
	for _, group in ipairs(self.Groups) do
		DrawGroupPath(group)
	end
end

--- Adds the WaypointMarker to the indices after a given value, and updates the IDs of any other markers in the same group that have an ID greater than the current marker's ID.
---
--- This function is responsible for ensuring that the IDs of the remaining markers in the group are updated to maintain a contiguous sequence when a new marker is added.
---
--- @param self WaypointMarker The WaypointMarker instance.
--- @param value number The value to add to the indices.
--- @param group string The group the marker belongs to.
function WaypointMarker:AddToIndicesAfter(value, group)
	local markers = MapGetMarkers("GridMarker", group or self.Groups[1], marker_group_filter)
	local id = tonumber(self.ID)
	for i, m in ipairs(markers) do
		local m_id = tonumber(m.ID)
		if m_id and m_id > id then
			m:SetID(tostring(m_id + value))
		end
	end
end

--- Checks if the WaypointMarker is placed on an impassable surface or if it belongs to multiple groups, and returns an error message if either condition is true.
---
--- @return string|nil An error message if the marker is placed on an impassable surface or belongs to multiple groups, otherwise `nil`.
function WaypointMarker:GetError()
	if (IsKindOf(self, "WaypointMarker") or self.Type == "Entrance" or self.Type == "Defender") and not GetPassSlab(self) then
		return "Marker placed on impassable."
	end
	
	if self.Groups and #self.Groups > 1 then
		return "Waypoint markers should have only one group."
	end	
end

function OnMsg.EditorSelectionChanged(objects)
	objects = objects or {}
	local waypoint_groups = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "WaypointMarker") then
			if obj.Groups and #obj.Groups > 0 then
				waypoint_groups[obj.Groups[1]] = true
			end
		end
	end 
	
	UpdateDrawnGroupWaypointPaths(waypoint_groups)
end

---
--- Adds a thick line between two points with an optional thickness divisor and color.
---
--- @param p_pstr string The string to append the vertex data to.
--- @param p1 point The starting point of the line.
--- @param p2 point The ending point of the line.
--- @param thickness_divisor number (optional) The divisor to use for the thickness of the line. Defaults to 20.
--- @param color color (optional) The color of the line. Defaults to const.clrPaleBlue.
---
function AddThickLine(p_pstr, p1, p2, thickness_divisor, color)
	thickness_divisor = thickness_divisor or 20
	color = color or const.clrPaleBlue
	if not p1:IsValidZ() then
		p1 = p1:SetTerrainZ()
	end
	if not p2:IsValidZ() then
		p2 = p2:SetTerrainZ()
	end
	local dir = p2 - p1
	local orth = point(-dir:y(), dir:x())
	orth = Normalize(orth)
	local delta_vector = (orth/thickness_divisor):SetZ(0)
	p_pstr:AppendVertex(p1 + delta_vector,  color)
	p_pstr:AppendVertex(p2 + delta_vector)
	p_pstr:AppendVertex(p1 - delta_vector)
	p_pstr:AppendVertex(p1 - delta_vector)
	p_pstr:AppendVertex(p2 + delta_vector)
	p_pstr:AppendVertex(p2 - delta_vector)
end

MapVar("WaypointMarkersMeshes", {})
MapVar("LastTimeDrawnWaypointMarkerMeshes", false)

---
--- Updates the drawn waypoint paths for the specified groups.
---
--- @param groups_to_draw table A table of group names to draw waypoint paths for.
---
function UpdateDrawnGroupWaypointPaths(groups_to_draw)
	for group, value in pairs(groups_to_draw) do
		if value then
			DrawGroupPath(group)
		end
	end
	for group, value in pairs(WaypointMarkersMeshes) do
		if value and not groups_to_draw[group] then
			WaypointMarkersMeshes[group]:delete()
			WaypointMarkersMeshes[group] = false
		end
	end
end

---
--- Draws the waypoint paths for the specified group.
---
--- @param group string The name of the group to draw the waypoint paths for.
---
function DrawGroupPath(group)
	if WaypointMarkersMeshes[group] then
		WaypointMarkersMeshes[group]:delete()
		WaypointMarkersMeshes[group] = false
	end
	local waypoints = {}
	local impassable = {}
	local markers = MapGetMarkers("GridMarker", group, marker_group_filter)
	table.sort(markers, function(a, b) return a.ID < b.ID end)
	for i, marker in ipairs(markers) do
		local idx = table.find(markers, "ID", tostring(i))
		if not idx then
			return
		end
		local pass_pos = GetPassSlab(marker)
		waypoints[i] = pass_pos or marker:GetPos()
		impassable[i] = not pass_pos
	end
	local mesh = PlaceObject("Mesh")
	local p_pstr = pstr("")
	for i = 1, #waypoints - 1 do
		if impassable[i] or impassable[i+1] then
			AddThickLine(p_pstr, waypoints[i], waypoints[i+1], nil,const.clrRed)
		else
			if waypoints[i] ~= waypoints[i+1] then
				local has_path, closest_pos = pf.HasPosPath(waypoints[i], waypoints[i+1])
				if not has_path or closest_pos ~= waypoints[i+1] then
					assert(has_path, "Waypoint markers path blocked or two consecutive markers are too far.")
					break
				end
				local path = pf.GetPosPath(waypoints[i], waypoints[i+1])
				local p0 = path[#path]
				for i = #path-1, 1, -1 do
					local p1 = path[i]
					if p1:IsValid() then
						AddThickLine(p_pstr, p0, p1)
						p0 = p1
					end
				end
			end
		end
	end
	mesh:SetMesh(p_pstr)
	mesh:SetPos(0, 0, 0)
	WaypointMarkersMeshes[group] = mesh
end
