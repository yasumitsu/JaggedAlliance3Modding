if not const.SlabSizeX then return end

local offset = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ) / 2
local retrace = point(const.SlabSizeX, const.SlabSizeY, 0) / 2
local function snap_to_voxel_grid(pt)
	return SnapToVoxel(pt + offset) - retrace
end

DefineClass.XCreateGuidesTool = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		{ id = "Snapping", editor = "bool", default = true, },
		{ id = "Vertical", editor = "bool", default = true, },
		{ id = "Prg", name = "Apply Prg", editor = "choice", default = "", 
			items = function(self)
				return PresetsCombo("ExtrasGen", nil, "", function(prg)
					return prg.RequiresClass == "EditorLineGuide" and prg.RequiresGuideType == (self:GetVertical() and "Vertical" or "Horizontal")
				end)
			end,
		},
	},
	
	ToolTitle = "Create Guides",
	Description = {
		"(drag to place guide or guides)\n" ..
		"(<style GedHighlight>hold Ctrl</style> to disable snapping)",
	},
	UsesCodeRenderables = true,
	
	start_pos = false,
	guides = false,
	prg_applied = false,
	old_guides_hash = false,
}

---
--- Handles changes to the "Vertical" property of the `XCreateGuidesTool` class.
--- When the "Vertical" property is changed, the "Prg" property is set to an empty string.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged any The GED (Graphical Editor) object associated with the property.
---
function XCreateGuidesTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Vertical" then
		self:SetPrg("")
	end
end

---
--- Called when the `XCreateGuidesTool` is destroyed. If the tool was destroyed while dragging, it resumes the pass edits and creates 0 guides.
---
--- @param self XCreateGuidesTool The instance of the `XCreateGuidesTool` class.
---
function XCreateGuidesTool:Done()
	if self.start_pos then -- tool destroyed while dragging
		ResumePassEdits("XCreateGuidesTool")
		self:CreateGuides(0)
	end
end

---
--- Creates or destroys the line guides used by the `XCreateGuidesTool` class.
---
--- @param count number The number of line guides to create.
---
function XCreateGuidesTool:CreateGuides(count)
	self.guides = self.guides or {}
	
	local guides = self.guides
	if count == #guides then return end
	
	for i = 1, Max(count, #guides) do
		if i <= count and not guides[i] then
			guides[i] = EditorLineGuide:new()
			guides[i]:SetOpacity(self:GetPrg() == "" and 100 or 0)
		elseif i > count and guides[i] then
			DoneObject(guides[i])
			guides[i] = nil
		end
	end
end

---
--- Updates the line guides used by the `XCreateGuidesTool` class based on the given minimum and maximum points.
---
--- @param pt_min point The minimum point defining the guide area.
--- @param pt_max point The maximum point defining the guide area.
---
function XCreateGuidesTool:UpdateGuides(pt_min, pt_max)
	local x1, y1 = pt_min:xy()
	local x2, y2 = pt_max:xy()
	local z = Max(
		terrain.GetHeight(point(x1, y1)),
		terrain.GetHeight(point(x1, y2)),
		terrain.GetHeight(point(x2, y1)),
		terrain.GetHeight(point(x2, y2))
	)
	if x1 == x2 then
		local count = y1 == y2 and 0 or 1
		self:CreateGuides(count)
		if count == 0 then return end
		
		local pos, lookat = GetCamera()
		local dot = Dot(SetLen((lookat - pos):SetZ(0), 4096), axis_x)
		self.guides[1]:Set(point(x1, y1, z), point(x1, y2, z), dot > 0 and -axis_x or axis_x)
	elseif y1 == y2 then
		self:CreateGuides(1)
		
		local pos, lookat = GetCamera()
		local dot = Dot(SetLen((lookat - pos):SetZ(0), 4096), axis_y)
		self.guides[1]:Set(point(x1, y1, z), point(x2, y1, z), dot > 0 and -axis_y or axis_y)
	else
		self:CreateGuides(4)
		self.guides[1]:Set(point(x1, y1, z), point(x1, y2, z), -axis_x)
		self.guides[2]:Set(point(x2, y1, z), point(x2, y2, z),  axis_x)
		self.guides[3]:Set(point(x1, y1, z), point(x2, y1, z), -axis_y)
		self.guides[4]:Set(point(x1, y2, z), point(x2, y2, z),  axis_y)
	end
end

---
--- Calculates a hash value for the current set of line guides.
---
--- @return number The hash value for the current set of line guides.
---
function XCreateGuidesTool:GetGuidesHash()
	local hash = 42
	for _, guide in ipairs(self.guides or empty_table) do
		hash = xxhash(hash, guide:GetPos1(), guide:GetPos2(), guide:GetNormal())
	end
	return hash
end	

---
--- Applies the current Prg (program) to the line guides used by the `XCreateGuidesTool` class.
---
--- If the Prg has changed and the guides have changed since the last application, this function will:
--- - Create copies of the current guides
--- - Apply the Prg to the copied guides
--- - Destroy the copied guides
--- - Update the `old_guides_hash` to the current hash of the guides
--- - Set the `prg_applied` flag to true
---
--- This function is called when the user interacts with the tool to update the line guides.
---
function XCreateGuidesTool:ApplyPrg()
	local hash = self:GetGuidesHash()
	if self:GetPrg() ~= "" and hash ~= self.old_guides_hash and self.guides and #self.guides ~= 0 then
		if self.prg_applied then
			XEditorUndo:UndoRedo("undo")
		end
		
		-- create copies of the guides and apple the Prg to them (some Prgs change the guides)
		local guides = {}
		for _, guide in ipairs(self.guides) do
			local g = EditorLineGuide:new()
			g:Set(guide:GetPos1(), guide:GetPos2(), guide:GetNormal())
			guides[#guides + 1] = g
		end
		GenExtras(self:GetPrg(), guides)
		for _, guide in ipairs(guides) do
			DoneObject(guide)
		end
		
		self.old_guides_hash = hash
		self.prg_applied = true
	end
end

---
--- Handles the mouse button down event for the XCreateGuidesTool.
---
--- When the left mouse button is pressed, this function sets the starting position for the guide creation.
--- If the snapping option is enabled and the Control key is not pressed, the starting position is snapped to the nearest voxel grid point.
--- The mouse capture is set to the tool, and the pass edits are suspended to prevent other tools from interfering with the guide creation.
---
--- @param pt table The current mouse position in game coordinates.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XCreateGuidesTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.start_pos = GetTerrainCursor()
		self.snapping = self:GetSnapping() and not terminal.IsKeyPressed(const.vkControl)
		if self.snapping then
			self.start_pos = snap_to_voxel_grid(self.start_pos)
		end
		self.desktop:SetMouseCapture(self)
		SuspendPassEdits("XCreateGuidesTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

local function MinMaxPtXY(f, p1, p2)
	return point(f(p1:x(), p2:x()), f(p1:y(), p2:y()))
end

---
--- Handles the mouse position event for the XCreateGuidesTool.
---
--- When the left mouse button is pressed and the user is dragging the mouse, this function updates the position of the guide being created.
--- If the snapping option is enabled and the Control key is not pressed, the guide position is snapped to the nearest voxel grid point.
--- The function also applies any programmed changes (Prg) to the guide.
---
--- @param pt table The current mouse position in game coordinates.
--- @param button string The mouse button that is currently pressed ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
---
function XCreateGuidesTool:OnMousePos(pt, button)
	local start_pos = self.start_pos
	if start_pos then
		if self:GetVertical() then
			local eye, lookat = GetCamera()
			local cursor = ScreenToGame(pt)
			
			-- vertical plane parallel to screen
			local pt1, pt2, pt3 = start_pos, start_pos + axis_z, start_pos + SetLen(Cross(lookat - eye, axis_z), 4096)
			local intersection = IntersectRayPlane(eye, cursor, pt1, pt2, pt3)
			intersection = ProjectPointOnLine(pt1, pt2, intersection)
			intersection = self.snapping and snap_to_voxel_grid(intersection) or intersection
			if start_pos ~= intersection then
				local angle = CalcSignedAngleBetween2D(axis_x, eye - lookat)
				local axis = Rotate(axis_x, CardinalDirection(angle))
				if start_pos:Dist(intersection) > guim / 2 then
					self:CreateGuides(1)
					self.guides[1]:Set(start_pos, intersection, axis)
				end
			end
			self:ApplyPrg()
			return "break"
		end
		
		local pt_new = GetTerrainCursor()
		if self.snapping then
			pt_new = snap_to_voxel_grid(pt_new)
		else
			if abs(pt_new:x() - start_pos:x()) < guim / 2 then pt_new = pt_new:SetX(start_pos:x()) end
			if abs(pt_new:y() - start_pos:y()) < guim / 2 then pt_new = pt_new:SetY(start_pos:y()) end
		end
		local pt_min = MinMaxPtXY(Min, pt_new, start_pos)
		local pt_max = MinMaxPtXY(Max, pt_new, start_pos)
		self:UpdateGuides(pt_min, pt_max)
		self:ApplyPrg()
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

--- Handles the mouse button up event for the XCreateGuidesTool.
---
--- When the left mouse button is released, this function performs the following actions:
--- - If the `prg_applied` flag is true, it creates 0 guides.
--- - If there are more than 1 guide, it begins an undo operation, creates a collection for the guides, changes the selection to the guides, and ends the undo operation.
--- - It releases the mouse capture, clears the `start_pos`, `prg_applied`, and `guides` fields, and resumes pass edits for the "XCreateGuidesTool".
---
--- @param pt table The current mouse position in game coordinates.
--- @param button string The mouse button that is currently released ("L" for left, "R" for right, etc.).
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XCreateGuidesTool:OnMouseButtonUp(pt, button)
	local start_pos = self.start_pos
	if start_pos then
		if self.prg_applied then
			self:CreateGuides(0)
		elseif self.guides and #self.guides > 1 then
			XEditorUndo:BeginOp{ name = "Created guides" }
			local collection = Collection.Create()
			for _, obj in ipairs(self.guides) do
				obj:SetCollection(collection)
			end
			editor.ChangeSelWithUndoRedo(self.guides)
			XEditorUndo:EndOp(table.iappend(self.guides, { collection }))
		end
		
		self.desktop:SetMouseCapture()
		self.start_pos = nil
		self.prg_applied = nil
		self.guides = nil
		ResumePassEdits("XCreateGuidesTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end
