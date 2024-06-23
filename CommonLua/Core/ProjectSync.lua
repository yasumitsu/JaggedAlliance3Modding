if not FirstLoad or not Platform.ios or not Platform.developer then return end

local Updating = true
local FolderSyncRequests = 0
local OriginalLuaAllocLimit = 0
local SyncStart = 0
local DownloadedFiles = {}
local DeletedFiles = {}

---
--- Uploads a file to the remote server in parts.
---
--- @param filepath string The path of the file to upload.
--- @param part integer The current part number of the file being uploaded.
--- @param all_parts integer The total number of parts the file is divided into.
--- @param part_size integer The size of the current part in bytes.
--- @param total_size integer The total size of the file in bytes.
--- @param max_part_size integer The maximum size of each part in bytes.
---
luadebugger.UploadFile = function(self, filepath, part, all_parts, part_size, total_size, max_part_size)
    self.binary_mode = true
    self.binary_handler = function(data)
        self.binary_mode = false
        CreateRealTimeThread(function()
            local data_size = string.len(data)
            if (part_size ~= string.len(data)) then
                print(string.format("[Error] Invalid packet size - %d KB, (expected %d KB)", data_size / 1024,
                    part_size / 1024))
                return
            end
            if part + 1 == all_parts then
                DownloadedFiles[#DownloadedFiles + 1] = filepath
            end
            if all_parts > 1 then
                print(string.format("[downloaded part %d/%d (%d/%d KB)] %s ", (part + 1), all_parts,
                    (part * max_part_size + part_size) / 1024, total_size / 1024, filepath))
            else
                print(string.format("[downloaded %d KB] %s ", ((string.len(data)) / 1024), filepath))
            end
            local folder = SplitPath(filepath)
            if folder ~= "" and not io.exists(folder) then
                print("Create folder: ", folder)
                io.createpath(folder)
            end
            local mode = part > 0 and "a" or "w"
            local f, err = io.open(filepath, mode)
            if f then
                f:write(data);
                f:close()
            else
                print("[Error] ", err);
            end
        end)
    end
end

---
--- Deletes a file from the local file system.
---
--- @param filepath string The path of the file to delete.
---
luadebugger.DeleteFile = function(self, filepath)
    local ok, err = os.remove(filepath)
    if not ok and err == "File Not Found" then
        print("[Warning] File not found when trying to delete! " .. filepath);
        ok = true
        err = false
    end
    if ok then
        print(string.format("[deleted] %s ", filepath))
        DeletedFiles[#DeletedFiles + 1] = filepath
    end
end

---
--- Requests a folder sync operation with the remote debugger.
---
--- @param folder string The local folder path to sync.
--- @param remote_folder string The remote folder path to sync to.
--- @param recursive boolean Whether to sync the folder recursively.
---
luadebugger.RequestFolderSync = function(self, folder, remote_folder, recursive)
    local info = {}
    local files = io.listfiles(folder, "*", recursive)
    for fi = 1, #files do
        local file = files[fi]
        info[file:sub(folder:len() + 1)] = io.getmetadata(file, "modification_time")
    end
    -- print(info)
    FolderSyncRequests = FolderSyncRequests + 1
    self:Send({Event="RequestFolderSync", LocalFolder=folder, LocalFiles=info, Recursive=recursive,
        RemoteFolder=remote_folder})
end

---
--- Callback function that is called when a folder sync operation has completed.
---
--- This function is called by the `luadebugger` module when a folder sync operation has finished.
--- It decrements the `FolderSyncRequests` counter and checks if all sync requests have completed.
--- If so, it restores the original `config.ReportLuaAlloc` value and sets `Updating` to `false`.
--- It also prints the total time taken for the project sync operation.
---
--- @function luadebugger.FolderSynced
--- @param self table The `luadebugger` module instance.
luadebugger.FolderSynced = function(self)
    CreateRealTimeThread(function()
        FolderSyncRequests = FolderSyncRequests - 1
        if (FolderSyncRequests <= 0) then
            config.ReportLuaAlloc = OriginalLuaAllocLimit
            Updating = false
            print(string.format("Project synced in %d s", (GetPreciseTicks() - SyncStart) / 1000))
        end
    end)
end

---
--- Requests a project sync operation with the remote debugger.
---
--- This function is responsible for syncing the local "AppData/Build" folder with the remote build folder on the debugger server.
--- It first saves the original `config.ReportLuaAlloc` value, then sets it to 0 to disable Lua allocation reporting during the sync.
--- It then calls `g_LuaDebugger:RequestFolderSync()` to initiate the sync operation, passing the local and remote folder paths.
--- The function returns `true` if the sync operation was started successfully, or `false` if there is no debugger available.
---
--- @return boolean true if the sync operation was started, false otherwise
function ProjectSync()
    if g_LuaDebugger then
        SyncStart = GetPreciseTicks()

        OriginalLuaAllocLimit = config.ReportLuaAlloc
        config.ReportLuaAlloc = 0
        local remote_build_folder = string.format("%s\\Build\\%s", config.Haerald.ProjectAssetsPath, GetPlatformName())
        g_LuaDebugger:RequestFolderSync("AppData/Build", remote_build_folder, "recursive")
        return true;
    else
        print("Project sync skipped - no debugger")
        return false
    end
end

---
--- Initializes the remote debugger and starts the project sync process.
---
--- This function is responsible for setting up the remote debugger and initiating the project sync operation.
--- It first checks if the `config.Haerald` table exists, and if not, it creates it and populates it with settings from the bundle.
--- It then sets the `config.Haerald.platform` to the current platform name.
--- Next, it calls `SetupRemoteDebugger()` to configure the remote debugger with the appropriate IP address, remote root, and project folder.
--- Finally, it calls `StartDebugger()` to start the debugger, and then calls `ProjectSync()` to initiate the project sync operation.
--- If the project sync operation fails to start, it sets `Updating` to `false`.
---
--- @function CreateRealTimeThread
--- @return boolean true if the project sync operation was started, false otherwise
CreateRealTimeThread(function()
    if Platform.ios and not config.Haerald then
        config.Haerald = {}
        config.Haerald.ip = GetBundleSetting("HaeraldIP")
        config.Haerald.RemoteRoot = GetBundleSetting("RemoteRoot")
        config.Haerald.ProjectFolder = GetBundleSetting("ProjectFolder")
    end
    config.Haerald.platform = GetPlatformName()
    SetupRemoteDebugger(config.Haerald.ip or "localhost", config.Haerald.RemoteRoot or "",
        config.Haerald.ProjectFolder or "")
    StartDebugger()
    local started = ProjectSync()
    if not started then
        Updating = false
    end
end)

while(Updating) do
	local t = GetPreciseTicks()
	AdvanceThreads(t)
	os.sleep(10)
end

---
--- Remounts all downloaded packs.
---
--- This code iterates through the `DownloadedFiles` table and checks if each file has the extension "Lua.hpk". If a file with this extension is found, it notifies the user that Lua boot changes will not be available in this run and a restart is required.
---
--- @param DownloadedFiles table A table of downloaded file paths
---
for i = 1, #DownloadedFiles do
    local filepath = DownloadedFiles[i]
    if filepath:find("Lua.hpk") then
        -- notify user that lua boot changes will not be available
        -- this run. Restart is required for them.
    end
end

-- unmount and mount again all packs
if #DownloadedFiles > 0 then
	print("Remounting all packs...")
	dofile("mount.lua") 
end
