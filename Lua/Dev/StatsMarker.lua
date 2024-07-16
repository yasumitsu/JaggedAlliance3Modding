DefineClass.StatsMarker = {
	__parents = { "GridMarker" },
	properties =
	{
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "Stats", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 10, help = "Defining a voxel-aligned rectangle with North-South and East-West axes" },
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 10, help = "Defining a voxel-aligned rectangle with North-South and East-West axes" },
		{ category = "Marker", id = "Color",      name = "Color", editor = "color", default = const.clrYellow},
		{ category = "Marker", id = "Reachable",  name = "Reachable only", editor = "bool", default = false, no_edit = true},
	},
	stats_text = false,
	vertex_weight = false,
	moved = false,
}

local stats_marker_z_offset = 5000
---
--- Updates the text statistics displayed on the StatsMarker object.
---
--- @param obj_cnt number The number of objects in the marker's area.
--- @param obj_vcnt number The total number of vertices for the objects in the marker's area.
--- @param obj_tcnt number The total number of triangles for the objects in the marker's area.
--- @param shadow_cnt number The number of shadow objects in the marker's area.
--- @param shadow_vcnt number The total number of vertices for the shadow objects in the marker's area.
--- @param shadow_tcnt number The total number of triangles for the shadow objects in the marker's area.
--- @param pt_cnt number The number of point light shadow objects in the marker's area.
--- @param pt_vcnt number The total number of vertices for the point light shadow objects in the marker's area.
--- @param pt_tcnt number The total number of triangles for the point light shadow objects in the marker's area.
--- @param sp_cnt number The number of spot light shadow objects in the marker's area.
--- @param sp_vcnt number The total number of vertices for the spot light shadow objects in the marker's area.
--- @param sp_tcnt number The total number of triangles for the spot light shadow objects in the marker's area.
---
function StatsMarker:UpdateTextStats(obj_cnt, obj_vcnt,  obj_tcnt, shadow_cnt, shadow_vcnt, shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt)
	if not IsValid(self.stats_text) then
		self:DestroyAttaches("Text")
		local text = PlaceObject("Text")
		text:SetTextStyle("InfoText")
		text:SetShadowOffset(2)
		self.stats_text = text
		self:Attach(text)
		text:SetAttachOffset(0, 0, stats_marker_z_offset)
	end
	local text = ""
	if obj_cnt > 0 or shadow_cnt > 0 then
		text = string.format("Main + Shadow: %d/v%dK/t%dK\n", obj_cnt + shadow_cnt, (obj_vcnt + shadow_vcnt)/1000, (obj_tcnt + shadow_tcnt)/1000)
	end
	if pt_cnt > 0 or pt_vcnt > 0 or pt_tcnt > 0 then
		text = string.format("%sPoint light shadow: %d/v%dK/t%dK\n", text, pt_cnt, pt_vcnt/1000, pt_tcnt/1000)
	end
	if sp_cnt > 0 then
		text = string.format("%sSpot light shadow: %d/v%dK/t%dK\n", text, sp_cnt, sp_vcnt/1000, sp_tcnt/1000)
	end
	self.stats_text:SetText(text)
	self.stats_text:SetColor(self.Color)
end

---
--- Returns the bounding box of the StatsMarker object.
---
--- @return box The bounding box of the StatsMarker object.
---
function StatsMarker:GetBox()
	local pos = self:GetPos()
	local width = self.AreaWidth*const.SlabSizeX
	local height = self.AreaHeight*const.SlabSizeY
	local area_left = pos:x() - width/2 - const.SlabSizeX / 2
	local area_top = pos:y() - height/2 - const.SlabSizeY / 2
	return box(area_left, area_top, area_left + width, area_top + height)
end

local excl_classes = {"EditorMarker", "Unit", "AppearanceObject", "Light", "InvisibleObjectHelper"}
---
--- Visualizes the rendering statistics for the StatsMarker object.
---
--- This function calculates the number of objects, vertices, and triangles in the
--- marker's area, including main objects, shadow objects, point light shadows,
--- and spot light shadows. It then updates the text display on the marker to
--- show these statistics, and changes the color of the marker based on the total
--- number of vertices.
---
--- If the marker has been moved, this function also updates the visual
--- representation of the marker's area on the terrain.
---
--- @param self StatsMarker The StatsMarker object.
---
function StatsMarker:VisualizeStats()
	if not IsEditorActive() then return end
	local obj_cnt, obj_vcnt,  obj_tcnt, shadow_cnt, shadow_vcnt,
			shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt = GetBoxRenderingStats(self:GetBox(), excl_classes)
	local vertices = (obj_vcnt + shadow_vcnt + pt_vcnt + sp_vcnt)/1000
	local color
	if vertices < 600 then
		color = RGB(0, 255, 0)
	elseif vertices < 1000 then
		color = RGB(224, 224, 0)
	else 
		color = RGB(255, 0, 0)
	end
	self:SetColor(color)
	self:UpdateTextStats(obj_cnt, obj_vcnt, obj_tcnt, shadow_cnt, shadow_vcnt, shadow_tcnt, pt_cnt, pt_vcnt, pt_tcnt, sp_cnt, sp_vcnt, sp_tcnt)
	if self.moved or not self.area_ground_mesh then
		self.moved = false
		self:ShowArea()
	end
end

---
--- Recalculates the area positions of the StatsMarker object.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
function StatsMarker:RecalcAreaPositions()
end

---
--- Visualizes the area of the StatsMarker object on the terrain.
---
--- This function creates a terrain box that represents the area of the StatsMarker
--- object. The box is positioned and sized based on the StatsMarker's bounding box,
--- and its color is set to the StatsMarker's current color.
---
--- If the StatsMarker's area has already been visualized, the existing terrain box
--- is first deleted before creating a new one.
---
--- @param self StatsMarker The StatsMarker object.
---
function StatsMarker:ShowArea()
	local _ = self.area_ground_mesh and self.area_ground_mesh:delete()
	self.area_ground_mesh = PlaceTerrainBox(self:GetBox():grow(-500, -500), self.Color)
end

---
--- Called when the StatsMarker object is moved in the editor.
---
--- This function is called when the StatsMarker object is moved in the editor.
--- It updates the `moved` flag of the StatsMarker object and calls the `VisualizeStats()`
--- function to update the visual representation of the StatsMarker.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
---
function StatsMarker:EditorCallbackMove()
	VoxelSnappingObj.EditorCallbackMove(self)
	self.moved = true
	self:VisualizeStats()
end

---
--- Called when the StatsMarker object is placed in the editor.
---
--- This function is called when the StatsMarker object is placed in the editor.
--- It adds the StatsMarker to the global g_StatsMarkers table, sets the `moved`
--- flag, and calls the `VisualizeStats()` function to update the visual
--- representation of the StatsMarker.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
---
function StatsMarker:EditorCallbackPlace()
	GridMarker.EditorCallbackPlace(self)
	g_StatsMarkers = g_StatsMarkers or {}
	table.insert(g_StatsMarkers, self)
	self.moved = true
	CreateRealTimeThread(function(self)
		self:VisualizeStats()
	end, self)
end

---
--- Called when the StatsMarker object is deleted from the editor.
---
--- This function is called when the StatsMarker object is deleted from the editor.
--- It removes the StatsMarker from the global g_StatsMarkers table.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
---
function StatsMarker:EditorCallbackDelete()
	GridMarker.EditorCallbackDelete(self)
	if not g_StatsMarkers then return end
	table.remove_entry(g_StatsMarkers, self)
end

MapVar("g_StatsMarkers", false)
if FirstLoad then
	g_StatsMarkersThread = false
end

function OnMsg.GameEnterEditor()
	if not g_StatsMarkers then
		g_StatsMarkers = MapGetMarkers("Stats") or false
	end
	if not g_StatsMarkersThread then
		g_StatsMarkersThread = CreateRealTimeThread(function()
			while true do
				Sleep(5000)
				if IsEditorActive() then
					for _, m in ipairs(g_StatsMarkers or empty_table) do
						m:VisualizeStats()
					end
				end
			end
		end)
	end
end

if FirstLoad then
	g_DbgStatsMarkersVertexSorted = false
	StatsMarkerDbgActionIdx = false
end

local half_box_size_outdoor = 8
local half_box_size_underground = 5
---
--- Populates the map with StatsMarker objects and stores their vertex count information.
---
--- This function is responsible for placing StatsMarker objects on the map at regular intervals.
--- It calculates the position and size of the StatsMarkers based on the current map type (underground or outdoor).
--- The function also stores the vertex count information for each StatsMarker in the `g_DbgStatsMarkersVertexSorted` table, which is sorted by vertex count.
--- Finally, it calls the `PrintLightsTotalStats` function to print the total number of point and spot lights in the map.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
function PopulateMapWithStatsMarkers()
	g_StatsMarkers = g_StatsMarkers or {}
	local half_area_size = IsCurrentMapUnderground() and half_box_size_underground or half_box_size_outdoor
	local first_x = half_area_size*const.SlabSizeX + const.SlabSizeX/2
	local max_x = terrain.GetMapWidth()
	local step_x = 2*half_area_size*const.SlabSizeX
	local first_y = half_area_size*const.SlabSizeY + const.SlabSizeY/2
	local max_y = terrain.GetMapHeight()
	local step_y = 2*half_area_size*const.SlabSizeY
	g_DbgStatsMarkersVertexSorted = {}
	
	for x = first_x, max_x, step_x do
		for y = first_y, max_y, step_y do
			local sm = PlaceObject("StatsMarker")
			if not IsCurrentMapUnderground() then
				sm.AreaWidth = 2*half_box_size_outdoor
				sm.AreaHeight = 2*half_box_size_outdoor
			end
			sm:SetPos(x, y, const.InvalidZ)
			if IsEditorActive() then
				sm:SetHierarchyEnumFlags(const.efVisible)
			end
			table.insert(g_StatsMarkers, sm)
			
			local _, obj_vcnt,  _, _, shadow_vcnt, _, _, pt_vcnt, _, _, sp_vcnt = GetBoxRenderingStats(sm:GetBox())
			sm.vertex_weight = obj_vcnt + shadow_vcnt + pt_vcnt + sp_vcnt
			table.insert(g_DbgStatsMarkersVertexSorted, sm)
			if IsEditorActive() then
				sm:VisualizeStats()
			end
		end
	end
	table.sortby_field(g_DbgStatsMarkersVertexSorted, "vertex_weight")
	PrintLightsTotalStats()
end

---
--- Prints the total number of point and spot lights in the current map.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
function PrintLightsTotalStats()
	local _, _, _, _, _, _, pt_lights, _, _, sp_lights = GetBoxRenderingStats(GetMapBox())
	print(string.format("Point Lights: %d, Spot Lights: %d, Total Lights: %d", pt_lights, sp_lights, pt_lights + sp_lights))
end

---
--- Deletes all StatsMarker objects from the game and resets the global tables that store them.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param self StatsMarker The StatsMarker object.
function DeleteAllStatsMarkers()
	for _, m in ipairs(g_StatsMarkers or empty_table) do
		DoneObject(m)
	end
	g_StatsMarkers = false
	g_DbgStatsMarkersVertexSorted = false
end

local view_stats_marker_dist = 30000
---
--- Displays the StatsMarker object with the Nth highest vertex count.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- @param rank number The rank of the StatsMarker object to display, where 1 is the highest vertex count.
function ViewHeaviestStatsMarker(rank)
	if not g_DbgStatsMarkersVertexSorted then return end
	ViewObject(g_DbgStatsMarkersVertexSorted[#g_DbgStatsMarkersVertexSorted - rank + 1], view_stats_marker_dist)
end

---
--- Cycles through a series of debug actions related to StatsMarker objects in the current map.
---
--- This function is an internal implementation detail and is not part of the
--- public API of the StatsMarker class.
---
--- The actions performed by this function are:
--- 1. Populate the map with StatsMarker objects (if not already done)
--- 2. View the StatsMarker object with the Nth highest vertex count, where N is the current index
--- 3. Delete all StatsMarker objects from the map and reset the global tables
---
--- @param self StatsMarker The StatsMarker object.
function StatsMarkerDebugNext()
	if not StatsMarkerDbgActionIdx then
		PopulateMapWithStatsMarkers()
		StatsMarkerDbgActionIdx = 1
	elseif StatsMarkerDbgActionIdx == 5 then
		DeleteAllStatsMarkers()
		StatsMarkerDbgActionIdx = false
	else
		ViewHeaviestStatsMarker(StatsMarkerDbgActionIdx)
		StatsMarkerDbgActionIdx = StatsMarkerDbgActionIdx + 1
	end
end

function OnMsg.NewMapLoaded()
	StatsMarkerDbgActionIdx = false
end

local underground_maps = {
	"H-3 - Bunker FB45-68",
	"L-6U - Underground Prison",
}
---
--- Checks if the current map is an underground map.
---
--- @return boolean true if the current map is an underground map, false otherwise
function IsCurrentMapUnderground()
	return table.find(underground_maps, mapdata.id)
end