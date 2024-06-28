--- The base class for container objects that hold sub-objects (PropertyObject) in their array part.
---
--- The `ContainerClass` field specifies the class that the sub-objects must be an instance of or inherit from in order to be considered valid.
--- The `FilterSubItemClass` function can be overridden to provide custom filtering logic for sub-objects.
--- The `IsValidSubItem` function checks if a given sub-object or class is valid according to the `ContainerClass` and `FilterSubItemClass` rules.
DefineClass.ContainerBase = {
	__parents = { "PropertyObject", },
	ContainerClass = "",
}

---
--- Determines if a given sub-object class is valid to be contained within this container.
---
--- This function can be overridden to provide custom filtering logic for sub-objects.
---
--- @param class string|table The class of the sub-object to be checked.
--- @return boolean true if the sub-object class is valid, false otherwise.
---
function ContainerBase:FilterSubItemClass(class)
	return true
end

---
--- Determines if a given sub-object class is valid to be contained within this container.
---
--- This function checks if the sub-object class is a kind of the `ContainerClass` specified for this container, and if it passes the custom filtering logic defined in `FilterSubItemClass`.
---
--- @param item_or_class string|table The class of the sub-object to be checked, or the sub-object itself.
--- @return boolean true if the sub-object class is valid, false otherwise.
---
function ContainerBase:IsValidSubItem(item_or_class)
	local class = type(item_or_class) == "string" and _G[item_or_class] or item_or_class
	return self.ContainerClass ~= "" and (not self.ContainerClass or IsKindOf(class, self.ContainerClass)) and self:FilterSubItemClass(class)
end


----- Container
--
-- Contains sub-objects (PropertyObject) in its array part, editable in Ged

---
--- Defines a container class that holds sub-objects (PropertyObject) in its array part.
---
--- The `ContainerAddNewButtonMode` field specifies the behavior of the "Add new" button in the editor:
---   - `"children"`: Always visible, adds children only (used in Mod Editor)
---   - `"floating"`: Appears on hover, adds children only
---   - `"floating_combined"`: Appears on hover, adds children or siblings
---   - `"docked"`: Adds an "Add new..." button in the XTree for adding a child, on the spot where the added child would be
---   - `"docked_if_empty"`: Same as `"docked"`, but appears only if there are no children yet
---
DefineClass.Container = {
	__parents = { "ContainerBase", },
	
	ContainerAddNewButtonMode = false,
	-- Possible values:
	--   children          - always visible, adds children only (used in Mod Editor)
	--   floating          - appears on hover, adds children only
	--   floating_combined - appears on hover, adds children or siblings
	--   docked            - adds an "Add new..." button in the XTree for adding a child, on the spot where the added child would be
	--   docked_if_empty   - same as docked, but appears only if there are no children yet
}

---
--- Determines the mode for the "Add new" button in the editor for this container.
---
--- If the container is not a ModItem and has a parent ModDef, the mode is set to "floating".
--- Otherwise, the mode is set to the value of the `ContainerAddNewButtonMode` field.
---
--- @return string The mode for the "Add new" button in the editor.
---
function Container:GetContainerAddNewButtonMode()
	local mod = not IsKindOf(self, "ModItem") and GetParentTableOfKindNoCheck(self, "ModDef")
	return mod and "floating" or self.ContainerAddNewButtonMode
end

---
--- Generates the editor items menu for the container.
---
--- If the `ContainerClass` field is not defined in the global `g_Classes` table, this function will return `nil`.
---
--- Otherwise, this function calls `GedItemsMenu` with the `ContainerClass`, `FilterSubItemClass`, and the container instance as arguments, and returns the result.
---
--- @return table|nil The editor items menu, or `nil` if the `ContainerClass` is not defined.
---
function Container:EditorItemsMenu()
	if not g_Classes[self.ContainerClass] then return end
	return GedItemsMenu(self.ContainerClass, self.FilterSubItemClass, self)
end

---
--- Generates a diagnostic message for the container, checking for invalid subitems.
---
--- If the `ContainerClass` field is set, this function checks each subitem in the container to ensure it is a valid subitem of the specified class. If a subitem is not a valid subitem, an error message is returned.
---
--- If the `ContainerClass` field is not set or empty, this function calls the `GetDiagnosticMessage` function of the `PropertyObject` class to generate the diagnostic message.
---
--- @param verbose boolean Whether to include additional verbose information in the diagnostic message.
--- @param indent string The indentation to use for the diagnostic message.
--- @return table The diagnostic message, which is a table with two elements: the message string and the message type ("error" or "warning").
---
function Container:GetDiagnosticMessage(verbose, indent)
	if self.ContainerClass and self.ContainerClass ~= "" then
		for i, subitem in ipairs(self) do
			if not self:IsValidSubItem(subitem) and subitem.class ~= "TestHarness" then
				if IsKindOf(subitem, self.ContainerClass) then
					return { string.format("Invalid subitem #%d of class %s (expected to be a kind of %s)", i, self.class, self.ContainerClass), "error" }
				else
					return { string.format("Invalid subitem #%d (was filtered out by FilterSubItemClass, subitem class is %s)", i, self.class), "error" }
				end
			end
		end
	end
	return PropertyObject.GetDiagnosticMessage(self, verbose, indent)
end


----- GraphContainer
--
-- Contains a graph editable in Ged:
--  * graph nodes (PropertyObject) specify "sockets" for connecting to other nodes in 'GraphLinkSockets':
--    - socket definitions are specified as { id = <id>, name = <display name>, input = <true/false/nil>, type = <string/nil>, },
--    - if 'input' is specified, "input" sockets can only connect to non-"input" (output) sockets
--    - if 'type' is specified, this socket can only connect to sockets with a matching 'type' value
--  * the graph node classes eligible for the graph are controlled via 'ContainerClass' and 'FilterSubItemClass'
--  * the array part of GraphContainer contains the graph nodes
--  * the 'links' member contains the connections between them as an array of
--     { start_node = <node_idx>, start_socket = <id>, end_node = <node_idx>, end_socket = <id> }
--
-- Inherit GraphContainer in a Preset or a preset sub-item.

---
--- Defines a `GraphContainer` class that inherits from `ContainerBase`. This class represents a container for a graph structure that can be edited in Ged.
---
--- The `GraphContainer` class has the following properties:
---
--- - `links`: A table that stores the connections between the graph nodes.
--- - `x`: The x-coordinate of the graph node, injected into all sub-objects for saving purposes.
--- - `y`: The y-coordinate of the graph node, injected into all sub-objects for saving purposes.
---
--- The graph structure is defined by the array of graph nodes, where each node is a `PropertyObject` that specifies "sockets" for connecting to other nodes. The socket definitions are specified as a table with the following fields:
---
--- - `id`: The unique identifier of the socket.
--- - `name`: The display name of the socket.
--- - `input`: A boolean value indicating whether the socket is an input socket (`true`) or an output socket (`false`/`nil`).
--- - `type`: An optional string value that specifies the type of the socket, which can be used to restrict the connections between sockets.
---
--- The graph node classes eligible for the graph are controlled via the `ContainerClass` and `FilterSubItemClass` properties.
---
--- The `links` member contains the connections between the graph nodes as an array of tables with the following fields:
---
--- - `start_node`: The index of the starting node in the graph.
--- - `start_socket`: The ID of the starting socket.
--- - `end_node`: The index of the ending node in the graph.
--- - `end_socket`: The ID of the ending socket.
---
--- The `GraphContainer` class is typically inherited in a Preset or a preset sub-item.
DefineClass.GraphContainer = {
	__parents = { "ContainerBase", },
	properties = {
		{ id = "links", editor = "prop_table", default = true, no_edit = true },
		
		-- hidden x, y properties, injected to all subobjects for saving purposes
		{ id = "x", editor = "number", default = 0, no_edit = true, inject_in_subobjects = true, },
		{ id = "y", editor = "number", default = 0, no_edit = true, inject_in_subobjects = true, },
	},
}

-- extracts the data for the graph structure to be sent to Ged
---
--- Retrieves the data for the graph structure that is managed by the `GraphContainer` class.
---
--- The returned data is a table with the following structure:
---
--- - `links`: A table that stores the connections between the graph nodes.
--- - For each graph node:
---   - `x`: The x-coordinate of the graph node.
---   - `y`: The y-coordinate of the graph node.
---   - `node_class`: The class of the graph node.
---   - `handle`: A unique identifier for the graph node.
---
--- This function is used to extract the data for the graph structure to be sent to the Ged editor.
---
--- @return table The data for the graph structure.
function GraphContainer:GetGraphData()
	local data = { links = self.links }
	for idx, node in ipairs(self) do
		node.handle = node.handle or idx
		table.insert(data, { x = node.x, y = node.y, node_class = node.class, handle = node.handle })
	end
	return data
end

-- applies changes to the graph structure received from Ged
---
--- Applies changes to the graph structure received from the Ged editor.
---
--- This function is used to update the graph structure managed by the `GraphContainer` class based on data received from the Ged editor.
---
--- @param data table The data for the graph structure, containing the following fields:
---   - `links`: A table that stores the connections between the graph nodes.
---   - For each graph node:
---     - `x`: The x-coordinate of the graph node.
---     - `y`: The y-coordinate of the graph node.
---     - `node_class`: The class of the graph node.
---     - `handle`: A unique identifier for the graph node.
---
function GraphContainer:SetGraphData(data)
	local handle_to_idx = {}
	for idx, node in ipairs(self) do
		handle_to_idx[node.handle] = idx
	end	
	
	local new_nodes = {}
	for _, node_data in ipairs(data) do
		local idx = handle_to_idx[node_data.handle]
		local node = idx and self[idx] or g_Classes[node_data.node_class]:new()
		node.x = node_data.x
		node.y = node_data.y
		node.handle = node_data.handle
		table.insert(new_nodes, node)
	end
	table.iclear(self)
	table.iappend(self, new_nodes)
	
	self.links = data.links
	self:UpdateDirtyStatus()
end
