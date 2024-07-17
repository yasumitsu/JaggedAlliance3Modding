if FirstLoad then
	g_SelectedMod = false
	g_FocusedModPreset = false
end

--update the idSubMenuTittleDescr text in the MainMenu template
---
--- Updates the count of installed and enabled mods in the UI.
---
--- @param host table The dialog host object.
---
function UpdateModsCount(host)
	CreateRealTimeThread(function(host)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		if not g_ModsUIContextObj then
			assert(g_ModsUIContextObj, "To use this func make sure mods info is received.")
			return 0, 0
		end
		local totalInstalledNum = #g_ModsUIContextObj.installed_mods or 0
		local totalEnabledNum = 0
		
		for _, isEnabled in pairs(g_ModsUIContextObj.enabled) do
			if isEnabled then
				totalEnabledNum = totalEnabledNum + 1
			end
		end
		
		host:ResolveId("idSubMenuTittleDescr"):SetText(T{924426761490, "<style MMMultiplayerModsCount><totalNum></style> mods / <style MMMultiplayerModsCount><enabledNum></style> enabled", totalNum = totalInstalledNum, enabledNum = totalEnabledNum})
		host:ResolveId("idSubMenuTittleDescr"):SetVisible(true)
	end, host)
end

--show the mod info in the most right menu in the mod editor
---
--- Shows detailed information about a selected mod in the mod editor.
---
--- @param dlg table The dialog object containing the mod information.
---
function ShowModInfo(dlg)
	CreateRealTimeThread(function(dlg)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		
		local modContext = GetDialogModeParam(dlg)
		assert(modContext, "Missing context for the selected mod")
		assert(dlg.Mode == "mod")
		
		dlg.idImage:SetImage(modContext.Thumbnail)
		dlg.idEnabled:SetVisible(not not table.find(AccountStorage.LoadMods, modContext.ModID))
		dlg.idModTitle:SetText(Literal(modContext.DisplayName))
		dlg.idAuthorName:SetText(modContext.Author)
		dlg.idVersion:SetText(modContext.ModVersion or _InternalTranslate(T(77, "Unknown")))
		local rawDescr = g_ModsUIContextObj.mod_defs[modContext.ModID].description
		rawDescr = ParseSteam(rawDescr or "", {
			Heading1TextStyle = "ModDescription_Heading1",
			Heading2TextStyle = "ModDescription_Heading2",
			Heading3TextStyle = "ModsDescription_Heading3",
			NormalTextStyle = "ModDescription",
			ItalicTextStyle = "ModDescription", -- TODO: missing?
			BoldTextStyle = "ModDescription_Bold",
			HyperlinkTextStyle = "ModDescription_Hyperlink",
			CodeTextStyle = "ModDescription", -- TODO: missing?
			AllowUrl = false,
		})
		dlg.idDescrText:SetText(rawDescr and rawDescr ~= "" and rawDescr or _InternalTranslate(T(492159285354, "No description")))
		local requiredMods = GetModDependencies(modContext)
		if requiredMods then
			dlg.idRequiredMods:SetVisible(true)
			dlg.idListMods:SetText(requiredMods)
		end
		if dlg.idExternalLinks then
			local links = table.copy(modContext.ExternalLinks)
			for idx, link in ipairs(links) do
				local r, g, b = GetRGBA(GameColors.Yellow)
				links[idx] = string.format("<h %s %s %s %s underline>%s</h>", link, r, g, b, link)
			end
			if next(links) then
				dlg.idExternalLinks:SetVisible(true)
				dlg.idListLinks:SetText(table.concat(links, "\n"))
			else
				dlg.idListLinks:SetHandleMouse(false)
				dlg.idListLinks:SetText(_InternalTranslate(T(77, "Unknown")))
				dlg.idListLinks:SetTextStyle("SaveMapEntry")
			end
		end
		modContext.Corrupted, modContext.Warning, modContext.Warning_id = ModsUIGetModCorruptedStatus(Mods[modContext.ModID])
		if dlg.idWarningImg and modContext.Warning_id then
			dlg.idWarningImg:SetVisible(true)
		end
		ObjModified("NewSelectedMod")
	end, dlg)
end

---
--- Populates a mod entry in the UI with the provided context.
---
--- @param entry table The mod entry UI element.
--- @param context table The mod context.
---
function PopulateModEntry(entry, context)
	CreateRealTimeThread(function(entry, context)
		if IsValidThread(g_EnableModThread) then
			WaitMsg("EnableModThreadEnd")
		end
		
		local mod = Mods[context.ModID]
		local corrupt, warningT, warningId = ModsUIGetModCorruptedStatus(mod)

		if entry.idWarningImg then
			entry.idWarningImg:SetVisible(not not warningId)
		end
		
		if entry.idTextWarning then
			entry.idTextWarning:SetText(warningT or "")
		end
		
		entry.context = context
		entry.idName:SetText(Literal(context.DisplayName))
		local versionText
		if context.ModVersion then
			versionText = "(v. " .. context.ModVersion .. ")"
		else
			versionText = _InternalTranslate(T(77, "Unknown"))
		end
		entry.idVersion:SetText(versionText)
		entry.idAuthor:SetText(Literal(context.Author))
		local isEnabled = not not table.find(AccountStorage.LoadMods, context.ModID)
		entry.idEnabledCheck:SetColumn(isEnabled and 2 or 1)
		entry.idEnabledText:SetText(isEnabled and T(236767235164, "Enabled") or (g_CantLoadMods[context.ModID] and T(852686094555, "Failed to load") or T(569172870130, "Disabled")))
		entry.idEnabledText:SetTextStyle(isEnabled and "EnabledMod" or "SaveMapEntryTitle")
		entry.idImgBcgrSelected:SetVisible(g_SelectedMod and g_SelectedMod.ModID == context.ModID)
		ObjModified("NewSelectedMod")
	end, entry, context)
end

if FirstLoad then
	UnloadedMods = {}
end

function OnMsg.OnGedUnloadMod(modId)
	UnloadedMods[modId] = true
end

---
--- Forces the game to restart.
---
--- This function waits for the account storage to be saved, then displays a warning message and restarts the game.
---
--- @param none
--- @return none
function ForceRestartGame()
	WaitSaveAccountStorage()
	local dlg = GetPreGameMainMenu()
	if dlg then
		WaitMessage(dlg,
			T(6899, "Warning"), 
			T(970090440503, "Mods have been unloaded. The game will be restarted!"), 
			T(6900, "OK")
		)
		restart(GetAppCmdLine())
	end
end

function OnMsg.PreGameMenuOpen()
	if next(UnloadedMods) then
		CreateRealTimeThread(ForceRestartGame)
	end
end

---
--- Handles the closing of the mod manager dialog.
---
--- This function is called when the mod manager dialog is closed. It checks if the list of loaded mods has changed, and if so, displays a warning message to the user. It then reloads the mod definitions and items, saves the account storage, and resets some global variables.
---
--- @param dialog The mod manager dialog that was closed.
--- @return none
function OnModManagerClose(dialog)
	local new_mods = AccountStorage.LoadMods or empty_table
	local reloadDefs
	if not table.iequal(new_mods, g_InitialMods or empty_table) then
		WaitMessage(dialog, 
			T(6899, "Warning"), 
			T(172783978172, "Mods are player created software packages that modify your game experience. USE THEM AT YOUR OWN RISK! We do not examine, monitor, support or guarantee this user created content. You should take all precautions you normally take regarding downloading files from the Internet before using mods."), 
			T(6900, "OK"))
		reloadDefs = true
	end
	
	local unloadedModFound
	for _, modId in ipairs(g_InitialMods) do
		if not table.find(new_mods, modId) then
			ForceRestartGame()
			break
		end
	end
	
	LoadingScreenOpen("idLoadingScreen", "reload mods")
	WaitRenderMode("ui")
	ModsReloadDefs()
	if reloadDefs then ModsReloadItems() end
	SaveAccountStorage(5000)
	g_InitialMods = false
	g_ModsUIContextObj = false
	WaitRenderMode("scene")
	hr.TR_ForceReloadNoTextures = 1
	LoadingScreenClose("idLoadingScreen", "reload mods")
end

---
--- Gets the dependencies for a given mod context.
---
--- This function returns a string that lists the required mods for the given mod context. If there are no required mods, it returns `false`. The function checks the mod dependency graph to get the list of required mods, and formats the titles of the required mods based on whether they are currently loaded or not.
---
--- @param modContext The mod context to get the dependencies for.
--- @return string|boolean A string listing the required mods, or `false` if there are no required mods.
function GetModDependencies(modContext)
	local label = _InternalTranslate(T(781481359653, "<style SaveMapEntryTitle>Required mods: </style>"))
	local modDependencies = ModDependencyGraph[modContext.ModID]
	local requiredMods = table.copy(modDependencies.outgoing)
	table.iappend(requiredMods, modDependencies.outgoing_failed)
	local titles = {}
	if not next(requiredMods) then return false end
	local notIns
	for _, mod in ipairs(requiredMods) do
		if mod.required then
			local title = mod.title
			if not table.find(AccountStorage.LoadMods, mod.id) then
				title = "<style ModNotLoaded>" .. mod.title .. "</style>"
			else
				title = "<style SaveMapEntry>" .. mod.title .. "</style>"
			end

			table.insert(titles, title)
		end
	end
	titles = table.concat(titles, ", ")
	return label .. titles
end

--override mods popups to always have as parent terminal dekstop
---
--- Displays a question dialog box with the given caption, text, and buttons.
---
--- @param parent The parent UI element for the dialog box.
--- @param caption The caption to display at the top of the dialog box.
--- @param text The text to display in the body of the dialog box.
--- @param ok_text The text to display on the "OK" button.
--- @param cancel_text The text to display on the "Cancel" button.
--- @param context An optional context object to pass to the dialog box.
--- @return boolean True if the "OK" button was clicked, false if the "Cancel" button was clicked.
function WaitModsQuestion(parent, caption, text, ok_text, cancel_text, context)
	return CreateQuestionBox(terminal.dekstop, caption, text, ok_text, cancel_text, context):Wait()
end

---
--- Displays a message dialog box with the given caption, text, and "OK" button.
---
--- @param parent The parent UI element for the dialog box.
--- @param caption The caption to display at the top of the dialog box.
--- @param text The text to display in the body of the dialog box.
--- @param ok_text The text to display on the "OK" button.
--- @param context An optional context object to pass to the dialog box.
--- @return boolean True if the "OK" button was clicked.
function WaitModsMessage(parent, caption, text, ok_text, context)
	return WaitMessage(terminal.dekstop, caption, text, ok_text, context)
end