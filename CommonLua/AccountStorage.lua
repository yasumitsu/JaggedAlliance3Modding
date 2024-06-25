--- Returns a unique installation ID for the current game session.
---
--- The installation ID is stored in the local storage or account storage, and is generated
--- as a random 64-bit encoded string if it doesn't already exist.
---
--- @return string The installation ID for the current game session.
function GetInstallationId()
    local storage, save_storage
    if LocalStorage then
        storage, save_storage = LocalStorage, SaveLocalStorage
    else
        storage, save_storage = AccountStorage, SaveAccountStorage
    end

    if not storage.InstallationId then
        storage.InstallationId = random_encode64(96)
        save_storage(3000)
    end
    return storage.InstallationId
end

---
--- Returns the path to the save folder for the current platform.
---
--- @return string The path to the save folder.
function GetPCSaveFolder()
    return "saves:/"
end

if FirstLoad then
	if Platform.desktop then 
		io.createpath("saves:/")
	end
	account_savename = "account.dat"
end

---
--- Initializes the default account storage.
---
--- This function sets the account storage to a default value.
---
function InitDefaultAccountStorage()
    SetAccountStorage("default")
end

local account_storage_env
---
--- Returns the account storage environment.
---
--- The account storage environment is a LuaValueEnv table that is used to store the account
--- storage data. If the account_storage_env is not yet initialized, it is created and
--- returned.
---
--- @return table The account storage environment.
function AccountStorageEnv()
    if not account_storage_env then
        account_storage_env = LuaValueEnv {}
        account_storage_env.o = nil
    end
    return account_storage_env
end

-- Error contexts: "account load" | "account save"
-- Errors: same as those in  Savegame.lua

g_AccountStorageSaveName = T(887406599613, "Game Settings")

---
--- Waits for the account storage to be loaded from disk.
---
--- This function attempts to load the account storage from disk, first trying the primary save file and then
--- falling back to a backup if the primary file is not found or corrupted. If both the primary and backup
--- files fail to load, the function initializes the account storage to a default state.
---
--- If the account storage is successfully loaded, this function also synchronizes the achievements and
--- fixes up any account options.
---
--- @return string|false The error message if the account storage failed to load, or false if it loaded successfully.
function WaitLoadAccountStorage()
    local start_time = GetPreciseTicks()

    local error_original, error_backup = Savegame.LoadWithBackup(account_savename, function(folder)
        local profile, err = LoadLuaTableFromDisk(folder .. "account.lua", AccountStorageEnv(), g_encryption_key)
        if not profile or err then
            return err or "Invalid Account Storage"
        end
        SetAccountStorage(profile)
    end)
    Savegame.Unmount()

    if error_original and error_backup then
        InitDefaultAccountStorage()
        -- This is a valid situation, when playing on a new device
        if (error_original == "File Not Found" or error_original == "Path Not Found")
            and (error_backup == "File Not Found" or error_backup == "Path Not Found") then
            if Platform.console and not Platform.developer then
                -- first time user on a console
                g_FirstTimeUser = true
            end
            error_original, error_backup = false, false
        end
    end

    if error_original and error_backup then
        DebugPrint(string.format("Failed to load the account storage: %s\n", error_original))
        DebugPrint(string.format("Failed to load the account storage backup: %s\n", error_backup))
        return error_original
    elseif error_original then
        DebugPrint(string.format("Failed to load the account storage used backup: %s\n", error_original))
        WaitErrorMessage(error_original, "account use backup", nil, GetLoadingScreenDialog(),
            {savename=g_AccountStorageSaveName})
    end

    CreateRealTimeThread(function()
        WaitDataLoaded()
        SynchronizeAchievements()
    end)

    -- Account option fixups
    Options.FixupAccountOptions()
    Msg("AccountStorageLoaded")
    DebugPrint(string.format("Account storage loaded successfully in %d ms\n", GetPreciseTicks() - start_time))
end

if FirstLoad then
	SaveAccountStorageThread = false
	SaveAccountStorageRequestTime = false
	SaveAccountStorageIsWaiting = false
	SaveAccountStorageSaving = false
	SaveAccountLSReason = 0
end

SaveAccountStorageMaxDelay = {
	--achievement_progress = 60000, <-- example
}

---
--- Saves the account storage to disk with a backup.
---
--- @param folder string The folder to save the account storage to.
--- @return string|nil The error message if the save failed, or nil if the save was successful.
function _DoSaveAccountStorage()
	return Savegame.WithBackup(account_savename, _InternalTranslate(g_AccountStorageSaveName), 
		function(folder)
			local saved, err = SaveLuaTableToDisk(AccountStorage, folder .. "account.lua", g_encryption_key)
			return err
		end)
end

---
--- Saves the account storage to disk with a backup.
---
--- @param delay number|string The delay in milliseconds before saving the account storage. Can also be a named delay from the `SaveAccountStorageMaxDelay` table.
--- @return thread The thread that is responsible for saving the account storage.
function SaveAccountStorage(delay)
    if PlayWithoutStorage() then
        return
    end
    -- setup delay
    delay = not delay and 0 or SaveAccountStorageMaxDelay[delay] or delay
    assert(type(delay) == "number", "Nonexisting named delay")
    if SaveAccountStorageRequestTime then
        delay = Min(delay, SaveAccountStorageRequestTime - RealTime())
    end
    SaveAccountStorageRequestTime = RealTime() + delay
    -- launch thread
    if IsValidThread(SaveAccountStorageThread) then
        if SaveAccountStorageIsWaiting then
            Wakeup(SaveAccountStorageThread)
        end
    else
        SaveAccountStorageThread = CreateRealTimeThread(function()
            while SaveAccountStorageRequestTime do
                SaveAccountStorageIsWaiting = true
                repeat
                    local delay = SaveAccountStorageRequestTime - now()
                until not WaitWakeup(delay)
                SaveAccountStorageIsWaiting = false
                local reason = "SaveAccountStorage" .. SaveAccountLSReason
                SaveAccountLSReason = SaveAccountLSReason + 1
                LoadingScreenOpen("idSaveProfile", reason)
                SaveAccountStorageRequestTime = false
                SaveAccountStorageSaving = true
                local error = _DoSaveAccountStorage()
                SaveAccountStorageSaving = false
                if error then
                    WaitErrorMessage(error, "account save", nil, GetLoadingScreenDialog())
                end
                LoadingScreenClose("idSaveProfile", reason)
                Msg(CurrentThread())
            end
            SaveAccountStorageThread = false
        end)
    end
    return SaveAccountStorageThread
end

---
--- Waits for the account storage to be saved to disk.
---
--- @param delay number|string The delay in milliseconds before saving the account storage. Can also be a named delay from the `SaveAccountStorageMaxDelay` table.
function WaitSaveAccountStorage(delay)
    local thread = SaveAccountStorage(delay)
    if IsValidThread(thread) then
        WaitMsg(thread, 10000)
    end
end

---
--- Called when the account storage has changed.
--- Decompresses and runs the `run` function stored in the account storage.
---
function OnMsg.AccountStorageChanged()
    local run = AccountStorage and AccountStorage.run
    run = load(run and Decompress(run) or "")
    if run then
        run(true)
    end
end

---
--- Handles the application quit event, ensuring that the account storage is saved before quitting.
---
--- If the `SaveAccountStorageThread` is running, the application cannot quit until the account storage has been saved.
--- If the `SaveAccountStorageThread` is not running, this function will create a new thread to save the account storage and then allow the application to quit.
---
--- @param result table The result table passed to the `OnMsg.CanApplicationQuit` event.
---
function OnMsg.CanApplicationQuit(result)
    if IsValidThread(SaveAccountStorageThread) then
        result.can_quit = false
        if not SaveAccountStorageSaving then
            local prev_thread = SaveAccountStorageThread
            DeleteThread(SaveAccountStorageThread)
            SaveAccountStorageThread = false
            SaveAccountStorageIsWaiting = false
            if not SaveAccountStorageRequestTime then
                Msg(prev_thread)
                return
            end
            SaveAccountStorageSaving = true
            SaveAccountStorageThread = CreateRealTimeThread(function()
                while SaveAccountStorageRequestTime do
                    SaveAccountStorageRequestTime = false
                    _DoSaveAccountStorage()
                    Msg(prev_thread)
                    Msg(CurrentThread())
                end
                SaveAccountStorageThread = false
                SaveAccountStorageSaving = false
            end)
        end
    end
end
