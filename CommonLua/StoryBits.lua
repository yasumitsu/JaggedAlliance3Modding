-- Еngine for story bits (short UI interactions) via a system of triggers, categories, and cooldowns.
-- Depends on ClassDef and Constant groups with name "StoryBits"

if Platform.ged then return end

DefineConstInt("StoryBits", "TickDuration", 60, "sec", "Game time between Tick triggers")
config.StoryBitLogPrints = false

if FirstLoad then
	g_StoryBitTesting = config.StoryBitTesting or false
	VoiceActors = { "narrator" }
end

StoryBitTriggersCombo = {}

---
--- Defines a new story bit trigger.
---
--- @param name string The name of the story bit trigger.
--- @param msg_name string The name of the message that will trigger the story bit.
---
function DefineStoryBitTrigger(name, msg_name)
	StoryBitTriggersCombo[#StoryBitTriggersCombo + 1] = { text = name, value = msg_name }
	table.sortby_field(StoryBitTriggersCombo, "text")
	OnMsg[msg_name] = function(obj) StoryBitTrigger(msg_name, obj) end
end

---
--- Prints a story bit message with a yellow color.
---
--- @param text string The text to print.
---
function StoryBitPrint(text)
	assert(config.StoryBitLogPrints)
	print("<color 247 235 3>" .. text .. "</color>")
end


----- Debug log

if Platform.developer then
	local log_limit = 20
	GameVar("g_StoryBitsLog", {})
	GameVar("g_StoryBitsScopeStack", false)
	
	g_StoryBitsLogOld = false
	function OnMsg.ChangeMap()
		g_StoryBitsLogOld = g_StoryBitsLog
	end
	
	local function UpdateStoryBitLog()
		if #g_StoryBitsLog > log_limit then table.remove(g_StoryBitsLog, 1) end
		SuspendErrorOnMultiCall("StoryBitLog")
		ObjModified(g_StoryBitsLog)
		ResumeErrorOnMultiCall("StoryBitLog")
	end
	
	---
 --- Starts a new scope for logging story bit events.
 ---
 --- The scope is stored in the `g_StoryBitsScopeStack` table, and the current log entries are added to the last scope in the stack.
 --- When the scope ends, the last scope is removed from the stack using `StoryBitLogScopeEnd()`.
 ---
 --- @param ... any Values to be logged in the current scope.
 ---
	 function StoryBitLogScope(...)
		local stack = g_StoryBitsScopeStack or { g_StoryBitsLog }
		if #stack == 0 then stack = { g_StoryBitsLog } end
		g_StoryBitsScopeStack = stack
		
		local scope = stack[#stack]
		scope[#scope + 1] = { name = print_format(...) }
		stack[#stack + 1] = scope[#scope]
		UpdateStoryBitLog()
	end
	
	---
 --- Ends the current scope for logging story bit events.
 ---
 --- The last scope is removed from the `g_StoryBitsScopeStack` table.
 ---
 	function StoryBitLogScopeEnd()
		table.remove(g_StoryBitsScopeStack)
	end
	
	---
  --- Logs a message to the story bit log.
  ---
  --- The message is added to the current scope in the `g_StoryBitsScopeStack`. If no scope exists, a new one is created with the current `g_StoryBitsLog` as the initial scope.
  --- The log is limited to a maximum number of entries, and the oldest entries are removed as new ones are added.
  ---
  --- @param ... any Values to be logged in the current scope.
  ---
 function StoryBitLog(...)
		local stack = g_StoryBitsScopeStack or { g_StoryBitsLog }
		if #stack == 0 then stack = { g_StoryBitsLog } end
		g_StoryBitsScopeStack = stack
		
		local scope = stack[#stack]
		scope[#scope + 1] = print_format(...)
		UpdateStoryBitLog()
	end
	---
 --- Generates a description string for the given object.
 ---
 --- @param obj any The object to generate a description for.
 --- @return string The description string for the object.
 ---
 function StoryBitLogDescribe(obj)
		return TTranslate(obj:GetEditorView(), obj, false)
	end
else
	function StoryBitLogScope(name) end
	function StoryBitLogScopeEnd(name) end
	function StoryBitLog(name) end
	function StoryBitLogDescribe(self, obj) return "" end
end


----- StoryBitCategory

--- Defines a story bit category.
---
--- A story bit category is a group of related story bits that share a common trigger and other properties.
---
--- @class StoryBitCategory
--- @field Trigger string The trigger that activates the story bits from this category. For randomly occurring ones, use 'Tick'.
--- @field Chance number The chance that this category will be selected when the trigger fires, as a percentage.
--- @field Cooldowns CooldownDef[] Optional cooldowns that apply to this category.
--- @field Prerequisites Condition[] Optional common prerequisites for all story bits from this category.
--- @field ActivationEffects Effect[] Optional effects that are applied when this category is activated.
DefineClass.StoryBitCategory = {
	__parents = { "Preset" },
	properties = {
		{ id = "Trigger", editor = "combo", default = "", items = function() return StoryBitTriggersCombo end, help = "The trigger that activates the StoryBits from that category. For randomly occuring ones use 'Tick'." },
		{ id = "Chance", editor = "number", default = 5, scale = "%", 
			help = function (obj, prop_meta)
				local chance = obj[prop_meta.id]
				return ListChances({"Selected", "Not selected"}, {chance, 100 - chance}, 100, 
					"The chance that this category will be selected when the trigger fires.",
					{ 1, 2, 3, 4, 5, 7, 10, 15, 20, 24 })
			end
		},
		{ id = "Cooldowns", editor = "preset_id_list", default = false, preset_class = "CooldownDef", },
		{ id = "Prerequisites", editor = "nested_list", base_class = "Condition", default = false, help = "Common prerequisites for all StoryBits from the category.", },
		{ id = "ActivationEffects", name = "Activation Effects", editor = "nested_list", default = false, base_class = "Effect", all_descendants = true },
	},
	GlobalMap = "StoryBitCategories",
	EditorMenubarName = "Story Bits Categories",
	EditorMenubar = "Scripting",
	EditorIcon = "CommonAssets/UI/Icons/list outline.png",
	PropertyTranslation = false,
}

---
--- Checks if the total chance of all story bit categories with the same trigger exceeds 100%.
---
--- @return string|nil The error message if the total chance exceeds 100%, or nil if it's valid.
---
function StoryBitCategory:GetError()
	local total = 0
	ForEachPreset("StoryBitCategory", function(preset, group, trigger)
		if preset.Trigger == trigger then
			total = total + preset.Chance
		end
	end, self.Trigger)
	if total > 100 then
		return string.format("Total chance of categories with trigger %s exceeds 100%%.", self.Trigger)
	end
end

---
--- Registers a new ModItem preset for the "StoryBitCategory" class.
--- This preset will be available in the "Gameplay" submenu of the editor.
---
function OnMsg.ClassesGenerate()
	DefineModItemPreset("StoryBitCategory", { EditorName = "Story bit category", EditorSubmenu = "Gameplay" })
end

----- StoryBit states

GameVar("g_StoryBitCategoryStates", {}) -- separate tables per trigger
GameVar("g_StoryBitStates", {})
GameVar("g_StoryBitActive", {}) -- running storybit states (they are not found in g_StoryBitStates as the state unregisters on activation)
GameVar("g_StoryBitsLoaded", {}) -- keep track of what storybits were present when the savegame was made

function OnMsg.LoadGame() -- cleanup states of story bits that no longer exist (as presets) or were moved to a different category
	for _, states_for_trigger in pairs(g_StoryBitCategoryStates) do
		for _, category_state in pairs(states_for_trigger) do
			local to_remove
			for _, storybit_state in ipairs(table.copy(category_state.storybit_states)) do
				local preset = StoryBits[storybit_state.id]
				if not preset then
					to_remove = to_remove or {}
					to_remove[#to_remove + 1] = storybit_state
				elseif preset.Category ~= category_state.id then
					category_state:UnregisterStoryBit(storybit_state)
					GetStoryBitCategoryState(storybit_state.id):RegisterStoryBit(storybit_state)
				end
			end
			for _, storybit_state in ipairs(to_remove) do
				g_StoryBitStates[storybit_state.id] = nil
				category_state:UnregisterStoryBit(storybit_state)
			end
		end
	end
	
	-- empty g_StoryBitsLoaded means this is an older save and we don't want to create states that might have been removed from g_StoryBitStates on purpose
	if next(g_StoryBitsLoaded) then
		-- load story bits, which were not present when the savegame was made
		ForEachPreset("StoryBit", TryCreateStoryBitState)
	end
end

---
--- Represents the state of a story bit category.
--- Manages the list of story bit states that belong to this category.
---
--- @class StoryBitCategoryState
--- @field id string The unique identifier of the story bit category.
--- @field trigger string The trigger condition for the story bit category.
--- @field storybit_states table<number, StoryBitState> The list of story bit states that belong to this category.
---
DefineClass.StoryBitCategoryState = {
	__parents = { "InitDone" },
	id = false,
	trigger = false,
	storybit_states = false,
}

---
--- Initializes the `storybit_states` table for the `StoryBitCategoryState` class.
---
function StoryBitCategoryState:Init()
	self.storybit_states = {}
end

---
--- Registers a new story bit state to the category.
---
--- @param storybit_state StoryBitState The story bit state to be registered.
---
function StoryBitCategoryState:RegisterStoryBit(storybit_state)
	table.insert(self.storybit_states, storybit_state)
end

---
--- Unregisters a story bit state from the category.
---
--- @param storybit_state StoryBitState The story bit state to be unregistered.
---
function StoryBitCategoryState:UnregisterStoryBit(storybit_state)
	table.remove_entry(self.storybit_states, storybit_state)
end

---
--- Checks the prerequisites for a story bit category.
---
--- @param object table The object to check the prerequisites against.
--- @return boolean true if all prerequisites are satisfied, false otherwise.
---
function StoryBitCategoryState:CheckPrerequisites(object)
	local category = StoryBitCategories[self.id]
	assert(category)
	if not category or not Game then
		return
	end
	for _, cooldown_id in ipairs(category.Cooldowns) do
		if Game:GetCooldown(cooldown_id) then
			dbg(StoryBitLog("Category", self.id, "rejected due to cooldown", cooldown_id))
			NetUpdateHash("StoryBitPrerequisites in cooldown", self.id, cooldown_id, object)
			return
		end
	end
	for _, condition in ipairs(category.Prerequisites) do
		local valid = condition:ValidateObject(object, "Storybit category ", self.id)
		if not valid or not condition:Evaluate(object, nil) then -- the conditions expect StoryBitState as context
			dbg(StoryBitLog("Category", self.id, "rejected due to condition:", StoryBitLogDescribe(condition)))
			NetUpdateHash("StoryBitPrerequisites fail", self.id, object)
			return
		end
	end
	NetUpdateHash("StoryBitPrerequisites match", self.id, object)
	return true
end

---
--- Arranges the story bits in the given list.
---
--- If g_StoryBitTesting is true, the list is sorted using StoryBitsSortForTesting.
--- Otherwise, the list is shuffled using table.shuffle with a random seed from InteractionRand.
---
--- @param list table The list of story bit states to arrange.
--- @return table The arranged list of story bit states.
---
function StoryBitCategoryState:ArrangeStoryBits(list)
	list = table.copy(list)
	if g_StoryBitTesting then
		return StoryBitsSortForTesting(list)
	end
	table.shuffle(list, InteractionRand(nil, "ArrangeStoryBits"))
	return list
end

---
--- Tries to activate a story bit from the category's list of story bit states.
---
--- The story bit states are first arranged using the `ArrangeStoryBits` function, which either shuffles the list or sorts it for testing purposes. The function then iterates through the arranged list, checking the prerequisites for each story bit state. If a story bit state's prerequisites are satisfied, it is activated and the `StorybitActivated` function is called for the category.
---
--- @param object table The object to check the prerequisites against. If not provided, the object from the story bit state is used.
--- @param sleep number (optional) The amount of time to sleep between checking each story bit state, to prevent "stuttering".
--- @return boolean true if a matching story bit was found and activated, false otherwise.
---
function StoryBitCategoryState:TryActivateStoryBit(object, sleep)
	if #self.storybit_states == 0 then return end
	StoryBitLogScope("Trying category", self.id)
	-- shuffle/order the story bits and activate the first with satisfied prerequisites
	local list = self:ArrangeStoryBits(self.storybit_states)
	local match_found
	for _, storybit_state in ipairs(list) do
		local obj = storybit_state.object
		if obj and not IsStoryBitObjectValid(obj) then -- remove story bit states associated with an already invalid object
			dbg(StoryBitLog("StoryBit", storybit_state.id, "deleted due to invalid object"))
			storybit_state:Unregister() -- list is a copy - it is safe to call Unregister()
		elseif storybit_state:CheckPrerequisites(object or obj, nil) and (not sleep or table.find(self.storybit_states, storybit_state)) then
			storybit_state:ActivateStoryBit(object or obj)
			self:StorybitActivated(storybit_state)
			match_found = true
			break
		else
			storybit_state.object = obj -- CheckPrerequisites sometimes "picks" an object, clean it up
		end
		
		-- for the StoryBitTick trigger, this distributes the load to prevent "stuttering"
		if sleep then Sleep(sleep) end
	end
	
	StoryBitLogScopeEnd()
	return match_found
end

---
--- Activates a story bit in the category and handles any associated cooldowns or activation effects.
---
--- @param storybit_state StoryBitState The story bit state that was activated.
--- @param no_cooldown boolean (optional) If true, the category's cooldowns will not be set.
---
function StoryBitCategoryState:StorybitActivated(storybit_state, no_cooldown)
	local category = StoryBitCategories[self.id]
	if category then
		if Game and not no_cooldown then
			for _, cooldown_id in ipairs(category.Cooldowns) do
				Game:SetCooldown(cooldown_id)
			end
		end
		ExecuteEffectList(category.ActivationEffects, storybit_state.object, storybit_state)
	end
end

---
--- Gets the story bit category state for the given story bit ID.
---
--- @param storybit_id string The ID of the story bit.
--- @return StoryBitCategoryState The story bit category state.
---
function GetStoryBitCategoryState(storybit_id)
	local storybit = StoryBits[storybit_id]
	local category, trigger = storybit.Category, storybit.Trigger
	local states_for_trigger = g_StoryBitCategoryStates[trigger]
	if not states_for_trigger then
		states_for_trigger = {}
		g_StoryBitCategoryStates[trigger] = states_for_trigger
	end
	local state = states_for_trigger[category]
	if not state then
		state = StoryBitCategoryState:new{ id = category, trigger = trigger }
		states_for_trigger[category] = state
	end
	return state
end

---
--- Represents the state of a story bit in the game.
---
--- @class StoryBitState
--- @field id string The unique identifier of the story bit.
--- @field time_created number The time when the story bit was created.
--- @field object table The game object associated with the story bit.
--- @field player table The player associated with the story bit.
--- @field run_thread table The thread that runs the story bit.
--- @field inherited_title string The inherited title of the story bit.
--- @field inherited_image string The inherited image of the story bit.
--- @field chosen_reply_id string The identifier of the chosen reply.
DefineClass.StoryBitState = {
	__parents = { "InitDone" },
	id = false,
	time_created = false,
	object = false,
	player = false,
	run_thread = false,
	inherited_title = false,
	inherited_image = false,
	chosen_reply_id = false,
}

---
--- Initializes a new StoryBitState instance and registers it with the game.
---
--- This function is called when a new StoryBitState is created. It registers the
--- state with the global g_StoryBitStates table and the StoryBitCategoryState
--- associated with the story bit.
---
--- @function StoryBitState:Init
--- @return nil
function StoryBitState:Init()
	self:Register()
end

---
--- Marks the StoryBitState as done, unregistering it from the game and stopping its run thread.
---
--- This function is called when a StoryBitState has completed its execution. It performs the following actions:
---
--- 1. Unregisters the StoryBitState from the global `g_StoryBitStates` table and the associated `StoryBitCategoryState`.
--- 2. Stops the run thread associated with the StoryBitState.
--- 3. Calls the `OnStopRunning` function, which can be overridden in derived classes to perform additional cleanup.
---
--- @function StoryBitState:Done
--- @return nil
function StoryBitState:Done()
	self:Unregister()
	self:StopRunThread()
	self:OnStopRunning()
end

---
--- Overrides the __newindex metamethod to allow setting arbitrary keys on the StoryBitState instance.
---
--- This method is called whenever a new key-value pair is set on the StoryBitState instance. It simply calls the rawset function to set the value of the specified key.
---
--- @param key string The key to set on the StoryBitState instance.
--- @param value any The value to set for the specified key.
--- @return nil
function StoryBitState:__newindex(key, value)
	rawset(self, key, value)
end

---
--- Registers the StoryBitState instance with the global g_StoryBitStates table and the associated StoryBitCategoryState.
---
--- This function is called when a new StoryBitState is created. It performs the following actions:
---
--- 1. Sets the time_created field of the StoryBitState to the current game time.
--- 2. Adds the StoryBitState to the global g_StoryBitStates table, using the id field as the key.
--- 3. Notifies the game of the change to the g_StoryBitStates table by calling NetUpdateHash.
--- 4. Registers the StoryBitState with the associated StoryBitCategoryState by calling its RegisterStoryBit method.
---
--- @function StoryBitState:Register
--- @return nil
function StoryBitState:Register()
	self.time_created = StoryBitGetGameTime()
	g_StoryBitStates[self.id] = self
	NetUpdateHash("g_StoryBitStates Register", self.id)
	GetStoryBitCategoryState(self.id):RegisterStoryBit(self)
end

---
--- Unregisters the StoryBitState instance from the global `g_StoryBitStates` table and the associated `StoryBitCategoryState`.
---
--- This function is called when a StoryBitState is no longer needed. It performs the following actions:
---
--- 1. Removes the StoryBitState from the global `g_StoryBitStates` table, using the `id` field as the key.
--- 2. Notifies the game of the change to the `g_StoryBitStates` table by calling `NetUpdateHash`.
--- 3. Unregisters the StoryBitState from the associated `StoryBitCategoryState` by calling its `UnregisterStoryBit` method.
---
--- @function StoryBitState:Unregister
--- @return nil
function StoryBitState:Unregister()
	g_StoryBitStates[self.id] = nil
	NetUpdateHash("g_StoryBitStates Unregister", self.id)
	GetStoryBitCategoryState(self.id):UnregisterStoryBit(self)
end

---
--- Checks project-specific prerequisites for a StoryBit.
---
--- This function is a placeholder for project-specific implementation of checking prerequisites for a StoryBit. The default implementation simply returns true, allowing all StoryBits to pass the prerequisite check.
---
--- @param storybit table The StoryBit to check prerequisites for.
--- @param object table The object to check prerequisites against.
--- @param force boolean If true, the prerequisites will be checked regardless of cooldowns or suppression time.
--- @return boolean True if the prerequisites are met, false otherwise.
function StoryBitState:CheckProjectSpecificPrerequisites(storybit, object, force)
	-- implement in project-specific code
	return true
end

---
--- Checks the prerequisites for a StoryBit and returns whether they are met.
---
--- This function performs the following checks:
---
--- 1. Calls the `CheckProjectSpecificPrerequisites` function to check any project-specific prerequisites.
--- 2. Checks if the StoryBit is on cooldown, and if so, returns `false`.
--- 3. Checks if the StoryBit is currently suppressed, and if so, returns `false`.
--- 4. Iterates through the StoryBit's prerequisites and checks if each one is valid and evaluates to `true`. If any prerequisite fails, the function returns `false`.
---
--- @param object table The object to check the prerequisites against.
--- @param force boolean If `true`, the prerequisites will be checked regardless of cooldowns or suppression time.
--- @return boolean `true` if all prerequisites are met, `false` otherwise.
function StoryBitState:CheckPrerequisites(object, force)
	local storybit = StoryBits[self.id]
	if not self:CheckProjectSpecificPrerequisites(storybit, object, force) then
		return
	end
	if not force then
		for cooldown_id in pairs(storybit.Sets) do
			if Game:GetCooldown(cooldown_id) then
				dbg(StoryBitLog("StoryBit", self.id, "rejected due to cooldown", cooldown_id))
				return
			end
		end
		local supress_time = storybit.SuppressTime
		if g_StoryBitTesting then
			supress_time = supress_time / 10
		end
		if supress_time > 0 and StoryBitGetGameTime() <= self.time_created + supress_time then
			dbg(StoryBitLog("StoryBit", self.id, "suppressed for", self.time_created + supress_time - StoryBitGetGameTime()))
			return
		end
	end
	
	self.player = nil
	
	local result = true
	for _, condition in ipairs(storybit.Prerequisites or empty_table) do
		local valid = condition:ValidateObject(object, "Storybit ", self.id)
		if not valid or not condition:Evaluate(object, self) then
			result = false
			if not force then 
				dbg(StoryBitLog("StoryBit", self.id, "rejected due to condition:", StoryBitLogDescribe(condition)))
				break 
			end
		end
	end
	if result then
		return true
	end
	
	self.player = nil
end

---
--- Tests the prerequisites for a StoryBit object.
---
--- @param object table The object to check the prerequisites against.
--- @return table A table of test results, where each entry has a `text` field with the description of the prerequisite, and a `res` field with the boolean result of evaluating the prerequisite.
---
function StoryBitState:TestPrerequisites(object)
	local test = {}
	local storybit = StoryBits[self.id]
	for i, condition in ipairs(storybit.Prerequisites or empty_table) do
		local desc = self:PrepareT(condition:GetEditorView(), condition, "ignore_localization")
		test[i] = {
			text = _InternalTranslate(desc, nil, false),
			res = condition:ValidateObject(object, "Storybit ", self.id) and condition:Evaluate(object, self) and true or false,
		}
	end
	self.object = nil
	self.player = nil
	return test
end

---
--- Tests the category prerequisites for a StoryBit object.
---
--- @param object table The object to check the category prerequisites against.
--- @return table A table of test results, where each entry has a `text` field with the description of the prerequisite, and a `res` field with the boolean result of evaluating the prerequisite.
---
function StoryBitState:TestCategoryPrerequisites(object)
	local test = {}
	local storybit = StoryBits[self.id]
	local category = StoryBitCategories[storybit.Category].Prerequisites
	for i, condition in ipairs(StoryBitCategories[storybit.Category].Prerequisites or empty_table) do
		local desc = self:PrepareT(condition:GetEditorView(), condition, "ignore_localization")
		test[i] = {
			text = _InternalTranslate(desc, nil, false),
			res = condition:ValidateObject(object, "Storybit ", self.id) and condition:Evaluate(object, self) and true or false,
		}
	end
	self.object = nil
	self.player = nil
	return test
end

---
--- Prepares a localized text string for a story bit.
---
--- @param loc_text string|table The localized text string or a table with localization information.
--- @param subcontext table An optional table with a `ResolveValue` function to resolve values in the localized text.
--- @param ignore_localization boolean An optional flag to ignore localization and return the raw text.
--- @return string The prepared localized text string.
---
function StoryBitState:PrepareT(loc_text, subcontext, ignore_localization)
	if not loc_text or loc_text == "" then return "" end
	if Platform.developer and not ignore_localization and type(loc_text) == "table" and loc_text.untranslated then
		assert(false, string.format("Story bit %s is displaying an untranslated description:\n%s", self.id, _InternalTranslate(loc_text)))
	end
	if subcontext then
		return T{loc_text, Context:new{
			ResolveValue = function(context, key)
				return self:ResolveValue(key, subcontext)
			end,
		}}
	end
	return T{loc_text, self}
end

---
--- Resolves a value from the current StoryBit context.
---
--- This function first checks the `subcontext` table for a `ResolveValue` function, and uses that to resolve the value.
--- If the value is not found in the `subcontext`, it then checks the `StoryBits[self.id]` table for a matching key.
--- If the value is still not found, it checks the `self.object` table for a matching key.
--- Finally, it checks the `self` table for a matching key.
---
--- @param key string The key to resolve the value for.
--- @param subcontext table An optional table with a `ResolveValue` function to resolve values.
--- @return any The resolved value, or `nil` if not found.
---
function StoryBitState:ResolveValue(key, subcontext)
	local storybit = StoryBits[self.id]
	local value = subcontext and ResolveValue(subcontext, key)
	value = value or storybit:ResolveValue(key)
	value = value or rawget(storybit, key)
	value = value or self.object and self.object:ResolveValue(key)
	value = value or rawget(self, key)
	return value
end

---
--- Prepares the text for a story bit reply.
---
--- This function takes a `reply` table and generates the formatted text for the reply, including any prerequisite conditions and costs.
---
--- @param reply table The reply table containing the text and other information.
--- @return string The formatted reply text.
---
function StoryBitState:PrepareReplyText(reply)
	-- condition text
	local cond_text = self:PrepareT(reply.PrerequisiteText)
	
	-- cost text
	local cost = reply.Cost
	local cost_text = cost > 0 and StoryBitFormatCost(cost)
	
	-- format text
	local reply = self:PrepareT(reply.Text)
	if cond_text ~= "" and cost_text then
		return T{624976250551, "<condition_text>[<condition>, cost: <cost>]</condition_text> <reply>", condition = cond_text, cost = cost_text, reply = reply }
	elseif cond_text ~= "" then
		return T{924726909309, "<condition_text>[<condition>]</condition_text> <reply>", condition = cond_text, reply = reply }
	elseif cost_text then
		return T{474009362220, "<condition_text>[Cost: <cost>]</condition_text> <reply>", cost = cost_text, reply = reply }
	else
		return reply
	end
end

---
--- Prepares the outcome text for a story bit reply.
---
--- This function takes a `reply` table, the index of the reply, and a boolean indicating if the reply is enabled, and generates the formatted text for the outcome of the reply.
---
--- If the `OutcomeText` field of the reply is set to "custom", the function will use the `CustomOutcomeText` field to generate the outcome text.
---
--- If the `OutcomeText` field is set to "auto", the function will look for the next `StoryBitOutcome` in the `StoryBits[self.id]` table and generate the outcome text based on the descriptions of the effects in that outcome.
---
--- If the outcome text is empty, the function will return an empty string.
---
--- @param reply table The reply table containing the text and other information.
--- @param reply_idx number The index of the reply in the `StoryBits[self.id]` table.
--- @param enabled boolean A boolean indicating if the reply is enabled.
--- @return string The formatted outcome text.
---
function StoryBitState:PrepareOutcomeText(reply, reply_idx, enabled)
	local outcome_text = ""
	if reply.OutcomeText == "custom" then
		outcome_text = self:PrepareT(reply.CustomOutcomeText) or ""
	elseif reply.OutcomeText == "auto" then
		local storybit = StoryBits[self.id]
		local function next_outcome(storybit, idx)
			while not IsKindOf(storybit[idx], "StoryBitOutcome") do
				if IsKindOf(storybit[idx], "StoryBitReply") or idx > #storybit then return end
				idx = idx + 1
			end
			return idx
		end
	
		local idx = next_outcome(storybit, reply_idx + 1)
		if idx then
			local outcome_texts = {}
			for _, effect in ipairs(storybit[idx].Effects or empty_table) do
				local description = effect:GetDescription()
				if description and description ~= "" and not effect.NoIngameDescription then
					outcome_texts[#outcome_texts + 1] = self:PrepareT(description, effect)
				end
			end
			outcome_text = table.concat(outcome_texts, T(163645984724, ", "))
		end
	end
	
	if outcome_text == "" then
		return ""
	end
	return enabled and
		T{690643209328, "<outcome_text>(<outcome>)</outcome_text>", outcome = outcome_text} or
		T{269606479436, "<disabled_text>(<outcome>)</disabled_text>", outcome = outcome_text}
end

---
--- Activates a story bit and starts its execution.
---
--- @param object table|nil The object associated with the story bit, or `nil` if none.
--- @param immediate boolean Whether to run the story bit immediately or not.
---
function StoryBitState:ActivateStoryBit(object, immediate)
	assert(not IsValidThread(self.run_thread))
	
	local id = self.id
	local storybit = StoryBits[id]
	if g_StoryBitTesting then
		StoryBitSaveTime(id)
	end
	
	dbg(StoryBitLog("StoryBit", id, "activated", immediate and "immediate" or ""))
	NetUpdateHash("StoryBitActivated", id, immediate and "immediate" or "")

	self:Unregister()
	DisableStoryBits(storybit.Disables, self)
	
	self:StopRunThread() -- here for safety only, there should be no running threads
	self.object = object or self.object
	self.run_thread = CreateGameTimeThread(self.RunWrapper, self, immediate)
	Msg("StoryBitActivated", id, self)
end

---
--- Returns the title of the story bit.
---
--- @return string The title of the story bit.
---
function StoryBitState:GetTitle()
	local storybit = StoryBits[self.id]
	local has_title = storybit.Title and storybit.Title ~= ""
	return has_title and storybit.Title or self.inherited_title
end

---
--- Returns the image to be used for the story bit popup.
---
--- @return string The image to be used for the story bit popup.
---
function StoryBitState:GetImage()
	local storybit = StoryBits[self.id]
	local obj = self.object
	local image = storybit.UseObjectImage
		and IsValid(obj)
		and PropObjHasMember(obj, "GetStoryBitPopupImage")
		and obj:GetStoryBitPopupImage()
	if (image or "") ~= "" then return image end
	local has_image = storybit.Image and storybit.Image ~= ""
	return has_image and storybit.Image or self.inherited_image
end

---
--- Wraps the execution of a story bit, handling the start and stop of the story bit's run.
---
--- @param immediate boolean Whether the story bit should be run immediately.
---
function StoryBitState:RunWrapper(immediate)
	self:OnStartRunning()
	local success = self:Run(immediate)
	self:OnStopRunning()
	if success then
		self:OpenPopup()
	end
	self:Complete()
end

---
--- Stops the currently running thread for the StoryBitState.
---
--- If the current thread is not the run_thread, the run_thread is deleted.
--- If the current thread is the run_thread, a new game time thread is created to delete the run_thread.
---
function StoryBitState:StopRunThread()
	local thread = self.run_thread
	self.run_thread = nil
	if thread ~= CurrentThread() then
		DeleteThread(thread)
	else
		CreateGameTimeThread(DeleteThread, thread)
	end
end

---
--- Interrupts the currently running story bit.
---
--- Stops the run thread, stops the story bit from running, clears the object and player references, and re-registers the story bit.
---
function StoryBitState:Interrupt()
	self:StopRunThread()
	self:OnStopRunning()
	self.object = nil
	self.player = nil
	self:Register()
end

---
--- Marks the start of a story bit's execution.
---
--- Adds the current story bit state to the global list of active story bits, and increments the count for this story bit's ID.
---
function StoryBitState:OnStartRunning()
	local running = g_StoryBitActive
	running[#running + 1] = self
	running[self.id] = (running[self.id] or 0) + 1
end

---
--- Marks the end of a story bit's execution.
---
--- Removes the story bit notification, asserts that the run_thread is the current thread or invalid, sets the run_thread to nil, and removes the story bit from the global list of active story bits.
---
--- @param self StoryBitState The story bit state object.
function StoryBitState:OnStopRunning()
	RemoveStoryBitNotification(self.id)
	assert(self.run_thread == CurrentThread() or not IsValidThread(self.run_thread))
	self.run_thread = nil
	local running = g_StoryBitActive
	if not running[self.id] then
		return
	end
	for i=#running,1,-1 do
		local state = running[i]
		if state == self or not IsValidThread(state.run_thread) then
			table.remove(running, i)
			running[state.id] = (running[state.id] or 0) - 1
			if running[state.id] <= 0 then
				running[state.id] = nil
			end
		end
	end
end

---
--- Runs the story bit, optionally immediately.
---
--- If the story bit has a delay, it will be executed after the delay. If the story bit has an object, it will be detached during the delay. The story bit's activation effects will be executed, and a notification will be added if the story bit has one. The story bit will run until the expiration time is reached, or the notification action is triggered.
---
--- @param self StoryBitState The story bit state object.
--- @param immediate boolean Whether to run the story bit immediately, without a delay.
--- @return boolean Whether the story bit was successfully run.
function StoryBitState:Run(immediate)
	dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", self.id, "started", immediate and "immediate" or nil))
	
	local storybit = StoryBits[self.id]
	
	-- delay
	if not immediate then
		if storybit.DetachObj then
			self.object = false
		end
		StoryBitDelay(storybit.Delay)
	end
	
	if self.object and not IsStoryBitObjectValid(self.object) then
		return
	end
	
	if config.StoryBitLogPrints then
		StoryBitPrint("Story bits: Triggered story bit - " .. self.id)
	end
	
	-- activation effects
	for _, effect in ipairs(storybit.ActivationEffects or empty_table) do
		if effect:ValidateObject(self.object, "Storybit ", self.id) then
			effect:Execute(self.object, self)
		end
	end
	
	local expiration_time = storybit.ExpirationTime
	if not storybit.HasNotification and (not expiration_time or expiration_time == 0) then
		return true
	end
	
	assert(self.run_thread == CurrentThread())
	expiration_time = expiration_time or const.HourDuration
	expiration_time = expiration_time * (storybit:ExpirationModifier(self, self.object) or 100) / 100
	-- add notification, handle timeout with a thread
	local stop_wait
	if storybit.HasNotification then
		local notification_title = storybit.NotificationTitle ~= "" and storybit.NotificationTitle or self:GetTitle()
		local notification_text = storybit.NotificationText ~= "" and storybit.NotificationText or notification_title
		AddStoryBitNotification(self, storybit, 
			self:PrepareT(notification_title), 
			self:PrepareT(notification_text), 
			expiration_time,
			function()
				if storybit.NotificationAction == "complete" then
					stop_wait = true
					Wakeup(self.run_thread)
				elseif storybit.NotificationAction == "select object" then
					StoryBitViewAndSelectObject(self.object)
				elseif storybit.NotificationAction == "callback" then
					storybit:NotificationCallbackFunc(self)
				end
			end	)
	end
	local end_time = StoryBitGetGameTime() + expiration_time
	while not stop_wait and StoryBitGetGameTime() - end_time < 0 do
		WaitWakeup(100)
		if self.object and not IsStoryBitObjectValid(self.object) then
			return
		end
	end
	return true
end

---
--- Checks if the custom prerequisites for a story bit reply are satisfied.
---
--- This function is a placeholder for project-specific implementation. It should return
--- `true` if the custom prerequisites for the given `reply` are satisfied, or `false` otherwise.
---
--- @param reply StoryBitReply The story bit reply to check the custom prerequisites for.
--- @return boolean True if the custom prerequisites are satisfied, false otherwise.
---
function CheckCustomStoryBitReplyPrerequisites(reply)
	-- implement in project-specific code
	return true
end

---
--- Checks if the custom prerequisites for a story bit outcome are satisfied.
---
--- This function is a placeholder for project-specific implementation. It should return
--- `true` if the custom prerequisites for the given `outcome` are satisfied, or `false` otherwise.
---
--- @param outcome StoryBitOutcome The story bit outcome to check the custom prerequisites for.
--- @return boolean True if the custom prerequisites are satisfied, false otherwise.
---
function CheckCustomStoryBitOutcomePrerequisites(outcome)
	-- implement in project-specific code
	return true
end

---
--- Opens a popup window to display the story bit replies and allow the user to select one.
---
--- This function gathers all the available story bit replies, checks if their prerequisites are satisfied,
--- and displays them in a popup window. When the user selects a reply, the function processes the
--- corresponding outcome effects.
---
--- @param self StoryBitState The story bit state object.
---
function StoryBitState:OpenPopup()
	local storybit = StoryBits[self.id]
	if storybit and storybit.HasPopup then
		-- gather all replies
		local counter = 0
		local all_disabled = true
		local replies, choices, enabled, extra_texts = {}, {}, {}, {}
		local i = 1
		for idx, reply in ipairs(storybit) do
			if reply:IsKindOf("StoryBitReply") then
				counter = counter + 1
				local cost_satisfied = reply.Cost <= 0 or StoryBitCheckCost(reply.Cost)
				local project_specific_satisfied = CheckCustomStoryBitReplyPrerequisites(reply)
				local satisfied = cost_satisfied and project_specific_satisfied and EvalConditionList(reply.Prerequisites, self.object, self)
				all_disabled = all_disabled and not satisfied
				if not reply.HideIfDisabled or satisfied then
					enabled[i] = satisfied
					replies[i] = reply
					choices[i] = self:PrepareReplyText(reply)
					extra_texts[i] = self:PrepareOutcomeText(reply, idx, satisfied)
					i = i + 1
				end
			end
		end
		if counter > 0 and all_disabled then
			self:ShowError(false, "No available storybit replies!")
		end
		-- display popup
		Msg("StoryBitPopup", self.id, self)
		if storybit.PopupFxAction ~= "" then
			PlayFX(storybit.PopupFxAction, "start")
		end
		local reply_idx
		if config.NoUserInteraction then
			reply_idx = table.find(enabled, true) or 1 -- for testing purposes
		else
			reply_idx = WaitStoryBitPopup(self.id,
				self:PrepareT(self:GetTitle()), self:PrepareT(storybit.VoicedText), self:PrepareT(storybit.Text),
				self.object or storybit.Actor, self:GetImage(), choices, enabled, extra_texts)
		end
		local reply = replies[reply_idx]
		if reply then
			if config.StoryBitLogPrints then
				StoryBitPrint("Story bits: Reply selected - " .. _InternalTranslate(reply.Text))
			end
			self.chosen_reply_id = reply.unique_id
			local reply_counter = 0
			for _, reply_i in ipairs(storybit) do
				if reply_i:IsKindOf("StoryBitReply") then
					reply_counter = reply_counter + 1
					if reply_i.unique_id == reply.unique_id then
						Msg("StoryBitReplyActivated", self.id, self, reply_counter)
						break
					end
				end
			end
			-- gather possible outcomes
			local found, outcomes = false, {}
			local log_text = string.format("Storybit outcome for reply %d in %s", reply_idx, self.id)
			for _, outcome in ipairs(storybit) do
				if not found then
					found = outcome.unique_id == reply.unique_id
				else
					if outcome:IsKindOf("StoryBitReply") then
						break
					elseif outcome:IsKindOf("StoryBitOutcome") then
						local fulfilled = CheckCustomStoryBitOutcomePrerequisites(outcome)
						if fulfilled then
							for _, condition in ipairs(outcome.Prerequisites or empty_table) do
								local valid = condition:ValidateObject(self.object, log_text)
								if not valid or not condition:Evaluate(self.object, self) then
									fulfilled = false
									break
								end
							end
						end
						if fulfilled then
							outcomes[#outcomes + 1] = outcome
						end
					end
				end
			end
			
			-- charge the reply's cost if present
			local cost = reply.Cost
			if cost > 0 then
				StoryBitPayCost(cost)
			end
			
			-- trigger outcome selected by weighted random
			local outcome
			if g_StoryBitTesting then
				outcome = StoryBitOutcomeTestingPick(outcomes, storybit)
			else
				outcome = table.weighted_rand(outcomes, "Weight", InteractionRand(1000000, "StoryBitOutcome"))
			end
			if outcome then
				if (outcome.VoicedText and outcome.VoicedText ~= "" or outcome.Text and outcome.Text ~= "") and not config.NoUserInteraction then
					local image = outcome.Image
					if not image or image == "" then
						image = storybit.Image
					end
					local title = (outcome.Title and outcome.Title ~= "") and outcome.Title or self:GetTitle()
					WaitStoryBitPopup(self.id .. "Outcome", self:PrepareT(title), self:PrepareT(outcome.VoicedText), self:PrepareT(outcome.Text), outcome.Actor, image)
				end
				self:ProcessOutcomeEffects(outcome, log_text)
			end
		end
		if storybit.SelectObject and IsValid(self.object) then
			ViewAndSelectObject(self.object)
		end
	end
	self:ProcessOutcomeEffects(storybit, "Storybit " .. self.id)
end

---
--- Completes the current StoryBitState instance.
--- Sends a message indicating the StoryBit has been completed, clears the object and player references,
--- and re-registers the StoryBit if it is not a one-time event.
---
--- @param self StoryBitState The current StoryBitState instance.
---
function StoryBitState:Complete()
	Msg("StoryBitCompleted", self.id, self)
	self.object = nil
	self.player = nil
	local storybit = StoryBits[self.id]
	if not storybit.OneTime then
		self:Register()
	end
end

---
--- Displays an error message with information about the current StoryBitState instance.
---
--- @param self StoryBitState The current StoryBitState instance.
--- @param fo any The source object that triggered the error.
--- @param ... any Additional arguments to include in the error message.
---
function StoryBitState:ShowError(fo, ...)
	local texts = {
		print_format("Error:", ...),
		print_format("Storybit:", self.id),
	}
	if fo then
		local desc = _InternalTranslate(self:PrepareT(fo:GetEditorView(), fo, "ignore_localization"), nil, false)
		texts[#texts + 1] = print_format("Source:", fo.class, desc)
	end
	local text = table.concat(texts, "\n")
	assert(false, text)
end

-- called with both StoryBitOutcome and StoryBit parameter
---
--- Processes the effects defined in a StoryBitOutcome object.
--- Executes each effect that is valid for the current object, logs the effect execution, and
--- optionally tries to activate a random storybit from the outcome, disables storybits, and enables storybits.
---
--- @param self StoryBitState The current StoryBitState instance.
--- @param outcome StoryBitOutcome The outcome object containing the effects to process.
--- @param parentobj_text string The text to use for the parent object in the log message.
---
function StoryBitState:ProcessOutcomeEffects(outcome, parentobj_text)
	if not outcome then return end
	for _, effect in ipairs(outcome.Effects) do
		if effect:ValidateObject(self.object, parentobj_text) then
			if config.StoryBitLogPrints then
				local log_msg = "Story bits: Effect triggered - " .. effect.class
				if effect:HasMember("Effects") and type(effect.Effects) == "table" and #effect.Effects > 0 then
					log_msg = log_msg .. ": "
					for i = 1, #effect.Effects do
						if i == #effect.Effects then
							log_msg = log_msg .. effect.Effects[i].class
						else
							log_msg = log_msg .. effect.Effects[i].class .. ", "
						end
					end
				end
				StoryBitPrint(log_msg)
			end
			effect:Execute(self.object, self)
		end
	end
	-- try to select a random storybit from the outcome
	TryActivateRandomStoryBit(outcome.StoryBits, self.object, self)
	DisableStoryBits(outcome.Disables, self)
	self:EnableStoryBits(outcome.Enables)
end

---
--- Attempts to activate a random storybit from the provided list of storybits.
---
--- @param storybits table A list of storybit objects to choose from.
--- @param obj table The game object associated with the storybit activation.
--- @param context StoryBitState The current storybit state context.
---
function TryActivateRandomStoryBit(storybits, obj, context)
	if not next(storybits) then return end
	local items = {}
	for _, item in ipairs(storybits) do
		if CheckStoryBitPrerequisites(item.StoryBitId, obj) then
			items[#items + 1] = item
		end
	end
	local chosen_storybit = table.weighted_rand(items, "Weight", InteractionRand(1000000, "StoryBitOutcome"))
	if chosen_storybit then
		ForceActivateStoryBit(chosen_storybit.StoryBitId, obj, chosen_storybit.ForcePopup and "immediate", context, chosen_storybit.NoCooldown)
	end
end

---
--- Disables the specified story bits.
---
--- @param list table A list of story bit IDs to disable.
--- @param disabled_by StoryBitState The story bit state that is disabling the story bits.
---
function DisableStoryBits(list, disabled_by)
	if #(list or "") == 0 then return end
	if disabled_by then
		dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", disabled_by.id, "disables storybits:", table.concat(list, ", ")))
	end
	local g_StoryBitStates = g_StoryBitStates
	local g_StoryBitActive = g_StoryBitActive
	local to_delete
	for _, id in ipairs(list) do
		local storybit_state = g_StoryBitStates[id]
		if storybit_state then
			assert(storybit_state ~= disabled_by)
			storybit_state:delete()
		end
		if g_StoryBitActive[id] then
			for _, storybit_state in ipairs(g_StoryBitActive) do
				if storybit_state.id == id then
					to_delete = to_delete or {}
					to_delete[#to_delete + 1] = storybit_state
				end
			end
		end
	end
	for _, storybit_state in ipairs(to_delete) do
		assert(storybit_state ~= disabled_by)
		storybit_state:delete()
	end
end

---
--- Enables the specified story bits.
---
--- @param list table A list of story bit IDs to enable.
--- @param enabled_by StoryBitState The story bit state that is enabling the story bits.
---
function StoryBitState:EnableStoryBits(list, enabled_by)
	if #(list or "") == 0 then return end
	enabled_by = enabled_by or self
	dbg(StoryBitLog("["..StoryBitFormatGameTime().."]", enabled_by.id, "activates storybits:", table.concat(list, ", ")))
	for _, id in ipairs(list) do
		local storybit_state = g_StoryBitStates[id]
		if not storybit_state then
			local storybit = StoryBits[id]
			if not storybit then
				self:ShowError(false, "No such storybit", id)
			else
				assert(not storybit.Enabled)
				StoryBitState:new{
					id = id,
					object = storybit.InheritsObject and enabled_by.object or nil,
					player = self.player,
					inherited_title = enabled_by:GetTitle(),
					inherited_image = enabled_by:GetImage(),
				}
			end
		end
	end
end


----- StoryBit trigger engine

---
--- Triggers story bit events.
---
--- This function is responsible for processing story bit triggers and activating the appropriate story bit categories based on the trigger message and the current game state.
---
--- @param msg string The trigger message, such as "StoryBitTick" or other custom triggers.
--- @param object table An optional game object associated with the trigger.
---
function StoryBitTrigger(msg, object)
	if not mapdata.GameLogic or config.StoryBitsSuspended then
		return
	end
	
	NetUpdateHash("StoryBitTrigger", msg, object)
	
	local states = g_StoryBitCategoryStates[msg]
	if states == nil then
		--StoryBitLog("["..StoryBitFormatGameTime().."]", "Trigger", msg, "- no active story bits with this trigger!")
		return
	end

	StoryBitLogScope("["..StoryBitFormatGameTime().."]", "Trigger", msg, object and object.class or "")

	-- process follow ups if present
	local follow_ups = states["FollowUp"]
	if follow_ups and follow_ups:TryActivateStoryBit(object) then
		StoryBitLogScopeEnd()
		return
	end

	-- gather categories with this trigger
	if g_StoryBitTesting then
		local category = StoryBitCategoryTestingPick(states, object)
		if category then
			category:TryActivateStoryBit(object)
		end
	else
		local total, random = 0, InteractionRand(100, "StoryBitTrigger")
		local activated = false
		for category_name, category in sorted_pairs(states) do
			if category_name ~= "FollowUp" then
				local category_descr = StoryBitCategories[category_name]
				local chance = category_descr and category_descr.Chance or 0
				if random >= 0 and random < chance and category:CheckPrerequisites(object) then
					-- the execution passes through here just once, guaranteed
					if msg == "StoryBitTick" and #category.storybit_states > 0 then
						-- calculate sleep time to distribute the load of checking prerequisites (try to fit in 1/10 the tick time)
						local sleep_time = (const.StoryBits.TickDuration / 10) / #category.storybit_states
						assert(sleep_time ~= 0)
						CreateGameTimeThread(category.TryActivateStoryBit, category, object, Clamp(sleep_time, 1, 10))
					else
						category:TryActivateStoryBit(object)
					end
					activated = true
				end
				random = random - chance
				total = total + chance
			end
		end
		assert(total <= 100, string.format("Total chance of categories with trigger %s exceeds 100%%.", msg))
		--[[
		if not activated then
			StoryBitLog("No category was selected for activation (due to chance)")
		end
		--]]
	end
	
	StoryBitLogScopeEnd()
end

function OnMsg.Autorun()
	table.insert(StoryBitTriggersCombo, 1, { text = "Tick", value = "StoryBitTick" })
	table.insert(StoryBitTriggersCombo, 1, { text = "", value = "" })
end

---
--- Attempts to create a new StoryBitState for the given StoryBit, if it has not already been created.
---
--- If the StoryBit is enabled, a new StoryBitState will be created with a probability equal to the StoryBit's EnableChance.
---
--- @param storybit table The StoryBit to create a new StoryBitState for.
---
function TryCreateStoryBitState(storybit)
	local id = storybit.id
	if g_StoryBitsLoaded[id] then return end
	g_StoryBitsLoaded[id] = true
	if not storybit.Enabled then return end 
	local chance = storybit.EnableChance
	if chance == 100 or InteractionRand(100, "StoryBitsTickThread") < chance then
		StoryBitState:new{ id = id }
	end
end

MapGameTimeRepeat("StoryBitsTickThread", nil, function(sleep)
	if not sleep then
		if not const.StoryBits or not next(StoryBits) or not mapdata.GameLogic then Halt() end -- no StoryBits defined
		
		if rawget(_G, "g_StoryBitsLogOld") then
			GedRebindRoot(g_StoryBitsLogOld, g_StoryBitsLog)
			g_StoryBitsLogOld = false
		end
		
		ForEachPreset("StoryBit", TryCreateStoryBitState)
		
		if not const.StoryBits.TickDuration then Halt() end -- no Tick defined	
	else
		procall(StoryBitTrigger, "StoryBitTick", nil)
	end
	return const.StoryBits.TickDuration
end)

---
--- Checks the prerequisites for the specified StoryBit.
---
--- @param id string The ID of the StoryBit to check the prerequisites for.
--- @param object table An optional object to use for checking the prerequisites.
--- @return boolean true if the prerequisites are met, false otherwise.
---
function CheckStoryBitPrerequisites(id, object)
	local storybit_state = g_StoryBitStates[id]
	if storybit_state then 
		return storybit_state:CheckPrerequisites(object or storybit_state.object, nil)
	end
end

---
--- Forces the activation of a StoryBit, creating a new StoryBitState if necessary.
---
--- @param id string The ID of the StoryBit to activate.
--- @param object table An optional object to associate with the StoryBit.
--- @param immediate boolean If true, the StoryBit will be activated immediately.
--- @param activated_by table An optional object that activated the StoryBit.
--- @param no_cooldown boolean If true, the StoryBit will not be put on cooldown.
---
function ForceActivateStoryBit(id, object, immediate, activated_by, no_cooldown)
	local storybit_state = g_StoryBitStates[id] or StoryBits[id] and StoryBitState:new{ id = id }
	if not storybit_state then return end
	storybit_state.object = object or storybit_state.object
	if activated_by then
		storybit_state.inherited_title = activated_by:GetTitle()
		storybit_state.inherited_image = activated_by:GetImage()
		storybit_state.player = activated_by.player
	end
	-- the prerequisites have not been checked, do it now as they might pick an object for the story bit
	storybit_state:CheckPrerequisites(object, "force")
	storybit_state:ActivateStoryBit(nil, immediate)
	GetStoryBitCategoryState(id):StorybitActivated(storybit_state, no_cooldown)
end

---
--- Forcefully activates a StoryBit, creating a new StoryBitState if necessary.
---
--- @param socket table The socket to send the RPC response to.
--- @param storybit table The StoryBit to activate.
---
function GedRpcTestStoryBit(socket, storybit)
	if not GameState.gameplay or not storybit then return end
	ForceActivateStoryBit(storybit.id, SelectedObj, "immediate")
end

---
--- Tests the prerequisites for the specified StoryBit and displays the results in a message.
---
--- @param socket table The socket to send the RPC response to.
--- @param storybit table The StoryBit to test the prerequisites for.
---
function GedRpcTestPrerequisitesStoryBit(socket, storybit)
	if not GameState.gameplay or not storybit then return end

	local output = {}
	local id = storybit.id
	local storybit_state = g_StoryBitStates[id] or StoryBitState:new{ id = id, object = SelectedObj }
	for i, p in ipairs(storybit_state:TestPrerequisites(storybit_state.object)) do
		table.insert(output, string.format("Prerequisite %d: %s --> %s", i, p.text, p.res))
	end

	storybit_state.object = SelectedObj
	for i, p in ipairs(storybit_state:TestCategoryPrerequisites(storybit_state.object)) do
		table.insert(output, string.format("Category prerequisite %d: %s --> %s", i, p.text, p.res))
	end
	
	socket:ShowMessage("Test Prerequisites", table.concat(output, "\n"))
end

----- Override these in the game Lua code

---
--- Defines tag lookup table for various text formatting in the game.
---
--- @field condition_text string The tag for condition text.
--- @field /condition_text string The closing tag for condition text.
--- @field outcome_text string The tag for outcome text.
--- @field /outcome_text string The closing tag for outcome text.
--- @field disabled_text string The tag for disabled text.
--- @field /disabled_text string The closing tag for disabled text.
---
const.TagLookupTable["condition_text"]  = ""
const.TagLookupTable["/condition_text"] = ""
const.TagLookupTable["outcome_text"]    = "<color 233 242 255>"
const.TagLookupTable["/outcome_text"]   = "</color>"
const.TagLookupTable["disabled_text"]   = "<color 196 196 196>"
const.TagLookupTable["/disabled_text"]  = "</color>"

---
--- Checks if the specified game object is valid for use in a StoryBit.
---
--- @param obj CObject The game object to check.
--- @return boolean True if the object is valid, false otherwise.
---
function IsStoryBitObjectValid(obj)
	-- override to check for object-specific validity, e.g. is the unit alive
	if obj:IsKindOf("CObject") then
		return IsValid(obj)
	end
	return true
end

---
--- Displays a notification about a StoryBit with the specified title and text, and invokes a callback function when the notification is clicked.
---
--- @param storybit_state StoryBitState The state of the StoryBit.
--- @param storybit table The StoryBit data.
--- @param title string The title of the notification.
--- @param text string The text of the notification.
--- @param expiration_time number The time in seconds after which the notification expires.
--- @param callback function The callback function to invoke when the notification is clicked.
---
function AddStoryBitNotification(storybit_state, storybit, title, text, expiration_time, callback)
	-- display a notification about a StoryBit with the specified 'title' and 'text', invoke 'callback(id)' when the notification is clicked
end

---
--- Removes the notification with the provided id.
---
--- @param id number The id of the notification to remove.
---
function RemoveStoryBitNotification(id)
	-- remove the notification with the provided id
end

---
--- Displays the specified game object and selects it.
---
--- @param object CObject The game object to view and select.
---
function StoryBitViewAndSelectObject(object)
	ViewAndSelectObject(object)
end

---
--- Displays a popup with the specified parameters and waits for the user to make a choice.
---
--- @param id number The unique identifier for the popup.
--- @param title string The title of the popup.
--- @param voiced_text string The voiced text to be played with the popup.
--- @param text string The main text content of the popup.
--- @param actor CObject The game object representing the actor in the popup.
--- @param image string The image to be displayed in the popup.
--- @param choices table An array of choice strings to be displayed in the popup.
--- @param choice_enabled table A boolean array indicating which choices are enabled.
--- @param choice_extra_texts table An array of optional extra text strings for each choice.
--- @return number The index of the chosen option.
---
function WaitStoryBitPopup(id, title, voiced_text, text, actor, image, choices, choice_enabled, choice_extra_texts)
	-- display a game popup with the specified parameters
	-- 'choices' is an array of T values
	-- 'choice_enabled' specifies which choices are enabled
	-- 'choice_extra_texts' specifies optional extra comments for each choice, e.g. why is this choice present / not present
	local context = {
		translate = true,
		title = title,
		text = text,
		disabled = {},
		actor = actor,
	}
	local choices_count = #(choices or empty_table)
	for i, choice in ipairs(choices or empty_table) do
		context["choice" .. i] = T{876135565495, "<choice><newline><extra_text>", choice = choices[i], extra_text = choice_extra_texts[i]}
		context.disabled[i] = not choice_enabled[i]
	end
	return WaitPopupChoice(false, context)
end

---
--- Formats a cost value for display.
---
--- @param cost number The cost value to format.
--- @return string The formatted cost string.
---
function StoryBitFormatCost(cost)
	return T{504461186435, "<cost>", cost = cost}
end

---
--- Checks if the given cost is affordable.
---
--- @param cost number The cost to check.
--- @return boolean True if the cost is affordable, false otherwise.
---
function StoryBitCheckCost(cost)
	return true
end

---
--- Pays the specified cost.
---
--- @param cost number The cost to pay.
---
function StoryBitPayCost(cost)
end

-- for a turn-based game, this could be the number of the turn instead; cooldown logic uses this function
---
--- Gets the current game time.
---
--- @return number The current game time.
---
function StoryBitGetGameTime()
	return GameTime()
end

-- for the Delay property; for a turn-based game 'time' will likely to be number of turns, and this should be reimplemented
---
--- Pauses the game execution for the specified time.
---
--- @param time number The time to pause the game in milliseconds.
---
function StoryBitDelay(time)
	Sleep(time)
end

-- formats time-stamps for the Story Bit Log debug utility
---
--- Formats the current game time as a string in the format "HH:MM:SS".
---
--- @return string The formatted game time string.
---
function StoryBitFormatGameTime()
	local time = GameTime() / 1000
	return string.format("%d:%02d:%02d", time / 3600, time / 60 % 60, time % 60)
end

---
--- Dumps information about all enabled story bits.
---
--- This function iterates through all story bits that are enabled, and prints the ID of any story bit that does not have a corresponding entry in the story bit category state.
---
--- @function DumpStoryBits
--- @return nil
function DumpStoryBits()
	ForEachPreset("StoryBit", function(storybit)
		if storybit.Enabled then
			local category = GetStoryBitCategoryState(storybit.id)
			local idx = table.find_value(category.storybit_states, "id", storybit.id)
			if not idx then
				print(storybit.id)
			end
		end
	end)
end

---
--- Describes all story bits and story bit categories in the game and saves them to a specified folder.
---
--- This function iterates through all enabled story bits and story bit categories, and generates a text description for each one. The descriptions are then saved to individual text files in the specified folder.
---
--- @param dest_folder string The folder path to save the story bit descriptions.
---
function DescribeStoryBits(dest_folder)
	local function AddText(tbl, indent, ...)
		tbl[#tbl + 1] = print_format(...)
		tbl[#tbl + 1] = "\n"
		for i = 1,indent do
			tbl[#tbl + 1] = "    "
		end
	end
	local function GetText(obj, indent)
		if IsT(obj) then
			return _InternalTranslate(obj)
		elseif type(obj) == "table" then
			indent = (indent or 0) + 1
			local tbl = {}
			local init
			if obj.class then
				local def = g_Classes[obj.class]
				AddText(tbl, indent, obj.class)
				for _, prop in ipairs(obj:GetProperties()) do
					local id = prop.id
					local value = obj:GetProperty(id)
					local default = def:GetProperty(id)
					if value ~= default then
						local text = GetText(value, indent) or ""
						if text ~= "" then
							AddText(tbl, indent, id, "=", text)
						end
					end
				end
			else
				AddText(tbl, indent)
				init = #tbl
			end
			for _, value in ipairs(obj) do
				local text = GetText(value, indent) or ""
				if text ~= "" then
					AddText(tbl, indent, text)
				end
			end
			if init and init == #tbl then
				return
			end
			return table.concat(tbl)
		elseif type(obj) ~= "function" then
			return tostring(obj)
		end
	end
	CreateRealTimeThread(function()
		local count, errs = 0, 0
		dest_folder = dest_folder or "AppData/StoryBitDscr"
		local err = AsyncCreatePath(dest_folder)
		if err then
			print(err, "while trying to create path", ConvertToOSPath(dest_folder))
			return
		end
		print("Describing story bits...")
		local texts = {}
		local function Describe(preset)
			local text = GetText(preset)
			local err = AsyncStringToFile(dest_folder .. "/" .. preset.id .. ".txt", text)
			if err then
				errs = errs + 1
				print(preset.id, "failed to save:", err)
				return
			end
			count = count + 1
			print(preset.id)
			texts[#texts + 1] = text
			texts[#texts + 1] = "\n\n------------------------------------------------------------------\n\n"
		end
		ForEachPreset("StoryBit", Describe)
		ForEachPreset("StoryBitCategory", Describe)
		local err = AsyncStringToFile(dest_folder .. "/__ALL__.txt", texts)
		print("\n", count, "presets described in", ConvertToOSPath(dest_folder))
		if errs > 0 then
			print(err, "preset descriptions failed")
		end
	end)
end

---
--- Saves the timestamp for the specified StoryBit outcome ID in the account storage.
---
--- @param id string The ID of the StoryBit outcome to save the timestamp for.
---
function StoryBitSaveTime(id)
	local timestamp = AccountStorage.StoryBitTimestamp or {}
	timestamp[id] = os.time()
	AccountStorage.StoryBitTimestamp = timestamp
	SaveAccountStorage(3000)
end

---
--- Deletes the StoryBit testing backlog, which ensures that all events are tested before being triggered again.
---
--- This function displays a confirmation popup to the user, and if confirmed, it clears the StoryBitTimestamp in the AccountStorage.
---
function DeleteStoryBitTestingBacklog()
	CreateRealTimeThread(function()
		local params = {
			title = Untranslated("Delete StoryBit Testing Backlog"),
			text = Untranslated("The testing backlog ensures that all events are tested before being triggered again. Are you sure to delete it?"),
			choice1 = Untranslated("OK"),
			choice1_img = "UI/CommonNew/message_box_ok.tga",
			choice2 = Untranslated("Cancel"),
			choice2_img = "UI/CommonNew/message_box_cancel.tga",
			start_minimized = false,
		}
		local res = WaitPopupNotification(false, params, nil, terminal.desktop)
		if res == 1 then
			AccountStorage.StoryBitTimestamp = nil
			SaveAccountStorage(3000)
		end
	end)
end

---
--- Sorts a list of StoryBits for testing purposes, based on the timestamp of when each StoryBit was last triggered.
---
--- @param list table A list of StoryBits to sort.
--- @return table The sorted list of StoryBits.
---
function StoryBitsSortForTesting(list)
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	table.sort(list, function(a, b) return (timestamp[a.id] or 0) < (timestamp[b.id] or 0) end)
	return list
end

---
--- Picks a StoryBit outcome for testing purposes, based on the timestamp of when each outcome was last triggered.
---
--- @param outcomes table A list of StoryBit outcomes to pick from.
--- @param storybit table The StoryBit that the outcomes belong to.
--- @return table The selected StoryBit outcome.
---
function StoryBitOutcomeTestingPick(outcomes, storybit)
	local ids = {}
	local id = storybit.id
	local counter = 0
	for _, outcome in ipairs(storybit) do
		if outcome:IsKindOf("StoryBitOutcome") then
			counter = counter + 1
			ids[outcome] = id .. "_outcome_" .. counter
		end
	end
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	table.sort(outcomes, function(a, b)
		local ta = timestamp[ids[a]] or 0
		local tb = timestamp[ids[b]] or 0
		if ta < tb then
			return true
		end
		return a.Weight > b.Weight
	end)
	local result = outcomes[1]
	if not result then
		return
	end
	StoryBitSaveTime(ids[result])
	return result
end

---
--- Picks a random StoryBit category from the given states, based on the timestamp of when each category was last triggered.
---
--- @param states table A table of StoryBit category states.
--- @param object table An object to check the prerequisites of the StoryBit categories against.
--- @return table The selected StoryBit category.
---
function StoryBitCategoryTestingPick(states, object)
	local candidates
	for category_name, category in pairs(states) do
		if category_name ~= "FollowUp"
			and #category.storybit_states > 0 
			and category:CheckPrerequisites(object)
		then
			candidates = candidates or {}
			candidates[#candidates + 1] = category
		end
	end
	if not candidates then
		return
	end
	local timestamp = AccountStorage.StoryBitTimestamp or empty_table
	local max_weight = 7*24*60*60 -- one week
	local now = os.time()
	local category = table.weighted_rand(candidates, function(category)
		local weight = 0
		for _, state in ipairs(category.storybit_states) do
			local weight_i = Min(max_weight, now - (timestamp[state.id] or 0))
			weight = weight + weight_i
		end
		local weight_cat = Min(max_weight, now - (timestamp[category.id] or 0))
		local weight_res = MulDivRound(weight, weight_cat, max_weight)
		return 1 + weight_res
	end)
	if category then
		StoryBitSaveTime(category.id)
		return category
	end
end

---
--- Toggles the story bit testing mode.
--- When enabled, the story bit testing UI will be updated.
---
function ToggleStoryBitTesting()
	g_StoryBitTesting = not g_StoryBitTesting
	UpdateStoryBitTestingUI()
end

function UpdateStoryBitTestingUI() end -- override in project

---
--- Interrupts the suppression times for all story bit states.
--- This function resets the time_created field of each story bit state to -SuppressTime,
--- effectively removing the suppression period and allowing the story bits to be triggered again.
---
function InterruptStoryBitSupressionTimes()
	for id, state in pairs(g_StoryBitStates) do
		local storybit = StoryBits[id]
		local supress_time = storybit.SuppressTime
		state.time_created = -supress_time
	end
end

---
--- Resolves the player object from the given object or context.
---
--- @param obj table|nil The object to extract the player from.
--- @param context table|nil The context to extract the player from.
--- @return table|nil The player object, or nil if not found.
---
function ResolveEventPlayer(obj, context)
	return obj and rawget(obj, "player") or context and rawget(context, "player") or Players and Players[1]
end

------ Notification priorities -------
---
--- Returns the list of notification priorities used in the game.
---
--- The list includes the following priorities:
--- - Normal: Normal priority notifications
--- - Important: Important priority notifications
--- - Critical: Critical priority notifications
--- - StoryBit: Notifications related to story bits
---
--- The `AddGameSpecificNotificationPriorities` function can be overridden in game-specific code to insert additional priorities.
---
--- @return table The list of notification priorities
---
function GetGameNotificationPriorities()
	local priorities = {"Normal", "Important", "Critical", "StoryBit"}
	AddGameSpecificNotificationPriorities(priorities)
	return priorities
end

---
--- Allows game-specific code to insert additional notification priorities.
---
--- This function is intended to be overridden in game-specific code to add any additional notification priorities that the game requires.
---
--- @param priorities table The list of notification priorities to be modified
---
function AddGameSpecificNotificationPriorities(priorities)
end
-- override in game-specific code to insert additional priorities
function AddGameSpecificNotificationPriorities(priorities)
end