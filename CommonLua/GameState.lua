if FirstLoad then
	GameState = {}
end

if FirstLoad then
GameStateNotifyThread = false
AutoSetGameStates = false
end

---
--- Rebuilds the list of game states that should be automatically set based on the game state definitions.
--- This function iterates through all the game state definitions and adds the state IDs of any definitions that have an AutoSet condition to the AutoSetGameStates list.
---
--- The AutoSetGameStates list is used by the ChangeGameState function to automatically set certain game states based on the defined conditions, in addition to any explicit state changes.
---
--- @function RebuildAutoSetGameStates
--- @return nil
function RebuildAutoSetGameStates()
    AutoSetGameStates = ForEachPreset("GameStateDef", function(state_def, group, states)
        if #(state_def.AutoSet or "") > 0 then
            states[#states + 1] = state_def.id
        end
    end, {})
end

---
--- Changes the game state by updating the `GameState` table with the provided state changes.
---
--- This function supports two ways of changing the game state:
--- 1. Passing a table of state changes, where the keys are the state IDs and the values are the new states.
--- 2. Passing a single state ID and a new state value.
---
--- When a state change is made, this function also handles the following:
--- - AutoSet: Automatically sets any states that have an `AutoSet` condition defined in their game state definition.
--- - GroupExclusive: Ensures that only one state from a group of exclusive states is active at a time.
---
--- After the game state is changed, a `GameStateChanged` message is sent with the list of changes.
---
--- @param state_descr table|string The state changes to apply, either as a table or a single state ID.
--- @param state boolean|nil The new state value, if passing a single state ID.
--- @return table|nil The list of state changes that were made, or nil if no changes were made.
function ChangeGameState(state_descr, state)
    local changed
    local GameState = GameState
    if type(state_descr) == "table" then
        for state_id, state in pairs(state_descr) do
            if (GameState[state_id] or false) ~= state then
                changed = changed or {}
                changed[state_id] = state
                GameState[state_id] = state or nil
            end
        end
    elseif (state_descr or "") ~= "" then
        state = state or false
        if (GameState[state_descr] or false) ~= state then
            changed = {[state_descr]=state}
            GameState[state_descr] = state or nil
        end
    end

    if changed then
        local GameStateDefs = GameStateDefs
        -- AutoSet
        for _, state_id in ipairs(AutoSetGameStates) do
            local state_def = GameStateDefs[state_id]
            if state_def then
                local state = EvalConditionList(state_def.AutoSet, state_def) or false
                if (GameState[state_id] or false) ~= state then
                    assert(changed[state_id] == nil) -- an AutoSet state overwriting ChangeGameState call
                    changed[state_id] = state
                    GameState[state_id] = state or nil
                end
            end
        end
        -- GroupExclusive
        local excluded
        for state_id, state in pairs(GameState) do
            local state_def = GameStateDefs[state_id]
            if state and state_def and state_def.GroupExclusive then
                local group = state_def.group
                for other_id, other_state in sorted_pairs(changed) do
                    if other_state and other_id ~= state_id then
                        local other_state_def = GameStateDefs[other_id]
                        if other_state_def and other_state_def.group == group then
                            assert(not changed[state_id]) -- Adding two states from the same excludive group, undefined result
                            changed[state_id] = false
                            excluded = true
                            break
                        end
                    end
                end
            end
        end
        -- GameState was not changed above because we were iterating on it
        for state_id, state in pairs(excluded and changed) do
            if not state then
                GameState[state_id] = nil
            end
        end

        Msg("GameStateChanged", changed)
        GameStateNotifyThread = GameStateNotifyThread or CreateRealTimeThread(function()
            Msg("GameStateChangedNotify")
            GameStateNotifyThread = false
        end)
    end
    return changed
end

---
--- Waits until the specified game states match the current game state.
---
--- @param states table A table of game state names and their expected active state.
--- @return boolean True if the game states match, false otherwise.
function WaitGameState(states)
    while not MatchGameState(states) do
        WaitMsg("GameStateChanged")
    end
end

---
--- Checks if the current game state matches the specified states.
---
--- @param states table A table of game state names and their expected active state.
--- @return boolean True if the game states match, false otherwise.
function MatchGameState(states)
    local GameState = GameState
    for state, active in pairs(states) do
        local game_state_active = GameState[state] or false
        if active ~= game_state_active then
            return
        end
    end

    return true
end

---
--- Compares the current game state with the provided expected game states and returns information about any mismatches.
---
--- @param states table A table of game state names and their expected active state.
--- @return string A string containing the result, current states, and any mismatched states.
function GetMismatchGameStates(states)
    local GameState = GameState
    local curr_states, mismatches = {}, {}

    for state, active in pairs(GameState) do
        if string.match(state, "^[A-Z]") then
            curr_states[#curr_states + 1] = state
        end
    end

    for state, active in pairs(states) do
        local game_state_active = GameState[state] or false
        if active ~= game_state_active then
            table.insert(mismatches, state)
        end
    end

    local current = string.format("Current states: %s", table.concat(curr_states, ", "))
    local mismatched = (#mismatches > 0) and string.format("Mismatches: %s", table.concat(mismatches, ", "))
                           or "No mismatching states"
    local result = string.format("Result: %s", not (#mismatches > 0))

    return string.format("%s\n%s\n%s", result, current, mismatched)
end

function OnMsg.BugReportStart(print_func)
	local states = {}
	for state, active in pairs(GameState) do
		if active then
			if type(active) ~= "boolean" then
				state = state .. " (" .. tostring(active) .. ")"
			end
			states[#states + 1] = state
		end
	end
	if #states > 0 then
		table.sort(states)
		print_func("GameState:", table.concat(states, ", "), "\n")
	end
end
