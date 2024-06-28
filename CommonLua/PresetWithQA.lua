--- Defines a preset class that includes QA information.
---
--- The `PresetWithQA` class inherits from the `Preset` class and adds a `qa_info` property that holds a `PresetQAInfo` object. This object is used to track modifications and verifications made to the preset.
---
--- The `qa_info` property is marked as `inclusive`, which means that it will be included when the preset is saved or loaded.
---
--- The `OnPreSave` function is called when the preset is about to be saved. If the preset is dirty (i.e., has been modified) and the user requested the save, the `qa_info` object is updated with a "Modified" action.
---
--- The `OnVerifiedPress` function is called when the "Just Verified!" button is pressed in the preset editor. This updates the `qa_info` object with a "Verified" action.
DefineClass.PresetWithQA = {
	__parents = { "Preset" },
	properties = {
		{ category = "Preset", id = "qa_info", name = "QA Info", editor = "nested_obj", base_class = "PresetQAInfo", inclusive = true, default = false,
		  buttons = {{name = "Just Verified!", func = "OnVerifiedPress"}},
		  no_edit = function(obj) return obj:IsKindOf("ModItem") end,
		},
	},
	EditorMenubarName = false,
}

---
--- Called when the preset is about to be saved.
---
--- If the preset has been modified and the user requested the save, this function updates the `qa_info` object with a "Modified" action.
---
--- @param user_requested boolean Whether the save was user-requested.
---
function PresetWithQA:OnPreSave(user_requested)
	if Platform.developer and user_requested and self:IsDirty() then
		self.qa_info = self.qa_info or PresetQAInfo:new()
		self.qa_info:LogAction("Modified")
		ObjModified(self)
	end
end

---
--- Called when the "Just Verified!" button is pressed in the preset editor.
---
--- This function updates the `qa_info` object with a "Verified" action.
---
--- @param parent table The parent object of the property.
--- @param prop_id string The ID of the property.
--- @param ged table The GED object associated with the property.
---
function PresetWithQA:OnVerifiedPress(parent, prop_id, ged)
	self.qa_info = self.qa_info or PresetQAInfo:new()
	self.qa_info:LogAction("Verified")
	ObjModified(self)
end

---
--- Defines a class `PresetQAInfo` that holds information about the quality assurance (QA) of a preset.
---
--- The `PresetQAInfo` class has the following properties:
---
--- - `Log`: A read-only text field that displays the full log of actions performed on the preset.
--- - `data`: A table that stores the history of actions performed on the preset, where each entry is a table with the following fields:
---   - `user`: The user who performed the action.
---   - `action`: The type of action performed (e.g. "Verified", "Modified").
---   - `time`: The timestamp of when the action was performed.
---
--- The `PresetQAInfo` class also has the following methods:
---
--- - `GetEditorView()`: Returns a formatted string that displays the most recent action performed on the preset.
--- - `GetLog()`: Returns a string that contains the full log of actions performed on the preset.
--- - `LogAction(action)`: Adds a new entry to the `data` table with the specified action, the current user, and the current timestamp. If the last entry has the same user and action (or the action is "Modified") and was made within the last 24 hours, the new entry is not added.
---
DefineClass.PresetQAInfo = {
	__parents = { "InitDone" },
	properties = {
		{ id = "Log", name = "Full Log", editor = "text", lines = 1, max_lines = 10, default = false, read_only = true, },
	},
	
	data = false, -- entries in the format { user = "Ivko", action = "Verified", time = os.time() }
	StoreAsTable = true, -- persist 'data' too
}

---
--- Returns a formatted string that displays the most recent action performed on the preset.
---
--- @return string A formatted string that displays the most recent action performed on the preset.
---
function PresetQAInfo:GetEditorView()
	if not self.data then return "[Empty]" end
	local last = self.data[#self.data]
	return T{Untranslated("[Last Entry] <action> by <user> on <timestamp>"), last, timestamp = os.date("%Y-%b-%d", last.time)}
end

---
--- Returns a string that contains the full log of actions performed on the preset.
---
--- @return string The full log of actions performed on the preset.
---
function PresetQAInfo:GetLog()
	local log = {}
	for _, entry in ipairs(self.data or empty_table) do
		log[#log + 1] = string.format("%s by %s on %s", entry.action, entry.user, os.date("%Y-%b-%d", entry.time))
	end
	return table.concat(log, "\n")
end

---
--- Adds a new entry to the `data` table with the specified action, the current user, and the current timestamp.
---
--- If the last entry has the same user and action (or the action is "Modified") and was made within the last 24 hours, the new entry is not added.
---
--- @param action string The type of action performed (e.g. "Verified", "Modified")
---
function PresetQAInfo:LogAction(action)
	local user_data = GetHGMemberByIP(LocalIPs())
	if not user_data then return end -- outside of HG network, can't get user from his local IP

	self.data = self.data or {}

	local user = user_data.id
	local time = os.time()
	local data = self.data
	local last = data[#data]
	if not (last and last.user == user and (last.action == action or action == "Modified") and time - last.time < 24 * 60 * 60) then -- 24 hours
		data[#data + 1] = { user = user, action = action, time = time }
	end
	ObjModified(self)
end
