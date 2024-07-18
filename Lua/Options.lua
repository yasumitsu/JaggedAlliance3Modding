local lUIViewModes = {
	{
		value = "Always",
		text = T(296490837983, "Always")
	},
	{
		value = "Combat",
		text = T(124570697841, "Combat Only")
	}
}

local Difficulties = {
	{
		value = "Normal",
		text = T(389262521478, "First Blood")
	},
	{
		value = "Hard",
		text = T(285690646012, "Commando")
	},
	{
		value = "VeryHard",
		text = T(120945667693, "Mission Impossible")
	},
}

local lInteractableHighlightMode = {
	{
		value = "Toggle",
		text = T(252778189879, "Toggle")
	},
	{
		value = "Hold",
		text = T(645245601207, "Hold")
	}
}

local lAspectRatioItems = 
{
	{value = 1, text = T(601695937982, "None"), real_value = -1}, 
	{value = 2, text = T(375403058307, "16:9"), real_value = 16./9.}, 
	{value = 3, text = T(830202883779, "21:9"), real_value = 21./9.}
}

AppendClass.OptionsObject = {
	properties = {
		{ category = "Controls", id = "InvertRotation",           name = T(210910950476, "Invert Camera Rotation"),         editor = "bool",   default = false,     storage = "account", help = T(557409301877, "Inverts the camera rotation.") },
		{ category = "Controls", id = "InvertLook",               name = T(175826014125, "Invert Camera Rotation (Y axis)"),editor = "bool",   default = false,     storage = "account", no_edit = not Platform.trailer, },
		{ category = "Controls", id = "FreeCamRotationSpeed",     name = T(939095110164, "Controller Rotation Speed"),      editor = "number", default = 2000,      storage = "account", min = 100, max = 4000, step = 5, no_edit = not Platform.trailer, },
		{ category = "Controls", id = "FreeCamPanSpeed",          name = T(188537213687, "Controller Pan Speed"),           editor = "number", default = 1000,      storage = "account", min = 50, max = 2000, step = 5, no_edit = not Platform.trailer, },
		
		{ category = "Controls", id = "GamepadCameraMoveSpeed",   name = T(747450471741, "Tactical view sensitivity"),     editor = "number", default = 2000,      storage = "account", min = 800, max = 2500, step = 5, help = T(199647792136, "Controls how fast the selection moves in tactical view."), no_edit = function() return not GetUIStyleGamepad() end, },
		{ category = "Controls", id = "GamepadCursorMoveSpeed",   name = T(509293698210, "Cursor sensitivity"),     editor = "number", default = 11,      storage = "account", min = 2, max = 15, step = 1, help = T(573262864566, "Controls how fast the cursor in Satellite view and other menus is."), no_edit = function() return not GetUIStyleGamepad() end, },
		
		{ category = "Controls", id = "MouseScrollOutsideWindow", name = T(3587, "Panning outside window"),                 editor = "bool",   default = false,     storage = "account", no_edit = function() return GetUIStyleGamepad() end, help = T(787712595891, "Allows camera pan when the mouse cursor is outside the game window.") },
		{ category = "Controls", id = "LeftClickMoveExploration", name = T(988837649188, "Left-Click Move (Exploration)"),  editor = "bool",   default = false,     storage = "account", no_edit = function() return GetUIStyleGamepad() end, help = T(344343486722, "Use left-click to move mercs while exploring a sector out of combat.") },
		{ category = "Controls", id = "ShowGamepadHints",         name = T(731273807036, "Control Hints"),                  editor = "bool",   default = true,      storage = "account", help = T(696057050384, "Shows control hints while in exploration and in combat."), no_edit = function() return not GetUIStyleGamepad() end, },
		
		{ category = "Controls", id = "InvertPDAThumbs",          name = T(357598959787, "Swap PDA cursor controls"),  editor = "bool",   default = false,     storage = "account", help = T(965509635524, "Swaps the effect of <LS> and <RS> while using your PDA."), no_edit = function() return not GetUIStyleGamepad() end,},
		{ category = "Controls", id = "GamepadSwapTriggers",      name = T(447937688557, "Swap additional controls"),       editor = "bool",   default = false,     storage = "account", help = T(699900566044, "Swaps the actions done with <LeftTrigger> and <RightTrigger>."), no_edit = function() return not GetUIStyleGamepad() end,},
		
		{ category = "Gameplay", id = "Difficulty",               name = T(944075953376, "Difficulty"),                     editor = "choice", default = "Normal",  storage = "account", SortKey = -1900, items = Difficulties, read_only = function() return netInGame and not NetIsHost() end , help = T(146186342821, "Changing the difficulty level of the game affects loot drops, financial rewards, and enemy toughness.<newline><newline><flavor>You can change the difficulty of the game at any time during gameplay.</flavor>") },
		{ category = "Gameplay", id = "AnalyticsEnabled",         name = T(989416075981, "Analytics Enabled"),              editor = "bool",   default = "Off",     storage = "account", SortKey = 5000, on_value = "On", off_value = "Off", help = T(700491171054, "Enables or disables tracking anonymous usage data for analytics.") },
		{ category = "Gameplay", id = "HideActionBar",            name = T(805746173830, "Hide Action Bar (Exploration)"),  editor = "bool",   default = true,      storage = "account", help = T(915209994351, "Hides the action bar UI while not in combat.")},
		{ category = "Gameplay", id = "ActionCamera",             name = T(227204678948, "Targeting Action Camera"),        editor = "bool",   default = false,     storage = "account", help = T(819569684768, "A special cinematic camera view will be used while aiming an attack.\n\nThe action camera is always used with long-range weapons like sniper rifles.")},
		{ category = "Gameplay", id = "PauseOperationStart",      name = T(195176176002, "Auto-pause: Operation Start"),    editor = "bool",   default = false,     storage = "account", SortKey = 1200, help = T(783599794850, "Pause time in SatView mode whenever an Operation is started and the Operations menu is closed.") },
		{ category = "Gameplay", id = "PauseActivityDone",        name = T(219275271774, "Auto-pause: Operation Done"),     editor = "bool",   default = true,      storage = "account", SortKey = 1200, help = T(861937087426, "Pause time in SatView mode whenever an Operation is completed.") },
		{ category = "Gameplay", id = "AutoPauseDestReached",     name = T(220585419104, "Auto-pause: Sector Reached"),     editor = "bool",   default = true,      storage = "account", SortKey = 1000, help = T(679389220889, "Pause time in SatView mode whenever a squad reaches its destination sector.") },
		{ category = "Gameplay", id = "AutoPauseConflict",        name = T(292439424575, "Auto-pause: Sector Conflict"),    editor = "bool",   default = true,      storage = "account", SortKey = 1100, help = T(271690416933, "Pause time in SatView mode whenever a squad is in conflict.") },
		{ category = "Gameplay", id = "PauseSquadMovement",       name = T(700874998799, "Auto-pause: Squad Movement"),     editor = "bool",   default = false,     storage = "account", SortKey = 1100, help = T(269721155831, "Pause time in SatView mode whenever a squad travel order is given.") },
		{ category = "Gameplay", id = "ShowNorth",                name = T(397596571548, "Show North"),                     editor = "bool",   default = true,      storage = "account", help = T(968463817287, "Indicates North with an icon on the screen border.")},
		{ category = "Gameplay", id = "ShowCovers",               name = T(693926475349, "Show Covers Shields"),            editor = "choice", default = "Combat",  storage = "account", items = lUIViewModes, help = T(549744366946, "Allows cover shields to be visible when not in combat.")},
		{ category = "Gameplay", id = "AlwaysShowBadges",         name = T(834175857662, "Show Merc Badges"),               editor = "choice", default = "Combat",  storage = "account", items = lUIViewModes, help = T(526076106085, "Shows UI elements with detailed information above the merc's heads.") },
		{ category = "Gameplay", id = "ShowLOF",                  name = T(304702880820, "Show Line of Fire"),              editor = "bool",   default = true,      storage = "account", help = T(426202778816, "Allows line of fire lines to be visible when in combat.") },
		{ category = "Gameplay", id = "PauseConversation",        name = T(146071242733, "Pause conversations"),            editor = "bool",   default = true,      storage = "account", help = T(118088730513, "Wait for input before continuing to the next conversation line.")},
		{ category = "Gameplay", id = "AutoSave",                 name = T(571339674334, "AutoSave"),                       editor = "bool",   default = true,      storage = "account", SortKey = -1500, help = T(690186765577, "Automatically create a savegame when a new day starts, when a sector is entered, when a combat starts or ends, when a conflict starts in SatView, and on exit.") },
		{ category = "Gameplay", id = "InteractableHighlight",    name = T(770074868053, "Highlight mode"),                 editor = "choice", default = "Toggle",  storage = "account", items = lInteractableHighlightMode, help = T(705105646677, "Interactables can highlighted for a time when a button is pressed or held down.") },
		{ category = "Display",  id = "AspectRatioConstraint",    name = T(125094445172, "UI Aspect Ratio"),                editor = "choice", default = 1, items = lAspectRatioItems, storage = "local", no_edit = Platform.console, help = T(433997797079, "Constrain UI elements like the HUD to the set aspect ratio. Useful for Ultra Wide and Super Ultra Wide resolutions.") },
	},
}

local oldOptionsGetProperties = OptionsObject.GetProperties
---
--- Overrides the default `OptionsObject:GetProperties()` function to add additional options to the options menu.
--- This function is responsible for populating the options menu with the available game rules and settings.
---
--- The function first checks if a cached version of the properties is available, and returns it if so.
--- Otherwise, it calls the original `OptionsObject:GetProperties()` function to get the base set of properties.
---
--- It then iterates through the `Presets.GameRuleDef.Default` table, which contains the default game rules.
--- For each rule that has an associated option, it creates a new options entry with the following properties:
---
--- - `category`: The category the option belongs to, set to "Gameplay"
--- - `id`: The unique identifier for the option, taken from the `option_id` or `id` field of the rule
--- - `name`: The display name of the option, taken from the `display_name` field of the rule
--- - `editor`: The type of editor to use for the option, set to "bool"
--- - `default`: The default value for the option, taken from the `init_as_active` field of the rule
--- - `storage`: The storage location for the option, set to "account"
--- - `no_edit`: A function that returns `true` if the option should not be editable, based on whether the game is running or not
--- - `read_only`: A function that returns `true` if the option should be read-only, based on whether the player is the host of a network game or not
--- - `SortKey`: The sort key for the option, taken from the `SortKey` field of the rule
--- - `help`: The help text for the option, constructed from the `description` and `flavor_text` fields of the rule, with additional text added for advanced rules and rules that can be changed during gameplay
---
--- Finally, the function sorts the options by their `SortKey` values and caches the resulting list of properties for future use.
function OptionsObject:GetProperties()
	if self.props_cache then
		return self.props_cache
	end
	oldOptionsGetProperties(self)
	local props = {}
	for idx, rule in ipairs(Presets.GameRuleDef.Default) do
		if rule.option then
			local help_text = rule.description
			if rule.flavor_text~="" then
				help_text = T{334322641039, "<description><newline><newline><flavor><flavor_text></flavor>", rule}
			end
			if rule.advanced then
				help_text = help_text.."\n\n"..T(292693735449, "<flavor>The advanced game rules are not recommended for your first playthrough!</flavor>")
			end
			if rule.id~="ForgivingMode" and rule.id~="ActivePause" then
				help_text = help_text.."\n\n"..T(373450409022, "<flavor>You can change this option at any time during gameplay.</flavor>")
			end
			table.insert(props, 
				{ category = "Gameplay", id = rule.option_id or rule.id, name = rule.display_name, editor = "bool",  default = rule.init_as_active, storage = "account", 
				  no_edit = function (self) return not Game end, read_only = function() return netInGame and not NetIsHost() end, 
				  SortKey =rule.SortKey, help = help_text})
		end
	end		
	table.stable_sort(props, function(a,b)
		return (a.SortKey or 0) < (b.SortKey or 0)
	end)
	self.props_cache = table.iappend(self.props_cache,props)
	return self.props_cache
end

const.MaxUserUIScaleHighRes = 100

function OnMsg.ApplyAccountOptions()
	if AccountStorage then
		hr.CameraScrollOutsideWindow = GetAccountStorageOptionValue("MouseScrollOutsideWindow") == false and 0 or 1
		const.CameraControlInvertLook = GetAccountStorageOptionValue("InvertLook")
		const.CameraControlInvertRotation = GetAccountStorageOptionValue("InvertRotation")
		const.CameraControlControllerPanSpeed = GetAccountStorageOptionValue("FreeCamPanSpeed")
		hr.CameraFlyRotationSpeed = GetAccountStorageOptionValue("FreeCamRotationSpeed") / 1000.0
		hr.GamepadMouseUseRightStick = GetAccountStorageOptionValue("InvertPDAThumbs")
		hr.GamepadMouseSensitivity = GetAccountStorageOptionValue("GamepadCursorMoveSpeed")
		
		-- Editor mode
		local igi = GetInGameInterfaceModeDlg()
		if not igi then
			hr.CameraTacMoveSpeed = GetAccountStorageOptionValue("GamepadCameraMoveSpeed")
		end
		hr.CameraTacZoomStepGamepad = GetAccountStorageOptionValue("GamepadCameraMoveSpeed") / 10
		hr.CameraTacRotationSpeed = (GetAccountStorageOptionValue("GamepadCameraMoveSpeed") / 10) * 2

		UpdateAllBadgesAndModes()
		if GetUIStyleGamepad() then
			RecreateButtonsTagLookupTable()
			ObjModified("GamepadUIStyleChanged")
		end
	end
end

---
--- Saves the account storage after a change to the camera speed options.
---
--- This function is called after a delay of 1 second to allow other changes to be applied before saving.
---
function SaveAccStorageAfterCameraSpeedOptionChange()
	SaveAccountStorage(2000)
end

---
--- Synchronizes the camera controller speed options and saves the account storage after a delay.
---
--- This function sets the account storage option values for the free camera pan speed and rotation speed,
--- and then calls a delayed function to save the account storage after 1 second.
---
--- This allows other changes to be applied before the account storage is saved.
---
function SyncCameraControllerSpeedOptions()
	SetAccountStorageOptionValue("FreeCamPanSpeed", const.CameraControlControllerPanSpeed)
	SetAccountStorageOptionValue("FreeCamRotationSpeed", hr.CameraFlyRotationSpeed * 1000)
	DelayedCall(1000, SaveAccStorageAfterCameraSpeedOptionChange)
end

local ultraPresetWaringT = T{393813156807, --[[Warning popup on changing to 'Ultra' settings preset]] "You have selected the '<ultra_preset>' video preset! This choice is extremely demanding on the hardware and may strain even configurations well above the recommended system requirements.", ultra_preset = T(3551, "Ultra") }
local ultraPresetConfirmationT = T{782520163252, --[[Warning popup on changing to 'Ultra' settings preset]] "Are you certain you want to change the video preset to '<ultra_preset>'?", ultra_preset = T(3551, "Ultra") }

---
--- Applies the options selected by the user.
---
--- This function is called when the user has finished configuring their options and wants to apply the changes.
---
--- It performs the following steps:
--- - Checks if the user has selected the "Ultra" video preset, and displays a warning if so.
--- - Waits for the options to be applied successfully.
--- - Copies the selected options to the original options object.
--- - Saves the engine options and account storage.
--- - Applies any necessary changes based on the category of options being changed (e.g. reloading shortcuts for keybindings, applying language/difficulty/gameplay options, updating object detail).
--- - Refreshes the UI if the UI scale option was changed.
--- - Sends a "GameOptionsChanged" message with the category of options that were changed.
--- - Sets the dialog mode to the next mode, if specified.
---
--- @param host The dialog host object.
--- @param next_mode The next dialog mode to set, if any.
---
function ApplyOptions(host, next_mode)
	CreateRealTimeThread(function(host)
		local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		
		local ultraPresetCheck = UltraPresetWarning(obj, original_obj, category)
		if ultraPresetCheck == "revert" then
			return
		end

		if not obj:WaitApplyOptions() then
			WaitMessage(terminal.desktop, T(824112417429, "Warning"), T(862733805364, "Changes could not be applied and will be reverted."), T(325411474155, "OK"))
		else
			local object_detail_changed = obj.ObjectDetail ~= original_obj.ObjectDetail
			obj:CopyCategoryTo(original_obj, category)
			SaveEngineOptions()
			SaveAccountStorage(5000)
			if category == "Keybindings" then
				ReloadShortcuts()
			elseif category == "Gameplay" then
				ApplyLanguageOption()
				ApplyDifficultyOption()
				ApplyGameplayOption()
			elseif category == "Video" then
				if object_detail_changed then
					SetObjectDetail(obj.ObjectDetail)
				end
			end
			if category == obj:GetPropertyMetadata("UIScale").category then
				terminal.desktop:OnSystemSize(UIL.GetScreenSize()) -- force refresh, UIScale might be changed
			end
			Msg("GameOptionsChanged", category)
		end
		if not next_mode then
			--SetBackDialogMode(host)
		else
			--SetDialogMode(host, next_mode)
		end
	end, host)
end

---
--- Cancels the current options dialog and restores the original options.
---
--- @param host The dialog host object.
--- @param clear If true, clears the dialog mode and resets the main menu buttons.
---
function CancelOptions(host, clear)
	return CreateRealTimeThread(function(host)
		if host.window_state == "destroying" then return end
		local obj = OptionsObj
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		original_obj:WaitApplyOptions()
		original_obj:CopyCategoryTo(obj,category)
		if clear then 
			local sideButtuonsDialog = GetDialog(host):ResolveId("idMainMenuButtonsContent")
			if sideButtuonsDialog and GetDialogMode(sideButtuonsDialog) == "keybindings" then
				GetDialog(host):ResolveId("idMainMenuButtonsContent"):SetMode("mm")
			else
				local mmDialog = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
				mmDialog:SetMode("")
			end
			GetDialog(host):SetMode("empty") 
		end
		GetDialog(host):ResolveId("idSubSubContent"):SetMode("empty") 
	end, host)
end

---
--- Applies the display options selected by the user.
---
--- @param host The dialog host object.
--- @param next_mode The next mode to set for the dialog after applying the options.
---
function ApplyDisplayOptions(host, next_mode)
	CreateRealTimeThread( function(host)
		if host.window_state == "destroying" then return end
		local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local graphics_api_changed = obj.GraphicsApi ~= original_obj.GraphicsApi
		local graphics_adapter_changed = obj.GraphicsAdapterIndex ~= original_obj.GraphicsAdapterIndex
		local ok = obj:ApplyVideoMode()
		if ok == "confirmation" then
			ok = WaitQuestion(terminal.desktop, T(145768933497, "Video mode change"), T(751908098091, "The video mode has been changed. Keep changes?"), T(689884995409, "Yes"), T(782927325160, "No")) == "ok"
		end
		--options obj should always show the current resolution
		obj:SetProperty("Resolution", point(GetResolution()))
		if ok then
			obj:CopyCategoryTo(original_obj, "Display")
			original_obj:SaveToTables()
			SaveEngineOptions() -- save the original + the new display options to disk, in case user cancels options menu
		else
			-- user doesn't like it, restore
			original_obj:ApplyVideoMode()
			original_obj:CopyCategoryTo(obj, "Display")
		end
		local restartRequiredOptionT
		if graphics_api_changed and graphics_adapter_changed then
			restartRequiredOptionT = T(918368138749, "More than one option will only take effect after the game is restarted.")
		elseif graphics_api_changed then
			restartRequiredOptionT = T(419298766048, "Changing the Graphics API option will only take effect after the game is restarted.")
		elseif graphics_adapter_changed then
			restartRequiredOptionT = T(133453226856, "Changing the Graphics Adapter option will only take effect after the game is restarted.")
		end
		if restartRequiredOptionT then
			WaitMessage(terminal.desktop, T(1000599, "Warning"), restartRequiredOptionT, T(325411474155, "OK"))
		end
	end, host)
end

---
--- Cancels the display options changes made by the user.
---
--- @param host The dialog host object.
--- @param clear If true, clears the display options dialog.
---
function CancelDisplayOptions(host, clear)
	local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
	local original_obj = ResolvePropObj(host.idOriginalOptions.context)
	original_obj:CopyCategoryTo(obj, "Display")
	obj:SetProperty("Resolution", point(GetResolution()))
	if clear then 
		GetDialog(host):SetMode("empty")
		local mmDialog = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
		mmDialog:SetMode("")
		GetDialog(host):ResolveId("idSubSubContent"):SetMode("empty") 
	end
end

function OnMsg.OptionsChanged()
	local mm = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
	if mm then
		local resetApplyButtons = mm:ResolveId("idSubMenu"):ResolveId("idOptionsActionsCont")[1]
		local applyOpt = resetApplyButtons:ResolveId("idapplyOptions") or resetApplyButtons:ResolveId("idapplyDisplayOptions")
		if applyOpt then
			applyOpt.action.enabled = true
			applyOpt:SetEnabled(true)
			ObjModified("action-button-mm")
		end
		
		local resetOpt = resetApplyButtons:ResolveId("idresetToDefaults")
		if resetOpt then
			resetOpt.action.enabled = true
			resetOpt:SetEnabled(true)
			ObjModified("action-button-mm")
		end
	end
end

local lDialogsToApplyAspectRatioTo = {
	function()
		local igi = GetInGameInterface()
		return igi and igi.mode_dialog
	end,
	function()
		local weaponMod = GetDialog("ModifyWeaponDlg")
		return weaponMod and weaponMod.idModifyDialog
	end,
	function()
		local menu = GetDialog("PreGameMenu")
		return menu and menu.idMainMenu
	end,
	function()
		local menu = GetDialog("InGameMenu")
		return menu and menu.idMainMenu
	end,
}

---
--- Calculates the UI scale based on the screen size and aspect ratio constraints.
---
--- @param res table|nil The screen resolution to use, or nil to use the current screen size.
--- @return number The calculated UI scale.
function GetUIScale(res)
	--the user ui scale option now works on top of the previously automatic scale (multiplication).
	local screen_size = Platform.ged and UIL.GetOSScreenSize() or res or UIL.GetScreenSize()
	local xrez, yrez = screen_size:xy()
	
	local aspectRatioContraint = GetAspectRatioConstraintAmount("unscaled")
	xrez = xrez - aspectRatioContraint * 2
	
	local scale_x, scale_y = 1000 * xrez / 1920, 1000 * yrez / 1080
	-- combine the X and Y scale
	local scale = (scale_x + scale_y) / 2
	-- do not exceed the lower scale with more than 20%
	scale = Min(scale, scale_x * 120 / 100)
	scale = Min(scale, scale_y * 120 / 100)
	-- make the UI somewhat smaller on higher resolutions - having more pixels increases readability despite the lower size
	if scale > 1000 then
		scale = 1000 + (scale - 1000) * 900 / 1000
	end
	local controller_scale = table.get(AccountStorage, "Options", "Gamepad") and IsXInputControllerConnected() and const.ControllerUIScale or 100
	-- apply user scale and controller scale as multipliers
	return MulDivRound(scale, GetUserUIScale(scale) * controller_scale, 100 * 100)
end

---
--- Calculates the amount of aspect ratio constraint margin to apply to the screen.
---
--- @param unscaled boolean If true, the margin is returned in unscaled screen coordinates. Otherwise, it is returned in scaled UI coordinates.
--- @return number The amount of aspect ratio constraint margin to apply.
function GetAspectRatioConstraintAmount(unscaled)
	local screen_size = Platform.ged and UIL.GetOSScreenSize() or UIL.GetScreenSize()
	local x, y = screen_size:xy()
	
	local constraint = lAspectRatioItems[EngineOptions.AspectRatioConstraint]
	constraint = constraint and constraint.real_value or 0
	
	local constraintMargin = 0
	if constraint > 0 and (0.0 + x) / y > constraint then
		local smallerWidth = round(y * constraint, 1)
		local xx = DivRound(x - smallerWidth, 2)
		
		if not unscaled then
			local scale = GetUIScale()
			constraintMargin = MulDivRound(xx, 1000, scale)
		else
			constraintMargin = xx
		end
	end
	return constraintMargin
end

---
--- Applies the aspect ratio constraint to the specified dialogs.
---
--- The aspect ratio constraint is calculated using the `GetAspectRatioConstraintAmount()` function.
--- The calculated constraint margin is then applied to the specified dialogs by setting their margins.
---
--- The dialogs to apply the constraint to are specified in the `lDialogsToApplyAspectRatioTo` table.
---
--- @function ApplyAspectRatioConstraint
function ApplyAspectRatioConstraint()
	local constraintMargin = GetAspectRatioConstraintAmount()
	
	for i, dlg in ipairs(lDialogsToApplyAspectRatioTo) do
		local dlgInstance = false
		if type(dlg) == "function" then
			dlgInstance = dlg()
		elseif type(dlg) == "string" then
			dlgInstance = GetDialog(dlg)
		end
		if dlgInstance then
			dlgInstance:SetMargins(box(constraintMargin, 0, constraintMargin, 0))
		end
	end
end

function OnMsg.IGIModeChanging()
	ApplyAspectRatioConstraint()
end

function OnMsg.SystemSize()
	ApplyAspectRatioConstraint()
end

function OnMsg.DialogOpen()
	ApplyAspectRatioConstraint()
end

local baseSetDisplayAreaMargin = OptionsObject.SetDisplayAreaMargin
---
--- Sets the display area margin for the OptionsObject.
---
--- This function overrides the base `SetDisplayAreaMargin` function and sets the margin to 0.
---
--- @param x The new display area margin value.
--- @function SetDisplayAreaMargin
function OptionsObject:SetDisplayAreaMargin(x)
	baseSetDisplayAreaMargin(self, 0)
end

---
--- Sets the aspect ratio constraint for the OptionsObject.
---
--- The aspect ratio constraint is used to apply a margin to dialogs in order to maintain a specific aspect ratio.
--- This function sets the aspect ratio constraint value and then calls `ApplyAspectRatioConstraint()` to apply the constraint.
---
--- @param x The new aspect ratio constraint value.
--- @function SetAspectRatioConstraint
function OptionsObject:SetAspectRatioConstraint(x)
	self.AspectRatioConstraint = x
	ApplyAspectRatioConstraint()
end

---
--- Applies the difficulty option by syncing the difficulty change to the network or applying it directly.
---
--- If the game is in a multiplayer session, the difficulty change is synced to the network using the `MP_ApplyDifficulty` event. Otherwise, the difficulty is applied directly using the `ApplyDifficulty` function.
---
--- @param none
--- @return none
function ApplyDifficultyOption()
	if not Game then return end
	local newValue = OptionsObj and OptionsObj.Difficulty
	if netInGame then
		NetSyncEvent("MP_ApplyDifficulty", newValue)
	else
		ApplyDifficulty(newValue)
	end
end

---
--- Applies the difficulty option by syncing the difficulty change to the network.
---
--- If the game is in a multiplayer session, the difficulty change is synced to the network using the `MP_ApplyDifficulty` event.
---
--- @param newValue The new difficulty value to apply.
--- @return none
function NetSyncEvents.MP_ApplyDifficulty(newValue)
	ApplyDifficulty(newValue)
end

---
--- Applies the specified difficulty value to the game and updates the options object.
---
--- If the game difficulty is different from the new value, the game difficulty is updated and a "DifficultyChange" message is sent.
--- The options object is then updated with the new difficulty value and marked as modified.
--- Finally, the SetDifficultyOption function is called to apply the difficulty change.
---
--- @param newValue The new difficulty value to apply.
--- @return none
function ApplyDifficulty(newValue)
	if newValue and Game.game_difficulty ~= newValue then
		Game.game_difficulty = newValue
		Msg("DifficultyChange")
	end
	if OptionsObj then
		OptionsObj:SetProperty("Difficulty", newValue)
		ObjModified(OptionsObj)
	end
	SetDifficultyOption()
end

---
--- Changes the specified game rule to the given value.
---
--- If the game rule is currently active and the new value is false, the game rule is removed from the game.
--- If the game rule is currently inactive and the new value is true, the game rule is added to the game.
--- In either case, a "ChangeGameRule" message is sent with the rule ID and new value.
---
--- @param rule (string) The ID of the game rule to change.
--- @param value (boolean) The new value for the game rule.
--- @return none
function ChangeGameRule(rule, value)
	if Game and IsGameRuleActive(rule) ~= value then
		if value then
			Game:AddGameRule(rule)
		else
			Game:RemoveGameRule(rule)
		end
		Msg("ChangeGameRule", rule, value)
	end
end

---
--- Sets the game rules options in the options object.
---
--- This function iterates through the default game rule definitions and sets the corresponding options in the `OptionsObj` object.
--- If a game rule has an associated option, the function sets the option value to the current active state of the game rule.
--- Finally, the `ApplyOptionsObj` function is called to apply the updated options.
---
--- @return none
function SetGameRulesOptions()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	for idx, def in ipairs (Presets.GameRuleDef.Default) do
		if def.option then
			OptionsObj:SetProperty(def.option_id or def.id, IsGameRuleActive(def.id))
		end
	end
	ApplyOptionsObj(OptionsObj)
end	

---
--- Applies the current game rules options to the game.
---
--- This function retrieves the current state of the game rules options from the `OptionsObj` object,
--- and then synchronizes those options with the game rules in the active game. It does this by:
---
--- 1. Iterating through the default game rule definitions and creating a list of rule IDs and their
---    current option values.
--- 2. Sending a "ChangeGameRulesMode" network event with the list of rule changes.
--- 3. Sending a "ChangeActivePauseMode" network event to ensure the active pause state is synchronized.
---
--- This function is typically called when the game rules options have been modified, in order to
--- apply those changes to the active game.
---
--- @return none
function ApplyGameplayOption()	
	local values = {}
	for idx, ruledef  in ipairs(Presets.GameRuleDef.Default) do
		if ruledef.option then
			values[#values +1 ] = {rule = ruledef.id,  value = OptionsObj and OptionsObj[ruledef.option_id or ruledef.id]}
		end
	end
	NetSyncEvent("ChangeGameRulesMode", values)
	NetSyncEvent("ChangeActivePauseMode")
end

---
--- Synchronizes the game rules mode with the current options.
---
--- This function is called when the game rules options have been modified. It iterates through the list of
--- rule changes provided, and applies those changes to the active game rules. It also updates the corresponding
--- options in the `OptionsObj` object to ensure consistency.
---
--- @param values table A table of rule changes, where each entry has a `rule` field (the rule ID) and a `value` field (the new rule value).
--- @return none
function NetSyncEvents.ChangeGameRulesMode(values)
	for idx, def in ipairs(values) do
		local rule_id = def.rule
		local val = def.value
		ChangeGameRule(rule_id, val)
		local preset = GameRuleDef[rule_id]
		if OptionsObj and preset and preset.option then		
			OptionsObj:SetProperty(preset.option_id or rule_id, value)
			ObjModified(OptionsObj)
		end
		ApplyOptionsObj(OptionsObj)
	end
end

---
--- Synchronizes the active pause state with the game rules.
---
--- This function is called when the active pause state needs to be synchronized with the game rules.
--- It checks if the "ActivePause" game rule is not active, but the game is currently in an active
--- paused state. If so, it creates a new game time thread to set the active pause state.
---
--- This function is typically called after changes to the game rules options have been applied,
--- to ensure the active pause state is consistent with the current game rules.
---
--- @return none
function NetSyncEvents.ChangeActivePauseMode()
	if not IsGameRuleActive("ActivePause") and IsActivePaused() then
		CreateGameTimeThread(SetActivePause)
	end
end

function OnMsg.ZuluGameLoaded(game)
	SetGameRulesOptions()
	SetDifficultyOption()
end

---
--- Sets the difficulty option in the game options.
---
--- This function retrieves the current game difficulty from the `Game` object and sets the corresponding
--- "Difficulty" property in the `OptionsObj` object. It then applies the updated options to the game.
---
--- This function is typically called when the game is loaded, to ensure the difficulty option is
--- properly set based on the current game state.
---
--- @return none
function SetDifficultyOption()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	OptionsObj:SetProperty("Difficulty", Game.game_difficulty)
	ApplyOptionsObj(OptionsObj)
end

function OnMsg.NetGameLoaded()
	--in mp aply these options to the guest
	if not NetIsHost() then
		SetGameRulesOptions()
		SetDifficultyOption()
	end
end

local s_oldHideObjectsByDetailClass = HideObjectsByDetailClass

---
--- Overrides the default `HideObjectsByDetailClass` function to always pass `true` as the last argument.
---
--- This function is a wrapper around the original `HideObjectsByDetailClass` function, which is stored in the `s_oldHideObjectsByDetailClass` variable. It calls the original function with the same arguments, but always passes `true` as the last argument.
---
--- @param optionals table A table of optional parameters to pass to the original function.
--- @param future_extensions table A table of future extension parameters to pass to the original function.
--- @param eye_candies table A table of eye candy parameters to pass to the original function.
--- @return none
function HideObjectsByDetailClass(optionals, future_extensions, eye_candies, ...)
	s_oldHideObjectsByDetailClass(optionals, future_extensions, eye_candies, true)
end

---
--- Displays a warning dialog when the user attempts to change the video preset to "Ultra" mode.
---
--- This function is called when the video preset is changed in the options menu. If the new preset is "Ultra" and the user has not seen the warning before, a dialog is displayed asking the user to confirm the change.
---
--- If the user confirms the change, the function returns "ok" and the new preset is applied. If the user cancels the change, the function reverts the video preset to the original value and returns "revert".
---
--- @param new_obj table The new options object with the changed video preset.
--- @param original_obj table The original options object with the previous video preset.
--- @param category string The category of the options being changed (e.g. "Video").
--- @return string "ok" if the user confirms the change, "revert" if the user cancels the change.
function UltraPresetWarning(new_obj, original_obj, category)
	if new_obj.VideoPreset ~= original_obj.VideoPreset and new_obj.VideoPreset == "Ultra" and not LocalStorage.ShowedUltraWarning then
		local ok = WaitQuestion(
			terminal.desktop, 
			T(145768933497, "Video mode change"), 
			T{776508122432, "<ultraPresetWaringT>\n\n<ultraPresetConfirmationT>", ultraPresetWaringT = ultraPresetWaringT, ultraPresetConfirmationT = ultraPresetConfirmationT},
			T(689884995409, "Yes"), 
			T(782927325160, "No")) == "ok"
		if not LocalStorage.ShowedUltraWarning then
			LocalStorage.ShowedUltraWarning = true
		end
		SaveLocalStorage()
		if not ok then -- revert the ultra preset changes
			original_obj:CopyCategoryTo(new_obj, "Video")
			ObjModified(new_obj)
			return "revert"
		else
			return "ok"
		end
	end
	
	return "ok"
end