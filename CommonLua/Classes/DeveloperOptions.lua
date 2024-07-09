DefineClass.DeveloperOptions = {
	__parents = { "PropertyObject" },
	option_name = "",
}

---
--- Gets the value of a property for this DeveloperOptions object.
---
--- @param property string The name of the property to get.
--- @return any The value of the specified property.
function DeveloperOptions:GetProperty(property)
	local meta = table.find_value(self.properties, "id", property)
	if meta and not prop_eval(meta.dont_save, self, meta) then
		return GetDeveloperOption(property, self.class, self.option_name, meta.default)
	end
	return PropertyObject.GetProperty(self, property)
end

---
--- Sets the value of a property for this DeveloperOptions object.
---
--- @param property string The name of the property to set.
--- @param value any The new value for the specified property.
--- @return any The new value of the specified property.
function DeveloperOptions:SetProperty(property, value)
	local meta = table.find_value(self.properties, "id", property)
	if meta and not prop_eval(meta.dont_save, self, meta) then
		return SetDeveloperOption(property, value, self.class, self.option_name)
	end
	return PropertyObject.SetProperty(self, property, value)
end

---
--- Gets the value of a developer option from the local storage.
---
--- @param option string The name of the developer option to retrieve.
--- @param storage string (optional) The storage category for the option. Defaults to "Developer".
--- @param substorage string (optional) The subcategory for the option. Defaults to "General".
--- @param default any (optional) The default value to return if the option is not found.
--- @return any The value of the specified developer option, or the default value if not found.
function GetDeveloperOption(option, storage, substorage, default)
	storage = storage or "Developer"
	substorage = substorage or "General"
	local ds = LocalStorage and LocalStorage[storage]
	return ds and ds[substorage] and ds[substorage][option] or default or false
end

---
--- Sets a developer option in the local storage.
---
--- @param option string The name of the developer option to set.
--- @param value any The new value for the developer option.
--- @param storage string (optional) The storage category for the option. Defaults to "Developer".
--- @param substorage string (optional) The subcategory for the option. Defaults to "General".
--- @return any The new value of the specified developer option.
function SetDeveloperOption(option, value, storage, substorage)
	if not LocalStorage then
		print("no local storage available!")
		return
	end
	storage = storage or "Developer"
	substorage = substorage or "General"
	value = value or nil
	local infos = LocalStorage[storage] or {}
	local info = infos[substorage] or {}
	info[option] = value
	infos[substorage] = info
	LocalStorage[storage] = infos
	Msg("DeveloperOptionsChanged", storage, substorage, option, value)
	DelayedCall(0, SaveLocalStorage)
end

---
--- Gets the developer history for the specified class and name.
---
--- @param class string The class name for the developer history.
--- @param name string The name for the developer history.
--- @return table The list of developer history entries.
function GetDeveloperHistory(class, name)
	if not LocalStorage then
		return {}
	end
	
	local history = LocalStorage.History or {}
	LocalStorage.History = history
	
	history[class] = history[class] or {}
	local list = history[class][name] or {}
	history[class][name] = list
	
	return list
end


---
--- Adds a new entry to the developer history for the specified class and name.
---
--- @param class string The class name for the developer history.
--- @param name string The name for the developer history.
--- @param entry any The new entry to add to the history.
--- @param max_size number (optional) The maximum size of the history list. Defaults to 20.
--- @param accept_empty boolean (optional) Whether to accept empty entries. Defaults to false.
--- @return void
function AddDeveloperHistory(class, name, entry, max_size, accept_empty)
	max_size = max_size or 20
	if not LocalStorage or not accept_empty and (entry or "") == "" then
		return
	end
	local history = GetDeveloperHistory(class, name)
	table.remove_entry(history, entry)
	table.insert(history, 1, entry)
	while #history > max_size do
		table.remove(history)
	end
	SaveLocalStorageDelayed()
end