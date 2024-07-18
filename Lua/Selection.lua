---- Multiselect wrapper extensions

--- Resolves the value of a field in an array of objects.
---
--- This function iterates through an array of objects and checks if the specified field
--- exists on the object or its class. If the field is found, its value is stored in the
--- `self` table.
---
--- @param array table The array of objects to search.
--- @param field string The name of the field to resolve.
function ResolveField(array, field)
	--check children classes
	for i,subobj in ipairs(array) do
		--quicky and dirty "has member" check
		local value = rawget(subobj, field) or rawget(g_Classes[subobj.class], field)
		if value then
			self[field] = value
			break
		end
	end
end

--- Broadcasts a method or function call to an array of objects.
---
--- This function iterates through an array of objects and calls the specified method or function on each object.
---
--- @param array table The array of objects to call the method or function on.
--- @param method string|function The method name or function to call on each object.
--- @param ... any Any additional arguments to pass to the method or function.
function Broadcast(array, method, ...)
	if type(method) == "string" then
		for i,subobj in ipairs(array) do
			subobj[method](subobj, ...)
		end
	else
		for i,subobj in ipairs(array) do
			method(subobj, ...)
		end
	end
end

--- Checks if all objects in the given array pass the specified method call.
---
--- This function iterates through an array of objects and calls the specified method on each object.
--- If any object fails the method call, the function returns false. Otherwise, it returns true.
---
--- @param array table The array of objects to check.
--- @param method string|function The method name or function to call on each object.
--- @param ... any Any additional arguments to pass to the method or function.
--- @return boolean True if all objects pass the method call, false otherwise.
function CheckAll(array, method, ...)
	for i,subobj in ipairs(array) do
		if not subobj[method](subobj, ...) then
			return false
		end
	end
	return true
end

--- Checks if all objects in the given array have the specified property.
---
--- This function iterates through an array of objects and checks if each object has the specified property.
--- If any object does not have the property, the function returns false. Otherwise, it returns true.
---
--- @param array table The array of objects to check.
--- @param property string The name of the property to check for.
--- @return boolean True if all objects have the specified property, false otherwise.
function CheckAllProperty(array, property)
	for i,subobj in ipairs(array) do
		if not subobj[property] then
			return false
		end
	end
	return true
end

--- Checks if any object in the given array passes the specified method call.
---
--- This function iterates through an array of objects and calls the specified method on each object.
--- If any object passes the method call, the function returns the result of the method call. Otherwise, it returns false.
---
--- @param array table The array of objects to check.
--- @param method string|function The method name or function to call on each object.
--- @param ... any Any additional arguments to pass to the method or function.
--- @return any|boolean The result of the first successful method call, or false if no object passes the method call.
function CheckAny(array, method, ...)
	for i,subobj in ipairs(array) do
		local result, r2, r3, r4, r5 = subobj[method](subobj, ...)
		if result then return result, r2, r3, r4, r5 end
	end
	return false
end

--- Checks if any object in the given array has the specified property and returns its value.
---
--- This function iterates through an array of objects and checks if each object has the specified property.
--- If any object has the property, the function returns the value of that property. Otherwise, it returns false.
---
--- @param array table The array of objects to check.
--- @param property string The name of the property to check for.
--- @return any|boolean The value of the first object that has the specified property, or false if no object has the property.
function CheckAnyProperty(array, property)
	for i,subobj in ipairs(array) do
		local value = subobj[property]
		if value then
			return value
		end
	end
	return false
end

--- Combines the results of calling a method on each object in an array, and returns a unique set of the results.
---
--- This function iterates through an array of objects and calls the specified method on each object.
--- It collects the results of the method calls and returns a unique set of the results.
---
--- If a `comparison_key` is provided, the function will only add a result to the set if it does not already have an entry with the same value for the specified key.
--- If no `comparison_key` is provided, the function will simply add each unique result to the set.
---
--- @param array table The array of objects to call the method on.
--- @param method string|function The method name or function to call on each object.
--- @param comparison_key string The name of the key to use for comparing results (optional).
--- @param ... any Any additional arguments to pass to the method or function.
--- @return table The unique set of results from calling the method on each object.
function Union(array, method, comparison_key, ...)
	local values = { }
	for i,subobj in ipairs(array) do
		local result = subobj[method](subobj, ...)
		if result then
			for i,v in ipairs(result) do
				if comparison_key then
					if not find(values, comparison_key, v[comparison_key]) then
						table.insert(values, v)
					end
				else
					--optimized when there is no comparison key
					values[v] = true
				end
			end
		end
	end
	
	return comparison_key and values or table.keys(values)
end

--CombatAction Helpers

--- Chooses the closest object from an array that matches a given condition.
---
--- This function iterates through an array of objects and finds the closest object to a given target that matches a specified condition.
---
--- @param array table The array of objects to search.
--- @param target table The target object to compare distances to.
--- @param condition function An optional function that takes the object, target, and any additional arguments, and returns a boolean indicating if the object matches the condition.
--- @param ... any Any additional arguments to pass to the condition function.
--- @return table|nil The closest object that matches the condition, or nil if no object matches.
function ChooseClosestObject(array, target, condition, ...)
	local closest
	for _, obj in ipairs(array) do
		if not closest or IsCloser(target, obj, closest) then
			if not condition or condition(obj, target, ...) then
				closest = obj
			end
		end
	end
	return closest
end

--Combat Unit Methods

--- Sets a command on an array of objects.
---
--- This function iterates through an array of objects and sets a specified command on each object, if the object has the command member.
---
--- @param array table The array of objects to set the command on.
--- @param command string The name of the command to set.
--- @param ... any Any additional arguments to pass to the command.
function SetCommand(array, command, ...)
	--not all objs will have the command so this is a quick optimization for using the heavy `HasMember`
	local has_member_cache = { }
	
	for i,subobj in ipairs(array) do
		local cache = has_member_cache[subobj.class]
		if cache == nil and subobj:HasMember(command) or cache then
			subobj:SetCommand(command, ...)
			has_member_cache[subobj.class] = true
		end
	end
end

--- Checks if any object in the given array can be controlled.
---
--- This function iterates through an array of objects and checks if any of them can be controlled.
---
--- @param units table The array of objects to check.
--- @param ... any Any additional arguments to pass to the CanBeControlled method.
--- @return boolean True if any object in the array can be controlled, false otherwise.
function CanBeControlled(units, ...)
	return CheckAny(units, "CanBeControlled", ...)
end

--- Gets the maximum AP cost for a stance change between the units in the given array.
---
--- This function iterates through an array of objects and finds the maximum AP cost for a stance change between any of the objects.
---
--- @param units table The array of objects to check.
--- @param ... any Any additional arguments to pass to the GetStanceToStanceAP method.
--- @return number The maximum AP cost for a stance change, or -1 if no objects have the GetStanceToStanceAP method.
function GetStanceToStanceAP(units, ...)
	local result = -1
	for i,subobj in ipairs(units) do
		local value = subobj:GetStanceToStanceAP(...)
		if value and value > result then
			result = value
		end
	end
	return result
end

--- Checks if the given array of units are NPCs.
---
--- This function iterates through an array of units and checks if each unit is an NPC.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the IsNPC method.
--- @return boolean True if all units in the array are NPCs, false otherwise.
function IsNPC(units, ...)
	return CheckAll(units, "IsNPC", ...)
end

--- Gets the active weapons for the given units.
---
--- This function iterates through an array of units and returns a list of all active weapons for those units.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetActiveWeapons method.
--- @return table A list of all active weapons for the given units.
function GetActiveWeapons(units, ...)
	return Union(units, "GetActiveWeapons", ...)
end

---
--- Gets the item in the specified slot for the given units.
---
--- This function iterates through an array of units and returns the item in the specified slot for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetItemInSlot method.
--- @return table A list of the items in the specified slot for the given units.
function GetItemInSlot(units, ...)
	return CheckAny(units, "GetItemInSlot", ...)
end

--- Checks if the given array of units have any available action points (AP).
---
--- This function iterates through an array of units and checks if each unit has any available AP.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the UIHasAP method.
--- @return boolean True if any units in the array have available AP, false otherwise.
function UIHasAP(units, ...)
	return CheckAny(units, "UIHasAP", ...)
end

--- Checks if the given array of units have any available action points (AP).
---
--- This function iterates through an array of units and checks if each unit has any available AP.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the HasAP method.
--- @return boolean True if any units in the array have available AP, false otherwise.
function HasAP(units, ...)
	return CheckAny(units, "HasAP", ...)
end

--- Gets the visible enemies for the given units.
---
--- This function iterates through an array of units and returns a list of all visible enemies for those units.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetVisibleEnemies method.
--- @return table A list of all visible enemies for the given units.
function GetVisibleEnemies(units, ...)
	return Union(units, "GetVisibleEnemies", false, ...)
end

--- Gets the maximum UI-scaled action points (AP) for the given units.
---
--- This function iterates through an array of units and returns the maximum UI-scaled AP for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetUIScaledAPMax method.
--- @return table A list of the maximum UI-scaled AP for the given units.
function GetUIScaledAPMax(units, ...)
	return CheckAny(units, "GetUIScaledAPMax", ...)
end

--- Gets the UI-scaled action points (AP) for the given units.
---
--- This function iterates through an array of units and returns the UI-scaled AP for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetUIScaledAP method.
--- @return table A list of the UI-scaled AP for the given units.
function GetUIScaledAP(units, ...)
	return CheckAny(units, "GetUIScaledAP", ...)
end

--- Gets the available ammos for the given units.
---
--- This function iterates through an array of units and returns the available ammos for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetAvailableAmmos method.
--- @return table A list of the available ammos for the given units.
function GetAvailableAmmos(units, ...)
	return CheckAny(units, "GetAvailableAmmos", ...)
end

--- Gets the attack AP cost for the given units.
---
--- This function iterates through an array of units and returns the attack AP cost for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetAttackAPCost method.
--- @return table A list of the attack AP cost for the given units.
function GetAttackAPCost(units, ...)
	return CheckAny(units, "GetAttackAPCost", ...)
end

--- Gets a list of reachable objects for the given units.
---
--- This function iterates through an array of units and returns a list of all reachable objects for each unit.
---
--- @param units table The array of units to check.
--- @param ... any Any additional arguments to pass to the GetReachableObjects method.
--- @return table A list of all reachable objects for the given units.
function GetReachableObjects(units, ...)
	return Union(units, "GetReachableObjects", false, ...)
end

---- Helpers

--- Executes a function on a set of targets based on the specified behavior.
---
--- @param behavior string The behavior to use when executing the function. Can be "nearest", "all", or "first".
--- @param array table The array of targets to execute the function on.
--- @param func function The function to execute on the targets.
--- @param target any The target object to use for the "nearest" behavior.
--- @param ... any Additional arguments to pass to the function.
function MultiTargetExecute(behavior, array, func, target, ...)
	if #array == 0 then
		return
	end
	
	if behavior == "hidden" and #array == 1 then
		behavior = "first"
	end

	if behavior == "nearest" then
		local closest = ChooseClosestObject(array, target)
		func(closest, ...)
	elseif behavior == "all" then
		Broadcast(array, func, ...)
	elseif behavior == "first" then
		local obj = array[1]
		func(obj, ...)
	end
end

local table_find = table.find

function OnMsg.ObjModified(obj)
	if not table_find(Selection, obj) then return end
	ObjModified(Selection)
end

--- Gets the object under the cursor, propagating the selection if necessary.
---
--- This function retrieves the object under the cursor, first checking for a solid object, then a transparent object, and finally falling back to selecting an object from the terrain cursor or the terrain cursor object selection.
---
--- @return table|nil The selected object, or nil if no object is under the cursor.
function SelectionMouseObj()
	-- assert(IsAsyncCode()) -- game time threads can use SelectionMouseObj in Zulu, we do not persist them -> this will not cause a desync
	local solid, transparent = GetPreciseCursorObj()
	return SelectionPropagate(transparent or solid or SelectFromTerrainPoint(GetTerrainCursor()) or GetTerrainCursorObjSel())
end

GameVar("gv_Selection", false)

function OnMsg.GatherSessionData()
	gv_Selection = {}
	for i, unit in ipairs(Selection) do
		gv_Selection[i] = unit:GetHandle()
	end
end

function OnMsg.LoadSessionData()
	if not gv_Selection or #gv_Selection == 0 then
		EnsureCurrentSquad()
		return
	end
	local list = {}
	for _, handle in ipairs(gv_Selection) do
		local obj = HandleToObject[handle]
		if IsKindOf(obj, "Unit") then
			list[#list + 1] = obj
		end
	end
	SelectionSet(list)
end