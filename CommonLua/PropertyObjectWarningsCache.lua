if Platform.ged then return end

---- A diagnostic message cache to improve Ged performance
--
-- 1. The cache is only maintained for objects in the active Ged window.
-- 2. It is kept up-to-date by periodic updates.
--
-- Motivation: Diagnostic messages of objects often depend on external data. The usual way to update
-- the messages is with ObjModified calls whenever that external data changes. However, we can't
-- expect people to put this effort merely for a warning message. Thus we need an automated system.

---
--- Clears the diagnostic message cache and the list of objects that have cached messages.
---
--- This function is used to reset the cache when the application is first loaded, or when the
--- cache needs to be cleared for some other reason.
---
--- @function ClearDiagnosticMessageCache
--- @return nil
function ClearDiagnosticMessageCache()
	DiagnosticMessageCache = {}
	DiagnosticMessageObjs = {} -- topologically sorted (child objects first)
end

if FirstLoad then
	ClearDiagnosticMessageCache()
end

local GetDiagnosticMessageNoCache = GetDiagnosticMessage

---
--- Gets the diagnostic message for the given object, caching the result.
---
--- If the message is not cached, it is retrieved using `GetDiagnosticMessageNoCache` and stored in the cache.
---
--- @param obj GedEditedObject The object to get the diagnostic message for.
--- @param verbose boolean (optional) Whether to include verbose information in the message.
--- @param indent number (optional) The indentation level for the message.
--- @return string|false The diagnostic message for the object, or `false` if no message is available.
---
function GetDiagnosticMessage(obj, verbose, indent)
	local cached = DiagnosticMessageCache[obj]
	if cached ~= nil then return cached end
	
	local message = GetDiagnosticMessageNoCache(obj, verbose, indent) or false
	DiagnosticMessageObjs[#DiagnosticMessageObjs + 1] = obj
	DiagnosticMessageCache[obj] = message
	return message
end

---
--- Updates the diagnostic message for the given object, caching the result.
---
--- If the message is not cached, it is retrieved using `GetDiagnosticMessageNoCache` and stored in the cache.
---
--- @param obj GedEditedObject The object to update the diagnostic message for.
--- @return boolean Whether the message was updated (i.e. the cache was invalidated).
---
function UpdateDiagnosticMessage(obj)
	local no_cache = not DiagnosticMessageCache[obj]
	local old_msg = DiagnosticMessageCache[obj] or false
	local new_msg = GetDiagnosticMessageNoCache(obj) or false
	DiagnosticMessageCache[obj] = new_msg
	return no_cache or new_msg ~= old_msg and ValueToLuaCode(new_msg) ~= ValueToLuaCode(old_msg)
end

----- Keeping the cache up-to-date

if FirstLoad then
	DiagnosticMessageActiveGed = false
	DiagnosticMessageActivateGedThread = false
	DiagnosticMessageSuspended = false
end

local function for_each_subobject(t, class, fn)
	if IsKindOf(t, class) then
		fn(t)
	end
	for _, obj in ipairs(t and t.GedTreeChildren and t:GedTreeChildren() or t) do
		if type(obj) == "table" then
			for_each_subobject(obj, class, fn)
		end
	end
end

local function init_cache_for_object(ged, root, initial)
	local old_cache = DiagnosticMessageCache
	ClearDiagnosticMessageCache()
	
	local total, count = 0, 0
	for_each_subobject(root, "GedEditedObject", function() total = total + 1 end)
	
	local time = GetPreciseTicks()
	for_each_subobject(root, "GedEditedObject", function(obj)
		local old_msg = old_cache[obj] or false
		local new_msg = GetDiagnosticMessage(obj) or false
		if new_msg ~= old_msg and ValueToLuaCode(new_msg) ~= ValueToLuaCode(old_msg) then
			GedObjectModified(obj, "warning")
		end
		
		count = count + 1
		if GetPreciseTicks() > time + 150 then
			time = GetPreciseTicks()
			if initial then
				ged:SetProgressStatus("Updating warnings/errors...", count, total)
			end
			Sleep(50)
		end
	end)
	
	ged:SetProgressStatus(false)
end

local function ged_update_warnings(ged)
	-- update Ged with the warnings cache via GedGetCachedDiagnosticMessages (to show ! marks)
	GedUpdateObjectValue(ged, nil, "root|warnings_cache")
	-- update the status bar that contains warning/error information
	for name, obj in pairs(ged.bound_objects) do
		if name:find("|GedPresetStatusText", 1, true) or name:find("|GedModStatusText", 1, true) or name:find("|warning_error_count", 1, true) then
			GedUpdateObjectValue(ged, nil, name)
		end
	end
end

---
--- Initializes the warnings cache for a Ged editor.
---
--- @param ged GedEditor The Ged editor to initialize the warnings cache for.
--- @param initial boolean Whether this is the initial initialization of the warnings cache.
---
function InitializeWarningsForGedEditor(ged, initial)
	if IsValidThread(DiagnosticMessageActivateGedThread) and DiagnosticMessageActivateGedThread ~= CurrentThread then
		DeleteThread(DiagnosticMessageActivateGedThread)
	end
	
	DiagnosticMessageActiveGed = ged
	Msg("WakeupQuickDiagnosticThread")
	DiagnosticMessageActivateGedThread = CreateRealTimeThread(function()
		ged:SetProgressStatus(false)
		init_cache_for_object(ged, ged:ResolveObj(ged.context.WarningsUpdateRoot), initial)
		ged_update_warnings(ged)
		Msg("WakeupFullDiagnosticThread")
	end)
end

---
--- Handles the activation of a Ged editor, initializing the warnings cache if the editor has a valid WarningsUpdateRoot, or clearing the cache if not.
---
--- @param ged GedEditor The Ged editor that was activated.
--- @param initial boolean Whether this is the initial activation of the Ged editor.
---
function OnMsg.GedActivated(ged, initial)
	if ged.context.WarningsUpdateRoot and ged:ResolveObj(ged.context.WarningsUpdateRoot) then
		InitializeWarningsForGedEditor(ged, initial)
	else
		ClearDiagnosticMessageCache()
		DiagnosticMessageActiveGed = false
	end
end

---
--- Clears the diagnostic message cache and resets the active Ged editor.
---
function OnMsg.SystemActivate()
	ClearDiagnosticMessageCache()
	DiagnosticMessageActiveGed = false
end

---
--- Returns a table of cached diagnostic messages for all objects.
---
--- @return table A table mapping object IDs to their cached diagnostic messages.
---
function GedGetCachedDiagnosticMessages()
	local ret = {}
	for obj, msg in pairs(DiagnosticMessageCache) do
		if msg then
			ret[tostring(obj)] = msg
		end
	end
	return ret
end

---
--- Updates the diagnostic messages for the given objects.
---
--- This function first updates the diagnostic messages for any child objects of the given objects, to ensure that the warnings are correct. It then updates the diagnostic messages for the given objects, and marks the objects as modified in the Ged editor if the warning status has changed.
---
--- If the function takes longer than 50 milliseconds to complete, it will sleep for 50 milliseconds to avoid blocking the main thread for too long.
---
--- @param objs table A table of objects to update the diagnostic messages for.
---
function UpdateDiagnosticMessages(objs)
	-- Update children objects first, which are last on the list, so when an object is updated,
	-- we "know" its warning is correct (unless a child's warning status changed in the meantime)
	local time, updated = GetPreciseTicks(), false
	for i = 1, #objs do
		local obj = objs[i]
		if GedIsValidObject(obj) and UpdateDiagnosticMessage(obj) then
			GedObjectModified(obj, "warning")
			updated = true
		end
		if GetPreciseTicks() - time > 50 then
			Sleep(50)
			if not DiagnosticMessageActiveGed then return end
			time = GetPreciseTicks()
		end
	end
	if updated then
		ged_update_warnings(DiagnosticMessageActiveGed)
	end
end

if FirstLoad then
	CreateRealTimeThread(function()
		while true do
			Sleep(77)
			while DiagnosticMessageActiveGed do
				if not DiagnosticMessageSuspended then
					sprocall(UpdateDiagnosticMessages, DiagnosticMessageObjs)
				end
				Sleep(50)
			end
			WaitMsg("WakeupFullDiagnosticThread")
		end
	end)
	-- Update Ged's bound objects (the ones currently in panels) with a greater frequency for better responsiveness
	CreateRealTimeThread(function()
		while true do
			Sleep(33)
			while DiagnosticMessageActiveGed do
				if not DiagnosticMessageSuspended then
					local objs = {}
					for name, obj in pairs(DiagnosticMessageActiveGed.bound_objects) do
						if name:ends_with("|warning") then
							if IsKindOf(obj, "PropertyObject") then
								obj:ForEachSubObject(function(subobj) objs[subobj] = true end)
							end
							objs[obj] = true
						end
					end
					sprocall(UpdateDiagnosticMessages, table.keys(objs))
				end
				Sleep(50)
			end
			WaitMsg("WakeupQuickDiagnosticThread")
		end
	end)
end
