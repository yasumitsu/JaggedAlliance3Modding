MapVar("g_Animals", {})

DefineClass.AmbientLifeAnimal = {
	__parents = {
		"SyncObject", "CombatObject", "AppearanceObject", 
		"HittableObject", "AnimMomentHook", "AmbientLifeZoneUnit"
	},
	
	collision_radius = const.SlabSizeX/3,
	radius = const.SlabSizeX/4,
	
	anim_moments_single_thread = true,
	anim_moments_hook = true,
	__toluacode = empty_func,
	
	PrePlay = empty_func,
	PostPlay = empty_func,
}

--- Removes the current `AmbientLifeAnimal` instance from the global `g_Animals` table.
function AmbientLifeAnimal:Done()
	table.remove_entry(g_Animals, self)
end

--- Adds the current `AmbientLifeAnimal` instance to the global `g_Animals` table.
-- This function is called when the `AmbientLifeAnimal` is initialized.
function AmbientLifeAnimal:GameInit()
	table.insert(g_Animals, self)
end

--- Removes the current `AmbientLifeAnimal` instance from the game.
-- This function is called to despawn the `AmbientLifeAnimal` object.
function AmbientLifeAnimal:Despawn()
	DoneObject(self)
end

--- Called when the `AmbientLifeAnimal` object dies.
-- This function overrides the `CombatObject:OnDie()` function and plays a "die" FX for the animal.
function AmbientLifeAnimal:OnDie(...)
	CombatObject.OnDie(self, ...)
	PlayFX("Animal", "die", self)
end

--- Called when an animation moment occurs for the `AmbientLifeAnimal` object.
-- This function is responsible for playing any FX associated with the current animation moment.
-- If the animal is dead, the function returns early.
-- The function first determines the current animation state, and then plays any FX associated with the current animation moment.
-- If the `anim_moments_hook` table is defined, the function will also call any custom methods associated with the current animation moment.
-- @param moment The current animation moment.
-- @param anim The current animation state (optional).
function AmbientLifeAnimal:OnAnimMoment(moment, anim)
	if self:IsDead() then return end
	
	anim = anim or GetStateName(self)
	PlayFX(FXAnimToAction(anim), moment, self, self.anim_moment_fx_target or nil)
	local anim_moments_hook = self.anim_moments_hook
	if type(anim_moments_hook) == "table" and anim_moments_hook[moment] then
		local method = moment_hooks[moment]
		return self[method](self, anim)
	end
end

DefineClass.AmbientAnimalSpawnDef = {
	__parents = {"PropertyObject"},
	
	properties = {
		{id = "UnitDef", name = "Animal Definition", editor = "dropdownlist", default = false,
			items = ClassDescendantsCombo("AmbientLifeAnimal"),
		},
		{id = "CountMin", name = "Count Min", editor = "number", default = 3},
		{id = "CountMax", name = "Count Max", editor = "number", default = 6},
	},
	
	EditorView = Untranslated("<UnitDef> : <CountMin>-<CountMax>"),
}

DefineClass.AmbientZone_Animal = {
	__parents = {"AmbientZoneMarker", "EditorCallbackObject"},
	
	properties = {
		{category = "Ambient Zone", id = "SpawnDefs", name = "Spawn Definitions", editor = "nested_list",
			base_class = "AmbientAnimalSpawnDef", default = false,
		},
		{id = "Banters"},
		{id = "ApproachBanters"},
	},
	
	entity = "Animal_Hen",
	marker_scale = 400,
	marker_state = "idle2",
	
	persist_units = false,
}

--- Initializes an AmbientZone_Animal object.
---
--- This function sets the scale and state of the AmbientZone_Animal object, and defines a single AmbientAnimalSpawnDef with the "Animal_Hen" unit definition.
---
--- @param self AmbientZone_Animal The AmbientZone_Animal object being initialized.
function AmbientZone_Animal:Init()
	self:SetScale(self.marker_scale)
	self:SetState(self.marker_state)
	self.SpawnDefs = {
		PlaceObj('AmbientAnimalSpawnDef', {
			'UnitDef', "Animal_Hen",
		})	
	}
end

--- Places a spawned animal unit at the specified position.
---
--- @param self AmbientZone_Animal The AmbientZone_Animal object.
--- @param unit_def AmbientAnimalSpawnDef The spawn definition for the animal unit.
--- @param pos table The position to place the animal unit.
--- @return Object The placed animal unit.
function AmbientZone_Animal:PlaceSpawnDef(unit_def, pos)
	local animal = PlaceObject(unit_def.UnitDef)
	animal.zone = self
	animal:SetPos(pos)
	animal:SetScale(70 + self:Random(61))
	animal:SetCommand("Idle")
	
	return animal
end

--- Sets the dynamic data for the AmbientZone_Animal object and spawns the animal units.
---
--- @param self AmbientZone_Animal The AmbientZone_Animal object.
--- @param data table The dynamic data to set for the object.
function AmbientZone_Animal:SetDynamicData(data)
	self:Spawn()
end

AmbientZone_Animal.EditorCallbackPlace = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackMove = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackRotate = AmbientZone_Animal.RecalcAreaPositions
AmbientZone_Animal.EditorCallbackScale = AmbientZone_Animal.RecalcAreaPositions

--- Reduces the number of units in the AmbientZone_Animal object.
---
--- This function iterates through the `units` table of the AmbientZone_Animal object and prints each unit object.
---
--- @param self AmbientZone_Animal The AmbientZone_Animal object.
function AmbientZone_Animal:ReduceUnits()
	for idx, units_def in ipairs(self.units) do
		for _, unit in ipairs(units_def) do
			Msg(unit)
		end
	end
end

--- Checks if the AmbientZone_Animal object has valid area positions.
---
--- This function checks if the AmbientZone_Animal object has any valid area positions. If not, it stores an error source with the message "AmbientZone_Animal without valid area positions. Check Width and Height!".
---
--- @param self AmbientZone_Animal The AmbientZone_Animal object.
function AmbientZone_Animal:VME_Checks()
	if #self:GetAreaPositions() == 0 then
		StoreErrorSource(self, "AmbientZone_Animal without valid area positions. Check Width and Height!")
	end
end

DefineClass.Animal_Hen_Cosmetic = {
	__parents = { "Object" },
	entity = "Animal_Hen",
}

DefineClass.Animal_Hen = {
	__parents = {"AmbientLifeAnimal"},
	entity = "Animal_Hen",
	
	in_combat = false,
}

--- Initializes the Animal_Hen object.
---
--- This function sets the species property of the Animal_Hen object to "Hen".
function Animal_Hen:Init()
	self.species = "Hen"
end

--- Checks if the Animal_Hen object can play the specified animation entry.
---
--- This function checks if the specified animation entry can be played by the Animal_Hen object. If the animation is "fly" or there is no animation, it checks if the object is not in combat. Otherwise, it always returns true.
---
--- @param self Animal_Hen The Animal_Hen object.
--- @param anim_entry table The animation entry to check.
--- @return boolean Whether the animation can be played.
function Animal_Hen:CanPlay(anim_entry)
	if anim_entry.Animation == "fly" or not anim_entry.Animation then
		return not self.in_combat
	end
	
	return true
end

--- Runs before the specified animation entry is played.
---
--- This function is called before the specified animation entry is played for the Animal_Hen object. If the animation entry is "fly", it sleeps for a random duration between 1 second. If the animation entry has no animation, it sets the angle of the object to a random value between 0 and 360 degrees, and sleeps for 200 milliseconds.
---
--- @param self Animal_Hen The Animal_Hen object.
--- @param anim_entry table The animation entry to be played.
function Animal_Hen:PrePlay(anim_entry)
	if anim_entry.Animation == "fly" then
		Sleep(self:Random(1000))
	elseif not anim_entry.Animation then
		self:SetAngle(self:Random(360 * 60), 200)
		Sleep(200)
	end
end

--- Runs after the specified animation entry is played.
---
--- This function is called after the specified animation entry is played for the Animal_Hen object. If the animation entry is "fly" and the game is in combat state, it sets the in_combat property of the object to true.
---
--- @param self Animal_Hen The Animal_Hen object.
--- @param anim_entry table The animation entry that was just played.
function Animal_Hen:PostPlay(anim_entry)
	if GameState.Combat and anim_entry.Animation == "fly" then
		self.in_combat = true
	end
end

--- Handles the idle behavior of the Animal_Hen object.
---
--- This function is responsible for the idle behavior of the Animal_Hen object. It resets the combat path, gets the animation set for the Animal_Hen, and then enters a loop where it plays a random animation from the set. If the game is not in combat state, it sets the in_combat property of the object to false.
---
--- @param self Animal_Hen The Animal_Hen object.
function Animal_Hen:Idle()
	CombatPathReset()

	local anim_set = Presets.AnimationSet["AmbientLife"]["Animal_Hen"]
	while true do
		local anim_entry = anim_set:Play(self)
		if not GameState.Combat then
			self.in_combat = false
		end
	end
end

--- Respawns all AmbientZone_Animal objects on the map.
---
--- This function is called in response to the RespawnAmbientZone_Animal net sync event. It iterates over all AmbientZone_Animal objects on the map, despawns them, and then respawns them.
function NetSyncEvents.RespawnAmbientZone_Animal()
	MapForEach("map", "AmbientZone_Animal", function(zone)
		zone:Despawn()
		zone:Spawn()
	end)
end

function OnMsg.LoadSessionData()
	--this msg comes from a rtt
	FireNetSyncEventOnHost("RespawnAmbientZone_Animal")
end