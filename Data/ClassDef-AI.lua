-- ========== GENERATED BY ClassDef Editor (Ctrl-Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('PresetDef', {
	DefEditorIcon = "CommonAssets/UI/Icons/calculator",
	DefEditorMenubar = "Combat",
	DefGlobalMap = "Archetypes",
	group = "AI",
	id = "AIArchetype",
	PlaceObj('PropertyDefNestedList', {
		'category', "Execution",
		'id', "Behaviors",
		'base_class', "AIBehavior",
	}),
	PlaceObj('PropertyDefChoice', {
		'category', "Strategy",
		'id', "PrefStance",
		'name', "Stance Preference",
		'help', "Stance to use in optimal positions",
		'default', "Standing",
		'items', function (self) return PresetGroupCombo("CombatStance", "Default") end,
	}),
	PlaceObj('PropertyDefChoice', {
		'category', "Execution",
		'id', "MoveStance",
		'name', "Movement Stance",
		'default', "Standing",
		'items', function (self) return PresetGroupCombo("CombatStance", "Default") end,
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Strategy",
		'id', "OptLocSearchRadius",
		'name', "Optimal Location Search Radius",
		'help', "(in tiles)",
		'default', 20,
		'min', 1,
		'max', 100,
	}),
	PlaceObj('PropertyDefNestedList', {
		'category', "Strategy",
		'id', "OptLocPolicies",
		'name', "Optimal Location Policies",
		'base_class', "AIPositioningPolicy",
		'class_filter', function (name, class, obj)
			return class.optimal_location
		end,
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Targeting",
		'id', "TargetBaseScore",
		'name', "Base Score Weight",
		'help', "Score weight based on default attack/aiming logic and chance to hit target.",
		'default', 100,
		'scale', "%",
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Targeting",
		'id', "TargetScoreRandomization",
		'default', 20,
		'scale', "%",
		'min', 0,
		'max', 100,
	}),
	PlaceObj('PropertyDefNestedList', {
		'category', "Targeting",
		'id', "TargetingPolicies",
		'name', "Additional Policies",
		'help', "Additoinal targeting policies that modify target score (optional)",
		'base_class', "AITargetingPolicy",
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Execution",
		'id', "BaseAttackWeight",
		'name', "Base Attack Weight",
		'default', 100,
		'min', 0,
	}),
	PlaceObj('PropertyDefNumber', {
		'category', "Execution",
		'id', "BaseMovementWeight",
		'name', "Base Movement Weight",
		'default', 100,
		'min', 0,
	}),
	PlaceObj('PropertyDefSet', {
		'category', "Execution",
		'id', "BaseAttackTargeting",
		'help', "if any parts are set the unit will pick one of them randomly for each of its basic attacks; otherwise it will always use the default (torso) attacks",
		'items', function (self) return table.keys2(Presets.TargetBodyPart.Default) end,
	}),
	PlaceObj('PropertyDefChoice', {
		'category', "Execution",
		'id', "TargetChangePolicy",
		'help', 'Defines the way the unit handles a stituation where the intended attack target is no longer valid (e.g. dead or Downed). "restart" will force a complete reevaluation of the unit\'s turn, allowing them to perform additional movement if necessary, while "recalc" will only recalculate potential targets from the current position (default behavior).',
		'default', "recalc",
		'items', function (self) return {"recalc", "restart"} end,
	}),
	PlaceObj('PropertyDefChoice', {
		'category', "Execution",
		'id', "FallbackAction",
		'name', "Fallback Action",
		'help', "Defines the way the unit reacts when the AI didn't find anything to do in its turn. By default units will revert to their Unaware status. If this is set to something else, the unit will first attempt to do the chosen action and still revert to Unaware if it fails to do so.",
		'default', "revert",
		'items', function (self) return { "revert", "overwatch" } end,
	}),
	PlaceObj('PropertyDefNestedList', {
		'category', "Execution",
		'id', "SignatureActions",
		'name', "Signature Actions",
		'base_class', "AISignatureAction",
		'class_filter', function (name, class, obj)
			return not class.hidden
		end,
	}),
})

PlaceObj('ClassDef', {
	group = "AI",
	id = "AIBaseHealPolicy",
	PlaceObj('PropertyDefNumber', {
		'id', "MaxHp",
		'name', "Max Hit Points",
		'help', "Percentage of max HP under which allies are considered as targets for healing.",
		'default', 70,
		'scale', "%",
		'min', 0,
		'max', 100,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "BleedingWeight",
		'name', "Bleeding Weight",
		'help', "amount added to score if the target unit has Bleeding",
		'default', 30,
		'min', 0,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "HpWeight",
		'name', "Missing Hp Weight",
		'help', "missing hp percent converts to score at this rate",
		'default', 100,
		'scale', "%",
		'min', 0,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "SelfHealMod",
		'name', "Self Heal Modifier",
		'help', "multiplies the result score when targeting the same unit",
		'default', 50,
		'scale', "%",
		'min', 0,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "CanUseMod",
		'name', "Can Use Mod",
		'help', "modifier applied if the heal action can be used this turn",
		'default', 100,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIConsideration",
	},
	group = "AI",
	id = "AICChanceToHit",
	PlaceObj('ClassConstDef', {
		'name', "Name",
		'type', "translate",
		'value', T(706047359198, --[[ClassDef AI AICChanceToHit value]] "Chance to hit is <percent(RangeText)>"),
	}),
	PlaceObj('ClassConstDef', {
		'name', "ComboFormat",
		'type', "translate",
		'value', T(774449858743, --[[ClassDef AI AICChanceToHit value]] "Chance to hit"),
	}),
	PlaceObj('PropertyDefRange', {
		'id', "Range",
		'default', range(1, 100),
		'min', 0,
		'max', 100,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Score",
		'params', "obj, context",
		'code', function (self, obj, context)
			return obj:CalcChanceToHit(context.target, self)
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIConsideration",
	},
	group = "AI",
	id = "AICMyDistanceTo",
	PlaceObj('ClassConstDef', {
		'name', "Name",
		'type', "translate",
		'value', T(365923306098, --[[ClassDef AI AICMyDistanceTo value]] "My distance to <Target> is <RangeText>"),
		'untranslated', true,
	}),
	PlaceObj('ClassConstDef', {
		'name', "ComboFormat",
		'type', "translate",
		'value', T(903345187719, --[[ClassDef AI AICMyDistanceTo value]] "My distance to ..."),
		'untranslated', true,
	}),
	PlaceObj('PropertyDefCombo', {
		'id', "Target",
		'default', "target",
		'items', function (self) return {"target"} end,
	}),
	PlaceObj('PropertyDefRange', {
		'id', "Range",
		'default', range(0, 0),
		'min', 0,
		'max', 1000000,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Score",
		'params', "obj, context",
		'code', function (self, obj, context)
			local target = context.target
			if not target then
				return 0
			end
			local distance = obj:GetDist(target)
			local min = self.Range.from
			local max = self.Range.to
			if distance < min then
				return 0
			elseif distance >= max then
				return 100
			end
			return MulDiv(100, distance - min, max - min)
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIConsideration",
	},
	group = "AI",
	id = "AICMyStatusEffect",
	PlaceObj('ClassConstDef', {
		'name', "Name",
		'type', "translate",
		'value', T(867699654968, --[[ClassDef AI AICMyStatusEffect value]] "My status <Effect> is <Status>"),
		'untranslated', true,
	}),
	PlaceObj('ClassConstDef', {
		'name', "ComboFormat",
		'type', "translate",
		'value', T(891172370352, --[[ClassDef AI AICMyStatusEffect value]] "My status effect"),
		'untranslated', true,
	}),
	PlaceObj('PropertyDefPresetId', {
		'id', "Effect",
		'name', "",
		'preset_class', "CharacterEffectCompositeDef",
	}),
	PlaceObj('PropertyDefChoice', {
		'id', "Status",
		'default', "on",
		'items', function (self) return {"on", "off"} end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Score",
		'params', "obj, context",
		'code', function (self, obj, context)
			return obj:HasStatusEffect(id) and 100 or 0
		end,
	}),
})

PlaceObj('ClassDef', {
	group = "AI",
	id = "AIConsideration",
	PlaceObj('ClassConstDef', {
		'name', "Name",
		'type', "translate",
	}),
	PlaceObj('ClassConstDef', {
		'name', "ComboFormat",
		'type', "translate",
		'value', T(470337975431, --[[ClassDef AI AIConsideration value]] "<class>"),
	}),
	PlaceObj('ClassMethodDef', {
		'name', "Score",
		'params', "obj, context",
		'code', function (self, obj, context)
			return 0
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return Untranslated("<Name>")
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetRangeText",
		'code', function (self)
			return T{570065600041, "[<min> - <max>]", min = self.Range.from, max = self.Range.to}
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyAttackAP",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local unit = context.unit
			
			local ap = context.dest_ap[dest] or 0
			return ap > context.default_attack_cost and 100 or 0
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyDealDamage",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "CheckLOS",
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return string.format("Deal Damage (%s)", self.CheckLOS and "w/ LOS" or "w/o LOS")
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			if self.CheckLOS and not g_AIDestEnemyLOSCache[dest] then
				return 0
			end
			return context.dest_target_score[dest] or 0
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyDistanceFromStart",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "Away",
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local upos = context.unit_stance_pos
			local threshold = self.Distance * const.SlabSizeX
			local dist = stance_pos_dist(dest, upos)
			if self.Away and dist >= threshold then
				return self.Weight
			elseif not self.Away and dist <= threshold then
				return self.Weight
			end
			return 0
		end,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "Distance",
		'help', "in tiles",
		'default', 5,
		'min', 0,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.Away then
				return string.format("Be %d tiles away from starting location", self.Distance)
			else
				return string.format("Be no more than %d tiles away from starting location", self.Distance)
			end
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyEvadeEnemies",
	PlaceObj('PropertyDefCombo', {
		'id', "RangeBase",
		'name', "Preferred Range (Base)",
		'default', "Effective",
		'items', function (self) return { "Weapon", "Absolute" } end,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "Range",
		'name', "Minimum Range",
		'help', "Percent of base preferred range",
		'default', 80,
		'min', 0,
		'max', 1000,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.RangeBase == "Absolute" then
				return string.format("Keep enemies farther than %d tiles", self.Range)
			end
			return string.format("Keep enemies farther than %d%% of weapon range", self.RangeBase)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local x, y, z = point_unpack(grid_voxel)
			local base_range = self.RangeBase == "Effective" and context.EffectiveRange or context.ExtremeRange
			local range = MulDivRound(self.Range, base_range, 100)
			
			local enemy_in_range
			for _, enemy in ipairs(context.enemies) do
				enemy_in_range = enemy_in_range or AIRangeCheck(context, grid_voxel, enemy, context.enemy_grid_voxel[enemy], self.RangeBase, false, self.Range)
			end
			
			return enemy_in_range and 0 or 100
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyFlanking",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "AllyPlannedPosition",
		'help', "consider allies being on their destination positions instead of their current ones (when available)",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local unit = context.unit
			
			local ap = context.dest_ap[dest] or 0
			if self.ReserveAttackAP and ap < context.default_attack_cost then
				return 0
			end
			
			if not context.position_override then
				context.position_override = {}
				if self.AllyPlannedPosition then
					for _, ally in ipairs(unit.team.units) do
						local dest = ally.ai_context and ally.ai_context.ai_destination
						if dest then
							local x, y, z = stance_pos_unpack(dest)
							context.position_override[ally] = point(x, y, z)
						end
					end
				end
			end
			
			local x, y, z = stance_pos_unpack(dest)
			context.position_override[unit] = point(x, y, z)
			
			if not context.enemy_surrounded then
				context.enemy_surrounded = {}
				for _, enemy in ipairs(context.enemies) do
					if enemy:IsSurrounded() then
						context.enemy_surrounded[enemy] = true
					end
				end
			end
			
			local delta = 0
			for _, enemy in ipairs(context.enemies) do
				local new_surrounded = enemy:IsSurrounded(context.position_override)
				if new_surrounded and not context.enemy_surrounded[enemy] then
					delta = delta + 1
				elseif not new_surrounded and context.enemy_surrounded[enemy] then
					delta = delta - 1
				end
			end
			
			return delta *  self.Weight
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "ReserveAttackAP",
		'name', "Reserve Attack AP",
		'help', "do not consider locations where the unit will be out of ap and couldn't attack",
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
		"AIBaseHealPolicy",
	},
	group = "AI",
	id = "AIPolicyHealingRange",
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return string.format("Be in range to heal allies under %d%% HP", self.MaxHp)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local target, score = AISelectHealTarget(context, dest, grid_voxel, self)
			
			return score or 0
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyHighGround",
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local ux, uy, uz = point_unpack(context.unit_grid_voxel)
			local x, y, z = point_unpack(grid_voxel)
			return self.Weight * (z - uz)
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyIndoorsOutdoors",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "Indoors",
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return self.Indoors and "Be Indoors" or "Be Outdoors"
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			return AICheckIndoors(dest) == self.Indoors
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyLastEnemyPos",
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local last_pos = context.unit.last_known_enemy_pos
			if not last_pos then return 0 end
			local dist = context.unit:GetDist(last_pos)
			local dx, dy, dz = stance_pos_unpack(dest)
			if dist == 0 then
				return (last_pos:Dist(dx, dy, dz) == 0) and self.Weight or 0
			end
			return  self.Weight - MulDivRound(last_pos:Dist(dx, dy, dz), self.Weight, dist)
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyLosToEnemy",
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "Invert",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local los = g_AIDestEnemyLOSCache[dest]
			if self.Invert then
				return g_AIDestEnemyLOSCache[dest] and 0 or 100
			end
			return g_AIDestEnemyLOSCache[dest] and 100 or 0
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.Invert then
				return "Do not have LOS to enemies"
			end
			return "Have LOS to enemies"
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyProximity",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "AllyPlannedPosition",
		'help', "consider allies being on their destination positions instead of their current ones (when available)",
		'extra_code', 'no_edit = function(self) return self.TargetUnits ~= "allies" end',
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local unit = context.unit
			local target_enemies = self.TargetUnits == "enemies"
			local units = target_enemies and context.enemies or context.allies
			local tdist = self.TargetDist
			
			local score = 0
			local num = 0
			local scale = const.SlabSizeX
			
			for _, other in ipairs(units) do
				if other ~= unit then
					local upos
					if target_enemies then
						upos = context.enemy_pack_pos_stance[other]
					else
						upos = context.ally_pack_pos_stance[other]
						if self.AllyPlannedPosition and other.ai_context then
							upos = other.ai_context.ai_destination or upos
						end
					end
					local dist = stance_pos_dist(dest, upos) / scale
					if tdist == "total" or tdist == "average" then
						score = score + dist
					else
						assert(tdist == "min")
						if not score or score > dist then
							score = dist
						end
					end
				end
			end
			
			if tdist == "average" and num > 0 then
				score = score / num
			end
			
			return score >= self.MinScore and score or 0
		end,
	}),
	PlaceObj('PropertyDefChoice', {
		'id', "TargetUnits",
		'name', "TargetUnits",
		'default', "enemies",
		'items', function (self) return { "allies", "enemies"} end,
	}),
	PlaceObj('PropertyDefChoice', {
		'id', "TargetDist",
		'name', "Target Distance",
		'help', "which distance (in tiles) is used to score the target location",
		'default', "min",
		'items', function (self) return { "min", "average", "total"} end,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "MinScore",
		'help', "scores below this will result in zero evaluation for this location",
		'default', 0,
		'min', 0,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyStimRange",
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return string.format("Be in range to heal allies under %d%% HP", self.MaxHp)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			context.voxel_stim_score = context.voxel_stim_score or {}
			if context.voxel_stim_score[grid_voxel] then
				return context.voxel_stim_score[grid_voxel]
			end
			
			local x, y, z = stance_pos_unpack(dest)
			local ppos = point_pack(x, y, z)
			
			local score, target
			local unit = context.unit
			if self.CanTargetSelf then
				score = AIEvalStimTarget(unit, unit, self.Rules)
				target = (score > 0) and unit
			end
			
			for _, ally in ipairs(context.allies) do
				if IsMeleeRangeTarget(unit, ppos, nil, ally) then
					local ally_score = AIEvalStimTarget(unit, ally, self.Rules)
					if ally_score > score then
						score, target = ally_score, ally
					elseif ally_score == score and unit:GetDist(target) > unit:GetDist(ally) then
						score, target = ally_score, ally
					end
				end
			end
			
			score = MulDivRound(score, self.Weight, 100)
			context.voxel_stim_score[grid_voxel] = score
			return score
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefNestedList', {
		'id', "Rules",
		'base_class', "AIStimRule",
		'inclusive', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "CanTargetSelf",
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyTakeCover",
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefChoice', {
		'id', "visibility_mode",
		'name', "Visibility Mode",
		'default', "self",
		'items', function (self) return {"self", "team", "all"} end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local score = 0
			local tbl = context.enemies or empty_table
			for _, enemy in ipairs(tbl) do
				local visible = true
				if self.visibility_mode == "self" then
					 visible = context.enemy_visible[enemy]
				elseif  self.visibility_mode == "team" then
					visible = context.enemy_visible_by_team[enemy]
				end
				if visible then
					local cover = GetCoverFrom(dest, context.enemy_pack_pos_stance[enemy])
					score = score + self.CoverScores[cover]
				end
			end
			
			return  score / Max(1, #tbl)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return "Seek Cover"
		end,
	}),
	PlaceObj('ClassGlobalCodeDef', {
		'comment', "CoverScores",
		'code', function ()
			AIPolicyTakeCover.CoverScores = { 
				[const.CoverPass] = 0, 
				[const.CoverNone] = 0, 
				[const.CoverLow] = 50,
				[const.CoverHigh] = 100,
			}
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIPolicyWeaponRange",
	PlaceObj('PropertyDefSet', {
		'id', "EnvState",
		'name', "Environmental State",
		'items', function (self) return AIEnvStateCombo end,
		'three_state', true,
	}),
	PlaceObj('PropertyDefCombo', {
		'id', "RangeBase",
		'name', "Preferred Range (Base)",
		'default', "Weapon",
		'items', function (self) return { "Melee", "Weapon", "Absolute" } end,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "RangeMin",
		'name', "Preferred Range (Min)",
		'help', "Percent of base preferred range",
		'extra_code', 'no_edit = function(self) return self.RangeBase == "Melee" end',
		'default', 80,
		'min', 0,
		'max', 1000,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "RangeMax",
		'name', "Preferred Range (Max)",
		'help', "Percent of base preferred range",
		'extra_code', 'no_edit = function(self) return self.RangeBase == "Melee" end',
		'default', 120,
		'min', 0,
		'max', 1000,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "DownedWeightModifier",
		'name', "Downed Enemy Weight Modifier",
		'default', 5,
		'scale', "%",
		'min', 0,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.RangeBase == "Melee" then
				return "Be in Melee range"
			elseif self.RangeBase == "Absolute" then
				return string.format("Be in %d to %d tiles range", self.RangeMin, self.RangeMax)
			end
			return string.format("Be in %d%% to %d%% of weapon range", self.RangeMin, self.RangeMax)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			for state, value in pairs(self.EnvState) do
				if value ~= not not GameState[state] then
					return 0
				end
			end
			local enemy_grid_voxel = context.enemy_grid_voxel
			local range_type = self.RangeBase
			local range_min = self.RangeMin
			local range_max = self.RangeMax
			local weight = 0
			for _, enemy in ipairs(context.enemies) do
				if AIRangeCheck(context, grid_voxel, enemy, enemy_grid_voxel[enemy], range_type, range_min, range_max) then
					if enemy:IsIncapacitated() then
						weight = self.DownedWeightModifier
					else
						return 100
					end
				end
			end
			return weight
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
})

PlaceObj('ClassDef', {
	group = "AI",
	id = "AIPositioningPolicy",
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			assert(false, "EvalDest is not implemetned for class " .. self.class)
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
	}),
	PlaceObj('PropertyDefStringList', {
		'id', "RequiredKeywords",
		'template', true,
		'items', function (self) return AIKeywordsCombo end,
		'arbitrary_value', true,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "Weight",
		'default', 100,
		'scale', "%",
	}),
	PlaceObj('PropertyDefBool', {
		'id', "Required",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return self.class
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "MatchUnit",
		'params', "unit",
		'code', function (self, unit)
			for _, keyword in ipairs(self.RequiredKeywords) do
				if not table.find(unit.AIKeywords or empty_table, keyword) then
					return
				end
			end
			return true
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AIPositioningPolicy",
	},
	group = "AI",
	id = "AIRetreatPolicy",
	PlaceObj('ClassMethodDef', {
		'name', "EvalDest",
		'params', "context, dest, grid_voxel",
		'code', function (self, context, dest, grid_voxel)
			local vx, vy = point_unpack(grid_voxel)
			local markers = context.entrance_markers or MapGetMarkers("Entrance")
			context.entrance_markers = markers
			
			local score = 0
			
			for _, marker in ipairs(markers) do
				context.entrance_marker_dir = context.entrance_marker_dir or {}	
				local marker_dir = context.entrance_marker_dir[marker]
				if not marker_dir then
					marker_dir = marker:GetVisualPos() - context.unit:GetVisualPos()
					marker_dir = SetLen(marker_dir:SetZ(0), guim)
					context.entrance_marker_dir[marker] = marker_dir
				end 
				if marker:IsVoxelInsideArea(vx, vy) then
					-- score based on direction
					for _, enemy_dir in pairs(context.enemy_dir) do
						local dot = Dot2D(marker_dir, enemy_dir) / guim
						score = score + guim - dot
					end
				end
			end
			
			return score / Max(1, #(context.enemies or empty_table))
		end,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "optimal_location",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "end_of_turn",
		'read_only', true,
		'no_edit', true,
		'default', true,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "Weight",
		'default', 100,
		'scale', "%",
	}),
	PlaceObj('PropertyDefBool', {
		'id', "Required",
		'default', true,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return "Retreat"
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AITargetingPolicy",
	},
	group = "AI",
	id = "AITargetingCancelShot",
	PlaceObj('PropertyDefNumber', {
		'id', "BaseScore",
		'name', "Base Score",
		'help', "score for valid targets who are not threatening an ally",
		'default', 100,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "AllyThreatenedScore",
		'name', "Threatened Score",
		'help', "score for valid targets who are threatening an ally",
		'default', 100,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return "Use CancelShot"
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalTarget",
		'params', "unit, target",
		'code', function (self, unit, target)
			if not target:HasPreparedAttack() and not target:CanActivatePerk("MeleeTraining") then
				return 0
			end
			
			local enemies = {target}
			
			for _, ally in ipairs(unit.team.units) do
				if ally:IsThreatened(enemies) then
					return self.AllyThreatenedScore
				end
			end
			
			return self.BaseScore
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AITargetingPolicy",
	},
	group = "AI",
	id = "AITargetingEnemyHealth",
	PlaceObj('PropertyDefNumber', {
		'id', "Score",
		'default', 100,
	}),
	PlaceObj('PropertyDefNumber', {
		'id', "Health",
		'default', 100,
		'scale', "%",
		'min', 1,
		'max', 100,
	}),
	PlaceObj('PropertyDefBool', {
		'id', "AboveHealth",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.AboveHealth then
				return string.format("Enemy health >= %d%%", self.Health)
			end
			return string.format("Enemy health <= %d%%", self.Health)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalTarget",
		'params', "unit, target",
		'code', function (self, unit, target)
			local health_perc = MulDivRound(target.HitPoints, 100, target.MaxHitPoints)
			if self.AboveHealth then
				return health_perc >= self.Health and self.Score or 0
			end
			return health_perc <= self.Health and self.Score or 0
		end,
	}),
})

PlaceObj('ClassDef', {
	DefParentClassList = {
		"AITargetingPolicy",
	},
	group = "AI",
	id = "AITargetingEnemyWeapon",
	PlaceObj('PropertyDefNumber', {
		'id', "Score",
		'default', 100,
	}),
	PlaceObj('PropertyDefChoice', {
		'id', "EnemyWeapon",
		'default', "AssaultRifle",
		'items', function (self) return AIEnemyWeaponsCombo() end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			if self.EnemyWeapon == "Unarmed" then
				return "Unarmed enemies"
			end
			return string.format("Enemies armed with %s", self.EnemyWeapon)
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalTarget",
		'params', "unit, target",
		'code', function (self, unit, target)
			if self.EnemyWeapon == "Unarmed" then
				if not target:GetActiveWeapons() then
					return self.Score		
				end
			elseif g_Classes[self.EnemyWeapon] then
				if target:GetActiveWeapons(self.EnemyWeapon) then
					return self.Score
				end
			else -- by weapon type		
				local _, _, list = target:GetActiveWeapons("Firearm")
				for _, item in ipairs(list) do
					if item.WeaponType == self.EnemyWeapon then
						return self.Score
					end
				end
			end
			
			return 0
		end,
	}),
})

PlaceObj('ClassDef', {
	group = "AI",
	id = "AITargetingPolicy",
	PlaceObj('PropertyDefNumber', {
		'id', "Weight",
		'default', 100,
		'scale', "%",
	}),
	PlaceObj('ClassMethodDef', {
		'name', "GetEditorView",
		'code', function (self)
			return self.class
		end,
	}),
	PlaceObj('ClassMethodDef', {
		'name', "EvalTarget",
		'params', "unit, target",
	}),
})

