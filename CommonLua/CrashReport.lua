local logs_folder				= "AppData/crashes"

---
--- Gathers a list of minidump files from the `logs_folder` directory, optionally filtering out files that match the `ignore_pattern`.
---
--- @param ignore_pattern string|nil A pattern to match against the filenames of the minidump files, to exclude them from the returned list.
--- @return table, table The list of minidump file paths, and the corresponding list of last modified timestamps for each file.
function GatherMinidumps(ignore_pattern)
	local err, files = AsyncListFiles(logs_folder, "*.dmp", "recursive,modified")
	if err then
		print(string.format("Crash folder enum error: %s", err))
		return
	end
	
	if ignore_pattern then
		for i = #files, 1, -1 do
			local filepath = files[i]
			local _, filename = SplitPath(filepath)
			if string.match(filename, ignore_pattern) then
				table.remove(files, i)
				table.remove(files.modified, i)
			end
		end
	end
	
	return files
end

local function check(str, what)
	return string.starts_with(str, what, true)
end
	
---
--- Parses a crash file and extracts relevant information such as the Lua revision, timestamp, CPU, GPU, thread, module, address, function, process, error, and details.
---
--- @param crash_file string The path to the crash file to parse.
--- @return string|nil An error message if there was an issue parsing the file, otherwise `nil`.
--- @return string The crash information as a formatted string.
--- @return string The crash label.
--- @return table The parsed crash information values.
--- @return number The Lua revision number.
--- @return string The crash hash.
function CrashFileParse(crash_file)
	local info = {}
	local crash_section_found, crash_section_complete
	local err, lines = AsyncFileToString(crash_file, nil, nil, "lines")
	if err then
		return err
	end
	PauseInfiniteLoopDetection("CrashFileParse")
	local crash_keys = { "Thread", "Module", "Address", "Function", "Process", "Error", "Details" }
	local header_keys = {"Lua revision", "Timestamp", "CPU", "GPU" }
	local patterns = {
		["Lua revision"] = '^Lua revision:%s*(%d+)',
		["Timestamp"] = "^Timestamp:%s*(%x+)",
		["CPU"] = "^CPU%s*(.+)",
		["GPU"] = "^GPU%s*(.+)",
	}
	local values = {}
	local _
	local bR = string.byte("R")
	local b_ = string.byte("-")
	local bkeys, hkeys = {}, {}
	for i, key in ipairs(crash_keys) do
		bkeys[i] = string.byte(key)
	end
	for i, key in ipairs(header_keys) do
		hkeys[i] = string.byte(key)
	end
	for i, line in ipairs(lines) do
		local b = string.byte(line)
		
		for i, key in ipairs(header_keys) do
			if b == hkeys[i] and check(line, key) then
				local pattern = patterns[key] or ('^' .. key .. ':%s+(.+)$')
				local value = string.match(line, pattern)
				value = value and string.trim_spaces(value)
				if value then
					value = string.gsub(value, "[\n\r]", "")
					if key == "GPU" then
						local idx = string.find_lower(value, 'Feature Level') or string.find_lower(value, '{')
						if idx then
							value = string.sub(value, 1, idx - 1)
							value = string.trim_spaces(value)
						end
					elseif key == "CPU" then
						if string.starts_with(value, 'name', true) then
							value = string.sub(value, 5)
							value = string.trim_spaces(value)
						end
					end
					info[#info + 1] = key .. ": " .. value
					values[key] = value
					table.remove(header_keys, i)
					table.remove(hkeys, i)
				end
				break
			end
		end
		
		if crash_section_complete then
			--
		elseif not crash_section_found then
			if b_ == b and check(line, "-- Exception Information") then
				crash_section_found = true
			end
		else
			if b == bR and check(line, "Registers:") or #crash_keys == 0 then
				crash_section_complete = true
			else
				for i, key in ipairs(crash_keys) do
					if b == bkeys[i] and check(line, key) then
						local value = string.match(line, '^' .. key .. ':%s+(.+)$')
						value = value and string.trim_spaces(value)
						if value then
							info[#info + 1] = key .. ": " .. value
							if key == "Thread" then
								_, value = string.match(value, '^(%d+)%s*\"(.+)\"$')
							elseif key == "Address" then
								value = string.sub(value, -4)
							end
							values[key] = value
							table.remove(crash_keys, i)
							table.remove(bkeys, i)
						end
						break
					end
				end
			end
		end
		if (#crash_keys == 0 or crash_section_complete) and (#header_keys == 0 or i > 1024) then
			break
		end
	end
	ResumeInfiniteLoopDetection("CrashFileParse")
	if not crash_section_found then
		return "Crash info not found"
	end
	local hash = xxhash(values.Address, values.Thread, values.Error, values.Details)
	local label = string.format("[Crash] @%s%s%s (%s) %s%s%s", 
		values.Address or "", values.Function and " " or "", values.Function or "",
		values.Thread or "",
		values.Error or "", values.Details and ": " or "", values.Details or "")
	local revision = values["Lua revision"]
	local revision_num = revision and tonumber(revision) or 0
	local info_str = table.concat(info, "\n")
	return nil, info_str, label, values, revision_num, hash
end

---
--- Uploads crash reports to the Mantis bug tracking system.
---
--- @param minidumps table A table of minidump file paths to upload.
---
function CrashUploadToMantis(minidumps)
	local exception_info = {}
	local min_revision = config.BugReportCrashesMinRevision or 0
	local unmount
	local function report(dump_file)
		local dump_dir, dump_name, dump_ext = SplitPath(dump_file)
		local crash_file = dump_dir .. dump_name .. ".crash"
		local err, info_str, label, values, revision_num, hash = CrashFileParse(crash_file)
		if err or not info_str or revision_num < min_revision or exception_info[hash] then
			return
		end
		exception_info[hash] = true
		if MountsByPath("memorytmp") == 0 then
			local err = MountPack("memorytmp", "", "create", 16*1024*1024)
			if err then
				print("MountPack error:", err)
				return
			end
			unmount = true
		end
		local pack_file = "memorytmp/" .. dump_name .. ".hpk"
		local pack_index = {
			{ src = dump_file, dst = dump_name .. ".dmp", },
		}
		local err, log = AsyncPack(pack_file, "", pack_index)
		if err then
			print("Pack error:", err)
			return
		end
		
		--print(os.date("%T"), ConvertToOSPath(crash_file))
		local files = { crash_file, pack_file }
		local descr = "All crash and dump files are already attached." 
		WaitXBugReportDlg(label, descr, files, {
			summary_readonly = true,
			no_screenshot = true,
			no_extra_info = true,
			append_description = "\n----\n" .. info_str,
			tags = { "Crash" },
			severity = "crash",
		})
		AsyncFileDelete(pack_file)
	end
	for _, minidump in ipairs(minidumps) do
		report(minidump)
	end
	if unmount then
		local err = UnmountByPath("memorytmp")
		if err then
			print("UnmountByPath error:", err)
			return
		end
	end
end

---
--- Uploads a minidump file asynchronously to a specified URL.
---
--- @param url string The URL to upload the minidump file to.
--- @param os_path string The local file path of the minidump file to upload.
---
function MinidumpUploadAsync(url, os_path)
	local err, json = LuaToJSON({upload_file_minidump=os_path})
	if err then
		print("Failed to convert minidump data to JSON", err)
		return
	end
	local err, info = AsyncWebRequest{
		url = url,
		method = "POST",
		headers = {["Content-Type"] = "application/json"},
		body = json,
	}
	err = err or info and info.error
	if err then
		print(string.format("Minidump upload fail: %s", err))
	end
end

---
--- Gets the crash files in the logs folder.
---
--- @param file_spec string The file specification to use when searching for crash files. Defaults to "*.crash".
--- @return table, string, number, number The list of crash files, the most recent crash file, the timestamp of the most recent crash file, and the index of the most recent crash file in the list.
---
function GetCrashFiles(file_spec)
	local _, crash_files = AsyncListFiles(logs_folder, file_spec or "*.crash", "recursive,modified")
	crash_files = crash_files or {}
	local crash_date, index = table.max(crash_files.modified)
	
	return crash_files, crash_files[index], crash_date, index
end

---
--- Empties the crash folder asynchronously.
---
--- @return boolean, string The result of the operation and any error message.
---
function EmptyCrashFolder()
	return AsyncEmptyPath(logs_folder)
end

---
--- Checks if crash reporting is enabled.
---
--- @return boolean True if crash reporting is enabled, false otherwise.
---
function CrashReportingEnabled()
	if not Platform.pc then return end
	return config.UploadMinidump or config.BugReportCrashesOnStartup
end

---
--- Renames a crash file pair (minidump and crash file) to new names.
---
--- @param minidump string The path to the existing minidump file.
--- @param new_minidump string The new name for the minidump file.
---
function RenameCrashPair(minidump, new_minidump)
	AsyncFileRename(minidump, new_minidump)
	local crash_file = string.gsub(minidump, ".dmp$", ".crash")
	local new_crash_file = string.gsub(new_minidump, ".dmp$", ".crash")
	AsyncFileRename(crash_file, new_crash_file)
end

if FirstLoad then
	g_bCrashReported = false
end

---
--- Waits for a bug report crash to occur on startup and uploads the minidump file to Mantis.
--- After the upload, the crash folder is emptied.
---
--- @return nil
---
function WaitBugReportCrashesOnStartup()
	local _, minidump = GetCrashFiles("*.dmp")
	if not minidump then return end
	CrashUploadToMantis({minidump})
	EmptyCrashFolder()
end

function OnMsg.EngineStarted()
	if not config.BugReportCrashesOnStartup or g_bCrashReported then return end
	g_bCrashReported = true
	CreateRealTimeThread(WaitBugReportCrashesOnStartup)
end

----

if FirstLoad then
	SymbolsFolders = false
	GedFolderCrashesInstance = false
	CrashCache = false
	CrashFilter = false
	CrashResolved = false
end

CrashCacheVersion = 4
local base_cache_folder = "AppData/CrashCache/"
local cache_file = base_cache_folder .. "CrashCache.bin"
local resolved_file = ConvertToBenderProjectPath("Logs/Crashes/__Resolved.lua")

CrashFolderSymbols = ConvertToBenderProjectPath("Logs/Pdbs/")
CrashFolderBender = ConvertToBenderProjectPath("Logs/Crashes")
CrashFolderSwarm = ConvertToBenderProjectPath("SwarmBackup/*/Storage/log-crash")
CrashFolderLocal = "AppData/crashes"

--- Defines a table of default groups for Swarm backup folders.
---
--- The `defaults_groups` table maps Swarm backup folder names to their corresponding group names.
--- This allows organizing Swarm backup folders into logical groups for better organization and management.
---
--- @table defaults_groups
--- @field SwarmBackup (string) The group name for Swarm backup folders.
local defaults_groups = {
	SwarmBackup = ">Swarm",
}

---
--- Defines a table of buttons for the CrashInfo class.
---
--- The `CrashInfoButtons` table contains a single button with the name "LocateSymbols" and a function "SymbolsFolderOpen" that is called when the button is clicked.
---
--- @table CrashInfoButtons
--- @field [1] (table) A table with the following fields:
---   @field name (string) The name of the button, "LocateSymbols".
---   @field func (string) The name of the function to call when the button is clicked, "SymbolsFolderOpen".
local CrashInfoButtons = {
	{name = "LocateSymbols", func = "SymbolsFolderOpen"},
}

---
--- Defines the `CrashInfo` class, which is a `PropertyObject` that contains information about a crash.
---
--- The `CrashInfo` class has the following properties:
---
--- - `Actions`: A table of buttons that can be used to perform actions on the crash information.
--- - `ExeTimestamp`: The timestamp of the executable that caused the crash.
--- - `SymbolsFolder`: The folder containing the symbols (PDBs) for the executable that caused the crash. This property has a button to open the symbols folder.
---
--- @class CrashInfo
--- @field Actions table A table of buttons that can be used to perform actions on the crash information.
--- @field ExeTimestamp string The timestamp of the executable that caused the crash.
--- @field SymbolsFolder string The folder containing the symbols (PDBs) for the executable that caused the crash.
DefineClass.CrashInfo = {
	__parents = {"PropertyObject"},
	properties = {
		{ category = "Actions", id = "Actions", editor = "buttons", default = "", buttons = CrashInfoButtons },
		
		{ category = "Crash", id = "ExeTimestamp", name = "Exe Timestamp", editor = "text", default = "" },
		{ category = "Crash", id = "SymbolsFolder", name = "Symbols Folder", editor = "text", default = "", buttons = {{name = "Open", func = "SymbolsFolderOpen"}} },
	}
}

---
--- Opens the folder containing the symbols (PDBs) for the executable that caused the crash.
---
--- This function is called when the "Open" button is clicked on the "Symbols Folder" property of the `CrashInfo` class.
---
--- @function CrashInfo:SymbolsFolderOpen
--- @return nil
function CrashInfo:SymbolsFolderOpen()
	local bdb_folder = self.SymbolsFolder
	if bdb_folder ~= 0 then
		local os_command = string.format("cmd /c start \"\" \"%s\"", bdb_folder)
		os.execute(os_command)
	end
end

---
--- Gets the cache folder for the crash information.
---
--- The cache folder is determined by the executable timestamp. If the timestamp is empty, a "Missing timestamp!" error message is returned. Otherwise, the cache folder path is constructed by combining the base cache folder and the executable timestamp.
---
--- If the cache folder does not exist, it is created asynchronously. If there is an error creating the folder, the error message is returned.
---
--- @return string|nil, string The error message if there was an error, or nil if successful. The cache folder path.
function CrashInfo:GetCacheFolder()
	local timestamp = self.ExeTimestamp
	if timestamp == "" then
		return "Missing timestamp!"
	end
	local cache_folder = base_cache_folder .. timestamp .. "/"
	if not io.exists(cache_folder) then
		local err = AsyncCreatePath(cache_folder)
		if err then
			return err
		end
	end
	return nil, cache_folder
end

---
--- Opens the log file for the selected crash object.
---
--- This function is called when the "GedFolderCrashesRun" event is triggered, passing the selected crash object as the argument.
---
--- @param get table The table containing the selected crash object.
--- @param get.selected_object CrashInfo The selected crash object.
---
function GedFolderCrashesRun(get)
	local crash = get.selected_object
	if crash then crash:OpenLogFile() end
end

---
--- Represents a group of crash reports that can be filtered and sorted.
---
--- The `FolderCrashGroup` class is used to manage a group of crash reports, providing functionality to filter and sort the reports based on various criteria such as thread, timestamp, CPU, GPU, and name. It also provides an "Export to CSV" feature to export the filtered crash reports to a CSV file.
---
--- @class FolderCrashGroup
--- @field name string The name of the crash report group.
--- @field count number The total number of crash reports in the group.
--- @field thread boolean Whether to show crash reports with a specific thread.
--- @field timestamp boolean Whether to show crash reports with a specific timestamp.
--- @field filter string The filter to apply to the crash report names.
--- @field cpu boolean Whether to show crash reports with a specific CPU.
--- @field gpu boolean Whether to show crash reports with a specific GPU.
--- @field unique boolean Whether to show only unique crash reports.
--- @field resolved boolean Whether to show resolved crash reports.
--- @field shown_count number The number of crash reports that are currently shown.
--- @field shown table A table of shown crash report names.
--- @field names table A table of unique crash report names.
--- @field timestamps table A table of unique timestamps.
--- @field threads table A table of unique threads.
--- @field cpus table A table of unique CPUs.
--- @field gpus table A table of unique GPUs.
DefineClass.FolderCrashGroup = {
	__parents = {"SortedBy", "GedFilter" },
	properties = {
		{ id = "name", editor = "text", default = "", read_only = true, buttons = {{name = "Export", func = "ExportToCSV"}} },
		{ id = "count", editor = "number", default = 0, read_only = true },
		{ id = "thread", name = "Show Thread", editor = "combo", default = false, items = function(self) return table.keys(self.threads, true) end },
		{ id = "timestamp", name = "Show Timestamp", editor = "combo", default = false, items = function(self) return table.keys(self.timestamps, true) end },
		{ id = "filter", name = "Show Name", editor = "combo", default = false, items = function(self) return table.keys(self.names, true) end },
		{ id = "cpu", name = "Show CPU", editor = "combo", default = false, items = function(self) return table.keys(self.cpus, true) end },
		{ id = "gpu", name = "Show GPU", editor = "combo", default = false, items = function(self) return table.keys(self.gpus, true) end },
		{ id = "unique", name = "Show Unique Only", editor = "bool", default = false },
		{ id = "resolved", name = "Show Resolved", editor = "bool", default = false },
		{ id = "shown_count", name = "Shown Count", editor = "number", default = 0, read_only = true },
	},
	shown = false,
	names = false,
	timestamps = false,
	threads = false,
	cpus = false,
	gpus = false,
}

---
--- Prepares the `FolderCrashGroup` object for filtering by resetting the `shown` table and `shown_count` property.
---
--- This function is called before applying filters to the crash reports in the group, to ensure that the filtering process starts with a clean slate.
---
--- @function FolderCrashGroup:PrepareForFiltering
--- @return nil
function FolderCrashGroup:PrepareForFiltering()
	self.shown = {}
	self.shown_count = 0
end

---
--- Filters an object based on the configured filters in the `FolderCrashGroup` instance.
---
--- This function is called to determine whether a crash report object should be included in the group's list of shown reports.
---
--- @param obj table The crash report object to be filtered.
--- @return boolean|nil Whether the object should be included in the shown list, or `nil` if the object should be excluded.
function FolderCrashGroup:FilterObject(obj)
	local name = obj.name
	if self.unique then
		if self.shown[name] then
			return
		end
		self.shown[name] = true
	end
	if not self.resolved and CrashResolved and CrashResolved[obj.hash] then
		return
	end
	local timestamp = self.timestamp
	if timestamp and timestamp ~= obj.ExeTimestamp then
		return
	end
	local thread = self.thread
	if thread and thread ~= obj.thread then
		return
	end
	local cpu = self.cpu
	if cpu and cpu ~= obj.CPU then
		return
	end
	local gpu = self.gpu
	if gpu and gpu ~= obj.GPU then
		return
	end
	local filter = self.filter
	if filter and filter ~= name and not string.find(name, filter) then
		return
	end
	self.shown_count = self.shown_count + 1
	return true
end

---
--- Exports the crash report data for the FolderCrashGroup to a CSV file.
---
--- The CSV file is saved in the base_cache_folder with the name of the FolderCrashGroup (without the leading ">").
--- The CSV file contains the following columns: name, thread, date, CPU, GPU, ExeTimestamp.
--- If there is an error saving the CSV file, a message is printed to the console.
--- If the CSV file is saved successfully, a message is printed to the console and the file is opened with the default text editor.
---
--- @function FolderCrashGroup:ExportToCSV
--- @return nil
function FolderCrashGroup:ExportToCSV()
	local name = string.starts_with(self.name, ">") and string.sub(self.name, 2) or self.name
	local path = base_cache_folder .. name .. ".csv"
	local err = SaveCSV(path, self, {"name", "thread", "date", "CPU", "GPU", "ExeTimestamp"}, {"name", "thread", "date", "CPU", "GPU", "Exe"})
	if err then
		print(err, "while exporting", path)
	else
		print("Exported to", path)
		OpenTextFileWithEditorOfChoice(path)
	end
end

---
--- Returns a list of sort options for the FolderCrashGroup.
---
--- The returned list contains the following sort options:
--- - "name": Sort by the name of the crash report.
--- - "timestamp": Sort by the timestamp of the crash report.
--- - "thread": Sort by the thread of the crash report.
--- - "date": Sort by the date of the crash report.
--- - "CPU": Sort by the CPU of the crash report.
--- - "GPU": Sort by the GPU of the crash report.
--- - "occurrences": Sort by the number of occurrences of the crash report.
---
--- @return table A list of sort options for the FolderCrashGroup.
function FolderCrashGroup:GetSortItems()
	return {"name", "timestamp", "thread", "date", "CPU", "GPU", "occurrences"}
end

---
--- Compares two crash reports based on the specified sort criteria.
---
--- The comparison is performed in the following order:
--- 1. If sorting by "occurrences", compare the number of occurrences.
--- 2. If sorting by "date", compare the dump timestamp.
--- 3. If sorting by "thread", compare the thread name.
--- 4. If sorting by "timestamp", compare the execution timestamp.
--- 5. If sorting by "CPU", compare the CPU name.
--- 6. If sorting by "GPU", compare the GPU name.
--- 7. If the names are different, compare the names.
--- 8. If the execution timestamps are different, compare the execution timestamps.
--- 9. If the dump timestamps are different, compare the dump timestamps.
--- 10. If the number of occurrences are different, compare the number of occurrences in descending order.
--- 11. If the GPU names are different, compare the GPU names.
--- 12. If the CPU names are different, compare the CPU names.
---
--- @param c1 table The first crash report to compare.
--- @param c2 table The second crash report to compare.
--- @param sort_by string The sort criteria to use for the comparison.
--- @return boolean True if c1 should be sorted before c2, false otherwise.
function FolderCrashGroup:Cmp(c1, c2, sort_by)
	local n1, n2 = c1.name, c2.name
	local ts1, ts2 = c1.ExeTimestamp, c2.ExeTimestamp
	local d1, d2 = c1.DmpTimestamp, c2.DmpTimestamp
	local CPU1, CPU2 = c1.CPU, c2.CPU
	local GPU1, GPU2 = c1.GPU, c2.GPU
	local o1, o2 = c1.occurrences, c2.occurrences
	
	if sort_by == "occurrences" then
		if o1 ~= o2 then
			return o1 > o2
		end
	elseif sort_by == "date" then
		if d1 ~= d2 then
			return d1 < d2
		end
	elseif sort_by == "thread" then
		local t1, t2 = c1.thread, c2.thread
		if t1 ~= t2 then
			return t1 < t2
		end
	elseif sort_by == "timestamp" then
		if ts1 ~= ts2 then
			return ts1 < ts2
		end
	elseif sort_by == "CPU" then
		if CPU1 ~= CPU2 then
			return CPU1 < CPU2
		end
	elseif sort_by == "GPU" then
		if GPU1 ~= GPU2 then
			return GPU1 < GPU2
		end
	end
	if n1 ~= n2 then
		return n1 < n2
	end
	if ts1 ~= ts2 then
		return ts1 < ts2
	end
	if d1 ~= d2 then
		return d1 < d2
	end
	if o1 ~= o2 then
		return o1 > o2
	end
	if GPU1 ~= GPU2 then
		return GPU1 < GPU2
	end
	if CPU1 ~= CPU2 then
		return CPU1 < CPU2
	end
end

--- Returns a string representation of the FolderCrashGroup object, including the name and count.
---
--- @param self FolderCrashGroup The FolderCrashGroup object.
--- @return string The string representation of the FolderCrashGroup object.
function FolderCrashGroup:GetEditorView()
	return string.format("%s  <color 128 128 128>%d</color>", self.name, self.count)
end

--- A table of button definitions for the FolderCrash class.
---
--- Each button definition is a table with the following fields:
--- - `name`: The name of the button to display.
--- - `func`: The name of the function to call when the button is clicked.
local FolderCrashButtons = {
	{name = "DebugInVS", func = "DebugDump"},
	{name = "LocateSymbols", func = "SymbolsFolderOpen"},
	{name = "OpenLog", func = "OpenLogFile"},
	{name = "Resolve", func = "ResolveCrash"},
}

--- The `FolderCrash` class represents a crash report associated with a specific folder. It inherits from the `CrashInfo` class and provides additional properties and methods for managing crash reports.
---
--- The class has the following properties:
---
--- - `Actions`: A table of button definitions for the `FolderCrash` class, where each button has a name and a corresponding function to call when clicked.
--- - `Resolved`: A boolean flag indicating whether the crash has been resolved.
--- - `ModuleName`: The name of the module associated with the crash.
--- - `LocalModuleName`: A local module name that can be used to change the symbols name if the expected PDB name does not match.
--- - `name`: The summary of the crash.
--- - `occurrences`: The number of occurrences of the crash.
--- - `date`: The date of the crash.
--- - `DmpTimestamp`: The timestamp of the crash.
--- - `thread`: The thread associated with the crash.
--- - `CPU`: The CPU information associated with the crash.
--- - `GPU`: The GPU information associated with the crash.
--- - `full_path`: The full path to the log file associated with the crash.
--- - `crash_info`: The full information about the crash.
--- - `dump_file`: The path to the dump file associated with the crash.
--- - `group`: The group associated with the crash.
--- - `values`: Additional values associated with the crash.
--- - `hash`: The hash of the crash.
---
--- The class also has a `CustomModuleName` property that can be used to override the default module name.
DefineClass.FolderCrash = {
	__parents = {"CrashInfo"},
	properties = {
		{ category = "Actions", id = "Actions", editor = "buttons", default = "", buttons = FolderCrashButtons },
		{ category = "Actions", id = "Resolved", editor = "bool", default = false, read_only = true },
		
		{ category = "Crash", id = "ModuleName", editor = "text", default = "" },
		{ category = "Crash", id = "LocalModuleName", editor = "text", default = "", help = "Use it to change the symbols name locally, if the expected PDB name do not match" },
		
		{ category = "Crash", id = "name", name = "Summary", editor = "text", default = "" },
		{ category = "Crash", id = "occurrences", name = "Occurrences", editor = "number", default = 0, },
		{ category = "Crash", id = "date", name = "Dmp Date", editor = "text", default = "" },
		{ category = "Crash", id = "DmpTimestamp", name = "Dmp Timestamp", editor = "number", default = 0 },
		{ category = "Crash", id = "thread", editor = "text", default = "" },
		{ category = "Crash", id = "CPU", editor = "text", default = "" },
		{ category = "Crash", id = "GPU", editor = "text", default = "" },
		{ category = "Crash", id = "full_path", name = "Log Path", editor = "text", default = "", buttons = {{name = "Open", func = "OpenLogFile"}}, },
		{ category = "Crash", id = "crash_info", name = "Full Info", editor = "text", default = "", max_lines = 30, lines = 10, },
		
		{ category = "Crash", id = "dump_file", name = "text", editor = "text", default = "", no_edit = true, },
		{ category = "Crash", id = "group", name = "text", editor = "text", default = "", no_edit = true, },
		{ category = "Crash", id = "values", editor = "prop_table", default = false, no_edit = true, },
		{ category = "Crash", id = "hash", editor = "number", default = false, no_edit = true, },
	},
	StoreAsTable = true,
	CustomModuleName = false,
}

--- Saves the resolved crashes to a file.
---
--- This function is called after a crash has been resolved to persist the resolved state.
--- It converts the `CrashResolved` table to Lua code and writes it to the `resolved_file`.
--- If there is an error writing the file, a message is printed.
function WaitSaveCrashResolved()
	local code = pstr("return ", 1024)
	TableToLuaCode(CrashResolved, nil, code)
	local err = AsyncStringToFile(resolved_file, code)
	if err then
		print("once", "Failed to save the resolved crashes to", resolved_file, ":", err)
	end
end

--- Returns the raw module name from the crash information.
---
--- The raw module name is extracted from the `Module` field in the `values` table of the `FolderCrash` object. If the `Module` field is empty, an empty string is returned.
---
--- @return string The raw module name.
function FolderCrash:GetModuleNameRaw()
	local module_file = self.values and self.values.Module
	if (module_file or "") == "" then
		return ""
	end
	local module_dir, module_name, module_ext = SplitPath(module_file)
	return module_name
end

--- Returns the module name to use for the crash.
---
--- If `CustomModuleName` is set, it is returned. Otherwise, the raw module name from `GetModuleNameRaw()` is returned.
---
--- @return string The module name to use for the crash.
function FolderCrash:GetModuleName()
	if (self.CustomModuleName or "") ~= "" then
		return self.CustomModuleName
	end
	return self:GetModuleNameRaw()
end

--- Sets the custom module name for the crash.
---
--- If `module_name` is not empty and is different from the raw module name returned by `GetModuleNameRaw()`, it is set as the `CustomModuleName` property. Otherwise, `CustomModuleName` is set to `nil`.
---
--- @param module_name string The custom module name to set.
function FolderCrash:SetModuleName(module_name)
	self.CustomModuleName = (module_name or "") ~= "" and module_name ~= self:GetModuleNameRaw() and module_name or nil
end

--- Returns whether the crash has been resolved.
---
--- This function checks if the crash has been resolved by looking up the crash hash in the `CrashResolved` table. If the hash is found, the crash is considered resolved.
---
--- @return boolean True if the crash has been resolved, false otherwise.
function FolderCrash:GetResolved()
	return CrashResolved and CrashResolved[self.hash]
end

--- Resolves a crash by marking it as resolved in the `CrashResolved` table.
---
--- If the crash has already been resolved, a message is printed and the function returns.
---
--- If the user confirms the resolution, the crash hash is added to the `CrashResolved` table with the crash name and execution timestamp. A delayed call is made to `WaitSaveCrashResolved` to save the resolved crashes.
---
--- @param root table The root table or object containing the crash information.
--- @param prop_id string The property ID of the crash.
--- @param ged table The GED (Graphical Editor) object.
function FolderCrash:ResolveCrash(root, prop_id, ged)
	if self:GetResolved() then
		print(self.name, "is already resolved")
		return
	end
	if ged:WaitQuestion("Resolve", string.format("Mark crash \"%s\" as resolved?", self.name), "Yes", "No") ~= "ok" then
		return
	end
	CrashResolved = CrashResolved or {}
	CrashResolved[self.hash] = self.name .. " " .. self.ExeTimestamp
	DelayedCall(0, WaitSaveCrashResolved)
end

--- Returns a formatted string representing the crash information, with the crash name and relevant details.
---
--- If the crash has been resolved, the name is displayed in a gray color. Otherwise, the name is displayed in the default color.
---
--- The returned string includes the following information:
--- - Crash name
--- - Execution timestamp
--- - CPU information
--- - GPU information
---
--- @return string The formatted crash information string.
function FolderCrash:GetEditorView()
	local resolved = self:GetResolved()
	local color_start = resolved and "RESOLVED <color 128 128 128>" or ""
	local color_end = resolved and "</color>" or ""
	return string.format("<style GedMultiLine>%s%s%s <color 64 128 196>%s</color> <color 64 196 128>%s</color> <color 196 128 64>%s</color></style>",
		color_start, self.name, color_end, self.ExeTimestamp, self.CPU, self.GPU)
end

--- Opens the log file associated with the current crash.
---
--- If the `full_path` property of the `FolderCrash` object is not empty, this function opens the log file using the default text editor.
---
--- @function FolderCrash:OpenLogFile
--- @return nil
function FolderCrash:OpenLogFile()
	local full_path = self.full_path or ""
	if full_path ~= "" then
		OpenTextFileWithEditorOfChoice(full_path)
	end
end

--- Copies symbol files from a source folder to a cache folder for a specified module.
---
--- @param cache_folder string The path to the cache folder where the symbol files will be copied.
--- @param src_folder string The path to the source folder containing the symbol files.
--- @param module_name string The name of the module for which the symbol files are being copied.
--- @param local_name string The local name of the module, which may be different from the module name.
--- @return string|nil An error message if the operation fails, or nil if successful.
function CopySymbols(cache_folder, src_folder, module_name, local_name)
	if (module_name or "") == "" then
		return "Invalid param!"
	end
	if (local_name or "") == "" then
		local_name = module_name
	end
	local pdbfile = cache_folder .. local_name .. ".pdb"
	if io.exists(pdbfile) then
		print("Using locally cached", pdbfile)
		return
	end
	if src_folder == "" then
		return "Symbols folder not found!"
	end
	local err, files = AsyncListFiles(src_folder, module_name .. ".*")
	if err then
		return print_format("Failed to list", src_folder, ":", err)
	end
	for _, file in ipairs(files) do
		local file_dir, file_name, file_ext =  SplitPath(file)
		local dest = cache_folder .. local_name .. file_ext
		print("Copying", file, "to", dest)
		local err = AsyncCopyFile(file, dest, "raw")
		if err then
			return print_format("Failed to copy", file, ":", err)
		end
	end
	if not io.exists(pdbfile) then
		return print_format("No symbols found at", src_folder)
	end
end

--- Dumps the crash report for the specified module.
---
--- This function is responsible for copying the crash dump file to a local cache folder, copying the associated symbol files, and then opening the crash folder browser to view the dump.
---
--- @param self FolderCrash The FolderCrash instance.
--- @return nil
function FolderCrash:DebugDump()
	if not Platform.pc then
		print("Supported on PC only!")
		return
	end
	local err
	local module_name = self:GetModuleName() or ""
	if module_name == "" or string.lower(module_name) == "unknown" then
		print("Invalid module name!")
		return
	end
	local err, cache_folder = self:GetCacheFolder()
	if err then
		print("Failed to create working directory:", err)
		return
	end
	local orig_dump_file = self.dump_file
	local orig_dump_dir, dump_name, dump_ext = SplitPath(orig_dump_file)
	local dump_file = cache_folder .. dump_name .. dump_ext
	if not io.exists(dump_file) then
		if not io.exists(orig_dump_file) then
			print("No dump pack found!")
			return
		end
		local err = AsyncCopyFile(orig_dump_file, dump_file, "raw")
		if err then
			print("Failed to copy", orig_dump_file, ":", err)
			return
		end
	end
	local err = CopySymbols(cache_folder, self.SymbolsFolder, module_name, self.LocalModuleName)
	if err then
		print("Copy symbols error:", err)
		return
	end
	local os_path = ConvertToOSPath(dump_file)
	local os_command = string.format("cmd /c start \"\" \"%s\"", os_path)
	os.execute(os_command)
end

--- Fetches the list of symbol folders from the CrashFolderSymbols directory.
---
--- This function is responsible for retrieving the list of symbol folders from the CrashFolderSymbols directory and storing them in the SymbolsFolders global variable.
---
--- @return nil
function FetchSymbolsFolders()
	local err
	local st = GetPreciseTicks()
	err, SymbolsFolders = AsyncListFiles(CrashFolderSymbols, "*", "folders")
	if err then
		print("Failed to fetch symbols folders from Bender:", err)
		SymbolsFolders = {}
	end
	print(#SymbolsFolders, "symbol folders found in", GetPreciseTicks() - st, "ms at", CrashFolderSymbols)
end

--- Resolves the symbol folder for the given timestamp.
---
--- This function searches the list of symbol folders stored in the `SymbolsFolders` global variable and returns the folder that ends with the given timestamp.
---
--- @param timestamp string The timestamp to search for.
--- @return string|nil The symbol folder path, or `nil` if not found.
function ResolveSymbolsFolder(timestamp)
	if (timestamp or "") == "" then
		return
	end
	assert(SymbolsFolders)
	for _, folder in ipairs(SymbolsFolders) do
		if string.ends_with(folder, timestamp, true) then
			return folder
		end
	end
end

--- Opens the crash folder browser at the specified location and timestamp.
---
--- This function creates a new real-time thread that calls `WaitOpenCrashFolderBrowser` with the provided `location` and `timestamp` arguments. It is responsible for opening the crash folder browser and displaying the crash information.
---
--- @param location string The location of the crash folder to open.
--- @param timestamp string The timestamp of the crash to focus on.
--- @return nil
function OpenCrashFolderBrowser(location, timestamp)
	CreateRealTimeThread(WaitOpenCrashFolderBrowser, location, timestamp)
end

---
--- Waits for the crash folder browser to open and displays the crash information.
---
--- This function is responsible for fetching the list of symbol folders, loading the crash cache and resolved crash data, and then processing the crash files in the specified location. It creates a new `FolderCrashGroup` for each group of crashes and adds the crashes to the appropriate groups. The function then opens the GED app to display the crash information.
---
--- @param location string|table The location or list of locations of the crash folders to open.
--- @param timestamp string The timestamp of the crash to focus on.
--- @return nil
function WaitOpenCrashFolderBrowser(location, timestamp)
	print("Opening crash folder browser at", location)
	FetchSymbolsFolders()
	if not CrashCache then
		local err, str = AsyncFileToString(cache_file)
		if not err then
			CrashCache = dostring(str)
		end
		if not CrashCache or CrashCache.version ~= CrashCacheVersion then
			CrashCache = { version = CrashCacheVersion }
		end
	end
	if not CrashResolved then
		local err, str = AsyncFileToString(resolved_file)
		if not err then
			CrashResolved = dostring(str)
		end
		if not CrashResolved then
			CrashResolved = {}
		end
	end
	local to_read, to_delete = {}, {}
	local to_delete_count = 0
	local groups = {}
	local total_count = 0
	local function AddCrashTo(crash, crash_name, group_name)
		local group = groups[group_name]
		if not group then
			group = FolderCrashGroup:new{ name = group_name }
			groups[group_name] = group
			groups[#groups + 1] = group
		end
		group[#group + 1] = crash
	end
	local skipped = 0
	local function AddCrash(crash, group_name)
		if timestamp and timestamp ~= crash.ExeTimestamp then
			skipped = skipped + 1
			return
		end
		AddCrashTo(crash, crash.name, crash.group)
		AddCrashTo(crash, crash.name, ">All")
		total_count = total_count + 1
	end
	local created = 0
	local read = 0
	local function ReadCrash(info)
		read = read + 1
		local crashfile, folder = info[1], info[2]
		local file_dir, file_name, file_ext = SplitPath(crashfile)
		local dump_file = file_dir .. file_name .. ".dmp"
		local err, info, label, values, revision_num, hash, DmpTimestamp
		err, DmpTimestamp = AsyncGetFileAttribute(dump_file, "timestamp")
		if err then
			print(err, "while getting timestamp of", dump_file)
		else
			err, info, label, values, revision_num, hash = CrashFileParse(crashfile)
			if err then
				print(err, "error while reading", crashfile)
			end
		end
		if err then
			to_delete_count = to_delete_count + 1
			to_delete[#to_delete + 1] = crashfile
			to_delete[#to_delete + 1] = dump_file
			return
		end
		local group_name = string.sub(file_dir, #folder + 2)
		if group_name == "" then
			group_name = ">Ungrouped"
			for pattern, name in pairs(defaults_groups) do
				if file_dir:find(pattern) then
					group_name = name
					break
				end
			end
		else
			group_name = group_name:sub(1, -2)
			group_name = group_name:gsub("\\", "/")
		end
		local crash = FolderCrash:new{
			dump_file = dump_file,
			group = group_name,
			folder = file_dir,
			name = label,
			full_path = crashfile,
			crash_info = info,
			date = os.date("%y/%m/%d %H:%M:%S", DmpTimestamp),
			DmpTimestamp = DmpTimestamp,
			ExeTimestamp = values.Timestamp,
			SymbolsFolder = ResolveSymbolsFolder(values.Timestamp),
			CPU = values.CPU,
			GPU = values.GPU,
			thread = values.Thread,
			values = values,
			hash = hash,
		}
		CrashCache[crashfile] = crash
		AddCrash(crash)
		created = created + 1
		if read % 100 == 0 then
			print(#to_read - read, "remaining...")
		end
	end
	
	local folders
	if type(location) == "string" then
		folders = { location }
	elseif type(location) == "table" then
		folders = location
	else
		folders = { CrashFolderBender }
	end
	print("Fetching folder structure...")
	while true do
		local found
		for i=#folders,1,-1 do
			local folder = folders[i]
			local star_i = folder:find_lower("*")
			if star_i then
				found = true
				table.remove(folders, i)
				local base = folder:sub(1, star_i - 1)
				local sub = folder:sub(star_i + 1)
				local err, subfolders = AsyncListFiles(base, "*", "folders")
				if err then
					print("Failed to fetch issues from", base, ":", err)
				else
					for _, subfolder in ipairs(subfolders) do
						local f1 = subfolder .. sub
						if io.exists(f1) then
							folders[#folders + 1] = f1
						end
					end
				end
			end
		end
		if not found then
			break
		end
	end
	for _, folder in ipairs(folders) do
		if folder:ends_with("/") or folder:ends_with("\\") then
			folder = folder:sub(1, -2)
		end
		local st = GetPreciseTicks()
		local err, files = AsyncListFiles(folder, "*.crash", "recursive")
		if err then
			printf("Failed to fetch issues (%s) from '%s'", err, folder)
		else
			printf("%d crashes found in '%s'", #files, folder)
			for i, crashfile in ipairs(files) do
				local group_name
				local cache = CrashCache[crashfile]
				if cache then
					AddCrash(cache)
				else
					to_read[#to_read + 1] = { crashfile, folder }
				end
			end
		end
	end
	local st = GetPreciseTicks()
	parallel_foreach(to_read, ReadCrash)
	table.sortby_field(groups, "name")
	for _, group in ipairs(groups) do
		local names, timestamps, threads, gpus, cpus = {}, {}, {}, {}, {}
		group.names = names
		group.timestamps = timestamps
		group.threads = threads
		group.gpus = gpus
		group.cpus = cpus
		for _, crash in ipairs(group) do
			local name = crash.name
			names[name] = (names[name] or 0) + 1
			timestamps[crash.ExeTimestamp] = true
			threads[crash.thread] = true
			gpus[crash.GPU] = true
			cpus[crash.CPU] = true
		end
		for _, crash in ipairs(group) do
			crash.occurrences = names[crash.name]
		end
		group:Sort()
		group.count = #group
	end
	print("Crashes processed:", total_count, ", skipped:", skipped, ", time:", GetPreciseTicks() - st, "ms")
	if created > 0 then
		local code = pstr("return ", 1024)
		TableToLuaCode(CrashCache, nil, code)
		AsyncCreatePath(base_cache_folder)
		local err = AsyncStringToFile(cache_file, code, -2, 0, "zstd")
		if err then
			print("once", "Failed to save the crash cache to", cache_file, ":", err)
		end
	end
	local ged = OpenGedAppSingleton("GedFolderCrashes", groups)
	ged:SetSelection("root", { 1 }, nil, not "notify")
	if to_delete_count > 0 then
		if "ok" == WaitQuestion(terminal.desktop, "Warning", string.format("Confirm removal of %s invalid crash files?", to_delete_count)) then
			local err = AsyncFileDelete(to_delete)
			if err then
				print(err, "while deleting invalid crash files!")
			else
				print(to_delete_count, "invalid crash files removed.")
			end
		end
	end
end
