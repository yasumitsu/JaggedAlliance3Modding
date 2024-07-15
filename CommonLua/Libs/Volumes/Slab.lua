-- the map is considered in bottom-right quadrant, which means that (0, 0) is north, west
local default_color = RGB(100, 100, 100)
local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local no_mat = const.SlabNoMaterial
local noneWallMat = no_mat
local gofPermanent = const.gofPermanent
local efVisible = const.efVisible

const.SuppressMultipleRoofEdges = true

DefineClass.Restrictor = {
	__parents = { "Object" },

	restriction_box = false,
}

local iz = const.InvalidZ
---
--- Restricts the position of the object to the defined restriction box.
--- If no restriction box is defined, this function does nothing.
---
--- @param self Restrictor
--- The Restrictor object.
---
function Restrictor:Restrict()
	local b = self.restriction_box
	if not b then return end
	local x, y, z = self:GetPosXYZ()
	x, y, z = self:RestrictXYZ(x, y, z)
	self:SetPos(x, y, z)
end

---
--- Restricts the position of the object to the defined restriction box.
--- If no restriction box is defined, this function does nothing.
---
--- @param self Restrictor
--- The Restrictor object.
--- @param x number
--- The x-coordinate to restrict.
--- @param y number
--- The y-coordinate to restrict.
--- @param z number
--- The z-coordinate to restrict.
--- @return number, number, number
--- The restricted x, y, and z coordinates.
---
function Restrictor:RestrictXYZ(x, y, z)
	local b = self.restriction_box
	if not b then return x, y, z end
	local minx, miny, minz, maxx, maxy, maxz = b:xyzxyz()
	x = Clamp(x, minx, maxx)
	y = Clamp(y, miny, maxy)
	if z ~= iz and minz ~= iz and maxz ~= iz then
		z = Clamp(z, minz, maxz)
	end
	return x, y, z
end

DefineClass.WallAlignedObj = {
	__parents = { "AlignedObj" },
}

---
--- Aligns the object attached to its parent.
---
--- This function calculates the position and angle of the object relative to its parent, and sets the attachment offset accordingly.
---
--- @param self WallAlignedObj
--- The WallAlignedObj instance.
---
function WallAlignedObj:AlignObjAttached()
	local p = self:GetParent()
	assert(p)
	local ap = self:GetPos() + self:GetAttachOffset()
	local x, y, z, angle = WallWorldToVoxel(ap, self:GetAngle())
	x, y, z = WallVoxelToWorld(x, y, z, angle)
	px, py, pz = p:GetPosXYZ()
	self:SetAttachOffset(x - px, y - py, z - pz)
	self:SetAngle(angle) --havn't tested with parents with angle ~= 0, might not work
end

---
--- Aligns the object to the wall.
---
--- This function calculates the position and angle of the object relative to its parent, and sets the attachment offset accordingly.
---
--- @param self WallAlignedObj
--- The WallAlignedObj instance.
--- @param pos table|nil
--- The position to align the object to. If nil, the object's own position is used.
--- @param angle number|nil
--- The angle to align the object to. If nil, the object's own angle is used.
---
function WallAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = WallWorldToVoxel(pos, angle or self:GetAngle())
	else
		x, y, z, angle = WallWorldToVoxel(self)
	end
	x, y, z = WallVoxelToWorld(x, y, z, angle)
	self:SetPosAngle(x, y, z, angle)
end

DefineClass.FloorAlignedObj = {
	__parents = { "AlignedObj" },
	GetGridCoords = rawget(_G, "WorldToVoxel"),
}

---
--- Aligns the object to the floor.
---
--- This function calculates the position and angle of the object relative to the floor, and sets the position accordingly.
---
--- @param self FloorAlignedObj
--- The FloorAlignedObj instance.
--- @param pos table|nil
--- The position to align the object to. If nil, the object's own position is used.
--- @param angle number|nil
--- The angle to align the object to. If nil, the object's own angle is used.
---
function FloorAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = WorldToVoxel(pos, angle or self:GetAngle())
	else
		x, y, z, angle = WorldToVoxel(self)
	end
	x, y, z = VoxelToWorld(x, y, z)
	self:SetPosAngle(x, y, z, angle)
end

DefineClass.CornerAlignedObj = {
	__parents = { "AlignedObj" },
}

---
--- Aligns the CornerAlignedObj to the corner.
---
--- This function calculates the position and angle of the object relative to the corner, and sets the position accordingly.
---
--- @param self CornerAlignedObj
--- The CornerAlignedObj instance.
--- @param pos table|nil
--- The position to align the object to. If nil, the object's own position is used.
--- @param angle number|nil
--- The angle to align the object to. If nil, the object's own angle is used.
---
function CornerAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = CornerWorldToVoxel(pos, angle or self:GetAngle())
	else
		x, y, z, angle = CornerWorldToVoxel(self)
	end
	x, y, z = CornerVoxelToWorld(x, y, z, angle)
	self:SetPosAngle(x, y, z, angle)
end

DefineClass.GroundAlignedObj = {
	__parents = { "AlignedObj" },
	GetGridCoords = rawget(_G, "WorldToVoxel"),
}

---
--- Aligns a GroundAlignedObj to the ground.
---
--- This function calculates the position and angle of the object relative to the ground, and sets the position accordingly.
---
--- @param self GroundAlignedObj
--- The GroundAlignedObj instance.
--- @param pos table|nil
--- The position to align the object to. If nil, the object's own position is used.
--- @param angle number|nil
--- The angle to align the object to. If nil, the object's own angle is used.
---
function GroundAlignedObj:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = WorldToVoxel(pos, angle or self:GetAngle())
		if not pos:IsValidZ() then
			z = iz
		end
	else
		x, y, z, angle = WorldToVoxel(self)
		if not self:IsValidZ() then
			z = iz
		end
	end
	x, y, z = VoxelToWorld(x, y, z)
	self:SetPosAngle(x, y, z or iz, angle)
end

local function FloorsComboItems()
	local items = {}
	for i = -5, 10 do
		items[#items + 1] = tostring(i)
	end
	return items
end

function SlabMaterialComboItems()
	return PresetGroupCombo("SlabPreset", Slab.MaterialListClass, Slab.MaterialListFilter)
end

----

-- CObject slab variant (no Lua object)
DefineClass.CSlab = {
	__parents = { "EntityChangeKeepsFlags", "AlignedObj" },
	flags = { efBuilding = true },
	entity_base_name = "Slab",
	material = false, -- will store only temporally the value as the CObject Lua tables are subject to GC
	MaterialListClass = "SlabMaterials",
	MaterialListFilter = false,
	isVisible = true,
	always_visible = false,

	ApplyMaterialProps = empty_func,
	class_suppression_strenght = 0,
	variable_entity = true,
}

--- Returns the base entity name for the slab object.
---
--- The base entity name is constructed by concatenating the `entity_base_name` property
--- with the `material` property of the slab object.
---
--- @return string The base entity name for the slab object.
function CSlab:GetBaseEntityName()
	return string.format("%s_%s", self.entity_base_name, self.material)
end

---
--- Returns a random seed value based on the position of the CSlab object.
---
--- The seed value is generated using the `BraidRandom` function, which takes the encoded voxel position of the CSlab object and an optional constant value as input.
---
--- @return number The random seed value.
function CSlab:GetSeed(max, const)
	assert(self:IsValidPos())
	return BraidRandom(EncodeVoxelPos(self) + (const or 0), max)
end

---
--- Composes the entity name for a CSlab object based on its material preset and subvariants.
---
--- The base entity name is constructed by concatenating the `entity_base_name` property
--- with the `material` property of the CSlab object. If the material preset has any
--- subvariants defined, a random subvariant is selected and appended to the base entity
--- name. If no valid entity is found for the composed name, the base entity name with
--- a "_01" suffix is returned.
---
--- @return string The composed entity name for the CSlab object.
function CSlab:ComposeEntityName()
	local base_entity = self:GetBaseEntityName()
	local material_preset = self:GetMaterialPreset()
	local subvariants = material_preset and material_preset.subvariants or empty_table
	if #subvariants > 0 then
		local seed = self:GetSeed()
		local remaining = subvariants
		while true do
			local subvariant, idx = table.weighted_rand(remaining, "chance", seed)
			if not subvariant then
				break
			end
			local entity = subvariant.suffix ~= "" and (base_entity .. "_" .. subvariant.suffix) or base_entity
			if IsValidEntity(entity) then
				return entity
			end
			remaining = remaining == subvariants and table.copy(subvariants) or remaining
			table.remove(remaining, idx)
		end
	end
	return IsValidEntity(base_entity) and base_entity or (base_entity .. "_01")
end

---
--- Updates the entity associated with the CSlab object.
---
--- This function first composes the entity name for the CSlab object using the `ComposeEntityName` function. If the composed entity name is valid, the function changes the entity associated with the CSlab object using the `ChangeEntity` function and applies any material properties using the `ApplyMaterialProps` function.
---
--- If the composed entity name is not valid and the material of the CSlab object is not `no_mat`, the function reports a missing slab entity using the `ReportMissingSlabEntity` function.
---
--- @return void
function CSlab:UpdateEntity()
	local name = self:ComposeEntityName()
	if IsValidEntity(name) then
		self:ChangeEntity(name)
		self:ApplyMaterialProps()
	elseif self.material ~= no_mat then
		self:ReportMissingSlabEntity(name)
	end
end

if Platform.developer and config.NoPassEditsOnSlabEntityChange then
	function CSlab:ChangeEntity(entity, ...)
		DbgSetErrorOnPassEdit(self, "%s: Entity %s --> %s", self.class, self:GetEntity(), entity)
		EntityChangeKeepsFlags.ChangeEntity(self, entity, ...)
		DbgClearErrorOnPassEdit(self)
	end
end

--- Returns the material preset for the CSlab object.
---
--- This function retrieves the material preset for the CSlab object by calling the `CObject.GetMaterialPreset` function and passing the CSlab object as the argument.
---
--- @return table The material preset for the CSlab object.
function CSlab:GetArtMaterialPreset()
	return CObject.GetMaterialPreset(self)
end

---
--- Returns the material preset for the CSlab object.
---
--- This function retrieves the material preset for the CSlab object by calling the `Presets.SlabPreset[self.MaterialListClass]` table and accessing the preset for the `self.material` key.
---
--- @return table The material preset for the CSlab object, or `nil` if no preset is found.
function CSlab:GetMaterialPreset()
	local material_list = Presets.SlabPreset[self.MaterialListClass]
	return material_list and material_list[self.material]
end

---
--- Sets the suppressor state of the CSlab object.
---
--- If the `suppressor` parameter is `true`, the function turns the CSlab object invisible using the `TurnInvisible` function and the provided `reason` parameter. If the `suppressor` parameter is `false`, the function turns the CSlab object visible using the `TurnVisible` function and the provided `reason` parameter.
---
--- @param suppressor boolean Whether to set the suppressor state to on or off.
--- @param initiator any The initiator of the suppressor state change.
--- @param reason string The reason for the suppressor state change.
--- @return boolean Always returns `true`.
function CSlab:SetSuppressor(suppressor, initiator, reason)
	reason = reason or "suppressed"
	if suppressor then
		self:TurnInvisible(reason)
	else
		self:TurnVisible(reason)
	end
	return true
end

---
--- Determines whether the CSlab object should update its associated entity.
---
--- This function is called to check if the CSlab object should update its associated entity. It always returns `true`, indicating that the entity should be updated.
---
--- @return boolean Always returns `true`.
function CSlab:ShouldUpdateEntity(agent)
	return true
end

--presumably cslabs don't need reasons
---
--- Turns the CSlab object invisible.
---
--- This function sets the visibility of the CSlab object to invisible by clearing the `efVisible` hierarchy enum flag.
---
--- @param reason string The reason for turning the CSlab object invisible.
--- @return nil
function CSlab:TurnInvisible(reason)
	self:ClearHierarchyEnumFlags(const.efVisible)
end

---
--- Turns the CSlab object visible.
---
--- This function sets the visibility of the CSlab object to visible by setting the `efVisible` hierarchy enum flag.
---
--- @param reason string The reason for turning the CSlab object visible.
--- @return nil
function CSlab:TurnVisible(reason)
	self:SetHierarchyEnumFlags(const.efVisible)
end

---
--- Gets the material type of the CSlab object.
---
--- This function retrieves the material type of the CSlab object. It first tries to get the material preset, and if it exists, it returns the `obj_material` field from the preset. Otherwise, it returns the `material` field of the CSlab object.
---
--- @return string The material type of the CSlab object.
function CSlab:GetMaterialType()
	--this gets the combat or obj material, not to be confused with slab material..
	local preset = self:GetMaterialPreset()
	return preset and preset.obj_material or self.material
end

----
local function ListAddObj(list, obj)
	if not list[obj] then
		list[obj] = true
		list[#list + 1] = obj
	end
end

local function ListForEach(list, func, ...)
	for _, obj in ipairs(list or empty_table) do
		if IsValid(obj) then
			procall(obj[func], obj)
		end
	end
end

local DelayedUpdateEntSlabs = {}
local DelayedUpdateVariantEntsSlabs = {}
local DelayedAlignObj = {}
---
--- Updates various slab-related entities and objects.
---
--- This function performs the following tasks:
--- - Suspends pass edits for the "SlabUpdate" operation.
--- - Iterates through the `DelayedUpdateEntSlabs` table and calls the `UpdateEntity` method on each valid object.
--- - Clears the `DelayedUpdateEntSlabs` table.
--- - Iterates through the `DelayedUpdateVariantEntsSlabs` table and calls the `UpdateVariantEntities` method on each valid object.
--- - Clears the `DelayedUpdateVariantEntsSlabs` table.
--- - Iterates through the `DelayedAlignObj` table and calls the `AlignObj` method on each valid object.
--- - Clears the `DelayedAlignObj` table.
--- - Resumes pass edits for the "SlabUpdate" operation.
---
--- @return nil
function SlabUpdate()
	SuspendPassEdits("SlabUpdate", false)
	
	ListForEach(DelayedUpdateEntSlabs, "UpdateEntity")
	table.clear(DelayedUpdateEntSlabs)
	
	ListForEach(DelayedUpdateVariantEntsSlabs, "UpdateVariantEntities")
	table.clear(DelayedUpdateVariantEntsSlabs)
	
	ListForEach(DelayedAlignObj, "AlignObj")
	table.clear(DelayedAlignObj)
	
	ResumePassEdits("SlabUpdate")
end

local first = false
function OnMsg.NewMapLoaded()
	first = true
end

---
--- Wakes up the "DelayedSlabUpdate" periodic repeat thread.
---
--- This function is used to trigger the execution of the `SlabUpdate` function, which performs various updates on slab-related entities and objects.
---
--- @return nil
function DelayedSlabUpdate()
	--assert(mapdata.GameLogic, "Thread will never resume on map with no GameLogic.")
	Wakeup(PeriodicRepeatThreads["DelayedSlabUpdate"])
end


----
--this class is used when copying/preserving props of slabs and room objs
DefineClass.SlabPropHolder = {
	__parents = { "PropertyObject" },
	--props we want stored :
	properties = {
		{ id = "colors", name = "Colors", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ id = "interior_attach_colors", name = "Interior Attach Color", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of the interior attach for ExIn materials.", no_edit = function(self)
			return self.variant == "Outdoor"
		end,},
		{ id = "exterior_attach_colors", name = "Exterior Attach Color", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of the exterior attach for InIn materials.", no_edit = function(self)
			return self.variant == "Outdoor" or self.variant == "OutdoorIndoor"
		end},
		{ name = "Subvariant", id = "subvariant", editor = "number", default = -1}
	},
}
----

DefineClass("SlabAutoResolve")

DefineClass.Slab = {
	__parents = { "CSlab", "Object", "DestroyableSlab", "HideOnFloorChange", "ComponentExtraTransform", "EditorSubVariantObject", "Mirrorable", "SlabAutoResolve" },
	flags = { gofPermanent = true, cofComponentColorizationMaterial = true, gofDetailClass0 = false, gofDetailClass1 = true },
	
	properties = {
		category = "Slabs",
		{ id = "buttons", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true, sort_order = -1,
			buttons = {
				{name = "Select Parent Room", func = "SelectParentRoom"},
			},
		},
		{ id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "SlabMaterials", extra_item = noneWallMat, default = "Planks", },
		{ id = "variant", name = "Variant", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabVariants"), default = "Outdoor", },
		{ id = "forceVariant", name = "Force Variant", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabVariants"), default = "", help = "Variants are picked automatically and settings to the variant prop are overriden by internal slab workings, use this prop to force this slab to this variant at all times."},
		{ id = "indoor_material_1", name = "Indoor Material 1", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabIndoorMaterials", false, no_mat), default = no_mat, no_edit = function(self)
			return self.variant == "Outdoor"
		end,},
		{ id = "indoor_material_2", name = "Indoor Material 2", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabIndoorMaterials", false, no_mat), default = no_mat, no_edit = function(self)
			return self.variant == "Outdoor" or self.variant == "OutdoorIndoor"
		end,},
		{ id = "colors", name = "Colors", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },

		{ id = "colors1", name = "Colors 1", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of mat1 attach.", no_edit = function(self)
			return self.variant == "Outdoor"
		end, dont_save = true, no_edit = true}, --TODO: remove, save compat
		{ id = "interior_attach_colors", name = "Interior Attach Color", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of the interior attach for ExIn materials.", no_edit = function(self)
			return self.variant == "Outdoor"
		end,},
		{ id = "colors2", name = "Colors 2", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of mat2 attach", no_edit = function(self)
			return self.variant == "Outdoor" or self.variant == "OutdoorIndoor"
		end, dont_save = true, no_edit = true}, --TODO: remove, save compat
		{ id = "exterior_attach_colors", name = "Exterior Attach Color", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, help = "Color of the exterior attach for InIn materials.", no_edit = function(self)
			return self.variant == "Outdoor" or self.variant == "OutdoorIndoor"
		end,},
		{ id = "Walkable" },
		{ id = "ApplyToGrids" },
		{ id = "Collision" },
		{ id = "always_visible", name = "Always Visible", editor = "bool", help = "Ignores room slab logic for making slabs invisible. Only implemented for walls, other types upon request.", default = false },
		{ id = "ColorModifier", dont_save = true, read_only = true },
		{ id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = true, help = "In context of destruction."},
	},
	entity_base_name = "Slab",
	GetGridCoords = rawget(_G, "WorldToVoxel"),
	--in parent room
	
	variant_objects = false,
	
	isVisible = true,
	invisible_reasons = false,
	
	room = false,
	side = false,
	floor = 1,
	
	collision_allowed_mask = 0,
	colors_room_member = "outer_colors",
	room_container_name = false,
	invulnerable = true,
	
	subvariants_table_id = "subvariants",
	bad_entity = false,
	exterior_attach_colors_from_nbr = false,
}

---
--- Checks if the slab is invulnerable.
---
--- The slab is considered invulnerable if either the `invulnerable` flag is set,
--- or if the slab is temporarily marked as invulnerable.
---
--- @return boolean True if the slab is invulnerable, false otherwise.
function Slab:IsInvulnerable()
	--not checking IsObjInvulnerableDueToLDMark(self) because related setter is hidden for slabs;
	return self.invulnerable or TemporarilyInvulnerableObjs[self]
end

---
--- Returns the name of the room member used for coloring this slab.
---
--- @return string The name of the room member used for coloring this slab.
function Slab:GetColorsRoomMember()
	return self.colors_room_member
end

---
--- Sets up the invulnerability color marking on the given object when the invulnerability value changes.
---
--- This function is a stub and does not contain any implementation. It is likely intended to be implemented elsewhere in the codebase.
---
--- @param o table The object to set up the invulnerability color marking for.
---
function SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
	--stub
end

---
--- Sets whether the slab is forcibly invulnerable due to game rules.
---
--- This function sets the `forceInvulnerableBecauseOfGameRules` and `invulnerable` flags on the slab, and also calls `SetupObjInvulnerabilityColorMarkingOnValueChanged` to update the invulnerability color marking on the slab.
---
--- @param val boolean Whether the slab should be forcibly invulnerable due to game rules.
---
function Slab:SetforceInvulnerableBecauseOfGameRules(val)
	self.forceInvulnerableBecauseOfGameRules = val
	self.invulnerable = val
	SetupObjInvulnerabilityColorMarkingOnValueChanged(self)
end

---
--- Gets the entity subvariant for this slab.
---
--- The subvariant is extracted from the entity name by splitting the name on the "_" character and taking the last element, converting it to a number.
---
--- @return number The subvariant of the slab's entity.
function Slab:GetEntitySubvariant()
	local e = self:GetEntity()
	local strs = string.split(e, "_")
	return tonumber(strs[#strs])
end

---
--- Selects the parent room of the slab in the editor.
---
--- If the slab has a valid room, this function clears the current editor selection and adds the room to the selection.
--- If the slab has no room, a message is printed to the console.
---
function Slab:SelectParentRoom()
	if IsValid(self.room) then
		editor.ClearSel()
		editor.AddToSel({self.room})
	else
		print("This slab has no room.")
	end
end

---
--- Initializes the slab object.
---
--- This function is called during the initialization of the slab object. It performs the following tasks:
--- - Asserts that the slab object is being edited in the editor, or that the operation is being captured by the editor undo system.
--- - If the slab has a valid room, it sets the warped state of the slab to match the warped state of the room.
---
--- @param self table The slab object being initialized.
---
function Slab:Init()
	-- all Slab operations must be captured by editor undo
	assert(EditorCursorObjs[self] or XEditorUndo:AssertOpCapture())
	if IsValid(self.room) then
		self:SetWarped(self.room:GetWarped())
	end
end

if Platform.developer then
function Slab:Done()
	-- all Slab operations must be captured by editor undo
	assert(EditorCursorObjs[self] or XEditorUndo:AssertOpCapture())
end
end

---
--- Initializes the simulation material ID for the slab.
---
--- This function is called during the initialization of the slab object. It updates the simulation material ID for the slab, which is used for various simulation-related operations.
---
--- @param self table The slab object being initialized.
---
function Slab:GameInit()
	self:UpdateSimMaterialId()
end

---
--- Handles changes to the 'material' or 'variant' properties of the slab.
---
--- When the 'material' or 'variant' property is changed, this function resets the 'subvariant' property to -1.
---
--- When the 'forceVariant' property is changed, this function updates the 'variant' property to match the 'forceVariant' value, and then triggers delayed updates to the slab's entity.
---
--- @param self table The slab object.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Game Entity Data) object associated with the slab.
---
function Slab:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "material" or prop_id == "variant" then
		self.subvariant = -1
	end
	if prop_id == "forceVariant" then
		self.variant = self.forceVariant
		self:DelayedUpdateEntity()
		self:DelayedUpdateVariantEntities()
	end
end

---
--- Sets the warped state of the slab.
---
--- When the slab is warped, this function sets the `gofWarped` game object flag on the slab and all attached objects (like wallpapers).
--- When the slab is not warped, this function clears the `gofWarped` game object flag on the slab and all attached objects.
---
--- @param self table The slab object.
--- @param val boolean The new warped state of the slab.
---
function Slab:SetWarped(val)
	--all attached objs as well, like wallpapers and such
	if val then
		self:SetHierarchyGameFlags(const.gofWarped)
	else
		self:ClearHierarchyGameFlags(const.gofWarped)
	end
end

---
--- This function updates the simulation material ID for the slab, which is used for various simulation-related operations.
---
--- @param self table The slab object being updated.
---
function Slab:UpdateSimMaterialId()
end

---
--- Sets the material of the slab.
---
--- This function updates the `material` property of the slab and then calls `Slab:UpdateSimMaterialId()` to update the simulation material ID for the slab, which is used for various simulation-related operations.
---
--- @param self table The slab object.
--- @param val string The new material for the slab.
---
function Slab:Setmaterial(val)
	self.material = val
	self:UpdateSimMaterialId()
end

---
--- Sets the variant of the slab.
---
--- @param self table The slab object.
--- @param val number The new variant of the slab.
---
function Slab:Setvariant(val)
	self.variant = val
end

---
--- Propagates the room associated with the SlabAutoResolve object.
---
--- @return table The room associated with the SlabAutoResolve object.
---
function SlabAutoResolve:SelectionPropagate()
	return self.room
end

---
--- Completes the construction of the SlabAutoResolve element by updating the simulation material ID.
---
--- This function is called after the SlabAutoResolve element has been constructed, and it updates the simulation material ID for the slab, which is used for various simulation-related operations.
---
--- @param self table The SlabAutoResolve object being constructed.
---
function SlabAutoResolve:CompleteElementConstruction()
	self:UpdateSimMaterialId()
end

--suppress saving of this prop
---
--- Sets the room associated with the slab.
---
--- This function updates the `room` property of the slab and then calls `Slab:DelayedUpdateEntity()` to update the entity associated with the slab.
---
--- @param self table The slab object.
--- @param val table The new room for the slab.
---
function Slab:Setroom(val)
	self.room = val
	self:DelayedUpdateEntity()
end

---
--- Gets the default color for the slab.
---
--- This function retrieves the default color for the slab by looking up the color member in the slab's associated room. If the room has a color member, the value of that member is returned. Otherwise, the function returns `false`.
---
--- @param self table The slab object.
--- @return boolean|table The default color for the slab, or `false` if no default color is available.
---
function Slab:GetDefaultColor()
	local member = self:GetColorsRoomMember()
	return member and table.get(self.room, member) or false
end

---
--- Sets the colors for the slab.
---
--- This function sets the colors for the slab. If the `val` parameter is `nil`, `empty_table`, or `ColorizationPropSet`, the function sets the colors to the default color for the slab's associated room. Otherwise, the function clones the `val` parameter and sets it as the slab's colors. The function then calls `Slab:SetColorization()` and `SetSlabColorHelper()` to update the slab's appearance.
---
--- @param self table The slab object.
--- @param val table The new colors for the slab.
---
function Slab:Setcolors(val)
	local def_color = self:GetDefaultColor()
	if not val or val == empty_table or val == ColorizationPropSet then
		val = def_color
	end
	self.colors = (val ~= def_color) and val:Clone() or nil
	self:SetColorization(val)
	SetSlabColorHelper(self, val)
end

---
--- Sets the interior attach colors for the slab.
---
--- This function sets the interior attach colors for the slab. If the `val` parameter is `nil`, `empty_table`, or `ColorizationPropSet`, the function sets the colors to the default color for the slab's associated room. Otherwise, the function clones the `val` parameter and sets it as the slab's interior attach colors. The function then calls `SetSlabColorHelper()` to update the slab's appearance.
---
--- @param self table The slab object.
--- @param val table The new interior attach colors for the slab.
---
function Slab:Setinterior_attach_colors(val)
	local def_color = self.room and self.room.inner_colors or false
	if not val or val == empty_table or val == ColorizationPropSet then
		val = def_color
	end
	self.interior_attach_colors = (val ~= def_color) and val:Clone() or nil
	if self.variant_objects and self.variant_objects[1] then
		SetSlabColorHelper(self.variant_objects[1], val)
	end
end

---
--- Gets the exterior attach color for the slab.
---
--- This function returns the exterior attach color for the slab. It first checks if the `exterior_attach_colors` member is set, and returns that value. If not, it checks the `exterior_attach_colors_from_nbr` member and returns that value. If neither of those are set, it falls back to returning the `colors` member, or the default color for the slab's associated room if the `colors` member is not set.
---
--- @param self table The slab object.
--- @return table The exterior attach color for the slab.
---
function Slab:GetExteriorAttachColor()
	return self.exterior_attach_colors or self.exterior_attach_colors_from_nbr or self.colors or self:GetDefaultColor()
end

---
--- Sets the exterior attach colors for the slab based on the neighboring slab.
---
--- This function sets the exterior attach colors for the slab. If the `val` parameter is an empty table, the function sets the `exterior_attach_colors_from_nbr` member to `false`. Otherwise, if the `val` parameter is different from the current `exterior_attach_colors_from_nbr` member, the function clones the `val` parameter and sets it as the slab's `exterior_attach_colors_from_nbr` member. The function then calls `SetSlabColorHelper()` to update the slab's appearance.
---
--- @param self table The slab object.
--- @param val table The new exterior attach colors for the slab based on the neighboring slab.
---
function Slab:Setexterior_attach_colors_from_nbr(val)
	if val == empty_table then
		val = false
	end
	if val and (not self.exterior_attach_colors_from_nbr or not rawequal(self.exterior_attach_colors_from_nbr, val)) then
		val = val:Clone()
	end
	
	self.exterior_attach_colors_from_nbr = val
	if self.variant_objects and self.variant_objects[2] then
		SetSlabColorHelper(self.variant_objects[2], self:GetExteriorAttachColor())
	end
end

---
--- Sets the exterior attach colors for the slab.
---
--- This function sets the exterior attach colors for the slab. If the `val` parameter is an empty table, the function sets the `exterior_attach_colors` member to `false`. Otherwise, if the `val` parameter is different from the current `exterior_attach_colors` member, the function clones the `val` parameter and sets it as the slab's `exterior_attach_colors` member. The function then calls `SetSlabColorHelper()` to update the slab's appearance.
---
--- @param self table The slab object.
--- @param val table The new exterior attach colors for the slab.
---
function Slab:Setexterior_attach_colors(val)
	if val == empty_table then
		val = false
	end
	if val and (not self.exterior_attach_colors or not rawequal(self.exterior_attach_colors, val)) then
		val = val:Clone()
	end
	
	self.exterior_attach_colors = val
	if self.variant_objects and self.variant_objects[2] then
		SetSlabColorHelper(self.variant_objects[2], self:GetExteriorAttachColor())
	end
end

---
--- Determines whether the slab can be mirrored.
---
--- This function returns `true`, indicating that the slab can be mirrored.
---
--- @return boolean `true` if the slab can be mirrored, `false` otherwise.
function Slab:CanMirror()
	return true
end

local invisible_mask = const.cmDynInvisible & ~const.cmVisibility

---
--- Makes the slab invisible.
---
--- This function sets the slab to be invisible. It adds the given `reason` to the `invisible_reasons` table, which keeps track of the reasons why the slab is invisible. If the slab was previously visible, this function sets the `isVisible` flag to `false`, stores the current collision mask in the `collision_allowed_mask` member, clears the `efVisible` enum flag, and sets the collision mask to `invisible_mask`.
---
--- @param self table The slab object.
--- @param reason string The reason for making the slab invisible.
---
function Slab:TurnInvisible(reason)
	assert(not self.always_visible)
	self.invisible_reasons = table.create_set(self.invisible_reasons, reason, true)
	
	if self.isVisible or self:GetEnumFlags(efVisible) ~= 0 then
		self.isVisible = false
		local mask = collision.GetAllowedMask(self)
		self.collision_allowed_mask = mask ~= 0 and mask or nil
		self:ClearHierarchyEnumFlags(efVisible)
		collision.SetAllowedMask(self, invisible_mask)
	end
end

---
--- Makes the slab visible.
---
--- This function removes the given `reason` from the `invisible_reasons` table, which keeps track of the reasons why the slab is invisible. If the `invisible_reasons` table is now empty and the slab was previously invisible, this function sets the `isVisible` flag to `true`, restores the `collision_allowed_mask` member, sets the `efVisible` enum flag, and restores the collision mask to the previous value.
---
--- @param self table The slab object.
--- @param reason string The reason for making the slab visible.
---
function Slab:TurnVisible(reason)
	local invisible_reasons = self.invisible_reasons
	if reason and invisible_reasons then
		invisible_reasons[reason] = nil
	end
	if not next(invisible_reasons) and not self.isVisible then
		self.isVisible = nil
		assert(self.isVisible)
		self:SetHierarchyEnumFlags(efVisible)
		collision.SetAllowedMask(self, self.collision_allowed_mask)
		self.collision_allowed_mask = nil
		self.invisible_reasons = nil
	end
end

local sx, sy, sz = const.SlabSizeX or guim, const.SlabSizeY or guim, const.SlabSizeZ or guim

local slabgroupop_lastObjs = false
local slabgroupop_lastRealTime = false

local function slab_group_op_done(objs)
	local rt = RealTime()
	if objs == slabgroupop_lastObjs and slabgroupop_lastRealTime and slabgroupop_lastRealTime == rt  then
		return true
	end
	slabgroupop_lastObjs = objs
	slabgroupop_lastRealTime = rt
	return false
end

local slab_sides = { "N", "W", "S", "E" }
local slab_coord_limit = shift(1, 20)

local function slab_hash(x, y, z, side)
	local s = table.find(slab_sides, side) or 0
	assert(x < slab_coord_limit and y < slab_coord_limit and z < slab_coord_limit)
	return x + shift(y, 20) + shift(z, 40) + shift(s, 60)
end

---
--- Sets the heat material index for the slab.
---
--- @param self table The slab object.
--- @param matIndex number The heat material index to set.
---
function Slab:SetHeatMaterialIndex(matIndex)
	self:SetCustomData(9, matIndex)
end

---
--- Gets the heat material index for the slab.
---
--- @return number The heat material index of the slab.
---
function Slab:GetHeatMaterialIndex()
	return self:GetCustomData(9)
end

---
--- Removes any duplicate slabs that are at the same location as the current slab.
---
--- @param self table The slab object.
---
function Slab:RemoveDuplicates()
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	MapDelete(self, 0, self.class, nil, nil, gameFlags, function(o, self, is_permanent)
		return obj ~= self and (is_permanent or o:GetGameFlags(gofPermanent) == 0) and self:IsSameLocation(obj) 
	end, self, is_permanent)
end

---
--- Aligns the slab object to the terrain surface and updates its entity.
---
--- This function is called when the slab is placed in the editor, but not when it is pasted, cloned, or undone.
---
--- @param self table The slab object.
--- @param reason string The reason for the editor callback, such as "paste", "clone", or "undo".
---
function Slab:EditorCallbackPlace(reason)
	if reason == "paste" or reason == "clone" or reason == "undo" then return end
	local x, y, z = self:GetPosXYZ()
	local surfz = terrain.GetHeight(x, y) 
	z = z or (surfz + voxelSizeZ - 1)
	while z < surfz do
		z = z + sz
	end
	self:AlignObj(point(x, y, z))
	self:UpdateEntity()
end

---
--- Checks if the current slab object is at the same location as the given object.
---
--- @param self table The slab object.
--- @param obj table The object to compare the location with.
--- @return boolean True if the slab object is at the same location as the given object, false otherwise.
---
function Slab:IsSameLocation(obj)
	local x1, y1, z1 = self:GetPosXYZ()
	local x2, y2, z2 = obj:GetPosXYZ()
	
	return x1 == x2 and y1 == y2 and z1 == z2
end

---
--- Returns the world bounding box of the slab.
---
--- @param self table The slab object.
--- @return table The world bounding box of the slab.
---
function Slab:GetWorldBBox()
	return GetSlabWorldBBox(self:GetPos(), 1, 1, self:GetAngle())
end

---
--- Generates a random seed value based on the slab's position and an optional constant.
---
--- @param self table The slab object.
--- @param max number The maximum value for the random seed.
--- @param const number An optional constant to include in the seed calculation.
--- @return number The generated random seed value.
---
function Slab:GetSeed(max, const)
	assert(self:IsValidPos())
	return BraidRandom(EncodeVoxelPos(self) + (IsValid(self.room) and self.room.seed or 0) + (const or 0), max)
end

local cached_totals = {}
local function ClearCachedTotals()
	cached_totals = {}
end

OnMsg.DoneMap = ClearCachedTotals
OnMsg.DataReload = ClearCachedTotals
OnMsg.PresetSave = ClearCachedTotals

---
--- Gets the material subvariants for a given slab definition.
---
--- @param svd table The slab definition.
--- @param subvariants_id string An optional subvariants ID.
--- @return table,number The subvariants table and the total chance of all subvariants.
---
function GetMaterialSubvariants(svd, subvariants_id)
	if not svd then return false, 0 end
	local subvariants = not subvariants_id and svd.subvariants or subvariants_id and svd:HasMember(subvariants_id) and svd[subvariants_id]
	local key = xxhash(svd.class, svd.id, subvariants_id or "")
	local total = cached_totals[key]
	if not total then
		total = 0
		for i = 1, #(subvariants or empty_table) do
			total = total + subvariants[i].chance
		end
		
		cached_totals[key] = total
	end
	
	return subvariants, total
end

---
--- Sets the subvariant of the slab and updates the entity.
---
--- @param self table The slab object.
--- @param val number The new subvariant value.
---
function Slab:Setsubvariant(val)
	EditorSubVariantObject.Setsubvariant(self, val)
	self:DelayedUpdateEntity()
end

---
--- Resets the subvariant of the slab and updates the entity.
---
--- @param self table The slab object.
---
function Slab:ResetSubvariant()
	EditorSubVariantObject.ResetSubvariant(self, val)
	self:UpdateEntity()
end

variantToVariantName = {
	OutdoorIndoor = "ExIn",
	IndoorIndoor = "InIn",
	Outdoor = "ExEx",
}

---
--- Gets the base entity name for the slab.
---
--- @param self table The slab object.
--- @return string The base entity name.
---
function Slab:GetBaseEntityName()
	return string.format("%sExt_%s_Wall_%s", self.entity_base_name, self.material, variantToVariantName[self.variant])
end

---
--- Gets a random subvariant entity name from the given subvariants.
---
--- @param random number The random value to use for selecting the subvariant.
--- @param subvariants table A table of subvariant information, with each entry having a `suffix` and `chance` field.
--- @param get_ent_func function A function that takes the subvariant suffix and other arguments and returns the entity name.
--- @param ... any Additional arguments to pass to the `get_ent_func`.
--- @return string The randomly selected entity name.
--- @return string The suffix of the randomly selected subvariant.
---
function GetRandomSubvariantEntity(random, subvariants, get_ent_func, ...)
	local t = 0
	for i = 1, #subvariants do
		t = t + subvariants[i].chance
		if i == #subvariants or t > random then
			local ret = get_ent_func(subvariants[i].suffix, ...)
			while i > 1 and not IsValidEntity(ret) do
				--fallback to first valid ent in the set
				i = i - 1
				ret = (subvariants[i].chance > 0 or i == 1) and get_ent_func(subvariants[i].suffix, ...) or false
			end
			
			return ret, subvariants[i].suffix
		end
	end
end

---
--- Gets the subvariant digit string for the slab.
---
--- @param self table The slab object.
--- @param subvariants table (optional) The subvariant information table.
--- @return string The subvariant digit string.
---
function Slab:GetSubvariantDigitStr(subvariants)
	local digit = self.subvariant
	if digit == -1 then
		return "01"
	end
	if subvariants then
		digit = ((digit - 1) % #subvariants) + 1 --assumes "01, 02, etc. suffixes
	end
	return digit < 10 and "0" .. tostring(digit) or tostring(digit)
end

---
--- Composes the entity name for a slab based on its material, subvariant, and other properties.
---
--- @param self table The slab object.
--- @return string The composed entity name.
---
function Slab:ComposeEntityName()
	local material_list = Presets.SlabPreset[self.MaterialListClass]
	local svd = material_list and material_list[self.material]
	local svdId = self.subvariants_table_id
	
	local baseEntity = self:GetBaseEntityName()
	if svd and svd[svdId] and #svd[svdId] > 0 then
		local subvariants, total = GetMaterialSubvariants(svd, svdId)
		
		if self.subvariant ~= -1 then --user selected subvar
			local digitStr = self:GetSubvariantDigitStr()
			local ret = string.format("%s_%s", baseEntity, digitStr)
			if not IsValidEntity(ret) then
				print("Reverting slab [" .. self.handle .. "] subvariant [" .. self.subvariant .. "] because no entity [" .. ret .. "] found. The slab has a subvariant set by the user (level-designer) which produces an invalid entity, this subvariant will be reverted back to a random subvariant. Re-saving the map will save the removed set subvariant and this message will no longer appear.")
				ret = false
				self.subvariant = -1
			else
				return ret
			end
		end
				
		return GetRandomSubvariantEntity(self:GetSeed(total), subvariants, function(suffix, baseEntity)
			return string.format("%s_%s", baseEntity, suffix)
		end, baseEntity)
	else
		local digitStr = self:GetSubvariantDigitStr()
		local ent = string.format("%s_%s", baseEntity, digitStr)
		return IsValidEntity(ent) and ent or baseEntity
	end
end

---
--- Composes the entity name for an indoor material slab based on its material and subvariant properties.
---
--- @param self table The slab object.
--- @param mat string The material of the slab.
--- @return string The composed entity name.
---
function Slab:ComposeIndoorMaterialEntityName(mat)
	if self.destroyed_neighbours ~= 0 and self.destroyed_entity_side ~= 0 or
		self.is_destroyed and self.diagonal_ent_mask ~= 0 then
		return self:ComposeBrokenIndoorMaterialEntityName(mat)
	end
	
	local svd = (Presets.SlabPreset.SlabIndoorMaterials or empty_table)[mat]
	if svd and svd.subvariants and #svd.subvariants > 0 then
		local subvariants, total = GetMaterialSubvariants(svd)
		return GetRandomSubvariantEntity(self:GetSeed(total), subvariants, function(suffix, mat)
			return string.format("WallInt_%s_Wall_%s", mat, suffix)
		end, mat)
	else
		return string.format("WallInt_%s_Wall_01", mat)
	end
end

---
--- Sets the color modifier and colorization of the given object based on the provided colors.
---
--- If the object has more than 0 colorization materials, the color modifier is set to a dark gray and the colorization is set to the provided colors or the object's default colorization set.
--- If the object has 0 colorization materials, the color modifier is set to half the intensity of the first editable color in the provided color set or the default colorization set.
---
--- @param obj table The object to set the color modifier and colorization for.
--- @param colors table|nil The colors to use for colorization. If not provided, the object's default colorization set is used.
---
function SetSlabColorHelper(obj, colors)
	if obj:GetMaxColorizationMaterials() > 0 then
		obj:SetColorModifier(RGB(100, 100, 100))
		if not colors then 
			colors = obj:GetDefaultColorizationSet()
		end
		obj:SetColorization(colors, "ignore_his_max")
	else
		local color1 = (colors or ColorizationPropSet):GetEditableColor1()
		local r,g,b = GetRGB(color1)
		obj:SetColorModifier(RGB(r / 2, g / 2, b / 2))
	end
end

---
--- Determines whether the slab should use room mirroring.
---
--- This function always returns `true`, indicating that the slab should use room mirroring.
---
--- @return boolean Always returns `true`.
---
function Slab:ShouldUseRoomMirroring()
	return true
end

---
--- Handles mirroring of the slab based on the parent room's mirroring state.
---
--- If the slab's parent room is valid and the slab should use room mirroring, the slab's mirroring state is set based on a random chance. If the slab is mirrored, any interior objects are also mirrored to maintain the correct orientation.
---
--- @function Slab:MirroringFromRoom
--- @return nil
function Slab:MirroringFromRoom()
	--called on update entity, deals with mirroring coming from parent room
	if not IsValid(self.room) then
		return
	end
	if not self:ShouldUseRoomMirroring() then
		return
	end
	local mirror = self:CanMirror() and self:GetSeed(100, 115249) < 50
	self:SetMirrored(mirror)
	if mirror then
		-- interior objects can't be mirrored, so unmirror them... by mirroring them again
		for _, interior in ipairs(self.variant_objects or empty_table) do
			interior:SetMirrored(true)
		end
	end
end

---
--- Schedules a delayed update for the slab's variant entities.
---
--- This function adds the slab to the `DelayedUpdateVariantEntsSlabs` list and calls `DelayedSlabUpdate()` to trigger the delayed update.
---
--- @function Slab:DelayedUpdateVariantEntities
--- @return nil
function Slab:DelayedUpdateEntity()
	ListAddObj(DelayedUpdateEntSlabs, self)
	DelayedSlabUpdate()
end

---
--- Schedules a delayed update for the slab's variant entities.
---
--- This function adds the slab to the `DelayedUpdateVariantEntsSlabs` list and calls `DelayedSlabUpdate()` to trigger the delayed update.
---
--- @function Slab:DelayedUpdateVariantEntities
--- @return nil
function Slab:DelayedUpdateVariantEntities()
	ListAddObj(DelayedUpdateVariantEntsSlabs, self)
	DelayedSlabUpdate()
end

---
--- Schedules a delayed alignment update for the slab.
---
--- This function adds the slab to the `DelayedAlignObj` list and calls `DelayedSlabUpdate()` to trigger the delayed update.
---
--- @function Slab:DelayedAlignObj
--- @return nil
function Slab:DelayedAlignObj()
	ListAddObj(DelayedAlignObj, self)
	DelayedSlabUpdate()
end

---
--- Iterates over the destroyed attachments of the slab and calls the provided function `f` for each valid attachment.
---
--- If a destroyed attachment is a table, the function will be called for each valid element in the table.
---
--- @param f function The function to call for each valid destroyed attachment.
--- @param ... any Additional arguments to pass to the function `f`.
--- @return nil
function Slab:ForEachDestroyedAttach(f, ...)
	for k, v in pairs(rawget(self, "destroyed_attaches") or empty_table) do
		if IsValid(v) then
			f(v, ...)
		elseif type(v) == "table" then
			for i = 1, #v do
				local vi = v[i]
				if IsValid(vi) then
					f(vi, ...)
				end
			end
		end
	end
end

---
--- Refreshes the colors of the slab and its destroyed attachments.
---
--- This function sets the colors of the slab using the `SetSlabColorHelper` function, and then iterates over the destroyed attachments of the slab, calling `SetSlabColorHelper` for each valid attachment.
---
--- @function Slab:RefreshColors
--- @return nil
function Slab:RefreshColors()
	local clrs = self.colors or self:GetDefaultColor()
	SetSlabColorHelper(self, clrs)
	self:ForEachDestroyedAttach(function(v, clrs)
		SetSlabColorHelper(v, clrs)
	end, clrs)
end

---
--- Destroys the attachments of the slab and clears the `variant_objects` field.
---
--- This function calls the `Object.DestroyAttaches()` function to destroy the attachments of the slab, and then sets the `variant_objects` field to `nil`.
---
--- @function Slab:DestroyAttaches
--- @param ... any Additional arguments to pass to `Object.DestroyAttaches()`.
--- @return nil
function Slab:DestroyAttaches(...)
	Object.DestroyAttaches(self, ...)
	self.variant_objects = nil
end

---
--- Updates the destroyed state of the slab.
---
--- This function returns `false` to indicate that the slab is not in a destroyed state.
---
--- @return boolean `false` to indicate that the slab is not in a destroyed state.
function Slab:UpdateDestroyedState()
	return false
end

---
--- Gets the subvariant of the entity associated with the slab.
---
--- This function extracts the subvariant from the entity name by splitting the name on the "_" character and returning the last element as a number. If the last element cannot be converted to a number, it returns 1.
---
--- @param e Entity The entity to get the subvariant from. If not provided, the entity associated with the slab is used.
--- @return number The subvariant of the entity.
function Slab:GetSubvariantFromEntity(e)
	e = e or self:GetEntity()
	local strs = string.split(e, "_")
	return tonumber(strs[#strs]) or 1
end

---
--- Locks the subvariant of the slab to the subvariant of the current entity associated with the slab.
---
--- This function retrieves the entity associated with the slab and checks if it is a valid entity (not "InvisibleObject"). If so, it sets the `subvariant` field of the slab to the subvariant of the entity, as determined by the `Slab:GetSubvariantFromEntity()` function.
---
--- @function Slab:LockSubvariantToCurrentEntSubvariant
--- @return nil
function Slab:LockSubvariantToCurrentEntSubvariant()
	local e = self:GetEntity()
	if IsValidEntity(e) and e ~= "InvisibleObject" then
		self.subvariant = self:GetSubvariantFromEntity(e)
	end
end

---
--- Locks the subvariant of the slab to a random subvariant of the current entity associated with the slab.
---
--- This function first checks if the `subvariant` field of the slab is not set to -1. If it is not, the function returns without doing anything. Otherwise, it calls the `Slab:LockSubvariantToCurrentEntSubvariant()` function to set the `subvariant` field to the subvariant of the current entity associated with the slab.
---
--- @function Slab:LockRandomSubvariantToCurrentEntSubvariant
--- @return nil
function Slab:LockRandomSubvariantToCurrentEntSubvariant()
	if self.subvariant ~= -1 then return end
	self:LockSubvariantToCurrentEntSubvariant()
end

---
--- Unlocks the subvariant of the slab, setting it to -1.
---
--- This function is used to reset the subvariant of the slab to an unspecified value. This is typically done when the slab's subvariant needs to be determined dynamically, such as when the slab is associated with an entity whose subvariant can change.
---
--- @function Slab:UnlockSubvariant
--- @return nil
function Slab:UnlockSubvariant()
	self.subvariant = -1
end

---
--- Sets the visibility of the slab.
---
--- This function sets the visibility of the slab by calling the `Object.SetVisible()` function. If the slab is set to be visible, it calls the `Slab:TurnVisible()` function. If the slab is set to be invisible, it calls the `Slab:TurnInvisible()` function.
---
--- @param value boolean The new visibility state of the slab.
--- @return nil
function Slab:SetVisible(value)
	Object.SetVisible(self, value)
	if value then
		self:TurnVisible("SetVisible")
	else
		self:TurnInvisible("SetVisible")
	end
end

---
--- Resets the visibility flags of the slab.
---
--- This function checks the current visibility state of the slab. If the slab is visible, it sets the `efVisible` flag in the hierarchy. If the slab is not visible, it clears the `efVisible` flag in the hierarchy.
---
--- @function Slab:ResetVisibilityFlags
--- @return nil
function Slab:ResetVisibilityFlags()
	if self.isVisible then
		self:SetHierarchyEnumFlags(const.efVisible)
	else
		self:ClearHierarchyEnumFlags(const.efVisible)
	end
end

---
--- Updates the entity associated with the slab.
---
--- This function is responsible for updating the entity associated with the slab. It performs the following tasks:
---
--- 1. Checks if the slab is destroyed or has destroyed neighbors, and updates the destroyed state if necessary.
--- 2. If the slab's destroyed entity side is not 0, it means a neighboring slab has been repaired, so the slab's destroyed state is reset.
--- 3. Composes the entity name for the slab and checks if it matches the current entity. If so, it updates the simulation material ID and mirrors the slab from the room.
--- 4. If the entity name is valid, it updates the simulation material ID, changes the entity to the "idle" state, mirrors the slab from the room, refreshes the colors, and applies the material properties.
--- 5. Resets the visibility flags of the slab.
--- 6. If the slab is in the editor and selected, it marks the object as modified to fix a specific issue (0159218).
--- 7. If the slab's material is not "no_mat", it reports a missing slab entity.
---
--- @return nil
function Slab:UpdateEntity()
	self.bad_entity = nil
	if self.destroyed_neighbours ~= 0 or self.is_destroyed then
		if self:UpdateDestroyedState() then
			return
		end
	elseif self.destroyed_entity_side ~= 0 then
		--nbr got repaired
		self.destroyed_entity_side = 0
		self.destroyed_entity = false
		self:RestorePreDestructionSubvariant()
	end

	local name = self:ComposeEntityName()
	
	if name == self:GetEntity() then
		self:UpdateSimMaterialId()
		self:MirroringFromRoom()
	elseif IsValidEntity(name) then
		self:UpdateSimMaterialId()
		self:ChangeEntity(name, "idle")
		self:MirroringFromRoom()
		self:RefreshColors()
		self:ApplyMaterialProps()
		
		--change ent resets flags, set them back
		self:ResetVisibilityFlags()
		
		if Platform.developer and IsEditorActive() and selo() == self then
			ObjModified(self) --fixes 0159218
		end
	elseif self.material ~= no_mat then
		self:ReportMissingSlabEntity(name)
	end
end

DefineClass.SlabInteriorObject = {
	__parents = { "Object", "ComponentAttach" },
	flags = { efCollision = false, efApplyToGrids = false, cofComponentColorizationMaterial = true }
}

--- Updates the variant entities associated with this slab.
---
--- This function is responsible for updating the variant entities that are
--- associated with this slab. It ensures that the slab's visual representation
--- is kept in sync with its underlying state, such as the selected variant.
---
--- @return nil
function Slab:UpdateVariantEntities()
end

---
--- Sets a property of the Slab object and updates the associated entity.
---
--- @param id string The property ID to set.
--- @param value any The value to set for the property.
---
function Slab:SetProperty(id, value)
	EditorCallbackObject.SetProperty(self, id, value)
	if id == "material" then
		self:DelayedUpdateEntity()
	elseif id == "entity" or id == "variant" or id == "indoor_material_1" or id == "indoor_material_2" then
		self:DelayedUpdateEntity()
		self:DelayedUpdateVariantEntities()
	end
end

---
--- Gets the container in the room that this slab is associated with.
---
--- This function retrieves the container in the room that this slab is associated with. The container is determined by the `room_container_name` property of the slab. If the room is valid and the container name is set, the function will return the container object for the specified side of the slab. If the room is not valid or the container name is not set, the function will return `nil`.
---
--- @return table|nil The container in the room that this slab is associated with, or `nil` if the room is not valid or the container name is not set.
function Slab:GetContainerInRoom()
	local room = self.room
	if IsValid(room) then
		local container = self.room_container_name
		container = container and room[container]
		return container and container[self.side] or container
	end
end

---
--- Removes this slab from the room container it is associated with.
---
--- This function retrieves the container in the room that this slab is associated with, and removes the slab from that container. If the slab is not associated with a valid room or container, this function does nothing.
---
--- @return nil
function Slab:RemoveFromRoomContainer()
	local t = self:GetContainerInRoom()
	if t then
		local idx = table.find(t, self)
		if idx then
			t[idx] = false
		end
	end
end

---
--- Gets a unique identifier for this slab object.
---
--- This function returns a unique identifier for the slab object, taking into account the room and container it is associated with. If the slab is not associated with a valid room or container, the function falls back to the default object identifier.
---
--- @return string A unique identifier for this slab object.
function Slab:GetObjIdentifier()
	if not self.room or not IsValid(self.room) or not self.room_container_name then
		return CObject.GetObjIdentifier(self)
	end
	local idx = table.find(self:GetContainerInRoom(), self)
	assert(idx)
	return xxhash(CObject.GetObjIdentifier(self.room), self.room_container_name, self.side, idx)
end

---
--- Deletes the slab and removes it from the room container.
---
--- This function is called when the slab is deleted from the editor. It first removes the slab from the room container it is associated with. If the slab is not visible, hidden (suppressed) slabs from other rooms that are on the same position are also deleted.
---
--- @param reason string The reason for the deletion, such as "undo".
--- @return nil
function Slab:EditorCallbackDelete(reason)
	self:RemoveFromRoomContainer()
	
	-- delete hidden (supressed) slabs from other rooms that are on the same position
	if EditorCursorObjs[self] or not self.isVisible or reason == "undo" then
		return
	end
	MapForEach(self, 0, self.class, function(o, self)
		if o ~= self and not o.isVisible then
			o:RemoveFromRoomContainer()
			DoneObject(o)
		end
	end, self)
end

---
--- Gets the editor parent object for this slab.
---
--- The editor parent object is typically the room that the slab is associated with.
---
--- @return table The editor parent object for this slab.
function Slab:GetEditorParentObject()
	return self.room
end

DefineClass.FloorSlab = {
	__parents = { "Slab", "FloorAlignedObj", "DestroyableFloorSlab" },
	flags = { efPathSlab = true },
	properties = {
		category = "Slabs",
		{ id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "FloorSlabMaterials", extra_item = noneWallMat, default = "Planks", },
		{ id = "variant", name = "Variant", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabVariants"), default = "", no_edit = true },
	},
	entity = "Floor_Planks",
	entity_base_name = "Floor",
	MaterialListClass = "FloorSlabMaterials",
	colors_room_member = "floor_colors",
	room_container_name = "spawned_floors",
}

FloorSlab.MirroringFromRoom = empty_func
---
--- Determines whether the FloorSlab can be mirrored.
---
--- This function always returns false, indicating that the FloorSlab cannot be mirrored.
---
--- @return boolean false
function FloorSlab:CanMirror()
	return false
end

---
--- Gets the base entity name for the FloorSlab.
---
--- The base entity name is constructed by concatenating the `entity_base_name` property
--- with the `material` property, separated by an underscore.
---
--- @return string The base entity name for the FloorSlab.
function FloorSlab:GetBaseEntityName()
	return string.format("%s_%s", self.entity_base_name, self.material)
end

DefineClass.CeilingSlab = {
	__parents = { "Slab", "FloorAlignedObj", "DestroyableFloorSlab" },
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false, efPathSlab = false },
	properties = {
		category = "Slabs",
		{ id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "FloorSlabMaterials", extra_item = noneWallMat, default = "Planks", },
		{ id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = false, help = "In context of destruction."},
	},
	entity = "Floor_Planks",
	entity_base_name = "Floor",
	MaterialListClass = "FloorSlabMaterials",
	room_container_name = "roof_objs",
	class_suppression_strenght = -10,
}

---
--- Gets the base entity name for the CeilingSlab.
---
--- The base entity name is constructed by concatenating the `entity_base_name` property
--- with the `material` property, separated by an underscore.
---
--- @return string The base entity name for the CeilingSlab.
function CeilingSlab:GetBaseEntityName()
	return string.format("%s_%s", self.entity_base_name, self.material)
end

DefineClass.BaseWallSlab = {
	__parents = { "CSlab" },
}

DefineClass.WallSlab = {
	__parents = { "Slab", "BaseWallSlab", "WallAlignedObj", "ComponentAttach"},
	
	entity_base_name = "Wall",

	wall_obj = false, -- SlabWallObject currently covering this wall
	GetGridCoords = rawget(_G, "WallWorldToVoxel"),
	room_container_name = "spawned_walls",
	class_suppression_strenght = 100,
}

---
--- Updates the variant entities for the WallSlab.
---
--- This function is responsible for managing the variant objects that are attached to the WallSlab.
--- It handles the different variants of the WallSlab (Outdoor, OutdoorIndoor, IndoorIndoor) and
--- ensures that the correct entities are placed and their colors are set appropriately.
---
--- @param self WallSlab The WallSlab instance.
---
function WallSlab:UpdateVariantEntities()
	if self.variant == "Outdoor" or (self.is_destroyed and self.diagonal_ent_mask == 0) then
		DoneObjects(self.variant_objects)
		self.variant_objects = nil
	elseif self.variant == "OutdoorIndoor" then
		if not self.variant_objects then
			local o1 = PlaceObject("SlabInteriorObject")
			self:Attach(o1)
			o1:SetAttachAngle(180 * 60)
			self.variant_objects = { o1 }
		else
			DoneObject(self.variant_objects[2])
			self.variant_objects[2] = nil
		end
		
		if IsValid(self.variant_objects[1]) then
			local e = self:ComposeIndoorMaterialEntityName(self.indoor_material_1)
			if self.variant_objects[1]:GetEntity() ~= e then
				self.variant_objects[1]:ChangeEntity(e)
			end
			self:Setinterior_attach_colors(self.interior_attach_colors or self.room and self.room.inner_colors)
		end
	elseif self.variant == "IndoorIndoor" then
		if not self.variant_objects then
			local o1 = PlaceObject("SlabInteriorObject")
			self:Attach(o1)
			o1:SetAttachAngle(180 * 60)
			self.variant_objects = { o1 }
		end
		if not IsValid(self.variant_objects[2]) then
			local o1 = PlaceObject("SlabInteriorObject")
			self:Attach(o1)
			self.variant_objects[2] = o1
		end
		
		if IsValid(self.variant_objects[1]) then
			local e = self:ComposeIndoorMaterialEntityName(self.indoor_material_1)
			if self.variant_objects[1]:GetEntity() ~= e then
				self.variant_objects[1]:ChangeEntity(e)
			end
			self:Setinterior_attach_colors(self.interior_attach_colors or self.room and self.room.inner_colors)
		end
		
		if IsValid(self.variant_objects[2]) then
			local e = self:ComposeIndoorMaterialEntityName(self.indoor_material_2)
			if self.variant_objects[2]:GetEntity() ~= e then
				self.variant_objects[2]:ChangeEntity(e)
			end
			SetSlabColorHelper(self.variant_objects[2], self:GetExteriorAttachColor())
		end
	end
	
	self:SetWarped(IsValid(self.room) and self.room:GetWarped() or self:GetWarped()) --propagate warped state to variant_objs
end

---
--- Refreshes the colors of the WallSlab object and its attached objects.
---
--- This function sets the color of the WallSlab object and any attached objects
--- based on the `colors`, `interior_attach_colors`, and `room.inner_colors`
--- properties of the WallSlab. It also manages the colors of any attachments
--- of the attached objects, setting the exterior attach color for attachments
--- with a 0 degree angle, and the interior attach color for attachments with
--- any other angle.
---
--- If the WallSlab has `variant_objects`, this function also sets the color
--- of the first variant object to the interior attach color, and the second
--- variant object to the exterior attach color.
---
--- @param self WallSlab The WallSlab object to refresh the colors for.
---
function WallSlab:RefreshColors()
	local clrs = self.colors or self:GetDefaultColor()
	local iclrs = self.interior_attach_colors or self.room and self.room.inner_colors
	SetSlabColorHelper(self, clrs)
	self:ForEachDestroyedAttach(function(v, clrs, self)
		SetSlabColorHelper(v, clrs)
		--manage attaches of attaches colors
		local atts = v:GetAttaches()
		for i = 1, #(atts or "") do
			local a = atts[i]
			if not rawget(a, "editor_ignore") then
				local angle = a:GetAttachAngle()
				if angle == 0 then
					SetSlabColorHelper(a, self:GetExteriorAttachColor())
				else
					SetSlabColorHelper(a, iclrs)
				end
			end
		end
	end, clrs, self)
	
	if self.variant_objects then
		if self.variant_objects[1] then
			SetSlabColorHelper(self.variant_objects[1], self.interior_attach_colors or self.room and self.room.inner_colors)
		end
		if self.variant_objects[2] then
			SetSlabColorHelper(self.variant_objects[2], self:GetExteriorAttachColor())
		end
	end
end

---
--- Callback function for when a WallSlab object is placed in the editor.
---
--- This function is called when a WallSlab object is placed in the editor. It
--- sets the `always_visible` property of the WallSlab to `true` if the WallSlab
--- does not have a `room` associated with it, which means it was manually
--- placed and should not be suppressed.
---
--- @param self WallSlab The WallSlab object that was placed.
--- @param reason string The reason for the placement (e.g. "create", "paste", etc.).
---
function WallSlab:EditorCallbackPlace(reason)
	Slab.EditorCallbackPlace(self, reason)
	if not self.room then
		self.always_visible = true -- manually placed slabs can't be suppressed
	end
end

WallSlab.EditorCallbackPlaceCursor = WallSlab.EditorCallbackPlace

---
--- Clears the `wall_obj` reference for this `WallSlab` instance.
---
--- This function is called when the `WallSlab` object is being destroyed or
--- removed from the scene. It sets the `wall_obj` property to `nil` to clear
--- any references to the wall object associated with this `WallSlab`.
---
function WallSlab:Done()
	self.wall_obj = nil --clear refs if any
end

---
--- Sets the wall object associated with this `WallSlab` instance.
---
--- This function sets the `wall_obj` property of the `WallSlab` instance to the
--- provided `obj` parameter. If the `always_visible` property of the `WallSlab`
--- is `true`, this function will return without further action.
--- Otherwise, it will call the `SetSuppressor` function, passing the `obj`
--- parameter, `nil` for the second parameter, and the string `"wall_obj"` for
--- the third parameter.
---
--- @param obj table The wall object to associate with this `WallSlab` instance.
--- @return boolean|nil The return value of the `SetSuppressor` function, if called.
---
function WallSlab:SetWallObj(obj)
	self.wall_obj = obj
	if self.always_visible then
		return
	end
	return self:SetSuppressor(obj, nil, "wall_obj")
end

---
--- Sets the shadow-only state of the wall object associated with this `WallSlab` instance.
---
--- This function checks if the `wall_obj` property of the `WallSlab` instance is not `nil`. If it is not `nil`, it checks if the `shadow_only` state of the `wall_obj` needs to be updated based on the `shadow_only` parameter. If the `shadow_only` state needs to be updated, it calls the `SetShadowOnly` function on the `wall_obj`.
---
--- If the `wall_obj` has this `WallSlab` instance as its `main_wall`, it also calls the `SetManagedSlabsShadowOnly` function on the `wall_obj`, passing the `shadow_only` parameter and the `clear_contour` parameter.
---
--- @param shadow_only boolean Whether the wall object should be in shadow-only mode.
--- @param clear_contour boolean Whether to clear the contour of the wall object.
---
function WallSlab:SetWallObjShadowOnly(shadow_only, clear_contour)
	local wall_obj = self.wall_obj
	if wall_obj then
		if (const.cmtVisible and (not CMT_IsObjVisible(wall_obj))) ~= shadow_only then
			wall_obj:SetShadowOnly(shadow_only)
		end
		if wall_obj.main_wall == self then
			wall_obj:SetManagedSlabsShadowOnly(shadow_only, clear_contour)
		end
	end
end

---
--- Deletes the `WallSlab` instance and its associated wall object.
---
--- This function is called when the `WallSlab` instance is deleted. It first calls the `Slab.EditorCallbackDelete` function to handle the deletion of the `WallSlab` instance. If the `wall_obj` property of the `WallSlab` instance is valid and the `wall_obj` has this `WallSlab` instance as its `main_wall`, it calls the `DoneObject` function to delete the wall object.
---
--- @param reason string The reason for the deletion of the `WallSlab` instance.
---
function WallSlab:EditorCallbackDelete(reason)
	Slab.EditorCallbackDelete(self, reason)
	if IsValid(self.wall_obj) and self.wall_obj.main_wall == self then
		DoneObject(self.wall_obj)
	end
end

---
--- Gets the side of the wall slab based on its angle.
---
--- @param angle number The angle of the wall slab, in degrees. If not provided, the angle of the wall slab is used.
--- @return string The side of the wall slab, one of "N", "E", "S", or "W".
---
function WallSlab:GetSide(angle)
	angle = angle or self:GetAngle()
	if angle == 0 then
		return "E"
	elseif angle == 90*60 then
		return "S"
	elseif angle == 180*60 then
		return "W"
	else
		return "N"
	end
end

---
--- Checks if the current `WallSlab` instance is at the same location as the provided `obj`.
---
--- @param obj WallSlab The other `WallSlab` instance to compare the location with.
--- @return boolean True if the `WallSlab` instances are at the same location, false otherwise.
---
function WallSlab:IsSameLocation(obj)
	local x1, y1, z1 = self:GetPosXYZ()
	local x2, y2, z2 = obj:GetPosXYZ()
	local side1 = self:GetSide()
	local side2 = obj:GetSide()
	
	return x1 == x2 and y1 == y2 and z1 == z2 and side1 == side2
end

---
--- Extends the walls of the provided `WallSlab` objects.
---
--- This function first filters out the `WallSlab` objects that are on the same grid (x, y) coordinates, keeping only the topmost one. It then makes an initial pass to ensure there is space for the extension and that the objects being extended are not being pushed up by subsequent ones. Finally, it creates new `WallSlab` instances at the appropriate positions and angles, copying the relevant properties from the original `WallSlab` instances.
---
--- @param objs table A table of `WallSlab` instances to be extended.
---
function WallSlab:ExtendWalls(objs)
	local visited, topmost = {}, {}
	
	-- filter out objects on the same grid (x, y), keeping the topmost only
	for _, obj in ipairs(objs) do
		local gx, gy, gz = obj:GetGridCoords()
		local side = obj:GetSide()
		local loc = slab_hash(gx, gy, 0, side) -- ignore z so the whole column gets the same hash
		
		if not visited[loc] then
			visited[loc] = true
			-- find the topmost wall in this location
			local idx = #topmost + 1
			topmost[idx] = obj
			while true do
				local wall = GetWallSlab(gx, gy, gz + 1, side)
				if IsValid(wall) then
					gz = gz + 1
					topmost[idx] = wall
				else
					break
				end
			end
		end
	end
		
	-- make an initial pass to make sure there's a space for the extension and the objects being extended are not being pushed up by subsequent ones
	for _, obj in ipairs(topmost) do
		local gx, gy, gz = obj:GetGridCoords()
		SlabsPushUp(gx, gy, gz + 1)
	end
	
	-- create the walls
	for _, obj in ipairs(topmost) do
		local x, y, z = obj:GetPosXYZ()		
		local wall = WallSlab:new()
		wall:SetPosAngle(x, y, z + sz, obj:GetAngle())
		wall:EditorCallbackClone(obj) -- copy relevant properties
		wall:AlignObj()
		wall:UpdateEntity()
	end
end

DefineClass.StairSlab = {
	__parents = { "Slab", "FloorAlignedObj" },
	flags = { efPathSlab = true },
	properties = {
		{ category = "Slabs", id = "material", name = "Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "StairsSlabMaterials", extra_item = noneWallMat, default = "WoodScaff", },
		{ category = "Slab Tools", id = "autobuild_stair_up", editor = "buttons", buttons = {{name = "Extend Up", func = "UIExtendUp"}}, default = false, dont_save = true},
		{ category = "Slab Tools", id = "autobuild_stair_down", editor = "buttons", buttons = {{name = "Extend Down", func = "UIExtendDown" }}, default = false, dont_save = true},
		{ name = "Subvariant", id = "subvariant", editor = "number", default = 1,
			buttons = { 
				{ name = "Next", func = "CycleEntityBtn" },
			},
		},
		
		{ id = "variant" },
		{ id = "always_visible" },
		{ id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = true, help = "In context of destruction.", dont_save = true, no_edit = true},
	},
	entity = "Stairs_WoodScaff_01", --should be some sort of valid ent or place object new excludes it
	entity_base_name = "Stairs",
	
	MaterialListClass = "StairsSlabMaterials",
	hide_floor_slabs_above_in_range = 2, --how far above the slab origin will floor slabs be hidden
}

---
--- Returns whether the StairSlab is invulnerable.
---
--- This function always returns `true`, indicating that the StairSlab is invulnerable.
---
function StairSlab:IsInvulnerable()
	return true
end
--[[
function StairSlab:GameInit()
	self:PFConnect()
end

function StairSlab:Done()
	self:PFDisconnect()
end
]]

---
--- Returns the base entity name for the StairSlab.
---
--- The base entity name is constructed by concatenating the `entity_base_name` and `material` properties of the StairSlab.
---
--- @return string The base entity name for the StairSlab.
---
function StairSlab:GetBaseEntityName()
	return string.format("%s_%s", self.entity_base_name, self.material)
end

---
--- Returns the step height of the stairs.
---
--- This function calls the `GetStairsStepZ` function to retrieve the step height of the stairs.
---
--- @return number The step height of the stairs.
---
function StairSlab:GetStepZ()
	return GetStairsStepZ(self)
end

---
--- Returns the exit offset for the StairSlab.
---
--- The exit offset is a vector that represents the direction the stairs are facing. The vector is determined based on the angle of the stairs.
---
--- @return number, number, number The x, y, and z components of the exit offset vector.
---
function StairSlab:GetExitOffset()
	local dx, dy
	local angle = self:GetAngle()
	if angle == 0 then
		dx, dy = 0, 1
	elseif angle == 90*60 then
		dx, dy = -1, 0
	elseif angle == 180*60 then
		dx, dy = 0, -1
	else
		assert(angle == 270*60)
		dx, dy = 1, 0
	end
	return dx, dy, 1
end

---
--- Traces the stairs connected to the current StairSlab in the specified direction.
---
--- This function traces the stairs connected to the current StairSlab in the specified direction (up or down) and returns the first and last stairs found, as well as a table of all the stairs found.
---
--- @param zdir number The direction to trace the stairs, either 1 (up) or -1 (down).
--- @return StairSlab|nil, StairSlab|nil, table The first and last stairs found, and a table of all the stairs found.
---
function StairSlab:TraceConnectedStairs(zdir)
	assert(zdir == 1 or zdir == -1)
	
	local first, last
	local dx, dy = self:GetExitOffset()
	local angle = self:GetAngle()
	
	dx, dy = dx * zdir, dy * zdir -- reverse the direction if walking down
	
	local all = {}
	local gx, gy, gz = self:GetGridCoords()
	-- check for any stairs below heading toward this voxel	
	-- repeat until the first(lowest one) is found
	local step = 1
	while true do
		local obj = GetStairSlab(gx + step * dx, gy + step * dy, gz + step * zdir)
		if IsValid(obj) and obj:GetAngle() == angle and obj.floor == self.floor then
			first = first or obj
			last = obj
			all[step] = obj
			step = step + 1
		else
			break
		end
	end
	return first, last, all
end
--[[
function StairSlab:PFConnect()
	local first, last, start_stair, end_stair
	
	-- trace down
	first, last = self:TraceConnectedStairs(-1)
	start_stair = last or self
	if first then
		pf.RemoveTunnel(first)
	end
	
	-- trace up
	first, last = self:TraceConnectedStairs(1)
	end_stair = last or self	
	if first then
		pf.RemoveTunnel(first)
	end
	
	--DbgClearVectors()
	self:TunnelStairs(start_stair, end_stair)	
end

function StairSlab:TunnelStairs(start_stair, end_stair)
	-- add a tunnel starting at Stairbottom spot of the first stair and ending on Stairtop spot of the last one	
	local start_point = start_stair:GetSpotPos(start_stair:GetSpotBeginIndex("Stairbottom"))
	local exit_point = end_stair:GetSpotPos(end_stair:GetSpotBeginIndex("Stairtop"))
	local h = terrain.GetHeight(start_point)
	if h >= start_point:z() then
		start_point:SetInvalidZ()
	end
	local weight = 1
	pf.AddTunnel(start_stair, start_point, exit_point, weight, -1, const.fTunnelActiveOnImpassable)
	
	--DbgAddVector(start_point, exit_point - start_point, const.clrGreen)
end

function StairSlab:PFDisconnect()
	DbgClearVectors()
	-- trace down
	local first, last = self:TraceConnectedStairs(-1)
	if last then
		pf.RemoveTunnel(last)
		self:TunnelStairs(last, first)
	else
		-- no stairs below, tunnel starts from self
		pf.RemoveTunnel(self)
	end

	-- trace up
	local first, last = self:TraceConnectedStairs(1)
	if first and last then
		-- already disconnected, no need to further remove tunnels
		self:TunnelStairs(first, last)
	end
end
]]

--- Extends the stairs upward from the current StairSlab object.
---
--- This function is responsible for creating a new StairSlab object above the current one, effectively extending the stairs upward.
---
--- @param parent table|nil The parent object for the new StairSlab.
--- @param prop_id string|nil The property ID for the new StairSlab.
--- @param ged table|nil The game editor data for the new StairSlab.
function StairSlab:UIExtendUp(parent, prop_id, ged)
	if slab_group_op_done(parent or {self}) then
		return
	end
	
	-- trace up from 'self'
	local first, last = self:TraceConnectedStairs(1)
	
	-- check the spot for the next stair for a floor
	local obj = last or self
	local x, y, z = obj:GetGridCoords()
	local dx, dy, dz = obj:GetExitOffset()	
	local floor = GetFloorSlab(x + dx, y + dy, z + dz)
	
	if IsValid(floor) then
		print("Can't extend the stairs upward, floor tile is in the way")
		return
	end
	
	x, y, z = obj:GetPosXYZ()

	local stair = StairSlab:new({material = self.material, subvariant = self.subvariant})
	stair:SetPosAngle(x + dx * sx, y + dy * sy, z + dz * sz, obj:GetAngle())
	stair:EditorCallbackClone(self)
	stair:UpdateEntity()
	self:AlignObj()
	self:UpdateEntity()
end

--- Extends the stairs downward from the current StairSlab object.
---
--- This function is responsible for creating a new StairSlab object below the current one, effectively extending the stairs downward.
---
--- @param parent table|nil The parent object for the new StairSlab.
--- @param prop_id string|nil The property ID for the new StairSlab.
--- @param ged table|nil The game editor data for the new StairSlab.
function StairSlab:UIExtendDown(parent, prop_id, ged)
	if slab_group_op_done(parent or {self}) then
		return
	end
	
	-- trace down from 'self'
	local first, last = self:TraceConnectedStairs(-1)
	
	-- check the spot for the next stair for a floor
	local obj = last or self
	local x, y, z = obj:GetGridCoords()
	local dx, dy, dz = obj:GetExitOffset()	
	local floor = GetFloorSlab(x, y, z)
	
	if IsValid(floor) then
		print("Can't extend the stairs upward, floor tile is in the way")
		return
	end
	
	x, y, z = obj:GetPosXYZ()

	local stair = StairSlab:new({material = self.material, subvariant = self.subvariant})
	stair:SetPosAngle(x - dx * sx, y - dy * sy, z - dz * sz, obj:GetAngle())
	stair:EditorCallbackClone(self)
	stair:UpdateEntity()
	self:AlignObj()
	self:UpdateEntity()
end

--- Aligns the StairSlab object to the specified position and angle.
---
--- This function is responsible for aligning the StairSlab object to the given position and angle. It first calls the `AlignObj` function of the `FloorAlignedObj` class, and then checks if the object is permanent. If the object is not permanent, the function returns.
---
--- If the object is permanent, the function checks if the object's position has changed since the last update. If the position has changed, the function updates the `last_pos` property of the object and computes the visibility of the slab in the updated bounding box.
---
--- @param pos table|nil The position to align the object to.
--- @param angle number|nil The angle to align the object to.
function StairSlab:AlignObj(pos, angle)
	FloorAlignedObj.AlignObj(self, pos, angle)
	if self:GetGameFlags(const.gofPermanent) == 0 then
		return
	end
	local lp = rawget(self, "last_pos")
	local p = self:GetPos()
	if lp ~= p then
		rawset(self, "last_pos", p)
		local b = self:GetObjectBBox()
		if lp then
			local s = b:size() / 2
			b = Extend(b, lp + s)
			b = Extend(b, lp - s)
		end
		
		ComputeSlabVisibilityInBox(b)
	end
end

DefineClass.SlabWallObject = {
	__parents = { "Slab", "WallAlignedObj" },
	properties = {
		category = "Slabs",
		{ id = "variant", name = "Variant", editor = "dropdownlist", items = PresetGroupCombo("SlabPreset", "SlabVariants"), default = "", no_edit = true },
		{ id = "width", name = "Width", editor = "number", min = 0, max = 3, default = 1, },
		{ id = "height", name = "Height", editor = "number", min = 1, max = 4, default = 3, },
		{ id = "subvariant", name = "Subvariant", editor = "number", default = 1,
			buttons = { 
				{ name = "Next", func = "CycleEntityBtn" },
			},},
		{ id = "hide_with_wall", name = "Hide With Wall", editor = "bool", default = false },
		{ id = "owned_slabs", editor = "objects", default = false, no_edit = true },
		{ id = "forceInvulnerableBecauseOfGameRules", name = "Invulnerable", editor = "bool", default = false, help = "In context of destruction."},
		
		{ id = "colors" },
		{ id = "interior_attach_colors" },
		{ id = "exterior_attach_colors" },
		{ id = "indoor_material_1" },
		{ id = "indoor_material_2" },
	},
	
	entity = "Window_Colonial_Single_01", --ent that exists but is not a slab or common ent so it appear in new obj palette correctly
	material = "Planks",
	affected_walls = false,
	main_wall = false,
	last_snap_pos = false,
	room = false,
	owned_objs = false,
	invulnerable = false,
	colors_room_member = false,
}


SlabWallObject.GetSide = WallSlab.GetSide
SlabWallObject.GetGridCoords = WallSlab.GetGridCoords
SlabWallObject.IsSameLocation = WallSlab.IsSameLocation

--- Returns the interior and exterior attach colors for this wall slab.
---
--- @return table, table The interior attach colors and the exterior attach colors.
function WallSlab:GetAttachColors()
	local iclrs = self.interior_attach_colors or self.room and self.room.inner_colors
	local clrs = self:GetExteriorAttachColor()
	return iclrs, clrs
end

--- Returns the material type of the SlabWallObject.
---
--- This gets the combat or object material, not to be confused with the slab material.
---
--- @return string The material type of the SlabWallObject.
function SlabWallObject:GetMaterialType()
	--this gets the combat or obj material, not to be confused with slab material..
	return self.material_type
end

---
--- Refreshes the colors of the SlabWallObject and its attached objects.
---
--- This function is called when the SlabWallObject is destroyed. It retrieves the interior and exterior attach colors from the affected walls, and applies them to the SlabWallObject and its attached objects.
---
--- If the affected walls do not have any invisible reasons, the function uses the colors from the affected walls. Otherwise, it uses the default colors or the room's inner colors.
---
--- The function also ensures that the colors are applied correctly based on the angle of the affected walls.
---
--- @function SlabWallObject:RefreshColors
--- @return nil
function SlabWallObject:RefreshColors()
	if not self.is_destroyed then return end
	
	local clrs, iclrs
	local aw = self.affected_walls
	for i = 1, #(aw or "") do
		local w = aw[i]
		if w.invisible_reasons and not w.invisible_reasons["suppressed"] then
			iclrs, clrs = w:GetAttachColors()
			
			if w:GetAngle() ~= self:GetAngle() then
				local tmp = iclrs
				iclrs = clrs
				clrs = tmp
			end
			
			break
		end
	end

	if not clrs then
		clrs = self.colors or self:GetDefaultColor()
	end
	if not iclrs then
		iclrs = self.room and self.room.inner_colors
	end

	self:ForEachDestroyedAttach(function(v, self, clrs, iclrs)
		local c, ic = clrs, iclrs
		SetSlabColorHelper(v, rawget(v, "use_self_colors") and self or c or self)
		if c or ic then
			local atts = v:GetAttaches()
			for i = 1, #(atts or "") do
				local a = atts[i]
				if not rawget(a, "editor_ignore") then
					local angle = a:GetAttachAngle()
					if angle == 0 then
						if c then
							SetSlabColorHelper(a, c)
						end
					else
						if ic then
							SetSlabColorHelper(a, ic)
						end
					end
				end
			end
		end
	end, self, clrs, iclrs)
end

---
--- Sets the state of the SlabWallObject that is saved on the map.
---
--- @param val string The state value to set.
---
function SlabWallObject:SetStateSavedOnMap(val)
	self:SetState(val)
end

---
--- Gets the state of the SlabWallObject that is saved on the map.
---
--- @return string The state value saved on the map.
---
function SlabWallObject:GetStateSavedOnMap()
	return self:GetStateText()
end

local function InsertInParentContainersHelper(self, room, side)
	assert(side)
	if self:IsDoor() then
		room.spawned_doors = room.spawned_doors or {}
		room.spawned_doors[side] = room.spawned_doors[side] or {}
		table.insert(room.spawned_doors[side], self)
	else
		room.spawned_windows = room.spawned_windows or {}
		room.spawned_windows[side] = room.spawned_windows[side] or {}
		table.insert(room.spawned_windows[side], self)
	end
end

local function RemoveFromParentContainerHelper(self, room, side)
	if self:IsDoor() then
		local spawned_doors = room.spawned_doors
		if spawned_doors and spawned_doors[side] then
			table.remove_entry(spawned_doors[side], self)
			if #spawned_doors[side] <= 0 then
				spawned_doors[side] = nil
			end
		end
	else
		local spawned_windows = room.spawned_windows
		if spawned_windows and spawned_windows[side] then
			table.remove_entry(spawned_windows[side], self)
			if #spawned_windows[side] == 0 then
				spawned_windows[side] = nil
			end
		end
	end
end

---
--- Fixes the room and side properties of a SlabWallObject when it has no room assigned.
---
--- If the SlabWallObject has a main_wall property, it will attempt to get the room and side from the main_wall and assign them to the SlabWallObject. If the room and side are valid, it will also insert the SlabWallObject into the parent containers for that room and side.
---
--- @param self SlabWallObject The SlabWallObject instance to fix.
---
function SlabWallObject:FixNoRoom()
	if self.room then return end
	if not self.main_wall then return end
	
	local room = self.main_wall.room
	local side = self.main_wall.side
	self.room = room
	self.side = side
	if room and side then
		InsertInParentContainersHelper(self, room, side)
	end
end

---
--- Sets the side of the SlabWallObject.
---
--- If the SlabWallObject is currently in a room, it will be removed from the parent containers for the old side and inserted into the parent containers for the new side.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param newSide string The new side to set for the SlabWallObject.
---
function SlabWallObject:Setside(newSide)
	if self.side == newSide then return end
	if self.room then
		RemoveFromParentContainerHelper(self, self.room, self.side)
		if newSide then
			InsertInParentContainersHelper(self, self.room, newSide)
		end
	end
	
	self.side = newSide
end

---
--- Changes the room of the SlabWallObject.
---
--- If the SlabWallObject is currently in a room, it will be removed from the parent containers for the old room and side. If the SlabWallObject is being added to a new room, the XEditorUndo system will start tracking the old data for the new room.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param newRoom table The new room to set for the SlabWallObject.
---
function SlabWallObject:ChangeRoom(newRoom)
	if self.room == newRoom then return end
	self.restriction_box = false
	if self.room then
		RemoveFromParentContainerHelper(self, self.room, self.side)
	end
	if newRoom and not EditorCursorObjs[self] then
		XEditorUndo:StartTracking({newRoom}, not "created", "omit_children") -- let XEditorUndo store the "old" data for the room
	end
	self.room = newRoom
	if newRoom then
		InsertInParentContainersHelper(self, newRoom, self.side)
	end
end

---
--- Gets the world bounding box of the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return table The world bounding box of the SlabWallObject.
---
function SlabWallObject:GetWorldBBox()
	return GetSlabWorldBBox(self:GetPos(), self.width, self.height, self:GetAngle())
end

---
--- Calculates the world bounding box of a slab wall object.
---
--- @param pos table The position of the slab wall object.
--- @param width number The width of the slab wall object.
--- @param height number The height of the slab wall object.
--- @param angle number The angle of the slab wall object.
--- @return table The world bounding box of the slab wall object.
---
function GetSlabWorldBBox(pos, width, height, angle)
	local x, y, z = pos:xyz()
	local b
	local minAdd = width > 1 and voxelSizeX or 0
	local maxAdd = width == 3 and voxelSizeX or 0
	local tenCm = guim / 10
	if angle == 0 then --e
		return box(x - tenCm, y - halfVoxelSizeX - minAdd, z, x + tenCm, y + halfVoxelSizeX + maxAdd, z + height * voxelSizeZ)
	elseif angle == 180 * 60 then --w
		return box(x - tenCm, y - halfVoxelSizeX - maxAdd, z, x + tenCm, y + halfVoxelSizeX + minAdd, z + height * voxelSizeZ)
	elseif angle == 90 * 60 then --s
		return box(x - halfVoxelSizeX - maxAdd, y - tenCm, z, x + halfVoxelSizeX + minAdd, y + tenCm, z + height * voxelSizeZ)
	else --n
		return box(x - halfVoxelSizeX - minAdd, y - tenCm, z, x + halfVoxelSizeX + maxAdd, y + tenCm, z + height * voxelSizeZ)
	end
end

---
--- Checks if a new position for a SlabWallObject would intersect with any other existing SlabWallObjects.
---
--- @param obj SlabWallObject The SlabWallObject instance to check for intersection.
--- @param newPos table The new position to check for intersection.
--- @param width number The width of the SlabWallObject.
--- @param height number The height of the SlabWallObject.
--- @param angle number The angle of the SlabWallObject.
--- @return boolean True if the new position would intersect with another SlabWallObject, false otherwise.
---
function IntersectWallObjs(obj, newPos, width, height, angle)
	local ret = false
	local b = GetSlabWorldBBox(newPos or obj:GetPos(), width or obj.width, height or obj.height, angle or obj:GetAngle())
	angle = angle or obj:GetAngle()
	MapForEach(b:grow(voxelSizeX * 2, voxelSizeX * 2, voxelSizeZ * 3), "SlabWallObject", nil, nil, gofPermanent, function(o, obj, angle)
		if o ~= obj then
			local a = o:GetAngle()
			if a == angle or abs(a - angle) == 180 * 60 then --ignore perpendicular objs
				local hisBB = o:GetObjectBBox()
				local ib = IntersectRects(b, hisBB)
				if ib:IsValid() and (Max(ib:sizex(), ib:sizey()) >= halfVoxelSizeX / 2 and ib:sizez() >= halfVoxelSizeZ / 2) then
					--DbgAddBox(b)
					--DbgAddBox(hisBB)
					ret = true
					return "break"
				end
			end
		end
	end, obj, angle)
	
	return ret
end

SlabWallObject.MirroringFromRoom = empty_func
---
--- Indicates that the SlabWallObject cannot be mirrored.
---
--- This function is an override of the `CanMirror()` method, which is used to determine if an object can be mirrored. By returning `false`, this implementation disables the mirroring functionality for the SlabWallObject.
---
--- @return boolean false, indicating that the SlabWallObject cannot be mirrored.
---
function SlabWallObject:CanMirror()
	return false
end

---
--- Aligns the SlabWallObject to the nearest valid position and angle.
---
--- This function is called when the SlabWallObject is moved in the editor. It updates the position and angle of the object to the nearest valid voxel-aligned position, and checks for collisions with other SlabWallObjects. If a collision is detected, the object is not moved.
---
--- @return void
---
function SlabWallObject:EditorCallbackMove()
	self:AlignObj()
end

---
--- Aligns the SlabWallObject to the nearest valid position and angle.
---
--- This function is called when the SlabWallObject is moved in the editor. It updates the position and angle of the object to the nearest valid voxel-aligned position, and checks for collisions with other SlabWallObjects. If a collision is detected, the object is not moved.
---
--- @param pos table|nil The new position of the SlabWallObject. If not provided, the current position is used.
--- @param angle number|nil The new angle of the SlabWallObject. If not provided, the current angle is used.
--- @return void
---
function SlabWallObject:AlignObj(pos, angle)
	local x, y, z
	if pos then
		x, y, z, angle = WallWorldToVoxel(pos:x(), pos:y(), pos:z() or iz, angle or self:GetAngle())
	else
		x, y, z, angle = WallWorldToVoxel(self)
	end
	x, y, z = WallVoxelToWorld(x, y, z, angle)
	local oldPos = self:GetPos()
	local newPos = point(x, y, z)
	if not newPos:z() then
		newPos = newPos:SetZ(snapZCeil(terrain.GetHeight(newPos:xy())))
	end
	
	if pos then
		--this tests for collision with other wallobjs
		if oldPos:IsValid() and oldPos ~= newPos then
			if IntersectWallObjs(self, newPos, self.width, self.height, angle) then
				--print("WallObject could not move due to collision with other wall obj!", self.handle, newPos, oldPos)
				newPos = oldPos
			end
		end
	end
	
	self:SetPosAngle(newPos:x(), newPos:y(), newPos:z() or const.InvalidZ, angle)
	self:PostEntityUpdate() -- updates self.main_wall
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	
	if is_permanent and self.main_wall then
		self:Setside(self.main_wall.side)
		self:ChangeRoom(self.main_wall.room)
	else
		self:Setside(false)
		self:ChangeRoom(false)
	end
end

-- depending on height/width
local SlabWallObject_BaseNames = { "WindowVent", "Window", "Door", "TallDoor" }
local SlabWallObject_BaseNames_Window = { "WindowVent", "Window", "WindowBig", "TallWindow" }
local SlabWallObject_WidthNames = { "Single", "Double", "Triple", "Quadruple", [0] = "Small" }

---
--- Generates the name of a SlabWallObject based on its material, height, width, variant, and whether it is a door.
---
--- @param material string The material of the SlabWallObject.
--- @param height number The height index of the SlabWallObject.
--- @param width number The width index of the SlabWallObject.
--- @param variant number|nil The variant index of the SlabWallObject.
--- @param isDoor boolean|nil Whether the SlabWallObject is a door.
--- @return string The generated name of the SlabWallObject.
---
function SlabWallObjectName(material, height, width, variant, isDoor)
	local base = isDoor ~= nil and not isDoor and SlabWallObject_BaseNames_Window[height] or SlabWallObject_BaseNames[height] or ""
	
	if variant then
		local v = variant <= 0 and 1 or variant
		local str = variant < 10 and "%s_%s_%s_0%s" or "%s_%s_%s_%s"
		return string.format(str, base, material, 
							SlabWallObject_WidthNames[width] or "", tostring(v))
	else
		return string.format("%s_%s_%s", base, 
							material, SlabWallObject_WidthNames[width] or "")
	end
end

---
--- Initializes the properties of a SlabWallObject from its entity name.
---
--- This function is called when a SlabWallObject is placed in the editor. It extracts the height, material, width, and subvariant of the SlabWallObject from its entity name and sets the corresponding properties on the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance to initialize.
---
function SlabWallObject:EditorCallbackPlaceCursor()
	-- init properties from entity
	if IsValidEntity(self.class) then
		local e = self.class
		local strs = string.split(e, "_")
		local base = strs[1]
		local idxW = table.find(SlabWallObject_BaseNames_Window, base)
		local idxD = table.find(SlabWallObject_BaseNames, base)
		local isDoor = false
		if idxW then
			--window
			self.height = idxW
			if self:IsDoor() then
				assert(false, "Please fix " .. self.class .. ". It is named as a window but its parent class a door!")
			end
		else
			--door
			self.height = idxD
			if not self:IsDoor() then
				--zulu door SlabWallDoor
				--bacon door SlabDoor
				--setmetatable(self, g_Classes.SlabDoor or g_Classes.SlabWallDoor) --this wont work, cuz they inherit more then one thing.
				assert(false, "Please fix " .. self.class .. ". It is named as a door but its parent class is not a door!")
			end
		end
		
		self.material = strs[2]
		local w = table.find(SlabWallObject_WidthNames, strs[3]) or SlabWallObject_WidthNames[0] == strs[3] and 0
		assert(w)
		self.width = w
		self.subvariant = tonumber(strs[4])
		self:UpdateEntity()
		assert(self:GetEntity() == e, string.format("Failed to guess props from ent for slab wall obj, ent %s, picked ent %s", e, self:GetEntity()))
	end
end

---
--- Called when a SlabWallObject is placed in the editor.
---
--- This function is responsible for initializing the properties of the SlabWallObject based on its entity name. It extracts the height, material, width, and subvariant from the entity name and sets the corresponding properties on the SlabWallObject.
---
--- If the entity name does not match the expected format, this function will assert and report the issue.
---
--- @param self SlabWallObject The SlabWallObject instance being placed.
--- @param reason string The reason for the placement (e.g. "undo", "copy", etc.).
---
function SlabWallObject:EditorCallbackPlace(reason)
	Slab.EditorCallbackPlace(self, reason)
	if reason ~= "undo" then
		self:EditorCallbackPlaceCursor()
		self:FixNoRoom()
	end
end

---
--- Checks if a SlabWallObject has a valid entity for the given subvariant.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param var number The subvariant to check.
--- @return boolean True if a valid entity exists for the given subvariant, false otherwise.
---
function SlabWallObject:HasEntityForSubvariant(var)
	local ret = SlabWallObjectName(self.material, self.height, self.width, var, self:IsDoor())
	return IsValidEntity(ret)
end

---
--- Checks if a SlabWallObject has a valid entity for the given height.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param height number The height to check.
--- @return boolean True if a valid entity exists for the given height, false otherwise.
--- @return string The name of the valid entity, or nil if no valid entity exists.
---
function SlabWallObject:HasEntityForHeight(height)
	local ret
	if self.subvariant then
		ret = SlabWallObjectName(self.material, height, self.width, self.subvariant, self:IsDoor())
		if IsValidEntity(ret) then
			return true
		end
	end
	
	return IsValidEntity(SlabWallObjectName(self.material, height, self.width, nil, self:IsDoor())), ret
end

---
--- Checks if a SlabWallObject has a valid entity for the given width.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param width number The width to check.
--- @return boolean True if a valid entity exists for the given width, false otherwise.
--- @return string The name of the valid entity, or nil if no valid entity exists.
---
function SlabWallObject:HasEntityForWidth(width)
	local ret
	if self.subvariant then
		ret = SlabWallObjectName(self.material, self.height, width, self.subvariant, self:IsDoor())
		if IsValidEntity(ret) then
			return true
		end
	end
	
	return IsValidEntity(SlabWallObjectName(self.material, self.height, width, nil, self:IsDoor())), ret
end

---
--- Composes the name of a valid SlabWallObject entity based on the object's properties.
---
--- If the SlabWallObject has a subvariant, this function first checks if a valid entity exists for the given material, height, width, and subvariant. If a valid entity is found, it returns the entity name. If no valid entity is found, it reports the missing entity.
---
--- If the SlabWallObject does not have a subvariant, this function returns the entity name for the given material, height, and width, with a nil subvariant.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return string The name of the valid SlabWallObject entity.
---
function SlabWallObject:ComposeEntityName()
	if self.subvariant then
		local ret = SlabWallObjectName(self.material, self.height, self.width, self.subvariant, self:IsDoor())
		if IsValidEntity(ret) then
			return ret
		else
			self:ReportMissingSlabEntity(ret)
		end
	end
		
	return SlabWallObjectName(self.material, self.height, self.width, nil, self:IsDoor())
end

---
--- Callback function called when the SlabWallObject is deleted from the editor.
---
--- This function is responsible for removing the SlabWallObject from its parent containers when it is deleted outside of the GED room editor.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param reason string The reason for the deletion.
---
function SlabWallObject:EditorCallbackDelete(reason)
	--Slab.EditorCallbackDelete(self, reason) --this will do nothing
	if IsValid(self.room) then
		self.room:OnWallObjDeletedOutsideOfGedRoomEditor(self) --this will remove from parent containers
	end
end

---
--- Performs cleanup and removal of the SlabWallObject from its parent containers.
---
--- This function is responsible for restoring any affected slabs, removing the SlabWallObject from any owned objects or slabs, and removing the SlabWallObject from its parent room's spawned doors or windows.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:Done()
	self:RestoreAffectedSlabs()
	DoneObjects(self.owned_slabs)
	self.owned_slabs = false
	if self.owned_objs then
		DoneObjects(self.owned_objs)
	end
	self.owned_objs = false
	
	if not self.room or not self.side then return end
	local isDoor = self:IsDoor()
	local c
	if isDoor then
		c = self.room.spawned_doors and self.room.spawned_doors[self.side]
	else
		c = self.room.spawned_windows and self.room.spawned_windows[self.side]
	end
	if not c then return end
	table.remove_entry(c, self)
end

---
--- Iterates over the affected walls associated with this SlabWallObject and calls the provided callback function on each valid wall.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param callback function|string The callback function to call on each affected wall, or the name of a method on the wall object to call.
--- @param ... any Additional arguments to pass to the callback function.
---
function SlabWallObject:ForEachAffectedWall(callback, ...)
	for _, wall in ipairs(self.affected_walls or empty_table) do
		if IsValid(wall) and wall.wall_obj == self then
			local func = type(callback) == "function" and callback or wall[callback]
			func(wall, ...)
		end
	end
end

---
--- Restores the affected slabs associated with this SlabWallObject.
---
--- This function suspends pass edits, iterates over the affected walls associated with this SlabWallObject, and sets the wall object on each valid wall. It then clears the affected_walls and main_wall properties of the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:RestoreAffectedSlabs()
	SuspendPassEdits("SlabWallObject:RestoreAffectedSlabs")
	for _, wall in ipairs(self.affected_walls or empty_table) do
		if IsValid(wall) and wall.wall_obj == self then
			wall:SetWallObj()
		end
	end

	self.affected_walls = nil
	self.main_wall = nil
	ResumePassEdits("SlabWallObject:RestoreAffectedSlabs")
end

---
--- Sets a property on the SlabWallObject instance.
---
--- If the property being set is "width" or "height", this function will also call `DelayedUpdateEntity()` to update the entity.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param id string The property ID to set.
--- @param value any The value to set the property to.
---
function SlabWallObject:SetProperty(id, value)
	Slab.SetProperty(self, id, value)
	if IsChangingMap() then return end
	if id == "width" or id == "height" then
		self:DelayedUpdateEntity()
	end
end

---
--- Called after the SlabWallObject is loaded, this function triggers a delayed update of the entity.
---
--- This function is used to ensure that the entity is properly updated after the object is loaded, as some properties may have changed during the loading process.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:PostLoad()
	self:DelayedUpdateEntity()
end

---
--- Updates the SlabWallObject entity.
---
--- If the object is destroyed, this function first updates the destroyed state and returns if the object is still destroyed. Otherwise, it destroys any attached objects, updates the entity, automatically attaches objects, and refreshes the entity state and class.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:UpdateEntity()
	if self.is_destroyed then
		if self:UpdateDestroyedState() then
			return
		end
	end
	
	self:DestroyAttaches()
	Slab.UpdateEntity(self)
	AutoAttachObjects(self)
	self:PostEntityUpdate()
	self:RefreshEntityState()
	self:RefreshClass()
end

---
--- Cycles the entity associated with the SlabWallObject instance.
---
--- This function first calls the `CycleEntity()` method of the `EditorSubVariantObject` class, which handles the cycling of the entity. It then refreshes the entity state, refreshes the class, and updates the managed objects associated with the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param delta number The amount to cycle the entity by.
---
function SlabWallObject:CycleEntity(delta)
	EditorSubVariantObject.CycleEntity(self, delta)
	self:RefreshEntityState()
	self:RefreshClass()
	self:PostEntityUpdate()
end

---
--- Refreshes the class of the SlabWallObject instance.
---
--- This function is used to ensure that the SlabWallObject instance has the correct class metadata. It first retrieves the entity associated with the SlabWallObject, and if the entity is valid, it checks if the class of the entity is a subclass of SlabWallObject. If so, it sets the metatable of the SlabWallObject instance to the class of the entity.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:RefreshClass()
	--SlabWallObject is a cls that generates ent from given props
	--SlabWallWindow and SlabWallWindowBroken are functional classes, where ents inherit them
	local e = self:GetEntity()
	if IsValidEntity(e) then
		local cls = g_Classes[e]
		if cls and IsKindOf(cls, "SlabWallObject") then
			setmetatable(self, cls)
		end
	end
end

---
--- Iterates through all maps and refreshes the class of all `SlabWallObject` instances.
---
--- This function is used to ensure that all `SlabWallObject` instances have the correct class metadata. It does this by iterating through all maps, and for each map, it iterates through all `SlabWallObject` instances and calls the `RefreshClass()` method on each one. After updating all the `SlabWallObject` instances, the function saves the map without creating a backup.
---
--- This function is primarily used for debugging purposes, to ensure that the class metadata of all `SlabWallObject` instances is up-to-date.
---
--- @function DbgChangeClassOfAllWindows
function DbgChangeClassOfAllWindows()
	CreateRealTimeThread(function()
		ForEachMap(ListMaps(), function()
			MapForEach("map", "SlabWallObject", function(obj)
				obj:RefreshClass()
			end)
			SaveMap("no backup")
		end)
	end)
end

---
--- Refreshes the entity state of the SlabWallObject instance.
---
--- This function is a callback for when the SlabWallObject is lockpickable. It is used to update the state of the entity associated with the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:RefreshEntityState()
	--cb for lockpickable
end

---
--- Called after the entity associated with the SlabWallObject is updated.
---
--- This function is responsible for updating the affected walls, managed slabs, and managed objects associated with the SlabWallObject. It is called after the entity is updated to ensure that the related elements are also updated.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:PostEntityUpdate()
	self:UpdateAffectedWalls()
	self:UpdateManagedSlabs()
	self:UpdateManagedObj()
end

---
--- Checks if the SlabWallObject is a window.
---
--- This function returns true if the SlabWallObject is not a door, indicating that it is a window.
---
--- @function SlabWallObject:IsWindow
--- @return boolean True if the SlabWallObject is a window, false otherwise.
function SlabWallObject:IsWindow()
	return not self:IsDoor()
end

---
--- Checks if the SlabWallObject is a door.
---
--- This function returns true if the SlabWallObject is a door, false otherwise.
---
--- @function SlabWallObject:IsDoor
--- @return boolean True if the SlabWallObject is a door, false otherwise.
function SlabWallObject:IsDoor()
	return IsKindOfClasses(self, "SlabWallDoorDecor", "SlabWallDoor") or false
end

---
--- Iterates over the slab positions associated with the SlabWallObject.
---
--- This function calls the provided `func` callback for each slab position associated with the SlabWallObject. The callback is called with the x, y, z coordinates of each slab position, as well as any additional arguments passed to the `ForEachSlabPos` function.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param func function The callback function to call for each slab position.
--- @param ... any Additional arguments to pass to the callback function.
---
function SlabWallObject:ForEachSlabPos(func, ...)
	local width = self.width
	local height = self.height
	if width <= 0 or height <= 0 then return end
	
	local x, y, z = self:GetPosXYZ()
	if not z then
		z = terrain.GetHeight(x, y)
	end
	local side = self:GetSide()
	
	for w = 1, width do
		for h = 1, self.height do
			local tx, ty, tz, wf
			tz = z + (h - 1) * const.SlabSizeZ
			wf = (w - width/2 - 1)
			if side == "E" then 		-- x = const
				tx = x
				ty = y + wf * const.SlabSizeY
			elseif side == "W" then 	-- x = const
				tx = x
				ty = y - wf * const.SlabSizeY
			elseif side == "N" then	-- y = const
				tx = x + wf * const.SlabSizeX
				ty = y
			else 							-- y = const
				tx = x - wf * const.SlabSizeX
				ty = y
			end
			
			func(tx, ty, tz, ...)
		end
	end
end

---
--- Updates the affected walls for the SlabWallObject.
---
--- This function suspends pass edits, calculates the new affected walls, and updates the main wall. It iterates over the slab positions associated with the SlabWallObject and sets the wall object for any valid slabs that are not already associated with the SlabWallObject. It then picks the main wall from the affected walls. Finally, it removes the wall object association for any slabs that are no longer affected.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return table The old affected walls.
---
function SlabWallObject:UpdateAffectedWalls()
	SuspendPassEdits("SlabWallObject:UpdateAffectedWalls")
	
	local old_aw = self.affected_walls or empty_table
	local new_aw = {}
	self.affected_walls = new_aw
	self.main_wall = nil
	
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	local x, y, z = self:GetPosXYZ()
	if not z then
		z = terrain.GetHeight(x, y)
	end
	local side = self:GetSide()
	local width = Max(self.width, 1)
	for w = 1, width do
		for h = 1, self.height do
			local tx, ty, tz, wf
			tz = z + (h - 1) * const.SlabSizeZ
			wf = (w - width/2 - 1)
			if side == "E" then 		-- x = const
				tx = x
				ty = y + wf * const.SlabSizeY
			elseif side == "W" then 	-- x = const
				tx = x
				ty = y - wf * const.SlabSizeY
			elseif side == "N" then	-- y = const
				tx = x + wf * const.SlabSizeX
				ty = y
			else 							-- y = const
				tx = x - wf * const.SlabSizeX
				ty = y
			end
			
			local is_main_pos = tx == x and ty == y and tz == z
			local main_slab_candidates = is_main_pos and {}
			MapForEach(tx, ty, tz, 0, "WallSlab", nil, nil, gameFlags, function(slab, self, is_main_pos, is_permanent)
				local wall_obj = slab.wall_obj
				if IsValid(wall_obj) and wall_obj ~= self and not new_aw[slab] then
					return
				end
				if self.owned_slabs and table.find(self.owned_slabs, slab) then
					return
				end
				if wall_obj ~= self and (is_permanent or slab:GetGameFlags(gofPermanent) == 0) then
					-- non permanent wall objs should not affect permanent walls
					slab:SetWallObj(self)
				end
				new_aw[slab] = true
				table.insert(new_aw, slab)
				if is_main_pos then
					table.insert(main_slab_candidates, slab)
				end
			end, self, is_main_pos, is_permanent)
			
			if is_main_pos and #main_slab_candidates > 0 then
				--first non roof slab, if any
				self:PickMainWall(main_slab_candidates)
			end
		end
	end
	
	if not self.main_wall and #new_aw > 0 then
		--this makes it so that main_wall wont be in the same pos as the window/door, idk what that will break..
		--this is a fix for a fringe case where the slab at the door/window pos is deleted
		self:PickMainWall(new_aw)
	end
	
	for _, slab in ipairs(old_aw) do
		if IsValid(slab) and slab.wall_obj == self and not new_aw[slab] then
			slab:SetWallObj()
		end
	end
	
	ResumePassEdits("SlabWallObject:UpdateAffectedWalls")
	
	return old_aw
end

---
--- Picks the main wall slab from a list of candidate slabs.
---
--- @param t table A table of candidate wall slabs.
--- @return boolean|WallSlab The main wall slab, or `false` if no suitable slab was found.
---
function SlabWallObject:PickMainWall(t)
	local iHaveRoom = not not self.room
	local roofCandidate = false
	local nonRoofCandidateDiffRoom = false
	local nonRoofRotatedCandidate = false
	self.main_wall = false
	
	for i = 1, #t do
		local s = t[i]
		local slabHasRoom = not not s.room
		local anyRoomMissing = (not slabHasRoom or not iHaveRoom)
		local slaba = s:GetAngle()
		local selfa = self:GetAngle()
		local angleIsTheSame = slaba == selfa
		local angleIsReveresed = abs(slaba - selfa) == 180*60
		
		if (slabHasRoom and s.room == self.room or 
			not iHaveRoom and 
			(angleIsTheSame or angleIsReveresed)) and 
			(anyRoomMissing or s.room.being_placed == self.room.being_placed) then
			if not IsKindOf(s, "RoofWallSlab") then
				if angleIsReveresed then
					nonRoofRotatedCandidate = s
				else
					self.main_wall = s
					return
				end
			elseif not roofCandidate then
				roofCandidate = s
			end
		elseif not anyRoomMissing and s.room ~= self.room and angleIsTheSame then
			nonRoofCandidateDiffRoom = s
		end
	end
	
	self.main_wall = self.main_wall or nonRoofCandidateDiffRoom or nonRoofRotatedCandidate or roofCandidate
end

---
--- Destroys all attached objects for this SlabWallObject.
---
--- This function is called when the SlabWallObject is being destroyed. It will
--- destroy all attached objects, except for the editor text object if this
--- SlabWallObject is an EditorTextObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:DestroyAttaches()
	if self.is_destroyed and string.find(GetStack(2), "SetAutoAttachMode") then
		--todo: hack
		return
	end
	Slab.DestroyAttaches(self, function(o, doNotDelete)
		if IsKindOf(self, "EditorTextObject") and o == self.editor_text_obj then return end
		return not doNotDelete or not IsKindOf(o, doNotDelete.class)
	end, g_Classes.ConstructionSite)
end

---
--- Sets the shadow-only state of all managed slabs.
---
--- This function is used to set the shadow-only state of all slabs managed by
--- this SlabWallObject. If `clear_contour` is true, it will also clear the
--- contour inner flag for each managed slab.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param val boolean The new shadow-only state to set for the managed slabs.
--- @param clear_contour boolean If true, the contour inner flag will be cleared for each managed slab.
---
function SlabWallObject:SetManagedSlabsShadowOnly(val, clear_contour)
	for i = 1, #(self.owned_slabs or "") do
		local slab = self.owned_slabs[i]
		if slab then --can be saved as false if deleted by user
			slab:SetShadowOnly(val)
			if clear_contour then
				slab:ClearHierarchyGameFlags(const.gofContourInner)
			end
		end
	end
end

function OnMsg.EditorCallback(id, objs)
	if id == "EditorCallbackDelete" then
		for i = 1, #objs do
			local o = objs[i]
			if IsKindOf(o, "WallSlab") and o.always_visible and o:GetClipPlane() ~= 0 then
				local x, y, z = o:GetPosXYZ()
				local swo = MapGetFirst(x, y, z, 0, "SlabWallObject")
				if swo and swo.owned_slabs then
					local idx = table.find(swo.owned_slabs, o)
					if idx then
						swo.owned_slabs[idx] = false
					end
				end
			end
		end
	end
end

---
--- Updates the managed slabs for the SlabWallObject.
---
--- This function is responsible for updating the slabs managed by the SlabWallObject. It ensures that the managed slabs are properly positioned, sized, and configured based on the main wall and the SlabWallObject's properties.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:UpdateManagedSlabs()
	if self.width == 0 then
		--small window
		local main = self.main_wall
		
		--clipboard cpy paste fix, owned_slabs contains empty tables
		for i = 1, #(self.owned_slabs or "") do
			local s = self.owned_slabs[i]
			if not IsValid(s) then
				self.owned_slabs[i] = nil
			end
		end

		if not main or (main:GetAngle() ~= self:GetAngle() or self.room and self.room ~= main.room) then
			self:UpdateAffectedWalls()
			main = self.main_wall
			if not main then
				DoneObjects(self.owned_slabs)
				self.owned_slabs = false
				return
			end
		end
		
		if self.owned_slabs and self.owned_slabs[1] == false then
			--happens after copy
			DoneObjects(self.owned_slabs)
			self.owned_slabs = false
		end
		
		if not self.owned_slabs then
			self.owned_slabs = {}
			local s = WallSlab:new({always_visible = true, forceInvulnerableBecauseOfGameRules = false})
			table.insert(self.owned_slabs, s)
			s = WallSlab:new({always_visible = true, forceInvulnerableBecauseOfGameRules = false})
			table.insert(self.owned_slabs, s)
		end
		
		local bb = self:GetObjectBBox()
		local isVerticalAligned = self:GetAngle() % (180 * 60) == 0
		local mx, my, mz = main:GetPosXYZ()
		local ma = main:GetAngle()
		local destroyed = self.is_destroyed
		
		for i = 1, 2 do
			local s = self.owned_slabs[i]
			if IsValid(s) then --this is false when deleted manually and saved
				s:SetPosAngle(mx, my, mz, ma)
				s.material = main.material
				s.variant = main.variant
				s.indoor_material_1 = main.indoor_material_1
				s.indoor_material_2 = main.indoor_material_2
				s.subvariant = main.subvariant
				s:UpdateEntity()
				s:UpdateVariantEntities()
				local room = main.room
				s:SetColorModifier(main:GetColorModifier())
				s:Setcolors(main.colors or room and room.outer_colors)
				s:Setinterior_attach_colors(main.interior_attach_colors or room and room.inner_colors)
				s:Setexterior_attach_colors(main.exterior_attach_colors)
				s:Setexterior_attach_colors_from_nbr(main.exterior_attach_colors_from_nbr)
				s:SetWarped(main:GetWarped())
				collision.SetAllowedMask(s, 0)
				--save fixup, default state of slabs is invulnerable, so all small window helper slabs are now all saved as such..
				s.forceInvulnerableBecauseOfGameRules = false --TODO:remove
				s.invulnerable = false --TODO:remove
				
				if destroyed ~= s.is_destroyed then
					if destroyed then
						s:Destroy()
					else
						s:Repair()
					end
				end
				
				local p1, p2, p3
				
				if i == 2 then
					p3 = bb:min()
					p1 = p3 + point(0, 0, bb:sizez())
					if isVerticalAligned then
						p2 = p1 + point(bb:sizex(), 0, 0)
					else
						p2 = p1 + point(0, bb:sizey(), 0)
					end
				else
					p1 = bb:max()
					p3 = p1 - point(0, 0, bb:sizez())
					if isVerticalAligned then
						p2 = p1 - point(bb:sizex(), 0, 0)
					else
						p2 = p1 - point(0, bb:sizey(), 0)
					end
				end
				
				if isVerticalAligned then
					--east/west needs inversion
					p1, p3 = p3, p1
				end
				
				--DbgAddVector(p1, p2 - p1)
				--DbgAddVector(p2, p3 - p2)
				--DbgAddVector(p3, p1 - p3)
				
				s:SetClipPlane(PlaneFromPoints( p1, p2, p3 ))
			else
				self.owned_slabs[i] = false
			end
		end
	else
		if self.owned_slabs then
			DoneObjects(self.owned_slabs)
		end
		self.owned_slabs = false
	end
end

local function TryGetARepresentativeWall(self, wall)
	local mw
	if not mw then
		--mw = MapGetFirst(self, 0, "WallSlab", nil, const.efVisible)
		local aw = self.affected_walls
		for i = 1, #(aw or "") do
			local w = aw[i]
			if w.invisible_reasons and not w.invisible_reasons["suppressed"] then
				mw = w
				break
			end
		end
		
	end
	return mw or self.main_wall
end

local function TryFigureOutInteriorMaterialOnTheExteriorSide(self)
	local m, c, _
	local mw = TryGetARepresentativeWall(self)
	
	if mw then
		if self:GetAngle() == mw:GetAngle() then
			m = mw.indoor_material_2
			_, c = mw:GetAttachColors()
		else
			m = mw.indoor_material_1
			c = mw:GetAttachColors()
		end
	else
		m = self.material
	end
	
	
	return m ~= noneWallMat and m or false, c or self.colors or self:GetDefaultColor()
end

local function TryFigureOutInteriorMaterial(self)
	local m, c, _
	local mw = TryGetARepresentativeWall(self)
	
	if mw then
		if self:GetAngle() == mw:GetAngle() then
			m = mw.indoor_material_1
			c = mw:GetAttachColors()
		else
			m = mw.indoor_material_2
			_, c = mw:GetAttachColors()
		end
	elseif self.room then
		m = self.room.inner_wall_mat
		c = self.room.inner_colors
	end
	
	
	return m ~= noneWallMat and m or false, c
end

local function GetAttchEntName(e, material)
	if material then
		local e = string.format("%s_Int_%s", e, material)
		if IsValidEntity(e) then
			return e
		end
	end
	return string.format("%s_Int", e)
end

---
--- Updates the managed objects associated with this SlabWallObject.
--- This function is responsible for creating, updating, and destroying the
--- additional objects that are part of this SlabWallObject, such as window
--- decorations or door frames.
---
--- The function first checks if the SlabWallObject is not destroyed. If it is
--- not destroyed, it iterates through the "Interior1" and "Interior2" spots
--- on the object and creates or updates the associated managed objects. The
--- managed objects are placed at the correct position and angle, and their
--- colors are set based on the material and colors of the SlabWallObject.
---
--- If a managed object is no longer needed, it is destroyed. If all managed
--- objects are destroyed, the `owned_objs` table is set to `false`.
---
--- If the SlabWallObject is destroyed, all managed objects are destroyed and
--- the `owned_objs` table is set to `false`.
---
--- @function SlabWallObject:UpdateManagedObj
--- @return nil
function SlabWallObject:UpdateManagedObj()
	--some windows are composed from more than one entity for kicks
	--it musn't be attached or the colors don't work.
	if not self.is_destroyed then
		local function setupObj(ea, color, idx, si)
			local t = self.owned_objs
			if not t then
				t = {}
				for i = 1, idx - 1 do
					t[i] = false
				end
				self.owned_objs = t
			end
			
			if not IsValid(t[idx]) then
				t[idx] = PlaceObject("Object")
			end
			
			local o = t[idx]
			if o:GetEntity() ~= ea then
				o:ChangeEntity(ea)
			end
			o:SetPos(self:GetSpotPos(si))
			o:SetAngle(self:GetSpotAngle2D(si))
			SetSlabColorHelper(o, color)
		end
		
		local function manageObj(spotName, idx, mat_func)
			local added = false
			if self:HasSpot(spotName) then
				local si = self:GetSpotBeginIndex(spotName)
				local e = self:GetEntity()
				local material, color = mat_func(self)
				local ea = GetAttchEntName(e, material)
				
				if IsValidEntity(ea) then
					setupObj(ea, color, idx, si)
					added = true
				else
					print("SlabWallObject has a " .. spotName .. " spot defined but no ent found to place there [" .. ea .. "]")
				end
			end
			if not added then
				local t = self.owned_objs
				if t and IsValid(t[idx]) then
					DoneObject(t[idx])
					t[idx] = false
				end
			end
		end
		
		manageObj("Interior1", 1, TryFigureOutInteriorMaterial)
		manageObj("Interior2", 2, TryFigureOutInteriorMaterialOnTheExteriorSide)
		
		local t = self.owned_objs
		if t and not IsValid(t[1]) and not IsValid(t[2]) then
			self.owned_objs = false
		end
	else
		if self.owned_objs then
			DoneObjects(self.owned_objs)
		end
		self.owned_objs = false
	end
end

---
--- Sets the shadow-only state of the SlabWallObject and all its owned objects.
---
--- @param val boolean Whether the object should be shadow-only or not.
--- @param ... any Additional arguments to pass to the `Slab.SetShadowOnly` function.
---
function SlabWallObject:SetShadowOnly(val, ...)
	Slab.SetShadowOnly(self, val, ...)
	for _, o in ipairs(self.owned_objs or empty_table) do
		o:SetShadowOnly(val, ...)
	end
end

---
--- Returns the class of the SlabWallObject instance.
---
--- @return table The class of the SlabWallObject instance.
---
function SlabWallObject:GetPlaceClass()
	return self
end

---
--- Returns an error message if there are any issues with the SlabWallObject.
---
--- This function checks if there are any other SlabWallObject instances stacked on top of this one, or if the SlabWallObject is not properly aligned with a WallSlab. If any issues are found, an error message is returned.
---
--- @return string|nil An error message if there are any issues, or nil if the SlabWallObject is valid.
---
function SlabWallObject:GetError()
	local lst = MapGet(self, 0, "SlabWallObject")
	if #lst > 1 then
		return "Stacked doors/windows!"
	end

	self:ForEachSlabPos(function(x, y, z)
		local slb = MapGetFirst(x, y, z, 0, "WallSlab")
		if slb then
			if slb.wall_obj ~= self then
				return "Stacked doors/windows!"
			end
		end
	end)
end

DefineClass.SlabWallDoorDecor = { --SlabWallDoor carries logic in zulu, SlabWallDoorDecor == SlabWallObject but is considered a door by IsDoor
	__parents = { "SlabWallObject" },
	fx_actor_class = "Door",
}

DefineClass("SlabWallDoor", "SlabWallDoorDecor") --door with decals
DefineClass("SlabWallWindow", "SlabWallObject") --window with decals
DefineClass("SlabWallWindowBroken", "SlabWallObject")

--- Returns the first object of the specified class that is aligned with the given floor voxel coordinates.
---
--- @param gx number The x coordinate of the floor voxel.
--- @param gy number The y coordinate of the floor voxel.
--- @param gz number The z coordinate of the floor voxel.
--- @param class string The class of the object to retrieve.
--- @return table|nil The first object of the specified class that is aligned with the given floor voxel coordinates, or nil if no such object is found.
function GetFloorAlignedObj(gx, gy, gz, class)
	local x, y, z = VoxelToWorld(gx, gy, gz)
	return MapGetFirst(x, y, z, 0, class, nil, efVisible)
end

---
--- Returns the first object of the specified class that is aligned with the given wall voxel coordinates.
---
--- @param gx number The x coordinate of the wall voxel.
--- @param gy number The y coordinate of the wall voxel.
--- @param gz number The z coordinate of the wall voxel.
--- @param dir number The direction of the wall (0 = north, 1 = east, 2 = south, 3 = west).
--- @param class string The class of the object to retrieve.
--- @return table|nil The first object of the specified class that is aligned with the given wall voxel coordinates, or nil if no such object is found.
function GetWallAlignedObj(gx, gy, gz, dir, class)
	local x, y, z = WallVoxelToWorld(gx, gy, gz, dir)
	return MapGetFirst(x, y, z, 0, class, nil, efVisible)
end

---
--- Returns a table of all objects of the specified class that are aligned with the given wall voxel coordinates.
---
--- @param gx number The x coordinate of the wall voxel.
--- @param gy number The y coordinate of the wall voxel.
--- @param gz number The z coordinate of the wall voxel.
--- @param dir number The direction of the wall (0 = north, 1 = east, 2 = south, 3 = west).
--- @param class string The class of the objects to retrieve.
--- @return table A table of all objects of the specified class that are aligned with the given wall voxel coordinates, or an empty table if no such objects are found.
function GetWallAlignedObjs(gx, gy, gz, dir, class)
	local x, y, z = WallVoxelToWorld(gx, gy, gz, dir)
	return MapGet(x, y, z, 0, class, nil, nil, gofPermanent) or empty_table
end

---
--- Returns the first floor slab object aligned with the given floor voxel coordinates.
---
--- @param gx number The x coordinate of the floor voxel.
--- @param gy number The y coordinate of the floor voxel.
--- @param gz number The z coordinate of the floor voxel.
--- @return table|nil The first floor slab object aligned with the given floor voxel coordinates, or nil if no such object is found.
function GetFloorSlab(gx, gy, gz)
	return GetFloorAlignedObj(gx, gy, gz, "FloorSlab")
end

---
--- Returns the first wall slab object aligned with the given wall voxel coordinates.
---
--- @param gx number The x coordinate of the wall voxel.
--- @param gy number The y coordinate of the wall voxel.
--- @param gz number The z coordinate of the wall voxel.
--- @param side number The direction of the wall (0 = north, 1 = east, 2 = south, 3 = west).
--- @return table|nil The first wall slab object aligned with the given wall voxel coordinates, or nil if no such object is found.
function GetWallSlab(gx, gy, gz, side)
	return GetWallAlignedObj(gx, gy, gz, side, "WallSlab")
end

---
--- Returns a table of all wall slab objects aligned with the given wall voxel coordinates.
---
--- @param gx number The x coordinate of the wall voxel.
--- @param gy number The y coordinate of the wall voxel.
--- @param gz number The z coordinate of the wall voxel.
--- @param side number The direction of the wall (0 = north, 1 = east, 2 = south, 3 = west).
--- @return table A table of all wall slab objects aligned with the given wall voxel coordinates.
function GetWallSlabs(gx, gy, gz, side)
	return GetWallAlignedObjs(gx, gy, gz, side, "WallSlab")
end

---
--- Returns the first stair slab object aligned with the given floor voxel coordinates.
---
--- @param gx number The x coordinate of the floor voxel.
--- @param gy number The y coordinate of the floor voxel.
--- @param gz number The z coordinate of the floor voxel.
--- @return table|nil The first stair slab object aligned with the given floor voxel coordinates, or nil if no such object is found.
function GetStairSlab(gx, gy, gz)
	return GetFloorAlignedObj(gx, gy, gz, "StairSlab")
end

---
--- Enumerates all connected floor slab objects starting from the given floor voxel coordinates.
---
--- @param x number The x coordinate of the floor voxel.
--- @param y number The y coordinate of the floor voxel.
--- @param z number The z coordinate of the floor voxel.
--- @param visited table A table to keep track of visited voxels and slab objects.
--- @return table A table of all connected floor slab objects.
function EnumConnectedFloorSlabs(x, y, z, visited)
	local queue, objs = {}, {}
	visited = visited or {}
	
	local function push(x, y, z)
		local hash = slab_hash(x, y, z)
		if visited[hash] then return end
		visited[hash] = true
		
		local slab = GetFloorSlab(x, y, z)
		if not slab or visited[slab] then return end
		visited[slab] = true
		
		table.insert_unique(objs, slab)
		queue[#queue + 1] = { x = x, y = y, z = z }
	end
	
	push(x, y, z)
	while #queue > 0 do
		local loc = table.remove(queue)
		push(loc.x + 1, loc.y, loc.z)
		push(loc.x - 1, loc.y, loc.z)
		push(loc.x, loc.y + 1, loc.z)
		push(loc.x, loc.y - 1, loc.z)
	end
	return objs
end

---
--- Enumerates all connected wall slab objects starting from the given wall voxel coordinates.
---
--- @param x number The x coordinate of the wall voxel.
--- @param y number The y coordinate of the wall voxel.
--- @param z number The z coordinate of the wall voxel.
--- @param side string The side of the wall voxel to start from.
--- @param floor boolean Whether to only include wall slabs on the same floor.
--- @param enum_adjacent_sides boolean Whether to also enumerate adjacent wall slabs.
--- @param zdir number The direction to trace connected wall slabs (-1, 0, or 1).
--- @param visited table A table to keep track of visited voxels and slab objects.
--- @return table A table of all connected wall slab objects.
function EnumConnectedWallSlabs(x, y, z, side, floor, enum_adjacent_sides, zdir, visited)
	local queue, objs = {}, {}
	visited = visited or {}
	zdir = zdir or 0
	
	local function push(x, y, z, side)
		local hash = slab_hash(x, y, z, side)
		if visited[hash] then return end
		visited[hash] = true
		
		local slab = GetWallSlab(x, y, z, side)
		if not slab or (floor and slab.floor ~= floor) or visited[slab] then return end
		visited[slab] = true
		
		table.insert_unique(objs, slab)
		queue[#queue + 1] = { x = x, y = y, z = z, side = side }
	end
	
	push(x, y, z, side)
	while #queue > 0 do
		local loc = table.remove(queue)			
		if zdir >= 0 then
			push(loc.x, loc.y, loc.z + 1, loc.side)
		end
		if zdir <= 0 then
			push(loc.x, loc.y, loc.z - 1, loc.side)
		end
		if loc.side == "E" or loc.side == "W" then -- x = const
			push(loc.x, loc.y + 1, loc.z, loc.side)
			push(loc.x, loc.y - 1, loc.z, loc.side)
			if enum_adjacent_sides then
				push(loc.x, loc.y, loc.z, "S")
				push(loc.x, loc.y, loc.z, "N")
				
				-- handle non-convex shapes
				push(loc.x + 1, loc.y + 1, loc.z, "N")
				push(loc.x - 1, loc.y + 1, loc.z, "N")
				push(loc.x + 1, loc.y - 1, loc.z, "S")
				push(loc.x - 1, loc.y - 1, loc.z, "S")
			end
		else -- y = const
			push(loc.x + 1, loc.y, loc.z, loc.side)
			push(loc.x - 1, loc.y, loc.z, loc.side)
			if enum_adjacent_sides then
				push(loc.x, loc.y, loc.z, "E")
				push(loc.x, loc.y, loc.z, "W")
				
				-- handle non-convex shapes
				push(loc.x + 1, loc.y + 1, loc.z, "W")
				push(loc.x + 1, loc.y - 1, loc.z, "W")
				push(loc.x - 1, loc.y + 1, loc.z, "E")
				push(loc.x - 1, loc.y - 1, loc.z, "E")
			end
		end
	end
	return objs
end

---
--- Enumerates all connected stair slabs starting from the given grid coordinates.
---
--- @param x number The x-coordinate of the starting grid position.
--- @param y number The y-coordinate of the starting grid position.
--- @param z number The z-coordinate of the starting grid position.
--- @param zdir number The direction to trace the connected stairs (1 for up, -1 for down, 0 for both).
--- @param visited table A table to keep track of visited slabs.
--- @return table An array of connected stair slabs.
---
function EnumConnectedStairSlabs(x, y, z, zdir, visited)
	local stair = GetStairSlab(x, y, z)
	local objs = {}
	
	visited = visited or {}
	zdir = zdir or 0
	
	if stair then
		objs[1] = stair
		visited[stair] = true
		local first, last, all
		if zdir >= 0 then
			first, last, all = stair:TraceConnectedStairs(1)
			table.iappend(objs, all)
			for _, obj in ipairs(all) do
				visited[obj] = true
			end
		end
		if zdir <= 0 then
			first, last, all = stair:TraceConnectedStairs(-1)
			table.iappend(objs, all)
			for _, obj in ipairs(all) do
				visited[obj] = true
			end
		end
	end
	return objs
end

---
--- Finds the connected wall slab for the given object.
---
--- @param obj any The object to find the connected wall slab for.
--- @return WallSlab|nil The connected wall slab, or nil if not found.
---
function FindConnectedWallSlab(obj)
	if IsKindOf(obj, "WallSlab") then
		return obj
	elseif IsKindOf(obj, "SlabWallObject") then
		return obj.main_wall
	elseif IsKindOf(obj, "FloorSlab") then
		local x, y, z = obj:GetGridCoords()
		local tiles = EnumConnectedFloorSlabs(x, y, z)
		for _, tile in ipairs(tiles or empty_table) do
			x, y, z = tile:GetGridCoords()
			for _, side in ipairs(slab_sides) do
				local slab = GetWallSlab(x, y, z, side)
				if IsValid(slab) then
					return slab
				end
			end
		end
	end
end

---
--- Finds the connected floor slab for the given object.
---
--- @param obj any The object to find the connected floor slab for.
--- @return FloorSlab|nil The connected floor slab, or nil if not found.
---
function FindConnectedFloorSlab(obj)
	if IsKindOf(obj, "FloorSlab") then
		return obj
	end
	if IsKindOf(obj, "SlabWallObject") then
		obj = obj.main_wall
	end
	if IsKindOf(obj, "WallSlab") then
		local x, y, z = obj:GetGridCoords()
		local walls = EnumConnectedWallSlabs(x, y, z, obj:GetSide(), obj.floor)
		for _, wall in ipairs(walls) do
			x, y, z = wall:GetGridCoords()
			local slab = GetFloorSlab(x, y, z)
			if IsValid(slab) and slab.floor == obj.floor then
				return slab
			end
		end
	end
end

---
--- Recursively pushes up all connected floor and wall slabs starting from the given grid coordinates.
---
--- @param gx number The x-coordinate of the starting grid position.
--- @param gy number The y-coordinate of the starting grid position.
--- @param gz number The z-coordinate of the starting grid position.
--- @param visited table A table of visited grid coordinates to avoid revisiting.
---
function SlabsPushUp(gx, gy, gz, visited)
	visited = visited or {}
	local walls, floors = {}, {}
	local objs
	
	-- start by enumerating all connected slabs in the given grid coords
	floors = EnumConnectedFloorSlabs(gx, gy, gz, visited)
	for _, side in ipairs(slab_sides) do
		objs = EnumConnectedWallSlabs(gx, gy, gz, side, false, "enum adjacent", 1, visited)
		if #objs > 0 then
			table.iappend(walls, objs)
		end
	end
	
	-- enumerate the whole connected structure above	
	local iwall, ifloor = 1, 1
	while iwall <= #walls or ifloor <= #floors do
		if iwall <= #walls then
			local x, y, z = walls[iwall]:GetGridCoords()
			objs = EnumConnectedWallSlabs(x, y, z, walls[iwall]:GetSide(), false, "enum adjacent", 1, visited)
			if #objs > 0 then
				table.iappend(walls, objs)
			end
			objs = EnumConnectedFloorSlabs(x, y, z, visited)
			if #objs > 0 then
				table.iappend(floors, objs)
			end
			iwall = iwall + 1
		end
		if ifloor <= #floors then
			-- no need to check for other floors, they would be enumerated already
			local x, y, z = floors[ifloor]:GetGridCoords()
			for _, side in ipairs(slab_sides) do
				objs = EnumConnectedWallSlabs(x, y, z, side, false, "enum adjacent", 1, visited)
				if #objs > 0 then
					table.iappend(walls, objs)
				end
			end
			ifloor = ifloor + 1
		end
	end
	
	-- push up all enumerated objects by sz
	for _, obj in ipairs(floors) do
		local x, y, z = obj:GetPosXYZ()
		local gx, gy, gz = obj:GetGridCoords()
		obj:SetPos(x, y, z + sz)
		
		local stairs = EnumConnectedStairSlabs(gx, gy, gz)
		for i, stair in ipairs(stairs) do
			x, y, z = stair:GetPosXYZ()
			stair:SetPos(x, y, z + sz)
		end
	end
	for _, obj in ipairs(walls) do
		local x, y, z = obj:GetPosXYZ()
		obj:SetPos(x, y, z + sz)
		if IsValid(obj.wall_obj) and obj.wall_obj.main_wall == obj then
			obj.wall_obj:SetPos(x, y, z + sz)
		end
	end	
end
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
---
--- Composes the name for a corner plug based on the provided material, crossing type, and variant.
---
--- @param mat string The material of the corner plug.
--- @param crossingType string The crossing type of the corner plug.
--- @param variant string The variant of the corner plug.
--- @return string The composed corner plug name.
---
function ComposeCornerPlugName(mat, crossingType, variant)
	variant = variant or "01"
	local ret = string.format("WallExt_%s_Cap%s_%s", mat, crossingType, variant)
	return ret
end

---
--- Composes the name for a corner beam based on the provided material, interior/exterior type, variant, and optional SVD.
---
--- @param mat string The material of the corner beam.
--- @param interiorExterior string The interior or exterior type of the corner beam.
--- @param variant string The variant of the corner beam.
--- @param svd string (optional) The SVD of the corner beam.
--- @return string The composed corner beam name.
---
function ComposeCornerBeamName(mat, interiorExterior, variant, svd)
	variant = variant or "01"
	interiorExterior = interiorExterior or "Ext"
	local ret = string.format("Wall%s_%s_Corner_%s", interiorExterior, mat, variant)
	return ret
end

DefineClass.RoomCorner = {
	__parents = { "Slab", "CornerAlignedObj", "ComponentExtraTransform", "HideOnFloorChange" },	
	properties = {
		{ id = "ColorModifier", dont_save = true, },
		{ id = "isPlug", editor = "bool", default = false },
	},
	
	room_container_name = "spawned_corners",
}

---
--- Sets a property of the RoomCorner object.
---
--- @param id string The ID of the property to set.
--- @param value any The value to set the property to.
---
function RoomCorner:SetProperty(id, value)
	EditorCallbackObject.SetProperty(self, id, value)
end

---
--- Sets the entity associated with the RoomCorner object.
---
--- @param val Entity The entity to associate with the RoomCorner object.
---
function RoomCorner:Setentity(val)
	if not IsValidEntity(val) then
		--print(self.handle)
		self:ReportMissingSlabEntity(val)
		return
	end
	
	self.entity = val
	self:ChangeEntity(val)
	self:ResetVisibilityFlags()
end

---
--- Gets the attach colors for the RoomCorner object.
---
--- @return boolean, boolean The attach colors for the RoomCorner object.
---
function RoomCorner:GetAttachColors()
	return false, false
end

---
--- Updates the entity associated with the RoomCorner object.
---
--- This function is responsible for determining the appropriate entity to use for the RoomCorner object based on various factors, such as the material, angle, and surrounding walls. It will set the entity property of the RoomCorner object and apply any necessary material properties.
---
--- @param self RoomCorner The RoomCorner object to update.
---
function RoomCorner:UpdateEntity()
	self.bad_entity = nil
	if self.is_destroyed then --TODO: do corner destroyed nbrs matter?
		if self:UpdateDestroyedState() then
			return
		end
	end
	
	local pos = self:GetPos()
	local newEnt = "InvisibleObject"
	local angle = 0
	local dir = self.side
	local room = self.room
	if not room then return end
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	local mat = self.material
	local faceThis
	if mat ~= noneWallMat then
		local amIRoof = not not IsKindOf(self, "RoofCornerWallSlab")-- and "RoofWallSlab" or "WallSlab"
		local alwaysVisibleSlabsPresent = false
		local walls = MapGet(pos, voxelSizeX, "WallSlab", nil, nil, gameFlags, function(o, self, amIRoof, is_permanent)
			if not is_permanent and o:GetGameFlags(gofPermanent) ~= 0 then return end
			if not self:ShouldUpdateEntity(o) then return end
			local clsTest = amIRoof == not not IsKindOf(o, "RoofWallSlab")
			if not clsTest then return end
			--gofshadow should not be considered here, it would cause ent change because of temp invisible things, I can't recall what it fixes either
			local visible = (o:GetEnumFlags(const.efVisible) ~= 0 or IsValid(o.wall_obj))
			if not visible then return end
			
			local x, y, z = o:GetPosXYZ()
			if z ~= pos:z() then return end
			
			alwaysVisibleSlabsPresent = alwaysVisibleSlabsPresent or o.always_visible
			
			return true
		end, self, amIRoof, is_permanent) or empty_table
		
		--filter out walls on the same positions
		if (amIRoof or alwaysVisibleSlabsPresent) and #walls > 1 then
		
			local pos_top = pos:AddZ(voxelSizeZ)
			pos_top = pos_top:SetZ(Min(room and room:GetRoofZAndDir(pos_top) or pos_top:z(), pos_top:z()))

			for i = #walls, 1, -1 do
				local wall_i = walls[i]
				local pos_i = wall_i:GetPos()
				local height_i = wall_i.room and wall_i.room:GetRoofZAndDir(pos_i) or 0
				
				for j = 1, #walls do
					local wall_j = walls[j]
					if wall_j ~= wall_i then
						local pos_j = wall_j:GetPos()
						if pos_i == pos_j then
							if wall_i.room == wall_j.room or wall_i.room ~= room then
								table.remove(walls, i)
							end
							break
						elseif amIRoof and wall_i.room ~= wall_j.room then
							local go = true
							local other_room = wall_i.room ~= room and wall_i.room or wall_j.room
							if other_room ~= room then
								if IsValid(other_room) and (other_room:GetRoofZAndDir(pos_top) or 0) > pos_top:z() then
									go = false --don't drop lower roof slabs if we stick out
								end
							end
							
							if go then
								local height_j = wall_j.room and wall_j.room:GetRoofZAndDir(pos_j) or 0
								if height_i < height_j then
									table.remove(walls, i)
									break
								end
							end
						end
					end
				end
			end
		end

		local ext_material_list = Presets.SlabPreset.SlabMaterials or empty_table
		local int_material_list = Presets.SlabPreset.SlabIndoorMaterials or empty_table
		local esvd = ext_material_list[mat]
		local is_inner_none = room.inner_wall_mat == noneWallMat
		local inner_mat_to_use = not is_inner_none and room.inner_wall_mat or mat
		local isvd = int_material_list[inner_mat_to_use]
		local variantStr = false
		if self.subvariant ~= -1 then
			local digit = self.subvariant
			variantStr = digit < 10 and "0" .. tostring(digit) or tostring(digit)
		end
		
		if #walls > 1 then
			if #walls == 2 then
				local p1 = walls[1]:GetPos() - pos
				local p2 = walls[2]:GetPos() - pos
				if p1:x() ~= p2:x() and p1:y() ~= p2:y() then --else they are on the same plane and corner should be invisible
					local x = p1:x() ~= 0 and p1:x() or p2:x()
					local y = p1:y() ~= 0 and p1:y() or p2:y()
					if x < 0 and y < 0 then
						angle = 0
					elseif x < 0 and y > 0 then
						angle = 270 * 60
					elseif x > 0 and y > 0 then
						angle = 180 * 60
					elseif x > 0 and y < 0 then
						angle = 90 * 60
					end
					local d = slabCornerAngleToDir[angle]
					
					if self.isPlug then
						if self.material == "Concrete" and dir ~= d then
							newEnt = ComposeCornerPlugName(mat, "D")
						end
						if newEnt == "InvisibleObject" or not IsValidEntity(newEnt) then
							newEnt = ComposeCornerPlugName(mat, "L")
						end
					else
						if d ~= dir or 
							walls[1].variant == "IndoorIndoor" or
							walls[2].variant == "IndoorIndoor" then
							--What this does is that ExEx sets will use Ext corners for places where Int corners should be used.
							--This may not be exactly correct, the pedantically correct way would be for ExEx materials to use ExEx corners and have an ExExInt and an ExExExt variants.
							--Leave as is until someone needs it.
							local interior_exterior = not is_inner_none and "Int" or "Ext"
							
							if not variantStr and isvd then
								local subvariants, total = GetMaterialSubvariants(isvd, "corner_subvariants")
								if subvariants and #subvariants > 0 then
									local random = self:GetSeed(total)
									
									newEnt = GetRandomSubvariantEntity(random, subvariants, function(suffix, mat, interior_exterior)
										return ComposeCornerBeamName(mat, interior_exterior, suffix)
									end, inner_mat_to_use, interior_exterior) or ComposeCornerBeamName(inner_mat_to_use, interior_exterior)
								end
							end
							
							if newEnt == "InvisibleObject" then
								newEnt = ComposeCornerBeamName(inner_mat_to_use, interior_exterior, variantStr)
							end
						else
							if not variantStr and esvd then
								local subvariants, total = GetMaterialSubvariants(esvd, "corner_subvariants")
								if subvariants and #subvariants > 0 then
									local random = self:GetSeed(total)
									
									newEnt = GetRandomSubvariantEntity(random, subvariants, function(suffix, mat)
										return ComposeCornerBeamName(mat, "Ext", suffix)
									end, mat) or ComposeCornerBeamName(mat, "Ext")
								end
							end
							
							if newEnt == "InvisibleObject" then
								newEnt = ComposeCornerBeamName(mat, "Ext", variantStr)
							end
						end
					end
				end
			elseif #walls == 3 then
				if self.isPlug then
					newEnt = ComposeCornerPlugName(mat, "T")
					local a1 = walls[1]:GetAngle()
					local a2 = walls[2]:GetAngle()
					local a3 = walls[3]:GetAngle()
					local delim = 180 * 60
					local orthoEl
					
					if a1 % delim == a2 % delim then 
						orthoEl = walls[3]
					elseif a1 % delim == a3 % delim then
						orthoEl = walls[2]
					else
						orthoEl = walls[1]
					end
					
					local toMe = pos - orthoEl:GetPos()
					faceThis = pos + toMe
				end
			elseif #walls == 4 then
				if self.isPlug then
					newEnt = ComposeCornerPlugName(mat, "X")
				end
			end
		end
	end
	
	if not IsValidEntity(newEnt) then
		if self.subvariant == 1 or self.subvariant == -1 then
			--presumably if var 1 is missing nothing can be done
			self:ReportMissingSlabEntity(newEnt)
			newEnt = "InvisibleObject"
		else
			print("Reverting corner [" .. self.handle .. "] subvariant [" .. self.subvariant .. "] because no entity [" .. newEnt .. "] found.")
			self.subvariant = -1
			self:UpdateEntity()
			return
		end
	end
	
	if newEnt ~= self.entity or IsChangingMap() then
		self:Setentity(newEnt)
		self:ApplyMaterialProps()
	end
	
	if faceThis then
		self:Face(faceThis)
	else
		self:SetAngle(angle)
	end
	
	self:SetColorFromRoom()
end

---
--- Sets the color of a RoomCorner object based on the room it is associated with.
---
--- If the RoomCorner object has no associated room, the colors are set to the object's own colors.
--- Otherwise, the colors are set based on whether the RoomCorner is on the outer or inner side of the room.
---
--- @param self RoomCorner The RoomCorner object to set the colors for.
function RoomCorner:SetColorFromRoom()
	local room = self.room
	if not room then return end
	local rm = self:GetColorsRoomMember()
	self:Setcolors(self.colors or room[rm])
end

---
--- Gets the colors room member for a RoomCorner object.
---
--- If the RoomCorner object has no associated room, the colors_room_member field is returned.
--- Otherwise, the "outer_colors" or "inner_colors" field is returned based on the angle of the RoomCorner and whether the room has an inner wall material set.
---
--- @param self RoomCorner The RoomCorner object to get the colors room member for.
--- @return string The colors room member for the RoomCorner object.
function RoomCorner:GetColorsRoomMember()
	local room = self.room
	if not room then 
		return self.colors_room_member
	end
	if slabCornerAngleToDir[self:GetAngle()] == self.side or room.inner_wall_mat == noneWallMat then
		return "outer_colors"
	else
		return "inner_colors"
	end
end
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
g_BoxesToCompute = false
local BoxIntersect = box().Intersect
local irInside = const.irInside
local function DoesBoxEncompassBox(b1, b2)
	return BoxIntersect(b1, b2) == irInside
end

MapGameTimeRepeat("ComputeSlabVisibility", nil, function()
	if not g_BoxesToCompute then
		WaitWakeup()
	end
	ComputeSlabVisibility()
end)
--the order in which MapGameTimeRepeat get registered determines when they'll execute,
--we want DelayedSlabUpdate to be after ComputeSlabVisibility if they are concurent
MapGameTimeRepeat("DelayedSlabUpdate", -1, function(sleep)
	SlabUpdate()
	if first then
		Msg("SlabsDoneLoading")
		first = false
	end
	WaitWakeup()
end)

---
--- Computes the slab visibility for a set of objects.
---
--- @param objs table A table of objects to compute slab visibility for.
---
function ComputeSlabVisibilityOfObjects(objs)
	local bbox = empty_box
	for _, obj in ipairs(objs) do
		bbox = AddRects(bbox, obj:GetObjectBBox())
	end
	ComputeSlabVisibilityInBox(bbox)
end

---
--- Computes the slab visibility for a set of objects within a given bounding box.
---
--- This function is responsible for managing the list of bounding boxes that need to be processed for slab visibility computation.
--- It checks if the given bounding box is already in the list, and if not, adds it to the list and triggers a delayed computation of slab visibility.
---
--- @param box table The bounding box to compute slab visibility for.
---
function ComputeSlabVisibilityInBox(box)
	if not box or box:IsEmpty2D() then
		return
	end
	g_BoxesToCompute = g_BoxesToCompute or {}
	local boxes = g_BoxesToCompute
	for i = 1, #boxes do
		local bi = boxes[i]
		if bi == box then
			--same
			return
		end
		if DoesBoxEncompassBox(bi, box) then
			--fully encompassed
			return
		elseif DoesBoxEncompassBox(box, bi) then
			boxes[i] = box
			return
		end
	end
	--DbgAddBox(box)
	NetUpdateHash("ComputeSlabVisibilityInBox", box)
	table.insert(boxes, box)
	DelayedComputeSlabVisibility()
end

---
--- Wakes up the "ComputeSlabVisibility" periodic repeat thread, triggering a delayed computation of slab visibility.
---
--- This function is responsible for managing the delayed computation of slab visibility. It wakes up the "ComputeSlabVisibility" periodic repeat thread, which will then perform the actual slab visibility computation.
---
--- The delayed computation is necessary to batch multiple slab visibility requests and perform the computation efficiently, rather than computing visibility for each request individually.
---
--- @function DelayedComputeSlabVisibility
--- @return nil
function DelayedComputeSlabVisibility()
	Wakeup(PeriodicRepeatThreads["ComputeSlabVisibility"])
end

local function TestMaterials(myMat, hisMat, reverseNoneForMe, reverseNoneForHim)
	--first ret true -- someone will get suppressed
	--second ret true - otherSlab will get suppressed, false - slab will get suppressed
	if hisMat == noneWallMat then
		return true, reverseNoneForHim and true or false
	elseif myMat == noneWallMat and hisMat ~= noneWallMat then
		return true, not reverseNoneForMe and true or false
	end
	
	return false
end

---
--- Checks if the slab is offset from its voxel position.
---
--- This function returns a boolean indicating whether the slab's position in world space is offset from its corresponding voxel position.
---
--- @return boolean true if the slab is offset from its voxel position, false otherwise
function Slab:IsOffset()
	return false
end

---
--- Checks if the slab is offset from its voxel position.
---
--- This function returns a boolean indicating whether the slab's position in world space is offset from its corresponding voxel position.
---
--- @return boolean true if the slab is offset from its voxel position, false otherwise
function RoofWallSlab:IsOffset()
	local x1, y1, z1 = WallVoxelToWorld(WallWorldToVoxel(self))
	local x2, y2, z2 = self:GetPosXYZ()
	return x1 ~= x2 or y1 ~= y2
end

--  1 if otherSlab should be suppressed
-- -1 if self should be suppressed
--  0 if noone is suppress
---
--- Determines whether the current WallSlab should be suppressed by the given otherSlab, based on various factors such as importance, material, and roof/wall type.
---
--- @param otherSlab WallSlab The other slab to compare against
--- @param material_preset table A table of material presets
--- @return integer 1 if otherSlab should be suppressed, -1 if self should be suppressed, 0 if neither should be suppressed
function WallSlab:ShouldSuppressSlab(otherSlab, material_preset)
	if self:IsSuppressionDisabled(otherSlab) then
		return 0
	end
	
	local importance_test = self:SuppressByImportance(otherSlab)
	if importance_test ~= 0 then
		return importance_test
	end
	
	local amIRoof = IsKindOf(self, "RoofWallSlab")
	local isHeRoof = IsKindOf(otherSlab, "RoofWallSlab")
	if isHeRoof and not amIRoof then
		return 1
	elseif not isHeRoof and amIRoof then
		return -1
	end
	
	local mr = self.room
	local reverseNoneForMe = IsValid(mr) and (amIRoof and mr.none_roof_wall_mat_does_not_affect_nbrs or not amIRoof and mr.none_wall_mat_does_not_affect_nbrs) or false
	local hr = otherSlab.room
	local reverseNoneForHim = IsValid(hr) and (isHeRoof and hr.none_roof_wall_mat_does_not_affect_nbrs or not isHeRoof and hr.none_wall_mat_does_not_affect_nbrs) or false
	local r1, r2 = TestMaterials(self.material, otherSlab.material, reverseNoneForMe, reverseNoneForHim)
	
	if r1 then
		return r2 and 1 or -1
	end
	
	if isHeRoof and amIRoof then
		return 0
	end

	local material_test = self:SuppressByMaterial(otherSlab, material_preset)
	if material_test ~= 0 then
		return material_test
	end
	
	if IsValid(self.room) and IsValid(otherSlab.room) then
		return self.room.handle - otherSlab.room.handle
	end
	if not IsValid(self.room) and IsValid(otherSlab.room) then
		return -1
	end
	if IsValid(self.room) and not IsValid(otherSlab.room) then
		return 1
	end
	
	return self.handle - otherSlab.handle
end

--  1 if otherSlab should be suppressed
-- -1 if self should be suppressed
--  0 if noone is suppress
---
--- Determines whether the current FloorSlab should suppress the given otherSlab.
---
--- @param otherSlab FloorSlab The other slab to compare against.
--- @param material_preset table A table of material presets.
--- @return integer 1 if otherSlab should be suppressed, -1 if self should be suppressed, 0 if neither should be suppressed.
---
function FloorSlab:ShouldSuppressSlab(otherSlab, material_preset)
	if self:IsSuppressionDisabled(otherSlab) then
		return 0
	end
	
	local importance_test = self:SuppressByImportance(otherSlab)
	if importance_test ~= 0 then
		return importance_test
	end
	
	local reverseNoneForMe = IsValid(self.room) and self.room.none_floor_mat_does_not_affect_nbrs or false
	local reverseNoneForHim = IsValid(otherSlab.room) and otherSlab.room.none_floor_mat_does_not_affect_nbrs or false
	local r1, r2 = TestMaterials(self.material, otherSlab.material, reverseNoneForMe, reverseNoneForHim)
	
	if r1 then
		return r2 and 1 or -1
	end
	
	local material_test = self:SuppressByMaterial(otherSlab, material_preset)
	if material_test ~= 0 then
		return material_test
	end

	if IsValid(self.room) and IsValid(otherSlab.room) then
		local amIRoof = self.room:IsRoofOnly()
		local isHeRoof = otherSlab.room:IsRoofOnly()
		if isHeRoof and not amIRoof then
			return 1
		elseif amIRoof and not isHeRoof then
			return -1
		end
		
		return self.room.handle - otherSlab.room.handle
	end
	if not IsValid(self.room) and IsValid(otherSlab.room) then
		return -1
	end
	if IsValid(self.room) and not IsValid(otherSlab.room) then
		return 1
	end
	return self.handle - otherSlab.handle
end

CeilingSlab.ShouldSuppressSlab = FloorSlab.ShouldSuppressSlab

cornerToWallSides = {
	East = { "East", "North" },
	South = { "East", "South" },
	West = { "West", "South" },
	North = { "West", "North" },
}

--  1 if otherSlab should be suppressed
-- -1 if self should be suppressed
--  0 if noone is suppress
--- Determines whether the current slab should suppress the given slab.
---
--- This function checks various conditions to determine whether the current slab should
--- suppress the given slab. The conditions include:
--- - Whether suppression is disabled for either slab
--- - The relative importance of the two slabs
--- - Whether one slab is a roof corner and the other is not
--- - The materials of the two slabs
--- - The rooms the two slabs belong to
---
--- @param otherSlab Slab The other slab to compare against
--- @param material_preset MaterialPreset The material preset to use for comparison
--- @return integer 1 if the other slab should be suppressed, -1 if the current slab should be suppressed, 0 if neither should be suppressed
function RoomCorner:ShouldSuppressSlab(otherSlab, material_preset)
	if self:IsSuppressionDisabled(otherSlab) then
		return 0
	end
	
	local importance_test = self:SuppressByImportance(otherSlab)
	if importance_test ~= 0 then
		return importance_test
	end
	
	local amIRoof = IsKindOf(self, "RoofCornerWallSlab")
	local isHeRoof = IsKindOf(otherSlab, "RoofCornerWallSlab")
	if isHeRoof and not amIRoof then
		return 1
	elseif not isHeRoof and amIRoof then
		return -1
	elseif isHeRoof and amIRoof then
		return 0
	end
	
	local r1, r2 = TestMaterials(self.material, otherSlab.material)
	r2 = not r2 --reverse behavior, none corners should be below other corners
	if r1 then return r2 and 1 or -1 end
	
	local material_test = self:SuppressByMaterial(otherSlab, material_preset)
	if material_test ~= 0 then
		return material_test
	end
	
	if IsValid(self.room) and IsValid(otherSlab.room) then
		--if one of the walls of an adjacent bld is disabled, corners of existing walls have precedence
		local myC, hisC = 0, 0
		local myAdj = cornerToWallSides[self.side]
		local hisAdj = cornerToWallSides[otherSlab.side]
		for i = 1, 2 do
			myC = myC + ((self.room:GetWallMatHelperSide(myAdj[i]) == noneWallMat) and 1 or 0)
			hisC = hisC + ((otherSlab.room:GetWallMatHelperSide(hisAdj[i]) == noneWallMat) and 1 or 0)
		end
		if myC ~= hisC then
			return hisC - myC
		end
		
		return self.room.handle - otherSlab.room.handle
	end
	return self.handle - otherSlab.handle
end

--- @param otherSlab Slab The other slab to compare against
--- @return integer 0 if neither slab should be suppressed
---
--- Determines whether the current slab should be suppressed in relation to the other slab.
--- This implementation always returns 0, indicating that neither slab should be suppressed.
function CSlab:ShouldSuppressSlab(otherSlab)
	return 0
end

--- Determines the suppression strength between the current slab and the provided slab based on their material presets.
---
--- @param slab Slab The slab to compare against
--- @param material_preset table|nil The material preset to use for the current slab, or nil to use the default preset
--- @return integer The suppression strength, where a positive value indicates the current slab should be suppressed, and a negative value indicates the other slab should be suppressed
function CSlab:SuppressByMaterial(slab, material_preset)
	local mp_self = material_preset or self:GetMaterialPreset()
	local mp_slab = slab:GetMaterialPreset()
	return (mp_self and mp_self.strength or 0) - (mp_slab and mp_slab.strength or 0)
end

--- Determines the suppression strength between the current slab and the provided slab based on their class suppression strength.
---
--- @param slab Slab The slab to compare against
--- @return integer The suppression strength, where a positive value indicates the current slab should be suppressed, and a negative value indicates the other slab should be suppressed
function CSlab:SuppressByImportance(slab)
	return self.class_suppression_strenght - slab.class_suppression_strenght
end

--- Determines whether suppression is disabled for the given slab.
---
--- @param slab Slab The slab to check for suppression disabling.
--- @return boolean True if suppression is disabled for the given slab, false otherwise.
function CSlab:IsSuppressionDisabled(slab)
	return self == slab or self.always_visible or slab.always_visible
end

--- Gets the topmost visible wall slab from the given slab.
---
--- @param slab Slab The slab to start searching from.
--- @return Slab|nil The topmost visible wall slab, or nil if none found.
function GetTopmostWallSlab(slab)
	return MapGetFirst(slab, 0, "WallSlab", function(o)
		return o.isVisible
	end)
end

CSlab.visibility_pass = 1
--- Resets the suppressor for the current slab.
---
--- This function is used to clear the suppressor information for the current slab, indicating that it is no longer being suppressed by another slab.
function CSlab:ComputeVisibility(passed)
	self:SetSuppressor(false)
end

--- Computes the visibility of the slab around the object's bounding box.
---
--- This function is used to determine the visibility of the slab within the
--- surrounding area, which is defined by the slab's bounding box. It is
--- typically called as part of the slab's visibility computation process.
---
--- @function CSlab:ComputeVisibilityAround
--- @return nil
function CSlab:ComputeVisibilityAround()
	ComputeSlabVisibilityInBox(self:GetObjectBBox())
end

local function PassSlab(slab, passed)
	--for easier debug, all passing goes trhough here
	passed[slab] = true
end

local topMySide
local topOpSide
function OnMsg.DoneMap()
	topMySide = nil
	topOpSide = nil
end

local function PassWallSlabs(slab, self, passed, mpreset)
	if slab == self then
		return
	end
	if slab:GetAngle() == self:GetAngle() then
		local r = topMySide:ShouldSuppressSlab(slab, mpreset)
		if r > 0 then
			--slab is suppressed
			PassSlab(slab, passed)
			slab:SetSuppressor(topMySide, self)
		elseif r < 0 then
			if topMySide:SetSuppressor(slab, self) then
				topMySide = slab
			end
		end
	else
		local r = topOpSide and topOpSide:ShouldSuppressSlab(slab, mpreset) or 0
		if r > 0 then
			--slab is suppressed
			PassSlab(slab, passed)
			slab:SetSuppressor(topOpSide, self)
		elseif r < 0 then
			if topOpSide:SetSuppressor(slab, self) then
				topOpSide = slab
			end
		end
		topOpSide = topOpSide or slab
	end
end

---
--- Computes the visibility of a wall slab within the game world.
---
--- This function is typically called as part of the slab's visibility computation process.
---
--- @function WallSlab:ComputeVisibility
--- @param passed (table) A table to keep track of slabs that have already been processed.
--- @return nil
---
function WallSlab:ComputeVisibility(passed)
	--walls
	passed = passed or {}
	local mpreset = self:GetMaterialPreset()
	topMySide = self
	topOpSide = false
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	
	MapForEach(self, 0, "WallSlab", nil, nil, gameFlags, PassWallSlabs, self, passed, mpreset)

	local top = topMySide
	local variant = false
	--take inner mats from tops, todo: maybe they should be calculated b4 hand from all slabs in spot?
	local m1 = noneWallMat
	local m2 = noneWallMat
	local c2
	
	--dont do innerinner variants for roof<->notroof combo
	if top and topOpSide then
		local isTopRoof = IsKindOf(top, "RoofWallSlab")
		local isOpTopRoof = IsKindOf(topOpSide, "RoofWallSlab")
		
		if isTopRoof ~= isOpTopRoof then
			if isTopRoof and not isOpTopRoof then
				PassSlab(top, passed)
				if top:SetSuppressor(topOpSide, self) then
					top = topOpSide
					topOpSide = false
				end
			elseif not isTopRoof and isOpTopRoof then
				PassSlab(topOpSide, passed)
				if topOpSide:SetSuppressor(top, self) then
					topOpSide = false
				end
			end
		end
	end
	
	local opSideCompResult
	if topOpSide then
		variant = "IndoorIndoor"
		opSideCompResult = top:ShouldSuppressSlab(topOpSide, mpreset)
		if opSideCompResult > 0 then
			topOpSide:SetSuppressor(top, self)
			m1 = top.room and top.room.inner_wall_mat or top.indoor_material_1 or noneWallMat
			m2 = topOpSide.room and topOpSide.room.inner_wall_mat or topOpSide.indoor_material_1 or noneWallMat
			c2 = topOpSide.room and topOpSide.room.inner_colors
		elseif opSideCompResult < 0 then
			if top:SetSuppressor(topOpSide, self) then
				top = topOpSide
			end
			m1 = top.room and top.room.inner_wall_mat or top.indoor_material_1 or noneWallMat
			m2 = topMySide.room and topMySide.room.inner_wall_mat or topMySide.indoor_material_1 or noneWallMat
			c2 = topMySide.room and topMySide.room.inner_colors
			if top.wall_obj then
				passed[top] = nil --topOpSide is visible, he needs to pass in case his covered up by a slabwallobj
			end
		elseif opSideCompResult == 0 then
			passed[topOpSide] = nil --both are visible, this guy needs to pass to fix up his variant
			m1 = top.room and top.room.inner_wall_mat or top.indoor_material_1 or noneWallMat --stacked roof walls, ignore his mat, use ours though.
		end
		
		if m2 == noneWallMat and m1 == noneWallMat then
			variant = "Outdoor"
		elseif m2 == noneWallMat then
			variant = "OutdoorIndoor"
		elseif m1 == noneWallMat then
			--this will hide opposing inner mat
			variant = "Outdoor"
		end
	else
		local indoorMat = top.room and top.room.inner_wall_mat or top.indoor_material_1
		if indoorMat == noneWallMat then
			variant = "Outdoor"
		else
			variant = "OutdoorIndoor"
			m1 = indoorMat
		end
	end
	
	if top.material == noneWallMat and not top.always_visible then
		top:SetSuppressor(self)
	else
		if top.exterior_attach_colors == c2 then
			--save fixup, TODO: remove
			top:Setexterior_attach_colors(false)
		end
		
		if top:ShouldUpdateEntity(self)
			and (top.variant ~= variant or top.indoor_material_2 ~= m2 or top.exterior_attach_colors_from_nbr ~= c2) then
			
			local newVar = variant
			if not IsValid(top.room) then
				--slabs placed by hand have their variant preserved, unless forced
				newVar = top.variant
				m2 = top.indoor_material_2
			end
			if top.forceVariant ~= "" then
				newVar = top.forceVariant
			end
			
			local defaults = getmetatable(top)
			top.variant = newVar ~= defaults.variant and newVar or nil
			top.indoor_material_2 = m2 ~= defaults.indoor_material_2 and m2 or nil
			top:Setexterior_attach_colors_from_nbr(c2)
			top:UpdateEntity()
			top:UpdateVariantEntities()
		end
		 
		top:SetSuppressor(false, self)
	end
	
	--supress roof walls if they are in the box of above rooms (2D box)
	if top.room and not top.room:IsRoofOnly() and IsKindOf(top, "RoofWallSlab") then
		local pos = top:GetPos()
		local adjacent_rooms = top.room.adjacent_rooms or empty_table
		for _, adj_room in ipairs(adjacent_rooms) do
			local data = adjacent_rooms[adj_room]
			if not adj_room.being_placed and 
				not adj_room:IsRoofOnly() and adj_room.box ~= data[1] then --ignore rooms inside our room
				
				local adj_box = adj_room.box:grow(1, 1, 0)
				local in_box_3d = pos:InBox(adj_box)
				
				if not in_box_3d and top.room.floor < adj_room.floor then
					local rb = adj_room.roof_box
					if rb then
						rb = rb:grow(1, 1, 0)
						in_box_3d = pos:InBox(rb)
						--[[
						--restore if needed
						if in_box_3d then
							--this part shows offset pieces that are partially in the roof box of a lower room
							local b = top:GetObjectBBox()
							local ib = IntersectRects(b, rb)
							if ib:sizex() ~= b:sizex() and ib:sizey() ~= b:sizey() then
								in_box_3d = false --at least one side should be fully in, else we are partially affected and will leave a whole
							end
						end
						]]
					end
				end
				
				if in_box_3d then
					top:SetSuppressor(self)
					if topOpSide and opSideCompResult == 0 then --topOpSide is still visible
						topOpSide:SetSuppressor(self)
					end
					break
				end
			end
		end
	end
	
	topMySide = nil
	topOpSide = nil
end

local floor_top
function OnMsg.DoneMap()
	floor_top = nil
end

local function FloorPassFloorAndCeilingSlabs(slab, self, passed, mpreset)
	if slab == self then
		return
	end
	local comp = floor_top:ShouldSuppressSlab(slab, mpreset)
	if comp == 0 then
		return
	end
	PassSlab(slab, passed)
	if comp > 0 then
		slab:SetSuppressor(floor_top, self)
	else
		if floor_top:SetSuppressor(slab, self) then
			floor_top = slab
		end
	end
end

local function FloorPassRoofPlaneAndEdgeSlabs(slab, floor_top, topZ, passed, self)
	local dz = topZ - select(3, slab:GetPosXYZ())
	if 0 < dz and dz <= voxelSizeZ then
		PassSlab(slab, passed)
		slab:SetSuppressor(floor_top, self)
	end
end

---
--- Computes the visibility of a `FloorSlab` object.
---
--- This function is responsible for determining which slabs should be visible or suppressed based on the current `FloorSlab` object. It uses the `MapForEach` function to iterate over nearby slabs and apply visibility rules.
---
--- The function first sets the `floor_top` variable to the current `FloorSlab` object. It then checks the material preset and game flags of the `FloorSlab` object to determine how to handle the visibility of other slabs.
---
--- If the material of the `FloorSlab` object is `noneWallMat`, it sets the `FloorSlab` object as the suppressor for itself. Otherwise, it clears the suppressor and then uses `MapForEach` to iterate over nearby roof plane and edge slabs, passing them to the `FloorPassRoofPlaneAndEdgeSlabs` function to determine their visibility.
---
--- Finally, the function sets the `floor_top` variable to `nil`.
---
--- @param passed table A table of previously passed slabs.
function FloorSlab:ComputeVisibility(passed)
	passed = passed or {}
	floor_top = self
	local mpreset = self:GetMaterialPreset()
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	
	MapForEach(self, 0, "FloorSlab", "CeilingSlab", nil, nil, gameFlags, 
		FloorPassFloorAndCeilingSlabs, self, passed, mpreset)
	
	if floor_top.material == noneWallMat then
		floor_top:SetSuppressor(floor_top, self)
	else
		floor_top:SetSuppressor(false, self)
		
		--hide roofs 1 vox below 155029
		MapForEach(floor_top, halfVoxelSizeX, "RoofPlaneSlab", "RoofEdgeSlab", nil, nil, gameFlags, 
			FloorPassRoofPlaneAndEdgeSlabs, floor_top, select(3, floor_top:GetPosXYZ()), passed, self)
	end
	
	floor_top = nil
end

CeilingSlab.ComputeVisibility = FloorSlab.ComputeVisibility

function SlabWallObject:ComputeVisibility(passed)
	self:UpdateAffectedWalls()
end

local roof_suppressed
function OnMsg.DoneMap()
	roof_suppressed = nil
end

local function RoofPassRoofEdgeAndCornerSlabs(slab, self, passed, z)
	if slab == self or slab.room == self.room
	or (slab:GetAngle() == self:GetAngle() and slab:GetMirrored() == self:GetMirrored())
	or self:IsSuppressionDisabled(slab)
	then
		return
	end
	local _, _, slab_z = slab:GetPosXYZ()
	if z < slab_z then
		roof_suppressed = true
		return 
	end
	PassSlab(slab, passed)
	if slab:SetSuppressor(self) and z == slab_z then
		roof_suppressed = true
	end
end

---
--- Computes the visibility of a RoofSlab object.
---
--- This function is responsible for determining whether a RoofSlab object should be suppressed or not based on its position relative to other rooms and roof slabs.
---
--- @param passed table A table of previously processed slabs.
---
function RoofSlab:ComputeVisibility(passed)
	passed = passed or {}
	roof_suppressed = nil
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	
	if self.room and not self.room:IsRoofOnly() then
		--determine a list of rooms, inside whose volumes our self lies
		local passed = {}
		local function CheckSuppressed(adj_room, pos, adjacent_rooms, slab_room, passed)
			local data = adjacent_rooms[adj_room]
			if not passed[adj_room] then
				passed[adj_room] = true
				--ignore rooms inside our room
				if slab_room ~= adj_room and
					not adj_room:IsRoofOnly() and
					not adj_room.being_placed and
					(not data or adj_room.box ~= data[1])
				then
					local adj_box = adj_room.box:grow(1,1,1)
					local in_box = pos:InBox(adj_box)
					
					if not in_box and (slab_room.floor or 0) < (adj_room.floor or 0) then
						local rb = adj_room.roof_box
						if rb then
							rb = rb:grow(1, 1, 0)
							in_box = pos:InBox(rb)
						end
					end
					
					if in_box then
						roof_suppressed = true
						return "break"
					end
				end
			end
		end
		
		local pos = self:GetPos()
		local adjacent_rooms = self.room.adjacent_rooms or empty_table
		local sbox = self:GetObjectBBox() 
		EnumVolumes(sbox:grow(1, 1, 1), CheckSuppressed, pos, adjacent_rooms, self.room, passed) --this catches some rooms that are not considered adjacent (roof adjacency)
		if not roof_suppressed then
			--this catches other rooms the previous enum doesn't, normal adjacency
			for _, adj_room in ipairs(adjacent_rooms) do
				if CheckSuppressed(adj_room, pos, adjacent_rooms, self.room, passed) == "break" then
					break
				end
			end
		end
	end
	
	--idk, but this seems to be the best looking option atm, of course that could change
	if not roof_suppressed and const.SuppressMultipleRoofEdges and IsKindOfClasses(self, "RoofEdgeSlab", "RoofCorner") then
		--if more than one in one pos, suppress all
		local x, y, z = self:GetPosXYZ()
		MapForEach(x, y, guic, "RoofEdgeSlab", "RoofCorner", nil, nil, gameFlags, 
			RoofPassRoofEdgeAndCornerSlabs, self, passed, z)
	end

	if roof_suppressed then
		self:SetSuppressor(self)
	else
		self:SetSuppressor(false)
	end
	roof_suppressed = nil
end

local dev = Platform.developer
RoomCorner.visibility_pass = 2
---
--- Computes the visibility of a `RoomCorner` slab.
---
--- This function is responsible for determining if a `RoomCorner` slab should be suppressed or not based on its position relative to other `RoomCorner` slabs in the same z-level.
---
--- @param passed table A table of slabs that have already been processed.
---
function RoomCorner:ComputeVisibility(passed)
	local _, _, z = self:GetPosXYZ()
	local topSlab = self
	local mpreset = self:GetMaterialPreset()
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	
	MapForEach(self, halfVoxelSizeX, "RoomCorner", nil, nil, gameFlags, function(slab, self, z, mpreset)
		if slab == self then
			return
		end
		local _, _, z1 = slab:GetPosXYZ()
		if z1 ~= z or self.isPlug ~= slab.isPlug then
			return --plugs suppress plugs only, corners suppress corners only
		end
		if slab:ShouldUpdateEntity(self) then
			slab:UpdateEntity() --update all entities all the time, otherwise we get map save diffs when they get updated on load map
		end
		local comp = topSlab:ShouldSuppressSlab(slab, mpreset)
		if comp > 0 then
			slab:SetSuppressor(topSlab, self)
		elseif comp < 0 then
			if topSlab:SetSuppressor(slab, self) then
				topSlab = slab
			end
		end
	end, self, z, mpreset)
	
	if topSlab:ShouldUpdateEntity(self) then
		topSlab:UpdateEntity()
	end
	
	if topSlab.entity ~= "InvisibleObject" and IsValidEntity(topSlab.entity) or 
		dev and topSlab.entity == "InvisibleObject" and topSlab.is_destroyed then --so they can be seen and repaired by nbrs
		topSlab:SetSuppressor(false, self)
	else
		topSlab:SetSuppressor(topSlab, self)
	end
end

StairSlab.visibility_pass = 3
---
--- Computes the visibility of a `StairSlab` slab.
---
--- This function is responsible for determining if a `StairSlab` slab should be suppressed or not based on its position relative to other `FloorSlab` slabs in the same z-level.
---
--- @param passed table A table of slabs that have already been processed.
---
function StairSlab:ComputeVisibility(passed)
	if self:GetEnumFlags(const.efVisible) == 0 then
		return
	end
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	local x, y, z = self:GetPosXYZ()
	if z then
		local max = self.hide_floor_slabs_above_in_range
		for i = 1, max do
			z = z + voxelSizeZ
			MapForEach(x, y, z, 0, "FloorSlab", nil, nil, gameFlags, function(slab, self)
				slab:SetSuppressor(self)
			end, self)
		end
	else
		print(string.format("Stairs with handle[%d] have an invalid Z!", stairs_slab.handle))
	end
end

local function _ComputeSlabVisibility(boxes)
	local passed = {}
	local max_pass = 1
	local passes
	for i = 1, #boxes do
		local _box = boxes[i]:grow(1, 1, 1) -- include the wall elements
		--query optimizes some children away, so they are added explicitly
		MapForEach(_box, "CSlab", function(slab)
			if passed[slab] then
				return
			end
			local pass = slab.visibility_pass
			if pass == 1 then
				PassSlab(slab, passed)
				slab:ComputeVisibility(passed)
			else
				max_pass = Max(max_pass, pass)
				passes = passes or {}
				passes[pass] = table.create_add(passes[pass], slab)
			end
		end)
	end
	
	for i=2,max_pass do
		for _, slab in ipairs(passes[i] or empty_table) do
			if not passed[slab] then
				PassSlab(slab, passed)
				slab:ComputeVisibility(passed)
			end
		end
	end
end

---
--- Computes the visibility of all slabs in the specified boxes.
---
--- This function is responsible for determining which slabs are visible and which are not, based on the provided boxes.
--- It does this by iterating through the slabs in the boxes, computing their visibility, and marking them as passed or not passed.
---
--- @param boxes table A table of boxes to compute the visibility for.
---
function ComputeSlabVisibility()
	local boxes = g_BoxesToCompute
	g_BoxesToCompute = false
	if not boxes then return end --nothing to compute
	
	SuspendPassEdits("ComputeSlabVisibility")
	
	procall(_ComputeSlabVisibility, boxes)
	
	ResumePassEdits("ComputeSlabVisibility")
	Msg("SlabVisibilityComputeDone")
end

---
--- Deletes all RoomCorner objects that are not associated with a room.
---
--- This function iterates through all RoomCorner objects in the map and deletes any that do not have a valid room associated with them. This can happen if a room is deleted but its associated RoomCorner objects are not properly cleaned up.
---
--- @function DeleteOrphanCorners
--- @return nil
function DeleteOrphanCorners()
	MapForEach("map", "RoomCorner", nil, nil, gofPermanent, function(o)
		if not o.room then
			DoneObject(o)
		end
	end)
end

---
--- Deletes all WallSlab objects that are not associated with a room.
---
--- This function iterates through all WallSlab objects in the map and deletes any that do not have a valid room associated with them. This can happen if a room is deleted but its associated WallSlab objects are not properly cleaned up.
---
--- @function DeleteOrphanWalls
--- @return nil
function DeleteOrphanWalls()
	local c = 0
	MapForEach("map", "WallSlab", nil, nil, gofPermanent, function(o)
		if not o.room then
			DoneObject(o)
			c = c + 1
		end
	end)
	print("deleted: ", c)
end

---
--- Restores the selected slabs and floor walls after they have been recreated.
---
--- This function is called after the `RecreateSelectedSlabFloorWall()` function has completed. It iterates through a table of saved object information and restores the selection by finding the corresponding objects in the map and adding them to the editor's selection.
---
--- @param t table A table of tables, where each inner table contains the class, position, and room of a previously selected object.
--- @return nil
function RecreateSelectedSlabFloorWall_RestoreSel(t)
	editor.ClearSel()
	for i = 1, #t do
		local entry = t[i]
		local o = MapGet(entry[2], 0, entry[1], nil, nil, gofPermanent, function(o, room)
			return o.room == room
		end, entry[3])
		
		if o then
			editor.AddToSel(o)
		end
	end
end

---
--- Recreates the selected slab and floor wall objects after they have been deleted.
---
--- This function is called after the selected slab and floor wall objects have been deleted, typically as part of a larger operation. It iterates through the previously selected objects, recreates them in their original positions and rooms, and restores the editor's selection to include the newly recreated objects.
---
--- @return nil
function RecreateSelectedSlabFloorWall()
	local ol = editor.GetSel()
	local restoreSel = {}
	local walls = {}
	local floors = {}
	for i = 1, #ol do
		local o = ol[i]
		local room = o.room
		if IsValid(room) then
			if IsKindOf(o, "WallSlab") then
				table.insert(restoreSel, {o.class, o:GetPos(), room})
				table.insert_unique(walls, room)
			elseif IsKindOf(o, "FloorSlab") then
				table.insert(restoreSel, {o.class, o:GetPos(), room})
				table.insert_unique(floors, room)
			end
		end
	end
	
	for i = 1, #walls do
		walls[i]:RecreateWalls()
	end
	
	for i = 1, #floors do
		floors[i]:RecreateFloor()
	end
	
	if #restoreSel > 0 then
		DelayedCall(0, RecreateSelectedSlabFloorWall_RestoreSel, restoreSel)
	end
end

local defaultColorMod = RGBA(100, 100, 100, 255)
function Slab:ApplyColorModFromSource(source)
	local cm = source:GetColorModifier()
	if cm ~= defaultColorMod then
		self:SetColorModifier(cm)
	end
end
---
--- Clones the editor properties of a Slab object from a source object.
---
--- This function is called when a Slab object is cloned in the editor. It copies various properties from the source object to the new object, such as colors, color modifiers, and subvariant.
---
--- @param source Slab The source object to clone properties from.
--- @return nil
function Slab:EditorCallbackClone(source)
	self.room = false
	self.subvariant = source.subvariant
	self:Setcolors(source.colors)
	self:Setinterior_attach_colors(source.interior_attach_colors)
	self:Setexterior_attach_colors(source.exterior_attach_colors)
	self:Setexterior_attach_colors_from_nbr(source.exterior_attach_colors_from_nbr)
	self:ApplyColorModFromSource(source)
end

---
--- Clones the editor properties of a WallSlab object from a source object.
---
--- This function is called when a WallSlab object is cloned in the editor. It copies various properties from the source object to the new object, such as colors, color modifiers, and subvariant.
---
--- @param source Slab The source object to clone properties from.
--- @return nil
function WallSlab:EditorCallbackClone(source)
	Slab.EditorCallbackClone(self, source)
	--TODO: rem this once colors auto copy
	self:Setcolors(source.colors or source.room and source.room.outer_colors)
	self:Setinterior_attach_colors(source.interior_attach_colors or source.room and source.room.inner_colors)
	self:ApplyColorModFromSource(source)
end

---
--- Clones the editor properties of a FloorSlab object from a source object.
---
--- This function is called when a FloorSlab object is cloned in the editor. It copies various properties from the source object to the new object, such as colors and color modifiers.
---
--- @param source Slab The source object to clone properties from.
--- @return nil
function FloorSlab:EditorCallbackClone(source)
	Slab.EditorCallbackClone(self, source)
	self:Setcolors(source.colors or source.room and source.room.floor_colors)
	self:ApplyColorModFromSource(source)
end

---
--- Clones the editor properties of a SlabWallObject from a source object.
---
--- This function is called when a SlabWallObject is cloned in the editor. It copies various properties from the source object to the new object, such as the owned_slabs, room, subvariant, and colorization.
---
--- @param source SlabWallObject The source object to clone properties from.
--- @return nil
function SlabWallObject:EditorCallbackClone(source)
	if self.owned_slabs == source.owned_slabs then
		--props copy will sometimes provoke the creation of new slabs and sometimes it wont..
		self.owned_slabs = false
	end
	self.room = false
	self.subvariant = source.subvariant
	--aparently windows n doors use the default colorization
	self:SetColorization(source)
end

---
--- Clones the editor properties of a RoofSlab object from a source object.
---
--- This function is called when a RoofSlab object is cloned in the editor. It copies various properties from the source object to the new object, such as colors, color modifiers, and skew.
---
--- @param source Slab The source object to clone properties from.
--- @return nil
function RoofSlab:EditorCallbackClone(source)
	Slab.EditorCallbackClone(self, source)
	self:Setcolors(source.colors or source.room and source.room.roof_colors)
	self:ApplyColorModFromSource(source)
	local x, y = source:GetSkew()
	self:SetSkew(x, y)
end

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	if obj.class == "ColorizationPropSet" then
		-- escalate OnEditorSetProperty for the colorization nested object properties to the parent Room/Slab
		local ged = GedConnections[ged_id]
		local parents = ged:GatherAffectedGameObjects(obj)
		for _, parent in ipairs(parents) do
			if parent:IsKindOfClasses("Room", "Slab") then
				local prop_id = ""
				for _, value in ipairs(parent:GetProperties()) do
					if parent:GetProperty(value.id) == obj then
						prop_id = value.id
						break
					end
				end
				
				if IsKindOf(parent, "Slab") then
					ged:NotifyEditorSetProperty(parent, prop_id, obj)
					parent:SetProperty(prop_id, obj)
				elseif IsKindOf(parent, "Room") then
					parent:OnEditorSetProperty(prop_id, old_value, ged)
				end
			end
		end
	end
end

local similarSlabPropsToMatch = {
	"entity_base_name",
	"material",
	"variant",
	"indoor_material_1",
	"indoor_material_2",
}

---
--- Selects all Slab objects on the map that have similar properties to the selected Slab object.
---
--- This function is used in the editor to select all Slab objects that have the same values for certain properties as the currently selected Slab object. The properties that are checked for similarity are defined in the `similarSlabPropsToMatch` table.
---
--- @param matchSubvariant boolean If true, the function will only select Slab objects that have the same entity as the selected Slab object.
--- @return nil
function EditorSelectSimilarSlabs(matchSubvariant)
	local sel = editor.GetSel()
	local o = #(sel or "") > 0 and sel[1]
	if not o then
		print("No obj selected.")
		return
	end
	if not IsKindOf(o, "Slab") then
		print("Obj not a Slab.")
		return
	end
	
	local newSel = {o}
	MapForEach("map", "Slab", function(s, o, newSel, similarSlabPropsToMatch)
		if o ~= s then
			local similar = true
			for i = 1, #similarSlabPropsToMatch do
				local p = similarSlabPropsToMatch[i]
				if s[p] ~= o[p] then
					similar = false
					break
				end
			end
			if similar then
				if not matchSubvariant or s:GetEntity() == o:GetEntity() then
					table.insert(newSel, s)
				end
			end
		end
	end, o, newSel, similarSlabPropsToMatch)
	
	editor.ClearSel()
	editor.AddToSel(newSel)
end

---
--- Restores the default value of the `forceInvulnerableBecauseOfGameRules` property for all Slab objects on the map.
---
--- For Slab objects that are not part of a room, the `forceInvulnerableBecauseOfGameRules` property is set to the default value defined in the class definition.
---
--- For FloorSlab objects that are on the first floor, the `forceInvulnerableBecauseOfGameRules` property is set to `true`.
---
--- For all other Slab objects, the `forceInvulnerableBecauseOfGameRules` property is set to `false`.
---
function DbgRestoreDefaultsFor_forceInvulnerableBecauseOfGameRules()
	MapForEach("map", "Slab", function(o)
		if not o.room then
			--cls default
			o.forceInvulnerableBecauseOfGameRules = g_Classes[o.class].forceInvulnerableBecauseOfGameRules
		else
			
			if IsKindOf(o, "FloorSlab") and o.floor == 1 then
				o.forceInvulnerableBecauseOfGameRules = true
			else
				--vulnerable
				o.forceInvulnerableBecauseOfGameRules = false
			end
		end
	end)	
end

slab_missing_entity_white_list = {
}

---
--- Reports a missing slab entity.
---
--- If the missing entity is not in the `slab_missing_entity_white_list`, a warning message is printed with the slab handle, class, material, variant, and map name.
--- The `bad_entity` flag is set to `true` for the slab.
---
--- @param ent string|nil The missing entity name, or `nil` if unknown.
--- @param self CSlab The slab instance.
---
function CSlab:ReportMissingSlabEntity(ent)
	if not slab_missing_entity_white_list[ent] then
		print(string.format("[WARNING] Missing slab entity %s, reporting slab handle [%d], class [%s], material [%s], variant [%s], map [%s]", (ent or tostring(ent)), self.handle, self.class, self.material, self.variant, GetMapName()))
		slab_missing_entity_white_list[ent] = true
	end
	self.bad_entity = true
end

---
--- Returns a list of all Slab objects on the map that have the `bad_entity` flag set to `true`.
---
--- The `bad_entity` flag is set when a Slab object is missing a required entity. This function can be used to identify and handle these problematic Slab objects.
---
--- @return table A table containing all Slab objects on the map with the `bad_entity` flag set to `true`.
---
function GetBadEntitySlabsOnMap()
	return MapGet("map", "Slab", function(o) return o.bad_entity end)
end

---
--- Checks if a Slab object is passable.
---
--- A Slab object is considered passable if its skew is zero (i.e., it is not skewed) and its spot position snaps to a voxel.
---
--- @param o CSlab The Slab object to check.
--- @return boolean True if the Slab object is passable, false otherwise.
---
function IsSlabPassable(o)
	if o:GetSkewX() == 0 and o:GetSkewY() == 0 then
		local sp = o:GetSpotPos(o:GetSpotBeginIndex("Slab"))
		if SnapToVoxel(sp) == sp then
			return true
		end
	end
	return false
end

---
--- Validates the state of all Slab objects on the map.
---
--- This function checks the visibility and destroyed state of Slab objects, and performs the following actions:
--- - Kills invisible Slab objects that are not part of a room
--- - Resets the destroyed state of invisible Slab objects that are destroyed or have destroyed neighbors
--- - Fixes the destroyed neighbor data for Slab objects that are not invisible
--- - Ensures the lockpick state is set correctly for Lockpickable Slab objects
---
--- This function is called when the map is validated, such as when the game is running in the editor.
---
--- @return nil
---
function ValidateSlabs()
	local slabs = MapGet("map", "Slab", nil, nil, const.gofPermanent)

	local killedSlabs = 0
	local resetDestroyed = 0
	local passedNbrs = {}
	local slabsWithDestroyedNbrs = {}
	for _, slab in ipairs(slabs) do
		local e = slab:GetEntity()
		local isInvisibleObj = (e == "InvisibleObject") --these slabs suppress themselves, so isVisible is not a guarantee that its suppressed by another
		local isInvisible = not slab.isVisible and not isInvisibleObj or slab.material == noneWallMat
		if isInvisible and not slab.room then
			--invisible manually placed slab - kill it
			DoneObject(slab)
			killedSlabs = killedSlabs + 1
		elseif isInvisible and (slab.is_destroyed or slab.destroyed_neighbours ~= 0) then
			slab:ResetDestroyedState()
			resetDestroyed = resetDestroyed + 1
		end
		
		if not isInvisible then
			--fix neighbour data
			if slab.is_destroyed then
				local function proc(nbr, i)
					passedNbrs[nbr] = true
					local f = GetNeigbhourSideFlagTowardMe(1 << (i - 1), nbr, slab)
					if (nbr.destroyed_neighbours & f) == 0 then
						nbr.destroyed_neighbours = nbr.destroyed_neighbours | f
					end
				end
				local nbrs = {slab:GetNeighbours()}
				nbrs[1], nbrs[2], nbrs[3], nbrs[4] = nbrs[3], nbrs[4], nbrs[1], nbrs[2] --so masks fit, l,r,t,b -> t,b,l,r
				for i = 1, 4 do
					local nbrs2 = nbrs[i]
					if IsValid(nbrs2) then
						proc(nbrs2, i)
					else
						for j, nbr in ipairs(nbrs2) do
							proc(nbr, i)
						end
					end
				end
			elseif slab.destroyed_neighbours ~= 0 then
				slabsWithDestroyedNbrs[slab] = true
			end
		end
		
		if IsKindOf(slab, "Lockpickable") then
			--save fixup
			if slab:IsBlockedDueToRoom() and slab.lockpickState ~= "blocked" then
				slab:SetlockpickState("blocked")
			end
		end
	end
	
	for slab, _ in pairs(slabsWithDestroyedNbrs) do
		if not passedNbrs[slab] then
			for i = 0, 3 do
				local dn = slab.destroyed_neighbours
				local f = 1 << i
				if (dn & f) ~= 0 then
					local nbr = slab:GetNeighbour(f)
					if nbr and not nbr.is_destroyed then
						slab.destroyed_neighbours = slab.destroyed_neighbours & ~f
					end
				end
			end
		end
	end
	
	if killedSlabs > 0 then
		print("Killed invisible roomless slabs ", killedSlabs)
	end
	if resetDestroyed > 0 then
		print("Repaired invisible destroyed slabs ", resetDestroyed)
	end
	
	EnumVolumes(function(v)
		if v.ceiling_mat ~= noneWallMat and not v.build_ceiling then
			v.ceiling_mat = nil --the set material is irrelevant since there is no ceiling, revert to default
		end
	end)
end

function OnMsg.ValidateMap()
	if IsEditorActive() and not mapdata.IsRandomMap and mapdata.GameLogic then
		ValidateSlabs()
	end
end

---
--- Utility function to test and visualize invulnerable slabs on the current map.
---
--- @param lst table|nil A list of slabs to test, or nil to get all visible RoomCorner objects with the `forceInvulnerableBecauseOfGameRules` flag set.
---
function testInvulnerableSlabs(lst)
	lst = lst or MapGet("map", "RoomCorner", const.efVisible, function(o) return o.forceInvulnerableBecauseOfGameRules end)
	DbgClear()
	local c = 0
	for i = 1, #(lst or "") do 
		DbgAddVector(lst[i]) 
		c = c + 1
	end
	print(c, #(lst or ""))
end

------------------------------------
--maps are broken again, map fixing stuff
------------------------------------
local invulnerableMaterials = {
	["Concrete"] = true
}

---
--- Fixes the invulnerability state of all owned slabs on the current map.
--- This function iterates through all volumes on the map and sets the `invulnerable` and `forceInvulnerableBecauseOfGameRules` flags on each slab based on certain conditions:
--- - If the slab is on the outside border of a volume, it is set to be invulnerable.
--- - If the slab is a `FloorSlab` and on the first floor of a volume, it is set to be invulnerable.
--- - If the slab is a `WallSlab` and its material is in the `invulnerableMaterials` table, it is set to be invulnerable.
--- - Otherwise, the slab is set to be vulnerable.
---
function FixInvulnerabilityStateOfOwnedSlabsOnMap()
	local function makeInvul(o, val)
		o.invulnerable = val
		o.forceInvulnerableBecauseOfGameRules = val
	end
	EnumVolumes(function(r)
		local invul = r.outside_border
		local firstFloor = not r:IsRoofOnly() and r.floor == 1
		r:ForEachSpawnedObj(function(o, invul)
			if firstFloor and IsKindOf(o, "FloorSlab") or invul or invulnerableMaterials[o.material] and IsKindOf(o, "WallSlab") then
				makeInvul(o, true)
			else
				makeInvul(o, false)
			end
		end, invul)
	end)
end

--deleting slabs from editor deletes invisible slabs underneath
if Platform.developer then
	function DeleteSelectedSlabsWithoutPropagation()
		for _, obj in ipairs(editor.GetSel() or empty_table) do 
			rawset(obj, "dont_propagate_deletion", true)
		end
		editor.DelSelWithUndoRedo()
	end
end