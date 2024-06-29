if not const.rfSupply or not config.ResourceSimulation then
	return
end

local rfWork              = const.rfWork
local rfSupply            = const.rfSupply
local rfDemand            = const.rfDemand
local rfCanExecuteAlone   = const.rfCanExecuteAlone
local rfPostInQueue       = const.rfPostInQueue
local rfSupplyDemand      = rfSupply + rfDemand
local rfPostInQueueFlags  = rfDemand + rfWork + rfCanExecuteAlone + rfPostInQueue
local rfStorageDepot      = const.rfStorageDepot
local remove_entry = table.remove_entry
local table_find = table.find
local insert = table.insert

-- read settings from the TaskRequest const group in the Consts editor
local MinBuildingPriority        = -1
local DefBuildingPriority        = 2
local MaxBuildingPriority        = 3
local CommandCenterMaxRadius     = 35
local CommandCenterDefaultRadius = 35
function OnMsg.ClassesPreprocess() -- project-specific constants are loaded after TaskRequest.lua, give them time to kick in
	local settings = const.TaskRequest
	if settings and not Platform.ged then
		MinBuildingPriority        = settings.MinBuildingPriority or MinBuildingPriority
		DefBuildingPriority        = settings.DefBuildingPriority or DefBuildingPriority
		MaxBuildingPriority        = settings.MaxBuildingPriority or MaxBuildingPriority
		CommandCenterMaxRadius     = settings.CommandCenterMaxRadius or CommandCenterMaxRadius
		CommandCenterDefaultRadius = settings.CommandCenterDefaultRadius or CommandCenterDefaultRadius
		
		TaskRequestHub.work_radius = CommandCenterDefaultRadius
	end
end

-- TaskRequester
MapVar("TaskResourceIdx", {})

function OnMsg.PersistGatherPermanents(permanents)
	local meta = Request_GetMeta()
	permanents["TaskRequest.meta"] = meta
	permanents["TaskRequest.GetResource"] = meta.GetResource
	permanents["TaskRequest.GetTargetAmount"] = meta.GetTargetAmount
	permanents["TaskRequest.SetTargetAmount"] = meta.SetTargetAmount
	permanents["TaskRequest.GetBuilding"] = meta.GetBuilding
	permanents["TaskRequest.AssignUnit"] = meta.AssignUnit
	permanents["TaskRequest.UnassignUnit"] = meta.UnassignUnit
	permanents["TaskRequest.FulfillPartial"] = meta.FulfillPartial
	permanents["TaskRequest.GetFreeUnitSlots"] = meta.GetFreeUnitSlots
	permanents["TaskRequest.IsAnyFlagSet"] = meta.IsAnyFlagSet
end

--- Updates the source building for all requests associated with the old building.
---
--- @param old TaskRequester The old building that the requests were associated with.
--- @param new TaskRequester The new building to associate the requests with, or nil to disassociate them.
function Request_UpdateSource(old, new)
	for _, request in ipairs(old:GetAllRequests()) do
		request:SetBuilding(new or old)
	end
end

----

--- Defines the TaskRequester class, which is a parent class for objects that can request tasks.
---
--- @class TaskRequester
--- @field task_requests table|false A table of task requests associated with this TaskRequester, or false if none.
--- @field command_centers table|false A table of command centers associated with this TaskRequester, or false if none.
--- @field priority number The priority of this TaskRequester, which defaults to DefBuildingPriority.
--- @field auto_connect boolean Whether this TaskRequester should automatically connect to command centers, which defaults to true.
--- @field supply_dist_modifier number A modifier (in percents) of the distance when considering this supply, which defaults to 100.
DefineClass.TaskRequester = {
	__parents = { "Object" },
	task_requests = false,
	command_centers = false,
	priority = DefBuildingPriority,
	auto_connect = true,
	supply_dist_modifier = 100, -- modifier (percents) of the distance when considering this supply (0-255)
}

--- Called when the TaskRequester is initialized.
---
--- This function creates the resource requests for the TaskRequester and
--- connects it to any associated command centers if the `auto_connect`
--- flag is set.
function TaskRequester:GameInit()
	self:CreateResourceRequests()
	if self.auto_connect then
		self:ConnectToCommandCenters()
	end
end

--- Disconnects the TaskRequester from any associated command centers, removes all task requests associated with the TaskRequester, clears the TaskRequester's game flags, and sets the task_requests field to nil.
---
--- This function is called when the TaskRequester is done and needs to be cleaned up.
function TaskRequester:Done()
	self:DisconnectFromCommandCenters()
	for _, request in ipairs(self:GetAllRequests()) do
		request:SetBuilding(false)
	end
	self:ClearGameFlags(const.gofTaskRequest)
	self.task_requests = nil
end

--- Returns the visual building associated with this TaskRequester.
---
--- @param res_transporter ResourceTransporter The resource transporter that is requesting the visual building.
--- @return Building The visual building associated with this TaskRequester.
function TaskRequester:GetVisualBuilding(res_transporter)
	return self
end

AutoResolveMethods.OnPickUpResources = true
-- function TaskRequester:OnPickUpResources(res_transporter, res, amount)
TaskRequester.OnPickUpResources = empty_func

AutoResolveMethods.OnDropOffResources = true
-- function TaskRequester:OnDropOffResources(res_transporter, res, amount)
TaskRequester.OnDropOffResources = empty_func

--- Returns all the task requests associated with this TaskRequester.
---
--- @return table<Request> All the task requests associated with this TaskRequester.
function TaskRequester:GetAllRequests()
	return self.task_requests or empty_table
end

function TaskRequester:CreateResourceRequests()
end

--- Adds a work request to the TaskRequester.
---
--- @param resource string The resource to request.
--- @param amount number The amount of the resource to request.
--- @param flags number The flags to set on the request.
--- @param max_units number The maximum number of units that can fulfill the request.
--- @return Request The newly created request.
function TaskRequester:AddWorkRequest(resource, amount, flags, max_units)
	flags = bor(flags or 0, rfWork, rfPostInQueue)
	return self:AddRequest(resource, amount, flags, max_units)
end

--- Adds a demand request to the TaskRequester.
---
--- @param resource string The resource to request.
--- @param amount number The amount of the resource to request.
--- @param flags number The flags to set on the request.
--- @param max_units number The maximum number of units that can fulfill the request.
--- @param desired_amount number The desired amount of the resource.
--- @return Request The newly created request.
function TaskRequester:AddDemandRequest(resource, amount, flags, max_units, desired_amount)
	flags = bor(flags or 0, rfDemand, rfPostInQueue)
	return self:AddRequest(resource, amount, flags, max_units, desired_amount)
end

--- Adds a supply request to the TaskRequester.
---
--- @param resource string The resource to request.
--- @param amount number The amount of the resource to request.
--- @param flags number The flags to set on the request.
--- @param max_units number The maximum number of units that can fulfill the request.
--- @param desired_amount number The desired amount of the resource.
--- @return Request The newly created request.
function TaskRequester:AddSupplyRequest(resource, amount, flags, max_units, desired_amount)
	flags = bor(flags or 0, rfSupply)
	return self:AddRequest(resource, amount, flags, max_units, desired_amount)
end

--- Adds a new request to the TaskRequester.
---
--- @param resource string The resource to request.
--- @param amount number The amount of the resource to request.
--- @param flags number The flags to set on the request.
--- @param max_units number The maximum number of units that can fulfill the request.
--- @param desired_amount number The desired amount of the resource.
--- @return Request The newly created request.
function TaskRequester:AddRequest(resource, amount, flags, max_units, desired_amount)
	local request = Request_New(self, resource, amount, flags, max_units or -1, desired_amount or 0, self.supply_dist_modifier)
	if self.task_requests then
		self.task_requests[#self.task_requests + 1] = request
	else
		self.task_requests = { request }
	end
	for _, center in ipairs(self.command_centers) do
		center:_InternalAddRequest(request, self)
	end
	return request
end

--- Removes a request from the TaskRequester.
---
--- @param request Request The request to remove.
function TaskRequester:RemoveRequest(request)
	remove_entry(self.task_requests, request)
	for _, center in ipairs(self.command_centers) do
		center:_InternalRemoveRequest(request)
	end
	request:SetBuilding(false)
end

--- Adds a command center to the TaskRequester.
---
--- @param center CommandCenter The command center to add.
--- @return boolean True if the command center was added successfully, false otherwise.
function TaskRequester:AddCommandCenter(center)
	assert(center)
	if not center then
		return
	end
	if self.command_centers then
		if table_find(self.command_centers, center) then return false end
		self.command_centers[#self.command_centers + 1] = center
	else
		self.command_centers = { center }
	end
	center:AddBuilding(self)
	return true
end

--- Removes a command center from the TaskRequester.
---
--- @param center CommandCenter The command center to remove.
--- @return boolean True if the command center was removed successfully, false otherwise.
function TaskRequester:RemoveCommandCenter(center)
	assert(center)
	if center and self.command_centers and remove_entry(self.command_centers, center) then
		center:RemoveBuilding(self)
		return true
	end
end

--- Sets the priority of the TaskRequester.
---
--- When the priority is changed, the TaskRequester is removed from and then re-added to all its associated CommandCenters.
---
--- @param priority number The new priority for the TaskRequester.
function TaskRequester:SetPriority(priority)
	if self.priority == priority then return end
	for _, center in ipairs(self.command_centers) do
		center:RemoveBuilding(self)
	end
	self.priority = priority
	for _, center in ipairs(self.command_centers) do
		center:AddBuilding(self)
	end
end

--- Returns the priority for the given request.
---
--- If the request has the `rfStorageDepot` flag set, the priority is 0. Otherwise, the priority is the TaskRequester's priority.
---
--- @param req TaskRequest The request to get the priority for.
--- @return number The priority for the request.
function TaskRequester:GetPriorityForRequest(req)
	if req:IsAnyFlagSet(rfStorageDepot) then
		return 0
	else
		return self.priority
	end
end

function TaskRequester:ShouldAddRequestAtCurrentIndex(req)
end

function TaskRequester:OnAddedToTaskRequestHub(hub)
end

function TaskRequester:OnRemovedFromTaskRequestHub(hub)
end

local command_center_search = function (center, building, dist_obj)
	if center.accept_requester_connects and center.work_radius >= center:GetDist2D(dist_obj or building) then
		building:AddCommandCenter(center)
	end
end

--- Connects the TaskRequester to all CommandCenters within the CommandCenterMaxRadius.
---
--- This function iterates over all CommandCenters and adds the TaskRequester to any CommandCenter that is within the CommandCenterMaxRadius and accepts requester connections.
---
--- @param self TaskRequester The TaskRequester instance.
function TaskRequester:ConnectToCommandCenters()
	MapForEach(self, CommandCenterMaxRadius, "TaskRequestHub", command_center_search, self)
end

--- Connects the TaskRequester to all CommandCenters within the CommandCenterMaxRadius of the given other_building.
---
--- This function iterates over all CommandCenters and adds the TaskRequester to any CommandCenter that is within the CommandCenterMaxRadius of the other_building and accepts requester connections.
---
--- @param self TaskRequester The TaskRequester instance.
--- @param other_building any The other building to use for the CommandCenterMaxRadius search.
function TaskRequester:ConnectToOtherBuildingCommandCenters(other_building)
	MapForEach(other_building, CommandCenterMaxRadius, "TaskRequestHub", command_center_search, self, other_building)
end

--- Disconnects the TaskRequester from all CommandCenters it is currently connected to.
---
--- This function iterates over all CommandCenters that the TaskRequester is connected to and removes the connection.
---
--- @param self TaskRequester The TaskRequester instance.
function TaskRequester:DisconnectFromCommandCenters()
	local command_centers = self.command_centers or ""
	while #command_centers > 0 do
		self:RemoveCommandCenter(command_centers[#command_centers])
	end
end

----

--- Represents a hub for managing task requests from various sources.
---
--- The TaskRequestHub is responsible for maintaining a priority queue of task requests, as well as supply and demand queues for different resource priorities. It also manages the connection and disconnection of task requesters to the hub.
---
--- @class TaskRequestHub
--- @field work_radius number The radius within which the hub will connect to task requesters.
--- @field priority_queue table A table of priority queues, one for each priority level.
--- @field supply_queues table A table of supply queues, one for each priority level.
--- @field demand_queues table A table of demand queues, one for each priority level.
--- @field are_requesters_connected boolean Indicates whether task requesters are currently connected to the hub.
--- @field auto_connect_requesters_at_start boolean Indicates whether task requesters should be automatically connected to the hub at the start of the game.
--- @field accept_requester_connects boolean Indicates whether the hub will accept connections from task requesters.
--- @field under_construction boolean Indicates whether the hub is currently under construction.
--- @field restrictor_tables boolean Indicates whether the hub has any restrictor tables.
--- @field connected_task_requesters table A table of all task requesters currently connected to the hub.
--- @field lap_start number The start time of the current lap.
--- @field lap_time number The duration of the current lap.
DefineClass.TaskRequestHub = {
	__parents = { "SyncObject" },
	work_radius = CommandCenterDefaultRadius,
	
	priority_queue = false,
	supply_queues = false,
	demand_queues = false,
	
	are_requesters_connected = false,
	auto_connect_requesters_at_start = false,
	accept_requester_connects = false,
	
	under_construction = false,
	restrictor_tables = false,
	
	connected_task_requesters = false, -- all connected task requesters, so we can disconnect gracefully to requesters outside of our work range
	
	lap_start = 0,
	lap_time = 0,
}

--- Initializes the TaskRequestHub object.
---
--- This function sets up the various queues and data structures used by the TaskRequestHub to manage task requests. It initializes the following:
---
--- - `connected_task_requesters`: A table to store all the task requesters currently connected to the hub.
--- - `under_construction`: A table to store task requesters that are currently under construction.
--- - `priority_queue`: A table of priority queues, one for each priority level.
--- - `supply_queues`: A table of supply queues, one for each priority level.
--- - `demand_queues`: A table of demand queues, one for each priority level.
---
--- The priority, supply, and demand queues are initialized for the range of priority levels from `MinBuildingPriority` to `MaxBuildingPriority`.
function TaskRequestHub:Init()
	self.connected_task_requesters = {}
	self.under_construction = {}
	
	-- priority queue lists requests per priority
	self.priority_queue = {}
	-- queues are per priority per resource (priorities include 0 for StorageDepot)
	self.supply_queues = {}
	self.demand_queues = {}
	for priority = MinBuildingPriority, MaxBuildingPriority do
		self.priority_queue[priority] = {}
		self.supply_queues[priority] = {}
		self.demand_queues[priority] = {}
	end
end

--- Initializes the TaskRequestHub object and optionally connects task requesters at the start.
---
--- This function is called during the game initialization process. It sets the `lap_start` time to the current game time, and if `auto_connect_requesters_at_start` is true, it calls the `ConnectTaskRequesters` function to connect all task requesters within the hub's work radius.
---
--- @function GameInit
--- @return nil
function TaskRequestHub:GameInit()
	self.lap_start = GameTime()

	if self.auto_connect_requesters_at_start then
		self:Notify("ConnectTaskRequesters")
	end
end

--- Disconnects all task requesters that are currently connected to the TaskRequestHub.
---
--- This function is called when the TaskRequestHub is done processing task requests. It iterates through the list of connected task requesters and removes the command center connection for each one.
function TaskRequestHub:Done()
	self:DisconnectTaskRequesters()
end

--- Connects all task requesters within the TaskRequestHub's work radius to the hub.
---
--- This function iterates through all buildings within the hub's work radius that have the "TaskRequester" tag, and adds them as command centers to the hub if they have the `auto_connect` flag set and are not already part of a game initialization thread.
---
--- @function ConnectTaskRequesters
--- @return nil
function TaskRequestHub:ConnectTaskRequesters()
	if self.are_requesters_connected then return end
	local resource_search = function (building, center)
		if building.auto_connect and not GameInitThreads[building] then
			building:AddCommandCenter(center)
		end
	end
	MapForEach(self, self.work_radius, "TaskRequester", resource_search, self)
	self.are_requesters_connected = true
end

--- Disconnects all task requesters that are currently connected to the TaskRequestHub.
---
--- This function iterates through the list of connected task requesters and removes the command center connection for each one. It then sets the `are_requesters_connected` flag to `false`.
---
--- @function DisconnectTaskRequesters
--- @return nil
function TaskRequestHub:DisconnectTaskRequesters()
	while #self.connected_task_requesters > 0 do
		local bld = self.connected_task_requesters[#self.connected_task_requesters]
		if bld then
			bld:RemoveCommandCenter(self)
		end
	end
	self.are_requesters_connected = false
end

--- Adds a building to the TaskRequestHub.
---
--- This function is called when a new building with the "TaskRequester" tag is added to the game world. It iterates through the building's task requests and adds them to the appropriate queues in the TaskRequestHub. It then adds the building to the list of connected task requesters.
---
--- @param building Building The building to add to the TaskRequestHub.
--- @return nil
function TaskRequestHub:AddBuilding(building)
	assert(not table.find_value(self.connected_task_requesters, building))
	for _, request in ipairs(building.task_requests) do
		self:_InternalAddRequest(request, building)
	end
	insert(self.connected_task_requesters, building)
	building:OnAddedToTaskRequestHub(self)
end

--- Determines whether a task request should be posted in the priority queue.
---
--- This function checks if the given task request has any of the flags set that indicate the request should be posted in the priority queue.
---
--- @param request TaskRequest The task request to check.
--- @return boolean True if the request should be posted in the priority queue, false otherwise.
function ShouldPostRequestInQueue(request)
	return request:IsAnyFlagSet(rfPostInQueueFlags)
end

--- Adds a task request to the appropriate queues in the TaskRequestHub.
---
--- This function is called when a new task request is added to a building that is connected to the TaskRequestHub. It determines the priority of the request based on the building's priority for the request, and adds it to the appropriate supply or demand queue. If the request should be posted in the priority queue, it is also added to the priority queue.
---
--- @param request TaskRequest The task request to add.
--- @param building Building The building that the task request belongs to.
--- @return nil
function TaskRequestHub:_InternalAddRequest(request, building)
	assert(Request_IsTask(request))
	local resource = request:GetResource()
	local priority = building:GetPriorityForRequest(request)
	if request:IsAnyFlagSet(rfSupplyDemand) then
		local queue = request:IsAnyFlagSet(rfSupply) and self.supply_queues[priority] or self.demand_queues[priority]
		local rqueue = queue[resource]
		if rqueue then
			rqueue[#rqueue + 1] = request
		else
			queue[resource] = { request }
		end
	end
	if ShouldPostRequestInQueue(request) then
		local p_queue = self.priority_queue[priority]
		if building:ShouldAddRequestAtCurrentIndex(request) then
			local idx = p_queue.index or 1
			if idx > #p_queue + 1 then
				idx = 1
			end
			insert(p_queue, idx, request)
		else
			insert(p_queue, request)
		end
	end
end

local function RemoveRequest(res_to_requests, res, request)
	local requests = res_to_requests[res]
	if requests and remove_entry(requests, request) == 1 and #requests == 0 then
		res_to_requests[res] = nil
	end
end

---
--- Removes a building from the TaskRequestHub.
---
--- This function is called when a building is removed from the game. It removes all task requests associated with the building from the various queues in the TaskRequestHub.
---
--- @param building Building The building to remove from the TaskRequestHub.
--- @return nil
function TaskRequestHub:RemoveBuilding(building)
	assert(table.find_value(self.connected_task_requesters, building))
	local task_requests = building.task_requests or empty_table
	local supply_queues = self.supply_queues
	local demand_queues = self.demand_queues
	for priority = MinBuildingPriority, MaxBuildingPriority do
		local s_requests = supply_queues[priority]
		local d_requests = demand_queues[priority]
		local priority_queue = self.priority_queue[priority]
		for _, request in ipairs(task_requests) do
			local resource = request and request:GetResource()
			RemoveRequest(s_requests, resource, request)
			RemoveRequest(d_requests, resource, request)
			remove_entry(priority_queue, request)
		end
	end
	remove_entry(self.connected_task_requesters, building)
	building:OnRemovedFromTaskRequestHub(self)
end

---
--- Removes a request from the various queues in the TaskRequestHub.
---
--- This function is called internally to remove a request from the supply queues, demand queues, and priority queue.
---
--- @param request TaskRequest The request to remove from the queues.
--- @return nil
function TaskRequestHub:_InternalRemoveRequest(request)
	local supply_queues = self.supply_queues
	local demand_queues = self.demand_queues
	local priority_queue = self.priority_queue
	for priority = MinBuildingPriority, MaxBuildingPriority do
		local resource = request and request:GetResource()
		RemoveRequest(supply_queues[priority], resource, request)
		RemoveRequest(demand_queues[priority], resource, request)
		remove_entry(priority_queue[priority], request)
	end
end

local Request_FindDemand_C = Request_FindDemand
---
--- Finds a demand request that matches the given criteria.
---
--- This function is used to find a demand request in the TaskRequestHub that meets the specified requirements. It searches the demand queues and under-construction requests to find a suitable request.
---
--- @param requester table The requester object that is looking for a demand request.
--- @param resource string The resource type being requested.
--- @param amount number The amount of the resource being requested.
--- @param min_priority number The minimum priority level to consider.
--- @param ignore_flags table A table of flags to ignore when matching requests.
--- @param required_flags table A table of flags that must be present in the request.
--- @param requestor_prio number The priority level of the requester.
--- @param exclude_building table The building to exclude from the search.
--- @param measure_from table The position to measure distance from.
--- @param max_dist number The maximum distance to consider.
--- @return table|nil The found demand request, or nil if no suitable request was found.
function TaskRequestHub:FindDemandRequest(requester, resource, amount, min_priority, ignore_flags, required_flags, requestor_prio, exclude_building, measure_from, max_dist)
	assert(self.under_construction)
	return Request_FindDemand_C(
		requester, self.demand_queues, self.under_construction, self.restrictor_tables, resource, amount,
		min_priority, ignore_flags, required_flags, requestor_prio,
		exclude_building, requester.unreachable_targets, measure_from, max_dist)
end

local Request_FindSupply_C = Request_FindSupply
---
--- Finds a supply request that matches the given criteria.
---
--- This function is used to find a supply request in the TaskRequestHub that meets the specified requirements. It searches the supply queues to find a suitable request.
---
--- @param requester table The requester object that is looking for a supply request.
--- @param resource string The resource type being requested.
--- @param amount number The amount of the resource being requested.
--- @param min_priority number The minimum priority level to consider.
--- @param ignore_flags table A table of flags to ignore when matching requests.
--- @param required_flags table A table of flags that must be present in the request.
--- @param exclude_building table The building to exclude from the search.
--- @param measure_from table The position to measure distance from.
--- @param max_dist number The maximum distance to consider.
--- @return table|nil The found supply request, or nil if no suitable request was found.
function TaskRequestHub:FindSupplyRequest(requester, resource, amount, min_priority, ignore_flags, required_flags, exclude_building, measure_from, max_dist)
	return Request_FindSupply_C(
		requester, self.supply_queues, resource, amount,
		min_priority, ignore_flags, required_flags,
		exclude_building, requester.unreachable_targets,
		measure_from, max_dist)
end

local Request_FindTask_C = Request_FindTask
---
--- Finds a task request that matches the given criteria.
---
--- This function is used to find a task request in the TaskRequestHub that meets the specified requirements. It searches the priority queue, supply queues, demand queues, and under-construction requests to find a suitable request.
---
--- @param agent table The agent object that is looking for a task request.
--- @param flags table A table of flags to use when matching requests.
--- @return table|nil The found task request, or nil if no suitable request was found.
--- @return table|nil The found paired task request, or nil if no paired request was found.
--- @return string The resource type of the found request.
--- @return number The amount of the resource requested.
--- @return number The priority level of the found request.
function TaskRequestHub:FindTask(agent, flags)
	local request_lap, request, pair_request, resource, amount, priority = Request_FindTask_C(
		self.priority_queue, self.supply_queues, self.demand_queues,
		self.under_construction, self.restrictor_tables,
		ResourceUnits, agent and agent.unreachable_targets, flags)
	if request_lap then
		local time = GameTime()
		self.lap_time = time - self.lap_start
		self.lap_start = time
	end
	return request, pair_request, resource, amount, priority
end

----

if Platform.developer then

function FindTaskRequestReferences()
	return FindReferences(Request_IsTask, nil, true)
end

end

