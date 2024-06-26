----- GedFilter

--- Defines a GedFilter class that is used to filter objects in the GED (Graphical Editor) system.
---
--- The GedFilter class has the following properties:
--- - `properties`: A table of properties associated with the filter.
--- - `ged`: A reference to the GED object.
--- - `target_name`: The name of the target object for the filter.
--- - `supress_filter_reset`: A flag indicating whether the filter reset should be suppressed.
--- - `FilterName`: The name of the filter.
---
--- The GedFilter class provides the following methods:
--- - `ResetTarget(socket)`: Resets the target object for the filter.
--- - `OnEditorSetProperty(prop_id, old_value, ged)`: Handles the event when a property is set in the editor.
--- - `TryReset(ged)`: Attempts to reset the filter.
--- - `FilterObject(object)`: Filters the given object.
--- - `PrepareForFiltering()`: Prepares the filter for filtering.
--- - `DoneFiltering(displayed_count, filtered)`: Handles the completion of the filtering process.
DefineClass.GedFilter = {
	__parents = { "InitDone" },
	properties = {},
	
	ged = false,
	target_name = false,
	supress_filter_reset = false,
	FilterName = Untranslated("Filter"),
}

--- Resets the target object for the filter.
---
--- This function is called when a property is set in the editor. It resolves the target object for the filter based on the `target_name` property, and then modifies the object to trigger any necessary updates.
---
--- @param socket table The socket object used to resolve the target object.
function GedFilter:ResetTarget(socket)
	if self.target_name and socket then
		local obj = socket:ResolveObj(self.target_name)
		self.supress_filter_reset = true
		ObjModified(obj)
		self.supress_filter_reset = false
	end
end

--- Handles the event when a property is set in the editor.
---
--- This function is called when a property is set in the editor. It resets the target object for the filter based on the `target_name` property.
---
--- @param prop_id number The ID of the property that was set.
--- @param old_value any The previous value of the property.
--- @param ged table A reference to the GED object.
function GedFilter:OnEditorSetProperty(prop_id, old_value, ged)
	self:ResetTarget(ged)
end

---
--- Attempts to reset the filter.
---
--- This function is called to reset the filter. It sets all properties of the filter to their default values, and then forces an update of the object and marks it as modified.
---
--- @param ged table A reference to the GED object.
--- @return boolean True if the reset was successful, false otherwise.
function GedFilter:TryReset(ged)
	if self.supress_filter_reset then return false end
	for _, prop in ipairs(self:GetProperties()) do
		self:SetProperty(prop.id, self:GetDefaultPropertyValue(prop.id, prop))
	end
	GedForceUpdateObject(self)
	ObjModified(self)
	return true
end

--- Filters an object to determine if it should be included in the filtered list.
---
--- This function is called to determine if a given object should be included in the filtered list. By default, it always returns true, indicating that the object should be included.
---
--- @param object table The object to be filtered.
--- @return boolean True if the object should be included in the filtered list, false otherwise.
function GedFilter:FilterObject(object)
	return true
end

--- Prepares the filter for filtering.
---
--- This function is called to prepare the filter for filtering. It does not perform any actual filtering, but rather sets up any necessary state or properties for the filtering process.
---
--- @param self GedFilter The filter object.
function GedFilter:PrepareForFiltering()
end

---
--- Called when the filtering process is complete.
---
--- This function is called after the filtering process has completed. It is used to perform any necessary cleanup or post-processing after the filtered list has been generated.
---
--- @param displayed_count number The number of objects that were displayed after filtering.
--- @param filtered table The list of filtered objects (only passed for GedListPanel filters).
function GedFilter:DoneFiltering(displayed_count, filtered)
end
function GedFilter:DoneFiltering(displayed_count, filtered --[[ passed for GedListPanel filters only ]])
end

---
--- Initializes global variables related to the GED (Game Editor) system.
---
--- This code is executed when the file is first loaded, and sets up various global variables used by the GED system.
---
--- @field GedConnections table A table that stores weak references to GED connections.
--- @field GedObjects table A global mapping of objects to their associated names and sockets.
--- @field GedTablePropsCache table A cache of properties for bound objects, to prevent issues when editing nested or list properties.
--- @field g_gedListener boolean A reference to the GED listener object, or false if it has not been created.
--- @field GedTreePanelCollapsedNodes table A table that stores the collapsed state of nodes in the GED tree panel.
if FirstLoad then
	GedConnections = setmetatable({}, weak_values_meta)
	GedObjects = {} -- global mapping object -> { name1, socket1, name2, socket1, name3, socket2, ... }
	GedTablePropsCache = {} -- caches properties of the bound objects; this prevents issues when editing nested_obj/list props that work via Get/Set functions
	g_gedListener = false

	GedTreePanelCollapsedNodes = setmetatable({}, weak_keys_meta)
end

---
--- Sets the GED port to the configured value, or 44000 if not configured.
---
--- This global variable is used to configure the port that the GED (Game Editor) system will listen on. If the `config.GedPort` value is not set, it defaults to 44000.
---
--- @field config.GedPort number The configured GED port, or 44000 if not configured.
config.GedPort = config.GedPort or 44000

---
--- Starts listening for the GED (Game Editor) on the configured port, or a range of ports if searching for an available port.
---
--- This function is responsible for setting up the GED listener and finding an available port to listen on. It first stops any existing GED listener, then creates a new `BaseSocket` object with the `GedGameSocket` type. It then iterates through a range of ports, starting from the configured `GedPort` value (or 44000 if not configured), and attempts to listen on each port. If a port is successfully bound, the function returns `true` and sets the `port` field of the `g_gedListener` object. If no available port is found, the function returns `false`.
---
--- @param search_for_port boolean If `true`, the function will search a range of 100 ports starting from the configured `GedPort` value. If `false`, it will only attempt to listen on the configured `GedPort` value.
--- @return boolean `true` if a port was successfully bound, `false` otherwise.
function ListenForGed(search_for_port)
	StopListenForGed()
	g_gedListener = BaseSocket:new{
		socket_type = "GedGameSocket",
	}
	local port_start = config.GedPort or 44000
	local port_end = port_start + (search_for_port and 100 or 1)
	for port = port_start, port_end do
		local err = g_gedListener:Listen("*", port)
		if not err then
			g_gedListener.port = port
			return true
		elseif err == "address in use" then
			print("ListenForGed: Address in use. Trying with another port...")
		else
			return false
		end
	end
	return false
end

---
--- Stops listening for the GED (Game Editor) on the configured port.
---
--- This function is responsible for stopping the GED listener. It first checks if the `g_gedListener` object exists, and if so, it deletes the object and sets `g_gedListener` to `false`.
---
--- @
function StopListenForGed()
	if g_gedListener then
		g_gedListener:delete()
		g_gedListener = false
	end
end

if config.GedLanguageEnglish then
	if FirstLoad or ReloadForDlc then
		TranslationTableEnglish = false -- for the Mod Editor on PC
	end

	function GedTranslate(T, context_obj, check)
		local old_table = TranslationTable
		TranslationTable = TranslationTableEnglish
		local ret = _InternalTranslate(T, context_obj, check)
		TranslationTable = old_table
		return ret
	end
else
	GedTranslate = _InternalTranslate
end

---
--- Opens a new GED (Game Editor) application instance.
---
--- This function is responsible for starting a new GED application instance. It first checks if the `g_gedListener` object exists, and if not, it calls the `ListenForGed()` function to start listening for GED connections.
---
--- If the `config.GedLanguageEnglish` flag is set, the function checks if the `TranslationTableEnglish` table has been loaded. If not, it loads the English translation table.
---
--- The function then retrieves the port number that the GED listener is listening on, and creates a new GED socket connection. If the `in_game` flag is set, it creates a `GedSocket` object and connects to the GED listener on the local host. If the `in_game` flag is not set, it launches a new GED application process with the specified ID and connection parameters.
---
--- The function then waits for the GED connection to be established, and returns the connected GED socket object.
---
--- @param id (string) The unique identifier for the GED application instance.
--- @param in_game (boolean) Whether the GED application is being opened from within the game.
--- @return (GedSocket) The connected GED socket object, or `nil` if the connection failed.
---
function OpenGed(id, in_game)
	if not g_gedListener then
		ListenForGed(true)
	end
	if config.GedLanguageEnglish and not TranslationTableEnglish then
		if GetLanguage() == "English" then
			TranslationTableEnglish = TranslationTable
		else
			TranslationTableEnglish = {}
			LoadTranslationTablesFolder("EnglishLanguage/CurrentLanguage/", "English", TranslationTableEnglish)
		end
	end
	local port = g_gedListener.port
	if not port then
		print("Could not start the ged listener")
		return
	end
	id = id or AsyncRand()
	if in_game then
		assert(GedSocket, "Ged source files not loaded")
		local socket = GedSocket:new() -- if GedSocket is missing the Ged sources are not loaded
		local err = socket:WaitConnect(10000, "localhost", port)
		if err then
			socket:delete()
		else
			socket:Call("rfnGedId", id)
		end
	else
		local exec_path = GetExecDirectory() .. GetExecName()
		local path = string.format('"%s" %s -ged=%s -address=127.0.0.1:%d %s', exec_path, GetIgnoreDebugErrors() and "-no_interactive_asserts" or "", tostring(id), port, config.RunUnpacked and "-unpacked" or "")
		local start_func
		if Platform.linux or Platform.osx then
			start_func = function(path)
				local exit_code, _, std_error  = os.execute(path .. " &")
				return exit_code, std_error
			end
		else
			start_func = function(path)
				local cmd = string.format('cmd /c start "GED" %s', path)
				local err, exit_code, output, err_messsage = AsyncExec(cmd, nil, true)
				if err then return false, err end
				return exit_code, err_messsage
			end
		end
		local exit_code, std_error  = start_func(path)
		if exit_code ~= 0 then
			print("Could not launch Ged from:", path, "\nExec error:", std_error)
			return
		end
	end
	local timeout = 60000 
	while timeout do
		if GedConnections[id] then
			return GedConnections[id]
		end
		timeout = WaitMsg("GedConnection", timeout)
	end
end

local ged_print = CreatePrint{
	"ged",
	format = "printf",
	output = DebugPrint,
}

---
--- Opens a new Ged application window with the specified template, root object, and context.
---
--- @param template string The template name for the Ged application to open.
--- @param root table The root object to bind the Ged application to.
--- @param context table An optional table of context information for the Ged application.
--- @param id string An optional unique identifier for the Ged application.
--- @param in_game boolean An optional flag indicating whether the Ged application is being opened in-game.
--- @return table The Ged application instance.
function OpenGedApp(template, root, context, id, in_game)
	assert(root ~= nil)
	if not IsRealTimeThread() or not CanYield() then
		CreateRealTimeThread(OpenGedApp, template, root, context, id, in_game)
		return
	end
	if in_game == nil then
		in_game = (g_Classes[template] or XTemplates[template] and XTemplates[template].save_in ~= "Ged" and XTemplates[template].save_in ~= "GameGed") and true
	end
	context = context or {}
	if context.dark_mode == nil then
		context.dark_mode = GetDarkModeSetting()
	end
	context.color_palette = CurrentColorPalette and CurrentColorPalette:ColorsPlainObj() or false
	context.color_picker_scale = rawget(_G, "g_GedApp") and g_GedApp.color_picker_scale or EditorSettings:GetColorPickerScale()
	context.ui_scale = rawget(_G, "g_GedApp") and g_GedApp.ui_scale or EditorSettings:GetGedUIScale()
	context.max_fps = rawget(_G, "g_GedApp") and g_GedApp.max_fps or hr.MaxFps
	context.in_game = in_game
	context.game_real_time = RealTime()
	context.mantis_project_id = const.MantisProjectID
	context.mantis_copy_url_btn = const.MantisCopyUrlButton
	context.bug_report_tags = GetBugReportTagsForGed()
	local ged = OpenGed(id, in_game)
	if not ged then return end
	ged:BindObj("root", root)
	ged.app_template = template
	ged.context = context
	ged.in_game = in_game
	local err = ged:Call("rfnOpenApp", template, context, id)
	if err then
		printf("OpenGedApp('%s') error: %s", tostring(template), tostring(err))
	end
	Msg("GedOpened", ged.ged_id)

	local preset_class = context and context.PresetClass
	ged_print("Opened %s with class %s, id %s", tostring(template), tostring(preset_class), tostring(ged.ged_id))
	return ged
end

---
--- Closes a Ged application window.
---
--- @param gedsocket table The Ged application instance to close.
--- @param wait boolean If true, the function will wait for the Ged application to finish closing before returning.
---
function CloseGedApp(gedsocket, wait)
	if GedConnections[gedsocket.ged_id] then
		gedsocket:Close()
		if wait then
			local id
			repeat
				local _, id = WaitMsg("GedClosing")
			until id == gedsocket.ged_id
		end
	end
end

---
--- Finds a Ged application instance by its template and optional preset class.
---
--- @param template string The template of the Ged application to find.
--- @param preset_class string The preset class of the Ged application to find (optional).
--- @return table|nil The Ged application instance, or nil if not found.
---
function FindGedApp(template, preset_class)
	for id, conn in pairs(GedConnections) do
		if conn.app_template == template and 
			(not preset_class or conn.context.PresetClass == preset_class) then
			return conn
		end
	end
end

---
--- Finds all Ged application instances that match the given template and optional preset class.
---
--- @param template string The template of the Ged applications to find.
--- @param preset_class string The preset class of the Ged applications to find (optional).
--- @return table A table of all matching Ged application instances.
---
function FindAllGedApps(template, preset_class)
	local connections = setmetatable({}, weak_values_meta)
	for id, conn in pairs(GedConnections) do
		if conn.app_template == template and 
			(not preset_class or conn.context.PresetClass == preset_class) then
			table.insert(connections, conn)
		end
	end
	
	return connections
end

---
--- Opens a Ged application singleton instance.
---
--- @param template string The template of the Ged application to open.
--- @param root table The root object to bind the Ged application to.
--- @param context table The context to activate the Ged application with.
--- @param id string The unique identifier of the Ged application.
--- @param in_game boolean Whether the Ged application is being opened in-game.
--- @return table The Ged application instance.
---
function OpenGedAppSingleton(template, root, context, id, in_game)
	local app = FindGedApp(template)
	if app then
		app:Call("rfnApp", "Activate", context)
		app:BindObj("root", root)
		if app.last_app_state and app.last_app_state.root then
			local sel = app.last_app_state.root.selection
			if sel and type(sel[1]) == "table" then
				app:SetSelection("root", {1}, {1}) -- tree panel
			else
				app:SetSelection("root", 1, {1}) -- list panel
			end
		end
		app:ResetUndoQueue()
		app.last_app_state = false -- the last app state won't make sense for a new root object
		return app
	end
	return OpenGedApp(template, root, context, id, in_game)
end

function OnMsg.BugReportStart(print_func)
	local list = {}
	for key, ged in sorted_pairs(GedConnections) do
		local preset_class = ged.context and ged.context.PresetClass
		list[#list+1] = "\t" .. tostring(ged.app_template) .. " with preset class " .. tostring(preset_class) .. " and id " ..  tostring(ged.ged_id)
	end
	if #list == 0 then
		return
	end
	print_func("Opened GedApps:\n" .. table.concat(list, "\n") .. "\n")
end


----- GedGameSocket

---
--- Represents a GedGameSocket, which is a specialized MessageSocket used for managing the lifecycle and state of a Ged application.
---
--- @class GedGameSocket
--- @field msg_size_max number The maximum size of messages that can be sent through this socket.
--- @field call_timeout boolean Whether to use a timeout for calls made through this socket.
--- @field ged_id string The unique identifier of the Ged application associated with this socket.
--- @field app_template string The template of the Ged application associated with this socket.
--- @field context table The context used to activate the Ged application associated with this socket.
--- @field root_names table An array of the names of root objects, which are always updated when any object is edited.
--- @field bound_objects table A mapping of object names to the bound objects.
--- @field bound_objects_svalue table A mapping of object names to the cached string values of the bound objects.
--- @field bound_objects_func table A mapping of object names to the process functions for the bound objects.
--- @field bound_objects_path table A mapping of object names to the lists of BindObj calls from the root to the bound objects.
--- @field bound_objects_filter table A mapping of object names to the GedFilter objects for the bound objects.
--- @field prop_bindings table The property bindings for the Ged application.
--- @field last_app_state table The last state of the Ged application.
--- @field selected_object boolean The currently selected object in the Ged application.
--- @field tree_panel_collapsed_nodes boolean The collapsed nodes in the tree panel of the Ged application.
--- @field undo_position number The index of the next undo entry that will be executed with Ctrl-Z.
--- @field undo_queue table The undo queue for the Ged application.
--- @field redo_thread boolean The redo thread for the Ged application.
---
DefineClass.GedGameSocket = {
	__parents = { "MessageSocket" },
	msg_size_max = 256*1024*1024,
	call_timeout = false,
	ged_id = false,
	app_template = false,
	context = false,
	
	root_names = false, -- array of the names of root objects; these are always updated when any object is edited
	bound_objects = false, -- mapping name -> object
	bound_objects_svalue = false, -- mapping name -> cached value (string)
	bound_objects_func = false, -- mapping name -> process_function
	bound_objects_path = false, -- mapping name -> list of BindObj calls from root to this object
	bound_objects_filter = false, -- mapping name -> GedFilter object
	prop_bindings = false,
	
	last_app_state = false,
	selected_object = false,
	tree_panel_collapsed_nodes = false,
	
	-- undo/redo support
	undo_position = 0, -- idx of the next undo entry that will be executed with Ctrl-Z
	undo_queue = false,
	redo_thread = false,
}

---
--- Initializes a GedGameSocket instance.
---
--- This function sets up the initial state of the GedGameSocket, including:
--- - Initializing the `root_names` table with the "root" name
--- - Initializing the `bound_objects`, `bound_objects_svalue`, `bound_objects_func`, `bound_objects_path`, and `bound_objects_filter` tables to empty
--- - Initializing the `prop_bindings` table to empty
--- - Resetting the undo queue
---
--- @function GedGameSocket:Init
--- @return nil
function GedGameSocket:Init()
	self.root_names = { "root" }
	self.bound_objects = {}
	self.bound_objects_svalue = {}
	self.bound_objects_func = {}
	self.bound_objects_path = {}
	self.bound_objects_filter = {}
	self.prop_bindings = {}
	self:ResetUndoQueue()
end

---
--- Closes the GedGameSocket instance.
---
--- This function performs the following actions:
--- - Sends a "rfnGedQuit" message to notify the server that the GedGameSocket is closing
--- - Logs a message indicating the GedGameSocket is being closed, including the app template and GedGameSocket ID
--- - Notifies the selected object that the editor selection has changed, with a false value
--- - Sends a "GedOnEditorSelect" message with the selected object and a false value
--- - Unbinds all bound objects from the GedGameSocket
--- - Sends a "GedClosed" message to notify listeners that the GedGameSocket has been closed
--- - Sets the UI status to "ged_multi_select"
---
--- @function GedGameSocket:Done
--- @return nil
function GedGameSocket:Done()
	Msg("GedClosing", self.ged_id)
	ged_print("Closed %s with id %s", tostring(self.app_template), tostring(self.ged_id))
	GedNotify(self.selected_object, "OnEditorSelect", false, self)
	Msg("GedOnEditorSelect", self.selected_object, false, self)
	for name in pairs(self.bound_objects) do
		self:UnbindObj(name, "leave_values")
	end
	Msg("GedClosed", self)
	GedSetUiStatus("ged_multi_select")
end

---
--- Closes the GedGameSocket instance.
---
--- This function sends a "rfnGedQuit" message to notify the server that the GedGameSocket is closing.
---
--- @function GedGameSocket:Close
--- @return nil
function GedGameSocket:Close()
	self:Send("rfnGedQuit")
end

---
--- Resets the undo queue for the GedGameSocket instance.
---
--- This function performs the following actions:
--- - Sets the `undo_position` property to 0, indicating the start of the undo queue.
--- - Initializes the `undo_queue` property to an empty table, clearing any previous undo history.
---
--- @function GedGameSocket:ResetUndoQueue
--- @return nil
function GedGameSocket:ResetUndoQueue()
	self.undo_position = 0
	self.undo_queue = {}
end

---
--- Assigns a unique identifier to the GedGameSocket instance.
---
--- This function performs the following actions:
--- - Asserts that the provided `id` is not already associated with another GedGameSocket instance
--- - Stores the `id` in the `ged_id` property of the GedGameSocket instance
--- - Adds the GedGameSocket instance to the `GedConnections` table, using the `id` as the key
--- - Sends a "GedConnection" message with the `id` value
---
--- @function GedGameSocket:rfnGedId
--- @param id string The unique identifier to assign to the GedGameSocket instance
--- @return nil
function GedGameSocket:rfnGedId(id)
	assert(not GedConnections[id], "Duplicate Ged id " .. tostring(id))
	GedConnections[id] = self
	self.ged_id = id
	Msg("GedConnection", id)
end

---
--- Handles the disconnection of the GedGameSocket instance.
---
--- This function performs the following actions:
--- - Checks if the GedGameSocket instance is registered in the `GedConnections` table
--- - If so, it calls the `delete()` method to clean up the instance
--- - It then removes the GedGameSocket instance from the `GedConnections` table
---
--- @function GedGameSocket:OnDisconnect
--- @param reason string The reason for the disconnection
--- @return nil
function GedGameSocket:OnDisconnect(reason)
	if GedConnections[self.ged_id] then
		self:delete()
		GedConnections[self.ged_id] = nil
	end
end

local prop_prefix = "prop:"
---
--- Recursively traverses a tree-like data structure to retrieve a node at the specified path.
---
--- @param root table The root node of the tree-like data structure.
--- @param key1 string|number The first key or index to traverse.
--- @param key2 string|number The second key or index to traverse (optional).
--- @param ... string|number Additional keys or indices to traverse (optional).
--- @return table The node at the specified path, or the original `root` if the path is empty.
--- @return string The name of the property, if the last key in the path is a property name.
---
function TreeNodeByPath(root, key1, key2, ...)
	if key1 == nil or not root then
		return root
	end
	
	local key_type = type(key1)
	assert(key_type == "number" or key_type == "string")
	if key_type == "number" then
		local f = root.GedTreeChildren
		root = f and f(root) or root
	end
	
	local prop_name = type(key1) == "string" and key1:starts_with(prop_prefix) and key1:sub(#prop_prefix + 1)
	if prop_name then
		if GedTablePropsCache[root] and GedTablePropsCache[root][prop_name] ~= nil then
			root = GedTablePropsCache[root][prop_name]
		else
			root = root:GetProperty(prop_name)
		end
		if key2 == nil then
			return root, prop_name
		end
	else
		root = rawget(root, key1)
	end
	return TreeNodeByPath(root, key2, ...)
end

---
--- Resolves an object by name from the bound objects of the GedGameSocket.
---
--- @param name string The name of the object to resolve.
--- @param ... any Additional arguments to pass to the TreeNodeByPath function.
--- @return table The resolved object, or nil if not found.
---
function GedGameSocket:ResolveObj(name, ...)
	if name then
		local idx = string.find(name, "|")
		if idx then
			name = string.sub(name, 1, idx - 1)
		end
	end
	return TreeNodeByPath(self.bound_objects[name or false], ...)
end

---
--- Resolves the name of an object that is bound to the GedGameSocket.
---
--- @param obj table The object to resolve the name for.
--- @return string The name of the bound object, or nil if not found.
---
function GedGameSocket:ResolveName(obj)
	if not obj then return end
	for name, bobj in pairs(self.bound_objects) do
		if obj == bobj then
			return name
		end
	end
end

---
--- Finds the filter associated with the specified name.
---
--- @param name string The name of the object to find the filter for.
--- @return table|nil The filter associated with the name, or nil if not found.
---
function GedGameSocket:FindFilter(name)
	local filter = self.bound_objects_filter[name]
	if filter then return filter end
	
	local obj_name, view = name:match("(.+)|(.+)")
	if obj_name and view then
		return self.bound_objects_filter[obj_name]
	end
	
	for filter_name, filter in pairs(self.bound_objects_filter) do
		local obj_name, view = filter_name:match("(.+)|(.+)")
		if obj_name and view and obj_name == name then
			return filter
		end
	end
end

---
--- Resets the filter associated with the specified object name.
---
--- If a filter is found for the given object name, this function will attempt to reset the filter.
--- If the reset is successful, the filter's target will also be reset.
---
--- @param obj_name string The name of the object to reset the filter for.
---
function GedGameSocket:ResetFilter(obj_name)
	local filter = self:FindFilter(obj_name)
	if filter and filter:TryReset(self) then
		filter:ResetTarget(self)
	end
end

--- Binds an object to the GedGameSocket instance with the given name.
---
--- If an object is already bound to the given name, it will be unbound first.
--- The provided function will be used to generate a string representation of the bound object.
--- If the generated string representation differs from the previous one, a message will be sent to notify the change.
---
--- @param name string The name to bind the object to.
--- @param obj table The object to bind.
--- @param func function|nil The function to generate a string representation of the object. If not provided, a default function will be used.
--- @param dont_send boolean|nil If true, the change in object value will not be sent.
function GedGameSocket:BindObj(name, obj, func, dont_send)
	if not obj then return end
	if not func and rawequal(obj, self.bound_objects[name]) then return end
	self:UnbindObj(name)
	
	func = func or function(obj, filter) return tostring(obj) end
	local sockets = GedObjects[obj] or {}
	GedObjects[obj] = sockets
	sockets[#sockets + 1] = name
	sockets[#sockets + 1] = self
	self.bound_objects[name] = obj
	self.bound_objects_func[name] = func
	if not dont_send then
		local values = func(obj, self:FindFilter(name))
		local vpstr = ValueToLuaCode(values, nil, pstr("", 1024))
		if vpstr ~= self.bound_objects_svalue[name] then
			self.bound_objects_svalue[name] = vpstr
			self:Send("rfnObjValue", name, vpstr:str(), true)
		end
	end
	Msg("GedBindObj", obj)
end

---
--- Unbinds an object from the GedGameSocket instance with the given name.
---
--- If an object is bound to the given name, it will be unbound. The object's reference will be removed from the GedObjects table, and any cached property bindings will be cleared.
--- If `leave_values` is true, the bound object's value will not be cleared from the GedGameSocket instance.
---
--- @param name string The name of the object to unbind.
--- @param leave_values boolean|nil If true, the bound object's value will not be cleared.
---
function GedGameSocket:UnbindObj(name, leave_values)
	local obj = self.bound_objects[name]
	if obj then
		local sockets = GedObjects[obj]
		if sockets then
			for i = 1, #sockets - 1, 2 do
				if sockets[i] == name and sockets[i + 1] == self then
					table.remove(sockets, i)
					table.remove(sockets, i)
				end
			end
			if #sockets == 0 then
				GedObjects[obj] = nil
			end
		end
		self.prop_bindings[obj] = nil
		GedTablePropsCache[obj] = nil
	end
	if leave_values then return end
	self.bound_objects[name] = nil
	self.bound_objects_svalue[name] = nil
	self.bound_objects_func[name] = nil
	self.bound_objects_path[name] = nil
end

---
--- Unbinds all objects from the GedGameSocket instance that have a name starting with the given prefix.
---
--- If `leave_values` is true, the bound objects' values will not be cleared from the GedGameSocket instance.
---
--- @param name_prefix string The prefix of the object names to unbind.
--- @param leave_values boolean|nil If true, the bound objects' values will not be cleared.
---
function GedGameSocket:UnbindObjs(name_prefix, leave_values)
	for name in pairs(self.bound_objects) do
		if string.starts_with(name, name_prefix) then
			self:UnbindObj(name, leave_values)
		end
	end
end

---
--- Gets the parent object of the specified object that matches the given type.
---
--- If the `name` parameter is a table, it is assumed to be the object itself, and the function will search for the object's bind name in the `bound_objects` table.
---
--- The function will traverse the bind path of the object to find the last parent that matches the specified type. If no parent of the specified type is found, `nil` is returned.
---
--- @param name string|table The name of the object or the object itself.
--- @param type_name string The type name of the parent object to find.
--- @return table|nil The last parent object that matches the specified type, or `nil` if no such parent is found.
---
function GedGameSocket:GetParentOfKind(name, type_name)
	-- find object's bind name if we are searching by object
	if type(name) == "table" then
		for objname, obj in pairs(self.bound_objects) do
			if name == obj then
				name = objname
				break
			end
		end
		if type(name) == "table" then return end
	end

	local bind_path = self.bound_objects_path[name:match("(.+)|.+") or name]
	if not bind_path then return end

	-- return the last parent that matches
	local indexes_flattened = {}
	for i = 2, #bind_path do
		local subpath = bind_path[i]
		if type(subpath) == "table" then
			for u = 1, #subpath do
				-- a table here represents multiple selection handled by GedMultiSelectAdapter; we can't find bind parents below that level
				if type(subpath[u]) == "table" then
					goto completed
				end
				table.insert(indexes_flattened, subpath[u])
			end
		else
			table.insert(indexes_flattened, subpath)
		end
	end
::completed::

	local obj, last_matching = self.bound_objects[bind_path[1]], nil
	for _, key in ipairs(indexes_flattened) do
		obj = TreeNodeByPath(obj, key)
		if IsKindOf(obj, type_name) then
			last_matching = obj
		end
	end
	return last_matching
end

---
--- The function will return a list of all parent objects in the bind path of the specified object.
---
--- @param name string The name of the object to get the parent list for.
--- @return table The list of parent objects.
---
function GedGameSocket:GetParentsList(name)
	local all_parents = {}
	local bind_path = self.bound_objects_path[name:match("(.+)|.+") or name]
	if bind_path then
		local obj = self.bound_objects[bind_path[1]]
		table.insert(all_parents, obj)
		for i = 2, #bind_path - 1 do
			table.insert(all_parents, self.bound_objects[bind_path[i].name])
		end
	end
	return all_parents
end

---
--- Called when the parents of an object have been modified.
---
--- This function is responsible for marking the modified object and its root objects as dirty, so that they can be updated in the UI.
---
--- @param name string The name of the object whose parents have been modified.
---
function GedGameSocket:OnParentsModified(name)
	local all_parents = self:GetParentsList(name)
	-- call in reverse order, so a preset would be marked as dirty before the preset tree is refreshed
	for i = #all_parents, 1, -1 do
		ObjModified(all_parents[i])
	end
	assert(next(SuspendObjModifiedReasons)) -- assume that SuspendObjModified is called and will prevent multiple updates of the same object
	for _, name in ipairs(self.root_names) do
		ObjModified(self.bound_objects[name])
	end
end

---
--- Gathers a list of all game objects that are affected by the specified object, including the object itself and all of its parent objects.
---
--- @param obj any The object to gather affected game objects for.
--- @return table|nil A table of all affected game objects, or nil if there are no affected game objects.
---
function GedGameSocket:GatherAffectedGameObjects(obj)
	local ret = {}
	local objs_and_parents = self:GetParentsList(self:ResolveName(obj))
	table.insert(objs_and_parents, obj)
	for _, obj in ipairs(objs_and_parents) do
		if IsValid(obj) then
			table.insert(ret, obj)
		elseif IsKindOf(obj, "GedMultiSelectAdapter") then
			table.iappend(ret, obj.__objects)
		end
	end
	ret = table.validate(table.get_unique(ret))
	return #ret > 0 and ret
end

---
--- Restores the application state from the provided undo entry.
---
--- This function is responsible for:
--- 1. Setting the pending selection in all panels (which will be set when panel data arrives)
--- 2. Rebinding each panel to its former object
---
--- @param undo_entry table The undo entry containing the application state to restore.
---
function GedGameSocket:RestoreAppState(undo_entry)
	-- 1. Set pending selection in all panels (will be set when panel data arrives)
	local app_state = undo_entry and undo_entry.app_state or self.last_app_state
	local focused_panel = app_state.focused_panel
	for context, state in pairs(app_state) do
		local sel = state.selection
		if sel then
			self:SetSelection(context, sel[1], sel[2], not "notify", "restoring_state", focused_panel == context)
		end
	end
	
	-- 2. Rebind each panel to its former object
	if undo_entry then
		self.bound_objects_path = table.copy(undo_entry.bound_objects_path, "deep")
		self.bound_objects_func = table.copy(undo_entry.bound_objects_func)
		self:SetLastAppState(app_state)
	end
	self:RebindAll()
end

---
--- Rebinds all objects that are bound to the GedGameSocket.
---
--- This function is responsible for:
--- 1. Iterating through all bound objects and rebinding them to their respective objects.
--- 2. Unbinding any objects that no longer exist or have been removed from the bound objects.
---
--- @param self GedGameSocket The GedGameSocket instance.
---
function GedGameSocket:RebindAll()
	-- iterate a copy of the keys as the bound_objects changes while iterating
	for idx, name in ipairs(table.keys(self.bound_objects)) do
		if not name:find("|", 1, true) then
			local obj_path = self.bound_objects_path[name]
			local obj = self.bound_objects[obj_path and obj_path[1] or name]
			if obj then
				if obj_path then
					for i = 2, #obj_path do
						local path = obj_path[i]
						local last_entry = #path > 0 and path[#path]
						if type(last_entry) == "table" then
							obj = TreeNodeByPath(obj, unpack_params(path, 1, #path - 1))
							obj = GedMultiSelectAdapter:new{ __objects = table.map(last_entry, function(idx) return TreeNodeByPath(obj, idx) end) }
						else
							obj = TreeNodeByPath(obj, unpack_params(path))
						end
					end
				end
				if obj then
					local func = self.bound_objects_func[name]
					self:UnbindObj(name)
					self:UnbindObjs(name .. "|") -- unbind all views, Ged will rebind them
					self:BindObj(name, obj, func)
					self.bound_objects_path[name] = obj_path -- restore bind path as UnbindObj removes it
				elseif not self.bound_objects_filter[name] then
					self:UnbindObj(name)
				end
			end
		end
	end
end

---
--- Binds a filter object to the GedGameSocket.
---
--- This function is responsible for:
--- 1. Creating a new filter object if the `filter_class_or_instance` parameter is a string.
--- 2. Binding the filter object to the GedGameSocket using the `BindObj` method.
--- 3. Storing the filter object in the `bound_objects_filter` table, using the `name` parameter as the key.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name to associate with the filter object.
--- @param filter_name string The name of the filter object to bind.
--- @param filter_class_or_instance table|string The filter object or the name of the filter class to create.
---
function GedGameSocket:rfnBindFilterObj(name, filter_name, filter_class_or_instance)
	local filter = filter_class_or_instance
	if type(filter) == "string" then
		filter = _G[filter]:new()
	elseif not filter then
		filter = self:ResolveObj(filter_name)
	end
	assert(IsKindOf(filter, "GedFilter"))
	
	filter.ged = self
	filter.target_name = name
	self:BindObj(filter_name, filter)
	
	self.bound_objects_filter[name] = filter
end

---
--- Binds an object to the GedGameSocket.
---
--- This function is responsible for:
--- 1. Resolving the object to be bound based on the provided `obj_address` parameter.
--- 2. Binding the object to the GedGameSocket using the `BindObj` method.
--- 3. Storing the binding path in the `bound_objects_path` table, if the object has a path.
--- 4. Storing the property binding in the `prop_bindings` table, if the object has a property ID.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name to associate with the bound object.
--- @param obj_address table|string The address of the object to be bound, either as a table of path segments or a string.
--- @param func_name string The name of the function to call when the object is bound.
--- @param ... any Additional parameters to pass to the function.
---
function GedGameSocket:rfnBindObj(name, obj_address, func_name, ...)
	if func_name and not (type(func_name) == "string" and string.starts_with(func_name, "Ged")) then
		assert(not "func_name should start with 'Ged'")
		return
	end
	local parent_name, path
	if type(obj_address) == "table" then
		parent_name, path = obj_address[1], obj_address
		table.remove(path, 1)
	else
		parent_name, path = obj_address, empty_table
	end
	
	local params = pack_params(...)
	local obj, prop_id = self:ResolveObj(parent_name, unpack_params(path))
	self:BindObj(name, obj, func_name and function(obj, filter) return _G[func_name](obj, filter, unpack_params(params)) end)
	
	if next(path) then
		local bind_path = self.bound_objects_path[parent_name]
		bind_path = bind_path and table.copy(bind_path, "deep") or { parent_name }
		path.name = name
		table.insert(bind_path, path)
		self.bound_objects_path[name] = bind_path
	end
	if obj and prop_id and not name:find("|", 1, true) then
		assert(#path == 1)
		self.prop_bindings[obj] = { parent = self.bound_objects[parent_name], prop_id = prop_id }
	end
end

---
--- Sets the last application state and updates the selected objects for each panel.
---
--- This function is responsible for:
--- 1. Storing the provided `app_state` in the `last_app_state` table.
--- 2. Iterating through the `app_state` table and updating the selected objects for each panel that has a `selection` field.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param app_state table The new application state to set.
---
function GedGameSocket:SetLastAppState(app_state)
	self.last_app_state = app_state
	for key, value in pairs(app_state) do
		if type(value) == "table" and value.selection then
			self:UpdateObjectsFromPanelSelection(key)
		end
	end
end

---
--- Retrieves the parent object of the selected objects in the specified panel.
---
--- This function is responsible for:
--- 1. Resolving the root object for the given panel.
--- 2. Traversing the object hierarchy using the selection path to find the parent object.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param panel string The name of the panel.
--- @param selection table The selection path for the panel.
--- @return table|nil The parent object, or nil if the parent cannot be found.
---
function GedGameSocket:GetSelectedObjectsParent(panel, selection)
	local parent = self:ResolveObj(panel)
	if not parent then return end
	local path = selection[1]
	if type(path) == "table" then
		local children_fn = function(obj) return obj.GedTreeChildren and obj.GedTreeChildren(obj) or obj end
		for i = 1, #path - 1 do
			parent = children_fn(parent)[path[i]]
			if not parent then return end
		end
		parent = children_fn(parent)
	end
	return parent
end

---
--- Updates the selected objects for the specified panel based on the current application state.
---
--- This function is responsible for:
--- 1. Retrieving the selection information from the last application state for the given panel.
--- 2. Finding the parent object of the selected objects using the `GetSelectedObjectsParent` function.
--- 3. Populating the `selected_objects` field in the panel's state with the actual objects corresponding to the selection indices.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param panel string The name of the panel.
---
function GedGameSocket:UpdateObjectsFromPanelSelection(panel)
	local state = self.last_app_state[panel]
	local selection = state.selection
	if type(selection[2]) == "table" and next(selection[2]) then
		local objects = {}
		local parent = self:GetSelectedObjectsParent(panel, selection)
		if not parent then return end
		for i, idx in ipairs(selection[2]) do
			objects[i] = parent[idx]
		end
		state.selected_objects = objects
	else
		state.selected_objects = nil
	end
end

---
--- Updates the panel selection based on the current selected objects.
---
--- This function is responsible for:
--- 1. Retrieving the selection information and the selected objects from the last application state for the given panel.
--- 2. Finding the parent object of the selected objects using the `GetSelectedObjectsParent` function.
--- 3. Updating the `selection` field in the panel's state with the indices of the selected objects in the parent object.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param panel string The name of the panel.
---
function GedGameSocket:UpdatePanelSelectionFromObjects(panel)
	if not self.last_app_state then return end
	
	panel = panel:match("(.+)|.+")
	local state = self.last_app_state[panel]
	local selection = state.selection
	local objects = state.selected_objects
	if selection and type(objects) == "table" then
		local objects_idxs = {}
		local parent = self:GetSelectedObjectsParent(panel, selection)
		if not parent then return end
		for _, obj in ipairs(objects) do
			objects_idxs[#objects_idxs + 1] = table.find(parent, obj) or nil
		end
		if #objects_idxs ~= #objects then
			-- we failed finding the objects in their former parent, perform a fully recursive search
			local root = self:ResolveObj(panel)
			local path, selected_idxs = RecursiveFindTreeItemPaths(root, objects)
			if path then
				self:SetSelection(panel, path, selected_idxs, not "notify")
				return
			end
		end
		if not table.iequal(state.selection[2], objects_idxs) then
			if type(selection[1]) == "table" then
				selection[1][#selection[1]] = objects_idxs[1]
			end
			selection[2] = objects_idxs
			self:SetSelection(panel, selection[1], selection[2], not "notify")
		end
	end
end

---
--- Stores the current application state.
---
--- This function is responsible for:
--- 1. Setting the last application state for the GedGameSocket instance.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param app_state table The current application state to be stored.
---
function GedGameSocket:rfnStoreAppState(app_state)
	self:SetLastAppState(app_state)
end

---
--- Selects and binds an object to the GedGameSocket instance.
---
--- This function is responsible for:
--- 1. Binding the specified object to the GedGameSocket instance.
--- 2. Notifying the editor of the object selection.
--- 3. Updating the selected object in the GedGameSocket instance.
--- 4. Clearing the selection in the last application state if it exists.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name of the object to be bound.
--- @param obj_address table The address of the object to be bound.
--- @param func_name string (optional) The name of the function to be called on the bound object.
--- @param ... any (optional) Additional arguments to be passed to the function.
---
function GedGameSocket:rfnSelectAndBindObj(name, obj_address, func_name, ...)
	local panel_context = obj_address and obj_address[1]
	local sel = self.selected_object
	self:rfnBindObj(name, obj_address, func_name, ...)
	local obj = self:ResolveObj(name)
	if obj ~= sel then
		if sel then
			GedNotify(sel, "OnEditorSelect", false, self)
			Msg("GedOnEditorSelect", sel, false, self, panel_context)
		end
		if obj then
			GedNotify(obj, "OnEditorSelect", true, self)
			Msg("GedOnEditorSelect", obj, true, self, panel_context)
		end
		self.selected_object = obj
	end
	if self.last_app_state and self.last_app_state[name] then
		self.last_app_state[name].selection = nil
	end
end

---
--- Selects and binds multiple objects to the GedGameSocket instance.
---
--- This function is responsible for:
--- 1. Pausing infinite loop detection.
--- 2. Notifying the editor of the object deselection if the selected object exists.
--- 3. Binding the specified objects to the GedGameSocket instance using `rfnBindMultiObj`.
--- 4. Resolving the bound objects and notifying the editor of the multi-object selection.
--- 5. Updating the selected object in the GedGameSocket instance.
--- 6. Resuming infinite loop detection.
--- 7. Clearing the selection in the last application state if it exists.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name of the objects to be bound.
--- @param obj_address table The address of the parent object.
--- @param obj_children_list table A list of child object names to be bound.
--- @param func_name string (optional) The name of the function to be called on the bound objects.
--- @param ... any (optional) Additional arguments to be passed to the function.
---
function GedGameSocket:rfnSelectAndBindMultiObj(name, obj_address, obj_children_list, func_name, ...)
	PauseInfiniteLoopDetection("BindMultiObj")
	if #obj_children_list > 80 then
		GedSetUiStatus("ged_multi_select", "Please wait...") -- cleared in GedGetValues
	end
	
	GedNotify(self.selected_object, "OnEditorSelect", false, self)
	self:rfnBindMultiObj(name, obj_address, obj_children_list, func_name, ...)
	local obj = self:ResolveObj(name)
	Msg("GedOnEditorMultiSelect", obj, false, self)
	GedNotify(obj, "OnEditorSelect", true, self)
	Msg("GedOnEditorMultiSelect", obj, true, self)
	self.selected_object = obj
	
	ResumeInfiniteLoopDetection("BindMultiObj")
	
	if self.last_app_state and self.last_app_state[name] then
		self.last_app_state[name].selection = nil
	end
end

---
--- Binds multiple objects to the GedGameSocket instance.
---
--- This function is responsible for:
--- 1. Resolving the parent object based on the provided `obj_address`.
--- 2. Sorting the `obj_children_list` and creating a list of child objects.
--- 3. Creating a `GedMultiSelectAdapter` object to represent the bound objects.
--- 4. Binding the `GedMultiSelectAdapter` object to the GedGameSocket instance using the provided `func_name` and additional parameters.
--- 5. Updating the `bound_objects_path` table with the bound object information.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name of the objects to be bound.
--- @param obj_address table The address of the parent object.
--- @param obj_children_list table A list of child object names to be bound.
--- @param func_name string (optional) The name of the function to be called on the bound objects.
--- @param ... any (optional) Additional arguments to be passed to the function.
---
function GedGameSocket:rfnBindMultiObj(name, obj_address, obj_children_list, func_name, ...)
	local parent_name, path
	if type(obj_address) == "table" then
		parent_name, path = obj_address[1], obj_address
		table.remove(path, 1)
	else
		parent_name, path = obj_address, {}
	end 
	local obj = self:ResolveObj(parent_name, unpack_params(path))
	if not obj then
		return
	end
	
	table.sort(obj_children_list)
	local obj_list = table.map(obj_children_list, function(el) return TreeNodeByPath(obj, el) end)
	if #obj_list == 0 then
		return
	end
	obj = GedMultiSelectAdapter:new{ __objects = obj_list }
	
	local params = pack_params(...)
	self:BindObj(name, obj, func_name and function(obj) return _G[func_name](obj, unpack_params(params)) end)
	
	local bind_path = self.bound_objects_path[parent_name]
	bind_path = bind_path and table.copy(bind_path, "deep") or { parent_name }
	table.insert(path, obj_children_list)
	path.name = name
	table.insert(bind_path, path)
	self.bound_objects_path[name] = bind_path
end
	
---
--- Unbinds an object from the GedGameSocket instance.
---
--- This function is responsible for:
--- 1. Unbinding the object with the given `name` from the GedGameSocket instance.
--- 2. If `to_prefix` is provided, it will also unbind any objects with a name that starts with the `name` and `to_prefix` concatenation.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param name string The name of the object to be unbound.
--- @param to_prefix string (optional) The prefix to be used for unbinding additional objects.
---
function GedGameSocket:rfnUnbindObj(name, to_prefix)
	self:UnbindObj(name)
	if to_prefix then
		self:UnbindObjs(name .. to_prefix)
	end
end

---
--- Notifies that the Ged system has been activated.
---
--- This function is called when the Ged system is activated, either initially or after being deactivated.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param initial boolean Whether this is the initial activation of the Ged system.
---
function GedGameSocket:rfnGedActivated(initial)
	Msg("GedActivated", self, initial)
end

---
--- Notifies that a property has been edited on an object in the Ged system.
---
--- This function is called when a property of an object in the Ged system has been edited. It sends a notification message and triggers the "OnEditorSetProperty" event on the object.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param obj table The object whose property was edited.
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The previous value of the property.
--- @param multi boolean Whether the property was edited as part of a multi-object operation.
---
function GedGameSocket:NotifyEditorSetProperty(obj, prop_id, old_value, multi)
	Msg("GedPropertyEdited", self.ged_id, obj, prop_id, old_value)
	GedNotify(obj, "OnEditorSetProperty", prop_id, old_value, self, multi)
end

---
--- Executes a Ged operation on the GedGameSocket instance.
---
--- This function is responsible for:
--- 1. Resolving the operation function based on the provided `op_name`.
--- 2. Suspending object modification notifications.
--- 3. Resolving the object to be operated on based on the provided `obj_name`.
--- 4. Gathering any affected game objects if the editor is active.
--- 5. Executing the operation function with the provided `params`.
--- 6. Handling the operation result, including setting the new selection, updating the undo queue, and resuming object modification notifications.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param app_state table The current application state.
--- @param op_name string The name of the operation to be executed.
--- @param obj_name string The name of the object to be operated on.
--- @param params table The parameters to be passed to the operation function.
--- @return string|nil The result of the operation, or nil if the operation was successful.
---
function GedGameSocket:Op(app_state, op_name, obj_name, params)
	local op_fn = _G[op_name]
	if not op_fn then
		print("Ged - unrecognized op", op_name)
		return "not found"
	end
	
	SuspendObjModified("GedOp")
	
	local obj = self:ResolveObj(obj_name)
	local game_objects = IsEditorActive() and obj and self:GatherAffectedGameObjects(obj)
	if game_objects then
		local name = "Edit objects"
		if op_name == "GedSetProperty" then
			local prop_id = params[1]
			local prop_meta = obj:GetPropertyMetadata(prop_id)
			name = string.format("Edit %s", prop_meta.name or prop_id)
		end
		XEditorUndo:BeginOp{ name = name, objects = game_objects, collapse_with_previous = (op_name == "GedSetProperty") }
	end
	
	local op_params = table.copy(params, "deep") -- keep a copy for the undo queue
	local ok, new_selection, undo_fn, slider_drag_id = sprocall(op_fn, self, obj, unpack_params(params))
	if ok then
		if type(new_selection) == "string" then -- error
			local error_msg = new_selection
			self:Send("rfnApp", "GedOpError", error_msg)
			ResumeObjModified("GedOp")
			return new_selection
		elseif new_selection then
			self:ResetFilter(obj_name)
		end
		
		if undo_fn then
			assert(type(undo_fn) == "function")
			while #self.undo_queue ~= self.undo_position do
				table.remove(self.undo_queue)
			end
			local current = self.undo_queue[self.undo_position]
			if not (slider_drag_id and current and current.slider_drag_id == slider_drag_id) then
				self.undo_position = self.undo_position + 1
				self.undo_queue[self.undo_position] = {
					app_state = app_state,
					op_fn = op_fn,
					obj_name = obj_name,
					op_params = op_params,
					bound_objects_path = table.copy(self.bound_objects_path, "deep"),
					bound_objects_func = table.copy(self.bound_objects_func),
					clipboard = table.copy(GedClipboard),
					slider_drag_id = slider_drag_id,
					undo_fn = undo_fn,
				}
			end
		end
	end
	
	obj = self:ResolveObj(obj_name) -- might change, e.g. new list item in a nested_list that was false
	if not slider_drag_id and ObjModifiedIsScheduled(obj) then
		self:OnParentsModified(obj_name) -- the change might affect how our object is displayed in the parent object(s)
	end
	ResumeObjModified("GedOp")
	
	if game_objects then
		XEditorUndo:EndOp(game_objects)
	end
	if ok and new_selection then
		self:SetSelection(obj_name, new_selection)
	end
end
---
--- Returns the last error that occurred.
---
--- @return string The last error message.
function GedGameSocket:rfnGetLastError()
	return GetLastError()
end


---
--- Executes an operation on the game object with the given name.
---
--- @param app_state table The current application state.
--- @param op_name string The name of the operation to execute.
--- @param obj_name string The name of the game object to perform the operation on.
--- @param ... any Additional parameters required for the operation.
--- @return boolean, any, function Whether the operation was successful, the new selection, and an undo function.
function GedGameSocket:rfnOp(app_state, op_name, obj_name, ...)
	local params = table.pack(...)
	
	-- execute SetProperty immediately; it is sent as the selection is being changed and affects the newly selected object otherwise
	if op_name == "GedSetProperty" then
		self:Op(app_state, op_name, obj_name, params)
		return
	end
	
	CreateRealTimeThread(self.Op, self, app_state, op_name, obj_name, params)
end

---
--- Undoes the last operation performed on the game object.
---
--- @param self GedGameSocket The GedGameSocket instance.
function GedGameSocket:rfnUndo()
	if self.undo_position == 0 or IsValidThread(self.redo_thread) then return end
	
	local entry = self.undo_queue[self.undo_position]
	self.undo_position = self.undo_position - 1
	
	SuspendObjModified("GedUndo")
	procall(entry.undo_fn)
	self:RestoreAppState(entry)
	self:ResetFilter(entry.obj_name)
	
	self:OnParentsModified(entry.obj_name)
	ResumeObjModified("GedUndo")
end

---
--- Redoes the last operation that was undone.
---
--- This function is responsible for redoing the last operation that was undone. It retrieves the last entry from the undo queue, restores the application state to that point, and then re-executes the operation that was undone. The function also updates the selection and the undo/redo state accordingly.
---
--- @param self GedGameSocket The GedGameSocket instance.
function GedGameSocket:rfnRedo()
	if self.undo_position == #self.undo_queue then return end
	
	self.undo_position = self.undo_position + 1
	local entry = self.undo_queue[self.undo_position]
	
	self.redo_thread = CreateRealTimeThread(function()
		SuspendObjModified("GedRedo")
		
		local clipboard = GedClipboard
		GedClipboard = entry.clipboard
		self:RestoreAppState(entry)
		self:ResetFilter(entry.obj_name)
		
		local obj = self:ResolveObj(entry.obj_name)
		local params = table.copy(entry.op_params, "deep") -- make sure 'entry.op_params' is not modified
		local ok, new_selection, undo_fn = sprocall(entry.op_fn, self, obj, unpack_params(params))
		if ok then
			assert(type(new_selection) ~= "string") -- no errors are expected with redo
			if new_selection then
				self:SetSelection(entry.obj_name, new_selection)
			end
			entry.undo_fn = undo_fn
		end
		self:OnParentsModified(entry.obj_name)
		
		GedClipboard = clipboard
		ResumeObjModified("GedRedo")
	end)
end

---
--- Sets the selection for the specified panel context.
---
--- This function is responsible for setting the selection for the specified panel context. It takes the panel context, the selection, whether it's a multiple selection, whether to notify, whether it's restoring state, and the focus.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param panel_context string The panel context.
--- @param selection number|table The selection, either a single number or a table of numbers.
--- @param multiple_selection boolean Whether the selection is a multiple selection.
--- @param notify boolean Whether to notify of the selection change.
--- @param restoring_state boolean Whether the selection is being restored from state.
--- @param focus boolean Whether to focus on the selection.
function GedGameSocket:SetSelection(panel_context, selection, multiple_selection, notify, restoring_state, focus)
	assert(not selection or type(selection) == "number" or type(selection) == "table")
	assert(not string.find(panel_context, "|"))
	self:Send("rfnApp", "SetSelection", panel_context, selection, multiple_selection, notify, restoring_state, focus)
end

---
--- Sets the UI status for the specified ID.
---
--- This function is responsible for setting the UI status for the specified ID. It takes the ID, the text to display, and an optional delay.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param id string The ID of the UI element to set the status for.
--- @param text string The text to display in the UI status.
--- @param delay number (optional) The delay in seconds before the status is cleared.
function GedGameSocket:SetUiStatus(id, text, delay)
	self:Send("rfnApp", "SetUiStatus", id, text, delay)
end

---
--- Sets the search string for the specified panel context.
---
--- This function is responsible for setting the search string for the specified panel context. It takes the panel context and the search string to set.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param search_string string The search string to set.
--- @param panel string (optional) The panel context to set the search string for. Defaults to "root" if not provided.
function GedGameSocket:SetSearchString(search_string, panel)
	self:Send("rfnApp", "SetSearchString", panel or "root", search_string)
end

---
--- Selects all objects in the specified panel.
---
--- This function is responsible for selecting all objects in the specified panel. It resolves the objects in the panel, creates a selection table containing the indices of all objects, and sends a "SetSelection" message to the "rfnApp" to update the selection.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param panel string The panel context to select all objects in.
function GedGameSocket:SelectAll(panel)
	local objects, selection = self:ResolveObj(panel), {}
	if #objects > 0 then
		for i, _ in ipairs(objects) do
			table.insert(selection, i)
		end
		assert(not string.find(panel, "|"))
		self:Send("rfnApp", "SetSelection", panel, { 1 }, selection)
	end
end

---
--- Selects the siblings of the currently focused object in the panel.
---
--- This function is responsible for selecting the siblings of the currently focused object in the panel. It sends a "SelectSiblingsInFocusedPanel" message to the "rfnApp" to update the selection.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param selection table The current selection.
--- @param selected boolean Whether the siblings should be selected or deselected.
function GedGameSocket:SelectSiblingsInFocusedPanel(selection, selected)
	self:Send("rfnApp", "SelectSiblingsInFocusedPanel", selection, selected)
end

---
--- Runs a global function with the given name and arguments.
---
--- This function is responsible for running a global function with the given name and arguments. It first checks that the function name starts with "Ged", and then attempts to retrieve the function from the global namespace. If the function is found, it is called with the provided arguments and the result is returned. If the function is not found, a message is printed and "not found" is returned.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param func_name string The name of the global function to run.
--- @param ... any The arguments to pass to the global function.
--- @return any The result of calling the global function.
function GedGameSocket:rfnRunGlobal(func_name, ...)
	if not string.starts_with(func_name, "Ged") then
		assert(not "func_name should start with 'Ged'")
		return
	end
	local fn = _G[func_name]
	if not fn then
		print("Ged - function not found", func_name)
		return "not found"
	end
	return fn(self, ...)
end

---
--- Invokes a method on the specified object by name.
---
--- This function is responsible for invoking a method on the specified object by name. It first resolves the object using the `ResolveObj` method, and then checks if the object has a member with the specified function name. If the member exists, it is called with the provided arguments. If the member does not exist, a message is printed indicating that the object does not have the specified method.
---
--- @param self GedGameSocket The GedGameSocket instance.
--- @param obj_name string The name of the object to invoke the method on.
--- @param func_name string The name of the method to invoke.
--- @param ... any The arguments to pass to the method.
--- @return boolean True if the method was successfully invoked, false otherwise.
function GedGameSocket:rfnInvokeMethod(obj_name, func_name, ...)
	local obj = self:ResolveObj(obj_name)
	if not obj or IsKindOf(obj, "GedMultiSelectAdapter") then return false end
	if PropObjHasMember(obj, func_name) then
		if CanYield() then -- :Call() expects the result of the method call
			return obj[func_name](obj, self, ...)
		else
			CreateRealTimeThread(obj[func_name], obj, self, ...)
		end
	else
		print("The object has no method: ", func_name)
	end
end

---
--- Invokes a custom editor action on the specified object.
---
--- This function is responsible for invoking a custom editor action on the specified object. It first resolves the object using the `ResolveObj` method, and then checks if the object has a member with the specified function name. If the member exists, it is called with the provided `ged` argument. If the member does not exist, it checks if the function name exists in the global namespace and calls it with the `ged` and `obj` arguments. If the function is not found, a message is printed indicating that the method could not be found.
---
--- @param ged GedGameSocket The GedGameSocket instance.
--- @param obj_name string The name of the object to invoke the custom editor action on.
--- @param func_name string The name of the custom editor action to invoke.
--- @return boolean True if the custom editor action was successfully invoked, false otherwise.
function GedCustomEditorAction(ged, obj_name, func_name)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return false end
	if PropObjHasMember(obj, func_name) then
		CreateRealTimeThread(function() obj[func_name](obj, ged) end)
	elseif rawget(_G, func_name) then
		CreateRealTimeThread(function() _G[func_name](ged, obj) end)
	else
		print("Could not find CustomEditorAction's method by name", func_name)
	end
end

---
--- Gets the toggled action state for the specified function name.
---
--- This function is used to retrieve the toggled action state for a specific function. It looks up the function in the global namespace and calls it with the provided `ged` argument.
---
--- @param ged GedGameSocket The GedGameSocket instance.
--- @param func_name string The name of the function to get the toggled action state for.
--- @return boolean The toggled action state for the specified function.
function GedGetToggledActionState(ged, func_name)
	return _G[func_name](ged)
end

---
--- Displays a message dialog with the specified title and text.
---
--- This function is used to display a message dialog to the user. The title and text of the dialog are translated using the `GedTranslate` function before being displayed.
---
--- @param title string The title of the message dialog.
--- @param text string The text to be displayed in the message dialog.
function GedGameSocket:ShowMessage(title, text)
	title = GedTranslate(title or "", nil, false)
	text = GedTranslate(text or "", nil, false)
	self:Send("rfnApp", "ShowMessage", title, text)
end

---
--- Displays a question dialog with the specified title, text, and button labels.
---
--- This function is used to display a question dialog to the user. The title, text, and button labels are translated using the `GedTranslate` function before being displayed.
---
--- @param title string The title of the question dialog.
--- @param text string The text to be displayed in the question dialog.
--- @param ok_text string The label for the "OK" button.
--- @param cancel_text string The label for the "Cancel" button.
--- @return boolean True if the user clicked the "OK" button, false if the user clicked the "Cancel" button or closed the dialog.
function GedGameSocket:WaitQuestion(title, text, ok_text, cancel_text)
	title = GedTranslate(title or "", nil, false)
	text = GedTranslate(text or "", nil, false)
	ok_text = GedTranslate(ok_text or "", nil, false)
	cancel_text = GedTranslate(cancel_text or "", nil, false)
	return self:Call("rfnApp", "WaitQuestion", title, text, ok_text, cancel_text)
end

---
--- Deletes a question dialog.
---
--- This function is used to delete a previously displayed question dialog. It sends a request to the "rfnApp" component to delete the question dialog.
---
--- @return boolean True if the question dialog was successfully deleted, false otherwise.
function GedGameSocket:DeleteQuestion()
	return self:Call("rfnApp", "DeleteQuestion")
end

---
--- Displays a user input dialog with the specified title and default text, and optionally a list of combo items.
---
--- This function is used to display a user input dialog to the user. The title and default text are translated using the `GedTranslate` function before being displayed. If `combo_items` is provided, the dialog will display a combo box with the specified items.
---
--- @param title string The title of the user input dialog.
--- @param default_text string The default text to be displayed in the user input field.
--- @param combo_items table (optional) A table of items to be displayed in the combo box.
--- @return string The text entered by the user, or nil if the dialog was canceled.
function GedGameSocket:WaitUserInput(title, default_text, combo_items)
	title = GedTranslate(title or "", nil, false)
	default_text = GedTranslate(default_text or "", nil, false)
	return self:Call("rfnApp", "WaitUserInput", title, default_text, combo_items)
end

---
--- Displays a list choice dialog with the specified items, caption, and initial selection.
---
--- This function is used to display a list choice dialog to the user. The items, caption, and initial selection are translated using the `GedTranslate` function before being displayed.
---
--- @param items table A table of items to be displayed in the list.
--- @param caption string The caption for the list choice dialog.
--- @param start_selection any The initial item to be selected in the list.
--- @param lines number (optional) The number of lines to display in the list.
--- @return any The selected item from the list, or nil if the dialog was canceled.
function GedGameSocket:WaitListChoice(items, caption, start_selection, lines)
	if not caption or caption == "" then caption = "Please select:" end
	if not items or type(items) ~= "table" or #items == 0 then items = {""} end
	if not start_selection then start_selection = items[1] end
	return self:Call("rfnApp", "WaitListChoice", items, caption, start_selection, lines)
end


---
--- Displays a browse dialog to the user, allowing them to select a file or folder.
---
--- This function is used to display a browse dialog to the user, which allows them to select a file or folder. The dialog is displayed using the "rfnApp" component.
---
--- @param folder string The initial folder to display in the browse dialog.
--- @param filter string The file filter to apply to the browse dialog.
--- @param create boolean Whether to allow the user to create a new file or folder.
--- @param multiple boolean Whether to allow the user to select multiple files or folders.
--- @return string|table The selected file or folder path(s), or nil if the dialog was canceled.
function GedGameSocket:WaitBrowseDialog(folder, filter, create, multiple)
	return self:Call("rfnApp", "WaitBrowseDialog", folder, filter, create, multiple)
end

---
--- Sets the progress status of a long-running operation.
---
--- This function is used to update the progress status of a long-running operation, such as a background task or a loading process. The `text` parameter specifies the status message to display, `progress` specifies the current progress value, and `total_progress` specifies the total progress value.
---
--- @param text string The status message to display.
--- @param progress number The current progress value.
--- @param total_progress number The total progress value.
function GedGameSocket:SetProgressStatus(text, progress, total_progress)
	self:Send("rfnApp", "SetProgressStatus", text, progress, total_progress)
end

-- We only send the text representation of the items for combo & choice props (assuming uniqueness),
-- as the actual values could be complex objects that can't go through the socket.
---
--- Formats a combo item for display.
---
--- This function is used to format a combo item for display in a UI element. It takes a combo item, which can be a string, a table, or a localization ID, and returns a formatted string that can be displayed to the user.
---
--- If the item is a table, the function will use the `name` or `text` field of the table as the display text, and will translate the text using the `GedTranslate` function. If the item is a localization ID, the function will translate the ID using `GedTranslate`.
---
--- If the item is a string, the function will simply return the string as-is, unless it is a localization ID, in which case it will translate the ID using `GedTranslate`.
---
--- @param item any The combo item to format.
--- @param obj table The object that the combo item is associated with.
--- @return string The formatted display text for the combo item.
local function GedFormatComboItem(item, obj)
	if type(item) == "table" and not IsT(item) then
		return GedTranslate(item.name or item.text or Untranslated(item.id), obj, false)
	else
		return IsT(item) and GedTranslate(item, obj) or tostring(item)
	end
end

local function ComboGetItemIdByName(value, items, obj, allow_arbitrary_values, translate)
	if not value then return end
	for _, item in ipairs(items or empty_table) do
		if GedFormatComboItem(item, obj) == value then
			if type(item) == "table" then
				return item.id or (item.value ~= nil and item.value)
			else
				return item
			end
		end
	end
	if not allow_arbitrary_values then return end
	return translate and T{RandomLocId(), value} or value
end

local function ComboGetItemNameById(id, items, obj, allow_arbitrary_values)
	if not items then return end
	for _, item in ipairs(items) do
		if item == id or type(item) == "table" and not IsT(item) and (item.id or (item.value ~= nil and item.value)) == id then
			return GedFormatComboItem(item, obj)
		end
	end
	return IsT(id) and GedTranslate(id, obj) or id
end

local eval = prop_eval

---
--- Retrieves a list of items for a property in the Ged editor.
---
--- This function is used to get the list of items to display in a combo or choice property in the Ged editor. It takes the name of the object and the ID of the property, and returns a list of items that can be displayed in the UI.
---
--- The function first resolves the object using the `ResolveObj` method, and then retrieves the property metadata for the specified property ID. It then evaluates the `items` field of the property metadata to get the list of items.
---
--- The function formats each item using the `GedFormatComboItem` function, and returns a table of the formatted items.
---
--- @param obj_name string The name of the object.
--- @param prop_id string The ID of the property.
--- @return table A list of formatted items to display in the UI.
function GedGameSocket:rfnGetPropItems(obj_name, prop_id)
	local obj = self:ResolveObj(obj_name)
	if not obj then return empty_table end

	local meta = obj:GetPropertyMetadata(prop_id)
	local items = meta and eval(meta.items, obj, meta, {})
	if not items then return empty_table end
	
	local ret = {}
	for i, item in ipairs(items) do
		local text = GedFormatComboItem(item, obj)
		ret[#ret + 1] = type(item) == "table" and item or text
	end
	return ret
end	

---
--- Retrieves a list of preset items for a property in the Ged editor.
---
--- This function is used to get the list of preset items to display in a combo or choice property in the Ged editor. It takes the name of the object and the ID of the property, and returns a list of preset items that can be displayed in the UI.
---
--- The function first resolves the object using the `ResolveObj` method, and then retrieves the property metadata for the specified property ID. It then evaluates the `preset_class` field of the property metadata to get the class of the preset items.
---
--- The function then creates an enumerator based on the `preset_group` or `GlobalMap` properties of the preset class, and evaluates the enumerator to get the list of preset items. The function formats each item using the `ComboFormat` method of the preset class, if it exists, and returns a table of the formatted items.
---
--- @param obj_name string The name of the object.
--- @param prop_id string The ID of the property.
--- @return table A list of formatted preset items to display in the UI.
function GedGameSocket:rfnGetPresetItems(obj_name, prop_id)
	local obj = self:ResolveObj(obj_name)
	local meta = GedIsValidObject(obj) and obj:GetPropertyMetadata(prop_id)
	if not meta then return empty_table end -- can happen when the selected object in Ged changes and GetPresetItems RPC is sent after that
	
	local preset_class = eval(meta.preset_class, obj, meta)
	if not preset_class or not g_Classes[preset_class] then return empty_table end
	
	local extra_item = eval(meta.extra_item, obj, meta) or nil
	local combo_format = _G[preset_class]:HasMember("ComboFormat") and _G[preset_class].ComboFormat
	local enumerator
	local preset_group = eval(meta.preset_group, obj, meta)
	if preset_group then
		enumerator = PresetGroupCombo(preset_class, preset_group, meta.preset_filter, extra_item, combo_format)
	elseif _G[preset_class].GlobalMap or IsPresetWithConstantGroup(_G[preset_class]) then
		enumerator = PresetsCombo(preset_class, nil, extra_item, meta.preset_filter, combo_format)
	else
		return { "" }
	end
	return table.iappend({ "" }, eval(enumerator, obj, meta))
end

---
--- Retrieves a list of game objects that match the specified base class.
---
--- This function is used to get a list of game objects that match the base class specified in the property metadata for a given object and property ID. It first resolves the object using the `ResolveObj` method, and then retrieves the property metadata for the specified property ID. If the metadata contains a `base_class` field, it evaluates the base class and uses it to retrieve the list of matching game objects from the `MapGet` function. If no base class is specified, or if the object cannot be resolved, the function returns an empty table.
---
--- @param obj_name string The name of the object.
--- @param prop_id string The ID of the property.
--- @return table A list of game objects that match the specified base class.
function GedGameSocket:MapGetGameObjects(obj_name, prop_id)
	local obj = self:ResolveObj(obj_name)
	if not obj then return empty_table end

	local meta = obj:GetPropertyMetadata(prop_id)
	
	if not meta.base_class then return empty_table end
		
	local base_class = eval(meta.base_class, obj, meta) or "Object"
	local objects = MapGet("map", base_class) or {}

	return objects
end

---
--- Formats the display text for a game object in the object property editor.
---
--- This function is used to format the display text for a game object in the object property editor. It takes a game object as input and returns a formatted string that includes the object's editor label (or class name if no editor label is set) and the object's position.
---
--- @param gameobj table The game object to format.
--- @return string The formatted display text for the game object.
function GetObjectPropEditorFormatFuncDefault(gameobj)
	if gameobj and IsValid(gameobj) then
		local x, y = gameobj:GetPos():xy()
		local label = gameobj:GetProperty("EditorLabel") or gameobj.class
		return string.format("%s x:%d y:%d", label, x, y)
	else
		return ""
	end
end

---
--- Retrieves the appropriate format function for displaying a game object's property in the object property editor.
---
--- This function checks the property metadata to see if a custom format function is specified. If a custom function is specified, it is returned. Otherwise, the default format function `GetObjectPropEditorFormatFuncDefault` is returned.
---
--- @param prop_meta table The property metadata for the game object.
--- @return function The format function to use for displaying the game object's property.
function GetObjectPropEditorFormatFunc(prop_meta)
	local format_func = GetObjectPropEditorFormatFuncDefault
	if prop_meta.format_func then
		format_func = prop_meta.format_func
	end
	return format_func
end

---
--- Retrieves a list of game objects that match the specified base class for a given object and property ID.
---
--- This function is used to get a list of game objects that match the base class specified in the property metadata for a given object and property ID. It first resolves the object using the `ResolveObj` function, then retrieves the property metadata and the base class. It then uses the `MapGet` function to retrieve the list of game objects that match the base class.
---
--- @param obj_name string The name of the object.
--- @param prop_id string The ID of the property.
--- @return table A list of game objects that match the specified base class.
function GedGameSocket:rfnMapGetGameObjects(obj_name, prop_id)
	local obj = self:ResolveObj(obj_name)
	if not obj then return { {value = false, text = ""} } end

	local meta = obj:GetPropertyMetadata(prop_id)
	local objects = self:MapGetGameObjects(obj_name, prop_id)
	local format_func = GetObjectPropEditorFormatFunc(meta)
	local items = { {value = false, text = ""} }
	for key, value in ipairs(objects) do
		table.insert(items, {
			value = value.handle,
			text = format_func(value),
		})
	end
	return items
end

---
--- Handles the collapse state of a tree panel node for a given game object.
---
--- This function is called when a tree panel node is collapsed or expanded. It stores the collapsed state of the node in a global table `GedTreePanelCollapsedNodes`, keyed by the game object. If the current context has a `PresetClass`, it also sends a `GedTreeNodeCollapsedChanged` message.
---
--- @param obj_name string The name of the game object.
--- @param path table The path to the tree panel node.
--- @param collapsed boolean Whether the node is collapsed or not.
function GedGameSocket:rfnTreePanelNodeCollapsed(obj_name, path, collapsed)
	local obj = self:ResolveObj(obj_name, unpack_params(path))
	if not obj then return end
	GedTreePanelCollapsedNodes[obj] = collapsed or nil
	if self.context.PresetClass then
		Msg("GedTreeNodeCollapsedChanged")
	end
end

---
--- Retrieves a list of game objects that match the specified view functions for the bound objects of this socket.
---
--- This function iterates through the bound objects of the socket and checks if the object name matches the specified view functions. If a match is found, the object is added to the results list.
---
--- @param view_to_function table A table mapping view names to their corresponding functions.
--- @return table A list of game objects that match the specified view functions.
function GedGameSocket:GetMatchingBoundObjects(view_to_function)
	local results = {}
	for name, object in ipairs(self.bound_objects) do
		local name = name:match("^(%w+)$")
		if not name then
			goto no_match
		end
		for view, func in pairs(view_to_function) do
			local full_name = name .. "|" .. view
			if not self.bound_objects_func[full_name] ~= func then
				goto no_match
			end
		end
		
		table.insert(results, object)
		::no_match::
	end
	
	return results
end

---
--- Forces an update of the specified game object across all sockets that have it bound.
---
--- This function is used to ensure that the value of a game object is updated in all sockets that have it bound. It iterates through the sockets that have the object bound and sets the `bound_objects_svalue` for the object to `nil`, which will trigger an update the next time the object's value is accessed.
---
--- @param obj table The game object to force an update for.
function GedForceUpdateObject(obj)
	local sockets = GedObjects[obj]
	if not sockets then return end
	for i = 1, #sockets - 1, 2 do
		local name, socket = sockets[i], sockets[i + 1]
		if socket.bound_objects[name] == obj then
			socket.bound_objects_svalue[name] = nil
		end
	end
end

---
--- Updates the value of a game object bound to a socket.
---
--- This function is used to update the value of a game object that is bound to a socket. It retrieves the function associated with the bound object, calls that function to get the updated values, and then sends the updated values to the socket.
---
--- If the updated values are different from the previous values, the function updates the `bound_objects_svalue` table and sends the new values to the socket using the `rfnObjValue` message. If the bound object is a list or tree, the function also updates the panel selection from the objects.
---
--- @param socket table The socket that the game object is bound to.
--- @param obj table The game object to update.
--- @param name string The name of the bound object.
---
function GedUpdateObjectValue(socket, obj, name)
	local func = socket.bound_objects_func[name]
	if not func then return end
	
	local values = func(obj or socket.bound_objects[name], socket:FindFilter(name))
	local vpstr = ValueToLuaCode(values, nil, pstr("", 1024))
	if vpstr ~= socket.bound_objects_svalue[name] then
		socket.bound_objects_svalue[name] = vpstr
		socket:Send("rfnObjValue", name, vpstr:str(), true)
		
		if name:ends_with("|list") or name:ends_with("|tree") then
			socket:UpdatePanelSelectionFromObjects(name)
		end
	end
end

---
--- Handles the modification of a game object in the Ged (Game Editor) system.
---
--- This function is called when a game object is modified. It iterates through all the sockets that have the modified object bound, and updates the value of the bound object in those sockets. If the modified object is part of a nested property (e.g. a nested object or list), the function also calls the property setter to update the nested property.
---
--- @param obj table The game object that was modified.
--- @param view string (optional) The view that the modified object belongs to.
---
function GedObjectModified(obj, view)
	local sockets = GedObjects[obj]
	if not sockets then return end
	
	Msg("GedObjectModified", obj, view)
	
	sockets = table.copy(sockets) -- rfnBindObj and other calls could be received during socket:Send in GedUpdateObjectValue
	for i = 1, #sockets - 1, 2 do
		local name, socket = sockets[i], sockets[i + 1]
		if socket.bound_objects[name] == obj and (not view or name:ends_with("|" .. view)) then
			GedUpdateObjectValue(socket, obj, name)
		end
		
		-- when a nested_obj / nested_list changes, call its property setter
		-- this allow nested_obj/nested_list properties implemented via Get/Set to work
		local prop_binding = socket.prop_bindings[obj]
		if prop_binding then
			prop_binding.parent:SetProperty(prop_binding.prop_id, obj)
		end
	end
end

---
--- Handles the modification of a game object in the Ged (Game Editor) system.
---
--- This function is called when a game object is modified. It iterates through all the sockets that have the modified object bound, and updates the value of the bound object in those sockets. If the modified object is part of a nested property (e.g. a nested object or list), the function also calls the property setter to update the nested property.
---
--- @param obj table The game object that was modified.
--- @param view string (optional) The view that the modified object belongs to.
---
function OnMsg.ObjModified(obj)
	GedObjectModified(obj)
end

---
--- Handles the deletion of a game object in the Ged (Game Editor) system.
---
--- This function is called when a game object is deleted. It iterates through all the sockets that have the deleted object bound as the root, and sends a "rfnClose" message to those sockets to notify them of the object deletion.
---
--- @param obj table The game object that was deleted.
---
function GedObjectDeleted(obj)
	if GedObjects[obj] then
		for id, conn in pairs(GedConnections) do
			if conn:ResolveObj("root") == obj then
				conn:Send("rfnClose")
			end
		end
	end
end

-- delayed rebinding of root in all GedApps
-- can now be used with any bind name, not only root
---
--- Rebinds the root object in all GedConnections that have the specified old_value bound.
---
--- This function is used to update the root object binding in all GedConnections when the root object has changed. It iterates through all GedConnections and rebinds the new root object, optionally restoring the application state to keep the selection and last focused panel the same.
---
--- @param old_value table The old root object that needs to be rebound.
--- @param new_value table The new root object to bind.
--- @param bind_name string (optional) The name of the binding to update. Defaults to "root".
--- @param func function (optional) A function to call after the binding is updated.
--- @param dont_restore_app_state boolean (optional) If true, the application state will not be restored after the rebinding.
---
function GedRebindRoot(old_value, new_value, bind_name, func, dont_restore_app_state)
	if not old_value then return end
	bind_name = bind_name or "root"
	CreateRealTimeThread(function()
		for id, conn in pairs(GedConnections) do
			if conn:ResolveObj(bind_name) == old_value then
				conn:BindObj(bind_name, new_value, func)
				
				if not dont_restore_app_state then
					-- Will rebind all panels; everything that was bound "relatively" from the root might be invalidated as well.
					-- Keeps the selection and last focused panel the same (as stored in last_app_state).
					conn:RestoreAppState()
					conn:ResetUndoQueue()
				end
			end
		end
	end)
end

---
--- Configures the behavior of the editor for various events.
---
--- `AutoResolveMethods.OnEditorSetProperty` enables automatic resolution of methods for the `OnEditorSetProperty` event.
--- `RecursiveCallMethods.OnEditorNew` sets the method to be called for the `OnEditorNew` event to `sprocall`.
--- `RecursiveCallMethods.OnAfterEditorNew` sets the method to be called for the `OnAfterEditorNew` event to `sprocall`.
--- `RecursiveCallMethods.OnEditorDelete` sets the method to be called for the `OnEditorDelete` event to `sprocall`.
--- `RecursiveCallMethods.OnAfterEditorDelete` sets the method to be called for the `OnAfterEditorDelete` event to `sprocall`.
--- `RecursiveCallMethods.OnAfterEditorSwap` sets the method to be called for the `OnAfterEditorSwap` event to `sprocall`.
--- `RecursiveCallMethods.OnAfterEditorDragAndDrop` sets the method to be called for the `OnAfterEditorDragAndDrop` event to `procall`.
--- `AutoResolveMethods.OnEditorSelect` enables automatic resolution of methods for the `OnEditorSelect` event.
--- `AutoResolveMethods.OnEditorDirty` enables automatic resolution of methods for the `OnEditorDirty` event.
---
AutoResolveMethods.OnEditorSetProperty = true
RecursiveCallMethods.OnEditorNew = "sprocall"
RecursiveCallMethods.OnAfterEditorNew = "sprocall"
RecursiveCallMethods.OnEditorDelete = "sprocall"
RecursiveCallMethods.OnAfterEditorDelete = "sprocall"
RecursiveCallMethods.OnAfterEditorSwap = "sprocall"
RecursiveCallMethods.OnAfterEditorDragAndDrop = "procall"
AutoResolveMethods.OnEditorSelect = true
AutoResolveMethods.OnEditorDirty = true

---
--- Notifies an object of a method call.
---
--- @param obj table The object to notify.
--- @param method string The name of the method to call.
--- @param ... any Additional arguments to pass to the method.
--- @return boolean, any Whether the method call was successful and its return value.
---
function GedNotify(obj, method, ...)
	if not obj then return end
	Msg("GedNotify", obj, method, ...)
	if PropObjHasMember(obj, method) then
		local ok, result = sprocall(obj[method], obj, ...)
		return ok and result
	end
end

---
--- Recursively notifies an object and its sub-objects of a method call.
---
--- @param obj table The object to notify.
--- @param method string The name of the method to call.
--- @param parent table The parent object of the current object.
--- @param ... any Additional arguments to pass to the method.
---
function GedNotifyRecursive(obj, method, parent, ...)
	if not obj then return end
	assert(type(parent) == "table")
	obj:ForEachSubObject(function(obj, parents, key, ...)
		GedNotify(obj, method, parents[#parents] or parent, ...)
	end, ...)
end


----- Data formatting functions

---
--- Checks if the given object is a valid PropertyObject.
---
--- @param obj table The object to check.
--- @return boolean Whether the object is a valid PropertyObject.
---
function GedIsValidObject(obj)
	return IsKindOf(obj, "PropertyObject") and (not IsKindOf(obj, "CObject") or IsValid(obj))
end

---
--- Returns the global property categories.
---
--- @return table The global property categories.
---
function GedGlobalPropertyCategories()
	return PropertyCategories
end

---
--- Calculates usage statistics for properties in a set of presets.
---
--- @param root table The root object to search for presets.
--- @param filter function A function to filter the presets to consider.
--- @param preset_class string The class of presets to consider.
--- @return table The usage statistics for each property, where the key is the property ID and the value is either the number of presets it is used in (if used in more than one preset) or the ID of the preset it is used in (if used in only one preset).
---
function GedPresetPropertyUsageStats(root, filter, preset_class)
	local stats, used_in = {}, {}
	ForEachPreset(preset_class, function(preset)
		for _, prop in ipairs(preset:GetProperties()) do
			local id = prop.id
			stats[id] = stats[id] or 0
			if not preset:IsPropertyDefault(id, prop) then
				stats[id] = stats[id] + 1
				used_in[id] = preset.id
			end
		end
	end)
	for id, count in pairs(stats) do
		if count == 1 then
			stats[id] = used_in[id]
		elseif count ~= 0 then
			stats[id] = nil
		end
	end
	return stats
end

local function ConvertSlashes(path)
	return string.gsub(path, "\\", "/")
end

local function OSFolderObject(os_path)
	local os_path, err = ConvertToOSPath(os_path)
	-- if an error occurred, then this path doesn't exist in the OS filesystem.
	-- if we return nil, the result will not be added to the list of paths for this control (see GedGetFolders)
	-- thus a button will not be created for it
	if not err then
		return { os_path = ConvertSlashes(os_path) }
	end
end

local function GameFolderObject(game_path)
	local os_path, err = ConvertToOSPath(SlashTerminate(game_path))
	if not err then
		return { game_path = game_path, os_path = ConvertSlashes(os_path) }
	end
end

local function ToFolderObject(path, path_type)
	path = SlashTerminate(path)
	return path_type == "os" and OSFolderObject(path) or GameFolderObject(path)
end

local function GedGetFolders(obj, prop_meta, mod_def)
	local result = {}
	local folder = eval(prop_meta.folder, obj, prop_meta)
	local os_path = eval(prop_meta.os_path, obj, prop_meta)
	if folder then
		local default_type = os_path and "os" or "game"
		if type(folder) == "string" then
			result = { ToFolderObject(folder, default_type) }
		elseif type(folder) == "table" then
			for i,entry in ipairs(folder) do
				if type(entry) == "string" then
					table.insert(result, ToFolderObject(entry, default_type))
				elseif type(entry) == "table" then
					local path_type = entry.os_path and "os" or entry.game_path and "game" or default_type
					table.insert(result, ToFolderObject(entry[1], path_type))
				end
			end
		end
	end
	
	if not os_path then
		-- add built-in paths for image files
		if prop_meta.editor == "ui_image" then
			local preset = GetParentTableOfKindNoCheck(obj, "Preset")
			local common_preset = preset and preset:GetSaveLocationType() == "common"
			local builtin_paths = common_preset and { "CommonAssets/UI/" } or { "UI/", "CommonAssets/UI/" }
			for i, path in ipairs(builtin_paths) do
				if not table.find_value(result, "game_path", path) then
					table.insert(result, {
						game_path = path,
						os_path = ConvertToOSPath(path),
					})
				end
			end
		elseif not next(result) then
			table.insert(result, OSFolderObject("./"))
		end
		
		if mod_def then
			table.insert(result, {
				os_path = mod_def.path, --backwards compatibility
			})
			table.insert(result, {
				game_path = mod_def.content_path,
				os_path = ConvertToOSPath(mod_def.content_path),
			})
		end
	end

	return result
end

local function GedPopulateClassUseCounts(class_list, obj)
	local parent = IsKindOf(obj, "Preset") and obj or GetParentTableOfKindNoCheck(obj, "Preset")
	if not parent then return end
	
	local counts = {}
	local iterations = 1
	ForEachPreset(parent.class, function(preset)
		preset:ForEachSubObject(function(obj)
			local class = obj.class
			if obj.class then
				counts[class] = (counts[class] or 0) + 1
			end
			iterations = iterations + 1
			if iterations > 9999 then return "break" end
		end)
		if iterations > 9999 then return "break" end
	end)
	for _, item in ipairs(class_list) do
		item.use_count = counts[item.value] or 0
		item.use_count_in_preset = parent.PresetClass or parent.class
	end
end

---
--- Gets a list of sub-item classes for the given object and path.
---
--- @param socket table The socket object.
--- @param obj table The object to get the sub-item class list for.
--- @param path table The path to the object.
--- @param prop_script_domain string The script domain to filter the sub-items by.
--- @return table A list of sub-item classes, each with the following fields:
---   - text: The display name of the sub-item class.
---   - value: The class name of the sub-item.
---   - documentation: The documentation for the sub-item class.
---   - category: The editor submenu category for the sub-item class.
---
function GedGetSubItemClassList(socket, obj, path, prop_script_domain)
	local obj = socket:ResolveObj(obj, unpack_params(path))
	if not obj then return end
	local items = obj:EditorItemsMenu()
	local filtered_items = {}
	for _, item in ipairs(items) do
		-- Filter script blocks by script domain
		if not item.ScriptDomain or item.ScriptDomain == prop_script_domain then
			table.insert(filtered_items, {
				text = item.EditorName,
				value = item.Class,
				documentation = GedGetDocumentation(g_Classes[item.Class]),
				category = item.EditorSubmenu
			})
		end
	end
	GedPopulateClassUseCounts(filtered_items, obj)
	return filtered_items
end

---
--- Gets a list of sibling classes for the given object and path.
---
--- @param socket table The socket object.
--- @param obj table The object to get the sibling class list for.
--- @param path table The path to the object.
--- @return table A list of sibling classes, each with the following fields:
---   - text: The display name of the sibling class.
---   - value: The class name of the sibling class.
---   - documentation: The documentation for the sibling class.
---   - category: The editor submenu category for the sibling class.
---
function GedGetSiblingClassList(socket, obj, path)
	table.remove(path)
	return GedGetSubItemClassList(socket, obj, path)
end

---
--- Excludes the class from being displayed as a nested object in the editor.
---
--- This property is set on the `ClassNonInheritableMembers` class to prevent it from being shown as a nested object in the editor.
---
ClassNonInheritableMembers.EditorExcludeAsNested = true

--- Gets a list of nested class items for the given object and property ID.
---
--- @param socket table The socket object.
--- @param obj table The object to get the nested class items for.
--- @param prop_id string The property ID to get the nested class items for.
--- @return table A list of nested class items, each with the following fields:
---   - text: The display name of the nested class item.
---   - value: The class name of the nested class item.
---   - documentation: The documentation for the nested class item.
---   - category: The editor nested object category for the nested class item.
function GedGetNestedClassItems(socket, obj, prop_id)
	local obj = socket:ResolveObj(obj)
	local prop_meta = obj:GetPropertyMetadata(prop_id)

	local base_class = eval(prop_meta.base_class, obj, prop_meta) or eval(prop_meta.class, obj, prop_meta)
	local def = base_class and g_Classes[base_class]
	if not def or base_class == "PropertyObject" then
		assert(false, "Invalid base_class or class for a nested obj/list property")
		return {}
	end
	
	local list = {}
	local default_format = T(243864368637, "<class>")
	local function AddList(list, name, class, default_format)
		list[#list + 1] = {
			text = GedTranslate(class:HasMember("ComboFormat") and class.ComboFormat or default_format, class, false),
			value = name,
			documentation = GedGetDocumentation(class),
			category = class:HasMember("EditorNestedObjCategory") and class.EditorNestedObjCategory,
		}
	end
	
	if prop_meta.base_class then
		local inclusive = eval(prop_meta.inclusive, obj, prop_meta)
		if not eval(prop_meta.no_descendants, obj, prop_meta) then
			local all_descendants = eval(prop_meta.all_descendants, obj, prop_meta)
			local class_filter = prop_meta.class_filter
			local descendants_func = all_descendants and ClassDescendantsList or ClassLeafDescendantsList
			descendants_func(base_class, function(name, class)
				if not (class:HasMember("EditorExcludeAsNested") and class.EditorExcludeAsNested) and
					(not class_filter or class_filter(name, class, obj)) and
					not class:IsKindOf("Preset")
				then
					AddList(list, name, class, default_format)
				end
			end)
		end
		if inclusive or #list == 0 then
			AddList(list, base_class, def, default_format)
		end
		table.sortby_field(list, "value")
	else
		AddList(list, base_class, def, default_format)
	end
	
	GedPopulateClassUseCounts(list, obj)
	return list
end

local function GedGetProperty(obj, prop_meta)
	if eval(prop_meta.no_edit, obj, prop_meta) or not prop_meta.editor then
		return
	end
	
	local prop_id = prop_meta.id
	local name = eval(prop_meta.name, obj, prop_meta, "")
	if name and not IsT(name) then
		name = tostring(name)
	end
	local help = eval(prop_meta.help, obj, prop_meta, "")
	local editor = eval(prop_meta.editor, obj, prop_meta, "")
	local lines
	
	local scale = eval(prop_meta.scale, obj, prop_meta)
	local scale_name
	if scale and type(scale) == "string" then
		scale_name = scale
	elseif prop_meta.translate == true then
		scale_name = "T"
	end
	scale = type(scale) == "string" and const.Scale[scale] or scale
	scale = scale ~= 1 and scale or nil
	
	local buttons = eval(prop_meta.buttons, obj, prop_meta) or nil
	local buttons_data
	if editor == "number" and ((obj:IsKindOf("Preset") and obj.HasParameters) or (not obj:IsKindOf("Preset") and obj:HasMember("param_bindings"))) then
		buttons_data = { { name = "Param", func = "PickParam" } }
	end
	if buttons then
		buttons_data = buttons_data or {}
		for _, button in ipairs(buttons) do
			button.name = button.name or button[1]
			button.func = button.func or button[2] or button[1]
			assert(not table.find(buttons_data, "name", button.name), "Duplicate property button names!")
			if not button.is_hidden or not button.is_hidden(obj, prop_meta) then
				table.insert(buttons_data, {
					name = button.name,
					func = type(button.func) == "string" and button.func or nil,
					param = button.param,
					icon = button.icon,
					icon_scale = button.icon_scale,
					toggle = button.toggle,
					toggled = button.toggle and button.is_toggled and button.is_toggled(obj),
					rollover = button.rollover,
				})
			end
		end
		
		if editor == "buttons" and not next(buttons_data) then
			return
		end
	end
	
	local editor_class = g_Classes[GedPropEditors[editor]]
	local items = rawget(prop_meta, "items") and eval(prop_meta.items, obj, prop_meta) or nil
	local prop = {
		id = prop_id,
		category = eval(prop_meta.category, obj, prop_meta),
		editor = editor,
		script_domain = eval(prop_meta.script_domain, obj, prop_meta),
		default = GameToGedValue(obj:GetDefaultPropertyValue(prop_id, prop_meta), prop_meta, obj, items),
		sort_order = eval(prop_meta.sort_order, obj, prop_meta) or nil,
		name_on_top = eval(prop_meta.name_on_top, obj, prop_meta) or nil,
		name = name ~= "" and (IsT(name) and GedTranslate(name, obj) or name) or nil,
		help = help ~= "" and (IsT(help) and GedTranslate(help, obj) or help) or nil,
		read_only = eval(prop_meta.read_only, obj, prop_meta) or editor == "image" or editor == "grid" or nil,
		hide_name = eval(prop_meta.hide_name, obj, prop_meta) or nil,
		buttons = buttons_data,
		scale = scale,
		scale_name = scale_name,
		dlc_name = prop_meta.dlc,
		min = (editor == "number" or editor == "range" or editor == "point" or editor == "box") and eval(prop_meta.min, obj, prop_meta) or nil,
		max = (editor == "number" or editor == "range" or editor == "point" or editor == "box") and eval(prop_meta.max, obj, prop_meta) or nil,
		step = (editor == "number" or editor == "range") and eval(prop_meta.step, obj, prop_meta) or nil,
		float = (editor == "number" or editor == "range") and eval(prop_meta.float, obj, prop_meta) or nil,
		buttons_step = (editor == "number" or editor == "range") and prop_meta.slider and eval(prop_meta.buttons_step, obj, prop_meta) or nil,
		slider = (editor == "number" or editor == "range") and eval(prop_meta.slider, obj, prop_meta) or nil,
		params = (editor == "func" or editor == "expression") and eval(prop_meta.params, obj, prop_meta) or nil,
		translate = editor == "text" and eval(prop_meta.translate, obj, prop_meta) or nil,
		lines = (editor == "text" or editor == "func" or editor == "prop_table") and (eval(prop_meta.lines, obj, prop_meta) or lines) or nil,
		max_lines = (editor == "text" or editor == "func" or editor == "prop_table") and eval(prop_meta.max_lines, obj, prop_meta) or nil,
		max_len = editor == "text" and eval(prop_meta.max_len, obj, prop_meta) or nil,
		trim_spaces = editor == "text" and eval(prop_meta.trim_spaces, obj, prop_meta) or nil,
		realtime_update = editor == "text" and eval(prop_meta.realtime_update, obj, prop_meta) or nil,
		allowed_chars = editor == "text" and eval(prop_meta.allowed_chars, obj, prop_meta) or nil,
		size = editor == "flags" and (eval(prop_meta.size, obj, prop_meta) or 32) or nil,
		items = (editor == "flags" or editor == "set" or editor == "number_list" or editor == "string_list" or editor == "texture_picker" or editor == "text_picker")
			and items or nil, -- N.B: 'items' for combo properties are fetched on demand as an optimization,
		item_default = (editor == "number_list" or editor == "string_list" or editor == "preset_id_list") and eval(prop_meta.item_default, obj, prop_meta) or nil,
		arbitrary_value = (editor == "string_list" and items) and eval(prop_meta.arbitrary_value, obj, prop_meta) or nil,
		max_items = (editor == "number_list" or editor == "string_list" or editor == "preset_id_list" or editor == "T_list") and eval(prop_meta.max_items, obj, prop_meta) or nil,
		exponent = editor == "number" and eval(prop_meta.exponent, obj, prop_meta) or nil,
		per_item_buttons = (editor == "number_list" or editor == "string_list" or editor == "preset_id_list" or editor == "T_list") and prop_meta.per_item_buttons or nil,
		lock_ratio = IsKindOf(editor_class, "GedCoordEditor") and prop_meta.lock_ratio or nil,
	}
	
	if editor == "number_list" or editor == "string_list" or editor == "preset_id_list" then
		if eval(prop_meta.weights, obj, prop_meta) then
			prop.weights = true
			prop.weight_default = eval(prop_meta.weight_default, obj, prop_meta) or nil
			prop.weight_key = eval(prop_meta.weight_key, obj, prop_meta) or nil
			prop.value_key = eval(prop_meta.value_key, obj, prop_meta) or nil
		end
	end
	
	if items then -- all kinds or properties that use a combo box, including *_list properties
		prop.items_allow_tags = eval(prop_meta.items_allow_tags, obj, prop_meta) or nil
		prop.show_recent_items = eval(prop_meta.show_recent_items, obj, prop_meta) or nil
		prop.mru_storage_id = prop.show_recent_items and (prop_meta.mru_storage_id or string.format("%s.%s", obj.class, prop_meta.id)) -- ideally would use the class where the property was defined
	end
	if editor == "number" or editor == "text" or editor == "prop_table" or editor == "object" or editor == "range" or
	   editor == "point" or editor == "box" or editor == "rect" or editor == "expression" or editor == "func"
	then
		prop.auto_select_all = eval(prop_meta.auto_select_all, obj, prop_meta) or nil
		prop.no_auto_select  = eval(prop_meta.no_auto_select,  obj, prop_meta) or nil
	end
	if editor == "nested_list" or editor == "nested_obj" then
		local base_class = eval(prop_meta.base_class, obj, prop_meta)
		local class      = eval(prop_meta.class, obj, prop_meta)
		prop.base_class     = base_class or class -- used for clipboard class when copying items
		prop.format         = eval(prop_meta.format, obj, prop_meta) or nil
		prop.auto_expand    = eval(prop_meta.auto_expand, obj, prop_meta) or nil
		prop.suppress_props = eval(prop_meta.suppress_props, obj, prop_meta) or nil
	end
	if editor == "property_array" then
		prop.base_class     = "GedDynamicProps"
		prop.auto_expand    = true
	end
	if editor == "texture_picker" or editor == "text_picker" then
		prop.max_rows       = eval(prop_meta.max_rows, obj, prop_meta) or nil
		prop.multiple       = eval(prop_meta.multiple, obj, prop_meta) or nil
		prop.small_font     = eval(prop_meta.small_font, obj, prop_meta) or nil
		prop.filter_by_prop = eval(prop_meta.filter_by_prop, obj, prop_meta) or nil
		if editor == "texture_picker" then
			prop.thumb_size     = eval(prop_meta.thumb_size, obj, prop_meta) or nil
			prop.thumb_width    = eval(prop_meta.thumb_width, obj, prop_meta) or nil
			prop.thumb_height   = eval(prop_meta.thumb_height, obj, prop_meta) or nil
			prop.thumb_zoom     = eval(prop_meta.thumb_zoom, obj, prop_meta) or nil
			prop.alt_prop       = eval(prop_meta.alt_prop, obj, prop_meta) or nil
			prop.base_color_map = eval(prop_meta.base_color_map, obj, prop_meta) or nil
		else -- text_picker
			prop.horizontal     = eval(prop_meta.horizontal, obj, prop_meta) or nil
			prop.virtual_items  = eval(prop_meta.virtual_items, obj, prop_meta) or nil
			prop.bookmark_fn    = eval(prop_meta.bookmark_fn, obj, prop_meta) or nil
		end
	end
	if editor == "set" then
		prop.horizontal  = eval(prop_meta.horizontal,  obj, prop_meta) or nil
		prop.small_font  = eval(prop_meta.small_font,  obj, prop_meta) or nil
		prop.three_state = eval(prop_meta.three_state, obj, prop_meta) or nil
		prop.max_items_in_set = eval(prop_meta.max_items_in_set, obj, prop_meta) or nil
		prop.arbitrary_value = eval(prop_meta.arbitrary_value, obj, prop_meta) or nil
	end
	if editor == "preset_id" or editor == "preset_id_list" then
		prop.preset_class = eval(prop_meta.preset_class, obj, prop_meta)
		prop.preset_group = eval(prop_meta.preset_group, obj, prop_meta)
		prop.editor_preview = eval(prop_meta.editor_preview, obj, prop_meta)
		if prop.editor_preview == true then
			prop.editor_preview = g_Classes[prop.preset_class].EditorPreview
		end
		prop.editor_preview = prop.editor_preview and TDevModeGetEnglishText(prop.editor_preview, not "deep", "no_assert") or nil
	end
	if editor == "browse" or editor == "ui_image" or editor == "font" then
		local mod_def = TryGetModDefFromObj(obj)
		prop.image_preview_size = eval(prop_meta.image_preview_size, obj, prop_meta) or nil
		prop.filter = eval(prop_meta.filter, obj, prop_meta) or nil
		prop.dont_validate = eval(prop_meta.dont_validate, obj, prop_meta) or nil
		prop.os_path = eval(prop_meta.os_path, obj, prop_meta) or nil
		prop.folder = GedGetFolders(obj, prop_meta, mod_def) or nil
		prop.allow_missing = eval(prop_meta.allow_missing, obj, prop_meta) or nil
		prop.force_extension = eval(prop_meta.force_extension, obj, prop_meta) or nil
		prop.mod_dst = eval(prop_meta.mod_dst, obj, prop_meta) or nil
	end
	if editor == "text" then -- nil means 'true' for wordwrap, so we need a separate if statement
		prop.wordwrap = eval(prop_meta.wordwrap, obj, prop_meta)
		prop.text_style = eval(prop_meta.text_style, obj, prop_meta)
		prop.code = eval(prop_meta.code, obj, prop_meta)
		prop.trim_spaces = eval(prop_meta.trim_spaces, obj, prop_meta)
	end
	if editor == "func" then
		prop.trim_spaces = false
	end
	if editor == "image" then
		prop.img_back = eval(prop_meta.img_back, obj, prop_meta) or nil
		prop.img_size = eval(prop_meta.img_size, obj, prop_meta) or nil
		prop.img_width = eval(prop_meta.img_width, obj, prop_meta) or nil
		prop.img_height = eval(prop_meta.img_height, obj, prop_meta) or nil
		prop.img_box = eval(prop_meta.img_box, obj, prop_meta) or nil
		prop.img_draw_alpha_only = eval(prop_meta.img_draw_alpha_only, obj, prop_meta) or nil
		prop.img_polyline_color = eval(prop_meta.img_polyline_color, obj, prop_meta) or nil
		prop.img_polyline = eval(prop_meta.img_polyline, obj, prop_meta) or nil
		local img_polyline_closed = eval(prop_meta.img_polyline_closed, obj, prop_meta) or nil
		if img_polyline_closed and prop.img_polyline and prop.img_polyline_color then
			prop.img_polyline = table.copy(prop.img_polyline, "deep")
			for _, v in ipairs(prop.img_polyline) do
				if type(v) == "table" then
					v[#v+1] = v[1]
				end
			end
		end
		prop.base_color_map = eval(prop_meta.base_color_map, obj, prop_meta) or nil
	end
	if editor == "grid" then
		prop.frame = eval(prop_meta.frame, obj, prop_meta) or nil
		prop.color = eval(prop_meta.color, obj, prop_meta) or nil
		prop.min = eval(prop_meta.min, obj, prop_meta) or nil
		prop.max = eval(prop_meta.max, obj, prop_meta) or nil
		prop.invalid_value = eval(prop_meta.invalid_value, obj, prop_meta) or nil
		prop.grid_offset = eval(prop_meta.grid_offset, obj, prop_meta) or nil
		prop.dont_normalize = eval(prop_meta.dont_normalize, obj, prop_meta) or nil
	end
	if editor == "color" then
		prop.alpha = (prop_meta.alpha == nil) or eval(prop_meta.alpha, obj, prop_meta) or false
	end
	if editor == "packedcurve" then
		prop.display_scale_x = eval(prop_meta.display_scale_x, obj, prop_meta) or nil
		prop.max_amplitude = eval(prop_meta.max_amplitude, obj, prop_meta) or nil
		prop.min_amplitude = eval(prop_meta.min_amplitude, obj, prop_meta) or nil
		prop.color_args = eval(prop_meta.color_args, obj, prop_meta) or nil
	end
	if editor == "curve4" then
		prop.scale_x = eval(prop_meta.scale_x, obj, prop_meta) or nil
		prop.max_x = eval(prop_meta.max_x, obj, prop_meta) or nil
		prop.min_x = eval(prop_meta.min_x, obj, prop_meta) or nil
		prop.color_args = eval(prop_meta.color_args, obj, prop_meta) or nil
		prop.no_minmax = eval(prop_meta.no_minmax, obj, prop_meta) or nil
		prop.max = eval(prop_meta.max, obj, prop_meta) or nil
		prop.min = eval(prop_meta.min, obj, prop_meta) or nil
		prop.scale = eval(prop_meta.scale, obj, prop_meta) or nil
		prop.control_points = eval(prop_meta.control_points, obj, prop_meta) or nil
		prop.fixedx = eval(prop_meta.fixedx, obj, prop_meta) or nil
	end
	if editor == "script" then
		prop.name = string.format("%s(%s)", prop.name or prop.id, eval(prop_meta.params, obj, prop_meta) or "")
		if g_EditedScript and g_EditedScript == obj:GetProperty(prop.id) then
			prop.name = "<style GedHighlight>" .. prop.name
		end
		prop.class = eval(prop_meta.class, obj, prop_meta) or "ScriptProgram"
	end
	if editor == "linked_presets" then
		assert(IsKindOfClasses(obj, "Preset", "GedMultiSelectAdapter"))
		prop.preset_classes = eval(prop_meta.preset_classes, obj, prop_meta) or nil
		
		local data_exists
		for _, preset_class in ipairs(prop.preset_classes) do
			data_exists = data_exists or FindLinkedPresetOfClass(obj, preset_class)
		end
		
		-- setup .buttons, .help, .suppress_props in props
		local name = prop.name or prop.id
		prop.buttons = prop.buttons or {}
		table.insert(prop.buttons, not data_exists and
			{ name = "Create " .. name, func = "GedCreateLinkedPresets" } or
			{ name = "Delete " .. name, func = "GedDeleteLinkedPresets" })
		prop.help = "<center><style GedHighlight>" .. (prop.help or name)
		prop.suppress_props = table.copy(eval(prop_meta.suppress_props, obj, prop_meta) or empty_table)
		for _, id in ipairs({ "Id", "SaveIn", "Group", "SortKey", "Parameters", "Comment", "TODO" }) do
			assert(not prop.suppress_props[id]) -- preset class name coincides with one of the strings above?
			prop.suppress_props[id] = true
		end
	end
	if editor == "shortcut" then
		prop.shortcut_type = eval(prop_meta.shortcut_type, obj, prop_meta) or nil
	end
	if editor == "documentation" then
		local documentation = obj:GetProperty("Documentation")
		if not documentation or documentation == Undefined() then return end -- no documentation to show
		prop.help = not IsDocumentationHidden(obj) and documentation
		prop.buttons = prop.buttons or {}
		if prop.help then
			if obj.DocumentationLink then
				table.insert(prop.buttons, { name = "Read More", func = "GedOpenDocumentationLink" })
			end
			table.insert(prop.buttons, { name = "Hide Help", func = "GedHideDocumentation" })
		else
			table.insert(prop.buttons, { name = "Show Help", func = "GedShowDocumentation" })
		end
	end
	return prop
end

---
--- Gets the properties of the given object, filtering out any properties specified in the `suppress_props` table.
---
--- @param obj table The object to get the properties for.
--- @param filter table|nil A table of property IDs to filter the properties by.
--- @param suppress_props table|nil A table of property IDs to suppress (exclude) from the returned properties.
--- @return table The properties of the object, with the specified properties filtered out.
---
function GedGetProperties(obj, filter, suppress_props)
	suppress_props = suppress_props or empty_table
	
	local ged_props = {}
	if not GedIsValidObject(obj) then return ged_props end
	for _, prop_meta in ipairs(obj:GetProperties()) do
		if not suppress_props[prop_meta.id] then
			local ok, prop_or_err = procall(GedGetProperty, obj, prop_meta)
			if not ok then
				assert(false, string.format("[Ged] Failed to send property %s, likely a metadata function such as 'items' crashed. Internal err:\n%s", prop_meta.id, tostring(prop_or_err)))
			end
			ged_props[#ged_props + 1] = prop_or_err
		end
	end
	ged_props.tabs =
		obj:HasMember("PropertyTabs") and obj.PropertyTabs or
		obj:HasMember("GetPropertyTabs") and obj:GetPropertyTabs()
	ged_props.read_only = not not obj:IsReadOnly()
	return ged_props
end

---
--- Gets the values of the properties of the given object, excluding any properties that are the default value.
---
--- @param obj table The object to get the property values for.
--- @return table The values of the object's properties, excluding any properties that are the default value.
---
function GedGetValues(obj)
	local values = {}
	if not GedIsValidObject(obj) then return values end
	
	obj:PrepareForEditing()
	for _, prop_meta in ipairs(obj:GetProperties()) do
		if not eval(prop_meta.no_edit, obj, prop_meta) then
			local prop_id = prop_meta.id
			local value = obj:GetProperty(prop_id)
			if type(value) == "table" then
				GedTablePropsCache[obj] = GedTablePropsCache[obj] or {}
				GedTablePropsCache[obj][prop_id] = value
			end
			if not obj:IsDefaultPropertyValue(prop_id, prop_meta, value) then
				if rawget(obj, "param_bindings") and obj.param_bindings[prop_id] then
					values[prop_id] = obj.param_bindings[prop_id]
				else
					values[prop_id] = GameToGedValue(value, prop_meta, obj)
				end
			end
		end
	end
	GedSetUiStatus("ged_multi_select")
	return values
end

---
--- Determines if the given object is read-only.
---
--- This function checks if the object or any of its parent objects are marked as read-only. It first checks if the object itself has an `IsReadOnly` function, and returns the result of that. If the object is not read-only, it then checks the object's parent objects recursively until it reaches the root object.
---
--- @param obj table The object to check for read-only status.
--- @return boolean True if the object is read-only, false otherwise.
---
function GedGetReadOnly(obj)
	-- Mod items from unloaded or packed mods should be read-only
	if obj.mod and (not obj.mod:ItemsLoaded() or obj.mod:IsPacked()) then
		return true
	end

	local obj_read_only
	if obj and type(obj.IsReadOnly) == "function" then
		obj_read_only = obj:IsReadOnly() or false
		if obj_read_only then
			return obj_read_only
		end
	end
	
	local parent = obj
	repeat
		parent = ParentTableCache[parent]
		if parent and type(parent.IsReadOnly) == "function" then
			if parent:IsReadOnly() then
				return true
			end
		end
	until parent == nil
	
	return obj_read_only
end

-- Returns the mod id of a preset if it has one
---
--- Returns the mod ID of a preset if it has one.
---
--- @param obj table The object to get the mod ID from.
--- @return string|boolean The mod ID of the object, or false if the object does not have a mod ID.
---
function GedGetPresetMod(obj)
	if obj.mod and obj.mod.id then
		return obj.mod.id
	end
	
	return false
end

---
--- Lists objects from the given table, optionally filtering and formatting them.
---
--- @param obj table The table of objects to list.
--- @param filter GedFilter|nil The filter to apply to the objects.
--- @param format table|nil The format to apply to the objects.
--- @param allow_objects_only boolean|nil Whether to only allow objects (and not GedMultiSelectAdapter).
--- @return table The list of objects, with optional filtering and formatting applied.
---
function GedListObjects(obj, filter, format, allow_objects_only)
	if allow_objects_only and (not GedIsValidObject(obj) or IsKindOf(obj, "GedMultiSelectAdapter")) then
		return {}
	end
	
	if not filter and IsKindOf(obj, "GedFilter") then
		filter = obj
	end
	
	local format = T{format}
	local objects, ids = {}, {}
	local filtered = filter and {}
	if filter then
		filter:PrepareForFiltering()
	end
	local displayed_items = 0
	for i = 1, #obj do
		local item = obj[i]
		ids[i] = tostring(item)
		objects[i] = type(item) == "string" and item or GedTranslate(format, item, not "check")
		if filter and not filter:FilterObject(item) then
			filtered[i] = true
		else
			displayed_items = displayed_items + 1
		end
	end
	if filter then
		objects.filtered = filtered
		filter:DoneFiltering(displayed_items, filtered)
	end
	objects.ids = ids
	return objects
end

---
--- Gets the graph data from the given GraphContainer object.
---
--- @param obj GraphContainer The GraphContainer object to get the graph data from.
--- @return table The graph data.
---
function GedGetGraphData(obj)
	if GedIsValidObject(obj) then
		assert(IsKindOf(obj, "GraphContainer"))
		return obj:GetGraphData()
	end
end

---
--- Sets the graph data for the given GraphContainer object.
---
--- @param socket table The socket object.
--- @param obj GraphContainer The GraphContainer object to set the graph data for.
--- @param data table The graph data to set.
---
function GedSetGraphData(socket, obj, data)
	assert(IsKindOf(obj, "GraphContainer"))
	obj:SetGraphData(data)
end

---
--- Binds a graph node to a specified bind name.
---
--- @param socket table The socket object.
--- @param graph_name string The name of the graph.
--- @param node_handle any The handle of the node to bind.
--- @param bind_name string The name to bind the node to.
---
function GedBindGraphNode(socket, graph_name, node_handle, bind_name)
	local graph = socket:ResolveObj(graph_name)
	local node_idx = table.find(graph, "handle", node_handle)
	if node_idx then
		socket:rfnBindObj(bind_name, { graph_name, node_idx })
	end
end

local function GedDeduceSubitemMenus(node, obj, parent)
	local button_mode = IsKindOf(obj, "Container") and obj:GetContainerAddNewButtonMode()
	if not button_mode then return end
	
	local obj_container = IsKindOf(obj, "Container") and obj.ContainerClass ~= ""
	local parent_container = IsKindOf(parent, "Container") and parent.ContainerClass ~= ""
	if not obj_container and not parent_container then return end
	
	node.child_button_mode = button_mode
	node.child_class = obj_container and obj.ContainerClass or nil
	node.sibling_class = parent_container and parent.ContainerClass or nil
	node.child_name = node.child_class and g_Classes[node.child_class].EditorName
	node.sibling_name = node.sibling_class and g_Classes[node.sibling_class].EditorName
	
	--[[if node.child_button_mode:ends_with("combined") and node.child_class and node.sibling_class then
		-- if all child classes can also be added as siblings, only allow sibling creation; this skips the "Add child"/"Add below" choice step
		-- (in this case, the user can use the "Move in" afterwards if they wanted to create a child)
		local children, siblings = obj:EditorItemsMenu(), parent:EditorItemsMenu()
		for _, item in ipairs(siblings) do
			siblings[item.Class] = true
		end
		local all_children_can_be_siblings = true
		for _, item in ipairs(children) do
			if not siblings[item.Class] then
				all_children_can_be_siblings = false
				break
			end
		end
		if all_children_can_be_siblings then
			node.child_class = nil
		end
	end]]
end

local function GedCreateNode(obj, parent, format_fn, enable_rollover)
	local collapsed = GedTreePanelCollapsedNodes[obj]
	if collapsed == nil and IsKindOf(obj, "PropertyObject") and obj:HasMember("GedTreeCollapsedByDefault") then
		collapsed = obj.GedTreeCollapsedByDefault or nil
	end
	local node = {
		id = tostring(obj),
		name = format_fn(obj),
		collapsed = collapsed,
		class = obj.class,
		rollover = enable_rollover and GedGetDocumentation(obj),
	}
	GedDeduceSubitemMenus(node, obj, parent)
	return node
end

---
--- Expands a node in the Ged object tree.
---
--- @param obj table The object to expand.
--- @param parent table The parent object of the current object.
--- @param format_fn function A function to format the object's name.
--- @param children_fn function A function to get the children of the object.
--- @param filter_fn function A function to filter the children of the object.
--- @param enable_rollover boolean Whether to enable rollover for the node.
--- @return table The expanded node.
--- @return number The total number of displayed items.
---
function GedExpandNode(obj, parent, format_fn, children_fn, filter_fn, enable_rollover)
	if type(obj) ~= "table" then
		return tostring(obj), 1
	end
	
	local node = GedCreateNode(obj, parent, format_fn, enable_rollover)
	local total_displayed_items = 0
	local children_table = children_fn(obj) or empty_table
	for i = 1, #children_table do
		local item = children_table[i]
		if not IsKindOf(item, "CObject") or IsValid(item) then
			local child_node, displayed_items = GedExpandNode(item, obj, format_fn, children_fn, filter_fn, enable_rollover)
			total_displayed_items = total_displayed_items + displayed_items
			node[#node + 1] = child_node
		end
	end
	node.filtered = filter_fn and not filter_fn(obj) and total_displayed_items == 0 or nil
	return node, total_displayed_items + (node.filtered and 0 or 1)
end

---
--- Generates a tree-like object representation of the given object, with optional filtering and formatting.
---
--- @param obj table The object to generate the tree for.
--- @param filter table An optional filter to apply to the tree.
--- @param format string|table An optional format string or table to use for formatting the object names.
--- @param allow_objects_only boolean Whether to only allow objects in the tree.
--- @param enable_rollover boolean Whether to enable rollover for the nodes.
--- @return table The generated tree-like object representation.
---
function GedObjectTree(obj, filter, format, allow_objects_only, enable_rollover)
	if allow_objects_only and (not GedIsValidObject(obj) or IsKindOf(obj, "GedMultiSelectAdapter")) then
		return {}
	end
	
	if filter then
		filter:PrepareForFiltering()
	end
	
	local format = type(format) == "string" and T{format} or format
	local format_fn   = function(obj) return GedTranslate(format, obj, not "check") end
	local children_fn = function(obj) return obj.GedTreeChildren and obj.GedTreeChildren(obj) or obj end
	local filter_fn   = function(obj) return not filter or filter:FilterObject(obj) end
	local tree, total_displayed_items = GedExpandNode(obj, nil, format_fn, children_fn, filter_fn, enable_rollover)
	
	if filter then
		filter:DoneFiltering(total_displayed_items or 0)
	end
	return tree
end

---
--- Formats an object for display in the Ged (Graphical Editor) interface.
---
--- @param obj any The object to format.
--- @param filter table An optional filter to apply to the object.
--- @param format string The format string to use for formatting the object.
--- @return string The formatted object string.
---
function GedFormatObject(obj, filter, format)
	if type(obj) == "string" then
		return format == "" and obj or format
	end
	if not string.find(format, "<", 1, true) then
		return format
	end
	return GedIsValidObject(obj) and GedTranslate(T{format}, obj, not "check") or ""
end

---
--- Formats an object for display in the Ged (Graphical Editor) interface, with an additional count if the object is a table.
---
--- @param obj any The object to format.
--- @param filter table An optional filter to apply to the object.
--- @param format string The format string to use for formatting the object.
--- @return string The formatted object string, with a count if the object is a table.
---
function GedFormatObjectWithCount(obj, filter, format)
	local str = GedFormatObject(obj, filter, format)
	if type(obj) == "table" then
		str = string.format("%s (%s)", str, #obj)
	end
	return str
end


----- Handling T values for Ged
--
-- Ged is sent the actual T values, always in the { id, text } format (even in Gold Master).
-- This allows Ged to preserve loc IDs of Ts as they are edited.

local function GedToGameT(value)
	return type(value) == "table" and setmetatable(value, TMeta) or value
end

local function GameToGedT(value)
	if type(value) == "userdata" then
		return { TGetID(value), TDevModeGetEnglishText(value, not "deep", "no_assert") }
	elseif type(value) == "table" then
		-- strip T metatables and arguments (they can't pass through sockets and cause an assert); Ged can only show/edit plain Ts
		return table.raw_copy(TStripArgs(value))
	else
		return value -- could be "" or maybe false
	end
end


----- Handling function values for Ged
--
-- The user can abandon editing a function that doesn't compile and can't be saved. In this case:
--  * the last compilable source is in the FuncSource cache - this is what will be saved
--  * the user's uncompilable version is stored aside and is sent to Ged when the prop value is requested

if FirstLoad then
	UncompilableFuncPropsSources = {} -- object -> prop_id -> source code
end

---
--- Compiles a function or expression from the given source code, handling any compilation errors.
---
--- @param compile_func function The function to use for compiling the code (either CompileFunc or CompileExpression).
--- @param source string The source code to compile.
--- @param prop_meta table The metadata for the property being compiled.
--- @param obj any The object that the property belongs to.
--- @return function|nil The compiled function, or nil if there was an error.
---
function GedCompileCode(compile_func, source, prop_meta, obj)
	assert(type(source) == "string" or not source)
	if not source or source:match("^%s*$") then return nil end
	
	local prop_id = prop_meta.id
	local storage = UncompilableFuncPropsSources[obj]
	local fn, err = compile_func(prop_id, eval(prop_meta.params, obj, prop_meta) or "self", source)
	if err then
		storage = storage or {}
		storage[prop_id] = source
		UncompilableFuncPropsSources[obj] = storage
		return obj:GetProperty(prop_id) -- return previous valid function
	end
	if storage then
		storage[prop_id] = nil
	end
	return fn
end

local env
---
--- Converts a value from the Ged UI to the corresponding game value.
---
--- @param value any The value from the Ged UI.
--- @param prop_meta table The metadata for the property being converted.
--- @param object any The object that the property belongs to.
--- @return any The converted game value.
---
function GedToGameValue(value, prop_meta, object)
	local prop_type = eval(prop_meta.editor, object, prop_meta)
	if prop_type == "func" or prop_type == "expression" then
		return GedCompileCode(prop_type == "func" and CompileFunc or CompileExpression, value, prop_meta, object)
	elseif prop_type == "text" and eval(prop_meta.translate, object, prop_meta) then
		return GedToGameT(value)
	elseif prop_type == "T_list" and type(value) == "table" then
		for idx, item in ipairs(value) do
			value[idx] = GedToGameT(item)
		end
		return setmetatable(value, TConcatMeta)
	elseif prop_type == "browse" then
		if value == "" or value == nil then
			return value
		end
		local existence_check_path = value
		local vbar_idx = string.find(existence_check_path, "|")
		if vbar_idx then
			existence_check_path = string.sub(existence_check_path, 1, vbar_idx - 1)
		end
		if io.exists(existence_check_path) then
			return value
		else
			return value, "File does not exist."
		end
	elseif prop_type == "prop_table" then
		env = env or LuaValueEnv{}
		local str = "return " .. (value or "")
		return dostring(str, env) or false
	elseif prop_type == "choice" or prop_type == "combo" or prop_type == "dropdownlist" then
		local items = eval(prop_meta.items, object, prop_meta)
		local translate = eval(prop_meta.translate, object, prop_meta)
		return ComboGetItemIdByName(value, items, object, prop_type == "combo", translate)
	elseif prop_type == "object" then
		return HandleToObject[value and value.handle] or false
	elseif prop_type == "packedcurve" then
		if not value then return value end
		return PackCurveParams(value[1], value[2], value[3], value[4], value.range_y)
	end
	return value
end

---
--- Converts a game value to the corresponding Ged UI value.
---
--- @param value any The game value to be converted.
--- @param prop_meta table The metadata for the property being converted.
--- @param object any The object that the property belongs to.
--- @param items table (optional) The list of items for choice/combo/dropdownlist properties.
--- @return any The converted Ged UI value.
---
function GameToGedValue(value, prop_meta, object, items)
	if rawequal(value, Undefined()) then return value end
	
	local prop_type = eval(prop_meta.editor, object, prop_meta)
	if prop_type == "script" then
		return value and value:GetHumanReadableScript() or (prop_meta.class == "ScriptConditionList" and "empty condition list" or "empty script")
	elseif prop_type == "bool" then
		return value and true
	elseif prop_type == "func" or prop_type == "expression" then
		local storage = UncompilableFuncPropsSources[object]
		if storage and storage[prop_meta.id] then
			return storage[prop_meta.id] -- return last-entered code for uncompilable functions
		end
		
		if type(value) ~= "function" then return false end
		local name, params, body = GetFuncSource(value)
		if type(body) == "table" then
			body = table.concat(body, "\n")
		end
		if prop_type == "expression" and body then
			body = body:match("^%s*(.-)%s*$")
			if body:starts_with("return ") and not body:find("return ", 8, true) then
				body = body:match("^return%s*(.*)")
			end
		end
		return body or ""
	elseif prop_type == "browse" then
		value = value or ""
		value = const.XboxToPlayStationButtons[value] and GetPlatformSpecificImagePath(value) or value
		return value
	elseif prop_type == "prop_table" then
		local indent = eval(prop_meta.indent, object, prop_meta) or " "
		return type(value) == "table" and TableToLuaCode(value, indent) or not value and "" or Undefined()
	elseif prop_type == "choice" or prop_type == "combo" or prop_type == "dropdownlist" then
		items = items or eval(prop_meta.items, object, prop_meta)
		return ComboGetItemNameById(value, items, object, prop_type == "combo")
	elseif prop_type == "image" then
		if type(value) == "string" and value ~= "" then
			if prop_meta.os_path then
				return value
			end
			local os_path, err = ConvertToOSPath(value)
			if not err then
				return os_path
			end
		end
		return ""
	elseif prop_type == "text" and eval(prop_meta.translate, object, prop_meta) then
		return GameToGedT(value)
	elseif prop_type == "T_list" and type(value) == "table" then
		local temp = {}
		for _, item in ipairs(value) do
			temp[#temp + 1] = GameToGedT(item)
		end
		return temp
	elseif prop_type == "object" then
		if value and IsValid(value) and rawget(value, "handle") then
			local formatter = GetObjectPropEditorFormatFunc(prop_meta)
			return { handle = value.handle, text = formatter(value) }
		else
			return false
		end
	elseif prop_type == "objects" then
		return false -- not supported in Ged, but don't try to send it over the network
	elseif prop_type == "grid" then
		if IsGrid(value) then
			local w, h = value:size()
			local size, max_size = Max(w, h), eval(prop_meta.max, object, prop_meta)
			local resample
			if max_size and size > max_size then
				resample = true
				value = GridResample(value, w * max_size / size, h * max_size / size, false)
			end
			local str, err = GridWriteStr(value)
			if not err then
				return resample and { str, w, h } or str
			end
		end
		return ""
	elseif prop_type == "nested_obj" or prop_type == "property_array" then
		if prop_type == "property_array" and value then
			value = GedDynamicProps:Instance(object, value, prop_meta)
		end
		return value and table.hash(value) or false
	elseif prop_type == "nested_list" then
		local addresses = { table_addr = tostring(value) }
		for idx, item in ipairs(value) do
			addresses[idx] = tostring(item)
		end
		return addresses
	elseif prop_type == "packedcurve" then
		local pt1, pt2, pt3, pt4, range_y = UnpackCurveParams(value)
		return { pt1, pt2, pt3, pt4, range_y = range_y }
	elseif prop_type == "curve4" then
		if not value then return value end
		if type(value) == "number" then return false end
		return value
	end
	assert(value == "" or not IsT(value)) -- T values should pass through GedToGameT (maybe a property with translate == false has a T value?)
	return value
end

---
--- Generates a menu of editor items based on a base class and optional filter function.
---
--- @param base_class string The base class to generate the menu for.
--- @param filter_fn function An optional filter function to apply to the class list.
--- @param filter_param any An optional parameter to pass to the filter function.
--- @return table A table of menu items, where each item is a table with the following fields:
---   - Class: The class name
---   - EditorName: The translated editor name of the class
---   - EditorIcon: The editor icon of the class
---   - EditorShortcut: The editor shortcut of the class
---   - EditorSubmenu: The editor submenu of the class
---   - ScriptDomain: The script domain of the class
---   - Documentation: The documentation of the class
function GedItemsMenu(base_class, filter_fn, filter_param)
	local menu = {}
	local classes = ClassLeafDescendantsList(base_class, function(name, class) return not filter_fn or filter_fn(filter_param, class) end)
	if #classes == 0 and base_class and base_class ~= "" then
		classes = { base_class }
	end
	for _, class_name in ipairs(classes) do
		local class = g_Classes[class_name]
		local hasEditorName = class:HasMember("EditorName")
		if not hasEditorName or (class.EditorName or "") ~= "" then
			local name = hasEditorName and GedTranslate(class.EditorName, class, false) or class_name
			menu[#menu + 1] = {
				Class = class_name,
				EditorName = name,
				EditorIcon = rawget(class, "EditorIcon"),
				EditorShortcut = rawget(class, "EditorShortcut"),
				EditorSubmenu = class.EditorSubmenu or "New "..GedTranslate(g_Classes[base_class].EditorName or base_class, nil, false),
				ScriptDomain = rawget(class, "ScriptDomain"),
				Documentation = class.Documentation and string.format("<style GedTitleSmall><center>%s</style><left>\n%s", name, class.Documentation),
			}
		end
	end
	table.sortby_field(menu, "EditorName")
	return menu
end

---
--- Generates a dynamic menu of editor items based on the specified object, filter, class, and path.
---
--- @param obj table The object to generate the menu for.
--- @param filter function An optional filter function to apply to the class list.
--- @param class string The class to generate the menu for.
--- @param path table An optional path of keys to traverse to find the object to generate the menu for.
--- @return table A table of menu items, where each item is a table with the following fields:
---   - Class: The class name
---   - EditorName: The translated editor name of the class
---   - EditorIcon: The editor icon of the class
---   - EditorShortcut: The editor shortcut of the class
---   - EditorSubmenu: The editor submenu of the class
---   - ScriptDomain: The script domain of the class
---   - Documentation: The documentation of the class
function GedDynamicItemsMenu(obj, filter, class, path)
	local parent = (not class or IsKindOf(obj, class)) and obj
	for i, key in ipairs(path or empty_table) do
		obj = obj and rawget(TreeNodeChildren(obj), key)
		if IsKindOf(obj, class) then
			parent = obj
		end
	end
	return IsKindOf(parent, "Container") and parent:EditorItemsMenu()
end

---
--- Executes a member function on the given object if the object has the specified member.
---
--- @param obj table The object to execute the member function on.
--- @param filter function An optional filter function to apply to the member function.
--- @param member string The name of the member function to execute.
--- @param ... any Additional arguments to pass to the member function.
--- @return any The result of executing the member function.
function GedExecMemberFunc(obj, filter, member, ...)
	if obj and obj:HasMember(member) then
		return obj[member](obj, ...)
	end
end

---
--- Generates a warning message for the given object, based on the object's properties and dependencies.
---
--- @param obj table The object to generate the warning for.
--- @param filter function An optional filter function to apply to the warning generation.
--- @return string The warning message, or nil if no warning is generated.
function GedGetWarning(obj, filter)
	if not GedIsValidObject(obj) then return end
	if obj:HasMember("param_bindings") then
		local sockets = GedObjects[obj]
		local parent = #sockets >= 2 and sockets[2]:GetParentOfKind(obj, "Preset") or obj
		for property, param in pairs(obj.param_bindings or empty_table) do
			if not ResolveValue(parent, param) then
				return "Undefined parameter '"..param.."' for property '"..property.."'"
			end
		end
	end
	
	local diag_msg = GetDiagnosticMessage(obj)
	if diag_msg and type(diag_msg) == "table" and type(diag_msg[1]) == "table" then
		return diag_msg[1]
	end
	return diag_msg
end

---
--- Generates the documentation for the given object, including its class name, description, and property documentation.
---
--- @param obj table The object to generate the documentation for.
--- @return string The generated documentation.
---
function GedGetDocumentation(obj)
	if IsKindOfClasses(obj, "ScriptBlock", "FunctionObject") then
		local documentation = GetDocumentation(obj)
		if (documentation or "") == "" then return end
		local docs = { "<style GedTitleSmall><center>" .. obj.class .. "</style><left>"}
		docs[#docs+1] =  "<style GedMultiLine>" .. documentation .. "</style>\n" 
		for _, prop in ipairs(obj:GetProperties()) do
			local name = prop.name or prop.id
			if type(name) ~= "function" and (name ~= "Negate" or obj.HasNegate) then -- filters out ScriptSimpleStatement's Param1/2/3 properties
				if prop.help and prop.help ~= "" then
					docs[#docs + 1] = "<style GedPropertyName>" .. name .. ":</style> <style GedMultiLine>" .. prop.help .. "</style>"
				else
					docs[#docs + 1] = "<style GedPropertyName>" .. name .. "</style>"
				end
			end
		end
		return table.concat(docs, "\n")
	end
	return GetDocumentation(obj)
end

---
--- Generates a documentation link for the given object.
---
--- @param obj table The object to generate the documentation link for.
--- @return string The generated documentation link.
---
function GedGetDocumentationLink(obj)
	return GetDocumentationLink(obj)
end

-- hide/show functions for inline documentation at the place of the editor = "documentation" property (for Presets and Mod Items)
---
--- Hides the documentation for the specified object.
---
--- @param root table The root object.
--- @param obj table The object to hide the documentation for.
--- @param prop_id string The ID of the property.
--- @param ged table The GED instance.
--- @param btn_param table The button parameters.
--- @param idx number The index of the object.
---
function GedHideDocumentation(root, obj, prop_id, ged, btn_param, idx)
	local hidden = LocalStorage.DocumentationHidden or {}
	hidden[obj.class] = true
	LocalStorage.DocumentationHidden = hidden
	SaveLocalStorageDelayed()
	ObjModified(obj)
end

---
--- Shows the documentation for the specified object.
---
--- @param root table The root object.
--- @param obj table The object to show the documentation for.
--- @param prop_id string The ID of the property.
--- @param ged table The GED instance.
--- @param btn_param table The button parameters.
--- @param idx number The index of the object.
---
function GedShowDocumentation(root, obj, prop_id, ged, btn_param, idx)
	local hidden = LocalStorage.DocumentationHidden or {}
	hidden[obj.class] = nil
	LocalStorage.DocumentationHidden = hidden
	SaveLocalStorageDelayed()
	ObjModified(obj)
end

---
--- Checks if the documentation for the specified object is hidden.
---
--- @param obj table The object to check if the documentation is hidden for.
--- @return boolean True if the documentation for the object is hidden, false otherwise.
---
function IsDocumentationHidden(obj)
	return LocalStorage.DocumentationHidden and LocalStorage.DocumentationHidden[obj.class]
end

---
--- Tests an object in the GED (Game Editor).
---
--- @param socket table The socket object.
--- @param obj_name string The name of the object to test.
---
function GedTestFunctionObject(socket, obj_name)
	local obj = socket:ResolveObj(obj_name)
	local subject = obj:HasMember("RequiredObjClasses") and SelectedObj or nil
	obj:TestInGed(subject, socket)
end

---
--- Handles the double-click event on a picker item.
---
--- @param socket table The socket object.
--- @param obj_name string The name of the object.
--- @param prop_id string The ID of the property.
--- @param item_id string The ID of the picked item.
---
function GedPickerItemDoubleClicked(socket, obj_name, prop_id, item_id)
	local obj = socket:ResolveObj(obj_name)
	GedNotify(obj, "OnPickerItemDoubleClicked", prop_id, item_id, socket)
end

--- Handles various events related to the Game Editor (GED) and updates the UI status accordingly.
---
--- @param msg string The message name of the event.
---
function OnMsg.LuaFileChanged()
    --- Reloads Lua files and updates the UI status.
end

--- Initializes the GED and updates the UI status.
function OnMsg.Autorun()
    --- Updates the UI status to indicate that Lua files are being reloaded.
end

--- Handles the change of the current map and updates the UI status.
function OnMsg.ChangeMap()
    --- Updates the UI status to indicate that the map is being changed.
end

--- Handles the completion of the map change and updates the UI status.
function OnMsg.ChangeMapDone()
    --- Updates the UI status to indicate that the map change is complete.
end

--- Handles the pre-save event of the map and updates the UI status.
function OnMsg.PreSaveMap()
    --- Updates the UI status to indicate that the map is being saved.
end

--- Handles the completion of the map save and updates the UI status.
function OnMsg.SaveMapDone()
    --- Updates the UI status to indicate that the map save is complete.
end

--- Handles the data reload event and updates the UI status.
function OnMsg.DataReload()
    --- Updates the UI status to indicate that presets are being reloaded.
end

--- Handles the completion of the data reload and updates the UI status.
function OnMsg.DataReloadDone()
    --- Updates the UI status to indicate that the data reload is complete.
end

--- Handles the validation of presets and updates the UI status.
function OnMsg.ValidatingPresets()
    --- Updates the UI status to indicate that presets are being validated.
end

--- Handles the completion of the preset validation and updates the UI status.
function OnMsg.ValidatingPresetsDone()
    --- Updates the UI status to indicate that the preset validation is complete.
end

--- Handles the debugger break event and updates the UI status.
function OnMsg.DebuggerBreak()
    --- Updates the UI status to indicate that the debugger has paused.
end

--- Handles the debugger continue event and updates the UI status.
function OnMsg.DebuggerContinue()
    --- Updates the UI status to indicate that the debugger has resumed.
end
function OnMsg.LuaFileChanged() GedSetUiStatus("lua_reload", "Reloading Lua...") end -- unable to make remote calls in OnMsg.ReloadLua
--- Handles various events related to the game map and UI status updates.
---
--- @module CommonLua.Ged
--- @field OnMsg.Autorun Handles the autorun event and updates the UI status to indicate that Lua is being reloaded.
--- @field OnMsg.ChangeMap Handles the change of the current map and updates the UI status to indicate that the map is being changed.
--- @field OnMsg.ChangeMapDone Handles the completion of the map change and updates the UI status to indicate that the map change is complete.
--- @field OnMsg.PreSaveMap Handles the pre-save event of the map and updates the UI status to indicate that the map is being saved.
--- @field OnMsg.SaveMapDone Handles the completion of the map save and updates the UI status to indicate that the map save is complete.
--- @field OnMsg.DataReload Handles the data reload event and updates the UI status to indicate that presets are being reloaded.
--- @field OnMsg.DataReloadDone Handles the completion of the data reload and updates the UI status to indicate that the data reload is complete.
--- @field OnMsg.ValidatingPresets Handles the validation of presets and updates the UI status to indicate that presets are being validated.
--- @field OnMsg.ValidatingPresetsDone Handles the completion of the preset validation and updates the UI status to indicate that the preset validation is complete.
--- @field OnMsg.DebuggerBreak Handles the debugger break event and updates the UI status to indicate that the debugger has paused.
--- @field OnMsg.DebuggerContinue Handles the debugger continue event and updates the UI status to indicate that the debugger has resumed.
function OnMsg.Autorun() GedSetUiStatus("lua_reload") end
function OnMsg.ChangeMap() GedSetUiStatus("change_map", "Changing map...") end
function OnMsg.ChangeMapDone() GedSetUiStatus("change_map") end
function OnMsg.PreSaveMap() GedSetUiStatus("save_map", "Saving map...") end
function OnMsg.SaveMapDone() GedSetUiStatus("save_map") end
function OnMsg.DataReload() GedSetUiStatus("data_reload", "Reloading presets...") end
function OnMsg.DataReloadDone() GedSetUiStatus("data_reload") end
function OnMsg.ValidatingPresets() GedSetUiStatus("validating_presets", "Validating presets...") end
function OnMsg.ValidatingPresetsDone() GedSetUiStatus("validating_presets") end
function OnMsg.DebuggerBreak() GedSetUiStatus("pause", "Debugger Break") end
function OnMsg.DebuggerContinue() GedSetUiStatus("pause") end

--- Sets the UI status for all connected GED clients.
---
--- @param id string The unique identifier for the UI status.
--- @param text string The text to display in the UI status.
--- @param delay number (optional) The delay in seconds before the UI status is cleared.
function GedSetUiStatus(id, text, delay)
	for _, socket in pairs(GedConnections or empty_table) do
		socket:SetUiStatus(id, text, delay)
	end
end

--- Handles the application quit event by sending a "rfnGedQuit" message to all connected GED clients.
---
--- This function is called when the application is about to quit. It iterates through all the connected GED clients and sends a "rfnGedQuit" message to each of them, notifying them that the application is quitting.
---
--- @function OnMsg.ApplicationQuit
--- @return nil
function OnMsg.ApplicationQuit()
	for _, socket in pairs(GedConnections or empty_table) do
		socket:Send("rfnGedQuit")
	end
end

----- GedDynamicProps
-- A dummy class to generate the properties of the nested_obj that represents the value of a property_array property

--- A dummy class to generate the properties of the nested_obj that represents the value of a property_array property.
---
--- This class is used to handle the dynamic properties of a nested object that represents the value of a property_array property. It provides methods to manage the properties, such as getting the list of properties, updating the property metadata, and generating Lua code for the object.
---
--- @class GedDynamicProps
--- @field prop_meta table The metadata for the properties of the nested object.
--- @field parent_obj table The parent object of the nested object.
DefineClass.GedDynamicProps = {
	__parents = { "PropertyObject" },
	prop_meta = false,
	parent_obj = false,
}

--- Instantiates a new GedDynamicProps object with the given parent object, value, and property metadata.
---
--- @param parent table The parent object of the GedDynamicProps instance.
--- @param value table The value of the GedDynamicProps instance.
--- @param prop_meta table The property metadata for the GedDynamicProps instance.
--- @return table The new GedDynamicProps instance.
function GedDynamicProps:Instance(parent, value, prop_meta)
	local meta = { prop_meta = prop_meta, parent_obj = parent }
	meta.__index = meta
	setmetatable(meta, self)
	return setmetatable(value, meta)
end

--- Generates Lua code for the GedDynamicProps object.
---
--- This method removes any default values from the properties of the GedDynamicProps object, and then generates Lua code for the object using the TableToLuaCode function.
---
--- @param indent number The indentation level for the generated Lua code.
--- @param pstr string The prefix string to use for the generated Lua code.
--- @return string The generated Lua code for the GedDynamicProps object.
function GedDynamicProps:__toluacode(indent, pstr, ...)
	-- remove default values from the table
	for _, prop_meta in ipairs(self:GetProperties()) do
		if rawget(self, prop_meta.id) == prop_meta.default then
			rawset(self, prop_meta.id, nil)
		end
	end
	return TableToLuaCode(self, indent, pstr)
end

--- Gets the list of properties for the GedDynamicProps object.
---
--- This method retrieves the list of properties for the GedDynamicProps object, based on the property metadata stored in the `prop_meta` field. It handles different types of property sources, such as presets and table fields, and applies any necessary updates to the property metadata.
---
--- @return table The list of property metadata for the GedDynamicProps object.
function GedDynamicProps:GetProperties()
	local props = {}
	local meta = self.prop_meta
	if not meta then
		return props
	end
	local prop_meta = meta.prop_meta
	local idx = 1
	
	local parent_obj = self.parent_obj
	local prop_meta_update = meta.prop_meta_update or empty_func
	if IsKindOf(g_Classes[meta.from], "Preset") then
		ForEachPreset(meta.from, function(preset)
			local prop = table.copy(prop_meta)
			prop.id = preset.id
			prop.index = idx
			prop.preset = preset
			if prop_meta_update then
				prop_meta_update(parent_obj, prop)
			end
			props[idx] = prop
			idx = idx + 1
		end)
		return props
	end
	
	for k, v in sorted_pairs(eval(meta.items, self.parent_obj, meta)) do
		local prop = table.copy(prop_meta)
		prop.id =
			meta.from == "Table keys" and k or 
			meta.from == "Table values" and v or 
			meta.from == "Table field values" and type(v) == "table" and v[meta.field]
		if type(prop.id) == "string" or type(prop.id) == "number" then
			prop.index = idx
			prop.value = v
			if prop_meta_update then
				prop_meta_update(parent_obj, prop)
			end
			props[idx] = prop
			idx = idx + 1
		end
	end
	return props
end

--- Clones the GedDynamicProps object, creating a new instance with the same properties.
---
--- @param class string (optional) The class to use for the new instance. Defaults to the class of the current instance.
--- @param ... any Additional arguments to pass to the new instance constructor.
--- @return GedDynamicProps The cloned GedDynamicProps object.
function GedDynamicProps:Clone(class, ...)
	class = class or self.class
	local obj = g_Classes[class]:new(...)
	setmetatable(obj, getmetatable(self))
	obj:CopyProperties(self)
	return obj
end


----- Support for cached incremental recursive search in property values

if FirstLoad then
	ValueSearchCache = false
	ValueSearchCacheInProgress = false
end

local function populate_texts_cache_simple(obj, value, prop_meta)
	if type(value) == "table" and not IsT(value) then
		for k, v in pairs(value) do
			populate_texts_cache_simple(obj, k, prop_meta)
			populate_texts_cache_simple(obj, v, prop_meta)
		end
		return
	end
	
	local str, _
	if type(value) == "string" and value ~= "" then
		str = value
	elseif type(value) == "number" then
		str = tostring(value) -- TODO: Properly format the number values as Ged would display them?
	elseif type(value) == "function" then
		-- don't search in functions/expressions that are defaults (slow and these matches are of no interest most of the time)
		if value ~= (prop_meta.default or obj:HasMember(prop_meta.id) and obj[prop_meta.id]) then
			_, _, str = GetFuncSource(value)
			str = type(str) == "table" and table.concat(str, "\n") or str
		end
	elseif IsT(value) then
		str = TDevModeGetEnglishText(value, "deep", "no_assert")
	end
	if str and str ~= "" then
		local cache = ValueSearchCache
		table.insert(cache.objs, obj)
		table.insert(cache.texts, string.lower(str))
		table.insert(cache.props, prop_meta.id)
	end
end

local function populate_texts_cache(obj, parent)
	ValueSearchCache.obj_parent[obj] = parent
	
	for _, subobj in ipairs(obj) do
		if type(subobj) == "table" then
			populate_texts_cache(subobj, obj)
		end
	end
	
	if IsKindOf(obj, "PropertyObject") then
		for _, prop_meta in ipairs(obj:GetProperties()) do
			local id, editor = prop_meta.id, prop_meta.editor
			local value = obj:GetProperty(id)
			if editor == "nested_obj" and value then
				populate_texts_cache(value, obj)
			elseif editor == "nested_list" then
				for _, subobj in ipairs(value) do
					populate_texts_cache(subobj, obj)
				end
			else
				populate_texts_cache_simple(obj, value, prop_meta)
			end
		end
	end
end

local function search_in_cache(root, search_text, results)
	local cache = ValueSearchCache
	local old_text = cache.search_text
	local objs, texts, props = cache.objs, cache.texts, cache.props
	cache.search_text = search_text
	
	local match_idxs, i = { n = 0 }, 1
	if not old_text or old_text == search_text or not search_text:starts_with(old_text) then
		for idx, text in ipairs(cache.texts) do
			if string.find(text, search_text, 1, true) then
				match_idxs[i] = idx
				match_idxs.n = i
				i = i + 1
			end
		end
	else -- incremental search
		match_idxs = cache.matches
		local texts = cache.texts
		for i = 1, match_idxs.n do
			local idx = match_idxs[i]
			if idx and not string.find(texts[idx], search_text, 1, true) then
				match_idxs[i] = nil
			end
		end
	end
	cache.matches = match_idxs
	
	local hidden = {}
	for obj in pairs(cache.obj_parent) do
		hidden[tostring(obj)] = true
	end
	
	local objs, parents = cache.objs, cache.obj_parent
	for i = 1, match_idxs.n do
		local idx = match_idxs[i]
		if idx then
			local obj, prop = objs[idx], props[idx]
			local obj_id = tostring(obj)
			local result = results[obj_id] or {}
			if type(result) == "string" then -- there is a match both in an object's property, and its children
				result = { __match = result }
			end
			result[#result + 1] = prop
			
			local parent, obj = parents[obj], obj
			local match_path = { tostring(obj) }
			while parent do
				local parent_id = tostring(parent)
				results[parent_id] = results[parent_id] or tostring(obj)
				hidden[parent_id] = nil
				match_path[#match_path + 1] = parent_id
				obj = parent
				parent = parents[parent]
			end
			
			hidden[obj_id] = nil
			results[obj_id] = result
			results[#results + 1] = { prop = prop, path = table.reverse(match_path) }
		end
	end
	results.hidden = hidden
	return results
end

local function repopulate_cache(obj)
	PauseInfiniteLoopDetection("rfnPopulateSearchValuesCache")
	ValueSearchCache = {
		search_text = false,
		obj_parent = {}, -- obj -> parent
		matches = false, -- indexes in the tables below
		
		-- the following tables have one entry for each property text that was found recursively in 'root'
		objs = {},
		texts = {},
		props = {}, -- prop name where the text was found
	}
	populate_texts_cache(obj)
	ResumeInfiniteLoopDetection("rfnPopulateSearchValuesCache")
end

---
--- Populates the search values cache for the GedGameSocket.
--- This function is called to refresh the search results when the "Refresh" button is pressed.
---
--- @param obj_context table The object context to use for populating the search values cache.
---
function GedGameSocket:rfnPopulateSearchValuesCache(obj_context)
	local root = self:ResolveObj(obj_context)
	if root then
		if ValueSearchCacheInProgress then return end
		ValueSearchCacheInProgress = true
		CreateRealTimeThread(function(obj)
			local success, err = sprocall(repopulate_cache, obj)
			if not success then
				assert(false, err)
			end
			ValueSearchCacheInProgress = false
			Msg("ValueSearchCacheUpdated")
		end, root)
	end
end

---
--- Searches for values in the game object context and returns the search results.
---
--- @param obj_context table The object context to use for the search.
--- @param text string The search text to use.
--- @return table The search results.
---
function GedGameSocket:rfnSearchValues(obj_context, text)
	local root = self:ResolveObj(obj_context)
	if root and text and text ~= "" then
		local results = {}
		PauseInfiniteLoopDetection("rfnSearchValues")
		if ValueSearchCacheInProgress then
			WaitMsg("ValueSearchCacheUpdated")
		elseif text == ValueSearchCache.search_text then
			repopulate_cache(root) -- refresh results button pressed
		end
		search_in_cache(root, text, results)
		ResumeInfiniteLoopDetection("rfnSearchValues")
		return results
	end
end


----- Bookmarks

if FirstLoad then
	g_Bookmarks = {}
end

local function GedSortBookmarks(bookmarks)
	table.sort(bookmarks, function(a, b)
		local id1 = IsKindOf(a, "Preset") and a.id or a[1].group
		local id2 = IsKindOf(b, "Preset") and b.id or b[1].group
		return id1 < id2
	end)
end

-- Rebuild bookmarks from local storage
---
--- Rebuilds the bookmarks for the Ged editor.
---
--- This function is called when the data is loaded or reloaded, and it rebuilds the bookmarks
--- from the local storage. It removes bookmarks for deleted template classes, finds the
--- corresponding presets or groups for the bookmarks, and rebinds the bookmarks object to
--- the UI.
---
--- @param none
--- @return none
---
function RebuildBookmarks()
	if LocalStorage.editor.bookmarks then
		local bookmarks = {}
		local loc_storage_bookmarks = {}
		
		-- Remove previous bookmarks of deleted template classes
		LocalStorage.editor.bookmarks["UnitAnimalTemplate"] = nil
		LocalStorage.editor.bookmarks["InventoryItemTemplate"] = nil

		for class, preset_arr in pairs(LocalStorage.editor.bookmarks) do
			if not bookmarks[class] then
				bookmarks[class] = {}
				loc_storage_bookmarks[class] = {}
			end
		
			for idx, preset_path in ipairs(preset_arr) do
				-- Find preset or group by class and path = { group, id }
				local bookmark = PresetOrGroupByUniquePath(class, preset_path)
				if bookmark then
					table.insert(bookmarks[class], bookmark)
					table.insert(loc_storage_bookmarks[class], preset_path)
				end
			end
			GedSortBookmarks(bookmarks[class])
			
			-- Rebind new bookmarks object and update UI
			GedRebindRoot(g_Bookmarks[class], bookmarks[class], "bookmarks")
		end
		
		g_Bookmarks = bookmarks
		LocalStorage.editor.bookmarks = loc_storage_bookmarks
		
		SaveLocalStorageDelayed()
	else
		LocalStorage.editor.bookmarks = {}
	end
end

OnMsg.DataLoaded = RebuildBookmarks -- After Presets have been loaded initially
OnMsg.DataReloadDone = RebuildBookmarks -- After Presets have been reloaded
	
---
--- This function is called when a property of a Preset object is edited. It updates the corresponding bookmark in the local storage if the Preset is bookmarked.
---
--- @param ged_id number The ID of the GED (Graphical Editor) instance
--- @param object Preset The Preset object that was edited
--- @param prop_id string The ID of the property that was edited, either "Group" or "Id"
--- @param old_value string The old value of the edited property
--- @return none
---
function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if not IsKindOf(object, "Preset") then return end
	if not object.class or not LocalStorage.editor.bookmarks or not LocalStorage.editor.bookmarks[object.class] then return end
	if not table.find(g_Bookmarks[object.class], object) then return end
	
	local old_value_idx
	if prop_id == "Group" then
		old_value_idx = 1
	elseif prop_id == "Id" then
		old_value_idx = 2
	else
		return
	end
	-- Recreate the old path
	local old_path = GetPresetOrGroupUniquePath(object)
	old_path[old_value_idx] = old_value
	
	local change_idx
	for idx, path in ipairs(LocalStorage.editor.bookmarks[object.class]) do
		if path[1] == old_path[1] and path[2] == old_path[2] then
			change_idx = idx
			break
		end
	end
	
	if change_idx then
		-- Replace with the new path
		LocalStorage.editor.bookmarks[object.class][change_idx] = GetPresetOrGroupUniquePath(object)
		
		ObjModified(g_Bookmarks[object.class])
		SaveLocalStorageDelayed()
	end
end

---
--- Binds a list of bookmarked objects to a named socket.
---
--- @param name string The name of the socket to bind the bookmarks to.
--- @param class string The class of the bookmarked objects to bind.
--- @return none
---
function GedGameSocket:rfnBindBookmarks(name, class)
	if not g_Bookmarks[class] then
		g_Bookmarks[class] = {}
		LocalStorage.editor.bookmarks[class] = {}
	end
	
	self:BindObj(name, g_Bookmarks[class])
	table.insert_unique(self.root_names, name)
end

-- can bookmark a preset or a preset group
---
--- Toggles the bookmark state of the specified object.
---
--- @param socket GedGameSocket The socket to use for resolving the object.
--- @param bind_name string The name of the socket to bind the bookmarks to.
--- @param class string The class of the bookmarked objects to bind.
--- @return none
---
function GedToggleBookmark(socket, bind_name, class)
	local bookmark = socket:ResolveObj(bind_name)
	local preset_root = socket:ResolveObj("root")
	if not bookmark or not IsKindOf(bookmark, "Preset") and not table.find(preset_root, bookmark) then
		return
	end
	
	if not GedAddBookmark(bookmark, class) then
		GedRemoveBookmark(bookmark, class)
	end
end

---
--- Adds a bookmark for the specified object.
---
--- @param obj any The object to bookmark.
--- @param class string The class of the bookmarked object.
--- @return boolean True if the bookmark was added, false otherwise.
---
function GedAddBookmark(obj, class)
	local bookmarks = g_Bookmarks[class]
	if not table.find(bookmarks, obj) then
		if not bookmarks then
			bookmarks = {}
			g_Bookmarks[class] = bookmarks
			LocalStorage.editor.bookmarks[class] = {}
		end
		
		local bookmarks_size = #bookmarks
		bookmarks[bookmarks_size + 1] = obj
		GedSortBookmarks(bookmarks)
		ObjModified(bookmarks)
		
		LocalStorage.editor.bookmarks[class][bookmarks_size + 1] = GetPresetOrGroupUniquePath(obj)
		SaveLocalStorageDelayed()
		return true
	end
	return false
end

---
--- Removes a bookmark for the specified object.
---
--- @param obj any The object to remove the bookmark from.
--- @param class string The class of the bookmarked object.
--- @return none
---
function GedRemoveBookmark(obj, class)
	local index = table.find(g_Bookmarks[class], obj)
	if index then
		local removed_path = GetPresetOrGroupUniquePath(g_Bookmarks[class][index])
		
		local stored_bookmarks = LocalStorage.editor.bookmarks[class]
		local idx = table.findfirst(stored_bookmarks, function(idx, path, removed_path)
			return path[1] == removed_path[1] and path[2] == removed_path[2]
		end, removed_path)
		if idx then
			table.remove(stored_bookmarks, idx)
		end
		
		table.remove(g_Bookmarks[class], index)
		ObjModified(g_Bookmarks[class])
		SaveLocalStorageDelayed()
	end
end

---
--- Generates a tree-like representation of bookmarks for the given object.
---
--- @param obj any The object to generate the bookmarks tree for.
--- @param filter function (optional) A function to filter the bookmarks.
--- @param format string|table (optional) A format string or table to format the bookmark names.
--- @return string|table The tree-like representation of the bookmarks.
---
function GedBookmarksTree(obj, filter, format)
	local format = type(format) == "string" and T{format} or format
	local format_fn = function(obj)
		return IsKindOf(obj, "Preset") and GedTranslate(format, obj, not "check") or obj and obj[1] and obj[1].group or "[Invalid bookmark]"
	end
	local children_fn = function(obj)
		return not IsKindOf(obj, "Preset") and obj
	end
	return next(obj) and GedExpandNode(obj, nil, format_fn, children_fn) or "empty tree"
end

---
--- Calculates the total number of warnings and errors for a given preset object.
---
--- @param obj any The preset object to check for warnings and errors.
--- @return number, number, number The total number of warnings and errors, the number of warnings, and the number of errors.
---
function GedPresetWarningsErrors(obj)
	-- find the preset class by the object that's selected (it could be a preset, a preset group, or GedMultiSelectAdapter)
	local preset_class
	if IsKindOf(obj, "Preset") then
		preset_class = obj.class
	elseif IsKindOf(obj, "GedMultiSelectAdapter") then
		preset_class = obj.__objects[1].class
	else -- preset group
		preset_class = obj[1] and obj[1].class
	end
	
	local warnings, errors = 0, 0
	if preset_class then
		ForEachPreset(preset_class, function(preset)
			local msg = DiagnosticMessageCache[preset]
			if msg then
				if msg[#msg] == "warning" then
					warnings = warnings + 1
				else
					errors = errors + 1
				end
			end
		end)
	end
	return warnings + errors, warnings, errors
end

---
--- Calculates the total number of warnings and errors for a given mod object.
---
--- @param obj any The mod object to check for warnings and errors.
--- @return number, number, number The total number of warnings and errors, the number of warnings, and the number of errors.
---
function GedModWarningsErrors(obj)
	local parent = obj
	if not IsKindOf(parent, "ModItem") and not IsKindOf(parent, "ModDef") then parent = GetParentTableOfKind(parent, "ModItem") end
	if IsKindOf(parent, "ModItem") then parent = parent.mod end
	
	local warnings, errors = 0, 0
	local msg = DiagnosticMessageCache[parent]
	if msg then
		if msg[#msg] == "warning" then
			warnings = warnings + 1
		else
			errors = errors + 1
		end
	end
	
	assert(IsKindOf(parent, "ModDef"))
	parent:ForEachModItem(function(item)
		local msg = DiagnosticMessageCache[item]
		if msg then
			if msg[#msg] == "warning" then
				warnings = warnings + 1
			else
				errors = errors + 1
			end
		end
	end)
	return warnings + errors, warnings, errors
end

---
--- Generates a status text string for a given object, including any warnings or errors associated with the object.
---
--- @param obj any The object to generate the status text for.
--- @param filter string|nil A filter to apply to the status text.
--- @param format string|nil A format string to use for the status text.
--- @param warningErrorsFunction function A function to call to get the warning and error counts for the object.
--- @return string The generated status text.
---
function GedGenericStatusText(obj, filter, format, warningErrorsFunction)	
	local status = obj.class and obj:GetProperty("PresetStatusText")
	status = status and status ~= "" and string.format("<style GedHighlight>%s</style>", status) or ""
	
	local total, warnings, errors = warningErrorsFunction(obj)
	if total == 0 then return status end
	
	local texts = {}
	texts[#texts + 1] = errors   > 0 and string.format("<color 255   0 0>%d error%s</color>"  , errors  , errors   == 1 and "" or "s") or nil
	texts[#texts + 1] = warnings > 0 and string.format("<color 255 140 0>%d warning%s</color>", warnings, warnings == 1 and "" or "s") or nil
	return table.concat(texts, ", ") .. "\n" .. status
end

---
--- Generates a status text string for a given preset object, including any warnings or errors associated with the object.
---
--- @param obj any The preset object to generate the status text for.
--- @param filter string|nil A filter to apply to the status text.
--- @param format string|nil A format string to use for the status text.
--- @return string The generated status text.
---
function GedPresetStatusText(obj, filter, format)
	if IsKindOf(obj, "GedMultiSelectAdapter") then
		obj = obj.__objects[1]
	end
	return GedGenericStatusText(obj, filter, format, GedPresetWarningsErrors)
end

---
--- Generates a status text string for a given mod object, including any warnings or errors associated with the object.
---
--- @param obj any The mod object to generate the status text for.
--- @param filter string|nil A filter to apply to the status text.
--- @param format string|nil A format string to use for the status text.
--- @return string The generated status text.
---
function GedModStatusText(obj, filter, format)
	return GedGenericStatusText(obj, filter, format, GedModWarningsErrors)
end

-- Root panel and bookmarks panel set the selection in each other
---
--- Handles the selection of an object in the Ged editor.
---
--- When an object is selected in the Ged editor, this function updates the selection in the bookmarks panel and the root panel to match the selected object.
---
--- @param obj any The object that was selected.
--- @param selected boolean Whether the object was selected or deselected.
--- @param socket table The socket that the selection occurred in.
--- @param panel_context string The context of the panel where the selection occurred ("root" or "bookmarks").
---
function OnMsg.GedOnEditorSelect(obj, selected, socket, panel_context)
	if not selected then return end
	
	if panel_context == "root" then
		local bookmark_idx = table.find(g_Bookmarks[obj.PresetClass or obj.class], obj)
		if bookmark_idx then
			socket:SetSelection("bookmarks", { bookmark_idx }, nil, not "notify")
		end
	elseif panel_context == "bookmarks" then
		local path
		if IsKindOf(obj, "Preset") then
			socket:SetSelection("root", PresetGetPath(obj), nil, not "notify")
		else -- preset group
			local presets = socket:ResolveObj("root")
			local idx = table.find(presets, obj)
			if idx then
				socket:SetSelection("root", { idx }, nil, not "notify")
			end
		end
	end
end


----- Ask everywhere function (pops a message in-game and in all Ged windows)

local function wait_any(functions)
	local thread = CurrentThread()
	local result = false
	
	for key, value in ipairs(functions) do
		CreateRealTimeThread(function()
			local worker_result = table.pack(value())
			if not result then
				result = worker_result
				Wakeup(thread)
			end
		end)
	end
	
	return WaitWakeup() and table.unpack(result)
end

---
--- Displays a message dialog in the game and in all connected Ged editor windows.
---
--- @param title string The title of the message dialog.
--- @param question string The text of the message dialog.
--- @return boolean The result of the user's response (true for "Yes", false for "No").
---
function GedAskEverywhere(title, question)
	local game_question = StdMessageDialog:new({}, terminal.desktop, {
		question = true, title = title, text = question,
		ok_text = "Yes", cancel_text = "No",
	})
	game_question:Open()
	
	local questions = { function() return game_question:Wait() end }
	for id, ged in pairs(GedConnections) do
		if not ged.in_game then
			table.insert(questions, function() return ged:WaitQuestion(title, question, "Yes", "No") end)
		end
	end
	local result = wait_any(questions)
	
	-- close all dialogs
	if game_question.window_state ~= "destroying" then
		game_question:Close(false)
	end
	for id, ged in pairs(GedConnections) do
		if not ged.in_game then
			ged:DeleteQuestion()
		end
	end
	
	return result
end
