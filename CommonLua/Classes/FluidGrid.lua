local remove_entry = table.remove_entry
local max_grid_updates = 10
local MulDivRound = MulDivRound
local Min, Max, Clamp = Min, Max, Clamp
local HighestConsumePriority = config.FluidGridHighestConsumePriority or 1
local LowestConsumePriority = config.FluidGridLowestConsumePriority or 1
local BeyondHighestConsumePriority = HighestConsumePriority - 1


----- FluidGrid

DefineClass.FluidGrid = {
	__parents = { "InitDone" },
	grid_resource = "electricity",
	player = false,
	-- arrays with the various elements for faster access
	elements = false, -- all elements
	producers = false,
	consumers = false,
	storages = false,
	switches = false,
	-- smart connections
	smart_connections = 0,
	-- aggregated for the entire grid
	total_production = 0,
	total_throttled_production = 0,
	total_consumption = 0,
	total_variable_consumption = 0,
	total_charge = 0,
	total_discharge = 0,
	total_storage_capacity = 0,
	-- current
	current_storage_delta = 0,
	current_production = 0,
	current_production_delta = 0,
	current_throttled_production = 0,
	current_consumption = 0,
	current_variable_consumption = 0,
	current_storage = 0,
	-- visuals
	visual_mesh = false,
	visuals_thread = false,
	needs_visual_update = false,
	-- update
	update_thread = false,
	needs_update = false,
	update_consumers = false,
	consumers_supplied = false, -- can be false or a priority index - consumers with higher or same priority are supplied
	-- produce tick
	production_thread = false,
	production_interval = config.FluidGridProductionInterval or 10000, -- how often runs the production logic
	restart_supply_delay = config.FluidGridRestartDelay or 10000, -- after turning off, the grid will wait this amount of time to start in order to avoid cyclical grid restarts
	restart_supply_time = 0,
	
	LogChangedElements = empty_func,
}

---
--- Initializes a new FluidGrid instance.
--- This function sets up the various arrays to store the different elements of the grid,
--- ensures the consumer priority range is valid, and starts the necessary threads for
--- updating the grid and its visuals.
---
--- @param self FluidGrid The FluidGrid instance being initialized.
---
function FluidGrid:Init()
	self.elements = {}
	self.producers = {}
	self.consumers = {}
	assert(HighestConsumePriority <= LowestConsumePriority)
	for priority = HighestConsumePriority, LowestConsumePriority do
		self.consumers[priority] = { consumption = 0, variable_consumption = 0 }
	end
	self.storages = {}
	self.switches = {}
	self:RestartThreads()
end

---
--- Restarts the various threads used by the FluidGrid to update its state and visuals.
--- This function creates three separate threads:
--- - An update thread that periodically checks for changes to the grid and updates its state accordingly.
--- - A production thread that periodically runs the grid's production logic.
--- - A visuals thread that updates the grid's visual representation when needed.
---
--- @param self FluidGrid The FluidGrid instance whose threads are being restarted.
---
function FluidGrid:RestartThreads()
	DeleteThread(self.update_thread)
	self.update_thread = CreateGameTimeThread(function(self)
		local updates, last_element_count, last_update = 0, #self.elements
		while true do
			local now = GameTime()
			local elem_count = #self.elements
			if last_update ~= now or elem_count ~= last_element_count then
				last_update = now
				last_element_count = elem_count
				updates = 0
			end
			while self.needs_update do
				if updates == max_grid_updates then
					self:LogChangedElements()
					assert(false, "Infinite grid update recursion!")
					break
				end
				self.needs_update = false
				procall(self.UpdateGrid, self)
				updates = updates + 1
			end
			WaitWakeup()
		end
	end, self)
	
	DeleteThread(self.production_thread)
	self.production_thread = CreateGameTimeThread(function(self, production_interval)
		while true do
			Sleep(production_interval)
			procall(self.Production, self, production_interval)
		end
	end, self, self.production_interval)
	
	DeleteThread(self.visuals_thread)
	self.visuals_thread = CreateGameTimeThread(function()
		while true do
			while self.needs_visual_update do
				self.needs_visual_update = false
				procall(self.UpdateVisuals, self)
			end
			WaitWakeup()
		end
	end)
end

---
--- Finalizes and cleans up the FluidGrid instance.
---
--- This function is responsible for:
--- - Resetting the current consumption of all consumers in the grid
--- - Removing the grid reference from all elements in the grid
--- - Deleting the update, production, and visuals threads
--- - Destroying the visual mesh associated with the grid
--- - Sending a "FluidGridDestroyed" message
---
--- @param self FluidGrid The FluidGrid instance to be finalized.
---
function FluidGrid:Done()
	local grid_resource = self.grid_resource
	for priority = HighestConsumePriority, LowestConsumePriority do
		for _, consumer in ipairs(self.consumers[priority]) do
			if consumer.current_consumption > 0 and consumer.grid == self then
				local old = consumer.current_consumption
				consumer.current_consumption = 0
				consumer.owner:SetConsumption(grid_resource, old, 0)
			end
		end
	end
	for _, element in ipairs(self.elements) do
		if element.grid == self then
			element.grid = false
		end
	end
	DeleteThread(self.update_thread)
	self.update_thread = false
	DeleteThread(self.production_thread)
	self.production_thread = false
	DeleteThread(self.visuals_thread)
	self.visuals_thread = false
	DoneObject(self.visual_mesh)
	self.visual_mesh = false
	Msg("FluidGridDestroyed", self)
end

---
--- Adds an element to the FluidGrid.
---
--- This function is responsible for:
--- - Setting the grid reference of the element to the current FluidGrid instance
--- - Adding the element to the list of elements in the grid
--- - Updating the total production, throttled production, and producer lists if the element has production
--- - Adding the element's consumption to the appropriate consumer list
--- - Adding the element's charge, discharge, and storage capacity to the grid's totals
--- - Adding the element to the list of switches if it is a switch, and updating the smart connections
--- - Delaying an update to the grid and visuals if skip_update is not set
--- - Sending a "FluidGridAddElement" message
---
--- @param self FluidGrid The FluidGrid instance to add the element to.
--- @param element table The element to be added to the grid.
--- @param skip_update boolean (optional) If true, the grid and visuals will not be updated.
---
function FluidGrid:AddElement(element, skip_update)
	element.grid = self
	self.elements[#self.elements + 1] = element
	if element.production then
		self.total_production = self.total_production + element.production
		self.total_throttled_production = self.total_throttled_production + element.throttled_production
		self.producers[#self.producers + 1] = element
	end
	local consumption = element.consumption
	if consumption then
		local consumer_list = self.consumers[element.consume_priority]
		if element.variable_consumption then
			self.total_variable_consumption = self.total_variable_consumption + consumption
			consumer_list.variable_consumption = consumer_list.variable_consumption + consumption
		else
			self.total_consumption = self.total_consumption + consumption
			consumer_list.consumption = consumer_list.consumption + consumption
		end
		consumer_list[#consumer_list + 1] = element
	end
	if element.charge then
		self.total_charge = self.total_charge + element.charge
		self.total_discharge = self.total_discharge + element.discharge
		if element.discharge > 0 then
			self.current_storage = self.current_storage + element.current_storage
		end
		self.total_storage_capacity = self.total_storage_capacity + element.storage_capacity
		self.storages[#self.storages + 1] = element
	end
	if element.is_switch then
		self.switches[#self.switches + 1] = element
		self:UpdateSmartConnections()
	end

	if not skip_update then
		self:DelayedUpdateGrid(consumption)
		self:DelayedUpdateVisuals()
	end
	Msg("FluidGridAddElement", self, element)
end

---
--- Removes an element from the FluidGrid.
---
--- @param self FluidGrid The FluidGrid instance to remove the element from.
--- @param element table The element to be removed from the grid.
--- @param skip_update boolean (optional) If true, the grid and visuals will not be updated.
---
function FluidGrid:RemoveElement(element, skip_update)
	if element.grid ~= self then return end
	if element.current_consumption > 0 then
		local old = element.current_consumption
		element.current_consumption = 0
		element.owner:SetConsumption(self.grid_resource, old, 0)
	end
	element.grid = false
	remove_entry(self.elements, element)
	if element.production then
		self.total_production = self.total_production - element.production
		self.total_throttled_production = self.total_throttled_production - element.throttled_production
		remove_entry(self.producers, element)
	end
	local consumption = element.consumption
	if consumption then
		local consumer_list = self.consumers[element.consume_priority]
		if element.variable_consumption then
			self.total_variable_consumption = self.total_variable_consumption - consumption
			consumer_list.variable_consumption = consumer_list.variable_consumption - consumption
		else
			self.total_consumption = self.total_consumption - consumption
			consumer_list.consumption = consumer_list.consumption - consumption
		end
		remove_entry(consumer_list, element)
	end
	if element.current_storage then
		self.total_charge = self.total_charge - element.charge
		self.total_discharge = self.total_discharge - element.discharge
		if element.discharge > 0 then
			self.current_storage = self.current_storage - element.current_storage
		end
		self.total_storage_capacity = self.total_storage_capacity - element.storage_capacity
		remove_entry(self.storages, element)
	end
	if element.is_switch then
		remove_entry(self.switches, element)
		self:UpdateSmartConnections()
	end

	if #(self.elements or "") == 0 then
		self:delete()
		return
	end
	if not skip_update then
		self:DelayedUpdateGrid()
		self:DelayedUpdateVisuals()
	end
	Msg("FluidGridRemoveElement", self, element)
end

---
--- Counts the number of consumers in the FluidGrid that match the given filter function.
---
--- @param func function|nil The filter function to apply to each consumer. If not provided, a function that always returns true will be used.
--- @param ... any Additional arguments to pass to the filter function.
--- @return integer The number of consumers that match the filter function.
function FluidGrid:CountConsumers(func, ...)
	local count = 0
	func = func or return_true
	for priority = HighestConsumePriority, LowestConsumePriority do
		for _, consumer in ipairs(self.consumers[priority]) do
			if func(consumer, ...) then
				count = count + 1
			end
		end
	end
	return count
end

---
--- Schedules an update of the FluidGrid's grid. The update will be performed on the next call to `Wakeup()` on the `update_thread`.
---
--- @param update_consumers boolean|nil If provided, this value will be used to set the `update_consumers` flag. If not provided, the existing value of `update_consumers` will be used.
---
function FluidGrid:DelayedUpdateGrid(update_consumers)
	self.update_consumers = self.update_consumers or update_consumers
	self.needs_update = true
	Wakeup(self.update_thread)
end

---
--- Updates the FluidGrid's grid and consumption/production state.
---
--- @param update_consumers boolean|nil If provided, this value will be used to set the `update_consumers` flag. If not provided, the existing value of `update_consumers` will be used.
---
function FluidGrid:UpdateGrid(update_consumers)
	update_consumers = self.update_consumers or update_consumers
	self.update_consumers = false
	local total_production = self.total_production
	local total_discharge = self.total_discharge
	local current_consumption = 0
	local current_variable_consumption = 0
	local consumers_supplied = false
	-- limit restarting supply to lower priority consumers for some time
	local ConsumePriorityLimit = (GameTime() - self.restart_supply_time < 0) and (self.consumers_supplied or BeyondHighestConsumePriority) or LowestConsumePriority
	-- find out which priority consumers can consume
	local total_supply = total_production + total_discharge
	for priority = HighestConsumePriority, ConsumePriorityLimit do
		local consumer_list = self.consumers[priority]
		-- consumers of certain priority will consume only if all consumption and variable consumtion of higher priorities can be supplied
		assert(consumer_list)
		if #(consumer_list or "") > 0 and current_consumption + current_variable_consumption + consumer_list.consumption <= total_supply then
			consumers_supplied = priority
			current_consumption = current_consumption + current_variable_consumption + consumer_list.consumption
			current_variable_consumption = consumer_list.variable_consumption
			if current_consumption + current_variable_consumption >= total_supply then -- all supply is used
				current_variable_consumption = Min(current_variable_consumption, total_supply - current_consumption)
				break
			end
		end
	end
	assert(current_consumption <= self.total_consumption)
	current_consumption = current_consumption + current_variable_consumption
	assert(current_consumption <= total_supply)
	local storage_delta = Clamp(total_production - current_consumption, - total_discharge, self.total_charge)
	self.current_throttled_production = Min(total_production - current_consumption - storage_delta, self.total_throttled_production)
	self.current_storage_delta = storage_delta
	self.current_consumption = current_consumption
	self.current_production = total_production - self.current_throttled_production
	self.current_production_delta = self.current_production - current_consumption

	local old_consumers_supplied = self.consumers_supplied
	local old_current_variable_consumption = self.current_variable_consumption
	self.consumers_supplied = consumers_supplied
	self.current_variable_consumption = current_variable_consumption
	if consumers_supplied ~= old_consumers_supplied then
		update_consumers = true
		if (consumers_supplied or BeyondHighestConsumePriority) < (old_consumers_supplied or BeyondHighestConsumePriority) then -- degradation of supply
			self.restart_supply_time = GameTime() + self.restart_supply_delay
		end
		Msg("FluidGridConsumersSupplied", self, old_consumers_supplied, consumers_supplied)
	end
	if old_current_variable_consumption ~= current_variable_consumption then
		update_consumers = true
		Msg("FluidGridVariableConsumption", self, old_consumers_supplied, consumers_supplied)
	end

	if update_consumers then
		local grid_resource = self.grid_resource
		local consumers_variable_consumption = consumers_supplied and self.consumers[consumers_supplied].variable_consumption
		consumers_supplied = consumers_supplied or BeyondHighestConsumePriority
		for priority = HighestConsumePriority, LowestConsumePriority do
			for _, consumer in ipairs(self.consumers[priority]) do
				local consumption = priority > consumers_supplied and 0 -- lower priority than supplied
					or priority < consumers_supplied and consumer.consumption -- full supply to higher priority than supplied
					or consumer.variable_consumption and MulDivRound(consumer.consumption, current_variable_consumption, consumers_variable_consumption) or consumer.consumption
				local old_consumption = consumer.current_consumption
				if old_consumption ~= consumption then
					consumer.current_consumption = consumption
					consumer.owner:SetConsumption(grid_resource, old_consumption, consumption)
				end
			end
		end
	end
	ObjModifiedDelayed(self)
end

--- Schedules a delayed update of the visual representation of the FluidGrid.
-- This function is called when the visual representation of the FluidGrid needs to be updated,
-- such as when the consumers supplied or the variable consumption changes.
-- The actual update is performed in the `FluidGrid:UpdateVisuals()` function, which is
-- woken up by this function.
function FluidGrid:DelayedUpdateVisuals()
	self.needs_visual_update = true
	Wakeup(self.visuals_thread)
end

--- Updates the visual representation of the FluidGrid.
-- This function is called when the visual representation of the FluidGrid needs to be updated,
-- such as when the consumers supplied or the variable consumption changes.
-- The function iterates through the elements of the FluidGrid and adds the appropriate
-- visuals for each element, including the color of the grid and the joints. It also
-- updates the visual mesh of the FluidGrid if necessary.
function FluidGrid:UpdateVisuals()
	local active = self.consumers_supplied
	local color = active and const.PowerGridActiveColor or const.PowerGridInactiveColor
	local joint_color = active and const.PowerGridActiveJointColor or const.PowerGridInactiveJointColor
	local mesh_pstr = pstr("")
	local pos
	for i, element in ipairs(self.elements) do
		local owner = element.owner
		assert(IsValid(owner))
		if IsValid(owner) then
			pos = pos or owner:GetPos()
			owner:AddFluidGridVisuals(self.grid_resource, pos, color, joint_color, mesh_pstr)
		end
	end
	local mesh
	if #mesh_pstr > 0 then
		mesh = self.visual_mesh
		mesh = IsValid(mesh) and mesh or PlaceObject("Mesh")
		mesh:SetDepthTest(true)
		mesh:SetMesh(mesh_pstr)
		mesh:SetPos(pos)
	end
	if self.visual_mesh ~= mesh then
		DoneObject(self.visual_mesh)
		self.visual_mesh = mesh
	end
end

--- Updates the smart connections of the FluidGrid.
-- This function is called when the smart connections of the FluidGrid need to be updated,
-- such as when the switches in the grid change state.
-- The function calculates the new smart connection mask based on the current state of the
-- switches, and then updates the producers and consumers in the grid to reflect the
-- changes in the smart connections.
function FluidGrid:UpdateSmartConnections()
	local smart_connections = 0
	for _, switch in ipairs(self.switches) do
		smart_connections = smart_connections | switch.switch_mask
	end
	if self.smart_connections == smart_connections then return end
	local changed_connections = self.smart_connections ~ smart_connections
	self.smart_connections = smart_connections
	local grid_resource = self.grid_resource
	for _, producer in ipairs(self.producers) do
		if (producer.smart_connection or 0) & changed_connections ~= 0 then
			producer.owner:SmartConnectionChange(grid_resource)
		end
	end
	for priority = HighestConsumePriority, LowestConsumePriority do
		for _, consumer in ipairs(self.consumers[priority]) do
			if (consumer.smart_connection or 0) & changed_connections ~= 0 then
				consumer.owner:SmartConnectionChange(grid_resource)
			end
		end
	end
end

--- Checks if a given smart connection is currently on.
---
--- If no smart_connection is provided, this function will return true, as the lack of a
--- smart_connection indicates that the connection is always on.
---
--- @param smart_connection number|nil The smart connection mask to check.
--- @return boolean True if the smart connection is on, false otherwise.
function FluidGrid:IsSmartConnectionOn(smart_connection)
	if not smart_connection then return true end -- no smart_connection set, so it is on
	return (self.smart_connections & smart_connection) ~= 0
end

--- Performs production and consumption operations for the FluidGrid.
--
-- This function is called periodically to update the production and consumption of the
-- FluidGrid. It calculates the current throttled production for each producer, calls the
-- `OnProduce` callback on each producer to notify them of the production, calls the
-- `OnConsume` callback on each consumer to notify them of the consumption, and updates
-- the stored charge in the grid's storages based on the current storage delta.
--
-- The function also includes some developer-only assertions to verify that the grid's
-- storage values are consistent.
--
-- @param production_interval The time interval since the last production update.
function FluidGrid:Production(production_interval)
	local grid_resource = self.grid_resource
	-- producers
	local current_throttled_production = self.current_throttled_production
	local total_throttled_production = self.total_throttled_production
	for _, producer in ipairs(self.producers) do
		producer.current_throttled_production = total_throttled_production > 0
			and MulDivRound(producer.throttled_production, current_throttled_production, total_throttled_production) or 0
		local production = producer.production - producer.current_throttled_production
		producer.owner:OnProduce(grid_resource, production, production_interval)
	end
	-- consumers
	for priority = HighestConsumePriority, LowestConsumePriority do
		for _, consumer in ipairs(self.consumers[priority]) do
			consumer.owner:OnConsume(grid_resource, consumer.current_consumption, production_interval)
		end
	end
	-- storages
	local total_charge = self.total_charge
	local total_discharge = self.total_discharge
	local storage_delta = self.current_storage_delta
	if storage_delta > 0 and total_charge > 0 then
		for _, storage in ipairs(self.storages) do
			storage:AddStoredCharge(MulDivRound(storage_delta, storage.charge_efficiency * storage.charge, 100 * total_charge), self)
		end
	elseif storage_delta < 0 and total_discharge > 0 then
		for _, storage in ipairs(self.storages) do
			storage:AddStoredCharge(MulDivRound(storage_delta, storage.discharge, total_discharge), self)
		end
	end
	if Platform.developer then
		-- aggregate storage values and verify they match
		local current_storage, total_charge, total_discharge = 0, 0, 0
		for _, storage in ipairs(self.storages) do
			if storage.discharge > 0 then
				current_storage = current_storage + storage.current_storage
			end
			total_charge = total_charge + storage.charge
			total_discharge = total_discharge + storage.discharge
		end
		assert(self.current_storage == current_storage)
		assert(self.total_charge == total_charge)
		assert(self.total_discharge == total_discharge)
		self.current_storage = current_storage
		self.total_charge = total_charge
		self.total_discharge = total_discharge
	end
	self:DelayedUpdateGrid()
end

--- Merges the elements of the `grid` into the `new_grid`.
---
--- If `grid` and `new_grid` are the same, this function does nothing.
---
--- @param new_grid FluidGrid The grid to merge the elements into.
--- @param grid FluidGrid The grid to merge the elements from.

function MergeGrids(new_grid, grid) -- merges grid into new_grid
	if grid == new_grid then return end
	for i, element in ipairs(grid.elements) do
		new_grid:AddElement(element)
	end
	grid:delete()
end


----- FluidGridElementOwner

DefineClass.FluidGridElementOwner = {
	__parents = { "InitDone" },
}

-- callback when a resource consumption from the grid is modified
AutoResolveMethods.SetConsumption = true
--- Callback when a resource consumption from the grid is modified.
---
--- @param resource string The resource type.
--- @param old_amount number The previous consumption amount.
--- @param new_amount number The new consumption amount.
function FluidGridElementOwner:SetConsumption(resource, old_amount, new_amount)
end

-- callback when storage state changes - "empty", "full", "charging", "discharging"
--- Callback when the storage state of a grid element changes.
---
--- @param resource string The resource type.
--- @param state string The new storage state, can be "empty", "full", "charging", or "discharging".
function FluidGridElementOwner:SetStorageState(resource, state)
end

-- callback called each production_interval with the actual amount produced for the grid
--- Callback called each production_interval with the actual amount consumed from the grid.
---
--- @param resource string The resource type.
--- @param amount number The amount consumed.
--- @param production_interval number The production interval.
function FluidGridElementOwner:OnConsume(resource, amount, production_interval)
end


-- callback called each production_interval with the actual amount consumed from the grid
--- Callback called each production_interval with the actual amount consumed from the grid.
---
--- @param resource string The resource type.
--- @param amount number The amount consumed.
--- @param production_interval number The production interval.
function FluidGridElementOwner:OnConsume(resource, amount, production_interval)
end

-- callback called when the stored amount of a storage has changed
AutoResolveMethods.ChangeStoredAmount = true
--- Callback called when the stored amount of a storage has changed.
---
--- @param resource string The resource type.
--- @param storage number The new stored amount.
--- @param old_storage number The previous stored amount.
function FluidGridElementOwner:ChangeStoredAmount(resource, storage, old_storage)
end

-- callback called when a smart connection relevant to the grid element has changed
--- Callback called when a smart connection relevant to the grid element has changed.
---
--- @param resource string The resource type.
function FluidGridElementOwner:SmartConnectionChange(resource)
end

-- used to construct the visual mesh for the grid
--- Adds fluid grid visuals to the grid element.
---
--- @param grid_resource string The resource type of the grid.
--- @param origin table The origin position of the grid element.
--- @param color table The color of the grid element.
--- @param joint_color table The color of the grid element's joints.
--- @param mesh_pstr string The mesh pattern string for the grid element.
function FluidGridElementOwner:AddFluidGridVisuals(grid_resource, origin, color, joint_color, mesh_pstr)
end


----- FluidGridElement

DefineClass.FluidGridElement = {
	__parents = { "InitDone" },
	grid = false, -- the grid this element belongs to
	owner = false, -- inherits FluidGridElementOwner
	smart_connection = false, -- used by switch, consumer and producer
	smart_connection2 = false,
	-- producer
	production = false,
	throttled_production = 0, -- how much of the production can be throttled(not produced) when there is no demand for it
	current_throttled_production = 0, -- how much of the production is currently being throttled
	-- consumer
	consumption = false,
	variable_consumption = false, -- whether or not the consumer can work with any amount between 0 and consumption
	current_consumption = 0,
	consume_priority = config.FluidGridDefaultConsumePriority or HighestConsumePriority,
	-- storage
	storage_active = false,
	charge = false,
	discharge = false,
	storage_capacity = false,
	current_storage = false,
	max_charge = false,
	max_discharge = false,
	charge_efficiency = 100,
	storage_state = "", -- "empty", "charging", "discharging", "full"
	min_discharge_amount = 0, -- minumum stored amount before discharging
	-- is_connector
	is_connector = false,
	-- is_switch
	is_switch = false,
	switch_state = 0, -- a bitfield indicating which of our 2 smart connections are on (all combinations are valid)
	switch_mask = 0, -- a bitfield indicating which grid smart connections are on
	
	RegisterConsumptionChange = empty_func,
}

--- Creates a new fluid grid connector element.
---
--- @param owner table The owner of the fluid grid element.
--- @return table A new fluid grid connector element.
function NewFluidConnector(owner)
	assert(IsValid(owner))
	return FluidGridElement:new{
		owner = owner,
		is_connector = true,
	}
end

---
--- Creates a new fluid grid switch element.
---
--- @param owner table The owner of the fluid grid element.
--- @param consumption number The consumption of the switch.
--- @param variable_consumption boolean Whether the switch has variable consumption.
--- @return table A new fluid grid switch element.
function NewFluidSwitch(owner, consumption, variable_consumption)
	assert(IsValid(owner))
	return FluidGridElement:new{
		owner = owner,
		is_switch = true,
		smart_connection = 1,
		switch_mask = 1,
		consumption = consumption or false,
		variable_consumption = variable_consumption,
	}
end

--- Creates a new fluid grid producer element.
---
--- @param owner table The owner of the fluid grid element.
--- @param production number The production of the producer.
--- @param throttled_production number The throttled production of the producer.
--- @return table A new fluid grid producer element.
function NewFluidProducer(owner, production, throttled_production)
	assert(IsValid(owner))
	return FluidGridElement:new{
		owner = owner,
		production = production or 0,
		throttled_production = throttled_production or 0,
	}
end

--- Creates a new fluid grid consumer element.
---
--- @param owner table The owner of the fluid grid element.
--- @param consumption number The consumption of the consumer.
--- @param variable_consumption boolean Whether the consumer has variable consumption.
--- @return table A new fluid grid consumer element.
function NewFluidConsumer(owner, consumption, variable_consumption)
	assert(IsValid(owner))
	return FluidGridElement:new{
		owner = owner,
		consumption = consumption or 0,
		variable_consumption = variable_consumption,
	}
end

---
--- Creates a new fluid grid storage element.
---
--- @param owner table The owner of the fluid grid element.
--- @param storage_capacity number The maximum storage capacity of the storage element.
--- @param current_storage number The current amount of storage in the element.
--- @param max_charge number The maximum charge rate of the storage element.
--- @param max_discharge number The maximum discharge rate of the storage element.
--- @param charge_efficiency number The efficiency of charging the storage element.
--- @param min_discharge_amount number The minimum amount that can be discharged from the storage element.
--- @return table A new fluid grid storage element.
function NewFluidStorage(owner, storage_capacity, current_storage, max_charge, max_discharge, charge_efficiency, min_discharge_amount)
	assert(IsValid(owner))
	return FluidGridElement:new{
		owner = owner,
		charge = max_charge,
		discharge = 0,
		current_storage = current_storage,
		storage_capacity = storage_capacity,
		max_charge = max_charge,
		max_discharge = max_discharge,
		charge_efficiency = charge_efficiency,
		storage_state = "empty",
		min_discharge_amount = min_discharge_amount,
	}
end

--- Removes the fluid grid element from its associated grid and sets the grid reference to nil.
---
--- This function should be called when the fluid grid element is no longer needed, to ensure it is properly removed from the grid.
function FluidGridElement:Done()
	if self.grid then
		self.grid:RemoveElement(self)
		self.grid = nil
	end
end

--- Sets the production and throttled production values for the fluid grid element.
---
--- @param new_production number The new production value for the element.
--- @param new_throttled_production number The new throttled production value for the element.
--- @param skip_update boolean Whether to skip updating the grid after setting the new values.
--- @return boolean True if the production or throttled production values were changed, false otherwise.
function FluidGridElement:SetProduction(new_production, new_throttled_production, skip_update)
	assert(self.production) -- the element should already be a producer
	new_production = Max(new_production, 0)
	new_throttled_production = Max(new_throttled_production, 0)
	if self.production == new_production and self.throttled_production == new_throttled_production then return end
	local grid = self.grid
	if grid then
		grid.total_production = grid.total_production + new_production - self.production
		grid.total_throttled_production = grid.total_throttled_production - self.throttled_production + new_throttled_production
	end
	self.production = new_production
	self.throttled_production = new_throttled_production
	if grid and not skip_update then
		grid:DelayedUpdateGrid()
	end
	return true
end

--- Sets the consumption value for the fluid grid element.
---
--- @param new_consumption number The new consumption value for the element.
--- @param skip_update boolean Whether to skip updating the grid after setting the new value.
--- @return boolean True if the consumption value was changed, false otherwise.
function FluidGridElement:SetConsumption(new_consumption, skip_update)
	assert(self.consumption) -- the element should already be a consumer
	new_consumption = Max(new_consumption, 0)
	if self.consumption == new_consumption then return end
	self:RegisterConsumptionChange()
	local grid = self.grid
	if grid then
		local delta = new_consumption - self.consumption
		local consumer_list = grid.consumers[self.consume_priority]
		if self.variable_consumption then
			grid.total_variable_consumption = grid.total_variable_consumption + delta
			consumer_list.variable_consumption = consumer_list.variable_consumption + delta
		else
			grid.total_consumption = grid.total_consumption + delta
			consumer_list.consumption = consumer_list.consumption + delta
		end
	end
	self.consumption = new_consumption
	
	if grid and not skip_update then
		grid:DelayedUpdateGrid(true)
	end
	return true
end

--- Sets the consumption priority for the fluid grid element.
---
--- @param new_priority number The new consumption priority for the element. Must be between HighestConsumePriority and LowestConsumePriority.
--- @param skip_update boolean Whether to skip updating the grid after setting the new priority.
--- @return boolean True if the consumption priority was changed, false otherwise.
function FluidGridElement:SetConsumePriority(new_priority, skip_update)
	assert(self.consumption) -- the element should already be a consumer
	new_priority = Clamp(new_priority, HighestConsumePriority, LowestConsumePriority)
	if self.consume_priority == new_priority then return end
	self:RegisterConsumptionChange()
	local grid = self.grid
	if grid then
		local old_consumer_list = grid.consumers[self.consume_priority]
		local consumer_list = grid.consumers[new_priority]
		if self.variable_consumption then
			old_consumer_list.variable_consumption = old_consumer_list.variable_consumption - self.consumption
			consumer_list.variable_consumption = consumer_list.variable_consumption + self.consumption
		else
			old_consumer_list.consumption = old_consumer_list.consumption - self.consumption
			consumer_list.consumption = consumer_list.consumption + self.consumption
		end
		remove_entry(old_consumer_list, self)
		consumer_list[#consumer_list + 1] = self
	end
	self.consume_priority = new_priority
	
	if grid and not skip_update then
		grid:DelayedUpdateGrid(true)
	end
	return true
end


--- Sets the storage capacity for the fluid grid element.
---
--- @param new_storage_capacity number The new storage capacity for the element.
--- @return boolean True if the storage capacity was changed, false otherwise.
function FluidGridElement:SetStorageCapacity(new_storage_capacity)
	if self.storage_capacity == new_storage_capacity then return end
	local grid = self.grid
	if grid then
		grid.total_storage_capacity = grid.total_storage_capacity - self.storage_capacity + Max(new_storage_capacity, 0)
	end
	self.storage_capacity = new_storage_capacity
	if grid then
		grid:DelayedUpdateGrid()
	end
end

--- Sets the maximum charge and discharge rates for the fluid grid element.
---
--- @param max_charge number The new maximum charge rate for the element.
--- @param max_discharge number The new maximum discharge rate for the element.
--- @return boolean True if the storage settings were changed, false otherwise.
function FluidGridElement:SetStorage(max_charge, max_discharge)
	if self.max_charge == max_charge and self.max_discharge == max_discharge then return end
	self.max_charge = max_charge
	self.max_discharge = max_discharge
	local grid = self.grid
	self:UpdateStorageChargeDischarge(grid)
	if grid then
		grid:DelayedUpdateGrid()
	end
end

--- Updates the charge and discharge rates for the fluid grid element based on its current storage level and maximum charge/discharge rates.
---
--- @param grid FluidGrid The fluid grid that this element belongs to.
function FluidGridElement:UpdateStorageChargeDischarge(grid)
	local current_storage = self.current_storage
	local new_charge = Min(self.storage_capacity - current_storage, self.max_charge)
	local new_discharge = self.storage_state == "charging" and current_storage < self.min_discharge_amount and 0 
		or Min(current_storage, self.max_discharge)
	local old_charge, old_discharge = self.charge, self.discharge
	if new_charge == old_charge and new_discharge == old_discharge then return end
	self.charge = new_charge
	self.discharge = new_discharge
	if grid then
		grid.total_charge = grid.total_charge - old_charge + new_charge
		grid.total_discharge = grid.total_discharge - old_discharge + new_discharge
		if new_discharge ~= old_discharge then
			if new_discharge == 0 then
				-- remove current storage if max discharge has become 0
				grid.current_storage = grid.current_storage - current_storage
			elseif old_discharge == 0 then
				-- add current storage if max discharge has become > 0
				grid.current_storage = grid.current_storage + current_storage
			end
		end
	end
end

--- Adds a specified amount of charge to the fluid grid element.
---
--- @param delta number The amount of charge to add to the element.
--- @param grid FluidGrid The fluid grid that this element belongs to.
--- @return boolean True if the storage amount was changed, false otherwise.
function FluidGridElement:AddStoredCharge(delta, grid)
	assert(self.current_storage)
	local storage_capacity = self.storage_capacity
	local old_storage = self.current_storage
	local current_storage = Clamp(old_storage + delta, 0, storage_capacity)
	if current_storage == old_storage then return end
	self.current_storage = current_storage
	if self.discharge > 0 then
		grid.current_storage = grid.current_storage + current_storage - old_storage
	end
	self:UpdateStorageChargeDischarge(grid)

	local state
	if current_storage >= storage_capacity then
		state = "full"
	elseif current_storage <= 0 then
		state = "empty"
	elseif current_storage < old_storage then
		state = "discharging"
	else
		state = "charging"
	end
	if self.storage_state ~= state then
		self.storage_state = state
		self.owner:SetStorageState(grid.grid_resource, state)
	end
	self.owner:ChangeStoredAmount(grid.grid_resource, current_storage, old_storage)
end

--- Sets the stored amount of the fluid grid element.
---
--- @param amount number The new stored amount.
--- @return boolean True if the storage amount was changed, false otherwise.
function FluidGridElement:SetStoredAmount(amount)
	return self:AddStoredCharge(amount - self.current_storage, self.grid)
end

--- Sets the smart connection index for the fluid grid element.
---
--- @param smart_connection_index number The new smart connection index, or nil to clear the connection.
function FluidGridElement:SetSmartConnection(smart_connection_index)
	local smart_connection = smart_connection_index and (1 << (smart_connection_index - 1)) or false
	local old_value = self.smart_connection
	if old_value == smart_connection then return end
	self.smart_connection = smart_connection
	self:SetSwitchState(self.switch_state)
end

--- Gets the smart connection index for the fluid grid element.
---
--- @return number|nil The smart connection index, or nil if no smart connection is set.
function FluidGridElement:GetSmartConnection()
	local smart_connection = self.smart_connection
	local result = smart_connection and LastSetBit(smart_connection)
	return result and result + 1
end

--- Sets the smart connection index2 for the fluid grid element.
---
--- @param smart_connection_index number The new smart connection index2, or nil to clear the connection.
function FluidGridElement:SetSmartConnection2(smart_connection_index)
	local smart_connection2 = smart_connection_index and (1 << (smart_connection_index - 1)) or 0
	local old_value = self.smart_connection2
	if old_value == smart_connection2 then return end
	self.smart_connection2 = smart_connection2
	self:SetSwitchState(self.switch_state)
end

--- Gets the smart connection index2 for the fluid grid element.
---
--- @return number|nil The smart connection index2, or nil if no smart connection is set.
function FluidGridElement:GetSmartConnection2()
	local smart_connection2 = self.smart_connection2
	local result = smart_connection2 and LastSetBit(smart_connection2)
	return result and result + 1
end

--- Gets the current switch state of the fluid grid element.
---
--- @return number The current switch state.
function FluidGridElement:GetSwitchState()
	return self.switch_state
end

--- Sets the switch state of the fluid grid element.
---
--- This function updates the switch state of the fluid grid element and calculates the switch mask based on the current switch state and the smart connection settings. If the switch mask has changed, it triggers an update of the smart connections in the fluid grid.
---
--- @param state number The new switch state.
--- @return boolean True if the switch state was updated, false otherwise.
function FluidGridElement:SetSwitchState(state)
	self.switch_state = state
	local mask = ((state & 1 == 1) and self.smart_connection or 0)
		| ((state & 2 == 2) and self.smart_connection2 or 0)
	if self.switch_mask == mask then return end
	self.switch_mask = mask
	if self.grid then
		self.grid:UpdateSmartConnections()
	end
	return true
end

--- Toggles the fluid grid for the power grid of the FluidGridElementOwner.
---
--- This function is used to toggle the visibility of the fluid grid for debugging purposes.
---
--- @param self FluidGridElementOwner The owner of the fluid grid.
function FluidGridElementOwner:AsyncCheatShowGrid()
	DbgToggleFluidGrid(self:GetPowerGrid())
end

if Platform.developer then

FluidGridElement.grid_changed = false
FluidGridElement.grid_changes = 0
--- Registers a change in the consumption of the fluid grid element.
---
--- This function is called when the consumption of the fluid grid element changes. It updates the `grid_changed` and `grid_changes` properties to track the number of changes to the grid.
---
--- @param self FluidGridElement The fluid grid element instance.
function FluidGridElement:RegisterConsumptionChange()
	local now = GameTime()
	if self.grid_changed == now then
		self.grid_changes = self.grid_changes + 1
	else
		self.grid_changed = now
		self.grid_changes = nil
	end
end


---
--- Logs the fluid grid elements that have changed the most in the last `max_grid_updates` grid updates.
---
--- This function iterates through all the fluid grid elements and finds the ones that have had the most changes in the last `max_grid_updates` grid updates. It then prints out the top 10 most changed elements, including the number of changes and the owner of the element (if available).
---
--- @param self FluidGrid The fluid grid instance.
function FluidGrid:LogChangedElements()
	local changed = {}
	for _, element in ipairs(self.elements) do
		if element.grid_changes > 0 then
			changed[#changed + 1] = element
		end
	end
	table.sortby_field_descending(changed, "grid_changes")
	print("Most changed elements in the last", max_grid_updates, "grid updates:")
	for i=1,Min(#changed, 10) do
		local element = changed[i]
		local owner = element.owner
		print(owner and owner.class or "<no owner>", element.grid_changes)
	end
end

end -- Platform.developer

--[[ Test
function FluidTest()
	local grid = FluidGrid:new()
	local owner = FluidGridElementOwner:new()
	local tc = NewFluidConsumer(owner, 1000)
	local tp = NewFluidProducer(owner, 2000)
	local ts = NewFluidStorage(owner, 100000, 0, 5000, 5000)
	owner.SetStorageState = function (self, res, state) print("Storage", tostring(self), res, state, ts.current_storage) end
	owner.SetConsumption = function (self, res, amount) print("Consumer", tostring(self), res, amount == 0 and "off" or amount) end
	grid:AddElement(tc)
	grid:AddElement(tp)
	grid:AddElement(ts)
	rawset(_G, "tg", grid)
	rawset(_G, "tc", tc)
	rawset(_G, "tp", tp)
	rawset(_G, "ts", ts)
	return grid
end
--]]