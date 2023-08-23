-- ========== GENERATED BY CharacterEffectCompositeDef Editor DO NOT EDIT MANUALLY! ==========

UndefineClass('Hidden')
DefineClass.Hidden = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "CharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectAdded")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks)
				-- remove unit from Revealed tables (visible until end of turn mechanic, NOT Revealed status)
				for team, tbl in pairs(g_RevealedUnits) do
					table.remove_value(tbl, obj)
				end
				Msg("UnitStealthChanged", obj) -- this will invalidate visibility and apply the removed reveals automatically
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks) end
				
			end,
			HandlerCode = function (self, obj, id, stacks)
				-- remove unit from Revealed tables (visible until end of turn mechanic, NOT Revealed status)
				for team, tbl in pairs(g_RevealedUnits) do
					table.remove_value(tbl, obj)
				end
				Msg("UnitStealthChanged", obj) -- this will invalidate visibility and apply the removed reveals automatically
			end,
			param_bindings = false,
		}),
		PlaceObj('MsgReaction', {
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectRemoved")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks, reason)
				if g_Combat and IsKindOf(obj, "Unit") then
					-- check if visible to any enemies
					for _, team in ipairs(g_Teams) do
						if team:IsEnemySide(obj.team) and HasVisibilityTo(team, obj) then				
							obj:RevealTo(team)
						end
					end
				end
				Msg("UnitStealthChanged", obj)
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks, reason) end
				
			end,
			HandlerCode = function (self, obj, id, stacks, reason)
				if g_Combat and IsKindOf(obj, "Unit") then
					-- check if visible to any enemies
					for _, team in ipairs(g_Teams) do
						if team:IsEnemySide(obj.team) and HasVisibilityTo(team, obj) then				
							obj:RevealTo(team)
						end
					end
				end
				Msg("UnitStealthChanged", obj)
			end,
			param_bindings = false,
		}),
	},
	DisplayName = T(529131675951, --[[CharacterEffectCompositeDef Hidden DisplayName]] "Hidden"),
	Description = T(298232269359, --[[CharacterEffectCompositeDef Hidden Description]] "This character is harder to detect by enemies. Allows <em>Stealth Kill</em> attacks against enemies."),
	Icon = "UI/Hud/Status effects/hidden",
	RemoveOnSatViewTravel = true,
	Shown = true,
	HasFloatingText = true,
}

