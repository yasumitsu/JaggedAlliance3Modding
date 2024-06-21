---@class ClassNonInheritableMembers
---A table containing the names of class members that are not inheritable.
---@field __index boolean
---@field __parents boolean
---@field __ancestors boolean
---@field __generated_by_class boolean
---@field NoInstances boolean
---@field class boolean

---@class noncopyable
---A table containing the names of class members that are not copyable.
---@field __hierarchy_cache boolean
ClassNonInheritableMembers = {
	__index = true,
	__parents = true,
	__ancestors = true,
	__generated_by_class = true,
	NoInstances = true,
	class = true,
}
local noninheritable = ClassNonInheritableMembers

---@class noncopyable
---A table containing the names of class members that are not copyable.
---@field __hierarchy_cache boolean
local noncopyable = {
	__hierarchy_cache = true,
}

---@class RecursiveCallMethods
---A table containing the names of methods that should be recursively called on child objects.

---@class AutoResolveMethods
---A table containing the names of methods that should be automatically resolved on child objects.

---@param table table
---@param key any
---Resolves missing members on the given table, reporting them as syntax errors.
local function ReportMissingMembers(table, key)
end

---@type table<string, boolean>
local AutoResolveMethods = AutoResolveMethods

---@type fun(t: table): boolean
local ClassesResolved = ClassesResolved
RecursiveCallMethods = {}
AutoResolveMethods = {}
local AutoResolveMethods = AutoResolveMethods
local ipairs = ipairs
local pairs = pairs
local icopy = table.icopy
local copy = table.copy
local map = table.map
local insert_unique = table.insert_unique
local find = table.find
local insert = table.insert
local remove = table.remove
local clear = table.clear
local concat = table.concat
local developer = Platform.developer

---
--- Initializes or clears the global `g_Classes` table, which is used to store class definitions.
---
--- If `FirstLoad` is true, the `g_Classes` table is initialized as an empty table.
--- Otherwise, if `g_Classes` already exists, all class names in the table are removed from the global namespace.
---
--- This code is likely executed when the script is first loaded, to ensure a clean slate for class definitions.
---
if FirstLoad then
	g_Classes = {}
else
	for name, class in pairs(g_Classes) do
		rawset(_G, name, nil)
	end
end

---@class classdefs
---A table that stores class definitions.
---This table is likely used to keep track of all the classes that have been defined in the codebase.
---It serves as a central registry for class information, which can be useful for various class-related operations.
local classdefs = {}
---A table that stores the resolved classes.
---This table is likely used to keep track of which classes have been successfully resolved and defined.
---It serves as a way to avoid repeatedly resolving the same classes, which can improve performance.
local resolved = {}
---
--- Retrieves the global `g_Classes` table, which is used to store class definitions.
---
--- This variable provides access to the central registry of class information, which can be useful for various class-related operations.
---
--- @return table The `g_Classes` table containing class definitions.
---
local classes = g_Classes
---
--- A table that stores the ancestors of classes based on their parent classes.
--- This table is likely used to keep track of the inheritance hierarchy of classes,
--- which can be useful for various class-related operations such as method resolution.
---
local ancestors_by_parents = {}

---
--- Checks if the `classdefs` table is `nil`, indicating that the classes have not been resolved yet.
---
--- @return boolean `true` if the classes have not been resolved, `false` otherwise.
---
function ClassesResolved()
	return classdefs == nil
end

-- report as syntax errors all member access for uninitialized members
---
--- Handles the reporting of access to undefined class members.
---
--- This function is used as the `__index` metamethod for a table that represents an uninitialized class member.
--- When an attempt is made to access a member of this table, this function is called to handle the error.
---
--- If the key being accessed is a number, it is assumed to be an array index, and an assertion is raised with a message indicating that the class member is undefined.
--- If the key is not a number, the assertion message includes the name of the class and the member being accessed.
---
--- @param table table The table representing the uninitialized class member.
--- @param key any The key being accessed in the table.
---
function ReportMissingMembers(table, key)
	if type(key) ~= "number" then
		assert(false, "Access of an undefined class member " .. tostring(table.class) .. "." .. tostring(key), 1)
	end
end
---
--- A table that reports access to undefined class members.
---
--- This table is used as the `__index` metamethod for a table that represents an uninitialized class member. When an attempt is made to access a member of this table, the `ReportMissingMembers` function is called to handle the error.
---
--- If the key being accessed is a number, it is assumed to be an array index, and an assertion is raised with a message indicating that the class member is undefined. If the key is not a number, the assertion message includes the name of the class and the member being accessed.
---
--- @field __index function The function that handles access to undefined class members.
---
local report_missing_members = {
	__index = ReportMissingMembers,
}

-- defining classes
-- syntax DefineClass.<class name> = <classdef>
-- syntax DefineClass(<class name>, <classdef>)
-- syntax DefineClass(<class name>, parent1, parent2, ...)

---
--- Defines a new class in the codebase.
---
--- This function is used to define a new class in the codebase. It takes the name of the class and a class definition table as arguments.
---
--- The class definition table can either be a table with a `__parents` field containing a list of parent classes, or a single parent class definition.
---
--- This function performs the following steps:
--- 1. Checks if the class is being redefined, and raises an assertion error if so.
--- 2. Checks if the class name conflicts with a global variable, and raises an assertion error if so.
--- 3. Sets the class name global to the class definition table.
--- 4. Adds the class definition to the `classdefs` table.
--- 5. Asserts that the class definition has either a `__parents` field or a `__parent` field, but not both.
---
--- @param class string The name of the class to define.
--- @param class_def table The class definition table.
--- @param ... table Any additional parent classes.
--- @return table The class definition table.
---
local function define(class, class_def, ...)
	if type(class_def) == "table" then
		assert(select("#", ...) == 0, "DefineClass excess parameters ignored")
	else
		class_def = { __parents = { class_def, ... } }
	end
	
	-- check for duplicate classes	
	assert(not classdefs[class], "Redefinition of class " .. class, 1)
	if rawget(_G, class) ~= nil then
		assert(classdefs[class], "Class " .. class .. " conflicts with a global variable")
		return
	end
	-- point class name global to the class def (after the classes are built it will be changed to the class itself)
	rawset(_G, class, class_def)
	classdefs[class] = class_def

	assert(class_def.__parents or class_def.__parent == nil, string.format("There is '%s.__parent' which should most likely be '__parents'.", class))

	return class_def
end

---
--- Removes a class definition from the codebase.
---
--- This function is used to remove a class definition from the codebase. It takes the name of the class to be removed as an argument.
---
--- The function first checks if the class definition exists in the `classdefs` table. If it does, it removes the class definition from the `classdefs` table and removes the global variable with the same name as the class.
---
--- @param class string The name of the class to be removed.
---
local function undefine(class)
	if classdefs[class] then
		classdefs[class] = nil
		_G[class] = nil
	end
end

---
--- Defines a new class in the codebase.
---
--- This function is a wrapper around the `define` function, which is used to define new classes in the codebase. It sets up a function call table for the `define` function, allowing it to be called using the `DefineClass` global variable.
---
--- @param class string The name of the class to define.
--- @param class_def table The class definition table.
--- @param ... table Any additional parent classes.
--- @return table The class definition table.
---
DefineClass = SetupFuncCallTable(define)
---
--- Defines a new function call table for the `undefine` function.
---
--- This function is used to create a new function call table for the `undefine` function, which is used to remove a class definition from the codebase. The function call table is created using the `SetupFuncCallTable` function, which allows the `undefine` function to be called using the `UndefineClass` global variable.
---
--- @param class string The name of the class to be removed.
--- @return function The `undefine` function wrapped in a function call table.
---
UndefineClass = SetupFuncCallTable(undefine)

---
--- Represents an unresolved function that always asserts false.
---
--- This function is used as a placeholder for unresolved functions in the codebase. When called, it will always assert that the condition is false, indicating that the function has not been properly resolved.
---
--- @function unresolved_func
--- @return nil
local function unresolved_func()
	assert(false)
end

---
--- Schedules an auto-resolve for a class member.
---
--- This function is used to schedule an auto-resolve for a class member. It takes the name of the class, the name of the member, and two class references as arguments. The function then updates the `auto_resolved` table to keep track of the classes that have been auto-resolved for the given member.
---
--- @param classname string The name of the class.
--- @param member string The name of the member.
--- @param class1 function The first class reference.
--- @param class2 function The second class reference.
--- @param auto_resolved table The table of auto-resolved classes.
---
local function ScheduleAutoResolve(classname, member, class1, class2, auto_resolved)
	local method_to_classes = auto_resolved[classname] or {}
	auto_resolved[classname] = method_to_classes
	local classes = method_to_classes[member]
	if not classes then
		classes = {}
		method_to_classes[member] = classes
	end
	if class1 ~= unresolved_func then
		insert_unique(classes, class1)
	end
	if class2 ~= unresolved_func then
		insert_unique(classes, class2)
	end
end

---
--- Recursively gathers all auto-resolved methods for a given method and class hierarchy.
---
--- This function is used to gather all auto-resolved methods for a given method and class hierarchy. It takes a list of functions, the name of the method, a list of classes, and the auto-resolved table as arguments. It then recursively traverses the class hierarchy, adding any unresolved methods to the list of functions.
---
--- @param funcs table The list of functions to be gathered.
--- @param method string The name of the method.
--- @param classes table The list of classes to be traversed.
--- @param auto_resolved table The table of auto-resolved classes.
---
local function GatherAutoResolved(funcs, method, classes, auto_resolved)
	for _, class in ipairs(classes) do
		local method_to_classes = auto_resolved[class]
		local parents = method_to_classes and method_to_classes[method]
		if not parents then
			local func = classdefs[class][method]
			insert_unique(funcs, func)
		else
			-- the method has been auto-resolved in the parent too
			GatherAutoResolved(funcs, method, parents, auto_resolved)
		end
	end
end


----- CombinedMethodGenerator

---
--- A table that contains functions for generating combined methods.
---
--- The `CombinedMethodGenerator` table contains functions that can be used to generate a single combined method from a list of methods. This is useful when a class inherits from multiple parent classes and needs to combine the implementations of a method from those parent classes.
---
--- The available functions in the `CombinedMethodGenerator` table are:
---
--- - `call`: Generates a combined method that calls all the methods in the provided list in order.
--- - `procall_parents_last`: Generates a combined method that calls all the methods in the provided list, with the methods from the parent classes being called last.
---
--- These functions can be used to automatically generate the combined method implementation for a class, reducing the amount of boilerplate code that needs to be written.
---
CombinedMethodGenerator = {}

---
--- Removes all entries of a given value from an array.
---
--- This function takes an array and a value as arguments, and removes all occurrences of the value from the array. It iterates through the array in reverse order, and removes the element at the current index if it matches the given value.
---
--- @param array table The array to remove entries from.
--- @param entry any The value to remove from the array.
---
function remove_entries(array, entry)
end
local function remove_entries(array, entry)
	for i = #(array or ""), 1, -1 do
		if array[i] == entry then
			remove(array, i)
		end
	end
end

---
--- Generates a combined method that calls all the methods in the provided list in order.
---
--- This function takes a list of methods as input and returns a new method that calls all the methods in the list in the order they are provided. If the list is empty, it returns an empty function. If the list has only one method, it returns that method directly. For lists of two or three methods, it generates optimized versions of the combined method. For longer lists, it generates a loop that calls all the methods in reverse order.
---
--- @param method_list table A list of methods to combine.
--- @return function The combined method.
---
CombinedMethodGenerator["call"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then return method_list[1] end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			f1(obj, ...)
			f2(obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			f1(obj, ...)
			f2(obj, ...)
			f3(obj, ...)
		end
	end
	return function (obj, ...)
		for i = 1, count do
			method_list[i](obj, ...)
		end
	end
end

CombinedMethodGenerator[true] = CombinedMethodGenerator["call"]

CombinedMethodGenerator["procall_parents_last"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then
		local f = method_list[1]
		return function (obj, ...)
			procall(f, obj, ...)
		end
	end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			procall(f2, obj, ...)
			procall(f1, obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			procall(f3, obj, ...)
			procall(f2, obj, ...)
			procall(f1, obj, ...)
		end
	end
	return function (obj, ...)
		for i = count, 1, -1 do
			procall(method_list[i], obj, ...)
		end
	end
end

CombinedMethodGenerator["procall"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then
		local f = method_list[1]
		return function (obj, ...)
			procall(f, obj, ...)
		end
	end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			procall(f1, obj, ...)
			procall(f2, obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			procall(f1, obj, ...)
			procall(f2, obj, ...)
			procall(f3, obj, ...)
		end
	end
	return function (obj, ...)
		for i = 1, count do
			procall(method_list[i], obj, ...)
		end
	end
end

CombinedMethodGenerator["sprocall"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then
		local f = method_list[1]
		return function (obj, ...)
			sprocall(f, obj, ...)
		end
	end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			sprocall(f1, obj, ...)
			sprocall(f2, obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			sprocall(f1, obj, ...)
			sprocall(f2, obj, ...)
			sprocall(f3, obj, ...)
		end
	end
	return function (obj, ...)
		for i = 1, count do
			sprocall(method_list[i], obj, ...)
		end
	end
end

CombinedMethodGenerator["and"] = function (method_list)
	remove_entries(method_list, return_true)
	local count = #(method_list or "")
	if count == 0 then return return_true end
	if count == 1 then return method_list[1] end
	if find(method_list, empty_func) then return empty_func end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			return f1(obj, ...) and f2(obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			return f1(obj, ...) and f2(obj, ...) and f3(obj, ...)
		end
	end
	return function (obj, ...)
		local result
		for i = 1, count do
			result = method_list[i](obj, ...)
			if not result then return result end
		end
		return result
	end
end

CombinedMethodGenerator["or"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then return method_list[1] end
	if find(method_list, return_true) then return return_true end
	if count == 2 then -- a vast majority of the combined methods
		local f1, f2 = method_list[1], method_list[2]
		return function (obj, ...)
			return f1(obj, ...) or f2(obj, ...)
		end
	end
	if count == 3 then -- a large percentage of the combined methods
		local f1, f2, f3 = method_list[1], method_list[2], method_list[3]
		return function (obj, ...)
			return f1(obj, ...) or f2(obj, ...) or f3(obj, ...)
		end
	end
	return function (obj, ...)
		local result
		for i = 1, count do
			result = method_list[i](obj, ...)
			if result then return result end
		end
		return result
	end
end

CombinedMethodGenerator["+"] = function (method_list)
	remove_entries(method_list, empty_func)
	remove_entries(method_list, return_0)
	local count = #(method_list or "")
	if count == 0 then return return_0 end
	if count == 1 then return method_list[1] end
	return function (obj, ...)
		local result = method_list[1](obj, ...) or 0
		for i = 2, count do
			result = result + (method_list[i](obj, ...) or 0)
		end
		return result
	end
end

CombinedMethodGenerator["max"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then return method_list[1] end
	return function (obj, ...)
		local result = method_list[1](obj, ...)
		for i = 2, count do
			if type(result) ~= "number" then 
				result = method_list[i](obj, ...)
			else
				local next_result = method_list[i](obj, ...)
				if type(next_result) == "number" then
					result = Max(result, next_result)
				end
			end
		end
		return result
	end
end

CombinedMethodGenerator["%"] = function (method_list)
	remove_entries(method_list, empty_func)
	remove_entries(method_list, return_100)
	local count = #(method_list or "")
	if count == 0 then return return_100 end
	if count == 1 then return method_list[1] end
	if find(method_list, return_0) then return return_0 end
	return function (obj, ...)
		local result = method_list[1](obj, ...) or 100
		for i = 2, count do
			result = MulDivRound(result, method_list[i](obj, ...) or 100, 100)
		end
		return result
	end
end

CombinedMethodGenerator[".."] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then return method_list[1] end
	return function (obj, ...)
		local result = method_list[1](obj, ...) or ""
		if result == "" then result = nil end
		local results_list
		for i = 2, #method_list do
			local next_result = method_list[i](obj, ...) or ""
			if next_result ~= "" then
				if not result then
					result = next_result
				elseif results_list then
					results_list[#results_list + 1] = next_result
				else
					results_list = { result, next_result }
				end
			end
		end
		return results_list and concat(results_list, "\n") or result or ""
	end
end

CombinedMethodGenerator["modify"] = function (method_list)
	remove_entries(method_list, return_first)
	local count = #(method_list or "")
	if count == 0 then return return_first end
	if count == 1 then return method_list[1] end
	return function (obj, result, ...)
		for i = 1, count do
			result = method_list[i](obj, result, ...) or result
		end
		return result
	end
end

CombinedMethodGenerator["returncall"] = function (method_list)
	remove_entries(method_list, empty_func)
	local count = #(method_list or "")
	if count == 0 then return empty_func end
	if count == 1 then return method_list[1] end
	return function (obj, ...)
		local return_funcs = {}
		for i = 1, count do
			local ret = method_list[i](obj, ...)
			if type(ret) == "function" then
				table.insert(return_funcs, ret) 
			end
		end
		return function(...)
			for i = 1, #return_funcs do
				return_funcs[i](...)
			end
		end
	end
end

---
--- Automatically resolves the methods of a class based on the provided `methods` table.
---
--- @param class string The name of the class to resolve.
--- @param methods table A table mapping method names to a list of class names.
--- @param auto_resolved table A table to keep track of already resolved classes.
---
function AutoResolve(class, methods, auto_resolved)
    -- Implementation details omitted for brevity
end
local function AutoResolve(class, methods, auto_resolved)
	local classdef = classdefs[class]
	for method, classes in pairs(methods) do
		local funcs = {}
		GatherAutoResolved(funcs, method, classes, auto_resolved)
		local op = AutoResolveMethods[method]
		classdef[method] = (CombinedMethodGenerator[op] or op)(funcs)
	end
end

-- Resolves the inheritance of values for class 'classname', generating the class table in 'resolved'
---
--- Resolves the complex inheritance of a class by recursively processing its parent classes.
---
--- This function is responsible for handling the inheritance of class members when a class has
--- multiple parent classes or when the inheritance hierarchy is more complex.
---
--- @param classname string The name of the class to resolve.
--- @param classdef table The class definition table.
--- @param force boolean If true, forces the resolution of complex inheritance even if the class has 0 or 1 parents.
--- @param auto_resolved table A table to keep track of already resolved classes.
--- @return table The resolved class table.
---
local function ResolveComplexInheritance(classname, classdef, force, auto_resolved)
	local parents = classdef.__parents
	if not force and #parents <= 1 and not classdef.__hierarchy_cache then
		-- simple inheritance
		return
	end

	local current = resolved[classname]
	if current then
		-- existing and already processed class
		if not current.__ancestors then -- circular inheritance
			assert(false, "Circular inheritance of class '" .. classname .. "'") 
		end
		return current
	else
		current = {}
		resolved[classname] = current
	end

	local ancestors = {}

	-- apply members from classdef
	for member, value in pairs(classdef) do
		if noninheritable[member] then
			current[member] = value
		else
			current[member] = classname
		end
	end

	-- inherit values from parents
	for i = 1, #parents do
		local parent_name = parents[i]
		if not ancestors[parent_name] then
			ancestors[parent_name] = true
			local parent_def = classdefs[parent_name]
			local parent = ResolveComplexInheritance(parent_name, parent_def, true, auto_resolved)
			local parent_ancestors = parent.__ancestors
	
			for member, value in pairs(parent) do
				if not noninheritable[member] then
					local src = current[member]
					if src ~= classname and src ~= value then -- skip members set in our classdef, detect only changes (src ~= value)
						if not src or parent_ancestors[src] then
							-- a member is overwritten when it's not set at all or if it's set by an ancestor of the currently processed parent class
							current[member] = value
						elseif AutoResolveMethods[member] then
							current[member] = unresolved_func
							ScheduleAutoResolve(classname, member, src, value, auto_resolved)
						else
							-- two values for a member are inherited from unrelated parents
							assert(resolved[src].__ancestors[value] or classdefs[src][member] == classdefs[value][member], 
								string.format("%s.%s ambiguously inherited from %s and %s", classname, member, value, src))
						end
					end
				end
			end
			
			-- fill ancestors
			for class, _ in pairs(parent_ancestors) do
				ancestors[class] = true
			end
		end
	end
	
	-- mark the resolved methods as our own for any next auto resolve in child classes
	for method in pairs(auto_resolved[classname]) do
		current[method] = classname
	end
	
	local shared_ancestors = ancestors_by_parents[parents]
	if not shared_ancestors then
		ancestors_by_parents[parents] = ancestors
		shared_ancestors = ancestors
	end
	current.__ancestors = shared_ancestors
		
	return current
end

-- copies the actual values from the classdefs after the inheritance is resolved
---
--- Resolves the values of a class definition by handling complex inheritance.
---
--- This function is responsible for resolving the values of a class definition, taking into account
--- complex inheritance scenarios where a class can inherit from multiple parent classes.
---
--- @param classname string The name of the class being resolved.
--- @param resolved_class table The resolved class definition, if this is a complex inheritance case.
--- @param classdef table The original class definition.
--- @return table The resolved class.
---
local function ResolveValues(classname, resolved_class, classdef)
	local class = classes[classname]
	if class.class then
		if not class.__index then 
			assert(false, "Circular inheritance of class '" .. classname .. "'") 
		end
		return class
	end
	class.class = classname
	local meta -- = Platform.developer and report_missing_members or nil
	
	if resolved_class then -- complex inheritance
		local cache_classname = resolved_class.__hierarchy_cache
		local cache_ancestors
		if cache_classname then
			local cache = resolved[cache_classname]
			cache_ancestors = cache.__ancestors
			if cache_classname ~= classname then
				meta = ResolveValues(cache_classname, cache, classdefs[cache_classname])
			end
		else
			cache_ancestors = {}
		end

		for member, source in pairs(resolved_class) do
			if not noncopyable[member] then
				if not noninheritable[member] then -- skip reserved names
					-- source is the name of the classdef with the actual value
					local value = classdefs[source][member]
					if 
						cache_classname == classname 
						or (source ~= cache_classname and not cache_ancestors[source]) 
					then
						class[member] = value
					end
				else
					-- source is the actual value
					class[member] = source
				end
			end
		end
	else -- simple inheritance - class with 0 or 1 parents
		local __parents = classdef.__parents
		local parent_name = __parents[1] or false
		local ancestors = ancestors_by_parents[__parents]
		if parent_name then
			local parent_def = classdefs[parent_name]
			local parent = ResolveValues(parent_name, resolved[parent_name], parent_def)
			if parent_def.__hierarchy_cache == nil then
				for member, value in pairs(parent) do
					if not noninheritable[member] then
						class[member] = value
					end
				end
				meta = getmetatable(parent)
			else
				meta = parent
			end
			if not ancestors then
				ancestors = { [parent_name] = true }
				for class, _ in pairs(parent.__ancestors) do
					ancestors[class] = true
				end
				ancestors_by_parents[__parents] = ancestors
			end
		else
			if not ancestors then
				ancestors = {}
				ancestors_by_parents[__parents] = ancestors
			end
		end
		class.__ancestors = ancestors
		for member, value in pairs(classdef) do
			if not noncopyable[member] then
				class[member] = value
			end
		end
	end
	class.__index = class.__index or class
	setmetatable(class, meta)
	return class
end

---
--- Stores the resolved flag inheritance information for each class.
--- This table maps class names to a table of flag definitions, where the keys are the flag names and the values are the class names that define those flags.
---
--- @class table
--- @field [string] table Flag definitions for the corresponding class.
local resolved_flags = {}
---
--- Stores the flag definitions for all classes.
---
--- @class table
--- @field [string] table Flag definitions for the corresponding class.
local flag_defs = {}
---
--- Represents an empty table of flags.
---
--- @class table
local empty_flags = {}
---
--- Modifies the specified flag in the given flags table, ensuring that the enum flag value is consistent between parent and child classes.
---
--- @param flags table The flags table to modify.
--- @param flag string The name of the flag to modify.
--- @param parent string The name of the parent class.
--- @param child string The name of the child class.
---
function enum_flag_modified(flags, flag, parent, child)
	if not flag_defs[child] or flag_defs[child][flag] == nil then 
		return 
	end
	-- check if parent's enum flag value has been changed in child
	if parent and flag:starts_with("ef") and (const[flag] & const.StaticClassEnumFlags) ~= 0 then
		local pval = flag_defs[parent][flag]
		local cval = flag_defs[child][flag]
		if pval ~= cval then
			printf("once", "[Warning] Modifying enum flag %s from %s child class of %s: map enum functions will not work properly with these classes", flag, child, parent)
		end
	end
end
local function enum_flag_modified(flags, flag, parent, child)
	if not flag_defs[child] or flag_defs[child][flag] == nil then 
		return 
	end
	-- check if parent's enum flag value has been changed in child
	if parent and flag:starts_with("ef") and (const[flag] & const.StaticClassEnumFlags) ~= 0 then
		local pval = flag_defs[parent][flag]
		local cval = flag_defs[child][flag]
		if pval ~= cval then
			printf("once", "[Warning] Modifying enum flag %s from %s child class of %s: map enum functions will not work properly with these classes", flag, child, parent)
		end
	end
end

---
--- Resolves the flag inheritance for the specified class.
---
--- @param name string The name of the class.
--- @param classdef table The class definition.
--- @param force boolean Whether to force the resolution of flag inheritance.
--- @return table The resolved flags for the class.
---
function ResolveFlagInheritance(name, classdef, force)
	-- Implementation details
end
local function ResolveFlagInheritance(name, classdef, force)
	local flags = resolved_flags[name]
	if flags then
		return flags
	end
	
	local flag_def = flag_defs[name]
	local parents = classdef.__parents
	if not force and not flag_def and #parents <= 1 then
		-- simple inheritance
		return
	end
	local parent = parents[1]
	flags = parent and ResolveFlagInheritance(parent, classdefs[parent], true) or empty_flags
	local org_flags = flags
	if flag_def then
		flags = copy(flags)
		
		for flag in pairs(flag_def) do
			if not const[flag] then
				assert(false, "Unknown flag " .. flag)
			else
				enum_flag_modified(flags, flag, flags[flag], name)
				flags[flag] = name
			end
		end
	end

	for i = 2, #parents do
		parent = parents[i]
		local parent_flags = ResolveFlagInheritance(parent, classdefs[parent], true)
		local parent_ancestors = classes[parent].__ancestors
		for flag, src2 in pairs(parent_flags) do
			local src = flags[flag]
			if src ~= name and src ~= src2 and (not src or flag_defs[src][flag] ~= flag_defs[src2][flag]) then -- the flag is not forced and the two sources/values are different
				if not src or parent_ancestors[src] then -- the flag is not set so far or it is set in an ancestor of the currently processed parent
					-- before modification copy the flags
					if flags == org_flags then
						flags = copy(flags)
					end
					enum_flag_modified(flags, flag, src2, name)
					flags[flag] = src2
				elseif not classes[src].__ancestors[src2] then
					-- the flag is inherited from two unrelated parents
					assert(false, string.format("%s flag %s ambiguously inherited from %s and %s", name, flag, src, src2))
				end
			end
		end
	end

	resolved_flags[name] = flags
	return flags
end

---
--- Generates a table of flag values for a given base class and prefix.
---
--- @param base_class string The base class to generate flag values for.
--- @param prefix string The prefix of the flags to include.
--- @param f? function An optional function to apply to each flag value.
--- @return table A table of flag values, with the class name as the key and the flag value as the value.
---
function FlagValuesTable(base_class, prefix, f)
	local const = const
	local flag_values = {}
	for name, class in pairs(classes) do
		local ancestors = class.__ancestors
		if name == base_class or ancestors and ancestors[base_class] then
			local flags = resolved_flags[name]
			if flags then
				-- complex inheritance
				local flags_value = 0
				for flag, src in pairs(flags) do
					if flag:starts_with(prefix) then
						if flag_defs[src][flag] then
							flags_value = flags_value | const[flag]
						else
							flags_value = flags_value & ~const[flag]
						end
					end
				end
				flag_values[name] = flags_value
			end
		end
	end
	return setmetatable({}, { __index = function(t, name)
		local flags_value = flag_values[name]
		local class_name = name
		while not flags_value do
			-- simple inheritance leaf class
			local class = classes[class_name]
			local parent = class.__parents[1]
			assert(#class.__parents <= 1)
			flags_value = not parent and 0 or flag_values[parent]
			class_name = parent
		end
		return f and f(name, flags_value) or flags_value
	end})
end

---
--- Generates a table of class objects that are descendants of the given ancestor class.
---
--- @param ancestor string The name of the ancestor class.
--- @param filter? function An optional function to filter the descendants. The function should take the class name and class object as arguments and return a boolean indicating whether to include the class.
--- @param ... Additional arguments to pass to the filter function.
--- @return table A table of class objects that are descendants of the given ancestor class, with the class name as the key.
---
function ClassDescendants(ancestor, filter, ...)
	PauseInfiniteLoopDetection("ClassDescendants")
	local descendants
	for name, class in pairs(classes) do
		local ancestors = class.__ancestors
		if ancestors and ancestors[ancestor] and (not filter or filter(name, class, ...)) then
			descendants = descendants or {}
			descendants[name] = class
		end
	end
	ResumeInfiniteLoopDetection("ClassDescendants")
	return descendants or empty_table
end

---
--- Generates a list of class names that are descendants of the given ancestor class.
---
--- @param ancestor string The name of the ancestor class.
--- @param filter? function An optional function to filter the descendants. The function should take the class name and class object as arguments and return a boolean indicating whether to include the class.
--- @param ... Additional arguments to pass to the filter function.
--- @return table A list of class names that are descendants of the given ancestor class.
---
function ClassDescendantsList(ancestor, filter, ...)
	PauseInfiniteLoopDetection("ClassDescendantsList")
	local descendants = {}
	for name, class in pairs(classes) do
		local ancestors = class.__ancestors
		if ancestors and ancestors[ancestor] and (not filter or filter(name, class, ...)) then
			descendants[#descendants + 1] = name
		end
	end
	table.sort(descendants)
	ResumeInfiniteLoopDetection("ClassDescendantsList")
	return descendants
end

---
--- Generates a list of class names that are descendants of the given ancestor class, including the ancestor class itself.
---
--- @param ancestor string The name of the ancestor class.
--- @param filter? function An optional function to filter the descendants. The function should take the class name and class object as arguments and return a boolean indicating whether to include the class.
--- @param ... Additional arguments to pass to the filter function.
--- @return table A list of class names that are descendants of the given ancestor class, including the ancestor class itself.
---
function ClassDescendantsListInclusive(ancestor, filter, ...)
	local descendants = ClassDescendantsList(ancestor, filter, ...)
	if not filter or filter(ancestor, classes[ancestor], ...) then
		insert(descendants, 1, ancestor)
	end
	return descendants
end

---
--- Generates a list of class names that are leaf descendants of the given ancestor class.
---
--- @param classname string The name of the ancestor class.
--- @param filter? function An optional function to filter the descendants. The function should take the class name and class object as arguments and return a boolean indicating whether to include the class.
--- @param ... Additional arguments to pass to the filter function.
--- @return table A list of class names that are leaf descendants of the given ancestor class.
---
function ClassLeafDescendantsList(classname, filter, ...)
	PauseInfiniteLoopDetection("ClassLeafDescendantsList")
	local non_leaves = {}
	for name, class in pairs(classes) do
		local parents = class.__parents
		if parents then
			for i = 1, #parents do
				non_leaves[parents[i]] = true
			end
		end
	end

	local leaf_descendants = {}
	if non_leaves[classname] then
		for name, class in pairs(classes) do
			if not non_leaves[name] and class.__ancestors and class.__ancestors[classname] and (not filter or filter(name, class, ...)) then
				leaf_descendants[#leaf_descendants + 1] = name
			end
		end
		table.sort(leaf_descendants)
	end
	ResumeInfiniteLoopDetection("ClassLeafDescendantsList")
	return leaf_descendants
end

---
--- Generates a combo box of values based on the class hierarchy of the given class and member.
---
--- @param class string The name of the class.
--- @param member string The name of the member to get values from.
--- @param additional? any An optional additional value to include in the combo box.
--- @return function A function that returns a table of values for the combo box.
---
function ClassValuesCombo(class, member, additional)
	return function() 
		local values = {}
		ClassDescendants(class, function(name, classdef, values) 
			values[classdef[member] or false] = true 
		end, values)
		values[false] = nil
		values[additional or false] = nil
		values = table.keys(values, true)
		if additional then
			insert(values, 1, additional)
		end
		return values
	end
end

---
--- Processes the class definitions in the given root class, calling the provided process function on each class definition.
---
--- @param root string The name of the root class to start processing from.
--- @param process function The function to call for each class definition, with the class definition and class name as arguments.
---
function ProcessClassdefChildren(root, process)
	local processed = {}
	local function process_classdef(classdef, class_name)
		if not classdef then return end
		local seen = processed[class_name]
		if seen ~= nil then
			return seen
		end
		for _, parent in ipairs(classdef.__parents or empty_table) do
			seen = process_classdef(classdefs[parent], parent) or seen
		end
		if seen then
			process(classdef, class_name)
		end
		processed[class_name] = seen or false
		return seen
	end
	process(classdefs[root], root)
	processed[root] = true
	for class_name, classdef in pairs(classdefs) do
		process_classdef(classdef, class_name)
	end
end

--- Checks if the given class definition has the specified member.
---
--- @param classdef table The class definition to check.
--- @param name string The name of the member to check for.
--- @return boolean True if the class definition has the specified member, false otherwise.
local function ClassdefHasMember(classdef, name)
	if not classdef then return end
	if classdef[name] ~= nil then
		return true
	end

	for _, parent in ipairs(classdef.__parents or empty_table) do
		if ClassdefHasMember(classdefs[parent], name) then
			return true
		end
	end
end
---
--- Checks if the given class definition has the specified member.
---
--- @param classdef table The class definition to check.
--- @param name string The name of the member to check for.
--- @return boolean True if the class definition has the specified member, false otherwise.
---
_G.ClassdefHasMember = ClassdefHasMember

---
--- Handles the automatic generation and post-processing of classes in the game.
---
--- This function is called during the game's startup process to build the class hierarchy and perform various optimizations and validations on the class definitions.
---
--- The main steps performed by this function are:
--- - Resolve inheritance and build the actual classes from the `classdefs` table into the `g_Classes` table.
--- - Perform property inheritance and other pre-processing on the class definitions.
--- - Clear and remove any classes that are no longer defined.
--- - Create new class instances and report any undefined parent classes.
--- - Find and share common parent tables to save memory.
--- - Resolve complex inheritance and generate auto-resolved methods.
--- - Resolve flag inheritance.
--- - Perform post-processing on the built classes.
--- - Trigger various messages to allow other systems to hook into the class building process.
--- - Clean up temporary data structures used during the class building process.
---
--- @
function OnMsg.Autorun()
	-- Hereafter optimization gremlins lurk. A few hints to what actually happens:
	--  * When classes are declared with 'DefineClass', the class definitions are stored in _G[classname] and classdefs[classname].
	--  * After that, this function resolves the inheritance and builds the actual classes from 'classdefs' into 'g_Classes'.
	--  * The actual classes are also stored in _G[classname], replacing the classdefs that were there before.
	--  * Beware - 'classes' is an alias for 'g_Classes' here.
	--  * As a performance optimization, class tables for which 'hierarchy_cache' is true are "flattened", containing directly the
	--    inherited values from all parents. For the rest of the classes, non-inherited values are got from the parent class via 
	--    '__index'. This isn't done for all classes to save memory (the majority of the classes inherit thousands of values).

	SuspendThreadDebugHook("Classes")
	assert(not ResolveThreadDebugHook())
	
	--@@@msg ClassesGenerate - use this message to mess with the classdefs (before classes are built)
	Msg("ClassesGenerate", classdefs)
	MsgClear("ClassesGenerate")

	--@@@msg ClassesPreprocess - use this message to do some processing to the already final classdefs (still before classes are built)
	-- property inheritance is implemented here
	Msg("ClassesPreprocess", classdefs)
	MsgClear("ClassesPreprocess")

	for name, class in pairs(classes) do
		if classdefs[name] then
			-- clear table contents or old class
			setmetatable(class, nil)
			clear(class)
		else -- remove classes that are not longer defined
			classes[name] = nil
		end
	end

	-- create classes, report and clear nonexistent parents
	local no_parents = {}
	for name, classdef in pairs(classdefs) do
		if not rawget(classes, name) then
			classes[name] = {}
		end
		local parents = classdef.__parents
		if parents == nil then
			classdef.__parents = no_parents
		elseif type(parents) == "table" then
			for i = #parents, 1, -1 do
				if not classdefs[parents[i]] then
					assert(false, string.format("class %s has an undefined parent %s", name, parents[i]))
					table.remove(parents, i)
				end
			end
		else
			assert(false, string.format("class %s has an invalid __parents member (should be a table)", name))
		end
		-- store flags in flag_defs
		flag_defs[name] = classdef.flags
		classdef.flags = nil
	end	

	-- find parent tables with the same content and replace them with a single copy
	local parents_by_hash = {}
	-- parents_by_hash[parent_hash] = parents_table
	-- parents_by_hash[class.__parents] = true
	for name, class in pairs(classdefs) do
		local parents = class.__parents
		if not parents_by_hash[parents] then -- some classes already share the same parents table
			local parent_hash = #parents == 1 and parents[1] or concat(parents, "|")
			local parents_table = parents_by_hash[parent_hash]
			if parents_table then
				-- replace parent table with the shared one
				class.__parents = parents_table
			else
				parents_by_hash[parent_hash] = parents
				parents_by_hash[parents] = name
			end
		end
	end
	parents_by_hash = nil

	-- resolve complex inheritance (after this step values contain the name of the classdef which holds the actual value)
	local auto_resolved = {}
	for name, classdef in pairs(classdefs) do
		ResolveComplexInheritance(name, classdef, false, auto_resolved)
	end
	
	-- generate methods marked for auto resolve
	for classname, methods in pairs(auto_resolved) do
		AutoResolve(classname, methods, auto_resolved)
	end
	
	-- replace the class names in values with the actual values
	for name, class in pairs(classdefs) do
		ResolveValues(name, resolved[name], class)
	end

	-- resolve flag inheritance
	for name, classdef in pairs(classdefs) do
		ResolveFlagInheritance(name, classdef)
	end

	for name, class in pairs(classdefs) do
		-- point class name global to the class
		rawset(_G, name, classes[name])
	end

	resolved = nil
	classdefs = nil
	ancestors_by_parents = nil
	ClassNonInheritableMembers = nil
	DefineClass = nil
	
	--@@@msg ClassesPostprocess - use this message to make modifications to the built classes (before they are declared final)
	Msg("ClassesPostprocess")
	MsgClear("ClassesPostprocess")

	--@@@msg ClassesBuilt - use this message to perform post-built actions on the final classes
	Msg("ClassesBuilt")
	MsgClear("ClassesBuilt")
	--@@@msg ClassesPostBuilt - use this message to perform actions after MapObject classes' info has been added to the C++ engine
	Msg("ClassesPostBuilt")
	MsgClear("ClassesPostBuilt")
	
	CombinedMethodGenerator = false -- not used after ClassesBuilt
	
	-- cleanup flags
	FlagValuesTable = nil
	resolved_flags = nil
	flag_defs = nil

	-- cleanup the temp memory used
	collectgarbage("collect")

	if developer then
		local meta =
		{ 
			__newindex = function (t, k, v)
				assert(false, "Attempt to add/change value " .. tostring(k) .. ". Tables specified as default class values should not be modified.", 1)
			end,
		}

		ClassDescendants("PropertyObject", function(classname, classdef, meta)
			for k, v in pairs(classdef) do
				if k ~= "__index" and type(v) == "table" and not getmetatable(v) then
					setmetatable(v, meta)
				end 
			end
		end, meta)
	end
	
	ResumeThreadDebugHook("Classes")
end

--[[
function OnMsg.ClassesBuilt()
	local c, t = 0, 0
	for _, class in pairs(classes) do
		if class.__parents and #class.__parents == 1 then
			c = c + 1
		end
		t = t + 1
	end
	print ("Classes with single parent " .. c .. "/" .. t)
end
--]]

--[[ Count classes, members and methods

function OnMsg.ClassesPostprocess()
function OnMsg.ClassesBuilt()
	local total = 0
	local total_funcs = 0
	local total_values = 0

	local descendants = {}
	local class_names = {}
	local class_values = {}

	for name, class in sorted_pairs(classes) do
		local values = 0
		local funcs = 0
		total = total + 1
		for _, value in pairs(class) do
			values = values + 1
			if type(value) == "function" then
				funcs = funcs + 1
			end
		end

		for name in pairs(class.__ancestors) do
			descendants[name] = (descendants[name] or 0) + 1
		end
		
		class_names[#class_names + 1] = name
		class_values[name] = values
		total_values = total_values + values
		total_funcs = total_funcs + funcs
	end

	table.sort(class_names, function (a, b) return (descendants[a] or 0) > (descendants[b] or 0) end)
	print("", "-------- Classes with most descendants (name - descendants / values)")
	for i = 1, 30 do
		local name = class_names[i]
		printf("%s - %d / %d", name, descendants[name] or 0, class_values[name] or 0)
	end

	table.sort(class_names, function (a, b) return (class_values[a] or 0) > (class_values[b] or 0) end)
	print("", "-------- Classes with most values (name - descendats / values)")
	for i = 1, 30 do
		local name = class_names[i]
		printf("%s - %d / %d", name, descendants[name] or 0, class_values[name] or 0)
	end

	table.sort(class_names, function (a, b) return (class_values[a] or 0) * (descendants[a] or 0) > (class_values[b] or 0) * (descendants[b] or 0) end)
	print("", "-------- Classes with most descendants * values (name - descendats / values)")
	for i = 1, 30 do
		local name = class_names[i]
		printf("%s - %d / %d", name, descendants[name] or 0, class_values[name] or 0)
	end

	print("------- Total classes: " .. total)
	print("------- Average name/value pairs: " .. total_values/total)
	print("------- Average methods: " .. total_funcs/total)
end
end
--]]

--- A table to track reported missing classes.
-- This table is used to avoid repeatedly reporting the same missing class.
reported_missing = {}
local reported_missing = {}

--- Indicates whether the current map is present on the map.
-- This variable is used to track whether the current map is present, which is
-- useful for reporting warnings about objects being placed on the map.
local present_on_map = false
--- A table to track objects that have already been warned about.
-- This table is used to avoid repeatedly warning about the same object.
local warned_once = {}
--- A table to track objects that have been delayed for warning.
-- This table is used to store objects that need to be warned about, but the
-- warning has been delayed until the map has finished loading.
local delayed_warns = {}
--- Indicates whether the current map is present on the map.
-- This variable is used to track whether the current map is present, which is
-- useful for reporting warnings about objects being placed on the map.
local valid_entity = false

--- Checks if an object's entity is present on the map and not already warned about.
-- If the object's entity is valid and not already warned about, prints a warning message.
-- @param obj The object to check.
local function ReportObjectEntity(obj)
	if present_on_map and not present_on_map[obj:GetEntity()] and valid_entity[obj:GetEntity()] and not warned_once[obj:GetEntity()] then
		printf("[Warning] trying to place an object of class %s:", obj.class)
		warned_once[obj:GetEntity()] = true
	end
end

--- Handles the reporting of object entities when a new map is loaded.
--
-- This function is called when a new map is loaded, and it iterates through the
-- `delayed_warns` table, which contains objects that need to be warned about
-- because they were placed on the map before it was fully loaded. For each
-- object in the `delayed_warns` table, the `ReportObjectEntity` function is
-- called to check if the object's entity is present on the map and not already
-- warned about. After all the objects have been processed, the `delayed_warns`
-- table is cleared.
--
-- This function is only called when the `developer` variable is true, which
-- indicates that the game is running in developer mode.

if developer then
	function OnMsg.NewMapLoaded()
		for k, v in pairs(delayed_warns) do
			if v then
				ReportObjectEntity(k)
			end
		end
		delayed_warns = {}
	end
end

---
--- Places an object of the specified class with the given Lua object, components, and other arguments.
---
--- If the specified class does not exist, a warning is printed if the game is running in developer mode and the class name has not been reported as missing before.
---
--- If the game is running in developer mode, not in the editor, and the current map is present, the function checks if the object has an entity. If not, a warning is printed if the class name has not been reported as missing before.
---
--- If the game is changing maps, the object is added to the `delayed_warns` table to be checked later. Otherwise, the `ReportObjectEntity` function is called to check if the object's entity is present on the map and not already warned about.
---
--- @param classname string|nil The name of the class to create
--- @param luaobj table|nil The Lua object to associate with the new object
--- @param components table|nil The components to add to the new object
--- @param ... any Additional arguments to pass to the class constructor
--- @return table|nil The new object, or nil if the class does not exist
---
function PlaceObject(classname, luaobj, components, ...)
	local class = classname and g_Classes[classname]
	
	if not class then
		if developer and not reported_missing[classname or false] then
			reported_missing[classname or false] = true
			printf('[Warning] %s is trying to place an object of missing class "%s"', GetCallLine(), tostring(classname))
		end
		return
	end
	
	local obj = class:new(luaobj, components, ...)
	
	if developer and not IsEditorActive() and present_on_map and not class:IsKindOf("Template") then
		if not obj:HasMember("entity") then
			if not warned_once[classname] then
				printf('[Warning] %s is trying to place an object of class "%s" without entity!', GetCallLine(), classname)
				warned_once[classname] = true
			end
			return
		end
		if IsChangingMap() then
			delayed_warns[obj] = true
		else
			ReportObjectEntity(obj)
		end
	end
	return obj
end

--- Destroys the specified object; the game object is destroyed and the Lua table is still intact, but invalidated for C API calls.
-- @cstyle void DoneObject(object obj).
-- @param obj object.
---
--- Destroys the specified object. The game object is destroyed and the Lua table is still intact, but invalidated for C API calls.
---
--- @param obj object The object to destroy.
---
function DoneObject(obj)
	if not obj then return end
	if ChangingMap then
		delayed_warns[obj] = nil
	end
	obj:delete()
end

--- Destroys the specified list of objects. The game objects are destroyed and the Lua tables are still intact, but invalidated for C API calls.
---
--- @param objs table The list of objects to destroy.
--- @param clear_objs boolean If true, the list of objects will be cleared after destruction.
---
function DoneObjects(objs, clear_objs)
	if not objs then return end
	for k, obj in ipairs(objs) do
		DoneObject(obj)
	end
	if clear_objs then
		clear(objs)
	end
end

--- Destroys the specified object's field.
---
--- @param obj table The object containing the field to destroy.
--- @param field_name string The name of the field to destroy.
---
function DoneField(obj, field_name)
	if not obj then return end
	DoneObject(obj[field_name])
	obj[field_name] = nil
end

--- Returns a function that generates a list of class descendants, optionally filtered and including the base class.
---
--- @param class string The base class to get descendants for.
--- @param inclusive boolean If true, the base class will be included in the list.
--- @param filter function An optional filter function that takes a class name and class definition and returns true if the class should be included.
---
--- @return function A function that takes an object, property metadata, and a validation function name, and returns a list of class descendants.
function ClassDescendantsCombo(class, inclusive, filter)
	return function(obj, prop_meta, validate_fn)
		if validate_fn == "validate_fn" then
			-- function for preset validation, checks whether the property value is from "items"
			return "validate_fn", function(value, obj, prop_meta)
				return value == "" or IsKindOf(g_Classes[value], class) and (inclusive or value ~= class) and (not filter or filter(value, g_Classes[value]))
			end
		end
		
		local list = ClassDescendantsList(class, filter) or {}
		if inclusive then
			list[#list + 1] = class
		end
		table.sort(list)
		table.insert(list, 1, "")
		return list
	end
end

--- Returns a function that generates a list of class leaf descendants, optionally including the base class.
---
--- @param class string The base class to get leaf descendants for.
--- @param inclusive boolean If true, the base class will be included in the list.
---
--- @return function A function that takes an object and returns a list of class leaf descendants.
function ClassLeafDescendantsCombo(class, inclusive)
	return function(obj)
		local list = ClassLeafDescendantsList(class) or {}
		list[#list + 1] = ""
		if inclusive then
			list[#list + 1] = class
		end
		table.sort(list)
		return list
	end
end

--- Returns the value of the specified property on the given object.
---
--- @param obj table The object to get the property value from.
--- @param prop string The name of the property to get.
---
--- @return any The value of the specified property.
function GetClassValue(obj, prop)
	return  (getmetatable(obj))[prop]
end

--- Recursively enumerates the function names defined in a table.
---
--- @param def table The table to enumerate function names from.
--- @param funcs table (optional) A table to accumulate the function names in.
---
--- @return table A table containing the names of all functions defined in the input table and its metatable.
function EnumFuncNames(def, funcs)
	funcs = funcs or {}
	if not def then
		return funcs
	end
	for key, val in pairs(def) do
		if type(val) == "function" and type(key) == "string" then
			funcs[key] = true
		end
	end
	return EnumFuncNames(getmetatable(def), funcs)
end
local function EnumFuncNames(def, funcs)
	funcs = funcs or {}
	if not def then
		return funcs
	end
	for key, val in pairs(def) do
		if type(val) == "function" and type(key) == "string" then
			funcs[key] = true
		end
	end
	return EnumFuncNames(getmetatable(def), funcs)
end

---
--- Recursively enumerates the inheritance hierarchy of the specified class definition and returns a mapping of function names to the class where they are defined.
---
--- @param def table The class definition to enumerate.
--- @param funcs string|table (optional) A string or table of function names to enumerate. If not provided, all function names will be enumerated.
---
--- @return table A mapping of function names to the class where they are defined.
function GetFuncInheritance(def, funcs)
	local funcs = type(funcs) == "string" and { funcs } or funcs or table.keys(EnumFuncNames(def), true)
	local ancestors = {}
	for class_i in pairs(def.__ancestors) do
		ancestors[class_i] = g_Classes[class_i]
	end
	local class = def.class
	local map = {}
	for _, name in ipairs(funcs) do
		local func = def[name]
		local class_found, def_found
		for class_i, def_i in pairs(ancestors) do
			if rawget(def_i, name) == func then
				if not def_found or def_found.__ancestors[class_i] then
					class_found = class_i
					def_found = def_i
				end
			end
		end
		map[name] = class_found or class
	end
	return map
end


----- RecursiveCallMethods

---
--- Preprocesses the class definitions by merging and generating recursive call methods.
---
--- This function is called when the ClassesPreprocess message is received. It processes the class definitions by:
--- - Merging the __parents lists of classes
--- - Generating and caching combined methods for recursive call methods
--- - Storing the generated methods in the class definitions
---
--- @param classdefs table The class definitions to preprocess.
---
function OnMsg.ClassesPreprocess(classdefs)
	local function merge(list1, list2)
		if not list1 or not list2 or list1 == list2 then return list1 or list2 end
		local list = list1.cached and icopy(list1) or list1
		for _, item in ipairs(list2) do
			if not find(list1, item) then
				list[#list + 1] = item
			end
		end
		return list
	end

	local method_name, generated_methods, method_generator, lists_cache, generated_cache

	local function class_to_method(class_name)
		return classdefs[class_name][method_name]
	end

	local function process(class)
		local list = lists_cache[class]
		if list ~= nil then return list end
		local classdef = classdefs[class] or empty_table
		for _, parent in ipairs(classdef.__parents) do
			list = merge(list, process(parent))
		end
		if classdef[method_name] then
			list = list and list.cached and icopy(list) or list or {}
			list[#list + 1] = class
		end
		if list and not list.cached then -- generate method
			local str = concat(list, "|")
			local method = generated_cache[str]
			if not method then
				method = method_generator(map(list, class_to_method))
				generated_cache[str] = method
			end
			generated_methods[class] = method
			list.cached = true
		end
		lists_cache[class] = list or false
		return list
	end

	for entry, func in pairs(RecursiveCallMethods) do
		method_name = entry
		method_generator = CombinedMethodGenerator[func] or func
		lists_cache = { [false] = false }
		generated_cache = {}
		generated_methods = {}
		for class, classdef in pairs(classdefs) do
			process(class, classdef)
		end
		for class, method in pairs(generated_methods) do
			classdefs[class][method_name] = method
		end
	end
end


----- AppendClass

--- `AppendClassMembers` is a table that defines the behavior for appending class members when using the `AppendClass` function.
--- The table contains the following keys:
--- - `__parents`: a function that appends to the `__parents` field of a class definition.
--- - `properties`: a function that appends properties to a class definition, handling duplicate property IDs.
--- - `flags`: a function that overwrites the `flags` field of a class definition.
AppendClassMembers = {}
---
--- Appends the `__parents` field of a class definition.
---
--- @param t table The class definition table.
--- @param parents table A table of parent class names.
--- @return table The updated class definition table with the `__parents` field appended.
---
AppendClassMembers.__parents = table.iappend
---
--- Appends properties to a class definition, handling duplicate property IDs.
---
--- @param t table The class definition table.
--- @param props table A table of property metadata.
--- @return table The updated class definition table with the properties appended.
---
AppendClassMembers.properties = function(t, props)
	for _, prop_meta in ipairs(props) do
		local idx = table.find(t, "id", prop_meta.id)
		if idx then table.remove(t, idx) end
	end
	return table.iappend(t, props)
end
---
--- Overwrites the `flags` field of a class definition.
---
--- @param t table The class definition table.
--- @param flags table A table of flags to overwrite the `flags` field.
--- @return table The updated class definition table with the `flags` field overwritten.
---
AppendClassMembers.flags = table.overwrite

---
--- Appends additional members to an existing class definition.
---
--- @param class_name string The name of the class to append members to.
--- @param additions table A table of key-value pairs representing the new members to append.
---
--- The `AppendClass` function allows you to add new members to an existing class definition. It checks if the class is already defined, and if so, it appends the new members using the `AppendClassMembers` table.
---
--- The `AppendClassMembers` table defines the behavior for appending different types of class members:
--- - `__parents`: a function that appends to the `__parents` field of a class definition.
--- - `properties`: a function that appends properties to a class definition, handling duplicate property IDs.
--- - `flags`: a function that overwrites the `flags` field of a class definition.
---
--- @return nil
AppendClass = SetupFuncCallTable(function (class_name, additions)
	assert(classdefs, "Classes are already resolved") 
	local class_def = classdefs and classdefs[class_name]
	if not class_def then
		if classdefs then
			assert(class_def, string.format("AppendClass: class %s not defined", class_name), 2)
		end
		return
	end
	local AppendClassMembers = AppendClassMembers
	for member, new_value in pairs(additions) do
		local append = AppendClassMembers[member]
		if append then
			class_def[member] = class_def[member] and append(class_def[member], new_value) or new_value
		else
			class_def[member] = new_value
		end
	end
end)
