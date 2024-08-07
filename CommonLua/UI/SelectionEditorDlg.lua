local min_scale = 80
local max_scale = 120
local btn_percents = { 5, 10, 25, 33, 50,75, 90, 100 }

DefineClass.SelectionEditorDlg = {
	__parents = { "XDialog" },
	last_selection = false,
	last_viewed_idx = 0,
}

--- Initializes the SelectionEditorDlg class.
-- This function is called to set up the initial state of the SelectionEditorDlg instance.
-- It retrieves the current editor selection, sets the sort order to "number", disables counting all objects,
-- and enables selecting only permanent objects.
function SelectionEditorDlg:Init()
	self.editor_selection = editor.GetSel()
	self.sort_by = "number"
	self.count_all = false
	self.select_only_permanents = true
end	

--- Saves the current state of the selection editor dialog sections.
-- This function is called when the dialog is closed to persist the visibility state of the various sections
-- (selection, view, randomize) as well as the scroll position of the randomize slider.
-- The saved state is stored in the LocalStorage.editor.SelectionEditor table.
function SelectionEditorDlg:Done()
	self:SaveSectionsState()
end

---
--- Opens the SelectionEditorDlg and initializes its controls, list, and colorization.
--- Loads the saved sections state, sets the focus on the filter text input, and starts a thread to periodically check the editor selection cache.
--- Finally, it updates the dialog and opens it.
---
--- @param ... any additional arguments passed to the XDialog:Open() function
---
function SelectionEditorDlg:Open(...)
	self:InitControls()
	self:InitList()
	self:InitColorize()
	
	self.idScaleMin:SetNumber(min_scale)
	self.idScaleMax:SetNumber(max_scale)
	
	for _, v in ipairs(btn_percents) do
		local str_perc = self["idPercent" .. v]
		if str_perc then
			str_perc.OnPress = function()
				self:SelectPerc(v)
			end
		end
	end	
	
	-- close sections
	self:LoadSectionsState()
	
	self.idFilterText:SetFocus()

	self:CreateThread("update_thread",function ()
		while true do
			self:CheckEditorSelectionCache()
			Sleep(1000)
		end
	end)

	self:Update(true)
	XDialog.Open(self,...)
end

---
--- Checks the editor's selection cache and updates the UI if the selection has changed.
---
--- This function is called periodically to check if the editor's selection has changed since the last check.
--- If the selection has changed, the function updates the `editor_selection` table and calls `self:Update(true)` to update the UI.
---
--- @return nil
function SelectionEditorDlg:CheckEditorSelectionCache()
	local sel = editor.GetSel()
	if #sel > 0 and (#self.editor_selection ~= #sel or #table.subtraction(self.editor_selection, sel) > 0) then
		self.editor_selection = sel
		self:Update(true)
	end
end

---
--- Saves the current state of the selection editor UI sections to local storage.
---
--- The function saves the visibility and docking state of the various UI sections, as well as the values of the color and scale sliders.
--- The saved state is stored in the `LocalStorage.editor.SelectionEditor` table, which is then saved to disk using the `SaveLocalStorage()` function.
---
--- @return nil
function SelectionEditorDlg:SaveSectionsState()
	LocalStorage.editor = LocalStorage.editor or {}
	LocalStorage.editor.SelectionEditor = {
		selection = self:ResolveId("idButtons"):GetVisible(),
		view = self:ResolveId("idButtons1"):GetVisible(),
		randomize = self:ResolveId("idButtons2"):GetVisible(),
		rmin = self.idRMinSlider:GetScroll(),
		rmax = self.idRMaxSlider:GetScroll(),
		gmin = self.idGMinSlider:GetScroll(),
		gmax = self.idGMaxSlider:GetScroll(),
		bmin = self.idBMinSlider:GetScroll(),
		bmax = self.idBMaxSlider:GetScroll(),
		scale_min = self.idScaleMin.idEdit:GetText(),
		scale_max = self.idScaleMax.idEdit:GetText(),
	}
	SaveLocalStorage()
end

---
--- Loads the saved state of the selection editor UI sections from local storage.
---
--- This function is called to restore the visibility and docking state of the various UI sections, as well as the values of the color and scale sliders, from the previously saved state.
---
--- The saved state is retrieved from the `LocalStorage.editor.SelectionEditor` table and applied to the corresponding UI elements.
---
--- @return nil
function SelectionEditorDlg:LoadSectionsState()
	local states = LocalStorage.editor and LocalStorage.editor.SelectionEditor or empty_table
	
	local buttons = self:ResolveId("idButtons")	
	local state = states.selection or false
	buttons:SetVisible(state)
	buttons:SetDock(state and "bottom" or "ignore")
	
	buttons = self:ResolveId("idButtons1")
	state = states.view or false
	buttons:SetVisible(state)
	buttons:SetDock(state and "bottom" or "ignore")
	
	buttons = self:ResolveId("idButtons2")
	state = states.randomize or false
	buttons:SetVisible(state)
	buttons:SetDock(state and "bottom" or "ignore")
	
	if states.rmin then
		self.idRMinSlider:SetScroll(states.rmin) self.idRMin:SetText(tostring(states.rmin))
		self.idRMaxSlider:SetScroll(states.rmax) self.idRMax:SetText(tostring(states.rmax))
		self.idGMinSlider:SetScroll(states.gmin) self.idGMin:SetText(tostring(states.gmin))
		self.idGMaxSlider:SetScroll(states.gmax) self.idGMax:SetText(tostring(states.gmax))
		self.idBMinSlider:SetScroll(states.bmin) self.idBMin:SetText(tostring(states.bmin))
		self.idBMaxSlider:SetScroll(states.bmax) self.idBMax:SetText(tostring(states.bmax))
	end
	
	self.idScaleMin.idEdit:SetText(states.scale_min or "80")
	self.idScaleMax.idEdit:SetText(states.scale_max or "120")
end

---
--- Initializes the controls and event handlers for the Selection Editor dialog.
---
--- This function sets up the various UI controls and their associated event handlers for the Selection Editor dialog. It includes functionality for:
---
--- - Handling keyboard shortcuts for the stat list
--- - Handling text changes in the filter text input
--- - Setting the range for the scale min/max inputs
--- - Handling button presses for scaling, selecting all/visible objects, sorting by class/number/percent, selecting underground objects, viewing the next object, rotating objects, hiding/showing objects
--- - Handling the selection of duplicate objects
---
--- @return nil
function SelectionEditorDlg:InitControls()
	self.idStatList.OnShortcut = function(self, shortcut, ...)
		if shortcut == "Ctrl-D" then
			return -- allow this editor global shortcut to work
		end
		return XList.OnShortcut(self, shortcut, ...)
	end

	self.idFilterText.OnTextChanged = function(this, ...)
		DelayedCall(500, self.Update, self)
		return XEdit.OnTextChanged(this, ...)
	end
	
	self.idScaleMin.idEdit:SetRange(0, const.GameObjectMaxScale)
	self.idScaleMax.idEdit:SetRange(0, const.GameObjectMaxScale)
	
	self.idScale.OnPress = function()
		min_scale = self.idScaleMin:GetNumber()
		max_scale = self.idScaleMax:GetNumber()
		
		local list = self.idStatList
		if #list:GetSelection() == 0      then print("Select something from the list first") end
		if not min_scale or not max_scale then print("Specify two numbers for minimal and maximal scale") end
		
		self:ApplyToWorkingList(function(obj)
			obj:SetScaleClamped(min_scale + AsyncRand(max_scale - min_scale + 1))
		end )
	end
	self.idSelAll.OnPress = function()
		editor.ClearSel()
		table.iclear(self.editor_selection)
		self.count_all = true
		self:Update()
	end

	self.idSelVisible.OnPress = function()
		editor.ClearSel()
		editor.AddToSel(XEditorGetVisibleObjects())
	end

	self.idClassStatic.OnPress = function()
		self.sort_by = "class"
		self:Update()
		return "break"
	end

	self.idNumberStatic.OnPress = function()
		self.sort_by = "number"
		self:Update()
		return "break"
	end

	self.idPercentStatic.OnPress = function()
		self.sort_by = "number"
		self:Update()
		return "break"
	end
	self.idSelUnderground.OnPress = function()
		local objs = MapGet("map", function(o)
											local center, radius = o:GetBSphere()
											return terrain.GetHeight(center) > center:z() + radius
										end) or empty_table
		editor.ClearSel()
		editor.AddToSel(objs)
		OpenGedGameObjectEditor(objs)
		self:Update()
	end
	
	self.idViewNext.OnPress = function()
		ViewNextObject("SelectionEditorDlg", editor.GetSel())
	end

	self.idRotate.OnPress = function()
		self:ApplyToWorkingList(function(obj)
			obj:SetAngle(AsyncRand(360*60))
		end)
	end

	self.idHide.OnPress = function ()
		self:ApplyToWorkingList(function(obj)
			obj:ClearEnumFlags(const.efVisible)
		end)
	end

	self.idHideOthers.OnPress = function ()
		self:ApplyToUnselectedList(function(obj)
			obj:ClearEnumFlags(const.efVisible)
		end)
	end

	self.idShow.OnPress = function()
		local multiple, obj_to_view
		local list = self.idStatList
		local selected = list:GetSelection()[1]
		self:ApplyToWorkingList(function(obj)
			if obj:GetEnumFlags(const.efVisible) == 0 and
			   GetClassEnumFlags(obj.class, const.efVisible) then
				obj:SetEnumFlags(const.efVisible)
			end
			if selected and list[selected].class == obj.class then
				obj_to_view = not multiple and obj or false
				multiple = true
			end
		end )
		if obj_to_view then
			ViewObject(obj_to_view)
		end
	end
	
	self.idSelDuplicate.OnPress = function()
		self.count_all = false
		local duplicates = FindDuplicates()
		self:SetEditorSelection(duplicates)
	end
	
	self.idSelectOnlyPermanentCheck:SetCheck(self.select_only_permanents)
end

---
--- Initializes the color customization controls in the SelectionEditorDlg UI.
---
--- This function sets up the range sliders and text inputs for controlling the
--- minimum and maximum values of the red, green, and blue color channels.
--- It also adds event handlers to the controls to ensure that the values are
--- kept in sync and centered within the range.
---
--- Additionally, this function adds a "Colorize" button that applies a random
--- color to the selected objects in the editor, using the configured color
--- channel ranges and a selectable color property.
---
function SelectionEditorDlg:InitColorize()
	local ControlRangeLoad = function(ctrl_range_min, ctrl_range_max, ctrl_min, ctrl_max)
		ctrl_range_min:SetScroll(100)
		ctrl_range_max:SetScroll(100)
		ctrl_min:SetText("100")
		ctrl_max:SetText("100")
	end

	ControlRangeLoad(self.idRMinSlider, self.idRMaxSlider, self.idRMin, self.idRMax)
	ControlRangeLoad(self.idGMinSlider, self.idGMaxSlider, self.idGMin, self.idGMax)
	ControlRangeLoad(self.idBMinSlider, self.idBMaxSlider, self.idBMin, self.idBMax)

	local CenterRange = function(ctrl_range_min, ctrl_range_max, left)
		if left then
			ctrl_range_min:SetScroll(100)
			ctrl_range_max:SetScroll(Max(ctrl_range_max:GetScroll(), 100))
		else
			ctrl_range_min:SetScroll(Min(ctrl_range_min:GetScroll(), 100))
			ctrl_range_max:SetScroll(100)
		end
	end

	local ControlRangeImpl = function (ctrl_range_min, ctrl_range_max, ctrl_min, ctrl_max)
		ctrl_range_min.OnScrollTo = function(this, value)
			ctrl_min:SetText(tostring(value))
			if value > ctrl_range_max:GetScroll() then
				ctrl_range_max:SetScroll(value)
				ctrl_max:SetText(tostring(value))
			end
		end
		ctrl_range_max.OnScrollTo = function(this, value)
			ctrl_max:SetText(tostring(value))
			if value < ctrl_range_min:GetScroll() then
				ctrl_range_min:SetScroll(value)
				ctrl_min:SetText(tostring(value))
			end
		end
		ctrl_min.OnPress = function(this)
			CenterRange(ctrl_range_min, ctrl_range_max, true)
		end
		ctrl_max.OnPress = function(this)
			CenterRange(ctrl_range_min, ctrl_range_max, false)
		end
	end

	ControlRangeImpl(self.idRMinSlider, self.idRMaxSlider, self.idRMin, self.idRMax)
	ControlRangeImpl(self.idGMinSlider, self.idGMaxSlider, self.idGMin, self.idGMax)
	ControlRangeImpl(self.idBMinSlider, self.idBMaxSlider, self.idBMin, self.idBMax)
	
	local function RandColor(rm, rM, gm, gM, bm, bM)
		return RGB(rm + AsyncRand(rM - rm), gm + AsyncRand(gM - gm), bm + AsyncRand(bM - bm))
	end

	local ColorizeSelection = function(rm, rM, gm, gM, bm, bM, color_prop)
		color_prop = color_prop or "ColorModifier"
		self:ApplyToWorkingList(function(obj)
			local handler = "Set" .. color_prop
			if obj:HasMember(handler) then
				obj[handler](obj, RandColor(rm, rM, gm, gM, bm, bM))
			elseif obj:HasMember(color_prop) then
				obj[color_prop] = RandColor(rm, rM, gm, gM, bm, bM)
			end
		end)
	end
	
	self.ctrlColorProp:SetItems{
		{ name = "ColorModifier", id = "ColorModifier" },
		{ name = "Color1",        id = "Color1" },
		{ name = "Color2",        id = "Color2" },
		{ name = "Color3",        id = "Color3" },
	}
	self.ctrlColorProp:SetValue("ColorModifier")
	self.idColorize.OnPress = function()
		local color_prop = self.ctrlColorProp:GetValue()
		ColorizeSelection(
			self.idRMinSlider:GetScroll(), self.idRMaxSlider:GetScroll(),
			self.idGMinSlider:GetScroll(), self.idGMaxSlider:GetScroll(), 
			self.idBMinSlider:GetScroll(), self.idBMaxSlider:GetScroll(),
			color_prop)
	end
end

---
--- Initializes the list control in the SelectionEditorDlg.
--- This function sets up the behavior of the list control, including:
--- - Enabling/disabling the percent buttons based on whether there is a selection in the list
--- - Handling double-click events on list items to select 100% of the objects
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
function SelectionEditorDlg:InitList()
	local list = self.idStatList
	list.OnSelection = function(list, focused_item, selection)
		local enable = #selection > 0
		for _, v in ipairs(btn_percents) do
			local str_perc = self["idPercent"..v]
			str_perc:SetEnabled(enable)
		end
	end
	list.OnDoubleClick = function(list, idx)
		local item = list[idx]
		if item then
			self:SelectPerc(100)
		end
	end
end

---
--- Gets the list of selected objects from the list control.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @return table The list of selected objects
function SelectionEditorDlg:GetListSelectionObjects()
	local list = self.idStatList
	local sel = list:GetSelection()
	local classes, objs = {}, {}
	for _, v in ipairs(sel) do
		local cls = list[v].idClass:GetText()
		classes[cls] = true
	end
	
	self:CheckEditorSelectionCache()
	
	self:CalcWorkingList(function (o)
		if classes[o.class] then
			objs[#objs + 1] = o
		end
	end)
	return objs
end

---
--- Selects a percentage of the objects in the list control.
---
--- This function takes a percentage value and removes a random subset of the selected objects in the list control
--- such that the remaining objects make up the specified percentage of the original selection.
--- The remaining objects are then selected in the editor.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @param perc number The percentage of the original selection to keep (0-100)
function SelectionEditorDlg:SelectPerc(perc)
	local objs = self:GetListSelectionObjects()
	local numb_to_remove = #objs - #objs * perc / 100
	for i = 1, numb_to_remove do
		table.remove(objs, AsyncRand(#objs)+1)
	end
	editor.ClearSel()
	editor.AddToSel(objs)
	self.editor_selection = editor.GetSel()
	
	self:Update()
end

---
--- Applies a function to the objects in the working list that are selected in the list control.
---
--- This function iterates over the objects in the working list and calls the provided function `f` for each
--- object whose class is selected in the list control.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @param f function The function to call for each selected object
function SelectionEditorDlg:ApplyToWorkingList(f)
	local list = self.idStatList
	local sel = list:GetSelection()
	local classes = {}
	for _, v in ipairs(sel) do
		local cls = list[v].idClass:GetText()
		classes[cls] = true
	end

	self:CalcWorkingList(function (o)
		if classes[o.class] then
			f(o)
		end
	end)

	self:Update()
end

---
--- Applies a function to the objects in the working list that are not selected in the list control.
---
--- This function iterates over the objects in the working list and calls the provided function `f` for each
--- object whose class is not selected in the list control.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @param f function The function to call for each unselected object
function SelectionEditorDlg:ApplyToUnselectedList(f)
	local list = self.idStatList
	local sel = list:GetSelection()
	local classes = {}
	for _, v in ipairs(sel) do
		local cls = list[v].idClass:GetText()
		classes[cls] = true
	end

	self:CalcWorkingList(function (o)
		if not classes[o.class] then
			f(o)
		end
	end)
	self:Update()
end

---
--- Sets the editor selection to the provided selection.
---
--- This function clears the current editor selection, sets the editor selection to the provided `sel` table,
--- and then updates the UI.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @param sel table The table of selected objects to set in the editor
function SelectionEditorDlg:SetEditorSelection(sel)
	editor.ClearSel()
	table.iclear(self.editor_selection)
	if sel and #sel > 0 then
		editor.AddToSel(sel)
		self.editor_selection = editor.GetSel()
	end
	self:Update()
end

---
--- Updates the selection editor dialog.
---
--- This function updates the UI of the selection editor dialog, including the list of object classes, the total
--- number of objects, and the percentage of objects per square meter. It calculates the working list of objects
--- based on the current selection and filter, and then populates the list control with the class information.
---
--- @param self SelectionEditorDlg The instance of the SelectionEditorDlg
--- @param rebuild boolean (optional) Whether to rebuild the list control
function SelectionEditorDlg:Update(rebuild)
	local list = self.idStatList
	local selection = list:GetSelection()
	local classes_selected = {}
	for _, v in ipairs(selection) do
		local cls = list[v].idClass:GetText()
		classes_selected[cls] = true
	end

	local items = {}
	local totalObjects = 0
	
	local filter = string.lower(self.idFilterText:GetText())
	local rejected_items = {}

	self:CalcWorkingList(function(v)
		if items[v.class] then
			items[v.class] = items[v.class] + 1
			totalObjects = totalObjects + 1
		elseif not rejected_items[v.class] then
			if filter ~= "" and not string.find(string.lower(v.class), filter, 1, true) then
				rejected_items[v.class] = true
			else
				items[v.class] = 1
				totalObjects = totalObjects + 1
			end
		end
	end)

	local list_items = {}
	for k, v in pairs(items) do
		table.insert(list_items, { class = k, number = v, perc = v * 10000 / totalObjects })
	end

	if self.sort_by == "class" then
		table.sort(list_items, function(i1, i2) return i1.class < i2.class end)
	else -- 'number'
		table.sort(list_items, function(i1, i2) return i1.number > i2.number end)
	end
	list:Clear()
	local selection = {}
	for i = 1, #list_items do
		local item = XTemplateSpawn("ClassesListItem",list)
		item.selectable = true
		item.idClass:SetText(list_items[i].class)
		item.idCount:SetText(tostring(list_items[i].number))
		local str_perc = ""
		local objperc = list_items[i].perc
		if objperc then
			str_perc = "100%"
			local perc = objperc/100
			if perc < 10 then
				str_perc = string.format("%d.%02d%%", perc, objperc%100)
			elseif perc < 100 then
				str_perc = string.format("%d.%d%%", perc, objperc%10)
			end
		end
		item.idPercent:SetText(str_perc)
		if 	classes_selected[list_items[i].class] then
			table.insert(selection, i)
		end
	end
	
	if #selection == 0 or rebuild then
		list:SelectAll()
	else
		list:SetSelection(selection)
	end

	local objs_per_sq_meter = totalObjects * 100 / (terrain.GetMapHeight() / guim * terrain.GetMapWidth() / guim)
	self.idTotalCount:SetText(string.format("Total %d, %d.%02d per m2", totalObjects, objs_per_sq_meter / 100, objs_per_sq_meter % 100))
end

---
--- Calculates the working list of objects for the selection editor dialog.
---
--- If the editor selection is not empty, the function iterates over the selected objects and calls the provided callback for each object that is permanent (if `select_only_permanents` is true).
---
--- If the editor selection is empty and `count_all` is true, the function uses `MapForEach` to iterate over all objects in the map and call the provided callback for each permanent object (if `select_only_permanents` is true).
---
--- @param callback function The callback function to call for each object in the working list.
function SelectionEditorDlg:CalcWorkingList(callback)
	if #self.editor_selection > 0 then
		for _, obj in ipairs(self.editor_selection) do
			if not self.select_only_permanents or obj:GetGameFlags(const.gofPermanent) ~= 0 then 
				callback(obj)
			end
		end
		return
	end

	if not self.count_all then return end
	MapForEach("map", nil, nil, self.select_only_permanents and const.gofPermanent or 0, callback)
end

---
--- Handles keyboard shortcuts for the selection editor dialog.
---
--- If the "ButtonB" or "Escape" shortcut is received, the dialog is closed.
--- If the "Delete" shortcut is received, the selected objects are deleted from the editor.
---
--- @param shortcut string The name of the keyboard shortcut that was triggered.
--- @param source string The source of the keyboard shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" to indicate the shortcut has been handled.
---
function SelectionEditorDlg:OnShortcut(shortcut, source, ...)
	if GetUIStyleGamepad() and shortcut == "ButtonB" or shortcut == "Escape" then
		self:Close()
		return "break"
	end	
	if shortcut == "Delete" then
		local objs = self:GetListSelectionObjects()
		SuspendPassEdits("XEditorDeleteSel")
		XEditorUndo:BeginOp{ objects = objs, name = string.format("Deleted %d objects", #objs) }
		editor.RemoveFromSel(objs)
		Msg("EditorCallback", "EditorCallbackDelete", objs)
		for _, obj in ipairs(objs) do obj:delete() end
		XEditorUndo:EndOp()
		ResumePassEdits("XEditorDeleteSel")
		return "break"
	end
end
