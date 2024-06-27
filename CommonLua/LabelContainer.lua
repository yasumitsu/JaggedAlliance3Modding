---
--- Defines a container for managing labels and their associated effects.
--- The `LabelContainer` class provides methods for adding, removing, and clearing labels,
--- as well as applying effects to objects associated with those labels.
---
--- @class LabelContainer
--- @field labels table A table of labels, where each label is a key that maps to a list of associated objects.
--- @field label_effects table A table of effects associated with each label.
DefineClass.LabelContainer = {
	__parents = { "InitDone", "ContinuousEffectContainer" },
	labels = false,
	label_effects = false,
}

---
--- Initializes the LabelContainer object by setting up the labels and label_effects tables.
---
--- @function LabelContainer:Init
--- @return nil
function LabelContainer:Init()
	self.labels = {}
	self.label_effects = {}
end

---
--- Initializes an empty label in the LabelContainer.
---
--- @param label string The label to initialize.
---
function LabelContainer:InitEmptyLabel(label)
	self.labels[label] = self.labels[label] or {}
end

---
--- Adds an object to the specified label in the LabelContainer.
---
--- @param label string The label to add the object to.
--- @param obj any The object to add to the label.
--- @return boolean true if the object was added successfully, false otherwise.
function LabelContainer:AddToLabel(label, obj)
	if not label then return end
	local label_list = self.labels[label]
	if label_list then
		if table.find(label_list, obj) then return end -- already added
		label_list[#label_list + 1] = obj
	else
		self.labels[label] = { obj }
	end
	
	local effects = self.label_effects[label]
	for _, effect in pairs(effects or empty_table) do
		obj:StartEffect(effect)
	end
	Msg("AddedToLabel", label, obj)
	return true
end

---
--- Removes an object from the specified label in the LabelContainer.
---
--- @param label string The label to remove the object from.
--- @param obj any The object to remove from the label.
--- @return boolean true if the object was removed successfully, false otherwise.
function LabelContainer:RemoveFromLabel(label, obj)
	local label_list = self.labels[label]
	if label_list and table.remove_entry(label_list, obj) then
		local effects = self.label_effects[label]
		for _, effect in pairs(effects or empty_table) do
			obj:StopEffect(effect.Id)
		end
		Msg("RemovedFromLabel", label, obj)
		return true
	end
end

---
--- Clears all objects from the specified label in the LabelContainer.
---
--- @param label string The label to clear.
function LabelContainer:ClearLabel(label)
	local effects = self.label_effects[label]
	for _, obj in ipairs(self.labels[label] or empty_table) do
		for _, effect in pairs(effects or empty_table) do
			obj:StopEffect(effect.Id)
		end
	end
	self.labels[label] = {}
end

---
--- Checks if the specified object is in the given label.
---
--- @param label string The label to check.
--- @param obj any The object to check for.
--- @return boolean true if the object is in the label, false otherwise.
function LabelContainer:IsInLabel(label, obj)
	if table.find(self.labels[label], obj) then
		return true
	end
	return false
end

---
--- Attaches a continuous effect to the specified label in the LabelContainer.
---
--- @param label string The label to attach the effect to.
--- @param effect ContinuousEffect The effect to attach to the label.
--- @param make_permanent boolean (optional) Whether to make the effect permanent for the label. Defaults to true.
function LabelContainer:AttachEffectToLabel(label, effect, make_permanent)
	assert(IsKindOf(effect, "ContinuousEffect"))
	
	make_permanent = make_permanent ~= false
	
	local effects
	if make_permanent then
		effects = self.label_effects[label] or {}
		effects[effect.Id] = effect
	end
	for _, obj in ipairs(self.labels[label] or empty_table) do
		obj:StartEffect(effect) -- this will stop the old effect with the id if it exists
	end
	if make_permanent then
		self.label_effects[label] = effects
	end
end

---
--- Detaches a continuous effect from the specified label in the LabelContainer.
---
--- @param label string The label to detach the effect from.
--- @param id string The ID of the effect to detach.
function LabelContainer:DetachEffectFromLabel(label, id)
	local effects = self.label_effects[label] or {}
	effects[id] = nil
	for _, obj in ipairs(self.labels[label] or empty_table) do
		obj:StopEffect(id)
	end	
end

---
--- Iterates over all objects in the specified label and calls the provided function for each object.
---
--- @param label string The label to iterate over.
--- @param func function The function to call for each object in the label. The function should take the object as the first argument, and any additional arguments provided to this method.
--- @param ... any Additional arguments to pass to the provided function.
---
function LabelContainer:ForEachInLabel(label, func, ...)
	for _, obj in ipairs(self.labels[label] or empty_table) do
		func(obj, ...)
	end
end

---
--- Gets the first object in the specified label that matches the provided filter function.
---
--- @param label string The label to search.
--- @param filter function (optional) A function that takes an object and returns a boolean indicating whether it matches the filter.
--- @param ... any Additional arguments to pass to the filter function.
--- @return any The first object in the label that matches the filter, or nil if no object matches.
function LabelContainer:GetFirstInLabel(label, filter, ...)
	for _, obj in ipairs(self.labels[label] or empty_table) do
		if not filter or filter(obj, ...) then
			return obj
		end
	end
end

---
--- Resets all labels in the LabelContainer.
---
--- This method clears the contents of all labels in the LabelContainer, effectively resetting them to an empty state.
---
function LabelContainer:ResetLabels()
	local labels = self.labels
	for name, _ in pairs(labels) do
		labels[name] = {}
	end
end

---
--- Iterates over all objects in all labels and calls the provided function for each object.
---
--- @param func function The function to call for each object. The function should take the object as the first argument, and any additional arguments provided to this method.
--- @param ... any Additional arguments to pass to the provided function.
---
function LabelContainer:ForEachInLabels(func, ...)
	local labels = self.labels
	for _, label in pairs(labels) do
		for _, obj in ipairs(label) do
			func(obj, ...)
		end
	end
end

----

---
--- Defines a class called `LabelElement` that inherits from the `PropertyObject` class.
---
--- The `LabelElement` class is likely used to represent an element that can be associated with one or more labels. This class likely provides methods and properties for managing the labels associated with the element.
---
--- @class LabelElement
--- @field __parents table The parent classes that `LabelElement` inherits from.
--- @field ForEachLabel function A method that iterates over the labels associated with the `LabelElement` instance and calls a provided function for each label.
--- @field CheckLabelName function A method that checks if the `LabelElement` instance has a label with the specified name.
--- @field AddToLabels function A method that adds the `LabelElement` instance to the specified `LabelContainer`.
--- @field RemoveFromLabels function A method that removes the `LabelElement` instance from the specified `LabelContainer`.
DefineClass.LabelElement = {
	__parents = { "PropertyObject" },
}

---
--- Adds the `LabelElement` instance to the specified `LabelContainer`.
---
--- This method iterates over all the labels associated with the `LabelElement` instance and adds the instance to the corresponding label in the specified `LabelContainer`.
---
--- @param container LabelContainer The `LabelContainer` to add the `LabelElement` instance to.
---
function LabelElement:AddToLabels(container)
	if not container then return end
	self:ForEachLabel(function(label, self, container)
		container:AddToLabel(label, self)
	end, self, container)
end

---
--- Removes the `LabelElement` instance from the specified `LabelContainer`.
---
--- This method iterates over all the labels associated with the `LabelElement` instance and removes the instance from the corresponding label in the specified `LabelContainer`.
---
--- @param container LabelContainer The `LabelContainer` to remove the `LabelElement` instance from.
---
function LabelElement:RemoveFromLabels(container)
	if not container then return end
	self:ForEachLabel(function(label, self, container)
		container:RemoveFromLabel(label, self)
	end, self, container)
end

local __found = false
local function __CheckLabelName(label, self, name)
	__found = __found or name == label
end
---
--- Checks if the `LabelElement` instance has a label with the specified name.
---
--- This method iterates over all the labels associated with the `LabelElement` instance and checks if any of them match the specified name. It sets the `__found` flag to `true` if a matching label is found.
---
--- @param name string The name of the label to check for.
--- @return boolean true if the `LabelElement` instance has a label with the specified name, false otherwise.
---
function LabelElement:CheckLabelName(name)
	__found = false
	self:ForEachLabel(__CheckLabelName, self, name)
	return __found
end

RecursiveCallMethods.ForEachLabel = "call"
LabelElement.ForEachLabel = empty_func

---
--- Collects all labels used by `LabelElement` instances in the codebase.
---
--- This function iterates over all `LabelElement` instances in the codebase and collects the unique labels used by them. It then returns a table containing all the collected labels.
---
--- @return table A table containing all the unique labels used by `LabelElement` instances in the codebase.
---
function AllLabelsComboItems()
	local labels = {}
	-- collect auto labels
	ClassDescendants("LabelElement", function(name, def, labels)
		def:ForEachLabel(function(label, labels)
			labels[label] = true
		end, labels)
	end, labels)
	-- collect runtime custom labels
	Msg("GatherAllLabels", labels)
	return table.keys(labels, true)
end