DefineClass.Ladder = {
	__parents = {"Object", "TunnelObject", "FloorAlignedObj", "EditorCallbackObject"},
	
	properties = {
		category = "Ladder",
		{id = "LadderParts", name = "Ladder Parts", editor = "number", default = 0},
		{id = "Material", name = "Material", editor = "preset_id", preset_class = "LaddersMaterials", default = "Ladder_Metal", },
	},
	default_entity = "Ladder_Metal_01",
	
	tunnels = false,
}

--- Initializes the Ladder object by setting the Material property based on the Ladder entity name.
---
--- This function is called during the initialization of the Ladder object. It extracts the material name from the Ladder entity name and sets the Material property accordingly.
---
--- @param self Ladder The Ladder object being initialized.
function Ladder:Init()
	local material = string.match(self:GetEntity(), "([%w_]+)_%d+$")
	self:SetProperty("Material", material)
end

--- Updates the color modifier of the Ladder object.
---
--- This function is called during the initialization of the Ladder object. It updates the color modifier of the Ladder object, which is likely used to control the visual appearance of the ladder.
---
--- @param self Ladder The Ladder object being initialized.
function Ladder:GameInit()
	self:UpdateColorModifier()
end

--- Places the tunnels for the Ladder object.
---
--- This function is called to update the tunnels for the Ladder object. It checks if the Ladder has a parent object, and if not, it calls the `UpdateTunnels()` function to update the tunnels.
---
--- @param self Ladder The Ladder object.
function Ladder:PlaceTunnels()
	if self:GetParent() then
		return
	end
	self:UpdateTunnels()
end

--- Calculates the cost of a ladder object based on the number of ladder parts.
---
--- The cost of a ladder is determined by the number of ladder parts, where each step has a fixed cost. The total cost is calculated by multiplying the number of ladder parts plus one (to account for the base) by the cost per step.
---
--- @param self Ladder The ladder object.
--- @return number The total cost of the ladder.
function Ladder:GetCost()
	local cost_per_step = Presets.ConstDef["Action Point Costs"]["LadderStep"].value
	local steps = self.LadderParts
	local cost = (steps + 1) * cost_per_step
	return cost
end

local voxel_z = const.SlabSizeZ
local voxel_step = point(0, 0, voxel_z)
local GetHeight = terrain.GetHeight

--- Gets the positions of the tunnels for the ladder.
---
--- This function calculates the positions of the tunnels for the ladder based on the ladder's position and orientation. It first checks if there are any ladder parts attached, and if not, it returns. Otherwise, it retrieves the offset of the first attached ladder part and uses that to calculate the positions of the tunnel start and end points. The function ensures that the tunnel start and end points are not too close together, and that there is a sufficient height difference between them. If the conditions are met, the function returns the coordinates of the tunnel start and end points.
---
--- @param self Ladder The ladder object.
--- @return number, number, number, number, number, number The coordinates of the tunnel start and end points, or nil if the tunnel cannot be placed.
function Ladder:GetTunnelPositions()
	if self.LadderParts <= 0 then
		return
	end
	local first_attach = self:GetAttach(1)
	local offset = first_attach and first_attach:GetAttachOffset() or point30
	if offset == point30 then
		return
	end
	local offsetx, offsety, offsetz = offset:xyz()
	local dx, dy = RotateRadius(const.SlabSizeX, self:GetAngle(), 0, true)
	local posx, posy, posz = self:GetPosXYZ()
	if not posz then
		posz = GetHeight(posx, posY)
	end
	local x1, y1, z1 = GetPassSlabXYZ(posx + offsetx, posy + offsety, posz + offsetz)
	local x2, y2, z2 = GetPassSlabXYZ(posx + dx, posy + dy, posz)
	if not x1 or not x2 or x1 == x2 and y1 == y2 and z1 == z2 then
		return
	end
	local h1 = z1 or GetHeight(x1, y1)
	local h2 = z2 or GetHeight(x2, y2)
	if abs(h1 - h2) < const.SlabSizeZ then
		return
	end
	return x1, y1, z1, x2, y2, z2
end

---
--- Destroys any ladder parts that are sinking below the terrain level.
---
--- This function checks the position of each ladder part attached to the ladder object. If a ladder part's position is below the terrain level, it is detached from the ladder and destroyed.
---
--- @param self Ladder The ladder object.
---
function Ladder:DestroySinkingParts()
	local pos = self:GetPos()
	pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
	local slab_obj, floor_level = WalkableSlabByPoint(pos, true)
	for i = self.LadderParts, 1, -1 do
		local ladder_part = self:GetAttach(i)
		local ladder_pos = pos + ladder_part:GetAttachOffset()
		if ladder_pos:z() + voxel_z < floor_level then
			ladder_part:Detach()
			DoneObject(ladder_part)
			self.LadderParts = self.LadderParts - 1
		end
	end
	GedObjectModified(self)
end

---
--- Gets the material subvariants for the ladder.
---
--- This function retrieves the material, subvariants, and total number of subvariants for the ladder's material.
---
--- @param self Ladder The ladder object.
--- @return string material The material of the ladder.
--- @return table subvariants The subvariants of the material.
--- @return number total The total number of subvariants.
---
function Ladder:GetMaterialSubvariants()
	local material = self:GetProperty("Material")
	local material_preset = Presets.SlabPreset.LaddersMaterials[material] or empty_table
	local subvariants, total = GetMaterialSubvariants(material_preset)
	
	return material, subvariants, total
end

---
--- Updates the material of a ladder part.
---
--- This function is used to update the material, subvariants, and random variation of a ladder part. It can be used to create a new ladder part or update an existing one.
---
--- @param ladder_part table|Point3 The ladder part to update. If this is a table, it is treated as an offset from the ladder's position. If it is a Point3, a new ladder part is created at that position.
--- @param material string The material to use for the ladder part.
--- @param subvariants table The subvariants of the material.
--- @param total number The total number of subvariants.
--- @param offset Point3 The offset to use when creating a new ladder part. Defaults to point30.
---
function Ladder:UpdateLadderPartMaterial(ladder_part, material, subvariants, total, offset)
	offset = offset or point30
	
	local create_part = IsPoint(ladder_part)
	local pos = self:GetPos() + (create_part and ladder_part or ladder_part:GetAttachOffset())
	local hash_pos = pos + (create_part and ladder_part or offset)
	local random = BraidRandom(EncodeVoxelPos(hash_pos), total)
	local entity = self:GenerateLadderPartEntity(material, subvariants, total, random)
	
	if create_part then
		local offset = ladder_part
		ladder_part = PlaceObject(entity)
		self:Attach(ladder_part)
		ladder_part:SetAttachOffset(offset)
	else
		ladder_part:ChangeEntity(entity)
	end
	ladder_part:SetProperty("Material", material)
end

---
--- Extends the ladder to the bottom of the terrain.
---
--- This function extends the ladder to the bottom of the terrain, adding additional ladder parts as needed. It uses the current ladder's material, subvariants, and total subvariants to create the new ladder parts.
---
--- @param pieces number (optional) The number of additional ladder pieces to add. If not provided, the ladder will be extended until it reaches the terrain floor.
--- @param ladder_parts number (optional) The current number of ladder parts. If not provided, the function will use the value from `self.LadderParts`.
---
function Ladder:ExtendToBottom(pieces, ladder_parts)
	ladder_parts = ladder_parts or self.LadderParts

	local attach_offset = -(ladder_parts + 1) * voxel_step
	local pos = self:GetPos()
	pos = pos:IsValidZ() and pos or pos:SetTerrainZ()
	local slab_obj, floor_level = WalkableSlabByPoint(pos, true)
	pos = pos + attach_offset

	local material, subvariants, total = self:GetMaterialSubvariants()
	self:UpdateLadderPartMaterial(self, material, subvariants, total)
	while (pieces and pieces > 0) or (not pieces and pos:z() + voxel_z >= floor_level) do
		self:UpdateLadderPartMaterial(attach_offset, material, subvariants, total)
		ladder_parts = ladder_parts + 1
		pos, attach_offset = pos - voxel_step, attach_offset - voxel_step
		pieces = pieces and (pieces - 1)
	end
	self.LadderParts = ladder_parts
	self:UpdateColorModifier()
	GedObjectModified(self)
end

local color_prop_names = { "ColorModifier" }
for i = 1, const.MaxColorizationMaterials do
	table.insert(color_prop_names, "EditableColor" .. i)
	table.insert(color_prop_names, "EditableMetallic" .. i)
	table.insert(color_prop_names, "EditableRoughness" .. i)
end

---
--- Updates the color modifier properties of all ladder parts.
---
--- This function retrieves the current values of the color modifier properties (ColorModifier, EditableColor1-MaxColorizationMaterials, EditableMetallic1-MaxColorizationMaterials, EditableRoughness1-MaxColorizationMaterials) from the ladder object, and then sets those same property values on each of the ladder's attached parts.
---
--- This ensures that any changes made to the color modifier properties of the ladder object are propagated to all of its attached parts.
---
function Ladder:UpdateColorModifier()
	local prop_value = {}
	for _, prop_id in ipairs(color_prop_names) do
		prop_value[prop_id] = self:GetProperty(prop_id)
	end
	for i = 1, self.LadderParts do
		local ladder_part = self:GetAttach(i)
		for _, prop_id in ipairs(color_prop_names) do
			ladder_part:SetProperty(prop_id, prop_value[prop_id])
		end
	end
end

---
--- Updates the tunnels associated with the ladder.
---
--- This function first removes any existing tunnels associated with the ladder, then creates two new tunnels to represent the ladder's position in the game world. The tunnels are created using the `PlaceSlabTunnel` function, and are stored in the `tunnels` table of the ladder object.
---
--- The function retrieves the start and end positions of the ladder using the `GetTunnelPositions` function, and uses these positions to create the tunnels. The cost of the tunnels is determined by the `GetCost` function of the ladder.
---
--- If the tunnels are successfully created, they are added to the `tunnels` table of the ladder object. If the `tunnels` table does not exist, it is created.
---
--- @function Ladder:UpdateTunnels
--- @return nil
function Ladder:UpdateTunnels()
	if self.tunnels then
		for _, tunnel in ipairs(self.tunnels) do
			if IsValid(tunnel) then
				tunnel:RemovePFTunnel()
				DoneObject(tunnel)
			end
		end
		table.iclear(self.tunnels)
	end
	local x1, y1, z1, x2, y2, z2 = self:GetTunnelPositions()
	if not x1 then return end
	local costAP = self:GetCost()
	local luaobj1 = { ladder = self }
	local luaobj2 = { ladder = self }
	local tunnel1 = PlaceSlabTunnel("SlabTunnelLadder", costAP, luaobj1, x1, y1, z1, x2, y2, z2)
	local tunnel2 = PlaceSlabTunnel("SlabTunnelLadder", costAP, luaobj2, x2, y2, z2, x1, y1, z1)
	if tunnel1 or tunnel2 then
		if not self.tunnels then self.tunnels = {} end
		table.insert(self.tunnels, tunnel1)
		table.insert(self.tunnels, tunnel2)
	end
end

---
--- Generates a ladder part entity based on the provided material, subvariants, and seed.
---
--- If subvariants are provided and there are more than 0, a random subvariant entity is returned using the `GetRandomSubvariantEntity` function. The subvariant entity name is constructed by formatting the material and suffix.
---
--- If no subvariants are provided, the default entity is returned.
---
--- @param material string The material of the ladder part
--- @param subvariants table A table of subvariant strings
--- @param total number The total number of subvariants
--- @param seed number The seed value for randomization
--- @return string The name of the generated ladder part entity
---
function Ladder:GenerateLadderPartEntity(material, subvariants, total, seed)
	if subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntity(seed, subvariants, function(suffix)
			return string.format("%s_%s", material, suffix)
		end)
	else
		return self.default_entity
	end
end

---
--- Updates the material of the ladder and all its attached parts.
---
--- @param self Ladder The ladder object
--- @param material string The material of the ladder
--- @param subvariants table A table of subvariant strings
--- @param total number The total number of subvariants
---
function Ladder:UpdateMaterial()
	local material, subvariants, total = self:GetMaterialSubvariants()
	self:UpdateLadderPartMaterial(self, material, subvariants, total)
	for i = 1, self.LadderParts do
		local ladder_part = self:GetAttach(i)
		self:UpdateLadderPartMaterial(ladder_part, material, subvariants, total, ladder_part:GetAttachOffset())
	end
end

---
--- Updates the ladder by destroying any sinking parts, extending the ladder to the bottom, and updating the tunnels.
---
--- This function is called to maintain the ladder's state and ensure it is properly positioned and connected to any tunnels.
---
--- @param self Ladder The ladder object
---
function Ladder:Update()
	self:DestroySinkingParts()
	self:ExtendToBottom()
	self:UpdateTunnels()
end

---
--- Handles the editor callback when the `LadderParts` property is set.
---
--- This function is responsible for:
--- - Sorting the existing ladder parts by their attachment offset
--- - Removing any excess ladder parts
--- - Adding new ladder parts to extend the ladder to the bottom
--- - Updating the tunnels associated with the ladder
---
--- @param self Ladder The ladder object
--- @param prop_id string The ID of the property that was set
--- @param old_value number The previous value of the property
---
function Ladder:OnEditorSetProperty(prop_id, old_value)
	if prop_id == "LadderParts" then
		local ladder_parts = {}
		for i = 1, old_value do
			ladder_parts[i] = self:GetAttach(i)
		end
		table.sort(ladder_parts, function(part1, part2)
			return part1:GetAttachOffset() > part2:GetAttachOffset()
		end)
		while #ladder_parts > self.LadderParts do
			local ladder_part = ladder_parts[#ladder_parts]
			table.remove(ladder_parts)
			ladder_part:Detach()
			DoneObject(ladder_part)
		end
		local pieces = self.LadderParts - #ladder_parts
		if pieces > 0 then
			self:ExtendToBottom(pieces, #ladder_parts)
		end
		self:UpdateTunnels()
	elseif prop_id == "ColorModifier" or string.match(prop_id, "Editable") or prop_id == "ColorizationPalette" then
		self:UpdateColorModifier()
	elseif prop_id == "Material" then
		self:UpdateMaterial()
	end
end

---
--- Called when the ladder is cloned in the editor.
--- Updates the tunnels associated with the ladder.
---
--- @param self Ladder The ladder object
--- @param source Ladder The source ladder object being cloned
---
function Ladder:EditorCallbackClone(source)
	self:UpdateTunnels()
end

---
--- Called after the ladder object is loaded.
--- Extends the ladder to the bottom, sets the on-roof property, and updates the associated tunnels.
---
--- @param self Ladder The ladder object
--- @param reason string The reason the ladder was loaded
---
function Ladder:PostLoad(reason)
	local pieces = self.LadderParts
	self.LadderParts = 0
	self:ExtendToBottom(pieces)
	self:SetOnRoof(self:GetOnRoof())
	self:UpdateTunnels()
end

---
--- Sets the on-roof property of the ladder and its attached parts.
---
--- @param self Ladder The ladder object
--- @param on_roof boolean Whether the ladder is on the roof or not
---
function Ladder:SetOnRoof(on_roof)
	CObject.SetOnRoof(self, on_roof)
	for i = 1, self.LadderParts do
		self:GetAttach(i):SetOnRoof(on_roof)
	end
end

Ladder.EditorCallbackMove = Ladder.Update

DefineClass.SlabTunnelLadder = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeLadder,
	dbg_tunnel_color = const.clrCyan,
	dbg_tunnel_zoffset = 10 * guic,
	ladder = false,
}

---
--- Calculates the cost of a SlabTunnelLadder based on its base cost, modifier, and an optional context-specific ladder modifier.
---
--- @param self SlabTunnelLadder The SlabTunnelLadder object.
--- @param context table An optional table containing a ladder_modifier field.
--- @return number The calculated cost of the SlabTunnelLadder.
---
function SlabTunnelLadder:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.ladder_modifier or 0)) / 100
end

---
--- Sets the visibility of the mercenary detection indicators on the given unit.
---
--- @param unit table The unit to set the indicator visibility for.
--- @param visible boolean Whether the indicators should be visible or not.
---
function SetMercIndicatorsVisible(unit, visible)
	if not IsValid(unit) then return end
	
	local attaches = unit:GetAttaches("MercDetectionIndicator")
	for _, fx in ipairs(attaches) do
		fx:SetVisible(visible)
	end
	local attaches = unit:GetAttaches("Mesh")
	for _, fx in ipairs(attaches) do
		if IsKindOf(fx.CRMaterial, "CRM_RangeContourPreset") then
			fx:SetVisible(visible)
		end
	end
end

---
--- Traverses a tunnel using a ladder.
---
--- @param unit table The unit traversing the tunnel.
--- @param pos1 table The start position of the tunnel.
--- @param pos2 table The end position of the tunnel.
--- @param quick_play boolean Whether to quickly play the traversal animation.
---
function SlabTunnelLadder:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:Face(pos2)
		unit:SetPos(pos2)
		return
	end
	local ladder = self.ladder
	assert(ladder, "Ladder object missing for tunnel!")
	local ladder_parts = ladder.LadderParts

	local entrance_pos = self:GetEntrance()
	local exit_pos = self:GetExit()
	local z1 = entrance_pos:z() or GetHeight(entrance_pos)
	local z2 = exit_pos:z() or GetHeight(exit_pos)

	SetMercIndicatorsVisible(unit, false)
	unit:PushDestructor(function(unit)
		SetMercIndicatorsVisible(unit, true)
	end)

	unit:SetPos(unit:GetVisualPosXYZ()) -- place on a valid Z
	unit:SetPos(pos1:SetZ(z1), 200)
	unit:Face(pos2, 200)
	local hidden_weapon = unit:HideActiveMeleeWeapon()
	if hidden_weapon then
		unit:PushDestructor(unit.ShowActiveMeleeWeapon)
	end
	if z1 < z2 then
		-- up
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_Start")
		local t = 0
		if ladder_parts >= 4 then
			for i = 2, ladder_parts - 2 do
				unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_Idle", nil, 0, pos1:SetZ(z2 - (ladder_parts - i) * voxel_z))
				if i == 2 then
					unit:TunnelUnblock(entrance_pos, exit_pos)
				end
			end
		else
			local modifier = unit:CalcMoveSpeedModifier()
			if modifier > 0 then
				local hit_phase = Max(200, GetAnimDuration(unit:GetEntity(), "nw_LadderClimbOn_End") / 3)
				t = MulDivRound(hit_phase, 1000, modifier)
			end
			unit:SetPos(pos2:SetZ(z1 + 2 * voxel_z))
		end
		unit:SetPos(pos2, t)
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOn_End", nil, 0)
	else
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_Start")
		unit:TunnelUnblock(entrance_pos, exit_pos)
		unit:SetPos(pos2:SetZ(z1 - 2*voxel_z))
		local t = 0
		if ladder_parts >= 4 then
			for i = 2, ladder_parts - 2 do
				unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_Idle", nil, 0, pos2:SetZ(z2 + (ladder_parts - 2 - i) * voxel_z))
			end
		else
			local modifier = unit:CalcMoveSpeedModifier()
			if modifier > 0 then
				local t1 = unit:GetAnimMoment("nw_LadderClimbOff_End", "FootLeft")
				local t2 = unit:GetAnimMoment("nw_LadderClimbOff_End", "FootRight")
				local hit_phase = t1 and t2 and Min(t1, t2) or t1 or t2 or GetAnimDuration(unit:GetEntity(), "nw_LadderClimbOff_End") / 2
				t = MulDivRound(hit_phase, 1000, modifier)
			end
		end
		unit:SetPos(pos2, t)
		unit:MovePlayAnimSpeedUpdate("nw_LadderClimbOff_End", nil, 0)
	end
	unit:SetState("nw_Standing_Idle")
	if hidden_weapon then
		unit:PopAndCallDestructor()
	end
	unit:PopAndCallDestructor()
end
