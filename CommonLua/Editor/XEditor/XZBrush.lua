local supported_fmt = {[".tga"] = true, [".raw"] = true}
local thumb_fmt = {[".tga"] = true, [".png"] = true }
local textures_folders = {"svnAssets/Source/Editor/ZBrush"}
local thumbs_folders = {"svnAssets/Source/Editor/ZBrushThumbs"}

local function store_as_by_category(self, prop_meta) return prop_meta.id .. "_for_" .. self:GetCategory() end

DefineClass.XZBrush = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		store_as = function(self, prop_meta) -- store settings per texture
			if prop_meta.id == "BrushPattern" then
				return prop_meta.id
			else
				return prop_meta.id .. "_for_" .. self:GetBrushPattern()
			end
		end,
		{ id = "BrushHeightChange", name = "Height change",      editor = "number", default = 500*guim, min = -1000*guim, max = 1000*guim, scale = "m", slider = true, help = "Height change corresponding to the texture levels", buttons = {{name = "Invert", func = "ActionHeightChangeInvert"}} },
		{ id = "BrushZeroLevel",    name = "Texture zero level", editor = "number", default = -1,  min = -1, max = 255, slider = true, help = "The grayscale level corresponding to zero height. If negative, the top-left corner value would be used." },
		{ id = "BrushDistortAmp",   name = "Distort amplitude",  editor = "number", default = 10, min = 1, max = 30, slider = true },
		{ id = "BrushDistortFreq",  name = "Distort frequency",  editor = "number", default = 1,  min = 1, max = 10, slider = true },
		{ id = "BrushMode",         name = "Mode",               editor = "text_picker", default = "Add", items = { "Add", "Max", "Min" }, horizontal = true, store_as = false, },
		{ id = "ClampMin", name = "Min <style GedHighlight>(Ctrl-click)</style>", editor = "number", scale = "m", default = 0 },
		{ id = "ClampMax", name = "Max <style GedHighlight>(Shift-click)</style>", editor = "number", scale = "m", default = 0 },
		{ id = "BrushPattern",      name = "Pattern",            editor = "texture_picker", default = "", thumb_size = 100, items = function(self) return self:GetZBrushTexturesList() end, small_font = true },
		
		{ id = "TerrainR", name = "Terrain red",   editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		{ id = "TerrainG", name = "Terrain green", editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		{ id = "TerrainB", name = "Terrain blue",  editor = "choice", default = "", items = GetTerrainNamesCombo, no_edit = function(self) return not self.pattern_terrains_file end, },
		
		{ id = "_", editor = "buttons", buttons = {{name = "See Texture Locations", func = "OpenTextureLocationHelp"}}, default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Z Brush",
	Description = {
		"Select pattern and drag to place and size it.",
		"<style GedHighlight>hold Ctrl</style> - Move   <style GedHighlight>hold Shift</style> - Rotate  \n<style GedHighlight>hold Alt</style> - Height   <style GedHighlight>hold Space</style> - Distort"
	},
	ActionSortKey = "15",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Zbrush.tga", 
	ActionShortcut = "Ctrl-H",
	
	pattern_grid = false,
	pattern_raw = false,
	pattern_terrains_file = false,
	
	height_change = false,
	
	-- bools
	distorting = false,
	
	-- resizing
	z_resize_start = false,
	
	resize_start = false,
	last_resize_delta = false,
	
	-- angle of brush rotation in minutes
	last_rotation_delta = false,
	angle_start = false,
	angle = false, 
	
	distort_grid_x = false,
	distort_grid_y = false,
	distorting_start = false,
	
	distort_amp_xy = false,
	distort_distance = 0,
	
	initial_point_z = false,
	center_point = false,
	current_point = false,
	
	box_radius = 0,
	box_size = 0,
	old_box = false,
	
	cursor_start_pos = false, -- used with rotation (Shift)
	is_editing = false,
}

--- Initializes the XZBrush tool.
-- This function is called to set up the initial state of the XZBrush tool.
-- It initializes the distortion grid, the brush pattern, and sets the status text in the editor.
function XZBrush:Init()
	self:InitDistort()
	self:InitBrushPattern()
	XShortcutsTarget:SetStatusTextRight("ZBrush Editor")
end

---
--- Cleans up the state of the XZBrush tool when it is no longer needed.
--- This function is called to release any resources used by the XZBrush tool,
--- such as the brush pattern grid and the distortion grids. It also clears
--- the original height grid in the editor.
---
--- @function XZBrush:Done
--- @return nil
function XZBrush:Done()
	self:CancelOperation()
	
	if self.pattern_grid   then self.pattern_grid:free()   end
	if self.distort_grid_x then self.distort_grid_x:free() end
	if self.distort_grid_y then self.distort_grid_y:free() end
	
	editor.ClearOriginalHeightGrid()
end

---
--- Initializes the brush pattern for the XZBrush tool.
--- This function is called to set up the initial state of the brush pattern used by the XZBrush tool.
--- It loads the brush pattern image, creates a grid representation of the pattern, and sets the status text in the editor.
---
--- @function XZBrush:InitBrushPattern
--- @return nil
function XZBrush:InitBrushPattern()
	local brush_pattern = self:GetBrushPattern()
	local had_terrains = not not self.pattern_terrains_file
	if brush_pattern then
		local dir, name, ext = SplitPath(brush_pattern)
		XShortcutsTarget:SetStatusTextRight(name)
		
		if self.pattern_grid then
			self.pattern_grid:free()
		end
		self.pattern_raw = string.find(brush_pattern, ".raw") and true or false
		self.pattern_grid = ImageToGrids(brush_pattern, self.pattern_raw)
		self.pattern_terrains_file = dir .. name .. "_Mask.png"
		self.pattern_terrains_file = io.exists(self.pattern_terrains_file) and self.pattern_terrains_file
	end
	if had_terrains ~= not not self.pattern_terrains_file then
		ObjModified(self)
	end
end

---
--- Initializes the distortion grids used by the XZBrush tool.
--- This function creates two compute grids, one for the X distortion and one for the Y distortion,
--- and fills them with Perlin noise. The distortion grids are used to apply a distortion effect
--- to the brush pattern when painting on the terrain.
---
--- @function XZBrush:InitDistort
--- @return nil
function XZBrush:InitDistort()
	if self.distort_grid_x then self.distort_grid_x:free() end
	if self.distort_grid_y then self.distort_grid_y:free() end
	
	local dist_size = editor.ZBrushDistortSize
	self.distort_grid_x = NewComputeGrid(dist_size, dist_size, "F")
	self.distort_grid_y = NewComputeGrid(dist_size, dist_size, "F")
	
	local seed = AsyncRand()
	local noise = PerlinNoise:new()
	noise:SetMainOctave(1 + MulDivRound( editor.ZBrushParamsCount - 1, self:GetBrushDistortFreq()* 100 , 1024))
	
	noise:GetNoise(seed, self.distort_grid_x, self.distort_grid_y)
	GridNormalize(self.distort_grid_x, 0, 1)
	GridNormalize(self.distort_grid_y, 0, 1)
	
	self.distort_amp_xy = point(0, 0)
	self.distort_distance = 0
end

--- Handles changes to editor properties related to the XZBrush tool.
---
--- This function is called when certain properties of the XZBrush tool are changed in the editor.
--- It updates the brush pattern and distortion parameters based on the changes to these properties.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged any The GED object associated with the property.
function XZBrush:OnEditorSetProperty(prop_id, old_value, ged)
	local brush_pattern = false
	if prop_id == "BrushPattern" then
		self:InitBrushPattern()
	elseif prop_id == "BrushDistortFreq" then 
		self:InitDistort()
	end
end

---
--- Inverts the current brush height change value.
---
--- This function sets the brush height change value to the negative of its current value.
--- It then calls `OnEditorSetProperty` to notify the editor that the brush height change
--- property has been modified, and calls `ObjModified` to mark the object as modified.
---
--- @function XZBrush:ActionHeightChangeInvert
--- @return nil
function XZBrush:ActionHeightChangeInvert()
	self:SetBrushHeightChange(-self:GetBrushHeightChange())
	self:OnEditorSetProperty("SetBrushHeightChange")
	ObjModified(self)
end

---
--- Calculates the resize delta for the XZBrush tool.
---
--- This function calculates the delta between the current position and the start position of the resize operation.
--- If the `last_resize_delta` is not zero, it scales the `last_resize_delta` based on the distance between the current position
--- and the center point, and the distance between the start position and the center point.
--- Otherwise, it returns the difference between the current position and the start position.
---
--- @return point The resize delta.
---
function XZBrush:CalculateResizeDelta()
	if not self.resize_start then 
		return self.last_resize_delta
	end 
	if self.last_resize_delta ~= point(0, 0, 0) then 
		local dCCP = self.current_point:Dist2D(self.center_point)
		local dCLP = self.resize_start:Dist2D(self.center_point)
		return MulDivRound(self.last_resize_delta, dCCP, dCLP)
	else
		return self.current_point - self.resize_start
	end
end

---
--- Updates the parameters of the XZBrush tool based on user input.
---
--- This function is called when the user interacts with the XZBrush tool, such as by pressing keys or moving the mouse. It updates various properties of the brush based on the user's actions, including:
---
--- - Scaling the brush height change value based on mouse delta
--- - Distorting the brush based on the distance between the current mouse position and the distorting start position
--- - Rotating the brush based on the angle between the current mouse position and the start position
--- - Moving the brush center point based on the difference between the current mouse position and the previous mouse position
--- - Resizing the brush based on the difference between the current mouse position and the start position
---
--- @param screen_point point The current screen position of the mouse cursor.
---
function XZBrush:UpdateParameters(screen_point)
	local isRotating = false
	local isScalingZ = false
	local isMoving = false
	if terminal.IsKeyPressed(const.vkAlt) then
		isScalingZ = true
		SetMouseDeltaMode(true)
		self.height_change = self.height_change - MulDivRound(GetMouseDelta():y(), self:GetBrushHeightChange(), 100)
	else
		SetMouseDeltaMode(false)
	end
	
	local isDistorting = false
	if terminal.IsKeyPressed(const.vkSpace) then 
		isDistorting = true
		if not self.distorting then
			self.distorting_start = screen_point
		end
		self.distort_distance = self.distorting_start:Dist2D(screen_point)
		self.distort_amp_xy = self:GetBrushDistortAmp() * (self.distorting_start - screen_point)
	end
	self.distorting = isDistorting
	
	local ptDelta = screen_point - self.cursor_start_pos
	if terminal.IsKeyPressed(const.vkShift) then
		local absDiff = Max(abs(ptDelta:x()), abs(ptDelta:y()))
		if absDiff > 0 then
			self.angle = atan(ptDelta:y(), ptDelta:x())
			if not self.angle_start then 
				self.angle_start = self.angle
			end
		end
		isRotating = true
	else
		if self.angle_start then
			self.last_rotation_delta = self.last_rotation_delta + (self.angle - self.angle_start)
			self.angle_start = false
		end
	end
	
	local mouse_world_pos = GetTerrainCursor()
	if terminal.IsKeyPressed(const.vkControl) then 
		self.center_point = self.center_point + mouse_world_pos - self.current_point
		isMoving = true
	end
	self.current_point = mouse_world_pos
	if not isScalingZ and not isDistorting and not isRotating and not isMoving then
		-- if not all that, then we do default action - resize
		if not self.resize_start then
			self.resize_start = self.current_point
		end
	else
		if self.resize_start then
			self.last_resize_delta = self:CalculateResizeDelta()
			self.resize_start = false
		end	
	end
end

---
--- Handles mouse button down events for the XZBrush tool.
---
--- This function is called when the user presses a mouse button while the XZBrush tool is active.
--- It handles different actions based on the mouse button and modifier keys pressed:
--- - Right-click: Cancels the current operation
--- - Left-click: 
---   - With Ctrl: Sets the minimum height clamp for the brush
---   - With Shift: Sets the maximum height clamp for the brush
---   - Without modifiers: Starts a new brush operation, storing the initial state and preparing for editing
---
--- @param screen_point vec2 The screen position of the mouse cursor
--- @param button string The mouse button that was pressed ("L" for left, "R" for right)
--- @return string "break" to indicate the event has been handled
function XZBrush:OnMouseButtonDown(screen_point, button)
	if button == "R" and self.is_editing then
		self:CancelOperation()
		return "break"
	end
	if button == "L" then
		if terminal.IsKeyPressed(const.vkControl) then
			self:SetClampMin(GetTerrainCursor():z())
			ObjModified(self)
			return "break"
		end
		if terminal.IsKeyPressed(const.vkShift) then
			self:SetClampMax(GetTerrainCursor():z())
			ObjModified(self)
			return "break"
		end
	
		XEditorUndo:BeginOp{ height = true, terrain_type = not not self.pattern_terrains_file, name = "Z Brush" }
		editor.StoreOriginalHeightGrid(true)
		
		self.is_editing = true
		self.cursor_start_pos = screen_point
		
		local game_pt = GetTerrainCursor()
		self.center_point = game_pt
		self.current_point = game_pt
		self.resize_start = game_pt
		self.last_resize_delta = point30
		self.initial_point_z = game_pt:z()
		
		local w, h = terrain.HeightMapSize()
		self.height_change = self:GetBrushHeightChange() / const.TerrainHeightScale
		self.last_rotation_delta = 0
		
		self.desktop:SetMouseCapture(self)
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, screen_point, button)
end

--- Handles the mouse button up event for the XZBrush tool.
---
--- This function is called when the user releases the mouse button while using the XZBrush tool. It performs the following actions:
--- - If the tool is in editing mode (`self.is_editing` is true):
---   - Updates the brush parameters based on the current mouse position (`self:UpdateParameters(screen_point)`)
---   - Gets the bounding box of the affected terrain segment (`editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)`)
---   - Sends a "EditorHeightChanged" message with the bounding box
---   - If a terrain texture pattern file is set (`self.pattern_terrains_file`), applies the terrain textures (`self:ApplyTerrainTextures(self.pattern_terrains_file)`) and sends an "EditorTerrainTypeChanged" message with the bounding box
---   - Ends the current undo operation (`XEditorUndo:EndOp()`)
---   - Resets the editing state variables
---   - Sets the status text to the name of the current brush pattern
---   - Releases the mouse capture and unhides the mouse cursor
--- - If the tool is not in editing mode, it calls the parent class's `OnMouseButtonUp` function.
---
--- @param screen_point vec2 The screen position of the mouse cursor
--- @param button string The mouse button that was released ("L" for left, "R" for right)
--- @return string "break" to indicate the event has been handled
function XZBrush:OnMouseButtonUp(screen_point, button)
	if self.is_editing then
		self:UpdateParameters(screen_point)
		local bbox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
		Msg("EditorHeightChanged", true, bbox)
		if self.pattern_terrains_file then
			self:ApplyTerrainTextures(self.pattern_terrains_file)
			Msg("EditorTerrainTypeChanged", bbox)
		end
		XEditorUndo:EndOp()
		
		self.is_editing = false
		self.center_point = false
		self.current_point = false
		self.scalingZ = false 
		self.distorting = false
		self.angle_start = false
		self.last_rotation_delta = 0
		self.distort_amp_xy = point(0, 0)
		self.distort_distance = 0
		
		local dir, name, ext = SplitPath(self:GetBrushPattern())
		XShortcutsTarget:SetStatusTextRight(name or "ZBrush Editor")
		
		SetMouseDeltaMode(false)
		self.desktop:SetMouseCapture()
		UnforceHideMouseCursor("XEditorBrushTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, screen_point, button)
end

--- Handles the mouse position event for the XZBrush tool.
---
--- This function is called when the user moves the mouse while using the XZBrush tool. It performs the following actions:
--- - If the tool is in editing mode (`self.is_editing` is true) and a brush pattern is set (`self.pattern_grid`):
---   - If the Escape key is pressed, cancels the current operation (`self:CancelOperation()`)
---   - Updates the brush parameters based on the current mouse position (`self:UpdateParameters(screen_point)`)
---   - Calculates the rotation angle delta and the bounding box of the affected terrain segment
---   - Applies the brush pattern to the terrain using `editor.ApplyZBrushToGrid()` and updates the status text with the size, minimum height, and maximum height of the affected area
---   - Stores the current bounding box in `self.old_box`
---   - Sends an "EditorHeightChanged" message with the extended bounding box
--- - If the tool is not in editing mode, it calls the parent class's `OnMousePos` function.
---
--- @param screen_point vec2 The screen position of the mouse cursor
--- @param button string The mouse button that is currently pressed ("L" for left, "R" for right)
--- @return string "break" to indicate the event has been handled
function XZBrush:OnMousePos(screen_point, button)
	if self.is_editing and self.pattern_grid then
		if terminal.IsKeyPressed(const.vkEsc) then 
			self:CancelOperation()
			return "break"
		end 
		
		self:UpdateParameters(screen_point)	
		local angleDelta = self.last_rotation_delta + (self.angle_start and (self.angle - self.angle_start) or 0)
		local sin, cos = sincos(angleDelta)
		local ptDelta = self:CalculateResizeDelta()
		local box_size = Max(abs(ptDelta:x()), abs(ptDelta:y()))
		self.box_radius = box_size > 0 and MulDivRound(box_size, abs(sin) + abs(cos), 4096) or const.HeightTileSize / 2
		
		local bBox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
		local extended_box = AddRects(self.old_box or bBox, bBox)
		local min, max = editor.ApplyZBrushToGrid(self.pattern_grid, self.distort_grid_x, self.distort_grid_y, extended_box, self.center_point:SetZ(self.initial_point_z),
			self.distort_amp_xy, self.distort_distance, angleDelta, box_size, self.height_change, self:GetBrushZeroLevel(), self.pattern_raw,
			self:GetBrushMode(), self:GetClampMin(), self:GetClampMax())
		if max and min then
			XShortcutsTarget:SetStatusTextRight(string.format("Size %d, Min height %dm, Max height %dm", (2 * box_size) / guim, min * const.TerrainHeightScale / guim, max * const.TerrainHeightScale / guim))
		end
		self.old_box = bBox
		self.box_size = box_size
		
		Msg("EditorHeightChanged", false, extended_box)
		return "break"
	end
	XEditorTool.OnMousePos(self, screen_point, button)
end
--- Handles the keyboard key down event for the XZBrush tool.
---
--- This function is called when a keyboard key is pressed while the XZBrush tool is active. If the tool is in editing mode (`self.is_editing` is true) and the Escape key is pressed, it cancels the current operation by calling `self:CancelOperation()`. Otherwise, it calls the parent class's `OnKbdKeyDown` function.
---
--- @param key integer The key code of the pressed key
--- @param ... any Additional arguments passed to the function
--- @return string "break" to indicate the event has been handled


function XZBrush:OnKbdKeyDown(key, ...)
	if self.is_editing and key == const.vkEsc then
		self:CancelOperation()
		return "break"
	end
	XEditorTool.OnKbdKeyDown(self, key, ...)
end

--- Cancels the current operation of the XZBrush tool.
---
--- This function is called when the user wants to cancel the current operation of the XZBrush tool. It resets the terrain to its original state by setting the height of the affected area to 0 using a mask. It then calls the `OnMouseButtonUp` function to handle the end of the operation.
---
--- @return nil
function XZBrush:CancelOperation()
	if self.editing then
		local w, h = terrain.HeightMapSize()
		local mask = NewComputeGrid(w, h, "F")
		local box = editor.DrawMaskSegment(mask, self.center_point, self.center_point, self.box_radius, self.box_radius, "min")
		editor.SetHeightWithMask(0, mask, box)
		mask:clear()
		
		self:OnMouseButtonUp(self.center_point, 'L')
	end
end

--- Applies terrain textures to the terrain based on the specified filename.
---
--- This function takes a filename and applies terrain textures to the terrain based on the R, G, and B channels of the image. It uses the `editor.ApplyZBrushToGrid` function to place the terrain based on the texture, taking into account the current brush settings such as distortion, height change, and clamping.
---
--- @param filename string The filename of the texture to apply
--- @return nil
function XZBrush:ApplyTerrainTextures(filename)
	local r, g, b = ImageToGrids(filename)
	local bbox = editor.GetSegmentBoundingBox(self.center_point, self.center_point, self.box_radius, true)
	local angle = self.last_rotation_delta + (self.angle_start and (self.angle - self.angle_start) or 0)
	-- places terrain based on the texture in filename (different terrain for R, G, B channels); pattern_grid, pattern_raw are ignored
	editor.ApplyZBrushToGrid(self.pattern_grid, self.distort_grid_x, self.distort_grid_y, bbox, self.center_point:SetZ(self.initial_point_z),
		self.distort_amp_xy, self.distort_distance, angle, self.box_size, self.height_change, self:GetBrushZeroLevel(), self.pattern_raw,
		self:GetBrushMode(), self:GetClampMin(), self:GetClampMax(),
		r, g, b, self:GetTerrainR(), self:GetTerrainG(), self:GetTerrainB())
end

---
--- Opens a message box that displays the paths to the texture and thumbnail folders used by the XZBrush tool.
---
--- This function is called to provide information about the location of the texture and thumbnail files used by the XZBrush tool. It creates a message box that lists the paths to the folders containing these files.
---
--- @param self XZBrush The instance of the XZBrush tool
--- @return nil
function XZBrush:OpenTextureLocationHelp()
	local paths = { "Texture folders:" }
	for i = 1, #textures_folders do
		paths[#paths + 1] = ConvertToOSPath(textures_folders[i])
	end
	paths[#paths + 1] = "Thumb folders:"
	for i = 1, #thumbs_folders do
		paths[#paths + 1] = ConvertToOSPath(thumbs_folders[i])
	end
	CreateMessageBox(self, Untranslated("Texture Location"), Untranslated(table.concat(paths, "\n")))
end

---
--- Gets a list of available ZBrush textures.
---
--- This function searches the configured texture and thumbnail folders for available ZBrush textures, and returns a list of texture information including the file name, file path, and thumbnail image path.
---
--- @return table A table of texture information, where each entry is a table with the following fields:
---   - text (string): The display name of the texture
---   - value (string): The file path of the texture
---   - image (string): The file path of the thumbnail image for the texture
function XZBrush:GetZBrushTexturesList()
	local texture_list = {}
	for i = 1, #textures_folders do
		local textures_folder = textures_folders[i] or ""
		local thumbs_folder = thumbs_folders[i] or ""
		local err, thumbs, textures
		if thumbs_folder ~= "" then
			err, thumbs = AsyncListFiles(thumbs_folder, "*.png")
		end
		if textures_folder ~= "" then
			err, textures = AsyncListFiles(textures_folder)
		end
		
		for _, texture in ipairs(textures or empty_table) do
			local dir, name, ext = SplitPath(texture)
			if supported_fmt[ext] then
				local thumb = thumbs_folder .. "/" .. name .. ".png"
				if not table.find(thumbs or empty_table, thumb) and thumb_fmt[ext] then
					thumb = texture
				end
				texture_list[#texture_list + 1] = { text = name, value = texture, image = thumb }
			end
		end
	end
	table.sort(texture_list, function(a, b) return a.text < b.text or a.text == b.text and a.value < b.value end )
	return texture_list
end