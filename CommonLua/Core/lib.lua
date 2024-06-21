--- Basic lua library functions.
---@class WeakMetaTable
--- Metatable for weak-key or weak-value tables.
--- @field __mode string The mode of the weak table, either "k" for weak keys, "v" for weak values, or "kv" for both.
--- @field __name string The name of the metatable.

---@class ImmutableMetaTable
--- Metatable for immutable tables.
--- @field __newindex fun(table: table, key: any, value: any) Throws an error when trying to modify an immutable table.
--- @field __name string The name of the metatable.

---@class EmptyMetaTable
--- Metatable for the empty table.
--- @field __newindex fun(table: table, key: any, value: any) Throws an error when trying to modify the empty table.
--- @field __eq fun(t1: table, t2: table): boolean Compares two empty tables for equality.
--- @field __name string The name of the metatable.
--- @field __metatable table The metatable itself, to prevent it from being changed.

---@type table
--- An empty table with a special metatable that prevents modifications.
empty_table = setmetatable({}, __empty_meta)

---@type fun(): nil
--- An empty function that does nothing.
empty_func = function() end

---@type fun(): boolean
--- A function that always returns true.
return_true = function() return true end

---@type fun(): integer
--- A function that always returns 0.
return_0 = function() return 0 end

---@type fun(): integer
--- A function that always returns 100.
return_100 = function() return 100 end

---@type fun(a: any): any
--- A function that returns its first argument.
return_first = function(a) return a end

---@type fun(a: any, b: any): any
--- A function that returns its second argument.
return_second = function(a, b) return b end

---@type box
--- An empty box object.
empty_box = box()

---@type point
--- A 2D point at (0, 0).
point20 = point(0, 0)

---@type point
--- A 3D point at (0, 0, 0).
point30 = point(0, 0, 0)

---@type point
--- A 3D point representing the positive X axis.
axis_x = point(4096, 0, 0)

---@type point
--- A 3D point representing the positive Y axis.
axis_y = point(0, 4096, 0)

---@type point
--- A 3D point representing the positive Z axis.
axis_z = point(0, 0, 4096)

---@type point
--- A 3D point representing the negative Z axis.
axis_minus_z = point(0, 0, -4096)
if FirstLoad then
	weak_keys_meta = { __mode = "k", __name = "weak_keys_meta" }
	weak_values_meta = { __mode = "v", __name = "weak_values_meta" }
	weak_keyvalues_meta = { __mode = "kv", __name = "weak_keyvalues_meta" }
	immutable_meta = {
		__newindex = function() assert(false, "Trying to modify an immutable table", 1) end,
		__name = "immutable_meta",
	}
	__empty_meta = {
		__newindex = function() assert(false, "Trying to modify the empty table", 1) end,
		__eq = function(t1, t2) return next(t1) == nil and next(t2) == nil end,
		__name = "__empty_meta"
	}
	__empty_meta.__metatable = __empty_meta -- raise an error if the metatable is changed
	empty_table = setmetatable({}, __empty_meta)
	empty_func = function() end
	return_true = function() return true end
	return_0 = function() return 0 end
	return_100 = function() return 100 end
	return_first = function(a) return a end
	return_second = function(a, b) return b end
	empty_box = box()
	point20 = point(0, 0)
	point30 = point(0, 0, 0)
	axis_x = point(4096, 0, 0)
	axis_y = point(0, 4096, 0)
	axis_z = point(0, 0, 4096)
	axis_minus_z = point(0, 0, -4096)
end

---@deprecated
--- A placeholder function that does nothing. This will be removed in the gold master release.
empty_func = function() end
dbg = empty_func -- WILL BE REMOVED IN GOLD MASTER

---@param table table
---Wraps the given table in a read-only table. Attempts to modify the table will result in an assertion error.
---@return table
function readonlytable(table)
	return setmetatable({}, {
		__index = table,
		__newindex = function(table, key, value)
			assert(false, "Trying to modify a read-only table!")
		end,
	})
end

---@class integer
--- Represents the maximum and minimum values for 32-bit and 64-bit integers.
---
--- @field max_int integer The maximum value for a 32-bit integer (2^31 - 1).
--- @field min_int integer The minimum value for a 32-bit integer (-2^31).
--- @field max_int64 integer The maximum value for a 64-bit integer (2^63 - 1).
--- @field min_int64 integer The minimum value for a 64-bit integer (-2^63).
max_int = 2^31 - 1
min_int = -(2^31)
max_int64 = 2^63 - 1
min_int64 = -(2^63)

---@param val any
--- Converts the given value to a string.
---
--- If the value is a function, the function's source file and line number are returned.
--- Otherwise, the standard `tostring()` function is used to convert the value to a string.
---
--- @return string
function tostring(val)
end
local function tostring(val)
	if type(val) == "function" then
		local debug_info = debug.getinfo(val, "Sn")
		return debug_info.short_src .. "(" .. debug_info.linedefined .. ")"
	end
	return _G.tostring(val)
end

---@param sep string
---@param ... any
---@return string
--- Concatenates the given parameters into a string, separated by the given separator.
---
--- If any of the parameters are tables, they will be converted to strings using `tostring()` before concatenation.
---
--- If no parameters are provided, an empty string is returned.
function concat_params(sep, ...)
	local p = pack_params(...)
	if p then
		for i = 1, #p do
			p[i] = tostring(p[i])
		end
		return table.concat(p, sep)
	end
	return ""
end

--- Converts the arguments to a string to be printed in the game console in a convenient way.
-- @cstyle string print_format(...).
---@param ... any
--- Concatenates the given parameters into a string, separated by a space.
---
--- If any of the parameters are tables, they will be converted to strings using `table.format()` before concatenation.
---
--- If no parameters are provided, an empty string is returned.
---
--- @return string
function print_format(...)
	local arg = {...}
	local count = count_params(...)
	if count == 0 then
		return
	end
	for i = count, 1, -1 do
		if arg[i] ~= nil then
			break
		end
		count = count - 1
	end
	if count == 1 and type(arg[1])=="table" then
		return table.format(arg[1], 3, 175)
	end
	for i = 1, count do
		arg[i] = type(arg[i])=="table" and table.format(arg[i], 1, -1) or tostring(arg[i])
	end
	return table.concat(arg, " ")
end

--- Creates a print function to be used locally within a subsystem
--[[
	my_print = CreatePrint{
		"tag",         -- comment out to disable these prints; all prints will be prefixed with [tag]; "" to print, but without tag
		trace = "line", -- "line" for call line or "stack" for entire call stack
		timestamp = "realtime", -- "realtime", "gametime" or "both"
		output = ConsolePrint, -- OutputDebugString, etc.
		format = "printf", -- use printf format for this print
	}
	usage: my_print("message", table, integer, string, ...)
	usage: my_print("once", "message", table, integer, string, ...)
]]--
---@class FirstLoad
---Indicates whether this is the first time the script has been loaded.
---When the script is first loaded, `org_print` is set to the original `print` function,
---and `once_log` is initialized as an empty table to track messages that should only be printed once.
if FirstLoad then
	org_print = print
	once_log = {}
end

---@param s string
--- Outputs the given string to the debug output, and then outputs a newline character.
---
--- This function is a convenience wrapper around `OutputDebugString` that automatically appends a newline character to the output.
---
--- @return nil
function OutputDebugStringNL(s)
end
function OutputDebugStringNL(s) OutputDebugString(s) OutputDebugString("\r\n") end
---Outputs the given string to the debug output, and then outputs a newline character.

---This function is a convenience wrapper around `DebugPrint` that automatically appends a newline character to the output.

---@param s string The string to output to the debug output.
---@return nil
function DebugPrintNL(s)
end
function DebugPrintNL(s) DebugPrint(s) DebugPrint("\r\n") end

---@param options table
--- Creates a print function to be used locally within a subsystem.
---
--- The `options` table can contain the following fields:
---
--- - `tag`: A string to prefix each print message with, or an empty string to disable the tag.
--- - `trace`: The type of trace information to include, either `"line"` for the call line or `"stack"` for the entire call stack.
--- - `timestamp`: The type of timestamp to include, either `"realtime"`, `"gametime"`, `"precise"`, or `"both"` to include both real-time and game-time.
--- - `output`: The function to use for output, such as `ConsolePrint`, `OutputDebugString`, or `DebugPrint`.
--- - `format`: The formatting function to use, either `"printf"` or a custom function.
--- - `append_new_line`: A boolean indicating whether to append a newline character to the output.
--- - `color`: An RGB color value to use for the print message.
---
--- The returned function can be called with either a "once" flag followed by the message and arguments, or just the message and arguments. The "once" flag ensures the message is only printed once.
---@return function
function CreatePrint(options)
	if not options or not options[1] then
		return empty_func
	end
	local tag
	if type(options[1]) == "string" and options[1] ~= "" then
		tag = "[" .. options[1] .. "] "
	else
		tag = ""
	end
	local trace = options.trace
	local timestamp = options.timestamp
	local format = options.format == "printf" and string.format or options.format or print_format
	local output
	if Platform.cmdline then
		output = org_print
	else
		output = options.output or ConsolePrint
		if output == OutputDebugString then
			output = OutputDebugStringNL
		end
		if output == DebugPrint then
			output = DebugPrintNL
		end
	end
	local append_new_line = options.append_new_line
	local color_tag
	if options.color then
		local r, g, b = GetRGB(options.color)
		color_tag = string.format("<color %d %d %d>", r, g, b)
	end
		
	return function(once, ...)
		local s
		if once == "once" then
			s = format(...) or ""
			if once_log[s] then
				return
			else
				once_log[s] = true
			end
		else
			s = format(once, ...) or ""
		end
		if timestamp == "realtime" then
			s = string.format("%srt %8d\t%s", tag, RealTime(), s)
		elseif timestamp == "gametime" then
			s = string.format("%sgt %8d\t%s", tag, GameTime(), s)
		elseif timestamp == "precise" then
			s = string.format("%spt %8d\t%s", tag, GetPreciseTicks(), s)
		elseif timestamp then
			s = string.format("%srt %8d gt %7d\t%s", tag, RealTime(), GameTime(), s)
		else
			s = tag .. s
		end
		if trace == "line" then
			s = s .. "\n\t" .. GetCallLine()
		elseif trace == "stack" then
			s = s .. "\n" .. GetStack(2, false, "\t")
		end
		if color_tag then
			s = color_tag .. s .. "</color>"
		end
		if append_new_line then
			s = s .. "\n"
		end
		return output(s)
	end
end

---
--- Creates a print function that can be customized with various options.
---
--- @param options table
---   - tag: string, a prefix to add to each print
---   - timestamp: string, one of "realtime", "gametime", "precise" or nil to disable timestamps
---   - trace: string, one of "line" or "stack" to add a trace to each print
---   - color: table, an RGB color table to colorize the print
---   - append_new_line: boolean, whether to append a new line to each print
---   - format: function, the format function to use
---
--- @return function
---   - The created print function, which takes the same arguments as string.format
print = CreatePrint{
	"",
	--trace = "stack",
}

---
--- Creates a print function that can be customized with various options.
---
--- @param options table
---   - tag: string, a prefix to add to each print
---   - timestamp: string, one of "realtime", "gametime", "precise" or nil to disable timestamps
---   - trace: string, one of "line" or "stack" to add a trace to each print
---   - color: table, an RGB color table to colorize the print
---   - append_new_line: boolean, whether to append a new line to each print
---   - format: function, the format function to use
---
--- @return function
---   - The created print function, which takes the same arguments as string.format
printf = CreatePrint{
	"",
	--trace = "stack",
	format = string.format,
}

---
--- Prints a formatted debug message.
---
--- @param fmt string
---   The format string, as in `string.format`.
--- @param ... any
---   The arguments to format.
---
--- @return any
---   The result of `DebugPrint(string.format(fmt, ...))`.
function DebugPrintf(fmt, ...)
	return DebugPrint(string.format(fmt, ...))
end

---
--- Parses an error message and extracts the file name, line number, and error text.
---
--- @param err string
---   The error message to parse.
--- @return string|nil
---   The file name, or `nil` if the file name could not be extracted.
--- @return string|nil
---   The line number, or `nil` if the line number could not be extracted.
--- @return string|nil
---   The error text, or `nil` if the error text could not be extracted.
local function parse_error(err)
	local file, line, err = string.match(tostring(err), "(.-%.lua):(%d+): (.*)")
	if file and line and io.exists(file) then
		return file, line, err
	end
end

---
--- Runs when the application starts up.
---
--- This function is called when the application is first loaded and initializes the `LoadingBlacklist` table.
---
--- @function OnMsg.Autorun
--- @return nil
function OnMsg.Autorun()
	LoadingBlacklist = {}
end

--- Protected "silent" versions of 'dofile'. Instead of printing an error, returns ok code followed by error text or execution results.
-- @cstyle void pdofile(filename, fenv, mode).
-- @param filename string; the file name.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @param mode string; controls weather the chuck can be text or binary. Possible values are "b", "t" and "bt".
-- @return ok bool, err text or execution results.
---
--- Executes a Lua file with the given environment and returns the results of the execution. If the file is blacklisted, returns `false` and the string `"Blacklisted"`.
---
--- @param name string
---   The name of the Lua file to execute.
--- @param fenv table
---   The environment to execute the file in. If not provided, the caller's environment is used.
--- @param mode string
---   The mode to use when loading the file. Can be "b" for binary, "t" for text, or "bt" for both.
---
--- @return boolean
---   `true` if the file was executed successfully, `false` otherwise.
--- @return string|any
---   If the execution was successful, the results of the execution. If the execution failed, the error message.
function pdofile(name, fenv, mode)
	if LoadingBlacklist[name] then return false, "Blacklisted" end

	local func, err = loadfile(name, mode, fenv or _ENV)
	if not func then
		return false, err
	end

	return pcall(func)
end

local function procall_helper(ok, ...)
	if not ok then return end
	return ...
end

--- Executes a file and returs the results of the execution. Prints in case of any errors.
-- @cstyle void dofile(filename, fenv).
-- @param filename string; the file name.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @return execution results.
---
--- Executes a Lua file with the given environment and returns the results of the execution. If the file is blacklisted, returns `false` and the string `"Blacklisted"`.
---
--- @param name string
---   The name of the Lua file to execute.
--- @param fenv table
---   The environment to execute the file in. If not provided, the caller's environment is used.
--- @param ... any
---   Additional arguments to pass to the loaded function.
---
--- @return boolean
---   `true` if the file was executed successfully, `false` otherwise.
--- @return string|any
---   If the execution was successful, the results of the execution. If the execution failed, the error message.
function dofile(name, fenv, ...)
	if LoadingBlacklist[name] then return end
	
	local func, err = loadfile(name, nil, fenv or _ENV)
	if not func then
		syntax_error(err, parse_error(err))
		if parse_error(err) and GetIgnoreDebugErrors() then
			syntax_error(string.format("[Compile Error]: Lua compilation error in '%s'!", name))
			FlushLogFile()
			quit(1)
		end
		return
	end

	return procall_helper(procall(func, ...))
end

--- dofolder loads a folder tree of lua files. If there is a "__load.lua" file in a folder then only it is loaded instead of loading all lua files.
-- @cstyle void dofolder(folder, fenv).
-- @param folder string; the folder name.
-- @param fenv string; optional, the envoronment for the code execution.
--- Executes a folder tree of Lua files. If there is a "__load.lua" file in a folder, only that file is loaded instead of loading all Lua files.
---
--- @param folder string
---   The folder name to execute.
--- @param fenv table
---   The environment to execute the files in. If not provided, the caller's environment is used.
--- @param ... any
---   Additional arguments to pass to the loaded functions.
---
--- @return boolean
---   `true` if the folder was executed successfully, `false` otherwise.
--- @return string|any
---   If the execution was successful, the results of the execution. If the execution failed, the error message.
function dofolder(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	-- see if the folder has special init
	local load = folder .. "/__load.lua"
	if io.exists(load) then
		dofile(load, fenv, folder, ...)
		return
	end
	dofolder_files(folder, fenv, ...)
	dofolder_folders(folder, fenv, ...)
end

--- Executes a folder tree of Lua files, excluding any files that match the pattern `.*[/\\]__[^/\\]*$`.
---
--- @param folder string
---   The folder name to execute.
--- @param fenv table
---   The environment to execute the files in. If not provided, the caller's environment is used.
--- @param ... any
---   Additional arguments to pass to the loaded functions.
---
--- @return boolean
---   `true` if the folder was executed successfully, `false` otherwise.
--- @return string|any
---   If the execution was successful, the results of the execution. If the execution failed, the error message.
function dofolder_files(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	local files = io.listfiles(folder, "*.lua", "non recursive")
	table.sort(files, CmpLower)
	for i = 1, #files do
		local file = files[i]
		if not string.match(file, ".*[/\\]__[^/\\]*$") then
			dofile(file, fenv, ...)
		end
	end
end

---
--- Executes a folder tree of Lua files, excluding any folders that match the pattern `.*[/\\]__[^/\\]*$`.
---
--- @param folder string
---   The folder name to execute.
--- @param fenv table
---   The environment to execute the files in. If not provided, the caller's environment is used.
--- @param ... any
---   Additional arguments to pass to the loaded functions.
---
--- @return boolean
---   `true` if the folder was executed successfully, `false` otherwise.
--- @return string|any
---   If the execution was successful, the results of the execution. If the execution failed, the error message.
function dofolder_folders(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	local folders = io.listfiles(folder, "*", "folders")
	table.sort(folders, CmpLower)
	for i = 1, #folders do
		local folder = folders[i]
		if not string.match(folder, ".*[/\\]__[^/\\]*$") then
			dofolder(folder, fenv, ...)
		end
	end
end

--- Executes a string and returs the results of the execution. Prints in case of any errors.
-- @cstyle void dostring(code, fenv).
-- @param code string; the code to execute.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @return execution results.
--- Executes a string and returns the results of the execution. Prints in case of any errors.
---
--- @param text string The code to execute.
--- @param fenv table The execution environment, if not present taken from caller function.
---
--- @return any The execution results.
function dostring(text, fenv)
	local func, err = load(text, nil, nil, fenv or _ENV)
	if not func then
		syntax_error(err, parse_error(err))
		return
	end
	return procall_helper(procall(func))
end

---
--- Loads a configuration file and decrypts it if necessary.
---
--- @param cfg string The path to the configuration file.
--- @param secret string The secret key to decrypt the file, if necessary. Defaults to an empty string.
---
--- @return boolean, string
---   - `true` if the file was loaded successfully, `false` otherwise.
---   - The decrypted file contents, or an error message if loading failed.
function LoadConfig(cfg, secret)
	local err, file = AsyncFileToString(cfg)
	if not err then
		local err, text = OSDecryptData(file, secret or "")
		file = text or file
	end
	pcall(load(file or ""))
end

--- Returns a string description of the function, file name and file line it was called from.
-- @cstyle string getfileline(depth).
-- @param depth type int; the level of the call stack to get information from.
-- @return string.
---
--- Returns a string description of the function, file name and file line it was called from.
---
--- @param depth integer The level of the call stack to get information from.
---
--- @return string A string description of the function, file name and file line it was called from.
function getfileline(depth)
	local info = type(depth) == "function" and debug.getinfo(depth) or debug.getinfo(2 + (depth or 0))
	local file = io.getmetadata(info.short_src, "os_path") or info.short_src
	return info and string.format("%s(%d): %s %s", file, info.currentline or 0, info.namewhat or "", info.name or "<>")
end

---
--- Reloads Lua files, including any DLC files.
---
--- @param dlc boolean|nil Whether to reload DLC files. If not provided, defaults to false.
function ReloadLua(dlc)
	SuspendThreadDebugHook("ReloadLua") -- disable any Lua debug hooks (infinite loop detection, backtracing, Lua debugger)
	local start_time = GetPreciseTicks()
	local ct = CurrentThread()
	ReloadForDlc = dlc or false
	print("Reloading lua files")
	if MountsByLabel("Lua") == 0 and LuaPackfile then
		MountPack("", LuaPackfile, "in_mem,seethrough,label:Lua")
	end
	if MountsByLabel("Data") == 0 and DataPackfile then
		MountPack("Data", DataPackfile, "in_mem,label:Data")
	end
	const.LuaReloads = (const.LuaReloads or 0) + 1
	Msg("ReloadLua")
	collectgarbage("collect")
	dofile("CommonLua/Core/autorun.lua")
	Msg("Autorun")
	Msg("AutorunEnd")
	MsgClear("AutorunEnd")
	printf("Reloading done in %dms", GetPreciseTicks() - start_time)
	ReloadForDlc = false
	if ct then
		InterruptAdvance()
	end
	ResumeThreadDebugHook("ReloadLua")
end

---
--- Resolves a handle to an object.
---
--- @param handle any The handle to resolve.
--- @return table|nil The object associated with the handle, or `nil` if the handle is not found.
function ResolveHandle(handle)
	if not handle then return end
	local obj = HandleToObject[handle]
	if not obj then
		obj = { handle = handle, [true] = false }
		HandleToObject[handle] = obj
	end
	return obj
end

o = ResolveHandle

---
--- Gets the modified properties of an object.
---
--- @param obj table The object to get the modified properties from.
--- @param GetPropFunc function|nil The function to use to get the property value. If not provided, the object's `GetProperty` method will be used.
--- @param ignore_props table|nil A table of property IDs to ignore.
--- @return table|nil A table of modified properties, where the keys are the property IDs and the values are the modified values.
function GetModifiedProperties(obj, GetPropFunc, ignore_props)
	local result
	GetPropFunc = GetPropFunc or obj.GetProperty
	for i, prop in ipairs(obj:GetProperties()) do
		if not prop_eval(prop.dont_save, obj, prop) and prop.editor then
			local id = prop.id
			if not ignore_props or not ignore_props[id] then
				local value = GetPropFunc(obj, id, prop)
				if not obj:IsDefaultPropertyValue(id, prop, value) then
					result = result or {}
					result[id] = value
				end
			end
		end
	end
	return result
end

---
--- Sets the properties of an object from a list of property IDs and values.
---
--- @param obj table The object to set the properties on.
--- @param list table A table of property IDs and values, where the property IDs are at odd indices and the values are at even indices.
---
function SetObjPropertyList(obj, list)
	if obj and list then
		local SetPropFunc = obj.SetProperty
		for i = 1, #list, 2 do
			SetPropFunc(obj, list[i], list[i + 1])
		end
	end
end
SetObjPropertyList = rawget(_G, "SetObjPropertyList") or function(obj, list)
	if obj and list then
		local SetPropFunc = obj.SetProperty
		for i = 1, #list, 2 do
			SetPropFunc(obj, list[i], list[i + 1])
		end
	end
end

---
--- Sets the elements of an object to the values in the given array.
---
--- @param obj table The object to set the array elements on.
--- @param array table The array of values to set on the object.
---
function SetArray(obj, array)
	if obj and array then
		for i = 1, #array do
			rawset(obj, i, array[i])
		end
	end
end
SetArray = rawget(_G, "SetArray") or function(obj, array)
	if obj and array then
		for i = 1, #array do
			rawset(obj, i, array[i])
		end
	end
end

----

---
--- A list of default environment variables used in Lua code.
---
--- @field PlaceObj string
--- @field o string
--- @field point string
--- @field box string
--- @field RGBA string
--- @field RGB string
--- @field RGBRM string
--- @field PackCurveParams string
--- @field T string
--- @field TConcat string
--- @field range string
--- @field set string
---
local env_defaults = {"PlaceObj", "o", "point", "box", "RGBA", "RGB", "RGBRM", "PackCurveParams", "T", "TConcat", "range", "set"}
---
--- Initializes a Lua environment with a set of default environment variables.
---
--- @param env table The environment table to initialize. If not provided, a new table will be created.
--- @return table The initialized environment table.
---
function LuaValueEnv(env)
	env = env or {}
	for _, k in ipairs(env_defaults) do
		if env[k] == nil then
			env[k] = rawget(_G, k)
		end
	end
	return setmetatable(env, {
		__index = function (t, key)
			if key ~= "class" then
				assert(false, string.format("missing '%s' used in lua code", key), 1) 
			end
		end})
end

---
--- Converts a Lua script into game objects and places them in the game world.
---
--- @param script string|function The Lua script to execute, or a function to call.
--- @param params table Optional parameters:
---   - pos: a point representing the center position to place the objects
---   - no_pos_clamp: if true, the object positions will not be clamped to the map bounds
---   - no_z: if true, the z-coordinate of the object positions will be ignored
---   - no_collections: if true, collections will not be placed
---   - handle_provider: a function that provides a handle for each object
---   - collection_index_provider: a function that provides a collection index for each object
---   - ground_offsets: a table of offsets to apply to the object positions based on the terrain
---   - normal_offsets: a table of offsets to apply to the object rotations based on the terrain
---   - exec: a function to execute for each object after it is placed
---   - comment_tag: a string to identify the script, used to validate the script
---   - is_file: if true, the script parameter is a file path instead of a string
--- @return table|boolean, string The list of placed objects, or false and an error message if the script failed to execute.
---
function LuaCodeToObjs(script, params)
	params = params or empty_table
	
	local mapx, mapy = terrain.GetMapSize()
	local pos = params.pos
	local invalid_center = not pos or pos == InvalidPos() or pos:x() < 0 or pos:y() < 0 or pos:x() > mapx or pos:y() > mapy
	local xc, yc, zc = 0, 0, 0
	if not invalid_center then
		xc, yc, zc = pos:xyz()
	end
	
	local HandleToObject = HandleToObject
	local gofPermanent = const.gofPermanent
	local PlaceObj = PlaceObj
	local g_Classes = g_Classes
	local CObject = CObject
	local InvalidZ = const.InvalidZ
	local SetGameFlags = CObject.SetGameFlags
	local GetCollectionIndex = CObject.GetCollectionIndex
	local SetCollectionIndex = CObject.SetCollectionIndex
	local SetPos = CObject.SetPos
	local SetScale = CObject.SetScale
	local SetAngle = CObject.SetAngle
	local SetAxis = CObject.SetAxis
	local CObject_new = CObject.new
	
	local AdjustPos, AdjustPosXY, AdjustPosXYZ
	if params.no_pos_clamp then
		AdjustPosXY = function(x, y)
			return x + xc, y + yc
		end
		AdjustPosXYZ = function(x, y, z)
			return x + xc, y + yc, z and zc and (z + zc) or InvalidZ
		end
	else
		AdjustPosXY = function(x, y)
			return Clamp(x + xc, 0, mapx), Clamp(y + yc, 0, mapy)
		end
		AdjustPosXYZ = function(x, y, z)
			return Clamp(x + xc, 0, mapx), Clamp(y + yc, 0, mapy), z and zc and (z + zc) or InvalidZ
		end
	end
	if params.no_z then
		AdjustPos = function(pt)
			if pt then
				return point(AdjustPosXY(pt:xy()))
			end
		end
	else
		AdjustPos = function(pt)
			if pt then
				return point(AdjustPosXYZ(pt:xyz()))
			end
		end
	end
	
	local exec = params.exec
	local handle_provider = params.handle_provider
	local no_collections = params.no_collections
	local collection_index_provider = params.collection_index_provider
	local ground_offsets = params.ground_offsets
	local normal_offsets = params.normal_offsets
	
	local func, err
	local objs = {}
	local collection_remap = {}
	if type(script) == "string" then
		local comment_tag = params.comment_tag or "--[[HGE place script]]--"
		if not params.is_file and comment_tag ~= "" and not string.starts_with(script, comment_tag) then
			return false, "invalid script"
		end

		local env = {
			SetObjectsCenter = function(center)
				if invalid_center then
					xc, yc, zc = center:xyz()
				end
			end,
			PlaceObj = function (class, values, arr, handle)
				local is_collection = class == "Collection"
				if no_collections and is_collection then
					return
				end
				
				-- handle nested objects properties
				if not g_Classes[class]:IsKindOf("CObject") then
					return PlaceObj(class, values)
				end

				if handle_provider then
					handle = handle_provider(class, values)
				else
					handle = handle and not HandleToObject[handle] and handle
				end
				local col_idx
				if is_collection then
					for i = 1, #values, 2 do
						if values[i] == "Index" then
							col_idx = values[i + 1]
							if collection_index_provider then
								values[i + 1] = collection_index_provider(col_idx)
							end
							break
						end
					end
				else
					for i = 1, #values, 2 do
						if values[i] == "Pos" then
							values[i + 1] = AdjustPos(values[i + 1])
							break
						end
					end
				end
				
				local obj = PlaceObj(class, values, arr, handle)
				if is_collection and col_idx and col_idx ~= 0 then
					collection_remap[col_idx] = obj.Index
				end
				if exec then exec(obj) end
				objs[#objs + 1] = obj
			end,
			PlaceGrass = function(class, x, y, s, a, ox, oy, oz)
				local classdef = g_Classes[class]
				if not classdef then
					assert(false, "No such class: " .. class)
					return
				end
				local obj = CObject_new(classdef)
				x, y = AdjustPosXY(x, y)
				SetPos(obj, x, y, InvalidZ)
				if s then SetScale(obj, s) end
				if a then SetAngle(obj, a) end
				if ox then SetAxis(obj, ox, oy, oz) end
				if exec then exec(obj) end
				objs[#objs + 1] = obj
			end,
			PlaceCObjects = function(data)
				local new_objs = exec and {} or objs
				local err = PlaceAndInitBin(data, point(xc, yc, zc), new_objs, ground_offsets, normal_offsets, params.no_pos_clamp)
				if err then
					assert(false, "Failed to decode object stream " .. comment_tag .. ": " .. err)
					return
				end
				if exec then
					for i=1,#new_objs do
						local obj = new_objs[i]
						exec(obj)
						objs[#objs + 1] = obj
					end
				end
			end,
			o = ResolveHandle,
			point = point,
			box = box,
			LoadGrid = function (data, ...)
				data = data or ""
				local grid, err = LoadGrid(data, ...)
				if not grid and data ~= "" then
					assert(false, err)
				end
				return grid
			end,
			GridReadStr = function (data, ...)
				data = data or ""
				local grid, err = GridReadStr(data, ...)
				if not grid and data ~= "" then
					assert(false, err)
				end
				return grid
			end,
			InvalidPos = InvalidPos,
			RGBA = RGBA,
			RGB = RGB,
			RGBRM = RGBRM,
			T = T,
			range = range,
			set = set,
			PlaceAndInit4 = PlaceAndInit4,
			PlaceAndInit_v2 = PlaceAndInit_v2,
		}
		if params.is_file then
			func, err = loadfile(script, nil, env)
		else
			func, err = load(script, nil, nil, env)
		end
		assert(func, err)
		if not func then
			return false, err
		end
	elseif type(script) == "function" then
		func = script
	else
		return false, "invalid script"
	end

	SuspendPassEdits("LuaCodeToObjs")
	func()
	
	table.validate(objs)
	
	local locked_idx = editor.GetLockedCollectionIdx()
	for i = 1,#objs do
		local obj = objs[i]
		if not handle_provider then
			SetGameFlags(obj, gofPermanent)
		end
		if not no_collections then
			local idx = GetCollectionIndex(obj)
			idx = idx ~= 0 and collection_remap[idx] or locked_idx
			SetCollectionIndex(obj, idx)
		end
		if obj.__ancestors.Object then
			obj:PostLoad("paste")
		end
	end

	UpdateCollectionsEditor()
	ResumePassEdits("LuaCodeToObjs")
	
	return objs
end

---@type function
--- Holds a reference to the empty function.
local empty_func = empty_func
---@param t table
---Iterates over the keys of the given table in sorted order.
---@return fun(t: table, key: any): any, any
---@return table
---@return nil
function sorted_pairs(t)
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func -- the table has no elements
	elseif next(t, first_key) == nil then 
		return pairs(t) -- the table has only one element
	end
	local keys = table.keys(t, true)
	local n = 1
	return function(t, key)
		key = keys[n]
		assert(type(key) ~= "table") --cant sort table keys, it will cause desyncs
		n = n + 1
		if key == nil then return end
		return key, t[key]
	end, t, nil
end

function sorted_handled_obj_key_pairs(t) --note that it traverses only obj keys and skips the rest
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func
	elseif next(t, first_key) == nil then 
		return pairs(t) 
	end
	local handleToVal = {}
	local handleToKey = {}
	local orderT = {}
	local n = 1
	for k, v in pairs(t) do
		if IsKindOf(k, "Object") then
			local h = k.handle
			handleToVal[h] = v
			handleToKey[h] = k
			orderT[n] = h
			n = n + 1
		end
	end
	
	table.sort(orderT, lessthan)
	n = 1
	
	return function(t, key)
		local h = orderT[n]
		n = n + 1
		if h == nil then return end
		return handleToKey[h], handleToVal[h]
	end, t, nil
end

---@brief Stores the original `pairs` function in `g_old_pairs` if the game is in developer mode.
---
---This is used to provide a custom `simple_key_pairs` function that performs additional checks on the table keys.
---
---@param FirstLoad boolean Whether this is the first time the code is loaded.
if FirstLoad then
	g_old_pairs = pairs
end
---@brief Iterates over the keys and values of a table in a random order.
---
---This function is similar to the standard `pairs()` function, but it returns the keys and values in a random order.
---
---@param t table The table to iterate over.
---@return function The iterator function.
---@return table The table being iterated over.
---@return nil The initial state of the iterator.
function totally_async_pairs(t)
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func -- the table has no elements
	elseif next(t, first_key) == nil then 
		return g_old_pairs(t) -- the table has only one element
	end
	local keys = table.keys(t)
	local rand_idx = AsyncRand(#keys - 1) + 1
	keys[1], keys[rand_idx] = keys[rand_idx], keys[1]
	local n = 1
	return function(t, key)
		key = keys[n]
		n = n + 1
		if key == nil then return end
		return key, t[key]
	end, t, nil
end
---@brief Provides a custom `simple_key_pairs` function that performs additional checks on the table keys.
---
---This function is used when the game is in developer mode. It iterates over the keys and values of a table, ensuring that all keys are either numbers or booleans.
---
---@param t table The table to iterate over.
---@return function The iterator function.
---@return table The table being iterated over.
---@return nil The initial state of the iterator.

if Platform.developer then
function simple_key_pairs(t)
		for key in g_old_pairs(t) do
			local tkey = type(key)
			assert(tkey == "number" or tkey == "boolean")
		end
	return g_old_pairs(t)
end
else
	simple_key_pairs = pairs
end


----- random array iterator

local large_primes = { -- using different primes improves somewhat the possible permutations received
	2000000011, 2000025539, 2000049899, 2000074933, 2000092243, 2000130467, 2000193983, 2000233049, 2000258899, 2000323693, 
	2000398357, 2000424479, 2000449897, 2000493491, 2000541203, 2000553461, 2000574853, 2000610511, 2000685233, 2000699957,
	2000776051, 2000802673, 2000854319, 2000892217, 
}
-- if seed is string it is used as an InteractionRand() parameter
-- if seed is nil or false then AsyncRand() is used
---@brief Provides a custom `random_ipairs` function that iterates over the items in a list in a random(ish) order.
---
---This function is used to iterate over a list in a random order, using a provided seed value to ensure the order is consistent across multiple iterations. If the seed is a string, it is used as a parameter to `InteractionRand()` to generate the random order. If the seed is `nil` or `false`, `AsyncRand()` is used instead.
---
---@param list table The list to iterate over.
---@param seed string|nil The seed value to use for the random order.
---@return function The iterator function.
---@return table The list being iterated over.
---@return number The initial index of the iterator.
function random_ipairs(list, seed) -- iterates over list items in random(ish) order
	if not list or #list < 2 then
		return ipairs(list)
	end
	if type(seed) == "string" then seed = InteractionRand(#list * #large_primes, seed) end
	seed = abs(seed or AsyncRand(#list * #large_primes))
	local last
	local large_prime = large_primes[1 + (seed / #list) % #large_primes]
	return function(list, index)
		index = 1 + (index - 1 + large_prime) % #list
		if index == last then return end
		last = last or index
		return index, list[index]
	end, list, seed % #list + 1
end

-- if seed is string it is used as an InteractionRand() parameter
-- if seed is nil or false then AsyncRand() is used
---@brief Provides a custom `random_index` function that returns a sequence of random(ish) indices within the range `[0, max - 1]`.
---
---This function is used to generate a sequence of random indices within a specified range. If the `seed` parameter is a string, it is used as a parameter to `InteractionRand()` to generate the random order. If the `seed` parameter is `nil` or `false`, `AsyncRand()` is used instead.
---
---@param max number The maximum value of the indices to generate (inclusive).
---@param seed string|nil The seed value to use for the random order.
---@return function The iterator function.
---@return number The maximum value of the indices.
---@return number The initial index of the iterator.
function random_index(max, seed) -- returns values from [0 .. max - 1] in random(ish) order
	if (max or 0) < 1 then 
		return empty_func
	end
	if type(seed) == "string" then seed = InteractionRand(max * #large_primes, seed) end
	seed = abs(seed or AsyncRand(max * #large_primes))
	local last
	local large_prime = large_primes[1 + (seed / max) % #large_primes]
	return function(max, index)
		index = (index + large_prime) % max
		if index == last then return end
		last = last or index
		return index
	end, max, seed % max
end


--- Makes certain fields in a table refer to engine exported variables (LuaVars)
-- The values of all matching fields are set to the corresponding engine exported variable (LuaVar)
-- Any further read/writes to matching fields are redirected to LuaVar get/set calls
-- @cstyle void SetupVarTable(table table, string prefix).
-- @param table - the table to be modified; modifies metatable.
-- @param prefix - a prefix used to match engine exported vars (LuaVars) to table fields - a field matches when <engine var> == <prefix><field>

---@brief Makes certain fields in a table refer to engine exported variables (LuaVars).
---
---The values of all matching fields are set to the corresponding engine exported variable (LuaVar).
---Any further read/writes to matching fields are redirected to LuaVar get/set calls.
---
---@param table table The table to be modified; modifies metatable.
---@param prefix string A prefix used to match engine exported vars (LuaVars) to table fields - a field matches when <engine var> == <prefix><field>.
function SetupVarTable(table, prefix)
	if FirstLoad and getmetatable(table) then
		error("SetupVarTable requires a table without a metatable", 1)
		return
	end
	
	setmetatable(table, nil)

	local vars = {}
	for key, value in pairs(EnumEngineVars(prefix)) do
		vars[key] = true
		local new_value = table[key]
		if new_value == nil then
			local subtable_key = string.match(key, "(%w*)%.")
			local subtable = subtable_key and table[subtable_key]
			if subtable_key and not (subtable and getmetatable(subtable)) then
				subtable = subtable or {}
				SetupVarTable(subtable, prefix .. subtable_key .. ".")
				table[subtable_key] = subtable
			end
		elseif new_value ~= nil and new_value ~= value then
			SetEngineVar(prefix, key, new_value)
		end
		table[key] = nil
	end

	local meta = {
		__index = function (table, key)
			if vars[key] then
				return GetEngineVar(prefix, key)
			end
		end,

		__newindex_locked = function (table, key, value)
			if vars[key] then
				SetEngineVar(prefix, key, value)
			else
				error("Trying to create new value " .. prefix .. key, 1)
			end
		end,

		__newindex_unlocked = function (table, key, value)
			if vars[key] then
				SetEngineVar(prefix, key, value)
			else
				rawset(table, key, value)
			end
		end,

		__enum = function(table)
			local bVars = true
			return function(table, key)
				if bVars then
					key = next(vars, key)
					if key ~= nil then
						return key, GetEngineVar(prefix, key)
					end
					bVars = false
				end
				return next(table, key)
			end,
			table,
			nil
		end,
	}
	meta.__newindex = meta.__newindex_unlocked
	setmetatable(table, meta)
	
	return vars
end

---
--- Sets the lock state of the metatable for the given table.
---
--- When the table is locked, attempts to create new keys will result in an error.
--- When the table is unlocked, attempts to create new keys will add them to the table.
---
--- @param table table The table to set the lock state for.
--- @param bLock boolean True to lock the table, false to unlock it.
---
function SetVarTableLock(table, bLock)
	local meta = getmetatable(table)
	meta.__newindex = bLock and meta.__newindex_locked or meta.__newindex_unlocked
end

---
--- Executes a function in parallel across an array of items.
---
--- @param array table The array of items to process in parallel.
--- @param func function The function to execute on each item in the array.
--- @param timeout number (optional) The maximum time in seconds to wait for the parallel execution to complete.
--- @param threads number (optional) The number of threads to use for the parallel execution. Defaults to the number of processors.
---
--- @return string|nil The error message if any of the parallel executions failed, or "timeout" if the parallel execution timed out.
---
function parallel_foreach(array, func, timeout, threads)
	local thread = CurrentThread()
	assert(thread)
	if not array or not thread or not func then return "bad params" end
	if #array == 0 then return end
	threads = threads or tonumber(os.getenv("NUMBER_OF_PROCESSORS"))
	threads = Min(threads or #array, #array)
	local err
	local counter = 1
	local items = #array

	local function worker()
		while not err and counter <= items do
			local idx = counter
			counter = counter + 1
			err = err or func(array[idx], idx)
		end
		threads = threads - 1
		if threads == 0 then
			Wakeup(thread)
		end
	end

	for i = 1, threads do
		CreateRealTimeThread(worker)
	end

	if WaitWakeup(timeout) then
		return err
	end
	-- in case of a timeout stop threads from making additional calls
	counter = items + 1
	threads = -1
	return "timeout"
end

---
--- Converts a file path from an OS-specific format to a forward-slash separated format, relative to a base folder.
---
--- @param path string The full file path to convert.
--- @param base_folder string The base folder to use for the conversion.
--- @return string The converted file path, relative to the base folder and using forward slashes.
---
function ConvertFromOSPath(path, base_folder)
	-- find a suffix of path which starts with base_folder; preserves case; flips slashes to forward
	-- e.g. ConvertFromOSPath("C:\\Src\\GangsAssets\\source\\Textures\\Particles\\pesho.tga", "Textures") -> "Textures/Particles/pesho.tga"
	if not base_folder then return path end
	if not string.ends_with(base_folder, "/") and not string.ends_with(base_folder, "\\")  then
		base_folder = base_folder .. "/"
	end
	base_folder = string.gsub(base_folder, "/", "\\")
	
	local re = string.format(".*\\%s(.*)$", string.lower(base_folder))
	local filename = string.match(string.lower(path):gsub("/", "\\"), re)
	if filename then
		return string.gsub(base_folder .. string.sub(path, -#filename), "\\", "/")
	end
	return path
end

-- MapVars (persistable, reset at map change)

---
--- Stores a list of map variable names.
---
--- This global variable holds a list of the names of all map variables defined using the `MapVar()` function.
---
--- @field MapVars table A table containing the names of all map variables.
---
MapVars = {}
---
--- A table that stores the values of map variables defined using the `MapVar()` function.
---
--- This table holds the initial values of all map variables. When a new map is loaded, the values in this table are used to initialize the global variables with the same names.
---
--- @field MapVarValues table A table that maps map variable names to their initial values.
---
MapVarValues = {}

---
--- Defines a map variable that persists across map changes.
---
--- Map variables are global variables that are initialized when a new map is loaded, and their values are persisted across map changes. This function sets up the necessary infrastructure to manage map variables.
---
--- @param name string The name of the map variable.
--- @param value any The initial value of the map variable. If the value is a table, it will be deep-copied when the map variable is initialized.
--- @param meta table (optional) The metatable to apply to the map variable if it is a table.
---
function MapVar(name, value, meta)
	if type(value) == "table" then
		local org_value = value
		value = function()
			local v = table.copy(org_value, false)
			setmetatable(v, getmetatable(org_value) or meta)
			return v
		end
	end
	if FirstLoad or rawget(_G, name) == nil then
		rawset(_G, name, false)
	end
	assert(not table.find(MapVars, name))
	MapVars[#MapVars + 1] = name
	MapVarValues[name] = value or false
	PersistableGlobals[name] = true
end

---
--- Initializes all map variables when a new map is loaded.
---
--- This function is called when a new map is loaded. It iterates through all the map variables defined using the `MapVar()` function, and initializes their values from the `MapVarValues` table. If the value is a function, it is called to get the initial value.
---
--- @function OnMsg.NewMap
function OnMsg.NewMap()
	for _, name in ipairs(MapVars) do
		local value = MapVarValues[name]
		if type(value) == "function" then
			value = value()
		end
		_G[name] = value or false
	end
end

---
--- Initializes map variables that were not persisted when a new map was loaded.
---
--- This function is called after a new map is loaded. It iterates through all the map variables defined using the `MapVar()` function, and initializes the values of any variables that were not persisted from the previous map. If the value is a function, it is called to get the initial value.
---
--- @param data table The table of persisted data from the previous map.
---
function OnMsg.PersistPostLoad(data)
	for _, name in ipairs(MapVars) do
		if data[name] == nil then
			local value = MapVarValues[name]
			if type(value) == "function" then
				value = value()
			end
			_G[name] = value or false
		end
	end
end

---
--- Hooks the handler for the `OnMsg.Autorun` event, which is called after all other initialization is complete.
---
--- This function is used to register a handler for the `OnMsg.Autorun` event, which is triggered after all other initialization is complete. This allows you to perform any additional setup or initialization tasks that depend on the system being fully initialized.
---
--- @function OnMsg.Autorun
function OnMsg.Autorun() -- hook the handler below after everything else
---
--- Resets all map variables to false when a new map is loaded.
---
--- This function is called after a new map is loaded. It iterates through all the map variables defined using the `MapVar()` function, and sets their values to `false`.
---
function OnMsg.PostDoneMap()
	for _, name in ipairs(MapVars) do
		_G[name] = false
	end
end
end

---
--- Loads the log file and returns the contents as a table or a string.
---
--- This function reads the contents of the log file, optionally limiting the number of lines returned, and returns the contents either as a table of lines or as a single string.
---
--- @param max_lines number (optional) The maximum number of lines to return from the log file.
--- @param as_table boolean (optional) If true, the function will return the log file contents as a table of lines. If false or not provided, the function will return the contents as a single string.
--- @return table|string The contents of the log file, either as a table of lines or as a single string.
--- @return string The first line in the log file that contains an error message, or nil if no error messages were found.
function LoadLogfile(max_lines, as_table)
	FlushLogFile()
	local f, err = io.open(GetLogFile(), "r")
	if not f then
		return err
	end

	local lines = {}
	local first_err = false
	for line in f:lines() do
		lines[#lines + 1] = line
		if max_lines and #lines > max_lines then
			table.remove(lines, 1)
		end
		if not first_err and (string.find(line, "Error%]") or string.find(line, "%[Console%]")) then
			first_err = line
		end
	end
	f:close()
	return as_table and lines or table.concat(lines, "\n"), first_err
end

---
--- Creates a function that generates random numbers using a braid random number generator.
---
--- The `BraidRandomCreate` function creates a new function that can be used to generate random numbers using a braid random number generator. The braid random number generator is a type of random number generator that produces a sequence of numbers that appear to be random, but are actually deterministic based on an initial seed value.
---
--- The created function takes a variable number of arguments, which are used to generate the initial seed value for the random number generator. The seed value is then used to generate a sequence of random numbers, which can be retrieved by calling the created function.
---
--- @param ... any The arguments used to generate the initial seed value for the random number generator.
--- @return function The created function that can be used to generate random numbers.
function BraidRandomCreate(...)
	local seed, _ = xxhash(...)
	_, seed = BraidRandom(seed)
	_, seed = BraidRandom(seed)
	return function (...)
		local rand
		rand, seed = BraidRandom(seed, ...)
		return rand
	end
end

---
--- Generates a random 3D point within a specified bounding box.
---
--- @param ampx number The maximum absolute value for the x-coordinate of the point.
--- @param ampy number The maximum absolute value for the y-coordinate of the point. If not provided, defaults to `ampx`.
--- @param ampz number The maximum absolute value for the z-coordinate of the point. If not provided, defaults to `ampx`.
--- @param seed any The seed value used to initialize the random number generator. If not provided, a random seed value is used.
--- @return point The generated random 3D point.
function RandPoint(ampx, ampy, ampz, seed)
	ampy = ampy or ampx
	ampz = ampz or ampx
	seed = seed or AsyncRand()
	local x, y, z
	x, seed = BraidRandom(seed, -ampx, ampx)
	y, seed = BraidRandom(seed, -ampy, ampy)
	z, seed = BraidRandom(seed, -ampz, ampz)
	return point(x, y, z) 
end

---
--- A thread that keeps references to objects that need to be rendered.
---
--- This thread is responsible for managing the lifetime of objects that need to be kept in memory for rendering purposes. It listens for the "OnRender" message and calls the free handler for any objects that are no longer needed.
---
--- @field keep_ref_thread thread The thread that manages the lifetime of objects that need to be kept in memory for rendering.
local keep_ref_thread
---
--- A table that keeps references to objects that need to be rendered.
---
--- This table is used by the `KeepRefForRendering` function to store references to objects that need to be kept in memory for rendering purposes. The `OnRender` message is used to trigger the release of these objects when they are no longer needed.
---
local keep_ref_objects

---
--- Keeps a reference to an object that needs to be rendered, and provides a free handler to be called when the object is no longer needed.
---
--- This function is used to manage the lifetime of objects that need to be kept in memory for rendering purposes. It adds the object to a table that is monitored by a separate thread, which will call the provided free handler when the object is no longer needed.
---
--- @param obj any The object to be kept in memory for rendering.
--- @param free_handler function The function to be called when the object is no longer needed.
function KeepRefForRendering(obj, free_handler)
	if not keep_ref_thread then
		keep_ref_thread = CreateRealTimeThread(function()
			local f1, f2, f3
			repeat
				WaitMsg("OnRender")
				for i=1,#(f1 or "") do
					local handler = type(f1[i]) == "table" and rawget(f1[i], "__free_handler")
					if handler then
						handler(f1[i].__obj)
					end
				end
				f1, f2, f3 = f2, f3, keep_ref_objects
				keep_ref_objects = nil
			until not (f1 or f2 or f3)
			keep_ref_thread = false
		end)
	end
	if free_handler then
		obj = { __obj = obj, __free_handler = free_handler }
	end
	if keep_ref_objects then
		keep_ref_objects[#keep_ref_objects + 1] = obj
	else
		keep_ref_objects  = {obj}
	end
end

----

---
--- Initializes the `g_ReleaseNextFrame` table with two empty sub-tables.
---
--- This code is executed when the module is first loaded. It creates a table `g_ReleaseNextFrame` with two empty sub-tables, `[1]` and `[2]`. This table is used to keep track of objects that need to be released on the next frame.
---
if FirstLoad then
	g_ReleaseNextFrame = { [1] = {} , [2] = {} }
end
---
--- Holds references to objects that need to be released on the next frame.
---
--- This table is used to keep track of objects that need to be released on the next frame. It consists of two sub-tables, `[1]` and `[2]`, which are used to alternate between frames. This allows objects to be released without causing issues with the rendering loop.
---
local g_ReleaseNextFrame = g_ReleaseNextFrame

---
--- This function is called on each frame render. It swaps the two tables in `g_ReleaseNextFrame` and clears the second table, effectively releasing any objects that were added to the first table.
---
--- This function is likely called as part of the game's rendering loop, and is responsible for managing the release of objects that were kept in memory for rendering purposes. By alternating between the two tables in `g_ReleaseNextFrame`, it ensures that objects can be released without causing issues with the rendering loop.
---
--- @function OnMsg.OnRender
--- @return nil
function OnMsg.OnRender()
	if #g_ReleaseNextFrame[1] == 0 and #g_ReleaseNextFrame[2] == 0 then return end
	
	g_ReleaseNextFrame[1] = g_ReleaseNextFrame[2]
	g_ReleaseNextFrame[2] = {}
end

---
--- Adds the given object to the `g_ReleaseNextFrame` table, which is used to track objects that need to be released on the next frame.
---
--- This function is used to ensure that an object is properly released at the end of the current frame, without causing issues with the rendering loop. By adding the object to the `g_ReleaseNextFrame` table, it will be released on the next frame, when the `OnMsg.OnRender()` function is called.
---
--- @param obj any The object to be added to the `g_ReleaseNextFrame` table.
--- @return nil
function KeepRefOneFrame(obj)
	if obj then
		table.insert(g_ReleaseNextFrame[#g_ReleaseNextFrame], obj)
	end
end

----

---
--- Creates a new table with a custom metatable that delegates all `__newindex` and `__call` operations to the provided `func`.
---
--- This function is useful for creating a table that acts as a proxy for a function, allowing the function to be called using table syntax. The returned table can be used as a drop-in replacement for the original function, with the added benefit of being able to set and get values on the table, which will be passed to the underlying function.
---
--- @param func function The function to be proxied by the returned table.
--- @return table A new table with a custom metatable that delegates to the provided `func`.
function SetupFuncCallTable(func)
	local table = {}
	setmetatable(table, {
		__newindex = function (table, key, value)
			return func(key, value)
		end,
		__call = function (table, ...)
			return func(...)
		end,
	})
	return table
end

---
--- Recursively deletes all files and folders under the specified path.
---
--- This function first checks if the given `path` is empty, `./`, or `../`. If so, it returns an error message.
---
--- It then recursively lists all files under the `path` and deletes them using `AsyncFileDelete()`. After that, it recursively lists all folders under the `path`, sorts them in reverse order, and deletes them using `AsyncFileDelete()`.
---
--- @param path string The path to be deleted.
--- @return string|nil An error message if the deletion fails, or `nil` if the deletion is successful.
--- @return number The number of files deleted.
--- @return number The number of folders deleted.
function AsyncEmptyPath(path)
	if (path or "") == "" or path == "./" or path == "../" then return "Cannot delete path " .. tostring(path) end
	local err, files = AsyncListFiles(path, "*", "recursive")
	if err then return err end
	if #files > 0 then
		err = AsyncFileDelete(files)
		if err then return err end
	end
	local err, folders = AsyncListFiles(path, "*", "recursive,folders")
	if err then return err end
	if #folders > 0 then
		table.sort(folders) -- so we can be sure to delete subfolders before root folders
		table.reverse(folders)
		err = AsyncFileDelete(folders)
		if err then return err end
	end
	return nil, #files, #folders
end

---
--- Recursively deletes a file or directory at the specified path.
---
--- This function first calls `AsyncEmptyPath()` to recursively delete all files and folders under the specified `path`. If that operation is successful, it then calls `AsyncFileDelete()` to delete the path itself.
---
--- @param path string The path to be deleted.
--- @return string|nil An error message if the deletion fails, or `nil` if the deletion is successful.
function AsyncDeletePath(path)
	local err = AsyncEmptyPath(path)
	if err then return err end
	return AsyncFileDelete(path)
end


-- SVN stub
---
--- Deletes a file from the SVN repository.
---
--- This function is a stub and does not currently implement any functionality. It is intended to be used to delete a file from an SVN repository, but the implementation is not provided.
---
--- @param path string The path of the file to be deleted.
--- @return boolean true if the file was successfully deleted, false otherwise.
function SVNDeleteFile(path)
end
function SVNDeleteFile() end
---
--- Adds a file to the SVN repository.
---
--- This function is a stub and does not currently implement any functionality. It is intended to be used to add a file to an SVN repository, but the implementation is not provided.
---
--- @param path string The path of the file to be added.
--- @return boolean true if the file was successfully added, false otherwise.
function SVNAddFile(path)
end
function SVNAddFile() end
---
--- Moves a file in the SVN repository.
---
--- This function is a stub and does not currently implement any functionality. It is intended to be used to move a file in an SVN repository, but the implementation is not provided.
---
--- @param path string The path of the file to be moved.
--- @return boolean true if the file was successfully moved, false otherwise.
function SVNMoveFile(path)
end
function SVNMoveFile() end
---
--- This function is a stub and does not currently implement any functionality. It is intended to be used to check if a file exists in an SVN repository, but the implementation is not provided.
---
--- @param path string The path of the file to check.
--- @return boolean true if the file exists, false otherwise.
function SVNExistFile(path)
end
function SVNExistFile() end

---
--- Shows the SVN log for the specified path.
---
--- This function creates a real-time thread to execute the TortoiseProc command to display the SVN log for the specified path. The path is converted to an OS-specific path before being passed to the command.
---
--- @param path string The path to show the SVN log for.
---
function SVNShowLog(path)
	CreateRealTimeThread(function()
		AsyncExec(string.format('TortoiseProc /command:log /notempfile /closeonend /path:"%s"', ConvertToOSPath(path)))
	end)
end

---
--- Shows the SVN blame for the specified path.
---
--- This function creates a real-time thread to execute the TortoiseProc command to display the SVN blame for the specified path. The path is converted to an OS-specific path before being passed to the command. The blame is shown starting from revision 1 up to the current revision.
---
--- @param path string The path to show the SVN blame for.
---
function SVNShowBlame(path)
	local path = ConvertToOSPath(path)
	local rev = LuaRevision
	local cmd = string.format('TortoiseProc /command:blame /notempfile /closeonend /ignoreeol /ignoreallspaces /startrev:1 /endrev:%d /path:"%s"', rev, path)
	AsyncExec(cmd)
end

---
--- Shows the SVN diff for the specified path.
---
--- This function creates a real-time thread to execute the TortoiseProc command to display the SVN diff for the specified path. The path is converted to an OS-specific path before being passed to the command.
---
--- @param path string The path to show the SVN diff for.
---
function SVNShowDiff(path)
	local path = ConvertToOSPath(path)
	local cmd = string.format('TortoiseProc /command:diff /notempfile /closeonend /path:"%s"', path)
	AsyncExec(cmd)
end

---
--- A table of values extracted from the output of the `svn info` command.
--- The table contains the following keys:
---
--- - `localPath`: The working copy root path.
--- - `branch`: The URL of the branch.
--- - `relative_url`: The relative URL.
--- - `root`: The repository root.
--- - `revision`: The revision number.
--- - `kind`: The node kind.
--- - `depth`: The depth (default is "infinity").
--- - `author`: The last changed author.
--- - `last_revision`: The last changed revision.
--- - `date`: The last changed date.
--- - `text_date`: The last text update date.
--- - `checksum`: The checksum.
---
local ExtractedSvnInfoValues = {
	{ key = "localPath", re = "Working Copy Root Path: (.-)\n"},
	{ key = "branch", re = "URL: (.-)\n"},
	{ key = "relative_url", re = "Relative URL: (.-)\n"},
	{ key = "root", re = "Repository Root: (.-)\n"},
	{ key = "revision", re = "Revision: (%d+)", number = true},
	{ key = "kind", re = "Node Kind: (%w+)"},
	{ key = "depth", re = "Depth: (%w+)", default = "infinity" },
	{ key = "author", re = "Last Changed Author: (%w+)"},
	{ key = "last_revision", re = "Last Changed Rev: (%d+)", number = true},
	{ key = "date", re = "Last Changed Date: (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)"},
	{ key = "text_date", re = "Text Last Updated: (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)"},
	{ key = "checksum", re = "Checksum: (%w+)"}
}

---
--- A cache for storing the results of the `GetSvnInfo` function.
---
--- This cache is used to avoid repeatedly executing the `svn info` command for the same target. The results of the `GetSvnInfo` function are stored in this cache, keyed by the target path.
---
--- @type table
local SvnInfoCache = {}
local SvnInfoCache = {} -- GetSvnInfo is dev only so it's ok having such cache

---
--- Retrieves information about a Subversion (SVN) repository target.
---
--- This function checks a cache to see if the SVN information for the given target has already been retrieved. If not, it executes the `svn info` command to get the information and stores the results in the cache.
---
--- @param target string The path to the SVN repository target.
--- @param env table An optional environment table to use for expanding variables in the target path.
--- @return string|nil An error message if there was a problem retrieving the SVN information, or `nil` if the information was retrieved successfully.
--- @return table|nil A table containing the SVN information, or `nil` if there was an error.
--- @return number|nil The exit code of the `svn info` command, or `nil` if there was an error.
--- @return string|nil The output of the `svn info` command, or `nil` if there was an error.
--- @return string|nil The error message from the `svn info` command, or `nil` if there was no error.
function GetSvnInfo(target, env)
	local svn_info_values = SvnInfoCache[target]
	if not svn_info_values then
		local folder, filename, ext = SplitPath(target)
		local file = filename .. ext
		if file == "" then
			file = "."
		end
		local err, exit_code, output, err_messsage = AsyncExec("svn info " .. file, ConvertToOSPath(folder), true, true, "belownormal")
		if err then 
			return err, nil, exit_code, output, err_messsage
		end

		svn_info_values = {}
		for _, value in ipairs(output and ExtractedSvnInfoValues) do
			local m = string.match(output, value.re) or value.default
			if m then
				svn_info_values[value.key] = value.number and tonumber(m) or m
			end
		end
		SvnInfoCache[target] = svn_info_values
	end
	return nil, svn_info_values
end

---
--- Writes the given data to a file if the contents are different from the existing file.
---
--- This function checks if the file at the given `filename` already exists and has the same contents as the `data` parameter. If the contents are different, it creates the necessary directories and writes the new data to the file.
---
--- @param filename string The path to the file to write.
--- @param data string The data to write to the file.
--- @return string|nil An error message if there was a problem writing the file, or `nil` if the file was written successfully.
---
function StringToFileIfDifferent(filename, data)
	local err, old_data = AsyncFileToString(filename, nil, nil, "pstr")
	if not err then
		local same = old_data:equals(data)
		old_data:free()
		if same then return end
	end
	local dir = SplitPath(filename)
	AsyncCreatePath(dir)
	return AsyncStringToFile(filename, data)
end

---
--- Saves a file with the given data, creating the necessary directories if they don't exist. If the file already exists and the contents are different, the file is updated. If the file is a Lua source file, it is also cached.
---
--- @param file_path string The path to the file to save.
--- @param data string The data to write to the file.
--- @param is_local boolean Whether the file is a local file (not part of the SVN repository).
--- @return string|nil An error message if there was a problem writing the file, or `nil` if the file was written successfully.
---
function SaveSVNFile(file_path, data, is_local)
	local exists = io.exists(file_path)
	if not exists then
		local path = SplitPath(file_path)
		AsyncCreatePath(path)
		if path:starts_with("CommonLua/Libs/") and (path:ends_with("/Data/") or path:ends_with("/XTemplates/")) then
			AsyncStringToFile(path .. "/__load.lua", "")
		end
		if not is_local then
			SVNAddFile(path)
		end
	end
	local err = StringToFileIfDifferent(file_path, data)
	if err then return err end
	if not exists and not is_local then
		SVNAddFile(file_path)
	end
	if file_path:ends_with(".lua") then
		CacheLuaSourceFile(file_path, data)
	end
end

--- Gets the unpacked Lua revision for the given path.
---
--- This function checks the SVN revision of the specified path, and returns the revision number if it can be determined. If the path is not under SVN control, it returns the provided fallback revision number.
---
--- @param env table|nil The environment table, if available. Used for error reporting.
--- @param path string|nil The path to check the SVN revision for. Defaults to "svnSrc/." if not provided.
--- @param fallback_revision number|nil The fallback revision number to use if the SVN revision cannot be determined.
--- @return boolean|number, string|nil The SVN revision number, or `false` if the revision could not be determined. If an error occurs, it also returns an error message.
function GetUnpackedLuaRevision(env, path, fallback_revision)
	if not Platform.cmdline and not config.RunUnpacked then
		return false
	end
	if env then
		path = expand_vars(path or "$(project)/..", env)
	else
		path = path or "svnSrc/."
	end
	local dir = ConvertToOSPath(path)
	local err, exit_code, output, err_messsage = AsyncExec("svn info .", dir, true, true)
	if not err and exit_code ~= 0 then
		err = "Exit code (" .. tostring(exit_code) .. ")"
		if (err_messsage or "") ~= "" then
			err = err .. ": " .. tostring(err_messsage)
		end
	end
	if not err then
		local rev = string.match(output or "", "Last Changed Rev: (%d+)")
		rev = tonumber(rev) or -1
		assert(rev ~= -1)
		if rev == -1 then
			return false, "Failed to parse revision info"
		end
		return rev
	elseif type(fallback_revision) == "number" then
		return fallback_revision
	else
		if env then
			env:error("svn info '%s' err '%s'", dir, err)
		else
			assert(false, string.format("svn info '%s' err '%s'", dir, err))
		end
		return false, err
	end
end

--- Shows the log file in the editor of choice.
---
--- This function creates a real-time thread that flushes the log file and opens it in the editor specified by the `config.EditorVSCode`, `config.EditorGed`, or default file explorer.
function ShowLog()
	CreateRealTimeThread(function()
		FlushLogFile()
		OpenTextFileWithEditorOfChoice(GetLogFile())
	end)
end

--- Opens the specified text file in the editor of choice.
---
--- This function opens the specified text file in the editor specified by the `config.EditorVSCode`, `config.EditorGed`, or the default file explorer.
---
--- @param file string The path to the text file to open.
--- @param line number The line number to open the file at, or 0 to open the file at the beginning.
function OpenTextFileWithEditorOfChoice(file, line)
	file = file or ""
	if file == "" then return end
	file = ConvertToOSPath(file)
	line = line or 0
	if config.EditorVSCode then
		AsyncExec("cmd /c code -r -g \"" .. file .. ":" .. line .. "\"", true, true)
	elseif config.EditorGed or not Platform.desktop then
		OpenGedApp("GedFileEditor", false, { file_name = file })
	else
		local err = AsyncExec("explorer " .. file)
		if err then
			print(err)
			OS_LocateFile(file)
		end
	end
end

--- Generates a random color based on the provided color and variation.
---
--- This function takes a base color and a variation color, and generates a new color by randomly varying the RGB values of the base color within the range of the variation color.
---
--- @param color table The base color, represented as an RGB table with fields `r`, `g`, and `b`.
--- @param variation table The variation color, represented as an RGB table with fields `r`, `g`, and `b`.
--- @return table The generated color, represented as an RGB table with fields `r`, `g`, and `b`.
function GenerateColor(color, variation)
	local r, g, b = GetRGB(color)
	local vr, vg, vb = GetRGB(variation)
	local red = r + AsyncRand(2*vr+1) - vr
	local green = g + AsyncRand(2*vg+1) - vg
	local blue = b + AsyncRand(2*vb+1)- vb
	return RGB(red, green, blue)
end

--- Returns the invalid position value.
---
--- This function returns the value of the `invalid_pos` global variable, which represents an invalid position value.
---
--- @return table The invalid position value.
function InvalidPos()
	return invalid_pos
end
local invalid_pos = InvalidPos()
--- Returns the invalid position value.
---
--- This function returns the value of the `invalid_pos` global variable, which represents an invalid position value.
---
--- @return table The invalid position value.
function InvalidPos()
	return invalid_pos
end


-- PeriodicRepeat

--- A table that stores the names of all periodic repeat functions.
---
--- This table is used to keep track of the names of all periodic repeat functions that have been registered using the `PeriodicRepeat` function. It is used for various purposes, such as iterating over all registered periodic repeat functions.
PeriodicRepeatNames = {}
--- A table that stores information about periodic repeat functions.
---
--- This table is used to store information about periodic repeat functions that have been registered using the `PeriodicRepeat` function. Each entry in the table is a table with the following fields:
---
--- - `create_thread`: A function that creates a new thread to run the periodic repeat function.
--- - `interval`: The interval, in seconds, at which the periodic repeat function should be called.
--- - `func`: The function that should be called periodically.
--- - `condition`: An optional function that returns a boolean value indicating whether the periodic repeat function should be executed.
PeriodicRepeatInfo = {}
--- Initializes the `PeriodicRepeatThreads` table if it is the first time the code is loaded.
---
--- This code checks if `FirstLoad` is true, which indicates that this is the first time the code is being loaded. If so, it initializes the `PeriodicRepeatThreads` table, which is used to store information about periodic repeat functions that have been registered using the `PeriodicRepeat` function.
if FirstLoad then
	PeriodicRepeatThreads = {}
end
--- Marks the `PeriodicRepeatThreads` table as a persistable global variable.
---
--- This line of code adds the `PeriodicRepeatThreads` table to the `PersistableGlobals` table, which ensures that the contents of the `PeriodicRepeatThreads` table are saved and loaded when the game is saved and loaded. This is important because the `PeriodicRepeatThreads` table is used to store information about periodic repeat functions that have been registered using the `PeriodicRepeat` function.
PersistableGlobals.PeriodicRepeatThreads = true

 -- !!! backwards compatibility
--- Backwards compatibility for the `MapRepeatThreads` table.
---
--- This line assigns the `PeriodicRepeatThreads` table to the `MapRepeatThreads` table, providing backwards compatibility for code that may have been using the `MapRepeatThreads` table instead of the `PeriodicRepeatThreads` table.
---
--- @field MapRepeatThreads table The table that stores information about periodic repeat functions that have been registered using the `PeriodicRepeat` function.
MapRepeatInfo = PeriodicRepeatInfo
--- Backwards compatibility for the `MapRepeatThreads` table.
---
--- This line assigns the `PeriodicRepeatThreads` table to the `MapRepeatThreads` table, providing backwards compatibility for code that may have been using the `MapRepeatThreads` table instead of the `PeriodicRepeatThreads` table.
---
--- @field MapRepeatThreads table The table that stores information about periodic repeat functions that have been registered using the `PeriodicRepeat` function.
MapRepeatThreads = PeriodicRepeatThreads
--- Handles the loading of persistent data for periodic repeat threads.
---
--- This function is called when the game is loaded from a saved state. It restores the state of the `PeriodicRepeatThreads` table, which stores information about periodic repeat functions that have been registered using the `PeriodicRepeat` function. If the `PeriodicRepeatThreads` table is not available in the saved data, it falls back to using the `MapRepeatThreads` table for backwards compatibility.
---
--- @param data table The saved game data.
function OnMsg.PersistLoad(data)
	PeriodicRepeatThreads = data["PeriodicRepeatThreads"] or data["MapRepeatThreads"]
	MapRepeatThreads = PeriodicRepeatThreads
end
--- !!!

--- Registers a new periodic repeat function.
---
--- This function registers a new periodic repeat function that will be called at the specified interval. The function takes the following parameters:
---
--- @param create_thread function A function that creates a new thread to run the periodic repeat function.
--- @param name string The name of the periodic repeat function.
--- @param interval number The interval, in seconds, at which the periodic repeat function should be called.
--- @param func function The function that should be called periodically.
--- @param condition function An optional function that returns a boolean value indicating whether the periodic repeat function should be executed.
function PeriodicRepeat(create_thread, name, interval, func, condition)
	assert(not PeriodicRepeatInfo[name], "Duplicated map repeat")
	PeriodicRepeatInfo[name] = {
		create_thread,
		interval,
		func,
		condition,
	}
	PeriodicRepeatNames[#PeriodicRepeatNames + 1] = name
end

--- Checks if a map is currently loaded.
---
--- This function returns a boolean value indicating whether a map is currently loaded. It does this by checking the value of the `CurrentMap` global variable, which is set when a map is loaded.
---
--- @return boolean true if a map is currently loaded, false otherwise
function has_map()
	return rawget(_G, "CurrentMap") ~= ""
end
local function has_map()
	return rawget(_G, "CurrentMap") ~= ""
end

--- Registers a new map-based periodic repeat function.
---
--- This function registers a new periodic repeat function that will be called at the specified interval, but only when a map is currently loaded. The function takes the following parameters:
---
--- @param name string The name of the periodic repeat function.
--- @param interval number The interval, in seconds, at which the periodic repeat function should be called.
--- @param func function The function that should be called periodically.
--- @param condition function An optional function that returns a boolean value indicating whether the periodic repeat function should be executed.
function MapGameTimeRepeat(name, interval, func, condition)
	return PeriodicRepeat(CreateGameTimeThread, name, interval, func, condition or has_map)
end

--- Registers a new map-based periodic repeat function.
---
--- This function registers a new periodic repeat function that will be called at the specified interval, but only when a map is currently loaded. The function takes the following parameters:
---
--- @param name string The name of the periodic repeat function.
--- @param interval number The interval, in seconds, at which the periodic repeat function should be called.
--- @param func function The function that should be called periodically.
--- @param condition function An optional function that returns a boolean value indicating whether the periodic repeat function should be executed.
function MapRealTimeRepeat(name, interval, func, condition)
	return PeriodicRepeat(CreateMapRealTimeThread, name, interval, func, condition or has_map)
end

--- Creates a new periodic repeat thread for the given name.
---
--- This function creates a new persistent thread that will execute the periodic repeat function for the given name. The thread will sleep for the specified interval and then call the periodic repeat function, unless the optional condition function returns false.
---
--- @param name string The name of the periodic repeat function.
--- @return thread The created thread.
local function PeriodicRepeatCreateThread(name)
	local info = PeriodicRepeatInfo[name]
	if info[4] and not info[4](info) then return end -- condition failed
	local thread = PeriodicRepeatInfo[name][1](function(name)
		local sleep
		while true do
			do
				local info = PeriodicRepeatInfo[name]
				sleep = info[3](sleep) or info[2] or -1
			end
			Sleep(sleep)
		end
	end, name)
	MakeThreadPersistable(thread)
	if not Platform.goldmaster then
		ThreadsSetThreadSource(thread, name, PeriodicRepeatInfo[name][3])
	end
	return thread
end

--- Ensures that all periodic repeat threads are created and running.
---
--- This function iterates through the list of periodic repeat names and creates a new thread for each one if it doesn't already exist. The created threads will execute the periodic repeat function at the specified interval, unless the optional condition function returns false.
function PeriodicRepeatCreateThreads()
	for _, name in ipairs(PeriodicRepeatNames) do
		if not IsValidThread(PeriodicRepeatThreads[name]) then
			PeriodicRepeatThreads[name] = PeriodicRepeatCreateThread(name)
		end
	end
end

--- Called when a new map is loaded.
---
--- This function is called when a new map is loaded. It ensures that all periodic repeat threads are created and running.
function OnMsg.NewMap()
	PeriodicRepeatCreateThreads()
end

--- Called when the Lua code is reloaded.
---
--- This function ensures that all periodic repeat threads are created and running after the Lua code is reloaded.
function OnMsg.ReloadLua()
	PeriodicRepeatCreateThreads()
end
OnMsg.ReloadLua = PeriodicRepeatCreateThreads
--- Called when the Lua code is reloaded.
---
--- This function ensures that all periodic repeat threads are created and running after the Lua code is reloaded.
OnMsg.PersistPostLoad = PeriodicRepeatCreateThreads

--- Validates and cleans up the periodic repeat threads.
---
--- This function iterates through the list of periodic repeat threads and removes any threads that no longer have a corresponding entry in the `PeriodicRepeatInfo` table. This ensures that the list of active periodic repeat threads is kept up-to-date and does not contain any stale or invalid entries.
function PeriodicRepeatValidateThreads()
	for name, thread in pairs(PeriodicRepeatThreads) do
		if not PeriodicRepeatInfo[name] then
			PeriodicRepeatThreads[name] = nil
			DeleteThread(thread)
		end
	end
end
--- Called when the Lua code is reloaded.
---
--- This function ensures that all periodic repeat threads are created and running after the Lua code is reloaded.
OnMsg.LoadGame = PeriodicRepeatValidateThreads

---
--- Restarts a periodic repeat thread.
---
--- This function deletes the existing periodic repeat thread for the given name, and creates a new thread if the corresponding `PeriodicRepeatInfo` entry exists.
---
--- @param name string The name of the periodic repeat thread to restart.
---
function RestartPeriodicRepeatThread(name)
	DeleteThread(PeriodicRepeatThreads[name])
	if PeriodicRepeatInfo[name] then
		PeriodicRepeatThreads[name] = PeriodicRepeatCreateThread(name)
	end
end

---
--- Wakes up a periodic repeat thread by its name.
---
--- @param name string The name of the periodic repeat thread to wake up.
--- @param ... any Optional arguments to pass to the woken up thread.
--- @return boolean True if the thread was successfully woken up, false otherwise.
function WakeupPeriodicRepeatThread(name, ...)
	return Wakeup(PeriodicRepeatThreads[name], ...)
end

---- PostMsg

--- Calls all static messages (and wakes up threads) from a GameTime thread before the end of the current millisecond.
-- @cstyle void PostMsg(message, ...).
-- @param message any value used as message name.
---
--- Calls all static messages (and wakes up threads) from a GameTime thread before the end of the current millisecond.
---
--- @param message any value used as message name.
--- @param ... any optional arguments to pass to the message.
function PostMsg(message, ...)
	local list = PostMsgList
	if list then
		assert(IsValidThread(PeriodicRepeatThreads["PostMsgThread"]))
		list[#list + 1] = pack_params(message, ...)
		Wakeup(PeriodicRepeatThreads["PostMsgThread"])
	else
		Msg(message, ...)
	end
end

---
--- Creates a new table named "PostMsgList" and assigns it to the global variable "PostMsgList".
---
--- This variable is used to store a list of messages that need to be posted at the end of the current millisecond. The "PostMsgThread" periodic repeat thread is responsible for processing this list and posting the messages.
---
--- @global
--- @type table
--- @name PostMsgList
MapVar("PostMsgList", {})
---
--- Removes an element from the specified table.
---
--- @param t table The table to remove the element from.
--- @param index integer The index of the element to remove.
--- @return any The removed element.
function remove(t, index)
end
local remove = table.remove
---
--- Removes an element from the specified table.
---
--- @param t table The table to remove the element from.
--- @param index integer The index of the element to remove.
--- @return any The removed element.
function remove(t, index)
end
local clear = table.clear
---
--- Runs a periodic repeat thread that processes the `PostMsgList` and posts all the messages in the list before the end of the current millisecond.
---
--- This thread is responsible for iterating through the `PostMsgList` table, unpacking the message parameters, and calling `Msg()` to post the message. After processing all the messages in the list, it clears the list and waits for the next wakeup signal.
---
--- @function MapGameTimeRepeat
--- @param name string The name of the periodic repeat thread.
--- @param delay number The delay in milliseconds between each iteration of the thread.
--- @param func function The function to be executed in each iteration of the thread.
MapGameTimeRepeat("PostMsgThread", 0, function()
	while true do
		local i, list = 1, PostMsgList
		while i <= #list do
			local msg = list[i]
			list[i] = false
			if msg then
				Msg(unpack_params(msg))
			end
			i = i + 1
		end
		clear(list)
		WaitWakeup()
	end
end)


---- DelayedCall

---
--- Initializes the DelayedCallTime, DelayedCallParams, and DelayedCallThread tables when the script is first loaded.
---
--- This code is executed when the script is first loaded, and it initializes the DelayedCallTime, DelayedCallParams, and DelayedCallThread tables to empty values. These tables are used to manage delayed function calls in the script.
---
--- @section FirstLoad
if FirstLoad then
	DelayedCallTime = {}
	DelayedCallParams = {}
	DelayedCallThread = {}
end

---
--- Calls the specified method on the given object, passing the object itself as the first argument.
---
--- @param self table The object on which to call the method.
--- @param method string The name of the method to call.
--- @param ... any The arguments to pass to the method.
local function call_method(self, method, ...)
	self[method](self, ...)
end

---
--- Schedules a function to be called after a specified delay.
---
--- This function creates a new thread that waits for the specified delay before calling the provided function. The function can be a regular Lua function, a table method, or a global function name. Any additional arguments passed to `DelayedCall` will be passed to the called function.
---
--- @param delay number The delay in seconds before the function is called.
--- @param func function|table|string The function, table method, or global function name to be called.
--- @param ... any Additional arguments to pass to the called function.
--- @return thread The thread that will execute the delayed call.
function DelayedCall(delay, func, ...)
	assert(delay >= 0)
	DelayedCallThread[func] = DelayedCallThread[func] or CreateMapRealTimeThread(function()
		while WaitWakeup(DelayedCallTime[func] - now()) do
		end
		local params = DelayedCallParams[func]
		DelayedCallTime[func] = nil
		DelayedCallParams[func] = nil
		DelayedCallThread[func] = nil
		local typ = type(func)
		if typ == "function" then
			func(unpack_params(params))
		elseif typ == "table" then
			assert(params and params[1], "Method name required for tables")
			call_method(func, unpack_params(params))
		elseif typ == "string" then
			_G[func](unpack_params(params))
		else
			assert(false, "DelayedCall invalid function type")
		end
	end)
	DelayedCallParams[func] = pack_params(...)
	DelayedCallTime[func] = RealTime() + (delay or 0)
	Wakeup(DelayedCallThread[func])
end

---
--- Cancels a delayed call that was previously scheduled with `DelayedCall`.
---
--- This function removes the scheduled delayed call from the internal tracking structures, effectively canceling the call.
---
--- @param func function|table|string The function, table method, or global function name that was previously passed to `DelayedCall`.
---
function DelayedCallCancel(func)
	DeleteThread(DelayedCallThread[func])
	DelayedCallParams[func] = nil
	DelayedCallTime[func] = nil
	DelayedCallThread[func] = nil
end

---
--- Clears the internal tracking structures for delayed calls.
---
--- This function is called when the map is done loading, and resets the internal data structures used to track delayed calls scheduled with `DelayedCall`.
---
function OnMsg.PostDoneMap()
	DelayedCallTime = {}
	DelayedCallParams = {}
	DelayedCallThread = {}
end

---
--- Calls a specified member function on each object in the given list.
---
--- @param obj_list table A list of objects.
--- @param member string The name of the member function to call.
--- @param ... any Arguments to pass to the member function.
---
function CallMember(obj_list, member, ...)
	for _, obj in ipairs(obj_list) do
		if PropObjHasMember(obj, member) then call_method(obj, member, ...) end
	end
end

---
--- Logs a message.
---
--- This function does nothing, as it is just a placeholder for a logging function.
---
function log()
end
function log() end

---
--- Trims user input to a specified length range.
---
--- This function takes a string input, trims any leading or trailing whitespace, and ensures the length of the input is within a specified minimum and maximum length.
---
--- @param input string The input string to be trimmed.
--- @param min_len number (optional) The minimum length of the trimmed input. Defaults to 1.
--- @param max_len number (optional) The maximum length of the trimmed input. Defaults to 80.
--- @return string|nil The trimmed input string if it is within the specified length range, otherwise nil.
---
function TrimUserInput(input, min_len, max_len)
	if type(input) ~= "string" then return end
	input = input:trim_spaces()
	if #input < (min_len or 1) or #input > (max_len or 80) then return end
	return input
end

---
--- Validates an email address.
---
--- This function checks if the given email address is valid according to the configured email pattern.
---
--- @param email string The email address to validate.
--- @return boolean|nil True if the email is valid, false if the email is invalid, or nil if the input is not a string or matches the "example.com" pattern.
---
function IsValidEmail(email)
	if type(email) ~= "string" or email:match("%@example%.com$") then
		return
	end
	--return email:match(config.EmailPattern or "^[%w\128-\255%!%#%$%%%&%'%*%+%-%/%=%?%^%_%`%{%|%}%~]+%@[%w\128-\255%-%.]+%.[%w\128-\255]+$") or nil
	return email:match(config.EmailPattern or "[^@]+%@[^@]+%.[^@]+$") or nil -- at most one @ and at least one dot after it
end

---
--- Validates a password based on the configured password rules.
---
--- This function checks if the given password meets the configured password requirements, such as minimum and maximum length, mixed digits, and whether it is a common password or contains the username.
---
--- @param pass string The password to validate.
--- @param username string The username associated with the password.
--- @return boolean, string True if the password is valid, false and an error message if the password is invalid.
---
function IsValidPassword(pass, username)
	if not utf8.IsStrMoniker(pass, config.PasswordMinLen or 8, config.PasswordMaxLen or 128) then
		return false, "bad-password-length"
	end
	if config.PasswordHasMixedDigits ~= false and (not pass:find("%d") or not pass:find("%D")) then
		return false, "no-mixed-digits"
	end
	if not config.PasswordAllowCommon and CommonPasswords and CommonPasswords[pass] then
		return false, "common-pass"
	end
	if not config.PasswordAllowUsername and username and pass:find(username, 1, true) then
		return false, "username-in-pass"
	end
	
	return true
end

---
--- Validates a username based on the configured username rules.
---
--- This function checks if the given username meets the configured username requirements, such as minimum and maximum length, and whether it matches the configured username pattern.
---
--- @param name string The username to validate.
--- @return boolean|nil True if the username is valid, false if the username is invalid, or nil if the input is not a string or does not match the configured username pattern.
---
function IsValidUserName(name)
	if not utf8.IsStrMoniker(name, config.UsernameMin or 4, config.UsernameMax or 30) then
		return
	end

	return name:match(config.UsernamePattern or "^[%w\128-\255_%-%/%+][%w\128-\255%s_%-%/%+]+[%w\128-\255_%-%/%+]$") and true or false
end

-- the checksum check in this function should be the same in the functions ParseSerial and GenerateSerial
---
--- Validates a serial number based on the configured serial number charset.
---
--- This function checks if the given serial number is valid by verifying the checksum digit. The serial number is expected to be in the format "XXXC-XXXX-XXXX-XXXX-XXXX", where X represents a character from the configured serial number charset and C represents the checksum digit.
---
--- @param serial string The serial number to validate.
--- @param charset string The charset to use for the serial number. If not provided, the default charset from the config will be used.
--- @return boolean True if the serial number is valid, false otherwise.
---
function IsSerialNumberValid(serial, charset)
	serial = tostring(serial):upper()
	local charset = config.SerialCharset or 'ABCDEFGHJKLMNPRTUVWXY346789'
	local set, checksum, g1, g2, g3, g4 = string.match(serial, "^(%w%w%w)(%w)-(%w%w%w%w)-(%w%w%w%w)-(%w%w%w%w)-(%w%w%w%w)$")
	if set then
		local n = abs(xxhash(set, g1, g2, g3, g4)) % #charset + 1
		return charset:sub(n, n) == checksum
	end
end

-- HMAC SHA1 HASH ---------------------------
---
--- Holds the last used key, inner padding, outer padding, and hash function for the Hmac function.
---
--- These values are cached to avoid unnecessary recalculation when the Hmac function is called repeatedly with the same parameters.
---
local last_key, last_ipad, last_opad, last_hash
---
--- Calculates the HMAC (Hash-based Message Authentication Code) of the given string using the specified key and hash function.
---
--- The function caches the last used key, inner padding, outer padding, and hash function to avoid unnecessary recalculation when the Hmac function is called repeatedly with the same parameters.
---
--- @param str string The input string to calculate the HMAC for.
--- @param key string The key to use for the HMAC calculation.
--- @param fHash function The hash function to use for the HMAC calculation. Defaults to SHA256 if not provided.
--- @return string The HMAC of the input string.
---
function Hmac(str, key, fHash)
	fHash = fHash or SHA256
	local ipad, opad = last_ipad, last_opad
	if key ~= last_key or last_hash ~= fHash then
		local key = #key > 64 and fHash(key) or key
		local aipad, aopad = {}, {}
		for i = 1, #key do
			local k = string.byte(key, i)
			aipad[i] = bxor(k, 0x36)
			aopad[i] = bxor(k, 0x5c)
		end
		for i = #key+1, 64 do
			aipad[i] = 0x36
			aopad[i] = 0x5c
		end
		ipad = string.char(unpack_params(aipad))
		opad = string.char(unpack_params(aopad))
		last_key, last_ipad, last_opad = key, ipad, opad
		last_hash = fHash
	end
	str = fHash(opad .. fHash(ipad .. str))
	return str
end

---
--- Calculates the Base64-encoded HMAC (Hash-based Message Authentication Code) of the given string using the specified key and hash function.
---
--- This function is a wrapper around the `Hmac` function, which calculates the HMAC of the input string. This function then encodes the result in Base64 format.
---
--- @param str string The input string to calculate the HMAC for.
--- @param key string The key to use for the HMAC calculation.
--- @param fHash function The hash function to use for the HMAC calculation. Defaults to SHA256 if not provided.
--- @return string The Base64-encoded HMAC of the input string.
---
function Hmac64(str, key, fHash)
	return Encode64(Hmac(str, key, fHash))
end

---
--- Calculates the Base64-encoded SHA256 hash of the given XUID string.
---
--- @param XUID string The XUID string to hash.
--- @return string The Base64-encoded SHA256 hash of the XUID.
---
function HashXUID(XUID)
	if type(XUID) ~= "string" then return end
	return Encode64(SHA256("XUID" .. XUID))
end

---
--- Checks if the given IP address matches any of the IP masks in the provided list.
---
--- @param ip string The IP address to check.
--- @param mask_list table A list of IP masks to check against.
--- @return boolean True if the IP address matches any of the masks, false otherwise.
---
function MatchIPMask(ip, mask_list)
	if type(ip) ~= "string" then return end
	if not mask_list then return true end
	for i = 1, #mask_list do
		if ip:match(mask_list[i]) then
			return true
		end
	end
end

---
--- Checks if the game is running in an unpacked file system.
---
--- This function returns true if the current platform is PC, OSX, Linux, or PS4, and the `config.RunUnpacked` setting is true. This indicates that the game is running in an unpacked file system, rather than a packed or bundled file system.
---
--- @return boolean True if the game is running in an unpacked file system, false otherwise.
---
function IsFSUnpacked()
	return (Platform.pc or Platform.osx or Platform.linux or Platform.ps4) and config.RunUnpacked
end

-- allow the engine to provide its own func
---
--- Resolves the local IP addresses for the current host.
---
--- This function is used to get the list of local IP addresses for the current machine. It calls the `sockGetHostName()` function to get the hostname, and then uses `sockResolveName()` to resolve the IP addresses associated with that hostname.
---
--- @return table A table of local IP addresses as strings.
---
function LocalIPs()
	return sockResolveName(sockGetHostName())
end
if not rawget(_G, "LocalIPs") then
function LocalIPs()
	return sockResolveName(sockGetHostName())
end
end

---
--- Checks if the given IP address is inside the HG network.
---
--- This function recursively checks if the given IP address matches the patterns for IP addresses inside the HG network. It returns true if the IP address matches either the "213.240.234.*" or "10.34.*.*" patterns.
---
--- @param item string The IP address to check.
--- @param ... string Any additional IP addresses to check.
--- @return boolean True if the IP address is inside the HG network, false otherwise.
---
local function IPListInsideHG(item, ...)
	if type(item) ~= "string" then return end
	if item:match("^213%.240%.234%.%d+$") or item:match("^10%.34%.%d+%.%d+$") then return true end
	return IPListInsideHG(...)
end
---
--- Checks if the current host is inside the HG network.
---
--- This function first checks if the current platform is a console platform and in developer mode. If so, it returns `true`. Otherwise, it calls the `IPListInsideHG()` function, passing in the list of local IP addresses obtained from the `LocalIPs()` function, to determine if any of the IP addresses match the patterns for IP addresses inside the HG network.
---
--- @return boolean True if the current host is inside the HG network, false otherwise.
---
function insideHG()	
	if Platform.console then return Platform.developer end
	return IPListInsideHG(LocalIPs())
end

---
--- Returns the name of the current platform.
---
--- This function checks the current platform and returns a string representing the platform name. If the platform is not recognized, an empty string is returned.
---
--- @return string The name of the current platform, or an empty string if the platform is not recognized.
---
function PlatformName()
	return 	Platform.pc and "pc" or 
				Platform.linux and "linux" or 
				Platform.osx and "osx" or 
				Platform.ios and "ios" or 
				Platform.ps4 and "ps4" or 
				Platform.ps5 and "ps5" or 
				Platform.xbox_one and "xbox_one" or
				Platform.xbox_series and "xbox_series" or
				Platform.switch and "switch" or  
				''
end

---
--- Returns an empty string.
---
--- This function always returns an empty string. It is likely an implementation detail or a placeholder for a more complex function.
---
--- @return string An empty string.
---
function ProviderName()
	return ''
end

---
--- Returns the variant name of the current platform.
---
--- This function checks the current platform and returns a string representing the variant name. If the platform is not a publisher, demo, beta, or developer variant, an empty string is returned.
---
--- @return string The variant name of the current platform, or an empty string if the platform is not a recognized variant.
---
function VariantName()
	return Platform.publisher and "publisher" or Platform.demo and "demo" or Platform.beta and "beta" or Platform.developer and "developer" or ''
end

---
--- Encodes a given text string into a URL-safe format for use in an "hgrun://" URL.
---
--- This function takes a text string as input, encodes it using Base64 encoding, and then performs additional transformations to make the resulting string URL-safe. The encoded string is then prefixed with "hgrun://" to create a complete URL.
---
--- @param text string The text to be encoded into a URL-safe format.
--- @return string The encoded URL-safe string, prefixed with "hgrun://".
---
function EncodeHGRunUrl(text)
	local url = Encode64(text)
	url = string.gsub(url, "[\n\r]", "")
	url = string.gsub(url, "=", "%%3D")
	return "hgrun://" .. url
end

---
--- Decodes a URL-safe string into the original text.
---
--- This function takes a URL-safe string, typically created by `EncodeHGRunUrl()`, and decodes it back into the original text. The URL-safe string is first extracted from the "hgrun://" prefix, then the URL-encoding is reversed, and finally the Base64 decoding is applied to obtain the original text.
---
--- @param url string The URL-safe string to be decoded.
--- @return string The original text that was encoded.
---
function DecodeHGRunUrl(url)
	url = string.match(url, "hgrun://(.*)/")
	url = string.gsub(url, "%%3D", "=")
	url = Decode64(url)
	return url
end

---
--- Opens a URL in the appropriate browser or platform-specific application.
---
--- This function handles opening URLs on different platforms. It checks the current platform and uses the appropriate method to open the URL:
---
--- - On Steam, it activates the Steam overlay and opens the URL in the overlay browser.
--- - On PC, it uses the default system browser to open the URL.
--- - On macOS, it uses the `OpenNSURL` function to open the URL.
--- - On Linux, it uses the `xdg-open` command to open the URL.
--- - On Xbox, it uses the `XboxLaunchUri` function to open the URL.
--- - On PlayStation, it uses the `AsyncPlayStationShowBrowserDialog` function to open the URL.
---
--- @param url string The URL to be opened.
--- @param force_external_browser boolean (optional) If true, the URL will be opened in an external browser, even on platforms that have a platform-specific method.
---
function OpenUrl(url, force_external_browser)
	if Platform.steam and SteamIsOverlayEnabled() and IsSteamLoggedIn() and not force_external_browser then
		SteamActivateGameOverlayToWebPage(url)
	elseif Platform.pc then
		local os_command = string.format("explorer \"%s\"", url)
		os.execute(os_command)
	elseif Platform.osx then
		url = string.gsub(url, "%^", "") -- strip win shell escapes
		OpenNSURL(url)	
	elseif Platform.linux then
		AsyncExec("xdg-open " .. url)
	elseif Platform.xbox then
		XboxLaunchUri(url)
	elseif Platform.playstation then
		AsyncPlayStationShowBrowserDialog(url)
	end
end

-- Helper functions for getting coords on the night sky
---
--- Calculates the right ascension (RA) coordinate of a celestial object.
---
--- This function takes the hour, minute, and second components of a right ascension coordinate and calculates the total value in seconds.
---
--- @param h number The hour component of the right ascension.
--- @param m number The minute component of the right ascension.
--- @param s number The second component of the right ascension.
--- @return number The right ascension coordinate in seconds.
---
function CSphereRA(h, m, s)
	local correction = -2*60 - 27 -- offset from input stars data
	return h*60*60 + m*60 + s + correction
end

---
--- Calculates the declination (Dec) coordinate of a celestial object.
---
--- This function takes the degree, minute, and second components of a declination coordinate and calculates the total value in seconds.
---
--- @param d number The degree component of the declination.
--- @param m number The minute component of the declination.
--- @param s number The second component of the declination.
--- @return number The declination coordinate in seconds.
---
function CSphereDec(d, m, s)
	local value = abs(d) * 60*60 + abs(m)*60 + abs(s)
	return d > 0 and value or -value
end

---- Infinite Loop Detection

--- Resets the `IFD_PauseReasons` table to `false` on first load.
---
--- This code is executed when the script is first loaded, and it resets the `IFD_PauseReasons` table to `false`. This table is used to track the reasons for pausing the infinite loop detection feature.
---
--- @param FirstLoad boolean True if this is the first time the script has been loaded.
if FirstLoad then
	IFD_PauseReasons = false
end

if not rawget(_G, "SetInfiniteLoopDetectionHook") then

ResumeInfiniteLoopDetection = empty_func
PauseInfiniteLoopDetection = empty_func

else

---
--- Resumes the infinite loop detection feature.
---
--- This function is used to resume the infinite loop detection feature after it has been paused. It checks the `IFD_PauseReasons` table to see if there are any remaining reasons for the detection to be paused. If there are no more reasons, it sets `IFD_PauseReasons` to `false` and enables the `InfiniteLoopDetection` configuration.
---
--- @param reason string|boolean The reason for pausing the infinite loop detection. This can be a string or `true` if no specific reason is provided.
--- @return boolean|nil Returns `true` if the infinite loop detection was resumed, or `nil` if there are still reasons for it to be paused.
---
function ResumeInfiniteLoopDetection(reason)
	reason = reason or true
	local reasons = IFD_PauseReasons
	if not reasons then
		return
	end
	reasons[reason] = nil
	if next(reasons) then
		return
	end
	IFD_PauseReasons = false
	config.InfiniteLoopDetection = true
end

---
--- Pauses the infinite loop detection feature.
---
--- This function is used to pause the infinite loop detection feature. It adds the provided reason to the `IFD_PauseReasons` table, and disables the `InfiniteLoopDetection` configuration. If the `IFD_PauseReasons` table is already initialized, it simply adds the new reason to the table.
---
--- @param reason string|boolean The reason for pausing the infinite loop detection. This can be a string or `true` if no specific reason is provided.
--- @return boolean|nil Returns `true` if the infinite loop detection was paused, or `nil` if the detection was already paused.
---
function PauseInfiniteLoopDetection(reason)
	reason = reason or true
	local reasons = IFD_PauseReasons
	if not reasons then
		if not config.InfiniteLoopDetection then
			-- disabled by default
			return
		end
		IFD_PauseReasons = { [reason] = true }
		config.InfiniteLoopDetection = false
	else
		if reasons[reason] then
			return
		end
		reasons[reason] = true
	end
	return true
end

end -- SetInfiniteLoopDetectionHook

----

---
--- Encrypts the given data using AES and then generates an HMAC signature for the encrypted data.
---
--- @param key string The encryption key to use for AES.
--- @param data string The data to encrypt and sign.
--- @return string|nil The encrypted data concatenated with the HMAC signature. If an error occurs, returns an error string.
---
function AESEncryptThenHmac(key, data)
	local err, encrypted = AESEncrypt(key, data)
	if err then return err end
	local hmac = Hmac(tostring(encrypted), SHA256(key), SHA256) -- just in case do not reuse the key directly
	if not hmac then return "hmac err" end
	return nil, encrypted .. hmac
end

---
--- Decrypts the given data using AES and verifies the HMAC signature.
---
--- @param key string The encryption key to use for AES.
--- @param data string The encrypted data concatenated with the HMAC signature.
--- @return string|nil The decrypted data. If the HMAC signature is invalid, returns an error string.
---
function AESHmacThenDecrypt(key, data)
	assert(type(data) == "string")
	local hmac_key = SHA256(key)
	local hmac_len = hmac_key:len() -- also a SHA256
	-- sanity-check data size to be at least an AES block + hmac and to be a whole number of AES blocks
	if #data < 16 + hmac_len or #data % 16 ~= 0 then
		return "data err"
	end
	local encrypted = data:sub(1, -(hmac_key:len() + 1))
	local hmac = data:sub(-hmac_key:len())
	local calculated_hmac = Hmac(encrypted, hmac_key, SHA256)
	if not calculated_hmac or calculated_hmac ~= hmac then 
		return "hmac err"
	end
	local err, data = AESDecrypt(key, encrypted)
	return err, data
end

---
--- Encrypts the given data using AES and then generates an HMAC signature for the encrypted data.
---
--- @param key string The encryption key to use for AES.
--- @param data string The data to encrypt and sign.
--- @return string|nil The encrypted data concatenated with the HMAC signature. If an error occurs, returns an error string.
---
function EncryptAuthenticated(key, data)
	return AESEncryptThenHmac(key, data)
end
EncryptAuthenticated = AESEncryptThenHmac
DecryptAuthenticated = AESHmacThenDecrypt

---
--- Initializes the global encryption key if not running in a command-line environment.
---
--- The encryption key is generated using the SHA256 hash of the app ID and a project-specific key.
---
--- @return nil
---
if not Platform.cmdline then
	g_encryption_key = SHA256(GetAppId() .. (config.ProjectKey or "1ac7d4eb8be00f1bf6ae7af04142b8fc"))
end

--filename expects full relative path
---
--- Saves a Lua table to disk, optionally compressing and encrypting the data.
---
--- @param t table The Lua table to save to disk.
--- @param filename string The file path to save the table to.
--- @param key string The encryption key to use, if encrypting the data.
--- @return boolean, string True if the save was successful, or false and an error message if it failed.
---
function SaveLuaTableToDisk(t, filename, key)
	local shouldCompress =         not Platform.console and not Platform.developer
	local shouldEncrypt  = key and not Platform.console and not Platform.developer
	
	local data, success
	data = pstr("return ", 1024)
	local len0 = #data
	ValueToLuaCode(t, nil, data)
	success = #data > len0
	
	if not success then
		IgnoreError("empty data", "SaveLuaTableToDisk")
		return false, "empty data"
	end

	if shouldCompress then
		data = CompressPstr(data)
	end
	
	if shouldEncrypt then
		local err, result = EncryptAuthenticated(key, data)
		if err then
			IgnoreError(err, "SaveLuaTableToDisk")
			-- ATTN: we keep the original data on error
		else
			data = result
		end
	end	
	
	local err = AsyncStringToFile(filename, data, -2, 0, nil) -- -2 = overwrite entire file
	
	if err then
		IgnoreError(err, "SaveLuaTableToDisk")
		return false, err
	end
	
	return true
end

---
--- Loads a Lua table from disk, optionally decompressing and decrypting the data.
---
--- @param filename string The file path to load the table from.
--- @param env table The environment to load the table into.
--- @param key string The decryption key to use, if the data is encrypted.
--- @return boolean, string True if the load was successful, or false and an error message if it failed.
---
function LoadLuaTableFromDisk(filename, env, key)
	local shouldDecrypt    = key and not Platform.console
	local shouldDecompress =         not Platform.console
	
	local err, data, result
	err, data = AsyncFileToString(filename)
	
	if err then
		IgnoreError(err, "LoadLuaTableFromDisk")
		return false, err
	end
	
	if shouldDecrypt then
		err, result = DecryptAuthenticated(key, data)
		if not err then
			data = result
		else
			-- ATTN: leave original data
		end
	end
	
	local decompressedData = shouldDecompress and not data:starts_with("return ") and Decompress(data)
	if decompressedData then data = decompressedData end
	-- inlined dofile
	local func, err = load(data, nil, nil, env or _ENV)
	if not func then
		return false, "invalid data"
	end
	return procall_helper(procall(func))
end

---
--- Creates an RSA key without throwing an error.
---
--- @param data table The data to use for creating the RSA key.
--- @return table The created RSA key.
---
function RSACreateKeyNoErr(data)
	local err, key = RSACreate(data)
	if err then
		assert(false, "RSA create key err: " .. err)
		return
	end
	return key
end

---
--- Generates a new RSA key pair.
---
--- @return string|nil Error message if generation failed, otherwise the RSA key, private key string, and public key string.
---
function RSAGenerate()
	local err, key = RSACreate()
	if err then
		assert(false, "RSA create key err: " .. err)
		return err
	end
	local err, private_str = RSASerialize(key)
	if err then
		assert(false, "RSA serialize private key err: " .. err)
		return err
	end
	local err, public_str = RSASerialize(key, true)
	if err then
		assert(false, "RSA serialize public key err: " .. err)
		return err
	end
	return nil, key, private_str, public_str
end

---
--- Creates a file signature using RSA encryption.
---
--- @param file string The path to the file to create a signature for.
--- @param key table The RSA key to use for signing.
--- @return string|nil An error message if the signature creation failed, otherwise nil.
---
function CreateFileSignature(file, key)
	local err, data = AsyncFileToString(file)
	if err then
		return string.format("reading %s failed: %s", file, err)
	end
	
	local hash = SHA256(data)
	assert(#hash == 32)
	local err, sign = RSACreateSignature(key, hash)
	if err then
		return string.format("encryption failed: %s", err)
	end
	assert(#sign == 256)
	local signature = file .. ".sign"
	local err = AsyncStringToFile(signature, sign)
	if err then
		return string.format("signature %s creation failed: %s", signature, err)
	end
end

---
--- Checks the signature of the provided data using the given RSA key.
---
--- @param data string The data to check the signature for.
--- @param sign string The signature to check against the data.
--- @param key table The RSA key to use for verifying the signature.
--- @return string|nil An error message if the signature check failed, otherwise nil.
---
function CheckSignature(data, sign, key)
	if not key then
		return "key"
	end
	if not data then
		return "data"
	end
	if #(sign or "") ~= 256 then
		return "signature"
	end
	return RSACheckSignature(key, sign, SHA256(data))
end

---- ObjModified

---
--- Initializes the delayed object modification system.
---
--- This code is executed on the first load of the module. It sets up the necessary data structures
--- to track delayed object modifications, including a list of objects to be modified and a thread
--- to process the list.
---
--- @field DelayedObjModifiedList table A table to store objects that need to be modified in a delayed fashion.
--- @field DelayedObjModifiedThread thread A thread that processes the DelayedObjModifiedList.
--- @field SuspendObjModifiedReasons table A table to store reasons for suspending object modification.
--- @field SuspendObjModifiedList table A table to store objects that have been suspended from modification.
---
if FirstLoad then
	DelayedObjModifiedList = {}
	DelayedObjModifiedThread = false
	SuspendObjModifiedReasons = {}
	SuspendObjModifiedList = false
end

---
--- Processes a list of objects that have been marked as modified.
---
--- This function iterates through the provided list of objects and checks if each object is a valid `CObject`. If the object is valid, it calls the `ObjModified` function with the `instant` parameter set to `true` to immediately notify the system of the object modification.
---
--- @param list table A table containing the objects that have been marked as modified.
---
function ObjListModified(list)
	local IsKindOf, IsValid = IsKindOf, IsValid
	local i = 1
	while true do
		local obj = list[i]
		if obj == nil then
			break
		end
		if type(obj) ~= "table" or not IsKindOf(obj, "CObject") or IsValid(obj) then
			ObjModified(obj, true)
		end
		i = i + 1
	end
end

---
--- Schedules an object for delayed modification.
---
--- This function adds the provided object to a list of objects that need to be modified. If the list of delayed modifications is currently suspended, the object is added to the suspended list instead.
---
--- If the delayed modification thread is not currently running, this function will create a new thread to process the list of delayed modifications.
---
--- @param obj CObject The object to be modified in a delayed fashion.
---
function ObjModifiedDelayed(obj)
	if SuspendObjModifiedList then
		return ObjModified(obj)
	end
	local list = DelayedObjModifiedList
	assert(list)
	if not obj or not list or list[obj] then
		return
	end
	list[obj] = true
	list[#list + 1] = obj
	if IsValidThread(DelayedObjModifiedThread) then
		Wakeup(DelayedObjModifiedThread)
		return
	end
	DelayedObjModifiedThread = CreateRealTimeThread(function(list)
		while true do
			procall(ObjListModified, list)
			table.clear(list)
			WaitWakeup()
		end
	end, list)
end

function ObjModifiedIsScheduled(obj)
	return SuspendObjModifiedList and SuspendObjModifiedList[obj] or DelayedObjModifiedList and DelayedObjModifiedList[obj]
end

---
--- Schedules an object for immediate or delayed modification.
---
--- If the delayed modification list is currently suspended, the object is modified immediately. Otherwise, the object is added to the delayed modification list. If the delayed modification thread is not currently running, a new thread is created to process the list of delayed modifications.
---
--- @param obj CObject The object to be modified.
--- @param instant boolean If true, the object is modified immediately instead of being added to the delayed modification list.
---
function ObjModified(obj, instant)
	if not obj then return end
	local objs = SuspendObjModifiedList
	if not objs or instant then
		Msg("ObjModified", obj)
		return
	end
	if objs[obj] then
		table.remove_value(objs, obj)
	else
		objs[obj] = true
	end
	objs[#objs + 1] = obj
end

---
--- Suspends the processing of modified objects.
---
--- When an object is modified, it is normally added to a delayed modification list that is processed in a separate thread. Calling this function will suspend that processing and instead add the modified objects to a separate list.
---
--- To resume processing of modified objects, call the `ResumeObjModified` function.
---
--- @param reason string The reason for suspending object modifications. This is used to track the suspension state.
---
function SuspendObjModified(reason)
	if next(SuspendObjModifiedReasons) == nil then
		SuspendObjModifiedList = {}
	end
	SuspendObjModifiedReasons[reason] = true
end

---
--- Resumes the processing of modified objects.
---
--- When an object is modified, it is normally added to a delayed modification list that is processed in a separate thread. Calling `SuspendObjModified` will suspend that processing and instead add the modified objects to a separate list. This function resumes the processing of modified objects.
---
--- @param reason string The reason for suspending object modifications. This is used to track the suspension state.
---
function ResumeObjModified(reason)
	if not SuspendObjModifiedReasons[reason] then
		return
	end
	SuspendObjModifiedReasons[reason] = nil
	if next(SuspendObjModifiedReasons) == nil then
		local objs = SuspendObjModifiedList
		SuspendObjModifiedList = false
		procall(ObjListModified, objs)
	end
end

----

---
--- Scales a child size to fit within a parent size, while preserving the aspect ratio.
---
--- This function takes the size of a child object and the size of a parent object, and returns a new size for the child that will fit within the parent while preserving the child's aspect ratio.
---
--- If the `clip` parameter is true, the child will be scaled down to fit within the parent. If `clip` is false, the child will be scaled up to fill the parent.
---
--- @param child_size point The size of the child object.
--- @param parent_size point The size of the parent object.
--- @param clip boolean Whether to clip the child to fit within the parent.
--- @return point The new size for the child object.
---
function ScaleToFit(child_size, parent_size, clip)
	local x_greater = parent_size:x() * child_size:y() > parent_size:y() * child_size:x()
	if x_greater == not not clip then
		return point(parent_size:x(), child_size:y() * parent_size:x() / child_size:x())
	else
		return point(child_size:x() * parent_size:y() / child_size:y(), parent_size:y())
	end
end

---
--- Fits an inner box within an outer box, ensuring the inner box is fully contained within the outer box.
---
--- This function takes two boxes, an inner box and an outer box, and adjusts the position of the inner box so that it is fully contained within the outer box. The function returns the adjusted inner box.
---
--- @param inner box The inner box to fit within the outer box.
--- @param outer box The outer box that the inner box must fit within.
--- @return box The adjusted inner box that is fully contained within the outer box.
---
function FitBoxInBox(inner, outer)
	local result = inner
	if result:maxx() > outer:maxx() then
		result = Offset(result, point(outer:maxx() - result:maxx(), 0))
	end
	if result:minx() < outer:minx() then
		result = Offset(result, point(outer:minx() - result:minx(), 0))
	end
	if result:maxy() > outer:maxy() then
		result = Offset(result, point(0, outer:maxy() - result:maxy()))
	end
	if result:miny() < outer:miny() then
		result = Offset(result, point(0, outer:miny() - result:miny()))
	end
	return result
end
---
--- Multiplies and divides a point by the given multiplier and divisor, rounding the result.
---
--- This function takes a point and two values, a multiplier and a divisor. It multiplies the x and y components of the point by the multiplier, divides the result by the divisor, and rounds the final result to the nearest integer.
---
--- @param point_in point The input point to be multiplied and divided.
--- @param multiplier point|number The multiplier to apply to the point. Can be a point or a number.
--- @param divisor point|number The divisor to apply to the point. Can be a point or a number.
--- @return point The resulting point after multiplication and division, with the values rounded to the nearest integer.
---
function MulDivRoundPoint(point_in, multiplier, divisor)
end

function MulDivRoundPoint(point_in, multiplier, divisor)
	if type(multiplier) == "number" then
		multiplier = point(multiplier, multiplier)
	end
	if type(divisor) == "number" then
		divisor = point(divisor, divisor)
	end
	return point(MulDivRound(point_in:x(), multiplier:x(), divisor:x()), MulDivRound(point_in:y(), multiplier:y(), divisor:y()))
end

---
--- Generates a list of class method names that match a given prefix.
---
--- This function takes a class name, a method prefix, and an optional additional method name to include in the list.
--- It searches the g_Classes table for the given class and collects all method names that start with the given prefix.
--- The list of method names is sorted and returned, with the optional additional method name inserted at the beginning of the list.
---
--- @param class string The name of the class to search for methods.
--- @param method_prefix string The prefix to match method names against.
--- @param additional string (optional) An additional method name to include in the list.
--- @return table A list of method names that match the given prefix.
---
function ClassMethodsCombo(class, method_prefix, additional)
	local list = {}
	for name, value in pairs(g_Classes[class or false] or empty_table) do
		if type(value) == "function" and type(name) == "string" and name:starts_with(method_prefix) then
			list[#list + 1] = name
		end
	end
	table.sort(list)
	if additional then
		table.insert(list, 1, additional)
	end
	return list
end

---
--- Formats a number with a given scale and precision.
---
--- This function takes a number, a scale, and an optional precision, and formats the number with the given scale and precision. If the scale is a string, it is treated as a unit and the corresponding scale is looked up using `GetPropScale()`. The formatted number is returned as a string, with the scale appended as a suffix.
---
--- @param number number The number to be formatted.
--- @param scale number|string The scale to apply to the number. Can be a number or a string representing a unit.
--- @param precision number (optional) The number of decimal places to include in the formatted number.
--- @return string The formatted number as a string, with the scale appended as a suffix.
---
function FormatNumberProp(number, scale, precision)
	local suffix = ""
	if type(scale) ~= "number" then
		suffix = " " .. scale
		scale = GetPropScale(scale)
	end
	
	local full_units = number / scale
	if number < 0 and number % scale ~= 0 then
		full_units = full_units + 1
	end
	local fractional_part = abs(number - full_units * scale)
	local number_str = full_units == 0 and number < 0 and "-0" or tostring(full_units)
	
	-- guess precision
	if not precision then
		precision = 1
		local s = scale
		while s > 10 do
			s = s / 10
			precision = precision + 1
		end
	end
	
	if precision > 0 and scale > 1 then
		local frac = ""
		local power = 1
		for i = 1, precision do
			power = power * 10
			frac = frac .. MulDivTrunc(fractional_part, power, scale) % 10
		end
		frac = frac:gsub("0*$", "") -- remove trailing zeroes
		if #frac > 0 then
			number_str = number_str .. "." .. frac
		end
	end
	return number_str .. suffix
end

---
--- Matches a set of flags against a set of required and optional flags.
---
--- This function takes three sets of flags: `set_to_match`, `set_any`, and `set_all`. It checks if the `set_to_match` set matches the requirements specified by `set_any` and `set_all`.
---
--- The function returns `true` if the `set_to_match` set matches the requirements, and `nil` otherwise.
---
--- @param set_to_match table A set of flags to match against the requirements.
--- @param set_any table A set of optional flags, at least one of which must be present in `set_to_match`.
--- @param set_all table A set of required flags, all of which must be present in `set_to_match`.
--- @return boolean|nil `true` if the `set_to_match` set matches the requirements, `nil` otherwise.
---
function MatchThreeStateSet(set_to_match, set_any, set_all)
	if not next(set_to_match) then
		for _, is_set in pairs(set_any) do
			if is_set then
				return
			end
		end
		for _, is_set in pairs(set_all) do
			if is_set then
				return
			end
		end
		return true
	end
	if next(set_any) then
		local require_any, found_any
		for tag, is_set in pairs(set_any) do
			local found = set_to_match[tag]
			if found then
				if not is_set then
					return
				end
				found_any = true -- at least one of the required flags is present
			else
				if is_set then
					require_any = true -- there are required flags to match
				end
			end
		end
		if require_any and not found_any then
			return
		end
	end
	if next(set_all) then
		local has_disable, disable_missing
		for tag, is_set in pairs(set_all) do
			local found = set_to_match[tag]
			if is_set then
				if not found then
					return
				end
			else
				has_disable = true -- there are rejected flags to match
				if not found then
					disable_missing = true -- at least one of the rejected flags isn't present
				end
			end
		end
		if has_disable and not disable_missing then
			return
		end
	end
	return true
end

---
--- Executes a function with a status UI dialog that is displayed while the function is running.
---
--- @param status string The status message to display in the UI dialog.
--- @param fn function The function to execute.
--- @param wait boolean If true, waits for the function to complete before returning.
---
function ExecuteWithStatusUI(status, fn, wait)
	CreateRealTimeThread(function()
		local ui = StdStatusDialog:new({}, terminal.desktop, { status = status })
		ui:Open()
		WaitNextFrame(3)
		fn(ui)
		ui:Close()
		if wait then Msg("ExecuteWithStatusUI") end
	end)
	if wait then WaitMsg("ExecuteWithStatusUI") end
end

--[[
	ic - fancy print-debugging loosely inspired by https://github.com/gruns/icecream
		ic()     -- prints the current file/line
		ic(a, b) -- prints a = <value of a>, b = <value of b>; not a real parser so don't get fancy
		ic "foo" -- prints foo
	each ic() also prints time elapsed since the previous ic() in the same function, if >= 2 ms 
]]

---
--- Provides a set of utility functions for print-debugging.
---
--- The `ic` table provides a set of functions for print-debugging, inspired by the `icecream` library in Python.
---
--- @module ic
--- @author CommonLua
---
local 
ic = {
	print_func = print,
	prefix = "[ic] ",
	file_cache = {}, -- clear on reload
	read_file = function(self, file)
		if not self.file_cache[file] then
			local err, lines = async.AsyncFileToString(nil, file, nil, nil, "lines")
			self.file_cache[file] = { err, lines }
		end
		return table.unpack(self.file_cache[file])
	end,
	file_line = function(self, file, line)
		local err, lines = self:read_file(file)
		if err then 
			return err 
		end
		return false, tostring(lines[line])
	end,
	file_line_parsed_cache = {}, -- clear on reload
	parse_file_line = function(self, call_line)
		local file, line = call_line:match("^(.-)%((%d+)%)$")
		line = tonumber(line)
		if not file and not line then
			return "can't parse file/line from " .. call_line
		end
		local err, source_line = self:file_line(file, line)
		if err then 
			return err 
		end
		local source_args = source_line:match("ic%s*(%b())") or source_line:match([[ic%s*(%b"")]])
		if not source_args then 
			return "can't parse arguments from " .. call_line
		end
		if source_args:starts_with("(") then
			source_args = source_args:sub(2, -2)
		end
		return false, source_args:split("%s*,%s*")
	end,
	file_line_args = function(self, call_line)
		if not self.file_line_parsed_cache[call_line] then
			self.file_line_parsed_cache[call_line] = { self:parse_file_line(call_line) }
		end
		return table.unpack(self.file_line_parsed_cache[call_line])
	end,
	__call = function(self, ...)
		local args = {...}
		local call_line = GetCallLine(2)
		local ret
		if not next(args) then
			ret = call_line
		else
			local err, source_args = self:file_line_args(call_line)
			if err then 
				ret = err
			else
				local rets = {}
				for i, source_arg in ipairs(source_args) do
					if source_arg:starts_with([["]]) and source_arg:ends_with([["]]) then
						rets[i] = source_arg:match([["(.-)"]])
					elseif source_arg:match("^%d+$") then
						rets[i] = source_arg
					else
						rets[i] = source_arg .. " = " .. ValueToLuaCode(args[i], ' ')
					end
				end
				ret = table.concat(rets, ", ")
			end
		end

		local func = debug.getinfo(2).func
		if self.profile_func ~= func then
			self.profile_time = GetPreciseTicks()
			self.profile_func = func
		else
			local t = GetPreciseTicks()
			local elapsed = t - self.profile_time
			if elapsed > 1 then
				ret = ret .. " (+" .. tostring(elapsed) .. " ms)"
			end
			self.profile_time = t
		end

		self.print_func(self.prefix .. ret)
	end,
}

setmetatable(ic, ic)


----- Pausing threads (used by XWindowInspector)

--- Initializes the PauseLuaThreadsOldGT, PauseLuaThreadsOldRT, and PauseLuaThreadsReasons variables when the script is first loaded.
-- This is likely used to keep track of the original game time and real time functions, as well as a table of reasons for pausing Lua threads.
-- The PauseLuaThreads and ResumeLuaThreads functions likely use these variables to pause and resume the Lua threads accordingly.
if FirstLoad then
	PauseLuaThreadsOldGT = false
	PauseLuaThreadsOldRT = false
	PauseLuaThreadsReasons = {}
end

---
--- Pauses all Lua threads in the application.
---
--- This function is used to pause the execution of all Lua threads in the application, typically for debugging or other purposes. It saves the current state of the `AdvanceGameTime` and `AdvanceRealTime` functions, and replaces them with custom functions that maintain the paused state.
---
--- When Lua threads are paused, the `AdvanceRealTime` function also updates the desktop layout and checks for Lua reload requests.
---
--- @param reason string|boolean The reason for pausing the Lua threads, or `false` if no reason is provided.
---
function PauseLuaThreads(reason)
	if next(PauseLuaThreadsReasons) then return end
	PauseLuaThreadsReasons[reason or false] = true
	
	PauseLuaThreadsOldGT = AdvanceGameTime
	PauseLuaThreadsOldRT = AdvanceRealTime
	AdvanceGameTime = function(time) -- time is ignored
		PauseLuaThreadsOldGT(GameTime())
	end
	AdvanceRealTime = function(time) -- time is ignored
		PauseLuaThreadsOldRT(now())
		local desktop = terminal.desktop
		if desktop.measure_update or desktop.layout_update then
			desktop:MeasureAndLayout()
		end
		if rawget(_G, "g_LuaDebugger") and g_LuaDebugger.update_thread then
			g_LuaDebugger:DebuggerTick()
		end
		if rawget(_G, "LuaReloadRequest") then
			LuaReloadRequest = false
			ReloadLua()
		end
	end
	Msg("LuaThreadsPaused", true)
end

---
--- Resumes all Lua threads in the application that were previously paused.
---
--- This function is used to resume the execution of all Lua threads in the application that were previously paused using the `PauseLuaThreads` function. It restores the original `AdvanceGameTime` and `AdvanceRealTime` functions, and removes the reason for pausing the Lua threads from the `PauseLuaThreadsReasons` table.
---
--- If there are still reasons for pausing the Lua threads in the `PauseLuaThreadsReasons` table, this function will not resume the threads.
---
--- @param reason string|boolean The reason for resuming the Lua threads, or `false` if no reason is provided.
---
function ResumeLuaThreads(reason)
	if not next(PauseLuaThreadsReasons) then return end
	
	PauseLuaThreadsReasons[reason or false] = nil
	if next(PauseLuaThreadsReasons) then return end
	
	AdvanceGameTime = PauseLuaThreadsOldGT
	AdvanceRealTime = PauseLuaThreadsOldRT
	Msg("LuaThreadsPaused", false)
end

---
--- Checks if the Lua threads in the application are currently paused.
---
--- @return boolean true if the Lua threads are paused, false otherwise
---
function AreLuaThreadsPaused()
	return not not next(PauseLuaThreadsReasons)
end

---
--- Rounds up a number to the nearest multiple of a given period.
---
--- If the input number is already a multiple of the period, it is returned unchanged.
--- Otherwise, the function calculates the next multiple of the period that is greater than or equal to the input number.
---
--- @param x number The number to be rounded up.
--- @param period number The period to round up to.
--- @return number The rounded up number.
---
function RoundUp(x, period)
	if x % period == 0 then
		return x
	end
	return ((x / period) + 1) * period
end

---
--- Converts a path to a Bender project path.
---
--- This function takes a path and converts it to a Bender project path. It does this by:
--- - Replacing forward slashes with backslashes
--- - Removing a leading backslash if present
--- - Prepending the path with `\\bender.haemimontgames.com\<project_name>\`, where `<project_name>` is the value of `const.ProjectName` or `ProjectEnv.project`
---
--- @param path string The path to convert
--- @return string The converted Bender project path
---
function ConvertToBenderProjectPath(path)
	path = string.gsub(path or "", "/", "\\")
	if string.starts_with(path, "\\") then
		path = string.sub(path, 2)
	end
	return string.format("\\\\bender.haemimontgames.com\\%s\\%s", const.ProjectName or ProjectEnv.project, path)
end

---
--- Resets the cache used by `SearchStringsInFiles` when the script is first loaded.
---
--- This function is called when the script is first loaded (`FirstLoad` is true) to reset the cache used by `SearchStringsInFiles`. The cache stores the contents of files that have been searched, along with metadata about the files, to avoid re-reading the files on subsequent searches.
---
--- By resetting the cache on first load, this ensures that the cache will be populated with the latest file contents and metadata the next time `SearchStringsInFiles` is called.
---
if FirstLoad then
	SearchStringsInFilesCache = false
end

---
--- Searches for the given strings in the specified files and returns a table mapping each string to the files where it was found.
---
--- This function uses a cache to avoid re-reading the contents of files that have already been searched. The cache stores the contents of files along with metadata about the files, such as the modification time and size.
---
--- @param strings table A table of strings to search for
--- @param files table A table of file paths to search in
--- @param string_to_files table (optional) A table to store the mapping of strings to files where they were found
--- @param threads number (optional) The number of threads to use for parallel processing
--- @param silent boolean (optional) If true, the function will not print progress information
--- @return table The mapping of strings to files where they were found
---
function SearchStringsInFiles(strings, files, string_to_files, threads, silent)
	threads = Max(1, threads or tonumber(os.getenv("NUMBER_OF_PROCESSORS")))
	
	local st = GetPreciseTicks()
	local count = 0
	string_to_files = string_to_files or {}
	local function SearchForStringsInFile(file)
		local data
		local err, src_modified, src_size = AsyncGetFileAttribute(file)
		SearchStringsInFilesCache = SearchStringsInFilesCache or {}
		local cache = SearchStringsInFilesCache[file]
		if not err and cache and cache.src_modified == src_modified and cache.src_size == src_size then
			data = cache.data
		end
		if not data then
			local err
			err, data = AsyncFileToString(file, nil, nil, "pstr")
			if err then
				return
			end
			cache = {
				data = data,
				src_modified = src_modified,
				src_size = src_size,
			}
			SearchStringsInFilesCache[file] = cache
		end
		for _, str in ipairs(strings) do
			local files = string_to_files[str] or {}
			if not files[file] then
				local searches = cache.searches or {}
				local search = searches[str]
				if not search then
					search = ""
					local err, idx = AsyncStringSearch(data, str, false, true)
					if idx then
						local code = string.byte('\n')
						local len = #data
						local from = idx - 1
						while from > 0 and data:byte(from) ~= code do
							from = from - 1
						end
						from = from + 1
						local to = idx + #str
						while to <= len and data:byte(to) ~= code do
							to = to + 1
						end
						to = to - 1
						search = data:sub(from, to)
					end
					searches[str] = search
					cache.searches = searches
				end
				if search ~= "" then
					files[file] = search
					string_to_files[str] = files
				end
			end
		end
		count = count + 1
		if not silent then
			print("Files processed:", count, "/", #files)
		end
	end
	parallel_foreach(files, SearchForStringsInFile, nil, threads)
	if not silent then
		printf("All files processed in %.1f s", (GetPreciseTicks() - st) / 1000.0)
	end
	return string_to_files
end

---
--- Copies a directory recursively from a source path to a destination path.
---
--- @param src string The source directory path.
--- @param dest string The destination directory path.
--- @return string|nil The error message if an error occurred, or `nil` if the operation was successful.
function WaitCopyDir(src, dest)
	src = ConvertToOSPath(SlashTerminate(src))
	dest = ConvertToOSPath(SlashTerminate(dest))
	local err, files = AsyncListFiles(src, nil, "recursive,relative")
	for _, file in ipairs(files) do
		local path, filename, ext = SplitPath(file)
		err = err or AsyncCreatePath(dest .. path)
		err = err or AsyncCopyFile(src .. file, dest .. file, "raw")
	end
	return err
end

---
--- Creates a line of 4 points between a start and end y-coordinate, spanning the given max x-coordinate.
---
--- @param start_y number The starting y-coordinate of the line.
--- @param end_y number The ending y-coordinate of the line.
--- @param max_x number The maximum x-coordinate to span the line across.
--- @return table A table of 4 points representing the line.
function MakeLine(start_y, end_y, max_x)
	start_y = start_y or 1000
	end_y = end_y or 1000
	max_x = max_x or 1000

	local points = {}
	local slope = end_y - start_y
	for i = 0, 3 do
		local y = start_y + MulDivRound(i, slope, 3)
		table.insert(points, point(MulDivRound(i, max_x, 3), y, y))
	end
	return points
end

----

---
--- Returns the name of the current platform.
---
--- @return string The name of the current platform.
function GetPlatformName()
	if Platform.pc then
		return "win32"
	elseif Platform.osx then
		return "osx"
	elseif Platform.linux then
		return "linux"
	elseif Platform.ios then
		return "ios"
	elseif Platform.ps4 then
		return "ps4"
	elseif Platform.ps5 then
		return "ps5"
	elseif Platform.xbox_one then
		return "xbox_one"
	elseif Platform.xbox_series then
		return "xbox_series"
	elseif Platform.switch then
		return "switch"
	else
		return "unknown"
	end
end

----

--- Suspends the error that is thrown when a function is called multiple times.
--- This is a no-op function that does nothing.
function SuspendErrorOnMultiCall()
end
SuspendErrorOnMultiCall = empty_func
--- Resumes the error that is thrown when a function is called multiple times.
--- This is a no-op function that does nothing.
function ResumeErrorOnMultiCall()
end
ResumeErrorOnMultiCall = empty_func
--- Disables the error that is thrown when a function is called multiple times.
--- This is a no-op function that does nothing.
function ErrorOnMultiCall()
end
ErrorOnMultiCall = empty_func

---
--- Registers a function name, call count, and class name when a function is called multiple times.
--- This is used for developer-only functionality to track and report on multiple calls to the same function.
---
--- @param func_name string The name of the function that was called multiple times.
--- @param count number The number of times the function was called.
--- @param class_name string The name of the class the function belongs to.
function ErrorOnMultiCall(func_name, count, class_name)
	local idx = table.find(MultiCallRegistered, 1, func_name) or (#MultiCallRegistered + 1)
	MultiCallRegistered[idx] = {func_name, count, class_name}
end
if Platform.developer then
	MultiCallRegistered = {}
	ErrorOnMultiCall = function(func_name, count, class_name)
		local idx = table.find(MultiCallRegistered, 1, func_name) or (#MultiCallRegistered + 1)
		MultiCallRegistered[idx] = {func_name, count, class_name}
	end
end
