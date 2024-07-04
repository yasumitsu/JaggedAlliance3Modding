DefineClass.XVertexPushBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Strength",   name = "Strength", editor = "number", default = 50, scale = "%", min = 1, max = 100, step = 1 },
		{ id = "Falloff",  default = 100, scale = "%", min = 0, max = 250, no_edit = function(self) return self:IsCursorSquare() end },
	},
	
	ToolSection = "Height",
	ToolTitle = "Vertex push",
	Description = {
		"Precisely pushes terrain up or down.",
		"(hold left button and drag)"
	},
	ActionSortKey = "13",
	ActionIcon = "CommonAssets/UI/Editor/Tools/VertexNudge.tga", 
	ActionShortcut = "Ctrl-W",
	
	mask_grid = false,
	offset = 0,
	last_mouse_pos = false,
}

--- Initializes the mask grid for the XVertexPushBrush tool.
---
--- The mask grid is used to store and manipulate the terrain height changes
--- made by the brush tool. It is initialized to the size of the terrain
--- height map.
---
--- @function XVertexPushBrush:Init
--- @return nil
function XVertexPushBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

--- Cleans up the resources used by the XVertexPushBrush tool.
---
--- This function is called when the tool is no longer needed. It clears the
--- original height grid stored by the editor and frees the memory used by
--- the mask grid.
---
--- @function XVertexPushBrush:Done
--- @return nil
function XVertexPushBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

--- Starts the drawing operation for the XVertexPushBrush tool.
---
--- This function is called when the user starts drawing with the brush tool.
--- It clears the mask grid, pauses the terrain cursor update, and begins a
--- new undo operation to track the height changes made by the brush.
---
--- @param pt Vector2 The initial mouse position when the drawing starts.
--- @return nil
function XVertexPushBrush:StartDraw(pt)
	self.mask_grid:clear()
	
	PauseTerrainCursorUpdate()	
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
end

--- Handles the mouse button down event for the XVertexPushBrush tool.
---
--- This function is called when the user presses the left mouse button while
--- using the XVertexPushBrush tool. It stores the initial mouse position and
--- resets the offset value. It then calls the parent class's OnMouseButtonDown
--- function to handle any additional logic.
---
--- @param pt Vector2 The initial mouse position when the button is pressed.
--- @param button string The mouse button that was pressed ("L" for left).
--- @return boolean True if the event was handled, false otherwise.
function XVertexPushBrush:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.last_mouse_pos = pt
		self.offset = 0
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

--- Handles the mouse button up event for the XVertexPushBrush tool.
---
--- This function is called when the user releases the left mouse button while
--- using the XVertexPushBrush tool. It resets the last mouse position and
--- the offset value. It then calls the parent class's OnMouseButtonUp
--- function to handle any additional logic.
---
--- @param pt Vector2 The final mouse position when the button is released.
--- @param button string The mouse button that was released ("L" for left).
--- @return boolean True if the event was handled, false otherwise.
function XVertexPushBrush:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.last_mouse_pos = false
		self.offset = 0
	end
	
	return XEditorBrushTool.OnMouseButtonUp(self, pt, button)
end

--- Handles the mouse position event for the XVertexPushBrush tool.
---
--- This function is called when the user moves the mouse while using the
--- XVertexPushBrush tool. It calculates the offset of the brush based on the
--- change in the mouse's y-coordinate, and then calls the parent class's
--- OnMousePos function to handle any additional logic.
---
--- @param pt Vector2 The current mouse position.
--- @param button string The mouse button that is currently pressed ("L" for left).
--- @return boolean True if the event was handled, false otherwise.
function XVertexPushBrush:OnMousePos(pt, button)
	if self.last_mouse_pos then
		self.offset = self.offset + (self.last_mouse_pos:y() - pt:y()) * (guim / const.TerrainHeightScale)
		self.last_mouse_pos = pt
	end
	XEditorBrushTool.OnMousePos(self, pt, button)
end

---
--- Draws the terrain modification using the XVertexPushBrush tool.
---
--- This function is responsible for applying the terrain modification based on the
--- current state of the XVertexPushBrush tool. It calculates the bounding box of the
--- affected area, draws the mask segment, and adds the height change to the terrain.
--- If the ClampToLevels property is enabled, it also clamps the height to the
--- configured terrain height slab levels.
---
--- @param pt1 Vector2 The starting point of the brush stroke.
--- @param pt2 Vector2 The ending point of the brush stroke.
function XVertexPushBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, self.first_pos, self.first_pos, inner_radius, outer_radius, "max", 1.0, 1.0, self:IsCursorSquare())
	editor.AddToHeight(self.mask_grid, MulDivRound(self.offset, self:GetStrength(), const.TerrainHeightScale * 100), bbox)

	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	Msg("EditorHeightChanged", false, bbox)
end

---
--- Ends the terrain modification operation using the XVertexPushBrush tool.
---
--- This function is called when the user finishes the terrain modification operation.
--- It calculates the bounding box of the affected area, sends a message to notify
--- other systems about the height change, ends the undo operation, and resumes the
--- terrain cursor update.
---
--- @param pt1 Vector2 The starting point of the brush stroke.
--- @param pt2 Vector2 The ending point of the brush stroke.
function XVertexPushBrush:EndDraw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, bbox)
	
	ResumeTerrainCursorUpdate()
	self.cursor_default_flags = XEditorBrushTool.cursor_default_flags
	self.offset = guim
end

---
--- Calculates the inner and outer radius of the cursor for the XVertexPushBrush tool.
---
--- The inner radius is calculated based on the brush size and falloff, while the outer
--- radius is simply the brush size divided by 2.
---
--- @return number inner_radius The inner radius of the cursor
--- @return number outer_radius The outer radius of the cursor
function XVertexPushBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end

---
--- Returns the height of the cursor for the XVertexPushBrush tool.
---
--- The height is calculated by multiplying the brush offset by the brush strength and
--- dividing by 100. This gives the final height value that will be applied to the terrain.
---
--- @return number The height of the cursor
function XVertexPushBrush:GetCursorHeight()
	return MulDivRound( self.offset, self:GetStrength(), 100)
end

---
--- Determines if the cursor for the XVertexPushBrush tool should be displayed as a square.
---
--- The cursor is displayed as a square if the `const.SlabSizeZ` constant is truthy and the
--- `XVertexPushBrush:GetSquareBrush()` function returns true.
---
--- @return boolean True if the cursor should be displayed as a square, false otherwise.
function XVertexPushBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

---
--- Returns the extra flags to be used for the terrain cursor.
---
--- The extra flags are determined based on the current state of the XVertexPushBrush tool.
--- If the `const.SlabSizeZ` constant is truthy and either the `SquareBrush` or `ClampToLevels`
--- properties are true, the `const.mfTerrainHeightFieldSnapped` flag is returned. Otherwise,
--- 0 is returned.
---
--- @return number The extra flags to be used for the terrain cursor.
function XVertexPushBrush:GetCursorExtraFlags()
	return const.SlabSizeZ and (self:GetSquareBrush() or self:GetClampToLevels()) and const.mfTerrainHeightFieldSnapped or 0
end

---
--- Returns the color of the cursor for the XVertexPushBrush tool.
---
--- The cursor is displayed as a green square if `IsCursorSquare()` returns true, otherwise it is displayed as a white square.
---
--- @return number The color of the cursor as an RGB value.
function XVertexPushBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end

----- Shortcuts 

---
--- Handles keyboard shortcuts for the XVertexPushBrush tool.
---
--- This function is called when a keyboard shortcut is triggered while the XVertexPushBrush tool is active.
--- It first checks if the shortcut is handled by the parent XEditorBrushTool class, and if so, returns "break" to indicate the shortcut has been handled.
--- If the shortcut is "+" or "Numpad +", it increases the brush strength by 1. If the shortcut is "-" or "Numpad -", it decreases the brush strength by 1.
---
--- @param shortcut string The name of the keyboard shortcut that was triggered.
--- @param source any The source of the keyboard shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, nil otherwise.
function XVertexPushBrush:OnShortcut(shortcut, source, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, ...) then
		return "break"
	elseif shortcut == "+" or shortcut == "Numpad +" then
		self:SetStrength(self:GetStrength() + 1)
		return "break"
	elseif shortcut == "-" or shortcut == "Numpad -" then
		self:SetStrength(self:GetStrength() - 1)
		return "break"
	end
end

-----
if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	---
 --- Returns the property metadata for the specified property ID.
 ---
 --- If the property ID is "Size" and the cursor is square, the returned metadata includes:
 --- - ID: "Size"
 --- - Name: "Size (tiles)"
 --- - Help: "1 tile = {sizex}m"
 --- - Default: `const.SlabSizeX`
 --- - Scale: `const.SlabSizeX`
 --- - Min: 0
 --- - Max: 50 * `const.SlabSizeX`
 --- - Step: `const.SlabSizeX`
 --- - Editor: "number"
 --- - Slider: true
 --- - Persisted Setting: true
 --- - Auto Select All: true
 ---
 --- For all other property IDs, the metadata is looked up in the `self.properties` table.
 ---
 --- @param prop_id string The ID of the property to get the metadata for.
 --- @return table The property metadata.
 function XVertexPushBrush:GetPropertyMetadata(prop_id)
		if prop_id == "Size" and self:IsCursorSquare() then
			local sizex = const.SlabSizeX
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = 0, max = 50 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		return table.find_value(self.properties, "id", prop_id)
	end
	
	---
 --- Returns a table of property metadata for all properties defined in the `self.properties` table.
 ---
 --- @return table A table of property metadata, where each entry is a table with the following fields:
 ---   - id: The unique identifier of the property
 ---   - name: The display name of the property
 ---   - help: A help text describing the property
 ---   - default: The default value of the property
 ---   - scale: The scale factor for the property value
 ---   - min: The minimum allowed value for the property
 ---   - max: The maximum allowed value for the property
 ---   - step: The step size for the property value
 ---   - editor: The type of editor to use for the property (e.g. "number", "string")
 ---   - slider: Whether to use a slider editor for the property
 ---   - persisted_setting: Whether the property value should be persisted as a setting
 ---   - auto_select_all: Whether to automatically select all text when editing the property
 function XVertexPushBrush:GetProperties()
     local props = {}
     for _, prop in ipairs(self.properties) do
         props[#props + 1] = self:GetPropertyMetadata(prop.id)
     end
     return props
 end
 
	
	---
 --- Called when an editor property is set.
 ---
 --- If the "SquareBrush" property is set, the size of the brush is updated.
 ---
 --- @param prop_id string The ID of the property that was set.
 --- @param old_value any The previous value of the property.
 --- @param ged any The GED (GUI Editor) object associated with the property.
 ---
 function XVertexPushBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" then
			self:SetSize(self:GetSize())
		end
	end
end
