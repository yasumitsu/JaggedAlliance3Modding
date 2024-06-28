ReactionTargets = {}

---
--- Defines a message definition object that represents a message that can be sent and received in the game.
---
--- @class MsgDef
--- @field Params string The parameters of the message.
--- @field Target string The target of the message.
--- @field Description string The description of the message.
--- @field CopyHandler fun() Copies the handler function for the message to the clipboard.
--- @field OnMsg.ClassesGenerate fun() Defines a preset for the MsgDef class in the editor.
---
DefineClass.MsgDef = {
	__parents = { "Preset" },
	properties = {
		{ id = "Params", editor = "text", default = "", buttons = {{ name = "Copy", func = "CopyHandler" }}, },
		{ id = "Target", editor = "choice", default = "", items = function() return ReactionTargets end },
		{ id = "Description", editor = "text", default = "" },
	},
	GlobalMap = "MsgDefs",
	EditorMenubarName = "Msg defs",
	EditorMenubar = "Editors.Engine",
	EditorIcon = "CommonAssets/UI/Icons/message typing.png",
}

---
--- Copies the handler function for the message to the clipboard.
---
--- @function MsgDef:CopyHandler
--- @return nil
function MsgDef:CopyHandler()
	local handler = string.format("function OnMsg.%s(%s)\n\t\nend\n\n", self.id, self.Params)
	CopyToClipboard(handler)
end

---
--- Defines a preset for the MsgDef class in the editor.
---
--- This function is called when the game's classes are generated, and it defines a preset for the MsgDef class in the editor. The preset includes the following properties:
---
--- - EditorName: "Message definition"
--- - EditorSubmenu: "Other"
--- - Documentation: "Refer to Messages and Reactions documentation for more info."
---
--- This preset allows the MsgDef class to be easily added and configured in the game's editor.
---
--- @function OnMsg.ClassesGenerate
--- @return nil
function OnMsg.ClassesGenerate()
	DefineModItemPreset("MsgDef", { EditorName = "Message definition", EditorSubmenu = "Other", Documentation = "Refer to Messages and Reactions documentation for more info." })
end


---
--- Defines a base class for reactions in the game.
---
--- Reactions are used to define how the game responds to various events or messages. The `Reaction` class provides a set of properties that can be used to configure the behavior of a reaction, such as the event that triggers the reaction, the target of the reaction, and the handler function that implements the reaction logic.
---
--- The `Reaction` class has the following properties:
---
--- - `Event`: The event or message that triggers the reaction. This is defined using a `MsgDef` object.
--- - `Description`: A read-only property that provides a description of the reaction, based on the `Description` property of the associated `MsgDef` object.
--- - `Handler`: The function that implements the reaction logic. The parameters of this function are determined by the `Params` property of the associated `MsgDef` object.
---
--- The `Reaction` class also provides the following methods:
---
--- - `OnEditorSetProperty`: A method that is called when a property of the reaction is set in the editor. This method is used to force the reevaluation of the `Handler` function's parameters when the `Event` property is changed.
--- - `GetParams`: A method that returns the parameter list for the `Handler` function, based on the `Params` property of the associated `MsgDef` object.
--- - `GetHelp`: A method that returns the description of the reaction, based on the `Description` property of the associated `MsgDef` object.
---
DefineClass.Reaction = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Event", editor = "preset_id", default = "", preset_class = "MsgDef", 
			preset_filter = function(preset, obj) return preset.Target == obj.ReactionTarget end },
		{ id = "Description", name = "Description", editor = "help", default = false, dont_save = true, read_only = true, 
			help = function (self) return self:GetHelp() end, },
		{ id = "Handler", editor = "func", default = false, lines = 6, max_lines = 60,
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
	},
	ReactionTarget = "",
	StoreAsTable = true,
	EditorView = T(205999281210, "<u(Event)>(<u(Params)>)"),
}

--- When the `Event` property of a `Reaction` object is set in the editor, this method is called to force the reevaluation of the `Handler` function's parameters.
---
--- This is necessary because the parameters of the `Handler` function are determined by the `Params` property of the associated `MsgDef` object, which is referenced by the `Event` property. When the `Event` property changes, the parameters of the `Handler` function may also change, and this method ensures that the editor reflects the updated parameters.
---
--- @param prop_id string The ID of the property that was set
--- @param old_value any The previous value of the property
--- @param ged table A reference to the GED (Game Editor) object associated with the `Reaction` object
function Reaction:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Event" and type(self.Handler) == "function" then
		-- force reevaluation of the Handler's params when the event changes
		GedSetProperty(ged, self, "Handler", GameToGedValue(self.Handler, self:GetPropertyMetadata("Handler"), self))
	end
end

---
--- Returns the parameter list for the `Handler` function of a `Reaction` object.
---
--- The parameter list is determined by the `Params` property of the `MsgDef` object associated with the `Event` property of the `Reaction` object. If the `Params` property is empty, the parameter list defaults to `self` if the `ReactionTarget` property is empty, or `self, target` if the `ReactionTarget` property is not empty.
---
--- @return string The parameter list for the `Handler` function
function Reaction:GetParams()
	local def = MsgDefs[self.Event]
	if not def then return "" end
	local params = def.Params or ""
	if params == "" then
		return self.ReactionTarget == "" and "self" or "self, target"
	end
	return (self.ReactionTarget == "" and "self, " or "self, target, ") .. params
end

---
--- Returns the description of the reaction, based on the `Description` property of the associated `MsgDef` object.
---
--- @return string The description of the reaction
function Reaction:GetHelp()
	local def = MsgDefs[self.Event]
	return def and def.Description or ""
end


----- ReactionScript

---
--- Defines a `ReactionScript` class that inherits from the `Reaction` class.
---
--- The `ReactionScript` class has a `properties` table that defines a single property:
---
--- - `Handler`: A script editor property that allows the user to define the handler function for the reaction. The name of the property is determined by the `Event` property of the `Reaction` object, and the parameter list is determined by the `GetParams()` function.
---
DefineClass.ReactionScript = {
	__parents = { "Reaction" },
	properties = {
		{ id = "Handler", editor = "script", default = false, lines = 6, max_lines = 60,  
			name = function(self) return self.Event end,
			params = function (self) return self:GetParams() end, },
	},
}


---
--- Defines a preset for reactions, including a target object, a reaction class, and a reactions property.
---
--- @param name string The name of the preset.
--- @param target string The target object for the reactions.
--- @param reactions_member string The name of the reactions member property.
--- @param parent string The parent class for the reactions preset.
---
--- @return table The defined reactions preset class.
function DefineReactionsPreset(name, target, reactions_member, parent)
	assert(name)
	reactions_member = reactions_member or (name .. "_reactions")
	ReactionTargets[#ReactionTargets + 1] = target
	local ReactionClassName = name .. "Reaction"
	DefineClass[ReactionClassName] = {
		__parents = { "Reaction" },
		ReactionTarget = target,
	}
	DefineClass(name .. "ReactionScript", ReactionClassName, "ReactionScript")
	DefineClass[name .. "ReactionsPreset"] = {
		__parents = { parent or "Preset" },
		properties = {
			{ category = "Reactions", id = reactions_member, name = name .. " Reactions", default = false, 
				editor = "nested_list", base_class = ReactionClassName, auto_expand = true, inclusive = true },			
		},
		ReactionTarget = target,
		ReactionsMember = reactions_member,
		EditorMenubarName = false,
	}
end


----- ReactionObject

---
--- Defines a `ReactionObject` class that inherits from the `PropertyObject` class.
---
--- The `ReactionObject` class has the following properties:
---
--- - `reaction_handlers`: A table that stores the reaction handlers for different events.
--- - `reaction_handlers_in_use`: A counter that keeps track of the number of reaction handlers in use.
---
--- This class is used to manage the reactions and their associated handlers.
---
DefineClass.ReactionObject = {
	__parents = { "PropertyObject" },
	reaction_handlers = false,
	reaction_handlers_in_use = 0,
}

local move = table.move
local icopy = table.icopy
---
--- Adds reactions to the `ReactionObject` instance.
---
--- @param instance table|false The instance to add reactions to. If `false`, the reactions will be added to all instances.
--- @param list table A list of reactions to add.
--- @param insert_locations table|nil A table of insert locations for the reactions, keyed by event ID.
---
--- This function adds the reactions specified in the `list` parameter to the `ReactionObject` instance. If `insert_locations` is provided, the reactions will be inserted at the specified locations. Otherwise, the reactions will be added to the end of the existing reaction handlers.
---
--- If the `list` is empty, the function will return without making any changes.
---
--- If the `reaction_handlers_in_use` counter is greater than 0, the function will make a copy of the existing reaction handlers before modifying them, to avoid affecting other instances that may be using the same reaction handlers.
---
--- The function also checks the `ModMsgBlacklist` to ensure that the event ID is not blacklisted before adding the reaction.
---
function ReactionObject:AddReactions(instance, list, insert_locations)
	if #(list or "") == 0 then return end
	local reaction_handlers_in_use = self.reaction_handlers_in_use
	instance = instance or false
	local reaction_handlers = self.reaction_handlers
	if not reaction_handlers then
		reaction_handlers = {}
		self.reaction_handlers = reaction_handlers
	end
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	for _, reaction in ipairs(list) do
		local event_id = reaction.Event
		local handler = reaction.Handler
		if not ModMsgBlacklist[event_id] and handler then
			local handlers = reaction_handlers[event_id]
			if handlers then
				if reaction_handlers_in_use > 0 then
					handlers = icopy(handlers)
					reaction_handlers[event_id] = handlers
				end
				local index = insert_locations and insert_locations[event_id] or #handlers + 1
				move(handlers, index, #handlers, index + 2)
				handlers[index] = instance
				handlers[index + 1] = handler
				if insert_locations and insert_locations[event_id] then
					insert_locations[event_id] = index + 2
				end
			else
				reaction_handlers[event_id] = { instance, handler }
			end
		end
	end
end

---
--- Removes reactions from the `ReactionObject` instance for the specified `instance`.
---
--- @param instance table|false The instance to remove reactions from. If `false`, the reactions will be removed from all instances.
---
--- This function removes all reaction handlers associated with the specified `instance` from the `ReactionObject` instance. If the `reaction_handlers_in_use` counter is greater than 0, the function will make a copy of the existing reaction handlers before modifying them, to avoid affecting other instances that may be using the same reaction handlers.
---
--- If the `instance` parameter is `false`, the function will remove all reaction handlers from the `ReactionObject` instance.
function ReactionObject:RemoveReactions(instance)
	-- remove all handlers for this instance
	instance = instance or false
	local reaction_handlers = self.reaction_handlers
	for event_id, handlers in pairs(reaction_handlers) do
		local reaction_handlers_in_use = self.reaction_handlers_in_use
		for i = #handlers - 1, 1, -2 do
			if instance == handlers[i] then
				if #handlers == 2 then
					reaction_handlers[event_id] = nil
				else
					if reaction_handlers_in_use > 0 then
						handlers = icopy(handlers)
						reaction_handlers[event_id] = handlers
						reaction_handlers_in_use = 0
					end
					move(handlers, i + 2, #handlers + 2, i)
				end
			end
		end
	end
end

-- to be used when the reactions list or handlers have changed
---
--- Reloads the reactions for the specified instance.
---
--- @param instance table The instance to reload reactions for.
--- @param list table A list of new reactions to add for the instance.
---
--- This function first removes all existing reaction handlers for the specified `instance`. It then calls `ReactionObject:AddReactions()` to add the new reactions in the `list` parameter to the `ReactionObject` instance.
---
--- The function asserts that the `reaction_handlers_in_use` counter is 0, which means that no other instances are currently using the reaction handlers. This ensures that the reaction handlers can be safely modified without affecting other instances.
---
--- If the `insert_locations` table is populated, it is used to specify the positions where the new reaction handlers should be inserted. This allows the new handlers to be inserted at the same positions as the old handlers, preserving the order of the handlers.
---
function ReactionObject:ReloadReactions(instance, list)
	assert(self.reaction_handlers_in_use == 0)
	local insert_locations
	local reaction_handlers = self.reaction_handlers
	for event_id, handlers in pairs(reaction_handlers) do
		-- remove all handlers for this instance
		for i = #handlers - 1, 1, -2 do
			if instance == handlers[i] then
				if #handlers == 2 then
					reaction_handlers[event_id] = nil
				else
					if i ~= #handlers - 1 then
						insert_locations = insert_locations or {}
						insert_locations[event_id] = i
					end
					move(handlers, i + 2, #handlers + 2, i)
				end
			end
		end
	end
	-- insert the new handlers at the appropriate places
	self:AddReactions(instance, list, insert_locations)
end

---
--- Adds a new reaction handler for the specified event ID and instance.
---
--- @param event_id string The ID of the event to add the reaction handler for.
--- @param instance table The instance that the reaction handler is associated with.
--- @param handler function The function to call when the event is triggered.
---
--- If the `ModMsgBlacklist` table contains the `event_id`, the reaction handler will not be added.
---
--- The reaction handlers are stored in the `reaction_handlers` table, where the keys are the event IDs and the values are tables containing the instance and handler pairs.
---
--- If the `reaction_handlers_in_use` counter is greater than 0, the handlers table is copied before adding the new handler to avoid modifying the table while it is being used by other instances.
---
function ReactionObject:AddEventReaction(event_id, instance, handler)
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	if not handler or ModMsgBlacklist[event_id] then return end
	local reaction_handlers = self.reaction_handlers
	if not reaction_handlers then
		reaction_handlers = {}
		self.reaction_handlers = reaction_handlers
	end
	local handlers = reaction_handlers[event_id]
	if handlers then
		if self.reaction_handlers_in_use > 0 then
			handlers = icopy(handlers)
			reaction_handlers[event_id] = handlers
		end
		handlers[#handlers + 1] = instance
		handlers[#handlers + 1] = handler
	else
		reaction_handlers[event_id] = { instance, handler }
	end
end

---
--- Removes all event reaction handlers associated with the specified event ID and instance.
---
--- @param event_id string The ID of the event to remove the reaction handlers for.
--- @param instance table The instance that the reaction handlers are associated with.
---
--- This function removes all reaction handlers for the specified event ID and instance from the `reaction_handlers` table. If the `reaction_handlers_in_use` counter is greater than 0, the handlers table is copied before removing the handlers to avoid modifying the table while it is being used by other instances.
---
function ReactionObject:RemoveEventReactions(event_id, instance)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	local reaction_handlers_in_use = self.reaction_handlers_in_use
	for i = #(handlers or "") - 1, 1, -2 do
		if instance == handlers[i] then
			if #handlers == 2 then
				reaction_handlers[event_id] = nil
			else
				if reaction_handlers_in_use > 0 then
					handlers = icopy(handlers)
					reaction_handlers[event_id] = handlers
					reaction_handlers_in_use = 0
				end
				move(handlers, i + 2, #handlers + 2, i)
			end
		end
	end
end

local procall = procall
---
--- Calls all registered reaction handlers for the specified event ID.
---
--- @param event_id string The ID of the event to call the reaction handlers for.
--- @param ... any Additional arguments to pass to the reaction handlers.
---
--- This function calls all registered reaction handlers for the specified event ID. If there are no registered handlers, it returns without doing anything. If there are multiple handlers registered, it calls them in the order they were registered.
---
--- The `reaction_handlers_in_use` counter is incremented while the handlers are being called, to prevent modifications to the `reaction_handlers` table during the call. After all handlers have been called, the counter is decremented.
---
function ReactionObject:CallReactions(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return end
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			procall(handlers[i + 1], handlers[i], self, ...)
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
end

---
--- Calls all registered reaction handlers for the specified event ID, returning the logical AND of the results.
---
--- @param event_id string The ID of the event to call the reaction handlers for.
--- @param ... any Additional arguments to pass to the reaction handlers.
---
--- This function calls all registered reaction handlers for the specified event ID and returns the logical AND of the results. If there are no registered handlers, it returns `true`. If there are multiple handlers registered, it calls them in the order they were registered.
---
--- The `reaction_handlers_in_use` counter is incremented while the handlers are being called, to prevent modifications to the `reaction_handlers` table during the call. After all handlers have been called, the counter is decremented.
---
function ReactionObject:CallReactions_And(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return true end
	local result = true
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, ...)
			if success then
				result = result and res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
	if success then
		result = result and res
	end
	return result
end

---
--- Calls all registered reaction handlers for the specified event ID, returning the logical OR of the results.
---
--- @param event_id string The ID of the event to call the reaction handlers for.
--- @param ... any Additional arguments to pass to the reaction handlers.
---
--- This function calls all registered reaction handlers for the specified event ID and returns the logical OR of the results. If there are no registered handlers, it returns `false`. If there are multiple handlers registered, it calls them in the order they were registered.
---
--- The `reaction_handlers_in_use` counter is incremented while the handlers are being called, to prevent modifications to the `reaction_handlers` table during the call. After all handlers have been called, the counter is decremented.
---
function ReactionObject:CallReactions_Or(event_id, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return false end
	local result = false
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, ...)
			if success then
				result = result or res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, ...)
	if success then
		result = result or res
	end
	return result
end

---
--- Calls all registered reaction handlers for the specified event ID, modifying the provided value based on the results.
---
--- @param event_id string The ID of the event to call the reaction handlers for.
--- @param value any The initial value to pass to the reaction handlers.
--- @param ... any Additional arguments to pass to the reaction handlers.
---
--- This function calls all registered reaction handlers for the specified event ID and modifies the provided value based on the results. If there are no registered handlers, it returns the original value. If there are multiple handlers registered, it calls them in the order they were registered, and the final value is the result of applying all the handlers.
---
--- The `reaction_handlers_in_use` counter is incremented while the handlers are being called, to prevent modifications to the `reaction_handlers` table during the call. After all handlers have been called, the counter is decremented.
---
--- @return any The modified value after applying all the reaction handlers.
function ReactionObject:CallReactions_Modify(event_id, value, ...)
	local reaction_handlers = self.reaction_handlers
	local handlers = reaction_handlers and reaction_handlers[event_id]
	if #(handlers or "") == 0 then return value end
	if #handlers > 2 then
		self.reaction_handlers_in_use = self.reaction_handlers_in_use + 1
		for i = 1, #handlers - 2, 2 do
			local success, res = procall(handlers[i + 1], handlers[i], self, value, ...)
			if success and res ~= nil then
				value = res
			end
		end
		self.reaction_handlers_in_use = self.reaction_handlers_in_use - 1
	end
	local success, res = procall(handlers[#handlers], handlers[#handlers - 1], self, value, ...)
	if success and res ~= nil then
		value = res
	end
	return value
end


---
--- Calls the `CallReactions` method on each object in the provided list for the specified event ID.
---
--- @param list table A list of objects that have a `CallReactions` method.
--- @param event_id string The ID of the event to call the reaction handlers for.
--- @param ... any Additional arguments to pass to the `CallReactions` method.
---
--- This function iterates over the provided list of objects and calls the `CallReactions` method on each object, passing the specified event ID and any additional arguments. This is a convenience function for calling the `CallReactions` method on multiple objects at once.
---
--- @return nil
function ListCallReactions(list, event_id, ...)
	for _, obj in ipairs(list) do
		obj:CallReactions(event_id, ...)
	end
end

----- MsgReactions
---
--- Defines a preset for message reactions.
---
--- @param preset_name string The name of the preset.
--- @param description string The description of the preset.
--- @param field_name string The name of the field in the preset class that contains the message reactions.
---
--- This function defines a new preset class for message reactions. The preset class is used to store a collection of message reactions that can be applied to various events. The `field_name` parameter specifies the name of the field in the preset class that contains the message reactions.

DefineReactionsPreset("Msg", "", "msg_reactions") -- DefineClass.MsgReactionsPreset

-- MsgReactions is defined in cthreads.lua
local MsgReactions = MsgReactions
---
--- Reloads the message reactions defined in the `MsgReactionsPreset` classes.
---
--- This function iterates over all the `MsgReactionsPreset` classes and adds their message reactions to the `MsgReactions` table. The `MsgReactions` table is a global table that stores all the message reactions, indexed by the event ID.
---
--- The function first clears the `MsgReactions` table, then gets a list of all the `MsgReactionsPreset` classes. It then iterates over the list, and for each preset, it iterates over the `msg_reactions` field and adds the reaction handler to the `MsgReactions` table, unless the event ID is blacklisted in the `ModMsgBlacklist` table.
---
--- @
function ReloadMsgReactions()
	table.clear(MsgReactions)
	local list = {}
	ClassDescendants("MsgReactionsPreset", function(classname, classdef, list)
		list[#list + 1] = classdef.PresetClass or classname
	end, list)
	table.sort(list)
	local ModMsgBlacklist = config.Mods and ModMsgBlacklist or empty_table
	local last_preset
	for i, preset_type in ipairs(list) do
		if preset_type ~= last_preset then
			last_preset = preset_type
			ForEachPreset(preset_type, function(preset_instance)
				for _, reaction in ipairs(preset_instance.msg_reactions or empty_table) do
					local event_id = reaction.Event
					local handler = reaction.Handler
					if not ModMsgBlacklist[event_id] and handler then
						local handlers = MsgReactions[event_id]
						if handlers then
							handlers[#handlers + 1] = preset_instance
							handlers[#handlers + 1] = handler
						else
							MsgReactions[event_id] = { preset_instance, handler }
						end
					end
				end
			end)
		end
	end
end

---
--- Reloads the message reactions defined in the `MsgReactionsPreset` classes.
---
--- This function is called when the following events occur:
--- - `OnMsg.ModsReloaded`: When mods are reloaded.
--- - `OnMsg.DataLoaded`: When data is loaded.
--- - `OnMsg.PresetSave`: When a preset is saved.
--- - `OnMsg.DataReloadDone`: When data reload is complete.
---
--- The function iterates over all the `MsgReactionsPreset` classes and adds their message reactions to the `MsgReactions` table, which is a global table that stores all the message reactions, indexed by the event ID. It also handles blacklisting of event IDs using the `ModMsgBlacklist` table.
OnMsg.ModsReloaded = ReloadMsgReactions
OnMsg.DataLoaded = ReloadMsgReactions
OnMsg.PresetSave = ReloadMsgReactions
OnMsg.DataReloadDone = ReloadMsgReactions
