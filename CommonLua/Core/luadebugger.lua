local translate_Ts = false
local h_print = CreatePrint{"Debugger"}

---
--- Recursively formats a Lua table as a string representation.
---
--- @param t table The table to format.
--- @param indent string (optional) The indentation to use for nested tables.
--- @return string The formatted string representation of the table.
---
function DbgLuaCode(t, indent)
    -- Implementation details omitted for brevity
end
local function DbgLuaCode(t, indent)
	indent = indent or ""
	local result = {}
	local function format(k, v)
		local s
		local ktype, vtype = type(k), type(v)
		if (ktype == "string" or ktype == "number" or ktype == "nil") and
			(vtype == "string" or vtype == "number" or vtype == "table" or vtype == "boolean" or IsPStr(v)) then
			if k then
				s = FormatKey(k)
			else
				s = ""
			end
			if vtype == "table" then
				s = s .. DbgLuaCode(v, indent .. "\t")
			elseif vtype == "string" or IsPStr(v) then
				s = s .. StringToLuaCode(v)
			elseif vtype == "number" or vtype == "boolean" then
				s = s .. tostring(v)
			end
			result[#result + 1] = s
		end
	end
	local len = #t
	for i = 1, len do
		format(nil, t[i])
	end
	for k, v in pairs(t) do
		if type(k) ~= "number" or k > len or k < 1 then
			format(k, v)
		end
	end
	return "{" .. table.concat(result, ",") .. "}"
end

luadebugger = {}

---
--- Constructs a new luadebugger object.
---
--- @param obj table (optional) A table to use as the base for the new luadebugger object.
--- @return table The new luadebugger object.
---
function luadebugger:new(obj)
	obj = obj or {}
	setmetatable(obj, self)
	self.__index = self
	
	obj.server = LuaSocket:new()
	obj.update_thread = false
	obj.started = false
	obj.call_stack = {}
	obj.stack_vars = {}
	obj.to_send = {}
	obj.in_break = false
	obj.coroutine = false
	obj.context_id = 0
	obj.stack_level = 1
	obj.eval_env = false
	obj.watches = {}
	obj.to_expand = {}
	obj.watches_results = {}
	obj.watches_evaluated = {}
	obj.last_received = false
	obj.init_packet_received = false
	obj.SetStepOver = false
	obj.SetStepInto = false
	obj.breakpoints = {}
	obj.continue = false
	obj.timeout = 300000
	obj.handle_to_obj = {}
	obj.obj_to_handle = {}
	obj.conditions = {}
	-- 0 is the base "hidden" stack frame of the Lua_State
	-- 1 is the first actual stack frame we can see
	-- Just like for relative values 0 is the current method (usually the C method that prints the metadata). 1 Gets you info for the caller
	obj.user_stack_level_top = false
	obj.__threadmeta = {
		__tostring = function(v)
			if v.type == "key" then
				return v.info.short_src .. " ( line: " ..  v.info.currentline .. " )"
			else
				return tostring(v.info.name)
			end
		end,
	}
	obj.__tuple_meta = {
		__tostring = function(v)
			local str = {}
			local count = table.maxn(v)
			for i=1,count do
				local value = v[i]
				if ObjectClass(value) then
					str[i] = value.class
				else
					str[i] = print_format(value) or "nil"
				end
			end
			return table.concat(str, ", ")
		end
	}
	obj.condition_env = {}
	obj.reload_thread = false
	setmetatable(obj.condition_env, {
			__index = DebuggerIndex
		})
	return obj
end
	
--- Breaks the execution of the debugger.
-- This function is called to interrupt the execution of the debugger and enter a break state.
-- When the debugger is in a break state, it can be used to inspect the current state of the program,
-- set breakpoints, step through the code, and perform other debugging operations.
-- After the debugging operations are complete, the debugger can be resumed to continue the program execution.
function luadebugger:BreakExecution()
	DebuggerBreakExecution()
end

---
--- Breaks the execution of the debugger and enters a break state.
--- This function is called to interrupt the execution of the debugger and enter a break state.
--- When the debugger is in a break state, it can be used to inspect the current state of the program,
--- set breakpoints, step through the code, and perform other debugging operations.
--- After the debugging operations are complete, the debugger can be resumed to continue the program execution.
---
--- @param co table|nil The coroutine to break, or `nil` to break the current thread.
--- @param break_offset number|nil The offset to apply to the stack level when breaking, or `"keep_user_stack_level_top"` to keep the user's stack level top.
function luadebugger:Break(co, break_offset)
	Msg("DebuggerBreak")
	self.in_break = true
	self.call_info, self.stack_vars = self:GetCallInfo(co, co and 0 or 3)
	self.coroutine = co
	local level = 1

	if "keep_user_stack_level_top" == break_offset and self.user_stack_level_top then
		level = #self.call_info - self.user_stack_level_top + 1
	else
		if self.call_info[1].Name == "assert" then
			level = Min(#self.stack_vars, 2)
		elseif self.call_info[1].Name == "error" then
			level = Min(#self.stack_vars, 3)
		end
		
		level = level + (break_offset or 0)
		while self.call_info[level] and self.call_info[level].Source == "C function" do
			level = level + 1
		end

		self.user_stack_level_top = #self.call_info - level + 1
	end
	-- remove the unusable part of the stack so that the break location is on top
	for i=1,level-1 do
		table.remove(self.call_info, 1)
		table.remove(self.stack_vars, 1)
	end
	self.stack_level = 1
	self.eval_env = self.stack_vars[1] or {}
	self.watches_evaluated = {}
	self.watches_results = {}
	self:AgeHandles()
	self.context_id = self.context_id + 1
	if self.context_id > 30000 then
		self.context_id = 0
	end
	local autos = self:GetAutos()
	self:Send{Event="Break", ShowLevel = 1, Watches=self:EvalWatches(), CallStack=self.call_info, ContextId=self.context_id, Autos=autos}
	self.continue = false
	while not self.continue do
		if not self:DebuggerTick() then
			self:Stop()
			break
		end
		os.sleep(1)
	end
end

--- Opens the specified file at the given line number in the editor.
---
--- @param file string The file path to open.
--- @param line number The line number to navigate to in the file.
function luadebugger:OpenFile(file, line)
	if not Platform.desktop then return end
	
	if config.AlternativeDebugger then
		OpenTextFileWithEditorOfChoice(file, line)
	else
		self:Send{Event="OpenFile", File = file, Line = line}
	end
end
	
--- Breaks the debugger and enters a break state, displaying the current call stack and watches.
---
--- @param file string The file path where the break occurred.
--- @param line number The line number where the break occurred.
--- @param status_text string An optional status text to display.
function luadebugger:BreakInFile(file, line, status_text)
	Msg("DebuggerBreak")
	self.in_break = true
	self.call_info = {{
		Source = file or "",
		Line = (line - 1) or 0,
		Name = "?",
		NameWhat = "",
	}}
	self.stack_vars = {}
	self.eval_env = {}
	self.watches_evaluated = {}
	self.watches_results = {}
	self:AgeHandles()
	self.context_id = self.context_id + 1
	if self.context_id > 30000 then
		self.context_id = 0
	end
	self:Send{Event="Break", ShowLevel = 1, Watches={}, CallStack=self.call_info, ContextId=self.context_id, Autos={}}
	if status_text then
		self:Send{Event="UpdateStatusText", text=status_text}
	end
	self.continue = false
	while not self.continue do
		if not self:DebuggerTick() then
			self:Stop()
			break
		end
		os.sleep(1)
	end
end

---
--- Resumes the debugger from a break state, allowing the program to continue execution.
---
function luadebugger:Continue()
	self.in_break = false
	self.continue = true
	self.coroutine = false
	Msg("DebuggerContinue")
end

-- Remotely called methods	
---
--- Resumes the debugger from a break state, allowing the program to continue execution.
---
function luadebugger:Run(to_expand)
	self:SetAllExpanded(to_expand)
	self:Continue()
end
	
---
--- Steps over the current line of execution, allowing the program to continue execution.
---
--- @param to_expand table A table of variables to expand in the debugger UI.
---
function luadebugger:StepOver(to_expand)
	self:SetAllExpanded(to_expand)
	DebuggerStep("step over", self.coroutine)
	self:Continue()
end

---
--- Steps into the current line of execution, allowing the program to continue execution.
---
--- @param to_expand table A table of variables to expand in the debugger UI.
---
function luadebugger:StepInto(to_expand)
	self:SetAllExpanded(to_expand)
	DebuggerStep("step into", self.coroutine)
	self:Continue()
end
	
---
--- Steps out of the current line of execution, allowing the program to continue execution.
---
--- @param to_expand table A table of variables to expand in the debugger UI.
---
function luadebugger:StepOut(to_expand)
	self:SetAllExpanded(to_expand)
	DebuggerStep("step out", self.coroutine)
	self:Continue()
end

---
--- Jumps the debugger to the specified line of execution, allowing the program to continue execution.
---
--- @param to_expand table A table of variables to expand in the debugger UI.
--- @param line number The line number to jump to.
---
function luadebugger:Goto(to_expand, line)
	self:SetAllExpanded(to_expand)
	assert(#self.call_info + 1 - self.stack_level == self.user_stack_level_top)
	DebuggerGoto(self.user_stack_level_top, line)
	self:Break(nil, "keep_user_stack_level_top")
end

---
--- Gets the list of line numbers that can be jumped to in the debugger for the current stack frame.
---
--- @param id number The request ID for the response.
--- @return table The list of line numbers that can be jumped to, along with the current stack level and source file.
---
function luadebugger:GetGotoTargets(id)
	assert(#self.call_info + 1 - self.stack_level == self.user_stack_level_top)

	local absolute_level = self.user_stack_level_top
	local relative_level = DebuggerToRelativeStackLevel(absolute_level)

	local info = debug.getinfo(relative_level, "SL")
	if not info then return end
	local lines = table.keys(info.activelines)
	self:Send{Event="Result", RequestId = id, Data = {level = self.stack_level, source = string.gsub(info.source, "^@", "") or "", lines = lines}}
end

---
--- Sets the stack level for the debugger.
---
--- @param req_id number The request ID for the response.
--- @param level number The stack level to set.
---
function luadebugger:SetStackLevel(req_id, level)
	if self.in_break and self.stack_level ~= level and #self.stack_vars >= level then
		self.stack_level = level
		self.eval_env = self.stack_vars[level] or {}
		self.watches_evaluated = {}
		self.watches_results = {}
		self.context_id = self.context_id + 1
		if self.context_id > 30000 then
			self.context_id = 0
		end
		local autos = self:GetAutos()
		local watches = self:EvalWatches()
		self:Send{Event="Result", RequestId = req_id, Data={Watches=watches, Autos=autos}}
	elseif config.AlternativeDebugger then
		assert(not "Unnecessary set stack level")
	end
end
	
---
--- Sets the breakpoints for the debugger.
---
--- @param b table A table of breakpoint definitions, where each breakpoint definition is a table with the following fields:
---   - File: string The file path of the breakpoint.
---   - Line: number The line number of the breakpoint.
---   - Condition: string (optional) A Lua expression that must evaluate to true for the breakpoint to be triggered.
---
function luadebugger:SetBreakpoints(b)
	DebuggerClearBreakpoints()
	for _, bp in ipairs(b) do
		if bp.Condition then
			local eval, err = load("return " .. bp.Condition, nil, nil, self.condition_env)
			if eval then
				DebuggerAddBreakpoint(bp.File, bp.Line, eval)
			else
				h_print(err)
				DebuggerAddBreakpoint(bp.File, bp.Line)
			end
		else
			DebuggerAddBreakpoint(bp.File, bp.Line)
		end
	end
	self.breakpoints = b
end
	
---
--- Sets the watches for the debugger.
---
--- @param req_id number The request ID for the response.
--- @param to_eval table A table of expressions to evaluate as watches.
---
--- This function sets the watches for the debugger. It evaluates the expressions in the `to_eval` table and sends the results back as a response to the request with the given `req_id`.
---
function luadebugger:SetWatches(req_id, to_eval)
	self.watches = to_eval
	local res = self:EvalWatches()
	if next(res)~=nil then
		self:Send{Event="Result", RequestId = req_id, Data=res}
	end
end
	
---
--- Sets the `to_expand` table to contain the keys of the `expanded` table as true values.
---
--- @param expanded table A table of expressions to expand.
---
function luadebugger:SetAllExpanded(expanded)
	self.to_expand = {}
	for _, v in ipairs(expanded) do
		self.to_expand[v] = true
	end
end
	
---
--- Expands a watch expression in the debugger.
---
--- @param req_id number The request ID for the response.
--- @param to_expand string The expression to expand.
---
--- This function adds the given expression to the list of expanded expressions, evaluates all watches, and sends the results back as a response to the request with the given `req_id`.
---
function luadebugger:Expand(req_id, to_expand)
	self.to_expand[to_expand] = true
	local res = self:EvalWatches()
	if next(res)~=nil then
		self:Send{Event="Result", RequestId = req_id, Data=res}
	end
end
	
---
--- Shows a position in the game.
---
--- @param to_view any The position to show in the game.
---
function luadebugger:ViewInGame(to_view)
	local r, err = load("return " .. to_view, nil, nil, self.eval_env)
	if r then
		local ok, r = pcall(r)
		if IsValidPos(r) then
			ShowMe(r)
		end
	end
end

---
--- Streams a grid to the debugger client.
---
--- @param req_id number The request ID for the response.
--- @param expression string The expression to evaluate and stream as a grid.
--- @param size number (optional) The maximum size of the grid to stream, in pixels.
---
--- This function evaluates the given expression and checks if the result is a grid. If so, it repackages the grid data, optionally resizes it, and streams the grid data to the debugger client in chunks.
---
--- If the expression does not evaluate to a grid, an error message is sent back to the debugger client.
---
function luadebugger:StreamGrid(req_id, expression, size)
	local ok
	local r, err = load("return " .. expression, nil, nil, self.eval_env)
	if r then
		local ok, r = pcall(r)
		if ok then
			if IsGrid(r) then
				r = GridRepack(r, "F")
				local w, h = r:size()
				local orig_w, orig_h = w, h
				if size and size > 0 and (w > size or h > size) then
					r = GridResample(r, size, size, false)
					w, h = size, size
				end
				local packet_size = 512 * 512
				for i = 0, w * h - 1, packet_size do
					local offset = i
					self:Send(function()
						local data = GridGetBinData(r, offset, packet_size)
						data = Encode64(data)
						return {
							Event="Result",
							RequestId = req_id,
							Data= {
								Expression = expression,
								width = w, height = h,
								orig_w = orig_w, orig_h = orig_h,
								offset = offset
							},
						}, data
					end)
				end
			else
				self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Error = "not a grid (" .. self:Type(r) .. ")"}}
			end
		else
			self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Error = r}}
		end
	else
		self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Error = err}}
	end
end
	
--- Evaluates the given expression and sends the result back to the debugger client.
---
--- @param req_id string The unique request ID for this evaluation.
--- @param expression string The expression to evaluate.
function luadebugger:Eval(req_id, expression)
	local ok
	local r, err = load("return " .. expression, nil, nil, self.eval_env)
	if r then
		local ok, r = pcall(r)
		if ok then
			self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Result = r}}
		else
			self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Error = r}}
		end
	else
		self:Send{Event="Result", RequestId = req_id, Data={Expression = expression, Error = err}}
	end
end

--- Sends the given text to the debugger client as output.
---
--- @param text string The text to send to the debugger client.
function luadebugger:WriteOutput(text)
	self:Send({Event = "Output", Text = text})
end
	
--- Initializes the luadebugger with the given breakpoints, watches, and expanded state.
---
--- @param breakpoints table A table of breakpoint information.
--- @param watches table A table of watch expressions.
--- @param expanded table A table of expanded variables.
function luadebugger:Init(breakpoints, watches, expanded)
	self.watches = watches
	self:SetBreakpoints(breakpoints)
	self:SetAllExpanded(expanded)
	self.init_packet_received = true
end
	
-- End remotely called methods
	
--- Returns a table of all the auto-complete variables available in the debugger's evaluation environment.
---
--- This function is used to retrieve the list of variables that are available for auto-completion
--- when evaluating expressions in the debugger.
---
--- @return table A table of variable names.
function luadebugger:GetAutos()
	local autos = {}
	for k in pairs(self.eval_env) do
		table.insert(autos, k)
	end
	return autos
end
	
--- Quits the luadebugger.
---
--- This function is used to quit the luadebugger and terminate the debugging session.
function luadebugger:Quit()
	quit()
end

--- The path to the overload files directory.
---
--- This global variable specifies the path to the directory where overload files are stored. It is used to manage the loading and unloading of overload files in the game.
OverloadFilesPath = "AppData/overload/"
--- Initializes the overload file system on startup.
---
--- This function is called on autorun to set up the overload file system. It deletes the existing overload files directory and creates a new one. This is necessary to ensure a clean slate for the overload file system on each game startup.
---
--- The overload file system is used to dynamically load and unload game assets and resources during runtime. This allows the game to be updated and patched without requiring a full recompile and redeployment.
if FirstLoad then
	PendingFileOverloads = 0
	
	function OnMsg.Autorun()
		if not Platform.goldmaster and (Platform.xbox or Platform.playstation or Platform.switch) then
			local err = DeleteFolderTree(OverloadFilesPath)
			if err and err ~= "File Not Found" and err ~= "Path Not Found" then
				print("Overload path delete error: ", err)
			end
			err = AsyncCreatePath("AppData/overload/")
			if err then
				print("Overload path create error: ", err)
			end
		end
	end
end

--- Mounts an overload folder with the given name.
---
--- This function is used to mount an overload folder during runtime. It checks if the folder exists and mounts it with a high priority and see-through label.
---
--- @param folder_name string The name of the folder to mount.
function MountOverloadFolder(folder_name)
	assert(not Platform.goldmaster and (Platform.xbox or Platform.playstation or Platform.switch))
	local label = folder_name .. "Overload"
	local folder_path = OverloadFilesPath .. folder_name .. "/"
	if MountsByLabel(label) == 0 and io.exists(folder_path) then
		local err = MountFolder(folder_name, folder_path, "priority:high,seethrough,label:" .. label)
		if err then print("Overload folder mount error: ", err) end
	end
end
local function MountOverloadFolder(folder_name)
	assert(not Platform.goldmaster and (Platform.xbox or Platform.playstation or Platform.switch))
	local label = folder_name .. "Overload"
	local folder_path = OverloadFilesPath .. folder_name .. "/"
	if MountsByLabel(label) == 0 and io.exists(folder_path) then
		local err = MountFolder(folder_name, folder_path, "priority:high,seethrough,label:" .. label)
		if err then print("Overload folder mount error: ", err) end
	end
end

--- Overloads a file with the given data.
---
--- This function is used to overload a file with new data during runtime. It creates the necessary directory structure and writes the data to the file.
---
--- @param filepath string The path of the file to overload, relative to the OverloadFilesPath directory.
--- @param data string The data to write to the file.
local function OverloadFile(filepath, data)
	filepath = OverloadFilesPath .. filepath
	local dir = SplitPath(filepath)
	AsyncCreatePath(dir)
	AsyncStringToFile(filepath, data)
end

--- Overloads a file with the given data.
---
--- This function is used to overload a file with new data during runtime. It creates the necessary directory structure and writes the data to the file.
---
--- @param filepath string The path of the file to overload, relative to the OverloadFilesPath directory.
--- @param size number The size of the data to write to the file.
function luadebugger:OverloadFile(filepath, size)
	if size == 0 then
		OverloadFile(filepath, "")
		return
	end
	self.binary_mode = true
	self.binary_handler = function(data)
		self.binary_mode = false
		PendingFileOverloads = PendingFileOverloads + 1
		CreateRealTimeThread(function()
			OverloadFile(filepath, data)
			h_print(string.format("[downloaded %d KB] %s (overload)", ((string.len(data))/1024), filepath))
			PendingFileOverloads = PendingFileOverloads - 1
			assert(PendingFileOverloads > -1)
		end)
	end
end

--- Compiles the specified shader.
---
--- This function is used to compile a shader during runtime. It sends a message to the debugger to initiate the shader compilation process.
---
--- @param shader string The name of the shader to compile.
function luadebugger:CompileShaders(shader)
	local shader_config = config.Haerald.CompileShaders
	self:Send({Event="CompileShaders", 
		Shader = shader, 
		ListFilePath = shader_config.ListFilePath or "",
		BuildTool = shader_config.BuildTool or "",
		BuildArgs = shader_config.BuildArgs or "", 
		ShaderCachePath = shader_config.ShaderCachePath or ""}
	)
end

--- Reloads the specified shader.
---
--- This function is used to reload a shader during runtime. It sends a message to the debugger to initiate the shader compilation process.
---
--- @param shader string The name of the shader to reload.
function luadebugger:ReloadShader(shader)
	local shader_config = config.Haerald.CompileShaders
	self:Send({	Event="CompileShaders", 
					Shader = shader, 
					ListFilePath = shader_config.ListFilePath or "", 
					BuildTool = shader_config.BuildTool or "", 
					BuildArgs = shader_config.BuildArgs or "", 
					ShaderCachePath = shader_config.ShaderCachePath or ""
	})
end

--- Reloads the shader cache.
---
--- This function is used to reload the shader cache during runtime. It mounts the overload folder for the shader cache and waits for any pending file overloads to complete before setting the `hr.AddRemotelyCompiledShader` flag to `true`.
function luadebugger:ReloadShaderCache()
	CreateRealTimeThread(function()
		MountOverloadFolder("ShaderCache")
		while PendingFileOverloads > 0 do
			Sleep(5)
		end
		hr.AddRemotelyCompiledShader = true
	end)
end
	
--- Reloads the Lua code.
---
--- This function is used to reload the Lua code during runtime. It creates a real-time thread that waits for 1 second, mounts the overload folders for CommonLua, Lua, and Data, and then reloads the Lua code.
---
--- This function is designed to handle multiple reload requests without actually reloading multiple times.
function luadebugger:ReloadLua()
	h_print("Reload request")
	-- Multiple reload requests will not actually reload multiple times
	DeleteThread(self.reload_thread)
	self.reload_thread = CreateRealTimeThread(function()
		Sleep(1000)
		MountOverloadFolder("CommonLua")
		MountOverloadFolder("Lua")
		MountOverloadFolder("Data")
		ReloadLua()	
	end)
end
	
--- Executes the provided Lua code in the debugger console.
---
--- This function is used to execute arbitrary Lua code in the debugger console. It sends a message to the debugger to execute the provided code.
---
--- @param code string The Lua code to execute.
function luadebugger:RemoteExec(code)
	if dlgConsole then
		dlgConsole:Exec(code)
	end
end
	
--- Sends an auto-completion list to the debugger console.
---
--- This function is used to generate an auto-completion list for the provided code and index, and send it to the debugger console.
---
--- @param code string The code to generate the auto-completion list for.
--- @param idx number The index within the code to generate the auto-completion list for.
--- @return nil
function luadebugger:RemoteAutoComplete(code, idx)
	if dlgConsole then
		local list = GetAutoCompletionList(code, idx)
		self:Send({Event="AutoCompleteList", List=list})
	end
end
	
--- Prints the provided text to the debugger console.
---
--- This function is used to print text to the debugger console. It is a convenience wrapper around the `h_print` function.
---
--- @param text string The text to print to the debugger console.
--- @return nil
function luadebugger:RemotePrint(text)
	h_print(text)
end
	
--- Evaluates the watches and returns a table of new or expanded watches.
---
--- This function is responsible for evaluating the watches and returning a table of new or expanded watches. It first checks if the debugger is in a break state, and if not, returns an empty table. It then iterates through the existing watches, evaluating any that have not been evaluated yet, and expanding any watches that are marked for expansion. Finally, it returns a table of new or expanded watches.
---
--- @return table A table of new or expanded watches.
function luadebugger:EvalWatches()
	if not self.in_break then
		return {}
	end
	local new = {}
	local old = {}
	for k, v in pairs(self.watches_results) do
		old[k] = (v.Children ~= nil)
	end
	
	for _, value_lua in pairs(self.watches) do
		if not self.watches_evaluated[value_lua] then
			self:EvalWatch(value_lua)
		end
	end
	for k in pairs(self.eval_env) do
		if not self.watches_evaluated[k] then
			self:EvalWatch(k)
		end
	end
	for value_lua in pairs(self.to_expand) do
		self:ExpandWatch(value_lua)
	end
	for k, v in pairs(self.watches_results) do
		if old[k] == nil or (old[k] == false and v.Children) then
			new[k] = v
		end
	end
	
	return new
end
	
--- Evaluates the provided expression and adds the result as a new watch.
---
--- This function is responsible for evaluating the provided expression and adding the result as a new watch. It first attempts to load the expression using `load()` and the provided `eval_env` environment. If the load is successful, it calls `pcall()` to execute the expression and get the result. If the execution is successful, it adds the expression and its result as a new watch using `self:AddWatch()`. If there is an error, it adds the expression and the error message as a new watch instead.
---
--- If the expression was marked for expansion (`self.to_expand[ToEval]`), it also calls `self:ExpandWatch()` to expand the watch.
---
--- @param ToEval string The expression to evaluate and add as a new watch.
--- @return nil
function luadebugger:EvalWatch(ToEval)
	local ok
	local r, err = load("return " .. ToEval, nil, nil, self.eval_env)
	if r then
		err = nil
		local old = config.InDebugger
		config.InDebugger = true
		local results = pack_params(pcall(r))
		config.InDebugger = old
		if results[1] then
			local res = results[2]
			if Max(#results, results.n or 0) > 2 then
				res = setmetatable({unpack_params(results, 2)}, self.__tuple_meta)
			end
			self:AddWatch(ToEval, res, ToEval, ToEval)
		else
			err = results[2]
		end
	end
	if err then
		err = string.gsub(err, "%[.+%]:%d+: ", "")
		self:AddWatch(ToEval, err, ToEval, ToEval)
	end
	
	if self.to_expand[ToEval] then
		self:ExpandWatch(ToEval)
	end
end
	
--- Expands the watch for the given Lua value.
---
--- This function is responsible for expanding the watch for the given Lua value. It first checks if the watch has already been expanded (`t.Children`). If not, it creates a new table `res` to store the expanded watch values.
---
--- If the watch is expandable (`t.Expandable`) and marked for expansion (`self.to_expand[value_lua]`), it enumerates the keys and values of the watch's value object (`self.watches_evaluated[value_lua].ValueObj`) using `self:Enum()`. For each key-value pair, it adds a new watch using `self:AddWatch()` and recursively expands the watch if it is marked for expansion (`self.to_expand[value2_lua]`).
---
--- The expanded watch values are then sorted based on their sort priority (`a.SortPriority` and `b.SortPriority`), and if the keys are numbers, they are sorted numerically. Otherwise, they are sorted lexicographically.
---
--- Finally, the expanded watch values are stored in the `t.Children` field and returned.
---
--- @param value_lua string The Lua value to expand the watch for.
--- @param new table (optional) A table to store the new watch values.
--- @return table The expanded watch values.
function luadebugger:ExpandWatch(value_lua, new)
	local t = self.watches_results[value_lua]
	if not t or t.Children then
		return
	end
	local res = {}		
	if t.Expandable and self.to_expand[value_lua] then
		local value_obj = self.watches_evaluated[value_lua].ValueObj
		for key2_obj, value2_obj, key2_lua, value2_lua, sort_priority in self:Enum(value_obj, value_lua) do
			self:AddWatch(key2_obj, value2_obj, key2_lua, value2_lua, sort_priority)
			if self.to_expand[value2_lua] then
				self:ExpandWatch(value2_lua)
			end
			table.insert(res, value2_lua)
		end
		
		local watches_results = self.watches_results
		
		table.sort(res, function(a, b)
			local a, b = watches_results[a] or empty_table, watches_results[b] or empty_table
			if (a.SortPriority or 0) ~= (b.SortPriority or 0) then
				return (a.SortPriority or 0) > (b.SortPriority or 0)
			end
			if a.KeyType == "number" and b.KeyType == "number" then
				return tonumber(a.Key) < tonumber(b.Key)
			end
			if a.KeyType == "number" then
				return true
			end
			if b.KeyType == "number" then
				return false
			end
			return CmpLower(a.Key, b.Key)
		end)
			
		t.Children = res
		return t
	end
end
	
---
--- Converts a Lua value to a string representation.
---
--- This function handles various Lua value types, including:
--- - `_G`: Returns the string "_G"
--- - `thread`: Returns the status and string representation of the thread
--- - `function`: Returns the source file and line number of the function
--- - `table`: Handles various table types, including valid objects, translations, and custom `__tostring` metamethods
--- - Other types: Returns the string representation of the value
---
--- @param v any The Lua value to convert to a string
--- @return string The string representation of the Lua value
function luadebugger:ToString(v)
	local type = type(v)
	if rawequal(v, _G) then
		return "_G"
	elseif type == "thread" then
		if coroutine.running() == v then
			return "current " .. tostring(v)
		end
		return coroutine.status(v) .. " " .. tostring(v)
	elseif type == "function" then
		local info = debug.getinfo(v)
		if info and info.short_src and info.linedefined and info.linedefined ~= -1 then
			return string.format("%s(%d)", info.short_src, info.linedefined)
		end
		return tostring(v)
	elseif type == "table" then
		if IsValid(rawget(v, 1)) then
			local str = tostring(v)
			if #str > 80 then
				return string.sub(str, 1, 80) .. "..."
			end
			return str
		end
		if IsT(v) then
			if translate_Ts then
				return _InternalTranslate(v, nil, false)
			else
				return TDevModeGetEnglishText(v, "deep", "no_assert")
			end
		elseif ObjectClass(v) then
			local suffix, num = string.gsub(tostring(v), "^table", "")
			if num == 0 then
				suffix = ""
			end
			if rawget(_G, "CObject") and IsKindOf(v, "CObject") and not IsValid(v) then
				return "invalid object" .. suffix
			else
				return "object" .. suffix
			end
		end
		for k, class in pairs(g_Classes or empty_table) do
			if v == class then
				return "class " .. k
			end
		end
		local meta = getmetatable(v)
		if meta == rawget(_G, "g_traceMeta") then
			return "trace log"
		end
		if meta and rawget(meta, "__tostring") ~= nil then
			local ok, result = pcall(meta.__tostring, v)
			return ok and result or "error in custom tostring function: " .. result
		else
			return tostring(v) .. " (len: " .. #v .. ")"
		end
	else
		return tostring(v)
	end
end
	
--- Determines the type of the given object `o`.
---
--- This function is used to get a human-readable string representation of the type of an object. It handles various types of objects, including tables, classes, and special types like points, boxes, and grids.
---
--- @param o any The object to get the type of.
--- @return string The type of the object as a string.
function luadebugger:Type(o)
	local otype = type(o)
	if otype == "table" and IsT(o) then
		return "translation"
	end
	if rawequal(o, _G) then return "table" end
	if ObjectClass(o) then
		local ctype = o.class
		local particles = IsValid(o) and g_Classes.CObject and o:IsKindOf("CObject") and o:GetParticlesName() or ""
		if type(particles) == "string" and particles ~= "" then
			ctype = ctype .. ": " .. particles
		end
		local id = rawget(o, "id") or ""
		if type(id) == "string" and id ~= "" then
			ctype = ctype .. ": " .. id
		end
		return ctype
	end
	local meta = getmetatable(o)
	if meta then
		if IsPoint(o) then
			return "Point" 
		end
		if IsBox(o) then
			return "Box" 
		end
		if IsQuaternion(o) then
			return "Quaternion" 
		end
		if IsGrid(o) then
			local pid = GridGetPID(o)
			local w, h = o:size()
			return "Grid " .. pid .. ' ' .. w .. 'x' .. h
		end
		if IsPStr(o) then
			return "pstr (#" .. #o .. ")"
		end
		if meta == __range_meta then
			return "Range"
		end
		if meta == __set_meta then
			return "Set"
		end
		if meta == self.__tuple_meta then
			return "tuple (#" .. table.count(o) .. ")"
		end
		-- check for UI
		if meta == self.__threadmeta then
			return "thread level info"
		end
	end
	if otype == "string" then
		return "string (#" .. #o .. ")"
	end
	if otype == "table" then
		return "table (#" .. table.count(o) .. ")"
	end
	if otype == "function" then
		if IsCFunction(o) then
			return "C function"
		end
		return "function"
	end
	return otype
end

---
--- Ages the handles in the luadebugger object.
---
--- This function iterates through the `handle_to_obj` table and increments the age of each handle. If the age of a handle reaches 1, the handle is removed from both the `handle_to_obj` and `obj_to_handle` tables.
---
--- @param self luadebugger The luadebugger object.
---
function luadebugger:AgeHandles()
	for k, v in pairs(self.handle_to_obj) do
		if v.age >= 1 then
			self.obj_to_handle[v.obj] = nil
			self.handle_to_obj[k] = nil
		else
			v.age = v.age + 1
		end
	end
end
	
---
--- Gets a handle for the given object.
---
--- If the object does not have a handle yet, a new handle is created and added to the `handle_to_obj` and `obj_to_handle` tables. The age of the handle is set to 0.
---
--- @param self luadebugger The luadebugger object.
--- @param obj any The object to get a handle for.
--- @return integer The handle for the object.
---
function luadebugger:GetHandle(obj)
	local handle = self.obj_to_handle[obj]
	if handle == nil then
		handle = #self.handle_to_obj + 1
		self.handle_to_obj[handle] = {obj=obj, age=0}
		self.obj_to_handle[obj] = handle
	end
	self.handle_to_obj[handle].age = 0
	return handle
end
	
---
--- Gets the object associated with the given handle.
---
--- If the handle is valid, the associated object is returned with its age reset to 0. If the handle is not valid, `nil` is returned.
---
--- @param self luadebugger The luadebugger object.
--- @param handle integer The handle of the object to retrieve.
--- @return any The object associated with the given handle, or `nil` if the handle is not valid.
---
function luadebugger:GetObj(handle)
	local obj_desc = self.handle_to_obj[handle]
	if obj_desc ~= nil then
		obj_desc.age = 0
		return obj_desc.obj
	end
	return nil
end
	
---
--- Formats the index expression for a table access.
---
--- This function takes a string representation of the table expression (`to_index`) and the key (`k`) being accessed, and returns the formatted index expression and the key as a string.
---
--- If the key is a number or boolean, it is returned as a string and the index expression is `[key]`.
--- If the key is a string that matches the pattern `^[_%a][_%w]*$`, it is returned as a string and the index expression is `.key`.
--- If the key is a string that does not match the pattern, it is returned as a string and the index expression is `[ "key" ]`.
--- If the key is any other type, the handle for the key object is retrieved and the index expression is `[g_LuaDebugger:GetObj(g_LuaDebugger:GetHandle(key))]`.
---
--- @param to_index string The string representation of the table expression.
--- @param k any The key being accessed.
--- @return string, string The formatted key and index expression.
---
function luadebugger:FormatIndex(to_index, k)
	to_index = "(" .. to_index .. ")"
	if type(k) == "number" or type(k) == "boolean" then
		return tostring(k), to_index .. "[" .. tostring(k) .. "]"
	elseif type(k) == "string" then
		if string.match(k, "^[_%a][_%w]*$") then
			return StringToLuaCode(k), to_index .. "." .. k
		else
			return StringToLuaCode(k), to_index .. "[ " .. StringToLuaCode(k).. " ]"
		end
	else
		local expr = "g_LuaDebugger:GetObj(" .. g_LuaDebugger:GetHandle(k) .. ")"
		return expr, to_index .. "[" .. expr .. "]"
	end
end
	
---
--- Enumerates the values in a table, function, or thread.
---
--- This function returns an iterator that can be used to enumerate the values in a table, function, or thread. The iterator returns the key, value, formatted key expression, and formatted value expression for each element.
---
--- For tables, the iterator returns the key and value, along with the formatted key and value expressions. For functions, the iterator returns the upvalue name and value, along with the formatted upvalue expression. For threads, the iterator returns the local variable name and value, along with the formatted local variable expression.
---
--- @param self luadebugger The luadebugger object.
--- @param value any The value to enumerate.
--- @param value_str string The string representation of the value.
--- @return function The iterator function.
---
function luadebugger:Enum(value, value_str)
	local vtype = type(value)
	if vtype == "table" then
		local metatable = getmetatable(value)
		if metatable == self.__threadmeta then
			local up, l = 1, 1
			local info = value.info
			return function()
				if up then
					if up <= info.nups then
						local name, val = debug.getupvalue(info.func, up)
						up = up + 1
						return (name or "") .. "(upvalue)", val, "", "g_LuaDebugger:GetUpvalue(" .. value_str .. "," .. up .. ")", 1
					else
						up = false
					end
				end
				if not up then
					local name, val = debug.getlocal (value.thread, value.level, l) 
					if not name then
						return
					end
					l = l + 1
					return (name or "") .. "(local)", val, "", "g_LuaDebugger:GetLocal(" .. value_str .. "," .. l .. ")", 2
				end
			end
		else
			local key
			local meta
			return function()
				if not meta then
					meta = true
					local m = metatable
					if m and m ~= self.__tuple_meta then
						return "metatable", m, "", "getmetatable(".. value_str ..")", 1
					end
				end
				local v
				key, v = next(value, key)
				if v == nil then
					return
				end
				local key_str, value_str = self:FormatIndex(value_str, key)
				return key, v, key_str, value_str
			end
		end
	elseif vtype == "function" then
		local up = 1
		local info = debug.getinfo(value, "u")
		return function()
			if up <= info.nups then
				local name, val = debug.getupvalue(value, up)
				up = up + 1
				return tostring(name) .. "(upvalue)", val, "", "g_LuaDebugger:GetFnUpvalue(" .. value_str .. "," .. up .. ")", 1
			end
		end
	elseif vtype == "thread" then
		local level = 0
		return function()
			local k = self:ThreadKeyWrapper(value, level)
			if not k then
				return
			end
			local v = self:ThreadValueWrapper(value, level)
			level = level + 1
			return k, v, "", "g_LuaDebugger:ThreadValueWrapper(" .. value_str .. "," .. level .. ")", -level
		end
	else
		return function()
		end
	end
end
	
---
--- Gets the upvalue at the specified index for the given function.
---
--- @param fn function The function to get the upvalue from.
--- @param i integer The index of the upvalue to get.
--- @return any The value of the upvalue at the specified index.
function luadebugger:GetFnUpvalue(fn, i)
	local _, v = debug.getupvalue(fn, i)
	return v
end
	
---
--- Gets the upvalue at the specified index for the given function.
---
--- @param thread_wrapper table The thread wrapper containing the function and level information.
--- @param i integer The index of the upvalue to get.
--- @return any The value of the upvalue at the specified index.
function luadebugger:GetUpvalue(thread_wrapper, i)
	local _, v = debug.getupvalue(thread_wrapper.info.func, i)
	return v
end

---
--- Gets the local variable at the specified index for the given thread.
---
--- @param thread_wrapper table The thread wrapper containing the thread and level information.
--- @param i integer The index of the local variable to get.
--- @return any The value of the local variable at the specified index.
function luadebugger:GetLocal(thread_wrapper, i)
	local _, v = debug.getlocal(thread_wrapper.thread, thread_wrapper.level, i)
	return v
end
	
---
--- Wraps a Lua thread with metadata to provide additional information.
---
--- @param thread table The Lua thread to wrap.
--- @param level integer The stack level of the thread.
--- @return table A wrapped thread object with additional metadata.
function luadebugger:ThreadKeyWrapper(thread, level)
	local info = debug.getinfo(thread, level, "Slfun")
	if info then
		local v = { type = "key", thread = thread, level = level, info = info }
		setmetatable(v, self.__threadmeta)
		return v
	end
end

---
--- Wraps a Lua thread with metadata to provide additional information.
---
--- @param thread table The Lua thread to wrap.
--- @param level integer The stack level of the thread.
--- @return table A wrapped thread object with additional metadata.
function luadebugger:ThreadValueWrapper(thread, level)
	local info = debug.getinfo(thread, level, "Slfun")
	if info then
		local v = { type = "value", thread = thread, level = level, info = info }
		setmetatable(v, self.__threadmeta)
		return v
	end
end
		
---
--- Determines if the given value is expandable in the debugger.
---
--- @param v any The value to check for expandability.
--- @return boolean True if the value is expandable, false otherwise.
function luadebugger:IsExpandable(v)
	local type = type(v)
	local meta = getmetatable(v)
	if meta == self.__threadmeta and meta.type == "key" then
		return false
	end
	if coroutine.running () == v then
		return false
	end
	return type == "thread" or type == "function" or type == "table"
end

---
--- Checks if the given value is a valid position.
---
--- @param v any The value to check for a valid position.
--- @return boolean True if the value is a valid position, false otherwise.
function IsValidPos(v)
	return rawget(_G, "IsValidPos") or empty_func(v)
end
local IsValidPos = rawget(_G, "IsValidPos") or empty_func
---
--- Determines the custom views for a given value in the debugger.
---
--- @param luav any The Lua value to determine custom views for.
--- @param v any The value to determine custom views for.
--- @return table A table of custom view definitions, where each entry has the following fields:
---   - MenuText (string): The text to display in the menu for the custom view.
---   - Viewer (string): The name of the custom viewer to use.
---   - Expression (string, optional): An expression to evaluate and display in the custom viewer.
function luadebugger:CustomViews(luav, v)
	local type = type(v)
	if type == "string" or IsPStr(v) then
		return {{MenuText="Inspect as String", Viewer = "Text"}}
	end
	if type == "function" then
		if IsCFunction(v) then
			return
		end
		local info = debug.getinfo(v, "Sln")
		return {{MenuText="Open source file", Viewer = "OpenFile", Expression = info.short_src .. "(" ..  info.linedefined .. ")"}}			
	end
	if type == "table" and getmetatable(v) == self.__threadmeta then
		return {{MenuText="Open source file", Viewer = "OpenFile", Expression = v.info.short_src .. "(" ..  v.info.currentline .. ")"}}
	end
	if IsValidPos(v) then
		return {{MenuText="View InGame", Viewer = "ViewInGame"}}
	end
	if IsGrid(v) then
		return {{MenuText="View as Image", Viewer = "FloatGridAsImage", Expression = luav}}
	end
end
	
---
--- Adds a watch to the debugger.
---
--- @param key_obj any The key object to watch.
--- @param value_obj any The value object to watch.
--- @param key_lua string The Lua representation of the key.
--- @param value_lua string The Lua representation of the value.
--- @param sort_priority number The sort priority of the watch.
function luadebugger:AddWatch(key_obj, value_obj, key_lua, value_lua, sort_priority)
	self.watches_results[value_lua] = {
		KeyLua = key_lua, 
		ValueLua = value_lua, 
		Key = self:ToString(key_obj), 
		Value = self:ToString(value_obj), 
		KeyType = self:Type(key_obj), 
		ValueType = self:Type(value_obj),
		Expandable = self:IsExpandable(value_obj),
		CustomViews = self:CustomViews(value_lua, value_obj),
		SortPriority = sort_priority
	}
	self.watches_evaluated[value_lua] = 
	{
		KeyObj = key_obj, 
		ValueObj = value_obj
	}
end
	
---
--- Sends a table to the debugger's send buffer.
---
--- @param t table The table to send to the debugger.
function luadebugger:Send(t)
	table.insert(self.to_send, t)
end
	
---
--- Receives and processes a packet from the debugger.
---
--- @param t table The packet data.
--- @param packet string The raw packet string.
function luadebugger:Received(t, packet)
	if not t or not t.command then
		h_print("no command found in packet " .. packet)
	else
		--h_print(t.command .. " size : " .. #packet)
		local handler = rawget(self, t.command) or rawget(luadebugger, t.command)
		
		if not handler then
			h_print("the command " .. t.command .. " is not recognized in packet " .. packet)
		else
			self.last_received = t
			handler(self, unpack_params(t.parameters))
		end
	end
end
	
---
--- Clears all breakpoints set in the debugger.
---
function luadebugger:ClearBreakpoints()
	DebuggerClearBreakpoints()
end
	
---
--- Receives and processes a packet from the debugger.
---
--- @param packet string The raw packet string.
function luadebugger:ReadPacket(packet)
	if self.binary_mode then
		local callback = self.binary_handler
		if (not callback or type(callback) ~= "function") then
			assert(false, "No callback to process binary stream!")
			self.binary_mode = false
		else				
			callback(packet)			
			return
		end
	end
	local r, err = load("return " .. packet)
	if r then
		local ok, r = pcall(r)
		if ok then
			self:Received(r, packet)
		else
			h_print("while loadind string " .. packet)
		end
	else
		h_print(err)
		h_print("while loadind string " .. packet)
	end
end
	
---
--- Ticks the debugger, sending any pending messages and processing incoming packets.
---
--- This function is responsible for the main loop of the debugger, sending any messages that
--- have been queued up and processing any incoming packets from the debugger server.
---
--- If the debugger is in a break state, this function will only send messages and not process
--- any incoming packets until the break state is cleared.
---
--- @return boolean True if the debugger is still connected, false if the connection has been lost.
---
function luadebugger:DebuggerTick()
	local server = self.server
	if not self.in_break or #server.send_buffer == 0 then
		while #self.to_send > 0 do
			local to_send, data = self.to_send[1]
			if type(to_send) == "function" then
				to_send, data = to_send()
			end
			if data then
				server:send("!", data)
			end
			local s = DbgLuaCode(to_send)
			server:send(s)
			table.remove(self.to_send, 1)
			s = nil
			if self.in_break then
				break
			end
		end
	end
	if not server.update then
		assert(false)
	end
	server:update()
	while true do
		local packet = server:readpacket()
		if packet then
			self:ReadPacket(packet)	
		else
			break
		end
	end
	if server:isdisconnected() then
		h_print("Disconnected")
		return false
	end
	return true
end
	
---
--- Captures the variables in the current scope of the given coroutine or stack level.
---
--- This function retrieves the local variables and upvalues for the specified coroutine or stack level.
--- It returns a table containing the variable names and their values, with nil values represented as a special entry in the table.
---
--- @param co Coroutine (optional) The coroutine to capture variables from. If not provided, the current stack level is used.
--- @param level Integer The stack level to capture variables from.
--- @return table The table of captured variables.
---
function luadebugger:CaptureVars(co, level)
	local vars = {}
	local info
	if co then
		info = debug.getinfo(co, level, "fu")
	else
		info = debug.getinfo(level, "fu")
	end
	local func = info and info.func or nil
	if not func then return vars end
	local i = 1
	local nils = {}
	local function capture(name, value)
		if name then
			if rawequal(value, nil) then
				nils[name] = true
			else
				vars[name] = value
			end
			return true
		end
	end
	if co then
		while capture(debug.getlocal(co, level, i)) do
			i = i + 1
		end
	else
		while capture(debug.getlocal(level, i)) do
			i = i + 1
		end
	end
	for i = 1, info.nups do
		capture(debug.getupvalue(func, i))
	end

	return setmetatable(vars, { __index = function (t, key)
		if nils[key] then
			return nil
		end
		return rawget(_G, key)
	end })
end

--- This function retrieves the call stack and local variables for the specified coroutine or stack level.
---
--- @param co Coroutine (optional) The coroutine to capture the call stack and variables from. If not provided, the current stack level is used.
--- @param level Integer The stack level to capture the call stack and variables from.
--- @return table The table of captured call stack information.
--- @return table The table of captured local variables.
---
function luadebugger:GetCallInfo(co, level)
	local stack_vars = {}
	local call_stack = {}
	local i = 1
	local start_level = level + (co and 0 or 1) - 1  -- -1 here offset the i being 1 based
	while i < 100 do
		local info
		if co then
			info = debug.getinfo(co, i+start_level, "Sln")
		else
			info = debug.getinfo(i+start_level, "Sln")
		end
		if not info then break end
		if info.what ~= "C" then
			stack_vars[i] = self:CaptureVars(co, i+start_level+(co and 0 or 1))
			
			local source = string.gsub(info.source, "^@", "") or ""
			local nl = string.find(source, "\n") or 0
			source = string.sub(source, 1, nl - 1)
			call_stack[i] = {
				Source = source,
				Line = info.currentline or 0,
				Name = tostring(info.name or "?"),
				NameWhat = tostring(info.namewhat)
			}
		else
			stack_vars[i] = self:CaptureVars(co, i+start_level+(co and 0 or 1))
			call_stack[i] = {
				Source = "C function",
				Line = 0,
				Name = tostring(info.name or "?"),
				NameWhat = ""
			}
		end
		i = i + 1
	end
	
	return call_stack, stack_vars
end
	
--- Starts the Lua debugger and initializes the necessary components.
---
--- This function sets up the Lua debugger, connects to the remote debugger server, and performs various initialization tasks. It handles the connection process, sets up path remapping, and configures the debugger's behavior. Once the debugger is started, it enters a loop to handle debugger ticks until the debugger is stopped.
---
--- @return boolean true if the debugger was successfully started, false otherwise
function luadebugger:Start()
	if self.started then
		return
	end
	h_print("Starting...");
	DebuggerInit()
	DebuggerClearBreakpoints()
	self.started = true

	local server = self.server
	--server.log_enabled = true
	local debugger_port = controller_port+2
	if config.ForceDebuggerPort then
		debugger_port = config.ForceDebuggerPort
	end
	--
	controller_host = not Platform.pc and config.Haerald and config.Haerald.ip or "localhost"
	server:connect(controller_host, debugger_port)
	server:update()
	if not server:isconnected() then
		if Platform.pc then
			local processes = os.enumprocesses()
			local running = false
			for i = 1, #processes do
				if string.find(processes[i], "Haerald.exe") then
					--h_print("Connecting to running debugger", processes[i])
					running = true
					break
				end
			end
			
			if not running and not config.AlternativeDebugger then
				local os_path = ConvertToOSPath(config.HaeraldPath)
				--h_print("Starting the debugger form", os_path);
				local exit_code, std_out, std_error = os.exec(os_path)
				if exit_code ~= 0 then
					h_print("Could not launch from:", os_path, "\nExec error:", std_error)
					self:Stop()
					return
				end
			end
		end
		
		local total_timeout = 6000
		local retry_timeout = Platform.pc and 100 or 2000
		local steps_before_reset = Platform.pc and 10 or 1
		
		local num_retries = total_timeout / retry_timeout
		for i = 1, num_retries do
			server:update()
			if server:isconnected() then
				break
			end
			if not server:isconnecting() or (i % steps_before_reset) == 0 then
				server:close()
				server:connect(controller_host, debugger_port, retry_timeout)
			end
			os.sleep(retry_timeout)
		end
		
		if not server:isconnected() then
			h_print("Could not connect to debugger at "..controller_host..":"..debugger_port)
			self:Stop()
			return
		end
	end
	server.timeout = 5000
	self.watches = {}
	self.handle_to_obj = {}
	self.obj_to_handle = {}
	
	local PathRemapping = config.Haerald and config.Haerald.PathRemapping
	if not PathRemapping and IsFSUnpacked() then
		PathRemapping = {
			["CommonLua"] = "CommonLua",
			["Lua"] = Platform.cmdline and "" or "Lua",
			["Data"] = Platform.cmdline and "" or "Data",
			["svnProject/Dlc"] = Platform.cmdline and "" or "svnProject/Dlc",
			["Swarm"] = "CommonLua/../Swarm",
			["Tools"] = "CommonLua/../Tools",
			["Shaders"] = "Shaders",
			["Mods"] = Platform.cmdline and "" or "AppData/Mods",
		}
		for _, mod in ipairs(rawget(_G, "ModsLoaded")) do
			if not mod.packed then
				PathRemapping["Mod/" .. mod.id] = mod.path
			end
		end
		for key, value in pairs( PathRemapping ) do
			if value ~= "" then
				local game_path = value .. "/."
				local os_path, failed = ConvertToOSPath(game_path)
				if failed or not io.exists(os_path) then
					os_path = nil
				end
				PathRemapping[key] = os_path
			end
		end
		--PathRemapping["/"] = Platform.cmdline and GetCWD() or ConvertToOSPath(".")
	end
	
	local SourcesDirectory = config.Haerald and config.Haerald.SourcesDirectory
	if not SourcesDirectory and IsFSUnpacked() then
		SourcesDirectory = ConvertToOSPath("CommonLua/..")
	end
	
	local FileDictionaryPath = config.Haerald and config.Haerald.FileDictionaryPath or {
		"CommonLua",
		"Lua",
		"svnProject/Dlc",
		"Swarm",
		"Tools",
		"Mods",
		"Mod"
	}	
	local FileDictionaryExclude = config.Haerald and config.Haerald.FileDictionaryExclude or { 
		".svn",
		"__load.lua",
		".prefab.lua",
		"/Storage/",
	}
	local PropFormatList = config.Haerald and config.Haerald.PropFormatList or {
		"category", 
		"id", 
		"name", 
		"editor", 
		"default",
	}
	local FileDictionaryIgnore = config.Haerald and config.Haerald.FileDictionaryIgnore or {
		"^exec$",
		"^items$",
		"^filter$",
		"^action$",
		"^state$",
		"^f$",
		"^func$",
		"^no_edit$",
	}
	local SearchExclude = config.Haerald and config.Haerald.SearchExclude or {
		".svn",
		"/Prefabs/",
		"/Storage/",
		"/Collections/",
		"/BuildCache/",
	}
	local TablesToKeys = {}
	--[[
	local TableDictionary = config.Haerald and config.Haerald.TableDictionary or {
		"const", "config", "hr", "Platform", "EntitySurfaces", "terrain", "ShadingConst",
		"table", "coroutine", "debug", "io", "os", "string",
	}
	for i=1,#TableDictionary do
		local name = TableDictionary[i]
		local t = rawget(_G, name)
		local keys = type(t) == "table" and table.keys(t) or ""
		if type(keys) == "table" then
			local vars = EnumEngineVars(name .. ".")
			for key in pairs(vars) do
				keys[#keys + 1] = key
			end
			if #keys > 0 then
				table.sort(keys)
				TablesToKeys[name] = keys
			end
		end
	end
	--]]
	local InitPacket = {
		Event = "InitPacket",
		PathRemapping = PathRemapping or {},
		ExeFileName = string.gsub(GetExecName(), "/", "\\"),
		ExePath = string.gsub(GetExecDirectory(), "/", "\\"),
		CurrentDirectory = Platform.pc and string.gsub(GetCWD(), "/", "\\") or "",
		SourcesDirectory = SourcesDirectory,
		FileDictionaryPath = FileDictionaryPath,
		FileDictionaryExclude = FileDictionaryExclude,
		PropFormatList = PropFormatList,
		FileDictionaryIgnore = FileDictionaryIgnore,
		SearchExclude = SearchExclude,
		TablesToKeys = TablesToKeys,
		ConsoleHistory = rawget(_G, "LocalStorage") and LocalStorage.history_log or {},
	}

	InitPacket.Platform = GetPlatformName()
	
	if Platform.console or Platform.ios then
		InitPacket.UploadData = "true"
		InitPacket.UploadPartSize = config.Haerald and config.Haerald.UploadPartSize or 2*1024*1024
		InitPacket.UploadFolders = config.Haerald and config.Haerald.UploadFolders or {}
	end
	
	local project_name = const.ProjectName
	if not project_name then
		local dir, filename, ext = SplitPath(GetExecName())
		project_name = filename or "unknown"
	end
	InitPacket.ProjectName = project_name
	self:Send(InitPacket)
	
	for i = 1, 500 do
		if not self:DebuggerTick() then
			break
		end
		if self.init_packet_received then
			break
		end
		os.sleep(10)
	end
	
	if not self.init_packet_received then
		h_print("Didn't receive initialization packages (maybe the debugger is taking too long to upload the files?)")
		self:Stop()
		return
	end
	
	UpdateThreadDebugHook()
	
	if DebuggerTracingEnabled() then
		local coroutine_resume, coroutine_status = coroutine.resume, coroutine.status
		SetThreadResumeFunc(function(thread)
			collectgarbage("stop")
			DebuggerPreThreadResume(thread)
			local r1, r2 = coroutine.resume(thread)
			local time = DebuggerPostThreadYield(thread)
			collectgarbage("restart")
			assert(time < 15 * 1000)
			if coroutine_status(thread) ~= "suspended" then
				DebuggerClearThreadHistory(thread)
			end
			return r1, r2
		end)
	end
	DeleteThread(self.update_thread)
	self.update_thread = CreateRealTimeThread(function()
		h_print("Connected.")
		while self:DebuggerTick() do
			Sleep(25)
		end
		self:Stop()
	end)
	
	if Platform.console and not Platform.switch then
		-- check whether shaders were requested while the debugger was not connected
		RemoteCompileRequestShaders()
	end
end
	
---
--- Stops the Lua debugger and cleans up associated resources.
---
--- @param disabledPrint boolean (optional) If true, suppresses printing a deactivation message.
---
function luadebugger:Stop(disabledPrint)
	if not self.started then
		if not disabledPrint then h_print("Not currently active!") end
		return
	end
	DebuggerDone()

	self.handle_to_obj = {}
	self.obj_to_handle = {}

	self.server:close()
	

	if not disabledPrint then h_print("Deactivated.") end
	local thread = self.update_thread
	self.update_thread = false
	self.started = false
	g_LuaDebugger = false
	-- clear hooks of currently existing threads and main chunk
	UpdateThreadDebugHook() --this uses g_LuaDebugger to determine what to do;
	DeleteThread(thread, true)
end

---
--- Retrieves the global `g_LuaDebugger` variable, or `false` if it does not exist.
---
--- This is a convenience function to safely access the `g_LuaDebugger` global variable,
--- which may or may not be defined depending on the state of the application.
---
--- @return table|boolean g_LuaDebugger or `false` if it does not exist
---
g_LuaDebugger = rawget(_G, "g_LuaDebugger") or false

---
--- Sets up the remote debugger configuration.
---
--- @param ip string The IP address of the remote host.
--- @param srcRootPath string The root path of the source code.
--- @param projectFolder string The folder name of the project.
---
function SetupRemoteDebugger(ip, srcRootPath, projectFolder)
	config.Haerald = config.Haerald or {}
	local projectPath = srcRootPath.."\\"..projectFolder
	h_print("Setting up for remote debugging...")
	h_print("Source  root: " .. srcRootPath)
	h_print("Project root: " .. projectPath)
	h_print("Host ip: " .. ip)
	
	config.Haerald.RemoteRoot = srcRootPath
	config.Haerald.ProjectFolder = projectFolder
	config.Haerald.ProjectAssetsPath = projectPath.."Assets"
	config.Haerald.UploadPartSize = 2*1024*1024
	config.Haerald.ip = ip
	
	local platform = GetPlatformName()
	local shader_config = {}
	shader_config.ListFilePath = string.format("%s\\BuildCache\\%s\\ShaderListRemote.txt", config.Haerald.ProjectAssetsPath, platform)	
	shader_config.ShaderCachePath = string.format("%s\\BuildCache\\%s\\ShaderCacheRemote", config.Haerald.ProjectAssetsPath, platform)
	shader_config.BuildTool = string.format("%s\\%s\\Build.bat", srcRootPath, projectFolder)
	shader_config.BuildArgs = "ShaderCacheRemote-" .. platform .. " --err_msg_limit=false"
	config.Haerald.CompileShaders = shader_config
	
	config.Haerald.PathRemapping = {
		["Lua"] = projectPath.."\\Lua",
		["Data"] = projectPath.."\\Data",
		["Dlc"] = projectPath.."\\Dlc",
		["CommonLua"] = srcRootPath.."\\CommonLua",
		["Swarm"] = srcRootPath.."\\Swarm",
		["Tools"] = srcRootPath.."\\Tools",
		["ShaderCache"] = shader_config.ShaderCachePath,
		["Shaders"] = srcRootPath.."\\HR\\Shaders",
	}
end

---
--- Starts the Lua debugger if it has not already been started.
---
--- If the `g_LuaDebugger` global variable is not defined or has not been started, this function will create a new instance of the Lua debugger and start it. If the `g_LuaDebugger` global variable is defined but has not been started, this function will set it to `false` before creating a new instance.
---
--- If the application is running on a console platform, this function will also set up the remote debugger configuration using the `SetupRemoteDebugger` function.
---
--- @function StartDebugger
--- @return nil
function StartDebugger ()
	if g_LuaDebugger and not g_LuaDebugger.started then
		g_LuaDebugger = false
	end
	if not g_LuaDebugger  then
		if Platform.console then
			config.Haerald = config.Haerald or {}
			SetupRemoteDebugger(config.Haerald and config.Haerald.ip or "localhost", config.Haerald.RemoteRoot or "", config.Haerald.ProjectFolder or "")
		end
		g_LuaDebugger = luadebugger:new()
		g_LuaDebugger:Start()
	end
end

---
--- Stops the Lua debugger if it has been started.
---
--- If the `g_LuaDebugger` global variable is defined and has been started, this function will stop the Lua debugger and set the `g_LuaDebugger` variable to `false`.
---
--- @function StopDebugger
--- @return nil
function StopDebugger()
	if g_LuaDebugger then
		g_LuaDebugger:Stop()
		g_LuaDebugger = false
	end
end

---
--- Starts the Lua debugger and breaks execution at the specified coroutine and offset.
---
--- If the `g_LuaDebugger` global variable is not defined or has not been started, this function will create a new instance of the Lua debugger and start it. If the `g_LuaDebugger` global variable is defined but has not been started, this function will set it to `false` before creating a new instance.
---
--- This function will enable the Lua debugger hook and break execution at the specified coroutine and offset.
---
--- @param co Coroutine to break execution at
--- @param break_offset Offset within the coroutine to break execution at
--- @function _G.startdebugger
--- @return nil
function _G.startdebugger(co, break_offset)
	StartDebugger()
	if g_LuaDebugger then
		DebuggerEnableHook(true)
		g_LuaDebugger:Break(co, break_offset)
	end
end

---
--- Opens the specified file and line in the Lua debugger, breaking execution at that point.
---
--- If the `g_LuaDebugger` global variable is defined and has been started, this function will call the `BreakInFile` method on the Lua debugger instance, passing the specified file, line, and optional status text.
---
--- @param file The file path to open in the debugger
--- @param line The line number to break execution at
--- @param status_text Optional status text to display in the debugger
--- @function _G.openindebugger
--- @return nil
function _G.openindebugger(file, line, status_text)
	StartDebugger()
	if g_LuaDebugger then
		g_LuaDebugger:BreakInFile(file, line, status_text)
	end
end

---
--- Opens the specified file and line in the Lua debugger, breaking execution at that point.
---
--- If the `g_LuaDebugger` global variable is defined and has been started, this function will call the `OpenFile` method on the Lua debugger instance, passing the specified file and line.
---
--- @param file The file path to open in the debugger
--- @param line The line number to break execution at
--- @function _G.openineditor
--- @return nil
function _G.openineditor(file, line)
	StartDebugger()
	if g_LuaDebugger then
		g_LuaDebugger:OpenFile(file, line)
	end
end

---
--- Disables the Lua debugger hook during Lua reload for performance reasons.
---
--- This function is called when the `OnMsg.ReloadLua` event is triggered, which occurs when the Lua code is reloaded. By disabling the debugger hook, the code can be reloaded more quickly without stopping on breakpoints.
---
--- @function OnMsg.ReloadLua
--- @return nil
function OnMsg.ReloadLua() -- disable hook (do not stop on breakpoints) during lua reload for performance reasons
	DebuggerEnableHook(false)
end

---
--- Enables the Lua debugger hook after Lua code has been reloaded.
---
--- This function is called when the `OnMsg.ClassesBuilt` event is triggered, which occurs after the Lua code has been reloaded. By enabling the debugger hook, the code can be debugged again after the reload.
---
--- @function OnMsg.ClassesBuilt
--- @return nil
function OnMsg.ClassesBuilt() -- enable hook (stop on breakpoints) after lua reload
	DebuggerEnableHook(true)
end

---
--- Breaks the Lua debugger and optionally sets a break offset.
---
--- If no arguments are provided, or the first argument is truthy, this function will start the Lua debugger and enable the debugger hook. If the `g_LuaDebugger` global variable is defined, it will call the `Break` method on the Lua debugger instance, optionally passing a break offset as the second argument.
---
--- @param ... Optional arguments:
---   - The first argument is a boolean, if truthy the debugger will be started and the hook enabled.
---   - The second argument is a number, the break offset to pass to the `Break` method.
--- @return nil
function _G.bp(...)
end
_G.bp = function(...)
	if select("#", ...) == 0 or select(1, ...) then
		StartDebugger()
		DebuggerEnableHook(true)
		if g_LuaDebugger then
			local break_offset = select(2, ...)
			g_LuaDebugger:Break(nil, break_offset)
		end
	end
end

---
--- Breaks the Lua debugger and triggers the debugger's `Break` method.
---
--- This function is called from C code and passes the `self` parameter to the Lua debugger's `Break` method.
---
--- @function hookBreakLuaDebugger
--- @return nil
function hookBreakLuaDebugger()
end
function hookBreakLuaDebugger() -- called from C so we can pass the self param
	if g_LuaDebugger then
		g_LuaDebugger:Break()
	end
end

---
--- Compiles a list of shaders on the remote server if the platform is not in goldmaster mode.
---
--- This function retrieves a list of shaders that need to be compiled from the `RemoteCompileGetShadersList()` function. If the `g_LuaDebugger` global variable is defined, it calls the `CompileShaders()` method on the Lua debugger instance, passing the list of shaders.
---
--- @function RemoteCompileRequestShaders
--- @return nil
function RemoteCompileRequestShaders()
	if Platform.goldmaster then return end
	local list = RemoteCompileGetShadersList()
	if g_LuaDebugger and list and #list > 0 then
		g_LuaDebugger:CompileShaders(list)
	end
end

---
--- Opens a file and line in the Herald debugger.
---
--- This function starts the Lua debugger and opens the specified file and line in the Herald debugger.
---
--- @param file string The file path to open.
--- @param line number The line number to open.
--- @return nil
function OpenFileLineInHaerald(file, line)
	StartDebugger()
	if g_LuaDebugger then
		g_LuaDebugger:OpenFile(file, line - 1)
	end
end
