DefineClass.GedSocket = {
	__parents = { "MessageSocket" },
	msg_size_max = 256*1024*1024,
	bound_objects = false, -- mapping name -> object
	app = false,
}

--- Initializes the `bound_objects` table for the `GedSocket` class.
-- The `bound_objects` table is used to store a mapping of object names to their corresponding objects.
-- This function is called during the initialization of a `GedSocket` instance.
function GedSocket:Init()
	self.bound_objects = {}
end

--- Closes the application associated with the `GedSocket` instance.
-- This function is called when the `GedSocket` instance is marked as "Done".
-- It ensures that the associated application is properly closed, and if the application is not in-game, the entire application is quit.
function GedSocket:Done()
	self:CloseApp()
end

--- Called when the `GedSocket` instance is disconnected.
-- This function is responsible for closing the application associated with the `GedSocket` instance.
-- @param reason (string) The reason for the disconnection.
function GedSocket:OnDisconnect(reason)
	self:CloseApp()
end

--- Closes the application associated with the `GedSocket` instance.
-- This function is called when the `GedSocket` instance is marked as "Done".
-- It ensures that the associated application is properly closed, and if the application is not in-game, the entire application is quit.
function GedSocket:CloseApp()
	if self.app and self.app.window_state == "open" then
		self.app:Close()
		if not self.app.in_game then
			quit()
		end
	end
end

--- Deletes the `GedSocket` instance.
-- This function is called when the `GedSocket` instance needs to be removed or destroyed.
-- It ensures that the `GedSocket` instance is properly deleted and removed from the system.
function GedSocket:rfnGedQuit()
	self:delete()
end

--- Returns the object bound to the specified name.
-- @param name (string) The name of the bound object to retrieve.
-- @return The object bound to the specified name, or `nil` if no object is bound.
function GedSocket:Obj(name)
	return self.bound_objects[name]
end

--- Binds an object to the specified name.
-- This function is used to associate an object with a specific name in the `GedSocket` instance.
-- @param name (string) The name to bind the object to.
-- @param obj_address (any) The address or reference of the object to be bound.
-- @param func_name (string) The name of the function to be called on the bound object.
-- @param ... (any) Additional arguments to be passed to the function.
function GedSocket:BindObj(name, obj_address, func_name, ...)
	self:Send("rfnBindObj", name, obj_address, func_name, ...)
end

--- Binds a filter object to the specified target and name.
-- This function is used to associate a filter object with a specific name in the `GedSocket` instance.
-- @param target (string) The target to bind the filter object to.
-- @param name (string) The name to bind the filter object to.
-- @param class_or_instance (any) The class or instance of the filter object to be bound.
function GedSocket:BindFilterObj(target, name, class_or_instance)
	self:Send("rfnBindFilterObj", target, name, class_or_instance)
end

--- Unbinds an object from the specified name.
-- This function is used to remove the association between an object and a specific name in the `GedSocket` instance.
-- @param name (string) The name to unbind the object from.
-- @param to_prefix (string) (optional) If provided, this will also unbind any objects whose names start with the specified prefix.
function GedSocket:UnbindObj(name, to_prefix)
	self:Send("rfnUnbindObj", name, to_prefix)
	self.bound_objects[name] = nil
	if to_prefix then
		local pref = name .. to_prefix
		for obj_name in pairs(self.bound_objects) do
			if string.starts_with(obj_name, pref) then
				self.bound_objects[obj_name] = nil
			end
		end
	end
end

--- Sets the value of a bound object in the `GedSocket` instance.
-- If the value is Lua code, it will be deserialized and set as the bound object.
-- After setting the value, the corresponding context will be updated.
-- @param name (string) The name of the bound object to set the value for.
-- @param value (any) The value to set for the bound object. If `is_code` is true, this should be Lua code that can be deserialized.
-- @param is_code (boolean) Indicates whether the `value` parameter is Lua code that needs to be deserialized.
function GedSocket:rfnObjValue(name, value, is_code)
	if is_code then
		local err, obj = LuaCodeToTuple(value)
		if err then
			printf("Error deserializing %s", name)
			return
		end
		value = obj
	end
	self.bound_objects[name] = value
	
	local obj_name, view = name:match("(.+)|(.+)")
	PauseInfiniteLoopDetection("GedUpdateContext")
	XContextUpdate(obj_name or name, view)
	ResumeInfiniteLoopDetection("GedUpdateContext")
end

--- Opens a GedApp dialog with the specified template or class, context, and optional ID.
-- This function is used to create and initialize a new GedApp instance.
-- @param template_or_class (string) The template or class name to use for the new GedApp instance.
-- @param context (table) The context table to pass to the new GedApp instance.
-- @param id (string) (optional) The ID to use for the new GedApp instance.
-- @return (string) Returns "xtemplate" if the app could not be created.
function GedSocket:rfnOpenApp(template_or_class, context, id)
	context = context or {}
	context.connection = self
	local app = OpenDialog(id or template_or_class, context.in_game and GetDevUIViewport(), context)
	assert(IsKindOf(app, "GedApp"))
	if not app then return "xtemplate" end
	if app.AppId == "" then
		app:SetAppId(template_or_class)
		app:ApplySavedSettings()
	end
	if app:GetTitle() == "" then
		app:SetTitle(template_or_class)
	end
	XShortcutsTarget:SetDarkMode(GetDarkModeSetting())
	
	LogOnlyPrint("Initializing ged app: " .. tostring(template_or_class))
end

--- Closes the GedSocket instance.
-- This function is used to quit the application.
function GedSocket:rfnClose()
	quit()
end

--- Calls a function on the GedSocket's app object.
---
--- @param func string The name of the function to call on the app object.
--- @param ... any Arguments to pass to the function.
--- @return string "app" if the app object is not available, "func" if the function does not exist on the app object, otherwise the result of calling the function.
function GedSocket:rfnApp(func, ...)
	local app = self.app
	if not app or app.window_state == "destroying" then return "app" end
	if not app:HasMember(func) then return "func" end
	return app[func](app, ...)
end

if Platform.ged then
	function OnMsg.ApplicationQuit()
		for _, win in ipairs(terminal.desktop) do
			if win:IsKindOf("GedApp") then
				win:Close()
			end
		end
	end
end
