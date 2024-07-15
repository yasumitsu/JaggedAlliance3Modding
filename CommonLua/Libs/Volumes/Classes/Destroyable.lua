ShouldShowAssociateLightsShortcut = empty_func
local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
local noneWallMat = const.SlabNoMaterial

if FirstLoad then
	DestroyedSlabsThisTick = {}
	RepairedSlabsThisTick = {}
	DestroyedCOThisTick = {}
	DestroyedObjectsThisTick = {}
end

SlabNeighbourMask = {
	Top = 1,
	Bottom = 1 << 1,
	Left = 1 << 2,
	Right = 1 << 3,
	
	AllDestroyed = 1 | (1 << 1) | (1 << 2) | (1 << 3),
}

local function IsStructuralRow(r)
	--return (r - 2 * (r/5)) % 3 == 0
	return false
end

maskToOppositeMask = {
	[SlabNeighbourMask.Left] = SlabNeighbourMask.Right,
	[SlabNeighbourMask.Right] = SlabNeighbourMask.Left,
	[SlabNeighbourMask.Top] = SlabNeighbourMask.Bottom,
	[SlabNeighbourMask.Bottom] = SlabNeighbourMask.Top,
}

local invertDiagEntMask = {
	[SlabNeighbourMask.Right | SlabNeighbourMask.Top] = SlabNeighbourMask.Left | SlabNeighbourMask.Bottom,
	[SlabNeighbourMask.Left | SlabNeighbourMask.Top] = SlabNeighbourMask.Right | SlabNeighbourMask.Bottom,
	[SlabNeighbourMask.Right | SlabNeighbourMask.Bottom] = SlabNeighbourMask.Left | SlabNeighbourMask.Top,
	[SlabNeighbourMask.Left | SlabNeighbourMask.Bottom] = SlabNeighbourMask.Right | SlabNeighbourMask.Top,
}

local maskToCharWall = {
	[SlabNeighbourMask.Left] = "R", --with mirror
	[SlabNeighbourMask.Right] = "R",
	[SlabNeighbourMask.Top] = "T",
	[SlabNeighbourMask.Bottom] = "B",
	[SlabNeighbourMask.Right | SlabNeighbourMask.Top] = "RT",
	[SlabNeighbourMask.Left | SlabNeighbourMask.Top] = "RT", --mirror
	[SlabNeighbourMask.Right | SlabNeighbourMask.Bottom] = "RB",
	[SlabNeighbourMask.Left | SlabNeighbourMask.Bottom] = "RB", --mirror
}

local maskToCharFloor = {
	[SlabNeighbourMask.Left] = "R", --with mirror
	[SlabNeighbourMask.Right] = "R",
	[SlabNeighbourMask.Top] = "B", --mirror
	[SlabNeighbourMask.Bottom] = "B",
}

maskToString = {
	[SlabNeighbourMask.Left] = "Left",
	[SlabNeighbourMask.Right] = "Right",
	[SlabNeighbourMask.Top] = "Top",
	[SlabNeighbourMask.Bottom] = "Bottom",
}

local function manageAttachsAttaches(self, a, sc, suffix, variant, index, m1, m2)
	variant = variant or self.variant
	if variant == "IndoorIndoor" then
		local atts = a:GetAttaches() or empty_table
		local a1 = atts[1] or PlaceObject("Object")
		local a2 = atts[2] or PlaceObject("Object")
		if self:GetGameFlags(const.gofPermanent) ~= 0 then
			a1:SetGameFlags(const.gofPermanent)
			a2:SetGameFlags(const.gofPermanent)
		end
		
		m2 = m2 or self.indoor_material_1
		m1 = m1 or self.indoor_material_2
		
		local e1 = self:ComposeBrokenDecInteriorAttachName(sc, suffix, m1, index)
		local e2 = self:ComposeBrokenDecInteriorAttachName(sc, suffix, m2, (index or 0) + 2659)
		
		if not IsValidEntity(e1) then
			self:ReportMissingBrokenDecInteriorAttach(e1)
		else
			a1:ChangeEntity(e1)
		end
		
		if not IsValidEntity(e2) then
			self:ReportMissingBrokenDecInteriorAttach(e2)
		else
			a2:ChangeEntity(e2)
		end
		
		a:Attach(a1)
		a1:SetAttachAngle(0)
		a1:SetMirrored(false)
		a:Attach(a2)
		a2:SetAttachAngle(180*60)
		a2:SetMirrored(true)
	elseif variant == "OutdoorIndoor" then
		local atts = a:GetAttaches() or empty_table
		local a1 = atts[1] or PlaceObject("Object")
		for i = 2, #atts do
			DoneObject(atts[i])
		end
		if self:GetGameFlags(const.gofPermanent) ~= 0 then
			a1:SetGameFlags(const.gofPermanent)
		end
		m1 = m1 or self.indoor_material_1
		local e1 = self:ComposeBrokenDecInteriorAttachName(sc, suffix, m1, index)
		if not IsValidEntity(e1) then
			self:ReportMissingBrokenDecInteriorAttach(e1)
		else
			a1:ChangeEntity(e1)
		end
		a:Attach(a1)
		a1:SetAttachAngle(180*60)
		a1:SetMirrored(true)
	else
		a:DestroyAttaches()
	end
end

---
--- Generates a unique identifier for a destroyed slab attach based on the side flag and offset.
---
--- @param sideFlag number The side flag of the destroyed slab attach.
--- @param offset number The offset of the destroyed slab attach.
--- @return number The unique identifier for the destroyed slab attach.
function GetDestroyedSlabAttachId(sideFlag, offset)
	return xxhash(sideFlag, offset)
end

DefineClass("DestroyableFloorSlab", "Slab")
DefineClass.DestroyedSlabAttach = {
	__parents = { "Object", "EditorSubVariantObject" },
	flags = { gofPermanent = false },
	
	use_self_colors = false,
	index = false,
	--editor stuff
	parent = false,
	offset = false,
	angle = false,
}
DestroyedAttachClass = "DestroyedSlabAttach"

---
--- Handles the deletion of a destroyed slab attach object.
---
--- @param o DestroyedSlabAttach The destroyed slab attach object that was deleted.
---
function OnDestroyedAttachDeleted(o)
	--common stub
end

---
--- Handles the deletion of a destroyed slab attach object.
---
--- @param o DestroyedSlabAttach The destroyed slab attach object that was deleted.
---
function DestroyedSlabAttach:Destroy()
	--this should only get called from editor when pressing shift+d on an attach when DestroyedAttachSelectionEnabled is true
	--I find myself pressing shift+d instead of delete often hence this handling
	OnDestroyedAttachDeleted(self)
	DoneObject(self)
end

---
--- Generates a unique identifier for a destroyed slab attach based on the side flag and offset.
---
--- @param self DestroyedSlabAttach The destroyed slab attach object.
--- @return number The unique identifier for the destroyed slab attach.
function DestroyedSlabAttach:GetId()
	return GetDestroyedSlabAttachId(self:GetSide(), self:GetParent() and self:GetAttachOffset() or self.offset)
end

---
--- Gets the side flag for the destroyed slab attach.
---
--- @param self DestroyedSlabAttach The destroyed slab attach object.
--- @return number The side flag for the destroyed slab attach.
function DestroyedSlabAttach:GetSide()
	local p = self:GetParent() or self.parent
	assert(p)
	local da = p.destroyed_attaches
	if da.Top == self or table.find(da.Top, self) then
		return SlabNeighbourMask.Top
	elseif da.Bottom == self or table.find(da.Bottom, self) then
		return SlabNeighbourMask.Bottom
	elseif da.Right == self or table.find(da.Right, self) then
		return SlabNeighbourMask.Right
	else
		return SlabNeighbourMask.Left
	end
end

---
--- Manages the attaches for a destroyed slab attach object.
---
--- This function is responsible for updating the visual representation of the destroyed slab attach object, including its entity, suffix, and variant. It ensures that the destroyed slab attach object is properly integrated with the parent slab object.
---
--- @param self DestroyedSlabAttach The destroyed slab attach object.
function DestroyedSlabAttach:ManageAttaches()
	local p = self:GetParent() or self.parent
	local sideFlag = self:GetSide()
	local sc = p:MaskToChar(maskToOppositeMask[sideFlag]) --art is reversed
	local curE = self:GetEntity()
	local suffix = string.match(curE, "%d+$")
	local variant = p.variant
	if IsKindOf(p, "SlabWallObject") then
		--slabwallobjs dont have variants
		local slabAtAttchPos = MapGetFirst(self, 0, "WallSlab", function(o)
			return o.invisible_reasons and not o.invisible_reasons["suppressed"]
		end)
		if slabAtAttchPos then
			variant = slabAtAttchPos.variant
		end
	end
	manageAttachsAttaches(p, self, sc, suffix, variant, self.index)
end

---
--- Cycles the entity of the destroyed slab attach object and updates the visual representation of the destroyed slab attach.
---
--- This function is responsible for updating the visual representation of the destroyed slab attach object, including its entity, suffix, and variant. It ensures that the destroyed slab attach object is properly integrated with the parent slab object.
---
--- @param self DestroyedSlabAttach The destroyed slab attach object.
--- @param delta number The amount to cycle the entity.
--- @return boolean True if the entity was successfully cycled, false otherwise.
function DestroyedSlabAttach:CycleEntity(delta)
	if EditorSubVariantObject.CycleEntity(self, delta) then
		self:ManageAttaches()
		local p = self.parent or self:GetParent()
		local id = self:GetId()
		p.da_subvariants = p.da_subvariants or {}
		p.da_subvariants[id] = self.subvariant
	end
end

--WallInt_Colonial_Wall_BrokenDec_R_01
---
--- Composes the name for a broken decoration interior attach object.
---
--- This function is responsible for generating the name of a broken decoration interior attach object based on the provided parameters. It selects a random subvariant entity from the available subvariants for the given material and side.
---
--- @param side string The side of the slab the broken decoration attach object is on (e.g. "R", "T", "B").
--- @param suffix string The suffix of the broken decoration attach object.
--- @param material string The material of the slab.
--- @param index number The index of the broken decoration attach object.
--- @return string The name of the broken decoration interior attach object.
function Slab:ComposeBrokenDecInteriorAttachName(side, suffix, material, index)
	material = material or self.material
	local svd = (Presets.SlabPreset.SlabIndoorMaterials or empty_table)[material]
	local subvarId = string.format("broken_attach_attaches_%s_subvariants", string.lower(side))
	local subvariants, total = GetMaterialSubvariants(svd, subvarId)
	
	if subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntity(self:GetSeed(total, 	7001 + (index or 0)), subvariants, function(suffix, material, side)
			return string.format("WallInt_%s_Wall_BrokenDec_%s_%s", material, side, suffix)
		end, material, side)
	else
		return string.format("WallInt_%s_Wall_BrokenDec_%s_%s", material, side, suffix)
	end
end

---
--- Gets the base string for broken decoration attaches based on the slab's roof component.
---
--- This function returns the base string for broken decoration attaches based on the slab's roof component. If the slab does not have a roof component, it falls back to the default base string.
---
--- @return string The base string for broken decoration attaches.
function Slab:GetBrokenDecAttachesBaseString()
	return "broken_attaches_%s_subvariants"
end

local roofCompToDecSubvariantArr = {
	Eave = "broken_attaches_eave_%s_subvariants",
	Rake = "broken_attaches_rake_%s_subvariants",
	Ridge = "broken_attaches_ridge_%s_subvariants",
	Gable = "broken_attaches_gable_%s_subvariants",
}

---
--- Gets the base string for broken decoration attaches based on the roof component of the slab.
---
--- This function returns the base string for broken decoration attaches based on the roof component of the slab. If the slab does not have a roof component, it falls back to the default base string returned by `Slab:GetBrokenDecAttachesBaseString()`.
---
--- @return string The base string for broken decoration attaches.
function RoofSlab:GetBrokenDecAttachesBaseString()
	return roofCompToDecSubvariantArr[self.roof_comp] or Slab.GetBrokenDecAttachesBaseString()
end

---
--- Gets a random subvariant entity from the provided list of subvariants, avoiding a specific subvariant if provided.
---
--- This function selects a random subvariant entity from the provided list of subvariants. If an `avoidSubvariant` is provided, it will avoid selecting that specific subvariant if possible.
---
--- @param random number The random seed to use for selecting the subvariant.
--- @param subvariants table A table of subvariant data, where each entry has a `suffix` and `chance` field.
--- @param avoidSubvariant string (optional) The subvariant to avoid selecting.
--- @param get_ent_func function A function that takes the subvariant suffix and other arguments and returns the entity name.
--- @param ... any Additional arguments to pass to the `get_ent_func`.
--- @return string The name of the selected subvariant entity.
--- @return string The suffix of the selected subvariant.
function GetRandomSubvariantEntityAvoidSubvariant(random, subvariants, avoidSubvariant, get_ent_func, ...)
	if not avoidSubvariant then
		return GetRandomSubvariantEntity(random, subvariants, get_ent_func, ...)
	end
	
	local t = 0
	for i = 1, #subvariants do
		t = t + subvariants[i].chance
		if i == #subvariants or t > random then
			local suff = subvariants[i].suffix
			if suff == avoidSubvariant then
				if i < #subvariants then
					i = i + 1
				elseif i > 1 then
					i = i - 1
				end
			end
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

--WallExt_Colonial_Wall_ExEx_BrokenDec_R_01
---
--- Composes the name of a broken decoration attachment based on the provided parameters.
---
--- @param side string The side of the slab the broken decoration is attached to. Can be "R", "T", or "B".
--- @param seedConst number (optional) A seed constant to use for selecting a random subvariant.
--- @param subvariant number (optional) The specific subvariant to use.
--- @param avoidSubvariant string (optional) A subvariant to avoid selecting.
--- @return string The composed name of the broken decoration attachment.
--- @return string The suffix of the selected subvariant.
function Slab:ComposeBrokenDecName(side, seedConst, subvariant, avoidSubvariant) --sides are R, T, B
	local svd = self:GetMaterialPreset()
	local str = self:GetBrokenDecAttachesBaseString()
	local subvarId = string.format(str, string.lower(side))
	local subvariants, total = GetMaterialSubvariants(svd, subvarId)
	local e = self:GetBaseEntityName()
	
	if not subvariant and subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntityAvoidSubvariant(self:GetSeed(total, seedConst or 0), subvariants, avoidSubvariant, function(suffix, e, side)
			return string.format("%s_BrokenDec_%s_%s", e, side, suffix)
		end, e, side)
	elseif subvariant then
		local subvarStr = subvariant >= 10 and tostring(subvariant) or string.format("0%s", tostring(subvariant))
		return string.format("%s_BrokenDec_%s_%s", e, side, subvarStr), subvarStr
	else
		return string.format("%s_BrokenDec_%s_01", e, side), "01"
	end
end

---
--- Composes the name of a broken decoration attachment for a RoofPlaneSlab object, taking into account the angle of the slab.
---
--- @param side string The side of the slab the broken decoration is attached to. Can be "R", "T", or "B".
--- @param ... any Additional arguments to pass to the Slab.ComposeBrokenDecName function.
--- @return string The composed name of the broken decoration attachment.
--- @return string The suffix of the selected subvariant.
function RoofPlaneSlab:ComposeBrokenDecName(side, ...)
	if side == "T" or side == "B" then
		--flip t and b when flipped by angle
		local a = self:GetAngle() / 60
		if a == 180 or a == 270 then
			side = side == "T" and "B" or "T"
		end
	end
	
	return Slab.ComposeBrokenDecName(self, side, ...)
end

---
--- Composes the name of a broken decoration attachment for a RoofPlaneSlab object, taking into account the angle of the slab.
---
--- @param side string The side of the slab the broken decoration is attached to. Can be "R", "T", or "B".
--- @return string The composed name of the broken decoration attachment.
--- @return string The suffix of the selected subvariant.
function RoofPlaneSlab:ComposeBrokenEntityName(side)
	if side == "T" or side == "B" then
		--flip t and b when flipped by angle
		local a = self:GetAngle() / 60
		if a == 180 or a == 270 then
			side = side == "T" and "B" or "T"
		end
	end
	
	return Slab.ComposeBrokenEntityName(self, side)
end

---
--- Composes the name of a broken decoration attachment for a SlabWallObject object, taking into account the side of the slab.
---
--- @param side string The side of the slab the broken decoration is attached to. Can be "R", "T", or "B".
--- @param nbrvar integer The variant of the slab.
--- @param count integer The seed value to use for random subvariant selection.
--- @param subvariant integer The specific subvariant to use, if provided.
--- @param material string The material of the slab.
--- @return string The composed name of the broken decoration attachment.
--- @return string The suffix of the selected subvariant.
function SlabWallObject:ComposeBrokenDecName(side, nbrvar, count, subvariant, material) --sides are R, T, B
	local material_list = Presets.SlabPreset.SlabMaterials
	material = material or self.material
	local svd = material_list and material_list[material]
	local subvarId = string.format("broken_attaches_%s_subvariants", string.lower(side))
	local subvariants, total = GetMaterialSubvariants(svd, subvarId)
	local e = string.format("WallExt_%s_Wall_%s", material, variantToVariantName[nbrvar])
	
	if not subvariant and subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntity(self:GetSeed(total, count), subvariants, function(suffix, e, side)
			return string.format("%s_BrokenDec_%s_%s", e, side, suffix)
		end, e, side)
	elseif subvariant then
		local subvarStr = subvariant >= 10 and tostring(subvariant) or string.format("0%s", tostring(subvariant))
		return string.format("%s_BrokenDec_%s_%s", e, side, subvarStr), subvarStr
	else
		return string.format("%s_BrokenDec_%s_01", e, side), "01"
	end
end

--WallExt_Colonial_Wall_ExEx_Broken_R_01
---
--- Composes the name of a broken decoration attachment for a Slab object, taking into account the side of the slab.
---
--- @param side string The side of the slab the broken decoration is attached to. Can be "R", "T", or "B".
--- @return string The composed name of the broken decoration attachment.

function Slab:ComposeBrokenEntityName(side) --sides are R, T, B
	local svd = self:GetMaterialPreset()
	local subvarId = string.format("broken_%s_subvariants", string.lower(side))
	local subvariants, total = GetMaterialSubvariants(svd, subvarId)
	local e = self:GetBaseEntityName()

	if subvariants and #subvariants > 0 then
		if self.subvariant ~= -1 then --user selected subvar
			local digitStr = self:GetSubvariantDigitStr(subvariants)
			return string.format("%s_Broken_%s_%s", e, side, digitStr)
		else
			return GetRandomSubvariantEntity(self:GetSeed(total), subvariants, function(suffix, e, side)
				return string.format("%s_Broken_%s_%s", e, side, suffix)
			end, e, side)
		end
	else
		local digitStr = self:GetSubvariantDigitStr()
		return string.format("%s_Broken_%s_%s", e, side, digitStr)
	end
end

--WallExt_Colonial_Wall_ExEx_Damaged_01
---
--- Composes the name of a damaged entity for a Slab object, taking into account the subvariant.
---
--- @return string The composed name of the damaged entity.
function Slab:ComposeDamagedEntityName()
	local svd = self:GetMaterialPreset()
	local subvariants, total = GetMaterialSubvariants(svd, "damaged_subvariants")
	local e = self:GetBaseEntityName()
	
	if subvariants and #subvariants > 0 then
		if self.subvariant ~= -1 then --user selected subvar
			local digitStr = self:GetSubvariantDigitStr(subvariants)
			return string.format("%s_Damaged_%s", e, digitStr)
		else
			return GetRandomSubvariantEntity(self:GetSeed(total), subvariants, function(suffix, e)
				return string.format("%s_Damaged_%s", e, suffix)
			end, e)
		end
	else
		local digitStr = self:GetSubvariantDigitStr()
		return string.format("%s_Damaged_%s", e, digitStr)
	end
end

--WallInt_Planks_Wall_Broken_R_02 --maybe.. who knows..
---
--- Composes the name of a broken indoor material entity for a Slab object, taking into account the subvariant.
---
--- @param mat string The material of the slab.
--- @return string The composed name of the broken indoor material entity.
function Slab:ComposeBrokenIndoorMaterialEntityName(mat)
	local svd = (Presets.SlabPreset.SlabIndoorMaterials or empty_table)[mat]
	local side = maskToCharWall[self.diagonal_ent_mask ~= 0 and invertDiagEntMask[self.diagonal_ent_mask] or self.destroyed_entity_side]
	local subvarId = string.format("broken_%s_subvariants", string.lower(side))
	local subvariants, total = GetMaterialSubvariants(svd, subvarId)
	
	if subvariants and #subvariants > 0 then
		return GetRandomSubvariantEntity(self:GetSeed(total), subvariants, function(suffix, mat, side)
			return string.format("WallInt_%s_Wall_Broken_%s_%s", mat, side, suffix)
		end, mat, side)
	else
		return string.format("WallInt_%s_Wall_Broken_%s_01", mat, side)
	end
end

---
--- Converts a slab neighbor mask to a character representation.
---
--- @param m number The slab neighbor mask.
--- @return string The character representation of the slab neighbor mask.
function Slab:MaskToChar(m)
	return maskToCharWall[m]
end

---
--- Converts a slab neighbor mask to a character representation for a floor slab.
---
--- @param m number The slab neighbor mask.
--- @return string The character representation of the slab neighbor mask.
function DestroyableFloorSlab:MaskToChar(m)
	return maskToCharFloor[m]
end

local maskToCharRake = {
	[SlabNeighbourMask.Left] = "B",
	[SlabNeighbourMask.Right] = "T",
}
---
--- Converts a slab neighbor mask to a character representation for a roof edge slab.
---
--- @param m number The slab neighbor mask.
--- @return string The character representation of the slab neighbor mask.
function RoofEdgeSlab:MaskToChar(m)
	if self.roof_comp == "Rake" then
		return maskToCharRake[m]
	end

	return maskToCharWall[m]
end

---
--- Determines whether a slab should add an attachment when there is no neighbor.
---
--- @param sideFlag number The side flag indicating which side of the slab has no neighbor.
--- @return boolean Always returns false, indicating that a slab should not add an attachment when there is no neighbor.
---
function Slab:ShouldAddAttachOnNoNbr(sideFlag)
	return false
end

---
--- Determines whether the slab is a roof plane.
---
--- @return boolean Always returns false, indicating that the slab is not a roof plane.
---
function Slab:IsRoofPlane()
	return false
end

---
--- Determines whether the slab is a roof plane.
---
--- @return boolean Always returns true, indicating that the slab is a roof plane.
---
function RoofPlaneSlab:IsRoofPlane()
	return true
end

---
--- Updates the destroyed state of the slab.
---
--- If `use_replace_ent_destruction` is false, calls `UpdateDestroyedStateInternal()` to update the destroyed state.
--- If `use_replace_ent_destruction` is true, calls `UpdateDestroyedStateInternal_ReplaceEntity()` to update the destroyed state by replacing the entity.
---
--- @return boolean True if the update was successful, false otherwise.
---
function Slab:UpdateDestroyedState()
	if not self.use_replace_ent_destruction then
		return self:UpdateDestroyedStateInternal()
	else
		return self:UpdateDestroyedStateInternal_ReplaceEntity()
	end
end

---
--- Updates the destroyed state of the slab by replacing the entity.
---
--- This function is called when `use_replace_ent_destruction` is true. It composes the name of the damaged entity, checks if it is a valid entity, and if so, changes the entity of the slab to the damaged entity. It then sets the appropriate enumeration flags, resets the visibility flags, and sets the collision mask.
---
--- If the damaged entity is not valid, it reports the missing damaged entity.
---
--- @return boolean True if the update was successful, false otherwise.
---
function Slab:UpdateDestroyedStateInternal_ReplaceEntity()
	local e = self:ComposeDamagedEntityName()
	if IsValidEntity(e) then
		if e ~= self:GetEntity() then
			self.destroyed_entity_side = 0
			self.destroyed_entity = false
			self.diagonal_ent_mask = 0
			self:ChangeEntity(e)
			self:SetEnumFlags(const.efCollision + const.efApplyToGrids)
			self:ResetVisibilityFlags()
			collision.SetAllowedMask(self, self.collision_mask or 0)
		end
	else
		self:ReportMissingDamagedEntity(e)
	end
	
	return true
end

---
--- Determines whether a wall slab should add an attachment on the side with no neighbor.
---
--- @param sideFlag number The side flag indicating the side of the slab.
--- @param isStructuralRow boolean Whether the slab is part of a structural row.
--- @param osf number The opposite side flag.
--- @return boolean True if an attachment should be added, false otherwise.
---
function WallSlab:ShouldAddAttachOnNoNbr(sideFlag, isStructuralRow, osf)
	osf = osf or maskToOppositeMask[sideFlag]
	local cnbr = self:GetNeighbourCorner(sideFlag)
	if not cnbr or cnbr.is_destroyed then
		--check for windows
		local x, y, z = self:GetPosXYZ()
		local nbr = self:GetNeighbour(sideFlag, nil, 0)
		if not nbr or not nbr.wall_obj then --window on this side, use attach
			return false
		end
	end
	return true
end

---
--- Determines whether a floor slab should add an attachment on the side with no neighbor.
---
--- @param sideFlag number The side flag indicating the side of the slab.
--- @return boolean True if an attachment should be added, false otherwise.
---
function DestroyableFloorSlab:ShouldAddAttachOnNoNbr(sideFlag)
	return self:IsStructuralRow(sideFlag)
end

---
--- Determines whether the side flag of a slab should be flipped when checking its neighbor.
---
--- @param sideFlag number The side flag of the slab.
--- @param nbr table The neighbor slab.
--- @param myAngle number The angle of the slab.
--- @param me table The slab object.
--- @return boolean True if the side flag should be flipped, false otherwise.
---
function ShouldFlipSideFlag(sideFlag, nbr, myAngle, me)
	--if its top or bot, same angle as me or a floor take the opposite side flag, else same side
	return ((sideFlag & 12) == 0) or nbr:GetAngle() == myAngle or IsKindOfClasses(nbr, "DestroyableFloorSlab", "RoomCorner") or (me and IsKindOf(me, "RoomCorner"))
end

---
--- Determines the side flag to use when checking a neighbor slab's orientation.
---
--- @param sideFlag number The side flag of the current slab.
--- @param nbr table The neighbor slab.
--- @param self table The current slab object.
--- @return number The side flag to use when checking the neighbor.
---
function GetNeigbhourSideFlagTowardMe(sideFlag, nbr, self)
	local a = self:GetAngle()
	if self:IsRoofPlane() then
		local ha = nbr:GetAngle()
		if (abs(a - ha) / 60) % 180 == 90 then
			return 0
		end
	end
	return ShouldFlipSideFlag(sideFlag, nbr, a, self)
				and maskToOppositeMask[sideFlag] or sideFlag
end

local sideToSeedConst = {
	[SlabNeighbourMask.Left] = 0,
	[SlabNeighbourMask.Right] = 181,
	[SlabNeighbourMask.Top] = 0,
	[SlabNeighbourMask.Bottom] = 83,
}

local function processSideHelper(self, da, sideFlag, mask)
	local ss = maskToString[sideFlag]
	local osf = maskToOppositeMask[sideFlag]
	local hasDestroyedNbr = (mask & sideFlag) == sideFlag
	local a = self:GetAngle()
	
	if self.is_destroyed then
		::begin::
		local isStructuralRow = self:IsStructuralRow(sideFlag)
		if (not hasDestroyedNbr or isStructuralRow) then --has a non destroyed nbr on this side (or empty space or corner)			
			local attId = GetDestroyedSlabAttachId(sideFlag, point30)
			local forcedSubvariant = self.da_subvariants and self.da_subvariants[attId] or false
			local addAttch = forcedSubvariant ~= 0
			local nbrs = self:GetNeighbour(sideFlag, "all")
			local firstNbr = IsValid(nbrs) and nbrs or type(nbrs) == "table" and nbrs[1]
			
			if addAttch then
				if not IsValid(firstNbr) then
					addAttch = self:ShouldAddAttachOnNoNbr(sideFlag, isStructuralRow, osf)
				else
					local isRoofPlane = self:IsRoofPlane()
					local destroyedNbrs = 0
					local function processNbr(nbr)
						if nbr.is_destroyed then
							destroyedNbrs = destroyedNbrs + 1
						end
						local ha = nbr:GetAngle()
						if not hasDestroyedNbr and not nbr.use_replace_ent_destruction and
							((a == ha or sideFlag < 4) and (nbr.destroyed_entity_side & osf) == osf or  --same orientation or top/bot and opposite side
							a ~= ha and sideFlag >= 4 and (nbr.destroyed_entity_side & sideFlag) == sideFlag) or --diff orientation and left/right and same side
							(isRoofPlane and #nbrs == 1 and (abs(a - ha)/60) % 180 ~= 0) then
							--nbr uses ent towards us
							addAttch = false
						end
					end
					
					if IsValid(nbrs) then
						processNbr(nbrs)
					elseif type(nbrs) == "table" then
						for i = 1, #nbrs do
							processNbr(nbrs[i])
							if not addAttch then
								break
							end
						end
					end
					
					if addAttch and destroyedNbrs > 0 then
						--fallback fix for when .destroyed_neighbours is not updated with real nbr state
						--nbr failed to tweak our state flags, but is destroyed
						--probably a different room that is aligned with gaps to us
						--so what we do is update the flags and reset the current procedure
						self.destroyed_neighbours = self.destroyed_neighbours | sideFlag
						mask = self.destroyed_neighbours
						hasDestroyedNbr = true
						goto begin
					end
				end
			end
			
			if addAttch then
				local sc = self:MaskToChar(osf)
				local avoidSubviariant = nil
				if not forcedSubvariant and sideFlag == SlabNeighbourMask.Right then
					local ssc = maskToString[osf]
					if da[ssc] then
						local ose = da[ssc]:GetEntity()
						avoidSubviariant = string.match(ose, "%d+$")
					end
				end
				local e, suffix = self:ComposeBrokenDecName(sc, sideToSeedConst[sideFlag], forcedSubvariant, avoidSubviariant)
				
				if not da[ss] then
					local a = PlaceObject(DestroyedAttachClass)
					if self:GetGameFlags(const.gofPermanent) ~= 0 then
						a:SetGameFlags(const.gofPermanent)
					end
					
					if not IsValidEntity(e) then
						self:ReportMissingBrokenDec(e)
						a:ChangeEntity("InvisibleObject", "idle")
					else
						a:ChangeEntity(e)
					end
					da[ss] = a
				else
					--attch already exists, refresh ent
					if e and e ~= da[ss]:GetEntity() then
						if not IsValidEntity(e) then
							self:ReportMissingBrokenDec(e)
							da[ss]:ChangeEntity("InvisibleObject", "idle")
						else
							da[ss]:ChangeEntity(e)
						end
					end
				end
				
				--manage attach's interior attaches
				local a = da[ss]
				collision.SetAllowedMask(a, 0)
				manageAttachsAttaches(self, a, sc, suffix)
				
			elseif da[ss] then
				--attach exists but it shouldn't
				DoneObject(da[ss])
				da[ss] = false
			end
		elseif not isStructuralRow then
			--nbr is destroyed and not structural row
			DoneObject(da[ss])
			da[ss] = false
			local nbr = self:GetNeighbour(sideFlag)
			if IsValid(nbr) then
				if ((sideFlag & 12) == 0) or nbr:GetAngle() == a then
					nbr:DestroyDestroyedAttach(osf, self)
				else
					nbr:DestroyDestroyedAttach(sideFlag, self)
				end
			end
		end
	else --not destroyed
		local nbr
		local destroyedNbrSideIsFree = true
		if hasDestroyedNbr then
			nbr = self:GetNeighbour(sideFlag)
			if IsValid(nbr) then
				if IsKindOf(nbr, "SlabWallObject") then
					--in this case we only care if it's on top and its broken
					local _, state = nbr:GetDestroyedEntityAndState() --it will pick ent in this pass so we can't check directly
					destroyedNbrSideIsFree = not state:starts_with("broken") and (sideFlag ~= 1 or self.force_destroyed_entity == sideFlag)
				else
					destroyedNbrSideIsFree = (nbr.diagonal_ent_mask & osf) == 0
				end
			end
		end
		
		if hasDestroyedNbr and not self.destroyed_entity then --has a destroyed nbr on this side and hasn't picked ent yet
			--we can set a special entity facing the destruction
			--if we do, we got to make sure nbr doesn't have an attch there
			if self.force_no_destroyed_entity then
				return
			end
			local random = -1
			local isStackable = self.class == "RoofWallSlab"
			local stack
			if self.force_destroyed_entity then
				if self.force_destroyed_entity == sideFlag then
					random = 100
				else
					random = 0
				end
			else
				if isStackable then
					stack = MapGet(self, 0, self.class, nil, const.efVisible)
					for _, obj in ipairs(stack) do
						random = Max(obj:GetSeed(100, 102317), random)
					end
				else
					random = self:GetSeed(100, 102317)
				end
			end
			
			if destroyedNbrSideIsFree and random >= 50 then
				if IsValid(nbr) then
					if ShouldFlipSideFlag(sideFlag, nbr, a) then
						nbr:DestroyDestroyedAttach(osf, self)
					else
						nbr:DestroyDestroyedAttach(sideFlag, self)
					end
				else
					--somebody flagged this direction as having a destroyed nbr, yet it's missing.
					--last time it was because invisible/suppressed slabs were getting destroyed.
					--assert(false) --well that sux.
				end
				
				local sc = self:MaskToChar(sideFlag)
				self:UnlockSubvariantReversible()
				self.destroyed_entity = self:ComposeBrokenEntityName(sc)
				if not IsValidEntity(self.destroyed_entity) then
					self:ReportMissingBrokenEntity(self.destroyed_entity)
					self.destroyed_entity = nil
					return
				end
				
				self.destroyed_entity_side = sideFlag
				
				for i = 1, #(stack or "") do
					if stack[i] ~= self then
						stack[i].destroyed_entity_side = (sideFlag & 12) ~= 0 and a ~= stack[i]:GetAngle() and osf or sideFlag
						stack[i].destroyed_entity = self.destroyed_entity
						stack[i]:UnlockSubvariantReversible()
					end
				end
				
				if IsValid(nbr) then
					nbr:UpdateDecorationsDestroyedState()
				end
			end
		elseif not hasDestroyedNbr and (self.destroyed_entity_side & sideFlag) == sideFlag then
			--nbr got repaired
			self.destroyed_entity_side = 0
			self.destroyed_entity = false
			self:RestorePreDestructionSubvariant()
		elseif hasDestroyedNbr and (self.destroyed_entity_side & sideFlag) == sideFlag then
			if destroyedNbrSideIsFree then
				--status quoe, refresh ent
				local sc = self:MaskToChar(sideFlag)
				self.destroyed_entity = self:ComposeBrokenEntityName(sc)
				if not IsValidEntity(self.destroyed_entity) then
					self:ReportMissingBrokenEntity(self.destroyed_entity)
					self.destroyed_entity = nil
					return
				end
			else
				--nbr picked a diag ent on this side, clean up
				self.destroyed_entity_side = 0
				self.destroyed_entity = false
				self:RestorePreDestructionSubvariant()
			end
		end
	end
end

---
--- Iterates over all stacked and visible objects and calls the provided function for each one.
---
--- @param func function The function to call for each visible object.
--- @param ... any Additional arguments to pass to the function.
---
function Slab:ForEachStackedVisible(func, ...)
	MapForEach(self, 0, self.class, nil, const.efVisible, function(o, func, ...)
		func(o, ...)
	end, func, ...)
end

---
--- Iterates over all neighboring objects and calls the provided function for each one.
---
--- @param sideFlag integer The side flag to use when getting the neighbors.
--- @param func function The function to call for each neighbor.
--- @param ... any Additional arguments to pass to the function.
---
function Slab:ForEachNeighbour(sideFlag, func, ...)
	local nbrs = self:GetNeighbour(sideFlag, "all")
	if IsValid(nbrs) then
		func(nbrs, ...)
	else
		for i = 1, #(nbrs or "") do
			func(nbrs[i], ...)
		end
	end
end

---
--- Sets the destroyed entity and clears associated flags.
---
--- When an object is destroyed, this function is called to set the destroyed entity and clear any associated flags. It sets the `destroyed_entity_side`, `destroyed_entity`, and `diagonal_ent_mask` properties to their default values. If the current entity is not "InvisibleObject", it changes the entity to "InvisibleObject" with the "idle" state. Finally, it clears the `efCollision` and `efApplyToGrids` enum flags, as these do not get saved and need to be re-applied.
---
--- @param self Slab The Slab object.
---
function Slab:SetDestroyedEntityAndFlags()
	self.destroyed_entity_side = 0
	self.destroyed_entity = false
	self.diagonal_ent_mask = 0
	
	if self:GetEntity() ~= "InvisibleObject" then
		self:ChangeEntity("InvisibleObject", "idle")
		self.entity = "InvisibleObject" --needed for corners
	end
	self:ClearEnumFlags(const.efCollision + const.efApplyToGrids) --these dont get saved and need to be re-applied
end

---
--- Sets the destroyed entity and clears associated flags.
---
--- When an object is destroyed, this function is called to set the destroyed entity and clear any associated flags. It sets the `destroyed_entity_side`, `destroyed_entity`, and `diagonal_ent_mask` properties to their default values. If the current entity is not "InvisibleObject", it changes the entity to "InvisibleObject" with the "idle" state. Finally, it clears the `efCollision` and `efApplyToGrids` enum flags, as these do not get saved and need to be re-applied.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:SetDestroyedEntityAndFlags()
	local e = self:GetEntity()
	local ne, state = self:GetDestroyedEntityAndState()
	if e and e ~= "" and e ~= "InvisibleObject" then
		if e ~= self.class then
			print("once", "SlabWallObject non destroyed ent unrecoverable. Ent - " .. e .. " Cls - " .. self.class)
		end
	end

	self.destroyed_entity_side = 0
	self.destroyed_entity = false
	self.diagonal_ent_mask = 0
	
	if self:GetEntity() ~= ne or self:GetStateText() ~= state then
		if ne == "InvisibleObject" then
			--when going to inv obj for the first time kill light attaches
			self:DestroyAttaches("ParSystem", "SpotLight")
		end
		self:ChangeEntity(ne, state)
		self:SetState(state)
	end
	self:ClearEnumFlags(const.efCollision + const.efApplyToGrids) --these dont get saved and need to be re-applied
	if self.is_destroyed and self:HasMember("pass_through_state") then
		self.pass_through_state = "broken"
	end
end

---
--- Updates the destroyed state of a RoofEdgeSlab object.
---
--- This function is responsible for updating the destroyed state of a RoofEdgeSlab object. It first sets the destroyed entity and clears any associated flags if the object is destroyed. It then processes the destroyed attaches on the sides of the slab, setting the mirroring and attaching the attaches as necessary. Finally, it refreshes the colors, sets the warped state, and returns a boolean indicating whether the update was successful.
---
--- @param self RoofEdgeSlab The RoofEdgeSlab object.
--- @return boolean Whether the update was successful.
function RoofEdgeSlab:UpdateDestroyedStateInternal()
	local mask = self.destroyed_neighbours
	self.destroyed_attaches = self.destroyed_attaches or {Top = false, Bottom = false, Left = false, Right = false}
	local da = self.destroyed_attaches
	local isDestroyed = self.is_destroyed
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
	else 
		return false --has only attaches so let non destroyed guys pick their regular ents
	end
	
	for i = 2, 3 do
		processSideHelper(self, da, 1 << i, mask)
	end
	
	local isMirrored = self:GetMirrored()
	local rc = self.roof_comp
	
	if da.Right then
		local ml = isMirrored
		if rc == "Gable" or rc == "Eave" then
			ml = not ml
		end
		da.Right:SetMirrored(ml)
		self:Attach(da.Right)
	end
	
	if da.Left then
		local ml = isMirrored
		if rc == "Ridge" then
			ml = not ml
		end
		da.Left:SetMirrored(ml)
		self:Attach(da.Left)
	end
	
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return true
end

---
--- Calculates the offset for a row in a SlabWallObject.
---
--- The offset is calculated based on the width of the SlabWallObject, with the center row having an offset of 0. If the width is even, the offset is simply the row number minus half the width. If the width is odd, the offset is the row number minus half the width, minus 1.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param row number The row number to calculate the offset for.
--- @return number The calculated offset for the given row.
function SlabWallObject:GetOffset(row)
	return (row - self.width/2 - (self.width % 2 == 0 and 0 or 1))
end

---
--- Calculates the offset for the left side of a SlabWallObject.
---
--- The offset is calculated based on the width of the SlabWallObject, with the center row having an offset of 0. If the width is even, the offset is simply the row number minus half the width. If the width is odd, the offset is the row number minus half the width, minus 1.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return number The calculated offset for the left side.
function SlabWallObject:GetLeftOffset()
	return self:GetOffset(1)
end

---
--- Calculates the offset for the right side of a SlabWallObject.
---
--- The offset is calculated based on the width of the SlabWallObject, with the center row having an offset of 0. If the width is even, the offset is simply the row number minus half the width. If the width is odd, the offset is the row number minus half the width, minus 1.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return number The calculated offset for the right side.
function SlabWallObject:GetRightOffset()
	return self:GetOffset(self.width)
end

local SlabWallObjectBrokenDecAttachMaterials = {
	Colonial = true,
}

local SlabWallObjectBrokenDecExceptionEnts = {
	TallDoor_Colonial_Double_02 = true,
	Window_Colonial_Single_01 = true,
	WindowBig_Colonial_Single_03 = true,
	WindowBig_Colonial_Single_04 = true,
	WindowBig_Colonial_Single_05 = true,
	WindowBig_Colonial_Double_02 = true,
}

---
--- Iterates over all the neighbours of a SlabWallObject, including those around the corners.
---
--- The function passed as the first argument will be called for each neighbour, and can return "break" to stop the iteration early.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @param func function The function to call for each neighbour.
--- @param ... any Additional arguments to pass to the function.
--- @return boolean True if the iteration was stopped early, false otherwise.
function SlabWallObject:ForEachNeighbourOnAllSidesAndAroundCorners(func, ...)
	local function iterate(nbrs, func, ...)
		for j = 1, #(nbrs or "") do
			if func(nbrs[j], ...) == "break" then
				return true
			end
		end
	end
	for i = 0, 3 do
		local sf = 1 << i
		local nbrs = self:GetNeighbour(sf)
		if iterate(nbrs, func, ...) then return end
		
		if i >= 2 then --left or right
			nbrs = self:GetNeighboursAroundCorner(sf)
			if iterate(nbrs, func, ...) then return end
		else
			nbrs = self:GetNeighbourFloor(sf)
			if iterate(nbrs, func, ...) then return end
		end
	end
end

---
--- Checks if the SlabWallObject has any live (not destroyed) neighbours.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return boolean True if the SlabWallObject has any live neighbours, false otherwise.
function SlabWallObject:HasLiveNeighbour()
	local ret = false
	self:ForEachNeighbourOnAllSidesAndAroundCorners(function(nbr)
		if not nbr.is_destroyed then
			ret = true
			return "break"
		end
	end)
	
	return ret
end

---
--- Checks if the SlabWallObject has any live (not destroyed) neighbours below it.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return boolean True if the SlabWallObject has any live neighbours below, false otherwise.
function SlabWallObject:HasLiveNeighbourBelow()
	local nbrs = self:GetNeighbour(SlabNeighbourMask.Bottom)
	for i = 1, #(nbrs or "") do
		if not nbrs[i].is_destroyed then
			return true
		end
	end
	
	return false
end

---
--- Checks if the SlabWallObject has any living (not destroyed) neighbours on two sides or below it.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return boolean True if the SlabWallObject has any living neighbours on two sides or below, false otherwise.
function SlabWallObject:HasLivingNeighbourOnTwoSidesOrBelow()
	local left, right, top, bot = self:GetNeighbours()
	local count = 0
	local function test(arr)
		for i = 1, #(arr or "") do
			if not arr[i].is_destroyed then
				return true
			end
		end
	end
	if test(bot) then return true end
	if test(top) then count = count + 1 end
	if test(left) then count = count + 1 end
	if count >= 2 then return true end
	if test(right) then count = count + 1 end
	return count >= 2
end

---
--- Computes the broken state for the given object.
---
--- @param obj table The object to compute the broken state for.
--- @return string The broken state for the object.
function ComputeBrokenStateForObj(obj)
	return "broken"
end

---
--- Gets the destroyed entity and state for the SlabWallObject.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return string, string The destroyed entity and state for the SlabWallObject.
function SlabWallObject:GetDestroyedEntityAndState()
	if not self:ShouldHaveBrokenDecAttaches() and self:HasState("broken") then
		if self.width > 0 and self:HasLivingNeighbourOnTwoSidesOrBelow() 
			or self.width == 0 and self:HasLiveNeighbourBelow() then
			local state = ComputeBrokenStateForObj(self)
			return self:GetEntity(), state
		end
	end
	
	return "InvisibleObject", "idle"
end

---
--- Checks if the SlabWallObject should have broken decoration attachments.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return boolean True if the SlabWallObject should have broken decoration attachments, false otherwise.
function SlabWallObject:ShouldHaveBrokenDecAttaches()
	if not SlabWallObjectBrokenDecAttachMaterials[self.material] then return false end
	
	local notDestroyedEnt = self.class
	if SlabWallObjectBrokenDecExceptionEnts[notDestroyedEnt] then return false end
	
	return true
end

local function DecSetDestroyedEnt(dec, e, de, destroyed_by)
	if e ~= "InvisibleObject" then
		assert(IsKindOf(dec, "Object"))
		if not rawget(dec, "orig_decoration_ent") then
			rawset(dec, "orig_decoration_ent", e)
		end
		
		if destroyed_by then
			if not rawget(dec, "destroyed_by") then
				rawset(dec, "destroyed_by", destroyed_by)
			end
		end
		
		de = de or "InvisibleObject"
		if not IsValidEntity(de) then
			print("once", "Failed to find entity for broken decoration: " .. de)
		else
			dec:ChangeEntity(de)
		end
	end
end

local function DecRestoreOrigEnt(dec, e, repaired_by)
	local destroyed_by = rawget(dec, "destroyed_by")
	if destroyed_by ~= nil and repaired_by ~= destroyed_by then
		return
	end
	
	local oe = rawget(dec, "orig_decoration_ent")
	if oe ~= e then
		dec:ChangeEntity(oe)
		rawset(dec, "orig_decoration_ent", nil)
	end
end

---
--- Updates the destroyed state of the SlabWallObject and its decorations.
---
--- This function is responsible for managing the destroyed state of a SlabWallObject and its associated decorations. It handles the following tasks:
--- - Sets the destroyed entity and flags for the SlabWallObject if it is destroyed.
--- - Processes the destroyed state of the SlabWallObject's neighbors (both SlabWallObjects and WallSlabs) and attaches appropriate destroyed decoration objects.
--- - Cleans up any unused destroyed decoration objects.
--- - Refreshes the colors of the SlabWallObject.
--- - Updates the destroyed state of the SlabWallObject's decorations.
---
--- @param self SlabWallObject The SlabWallObject instance.
--- @return boolean True if the SlabWallObject's destroyed state was updated, false otherwise.
function SlabWallObject:UpdateDestroyedStateInternal()
	--WINDOW/DOOR
	local isDestroyed = self.is_destroyed
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
	else 
		return false
	end
	
	self.destroyed_attaches = self.destroyed_attaches or {Top = {}, Bottom = {}, Left = {}, Right = {}}
	local da = self.destroyed_attaches
	local left, right, top, bottom = self:GetNeighbours()
	local count = 0
	local h = self.height
	local leftOffset = self:GetLeftOffset()
	local rightOffset = self:GetRightOffset()
	local ma = self:GetAngle()
	local mp = self:GetPos()
	local side = self.side or slabAngleToDir[ma]
	local isFlipped = side ~= slabAngleToDir[ma]
	local flippedMultiplier = isFlipped and 1 or -1
	
	local function addAttchObj(arr)
		count = count + 1
		local o = IsValid(arr[count]) and arr[count] or PlaceObject(DestroyedAttachClass)
		if rawget(o, "use_self_colors") then
			--wrong obj type
			table.insert(arr, count, PlaceObject(DestroyedAttachClass))
			o = arr[count]
		end
		if self:GetGameFlags(const.gofPermanent) ~= 0 then
			o:SetGameFlags(const.gofPermanent)
		end
		arr[count] = o
		o.index = count
		return o
	end
	
	local function prepAttach(arr, sc, variant, sideString, subvariant, material)
		local o = addAttchObj(arr)
		local e, suffix = self:ComposeBrokenDecName(sc, variant, count, subvariant, material)
		
		if not IsValidEntity(e) then
			self:ReportMissingBrokenDec(e)
		else
			o:ChangeEntity(e)
		end
		collision.SetAllowedMask(o, 0)
		self:Attach(o)
		
		if sideString == "Right" then
			o:SetMirrored(true)
		else
			o:SetMirrored(false)
		end
		
		return o, suffix
	end
	
	local function prepArgs(variant, mat, slabAtAttchPos)
		local m1, m2
		if slabAtAttchPos then
			variant = slabAtAttchPos.variant
			mat = slabAtAttchPos.material
			m1 = variant == "IndoorIndoor" and slabAtAttchPos.indoor_material_2 or slabAtAttchPos.indoor_material_1
			m2 = slabAtAttchPos.indoor_material_1
		else
			m1 = self.material
		end
		return variant, mat, m1, m2
	end
	
	local function processNbr(nbr, sideFlag, sideString)
		if IsValid(nbr) then
			local isLeftOrRight = (sideFlag & 12) ~= 0 --sideString == "Left" or sideString == "Right"
			if IsKindOf(nbr, "SlabWallObject") then
				--door or window nbr..
				--this adds destroyed dec attaches in the areas where this destroyed window is adjacent with non destroyed windows
				if not nbr.is_destroyed or (isLeftOrRight and self:IsStructuralRow(sideFlag)) then
					--figure out attach pos and count
					local c, oz, zs, oy, ys
					
					if isLeftOrRight then
						local hp = nbr:GetPos()
						local zd = Max(hp:z() - mp:z(), 0)
						
						local minz = mp:z() + zd
						local maxz = Min((nbr.height - 1) * voxelSizeZ + hp:z(), (h - 1) * voxelSizeZ + mp:z())
						c = (maxz - minz) / voxelSizeZ + 1
						oz = zd
						zs = voxelSizeZ
						ys = 0
						if sideString == "Left" then
							oy = leftOffset * voxelSizeY * flippedMultiplier
						else
							oy = rightOffset * voxelSizeY * flippedMultiplier
						end
					else
						zs = 0
						ys = voxelSizeX
						if sideString == "Top" then
							oz = (h - 1) * voxelSizeZ
						else
							oz = 0
						end
						--ns - x
						--we - y
						local hp = nbr:GetPos()
						
						local function calcHelper(ms, nbr, mpy, hpy)
							local mlo = leftOffset * ms
							local mly = mlo * voxelSizeX - halfVoxelSizeX * ms + mpy
							
							local hlo = nbr:GetLeftOffset() * ms
							local hly = hlo * voxelSizeX - halfVoxelSizeX * ms + hpy
							
							local mro = rightOffset * ms
							local mry = mro * voxelSizeX + halfVoxelSizeX * ms + mpy
							
							local hro = nbr:GetRightOffset() * ms
							local hry = hro * voxelSizeX + halfVoxelSizeX * ms + hpy
							
							local miniy = Max(Min(mly, mry), Min(hly, hry))
							local maxiy = Min(Max(mly, mry), Max(hly, hry))
							
							c = (maxiy - miniy) / voxelSizeY
							oy = (miniy + halfVoxelSizeY) - mpy
							oy = oy * ms * flippedMultiplier
							ys = ys * ms * flippedMultiplier
						end
						
						if side == "North" or side == "South" then
							local ms = side == "North" and -1 or 1
							calcHelper(ms, nbr, mp:x(), hp:x())
						else
							local ms = side == "East" and -1 or 1
							calcHelper(ms, nbr, mp:y(), hp:y())
						end
					end
					
					local osf = maskToOppositeMask[sideFlag]
					local arr = da[sideString]
					local sc = WallSlab.MaskToChar(self, osf)
					
					for i = 1, c do
						local attPos = point(0, oy + (i - 1) * ys, oz + (i - 1) * zs)
						local id = GetDestroyedSlabAttachId(sideFlag, attPos)
						local subvariant = self.da_subvariants and self.da_subvariants[id] or false
						if subvariant ~= 0 then
							local wAttPos = self:GetRelativePoint(attPos)
							local slabAtAttchPos = MapGetFirst(wAttPos, 0, "WallSlab", function(o)
								return o.invisible_reasons and not o.invisible_reasons["suppressed"]
							end)
							local variant, mat, m1, m2 = prepArgs("OutdoorIndoor", self.material, slabAtAttchPos)
							local o, suffix = prepAttach(arr, sc, variant, sideString, subvariant, mat)
							manageAttachsAttaches(self, o, sc, suffix, variant, count, m1, m2)
							o:SetAttachOffset(attPos)
						end
					end
				end
			else --wall slab nbr
				local osf = maskToOppositeMask[sideFlag]
				if (not nbr.is_destroyed or (isLeftOrRight and self:IsStructuralRow(sideFlag))) 
					and ((not isLeftOrRight or nbr.side == side) and nbr.destroyed_entity_side ~= osf --top or bot or same orientation and osf
					or isLeftOrRight and nbr.side ~= side and nbr.destroyed_entity_side ~= sideFlag) then --left or right and different orientation and sideFlag
					local attPos, worldAttPos = self:GetDestroyedAttachOffset(sideFlag, nbr, mp)
					local id = GetDestroyedSlabAttachId(sideFlag, attPos)
					local subvariant = self.da_subvariants and self.da_subvariants[id] or false
					if subvariant ~= 0 then
						local slabAtAttchPos = MapGetFirst(worldAttPos, 0, "WallSlab", function(o)
							return o.invisible_reasons and not o.invisible_reasons["suppressed"]
						end)
						
						local arr = da[sideString]
						local sc = WallSlab.MaskToChar(self, osf)
						local variant, mat, m1, m2 = prepArgs(false, false, slabAtAttchPos or nbr)
						local o, suffix = prepAttach(arr, sc, variant, sideString, subvariant, mat)
						local ad = abs(self:GetAngle() - nbr:GetAngle())
						manageAttachsAttaches(self, o, sc, suffix, variant, count, m1, m2)
						o:SetAttachOffset(attPos)
					end
				end
			end
		else
			for i = 1, #(nbr or "") do
				processNbr(nbr[i], sideFlag, sideString)
			end
		end
	end
	
	local function cleanup(arr)
		for i = count + 1, #(arr or "") do
			DoneObject(arr[i])
			arr[i] = nil
		end
		count = 0
	end
	
	local function appendNbrs(t1, t2)
		if IsValid(t1) then
			if IsValid(t2) then
				return {t1, t2}
			elseif t2 then
				return table.iappend({t1}, t2)
			else
				return t1
			end
		elseif t1 then
			if IsValid(t2) then
				table.insert(t1, t2)
				return t1
			elseif t2 then
				return table.iappend(t1, t2)
			else
				return t1
			end
		else
			return t2
		end
	end
	
	if self:ShouldHaveBrokenDecAttaches() then
		local lc = self:GetNeighbourCorner(SlabNeighbourMask.Left)
		left = appendNbrs(left, lc)
		local rc = self:GetNeighbourCorner(SlabNeighbourMask.Right)
		right = appendNbrs(right, rc)
		
		processNbr(left, SlabNeighbourMask.Left, "Left")
		cleanup(da.Left)
		processNbr(right, SlabNeighbourMask.Right, "Right")
		cleanup(da.Right)
		processNbr(top, SlabNeighbourMask.Top, "Top")
		cleanup(da.Top)
		processNbr(bottom, SlabNeighbourMask.Bottom, "Bottom")
		cleanup(da.Bottom)
	else
		cleanup(da.Left)
		cleanup(da.Right)
	end
	
	self:RefreshColors()
	local decs = self:GetDecorations()
	for i = 1, #(decs or "") do
		DecSetDestroyedEnt(decs[i], decs[i]:GetEntity(), nil, self)
	end
	self:UpdateDecorationsDestroyedState()
	
	return true
end

local function ShouldProcessDecsDestroyedStateForNbrSWO(swo)
	return not swo.is_destroyed and swo.material == "Colonial" and swo.width > 0 and swo.height > 1
end

local function ShouldProcessDecsDestroyedStateForSWO(swo)
	return swo.is_destroyed and swo.material == "Colonial" and swo.width > 0 and swo.height > 1
end

---
--- Updates the destroyed state of decorations attached to a SlabWallObject.
---
--- This function is called when a SlabWallObject is destroyed to update the state of any decorations
--- attached to it. It checks the neighboring wall slabs and windows to determine if the decorations
--- should be updated to a broken state.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:UpdateDecorationsDestroyedState()
	if ShouldProcessDecsDestroyedStateForSWO(self) then
		--colonial slabwallobjs' art has built in friezes at the top edge :|
		local leftOffset = self:GetLeftOffset()
		local rightOffset = self:GetRightOffset()
		local ma = self:GetAngle()
		local side = self.side or slabAngleToDir[ma]
		local isFlipped = side ~= slabAngleToDir[ma]
		local x, y, z = self:GetPosXYZ()
		
		local lns = self:GetNeighbourWallSlab(SlabNeighbourMask.Left)
		local rns = self:GetNeighbourWallSlab(SlabNeighbourMask.Right)
		local topz = z + (self.height - 1) * voxelSizeZ
		local ln, rn
		
		for i = #(lns or ""), 1, -1 do
			local lnn = lns[i]
			if lnn:GetPos():z() >= topz then
				ln = lnn
				break
			end
		end
		
		for i = #(rns or ""), 1, -1 do
			local rnn = rns[i]
			if rnn:GetPos():z() >= topz then
				rn = rnn
				break
			end
		end
		
		local function processWindowNbrs(wn)
			if wn then
				if #wn <= 0 then
					local hisz = wn:GetPos():z()
					if topz <= wn.height * voxelSizeZ + hisz and topz >= hisz then
						return wn
					end
				else
					for i = 1, #wn do
						local hisz = wn[i]:GetPos():z()
						if topz <= wn[i].height * voxelSizeZ + hisz and topz >= hisz then
							return wn[i]
						end
					end
				end
			end
			return nil
		end
		
		local lnIsWindow, rnIsWindow
		if not ln then
			local lw = self:GetNeighbourWindow(SlabNeighbourMask.Left)
			ln = processWindowNbrs(lw)
			ln = ln and ShouldProcessDecsDestroyedStateForNbrSWO(ln) and ln or false
			lnIsWindow = ln and true or false
		end
		
		if not rn then
			local rw = self:GetNeighbourWindow(SlabNeighbourMask.Right)
			rn = processWindowNbrs(rw)
			rn = rn and ShouldProcessDecsDestroyedStateForNbrSWO(rn) and rn or false
			rnIsWindow = rn and true or false
		end
		
		if ln and not ln.is_destroyed then
			local proceed = lnIsWindow or MapGetFirst(self:GetRelativePoint(point(0, -voxelSizeX * (leftOffset - 1), topz - z)), 10, "DestroyableWallDecoration")
			if proceed then
				local att = PlaceObject("Object", {use_self_colors = true})
				self:Attach(att)
				att:ChangeEntity("WallDec_Colonial_Frieze_Body_BrokenDec_R_01")
				att:SetAttachOffset(point(0, voxelSizeX * leftOffset, topz - z))
				att:SetColorization(IsValid(proceed) and proceed or self, "ignore_his_max")
				
				self.destroyed_attaches = self.destroyed_attaches or {Top = {}, Bottom = {}, Left = {}, Right = {}}
				table.insert(self.destroyed_attaches.Left, att)
			end
		end
		
		if rn and not rn.is_destroyed then
			local proceed = rnIsWindow or MapGetFirst(self:GetRelativePoint(point(0, -voxelSizeX * (rightOffset + 1), topz - z)), 10, "DestroyableWallDecoration")
			if proceed then
				local att = PlaceObject("Object", {use_self_colors = true})
				self:Attach(att)
				att:ChangeEntity("WallDec_Colonial_Frieze_Body_BrokenDec_L_01")
				att:SetAttachOffset(point(0, -voxelSizeX * rightOffset, topz - z))
				att:SetColorization(IsValid(proceed) and proceed or self, "ignore_his_max")
				
				self.destroyed_attaches = self.destroyed_attaches or {Top = {}, Bottom = {}, Left = {}, Right = {}}
				table.insert(self.destroyed_attaches.Right, att)
			end
		end
	end
end

---
--- Updates the destroyed state of a RoofPlaneSlab object.
---
--- If the roof_comp property is "Gable", this function delegates to the UpdateDestroyedStateInternal function of the RoofEdgeSlab class.
---
--- Otherwise, this function processes the destroyed state of the RoofPlaneSlab object, including updating the destroyed_attaches table, setting the destroyed entity and flags, and handling diagonal entities.
---
--- @param self RoofPlaneSlab The RoofPlaneSlab object to update.
--- @return boolean True if the RoofPlaneSlab is destroyed, false otherwise.
function RoofPlaneSlab:UpdateDestroyedStateInternal()
	if self.roof_comp == "Gable" then
		--it's a roof edge mascarading as a plane
		return RoofEdgeSlab.UpdateDestroyedStateInternal(self)
	end
	--ROOF
	local mask = self.destroyed_neighbours
	self.destroyed_attaches = self.destroyed_attaches or {Top = false, Bottom = false, Left = false, Right = false}
	local da = self.destroyed_attaches
	local isDestroyed = self.is_destroyed
	
	for i = 0, 3 do
		processSideHelper(self, da, 1 << i, mask)
	end
	
	local a = self:GetAngle()
	local isFlipped = (a == 180 * 60 or a == 270 * 60)
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
		--check for diagonal ents
		local lOrRExist = (da.Left or da.Right)
		local rbPossible = (isFlipped and da.Top or not isFlipped and da.Bottom) and lOrRExist
		local rtPossible = (isFlipped and da.Bottom or not isFlipped and da.Top) and lOrRExist
		if rtPossible or rbPossible then
			if self:GetSeed(100, 97577) >= 50 then
				local side
				if rtPossible and rbPossible then
					if self:GetSeed(100, 7759) >= 50 then
						side = "RT"
					else
						side = "RB"
					end
				elseif rtPossible then
					side = "RT"
				else
					side = "RB"
				end
				
				local e = self:ComposeBrokenEntityName(side)
				if IsValidEntity(e) then
					self:ChangeEntity(e)
					self:ResetVisibilityFlags()
					if side == "RB" and not isFlipped or isFlipped and side == "RT" then
						self:DestroyDestroyedAttach(SlabNeighbourMask.Bottom, self)
						self.diagonal_ent_mask = SlabNeighbourMask.Bottom
					else
						self:DestroyDestroyedAttach(SlabNeighbourMask.Top, self)
						self.diagonal_ent_mask = SlabNeighbourMask.Top
					end
					if da.Left then
						self.diagonal_ent_mask = self.diagonal_ent_mask | SlabNeighbourMask.Left
						self:DestroyDestroyedAttach(SlabNeighbourMask.Left, self)
					else
						self.diagonal_ent_mask = self.diagonal_ent_mask | SlabNeighbourMask.Right
						self:DestroyDestroyedAttach(SlabNeighbourMask.Right, self)
					end
				end
			end
		end
	end
	
	if self.destroyed_entity and self:GetEntity() ~= self.destroyed_entity then
		if IsValidEntity(self.destroyed_entity) then
			self:ChangeEntity(self.destroyed_entity)
			self:ResetVisibilityFlags()
		end
		self:UpdateVariantEntities()
	end
	
	local isMirrored = not isFlipped and (self.destroyed_entity_side & SlabNeighbourMask.Left) ~= 0
							or (isFlipped and (self.destroyed_entity_side & SlabNeighbourMask.Right) ~= 0)
							or not isFlipped and (self.diagonal_ent_mask & SlabNeighbourMask.Right) ~= 0
							or isFlipped and (self.diagonal_ent_mask & SlabNeighbourMask.Left) ~= 0
	
	self:SetMirrored(isMirrored)
	local hasAtLeastOneAttch = false
	
	if da.Right then
		local m = not isMirrored
		if isFlipped then m = not m end
		da.Right:SetMirrored(m)
		self:Attach(da.Right)
		hasAtLeastOneAttch = true
	end
	
	if da.Left then
		local m = isMirrored
		if isFlipped then m = not m end
		da.Left:SetMirrored(m)
		self:Attach(da.Left)
		hasAtLeastOneAttch = true
	end
	
	if da.Top then
		self:Attach(da.Top)
		hasAtLeastOneAttch = true
	end
	
	if da.Bottom then
		self:Attach(da.Bottom)
		hasAtLeastOneAttch = true
	end
	
	if not isDestroyed and not hasAtLeastOneAttch and not self.destroyed_entity then
		--our destroyed state is the same as a non destroyed state
		return false --let updateent do its thing
	end
	
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return true
end

--- Updates the destroyed state of a RoofCorner object.
---
--- This function is responsible for updating the destroyed state of a RoofCorner object. It checks if the object is destroyed, and if so, sets the destroyed entity and flags. It then refreshes the colors and sets the warped state of the object.
---
--- @param self RoofCorner The RoofCorner object to update.
--- @return boolean Whether the object is destroyed.
function RoofCorner:UpdateDestroyedStateInternal()
	local isDestroyed = self.is_destroyed
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
	end
	
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return isDestroyed
end

--- Updates the destroyed state of a RoomCorner object.
---
--- This function is responsible for updating the destroyed state of a RoomCorner object. It checks if the object is destroyed, and if so, sets the destroyed entity and flags. It then updates the decorations destroyed state, refreshes the colors, and sets the warped state of the object.
---
--- @param self RoomCorner The RoomCorner object to update.
--- @return boolean Whether the object is destroyed.
function RoomCorner:UpdateDestroyedStateInternal()
	local isDestroyed = self.is_destroyed
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
	end
	
	self:UpdateDecorationsDestroyedState()
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return isDestroyed
end

--- Updates the destroyed state of a WallSlab object.
---
--- This function is responsible for updating the destroyed state of a WallSlab object. It checks the destroyed neighbors mask and the destroyed attaches state, and sets the destroyed entity and flags accordingly. It also handles the case where the WallSlab is part of a diagonal entity, and updates the variant entities if necessary. Finally, it refreshes the colors and sets the warped state of the object.
---
--- @param self WallSlab The WallSlab object to update.
--- @return boolean Whether the object is destroyed.
function WallSlab:UpdateDestroyedStateInternal()
	--WALL
	local mask = self.destroyed_neighbours
	self.destroyed_attaches = self.destroyed_attaches or {Top = false, Bottom = false, Left = false, Right = false}
	local da = self.destroyed_attaches
	local isDestroyed = self.is_destroyed
	
	for i = 0, 3 do
		processSideHelper(self, da, 1 << i, mask)
	end
	
	if isDestroyed then
		local odem = self.diagonal_ent_mask
		self:SetDestroyedEntityAndFlags()
		if da.Top and (da.Left or da.Right) then
			--maybe use diagonal ent?
			if not IsKindOf(self, "RoofWallSlab") and not self.always_visible and self:GetSeed(100, 97577) >= 50 then 
				--roof walls stack, so rolls there are weird, all stacked should roll and at least one success means success, just disable for sanity
				--always_visible check is a hacky way to know whether we are part of a vent window
				local e = self:ComposeBrokenEntityName("RB")
				if IsValidEntity(e) then
					self:ChangeEntity(e)
					self:ResetVisibilityFlags()
					self:DestroyDestroyedAttach(SlabNeighbourMask.Top, self)
					if da.Left then
						self.diagonal_ent_mask = (SlabNeighbourMask.Left | SlabNeighbourMask.Top)
						self:DestroyDestroyedAttach(SlabNeighbourMask.Left, self)
					else
						self.diagonal_ent_mask = (SlabNeighbourMask.Right | SlabNeighbourMask.Top)
						self:DestroyDestroyedAttach(SlabNeighbourMask.Right, self)
					end
				end
			end
		end
		if odem ~= self.diagonal_ent_mask then
			self:UpdateVariantEntities()
		end
	end
	
	if self.destroyed_entity and self:GetEntity() ~= self.destroyed_entity then
		if IsValidEntity(self.destroyed_entity) then
			self:ChangeEntity(self.destroyed_entity)
			self:ResetVisibilityFlags()
		end
		self:UpdateVariantEntities()
	end
	
	local isMirrored = (self.destroyed_entity_side & SlabNeighbourMask.Left) ~= 0
							or (self.diagonal_ent_mask & SlabNeighbourMask.Right) ~= 0
	self:SetMirrored(isMirrored)
	if self.variant_objects then
		--these are rotated 180 so always mirror
		local mi = (self.destroyed_entity_side & (SlabNeighbourMask.Left | SlabNeighbourMask.Right)) ~= 0
		self.variant_objects[1]:SetMirrored(mi)
		local o = self.variant_objects[2]
		if IsValid(o) then
			o:SetMirrored(not mi)
		end
	end
	local hasAtLeastOneAttch = false
	
	if da.Right then
		da.Right:SetMirrored(true and not isMirrored)
		self:Attach(da.Right)
		hasAtLeastOneAttch = true
	end
	
	if da.Left then
		da.Left:SetMirrored(isMirrored)
		self:Attach(da.Left)
		hasAtLeastOneAttch = true
	end
	
	if da.Top then
		self:Attach(da.Top)
		hasAtLeastOneAttch = true
	end
	
	if da.Bottom then
		self:Attach(da.Bottom)
		hasAtLeastOneAttch = true
	end
	
	if self.diagonal_ent_mask ~= 0 then
		local o1 = self.variant_objects and self.variant_objects[1]
		local o2 = self.variant_objects and self.variant_objects[2]
		if IsValid(o1) then
			o1:SetMirrored(true)
		end
		if IsValid(o2) then
			o2:SetMirrored(false)
		end
	end
	
	self:UpdateDecorationsDestroyedState()
	
	if not isDestroyed and not hasAtLeastOneAttch and not self.destroyed_entity then
		--our destroyed state is the same as a non destroyed state
		return false --let updateent do its thing
	end
	
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return true
end

local horizontalDecorationNames = {
	"Frieze",
	"Socle",
	"FenceTop",
}

local function IsHorizontalDecoration(ent_name, obj)
	for i = 1, #horizontalDecorationNames do
		local str = horizontalDecorationNames[i]
		if string.find(ent_name, str) then
			local my_axis = obj:GetAxis()
			if my_axis ~= axis_z and my_axis ~= -axis_z then
				--named as such but rotated
				return false
			end
			return true
		end
	end
	
	return false
end

---
--- Composes the name for a broken decoration attachment entity.
---
--- @param self table The Destroyable object.
--- @param e string The original decoration entity name.
--- @param sc string The side of the decoration (e.g. "Left", "Right", "Top", "Bottom").
--- @param var number The variant index of the decoration.
--- @param t string (optional) The type of the broken decoration attachment (default is "BrokenDec").
--- @param suppressError boolean (optional) Whether to suppress error messages.
--- @return string The composed name for the broken decoration attachment entity.
function ComposeBrokenDecorationAttachName(self, e, sc, var, t, suppressError)
	assert(string.find(e, "%d+", -2), e)
	t = t or "BrokenDec"
	
	if not var then
		local varStr = string.sub(e, -2)
		var = tonumber(varStr) or 1
	end
	
	local be = string.sub(e, 1, -3)
	local ret = string.format("%s%s_%s_%s", be, t, sc, var < 10 and string.format("0%d", var) or tostring(var))
	if IsValidEntity(ret) then
		return ret
	else
		local err
		if not slab_missing_entity_white_list[e] and not slab_missing_entity_white_list[ret] then
			err = "ComposeBrokenDecorationAttachName " .. ret .. " is invalid ent. " .. " Original ent " .. e .. ". " .. tostring(self.handle)
			if not suppressError then
				print("once", err)
			end
		end
		return "InvisibleObject", err
	end
end

local epsilon = 10 * 60
---
--- Updates the destroyed state of decorations attached to a slab.
---
--- @param self table The Slab object.
--- @return nil
function Slab:UpdateDecorationsDestroyedState()
	local decs = self:GetDecorations()
	local da = self.destroyed_attaches
	local isDestroyed = self.is_destroyed
	local a = self:GetAngle()
	local mask = self.destroyed_neighbours
	local ds = self.destroyed_entity_side
	local ln = self:GetNeighbour(SlabNeighbourMask.Left)
	local rn = self:GetNeighbour(SlabNeighbourMask.Right)
	local tn = self:GetNeighbour(SlabNeighbourMask.Top)
	local bn = self:GetNeighbour(SlabNeighbourMask.Bottom)
	--local diagl = (self.diagonal_ent_mask & SlabNeighbourMask.Left) ~= 0
	--local diagr = (self.diagonal_ent_mask & SlabNeighbourMask.Right) ~= 0
	local diagt = (self.diagonal_ent_mask & SlabNeighbourMask.Top) ~= 0
	
	for i = 1, #(decs or "") do
		local d = decs[i]
		local e = d:GetEntity()
		local na = 1
		local oe = rawget(d, "orig_decoration_ent") or d:GetEntity()
		local isHorizontal = IsHorizontalDecoration(oe, d)
		local isTop = string.find(oe, "_Top")
		local isBot = string.find(oe, "_Bottom")
		local varStr = string.sub(oe, -2)
		local var = tonumber(varStr) or 1
		
		local forceNoT = isBot and var > 1
		local forceNoB = isTop and var > 1
		
		local function AddAttch(d, oe, sc)
			local ae = ComposeBrokenDecorationAttachName(self, oe, sc, var)
			if not IsValidEntity(ae) then
				print("once", "Failed to find entity for broken attach for decoration: " .. ae)
				return
			end
			
			local att
			
			repeat
				att = d:GetAttach(na) or PlaceObject("Object")
				na = na + 1
			until not rawget(att, "editor_ignore")
			
			att:ChangeEntity(ae)
			d:Attach(att)
			att:SetColorization(d, "ignore_his_max")
		end
		
		if not isDestroyed then
			--dec is destroyed, but we aren't, maybe repair
			d:DestroyAttaches()
			if not forceNoB and not isHorizontal and (ds & SlabNeighbourMask.Top) ~= 0 and e ~= "InvisibleObject" then
				local ne, err = ComposeBrokenDecorationAttachName(self, oe, "B", var, "Broken", "suppressError")
				if ne == "InvisibleObject" then
					ne = ComposeBrokenDecorationAttachName(self, oe, "B")
					if ne == "InvisibleObject" then
						print(err)
					end
				end
				DecSetDestroyedEnt(d, oe, ne, self)
			elseif not forceNoT and not isHorizontal and (ds & SlabNeighbourMask.Bottom) ~= 0 and e ~= "InvisibleObject" then
				local ne, err = ComposeBrokenDecorationAttachName(self, oe, "T", var, "Broken", "suppressError")
				if ne == "InvisibleObject" then
					ne = ComposeBrokenDecorationAttachName(self, oe, "T")
					if ne == "InvisibleObject" then
						print(err)
					end
				end
				DecSetDestroyedEnt(d, oe, ne, self)
			elseif e ~= oe then
				DecRestoreOrigEnt(d, e, self)
			end
			
		elseif isDestroyed then
			DecSetDestroyedEnt(d, e, nil, self)
			local decA = d:GetAngle()
			local x, y, z = d:GetPosXYZ()
			z = z or terrain.GetHeight(d:GetPos())
			local cls = "DestroyableWallDecoration"
			if isHorizontal then
				if (ln and (mask & SlabNeighbourMask.Left) == 0) or da and da.Left then
					local sc = abs(decA - a) < epsilon and "R" or "L" --art is flipped
					AddAttch(d, oe, sc)
				end
				if (rn and (mask & SlabNeighbourMask.Right) == 0) or da and da.Right then
					local sc = abs(decA - a) < epsilon and "L" or "R" --art is flipped
					AddAttch(d, oe, sc)
				end
			else --vertical
				local function filter(o, test_str)
					local e = o:GetEntity()
					return e == o.class or string.find(e, test_str)
				end
				
				if (not forceNoT and not isTop) and (da and da.Top or diagt or (tn and (tn.destroyed_entity_side & SlabNeighbourMask.Bottom) == 0 and (mask & SlabNeighbourMask.Top) == 0)) then
					--check for a dec on top
					local nd = MapGetFirst(x, y, z + voxelSizeZ, 0, cls, filter, "Broken_B")
					if nd and nd:GetEntity() ~= "InvisibleObject" then
						AddAttch(d, oe, "T")
					end
				end
				if not forceNoB and (da and da.Bottom or (bn and (bn.destroyed_entity_side & SlabNeighbourMask.Top) == 0 and (mask & SlabNeighbourMask.Bottom) == 0)) then
					local nd = MapGetFirst(x, y, z - voxelSizeZ, 0, cls, filter, "Broken_T")
					if nd and nd:GetEntity() ~= "InvisibleObject" then
						AddAttch(d, oe, "B")
					end
				end
			end
		end
		
		while d:GetAttach(na) do
			DoneObject(d:GetAttach(na))
		end
	end
end

--- Returns the corner index of the current DestroyableFloorSlab.
-- This function is used to determine the position of the current slab within a larger grid of slabs.
-- @return The corner index of the current slab, which can be used to determine its position.
function DestroyableFloorSlab:GetNeighbourCorner()
end

---
--- Updates the destroyed state of a DestroyableFloorSlab.
--- This function is responsible for handling the visual representation of a destroyed slab, including attaching any necessary decorations or diagonal entities.
--- @param self DestroyableFloorSlab The slab being updated.
--- @return boolean Whether the slab's state was successfully updated.
---
function DestroyableFloorSlab:UpdateDestroyedStateInternal()
	--FLOOR
	local mask = self.destroyed_neighbours
	self.destroyed_attaches = self.destroyed_attaches or {Top = false, Bottom = false, Left = false, Right = false}
	local da = self.destroyed_attaches
	local isDestroyed = self.is_destroyed
	
	if isDestroyed then
		self:SetDestroyedEntityAndFlags()
		self:SetAngle(0)
	end
	
	for i = 0, 3 do
		processSideHelper(self, da, 1 << i, mask)
	end
	
	local isFlipped = false
	if isDestroyed then
		--check for diagonal ents
		local lOrRExist = da.Left or da.Right
		local rbPossible = da.Bottom and lOrRExist
		local rtPossible = da.Top and lOrRExist
		if rtPossible or rbPossible then
			if self:GetSeed(100, 97577) >= 50 then
				local e = self:ComposeBrokenEntityName("RB")
				if IsValidEntity(e) then
					if rtPossible and rbPossible then
						if self:GetSeed(100, 7759) < 50 then
							isFlipped = true
						end
					elseif rbPossible then
						isFlipped = true
					end
					
					self:ChangeEntity(e)
					self:ResetVisibilityFlags()
					if isFlipped then
						self:DestroyDestroyedAttach(SlabNeighbourMask.Bottom, self)
						self.diagonal_ent_mask = SlabNeighbourMask.Bottom
						self:SetAngle(180*60)
					else
						self:DestroyDestroyedAttach(SlabNeighbourMask.Top, self)
						self.diagonal_ent_mask = SlabNeighbourMask.Top
					end
					if da.Left then
						self.diagonal_ent_mask = self.diagonal_ent_mask | SlabNeighbourMask.Left
						self:DestroyDestroyedAttach(SlabNeighbourMask.Left, self)
					else
						self.diagonal_ent_mask = self.diagonal_ent_mask | SlabNeighbourMask.Right
						self:DestroyDestroyedAttach(SlabNeighbourMask.Right, self)
					end
				end
			end
		end
	elseif self.destroyed_entity and self:GetEntity() ~= self.destroyed_entity then
		if IsValidEntity(self.destroyed_entity) then
			self:ChangeEntity(self.destroyed_entity)
			self:ResetVisibilityFlags()
		end
		if (self.destroyed_entity_side & SlabNeighbourMask.Top) ~= 0 then
			self:SetAngle(180*60)
		else
			self:SetAngle(0)
		end
	end
	
	local isMirrored = (self.destroyed_entity_side & SlabNeighbourMask.Left) ~= 0
								or not isFlipped and (self.diagonal_ent_mask & SlabNeighbourMask.Right) ~= 0
								or isFlipped and (self.diagonal_ent_mask & SlabNeighbourMask.Left) ~= 0
								
	self:SetMirrored(isMirrored)
	local hasAtLeastOneAttch = false
	
	if da.Right then
		local m = not isMirrored
		if isFlipped then m = not m end
		da.Right:SetMirrored(m)
		self:Attach(da.Right)
		hasAtLeastOneAttch = true
	end
	
	if da.Left then
		local m = isMirrored
		if isFlipped then m = not m end
		da.Left:SetMirrored(m)
		self:Attach(da.Left)
		hasAtLeastOneAttch = true
	end
	
	if da.Top then
		self:Attach(da.Top)
		if isFlipped then da.Top:SetAttachAngle(180*60) end
		hasAtLeastOneAttch = true
	end
	
	if da.Bottom then
		self:Attach(da.Bottom)
		if not isFlipped then da.Bottom:SetAttachAngle(180*60) end
		hasAtLeastOneAttch = true
	end
	
	if not isDestroyed and not hasAtLeastOneAttch and not self.destroyed_entity then
		--our destroyed state is the same as a non destroyed state
		return false --let updateent do its thing
	end
	
	self:RefreshColors()
	self:SetWarped(self:GetWarped())
	
	return true
end

---
--- Determines if the current slab is a structural slab.
---
--- A slab is considered a structural slab if it is invulnerable or if the `force_structural` flag is set.
---
--- @param self Slab The slab instance.
--- @return boolean True if the slab is a structural slab, false otherwise.
function Slab:IsStructuralSlab(r)
	return self:IsInvulnerable() or self.force_structural
end

---
--- Determines if the current slab is a structural slab.
---
--- A slab is considered a structural slab if it is invulnerable or if the `force_structural` flag is set.
---
--- @param self Slab The slab instance.
--- @return boolean True if the slab is a structural slab, false otherwise.
function Slab:IsStructuralRow(r)
	return false
end

---
--- Gets the neighbouring slabs around the current slab.
---
--- @param self Slab The slab instance.
--- @return table A table of neighbouring slab instances.
function Slab:GetNeighbours()
end

function Slab:GetNeighbour()
end

function Slab:GetNeighboursAroundCorner()
end

function Slab:GetDecorationQueryBox()
end

function Slab:GetDecorations()
end

function Slab:GetNeighbourWindow()
end

function Slab:GetStairNeighbours()
end

---
--- Clears the destroyed slab attach subvariants for the given side flag and attach position.
---
--- If there are any destroyed slab attach subvariants, this function will remove them from the `da_subvaraints` table. If the `da_subvaraints` table becomes empty after the removal, it will be set to `nil`.
---
--- @param self Slab The slab instance.
--- @param sideFlag number The side flag indicating the side of the slab.
--- @param [attPos] point The attach position, or `point30` if not provided.
---
function Slab:ClearDaSubvariants(sideFlag, attPos)
	if self.da_subvaraints then
		attPos = attPos or point30
		local id = GetDestroyedSlabAttachId(sideFlag, attPos)	
		self.da_subvaraints[id] = nil
		if not next(self.da_subvaraints) then
			self.da_subvaraints = nil
		end
	end
end

---
--- Destroys the destroyed slab attachments for the given side flag.
---
--- This function will remove any destroyed slab attachments from the `destroyed_attaches` table for the given side flag. If the `destroyed_attaches` table becomes empty after the removal, it will be set to `nil`.
---
--- @param self Slab The slab instance.
--- @param sideFlag number The side flag indicating the side of the slab.
---
function Slab:DestroyDestroyedAttach(sideFlag)
	local ss = maskToString[sideFlag]
	local att = self.destroyed_attaches and self.destroyed_attaches[ss]
	if att then
		DoneObject(att)
		self.destroyed_attaches[ss] = false
	end
	self:ClearDaSubvariants(sideFlag)
end

---
--- Destroys the destroyed slab attachments for the given side flag on all RoofWallSlab objects in the scene.
---
--- This function will remove any destroyed slab attachments from the `destroyed_attaches` table for the given side flag on all RoofWallSlab objects. If the `destroyed_attaches` table becomes empty after the removal, it will be set to `nil`.
---
--- @param sideFlag number The side flag indicating the side of the slab.
---
function RoofWallSlab:DestroyDestroyedAttach(sideFlag)
	MapForEach(self, 0, "RoofWallSlab", nil, const.efVisible, function(o, sideFlag, self)
		if (sideFlag & 12) == 0 or o:GetAngle() == self:GetAngle() then
			Slab.DestroyDestroyedAttach(o, sideFlag)
		else
			local osf = maskToOppositeMask[sideFlag]
			Slab.DestroyDestroyedAttach(o, osf)
		end
	end, sideFlag, self)
end

---
--- Returns a point30 representing the default destroyed attachment offset.
---
--- This function is used to get the default position for destroyed attachments when no specific offset is provided.
---
--- @return point The default destroyed attachment offset.
---
function Slab:GetDestroyedAttachOffset()
	return point30
end

---
--- Gets the default destroyed attachment offset for the given side flag and attachment number.
---
--- This function calculates the default position for a destroyed attachment based on the side flag and the attachment number. It takes into account the position of the attachment and the size of the slab to determine the appropriate offset.
---
--- @param sideFlag number The side flag indicating the side of the slab.
--- @param nbr number The attachment number.
--- @param mp point The position of the slab. Defaults to the slab's position if not provided.
--- @return point, point The local and global positions of the destroyed attachment offset.
---
function SlabWallObject:GetDestroyedAttachOffset(sideFlag, nbr, mp)
	mp = mp or self:GetPos()
	local hp = nbr:GetPos()
	local dp = mp - hp
	local dx, dy, dz = dp:xyz()
	local attPos
	
	if (sideFlag & 12) ~= 0 then --is left or right
		local offs = IsKindOf(nbr, "WallSlab") and voxelSizeX or halfVoxelSizeX
		attPos = hp + point(sign(dx) * offs, sign(dy) * offs, 0)
	else
		attPos = hp + point(0, 0, sign(dz) * voxelSizeZ)
	end

	local localAttPos = self:GetLocalPoint(attPos)
	return localAttPos, attPos
end

---
--- Destroys the destroyed attachments associated with the SlabWallObject.
---
--- This function is responsible for removing and destroying any destroyed attachments that are associated with the SlabWallObject. It uses the `GetDestroyedAttachOffset` function to determine the position of the destroyed attachments, and then iterates through the list of destroyed attachments for the specified side flag, removing and destroying any that match the calculated position.
---
--- @param sideFlag number The side flag indicating the side of the slab.
--- @param nbr table The attachment object.
---
function SlabWallObject:DestroyDestroyedAttach(sideFlag, nbr)
	local da = self.destroyed_attaches
	if not da then return end
	local attPos = self:GetDestroyedAttachOffset(sideFlag, nbr)
	self:ClearDaSubvariants(sideFlag, attPos)
	
	local atts = da[maskToString[sideFlag] ]
	
	for i = #(atts or ""), 1, -1 do
		local a = atts[i]
		if not IsValid(a) then
			--malicious people go around and kill attaches, so this can be dead at any time;
			table.remove(atts, i)
			print(string.format("Found invalid attch h[%s] class[%s] i[%d] side[%s]", tostring(self.handle), self.class, i, maskToString[sideFlag]))
		elseif (a.offset or a:GetAttachOffset()) == attPos and IsKindOf(a, DestroyedAttachClass) then --other class attaches never get destroyed..
			table.remove(atts, i)
			DoneObject(a)
			if #atts <= 0 then
				local canClear = true
				for side, satts in pairs(da) do
					if #satts > 0 then
						canClear = false
						break
					end
				end
				if canClear then
					self.destroyed_attaches = false
				end
			end
			return
		end
	end
end

---
--- Checks if the Slab object is grounded on the terrain.
---
--- This function checks the position of the Slab object and compares it to the height of the terrain at the same horizontal position. If the Slab's Z coordinate is less than or equal to the terrain height, or the difference between the Slab's Z coordinate and the terrain height is less than the voxel size in the Z axis, the function returns `true` indicating that the Slab is grounded. Otherwise, it returns `false`.
---
--- @return boolean true if the Slab is grounded on the terrain, false otherwise
function Slab:IsGrounded()
	local x, y, z = self:GetPosXYZ()
	local tz = terrain.GetHeight(x, y)
	if z <= tz or abs(z - tz) < voxelSizeZ then
		return true --on ground
	end
	return false
end

---
--- Reports a missing damaged entity.
---
--- This function is used to report a missing damaged entity. It calls the `ReportMissingDestructionEntity` function with the provided `ent` parameter and a message indicating that the damaged entity was not found.
---
--- @param ent string The name or identifier of the missing damaged entity.
---
function Slab:ReportMissingDamagedEntity(ent)
	self:ReportMissingDestructionEntity(ent, "Failed to find damaged entity " .. ent)
end

---
--- Reports a missing broken entity.
---
--- This function is used to report a missing broken entity. It calls the `ReportMissingDestructionEntity` function with the provided `ent` parameter and a message indicating that the broken entity was not found.
---
--- @param ent string The name or identifier of the missing broken entity.
---
function Slab:ReportMissingBrokenEntity(ent)
	self:ReportMissingDestructionEntity(ent, "Failed to find broken entity " .. ent)
end

---
--- Reports a missing broken dec interior attach entity.
---
--- This function is used to report a missing broken dec interior attach entity. It calls the `ReportMissingDestructionEntity` function with the provided `ent` parameter and a message indicating that the broken dec interior attach entity was not found.
---
--- @param ent string The name or identifier of the missing broken dec interior attach entity.
---
function Slab:ReportMissingBrokenDecInteriorAttach(ent)
	self:ReportMissingDestructionEntity(ent, "Failed to find broken dec interior attach entity " .. ent)
end

---
--- Reports a missing broken dec entity.
---
--- This function is used to report a missing broken dec entity. It calls the `ReportMissingDestructionEntity` function with the provided `ent` parameter and a message indicating that the broken dec entity was not found.
---
--- @param ent string The name or identifier of the missing broken dec entity.
---
function Slab:ReportMissingBrokenDec(ent)
	self:ReportMissingDestructionEntity(ent, "Failed to find broken dec entity " .. ent)
end

---
--- Reports a missing destruction entity.
---
--- This function is used to report a missing destruction entity, such as a damaged or broken entity. It prints a message to the console indicating the class of the entity, the map name, and the provided error message.
---
--- If the entity has been added to the `slab_missing_entity_white_list`, the message will not be printed again.
---
--- @param ent string The name or identifier of the missing destruction entity.
--- @param msg string The error message to include in the report.
---
function Slab:ReportMissingDestructionEntity(ent, msg)
	if not slab_missing_entity_white_list[ent] then
		print(string.format("[%s][%s][%s] %s", tostring(rawget(self, "handle")), self.class, GetMapName(), msg))
		slab_missing_entity_white_list[ent] = true
	end
end

wallSidewaysOffsets = {
	North = { x = 1, y = 0 },
	South = { x = -1, y = 0 },
	East = { x = 0, y = 1 },
	West = { x = 0, y = -1 },
}

---
--- Gets the left and right neighbours of the RoofEdgeSlab.
---
--- This function retrieves the left and right neighbours of the RoofEdgeSlab by calling the `GetNeighbour` function with the `SlabNeighbourMask.Left` and `SlabNeighbourMask.Right` flags, respectively.
---
--- @return table, table The left and right neighbours of the RoofEdgeSlab, or `nil` if no neighbours are found.
---
function RoofEdgeSlab:GetNeighbours()
	return self:GetNeighbour(SlabNeighbourMask.Left), self:GetNeighbour(SlabNeighbourMask.Right)
end

local function RoofEdgeSlab_GetNeighbour(self, sideFlag, corner)
	if self.roof_comp == "RakeGable" then return end
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	local pt
	local s = slabAngleToDir[self:GetAngle()] --for some reason .side is bogus for roofedgeslabs
	local xstep, ystep = voxelSizeX, voxelSizeY
	if corner then
		xstep, ystep = xstep / 2, ystep / 2
	end
	
	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		pt = point(x + offs.x * xstep, y + offs.y * ystep)
	elseif sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		pt = point(x - offs.x * xstep, y - offs.y * ystep)
	else
		return false
	end
	
	local room = self.room
	local oz = z
	local checkAngle
	if self.roof_comp ~= "Gable" then
		oz = room and room:GetRoofZAndDir(pt) or z
		oz = oz == const.InvalidZ and z or oz
	else -- == "Gable"
		checkAngle = self:GetAngle() --if different gables are crossing eachother in 90 degree fashion, check the angle to make sure we are getting the nbr that is aligned the same as us and not the one perpendicular to us.
	end

	local mirrored = self:GetMirrored()
	if not corner then
		local cls = self.class
		return MapGetFirst(pt:x(), pt:y(), oz, 0, cls, nil, const.efVisible, 
							function(o, mirrored, angle) 
								return o:GetMirrored() == mirrored and (not angle or angle == o:GetAngle()) 
							end, mirrored, checkAngle)
					or MapGetFirst(self, 0, cls, nil, const.efVisible, function(o, self) return o ~= self end, self)
					or MapGetFirst(pt:x(), pt:y(), oz, 0, cls, nil, const.efVisible)
	else
		local cls = "RoofCorner"
		return MapGetFirst(pt:x(), pt:y(), oz, 0, cls, nil, const.efVisible)
	end
end

---
--- Returns the RoofEdgeSlab neighbor at the specified side of the current RoofEdgeSlab.
---
--- @param sideFlag number The side flag indicating which neighbor to retrieve. Can be `SlabNeighbourMask.Left` or `SlabNeighbourMask.Right`.
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab, or `false` if no neighbor was found.
function RoofEdgeSlab:GetNeighbourCorner(sideFlag)
	return RoofEdgeSlab_GetNeighbour(self, sideFlag, "corner")
end

---
--- Returns the RoofEdgeSlab neighbor at the specified side of the current RoofEdgeSlab.
---
--- @param sideFlag number The side flag indicating which neighbor to retrieve. Can be `SlabNeighbourMask.Left` or `SlabNeighbourMask.Right`.
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab, or `false` if no neighbor was found.
function RoofEdgeSlab:GetNeighbour(sideFlag)
	return RoofEdgeSlab_GetNeighbour(self, sideFlag)
end

cornerAngleToSidewaysOffsets = {
	[0] = { x = 0, y = -1 },
	[180 * 60] = { x = 0, y = 1 },
	[270 * 60] = { x = 1, y = 0 },
	[90 * 60] = { x = -1, y = 0 },
}

---
--- Returns the RoofEdgeSlab neighbors on the left and right sides of the current RoofCorner.
---
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab on the left side, or `false` if no neighbor was found.
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab on the right side, or `false` if no neighbor was found.
function RoofCorner:GetNeighbours()
	return self:GetNeighbourEdge(SlabNeighbourMask.Left),
			self:GetNeighbourEdge(SlabNeighbourMask.Right)
end

---
--- Returns the RoofEdgeSlab neighbor at the specified side of the current RoofCorner.
---
--- @param sideFlag number The side flag indicating which neighbor to retrieve. Can be `SlabNeighbourMask.Left` or `SlabNeighbourMask.Right`.
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab, or `false` if no neighbor was found.
function RoofCorner:GetNeighbour(...)
	return self:GetNeighbourEdge(...)
end

---
--- Returns the RoofEdgeSlab neighbor at the specified side of the current RoofCorner.
---
--- @param sideFlag number The side flag indicating which neighbor to retrieve. Can be `SlabNeighbourMask.Left` or `SlabNeighbourMask.Right`.
--- @return RoofEdgeSlab|boolean The neighbor RoofEdgeSlab, or `false` if no neighbor was found.
function RoofCorner:GetNeighbourEdge(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	local pt
	local xstep, ystep = voxelSizeX / 2, voxelSizeY / 2
	local a = self:GetAngle()
	local offs = cornerAngleToSidewaysOffsets[a]
	local m = self:GetMirrored()
	
	if sideFlag == SlabNeighbourMask.Left then
		pt = point(x + offs.y * xstep, y + offs.x * ystep)
	elseif sideFlag == SlabNeighbourMask.Right then
		local mm = (m and -1 or 1)
		pt = point(x - offs.x * xstep * mm, y + offs.y * ystep * mm)
	else
		return false
	end

	return MapGetFirst(pt, 1, "RoofEdgeSlab", nil, const.efVisible)
end

---
--- Determines if the RoofPlaneSlab is a structural slab.
---
--- A RoofPlaneSlab is considered structural if it is invulnerable or has the `force_structural` flag set.
---
--- @return boolean True if the RoofPlaneSlab is structural, false otherwise.
function RoofPlaneSlab:IsStructuralSlab()
	return self:IsInvulnerable() or self.force_structural
end

---
--- Determines if the RoofPlaneSlab is part of a structural row.
---
--- This function always returns `false`, as the RoofPlaneSlab is not considered a structural slab.
---
--- @return boolean Always returns `false`.
function RoofPlaneSlab:IsStructuralRow(sideFlag)
	return false
end

---
--- Returns the RoofEdgeSlab or RoofCorner neighbor at the specified side of the current RoofPlaneSlab.
---
--- @param sideFlag number The side flag indicating which neighbor to retrieve. Can be `SlabNeighbourMask.Left`, `SlabNeighbourMask.Right`, `SlabNeighbourMask.Top`, or `SlabNeighbourMask.Bottom`.
--- @param corner boolean If true, the function will return a RoofCorner neighbor instead of a RoofEdgeSlab.
--- @return RoofEdgeSlab|RoofCorner|boolean The neighbor RoofEdgeSlab or RoofCorner, or `false` if no neighbor was found.
function RoofPlaneSlab:GetNeighbourEdge(sideFlag, corner)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	local a = self:GetAngle()
	local flipped = a % (180 * 60) ~= 0
	local pt
	
	if not flipped and sideFlag == SlabNeighbourMask.Left
		or flipped and sideFlag == SlabNeighbourMask.Bottom then
		if not corner then
			pt = point(x, y + halfVoxelSizeY)
		else
			pt = point(x - halfVoxelSizeX, y + halfVoxelSizeY)
		end
	elseif not flipped and sideFlag == SlabNeighbourMask.Right 
			or flipped and sideFlag == SlabNeighbourMask.Top then
		if not corner then
			pt = point(x, y - halfVoxelSizeY)
		else
			pt = point(x + halfVoxelSizeX, y - halfVoxelSizeY)
		end
	elseif not flipped and sideFlag == SlabNeighbourMask.Top
			or flipped and sideFlag == SlabNeighbourMask.Left then
		if not corner then
			pt = point(x - halfVoxelSizeX, y)
		else
			pt = point(x - halfVoxelSizeX, y - halfVoxelSizeY)
		end
	elseif not flipped and sideFlag == SlabNeighbourMask.Bottom
			or flipped and sideFlag == SlabNeighbourMask.Right then
		if not corner then
			pt = point(x + halfVoxelSizeX, y)
		else
			pt = point(x + halfVoxelSizeX, y + halfVoxelSizeY)
		end
	else
		return false
	end
	-------------
	local room = self.room
	if room then
		local rb = room.roof_box
		if rb then
			local delta = rb:min() - pt
			if abs(delta:x()) >= voxelSizeX and abs(delta:y()) >= voxelSizeY then
				delta = rb:max() - pt
				if abs(delta:x()) >= voxelSizeX and abs(delta:y()) >= voxelSizeY then
					--2 far from edge
					return false
				end
			end
		end
	end
	
	local oz = room and room:GetRoofZAndDir(pt) or z
	oz = oz == const.InvalidZ and z or oz
	local anotherZWhereEdgesMayPreside = room:AdjustGableCapZ(oz)
	local cp = self:GetClipPlane()
	local cls = not corner and "RoofEdgeSlab" or "RoofCorner"
	if cp ~= 0 and (sideFlag == SlabNeighbourMask.Right or sideFlag == SlabNeighbourMask.Left) then
		local function filter(o, cp)
			return o:GetClipPlane() == cp
		end
		return MapGetFirst(pt:x(), pt:y(), oz, 0, cls, nil, const.efVisible, filter, cp)
				or MapGetFirst(pt:x(), pt:y(), anotherZWhereEdgesMayPreside, 0, cls, nil, const.efVisible, filter, cp)
				or MapGetFirst(pt:x(), pt:y(), anotherZWhereEdgesMayPreside + 1, 0, cls, nil, const.efVisible, filter, cp) --old round error could cause these to be offset
	else				
		return MapGetFirst(pt:x(), pt:y(), oz, 0, cls, nil, const.efVisible)
				or MapGetFirst(pt:x(), pt:y(), anotherZWhereEdgesMayPreside, 0, cls, nil, const.efVisible)
				or MapGetFirst(pt:x(), pt:y(), anotherZWhereEdgesMayPreside + 1, 0, cls, nil, const.efVisible)
	end
end

---
--- Gets the wall slab neighbor of a roof plane slab in the specified direction.
---
--- @param sideFlag number The direction to check for a wall slab neighbor. Must be one of the `SlabNeighbourMask` constants.
--- @return WallSlab|boolean The wall slab neighbor, or `false` if none is found.
function RoofPlaneSlab:GetNeighbourWallSlab(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	z = snapZ(z)
	local nz = snapZ(z - 1) --look on the tile below as well since these guys are bent
	local a = self:GetAngle()
	local flipped = a % (180 * 60) ~= 0
	
	if not flipped and sideFlag == SlabNeighbourMask.Left
		or flipped and sideFlag == SlabNeighbourMask.Bottom then
		return MapGetFirst(x, y + halfVoxelSizeY, z, 0, "WallSlab", nil, const.efVisible) or MapGetFirst(x, y + halfVoxelSizeY, nz, 0, "WallSlab", nil, const.efVisible)
	elseif not flipped and sideFlag == SlabNeighbourMask.Right 
			or flipped and sideFlag == SlabNeighbourMask.Top then
		return MapGetFirst(x, y - halfVoxelSizeY, z, 0, "WallSlab", nil, const.efVisible) or MapGetFirst(x, y - halfVoxelSizeY, nz, 0, "WallSlab", nil, const.efVisible)
	elseif not flipped and sideFlag == SlabNeighbourMask.Top
			or flipped and sideFlag == SlabNeighbourMask.Left then
		return MapGetFirst(x - halfVoxelSizeX, y, z, 0, "WallSlab", nil, const.efVisible) or MapGetFirst(x - halfVoxelSizeX, y, nz, 0, "WallSlab", nil, const.efVisible)
	elseif not flipped and sideFlag == SlabNeighbourMask.Bottom
			or flipped and sideFlag == SlabNeighbourMask.Right then
		return MapGetFirst(x + halfVoxelSizeX, y, z, 0, "WallSlab", nil, const.efVisible) or MapGetFirst(x + halfVoxelSizeX, y, nz, 0, "WallSlab", nil, const.efVisible)
	end
	
	return false
end

---
--- Gets the roof plane slab neighbor in the specified direction.
---
--- @param sideFlag number The direction to check for a neighbor. Must be one of the `SlabNeighbourMask` constants.
--- @param all boolean If true, returns all neighbors in the specified direction, otherwise only the first one.
--- @return RoofPlaneSlab|boolean The neighbor slab, or `false` if none is found.
function RoofPlaneSlab:GetNeighbour(sideFlag, all)
	if self.roof_comp == "Gable" then
		--it's a roof edge mascarading as a plane
		return RoofEdgeSlab.GetNeighbour(self, sideFlag)
	end
	
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	local room = self.room
	local a = self:GetAngle()
	local flipped = a % (180 * 60) ~= 0
	local pt
	
	if not flipped and sideFlag == SlabNeighbourMask.Left
		or flipped and sideFlag == SlabNeighbourMask.Bottom then
		pt = point(x, y + voxelSizeY)
	elseif not flipped and sideFlag == SlabNeighbourMask.Right 
			or flipped and sideFlag == SlabNeighbourMask.Top then
		pt = point(x, y - voxelSizeY)
	elseif not flipped and sideFlag == SlabNeighbourMask.Bottom
			or flipped and sideFlag == SlabNeighbourMask.Right then
		pt = point(x + voxelSizeX, y)
	elseif not flipped and sideFlag == SlabNeighbourMask.Top
			or flipped and sideFlag == SlabNeighbourMask.Left then
		pt = point(x - voxelSizeX, y)
	end
	
	local oz = room and room:GetRoofZAndDir(pt) or z
	oz = oz == const.InvalidZ and z or oz
	local getfunc = all and MapGet or MapGetFirst
	return getfunc(pt:x(), pt:y(), oz, 0, "RoofPlaneSlab", nil, const.efVisible, function(o, a) return o:GetClipPlane() == 0 or o:GetAngle() == a end, a)
				--sometimes we are looking for adjacent pieces of a different room that ld makes look like a single roof, then oz would be bogus
			or z ~= oz
			and getfunc(pt:x(), pt:y(), z, 0, "RoofPlaneSlab", nil, const.efVisible, function(o, a) return o:GetClipPlane() == 0 or o:GetAngle() == a end, a)
end

---
--- Gets all the roof plane slab neighbors in the four cardinal directions.
---
--- @return RoofPlaneSlab|boolean The neighbor slabs, or `false` if none are found.
function RoofPlaneSlab:GetNeighbours()
	return self:GetNeighbour(SlabNeighbourMask.Left, "all"),
			self:GetNeighbour(SlabNeighbourMask.Right, "all"),
			self:GetNeighbour(SlabNeighbourMask.Top, "all"),
			self:GetNeighbour(SlabNeighbourMask.Bottom, "all")
end

--- Determines if the current WallSlab is a structural slab.
---
--- A slab is considered structural if it is:
--- - Invulnerable
--- - Grounded
--- - Part of a structural row on the left or right side
--- - Explicitly marked as force_structural
---
--- @return boolean True if the slab is structural, false otherwise.
function WallSlab:IsStructuralSlab()
	return self:IsInvulnerable() or self:IsGrounded() or self:IsStructuralRow(SlabNeighbourMask.Left) or self:IsStructuralRow(SlabNeighbourMask.Right) or self.force_structural
end

---
--- Determines if the current WallSlab is part of a structural row on the left or right side.
---
--- A slab is considered part of a structural row if it is:
--- - Aligned with the slab in the specified direction (left or right)
--- - The slab in the specified direction is also a structural slab
---
--- @param sideFlag SlabNeighbourMask The direction to check for a structural row
--- @return boolean True if the slab is part of a structural row, false otherwise
function WallSlab:IsStructuralRow(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local vx, vy, vz, a = WallWorldToVoxel(self)
	local s = slabAngleToDir[self:GetAngle()]
	
	if s == "North" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vx + 1)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vx)
		end
	elseif s == "South" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vx)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vx + 1)
		end
	elseif s == "West" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vy)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vy + 1)
		end
	elseif s == "East" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vy + 1)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vy)
		end
	end
	
	return false
end

RoofWallSlab.IsStructuralRow = empty_func --structural rows on roof can clip so, just no structure there

---
--- Gets the decoration query box for a room corner.
---
--- @return box The decoration query box for the room corner.
function RoomCorner:GetDecorationQueryBox()
	local e = self:GetEntity()
	if e ~= "InvisibleObject" then
		return self:GetObjectBBox():grow(1)
	end
	
	local min = self:GetRelativePoint(point(-10, -10, 0))
	local max = self:GetRelativePoint(point(110, 110, voxelSizeZ))
	local a, b, c = min:xyz()
	local d, e, f = max:xyz()
	return box(Min(a, d), Min(b, e), c, Max(a, d), Max(b, e), f)
end

---
--- Gets the decoration query box for a wall slab.
---
--- @return box The decoration query box for the wall slab.
function WallSlab:GetDecorationQueryBox()
	local e = self:GetEntity()
	local add = 0
	local minz = 0
	if not self:GetNeighbour(SlabNeighbourMask.Bottom) then
		minz = -voxelSizeZ
	end
	if e ~= "InvisibleObject" then
		local b = self:GetObjectBBox():grow(-add)
		if minz ~= 0 then
			local growth = abs(minz) / 2
			b = b:grow(0, 0, growth)
			b = Offset(b, point(0, 0, -growth))
		end
		return b
	end
	
	local min = self:GetRelativePoint(point(-86, -halfVoxelSizeX + add, minz)) --x const probably comes from somewhere
	local max = self:GetRelativePoint(point(86, halfVoxelSizeX - add, voxelSizeZ))
	local a, b, c = min:xyz()
	local d, e, f = max:xyz()
	return box(Min(a, d), Min(b, e), c, Max(a, d), Max(b, e), f)
end

---
--- Gets the decoration query box for a wall slab.
---
--- @return box The decoration query box for the wall slab.
function SlabWallObject:GetDecorationQueryBox()
	local e = self:GetEntity()
	local add = -1
	local minz = 0
	if not self:GetNeighbour(SlabNeighbourMask.Bottom) then
		minz = -voxelSizeZ
	end
	if e ~= "InvisibleObject" then
		local b = self:GetObjectBBox():grow(-add)
		if minz ~= 0 then
			local growth = abs(minz) / 2
			b = b:grow(0, 0, growth)
			b = Offset(b, point(0, 0, -growth))
		end
		return b
	end
	
	local leftOffset = self:GetLeftOffset()
	local rightOffset = self:GetRightOffset()
	
	local min = self:GetRelativePoint(point(-100, -halfVoxelSizeX + add - rightOffset * voxelSizeX, minz)) --x const probably comes from somewhere
	local max = self:GetRelativePoint(point(100, halfVoxelSizeX - add - leftOffset * voxelSizeX, voxelSizeZ * self.height))
	local a, b, c = min:xyz()
	local d, e, f = max:xyz()
	return box(Min(a, d), Min(b, e), c, Max(a, d), Max(b, e), f)
end

---
--- Gets whether the wall slab has any corner decorations.
---
--- @return boolean Whether the wall slab has any corner decorations.
function WallSlab:GetCornerDecorations()
	return false
end

SlabWallObject.GetCornerDecorations = WallSlab.GetCornerDecorations

---
--- Gets whether the room corner has any corner decorations.
---
--- @return boolean Whether the room corner has any corner decorations.
function RoomCorner:GetCornerDecorations()
	return true
end

---
--- Gets the decorations for the wall slab.
---
--- @return table The decorations for the wall slab.
function WallSlab:GetDecorations()
	local qb = self:GetDecorationQueryBox()
	local getCorners = self:GetCornerDecorations()
	local minz = qb:minz()
	local maxz = qb:maxz()
	return MapGet(qb, "CObject", function(o, minz, maxz)
		if o:GetParent() then return end
		local _, __, z = o:GetPosXYZ()
		if not z or (minz <= z and maxz > z) then
			local e = o:GetEntity()
			--this can be a class check at some point, assets need to be marked from art spec
			return (rawget(o, "orig_decoration_ent") or e:starts_with("WallDec_")) and (getCorners or not string.find(e, "Corner"))
		end
	end, minz, maxz)
end

SlabWallObject.GetDecorations = WallSlab.GetDecorations
RoomCorner.GetDecorations = WallSlab.GetDecorations

---
--- Gets the wall slabs around the given corner of the current wall slab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which corner to get the neighbors for.
--- @return WallSlab|nil The wall slab on the left side of the corner, or nil if none.
--- @return WallSlab|nil The wall slab on the right side of the corner, or nil if none.
function WallSlab:GetNeighboursAroundCorner(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local s = slabAngleToDir[self:GetAngle()]
	local x, y, z = self:GetPosXYZ()
	local r1, r2
	
	local function filter(o)
		return o:GetEnumFlags(const.efVisible) ~= 0 or o.wall_obj
	end
	
	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		if offs.x ~= 0 then
			r1 = MapGetFirst(x + offs.x * halfVoxelSizeX, y + halfVoxelSizeY, z, 0, "WallSlab", filter)
			r2 = MapGetFirst(x + offs.x * halfVoxelSizeX, y - halfVoxelSizeY, z, 0, "WallSlab", filter)
		else
			r1 = MapGetFirst(x + halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z, 0, "WallSlab", filter)
			r2 = MapGetFirst(x - halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z, 0, "WallSlab", filter)
		end
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		if offs.x ~= 0 then
			r1 = MapGetFirst(x - offs.x * halfVoxelSizeX, y + halfVoxelSizeY, z, 0, "WallSlab", filter)
			r2 = MapGetFirst(x - offs.x * halfVoxelSizeX, y - halfVoxelSizeY, z, 0, "WallSlab", filter)
		else
			r1 = MapGetFirst(x + halfVoxelSizeX, y - offs.y * halfVoxelSizeY, z, 0, "WallSlab", filter)
			r2 = MapGetFirst(x - halfVoxelSizeX, y - offs.y * halfVoxelSizeY, z, 0, "WallSlab", filter)
		end
	end
	
	r1 = r1 and not r1.isVisible and r1.wall_obj or r1
	r2 = r2 and not r2.isVisible and r2.wall_obj or r2
	
	return r1 or r2, r1 and r2
end

---
--- Gets the room corners around the given side of the current wall slab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which corners to get.
--- @param all boolean If true, returns all corners on the specified side, otherwise only the first one.
--- @return RoomCorner|nil The room corner on the specified side, or nil if none.
function WallSlab:GetNeighbourCorner(sideFlag, all)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local s = slabAngleToDir[self:GetAngle()]
	local x, y, z = self:GetPosXYZ()
	local f = all and MapGet or MapGetFirst
	
	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		return f(x + offs.x * halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z, 0, "RoomCorner", nil, const.efVisible)
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		return f(x - offs.x * halfVoxelSizeX, y - offs.y * halfVoxelSizeY, z, 0, "RoomCorner", nil, const.efVisible)
	end
end

---
--- Gets the neighbouring WallSlab or Window object for the given side of the current WallSlab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which neighbour to get.
--- @param all boolean If true, returns all neighbours on the specified side, otherwise only the first one.
--- @param enumFlags number Bitfield of enum flags to use when searching for neighbours.
--- @return WallSlab|Window|nil The neighbouring WallSlab or Window object, or nil if none.
function WallSlab:GetNeighbour(sideFlag, all, enumFlags)
	local rez = self:GetNeighbourWallSlab(sideFlag, all, enumFlags) 
	if not IsValid(rez) and #(rez or "") <= 0 then
		rez = self:GetNeighbourWindow(sideFlag)
	end
	return rez
end

---
--- Gets the neighbouring WallSlab object for the given side of the current WallSlab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which neighbour to get.
--- @param all boolean If true, returns all neighbours on the specified side, otherwise only the first one.
--- @param enumFlags number Bitfield of enum flags to use when searching for neighbours.
--- @return WallSlab|nil The neighbouring WallSlab object, or nil if none.
function WallSlab:GetNeighbourWallSlab(sideFlag, all, enumFlags)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local s = slabAngleToDir[self:GetAngle()]
	local x, y, z = self:GetPosXYZ()
	enumFlags = enumFlags == nil and const.efVisible or enumFlags

	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		return not all and MapGetFirst(x + offs.x * voxelSizeX, y + offs.y * voxelSizeY, z, 0, "WallSlab", nil, enumFlags)
				or all and (MapGet(x + offs.x * voxelSizeX, y + offs.y * voxelSizeY, z, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		return not all and MapGetFirst(x - offs.x * voxelSizeX, y - offs.y * voxelSizeY, z, 0, "WallSlab", nil, enumFlags)
				or all and (MapGet(x - offs.x * voxelSizeX, y - offs.y * voxelSizeY, z, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
	
	if sideFlag == SlabNeighbourMask.Top then
		return not all and MapGetFirst(x, y, z + voxelSizeZ, 0, "WallSlab", nil, enumFlags)
				or all and (MapGet(x, y, z + voxelSizeZ, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
	
	if sideFlag == SlabNeighbourMask.Bottom then
		return not all and MapGetFirst(x, y, z - voxelSizeZ, 0, "WallSlab", nil, enumFlags)
				or all and (MapGet(x, y, z - voxelSizeZ, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
end

--- Gets all neighbouring WallSlab or Window objects for the current WallSlab.
---
--- @return WallSlab|Window|nil The neighbouring WallSlab or Window objects, or nil if none.
function WallSlab:GetNeighbours()
	return self:GetNeighbour(SlabNeighbourMask.Left, "all"),
			self:GetNeighbour(SlabNeighbourMask.Right, "all"),
			self:GetNeighbour(SlabNeighbourMask.Top, "all"),
			self:GetNeighbour(SlabNeighbourMask.Bottom, "all")
end

---
--- Gets the neighbouring Window object for the given side of the current WallSlab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which neighbour to get.
--- @return Window|boolean The neighbouring Window object, or false if none.
function WallSlab:GetNeighbourWindow(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local wallNbr = self:GetNeighbourWallSlab(sideFlag, false, ~const.efVisible)
	return wallNbr and wallNbr.wall_obj or false
end

---
--- Gets the neighbouring DestroyableFloorSlab or RoofPlaneSlab object for the given side of the current WallSlab.
---
--- @param sideFlag SlabNeighbourMask The side flag indicating which neighbour to get.
--- @return DestroyableFloorSlab|RoofPlaneSlab|nil The neighbouring DestroyableFloorSlab or RoofPlaneSlab object, or nil if none.
function WallSlab:GetNeighbourFloor(sideFlag)
	local offs
	if sideFlag == SlabNeighbourMask.Top then
		offs = point(halfVoxelSizeX, 0, 0)
	elseif sideFlag == SlabNeighbourMask.Bottom then
		offs = point(-halfVoxelSizeX, 0, 0)
	else
		return
	end
	
	local f = self:GetRelativePoint(offs)
	return MapGetFirst(f, 0, "DestroyableFloorSlab", "RoofPlaneSlab", nil, const.efVisible)
end

local function getNbrPosHelper(x, y, z, w, width, h, side, corner)
	local tx, ty, tz
	local wf = (w - width/2 - (width % 2 == 0 and 0 or 1))
	tz = z + (h - 1) * voxelSizeZ
	local cornerOffset = corner and halfVoxelSizeX or 0
	
	if side == "East" then
		tx = x
		ty = y - wf * voxelSizeY + cornerOffset * sign(wf)
	elseif side == "West" then
		tx = x
		ty = y + wf * voxelSizeY - cornerOffset * sign(wf)
	elseif side == "North" then
		tx = x - wf * voxelSizeX + cornerOffset * sign(wf)
		ty = y
	else
		tx = x + wf * voxelSizeX - cornerOffset * sign(wf)
		ty = y
	end
	
	return tx, ty, tz
end

local function processPosHelper(tx, ty, tz, ret, all, enumFlags, class, class2)
	--DbgAddVector(point(tx, ty, tz))
	local rez
	if not class2 then
		rez = not all and MapGetFirst(tx, ty, tz, 0, class, nil, enumFlags)
						or all and MapGet(tx, ty, tz, 0, class, nil, enumFlags)
	else
		rez = not all and MapGetFirst(tx, ty, tz, 0, class, class2, nil, enumFlags)
						or all and MapGet(tx, ty, tz, 0, class, class2, nil, enumFlags)
	end
		
	if rez then
		ret = ret or {}
		if not all then
			table.insert(ret, rez)
		else
			table.iappend(ret, rez)
		end
	end
	
	return ret
end

local function processVerticalNbrsHelper(height, tx, ty, z, ret, all, enumFlags, class)
	for h = 1, height do
		local tz = z + (h - 1) * voxelSizeZ
		ret = processPosHelper(tx, ty, tz, ret, all, enumFlags, class)
	end
	
	return ret
end

--- Returns the neighbouring SlabWallObject instances for the current SlabWallObject.
---
--- This function returns a list of neighbouring SlabWallObject instances for the current SlabWallObject, based on the specified side flags.
---
--- @param sideFlag SlabNeighbourMask The side flags to check for neighbouring SlabWallObject instances.
--- @param all boolean Whether to return all neighbouring SlabWallObject instances or just the first one found.
--- @return table The list of neighbouring SlabWallObject instances.
function SlabWallObject:GetNeighbours()
	return self:GetNeighbour(SlabNeighbourMask.Left, "all"),
			self:GetNeighbour(SlabNeighbourMask.Right, "all"),
			self:GetNeighbour(SlabNeighbourMask.Top, "all"),
			self:GetNeighbour(SlabNeighbourMask.Bottom, "all")
end

--- Returns the neighbouring SlabWallObject instances and Window instances for the current SlabWallObject.
---
--- This function returns a list of neighbouring SlabWallObject instances and Window instances for the current SlabWallObject, based on the specified side flags.
---
--- @param sideFlag SlabNeighbourMask The side flags to check for neighbouring SlabWallObject instances and Window instances.
--- @param all boolean Whether to return all neighbouring SlabWallObject instances and Window instances or just the first one found.
--- @param enumFlags integer The enumeration flags to use when searching for neighbouring objects.
--- @return table The list of neighbouring SlabWallObject instances and Window instances.
function SlabWallObject:GetNeighbour(sideFlag, all, enumFlags)
	local rez = self:GetNeighbourWallSlab(sideFlag, all, enumFlags)
	local rezw = self:GetNeighbourWindow(sideFlag)
	if rez then
		if IsValid(rezw) then
			table.insert(rez, rezw)
		elseif type(rezw) == "table" then
			table.iappend(rez, rezw)
		end
	else
		rez = rezw
	end
	
	return rez
end

--- Returns the neighbouring SlabWallObject instances for the current SlabWallObject, adjusting for corners.
---
--- This function returns a list of neighbouring SlabWallObject instances for the current SlabWallObject, based on the specified side flags. It adjusts the results to account for corner cases.
---
--- @param sideFlag SlabNeighbourMask The side flags to check for neighbouring SlabWallObject instances.
--- @param all boolean Whether to return all neighbouring SlabWallObject instances or just the first one found.
--- @param enumFlags integer The enumeration flags to use when searching for neighbouring objects.
--- @return table The list of neighbouring SlabWallObject instances.
function SlabWallObject:GetNeighbourCorner(sideFlag, all, enumFlags)
	return self:GetNeighbourWallSlab(sideFlag, all, enumFlags, "adjustForCorner")
end

--- Returns the neighbouring DestroyableFloorSlab and RoofPlaneSlab instances for the current SlabWallObject.
---
--- This function returns a list of neighbouring DestroyableFloorSlab and RoofPlaneSlab instances for the current SlabWallObject, based on the specified side flags.
---
--- @param sideFlag SlabNeighbourMask The side flags to check for neighbouring DestroyableFloorSlab and RoofPlaneSlab instances.
--- @param all boolean Whether to return all neighbouring DestroyableFloorSlab and RoofPlaneSlab instances or just the first one found.
--- @return table The list of neighbouring DestroyableFloorSlab and RoofPlaneSlab instances.
function SlabWallObject:GetNeighbourFloor(sideFlag, all)
	local ret
	local side = self.side or slabAngleToDir[self:GetAngle()]
	local width = Max(self.width, 1)
	local height = self.height
	local x, y, z = self:GetPosXYZ()
	local enumFlags = const.efVisible
	if not z then
		z = terrain.GetHeight(x, y)
	end
	
	local xOffs, yOffs = 0, 0
	if side == "West" then
		xOffs = halfVoxelSizeX
	elseif side == "East" then
		xOffs = -halfVoxelSizeX
	elseif side == "North" then
		yOffs = halfVoxelSizeY
	else
		yOffs = -halfVoxelSizeY
	end
	
	if sideFlag == SlabNeighbourMask.Top then
		for w = 1, width do
			local tx, ty, tz = getNbrPosHelper(x, y, z, w, width, 0, side)
			tx = tx - xOffs
			ty = ty - yOffs
			ret = processPosHelper(tx, ty, z, ret, all, enumFlags, "DestroyableFloorSlab", "RoofPlaneSlab")
		end
	end
	
	if sideFlag == SlabNeighbourMask.Bottom then
		for w = 1, width do
			local tx, ty, tz = getNbrPosHelper(x, y, z, w, width, 0, side)
			tx = tx + xOffs
			ty = ty + yOffs
			ret = processPosHelper(tx, ty, z, ret, all, enumFlags, "DestroyableFloorSlab", "RoofPlaneSlab")
		end
	end
	
	return ret
end

--- Returns the neighbouring WallSlab and RoomCorner instances for the current SlabWallObject.
---
--- This function returns a list of neighbouring WallSlab and RoomCorner instances for the current SlabWallObject, based on the specified side flags.
---
--- @param sideFlag SlabNeighbourMask The side flags to check for neighbouring WallSlab and RoomCorner instances.
--- @param all boolean Whether to return all neighbouring WallSlab and RoomCorner instances or just the first one found.
--- @param enumFlags number The enum flags to use when searching for neighbouring objects.
--- @param adjustForCorner boolean Whether to adjust the search for corner cases.
--- @return table The list of neighbouring WallSlab and RoomCorner instances.
function SlabWallObject:GetNeighbourWallSlab(sideFlag, all, enumFlags, adjustForCorner)
	local ret
	local side = slabAngleToDir[self:GetAngle()]
	local width = Max(self.width, 1)
	local height = self.height
	local x, y, z = self:GetPosXYZ()
	enumFlags = enumFlags == nil and const.efVisible or enumFlags
	
	if not z then
		z = terrain.GetHeight(x, y)
	end
	
	if sideFlag == SlabNeighbourMask.Left then
		local tx, ty, _ = getNbrPosHelper(x, y, z, 0, width, height, side, adjustForCorner)
		ret = processVerticalNbrsHelper(height, tx, ty, z, ret, all, enumFlags, not adjustForCorner and "WallSlab" or "RoomCorner")
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local tx, ty, _ = getNbrPosHelper(x, y, z, width + 1, width, height, side, adjustForCorner)
		ret = processVerticalNbrsHelper(height, tx, ty, z, ret, all, enumFlags, not adjustForCorner and "WallSlab" or "RoomCorner")
	end
	
	if sideFlag == SlabNeighbourMask.Top then
		for w = 1, width do
			local tx, ty, tz = getNbrPosHelper(x, y, z, w, width, height + 1, side, adjustForCorner)
			ret = processPosHelper(tx, ty, tz, ret, all, enumFlags, not adjustForCorner and "WallSlab" or "RoomCorner")
		end
	end
	
	if sideFlag == SlabNeighbourMask.Bottom then
		for w = 1, width do
			local tx, ty, tz = getNbrPosHelper(x, y, z, w, width, 0, side, adjustForCorner)
			ret = processPosHelper(tx, ty, tz, ret, all, enumFlags, not adjustForCorner and "WallSlab" or "RoomCorner")
		end
	end
	
	return ret
end

local function getNbrAroundCornerPosHelper(x, y, z, w, width, h, side)
	local tx, ty, tz
	local wf = (w - width/2 - (width % 2 == 0 and 0 or 1))
	local sign = wf / abs(wf)
	tz = z + (h - 1) * voxelSizeZ
	
	if side == "East" then
		tx = x
		ty = y - wf * voxelSizeY + halfVoxelSizeY * sign
		return tx + halfVoxelSizeX, ty, tz, tx - halfVoxelSizeX, ty, tz
	elseif side == "West" then
		tx = x
		ty = y + wf * voxelSizeY - halfVoxelSizeY * sign
		return tx + halfVoxelSizeX, ty, tz, tx - halfVoxelSizeX, ty, tz
	elseif side == "North" then
		tx = x - wf * voxelSizeX + halfVoxelSizeX * sign
		ty = y
		return tx, ty + halfVoxelSizeY, tz, tx, ty - halfVoxelSizeY, tz
	else
		tx = x + wf * voxelSizeX - halfVoxelSizeX * sign
		ty = y
		return tx, ty + halfVoxelSizeY, tz, tx, ty - halfVoxelSizeY, tz
	end
end

---
--- Gets the wall slab objects that are neighbors around the corner of this slab wall object.
---
--- @param sideFlag number The side flag indicating which neighbors to get.
--- @return table|nil The list of neighboring wall slab objects, or nil if none.
---
function SlabWallObject:GetNeighboursAroundCorner(sideFlag)
	local ret
	local side = self.side
	local width = Max(self.width, 1)
	local height = self.height
	local x, y, z = self:GetPosXYZ()
	local enumFlags = nil
	local all = nil
	if not z then
		z = terrain.GetHeight(x, y)
	end
	
	if sideFlag == SlabNeighbourMask.Left then
		local tx1, ty1, _, tx2, ty2, _ = getNbrAroundCornerPosHelper(x, y, z, 0, width, height, side)
		
		ret = processVerticalNbrsHelper(height, tx1, ty1, z, ret, all, enumFlags, "WallSlab")
		ret = processVerticalNbrsHelper(height, tx2, ty2, z, ret, all, enumFlags, "WallSlab")
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local tx1, ty1, _, tx2, ty2, _ = getNbrAroundCornerPosHelper(x, y, z, width + 1, width, height, side)

		ret = processVerticalNbrsHelper(height, tx1, ty1, z, ret, all, enumFlags, "WallSlab")
		ret = processVerticalNbrsHelper(height, tx2, ty2, z, ret, all, enumFlags, "WallSlab")
	end
	
	local swos = false
	for i = #(ret or ""), 1, -1 do
		local ws = ret[i]
		if not ws.isVisible then
			table.remove(ret, i)
			if ws.wall_obj then
				swos = swos or {}
				swos[ws.wall_obj] = true
			end
		end
	end
	
	for swo, _ in pairs(swos or empty_table) do
		table.insert(ret, swo)
	end
	
	return ret
end

--- Gets the neighboring wall slab objects that contain a window object.
---
--- @param sideFlag number The side flag indicating which neighbors to get.
--- @return table|nil The list of neighboring wall slab objects with window objects, or nil if none.
function SlabWallObject:GetNeighbourWindow(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local ret
	local retIsTable = false
	local wallNbrs = self:GetNeighbourWallSlab(sideFlag, "all", ~const.efVisible)
	if wallNbrs and #wallNbrs > 0 then
		for i = 1, #wallNbrs do
			local nbr = wallNbrs[i]
			if nbr.wall_obj then
				if not ret then
					ret = nbr.wall_obj
				elseif not retIsTable and ret ~= nbr.wall_obj then
					ret = {ret}
					table.insert_unique(ret, nbr.wall_obj)
					retIsTable = true
				elseif retIsTable then
					table.insert_unique(ret, nbr.wall_obj)
				end
			end
		end
	end
	
	return ret
end

--- Determines if the current DestroyableFloorSlab is a structural slab.
---
--- A slab is considered structural if it is grounded, has the `force_structural` flag set, or is part of a structural row.
---
--- @return boolean True if the slab is structural, false otherwise.
function SlabWallObject:IsStructuralSlab()
	if self:IsGrounded() or self.force_structural then
		return true
	end
	
	local lo = self:GetLeftOffset()
	local ro = self:GetRightOffset()
	local vx, vy, vz, a = WallWorldToVoxel(self)
	local s = slabAngleToDir[self:GetAngle()]
	local min, max
	
	if s == "North" then
		min = vx - ro
		max = vx + lo + 1
	elseif s == "South" then
		min = vx - lo
		max = vx + ro + 1
	elseif s == "West" then
		min = vy - lo
		max = vy + ro + 1
	elseif s == "East" then
		min = vy - ro
		max = vy + lo + 1
	end
	
	for i = min, max do
		if IsStructuralRow(i) then
			return true
		end
	end

	return false
end

--- Determines if the specified side of the SlabWallObject is part of a structural row.
---
--- @param sideFlag SlabNeighbourMask The side of the SlabWallObject to check.
--- @return boolean True if the specified side is part of a structural row, false otherwise.
function SlabWallObject:IsStructuralRow(sideFlag)
	local vx, vy, vz, a = WallWorldToVoxel(self)
	local s = slabAngleToDir[self:GetAngle()]
	local lo = self:GetLeftOffset()
	local ro = self:GetRightOffset()
	
	if s == "North" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vx + lo + 1)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vx - ro)
		end
	elseif s == "South" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vx - lo)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vx + ro + 1)
		end
	elseif s == "West" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vy - lo)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vy + ro + 1)
		end
	elseif s == "East" then
		if sideFlag == SlabNeighbourMask.Left then
			return IsStructuralRow(vy + lo + 1)
		elseif sideFlag == SlabNeighbourMask.Right then
			return IsStructuralRow(vy - ro)
		end
	end
	
	return false
end

--- Determines if the DestroyableFloorSlab is a structural slab.
---
--- A DestroyableFloorSlab is considered a structural slab if:
--- - It is invulnerable (cannot be destroyed)
--- - The `force_structural` flag is set
--- - It is grounded (resting on the ground)
---
--- @return boolean True if the DestroyableFloorSlab is a structural slab, false otherwise.
function DestroyableFloorSlab:IsStructuralSlab()
	return self:IsInvulnerable() or self.force_structural
			or self:IsGrounded()
end

--- Retrieves the neighboring WallSlab object on the specified side of the DestroyableFloorSlab.
---
--- @param sideFlag SlabNeighbourMask The side of the DestroyableFloorSlab to check.
--- @return DestroyableFloorSlab|boolean The neighboring WallSlab object, or false if no WallSlab is found on the specified side.
function DestroyableFloorSlab:GetNeighbourWallSlab(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	if sideFlag == SlabNeighbourMask.Left then
		return MapGetFirst(x, y + halfVoxelSizeY, z, 0, "WallSlab", nil, const.efVisible)
	elseif sideFlag == SlabNeighbourMask.Right then
		return MapGetFirst(x, y - halfVoxelSizeY, z, 0, "WallSlab", nil, const.efVisible)
	elseif sideFlag == SlabNeighbourMask.Top then
		return MapGetFirst(x - halfVoxelSizeX, y, z, 0, "WallSlab", nil, const.efVisible)
	elseif sideFlag == SlabNeighbourMask.Bottom then
		return MapGetFirst(x + halfVoxelSizeX, y, z, 0, "WallSlab", nil, const.efVisible)
	end
	
	return false
end

--- Retrieves the neighboring DestroyableFloorSlab object on the specified side of the current DestroyableFloorSlab.
---
--- @param sideFlag SlabNeighbourMask The side of the DestroyableFloorSlab to check.
--- @return DestroyableFloorSlab|boolean The neighboring DestroyableFloorSlab object, or false if no DestroyableFloorSlab is found on the specified side.
function DestroyableFloorSlab:GetNeighbour(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local vx, vy, vz = WorldToVoxel(self)
	if sideFlag == SlabNeighbourMask.Left then
		return GetFloorAlignedObj(vx, vy + 1, vz, self.class)
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		return GetFloorAlignedObj(vx, vy - 1, vz, self.class)
	end
	
	if sideFlag == SlabNeighbourMask.Top then
		return GetFloorAlignedObj(vx - 1, vy, vz, self.class)
	end
	
	if sideFlag == SlabNeighbourMask.Bottom then
		return GetFloorAlignedObj(vx + 1, vy, vz, self.class)
	end
end

--- Retrieves the neighboring StairSlab objects around the current DestroyableFloorSlab.
---
--- @return table|nil A table containing the neighboring StairSlab objects, or nil if no StairSlab neighbors were found.
function DestroyableFloorSlab:GetStairNeighbours()
	local ret
	local vx, vy, vz = WorldToVoxel(self)
	local cls = "StairSlab"
	local function add(val)
		if val then
			ret = ret or {}
			ret[#ret + 1] = val
		end
	end
	add(GetFloorAlignedObj(vx, vy + 1, vz, cls))
	add(GetFloorAlignedObj(vx, vy + 1, vz + 1, cls))
	add(GetFloorAlignedObj(vx, vy - 1, vz, cls))
	add(GetFloorAlignedObj(vx, vy - 1, vz + 1, cls))
	add(GetFloorAlignedObj(vx - 1, vy, vz, cls))
	add(GetFloorAlignedObj(vx - 1, vy, vz + 1, cls))
	add(GetFloorAlignedObj(vx + 1, vy, vz, cls))
	add(GetFloorAlignedObj(vx + 1, vy, vz + 1, cls))
	
	return ret
end

--- Retrieves the neighboring DestroyableFloorSlab objects around the current DestroyableFloorSlab.
---
--- @return DestroyableFloorSlab, DestroyableFloorSlab, DestroyableFloorSlab, DestroyableFloorSlab The neighboring DestroyableFloorSlab objects to the left, right, top, and bottom of the current DestroyableFloorSlab.
function DestroyableFloorSlab:GetNeighbours()
	local vx, vy, vz = WorldToVoxel(self)
	local cls = self.class
	local left = GetFloorAlignedObj(vx, vy + 1, vz, cls)
	local right = GetFloorAlignedObj(vx, vy - 1, vz, cls)
	local top = GetFloorAlignedObj(vx - 1, vy, vz, cls)
	local bottom = GetFloorAlignedObj(vx + 1, vy, vz, cls)
	
	return left, right, top, bottom
end

--- Retrieves the neighboring WallSlab objects around the current RoomCorner.
---
--- @param sideFlag SlabNeighbourMask The side flag to check for neighboring WallSlab objects.
--- @param all boolean If true, returns all neighboring WallSlab objects, otherwise only the first one.
--- @param enumFlags number The enumeration flags to use when searching for neighboring WallSlab objects.
--- @return WallSlab|table|nil The neighboring WallSlab object(s), or nil if no WallSlab neighbors were found.
function RoomCorner:GetNeighbourWallSlab(sideFlag, all, enumFlags)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local s = self.side or slabAngleToDir[self:GetAngle()]
	local x, y, z = self:GetPosXYZ()
	enumFlags = enumFlags == nil and const.efVisible or enumFlags
	
	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		--DbgAddVector(point(x + offs.x * halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z))
		return not all and MapGetFirst(x + offs.x * halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z, 0, "WallSlab", nil, enumFlags)
					or all and (MapGet(x + offs.x * halfVoxelSizeX, y + offs.y * halfVoxelSizeY, z, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
	
	if sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		--DbgAddVector(point(x - offs.y * halfVoxelSizeX, y + offs.x * halfVoxelSizeY, z))
		return not all and MapGetFirst(x - offs.y * halfVoxelSizeX, y + offs.x * halfVoxelSizeY, z, 0, "WallSlab", nil, enumFlags)
					or all and (MapGet(x - offs.y * halfVoxelSizeX, y + offs.x * halfVoxelSizeY, z, 0, "WallSlab", nil, enumFlags) or empty_table)
	end
end

RoomCorner.GetNeighbourWindow = WallSlab.GetNeighbourWindow

--- Retrieves the neighboring RoomCorner objects around the current RoomCorner.
---
--- @param sideFlag SlabNeighbourMask The side flag to check for neighboring RoomCorner objects.
--- @param all boolean If true, returns all neighboring RoomCorner objects, otherwise only the first one.
--- @param enumFlags number The enumeration flags to use when searching for neighboring RoomCorner objects.
--- @return RoomCorner|table|nil The neighboring RoomCorner object(s), or nil if no RoomCorner neighbors were found.
function RoomCorner:GetNeighbour(sideFlag, all, enumFlags)
	--presumably has only t and b nbrs
	enumFlags = enumFlags == nil and const.efVisible or enumFlags
	local x, y, z = self:GetPosXYZ()
	
	if sideFlag == SlabNeighbourMask.Top then
		return not all and MapGetFirst(x, y, z + voxelSizeZ, 0, "RoomCorner", nil, enumFlags) or
					all and (MapGet(x, y, z + voxelSizeZ, 0, "RoomCorner", nil, enumFlags))
	end
	
	if sideFlag == SlabNeighbourMask.Bottom then
		return not all and MapGetFirst(x, y, z - voxelSizeZ, 0, "RoomCorner", nil, enumFlags) or
					all and (MapGet(x, y, z - voxelSizeZ, 0, "RoomCorner", nil, enumFlags))
	end
	
	return nil
end

--- Retrieves the neighboring RoomCorner objects around the current RoomCorner.
---
--- @return WallSlab|table|nil The neighboring WallSlab object(s), or nil if no WallSlab neighbors were found.
--- @return WallSlab|table|nil The neighboring WallSlab object(s), or nil if no WallSlab neighbors were found.
--- @return RoomCorner|table|nil The neighboring RoomCorner object(s), or nil if no RoomCorner neighbors were found.
--- @return RoomCorner|table|nil The neighboring RoomCorner object(s), or nil if no RoomCorner neighbors were found.
function RoomCorner:GetNeighbours()
	return self:GetNeighbourWallSlab(SlabNeighbourMask.Left, "all"), self:GetNeighbourWallSlab(SlabNeighbourMask.Right, "all"), self:GetNeighbour(SlabNeighbourMask.Top, "all"), self:GetNeighbour(SlabNeighbourMask.Bottom, "all")
end

DefineClass.Destroyable = {
	__parents = { "Object" },
	properties = {
		{ id = "is_destroyed", editor = "bool", default = false, no_edit = true },
	},
}

--- Sets up any necessary flags or properties for the Destroyable object.
function Destroyable:SetupFlags()
end

AutoResolveMethods.OnDestroy = "call"
Destroyable.OnDestroy = empty_func

--- Determines whether destruction FX should be played for the given object.
---
--- @param obj any The object to check for destruction FX.
--- @return boolean true if destruction FX should be played, false otherwise.
function ShouldPlayDestructionFX(obj)
	return true --stub
end

--- Marks the Destroyable object as destroyed. If the object is not in editor mode and destruction FX should be played, the destruction FX is played. The OnDestroy event is then called.
function Destroyable:Destroy()
	self.is_destroyed = true
	if not IsEditorActive() and ShouldPlayDestructionFX(self) then
		self:PlayDestructionFX()
	end
	self:OnDestroy()
end

--- Marks the Destroyable object as repaired, setting the `is_destroyed` property to `false`.
function Destroyable:Repair()
	self.is_destroyed = false
end

local function touch(o, touchedSlabs) --for easier dbg
	if IsValid(o) and not o.is_destroyed then
		touchedSlabs[o] = true
	end
end

local function touchd(o, touchedDestroyedSlabs)
	if IsValid(o) and o.is_destroyed then
		touchedDestroyedSlabs[o] = true
	end
end

local function processRepairedRoofEdgeNbrHelper(slab, sideFlag, touchedDestroyedSlabs, touchedSlabs, corner)
	local e = slab:GetNeighbourEdge(sideFlag, corner)
	if e then
		if e.is_destroyed then
			e:Repair()
		end
	end
end

local function processRoofEdgeNbrHelper(slab, sideFlag, touchedDestroyedSlabs, touchedSlabs, corner)
	local e = slab:GetNeighbourEdge(sideFlag, corner)
	if e then
		if e.is_destroyed then
			touchedDestroyedSlabs[e] = true
		else
			e:Destroy()
		end
	end
end

local function _processCornerNbrHelper(c, slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
	if IsValid(c) then
		if c.is_destroyed then
			touchedDestroyedSlabs[c] = true
			local otherWall = c:GetNeighbourWallSlab(sideFlag) or c:GetNeighbourWindow(sideFlag)
			if otherWall then
				touchedDestroyedSlabs[otherWall] = true
			end
		else
			local s = slab.side or slabAngleToDir[slab:GetAngle()]
			local isStructuralCorner = ((s == "North" or s == "South") and slab:IsStructuralRow(sideFlag)) or false --consider only x axis rows for corners
			if not isStructuralCorner then
				local otherWall = c:GetNeighbourWallSlab(sideFlag) or c:GetNeighbourWindow(sideFlag)
				if otherWall then
					local osf = maskToOppositeMask[sideFlag]
					s = otherWall.side or slabAngleToDir[otherWall:GetAngle()]
					isStructuralCorner = ((s == "North" or s == "South") and otherWall:IsStructuralRow(osf)) or false
					if not isStructuralCorner and otherWall.is_destroyed then
						--no structure row on either side and both walls destroyed
						c:Destroy()
						touchedDestroyedSlabs[otherWall] = true
					else
						touch(otherWall, touchedSlabs)
					end
				else --no other wall
					c:Destroy()
				end
			end
		end
	elseif type(c) == "table" then
		for i = 1, #c do
			_processCornerNbrHelper(c[i], slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
		end
	end
end

local function processCornerNbrHelper(slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
	local c = slab:GetNeighbourCorner(sideFlag, "all")
	_processCornerNbrHelper(c, slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
end

local function _processRepairedCornerNbrHelper(c, slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
	if IsValid(c) then
		if c.is_destroyed then
			c:Repair()
			
			local otherWall = c:GetNeighbourWallSlab(sideFlag)
			if otherWall then
				if otherWall.is_destroyed then
					touchedDestroyedSlabs[otherWall] = true
				else
					touch(otherWall, touchedSlabs)
				end
			end
		end
	elseif type(c) == "table" then
		for i = 1, #c do
			_processRepairedCornerNbrHelper(c[i], slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
		end
	end
end

local function processRepairedCornerNbrHelper(slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
	local c = slab:GetNeighbourCorner(sideFlag, "all")
	_processRepairedCornerNbrHelper(c, slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
end

local function _processRepairedNbr(n, sideFlag, touchedDestroyedSlabs, touchedSlabs, slab)
	if IsValid(n) then
		local osf = GetNeigbhourSideFlagTowardMe(sideFlag, n, slab)
		n.destroyed_neighbours = n.destroyed_neighbours & (~osf)
		if n.is_destroyed then
			touchedDestroyedSlabs[n] = true
		else
			touch(n, touchedSlabs)
		end
	elseif type(n) == "table" then
		for i = 1, #n do
			_processRepairedNbr(n[i], sideFlag, touchedDestroyedSlabs, touchedSlabs, slab)
		end
	end
end

local function processRepairedNbr(slab, sideFlag, touchedDestroyedSlabs, touchedSlabs)
	local n = slab:GetNeighbour(sideFlag, "all")
	_processRepairedNbr(n, sideFlag, touchedDestroyedSlabs, touchedSlabs, slab)
	return IsValid(n) or #(n or "") > 0
end

---
--- Processes all objects in the same volume as the given `slab` and calls the specified `method` on them, except for the `slab` itself.
---
--- @param slab table The slab object to process.
--- @param method string The method to call on the objects.
---
function processStackedRoofWalls(slab, method)
	MapForEach(slab, 0, slab.class, nil, const.efVisible, function(other, slab, method)
		if other ~= slab then
			other[method](other)
		end
	end, slab, method)
end

local function processStackedRoofs(slab, method)
	if slab:GetClipPlane() ~= 0 then
		--clipped tiles overlap, kill everything overlapping
		MapForEach(slab, 0, slab.class, nil, const.efVisible, function(obj, slab, method)
			if obj ~= slab then
				obj[method](obj)
			end
		end, slab, method)
		if slab.room then
			--this would work for new roofs, but there was a nasty round error so gable pieces are offset
			local other = MapGetFirst(slab, 1, slab.class, nil, const.efVisible, function(o) return o.roof_comp == "Gable" end)
			if other then
				other[method](other)
			end
		end
	end
end

local function destroyRoffWallsHelper(x, y, z, method)
	local others = MapGet(x, y, z, 0, "RoofWallSlab", nil, const.efVisible)
	for i = 1, #(others or "") do
		local o = others[i]
		if o:GetClipPlane() ~= 0 then
			o[method](o)
		end
	end
end

local function processWallsBelowEaves(slab, method)
	local x, y, z = slab:GetPosXYZ()
	z = snapZ(z)
	
	destroyRoffWallsHelper(x, y, z, method) --tile below
	local bz = snapZ(z - 1) --tile below that
	destroyRoffWallsHelper(x, y, bz, method)

	local rp = slab:GetRelativePoint(point(0, -halfVoxelSizeY, 0))
	destroyRoffWallsHelper(rp:x(), rp:y(), z, method) --offset tile below
	destroyRoffWallsHelper(rp:x(), rp:y(), bz, method) --offset tile below that
	
	local rp = slab:GetRelativePoint(point(0, halfVoxelSizeY, 0))
	destroyRoffWallsHelper(rp:x(), rp:y(), z, method) --other dir offset tile below
	destroyRoffWallsHelper(rp:x(), rp:y(), bz, method) --offset tile below that
end

local function processWallsBelowRoofPlanes(slab, method)
	local x, y, z = slab:GetPosXYZ()
	local a = slab:GetAngle()
	local flipped = a % (180 * 60) ~= 0
	local lx, ly, rx, ry
	
	if not flipped then
		ly = y + halfVoxelSizeY
		ry = y - halfVoxelSizeY
		rx = x
		lx = x
	else
		lx = x - halfVoxelSizeX
		rx = x + halfVoxelSizeX
		ry = y
		ly = y
	end
	z = snapZ(z)
	destroyRoffWallsHelper(lx, ly, z, method) --tile below
	destroyRoffWallsHelper(rx, ry, z, method) --tile below
	local bz = snapZ(z - 1) --tile below that
	destroyRoffWallsHelper(lx, ly, bz, method)
	destroyRoffWallsHelper(rx, ry, bz, method)
	
	if not flipped then
		local ox = x - halfVoxelSizeX
		destroyRoffWallsHelper(ox, ly, z, method) --offset tile below
		destroyRoffWallsHelper(ox, ly, bz, method) --offset tile further below
		destroyRoffWallsHelper(ox, ry, z, method) --offset tile below
		destroyRoffWallsHelper(ox, ry, bz, method) --offset tile further below
		ox = x + halfVoxelSizeX
		destroyRoffWallsHelper(ox, ly, z, method) --offset in other dir tile below
		destroyRoffWallsHelper(ox, ly, bz, method) --offset in other dir tile further below
		destroyRoffWallsHelper(ox, ry, z, method) --offset in other dir tile below
		destroyRoffWallsHelper(ox, ry, bz, method) --offset in other dir tile further below
	else
		local oy = y - halfVoxelSizeY
		destroyRoffWallsHelper(lx, oy, z, method) --offset tile below
		destroyRoffWallsHelper(lx, oy, bz, method) --offset tile further below
		destroyRoffWallsHelper(rx, oy, z, method) --offset tile below
		destroyRoffWallsHelper(rx, oy, bz, method) --offset tile further below
		oy = y + halfVoxelSizeY
		destroyRoffWallsHelper(lx, oy, z, method) --offset in other dir tile below
		destroyRoffWallsHelper(lx, oy, bz, method) --offset in other dir tile further below
		destroyRoffWallsHelper(rx, oy, z, method) --offset in other dir tile below
		destroyRoffWallsHelper(rx, oy, bz, method) --offset in other dir tile further below
	end
end

local function processGableEdges(slab, method)
	--look for gable edges
	local cls
	local mp = slab:GetPos()
	local s = slabAngleToDir[slab:GetAngle()]
	local offs = wallSidewaysOffsets[s]
	if IsKindOf(slab, "RoofPlaneSlab") then
		cls = "RoofEdgeSlab"
	elseif IsKindOf(slab, "RoofEdgeSlab") then
		cls = "RoofCorner"
	end
	local l = MapGetFirst(mp:x() + offs.x * halfVoxelSizeX, mp:y() + offs.y * halfVoxelSizeY, mp:z(), 0, cls, nil, const.efVisible)
	local r = MapGetFirst(mp:x() - offs.x * halfVoxelSizeX, mp:y() - offs.y * halfVoxelSizeY, mp:z(), 0, cls, nil, const.efVisible)
	if l then l[method](l) end
	if r then r[method](r) end
end

local maxDist = voxelSizeZ * 2
---
--- Attempts to find the closest adjacent RoofPlaneSlab above the current WallSlab.
---
--- @param aboveOnly boolean If true, only return RoofPlaneSlabs that are above the current WallSlab.
--- @return RoofPlaneSlab|false The closest adjacent RoofPlaneSlab, or false if none found.
function WallSlab:TryGetAdjacentRoofPlane(aboveOnly)
	local offs = point(-halfVoxelSizeX, 0, 0)
	local f = self:GetRelativePoint(offs)
	local _, _, selfZ = self:GetPosXYZ()
	local roof = MapGetFirst(f, 1, "RoofPlaneSlab", nil, const.efVisible, function(o, self, selfZ)
		return o.roof_comp == "Plane" and 
			(not self.room or o.room == self.room or (not o.room or o.room:IsRoofOnly() and not self.room:HasRoofSet())) and 
			(not aboveOnly or o:GetPos():z() >= selfZ)
	end, self, selfZ)

	return roof and IsCloser(roof, f, maxDist) and roof or false
end

---
--- Attempts to find the closest adjacent RoofPlaneSlab in front of the current WallSlab.
---
--- @param self WallSlab The WallSlab instance.
--- @return RoofPlaneSlab|false The closest adjacent RoofPlaneSlab in front of the WallSlab, or false if none found.
function WallSlab:TryGetAdjacentRoofPlaneInFront()
	local offs = point(halfVoxelSizeX, 0, 0)
	local f = self:GetRelativePoint(offs)
	local _, _, selfZ = self:GetPosXYZ()
	local roof = MapGetFirst(f, 1, "RoofPlaneSlab", nil, const.efVisible, function(o, self, selfZ)
		local _, _, oz = o:GetPosXYZ()
		return o.roof_comp == "Plane" and 
			(not o.room or o.room:IsRoofOnly()) and
			(oz >= selfZ and oz < (selfZ + voxelSizeZ))
	end, self, selfZ)
	
	return roof
end

RoofEdgeSlab.TryGetAdjacentRoofPlane = WallSlab.TryGetAdjacentRoofPlane

---
--- Determines whether a destruction pass should be performed.
---
--- @return boolean true if there are any destroyed or repaired objects, false otherwise
---
function ShouldDoDestructionPass()
	return not (#DestroyedCOThisTick <= 0 and #RepairedSlabsThisTick <= 0 and #DestroyedSlabsThisTick <= 0 and #DestroyedObjectsThisTick <= 0)
end

local debrisThisTick = 0
---
--- Processes all destroyed objects in the current tick.
---
--- This function is responsible for handling the destruction of various game objects, including
--- construction objects (COs), slabs, and generic objects. It performs the following tasks:
---
--- 1. Checks if a destruction pass should be performed by calling `ShouldDoDestructionPass()`.
--- 2. Suspends pass edits to ensure consistency during the destruction process.
--- 3. Processes all destroyed slabs by calling `ProcessDestroyedSlabsThisTick()`.
--- 4. Plays sound effects based on the number of destroyed objects.
--- 5. Processes all destroyed generic objects by calling `ProcessDestroyedGenericObjectsThisTick()`.
--- 6. Processes all destroyed construction objects by calling `ProcessDestroyedCOThisTick()`.
--- 7. Resumes pass edits and sends a "DestructionPassDone" message.
---
--- @return nil
function ProcessDestroyedObjectsThisTick()
	if not ShouldDoDestructionPass() then
		return
	end
	SuspendPassEdits("ProcessDestroyedObjectsThisTick")
	--print("pass", #DestroyedCOThisTick, #RepairedSlabsThisTick, #DestroyedSlabsThisTick, #DestroyedObjectsThisTick)
	
	local allDestroyed = {}
	debrisThisTick = 0
	while #DestroyedSlabsThisTick > 0 or #RepairedSlabsThisTick > 0 do --disconnected slabs will generate another pass, run it now to avoid suspendpassresume between passes
		table.iappend(allDestroyed, ProcessDestroyedSlabsThisTick())
	end
	--sound fx
	local c = #allDestroyed
	if c > 0 then
		local fxPos = AveragePoint(allDestroyed)
		local fxAction = c < 5 and "BulkDestructionSmall" or c < 9 and "BulkDestructionMedium" or "BulkDestructionLarge"
		PlayFX(fxAction, "start", nil, nil, fxPos)
	end

	ProcessDestroyedGenericObjectsThisTick()
	ProcessDestroyedCOThisTick()
	
	ResumePassEdits("ProcessDestroyedObjectsThisTick")
	Msg("DestructionPassDone")
end

---
--- Processes all destroyed generic objects in the current tick.
---
--- This function is responsible for handling the destruction of generic game objects. It performs any necessary cleanup or processing for objects that have been destroyed.
---
--- @return nil
function ProcessDestroyedGenericObjectsThisTick()
	--stub
end

---
--- Processes all destroyed construction objects (COs) in the current tick.
---
--- This function is responsible for handling the destruction of construction objects. It performs any necessary cleanup or processing for COs that have been destroyed.
---
--- @return nil
function ProcessDestroyedCOThisTick()
	if #DestroyedCOThisTick <= 0 then
		return
	end
	
	DoneObjects(DestroyedCOThisTick)
	DestroyedCOThisTick = {}
end

local function TouchNonDestroyedNeighbours(o, touchedSlabs)
	local nbrs = {o:GetNeighbours()}
	local function porcessNeighbours(lst)
		if IsValid(lst) then
			if not lst.is_destroyed then
				touch(lst, touchedSlabs)
			end
		else
			for i, nbr in ipairs(lst) do
				porcessNeighbours(nbr)
			end
		end
	end
	for _, lst in ipairs(nbrs) do
		porcessNeighbours(lst)
	end
end

function ProcessObjectsAroundSlabs(destroyedFloorBoxes, destroyedFloorMap, destroyedWallBoxes, destroyedRoofBoxes)
	--project specific
end

local point21 = point(1, 1, 0)
---
--- Processes all destroyed slabs in the current tick.
---
--- This function is responsible for handling the destruction of slabs. It performs any necessary cleanup or processing for slabs that have been destroyed, including updating neighboring objects, creating bounding boxes for destroyed geometry, and notifying rooms of changes.
---
--- @return table The list of slabs that were processed during this pass.
function ProcessDestroyedSlabsThisTick()
	if #RepairedSlabsThisTick <= 0 and #DestroyedSlabsThisTick <= 0 then
		return
	end
	
	local lst = DestroyedSlabsThisTick
	local touchedSlabs = {}
	local touchedDestroyedSlabs = {}
	DestroyedSlabsThisTick = {}
	
	local destroyedFloorMap = {}
	local destroyedFloorBoxes = {}
	local function AddFloorBox(box)
		local nb = box:grow(1) --grow to catch touching boxes
		for i = 1, #destroyedFloorBoxes do
			local ob = destroyedFloorBoxes[i]
			local ir = ob:Intersect(nb)
			
			if ir == const.irInside or ob == nb then
				return
			end
			
			if ir ~= const.irOutside then
				local nb = AddRects(ob, box)
				table.remove(destroyedFloorBoxes, i)
				AddFloorBox(nb)
				return
			end
		end
		
		table.insert(destroyedFloorBoxes, box)
	end
	
	local function appendBoxToBoxContainer(box, boxContainer)
		local x, y, z = box:sizexyz()
		for i, otherBox in ipairs(boxContainer) do
			local nb = AddRects(box, otherBox)
			local ox, oy, oz = otherBox:sizexyz()
			local nx, ny, nz = nb:sizexyz()
			if oz + z >= nz and ((nx == x and (oy + y + 1) >= ny)
				or (ny == y and (ox + x + 1) >= nx)) then
				boxContainer[i] = nb
				return i
			end
		end
		table.insert(boxContainer, box)
		return #boxContainer
	end
	--appendBoxToBoxContainer = C_AppendBoxToBoxContainer
	local extrudeBoxWith = 200
	local destroyedWallBoxes = {}
	local destroyedWallBoxesOnTop = {}
	local function AddWallBox(box, growZ)
		local x, y, z = box:sizexyz()
		growZ = growZ or 0
		if x < y then
			box = box:grow(extrudeBoxWith, 0, growZ)
		elseif x > y then
			box = box:grow(0, extrudeBoxWith, growZ)
		else
			box = box:grow(extrudeBoxWith, extrudeBoxWith, growZ)
		end
		
		local i = appendBoxToBoxContainer(box, destroyedWallBoxes)
		if growZ > 0 then
			destroyedWallBoxesOnTop[i] = true
		end
	end
	
	local destroyedRoofBoxes = {}
	local function AddRoofBox(b, slab)
		local z = slab.room and slab.room.roof_box:minz() or b:minz() - extrudeBoxWith
		b = box( (b:min() + point21):SetZ(z), (b:max() + point21):AddZ(extrudeBoxWith))
		appendBoxToBoxContainer(b, destroyedRoofBoxes)
	end
	
	local roomsWithDestroyedRoofPlaneSlabs = {}
	local roomsWithDestroyedRoofEdgeSlabs = {}
	local roomsWithDestroyedSlabs = {}
	local inEditor = IsEditorActive()
	
	local i = 1
	while i <= #lst do 
		local slab = lst[i]
		slab:SetDestroyedState(inEditor)
		touchedDestroyedSlabs[slab] = true
		if slab.room then
			roomsWithDestroyedSlabs[slab.room] = true
		end
		
		local ured = slab.use_replace_ent_destruction
		--process nbrs
		local left, right, top, bottom = slab:GetNeighbours()
		local function processNeighbours(o, sideFlag, touchedDestroyedSlabs, touchedSlabs)
			if IsValid(o) then
				if not ured then
					local f = GetNeigbhourSideFlagTowardMe(sideFlag, o, slab)
					o.destroyed_neighbours = o.destroyed_neighbours | f
				end
				
				if o.is_destroyed then
					touchedDestroyedSlabs[o] = true
					if o:GetStateText():starts_with("broken") then
						--if its a "broken" slabwallobj it could spontaenously decide it no longer is such and repaired nbrs need to fix their broken look towards it
						TouchNonDestroyedNeighbours(o, touchedSlabs)
					end
					if rawget(o, "always_visible") then
						--sometimes we wont get the window but rather it's walls
						touchd(MapGetFirst(o, 0, "SlabWallObject"), touchedDestroyedSlabs)
					end
				else
					touch(o, touchedSlabs)
				end
			elseif type(o) == "table" then
				for i = 1, #o do
					processNeighbours(o[i], sideFlag, touchedDestroyedSlabs, touchedSlabs)
				end
			end
		end
		
		local function destroyAndPush(s)
			if IsValid(s) and not s.is_destroyed then
				touchedDestroyedSlabs[s] = true
				s:Destroy()
			end
		end
		
		if IsKindOf(slab, "WallSlab") then
			local ventWindowOwned = slab.always_visible
			if IsKindOf(slab, "RoofWallSlab") or ventWindowOwned then
				--these stack, destroy all stacked pieces
				processStackedRoofWalls(slab, "Destroy")
			end
			if ventWindowOwned then
				local w = MapGetFirst(slab, 0, "SlabWallObject")
				if w and not w.is_destroyed then
					w:Destroy()
				end
			end
			local nbr = slab:TryGetAdjacentRoofPlane()
			touch(nbr, touchedSlabs)
			--check for nbr corners and figure out what to do
			processCornerNbrHelper(slab, SlabNeighbourMask.Left, touchedDestroyedSlabs, touchedSlabs)
			processCornerNbrHelper(slab, SlabNeighbourMask.Right, touchedDestroyedSlabs, touchedSlabs)
			--destroy floors in front or behind
			local offs = point(halfVoxelSizeX, 0, 0)
			local f = slab:GetRelativePoint(offs)
			local floor = MapGetFirst(f, 0, "FloorSlab", "CeilingSlab", nil, const.efVisible)
			destroyAndPush(floor)
			f = slab:GetRelativePoint(-offs)
			floor = MapGetFirst(f, 0, "FloorSlab", "CeilingSlab", nil, const.efVisible)
			destroyAndPush(floor)
			local lnbr1, lnbr2 = slab:GetNeighboursAroundCorner(SlabNeighbourMask.Left)
			local rnbr1, rnbr2 = slab:GetNeighboursAroundCorner(SlabNeighbourMask.Right)
			
			
			--process T junktion walls
			if IsValid(left) or #(left or "") > 0 then
				destroyAndPush(lnbr1)
				destroyAndPush(lnbr2)
			else
				touchd(lnbr1, touchedDestroyedSlabs)
				touchd(lnbr2, touchedDestroyedSlabs)
			end
			if IsValid(right) or #(right or "") > 0 then
				local nbr1, nbr2 = slab:GetNeighboursAroundCorner(SlabNeighbourMask.Right)
				destroyAndPush(rnbr1)
				destroyAndPush(rnbr2)
			else
				touchd(rnbr1, touchedDestroyedSlabs)
				touchd(rnbr2, touchedDestroyedSlabs)
			end
			
			AddWallBox(slab:GetObjectBBox(), not top and extrudeBoxWith)
		elseif IsKindOf(slab, "RoofPlaneSlab") and slab.roof_comp ~= "Gable" then
			MapForEach(slab:GetObjectBBox(), "RoofPlaneSlab", function(o, slab)
				--destroy all roof planes on the same 2d pos
				if o ~= slab then
					o:Destroy()
				end
			end, slab)
			processStackedRoofs(slab, "Destroy")
			processWallsBelowRoofPlanes(slab, "Destroy")
			for i = 0, 3 do
				processRoofEdgeNbrHelper(slab, 1 << i, touchedDestroyedSlabs, touchedSlabs)
				processRoofEdgeNbrHelper(slab, 1 << i, touchedDestroyedSlabs, touchedSlabs, "corner")
			end
			roomsWithDestroyedRoofPlaneSlabs[slab.room] = true
			AddRoofBox(slab:GetObjectBBox(), slab)
			
			local ceiling = MapGetFirst(slab, 1, "CeilingSlab", nil, const.efVisible)
			if ceiling then
				local cx, cy, cz = ceiling:GetPosXYZ()
				local sx, sy, sz = slab:GetPosXYZ()
				local range = voxelSizeZ * (slab:GetSeed(2, 2179) + 1)
				if sz >= cz and sz - cz <= range then
					ceiling:Destroy()
				end
			end
		elseif IsKindOf(slab, "RoofEdgeSlab") then
			if slab.roof_comp ~= "Gable" then
				processWallsBelowEaves(slab, "Destroy")
				local nbr = slab:TryGetAdjacentRoofPlane()
				if IsValid(nbr) then
					nbr:Destroy()
				end
			end
			roomsWithDestroyedRoofEdgeSlabs[slab.room] = true
		elseif IsKindOf(slab, "SlabWallObject") then
			processCornerNbrHelper(slab, SlabNeighbourMask.Left, touchedDestroyedSlabs, touchedSlabs)
			processCornerNbrHelper(slab, SlabNeighbourMask.Right, touchedDestroyedSlabs, touchedSlabs)
			AddWallBox(slab:GetObjectBBox())
			for _, nbr in ipairs(slab:GetNeighboursAroundCorner(SlabNeighbourMask.Left) or empty_table) do
				touch(nbr, touchedSlabs)
			end
			for _, nbr in ipairs(slab:GetNeighboursAroundCorner(SlabNeighbourMask.Right) or empty_table) do
				touch(nbr, touchedSlabs)
			end
		elseif IsKindOf(slab, "FloorSlab") then
			destroyedFloorMap[EncodeVoxelPos(slab)] = true
			AddFloorBox(slab:GetObjectBBox())
		elseif IsKindOf(slab, "RoomCorner") then
			AddWallBox(slab:GetObjectBBox(), not top and extrudeBoxWith)
		end
		
		processNeighbours(left, SlabNeighbourMask.Left, touchedDestroyedSlabs, touchedSlabs)
		processNeighbours(right, SlabNeighbourMask.Right, touchedDestroyedSlabs, touchedSlabs)
		processNeighbours(top, SlabNeighbourMask.Top, touchedDestroyedSlabs, touchedSlabs)
		processNeighbours(bottom, SlabNeighbourMask.Bottom, touchedDestroyedSlabs, touchedSlabs)
		
		if rawget(slab, "roof_comp") == "Gable" then
			processGableEdges(slab, "Destroy")
		end
		
		if #DestroyedSlabsThisTick > 0 then
			table.iappend(lst, DestroyedSlabsThisTick)
			DestroyedSlabsThisTick = {}
		end
		i = i + 1
	end
	local processedDestroyedThisPass = lst
	--repaired slabs
	lst = RepairedSlabsThisTick
	RepairedSlabsThisTick = {}
	i = 1
	
	while i <= #lst do
		local slab = lst[i]
		slab:SetRepairedState()
		touch(slab, touchedSlabs)
		--process neighbours
		for i = 0, 3 do
			processRepairedNbr(slab, 1 << i, touchedDestroyedSlabs, touchedSlabs)
		end
		
		if IsKindOf(slab, "WallSlab") then
			if IsKindOf(slab, "RoofWallSlab") then
				--these stack, destroy all stacked pieces
				processStackedRoofWalls(slab, "Repair")
			end
			--check for nbr corners and figure out what to do
			processRepairedCornerNbrHelper(slab, SlabNeighbourMask.Right, touchedDestroyedSlabs, touchedSlabs)
			processRepairedCornerNbrHelper(slab, SlabNeighbourMask.Left, touchedDestroyedSlabs, touchedSlabs)
			--intentionally don't repair floors and t junctions
		elseif IsKindOf(slab, "RoofPlaneSlab") and slab.roof_comp ~= "Gable" then
			processStackedRoofs(slab, "Repair")
			processWallsBelowRoofPlanes(slab, "Repair")
			for i = 0, 3 do
				processRepairedRoofEdgeNbrHelper(slab, 1 << i, touchedDestroyedSlabs, touchedSlabs)
				processRepairedRoofEdgeNbrHelper(slab, 1 << i, touchedDestroyedSlabs, touchedSlabs, "corner")
			end
		elseif IsKindOf(slab, "RoofEdgeSlab") then
			if slab.roof_comp ~= "Gable" then
				processWallsBelowEaves(slab, "Repair")
			end
		end
		
		if rawget(slab, "roof_comp") == "Gable" then
			processGableEdges(slab, "Repair")
		end
		
		if #RepairedSlabsThisTick > 0 then
			table.iappend(lst, RepairedSlabsThisTick)
			RepairedSlabsThisTick = {}
		end
		i = i + 1
	end
	
	--check for islands
	local connectedSlabs = {}
	local disconnectedSlabs = {}
	local allDestroyed = SlabNeighbourMask.AllDestroyed
	for slab, _ in sorted_handled_obj_key_pairs(touchedSlabs) do
		if IsKindOf(slab, "RoofWallSlab") then
			--if the tile is not voxel aligned not much we can do with it.
			local x1, y1, z1 = WallVoxelToWorld(WallWorldToVoxel(slab))
			local x2, y2, z2 = slab:GetPosXYZ()
			if x1 ~= x2 or y1 ~= y2 then
				connectedSlabs[slab] = true
			end
		end
		
		if not IsKindOfClasses(slab, "WallSlab", "FloorSlab", "RoofPlaneSlab", "CeilingSlab", "SlabWallObject", "RoofEdgeSlab", "RoofCorner") then --only these support structures and such for now
			connectedSlabs[slab] = true
		elseif IsKindOf(slab, "RoofPlaneSlab") and slab.roof_comp == "Gable" then
			connectedSlabs[slab] = true
		elseif not disconnectedSlabs[slab] and not connectedSlabs[slab] then
			local waveFront = {slab}
			local passed = {}
			local waveIsConnected = false
			local count = 0 --for dbg
			
			while #waveFront > 0 do
				local nxtSlab = waveFront[#waveFront]
				waveFront[#waveFront] = nil
				waveFront[nxtSlab] = nil
				assert(not passed[nxtSlab])
				passed[nxtSlab] = true
				local isLarge = IsKindOf(nxtSlab, "SlabWallObject")
				
				if not waveIsConnected then
					if connectedSlabs[nxtSlab] or nxtSlab:IsStructuralSlab() then
						waveIsConnected = true
						--DbgAddVector(nxtSlab:GetPos())
						break
					end
				end
				
				local function pushNbr(nbr)
					if IsValid(nbr) then
						if nbr and (not nbr.is_destroyed or nbr.use_replace_ent_destruction) and not passed[nbr] and not waveFront[nbr] then
							table.insert(waveFront, nbr)
							waveFront[nbr] = true
						end
					elseif type(nbr) == "table" then
						for i = 1, #nbr do
							pushNbr(nbr[i])
						end
					end
				end
				
				local sm = nxtSlab.destroyed_neighbours
				local topNbr, botNbr, leftNbr, rightNbr
				if (sm & SlabNeighbourMask.Top) == 0 or isLarge then
					local nbr = nxtSlab:GetNeighbour(SlabNeighbourMask.Top)
					topNbr = nbr
					pushNbr(nbr)
				end
				
				if (sm & SlabNeighbourMask.Left) == 0 or isLarge then
					local nbr = nxtSlab:GetNeighbour(SlabNeighbourMask.Left)
					leftNbr = nbr
					pushNbr(nbr)
				end
				
				local snbr1, snbr2 = nxtSlab:GetNeighboursAroundCorner(SlabNeighbourMask.Left) --propagate sideways around corners
				pushNbr(snbr1)
				pushNbr(snbr2)
				
				if (sm & SlabNeighbourMask.Right) == 0 or isLarge then
					local nbr = nxtSlab:GetNeighbour(SlabNeighbourMask.Right)
					rightNbr = nbr
					pushNbr(nbr)
				end
				
				snbr1, snbr2 = nxtSlab:GetNeighboursAroundCorner(SlabNeighbourMask.Right) --propagate sideways around corners
				pushNbr(snbr1)
				pushNbr(snbr2)
				
				if (sm & SlabNeighbourMask.Bottom) == 0 or isLarge then
					local nbr = nxtSlab:GetNeighbour(SlabNeighbourMask.Bottom)
					botNbr = nbr
					pushNbr(nbr)
				end
				
				if IsKindOf(nxtSlab, "WallSlab") then
					--look for floors
					pushNbr(nxtSlab:GetNeighbourFloor(SlabNeighbourMask.Top))
					pushNbr(nxtSlab:GetNeighbourFloor(SlabNeighbourMask.Bottom))
					--add roof planes above roof walls as nbrs
					if not topNbr then --if we got a destroyed top nbr it exists, if it wasn't destroyed and we didn't get it it doesn't, so we must be @ the top row
						local nbr = nxtSlab:TryGetAdjacentRoofPlane("aboveOnly")
						pushNbr(nbr)
					end
					pushNbr(nxtSlab:TryGetAdjacentRoofPlaneInFront()) --eaves sticking out of walls
				elseif IsKindOfClasses(nxtSlab, "RoofPlaneSlab", "DestroyableFloorSlab") then
					--add roof walls below roof planes as nbrs
					--or add walls nbring floors
					if not topNbr then
						pushNbr(nxtSlab:GetNeighbourWallSlab(SlabNeighbourMask.Top))
					end
					if not botNbr then
						pushNbr(nxtSlab:GetNeighbourWallSlab(SlabNeighbourMask.Bottom))
					end
					if not leftNbr then
						pushNbr(nxtSlab:GetNeighbourWallSlab(SlabNeighbourMask.Left))
					end
					if not rightNbr then
						pushNbr(nxtSlab:GetNeighbourWallSlab(SlabNeighbourMask.Right))
					end
					
					--check for stairs around floors and treat them as structure, since they are invulnerable
					pushNbr(nxtSlab:GetStairNeighbours())
					if IsKindOf(nxtSlab, "RoofPlaneSlab") then
						if not topNbr then
							pushNbr(nxtSlab:GetNeighbourEdge(SlabNeighbourMask.Top))
						end
						if not botNbr then
							pushNbr(nxtSlab:GetNeighbourEdge(SlabNeighbourMask.Bottom))
						end
						if not leftNbr then
							pushNbr(nxtSlab:GetNeighbourEdge(SlabNeighbourMask.Left))
						end
						if not rightNbr then
							pushNbr(nxtSlab:GetNeighbourEdge(SlabNeighbourMask.Right))
						end
					end
				elseif IsKindOf(nxtSlab, "RoofEdgeSlab") then
					pushNbr(nxtSlab:TryGetAdjacentRoofPlane())
					if not leftNbr then
						pushNbr(nxtSlab:GetNeighbourCorner(SlabNeighbourMask.Left))
					end
					if not rightNbr then
						pushNbr(nxtSlab:GetNeighbourCorner(SlabNeighbourMask.Right))
					end
				end
				
				count = count + 1
			end
			--print(count)
			local t = waveIsConnected and connectedSlabs or disconnectedSlabs
			for slab2, _ in pairs(passed) do
				t[slab2] = true
			end
		end
	end
	
	local destroyed_disconnected = 0
	for slab, _ in sorted_handled_obj_key_pairs(disconnectedSlabs) do
		--force vulnerable if it is due to material or ld mark, will not force to vulnerable if it is invulnerable due to being interactable or any other reason.
		--also, only invulnerable doors are not structural
		--http://mantis.haemimontgames.com/view.php?id=206986
		slab.invulnerable = false
		slab:Destroy()
		destroyed_disconnected = destroyed_disconnected + 1
	end
	
	if inEditor and destroyed_disconnected > 0 then
		print(string.format("<color 165 0 255>%d slabs were not connected to structural slabs and were destroyed!</color>", destroyed_disconnected))
	end
	
	for slab, _ in sorted_handled_obj_key_pairs(touchedSlabs) do
		if IsValid(slab) and connectedSlabs[slab] then --small window fake slabs may become invalid if the window was destroyed since we touched them
			slab:UpdateEntity()
			slab:UpdateVariantEntities()
			slab:UpdateDecorationsDestroyedState()
		end
	end
	
	for slab, _ in sorted_handled_obj_key_pairs(touchedDestroyedSlabs) do
		if not table.find(DestroyedSlabsThisTick, slab) then --got destroyed this tick, it will update next tick
			slab:UpdateEntity()
		end
	end
	
	for room, _ in pairs(roomsWithDestroyedRoofPlaneSlabs) do
		if room then
			Notify(room, "OnRoofPlaneTilesDestroyed")
		end
	end
	
	for room, _ in pairs(roomsWithDestroyedRoofEdgeSlabs) do
		if room then
			Notify(room, "OnRoofEdgeTilesDestroyed")
		end
	end
	
	for room, _ in pairs(roomsWithDestroyedSlabs) do
		Notify(room, "OnSlabsDestroyed")
	end

	ProcessObjectsAroundSlabs(destroyedFloorBoxes, destroyedFloorMap, destroyedWallBoxes, destroyedRoofBoxes, destroyedWallBoxesOnTop)
	
	if inEditor then
		--reselect destroyed slabs because their selection box disappears
		local sel = editor.GetSel()
		for i = #(sel or ""), 1, -1 do
			local o = sel[i]
			if touchedDestroyedSlabs[o] then
				editor.RemoveObjFromSel(o, true)
				--editor.AddObjToSel(o, true)
			end
		end
	end
	
	return processedDestroyedThisPass
end

---
--- Checks if the interior lighting should be disabled for the volume based on the destruction percentage of the spawned objects.
--- If more than 40% of the spawned objects are destroyed, the interior lighting is disabled for the volume.
---
--- @param self Volume The volume object.
---
function Volume:CheckInteriorLightingOnDestruction()
	if self.dont_use_interior_lighting or self:IsRoofOnly() then return end
	if IsEditorActive() then return end
	--if more than 40% destroyed?
	local total = 0
	local destroyed = 0
	self:ForEachSpawnedObj(function(o)
		if o.isVisible then
			total = total + 1
			if o.is_destroyed then
				destroyed = destroyed + 1
			end
		end
	end)
	
	local perc = MulDivRound(destroyed, 100, total)
	if perc >= 40 then
		self:Setdont_use_interior_lighting(true)
	end
end

---
--- Called when slabs in the volume have been destroyed.
--- Checks if the interior lighting should be disabled for the volume based on the destruction percentage of the spawned objects.
---
--- @param self Volume The volume object.
---
function Volume:OnSlabsDestroyed()
	self:CheckInteriorLightingOnDestruction()
end

MapGameTimeRepeat("DestructionPP", -1, function()
	WaitWakeup()
	Sleep(0) --cmd objs hit directly need a bit for their command to fire, wait for them;
	ProcessDestroyedObjectsThisTick()
end)

---
--- Wakes up the "DestructionPP" periodic repeat thread to process destroyed objects.
---
--- If the editor is active, the processing is delayed by one frame to ensure it works correctly in the editor.
--- If the editor is not active, the "DestructionPP" periodic repeat thread is woken up directly.
---
function WakeUpDestructionPP()
	--needs to be real time in f3 so it works for ld
	--needs to be game time not in f3 so it works in mp
	local editor = IsEditorActive()
	if editor then
		DelayedCall(0, ProcessDestroyedObjectsThisTick)
	else
		Wakeup(PeriodicRepeatThreads["DestructionPP"])
	end
end

---
--- Appends a destroyed slab object to the list of destroyed slabs for this tick.
--- Also wakes up the "DestructionPP" periodic repeat thread to process the destroyed objects.
---
--- @param obj Destroyable The destroyed slab object to append.
---
function AppendDestroyedSlab(obj)
	NetUpdateHash("AppendDestroyedSlab", obj)
	table.insert(DestroyedSlabsThisTick, obj)
	WakeUpDestructionPP()
end

---
--- Appends a repaired slab object to the list of repaired slabs for this tick.
--- Also wakes up the "DestructionPP" periodic repeat thread to process the repaired objects.
---
--- @param obj Destroyable The repaired slab object to append.
---
function AppendRepairedSlab(obj)
	table.insert(RepairedSlabsThisTick, obj)
	WakeUpDestructionPP()
end


---
--- Handles the destruction of a combat object.
---
--- If the object is a Unit, it is added to the list of destroyed combat objects for the current tick and the "DestructionPP" periodic repeat thread is woken up to process the destroyed objects.
--- If the object is not a Unit, it is simply destroyed.
---
--- @param obj CObject The combat object to be destroyed.
---
function DoneCombatObject(obj)
	if IsKindOf(obj, "Unit") or not IsKindOf(obj, "CObject") then
		table.insert(DestroyedCOThisTick, obj)
		WakeUpDestructionPP()
	else
		obj:Destroy() --treat non unit co as generic destroyables
	end
end

DefineClass.DestroyableSlab = {
	__parents = { "Destroyable" },
	properties = {
		{ id = "destroyed_neighbours", editor = "number", default = 0, no_edit = true },
		{ id = "destroyed_entity", editor = "string", default = false, no_edit = true },
		{ id = "destroyed_entity_side", editor = "number", default = 0, no_edit = true },
		{ id = "pre_destruction_subvariant", editor = "number", default = -1, no_edit = true },
		{ id = "da_subvariants", editor = "prop_table", default = false, no_edit = true }, --.da_subvariants = {[id] = subvar, ...
		{ id = "force_destroyed_entity", editor = "bool", default = false, no_edit = true },
		{ category = "Slabs", id = "force_no_destroyed_entity", name = "Force No Destroyed Entity", editor = "bool", default = false, help = "If true, this slab will never look partially damaged due to neighbour being destroyed." },
		{ category = "Slabs", id = "force_structural", name = "Force Structural", editor = "bool", default = false, },
		
		{ category = "Slabs", id = "buttons2", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Destroy", func = "DestroyFromEditor"},
				{name = "Repair", func = "Repair"},
			},
		},
	},
	
	destroyed_attaches = false, --attaches don't get saved so rebuild them
	diagonal_ent_mask = 0, --mark which sides the diag ent covers,
	invulnerable = true, --by default, all are invulnerable so hand placed slabs are invulnerable, room and roof try to make all their owned slabs vulnerable
	origin_of_destruction = false,
	play_size_fx = false,
	
	selection_marker = false,
	collision_mask = false, --this preserves cm for repair purposes
	use_replace_ent_destruction = false, --used to distinguish the type of destruction to use with this obj
}

local function EnumNeighbours(nbr, func)
	if IsValid(nbr) then
		func(nbr)
	elseif type(nbr) == "table" then
		for i = 1, #nbr do
			func(nbr[i])
		end
	end
end

function DestroyableSlab:ManageSelectionMarker(create)
end

---
--- Sets whether this DestroyableSlab should force no destroyed entity.
---
--- If `val` is `true`, this slab will never look partially damaged due to a neighbor being destroyed. If `val` is `false`, the slab will update its appearance based on the destruction state of its neighbors.
---
--- If `val` is set to `true`, the slab will be repaired. If `val` is set to `false`, the slab will check its neighbors and append any destroyed slabs.
---
--- @param val boolean Whether to force no destroyed entity
function DestroyableSlab:Setforce_no_destroyed_entity(val)
	self.force_no_destroyed_entity = val
	if val then
		self:Repair()
	else
		local t = {self:GetNeighbours()}
		for _, nbrs in ipairs(t) do
			EnumNeighbours(nbrs, function(nbr)
				if nbr.is_destroyed then
					AppendDestroyedSlab(nbr)
				end
			end)
		end
	end
end

---
--- Restores the pre-destruction subvariant of the DestroyableSlab.
---
--- This function is used to reset the subvariant of the DestroyableSlab to its state before it was destroyed. The `pre_destruction_subvariant` field is used to store the original subvariant, which is then restored when this function is called.
---
--- @function DestroyableSlab:RestorePreDestructionSubvariant
--- @return nil
function DestroyableSlab:RestorePreDestructionSubvariant()
	self.subvariant = self.pre_destruction_subvariant
	self.pre_destruction_subvariant = -1
end

---
--- Unlocks the subvariant of the DestroyableSlab, making it reversible.
---
--- This function stores the current subvariant of the DestroyableSlab in the `pre_destruction_subvariant` field, and then sets the `subvariant` field to -1. This allows the subvariant to be restored later using the `RestorePreDestructionSubvariant` function.
---
--- @function DestroyableSlab:UnlockSubvariantReversible
--- @return nil
function DestroyableSlab:UnlockSubvariantReversible()
	self.pre_destruction_subvariant = self.subvariant
	self.subvariant = -1
end

---
--- Resets the destroyed state of the DestroyableSlab.
---
--- This function resets various fields related to the destroyed state of the DestroyableSlab, including:
---
--- - `is_destroyed`: Whether the slab is destroyed
--- - `destroyed_neighbours`: The destroyed neighbors of the slab
--- - `destroyed_entity`: The destroyed entity associated with the slab
--- - `destroyed_entity_side`: The side of the slab where the destroyed entity is located
--- - `force_no_destroyed_entity`: Whether to force no destroyed entity
--- - `force_destroyed_entity`: Whether to force a destroyed entity
--- - `da_subvariants`: The subvariants of the slab when it is damaged
--- - `diagonal_ent_mask`: The diagonal entity mask of the slab
--- - `use_replace_ent_destruction`: Whether to use replace entity destruction
--- - `destroyed_attaches`: The destroyed attachments of the slab
---
--- This function is used to reset the destroyed state of the DestroyableSlab, for example, when the slab is repaired.
---
--- @function DestroyableSlab:ResetDestroyedState
--- @return nil
function DestroyableSlab:ResetDestroyedState()
	self.is_destroyed = nil
	self.destroyed_neighbours = nil
	self.destroyed_entity = nil
	self.destroyed_entity_side = nil
	self.force_no_destroyed_entity = nil
	self.force_destroyed_entity = nil
	self.da_subvariants = nil
	self.diagonal_ent_mask = nil
	self.use_replace_ent_destruction = nil
	for k, v in pairs(self.destroyed_attaches or empty_table) do
		DoneObject(v)
	end
	self.destroyed_attaches = nil
end

---
--- Destroys the DestroyableSlab.
---
--- This function is called when the DestroyableSlab is destroyed. It logs a debug message to the combat log and then calls the `Destroy` function to handle the destruction of the slab.
---
--- @function DestroyableSlab:Die
--- @return nil
function DestroyableSlab:Die()
	--command func called on death
	CombatLog("debug", T{Untranslated("  <name> was destroyed"), name = self:GetLogName()})
	self:Destroy()
end

--resolve inheritence, zulu specific
Slab.Die = DestroyableSlab.Die
--corners only get destroyed trhough nbr walls
RoomCorner.Die = empty_func

---
--- Destroys the DestroyableSlab from the editor.
---
--- This function is called when the DestroyableSlab needs to be destroyed from the editor. It first sets the `force_invulnerable_because_of_game_rules` flag to false, and then calls the `Destroy()` function to handle the destruction of the slab.
---
--- @function DestroyableSlab:DestroyFromEditor
--- @return nil
function DestroyableSlab:DestroyFromEditor()
	self:SetforceInvulnerableBecauseOfGameRules(false)
	self:Destroy()
end

dbgForceUseDamaged = false
---
--- Determines whether the DestroyableSlab should use replace entity destruction.
---
--- This function checks if the editor is active or if `dbgForceUseDamaged` is true. If either of these conditions is met, it retrieves the material preset for the slab and checks if `use_damaged` is true or if `use_damaged_first_floor` is true and the slab is on the first floor. If either of these conditions is met, the function returns `true`, indicating that replace entity destruction should be used.
---
--- @return boolean
--- @function DestroyableSlab:ShouldUseReplaceEntDestruction
function DestroyableSlab:ShouldUseReplaceEntDestruction()
	--figure out destruction type, i.e. use_replace_ent_destruction = ?
	if not IsEditorActive() or dbgForceUseDamaged then
		local svd = self:GetMaterialPreset()
		if svd.use_damaged or (svd.use_damaged_first_floor and self.floor == 1) then
			return true
		end
	end
end

---
--- Destroys the DestroyableSlab.
---
--- This function is called when the DestroyableSlab needs to be destroyed. It first checks if the slab is already destroyed or invulnerable, and returns if either of these conditions is true. It then unlocks the subvariant reversible, sets the origin of destruction, calls the base `Destroy()` function, determines if replace entity destruction should be used, appends the destroyed slab, and manages the selection marker.
---
--- @param origin_of_destruction any The origin of the destruction, which can be any value.
--- @return nil
function DestroyableSlab:Destroy(origin_of_destruction)
	if self.is_destroyed or self:IsInvulnerable() then
		return
	end
	
	self:UnlockSubvariantReversible() --clear user selected subvar on death
	self.origin_of_destruction = origin_of_destruction
	Destroyable.Destroy(self)
	
	self.use_replace_ent_destruction = self:ShouldUseReplaceEntDestruction()
	
	AppendDestroyedSlab(self)
	self:ManageSelectionMarker(true and not self.use_replace_ent_destruction)
end

---
--- Repairs a DestroyableSlab by restoring its pre-destruction state.
---
--- This function first checks if the slab is not already destroyed. If it is not destroyed, it checks if the slab has a destroyed entity. If so, it retrieves the side of the destroyed entity, checks if the slab is a RoofWallSlab, and gets the neighboring slabs. It then resets the destroyed entity properties, suspends pass edits, and updates the neighboring slabs' destroyed state. Finally, it restores the pre-destruction subvariant, updates the entity and variant entities, and propagates the repair to other stacked slabs if the slab is a RoofWallSlab.
---
--- If the slab is already destroyed, it restores the pre-destruction subvariant, clears the `da_subvariants` and `diagonal_ent_mask` properties, calls the base `Repair()` function, appends the repaired slab, and manages the selection marker.
---
--- @param dont_propagate boolean (optional) If true, the repair will not be propagated to other stacked slabs.
--- @return nil
function DestroyableSlab:Repair(dont_propagate)
	if not self.is_destroyed then
		if self.destroyed_entity then
			local side = self.destroyed_entity_side
			local isStacked = IsKindOf(self, "RoofWallSlab")
			local nbrs = self:GetNeighbour(side, isStacked or nil) --roof wall slabs are sometimes stacked, need to fix all nbrs in that case
			self.destroyed_entity_side = 0
			self.destroyed_entity = false
			self.force_no_destroyed_entity = true
			self.force_destroyed_entity = false
			SuspendPassEdits("DestroyableSlab:Repair")
			if nbrs then
				nbrs = IsValid(nbrs) and {nbrs} or nbrs
				for _, nbr in ipairs(nbrs) do
					if nbr.da_subvariants then
						--DbgAddCircle(nbr:GetPos(), 200)
						local f = GetNeigbhourSideFlagTowardMe(side, nbr, self)
						local offset = nbr:GetDestroyedAttachOffset(f, self)
						local id = GetDestroyedSlabAttachId(f, offset)
						nbr.da_subvariants[id] = nil
						if not next(nbr.da_subvariants) then
							nbr.da_subvariants = nil
						end
					end
					nbr:UpdateDestroyedState()
				end
			end
			
			self:RestorePreDestructionSubvariant()
			self:UpdateEntity()
			self:UpdateVariantEntities()
			
			if not dont_propagate and isStacked then
				local lst = MapGet(self, 0, self.class)
				for _, slab in ipairs(lst) do
					if slab ~= self then
						slab:Repair("dont_propagate")
					end
				end
			end
			ResumePassEdits("DestroyableSlab:Repair")
		end
		return
	end
	
	self:RestorePreDestructionSubvariant()
	self.da_subvariants = nil
	self.diagonal_ent_mask = nil
	Destroyable.Repair(self)
	AppendRepairedSlab(self)
	self:ManageSelectionMarker(false)
end

---
--- Sets the destroyed state of a SlabWallObject.
---
--- This function calls `DestroyableSlab.SetDestroyedState()` to set the destroyed state of the object.
--- It then updates the managed slabs and objects, and destroys any attached entities.
---
--- @param self SlabWallObject The SlabWallObject instance.
---
function SlabWallObject:SetDestroyedState()
	DestroyableSlab.SetDestroyedState(self)
	self:UpdateManagedSlabs()
	self:UpdateManagedObj()
	self:DestroyAttaches()
end

---
--- Sets the destroyed state of a DestroyableFloorSlab.
---
--- This function calls `DestroyableSlab.SetDestroyedState()` to set the destroyed state of the object.
--- If the `use_replace_ent_destruction` flag is not set, it also sets the angle of the slab to 0.
---
--- @param self DestroyableFloorSlab The DestroyableFloorSlab instance.
--- @param ... Any additional arguments to pass to `DestroyableSlab.SetDestroyedState()`.
---
function DestroyableFloorSlab:SetDestroyedState(...)
	DestroyableSlab.SetDestroyedState(self, ...)
	if not self.use_replace_ent_destruction then
		self:SetAngle(0)
	end
end

---
--- Sets the destroyed state of a DestroyableSlab.
---
--- This function sets the destroyed state of a DestroyableSlab. It performs the following actions:
--- - Stores the current collision mask of the slab
--- - Clears the `force_no_destroyed_entity` and `force_destroyed_entity` flags
--- - If `no_debris` is false, it calls `SpreadDebris()` to spread debris around the slab
--- - Calls `DestroyAttaches()` to destroy any attached entities
--- - Sets the `destroyed_attaches` flag to false
--- - Clears the `efCollision` and `efApplyToGrids` enum flags
--- - Sets the allowed collision mask to 0
--- - Sends a "DestroyableSlabDestroyed" message
---
--- @param self DestroyableSlab The DestroyableSlab instance.
--- @param no_debris boolean (optional) If true, no debris will be spread.
---
function DestroyableSlab:SetDestroyedState(no_debris)
	self.collision_mask = collision.GetAllowedMask(self)
	self.force_no_destroyed_entity = nil
	self.force_destroyed_entity = nil
	if not no_debris then
		--attaches spread debris, so b4 destroyattaches
		self:SpreadDebris()
	end
	self:DestroyAttaches()
	self.destroyed_attaches = false
	self:ClearEnumFlags(const.efCollision + const.efApplyToGrids)
	collision.SetAllowedMask(self, 0)
	Msg("DestroyableSlabDestroyed", self, no_debris)
end

---
--- Sets the repaired state of a DestroyableSlab.
---
--- This function performs the following actions to set the repaired state of a DestroyableSlab:
--- - Calls `DestroyAttaches()` to destroy any attached entities
--- - Sets the `destroyed_attaches` flag to false
--- - Sets the `use_replace_ent_destruction` flag to false
--- - Sets the `efCollision` and `efApplyToGrids` enum flags
--- - Restores the allowed collision mask to the original value stored in `collision_mask`
--- - Sets the state of the slab to "idle"
---
--- @param self DestroyableSlab The DestroyableSlab instance.
---
function DestroyableSlab:SetRepairedState()
	self:DestroyAttaches()
	self.destroyed_attaches = false
	self.use_replace_ent_destruction = false
	self:SetEnumFlags(const.efCollision + const.efApplyToGrids)
	collision.SetAllowedMask(self, self.collision_mask or 0)
	self:SetState("idle")
end

local details_cache = {}

local function GetDebrisLOD()
	local detail = EngineOptions.ObjectDetail
	local LOD = details_cache[detail]
	if LOD then
		return LOD
	end
	
	LOD = table.find_value(OptionsData.Options.ObjectDetail, "value", detail).ObjectLODPercents
	details_cache[detail] = LOD
	
	return LOD		
end

---
--- Gets the debris information for a DestroyableSlab or an optional entity.
---
--- This function retrieves the debris information for a DestroyableSlab or an optional entity. It returns the following:
---
--- - `count`: The number of debris pieces to spawn, based on the current object detail level.
--- - `classes`: A table of debris classes and their weights, used to randomly select debris types.
--- - `radius`: The radius around the origin of destruction to spread the debris.
---
--- @param entity Entity The optional entity to get debris information for. If not provided, the DestroyableSlab's entity is used.
--- @return number count The number of debris pieces to spawn.
--- @return table classes The table of debris classes and weights.
--- @return number radius The radius around the origin of destruction to spread the debris.
function DestroyableSlab:GetDebrisInfo(entity)
	local classes, debris_min, debris_max = GetDebrisInfo(entity or self:GetEntity())
	if not classes then
		return 0
	end
	
	local LOD = GetDebrisLOD()
	local count = classes and ((debris_min + self:Random(debris_max - debris_min + 1)) * LOD / 100) or 0
	local radius = const.DebrisExplodeRadius

	return count, classes, radius
end

---
--- Spreads debris around the specified object.
---
--- This function is responsible for spawning debris pieces around a DestroyableSlab or other object. It takes the following parameters:
---
--- - `self`: The object that is being destroyed and spawning debris.
--- - `count`: The number of debris pieces to spawn.
--- - `debris_classes`: A table of debris classes and their weights, used to randomly select debris types.
--- - `radius`: The radius around the origin of destruction to spread the debris.
--- - `origin_of_destruction`: The optional origin point for the debris explosion.
---
--- The function plays a "SpreadDebris" FX at the object's position, and then spawns the debris pieces. Each debris piece is placed using the `PlaceObject` function, with its color set to match the object. The debris pieces are then started in the "Explode" phase, with the specified position, radius, and origin of destruction.
---
--- The function also includes a throttling mechanism to limit the number of debris pieces spawned per frame, to avoid performance issues.
---
function SpreadDebris(self, count, debris_classes, radius, origin_of_destruction)
	PlayFX("SpreadDebris", "explosion", self, self.material)
	local slab_pos = self:GetPos()
	for i = 1, count do
		debrisThisTick = debrisThisTick + 1
		--throttle debris
		local div = Min(((debrisThisTick) / 100) + 1, 10)
		if (debrisThisTick % div) ~= 0 then
			goto vlad
		end
		local slot = self:Random(debris_classes.total_weight)
		local idx = GetRandomItemByWeight(debris_classes, slot, "weight")
		local class = debris_classes[idx].class
		local debris = PlaceObject(class)
		debris.spawning_obj = self
		debris:SetColorization(self)
		debris:StartPhase("Explode", slab_pos, radius, origin_of_destruction or self.origin_of_destruction)
		--debris:BootDebris("Explode", slab_pos, radius, origin_of_destruction or self.origin_of_destruction) --this basically shifts the hit from creating mny gtts to a later frame
		::vlad::
	end
end

---
--- Spreads debris around the specified DestroyableSlab object.
---
--- This function is responsible for spawning debris pieces around a DestroyableSlab object. It takes the following parameters:
---
--- - `self`: The DestroyableSlab object that is being destroyed and spawning debris.
--- - `count`: The number of debris pieces to spawn.
--- - `debris_classes`: A table of debris classes and their weights, used to randomly select debris types.
--- - `radius`: The radius around the origin of destruction to spread the debris.
---
--- The function plays a "SpreadDebris" FX at the object's position, and then spawns the debris pieces. Each debris piece is placed using the `PlaceObject` function, with its color set to match the object. The debris pieces are then started in the "Explode" phase, with the specified position, radius, and origin of destruction.
---
--- The function also includes a throttling mechanism to limit the number of debris pieces spawned per frame, to avoid performance issues.
---
function DestroyableSlab:SpreadDebris()
	MapForEach(self:GetObjectBBox():grow(halfVoxelSizeX / 4, halfVoxelSizeY / 4, halfVoxelSizeZ / 4), "Debris", DoneObject)
	
	local count, debris_classes, radius = self:GetDebrisInfo()
	if count <= 0 then return end
	
	SpreadDebris(self, count, debris_classes, radius)
end

---
--- Spreads debris around the specified WallSlab object and its variant objects.
---
--- This function is responsible for spawning debris pieces around a WallSlab object and its variant objects. It takes the following steps:
---
--- 1. Calls `MapForEach` to find all "Debris" objects within the WallSlab's bounding box, and marks them as "DoneObject".
--- 2. Calls `self:GetDebrisInfo()` to get the count, debris classes, and radius for the WallSlab object.
--- 3. If the count is greater than 0, it calls `SpreadDebris()` to spawn the debris pieces around the WallSlab object.
--- 4. For each variant object of the WallSlab, it calls `self:GetDebrisInfo()` to get the count, debris classes, and radius, and then calls `SpreadDebris()` to spawn the debris pieces around the variant object, using the WallSlab's origin of destruction.
---
--- The function uses the `SpreadDebris()` function to actually spawn the debris pieces, passing in the necessary parameters.
---
function WallSlab:SpreadDebris()
	MapForEach(self:GetObjectBBox():grow(halfVoxelSizeX / 4, halfVoxelSizeY / 4, halfVoxelSizeZ / 4), "Debris", DoneObject)
	
	local count, debris_classes, radius = self:GetDebrisInfo()
	if count > 0 then
		SpreadDebris(self, count, debris_classes, radius)
	end
		
	for _, o in ipairs(self.variant_objects or empty_table) do
		count, debris_classes, radius = self:GetDebrisInfo(o:GetEntity())
		if count > 0 then
			SpreadDebris(o, count, debris_classes, radius, self.origin_of_destruction)
		end
	end
end

const.TestExplodeRadius = voxelSizeX * 2 + 10

---
--- Explodes a test explosion at the specified position, optionally playing a FX.
---
--- This function is responsible for creating a test explosion at a given position. It takes the following steps:
---
--- 1. If no position is provided, it tries to find the closest visible and non-destroyed Slab object to the mouse cursor.
--- 2. If no Slab object is found, it uses the terrain cursor position as the explosion position.
--- 3. If a FX is provided, it plays the "FragGrenade" FX at the explosion position, using the surface material type.
--- 4. It then finds all Slab objects within the `const.TestExplodeRadius` around the explosion position, and sorts them by distance from the explosion.
--- 5. It then calls the `Destroy()` method on each Slab object, passing the explosion position as a parameter.
---
--- This function is primarily used for debugging and testing purposes, to simulate an explosion and its effects on the surrounding environment.
---
function DbgTestExplode(pt, fx)
	if not pt then
		local eye = camera.GetEye()
		local cursor = ScreenToGame(terminal.GetMousePos())
		local sp = eye
		local ep = (cursor - eye) * 1000 + cursor
		local closest = false
		local objs = IntersectObjectsOnSegment(sp, ep, 0, "Slab", function(o)
			if o.isVisible and not o.is_destroyed then
				closest = not closest and o or IsCloser(sp, o, closest) and o or closest
				return true
			end
		end)
		if closest then
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			pt = p1 or closest:GetPos()
		end
	end
	if not pt then
		pt = GetTerrainCursor()
	end
	
	if fx then
		local terrainPt = GetExplosionDecalPos(pt)
		local surf_fx_type = GetObjMaterial(pt)
		local fxPt = abs(terrainPt:z() - pt:z()) <= voxelSizeZ * 2 and terrainPt or pt
		PlayFX(fx, "start", "FragGrenade", surf_fx_type, fxPt)
	end
	local to_destroy = {}
	MapForEach(pt, const.TestExplodeRadius + voxelSizeX, "Slab", "CeilingSlab", const.efVisible, 0, 0, function(o, pt, rad)
		if IsCloser(o, pt, rad) then
			table.insert(to_destroy, {slab = o, dist = o:GetDist(pt)})
		end
	end, pt, const.TestExplodeRadius)
	table.sort(to_destroy, function(a, b) return a.dist < b.dist end)
	for _, descr in ipairs(to_destroy) do
		descr.slab:Destroy(pt)
	end
end

DefineClass.DestroyableWallDecoration = {
	__parents = { "Destroyable" },
	properties = {
		{ id = "managed_by_slab", editor = "bool", default = true, no_edit = true },
	},
	orig_ent = false, --need this for repair
}

--- Changes the entity of the DestroyableWallDecoration object.
---
--- If the handle of the object is 1415991251, a local variable `a` is set to 9.
---
--- The original entity of the object is stored in the `orig_ent` field, if it hasn't been set already. Then, the `ChangeEntity` function of the `Destroyable` class is called with the new entity.
---
--- @param self DestroyableWallDecoration The DestroyableWallDecoration object.
--- @param ne string The new entity to set.
function DestroyableWallDecoration:ChangeEntity(ne)
	if self.handle == 1415991251 then
		local a = 9
	end
	self.orig_ent = self.orig_ent or self:GetEntity()
	Destroyable.ChangeEntity(self, ne)
end

--- Gets the neighbour of the DestroyableWallDecoration object in the specified direction.
---
--- The function takes a `sideFlag` parameter which specifies the direction to get the neighbour in. The valid values for `sideFlag` are `SlabNeighbourMask.Left`, `SlabNeighbourMask.Right`, `SlabNeighbourMask.Top`, and `SlabNeighbourMask.Bottom`.
---
--- The function first asserts that only one flag is set in the `sideFlag` parameter. It then calculates the position of the neighbour based on the current position and orientation of the DestroyableWallDecoration object. Finally, it uses `MapGetFirst` to find the first object at the calculated position that is either an instance of the same class as the DestroyableWallDecoration object, or has an entity name that starts with "WallDec_".
---
--- @param self DestroyableWallDecoration The DestroyableWallDecoration object.
--- @param sideFlag number The direction to get the neighbour in.
--- @return boolean|CObject The neighbour object, or `false` if no neighbour was found.
function DestroyableWallDecoration:GetNeighbour(sideFlag)
	assert(sideFlag & (sideFlag - 1) == 0) --only 1 flag must be set
	local x, y, z = self:GetPosXYZ()
	local qx, qy, qz
	local s = slabAngleToDir[self:GetAngle()]
	
	if sideFlag == SlabNeighbourMask.Left then
		local offs = wallSidewaysOffsets[s]
		qx, qy, qz = x + offs.x * voxelSizeX, y + offs.y * voxelSizeY, z
	elseif sideFlag == SlabNeighbourMask.Right then
		local offs = wallSidewaysOffsets[s]
		qx, qy, qz = x - offs.x * voxelSizeX, y - offs.y * voxelSizeY, z
	elseif sideFlag == SlabNeighbourMask.Top then
		qx, qy, qz = x, y, z + voxelSizeZ
	elseif sideFlag == SlabNeighbourMask.Bottom then
		qx, qy, qz = x, y, z - voxelSizeZ
	else 
		return false
	end
	--not all decs have the proper class
	return MapGetFirst(qx, qy, qz, 0, "CObject", function(o) return IsKindOf(o, self.class) or o:GetEntity():starts_with("WallDec_") end)
end

--- Gets the neighbours of the DestroyableWallDecoration object.
---
--- If the entity of the object is a horizontal decoration, the function returns the left and right neighbours. Otherwise, it returns the top and bottom neighbours.
---
--- @param self DestroyableWallDecoration The DestroyableWallDecoration object.
--- @return CObject|boolean, CObject|boolean, CObject|boolean, CObject|boolean The left, right, top, and bottom neighbours, or `false` if no neighbour was found.
function DestroyableWallDecoration:GetNeighbours()
	local e = self.orig_ent or self:GetEntity()
	if IsHorizontalDecoration(e) then
		return self:GetNeighbour(SlabNeighbourMask.Left), self:GetNeighbour(SlabNeighbourMask.Right), false, false
	else
		return false, false, self:GetNeighbour(SlabNeighbourMask.Top), self:GetNeighbour(SlabNeighbourMask.Bottom)
	end
end
--stubs for when used in common code with slab objs -> flat roof with parapet atm
--- Sets the colors of the DestroyableWallDecoration object.
---
--- This function sets the colorization of the DestroyableWallDecoration object to the specified value, or to the default colorization set if no value is provided.
---
--- @param self DestroyableWallDecoration The DestroyableWallDecoration object.
--- @param val table|nil The colorization value to set. If `nil`, the default colorization set is used.
function DestroyableWallDecoration:Setcolors(val)
	self:SetColorization(val or self:GetDefaultColorizationSet())
end
--- Sets the interior attachment colors of the DestroyableWallDecoration object.
function DestroyableWallDecoration:Setinterior_attach_colors()
end
function DestroyableWallDecoration:DelayedUpdateEntity()
end
function DestroyableWallDecoration:UpdateVariantEntities()
end
function DestroyableWallDecoration:UpdateEntity()
end
function DestroyableWallDecoration:UnlockSubvariant()
end
function DestroyableWallDecoration:AlignObj()
end


--- Makes all RoofWallSlab objects in the map vulnerable.
---
--- This function iterates through all RoofWallSlab objects in the map and sets their `invulnerable` and `forceInvulnerableBecauseOfGameRules` properties to `false`, making them vulnerable.
function MakeRoofWallSlabVulnerable()
	MapForEach("map", "RoofWallSlab", function(o)
		if o.room then
			o.invulnerable = false
			o.forceInvulnerableBecauseOfGameRules = false
		end
	end)
end

---
--- Iterates through the selected objects in the editor and either destroys or repairs them, depending on the provided `destroy` parameter.
---
--- @param destroy boolean Whether to destroy or repair the selected objects.
--- @param class string|nil The class of the objects to operate on. If `nil`, all selected objects will be processed.
function EditorDestroyRepairSelectedObjs(destroy, class)
	local fname = destroy and "Destroy" or "Repair"
	local sel = editor.GetSel()
	for _, obj in ipairs(sel) do
		if obj:GetEnumFlags(const.efVisible) ~= 0 and (not class or IsKindOf(obj, class)) and obj:HasMember(fname) then --in bacon cobj doesn't have destroy, in zulu it does
			obj[fname](obj)
		end
	end
end