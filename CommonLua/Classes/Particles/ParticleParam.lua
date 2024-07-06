DefineClass.ParticleParam =
{
	__parents = { "ParticleSystemSubItem" },
	PropEditorCopy = true,

	properties = {
		{ id = "label", name = "Name", editor = "text" },
		{ id = "type", name = "Type", editor = "dropdownlist", items = { "number", "point", "color", "bool" } },
		{ id = "default_value", name = "Default value", editor = "number" },
	},
	
	label = "<empty>",
	type = "number",
	default_value = 0,
	EditorView = Untranslated("<FormatNameForGed>"),
	EditorName = "Particle Param",
}

--- Formats the name of a ParticleParam object for display in the GED (Game Editor).
---
--- The formatted name includes the class name, the label, and the type of the ParticleParam.
---
--- @param self ParticleParam The ParticleParam object to format.
--- @return string The formatted name.
function ParticleParam:FormatNameForGed()
	return string.format("<color 95 12 200>%s: %s (%s)", self.class, self.label, self.type)
end

-- Called only by ged's OP, so parent is always a preset and not data isntance
--- Called when a ParticleParam is created in the editor.
---
--- This function is responsible for binding the ParticleParam to its parent ParticleSystemPreset and updating the properties of the preset.
---
--- @param self ParticleParam The ParticleParam instance.
--- @param parent any The parent object of the ParticleParam.
--- @param socket any The socket that the ParticleParam is attached to.
function ParticleParam:OnAfterEditorNew(parent, socket)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	container:BindParamsAndUpdateProperties()
end

-- Called only by ged's OP, so parent is always a preset and not data isntance
--- Called when a ParticleParam is deleted from the editor.
---
--- This function is responsible for binding the ParticleParam to its parent ParticleSystemPreset and updating the properties of the preset.
---
--- @param self ParticleParam The ParticleParam instance.
--- @param parent any The parent object of the ParticleParam.
--- @param socket any The socket that the ParticleParam is attached to.
function ParticleParam:OnAfterEditorDelete(parent, socket)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	container:BindParamsAndUpdateProperties()
end

--- Sets the type of the ParticleParam and updates the default value accordingly.
---
--- If the new type is the same as the current type, this function does nothing.
---
--- @param self ParticleParam The ParticleParam instance.
--- @param new_type string The new type to set for the ParticleParam. Can be "number", "point", "color", or "bool".
function ParticleParam:Settype(new_type)
	if self.type == new_type then
		return
	end
	self.type = new_type
	self.default_value = self:GetDefaultPropertyValue("default_value")
end

--- Gets the default value of the ParticleParam.
---
--- If a raw default value is set, it returns that value. Otherwise, it returns the default property value for the ParticleParam's type.
---
--- @param self ParticleParam The ParticleParam instance.
--- @return any The default value of the ParticleParam.
function ParticleParam:Getdefault_value()
	local raw_value = rawget(self, "default_value")
	if raw_value and raw_value ~= 0 then
		return raw_value
	else
		return self:GetDefaultPropertyValue("default_value")
	end
end

--- Sets the default value of the ParticleParam.
---
--- @param self ParticleParam The ParticleParam instance.
--- @param v any The new default value to set.
function ParticleParam:Setdefault_value(v)
	self.default_value = v
end

--- Gets the properties of the ParticleParam.
---
--- If the ParticleParam type is "number", it returns the properties as-is.
--- Otherwise, it creates a copy of the properties table and updates the "default_value" property to have the appropriate editor type based on the ParticleParam type.
---
--- @param self ParticleParam The ParticleParam instance.
--- @return table The properties of the ParticleParam.
function ParticleParam:GetProperties()
	if self.type == "number" then
		return self.properties
	else
		local props = table.copy(self.properties)
		local idx = table.find(props, "id", "default_value")
		props[idx ] = { id = "default_value", name = "Default value", editor = self.type }
		return props
	end
end

--- Gets the default property value for the ParticleParam.
---
--- If the property is "default_value", it returns a default value based on the ParticleParam's type. Otherwise, it calls the `GetDefaultPropertyValue` function on the `InitDone` object.
---
--- @param self ParticleParam The ParticleParam instance.
--- @param prop string The name of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
function ParticleParam:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "default_value" then
		local def = {
			point = point30,
			color = 255,
			number = 0,
			bool = false,
		}
		return def[self.type]
	end
	return InitDone.GetDefaultPropertyValue(self, prop, prop_meta)
end