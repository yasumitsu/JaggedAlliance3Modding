---
--- Tests a particle effect by setting its path.
---
--- @param editor table The particle editor object.
--- @param obj table The particle object to test.
--- @param prop table The particle property to test.
function TestParticle(editor, obj, prop)
	obj:SetPath(obj.par_name)
end

---
--- Returns a list of all particle systems.
---
--- @return table A table of particle system objects, keyed by their ID.
function GetParticleSystemList()
	local list = {}
	for key, item in GetParticleSystemIterator() do
		local item_name = item:GetId()
		table.insert(list, item)
		assert(not list[item_name])
		list[item_name] = item
	end
	return list
end

---
--- Returns a list of all particle system names.
---
--- @param ui boolean (optional) If true, only return particle systems that are marked as UI-related.
--- @return table A table of particle system names.
function GetParticleSystemNameList(ui)
	ui = ui or false
	local list = {}
	for key, item in GetParticleSystemIterator() do
		local item_name = item:GetId()
		if item.ui == ui then
			table.insert(list, item_name)
		end
	end
	return list
end

---
--- Returns an iterator over all particle system presets.
---
--- @return function An iterator function that returns (key, value) pairs for each particle system preset.
function GetParticleSystemIterator()
	return pairs(ParticleSystemPresets)
end

---
--- Returns a particle system preset by its name.
---
--- @param name string The name of the particle system preset to retrieve.
--- @return ParticleSystemPreset|nil The particle system preset, or nil if not found.
function GetParticleSystem(name)
	local preset = ParticleSystemPresets[name]
	if preset then
		return preset
	end
end

---
--- Returns a list of all particle system preset file paths on disk.
---
--- @return table A table of particle system preset file paths.
function GetParticleSystemNameListFromDisk()
	local list = {}
	for _, folder in ipairs(ParticleDirectories()) do
		for idx, preset in ipairs(io.listfiles(folder, "*.bin")) do
			table.insert(list, preset)
		end
	end
	return list
end

---
--- Returns a list of directories containing particle system presets.
---
--- The list includes the default "Data/ParticleSystemPreset" directory, as well as any DLC-specific particle system preset directories.
---
--- @return table A table of particle system preset directory paths.
function ParticleDirectories()
	local dirs = { "Data/ParticleSystemPreset" }
	for _, folder in ipairs(DlcFolders or empty_table) do
		local dir = folder .. "/Presets/ParticleSystemPreset"
		if io.exists(dir) then
			table.insert(dirs, dir)
		end
	end
	return dirs
end

-- Convenience function to be called from C
---
--- Returns a table containing the particle system preset with the given name.
---
--- @param name string The name of the particle system preset to retrieve.
--- @return table A table containing the particle system preset, or nil if not found.
function GetParticleSystemForReloading(name)
	return { GetParticleSystem(name) }
end

--- Opens the editor for the particle system with the given name.
---
--- @param name string The name of the particle system preset to open the editor for.
function EditParticleSystem(name)
	local sys = GetParticleSystem(name)
	if IsKindOf(sys, "ParticleSystemPreset") then
		sys:OpenEditor()
	end
end

DefineClass.ParSystemBase =
{
	__parents = { "CObject" },
 	flags = { cfParticles = true, cfConstructible = false, efSelectable = false, efWalkable = false, efCollision = false, efApplyToGrids = false, efShadow = false, cofComponentParticles = true },
	entity = "",
	dynamic_params = false,

	polyline = false,

	properties = {
		{ id = "ParticlesName", name = "Particles", editor = "preset_id", default = "", preset_class = "ParticleSystemPreset", autoattach_prop = true, buttons = {{name = "Apply", func = "ParSystemNameApply"}}},
	}
}

--- Returns the particle system preset name associated with this ParSystemBase object.
---
--- @return string The name of the particle system preset, or an empty string if the object is invalid.
function ParSystemBase:GetId()
	return IsValid(self) and self:GetParticlesName() or ""
end

for name, method in pairs(ComponentParticles) do
	ParSystemBase[name] = method
end

DefineClass.ParSystem =
{
	__parents = { "InvisibleObject", "ComponentAttach", "ParSystemBase", "EditorCallbackObject" },
	HelperEntity = "ParticlePlaceholder",
	HelperScale = 10,
	HelperCursor = true,
}

--- Returns the name of the particle system preset associated with this ParSystem object.
---
--- @return string The name of the particle system preset.
function ParSystem:EditorGetText()
	return self:GetParticlesName()
end

local function RecreateParticle(par)
	par:DestroyRenderObj()
end

local function ParSystemPlayFX(par, no_delay)
	if no_delay then
		RecreateParticle(par)
	else
		if EditorSettings:GetTestParticlesOnChange() then
			DelayedCall(500, RecreateParticle, par)
		end
	end
end

ParSystem.EditorCallbackMove = ParSystemPlayFX
ParSystem.EditorCallbackRotate = ParSystemPlayFX
ParSystem.EditorCallbackMoveScale = ParSystemPlayFX

function OnMsg.EditorSelectionChanged(objects)
	for _, obj in ipairs(objects or empty_tample) do
		if IsKindOf(obj, "ParSystem") then
			ParSystemPlayFX(obj)
			return
		end
	end
end

--- Recreates the particle effect for the currently selected ParSystem objects in the editor.
---
--- @param no_delay boolean If true, the particle effect will be recreated immediately without a delay.
function RecreateSelectedParticle(no_delay)
	local selection = editor.GetSel()
	for _, sel_obj in ipairs(selection) do
		if IsKindOf(sel_obj, "ParSystem") then
			ParSystemPlayFX(sel_obj, no_delay)
			return
		end
	end	
end

DefineClass.ParSystemUI =
{
	__parents = { "ParSystemBase" },
	flags = { gofUILObject = true },
}

---
--- Applies the ParSystem name and dynamic parameters to the given object.
---
--- If the object has the `gofRealTimeAnim` game flag set, the creation time is set to the current real time.
--- Otherwise, the creation time is set to the current game time.
---
--- The object's render object is then destroyed, and the dynamic parameters are applied to the object.
---
--- @param editor table The editor object.
--- @param obj ParSystem The ParSystem object to apply the name and dynamic parameters to.
---
function ParSystemNameApply(editor, obj)
	if obj:GetGameFlags(const.gofRealTimeAnim) == const.gofRealTimeAnim then
		obj:SetCreatonTime(RealTime())
	else
		obj:SetCreatonTime(GameTime())
	end
	obj:DestroyRenderObj()
	obj:ApplyDynamicParams()
end

---
--- Determines whether the ParSystem should use game time or real time for its particle effects.
---
--- @param self ParSystem The ParSystem object to check.
--- @return boolean True if the ParSystem should use game time, false otherwise.
---
function ParSystem:ShouldBeGameTime()
	local name = self:GetParticlesName()
	if not name then return false end
	if name == "" then return false end
	local flags = ParticlesGetBehaviorFlags(name, -1)
	if not flags then return false end
	return flags.gametime and true
end

---
--- Called after the ParSystem object is loaded.
--- Applies any dynamic parameters defined for the ParSystem's particle effect.
---
function ParSystem:PostLoad()
	self:ApplyDynamicParams()
end

-- function OnMsg.GatherFXActors(list)
-- 	local t = GetParticleSystemNames()
-- 	local cnt = #list
-- 	for i = 1, #t do
-- 		list[cnt + i] = "Particles: " .. t[i]
-- 	end
-- end

if FirstLoad then
	g_DynamicParamsDefs = {}
end
function OnMsg.DoneMap()
	g_DynamicParamsDefs = {}
end
---
--- Retrieves the dynamic parameters defined for a particle effect.
---
--- @param name string The name of the particle effect.
--- @return table The dynamic parameters defined for the particle effect.
---
function ParGetDynamicParams(name)
	local defs = g_DynamicParamsDefs
	local def = defs[name]
	if not def then
		def = ParticlesGetDynamicParams(name) or empty_table
		defs[name] = def
	end
	return def
end

if config.ParticleDynamicParams then

---
--- Applies any dynamic parameters defined for the ParSystem's particle effect.
---
--- This function retrieves the dynamic parameters defined for the particle effect
--- associated with the ParSystem, and sets the values of those parameters on the
--- ParSystem object. If no dynamic parameters are defined, the `dynamic_params`
--- field of the ParSystem is set to `nil`.
---
--- @param self ParSystem The ParSystem object to apply the dynamic parameters to.
---
function ParSystem:ApplyDynamicParams()
	local proto = self:GetParticlesName()
	local dynamic_params = ParGetDynamicParams(proto)
	if not next(dynamic_params) then
		self.dynamic_params = nil
		return
	end
	self.dynamic_params = dynamic_params
	local set_value = self.SetParamDef
	for k, v in pairs(dynamic_params) do
		set_value(self, v, v.default_value)
	end
end 

---
--- Sets a dynamic parameter on the ParSystem object.
---
--- This function retrieves the dynamic parameter definition for the specified
--- parameter name, and sets the value of that parameter on the ParSystem object.
--- If no dynamic parameter definition is found, this function does nothing.
---
--- @param self ParSystem The ParSystem object to set the parameter on.
--- @param param string The name of the dynamic parameter to set.
--- @param value any The value to set for the dynamic parameter.
---
function ParSystem:SetParam(param, value)
	local dynamic_params = self.dynamic_params
	local def = dynamic_params and rawget(dynamic_params, param)
	if def then
		self:SetParamDef(def, value)
	end
end

---
--- Sets a dynamic parameter on the ParSystem object.
---
--- This function sets the value of a dynamic parameter on the ParSystem object.
--- The parameter type is determined by the `type` field of the parameter definition,
--- and the value is set accordingly.
---
--- @param self ParSystem The ParSystem object to set the parameter on.
--- @param def table The dynamic parameter definition.
--- @param value any The value to set for the dynamic parameter.
---
function ParSystem:SetParamDef(def, value)
	local ptype = def.type
	if ptype == "number" or ptype == "color" then
		self:SetDynamicData(def.index, value)
	elseif ptype == "point" then
		local x, y, z = value:xyz()
		local idx = def.index
		self:SetDynamicData(idx, x)
		self:SetDynamicData(idx + 1, y)
		self:SetDynamicData(idx + 2, z or 0)
	elseif ptype == "bool" then
		self:SetDynamicData(def.index, value and 1 or 0)
	end
end

---
--- Gets the value of a dynamic parameter on the ParSystem object.
---
--- This function retrieves the dynamic parameter definition for the specified
--- parameter name, and gets the value of that parameter from the ParSystem object.
--- If no dynamic parameter definition is found, this function returns `nil`.
---
--- @param self ParSystem The ParSystem object to get the parameter from.
--- @param param string The name of the dynamic parameter to get.
--- @return any The value of the dynamic parameter, or `nil` if not found.
---
function ParSystem:GetParam(param, value)
	local dynamic_params = self.dynamic_params
	local p = dynamic_params and rawget(dynamic_params, param)
	if p then
		local ptype = p.type
		if ptype == "number" or ptype == "color" then
			return self:GetDynamicData(p.index)
		elseif ptype == "point" then
			local idx = p.index
			return point(
				self:GetDynamicData(idx),
				self:GetDynamicData(idx + 1),
				self:GetDynamicData(idx + 2))
		elseif ptype == "bool" then
			return self:GetDynamicData(p.index) ~= 0
		end
	end
end

else -- config.ParticleDynamicParams

ParSystem.ApplyDynamicParams = empty_func
ParSystem.SetParam = empty_func
ParSystem.GetParam = empty_func
ParSystem.SetParamDef = empty_func

end -- config.ParticleDynamicParams

---
--- Sets the polyline data for the ParSystem object.
---
--- This function sets the polyline data for the ParSystem object. The polyline
--- data is stored as a series of 2D points, with the first point repeated at
--- the end to form a closed loop. This function takes the polyline data and
--- stores it in the ParSystem object's dynamic parameters.
---
--- @param self ParSystem The ParSystem object to set the polyline data for.
--- @param polyline table A table of 2D points representing the polyline.
--- @param parent any An optional parent object for the polyline.
---
function ParSystem:SetPolyline(polyline, parent)
	local count = #polyline
	assert(count <= 4)
	if count <= 4 then
		-- the last point is copied from the first in C-side so we skip it here
		for i = 1, count - 1 do
			local v1, v2 = polyline[i]:xy()
			self:SetDynamicData(i, v1)
			self:SetDynamicData(i+1, v2)
		end
		self:SetDynamicData(0, count)
	end
end

function OnMsg.LoadGame()
	local empty = pstr("")
	MapForEach(true, "ParSystem", function(o) 
		if o["polyline"] then
			o.polyline = o.polyline or empty
			o.polyline:SetPolyline(0)
		end
	end )
end

---
--- Places a particle system object with the given name and class.
---
--- This function creates a new particle system object with the specified name and class. If the name is missing or the class is not found, it will assert an error. The function will apply any dynamic parameters to the particle system object before returning it.
---
--- @param name string The name of the particle system to place.
--- @param class string The class of the particle system to place. Defaults to "ParSystem" if not provided.
--- @param components table Optional table of components to add to the particle system object.
--- @return ParSystem The created particle system object.
---
function PlaceParticles(name, class, components)
	if type(name) ~= "string" or name == "" then 
		assert(false , "Particle name is missing")
		return
	end
	local o = PlaceObject(class or "ParSystem", nil, components)
	if not o then
		assert(false, "Particle class missing: " .. (class or "ParSystem"))
		return
	end
	if not o:SetParticlesName(name) then
		assert(false, "No such particle name: " .. name)
		DoneObject(o)
		return
	end
	o:ApplyDynamicParams()
	return o
end

local function WaitClearParticle(obj, max_timeout)
	local kill_time = now() + (max_timeout or 10000)
	while IsValid(obj) and obj:HasParticles() and now() - kill_time < 0 do
		Sleep(1000)
	end
	DoneObject(obj)
end

-- gracefully stop a particle system
---
--- Stops a particle system object and optionally waits for it to clear.
---
--- This function stops the particle emitters of the given particle system object. If the `wait` parameter is true, it will wait for the particle system to fully clear before returning. Otherwise, it will start a separate thread to wait for the particle system to clear.
---
--- @param obj ParSystem The particle system object to stop.
--- @param wait boolean If true, the function will wait for the particle system to clear before returning. If false, it will start a separate thread to wait for the particle system to clear.
--- @param max_timeout number The maximum time in milliseconds to wait for the particle system to clear.
---
function StopParticles(obj, wait, max_timeout)
	if not IsValid(obj) then
		return
	end
	if obj:IsParticleSystemVanishing() or not obj:HasParticles() then
		DoneObject(obj)
		return
	end
	obj:StopEmitters()
	if wait then
		WaitClearParticle(obj, max_timeout)
	else
		if obj:GetGameFlags(const.gofRealTimeAnim) == const.gofRealTimeAnim then
			CreateMapRealTimeThread(WaitClearParticle, obj, max_timeout)
		else
			CreateGameTimeThread(WaitClearParticle, obj, max_timeout)
		end
	end
end

---
--- Stops multiple particle systems and waits for them to clear.
---
--- This function stops the particle emitters of the given list of particle system objects. It then waits for all the particle systems to fully clear before returning.
---
--- @param objs table A table of particle system objects to stop.
--- @param max_timeout number The maximum time in milliseconds to wait for the particle systems to clear.
---
function StopMultipleParticles(objs, max_timeout)
	if type(objs) ~= "table" or #objs == 0 then
		return
	end
	-- This can be used only from a RTT, because HasParticles touches the renderer
	CreateMapRealTimeThread(function(objs, max_timeout)
		local kill_time = now() + (max_timeout or 10000)
		for i=1,#objs do
			local obj = objs[i]
			if IsValid(obj) then
				if obj:IsParticleSystemVanishing() or not obj:HasParticles() then
					DoneObject(obj)
				else
					obj:StopEmitters()
				end
			end
		end
		while true do
			local has_time = now() - kill_time < 0
			local loop
			for i=1,#objs do
				local obj = objs[i]
				if IsValid(obj) then
					if has_time and obj:HasParticles() then
						loop = true
						break
					else
						DoneObject(obj)
					end
				end
			end
			if not loop then
				break
			end
			Sleep(1000)
		end
	end, objs, max_timeout)
end

---
--- Places a particle system at the given position, angle and axis, and stops it after 2 seconds.
---
--- @param particles string The name of the particle system to place.
--- @param pos table The position to place the particle system at.
--- @param angle table The angle to orient the particle system at.
--- @param axis table The axis to orient the particle system along.
--- @return ParSystem The placed particle system object.
---
function PlaceParticlesOnce( particles, pos, angle, axis )
	local o = PlaceParticles( particles )
	if axis then
		o:SetAxis( axis )
	end
	if angle then
		o:SetAngle( angle )
	end
	if pos then
		o:SetPos( pos )
	end
	CreateMapRealTimeThread(function(o)
		Sleep(2000) -- wait all emitters to stop emitting
		StopParticles(o, true)
	end, o)
	return o
end

---
--- Finds the first attached ParSystem object with the given name.
---
--- @param obj table The object to search for attached ParSystem objects.
--- @param name string The name of the ParSystem to find.
--- @return ParSystem|nil The first attached ParSystem object with the given name, or nil if not found.
---
function GetAttachParticle(obj, name)
	for i = 1, obj:GetNumAttaches() do
		local o = obj:GetAttach(i)
		if o:IsKindOf("ParSystem") and o:GetProperty("ParticlesName") == name then
			return o
		end
	end
end

---
--- Finds all attached ParSystem objects with the given name.
---
--- @param obj table The object to search for attached ParSystem objects.
--- @param name string The name of the ParSystem to find.
--- @return table A list of all attached ParSystem objects with the given name.
---
function GetParticleAttaches(obj, name)
	local attaches = obj:GetNumAttaches()
	local list = {}
	for i = 1, attaches do
		local o = obj:GetAttach(i)
		if IsKindOf(o, "ParSystem") and o:GetProperty("ParticlesName") == name then
			table.insert(list, o)
		end
	end
	
	return list
end
