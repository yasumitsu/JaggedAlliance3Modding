DefineClass.TrapSpawnProperties = {
	__parents = { "TrapProperties" },
	properties = {
		{ category = "Visuals", id = "trapType", name = "Trap Type", editor = "combo", items = ClassDescendantsCombo("Trap"), default = "Landmine",
			help = "The class of trap to spawn." },
	},
}

--- Returns a table of property values for the TrapSpawnProperties object.
---
--- This function retrieves the list of properties defined for the TrapSpawnProperties class,
--- and creates a table of the current property values for the object. It skips any properties
--- that have the `dont_save` flag set.
---
--- @return table The table of property values.
function TrapSpawnProperties:GetPropertyList()
	local properties = TrapSpawnProperties:GetProperties()
	local values = {}
	for i = 1, #properties do
		local prop = properties[i]
		if not prop_eval(prop.dont_save, self, prop) then
			local prop_id = prop.id
			local value = self:GetProperty(prop_id)
			-- Unlike TrapProperties this copies the default properties as well,
			-- since it is used by the ModifyTrapSpawnersEffect
			values[prop_id] = value
		end
	end
	return values
end

-- Spawns a trap object.
DefineClass.TrapSpawnMarker = {
	__parents = { "ConditionalSpawnMarker", "TrapSpawnProperties" },
	properties = {
		{ category = "Visuals", id = "colors", name = "Colors", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false,  },
		{ category = "Visuals",
			id = "TriggerType",
			name = "TriggerType",
			editor = "choice",
			items = LandmineTriggerType,
			default = "Proximity",
			no_edit = function(o) return o.trapType ~= "Landmine" end
		},
	},
	disabled = false
}

--- Checks for any existing Landmine objects grouped with the TrapSpawnMarker.
---
--- This function is called during the GameInit event of the TrapSpawnMarker object.
--- It checks the root collection of the TrapSpawnMarker to see if there are any
--- Landmine objects grouped with it. If a Landmine is found, it logs an error
--- message indicating that this will cause two Landmines to be spawned on top
--- of each other.
---
--- @return nil
function TrapSpawnMarker:GameInit()
	local root_collection = self:GetRootCollection()
	local collection_idx = root_collection and root_collection.Index or 0
	if collection_idx ~= 0 then
		local obj = MapGetFirst(self:GetPos(), guim * 10, "collection", collection_idx, true, "Landmine")
		if obj then
			StoreErrorSource(self, "Landmine grouped with a TrapSpawnMarker, this will cause two landmines on top of each other.")
			DoneObject(obj)
		end
	end
end

---
--- Sets the active state of the TrapSpawnMarker.
---
--- If the marker is set to active, it will spawn the trap objects. If it is set to inactive,
--- it will despawn any existing trap objects.
---
--- @param active boolean
---   True to set the marker as active, false to set it as inactive.
---
function TrapSpawnMarker:SetActive(active)
	self.disabled = not active
	if self.objects and self.disabled then
		self:DespawnObjects()
	end
	self:Update()
end

---
--- Despawns any existing trap objects associated with the TrapSpawnMarker.
---
--- This function is called to remove any trap objects that were previously spawned by the
--- TrapSpawnMarker. It deletes the objects and sets the `objects` field to `false`.
---
--- @return nil
function TrapSpawnMarker:DespawnObjects()
	if not self.objects then return end
	self.objects:delete()
	self.objects = false
end

---
--- Spawns the trap objects associated with the TrapSpawnMarker.
---
--- This function is called to create the trap objects that the TrapSpawnMarker is responsible for. It checks the marker's state to determine if it should spawn the objects, and then places the trap object at the marker's position and orientation. If the marker has a color set, it applies that colorization to the trap object as well.
---
--- The spawned trap object is stored in the `objects` field of the TrapSpawnMarker, and the `last_spawned_objects` flag is set to true to indicate that objects have been spawned.
---
--- @return nil
function TrapSpawnMarker:SpawnObjects()
	if self.disabled then return end
	if self.Trigger == "once" and self.last_spawned_objects then return end
	if not self.trapType then return end

	local values = TrapProperties.GetPropertyList(self)
	values.TriggerType = self.TriggerType
	local obj = PlaceObject(self.trapType, values)
	obj:SetPos(self:GetPos())
	obj:SetOrientation(self:GetOrientation())
	if self.colors then
		obj:SetColorization(self.colors)
	end
	obj:MakeSync()

	self.objects = obj
	self.last_spawned_objects = true
end

---
--- Retrieves the dynamic data associated with the TrapSpawnMarker.
---
--- This function is called to get the dynamic data for the TrapSpawnMarker, which includes information about the spawned trap objects and whether the marker is disabled. If the marker has spawned trap objects, the dynamic data for those objects is also retrieved and included in the returned data table.
---
--- @param data table The table to store the dynamic data in.
--- @return nil
function TrapSpawnMarker:GetDynamicData(data)
	if self.objects then
		local obj_data = {}
		procall(self.objects.GetDynamicData, self.objects, obj_data)
		if next(obj_data) ~= nil then
			data.obj = obj_data
		end
	end
	if self.disabled then
		data.disabled = self.disabled
	end
end

---
--- Sets the dynamic data for the TrapSpawnMarker.
---
--- This function is called to set the dynamic data for the TrapSpawnMarker, which includes information about whether the marker is disabled and whether trap objects have been spawned. If the marker has spawned trap objects, the dynamic data for those objects is also set.
---
--- @param data table The table containing the dynamic data to set.
--- @return nil
function TrapSpawnMarker:SetDynamicData(data)
	self.disabled = data.disabled or false
	if data.last_spawned_objects then
		-- Parent will set this true when reading from the data (SetDynamicData is called with a RecursiveCall), preventing a spawn.
		self.last_spawned_objects = false
		self:SpawnObjects()
		if data.obj then
			procall(self.objects.SetDynamicData, self.objects, data.obj)
		end
	end
end

---
--- Applies a property list to the TrapSpawnMarker.
---
--- This function is used to apply a list of properties to the TrapSpawnMarker. It first removes the 'done' property from the list, as this property should not be copied as it will restore mines. It then calls the `TrapProperties.ApplyPropertyList` function to apply the remaining properties to the TrapSpawnMarker. If the TrapSpawnMarker has already spawned objects, the function also applies the property changes to those objects.
---
--- @param list table The list of properties to apply to the TrapSpawnMarker.
--- @return nil
function TrapSpawnMarker:ApplyPropertyList(list)
	-- This property shouldn't be copied as it will restore mines.
	list.done = nil

	TrapProperties.ApplyPropertyList(self, list)
	-- If the trap is already spawned, apply the property change to it as well.
	if self.objects then
		TrapProperties.ApplyPropertyList(self.objects, list)
	end
end