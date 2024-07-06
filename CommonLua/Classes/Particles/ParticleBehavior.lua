
DefineClass.ParticleBehavior =
{
	__parents = { "ParticleSystemSubItem", "PropertyObject" },
	__hierarchy_cache = true,
	PropEditorCopy = true,

	properties = {
		{ id = "label", category = "Base", name = "Label", editor = "text", dynamic = true, default = "", help = "A help text used to show the meaning of the behavior" },
		{ id = "bins", category = "Base", name = "Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" } },
		{ id = "time_start", category = "Base", name = "Time Start", editor = "number", scale = "sec", dynamic = true },
		{ id = "time_stop", category = "Base", name = "Time Stop", editor = "number", scale = "sec", dynamic = true },
		{ id = "time_period", category = "Base", name = "Time Period", editor = "number", scale = "sec", dynamic = true },
		{ id = "period_seed", category = "Base", name = "Period Seed", editor = "number", help = "Leave 0 for random. If period_seed, time_start, time_stop, time_period are equal the seed will be equal." },
		{ id = "randomize_period", category = "Base", name = "Randomize Period (%)", editor = "number", dynamic = true },		
		{ id = "world_space", name = "World space", editor = "bool" },
		{ id = "probability", name = "Probability", editor = "number", dynamic = true, help = "The probability of that behavior to be used", min = 1, max = 100 },
	},
	
	active = true,
	flags_label = false,
	bins = set("A"),
	time_start = 0,
	time_stop = -1000,
	time_period = 0,
	period_seed = 0,
	randomize_period = 0,
	EditorName = false,
	EditorView = Untranslated("<FormatNameForGed>"),
	world_space = false,
	probability = 100,
	
	override_props = false,
	override_value = false,
}

---
--- Formats the bins property of a ParticleBehavior object as a string.
---
--- The bins property is a set of strings representing the bins that the particle behavior is associated with.
--- This function iterates over the possible bin items and constructs a string representation of the bins,
--- where a bin name is included if it is set in the bins property, or an underscore is used if it is not set.
---
--- @return string The formatted bins string.
---
function ParticleBehavior:FormatBins()
	local bins = "["
	local items = self:GetPropertyMetadata("bins").items
	for _, item in ipairs(items) do
		if self.bins[item] then
			bins = bins .. item
		else
			bins = bins .. "_"
		end
	end
	bins = bins .. "]"
	return bins	
end

---
--- Returns the color to be used for the particle behavior in the GED editor.
---
--- If the particle behavior is active, the color is set to "75 105 198" (a shade of blue).
--- If the particle behavior is not active, the color is set to "170 170 170" (a shade of gray).
---
--- @return string The color to be used for the particle behavior in the GED editor.
---
function ParticleBehavior:GetColorForGed()
	return self.active and "75 105 198" or "170 170 170"
end

---
--- Called when a new ParticleBehavior is added to a ParticleSystemPreset in the editor.
---
--- This function performs the following actions:
--- - Finds the parent ParticleSystemPreset container of the new ParticleBehavior
--- - If the new ParticleBehavior is not the first one in the container, it copies the bins property from the previous ParticleBehavior
--- - Refreshes the behavior usage indicators in the ParticleSystemPreset
--- - Reloads the ParticleSystemPreset to apply the changes
--- - Enables the dynamic toggle for the ParticleBehavior based on the dynamic parameters of the ParticleSystemPreset
---
--- @param parent table The parent object of the ParticleBehavior
--- @param socket table The socket where the ParticleBehavior was added
--- @param paste boolean Whether the ParticleBehavior was pasted or newly created
---
function ParticleBehavior:OnAfterEditorNew(parent, socket, paste)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	
	local idx = table.find(container, self)
	if idx and idx > 1 and not paste then
		local old_item = container[idx - 1]
		self.bins = table.copy(old_item.bins)
	end
	
	if IsKindOf(container, "ParticleSystemPreset") then
		container:RefreshBehaviorUsageIndicators("do_now")
		ParticlesReload(container.id)
		self:EnableDynamicToggle(container:DynamicParams())
	end
end

---
--- Called when a ParticleBehavior is swapped with another ParticleBehavior in the editor.
---
--- This function performs the following actions:
--- - Finds the parent ParticleSystemPreset container of the swapped ParticleBehaviors
--- - Reloads the ParticleSystemPreset to apply the changes
---
--- @param parent table The parent object of the ParticleBehavior
--- @param socket table The socket where the ParticleBehavior was swapped
--- @param idx1 number The index of the first ParticleBehavior
--- @param idx2 number The index of the second ParticleBehavior
---
function ParticleBehavior:OnAfterEditorSwap(parent, socket, idx1, idx2)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	if IsKindOf(container, "ParticleSystemPreset") then
		ParticlesReload(container.id)
	end
end

---
--- Called when a ParticleBehavior is dragged and dropped in the editor.
---
--- This function performs the following actions:
--- - Finds the parent ParticleSystemPreset container of the dragged and dropped ParticleBehavior
--- - Reloads the ParticleSystemPreset to apply the changes
---
--- @param parent table The parent object of the ParticleBehavior
--- @param socket table The socket where the ParticleBehavior was dragged and dropped
---
function ParticleBehavior:OnAfterEditorDragAndDrop(parent, socket)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	if IsKindOf(container, "ParticleSystemPreset") then
		ParticlesReload(container.id)
	end
end

---
--- Called when a ParticleBehavior is deleted from the editor.
---
--- This function performs the following actions:
--- - Finds the parent ParticleSystemPreset container of the deleted ParticleBehavior
--- - Refreshes the behavior usage indicators for the ParticleSystemPreset
--- - Reloads the ParticleSystemPreset to apply the changes
---
--- @param parent table The parent object of the ParticleBehavior
--- @param socket table The socket where the ParticleBehavior was deleted
---
function ParticleBehavior:OnAfterEditorDelete(parent, socket)
	local container = GetParentTableOfKind(self, "ParticleSystemPreset")
	if not container then return end
	container:RefreshBehaviorUsageIndicators()
	ParticlesReload(container.id)
end

---
--- Formats the name of a ParticleBehavior for display in the GED (Graphical Editor).
---
--- The formatted name includes the following elements:
--- - Bins: A string representation of the particle bins associated with the behavior.
--- - Label: The label of the behavior, if it has one, enclosed in double quotes.
--- - Editor Name: The name of the behavior class, or the EditorName property if it is set.
--- - Flags Label: If the behavior has a flags_label property, it is appended to the right side of the name.
---
--- The name is formatted with color tags to indicate the behavior type.
---
--- @return string The formatted name of the ParticleBehavior for display in the GED.
function ParticleBehavior:FormatNameForGed()
	local bins = self:FormatBins()
	local color = self:GetColorForGed()
	local label = ""
	if self.label ~= "" then
		label = "\"" .. self.label .. "\""
	end

	local name = string.format("<color %s>%s %s %s", color, bins, label, self.EditorName or self.class )
	if self.flags_label then
		name = name .. "<right>" .. self.flags_label
	end

	return name
end

local function FilterDynamicParamsForEditor(dynamic_params, editor)
	local available = {}
	for k, v in sorted_pairs(dynamic_params) do	
		if v.type  == editor then
			available[#available + 1] = k
		end
	end
	return available
end

-- Glue code to support editing in both Hedgehog and GED; to be removed

---
--- Switches the value of a dynamic parameter for a ParticleBehavior object.
---
--- @param root table The root object of the particle system.
--- @param obj ParticleBehavior The ParticleBehavior object to switch the parameter for.
--- @param prop string The name of the dynamic parameter property to toggle.
--- @param ... any Additional arguments to pass to the GedSwitchParam method.
---
--- @return any The result of calling the GedSwitchParam method.
function ParticleBehavior_SwitchParam(root, obj, prop, ...)
	return ParticleBehavior.GedSwitchParam(obj, root, prop, ...)
end

---
--- Switches the value of a dynamic parameter for a ParticleBehavior object.
---
--- @param root table The root object of the particle system.
--- @param prop string The name of the dynamic parameter property to toggle.
--- @param socket any Additional arguments to pass to the GedSwitchParam method.
---
--- @return any The result of calling the GedSwitchParam method.
function ParticleBehavior:GedSwitchParam(root, prop, socket)
	local parsys = GetParentTableOfKind(self, "ParticleSystemPreset")
	if parsys then
		self:ToggleProperty(prop, parsys:DynamicParams())
		ObjModified(self)
	end
end

---
--- Enables dynamic toggle functionality for the properties of a ParticleBehavior object.
---
--- @param dynamic_params table A table of dynamic parameters for the particle system.
---
function ParticleBehavior:EnableDynamicToggle(dynamic_params)
	local available_types = {}
	for k, v in sorted_pairs(dynamic_params) do
		available_types[v.type] = true
	end

	for i = 1, #self.properties do
		local prop = self.properties[i]
		if available_types[prop.orig_editor or prop.editor] and prop.dynamic then
			-- create override metadata for this property with different editor and toggle button

			prop.buttons = { {name = "Dynamic", func = "ParticleBehavior_SwitchParam"} }
			
			self.override_props = self.override_props or {}
			self.override_props[prop.id] = table.copy(prop)
			
			local available = FilterDynamicParamsForEditor(dynamic_params, prop.editor)
			self.override_props[prop.id].editor = "combo"
			self.override_props[prop.id].items = available
		else
			-- remove override metadata, value and toggle button
			prop.buttons = nil
			if self.override_props then
				self.override_props[prop.id] = nil
				if next(self.override_props) == nil then
					self.override_props = nil
				end
			end
			if self.override_value and self.override_value[prop.id] then
				self[prop.id] = self.override_value[prop.id]
				self.override_value[prop.id] = nil
				if next(self.override_value) == nil then
					self.override_value = nil
				end
			end
		end
	end
end

---
--- Toggles the value of a property in a ParticleBehavior object between the original value and a dynamic override value.
---
--- @param prop string The name of the property to toggle.
--- @param dynamic_params table A table of dynamic parameters for the particle system.
---
function ParticleBehavior:ToggleProperty(prop, dynamic_params)
	if self.override_value and self.override_value[prop] then
		local value = self.override_value[prop]
		self[prop] = value
		self.override_value[prop] = nil
		if next(self.override_value) == nil then
			self.override_value = nil
		end
	else
		self.override_value = self.override_value or {}
		self.override_value[prop] = self[prop]
		local new_meta = self.override_props[prop]
		self[prop] = new_meta.items[1]
	end
end


---
--- Returns a table of properties for the ParticleBehavior object, with any overridden properties replaced by their dynamic override values.
---
--- @return table The table of properties for the ParticleBehavior object.
---
function ParticleBehavior:GetProperties()
	if not self.override_props or not self.override_value then
		return self.properties
	end
	
	local props = {}
	for i = 1, #self.properties do
		local prop = self.properties[i]
		props[i] = self.override_value[prop.id] and self.override_props[prop.id] or prop
	end
	return props
end

---
--- Serializes a ParticleBehavior object to Lua code.
---
--- @param indent string The indentation string to use for the Lua code.
--- @param pstr string (optional) A string buffer to append the Lua code to.
--- @param GetPropFunc function (optional) A function to get the property value for the object.
--- @return string The Lua code representation of the ParticleBehavior object.
---
function ParticleBehavior:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		local props = ObjPropertyListToLuaCode(self, indent, GetPropFunc)
		local arr = ArrayToLuaCode(self, indent)
		local stored
		if self.override_value then
			stored = ValueToLuaCode(self.override_value, indent)
		end
		return string.format("PlaceObj('%s', %s, %s, %s)", self.class, props or "nil", arr or "nil", stored or "nil")
	else
		pstr:appendf("PlaceObj('%s', ", self.class)
		if not ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr) then
			pstr:append("nil")
		end
		pstr:append(", ")
		if not ArrayToLuaCode(self, indent, pstr) then
			pstr:append("nil")
		end
		pstr:append(", ")
		if self.override_value then
			pstr:appendv(self.override_value, indent)
		else
			pstr:append("nil")
		end
		return pstr:append(")")
	end
end

---
--- Constructs a ParticleBehavior object from Lua code.
---
--- @param props table A table of property values for the ParticleBehavior object.
--- @param arr table An array of additional data for the ParticleBehavior object.
--- @param stored table A table of overridden property values for the ParticleBehavior object.
--- @return ParticleBehavior The constructed ParticleBehavior object.
---
function ParticleBehavior:__fromluacode(props, arr, stored)
	local obj = PropertyObject.__fromluacode(self, props, arr)
	if stored then
		obj.override_value = stored
	end
	return obj
end

---
--- Clones a ParticleBehavior object, optionally overriding the override_value and override_props properties.
---
--- @param class string The class name of the object to clone.
--- @return ParticleBehavior The cloned ParticleBehavior object.
---
function ParticleBehavior:Clone(class)
	local obj = PropertyObject.Clone(self, class)
	if obj:IsKindOf(self.class) and self.override_value and self.override_props then
		obj.override_value = table.copy(self.override_value)
		obj.override_props = table.copy(self.override_props)
	end
	return obj
end
