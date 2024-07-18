GameVar("gv_MoneyLog", {})
--[[
	{
		amount = number, 	
		reason = string,
		time = number
	}
]]

--[[
	MoneyReasons = {
		"system",
		"income",		+
		"salary",		-
		"deposit",	+
		"expense",	-
		"operation"	-
	}
]]

--- Checks if the specified amount can be paid from the current game money balance.
---
--- @param amount number The amount to check if it can be paid.
--- @return boolean True if the amount can be paid, false otherwise.
function CanPay(amount)
	return amount <= 0 or Game.Money >= amount
end

--- Adds the specified amount of money to the game's money balance.
---
--- @param amount number The amount of money to add. Can be negative to subtract money.
--- @param logReason string (optional) The reason for the money change, to be logged.
--- @param noCombatLog boolean (optional) If true, no combat log message will be displayed.
function AddMoney(amount, logReason, noCombatLog)
	if amount == 0 then return end
	
	local previousBalance = Game.Money
	Game.Money = Game.Money + amount

	if logReason then
		local log = {
			amount = amount,
			reason = logReason,
			time = Game.CampaignTime
		}
		gv_MoneyLog[#gv_MoneyLog+1] = log
	end
	
	if not noCombatLog then
		if amount < 0 then
			CombatLog("short", T{227020362130, "Spent <em><money(amount)></em>", amount = -amount})
		else
			CombatLog("short", T{945065893315, "Gained <em><money(amount)></em>", amount = amount})
		end
	end
	
	local pda = GetDialog("PDADialog")
	if pda and pda.window_state ~= "destroying" then
		pda:AnimateMoneyChange(amount)
	end
	
	pda = GetDialog("PDADialogSatellite")
	if pda and pda.window_state ~= "destroying" then
		pda:AnimateMoneyChange(amount)
	end
	
	ObjModified(Game)
	Msg("MoneyChanged", amount, logReason, previousBalance)
end

--- Adds a large amount of money (100,000) to the game's money balance.
---
--- This function is likely a cheat or debug function, and should not be used in normal gameplay.
---
--- @param reason string The reason for the money change, to be logged.
function NetSyncEvents.CheatGetMoney()
	AddMoney(100000, "system")
end

---
--- Returns the daily income from the Forgiving Mode game rule.
---
--- If the Forgiving Mode game rule is active, this function returns the value of the "DailyIncome" property from the game rule definition. Otherwise, it returns 0.
---
--- @return number The daily income from the Forgiving Mode game rule, or 0 if the rule is not active.
function GetForgivingModeDailyIncome()
	if IsGameRuleActive("ForgivingMode") then
		return GameRuleDefs.ForgivingMode:ResolveValue("DailyIncome") or 0
	end
	return 0
end

---
--- Calculates the total income for the specified number of days.
---
--- The income is calculated by summing the income from all sectors, and adding the daily income from the Forgiving Mode game rule.
---
--- @param days number The number of days to calculate the income for. If not provided, defaults to 1.
--- @return number The total income for the specified number of days.
function GetIncome(days)
	local income = 0
	days = days or 1
	
	for id, sector in sorted_pairs(gv_Sectors) do
		income = income + (GetMineIncome(id) or 0)
	end
	
	income =  income + GetForgivingModeDailyIncome()
	
	return income * days
end

---
--- Returns the daily income.
---
--- This function calculates and returns the total income for a single day by calling the `GetIncome` function with a days parameter of 1.
---
--- @return number The total daily income.
function GetDailyIncome()
	return GetIncome(1)
end

---
--- Adds the daily income from the Forgiving Mode game rule to the player's money.
---
--- This function is called every day when the game advances to the next day. It retrieves the daily income from the Forgiving Mode game rule using the `GetForgivingModeDailyIncome()` function, and then adds that amount to the player's money using the `AddMoney()` function.
---
--- @param reason string The reason for the money change, which is set to "ForgivingMode" in this case.
function OnMsg.NewDay()
	AddMoney(GetForgivingModeDailyIncome(),"ForgivingMode")
end

-- Log the previous day income
function OnMsg.NewDay()
	local moneyLog = GetPastMoneyTransfers(const.Scale.day)
	local pastDayIncome = moneyLog.income or 0
	if pastDayIncome > 0 then
		CombatLog("short", T{363617642603, "Daily income: <em><money(amount)></em>", amount = pastDayIncome})
	end
end

---
--- Returns the current daily salary for the specified mercenary.
---
--- If the mercenary is currently hired, this function returns the current daily salary for that mercenary. If the mercenary is not hired, it returns 0.
---
--- @param id number The ID of the mercenary.
--- @return number The current daily salary for the specified mercenary.
function GetMercCurrentDailySalary(id)
	local unitData = gv_UnitData[id]
	if unitData.HiredUntil then
		return GetMercStateFlag(id, "CurrentDailySalary") or GetMercPrice(unitData, 1)
	else
		return 0
	end
end

---
--- Returns the current daily burn rate for all hired mercenaries.
---
--- This function calculates the total daily burn rate by iterating through all hired mercenaries and summing their current daily salaries using the `GetMercCurrentDailySalary()` function.
---
--- @return number The current daily burn rate for all hired mercenaries.
function GetBurnRate()
	local burnRate = 0
	local mercIds = GetHiredMercIds()
	
	for _, id in ipairs(mercIds) do
		burnRate = burnRate + GetMercCurrentDailySalary(id)
	end
	
	return burnRate
end

---
--- Calculates the projected money balance after a specified number of days, taking into account the daily income and the burn rate from hired mercenaries.
---
--- @param days number The number of days to project the money balance for.
--- @return number The projected money balance after the specified number of days.
function GetMoneyProjection(days)
	if not type(days) == "number" then return end
	
	local income = GetIncome(days)
	local burn = 0
	
	local mercIds = GetHiredMercIds()
	for _, id in ipairs(mercIds) do
		local unitData = gv_UnitData[id]
		local HiredUntil = unitData.HiredUntil
		if HiredUntil then
			local timeAfterExpiration = (Game.CampaignTime + const.Scale.day * days) - HiredUntil
			if timeAfterExpiration > 0 then
				burn = burn + GetMercPrice(unitData, DivRound(timeAfterExpiration, const.Scale.day))
			end
		end
	end
	
	local projection = Game.Money + income - burn
	return projection
end

---
--- Returns a table of past money transfers within the specified time period.
---
--- This function iterates through the `gv_MoneyLog` table in reverse order, adding up the amounts for each unique reason until it reaches transfers that occurred outside the specified time period.
---
--- @param time number The number of seconds to look back for past money transfers.
--- @return table A table where the keys are the reasons for the money transfers, and the values are the total amounts transferred for each reason.
function GetPastMoneyTransfers(time)
	local result = {}
	
	for i=#gv_MoneyLog, 1, -1 do
		local log = gv_MoneyLog[i]
		if Game.CampaignTime - log.time <= time then
			result[log.reason] = (result[log.reason] or 0) + log.amount
		else
			break
		end
	end
	
	return result
end

---
--- Returns the daily change in money, calculated as the daily income minus the burn rate.
---
--- @return table A table with the formatted daily money change, with the amount formatted using the `moneyWithSign` function.
function TFormat.GetDailyMoneyChange()
	local dailyIncome = GetDailyIncome()
	local burnRate = GetBurnRate(1)
	local change = dailyIncome - burnRate
	return T{780491782250, "<moneyWithSign(amount)>", amount = change}
end