local ai_debug = Platform.developer and Platform.pc
local bias_base = 1000000 -- fixed point value equivalent to 1 or 100%

DefineClass.DumbAIPlayer = {
	__parents = { "InitDone" },
	
	actions = false,
	action_log = false,
	log_size = 10,
	running_actions = false,
	biases = false,
	resources = false,
	display_name = false,
	
	absolute_actions = 10,
	absolute_threshold = 10000,
	relative_threshold = 50, -- percent of the highest eval
	think_interval = 1000,

	seed = 0,
	think_thread = false,
	ai_start = 0,

	GedEditor = "DumbAIDebug",
	
	-- production
	production_interval = 60000,
	next_production = 0,
	production_rules = false,
	next_production_times = false,
}

--- Initializes the DumbAIPlayer instance.
-- This function sets up the initial state of the DumbAIPlayer, including:
-- - Initializing the `actions`, `action_log`, `running_actions`, `biases`, and `resources` tables.
-- - Setting the default resource values from the `Presets.AIResource.Default` table.
-- - Setting the `ai_start` time to the current game time.
-- - Initializing the `production_rules` and `next_production` time.
-- - Setting up a weak-keyed metatable for `next_production_times`.
function DumbAIPlayer:Init()
	self.actions = {}
	self.action_log = {}
	self.running_actions = {}
	self.biases = {}
	self.resources = {}
	for _, def in ipairs(Presets.AIResource.Default) do
		self.resources[def.id] = 0
	end
	self.ai_start = GameTime()
	self.production_rules = {}
	self.next_production = GameTime()
	self.next_production_times = setmetatable({}, weak_keys_meta)
end

--- Finalizes the DumbAIPlayer instance.
-- This function is called when the DumbAIPlayer is being deleted. It performs the following actions:
-- - Deletes the `think_thread` thread associated with the DumbAIPlayer.
-- - Notifies the GED (Game Editor) that the DumbAIPlayer object has been deleted.
function DumbAIPlayer:Done()
	DeleteThread(self.think_thread)
	GedObjectDeleted(self)
end

--- Adds an AI definition to the DumbAIPlayer instance.
-- This function performs the following actions:
-- - Adds all the actions from the `ai_def` table to the `actions` table of the DumbAIPlayer.
-- - Adds the initial resources specified in the `ai_def` table to the `resources` table of the DumbAIPlayer.
-- - Adds all the production rules from the `ai_def` table to the `production_rules` table of the DumbAIPlayer.
-- - Adds all the biases from the `ai_def` table to the `biases` table of the DumbAIPlayer, using the `AddBias` function.
-- @param ai_def The AI definition table to be added to the DumbAIPlayer.
function DumbAIPlayer:AddAIDef(ai_def)
	if not ai_def then return end
	local actions = self.actions
	for _, action in ipairs(ai_def) do
		actions[#actions + 1] = action
	end
	local resources = self.resources
	for _, res in ipairs(ai_def.initial_resources) do
		local resource = res.resource
		resources[resource] = resources[resource] + res:Amount()
	end
	local production_rules = self.production_rules
	for _, rule in ipairs(ai_def.production_rules or empty_table) do
		production_rules[#production_rules + 1] = rule
	end
	local label = "AIDef " .. ai_def.id
	for _, bias in ipairs(ai_def.biases) do
		self:AddBias(bias.tag, bias.bias, nil, label)
	end
end

--- Removes an AI definition from the DumbAIPlayer instance.
-- This function performs the following actions:
-- - Removes all the actions from the `ai_def` table from the `actions` table of the DumbAIPlayer.
-- - Removes all the production rules from the `ai_def` table from the `production_rules` table of the DumbAIPlayer.
-- - Removes all the biases from the `ai_def` table from the `biases` table of the DumbAIPlayer, using the `RemoveBias` function.
-- @param ai_def The AI definition table to be removed from the DumbAIPlayer.
function DumbAIPlayer:RemoveAIDef(ai_def)
	if not ai_def then return end
	local actions = self.actions
	for _, action in ipairs(ai_def) do
		table.remove_entry(actions, action)
	end
	local production_rules = self.production_rules
	for _, rule in ipairs(ai_def.production_rules or empty_table) do
		table.remove_entry(production_rules, rule)
	end
	local label = "AIDef " .. ai_def.id
	for _, bias in ipairs(ai_def.biases) do
		self:RemoveBias(bias.tag, nil, label)
	end
end


-- AI bias

local function recalc_bias(tag_biases)
	local acc = bias_base
	for _, bias in ipairs(tag_biases) do
		acc = MulDivRound(acc, bias.change, bias_base)
	end
	tag_biases.acc = acc
end

---
--- Adds a bias to the DumbAIPlayer instance.
---
--- This function performs the following actions:
--- - Adds a new bias to the `biases` table of the DumbAIPlayer, associated with the given `tag`.
--- - If the `tag` already exists in the `biases` table, it updates the existing biases for that tag.
--- - If a `label` is provided, it removes any existing bias with the same label before adding the new bias.
--- - Recalculates the accumulated bias for the `tag` using the `recalc_bias` function.
---
--- @param tag The tag to associate the bias with.
--- @param change The amount to change the bias by.
--- @param source The source of the bias (optional, only used for debugging).
--- @param label A label to associate with the bias (optional).
--- @return The added bias table.
function DumbAIPlayer:AddBias(tag, change, source, label)
	local tag_biases = self.biases[tag]
	if not tag_biases then
		tag_biases = { acc = bias_base }
		self.biases[tag] = tag_biases
	end
	if label then
		local idx = table.find(tag_biases, "label", label)
		if idx then
			table.remove(tag_biases, idx)
		end
	end
	local bias = {
		change = change,
		label = label or nil,
		source = ai_debug and source or nil,
	}
	tag_biases[#tag_biases + 1] = bias
	recalc_bias(tag_biases)
	return bias
end

---
--- Removes a bias from the DumbAIPlayer instance.
---
--- This function performs the following actions:
--- - Removes the specified bias from the `biases` table of the DumbAIPlayer, associated with the given `tag`.
--- - If a `label` is provided, it removes any existing bias with the same label.
--- - Recalculates the accumulated bias for the `tag` using the `recalc_bias` function.
---
--- @param tag The tag to remove the bias from.
--- @param bias The bias table to remove.
--- @param label The label of the bias to remove (optional).
function DumbAIPlayer:RemoveBias(tag, bias, label)
	local tag_biases = self.biases[tag]
	if tag_biases then
		table.remove_entry(tag_biases, bias)
		local idx = table.find(tag_biases, "label", label)
		if idx then
			table.remove(tag_biases, idx)
		end
		recalc_bias(tag_biases)
	end
end

---
--- Applies the accumulated biases for the given tags to the provided value.
---
--- This function iterates through the provided tags and applies the accumulated bias
--- for each tag to the given value. The biases are applied by calling `MulDivRound`
--- to scale the value based on the accumulated bias for the tag.
---
--- @param value The value to be biased.
--- @param tags A table of tags to apply the biases for. If not provided, an empty table is used.
--- @return The biased value.
function DumbAIPlayer:BiasValue(value, tags)
	local biases = self.biases
	for _, tag in ipairs(tags or empty_table) do
		local tag_biases = biases[tag]
		if tag_biases then
			value = MulDivRound(value, tag_biases.acc, bias_base)
		end
	end
	return value
end

---
--- Applies the accumulated biases for the given tag to the provided value.
---
--- This function scales the provided value based on the accumulated bias for the given tag.
--- If there are no biases associated with the tag, the value is returned unchanged.
---
--- @param value The value to be biased.
--- @param tag The tag to apply the biases for.
--- @return The biased value.
function DumbAIPlayer:BiasValueByTag(value, tag)
	local tag_biases = self.biases[tag]
	if tag_biases then
		value = MulDivRound(value, tag_biases.acc, bias_base)
	end
	return value
end

-- AI main loop

---
--- Performs periodic updates for the AI player's production rules.
---
--- This function iterates through the AI player's production rules and checks if the
--- next production time for each rule has been reached. If so, it calls the `Run`
--- function of the production rule, passing the player's resources and the AI player
--- instance as arguments. The next production time for the rule is then updated to
--- the current time plus the production interval.
---
--- @param seed The seed value for the AI player's random number generator.
function DumbAIPlayer:AIUpdate(seed)
	local resources = self.resources
	for _, rule in ipairs(self.production_rules) do
		local time = self.next_production_times[rule] or 0
		if GameTime() >= time then
			self.next_production_times[rule] = time + rule.production_interval
			procall(rule.Run, rule, resources, self)
		end
	end
end

---
--- Logs an action taken by the AI player.
---
--- This function adds the given action and the current game time to the AI player's action log.
--- If the action log exceeds the configured log size, the oldest entry is removed.
---
--- @param action The action to be logged.
---
function DumbAIPlayer:LogAction(action)
	table.insert(self.action_log, {action = action, time = GameTime()})
	while #self.action_log > self.log_size do
		table.remove(self.action_log, 1)
	end
end

---
--- Gets the display name of the DumbAIPlayer instance.
---
--- @return The display name of the DumbAIPlayer instance, or an empty string if no display name is set.
function DumbAIPlayer:GetDisplayName()
	return self.display_name or ""
end

---
--- Starts an action for the DumbAIPlayer instance.
---
--- This function is responsible for starting an AI action. It updates the running actions
--- count, deducts the required resources from the player's resources, runs the action's
--- `Run` function in a separate game time thread, logs the action if it has a log entry,
--- adds the resulting resources to the player's resources, calls the action's `OnEnd`
--- function, and decrements the running actions count.
---
--- @param action The action to be started.
function DumbAIPlayer:AIStartAction(action)
	self.running_actions[action] = (self.running_actions[action] or 0) + 1
	local resources = self.resources
	for _, res in ipairs(action.required_resources) do
		local resource = res.resource
		resources[resource] = resources[resource] - res.amount
	end
	CreateGameTimeThread(function(self, action, ai_debug)
		sprocall(action.Run, action, self)
		Sleep(self:BiasValueByTag(action.delay, "action_delay"))
		if (action.log_entry or "") ~= "" then
			self:LogAction(action)
		end
		local resources = self.resources
		for _, res in ipairs(action.resulting_resources) do
			local resource = res.resource
			resources[resource] = resources[resource] + res:Amount()
		end
		sprocall(action.OnEnd, action, self)
		assert((self.running_actions[action] or 0) > 0)
		self.running_actions[action] = (self.running_actions[action] or 0) - 1
		if ai_debug then
			ObjModified(self)
		end
	end, self, action, ai_debug)
end

---
--- Limits the actions that can be performed by the DumbAIPlayer based on available resources and other constraints.
---
--- This function takes a list of actions and returns a subset of those actions that can be performed given the current state of the DumbAIPlayer. It checks the following constraints:
---
--- - The number of running instances of each action is less than the maximum allowed.
--- - The player has sufficient resources to perform the action.
--- - The action is allowed to be performed by the player.
---
--- The actions are sorted in descending order by their evaluated score, and the number of actions returned is limited by the `ai_absolute_actions` and `ai_absolute_threshold` bias values.
---
--- @param actions The list of actions to be limited.
--- @return The list of actions that can be performed, and the count of those actions.
function DumbAIPlayer:AILimitActions(actions)
	local active_actions = {}
	local resources = self.resources
	local running_actions = self.running_actions
	for _, action in ipairs(actions) do
		if (running_actions[action] or 0) < action.max_running then
			for _, res in ipairs(action.required_resources) do
				assert(res:Amount() == res.amount, "randomized amounts are not supported for required_resources")
				if resources[res.resource] < res.amount then
					action = nil
					break
				end
			end
			if action and action:IsAllowed(self) then
				local eval = action:Eval(self) or action.base_eval
				action.eval = self:BiasValue(eval, action.tags)
				active_actions[#active_actions + 1] = action
			end
		end
	end
	table.sortby_field_descending(active_actions, "eval")
	-- limit by number of actions
	local count = self:BiasValueByTag(self.absolute_actions, "ai_absolute_actions")
	count = Min(count, #active_actions)
	if count < 1 then
		return active_actions, 0
	end
	-- limit by evaluation
	local threshold = self:BiasValueByTag(self.absolute_threshold, "ai_absolute_threshold")
	local rel_threshold = self:BiasValueByTag(self.relative_threshold, "ai_relative_threshold")
	threshold = Max(threshold, MulDivRound(active_actions[1].eval, rel_threshold, 100))

	while count > 0 
		and active_actions[count].eval < threshold do
		count = count - 1
	end
	return active_actions, count
end

---
--- Performs a single AI thinking iteration for the DumbAIPlayer.
---
--- This function is responsible for the core AI logic of the DumbAIPlayer. It performs the following steps:
---
--- 1. Updates the AI's internal state using `AIUpdate()`.
--- 2. Limits the available actions using `AILimitActions()`, which filters the actions based on resource constraints, running action limits, and other factors.
--- 3. Selects a single action from the limited set of actions using a random seed.
--- 4. Starts the selected action using `AIStartAction()`.
--- 5. If `ai_debug` is enabled, it records the AI's state and the selected action in a debug log.
---
--- @param seed (number) A random seed to use for the AI's decision-making process.
--- @return (Action|nil) The action that was selected and started, or `nil` if no action was selected.
function DumbAIPlayer:AIThink(seed)
	seed = seed or AsyncRand()
	self:AIUpdate(seed)
	local actions, count = self:AILimitActions(self.actions)
	local action = actions[BraidRandom(seed, count) + 1]
	if action then
		self:AIStartAction(action)
	end
	if ai_debug then
		if #self > 40 then -- remove entries beyond 40
			for i = 1, #self do
				self[i] = self[i + 1]
			end
		end
		if #self > 0 and not self[#self][3] then
			self[#self] = nil -- replace last entry if there was no action selected
		end
		self[#self + 1] = {
			GameTime() - self.ai_start,
			seed,
			action or false,
			actions,
			count,
			table.copy(self.resources),
			action and action.eval,
		}
		ObjModified(self)
	end
	return action
end

---
--- Creates a new AI thinking thread for the DumbAIPlayer.
---
--- This function is responsible for creating a new game time thread that will periodically call the `AIThink()` function to update the AI's decision-making process. The thread will sleep for a duration determined by the `ai_think_interval` tag bias, and then call `AIThink()` with a new random seed.
---
--- @param self (DumbAIPlayer) The DumbAIPlayer instance.
--- @return (nil)
function DumbAIPlayer:CreateAIThinkThread()
	DeleteThread(self.think_thread)
	self.think_thread = CreateGameTimeThread(function(self)
		local rand, think_seed = BraidRandom(self.seed)
		while true do
			Sleep(self:BiasValueByTag(self.think_interval, "ai_think_interval"))
			rand, think_seed = BraidRandom(think_seed)
			self:AIThink(rand)
		end
	end, self)
end

-- AI Debug

if ai_debug then

local function format_bias(n)
	return string.format("%d.%02d", n / bias_base, (n % bias_base) * 100 / bias_base)
end

local function DumbAIDebugActions(texts, actions, count, eval)
	texts[#texts + 1] = "<style GedTitleSmall><center>Actions selection</style>"
	for i, action in ipairs(actions) do
		if i == count + 1 then
			texts[#texts + 1] = ""
			texts[#texts + 1] = "<style GedTitleSmall><center>Low evaluation</style>"
		end
		if eval then
			texts[#texts + 1] = string.format("<left>%s<right>%s", action.id, format_bias(action.eval))
		else
			texts[#texts + 1] = string.format("<left>%s", action.id)
		end
	end
end

local function DumbAIDebugResources(texts, resources)
	texts[#texts + 1] = "<style GedTitleSmall><center>Resources</style>"
	for _, def in ipairs(Presets.AIResource.Default) do
		local resource = def.id
		texts[#texts + 1] = string.format("<left>%s<right>%d", resource, resources[resource])
	end
end

---
--- Generates a string representation of the current state of a DumbAIPlayer instance, including information about its resources, tag biases, and the actions it is considering.
---
--- @param ai_player (DumbAIPlayer) The DumbAIPlayer instance to generate the state for.
--- @return (string) A string representation of the DumbAIPlayer's current state.
function GedDumbAIDebugState(ai_player)
	local texts = {}
	DumbAIDebugResources(texts, ai_player.resources)
	texts[#texts + 1] = ""
	texts[#texts + 1] = "<style GedTitleSmall><center>Tag biases</style>"
	for _, def in ipairs(Presets.AITag.Default) do
		local tag = def.id
		local tag_biases = ai_player.biases[tag]
		if tag_biases then
			texts[#texts + 1] = string.format("<left>%s<right>%d%%", tag, MulDivRound(tag_biases.acc, 100, bias_base))
		end
	end
	
	texts[#texts + 1] = ""
	local actions, count = ai_player:AILimitActions(ai_player.actions)
	DumbAIDebugActions(texts, actions, count, true)
	return table.concat(texts, "\n")
end

local function time(time)
	time = tonumber(time)
	if time then
		local sign = time < 0 and "-" or ""
		local sec = abs(time) / 1000
		local min = sec / 60
		local hours = min / 60
		local days = hours / 24
		if days > 0 then
			return string.format("%s%dd%02dh%02dm%02ds", sign, days, hours % 24, min % 60, sec % 60)
		else
			return string.format("%s%dh%02dm%02ds", sign, hours, min % 60, sec % 60)
		end
	end
end

---
--- Generates a string representation of the debug log for a DumbAIPlayer instance, including information about the actions it has taken and the resources it has.
---
--- @param ai_player (DumbAIPlayer) The DumbAIPlayer instance to generate the debug log for.
--- @return (table<string>) A table of strings representing the debug log entries.
function GedDumbAIDebugLog(ai_player)
	local list = {}
	for i, entry in ipairs(ai_player) do
		local t, seed, action, actions, count, resources, eval = table.unpack(entry)
		list[i] = string.format("%s %s %s", time(t) or "???", action and action.id or "---", action and format_bias(eval) or "")
	end
	return list
end

---
--- Generates a string representation of a single debug log entry for a DumbAIPlayer instance, including information about the actions it has taken and the resources it has.
---
--- @param entry (table) A table containing the following values:
---   - time (number) The time of the log entry in milliseconds.
---   - seed (number) The random seed used for the log entry.
---   - action (table) The action taken by the DumbAIPlayer.
---   - actions (table) The list of actions available to the DumbAIPlayer.
---   - count (number) The number of actions available to the DumbAIPlayer.
---   - resources (table) The resources of the DumbAIPlayer.
--- @return (string) A string representation of the debug log entry.
function GedDumbAIDebugLogEntry(entry)
	local texts = {}
	local time, seed, action, actions, count, resources = table.unpack(entry)
	DumbAIDebugResources(texts, resources)
	texts[#texts + 1] = ""
	DumbAIDebugActions(texts, actions, count)
	return table.concat(texts, "\n")
end

-- Test

__TestAI = false

---
--- Runs a test AI player with default and IMM mission sponsor AI definitions.
---
--- The function creates a new `DumbAIPlayer` instance, adds the default and IMM mission sponsor AI definitions to it, creates an AI think thread, opens the AI editor, and resumes the game.
---
--- This function is intended for testing and debugging purposes.
---
function TestAI()
	if __TestAI then __TestAI:delete() end
	__TestAI = DumbAIPlayer:new{
		think_interval = const.HourDuration,
		production_interval = const.DayDuration,
	}
	__TestAI:AddAIDef(Presets.DumbAIDef.Default.default)
	__TestAI:AddAIDef(Presets.DumbAIDef.MissionSponsors.IMM)
	__TestAI:CreateAIThinkThread()
	__TestAI:OpenEditor()
	Resume()
end

end

---
--- Returns the current standing value of the DumbAIPlayer.
---
--- @return number The current standing value of the DumbAIPlayer.
function DumbAIPlayer:GetCurrentStanding()
	return self.resources.standing
end