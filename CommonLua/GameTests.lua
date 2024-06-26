---
--- Creates print functions for game tests.
---
--- @param output function The output function to use for printing.
--- @param tag string The tag to use for the print functions.
--- @param timestamp boolean Whether to include a timestamp in the output.
---
--- The created print functions are:
--- - `GameTestsPrint`: A simple print function.
--- - `GameTestsPrintf`: A print function that supports formatting.
--- - `GameTestsError`: An error print function that includes a timestamp.
--- - `GameTestsErrorf`: An error print function that supports formatting and includes a timestamp.
---
function CreateTestPrints(output, tag, timestamp)
	tag = tag or ""
	local err_tag = "GT_ERROR " .. tag
	
	GameTestsPrint = CreatePrint { tag, output = output }
	GameTestsPrintf = CreatePrint { tag, output = output, format = string.format }
	GameTestsError = CreatePrint { err_tag, output = output, timestamp = timestamp  }
	GameTestsErrorf = CreatePrint { err_tag, output = output, timestamp = timestamp, format = string.format }
end

if FirstLoad then
	GameTestsRunning = false
	GameTestsPrint = false
	GameTestsPrintf = false
	GameTestsError = false
	GameTestsErrorf = false
	GameTestsErrorsFilename = "svnAssets/Logs/GameTestsErrors.log"
	GameTestsFlushErrors = empty_func -- if you want to see the prints from asserts inside the prints some sub-section of your test, call this when the sub-section ends
	
	CreateTestPrints()
end

---
--- Runs a set of game tests.
---
--- @param time_start_up number The time when the game started up, in seconds.
--- @param game_tests_name string The name of the game tests table to run.
--- @param ... string The names of the specific tests to run. If none are provided, all tests in the table will be run.
---
--- This function creates a real-time thread to run the game tests. It performs the following steps:
--- 1. Deletes the `GameTestsErrorsFilename` file.
--- 2. Opens a file to log any errors that occur during the tests.
--- 3. Creates a `GameTestOutput` function that prints to the console and writes to the error log file.
--- 4. Calls `CreateTestPrints` to set up the print functions for the tests.
--- 5. Loads the necessary bin assets.
--- 6. Sets the `GameTestsRunning` flag to true and sends a "GameTestsBegin" message.
--- 7. Sets all dev DLCs to true.
--- 8. Modifies the `config` table to disable backtraces and silent VME stack.
--- 9. Retrieves the game tests table and the list of tests to run.
--- 10. Runs each test, capturing any errors and flushing the log file.
--- 11. If any tests failed, prints the complete log file.
--- 12. Closes the error log file.
--- 13. Sets the `GameTestsRunning` flag to false and sends a "GameTestsEnd" message.
--- 14. Restores the `config` table and updates the thread debug hook.
--- 15. Calls `CreateTestPrints` to reset the print functions.
--- 16. Quits the thread.
---
function RunGameTests(time_start_up, game_tests_name, ...)
	time_start_up = os.time() - (time_start_up or os.time())
	game_tests_name = game_tests_name or "GameTests"

	CreateRealTimeThread( function(...)
		AsyncFileDelete(GameTestsErrorsFilename)
		local game_tests_errors_file, error_msg = io.open(GameTestsErrorsFilename, "w+")
		if not game_tests_errors_file then
			print("Failed to open GameTestsErrors.log:", error_msg)
		end
		
		local function GameTestOutput(s)
			ConsolePrintNoLog(s)
			if game_tests_errors_file then
				game_tests_errors_file:write(s, "\n")
			end
		end

		CreateTestPrints(GameTestOutput)
		GameTestsPrintf("Lua rev: %d, Assets rev: %d", LuaRevision, AssetsRevision)
		
		LoadBinAssets("") -- saving presets that include ColorizationPropSet requires knowledge about the number of colorization channels for entities
		
		GameTestsRunning = true
		Msg("GameTestsBegin", true)
		SetAllDevDlcs(true)
		
		table.change(config, "GameTests", {
			Backtrace = false,
			SilentVMEStack = true,
		})
		UpdateThreadDebugHook()

		local game_tests_table = _G[game_tests_name]
		local tests_to_run = {...}
		if #tests_to_run == 0 then
			tests_to_run = table.keys2(game_tests_table, "sorted")
		end
		local log_lines_processed = 0

		local any_failed
		local lua_error_prefix = "[LUA ERROR] "
		GameTestsFlushErrors = function()
			FlushLogFile()
			local err, log_file = AsyncFileToString(GetLogFile(), false, false, "lines")
			if not err then
				for i = log_lines_processed+1, #log_file do
					local line = log_file[i]
					if line:starts_with(lua_error_prefix) then
						GameTestsErrorf("%s", string.sub(line, #lua_error_prefix+1))
						any_failed = true
					elseif line:match("%)%: ASSERT.*failed") then
						GameTestsErrorf("once", "%s", line)
						any_failed = true
					elseif line:match(".*%.lua%(%d*%): ") then
						GameTestsErrorf("%s", line)
						any_failed = true
					elseif line:match("COMPILE!.*fx") then
						GameTestsPrint("once", line)
					end
				end
				log_lines_processed = #log_file
			else
				GameTestsPrint("Failed to load log file from game " .. GetLogFile() .. " : " .. err)
			end
			if game_tests_errors_file then
				game_tests_errors_file:flush()
			end
		end
		
		GameTestsFlushErrors()
		
		local all_tests_start_time = GetPreciseTicks()
		for _, test in ipairs(tests_to_run) do
			if game_tests_table[test] then
				CreateTestPrints(GameTestOutput, test, "gametime")
				
				GameTestsPrint("Start...")
				local time = GetPreciseTicks()
				Msg("GameTestBegin", test)
				
				local success = sprocall(game_tests_table[test], time_start_up, game_tests_name)
				if not success then
					any_failed = true
				end
				
				Msg("GameTestEnd", test)
				GameTestsFlushErrors()
				GameTestsPrint(string.format("...end. Duration %i ms. Since start %i sec.", GetPreciseTicks() - time , (GetPreciseTicks() - all_tests_start_time) / 1000))
			else
				GameTestsError("GameTest not found:", test)
			end
		end
		
		if any_failed then
			FlushLogFile()
			local err, log_file = AsyncFileToString(GetLogFile(), false, false, "lines")
			if not err then
				CreateTestPrints(GameTestOutput, "GT_LOG")
				GameTestsPrint("Complete log file from run follows:")
				GameTestsPrint(string.rep("-", 80))
				for _, line in ipairs(log_file) do
					GameTestsPrint(line)
				end
			end
		end
		
		if game_tests_errors_file then
			game_tests_errors_file:close()
		end
		
		GameTestsRunning = false
		Msg("GameTestsEnd", true)
		
		table.restore(config, "GameTests", true)
		UpdateThreadDebugHook()
		
		CreateTestPrints()
		
		quit()
	end, ...)
end

---
--- Runs a set of game tests.
---
--- @param game_tests_table table A table of game test functions.
--- @param names string[] An optional list of test names to run.
---
function DbgRunGameTests(game_tests_table, names)
	if not IsRealTimeThread() then
		return CreateRealTimeThread(DbgRunGameTests, game_tests_table, names)
	end
	GameTestsRunning = true
	Msg("GameTestsBegin")
	local old = LocalStorage.DisableDLC
	SetAllDevDlcs(true)
	game_tests_table = game_tests_table or GameTests
	names = names or table.keys(game_tests_table, true)
	local times = {}
	local st = GetPreciseTicks()
	for _, name in ipairs(names) do
		local func = game_tests_table[name]
		if not func then
			printf("No such test", name)
		else
			CreateTestPrints(print, name)
			Msg("GameTestBegin", name)
			print("Testing", name)
			CloseMenuDialogs()
			local time = GetPreciseTicks()
			sprocall(func)
			time = GetPreciseTicks() - time
			Msg("GameTestEnd", name)
			printf("Done testing %s in %d ms", name, time)
			times[name] = time
		end
	end
	if #names > 1 then
		printf("Done testing all in %d ms", GetPreciseTicks() - st)
		for _, name in ipairs(names) do
			printf("\t%s: %d ms", name, times[name])
		end
		print()
	end
	LocalStorage.DisableDLC = old
	SaveLocalStorage()
	CreateTestPrints()
	GameTestsRunning = false
	Msg("GameTestsEnd")
end

---
--- Runs a single game test.
---
--- @param name string The name of the game test to run.
--- @param game_tests_table table A table of game test functions.
--- @return nil
---
function DbgRunGameTest(name, game_tests_table)
	return DbgRunGameTests(game_tests_table, {name})
end

GameTests = {}
GameTestsNightly = {}

-- these are defined per project
---
--- Configures global variables related to UI testing.
---
--- @field g_UIAutoTestButtonsMap boolean Indicates whether to automatically map buttons for UI testing.
--- @field g_UIGameChangeMap function Function to call when changing the game map.
--- @field g_UIGetContentTop function Function to get the top-level UI content.
--- @field g_UIGetBuildingsList boolean Indicates whether to get a list of buildings.
--- @field g_UISpecialToggleButton table Configuration for special toggle buttons, including a match function.
--- @field g_UIBlacklistButton table Configuration for blacklisted buttons, including a match function.
--- @field g_UIPrepareTest boolean Indicates whether to call a function to prepare for UI testing.
---
g_UIAutoTestButtonsMap = false
g_UIGameChangeMap = ChangeMap
g_UIGetContentTop = function() return GetInGameInterface() end
g_UIGetBuildingsList = false
g_UISpecialToggleButton = {match = false}	-- match is function checking button properties to recognize special ones
g_UIBlacklistButton = {match = false}		-- match is function checking button properties to recognize black listed
g_UIPrepareTest = false						-- funtion to call on UI test start, e.g. cheat for research all

local function IsSpecialToggleButton(button, id)
	if g_UISpecialToggleButton[id] then return true end
	local match = g_UISpecialToggleButton.match
	return match and match(button)
end

local function IsBlacklistedButton(button, id)
	local id = rawget(button, "Id")
	if id and g_UIBlacklistButton[id] then
		return true
	end
	local match = g_UIBlacklistButton.match
	return match and match(button)
end

local function GetContentSnapshot(content)
	content = content or g_UIGetContentTop()
	
	local snapshot, used = {}, {}
	for idx, window in ipairs(content) do
		if not used[window] then
			used[window] = true
			snapshot[idx] = GetContentSnapshot(window)
		end
	end
	
	return snapshot, used
end

local function DetectNewWindows(snapshot, used)
	local new_snapshot, new_used = GetContentSnapshot()
	local windows = setmetatable({}, weak_keys_meta)
	for window in pairs(new_used) do
		if not used[window] then
			table.insert(windows, window)
		end
	end
	
	return windows
end

local function GetButtons(windows, buttons)
	buttons = buttons or {}
	
	for _, control in ipairs(windows) do
		if control:IsKindOf("XButton") then
			if not IsBlacklistedButton(control) then
				table.insert(buttons, control)
			end
		else
			GetButtons(control, buttons)
		end
	end
	
	return buttons
end

local function FilterWindowsWithButtons(windows)
	local windows_with_buttons = {}
	for _, window in ipairs(windows) do
		local buttons = GetButtons(window)
		if #buttons > 0 then
			table.insert(windows_with_buttons, {window = window, buttons = buttons})
		end
	end
	
	return windows_with_buttons
end

local function GetSelectObjContainer(obj)
	local snapshot, used = GetContentSnapshot()
	SelectObj(obj)
	WaitMsg("SelectionChange", 1000)
	local windows = DetectNewWindows(snapshot, used)
	local windows_with_buttons = FilterWindowsWithButtons(windows)
	assert(#windows_with_buttons <= 1)
	
	return #windows_with_buttons == 1 and windows_with_buttons[1]
end

local function GetButtonPressContainer(button)
	local snapshot, used = GetContentSnapshot()
	button:Press()
	local windows = DetectNewWindows(snapshot, used)
	local windows_with_buttons = FilterWindowsWithButtons(windows)
	assert(#windows_with_buttons <= 1)
	
	return #windows_with_buttons == 1 and windows_with_buttons[1]
end

local function GetButtonId(button, idx)
	return button.Id or string.format("idChild_%d", idx)
end

---
--- Recursively searches a container of UI controls for an XButton with the specified ID.
---
--- @param container table The container of UI controls to search.
--- @param id string The ID of the XButton to find.
--- @return XButton|nil The XButton with the specified ID, or nil if not found.
function FindButton(container, id)
	for _, control in ipairs(container) do
		if control:IsKindOf("XButton") then
			if GetButtonId(control) == id then
				return control
			end
		else
			local button = FindButton(control, id)
			if button then
				return button
			end
		end
	end
end

local function ExpandGraph(node, buttons)
	node.children = node.children or {}
	for idx, button in ipairs(buttons) do
		local id = GetButtonId(button, idx)
		table.insert(node.children, {processed = {}, children = {}, parent = node, id = id, expanded = false})
	end
	node.expanded = true
end

local function MarkNodeProcessed(node)
	node.parent.processed[node.id] = true
end

local function GenNodePath(node, nodes)
	for idx, child in ipairs(node.children) do
		if not node.processed[child.id] then
			table.insert(nodes, child)
			if child.expanded then
				local old_len = #buttons
				GenButtonSequence(child, nodes)
				if #nodes > old_len then
					return
				end
			else
				return
			end
			table.remove(nodes)
			node.processed[child.id] = true
		end
	end
end

local function FindButtonSequence(root)
	local nodes = {}
	GenNodePath(root, nodes)
	if #nodes > 0 then
		local node = nodes[#nodes]
		local buttons = {}
		for i = 1, #nodes - 1 do
			buttons[i] = nodes[i].id
		end
		
		return buttons, node
	end
end

---
--- Returns a list of unique building classes from the given list of buildings.
---
--- @param list table A list of buildings.
--- @return table A list of unique building classes.
function GetSingleBuildingClassList(list)
	local buildings, class_taken = {}, {}
	for _, bld in ipairs(list) do
		if not class_taken[bld.class] then
			table.insert(buildings, bld)
			class_taken[bld.class] = true
		end
	end
	
	return buildings
end

---
--- Performs UI button testing for a list of buildings.
---
--- This function iterates through a list of buildings, expands the graph of buttons for each building,
--- and clicks through the sequence of buttons for each building. It keeps track of the number of
--- button clicks performed and the total time taken.
---
--- @param none
--- @return none
function GameTests.BuildingButtons()
	if not g_UIAutoTestButtonsMap then return end
	
	local time_started = GetPreciseTicks()
	
	if GetMapName() ~= g_UIAutoTestButtonsMap then g_UIGameChangeMap(g_UIAutoTestButtonsMap) end
	local list, content
	while not (list and content) do
		list = g_UIGetBuildingsList()
		content = g_UIGetContentTop()
		Sleep(50)
	end
	if g_UIPrepareTest then
		g_UIPrepareTest()
	end
	
	--print(string.format("Testing UI buttons for %d buildings", #list))
	local clicks = 0
	SelectObj(false)
	for bld_idx, bld in ipairs(list) do
		local container = IsValid(bld) and GetSelectObjContainer(bld)
		if container then
			local root = {processed = {}, children = {}, expanded = false}
			ExpandGraph(root, container.buttons)
			local buttons, node = FindButtonSequence(root)
			while container and buttons do
				for _, button in ipairs(buttons) do
					-- TODO: keep changing container here
					button:Press()
					clicks = clicks + 1
				end
				local button = FindButton(container.window, node.id)
				if button and button:GetVisible() and button:GetEnabled() and not IsBlacklistedButton(button) then
					--print(string.format("Pressing %s:%s", bld.class, node.id))
					local new_container = GetButtonPressContainer(button)
					if new_container then
						ExpandGraph(node, new_container.buttons)
					end
					if IsSpecialToggleButton(button, node.id) then
						--print(string.format("Toggling off %s:%s", bld.class, node.id))
						button:Press()		-- toggle it
						clicks = clicks + 1
					end
				end
				MarkNodeProcessed(node)
				SelectObj(false)
				container = GetSelectObjContainer(bld)
				-- TODO: detect graph cycles
				buttons, node = FindButtonSequence(root)
			end
		end
		SelectObj(false)
	end
	GameTestsPrintf("Testing %d building for %d UI buttons clicks finished: %ds.", #list, clicks, (GetPreciseTicks() - time_started) / 1000)
end

---
--- Adds a reference value for a game test.
---
--- @param type string The type of the reference value (e.g. "Camera", "Lighting", etc.)
--- @param name string The name of the reference value (e.g. the camera ID)
--- @param value number The value to be used as a reference
--- @param comment string A comment describing the reference value
--- @param tolerance_mul number The multiplier for the tolerance value
--- @param tolerance_div number The divisor for the tolerance value
---
--- @return nil
function GameTestAddReferenceValue(type, name, value, comment, tolerance_mul, tolerance_div)
	if not type then return end	
	local results_file = "AppData/Benchmarks/GameTestReferenceValues.lua"
	local _, str_result = AsyncFileToString(results_file)
	local _, referenceValues = LuaCodeToTuple(str_result)

	referenceValues = referenceValues or {}

	local avg_previous, avg_items = 0, 0
	
	local maxResults = 5    -- how many results should be stored per test
	
	referenceValues[type] = referenceValues[type] or {}
	local benchmark_results = table.copy(referenceValues[type])
	
	benchmark_results[name] = benchmark_results[name] or {}

	for oldInd, oldCamera in pairs(benchmark_results[name]) do
		if oldCamera.comment == comment then
			avg_previous = avg_previous + oldCamera.value
			avg_items = avg_items + 1
		else 
			table.remove(benchmark_results[name], oldInd)
			GameTestsPrintf("Old %s not matching, deleting results for %s data!", name, type)
		end
	end
	table.insert(benchmark_results[name], {comment = comment, value = value})
	referenceValues[type] = benchmark_results
	while true do 
		if #benchmark_results[name] > maxResults then 
			table.remove(benchmark_results[name], 1) 
		else 
			break 
		end 
	end

	if avg_items == 0 then
		GameTestsPrintf("No previous results to compare to for %s: %s. New results saved.",type, name)
	else
		avg_previous = avg_previous/avg_items
	end
	
	if avg_previous ~= 0 then
		if abs( 100.0 - ( ( (value*1.0)* 100.0) / (avg_previous*1.0) ) ) <= (tolerance_mul*1.0)/(tolerance_div*1.0) * 100.0 then
			GameTestsPrintf("Reference value %s: %s is %s, avg of previous is %s", type, name, value, avg_previous)
		else
			GameTestsErrorf("Reference value %s: %s is %s, avg of previous is %s", type, name, value, avg_previous)
			GameTestsPrintf("Camera properties: "..tostring(comment))
		end
	end

	AsyncCreatePath("AppData/Benchmarks") 
	local err = AsyncStringToFile(results_file, ValueToLuaCode(referenceValues))
	if err then 
		GameTestsError("Failed to create file with reference values", results_file, err) 
	end
end

---
--- Runs a series of reference image tests for the game.
--- This function changes the map and video mode to a specific configuration,
--- captures screenshots from a set of predefined camera positions, and compares
--- the screenshots to reference images. The results are saved to an HTML report.
---
--- @param none
--- @return none
---
function GameTestsNightly.ReferenceImages()
	-- change map and video mode for consistency in tests
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap map not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	SetMouseDeltaMode(true)
	
	ChangeVideoMode(512, 512, 0, false, false)
	SetLightmodel(0, LightmodelPresets.ArtPreview, 0)
	WaitNextFrame(10)
	
	local allowedDifference = 80    -- the lower the value, the more different the images are allowed to be 
									-- max is (inf), if images are identical, (0) means images have absolutely nothing in common
									-- usually, when two images are quite simmilar, results vary from 80 to 100+
	
	local cameras =  Presets.Camera["reference"]
	if not cameras or #cameras == 0 then
		GameTestsPrint("No recorded 'reference' Cameras, could not complete test.")
		return
	end
	
	local ostime = os.time()
	local results = {}
	for i, cam in ipairs(cameras) do
		local logs_gt_src = "svnAssets/Logs/"..cam.id..".png"
		local logs_ref_src = "svnAssets/Logs/"..cam.id.."_"..ostime.."_reference.png"
		local logs_diff_src = "svnAssets/Logs/"..cam.id.."_"..ostime.."_diffResult.png"

		cam:ApplyProperties()
		cam:beginFunc()
		camera.Lock()
		Sleep(3500)
		
		AsyncCreatePath("svnAssets/Logs")
		local ref_img_path = "svnAssets/Tests/ReferenceImages/"
		local name = ref_img_path .. cam.id .. ".png"
		local err = AsyncCopyFile(name, logs_gt_src, "raw")
		if err then 
			err = AsyncExec(string.format("svn update %s --set-depth infinity", ConvertToOSPath(ref_img_path)), true, true)
			if err then
				GameTestsErrorf("Reference images folder '%s' could not be updated. Reason: %s!", ConvertToOSPath(ref_img_path), err) 
				return
			end
			err = AsyncExec(string.format("svn update %s --depth infinity", ConvertToOSPath(ref_img_path)), true, true)
			if err then
				GameTestsErrorf("Reference images folder '%s' could not be updated. Reason: %s!", ConvertToOSPath(ref_img_path), err) 
				return
			end
			err = AsyncCopyFile(name, logs_gt_src, "raw")
			if err then
				GameTestsErrorf("Reference images could not be copied from Tests folder for '%s' --> '%s'. Reason: %s. Try increasing SVN update depth manually!", ConvertToOSPath(name), ConvertToOSPath(logs_gt_src), err) 
				return
			end
		end
		
		AsyncFileDelete(logs_ref_src) 
		WriteScreenshot(logs_ref_src, 512, 512)
		Sleep(300)
		
		local err, img_err = CompareImages( logs_gt_src, logs_ref_src, logs_diff_src, 4)
		if img_err then if img_err < allowedDifference then
			GameTestsErrorf("Image taken from "..cam.id.." is too different from reference image!")
		end end
		cam:endFunc()
		WaitNextFrame(1)
		table.insert(results, {id = cam.id, img_err = img_err})
	end
	
	local newHTMLTable = {"<!doctype html>",
	"<head><style> table, th, td {border: 1px solid black;} </style>",
	"<title> Image report for Reference Cameras </title>",
	"<style type=\"text/css\">"}

	for i, img in ipairs(results) do
		local img_gt = string.format('"%s.png"',tostring(img.id))
		local img_ref = string.format('"%s_%s_reference.png"',tostring(img.id), tostring(ostime))

		table.iappend(newHTMLTable,
		{".class_", img.id, " {width: 512px; height: 512px;",
        "background: url(", img_gt, ") no-repeat;}",
        ".class_", img.id, ":active {width: 512px; height: 512px;",
        "background: url(", img_ref, ") no-repeat;}",
        ".class_", img.id, "_ref {width: 512px; height: 512px;",
        "background: url(", img_ref, ") no-repeat;}",
        ".class_", img.id, "_ref:active {width: 512px; height: 512px;",
        "background: url(", img_gt, ") no-repeat;}",
		})
	end

	table.iappend(newHTMLTable, 
		{"</style> </head> <body> <table>",
	 	 "<tr><th>Camera ID</th>",
		 "<th>Image error metric</th>",
		 "<th>Ground Truth</th>",
		 "<th>Difference</th> ",
		 "<th>New Image</th></tr>"})
	  
	for i,img in ipairs(results) do
		local str_for_color = " style=\"background-color:"..(img.img_err < allowedDifference and "#f76e59;\"" or "#92ed78;\"")
		local img_diff = string.format('"%s_%s_diffResult.png"',tostring(img.id), tostring(ostime))
		table.iappend(newHTMLTable,{
			"<tr><td><b>",img.id,"</b></td><td ",str_for_color,">", img.img_err,
			"</td><td><div class=\"class_", img.id,"\"></div></td>",
			"<td><img src=",img_diff, " alt=\" Difference image missing.\"></td>",
			"<td><div class=\"class_",img.id, "_ref\"> </div> </tr>"})
	  end
	table.insert(newHTMLTable,"</body></html>")

	AsyncCreatePath("svnAssets/Logs")	
	local report_name = os.date("%Y-%m-%d_%H-%M-%S", os.time())
	local err = AsyncStringToFile("svnAssets/Logs/reference_images_"..report_name..".html", table.concat(newHTMLTable))
		
	GameTestsPrint("RULE(reference_images_" .. report_name .. ")")
		
	--table.restore(hr, "reference_screenshot")
	ChangeVideoMode(1680, 940, 0, false, false)
	SetMouseDeltaMode(false)
	camera.Unlock()
end

---
--- Runs a rendering benchmark test for the game.
---
--- This function tests the rendering performance of the game by loading a specified map,
--- setting up a number of preset cameras, and measuring the CPU and GPU frame times for
--- each camera.
---
--- The function first checks if a rendering test map is specified in the configuration.
--- If not, it prints a message and returns. If the map is not found, it logs an error and
--- returns.
---
--- The function then changes the video mode to 1920x1080, waits for a few frames, and
--- gets the total number of shaders. It adds a reference value for the total number of
--- shaders to the game tests.
---
--- Next, the function retrieves the "benchmark" camera presets. If no presets are found,
--- it prints a message and returns.
---
--- The function then iterates through the camera presets, applying each one and measuring
--- the GPU and CPU frame times. The results are stored in a table.
---
--- Finally, the function restores the original rendering benchmark settings and adds
--- reference values for the CPU and GPU frame times for each camera to the game tests.
---
--- @return nil
function GameTestsNightly.RenderingBenchmark()
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap map not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	ChangeVideoMode(1920, 1080, 0, false, false)
	WaitNextFrame(5)
	
	local num_shaders = GetNumShaders()
	GameTestAddReferenceValue("TotalNumberOfShaders", 0, num_shaders, "", 20, 100)
	
	local cameras =  Presets.Camera["benchmark"]
	if not cameras or #cameras == 0 then
		GameTestsPrint("No recorded 'benchmark' Cameras, could not complete test.")
		return 
	end
	
	local results = {}
	table.change(hr, "rendering_benchmark", { RenderStatsSmoothing = 30 })
	for i, cam in pairs(cameras) do
		cam:ApplyProperties()
		Sleep(3000)
		
		local gpu_time = hr.RenderStatsFrameTimeGPU
		local cpu_time = hr.RenderStatsFrameTimeCPU
		local result = {
			time = os.time(),
			id = cam.id, 
			gpu_time = gpu_time, 
			cpu_time = cpu_time
		}
		table.insert (results, result)
	end
	table.restore(hr, "rendering_benchmark")
	
	for _, cameraResult in ipairs(results) do
		GameTestAddReferenceValue("RenderingBenchmarkCPU", cameraResult.id, cameraResult.cpu_time, "", 50, 1000)
		GameTestAddReferenceValue("RenderingBenchmarkGPU", cameraResult.id, cameraResult.gpu_time, "", 50, 1000)
	end
end

---
--- Runs a test that changes various rendering options in the game over a period of time.
---
--- The test will run for a specified duration (default 5 minutes) and randomly change various rendering options
--- in the game, such as shader settings, to ensure that non-inferred shaders are working correctly.
---
--- @param time number (optional) The duration of the test in milliseconds (default is 5 minutes)
--- @param seed number (optional) The random seed to use for the test (default is a random value)
--- @param verbose boolean (optional) Whether to print detailed information about the changes made during the test
--- @return nil
function TestNonInferedShaders(time, seed, verbose)
	if not config.RenderingTestsMap then
		GameTestsPrint("config.RenderingTestsMap not specified, skipping the test.")
		return
	end
	if not MapData[config.RenderingTestsMap] then
		GameTestsError(config.RenderingTestsMap, "map not found, could not complete test.")
		return
	end
	ChangeMap(config.RenderingTestsMap)
	WaitNextFrame(5)
	
	time = time or 5 * 60 * 1000 -- 5 min
	seed = seed or AsyncRand()
	GameTestsPrintf("TestNonInferedShaders: time %d, seed %d", time, seed)
	
	local options = {}
	for option, descr in pairs(OptionsData.Options) do
		if descr[1] and descr[1].hr then
			options[#options + 1] = descr
		end
	end
	
	local real_time_start = RealTime()
	local precise_time_start = GetPreciseTicks()
	local test = 0
	local rand = BraidRandomCreate(seed)
	local orig_hr = {}
	while RealTime() - real_time_start < time do
		test = test + 1
		GameTestsPrintf("Changing hr. options test #%d", test)
		local change_time = RealTime()
		local changed
		while not changed do
			for _, option_set in ipairs(options) do
				local entry = table.rand(option_set, rand())
				for hr_key, hr_param in sorted_pairs(entry.hr) do
					if hr[hr_key] ~= hr_param then
						if verbose then
							GameTestsPrintf("   hr['%s'] = %s -- was %s", hr_key, hr_param, hr[hr_key])
						end
						orig_hr[hr_key] = orig_hr[hr_key] or hr[hr_key]
						hr[hr_key] = hr_param
						changed = true
					end
				end
			end
		end
		WaitNextFrame(3)
		if verbose then
			GameTestsPrintf("done for %dms.", RealTime() - change_time)
		end
	end
	
	GameTestsPrintf("Restoring initial hr...")
	for hr_key, hr_param in sorted_pairs(orig_hr) do
		if verbose then
			GameTestsPrintf("   hr['%s'] = %s", hr_key, hr_param)
		end
		hr[hr_key] = hr_param
	end
	
	if verbose then
		GameTestsPrintf("Changing hr. options for %d mins finished.", time / (60 * 1000))
	end
end

---
--- Runs a test to validate that non-infered shaders are working correctly.
---
--- This function is part of the GameTestsNightly module, which contains a suite of nightly tests for the game.
---
--- @function GameTestsNightly.NonInferedShaders
--- @return nil
function GameTestsNightly.NonInferedShaders()
	TestNonInferedShaders()
end

---
--- Runs a test to validate that saving a map does not generate fake deltas.
---
--- This function is part of the GameTests module, which contains a suite of tests for the game.
---
--- @function GameTests.TestDoesMapSavingGenerateFakeDeltas
--- @return nil
function GameTests.TestDoesMapSavingGenerateFakeDeltas()
	if not config.AutoTestSaveMap then return end
	ChangeMap(config.AutoTestSaveMap)
	if GetMapName() ~= config.AutoTestSaveMap then
		GameTestsError("Failed to change map to " .. config.AutoTestSaveMap .. "! ")
		return
	end
	
	local p = "svnAssets/Source/Maps/" .. config.AutoTestSaveMap .. "/objects.lua"
	
	if not IsEditorActive() then
		EditorActivate()
	end
	SaveMap("no backup")
	EditorDeactivate()
	
	local _, str = SVNDiff(p)
	local diff = {}
	for s in str:gmatch("[^\r\n]+") do
		diff[#diff+1] = s
		if #diff == 20 then break end
	end
	if #diff > 0 then
		GameTestsError("Resaving " .. config.AutoTestSaveMap .. " produced differences!")
		GameTestsPrint(table.concat(diff, "\n"))
	end
end

-- call this at the beginning of each game test which requires to happen on a map, with loaded BinAssets
---
--- Loads a map for testing purposes.
---
--- This function is part of the GameTests module, which contains a suite of tests for the game.
---
--- If a map is already loaded, this function will return without doing anything. Otherwise, it will load the map specified by the `config.VideoSettingsMap` configuration variable. If that variable is not set, it will display an error message.
---
--- @function GameTests_LoadAnyMap
--- @return nil
function GameTests_LoadAnyMap()
	if GetMap() ~= "" then return end
	if not config.VideoSettingsMap then 
		GameTestsError("Configure config.GameTestsMap to test presets - some preset validation tests may only run on a map")
		return 
	end
	if GetMap() ~= config.VideoSettingsMap then
		CloseMenuDialogs()
		ChangeMap(config.VideoSettingsMap)
		WaitNextFrame()
	end
end

---
--- Validates the integrity of preset data for game tests.
---
--- This function is part of the GameTests module, which contains a suite of tests for the game.
---
--- It first loads a map for testing purposes using the `GameTests_LoadAnyMap()` function. It then temporarily replaces the `pairs` function with `g_old_pairs` and calls `ValidatePresetDataIntegrity()` with the "validate_all", "game_tests", and "verbose" arguments. Finally, it restores the original `pairs` function.
---
--- @function GameTests.z8_ValidatePresetDataIntegrity
--- @return nil
function GameTests.z8_ValidatePresetDataIntegrity()
	GameTests_LoadAnyMap()
	
	local orig_pairs = pairs
	pairs = g_old_pairs
	ValidatePresetDataIntegrity("validate_all", "game_tests", "verbose")
	pairs = orig_pairs
end

---
--- Runs tests for the in-game editors in the current project.
---
--- This function is part of the GameTests module, which contains a suite of tests for the game.
---
--- It first pauses the infinite loop detection, then iterates through the list of editors specified in the `config.EditorsToTest` variable. For each editor, it opens the preset editor, saves all changes, and then closes the editor. If any errors occur during this process, it logs an error message. 
---
--- The function can run the tests in parallel or sequentially, depending on the value of the `config.EditorsToTestThrottle` variable. If the throttle is not set, it runs the tests in parallel using up to 8 threads. Otherwise, it runs the tests sequentially with a delay between each test.
---
--- Finally, it prints the total time taken to run the tests and resumes the infinite loop detection.
---
--- @function GameTests.InGameEditors
--- @return nil
function GameTests.InGameEditors()
	if not config.EditorsToTest then return end
	
	PauseInfiniteLoopDetection("GameTests.InGameEditors")

	local time_started = GetPreciseTicks()
	local project = GetAppName()
	local function Test(editor_class)
		local waiting = CurrentThread()
		local worker = CreateRealTimeThread(function()
			local ged = OpenPresetEditor(editor_class)
			if ged then
				local err = ged:Send("rfnApp", "SaveAll", true)
				if err then
					GameTestsErrorf("%s:%s In-Game editor SaveAll(true) failed: %s", project, editor_class, tostring(err))
				end
				err = ged:Send("rfnClose")
			else
				GameTestsErrorf("%s:%s In-Game editor opening failed", project, editor_class)
			end
			Wakeup(waiting)
		end)
		if not WaitWakeup(10000) then
			GameTestsErrorf("%s:%s In-Game editor test timeout", project, editor_class)
			DeleteThread(worker)
		end
	end
	if not config.EditorsToTestThrottle then
		parallel_foreach(config.EditorsToTest, Test, nil, 8)
	else
		for _, editor_class in ipairs(config.EditorsToTest) do
			Test(editor_class)
			Sleep(config.EditorsToTestThrottle)
		end
	end
	GameTestsPrintf("%s In-Game editors tests finished: %ds.", project, (GetPreciseTicks() - time_started) / 1000)
	
	ResumeInfiniteLoopDetection("GameTests.InGameEditors")
end

--- This function is called to update the view positions after applying a video preset.
---
--- It is likely an internal implementation detail used by the `GameTests.ChangeVideoSettings()` function to ensure the camera and other view-related settings are properly updated when switching between video presets.
---
--- @function ChangeVideoSettings_ViewPositions
--- @return nil
function ChangeVideoSettings_ViewPositions() end
function GameTests.ChangeVideoSettings()
	if not config.VideoSettingsMap then return end
	local presets = {"Low", "Medium", "High", "Ultra"}
	if GetMap() ~= config.VideoSettingsMap then -- speed up the test by skipping map change if already on the test map
		CloseMenuDialogs()
		ChangeMap(config.VideoSettingsMap)
		WaitNextFrame()
	end
	local orig = OptionsCreateAndLoad()
	for _, p in ipairs(presets) do
		GameTestsPrint("Video preset", p)
		ApplyVideoPreset(p)
		WaitNextFrame()
		ChangeVideoSettings_ViewPositions()
	end
	if orig then
		GameTestsPrint("Returning to the original preset", orig.VideoPreset)
		ApplyOptionsObj(orig)
		WaitNextFrame()
	end
end

--- This function checks for missing animations in the entity states of all entities in the game.
---
--- It iterates through all entities and checks each state of the entity. If the state is animated but has no exported animation, it prints a warning message.
---
--- This function is likely used as part of the game's testing suite to ensure that all animated entity states have the necessary animations exported and available.
---
--- @function GameTests.EntityStatesMissingAnimations
--- @return nil
function GameTests.EntityStatesMissingAnimations()
	if not g_AllEntities then
		GameTests_LoadAnyMap()
	end
	for entity_name in sorted_pairs(g_AllEntities) do
		local entity_spec = GetEntitySpec(entity_name, "expect_missing")
		if entity_spec then
			local entity_states = GetStates(entity_name)
			local state_specs = entity_spec:GetSpecSubitems("StateSpec", not "inherit")
			for _, state_name in pairs(entity_states) do
				local state_spec = state_specs[state_name]
				if state_spec and state_name:sub(1, 1) ~= "_" then
					local mesh_spec = entity_spec:GetMeshSpec(state_spec.mesh)
					local anim_name = GetEntityAnimName(entity_name, state_spec.name)
					if mesh_spec.animated and (not anim_name or anim_name == "") then
						GameTestsPrintf("State %s/%s is animated but has no exported animation!", entity_name, state_spec.name)
					end
				end
			end
		end
	end
end

--- This function retrieves a list of all billboard entities in the game and prints any errors encountered.
---
--- Billboard entities are a type of entity in the game that are used to display 2D images or text overlays on the screen. This function is likely used as part of the game's testing suite to ensure that all billboard entities are properly configured and functioning.
---
--- @function GameTests.EntityBillboards
--- @return nil
function GameTests.EntityBillboards()
	GetBillboardEntities(GameTestsErrorf)
end

--- This function generates sound metadata for the game's sound assets.
---
--- It generates a sound metadata file named "sndmeta-autotest.dat" in the "svnAssets/tmp/" directory. This file likely contains information about the game's sound assets, such as file paths, sound properties, and other metadata used by the game's sound system.
---
--- This function is likely used as part of the game's testing suite to ensure that the sound metadata is properly generated and up-to-date.
---
--- @function GameTests.ValidateSounds
--- @return nil
function GameTests.ValidateSounds()
	GenerateSoundMetadata("svnAssets/tmp/sndmeta-autotest.dat") 
end

---
--- Checks for duplicate entity spots in the game.
---
--- This function iterates through all valid states for the specified entity, and checks for any duplicate spots at the same position. If any duplicate spots are found, an error message is printed with the details of the duplicates.
---
--- @param entity string The name of the entity to check for duplicate spots.
--- @return nil
function CheckEntitySpots(entity)
	local meshes = {}
	for k, state in pairs( EnumValidStates(entity) ) do
		local mesh = GetStateMeshFile(entity, state)
		if mesh and not meshes[mesh] then
			meshes[mesh] = state
		end
	end
	for mesh, state in sorted_pairs(meshes) do
		local spbeg, spend = GetAllSpots(entity, state)
		local pos_map, pos_spots = {}, {}
		local pos_list = { GetEntitySpotPos(entity, state, 0, spbeg, spend) }
		for idx=spbeg, spend do
			local pos = pos_list[idx - spbeg + 1]
			local pos_hash = point_pack(pos)
			local spot_name = GetSpotName(entity, idx)
			local annotation = GetSpotAnnotation(entity, idx) or ""
			if annotation ~= "" then
				spot_name = spot_name .. " [" .. annotation .. "]"
			end
			local spot_names = pos_spots[pos_hash] or {}
			pos_spots[pos_hash] = spot_names
			if pos_map[pos_hash] and spot_names[spot_name] then
				table.insert(spot_names[spot_name], idx)
			else
				pos_map[pos_hash] = pos
				spot_names[spot_name] = {idx}
			end
		end
		for pos_hash, spot_names in sorted_pairs(pos_spots) do
			local pos = pos_map[pos_hash]
			for spot_name, spot_index_list in sorted_pairs(spot_names) do
				if #spot_index_list > 1 then
					GameTestsErrorf("%d duplicated spots %s.%s (%s) %s: %s", #spot_index_list, entity, spot_name, mesh, tostring(pos), table.concat(spot_index_list, ","))
				end
			end
		end
	end
end

---
--- Checks for duplicate entity spots in the game.
---
--- This function iterates through all valid states for the specified entity, and checks for any duplicate spots at the same position. If any duplicate spots are found, an error message is printed with the details of the duplicates.
---
--- @param entity string The name of the entity to check for duplicate spots.
--- @return nil
function GameTests.CheckSpots()
	if not g_AllEntities then
		GameTests_LoadAnyMap()
	end
	PauseInfiniteLoopDetection("CheckSpots")
	for entity in sorted_pairs(g_AllEntities) do
		CheckEntitySpots(entity)
	end
	ResumeInfiniteLoopDetection("CheckSpots")
end

---
--- Resets the interaction random seed and resaves all presets for the "game_tests" preset group.
---
--- This function is used to test the process of resaving all presets for the "game_tests" preset group. It first resets the interaction random seed, then calls the `ResaveAllPresetsTest` function with the "game_tests" preset group as the argument.
---
--- @function GameTests.z9_ResaveAllPresetsTest
--- @return nil
function GameTests.z9_ResaveAllPresetsTest()
	ResetInteractionRand()
	ResaveAllPresetsTest("game_tests")
end
