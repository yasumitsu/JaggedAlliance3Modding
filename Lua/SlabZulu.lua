Slab.flags.efCollision = true
Slab.flags.efApplyToGrids = true

AppendClass.Slab = {
	properties = {
		{ category = "Misc", id = "Mirrored", editor = "bool", default = false, 
			no_edit = function(self)
				return not self:CanMirror() or not not self.room
			end,
			dont_save = function(self)
				return not not self.room
			end,
		},
		{ id = "MirroredSetFromEditor", default = nil, editor = "bool", no_edit = true },
		{ category = "Misc", id = "MirroredSetFromEditorVisual", editor = "bool", default = nil, 
			name = function(self)
				if self.MirroredSetFromEditor == nil then
					return "Mirrored (From Room)"
				elseif self.MirroredSetFromEditor ~= nil then
					return "Mirrored (Room Overriden)"
				end
			end,
			no_edit = function(self)
				return not self:CanMirror() or not self.room
			end,
			dont_save = true,
			read_only = function(self) return not self:CanMirror() end,
			buttons = {{ name = "Revert to Room Value", func = function(self)
				self.MirroredSetFromEditor = nil
				self:MirroringFromRoom()
			end}},
		},
	}
}

--- Returns the value of the `MirroredSetFromEditor` property.
---
--- This property is used to track whether the mirrored state of the slab has been
--- set from the editor, or if it should use the mirrored state from the room.
---
--- @return boolean|nil The value of the `MirroredSetFromEditor` property.
function Slab:GetMirroredSetFromEditor()
	return self.MirroredSetFromEditor
end

AppendClass.RoofSlab = {
	properties = {
		{ id = "MirroredSetFromEditorVisual", name = "Mirrored", default = nil},
	}
}

local original = Slab.EditorCallbackClone
--- Overrides the `EditorCallbackClone` method to reset the `MirroredSetFromEditor` property to `nil` when cloning a slab.
---
--- This ensures that the mirrored state of the cloned slab is not inherited from the original slab, and instead uses the mirrored state from the room.
function Slab:EditorCallbackClone(source)
	original(self, source)
	self.MirroredSetFromEditor = nil
end

--- Returns whether the slab should use the mirrored state from the room.
---
--- The slab will use the mirrored state from the room if the `MirroredSetFromEditor` property is `nil`, indicating that the mirrored state has not been overridden in the editor.
---
--- @return boolean Whether the slab should use the mirrored state from the room.
function Slab:ShouldUseRoomMirroring()
	return self.MirroredSetFromEditor == nil
end

--- Sets the `MirroredSetFromEditor` property and updates the mirrored state of the slab.
---
--- This function is used to set the `MirroredSetFromEditor` property, which is used to track whether the mirrored state of the slab has been set from the editor, or if it should use the mirrored state from the room.
---
--- When the `MirroredSetFromEditor` property is set, the function also updates the mirrored state of the slab using the `SetMirrored` method.
---
--- @param val boolean|nil The new value for the `MirroredSetFromEditor` property.
function Slab:SetMirroredSetFromEditor(val)
	self.MirroredSetFromEditor = val
	self:SetMirrored(val)
end

--- Sets the `MirroredSetFromEditor` property and updates the mirrored state of the slab.
---
--- This function is used to set the `MirroredSetFromEditor` property, which is used to track whether the mirrored state of the slab has been set from the editor, or if it should use the mirrored state from the room.
---
--- When the `MirroredSetFromEditor` property is set, the function also updates the mirrored state of the slab using the `SetMirrored` method.
---
--- @param val boolean|nil The new value for the `MirroredSetFromEditor` property.
function Slab:SetMirroredSetFromEditorVisual(val)
	self:SetMirroredSetFromEditor(val)
end

--- Returns whether the slab's mirrored state has been set from the editor.
---
--- This function returns a boolean value indicating whether the slab's mirrored state has been set from the editor, or if it should use the mirrored state from the room.
---
--- @return boolean Whether the slab's mirrored state has been set from the editor.
function Slab:GetMirroredSetFromEditorVisual()
	return self:GetGameFlags(const.gofMirrored) ~= 0
end

local testing_saves = false
--- Tests the mirrored state of all Slab objects in the map.
---
--- This function retrieves all Slab objects in the map and checks if their mirrored state is still present in the `testing_saves` table. Any Slab objects that are not found in the `testing_saves` table are printed to the console.
---
--- This function is likely used for testing or debugging purposes to ensure that the mirrored state of Slab objects is being properly saved and restored.
function testing_mirror_prop_on_saves()
	local res = MapGet("map", "Slab", function(o) return o:GetMirrored(); end)
	for k, v in ipairs(res) do
		res[k] = v.handle
	end
	local not_found = {}
	testing_saves = testing_saves or res
	for k, v in ipairs(testing_saves) do
		local idx = table.find(res, v)
		if not idx then
			table.insert(not_found, v)
		end
	end
	print("not found", not_found)
end