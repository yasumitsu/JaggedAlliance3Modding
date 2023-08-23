-- ========== GENERATED BY ClassDef Editor (Ctrl-Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('ZuluModuleDef', {
	DefAlwaysAddInstances = true,
	DefEditorMenubar = "Combat",
	DefEditorName = "Combat Tasks",
	DefGlobalMap = "CombatTaskDefs",
	DefOwnerMember = "combatTasks",
	DefParentClassList = {
		"ModulePreset",
		"TODOPreset",
		"MsgReactionsPreset",
	},
	id = "CombatTask",
	PlaceObj('PropertyDefText', {
		'category', "Display",
		'id', "name",
		'name', "Name",
		'default', T(635036510295, --[[ZuluModuleDef CombatTask default]] "Combat Task"),
	}),
	PlaceObj('PropertyDefText', {
		'category', "Display",
		'id', "description",
		'name', "Description",
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Rewards",
		'id', "xpReward",
		'name', "XP Reward",
		'default', 300,
	}),
	PlaceObj('PropertyDefStringList', {
		'category', "Rewards",
		'id', "statGainRolls",
		'name', "Related Stats",
		'help', "Trigger rolls for Stat Gaining for the selected Stats on Task completion.",
		'item_default', "Wisdom",
		'items', function (self) return GetUnitStatsCombo() end,
	}),
	PlaceObj('PropertyDefNestedList', {
		'category', "CombatTask",
		'id', "selectionConditions",
		'name', "Selection Conditions",
		'help', "Explicitly specified",
		'base_class', "Condition",
	}),
	PlaceObj('PropertyDefNestedList', {
		'category', "CombatTask",
		'id', "favouredConditions",
		'name', "Favoured Conditions",
		'help', "Explicitly specified",
		'base_class', "Condition",
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "CombatTask",
		'id', "requiredProgress",
		'name', "Required Progress",
		'help', "Amount of things you need to do.",
		'default', 1,
	}),
	PlaceObj('PropertyDefBool', {
		'category', "CombatTask",
		'id', "hideProgress",
		'name', "Hide Progress",
	}),
	PlaceObj('PropertyDefBool', {
		'category', "CombatTask",
		'id', "holdUntilEnd",
		'name', "Hold until Conflict* End",
		'help', "End is when all non animal enemies have died.",
	}),
	PlaceObj('PropertyDefBool', {
		'category', "CombatTask",
		'id', "reverseProgress",
		'name', "Reverse Progress",
		'help', "If enabled currentProgress must not reach the requiredProgress instead.",
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "CombatTask",
		'id', "cooldown",
		'name', "Cooldown",
		'help', "How much to wait (in SatView time) to be able to select the task again.",
		'default', 432000,
		'scale', "day",
		'min', 0,
		'max', 8640000,
	}),
	PlaceObj('PropertyDefBool', {
		'category', "CombatTask",
		'id', "competition",
		'name', "Competition",
		'help', "Puts the merc in a race against one of his Liked/Disliked",
	}),
	PlaceObj('PropertyDefButtons', {
		'category', "CombatTask",
		'id', "buttonGiveCombatTask",
		'buttons', {
			PlaceObj('PropertyDefPropButton', {
				'Name', "Give Combat Task",
				'FuncName', "GiveCombatTaskEditor",
			}),
		},
		'template', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GiveCombatTaskEditor",
		'params', "root, prop_id, ged",
		'code', function (self, root, prop_id, ged)
			if gv_SatelliteView then return end
			if not IsKindOf(SelectedObj, "Unit") then return end
			GiveCombatTask(self, SelectedObj.session_id)
		end,
	}),
	PlaceObj('ClassConstDef', {
		'name', "currentProgress",
		'type', "number",
		'value', 0,
	}),
	PlaceObj('ClassConstDef', {
		'name', "state",
		'type', "text",
		'value', "inProgress",
	}),
	PlaceObj('ClassConstDef', {
		'name', "additionalData",
		'type', "prop_table",
	}),
	PlaceObj('ClassConstDef', {
		'name', "unitId",
		'type', "text",
	}),
	PlaceObj('ClassConstDef', {
		'name', "otherUnitId",
		'type', "text",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "CanBeSelected",
		'params', "unit",
		'code', function (self, unit)
			if self.competition then
				local hasOpponent = false
				local units = GetCurrentMapUnits()
				for _, u in ipairs(units) do
					if table.find(unit.Likes, u.session_id) or table.find(unit.Dislikes, u.session_id) then
						hasOpponent = true
						break
					end
				end
				if not hasOpponent then
					return false
				end
			end
			
			if not self.selectionConditions or #self.selectionConditions <= 0 then return true end
			return EvalConditionList(self.selectionConditions, self, {target_units = { unit }, no_log = true})
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "IsFavoured",
		'params', "unit",
		'code', function (self, unit)
			for _, stat in ipairs(self.statGainRolls) do
				if unit[stat] >= 70 then
					return true
				end
			end
			
			if self.favouredConditions and #self.favouredConditions > 0 then
				return EvalConditionList(self.favouredConditions, self, {target_units = { unit }, no_log = true})
			end
			
			return false
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "OnAdd",
		'params', "owner, ...",
		'code', function (self, owner, ...)
			if not self.unitId or self.unitId == "" then
				self.unitId = owner.session_id
				
				if self.competition then
					local unit = g_Units[self.unitId]
					local ids = {}
					local units = GetCurrentMapUnits()
					for _, u in ipairs(units) do
						if table.find(unit.Likes, u.session_id) or table.find(unit.Dislikes, u.session_id) then
							ids[#ids+1] = u.session_id
						end
					end
					
					self.otherUnitId = ids[InteractionRand(#ids, "CombatTask")+1]
				end
			end
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Finish",
		'code', function (self)
			ObjModified(self)
			local unit = g_Units[self.unitId]
			
			Msg("CombatTaskFinished", self.id, unit, self.state == "completed")
			
			CombatTaskUIAnimations[self] = {}
			CombatTaskUIAnimations[self].startTime = GetPreciseTicks()
			CombatTaskUIAnimations[self].thread = CreateRealTimeThread(function()
				if not (g_Teams[g_CurrentTeam].control == "UI") then
					WaitMsg("TurnEnded")
				end
				
				local igi = GetInGameInterfaceModeDlg()
				if IsKindOf(igi, "IModeCommonUnitControl") then
					local combatTasks = igi:ResolveId("idCombatTasks")
					for _, taskUI in ipairs(combatTasks) do
						if taskUI.context == self then
							taskUI:Animate()
							Sleep(taskUI.animPulseDuration + taskUI.animHideDuration)
							break
						end
					end
				end
				
				if unit then unit:RemoveCombatTask(self) end
				RefreshCombatTasks()
			end)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Complete",
		'code', function (self)
			if self.state ~= "inProgress" then return end
				
			local unit = g_Units[self.unitId]
			if unit then
				RewardTeamExperience({ RewardExperience = self.xpReward }, { units = {unit}})
			
				for _, stat in ipairs(self.statGainRolls) do
					RollForStatGaining(unit, stat)
				end
				
				PlayVoiceResponse(unit, "CombatTaskCompleted")
			end
			
			self.state = "completed"
			self:Finish()
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Fail",
		'code', function (self)
			if self.state ~= "inProgress" then return end
			
			local unit = g_Units[self.unitId]
			if unit then
				PlayVoiceResponse(unit, "CombatTaskFailed")
			end
			
			self.state = "failed"
			self:Finish()
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Update",
		'params', "progress, otherProgress",
		'code', function (self, progress, otherProgress)
			if self.state ~= "inProgress" then return end
			
			if self.competition then
				self.currentProgress = self.currentProgress + (progress or 0)
				self.requiredProgress = self.requiredProgress + (otherProgress or 0)
			else
				self.currentProgress = Clamp(self.currentProgress + progress, 0, self.requiredProgress)
			end
			
			if self.currentProgress >= self.requiredProgress then
				if not self.holdUntilEnd then
					if self.reverseProgress then
						self:Fail()
					else
						self:Complete()
					end
				end
			end
			
			ObjModified(self)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "ShouldSave",
		'code', function (self)
			return self.state == "inProgress"
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetDynamicData",
		'params', "data",
		'code', function (self, data)
			data.currentProgress = self.currentProgress
			data.state = self.state
			data.additionalData = self.additionalData
			data.unitId = self.unitId
			data.otherUnitId = self.otherUnitId
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "SetDynamicData",
		'params', "data",
		'code', function (self, data)
			self.currentProgress = data.currentProgress
			self.state = data.state
			self.additionalData = data.additionalData
			self.unitId = data.unitId
			self.otherUnitId = data.otherUnitId
		end,
	}),
})

