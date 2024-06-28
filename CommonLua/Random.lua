--- Initializes the `MapLoadRandom` global variable with a random seed value based on the current game state.
---
--- The seed value is determined by the following rules:
--- - If `config.FixedMapLoadRandom` is set, it is used as the seed.
--- - If `Game.seed_text` is not empty, the seed is generated from the text.
--- - If in a networked game using the "sync" network library, the seed is generated from `netGameSeed` and `mapdata.NetHash`.
--- - Otherwise, a random seed is generated using `AsyncRand()`.
---
--- The `InteractionSeeds` and `InteractionSeed` global variables are also initialized based on the `MapLoadRandom` seed.
GameVar("MapLoadRandom", function() return InitMapLoadRandom() end)
GameVar("InteractionSeeds", {})
GameVar("InteractionSeed", function() return MapLoadRandom end)

--- Initializes the `MapLoadRandom` global variable with a random seed value based on the current game state.
---
--- The seed value is determined by the following rules:
--- - If `config.FixedMapLoadRandom` is set, it is used as the seed.
--- - If `Game.seed_text` is not empty, the seed is generated from the text.
--- - If in a networked game using the "sync" network library, the seed is generated from `netGameSeed` and `mapdata.NetHash`.
--- - Otherwise, a random seed is generated using `AsyncRand()`.
---
--- @return number The initialized `MapLoadRandom` seed value.
function InitMapLoadRandom()
	if config.FixedMapLoadRandom then
		return config.FixedMapLoadRandom
	elseif Game and (Game.seed_text or "") ~= "" then
		return xxhash(Game.seed_text)
	elseif netInGame and Libs.Network == "sync" then
		return bxor(netGameSeed, mapdata and mapdata.NetHash or 0)
	else
		return AsyncRand()
	end
end

--- Called when a new map is loaded.
---
--- Initializes the `MapLoadRandom` global variable with a random seed value based on the current game state, and resets the `InteractionRand` random state.
function OnMsg.PreNewMap()
	MapLoadRandom = InitMapLoadRandom()
	ResetInteractionRand(0)
end

--- Called when a new map is loaded.
---
--- Prints the `Game.seed_text` value to the debug log.
function OnMsg.NewMapLoaded()
	if Game then
		DebugPrint("Game Seed: ", Game.seed_text, "\n")
	end
end

local BraidRandom = BraidRandom
local xxhash = xxhash

--- Resets the `InteractionSeeds` and `InteractionSeed` global variables based on the provided `seed` value.
---
--- This function is typically called when a new map is loaded to reset the random state used for interaction-based randomness.
---
--- @param seed number The seed value to use for resetting the random state.
function ResetInteractionRand(seed)
	NetUpdateHash("ResetInteractionRand", seed)
	InteractionSeeds = {}
	InteractionSeed = xxhash(seed, MapLoadRandom)
end

--- Generates a random number within the specified range, using the current interaction-based random state.
---
--- @param max number The maximum value (inclusive) for the random number.
--- @param int_type string The type of interaction to use for the random seed. Can be "none" for no interaction-specific seed.
--- @param obj table|nil The object associated with the interaction, if any.
--- @param target table|nil The target object associated with the interaction, if any.
--- @return number The generated random number.
--- @return number The updated interaction seed value.
function InteractionRand(max, int_type, obj, target)
	assert(type(max) ~= "string")
	int_type = int_type or "none"
	assert(type(int_type) == "string")
	assert(not IsValid(obj) or obj:IsSyncObject() or IsHandleSync(obj.handle) or obj:GetGameFlags(const.gofPermanent) ~= 0)
	if type(max) == "number" and max <= 1 then
		return 0
	end

	local interaction_seeds = InteractionSeeds
	assert(interaction_seeds)
	if not interaction_seeds then
		return 0
	end
	
	local interaction_seed = interaction_seeds[int_type] or xxhash(InteractionSeed, int_type)
	local rand
	rand, interaction_seed = BraidRandom(interaction_seed, max)
	interaction_seeds[int_type] = interaction_seed

	NetUpdateHash("InteractionRand", rand, max, int_type, obj)

	return rand, interaction_seed
end

--- Generates a random number within the specified range, using the current interaction-based random state.
---
--- @param min number The minimum value (inclusive) for the random number.
--- @param max number The maximum value (inclusive) for the random number.
--- @param int_type string The type of interaction to use for the random seed. Can be "none" for no interaction-specific seed.
--- @param obj table|nil The object associated with the interaction, if any.
--- @param target table|nil The target object associated with the interaction, if any.
--- @return number The generated random number.
function InteractionRandRange(min, max, int_type, ...)
	return min + InteractionRand(max - min + 1, int_type, ...)
end

--- Generates a random number within the specified range, using the current interaction-based random state.
---
--- @param range table The range of values for the random number, with `from` and `to` fields.
--- @param int_type string The type of interaction to use for the random seed. Can be "none" for no interaction-specific seed.
--- @param obj table|nil The object associated with the interaction, if any.
--- @param target table|nil The target object associated with the interaction, if any.
--- @return number The generated random number.
function InteractionRandRange2(range, int_type, ...)
	return range.from + InteractionRand(range.to - range.from + 1, int_type, ...)
end

function OnMsg.NewMapLoaded()
	DebugPrint("MapLoadRandom: ", MapLoadRandom, "\n")
end

--- Creates a new interaction-based random number generator.
---
--- @param int_type string The type of interaction to use for the random seed. Can be "none" for no interaction-specific seed.
--- @param obj table|nil The object associated with the interaction, if any.
--- @param target table|nil The target object associated with the interaction, if any.
--- @return table A new random number generator instance.
function InteractionRandCreate(int_type, obj, target)
	return BraidRandomCreate(InteractionRand(nil, int_type, obj, target))
end
