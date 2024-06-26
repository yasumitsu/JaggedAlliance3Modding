---
--- Defines a cooldown effect that can be applied to game objects.
---
--- @class CooldownDef
--- @field DisplayName string The display name of the cooldown effect.
--- @field TimeScale string The time scale used for the cooldown effect (e.g. "sec", "min", "hour").
--- @field TimeMin number The default minimum cooldown time.
--- @field TimeMax number The default maximum cooldown time.
--- @field MaxTime number The maximum time the cooldown can accumulate to.
--- @field ExpireMsg boolean Whether to send a "CooldownExpired" message when the cooldown expires.
--- @field OnExpire function(cooldown_obj, cooldown_def) A function to be called when the cooldown expires.
DefineClass.CooldownDef = {__parents={"Preset"},
    properties={{category="General", id="DisplayName", name="Display Name", editor="text", default=false, translate=true},
        {category="General", id="TimeScale", name="Time Scale", editor="choice", default="sec", items=function(self)
            return GetTimeScalesCombo()
        end},
        {category="General", id="TimeMin", name="Default min", help="Defaut cooldown time.", editor="number",
            default=1000, scale=function(obj)
                return obj.TimeScale
            end},
        {category="General", id="TimeMax", name="Default max", editor="number", default=false, scale=function(obj)
            return obj.TimeScale
        end},
        {category="General", id="MaxTime", name="Max time", help="The maximum time the cooldown can accumulate to.",
            editor="number", default=false, scale=function(obj)
                return obj.TimeScale
            end},
        {category="General", id="ExpireMsg", name="Send CooldownExpired message", editor="bool", default=false},
        {category="General", id="OnExpire", name="OnExpire", editor="script", default=false,
            params="cooldown_obj, cooldown_def"}}, GlobalMap="CooldownDefs", EditorMenubarName="Cooldowns",
    EditorMenubar="Editors.Lists", EditorIcon="CommonAssets/UI/Icons/cooldown.png"}

---
--- Defines a CooldownObj class that manages cooldown effects for game objects.
---
--- @class CooldownObj
--- @field cooldowns table A table of cooldown timers, keyed by cooldown ID.
--- @field cooldowns_thread thread A thread that updates the cooldown timers.
---
DefineClass.CooldownObj = {__parents={"InitDone"}, cooldowns=false, cooldowns_thread=false}

---
--- Initializes the cooldown object, setting up an empty table to store cooldown timers.
---
function CooldownObj:Init()
    self.cooldowns = {}
end

---
--- Destroys the cooldown object by setting the cooldowns table to nil and deleting the cooldowns_thread.
---
function CooldownObj:Done()
    self.cooldowns = nil
    DeleteThread(self.cooldowns_thread)
    self.cooldowns_thread = nil
end

---
--- Gets the remaining time on a cooldown timer.
---
--- @param cooldown_id string The ID of the cooldown timer to get.
--- @return number|boolean The remaining time on the cooldown timer, or `true` if the cooldown is active but has no time remaining.
---
function CooldownObj:GetCooldown(cooldown_id)
    local cooldowns = self.cooldowns
    local time = cooldowns and cooldowns[cooldown_id]
    if not time or time == true then
        return time
    end
    time = time - GameTime()
    if time >= 0 then
        return time
    end
    cooldowns[cooldown_id] = nil
end

---
--- Gets the current cooldown timers for all cooldowns.
---
--- @return table The current cooldown timers, keyed by cooldown ID.
---
function CooldownObj:GetCooldowns()
    for id in pairs(self.cooldowns) do
        self:GetCooldown(id)
    end
    return self.cooldowns
end

---
--- Handles the expiration of a cooldown timer.
---
--- If the cooldown definition has an `ExpireMsg` field, it sends a `CooldownExpired` message with the cooldown ID and definition.
---
--- If the cooldown definition has an `OnExpire` field, it calls the function specified by that field, passing the `CooldownObj` instance and the cooldown definition as arguments. The return value of the `OnExpire` function is returned.
---
--- @param cooldown_id string The ID of the cooldown timer that has expired.
--- @return any The return value of the `OnExpire` function, if it exists.
---
function CooldownObj:OnCooldownExpire(cooldown_id)
    local def = CooldownDefs[cooldown_id]
    assert(def)
    if def.ExpireMsg then
        Msg("CooldownExpired", self, cooldown_id, def)
    end
    local OnExpire = def.OnExpire
    if OnExpire then
        return OnExpire(self, def)
    end
end

---
--- Calculates the default cooldown time for a given cooldown ID and definition.
---
--- If the cooldown definition has a `TimeMin` and `TimeMax` field, this function will return a random value between the minimum and maximum time. Otherwise, it will return the `TimeMin` value.
---
--- @param cooldown_id string The ID of the cooldown timer.
--- @param def table The cooldown definition table.
--- @return number The default cooldown time.
---
function CooldownObj:DefaultCooldownTime(cooldown_id, def)
    def = def or CooldownDefs[cooldown_id]
    local min, max = def.TimeMin, def.TimeMax
    if not max or min > max then
        return min
    end
    return InteractionRandRange(min, max, cooldown_id)
end

---
--- Sets a cooldown timer for the specified cooldown ID.
---
--- If the cooldown definition has a `TimeMin` and `TimeMax` field, the default cooldown time will be a random value between the minimum and maximum time. Otherwise, the default cooldown time will be the `TimeMin` value.
---
--- If the cooldown definition has an `OnExpire` field, it will call the function specified by that field when the cooldown expires, passing the `CooldownObj` instance and the cooldown definition as arguments.
---
--- If the cooldown definition has an `ExpireMsg` field, it will send a `CooldownExpired` message with the cooldown ID and definition when the cooldown expires.
---
--- @param cooldown_id string The ID of the cooldown timer to set.
--- @param time number The duration of the cooldown timer, in seconds. If not provided, the default cooldown time will be used.
--- @param max boolean If true, the cooldown timer will only be set if the previous cooldown has expired.
--- @return boolean True if the cooldown timer was set, false otherwise.
---
function CooldownObj:SetCooldown(cooldown_id, time, max)
    local cooldowns = self.cooldowns
    if not cooldowns then
        return
    end
    local def = CooldownDefs[cooldown_id]
    assert(def)
    if not def then
        return
    end
    time = time or self:DefaultCooldownTime(cooldown_id, def)
    local prev_time = cooldowns[cooldown_id]
    local now = GameTime()
    if time == true then
        cooldowns[cooldown_id] = true
    else
        if max then
            if prev_time == true or prev_time and prev_time - now >= time then
                return
            end
        end
        time = Min(time, def.MaxTime)
        cooldowns[cooldown_id] = now + time
        if def.OnExpire or def.ExpireMsg then
            if IsValidThread(self.cooldowns_thread) then
                Wakeup(self.cooldowns_thread)
            else
                self.cooldowns_thread = CreateGameTimeThread(function(self)
                    while self:UpdateCooldowns() do
                    end
                end, self)
            end
        end
    end
    if not prev_time or prev_time ~= true and prev_time - now < 0 then
        Msg("CooldownSet", self, cooldown_id, def)
    end
end

---
---Modifies the cooldown timer for the specified cooldown ID.

---@param cooldown_id string The ID of the cooldown timer to modify.
---@param delta_time number The amount of time to add or subtract from the cooldown timer, in seconds.
---@return boolean True if the cooldown timer was modified, false otherwise.
---
function CooldownObj:ModifyCooldown(cooldown_id, delta_time)
	local cooldowns = self.cooldowns
	if not cooldowns or (delta_time or 0) == 0 then return end
	local def = CooldownDefs[cooldown_id]
	assert(def)
	local time = cooldowns[cooldown_id]
	if not time or time == true then
		return
	end
	local now = GameTime()
	if time - now < 0 then
		assert(not (def.OnExpire or def.ExpireMsg)) -- messages with expiration effects should be removed by now
		cooldowns[cooldown_id] = nil
		return
	end
	cooldowns[cooldown_id] = now + Min(time + delta_time - now, def.MaxTime)
	if delta_time < 0 and (def.OnExpire or def.ExpireMsg) then
		Wakeup(self.cooldowns_thread)
	end
	return true
end

---
---Modifies the cooldown timers for the specified cooldown IDs.
---
---@param delta_time number The amount of time to add or subtract from the cooldown timers, in seconds.
---@param filter fun(cooldown_id: string, time: number): boolean An optional filter function that determines which cooldown timers to modify.
---@return nil
---
function CooldownObj:ModifyCooldowns(delta_time, filter)
    local cooldowns = self.cooldowns
    if not cooldowns or (delta_time or 0) == 0 then
        return
    end
    if delta_time <= 0 then
        Wakeup(self.cooldowns_thread)
    end
    local now = GameTime()
    for cooldown_id, time in sorted_pairs(cooldowns) do
        if time ~= true and time - now >= 0 or (not filter or filter(cooldown_id, time)) then
            cooldowns[id] = now + Min(time + delta_time - now, def.MaxTime)
        end
    end
end
---Removes the cooldown timer for the specified cooldown ID.
---
---@param cooldown_id string The ID of the cooldown timer to remove.

function CooldownObj:RemoveCooldown(cooldown_id)
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local def = CooldownDefs[cooldown_id]
	assert(def)
	local time = cooldowns[cooldown_id]
	if time then
		cooldowns[cooldown_id] = nil
		if time == true or time - GameTime() >= 0 then
			self:OnCooldownExpire(cooldown_id)
		end
	end
end

---
---Removes the cooldown timers for the specified cooldown IDs that match the provided filter function.
---
---@param filter fun(cooldown_id: string): boolean An optional filter function that determines which cooldown timers to remove.
---@return nil
---
function CooldownObj:RemoveCooldowns(filter)
    local cooldowns = self.cooldowns
    if not cooldowns then
        return
    end
    local removed
    local now = GameTime()
    for cooldown_id, time in sorted_pairs(cooldowns) do
        if not filter or filter(cooldown_id) then
            cooldowns[id] = nil
            if time == true or time - now >= 0 then
                removed = removed or {}
                removed[#removed + 1] = id
            end
        end
    end
    for _, id in ipairs(removed) do
        self:OnCooldownExpire(id)
    end
end

---Updates the cooldown timers for the CooldownObj instance.
---
---This function is responsible for managing the cooldown timers, including expiring timers and triggering any associated events or messages.
---
---It iterates through the cooldowns table, updating the time remaining for each cooldown. If a cooldown has expired, it removes the cooldown from the table and triggers the associated OnCooldownExpire event.
---
---The function also keeps track of the next cooldown that is set to expire, and waits for that cooldown to expire before calling itself again to check for more expired cooldowns.
---
---@param self CooldownObj The CooldownObj instance.
---@return boolean Whether the function should be called again to check for more expired cooldowns.
function CooldownObj:UpdateCooldowns()
    local cooldowns = self.cooldowns
    if not cooldowns then
        return
    end
    local now = GameTime()
    local next_time
    local CooldownDefs = CooldownDefs
    while true do
        local expired, more_expired
        for cooldown_id, time in pairs(cooldowns) do
            if time ~= true then
                local def = CooldownDefs[cooldown_id]
                time = time - now
                if time <= 0 then
                    if def.OnExpire or def.ExpireMsg then
                        if expired then
                            more_expired = true
                            if expired > cooldown_id then
                                expired = cooldown_id
                            end
                        else
                            expired = cooldown_id
                        end
                    else
                        cooldowns[cooldown_id] = nil
                    end
                else
                    if def.OnExpire or def.ExpireMsg then
                        next_time = Min(next_time, time)
                    end
                end
            end
        end
        if expired then
            cooldowns[expired] = nil
            self:OnCooldownExpire(expired)
        end
        if not more_expired then
            break
        end
    end
    if next_time then
        WaitWakeup(next_time)
        return true -- get called again
    end
    self.cooldowns_thread = nil
end

---@brief Gets the dynamic data for the cooldown object.
---
---This function updates the cooldowns dictionary by removing any expired cooldowns. It then returns the updated cooldowns dictionary if there are any remaining cooldowns, or `nil` if the cooldowns dictionary is empty.
---
---@param data table The table to store the dynamic data in.
---@return nil|table The updated cooldowns dictionary, or `nil` if the dictionary is empty.
function CooldownObj:GetDynamicData(data)
    local cooldowns = self.cooldowns
    if not cooldowns then
        return
    end
    local now = GameTime()
    for cooldown_id, time in pairs(cooldowns) do
        if time ~= true and time - now < 0 then
            cooldowns[cooldown_id] = nil
        end
    end
    data.cooldowns = next(cooldowns) and cooldowns or nil
end

---@brief Sets the dynamic data for the cooldown object.
---
---This function updates the cooldowns dictionary by setting the cooldowns from the provided data. If the data.cooldowns is nil, it clears the cooldowns dictionary and deletes the cooldowns_thread. If the data.cooldowns is not nil, it sets the cooldowns dictionary and checks if any cooldowns have expired. If there are expired cooldowns, it wakes up the cooldowns_thread to update the cooldowns.
---
---@param data table The table containing the dynamic data to set.
function CooldownObj:SetDynamicData(data)
    local cooldowns = data.cooldowns
    if not cooldowns then
        self.cooldowns = {}
        DeleteThread(self.cooldowns_thread)
        self.cooldowns_thread = nil
        return
    end
    self.cooldowns = cooldowns
    local CooldownDefs = CooldownDefs
    for cooldown_id, time in pairs(cooldowns) do
        local def = CooldownDefs[def]
        if not def then
            cooldowns[cooldown_id] = nil
        elseif time ~= true then
            if def.OnExpire or def.ExpireMsg then
                if IsValidThread(self.cooldowns_thread) then
                    Wakeup(self.cooldowns_thread)
                else
                    self.cooldowns_thread = CreateGameTimeThread(function(self)
                        while self:UpdateCooldowns() do
                        end
                    end, self)
                end
                return
            end
        end
    end
    DeleteThread(self.cooldowns_thread)
    self.cooldowns_thread = nil
end

---@brief Clears all cooldowns for the CooldownObj instance.
---
---This function iterates through the cooldowns dictionary and sets all cooldown times to nil, effectively clearing all cooldowns. It then calls the OnCooldownExpire function for each cleared cooldown, and sets the cooldowns_thread to nil. Finally, it marks the CooldownObj as modified.
---
---@return nil
function CooldownObj:CheatClearCooldowns()
    local cooldowns = self.cooldowns
    if not cooldowns then
        return
    end
    for cooldown_id in pairs(cooldowns) do
        cooldowns[cooldown_id] = nil
        self:OnCooldownExpire(cooldown_id)
    end
    self.cooldowns_thread = nil
    ObjModified(self)
end
