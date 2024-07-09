DefineClass.EditorObject = {
	__parents = { "CObject" },

	EditorEnter = empty_func,
	EditorExit = empty_func,
}

---
--- Called after the object is loaded from the map.
--- If the editor is active, this will call the `EditorEnter()` function to mark the object as visible in the editor.
---
function EditorObject:PostLoad()
	if IsEditorActive() then
		self:EditorEnter()
	end
end

RecursiveCallMethods.EditorEnter = "procall"
RecursiveCallMethods.EditorExit = "procall_parents_last"

DefineClass.EditorCallbackObject = {
	__parents = { "CObject" },
	flags = { cfEditorCallback = true },

	-- all callbacks receive no parameters, except EditorCallbackClone, which receives the original object
	EditorCallbackPlace = empty_func,
	EditorCallbackPlaceCursor = empty_func,
	EditorCallbackDelete = empty_func,
	EditorCallbackRotate = empty_func,
	EditorCallbackMove = empty_func,
	EditorCallbackScale = empty_func,
	EditorCallbackClone = empty_func, -- function(orig) end,
	EditorCallbackGenerate = empty_func, -- function(generator, object_source, placed_objects, prefab_list) end,
}

AutoResolveMethods.EditorCallbackPlace = true
AutoResolveMethods.EditorCallbackPlaceCursor = true
AutoResolveMethods.EditorCallbackDelete = true
AutoResolveMethods.EditorCallbackRotate = true
AutoResolveMethods.EditorCallbackMove = true
AutoResolveMethods.EditorCallbackScale = true
AutoResolveMethods.EditorCallbackClone = true
AutoResolveMethods.EditorCallbackGenerate = true

function OnMsg.ChangeMapDone()
	--CObjects that are EditorVisibleObject will get saved as efVisible == true and pop up on first map load
	if GetMap() == "" then return end
	if not IsEditorActive() then
		MapForEach("map", "EditorVisibleObject", const.efVisible, function(o)
			o:ClearEnumFlags(const.efVisible)
		end)
	end
end

DefineClass.EditorVisibleObject = {
	__parents = { "EditorObject" },
	flags = { efVisible = false },
	properties = {
		{ id = "OnCollisionWithCamera" },
	},
}

---
--- Sets the efVisible flag on the EditorVisibleObject when entering the editor.
---
--- This function is called when the editor is activated and the object needs to be
--- made visible in the editor interface.
---
--- @function EditorVisibleObject:EditorEnter
--- @return nil
function EditorVisibleObject:EditorEnter()
	self:SetEnumFlags(const.efVisible)
end

---
--- Sets the efVisible flag on the EditorVisibleObject when exiting the editor.
---
--- This function is called when the editor is deactivated and the object needs to be
--- made invisible in the editor interface.
---
--- @function EditorVisibleObject:EditorExit
--- @return nil
function EditorVisibleObject:EditorExit()
	self:ClearEnumFlags(const.efVisible)
end

----

DefineClass.EditorColorObject = {
	__parents = { "EditorObject" },
	editor_color = false,
	orig_color = false,
}

---
--- Returns the editor color of the EditorColorObject.
---
--- @return boolean|table The editor color of the object, or false if no editor color is set.
function EditorColorObject:EditorGetColor()
	return self.editor_color
end

---
--- Sets the editor color of the EditorColorObject when entering the editor.
---
--- This function is called when the editor is activated and the object needs to be
--- styled with a custom color in the editor interface.
---
--- If the object has an editor color set, the original color modifier is stored and
--- the editor color is applied to the object.
---
--- @function EditorColorObject:EditorEnter
--- @return nil
function EditorColorObject:EditorEnter()
	local editor_color = self:EditorGetColor()
	if editor_color then
		self.orig_color = self:GetColorModifier()
		self:SetColorModifier(editor_color)
	end
end

---
--- Restores the original color modifier of the EditorColorObject when exiting the editor.
---
--- This function is called when the editor is deactivated and the object needs to revert
--- to its original color in the editor interface.
---
--- If the object had an editor color set, the original color modifier is restored.
---
--- @function EditorColorObject:EditorExit
--- @return nil
function EditorColorObject:EditorExit()
	if self.orig_color then
		self:SetColorModifier(self.orig_color)
		self.orig_color = false
	end
end

---
--- Returns the original color modifier of the EditorColorObject.
---
--- If the object has an original color modifier stored, this function returns that.
--- Otherwise, it calls the GetColorModifier function of the parent EditorObject class.
---
--- @return table The original color modifier of the object.
function EditorColorObject:GetColorModifier()
	if self.orig_color then
		return self.orig_color
	end
	return EditorObject.GetColorModifier(self)
end

----

DefineClass.EditorEntityObject = {
	__parents = { "EditorCallbackObject", "EditorColorObject" },
	entity = "",
	editor_entity = "",
	orig_scale = false,
	editor_scale = false,
}

---
--- Determines if the EditorEntityObject can be placed in the editor.
---
--- This function always returns true, indicating that the EditorEntityObject can be placed.
---
--- @return boolean Always returns true.
function EditorEntityObject:EditorCanPlace()
	return true
end

---
--- Sets the editor entity and scale of the EditorEntityObject.
---
--- If the object has an editor entity set, this function changes the entity to the editor entity when `set` is true, or back to the original entity when `set` is false.
---
--- If the object has an editor scale set, this function sets the scale to the editor scale when `set` is true, and restores the original scale when `set` is false.
---
--- @param set boolean Whether to set the editor entity and scale, or restore the original entity and scale.
--- @return nil
function EditorEntityObject:SetEditorEntity(set)
	if (self.editor_entity or "") ~= "" then
		self:ChangeEntity(set and self.editor_entity or g_Classes[self.class]:GetEntity())
	end
	if self.editor_scale then
		if set then
			self.orig_scale = self:GetScale()
			self:SetScale(self.editor_scale)
		elseif self.orig_scale then
			self:SetScale(self.orig_scale)
			self.orig_scale = false
		end
	end
end
---
--- Gets the scale of the EditorEntityObject.
---
--- If the object has an original scale set, this function returns the original scale. Otherwise, it calls the GetScale function of the EditorObject class.
---
--- @return number The scale of the EditorEntityObject.
function EditorEntityObject:GetScale()
	if self.orig_scale then
		return self.orig_scale
	end
	return EditorObject.GetScale(self)
end

---
--- Sets the editor entity of the EditorEntityObject to the editor entity.
---
--- This function is called when the EditorEntityObject enters the editor. It sets the entity of the object to the editor entity, if one is defined.
---
--- @return nil
function EditorEntityObject:EditorEnter()
	self:SetEditorEntity(true)
end
---
--- Restores the original entity and scale of the EditorEntityObject when exiting the editor.
---
--- This function is called when the EditorEntityObject exits the editor. It sets the entity of the object back to the original entity, and restores the original scale if it was previously set.
---
--- @return nil
function EditorEntityObject:EditorExit()
	self:SetEditorEntity(false)
end
function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackPlace" or id == "EditorCallbackPlaceCursor" then
		for i = 1, #objects do
			local obj = objects[i]
			if obj:IsKindOf("EditorEntityObject") then
				obj:SetEditorEntity(true)
			end
		end
	end
end

----

DefineClass.EditorTextObject = {
	__parents = { "EditorObject", "ComponentAttach" },
	editor_text_spot = "Label",
	editor_text_color = RGBA(255,255,255,255),
	editor_text_offset = point(0,0,3*guim),
	editor_text_style = false,
	editor_text_depth_test = true,
	editor_text_ctarget = "SetColor",
	editor_text_obj = false,
	editor_text_member = "class",
	editor_text_class = "Text",
}

---
--- Sets up the editor text object when the EditorTextObject enters the editor.
---
--- This function is called when the EditorTextObject enters the editor. It updates the editor text object, creating it if necessary.
---
--- @return nil
function EditorTextObject:EditorEnter()
	self:EditorTextUpdate(true)
end

---
--- Restores the original editor text object when the EditorTextObject exits the editor.
---
--- This function is called when the EditorTextObject exits the editor. It destroys the editor text object that was created when the EditorTextObject entered the editor.
---
--- @return nil
function EditorTextObject:EditorExit()
	DoneObject(self.editor_text_obj)
	self.editor_text_obj = nil
end

AutoResolveMethods.EditorGetText = ".."

---
--- Returns the editor text for the EditorTextObject.
---
--- This function retrieves the editor text for the EditorTextObject, which is stored in the `editor_text_member` field.
---
--- @return string The editor text for the EditorTextObject.
function EditorTextObject:EditorGetText()
	return self[self.editor_text_member]
end

---
--- Returns the editor text color for the EditorTextObject.
---
--- This function retrieves the editor text color for the EditorTextObject, which is stored in the `editor_text_color` field.
---
--- @return RGBA The editor text color for the EditorTextObject.
function EditorTextObject:EditorGetTextColor()
	return self.editor_text_color
end

---
--- Returns the editor text style for the EditorTextObject.
---
--- This function retrieves the editor text style for the EditorTextObject, which is stored in the `editor_text_style` field.
---
--- @return table The editor text style for the EditorTextObject.
function EditorTextObject:EditorGetTextStyle()
	return self.editor_text_style
end

---
--- Creates a clone of the EditorTextObject, updating the editor text object if the clone is also an EditorTextObject.
---
--- @param class string|nil The class to use for the clone. If not provided, the same class as the original object is used.
--- @param ... any Additional arguments to pass to the clone constructor.
--- @return EditorTextObject The cloned EditorTextObject.
function EditorTextObject:Clone(class, ...)
	local clone = EditorObject.Clone(self, class or self.class, ...)
	if IsKindOf(clone, "EditorTextObject") then
		clone:EditorTextUpdate(true)
	end
	return clone
end

---
--- Updates the editor text object for the EditorTextObject.
---
--- This function is responsible for creating, updating, and managing the editor text object associated with the EditorTextObject. It checks if the editor text object is valid, and if not, creates a new one. It then sets the text, color, and style of the editor text object based on the properties of the EditorTextObject.
---
--- @param create boolean Whether to create a new editor text object if it doesn't exist.
function EditorTextObject:EditorTextUpdate(create)
	if not IsValid(self) then
		return
	end
	local obj = self.editor_text_obj
	if not IsValid(obj) and not create then return end
	local is_hidden = GetDeveloperOption("Hidden", "EditorHiddenTextOptions", self.class)
	local text = not is_hidden and self:EditorGetText()
	if not text then
		DoneObject(obj)
		return
	end
	if not IsValid(obj) then
		obj = PlaceObject(self.editor_text_class, {text_style = self:EditorGetTextStyle()})
		obj:SetDepthTest(self.editor_text_depth_test)
		local spot = self.editor_text_spot
		if spot and self:HasSpot(spot) then
			self:Attach(obj, self:GetSpotBeginIndex(spot))
		else
			self:Attach(obj)
		end
		local offset = self.editor_text_offset
		if offset then
			obj:SetAttachOffset(offset)
		end
		self.editor_text_obj = obj
	end
	obj:SetText(text)
	local color = self:EditorGetTextColor()
	if color then
		obj[self.editor_text_ctarget](obj, color)
	end
end

---
--- Handles updating the editor text object when a property is set on the `EditorTextObject`.
---
--- If the `editor_text_member` property is set, this function will call `EditorTextUpdate` to update the text object.
--- It then calls the base class's `OnEditorSetProperty` function to handle any other property changes.
---
--- @param prop_id string The ID of the property that was set.
--- @return boolean The result of calling the base class's `OnEditorSetProperty` function.
---
function EditorTextObject:OnEditorSetProperty(prop_id)
	if prop_id == self.editor_text_member then
		self:EditorTextUpdate(true)
	end
	return EditorObject.OnEditorSetProperty(self, prop_id)
end

DefineClass.NoteMarker = {
	__parents = { "Object", "EditorVisibleObject", "EditorTextObject" },
	properties = {
		{ id = "MantisID", editor = "number", default = 0, important = true , buttons = {{name = "OpenMantis", func = "OpenMantisFromMarker"}}},
		{ id = "Text", editor = "text", lines = 5, default = "", important = true },
		{ id = "TextColor", editor = "color", default = RGB(255,255,255), important = true },
		{ id = "TextStyle", editor = "text", default = "InfoText", important = true },
		-- disabled properties
		{ id = "Angle", editor = false},
		{ id = "Axis", editor = false},
		{ id = "Opacity", editor = false},
		{ id = "StateCategory", editor = false},
		{ id = "StateText", editor = false},
		{ id = "Groups", editor = false},
		{ id = "Mirrored", editor = false},
		{ id = "ColorModifier", editor = false},
		{ id = "Occludes", editor = false},
		{ id = "Walkable", editor = false},
		{ id = "ApplyToGrids", editor = false},
		{ id = "Collision", editor = false},
		{ id = "OnCollisionWithCamera", editor = false},
		{ id = "CollectionIndex", editor = false},
		{ id = "CollectionName", editor = false},
	},
	editor_text_offset = point(0,0,4*guim),
	editor_text_member = "Text",
}

for i = 1, const.MaxColorizationMaterials do
	table.iappend( NoteMarker.properties, { 
		{ id = string.format("Color%d", i), editor = false },
		{ id = string.format("Roughness%d", i), editor = false },
		{ id = string.format("Metallic%d", i), editor = false },
	})
end

---
--- Returns the text color of the NoteMarker object.
---
--- @return table The text color of the NoteMarker object.
---
function NoteMarker:EditorGetTextColor()
	return self.TextColor
end

---
--- Returns the text style of the NoteMarker object.
---
--- @return string The text style of the NoteMarker object.
---
function NoteMarker:EditorGetTextStyle()
	return self.TextStyle
end

---
--- Opens a Mantis bug tracker URL for the specified object property.
---
--- @param parentEditor EditorBase The parent editor object.
--- @param object table The object containing the Mantis bug tracker ID.
--- @param prop_id string The property ID containing the Mantis bug tracker ID.
--- @param ... any Additional arguments (unused).
---
function OpenMantisFromMarker(parentEditor, object, prop_id, ...)
	local mantisID = object:GetProperty(prop_id)
	if mantisID and mantisID ~= "" and mantisID ~= 0 then
		local url = "http://mantis.haemimontgames.com/view.php?id="..mantisID
		OpenUrl(url, "force external browser")
	end
end

if not Platform.editor then

	function OnMsg.ClassesPreprocess(classdefs)
		for name, class in pairs(classdefs) do
			class.EditorCallbackPlace = nil
			class.EditorCallbackPlaceCursor = nil
			class.EditorCallbackDelete = nil
			class.EditorCallbackRotate = nil
			class.EditorCallbackMove = nil
			class.EditorCallbackScale = nil
			class.EditorCallbackClone = nil
			class.EditorCallbackGenerate = nil

			class.EditorEnter = nil
			class.EditorExit = nil

			class.EditorGetText = nil
			class.EditorGetTextColor = nil
			class.EditorGetTextStyle = nil
			class.EditorGetTextFont = nil
			
			class.editor_text_obj = nil
			class.editor_text_spot = nil
			class.editor_text_color = nil
			class.editor_text_offset = nil
			class.editor_text_style = nil
		end
	end

	function OnMsg.Autorun()
		MsgClear("EditorCallback")
		MsgClear("GameEnterEditor")
		MsgClear("GameExitEditor")
	end

end

----

local update_thread
--- Updates the editor texts for all EditorTextObject instances.
---
--- This function is called when the "EditorHiddenTextOptions" developer option is changed.
--- It creates a real-time thread that iterates through all EditorTextObject instances and calls their EditorTextUpdate method.
---
--- This ensures that the editor texts are updated to reflect any changes in the hidden text options.
function UpdateEditorTexts()
	if not IsEditorActive() or IsValidThread(update_thread) then
		return
	end
	update_thread = CreateRealTimeThread(function()
		MapForEach("map", "EditorTextObject", function(obj)
			obj:EditorTextUpdate(true)
		end)
	end)
end


function OnMsg.DeveloperOptionsChanged(storage, name, id, value)
	if storage == "EditorHiddenTextOptions" then
		UpdateEditorTexts()
	end
end

----

DefineClass.ForcedTemplate =
{
	__parents = { "EditorObject" },
	template_class = "Template",
}

---
--- Returns the template class for the given class name.
---
--- @param class_name string The name of the class.
--- @return string The template class name, or an empty string if no template class is defined.
function GetTemplateBase(class_name)
	local class = g_Classes[class_name]
	return class and class.template_class or ""
end

MapVar("ForcedTemplateObjs", {})

---
--- Called when the ForcedTemplate object enters the editor.
---
--- If the object is not permanent and is currently visible, it is added to the ForcedTemplateObjs table and its visibility is cleared.
---
--- This ensures that the object is hidden in the editor until it is explicitly made visible again.
---
--- @param self ForcedTemplate The ForcedTemplate object that is entering the editor.
function ForcedTemplate:EditorEnter()
	if self:GetGameFlags(const.gofPermanent) == 0 and self:GetEnumFlags(const.efVisible) ~= 0 then
		ForcedTemplateObjs[self] = true
		self:ClearEnumFlags(const.efVisible)
	end
end

---
--- Called when the ForcedTemplate object is exiting the editor.
---
--- If the object was previously hidden in the editor, its visibility is restored.
---
--- @param self ForcedTemplate The ForcedTemplate object that is exiting the editor.
function ForcedTemplate:EditorExit()
	if ForcedTemplateObjs[self] then
		self:SetEnumFlags(const.efVisible)
	end
end


---- EditorSelectedObject --------------------------------------

MapVar("l_editor_selection", empty_table)

DefineClass.EditorSelectedObject = {
	__parents = { "CObject" },
}

---
--- Sets whether the EditorSelectedObject is selected or not.
---
--- @param self EditorSelectedObject The EditorSelectedObject instance.
--- @param selected boolean Whether the object should be selected or not.
function EditorSelectedObject:EditorSelect(selected)
end

---
--- Checks if the EditorSelectedObject is currently selected in the editor.
---
--- @param self EditorSelectedObject The EditorSelectedObject instance.
--- @param check_helpers boolean If true, also checks if any associated PropertyHelpers are selected.
--- @return boolean True if the object is selected, false otherwise.
---
function EditorSelectedObject:EditorIsSelected(check_helpers)
	if l_editor_selection[self] then
		return true
	end
	if check_helpers then
		local helpers = PropertyHelpers and PropertyHelpers[self] or empty_table
		for prop_id, helper in pairs(helpers) do
			if editor.IsSelected(helper) then
				return true
			end
		end
	end
	return false
end

---
--- Updates the editor's selected objects.
---
--- This function is called when the editor selection changes, either when the user selects or deselects objects in the editor.
---
--- It maintains a table of the currently selected EditorSelectedObject instances, and updates their selection state accordingly.
---
--- @param selection table|nil A table of the currently selected objects in the editor. If nil, the selection is cleared.
---
function UpdateEditorSelectedObjects(selection)
	local new_selection = setmetatable({}, weak_keys_meta)
	local old_selection = l_editor_selection
	l_editor_selection = new_selection
	for i=1,#(selection or "") do
		local obj = selection[i]
		if IsKindOf(obj, "EditorSelectedObject") then
			new_selection[obj] = true
			if not old_selection[obj] then
				obj:EditorSelect(true)
			end
		end
	end
	for obj in pairs(old_selection or empty_table) do
		if not new_selection[obj] then
			obj:EditorSelect(false)
		end
	end
end

function OnMsg.EditorSelectionChanged(selection)
	UpdateEditorSelectedObjects(selection)
end

function OnMsg.GameEnterEditor()
	UpdateEditorSelectedObjects(editor.GetSel())
end

function OnMsg.GameExitEditor()
	UpdateEditorSelectedObjects()
end


---- EditorSubVariantObject --------------------------------------

DefineClass.EditorSubVariantObject = {
	__parents = { "PropertyObject" },
	properties = {
		{ name = "Subvariant", id = "subvariant", editor = "number", default = -1,
			buttons = { 
				{ name = "Next", func = "CycleEntityBtn" },
			},
		},
	},
}

--- Cycles through the available entity variants for this EditorSubVariantObject.
---
--- This function is called when the "Next" button is clicked in the editor for this object.
--- It cycles through the available entity variants, updating the Subvariant property and
--- changing the entity to the next variant.
---
--- @return boolean true if the entity variant was changed, false otherwise
function EditorSubVariantObject:CycleEntityBtn()
	self:CycleEntity()
end

--- Sets the subvariant property of the EditorSubVariantObject.
---
--- @param val number The new value for the subvariant property.
function EditorSubVariantObject:Setsubvariant(val)
	self.subvariant = val
end

--- Sets the subvariant property of the EditorSubVariantObject to the previous available entity variant.
---
--- This function is called to cycle to the previous available entity variant for this EditorSubVariantObject.
--- It decrements the Subvariant property and changes the entity to the previous variant.
---
--- @return boolean true if the entity variant was changed, false otherwise
function EditorSubVariantObject:PreviousEntity()
	self:CycleEntity(-1)
end

--- Sets the subvariant property of the EditorSubVariantObject to the previous available entity variant.
---
--- This function is called to cycle to the previous available entity variant for this EditorSubVariantObject.
--- It decrements the Subvariant property and changes the entity to the previous variant.
---
--- @return boolean true if the entity variant was changed, false otherwise
function EditorSubVariantObject:NextEntity()
	self:CycleEntity(-1)
end

local maxEnt = 20
--- Cycles through the available entity variants for this EditorSubVariantObject.
---
--- This function is called when the "Next" button is clicked in the editor for this object.
--- It cycles through the available entity variants, updating the Subvariant property and
--- changing the entity to the next variant.
---
--- @param delta number (optional) The direction to cycle the variants. Positive values cycle forward, negative values cycle backward.
--- @return boolean true if the entity variant was changed, false otherwise
function EditorSubVariantObject:CycleEntity(delta)
	delta = delta or 1
	local curE = self:GetEntity()
	local nxt = self.subvariant == -1 and (tonumber(string.match(curE, "%d+$")) or 1) or self.subvariant
	nxt = nxt + delta
	
	local nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
	if not IsValidEntity(nxtE) then
		if delta > 0 then
			--going up, reset to first
			nxt = 1
			nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
		else
			--going down, reset to last, whichever that is..
			nxt = maxEnt + 1
			while not IsValidEntity(nxtE) and nxt > 0 do
				nxt = nxt - 1
				nxtE = string.gsub(curE, "%d+$", (nxt < 10 and "0" or "") .. tostring(nxt))
			end
		end
		
		if not IsValidEntity(nxtE) then
			nxtE = curE
			nxt = -1
		end
	end
	
	if self.subvariant ~= nxt then
		self.subvariant = nxt
		self:ChangeEntity(nxtE)
		ObjModified(self)
		return true
	end
	return false
end

--- Resets the subvariant of the EditorSubVariantObject to -1.
---
--- This function is used to reset the subvariant of the object to its default state.
---
--- @function EditorSubVariantObject:ResetSubvariant
--- @return nil
function EditorSubVariantObject:ResetSubvariant()
	self.subvariant = -1
end

--- Cycles the subvariant of the selected EditorSubVariantObject instances.
---
--- This function is called when a shortcut is triggered to cycle the subvariant of the selected objects.
--- It iterates through the selected objects, and if the object is an EditorSubVariantObject, it calls the CycleEntity
--- method on that object, passing the delta value to indicate the direction to cycle the variants.
---
--- @param delta number The direction to cycle the variants. Positive values cycle forward, negative values cycle backward.
--- @return nil
function EditorSubVariantObject.OnShortcut(delta)
	local sel = editor.GetSel()
	if sel and #sel > 0 then
		XEditorUndo:BeginOp{ objects = sel }
		for i = 1, #sel do
			if IsKindOf(sel[i], "EditorSubVariantObject") then
				sel[i]:CycleEntity(delta)
			end
		end
		XEditorUndo:EndOp(sel)
	end
end

--- Cycles the subvariant of the selected EditorSubVariantObject instances.
---
--- This function is called when a shortcut is triggered to cycle the subvariant of the selected objects.
--- It iterates through the selected objects, and if the object is an EditorSubVariantObject, it calls the CycleEntity
--- method on that object, passing the delta value to indicate the direction to cycle the variants.
---
--- @param delta number The direction to cycle the variants. Positive values cycle forward, negative values cycle backward.
--- @return nil
function CycleObjSubvariant(obj, dir)
	if IsKindOf(obj, "EditorSubVariantObject") then
		obj:CycleEntity(dir)
	else
		local class = obj.class
		local num = tonumber(class:sub(-2, -1))
		if num then
			local list = {}
			for i = 0, 99 do
				local class_name = class:sub(1, -3) .. (i <= 9 and "0" or "") .. tostring(i)
				if g_Classes[class_name] and IsValidEntity(g_Classes[class_name]:GetEntity()) then
					list[#list + 1] = class_name
				end
			end
			
			local idx = table.find(list, class) + dir
			if idx == 0 then idx = #list elseif idx > #list then idx = 1 end
			obj = editor.ReplaceObject(obj, list[idx])
		end
	end
	
	return obj
end