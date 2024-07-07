----- UpdateObject

DefineClass.UpdateObject = {
	__parents = {"Object"},
	
	update_thread_on_init = true,
	update_interval = 10000,
	update_thread = false,
}

RecursiveCallMethods.OnObjUpdate = "call"

local Sleep = Sleep
local procall = procall
local GameTime = GameTime
function UpdateObject:Init()
	if self.update_thread_on_init then
		self:StartObjUpdateThread()
	end
end

---
--- Periodically calls the `OnObjUpdate` method on the object, with the current game time and the configured update interval.
---
--- This function is intended to be run in a separate game thread, as configured by the `update_thread_on_init` and `update_interval` properties of the `UpdateObject` class.
---
--- @param update_interval number The interval, in milliseconds, at which to call the `OnObjUpdate` method.
function UpdateObject:ObjUpdateProc(update_interval)
	self:InitObjUpdate(update_interval)
	while true do
		procall(self.OnObjUpdate, self, GameTime(), update_interval)
		Sleep(update_interval)
	end
end

---
--- Starts a game thread that periodically calls the `OnObjUpdate` method on the object, with the current game time and the configured update interval.
---
--- This function is intended to be called when the object is initialized, if the `update_thread_on_init` property is set to `true`.
---
--- @param self UpdateObject The object instance.
function UpdateObject:StartObjUpdateThread()
	if not self:IsSyncObject() or not mapdata.GameLogic or not self.update_interval then
		return
	end
	DeleteThread(self.update_thread)
	self.update_thread = CreateGameTimeThread(self.ObjUpdateProc, self, self.update_interval)
	if Platform.developer then
		ThreadsSetThreadSource(self.update_thread, "ObjUpdateThread", self.ObjUpdateProc)
	end
end

---
--- Stops the game thread that periodically calls the `OnObjUpdate` method on the object.
---
--- This function is intended to be called when the object is being destroyed or no longer needs to be updated.
---
--- @param self UpdateObject The object instance.
function UpdateObject:StopObjUpdateThread()
	DeleteThread(self.update_thread)
	self.update_thread = nil
end

---
--- Initializes the object update process by adding a random delay before the first update.
---
--- This function is called by the `ObjUpdateProc` function to add a small random delay before the first update of the object. This helps to stagger the updates of multiple objects and avoid synchronization issues.
---
--- @param update_interval number The interval, in milliseconds, at which to call the `OnObjUpdate` method.
function UpdateObject:InitObjUpdate(update_interval)
	Sleep(1 + self:Random(update_interval, "InitObjUpdate"))
end

---
--- Stops the game thread that periodically calls the `OnObjUpdate` method on the object.
---
--- This function is intended to be called when the object is being destroyed or no longer needs to be updated.
---
--- @param self UpdateObject The object instance.
function UpdateObject:Done()
	self:StopObjUpdateThread()
end


----- ReservedObject

DefineClass.ReservedObject = {
	__parents = { "InitDone" },
	properties = {
		{ id = "reserved_by", editor = "object", default = false, no_edit = true },
	},
}

---
--- Attempts to interrupt the reservation of the specified object.
---
--- If the object is currently reserved by a valid reserver object, this function calls the `OnReservationInterrupted` method on the reserver object. Otherwise, it clears the reservation on the object.
---
--- @param reserved_obj ReservedObject The object whose reservation is to be interrupted.
--- @return boolean True if the reservation was successfully interrupted, false otherwise.
function TryInterruptReserved(reserved_obj)
	local reserved_by = reserved_obj.reserved_by
	if IsValid(reserved_by) then
		return reserved_by:OnReservationInterrupted()
	end 
	reserved_obj.reserved_by = nil
end

ReservedObject.Disown = TryInterruptReserved

AutoResolveMethods.CanReserverBeInterrupted = "or"
ReservedObject.CanReserverBeInterrupted = empty_func

---
--- Checks if the specified object can reserve this object.
---
--- If this object is not currently reserved, or is reserved by the specified object, or the current reserver can be interrupted, this function returns true.
---
--- @param obj ReserverObject The object that is attempting to reserve this object.
--- @return boolean True if the object can be reserved by the specified object, false otherwise.
function ReservedObject:CanBeReservedBy(obj)
	return not self.reserved_by or self.reserved_by == obj or self:CanReserverBeInterrupted(obj)
end

---
--- Attempts to reserve the specified object for the given reserver object.
---
--- If the object can be reserved by the reserver object, this function reserves the object and returns true. Otherwise, it returns false.
---
--- If the object is currently reserved by a different reserver object, this function will attempt to interrupt the existing reservation by calling the `OnReservationInterrupted` method on the current reserver object. If the interruption is successful, the object is then reserved for the new reserver object.
---
--- @param reserved_by ReserverObject The object that is attempting to reserve this object.
--- @return boolean True if the object was successfully reserved, false otherwise.
function ReservedObject:TryReserve(reserved_by)
	if not self:CanBeReservedBy(reserved_by) then return false end
	if self.reserved_by and self.reserved_by ~= reserved_by then
		if not TryInterruptReserved(self) then return end
	end
	return self:Reserve(reserved_by)
end

---
--- Attempts to reserve the specified object for the given reserver object.
---
--- If the object can be reserved by the reserver object, this function reserves the object and returns true. Otherwise, it returns false.
---
--- If the object is currently reserved by a different reserver object, this function will attempt to interrupt the existing reservation by calling the `OnReservationInterrupted` method on the current reserver object. If the interruption is successful, the object is then reserved for the new reserver object.
---
--- @param reserved_by ReserverObject The object that is attempting to reserve this object.
--- @return boolean True if the object was successfully reserved, false otherwise.
function ReservedObject:Reserve(reserved_by)
	assert(IsKindOf(reserved_by, "ReserverObject"))
	local previous_reservation = reserved_by.reserved_obj
	if previous_reservation and previous_reservation ~= self then
		--assert(not previous_reservation, "Reserver trying to reserve two objects at once!")
		previous_reservation:CancelReservation(reserved_by)
	end
	self.reserved_by = reserved_by
	reserved_by.reserved_obj = self
	self:OnReserved(reserved_by)
	return true
end

ReservedObject.OnReserved = empty_func
ReservedObject.OnReservationCanceled = empty_func

---
--- Cancels the reservation of the object by the specified reserver object.
---
--- If the object is currently reserved by the specified reserver object, this function removes the reservation and notifies the reserver object that the reservation has been canceled.
---
--- @param reserved_by ReserverObject The reserver object that is attempting to cancel the reservation.
--- @return boolean True if the reservation was successfully canceled, false otherwise.
function ReservedObject:CancelReservation(reserved_by)
	if self.reserved_by == reserved_by then
		self.reserved_by = nil
		reserved_by.reserved_obj = nil
		self:OnReservationCanceled()
		return true
	end
end

---
--- Disowns the reserved object.
---
--- This function is called when the reserved object is done being used and should be disowned. It calls the `Disown` function on the reserved object to remove its ownership.
---
--- @return nil
function ReservedObject:Done()
	self:Disown()
end

DefineClass.ReserverObject = {
	__parents = { "CommandObject" },

	reserved_obj = false,
}

---
--- Interrupts the reservation of the object by the reserver object.
---
--- This function is called when the reservation of the object is interrupted, such as when the reserver object is no longer able to reserve the object. It attempts to set the command of the reserver object to "CmdInterrupt" to handle the interruption.
---
--- @return boolean True if the command was successfully set, false otherwise.
function ReserverObject:OnReservationInterrupted()
	return self:TrySetCommand("CmdInterrupt")
end

----- OwnedObject

DefineClass.OwnershipStateBase = {
	OnStateTick  = empty_func,
	OnStateExit  = empty_func,

	CanDisown    = empty_func,
	CanBeOwnedBy = empty_func,
}

DefineClass("ConcreteOwnership", "OwnershipStateBase")

local function SetOwnerObject(owned_obj, owner)
	assert(not owner or IsKindOf(owner, "OwnerObject"))
	owner = owner or false
	local prev_owner = owned_obj.owner
	if owner ~= prev_owner then
		owned_obj.owner = owner
		
		local notify_owner = not prev_owner or prev_owner:GetOwnedObject(owned_obj.ownership_class) == owned_obj		
		if notify_owner then
			if prev_owner then
				prev_owner:SetOwnedObject(false, owned_obj.ownership_class)
			end
			if owner then
				owner:SetOwnedObject(owned_obj)
			end
		end
	end
end

---
--- Sets the owner of the specified owned object.
---
--- This function is called when the state of the ownership changes for the given owned object. It updates the owner property of the object and notifies the previous and new owners of the change.
---
--- @param owned_obj OwnedObject The owned object whose owner is being set.
--- @param owner OwnerObject|false The new owner of the object, or `false` to remove the owner.
--- @return boolean True if the owner was successfully set, false otherwise.
---
function ConcreteOwnership.OnStateTick(owned_obj, owner)
	return SetOwnerObject(owned_obj, owner)
end

---
--- Called when the ownership state of an owned object is exited.
---
--- This function sets the owner of the specified owned object to `false`, effectively removing the owner.
---
--- @param owned_obj OwnedObject The owned object whose ownership state is being exited.
--- @return boolean True if the owner was successfully set to `false`, false otherwise.
---
function ConcreteOwnership.OnStateExit(owned_obj)
	return SetOwnerObject(owned_obj, false)
end

---
--- Checks if the specified owned object can be disowned by the given owner.
---
--- This function returns true if the owner of the owned object matches the given owner, indicating that the object can be disowned by that owner.
---
--- @param owned_obj OwnedObject The owned object to check.
--- @param owner OwnerObject The owner to check against.
--- @param reason string|nil The reason for disowning the object (optional).
--- @return boolean True if the owned object can be disowned by the given owner, false otherwise.
---
function ConcreteOwnership.CanDisown(owned_obj, owner, reason)
	return owned_obj.owner == owner
end

---
--- Checks if the specified owned object can be owned by the given owner.
---
--- This function returns true if the owner of the owned object matches the given owner, indicating that the object can be owned by that owner.
---
--- @param owned_obj OwnedObject The owned object to check.
--- @param owner OwnerObject The owner to check against.
--- @param ... any Additional arguments (unused).
--- @return boolean True if the owned object can be owned by the given owner, false otherwise.
---
function ConcreteOwnership.CanBeOwnedBy(owned_obj, owner, ...)
	return owned_obj.owner == owner
end

DefineClass("SharedOwnership", "OwnershipStateBase")
SharedOwnership.CanBeOwnedBy = return_true

DefineClass("ForbiddenOwnership", "OwnershipStateBase")

DefineClass.OwnedObject = {
	__parents = { "ReservedObject" },
	properties = {
		{ id = "owner",                                               editor = "object", default = false, no_edit = true },
		{ id = "can_change_ownership", name = "Can change ownership", editor = "bool",   default = true,  help = "If true, the player can change who owns the object", },
		{ id = "ownership_class",      name = "Ownership class",      editor = "combo",  default = false, items = GatherComboItems("GatherOwnershipClasses"), },
	},
	
	ownership = "SharedOwnership",
}

AutoResolveMethods.CanDisown = "and"
---
--- Checks if the specified owned object can be disowned by the given owner.
---
--- This function returns true if the owner of the owned object matches the given owner, indicating that the object can be disowned by that owner.
---
--- @param owner OwnerObject The owner to check against.
--- @param reason string|nil The reason for disowning the object (optional).
--- @return boolean True if the owned object can be disowned by the given owner, false otherwise.
---
function OwnedObject:CanDisown(owner, reason)
	return g_Classes[self.ownership].CanDisown(self, owner, reason)
end

---
--- Disowns the owned object and sets its ownership to shared ownership.
---
--- This function first calls the `Disown` function of the `ReservedObject` class, which removes any reservation on the object. It then calls the `TrySetSharedOwnership` function to set the object's ownership to shared ownership.
---
--- @param self OwnedObject The owned object to disown.
---
function OwnedObject:Disown()
	ReservedObject.Disown(self)
	self:TrySetSharedOwnership()
end

AutoResolveMethods.CanBeOwnedBy = "and"
---
--- Checks if the specified object can be owned by the current object.
---
--- This function first checks if the specified object can be reserved by the current object using the `CanBeReservedBy` function. If the object cannot be reserved, the function returns `false`, indicating that the object cannot be owned.
---
--- If the object can be reserved, the function then delegates the ownership check to the ownership class associated with the current object. The ownership class's `CanBeOwnedBy` function is called with the current object and the specified object as arguments.
---
--- @param obj any The object to check if it can be owned by the current object.
--- @param ... any Additional arguments (unused).
--- @return boolean True if the specified object can be owned by the current object, false otherwise.
---
function OwnedObject:CanBeOwnedBy(obj, ...)
	if not self:CanBeReservedBy(obj) then return end
	return g_Classes[self.ownership].CanBeOwnedBy(self, obj, ...)
end

AutoResolveMethods.CanChangeOwnership = "and"
---
--- Checks if the ownership of the owned object can be changed.
---
--- This function returns true if the ownership of the owned object can be changed, false otherwise.
---
--- @return boolean True if the ownership can be changed, false otherwise.
---
function OwnedObject:CanChangeOwnership()
	return self.can_change_ownership
end

---
--- Gets the object that has reserved the owned object, or the owner of the owned object if it is not reserved.
---
--- @return any The object that has reserved the owned object, or the owner of the owned object if it is not reserved.
---
function OwnedObject:GetReservedByOrOwner()
	return self.reserved_by or self.owner
end

OwnedObject.OnOwnershipChanged = empty_func

---
--- Attempts to set the ownership of the owned object.
---
--- This function first checks if the ownership can be changed. If the ownership cannot be changed and the `forced` parameter is not set, the function returns without making any changes.
---
--- If the ownership can be changed, the function stores the previous owner and ownership, sets the new ownership, and calls the `OnStateTick` function of the new ownership class. It then calls the `OnOwnershipChanged` function to notify any listeners of the ownership change.
---
--- @param self OwnedObject The owned object.
--- @param ownership string The new ownership to set.
--- @param forced boolean (optional) If true, the ownership will be set even if it cannot be changed.
--- @param ... any Additional arguments to pass to the ownership class functions.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:TrySetOwnership(ownership, forced, ...)
	assert(ownership)
	if not ownership or not forced and not self:CanChangeOwnership() then return end
	
	local prev_owner = self.owner
	local prev_ownership = self.ownership
	self.ownership = ownership
	if prev_ownership ~= ownership then
		g_Classes[prev_ownership].OnStateExit(self, ...)
	end
	g_Classes[ownership].OnStateTick(self, ...)
	self:OnOwnershipChanged(prev_ownership, prev_owner)
end

local function TryInterruptReservedOnDifferentOwner(owned_obj)
	local reserved_by = owned_obj.reserved_by
	if IsValid(reserved_by) and reserved_by ~= owned_obj.owner then
		reserved_by:OnReservationInterrupted()
		owned_obj.reserved_by = nil
	end
end

local OwnershipChangedReactions = {
	ConcreteOwnership = {
		ConcreteOwnership  = TryInterruptReservedOnDifferentOwner,
		ForbiddenOwnership = TryInterruptReserved,
	},
	SharedOwnership = {
		ConcreteOwnership  = TryInterruptReservedOnDifferentOwner,
		ForbiddenOwnership = TryInterruptReserved,
	}
}

---
--- Called when the ownership of the owned object changes.
---
--- This function is responsible for handling any necessary reactions to the ownership change. It looks up the appropriate reaction function in the `OwnershipChangedReactions` table based on the previous and new ownership, and calls that function if it exists.
---
--- @param self OwnedObject The owned object.
--- @param prev_ownership string The previous ownership of the object.
--- @param prev_owner any The previous owner of the object.
---
function OwnedObject:OnOwnershipChanged(prev_ownership, prev_owner)
	local transition = table.get(OwnershipChangedReactions, prev_ownership, self.ownership)
	if transition then
		transition(self)
	end
end

----- OwnedObject helper functions

---
--- Sets the concrete ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "ConcreteOwnership".
---
--- @param self OwnedObject The owned object.
--- @param forced boolean (optional) If true, the ownership will be set even if the object cannot change ownership.
--- @param owner any The new owner of the object.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:TrySetConcreteOwnership(forced, owner)
	return self:TrySetOwnership("ConcreteOwnership", forced, owner)
end

---
--- Sets the concrete ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "ConcreteOwnership".
---
--- @param self OwnedObject The owned object.
--- @param ... any Additional arguments to pass to `OwnedObject:TrySetOwnership()`.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:SetConcreteOwnership(...)
	return self:TrySetConcreteOwnership("forced", ...)
end

---
--- Checks if the owned object has concrete ownership.
---
--- @param self OwnedObject The owned object.
--- @return boolean True if the object has concrete ownership, false otherwise.
---
function OwnedObject:HasConcreteOwnership()
	return self.ownership == "ConcreteOwnership"
end

---
--- Sets the shared ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "SharedOwnership".
---
--- @param self OwnedObject The owned object.
--- @param forced boolean (optional) If true, the ownership will be set even if the object cannot change ownership.
--- @param ... any Additional arguments to pass to `OwnedObject:TrySetOwnership()`.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:TrySetSharedOwnership(forced, ...)
	return self:TrySetOwnership("SharedOwnership", forced, ...)
end

---
--- Sets the shared ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "SharedOwnership".
---
--- @param self OwnedObject The owned object.
--- @param ... any Additional arguments to pass to `OwnedObject:TrySetOwnership()`.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:SetSharedOwnership(...)
	return self:TrySetSharedOwnership("forced", ...)
end

---
--- Checks if the owned object has shared ownership.
---
--- @param self OwnedObject The owned object.
--- @return boolean True if the object has shared ownership, false otherwise.
---
function OwnedObject:HasSharedOwnership()
	return self.ownership == "SharedOwnership"
end

---
--- Sets the forbidden ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "ForbiddenOwnership".
---
--- @param self OwnedObject The owned object.
--- @param forced boolean (optional) If true, the ownership will be set even if the object cannot change ownership.
--- @param ... any Additional arguments to pass to `OwnedObject:TrySetOwnership()`.
--- @return boolean True if the ownership was successfully set, false otherwise.
---
function OwnedObject:TrySetForbiddenOwnership(forced, ...)
	return self:TrySetOwnership("ForbiddenOwnership", forced, ...)
end

--- Sets the forbidden ownership of the owned object.
---
--- This function is a wrapper around `OwnedObject:TrySetOwnership()` that sets the ownership to "ForbiddenOwnership".
---
--- @param self OwnedObject The owned object.
--- @param ... any Additional arguments to pass to `OwnedObject:TrySetOwnership()`.
--- @return boolean True if the ownership was successfully set, false otherwise.
function OwnedObject:SetForbiddenOwnership(...)
	return self:TrySetForbiddenOwnership("forced", ...)
end

---
--- Checks if the owned object has forbidden ownership.
---
--- @param self OwnedObject The owned object.
--- @return boolean True if the object has forbidden ownership, false otherwise.
---
function OwnedObject:HasForbiddenOwnership()
	return self.ownership == "ForbiddenOwnership"
end

----- OwnedObject helper functions end

DefineClass.OwnedByUnit = {
	__parents = { "OwnedObject" },
	properties = {
		{ id = "can_have_dead_owners", name = "Can have dead owners", editor = "bool", default = false, help = "If true, the object can have dead units as owners", },
	}
}

---
--- Checks if the owned object can be owned by the specified object.
---
--- This function is a wrapper around `OwnedObject:CanBeOwnedBy()` that also checks if the owner object is dead. If the owned object cannot have dead owners and the owner object is dead, this function will return `false`.
---
--- @param self OwnedByUnit The owned object.
--- @param obj any The object that wants to own the owned object.
--- @param ... any Additional arguments to pass to `OwnedObject:CanBeOwnedBy()`.
--- @return boolean True if the owned object can be owned by the specified object, false otherwise.
---
function OwnedByUnit:CanBeOwnedBy(obj, ...)
	if not self.can_have_dead_owners and obj:IsDead() then return end
	return OwnedObject.CanBeOwnedBy(self, obj, ...)
end

DefineClass.OwnerObject = {
	__parents = { "ReserverObject" },
	owned_objects = false,
}

---
--- Initializes the `owned_objects` table for the `OwnerObject` class.
---
--- The `owned_objects` table is used to store the objects that are owned by this `OwnerObject` instance. This function sets up the initial empty table for this purpose.
---
--- @param self OwnerObject The `OwnerObject` instance.
---
function OwnerObject:Init()
	self.owned_objects = {}
end

---
--- Checks if the specified object is owned by this `OwnerObject` instance.
---
--- @param self OwnerObject The `OwnerObject` instance.
--- @param object any The object to check ownership for.
--- @return boolean True if the specified object is owned by this `OwnerObject` instance, false otherwise.
---
function OwnerObject:Owns(object)
	local ownership_class = object.ownership_class
	if not ownership_class then return end
	return self.owned_objects[ownership_class] == object
end

---
--- Disowns all objects owned by this `OwnerObject` instance.
---
--- This function iterates through the `owned_objects` table and calls the `Disown()` method on each owned object, if the object can be disowned by this `OwnerObject` instance.
---
--- @param self OwnerObject The `OwnerObject` instance.
--- @param reason any The reason for disowning the objects.
---
function OwnerObject:DisownObjects(reason)
	local owned_objects = self.owned_objects
	for _, ownership_class in ipairs(owned_objects) do
		local owned_object = owned_objects[ownership_class]
		if owned_object and owned_object:CanDisown(self, reason) then
			owned_object:Disown()
		end
	end
end

---
--- Gets the object owned by this `OwnerObject` instance for the specified ownership class.
---
--- @param self OwnerObject The `OwnerObject` instance.
--- @param ownership_class string The ownership class to get the owned object for.
--- @return any|nil The owned object, or `nil` if no object is owned for the specified ownership class.
---
function OwnerObject:GetOwnedObject(ownership_class)
	assert(ownership_class)
	return self.owned_objects[ownership_class]
end

---
--- Sets the owned object for the specified ownership class.
---
--- If an owned object already exists for the specified ownership class, the previous object is disowned and the new object is owned.
---
--- @param self OwnerObject The `OwnerObject` instance.
--- @param owned_obj OwnedObject|nil The object to own, or `nil` to disown the object for the specified ownership class.
--- @param ownership_class string The ownership class to set the owned object for.
--- @return boolean True if the owned object was successfully set, false otherwise.
---
function OwnerObject:SetOwnedObject(owned_obj, ownership_class)
	assert(not owned_obj or owned_obj:IsKindOf("OwnedObject"))
	if owned_obj then
		ownership_class = ownership_class or owned_obj.ownership_class
		assert(ownership_class == owned_obj.ownership_class)
	end
	assert(ownership_class)
	if not ownership_class then
		return false
	end
	local prev_owned_obj = self:GetOwnedObject(ownership_class)
	if prev_owned_obj == owned_obj then
		return false
	end
	local owned_objects = self.owned_objects
	
	owned_objects[ownership_class] = owned_obj
	table.remove_entry(owned_objects, ownership_class)
	if owned_obj then
		table.insert(owned_objects, ownership_class)
		if prev_owned_obj then
			prev_owned_obj:TrySetSharedOwnership()
		end
		owned_obj:TrySetConcreteOwnership(nil, self)
	end
	return true
end

if Platform.developer then

---
--- Gets the test data for the owned object.
---
--- @param self OwnedObject The `OwnedObject` instance.
--- @param data table The data table to populate with the test data.
---
function OwnedObject:GetTestData(data)
	data.ReservedBy = self.reserved_by
end

end
