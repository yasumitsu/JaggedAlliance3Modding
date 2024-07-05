-- TODO:
-- 1. Add scrollbars to GraphEditorPanel
-- 2. Undo support
-- 3. Support multiple split points, serialize them

local SocketLinkOffset = point(10, 0)
local LinkMouseHoverDist = 7
local LinkThickness = 8
local SplineSampleStep = 10
local NodeSelectedColor = RGB(248, 220, 120)
local GraphSocketColors = {
	number = RGB(205, 0, 205),
	string = RGB(0, 150, 100),
	boolean = RGB(0, 100, 0),
	any = RGB(240, 240, 240),
}

DefineClass.XGraphEditor = {
	__parents = { "XMap" },
	
	drag_start_socket = false,
	drag_end_socket = false,
	drag_end_pt = false,
	last_node_pt = false,
	menu = false,
	links = false,
	read_only = false,
	selected_node = false,
	
	UseCustomTime = false,
	
	NodeClassItems = false, -- set to a table with { EditorName = ..., Class = ... } items for each node class
	OnGraphEdited = empty_func,
	OnNodeSelected = empty_func,
}

---
--- Initializes the links table for the XGraphEditor class.
---
--- This function is called during the initialization of the XGraphEditor class to set up the links table, which is used to store information about the links between nodes in the graph editor.
---
--- @function [parent=XGraphEditor] Init
--- @return nil
function XGraphEditor:Init()
	self.links = {}
end

---
--- Selects the specified node in the graph editor.
---
--- If the specified node is different from the currently selected node, the currently selected node (if any) is deselected and the new node is selected. The `OnNodeSelected` callback is called with the selected node.
---
--- @param node XGraphNode The node to select.
---
function XGraphEditor:SelectNode(node)
	if self.selected_node ~= node then
		if self.selected_node then
			self.selected_node:Select(false)
		end
		self.selected_node = node
		if node then
			node:Select(true)
		end
	end
	self:OnNodeSelected(node)
end

---
--- Retrieves the graph data for the XGraphEditor instance.
---
--- This function collects the data for all the nodes and links in the graph editor and returns it as a table. The returned table has the following structure:
---
--- 
--- {
---     links = {
---         {
---             start_node = <index of start node>,
---             start_socket = <socket ID of start socket>,
---             end_node = <index of end node>,
---             end_socket = <socket ID of end socket>
---         },
---         ...
---     },
---     {
---         x = <x position of node>,
---         y = <y position of node>,
---         node_class = <class of node>,
---         handle = <handle of node>
---     },
---     ...
--- }
--- 
---
--- @return table The graph data
---
function XGraphEditor:GetGraphData()
	local data = { links = {} }
	local node_to_idx = {}
	for idx, node in ipairs(self) do
		if IsKindOf(node, "XGraphNode") then
			table.insert(data, { x = node.PosX, y = node.PosY, node_class = node.node_class, handle = node.handle })
			node_to_idx[node] = idx
		end
	end
	for _, link in ipairs(self.links) do
		local start_sock = link.start_socket
		local end_sock = link.end_socket
		table.insert(data.links, {
			start_node = node_to_idx[start_sock.parent_node],
			start_socket = start_sock.socket_id,
			end_node = node_to_idx[end_sock.parent_node],
			end_socket = end_sock.socket_id,
		})
	end
	return data
end

---
--- Sets the graph data for the XGraphEditor instance.
---
--- This function deletes all existing nodes and links in the graph editor, and then recreates the nodes and links based on the provided data table. The data table should have the following structure:
---
--- {
---     links = {
---         {
---             start_node = <index of start node>,
---             start_socket = <socket ID of start socket>,
---             end_node = <index of end node>,
---             end_socket = <socket ID of end socket>
---         },
---         ...
---     },
---     {
---         x = <x position of node>,
---         y = <y position of node>,
---         node_class = <class of node>,
---         handle = <handle of node>
---     },
---     ...
--- }
---
--- @param data table The graph data to set
---
function XGraphEditor:SetGraphData(data)
	self:DeleteChildren()
	for _, data in ipairs(data) do
		local node = XGraphNode:new({}, self)
		node:SetNodeClass(data.node_class)
		node:SetPos(data.x, data.y)
		node.handle = data.handle
	end
	self.links = {}
	for _, link in ipairs(data and data.links) do
		local start_sock = table.find_value(self[link.start_node].sockets, "socket_id", link.start_socket)
		local end_sock = table.find_value(self[link.end_node].sockets, "socket_id", link.end_socket)
		if start_sock and end_sock then
			self:AddLink(start_sock, end_sock)
		end
	end
end

---
--- Sets the read-only state of the XGraphEditor instance.
---
--- When the editor is in read-only mode, the grid lines will be drawn in a different color and the context menu will be closed.
---
--- @param read_only boolean Whether the editor should be in read-only mode.
---
function XGraphEditor:SetReadOnly(read_only)
	self.read_only = read_only
	self:CloseContextMenu()
	self:Invalidate()
end

---
--- Draws the content of the XGraphEditor instance, including the grid lines and any active connections.
---
--- The grid lines are drawn in a different color depending on whether the editor is in read-only mode or not.
---
--- @param self XGraphEditor The XGraphEditor instance to draw the content for.
---
function XGraphEditor:DrawContent()
	UIL.DrawSolidRect(box(0, 0, self.map_size:x(), self.map_size:y()), RGB(85, 85, 85))
	
	local color1 = self.read_only and RGB(115, 115, 115) or RGB(175, 175, 175)
	local color2 = self.read_only and RGB( 95,  95,  95) or RGB(125, 125, 125)
	for x = 0, self.map_size:x(), 25 do
		local thick = x % 125 == 0
		UIL.DrawLineAntialised(thick and 7 or 3, point(x, 0), point(x, self.map_size:y()), thick and color2 or color1)
	end
	for y = 0, self.map_size:y(), 25 do
		local thick = y % 125 == 0
		UIL.DrawLineAntialised(thick and 7 or 3, point(0, y), point(self.map_size:x(), y), thick and color2 or color1)
	end
end

local function get_link_spline(start_point, end_point)
	local offset = start_point:x() < end_point:x() and SocketLinkOffset or -SocketLinkOffset
	local spline_start = start_point + offset
	local spline_end = end_point - offset
	local the_x = spline_end:x() - spline_start:x() 
	local vector_end1 = point(spline_start:x() + the_x/4, spline_start:y())
	local vector_end2 = point(spline_end:x() - the_x/4, spline_end:y())
	return { spline_start, vector_end1, vector_end2, spline_end }
end

local function draw_link(start_point, end_point, spline, color)
	UIL.DrawLineAntialised(LinkThickness, start_point, spline[1], color)
	local spline_length = BS3_GetSplineLength2D(spline)
	local last_pos = spline[1]
	local i = SplineSampleStep
	while i < spline_length do
		local next_pos = point(BS3_GetSplinePos2D(spline, i, spline_length))
		UIL.DrawLineAntialised(LinkThickness, last_pos, next_pos, color)
		last_pos = next_pos
		i = i + SplineSampleStep
	end
	UIL.DrawLineAntialised(LinkThickness, last_pos, spline[4], color)
	UIL.DrawLineAntialised(LinkThickness, spline[4], end_point, color)
end

---
--- Draws the children of the XGraphEditor instance, including any active connections.
---
--- If there is a drag connection in progress, the connection is drawn from the start socket to the current mouse position.
--- All other connections are drawn using the DrawSpline method of the link objects.
---
--- @param self XGraphEditor The XGraphEditor instance to draw the children for.
--- @param clip_box table The bounding box to clip the drawing to.
---
function XGraphEditor:DrawChildren(clip_box)
	XMap.DrawChildren(self, clip_box)
	if self.drag_end_pt and self.drag_start_socket then
		local start_pos, end_pos = self.drag_start_socket.box:Center(), self.drag_end_pt
		local spline = get_link_spline(start_pos, end_pos)
		draw_link(start_pos, end_pos, spline, self.drag_start_socket.ImageColor)
	end
	for _, link in ipairs(self.links) do
		link:DrawSpline(self.drag_end_pt)
	end
end

---
--- Closes the context menu for the XGraphEditor instance.
---
--- If a context menu is currently open, this function will delete the menu and set the `menu` property to `false`.
---
function XGraphEditor:CloseContextMenu()
	if self.menu then
		self.menu:delete()
		self.menu = false
	end
end

---
--- Handles the mouse position event for the XGraphEditor instance.
---
--- This function is called when the mouse position changes within the XGraphEditor. It updates the `drag_end_pt` property to the current mouse position in map coordinates, and then invalidates the editor to allow connections to change color depending on the mouse position.
---
--- @param pt table The current mouse position in screen coordinates.
--- @param button string The current mouse button state ("L", "R", or "M").
--- @return boolean The result of calling `XMap.OnMousePos` with the same arguments.
---
function XGraphEditor:OnMousePos(pt, button)
	self.drag_end_pt = self:ScreenToMapPt(pt)
	self:Invalidate() -- allow connections to change color depending on mouse position
	return XMap.OnMousePos(self, pt, button)
end

---
--- Handles the mouse button down event for the XGraphEditor instance.
---
--- This function is called when the user presses a mouse button within the XGraphEditor. It performs the following actions:
---
--- 1. Closes any open context menu.
--- 2. If the left mouse button is pressed and the editor is not read-only:
---    - Checks if the mouse is over an existing link, and if so, creates a new split point on that link.
--- 3. If the right mouse button is pressed and the editor is not read-only:
---    - Checks if the mouse is over an existing link, and if so, deletes that link.
---    - Creates a new context menu with options to create new nodes of different types.
---
--- @param pt table The current mouse position in screen coordinates.
--- @param button string The current mouse button state ("L", "R", or "M").
--- @return boolean The result of calling `XMap.OnMouseButtonDown` with the same arguments.
---
function XGraphEditor:OnMouseButtonDown(pt, button)
	self:CloseContextMenu()
	
	local pt1 = self:ScreenToMapPt(pt)
	if not self.read_only and button == "L" then
		if #self.links > 0 then
			for _, spline in ipairs(self.links) do
				if BS3_GetSplineToPointDist2D(spline.spline1, self.drag_end_pt) <= LinkMouseHoverDist and not spline.split_point then
					local split = XGraphEditorSplineSplitPoint:new({ PosX = pt1:x(), PosY = pt1:y() }, self)
					split:OnMouseButtonDown(pt, "L") -- start dragging the split point
					spline.split_point = split
					self:OnGraphEdited()
					break
				end
			end
		end
	elseif not self.read_only and button == "R" then
		-- if there is a link under the mouse, delete it
		for idx, spline in ipairs(self.links) do
			if BS3_GetSplineToPointDist2D(spline.spline1, self.drag_end_pt) <= LinkMouseHoverDist or
			   spline.split_point and BS3_GetSplineToPointDist2D(spline.spline2, self.drag_end_pt) <= LinkMouseHoverDist
			then
				spline:delete()
				table.remove(self.links, idx)
				self:OnGraphEdited()
				return "break"
			end
		end
		
		-- create context menu
		self.menu = XPopupList:new({
			Background = RGB(196, 196, 196),
		}, terminal.desktop)
		self.menu:SetAnchorType("mouse")
		self.menu.Anchor = pt
		for _, obj in ipairs(self.NodeClassItems) do
			XTextButton:new({
				OnPress = function()
					local node = XGraphNode:new({}, self)
					node:SetNodeClass(obj.Class)
					node:SetPos(pt1:x(), pt1:y())
					node.handle = #self == 1 and 1 or self[#self - 1].handle + 1
					node.OnLayoutComplete = function()
						local clip = false
						for _, obj in ipairs(node.map) do
							if obj ~= node and node.box:Intersect2D(obj.box) ~= const.irOutside then
								clip = true
								node:Move(node.box:Center(), obj.box:sizex(), 0, 100)
								break
							end
						end
						if not clip then
							node.last_valid_pt = node:GetPos()
						end
						node.OnLayoutComplete = nil
					end
					self:CloseContextMenu()
					self:OnGraphEdited()
				end,
				Text = obj.EditorName,
				RolloverBackground = RGB(204, 232, 255),
				PressedBackground = RGB(121, 189, 241),
			}, self.menu)
		end
		return "break" 
	end
	return XMap.OnMouseButtonDown(self, pt, button)
end

---
--- Adds a link between two sockets in the graph editor.
---
--- @param sock1 XGraphSocket The first socket to connect.
--- @param sock2 XGraphSocket The second socket to connect.
--- @return XGraphLink The created link, or nil if the connection is not allowed.
---
function XGraphEditor:AddLink(sock1, sock2)
	if self:CanConnect(sock1, sock2) then
		local link = XGraphLink:new{ start_socket = sock2, end_socket = sock1 }
		table.insert(self.links, link)
		return link
	end
end

---
--- Removes all links connected to the specified socket.
---
--- @param sock XGraphSocket The socket to remove links from.
---
function XGraphEditor:RemoveLinks(sock)
	for idx = #self.links, 1, -1 do
		local spline = self.links[idx]
		if spline.end_socket == sock or spline.start_socket == sock then
			spline:delete()
			table.remove(self.links, idx)
		end
	end
end

---
--- Called when the layout of the graph editor is complete.
--- Updates the link splines and then calls the base class's OnLayoutComplete method.
---
--- @return boolean True if the layout was successfully completed, false otherwise.
---
function XGraphEditor:OnLayoutComplete()
	self:UpdateLinkSplines()
	return XMap.OnLayoutComplete(self)
end

---
--- Updates the link splines in the graph editor.
---
--- @param sock XGraphSocket The socket to update links for, or nil to update all links.
---
function XGraphEditor:UpdateLinkSplines(sock)
	for _, spline in ipairs(self.links) do
		if not sock or spline.end_socket == sock or spline.start_socket == sock then
			spline:CalcSplinePoints()
		end
	end
end

---
--- Checks if two sockets can be connected in the graph editor.
---
--- @param sock1 XGraphSocket The first socket to check.
--- @param sock2 XGraphSocket The second socket to check.
--- @return boolean True if the sockets can be connected, false otherwise.
---
function XGraphEditor:CanConnect(sock1, sock2)
	local data1, data2 = sock1.link_data, sock2.link_data
	return
		sock1.parent_node ~= sock2.parent_node and
		(data1.type == nil or data2.type == nil or data1.type == data2.type) and
		(data1.input == nil or data2.input == nil or data1.input ~= data2.input)
end

---
--- Checks if two sockets are connected in the graph editor.
---
--- @param sock1 XGraphSocket The first socket to check.
--- @param sock2 XGraphSocket The second socket to check.
--- @return boolean True if the sockets are connected, false otherwise.
---
function XGraphEditor:IsConnected(sock1, sock2)
	for _, spline in ipairs(self.links) do
		if spline.start_socket == sock2 and spline.end_socket == sock1 or spline.start_socket == sock1 and spline.end_socket == sock2 then
			return true
		end
	end
end


DefineClass.XGraphNode = {
	__parents = { "XMapObject" },
	
	Background = RGB(196, 196, 196),
	BorderColor = NodeSelectedColor,
	LayoutMethod = "HList",
	
	node_class = false,
	handle = false, -- temporary handle sent from the game to Ged, used to recognize the object when sending the data back
	sockets = false, -- array of XGraphSocket
	last_valid_pt = false,
	diff_x = false,
	diff_y = false,
}

---
--- Sets the node class for the XGraphNode.
---
--- @param node_class string The class name of the node.
---
function XGraphNode:SetNodeClass(node_class)
	self:DeleteChildren()
	self.sockets = {}
	self.node_class = node_class
	
	local class = g_Classes[node_class]
	local title = XText:new({
		Dock = "top",
		TextHAlign = "center",
		TextStyle = "GedTitle",
		UseClipBox = false,
		Clip = false,
	}, self)
	title:SetText(class.EditorName)
	local inputW = XWindow:new({
		HAlign = "left",
		LayoutMethod = "VList",
		UseClipBox = false,
		Margins = box(0, 0, 10, 0),
	}, self)
	local outputW = XWindow:new({
		HAlign = "right",
		LayoutMethod = "VList",
		UseClipBox = false,
		Margins = box(10, 0, 0, 0),
	}, self)
	
	-- add input sockets
	for _, link_data in ipairs(class.GraphLinkSockets) do
		local alignment = link_data.input and "right" or "left"
		local socket_parent = link_data.input and inputW or outputW
		local inputBlock = XWindow:new({
			HAlign = link_data.input and "left" or "right",
			UseClipBox = false,
		}, socket_parent)
		local sock = XGraphSocket:new({
			HAlign = alignment,
			parent_node = self,
			link_data = link_data,
		}, inputBlock)
		local text = XText:new({
			Dock = alignment,
			TextHAlign = alignment,
			TextStyle = "GedTitle",
			UseClipBox = false,
			Clip = false,
		}, inputBlock)
		text:SetText(link_data.name or link_data.id)
		table.insert(self.sockets, sock)
	end
end

---
--- Sets the border width of the XGraphNode based on whether it is selected or not.
---
--- @param selected boolean Whether the node is selected or not.
function XGraphNode:Select(selected)
	self:SetBorderWidth(selected and 2 or 0)
end

---
--- Handles mouse button down events for an XGraphNode.
---
--- If the left mouse button is pressed and the map is not read-only, the node is selected and the mouse capture is set to the node. The node's position is stored and the difference between the node's position and the mouse position is calculated.
---
--- If the right mouse button is pressed and the map is not read-only, a context menu is opened with an option to delete the node. When the "Delete Node" option is selected, the node's links are deleted, the node is deleted, and the graph is edited.
---
--- @param pt point The mouse position.
--- @param button string The mouse button that was pressed.
--- @return string "break" to indicate the event has been handled.
function XGraphNode:OnMouseButtonDown(pt, button)
	self.map:CloseContextMenu()
	
	if not self.map.read_only and button == "L" then
		terminal.desktop:SetMouseCapture(self)
		local pt1 = self.map:ScreenToMapPt(pt)
		self.map.last_node_pt = self:GetPos()
		self.last_valid_pt = self:GetPos()
		self.diff_x = self.PosX - pt1:x()
		self.diff_y = self.PosY - pt1:y()
		self.map:SelectNode(self)
		return "break"
	elseif not self.map.read_only and button == "R" then
		local map = self.map
		map.menu = XPopupList:new({
			Background = RGB(196, 196, 196),
		}, terminal.desktop)
		map.menu:SetAnchorType("mouse")
		map.menu.Anchor = pt
		XTextButton:new({
			OnPress = function()
				self:DeleteLinks()
				self:delete()
				map:CloseContextMenu()
				map:OnGraphEdited()
			end,
			Text = "Delete Node",
			RolloverBackground = RGB(204, 232, 255),
			PressedBackground = RGB(121, 189, 241),
			HAlign = "left",
		}, self.map.menu)
		return "break"
	end
end

---
--- Handles mouse position events for an XGraphNode.
---
--- If the node is being dragged (mouse capture is set to the node), this function checks if the mouse position is outside the visible area of the map. If so, it starts a scroll thread that continuously moves the node and scrolls the map. If the mouse position is inside the visible area, it simply moves the node.
---
--- The function also checks if the node's new position would overlap with any other nodes on the map. If there is no overlap, the node's last valid position is updated.
---
--- @param pt point The current mouse position.
--- @param button string The mouse button that is currently pressed.
--- @return string "break" to indicate the event has been handled.
function XGraphNode:OnMousePos(pt, button)
	if terminal.desktop:GetMouseCapture() == self then
		if self:IsThreadRunning("ScrollThread") then
			if self.map.box:Point2DInside(pt) then
				self:DeleteThread("ScrollThread")
			end
			return "break"
		end
		local my_pt = self:GetPos()
		local pt1 = self.map:ScreenToMapPt(pt)
		local my_min = self.map:ScreenToMapPt(point(self.map.box:minx(),self.map.box:miny()))
		local my_max = self.map:ScreenToMapPt(point(self.map.box:maxx(),self.map.box:maxy()))
		if my_pt:x() > 0 + self.box:sizex()/2 or
		   my_pt:x() < self.map.box:sizex() - self.box:sizex()/2 or
		   my_pt:y() > 0 + self.box:sizey()/2 or
		   my_pt:y() < self.map.box:sizey() - self.box:sizex()/2
		then
			if pt1:x() < my_min:x() + self.box:sizex()/2 or
			   pt1:x() > my_max:x() - self.box:sizex()/2 or
			   pt1:y() < my_min:y() + self.box:sizey()/2 or
			   pt1:y() > my_max:y() - self.box:sizey()/2
			then
				self:CreateThread("ScrollThread", function()
					while true do
						self:Move(pt1, self.diff_x, self.diff_y, 100)
						Sleep(100)
					end
				end)
			else
				self:Move(pt1, self.diff_x, self.diff_y, false)
			end
		end
		local clip = false
		for i, obj in ipairs(self.map) do
			if obj ~= self and self.box:Intersect2D(obj.box) ~= const.irOutside then
				clip = true
				break
			end
		end
		if not clip then
			self.last_valid_pt = self:GetPos()
		end
		return "break"
	end
end

---
--- Handles the mouse button up event for an XGraphNode.
---
--- When the mouse button is released, this function checks if the node was being scrolled. If so, it stops the scroll thread. Otherwise, it resets the node's position to the last valid position.
---
--- The function also notifies the graph editor that the graph has been edited.
---
--- @param pt point The current mouse position.
--- @param button string The mouse button that is currently released.
--- @return string "break" to indicate the event has been handled.
function XGraphNode:OnMouseButtonUp(pt, button)
	if terminal.desktop:GetMouseCapture() == self then	
		if self:IsThreadRunning("ScrollThread") then
			self:DeleteThread("ScrollThread")
		else
			self:SetPos(self.last_valid_pt:x(), self.last_valid_pt:y())
		end
		terminal.desktop:SetMouseCapture(false)
		self.map:OnGraphEdited()
		return "break"
	end
end

---
--- Moves the XGraphNode to the specified mouse position, with optional scrolling.
---
--- If the node is being scrolled, this function updates the map's scroll position based on the node's movement. It also ensures the map size is expanded if the node is moved outside the current map bounds.
---
--- Finally, this function updates the link splines for all sockets attached to the node.
---
--- @param mouse_pt point The current mouse position.
--- @param dx number The horizontal offset to apply to the node's position.
--- @param dy number The vertical offset to apply to the node's position.
--- @param scroll boolean Whether to scroll the map as the node is moved.
function XGraphNode:Move(mouse_pt, dx, dy, scroll)
	local my_min = self.map:ScreenToMapPt(point(self.map.box:minx(), self.map.box:miny()))
	local my_max = self.map:ScreenToMapPt(point(self.map.box:maxx(), self.map.box:maxy()))
	self:SetPos(
		Clamp(mouse_pt:x() + dx, self.box:sizex()/2, self.map.map_size:x() - self.box:sizex()/2),
		Clamp(mouse_pt:y() + dy, self.box:sizey()/2, self.map.map_size:y() - self.box:sizey()/2),
	scroll)
	if scroll then
		local xd = self.PosX - self.map.last_node_pt:x()
		local yd = self.PosY - self.map.last_node_pt:y()
		xd = MulDivRound(xd, 1000, self.map.scale:x())
		yd = MulDivRound(yd, 1000, self.map.scale:y())
		self.map:ScrollMap(-xd, -yd, scroll)
	end
	if mouse_pt:x() > self.map.map_size:x() or mouse_pt:y() > self.map.map_size:y() then
		if mouse_pt:x() > self.map.map_size:x() then
			self.map.map_size = point(self.map.map_size:x() + 25, self.map.map_size:y())
		end
		if mouse_pt:y() > self.map.map_size:y() then
			self.map.map_size = point(self.map.map_size:x(), self.map.map_size:y() + 25)
		end
	end
	self.map.last_node_pt = self:GetPos()
	
	for _, sock in ipairs(self.sockets) do
		self.map:UpdateLinkSplines(sock)
	end
end
 
---
--- Deletes all links connected to the sockets of this XGraphNode.
---
--- This function iterates through all the sockets of the node and calls the `RemoveLinks` function on the map for each socket. This effectively removes all links connected to the node.
---
--- @param self XGraphNode The XGraphNode instance.
function XGraphNode:DeleteLinks()
	for _, sock in ipairs(self.sockets) do
		self.map:RemoveLinks(sock)
	end
end


DefineClass.XGraphSocket = {
	__parents = { "XImage" },
	
	UseClipBox = false,
	Image = "CommonAssets/UI/Ged/socket_empty",
	ImageScale = point(500, 500),
	HandleMouse = true,
	
	link_data = false, -- the data for this socket from the node's GraphLinkSockets table
	socket_id = false, -- set to link_data.id
	parent_node = false, -- my parent node
	connections = 0, -- how many links to this socket
}

---
--- Initializes an XGraphSocket instance.
---
--- This function sets the `socket_id` field to the `id` field of the `link_data` table, and sets the `ImageColor` field to the color associated with the `type` field of the `link_data` table, or the default "any" color if no specific color is defined.
---
--- @param self XGraphSocket The XGraphSocket instance.
function XGraphSocket:Init()
	self.socket_id = self.link_data.id
	self.ImageColor = GraphSocketColors[self.link_data.type] or GraphSocketColors.any
end

---
--- Increments the connection count for this socket and updates the socket's image to indicate it is full.
---
--- This function is called when a new link is connected to this socket. It increments the `connections` field and updates the socket's image to the "full" state.
---
--- @param self XGraphSocket The XGraphSocket instance.
function XGraphSocket:AddConnection()
	self.connections = self.connections + 1
	self:SetImage("CommonAssets/UI/Ged/socket_full")
end

---
--- Decrements the connection count for this socket and updates the socket's image to indicate it is empty.
---
--- This function is called when a link is removed from this socket. It decrements the `connections` field and updates the socket's image to the "empty" state if the connection count reaches 0.
---
--- @param self XGraphSocket The XGraphSocket instance.
function XGraphSocket:RemoveConnection()
	self.connections = self.connections - 1
	if self.connections == 0 then
		self:SetImage("CommonAssets/UI/Ged/socket_empty")
	end
end

---
--- Handles mouse button down events for an XGraphSocket instance.
---
--- This function is called when the user presses a mouse button on the socket. If the left mouse button is pressed and the map is not in read-only mode, it sets the `drag_start_socket` field of the map to the current socket and captures the mouse. If the right mouse button is pressed and the map is not in read-only mode, it removes any links connected to the socket and calls the `OnGraphEdited` function of the map.
---
--- @param self XGraphSocket The XGraphSocket instance.
--- @param pt table The screen position of the mouse pointer.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @return string "break" to indicate the event has been handled.
function XGraphSocket:OnMouseButtonDown(pt, button)
	local map = GetParentOfKind(self, "XMap")
	if not map.read_only and button == "L" then
		map.drag_start_socket = self
		terminal.desktop:SetMouseCapture(self)
		return "break"
	elseif not map.read_only and button == "R" then
		map:RemoveLinks(self)
		map:OnGraphEdited()
		return "break"
	end
end

---
--- Handles mouse position events for an XGraphSocket instance when the mouse is captured.
---
--- This function is called when the user moves the mouse while holding down the mouse button on the socket. It updates the appearance of the socket and any potential target sockets based on the mouse position. If a valid target socket is found, it sets the `drag_end_socket` field of the map to that socket. If no valid target is found, it clears the `drag_end_socket` field.
---
--- @param self XGraphSocket The XGraphSocket instance.
--- @param pt table The screen position of the mouse pointer.
--- @param button string The mouse button that is currently pressed ("L" for left, "R" for right).
--- @return string "break" to indicate the event has been handled.
function XGraphSocket:OnMousePos(pt, button)
	if terminal.desktop:GetMouseCapture() == self then
		self:SetImage("CommonAssets/UI/Ged/socket_full")
		local map = GetParentOfKind(self, "XMap")
		local target = map:GetMouseTarget(pt)
		if IsKindOf(target, "XGraphSocket") and map:CanConnect(self, target) and target.connections == 0 then
			if map.drag_end_socket and map.drag_end_socket ~= target then
				map.drag_end_socket:SetImage("CommonAssets/UI/Ged/socket_empty")
			end
			target:SetImage("CommonAssets/UI/Ged/socket_full")
			map.drag_end_socket = target
		elseif map.drag_end_socket then
			map.drag_end_socket:SetImage("CommonAssets/UI/Ged/socket_empty")
			map.drag_end_socket = false
		end
		map.drag_end_pt = map:ScreenToMapPt(pt)
		map:Invalidate()
		return "break"
	end
end

---
--- Handles mouse button up events for an XGraphSocket instance when the mouse is captured.
---
--- This function is called when the user releases the mouse button on the socket. If the mouse was previously captured, it checks if a valid target socket was found during the drag operation. If so, it creates a new XGraphLink between the start and end sockets and calculates the spline points for the link. If no valid target was found and the socket has no connections, it sets the socket image to the empty state. It then clears the `drag_start_socket` and `drag_end_socket` fields of the map and invalidates the map to trigger a redraw.
---
--- @param self XGraphSocket The XGraphSocket instance.
--- @param pt table The screen position of the mouse pointer.
--- @param button string The mouse button that was released ("L" for left, "R" for right).
--- @return string "break" to indicate the event has been handled.
function XGraphSocket:OnMouseButtonUp(pt, button)
	if terminal.desktop:GetMouseCapture() == self then
		terminal.desktop:SetMouseCapture(false)
		local map = GetParentOfKind(self, "XMap")
		local target = map:GetMouseTarget(pt)
		if IsKindOf(target, "XGraphSocket") and map:CanConnect(target, self) then
			map:AddLink(self, target):CalcSplinePoints()
		elseif self.connections == 0 then
			self:SetImage("CommonAssets/UI/Ged/socket_empty")
		end
		map.drag_end_socket = false
		map.drag_start_socket = false
		map:Invalidate()
		map:OnGraphEdited()
		return "break"
	end
end

---
--- Sets the image of an XGraphSocket instance based on whether the socket is being hovered over or has any connections.
---
--- If the socket is being hovered over or has any connections, the image is set to "CommonAssets/UI/Ged/socket_full". Otherwise, the image is set to "CommonAssets/UI/Ged/socket_empty".
---
--- @param self XGraphSocket The XGraphSocket instance.
--- @param inside boolean Whether the mouse is currently hovering over the socket.
---
function XGraphSocket:OnSetRollover(inside)
	if inside or self.connections > 0 then
		self:SetImage("CommonAssets/UI/Ged/socket_full")
	else
		self:SetImage("CommonAssets/UI/Ged/socket_empty")
	end
end


DefineClass.XGraphLink = {
	__parents = { "InitDone" },
	
	spline1 = false,	-- the spline before the split point
	spline2 = false, -- the spline after the split point
	start_socket = false, -- a reference to the input socket in the connection
	end_socket = false, -- a reference to the output socket in the connection 
	split_point = false,
}
---
--- Initializes an XGraphLink instance by adding connections to the start and end sockets.
---
--- This function is called when an XGraphLink is created. It adds the link to the start and end sockets, connecting them together.
---
--- @param self XGraphLink The XGraphLink instance being initialized.
---

function XGraphLink:Init()
	self.start_socket:AddConnection()
	self.end_socket:AddConnection()
end

---
--- Cleans up an XGraphLink instance by removing its connections from the start and end sockets, and deleting its split point if it exists.
---
--- This function is called when an XGraphLink is being destroyed. It removes the link from the start and end sockets, disconnecting them, and deletes the split point if it exists.
---
--- @param self XGraphLink The XGraphLink instance being cleaned up.
---
function XGraphLink:Done()
	self.start_socket:RemoveConnection()
	self.end_socket:RemoveConnection()
	if spline.split_point then
		spline.split_point:delete()
	end
end

---
--- Calculates the spline points for an XGraphLink instance.
---
--- This function is responsible for setting the `spline1` and `spline2` properties of the XGraphLink instance based on the positions of the start and end sockets, and the optional split point.
---
--- If a split point exists, the function calculates two separate splines - one from the start socket to the split point, and another from the split point to the end socket. Otherwise, it calculates a single spline from the start socket to the end socket.
---
--- @param self XGraphLink The XGraphLink instance for which to calculate the spline points.
---
function XGraphLink:CalcSplinePoints()
	local start_point = self.start_socket.box:Center()
	local end_point = self.end_socket.box:Center()
	if self.split_point then
		local midpoint = self.split_point.box:Center()
		self.spline1 = get_link_spline(start_point, midpoint - SocketLinkOffset)
		self.spline2 = get_link_spline(midpoint + SocketLinkOffset, end_point)
	else
		self.spline1 = get_link_spline(start_point, end_point)
	end
end

---
--- Checks if the given mouse point is inside the bounds of the XGraphLink.
---
--- If the link has a split point, the function checks if the mouse point is within the hover distance of either the first or second spline. If the link does not have a split point, the function checks if the mouse point is within the hover distance of the single spline.
---
--- @param self XGraphLink The XGraphLink instance.
--- @param mouse_pt Vector2 The mouse point to check.
--- @return boolean True if the mouse point is inside the link, false otherwise.
---
function XGraphLink:PointInside(mouse_pt)
	if self.split_point then
		return (BS3_GetSplineToPointDist2D(self.spline1, mouse_pt) <= LinkMouseHoverDist or
		        BS3_GetSplineToPointDist2D(self.spline2, mouse_pt) <= LinkMouseHoverDist)
	else
		return BS3_GetSplineToPointDist2D(self.spline1, mouse_pt) <= LinkMouseHoverDist
	end
end

---
--- Draws the spline representing the XGraphLink instance.
---
--- If the link has a split point, the function draws two separate splines - one from the start socket to the split point, and another from the split point to the end socket. Otherwise, it draws a single spline from the start socket to the end socket.
---
--- The color of the spline is determined by the link data type, and is highlighted if the mouse point is inside the link bounds and the mouse is not captured.
---
--- @param self XGraphLink The XGraphLink instance to draw.
--- @param mouse_pt Vector2 The current mouse position (optional).
---
function XGraphLink:DrawSpline(mouse_pt)
	local color = GraphSocketColors[self.start_socket.link_data.type or self.end_socket.link_data.type or "any"]
	if mouse_pt and self:PointInside(mouse_pt) and not terminal.desktop:GetMouseCapture() then
		color = InterpolateRGB(color, const.clrWhite, 1, 3) -- highlighted color
	end
	
	local start_point = self.start_socket.box:Center()
	local end_point = self.end_socket.box:Center()
	if not self.split_point then
		draw_link(start_point, end_point, self.spline1, color)
	else
		local split_point = self.split_point.box:Center()
		draw_link(start_point, split_point, self.spline1, color)
		draw_link(split_point, end_point, self.spline2, color)
	end
end


DefineClass.XGraphEditorSplineSplitPoint = {
	__parents = { "XMapObject" },
	
	HandleMouse = true,
	MinWidth = 10,
	MaxWidth = 10,
	MinHeight = 10,
	MaxHeight = 10,
}

---
--- Handles the mouse button down event for the XGraphEditorSplineSplitPoint class.
---
--- If the map is not read-only and the left mouse button is pressed, this function sets the mouse capture to the current object and returns "break" to prevent further event propagation.
---
--- @param self XGraphEditorSplineSplitPoint The XGraphEditorSplineSplitPoint instance.
--- @param pt Vector2 The current mouse position.
--- @param button string The mouse button that was pressed.
--- @return string "break" to prevent further event propagation.
---
function XGraphEditorSplineSplitPoint:OnMouseButtonDown(pt, button)
	if not self.map.read_only and button == "L" then
		terminal.desktop:SetMouseCapture(self)
		return "break"
	end
end

---
--- Handles the mouse position event for the XGraphEditorSplineSplitPoint class.
---
--- If the map is not read-only and the left mouse button is pressed, this function updates the position of the XGraphEditorSplineSplitPoint instance to the current mouse position and invalidates the map.
---
--- @param self XGraphEditorSplineSplitPoint The XGraphEditorSplineSplitPoint instance.
--- @param pt Vector2 The current mouse position.
--- @param button string The mouse button that was pressed.
--- @return string "break" to prevent further event propagation.
---
function XGraphEditorSplineSplitPoint:OnMousePos(pt, button)
	if terminal.desktop:GetMouseCapture() == self then
		local pt1 = self.map:ScreenToMapPt(pt)
		self:SetPos(pt1:x(), pt1:y())
		self.map:Invalidate()
		return "break"
	end
end

---
--- Handles the mouse button up event for the XGraphEditorSplineSplitPoint class.
---
--- If the map is not read-only and the left mouse button is released, this function updates the position of the XGraphEditorSplineSplitPoint instance to the current mouse position, releases the mouse capture, and notifies the map that the graph has been edited.
---
--- @param self XGraphEditorSplineSplitPoint The XGraphEditorSplineSplitPoint instance.
--- @param pt Vector2 The current mouse position.
--- @param button string The mouse button that was released.
--- @return string "break" to prevent further event propagation.
---
function XGraphEditorSplineSplitPoint:OnMouseButtonUp(pt, button)
	if terminal.desktop:GetMouseCapture() == self then
		local pt1 = self.map:ScreenToMapPt(pt)
		self:SetPos(pt1:x(), pt1:y())
		terminal.desktop:SetMouseCapture(false)
		self.map:OnGraphEdited()
		return "break"
	end
end	


-- Classes for testing

DefineClass("TestGraphNode", "PropertyObject")

DefineClass.GraphNodeMath = {
	__parents = { "TestGraphNode" },
	properties = {
		{ id = "Operation", editor = "text", default = "" },
	},
	
	GraphLinkSockets = {
		{ id = "input1", name = "A", input = true, type = "number", },
		{ id = "input2", name = "B", input = true, type = "number", },
		{ id = "output", name = "Output", input = false, type = "number", },
	},
	EditorName = "Math Node",
}

DefineClass.GraphNodeBooleanCheck = {
	__parents = { "TestGraphNode" },
	
	GraphLinkSockets = {
		{ id = "input1", name = "InfoCheck", input = true, },
		{ id = "input2", name = "InfoGot", input = true, },
		{ id = "output1", name = "false", input = false, type = "boolean", },
		{ id = "output2", name = "true", input = false, type = "boolean", },
	},
	EditorName = "Boolean Node",
}

DefineClass.GraphNodeString = {
	__parents = { "TestGraphNode" },
	
	GraphLinkSockets = {
		{ id = "input1", name = "word", input = true, type = "string", },
		{ id = "input2", name = "another word", input = true, type = "string", },
		{ id = "input3", name = "even more word", input = true, type = "string", },
		{ id = "input4", name = "many a word", input = true, type = "string", },
		{ id = "output", name = "Sentence", input = false, type = "string", },
	},
	EditorName = "String Node",
}
