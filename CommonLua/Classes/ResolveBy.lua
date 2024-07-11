
----- ResolveByDefId - serialize/unserialize object by position and matching def_id

DefineClass.ResolveByDefId = {
	__parents = { "CObject" }
}

--- Serializes a `ResolveByDefId` object by storing its position and definition ID.
---
--- @param obj ResolveByDefId The object to serialize.
--- @return string, table The serialized object data.
function ResolveByDefId.__serialize(obj)
	assert(IsValid(obj))
	if not IsValid(obj) then
		return
	end
	local pos, def_id = obj:GetPos(), obj:GetDefId()
	return "ResolveByDefId", { pos, def_id }
end

--- Deserializes a `ResolveByDefId` object from the provided data.
---
--- @param data table The serialized data, containing the position and definition ID of the object.
--- @return ResolveByDefId The deserialized object.
function ResolveByDefId.__unserialize(data)
	local pos, def_id = data[1], data[2]
	local obj = MapGetFirst(pos, 0, "ResolveByDefId", function(obj, def_id)
		return obj:GetDefId() == def_id
	end, def_id)
	assert(obj)
	return obj
end

--- Returns the definition ID of the `ResolveByDefId` object.
---
--- This function is a placeholder and should be implemented to return the definition ID of the object.
---
--- @return number The definition ID of the object.
function ResolveByDefId:GetDefId()
	assert(false)
end


----- ResolveByClassPos - serialize/unserialize object by position and class name

DefineClass.ResolveByClassPos = {
	__parents = { "CObject" }
}

--- Serializes a `ResolveByClassPos` object by storing its position and class name.
---
--- @param obj ResolveByClassPos The object to serialize.
--- @return string, table The serialized object data.
function ResolveByClassPos.__serialize(obj)
	assert(IsValid(obj))
	if not IsValid(obj) then
		return
	end
	return "ResolveByClassPos", { obj:GetPos(), obj.class }
end

--- Deserializes a `ResolveByClassPos` object from the provided data.
---
--- @param data table The serialized data, containing the position and class name of the object.
--- @return ResolveByClassPos The deserialized object.
function ResolveByClassPos.__unserialize(data)
	local pos, class = data[1], data[2]
	local obj = MapGetFirst(pos, 0, class)
	assert(obj)
	return obj
end


----- ResolveByCopy - serialize/unserialize object by creating a copy of it

DefineClass.ResolveByCopy = {
	__parents = { "PropertyObject" }
}

-- needed for the prefab serialization
--- Serializes a `ResolveByCopy` object by storing its class name and property values.
---
--- This function is used to serialize a `ResolveByCopy` object for storage or transmission. It iterates through the object's properties, skipping any properties marked as `dont_save` or without an `editor` flag. For each remaining property, it stores the property ID and value in the serialized data, unless the value is the default for that property.
---
--- @param obj ResolveByCopy The object to serialize.
--- @return string, table The serialized object data, containing the class name and property values.
function ResolveByCopy.__serialize(obj)
	local data = { obj.class }
	local n = 1
	local prop_eval = prop_eval
	local GetProperty = obj.GetProperty
	for i, prop in ipairs(obj:GetProperties()) do
		if not prop_eval(prop.dont_save, obj, prop) and prop.editor then
			local id = prop.id
			local value = GetProperty(obj, id)
			if not obj:IsDefaultPropertyValue(id, prop, value) then
				data[n + 1] = id
				data[n + 2] = value
				n = n + 2
			end
		end
	end
	return "ResolveByCopy", data
end

--- Deserializes a `ResolveByCopy` object from the provided data.
---
--- This function is used to deserialize a `ResolveByCopy` object that was previously serialized using the `ResolveByCopy.__serialize` function. It creates a new instance of the object's class and sets the property values from the serialized data.
---
--- @param data table The serialized data, containing the class name and property values.
--- @return ResolveByCopy The deserialized object.
function ResolveByCopy.__unserialize(data)
	local class = data[1]
	local classdef = g_Classes[class]
	assert(classdef)
	if not classdef then
		return
	end
	local obj = classdef:new()
	local SetPropFunc = obj.SetProperty
	for i = 2, #data, 2 do
		local id, value = data[i], data[i + 1]
		SetPropFunc(obj, id, value)
	end
	return obj
end