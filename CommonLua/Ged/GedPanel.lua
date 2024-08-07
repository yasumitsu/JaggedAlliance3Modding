local  warn_mark = Untranslated("<color 255 140 0>!</color>")
local   err_mark = Untranslated("<color 240 0 0>!!</color>")
local dirty_mark = Untranslated("<color 240 0 0>*</color>")
local match_mark_text = "<color 0 196 0>•</color>"
local match_mark = Untranslated(match_mark_text)

local function get_warning_msg(obj_addr)
	return (Platform.ged and g_GedApp.connection:Obj("root|warnings_cache") or rawget(_G, "DiagnosticMessagesForGed") or empty_table)[obj_addr]
end

---
--- Generates a string of visual marks to be displayed alongside a GED object.
--- The marks indicate the following:
--- - Warning or error message for the object (indicated by '!' or '!!')
--- - Whether the object is marked as 'dirty' in the GED (indicated by '*')
--- - Whether the object matches the current search value in any GED panel (indicated by '•')
---
--- @param context_obj table The context object for the GED panel
--- @param obj_addr string The address of the GED object
--- @return string The string of visual marks
---
function TFormat.ged_marks(context_obj, obj_addr)
	local marks = ""
	
	-- Ged warning/error ! mark
	local msg = get_warning_msg(obj_addr)
	if msg then
		marks = marks .. (msg[#msg] == "warning" and warn_mark or err_mark)
	end
	
	-- Ged dirty * mark
	local dirty = Platform.ged and g_GedApp.connection:Obj("root|dirty_objects") or empty_table
	if dirty[obj_addr] then
		marks = marks .. dirty_mark
	end
	
	-- Mark for a match from "search values"
	for _, panel in pairs(Platform.ged and g_GedApp.interactive_panels) do
		local results = panel.search_value_results
		if results and type(results[obj_addr]) == "table" then
			marks = marks .. match_mark
			break
		end
	end
	return marks
end

local read_only_color = Untranslated("<color 150 150 150>")
local read_only_color_close = Untranslated("</color>")

-- <read_only(panel.context)>
-- The read_only tag is used to gray out all items in a ged panel whose context is read-only.
-- Currently this is useful to gray out a Container's sub-items (like Preset sub-items).
-- If you want to gray out only specific items that read-only in a panel whose context is NOT read-only 
-- use the Format property with a construct like <if(IsReadOnly)>...</if>
---
--- Generates a string of read-only color markup to be applied to a GED object.
---
--- @param context_obj table The context object for the GED panel
--- @param context_name string The name of the context object
--- @return string The read-only color markup
---
function TFormat.read_only(context_obj, context_name)
	local result = ""

	local read_only = (Platform.ged and context_name) and g_GedApp.connection:Obj(context_name .. "|read_only")
	if read_only then
		result = result .. read_only_color
	end
	
	return result
end

-- </read_only(panel.context)>
-- Closes a read_only tag.
TFormat["/read_only"] = function(context_obj, context_name)
	local result = ""
	
	local read_only = (Platform.ged and context_name) and g_GedApp.connection:Obj(context_name .. "|read_only")
	if read_only then
		result = result .. read_only_color_close
	end
	
	return result
end


----- GedPanelBase, used by all panels and GedPropNestedList

local reCommaList = "([%w_]+)%s*,%s*"

DefineClass.GedPanelBase = {
	__parents = { "XControl", "XContextWindow" },
	properties = {
		{ category = "Interaction", id = "Collapsible", editor = "bool", default = false, help = "Allows the panel to be collapsed and expanded." },
		{ category = "Interaction", id = "StartsExpanded", editor = "bool", default = false, help = "Controls if the panel is initially collapsed or expanded." },
		{ category = "Interaction", id = "ExpandedMessage", editor = "text", default = "", help = "Dimmed help message to display right-aligned in the panel's title when it is expanded." },
		{ category = "Interaction", id = "EmptyMessage", editor = "text", default = "", help = "Dimmed help message to display right-aligned in the panel's title when it is empty." },
	},
	Embedded = false,
	Interactive = false, -- interactive panels have selection and store/restore state (see GedApp)
	MatchMark = match_mark_text,
	focus_column = 1,
	connection = false,
	app = false,
}

---
--- Initializes a GedPanelBase instance.
---
--- @param parent table The parent control of the GedPanelBase instance.
--- @param context string The bind name of the object displayed in the panel.
---
function GedPanelBase:Init(parent, context)
	assert(not context or type(context) == "string") -- context is the bind name of the object displayed
	self.app = GetParentOfKind(self.parent, "GedApp")
	self.connection = self.app and self.app.connection
	self.app:AddPanel(self.context, self)
end

---
--- Called when the GedPanelBase instance is done and should be cleaned up.
---
--- If the application window is not in the "destroying" state, this function will:
--- - Unbind any views associated with the GedPanelBase instance
--- - Remove the GedPanelBase instance from the application's panel list
---
--- @param self GedPanelBase The GedPanelBase instance being cleaned up.
function GedPanelBase:Done()
	if self.app.window_state ~= "destroying" then
		self:UnbindViews()
		self.app:RemovePanel(self)
	end
end

---
--- Sets the focus on the GedPanelBase instance.
---
--- This function is used to set the focus on the GedPanelBase instance, which is typically used when the panel is selected or activated.
---
--- @param self GedPanelBase The GedPanelBase instance to set the focus on.
---
function GedPanelBase:SetPanelFocused()
end

---
--- Gets the selection of the GedPanelBase instance.
---
--- @return boolean false The GedPanelBase instance does not support selection.
---
function GedPanelBase:GetSelection()
	return false
end

---
--- Gets the multi-selection of the GedPanelBase instance.
---
--- This function returns false, indicating that the GedPanelBase instance does not support multi-selection.
---
--- @return boolean false The GedPanelBase instance does not support multi-selection.
---
function GedPanelBase:GetMultiSelection()
	return false
end

---
--- Sets the selection of the GedPanelBase instance.
---
--- This function is used to set the selection of the GedPanelBase instance. However, the GedPanelBase instance does not support selection, so this function does nothing.
---
--- @param self GedPanelBase The GedPanelBase instance to set the selection on.
--- @param ... any Any additional arguments passed to the function.
---
function GedPanelBase:SetSelection(...)
end

---
--- Handles the selection event for the GedPanelBase instance.
---
--- This function is called when the selection of the GedPanelBase instance changes. However, the GedPanelBase instance does not support selection, so this function does nothing.
---
--- @param self GedPanelBase The GedPanelBase instance that the selection event occurred for.
--- @param selection any The new selection of the GedPanelBase instance.
---
function GedPanelBase:OnSelection(selection)
end

---
--- This function is used to indicate that the GedPanelBase instance does not support search functionality.
---
function GedPanelBase:TryHighlightSearchMatch()
	-- no search support in GetPanelBase
end

---
--- Cancels the search functionality of the GedPanelBase instance.
---
--- This function is used to cancel any ongoing search operations in the GedPanelBase instance. However, since the GedPanelBase instance does not support search functionality, this function does nothing.
---
--- @param self GedPanelBase The GedPanelBase instance to cancel the search for.
--- @param dont_select boolean (optional) A flag indicating whether to avoid selecting any items after canceling the search.
---
function GedPanelBase:CancelSearch(dont_select)
	-- no search support in GetPanelBase
end

---
--- Returns the current state of the GedPanelBase instance, including the selection.
---
--- @return table The current state of the GedPanelBase instance, with the selection stored in a table.
---
function GedPanelBase:GetState()
	return { selection = table.pack(self:GetSelection()) }
end

---
--- Returns the bound object with the given name.
---
--- @param self GedPanelBase The GedPanelBase instance.
--- @param name string The name of the bound object to retrieve.
--- @return any The bound object with the given name, or nil if not found.
---
function GedPanelBase:Obj(name)
	return self.connection.bound_objects[name]
end

---
--- Binds a view to the GedPanelBase instance.
---
--- This function is used to bind a view to the GedPanelBase instance. The view is identified by a suffix, and the function name and any additional arguments are used to bind the view to the GedPanelBase instance.
---
--- @param self GedPanelBase The GedPanelBase instance to bind the view to.
--- @param suffix string The suffix to identify the view.
--- @param func_name string The name of the function to bind the view to.
--- @param ... any Additional arguments to pass to the function.
---
function GedPanelBase:BindView(suffix, func_name, ...)
	local name = self.context
	self.connection:BindObj(name .. "|" .. suffix, name, func_name, ...)
end

---
--- Unbinds a view from the GedPanelBase instance.
---
--- This function is used to unbind a view from the GedPanelBase instance. The view is identified by a suffix, and the function will unbind the view from the GedPanelBase instance.
---
--- @param self GedPanelBase The GedPanelBase instance to unbind the view from.
--- @param suffix string The suffix to identify the view to unbind.
---
function GedPanelBase:UnbindView(suffix)
	local name = self.context
	self.connection:UnbindObj(name .. "|" .. suffix)
end

---
--- Binds all views associated with the GedPanelBase instance.
---
--- This function is used to bind all views associated with the GedPanelBase instance. It retrieves the context name and binds all views with that context name to the GedPanelBase instance.
---
--- @param self GedPanelBase The GedPanelBase instance to bind the views to.
---
function GedPanelBase:BindViews()
end

---
--- Unbinds all views associated with the GedPanelBase instance.
---
--- This function is used to unbind all views associated with the GedPanelBase instance. It retrieves the context name and unbinds all views with that context name from the GedPanelBase instance.
---
--- @param self GedPanelBase The GedPanelBase instance to unbind the views from.
---
function GedPanelBase:UnbindViews()
	local name = self.context
	if name then
		self.connection:UnbindObj(name)
		self.connection:UnbindObj(name .. "|", "") -- unbind all views
		self:SetContext(false)
	end
end

---
--- Updates the context and binds/unbinds views for the GedPanelBase instance.
---
--- This function is called when the context of the GedPanelBase instance is updated. It sets the panel visible, binds or unbinds views based on whether a view is provided, and checks for updates to item texts.
---
--- @param self GedPanelBase The GedPanelBase instance.
--- @param context any The updated context.
--- @param view any The updated view, or nil if no view is provided.
---
function GedPanelBase:OnContextUpdate(context, view)
	self:SetVisible(true)
	if view == nil then
		self:BindViews()
	end
	self.app:CheckUpdateItemTexts(view)
end

---
--- Called when the GedPanelBase instance receives focus.
---
--- This function is called when the GedPanelBase instance receives focus. It sets the last focused panel in the application to the current GedPanelBase instance, and then binds the selected object to the panel.
---
--- @param self GedPanelBase The GedPanelBase instance that received focus.
---
function GedPanelBase:OnSetFocus()
	if self.app:SetLastFocusedPanel(self) then
		self:BindSelectedObject(self:GetSelection())
	end
end

---
--- Binds the selected object to the GedPanelBase instance.
---
--- This function is called when the selected object in the application is updated. It binds the selected object to the GedPanelBase instance, allowing the panel to display and interact with the selected object.
---
--- @param self GedPanelBase The GedPanelBase instance.
--- @param selected_item any The selected object to bind to the panel.
---
function GedPanelBase:BindSelectedObject(selected_item)
end

---
--- Executes the specified operation on the GedPanelBase instance.
---
--- This function is used to execute various operations on the GedPanelBase instance, such as moving, deleting, copying, or pasting objects. The specific operation to be executed is specified by the `op_name` parameter, and any additional parameters required by the operation are passed in as additional arguments.
---
--- @param self GedPanelBase The GedPanelBase instance.
--- @param op_name string The name of the operation to execute.
--- @param obj any The object to perform the operation on.
--- @param ... any Additional parameters required by the operation.
---
function GedPanelBase:Op(op_name, obj, ...)
	self.app:Op(op_name, obj, ...)
end

---
--- Sends a remote function call to the application.
---
--- This function is used to send a remote function call to the application. The `rfunc_name` parameter specifies the name of the remote function to call, and any additional parameters required by the function are passed in as additional arguments.
---
--- @param self GedPanelBase The GedPanelBase instance.
--- @param rfunc_name string The name of the remote function to call.
--- @param ... any Additional parameters required by the remote function.
---
function GedPanelBase:Send(rfunc_name, ...)
	self.app:Send(rfunc_name, ...)
end

---
--- Updates the text of all items in the GedPanelBase instance.
---
--- This function is used to refresh all the text elements in the GedPanelBase instance, ensuring that their warning statuses are updated. This is necessary to reflect any changes to the diagnostic messages associated with the items.
---
function GedPanelBase:UpdateItemTexts()
	-- used to refresh all texts so that their warning statuses get updated (see TFormat.diagnmsg)
end

local function get_warning_nodes(self)
	-- see Preset's Warning property
	local warning_data = self:Obj(self.context .. "|warning")
	if type(warning_data) == "table" then
		local warning_idxs = {}
		for i = 3, #warning_data do
			table.insert(warning_idxs, warning_data[i])
		end
		return warning_idxs
	end
	return empty_table
end


----- Ops for common actions per panel type and class

local common_action_ops = {
	GedListPanel = {
		None = {},
		PropertyObject = {
			MoveUp    = "GedOpListMoveUp",
			MoveDown  = "GedOpListMoveDown",
			Delete    = "GedOpListDeleteItem",
			Cut       = "GedOpListCut",
			Copy      = "GedOpListCopy",
			Paste     = "GedOpListPaste",
			Duplicate = "GedOpListDuplicate",
		},
		Object = {
			Delete    = "GedOpListDeleteItem",
			Cut       = "GedOpObjectCut",
			Copy      = "GedOpObjectCopy",
			Paste     = "GedOpObjectPaste",
			Duplicate = "GedOpObjectDuplicate",
		},
	},
	GedTreePanel = {
		None = {},
		PropertyObject = {
			MoveUp    = "GedOpTreeMoveItemUp",
			MoveDown  = "GedOpTreeMoveItemDown",
			MoveOut   = "GedOpTreeMoveItemOutwards",
			MoveIn    = "GedOpTreeMoveItemInwards",
			Delete    = "GedOpTreeDeleteItem",
			Cut       = "GedOpTreeCut",
			Copy      = "GedOpTreeCopy",
			Paste     = "GedOpTreePaste",
			Duplicate = "GedOpTreeDuplicate",
		},
		Preset = {
			Delete    = "GedOpPresetDelete",
			Cut       = "GedOpPresetCut",
			Copy      = "GedOpPresetCopy",
			Paste     = "GedOpPresetPaste",
			Duplicate = "GedOpPresetDuplicate",
		},
	},
	GedPropPanel = {
		None = {},
		PropertyObject = {
			Copy      = "GedOpPropertyCopy",
			Paste     = "GedOpPropertyPaste",
		},
	},
}


----- GedPanel

local function op_readonly(self, prop_meta) return self:GetProperty(prop_meta.id) == GedDisabledOp end
local function op_noedit(self, prop_meta) return not common_action_ops[rawget(self, "__class") or self.class] end
local op_edit_button = {{
	name = "Edit", func = "OpEdit",
	is_hidden = function(obj, prop_meta) return obj:GetProperty(prop_meta.id) ~= GedDisabledOp end
}}

DefineClass.GedPanel = {
	__parents = { "GedPanelBase" },
	properties = {
		{ category = "General", id = "Title", editor = "text", default = "<class>", },
		{ category = "General", id = "TitleFormatFunc", editor = "text", default = "GedFormatObject", },
		{ category = "General", id = "EnableSearch", editor = "bool", default = false, },
		{ category = "General", id = "SearchHistory", editor = "number", default = 0 },
		{ category = "General", id = "SearchValuesAvailable", editor = "bool", default = false },
		{ category = "General", id = "PersistentSearch", editor = "bool", default = false },
		{ category = "General", id = "Predicate", editor = "text", default = "", help = "This object member function controls whether the panel is visible" },
		{ category = "General", id = "DisplayWarnings", editor = "bool", default = true, },
		
		{ category = "Common Actions", id = "ActionsClass", editor = "choice", default = "None", no_edit = op_noedit,
		  items = function(self) return table.keys2(common_action_ops[rawget(self, "__class") or self.class] or { None = true }, "sorted") end },
		{ category = "Common Actions", id = "MoveUp",    editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "MoveDown",  editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "MoveOut",   editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "MoveIn",    editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "Delete",    editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "Cut",       editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "Copy",      editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "Paste",     editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		{ category = "Common Actions", id = "Duplicate", editor = "text", default = GedDisabledOp, read_only = op_readonly, no_edit = op_noedit, buttons = op_edit_button },
		
		{ category = "Context Menu", id = "ActionContext", editor = "text", default = "" },
		{ category = "Context Menu", id = "SearchActionContexts", editor = "string_list", default = false,},
	},
	IdNode = true,
	HAlign = "stretch",
	VAlign = "stretch",
	Padding = box(2, 2, 2, 2),
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	MinWidth = 300,
	MaxWidth = 100000,
	
	ContainerControlClass = "XScrollArea",
	HorizontalScroll = false,
	Translate = false,
	documentation_btn = false,
	test_btn = false,
	expanded = true, -- panels with Collapsible == true can be expanded/collapsed
	search_popup = false,
	search_values = false,
	search_value_results = false,
	read_only = false,
}

---
--- Handles changes to the `__class` or `ActionsClass` properties of the `GedPanel` class.
---
--- When the `__class` property changes, this function resets the `ActionsClass` property to the default value for the new class.
--- It then updates the values of the common action properties (`MoveUp`, `MoveDown`, etc.) based on the new `ActionsClass` value.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Graphical Editor) object associated with the panel.
---
function GedPanel:OnXTemplateSetProperty(prop_id, old_value, ged)
	if prop_id == "__class" or prop_id == "ActionsClass" then
		local data = common_action_ops[self.__class]
		if prop_id == "__class" then -- reset to default ops for that panel class
			self.ActionsClass = data and "PropertyObject" or "None"
		end
		
		local ops = data and data[self.ActionsClass] or empty_table
		for _, op in ipairs(GedCommonOps) do
			self:SetProperty(op.Id, ops[op.Id] or GedDisabledOp)
		end
	end
end

---
--- Edits the value of the specified property on the GedPanel object.
---
--- @param root any The root object of the GED (Graphical Editor) hierarchy.
--- @param prop_id string The ID of the property to edit.
--- @param ged table The GED (Graphical Editor) object associated with the panel.
--- @param param any Additional parameters for the edit operation.
---
function GedPanel:OpEdit(root, prop_id, ged, param)
	self:SetProperty(prop_id, "")
	ObjModified(self)
end

---
--- Toggles the search functionality of the GedPanel.
---
--- If the search container is currently visible, this function will close the search.
--- If the search container is not visible, this function will open the search.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:ToggleSearch()
	if self.idSearchContainer:GetVisible() then
		self:CloseSearch()
	else
		self:OpenSearch()
	end
end

---
--- Saves the toggled state of the search functionality for the GedPanel.
---
--- This function stores the current state of the search functionality (open or closed) in the application settings.
---
--- @param value boolean The new toggled state of the search functionality.
--- @return boolean The current toggled state of the search functionality.
---
function GedPanel:SaveSearchToggled(value)
	local settings = self.app.settings or {}
	local opened_panels = settings.opened_panels or {}
	if value ~= nil then
		opened_panels[self.Id] = value
	end
	settings.opened_panels = opened_panels
	self.app.settings = settings
	return opened_panels[self.Id]
end

---
--- Opens the search functionality of the GedPanel.
---
--- If the search container is not currently visible, this function will open the search.
--- If the search container is already visible, this function will focus the search input and select all text.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:OpenSearch()
	if not self:IsSearchAvailable() then return end
	
	local search = self.idSearchContainer
	if not search.visible then
		search:SetDock("top")
		search:SetVisible(true)
	end
	self.idSearchEdit:SetFocus()
	self.idSearchEdit:SelectAll()
	self:SaveSearchToggled(true)
end

---
--- Closes the search functionality of the GedPanel.
---
--- If the search container is currently visible, this function will hide the search container and update the filter based on the current search text. It will also save the toggled state of the search functionality to the application settings.
---
--- @param self GedPanel The GedPanel instance.
--- @return boolean True if the search was successfully closed, false otherwise.
---
function GedPanel:CloseSearch()
	local search = self.idSearchContainer
	if not search.visible then return end
	search:SetDock("ignore")
	search:SetVisible(false)
	if self.idSearchEdit:GetText() ~= "" then
		self:UpdateFilter()
	end
	self:SaveSearchToggled(false)
	return true
end

---
--- Cancels the search functionality of the GedPanel.
---
--- If the search container is currently visible, this function will handle the cancellation of the search. If the PersistentSearch flag is set, it will clear the search text, clear any search highlights in child panels, and update the filter. If the PersistentSearch flag is not set, it will simply close the search. If the search container is not visible, this function will return false.
---
--- @param self GedPanel The GedPanel instance.
--- @param dont_select boolean (optional) If true, the function will not focus the first entry after canceling the search.
--- @return boolean True if the search was successfully canceled, false otherwise.
---
function GedPanel:CancelSearch(dont_select)
	if not self.idSearchContainer:GetVisible() then
		return false
	end
	if self.PersistentSearch then
		if self.idSearchEdit:GetText() ~= "" then
			self.idSearchEdit:SetText("")
			self.app.search_value_filter_text = ""
			self.app:TryHighlightSearchMatchInChildPanels(self) -- clear highlights when search is canceled
			self:UpdateFilter()
		elseif not self.idContainer:IsFocused(true) then
			if not dont_select then
				self:FocusFirstEntry()
			end
		else
			self.idSearchEdit:SetFocus()
			self.idSearchEdit:SelectAll()
		end
		return true
	else
		return self:CloseSearch()
	end
end

---
--- Updates the filter of the GedPanel based on the current search text.
---
--- If the search container is currently visible and the search text is not empty, this function will update the filter of the GedPanel to only show entries that match the search text. It will also save the current search text to the application settings.
---
--- @param self GedPanel The GedPanel instance.
function GedPanel:UpdateFilter()
end

---
--- Focuses the first entry in the GedPanel.
---
--- This function is used to focus the first entry in the GedPanel, typically after canceling a search. If the container is not focused, this function will focus the first entry. If the container is already focused, this function will do nothing.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:FocusFirstEntry()
end

---
--- Returns the current search text, or an empty string if the search container is not visible.
---
--- @param self GedPanel The GedPanel instance.
--- @return string The current search text, or an empty string if the search container is not visible.
---
function GedPanel:GetFilterText()
	local search = self.idSearchContainer
	if not search or not search.visible then
		return ""
	end
	return string.lower(self.idSearchEdit:GetText())
end

---
--- Returns the current search text if a search is active, or an empty string if no search is active.
---
--- @param self GedPanel The GedPanel instance.
--- @return string The current search text, or an empty string if no search is active.
---
function GedPanel:GetHighlightText()
	local app = self.app
	return app.search_value_results and app.search_value_filter_text
end

---
--- Handles keyboard shortcuts for the GedPanel.
---
--- This function is called when a keyboard shortcut is triggered while the GedPanel is active. It handles the following shortcuts:
---
--- - "Escape": Cancels the current search and closes the search container.
--- - "F4": Navigates to the next search result.
--- - "Shift-F4": Navigates to the previous search result.
--- - "F5": Starts a new search thread to update the filter.
---
--- @param self GedPanel The GedPanel instance.
--- @param shortcut string The name of the triggered shortcut.
--- @param source any The source of the shortcut trigger.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, nil otherwise.
---
function GedPanel:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" and self:CancelSearch() then
		return "break"
	end
	
	local app = self.app
	local search_panel = app.search_value_panel
	if app.search_value_results and search_panel then
		if shortcut == "F4" then
			search_panel:NextMatch(1)
			return "break"
		elseif shortcut == "Shift-F4" then
			search_panel:NextMatch(-1)
			return "break"
		elseif shortcut == "F5" then
			search_panel:StartUpdateFilterThread()
			return "break"
		end
	end
end

---
--- Checks if the search functionality is available for the GedPanel.
---
--- @param self GedPanel The GedPanel instance.
--- @return boolean True if the search functionality is available, false otherwise.
---
function GedPanel:IsSearchAvailable()
	return self.EnableSearch and not self.Embedded
end

---
--- Updates the visibility of the search functionality in the GedPanel.
---
--- This function is responsible for enabling or disabling the search functionality based on the `EnableSearch` and `Embedded` properties of the GedPanel. It also updates the visibility and docking of the "Toggle Search" button.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:UpdateSearchVisiblity()
	local enabled = self.EnableSearch and not self.Embedded
	if not enabled then
		self:CloseSearch()
	end
	self.idToggleSearch:SetVisible(enabled)
	self.idToggleSearch:SetDock(enabled and "right" or "ignore")

	self:UpdateSearchContextMenu(self:GetSearchActionContexts()) -- updates "Search" action
end

---
--- Sets the search action contexts for the GedPanel.
---
--- This function is responsible for updating the search action contexts in the GedPanel. It calls the `UpdateSearchContextMenu` function to apply the new search contexts.
---
--- @param self GedPanel The GedPanel instance.
--- @param search_contexts table A table of search action contexts to set.
---
function GedPanel:SetSearchActionContexts(search_contexts)
	if not search_contexts or type(search_contexts) ~= "table" then return end
	
	self:UpdateSearchContextMenu(search_contexts)
end

---
--- Updates the search action contexts for the GedPanel.
---
--- This function is responsible for updating the search action contexts in the GedPanel. It removes any existing search action contexts and adds the new ones if the search functionality is enabled.
---
--- @param self GedPanel The GedPanel instance.
--- @param new_contexts table A table of new search action contexts to set.
---
function GedPanel:UpdateSearchContextMenu(new_contexts)
	-- Attach search to the context menu
	if not new_contexts or type(new_contexts) ~= "table" or #new_contexts == 0 then return end
	
	local host = GetActionsHost(self)
	if not host then return end
	local search_action = host:ActionById("idSearch")
	if not search_action then return end
	local contexts = search_action.ActionContexts
	if not contexts then return end
	
	local old_contexts = self:GetSearchActionContexts()
	if old_contexts and #old_contexts ~= 0 then
		for _, old in ipairs(old_contexts) do 
			table.remove_entry(contexts, old)
		end
	end
	
	local search_enabled = self.EnableSearch and not self.Embedded
	if search_enabled then
		for _, new in ipairs(new_contexts) do 
			table.insert(contexts, new)
		end
	end
	
	self.SearchActionContexts = new_contexts
end

---
--- Adds the given text to the search history for the GedPanel.
---
--- If the text is not empty, it is added to the beginning of the search history list for the GedPanel. If the history list exceeds the `SearchHistory` limit, the oldest entry is removed.
---
--- The search history is stored in the application settings, keyed by the GedPanel's Id.
---
--- @param self GedPanel The GedPanel instance.
--- @param text string The text to add to the search history.
--- @return table The updated search history list.
---
function GedPanel:AddToSearchHistory(text)
	local settings = self.app.settings or {}
	settings.search_history = settings.search_history or {}
	local history_list = settings.search_history[self.Id] or {}
	if text and #text:trim_spaces() > 0 then
		table.remove_value(history_list, text)
		table.insert(history_list, 1, text)
		if #history_list > self.SearchHistory then
			table.remove(history_list, #history_list)
		end
	end
	settings.search_history[self.Id] = history_list
	self.app.settings = settings
	return history_list
end

---
--- Opens the search history popup for the GedPanel.
---
--- This function creates a new popup window that displays the search history for the GedPanel. The history is retrieved from the application settings and displayed as a list of items. When an item is selected, the search edit field is updated with the selected text and the history is updated accordingly.
---
--- If the search history is empty, a "No history." message is displayed in the popup.
---
--- The popup is positioned relative to the search container of the GedPanel and is opened with the "drop" anchor type.
---
--- If the `keyboard` parameter is true and the search history is not empty, the first item in the list is focused.
---
--- @param self GedPanel The GedPanel instance.
--- @param keyboard boolean (optional) Whether the popup was opened via keyboard interaction.
---
function GedPanel:OpenSearchHistory(keyboard)
	local popup = XPopupList:new({
		LayoutMethod = "VList",
	}, self.desktop)
	
	local history = self:AddToSearchHistory(nil)
	if #history > 0 then
		for idx, item in ipairs(history) do
			local entry = XTemplateSpawn("XComboListItem", popup.idContainer, self.context)
			entry:SetFocusOrder(point(1, idx))
			entry:SetFontProps(XCombo)
			entry:SetText(item)
			entry:SetMinHeight(entry:GetFontHeight())
			entry.OnPress = function(entry)
				self.idSearchEdit:SetText(item)
				self:AddToSearchHistory(item)
				if popup.window_state ~= "destroying" then
					popup:Close()
				end
			end
		end
	else
		XText:new({}, popup.idContainer):SetText("No history.")
	end
	popup:SetAnchor(self.idSearchContainer.box)
	popup:SetAnchorType("drop")
	popup:Open()
	if keyboard and #history > 0 then 
		popup.idContainer[1]:SetFocus()
	end
	self.search_popup = popup
	self.app:UpdateChildrenDarkMode(popup)
end

---
--- Initializes the controls for the GedPanel.
---
--- This function sets up the various UI elements and event handlers for the GedPanel. It creates the title container, search container, search edit field, and other related controls. The function also handles the visibility and behavior of these controls based on the panel's configuration.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:InitControls()
	self.expanded = self.StartsExpanded
	
	XWindow:new({
		Id = "idTitleContainer",
		Dock = "ignore", -- see OnContextUpdate
		Background = RGB(196, 196, 196),
		HandleMouse = true,
	}, self):SetVisible(false)
	
	local search_container
	if self.SearchValuesAvailable then
		assert(self.PersistentSearch)
		XWindow:new({
			Id = "idSearchContainer",
			Dock = "ignore",
		}, self):SetVisible(false)
		search_container = XWindow:new({
			BorderWidth = 1,
		}, self.idSearchContainer)
		
		self:CreateSearchResultsPanel()
		
		local search_toggle = XTemplateSpawn("GedToolbarToggleButtonSmall", self.idSearchContainer)
		search_toggle:SetId("idSearchValuesButton")
		search_toggle:SetIcon("CommonAssets/UI/Ged/log-dataset.tga")
		search_toggle:SetRolloverText(Untranslated("Toggle search in properties and sub-objects"))
		search_toggle:SetMargins(box(2, 0, 0, 0))
		search_toggle.OnPress = function() return self:ToggleSearchValues() end
	else
		search_container = XWindow:new({
			Id = "idSearchContainer",
			Dock = "ignore",
			BorderWidth = 1,
			Background = RGB(255, 255, 255),
		}, self)
		search_container:SetVisible(false)
	end
	
	local button = XTemplateSpawn("XComboButton", search_container, self.context)
	button:SetId("idSearchHistory")
	button:SetMargins(empty_box)
	button:SetVisible(self.SearchHistory > 0)
	button.OnPress = function(button)
		if not self.search_popup or self.search_popup.window_state ~= "open" then
			self:PopulateSearchValuesCache()
			self:OpenSearchHistory()
		else
			self.search_popup:Close()
		end
	end
	button.FoldWhenHidden = true
	XTextButton:new({
		Id = "idCancelSearch",
		Dock = "right",
		VAlign = "center",
		Text = "x",
		MaxWidth = 20,
		MaxHeight = 16,
		LayoutHSpacing = 0,
		BorderWidth = 0,
		Background = RGBA(0, 0, 0, 0),
		RolloverBackground = RGB(204, 232, 255),
		PressedBackground = RGB(121, 189, 241),
		OnPress = function() self:CancelSearch() end,
		FoldWhenHidden = true,
	}, search_container)
	self.idCancelSearch:SetVisible(false)
	XEdit:new({
		Id = "idSearchEdit",
		Dock = "box",
		Hint = "Search...",
		BorderWidth = 0,
		Background = RGBA(0, 0, 0, 0),
		AllowEscape = false,
		OnTextChanged = function(edit)
			XEdit.OnTextChanged(edit)
			self:StartUpdateFilterThread()
			if edit:GetText() ~= "" then
				self:SetSelection(false)
			end
			self.idCancelSearch:SetVisible(edit:GetText() ~= "")
		end,
		OnShortcut = function(edit, shortcut, source, ...)
			local result = XEdit.OnShortcut(edit, shortcut, source, ...)
			if result == "break" then return result end
			if shortcut == "Down" or shortcut == "Enter" then
				if shortcut == "Down" and self.SearchHistory > 0 and edit:GetText() == "" then
					self:OpenSearchHistory("keyboard")
					return "break"
				else
					self:FocusFirstEntry()
					return shortcut == "Down" and "break" -- allow Enter to open console, e.g. when typing in Inspector's search
				end
			end
		end,
		OnSetFocus = function(edit)
			self:PopulateSearchValuesCache()
			return XEdit.OnSetFocus(edit)
		end,
		OnKillFocus = function(edit, new_focus)
			self:AddToSearchHistory(edit:GetText())
			return XEdit.OnKillFocus(edit, new_focus)
		end,
	}, search_container)
	
	local search_button = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
	search_button:SetId("idToggleSearch")
	search_button:SetIcon("CommonAssets/UI/Ged/view.tga")
	search_button:SetRolloverText("Search (Ctrl-F)")
	search_button:SetBackground(self.idTitleContainer:GetBackground())
	search_button.OnPress = function() self:ToggleSearch() end
	--- End search controls

	XText:new({
		Id = "idTitle",
		Dock = "box",
		ZOrder = 1000,
		Margins = box(2, 1, 2, 1),
		TextStyle = self.Collapsible and "GedDefault" or "GedTitleSmall",
		HandleMouse = self.Collapsible,
		Translate = true,
		OnMouseButtonDown = function(button, pt, button)
			if self.Collapsible and button == "L" and
			   not terminal.IsKeyPressed(const.vkShift) and
			   not terminal.IsKeyPressed(const.vkControl) then
				self:Expand(not self.expanded)
			end
		end,
	}, self.idTitleContainer)
	
	XText:new({
		Id = "idWarningText",
		Dock = "top",
		VAlign = "center",
		TextHAlign = "center",
		BorderWidth = 1,
		BorderColor = RGB(255, 0 , 0),
		Background = RGB(255, 196, 196),
		FoldWhenHidden = true,
	}, self)
	self.idWarningText:SetVisible(false)
	
	if self.HorizontalScroll then
		XSleekScroll:new({
			Id = "idHScroll",
			Target = "idContainer",
			Dock = "bottom",
			Margins = box(0, 2, 7, 0),
			Horizontal = true,
			AutoHide = true,
			FoldWhenHidden = true,
		}, self)
	end
	local vertical_scroll = _G[self.ContainerControlClass]:IsKindOf("XScrollArea")
	if vertical_scroll then
		XSleekScroll:new({
			Id = "idScroll",
			Target = "idContainer",
			Dock = "right",
			Margins = box(2, 0, 0, 0),
			Horizontal = false,
			AutoHide = true,
			FoldWhenHidden = true,
		}, self)
	end
	_G[self.ContainerControlClass]:new({
		Id = "idContainer",
		HAlign = "stretch",
		VAlign = "stretch",
		MinHSize = false,
		LayoutMethod = "VList",
		Padding = box(2, 2, 2, 2),
		BorderWidth = 0,
		HScroll = self.HorizontalScroll and "idHScroll" or "",
		VScroll = vertical_scroll and "idScroll" or "",
		FoldWhenHidden = true,
		RolloverTemplate = "GedPropRollover",
		Translate = self.Translate,
	}, self)
	self.idContainer.OnSetFocus = function() self:OnSetFocus() end -- fix for edge case with one panel docked in another one
	
	self:UpdateSearchVisiblity()
end

--- Returns a unique view ID for the panel's title, based on the TitleFormatFunc and Title properties.
---
--- This ensures that different panels won't have clashing view IDs.
---
--- @return string The unique view ID for the panel's title
function GedPanel:GetTitleView()
	return self.TitleFormatFunc .. "." .. self.Title -- generate unique view id, to make sure different panels won't clash
end

--- Opens the GedPanel and performs various initialization and binding tasks.
---
--- @param ... Additional arguments passed to the XWindow.Open function
function GedPanel:Open(...)
	self:InitControls()

	XWindow.Open(self, ...)
	
	if self.context then
		self:BindViews()
		if self.Title ~= "" then
			self:BindView(self:GetTitleView(), self.TitleFormatFunc, self.Title)
		end
		if self.Predicate ~= "" then
			self:BindView("predicate", "GedExecMemberFunc", self.Predicate)
		end
		self:BindView("read_only", "GedGetReadOnly")
	end
	
	if self.PersistentSearch then
		if self:IsSearchAvailable() and not self.idSearchContainer:GetVisible() and self:SaveSearchToggled(nil) ~= false then
			self:OpenSearch()
		end
	end
end

--- Expands or collapses the GedPanel.
---
--- @param expand boolean Whether to expand or collapse the panel.
function GedPanel:Expand(expand)
	self.expanded = expand
	self.idContainer:SetVisible(expand)
	self.idScroll:SetAutoHide(expand)
	self.idScroll:SetVisible(expand)
	if self.HorizontalScroll then
		self.idHScroll:SetAutoHide(expand)
		self.idHScroll:SetVisible(expand)
	end
	self:UpdateTitle(self.context)
end

---
--- Updates the title of the GedPanel based on the current context.
---
--- If the panel is collapsible, the title will be formatted with a prefix indicating
--- whether the panel is expanded or collapsed, and a corner message indicating the
--- panel's state.
---
--- @param context table The current context object.
function GedPanel:UpdateTitle(context)
	local title = self.Title ~= "" and self.Title ~= "<empty>" and self:Obj(context .. "|" .. self:GetTitleView()) or ""
	if self.Collapsible then
		if title == "" and self.Title ~= "<empty>" then title = "(no description)" end
		
		local match
		local obj_id = self:Obj(context)
		for _, panel in pairs(self.app.interactive_panels) do
			local res = panel.search_value_results
			if res and res[obj_id] then
				title = GedPanelBase.MatchMark .. title
				match = true
				break
			end
		end	
		
		local is_empty = self:IsEmpty()
		local corner_message = self.EmptyMessage
		if not is_empty then
			corner_message = (self.expanded and self.ExpandedMessage or "(click to expand)")
		end
		
		if not match then
			title = (not is_empty and (self.expanded and "- " or "+ ") or "") .. title
			if not self.Embedded then
				title = title .. "<right><color 128 128 128>" .. corner_message
			end
		end
	end
	self.idTitle:SetText(Untranslated(title))
	self.idTitleContainer:SetVisible(title ~= "")
	self.idTitleContainer:SetDock(title ~= "" and "top" or "ignore")
end

---
--- Updates the GedPanel when the context or view changes.
---
--- This function is called when the context or view of the GedPanel changes. It updates the panel's title, predicate, warnings, read-only status, and documentation based on the new context and view.
---
--- @param context table The current context object.
--- @param view string The view that has changed.
function GedPanel:OnContextUpdate(context, view)
	if not view then -- obj changed
		if self.Title ~= "" then
			self:BindView(self:GetTitleView(), self.TitleFormatFunc, self.Title)
		end
		if self.Predicate ~= "" then
			self:BindView("predicate", "GedExecMemberFunc", self.Predicate)
		end
		if self.DisplayWarnings and not self.app.actions_toggled["ToggleDisplayWarnings"] then
			self:BindView("warning", "GedGetWarning")
		end
		if not self.Embedded then
			self:BindView("read_only", "GedGetReadOnly")
		end
		self:BindView("documentationLink", "GedGetDocumentationLink")
		self:BindView("documentation", "GedGetDocumentation")
		
		if self.Collapsible then
			local obj_id = self:Obj(self.context)
			for _, panel in pairs(self.app.interactive_panels) do
				local results = panel.search_value_results
				if results and results[obj_id] then
					self.expanded = true
				end
			end
			self:Expand(self.expanded)
		end
	end
	if view == self:GetTitleView() then
		self:UpdateTitle(context)
	end
	if view == "predicate" then
		local predicate = self:Obj(context .. "|predicate")
		self:SetVisible(predicate)
		self:SetDock(not predicate and "ignore")
	end
	if view == "warning" and self.DisplayWarnings then
		local warning = self:Obj(context .. "|warning")
		self.idWarningText:SetVisible(warning)
		self.idWarningText:SetTextColor(RGB(0, 0, 0))
		self.idWarningText:SetRolloverTextColor(RGB(0, 0, 0))
		if type(warning) == "table" then
			self.idWarningText:SetText(warning[1])
			local color = warning[2]
			if color == "warning" then color = RGB(255, 140, 0) end
			if color == "error" then color = RGB(255, 196, 196) end
			
			if color then
				local r, g, b = GetRGB(color)
				local max = Max(Max(r, g), b)
				self.idWarningText:SetBackground(color)
				self.idWarningText:SetBorderColor(RGB(r == max and r or r / 4, g == max and g or g / 4, b == max and b or b / 4))
			else
				self.idWarningText:SetBackground(RGB(255, 196, 196))
				self.idWarningText:SetBorderColor(RGB(255, 0 , 0))
			end
		else
			self.idWarningText:SetText(warning)
			self.idWarningText:SetBackground(RGB(255, 196, 196))
			self.idWarningText:SetBorderColor(RGB(255, 0 , 0))
		end
	end
	if (view or ""):starts_with("documentation") then
		local documentation = self:Obj(context .. "|documentation")
		local doc_link = self:Obj(context .. "|documentationLink")
		if (documentation or doc_link or "") ~= "" then
			if not self.documentation_btn then
				self.documentation_btn = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
				self.documentation_btn:SetIcon("CommonAssets/UI/Ged/help.tga")
				self.documentation_btn:SetZOrder(-1)
			end
			self.documentation_btn.OnPress = function(button)
				button:SetFocus()
				if (doc_link or "") ~= "" then
					local link = doc_link:starts_with("http") and doc_link or ("file:///" .. doc_link)
					OpenUrl(link, "force external browser")
				end
				button:SetFocus(false)
			end
			local rollover_text = ""
			if doc_link then
				rollover_text = string.format("Open  %s \n\n", doc_link)
			end
			rollover_text = rollover_text .. (documentation or "")
			self.documentation_btn:SetRolloverText(rollover_text)
			self.documentation_btn:SetVisible(true)
			
			if self.Embedded then
				if not self.test_btn then
					self.test_btn = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
					self.test_btn:SetIcon("CommonAssets/UI/Ged/play.tga")
					self.test_btn:SetZOrder(-1)
					self.test_btn:SetRolloverText("Run now!")
				end
				self.test_btn.OnPress = function(button)
					button:SetFocus()
					self:Send("GedTestFunctionObject", self.context)
					button:SetFocus(false)
				end
			end
		elseif self.documentation_btn then
			self.documentation_btn:SetVisible(false)
		end
	end
	if view == "read_only" then
		self.read_only = self:Obj(self.context .. "|read_only")
		self.app:ActionsUpdated()
	end
	GedPanelBase.OnContextUpdate(self, context, view)
end

---
--- Sets the focus on the panel's container.
---
--- @return boolean True if the focus was successfully set, false otherwise.
function GedPanel:SetPanelFocused()
	return self.idContainer:SetFocus()
end

---
--- Toggles the search values feature for the GedPanel.
---
--- @param no_settings_update boolean (optional) If true, the search values setting will not be updated in the app settings.
---
function GedPanel:ToggleSearchValues(no_settings_update)
	self.search_values = not self.search_values
	local button = self.idSearchValuesButton
	button:SetToggled(not button:GetToggled())
	self.idSearchEdit:SetFocus(false)
	self.idSearchEdit:SetFocus()
	self:StartUpdateFilterThread()
	
	if not no_settings_update then
		local settings = self.app.settings
		settings.search_in_props = settings.search_in_props or {}
		settings.search_in_props[self.context] = self.search_values
		self.app:SaveSettings()
	end
end

---
--- Starts a thread to update the filter for the GedPanel.
---
--- @param not_user_initiated boolean (optional) If true, the search was not initiated by the user.
---
function GedPanel:StartUpdateFilterThread(not_user_initiated)
	if self.search_values and self.idSearchEdit:GetText() ~= "" then
		self.app:SetUiStatus("value_search_in_progress", "Searching...")
	end
	
	self:DeleteThread("UpdateFilterThread")
	self:CreateThread("UpdateFilterThread", function()
		Sleep(75)
		
		if self.search_values then
			local filter = self.idSearchEdit:GetText()
			self.search_value_results = filter ~= "" and self.connection:Call("rfnSearchValues", self.context, self:GetFilterText())
			if self.search_value_results == "timeout" then
				self.search_value_results = false
			end
			
			if self.PersistentSearch and not not_user_initiated then
				self:ShowSearchResultsPanel(self:GetFilterText(), self.search_value_results)
			end
		else
			self.search_value_results = nil
		end
		
		if self.window_state ~= "destroying" then
			self:UpdateFilter()
			for _, panel in pairs(self.app.interactive_panels) do
				if panel ~= self then
					panel:UpdateItemTexts()
				end
			end
			self.app:SetUiStatus("value_search_in_progress", false)
		end
	end)
end

---
--- Populates the search values cache for the GedPanel.
---
--- This function is called to populate the cache of search values for the GedPanel. It does this by calling the "rfnPopulateSearchValuesCache" remote function on the connection, passing the current context.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:PopulateSearchValuesCache()
	if self.search_values then
		CreateRealTimeThread(function() self.connection:Call("rfnPopulateSearchValuesCache", self.context) end)
	end
end

---
--- Creates the search results panel for the GedPanel.
---
--- The search results panel is a docked panel at the bottom of the GedPanel that displays the results of a search. It contains buttons to refresh the search, navigate to the previous and next search results, and displays the current search result index.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:CreateSearchResultsPanel()
	XWindow:new({
		Id = "idSearchResultsPanel",
		Dock = "bottom",
		FoldWhenHidden = true,
		Padding = box(0, 1, 0, 1)
	}, self.idSearchContainer):SetVisible(false)

	local button = XTemplateSpawn("GedToolbarButtonSmall", self.idSearchResultsPanel)
	button:SetIcon("CommonAssets/UI/Ged/undo.tga")
	button:SetRolloverText("Refresh search results (F5)")
	button:SetDock("right")
	button.OnPress = function() self:StartUpdateFilterThread() end

	local button = XTemplateSpawn("GedToolbarButtonSmall", self.idSearchResultsPanel)
	button:SetIcon("CommonAssets/UI/Ged/up.tga")
	button:SetRolloverText("Previous match (Shift-F4)")
	button:SetDock("right")
	button.OnPress = function() self:NextMatch(-1) end
	
	local button = XTemplateSpawn("GedToolbarButtonSmall", self.idSearchResultsPanel)
	button:SetIcon("CommonAssets/UI/Ged/down.tga")
	button:SetRolloverText("Next match (F4)")
	button:SetDock("right")
	button.OnPress = function() self:NextMatch(1) end
	
	XText:new({
		Id = "idSearchResultsText",
		TextStyle = "GedDefault",
	}, self.idSearchResultsPanel)
end

---
--- Shows the search results panel for the GedPanel.
---
--- This function is called to display the search results panel at the bottom of the GedPanel. It sets the search value filter text, the search value results, and the current search value panel. It also sets the search results panel visible if there are search results, and initializes the search result index to 1 and calls the NextMatch function.
---
--- @param self GedPanel The GedPanel instance.
--- @param filter string The search value filter text.
--- @param search_value_results table The search value results.
---
function GedPanel:ShowSearchResultsPanel(filter, search_value_results)
	local app = self.app
	app.search_value_filter_text = filter
	app.search_value_results = search_value_results
	app.search_value_panel = self
	self.idSearchResultsPanel:SetVisible(search_value_results)
	if search_value_results then
		app.search_result_idx = 1
		self:NextMatch(0, "dont_unfocus_search_edit")
	end
end

---
--- Navigates to the next or previous search result in the GedPanel.
---
--- This function is called to move the current search result index to the next or previous match in the search results. It updates the search result index, displays the current match number, and tries to highlight the current search match.
---
--- @param self GedPanel The GedPanel instance.
--- @param direction number The direction to move the search result index (-1 for previous, 1 for next).
--- @param dont_unfocus_search_edit boolean If true, the function will not remove the keyboard focus from the search edit field.
---
function GedPanel:NextMatch(direction, dont_unfocus_search_edit)
	local app = self.app
	local count = #app.search_value_results
	app.search_result_idx = Clamp(app.search_result_idx + direction, 1, count)
	app.display_search_result = true
	self.idSearchResultsText:SetText(string.format("Match %d/%d", app.search_result_idx, count))
	
	local focus = self.desktop:GetKeyboardFocus()
	if not dont_unfocus_search_edit and focus.Id == "idSearchEdit" then
		self.desktop:RemoveKeyboardFocus(focus)
	end
	self:TryHighlightSearchMatch()
end

---
--- Filters an item based on the provided text and filter text.
---
--- This function is used to determine whether an item should be displayed or hidden based on the current search filter. If the filter text is empty, the item is always displayed. If there are search results, the item is hidden if it is in the list of hidden items. Otherwise, the function extracts the text from the item and checks if it contains the filter text.
---
--- @param self GedPanel The GedPanel instance.
--- @param text string The text of the item.
--- @param item_id any The ID of the item.
--- @param filter_text string The current search filter text.
--- @return boolean True if the item should be displayed, false if it should be hidden.
---
function GedPanel:FilterItem(text, item_id, filter_text)
	if filter_text == "" then return end
	if self.search_values then
		return not self.search_value_results or self.search_value_results.hidden[item_id or false]
	else
		text = IsT(text) and TDevModeGetEnglishText(text) or tostring(text):gsub("<[^>]+>", "")
		text = string.lower(text)
		return not text:find(filter_text, 1, true)
	end
end

---
--- Updates the title text of the GedPanel.
---
--- This function is called to update the title text of the GedPanel based on the current context. It calls the UpdateTitle function of the GedPanel to set the title text.
---
--- @param self GedPanel The GedPanel instance.
---
function GedPanel:UpdateItemTexts()
	self:UpdateTitle(self.context)
end

---
--- Checks if the GedPanel is empty.
---
--- This function is a placeholder that should be overridden in child panels to implement the logic for checking if the panel is empty.
---
--- @param self GedPanel The GedPanel instance.
--- @return boolean True if the panel is empty, false otherwise.
---
function GedPanel:IsEmpty()
	-- override in child panels
end


----- GedPropPanel

DefineClass.GedPropPanel = {
	__parents = { "GedPanel" },
	properties = {
		-- internal use
		{ category = "General", id = "CollapseDefault", editor = "bool", default = false, no_edit = true, },
		{ category = "General", id = "ShowInternalNames", editor = "bool", default = false, no_edit = true, },
		{ category = "General", id = "EnableUndo", editor = "bool", default = true, },
		{ category = "General", id = "EnableCollapseDefault", editor = "bool", default = true, },
		{ category = "General", id = "EnableShowInternalNames", editor = "bool", default = true, },
		{ category = "General", id = "EnableCollapseCategories", editor = "bool", default = true, },
		{ category = "General", id = "HideFirstCategory", editor = "bool", default = false, },
		{ category = "General", id = "RootObjectBindName", editor = "text", default = false, },
		{ category = "General", id = "SuppressProps", editor = "prop_table", default = false, help = "Set of properties to skip in format { id1 = true, id2 = true, ... }." },
		
		{ category = "Context Menu" , id = "PropActionContext", editor = "text", default = "" },
	},
	MinWidth = 200,
	Interactive = true,
	EnableSearch = true,
	ShowUnusedPropertyWarnings = false,
	
	update_request = false,
	rebuild_props = true,
	prop_update_in_progress = false,
	parent_obj_id = false,
	parent_changed = false,
	parent_changed_notified = false,
	collapsed_categories = false,
	collapse_default_button = false,
	active_tab = "All",
	
	-- property selection
	selected_properties = false,
	last_selected_container_indx = false, 
	last_selected_property_indx = false, 
}

---
--- Initializes the controls for the GedPropPanel.
---
--- This function sets up the layout and controls for the GedPropPanel, including the container, collapsed categories, selected properties, search action contexts, and various toolbar buttons.
---
--- @param self GedPropPanel The GedPropPanel instance.
---
function GedPropPanel:InitControls()
	GedPanel.InitControls(self)

	self.idContainer:SetPadding(box(0, 3, 0, 0))
	self.idContainer:SetLayoutVSpacing(5)
	self.collapsed_categories = {}
	self.selected_properties = {}
	
	GedPanel.SetSearchActionContexts(self, self.SearchActionContexts) 
	
	local host = GetActionsHost(self)
	if not host:ActionById("EditCode") then
		XAction:new({
			ActionId = "EditCode",
			ActionContexts = { self.PropActionContext } ,
			ActionName = "Edit Code",
			ActionTranslate = false,
			OnAction = function(action, host)
				local panel = host:GetLastFocusedPanel()
				if IsKindOf(panel, "GedPropPanel") then
					self:Send("GedEditFunction", panel.context, panel:GetSelectedProperties())
				end
			end,
			ActionState = function(action, host)
				local panel = host:GetLastFocusedPanel()
				if not IsKindOf(panel, "GedPropPanel") then
					return "hidden"
				end
				local selected = panel.selected_properties
				if not selected or #selected ~= 1 then return "hidden" end
				local prop_meta = selected[1].prop_meta
				if prop_meta.editor ~= "func" and prop_meta.editor ~= "expression" and prop_meta.editor ~= "script" then
					return "hidden"
				end
			end,
		}, self)
	end
	
	local show_collapse_action = self.EnableCollapseDefault and not self.Embedded
	if show_collapse_action and not self.collapse_default_button then
		self.collapse_default_button = XTemplateSpawn("GedToolbarToggleButtonSmall", self.idTitleContainer)
		self.collapse_default_button:SetId("idCollapseDefaultBtn")
		self.collapse_default_button:SetIcon("CommonAssets/UI/Ged/collapse.tga")
		self.collapse_default_button:SetRolloverText(T(912785185075, "Hide/show all properties with default values"))
		self.collapse_default_button:SetBackground(self.idTitleContainer:GetBackground())
		self.collapse_default_button:SetToggled(self.CollapseDefault)
		self.collapse_default_button.OnPress = function(button)
			self:SetFocus()
			self:SetCollapseDefault(not self.CollapseDefault)
			button:SetToggled(not button:GetToggled())
		end
	end
	
	local show_internal_names_action = self.EnableShowInternalNames and not self.Embedded
	if show_internal_names_action then
		local show_internal_names_button = XTemplateSpawn("GedToolbarToggleButtonSmall", self.idTitleContainer)
		show_internal_names_button:SetId("idShowInternalNamesBtn")
		show_internal_names_button:SetIcon("CommonAssets/UI/Ged/log-focused.tga")
		show_internal_names_button:SetRolloverText(T(496361185046, "Hide/show internal names of properties"))
		show_internal_names_button:SetBackground(self.idTitleContainer:GetBackground())
		show_internal_names_button:SetToggled(self.ShowInternalNames)
		show_internal_names_button.OnPress = function(button) 
			self:ShowInternalPropertyNames(not self.ShowInternalNames)
			button:SetToggled(not button:GetToggled())
		end
	end
	
	if not self.Embedded then
		if self.EnableCollapseCategories then
			local button = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
			button:SetIcon("CommonAssets/UI/Ged/collapse_tree.tga")
			button:SetRolloverText("Expand/collapse categories (Shift-C)")
			button:SetBackground(self.idTitleContainer:GetBackground())
			button.OnPress = function() self:ExpandCollapseCategories() end
		end
	
		if self.app.PresetClass and self.DisplayWarnings then
			self.ShowUnusedPropertyWarnings = self.app.ShowUnusedPropertyWarnings
			
			local button = XTemplateSpawn("GedToolbarToggleButtonSmall", self.idTitleContainer)
			button:SetIcon("CommonAssets/UI/Ged/warning_button.tga")
			button:SetRolloverText("Show/hide unused property warnings")
			button:SetBackground(self.idTitleContainer:GetBackground())
			button:SetToggled(self.ShowUnusedPropertyWarnings)
			button.OnPress = function(button)
				self.ShowUnusedPropertyWarnings = not self.ShowUnusedPropertyWarnings
				button:SetToggled(not button:GetToggled())
				self:UpdatePropertyNames(self.ShowInternalNames)
			end
		end
	end
end

--- Opens the GedPropPanel and sets up the update thread and action context.
---
--- @param ... any Additional arguments passed to the GedPanel:Open() function.
function GedPropPanel:Open(...)
	GedPanel.Open(self, ...)
	
	self:CreateThread("update", self.UpdateThread, self)
	GetActionsHost(self, true):ActionById("EditCode").ActionContexts = { self.PropActionContext }
end

--- Sets whether to show the internal property names in the GedPropPanel.
---
--- @param value boolean Whether to show the internal property names.
function GedPropPanel:ShowInternalPropertyNames(value)
	if self.ShowInternalNames ~= value then
		self.ShowInternalNames = value
		self:UpdatePropertyNames(value)
	end
end

--- Sets the selection of properties in the GedPropPanel.
---
--- @param properties table A table of property IDs to select.
function GedPropPanel:SetSelection(properties)
	if not properties then return end
	self:ClearSelectedProperties()
	for con_indx, win in ipairs(self.idContainer) do
		for cat_indx, item in ipairs(win.idCategory) do
			for _, id in ipairs(properties) do
				if item.prop_meta.id == id then 
					self:AddToSelected(item, con_indx, cat_indx)
				end
			end
		end
	end
end

---
--- Handles mouse button down events on the GedPropPanel.
---
--- This function is responsible for managing the selection of properties in the GedPropPanel.
--- It handles left-click selection, Ctrl-click to add/remove from selection, and Shift-click to select a range of properties.
--- Right-click events open a context menu for the selected properties.
---
--- @param pos table The position of the mouse click.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @return string "break" to indicate the event has been handled.
---
function GedPropPanel:OnMouseButtonDown(pos, button)
	local prop, container_indx, category_indx = self:GetGedPropAt(pos)
	local selected_props = self.selected_properties
	
	if button == "L" then
		self:SetFocus()
		self.app:SetLastFocusedPanel(self)
		if prop then 
			if #selected_props == 0 then
				self:AddToSelected(prop, container_indx, category_indx)
			else	
				if terminal.IsKeyPressed(const.vkControl) then -- Ctrl pressed
					if prop.selected then
						self:RemoveFromSelected(prop, container_indx, category_indx)
					else
						self:AddToSelected(prop, container_indx, category_indx)
					end
				elseif terminal.IsKeyPressed(const.vkShift) then -- Shift pressed
					self:ShiftSelectMultiple(prop, container_indx, category_indx)
				else
					local current_prop_selected = prop.selected
					self:ClearSelectedProperties()
					if not current_prop_selected then 
						self:AddToSelected(prop, container_indx, category_indx)
					end
				end
			end
		else
			self:ClearSelectedProperties()
		end
		return "break"
	elseif button == "R" then 
		self:SetFocus()
		local action_context = self:GetActionContext()
		if prop then 
			if #selected_props < 2 then
				self:ClearSelectedProperties()
				self:AddToSelected(prop, container_indx, category_indx)
			end
			action_context = self.PropActionContext
		end
		
		local host = GetActionsHost(self, true)
		if host then
			host:OpenContextMenu(action_context, pos)
		end
		return "break"
	end
end

---
--- Returns a table of the IDs of the currently selected properties.
---
--- @return table Selected property IDs
function GedPropPanel:GetSelectedProperties()
	local selected_ids = {}
	for _, prop in ipairs(self.selected_properties) do
		table.insert(selected_ids, prop.prop_meta.id)
	end
	return selected_ids
end

---
--- Shift-selects multiple properties in the GedPropPanel.
---
--- This function is used to select multiple properties in the GedPropPanel when the Shift key is pressed. It determines the range of properties to select based on the current and last selected property indices, and then adds all the properties in that range to the selected properties list.
---
--- @param prop The property that was clicked on.
--- @param container_indx The index of the container that the property is in.
--- @param category_indx The index of the category that the property is in.
---
function GedPropPanel:ShiftSelectMultiple(prop, container_indx, category_indx)
	self:ClearSelectedProperties("keep_last_selected_container_indx")

	--- default, when selection is in same container ---
	local con_indx = container_indx
	local max_con_indx = container_indx
	local cat_indx = category_indx
	local cat_max_indx = self.last_selected_property_indx
	if category_indx > self.last_selected_property_indx then
		cat_indx = self.last_selected_property_indx 
		cat_max_indx = category_indx
	end
	--- when selection is in different container ---
	if container_indx ~= self.last_selected_container_indx then
		if container_indx > self.last_selected_container_indx then
			con_indx = self.last_selected_container_indx 
			max_con_indx = container_indx 
			cat_indx = self.last_selected_property_indx 
			cat_max_indx = category_indx 
		else
			con_indx = container_indx
			max_con_indx = self.last_selected_container_indx 
			cat_indx = category_indx
			cat_max_indx = self.last_selected_property_indx
		end
	end
	
	local container = false
	local category_cnt = false
	local shift_select = true
	while shift_select do
		container = self.idContainer[con_indx]
		category_cnt = con_indx == max_con_indx and cat_max_indx or #container.idCategory
		if container.idCategory.visible then
			for i = cat_indx, category_cnt do
				self:AddToSelected(container.idCategory[i], self.last_selected_container_indx, self.last_selected_property_indx)
			end
		end
		con_indx = con_indx + 1
		cat_indx = 1
		if con_indx > max_con_indx then
			shift_select = false
		end		
	end
end
				
--- Handles shortcut key events for the GedPropPanel.
---
--- This function is called when a shortcut key is pressed while the GedPropPanel is active.
---
--- If the shortcut is "Escape" or "ButtonB", the function will clear the selected properties in the panel.
---
--- @param shortcut string The name of the shortcut key that was pressed.
--- @param source any The source of the shortcut event.
--- @param ... any Additional arguments passed with the shortcut event.
--- @return string|nil The result of the shortcut handling, or "break" to indicate the event was handled.
function GedPropPanel:OnShortcut(shortcut, source, ...)
	local res = GedPanel.OnShortcut(self, shortcut, source, ...)
	if res == "break" then return res end
	if shortcut == "Escape" or shortcut == "ButtonB" then
		self:ClearSelectedProperties()
	end
end

---
--- Clears the selected properties in the GedPropPanel.
---
--- If `keep_last_selected` is false, the last selected container and property indices are also cleared.
---
--- @param keep_last_selected boolean (optional) If true, the last selected container and property indices are not cleared.
---
function GedPropPanel:ClearSelectedProperties(keep_last_selected)
	local selected_props = self.selected_properties
	for i = 1, #selected_props do
		selected_props[i]:SetSelected(false)
		selected_props[i] = nil
	end 
	if not keep_last_selected then
		self.last_selected_container_indx = false
		self.last_selected_property_indx = false
	end
end

---
--- Adds a property to the list of selected properties in the GedPropPanel.
---
--- @param prop GedPropEditor The property to add to the selected properties list.
--- @param con_indx number The index of the container that the property belongs to.
--- @param prop_indx number The index of the property within the container.
---
function GedPropPanel:AddToSelected(prop, con_indx, prop_indx)
	prop:SetSelected(true)
	local selected_props = self.selected_properties
	assert(not table.find(selected_props, prop))
	selected_props[#selected_props + 1] = prop
	self.last_selected_container_indx = con_indx
	self.last_selected_property_indx = prop_indx
end

---
--- Removes a property from the list of selected properties in the GedPropPanel.
---
--- @param prop GedPropEditor The property to remove from the selected properties list.
--- @param con_indx number The index of the container that the property belongs to.
--- @param prop_indx number The index of the property within the container.
---
function GedPropPanel:RemoveFromSelected(prop, con_indx, prop_indx)
	prop:SetSelected(false)
	local selected_props = self.selected_properties
	local indx = table.find(selected_props, prop)
	assert(indx)
	selected_props[indx] = nil
	self.last_selected_container_indx = con_indx
	self.last_selected_property_indx = prop_indx
end

---
--- Gets the GedPropEditor at the specified screen point.
---
--- @param pt table The screen point to check for a GedPropEditor.
--- @return GedPropEditor|nil The GedPropEditor at the specified point, or nil if none found.
--- @return number|nil The index of the container that the GedPropEditor belongs to, or nil if none found.
--- @return number|nil The index of the GedPropEditor within the container, or nil if none found.
---
function GedPropPanel:GetGedPropAt(pt)
	for container_indx, container in ipairs(self.idContainer) do
		if container:HasMember("idCategory") and container.idCategory.visible then -- window which holds the GedPropEditors
			for gedprop_index, gedprop in ipairs(container.idCategory) do
				if gedprop:MouseInWindow(pt) then 
					return gedprop, container_indx, gedprop_index
				end 
			end
		end
	end
end

---
--- Sets the default collapse state for the GedPropPanel.
---
--- @param value boolean The new default collapse state.
---
function GedPropPanel:SetCollapseDefault(value)
	if self.CollapseDefault ~= value then
		self.CollapseDefault = value
		self.rebuild_props = true
		self:RequestUpdate()
	end
end

---
--- Binds the "props" and "values" views to the GedPropPanel.
---
--- The "props" view is bound to the "GedGetProperties" function, with the "SuppressProps" function used as a filter.
--- The "values" view is bound to the "GedGetValues" function.
---
--- This ensures that the "props" and "values" views will be resent on rebind, by first unbinding any existing views.
---
--- @param self GedPropPanel The GedPropPanel instance.
---
function GedPropPanel:BindViews()
	if not self.context then return end
	
	-- ensures all views will be resent on rebind
	self:UnbindView("props")
	self:UnbindView("values")
	
	self:BindView("props", "GedGetProperties", self.SuppressProps)
	self:BindView("values", "GedGetValues")
end

---
--- Handles context updates for the GedPropPanel.
---
--- This function is called when the context or view of the GedPropPanel changes. It updates the parent object ID, triggers a rebuild of the properties, and rebuilds the tabs.
---
--- @param context string The current context of the GedPropPanel.
--- @param view string|nil The current view of the GedPropPanel, or nil if the context has changed.
---
function GedPropPanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	if view == nil then
		self.parent_obj_id = self.connection.bound_objects[context]
		self.parent_changed = true
		self.parent_changed_notified = true
		self.connection.bound_objects[context .. "|values"] = nil
		self:RequestUpdate()
	end
	if view == "values" then
		self.rebuild_props = self.rebuild_props or self.CollapseDefault
		self:RequestUpdate()
	end
	if view == "props" then
		self.rebuild_props = true
		self:RequestUpdate()
		self:RebuildTabs()
	end
end

---
--- Gets the tabs data for the GedPropPanel.
---
--- This function retrieves the tabs data from the "props" object associated with the current context. It ensures that all categories are represented in the tabs, even if some tabs are empty. It also handles a special case for the "XTemplate" preset class, where the "Template" category is skipped.
---
--- @return table|nil The tabs data, or nil if no tabs data is available.
---
function GedPropPanel:GetTabsData()
	local data = self:Obj(self.context .. "|props")
	local tabs = data and data.tabs
	if not tabs then return end
	
	-- list all categories not it any tabs in an Other tab; remove empty tabs
	if tabs[#tabs].TabName ~= "Other" then
		local categories = {}
		for _, prop in ipairs(data) do
			categories[prop.category or "Misc"] = true
		end
		local allcats = table.copy(categories)
		for i = #tabs, 1, -1 do
			local tab = tabs[i]
			local has_content
			for category in pairs(tab.Categories) do
				has_content = has_content or allcats[category]
				categories[category] = nil
			end
			if not has_content then
				table.remove(tabs, i)
			end
		end
		if self.app.PresetClass == "XTemplate" then
			categories.Template = nil -- skip Template as a special case for XTemplate Editor (too hard not to make this hack)
		end
		tabs[#tabs + 1] = { TabName = #table.keys(categories) == 1 and next(categories) or "Other", Categories = categories }
	end
	return tabs
end

---
--- Rebuilds the tabs for the GedPropPanel.
---
--- This function is responsible for creating and managing the tabs in the GedPropPanel. It retrieves the tabs data from the `GetTabsData()` function, and then creates a new tab for each category. The tabs are displayed in the `idTabContainer` window.
---
--- If the `GetTabsData()` function returns `nil`, the function will not create any tabs and will set the layout spacing of the `idContainer` to 5 instead of 0.
---
--- The function also adds a special "All" tab at the beginning of the tab list, which will show all properties regardless of category.
---
--- When a tab is clicked, the `active_tab` property is updated and the `RebuildTabs()` and `UpdateVisibility()` functions are called to update the panel.
---
--- @return nil
function GedPropPanel:RebuildTabs()
	local container = rawget(self, "idTabContainer")
	if not container then
		container = XWindow:new({
			Id = "idTabContainer",
			LayoutMethod = "HList",
			Dock = "bottom",
			ZOrder = -1,
		}, self.idTitleContainer)
	end
	container:DeleteChildren()
	
	local tabs = self:GetTabsData()
	self.idContainer:SetLayoutVSpacing(tabs and 0 or 5)
	if not tabs then return end
	
	tabs = table.copy(tabs)
	table.insert(tabs, 1, { TabName = "All" })
	
	for _, tab in ipairs(tabs) do
		if tab.TabName == "All" or next(tab.Categories) then
			XToggleButton:new({
				Text = tab.TabName,
				Toggled = self.active_tab == tab.TabName,
				OnChange = function(button)
					self.active_tab = tab.TabName
					self:RebuildTabs()
					self:UpdateVisibility()
				end,
				Padding = box(2, 1, 2, 1),
				BorderWidth = 1,
			}, container)
		end
	end
	Msg("XWindowRecreated", container)
end

---
--- Requests an update of the GedPropPanel.
---
--- This function sets the `update_request` flag to `true` and wakes up the `update` thread, which will then proceed to update the property panel.
---
--- @return nil
function GedPropPanel:RequestUpdate()
	self.update_request = true
	Wakeup(self:GetThread("update"))
end

local function is_slider_dragged()
	return IsKindOfClasses(terminal.desktop:GetMouseCapture(), "XSleekScroll", "XCurveEditor", "XCoordAdjuster")
end

---
--- The `UpdateThread` function is responsible for updating the property panel in the Ged (Game Editor) application.
---
--- This function runs in a separate thread and is responsible for the following tasks:
---
--- 1. Waiting for an update request to be made by calling `RequestUpdate()`.
--- 2. Clearing the selected properties.
--- 3. Checking if the user is dragging a slider, and if so, updating the property panel without rebuilding the controls.
--- 4. Updating the property panel, either by rebuilding the controls or just updating the values, depending on the state of the `rebuild_props` flag.
--- 5. Resetting the `update_request` flag and the `parent_changed` flag.
--- 6. Queueing a reassignment of focus orders.
---
--- This function runs in a loop and will continue to execute until the application window is closed or the panel is destroyed.
---
--- @return nil
function GedPropPanel:UpdateThread()
	while true do
		if not self.update_request then
			WaitWakeup()
			if self.app.window_state == "closing" or self.window_state == "destroying" or not self.context then return end
		end
		self.update_request = false
		self:ClearSelectedProperties()
		-- don't recreate property editors while the user is dragging a slider
		while is_slider_dragged() do
			if self.app.window_state == "closing" or self.window_state == "destroying" or not self.context then return end
			self:Update(false)
			Sleep(50)
		end
		if self.app.window_state == "closing" or self.window_state == "destroying" or not self.context then return end
		self:Update(self.rebuild_props)
	end
end

---
--- Sets a property on an object in the Ged (Game Editor) application.
---
--- This function checks if a rebuild of the property panel is pending, and if not, it sets the specified property on the given object. It also checks if the parent object ID has changed, and if so, it skips the property update.
---
--- @param obj table The object to set the property on.
--- @param prop_id string The ID of the property to set.
--- @param value any The value to set the property to.
--- @param parent_obj_id string The ID of the parent object.
--- @param slider_drag_id boolean Whether the property is being set during a slider drag.
--- @return boolean Whether the property was successfully set.
function GedPropPanel:RemoteSetProperty(obj, prop_id, value, parent_obj_id, slider_drag_id)
	local rebuild_pending = self.rebuild_props and not slider_drag_id -- see UpdateThread above
	if not rebuild_pending and not self.parent_changed and (parent_obj_id or false) == self.parent_obj_id then
		return self.app:Op("GedSetProperty", obj, prop_id, value, not self.EnableUndo, slider_drag_id or is_slider_dragged())
	end
end

---
--- Updates the property panel, either by rebuilding the controls or just updating the values, depending on the state of the `rebuild_props` flag.
---
--- If `rebuild_props` is true and there are values to display, this function will:
--- - Save the current scroll position of the property panel
--- - Rebuild the controls in the property panel
--- - Restore the scroll position
--- - Set `rebuild_props` to false
---
--- If `rebuild_props` is false, this function will:
--- - Set `prop_update_in_progress` to true
--- - Loop through each category window in the property panel
--- - For each category window, loop through each property editor
--- - If there are values to display, update the value of the property editor
--- - Set the `parent_obj_id` of the property editor
--- - Set `prop_update_in_progress` to false
---
--- After the update, this function will:
--- - Set `parent_changed_notified` to false if there are values to display
--- - Set `parent_changed` to false
--- - Queue a reassignment of focus orders
---
--- @param rebuild_props boolean Whether to rebuild the controls in the property panel
--- @return nil
function GedPropPanel:Update(rebuild_props)
	local has_values = self:Obj(self.context .. "|values")
	if has_values and rebuild_props then -- rebuild controls
		local scroll_pos = self.idScroll.Scroll
		self:RebuildControls()
		self.idScroll:ScrollTo(scroll_pos)
		self.rebuild_props = false
	else -- only update the values
		self.prop_update_in_progress = true
		for _, category_window in ipairs(self.idContainer) do
			if category_window:HasMember("idCategory") then
				for _, win in ipairs(category_window.idCategory) do
					if has_values then
						win:UpdateValue(self.parent_changed_notified)
					end
					win.parent_obj_id = self.parent_obj_id
				end
			end
		end
		self.prop_update_in_progress = false
	end
	if has_values then
		self.parent_changed_notified = false
	end
	self.parent_changed = false
	self:QueueReassignFocusOrders()
end

---
--- Determines whether a button should be shown for the given function name.
---
--- If the `app.suppress_property_buttons` table is set, this function will check if the
--- given `func_name` is in that table. If so, it will return `nil`, indicating the button
--- should not be shown.
---
--- Otherwise, this function will return `true`, indicating the button should be shown.
---
--- @param func_name string The name of the function to check
--- @return boolean|nil Whether the button should be shown for the given function
---
function GedPropPanel:ShouldShowButtonForFunc(func_name)
	if rawget(self.app, "suppress_property_buttons") then
		if table.find(self.app.suppress_property_buttons, func_name) then
			return
		end
	end
	return true
end

---
--- Queues a thread to reassign focus orders for the GedPropPanel hierarchy.
---
--- This function traverses the parent hierarchy of the current GedPropPanel instance,
--- finding the topmost GedPropPanel instance. If that instance is not already running
--- a "ReasignFocusOrders" thread, it creates a new thread to call the `ReassignFocusOrders`
--- method with the provided `x` and `y` coordinates.
---
--- @param x number The x coordinate to pass to `ReassignFocusOrders`
--- @param y number The y coordinate to pass to `ReassignFocusOrders`
---
function GedPropPanel:QueueReassignFocusOrders(x, y)
	local obj = self
	while obj and obj.Embedded do
		obj = GetParentOfKind(obj.parent, "GedPropPanel")
	end
	
	if obj and not obj:IsThreadRunning("ReasignFocusOrders") then
		obj:CreateThread("ReasignFocusOrders", function() obj:ReassignFocusOrders(x, y) end)
	end
end

---
--- Updates the visibility of the GedPropPanel based on the current filter text.
---
function GedPropPanel:UpdateFilter()
	self:UpdateVisibility()
end

local function find_parent_prop_panel(xcontrol)
	return (xcontrol:HasMember("panel") and xcontrol.panel) or 
			(xcontrol.parent and find_parent_prop_panel(xcontrol.parent))
end

---
--- Rebuilds the controls for the GedPropPanel.
---
--- This function is responsible for creating and managing the property editors
--- displayed in the GedPropPanel. It performs the following steps:
---
--- 1. Gathers the existing property editors and stores them in a hash table for potential reuse.
--- 2. Clears the idContainer of the GedPropPanel.
--- 3. Finds the results from a value search to highlight the matching properties.
--- 4. Builds the categories and property editors based on the available properties.
--- 5. Sorts the categories and property editors based on priority.
--- 6. Creates the category windows and property editors, reusing existing editors when possible.
--- 7. Updates the visibility of the property editors based on the current filter text.
--- 8. Reassigns the focus orders for the property editors.
--- 9. Tries to highlight the search match.
--- 10. Sends a "XWindowRecreated" message.
--- 11. Deletes any remaining unused property editors.
---
--- @param self GedPropPanel The GedPropPanel instance.
---
function GedPropPanel:RebuildControls()
	-- gather the old prop editors for potential reuse
	local editors_by_hash = {}
	for _, category_window in ipairs(self.idContainer) do
		if category_window:HasMember("idCategory") then
			for _, editor in ipairs(category_window.idCategory) do
				local hash = xxhash(editor:GetContext(), table.hash(editor.prop_meta))
				assert(not editors_by_hash[hash])
				editors_by_hash[hash] = editor
				editor:DetachForReuse()
			end
		end
	end
	self.idContainer:Clear()
	
	-- find the results from a value search to highlight the matching properties
	local matching_props = {}
	local obj_id = self:Obj(self.context)
	for _, panel in pairs(self.app.interactive_panels) do
		local res = panel.search_value_results
		if res and type(res[obj_id]) == "table" then
			for idx, prop in ipairs(res[obj_id]) do
				matching_props[prop] = true
			end
			break
		end
	end	
	
	local categories = {}
	local sort_priority = 1
	local context = self.context
	local values = self:Obj(context .. "|values") or empty_table
	local props = self:Obj(context .. "|props") or empty_table
	if self.read_only then
		for idx, prop_meta in ipairs(props) do
			props[idx] = table.copy(prop_meta)
			props[idx].read_only = true
		end
	end
	table.stable_sort(props, function(a, b) return (a.sort_order or 0) < (b.sort_order or 0) end)
	
	local filter_text = self:GetFilterText()
	local focus = self.desktop.keyboard_focus
	local order = focus and focus:IsWithin(self) and focus:GetFocusOrder()
	local category_data = self:Obj("root|categories") or empty_table
	local parent_panel = find_parent_prop_panel(self) 
	local collapse_default = filter_text == "" and (self.CollapseDefault or (self.Embedded and parent_panel and parent_panel.CollapseDefault) )
	for _, prop_meta in ipairs(props) do
		if not collapse_default or prop_meta.editor == "buttons" or
			values[prop_meta.id] ~= nil and values[prop_meta.id] ~= prop_meta.default
		then
			local group
			local category = prop_meta.category or "Misc"
			local idx = table.find(categories, "category", category)
			if idx then
				group = categories[idx]
			else
				group = { prop_metas = {}, category = category, category_name = category, priority = sort_priority}
				sort_priority = sort_priority + 1
				local property_category = category_data and category_data[category]
				if property_category then
					group.category_name = _InternalTranslate(property_category.display_name, property_category)
					group.priority = group.priority + property_category.SortKey * 1000
				end
				table.insert(categories, group)
			end
			table.insert(group.prop_metas, prop_meta)
		end
	end
	
	if #categories == 0 then
		local text = XText:new({
			Id = "idNoPropsToShow",
			MaxWidth = 300,
			TextHAlign = "center",
		}, self.idContainer)
		text:SetText(collapse_default and "No properties with non-default value were found." or "There are no properties to show.")
		text:Open()
		goto cleanup
	end
	
	table.stable_sort(categories, function(a, b) return a.priority < b.priority end)
	for i, group in ipairs(categories) do
		local category_window = XWindow:new({
			IdNode = true,
			FoldWhenHidden = true,
		}, self.idContainer)
		local container = XWindow:new({
			Id = "idCategory",
			LayoutMethod = "VList",
			LayoutVSpacing = 0,
			FoldWhenHidden = true,
		}, category_window)
		local button = XTextButton:new({
			Id = "idCategoryButton",
			Dock = "top",
			FoldWhenHidden = true,
			LayoutMethod = "VList",
			Padding = box(2, 2, 2, 2),
			Background = RGBA(38, 146, 227, 255),
			FocusedBackground = RGBA(24, 123, 197, 255),
			DisabledBackground = RGBA(128, 128, 128, 255),
			OnPress = function(button)
				self:ExpandCategory(container, group.category, not container:GetVisible(), not self.Embedded and "save_settings")
			end,
			RolloverBackground = RGBA(24, 123, 197, 255),
			PressedBackground = RGBA(13, 113, 187, 255),
			Image = "CommonAssets/UI/round-frame-20.tga",
			ImageScale = point(500, 500),
			FrameBox = box(9, 9, 9, 9),
		}, category_window)
		button:SetTextStyle("GedButton")
		button:SetText(group.category_name)
		button:SetVisible(not self.HideFirstCategory or i ~= 1)
		if self.collapsed_categories[group.category] then
			container:SetVisible(false)
		end
		rawset(category_window, "category", group.category)
		category_window:Open()
		
		self.prop_update_in_progress = true
		
		local values_name = context .. "|values"
		for p, prop_meta in ipairs(group.prop_metas) do
			local editor_name = prop_meta.editor or prop_meta.type
			local editor_class = GedPropEditors[editor_name or false]
			if not editor_class then
				assert(editor_class ~= "objects", "Unknown prop editor name: " .. tostring(editor_name))
			elseif not g_Classes[editor_class] then
				assert(false, "Unknown prop editor class: " .. tostring(editor_class))
			else
				local context = self.context .. "." .. prop_meta.id
				local editor = editors_by_hash[xxhash(context, table.hash(prop_meta))]
				if editor then
					editor:SetParent(container)
					editor:SetContext(context)
				else
					editor = g_Classes[editor_class]:new({
						panel = self,
						obj = values_name,
					}, container, context, prop_meta)
					editor:Open()
				end
				editor:SetHighlightSearchMatch(matching_props[prop_meta.id])
				editor:UpdatePropertyNames(self.ShowInternalNames)
				editor:UpdateValue(true)
				editor.parent_obj_id = self.parent_obj_id
			end
		end
		
		self.prop_update_in_progress = false
	end
	
	self:UpdateVisibility()
	self:ReassignFocusOrders()
	focus = self:GetRelativeFocus(order, "nearest")
	if focus then
		focus:SetFocus()
	end
	
::cleanup::
	self:TryHighlightSearchMatch("skip_visibility_update")
	
	Msg("XWindowRecreated", self)
	for _, editor in pairs(editors_by_hash) do
		if not editor.parent then
			editor:delete()
		end
	end
end

---
--- Reassigns the focus order of the property editors within the GedPropPanel.
---
--- @param x number|nil The new focus column index, or nil to use the current value.
--- @param y number|nil The new focus row index, or nil to use the current value.
--- @return number The next focus row index.
function GedPropPanel:ReassignFocusOrders(x, y)
	x = x or self.focus_column
	y = y or 0
	
	if self.window_state == "destroying" then
		return y
	end
	
	for _, category_window in ipairs(self.idContainer) do
		if category_window:GetVisible() and category_window:HasMember("idCategory") then
			for _, prop_editor in ipairs(category_window.idCategory) do
				y = prop_editor:ReassignFocusOrders(x, y)
				assert(y)
			end
		end
	end
	return y
end

---
--- Updates the property names for all property editors in the GedPropPanel.
---
--- @param internal boolean Whether the update is being triggered internally.
function GedPropPanel:UpdatePropertyNames(internal)
	for _, category_window in ipairs(self.idContainer) do
		for _, prop_editor in ipairs(rawget(category_window, "idCategory") or empty_table) do
			prop_editor:UpdatePropertyNames(internal)
		end
	end
end

---
--- Determines whether a property editor should be visible based on the current filter and highlight text.
---
--- @param prop_editor GedPropEditor The property editor to check for visibility.
--- @param filter_text string The current filter text.
--- @param highlight_text string The current highlight text.
--- @return boolean Whether the property editor should be visible.
function GedPropPanel:IsPropEditorVisible(prop_editor, filter_text, highlight_text)
	local tab = self.active_tab
	local tabs = self:GetTabsData()
	if tab ~= "All" and tabs then
		local prop = prop_editor.prop_meta
		local tab_data = table.find_value(tabs, "TabName", tab)
		if tab_data and not tab_data.Categories[prop.category or "Misc"] then
			return false
		end
	end
	return prop_editor:FindText(filter_text, highlight_text)
end

---
--- Updates the visibility of property editors in the GedPropPanel based on the current filter and highlight text.
---
--- @param self GedPropPanel The GedPropPanel instance.
function GedPropPanel:UpdateVisibility()
	local values = self.context and self:Obj(self.context .. "|values")
	if not values then return end
	
	local filter_text = self:GetFilterText()
	local highlight_text = self:GetHighlightText()
	for _, category_window in ipairs(self.idContainer) do
		local hidden = 0
		local prop_editors = rawget(category_window, "idCategory") or empty_table
		for _, prop_editor in ipairs(prop_editors) do
			local visible = self:IsPropEditorVisible(prop_editor, filter_text, highlight_text)
			prop_editor:SetVisible(visible)
			if not visible then
				hidden = hidden + 1
			end
		end
		category_window:SetVisible(hidden ~= #prop_editors)
	end
end

---
--- Locates a property editor by its unique identifier.
---
--- @param id string The unique identifier of the property editor to locate.
--- @return GedPropEditor|nil The property editor with the specified identifier, or nil if not found.
function GedPropPanel:LocateEditorById(id)
	if self.window_state == "destroying" then return end
	for _, category_window in ipairs(self.idContainer) do
		if category_window:HasMember("idCategory") then
			for _, prop_editor in ipairs(category_window.idCategory) do
				if prop_editor.prop_meta.id == id then
					return prop_editor
				end
			end
		end
	end
end

---
--- Attempts to highlight the search match for the current property editor.
---
--- If a search match is found for the current property editor, this function will focus the
--- property editor and scroll it into view. It will also update the visibility of the
--- property editors based on the current filter and highlight text.
---
--- @param self GedPropPanel The GedPropPanel instance.
--- @param skip_visibility_update boolean (optional) If true, the visibility update will be skipped.
function GedPropPanel:TryHighlightSearchMatch(skip_visibility_update)
	local match_data = self.app:GetDisplayedSearchResultData()
	local obj_id = self:Obj(self.context)
	if match_data and match_data.path[#match_data.path] == obj_id then
		if self.desktop:GetKeyboardFocus().Id ~= "idSearchEdit" then
			self:FocusPropEditor(match_data.prop)
		end
		self.app.display_search_result = false
	end
	if not skip_visibility_update then
		self:UpdateVisibility()
	end
end

---
--- Focuses the specified property editor and scrolls it into view.
---
--- If a search match is found for the current property editor, this function will focus the
--- property editor and scroll it into view. It will also update the visibility of the
--- property editors based on the current filter and highlight text.
---
--- @param self GedPropPanel The GedPropPanel instance.
--- @param prop_id string The unique identifier of the property editor to focus.
function GedPropPanel:FocusPropEditor(prop_id)
	local old_focused = self.search_value_focused_prop_editor
	if old_focused and old_focused.parent and old_focused.window_state ~= "destroying" then
		old_focused:HighlightAndSelect(false)
	end
	
	local highlight_text = self:GetHighlightText()
	local prop_editor = self:LocateEditorById(prop_id)
	local focus = highlight_text and prop_editor and prop_editor:HighlightAndSelect(highlight_text)
	if focus then
		-- scroll the prop editor into the view
		local scrollarea = self.idContainer
		local parent = GetParentOfKind(scrollarea.parent, "XScrollArea")
		while parent do
			scrollarea = parent
			parent = GetParentOfKind(scrollarea.parent, "XScrollArea")
		end
		scrollarea:ScrollIntoView(focus)
	end
	self.search_value_focused_prop_editor = prop_editor
end

---
--- Expands or collapses a category in the GedPropPanel.
---
--- @param self GedPropPanel The GedPropPanel instance.
--- @param container XWindow The container window for the category.
--- @param category string The name of the category.
--- @param expand boolean Whether to expand or collapse the category.
--- @param save_settings boolean Whether to save the collapsed state of the category.
---
function GedPropPanel:ExpandCategory(container, category, expand, save_settings)
	self.collapsed_categories[category] = not expand
	if save_settings then
		self:SaveCollapsedCategories(self.context)
	end
	container:SetVisible(expand)
end

---
--- Saves the collapsed state of categories in the GedPropPanel.
---
--- This function saves the collapsed state of the categories in the GedPropPanel to the application settings.
---
--- @param self GedPropPanel The GedPropPanel instance.
--- @param key string The key to use for storing the collapsed categories.
function GedPropPanel:SaveCollapsedCategories(key)
	local app = self.app
	local settings = app.settings.collapsed_categories or {}
	settings[key] = self.collapsed_categories
	app.settings.collapsed_categories = settings
	app:SaveSettings()
end

---
--- Expands or collapses all categories in the GedPropPanel.
---
--- This function is used to expand or collapse all categories in the GedPropPanel. It checks if any category is currently expanded, and then sets the visibility of all category windows accordingly. The collapsed state of the categories is not saved.
---
--- @param self GedPropPanel The GedPropPanel instance.
---
function GedPropPanel:ExpandCollapseCategories()
	if self.window_state == "destroying" then return end
	
	local has_expanded
	for _, category_window in ipairs(self.idContainer) do
		if category_window:HasMember("idCategory") and category_window.idCategory:GetVisible() then
			has_expanded = true
			break
		end
	end
	
	for _, category_window in ipairs(self.idContainer) do
		if category_window:HasMember("idCategory") then
			self:ExpandCategory(category_window.idCategory, category_window.category, not has_expanded, not "save_settings")
		end
	end
end


----- GedListPanel

DefineClass.GedListPanel = {
	__parents = { "GedPanel" },
	properties = {
		{ category = "General", id = "FormatFunc", editor = "text", default = "GedListObjects", },
		{ category = "General", id = "Format", editor = "text", default = "<name>", },
		{ category = "General", id = "AllowObjectsOnly", editor = "bool", default = false, },
		{ category = "General", id = "FilterName", editor = "text", default = "", },
		{ category = "General", id = "FilterClass", editor = "text", default = "", },
		{ category = "General", id = "SelectionBind", editor = "text", default = "", },
		{ category = "General", id = "OnDoubleClick", editor = "func", params = "self, item_idx", default = function(self, item_idx) end, },
		{ category = "General", id = "MultipleSelection", editor = "bool", default = false },
		
		{ category = "General", id = "EmptyText", editor = "text", default = "" },
		{ category = "General", id = "DragAndDrop", editor = "bool", default = false },
		
		{ category = "Common Actions", id = "ItemClass", editor = "expression", params = "gedapp", default = function(gedapp) return "" end, },
		{ category = "Context Menu", id = "ItemActionContext", editor = "text", default = "" },
	},
	ContainerControlClass = "XList",
	Interactive = true,
	EnableSearch = true,
	Translate = true,
	
	pending_update = false,
	pending_selection = false,
	restoring_state = false,
}

--- Initializes the controls for the GedListPanel.
-- This function sets up the event handlers for the list control, including the selection and double-click events.
-- It also sets the multiple selection mode and the action contexts for the list.
-- Finally, it sets the search action contexts for the panel.
function GedListPanel:InitControls()
	GedPanel.InitControls(self)
	
	local list = self.idContainer
	list.OnSelection   = function(list, ...)          self:OnSelection(...)          end
	list.OnDoubleClick = function(list, item_idx)     self:OnDoubleClick(item_idx)   end
	list.CreateTextItem = function(list, ...) return  self:CreateTextItem(...)       end
	list:SetMultipleSelection(true)
	list:SetActionContext(self.ActionContext)
	list:SetItemActionContext(self.ItemActionContext)

	GedPanel.SetSearchActionContexts(self, self.SearchActionContexts)
end

--- Unbinds the objects associated with the `SelectionBind` property of the `GedListPanel` instance.
-- This function is called when the `GedListPanel` is done with its operations, to clean up any
-- object bindings that were set up during the panel's lifetime.
function GedListPanel:Done()
	for bind in string.gmatch(self.SelectionBind .. ",", reCommaList) do
		self.connection:UnbindObj(bind)
	end
end

--- Creates a new text item for the GedListPanel.
-- @param text The text to display in the item.
-- @param props A table of properties to apply to the item.
-- @param context The context to use for the item.
-- @return The created XListItem.
function GedListPanel:CreateTextItem(text, props, context)
	props = props or {}
	local item = XListItem:new({ selectable = props.selectable }, self.idContainer)
	props.selectable = nil
	local label = XText:new(props, item, context)
	label:SetText(text)
	item.idLabel = label
	if self.DragAndDrop then
		item.idDragAndDrop = GedListDragAndDrop:new({
			Dock = "box",
			List = self,
			Item = item,
		}, item)
	end
	return item
end

--- Binds the views for the GedListPanel.
-- If the FilterName is not empty and the FilterClass is set, it binds a filter object to the list.
-- It then binds the view for the "list" element using the FormatFunc, Format, and AllowObjectsOnly properties.
function GedListPanel:BindViews()
	if self.FilterName ~= "" and self.FilterClass then
		self.connection:BindFilterObj(self.context .. "|list", self.FilterName, self.FilterClass)
	end
	self:BindView("list", self.FormatFunc, self.Format, self.AllowObjectsOnly)
end

--- Returns the currently selected item(s) in the GedListPanel.
-- If there is a single selected item, it returns that item and a table containing the selected item.
-- If there are multiple selected items, it returns the first selected item and the table of selected items.
-- If there are no selected items, it returns nil.
function GedListPanel:GetSelection()
	local selection = self.pending_selection or self.idContainer:GetSelection()
	if not selection or not next(selection) then return end
	return selection[1], selection
end

--- Returns the currently selected item(s) in the GedListPanel.
-- If there is a single selected item, it returns that item and a table containing the selected item.
-- If there are multiple selected items, it returns the first selected item and the table of selected items.
-- If there are no selected items, it returns nil.
function GedListPanel:GetMultiSelection()
	return self.idContainer:GetSelection()
end

--- Sets the selection of the GedListPanel.
-- If `restoring_state` or `self.pending_update` is true, the `pending_selection` is set to `multiple_selection` or `selection`, and `restoring_state` is set to `restoring_state`.
-- Otherwise, the `idContainer` selection is set to `multiple_selection` or `selection`, with `notify` being passed through.
-- @param selection The selection to set, either a single item or a table of items.
-- @param multiple_selection Whether the selection is multiple items.
-- @param notify Whether to notify listeners of the selection change.
-- @param restoring_state Whether the selection is being restored from a previous state.
function GedListPanel:SetSelection(selection, multiple_selection, notify, restoring_state)
	if restoring_state or self.pending_update then
		self.pending_selection = multiple_selection or selection
		self.restoring_state = restoring_state
		return
	end
	self.idContainer:SetSelection(multiple_selection or selection, notify)
end

--- Binds the selected object and selected objects to the GedListPanel.
-- This function is called when an item is selected in the GedListPanel.
-- @param selected_item The currently selected item.
-- @param selected_items A table of all currently selected items.
function GedListPanel:OnSelection(selected_item, selected_items)
	self:BindSelectedObject(selected_item, selected_items)
end

---
--- Sets the selection of the GedListPanel and tries to highlight the search match in child panels.
--- If the list's selection is already set to the given index, it tries to highlight the search match in child panels.
--- Otherwise, it sets the selection to the given index and sets the focus to the GedListPanel if the keyboard focus is not on the search edit.
---
--- @param idx The index of the item to select in the list.
---
function GedListPanel:SetSelectionAndFocus(idx)
	local list = self.idContainer
	if list:GetSelection() == idx then
		self.app:TryHighlightSearchMatchInChildPanels(self)
	else
		-- focusing prevents issues with the focus restored to the leftmost panel (and selecting the wrong object) when cycling through search results
		local focus = self.desktop:GetKeyboardFocus()
		if not focus or focus.Id ~= "idSearchEdit" then
			self:SetFocus()
		end
		list:SetSelection(idx)
	end
end

---
--- Tries to highlight the search match in child panels.
--- If the list's selection is already set to the index of the search match, it tries to highlight the search match in child panels.
--- Otherwise, it sets the selection to the index of the search match and sets the focus to the GedListPanel if the keyboard focus is not on the search edit.
---
--- @param self The GedListPanel instance.
---
function GedListPanel:TryHighlightSearchMatch()
	local obj_id = self:Obj(self.context)
	local match_data = self.app:GetDisplayedSearchResultData()
	if match_data then
		local match_path = match_data.path
		local match_idx = table.find(match_path, obj_id)
		if match_idx and match_idx < #match_path then
			local match_id = match_path[match_idx + 1]
			local list = self:Obj(self.context .. "|list")
			local ids = list.ids or empty_table
			for idx in ipairs(list) do
				if ids[idx] == match_id then
					self:SetSelectionAndFocus(idx)
					break
				end
			end
		end
	end
end

---
--- Handles the context update for the GedListPanel.
--- If the view is `nil`, it clears the selection of the idContainer and sets the pending_update flag.
--- If the view is "list", it updates the content of the panel, starts the update filter thread if search_values is not nil, and tries to highlight the search match.
--- If the view is "warning" and DisplayWarnings is true, it updates the content of the panel to underline the warning nodes.
---
--- @param context The context of the panel.
--- @param view The view of the panel.
---
function GedListPanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	if view == nil then
		self.idContainer:SetSelection(false)
		self.pending_update = true
	end
	if view == "list" then
		self:UpdateContent()
		if self.search_values then
			self:StartUpdateFilterThread("not_user_initiated")
		end
		self:TryHighlightSearchMatch()
	end
	if view == "warning" and self.DisplayWarnings then
		self:UpdateContent() -- if the displayed items need to be underlined
	end
end

---
--- Binds the selected object to the specified bindings.
---
--- If `selected_item` is `nil`, this function does nothing.
---
--- If `MultipleSelection` is true and `selected_indexes` is not `nil` and has more than one element, it selects and binds multiple objects using `app:SelectAndBindMultiObj()`.
---
--- Otherwise, it selects and binds a single object using `app:SelectAndBindObj()`.
---
--- @param selected_item The selected object to bind.
--- @param selected_indexes The indices of the selected objects, if multiple selection is enabled.
---
function GedListPanel:BindSelectedObject(selected_item, selected_indexes)
	if not selected_item then return end
	self.app:StoreAppState()
	for bind in string.gmatch(self.SelectionBind .. ",", reCommaList) do
		if self.MultipleSelection and selected_indexes and #selected_indexes > 1 then
			self.app:SelectAndBindMultiObj(bind, self.context, selected_indexes)
		else
			self.app:SelectAndBindObj(bind, { self.context, selected_item })
		end
	end
end

---
--- Updates the content of the GedListPanel.
---
--- If the list is not available, it clears the idContainer and sets the pending_update flag.
---
--- Otherwise, it updates the content of the panel, including:
--- - Handling the selection and scroll position
--- - Filtering the items based on the filter text
--- - Underlining the warning nodes if DisplayWarnings is true
--- - Creating an empty text item if the list is empty and EmptyText is set
---
--- @param self The GedListPanel instance
function GedListPanel:UpdateContent()
	if not self.context then return end
	local list = self:Obj(self.context .. "|list")
	if not list then
		self.idContainer:Clear()
		return
	end
	
	local sel = self.pending_selection or self.idContainer:GetSelection()
	local scroll_pos = self.idScroll.Scroll
	local filtered, ids = list.filtered, list.ids
	local filter_text = self:GetFilterText()
	if filter_text == "" then
		filter_text = false
	end
	local warning_idxs = self.DisplayWarnings and get_warning_nodes(self) or empty_table
	if #warning_idxs == 0 then
		warning_idxs = false
	end
	local container = self.idContainer
	container:Clear()
	local string_format = string.format
	for i, item_text in ipairs(list) do
		local str = "<literal(text,true)>"
		if warning_idxs and table.find(warning_idxs, i) then
			str = string_format("<underline>%s</underline>", str)
		end
		str = string.format("<read_only('%s')>%s</read_only('%s')>", self.context, str, self.context)
		local item_id = ids and ids[i]
		if item_id then
			str = string_format("<ged_marks('%s')>%s", item_id, str)
		end
		
		str = T{str, text = item_text, untranslated = true}
		local item = container:CreateTextItem(str, { Translate = true })
		if filtered and filtered[i] or filter_text and self:FilterItem(item_text, item_id, filter_text) then
			item:SetDock("ignore")
			item:SetVisible(false)
		end
	end

	if #list == 0 and self.EmptyText then
		self.idContainer:CreateTextItem(Untranslated(self.EmptyText), { Translate = true })
	end
	
	self.idScroll:ScrollTo(scroll_pos)
	self.idContainer:SetSelection(sel, self.pending_update and not self.restoring_state) -- notify only if selection is set externally
	self.pending_update = false
	self.pending_selection = false
	self.restoring_state = false
	Msg("XWindowRecreated", self)
end

---
--- Focuses the first visible entry in the GedListPanel's item container.
--- This function iterates through the items in the container and sets the selection
--- to the first item that is not hidden (i.e. has a "ignore" dock state).
--- After setting the selection, the function also sets the panel as focused.
---
--- @param self GedListPanel The GedListPanel instance.
---
function GedListPanel:FocusFirstEntry()
	for idx, value in ipairs(self.idContainer) do
		if value.Dock ~= "ignore" then
			self.idContainer:SetSelection(idx)
			break
		end
	end
	self:SetPanelFocused()
end

---
--- Updates the filter for the GedListPanel.
---
--- This function is called to update the content of the GedListPanel based on the current filter settings.
---
--- @param self GedListPanel The GedListPanel instance.
---
function GedListPanel:UpdateFilter()
	self:UpdateContent()
end

---
--- Updates the text of all items in the GedListPanel's item container.
---
--- This function is called to update the text of all items in the GedListPanel's item container.
--- It first updates the title of the panel, then iterates through all the items in the container
--- and sets the text of each item to its current text.
---
--- @param self GedListPanel The GedListPanel instance.
---
function GedListPanel:UpdateItemTexts()
	self:UpdateTitle(self.context)
	for _, item in ipairs(self.idContainer) do
		item[1]:SetText(item[1]:GetText())
	end
end

--- Checks if the GedListPanel is empty.
---
--- @param self GedListPanel The GedListPanel instance.
--- @return boolean True if the list in the GedListPanel is empty, false otherwise.
function GedListPanel:IsEmpty()
	local list = self:Obj(self.context .. "|list")
	return list and #list > 0
end


----- GedTreePanel

DefineClass.GedTreePanel = {
	__parents = { "GedPanel" },
	properties = {
		{ category = "General", id = "FormatFunc", editor = "text", default = "GedObjectTree", },
		{ category = "General", id = "Format", editor = "text", default = "<name>", },
		{ category = "General", id = "AltFormat", editor = "text", default = "", },
		{ category = "General", id = "AllowObjectsOnly", editor = "bool", default = false, },
		{ category = "General", id = "FilterName", editor = "text", default = "", },
		{ category = "General", id = "FilterClass", editor = "text", default = "", },
		{ category = "General", id = "SelectionBind", editor = "text", default = "", },
		{ category = "General", id = "OnSelectionChanged", editor = "func", params = "self, selection", default = function(self, selection) end, },
		{ category = "General", id = "OnCtrlClick", editor = "func", params = "self, selection", default = function(self, selection) end, },
		{ category = "General", id = "OnAltClick", editor = "func", params = "self, selection", default = function(self, selection) end, },
		{ category = "General", id = "OnDoubleClick", editor = "func", params = "self, selection", default = function(self, selection) end, },
		{ category = "General", id = "MultipleSelection", editor = "bool", default = false },
		{ category = "General", id = "DragAndDrop", editor = "bool", default = false },
		{ category = "General", id = "EnableRollover", editor = "bool", default = false },
		
		{ category = "General", id = "EmptyText", editor = "text", default = "" },
		
		-- Enables the actions for all nodes of a tree panel. By default actions are disabled for Group nodes but some tree panels don't have groups and can use this option.
		{ category = "Common Actions", id = "EnableForRootLevelItems", editor = "bool", default = false, },
		{ category = "Common Actions", id = "ItemClass", editor = "expression", params = "gedapp", default = function(gedapp) return "" end, },
		
		{ category = "Context Menu", id = "RootActionContext", editor = "text", default = "" },
		{ category = "Context Menu", id = "ChildActionContext", editor = "text", default = "" },

		{ category = "Layout", id = "FullWidthText", editor = "bool", default = false, },
		{ category = "Layout", id = "ShowToolbarButtons", name = "Show toolbar buttons", editor = "bool", default = true, help = "Show/hide the buttons in the TreePanel toolbar (expand/collapse tree, etc)", },
	},
	ContainerControlClass = "XTree",
	HorizontalScroll = true,
	EnableSearch = true,
	Interactive = true,
	Translate = true,
	
	expanding_node = false,
	currently_selected_path = false,
	pending_update = false,
	pending_selection = false,
	alt_format_enabled = false,
	filtered_tree = false,
	view_warnings_only = false,
	view_errors_only = false,
}

---
--- Initializes the controls for the GedTreePanel.
--- This function sets up the behavior and event handlers for the tree control
--- within the GedTreePanel. It configures the tree control to use the
--- `GedTreePanel:GetNodeChildren()` function to populate the tree, and sets up
--- event handlers for various user interactions with the tree.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:InitControls()
	GedPanel.InitControls(self)
	
	local tree = self.idContainer
	tree:SetSortChildNodes(false)
	tree.GetNodeChildren = function(tree, ...) return self:GetNodeChildren(...) end
	tree.InitNodeControls = function(tree, ...) self:InitNodeControls(...) end
	tree.OnSelection = function(tree, selection, selected_indexes) self:OnSelection(selection, selected_indexes) end
	tree.OnCtrlClick = function(tree, ...) self:OnCtrlClick(...) end
	tree.OnAltClick = function(tree, ...) self:OnAltClick(...) end
	tree.OnUserExpandedNode = function(tree, path) self:OnUserExpandedNode(path) end
	tree.OnUserCollapsedNode = function(tree, path) self:OnUserCollapsedNode(path) end
	tree.OnDoubleClickedItem = function(tree, path) self:OnDoubleClick(path) end
	
	tree:SetActionContext(self.ActionContext)
	tree:SetRootActionContext(self.RootActionContext)
	tree:SetChildActionContext(self.ChildActionContext)
	tree:SetMultipleSelection(true)
	tree:SetFullWidthText(self.FullWidthText)
	GedPanel.SetSearchActionContexts(self, self.SearchActionContexts)
	
	local alt_format_button = XTemplateSpawn("GedToolbarToggleButtonSmall", self.idTitleContainer)
	alt_format_button:SetId("idAltFormatButton")
	alt_format_button:SetIcon("CommonAssets/UI/Ged/log-focused.tga")
	alt_format_button:SetRolloverText(T(185486815318, "Hide/show alternative names"))
	alt_format_button:SetBackground(self.idTitleContainer:GetBackground())
	alt_format_button:SetToggled(false)
	alt_format_button:SetFoldWhenHidden(true)
	alt_format_button:SetVisible(self.AltFormat and self.AltFormat ~= "")
	alt_format_button.OnPress = function(button)
		self.alt_format_enabled = not button:GetToggled()
		button:SetToggled(self.alt_format_enabled)
		self:BindView("tree", self.FormatFunc, self.alt_format_enabled and self.AltFormat or self.Format, self.AllowObjectsOnly)
	end

	if self.ShowToolbarButtons then
		local button = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
		button:SetIcon("CommonAssets/UI/Ged/collapse_node.tga")
		button:SetRolloverText("Expand/collapse selected node's children (Alt-C)")
		button:SetBackground(self.idTitleContainer:GetBackground())
		button.OnPress = function()
			self.idContainer:ExpandNodeByPath(self.idContainer:GetFocusedNodePath() or empty_table)
			self.idContainer:ExpandCollapseChildren(self.idContainer:GetFocusedNodePath() or empty_table, not "recursive", "user_initiated")
		end
		
		local button = XTemplateSpawn("GedToolbarButtonSmall", self.idTitleContainer)
		button:SetIcon("CommonAssets/UI/Ged/collapse_tree.tga")
		button:SetRolloverText("Expand/collapse tree (Shift-C)")
		button:SetBackground(self.idTitleContainer:GetBackground())
		button.OnPress = function() self.idContainer:ExpandCollapseChildren({}, "recursive", "user_initiated") end
	end
end

---
--- Unbinds all objects associated with the `SelectionBind` property of the `GedTreePanel` instance.
---
--- This function is called when the `GedTreePanel` is done being used, to clean up any bindings that were set up.
---
function GedTreePanel:Done()
	for bind in string.gmatch(self.SelectionBind .. ",", reCommaList) do
		self.connection:UnbindObj(bind)
	end
end

---
--- Binds the views for the GedTreePanel instance.
---
--- If a filter name and class are set, the connection is bound to the filtered object.
--- The tree view is bound using the specified format function, alt format, and allow objects only setting.
--- If the desktop does not have keyboard focus, the panel is set as focused.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:BindViews()
	if self.FilterName ~= "" and self.FilterClass then
		self.connection:BindFilterObj(self.context .. "|tree", self.FilterName, self.FilterClass)
	end
	self:BindView("tree", self.FormatFunc, self.alt_format_enabled and self.AltFormat or self.Format, self.AllowObjectsOnly, self.EnableRollover)
	if not terminal.desktop:GetKeyboardFocus() then
		self:SetPanelFocused()
	end
end

local function try_index(root, key, ...)
	if key and root then
		return try_index(root[key], ...)
	end
	return root
end

---
--- Gets the children of a node in the GedTreePanel.
---
--- @param self GedTreePanel The GedTreePanel instance.
--- @param ... Any number of keys to index into the filtered_tree table.
--- @return table, table, table, table, table The texts, is_leaf, auto_expand, rollovers, and user_datas for the child nodes.
---
function GedTreePanel:GetNodeChildren(...)
	if not self.filtered_tree then return end

	local texts, is_leaf, auto_expand, rollovers, user_datas = {}, {}, {}, {}, {}
	local node_data = try_index(self.filtered_tree, ...)
	local warning_idxs = self.filtered_tree == node_data and get_warning_nodes(self) or empty_table
	if type(node_data) == "table" then
		for i, subnode in ipairs(node_data) do
			if subnode then
				local read_only_wrapped_text = string.format("<read_only('%s')><literal(text,true)></read_only('%s')>", self.context, self.context)
				local format = subnode.id and ("<ged_marks('%s')>" .. read_only_wrapped_text) or read_only_wrapped_text
				if table.find(warning_idxs, i) then
					format = string.format("<underline>%s</underline>", format)
				end
				
				local str = subnode.id and string.format(format, subnode.id) or format
				texts[i] = T{str, text = subnode.name, untranslated = true}
				is_leaf[i] = #subnode == 0
				auto_expand[i] = not subnode.collapsed
				rollovers[i] = subnode.rollover
				user_datas[i] = subnode
			end
		end
	end
	return texts, is_leaf, auto_expand, rollovers, user_datas
end

GedTreePanel.OnShortcut = GedPanel.OnShortcut

local function new_item(self, child, class, path, button)
	local method = child and "GedGetSubItemClassList" or "GedGetSiblingClassList"
	local items = self.app:Call(method, self.context, path, self.app.ScriptDomain)
	local title = string.format("New %s", class)
	GedOpenCreateItemPopup(self, title, items, button, function(class)
		if self.window_state == "destroying" then return end
		self.app:Op("GedOpTreeNewItem", self.context, path, class, child and "child")
	end)
end

---
--- Initializes the node controls for a GedTreePanel.
---
--- @param self GedTreePanel The GedTreePanel instance.
--- @param node XTreeNode The node to initialize the controls for.
--- @param data table The data associated with the node.
---
function GedTreePanel:InitNodeControls(node, data)
	if self.DragAndDrop then
		local label = node.idLabel
		if label then
			local l, u, r, b = label:GetPadding():xyxy()
			node.idDragAndDrop = GedTreeDragAndDrop:new({
				Dock = "box",
				Margins = box(-l, -u, -r, -b),
				NodeParent = node,
			}, label)
		end
	end

	local mode = data and data.child_button_mode
	if not mode then return end
	
	if data.child_class and (mode == "docked" or mode == "docked_if_empty" and #self.idContainer:GetChildNodes(node) == 0) then
		local button = XTemplateSpawn("GedPropertyButton", node)
		button:SetText("Add new...")
		button:SetDock(IsKindOf(node, "XTreeNode") and "bottom")
		button:SetZOrder(IsKindOf(node, "XTreeNode") and 0 or 1)
		button:SetMargins(IsKindOf(node, "XTreeNode") and box(40, 2, 0, 2) or box(20, 2, 0, 2))
		button:SetHAlign("left")
		button.OnPress = function() CreateRealTimeThread(new_item, self, "child", data.child_name or data.child_class, node.path, button) end
		Msg("XWindowRecreated", button)
		return
	end
	
	-- create floating button that appears on rollover at the right side of items
	if node == self.idContainer then return end
	if (mode == "floating" or mode == "children") and not data.child_class then return end
	if mode == "floating_combined" and not (data.child_class or data.sibling_class) then return end
	
	local new_parent = XWindow:new({ HandleMouse = true, HAlign = "left" }, node)
	node.idLabel:SetParent(new_parent)
	
	local create_button = XTemplateSpawn("GedToolbarButtonSmall", new_parent)
	create_button:SetId("idNew")
	create_button:SetDock("right")
	create_button:SetIcon("CommonAssets/UI/Ged/new.tga")
	create_button:SetVisible(not mode:starts_with("floating"))
	create_button:SetRolloverText("New " .. (data.child_name or data.child_class))
	create_button.OnPress = function(button)
		if not self:IsThreadRunning("CreateSubItem") then
			self:CreateThread("CreateSubItem", function(self, data)
				local mode = data.child_button_mode
				if mode == "floating_combined" and data.child_class and data.sibling_class then
					local host = XActionsHost:new({}, self)
					XAction:new({
						ActionId = "AddChild",
						ActionMenubar = "menu",
						ActionTranslate = false,
						ActionName = "Add child item...",
						OnAction = function() CreateRealTimeThread(new_item, self, "child", data.child_name or data.child_class, node.path, button) end,
					}, host)
					XAction:new({
						ActionId = "AddSibling",
						ActionMenubar = "menu",
						ActionTranslate = false,
						ActionName = "Add new item below...",
						OnAction = function() CreateRealTimeThread(new_item, self, not "child", data.sibling_name or data.sibling_class, node.path, button) end,
					}, host)
					host:OpenPopupMenu("menu", terminal.GetMousePos())
				elseif (mode == "floating_combined" or mode == "floating" or mode == "children") and data.child_class then
					new_item(self, "child", data.child_name or data.child_class, node.path, button)
				elseif mode == "floating_combined" and data.sibling_class then
					new_item(self, not "child", data.sibling_name or data.sibling_class, node.path, button)
				end
			end, self, data)
		end
	end
	create_button.button_mode = mode
	
	-- A thread to make the hovered button visible; OnSetRollover doesn't work as multiple nested items get rollovered at once
	if not self:IsThreadRunning("TreeItemRollover") then
		self:CreateThread("TreeItemRollover", function(self)
			local last
			while true do
				local focus = terminal.desktop.keyboard_focus
				if not focus or not GetParentOfKind(focus, "XPopup") then
					local pt = terminal.GetMousePos()
					local rollover = GetParentOfKind(terminal.desktop.modal_window:GetMouseTarget(pt), "XTreeNode")
					if rollover ~= last then
						if last and last.idNew and last.idNew.button_mode:starts_with("floating") then last.idNew:SetVisible(false) end
						last = rollover
						if last and last.idNew and last.idNew.button_mode:starts_with("floating") then last.idNew:SetVisible(true) end
					end
				end
				Sleep(50)
			end
		end, self)
	end	
end

---
--- Called when the user expands a node in the tree panel.
---
--- @param path table The path of the node that was expanded.
---
function GedTreePanel:OnUserExpandedNode(path)
	self.connection:Send("rfnTreePanelNodeCollapsed", self.context, path, false)
	local entry = try_index(self.filtered_tree, table.unpack(path))
	if entry then entry.collapsed = false end
	local orig_entry = try_index(self:Obj(self.context.."|tree"), table.unpack(path))
	if orig_entry then orig_entry.collapsed = false end
end

---
--- Called when the user collapses a node in the tree panel.
---
--- @param path table The path of the node that was collapsed.
---
function GedTreePanel:OnUserCollapsedNode(path)
	self.connection:Send("rfnTreePanelNodeCollapsed", self.context, path, true)
	local entry = try_index(self.filtered_tree, table.unpack(path))
	if entry then entry.collapsed = true end
	local orig_entry = try_index(self:Obj(self.context.."|tree"), table.unpack(path))
	if orig_entry then orig_entry.collapsed = true end
end

---
--- Returns the current selection in the tree panel.
---
--- @return table The currently selected nodes in the tree panel.
---
function GedTreePanel:GetSelection()
	return self.idContainer:GetSelection()
end

---
--- Returns the current multi-selection in the tree panel.
---
--- @return table The currently selected nodes in the tree panel.
---
function GedTreePanel:GetMultiSelection()
	return table.pack(self:GetSelection())
end

---
--- Sets the selection in the tree panel.
---
--- @param selection table The selected nodes in the tree panel.
--- @param selected_keys table The keys of the selected nodes.
--- @param notify boolean Whether to notify listeners of the selection change.
--- @param restoring_state boolean Whether the selection is being restored from a previous state.
---
function GedTreePanel:SetSelection(selection, selected_keys, notify, restoring_state)
	if type(selection) == "table" and type(selection[1]) == "table" then
		selected_keys = selection[2]
		selection = selection[1]
	end
	if restoring_state or self.pending_update then
		self.pending_selection = { selection, selected_keys }
		self.restoring_state = restoring_state
		return
	end
	self.idContainer:SetSelection(selection, selected_keys, notify)
end

---
--- Binds the selected object(s) in the GedTreePanel.
---
--- @param selection table The selected nodes in the tree panel.
--- @param selected_keys table The keys of the selected nodes.
---
function GedTreePanel:BindSelectedObject(selection, selected_keys)
	if not selection then return end
	self.app:StoreAppState()
	for bind in string.gmatch(self.SelectionBind .. ",", reCommaList) do
		if self.MultipleSelection and selected_keys and #selected_keys > 1 then
			self.app:SelectAndBindMultiObj(bind, { self.context, unpack_params(selection, 1, #selection - 1) }, selected_keys)
		else
			self.app:SelectAndBindObj(bind, { self.context, table.unpack(selection) })
		end
	end
end

---
--- Handles the selection of nodes in the GedTreePanel.
---
--- When the selection changes, this function binds the selected object(s) and notifies listeners of the selection change.
---
--- @param selection table The selected nodes in the tree panel.
--- @param selected_keys table The keys of the selected nodes.
---
function GedTreePanel:OnSelection(selection, selected_keys)
	self:BindSelectedObject(selection, selected_keys)
	local old_selection = self.currently_selected_path or empty_table
	if not table.iequal(old_selection, selection) then
		self:OnSelectionChanged(selection)
		self.currently_selected_path = selection
		self.app:ActionsUpdated()
	end
end

---
--- Sets the selection and focuses the tree panel on the given path.
---
--- If the current selection matches the given path, this function will try to highlight the search match in child panels.
--- Otherwise, it will set the selection and focus on the tree panel, preventing issues with the focus being restored to the leftmost panel when cycling through search results.
---
--- @param path table The path of the node to select and focus on.
---
function GedTreePanel:SetSelectionAndFocus(path)
	local tree = self.idContainer
	if not tree then return end -- window destroying
	if table.iequal(tree:GetSelection() or empty_table, path) then
		self.app:TryHighlightSearchMatchInChildPanels(self)
	else
		-- focusing prevents issues with the focus restored to the leftmost panel (and selecting the wrong object) when cycling through search results
		local focus = self.desktop:GetKeyboardFocus()
		if not focus or focus.Id ~= "idSearchEdit" then
			self:SetFocus()
		end
		tree:SetSelection(path)
	end
end

---
--- Attempts to highlight the search match in the tree panel.
---
--- If there is a displayed search result, this function will try to find the node in the tree panel that matches the search result path and set the selection and focus on that node.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:TryHighlightSearchMatch()
	local match_data = self.app:GetDisplayedSearchResultData()
	if match_data then
		local match_path = match_data.path
		local max_idx, path = 0
		self.idContainer:ForEachNode(function(node)
			local text = TDevModeGetEnglishText(node:GetText())
			for idx, obj_id in ipairs(match_path) do
				if string.find(text, obj_id, 1, true) then
					max_idx = Max(max_idx, idx)
					path = node.path
				end
			end
		end)
		
		if max_idx > 0 then
			self:SetSelectionAndFocus(path)
		end
	end
end

---
--- Called when the context or view of the GedTreePanel is updated.
---
--- This function is responsible for handling various updates to the tree panel, such as rebuilding the tree, setting the selection, and handling empty tree scenarios.
---
--- @param context string The current context of the tree panel (e.g. "bookmarks").
--- @param view string The current view of the tree panel (e.g. "tree").
---
function GedTreePanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	if view == nil then
		self.idContainer:ClearSelection(false)
		self.pending_update = true
	end
	if view == "tree" then
		self:RebuildTree()
		local tree_empty = self:IsEmpty()
		if context == "bookmarks" then
			if tree_empty then
				self:Expand(false) -- collapse bookmarks panel when empty
			elseif not self.expanded then
				self:Expand(true) -- expand when adding a bookmark and panel is collapsed
			end
		end
		local first_update = self.app.first_update
		local sel = self.pending_selection or                         -- selection set before the tree data arrived
		   first_update and (tree_empty and {{}, {}} or {{1},{1}}) or -- default selection upon first editor open
		   table.pack(self.idContainer:GetSelection())                -- previous selection
		local scroll_pos = self.idScroll.Scroll
		self.idContainer:Clear() -- fills the tree control with content
		if tree_empty and self.context ~= "bookmarks" then
			self:OnSelection(empty_table) -- will bind "nothing" to child panels to empty them
			local text = XText:new({ ZOrder = 1, Margins = box(20, 2, 0, 2) }, self.idContainer)
			text:SetText(self.EmptyText)
			Msg("XWindowRecreated", text)
		else
			self.idContainer:SetSelection(sel[1], sel[2], first_update or self.pending_update and not self.restoring_state)
		end
		self.idScroll:ScrollTo(scroll_pos)
		self.pending_update = false
		self.pending_selection = false
		self.app.first_update = false
		self.restoring_state = false
		self:InitNodeControls(self.idContainer, self.filtered_tree)
		Msg("XWindowRecreated", self)
		
		if self.search_values then
			self:StartUpdateFilterThread("not_user_initiated")
		end
		self:TryHighlightSearchMatch()
	end
end

---
--- Sets whether the tree panel should only display warnings.
---
--- @param mode boolean Whether to only display warnings.
---
function GedTreePanel:SetViewWarningsOnly(mode)
	if self.view_warnings_only ~= mode then
		self.view_warnings_only = mode
		if self.idSearchEdit:GetText() ~= "" then
			self:CancelSearch()
		else
			self:UpdateFilter()
		end
	end
end

---
--- Sets whether the tree panel should only display errors.
---
--- @param mode boolean Whether to only display errors.
---
function GedTreePanel:SetViewErrorsOnly(mode)
	if self.view_errors_only ~= mode then
		self.view_errors_only = mode
		if self.idSearchEdit:GetText() ~= "" then
			self:CancelSearch()
		else
			self:UpdateFilter()
		end
	end
end

-- If it returns true - hide the item
---
--- Filters an item in the GedTreePanel based on the specified filter text and the current view mode (warnings only, errors only, or both).
---
--- @param text string The text to filter.
--- @param item_id string The ID of the item to filter.
--- @param filter_text string The filter text to use.
--- @param has_child_nodes boolean Whether the item has child nodes.
--- @return boolean Whether the item should be filtered out.
---
function GedTreePanel:FilterItem(text, item_id, filter_text, has_child_nodes)
	local msg = get_warning_msg(item_id)
	local msg_type = msg and msg[#msg]
	
	local filter = GedPanel.FilterItem(self, text, item_id, filter_text)
	local children = not has_child_nodes
	
	-- Show only warnings/errors - 4 states
	if self.view_warnings_only and not self.view_errors_only then
		return filter or children and msg_type ~= "warning" -- only warnings
	elseif not self.view_warnings_only and self.view_errors_only then
		return filter or children and msg_type ~= "error" -- only errors
	elseif self.view_warnings_only and self.view_errors_only then
		return filter or children and not msg_type -- warning or error
	else
		return filter -- everything
	end
end

---
--- Builds a tree structure from the given root node, filtering the tree based on the provided filter text.
---
--- @param root table|string The root node of the tree to build.
--- @param filter_text string The filter text to use when building the tree.
--- @return table|boolean The built tree, or false if the tree should be filtered out.
---
function GedTreePanel:BuildTree(root, filter_text)
	if not root or root.filtered then
		return false
	end
	local has_child_nodes = type(root) ~= "string" and #root > 0
	if (self.search_value_results or type(root) == "string") and self:FilterItem(root, root.id, filter_text, has_child_nodes) then
		return false
	end
	if type(root) == "string" then
		return { id = root.id, name = root }
	end
	
	local node = {
		id = root.id,
		name = root.name,
		class = root.class,
		child_button_mode = root.child_button_mode,
		child_class = root.child_class,
		child_name = root.child_name,
		sibling_class = root.sibling_class,
		sibling_name = root.sibling_name,
		rollover = root.rollover,
		collapsed = filter_text == "" and not self.view_warnings_only and not self.view_errors_only and root.collapsed
	}
	
	local visible = false
	for key, subnode in ipairs(root) do
		local child = self:BuildTree(subnode, filter_text) or false
		table.insert(node, child)
		if child then visible = true end
	end
	if visible or root.name and (self.search_value_results or not self:FilterItem(root.name, root.id, filter_text)) then
		return node
	end
end

---
--- Rebuilds the tree structure for the GedTreePanel.
---
--- This function retrieves the tree data from the context, and then builds a new tree structure based on the current filter text. The resulting tree is stored in the `filtered_tree` field of the GedTreePanel.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:RebuildTree()
	local data = self:Obj(self.context .. "|tree")
	if not data then return end
	self.filtered_tree = self:BuildTree(data, self:GetFilterText()) or empty_table
end

---
--- Focuses the first entry in the GedTreePanel's filtered tree.
---
--- If the filter text is empty, this function will set the selection to the first entry in the tree and focus the panel. If the filter text is not empty, this function will traverse the filtered tree to find the first visible entry, set the selection to that entry, and focus the panel.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:FocusFirstEntry()
	if self:GetFilterText() == "" then
		if not self:GetSelection() then
			self:SetSelection({1})
		end
		self:SetPanelFocused()
		return
	end
	
	local path = {}
	local root = self.filtered_tree
	while type(root) == "table" do
		local to_iterate = root
		root = nil
		for key, node in ipairs(to_iterate) do
			if node then
				root = node
				table.insert(path, key)
				break
			end
		end
	end
	self:SetSelection(path)
	self:SetPanelFocused()
end

---
--- Updates the filter and rebuilds the tree structure for the GedTreePanel.
---
--- This function first calls `GedTreePanel:RebuildTree()` to rebuild the tree structure based on the current filter text. It then clears the `idContainer` tree control and restores the previous selection and scroll position. Finally, it initializes the node controls for the filtered tree.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:UpdateFilter()
	self:RebuildTree()
	local sel = table.pack(self.idContainer:GetSelection())
	local scroll_pos = self.idScroll.Scroll
	self.idContainer:Clear() -- fills the tree control with content
	self.idContainer:SetSelection(sel[1], sel[2], not "notify") -- restore selection as if nothing has changed (don't notify)
	self.idScroll:ScrollTo(scroll_pos)
	self:InitNodeControls(self.idContainer, self.filtered_tree)
	Msg("XWindowRecreated", self)
end

--- Updates the text of all labels in the GedTreePanel's tree control.
---
--- This function first updates the title of the GedTreePanel using the `UpdateTitle` function and the current context. It then iterates over all the nodes in the `idContainer` tree control and sets the text of each node's `idLabel` control to the current text.
---
--- @param self GedTreePanel The GedTreePanel instance.
---
function GedTreePanel:UpdateItemTexts()
	self:UpdateTitle(self.context)
	self.idContainer:ForEachNode(function(node) node.idLabel:SetText(node.idLabel:GetText()) end)
end

---
--- Checks if the GedTreePanel is empty.
---
--- @param self GedTreePanel The GedTreePanel instance.
--- @return boolean True if the filtered_tree is not a table, false otherwise.
---
function GedTreePanel:IsEmpty()
	return type(self.filtered_tree) ~= "table"
end

if FirstLoad then
	ged_drag_target = false
	ged_drag_initatior = false
	ged_drop_target = false
	ged_drop_type = false
end
DefineClass.GedDragAndDrop = {
	__parents = { "XDragAndDropControl", },
	ForEachSelectedDragTargetChild = empty_func,
	ForEachDragTargetChild = empty_func,
	GetGedDragTarget = empty_func,
	drop_target_container_class = "XTree",
	line_thickness = 2,
}

---
--- Checks if there is a valid drag and drop operation in progress.
---
--- This function first checks if there is a valid drag target and drop target set. If either of these is missing, it returns `true` indicating an error.
---
--- It then iterates over the selected drag target children and stores them in a table. If there are no selected children, it returns `true` indicating an error.
---
--- Finally, it checks if the drop target or any of its parent windows is one of the selected drag target children. If so, it returns `true` indicating an error, as this would create a circular dependency.
---
--- @param self GedDragAndDrop The GedDragAndDrop instance.
--- @return boolean True if there is an error in the current drag and drop operation, false otherwise.
---
function GedDragAndDrop:GetDragAndDropError()
	if not ged_drag_target or not ged_drop_target then
		return true
	end
	local selected_children = {}
	self:ForEachSelectedDragTargetChild(function(selected_child, selected_children)
		selected_children[selected_child] = true
	end, selected_children)
	if not next(selected_children) then
		return true
	end
	local win = ged_drop_target
	while win and not IsKindOf(win, self.drop_target_container_class) do
		if selected_children[win] then
			return true
		end
		win = win.parent
	end
end

---
--- Handles the mouse button down event for the GedDragAndDrop control.
---
--- This function first checks if the left mouse button was pressed. If not, it returns without doing anything.
---
--- It then calls the `OnMouseButtonDown` function of the parent `XDragAndDropControl` class, and stores the result in the `res` variable.
---
--- If there is no active drag window and the mouse was pressed, it sets the control as the modal window.
---
--- Finally, it returns the result of the parent `OnMouseButtonDown` function.
---
--- @param self GedDragAndDrop The GedDragAndDrop instance.
--- @param pt Point The mouse position.
--- @param button string The mouse button that was pressed.
--- @return boolean The result of the parent `OnMouseButtonDown` function.
---
function GedDragAndDrop:OnMouseButtonDown(pt, button)
	if button ~= "L" then return end
	local res = XDragAndDropControl.OnMouseButtonDown(self, pt, button)
	if not self.drag_win and self.pt_pressed then
		self:SetModal()
	end
	return res
end

---
--- Handles the mouse button up event for the GedDragAndDrop control.
---
--- This function first checks if the control is the current modal window. If so, it sets the modal window to false.
---
--- It then calls the `OnMouseButtonUp` function of the parent `XDragAndDropControl` class and returns the result.
---
--- @param self GedDragAndDrop The GedDragAndDrop instance.
--- @param pt Point The mouse position.
--- @param button string The mouse button that was released.
--- @return boolean The result of the parent `OnMouseButtonUp` function.
---
function GedDragAndDrop:OnMouseButtonUp(pt, button)
	if self.desktop.modal_window == self then
		self:SetModal(false)
	end
	return XDragAndDropControl.OnMouseButtonUp(self, pt, button)
end

---
--- Returns the appropriate mouse cursor for the GedDragAndDrop control based on the current state.
---
--- If the control is not enabled, this function returns `nil`, indicating that the default cursor should be used.
---
--- If the control is currently dragging a window, this function returns one of two possible cursor images:
--- - If there is a drag and drop error, it returns the "CommonAssets/UI/ErrorCursor.tga" image.
--- - Otherwise, it returns the "CommonAssets/UI/HandCursor.tga" image.
---
--- @param self GedDragAndDrop The GedDragAndDrop instance.
--- @return string|nil The path to the cursor image to use, or `nil` if the default cursor should be used.
---
function GedDragAndDrop:GetMouseCursor()
	if not self.enabled then return end
	if self.drag_win then
		if self:GetDragAndDropError() then
			return "CommonAssets/UI/ErrorCursor.tga"
		else
			return "CommonAssets/UI/HandCursor.tga"
		end
	end
end

---
--- Handles the start of a drag and drop operation for the GedDragAndDrop control.
---
--- This function is called when the user starts a drag and drop operation on the GedDragAndDrop control. It creates a new window to display the dragged items, and adds any selected drag target children to this window. The window is then positioned at the current mouse cursor position.
---
--- @param self GedDragAndDrop The GedDragAndDrop instance.
--- @param pt Point The starting position of the drag operation.
--- @param button string The mouse button that was used to start the drag.
--- @return XWindow The window containing the dragged items.
---
function GedDragAndDrop:OnDragStart(pt, button)
	local drag_target = self:GetGedDragTarget()
	if not drag_target then return end
	ged_drag_target = drag_target
	ged_drag_initatior = self

	local drag_parent_win = XWindow:new({
		LayoutMethod = "VList",
		ZOrder = 10,
		Clip = false,
		HideOnEmpty = true,
		UseClipBox = false,
	}, self.desktop)

	self:ForEachSelectedDragTargetChild(function(child, drag_parent_win, self)
		return self:AddDragWindowText(child, drag_parent_win)
	end, drag_parent_win, self)
	
	if #drag_parent_win == 0 then
		drag_parent_win:delete()
		return
	end

	drag_parent_win:UpdateMeasure(drag_parent_win.MaxWidth, drag_parent_win.MaxHeight)
	local cursor_width = UIL.MeasureImage(GetMouseCursor())
	drag_parent_win:SetBox(pt:x() + cursor_width - 10, pt:y(), drag_parent_win.measure_width, drag_parent_win.measure_height, true)

	return drag_parent_win
end

---
--- Gets the drag window text control for the given control.
---
--- @param control any The control to get the drag window text control for.
--- @return XText|nil The drag window text control, or nil if it doesn't exist.
---
function GedDragAndDrop:GetDragWindowTextControl(control)
	return control.idLabel
end

---
--- Adds a text control to the drag window for the given control.
---
--- This function is called when adding a control to the drag window. It creates a new text control with the same text as the control's label, and adds it to the drag window.
---
--- @param control any The control to add the drag window text control for.
--- @param drag_parent_win XWindow The window containing the dragged items.
--- @return boolean Whether the drag window text control was successfully added.
---
function GedDragAndDrop:AddDragWindowText(control, drag_parent_win)
	local label_win = self:GetDragWindowTextControl(control)
	if not label_win then return end
	XText:new({
		HAlign = "left",
		VAlign = "top",
		ZOrder = 10,
		Clip = false,
		TextStyle = GetDarkModeSetting() and "GedDefaultDarkMode" or "GedDefault",
		Translate = label_win.Translate,
		HideOnEmpty = true,
		UseClipBox = false,
		Background = RGBA(89, 126, 141, 100),
	}, drag_parent_win):SetText(label_win:GetText())
end

---
--- Updates the drag window position and drop target during a drag operation.
---
--- This function is called during a drag operation to update the position of the drag window and determine the current drop target.
---
--- @param drag_win XWindow The window containing the dragged items.
--- @param pt Point The current mouse position.
---
function GedDragAndDrop:UpdateDrag(drag_win, pt)
	XDragAndDropControl.UpdateDrag(self, drag_win, pt)
	if not ged_drag_target or ged_drag_target ~= self:GetGedDragTarget() then return end
	local drop_target = false
	if ged_drag_target.box:minx() < pt:x() and ged_drag_target.box:maxx() > pt:x() then
		self:ForEachDragTargetChild(function(child, self, py)
			local drop_target_box = self:GetDropTargetBox(child)
			if drop_target_box and drop_target_box:miny() <= py and drop_target_box:maxy() > py then
				drop_target = child
				return "break"
			end
		end, self, pt:y())
	end
	if drop_target ~= ged_drop_target then
		ged_drop_target = drop_target
		UIL.Invalidate()
	end
	if ged_drop_target then
		local drop_target_box = self:GetDropTargetBox()
		if not drop_target_box then return end
		local miny, maxy = drop_target_box:miny(), drop_target_box:maxy()
		local sizey = maxy - miny
		local dy = pt:y() - miny
		local pct = dy * 100 / sizey
		local new_drop_type = self:GetDropType(pct)
		if new_drop_type ~= ged_drop_type then
			ged_drop_type = new_drop_type
			UIL.Invalidate()
		end
	end
end

---
--- Gets the bounding box of the current drop target.
---
--- @param drop_target XWindow The drop target window, or nil to use the global `ged_drop_target`.
--- @return box The bounding box of the drop target, or nil if there is no drop target.
---
function GedDragAndDrop:GetDropTargetBox(drop_target)
	drop_target = drop_target or ged_drop_target
	return drop_target and drop_target.box
end

--- Gets the drop type based on the percentage of the drop target's height.
---
--- @param pct number The percentage of the drop target's height.
--- @return string The drop type, either "Up" or "Down".
---
function GedDragAndDrop:GetDropType(pct)
	return pct < 50 and "Up" or "Down"
end

local function DrawHorizontalLine(width, pt1, pt2, color)
	local x1, y1 = pt1:xy()
	local x2, y2 = pt2:xy()
	for i = -width/2, width - width/2 - 1 do
		UIL.DrawLine(point(x1, y1 + i), point(x2, y2 + i), color)
	end
end

local highlight_color = RGB(62, 165, 165)
local highlight_color_error = RGB(197, 128, 128)
---
--- Highlights the drop target for a drag and drop operation in the GedPanel.
---
--- This function is called when a drag and drop operation is in progress. It draws a
--- visual indicator to show the current drop target and the type of drop (up or down).
---
--- @param ged_drag_initatior GedDragAndDrop The drag and drop initiator object.
--- @param ged_drop_target XWindow The current drop target window.
--- @param ged_drop_type string The type of drop, either "Up" or "Down".
---
function GedDragAndDropHighlight()
	if not ged_drag_initatior or not ged_drop_target then return end
	local color = ged_drag_initatior:GetDragAndDropError() and highlight_color_error or highlight_color
	local drop_target_box = ged_drag_initatior:GetDropTargetBox()
	local x_padding = ged_drag_initatior.line_thickness/2
	if ged_drop_type == "Up" then
		DrawHorizontalLine(ged_drag_initatior.line_thickness, point(drop_target_box:minx() - x_padding, drop_target_box:miny() + 1), point(drop_target_box:maxx() + x_padding, drop_target_box:miny() + 1), color)
	elseif ged_drop_type == "Down" then
		DrawHorizontalLine(ged_drag_initatior.line_thickness, point(drop_target_box:minx() - x_padding, drop_target_box:maxy() + 1), point(drop_target_box:maxx() + x_padding, drop_target_box:maxy() + 1), color)
	else
		UIL.DrawBorderRect(box(drop_target_box:minx() - x_padding, drop_target_box:miny() - 1 + ged_drag_initatior.line_thickness%2, drop_target_box:maxx() + x_padding, drop_target_box:maxy() + 1), ged_drag_initatior.line_thickness, ged_drag_initatior.line_thickness, color, RGBA(0, 0, 0, 0))
	end
end

function OnMsg.Start()
	if Platform.desktop then
		UIL.Register("GedDragAndDropHighlight", XDesktop.terminal_target_priority + 1)
	end
end

---
--- Handles the end of a drag and drop operation in the GedPanel.
---
--- This function is called when a drag and drop operation is completed. It cleans up the
--- state related to the drag and drop operation, such as deleting the drag window and
--- resetting the drag and drop targets.
---
--- @param drag_win XWindow The window that was being dragged.
--- @param last_target XWindow The last drop target window.
--- @param drag_res boolean The result of the drag and drop operation.
---
function GedDragAndDrop:OnDragEnded(drag_win, last_target, drag_res)
	drag_win:delete()
	ged_drag_target = false
	ged_drag_initatior = false
	ged_drop_target = false
	ged_drop_type = false
	UIL.Invalidate()
end

---
--- Gets the drop target for a drag and drop operation.
---
--- If a drop target has been set, this function returns the `idDragAndDrop` property of the drop target.
--- Otherwise, it calls the `GetDropTarget` function of the `XDragAndDropControl` class.
---
--- @param ... any Additional arguments to pass to the `XDragAndDropControl.GetDropTarget` function.
--- @return XWindow|nil The drop target window, or `nil` if no drop target is set.
---
function GedDragAndDrop:GetDropTarget(...)
	if ged_drop_target then
		return ged_drop_target.idDragAndDrop
	end
	return XDragAndDropControl.GetDropTarget(self, ...)
end

DefineClass.GedTreeDragAndDrop = {
	__parents = { "GedDragAndDrop", },
	NodeParent = false,
}

---
--- Iterates over the selected child nodes of the drag target in a GedTreePanel.
---
--- This function is used to perform an operation on each of the selected child nodes of the
--- drag target in a GedTreePanel. It retrieves the selected nodes, and then calls the
--- provided `func` function for each selected node, passing the node as an argument.
---
--- @param func function The function to call for each selected child node.
--- @param ... any Additional arguments to pass to the `func` function.
--- @return string "break" if the iteration is interrupted, otherwise `nil`.
---
function GedTreeDragAndDrop:ForEachSelectedDragTargetChild(func, ...)
	local panel = GetParentOfKind(ged_drag_target, "GedTreePanel")
	if not panel then return end
	local first_selected, selected_idxs = panel:GetSelection()
	if not first_selected then return end
	local parent = ged_drag_target:NodeByPath(first_selected, #first_selected - 1, "allow_root")
	local children = ged_drag_target:GetChildNodes(parent)
	for _, idx in ipairs(selected_idxs) do
		local selected_child = children[idx]
		if func(selected_child, ...) == "break" then
			return "break"
		end
	end
end

---
--- Gets the GedTreePanel that the GedTreeDragAndDrop instance is associated with.
---
--- @return GedTreePanel The GedTreePanel that the GedTreeDragAndDrop instance is associated with.
---
function GedTreeDragAndDrop:GetGedDragTarget()
	return self.NodeParent.tree
end

---
--- Iterates over the child nodes of the drag target in a GedTreePanel or GedListPanel.
---
--- This function is used to perform an operation on each of the child nodes of the
--- drag target in a GedTreePanel or GedListPanel. It retrieves the child nodes, and then
--- calls the provided `func` function for each child node, passing the node as an argument.
---
--- @param func function The function to call for each child node.
--- @param ... any Additional arguments to pass to the `func` function.
--- @return string "break" if the iteration is interrupted, otherwise `nil`.
---
function GedTreeDragAndDrop:ForEachDragTargetChild(func, ...)
	if not IsKindOf(ged_drag_target, self.drop_target_container_class) then return end
	return ged_drag_target:ForEachNode(func, ...)
end

---
--- Gets the bounding box of the drop target in a GedTreePanel or GedListPanel.
---
--- This function retrieves the bounding box of the drop target in a GedTreePanel or GedListPanel.
--- The drop target is either the provided `drop_target` parameter, or the global `ged_drop_target`
--- variable if no parameter is provided.
---
--- @param drop_target table|nil The drop target to get the bounding box for. If not provided, the global `ged_drop_target` variable is used.
--- @return table|nil The bounding box of the drop target, or `nil` if the drop target does not have a bounding box.
---
function GedTreeDragAndDrop:GetDropTargetBox(drop_target)
	drop_target = drop_target or ged_drop_target
	return drop_target and drop_target.idLabel and drop_target.idLabel.box
end

---
--- Determines the drop type based on the percentage of the drop target's height.
---
--- This function is used to determine the drop type (up, down, or inwards) based on the
--- percentage of the drop target's height where the drop occurred. The drop type is used
--- to determine the operation to perform when the item is dropped.
---
--- @param pct number The percentage of the drop target's height where the drop occurred.
--- @return string The drop type, which can be "Up", "Down", or "In".
---
function GedTreeDragAndDrop:GetDropType(pct)
	if pct < 20 then
		return "Up"
	elseif pct > 80 and (not ged_drop_target or #ged_drop_target.idSubtree == 0) then
		return "Down"
	else
		return "In"
	end
end

gedTreeDragAndDropOps = {
	Up   = "GedOpTreeDropItemUp",
	Down = "GedOpTreeDropItemDown",
	In   = "GedOpTreeDropItemInwards",
}
---
--- Handles the drop event for a GedTreePanel.
---
--- This function is called when an item is dropped onto a GedTreePanel. It determines the
--- appropriate drop operation based on the drop type (up, down, or inwards) and then
--- performs the operation using the GedOp system.
---
--- @param drag_win table The window that initiated the drag operation.
--- @param pt table The point where the drop occurred, in screen coordinates.
--- @param drag_source_win table The window that was the source of the drag operation.
---
function GedTreeDragAndDrop:OnDrop(drag_win, pt, drag_source_win)
	if self:GetDragAndDropError() then return end
	local panel = GetParentOfKind(ged_drop_target, "GedTreePanel")
	local op = gedTreeDragAndDropOps[ged_drop_type]
	panel.app:Op(op, panel.context, panel:GetMultiSelection(), table.copy(ged_drop_target.path))
end

DefineClass.GedListDragAndDrop = {
	__parents = { "GedDragAndDrop", },
	drop_target_container_class = "XList",
	List = false,
	Item = false,
}

---
--- Iterates over the selected children of the drag target in a GedListPanel.
---
--- This function is used to iterate over the selected children of the drag target in a
--- GedListPanel. The provided `func` function is called for each selected child, and the
--- iteration can be stopped early by returning `"break"` from the `func` function.
---
--- @param func function The function to call for each selected child. It should take the
---   selected child as the first argument, and any additional arguments passed to
---   `ForEachSelectedDragTargetChild`.
--- @param ... any Additional arguments to pass to the `func` function.
---
function GedListDragAndDrop:ForEachSelectedDragTargetChild(func, ...)
	local list = GetParentOfKind(ged_drag_target, "GedListPanel")
	if not list then return end
	local selection = ged_drag_target:GetSelection()
	for _, idx in ipairs(selection) do
		local selected_child = ged_drag_target[idx]
		if func(selected_child, ...) == "break" then
			return "break"
		end
	end
end

---
--- Returns the GedDragTarget for the GedListDragAndDrop instance.
---
--- This function returns the idContainer of the List property, which is the container
--- that holds the items being dragged in a GedListPanel.
---
--- @return table The GedDragTarget container
---
function GedListDragAndDrop:GetGedDragTarget()
	return self.List.idContainer
end

---
--- Iterates over the children of the drag target in a GedListPanel.
---
--- This function is used to iterate over the children of the drag target in a GedListPanel.
--- The provided `func` function is called for each child, and the iteration can be stopped
--- early by returning `"break"` from the `func` function.
---
--- @param func function The function to call for each child. It should take the child as the
---   first argument, and any additional arguments passed to `ForEachDragTargetChild`.
--- @param ... any Additional arguments to pass to the `func` function.
---
function GedListDragAndDrop:ForEachDragTargetChild(func, ...)
	if not IsKindOf(ged_drag_target, self.drop_target_container_class) then return end
	for _, child in ipairs(ged_drag_target) do
		if func(child, ...) == "break" then
			return "break"
		end
	end
end

gedListDragAndDropOps = {
	Up   = "GedOpListDropUp",
	Down = "GedOpListDropDown",
}
---
--- Handles the drop event for a GedListDragAndDrop instance.
---
--- This function is called when an item is dropped in a GedListPanel. It checks for any
--- errors in the drag and drop operation, and then performs the appropriate drop operation
--- based on the `ged_drop_type` value.
---
--- @param drag_win table The window that was being dragged.
--- @param pt table The position where the item was dropped.
--- @param drag_source_win table The window that was the source of the drag operation.
---
function GedListDragAndDrop:OnDrop(drag_win, pt, drag_source_win)
	if self:GetDragAndDropError() then return end
	local panel = GetParentOfKind(ged_drop_target, "GedListPanel")
	local op = gedListDragAndDropOps[ged_drop_type]
	panel.app:Op(op, panel.context, panel:GetMultiSelection(), table.find(panel.idContainer, ged_drop_target))
end

----- GedBreadcrumbPanel

DefineClass.GedBreadcrumbPanel = {
	__parents = { "GedPanel" },
	properties = {
		{ category = "General", id = "FormatFunc", editor = "text", default = "GedFormatObject", },
		{ category = "General", id = "TreePanelId", editor = "text", default = "", },
	},
	ContainerControlClass = "XWindow",
	MaxWidth = 1000000,
}

---
--- Initializes the controls for the GedBreadcrumbPanel.
---
--- This function sets the layout method of the `idContainer` to "HWrap", which causes the
--- child controls to be laid out horizontally.
---
function GedBreadcrumbPanel:InitControls()
	GedPanel.InitControls(self)
	self.idContainer.LayoutMethod = "HWrap"
end

---
--- Binds the "path" view to the `FormatFunc` function for the GedBreadcrumbPanel.
---
--- This function is responsible for setting up the view for the "path" view of the GedBreadcrumbPanel. It binds the "path" view to the `FormatFunc` function, which is likely responsible for formatting the data to be displayed in the breadcrumb panel.
---
--- @function GedBreadcrumbPanel:BindViews
function GedBreadcrumbPanel:BindViews()
	self:BindView("path", self.FormatFunc)
end

---
--- Updates the context and view for the GedBreadcrumbPanel.
---
--- This function is called when the context or view of the GedBreadcrumbPanel is updated. It
--- handles the "path" view by creating a series of buttons representing the path data, and
--- setting the text of each button to the corresponding path entry text.
---
--- @param context table The current context of the GedBreadcrumbPanel.
--- @param view string The current view of the GedBreadcrumbPanel.
---
function GedBreadcrumbPanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	if view == "path" then
		local pathdata = self:Obj(self.context .. "|path")
		self.idContainer:DeleteChildren()
		for k, entry in ipairs(pathdata) do
			local button = XButton:new({
				OnPress = function(button)
					self.app[self.TreePanelId]:SetSelection(entry.path)
				end,
				Background = RGBA(0, 0, 0, 0),
				RolloverBackground = RGBA(72, 72, 72, 255),
			}, self.idContainer)
			XText:new({}, button):SetText(entry.text)
			if k < #pathdata then
				XText:new({}, self.idContainer):SetText("<color 32 128 32> >> </color>")
			end
		end
		for _, win in ipairs(self.idContainer) do
			win:Open()
		end
		Msg("XWindowRecreated", self)
	end
end


----- GedTextPanel

DefineClass.GedTextPanel = {
	__parents = { "GedPanel", "XFontControl" },
	properties = {
		{ category = "General", id = "FormatFunc", editor = "text", default = "GedFormatObject", },
		{ category = "General", id = "Format", editor = "text", default = "", },
		{ category = "General", id = "AutoHide", editor = "bool", default = true, },
	},
	ContainerControlClass = "XText",
	MaxWidth = 1000000,
	TextStyle = "GedTextPanel",
}

LinkFontPropertiesToChild(GedTextPanel, "idContainer")

---
--- Initializes the controls for the GedTextPanel.
---
--- This function sets up the properties of the idContainer control, which is the main text display
--- area for the GedTextPanel. It disables editing, sets the border width to 0, applies the font
--- properties defined for the panel, and disables word wrapping.
---
--- @param self GedTextPanel The GedTextPanel instance.
---
function GedTextPanel:InitControls()
	GedPanel.InitControls(self)

	local text = self.idContainer
	text:SetEnabled(false)
	text:SetBorderWidth(0)
	text:SetFontProps(self)
	text:SetWordWrap(false)
end

---
--- Generates a unique view ID for the GedTextPanel instance.
---
--- The view ID is generated by concatenating the `FormatFunc` and `Format` properties of the GedTextPanel instance. This ensures that different GedTextPanels will have unique view IDs, preventing clashes.
---
--- @return string The unique view ID for the GedTextPanel instance.
---
function GedTextPanel:GetView()
	return self.FormatFunc .. "." .. self.Format -- generate unique view id, to make sure different GedTextPanels won't clash
end

---
--- Binds the views for the GedTextPanel instance.
---
--- This function sets up the view for the GedTextPanel by binding the `FormatFunc` and `Format` properties to the view ID generated by the `GetView()` function.
---
--- @param self GedTextPanel The GedTextPanel instance.
---
function GedTextPanel:BindViews()
	self:BindView(self:GetView(), self.FormatFunc, self.Format)
end

---
--- Gets the text to display for the GedTextPanel instance.
---
--- This function retrieves the text to be displayed in the GedTextPanel's text container. It does this by
--- getting the object associated with the view ID generated by the `GetView()` function, and returning
--- its text content. If no object is found, an empty string is returned.
---
--- @param self GedTextPanel The GedTextPanel instance.
--- @return string The text to display in the GedTextPanel.
---
function GedTextPanel:GetTextToDisplay()
	return self:Obj(self.context .. "|" .. self:GetView()) or ""
end

---
--- Updates the context and view for the GedTextPanel instance.
---
--- This function is called when the context or view of the GedTextPanel changes. It retrieves the text to display in the panel's text container and sets the panel's visibility based on the window state and the text content.
---
--- @param self GedTextPanel The GedTextPanel instance.
--- @param context string The current context of the GedTextPanel.
--- @param view string The current view of the GedTextPanel.
---
function GedTextPanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	
	if self.window_state == "open" then
		local text = self:GetTextToDisplay()
		self.idContainer:SetText(text)
		self:SetVisible(not self.AutoHide or text ~= "")
	end
end

DefineClass.GedMultiLinePanel = {
	__parents = { "GedTextPanel" },
	ContainerControlClass = "XMultiLineEdit",
	TextStyle = "GedMultiLine",
}

---
--- Initializes the controls for the GedMultiLinePanel instance.
---
--- This function sets up the controls for the GedMultiLinePanel by calling the `InitControls()` function of the parent `GedTextPanel` class, and then setting the `XCodeEditorPlugin` plugin on the container control.
---
--- @param self GedMultiLinePanel The GedMultiLinePanel instance.
---
function GedMultiLinePanel:InitControls()
	GedTextPanel.InitControls(self)
	self.idContainer:SetPlugins({ "XCodeEditorPlugin" })
end


----- GedObjectPanel

DefineClass.GedObjectPanel = {
	__parents = { "GedPanel" },
	properties = {
		{ category = "General", id = "FormatFunc", editor = "text", default = "GedInspectorFormatObject", },
	},
	ContainerControlClass = "XScrollArea",
	MaxWidth = 1000000,
	HorizontalScroll = true,
	Interactive = true,
}

---
--- Binds the "objectview" view to the `FormatFunc` function.
---
--- This function is responsible for binding the "objectview" view to the `FormatFunc` function, which is used to format the object being displayed in the GedObjectPanel.
---
--- @param self GedObjectPanel The GedObjectPanel instance.
---
function GedObjectPanel:BindViews()
	self:BindView("objectview", self.FormatFunc)
end

---
--- Updates the object view in the GedObjectPanel.
---
--- This function is called when the context of the GedObjectPanel is updated. It is responsible for updating the object view by deleting the existing children, creating a new title text, and then creating new child text elements for each member of the object being displayed.
---
--- The function also handles the filtering of the child elements based on the search text entered in the search bar.
---
--- @param self GedObjectPanel The GedObjectPanel instance.
--- @param context table The current context of the GedObjectPanel.
--- @param view string The current view of the GedObjectPanel.
---
function GedObjectPanel:OnContextUpdate(context, view)
	GedPanel.OnContextUpdate(self, context, view)
	if view == "objectview" then
		self.idContainer:DeleteChildren()
		
		local objectview = self:Obj(self.context .. "|objectview")
		if not objectview then return end
		
		local metatable_id = objectview.metatable_id
		local text = objectview.name .. (objectview.metatable_id and (" [ <color 128 128 216> <h OpenKey 1>" .. objectview.metatable_name .. "</h></color> ]") or "")
		local child = XText:new({
			TextStyle = self.app.dark_mode and "GedTitleDarkMode" or "GedTitle",
		}, self.idContainer)
		child:SetText(text)
		child.OnHyperLink = function(this, id, ...)
			if id == "OpenKey" then
				self.app:Op("GedOpBindObjByRefId", "root", objectview.metatable_id, terminal.IsKeyPressed(const.vkControl)) 
			end
		end
		
		local search_text = self.idSearchEdit:GetText()
		for _, v in ipairs(objectview.members) do
			local key = v.key
			local val = v.value
			local count = v.count
			local value_id = v.value_id
			local key_id = v.key_id
			
			local text = (key_id and "<color 128 128 216><h OpenKey q>" .. key .. "</h></color>" or key) .. " = " .. (value_id and "<color 128 128 216><h OpenValue 2>" .. val .. "</h></color>"  or val) .. (count and "<color 100 200 220> (#" .. count .. ")</color>" or "")
			local child = XText:new({
				TextStyle = self.app.dark_mode and "GedDefaultDarkMode" or "GedDefault",
			}, self.idContainer)
			child:SetText(text)
			child.OnHyperLink = function(this, id, ...)
				if id == "OpenKey" then
					self.app:Op("GedOpBindObjByRefId", "root", key_id, terminal.IsKeyPressed(const.vkControl)) 
				elseif id == "OpenValue" then
					self.app:Op("GedOpBindObjByRefId", "root", value_id, terminal.IsKeyPressed(const.vkControl))
				end	
			end
			
			self:UpdateChildVisible(child, search_text)
		end
		self.idContainer:ScrollTo(0, 0)
	end	
end

--- Updates the visibility of a child control based on the search text.
---
--- @param child XText The child control to update.
--- @param search_text string The search text to match against.
function GedObjectPanel:UpdateChildVisible(child, search_text)
	if search_text ~= "" and not string.find_lower(string.strip_tags(child.Text), search_text) then 
		child:SetDock("ignore")
		child:SetVisible(false)
	else
		child:SetDock(false)
		child:SetVisible(true)
	end
end

-- Called when there's a change in the search bar
--- Updates the visibility of child controls in the object panel based on the search text.
---
--- This function is called when the search text in the object panel changes. It iterates through the child controls
--- in the "idContainer" control and updates their visibility based on whether the search text is found in the
--- child's text content.
---
--- @param self GedObjectPanel The GedObjectPanel instance.
--- @param search_text string The search text to match against.
function GedObjectPanel:UpdateFilter()
	local search_text = self.idSearchEdit:GetText()
	for _, container in ipairs(self) do
		if container.Id == "idContainer" then
			for idx, child in ipairs(container) do
				if idx ~= 1 then
					self:UpdateChildVisible(child, search_text) -- hide the items that don't contain the search string and show the rest
				end
			end
		end
	end
end


----- GedGraphEditorPanel

DefineClass.GedGraphEditorPanel = {
	__parents = { "GedPanel" },
	properties = {
		{ category = "General", id = "SelectionBind", editor = "text", default = "", },
	},
	
	ContainerControlClass = "XGraphEditor",
}

--- Initializes the controls for the GedGraphEditorPanel.
---
--- This function is called to set up the controls for the GedGraphEditorPanel. It binds the graph editor control to the
--- "GedGetGraphData" function, sets the graph editor to read-only mode, and sets up event handlers for when the graph is
--- edited and when a node is selected.
---
--- The `NodeClassItems` property of the graph editor is also set to the `g_GedApp.ContainerGraphItems` table.
---
--- @param self GedGraphEditorPanel The GedGraphEditorPanel instance.
function GedGraphEditorPanel:InitControls()
	GedPanel.InitControls(self)
	
	local graph = self.idContainer
	graph:SetReadOnly(true)
	graph.OnGraphEdited = function()
		self:Op("GedSetGraphData", "SelectedPreset", self.idContainer:GetGraphData())
	end
	graph.OnNodeSelected = function(graph, node)
		for bind_name in string.gmatch(self.SelectionBind .. ",", reCommaList) do
			self:Send("GedBindGraphNode", "SelectedPreset", node.handle, bind_name)
		end
	end
	graph.NodeClassItems = g_GedApp.ContainerGraphItems
end

--- Binds the graph editor view to the "GedGetGraphData" function.
---
--- This function is called to bind the graph editor view to the "GedGetGraphData" function. It ensures that the graph editor
--- is properly set up and configured to display the graph data.
---
--- @param self GedGraphEditorPanel The GedGraphEditorPanel instance.
function GedGraphEditorPanel:BindViews()
	if not self.context then return end
	self:BindView("graph", "GedGetGraphData")
end

--- Updates the graph editor view when the context changes.
---
--- This function is called when the context of the GedGraphEditorPanel changes. It updates the graph editor view to display
--- the graph data associated with the current context. If the current context has no graph data, the graph editor is set to
--- read-only mode.
---
--- @param self GedGraphEditorPanel The GedGraphEditorPanel instance.
--- @param context string The current context.
--- @param view string The current view.
function GedGraphEditorPanel:OnContextUpdate(context, view)
	if view == "graph" then
		local data = self:Obj(context .. "|graph") -- will be nil if a non-preset is selected
		self.idContainer:SetGraphData(data)
		self.idContainer:SetReadOnly(not data)
	end
	GedPanelBase.OnContextUpdate(self, context, view)
end


----- XPanelSizer

DefineClass.XPanelSizer = 
{
	__parents = { "XControl" },
	
	properties = {
		{ category = "Visual", id = "Cursor", editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize03.tga" },
		{ category = "Visual", id = "BorderSize", editor = "number", default = 3, },
	},
	is_horizontal = true,
	drag_start_mouse_pos = false, 
	drag_start_panel1_max_sizes = false,
	drag_start_panel2_max_sizes = false,
	
	panel1 = false, 
	panel2 = false,
	valid = true,
}

---
--- Opens the XPanelSizer and initializes its state.
---
--- This function is called to open the XPanelSizer and set up its initial state. It determines the layout method of the parent panel, sets the size limits of the XPanelSizer, and finds the two adjacent panels that the XPanelSizer will be used to resize.
---
--- @param self XPanelSizer The XPanelSizer instance.
--- @param ... Any additional arguments passed to the Open function.
function XPanelSizer:Open(...)
	local layout_method = self.parent.LayoutMethod
	assert(layout_method == "HPanel" or layout_method == "VPanel")
	self.is_horizontal = layout_method == "HPanel"

	if self.is_horizontal then
		self:SetMaxWidth(self.BorderSize)
		self:SetMinWidth(self.BorderSize)
	else
		self:SetMaxHeight(self.BorderSize)
		self:SetMinHeight(self.BorderSize)
	end
	
	if not self.panel1 or not self.panel2 then
		local current_index = table.find(self.parent, self)
		assert(current_index)
		if current_index then 
			for i = current_index - 1, 1, -1 do
				if not self.parent[i].Dock then
					assert(not IsKindOf(self.parent[i], "XPanelSizer"))
					self.panel1 = self.parent[i]
					break
				end
			end
			for i = current_index + 1, #self.parent do
				if not self.parent[i].Dock then
					assert(not IsKindOf(self.parent[i], "XPanelSizer"))
					self.panel2 = self.parent[i]
					break
				end
			end
		end
		if not self.panel1 or not self.panel2 then 
			self.valid = false 
		end
	end
end

---
--- Handles the mouse button down event for the XPanelSizer.
---
--- This function is called when the user presses the left mouse button on the XPanelSizer. It sets the XPanelSizer as the mouse capture, stores the initial mouse position and the initial max sizes of the adjacent panels. This information is used later when the user drags the XPanelSizer to resize the adjacent panels.
---
--- @param self XPanelSizer The XPanelSizer instance.
--- @param pos point The initial mouse position when the button was pressed.
--- @param button string The mouse button that was pressed ("L" for left).
--- @return string "break" to indicate the event has been handled.
function XPanelSizer:OnMouseButtonDown(pos, button)
	if not self.valid then return "break" end
	if button == "L" then
		self:SetFocus()
		self.desktop:SetMouseCapture(self)		
		self.drag_start_mouse_pos = pos
		self.drag_start_panel1_max_size = point(self.panel1.MaxWidth, self.panel1.MaxHeight)
		self.drag_start_panel2_max_size = point(self.panel2.MaxWidth, self.panel2.MaxHeight)
	end
	return "break"
end

---
--- Handles the mouse position event for the XPanelSizer.
---
--- This function is called when the user moves the mouse while the XPanelSizer has mouse capture. It updates the size of the adjacent panels based on the mouse movement.
---
--- @param self XPanelSizer The XPanelSizer instance.
--- @param new_pos point The new mouse position.
--- @return string "break" to indicate the event has been handled.
function XPanelSizer:OnMousePos(new_pos)
	if self.valid and self.desktop:GetMouseCapture() == self then
		self:MovePanel(new_pos)
	end
	return "break"
end

local MulDivRoundPoint = MulDivRoundPoint

local function ElementwiseMax(min_value, point2)
	return point(Max(min_value, point2:x()), Max(min_value, point2:y()))
end

---
--- Moves the adjacent panels based on the mouse position change.
---
--- This function is called when the user drags the XPanelSizer to resize the adjacent panels. It calculates the new maximum sizes for the panels based on the mouse movement and updates the panels accordingly.
---
--- @param self XPanelSizer The XPanelSizer instance.
--- @param new_pos point The new mouse position.
function XPanelSizer:MovePanel(new_pos)
	local old_pos = self.drag_start_mouse_pos
	local diff = new_pos - old_pos
	
	-- code is analogous to HPanel/VPanel's measure and layout methods
	local total_size = point(0, 0)
	local min_sizes = point(0, 0)
	local total_items = 0
	local panel_pixel_sizes = point(0, 0)
	for _, win in ipairs(self.parent) do
		if not win.Dock and not IsKindOf(win, "XPanelSizer") then
			local min_width, min_height, max_width, max_height = ScaleXY(win.scale, win.MinWidth, win.MinHeight, win.MaxWidth, win.MaxHeight)
			total_size = total_size + point(max_width, max_height)
			min_sizes = min_sizes + point(min_width, min_height)
			total_items = total_items + 1
			panel_pixel_sizes = panel_pixel_sizes + win.box:size()
		end
	end
	if self.is_horizontal then
		assert(total_size:x() >= 100000, "MaxWidths of HPanel's children should be > 1000000")
	else
		assert(total_size:y() >= 100000, "MaxHeights of VPanel's children should be > 1000000")
	end
	
	local pixels_to_distribute = panel_pixel_sizes - min_sizes
	if pixels_to_distribute:x() == 0 or pixels_to_distribute:y() == 0 then return end
	local pixels_to_max_space_units = MulDivRoundPoint(total_size - min_sizes, 1000, pixels_to_distribute)
	
	local prop_diff = MulDivRoundPoint(diff, pixels_to_max_space_units, 1000)
	local min_diff = MulDivRoundPoint(self.panel1.scale,
						- ElementwiseMax(0, self.drag_start_panel1_max_size - point(self.panel1.MinWidth, self.panel1.MinHeight)), 1000)
	local max_diff = MulDivRoundPoint(self.panel2.scale,
						ElementwiseMax(0, self.drag_start_panel2_max_size - point(self.panel2.MinWidth, self.panel2.MinHeight)), 1000)
	prop_diff = ClampPoint(prop_diff, box(min_diff, max_diff))
	
	local panel1_new_max_size = self.drag_start_panel1_max_size + MulDivRoundPoint(prop_diff, 1000, self.panel1.scale)
	local panel2_new_max_size = self.drag_start_panel2_max_size - MulDivRoundPoint(prop_diff, 1000, self.panel2.scale)
	
	if self.is_horizontal then
		self.panel1.MaxWidth = panel1_new_max_size:x()
		self.panel2.MaxWidth = panel2_new_max_size:x()
	else
		self.panel1.MaxHeight = panel1_new_max_size:y()
		self.panel2.MaxHeight = panel2_new_max_size:y()
	end
	
	self.panel1:InvalidateMeasure()
	self.panel2:InvalidateMeasure()
	self.parent:InvalidateLayout()
	self.parent:UpdateLayout()
end

--- Returns the mouse target and cursor for the XPanelSizer.
---
--- This function is called to determine the mouse target and cursor when the mouse is over the XPanelSizer.
---
--- @param pos The current mouse position.
--- @return The XPanelSizer instance and the cursor to use.
function XPanelSizer:GetMouseTarget(pos)
	return self, self.Cursor
end

--- Handles the mouse button up event for the XPanelSizer.
---
--- This function is called when the mouse button is released while the XPanelSizer has mouse capture. It releases the mouse capture and updates the XPanelSizer's internal state.
---
--- @param pos The current mouse position.
--- @param button The mouse button that was released.
--- @return "break" to indicate the event has been handled.
function XPanelSizer:OnMouseButtonUp(pos, button)
	if self.valid and self.desktop:GetMouseCapture() == self and button == "L" then
		self:OnMousePos(pos)
		self.desktop:SetMouseCapture()
	
		self.drag_start_mouse_pos = false
	end
	return "break"
end
