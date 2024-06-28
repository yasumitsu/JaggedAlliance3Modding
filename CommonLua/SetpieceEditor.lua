if Platform.ged then return end

if FirstLoad then
	SetpieceDebugState = {}
	SetpieceLastStatement = false
	SetpieceSelectedStatement = false
	SetpieceVariableRefs = {}
end

-- Replace the GedEditorView functions of Setpiece statements to allow statements highlighting, depending on data
---
--- Modifies the `GetEditorView` function of `PrgStatement` classes with the `StatementTag` of "Setpiece" to provide custom coloring and highlighting for Setpiece statements in the editor.
---
--- The coloring and highlighting is based on the following conditions:
--- - If the statement is currently "running", it is colored green.
--- - If the statement has "completed", it is colored dark green.
--- - If there are no active Setpiece statements, the selected Setpiece statement is colored blue.
--- - If there are active Setpiece variable references, the selected Setpiece statement is colored green.
---
--- This function is called during the `ClassesPostprocess` event, which is triggered after all classes have been loaded.
---
function OnMsg.ClassesPostprocess()
	ClassDescendants("PrgStatement", function(name, class)
		if class.StatementTag == "Setpiece" then
			local old_fn = class.GetEditorView
			class.GetEditorView = function(self)
				local state = SetpieceDebugState[self]
				local color_tag =
					state == "running" and "<color 0 210 0>" or
					state == "completed" and "<color 0 128 0>" or
					not next(SetpieceDebugState) and 
						(SetpieceVariableRefs[self] and "<color 0 210 0>" or 
						 not next(SetpieceVariableRefs) and SetpieceSelectedStatement and SetpieceSelectedStatement.class == self.class and "<color 75 105 198>")
					or 	""
				return Untranslated(color_tag .. (old_fn and old_fn(self) or self.EditorView))
			end
		end
	end)
end


----- Highlight statements in Ged as they are being executed

---
--- Handles the processing of Setpiece statements when a program line is executed.
---
--- This function is called when a program line is executed, and it processes the Setpiece statements associated with that line.
---
--- If a Setpiece statement is found, it is marked as "running" or "completed" in the `SetpieceDebugState` table, depending on the type of statement. The `SetpieceLastStatement` variable is also updated to reference the current statement.
---
--- The function also calls `ObjModified` on the Setpiece object to trigger any necessary updates.
---
--- @param lineinfo table The information about the program line that was executed.
function OnMsg.OnPrgLine(lineinfo)
	local setpiece = Setpieces[lineinfo.id]
	local statement = TreeNodeByPath(setpiece, unpack_params(lineinfo))
	if statement then -- can mismatch if the preset and the generated code do not match
		SetpieceLastStatement = statement
		SetpieceDebugState[statement] = IsKindOf(statement, "PrgSetpieceCommand") and "running" or "completed"
	end
	ObjModified(setpiece)
end

---
--- Handles the completion of a Setpiece command.
---
--- This function is called when a Setpiece command has completed execution. It updates the `SetpieceDebugState` table to mark the corresponding statement as "completed", and calls `ObjModified` on the Setpiece object to trigger any necessary updates.
---
--- @param state table The Setpiece state object.
--- @param thread table The Setpiece thread object.
--- @param statement PrgStatement The Setpiece statement that has completed.
---
function OnMsg.SetpieceCommandCompleted(state, thread, statement)
	SetpieceDebugState[statement] = "completed"
	ObjModified(state.setpiece)
end

---
--- Handles the completion of a Setpiece execution.
---
--- This function is called when a Setpiece has finished executing. It clears the `SetpieceDebugState` table for all the statements in the Setpiece, and calls `ObjModified` on the Setpiece object to trigger any necessary updates.
---
--- @param setpiece SetpiecePrg The Setpiece that has finished executing.
---
function OnMsg.SetpieceEndExecution(setpiece)
	setpiece:ForEachSubObject("PrgStatement", function(obj)
		SetpieceDebugState[obj] = nil
	end)
	ObjModified(setpiece)
end


----- Highlight setpiece statements with a matching actor upon selection

---
--- Handles the selection of a Setpiece statement in the editor.
---
--- This function is called when a Setpiece statement is selected or deselected in the editor. If a Setpiece statement is selected, it updates the `SetpieceSelectedStatement` and `SetpieceVariableRefs` variables to keep track of the selected statement and any variables it references. If a Setpiece statement is deselected, it clears these variables.
---
--- @param obj PrgStatement The Setpiece statement that was selected or deselected.
--- @param method string The method that was called on the object (e.g. "OnEditorSelect").
--- @param selected boolean Whether the object was selected or deselected.
--- @param ged table The GED object associated with the object.
---
function OnMsg.GedNotify(obj, method, selected, ged)
	if IsKindOf(obj, "PrgStatement") and obj.StatementTag == "Setpiece" and method == "OnEditorSelect" then
		if not selected then
			SetpieceSelectedStatement = false
			SetpieceVariableRefs = {}
		elseif SetpieceSelectedStatement ~= obj then
			SetpieceSelectedStatement = obj
			UpdateSetpieceVariableRefs()
		end
	end
end

---
--- Handles the editing of a property on a Setpiece statement.
---
--- This function is called when a property on a Setpiece statement is edited in the editor. If the edited property is a variable, it calls `UpdateSetpieceVariableRefs()` to update the references to that variable in the Setpiece.
---
--- @param ged_id string The ID of the GED object that was edited.
--- @param obj PrgStatement The Setpiece statement object that was edited.
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The old value of the property.
---
function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	if IsKindOf(obj, "PrgStatement") and obj:GetPropertyMetadata(prop_id).variable then
		UpdateSetpieceVariableRefs()
	end
end

---
--- Handles the notification of editor events for PrgStatement objects.
---
--- This function is called when a PrgStatement object is deleted or a new one is created in the editor. When this happens, it calls the `UpdateSetpieceVariableRefs()` function to update the references to variables used in the Setpiece.
---
--- @param obj PrgStatement The PrgStatement object that was deleted or created.
--- @param method string The method that was called on the object (e.g. "OnEditorDelete" or "OnAfterEditorNew").
---
function OnMsg.GedNotify(obj, method, ...)
	if IsKindOf(obj, "PrgStatement") and (method == "OnEditorDelete" or method == "OnAfterEditorNew") then
		UpdateSetpieceVariableRefs()
	end
end

---
--- Updates the references to variables used in the currently selected Setpiece statement.
---
--- This function is called when a property on a Setpiece statement is edited, or when a PrgStatement object is deleted or created in the editor. It iterates through all the properties of the currently selected Setpiece statement, and collects the names of any variables that are used. It then iterates through all the PrgStatement objects in the Setpiece, and marks any statements that reference those variables as being part of the Setpiece's variable references.
---
--- @param none
--- @return none
---
function UpdateSetpieceVariableRefs()
	local statement = SetpieceSelectedStatement
	if not statement then return end
	
	local variables = {}
	for _, prop_meta in ipairs(statement:GetProperties()) do
		if prop_meta.variable then
			local var_name = statement:GetProperty(prop_meta.id)
			if var_name ~= "" then
				variables[var_name] = true
				table.insert(variables, var_name)
			end
		end
	end
	
	SetpieceVariableRefs = {}
	local setpiece = GetParentTableOfKind(statement, "SetpiecePrg")
	setpiece:ForEachSubObject("PrgStatement", function(statement)
		for _, prop_meta in ipairs(statement:GetProperties()) do
			if prop_meta.variable and variables[statement:GetProperty(prop_meta.id)] then
				SetpieceVariableRefs[statement] = true
			end
		end
	end)
	
	ObjModified(setpiece)
end
