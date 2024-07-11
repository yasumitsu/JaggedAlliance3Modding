local optimizations = {
	[string.gsub("function %b() return true end", " ", "%%s*")] = "return_true",
	[string.gsub("function %b() return false end", " ", "%%s*")] = "empty_func",
	[string.gsub("function %b() return end", " ", "%%s*")] = "empty_func",
}

---
--- Returns a function that retrieves a sorted list of variable names in scope for the given object.
---
--- @param obj table The object to retrieve the variables in scope for.
--- @return function A function that returns a sorted list of variable names in scope for the given object.
function ScriptVarsCombo()
	return function(obj)
		return table.keys2(obj:VarsInScope(), "sorted", "")
	end
end

DefineClass.ScriptBlock = {
	__parents = { "Container" },
	ContainerClass = "",
	ContainerAddNewButtonMode = "floating_combined",
	EditorName = false,
	EditorSubmenu = false,
	StoreAsTable = true,
	ScriptDomain = false,
}

---
--- Returns a sorted list of variable names in scope for the given ScriptBlock object.
---
--- @param self ScriptBlock The ScriptBlock object to retrieve the variables in scope for.
--- @return table A sorted list of variable names in scope for the given ScriptBlock object.
function ScriptBlock:VarsInScope()
	local vars = self:GatherVarsFromParentStatements{}
	vars[""] = nil -- skip "" vars due to unset properties
	return vars
end

---
--- Recursively gathers all variables in scope for the current ScriptBlock and its parent ScriptBlocks.
---
--- @param self ScriptBlock The current ScriptBlock object.
--- @param vars table An optional table to store the gathered variables in.
--- @return table The table of variables in scope for the current ScriptBlock and its parents.
function ScriptBlock:GatherVarsFromParentStatements(vars)
	local parent = GetParentTableOfKindNoCheck(self, "ScriptBlock")
	if not parent then return vars end
	
	for _, item in ipairs(parent) do
		if item == self then break end
		item:GatherVars(vars)
	end
	parent:GatherVars(vars)
	return parent:GatherVarsFromParentStatements(vars)
end

---
--- Gathers all variables in scope for the current ScriptBlock.
---
--- @param self ScriptBlock The current ScriptBlock object.
--- @param vars table An optional table to store the gathered variables in.
--- @return table The table of variables in scope for the current ScriptBlock.
function ScriptBlock:GatherVars(vars)
end

---
--- Filters the sub-items of a ScriptBlock to exclude ScriptValue items.
---
--- @param self ScriptBlock The ScriptBlock instance.
--- @param class table The class of the sub-item to be filtered.
--- @return boolean True if the sub-item should be included, false otherwise.
function ScriptBlock:FilterSubItemClass(class)
	if self.ContainerClass == "ScriptBlock" and IsKindOf(class, "ScriptValue") then
		return false
	end
	return true
end

---
--- Recursively generates the code for all sub-items of the current ScriptBlock.
---
--- @param self ScriptBlock The current ScriptBlock object.
--- @param pstr string The string to append the generated code to.
--- @param indent string The current indentation level.
function ScriptBlock:GenerateCode(pstr, indent)
	indent = indent and indent .. "\t" or ""
	for i = 1, #self do
		self[i]:GenerateCode(pstr, indent)
	end
end

---
--- Recursively generates a human-readable script representation for the current ScriptBlock and its sub-items.
---
--- @param self ScriptBlock The current ScriptBlock object.
--- @param pstr string The string to append the generated script to.
--- @param indent string The current indentation level.
function ScriptBlock:GetHumanReadableScript(pstr, indent)
	pstr:append(indent, _InternalTranslate(self:GetProperty("EditorView"), self, false), "\n")
	indent = indent .. "\t"
	for _, block in ipairs(self) do
		block:GetHumanReadableScript(pstr, indent)
	end
end

---
--- Returns a formatted string with the location of the currently edited script.
---
--- @return string The formatted string with the location of the currently edited script.
function ScriptBlock:GetEditedScriptStatusText()
	local preset = GetParentTableOfKind(g_EditedScript, "Preset")
	return string.format("<style GedHighlight>Located in %s %s", preset.class, preset.id)
end

---
--- Generates a human-readable description of a script object.
---
--- @param obj ScriptProgram The script object to generate the description for.
--- @param filter function An optional filter function to apply to the script object.
--- @param format string An optional format string to use for the description.
--- @return string The human-readable description of the script object.
function GedScriptDescription(obj, filter, format)
	local prop_meta = g_EditedScriptPropMeta
	if prop_meta then
		local prop_name = prop_eval(prop_meta.name, g_EditedScriptParent, prop_meta) or prop_meta.id
		return string.format("%s(%s)", prop_name, obj.Params)
	end
	return string.format("Script(%s)", obj.Params)
end


DefineClass.ScriptProgram = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "eval", editor = "func", default = empty_func, read_only = true, params = function(self) return self.Params end, },
	},
	ContainerClass = "ScriptBlock",
	ContainerAddNewButtonMode = "docked",
	EditorExcludeAsNested = true,
	EditorView = Untranslated("script(<Params>)"),
	Params = "", -- for 'script' properties this is obtained from the property metadata 'params'
	
	upvalues = false, -- name => code & code => name
	last_code = false,
	err = false,
}

---
--- Requests a unique upvalue name for the given code or value.
---
--- @param prefix string The prefix to use for the upvalue name.
--- @param upvalue any The value or code to get a unique upvalue name for.
--- @param is_code boolean Whether the `upvalue` parameter is code or a value.
--- @return string The unique upvalue name.
function ScriptProgram:RequestUpvalue(prefix, upvalue, is_code)
	local code = is_code and upvalue or ValueToLuaCode(upvalue)
	local code_key = " " .. code
	local upvalues = self.upvalues
	local existing = upvalues[code_key]
	if existing then
		return existing
	end
	
	local n = 1
	local name = prefix .. tostring(n)
	while upvalues[name] do
		n = n + 1
		name = prefix .. tostring(n)
	end
	
	upvalues[name] = code
	upvalues[code_key] = name
	return name
end

---
--- Calls the `eval` function of the `ScriptProgram` object with the provided arguments.
---
--- @param ... any Arguments to pass to the `eval` function.
--- @return boolean, any Returns `true` and the return value of the `eval` function if the call was successful, `false` and the error message otherwise.
function ScriptProgram:__call(...)
	local ok, ret = procall(self.eval, ...)
	return ok and ret
end

---
--- Serializes the `ScriptProgram` object, optionally with a provided code block and function evaluation.
---
--- @param indent_num number The indentation level for the serialized code.
--- @param code string|nil The code block to serialize, or `nil` to serialize the entire `ScriptProgram`.
--- @param fn_eval function|nil The function to use for evaluation, or `nil` to use the existing `eval` function.
--- @return string The serialized `ScriptProgram`.
function ScriptProgram:Serialize(indent_num, code, fn_eval)
	local old_eval, old_code = self.eval, self.last_code
	self.eval = fn_eval or nil
	self.last_code = nil
	local ret = ScriptBlock.__toluacode(self, indent_num, code)
	self.eval, self.last_code = old_eval, old_code
	return ret
end

---
--- Serializes the `ScriptProgram` object, optionally with a provided code block and function evaluation.
---
--- @param indent_num number The indentation level for the serialized code.
--- @param code string|nil The code block to serialize, or `nil` to serialize the entire `ScriptProgram`.
--- @param fn_eval function|nil The function to use for evaluation, or `nil` to use the existing `eval` function.
--- @return string The serialized `ScriptProgram`.
function ScriptProgram:__toluacode(indent_num, code)
	if not code then
		return self:Serialize(indent_num) -- used in copy/paste scenarios; doesn't include the 'eval' function, it is regenerated in OnEditorNew
	end
	
	local indent = string.rep("\t", indent_num + 1)
	local fn, err, fn_code, upvalue_line_count = self:Compile(indent)
	if err then
		self:Serialize(indent_num, code, nil)
	elseif not upvalue_line_count then
		self:Serialize(indent_num, code, fn)
	else
		local object_code = pstr()
		self:Serialize(indent_num, object_code)
		
		assert(object_code:sub(-4) == "\n\t})")
		code:append(object_code:sub(1, -5), "\n", indent, "eval = (function()\n")
		-- N.B: THIS CAUSES CORRUPTION, e.g. saved presets have bogus symbols instead of function 'end' clauses
		--[[local result, line_count = code:str():gsub("\n", "\n") -- find line number
		SetFuncDebugInfo(g_PresetCurrentLuaFileSavePath, line_count + upvalue_line_count + 1, self.eval)]]
		code:append(fn_code, "\n", indent, "end)(),\n", indent:sub(1, -2), "})")
	end
	
	ObjModified(self)
	return code
end

---
--- Called when a new `ScriptProgram` is created in the editor.
---
--- @param parent any The parent object of the `ScriptProgram`.
--- @param ged any The `ged` object associated with the `ScriptProgram`.
--- @param is_paste boolean Whether the `ScriptProgram` was created by pasting.
---
--- If the `ScriptProgram` was created by pasting, this function will compile the `ScriptProgram`.
function ScriptProgram:OnEditorNew(parent, ged, is_paste)
	if is_paste then
		self:Compile()
	end
end

---
--- Creates a deep copy of the `ScriptProgram` object.
---
--- @return ScriptProgram A new `ScriptProgram` object that is a deep copy of the original.
function ScriptProgram:Clone()
	local clone = ScriptBlock.Clone(self)
	clone.Params = self.Params
	for idx, obj in ipairs(self) do
		clone[idx] = obj:Clone()
	end
	clone:Compile()
	return clone
end

---
--- Gathers all the variable names used as parameters in the `ScriptProgram`.
---
--- @param vars table A table to store the parameter names.
---
function ScriptProgram:GatherVars(vars)
	for param in string.gmatch(self.Params .. ",", "([%w_]+)%s*,%s*") do
		vars[param] = true
	end
end

---
--- Gathers all the parameter names used in the `ScriptProgram`.
---
--- @return table An array of parameter names.
function ScriptProgram:GetParamNames()
	local params = {}
	for param in string.gmatch(self.Params .. ",", "([%w_]+)%s*,%s*") do
		params[#params + 1] = param
	end
	return params
end

---
--- Generates a human-readable script representation of the `ScriptProgram` object.
---
--- @return string The human-readable script representation.
function ScriptProgram:GetHumanReadableScript()
	local pstr = pstr("", 256)
	for _, block in ipairs(self) do
		block:GetHumanReadableScript(pstr, "")
	end
	return pstr:str():sub(1, -2) -- remove trailing new line
end

---
--- Generates the internal code representation for the `ScriptProgram` object.
---
--- @param pstr pstr The string buffer to write the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptProgram:GenerateCodeInternal(pstr, indent)
	ScriptBlock.GenerateCode(self, pstr, indent)
end

---
--- Generates the internal code representation for the `ScriptProgram` object.
---
--- @param pstr pstr The string buffer to write the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptProgram:GenerateCode(pstr_in, indent)
	assert(pstr_in == nil) -- use ScriptProgram:GenerateCode to get a string returned value
	
	local code = pstr("", 256)
	self.upvalues = {}
	self:GenerateCodeInternal(code, indent) -- fills upvalues in 'self.upvalues', if any
	
	local upvalues = self.upvalues
	local _, upvalue_line_count
	if next(upvalues) then
		indent = indent or ""
		local pstr = pstr("", 256)
		for name, value in sorted_pairs(upvalues) do
			if not name:starts_with(" ") then
				pstr:appendf("%slocal %s = %s\n", indent, name, value)
			end
		end
		_, upvalue_line_count = pstr:str():gsub("\n", "\n")
		pstr:append(indent, "return function(", self.Params, ")\n", code, indent, "end")
		code = pstr
	end
	self.upvalues = nil
	
	local str = code:str()
	if str:ends_with("\n") then
		str = str:sub(1, -2)
	end
	for from, to in pairs(optimizations) do
		str = str:gsub(from, to)
	end
	return str, upvalue_line_count
end

-- generates code and compiles the resulting function in the 'eval' member without saving the code to a Lua file (used by Test Harness)
---
--- Compiles the script program and returns the compiled function, any error message, the generated code, and a flag indicating if the script has upvalues.
---
--- @param indent string The indentation level for the generated code.
--- @return function The compiled function.
--- @return string|nil The error message, if any.
--- @return string The generated code.
--- @return boolean Whether the script has upvalues.
---
function ScriptProgram:Compile(indent)
	local code, has_upvalues = self:GenerateCode()
	if self.last_code ~= code then -- don't modify the object if code didn't change, or it will be marked as modified in Ged
		if has_upvalues then
			code = self:GenerateCode(nil, (indent or "") .. "\t") -- get code with proper indent
			self.eval, self.err = CompileFunc("eval", "", code)()
			FuncSource[self.eval] = { "eval", self.Params, code }
		else
			self.eval, self.err = CompileFunc("eval", self.Params, code)
		end
		self.last_code = self.err or code
	end
	self.err = self.err and self.err:match("^[^:]+:(.*)") or nil
	return self.eval, self.err, code, has_upvalues
end

---
--- Returns the error message, if any, from the last compilation of the script program.
---
--- @return string|nil The error message, or nil if there was no error.
---
function ScriptProgram:GetError()
	return self.err
end


DefineClass.ScriptConditionList = {
	__parents = { "ScriptProgram" },
	ContainerClass = "ScriptValue",
	EditorView = Untranslated("condition(<Params>)"),
}

---
--- Generates the internal code for a script condition list.
---
--- @param pstr string The string builder to append the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptConditionList:GenerateCodeInternal(pstr, indent)
	indent = indent and indent .. "\t" or ""
	pstr:append(indent, "return ")
	indent = indent .. "\t"
	local n = #self
	for i = 1, n do
		pstr:append("(")
		self[i]:GenerateCode(pstr, "")
		pstr:append(")\n")
		if i ~= n then
			pstr:append(indent, "and ")
		end
	end
end


----- General statements - code, local, return, break, etc.

DefineClass.ScriptCode = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "Code", editor = "func", default = false, params = "" },
	},
	EditorName = "Code",
	EditorSubmenu = "Scripting",
}

---
--- Returns the editor view for a ScriptCode object.
---
--- @return string The editor view for the ScriptCode object.
---
function ScriptCode:GetEditorView()
	local code = GetFuncBody(self.Code)
	return code == "" and "<code>" or code
end

---
--- Generates the internal code for a ScriptCode object.
---
--- @param pstr string The string builder to append the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptCode:GenerateCode(pstr, indent)
	pstr:append(GetFuncBody(self.Code, indent), "\n")
end


DefineClass.ScriptLocal = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "Name", name = "Variable name", editor = "text", default = "", },
		{ id = "Value", editor = "nested_obj", default = false, base_class = "ScriptValue", },
	},
	EditorName = "Local variable",
	EditorSubmenu = "Scripting",
}

---
--- Generates the Lua code for a ScriptLocal object.
---
--- @param pstr string The string builder to append the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptLocal:GenerateCode(pstr, indent)
	if self.Name == "" then return end
	
	pstr:append(indent, "local ", self.Name)
	if self.Value then
		pstr:append(" = ")
		self.Value:GenerateCode(pstr, "")
	end
	pstr:append("\n")
end

---
--- Gathers the variables used in the ScriptLocal object.
---
--- @param vars table A table to store the variable names used in the ScriptLocal object.
---
function ScriptLocal:GatherVars(vars)
	vars[self.Name] = true
end

---
--- Generates the editor view for a ScriptLocal object.
---
--- @param self ScriptLocal The ScriptLocal object to generate the editor view for.
--- @return string The editor view for the ScriptLocal object.
---
function ScriptLocal:GetEditorView()
	if not self.Value then
		return string.format("<style GedName>local</style> %s", self.Name)
	end
	return string.format("<style GedName>local</style> %s = %s", self.Name, _InternalTranslate(Untranslated("<EditorView>"), self.Value, false))
end


DefineClass.ScriptReturnExpr = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "Value", editor = "expression", default = empty_func, params = "" },
	},
	EditorName = "Return Lua expression value(s)",
	EditorSubmenu = "Scripting",
	EditorView = Untranslated("<style GedName>return</style> <Value>"),
}
---
--- Generates the Lua code for a ScriptReturnExpr object.
---
--- @param pstr string The string builder to append the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptReturnExpr:GenerateCode(pstr, indent)
	pstr:append(GetFuncBody(self.Value, indent, "return"), "\n")
end

DefineClass.ScriptReturn = {
	__parents = { "ScriptBlock" },
	ContainerClass = "ScriptValue",
	EditorName = "Return script value(s)",
	EditorSubmenu = "Scripting",
	EditorView = Untranslated("<style GedName>return</style>"),
}

---
--- Generates the Lua code for a ScriptReturn object.
---
--- @param pstr string The string builder to append the generated code to.
--- @param indent string The indentation level for the generated code.
---
function ScriptReturn:GenerateCode(pstr, indent)
	pstr:append(indent, "return")
	local delimeter = " "
	for _, block in ipairs(self) do
		pstr:append(delimeter)
		block:GenerateCode(pstr, "")
		delimeter = ", "
	end
	pstr:append("\n")
end


----- Compound statements (e.g. if-then-else)

-- All elements of a compound statements are selected at once, so it can't be partially moved or deleted in Ged
DefineClass.ScriptCompoundStatementElement = {
	__parents = { "ScriptBlock" },
}

---
--- Finds the main block that contains the current script block.
---
--- @param self ScriptCompoundStatementElement The current script block.
--- @return table, number The parent table and index of the main block.
---
function ScriptCompoundStatementElement:FindMainBlock()
	local parent = GetParentTableOfKind(self, "ScriptBlock")
	local idx = table.find(parent, self)
	if not idx then return end
	while idx > 0 and not IsKindOf(parent[idx], "ScriptCompoundStatement") do
		idx = idx - 1
	end
	return parent, idx
end

---
--- Selects the complete selection for a compound statement element.
---
--- When a compound statement element is selected, this function ensures that all related elements
--- (e.g. the 'if' and 'then' blocks of an if-then-else statement) are also selected.
---
--- @param self ScriptCompoundStatementElement The compound statement element being selected.
--- @param selected boolean Whether the element is being selected or deselected.
--- @param ged table The Ged editor instance.
---
function ScriptCompoundStatementElement:OnEditorSelect(selected, ged)
	local parent, idx = self:FindMainBlock()
	if parent then
		ged:SelectSiblingsInFocusedPanel(parent[idx]:GetCompleteSelection{ idx }, selected)
	end
end

---
--- Determines the mode for the "Add New" button when editing a script compound statement element.
---
--- The "Add New" button is only shown for the last compound statement element in a sequence.
---
--- @param self ScriptCompoundStatementElement The current script compound statement element.
--- @return string The mode for the "Add New" button, either "floating" or "floating_combined".
---
function ScriptCompoundStatementElement:GetContainerAddNewButtonMode()
	-- only the last compound statement element allows adding siblings
	local parent, idx = self:FindMainBlock()
	local my_idx = table.find(parent, self)
	return my_idx == idx + parent[idx]:GetExtraStatementCount() and "floating_combined" or "floating"
end


DefineClass.ScriptCompoundStatement = {
	__parents = { "ScriptCompoundStatementElement" },
	ExtraStatementClass = "",
}

---
--- Determines the complete selection for a script compound statement element.
---
--- When a script compound statement element is selected in the editor, this function ensures that all related elements
--- (e.g. the 'if' and 'then' blocks of an if-then-else statement) are also selected.
---
--- @param self ScriptCompoundStatement The script compound statement element being selected.
--- @param selection table The current selection indices.
--- @return table The complete selection indices.
---
function ScriptCompoundStatement:GetCompleteSelection(selection)
	local idx = selection[#selection]
	for i = idx + 1, idx + self:GetExtraStatementCount() do
		selection[#selection + 1] = i
	end
	return selection
end

---
--- Called after a new ScriptCompoundStatement is created in the editor.
--- If the statement is not being pasted, this function ensures that any required extra statements (e.g. the 'then' block of an if-then-else statement) are also created.
---
--- @param self ScriptCompoundStatement The script compound statement that was just created.
--- @param parent table The parent table containing the new statement.
--- @param ged table The Ged editor instance.
--- @param is_paste boolean Whether the statement was pasted or newly created.
---
function ScriptCompoundStatement:OnAfterEditorNew(parent, ged, is_paste)
	if not is_paste then
		local parent = GetParentTableOfKind(self, "ScriptBlock")
		local idx = table.find(parent, self)
		if not IsKindOf(parent[idx + 1], self.ExtraStatementClass) then -- TODO: Undo issue, this check doesn't work because the 'then' is not yet restored
			table.insert(parent, idx + 1, g_Classes[self.ExtraStatementClass]:new())
			ParentTableModified(parent[idx + 1], parent)
		end
	end
end

---
--- Determines the number of extra statements associated with this script compound statement.
---
--- For example, an if-then-else statement has 2 extra statements (the 'then' and 'else' blocks),
--- while a simple if statement has 1 extra statement (the 'then' block).
---
--- @return integer The number of extra statements associated with this script compound statement.
---
function ScriptCompoundStatement:GetExtraStatementCount()
	return 1
end


----- If-then-else

DefineClass.ScriptIf = {
	__parents = { "ScriptCompoundStatement" },
	properties = {
		{ id = "HasElse", name = "Has else", editor = "bool", default = false, },
	},
	ContainerClass = "ScriptValue",
	ExtraStatementClass = "ScriptThen",
	
	EditorView = Untranslated("<style GedName>if</style>"),
	EditorName = "if-then-else",
	EditorSubmenu = "Scripting",
	
	else_backup = false,
}

---
--- Called when the "Has else" property of a ScriptIf statement is changed in the editor.
--- This function handles the addition or removal of the "else" block based on the new value of the "Has else" property.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value boolean The previous value of the "Has else" property.
--- @param ged table The Ged editor instance.
---
function ScriptIf:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "HasElse" then
		local parent, idx = self:FindMainBlock()
		if self.HasElse then
			table.insert(parent, idx + 2, self.else_backup or ScriptElse:new())
			ParentTableModified(parent[idx + 2], parent)
		else
			self.else_backup = table.remove(parent, idx + 2)
		end
		
		local selected_path, nodes = unpack_params(ged.last_app_state.root.selection)
		ged:SetSelection("root", selected_path, self:GetCompleteSelection{ nodes[1] }, false, "restoring_state")
		ObjModified(self)
	end
end

---
--- Returns the number of extra statements associated with this script if statement.
---
--- If the script if statement has an "else" block, this function returns 2, otherwise it returns 1.
---
--- @return integer The number of extra statements associated with this script if statement.
---
function ScriptIf:GetExtraStatementCount()
	return self.HasElse and 2 or 1
end

---
--- Generates the Lua code for a ScriptIf statement.
---
--- This function is responsible for generating the Lua code for a ScriptIf statement, which is a compound statement that represents an if-then-else control flow structure in the scripting system.
---
--- The function first appends the "if" keyword to the output string, then generates the code for the condition expression(s) that make up the if statement. If there is only one condition expression, it is generated directly. If there are multiple condition expressions, they are generated with "and" operators between them.
---
--- If the if statement has no child statements, the function appends "true" to the output string to represent an empty if block. Otherwise, it generates the code for the child statements, which are typically ScriptThen and ScriptElse statements.
---
--- @param pstr table The output string builder to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptIf:GenerateCode(pstr, indent)
	pstr:append(indent, "if ")
	indent = indent .. "\t"
	
	if #self == 0 then
		pstr:append("true ")
	elseif #self == 1 then
		self[1]:GenerateCode(pstr, "")
	else
		for i, subitem in ipairs(self) do
			subitem:GenerateCode(pstr, i == 1 and "" or indent)
			if i ~= #self then
				pstr:append(" and\n")
			end
		end
	end
end

DefineClass.ScriptThen = {
	__parents = { "ScriptCompoundStatementElement" },
	ContainerClass = "ScriptBlock",
	EditorExcludeAsNested = true,
	EditorView = Untranslated("<style GedName>then</style>"),
}

---
--- Generates the Lua code for a ScriptThen statement.
---
--- This function is responsible for generating the Lua code for a ScriptThen statement, which represents the "then" block of an if-then-else control flow structure in the scripting system.
---
--- The function first appends the "then" keyword to the output string, then generates the code for the child statements of the ScriptThen statement. If the parent if statement does not have an "else" block, the function also appends the "end" keyword to close the if statement.
---
--- @param pstr table The output string builder to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptThen:GenerateCode(pstr, indent)
	pstr:append(" then\n")
	ScriptCompoundStatementElement.GenerateCode(self, pstr, indent)
	local parent, index = self:FindMainBlock()
	if not parent[index].HasElse then
		pstr:append(indent, "end\n")
	end
end

DefineClass.ScriptElse = {
	__parents = { "ScriptCompoundStatementElement" },
	ContainerClass = "ScriptBlock",
	EditorExcludeAsNested = true,
	EditorView = Untranslated("<style GedName>else</style>"),
}

---
--- Generates the Lua code for a ScriptElse statement.
---
--- This function is responsible for generating the Lua code for a ScriptElse statement, which represents the "else" block of an if-then-else control flow structure in the scripting system.
---
--- The function first appends the "else" keyword to the output string, then generates the code for the child statements of the ScriptElse statement. Finally, it appends the "end" keyword to close the if statement.
---
--- @param pstr table The output string builder to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptElse:GenerateCode(pstr, indent)
	pstr:append(indent, "else\n")
	ScriptCompoundStatementElement.GenerateCode(self, pstr, indent)
	pstr:append(indent, "end\n")
end


----- Loops

DefineClass.ScriptForEach = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "IPairs",     name = "Array", editor = "bool", default = true, },
		{ id = "CounterVar", name = "Store index in",    editor = "text", default = "i",     no_edit = function(self) return not self.IPairs end, },
		{ id = "ItemVar",    name = "Store value in",    editor = "text", default = "item",  no_edit = function(self) return not self.IPairs end, },
		{ id = "KeyVar",     name = "Store key in",      editor = "text", default = "key",   no_edit = function(self) return     self.IPairs end, },
		{ id = "ValueVar",   name = "Store value in",    editor = "text", default = "value", no_edit = function(self) return     self.IPairs end, },
		{ id = "Table", editor = "nested_obj", default = false, base_class = "ScriptValue", auto_expand = true },
	},
	ContainerClass = "ScriptBlock",
	EditorName = "for-each",
	EditorSubmenu = "Scripting",
}

---
--- Initializes a new ScriptForEach object when it is created in the editor.
---
--- This function is called when a new ScriptForEach object is created in the editor. If the object is not being pasted, it creates a new ScriptVariableValue object and assigns it to the `Table` property of the ScriptForEach object.
---
--- @param parent table The parent object of the new ScriptForEach object.
--- @param ged table The editor object associated with the new ScriptForEach object.
--- @param is_paste boolean Indicates whether the object is being pasted or not.
---
function ScriptForEach:OnEditorNew(parent, ged, is_paste)
	if not is_paste then
		self.Table = ScriptVariableValue:new()
	end
end

---
--- Generates the Lua code for a ScriptForEach statement.
---
--- This function is responsible for generating the Lua code for a ScriptForEach statement, which represents a "for each" loop in the scripting system.
---
--- The function first determines the appropriate loop iterator function to use (ipairs or pairs) based on the IPairs property of the ScriptForEach object. It then generates the loop header, including the loop counter and item variables. If the Table property is set, it generates the code for the Table object; otherwise, it uses an empty table.
---
--- Finally, it generates the code for the child statements of the ScriptForEach statement, indenting them by one level.
---
--- @param pstr table The output string builder to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptForEach:GenerateCode(pstr, indent)
	local key_var = self.IPairs and self.CounterVar or self.KeyVar
	local val_var = self.IPairs and self.ItemVar    or self.ValueVar
	local iterate = self.IPairs and "ipairs"        or "pairs"
	pstr:appendf("%sfor %s, %s in %s(", indent, key_var, val_var, iterate)
	if self.Table then
		self.Table:GenerateCode(pstr, "")
		pstr:append(") do\n")
	else
		pstr:append("empty_table) do\n")
	end
	for _, item in ipairs(self) do
		item:GenerateCode(pstr, indent .. "\t")
	end
	pstr:append(indent, "end\n")
end

---
--- Gathers the variables used in the ScriptForEach object.
---
--- This function is responsible for gathering the variables used in the ScriptForEach object, which are the loop counter variable and the loop item variable. The variables gathered depend on the value of the `IPairs` property of the ScriptForEach object.
---
--- @param vars table The table to store the gathered variables in.
---
function ScriptForEach:GatherVars(vars)
	vars[self.IPairs and self.CounterVar or self.KeyVar  ] = true
	vars[self.IPairs and self.ItemVar    or self.ValueVar] = true
end

---
--- Handles changes to the `IPairs` property of the `ScriptForEach` object.
---
--- When the `IPairs` property is changed, this function resets the `KeyVar`, `ValueVar`, `CounterVar`, and `ItemVar` properties to `nil`. This ensures that the appropriate loop iterator variables are used when generating the Lua code for the `ScriptForEach` statement.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor object associated with the `ScriptForEach` object.
---
function ScriptForEach:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "IPairs" then
		self.KeyVar = nil
		self.ValueVar = nil
		self.CounterVar = nil
		self.ItemVar = nil
	end
end

---
--- Generates the editor view for the `ScriptForEach` object.
---
--- This function is responsible for generating the editor view for the `ScriptForEach` object, which is displayed in the editor UI. The editor view includes the loop iterator variables and the table or array being iterated over.
---
--- @param self ScriptForEach The `ScriptForEach` object.
--- @return string The generated editor view.
---
function ScriptForEach:GetEditorView()
	local key_var = self.IPairs and self.CounterVar or self.KeyVar
	local val_var = self.IPairs and self.ItemVar    or self.ValueVar
	local tbl = self.Table and _InternalTranslate(Untranslated("<EditorView>"), self.Table, false) or "?"
	local text = string.format("<style GedName>for each</style> (%s, %s) <style GedName><u(select(IPairs, 'key/value in the table', 'item in the array'))></style> %s", key_var, val_var, tbl)
	return Untranslated(text)
end


DefineClass.ScriptLoop = {
	__parents = { "ScriptBlock" },
	properties = {
		{ id = "CounterVar", name = "Store index in", editor = "text", default = "i", },
		{ id = "StartIndex", name = "Start index", editor = "expression", params = "", default = function() return 1 end, },
		{ id = "EndIndex", name = "End index",     editor = "expression", params = "", default = function() return 1 end, },
		{ id = "Step",                             editor = "expression", params = "", default = function() return 1 end, },
	},
	ContainerClass = "ScriptBlock",
	EditorName = "for",
	EditorSubmenu = "Scripting",
}

---
--- Generates the Lua code for a `ScriptLoop` object.
---
--- This function is responsible for generating the Lua code for a `ScriptLoop` object, which represents a for loop in the script. The function generates the loop header with the appropriate start index, end index, and step, and then recursively generates the code for any nested script blocks within the loop.
---
--- @param pstr string The output string to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptLoop:GenerateCode(pstr, indent)
	local startidx = GetExpressionBody(self.StartIndex)
	local endidx = GetExpressionBody(self.EndIndex)
	local step = GetExpressionBody(self.Step)
	if step == "1" then
		pstr:appendf("%sfor %s = %s, %s do\n", indent, self.CounterVar, startidx, endidx)
	else
		pstr:appendf("%sfor %s = %s, %s, %s do\n", indent, self.CounterVar, startidx, endidx, step)
	end
	for _, item in ipairs(self) do
		item:GenerateCode(pstr, indent .. "\t")
	end
	pstr:append(indent, "end\n")
end

---
--- Generates the editor view for a `ScriptLoop` object, which represents a for loop in the script.
---
--- The editor view includes the loop iterator variables and the start index, end index, and step.
---
--- @param self ScriptLoop The `ScriptLoop` object.
--- @return string The generated editor view.
---
function ScriptLoop:GetEditorView()
	local startidx = GetExpressionBody(self.StartIndex)
	local endidx = GetExpressionBody(self.EndIndex)
	local step = GetExpressionBody(self.Step)
	return string.format("<style GedName>for</style> %s <style GedName>from</style> %s <style GedName>to</style> %s%s",
		self.CounterVar, startidx, endidx, step ~= "1" and " <style GedName>step</style> "..step or "")
end


DefineClass.ScriptBreak = {
	__parents = { "ScriptSimpleStatement" },
	EditorName = "break loop",
	EditorSubmenu = "Scripting",
	EditorView = Untranslated("<style GedName>break loop</style>"),
	AutoPickParams = false,
	CodeTemplate = "break",
}


----- Simple statements with support to generate code via CodeTemplate

DefineClass.ScriptSimpleStatement = {
	__parents = { "ScriptBlock" },
	properties = {
		{ category = "Parameters", id = "Param1", name = function(self) return self.Param1Name end, editor = "choice", default = "", items = ScriptVarsCombo, no_edit = function(self) return not self.Param1Name end, help = function(self) return self.Param1Help end, },
		{ category = "Parameters", id = "Param2", name = function(self) return self.Param2Name end, editor = "choice", default = "", items = ScriptVarsCombo, no_edit = function(self) return not self.Param2Name end, help = function(self) return self.Param2Help end, },
		{ category = "Parameters", id = "Param3", name = function(self) return self.Param3Name end, editor = "choice", default = "", items = ScriptVarsCombo, no_edit = function(self) return not self.Param3Name end, help = function(self) return self.Param3Help end, },
	},
	Param1Name = false,
	Param2Name = false,
	Param3Name = false,
	Param1Help = false,
	Param2Help = false,
	Param3Help = false,
	AutoPickParams = true,
	CodeTemplate = "",
	NewLine = true,
}

-- Values that require allocation will be made upvalues, so they are not allocated with each call to the script.
-- Common values such as point30 will be used as well.
---
--- Converts a value to its corresponding Lua code representation.
---
--- This function is used to generate Lua code for various types of values, including:
--- - `empty_func`: Returns the string "empty_func"
--- - `empty_box`: Returns the string "empty_box"
--- - `point20`: Returns the string "point20"
--- - `point30`: Returns the string "point30"
--- - `axis_x`: Returns the string "axis_x"
--- - `axis_y`: Returns the string "axis_y"
--- - `axis_z`: Returns the string "axis_z"
--- - Tables and userdata: Requests an upvalue from the parent `ScriptProgram` and returns the corresponding variable name
--- - Other values: Calls the `ValueToLuaCode` function to convert the value to its Lua code representation
---
--- @param value any The value to be converted to Lua code
--- @return string The Lua code representation of the value
---
function ScriptSimpleStatement:ValueToLuaCode(value)
	if value == empty_func then return "empty_func" end
	if value == empty_box  then return "empty_box" end
	if value == point20    then return "point20" end
	if value == point30    then return "point30" end
	if value == axis_x     then return "axis_x" end
	if value == axis_y     then return "axis_y" end
	if value == axis_z     then return "axis_z" end
	
	if type(value) == "table" or type(value) == "userdata" then
		local program = GetParentTableOfKind(self, "ScriptProgram")
		local prefix =
			IsPoint(value) and "pt" or
			IsBox(value) and "bx" or
			type(value) == "table" and "t" or "v"
		return program:RequestUpvalue(prefix, value)
	end
	
	return ValueToLuaCode(value)
end

---
--- Generates the Lua code for a `ScriptSimpleStatement` object.
---
--- This function is responsible for generating the Lua code representation of a `ScriptSimpleStatement` object. It handles the following cases:
---
--- 1. If the `CodeTemplate` property contains a conjunction (e.g. `" and "`, `" or "`, `" + "`, `" * "`), it generates the Lua code for all the sub-items of the `ScriptSimpleStatement` separated by the conjunction.
--- 2. For each property of the `ScriptSimpleStatement` object, it generates the corresponding Lua code using the `ValueToLuaCode` function.
--- 3. It replaces any newline characters in the generated code with the specified indent.
--- 4. It appends the generated code to the `pstr_out` parameter, followed by a newline if `self.NewLine` is true.
---
--- @param pstr_out string The output string to append the generated code to
--- @param indent string The indent to use for the generated code
function ScriptSimpleStatement:GenerateCode(pstr_out, indent)
	-- self[conjunction] case, output all subitem ScriptBlocks separated with a conjunction such as 'and'
	local code = self.CodeTemplate:gsub("self(%b[])", function(conjunction)
		local str, n = pstr("", 64), #self
		conjunction = string.format(" %s ", conjunction:sub(2, -2))
		for idx, subitem in ipairs(self) do
			subitem:GenerateCode(str, "")
			if idx ~= n then
				str:append(conjunction)
			end
		end
		if #str ~= 0 then
			return str:str()
		end
		if     conjunction == " and " then return "true"
		elseif conjunction == " or "  then return "false"
		elseif conjunction == " + "   then return "0"
		elseif conjunction == " * "   then return "1"
		end
		return ""
	end)
	
	code = code:gsub("(%$?)self%.([%w_]+)", function(prefix, identifier)
		-- self.prop, where prop is another ScriptBlock nested_obj
		local value = self[identifier]
		if IsKindOf(value, "ScriptBlock") then
			local str = pstr("", 32)
			value:GenerateCode(str, "")
			return str:str()
		end
		-- $self.prop means we have a variable name in self.prop (output directly, not enclosed in quotes)
		if prefix == "$" then
			return (value ~= "" and value or "nil")
		end
		-- default case - output the property value
		return self:ValueToLuaCode(value) -- the method will request upvalues for tables, points, boxes, etc.
	end)
	code = code:gsub("\n", "\n"..indent)
	pstr_out:append(indent, code, self.NewLine and "\n" or "")
end

--- This function is called after a new instance of `ScriptSimpleStatement` is created in the editor.
---
--- If `AutoPickParams` is true and the instance is not being pasted, it will automatically set the `Param1`, `Param2`, and `Param3` properties to the first three parameters of the parent `ScriptProgram`.
---
--- @param parent ScriptProgram The parent `ScriptProgram` object.
--- @param ged table The editor GUI object.
--- @param is_paste boolean Whether the instance is being pasted or not.
function ScriptSimpleStatement:OnAfterEditorNew(parent, ged, is_paste)
	if self.AutoPickParams and not is_paste then
		local params = GetParentTableOfKind(self, "ScriptProgram"):GetParamNames()
		for i, param in ipairs(params) do
			if self["Param"..i.."Name"] then
				self:SetProperty("Param" .. i, param)
			end
		end
	end
end

DefineClass.ScriptPrint = {
	__parents = { "ScriptSimpleStatement" },
	Param1Name = "Param1",
	Param2Name = "Param2",
	Param3Name = "Param3",
	EditorName = "Print",
	EditorSubmenu = "Effects",
	EditorView = Untranslated("print(<opt(u(Param1),'','')><opt(u(Param2),', ','')><opt(u(Param3),', ','')>)"),
	CodeTemplate = "print($self.Param1, $self.Param2, $self.Param3)",
	AutoPickParams = false,
}


----- Values

DefineClass.ScriptValue = {
	__parents = { "ScriptSimpleStatement" },
	NewLine = false,
}

DefineClass.ScriptExpression = {
	__parents = { "ScriptValue" },
	properties = {
		{ id = "Value", editor = "expression", default = empty_func, params = "" },
	},
	EditorName = "Expression",
	EditorSubmenu = "Scripting",
}

function ScriptExpression:GetEditorView()
	return GetExpressionBody(self.Value)
end

---
--- Generates the code for a script expression.
---
--- @param pstr string The string to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptExpression:GenerateCode(pstr, indent)
	pstr:append(GetExpressionBody(self.Value))
end

DefineClass.ScriptVariableValue = {
	__parents = { "ScriptValue" },
	properties = {
		{ id = "Variable", editor = "choice", default = "", items = ScriptVarsCombo }
	},
	EditorName = "Variable value",
	EditorSubmenu = "Values",
	EditorView = Untranslated("<def(Variable,'nil')>"),
	CodeTemplate = "$self.Variable",
}


----- Conditions

DefineClass.ScriptCondition = {
	__parents = { "ScriptValue" },
	properties = {
		{ id = "Negate", editor = "bool", default = false, no_edit = function(self) return not self.HasNegate end }
	},
	-- all these properties must be defined when adding a new condition
	HasNegate = false,
	Documentation = "",
	EditorView = Untranslated("<class>"),
	EditorViewNeg = Untranslated("not <class>"),
	EditorName = false,
	EditorSubmenu = false,
}

---
--- Generates the code for a script condition.
---
--- @param pstr string The string to append the generated code to.
--- @param indent string The current indentation level.
---
function ScriptCondition:GenerateCode(pstr, indent)
	if self.Negate then pstr:append("not (") end
	ScriptValue.GenerateCode(self, pstr, indent)
	if self.Negate then pstr:append(")") end
end

---
--- Gets the editor view for a script condition.
---
--- If the condition is negated, returns the negated editor view. Otherwise, returns the normal editor view.
---
--- @param self ScriptCondition The script condition object.
--- @return string The editor view for the script condition.
---
function ScriptCondition:GetEditorView()
	return self.Negate and self.EditorViewNeg or self.EditorView
end


DefineClass.ScriptCheckNumber = {
	__parents = { "ScriptCondition" },
	properties = {
		{ id = "Value", editor = "nested_obj", default = false, base_class = "ScriptValue", },
		{ id = "Condition", editor = "choice", default = "==", items = function (self) return { ">=", "<=", ">", "<", "==", "~=" } end, },
		{ id = "Amount", editor = "nested_obj", default = false, base_class = "ScriptValue", },
	},
	HasNegate = false,
	EditorName = "Check number",
	EditorSubmenu = "Conditions",
	CodeTemplate = "self.Value $self.Condition self.Amount",
}

---
--- Called after a new instance of `ScriptCheckNumber` is created in the editor.
--- Initializes the `Amount` property with a new `ScriptExpression` object and links the parent table.
---
--- @param self ScriptCheckNumber The `ScriptCheckNumber` instance.
---
function ScriptCheckNumber:OnAfterEditorNew()
	self.Amount = ScriptExpression:new()
	ParentTableModified(self.Amount, self)
end

---
--- Gets the editor view for a script check number condition.
---
--- The editor view is a string representation of the condition that is displayed in the editor UI.
--- It includes the value, condition, and amount properties of the `ScriptCheckNumber` object.
---
--- @param self ScriptCheckNumber The script check number condition object.
--- @return string The editor view for the script check number condition.
---
function ScriptCheckNumber:GetEditorView()
	local value1 = self.Value and _InternalTranslate(Untranslated("<EditorView>"), self.Value, false) or ""
	local value2 = self.Amount and _InternalTranslate(Untranslated("<EditorView>"), self.Amount, false) or ""
	return string.format("%s %s %s", value1, self.Condition, value2)
end
