-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('CharacterEffectCompositeDef', {
	'Group', "System",
	'Id', "StationedMachineGun",
	'object_class', "CharacterEffect",
	'msg_reactions', {
		PlaceObj('MsgActorReaction', {
			Event = "EnterSector",
			Handler = function (self, game_start, load_game)
				
				local function exec(self, reaction_actor, game_start, load_game)
				if not load_game then
					for _, unit in ipairs(g_Units) do
						if unit:HasStatusEffect("StationedMachineGun") then
							unit:InterruptPreparedAttack()
							unit:RemoveStatusEffect("StationedMachineGun")
						end
					end
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[1]
				if not reaction_def or reaction_def.Event ~= "EnterSector" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					local reaction_actor
					exec(self, reaction_actor, game_start, load_game)
				end
				
				
				local actors = self:GetReactionActors("EnterSector", reaction_def, game_start, load_game)
				for _, reaction_actor in ipairs(actors) do
					if self:VerifyReaction("EnterSector", reaction_def, reaction_actor, game_start, load_game) then
						exec(self, reaction_actor, game_start, load_game)
					end
				end
			end,
			HandlerCode = function (self, reaction_actor, game_start, load_game)
				if not load_game then
					for _, unit in ipairs(g_Units) do
						if unit:HasStatusEffect("StationedMachineGun") then
							unit:InterruptPreparedAttack()
							unit:RemoveStatusEffect("StationedMachineGun")
						end
					end
				end
			end,
		}),
		PlaceObj('MsgActorReaction', {
			ActorParam = "unit",
			Event = "UnitEndTurn",
			Handler = function (self, unit)
				
				local function exec(self, unit)
				if g_Overwatch[unit] then
					g_Overwatch[unit].num_attacks = Min(unit:GetNumMGInterruptAttacks(), g_Overwatch[unit].num_attacks or 0)
					ObjModified(unit)
				end
				end
				
				if not IsKindOf(self, "MsgReactionsPreset") then return end
				
				local reaction_def = (self.msg_reactions or empty_table)[2]
				if not reaction_def or reaction_def.Event ~= "UnitEndTurn" then return end
				
				if not IsKindOf(self, "MsgActorReactionsPreset") then
					exec(self, unit)
				end
				
				if self:VerifyReaction("UnitEndTurn", reaction_def, unit, unit) then
					exec(self, unit)
				end
			end,
			HandlerCode = function (self, unit)
				if g_Overwatch[unit] then
					g_Overwatch[unit].num_attacks = Min(unit:GetNumMGInterruptAttacks(), g_Overwatch[unit].num_attacks or 0)
					ObjModified(unit)
				end
			end,
		}),
	},
})

