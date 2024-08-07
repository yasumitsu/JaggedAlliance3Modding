DefineClass.ModItemFolder = {
	__parents = { "ModItem" },
	properties = {
		{ category = "Mod", id = "_", default = false, editor = "help", help = "<style GedHighlight><center>Alt-Click on mod items to add them to this folder." },
	},
	EditorName = "Folder",
	EditorSubmenu = "",
	EditorView = Untranslated("<ModItemDescription> <color 75 105 198><u(comment)></color>"),
	ContainerClass = "ModItem",
	ContainerAddNewButtonMode = false,
	GedTreeChildren = function (self) return self end,
}

---
--- Iterates over all ModItem instances contained within the ModItemFolder, optionally filtering by a specific class name.
---
--- @param classname string|nil The class name to filter by, or nil to include all ModItem instances.
--- @param fn function The callback function to execute for each ModItem instance. The function should accept a single argument, which is the current ModItem instance.
--- @return any The return value of the last callback function executed, or nil if no callback function returned a non-nil value.
function ModItemFolder:ForEachModItem(classname, fn)
	if not fn then
		fn = classname
		classname = nil
	end
	
	local ret = nil
	if not classname or IsKindOf(self, classname) then ret = fn(self) end
	if ret ~= nil then return ret end
	
	for _, item in ipairs(self) do
		ret = item:ForEachModItem(classname, fn)
		if ret == "break" then
			break
		elseif ret ~= nil then
			return ret
		end
	end
end

---
--- Disallows creating new mod items (into the folder) via the Ged main menu.
---
--- This function is an implementation detail of the `ModItemFolder` class and is not part of the public API.
---
function ModItemFolder:EditorItemsMenu()
	-- disallow creating new mod items (into the folder) via the Ged main menu
end

---
--- Prevents the ModItemFolder instance from "inheriting" errors of its subitems.
---
--- This function is an implementation detail of the `ModItemFolder` class and is not part of the public API.
---
function ModItemFolder:GetDiagnosticMessage()
	-- prevent the folder from "inheriting" errors of its subitems
end

---
--- Called after a new `ModItemFolder` instance is created in the editor.
---
--- This function is an implementation detail of the `ModItemFolder` class and is not part of the public API.
---
--- @param parent ModDef|ModItem The parent object of the new `ModItemFolder` instance.
--- @param ged Ged The Ged editor instance.
--- @param is_paste boolean Whether the new `ModItemFolder` instance was created by pasting.
---
function ModItemFolder:OnAfterEditorNew(parent, ged, is_paste)
	if self.name == "" then
		self.name = "New folder"
	end
	self.mod = parent:IsKindOf("ModDef") and parent or parent:IsKindOf("ModItem") and parent.mod
	assert(self.mod)
end


----- Ged ops

---
--- Adds the selected mod items to a new folder.
---
--- This function is an implementation detail of the `ModItemFolder` class and is not part of the public API.
---
--- @param socket Ged The Ged editor instance.
--- @param root table The root node of the Ged editor.
--- @param selection table The selected mod items to be added to the new folder.
---
--- @return table|string The new folder path, or an error message if the operation failed.
--- @return function The undo function to revert the operation.
---
function GedOpAddModItemsToFolder(socket, root, selection)
	if not selection[1] then return end
	local undo_funcs = {}
	
	local path = (selection and selection[1]) or {}
	local min_selected_index = false
	for _, val in ipairs(selection[2]) do
		if not IsKindOf(TreeNodeChildren(ParentNodeByPath(root, path))[val], "ModItem") then
			return "Only Mod Items can be arranged in folders."
		end
		if not min_selected_index or min_selected_index > val then
			min_selected_index = val
		end
	end
	min_selected_index = min_selected_index - 1
	path[#path] = min_selected_index
	
	local folder_name = socket:WaitUserInput("Add Items to Folder", "New folder")
	if not folder_name or folder_name == "" then return end
	
	local new_selection, undo_func = GedOpTreeNewItemInContainer(socket, root, path, "ModItemFolder")
	GetNodeByPath(root, new_selection).name = folder_name
	
	local folder_path = table.copy(selection[1])
	folder_path[#folder_path] = min_selected_index + 1
	table.insert(undo_funcs, undo_func)
	
	local children_count = 1
	local sorted_selection = {}
	for _, val in ipairs(selection[2]) do
		table.insert(sorted_selection, val)
	end
	table.sort(sorted_selection)
	for _,val in ipairs(sorted_selection) do
		local old_modified_path = table.copy(selection[1])
		old_modified_path[#old_modified_path] = val + 2 - children_count -- +1 because the folder was inserted before it, + 1 - children_count because every relocation removes one child
		local new_path = table.copy(folder_path)
		new_path[#new_path + 1] = children_count
		children_count = children_count + 1
		TreeRelocateNode(root, old_modified_path, new_path)
		table.insert(undo_funcs, function() TreeRelocateNode(root, new_path, old_modified_path) end)
	end
	
	return new_selection, function()
		for i = #undo_funcs, 1, -1 do
			undo_funcs[i]()
		end
	end
end

---
--- Relocates a ModItem node to a ModItemFolder node in the game's mod item tree.
---
--- @param socket table The socket object used for user input.
--- @param root table The root node of the mod item tree.
--- @param clicked_path table The path to the ModItem node that was clicked.
--- @param folder_path table The path to the ModItemFolder node that the ModItem should be moved to.
--- @return table|string The new path of the ModItemFolder node after the relocation, or an error message if the relocation is not possible.
--- @return function An undo function that can be used to revert the relocation.
function GedOpRelocateModItemToFolder(socket, root, clicked_path, folder_path)
	if not folder_path then return end
	local folder_node = GetNodeByPath(root, folder_path)
	local clicked_node = GetNodeByPath(root, clicked_path)
	if not IsKindOf(folder_node, "ModItemFolder") then return end
	if not IsKindOf(clicked_node, "ModItem") then return end
	
	local lca_path = GetLowestCommonAncestor(folder_path, clicked_path)
	local lca_node = GetNodeByPath(root, lca_path)
	if ParentNodeByPath(root, clicked_path) == folder_node or lca_node == clicked_node then
		return "error" -- just blink in red without error message
	end
	
	local earlier_in_tree = #folder_path ~= #lca_path and folder_path[#lca_path + 1] > clicked_path[#lca_path + 1] and #clicked_path == #lca_path + 1
	
	local old_path = table.copy(clicked_path)
	local new_path = table.copy(folder_path)
	new_path[#new_path + 1] = #TreeNodeChildren(folder_node) + 1
	TreeRelocateNode(root, old_path, new_path)
	
	if earlier_in_tree then
		new_path[#lca_path + 1] = new_path[#lca_path + 1] - 1
	end
	local new_folder_path = table.copy(new_path)
	new_folder_path[#new_folder_path] = nil
	return new_folder_path, function() TreeRelocateNode(root, new_path, old_path) end
end