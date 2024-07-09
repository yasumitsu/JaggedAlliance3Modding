--- An object which can resolve a key to a value.
-- Context objects can be nested to create a complex value resolution structure.
-- The global function ResolveValue allows resolving a tuple to a value in an arbitrary context.

DefineClass.Context = {
	__parents = {},
	__hierarchy_cache = true,	
}

--- Creates a new Context object.
-- @param obj A table to use as the new Context object. If nil, a new empty table is created.
-- @return The new Context object.
function Context:new(obj)
	return setmetatable(obj or {}, self)
end

---
--- Resolves the value associated with the given key in the context.
--- If the key is not found in the current context, it recursively searches the sub-contexts.
---
--- @param key string The key to resolve
--- @return any The value associated with the key, or `nil` if not found
---
function Context:ResolveValue(key)
	local value = rawget(self, key)
	if value ~= nil then return value end
	for _, sub_context in ipairs(self) do
		value = ResolveValue(sub_context, key)
		if value ~= nil then return value end
	end
end

-- change __index method to allow full member resolution without warning
function OnMsg.ClassesBuilt()
	local context_class = g_Classes.Context
	context_class.__index = function (self, key)
		if type(key) == "string" then
			return rawget(context_class, key) or context_class.ResolveValue(self, key)
		end
	end
end

---
--- Checks if the current context or any of its sub-contexts are instances of the specified class(es).
---
--- @param ... string|table The class(es) to check against
--- @return boolean True if the current context or any sub-context is an instance of the specified class(es), false otherwise
---
function Context:IsKindOf(class)
	if IsKindOf(self, class) then return true end
	for _, sub_context in ipairs(self) do
		if IsKindOf(sub_context, "Context") and sub_context:IsKindOf(class) or IsKindOf(sub_context, class) then
			return true
		end
	end
end

---
--- Checks if the current context or any of its sub-contexts are instances of the specified class(es).
---
--- @param ... string|table The class(es) to check against
--- @return boolean True if the current context or any sub-context is an instance of the specified class(es), false otherwise
---
function Context:IsKindOfClasses(...)
	if IsKindOfClasses(self, ...) then return true end
	for _, sub_context in ipairs(self) do
		if IsKindOf(sub_context, "Context") and sub_context:IsKindOfClasses(...) or IsKindOfClasses(sub_context, ...) then
			return true
		end
	end
end

---
--- Iterates over all objects in the given context, calling the provided function for each object.
---
--- @param context table|Context The context to iterate over.
--- @param f function The function to call for each object in the context.
--- @param ... any Additional arguments to pass to the function.
---
function ForEachObjInContext(context, f, ...)
	if not context then return end
	if IsKindOf(context, "Context") then
		for _, sub_context in ipairs(context) do
			ForEachObjInContext(sub_context, f, ...)
		end
	else
		f(context, ...)
	end
end

---
--- Creates a new Context object from the given table or object.
---
--- @param context table|any The table or object to create the new Context from.
--- @return Context The new Context object.
---
function SubContext(context, t)
	assert(not IsKindOf(t, "PropertyObject"))
	t = t or {}
	if IsKindOf(context, "PropertyObject") or type(context) ~= "table" then
		t[#t + 1] = context
	elseif type(context) == "table" then
		for _, obj in ipairs(context) do
			t[#t + 1] = obj
		end
		for k, v in pairs(context) do
			if rawget(t, k) == nil then
				t[k] = v
			end
		end
	end
	return Context:new(t)
end

---
--- Resolves the value of the given key in the provided context.
---
--- @param context table|Context|PropertyObject The context to resolve the value in.
--- @param key string The key to resolve the value for.
--- @param ... any Additional arguments to pass to the resolved value.
--- @return any The resolved value.
---
function ResolveValue(context, key, ...)
	if key == nil then return context end
	if type(context) == "table" then
		if IsKindOfClasses(context, "Context", "PropertyObject") then
			return ResolveValue(context:ResolveValue(key), ...)
		end
		return ResolveValue(rawget(context, key), ...)
	end
end

---
--- Resolves a function from the given context.
---
--- @param context table|Context|PropertyObject The context to resolve the function from.
--- @param key string The key of the function to resolve.
--- @return function|nil The resolved function, or nil if not found.
--- @return table|nil The object the function was found on, or nil if not found.
---
function ResolveFunc(context, key)
	if key == nil then return end
	if type(context) == "table" then
		if IsKindOf(context, "Context") then
			local f = rawget(context, key)
			if type(f) == "function" then
				return f
			end
			for _, sub_context in ipairs(context) do
				local f, obj = ResolveFunc(sub_context, key)
				if f ~= nil then return f, obj end
			end
			return
		end
		if IsKindOf(context, "PropertyObject") and context:HasMember(key) then
			local f = context[key]
			if type(f) == "function" then return f, context end
		else
			local f = rawget(context, key)
			if f == false or type(f) == "function" then return f end
		end
	end
end

---
--- Resolves a PropertyObject from the given context.
---
--- @param context table|Context|PropertyObject The context to resolve the PropertyObject from.
--- @return PropertyObject|nil The resolved PropertyObject, or nil if not found.
---
function ResolvePropObj(context)
	if IsKindOf(context, "PropertyObject") then
		return context
	end
	if IsKindOf(context, "Context") then
		for _, sub_context in ipairs(context) do
			local obj = ResolvePropObj(sub_context)
			if obj then return obj end
		end
	end
end

