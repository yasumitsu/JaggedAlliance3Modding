local cardinal_dirs = {"east", "west", "north", "south"}
local dir_angle = { ["east"] = 90 * 60, ["west"] = 270 * 60, ["south"] = 180 * 60, ["north"] = 0 }

local function GetPlaneDir(plane)
	for _, dir in ipairs(cardinal_dirs) do
		if string.match(plane:lower(), dir) then
			return dir
		end
	end
end

MapVar("s_BorderBuildingAutoAttachesRequired", 0)
MapVar("s_BorderBuildingAutoAttachesCreated", 0)

DefineClass.BorderBuilding = {
	__parents = {"AutoAttachObject", "EditorCallbackObject", "EditorSelectedObject"},
	
	properties = {
		{category = "Windows Auto Attaches", id = "east", name = "East", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "west", name = "West", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "north", name = "North", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "south", name = "South", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "Recalc", editor = "buttons", default = false,
			buttons = {
				{ name = "Recalc Visible Sides", func = function(self)
					self:CalcVisibleSides()
				end},
				{ name = "Turn All Sides ON", func = function(self)
					self:TurnAllSides(true)
				end},
				{ name = "Turn All Sides OFF", func = function(self)
					self:TurnAllSides(false)
				end},
			},
		},
	},
	
	texts = false,
}

---
--- Determines whether an object should be automatically attached to the BorderBuilding.
---
--- @param attach AutoAttachObject The object to check for attachment.
--- @return boolean Whether the object should be attached.
function BorderBuilding:ShouldAttach(attach)
	s_BorderBuildingAutoAttachesRequired = s_BorderBuildingAutoAttachesRequired + 1
	
	local spot_ann = self:GetSpotAnnotation(attach.spot_idx)
	if not spot_ann then return true end
	
	local dir = GetPlaneDir(spot_ann)
	if not dir then return true end
	
	return self[dir]
end

---
--- Handles the creation of an attached object to the BorderBuilding.
---
--- If the attached object is a WindowTunnelObject or Door, sets its AttachLight property to false.
---
--- @param attach AutoAttachObject The object that was attached.
--- @param spot table The spot information for the attachment.
---
function BorderBuilding:OnAttachCreated(attach, spot)
	s_BorderBuildingAutoAttachesCreated = s_BorderBuildingAutoAttachesCreated + 1
	
	if IsKindOfClasses(attach, "WindowTunnelObject", "Door") then
		attach.AttachLight = false
	end
end

---
--- Updates the auto-attach mode for the BorderBuilding.
---
--- This function is responsible for setting the auto-attach mode for the BorderBuilding. It is likely called when the auto-attach mode needs to be updated, such as when the BorderBuilding's properties change.
---
function BorderBuilding:UpdateAutoAttaches()
	self:SetAutoAttachMode(self:GetAutoAttachMode())
end

---
--- Gathers the wall windows for the BorderBuilding.
---
--- This function collects the wall windows (spots) for the BorderBuilding and organizes them into a planes table and a sides table.
---
--- The planes table maps the spot annotation to a table of spot information, where each spot has a position, name, and index.
--- The sides table maps the cardinal direction to a table of spot information.
---
--- @return table, table The planes and sides tables.
---
function BorderBuilding:GatherWallWindows()
	local spots_used = {}
	local spots = table.imap(AutoAttachPresets[self.class], function(attach)
		spots_used[attach.name] = true
	end)
	local spots = table.keys(spots_used)
	
	local planes = {}
	local sides = {}
	for _, spot_name in ipairs(spots) do
		local first, last = self:GetSpotRange(spot_name)
		for spot_idx = first, last do
			local spot_pos = self:GetSpotPos(spot_idx)
			local spot_ann = self:GetSpotAnnotation(spot_idx)
			if spot_ann then
				local dir = GetPlaneDir(spot_ann)
				if dir then
					local spot = {pos = spot_pos, name = spot_name, idx = spot_idx}
					planes[spot_ann] = planes[spot_ann] or {dir = dir}
					table.insert(planes[spot_ann], spot)
					sides[dir] = sides[dir] or {}
					table.insert(sides[dir], spot)
				end
			end
		end
	end
	
	return planes, sides
end

---
--- Calculates the visible sides of the BorderBuilding.
---
--- This function is responsible for determining which sides of the BorderBuilding are visible from the map center. It does this by gathering the wall windows (spots) for the BorderBuilding, calculating the angle of each plane, and then checking if the plane is facing the map center. The visibility information is then stored in the BorderBuilding's properties.
---
--- @param self BorderBuilding The BorderBuilding instance.
---
function BorderBuilding:CalcVisibleSides()
	local center = GetMapBox():Center()
	local planes, sides = self:GatherWallWindows()
	local side_count = {}
	for plane_name, plane in pairs(planes) do
		local dir = GetPlaneDir(plane_name)
		local angle = self:GetAngle() + dir_angle[dir]
		local plane_norm = Rotate(point(4096, 0), angle)
		local plane_data = side_count[dir] or {total = 0, visible = 0}
		side_count[dir] = plane_data
		plane_data.total = plane_data.total + #plane
		if Dot(center - plane[1].pos, plane_norm) > 0 then
			plane_data.visible = plane_data.visible + #plane			
		end
	end
	
	for dir, side in pairs(side_count) do
		self:SetProperty(dir, side.visible > side.total / 2)
	end
	ObjModified(self)
	
	self:UpdateAutoAttaches()
end

---
--- Sets the visibility state of all sides of the BorderBuilding.
---
--- This function is used to set the visibility state of all sides of the BorderBuilding. It iterates through the cardinal directions and sets the visibility property for each side. After updating the properties, it calls `ObjModified(self)` to notify the engine of the changes, and then calls `UpdateAutoAttaches()` to update any attached objects.
---
--- @param self BorderBuilding The BorderBuilding instance.
--- @param state boolean The new visibility state for all sides.
---
function BorderBuilding:TurnAllSides(state)
	for _, dir in pairs(cardinal_dirs) do
		self:SetProperty(dir, state)
	end
	ObjModified(self)
	self:UpdateAutoAttaches()
end

---
--- Called when a property of the BorderBuilding is set in the editor.
---
--- This function is called when a property of the BorderBuilding is set in the editor. If the property being set is one of the cardinal directions, it calls the `UpdateAutoAttaches()` function to update any attached objects.
---
--- @param self BorderBuilding The BorderBuilding instance.
--- @param prop_id string The ID of the property that was set.
---
function BorderBuilding:OnEditorSetProperty(prop_id)
	if table.find(cardinal_dirs, prop_id) then
		self:UpdateAutoAttaches()
	end
end

---
--- Delays the recalculation of auto-attached objects for the BorderBuilding.
---
--- This function is called when the BorderBuilding is moved, rotated, or placed in the editor. It delays the recalculation of auto-attached objects by 500 milliseconds, then calls `CalcVisibleSides()` and `UpdateAutoAttaches()` to update the visibility and auto-attached objects.
---
--- @param self BorderBuilding The BorderBuilding instance.
---
function BorderBuilding:DelayedRecalcAutoAttaches()
	DelayedCall(500, function(self)
		self:CalcVisibleSides()
		self:UpdateAutoAttaches()
	end, self)
end

BorderBuilding.EditorCallbackMove = BorderBuilding.DelayedRecalcAutoAttaches
BorderBuilding.EditorCallbackRotate = BorderBuilding.DelayedRecalcAutoAttaches
BorderBuilding.EditorCallbackPlace = BorderBuilding.DelayedRecalcAutoAttaches

---
--- Called when the BorderBuilding is selected in the editor.
---
--- This function is called when the BorderBuilding is selected in the editor. It performs the following actions:
---
--- 1. Calculates the center position and maximum height of the BorderBuilding.
--- 2. Gathers the wall and window positions for each cardinal direction.
--- 3. For each cardinal direction, creates a text object at the average position of the wall/window spots and attaches it to the BorderBuilding.
--- 4. Stores the created text objects in the `self.texts` table.
---
--- When the BorderBuilding is deselected, this function detaches and destroys the created text objects.
---
--- @param self BorderBuilding The BorderBuilding instance.
--- @param selected boolean True if the BorderBuilding is selected, false if deselected.
---
function BorderBuilding:EditorSelect(selected)
	if selected then
		local center = self:GetPos()
		local high_z = self:GetObjectBBox():sizez() + guim
		local _, sides = self:GatherWallWindows()
		for dir, spots in pairs(sides) do
			local pos = point30
			for _, spot in pairs(spots) do
				pos = pos + spot.pos - center
			end
			pos = (pos / #spots):SetZ(high_z)
			local text = PlaceText(dir:upper(), pos, const.clrGreen)
			self:Attach(text)
			text:SetAttachOffset(pos)
			self.texts = self.texts or {}
			table.insert(self.texts, text)
		end
	elseif self.texts then
		for _, text in ipairs(self.texts) do
			if IsValid(text) then
				text:Detach()
				DoneObject(text)
			end
		end
		self.texts = false
	end
end

---
--- Recalculates the visible sides of all BorderBuilding objects in the map and updates their auto-attaches.
---
--- This function iterates through all BorderBuilding objects in the map, calls their `CalcVisibleSides()` and `UpdateAutoAttaches()` methods, and keeps track of the number of auto-attaches that were created and required. It then prints a summary of the BorderBuilding and auto-attach statistics.
---
--- @function BorderBuildingsRecalcVisibleSides
--- @return nil
function BorderBuildingsRecalcVisibleSides()
	s_BorderBuildingAutoAttachesRequired = 0
	s_BorderBuildingAutoAttachesCreated = 0
	
	local buildings = 0
	MapForEach("map", "BorderBuilding", function(bld)
		buildings = buildings + 1
		bld:CalcVisibleSides()
		bld:UpdateAutoAttaches()
	end)
	
	printf("BorderBuilding(s): %d, Auto Attaches Created/Required: %d/%d(%d%%)", buildings, 
		s_BorderBuildingAutoAttachesCreated, s_BorderBuildingAutoAttachesRequired, 
		100 * s_BorderBuildingAutoAttachesCreated / s_BorderBuildingAutoAttachesRequired)
end

---
--- Toggles the visibility of a wall on a BorderBuilding object.
---
--- @param dir string The direction of the wall to toggle (e.g. "north", "south", "east", "west")
--- @return nil
function SelectionBorderBuildingToggleWall(dir)
	for _, obj in ipairs(editor.GetSel() or empty_table) do
		if IsKindOf(obj, "BorderBuilding") then
			obj:SetProperty(dir, not obj:GetProperty(dir))
			obj:UpdateAutoAttaches()
		end
	end
end
