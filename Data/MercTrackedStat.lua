-- ========== GENERATED BY MercTrackedStat Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('MercTrackedStat', {
	SortKey = 100,
	group = "Contract",
	hide = true,
	id = "CombatTasksCompleted",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "CombatTaskFinished",
			Handler = function (self, taskId, unit, success)
				if success then
					local value = GetTrackedStat(unit, self.id) or 0
					value = value + 1
					SetTrackedStat(unit, self.id, value)
				end
			end,
		}),
	},
	name = T(257329580092, --[[MercTrackedStat CombatTasksCompleted name]] "Combat Tasks Completed"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local value = GetTrackedStat(merc, self.id)
		return value and T{227251647374, "<value>", value = value} or T(555613400236, "-")
	end,
	SortKey = 100,
	group = "Contract",
	id = "DaysInService",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "MercHired",
			Handler = function (self, mercId, price, days)
				local merc = gv_UnitData[mercId]
				local value = GetTrackedStat(merc, self.id)
				if not value or value == 0 then
					SetTrackedStat(merc, self.id, 1)
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "NewDay",
			Handler = function (self)
				local squads = GetPlayerMercSquads()
				for i, squad in ipairs(squads) do
					for i, id in ipairs(squad.units) do
						local unit = gv_UnitData[id]
						local value = GetTrackedStat(unit, self.id) or 0
						value = value + 1
						SetTrackedStat(unit, self.id, value)
					end
				end
			end,
		}),
	},
	name = T(512976696552, --[[MercTrackedStat DaysInService name]] "Days in Service"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local value = GetTrackedStat(merc, self.id)
		return value and T{283666490079, "<money(value)>", value = value} or T(555613400236, "-")
	end,
	SortKey = 100,
	group = "Contract",
	id = "TotalHiringFee",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "MercHired",
			Handler = function (self, mercId, price, days)
				local merc = gv_UnitData[mercId]
				local value = GetTrackedStat(merc, self.id) or 0
				value = value + price
				SetTrackedStat(merc, self.id, value)
			end,
		}),
	},
	name = T(841796250636, --[[MercTrackedStat TotalHiringFee name]] "Total Hiring Fee"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 200,
	group = "Kills",
	id = "TotalKills",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units then
					local value = GetTrackedStat(attacker, self.id) or 0
					value = value + EnemiesKilled(attacker, results)
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(628627388198, --[[MercTrackedStat TotalKills name]] "Total Kills"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 250,
	group = "Kills",
	id = "CivilianCasualties",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units then
					local npcKills = 0
					for _, unit in ipairs(results.killed_units) do
						if IsNPC(unit) and unit.team.side == "neutral" and not unit.immortal then
							npcKills = npcKills + 1
						end
					end
					if npcKills > 0 then
						local value = GetTrackedStat(attacker, self.id) or 0
						value = value + npcKills
						SetTrackedStat(attacker, self.id, value)
					end
				end
			end,
		}),
	},
	name = T(243871965950, --[[MercTrackedStat CivilianCasualties name]] "Civilian Casualties"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 250,
	group = "Kills",
	id = "ExplosiveKills",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units and IsKindOfClasses(results.weapon, "Grenade", "HeavyWeapon", "Ordnance") then
					local value = GetTrackedStat(attacker, self.id) or 0
					value = value + EnemiesKilled(attacker, results)
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(160800834040, --[[MercTrackedStat ExplosiveKills name]] "Explosive Kills"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 250,
	group = "Kills",
	id = "GloryKills",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "UnitDied",
			Handler = function (self, unit, killer, results)
				if IsMerc(killer) and results.glory_kill then
					local value = GetTrackedStat(killer, self.id) or 0
					value = value + 1
					SetTrackedStat(killer, self.id, value)
				end
			end,
		}),
	},
	name = T(712660486858, --[[MercTrackedStat GloryKills name]] "Glory Kills"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 250,
	group = "Kills",
	id = "MeleeKills",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units and results.melee_attack then
					local value = GetTrackedStat(attacker, self.id) or 0
					value = value + EnemiesKilled(attacker, results)
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(978619086191, --[[MercTrackedStat MeleeKills name]] "Melee Kills"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 250,
	group = "Kills",
	id = "StealthKills",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units and results.stealth_attack then
					local value = GetTrackedStat(attacker, self.id) or 0
					value = value + EnemiesKilled(attacker, results)
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(989132504267, --[[MercTrackedStat StealthKills name]] "Stealth Kills"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local state = GetTrackedStat(merc, self.id) or {}
		local name = state.nameId and T{state.nameId, TranslationTable[state.nameId]} or T(555613400236, "-")
		return name
	end,
	SortKey = 290,
	group = "Kills",
	id = "ToughestGuyDefeated",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.killed_units and #results.killed_units > 0 then
					local state = GetTrackedStat(attacker, self.id) or {}
					for _, unit in ipairs(results.killed_units) do
						if attacker:IsOnEnemySide(unit) then
							local newToughness = unit:GetToughness() 
							if not state.toughness or not state.nameId or newToughness > state.toughness then
								state.toughness = newToughness
								state.nameId = TGetID(unit.Name)
								SetTrackedStat(attacker, self.id, state)
							end
						end
					end
				end
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "VillainDefeated",
			Handler = function (self, villain, attacker)
				if IsMerc(attacker) then
					local state = GetTrackedStat(attacker, self.id) or {}
					local newToughness = villain:GetToughness() 
					if not state.toughness or not state.nameId or newToughness > state.toughness then
						state.toughness = newToughness
						state.nameId = TGetID(villain.Name)
						SetTrackedStat(attacker, self.id, state)
					end
				end
			end,
		}),
	},
	name = T(581333093895, --[[MercTrackedStat ToughestGuyDefeated name]] "Toughest Enemy Defeated"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 300,
	group = "Medical",
	id = "MercsTreated",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnBandage",
			Handler = function (self, healer, target, healAmount)
				if IsMerc(healer) then
					local value = GetTrackedStat(healer, self.id) or 0
					value = value + 1
					SetTrackedStat(healer, self.id, value)
				end
			end,
		}),
	},
	name = T(649832721294, --[[MercTrackedStat MercsTreated name]] "Mercs Treated"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local state = GetTrackedStat(merc, self.id) or {}
		local value = state.timeSpent
		return value and T{122010272459, "<day(value)>", value = value} or T(555613400236, "-")
	end,
	SortKey = 300,
	group = "Medical",
	id = "RestingDays",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "UnitDataTick",
			Handler = function (self, unit)
				-- Acumulate time spent
				if IsMerc(unit) then
					if unit.Operation == "RAndR" or unit.Operation == "Idle" then
						local state = GetTrackedStat(unit, self.id) or {}
						if not state.trackTime then
							state.trackTime = Game.CampaignTime
						else
							state.timeSpent = (state.timeSpent or 0) + (Game.CampaignTime - state.trackTime)
							state.trackTime = Game.CampaignTime
						end
						SetTrackedStat(unit, self.id, state)
					end
				end
			end,
		}),
	},
	name = T(451904114488, --[[MercTrackedStat RestingDays name]] "Resting Days"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 300,
	group = "Medical",
	id = "WoundsTaken",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				if IsMerc(obj) and id == "Wounded" then
					local value = GetTrackedStat(obj, self.id) or 0
					value = value + 1
					SetTrackedStat(obj, self.id, value)
				end
			end,
		}),
	},
	name = T(273746787493, --[[MercTrackedStat WoundsTaken name]] "Wounds Taken"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 400,
	group = "SatView",
	id = "ActivitiesCompleted",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OperationChanged",
			Handler = function (self, unit, oldOperation, newOperation)
				if IsMerc(unit) then
					if oldOperation and oldOperation.id ~= "Idle" and oldOperation.id ~= "Traveling" and oldOperation.id ~= "Arriving" then
						local value = GetTrackedStat(unit, self.id) or 0
						value = value + 1
						SetTrackedStat(unit, self.id, value)
					end
				end
			end,
		}),
	},
	name = T(954750259029, --[[MercTrackedStat ActivitiesCompleted name]] "Operations Completed"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 400,
	group = "SatView",
	id = "SectorsCaptured",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "SectorSideChanged",
			Handler = function (self, sectorId, oldSide, newSide)
				if newSide == "player1" or newSide == "player2" then
					local units = GetPlayerSectorUnits(sectorId)
					for i, unit in ipairs(units) do
						local value = GetTrackedStat(unit, self.id) or 0
						value = value + 1
						SetTrackedStat(unit, self.id, value)
					end
				end
			end,
		}),
	},
	name = T(482089400844, --[[MercTrackedStat SectorsCaptured name]] "Sectors Captured"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local value = merc.TravelTime
		return value and T{811734279163, "<time(value)>", value = value} or T(555613400236, "-")
	end,
	SortKey = 400,
	group = "SatView",
	id = "TravelTime",
	name = T(376375248454, --[[MercTrackedStat TravelTime name]] "Travel Time"),
})

PlaceObj('MercTrackedStat', {
	Comment = "implements Hits and Misses also",
	DisplayValue = function (self, merc)
		local value = GetTrackedStat(merc, self.id)
		return value and T{462777279406, "<percent(value)>", value = value} or T(555613400236, "-")
	end,
	SortKey = 500,
	group = "Weapon",
	id = "AverageAccuracy",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and not attack_args.free_aim and target then
					local hitsTotal = GetTrackedStat(attacker, "Hits") or 0
					local missesTotal = GetTrackedStat(attacker, "Misses") or 0
					local hits = 0
					local misses = 0
					
					if IsKindOf(results.weapon, "MeleeWeapon") then
						if results.miss then
							misses = misses + 1 
						else
							hits = hits + 1 
						end
					else
						for _, shot in ipairs(results.shots) do
							if shot.target_hit then
								hits = hits + 1
							else
								misses = misses + 1
							end
						end
					end
					
					hitsTotal = hitsTotal + hits
					missesTotal = missesTotal + misses
					SetTrackedStat(attacker, "Hits", hitsTotal)
					SetTrackedStat(attacker, "Misses", missesTotal)
					
					-- accuracy
					local total = hitsTotal + missesTotal
					local accuracy = total > 0 and MulDivRound(hitsTotal, 100, total) or 0
					SetTrackedStat(attacker, "AverageAccuracy", accuracy)
				end
			end,
		}),
	},
	name = T(377972653498, --[[MercTrackedStat AverageAccuracy name]] "Average Accuracy"),
})

PlaceObj('MercTrackedStat', {
	Comment = "see AverageAccuracy",
	SortKey = 510,
	group = "Weapon",
	id = "Hits",
	name = T(761525783072, --[[MercTrackedStat Hits name]] "Hits"),
})

PlaceObj('MercTrackedStat', {
	Comment = "see AverageAccuracy",
	SortKey = 520,
	group = "Weapon",
	id = "Misses",
	name = T(923653529632, --[[MercTrackedStat Misses name]] "Misses"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 540,
	group = "Weapon",
	id = "Headshots",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and not results.miss then
					local value = GetTrackedStat(attacker, self.id) or 0
					for _, hit in ipairs(results) do
						if hit.spot_group and hit.spot_group == "Head" then
							value = value + 1
						end
					end
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(462899494146, --[[MercTrackedStat Headshots name]] "Headshots"),
})

PlaceObj('MercTrackedStat', {
	SortKey = 580,
	group = "Weapon",
	id = "CriticalHits",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and not results.miss then
					local value = GetTrackedStat(attacker, self.id) or 0
					for _, hit in ipairs(results) do
						if hit.critical then
								value = value + 1
						end
					end
					SetTrackedStat(attacker, self.id, value)
				end
			end,
		}),
	},
	name = T(269938126884, --[[MercTrackedStat CriticalHits name]] "Critical Hits"),
})

PlaceObj('MercTrackedStat', {
	DisplayValue = function (self, merc)
		local state = GetTrackedStat(merc, self.id) or {}
		local id = nil
		local uses = 0
		for k, v in pairs(state) do
			if v > uses then
				id = k
				uses = v
			end
		end
		return id and InventoryItemDefs[id].DisplayName or T(555613400236, "-")
	end,
	SortKey = 590,
	group = "Weapon",
	id = "FavouriteWeapon",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "OnAttack",
			Handler = function (self, attacker, action, target, results, attack_args)
				if IsMerc(attacker) and results.weapon then
					local state = GetTrackedStat(attacker, self.id) or {}
					local weaponUses = state[results.weapon.class] or 0
					state[results.weapon.class] = weaponUses + 1
					SetTrackedStat(attacker, self.id, state)
				end
			end,
		}),
	},
	name = T(567814768055, --[[MercTrackedStat FavouriteWeapon name]] "Favourite Weapon"),
})

