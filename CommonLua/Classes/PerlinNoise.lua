local max_octaves = 20
local octave_scale = 1024
local noise_scale = 1024
local ratio_scale = 1000

DefineClass.PerlinNoiseBase =
{
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Noise", id = "Frequency",   name = "Frequency (%)",   editor = "number", default = false, min = 0, max = 100, slider = true, help = "A tool for changing the main noise frequency. Depends on the number of octaves and the chosen persistence" },
		{ category = "Noise", id = "Persistence", name = "Persistence",     editor = "number", default = 50,    min = 1, max = 99, slider = true, help = "Defines the behavior of the noise octaves when changing the noise frequency" },
		{ category = "Noise", id = "Octaves",     name = "Octaves Count",   editor = "number", default = 9,     min = 1, max = max_octaves, help = "Number of octaves to use" },
		{ category = "Noise", id = "OctavesList", name = "Octaves",         editor = "text",   default = "",    dont_save = true, help = "Used to copy or paste a set octaves" },
		{ category = "Noise", id = "BestSize",    name = "Best Size",       editor = "number", default = 0,     read_only = true, dont_save = true, help = "Recomended noise grid size" },
	},
	octave_ids = {},
}

---
--- Expands Perlin noise parameters based on the specified count, persistence, main octave, and amplitude.
---
--- @param count integer|nil The number of octaves to generate. If -1, generates octaves until the amplitude becomes negligible.
--- @param persistence number|nil The persistence factor, which determines how the amplitude of each octave decreases. Defaults to 50.
--- @param main integer|nil The index of the main octave. Defaults to 1.
--- @param amp number|nil The amplitude of the main octave. Defaults to `octave_scale`.
--- @return table A table of octave amplitudes, indexed by octave index.
---
function ExpandPerlinParams(count, persistence, main, amp)
	count = count or -1
	persistence = persistence or 50
	main = main or 1
	
	if count == 0 then return "" end
	local octaves = {}
	amp = amp or octave_scale
	octaves[main] = amp
	local i = 0
	while i ~= count do
		i = i + 1
		local new_amp = amp * persistence / 100
		if new_amp == amp and count <= 0 then
			break
		end
		amp = new_amp
		local left = main - i
		local right = main + i
		if count > 0 and left < 1 and right > count then
			break
		end
		if left >= 1 then
			octaves[left] = amp
		end
		if count < 0 or right <= count then
			octaves[right] = amp
		end
	end
	return octaves
end

do
	local params = ExpandPerlinParams(max_octaves, 50)
	local octave_ids = PerlinNoiseBase.octave_ids
	for i=1,max_octaves do
		local id = "Octave_"..i
		octave_ids[i] = id
		octave_ids[id] = i
		table.insert(PerlinNoiseBase.properties, {
			id = id,
			name = "Octave "..i,
			editor = "number",
			default = params[i] or 0,
			category = "Noise",
			min = 0, max = octave_scale, slider = true,
			no_edit = function(self) return self.Octaves < i end,
		})
	end
end

--- Returns a comma-separated string of the octave values.
---
--- This function exports the octave values as a string that can be used to set the octave list.
---
--- @return string A comma-separated string of the octave values.
function PerlinNoiseBase:GetOctavesList()
	return table.concat(self:ExportOctaves(), ', ')
end

--- Sets the octave values from a comma-separated string.
---
--- This function takes a comma-separated string of octave values and imports them into the PerlinNoiseBase object.
---
--- @param list string A comma-separated string of octave values.
--- @return boolean True if the octaves were successfully imported, false otherwise.
function PerlinNoiseBase:SetOctavesList(list)
	local octaves = dostring("return {" .. list .. "}")
	if octaves then
		return self:ImportOctaves(octaves)
	end
end

--- Returns the best size for the Perlin noise grid based on the number of octaves.
---
--- The best size is calculated as 2 raised to the power of the number of octaves. This ensures that the grid size is a power of 2, which is optimal for Perlin noise generation.
---
--- @return integer The best size for the Perlin noise grid.
function PerlinNoiseBase:GetBestSize()
	return 2 ^ self.Octaves
end

--- Callback function that is called when a property of the PerlinNoiseBase object is edited in the editor.
---
--- This function is responsible for updating the main octave value when certain properties are changed, such as Frequency, Persistence, or Octaves. It also handles updating the octave-specific properties when other octave-related properties are changed.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The editor object that triggered the property change.
function PerlinNoiseBase:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Frequency" or prop_id == "Persistence" or prop_id == "Octaves" then
		if self.Frequency then
			local mo = 1 + MulDivRound(self.Octaves - 1, self.Frequency, 100)
			self:SetMainOctave(mo)
		end
	elseif self.octave_ids[prop_id] then
		self.Frequency = nil
	end
end

--- Sets the main octave value for the Perlin noise generation.
---
--- This function updates the octave values of the PerlinNoiseBase object based on the provided main octave value. It calls the `ImportOctaves` function to update the octave-specific properties.
---
--- @param mo number The new main octave value.
function PerlinNoiseBase:SetMainOctave(mo)
	if not mo then
		return
	end
	local params = ExpandPerlinParams(self.Octaves, self.Persistence, mo)
	self:ImportOctaves(params)
end

---
--- Exports the octave values of the PerlinNoiseBase object as a table.
---
--- This function iterates through the octave-specific properties of the PerlinNoiseBase object and collects their values into a table. It then removes any trailing zero values from the end of the table, as they are not needed for Perlin noise generation.
---
--- @return table The table of octave values.
function PerlinNoiseBase:ExportOctaves()
	local octaves = {}
	local octave_ids = self.octave_ids
	for i=1,self.Octaves do	
		octaves[#octaves + 1] = self[octave_ids[i]]
	end
	for i=self.Octaves,1,-1 do
		if octaves[i] ~= 0 then
			break
		end
		octaves[i] = nil
	end
	return octaves
end

---
--- Imports the octave values for the Perlin noise generation.
---
--- This function takes a table of octave values and updates the corresponding properties of the PerlinNoiseBase object. It sets the Octaves property to the length of the octaves table, and then iterates through the table, assigning each value to the corresponding octave-specific property.
---
--- @param octaves table The table of octave values to import.
function PerlinNoiseBase:ImportOctaves(octaves)
	self.Octaves = #octaves
	local params = {}
	local octave_ids = self.octave_ids
	for i=1,max_octaves do
		self[octave_ids[i]] = octaves[i]
	end
end

---
--- Generates raw Perlin noise using the specified parameters.
---
--- This function generates Perlin noise using the octave values stored in the PerlinNoiseBase object. It takes an optional random seed value, and a compute grid object to store the generated noise. The function calls the GridPerlin function to generate the noise and returns the compute grid.
---
--- @param rand_seed number|nil The random seed value to use for the noise generation. If not provided, the Seed property of the PerlinNoiseBase object is used.
--- @param g ComputeGrid The compute grid object to store the generated noise.
--- @return ComputeGrid, any The compute grid with the generated noise, and any additional return values from the GridPerlin function.
function PerlinNoiseBase:GetNoiseRaw(rand_seed, g, ...)
	rand_seed = self.Seed + (rand_seed or 0)
	GridPerlin(rand_seed, self:ExportOctaves(), g, ...)
	return g, ...
end

----

DefineClass.PerlinNoise =
{
	__parents = { "PerlinNoiseBase" },
	properties = {
		{ id = "Seed",    name = "Random Seed",     editor = "number", default = 0,             category = "Noise", buttons = {{name = "Rand", func = "ActionRand"}}, help = "Fixed randomization seed"},
		{ id = "Size",    name = "Grid Size",       editor = "number", default = 256,           category = "Noise", min = 2, max = 2048, help = "Size of the noise grid" },
		{ id = "Min",     name = "Min Value",       editor = "number", default = 0,             category = "Noise", },
		{ id = "Max",     name = "Max Value",       editor = "number", default = noise_scale,   category = "Noise", },
		{ id = "Preview",                           editor = "grid",   default = false,         category = "Noise", dont_save = true, interpolation = "nearest", frame = 1, min = 128, max = 512, read_only = true, no_validate = true },
		{ id = "Clamp",   name = "Clamp Range (%)", editor = "range",  default = range(0, 100), category = "Post Process", min = 0, max = 100, slider = true, help = "Clamp the noise in that range and re-normalize afterwards" },
		{ id = "Sin",     name = "Sin Unity (%)",   editor = "number", default = 0,             category = "Post Process", min = 0, max = 100, slider = true, help = "Applies sinusoidal easing. Useful to smooth noise after clamping" },
		{ id = "Mask",    name = "Mask Area (%)",   editor = "number", default = 0,             category = "Post Process", min = 0, max = 100, slider = true, help = "Creates a mask with that percentage of area" },
	},
}

---
--- Called when the noise properties have changed.
---
--- This function is called when any of the noise properties, such as the seed, size, or post-processing settings, have been modified. It allows the PerlinNoise object to perform any necessary updates or recalculations in response to the changes.
---
--- @param self PerlinNoise The PerlinNoise object that has been modified.
function PerlinNoise:OnNoiseChanged()
end

---
--- Returns a preview of the Perlin noise generated by this object.
---
--- This function generates a preview of the Perlin noise using the current noise properties, such as the seed, size, and post-processing settings. The preview is returned as a compute grid object.
---
--- @return ComputeGrid The compute grid containing the Perlin noise preview.
function PerlinNoise:GetPreview()
	return self:GetNoise()
end

---
--- Returns a preview of the Perlin noise generated for the specified noise preset.
---
--- This function generates a preview of the Perlin noise using the properties defined in the specified noise preset. The preview is returned as a compute grid object.
---
--- @param noise_name string The name of the noise preset to use for generating the preview.
--- @return ComputeGrid The compute grid containing the Perlin noise preview.
function GetNoisePreview(noise_name)
	local noise_preset = NoisePresets[noise_name]
	return noise_preset and noise_preset:GetPreview()
end

---
--- Generates a Perlin noise grid and applies post-processing to it.
---
--- This function generates a Perlin noise grid using the current noise properties, such as the seed, size, and post-processing settings. The generated noise grid is then passed through the `PostProcess` function to apply any additional transformations, such as clamping, sinusoidal easing, or masking.
---
--- @param rand_seed number The random seed to use for generating the Perlin noise.
--- @param g ComputeGrid An optional compute grid to use for the noise generation. If not provided, a new grid will be created.
--- @return ComputeGrid The compute grid containing the processed Perlin noise.
function PerlinNoise:GetNoise(rand_seed, g, ...)
	g = g or NewComputeGrid(self.Size, self.Size, "F")
	return self:PostProcess(self:GetNoiseRaw(rand_seed, g, ...))
end

---
--- Applies post-processing to a Perlin noise grid.
---
--- This function takes a Perlin noise grid and applies various post-processing operations to it, such as clamping the noise values to a specified range, applying sinusoidal easing, and masking the noise.
---
--- @param g ComputeGrid The compute grid containing the Perlin noise to be post-processed.
--- @param ... Any additional arguments to be passed to the post-processing functions.
--- @return ComputeGrid The compute grid containing the post-processed Perlin noise.
function PerlinNoise:PostProcess(g, ...)
	if not g then
		return
	end
	local min, max = self.Min, self.Max
	local smin, smax = min * ratio_scale, max * ratio_scale
	local function pct(v)
		return smin + MulDivRound(smax - smin, v, 100)
	end
	
	GridNormalize(g, min, max)
	if self.Clamp.from > 0 or self.Clamp.to < 100 then
		local from = pct(self.Clamp.from)
		local to = pct(self.Clamp.to)
		GridClamp(g, from, to, ratio_scale)
		GridRemap(g, from, to, smin, smax, ratio_scale)
	end
	if self.Sin ~= 0 then
		local unity = pct(self.Sin)
		if unity > smin then
			GridSin(g, smin, unity, ratio_scale)
			GridRemap(g, -1, 1, min, max)
		end
	end
	if self.Mask ~= 0 then
		local level = GridLevel(g, self.Mask, 100, ratio_scale)
		GridMask(g, 0, level, ratio_scale)
		GridRemap(g, 0, 1, min, max)
	end
	--NetUpdateHash("PerlinNoise", g)
	return g, self:PostProcess(...)
end

---
--- Generates a new random seed for the Perlin noise and marks the object as modified.
---
--- @param root any The root object.
--- @param prop_id string The property ID.
--- @param ged any The GED object.
function PerlinNoise:ActionRand(root, prop_id, ged)
	self.Seed = AsyncRand()
	ObjModified(self)
end

---
--- Returns a list of available noise presets, sorted alphabetically, with an empty string as the first item.
---
--- @return table A table of noise preset IDs.
function NoisePresetsCombo()
	local items = table.values(NoisePresets)
	items = table.map(items, "id")
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

DefineClass.WangPerlinNoise = {
	__parents = {"PerlinNoise"},

	properties = {
		{id = "unique_edges", editor = "number", default = 2,},
		{id = "tiles", editor = "point", default = point(4,4), read_only = true,},
		{id = "cells_per_tile", editor = "point", default = point(4,4), },
	}
}

---
--- Returns the size of the tiles used for the Wang noise.
---
--- @return point The size of the tiles.
function WangPerlinNoise:Gettiles()
	local size = self.unique_edges ^ 2
	return point(size, size)
end

---
--- Generates a Wang noise grid using the specified parameters.
---
--- @param rand_seed number The random seed to use for the noise generation.
--- @param g table The grid to store the generated noise values.
--- @return table The modified grid with the generated noise values.
function WangPerlinNoise:GetNoiseRaw(rand_seed, g, ...)
	rand_seed = self.Seed + (rand_seed or 0)
	local n = GetPreciseTicks()
	GridWang(rand_seed, {octaves = self:ExportOctaves(), tiles = self:Gettiles(), cells_per_tile = self.cells_per_tile}, g)
	--print("WangNoise Took", GetPreciseTicks() - n)
	return g, ...
end
