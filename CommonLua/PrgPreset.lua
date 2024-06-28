--- Defines the color tags for the "keyword" tag in the `const.TagLookupTable` table.
--- The "keyword" tag will be rendered as a color with the RGB values (75, 105, 198).
--- The "/keyword" tag will be rendered as the end of the color formatting.
const.TagLookupTable["keyword"] = "<color 75 105 198>"
const.TagLookupTable["/keyword"] = "</color>"

--- Defines a debug function `prgdbg` that logs information about the current program line.
---
--- If `Platform.developer` is true, `prgdbg` is defined as a function that takes three arguments:
--- - `li`: a table containing the current program line information
--- - `level`: the current nesting level of the program
--- - `idx`: the index of the current program line
---
--- The function appends the current program line information to the `li` table, and sends a message with the name "OnPrgLine" containing the `li` table.
---
--- If `Platform.developer` is false, `prgdbg` is defined as an empty function.
if Platform.developer then
	function prgdbg(li, level, idx)
		li[level] = idx
		Msg("OnPrgLine", li)
	end
else
	prgdbg = empty_func
end

g_PrgPresetPropsCache = {}

--- Defines the base class for a program preset.
---
--- The `PrgPreset` class is a subclass of the `Preset` class, and provides functionality for generating code for a program preset.
---
--- The `PrgPreset` class has the following properties:
---
--- - `Params`: a list of parameters for the program preset
--- - `SingleFile`: a boolean indicating whether the program preset is contained in a single file
--- - `ContainerClass`: the class that contains the individual statements for the program preset
--- - `EditorMenubarName`: the name of the program preset in the editor menubar
--- - `HasCompanionFile`: a boolean indicating whether the program preset has a companion file
--- - `StatementTags`: a list of tags for the individual statements in the program preset
--- - `FuncTable`: the name of the table that contains the functions for the program preset
DefineClass.PrgPreset = {
	__parents = { "Preset" },
	
	properties = {
		{ id = "Params", editor = "string_list", default = {} },
	},
	
	SingleFile = false,
	ContainerClass = "PrgStatement",
	EditorMenubarName = false,
	HasCompanionFile = true,
	
	StatementTags = { "Basics" }, -- list the PrgStatement tags usable in this Prg class
	FuncTable = "Prgs", -- override in child classes
}

--- Returns the function name for the program preset.
---
--- The function name is generated based on the `id` property of the `PrgPreset` instance.
---
--- @return string The function name for the program preset.
function PrgPreset:GenerateFuncName()
	return self.id
end

--- Returns a comma-separated string of the parameters defined for the `PrgPreset` instance.
---
--- @return string A comma-separated string of the parameters.
function PrgPreset:GetParamString()
	return table.concat(self.Params, ", ")
end

--- Generates random seed for the program preset function.
---
--- This function is called at the start of the program preset function to create a random seed for the program execution. The random seed is created using the `BraidRandomCreate` function, which takes an optional seed value. If no seed value is provided, the `AsyncRand` function is used to generate a random seed.
---
--- @param code CodeBuffer The code buffer to append the random seed generation code to.
function PrgPreset:GenerateCodeAtFunctionStart(code)
	code:append("\tlocal rand = BraidRandomCreate(seed or AsyncRand())\n")
end

--- Generates the companion file code for the `PrgPreset` instance.
---
--- This function is responsible for generating the code that will be written to the companion file for the program preset. It first generates the static code for each statement in the preset, and then generates the function code that will be added to the `FuncTable` table.
---
--- The function code includes the following:
--- - A call to `rawset(_G, FuncTable, rawget(_G, FuncTable) or {})` to ensure the `FuncTable` table exists in the global scope.
--- - The function definition for the program preset, using the `GenerateFuncName()` method to get the function name.
--- - A call to `GenerateCodeAtFunctionStart()` to generate the random seed code.
--- - A loop that calls `GenerateCode()` on each statement in the preset to generate the function body.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
function PrgPreset:GenerateCompanionFileCode(code)
	-- generate static code
	local has_statements = false
	for _, statement in ipairs(self) do
		if not statement.Disable then
			local len = code:size()
			statement:GenerateStaticCode(code)
			if len ~= code:size() then
				code:append("\n")
				has_statements = true
			end
		end
	end
	if has_statements then
		code:append("\n")
	end
	
	-- generate function code
	code:appendf("rawset(_G, '%s', rawget(_G, '%s') or {})\n", self.FuncTable, self.FuncTable)
	code:appendf("%s.%s = function(seed, %s)\n", self.FuncTable, self:GenerateFuncName(), self:GetParamString())
	code:appendf("\tlocal li = { id = \"%s\" }\n", self.id)
	self:GenerateCodeAtFunctionStart(code)
	for idx, statement in ipairs(self) do
		if not statement.Disable then
			statement:GenerateCode(code, "\t", idx)
			code:append("\n")
		end
	end
	code:append("end")
end

--- Returns the editor context for the PrgPreset instance.
---
--- The editor context includes information about the container tree, which is set to true in this implementation.
---
--- @return table The editor context for the PrgPreset instance.
function PrgPreset:EditorContext()
	local context = Preset.EditorContext(self)
	context.ContainerTree = true
	return context
end

---
--- Filters a class based on whether it has a StatementTag that matches the StatementTags of the current PrgPreset instance.
---
--- @param class table The class to filter.
--- @return boolean True if the class should be included, false otherwise.
function PrgPreset:FilterSubItemClass(class)
	return not class.StatementTag or table.find(self.StatementTags, class.StatementTag)
end

---
--- Ensures that all `PrgStatement` classes have a `StatementTag` defined, and adds a validation function to enforce variable names to be valid identifiers.
---
--- This function is called when the game classes are built, ensuring that the `PrgStatement` classes are properly configured.
---
--- @function OnMsg.ClassesBuilt
--- @return nil
function OnMsg.ClassesBuilt()
	local undefined = ClassLeafDescendantsList("PrgStatement", function(name, class) return not class.StatementTag end)
	assert(#undefined == 0, string.format("Prg statement %s has no StatementTag defined.", undefined[1]))
	
	-- add a validate function to enforce variables names to be identifiers
	ClassLeafDescendantsList("PrgStatement", function(name, class)
		for _, prop_meta in ipairs(class:GetProperties()) do
			if prop_meta.items == PrgVarsCombo or prop_meta.variable then
				prop_meta.validate = function(self, value) 
					return ValidateIdentifier(self, value)
				end
			end
		end
	end)
end


----- Statement & Block

---
--- Returns a function that provides a list of variables in scope for the given object.
---
--- The returned function takes an object as an argument and returns a sorted list of variable names
--- in scope for that object, including an empty string.
---
--- @param obj table The object to get the variables in scope for.
--- @return function A function that returns a list of variables in scope.
---
function PrgVarsCombo()
	return function(obj)
		local vars = table.keys(obj:VarsInScope())
		table.insert(vars, "")
		table.sort(vars)
		return vars
	end
end

---
--- Returns a function that provides a list of local variables in scope for the given object.
---
--- The returned function takes an object as an argument and returns a sorted list of local variable names
--- in scope for that object, including an empty string.
---
--- @param obj table The object to get the local variables in scope for.
--- @return function A function that returns a list of local variables in scope.
---
function PrgLocalVarsCombo()
	return function(obj)
		local vars = {}
		for k, v in pairs(obj:VarsInScope()) do
			if v ~= "static" then
				vars[#vars + 1] = k
			end
		end
		table.insert(vars, "")
		table.sort(vars)
		return vars
	end
end

---
--- Defines the base class for a PrgStatement, which represents a statement in a Prg (Program) object.
---
--- The PrgStatement class has the following properties:
---
--- - `Disable`: A boolean property that determines whether the statement is disabled.
--- - `DisabledPrefix`: A string that is prepended to the statement's editor name when the statement is disabled.
--- - `EditorName`: The name of the statement as it appears in the editor.
--- - `StoreAsTable`: A boolean that determines whether the statement should be stored as a table.
--- - `StatementTag`: A boolean that determines whether the statement has a tag.
---
--- The PrgStatement class is a subclass of `PropertyObject`, which provides the basic functionality for managing properties.
---
DefineClass.PrgStatement = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Disable", editor = "bool", default = false, },
	},
	DisabledPrefix = Untranslated("<if(Disable)><style GedError>[Disabled] </style></if>"),
	EditorName = "Command",
	StoreAsTable = true,
	StatementTag = false, -- each PrgStatement must have a tag; each PrgPreset defines the list of tags that can be used in it
}

---
--- Returns a table of local variables in scope for the given PrgStatement object.
---
--- The returned table contains the names of all local variables that are in scope for the current PrgStatement,
--- including variables declared in any parent PrgBlock or PrgPreset objects.
---
--- @param self PrgStatement The PrgStatement object to get the local variables in scope for.
--- @return table A table of local variable names in scope for the PrgStatement.
---
function PrgStatement:VarsInScope()
	local vars = {}
	local current = self
	local block = GetParentTableOfKindNoCheck(self, "PrgBlock", "PrgPreset")
	while block do
		for _, statement in ipairs(block) do
			if statement ~= self then
				statement:GatherVars(vars)
			end
			if statement == current then break end
		end
		current = block
		block = GetParentTableOfKindNoCheck(block, "PrgBlock", "PrgPreset")
	end
	-- 'current' is now the PrgPreset
	for _, var in ipairs(current.Params) do
		vars[var] = true
	end
	vars[""] = nil -- skip "" vars due to unset properties
	return vars
end

---
--- Generates a line prefix for a PrgStatement object.
---
--- The line prefix includes a call to the `prgdbg` function, which is used for debugging purposes.
--- The prefix includes the current indent level and the index of the statement within the PrgBlock.
---
--- @param self PrgStatement The PrgStatement object to generate the line prefix for.
--- @param indent string The current indent level.
--- @param idx number The index of the statement within the PrgBlock.
--- @return string The generated line prefix.
---
function PrgStatement:LinePrefix(indent, idx)
	return string.format("%sprgdbg(li, %d, %d) ", indent, #indent, idx)
end

---
--- Gathers the variables declared by the current PrgStatement and adds them as keys in the provided `vars` table.
---
--- The values in the `vars` table will be either "local" or "static" depending on the variable declaration.
---
--- @param self PrgStatement The current PrgStatement object.
--- @param vars table The table to add the variables to.
---
function PrgStatement:GatherVars(vars)
	-- add variables declared by this statement as keys in the 'vars' table, with value "local" or "static"
end

---
--- Generates the code that declares the static variables for the PrgStatement.
---
--- This function is called to generate the code that will be inserted before the Prg function body. It is responsible for generating the code that declares any static variables that are used by the PrgStatement.
---
--- @param self PrgStatement The PrgStatement object.
--- @param code table A table that will be used to accumulate the generated code.
---
function PrgStatement:GenerateStaticCode(code)
	-- generate code to be inserted before the Prg function body, generates the code that declares the static vars
end

---
--- Generates the code for the Prg function body.
---
--- This function is responsible for generating the code that will be executed as part of the Prg function. It iterates through the PrgStatement objects within the PrgBlock and generates the code for each statement, appending it to the provided `code` table.
---
--- @param self PrgStatement The current PrgStatement object.
--- @param code table A table that will be used to accumulate the generated code.
--- @param indent string The current indent level.
--- @param idx number The index of the statement within the PrgBlock.
---
function PrgStatement:GenerateCode(code, indent, idx)
	-- generate code for the Prg function body
end

---
--- Generates the editor view string for the PrgStatement object.
---
--- The editor view string is a formatted string that represents the PrgStatement object in the editor. It includes the disabled prefix (if the statement is disabled) and the EditorView string, which is a template that can include placeholders for the statement's properties.
---
--- @param self PrgStatement The PrgStatement object to generate the editor view for.
--- @return string The generated editor view string.
---
function PrgStatement:GetEditorView()
	return _InternalTranslate(Untranslated("<DisabledPrefix>"), self, false) .. _InternalTranslate(self.EditorView, self, false)
end

---
--- Defines a class for a PrgBlock, which is a container for PrgStatement objects.
---
--- The PrgBlock class inherits from the PrgStatement and Container classes, and has a ContainerClass property that is set to "PrgStatement".
---
--- @class PrgBlock
--- @field __parents table The parent classes of the PrgBlock class.
--- @field ContainerClass string The class of the objects that can be contained within the PrgBlock.
DefineClass.PrgBlock = {
	__parents = { "PrgStatement", "Container" },
	ContainerClass = "PrgStatement",
}

---
--- Generates the static code for the PrgBlock.
---
--- This function is responsible for generating the code that declares any static variables used by the PrgStatement objects within the PrgBlock. It iterates through each PrgStatement in the PrgBlock and calls their `GenerateStaticCode` function to generate the static code.
---
--- @param self PrgBlock The PrgBlock object.
--- @param code table A table that will be used to accumulate the generated static code.
---
function PrgBlock:GenerateStaticCode(code)
	if #self == 0 then return end
	for i = 1, #self - 1 do
		self[i]:GenerateStaticCode(code)
	end
	self[#self]:GenerateStaticCode(code)
end

---
--- Generates the code for the PrgBlock.
---
--- This function iterates through each PrgStatement in the PrgBlock and calls their `GenerateCode` function to generate the code for the statement. If the statement is not disabled, the generated code is appended to the `code` table. After the last statement, a line is appended to the `code` table to set the `li[#indent]` variable to `nil`.
---
--- @param self PrgBlock The PrgBlock object.
--- @param code table A table that will be used to accumulate the generated code.
--- @param indent string The current indent level.
--- @param idx number The index of the PrgBlock within the containing PrgStatement or PrgBlock.
---
function PrgBlock:GenerateCode(code, indent, idx)
	if #self == 0 then return end
	indent = indent .. "\t"
	for i = 1, #self - 1 do
		if not self[i].Disable then
			self[i]:GenerateCode(code, indent, i)
			code:append("\n")
		end
	end
	if not self[#self].Disable then
		self[#self]:GenerateCode(code, indent, #self)
		code:appendf(" li[%d] = nil", #indent)
	end
end


----- Variables

local function get_expr_string(expr)
	if not expr or expr == empty_func then return "nil" end
	
	local name, parameters, body = GetFuncSource(expr)
	body = type(body) == "table" and table.concat(body, "\n") or body
	return body:match("^%s*return%s*(.*)") or body
end

---
--- Defines a class for a PrgAssign statement, which is used to assign a value to a variable.
---
--- The PrgAssign class has the following properties:
--- - `Variable`: The name of the variable to assign a value to. This is selected from a combo box of local variables.
---
--- The PrgAssign class has the following methods:
--- - `GatherVars(vars)`: Adds the variable name to the `vars` table, marking it as a local variable.
--- - `GenerateCode(code, indent, idx)`: Generates the code to assign a value to the variable, including declaring it as local if it doesn't already exist in scope.
--- - `GetValueCode()`: Returns the code to generate the value being assigned.
--- - `GetValueDescription()`: Returns a string description of the value being assigned.
---
DefineClass.PrgAssign = {
	__parents = { "PrgStatement" },
	properties = {
		{ id = "Variable", editor = "combo", default = "", items = PrgLocalVarsCombo, },
	},
	EditorView = Untranslated("<Variable> = <ValueDescription>"),
}

---
--- Gathers the variables used in the PrgAssign statement.
---
--- @param vars table A table to store the variables used in the PrgAssign statement.
---
function PrgAssign:GatherVars(vars)
	vars[self.Variable] = "local"
end

---
--- Generates the code to assign a value to a variable.
---
--- If the variable does not already exist in scope, it will be declared as a local variable.
---
--- @param code table The code table to append the generated code to.
--- @param indent table The current indentation level.
--- @param idx number The index of the statement within the current block.
---
function PrgAssign:GenerateCode(code, indent, idx)
	local var_exists = self:VarsInScope()[self.Variable]
	code:appendf("%s%s%s = %s", self:LinePrefix(indent, idx), var_exists and "" or "local ", self.Variable, self:GetValueCode())
end

---
--- Returns the code to generate the value being assigned.
---
--- This method should be defined in child classes of `PrgAssign`.
---
function PrgAssign:GetValueCode()
	-- define in child classes
end
---
--- Returns a string description of the value being assigned.
---
--- This method should be defined in child classes of `PrgAssign`.
---
function PrgAssign:GetValueDescription()
	-- define in child classes
end

function PrgAssign:GetValueDescription()
	-- define in child classes
end

---
--- Defines a class that represents an expression assignment to a variable.
---
--- The `PrgAssignExpr` class is a subclass of `PrgAssign` and is used to represent an assignment of an expression to a variable.
---
--- @class PrgAssignExpr
--- @field Value table The expression to be assigned to the variable.
--- @field __parents table The parent classes of this class.
--- @field properties table The properties of this class, including the `Value` expression.
--- @field EditorName string The name of this class in the editor.
--- @field EditorSubmenu string The submenu in the editor where this class is located.
--- @field StatementTag string The tag used to identify this class as a "Basics" statement.
---
DefineClass.PrgAssignExpr = {
	__parents = { "PrgAssign" },
	properties = {
		{ id = "Value", editor = "expression", default = empty_func },
	},
	EditorName = "Set variable",
	EditorSubmenu = "Basics",
	StatementTag = "Basics",
}

---
--- Returns the code to generate the value being assigned.
---
--- This method should be defined in child classes of `PrgAssign`.
---
function PrgAssignExpr:GetValueCode()
	return get_expr_string(self.Value)
end

---
--- Returns a string description of the expression being assigned.
---
--- This method should be defined in child classes of `PrgAssign` to provide a human-readable description of the expression being assigned to a variable.
---
--- @return string The description of the expression being assigned.
---
function PrgAssignExpr:GetValueDescription()
	return get_expr_string(self.Value)
end


----- Flow control - if / else, while, loops

---
--- Defines a class that represents a conditional statement (if/while) in a program.
---
--- The `PrgIf` class is a subclass of `PrgBlock` and is used to represent a conditional statement in a program. It has properties to define the condition for the statement and whether it should be a repeating loop (while) or a single conditional (if).
---
--- @class PrgIf
--- @field Repeat boolean Whether the conditional statement should be a repeating loop (while) or a single conditional (if).
--- @field Condition table The expression that defines the condition for the statement.
--- @field __parents table The parent classes of this class.
--- @field EditorName string The name of this class in the editor.
--- @field EditorSubmenu string The submenu in the editor where this class is located.
--- @field StatementTag string The tag used to identify this class as a "Basics" statement.
---
DefineClass.PrgIf = {
	__parents = { "PrgBlock" },
	properties = {
		{ id = "Repeat", name = "Repeat while satisfied", editor = "bool", default = false, },
		{ id = "Condition", editor = "expression", default = empty_func, },
	},
	EditorName = "Condition check (if/while)",
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Returns the expression code for the condition of the if/while statement.
---
--- @param for_preview boolean Whether the expression code is being generated for a preview in the editor.
--- @return string The expression code for the condition.
---
function PrgIf:GetExprCode(for_preview)
	return get_expr_string(self.Condition)
end

---
--- Generates the code for a conditional statement (if/while) in a program.
---
--- This method is responsible for generating the code for a conditional statement, which can be either a single if statement or a repeating while loop. It appends the appropriate code to the provided `code` object, using the specified `indent` and `idx` values.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param indent string The current indentation level.
--- @param idx integer The index of the current statement.
---
function PrgIf:GenerateCode(code, indent, idx)
	code:appendf(self.Repeat and "%swhile %s do\n" or "%sif %s then\n", self:LinePrefix(indent, idx), self:GetExprCode(false))
	PrgBlock.GenerateCode(self, code, indent)
	
	local parent = GetParentTableOfKind(self, "PrgBlock") or GetParentTableOfKind(self, "PrgPreset")
	local next_statement = parent[table.find(parent, self) + 1]
	if not IsKindOf(next_statement, "PrgElse") then
		code:appendf("\n%send", indent)
	end
end

---
--- Returns the editor view for the if/while statement.
---
--- The editor view is a string that represents how the if/while statement will be displayed in the editor. It includes the "if" or "while" keyword, and the condition expression.
---
--- @return string The editor view for the if/while statement.
---
function PrgIf:GetEditorView()
	return Untranslated("<DisabledPrefix>" .. (self.Repeat and "<keyword>while</keyword> " or "<keyword>if</keyword> ") .. self:GetExprCode(true))
end

---
--- Represents an "else" block in a conditional statement.
---
--- The `PrgElse` class is used to represent the "else" block in a conditional statement, such as an `if-else` or `if-elseif-else` statement. It is a subclass of `PrgBlock`, which means it inherits the functionality for generating code blocks.
---
--- @class PrgElse
--- @field EditorName string The name of the statement as it appears in the editor.
--- @field EditorView string The view of the statement as it appears in the editor.
--- @field EditorSubmenu string The submenu in the editor where the statement appears.
--- @field StatementTag string The tag used to categorize the statement.
DefineClass.PrgElse = {
	__parents = { "PrgBlock" },
	EditorName = "Condition else",
	EditorView = Untranslated("<keyword>else</keyword>"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Generates the code for an "else" block in a conditional statement.
---
--- This method is responsible for generating the code for an "else" block, which is used in conjunction with an "if" or "while" statement. It appends the appropriate code to the provided `code` object, using the specified `indent` and `idx` values.
---
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param indent string The current indentation level.
--- @param idx integer The index of the current statement.
---
function PrgElse:GenerateCode(code, indent, idx)
	if self:CheckPrgError() then return end
	code:appendf("%selse\n\t%s\n", indent, self:LinePrefix(indent, idx))
	PrgBlock.GenerateCode(self, code, indent, idx)
	code:appendf("\n%send", indent)
end

---
--- Checks if the current `PrgElse` statement has a valid parent `PrgBlock` or `PrgPreset`.
---
--- This function is used to ensure that the `PrgElse` statement is being used correctly within the context of a conditional statement (e.g. `PrgIf`). It checks if the previous statement in the parent `PrgBlock` or `PrgPreset` is a `PrgIf` statement, or if the previous statement is a `PrgIf` statement that has the `Repeat` property set.
---
--- @return boolean `true` if the `PrgElse` statement has a valid parent, `false` otherwise.
---
function PrgElse:CheckPrgError()
	local parent = GetParentTableOfKind(self, "PrgBlock") or GetParentTableOfKind(self, "PrgPreset")
	local prev_statement = parent[table.find(parent, self) - 1]
	return not IsKindOf(prev_statement, "PrgIf") or prev_statement.Repeat
end

---
--- Represents a "for each" loop statement in a code block.
---
--- The `PrgForEach` class is used to represent a "for each" loop statement, which iterates over the elements of a list variable. It is a subclass of `PrgBlock`, which means it inherits the functionality for generating code blocks.
---
--- @class PrgForEach
--- @field List string The name of the list variable to iterate over.
--- @field Value string The name of the variable to store the current value from the list.
--- @field Index string The name of the variable to store the current index of the list.
--- @field EditorName string The name of the statement as it appears in the editor.
--- @field EditorView string The view of the statement as it appears in the editor.
--- @field EditorSubmenu string The submenu in the editor where the statement appears.
--- @field StatementTag string The tag used to categorize the statement.
DefineClass.PrgForEach = {
	__parents = { "PrgBlock" },
	properties = {
		{ id = "List", name = "List variable", editor = "choice", default = "", items = PrgVarsCombo, },
		{ id = "Value", name = "Value variable", editor = "text", default = "value" },
		{ id = "Index", name = "Index variable", editor = "text", default = "i", },
	},
	EditorName = "For each",
	EditorView = Untranslated("<keyword>for each</keyword> '<Value>' <keyword>in</keyword> '<List>'"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Gathers the local variables used in the `PrgForEach` statement.
---
--- This function is responsible for identifying the local variables that are used within the `PrgForEach` statement and adding them to the `vars` table. The `vars` table is used to keep track of all the local variables that need to be declared at the beginning of the code block.
---
--- @param vars table The table of local variables to be gathered.
---
function PrgForEach:GatherVars(vars)
	vars[self.List] = "local"
	vars[self.Value] = "local"
	vars[self.Index] = "local"
end

---
--- Generates the code for a `PrgForEach` statement.
---
--- This function is responsible for generating the Lua code for a `PrgForEach` statement. It first checks if the `List` property is empty, and if so, it returns without generating any code. Otherwise, it generates a `for` loop that iterates over the elements of the list specified by the `List` property, using the variables specified by the `Index` and `Value` properties. It then calls the `GenerateCode` function of the `PrgBlock` class to generate the code for the block of statements within the `PrgForEach` statement.
---
--- @param code table The code generator object to which the generated code will be appended.
--- @param indent string The current indentation level.
--- @param idx number The index of the statement within the parent block.
---
function PrgForEach:GenerateCode(code, indent, idx)
	if self.List == "" then return end
	code:appendf("%sfor %s, %s in ipairs(%s) do\n", self:LinePrefix(indent, idx), self.Index, self.Value, self.List)
	PrgBlock.GenerateCode(self, code, indent)	
	code:appendf("\n%send", indent)
end


----- Calls (function and Prg)

-- calls self:Exec with sprocall, passing all property values in order as parameters
---
--- Represents a Prg statement that executes a function.
---
--- The `PrgExec` class is used to represent a Prg statement that executes a function. It inherits from the `PrgStatement` class and provides additional properties and methods to handle the execution of the function.
---
--- The `ExtraParams` property is used to specify any additional parameters that should be passed to the function before the properties of the `PrgExec` class.
---
--- The `AssignTo` property is used to specify the name of the variable to which the result of the function call should be assigned.
---
--- The `PassClassAsSelf` property is used to determine whether the class instance should be passed as the `self` parameter to the function being called.
---
--- @class PrgExec
--- @field ExtraParams table The extra parameters to pass to the function before the properties.
--- @field AssignTo string The name of the variable to assign the function result to.
--- @field PassClassAsSelf boolean Whether to pass the class instance as the `self` parameter to the function.
DefineClass.PrgExec = {
	__parents = { "PrgStatement" },
	ExtraParams = {}, -- extra params to pass before the properties, e.g. { "rand" } to use the random generator for the Prg
	AssignTo = "", -- variable name to assign function result to; create a property with the same name to allow the user specify it
	PassClassAsSelf = true,
}

---
--- Returns the list of properties for the PrgExec class.
---
--- This function is used to retrieve the list of properties defined for the PrgExec class. It is called by the GetParamProps function to get the list of properties that should be used to generate the parameter string for the Exec function.
---
--- @return table The list of properties for the PrgExec class.
---
function PrgExec:GetParamProps()
	return self:GetProperties()
end

---
--- Generates a string of parameters to be passed to the `Exec` function of the `PrgExec` class.
---
--- This function first checks if the `PassClassAsSelf` property is true, and if so, it adds the class instance to the list of parameters. It then appends any extra parameters specified in the `ExtraParams` property. Finally, it iterates over the properties returned by the `GetParamProps` function, and adds the corresponding values to the list of parameters, converting them to Lua code as necessary.
---
--- @param self PrgExec The instance of the `PrgExec` class.
--- @return string The string of parameters to be passed to the `Exec` function.
---
function PrgExec:GetParamString()
	local params = self.PassClassAsSelf and { self.class } or {}
	table.iappend(params, self.ExtraParams)
	for _, prop in ipairs(self:GetParamProps()) do
		if prop.editor ~= "help" and prop.editor ~= "buttons" and prop.id ~= "Disable" then
			local value = self:GetProperty(prop.id)
			params[#params + 1] =
				type(value) == "function"     and get_expr_string(value) or
				prop.variable and value == "" and "nil"                  or
				prop.variable and value ~= "" and value                  or ValueToLuaCode(value):gsub("[\t\r\n]", "")
		end
	end
	return table.concat(params, ", ")
end

---
--- Gathers the variables used in the `PrgExec` class and adds them to the provided `vars` table.
---
--- This function is called to gather the variables used in the `PrgExec` class, such as the variable specified by the `AssignTo` property. The gathered variables are added to the `vars` table, with the variable name as the key and the string `"local"` as the value, indicating that the variable is a local variable.
---
--- @param self PrgExec The instance of the `PrgExec` class.
--- @param vars table The table to add the gathered variables to.
---
function PrgExec:GatherVars(vars)
	vars[self.AssignTo] = "local"
end

---
--- Generates the code for executing the `PrgExec` class.
---
--- This function is responsible for generating the code that will execute the `PrgExec` class. If the `AssignTo` property is set, it will generate code to assign the result of the `Exec` function to a local variable. Otherwise, it will simply call the `Exec` function.
---
--- @param self PrgExec The instance of the `PrgExec` class.
--- @param code CodeBuffer The code buffer to append the generated code to.
--- @param indent string The current indentation level.
--- @param idx number The index of the current statement.
---
function PrgExec:GenerateCode(code, indent, idx)
	if self.AssignTo and self.AssignTo ~= "" then
		local var_exists = self:VarsInScope()[self.AssignTo]
		code:appendf("%slocal _%s\n", indent, var_exists and "" or ", " .. self.AssignTo)
		code:appendf("%s_, %s = sprocall(%s.Exec, %s)", self:LinePrefix(indent, idx), self.AssignTo, self.class, self:GetParamString())
	else
		code:appendf("%ssprocall(%s.Exec, %s)", self:LinePrefix(indent, idx), self.class, self:GetParamString())
	end
end

---
--- Executes the `PrgExec` class.
---
--- This function is responsible for executing the functionality of the `PrgExec` class. It is called with the parameters specified by the `Params` property of the class.
---
--- @param self PrgExec The instance of the `PrgExec` class.
--- @param ... any Any additional parameters passed to the function.
---
function PrgExec:Exec(...)
	-- IMPORTANT: 'self' will be the class and not the instance
	-- implement the function to execute here; all properties of your class are passed AS PARAMETERS in the order of their declaration
end

-- override to "export" an existing Lua function as a Prg statement
---
--- Defines a class for a Prg function.
---
--- The `PrgFunction` class is a subclass of `PrgExec` and provides additional properties and functionality for defining a Prg function. It allows specifying parameters, handling variable arguments, and generating the code for executing the function.
---
--- @class PrgFunction
--- @field Params string The comma-separated list of parameters for the function.
--- @field HasExtraParams boolean Indicates whether the function has variable arguments.
--- @field VarArgs table The list of variable arguments for the function.
--- @field Exec function The function to execute when the `PrgFunction` is executed.
--- @field PassClassAsSelf boolean Indicates whether the class instance should be passed as the `self` argument to the `Exec` function.
DefineClass.PrgFunction = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "VarArgs", name = "Add extra parameters", editor = "string_list", default = false, no_edit = function(self) return not self.HasExtraParams end },
	},
	
	PassClassAsSelf = false,
	
	Params = "", -- specify comma-separated parameters here
	HasExtraParams = false, -- has variable arguments?
	Exec = empty_func, -- function to execute
}

---
--- Generates the parameter properties for a `PrgFunction` instance.
---
--- This function is responsible for generating the parameter properties for a `PrgFunction` instance. It parses the `Params` property of the `PrgFunction` instance and creates a table of parameter properties, where each property has an `id` field corresponding to the parameter name, and an `editor` field set to `"expression"` with a default value of `empty_func`.
---
--- @param self PrgFunction The instance of the `PrgFunction` class.
--- @return table The table of parameter properties.
function PrgFunction:GetParamProps()
	local props = {}
	for param in string.gmatch(self.Params, "[^, ]+") do
		props[#props + 1] = { id = param, editor = "expression", default = empty_func, }
	end
	return props
end

---
--- Generates the parameter properties for a `PrgFunction` instance.
---
--- This function is responsible for generating the parameter properties for a `PrgFunction` instance. It parses the `Params` property of the `PrgFunction` instance and creates a table of parameter properties, where each property has an `id` field corresponding to the parameter name, and an `editor` field set to `"expression"` with a default value of `empty_func`.
---
--- @param self PrgFunction The instance of the `PrgFunction` class.
--- @return table The table of parameter properties.
function PrgFunction:GetParamProps()
	-- implementation
end
---
--- Generates the properties for a `PrgFunction` instance.
---
--- This function is responsible for generating the properties for a `PrgFunction` instance. It first checks if the properties have already been cached, and if not, it generates the parameter properties using the `GetParamProps()` function. It then copies the properties from the `PropertyObject` class, and inserts the `VarArgs` property if it exists. Finally, it appends the parameter properties to the class properties and caches the result.
---
--- @param self PrgFunction The instance of the `PrgFunction` class.
--- @return table The table of properties for the `PrgFunction` instance.
function PrgFunction:GetProperties()
	local props = g_PrgPresetPropsCache[self]
	if not props then
		props = self:GetParamProps()
		local class_props = table.copy(PropertyObject.GetProperties(self), "deep")
		local idx = table.find(class_props, "id", "VarArgs")
		if idx then
			table.insert(props, class_props[idx])
			table.remove(class_props, idx)
		end
		table.iappend(class_props, props)
		g_PrgPresetPropsCache[self] = class_props
	end
	return props
end

---
--- Generates the parameter string for a `PrgFunction` instance.
---
--- This function is responsible for generating the parameter string for a `PrgFunction` instance. It first gets the parameter string using the `PrgExec.GetParamString()` function. If the `PrgFunction` instance has extra parameters (indicated by the `HasExtraParams` property) and the `VarArgs` property is not `nil`, it appends the `VarArgs` parameters to the parameter string.
---
--- @param self PrgFunction The instance of the `PrgFunction` class.
--- @return string The parameter string for the `PrgFunction` instance.
function PrgFunction:GetParamString()
	local ret = PrgExec.GetParamString(self)
	if self.HasExtraParams and self.VarArgs then
		local extra = table.concat(self.VarArgs, ", ")
		ret = ret == "" and extra or (ret .. ", " .. extra)
	end
	return ret
end

-- call any Lua function by name
---
--- Defines a class for calling a Lua function.
---
--- The `PrgCallLuaFunction` class is used to call a Lua function from a `PrgPreset` instance. It has a `FunctionName` property that specifies the name of the Lua function to call, and the function's parameters are automatically extracted and used to generate the parameter string for the function call.
---
--- @class PrgCallLuaFunction
--- @field FunctionName string The name of the Lua function to call.
--- @field Params string The parameters of the Lua function.
--- @field HasExtraParams boolean Whether the Lua function has extra parameters.
--- @field StoreAsTable boolean Whether the function properties should be stored as a table.
--- @field EditorName string The name of the function in the editor.
--- @field EditorView string The view of the function in the editor.
--- @field EditorSubmenu string The submenu of the function in the editor.
--- @field StatementTag string The tag of the function in the editor.
DefineClass.PrgCallLuaFunction = {
	__parents = { "PrgFunction" },
	properties = {
		{ id = "FunctionName", name = "Function name", editor = "text", default = "",
			validate = function(self, value)
				return value ~= "" and not self:FindFunction(value) and "Can't find function with the specified name"
			end,
			help = "Lua function to call - use Object:MethodName if you'd like to call a class method."
		},
	},
	StoreAsTable = false, -- so SetFunctionName gets called upon loading
	
	EditorName = "Call function",
	EditorView = Untranslated("Call <FunctionName>(<ParamString>)"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Finds a Lua function with the specified name.
---
--- This function searches for a Lua function with the specified name in the global namespace. It splits the function name by the '.' and ':' characters and recursively looks up each part of the name in the global table.
---
--- @param self PrgCallLuaFunction The instance of the `PrgCallLuaFunction` class.
--- @param fn_name string The name of the Lua function to find.
--- @return function|nil The Lua function if found, otherwise `nil`.
function PrgCallLuaFunction:FindFunction(fn_name)
	local ret = _G
	for field in string.gmatch(fn_name, "[^:. ]+") do
		ret = rawget(ret, field)
		if not ret then return end
	end
	return fn_name ~= "" and ret
end

---
--- Sets the name of the Lua function to call.
---
--- This function is used to set the `FunctionName` property of the `PrgCallLuaFunction` class. It first checks if the new function name is different from the current one. If so, it attempts to find the Lua function with the specified name using the `FindFunction` method. If the function is found, it extracts the function's parameters and sets the `Params` and `HasExtraParams` properties accordingly. If the function name contains a colon `:`, it prepends `self` to the parameter list. Finally, it sets the `FunctionName` property and clears the `g_PrgPresetPropsCache` for this instance.
---
--- @param self PrgCallLuaFunction The instance of the `PrgCallLuaFunction` class.
--- @param fn_name string The name of the Lua function to set.
function PrgCallLuaFunction:SetFunctionName(fn_name)
	if self.FunctionName == fn_name then return end
	
	local fn = self:FindFunction(fn_name)
	local name, parameters, body = GetFuncSource(fn)
	if name then
		local extra = parameters:ends_with(", ...")
		self.Params = extra and parameters:sub(1, -6) or parameters
		self.HasExtraParams = extra
	else
		self.Params = nil
		self.HasExtraParams = nil
	end
	if string.find(fn_name, ":") then
		self.Params = self.Params == "" and "self" or ("self, " .. self.Params)
	end
	self.FunctionName = fn_name
	g_PrgPresetPropsCache[self] = nil
end

---
--- Generates the code for calling a Lua function.
---
--- This method generates the code for calling a Lua function with the specified parameters. It uses the `FunctionName` and `GetParamString` methods to construct the function call.
---
--- @param self PrgCallLuaFunction The instance of the `PrgCallLuaFunction` class.
--- @param code CodeWriter The code writer to append the function call to.
--- @param indent string The indentation level for the function call.
--- @param idx integer The index of the function call within the current code block.
function PrgCallLuaFunction:GenerateCode(code, indent, idx)
	code:appendf("%ssprocall(%s, %s)",  self:LinePrefix(indent, idx), self.FunctionName:gsub(":", "."), self:GetParamString())
end

---
--- Defines a class `PrgCallPrgBase` that inherits from `PrgStatement`. This class has properties that allow the user to select a Prg class, Prg preset group, and a specific Prg preset to call.
---
--- The `PrgClass` property allows the user to select a Prg class from a list of available classes that inherit from `PrgPreset`. The `PrgGroup` property allows the user to select a Prg preset group based on the selected `PrgClass`. The `Prg` property allows the user to select a specific Prg preset from the selected `PrgGroup`.
---
--- The class also has an `EditorName`, `EditorView`, `EditorSubmenu`, and `StatementTag` property that are used to customize the appearance and behavior of the class in the editor.
---
DefineClass.PrgCallPrgBase = {
	__parents = { "PrgStatement" },
	properties = {
	   { id = "PrgClass", name = "Prg class", editor = "choice", default = "", items = ClassDescendantsCombo("PrgPreset") },
	   { id = "PrgGroup", name = "Prg preset group", editor = "choice", default = "",
	     items = function(self) return PresetGroupsCombo(self.PrgClass) end, 
	     no_edit = function(self) return self.PrgClass == "" or g_Classes[self.PrgClass].GlobalMap end, },
		{ id = "Prg", editor = "preset_id", default = "",
		  preset_group = function(self) return self.PrgGroup ~= "" and self.PrgGroup end,
		  preset_class = function(self) return self.PrgClass ~= "" and self.PrgClass or "PrgPreset" end },
	},
	
	EditorName = "Call Prg",
	EditorView = Untranslated("Call Prg '<Prg>'"),
	EditorSubmenu = "Code flow",
	StatementTag = "Basics",
}

---
--- Gets the properties of the `PrgCallPrgBase` class.
---
--- This method returns the properties of the `PrgCallPrgBase` class, which includes the properties defined in the class definition as well as any additional properties that are dynamically added based on the selected Prg preset.
---
--- If a Prg preset is selected, the method will add additional properties to the list of properties based on the parameters defined in the Prg preset.
---
--- @return table The properties of the `PrgCallPrgBase` class.
function PrgCallPrgBase:GetProperties()
	local prg = self.Prg ~= "" and PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	if not prg then return self.properties end
	
	local props = g_PrgPresetPropsCache[self]
	if not props then
		props = table.copy(PropertyObject.GetProperties(self), "deep")
		for _, param in ipairs(prg.Params or empty_table) do
			props[#props + 1] = { id = param, editor = "expression", default = empty_func, }
		end
		g_PrgPresetPropsCache[self] = props
	end
	return props
end

---
--- Handles changes to the `PrgClass`, `PrgGroup`, and `Prg` properties of the `PrgCallPrgBase` class.
---
--- When the `PrgClass` property is changed, the `PrgGroup` property is updated to the second item in the `PresetGroupsCombo` list for the selected `PrgClass`, if the `PrgClass` is not a global map.
---
--- When the `PrgClass`, `PrgGroup`, or `Prg` property is changed, the `Prg` property is set to `nil`, and any additional properties that were dynamically added based on the selected Prg preset are removed from the object.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED object associated with the property.
function PrgCallPrgBase:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "PrgClass" then
		self.PrgGroup = self.PrgClass ~= "" and not g_Classes[self.PrgClass].GlobalMap and PresetGroupsCombo(self.PrgClass)()[2] or ""
	end
	if prop_id == "PrgClass" or prop_id == "PrgGroup" then
		self.Prg = nil
	end
	if prop_id == "PrgClass" or prop_id == "PrgGroup" or prop_id == "Prg" then
		local prop_cache = g_PrgPresetPropsCache[self]
		for _, prop in ipairs(prop_cache) do
			if not table.find(self.properties, "id", prop.id) then
				self[prop.id] = nil
			end
		end
		g_PrgPresetPropsCache[self] = nil
	end
end

---
--- Initializes the `PrgClass` and `PrgGroup` properties of the `PrgCallPrgBase` class after a new instance is created.
---
--- This method is called after a new instance of the `PrgCallPrgBase` class is created. It sets the `PrgClass` property to the class of the parent `PrgPreset` object, and sets the `PrgGroup` property to the second item in the `PresetGroupsCombo` list for the selected `PrgClass`, if the `PrgClass` is not a global map.
---
--- @method OnAfterEditorNew
--- @return nil
function PrgCallPrgBase:OnAfterEditorNew()
	local parent_prg = GetParentTableOfKind(self, "PrgPreset")
	self.PrgClass = parent_prg.class
	self.PrgGroup = self.PrgClass ~= "" and not g_Classes[self.PrgClass].GlobalMap and PresetGroupsCombo(self.PrgClass)()[2] or ""
end

---
--- Defines a new class `PrgCallPrg` that inherits from `PrgCallPrgBase`.
---
--- The `PrgCallPrg` class is used to represent a program call within a program preset. It is responsible for generating the code to call a specific program function with the appropriate parameters.
---
--- @class PrgCallPrg
--- @field PrgClass string The class of the program preset that this call belongs to.
--- @field PrgGroup string The group of the program preset that this call belongs to.
--- @field Prg string The ID of the program preset that this call is for.
--- @extends PrgCallPrgBase
DefineClass("PrgCallPrg", "PrgCallPrgBase")

---
--- Generates a comma-separated string of parameter values for the program preset associated with the `PrgCallPrg` object.
---
--- This function is used to generate the parameter string that will be passed to the program function when the program preset is executed. It retrieves the program preset instance associated with the `PrgCallPrg` object, and then generates a string of the parameter values by calling `get_expr_string()` on each parameter property of the program preset.
---
--- @return string A comma-separated string of parameter values for the program preset.
function PrgCallPrg:GetParamString()
	local prg = PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	local params = {}
	for _, param in ipairs(prg.Params or empty_table) do
		params[#params + 1] = get_expr_string(rawget(self, param))
	end
	return table.concat(params, ", ")
end

---
--- Generates the code to call a program function with the appropriate parameters.
---
--- This method is called to generate the code that will execute the program function associated with the `PrgCallPrg` object. It retrieves the program preset instance associated with the `PrgCallPrg` object, and then generates a `sprocall()` statement that calls the program function with the appropriate parameters.
---
--- @param code table The code table to append the generated code to.
--- @param indent number The current indentation level.
--- @param idx number The index of the `PrgCallPrg` object in the list of program calls.
--- @return nil
function PrgCallPrg:GenerateCode(code, indent, idx)
	if self.PrgClass == "" or self.Prg == "" then return end
	
	local prg = PresetIdPropFindInstance(self, table.find_value(self.properties, "id", "Prg"), self.Prg)
	if prg then
		code:appendf("%ssprocall(%s.%s, rand(), %s)", self:LinePrefix(indent, idx), prg.FuncTable, prg:GenerateFuncName(), self:GetParamString())
	end
end

---
--- Defines a new class `PrgPrint` that inherits from `PrgFunction`.
---
--- The `PrgPrint` class is used to represent a program function that prints a message to the console. It is responsible for generating the code to call the `print()` function with the appropriate parameters.
---
--- @class PrgPrint
--- @field Params string The parameter string for the program function.
--- @field HasExtraParams boolean Indicates whether the program function has additional parameters beyond those defined in the `Params` field.
--- @field Exec function The function to execute when the program function is called.
--- @field EditorName string The name of the program function as it appears in the editor.
--- @field EditorView string The editor view for the program function.
--- @field EditorSubmenu string The submenu in the editor where the program function appears.
--- @field StatementTag string The tag used to identify the program function in the editor.
--- @extends PrgFunction
DefineClass.PrgPrint = {
	__parents = { "PrgFunction" },
	Params = "",
	HasExtraParams = true,
	Exec = print,
	EditorName = "Print on console",
	EditorView = Untranslated("Print <ParamString>"),
	EditorSubmenu = "Basics",
	StatementTag = "Basics",
}

---
--- Defines a new class `PrgExecuteEffects` that inherits from `PrgExec`.
---
--- The `PrgExecuteEffects` class is used to represent a program function that executes a list of effects. It is responsible for generating the code to execute the effects and displaying the appropriate editor view.
---
--- @class PrgExecuteEffects
--- @field Effects table A list of effects to be executed.
--- @field EditorName string The name of the program function as it appears in the editor.
--- @field EditorSubmenu string The submenu in the editor where the program function appears.
--- @field StatementTag string The tag used to identify the program function in the editor.
--- @extends PrgExec
DefineClass.PrgExecuteEffects = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
	},
	EditorName = "Execute effects",
	EditorSubmenu = "Basics",
	StatementTag = "Effects",
}

---
--- Generates the editor view for the `PrgExecuteEffects` class, which represents a program function that executes a list of effects.
---
--- The editor view displays the list of effects that will be executed, with each effect's editor view displayed on a new line, prefixed by `"--> "`.
---
--- @param self PrgExecuteEffects The instance of the `PrgExecuteEffects` class.
--- @return string The generated editor view.
---
function PrgExecuteEffects:GetEditorView()
	local items = { _InternalTranslate("<DisabledPrefix>Execute effects:", self, false) }
	for _, effect in ipairs(self.Effects or empty_table) do
		items[#items + 1] = "--> " .. _InternalTranslate(Untranslated("<EditorView>"), effect, false)
	end
	return table.concat(items, "\n")
end

---
--- Executes a list of effects.
---
--- @param effects table A list of effects to be executed.
--- @return any The result of executing the effect list.
---
function PrgExecuteEffects:Exec(effects)
	return ExecuteEffectList(effects)
end


----- Get objects (add/remove/assign a list of objects to a variable)

---
--- Defines a new class `PrgGetObjs` that inherits from `PrgExec`.
---
--- The `PrgGetObjs` class is used to represent a program function that gets a list of objects. It is responsible for generating the code to get the objects and displaying the appropriate editor view.
---
--- @class PrgGetObjs
--- @field Action string The action to perform on the objects, either "Assign", "Add to", or "Remove from".
--- @field AssignTo string The variable to assign the objects to.
--- @extends PrgExec
---
DefineClass.PrgGetObjs = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Action", editor = "choice", default = "Assign", items = { "Assign", "Add to", "Remove from" }, },
		{ id = "AssignTo", name = "Objects variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

---
--- Generates the editor view for the `PrgGetObjs` class, which represents a program function that gets a list of objects.
---
--- The editor view displays the action to be performed on the objects, either "Assign", "Add to", or "Remove from", along with a description of the objects.
---
--- @param self PrgGetObjs The instance of the `PrgGetObjs` class.
--- @return string The generated editor view.
---
function PrgGetObjs:GetEditorView()
	local prefix = _InternalTranslate("<DisabledPrefix>", self, false)
	if self.Action == "Assign" then
		return string.format("'%s' = %s", self.AssignTo, self:GetObjectsDescription())
	elseif self.Action == "Add to" then
		return string.format("'%s' += %s", self.AssignTo, self:GetObjectsDescription())
	else -- if self.Action == "Remove from" then
		return string.format("'%s' -= %s", self.AssignTo, self:GetObjectsDescription())
	end
end

---
--- Executes the specified action on the list of objects.
---
--- @param Action string The action to perform on the objects, either "Assign", "Add to", or "Remove from".
--- @param AssignTo any The variable or object to assign the objects to.
--- @param ... any Additional parameters to pass to the `GetObjects` function.
--- @return any The resulting list of objects after the action is performed.
---
function PrgGetObjs:Exec(Action, AssignTo, ...)
	if self.Action == "Assign" then
		return self:GetObjects(...)
	elseif self.Action == "Add to" then
		local objs = IsKindOf(AssignTo, "Object") and { AssignTo } or AssignTo or {}
		return table.iappend(objs, self:GetObjects(...))
	else -- if self.Action == "Remove from" then
		local objs = IsKindOf(AssignTo, "Object") and { AssignTo } or AssignTo or {}
		return table.subtraction(objs, self:GetObjects(...))
	end
	return AssignTo
end

---
--- Generates a text description of the objects that the `PrgGetObjs` class will operate on.
---
--- The description should provide a concise summary of the objects, such as their type, location, or other relevant details.
---
--- @return string The text description of the objects.
---
function PrgGetObjs:GetObjectsDescription()
	-- return a text that describes the objects here, e.g. "enemy units of the unit in 'Variable'"
end

---
--- Executes the specified action on the list of objects.
---
--- @param ... any Additional parameters to pass to the `GetObjects` function.
--- @return any The resulting list of objects after the action is performed.
---
function PrgGetObjs:GetObjects(...)
	-- the properties after Action and Variable are passed to this function; return the list of objects here
end

---
--- Defines a class that gets objects from a specified group.
---
--- The `GetObjectsInGroup` class is a subclass of `PrgGetObjs` that allows you to get a list of objects from a specified group.
---
--- @class GetObjectsInGroup
--- @field Group string The name of the group to get objects from.
--- @field __parents table The parent classes of this class.
--- @field properties table The properties of this class, including the `Group` property.
--- @field EditorName string The name of this class in the editor.
---
--- @return table The list of objects from the specified group.
---
function GetObjectsInGroup:GetObjectsDescription()
	return string.format("objects from group '%s'", self.Group)
end

---
--- Gets the list of objects from the specified group.
---
--- @param Group string The name of the group to get objects from.
--- @return table The list of objects from the specified group.
---
function GetObjectsInGroup:GetObjects(Group)
	return table.copy(Groups[Group] or empty_table)
end
DefineClass.GetObjectsInGroup = {
__parents = { "PrgGetObjs" },
	properties = {
		{ id = "Group", editor = "choice", default = "", items = function() return table.keys2(Groups, true, "") end, },
	},
	EditorName = "Get objects from group",
}

--- Gets the text description of the objects from the specified group.
---
--- @return string The text description of the objects.
function GetObjectsInGroup:GetObjectsDescription()
	return string.format("objects from group '%s'", self.Group)
end

---
--- Gets the list of objects from the specified group.
---
--- @param Group string The name of the group to get objects from.
--- @return table The list of objects from the specified group.
---
function GetObjectsInGroup:GetObjects(Group)
	return table.copy(Groups[Group] or empty_table)
end


----- Object list filtering

---
--- Defines a class for filtering objects in a program.
---
--- @class PrgFilterObjs
--- @field AssignTo string The name of the variable to assign the filtered objects to.
--- @field __parents table The parent classes of this class.
--- @field properties table The properties of this class, including the `AssignTo` property.
--- @field EditorSubmenu string The name of the submenu in the editor where this class appears.
--- @field StatementTag string The tag used for this class in program statements.
---
DefineClass.PrgFilterObjs = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "AssignTo", name = "Objects variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

---
--- Defines a class for filtering objects in a program based on their classes.
---
--- @class FilterByClass
--- @field Classes table The list of classes to filter by.
--- @field Negate boolean Whether to negate the filter (i.e. remove objects of the specified classes instead of keeping them).
--- @field AssignTo string The name of the variable to assign the filtered objects to.
--- @field __parents table The parent classes of this class.
--- @field properties table The properties of this class, including the `Classes` and `Negate` properties.
--- @field EditorName string The name of this class in the editor.
---
DefineClass.FilterByClass = {
	__parents = { "PrgFilterObjs" },
	properties = {
		{ id = "Classes", editor = "string_list", default = false, items = ClassDescendantsCombo("Object"), arbitrary_value = true, },
		{ id = "Negate", editor = "bool", default = false, },
	},
	EditorName = "Filter by class",
}

---
--- Generates the editor view string for a FilterByClass object.
---
--- The editor view string describes how the FilterByClass object will filter objects.
--- If the Negate property is true, the string will indicate that only objects of the specified classes will be kept.
--- Otherwise, the string will indicate that objects of the specified classes will be removed.
---
--- @param self FilterByClass The FilterByClass object to generate the editor view for.
--- @return string The editor view string.
---
function FilterByClass:GetEditorView()
	return self.Negate and
		string.format("Leave only objects of classes %s in '%s'", table.concat(self.Classes, ", "), self.AssignTo) or
		string.format("Remove objects of classes %s in '%s'", table.concat(self.Classes, ", "), self.AssignTo)
end

---
--- Filters a list of objects based on their classes.
---
--- @param objs table The list of objects to filter.
--- @param Negate boolean Whether to negate the filter (i.e. remove objects of the specified classes instead of keeping them).
--- @param Classes table The list of classes to filter by.
--- @return table The filtered list of objects.
---
function FilterByClass:Exec(objs, Negate, Classes)
	return table.ifilter(objs, function(i, obj) return Negate == not IsKindOfClasses(obj, table.unpack(Classes)) end)
end

---
--- Defines a class for randomly selecting a subset of objects from a list.
---
--- @class SelectObjectsAtRandom
--- @field Percentage number The percentage of objects to keep, between 1 and 100.
--- @field MaxCount number The maximum number of objects to keep, or 0 for no limit.
--- @field AssignTo string The name of the variable to assign the selected objects to.
--- @field __parents table The parent classes of this class.
--- @field properties table The properties of this class, including the `Percentage` and `MaxCount` properties.
--- @field ExtraParams table The extra parameters required by this class, including `rand`.
--- @field EditorName string The name of this class in the editor.
---
DefineClass.SelectObjectsAtRandom = {
	__parents = { "PrgFilterObjs" },
	properties = {
		{ id = "Percentage", editor = "number", default = 100, min = 1, max = 100, slider = true },
		{ id = "MaxCount", editor = "number", default = 0, },
	},
	ExtraParams = { "rand" },
	EditorName = "Filter at random",
}

---
--- Generates the editor view string for a SelectObjectsAtRandom object.
---
--- The editor view string describes how the SelectObjectsAtRandom object will filter objects.
--- If the MaxCount is 0, the string will indicate that a percentage of the objects will be kept.
--- If the Percentage is 100, the string will indicate that no more than the MaxCount objects will be kept.
--- Otherwise, the string will indicate that a percentage of the objects will be kept, but no more than the MaxCount.
---
--- @param self SelectObjectsAtRandom The SelectObjectsAtRandom object to generate the editor view for.
--- @return string The editor view string.
---
function SelectObjectsAtRandom:GetEditorView()
	if self.MaxCount <= 0 then
		return string.format("Leave %d%% of the objects in '%s'", self.Percentage, self.AssignTo)
	elseif self.Percentage == 100 then
		return string.format("Leave no more than %d objects in '%s'", self.MaxCount, self.AssignTo)
	else
		return string.format("Leave %d%% of the objects in '%s', but no more than %d", self.Percentage, self.AssignTo, self.MaxCount)
	end
end

---
--- Randomly selects a subset of objects from a list.
---
--- @param rand function The random number generator function to use.
--- @param objs table The list of objects to select from.
--- @param Percentage number The percentage of objects to keep, between 1 and 100.
--- @param MaxCount number The maximum number of objects to keep, or 0 for no limit.
--- @return table The selected objects.
---
function SelectObjectsAtRandom:Exec(rand, objs, Percentage, MaxCount)
	local count = MulDivRound(#objs, Percentage, 100)
	if MaxCount > 0 then
		count = Min(count, MaxCount)
	end
	
	local ret, taken, len = {}, {}, #objs
	--local added = {}
	while count > 0 do
		local idx = rand(len) + 1
		ret[count] = objs[taken[idx] or idx]
		--assert(not added[ret[count]])
		--added[ret[count]] = true
		count, len = count - 1, len - 1
		taken[idx] = taken[len] or len
	end
	return ret
end


----- Others

---
--- Defines a class for deleting objects.
---
--- The `DeleteObjects` class is used to delete a set of objects. It provides an editor interface to select the objects to be deleted.
---
--- @class DeleteObjects
--- @field ObjectsVar string The name of the variable containing the objects to be deleted.
--- @field EditorName string The name of the editor UI element.
--- @field EditorView string The description of the editor UI element.
--- @field EditorSubmenu string The name of the editor submenu.
--- @field StatementTag string The tag used to identify the statement in the editor.
---
--- @function Exec
--- @param ObjectsVar table The objects to be deleted.
--- @return nil
---
DefineClass.DeleteObjects = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "ObjectsVar", name = "Objects variable", editor = "choice", default = "", items = PrgLocalVarsCombo, variable = true, },
	},
	EditorName = "Delete objects",
	EditorView = Untranslated("Delete the objects in '<ObjectsVar>'"),
	EditorSubmenu = "Objects",
	StatementTag = "Objects",
}

---
--- Deletes the objects specified in the `ObjectsVar` variable.
---
--- This function is used to delete a set of objects. It first begins an editor undo operation, then sends an `EditorCallbackDelete` message if the editor is active, and finally deletes each object in the `ObjectsVar` variable. Finally, it ends the editor undo operation.
---
--- @param ObjectsVar table The objects to be deleted.
--- @return nil
---
function DeleteObjects:Exec(ObjectsVar)
	ObjectsVar = ObjectsVar or empty_table
	XEditorUndo:BeginOp{ objects = ObjectsVar } -- does nothing if outside of editor
	if IsEditorActive() then
		Msg("EditorCallback", "EditorCallbackDelete", ObjectsVar)
	end
	for _, obj in ipairs(ObjectsVar) do obj:delete() end
	XEditorUndo:EndOp()
end
