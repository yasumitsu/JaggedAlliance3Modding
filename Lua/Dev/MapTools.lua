---
--- Resizes the map data to a new width and height.
---
--- @param mapdata table The map data to resize.
--- @param new_width number The new width of the map.
--- @param new_height number The new height of the map.
---
function MapDataResize(mapdata, new_width, new_height) -- Call in RealTimeThread
	local old_width, old_height = mapdata.Width, mapdata.Height
	if old_width ~= new_width or old_height ~= new_height then
		OpenMapLoadingScreen("")
		WaitRenderMode("ui")
		print("Resizing map...")
		if CurrentMap ~= mapdata.id then
			ChangeMap(mapdata.id)
		end
		
		mapdata.Width = new_width
		mapdata.Height = new_height
		
		local folder = GetMap()
		local function ResizeMapGridFile(filename, original, is_heightmap)
			local path = folder .. filename
			local old_grid = GridDest(original, 0, 0)
			GridLoadRaw(path, old_grid)
			
			local w, h = new_width, new_height
			if not is_heightmap then
				w,h = (w - 1), (h - 1)
			end
			local new_grid = GridDest(old_grid, w, h, true)
			
			GridExtend(old_grid, new_grid, true)
			GridSaveRaw(path, new_grid)
		end
		
		ResizeMapGridFile("biome.grid", terrain.GetBiomeGrid())
		ResizeMapGridFile("grass.grid", terrain.GetGrassGrid(0))
		ResizeMapGridFile("height.grid", terrain.GetHeightGrid(), true)
		--ResizeMapGridFile("impassable.grid", terrain.GetForcedImpassGrid())
		--ResizeMapGridFile("passable.grid", terrain.GetForcedPassGrid())
		ResizeMapGridFile("type.grid", terrain.GetTypeGrid())
		
		local new_size = point(new_width, new_height, 0)
		local old_size = point(old_width, old_height, 0)
		local offset = MulDivRound(new_size - old_size, const.SlabSizeX, 4)
		--local offset = (offset/const.SlabSizeX)*const.SlabSizeX
		MapForEach("map", "CObject", function(obj)
			if not obj:IsValidPos() then return end
			local old_pos = obj:GetVisualPos()
			local new_pos = old_pos + offset
			obj:SetPos(new_pos)
		end)
		
		SaveObjects(folder .. "objects.lua")
		mapdata:SaveMapData(folder)

		hr.TR_ForceReloadNoTextures = 1
		WaitRenderMode("scene")
		CloseMapLoadingScreen("")
		ChangeMap(mapdata.id)
		print("Map resized!")
	end
end

---
--- Saves the positions and angles of all terrain decals in the current map to a file.
---
--- The decal positions and angles are saved to a file named `<map_name>.decals.lua` in the `AppData` directory.
---
--- This function is typically called when the map is saved, to preserve the positions of decals that have been manually placed.
---
--- @function SaveDecalsPositions
--- @return nil
function SaveDecalsPositions()
	local decals = {}
	MapForEach("map", "TerrainDecal", function(o)
		decals[#decals+1] = { o.class, o:GetPos(), o:GetAngle() }
	end)
	AsyncStringToFile("AppData/" .. GetMapName() .. ".decals.lua", TableToLuaCode(decals))
end

---
--- Restores the positions and angles of all terrain decals in the current map from a file.
---
--- The decal positions and angles are loaded from a file named `<map_name>.decals.lua` in the `AppData` directory.
---
--- This function is typically called when the map is loaded, to restore the positions of decals that have been manually placed.
---
--- @function RestoreDecalsPositions
--- @return nil
function RestoreDecalsPositions()
	local err, decals = FileToLuaValue("AppData/" .. GetMapName() .. ".decals.lua")
	local by_x = {}
	for k,v in ipairs(decals) do
		local x, y, z = v[2]:xyz()
		by_x[x] = by_x[x] or {}
		by_x[x][#by_x[x]+1] = v
	end
	MapForEach("map", "TerrainDecal", function(o)
		local x, y, z = o:GetPosXYZ()
		for _, decal in ipairs(by_x[x] or empty_table) do
			if decal[1] == o.class and decal[2] == o:GetPos() then
				if decal[3] ~= o:GetAngle() then
					print("Fixing ", o.class, "at", o:GetPos(), o:GetAngle(), decal[3])
					o:SetAngle(decal[3])
				end
			end
		end
	end)
end

---
--- Creates a checkpoint timer with the given name.
---
--- The timer can be used to measure elapsed time between checkpoints.
---
--- @param name string The name of the checkpoint timer.
--- @return table The checkpoint timer object.
function CreateCheckpointTimer(name)
	return {
		name = name,
		current_time = GetPreciseTicks(),
		Checkpoint = function(self, name)
			local time = GetPreciseTicks()
			print(self.name, name, time - self.current_time)
			self.current_time = time
		end
	}
end
--[[
function OnMsg.Autorun()
	if FirstLoad then 
		PerfInstrument("EngineChangeMap") 
		PerfInstrument("WaitLoadBinAssets")
	end
	PerfInstrument("RebuildSlabTunnels")
	PerfInstrument("ChangeMap")
	PerfInstrument("LoadObjects")
	PerfInstrument("LoadMap")
	PerfInstrument("ResumePassEdits", 100, 100)
	PerfInstrument("ComputeSlabVisibility")
end

]]

-- Blackbox optimization based on the rather pompously called "differential evolution"
-- https://en.wikipedia.org/wiki/Differential_evolution
-- given points in a possibility space ("agents") which can be evaluated and recombined via a certain procedure
-- try to find a point which maximizes the evaluation function ("fitness")

DefineClass.DiffEvoAgent = {
	__parents = { "InitDone" },
	data = false, -- an array of values which represent the agent
	fitness = false,
	Evaluate = function() end, -- set fitness member to integer, higher is better
	RecombineValue = function(i, a, b, c, F) end, -- compute a new value of the i-th parameter based on the i-th paramethers of three other agents
}

---
--- Initializes the data member of the DiffEvoAgent class.
---
--- The data member is an array that represents the agent. This function
--- ensures that the data member is initialized to an empty array if it
--- does not already exist.
---
function DiffEvoAgent:Init()
	self.data = self.data or {}
end

---
--- Recombines the data of the current DiffEvoAgent with the data of three other agents to create a new agent.
---
--- This function is used as part of the differential evolution optimization algorithm. It takes the data of three other agents (a, b, c) and combines them with the current agent's data to create a new agent. The recombination is controlled by the crossover rate (CR) and the scaling factor (F).
---
--- @param a DiffEvoAgent The first agent to recombine with.
--- @param b DiffEvoAgent The second agent to recombine with.
--- @param c DiffEvoAgent The third agent to recombine with.
--- @param rand function A random number generator function.
--- @param CR number The crossover rate, a value between 0 and 1.
--- @param F number The scaling factor, a value greater than 0.
--- @return DiffEvoAgent A new agent created by recombining the data of the current agent and the three other agents.
function DiffEvoAgent:Recombine(a, b, c, rand, CR, F)
	local changed = {}
	for i=1,#self.data do
		changed[i] = self:RecombineValue(i, a.data[i], b.data[i], c.data[i], F)
	end
	local recombined_data = {}
	local R = 1 + rand(#self.data)
	for i=1,#self.data do
		if i == R or rand(1000) < CR then
			recombined_data[i] = changed[i]
		else
			recombined_data[i] = self.data[i]
		end
	end
	return g_Classes[self.class]:new{ data = recombined_data }
end

---
--- Computes a new value for the i-th parameter of the agent by recombining the i-th parameters of three other agents.
---
--- This function is used as part of the differential evolution optimization algorithm to create a new agent by recombining the data of the current agent with the data of three other agents. The new value is computed as `a + (b - c) * F`, where `a`, `b`, and `c` are the i-th parameters of the three other agents, and `F` is the scaling factor.
---
--- @param idx integer The index of the parameter to recombine.
--- @param a number The i-th parameter of the first agent to recombine with.
--- @param b number The i-th parameter of the second agent to recombine with.
--- @param c number The i-th parameter of the third agent to recombine with.
--- @param F number The scaling factor, a value greater than 0.
--- @return number The new value for the i-th parameter of the agent.
function DiffEvoAgent:RecombineValue(idx, a, b, c, F)
	return a + MulDivRound(b - c, F, 1000)
end

---
--- Optimizes a population of DiffEvoAgent objects using the differential evolution algorithm.
---
--- This function takes a population of DiffEvoAgent objects, a timeout value, a random seed, a crossover rate, and a scaling factor. It then iterates through the population, evaluating each agent and keeping track of the best fitness and average fitness. It then recombines each agent with three randomly selected other agents, evaluating the new agent and replacing the original agent if the new agent has a higher fitness. The optimization continues until the timeout is reached or the average fitness is sufficiently close to the best fitness.
---
--- @param pop table A table of DiffEvoAgent objects to optimize.
--- @param timeout number The maximum time (in ticks) to run the optimization.
--- @param seed number A random seed to use for the optimization.
--- @param CR number The crossover rate, a value between 0 and 1.
--- @param F number The scaling factor, a value greater than 0.
--- @return DiffEvoAgent The best agent found during the optimization.
function DiffEvoOptimize(pop, timeout, seed, CR, F)
	local rand = BraidRandomCreate(seed or 0)
	local start_time = GetPreciseTicks()
	local best_fitness, avg_fitness = 0, 0
	for i=1,#pop do
		if not pop[i].fitness then
			pop[i]:Evaluate()
		end
		if pop[i].fitness > best_fitness then
			best_fitness = pop[i].fitness
		end
		avg_fitness = avg_fitness + pop[i].fitness
	end
	print("initial", best_fitness)
	local iteration = 0
	while GetPreciseTicks() < start_time + timeout and avg_fitness <= MulDivRound(97*#pop, best_fitness, 100) do
		for i=1,#pop do
			local a, b, c = i, i, i
			while a == i do a = 1 + rand(#pop) end
			while b == i or b == a do b = 1 + rand(#pop) end
			while c == i or c == a or c == b do c = 1 + rand(#pop) end
			local new_agent = pop[i]:Recombine(pop[a], pop[b], pop[c], rand, CR, F)
			new_agent:Evaluate()
			if new_agent.fitness > pop[i].fitness then
				avg_fitness = avg_fitness - pop[i].fitness
				pop[i] = new_agent
				avg_fitness = avg_fitness + pop[i].fitness
				if new_agent.fitness > best_fitness then
					best_fitness = new_agent.fitness
					print("improvement", best_fitness)
				end
			end
			iteration = iteration + 1
			if GetPreciseTicks() > start_time + timeout or avg_fitness > MulDivRound(97*#pop, best_fitness, 100) then
				break
			end
		end
	end

	local best_i, best_fitness = 0, 0
	for i=1,#pop do
		if pop[i].fitness > best_fitness then
			best_i, best_fitness = i, pop[i].fitness
		end
	end
	pop[best_i]:View()
	return pop[best_i]
end

-- class representing possible gameplay (not action) cameras for Zulu

DefineClass.DiffEvoTacCamera = {
	__parents = { "DiffEvoAgent" },
}

---
--- Generates a population of `DiffEvoTacCamera` agents for a differential evolution optimization.
---
--- @param n number The number of agents to generate in the population.
--- @param seed number|nil The random seed to use for generating the population. If not provided, a random seed will be used.
--- @return table A table of `DiffEvoTacCamera` agents representing the generated population.
function DiffEvoTacCamera.GeneratePopulation(n, seed)
	seed = seed or 0
	local rand = BraidRandomCreate(seed)
	
	local sizex, sizey = terrain.GetMapSize()
	local pass_slabs = {}
	ForEachPassSlab("map", function(x, y, z)
		pass_slabs[#pass_slabs+1] = point(x, y)
	end )
	table.shuffle(pass_slabs, rand())
	local pop = {}
	if next(pass_slabs) then
		for i=1,n do
			pop[#pop+1] = DiffEvoTacCamera:new{ data = { pass_slabs[i]:x(), pass_slabs[i]:y(), rand(360*60) } }
		end
		for i=#pop+1,n do
			pop[#pop+1] = DiffEvoTacCamera:new{ data = { rand(sizex), rand(sizey), rand(360*60) } }
		end
	end
	return pop
end

---
--- Gets the camera position, look-at point, and floor height for a `DiffEvoTacCamera` agent.
---
--- @param self DiffEvoTacCamera The `DiffEvoTacCamera` agent.
--- @return point The camera position.
--- @return point The look-at point.
--- @return number The floor height.
function DiffEvoTacCamera:GetCameraPosLookatFloor()
	local x, y, angle = table.unpack(self.data)
	local lookat = point(x, y, terrain.GetHeight(x, y) + const.SlabSizeZ*16)
	local pos = lookat + Rotate(point(13*guim, 0, 0), angle) + point(0, 0, 11*guim)
	return pos, lookat, 5
end

---
--- Sets the camera position, look-at point, and floor height for the `DiffEvoTacCamera` agent.
---
--- @param self DiffEvoTacCamera The `DiffEvoTacCamera` agent.
function DiffEvoTacCamera:View()
	local pos, lookat, floor = self:GetCameraPosLookatFloor()
	cameraTac.SetCamera(pos, lookat, 0)
	cameraTac.Normalize()
	cameraTac.SetFloor(floor)
end

--- Evaluates the fitness of a `DiffEvoTacCamera` agent.
---
--- This function sets the camera to the agent's view, gets the camera's position and look-at point, updates the agent's data with the look-at point's x and y coordinates, and measures the rendering performance for the current frame.
---
--- The fitness of the agent is set to the number of vertices rendered in the current frame.
---
--- @param self DiffEvoTacCamera The `DiffEvoTacCamera` agent to evaluate.
function DiffEvoTacCamera:Evaluate()
	self:View()
	local p, l = cameraTac.GetPosLookAt()
	self.data[1], self.data[2] = l:xy()
	--self.data[4] = cameraTac.GetFloor()*1000 + 499
	
	local t = GetPreciseTicks()
	WaitNextFrame(5)
	local drawcalls, polygons, verts = GetRenderPerformanceStats()
	self.fitness = verts -- GetPreciseTicks() - t
end

---
--- Recombines the value at the given index for the `DiffEvoTacCamera` agent.
---
--- If the index is 3, the value is calculated as the sum of the first value (a) and the scaled angle difference between the second (b) and third (c) values, modulo 360 degrees. Otherwise, the value is calculated using the base `DiffEvoAgent.RecombineValue` function.
---
--- @param self DiffEvoTacCamera The `DiffEvoTacCamera` agent.
--- @param idx number The index of the value to recombine.
--- @param a number The first value.
--- @param b number The second value.
--- @param c number The third value.
--- @param F number The scaling factor.
--- @return number The recombined value.
function DiffEvoTacCamera:RecombineValue(idx, a, b, c, F)
	if idx == 3 then
		return (a + MulDivRound(AngleDiff(b, c), F, 1000)) % (360*60)
	else
		return DiffEvoAgent.RecombineValue(self, idx, a, b, c, F)
	end
end

---
--- Finds the slowest camera position for the current map and returns information about it.
---
--- This function sets the game state to pause, changes some rendering settings to optimize for performance, and then generates a population of `DiffEvoTacCamera` agents to find the camera position that renders the most vertices in a single frame.
---
--- The function returns a table with the following fields:
---
--- - `map`: the name of the current map
--- - `frame_time`: the time it takes to render a single frame with the best camera position (in milliseconds)
--- - `fps`: the estimated frames per second with the best camera position
--- - `str`: a Lua code snippet that can be used to load the best camera position
--- - `data`: the data for the best `DiffEvoTacCamera` agent
--- - `fitness`: the fitness (number of vertices rendered) of the best `DiffEvoTacCamera` agent
--- - `lightmodel`: the ID of the current light model
---
--- @param timeout number The maximum time to spend searching for the best camera position (in milliseconds)
--- @param rand function An optional random number generator function
--- @return table The information about the slowest camera position
function CurrentMapSlowestCamera(timeout, rand)
	CMT_SetPause(true, "CurrentMapSlowestCamera")
	table.change(hr, "CurrentMapSlowestCamera", { ShadowSDSMEnable = 0, StreamingForceFallbacks = 1, Shadowmap = 1 })
	WaitNextFrame(10)
	local pop = DiffEvoTacCamera.GeneratePopulation(20, rand and rand() or AsyncRand())
	if not next(pop) then
		return { map = GetMapName(), err = "no valid camera positions found", fitness = 0 }
	end
	local best = DiffEvoOptimize(pop, timeout, rand and rand() or AsyncRand(), 700, 700)
	local t = GetPreciseTicks()
	WaitNextFrame(100)
	local frame_time = (GetPreciseTicks() - t)/100
	local str = string.format("DbgLoadLocation(\"%s\", %s, false)", GetMapName(), TableToLuaCode({GetCamera()}, ' '))
	CMT_SetPause(false, "CurrentMapSlowestCamera")
	table.restore(hr, "CurrentMapSlowestCamera")
	return {
		map = GetMapName(),
		frame_time = frame_time,
		fps = 1000/Max(frame_time, 1),
		str = str,
		data = best.data,
		fitness = best.fitness,
		lightmodel = CurrentLightmodel and CurrentLightmodel[1].id,
	}
end

---
--- Performs a brute force search to find the slowest camera position for the current map.
---
--- This function sets the game state to pause, changes some rendering settings to optimize for performance, and then generates a population of `DiffEvoTacCamera` agents to find the camera position that renders the most vertices in a single frame.
---
--- The function returns a table with the following fields:
---
--- - `map`: the name of the current map
--- - `frame_time`: the time it takes to render a single frame with the best camera position (in milliseconds)
--- - `fps`: the estimated frames per second with the best camera position
--- - `str`: a Lua code snippet that can be used to load the best camera position
--- - `data`: the data for the best `DiffEvoTacCamera` agent
--- - `fitness`: the fitness (number of vertices rendered) of the best `DiffEvoTacCamera` agent
--- - `lightmodel`: the ID of the current light model
---
--- @param duration number The maximum time to spend searching for the best camera position (in milliseconds)
--- @return table The information about the slowest camera position
function BruteForceSlowestCamera(duration)
	CMT_SetPause(true, "CurrentMapSlowestCamera")
	table.change(hr, "CurrentMapSlowestCamera", { ShadowSDSMEnable = 0, StreamingForceFallbacks = 1, Shadowmap = 1 })
	WaitNextFrame(10)
	
	local pass_slabs = {}
	ForEachPassSlab("map", function(x, y, z) pass_slabs[#pass_slabs+1] = point(x, y) end)
	local clusters = KMeans2D(pass_slabs, Min(200, #pass_slabs/16), 100)
	
	local cameras = {}
	local angles = 12
	for i=1,#clusters do
		for i=1,angles do
			cameras[#cameras+1] = DiffEvoTacCamera:new{ data = { clusters[i]:x(), clusters[i]:y(), MulDivRound(i, 360*60, angles) } }
		end
	end
	
	local t = GetPreciseTicks()
	local best = { fitness = 0 }
	for i, p in ipairs(cameras) do
		p:Evaluate()
		if p.fitness > best.fitness then
			best = p
			print(p.fitness)
		end
		if GetPreciseTicks() - t > duration then
			print("iterations", i)
			break
		end
	end
	best:Evaluate()
	
	local t = GetPreciseTicks()
	WaitNextFrame(100)
	local frame_time = (GetPreciseTicks() - t)/100
	local str = string.format("DbgLoadLocation(\"%s\", %s, false)", GetMapName(), TableToLuaCode({GetCamera()}, ' '))
	CMT_SetPause(false, "CurrentMapSlowestCamera")
	table.restore(hr, "CurrentMapSlowestCamera")

	return {
		map = GetMapName(),
		frame_time = frame_time,
		fps = 1000/Max(frame_time, 1),
		str = str,
		data = best.data,
		fitness = best.fitness,
		lightmodel = CurrentLightmodel and CurrentLightmodel[1].id,
	}
end

---
--- Brute force searches for the slowest camera configuration for all maps in the game.
---
--- @param total_time number The total time in milliseconds to spend searching for the slowest camera.
--- @param seed number A random seed to use for the camera search.
--- @return table A table containing the results of the camera search for each map, sorted by fitness.
---
function AllMapsSlowestCameras(total_time, seed)
	total_time = total_time or 0
	local rand = BraidRandomCreate(seed or AsyncRand())
	IgnoreDebugErrors(true)
	ChangeMap("__Empty") -- to restart CMT thread after CMT_Time is changed
	
	local maps = {}
	for _, map in pairs(MapData) do
		if map.Status ~= "Not started" then
			maps[#maps+1] = map.id
		end
	end
	table.sort(maps)

	local results = {}
	for _, map in ipairs(maps) do
		ChangeMap(map)
		WaitLoadingScreenClose()
		WaitNextFrame(10)
		
		local ok, this_map = sprocall(BruteForceSlowestCamera, total_time/#maps, rand)
		if ok then
			table.insert(results, this_map)
			print(results[#results].str, results[#results].fitness/1000)
		else
			print("Failed on map", map)
		end
	end
	
	table.sortby_field(results, "fitness")
	results.lua_rev = LuaRevision
	results.assets_rev = AssetsRevision
	results.hardware = GetHardwareInfo(GetMainWindowDisplayIndex())
	results.resolution = UIL:GetScreenSize()
	AsyncStringToFile("svnAssets/Tests/BruteForceSlowCameras.lua", TableToLuaCode(results))
end

---
--- Runs a CPU tasks benchmark by loading a specific map location, configuring the rendering settings, and measuring the CPU frame time for different numbers of CPU task threads.
---
--- The benchmark loads the "G-8 - Colonial Mansion" map location, locks the camera, and then iterates through different numbers of CPU task threads, measuring the CPU frame time for each configuration. The rendering settings are modified to disable certain post-processing effects in order to isolate the CPU performance. The hardware information, including the CPU name and number of threads, is printed before and after the benchmark.
---
--- @param none
--- @return none
---
function CPUTasksBenchmark()
	CreateRealTimeThread( function()
		DbgLoadLocation("G-8 - Colonial Mansion", {point(168360, 174403, 26350),point(165120, 161748, 15350),"Tac",1000,{floor = 3},4200}, false)
		camera.Lock()
		local hardware_info = GetHardwareInfo(GetMainWindowDisplayIndex())
		print("------------", hardware_info.cpuName) 
		table.change(hr, "CPUTasksBenchmark", { PrimitiveCountModifier=-1, EnablePostprocess=0, EnableScreenSpaceReflections=0, EnableScreenSpaceAmbientObscurance=0 })
		WaitNextFrame()
		for i=1, hardware_info.cpuThreads do 
			config.CPUTaskThreads=i 
			Sleep(2000) 
			print(i, hr.RenderStatsFrameTimeCPU/100) 
		end 
		table.restore(hr, "CPUTasksBenchmark")
		print("------------")
		print("done.")
		camera.Unlock()
	end )
end

MapVar("LOSVoxelsMesh", false)

LOSVoxelConfig = {
	[0] = { guim*2, RGBA(0, 64, 255, 64) }, -- fully hidden from sight
	[1] = { guim/2, RGBA(64, 255, 64, 64) }, -- only a Standing or Crouched unit would be visible here
	[2] = false, -- fully visible, don't draw anything
}

---
--- Displays a wireframe visualization of the line-of-sight (LOS) voxels within a specified radius around a center object.
---
--- This function clears any existing debug vectors, deletes the existing LOSVoxelsMesh if it exists, and then generates a new mesh representing the LOS voxels within the specified radius. The voxels are colored based on their stance index, using the colors defined in the LOSVoxelConfig table.
---
--- @param center The center object around which to display the LOS voxels. If not provided, the SelectedObj is used.
--- @param radius The radius around the center object in which to display the LOS voxels. If not provided, the SelectedObj's sight radius is used.
--- @return none
---
function DbgShowLOSVoxelsWireframe(center, radius)
	DbgClearVectors()
	if LOSVoxelsMesh then
		LOSVoxelsMesh:delete()
	end
	center = center or SelectedObj
	radius = radius or SelectedObj:GetSightRadius()
	local t = GetLOSVoxelsInRadius(center, radius)
	local colors = { const.clrRed, const.clrBlue, const.clrGreen } 
	for _, voxel in ipairs(t) do
		local x, y, z, stance_idx = stance_pos_unpack(voxel)
		z = z or terrain.GetHeight(point(x,y))
		local vd = LOSVoxelConfig[stance_idx]
		if vd then
			DbgAddVoxel(point(x,y,z), vd[2])
		end
	end
end

local function AppendQuad(pstr, corner, x, y, color)
	pstr:AppendVertex(corner, color)
	pstr:AppendVertex(corner + x, color)
	pstr:AppendVertex(corner + x + y, color)
	pstr:AppendVertex(corner, color)
	pstr:AppendVertex(corner + x + y, color)
	pstr:AppendVertex(corner + y, color)
end

---
--- Displays a wireframe visualization of the line-of-sight (LOS) voxels within a specified radius around a center object.
---
--- This function clears any existing debug vectors, deletes the existing LOSVoxelsMesh if it exists, and then generates a new mesh representing the LOS voxels within the specified radius. The voxels are colored based on their stance index, using the colors defined in the LOSVoxelConfig table.
---
--- @param center The center object around which to display the LOS voxels. If not provided, the SelectedObj is used.
--- @param radius The radius around the center object in which to display the LOS voxels. If not provided, the SelectedObj's sight radius is used.
--- @return none
---
function DbgShowLOSVoxels(center, radius)
	DbgClearVectors()
	if LOSVoxelsMesh then
		LOSVoxelsMesh:delete()
	end
	center = center or SelectedObj
	radius = radius or SelectedObj:GetSightRadius()
	local t = GetLOSVoxelsInRadius(center, radius)
	local hs = const.SlabSizeX/2

	local mesh_str = pstr("", 24*20*#t)
	for _, voxel in ipairs(t) do
		local x, y, z, stance_idx = stance_pos_unpack(voxel)
		local vd = LOSVoxelConfig[stance_idx]
		if vd then
			z = z or terrain.GetHeight(point(x,y))
			local vert = vd[1]
			local color = vd[2]
			AppendQuad(mesh_str, point(x-hs, y-hs, z), point(2*hs, 0, 0), point(0, 2*hs, 0), color)
			AppendQuad(mesh_str, point(x-hs, y-hs, z + vert), point(2*hs, 0, 0), point(0, 2*hs, 0), color)
			AppendQuad(mesh_str, point(x-hs, y-hs, z), point(2*hs, 0, 0), point(0, 0, vert), color)
			AppendQuad(mesh_str, point(x-hs, y+hs, z), point(2*hs, 0, 0), point(0, 0, vert), color)
			AppendQuad(mesh_str, point(x-hs, y-hs, z), point(0, 2*hs, 0), point(0, 0, vert), color)
			AppendQuad(mesh_str, point(x+hs, y-hs, z), point(0, 2*hs, 0), point(0, 0, vert), color)
		end
	end
	LOSVoxelsMesh = Mesh:new()
	LOSVoxelsMesh:SetMesh(mesh_str)
	LOSVoxelsMesh:SetMeshFlags(const.mfWorldSpace)
	LOSVoxelsMesh:SetDepthTest(true)
	LOSVoxelsMesh:SetPos(center:GetVisualPos())
end

---
--- Checks if the given object has a 'Tree' vertex noise material.
---
--- @param obj The object to check.
--- @return boolean true if the object has a 'Tree' vertex noise material, false otherwise.
---
function DbgIsTreeWind(obj)
	local entity = obj:GetEntity()
	if not entity or entity == "" then return end
	local mat = GetStateMaterial(entity, obj:GetStateText())
	if not mat then return end
	local num_sub_mtls = GetNumSubMaterials(mat)
	for i=1, num_sub_mtls do
		local sub_mat = GetMaterialProperties(mat, i-1)
		if sub_mat.VertexNoise == "Tree" then return true end
	end
end

---
--- Forces the minimum LOD on objects outside of the border area.
---
--- This function iterates through all objects in the current map and sets the
--- minimum LOD on any objects that are outside of the border area. It then
--- recreates the render objects to apply the changes.
---
--- @param none
--- @return none
---
function ForceLODMinOutsideBorder()
	local border = GetBorderAreaLimits()
	MapForEach("map", "AutoAttachObject", function(obj)
		if not obj:GetPos():InBox2D(border) and border:Intersect2D(obj:GetObjectBBox()) == const.irOutside then
			obj:SetForcedLODMin(true)
			obj:SetAutoAttachMode(obj:GetAutoAttachMode())
		end
	end)
	MapForEach("map", function(obj)
		if not obj:GetPos():InBox2D(border) and border:Intersect2D(obj:GetObjectBBox()) == const.irOutside then
			obj:SetForcedLODMin(true)
		end
	end)
	RecreateRenderObjects()
end

-- Compatibility method used for reading the old LowerLOD value in the maps
---
--- Sets the lower LOD state of the object.
---
--- If `value` is true, the object's forced LOD state is set to "Minimum".
--- If `value` is false, the object's forced LOD state is set to "Automatic".
---
--- @param value boolean Whether to set the lower LOD state to "Minimum" or "Automatic".
---
function CObject:SetLowerLOD(value)
	if value then
		self:SetForcedLODState("Minimum")
	else
		self:SetForcedLODState("Automatic")
	end
end

---
--- Counts the number of entities in all maps and generates a CSV report with mesh statistics.
---
--- This function iterates through all entities in all maps, counting the number of instances of each entity.
--- It then generates a CSV report with the following information for each entity:
--- - Entity name
--- - Number of vertices in the entity's mesh
--- - Number of triangles in the entity's mesh
--- - Total number of vertices across all instances of the entity
--- - Total number of triangles across all instances of the entity
--- - Number of vertices in the entity's highest LOD mesh
--- - Number of triangles in the entity's highest LOD mesh
--- - Number of instances of the entity
---
--- The CSV report is saved to a file named "mesh_stats.csv".
---
--- @return none
---
function CountEntitiesInAllMaps()
	local stats = {}
	
	for entity in pairs(GetAllEntities()) do
		stats[entity] = 0
	end

	local maps = {}
	for _, map in pairs(MapData) do
		if map.Status ~= "Not started" then
			maps[#maps+1] = map.id
		end
	end
	
--	maps = { maps[1] }

	ForEachMap(maps, function()
		local count = MapForEach("map", function(obj)
			local entity = obj:GetEntity()
			if entity then
				stats[entity] = (stats[entity] or 0) + 1
			end
		end)
		print(count .. " objects in " .. GetMap())
	end)
	
	local csv = {}
	for entity, count in pairs(stats) do
		if entity ~= "" and GetStateMeshFile(entity, 0) then
			local mesh_props = GetMeshProperties(GetStateMeshFile(entity, 0))
			if mesh_props then
				local last_lod = 0
				while GetStateMeshFile(entity, 0, last_lod+1) do
					last_lod = last_lod + 1
				end
				local mesh_props_lod = GetMeshProperties( GetStateMeshFile(entity, 0, last_lod) )
				csv[#csv+1] = { 
					entity, 
					mesh_props.NumVerts, mesh_props.NumTriangles, 
					mesh_props.NumVerts*count, mesh_props.NumTriangles*count,
					(mesh_props_lod or mesh_props).NumVerts*count, (mesh_props_lod or mesh_props).NumTriangles*count,
					count, 
				}
			end
		end
	end
	SaveCSV("mesh_stats.csv", csv, nil, {"entity", "vertexes", "triangles", "vertexes_times_count", "triangles_times_count", "lod_vertexes_times_count", "lod_triangles_times_count", "count",})
end

function OnMsg.BeforeUpsampledScreenshot(store)
	local gridMarkers = {}
	MapForEachMarker("GridMarker", nil, function(marker)
		if marker:IsAreaShown() then 
			marker:HideArea()
			table.insert(gridMarkers,marker)
		end
	end)
	store.gridMarkers = gridMarkers
end

function OnMsg.AfterUpsampledScreenshot(store)
	for _, marker in ipairs(store.gridMarkers) do
		marker:ShowArea()
	end
end

---
--- Replaces sound sources in the map with beach markers if the sound source only contains wave sounds.
--- If the sound source contains both wave sounds and other sounds, it will not be replaced and an error will be logged.
---
--- @function ReplaceSoundSourcesWithBeachMarkers
--- @return nil
function ReplaceSoundSourcesWithBeachMarkers()
	local to_be_replaced = {
		"waves_cliffs",
		"waves_shore",
		"waves_wharf",
		"waves_beach",
	}
	if not IsEditorActive() then
		print("Please run this in editor")
		return
	end
	local replaced = 0
	local wss = MapGet("map", "SoundSource")
	for _, source in ipairs(wss) do
		local count = 0
		for _, sound in ipairs(source.Sounds) do
			for _, pattern in ipairs(to_be_replaced) do
				if sound.Sound:find(pattern) then
					count = count + 1
				end
			end
		end
		if count == #source.Sounds then
			local bm = PlaceObject("BeachMarker")
			bm:SetGameFlags(const.gofPermanent)
			bm:SetPos(source:GetPos())
			DoneObject(source)
			replaced = replaced + 1
		elseif count > 0 then
			StoreErrorSource(source, "Sound source contains both waves and other sound banks, not replacing - please review")
		end
	end
	print("Replaced sound sources with beach markers:", replaced)
end

if FirstLoad then
	s_BlacklistEntity = false
end

local function GetBlacklist(filename)
	local err, data = AsyncFileToString(filename, nil, nil, "lines")
	if err then
		printf("Error loading blacklist entities: %s", err)
	else	
		return data
	end
end


---
--- Toggles the visualization of blacklisted entities in the game.
---
--- When the blacklist is enabled, all blacklisted entities will be rendered with a white gamma modifier.
--- When the blacklist is disabled, the gamma modifier will be reset and the render objects will be recreated.
---
--- The blacklist is loaded from a file specified by `EngineBinAssetsBlacklistEntitiesFilename`.
---
function ToggleBlacklistEntitiesVisualization()
	if s_BlacklistEntity then
		s_BlacklistEntity = false
		hr.UseSatGammaModifier = 0
		RecreateRenderObjects()
		return
	end
	
	local entities = GetBlacklist(EngineBinAssetsBlacklistEntitiesFilename)
	s_BlacklistEntity = {}
	for _, entity in ipairs(entities) do
		s_BlacklistEntity[entity] = true
	end
	hr.UseSatGammaModifier = 1
	RecreateRenderObjects()
	MapForEach(true, "CObject", function(obj)
		if IsBlacklistEntity(obj) then
			obj:SetGamma(const.clrWhite)
		end
	end)
end

---
--- Checks if the given object or entity is on the blacklist.
---
--- @param obj_or_ent CObject|CEntity The object or entity to check
--- @return boolean True if the object or entity is on the blacklist, false otherwise
---
function IsBlacklistEntity(obj_or_ent)
	if not s_BlacklistEntity then	
		return false
	end
	
	return s_BlacklistEntity[IsValid(obj_or_ent) and obj_or_ent:GetEntity() or obj_or_ent]
end

local old_CObject_new = CObject.new

---
--- Overrides the `CObject.new()` constructor to set the gamma modifier for blacklisted entities.
---
--- When a new `CObject` instance is created, this function checks if the object is on the blacklist. If so, it sets the gamma modifier of the object to the white color.
---
--- @param self CObject The `CObject` class
--- @param ... any Arguments passed to the original `CObject.new()` constructor
--- @return CObject The new `CObject` instance with the gamma modifier set if it is on the blacklist
---
function CObject.new(self, ...)
	local obj = old_CObject_new(self, ...)
	
	if IsBlacklistEntity(obj) then
		obj:SetGamma(const.clrWhite)
	end
	
	return obj
end

local function GetBlacklistFootprint(filename, folder, ext)
	folder = folder or ""
	
	local footprint = 0
	local files = GetBlacklist(filename)
	for _, file in ipairs(files) do
		local path, filename, org_ext = SplitPath(file)
		local size = io.getsize(folder .. path .. filename .. (ext or org_ext))
		footprint = footprint + size
	end

	return footprint
end

---
--- Calculates the total size of the blacklisted textures.
---
--- This function retrieves the total size of all the files listed in the `EngineBinAssetsBlacklistTexturesFilename` file. It then prints the total size in gigabytes.
---
--- @return nil
---
function GetBlacklistTexturesFootprint()
	local size = GetBlacklistFootprint(EngineBinAssetsBlacklistTexturesFilename)
	printf("Textures DDS: %.2fGB", size / (1024.0 * 1024 * 1024))
end

---
--- Calculates the total size of the blacklisted music files.
---
--- This function retrieves the total size of all the music files listed in the `EngineBinAssetsBlacklistMusicFilename` file. It then prints the total size in gigabytes for both WAV and Opus formats, as well as the compression ratio between the two.
---
--- @return nil
---
function GetBlacklistMusicFootprint()
	local wav = GetBlacklistFootprint(EngineBinAssetsBlacklistMusicFilename, nil, ".wav")
	local opus = GetBlacklistFootprint(EngineBinAssetsBlacklistMusicFilename, "svnAssets/Bin/win32/", ".opus")
	printf("Music WAV: %.2fGB", wav / (1024.0 * 1024 * 1024))
	printf("Music Opus: %.2fGB", opus / (1024.0 * 1024 * 1024))
	printf("Music Compression Ratio: %.2f", 1.0 * wav / opus)
end

---
--- Calculates the total size of the blacklisted sound files.
---
--- This function retrieves the total size of all the sound files listed in the `EngineBinAssetsBlacklistSoundsFilename` file. It then prints the total size in gigabytes for both WAV and Opus formats, as well as the compression ratio between the two.
---
--- @return nil
---
function GetBlacklistSoundsFootprint()
	local wav = GetBlacklistFootprint(EngineBinAssetsBlacklistSoundsFilename, nil, ".wav")
	local opus = wav / 14.19
	printf("Sounds WAV: %.2fGB", wav / (1024.0 * 1024 * 1024))
	printf("Sounds Opus: %.2fGB", opus / (1024.0 * 1024 * 1024))
	printf("Sounds Compression Ratio: %.2f", 1.0 * wav / opus)
end

---
--- Calculates the total size of the blacklisted voice files.
---
--- This function retrieves the total size of all the voice files listed in the `EngineBinAssetsBlacklistVoicesFilename` file. It then prints the total size in gigabytes for both WAV and Opus formats, as well as the compression ratio between the two.
---
--- @return nil
---
function GetBlacklistVoicesFootprint()
	local wav = GetBlacklistFootprint(EngineBinAssetsBlacklistVoicesFilename, "svnAssets/Source/", ".wav")
	local opus = GetBlacklistFootprint(EngineBinAssetsBlacklistVoicesFilename, "svnAssets/Bin/win32/", ".opus")
	printf("Voices WAV: %.2fGB", wav / (1024.0 * 1024 * 1024))
	printf("Voices Opus: %.2fGB", opus / (1024.0 * 1024 * 1024))
	printf("Voices Compression Ratio: %.2f", 1.0 * wav / opus)
end

EngineBinAssetsBlacklistEntitiesFilename = "BinAssets/EngineBinAssetBlacklistEntities.txt"
EngineBinAssetsBlacklistTexturesFilename = "BinAssets/EngineBinAssetBlacklistTextures.txt"
EngineBinAssetsBlacklistMusicFilename = "BinAssets/EngineBinAssetBlacklistMusic.txt"
EngineBinAssetsBlacklistSoundsFilename = "BinAssets/EngineBinAssetBlacklistSounds.txt"
EngineBinAssetsBlacklistVoicesFilename = "BinAssets/EngineBinAssetBlacklistVoices.txt"

---
--- Retrieves the list of game map entities and unit markers with banter groups.
---
--- This function scans the "svnAssets/Source/Maps" directory for folders representing demo sectors. For each demo sector, it reads the "entlist.txt" file to get the list of used entities, and the "markers.debug.lua" file to get the list of unit markers with associated banter groups.
---
--- @return table, table Used entities and unit markers with banter groups
---
function GetGameMapEntities()
	local err, folders = AsyncListFiles("svnAssets/Source/Maps", "*", "folders")
	if err then
		EngineBinAssetsPrint("Error generating black list entities: %s", err)
		return
	end
	
	local used_entity, unit_markers_bantes_groups = {}, {}
	for _, folder in ipairs(folders) do
		local _, sector = SplitPath(folder)
		if IsDemoSector(sector) then
			local filename = folder .. "/entlist.txt"
			if io.exists(filename) then
				local err, lines = AsyncFileToString(filename, nil, nil, "lines")
				if err then
					EngineBinAssetsPrint("Error paris '%s': %s", filename, err)
				else
					for _, entity in ipairs(lines) do
						used_entity[entity] = true
					end
				end
			end
			local filename = folder  .. "/markers.debug.lua"
			if io.exists(filename) then
				local err, str = AsyncFileToString(filename)
				if str then
					local _, markers_data = LuaCodeToTuple(str)
					local map_name = markers_data and markers_data[1].map
					if map_name then
						for _, marker in ipairs(markers_data) do
							if marker.type == "UnitMarker" then
								if #(marker.ApproachedBanters or empty_table) > 0 or #(marker.BanterGroups or empty_table) > 0 or #(marker.ApproachBanterGroup or empty_table) > 0 then
									for _, group in ipairs(marker.Groups or empty_table) do
										unit_markers_bantes_groups[group] = true
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	return used_entity, unit_markers_bantes_groups
end

---
--- Generates a blacklist of entities, textures, and voices that are not used in the game.
---
--- @param entity_textures table A table mapping entity names to their used textures.
--- @param used_textures table A table of textures that are used in the game.
--- @param textures_data table A table containing metadata about the textures.
--- @return table, table, table The blacklists of entities, textures, and voices.
---
function GetBlacklistEntities(entity_textures, used_textures, textures_data)
	local used_entity, used_voices = GetGameMapEntities()
	local additional_blacklist_textures = {}
	Msg("GatherGameEntities", used_entity, additional_blacklist_textures, used_voices)
	local all_entities = GetAllEntities()
	local blacklist_entities = {}
	for entity in pairs(all_entities) do
		if not used_entity[entity] and not entity:starts_with("Terrain") then
			table.insert(blacklist_entities, entity)
		end
	end
	table.sort(blacklist_entities)
	
	local is_blacklisted = {}
	for _, entity in ipairs(blacklist_entities) do
		is_blacklisted[entity] = true
	end
	
	local all_textures, ref_by_non_blacklisted = {}, {}
	local err, list = AsyncListFiles("Textures/", "*.dds", "size,relative")
	local texture_sizes = {}
	for k,v in ipairs(list) do
		local file_data = textures_data[v]
		if not file_data.alias then
			texture_sizes["Textures/" .. v] = list.size[k]
		else
			texture_sizes["Textures/" .. v] = 0
		end
	end
	local entity_sizes = {}
	local texture_counted = {}
	for entity, textures in pairs(entity_textures) do
		for texture in pairs(textures) do
			all_textures[texture] = true
			if not is_blacklisted[entity] then
				ref_by_non_blacklisted[texture] = true
				entity_sizes[entity] = entity_sizes[entity] or 0
				if not texture_counted[texture] then
					entity_sizes[entity] = entity_sizes[entity] + texture_sizes[texture]
					texture_counted[texture] = true
				end
			end
		end
	end
	
	AsyncStringToFile("svnAssets/tmp/entity_sizes.lua", ValueToLuaCode(entity_sizes))
	AsyncStringToFile("svnAssets/tmp/entity_textures.lua", ValueToLuaCode(entity_textures))
	
	local blacklist_textures = {}
	local all_textures = table.keys(all_textures)
	for _, texture in ipairs(all_textures) do
		if not ref_by_non_blacklisted[texture] then
			blacklist_textures[texture] = true
		end
	end
	
	-- collapsing means out of multiple identical texture only one is shipped in the game
	-- if a texture is shipped, blacklisted, but has identical textures which are not blacklisted, it should be removed from the blacklist
	local siblings = {}
	for textureId, textureData in pairs(entity_textures) do
		local texture_siblings = siblings[textureId] or {}
		texture_siblings[#texture_siblings+1] = "Textures/" .. textureId
		siblings[textureId] = texture_siblings
		if textureData.alias then
			siblings[textureData.alias] = texture_siblings
		end
	end
	local remove_from_blacklist = {}
	for texture in pairs(blacklist_textures) do
		texture = texture:match("Textures/(.*)$")
		if texture and used_textures[texture] then
			for _, sibling in ipairs(siblings[texture]) do
				if not blacklist_textures[sibling] then
					remove_from_blacklist[texture] = true
					break
				end
			end
		end
	end
	for texture in pairs(remove_from_blacklist) do
		blacklist_textures["Textures/" .. texture] = nil
	end
	
	blacklist_textures = table.keys(blacklist_textures, "sorted")
	table.iappend(blacklist_textures, additional_blacklist_textures)
	
	local blacklist_banter_voices = {}
	Msg("GatherVoiceBanters", blacklist_banter_voices)
	
	local blacklist_voices = {}
	local err, voices = AsyncListFiles("svnAssets/bin/win32/Voices/English", "*")
	if err then
		printf("Error listing voices: %s", err)
	else
		local loc = LoadCSV("svnProject/LocalizationOut/English/CurrentLanguage/Game.csv")
		for i = 2, #loc do
			local entry = loc[i]
			local voice_id = tonumber(entry[1])
			local voice_blacklisted = blacklist_banter_voices[voice_id]
			local used_actor = used_voices[entry[15]] or used_voices[entry[16]] or used_voices[entry[17]]
			if used_actor then
				voice_blacklisted = false
			end
			if voice_blacklisted then
				local voice = string.format("Voices/English/%s.opus", voice_id)
				blacklist_voices[voice] = true
			end
		end
	end
	blacklist_voices = table.keys(blacklist_voices, "sorted")
	
	return blacklist_entities, blacklist_textures, blacklist_voices
end

local function GetBlacklistFiles(folder, used_files, ext)
	ext = ext or ""
	
	local err, files = AsyncListFiles(folder, "*", "recursive")
	if err then
		printf("Error listing '%s' folder: %s", folder, err)
		return
	end
	
	local blacklist_files = {}
	for _, filename in ipairs(files) do
		local path, file, ext = SplitPath(filename)
		local track = path .. file
		if not used_files[track] then
			table.insert(blacklist_files, track .. ext)
		end
	end
	table.sort(blacklist_files)
	
	return blacklist_files
end

local function GetBlacklistMusic()
	local used_music = {}
	Msg("GatherMusic", used_music)
	
	return GetBlacklistFiles("Music", used_music, ".wav")
end

local function GetBlacklistSounds()
	local used_sounds = {}
	Msg("GatherSounds", used_sounds)
	
	return GetBlacklistFiles("Sounds/environment-stereo", used_sounds, ".wav")
end

function OnMsg.BuildEngineBinAssets(entity_textures, used_tex, textures_data)
	local blacklist_entities, blacklist_textures, blacklist_voices = GetBlacklistEntities(entity_textures, used_tex, textures_data)
	AsyncStringToFile(EngineBinAssetsBlacklistEntitiesFilename, table.concat(blacklist_entities, "\n"))
	SVNAddFile(EngineBinAssetsBlacklistEntitiesFilename)
	AsyncStringToFile(EngineBinAssetsBlacklistTexturesFilename, table.concat(blacklist_textures, "\n"))
	SVNAddFile(EngineBinAssetsBlacklistTexturesFilename)
	local blacklist_music = GetBlacklistMusic()
	AsyncStringToFile(EngineBinAssetsBlacklistMusicFilename, table.concat(blacklist_music, "\n"))
	SVNAddFile(EngineBinAssetsBlacklistMusicFilename)
	local blacklist_sounds = GetBlacklistSounds()
	AsyncStringToFile(EngineBinAssetsBlacklistSoundsFilename, table.concat(blacklist_sounds, "\n"))
	SVNAddFile(EngineBinAssetsBlacklistSoundsFilename)
	AsyncStringToFile(EngineBinAssetsBlacklistVoicesFilename, table.concat(blacklist_voices, "\n"))
	SVNAddFile(EngineBinAssetsBlacklistVoicesFilename)
end

if Platform.developer then

---
--- Checks the position of a water object and determines if it is under the terrain.
--- If the water object is under the terrain, it will either store an error source or delete the object.
---
--- @param water table The water object to check.
--- @param data string|table If "delete", the water object will be deleted. If a table, the water object will be added to the table.
--- @param no_vme boolean If true, no error source will be stored.
---
function CheckWaterObjPos(water, data, no_vme)
	local pos = water:GetPos()
	local z = pos:z() or terrain.GetHeight(pos)
	local bbox = water:GetObjectBBox():SetInvalidZ()
	local minx, miny = bbox:min():xy()
	local maxx, maxy = bbox:max():xy()
	local sizex, sizey = terrain.GetMapSize()
	if 0 <= minx and minx < sizex and 0 <= miny and miny <= sizey and 0 <= maxx and maxx < sizex and 0 <= maxy and maxy <= sizey then
		local min_z, max_z = terrain.GetMinMaxHeight(bbox)
		if z < min_z then
			if not no_vme then
				StoreErrorSource(water, string.format("Water plane Z=%d but range[%d-%d] under terrain!", z, min_z, max_z))
			end
			if data == "delete" then
				DoneObject(water)
			elseif type(data) == "table" then
				table.insert(data, water)
			end
		end
	end
end

---
--- Checks all water objects in the map and determines if they are under the terrain. If a water object is under the terrain, it will either store an error source or delete the object.
---
--- @param delete boolean If true, water objects under the terrain will be deleted. If false, they will be stored in an error source.
---
function CheckWaterObjectsUnderTerrain(delete)
	MapForEach("map", "WaterObj", CheckWaterObjPos, delete)
end

---
--- Finds all maps that have water objects that are under the terrain.
---
--- This function creates a real-time thread that iterates through all maps and checks for water objects that are under the terrain. If any are found, the map name and the number of water objects under the terrain are printed to the console, and the map name is added to a list of maps with this issue.
---
--- After checking all maps, the function prints the total number of maps with water objects under the terrain, and the list of those maps.
---
--- @return none
---
function GetMapsWithWaterUnderTerrain()
	CreateRealTimeThread(function()
		local maps = {}
		ForEachMap(nil, function()
			local objs = {}
			MapForEach("map", "WaterObj", CheckWaterObjPos, objs, "no VME")
			if #objs > 0 then
				local msg = string.format("%s: %d", GetMapName(), #objs)
				table.insert(maps, msg)
				print(msg)
			end
		end)
		print(string.format("%d Maps with WaterObj under terrain\n%s", #maps, table.concat(maps, "\n")))
	end)
end

function OnMsg.SaveMap()
	CheckWaterObjectsUnderTerrain()
end

end

---
--- Forces EyeCandy instances of the selected object(s) outside of the map.
---
--- If no objects are selected, a message is printed to the console.
---
--- The function first gets the border area limits of the map. It then calculates a threshold distance from the map border, which is either 20 or 50 times the slab size, depending on whether the Control key is pressed.
---
--- The function then gets all objects of the same class as the selected object(s), that are outside the threshold distance from the map border. It applies a random salt to the object positions to distribute the objects more evenly.
---
--- The function then begins an editor undo operation, suspends pass edits, sets the detail class of the selected objects to "Eye Candy", and resumes pass edits. Finally, it ends the undo operation.
---
--- @param none
--- @return none
---
function editor.EyeCandyOutsideMap()
	if #editor.GetSel() < 1 then
		print("Please select an object to force EyeCandy to instances of that object outside of the map")
		return
	end

	local bx = GetBorderAreaLimits()
	local threshold = (terminal.IsKeyPressed(const.vkControl) and 50 or 20) * const.SlabSizeX
	local salt = "EyeCandyOutsideMap"
	
	local objs = MapGet("map", table.keys2(table.invert(table.map(editor.GetSel(), "class"))), 
		function(x)
			local dist = bx:Dist2D(x)
			if dist == 0 then return false end
			return
				dist > threshold or
				((xxhash(x:GetPos(), salt) % 1024) < MulDivRound(dist, 1024, threshold))
		end)
	
	XEditorUndo:BeginOp{ objects = objs, name = "Eye Candy outside map" }
	SuspendPassEditsForEditOp(objs)
	for _, x in ipairs(objs) do
		x:ClearEnumFlags(const.efCollision + const.efApplyToGrids)
		x:SetDetailClass("Eye Candy")
	end
	ResumePassEditsForEditOp(objs)
	XEditorUndo:EndOp(objs)
end
