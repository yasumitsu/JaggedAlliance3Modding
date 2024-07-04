if config.ModdingToolsInUserMode then return end

local lod_colors = {
	RGB(235,  18,  18),
	RGB( 18, 235,  18),
	RGB( 18,  18, 235),
	RGB(235, 235,  18),
	RGB(235,  18, 235),
	RGB( 18, 235, 235),
}

---
--- Moves the camera to focus on the specified LOD level of the given object.
---
--- @param obj table The object to move the camera to.
--- @param i integer The LOD level to move the camera to.
---
function MoveToLOD(obj, i)
	if not obj then
		CreateMessageBox(nil, Untranslated("Error"), Untranslated("Please select an object first"))
		return
	end
	if i < 0 or i >= (GetStateLODCount(obj, obj:GetState()) or 5) then
		return
	end
	
	if XLODTestingTool:GetMoveCamera() then
		obj:SetForcedLOD(const.InvalidLODIndex)
	else
		obj:SetForcedLOD(i)
		return
	end
	
	local lod_dist = i == 0 and
		MulDivRound(GetStateLODDistance(obj, obj:GetState(), 1),  80 * obj:GetScale(), 10000) - guim or
		MulDivRound(GetStateLODDistance(obj, obj:GetState(), i), 110 * obj:GetScale(), 10000) + guim
	local pos, lookat = GetCamera()
	local offs = lookat - pos
	pos = obj:GetVisualPos() + SetLen(pos - obj:GetVisualPos(), lod_dist)
	SetCamera(pos, pos + offs)
end

DefineClass.XLODTestingTool = {
	__parents = { "XEditorTool" },
	properties = {
		{ id = "_1", editor = "help", default = false,
			help = function(self) return "<center>" .. (self.obj and self.obj:GetEntity() or "No object selected") end,
		},
		{ id = "_2", editor = "buttons", default = false, buttons = function(self)
				local buttons = {}
				local obj = self.obj
				local lods = obj and GetStateLODCount(obj, obj and obj:GetState()) or 5
				for i = 0, lods - 1 do
					buttons[#buttons + 1] = {
						name = "LOD " .. i,
						func = function() MoveToLOD(obj, i) end,
					}
				end
				return buttons
			end
		},
		{ id = "MoveCamera", name = "Move camera", editor = "bool", default = true, persisted_setting = true, },
	},
	ToolTitle = "LOD Testing",
	Description = {
		"Select an object then use NumPad +/- to zoom in/out and observe LODs change.",
		"(use <style GedHighlight>PageUp</style>/<style GedHighlight>PageDown</style> to change current LOD)\n" ..
		"(use <style GedHighlight>Z</style> to center the object in the view)"
	},
	ActionSortKey = "6",
	ActionIcon = "CommonAssets/UI/Editor/Tools/RoomTools.tga", 
	ToolSection = "Misc",
	UsesCodeRenderables = true,

	obj = false,
	highlighed_obj = false,
	text = false,
}

--- Initializes the XLODTestingTool class.
-- This function is called when the XLODTestingTool is created.
-- It creates a thread that updates the text display with the current camera distance and LOD level of the selected object.
-- If an object is selected, it sets the object as the current object for the tool.
function XLODTestingTool:Init()
	self:CreateThread("UpdateTextThread", function()
		while true do
			local time = GetPreciseTicks()
			if self.obj then
				local cam_pos = GetCamera()
				local dist = self.obj:GetVisualDist(cam_pos)
				local lod = self.obj:GetCurrentLOD()
				local text = string.format("%dm  LOD %d", dist / guim, lod)
				if self.text.text ~= text then
					self.text:SetText(text)
					self.text:SetColor(lod_colors[lod + 1])
				end
			end
			Sleep(Max(50 - (GetPreciseTicks() - time), 1))
		end
	end)
	self:SetObj(selo())
end

---
--- Cleans up the XLODTestingTool instance.
--- This function is called when the XLODTestingTool is destroyed.
--- It sets the current object to false, removes the highlighted object, and clears the XEditorSelection.
---
function XLODTestingTool:Done()
	self:SetObj(false)
	self:Highlight(false)
	XEditorSelection = {}
end

---
--- Handles the mouse button down event for the XLODTestingTool.
--- If the left mouse button is pressed, it sets the current object for the tool to the object under the cursor.
--- Otherwise, it calls the base class's OnMouseButtonDown method.
---
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was pressed.
--- @return string "break" if the left mouse button was pressed, otherwise the result of the base class's OnMouseButtonDown method.
---
function XLODTestingTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		local obj = GetObjectAtCursor()
		if obj then
			self:SetObj(obj)
		end
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

---
--- Sets the current object for the XLODTestingTool.
--- If an object is provided, it creates a new Text object to display the object's distance and LOD level.
--- The Text object is positioned below the object's visual position.
--- The selected object is also added to the XEditorSelection, without setting the const.gofEditorSelection flag, so that the Z shortcut can still be used.
---
--- @param obj table The object to set as the current object for the tool.
---
function XLODTestingTool:SetObj(obj)
	if self.text then
		self.text:delete()
	end
	if obj then
		self.text = Text:new{ hide_in_editor = false }
		local b = obj:GetObjectBBox()
		local max = Max(b:sizex(), b:sizey(), b:sizez())
		self.text:SetPos(obj:GetVisualPos() + point(0, 0, -max / 2))
	end
	self.obj = obj
	CreateRealTimeThread(function()
		XEditorSelection = {obj} -- set as selected without setting const.gofEditorSelection, as we want the Z shortcut to work
		ObjModified(self)
	end)
end

---
--- Handles the mouse position event for the XLODTestingTool.
--- If the cursor is over an object, the object is highlighted. Otherwise, the highlight is cleared.
---
--- @param pt table The position of the mouse cursor.
---
function XLODTestingTool:OnMousePos(pt)
	self:Highlight(GetObjectAtCursor() or false)
end

---
--- Highlights the specified object in the editor.
---
--- If the specified object is different from the previously highlighted object, the previous highlight is cleared and the new object is highlighted.
---
--- @param obj table The object to highlight, or `false` to clear the highlight.
---
function XLODTestingTool:Highlight(obj)
	if obj ~= self.highlighted_obj then
		if IsValid(self.highlighted_obj) then
			self.highlighted_obj:ClearHierarchyGameFlags(const.gofEditorHighlight)
		end
		if obj then
			obj:SetHierarchyGameFlags(const.gofEditorHighlight)
		end
		self.highlighted_obj = obj
	end
end

---
--- Handles keyboard shortcuts for the XLODTestingTool.
---
--- If the "Pageup" shortcut is pressed, the current object's LOD is increased by 1.
--- If the "Pagedown" shortcut is pressed, the current object's LOD is decreased by 1.
--- Otherwise, the shortcut is passed to the parent XEditorTool class.
---
--- @param shortcut string The name of the keyboard shortcut that was pressed.
--- @param source table The source of the shortcut (e.g. the editor window).
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" if the shortcut was handled, otherwise nil.
---
function XLODTestingTool:OnShortcut(shortcut, source, ...)
	if shortcut == "Pageup" then
		MoveToLOD(self.obj, self.obj:GetCurrentLOD() + 1)
		return "break"
	elseif shortcut == "Pagedown" then
		MoveToLOD(self.obj, self.obj:GetCurrentLOD() - 1)
		return "break"
	end
	return XEditorTool.OnShortcut(self, shortcut, source, ...)
end
