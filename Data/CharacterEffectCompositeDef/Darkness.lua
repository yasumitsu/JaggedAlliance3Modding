-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "Darkness",
	'object_class', "CharacterEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					--obj:ClearHierarchyGameFlags(const.gofUnitLighting)
					obj:SetHighlightReason("darkness", true)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "StatusEffectAdded" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks)
				end
				
				if self:VerifyReaction("StatusEffectAdded", reaction_def, obj, obj, id, stacks) then
					exec(self, obj, id, stacks)
				end
			end,
			HandlerCode = function (self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					--obj:ClearHierarchyGameFlags(const.gofUnitLighting)
					obj:SetHighlightReason("darkness", true)
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "obj",
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetHighlightReason("darkness", nil)
					--obj:SetHierarchyGameFlags(const.gofUnitLighting)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "StatusEffectRemoved" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, obj, id, stacks, reason)
				end
				
				if self:VerifyReaction("StatusEffectRemoved", reaction_def, obj, obj, id, stacks, reason) then
					exec(self, obj, id, stacks, reason)
				end
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetHighlightReason("darkness", nil)
					--obj:SetHierarchyGameFlags(const.gofUnitLighting)
				end
			end,
		}),
		PlaceObj('MsgActorReactionEffects', {
			Effects = {
				PlaceObj('ConditionalEffect', {
					'Effects', {
						PlaceObj('ExecuteCode', {
							Code = function (self, obj)
								if IsKindOf(obj, "Unit") then
									obj:SetHighlightReason("darkness", true)
								end
							end,
							SaveAsText = false,
						}),
					},
				}),
			},
			Event = "EnterSector",
			Handler = function (self, game_start, load_game)
				ExecReactionEffects(self, 3, "EnterSector", nil, self, game_start, load_game)
			end,
		}),
	},
	'DisplayName', T(770333565093, --[[CharacterEffectCompositeDef Darkness DisplayName]] "In Darkness"),
	'Description', "",
	'Icon', "UI/Hud/Status effects/darkness",
})

