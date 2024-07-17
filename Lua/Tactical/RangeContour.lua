 -- offset against voxel border
const.ContoursOffset = -80
const.ContoursOffset_Merc = -85
const.ContoursOffset_BorderlineAttack = const.ContoursOffset -90
const.ContoursOffset_BorderlineTurn = const.ContoursOffset
-- z offset
const.ContoursOffsetZ = 15*guic
const.ContoursOffsetZ_Merc = const.ContoursOffsetZ +30
const.ContoursOffsetZ_BorderlineAttack = const.ContoursOffsetZ 
const.ContoursOffsetZ_BorderlineTurn = const.ContoursOffsetZ 
-- width
const.ContoursWidth = 480 / 5
const.ContoursWidth_Merc = const.ContoursWidth
const.ContoursWidth_BorderlineAttack = const.ContoursWidth
const.ContoursWidth_BorderlineTurn = const.ContoursWidth
-- turn radius
const.ContoursRadius2D = 180
const.ContoursRadius2D_Merc = 180
const.ContoursRadius2D_Merc_Exploration = 500
const.ContoursRadiusVertical = 80
const.ContoursRadiusSteps = 8
-- voxel connectivity
const.ContoursPassConnection = false
const.ContoursTunnelMask =
	const.TunnelMaskWalk
	| const.TunnelMaskClimbDrop
	| const.TunnelTypeLadder
	| const.TunnelTypeJumpOver1
	| const.TunnelTypeDoor
	| const.TunnelTypeWindow


---
--- Generates a range contour for the given set of voxels.
---
--- @param voxels table A table of voxels to generate the contour for.
--- @param contour_width number The width of the contour (default is `const.ContoursWidth`).
--- @param radius2D number The 2D radius of the contour (default is `const.ContoursRadius2D`).
--- @param offset number The offset of the contour from the voxel border (default is `const.ContoursOffset`).
--- @param offsetz number The z-offset of the contour (default is `const.ContoursOffsetZ`).
--- @param voxel_pass_connection boolean Whether to allow voxel pass connection (default is `const.ContoursPassConnection`).
--- @param tunnels_mask number The tunnels mask to use (default is `const.ContoursTunnelMask`).
--- @param exclude_voxels table A table of voxels to exclude from the contour.
--- @return table The contour as a table of polyline strings.
---
function GetRangeContour(voxels, contour_width, radius2D, offset, offsetz, voxel_pass_connection, tunnels_mask, exclude_voxels)
	if not voxels or #voxels == 0 then
		return
	end
	contour_width = contour_width or const.ContoursWidth
	radius2D = radius2D or const.ContoursRadius2D
	local radius_vertical = const.ContoursRadiusVertical
	offset = offset or const.ContoursOffset
	offsetz = offsetz or const.ContoursOffsetZ
	voxel_pass_connection = voxel_pass_connection or const.ContoursPassConnection
	tunnels_mask = tunnels_mask or const.ContoursTunnelMask
	local contours = GetContoursPStr(voxels, voxel_pass_connection, tunnels_mask, contour_width, radius2D, radius_vertical, offset, offsetz)
	return contours
end


local function RGBToModifier(r, g, b)
	local r = MulDivRound(r, 100, 255)
	local g = MulDivRound(g, 100, 255)
	local b = MulDivRound(b, 100, 255)
	return RGB(r, g, b)
end
---
--- Places a polyline contour mesh with the given contour, color, and shader.
---
--- @param contour table A table of polyline strings representing the contour.
--- @param color string|table The color of the contour mesh. Can be a string representing a text style ID or a table with RGBA values.
--- @param shader string The shader to use for the contour mesh. Defaults to "range_contour".
--- @return table A table of mesh objects representing the contour polyline.
---
function PlaceContourPolyline(contour, color, shader)
	local meshes = {
		SetVisible = function(self, value)
			for _, m in ipairs(self) do
				m:SetVisible(value)
			end
		end
	}
	shader = shader or "range_contour"
	if type(color) == "string" then
		color = Mesh.ColorFromTextStyle(color)
	else
		local r, g, b, opacity = GetRGBA(color)
		color = RGBToModifier(r, g, b)
	end
	for _, v_pstr in ipairs(contour) do
		local mesh = PlaceObject("Mesh")
		mesh:SetColorModifier(color)
		mesh:SetMesh(v_pstr)
		if not ProceduralMeshShaders[shader] then
			mesh:SetCRMaterial(shader)
		else
			mesh:SetShader(ProceduralMeshShaders[shader])
		end
		mesh:SetPos(0, 0, 0)
		table.insert(meshes, mesh)
	end
	return meshes
end

---
--- Places a single tile static contour mesh with the given color, position, and exploration flag.
---
--- @param color_textstyle_id string The text style ID for the color of the contour mesh.
--- @param pos table|nil The position to place the contour mesh. If not provided, the mesh will be placed at the origin.
--- @param exploration boolean Whether the contour mesh is for exploration.
--- @return table The placed contour mesh object.
---
function PlaceSingleTileStaticContourMesh(color_textstyle_id, pos, exploration)
	local r = const.SlabSizeX / 2 + const.ContoursOffset_Merc
	local z = const.ContoursOffsetZ_Merc
	local contour = GetRectContourPStr(box(-r, -r, z, r, r, z), const.ContoursWidth_Merc, exploration and const.ContoursRadius2D_Merc_Exploration or const.ContoursRadius2D_Merc)
	local polyline = PlaceContourPolyline({contour}, color_textstyle_id)
	if pos then
		polyline[1]:SetPos(pos)
	end
	return polyline[1]
end

---
--- Destroys the given mesh object.
---
--- @param mesh table The mesh object to destroy.
---
function DestroyMesh(mesh)
	if IsValid(mesh) then
		mesh:delete()
	end
end

---
--- Destroys the given contour polyline meshes.
---
--- @param meshes table The table of contour polyline meshes to destroy.
---
function DestroyContourPolyline(meshes)
	if not meshes then return end
	for _, mesh in ipairs(meshes) do
		DestroyMesh(mesh)
	end
	table.iclear(meshes)
end

---
--- Sets the visibility of the given contour polyline meshes.
---
--- @param meshes table The table of contour polyline meshes to set the visibility for.
--- @param visible boolean Whether the meshes should be visible or not.
---
function ContourPolylineSetVisible(meshes, visible)
	for _, mesh in ipairs(meshes) do
		if IsValid(mesh) then
			if visible then
				mesh:SetEnumFlags(const.efVisible)
			else
				mesh:ClearEnumFlags(const.efVisible)
			end
		end
	end
end

---
--- Sets the color of the given contour polyline meshes using the specified text style ID.
---
--- @param meshes table The table of contour polyline meshes to set the color for.
--- @param color_textstyle_id number The text style ID to use for setting the color.
---
function ContourPolylineSetColor(meshes, color_textstyle_id)
	for _, mesh in ipairs(meshes) do
		mesh:SetColorFromTextStyle(color_textstyle_id)
	end
end

---
--- Sets the shader of the given contour polyline meshes.
---
--- @param meshes table The table of contour polyline meshes to set the shader for.
--- @param shader string The name of the shader to use for the meshes.
---
function ContourPolylineSetShader(meshes, shader)
	shader = ProceduralMeshShaders[shader]
	for _, mesh in ipairs(meshes) do
		if mesh.shader ~= shader then
			mesh:SetShader(shader)
		end
	end
end

---
--- Places a ground rectangle mesh with the specified color and shader.
---
--- @param v_pstr string The mesh data for the ground rectangle.
--- @param color_textstyle_id number The text style ID to use for setting the color of the mesh.
--- @param shader string|CRMaterial The name of the shader or a CRMaterial to use for the mesh.
--- @return Mesh The placed ground rectangle mesh.
---
function PlaceGroundRectMesh(v_pstr, color_textstyle_id, shader)
	shader = shader or "ground_strokes"
	local mesh = PlaceObject("Mesh")
	if color_textstyle_id then
		mesh:SetColorFromTextStyle(color_textstyle_id)
	end
	mesh:SetMesh(v_pstr)
	mesh:SetPos(0, 0, 0)
	if IsKindOf(shader, "CRMaterial") then
		mesh:SetCRMaterial(shader)
	else
		mesh:SetShader(ProceduralMeshShaders[shader])
	end
	mesh:SetDepthTest(true)
	return mesh
end

local reload_prop_ids = {TextColor = true, ShadowColor = true, ShadowSize = true, }
---
--- Callback function that is called when a property of a `TextStyle` object is edited in the editor.
---
--- If the `TextStyle` object belongs to the "Zulu Ingame" group and the edited property is one of the properties in the `reload_prop_ids` table, this function will delay a call to `MapForEach` to update the color of all `Mesh` objects that use this `TextStyle`.
---
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The previous value of the edited property.
--- @param ged table The GED (Game Editor Data) object associated with the edited property.
---
function TextStyle:OnEditorSetProperty(prop_id, old_value, ged)
	if self.group == "Zulu Ingame" and reload_prop_ids[prop_id] then
		DelayedCall(300, MapForEach, "map", "Mesh", function(mesh)
			if mesh.textstyle_id == self.id then
				mesh:SetColorFromTextStyle(self.id)
			end
		end)
	end
end

DefineClass.CRM_RangeContourPreset = {
	__parents = { "CRMaterial" },
	group = "RangeContourPreset",
	properties = {
		{ uniform = true, id = "depth_softness", editor = "number", default = 0, scale = 1000, min = -2000, max = 2000, slider = true, },
		{ uniform = true, id = "fill_color", editor = "color", default = RGB(0, 255, 0) },
		{ uniform = true, id = "border_color", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "dash_color", editor = "color", default = RGB(255, 255, 255) },

		{ uniform = true, id = "fill_width", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },
		{ uniform = true, id = "border_width", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },
		{ uniform = true, id = "border_softness", editor = "number", default = 200, scale = 1000, min = 0, max = 1000, slider = true, },

		{ uniform = true, id = "dash_density", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "dash_segment", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 100000},

		{ uniform = true, id = "anim_speed", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 10000},
		{ uniform = true, id = "grain_strength", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "interlacing_strength", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1000},
	},

	shader_id = "range_contour_default",
}

DefineClass.CRM_RangeContourControllerPreset = {
	__parents = { "CRMaterial" },
	group = "RangeContourControllerPreset",

	shader_id = "combat_border",
	properties = {
		{ id = "contour_base_inside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_base_outside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_fx_inside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },
		{ id = "contour_fx_outside", editor = "preset_id", preset_class = "CRM_RangeContourPreset", default = false, },

		{ uniform = "integer", id = "fade_inout_start", editor = "number", scale = 1, default = 0, no_edit = true, dont_save = true, },
		{ uniform = true, id = "fade_in", editor = "number", scale = 1000, default = 200, min = 0, max = 2000, slider = true, },
		{ uniform = true, id = "cursor_alpha_distance", editor = "number", scale = 1000, default = 1000, min = 0, max = 3000, slider = true, },
		{ uniform = true, id = "cursor_alpha_falloff", editor = "number", scale = 1000, default = 1000, min = 0, max = 25000, slider = true, },
		
		{ uniform = "integer", id = "pop_in_start", editor = "number", scale = 1, default = 0, no_edit = true, dont_save = true,  },
		{ id = "pop_delay", editor = "number", scale = 1, default = 0, },
		{ uniform = true, id = "pop_in_time", editor = "number", scale = 1000, default = 500, slider = true, min = 0, max = 1200, },
		{ uniform = true, id = "pop_in_freq", editor = "number", scale = 1000, default = 200, slider = true, min = 0, max = 1200, },

		{ id = "is_inside", editor = "bool", default = false, no_edit = true, dont_save = true,  },

		{ uniform = true, id = "ZOffset", editor = "number", default = false, scale = 1000, no_edit = true, default = 0, }
	},
}

---
--- Recreates the CRM_RangeContourControllerPreset object by updating its internal buffer.
--- This function is responsible for writing the necessary preset data to the internal buffer,
--- which is then used by the rendering system to draw the range contour.
---
--- The function first checks if the preset is dirty, and if so, it proceeds to update the buffer.
--- It retrieves the appropriate CRM_RangeContourPreset objects based on whether the contour is
--- being drawn for the inside or outside of the range, and writes their data to the buffer.
--- Finally, it writes the CRM_RangeContourControllerPreset's own data to the buffer.
---
--- @param self CRM_RangeContourControllerPreset The instance of the CRM_RangeContourControllerPreset object.
function CRM_RangeContourControllerPreset:Recreate()
	self.dirty = false

	local pstr_buffer = self.pstr_buffer

	local preset = CRM_RangeContourPreset:GetById(self.is_inside and self.contour_base_inside or self.contour_base_outside)
	pstr_buffer = preset:WriteBuffer(pstr_buffer)

	local preset2 = CRM_RangeContourPreset:GetById(self.is_inside and self.contour_fx_inside or self.contour_fx_outside)
	pstr_buffer = preset2:WriteBuffer(pstr_buffer, 4 * 12)

	self:WriteBuffer(pstr_buffer, 4 * 12 * 2 )
	self.pstr_buffer = pstr_buffer
end

---
--- Sets whether the range contour is being drawn for the inside or outside of the range.
---
--- @param self CRM_RangeContourControllerPreset The instance of the CRM_RangeContourControllerPreset object.
--- @param value boolean Whether the contour is being drawn for the inside of the range.
--- @param notimereset boolean (optional) If true, the fade in/out timer will not be reset.
---
function CRM_RangeContourControllerPreset:SetIsInside(value, notimereset)
	value = value and true or false
	if self.is_inside ~= value then
		self.is_inside = value
		if not notimereset then
			self.fade_inout_start =  RealTime()
		end
		self.dirty = true
	end
end


DefineClass.RangeContourMesh = {
	__parents = {"Mesh"},

	preset_id = false,

	polyline = false,
	exclude_polyline = false,
	use_exclude_polyline = true,

	meshes = false,
	dirty_geometry = false,
}

---
--- Sets the polyline and exclude polyline for the RangeContourMesh.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param polyline table The polyline to use for the range contour.
--- @param exclude_polyline table The polyline to exclude from the range contour.
---
function RangeContourMesh:SetPolyline(polyline, exclude_polyline)
	self.polyline = polyline
	self.exclude_polyline = exclude_polyline
end

---
--- Sets the preset for the RangeContourMesh.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param preset CRM_RangeContourControllerPreset The preset to set for the RangeContourMesh.
---
function RangeContourMesh:SetPreset(preset)
	if type(preset) == "string" then
		preset = CRM_RangeContourControllerPreset:GetById(preset)
	end
	if self.CRMaterial and preset.id == self.CRMaterial.id  then
		return
	end
	self:SetCRMaterial(preset:Clone())
end

---
--- Sets the visibility of the RangeContourMesh.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param value boolean The visibility state to set.
---
function RangeContourMesh:SetVisible(value)
	if not g_PhotoMode then
		for _, mesh in ipairs(self.meshes or empty_table) do
			mesh:SetVisible(value)
		end
		if self.visible ~= value then
			self.CRMaterial.pop_in_start = RealTime() + self.CRMaterial.pop_delay
			self.visible = value
			self.CRMaterial.dirty = true
		end
	end
end
---
--- Sets whether the RangeContourMesh is considered inside or outside the range contour.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param value boolean The value to set the inside/outside state.
---
function RangeContourMesh:SetIsInside(value)
	self.CRMaterial:SetIsInside(value)
end

function RangeContourMesh:SetIsInside(value)
	self.CRMaterial:SetIsInside(value)
end

---
--- Sets whether the RangeContourMesh should use an exclude polyline.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param value boolean The value to set the use of the exclude polyline.
---
function RangeContourMesh:SetUseExcludePolyline(value)
	if self.use_exclude_polyline ~= value then
		self.use_exclude_polyline = value
		self.dirty_geometry = true
	end
end

---
--- Recreates the RangeContourMesh, optionally forcing a geometry update.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object.
--- @param force_geometry boolean (optional) If true, forces a geometry update.
---
function RangeContourMesh:Recreate(force_geometry)
	if #(self.meshes or empty_table) == 0 then
		force_geometry = true
	end
	if force_geometry or self.dirty_geometry then
		self.dirty_geometry = false
		for _, mesh in ipairs(self.meshes) do
			mesh:delete()
		end
		--self.polyline.side_len = 200
		self.meshes = PlaceContourPolyline(self.polyline, RGB(255, 255, 255), self.CRMaterial, self.use_exclude_polyline and self.exclude_polyline)
	else
		for _, mesh in ipairs(self.meshes) do
			mesh:SetCRMaterial(self.CRMaterial)
		end
	end
end

--- Deletes the RangeContourMesh object and all its associated meshes.
---
--- @param self RangeContourMesh The instance of the RangeContourMesh object to be deleted.
function RangeContourMesh:delete()
	for _, mesh in ipairs(self.meshes or empty_table) do
		mesh:delete()
	end
	self.meshes = false
	Mesh.delete(self)
end

---
--- Applies the CRMaterial to the current scene and updates the cached uniform buffer.
--- If the current map has a RangeContourMesh object with the same preset ID, it will be recreated.
---
--- @param self CRM_RangeContourPreset The instance of the CRM_RangeContourPreset object.
---
function CRM_RangeContourPreset:Apply()
	CRMaterial.Apply(self)
	self.cached_uniform_buf = self:GetDataPstr()
	if CurrentMap ~= "" then
		MapGet("map", "RangeContourMesh", function(o)
			if o.preset_id == self.id then
				o:Recreate()
			end
		end)
	end
end

RegisterSceneParam({
	id = "CursorPos", type = "float", elements = 3, default = { 0, 0, 0 }, scale = 1000, prop_id = false,
})
local cursor_pos_table = {0,0,0}
---
--- Updates the cursor position in the scene parameters.
---
--- This function is called repeatedly to update the cursor position in the scene parameters.
--- It retrieves the current cursor position, stores it in a local table, and then sets the
--- "CursorPos" scene parameter with the updated position. The interpolation time is set
--- to 0 if there are any pause reasons, or 33 otherwise.
---
--- @param pos Vector3 The current cursor position.
---
MapRealTimeRepeat("RangeContourSceneParam", 33, function()
	local pos = GetCursorPos()
	if pos then
		cursor_pos_table[1], cursor_pos_table[2], cursor_pos_table[3] = pos:xyz()
		local interp_time = next(PauseReasons) and 0 or 33
		SetSceneParamEx(1, "CursorPos", cursor_pos_table, interp_time)
	end
end)
