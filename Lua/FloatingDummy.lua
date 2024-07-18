DefineClass.FloatingDummy = {
	__parents = {"Object", "InvisibleObject", "ComponentAnim", },
}

--- Initializes the game state for the FloatingDummy object.
---
--- This function sets the initial animation phase for the FloatingDummy object to a random value within the duration of the animation.
---
--- @param self FloatingDummy The FloatingDummy object instance.
function FloatingDummy:GameInit()
	self:SetAnimPhase(1, self:Random(self:GetAnimDuration()))
end

DefineClass.FloatingDummyCollision = {
	__parents = {"Object" },
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false	},
	clone_of = false,
}

local floating_dummy_attach_clear_enum_flags = const.efWalkable + const.efCollision + const.efApplyToGrids

---
--- Attaches an object to a floating dummy object.
---
--- @param obj CObject The object to be attached to the floating dummy.
--- @param dummy FloatingDummy The floating dummy object to attach the object to.
--- @param parent Object The parent object to attach the object to, if any.
---
--- This function creates a `FloatingDummyCollision` object that acts as a proxy for the original object. The proxy object is attached to the floating dummy, preserving the original object's position, orientation, and other properties. If a parent object is provided, the proxy object is attached to the parent instead of the floating dummy directly.
---
--- The function also handles setting the appropriate enum flags and hierarchy game flags on the original object to ensure it is properly integrated with the floating dummy.
---
--- @return none
function AttachObjectToFloatingDummy(obj, dummy, parent)
	local o = PlaceObject("FloatingDummyCollision")
	NetTempObject(o)
	o.clone_of = obj
	TargetDummies[obj] = o
	o:ChangeEntity(obj:GetEntity())
	local enum_flags = obj:GetEnumFlags(floating_dummy_attach_clear_enum_flags)
	if enum_flags ~= 0 then
		o:SetEnumFlags(enum_flags)
		obj:ClearEnumFlags(enum_flags)
	end
	o:SetState(obj:GetState())
	o:SetMirrored(obj:GetMirrored())
	o:SetScale(obj:GetScale())
	o:SetOpacity(0)
	if parent then
		parent:Attach(o, obj:GetAttachSpot())
		o:SetAttachAxis(obj:GetAttachAxis())
		o:SetAttachAngle(obj:GetAttachAngle())
		o:SetAttachOffset(obj:GetAttachOffset())
	else
		local obj_axis = obj:GetAxis()
		local obj_angle = obj:GetAngle()
		local obj_pos = obj:GetPos()
		if not obj_pos:IsValidZ() then obj_pos = obj_pos:SetTerrainZ() end

		o:SetAxis(obj_axis)
		o:SetAngle(obj_angle)
		o:SetPos(obj:GetPosXYZ())

		local attach_spot = dummy:GetSpotBeginIndex("Spot")
		local spot_pos, spot_angle, spot_axis = dummy:GetSpotLoc(attach_spot, dummy:GetState(), 0)
		if not spot_pos:IsValidZ() then spot_pos = spot_pos:SetTerrainZ() end
		local attach_offset = RotateAxis(obj_pos - spot_pos, spot_axis, -spot_angle)
		local attach_axis, attach_angle = ComposeRotation(obj_axis, obj_angle, spot_axis, -spot_angle)
		dummy:Attach(obj, attach_spot)
		obj:SetAttachAxis(attach_axis)
		obj:SetAttachAngle(attach_angle)
		obj:SetAttachOffset(attach_offset)
		local phase = InteractionRand(obj:GetAnimDuration(), "FloatingDummy")
		obj:SetAnimPhase(1, phase)
	end
	obj:ForEachAttach(AttachObjectToFloatingDummy, dummy, o)
end

--- Attaches all objects in the map that are not already attached to a FloatingDummy to the appropriate FloatingDummy.
---
--- This function is called when a new map is loaded, and when the game exits the editor.
---
--- It first finds all the FloatingDummy objects in the map, and stores them in a collection. Then it iterates through all the CObject objects in the map, and for each one that is not already attached to a FloatingDummy, it calls the AttachObjectToFloatingDummy function to attach it to the appropriate FloatingDummy.
---
--- The function is wrapped in SuspendPassEdits and ResumePassEdits calls to ensure that the changes are properly committed to the map.
function AttachObjectsToFloatingDummies()
	if IsEditorActive() then return end
	local collection = {}
	MapForEach("map", "FloatingDummy", function(dummy, collection)
		local col_index = dummy:GetCollectionIndex()
		if col_index ~= 0 then
			collection[col_index] = dummy
		end
	end, collection)
	if not next(collection) then
		return
	end
	SuspendPassEdits("AttachObjectsToFloatingDummies")
	MapForEach("map", "CObject", function(obj, collection)
		local dummy = collection[obj:GetCollectionIndex()]
		if not dummy or obj == dummy or obj:GetParent() then
			return
		end
		AttachObjectToFloatingDummy(obj, dummy)
	end, collection)
	ResumePassEdits("AttachObjectsToFloatingDummies")
end

local function RestoreFloatingDummyAttachFlags(o)
	local obj = o.clone_of
	if IsValid(obj) then
		obj:SetEnumFlags(o:GetEnumFlags(floating_dummy_attach_clear_enum_flags))
		obj:ClearHierarchyGameFlags(const.gofSolidShadow)
	end
	o:ForEachAttach(RestoreFloatingDummyAttachFlags)
end

--- Restores the attachment state of a FloatingDummyCollision object to its original state.
---
--- This function is called when detaching objects from FloatingDummies. It checks if the object attached to the FloatingDummyCollision is still valid, and if it is attached to a FloatingDummy. If so, it detaches the object, restores its position, axis, and angle, and then calls RestoreFloatingDummyAttachFlags to restore any additional flags or state.
---
--- Finally, it marks the FloatingDummyCollision object as done and removes it from the TargetDummies table.
---
--- @param o FloatingDummyCollision The FloatingDummyCollision object to restore.
function RestoreFloatingDummyAttach(o)
	local obj = o.clone_of
	if IsValid(obj) then
		if IsKindOf(obj:GetParent(), "FloatingDummy") then
			obj:Detach()
			obj:SetPos(o:GetPosXYZ())
			obj:SetAxis(o:GetAxis())
			obj:SetAngle(o:GetAngle())
		end
		RestoreFloatingDummyAttachFlags(o)
	end
	DoneObject(o)
	TargetDummies[obj] = nil
end

--- Detaches all objects from FloatingDummies in the current map.
---
--- This function is called when the game is exiting the editor mode, to restore the original state of all objects that were attached to FloatingDummies.
---
--- It iterates through all FloatingDummyCollision objects in the map, and for each one, it detaches the attached object, restores its position, axis, and angle, and then calls `RestoreFloatingDummyAttachFlags` to restore any additional flags or state.
---
--- Finally, it marks the FloatingDummyCollision object as done and removes it from the `TargetDummies` table.
function DetachObjectsFromFloatingDummies()
	SuspendPassEdits("DetachObjectsFromFloatingDummies")
	MapForEach("map", "FloatingDummyCollision", RestoreFloatingDummyAttach)
	ResumePassEdits("DetachObjectsFromFloatingDummies")
end

OnMsg.NewMapLoaded = AttachObjectsToFloatingDummies
OnMsg.GameEnteringEditor = DetachObjectsFromFloatingDummies -- called before GameEnterEditor, allowing XEditorFilters to catch these objects
OnMsg.GameExitEditor = AttachObjectsToFloatingDummies
