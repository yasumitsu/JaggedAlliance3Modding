-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	group = "Zulu",
	id = "ModManagerActions",
	PlaceObj('XTemplateWindow', nil, {
		PlaceObj('XTemplateAction', {
			'ActionId', "idBack",
			'ActionName', T(991483755533, --[[XTemplate ModManagerActions ActionName]] "BACK"),
			'ActionToolbar', "mainmenu",
			'ActionShortcut', "Escape",
			'ActionGamepad', "ButtonB",
			'OnActionEffect', "back",
			'OnAction', function (self, host, source, ...)
				if GetLoadingScreenDialog("noAccStorage") then
					return
				end
				if not GetUIStyleGamepad() or host.isMMFocused then 
					CreateRealTimeThread(function(self, host, source)
						if source and source.class == "XButton" then
							source:SetFocus(true)
						end
						OnModManagerClose(GetPreGameMainMenu())
						host:ResolveId("idSubMenuTittle"):SetText(T(""))
						host:ResolveId("idSubMenuTittleDescr"):SetText(T(""))
						host:ResolveId("idSubContent"):SetMode("empty")
						host:ResolveId("idSubSubContent"):SetMode("empty")
						XAction.OnAction(self, host, source)
					end, self, host, source)
					host.isMMFocused = false
				else
					local subMenu = host:ResolveId("idSubMenu")
					local list = host:ResolveId("idMainMenuButtonsContent"):ResolveId("idList")
					list:SetFocus(true)
					list:SelectFirstValidItem()
					host.isMMFocused = true
					g_SelectedMod = false
					local installedModsList = subMenu and subMenu:ResolveId("idScrollArea")
					for _, btn in ipairs(installedModsList) do
						if IsKindOf(btn and btn.context, "ModUIEntry") then
							btn:SetSelected(false)
						end
					end
					host:ResolveId("idSubSubContent"):SetMode("empty")
				end
			end,
			'FXPress', "MainMenuButtonClick",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idGoToSubMenu",
			'ActionGamepad', "DPadRight",
			'ActionState', function (self, host)
				return GoToSubMenu_ActionState(self, host)
			end,
			'OnAction', function (self, host, source, ...)
				host.isMMFocused = false
				GoToSubMenu_OnAction(self, host, source, ...)
			end,
			'FXPress', "MainMenuButtonClick",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idGoToSubMenu",
			'ActionGamepad', "LeftThumbRight",
			'ActionState', function (self, host)
				return GoToSubMenu_ActionState(self, host)
			end,
			'OnAction', function (self, host, source, ...)
				host.isMMFocused = false
				GoToSubMenu_OnAction(self, host, source, ...)
			end,
			'FXPress', "MainMenuButtonClick",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idInstalledMods",
			'ActionName', T(395229437627, --[[XTemplate ModManagerActions ActionName]] "Installed Mods"),
			'ActionToolbar', "mainmenu",
			'OnAction', function (self, host, source, ...)
				XAction.OnAction(self, host, source)
			end,
			'FXPress', "MainMenuButtonClick",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idModEditor",
			'ActionName', T(509702074737, --[[XTemplate ModManagerActions ActionName]] "Mod Editor"),
			'ActionToolbar', "mainmenu",
			'OnAction', function (self, host, source, ...)
				CreateRealTimeThread(function(self, host, source)
					OnModManagerClose(GetPreGameMainMenu())
					ModEditorOpen()
					XAction.OnAction(self, host, source)
				end, self, host, source)
			end,
			'FXPress', "MainMenuButtonClick",
			'__condition', function (parent, context) return not Platform.steamdeck and not Platform.console end,
		}),
		}),
})

