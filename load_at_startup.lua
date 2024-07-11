
RealG = _G
--Platform.developer = true

PlaceObj('XTemplate', {
	comment = "This is the Holy Grail!",
	group = "Shortcuts",
	id = "DebugShortcuts",
	PlaceObj('XTemplateForEach', {
		'comment', "Preset editors",
		'array', function (parent, context)
					return ClassDescendantsList("Preset")
		end,
		'condition', function (parent, context, item, i)
					local class = g_Classes[item]
					local PresetClass = class and class.PresetClass or item
					return class and class.GedEditor and class.GedEditor ~= "" and class.EditorMenubarName and (PresetClass == item or g_Classes[PresetClass].GedEditor ~= class.GedEditor)
		end,
		'run_after', function (child, context, item, i, n, last)
			local class = g_Classes[item]
			child.ActionId = "PresetEditor" .. item
			child.ActionName = class.EditorMenubarName ~= "" and class.EditorMenubarName or item
			child:SetActionShortcuts(class.EditorShortcut, child.ActionShortcut2, child.ActionGamepad)
			child.ActionIcon = class.EditorIcon
			child:SetActionMenubar(class.EditorMenubar)
			child:SetActionSortKey(class.EditorMenubarSortKey)
			child.OnAction = function()
				OpenPresetEditor(item)
			end
		end,
	}, {
		PlaceObj('XTemplateAction', {
			'ActionTranslate', false,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "DLC",
		'ActionTranslate', false,
		'ActionName', "DLC",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateForEach', {
			'run_after', function (child, context, item, i, n, last)
				local dlc = string.gsub(item, "svnProject/Dlc/", "")
				child.ActionId = dlc
				child.ActionName = dlc .. (g_DlcDisplayNames[dlc] and " (" .. g_DlcDisplayNames[dlc] .. ")" or "")
				child.ActionSortKey = tostring(i)
			end,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/unchecked.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return not LocalStorage.DisableDLC or not LocalStorage.DisableDLC[self.ActionId]
				end,
				'ActionToggledIcon', "CommonAssets/UI/Menu/checked.tga",
				'OnActionEffect', "popup",
				'OnAction', function (self, host, source, ...)
					LocalStorage.DisableDLC = LocalStorage.DisableDLC or {}
					LocalStorage.DisableDLC[self.ActionId] = self:ActionToggled(host) and true or nil
					DelayedCall(1000, ReloadDevDlcs)
				end,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Enable All DLCs",
			'RolloverText', "Enable All DLCs(except future)",
			'ActionId', "G_EnableAllDLC",
			'ActionTranslate', false,
			'ActionName', "Enable All DLC-s",
			'ActionIcon', "CommonAssets/UI/Icons/add circle create new plus.png",
			'OnAction', function (self, host, source, ...)
				SetAllDevDlcs(true)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Disable All DLCs",
			'RolloverText', "Disable All DLCs(except future)",
			'ActionId', "G_DisableAllDLC",
			'ActionTranslate', false,
			'ActionName', "Disable All DLC-s",
			'ActionIcon', "CommonAssets/UI/Icons/circle delete minus remove.png",
			'OnAction', function (self, host, source, ...)
				SetAllDevDlcs(false)
			end,
			'replace_matching_id', true,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Editors",
		'ActionTranslate', false,
		'ActionName', "Editors",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.UI",
			'ActionTranslate', false,
			'ActionName', "UI ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Humans",
			'ActionTranslate', false,
			'ActionName', "Humans ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Engine",
			'ActionTranslate', false,
			'ActionName', "Engine ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "SHDiffuseIrradiance",
				'ActionTranslate', false,
				'ActionName', "SHDiffuseIrradiance",
				'ActionIcon', "CommonAssets/UI/Icons/caution danger exclamation",
				'OnAction', function (self, host, source, ...)
					OpenPresetEditor("SHDiffuseIrradiance")
				end,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Lists",
			'ActionTranslate', false,
			'ActionName', "Lists ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Other",
			'ActionTranslate', false,
			'ActionName', "Other ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "StoryBitsLog",
				'ActionTranslate', false,
				'ActionName', "Story Bits Log",
				'ActionIcon', "CommonAssets/UI/Icons/clipboard.png",
				'OnAction', function (self, host, source, ...)
							  if gv_Quests then
								OpenGedApp("StoryBitLog", gv_Quests)
							  else
								print("Story Bits log is unavailable.")
							  end
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Art",
			'ActionTranslate', false,
			'ActionName', "Art & FX ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "E_FX_AnimMetadataEditor",
				'ActionTranslate', false,
				'ActionName', "Anim Metadata Editor",
				'ActionIcon', "CommonAssets/UI/Icons/video",
				'OnAction', function (self, host, source, ...)
								OpenAnimationMomentsEditor()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "E_FX_SkinDecalEditor",
				'ActionTranslate', false,
				'ActionName', "Skin Decal Editor",
				'ActionIcon', "CommonAssets/UI/Icons/video",
				'OnAction', function (self, host, source, ...)
								OpenSkinDecalEditor()
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Editors.Audio",
			'ActionTranslate', false,
			'ActionName', "Audio ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Sound Debug",
				'RolloverText', "Toggle Sound Debug",
				'ActionId', "E_SoundToggleDebug",
				'ActionTranslate', false,
				'ActionName', "Toggle Sound Debug",
				'ActionIcon', "CommonAssets/UI/Icons/volume.png",
				'ActionShortcut', "Ctrl-\\",
				'OnAction', function (self, host, source, ...)
								ToggleSoundDebug()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Listener Update",
				'RolloverText', "Toggle Listener Update",
				'ActionId', "E_ToggleListenerUpdate",
				'ActionTranslate', false,
				'ActionName', "Toggle Listener Update",
				'ActionIcon', "CommonAssets/UI/Icons/volume.png",
				'OnAction', function (self, host, source, ...)
								ToggleListenerUpdate()
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "ModEditor",
			'ActionTranslate', false,
			'ActionName', "Mod Editor",
			'ActionIcon', "CommonAssets/UI/Icons/outline puzzle",
			'ActionShortcut', "Alt-Shift-M",
			'OnAction', function (self, host, source, ...)
						  ModEditorOpen()
			end,
			'__condition', function (parent, context)
						  return config.Mods
			end,
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Open / Exit Editor (F3)",
				'RolloverText', "Editor (F3)",
				'ActionId', "MO_Editor",
				'ActionTranslate', false,
				'ActionName', "Open / Exit Editor",
				'ActionIcon', "CommonAssets/UI/Icons/map.png",
				'ActionShortcut', "F3",
				'OnAction', function (self, host, source, ...)
							  ToggleEnterExitEditor()
				end,
			}),
			}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Render",
		'ActionTranslate', false,
		'ActionName', "Render",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Framerate Boost (Alt-+ or Alt-Numpad +)",
			'ActionId', "DbgToggleFramerateBoost",
			'ActionTranslate', false,
			'ActionName', "Toggle Framerate Boost",
			'ActionShortcut', "Alt-+",
			'ActionShortcut2', "Alt-Numpad +",
			'OnAction', function (self, host, source, ...)
						  ToggleFramerateBoost()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', " (Ctrl-Shift-I)",
			'RolloverText', " (Ctrl-Shift-I)",
			'ActionId', "G_ChangeFPSIndicator",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Change FPS Indicator mode",
			'ActionIcon', "CommonAssets/UI/Icons/chart graph growth increase profit stock.png",
			'ActionShortcut', "Ctrl-Shift-I",
			'OnAction', function (self, host, source, ...)
				local mode = hr.FpsCounter
				mode = mode + 1
				if mode >= 3 then mode = 0 end
				if mode == 0 then print("framerate indicator off")
				else if mode == 1 then print("show frames-per-second")
				else if mode == 2 then print("show (milli)seconds-per-frame")
				end end end
				hr.FpsCounter = mode
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', 'Cycle "Object Details"',
			'RolloverText', "Editor settings",
			'ActionId', "E_EditorCycleObjectDetails",
			'ActionTranslate', false,
			'ActionName', 'Cycle "Object Details"',
			'ActionIcon', "CommonAssets/UI/Menu/object_options.tga",
			'ActionShortcut', "Ctrl-Alt-/",
			'OnAction', function (self, host, source, ...)
				local details
				if EngineOptions.ObjectDetail == "Very Low" then
					details = "Low"
				elseif EngineOptions.ObjectDetail == "Low" then
					details = "Medium"
				elseif EngineOptions.ObjectDetail == "Medium" then
					details = "High"
				else
					details = table.find(OptionsData.Options.ObjectDetail, "value", "Very Low") and "Very Low" or "Low"
				end
				EngineSetObjectDetail(details, IsEditorActive() and "dont apply filters")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Debug Textures",
			'ActionTranslate', false,
			'ActionName', "Debug Textures ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Wireframe",
				'RolloverText', "Toggle Wireframe (Ctrl-Alt-W)",
				'ActionId', "G_Wireframe",
				'ActionTranslate', false,
				'ActionName', "Toggle Wireframe",
				'ActionIcon', "CommonAssets/UI/Menu/Wireframe.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.Wireframe == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("Wireframe")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Base Color Maps",
				'RolloverText', "Toggle Base Color Maps",
				'ActionId', "G_DisableBaseColorMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle Base Color Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableBaseColorMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableBaseColorMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableBaseColorMaps")
								hr.TR_ForceReloadNoTextures = 1
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle RM Maps",
				'RolloverText', "Toggle RM Maps",
				'ActionId', "G_DisableRMMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle RM Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableRMMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableRMMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableRMMaps")
								hr.TR_ForceReloadNoTextures = 1
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Normal Maps",
				'RolloverText', "Toggle Normal Maps",
				'ActionId', "G_DisableNormalMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle Normal Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableNormalMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableNormalMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableNormalMaps")
								hr.TR_ForceReloadNoTextures = 1
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle AO Maps",
				'RolloverText', "Toggle AO Maps",
				'ActionId', "G_DisableAOMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle AO Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableAOMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableAOMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableAOMaps")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Self-Illumination Maps",
				'RolloverText', "Toggle Self-Illumination Maps",
				'ActionId', "G_DisableSIMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle Self-illumination Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableSIMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableSIMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableSIMaps")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Colorization Maps",
				'RolloverText', "Toggle Colorization Maps",
				'ActionId', "G_DisableColorizationMaps",
				'ActionTranslate', false,
				'ActionName', "Toggle Colorization Maps",
				'ActionIcon', "CommonAssets/UI/Menu/DisableBaseColorMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DisableColorizationMaps == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DisableColorizationMaps")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle the height the terrain uses for blend",
				'RolloverText', "Toggle the height the terrain uses for blend",
				'ActionId', "G_ToggleTerrainHeight",
				'ActionTranslate', false,
				'ActionName', "Toggle Terrain Height",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleTerrainHeight.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.TR_ShowHeight == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("TR_ShowHeight")
								hr.TR_ForceReloadNoTextures = 1
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle color picker for screen render target (Alt-Shift-I)",
				'RolloverText', "Toggle color picker for screen render target (Alt-Shift-I)",
				'ActionId', "E_Colorpicker",
				'ActionTranslate', false,
				'ActionName', "Toggle Color picker",
				'ActionIcon', "CommonAssets/UI/Icons/color drop graphic paint picker tool.png",
				'ActionShortcut', "Alt-Shift-I",
				'OnAction', function (self, host, source, ...)
								local state = GetPostProcPredicate("debug_color_pick")
								SetPostProcPredicate("debug_color_pick", not state)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle stretch factor usage",
				'RolloverText', "Toggle stretch factor usage",
				'ActionId', "G_ToggleStretchFactorUsage",
				'ActionTranslate', false,
				'ActionName', "ToggleStretchFactorUsage",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleStretchFactor.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.DbgUseStretchFactor == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("DbgUseStretchFactor")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggleuv density",
				'RolloverText', "Toggle uv density",
				'ActionId', "G_ToggleUVDensity",
				'ActionTranslate', false,
				'ActionName', "Toggle UV Density",
				'ActionIcon', "CommonAssets/UI/Menu/ForceDiffuseMaps.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.UseCheckerboardAsBaseColor == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("UseCheckerboardAsBaseColor")
								hr.DisableBaseColorMaps = hr.UseCheckerboardAsBaseColor
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle SatGammaModifier rendering",
				'RolloverText', "Toggle SatGammaModifier rendering",
				'ActionId', "G_ToggleSatGamma",
				'ActionTranslate', false,
				'ActionName', "Toggle SatGamma Modifier",
				'ActionIcon', "CommonAssets/UI/Menu/toggle_dtm_slots.tga",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.UseSatGammaModifier ~= 0
				end,
				'OnAction', function (self, host, source, ...)
								hr.UseSatGammaModifier = 1 - hr.UseSatGammaModifier
								RecreateRenderObjects()
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Finds duplicated objects",
			'RolloverText', "Finds duplicated objects",
			'ActionId', "DbgFindOverlappingObjects",
			'ActionTranslate', false,
			'ActionName', "Find overlapping objects",
			'ActionIcon', "CommonAssets/UI/Icons/copy duplicate paste 2.png",
			'OnAction', function (self, host, source, ...)
						  ReportOverlappingObjects()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Render everything two-sided",
			'RolloverText', "Render everything two-sided",
			'ActionId', "G_ForceTwoSidedMode",
			'ActionTranslate', false,
			'ActionName', "Force two-sided mode",
			'ActionIcon', "CommonAssets/UI/Menu/ForceTwoSidedMode.tga",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.ForceTwoSidedMode == 1
			end,
			'OnAction', function (self, host, source, ...)
						  ToggleHR("ForceTwoSidedMode")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Shows/Hides the frustum",
			'RolloverText', "Shows/Hides the frustum",
			'ActionId', "DbgShowFrustum",
			'ActionTranslate', false,
			'ActionName', "Frustum",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.ShowFrustum == 1
			end,
			'OnAction', function (self, host, source, ...)
						  ToggleHR("ShowFrustum")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', " (Shift-U)",
			'RolloverText', " (Shift-U)",
			'ActionId', "G_LockCamera",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Lock Camera",
			'ActionIcon', "CommonAssets/UI/Icons/lock login padlock password safe secure.png",
			'ActionShortcut', "Shift-U",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
				return camera.IsLocked(1)
			end,
			'OnAction', function (self, host, source, ...)
				if camera.IsLocked(1) then
					camera.Unlock(1)
				else
					camera.Lock(1)
				end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', " (Ctrl-I)",
			'RolloverText', " (Ctrl-I)",
			'ActionId', "G_MoveFPSIndicator",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Move FPS Indicator",
			'ActionIcon', "CommonAssets/UI/Icons/drag move.png",
			'ActionShortcut', "Ctrl-I",
			'OnAction', function (self, host, source, ...)
						  local pos = hr.FpsCounterPos
						  pos = pos + 1
						  if pos < 4 then
							hr.FpsCounterPos = pos
						  else
							hr.FpsCounterPos = 0
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggles the object counter",
			'RolloverText', "Toggles the object counter",
			'ActionId', "DbgObjectCounter",
			'ActionTranslate', false,
			'ActionName', "Object counter",
			'ActionIcon', "CommonAssets/UI/Icons/th.png",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.ObjectCounter == 1
			end,
			'OnAction', function (self, host, source, ...)
						  ToggleHR("ObjectCounter")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Objects, Billboards & Particles",
			'ActionTranslate', false,
			'ActionName', "Objects, Billboards & Particles ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Shift-O)",
				'RolloverText', " (Ctrl-Shift-O)",
				'ActionId', "G_SimulateParticles",
				'ActionTranslate', false,
				'ActionName', "Toggle Particle Simulation",
				'ActionShortcut', "Ctrl-Shift-O",
				'OnAction', function (self, host, source, ...)
								ToggleHR("SimulateParticles")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Shift-P)",
				'RolloverText', " (Ctrl-Shift-P)",
				'ActionId', "G_RenderParticles",
				'ActionTranslate', false,
				'ActionName', "Toggle Particle Rendering",
				'ActionShortcut', "Ctrl-Shift-P",
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderParticles")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-T)",
				'RolloverText', " (Shift-T)",
				'ActionId', "G_ObjectBillboards",
				'ActionTranslate', false,
				'ActionName', "Toggle Billboards",
				'ActionShortcut', "Shift-T",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ObjectBillboards")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "G_MapObjects",
				'ActionTranslate', false,
				'ActionName', "Toggle Map Objects",
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderMapObjects")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-O)",
				'RolloverText', " (Shift-O)",
				'ActionId', "G_Outsiders",
				'ActionTranslate', false,
				'ActionName', "Toggle Outsider Objects",
				'ActionShortcut', "Shift-O",
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderOutsiders")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-N)",
				'RolloverText', " (Shift-N)",
				'ActionId', "G_RenderOBBs",
				'ActionTranslate', false,
				'ActionName', "Render Oriented Bounding Boxes",
				'ActionShortcut', "Shift-N",
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderOBBs")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-B)",
				'RolloverText', " (Shift-B)",
				'ActionId', "G_RenderBSpheres",
				'ActionTranslate', false,
				'ActionName', "Render Bounding Spheres",
				'ActionShortcut', "Shift-B",
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderBSpheres")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-C)",
				'RolloverText', " (Ctrl-C)",
				'ActionId', "G_ObjectCull",
				'ActionTranslate', false,
				'ActionName', "Toggle Object Cull",
				'ActionShortcut', "Ctrl-C",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ObjectCull")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Alt-Z)",
				'RolloverText', " (Ctrl-Alt-Z)",
				'ActionId', "G_ObjectLOD",
				'ActionTranslate', false,
				'ActionName', "Toggle Object LOD",
				'ActionShortcut', "Ctrl-Alt-Z",
				'OnAction', function (self, host, source, ...)
								if ToggleHR("VisualizeLOD") then
								  print("0 red, 1 green, 2 blue, 3 yellow, 4 pink, 5 cyan")
								end
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggles the building of render queues",
			'RolloverText', "Toggles the building of render queues",
			'ActionId', "G_TogglePauseRQ",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Pause RQ",
			'OnAction', function (self, host, source, ...)
						  ToggleHR("PauseRQ")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle postprocess (Ctrl-0)",
			'RolloverText', "Toggle postprocess (Ctrl-0)",
			'ActionId', "G_Postprocess",
			'ActionTranslate', false,
			'ActionName', "Postprocess",
			'ActionIcon', "CommonAssets/UI/Menu/toggle_post.tga",
			'ActionShortcut', "Ctrl-0",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.EnablePostprocess == 1
			end,
			'OnAction', function (self, host, source, ...)
						  ToggleHR("EnablePostprocess")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Profiler HUD",
			'ActionTranslate', false,
			'ActionName', "Profiler HUD ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Profiler HUD (Alt-Shift-0)",
				'ActionId', "ProfilerHUDEnable",
				'ActionTranslate', false,
				'ActionName', "Toggle Profiler",
				'ActionShortcut', "Alt-Shift-0",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ProfilerHUD")
								ToggleHR("EnableGPUProfiler")
								ProfilerHUD_InitColors()
								UIL.Invalidate()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Live update (Alt-Shift-9)",
				'RolloverText', " (Alt-Shift-9)",
				'ActionId', "ProfilerHUDRefresh",
				'ActionTranslate', false,
				'ActionName', "Live update",
				'ActionShortcut', "Alt-Shift-9",
				'OnAction', function (self, host, source, ...)
								if hr.ProfilerHUDRefreshInterval == 0 then
								  hr.ProfilerHUDRefreshInterval = 1000
								else
								  hr.ProfilerHUDRefreshInterval = 0
								end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Alt-Shift-8)",
				'RolloverText', " (Alt-Shift-8)",
				'ActionId', "ProfilerHUDForceCapture",
				'ActionTranslate', false,
				'ActionName', "Force capture",
				'ActionShortcut', "Alt-Shift-8",
				'OnAction', function (self, host, source, ...)
								hr.ProfilerHUDForceCapture = 1
								UIL.Invalidate()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "(Alt-Shift-6)",
				'RolloverText', "(Alt-Shift-6)",
				'ActionId', "ProfilerHUDSaveCapture",
				'ActionTranslate', false,
				'ActionName', "Save capture",
				'ActionShortcut', "Alt-Shift-6",
				'OnAction', function (self, host, source, ...)
								hr.ProfilerHUDSaveCapture = 1
								UIL.Invalidate()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "(Alt-Shift-5)",
				'RolloverText', "(Alt-Shift-5)",
				'ActionId', "ProfilerHUDAutoSaveFrameSpike",
				'ActionTranslate', false,
				'ActionName', "Auto Save Frame Spike",
				'ActionShortcut', "Alt-Shift-5",
				'OnAction', function (self, host, source, ...)
								if hr.ProfilerHUDAutoSaveCapture == 0 then
								  hr.ProfilerHUDAutoSaveCapture = 100
								elseif hr.ProfilerHUDAutoSaveCapture == 100 then
								  hr.ProfilerHUDAutoSaveCapture = 200
								elseif hr.ProfilerHUDAutoSaveCapture == 200 then
								  hr.ProfilerHUDAutoSaveCapture = 300
								elseif hr.ProfilerHUDAutoSaveCapture == 300 then
								  hr.ProfilerHUDAutoSaveCapture = 0
								end
								UIL.Invalidate()
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "G_RelativeZoom",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Relaitve Zoom",
			'OnAction', function (self, host, source, ...)
						  hr.CameraRTSRelativeZoomingMode = 1 - hr.CameraRTSRelativeZoomingMode
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Reload",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Reload ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-R)",
				'RolloverText', " (Shift-R)",
				'ActionId', "G_ReloadShaders",
				'ActionTranslate', false,
				'ActionName', "Reload Shaders",
				'ActionShortcut', "Shift-R",
				'OnAction', function (self, host, source, ...)
								ReloadShaders()
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Render targets",
			'ActionTranslate', false,
			'ActionName', "Render targets ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Shift-2)",
				'RolloverText', " (Ctrl-Shift-2)",
				'ActionId', "DbgShowRTEnable",
				'ActionTranslate', false,
				'ActionName', "Toggle RTs",
				'ActionShortcut', "Ctrl-Shift-2",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ShowRTEnable")
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Save a screenshot",
			'RolloverText', "Save a screenshot",
			'ActionId', "G_SaveScreenShot",
			'ActionTranslate', false,
			'ActionName', "Save Screenshot",
			'ActionIcon', "CommonAssets/UI/Menu/ToggleEnvMap.tga",
			'OnAction', function (self, host, source, ...)
						  local imageName = GenerateScreenshotFilename("")
						  CreateRealTimeThread(function()
							WaitNextFrame(3)
							WriteScreenshot(imageName)
							os.execute("start " .. lfs.currentdir())
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Shows/Hides the shadow frustum",
			'RolloverText', "Shows/Hides the shadow frustum",
			'ActionId', "DbgShadowShowFrustum",
			'ActionTranslate', false,
			'ActionName', "Shadow frustum",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.ShadowShowFrustum == 1
			end,
			'OnAction', function (self, host, source, ...)
						  ToggleHR("ShadowShowFrustum")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'RolloverText', "Toggles lights shadow statistics",
			'ActionId', "Render.Lights",
			'ActionTranslate', false,
			'ActionName', "Lights...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggles lights shadow statistics",
				'RolloverText', "Toggles lights shadow statistics",
				'ActionId', "DbgLightsShadowStatistics",
				'ActionTranslate', false,
				'ActionName', "Lights Shadow Stats",
				'ActionShortcut', "Alt-Shift-X",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.LightShadowsGOStatistics ~= 0
				end,
				'OnAction', function (self, host, source, ...)
								if hr.LightShadowsGOStatistics == 0 then
								  ShowLightShadowsStats(1000)
								else
								  HideLightShadowsStats()
								end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Cycle through Lights Objects",
				'RolloverText', "Cycle through Lights Objects",
				'ActionId', "CycleLightsPrev",
				'ActionTranslate', false,
				'ActionName', "Cycle through Lights(Previous)",
				'ActionShortcut', "Alt-Shift-V",
				'OnAction', function (self, host, source, ...)
								ViewNextLight(-1)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Cycle through Lights Objects",
				'RolloverText', "Cycle through Lights Objects",
				'ActionId', "CycleLightsNext",
				'ActionTranslate', false,
				'ActionName', "Cycle through Lights(Next)",
				'ActionShortcut', "Alt-V",
				'OnAction', function (self, host, source, ...)
								ViewNextLight(1)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Capture Screen Lights",
				'RolloverText', "Capture Screen Lights for cycling them",
				'ActionId', "CaptureScreenLights",
				'ActionTranslate', false,
				'ActionName', "Capture Screen Lights",
				'ActionShortcut', "Ctrl-Alt-Shift-X",
				'OnAction', function (self, host, source, ...)
								CaptureScreenLights()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Cycle through Screen Lights",
				'RolloverText', "Cycle through Lights Objects",
				'ActionId', "CycleScreenLightsPrev",
				'ActionTranslate', false,
				'ActionName', "Cycle through Screen Lights(Previous)",
				'ActionShortcut', "Alt-Shift-F",
				'OnAction', function (self, host, source, ...)
								ViewNextLight(-1, "screen lights")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Cycle through Lights",
				'RolloverText', "Cycle through Lights Objects",
				'ActionId', "CycleScreenLightsNext",
				'ActionTranslate', false,
				'ActionName', "Cycle through Screen Lights(Next)",
				'ActionShortcut', "Alt-F",
				'OnAction', function (self, host, source, ...)
								ViewNextLight(1, "screen lights")
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', " (0)",
			'RolloverText', " (0)",
			'ActionId', "G_Statistics",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Show Statistics",
			'ActionShortcut', "0",
			'ActionShortcut2', "Alt-0",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.RenderStatistics ~= 0
			end,
			'OnAction', function (self, host, source, ...)
						  local stats = config.RenderStatistics or {
							0,
							5,
							-1
						  }
						  local i = table.find(stats, hr.RenderStatistics)
						  if i then
							hr.RenderStatistics = stats[i + 1] or stats[1]
						  else
							hr.RenderStatistics = hr.RenderStatistics == 0 and -1 or 0
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', " (0)",
			'RolloverText', " (0)",
			'ActionId', "Histograms",
			'ActionTranslate', false,
			'ActionName', "Show Histograms",
			'OnAction', function (self, host, source, ...)
						  ToggleHistogram()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Override DIPs to consist of a single triangle (Ctrl-Shift-1)",
			'RolloverText', "Override DIPs to consist of a single triangle (Ctrl-Shift-1)",
			'ActionId', "G_RenderSingleTriangle",
			'ActionTranslate', false,
			'ActionName', "Single Triangle DIPs",
			'ActionIcon', "CommonAssets/UI/Menu/RenderSingleTriangle.tga",
			'ActionShortcut', "Ctrl-Shift-1",
			'OnAction', function (self, host, source, ...)
						  if hr.PrimitiveCountModifier == 1 then
							hr.PrimitiveCountModifier = -100
						  else
							hr.PrimitiveCountModifier = 1
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Shows render statistics",
			'RolloverText', "Shows render statistics",
			'ActionId', "DbgSubsystemsRenderCosts",
			'ActionTranslate', false,
			'ActionName', "Subsystems render costs",
			'OnAction', function (self, host, source, ...)
						  CreateMapRealTimeThread(function()
							local Print100f = function(v)
							  local str = ""
							  str = str .. v / 100
							  v = abs(v - v / 100 * 100)
							  str = str .. "." .. v / 10
							  v = v - v / 10 * 10
							  str = str .. v
							  return str
							end
							local GetMs100 = function()
							  local ms = hr.RenderStatsFrameTimeGPU
							  return ms * 100
							end
							local WaitRenderFrames = function(ms, weight100)
							  weight100 = weight100 or 10
							  local t0 = GetClock()
							  local time = 0
							  local ms100 = 0
							  local arr = {}
							  local frame = 1
							  WaitNextFrame(hr.RenderStatsSmoothing)
							  while ms > time do
								WaitNextFrame()
								arr[frame] = GetMs100()
								time = GetClock() - t0
								frame = frame + 1
								if 30 < frame then
								  frame = 1
								end
							  end
							  ms100 = 0
							  for i = 1, #arr do
								ms100 = ms100 + arr[i]
							  end
							  ms100 = ms100 / #arr
							  return ms100
							end
							local saved_value = false
							local tests = {
							  {
								name = "Post processing",
								start = function()
								  hr.EnablePostprocess = 0
								end,
								finish = function()
								  hr.EnablePostprocess = 1
								end
							  },
							  {
								name = "Particles",
								start = function()
								  hr.RenderParticles = 0
								end,
								finish = function()
								  hr.RenderParticles = 1
								end
							  },
							  {
								name = "Transparents",
								start = function()
								  hr.RenderTransparent = 0
								end,
								finish = function()
								  hr.RenderTransparent = 1
								end
							  },
							  {
								name = "Billboards",
								start = function()
								  hr.RenderBillboards = 0
								end,
								finish = function()
								  hr.RenderBillboards = 1
								end
							  },
							  {
								name = "Objects",
								start = function()
								  hr.RenderMapObjects = 0
								end,
								finish = function()
								  hr.RenderMapObjects = 1
								end
							  },
							  {
								name = "Streaming",
								start = function()
								  hr.StreamingForceFallbacks = 1
								end,
								finish = function()
								  hr.StreamingForceFallbacks = 0
								end
							  },
							  {
								name = "Shadowmap",
								start = function()
								  hr.Shadowmap = 0
								end,
								finish = function()
								  hr.Shadowmap = 1
								end
							  },
							  {
								name = "Shadowmap 1k",
								start = function()
								  saved_value = hr.ShadowmapSize
								  hr.ShadowmapSize = 1024
								end,
								finish = function()
								  hr.ShadowmapSize = saved_value
								end
							  },
							  {
								name = "Shadowmap 880",
								start = function()
								  saved_value = hr.ShadowmapSize
								  hr.ShadowmapSize = 880
								end,
								finish = function()
								  hr.ShadowmapSize = saved_value
								end
							  },
							  {
								name = "Skinned objects",
								start = function()
								  hr.RenderSkinned = 0
								end,
								finish = function()
								  hr.RenderSkinned = 1
								end
							  },
							  {
								name = "Decals",
								start = function()
								  hr.RenderDecals = 0
								end,
								finish = function()
								  hr.RenderDecals = 1
								end
							  }
							}
							print("Render subsystems test started (" .. #tests .. " tests) - please wait...")
							local saved_preciseselection = hr.EnablePreciseSelection
							hr.EnablePreciseSelection = 0
							local frame_ms = WaitRenderFrames(12000, 5)
							print("   0. Whole frame: " .. Print100f(frame_ms) .. " ms - " .. 1000 / (frame_ms / 100) .. " fps")
							for i = 1, #tests do
							  tests[i].start()
							  local ms = WaitRenderFrames(10000, 10)
							  local diff = frame_ms - ms
							  local percent = diff * 100 / frame_ms
							  print("   " .. i .. ". " .. tests[i].name .. ":      " .. Print100f(diff) .. " ms      " .. percent .. " %")
							  tests[i].finish()
							  WaitRenderFrames(2000)
							end
							print("done.")
							hr.EnablePreciseSelection = saved_preciseselection
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Surfaces",
			'ActionTranslate', false,
			'ActionName', "Surfaces ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Collisions (Ctrl-Shift-K)",
				'RolloverText', "Toggle Collisions (Ctrl-Shift-K)",
				'ActionId', "G_ToggleCollisions",
				'ActionTranslate', false,
				'ActionName', "Toggle Collisions",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleCollisions.tga",
				'ActionShortcut', "Ctrl-Shift-K",
				'OnAction', function (self, host, source, ...)
								if hr.ShowCollisionSurfaces == 0 and hr.ShowColliders == 0 then
								  print("Showing collision surfaces")
								  hr.ShowCollisionSurfaces = 1
								elseif hr.ShowCollisionSurfaces ~= 0 and 0 < const.maxCollidersPerObject then
								  print("Showing colliders")
								  hr.ShowCollisionSurfaces = 0
								  hr.ShowColliders = -1
								  OpenDialog("CollisionsLegend")
								else
								  print("Collision display off")
								  hr.ShowColliders = 0
								  hr.ShowCollisionSurfaces = 0
								  CloseDialog("CollisionsLegend")
								end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Walk (Ctrl-Shift-L)",
				'RolloverText', "Toggle Walk (Ctrl-Shift-L)",
				'ActionId', "G_ToggleWalk",
				'ActionTranslate', false,
				'ActionName', "Toggle Walk",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleWalk.tga",
				'ActionShortcut', "Ctrl-Shift-L",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ShowWalk")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle BlockPass (Shift-K)",
				'RolloverText', "Toggle BlockPass (Shift-K)",
				'ActionId', "G_ToggleBlockPass",
				'ActionTranslate', false,
				'ActionName', "Toggle BlockPass",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleBlockPass.tga",
				'ActionShortcut', "Shift-K",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ShowBlockPass")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Build",
				'RolloverText', "Toggle Build",
				'ActionId', "G_ToggleBuild",
				'ActionTranslate', false,
				'ActionName', "Toggle Build",
				'ActionIcon', "CommonAssets/UI/Menu/ToggleWalk.tga",
				'OnAction', function (self, host, source, ...)
								ToggleHR("ShowBuildSurfaces")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "(Ctrl-Shift-9)",
				'ActionId', "G_DebugDrawTunnels",
				'ActionTranslate', false,
				'ActionName', "Toggle Tunnels",
				'ActionShortcut', "Ctrl-Shift-9",
				'OnAction', function (self, host, source, ...)
								ToggleDrawTunnels()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "(Ctrl-Alt-9)",
				'ActionId', "G_TunnelHelpers",
				'ActionTranslate', false,
				'ActionName', "Tunnel Helpers",
				'ActionIcon', "CommonAssets/UI/Menu/object_options.tga",
				'ActionShortcut', "Ctrl-Alt-9",
				'OnAction', function (self, host, source, ...)
								local tunnels = 0
								MapForEach("map", "SlabTunnel", function(tunnel)
								  local helper = PlaceObject("SlabTunnelHelper")
								  helper:SetPos(tunnel:GetPos())
								  helper.tunnel = tunnel
								  if tunnel.dbg_tunnel_color then
									helper:SetColorModifier(tunnel.dbg_tunnel_color)
								  end
								  helper:SetScale(35)
								  tunnels = tunnels + 1
								end)
								print(string.format("%d Tunnel helpers created", tunnels))
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "G_PathDebugDraw",
				'ActionTranslate', false,
				'ActionName', "Toggle Path",
				'OnAction', function (self, host, source, ...)
								if hr.TerrainDebugDraw == 1 and DbgGetTerrainOverlay() == "path" and 1 < terrain.GetPassGridsCount() then
								  DbgSetTerrainOverlay("path_large")
								  print("path_large")
								else
								  DbgSetTerrainOverlay("path")
								  print("path")
								  ToggleHR("TerrainDebugDraw")
								  if hr.TerrainDebugDraw == 0 then
									pf.DbgDrawFindPath()
								  end
								end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-8)",
				'RolloverText', " (Ctrl-8)",
				'ActionId', "G_WindDebugDraw",
				'ActionTranslate', false,
				'ActionName', "Toggle Wind",
				'ActionShortcut', "Ctrl-8",
				'OnAction', function (self, host, source, ...)
								DbgDrawWind(not g_DebugWindDraw)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Shift-8)",
				'RolloverText', " (Ctrl-Shift-8)",
				'ActionId', "G_WindDebugDrawTexts",
				'ActionTranslate', false,
				'ActionName', "Toggle Wind + Numbers",
				'ActionShortcut', "Ctrl-Shift-8",
				'OnAction', function (self, host, source, ...)
								DbgDrawWind(not g_DebugWindDraw, "texts")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Alt-8)",
				'RolloverText', " (Ctrl-Alt-8)",
				'ActionId', "G_WindDebugDrawTextsTiles",
				'ActionTranslate', false,
				'ActionName', "Toggle Wind + Numbers + Tiles",
				'ActionShortcut', "Ctrl-Alt-8",
				'OnAction', function (self, host, source, ...)
								DbgDrawWind(not g_DebugWindDraw, "texts", "show tiles around cursor")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-9)",
				'RolloverText', " (Ctrl-9)",
				'ActionId', "G_TerrainDebugDraw",
				'ActionTranslate', false,
				'ActionName', "Toggle Passability",
				'ActionShortcut', "Ctrl-9",
				'OnAction', function (self, host, source, ...)
								if hr.TerrainDebugDraw == 0 then
								  DbgSetTerrainOverlay("passability")
								  EnablePassability3DVisualization(true)
								  hr.TerrainDebugDraw = 1
								else
								  EnablePassability3DVisualization(false)
								  hr.TerrainDebugDraw = 0
								end
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', " (Shift-C)",
			'RolloverText', " (Shift-C)",
			'ActionId', "G_CameraChange",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Toggle Camera Type",
			'ActionShortcut', "Shift-C",
			'OnAction', function (self, host, source, ...)
						  CheatToggleFlyCamera()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Render.Toggle Render",
			'ActionTranslate', false,
			'ActionName', "Toggle Render ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggles the rendering of the shadows",
				'RolloverText', "Toggles the rendering of the shadows",
				'ActionId', "DbgRenderShadows",
				'ActionTranslate', false,
				'ActionName', "Shadow",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.Shadowmap == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("Shadowmap")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggles the rendering of the objects",
				'RolloverText', "Toggles the rendering of the objects",
				'ActionId', "DbgRenderObjects",
				'ActionTranslate', false,
				'ActionName', "Objects",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.RenderMapObjects == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderMapObjects")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggles the rendering of the BSpheres",
				'RolloverText', "Toggles the rendering of the BSpheres",
				'ActionId', "DbgShowBSpheres",
				'ActionTranslate', false,
				'ActionName', "BSpheres",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.RenderBSpheres == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderBSpheres")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggles the rendering of the billboards",
				'RolloverText', "Toggles the rendering of the billboards",
				'ActionId', "DbgRenderBillboards",
				'ActionTranslate', false,
				'ActionName', "Billboards",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.RenderBillboards == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("RenderBillboards")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggles the rendering of the terrain bounding boxes",
				'RolloverText', "Toggles the rendering of the terrain bounding boxes",
				'ActionId', "DbgShowTerrainBBoxes",
				'ActionTranslate', false,
				'ActionName', "Terrain bboxes",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
								return hr.TerrainAABB == 1
				end,
				'OnAction', function (self, host, source, ...)
								ToggleHR("TerrainAABB")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Shift-Z)",
				'RolloverText', " (Shift-Z)",
				'ActionId', "G_Shadowmap",
				'ActionTranslate', false,
				'ActionName', "Toggle Shadowmap",
				'ActionShortcut', "Shift-Z",
				'OnAction', function (self, host, source, ...)
								ToggleHR("Shadowmap")
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Safearea Lines",
			'RolloverText', "Toggle Safearea Lines",
			'ActionId', "G_ToggleSafeareaLines",
			'ActionTranslate', false,
			'ActionName', "Toggle Safearea Lines",
			'OnAction', function (self, host, source, ...)
						  ToggleSafearea()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Obj Mask Mode",
			'ActionId', "DbgToggleObjMaskMode",
			'ActionTranslate', false,
			'ActionName', "Toggle Obj Mask Mode",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.DeferMode == DeferModes.OBJ_MASK
			end,
			'OnAction', function (self, host, source, ...)
						  if hr.DeferMode ~= DeferModes.OBJ_MASK then
							OpenDevDSForceModeDlg("OBJ_MASK")
						  else
							CloseDialog("DevDSForceModeDlg")
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Skinned Decal Space",
			'ActionId', "DbgToggleToggleSkinnedDecalSpace",
			'ActionTranslate', false,
			'ActionName', "Toggle Skinned Decal Space",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.ShowSkinnedDecalSpace ~= 0
			end,
			'OnAction', function (self, host, source, ...)
						  hr.ShowSkinnedDecalSpace = 1 - hr.ShowSkinnedDecalSpace
			end,
			'replace_matching_id', true,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Tests",
		'ActionTranslate', false,
		'ActionName', "Tests",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'ActionId', "Danger",
			'ActionTranslate', false,
			'ActionName', "Save your Game before using this!",
			'ActionIcon', "CommonAssets/UI/Icons/caution danger exclamation",
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Destruction Test",
			'ActionId', "DE_TestCarpetBomb",
			'ActionTranslate', false,
			'ActionName', "Test Carpet Bomb",
			'ActionIcon', "CommonAssets/UI/Icons/auto car transport transportation vehicle",
			'ActionShortcut', "Ctrl-Numpad /",
			'OnAction', function (self, host, source, ...)
				DbgCarpetExplosionDamage("bomb")
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "OnMouse",
			'ActionTranslate', false,
			'ActionName', "Will be applied at the Cursor",
			'ActionIcon', "CommonAssets/UI/Icons/caution danger exclamation",
		}),
		PlaceObj('XTemplateAction', {
			'comment', "molotov test",
			'ActionId', "DE_TestMolotov",
			'ActionTranslate', false,
			'ActionName', "Test Molotov",
			'ActionIcon', "CommonAssets/UI/Icons/alcohol beverage bottle drink glass wine",
			'ActionShortcut', "Ctrl-Numpad *",
			'OnAction', function (self, host, source, ...)
				CreateGameTimeThread(DbgIncendiaryExplosion)
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Bullet Impact Test",
			'ActionId', "DE_TestShoot",
			'ActionTranslate', false,
			'ActionName', "Test Shoot",
			'ActionIcon', "CommonAssets/UI/Icons/bullseye focus goal target",
			'ActionShortcut', "Ctrl-Numpad +",
			'OnAction', function (self, host, source, ...)
				CreateGameTimeThread(DbgBulletDamage)
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Bullet Destruction Test",
			'ActionId', "DE_TestShootDamage",
			'ActionTranslate', false,
			'ActionName', "Test Shoot Damage",
			'ActionIcon', "CommonAssets/UI/Icons/bullseye focus goal target",
			'ActionShortcut', "Ctrl-Numpad ,",
			'OnAction', function (self, host, source, ...)
				CreateGameTimeThread(DbgBulletDamage, nil, 10000)
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Destruction Test",
			'ActionId', "DE_TestExplode",
			'ActionTranslate', false,
			'ActionName', "Test Explode",
			'ActionIcon', "CommonAssets/UI/Icons/bullseye focus goal target",
			'ActionShortcut', "Ctrl-Numpad -",
			'OnAction', function (self, host, source, ...)
				CreateGameTimeThread(DbgExplosionFX)
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Destruction Test Display Range",
			'ActionId', "DE_TestExplodeToggleRange",
			'ActionTranslate', false,
			'ActionName', "Test Explode Toggle Range",
			'ActionIcon', "CommonAssets/UI/Icons/bullseye focus goal target",
			'ActionShortcut', "]",
			'OnAction', function (self, host, source, ...)
				DbgExplosionFX_ShowRange = not DbgExplosionFX_ShowRange
			end,
			'__condition', function (parent, context)
				return Platform.developer or Platform.trailer
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle CMT",
			'RolloverText', "Quick Test Ambient Life",
			'ActionId', "ToggleCMT",
			'ActionTranslate', false,
			'ActionName', "ToggleCMT",
			'ActionIcon', "CommonAssets/UI/Icons/map.png",
			'ActionShortcut', "Alt-Shift-H",
			'OnAction', function (self, host, source, ...)
				ToggleVisibilitySystems("ActionShortcut")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Hide Combat UI",
			'RolloverText', "Hide Combat UI",
			'ActionId', "G_HideCombatUI",
			'ActionTranslate', false,
			'ActionName', "Hide Combat UI",
			'ActionIcon', "CommonAssets/UI/Icons/analytics presentation report slideshow",
			'ActionShortcut', "Shift-I",
			'OnAction', function (self, host, source, ...)
				PlaybackNetSyncEvent("CheatEnable", "CombatUIHidden")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Hide optional combat UI",
			'RolloverText', "Hide optional combat UI",
			'ActionId', "G_HideOptionalCombatUI",
			'ActionTranslate', false,
			'ActionName', "Hide optional combat UI",
			'ActionIcon', "CommonAssets/UI/Icons/analytics presentation report slideshow",
			'ActionShortcut', "Shift-L",
			'OnAction', function (self, host, source, ...)
				PlaybackNetSyncEvent("CheatEnable", "OptionalUIHidden")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Hide Replay UI",
			'RolloverText', "Hide Replay UI",
			'ActionId', "G_HideReplayUI",
			'ActionTranslate', false,
			'ActionName', "Hide Replay UI",
			'ActionIcon', "CommonAssets/UI/Icons/analytics presentation report slideshow",
			'ActionShortcut', "Shift-J",
			'OnAction', function (self, host, source, ...)
				PlaybackNetSyncEvent("CheatEnable", "ReplayUIHidden")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Hide In-World Combat UI",
			'RolloverText', "Hide In-World Combat UI",
			'ActionId', "G_HideWorldCombatUI",
			'ActionTranslate', false,
			'ActionName', "Hide In-World Combat UI",
			'ActionIcon', "CommonAssets/UI/Icons/analytics presentation report slideshow",
			'ActionShortcut', "Shift-Y",
			'OnAction', function (self, host, source, ...)
				PlaybackNetSyncEvent("CheatEnable", "IWUIHidden")
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Load last save",
			'RolloverText', "Load Last Save (Ctrl-Alt-F5)",
			'ActionId', "DE_LoadLastSave",
			'ActionTranslate', false,
			'ActionName', "Load Last Save",
			'ActionIcon', "CommonAssets/UI/Icons/document note paper.png",
			'ActionShortcut', "Ctrl-Alt-F5",
			'OnAction', function (self, host, source, ...)
						  CreateRealTimeThread(function()
							local last_save = LocalStorage.last_save or ""
							if last_save == "" then
							  return
							end
							CloseMenuDialogs()
							LoadGame(last_save)
						  end)
			end,
			'replace_matching_id', true,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Tools",
		'ActionTranslate', false,
		'ActionName', "Tools",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'ActionId', "Tools.Extras",
			'ActionTranslate', false,
			'ActionName', "Extras ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Write screenshot (-PrtScr)",
				'RolloverText', "Write screenshot (-PrtScr)",
				'ActionId', "DE_Screenshot",
				'ActionTranslate', false,
				'ActionName', "Screenshot",
				'ActionIcon', "CommonAssets/UI/Icons/camera",
				'ActionShortcut', "-PrtScr",
				'OnAction', function (self, host, source, ...)
					WriteScreenshot(GenerateScreenshotFilename("SS", "AppData/"))
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Isolated object screenshot (-Ctrl-Alt-PrtScr)",
				'RolloverText', "Isolated object screenshot (-Ctrl-Alt-PrtScr)",
				'ActionId', "DE_Isolated_Object_Screenshot",
				'ActionTranslate', false,
				'ActionName', "Isolated Object Screenshot",
				'ActionIcon', "CommonAssets/UI/Icons/camera",
				'ActionShortcut', "-Ctrl-Alt-PrtScr",
				'OnAction', function (self, host, source, ...)
					IsolatedObjectScreenshot()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle UI in screenshots (-Ctrl-Shift-PrtScr)",
				'RolloverText', "Toggle UI in screenshots (-Ctrl-Shift-PrtScr)",
				'ActionId', "DE_ToggleScreenshotInterface",
				'ActionTranslate', false,
				'ActionName', "Toggle UI in screenshots",
				'ActionIcon', "CommonAssets/UI/Icons/camera outline",
				'ActionShortcut', "-Ctrl-Shift-PrtScr",
				'OnAction', function (self, host, source, ...)
					hr.InterfaceInScreenshot = hr.InterfaceInScreenshot ~= 0 and 0 or 1
					print("UI in screenshots is now", hr.InterfaceInScreenshot ~= 0 and "enabled" or "disabled")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Write upsampled screenshot (-Ctrl-PrtScr)",
				'RolloverText', "Write upsampled screenshot (-Ctrl-PrtScr)",
				'ActionId', "DE_UpsampledScreenshot",
				'ActionTranslate', false,
				'ActionName', "Upsampled Screenshot",
				'ActionIcon', "CommonAssets/UI/Icons/camera digital image media photo photography picture",
				'ActionShortcut', "-Ctrl-PrtScr",
				'OnAction', function (self, host, source, ...)
					if Platform.developer then
						CreateRealTimeThread(function()
						WaitNextFrame(3)
						LockCamera("Screenshot")
						local store = {}
						Msg("BeforeUpsampledScreenshot", store)
						WaitNextFrame()
						MovieWriteScreenshot(GenerateScreenshotFilename("SSAA", "AppData/"), 0, 64, false)
						WaitNextFrame()
						Msg("AfterUpsampledScreenshot", store)
						UnlockCamera("Screenshot")
					end)
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Report Bug (Ctrl-F1)",
				'RolloverText', "Report Bug (Ctrl-F1)",
				'ActionId', "DE_BugReport",
				'ActionTranslate', false,
				'ActionName', "Report Bug",
				'ActionIcon', "CommonAssets/UI/Icons/bacteria bug insect protection security virus.png",
				'ActionShortcut', "Ctrl-F1",
				'OnAction', function (self, host, source, ...)
					CreateRealTimeThread(CreateXBugReportDlg)
				end,
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "Dump All Shortcuts to a File",
			'RolloverText', "Dump All Shortcuts to a File",
			'ActionId', "ShortcutsViewer",
			'ActionTranslate', false,
			'ActionName', "Shortcuts Viewer",
			'ActionIcon', "CommonAssets/UI/Icons/bullet list.png",
			'ActionState', function (self, host)
				if Platform.developer then
					return
				end
					return "hidden"
			end,
			'OnAction', function (self, host, source, ...)
				XDumpShortcuts()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Enter/Exit Editor (F3)",
			'RolloverText', "Editor mode (F3)",
			'ActionId', "MO_Editor",
			'ActionTranslate', false,
			'ActionName', "Enter/Exit Editor",
			'ActionIcon', "CommonAssets/UI/Icons/door emergency enter entry exit login.png",
			'ActionShortcut', "F3",
			'OnAction', function (self, host, source, ...)
						  ToggleEnterExitEditor()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "DE_EditConfig",
			'ActionTranslate', false,
			'ActionName', "Edit config.lua",
			'ActionIcon', "CommonAssets/UI/Icons/create edit.png",
			'OnAction', function (self, host, source, ...)
						  CreateRealTimeThread(function()
							OpenGedApp("GedFileEditor", false, {
							  file_name = "config.lua"
							})
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Showcase",
			'ActionId', "DevShowcase",
			'ActionTranslate', false,
			'ActionName', "Showcase",
			'ActionIcon', "CommonAssets/UI/Icons/presentation slideshow video.png",
			'ActionMouseBindable', false,
			'OnAction', function (self, host, source, ...)
						  if GetDialog("Showcase") then
							CloseDialog("Showcase")
						  else
							OpenDialog("Showcase")
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Clear ignored errors",
			'RolloverText', "Clear ignored errors",
			'ActionId', "Clear Ignored Errors",
			'ActionTranslate', false,
			'ActionName', "Clear Ignored Errors",
			'ActionIcon', "CommonAssets/UI/Icons/bathroom commode restroom toilet washroom.png",
			'OnAction', function (self, host, source, ...)
						  ClearIgnoredErrors()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Describe Storybits",
			'RolloverText', "Describe Storybits",
			'ActionId', "Describe Storybits",
			'ActionTranslate', false,
			'ActionName', "Describe Storybits",
			'ActionIcon', "CommonAssets/UI/Icons/book.png",
			'OnAction', function (self, host, source, ...)
						  DescribeStoryBits()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Show decals",
			'RolloverText', "Show decals",
			'ActionId', "G_ShowDecals",
			'ActionTranslate', false,
			'ActionName', "Show Decals",
			'ActionIcon', "CommonAssets/UI/Icons/art brush creative design graphic paint.png",
			'ActionToggle', true,
			'ActionToggled', function (self, host)
						  return hr.DecalsRenderBoxes == 1
			end,
			'OnAction', function (self, host, source, ...)
						  hr.DecalsRenderBoxes = 1 - hr.DecalsRenderBoxes
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Copy Camera Location to Clipboard",
			'RolloverText', "Copy Camera Location to Clipboard",
			'ActionId', "Copy Camera Location to Clipboard",
			'ActionTranslate', false,
			'ActionName', "Copy Camera Location to Clipboard",
			'ActionIcon', "CommonAssets/UI/Icons/camera digital image media photo photography picture",
			'ActionShortcut', "Ctrl-Alt-F1",
			'OnAction', function (self, host, source, ...)
						  local camera_string = GetCameraLocationString()
						  CopyToClipboard(camera_string)
						  print("Copied to clipboard: ", camera_string)
			end,
			'replace_matching_id', true,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Map",
		'ActionTranslate', false,
		'ActionName', "Map",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'comment', "Change Map (Ctrl-F6)",
			'RolloverText', "Change Map (Ctrl-F6)",
			'ActionId', "DE_ChangeMap",
			'ActionTranslate', false,
			'ActionName', "Change Map",
			'ActionIcon', "CommonAssets/UI/Icons/chart map paper sheet travel.png",
			'ActionShortcut', "Ctrl-F6",
			'OnAction', function (self, host, source, ...)
				if IsMessageBoxOpen(self.ActionId) then
					return
				end
				CreateRealTimeThread(function()
					local caption = "Choose map:"
					local maps = table.ifilter(ListMaps(), function(idx, map)
					return not IsOldMap(map)
					end)
					table.insert(maps, 1, "")
					local parent_container = XWindow:new({}, terminal.desktop)
					parent_container:SetScaleModifier(point(1250, 1250))
					local map = WaitListChoice(parent_container, maps, caption, GetMapName(), nil, nil, self.ActionId)
					if not map then
					return
					end
					local editor_mode = Platform.editor and IsEditorActive()
					XShortcutsSetMode("Game")
					CloseMenuDialogs()
					Msg("DevUIMapChangePrep", map)
					ChangeMap(map, true)
					if editor_mode then
					EditorActivate()
					end
				end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Reload Map (Ctrl-F5)",
			'RolloverText', "Reload Map (Ctrl-F5)",
			'ActionId', "DE_ReloadMap",
			'ActionTranslate', false,
			'ActionName', "Reload Map",
			'ActionIcon', "CommonAssets/UI/Icons/loop refresh restart.png",
			'ActionShortcut', "Ctrl-F5",
			'OnAction', function (self, host, source, ...)
				if mapdata and mapdata.GameLogic then
					CloseMenuDialogs()
				end
				DevReloadMap()
			end,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Load Map from Backup (Shift-F5)",
			'RolloverText', "Load Map from Backup (Shift-F5)",
			'ActionId', "DE_LoadFromBackup",
			'ActionTranslate', false,
			'ActionName', "Load from backup",
			'ActionIcon', "CommonAssets/UI/Icons/anticlockwise backup history recent time.png",
			'ActionShortcut', "Shift-F5",
			'OnAction', function (self, host, source, ...)
						  if IsMessageBoxOpen(self.ActionId) then
							return
						  end
						  CreateRealTimeThread(function()
							local caption = "Choose map:"
							local prefix = "EditorBackup/" .. LocalStorage.last_map
							local _, maps = AsyncListFiles("EditorBackup", "*", "folders")
							maps = table.ifilter(maps, function(k, v)
							  return v:sub(1, #prefix) == prefix
							end)
							local default_selection = table.find(maps, GetMapName())
							local map = WaitListChoice(nil, maps, caption, default_selection, nil, nil, self.ActionId)
							if not map or map == "" then
							  return
							end
							local ineditor = Platform.editor and IsEditorActive()
							XShortcutsSetMode("Game")
							local restore_path = "Maps/__restore_from_backup"
							AsyncCreatePath(restore_path)
							local _, old_files = AsyncListFiles(restore_path, "*")
							AsyncFileDelete(old_files)
							local _, new_files = AsyncListFiles(map, "*")
							for i = 1, #new_files do
							  local dir, file, ext = SplitPath(new_files[i])
							  AsyncCopyFile(new_files[i], string.format("%s/%s.%s", restore_path, file, ext))
							end
							ChangeMap("__restore_from_backup")
							if ineditor then
							  EditorActivate()
							end
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Go to empty Map (Ctrl-Shift-F5)",
			'RolloverText', "Go to empty Map (Ctrl-Shift-F5)",
			'ActionId', "DE_LoadEmptyMap",
			'ActionTranslate', false,
			'ActionName', "Load Empty Map",
			'ActionIcon', "CommonAssets/UI/Icons/document note paper.png",
			'ActionShortcut', "Ctrl-Shift-F5",
			'OnAction', function (self, host, source, ...)
						  CreateRealTimeThread(function()
							CloseMenuDialogs()
							ChangeMap("__Empty", true)
							XShortcutsSetMode("Game")
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Map.POC_Maps",
			'ActionTranslate', false,
			'ActionName', "POC Maps ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateForEach', {
				'array', function (parent, context)
								return Presets.MapDataPreset.RandomMap
				end,
				'condition', function (parent, context, item, i)
								return string.match(item.id:lower(), "^.*alt(%d*)$")
				end,
				'run_after', function (child, context, item, i, n, last)
								local num = string.match(item.id:lower(), "^.*alt(%d*)$")
								child.ActionId = item.id
								child.ActionName = item.id
								num = tonumber(num)
								if 0 <= num and num < 10 then
								  child.ActionShortcut = string.format("Alt-%d", num)
								end
				end,
			}, {
				PlaceObj('XTemplateAction', {
					'ActionTranslate', false,
					'ActionIcon', "CommonAssets/UI/Icons/chart map paper sheet travel.png",
					'OnAction', function (self, host, source, ...)
									  CheatChangeMap(self.ActionId)
					end,
				}),
				}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionTranslate', false,
			'ActionName', "-----",
			'ActionIcon', "CommonAssets/UI/Icons/cancel close cross delete remove trash.png",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Map.Generate",
			'ActionTranslate', false,
			'ActionName', "Generate ...",
			'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "MarkerViewer",
			'ActionTranslate', false,
			'ActionName', "Marker Viewer",
			'ActionIcon', "CommonAssets/UI/Icons/flag marker nation.png",
			'OnAction', function (self, host, source, ...)
						  OpenMarkerViewer()
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "RoomEditor",
			'ActionTranslate', false,
			'ActionName', "Room Editor",
			'ActionIcon', "CommonAssets/UI/Icons/building office.png",
			'ActionShortcut', "Ctrl-Shift-R",
			'OnAction', function (self, host, source, ...)
						  OpenGedRoomEditor()
			end,
			'__condition', function (parent, context)
						  return const.SlabSizeX
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Map.ValidateMapObjects",
			'ActionTranslate', false,
			'ActionName', "Validate Map Objects (thorough)",
			'ActionIcon', "CommonAssets/UI/Icons/alert attention danger error warning.png",
			'OnAction', function (self, host, source, ...)
						  ValidateMapObjects({validate_properties = true})
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Map.ValidateMaps",
			'ActionTranslate', false,
			'ActionName', "Validate All Maps (fast)",
			'ActionIcon', "CommonAssets/UI/Icons/alert attention danger error warning.png",
			'OnAction', function (self, host, source, ...)
						  CreateRealTimeThread(WaitValidateAllMaps, {
							validate_properties = true,
							validate_Object = true,
							validate_CObject = false
						  })
			end,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Collections Editor (Ctrl-Alt-C)",
			'RolloverText', "Collections Editor (Ctrl-Alt-C)",
			'ActionId', "E_CollectionsEditor",
			'ActionTranslate', false,
			'ActionName', "Collections Editor",
			'ActionIcon', "CommonAssets/UI/Icons/cabinet cupboard drawer furniture interior.png",
			'ActionShortcut', "Ctrl-Alt-C",
			'OnAction', function (self, host, source, ...)
						  OpenCollectionsEditor()
			end,
			'replace_matching_id', true,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'ActionId', "Debug",
		'ActionTranslate', false,
		'ActionName', "Debug",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'ActionId', "actionTurboSpeedStart",
			'ActionTranslate', false,
			'ActionName', 'Turbo speed on (Hold "/" Instead)',
			'ActionShortcut', "/",
			'ActionShortcut2', "Numpad /",
			'ActionMouseBindable', false,
			'OnAction', function (self, host, source, ...)
				TurboSpeed(true)
			end,
			'IgnoreRepeated', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Memory allocation test",
			'RolloverText', "Memory allocation test",
			'ActionId', "DE_MemoryAllocationTest",
			'ActionTranslate', false,
			'ActionName', "Memory allocation test",
			'ActionIcon', "CommonAssets/UI/Icons/dashboard grid layout view.png",
			'OnAction', function (self, host, source, ...)
				dbgMemoryAllocationTest()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "actionTurboSpeedEnd",
			'ActionTranslate', false,
			'ActionName', "Turbo speed off",
			'ActionShortcut', "-/",
			'ActionShortcut2', "-Numpad /",
			'ActionMouseBindable', false,
			'OnAction', function (self, host, source, ...)
				TurboSpeed(false)
			end,
			'IgnoreRepeated', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Console Log",
			'RolloverText', "Toggle Console Log",
			'ActionId', "DE_ConsoleLogToggle",
			'ActionTranslate', false,
			'ActionName', "Toggle Console Log",
			'ActionIcon', "CommonAssets/UI/Icons/clipboard document paper report sheet.png",
			'ActionShortcut', "Ctrl-L",
			'OnAction', function (self, host, source, ...)
						  dlgConsoleLog:SetVisible(not dlgConsoleLog:GetVisible())
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Clear screen (F9)",
			'RolloverText', "Clear the Log",
			'ActionId', "DE_ClearScreenLog",
			'ActionTranslate', false,
			'ActionName', "Clear Screen (Log)",
			'ActionIcon', "CommonAssets/UI/Icons/bathroom commode restroom toilet washroom",
			'ActionShortcut', "F9",
			'OnAction', function (self, host, source, ...)
				cls()
				DbgClear()
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Inspect a live XWindow, its children, properties, focus, mouse target, etc. (Alt-X)",
			'RolloverText', "Inspect a live XWindow, its children, properties, focus, mouse target, etc. (Alt-X)",
			'ActionId', "DE_XWindowInspector",
			'ActionTranslate', false,
			'ActionName', "XWindow Inspector",
			'ActionIcon', "CommonAssets/UI/Icons/information mark question.png",
			'ActionShortcut', "Alt-X",
			'OnAction', function (self, host, source, ...)
						  OpenXWindowInspector({
							EditorShortcut = self.ActionShortcut
						  })
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Open the XTemplate the current window was spawned for in the XTemplate Editor",
			'RolloverText', "Open the XTemplate the current window was spawned for in the XTemplate Editor.",
			'ActionId', "DE_XTemplateEdit",
			'ActionTranslate', false,
			'ActionName', "Edit in XTemplate Editor",
			'ActionIcon', "CommonAssets/UI/Icons/menu outline th",
			'ActionShortcut', "Ctrl-Alt-X",
			'OnAction', function (self, host, source, ...)
						  CreateRealTimeThread(function()
							local target = terminal.desktop:GetMouseTarget(terminal.GetMousePos())
							local initial_target = target
							local template_id
							while target do
							  template_id = rawget(target, "__dbg_template_template") or rawget(target, "__dbg_template")
							  if template_id then
								break
							  end
							  target = target.parent
							end
							if not template_id then
							  XFlashWindow(initial_target)
							  CreateMessageBox(nil, Untranslated("Error"), Untranslated("Could not find the XTemplate this window was spawned from."))
							  return
							end
							local gedTarget = GetParentOfKind(target, "GedApp")
							if gedTarget then
							  context.dark_mode = gedTarget.dark_mode
							end
							XTemplates[template_id]:OpenEditor()
							XFlashWindow(target)
						  end)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'RolloverText', "Inspect the XWindow currently under the mouse.",
			'ActionId', "DE_InspectXWindowUnderMouse",
			'ActionTranslate', false,
			'ActionName', "Inspect XWindow Under Mouse",
			'ActionIcon', "CommonAssets/UI/Icons/information mark question.png",
			'ActionShortcut', "Alt-F8",
			'OnAction', function (self, host, source, ...)
						  local pt = terminal.desktop.last_mouse_pos
						  local target = terminal.desktop:GetMouseTarget(pt) or terminal.desktop
						  if target then
							Inspect(target)
						  end
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Toggle Console",
			'ActionId', "E_Console",
			'ActionTranslate', false,
			'ActionName', "Toggle Console",
			'ActionIcon', "CommonAssets/UI/Icons/clipboard document paper report sheet.png",
			'ActionShortcut', "Enter",
			'OnAction', function (self, host, source, ...)
						  dlgConsole:Show(true)
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "DE_DbgJoinGame",
			'ActionTranslate', false,
			'ActionName', "Join DbgGame",
			'ActionIcon', "CommonAssets/UI/Icons/group outline.png",
			'ActionShortcut', "Ctrl-G",
			'OnAction', function (self, host, source, ...)
						  DbgJoinGame()
			end,
			'__condition', function (parent, context)
						  return config.SwarmHost
			end,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "(Ctrl-Alt-0)",
			'ActionId', "DE_TogglePathVisuals",
			'ActionMode', "Game",
			'ActionTranslate', false,
			'ActionName', "Toggle Path Visuals",
			'ActionIcon', "CommonAssets/UI/Icons/collapse",
			'ActionShortcut', "Ctrl-Alt-0",
			'ActionShortcut2', "Ctrl-Alt-Numpad 0",
			'OnAction', function (self, host, source, ...) DbgTogglePaths() end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "Execute last console command (.)",
			'ActionId', "LastCommand",
			'ActionTranslate', false,
			'ActionName', "Last Command",
			'ActionDescription', "Execute last console command (.)",
			'ActionShortcut', ".",
			'OnAction', function (self, host, source, ...)
					  if rawget(_G, "dlgConsole") then
						dlgConsole:ExecuteLast()
					  end
			end,
		}),
		}),
	PlaceObj('XTemplateAction', {
		'comment', "Calls Preset:OpenEditor() of the current map thus selecting it in the editor",
		'ActionId', "MapDataPresetEditorOpen",
		'ActionTranslate', false,
		'ActionName', "Edit Map Data",
		'ActionIcon', "CommonAssets/UI/Icons/earth global globe internet world",
		'ActionMenubar', "Map",
		'ActionShortcut', "Shift-I",
		'OnAction', function (self, host, source, ...)
					MapData[GetMapName()]:OpenEditor()
		end,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Save current camera as start camera in map data (Ctrl-Shift-C)",
		'ActionId', "DE_SaveCamera",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-Shift-C",
		'OnAction', function (self, host, source, ...)
				  if not cameraRTS:IsActive() then
					print("RTS camera not active. Please set default camera in game mode.")
					return
				  end
				  local pos, lookat = cameraRTS.GetPosLookAt()
				  mapdata.CameraPos = pos
				  mapdata.CameraLookAt = lookat
				  mapdata.Zoom = cameraRTS.GetZoom()
				  mapdata:Save()
				  print("Updated default start camera")
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Examine the object under cursor (F8)",
		'ActionId', "DE_ExamineObject",
		'ActionTranslate', false,
		'ActionShortcut', "F8",
		'OnAction', function (self, host, source, ...)
				  local solid, transparent = GetPreciseCursorObj()
				  local o = transparent or solid or GetTerrainCursorObj()
				  if IsValid(o) then
					Inspect(o)
				  else
					print("There is no valid object under the cursor")
				  end
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Toggles the buildable debug grid (Ctrl-B)",
		'ActionId', "ToggleBuildable",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-B",
		'OnAction', function (self, host, source, ...)
				  DbgToggleBuildableGrid()
		end,
		'__condition', function (parent, context)
				  return Libs.Sim
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Colorization Matrix (Alt-K)",
		'ActionId', "ColorizationMatrix",
		'ActionTranslate', false,
		'ActionShortcut', "Alt-K",
		'OnAction', function (self, host, source, ...)
				  CreateGameObjectColorizationMatrix()
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Display main depth buffer stencil or depth channel (Shift-H)",
		'ActionId', "G_ShowDepth",
		'ActionTranslate', false,
		'ActionShortcut', "Shift-H",
		'OnAction', function (self, host, source, ...)
				  ToggleDebugForceMode("stencil")
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', " (Ctrl-C)",
		'ActionId', "E_CopyToClipboard",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-C",
		'OnAction', function (self, host, source, ...)
				  if IsEditorActive() and selo() then
					ExecuteWithStatusUI("Copying to clipboard...", XEditorCopyToClipboard)
				  end
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', " (Ctrl-X)",
		'ActionId', "E_CutToClipboard",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-X",
		'ActionState', function (self, host)
				  return IsEditorActive() and "enabled" or "disabled"
		end,
		'OnAction', function (self, host, source, ...)
				  if IsEditorActive() and selo() then
					ExecuteWithStatusUI("Cutting to clipboard...", function()
					  XEditorCopyToClipboard()
					  editor.DelSelWithUndoRedo()
					end)
				  end
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Paste (Ctrl-V)",
		'ActionId', "G_Paste",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-V",
		'OnAction', function (self, host, source, ...)
				  if IsEditorActive() then
					local clipboard = GetFromClipboard(-1)
					if clipboard then
					  if clipboard:starts_with("--[[HGE place script]]--") then
						editor.PasteFromClipboard()
					  else
						local lua_code = GetFromClipboard(-1)
						if not lua_code:starts_with(XEditorCopyScriptTag) then
						  ExecuteWithStatusUI("No objects in clipboard.", function()
							Sleep(500)
						  end)
						  return
						end
						ExecuteWithStatusUI("Pasting...", XEditorPasteFromClipboard)
					  end
					end
				  end
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', " (Ctrl-Shift-A)",
		'ActionId', "Dbg_ShowFpsOffenders",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-Shift-A",
		'OnAction', function (self, host, source, ...)
				  hr.FpsOffenderEnable = 1
				  CreateMapRealTimeThread(function()
					WaitNextFrame(5)
					PrintFpsOffenders()
				  end)
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', " (Ctrl-Shift-V)",
		'ActionId', "G_PasteNoZ",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-Shift-V",
		'OnAction', function (self, host, source, ...)
				  editor.PasteFromClipboard(true)
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Adds the visible objects to the selection (Ctrl-Alt-Space)",
		'ActionId', "Dbg_AddVisibleClassToSelection",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-Alt-Space",
		'OnAction', function (self, host, source, ...)
				  local ol = editor.GetSel()
				  if #ol == 0 then
					print("Select something first!")
				  else
					local num = #ol
					local locked = Collection.GetLockedCollection()
					editor.AddToSel(XEditorGetVisibleObjects(function(obj)
					  for i = 1, num do
						if ol[i].class == obj.class and (not locked or obj:GetRootCollection() == locked) then
						  return true
						end
					  end
					  return false
					end))
				  end
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Force display of Deferred misc maps (Shift-F7)",
		'ActionId', "DE_DS_ForceModeMisc",
		'ActionTranslate', false,
		'ActionShortcut', "Shift-F7",
		'OnAction', function (self, host, source, ...)
				  ToggleDebugForceMode("misc")
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Force display of Deferred lighting debug (Alt-F7)",
		'ActionId', "DE_DS_ForceModeLights",
		'ActionTranslate', false,
		'ActionShortcut', "Alt-F7",
		'OnAction', function (self, host, source, ...)
				  ToggleDebugForceMode("lights")
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Force display of Deferred GBuffer channels (F7)",
		'ActionId', "DE_DS_ForceModeGB",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-F7",
		'OnAction', function (self, host, source, ...)
				  ToggleDebugForceMode("gbuffers")
		end,
		'replace_matching_id', true,
	}),
	PlaceObj('XTemplateAction', {
		'comment', "Disable DS ForceMode (Ctrl-F7)",
		'ActionId', "DE_DS_ForceModeOff",
		'ActionTranslate', false,
		'ActionShortcut', "Ctrl-F7",
		'OnAction', function (self, host, source, ...)
				  ToggleDebugForceMode(false)
		end,
		'replace_matching_id', true,
	}),
})
PlaceObj('XTemplate', {
	SortKey = 100,
	comment = "Ohne das hier funktioniert der Map Editor wohl nicht.",
	group = "Shortcuts",
	id = "EditorShortcuts",
	PlaceObj('XTemplateGroup', {
		'__condition', function (parent, context) return Platform.editor end,
	}, {
		PlaceObj('XTemplateAction', {
			'comment', "Context menu actions",
			'ActionMode', "Editor",
			'ActionTranslate', false,
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Spots",
				'ActionId', "E_ToggleSpots",
				'ActionTranslate', false,
				'ActionName', "Toggle Spots",
				'ActionIcon', "CommonAssets/UI/Menu/EV_OpenFirst.tga",
				'OnAction', function (self, host, source, ...)
					ToggleSpotVisibility(editor.GetSel())
				end,
				'ActionContexts', {
					"SingleSelection",
					"MultipleSelection",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle Surfaces",
				'ActionId', "E_ToggleSurfaces",
				'ActionTranslate', false,
				'ActionName', "Toggle Surfaces",
				'ActionIcon', "CommonAssets/UI/Menu/EV_OpenFirst.tga",
				'ActionState', function (self, host)
					local sel = editor.GetSel()
					if sel and sel[1] and not HasAnySurfaces(sel[1], -1) then
						return "hidden"
					end
				end,
				'OnAction', function (self, host, source, ...)
					ToggleSurfaceVisibility(editor.GetSel())
				end,
				'ActionContexts', {
					"SingleSelection",
					"MultipleSelection",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Entity viewer",
				'ActionId', "E_EV_OpenFirst",
				'ActionTranslate', false,
				'ActionName', "Entity viewer",
				'ActionIcon', "CommonAssets/UI/Menu/EV_OpenFirst.tga",
				'OnAction', function (self, host, source, ...)
					CreateEntityViewer(editor.GetSel()[1])
				end,
				'ActionContexts', {
					"SingleSelection",
					"MultipleSelection",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Art Spec",
				'ActionId', "E_AS_OpenFirst",
				'ActionTranslate', false,
				'ActionName', "Art Spec",
				'ActionIcon', "CommonAssets/UI/Menu/EV_OpenFirst.tga",
				'OnAction', function (self, host, source, ...)
					local entity = selo() and selo():GetEntity() or ""
					local spec = EntitySpecPresets[entity]
					if spec then
						spec:OpenEditor()
					elseif entity ~= "" then
						print("No art spec defined for entity", entity)
					end
				end,
				'ActionContexts', {
					"SingleSelection",
					"MultipleSelection",
				},
				'__condition', function (parent, context) return next(EntitySpecPresets) end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Anim Moments",
				'ActionId', "E_AnimMoments",
				'ActionTranslate', false,
				'ActionName', "Anim Metadata",
				'ActionIcon', "CommonAssets/UI/Icons/video.tga",
				'ActionState', function (self, host)
					local sel = editor.GetSel()
					if sel and sel[1] and not sel[1]:IsAnimated() then
						return "hidden"
					end
				end,
				'OnAction', function (self, host, source, ...)
					OpenAnimationMomentsEditor(editor.GetSel()[1])
				end,
				'ActionContexts', {
					"SingleSelection",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Properties (Ctrl-O); Ctrl-RMB is there only to be displayed in context menu",
				'ActionId', "E_SelectedOptions",
				'ActionTranslate', false,
				'ActionName', "Properties",
				'ActionIcon', "CommonAssets/UI/Menu/object_options.tga",
				'ActionShortcut', "Ctrl-RMB",
				'ActionShortcut2', "Ctrl-O",
				'OnAction', function (self, host, source, ...) OpenGedGameObjectEditor(editor.GetSel()) end,
				'ActionContexts', {
					"SingleSelection",
					"MultipleSelection",
				},
				'replace_matching_id', true,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionMode', "Editor",
			'ActionTranslate', false,
			'ActionMenubar', "DevMenu",
			'OnActionEffect', "popup",
			'replace_matching_id', true,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "Editor",
				'ActionTranslate', false,
				'ActionName', "Editor",
				'ActionMenubar', "DevMenu",
				'OnActionEffect', "popup",
				'replace_matching_id', true,
			}, {
				PlaceObj('XTemplateAction', {
					'ActionId', "Editor.Selections",
					'ActionTranslate', false,
					'ActionName', "Selections ...",
					'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
					'OnActionEffect', "popup",
					'replace_matching_id', true,
				}, {
					PlaceObj('XTemplateAction', {
						'comment', "Select Route",
						'RolloverText', "Select Route",
						'ActionId', "DE_SelectRoute",
						'ActionTranslate', false,
						'ActionName', "Select Route",
						'ActionIcon', "CommonAssets/UI/Menu/SelectRoute.tga",
						'OnAction', function (self, host, source, ...)
							local way_pt = selo()
							if not way_pt then return end
							local route = FindRouteWaypoints(way_pt.Route) 
							editor.ClearSel()
							editor.AddToSel(route)
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Turn selected templates into spawned objects (Ctrl-Shift-Y)",
						'RolloverText', "Turn selected templates into spawned objects (Ctrl-Shift-Y)",
						'ActionId', "E_TurnSelectionToObjects",
						'ActionTranslate', false,
						'ActionName', "Spawn selected templates",
						'ActionIcon', "CommonAssets/UI/Menu/SelectionToObjects.tga",
						'ActionShortcut', "Ctrl-Shift-Y",
						'OnAction', function (self, host, source, ...) Template.TurnTemplatesIntoObjects(editor.GetSel()) end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Turn selected objects into templates (Ctrl-Shift-T)",
						'RolloverText', "Turn selected objects into templates (Ctrl-Shift-T)",
						'ActionId', "E_TurnSelectionToTemplates",
						'ActionTranslate', false,
						'ActionName', "Turn selection to templates",
						'ActionIcon', "CommonAssets/UI/Menu/SelectionToTemplates.tga",
						'OnAction', function (self, host, source, ...) Template.TurnObjectsIntoTemplates(editor.GetSel()) end,
						'replace_matching_id', true,
					}),
					}),
				PlaceObj('XTemplateAction', {
					'ActionId', "Editor.Objects",
					'ActionTranslate', false,
					'ActionName', "Objects ...",
					'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
					'OnActionEffect', "popup",
					'replace_matching_id', true,
				}, {
					PlaceObj('XTemplateAction', {
						'comment', "Removes texts from the selected objects",
						'RolloverText', "Removes texts from the selected objects",
						'ActionId', "E_RemoveTextsFromSelected",
						'ActionTranslate', false,
						'ActionName', "Remove Texts from Selected",
						'OnAction', function (self, host, source, ...)
							local objs = editor.GetSel()
							for i = 1, #objs do
								objs[i]:DestroyAttaches("Text")
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Removes texts from the selected objects",
						'RolloverText', "Removes texts from the selected objects",
						'ActionId', "E_RemoveAllTexts",
						'ActionTranslate', false,
						'ActionName', "Remove All Texts",
						'OnAction', function (self, host, source, ...) RemoveAllTexts() end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Adds LOD and distance indicators for the selected objects",
						'RolloverText', "Adds LOD and distance indicators for the selected objects",
						'ActionId', "E_ShowLOD",
						'ActionTranslate', false,
						'ActionName', "Show LOD info",
						'OnAction', function (self, host, source, ...)
							local objs = editor.GetSel()
							for i = 1, #objs do
								local o = objs[i]
								local f = function()
									local pDist = o:GetVisualPos() - camera.GetPos()
									return "Distance: " .. tostring ( pDist:Len() / guim ) .. "\nLOD: " .. tostring ( o:GetCurrentLOD() )
								end
								o:AttachUpdatingText(f)
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Displays spots with orientation and name on the selected objects",
						'RolloverText', "Displays spots with orientation and name on the selected objects",
						'ActionId', "E_ShowSpots",
						'ActionTranslate', false,
						'ActionName', "Show Spots",
						'OnAction', function (self, host, source, ...)
							local objs = editor.GetSel()
							for i = 1, #objs do
								objs[i]:ShowSpots()
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Hides spots from the selected objects. If no objects are selected, it hides all spots",
						'RolloverText', "Hides spots from the selected objects. If no objects are selected, it hides all spots",
						'ActionId', "E_HideSpots",
						'ActionTranslate', false,
						'ActionName', "Hide Spots",
						'OnAction', function (self, host, source, ...)
							local objs = editor.GetSel()
							for i = 1, #objs do
								objs[i]:HideSpots()
							end
						end,
						'replace_matching_id', true,
					}),
					}),
				PlaceObj('XTemplateAction', {
					'ActionId', "Editor.Window",
					'ActionTranslate', false,
					'ActionName', "Window ...",
					'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
					'OnActionEffect', "popup",
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Replay Particles",
					'RolloverText', "Toggle Particles Replay",
					'ActionId', "E_EditorToggleReplayParticles",
					'ActionTranslate', false,
					'ActionName', "Toggle Replay Particles",
					'ActionIcon', "CommonAssets/UI/Menu/object_options.tga",
					'ActionShortcut', "Alt-E",
					'OnAction', function (self, host, source, ...)
						EditorSettings:SetTestParticlesOnChange(not EditorSettings:GetTestParticlesOnChange())
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Replay Particles",
					'RolloverText', "Toggle Particles Replay",
					'ActionId', "E_EditorReplayParticles",
					'ActionTranslate', false,
					'ActionName', "Replay Particles",
					'ActionIcon', "CommonAssets/UI/Menu/object_options.tga",
					'ActionShortcut', "Shift-E",
					'OnAction', function (self, host, source, ...)
						RecreateSelectedParticle("no delay")
					end,
					'replace_matching_id', true,
				}),
				}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Map",
				'ActionTranslate', false,
				'ActionName', "Map",
				'ActionMenubar', "DevMenu",
				'OnActionEffect', "popup",
				'replace_matching_id', true,
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "Saves the map (Ctrl-S)",
					'RolloverText', "Saves the map (Ctrl-S)",
					'ActionId', "DE_SaveDefaultMap",
					'ActionSortKey', "000",
					'ActionTranslate', false,
					'ActionName', "Save Map",
					'ActionIcon', "CommonAssets/UI/Menu/save_city.tga",
					'ActionShortcut', "Ctrl-S",
					'OnAction', function (self, host, source, ...)
						if cameraFly.IsActive() then return end
						CreateRealTimeThread(XEditorSaveMap)
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Saves the list of entities present on the map",
					'RolloverText', "Saves the list of entities present on the map",
					'ActionId', "DE_SaveDefaultMapEntityList",
					'ActionSortKey', "0001",
					'ActionTranslate', false,
					'ActionName', "Save Map Entity List",
					'ActionIcon', "CommonAssets/UI/Menu/SaveMapEntityList.tga",
					'OnAction', function (self, host, source, ...) SaveMapEntityList(GetMap() .. "entlist.txt") end,
					'__condition', function (parent, context) return not editor.IsModdingEditor() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "OpenMapFolder",
					'ActionSortKey', "0002",
					'ActionTranslate', false,
					'ActionName', "Open Map Folder",
					'OnAction', function (self, host, source, ...) AsyncExec("explorer " .. ConvertToOSPath("svnAssets/Source/" .. GetMap())) end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "BuildingRulesEditor",
					'ActionSortKey', "0004",
					'ActionTranslate', false,
					'ActionName', "Building Rules Editor",
					'OnAction', function (self, host, source, ...)
						OpenGedBuildingRulesEditor()
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "NewRoom",
					'ActionSortKey', "0003",
					'ActionTranslate', false,
					'ActionName', "New Room",
					'ActionToolbar', "EditorRoomTools",
					'ActionToolbarSection', "Room",
					'ActionShortcut', "Ctrl-Shift-N",
					'OnAction', function (self, host, source, ...)
						SetDialogMode("XEditor", "XCreateRoomTool")
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "NewGuides",
					'ActionSortKey', "0004",
					'ActionTranslate', false,
					'ActionName', "New Guides",
					'ActionToolbar', "EditorRoomTools",
					'ActionToolbarSection', "Place Guides",
					'ActionShortcut', "Ctrl-Shift-G",
					'OnAction', function (self, host, source, ...)
						SetDialogMode("XEditor", "XCreateGuidesTool")
					end,
					'__condition', function (parent, context) return const.SlabSizeX end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "ToggleRoomSelectionMode",
					'ActionSortKey', "0005",
					'ActionTranslate', false,
					'ActionName', "Toggle Room Selection Mode",
					'ActionShortcut', "Ctrl-;",
					'OnAction', function (self, host, source, ...)
						ToggleRoomSelectionMode()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "ToggleDestroyedAttachSelection",
					'ActionSortKey', "0005",
					'ActionTranslate', false,
					'ActionName', "Toggle Destroyed Attach Selection",
					'ActionShortcut', "Ctrl-N",
					'OnAction', function (self, host, source, ...)
						ToggleDestroyedAttachSelectionMode()
					end,
					'__condition', function (parent, context) return Platform.developer and const.SlabSizeX and ShouldAttachSelectionShortcutWork() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "ToggleInvulnerabilityMarkings",
					'ActionSortKey', "0005",
					'ActionTranslate', false,
					'ActionName', "Toggle Invulnerability Markings",
					'ActionShortcut', "Ctrl-I",
					'OnAction', function (self, host, source, ...)
						ToggleInvulnerabilityMarkings()
					end,
					'__condition', function (parent, context) return Platform.developer and PersistableGlobals.DestructionInProgressObjs and const.SlabSizeX end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "CreateBlackPlanes",
					'ActionSortKey', "0005",
					'ActionTranslate', false,
					'ActionName', "Create Black Planes From Edge Room Edges",
					'OnAction', function (self, host, source, ...)
						AnalyseRoomsAndPlaceBlackPlanesOnEdges()
					end,
					'__condition', function (parent, context) return Platform.developer and ShouldBlackPlanesShortcutWork() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "DeleteBlackPlanes",
					'ActionSortKey', "0005",
					'ActionTranslate', false,
					'ActionName', "Delete All Black Planes",
					'OnAction', function (self, host, source, ...)
						CleanBlackPlanes()
					end,
					'__condition', function (parent, context) return Platform.developer and ShouldBlackPlanesShortcutWork() end,
					'replace_matching_id', true,
				}),
				}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Terrain",
				'ActionTranslate', false,
				'ActionName', "Terrain",
				'ActionMenubar', "DevMenu",
				'OnActionEffect', "popup",
				'replace_matching_id', true,
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "Fix All Passability Holes",
					'RolloverText', "Fix All Passability Holes",
					'ActionId', "E_FindPassHoles",
					'ActionTranslate', false,
					'ActionName', "Fix All Passability Holes",
					'ActionIcon', "CommonAssets/UI/Menu/passability.tga",
					'OnAction', function (self, host, source, ...)
						XEditorUndo:BeginOp{ passability = true, impassability = true, name = "Changed passability" }
						table.map(terrain.FindAndFillPassabilityHoles(30, 31), StoreErrorSource)
						XEditorUndo:EndOp()
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "ExportTerrainEditor",
					'ActionSortKey', "_002",
					'ActionTranslate', false,
					'ActionName', "Export Terrain",
					'OnAction', function (self, host, source, ...)
						local filename = GetMapName() .. ".heightmap.raw"
						if terrain.ExportHeightMap(filename) then
							print(string.format("Terrain heightmap exported to <color 0 255 0>'%s'</color>.", ConvertToOSPath(filename)))
						else
							print(string.format("<color 255 0 0>Error exporting terrain heightmap!</color>"))
						end
					end,
					'replace_matching_id', true,
				}),
				}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Objects",
				'ActionTranslate', false,
				'ActionName', "Objects",
				'ActionMenubar', "DevMenu",
				'OnActionEffect', "popup",
				'replace_matching_id', true,
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "Hide selected objects",
					'RolloverText', "Hide selected objects",
					'ActionId', "E_HideSelected",
					'ActionTranslate', false,
					'ActionName', "Hide selected",
					'ActionIcon', "CommonAssets/UI/Menu/HideSelected.tga",
					'OnAction', function (self, host, source, ...) editor.HideSelected() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Hide unselected objects",
					'RolloverText', "Hide unselected objects",
					'ActionId', "E_HideUnselected",
					'ActionTranslate', false,
					'ActionName', "Hide unselected",
					'ActionIcon', "CommonAssets/UI/Menu/HideUnselected.tga",
					'OnAction', function (self, host, source, ...) editor.HideUnselected() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Show all hidden objects",
					'RolloverText', "Show all hidden objects",
					'ActionId', "E_ShowAll",
					'ActionTranslate', false,
					'ActionName', "Show all",
					'ActionIcon', "CommonAssets/UI/Menu/ShowAll.tga",
					'OnAction', function (self, host, source, ...) editor.ShowHidden() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Add objects to collection (Ctrl-G)",
					'RolloverText', "Add objects to collection (Ctrl-G)",
					'ActionId', "E_AddToCollection",
					'ActionTranslate', false,
					'ActionName', "Add objects to collection",
					'ActionShortcut', "Ctrl-G",
					'OnAction', function (self, host, source, ...) Collection.AddToCollection() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Unlock collection (Alt-Shift-Z)",
					'RolloverText', "Unlock collection (Alt-Shift-Z)",
					'ActionId', "E_UnlockCollection",
					'ActionTranslate', false,
					'ActionName', "Unlock collection",
					'ActionIcon', "CommonAssets/UI/Menu/UnlockCollection.tga",
					'ActionShortcut', "Alt-Shift-Z",
					'ActionToggle', true,
					'ActionToggled', function (self, host)
						return editor.GetLockedCollectionIdx() ~= 0
					end,
					'OnAction', function (self, host, source, ...) Collection.UnlockAll() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Create collection (G)",
					'RolloverText', "Create collection (G)",
					'ActionId', "E_CollectObjects",
					'ActionTranslate', false,
					'ActionName', "Create collection",
					'ActionIcon', "CommonAssets/UI/Menu/CollectObjects.tga",
					'ActionShortcut', "G",
					'OnAction', function (self, host, source, ...)
						if IsEditorActive() then
							local sel = editor.GetSel()
							if sel and #sel > 0 then
								Collection.Collect(sel)
							end
						end
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Lock collection (Alt-Z)",
					'RolloverText', "Lock collection (Alt-Z)",
					'ActionId', "E_LockCollection",
					'ActionTranslate', false,
					'ActionName', "Lock selected collection",
					'ActionIcon', "CommonAssets/UI/Menu/LockCollection.tga",
					'ActionShortcut', "Alt-Z",
					'OnAction', function (self, host, source, ...)
						local obj = editor.GetSel()[1]
						local col = obj and obj:GetRootCollection()
						if col then
							col:SetLocked(true)
						end
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Select objects that share class with the selection",
					'RolloverText', "Select objects that share class with the selection",
					'ActionId', "E_SelectAllObjectsFromThisClass",
					'ActionTranslate', false,
					'ActionName', "Select objects that share class with the selection",
					'OnAction', function (self, host, source, ...)
						local sel = editor.GetSel()
						if not sel or #sel == 0 then
							return
						end
						local classes = table.get_unique(table.map(sel, "class"))
						editor.ClearSel()
						editor.AddToSel(MapGet("map", classes) or empty_table)
						
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Select all objects by a class name",
					'RolloverText', "Select all objects by a class name",
					'ActionId', "E_SelectObjectByClassName",
					'ActionTranslate', false,
					'ActionName', "Select objects by class name",
					'ActionIcon', "CommonAssets/UI/Menu/SelectByClassName.tga",
					'OnAction', function (self, host, source, ...)
						CreateRealTimeThread( function()
							local class = WaitInputText(nil, "Select by Class", "CObject")
							if not class then return end
							editor.SelectByClass(class)
						end)
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Selection editor (Ctrl-E)",
					'RolloverText', "Selection editor (Ctrl-E)",
					'ActionId', "E_ObjsStats",
					'ActionTranslate', false,
					'ActionName', "Selection editor",
					'ActionIcon', "CommonAssets/UI/Menu/SelectionEditor.tga",
					'ActionShortcut', "Ctrl-E",
					'OnAction', function (self, host, source, ...)
						if cameraFly.IsActive() then return end
						if not GetDialog("SelectionEditorDlg") then
							XEditorSetDefaultTool()
							OpenDialog("SelectionEditorDlg")
						end
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Select Similar Slabs (Ctrl-.)",
					'RolloverText', "Select Similar Slabs (Ctrl-.)",
					'ActionId', "E_SelectSimilarSlabs",
					'ActionTranslate', false,
					'ActionName', "Select Similar Slabs",
					'ActionShortcut', "Ctrl-.",
					'OnAction', function (self, host, source, ...)
						EditorSelectSimilarSlabs()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Select Similar Slabs Precise (Ctrl-Shift-.)",
					'RolloverText', "Select Similar Slabs Precise (Ctrl-Shift-.)",
					'ActionId', "E_SelectSimilarSlabsPrecise",
					'ActionTranslate', false,
					'ActionName', "Select Similar Slabs Precise",
					'ActionShortcut', "Ctrl-Shift-.",
					'OnAction', function (self, host, source, ...)
						EditorSelectSimilarSlabs(true)
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Destroy Selected Objects (Shift-D)",
					'RolloverText', "Destroy Selected Objects (Shift-D)",
					'ActionId', "E_DestroySelectedObjects",
					'ActionTranslate', false,
					'ActionName', "Destroy Selected Objects",
					'ActionShortcut', "Shift-D",
					'OnAction', function (self, host, source, ...)
						EditorDestroyRepairSelectedObjs("destroy")
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Repair Selected Objects (Shift-R)",
					'RolloverText', "Repair Selected Objects (Shift-R)",
					'ActionId', "E_RepairSelectedObjects",
					'ActionTranslate', false,
					'ActionName', "Repair Selected Objects",
					'ActionShortcut', "Shift-R",
					'OnAction', function (self, host, source, ...)
						EditorDestroyRepairSelectedObjs()
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Associate Lights For Destruction",
					'RolloverText', "Associate Lights For Destruction",
					'ActionId', "E_AssociateLightsForDestruction",
					'ActionTranslate', false,
					'ActionName', "Associate Lights For Destruction",
					'ActionMenubar', "Map",
					'ActionShortcut', "Shift-V",
					'OnAction', function (self, host, source, ...)
						AssociateLights()
					end,
					'__condition', function (parent, context) return rawget(_G, "ShouldShowAssociateLightsShortcut") and ShouldShowAssociateLightsShortcut() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Cycle Detail Class",
					'RolloverText', "Cycle Detail Class",
					'ActionId', "E_CycleDetailClass",
					'ActionTranslate', false,
					'ActionName', "Cycle Detail Class",
					'ActionShortcut', "Shift-W",
					'ActionMouseBindable', false,
					'OnAction', function (self, host, source, ...)
						editor.CycleDetailClass()
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'RolloverText', "Force Detail Class Eye Candy",
					'ActionId', "E_ForceDetailClassEyeCandy",
					'ActionTranslate', false,
					'ActionName', "Force Detail Class Eye Candy",
					'ActionShortcut', "Shift-Q",
					'ActionMouseBindable', false,
					'OnAction', function (self, host, source, ...)
						editor.ForceEyeCandy()
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'RolloverText', "Force Eye Candy Outside Map",
					'ActionId', "E_ForceDetailClassEyeCandyOutsideMap",
					'ActionTranslate', false,
					'ActionName', "Force Eye Candy Outside Map",
					'ActionIcon', "CommonAssets/UI/Icons/diamond jewelry ruby",
					'ActionMouseBindable', false,
					'OnAction', function (self, host, source, ...)
						editor.EyeCandyOutsideMap()
					end,
					'__condition', function (parent, context) return Platform.developer end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Toggle Detail Class Visualization",
					'RolloverText', "Toggle Detail Class Visualization",
					'ActionId', "E_ToggleDetailClassVisualization",
					'ActionTranslate', false,
					'ActionName', "Visualize Detail Class",
					'ActionIcon', "CommonAssets/UI/Icons/accessory diamond",
					'ActionMouseBindable', false,
					'ActionToggle', true,
					'ActionToggled', function (self, host)
						return hr.VisualizeDetailClass == 1
					end,
					'OnAction', function (self, host, source, ...)
						hr.VisualizeDetailClass = 1 - hr.VisualizeDetailClass
					end,
					'replace_matching_id', true,
				}),
				}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Tools",
				'ActionTranslate', false,
				'ActionName', "Tools",
				'ActionMenubar', "DevMenu",
				'OnActionEffect', "popup",
				'replace_matching_id', true,
			}, {
				PlaceObj('XTemplateAction', {
					'ActionId', "Tools.Extras",
					'ActionTranslate', false,
					'ActionName', "Extras ...",
					'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
					'OnActionEffect', "popup",
					'replace_matching_id', true,
				}, {
					PlaceObj('XTemplateAction', {
						'comment', "Toggle Objects Rotation",
						'RolloverText', "Toggle Objects Rotation",
						'ActionId', "tex_EditorRotateSelObjects",
						'ActionTranslate', false,
						'ActionName', "Toggle Objects Rotation",
						'ActionIcon', "CommonAssets/UI/Menu/RotateObjectsTool.tga",
						'OnAction', function (self, host, source, ...)
							local sel = editor:GetSel()
							local objects = editor.RotatingObjects
							for i = 1, #sel do
								local selelem = sel[i]
								local bFound = false
								for j = #objects, 1, -1 do
									local elem = objects[j]
									-- remove
									if elem.obj == selelem then
										table.remove(objects, j)
										selelem:SetAngle(60 * elem.angle)
										bFound = true
									end
								end
								-- add
								if not bFound then
									objects[#objects + 1] = { obj = selelem, angle = selelem:GetAngle()/60 }
								end
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Show-Hide Collision Geometry of selected objects",
						'RolloverText', "Show-Hide Collision Geometry of selected objects",
						'ActionId', "E_ShowCollisionGeometry",
						'ActionTranslate', false,
						'ActionName', "Show-Hide Collision Geometry",
						'ActionIcon', "CommonAssets/UI/Menu/CollisionGeometry.tga",
						'OnAction', function (self, host, source, ...) ToggleHR("ShowSelectionCollisions") end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Toggle particles (Shift-P)",
						'RolloverText', "Toggle particles (Shift-P)",
						'ActionId', "E_ToggleParticles",
						'ActionTranslate', false,
						'ActionName', "Toggle Particles",
						'ActionShortcut', "Shift-P",
						'OnAction', function (self, host, source, ...)
							ToggleInvisibleObjectHelpers()
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Toggle Camera Type (Ctrl-Shift-W)",
						'RolloverText', "Toggle Camera Type (Ctrl-Shift-W)",
						'ActionId', "E_CameraChange",
						'ActionTranslate', false,
						'ActionName', "Toggle Camera Type",
						'ActionIcon', "CommonAssets/UI/Menu/CameraToggle.tga",
						'ActionShortcut', "Ctrl-Shift-W",
						'OnAction', function (self, host, source, ...)
							if cameraRTS.IsActive() then
								cameraFly.Activate(1)
							elseif cameraFly.IsActive() then
								cameraMax.Activate(1)
							else
								cameraRTS.Activate(1)
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Camera Save (Alt-,)",
						'RolloverText', "Camera Save (Alt-,)",
						'ActionId', "E_CameraSave",
						'ActionTranslate', false,
						'ActionName', "Camera Save",
						'ActionIcon', "CommonAssets/UI/Menu/UnlockCamera.tga",
						'ActionShortcut', "Alt-,",
						'OnAction', function (self, host, source, ...)
							LocalStorage.saved_camera = {GetCamera()}
							SaveLocalStorage()
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Camera Load (Alt-.)",
						'RolloverText', "Camera Load (Alt-.)",
						'ActionId', "E_CameraLoad",
						'ActionTranslate', false,
						'ActionName', "Camera Load",
						'ActionIcon', "CommonAssets/UI/Menu/CameraEditor.tga",
						'ActionShortcut', "Alt-.",
						'OnAction', function (self, host, source, ...)
							if LocalStorage.saved_camera then
								SetCamera(unpack_params(LocalStorage.saved_camera))
							end
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Toggle spawned objects (Ctrl-Shift-H)",
						'RolloverText', "Toggle spawned objects (Ctrl-Shift-H)",
						'ActionId', "E_ToggleSpawnedObjects",
						'ActionTranslate', false,
						'ActionName', "Toggle spawned objects",
						'ActionIcon', "CommonAssets/UI/Menu/ToggleSpawn.tga",
						'ActionShortcut', "Ctrl-Shift-H",
						'ActionToggle', true,
						'ActionToggled', function (self, host)
							return HiddenSpawnedObjects
						end,
						'OnAction', function (self, host, source, ...) ToggleSpawnedObjects() end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "List new entities for the past 7 days",
						'RolloverText', "List new entities for the past 7 days",
						'ActionId', "List New Entities",
						'ActionTranslate', false,
						'ActionName', "List new entities",
						'OnAction', function (self, host, source, ...)
							CreateRealTimeThread(function() _ListNewEntities(7) end)
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Install URL handler",
						'RolloverText', "Install URL handler",
						'ActionId', "Install URL handler",
						'ActionTranslate', false,
						'ActionName', "Install URL handler",
						'OnAction', function (self, host, source, ...)
							CreateRealTimeThread(function() SetupHGRunUrl() end)
						end,
						'replace_matching_id', true,
					}),
					}),
				PlaceObj('XTemplateAction', {
					'ActionId', "Tools.Collections",
					'ActionTranslate', false,
					'ActionName', "Collections ...",
					'ActionIcon', "CommonAssets/UI/Menu/folder.tga",
					'OnActionEffect', "popup",
					'replace_matching_id', true,
				}, {
					PlaceObj('XTemplateAction', {
						'comment', "Remove All Collections",
						'RolloverText', "Remove All Collections",
						'ActionId', "DE_RemoveAllCollections",
						'ActionTranslate', false,
						'ActionName', "Remove All Collections",
						'OnAction', function (self, host, source, ...)
							local removed = Collection.RemoveAll()
							print(removed, "collections removed")
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Remove All Nested Collections",
						'RolloverText', "Remove All Nested Collections",
						'ActionId', "DE_RemoveAllNestedCollections",
						'ActionTranslate', false,
						'ActionName', "Remove Nested Collections",
						'OnAction', function (self, host, source, ...)
							local removed = Collection.RemoveAll(1)
							print(removed, "collections removed")
						end,
						'replace_matching_id', true,
					}),
					PlaceObj('XTemplateAction', {
						'comment', "Remove All Single Object Collections",
						'RolloverText', "Remove All Single Object Collections",
						'ActionId', "DE_RemoveAllSingleObjectCollections",
						'ActionTranslate', false,
						'ActionName', "Remove Single Object Collections",
						'OnAction', function (self, host, source, ...)
							local cols, removed = Collection.GetValid("remove_invalid", 2)
							print(removed, "collections removed")
						end,
						'replace_matching_id', true,
					}),
					}),
				PlaceObj('XTemplateAction', {
					'comment', "Align object to terrain (Shift-A)",
					'RolloverText', "Align object to terrain (Shift-A)",
					'ActionId', "E_AxisOrientation",
					'ActionTranslate', false,
					'ActionName', "Align object to terrain",
					'ActionIcon', "CommonAssets/UI/Menu/Axis.tga",
					'ActionShortcut', "Shift-A",
					'OnAction', function (self, host, source, ...)
						local function RndOffs(deg)
							local pt
							local sign
							local x, y, z
						
							sign = AsyncRand(2)
							if sign==0 then sign = -1 end
							x = sign*AsyncRand(deg)
							sign = AsyncRand(2)
							if sign==0 then sign = -1 end
							y = sign*AsyncRand(deg)
							sign = AsyncRand(2)
							if sign==0 then sign = -1 end
							z = sign*AsyncRand(deg)
						
							pt = point(x,y,z)
							return pt
						end
						
						local objects = editor:GetSel()
						XEditorUndo:BeginOp{ objects = objects, name = string.format("Aligned %d objects to terrain", #objects) }
						SuspendPassEdits("E_AxisOrientation")
						
						rawset(_G, "sState", rawget(_G, "sState") or "Up")
						if sState == "Up" then
							for i = 1, #objects do
								local obj = objects[i]
								local dir, angle = obj:GetOrientation()
								obj:SetOrientation(axis_z, angle)
							end
							sState = "terrain_normal"
						elseif sState == "terrain_normal" then
							for i = 1, #objects do
								local obj = objects[i]
								local dir, angle = obj:GetOrientation()
								obj:SetOrientation(terrain.GetTerrainNormal(obj:GetPos()), angle)
							end
							sState = "terrain_normal_deviation"
						elseif sState == "terrain_normal_deviation" then
							for i = 1, #objects do
								local obj = objects[i]
								local dir, angle = obj:GetOrientation()
								dir = terrain.GetTerrainNormal(obj:GetPos()) + RndOffs(30)
								obj:SetOrientation(dir, angle)
							end
							sState = "Up"
						end
						ResumePassEdits("E_AxisOrientation")
						XEditorUndo:EndOp(objects)
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', " (Alt-D)",
					'RolloverText', " (Alt-D)",
					'ActionId', "E_DistributeObjects",
					'ActionTranslate', false,
					'ActionName', "Distribute Objects",
					'ActionShortcut', "Alt-D",
					'OnAction', function (self, host, source, ...)
						if g_DistribObjs then return end
						local sel = editor.GetSel()
						if #sel < 2 then
							print("Select 2 (or more) objects")
							return
						end
						g_DistribObjs = DistribObjs:new{
							obj_sel = sel,
							project = true,
						}
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Mirror selected object (Shift-M)",
					'RolloverText', "Mirror selected object (Shift-M)",
					'ActionId', "E_Mirror",
					'ActionTranslate', false,
					'ActionName', "Mirror object",
					'ActionIcon', "CommonAssets/UI/Menu/Mirror.tga",
					'ActionShortcut', "Shift-M",
					'OnAction', function (self, host, source, ...)
						local sel = editor:GetSel()
						editor.MirrorSel(sel)
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', " (Ctrl-Alt-R)",
					'RolloverText', " (Ctrl-Alt-R)",
					'ActionId', "E_CustomScale",
					'ActionTranslate', false,
					'ActionName', "Random Scale Objects",
					'ActionShortcut', "Ctrl-Alt-R",
					'OnAction', function (self, host, source, ...)
						CreateRealTimeThread( function()
							local ol = editor.GetSel()
							local n = WaitInputText(nil, "Scale Range (e.g. 90-110)", LocalStorage.CustomEditorOps and LocalStorage.CustomEditorOps.E_CustomScale or "80-120")
							if not n or not tonumber(n)then return end
							local low, high
							low = tonumber(n)
							if low == nil then
								low, high = string.match(n, "(%d+)%-(%d+)")
								low = tonumber(low)
								high = tonumber(high)
							else
								high = low
							end
							XEditorUndo:BeginOp{ objects = editor.GetSel(), name = string.format("Random scaled %d objects", #editor.GetSel()) }
							for i=1,#ol do
								local o = ol[i]
								o:SetScale(low + AsyncRand(high - low + 1))		
							end
							XEditorUndo:EndOp( editor.GetSel() )
							LocalStorage.CustomEditorOps = LocalStorage.CustomEditorOps or {}
							LocalStorage.CustomEditorOps.E_CustomScale = n
						end )
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', " (Ctrl-R)",
					'RolloverText', " (Ctrl-R)",
					'ActionId', "E_RandomRotate",
					'ActionTranslate', false,
					'ActionName', "Random rotate objects",
					'ActionShortcut', "Ctrl-R",
					'OnAction', function (self, host, source, ...)
						local ol = editor.GetSel()
						XEditorUndo:BeginOp{ objects = editor.GetSel(), name = string.format("Random rotated %d objects", #editor.GetSel()) }
						for i=1,#ol do
							local o = ol[i]
							o:SetAngle(AsyncRand(360*60))		
						end
						XEditorUndo:EndOp( editor.GetSel() )
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', " (Ctrl-K)",
					'RolloverText', " (Ctrl-K)",
					'ActionId', "E_Rotate90X",
					'ActionTranslate', false,
					'ActionName', "Rotate Object 180",
					'ActionShortcut', "Ctrl-K",
					'OnAction', function (self, host, source, ...)
						local ol = editor.GetSel()
						XEditorUndo:BeginOp{ objects = editor.GetSel(), name = string.format("Rotated %d objects", #editor.GetSel()) }
						for i=1,#ol do
							local o = ol[i]
							local axis, angle = ComposeRotation( axis_y, 90*60, o:GetAxis(), o:GetAngle() )
							o:SetAxis( axis )
							o:SetAngle( angle )		
						end
						XEditorUndo:EndOp( editor.GetSel() )
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "(Ctrl-J)",
					'RolloverText', "(Ctrl-J)",
					'ActionId', "E_Rotate90Z",
					'ActionTranslate', false,
					'ActionName', "Rotate Object 90 Z",
					'ActionShortcut', "Ctrl-J",
					'OnAction', function (self, host, source, ...)
						local ol = editor.GetSel()
						XEditorUndo:BeginOp{ objects = editor.GetSel(), name = string.format("Rotated %d objects", #editor.GetSel()) }
						for i=1,#ol do
							local o = ol[i]
							local axis, angle = ComposeRotation( axis_z, 90*60, o:GetAxis(), o:GetAngle() )
							o:SetAxis( axis )
							o:SetAngle( angle )		
						end
						XEditorUndo:EndOp( editor.GetSel() )
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Select objects on the same floor (Shift-F)",
					'RolloverText', "Select objects on the same floor (Shift-F)",
					'ActionId', "SelectFloor",
					'ActionTranslate', false,
					'ActionName', "Select objects on the same floor",
					'ActionIcon', "CommonAssets/UI/Menu/Cube.tga",
					'ActionShortcut', "Shift-F",
					'OnAction', function (self, host, source, ...) SelectSameFloorObjects(editor.GetSel()) end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Snap selected object(s) onto terrain (Ctrl-D)",
					'RolloverText', "Snap selected object(s) onto terrain (Ctrl-D)",
					'ActionId', "E_ResetZ",
					'ActionTranslate', false,
					'ActionName', "Snap objects to terrain",
					'ActionShortcut', "Ctrl-D",
					'OnAction', function (self, host, source, ...) editor.ResetZ() end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "(Ctrl-Alt-I)",
					'RolloverText', "(Ctrl-Alt-I)",
					'ActionId', "E_RecreateRoomWallOrFloor",
					'ActionTranslate', false,
					'ActionName', "Recreate Room Slab Wall or Floor",
					'ActionShortcut', "Ctrl-Alt-I",
					'OnAction', function (self, host, source, ...)
						RecreateSelectedSlabFloorWall()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Snap selected object(s) onto room roof (Ctrl-Alt-D)",
					'RolloverText', "Snap selected object(s) onto room roof (Ctrl-Alt-D)",
					'ActionId', "E_SnapToRoof",
					'ActionTranslate', false,
					'ActionName', "Snap objects to roof",
					'ActionShortcut', "Ctrl-Alt-D",
					'OnAction', function (self, host, source, ...)
						editor.SnapToRoof()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Clear selected object(s)' roof flags (Alt-Shift-D)",
					'RolloverText', "Clear selected object(s)' roof flags (Alt-Shift-D)",
					'ActionId', "E_ClearRoofFlag",
					'ActionTranslate', false,
					'ActionName', "Clear objects roof flag",
					'ActionShortcut', "Alt-Shift-D",
					'OnAction', function (self, host, source, ...)
						editor.ClearRoofFlags()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Toggle whether an obj should hide with its encompassing room. (Alt-H)",
					'RolloverText', "Toggle whether an obj should hide with its encompassing room. (Alt-H)",
					'ActionId', "E_ToggleDontHideWithRoom",
					'ActionTranslate', false,
					'ActionName', "Toggle don't hide with room flag",
					'ActionShortcut', "Alt-H",
					'OnAction', function (self, host, source, ...)
						editor.ToggleDontHideWithRoom()
					end,
					'__condition', function (parent, context) return config.MapEditorRooms end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Snap selected object(s) onto terrain while preserving their relative positions. (Ctrl-Shift-D)",
					'RolloverText', "Snap selected object(s) onto terrain while preserving their relative positions. (Ctrl-Shift-D)",
					'ActionId', "E_ResetZRelative",
					'ActionTranslate', false,
					'ActionName', "Snap objects to terrain (Relative)",
					'ActionShortcut', "Ctrl-Shift-D",
					'OnAction', function (self, host, source, ...) editor.ResetZ(true) end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Toggle Force Night (for light objects)",
					'RolloverText', "Toggle Force Night (for light objects)",
					'ActionId', "Toggle Force Night",
					'ActionTranslate', false,
					'ActionName', "Toggle Force Night",
					'ActionIcon', "CommonAssets/UI/Menu/ToggleEnvMap.tga",
					'OnAction', function (self, host, source, ...)
						EditorForceNight = not EditorForceNight
						MapForEach("map", "LightObject", function(x) x:UpdateLight(CurrentLightmodel[1]) end)
					end,
					'replace_matching_id', true,
				}),
				PlaceObj('XTemplateAction', {
					'comment', "Toggle Transparency Cone",
					'RolloverText', "Toggle Transparency Cone",
					'ActionId', "Toggle Transparency Cone",
					'ActionTranslate', false,
					'ActionName', "Toggle Transparency Cone",
					'ActionIcon', "CommonAssets/UI/Menu/ToggleEnvMap.tga",
					'OnAction', function (self, host, source, ...) return ToggleTransparencyCone() end,
					'replace_matching_id', true,
				}),
				}),
			PlaceObj('XTemplateAction', {
				'comment', "Replace object(s) with object(s) from other class (Shift-~)",
				'ActionId', "E_ReplaceObjects",
				'ActionTranslate', false,
				'ActionShortcut', "Shift-~",
				'OnAction', function (self, host, source, ...)
					CreateRealTimeThread( function()
						local c = selo()
						if c and IsValid(c) then
							local class = WaitInputText(nil, "Type class name(s)", c.class)
							if class then
								editor.ReplaceObjects(editor:GetSel(), class)
							end
						end
					end)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Array (Ctrl-Numpad *)",
				'ActionId', "Array",
				'ActionTranslate', false,
				'ActionShortcut', "Ctrl-Numpad *",
				'OnAction', function (self, host, source, ...)
					CreateRealTimeThread( function()
						local sel = editor.GetSel()
						if #sel == 2 then
							local n = WaitInputText(nil, "Number of objects", "3")
							if not n then return end
							n = tonumber(n)
							if n and n > 2 then
								XEditorUndo:BeginOp{ objects = sel }
								local pt = sel[1]:GetVisualPos()
								local vec = sel[2]:GetVisualPos() - pt
								for i=3,n do
									sel[i] = sel[2]:Clone()
									sel[i]:SetGameFlags(const.gofPermanent)
									sel[i]:SetPos( pt + (i-1) * vec )
								end
								XEditorUndo:EndOp(sel)
								editor.ChangeSelWithUndoRedo(sel)
							end
						end
					end)
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (V)",
				'ActionId', "E_ViewSelection",
				'ActionTranslate', false,
				'ActionShortcut', "V",
				'OnAction', function (self, host, source, ...)
					local sel = editor.GetSel()
					local cnt = #sel
					local center = point30
					for i = 1, cnt do
						local bsc = sel[i]:GetBSphere()
						center = center + bsc
					end
					if cnt > 0 then
						-- find center of the selection
						center = point( center:x() / cnt, center:y() / cnt, const.InvalidZ )
						center = center:SetZ(terrain.GetHeight(center))
					
						-- find the radius of the bounding sphere of the selection
						local selSize = 0
						for i = 1, cnt do
							local bsc, bsr = sel[i]:GetBSphere()
							local dist = bsc:Dist(center) + bsr
							if selSize < dist then
								selSize = dist
							end
						end
						--print( selSize )
						local pos, lookat = cameraMax.GetPosLookAt() 
						--local minZ, maxZ = cameraRTS.GetHeightInterval()
						--local highestPoint = point( pos:x(), pos:y(), pos:z() + maxZ )
						--local maxDistToEye = highestPoint:Dist(lookat)
						--print( maxDistToEye )
						-- move the camera position to look in the center of the selection
						local vec = pos - lookat
						-- if the distance from the camera to the selection center is smaller than the selection bsphere radius
						-- move the camera back
						local distToEye = vec:Dist(point30)
						local scale = (selSize * 1000) / distToEye
						--if (distToEye * scale) / 1000 > maxDistToEye then
						--	scale = (maxDistToEye * 1000) / distToEye
						--	print( "clamped" )
						--end
						if scale > 1000 then
							--print( scale )
							--print( vec )
							vec = point( (vec:x() * scale) / 1000, (vec:y() * scale) / 1000, (vec:z() * scale) / 1000 )
							--print( vec )
						end
						pos = center + vec
						cameraMax.SetCamera( pos, center, 0 )
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Redo editor operation (Ctrl-Y)",
				'ActionId', "E_Redo",
				'ActionTranslate', false,
				'ActionShortcut', "Ctrl-Y",
				'OnAction', function (self, host, source, ...)
					XEditorUndo:UndoRedo("redo")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Disable group selection (Ctrl-Q)",
				'RolloverText', "Disable group selection (Ctrl-Q)",
				'ActionId', "E_DisableGroupSelection",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Editor/Tools/SelectSingleObject.tga",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Ctrl-Q",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return XEditorSelectSingleObjects == 1
				end,
				'OnAction', function (self, host, source, ...)
					XEditorSelectSingleObjects = 1-XEditorSelectSingleObjects
					local statusbar = GetDialog("XEditorStatusbar")
					if statusbar then
						statusbar:ActionsUpdated()
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Hide all texts (Alt-Shift-T)",
				'RolloverText', "Hide all texts (Alt-Shift-T)",
				'ActionId', "E_HideAllTexts",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Editor/Tools/HideTexts.tga",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Alt-Shift-T",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return XEditorHideTexts == true
				end,
				'OnAction', function (self, host, source, ...)
					XEditorHideTexts = not XEditorHideTexts
					XEditorUpdateHiddenTexts()
					local statusbar = GetDialog("XEditorStatusbar")
					if statusbar then
						statusbar:ActionsUpdated()
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Hide code renderables (Alt-Shift-R)",
				'RolloverText', "Hide code renderables (Alt-Shift-R)",
				'ActionId', "E_HideCodeRenderables",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Editor/Tools/HideCodeRenderables.tga",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Alt-Shift-R",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return hr.RenderCodeRenderables == 0
				end,
				'OnAction', function (self, host, source, ...)
					hr.RenderCodeRenderables = 1 - hr.RenderCodeRenderables
					local tool = XEditorGetCurrentTool()
					if tool.UsesCodeRenderables or IsKindOf(tool, "XEditorPlacementHelperHost") and tool.placement_helper.UsesCodeRenderables then
						if XEditorIsDefaultTool() then
							tool:SetHelperClass("XSelectObjectsHelper")
						else
							XEditorSetDefaultTool()
						end
					end
					local statusbar = GetDialog("XEditorStatusbar")
					if statusbar then
						statusbar:ActionsUpdated()
					end
				end,
				'__condition', function (parent, context) return not editor.IsModdingEditor() end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Open caves (Alt-Shift-E)",
				'RolloverText', "Open caves (Alt-Shift-E)",
				'ActionId', "E_OpenCaves",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Editor/Tools/CavesView",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Alt-Shift-E",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return CavesOpened
				end,
				'OnAction', function (self, host, source, ...)
					EditorSetCavesOpen(not CavesOpened)
				end,
				'__condition', function (parent, context) return const.CaveTileSize end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Room tools (Alt-R)",
				'RolloverText', "Room tools (Alt-R)",
				'ActionId', "E_RoomTools",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Editor/Tools/RoomTools",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Alt-R",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return GetDialog("XEditorRoomTools")
				end,
				'OnAction', function (self, host, source, ...)
					if GetDialog("XEditorRoomTools") then
						CloseDialog("XEditorRoomTools")
					else
						OpenDialog("XEditorRoomTools")
					end
					local statusbar = GetDialog("XEditorStatusbar")
					if statusbar then
						statusbar:ActionsUpdated()
					end
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Editor settings",
				'RolloverText', "Editor settings (Ctrl-F3)",
				'ActionId', "E_EditorSettings",
				'ActionTranslate', false,
				'ActionName', "Editor Settings",
				'ActionIcon', "CommonAssets/UI/Editor/Tools/EditorSettings",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "Ctrl-F3",
				'OnAction', function (self, host, source, ...)
					XEditorSettings:ToggleGedEditor()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Editor settings",
				'RolloverText', "Getting started (F1)",
				'ActionId', "E_EditorHelpText",
				'ActionTranslate', false,
				'ActionName', "Help",
				'ActionIcon', "CommonAssets/UI/Editor/Tools/Help",
				'ActionToolbar', "EditorStatusbar",
				'ActionShortcut', "F1",
				'OnAction', function (self, host, source, ...)
					GetDialog("XEditor"):ShowHelpText()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', " (Ctrl-Pagedown)",
				'ActionId', "E_ResetZ2",
				'ActionTranslate', false,
				'ActionShortcut', "Ctrl-Pagedown",
				'OnAction', function (self, host, source, ...)
					editor.ResetZ()
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Undo editor operation (Ctrl-Z)",
				'ActionId', "E_Undo",
				'ActionTranslate', false,
				'ActionShortcut', "Ctrl-Z",
				'OnAction', function (self, host, source, ...)
					XEditorUndo:UndoRedo("undo")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Measure tool (Alt-M)",
				'RolloverText', "Measure tool (Alt-M)",
				'ActionId', "DE_ToggleMeasure_Old",
				'ActionSortKey', "00",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/MeasureTool.tga",
				'ActionShortcut', "Alt-M",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return GetDialogMode("XEditor") == "XMeasureTool"
				end,
				'OnAction', function (self, host, source, ...)
					SetDialogMode("XEditor", "XMeasureTool")
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Show/Hide the User Actions toolbar (Tab)",
				'ActionId', "DE_Toolbar",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Tab",
				'OnAction', function (self, host, source, ...)
					if IsEditorActive() then
						XShortcutsTarget:Toggle()
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'comment', "Toggle between local and global coordinate systems for helpers (Shift-C)",
				'ActionId', "DE_LocalCoordinates",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Shift-C",
				'OnAction', function (self, host, source, ...)
					if IsEditorActive() then
						SetLocalCS(not GetLocalCS())
					end
				end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SelectNorthWall",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl-[",
				'OnAction', function (self, host, source, ...)
					SelectedRoomSelectWall("North")
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SelectEastWall",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl-]",
				'OnAction', function (self, host, source, ...)
					SelectedRoomSelectWall("East")
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SelectWestWall",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl-P",
				'OnAction', function (self, host, source, ...)
					SelectedRoomSelectWall("West")
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SelectSouthWall",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl-'",
				'OnAction', function (self, host, source, ...)
					SelectedRoomSelectWall("South")
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "ClearSelectedWall",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl--",
				'OnAction', function (self, host, source, ...)
					SelectedRoomClearSelectedWall()
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "ResetWallMaterials",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "Ctrl-Backspace",
				'OnAction', function (self, host, source, ...)
					SelectedRoomResetWallMaterials()
				end,
				'__condition', function (parent, context) return config.MapEditorRooms end,
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "ShowHideEditedMapVariation",
				'ActionTranslate', false,
				'ActionIcon', "CommonAssets/UI/Menu/default.tga",
				'ActionShortcut', "M",
				'OnAction', function (self, host, source, ...)
					if CurrentMapVariation then
						CreateRealTimeThread(XEditorHideShowVariation, CurrentMapVariation)
					else
						print("No map variation is currently active.")
					end
				end,
				'__condition', function (parent, context) return Platform.developer end,
				'replace_matching_id', true,
			}),
			}),
		}),
	PlaceObj('XTemplateAction', {
		'comment', "Modding editor overrides",
		'ActionId', "ModdingEditor",
		'ActionTranslate', false,
		'ActionName', "Modding Editor",
		'ActionMenubar', "DevMenu",
		'OnActionEffect', "popup",
		'__condition', function (parent, context) return config.ModdingToolsInUserMode and config.Mods end,
		'replace_matching_id', true,
	}, {
		PlaceObj('XTemplateAction', {
			'comment', "Saves the map editor changes (Ctrl-S)",
			'RolloverText', "Saves the map editor changes (Ctrl-S)",
			'ActionId', "DE_SaveDefaultMap",
			'ActionTranslate', false,
			'ActionName', "Save Map",
			'ActionIcon', "CommonAssets/UI/Menu/save_city.tga",
			'ActionShortcut', "Ctrl-S",
			'OnAction', function (self, host, source, ...)
				if editor.ModItem and not editor.ModItem:IsPacked() then
					CreateRealTimeThread(function()
						editor.ModItem:SaveMap()
						SetEditorMapDirty(false)
					end)
				end
			end,
			'replace_matching_id', true,
		}),
		}),
})
PlaceObj('TextStyle', {
	ShadowSize = 1,
	TextColor = 4278657900,
	TextFont = T(397826639911, --[[TextStyle InfoText TextFont]] "droid, 30"),
	group = "Common",
	id = "InfoText",
})
PlaceObj('TextStyle', {
	ShadowSize = 1,
	TextFont = T(509610940138, --[[TextStyle DevMenuBar TextFont]] "droid, 20"),
	group = "Common",
	id = "DevMenuBar",
})
PlaceObj('TextStyle', {
	ShadowSize = 1,
	TextColor = -1,
	TextFont = T(318278719322, --[[TextStyle EditorText TextFont]] "droid, 18"),
	group = "Common",
	id = "EditorText",
})
PlaceObj('TextStyle', {
	ShadowSize = 1,
	TextFont = T(390296351511, --[[TextStyle EditorToolbar TextFont]] "droid, 18"),
	group = "Common",
	id = "EditorToolbar",
})
PlaceObj('TextStyle', {
	DarkMode = "GedDefaultDarkMode",
	DisabledRolloverTextColor = 2149589024,
	RolloverTextColor = 4280295456,
	TextFont = T(631907372880, --[[TextStyle GedDefault TextFont]] "SchemeBk, 18"),
	group = "Common",
	id = "GedDefault",
})
PlaceObj('TextStyle', {
	DisabledRolloverTextColor = -2135772494,
	DisabledTextColor = -2135772494,
	RolloverTextColor = -4210753,
	TextColor = -4210753,
	TextFont = T(349604004179, --[[TextStyle GedDefaultDarkMode TextFont]] "SchemeBk, 18"),
	group = "Common",
	id = "GedDefaultDarkMode",
})
PlaceObj('TextStyle', {
	DarkMode = "GedSmallDarkMode",
	TextFont = T(997820552513, --[[TextStyle GedSmall TextFont]] "SchemeBk, 15"),
	group = "Common",
	id = "GedSmall",
})
PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	comment = "Only size changes",
	group = "Editor",
	id = "XEditorToolbarSection",
	PlaceObj('XTemplateWindow', {
		'IdNode', true,
		'Margins', box(0, 0, 0, 2),
		'LayoutMethod', "VList",
		'UniformColumnWidth', true,
		'FoldWhenHidden', true,
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'Id', "idSection",
			'BorderWidth', 1,
			'Padding', box(0, 1, 0, 1),
			'Background', RGBA(42, 41, 41, 232),
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XLabel",
				'Id', "idSectionName",
				'Padding', box(0, 0, 0, 0),
				'HAlign', "center",
				'VAlign', "center",
				'TextStyle', "GedMultiLineDarkMode",
				'Text', "Name",
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'comment', "divider",
			'BorderWidth', 1,
			'MinHeight', 1,
			'MaxHeight', 1,
		}),
		PlaceObj('XTemplateWindow', {
			'Padding', box(0, 3, 0, 3),
			'MaxWidth', 220,
			'MaxHeight', 45,
			'LayoutMethod', "VList",
		}, {
			PlaceObj('XTemplateWindow', {
				'Id', "idActionContainer",
				'Dock', "box",
				'HAlign', "left",
				'VAlign', "top",
				'MinWidth', 40,
				'MaxWidth', 220,
				'MaxHeight', 80,
				'LayoutMethod', "HOverlappingList",
				'FillOverlappingSpace', true,
				'LayoutHSpacing', 1,
				'UniformColumnWidth', true,
				'DrawOnTop', true,
			}),
			}),
		PlaceObj('XTemplateFunc', {
			'name', "GetContainer(self)",
			'func', function (self)
				return self.idActionContainer
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "SetName(self, name)",
			'func', function (self, name)
				self.idSectionName:SetText(name)
			end,
		}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XDarkModeAwareDialog",
	group = "Editor",
	id = "XEditorToolbar",
	PlaceObj('XTemplateWindow', {
		'__class', "XDarkModeAwareDialog",
		'ZOrder', -1,
		'Dock', "left",
		'MinWidth', 200,
		'MaxWidth', 300,
		'FoldWhenHidden', true,
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XToolBar",
			'Id', "idToolbar",
			'MinWidth', 200,
			'MaxWidth', 300,
			'LayoutMethod', "VList",
			'Background', RGBA(64, 64, 66, 255),
			'Toolbar', "XEditorToolbar",
			'Show', "icon",
			'ButtonTemplate', "GedToolbarButton",
			'ToggleButtonTemplate', "XEditorToolbarToggleButton",
			'ToolbarSectionTemplate', "XEditorToolbarSection",
		}, {
			PlaceObj('XTemplateFunc', {
				'name', "GetActionsHost(self)",
				'func', function (self)
							  return XShortcutsTarget
				end,
			}),
			}),
		PlaceObj('XTemplateFunc', {
			'name', "Open(self, ...)",
			'func', function (self, ...)
						XDarkModeAwareDialog.Open(self, ...)
						self:SetOutsideScale(point(1000, 1000))
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XContentTemplate",
			'VAlign', "bottom",
			'LayoutMethod', "VList",
		}, {
			PlaceObj('XTemplateWindow', {
				'Id', "Filters",
				'LayoutMethod', "VList",
				'UniformColumnWidth', true,
				'BorderColor', RGBA(41, 41, 41, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'Id', "idSection",
					'BorderWidth', 1,
					'Padding', box(2, 1, 2, 1),
					'BorderColor', RGBA(41, 41, 41, 255),
					'Background', RGBA(41, 41, 41, 255),
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XLabel",
						'Id', "idSectionName",
						'HAlign', "center",
						'VAlign', "center",
						'BorderColor', RGBA(41, 41, 41, 255),
						'TextStyle', "XEditorToolbarDark",
						'Text', "Filters",
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XStateButton",
					'RolloverTranslate', false,
					'RolloverTemplate', "XEditorToolbarRollover",
					'RolloverText', "All",
					'BorderWidth', 1,
					'BorderColor', RGBA(128, 128, 128, 255),
					'OnContextUpdate', function (self, context, ...)
						
					end,
					'FocusedBorderColor', RGBA(128, 128, 128, 255),
					'DisabledBorderColor', RGBA(128, 128, 128, 255),
					'OnPress', function (self, gamepad)
									local row = self.IconRow + 1
									if row > self.IconRows then
									  row = 1
									end
									local categories = {}
									local toggle_back_visibility = LocalStorage.FilteredCategories.All == "invisible"
									if not toggle_back_visibility then
									  for cat, filter in pairs(self.context.filter_buttons) do
										if filter == "invisible" then
										  categories[cat] = true
										end
									  end
									end
									XEditorFilters:ToggleFilter(categories, toggle_back_visibility)
									if LocalStorage.FilteredCategories.HideTop == "invisible" then
									  XEditorFilters:UpdateVisibility("HideTop", "invisible")
									end
									self:SetIconRow(row)
									self:OnRowChange(row)
					end,
					'AltPress', true,
					'OnAltPress', function (self, gamepad)
									if self.action and self.action.OnAltAction then
									  local host = GetActionsHost(self, true)
									  if host then
										self.action:OnAltAction(host, self)
									  end
									end
									local categories = {}
									for cat, filter in pairs(self.context.filter_buttons) do
									  if filter == "invisible" and not LocalStorage.LockedCategories[cat] then
										LocalStorage.FilteredCategories.All = "invisible"
										break
									  end
									end
									XEditorFilters:ToggleFilter(categories, true)
									if LocalStorage.FilteredCategories.HideTop == "invisible" then
									  XEditorFilters:UpdateVisibility("HideTop", "invisible")
									end
					end,
					'RolloverBorderColor', RGBA(128, 128, 128, 255),
					'PressedBorderColor', RGBA(128, 128, 128, 255),
					'IconRows', 1,
					'TextStyle', "GedDefaultWhite",
					'Text', "All",
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "CalcBackground(self)",
						'func', function (self)
										  local filter = XEditorFilters:GetFilter("All")
										  if filter == "visible" then
											self.Background = RGB(0, 96, 0)
											self.RolloverBackground = RGB(0, 128, 0)
											self.PressedBackground = RGB(0, 196, 0)
										  elseif filter == "invisible" then
											self.Background = RGB(96, 0, 0)
											self.RolloverBackground = RGB(128, 0, 0)
											self.PressedBackground = RGB(196, 0, 0)
										  elseif filter == "unselectable" then
											self.Background = RGB(96, 96, 96)
											self.RolloverBackground = RGB(128, 128, 128)
											self.PressedBackground = RGB(196, 196, 196)
										  end
										  self.BorderColor = RGBA(128, 128, 128, 255)
										  self.RolloverBorderColor = RGBA(128, 128, 128, 255)
										  self.PressedBorderColor = RGBA(128, 128, 128, 255)
										  self:SetIcon("")
										  if not self.enabled then
											return self.DisabledBackground
										  end
										  if self.state == "pressed-in" or self.state == "pressed-out" then
											return self.PressedBackground
										  end
										  if self.state == "mouse-in" then
											return self.RolloverBackground
										  end
										  return self:IsFocused() and self.FocusedBackground or self.Background
						end,
					}),
					}),
				PlaceObj('XTemplateForEach', {
					'array', function (parent, context)
									return XEditorFilters.GetCategories()
					end,
					'condition', function (parent, context, item, i)
									return context.filter_buttons[item] and item ~= "All"
					end,
					'run_after', function (child, context, item, i, n, last)
									local text = item
									if 12 < #text then
									  text = string.sub(text, 1, 20) .. "..."
									end
									child:SetText(text)
									child:SetRolloverText(item)
									child.ChildrenHandleMouse = true
									child[1].HandleMouse = true
									child[1]:SetImageColor(RGB(255, 255, 255))
									child[1]:SetTransparency(LocalStorage.LockedCategories[item] and 0 or 192)
									child[1].OnMouseButtonDown = function(self)
									  local category = self.parent:GetRolloverText()
									  LocalStorage.LockedCategories[category] = not LocalStorage.LockedCategories[category]
									  self:SetTransparency(LocalStorage.LockedCategories[category] and 0 or 192)
									end
									child[1].Dock = "right"
					end,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XStateButton",
						'RolloverTemplate', "XEditorToolbarRollover",
						'BorderWidth', 1,
						'BorderColor', RGBA(128, 128, 128, 255),
						'OnContextUpdate', function (self, context, ...)
							
						end,
						'FocusedBorderColor', RGBA(128, 128, 128, 255),
						'DisabledBorderColor', RGBA(128, 128, 128, 255),
						'OnPress', function (self, gamepad)
										  local row = self.IconRow + 1
										  if row > self.IconRows then
											row = 1
										  end
										  local category = self:GetRolloverText()
										  if terminal.IsKeyPressed(const.vkControl) then
											for cat, filter in pairs(self.context.filter_buttons) do
											  if cat == category then
												XEditorFilters:UpdateVisibility(cat, "visible")
											  elseif filter == "visible" then
												XEditorFilters:UpdateVisibility(cat, "unselectable")
											  end
											end
										  else
											XEditorFilters:ToggleFilter(category, false)
										  end
										  if LocalStorage.FilteredCategories.HideTop == "invisible" then
											XEditorFilters:UpdateVisibility("HideTop", "invisible")
										  end
										  self:SetIconRow(row)
										  self:OnRowChange(row)
						end,
						'AltPress', true,
						'OnAltPress', function (self, gamepad)
										  if self.action and self.action.OnAltAction then
											local host = GetActionsHost(self, true)
											if host then
											  self.action:OnAltAction(host, self)
											end
										  end
										  local category = self:GetRolloverText()
										  if terminal.IsKeyPressed(const.vkControl) then
											local categories = {
											  [category] = true
											}
											XEditorFilters:UpdateVisibility(category, "visible")
											XEditorFilters:UpdateVisibility(categories, "invisible")
										  else
											XEditorFilters:ToggleFilter(category, true)
											if LocalStorage.FilteredCategories.HideTop == "invisible" then
											  XEditorFilters:UpdateVisibility("HideTop", "invisible")
											end
										  end
						end,
						'RolloverBorderColor', RGBA(128, 128, 128, 255),
						'PressedBorderColor', RGBA(128, 128, 128, 255),
						'Icon', "CommonAssets/UI/Icons/lock login padlock password safe secure_white",
						'IconRows', 1,
						'TextStyle', "GedDefaultWhite",
					}, {
						PlaceObj('XTemplateFunc', {
							'name', "CalcBackground(self)",
							'func', function (self)
												local category = self:GetRolloverText()
												local filter = XEditorFilters:GetFilter(category)
												if filter == "visible" then
												  self.Background = RGB(0, 96, 0)
												  self.RolloverBackground = RGB(0, 128, 0)
												  self.PressedBackground = RGB(0, 196, 0)
												elseif filter == "invisible" then
												  self.Background = RGB(96, 0, 0)
												  self.RolloverBackground = RGB(128, 0, 0)
												  self.PressedBackground = RGB(196, 0, 0)
												elseif filter == "unselectable" then
												  self.Background = RGB(96, 96, 96)
												  self.RolloverBackground = RGB(128, 128, 128)
												  self.PressedBackground = RGB(196, 196, 196)
												end
												self.BorderColor = RGBA(128, 128, 128, 255)
												self.RolloverBorderColor = RGBA(128, 128, 128, 255)
												self.PressedBorderColor = RGBA(128, 128, 128, 255)
												if not self.enabled then
												  return self.DisabledBackground
												end
												if self.state == "pressed-in" or self.state == "pressed-out" then
												  return self.PressedBackground
												end
												if self.state == "mouse-in" then
												  return self.RolloverBackground
												end
												return self:IsFocused() and self.FocusedBackground or self.Background
							end,
						}),
						PlaceObj('XTemplateFunc', {
							'name', "OnMouseLeft(self, ...)",
							'func', function (self, ...)
												XEditorFilters:HighlightObjects(self:GetRolloverText(), false)
												XControl.OnMouseLeft(self, ...)
							end,
						}),
						PlaceObj('XTemplateFunc', {
							'name', "OnMouseEnter(self, ...)",
							'func', function (self, ...)
												XEditorFilters:HighlightObjects(self:GetRolloverText(), true)
												XControl.OnMouseEnter(self, ...)
							end,
						}),
						}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XTextButton",
					'BorderWidth', 1,
					'BorderColor', RGBA(128, 128, 128, 255),
					'FocusedBorderColor', RGBA(128, 128, 128, 255),
					'DisabledBorderColor', RGBA(128, 128, 128, 255),
					'OnPress', function (self, gamepad)
									local categories = {}
									local allCategories = XEditorFilters:GetCategories()
									for _, category in ipairs(allCategories) do
									  if not table.find(table.keys(self.context.filter_buttons), category) then
										table.insert(categories, category)
									  end
									end
									CreateRealTimeThread(function()
									  local categories = WaitListMultipleChoice(nil, categories, "Choose category / categories:")
									  XEditorFilters:Add(categories)
									end)
					end,
					'RolloverBorderColor', RGBA(128, 128, 128, 255),
					'PressedBorderColor', RGBA(128, 128, 128, 255),
					'Text', "Add",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XTextButton",
					'BorderWidth', 1,
					'BorderColor', RGBA(128, 128, 128, 255),
					'FocusedBorderColor', RGBA(128, 128, 128, 255),
					'DisabledBorderColor', RGBA(128, 128, 128, 255),
					'OnPress', function (self, gamepad)
									local categories = {}
									local allCategories = XEditorFilters:GetCategories()
									for _, category in ipairs(allCategories) do
									  if table.find(table.keys(self.context.filter_buttons), category) and category ~= "All" then
										table.insert(categories, category)
									  end
									end
									CreateRealTimeThread(function()
									  local categories = WaitListMultipleChoice(nil, categories, "Choose category / categories:")
									  XEditorFilters:Remove(categories)
									end)
					end,
					'RolloverBorderColor', RGBA(128, 128, 128, 255),
					'PressedBorderColor', RGBA(128, 128, 128, 255),
					'Text', "Remove",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XCheckButton",
					'Id', "idCustomFilter",
					'Margins', box(0, 2, 0, 2),
					'Text', "Custom",
					'OnChange', function (self, check)
									XEditorShowCustomFilters = check
									if check and not XEditorIsDefaultTool() then
									  XEditorSetDefaultTool()
									end
									ObjModified(XEditorGetCurrentTool())
									XEditorSettingsJustOpened = true
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__condition', function (parent, context)
							  return config.MapEditorRooms
				end,
				'Id', "Rooms",
				'IdNode', true,
				'LayoutMethod', "VList",
				'UniformColumnWidth', true,
				'BorderColor', RGBA(41, 41, 41, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'Id', "idSection",
					'BorderWidth', 1,
					'Padding', box(2, 1, 2, 1),
					'BorderColor', RGBA(41, 41, 41, 255),
					'Background', RGBA(41, 41, 41, 255),
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XLabel",
						'Id', "idSectionName",
						'HAlign', "center",
						'VAlign', "center",
						'BorderColor', RGBA(41, 41, 41, 255),
						'TextStyle', "XEditorToolbarDark",
						'Text', "Rooms",
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XToggleButton",
					'RolloverTemplate', "XEditorToolbarRollover",
					'RolloverText', T(149733040574, --[[XTemplate XEditorToolbar RolloverText]] "Roofs"),
					'BorderWidth', 1,
					'BorderColor', RGBA(128, 128, 128, 255),
					'Background', RGBA(0, 96, 0, 255),
					'OnContextUpdate', function (self, context, ...)
						
					end,
					'FocusedBorderColor', RGBA(128, 128, 128, 255),
					'DisabledBorderColor', RGBA(128, 128, 128, 255),
					'OnPress', function (self, gamepad)
									self:SetToggled(not self.Toggled)
									self.context.roof_visuals_enabled = not self.context.roof_visuals_enabled
									LocalStorage.FilteredCategories.Roofs = self.context.roof_visuals_enabled
									XEditorFilters:UpdateHiddenRoofsAndFloors()
					end,
					'AltPress', true,
					'OnAltPress', function (self, gamepad)
									if self.action and self.action.OnAltAction then
									  local host = GetActionsHost(self, true)
									  if host then
										self.action:OnAltAction(host, self)
									  end
									end
									self.context.roof_visuals_enabled = not self.context.roof_visuals_enabled
									LocalStorage.FilteredCategories.Roofs = self.context.roof_visuals_enabled
									XEditorFilters:UpdateHiddenRoofsAndFloors()
					end,
					'RolloverBorderColor', RGBA(128, 128, 128, 255),
					'PressedBorderColor', RGBA(128, 128, 128, 255),
					'TextStyle', "GedDefaultWhite",
					'Text', "Roofs",
					'ToggledBackground', RGBA(96, 0, 0, 255),
					'ToggledBorderColor', RGBA(128, 128, 128, 255),
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnSetRollover(self, rollover)",
					}),
					PlaceObj('XTemplateFunc', {
						'name', "CalcBackground(self)",
						'func', function (self)
										  local filter = LocalStorage.FilteredCategories.Roofs
										  if filter then
											self.Background = RGB(0, 96, 0)
											self.RolloverBackground = RGB(0, 128, 0)
											self.PressedBackground = RGB(0, 196, 0)
										  else
											self.Background = RGB(96, 0, 0)
											self.RolloverBackground = RGB(128, 0, 0)
											self.PressedBackground = RGB(196, 0, 0)
										  end
										  self.BorderColor = RGBA(128, 128, 128, 255)
										  self.RolloverBorderColor = RGBA(128, 128, 128, 255)
										  self.PressedBorderColor = RGBA(128, 128, 128, 255)
										  self:SetIcon("")
										  if not self.enabled then
											return self.DisabledBackground
										  end
										  if self.state == "pressed-in" or self.state == "pressed-out" then
											return self.PressedBackground
										  end
										  if self.state == "mouse-in" then
											return self.RolloverBackground
										  end
										  return self:IsFocused() and self.FocusedBackground or self.Background
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XLabel",
					'Background', RGBA(64, 64, 64, 255),
					'Text', "Hide floor",
				}),
				PlaceObj('XTemplateWindow', nil, {
					PlaceObj('XTemplateFunc', {
						'name', "Open(self, ...)",
						'func', function (self, ...)
										  local edit = CreateNumberEditor(self, "idEdit", function(multiplier)
											local floor = XEditorFilters:SetHideFloorFilter(multiplier)
											self:ResolveId("idEdit"):SetText(tostring(floor))
										  end, function(multiplier)
											local floor = XEditorFilters:SetHideFloorFilter(-multiplier)
											self:ResolveId("idEdit"):SetText(tostring(floor))
										  end)
										  local floors = 0
										  MapForEach("map", "Room", function(o)
											if o.floor > floors then
											  floors = o.floor
											end
										  end)
										  self[1]:SetBackground(RGBA(64, 64, 64, 255))
										  local text = tostring(LocalStorage.FilteredCategories.HideFloor)
										  edit:SetText(text)
										  edit.AutoSelectAll = true
										  function edit.OnTextChanged(edit)
											local value = tonumber(edit:GetText()) or 0
											LocalStorage.FilteredCategories.HideFloor = Clamp(value, 0, floors + 1)
											edit:SetText(tostring(LocalStorage.FilteredCategories.HideFloor))
											XEditorFilters:UpdateHiddenRoofsAndFloors()
											edit:SelectAll()
										  end
										  function edit:OnShortcut(shortcut, source, ...)
											if shortcut == "Escape" then
											  terminal.desktop:RemoveKeyboardFocus(self, true)
											else
											  XEdit.OnShortcut(self, shortcut, source, ...)
											end
										  end
										  return XWindow.Open(self, ...)
						end,
					}),
					}),
				}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XDialog",
	group = "Common",
	id = "AnimMetadataEditorTimeline",
	recreate_after_save = true,
	PlaceObj('XTemplateWindow', {
		'__class', "XDialog",
		'Id', "idAnimMetadataEditorTimeline",
		'Padding', box(0, 50, 0, 40),
		'Dock', "box",
		'HAlign', "center",
		'VAlign', "bottom",
		'MinWidth', 1000,
		'MinHeight', 130,
		'LayoutMethod', "HList",
		'UseClipBox', false,
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'VAlign', "bottom",
			'LayoutMethod', "HList",
		}, {
			PlaceObj('XTemplateWindow', {
				'Margins', box(0, 0, 5, 0),
				'VAlign', "center",
				'LayoutMethod', "VList",
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "idAnimationName",
					'Margins', box(0, 0, 0, 5),
					'TextStyle', "AnimMetadataEditorTimeline",
					'TextHAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'HAlign', "center",
					'LayoutMethod', "HList",
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'Id', "idPlay",
						'Margins', box(0, 0, 5, 0),
						'HAlign', "left",
						'VAlign', "center",
						'MaxWidth', 30,
						'MaxHeight', 30,
						'OnPress', function (self, gamepad)
										  GedOpAnimMetadataEditorPlay(self, GetAnimationMomentsEditorObject())
						end,
						'Image', "CommonAssets/UI/Ged/play",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'Id', "idStop",
						'Margins', box(0, 0, 5, 0),
						'HAlign', "left",
						'VAlign', "center",
						'MaxWidth', 30,
						'MaxHeight', 30,
						'GridX', 2,
						'LayoutMethod', "None",
						'OnPress', function (self, gamepad)
										  GedOpAnimMetadataEditorStop(self, GetAnimationMomentsEditorObject())
						end,
						'Image', "CommonAssets/UI/Ged/pause",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XToggleButton",
						'Id', "idLoop",
						'Margins', box(0, 0, 5, 0),
						'HAlign', "left",
						'VAlign', "center",
						'MaxWidth', 30,
						'MaxHeight', 30,
						'GridX', 3,
						'LayoutMethod', "None",
						'OnPress', function (self, gamepad)
										  GedOpAnimationMomentsEditorToggleLoop(self, GetAnimationMomentsEditorObject())
						end,
						'Image', "CommonAssets/UI/Ged/undo",
					}),
					}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idTimeline",
				'IdNode', true,
				'Margins', box(5, 0, 5, 0),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 1000,
				'MinHeight', 60,
				'MaxHeight', 60,
				'GridX', 4,
				'LayoutMethod', "None",
				'BorderColor', RGBA(0, 255, 246, 255),
				'Background', RGBA(0, 0, 0, 255),
				'HandleMouse', true,
			}, {
				PlaceObj('XTemplateFunc', {
					'name', "DrawContent(self)",
					'func', function (self)
									local obj = GetAnimationMomentsEditorObject()
									if not IsValid(obj) or not IsValidEntity(obj:GetEntity()) then
									  return
									end
									local dragging = AnimMetadataEditorTimelineSelectedControl and AnimMetadataEditorTimelineSelectedControl.dragging
									local frame = obj:GetFrame()
									if dragging then
									  local time = AnimMetadataEditorTimelineSelectedControl.moment.Time
									  frame = obj:GetModifiedTime(time)
									else
									  self:DrawLine(frame, RGB(0, 255, 0))
									end
									local dlg = self.parent.parent
									local button_text = string.format("+New moment (%s)", FormatTimeline(frame, 3))
									dlg:UpdateControl(frame, button_text, dlg:ResolveId("idMoment-NewMoment"), "above timeline")
									local enabled = dlg:GetEnabledMomentTypes()
									local moment_controls = dlg:GetMomentControls()
									table.sort(moment_controls, function(a, b)
									  return a.moment.Time < b.moment.Time
									end)
									for index, control in ipairs(moment_controls) do
									  local moment = control.moment
									  if enabled[moment.Type] then
										local time, text = dlg:GetMomentTime(moment)
										self:DrawLine(time, RGB(255, 0, 0))
										dlg:UpdateControl(time, text, control, index % 2 == 1)
									  end
									end
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "OnMouseButtonDown(self, pos, button)",
					'func', function (self, pos, button)
									if button ~= "L" then
									  return
									end
									AnimMetadataEditorTimelineDragging = true
									self:UpdateFrame(pos)
									return "break"
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "OnMouseButtonUp(self, pos, button)",
					'func', function (self, pos, button)
									if button ~= "L" then
									  return
									end
									if not AnimMetadataEditorTimelineDragging then
									  return
									end
									self:UpdateFrame(pos)
									AnimMetadataEditorTimelineDragging = false
									self.parent.parent:CreateNewMomentControl()
									local timeline = GetDialog("AnimMetadataEditorTimeline")
									if timeline then
									  timeline:DeselectMoment()
									end
									return "break"
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "OnMousePos(self, pos)",
					'func', function (self, pos)
									if not AnimMetadataEditorTimelineDragging then
									  return
									end
									DeleteThread(AnimMetadataEditorTimelineDragging)
									AnimMetadataEditorTimelineDragging = CreateMapRealTimeThread(function()
									  self:DrawContent()
									  self:UpdateFrame(pos, "delayed moments binding")
									end)
									return "break"
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "UpdateFrame(self, pos, delayed_moments_binding)",
					'func', function (self, pos, delayed_moments_binding)
									local frame = self:GetFrame(pos)
									if frame then
									  local obj = GetAnimationMomentsEditorObject()
									  obj:SetFrame(frame, delayed_moments_binding)
									  GedObjectModified(obj)
									end
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "MoveFrame(self, time)",
					'func', function (self, time)
									local obj = GetAnimationMomentsEditorObject()
									if AnimMetadataEditorTimelineSelectedControl then
									  local moment = AnimMetadataEditorTimelineSelectedControl.moment
									  obj:SetFrame(obj:GetModifiedTime(moment.Time))
									  local duration = obj:GetAbsoluteTime(obj.anim_duration)
									  moment.Time = Clamp(obj:GetAbsoluteTime(obj.Frame) + time, 0, duration - 1)
									  obj:SetFrame(obj:GetModifiedTime(moment.Time))
									else
									  obj:SetFrame(obj:GetAbsoluteTime(obj.Frame) + time)
									end
									GedObjectModified(obj)
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "DrawLine(self, frame, color)",
					'func', function (self, frame, color)
									local obj = GetAnimationMomentsEditorObject()
									if not obj then
									  return
									end
									local duration = Max(obj.anim_duration, 1)
									local b = self.box
									local width = b:sizex()
									local column = b:minx() + width * frame / duration
									UIL.DrawLine(point(column, b:miny()), point(column, b:maxy()), color)
					end,
				}),
				PlaceObj('XTemplateFunc', {
					'name', "GetFrame(self, pos)",
					'func', function (self, pos)
									local obj = GetAnimationMomentsEditorObject()
									if not obj then
									  return
									end
									local duration = obj.anim_duration
									if duration <= 0 then
									  return
									end
									local control = AnimMetadataEditorTimelineSelectedControl
									local box = self.box
									local width = box:sizex()
									local column = pos:x() - box:minx()
									if not control or not control.dragging then
									  column = Clamp(column, 0, width)
									end
									return MulDivTrunc(duration, column, width)
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XText",
				'Id', "idDuration",
				'Margins', box(5, 0, 5, 0),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 50,
				'MaxHeight', 30,
				'GridX', 5,
				'LayoutMethod', "None",
				'TextStyle', "AnimMetadataEditorTimeline",
				'Text', "Duration",
				'TextVAlign', "center",
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'GridX', 6,
			'GridStretchX', false,
			'GridStretchY', false,
			'LayoutMethod', "VList",
			'LayoutVSpacing', 5,
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XText",
				'HAlign', "center",
				'MinWidth', 50,
				'MaxHeight', 20,
				'LayoutMethod', "None",
				'HandleKeyboard', false,
				'HandleMouse', false,
				'TextStyle', "AnimMetadataEditorTimeline",
				'Text', "Preview Speed",
				'TextHAlign', "center",
				'TextVAlign', "center",
			}),
			PlaceObj('XTemplateWindow', {
				'__class', "XToggleButton",
				'Id', "idSpeed100",
				'BorderWidth', 1,
				'HAlign', "center",
				'MinWidth', 50,
				'Background', RGBA(134, 134, 134, 255),
				'OnPress', function (self, gamepad)
							  GedOpAnimationMomentsEditorToggleSpeed(self, 100)
							  self:SetToggled(true)
							  self:ResolveId("idSpeed50"):SetToggled(false)
							  self:ResolveId("idSpeed20"):SetToggled(false)
							  self:ResolveId("idSpeed10"):SetToggled(false)
				end,
				'RolloverBackground', RGBA(178, 178, 178, 255),
				'PressedBackground', RGBA(172, 172, 172, 255),
				'Text', "100%",
				'Toggled', true,
				'ToggledBackground', RGBA(204, 204, 204, 255),
			}),
			PlaceObj('XTemplateWindow', {
				'__class', "XToggleButton",
				'Id', "idSpeed50",
				'BorderWidth', 1,
				'HAlign', "center",
				'MinWidth', 50,
				'Background', RGBA(134, 134, 134, 255),
				'OnPress', function (self, gamepad)
							  GedOpAnimationMomentsEditorToggleSpeed(self, 50)
							  self:SetToggled(true)
							  self:ResolveId("idSpeed100"):SetToggled(false)
							  self:ResolveId("idSpeed20"):SetToggled(false)
							  self:ResolveId("idSpeed10"):SetToggled(false)
				end,
				'RolloverBackground', RGBA(178, 178, 178, 255),
				'PressedBackground', RGBA(172, 172, 172, 255),
				'Text', "50%",
				'ToggledBackground', RGBA(204, 204, 204, 255),
			}),
			PlaceObj('XTemplateWindow', {
				'__class', "XToggleButton",
				'Id', "idSpeed20",
				'BorderWidth', 1,
				'HAlign', "center",
				'MinWidth', 50,
				'Background', RGBA(134, 134, 134, 255),
				'OnPress', function (self, gamepad)
							  GedOpAnimationMomentsEditorToggleSpeed(self, 20)
							  self:SetToggled(true)
							  self:ResolveId("idSpeed100"):SetToggled(false)
							  self:ResolveId("idSpeed50"):SetToggled(false)
							  self:ResolveId("idSpeed10"):SetToggled(false)
				end,
				'RolloverBackground', RGBA(178, 178, 178, 255),
				'PressedBackground', RGBA(172, 172, 172, 255),
				'Text', "20%",
				'ToggledBackground', RGBA(204, 204, 204, 255),
			}),
			PlaceObj('XTemplateWindow', {
				'__class', "XToggleButton",
				'Id', "idSpeed10",
				'BorderWidth', 1,
				'HAlign', "center",
				'MinWidth', 50,
				'Background', RGBA(134, 134, 134, 255),
				'OnPress', function (self, gamepad)
							  GedOpAnimationMomentsEditorToggleSpeed(self, 10)
							  self:SetToggled(true)
							  self:ResolveId("idSpeed100"):SetToggled(false)
							  self:ResolveId("idSpeed50"):SetToggled(false)
							  self:ResolveId("idSpeed20"):SetToggled(false)
				end,
				'RolloverBackground', RGBA(178, 178, 178, 255),
				'PressedBackground', RGBA(172, 172, 172, 255),
				'Text', "10%",
				'ToggledBackground', RGBA(204, 204, 204, 255),
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'Id', "idFilters",
			'Margins', box(10, 0, 10, 0),
			'BorderWidth', 1,
			'Padding', box(5, 2, 5, 2),
			'GridX', 6,
			'GridStretchX', false,
			'GridStretchY', false,
			'LayoutMethod', "VList",
			'LayoutVSpacing', 5,
			'Background', RGBA(128, 128, 128, 255),
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XText",
				'HAlign', "center",
				'MinWidth', 50,
				'MaxHeight', 20,
				'LayoutMethod', "None",
				'HandleKeyboard', false,
				'HandleMouse', false,
				'TextStyle', "AnimMetadataEditorTimeline",
				'Text', "Moments Filter",
				'TextHAlign', "center",
				'TextVAlign', "center",
			}),
			}),
		PlaceObj('XTemplateFunc', {
			'name', "CreateNewMomentControl(self)",
			'func', function (self)
						local obj = GetAnimationMomentsEditorObject()
						local id = "idMoment-NewMoment"
						local control = rawget(self, id)
						if not control then
						  control = XTextButton:new({Id = id}, self)
						  self:InitControl(control)
						  function control.OnMouseButtonDown(this, pos, button)
							if button == "L" then
							  CreateRealTimeThread(function()
								local time = obj:GetProperty("Frame")
								local moments = ActionMomentNamesCombo()
								local moment = WaitListChoice(terminal.desktop, moments, "Select Moment Type", 1, nil, "free_input")
								if moment then
								  self:OnNewMoment(moment, time)
								end
							  end)
							  return "break"
							end
						  end
						end
						self:UpdateControl(obj.Frame, "+New Moment", control, "above timeline")
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "DeleteNewMomentControl(self)",
			'func', function (self)
						local control = self:ResolveId("idMoment-NewMoment")
						if control then
						  control:delete()
						end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "CreateMomentControls(self, ...)",
			'func', function (self, ...)
						local obj = GetAnimationMomentsEditorObject()
						if not obj then
						  return
						end
						for i = #self, 1, -1 do
						  local control = self[i]
						  if string.match(control.Id, "^idMoment-") then
							control:delete()
						  end
						end
						local control = XText:new({
						  Id = "idMoment-CurrentMoment"
						}, self)
						control:SetTextStyle(self.idDuration:GetTextStyle())
						control:SetDock("ignore")
						self:UpdateControl(obj.Frame, FormatTimeline(obj.Frame), control, "above timeline")
						if obj.anim_speed == 0 then
						  self:CreateNewMomentControl()
						end
						local visible_types = self:GetEnabledMomentTypes()
						local moment_types = {}
						local moments = obj:GetAnimMoments()
						table.sortby_field(moments, "Time")
						for index, moment in ipairs(moments) do
						  moment_types[moment.Type] = true
						  local visible = visible_types[moment.Type]
						  if visible == nil or visible == true then
							local control = XTextButton:new({
							  Id = "idMoment",
							  moment = moment,
							  offset = 0,
							  dragging = false,
							  update_thread = false
							}, self)
							self:InitControl(control)
							local time, text = self:GetMomentTime(moment)
							self:UpdateControl(time, text, control, index % 2 == 1)
							function control.OnMouseButtonDown(this, pos, button)
							  if button == "L" then
								self:DeselectMoment()
								AnimMetadataEditorTimelineSelectedControl = this
								this:SetBackground(RGBA(38, 146, 227, 255))
								local frame = self.idTimeline:GetFrame(pos)
								local time = obj:GetAbsoluteTime(frame)
								AnimMetadataEditorTimelineSelectedControl.offset = time - this.moment.Time
								AnimMetadataEditorTimelineSelectedControl.dragging = true
								this.moment.AnimRevision = obj.AnimRevision
								self:DeleteNewMomentControl()
								return "break"
							  elseif button == "R" then
								CreateRealTimeThread(function()
								  if terminal.IsKeyPressed(const.vkControl) then
									local actors = ActorFXClassCombo()
									table.remove_value(actors, "any")
									local actor = WaitListChoice(terminal.desktop, actors, "Select Actor", 1, nil, "free_input")
									if actor then
									  moment.Actor = actor
									end
								  else
									local actions = ActionFXClassCombo()
									table.remove_value(actions, "any")
									local fx = WaitListChoice(terminal.desktop, actions, "Select FX", 1, nil, "free_input")
									if fx then
									  moment.FX = fx
									end
								  end
								end)
								return "break"
							  end
							end
							function control.OnMouseButtonUp(this, pos, button)
							  if button ~= "L" then
								return
							  end
							  if not AnimMetadataEditorTimelineSelectedControl then
								return
							  end
							  DeleteThread(AnimMetadataEditorTimelineSelectedControl.update_thread)
							  local dragging = AnimMetadataEditorTimelineSelectedControl
							  local moment = dragging.moment
							  local frame = self.idTimeline:GetFrame(pos)
							  local time = obj:GetAbsoluteTime(frame)
							  local duration = obj:GetAbsoluteTime(obj.anim_duration)
							  moment.Time = Clamp(time - dragging.offset, 0, duration - 1)
							  table.sortby_field(moments, "Time")
							  dragging.update_thread = false
							  dragging.dragging = false
							  AnimationMomentsEditorBindObjects(obj)
							  self:CreateNewMomentControl()
							  obj:SetFrame(obj:GetModifiedTime(moment.Time))
							  return "break"
							end
							function control.OnMousePos(this, pos)
							  if not AnimMetadataEditorTimelineSelectedControl then
								return
							  end
							  if not AnimMetadataEditorTimelineSelectedControl.dragging then
								return
							  end
							  local dragging = AnimMetadataEditorTimelineSelectedControl
							  local moment = dragging.moment
							  local frame = self.idTimeline:GetFrame(pos)
							  local time = obj:GetAbsoluteTime(frame)
							  local duration = obj:GetAbsoluteTime(obj.anim_duration)
							  moment.Time = Clamp(time - dragging.offset, 0, duration - 1)
							  if not dragging.update_thread then
								dragging.update_thread = CreateRealTimeThread(function()
								  obj:SetFrame(obj:GetModifiedTime(moment.Time), "delayed moments binding")
								  table.sortby_field(moments, "Time")
								  dragging.update_thread = false
								end)
							  end
							  return "break"
							end
							function control.OnMouseButtonDoubleClick(this, pos, button)
							  if button ~= "L" then
								return
							  end
							  this.moment.AnimRevision = obj.AnimRevision
							  obj:SetFrame(obj:GetModifiedTime(self:GetMomentTime(this.moment)))
							  return "break"
							end
						  end
						end
						local parent = self:ResolveId("idFilters")
						for i = #parent, 1, -1 do
						  local control = parent[i]
						  if IsKindOf(control, "XCheckButton") then
							control:delete()
						  end
						end
						parent:SetVisible(next(moment_types))
						for _, moment_type in ipairs(table.keys2(moment_types, "sorted")) do
						  local check = XCheckButton:new({moment_type = moment_type}, parent)
						  check:SetCheck(true)
						  if visible_types[moment_type] ~= nil then
							check:SetCheck(visible_types[moment_type])
						  end
						  check:SetText(moment_type)
						  function check.OnChange(check, value)
							self:CreateMomentControls()
						  end
						end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "GetMomentControls(self)",
			'func', function (self)
						local moment_controls = {}
						for _, control in ipairs(self) do
						  if control.Id == "idMoment" then
							table.insert(moment_controls, control)
						  end
						end
						return moment_controls
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "GetEnabledMomentTypes(self)",
			'func', function (self)
						local enabled = {}
						for _, control in ipairs(self:ResolveId("idFilters")) do
						  if control.moment_type then
							enabled[control.moment_type] = control:GetCheck()
						  end
						end
						return enabled
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "InitControl(self, control)",
			'func', function (self, control)
						control:SetTextStyle(self.idDuration:GetTextStyle())
						control:SetDock("ignore")
						control:SetBackground(RGBA(128, 128, 128, 255))
						control:SetRolloverBackground(RGBA(192, 192, 192, 255))
						control:SetImage("CommonAssets/UI/round-frame-20.tga")
						control:SetImageScale(point(500, 500))
						control:SetFrameBox(box(9, 9, 9, 9))
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "UpdateControl(self, time, text, control, above_timeline)",
			'func', function (self, time, text, control, above_timeline)
						if not control then
						  return
						end
						local tw, th = control:Measure(1000000, 1000000)
						local b = self.idTimeline.box
						local width = b:sizex()
						local duration = GetAnimationMomentsEditorObject().anim_duration
						local column = b:minx() + width * time / Max(1, duration)
						local y = above_timeline and b:miny() - 5 - th or b:maxy() + 5
						if control.Id == "idMoment-NewMoment" then
						  y = y - control.box:sizey() - 5
						end
						control:SetBox(column - tw / 2, y, tw, th)
						local l, u, r, b = control.Padding:xyxy()
						local x1, y1, x2, y2 = control.box:xyxy()
						control:SetBox(x1 - l, y1 - u, x2 - x1 + l + r, y2 - y1 + u + b)
						control:SetText(text)
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "DeleteMoment(self,moment)",
			'func', function (self,moment)
						local obj = GetAnimationMomentsEditorObject()
						local moments = obj:GetAnimMoments()
						table.remove_entry(moments, moment)
						self:CreateMomentControls()
						AnimationMomentsEditorBindObjects(obj)
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "DeselectMoment(self)",
			'func', function (self)
						if AnimMetadataEditorTimelineSelectedControl then
						  AnimMetadataEditorTimelineSelectedControl:SetBackground(RGBA(128, 128, 128, 255))
						  AnimMetadataEditorTimelineSelectedControl = false
						end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "SelectMoment(self, control)",
			'func', function (self, control)
						AnimMetadataEditorTimelineSelectedControl = control
						control:SetBackground(RGBA(38, 146, 227, 255))
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnNewMoment(self, moment, time)",
			'func', function (self, moment, time)
						local obj = GetAnimationMomentsEditorObject()
						local entity, anim, anim_preset = GetOrCreateAnimMetadata(obj)
						local ent_speed = GetStateSpeedModifier(entity, GetStateIdx(anim))
						local absolute_time = MulDivTrunc(time, ent_speed, const.AnimSpeedScale)
						local new_moment = AnimMoment:new({
						  Type = moment,
						  Time = absolute_time,
						  AnimRevision = obj.AnimRevision,
						  parent = anim_preset
						})
						anim_preset.Moments = anim_preset.Moments or {}
						table.insert_sorted(anim_preset.Moments, new_moment, "Time")
						UpdateParentTable(new_moment, anim_preset)
						AnimationMomentsEditorBindObjects(obj)
						self:CreateMomentControls()
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "GetMomentTime(self, moment)",
			'func', function (self, moment)
						local obj = GetAnimationMomentsEditorObject()
						local time = obj:GetModifiedTime(moment.Time)
						local text = string.format("%s %s", moment.Type, FormatTimeline(time))
						return time, text
			end,
		}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XDialog",
	group = "Common",
	id = "CollisionsLegend",
	recreate_after_save = true,
	PlaceObj('XTemplateWindow', {
		'__class', "XDialog",
		'Id', "idCollisionsLegend",
		'Padding', box(0, 50, 0, 40),
		'Dock', "box",
		'HAlign', "right",
		'VAlign', "bottom",
		'MinWidth', 220,
		'MinHeight', 130,
		'LayoutMethod', "HList",
		'UseClipBox', false,
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'LayoutMethod', "VList",
			'UniformRowHeight', true,
			'Background', RGBA(0, 0, 0, 255),
		}, {
			PlaceObj('XTemplateWindow', {
				'Id', "idPassability",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(255, 0, 0, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "Passability",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idVisibility",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(0, 255, 0, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "Visibility",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idObstruction",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(0, 0, 255, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "Obstruction",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idPassabilityVisibility",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(255, 255, 0, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "Passability + Visibility",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idPassabilityObstruction",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(255, 0, 255, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "Passability + Obstruction",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idAllON",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(192, 192, 192, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'Text', "All ON",
					'TextVAlign', "center",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idAllOFF",
				'Margins', box(5, 5, 5, 5),
				'HAlign', "left",
				'VAlign', "center",
				'MinWidth', 200,
				'MinHeight', 30,
				'MaxWidth', 200,
				'MaxHeight', 30,
				'Background', RGBA(32, 32, 32, 255),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(5, 0, 5, 0),
					'HAlign', "left",
					'VAlign', "center",
					'MinWidth', 50,
					'MaxHeight', 30,
					'TextStyle', "GedDefaultDarkMode",
					'Text', "All OFF",
					'TextVAlign', "center",
				}),
				}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XRolloverWindow",
	group = "GedControls",
	id = "GedImageRollover",
	PlaceObj('XTemplateWindow', {
		'__class', "XRolloverWindow",
		'MaxWidth', 400,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XImage",
			'MaxWidth', 1366,
			'MaxHeight', 768,
			'ImageFit', "scale-down",
		}, {
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
							  parent:SetImage(context.control:GetRolloverText())
				end,
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
		}, {
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
							  local text = context.control:GetRolloverText()
							  local width, height = UIL.MeasureImage(text)
							  parent:SetText(tostring(width) .. "x" .. tostring(height))
				end,
			}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XMenuBar",
	group = "GedControls",
	id = "GedMenuBar",
	PlaceObj('XTemplateWindow', {
		'__class', "XMenuBar",
		'Id', "idMenubar",
		'Dock', "top",
		'MenuEntries', "main",
	}),
})
PlaceObj('XTemplate', {
	group = "GedControls",
	id = "GedNestedElementsCategory",
	PlaceObj('XTemplateWindow', {
		'Id', "idWin",
		'IdNode', true,
		'Margins', box(0, 0, 0, 5),
		'BorderWidth', 1,
		'MinWidth', 280,
		'MaxWidth', 280,
		'LayoutMethod', "VList",
		'Background', RGBA(128, 128, 128, 64),
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'Id', "idCategoryTitle",
			'TextStyle', "GedTitleSmall",
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XList",
			'Id', "idCategoryElements",
			'BorderWidth', 0,
		}),
		}),
})
PlaceObj('XTemplate', {
	group = "GedControls",
	id = "GedNestedElementsList",
	PlaceObj('XTemplateWindow', {
		'__class', "XDialog",
		'Background', RGBA(0, 0, 0, 160),
	}, {
		PlaceObj('XTemplateWindow', {
			'Id', "idPopupBackground",
			'Margins', box(30, 50, 30, 30),
			'BorderWidth', 2,
			'HAlign', "center",
			'VAlign', "center",
			'Background', RGBA(128, 128, 128, 16),
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XMoveControl",
				'Margins', box(0, 0, 0, 10),
				'Dock', "top",
				'Background', RGBA(128, 128, 128, 64),
				'Target', "idPopupBackground",
				'FocusedBackground', RGBA(128, 128, 128, 64),
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "idTitle",
					'Margins', box(4, 2, 4, 2),
					'Dock', "left",
					'TextStyle', "GedTitle",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XTextButton",
					'Padding', box(1, 1, 1, 1),
					'Dock', "right",
					'VAlign', "center",
					'LayoutHSpacing', 0,
					'Background', RGBA(0, 0, 0, 0),
					'OnPressEffect', "close",
					'RolloverBackground', RGBA(204, 232, 255, 255),
					'PressedBackground', RGBA(121, 189, 241, 255),
					'TextStyle', "GedTitle",
					'Text', "X",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'Id', "idLeftList",
				'IdNode', true,
				'Margins', box(0, 0, 0, 7),
				'Padding', box(10, 0, 10, 0),
				'Dock', "left",
				'MinWidth', 310,
				'MaxWidth', 310,
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XEdit",
					'Id', "idSearch",
					'IdNode', true,
					'Margins', box(0, 0, 0, 5),
					'Dock', "top",
				}),
				PlaceObj('XTemplateWindow', {
					'Id', "idWin",
					'IdNode', true,
					'BorderWidth', 1,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XList",
						'Id', "idList",
						'IdNode', false,
						'BorderWidth', 0,
						'VScroll', "idScroll",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XSleekScroll",
						'Id', "idScroll",
						'Dock', "right",
						'Target', "idList",
						'SnapToItems', true,
						'AutoHide', true,
					}),
					}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XScrollArea",
				'Id', "idRightList",
				'IdNode', false,
				'Margins', box(0, 0, 5, 7),
				'BorderWidth', 1,
				'Padding', box(3, 3, 3, 0),
				'LayoutMethod', "VWrap",
				'LayoutHSpacing', 5,
				'Background', RGBA(240, 240, 240, 255),
				'HScroll', "idHScroll",
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XSleekScroll",
					'Id', "idHScroll",
					'Dock', "bottom",
					'DrawOnTop', true,
					'Target', "idRightList",
					'SnapToItems', true,
					'AutoHide', true,
					'Horizontal', true,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XText",
				'Margins', box(4, 2, 4, 2),
				'Dock', "bottom",
				'Text', "(click to choose an item)",
			}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XRolloverWindow",
	group = "GedControls",
	id = "GedPropRollover",
	PlaceObj('XTemplateWindow', {
		'__class', "XRolloverWindow",
		'MaxWidth', 800,
		'DrawOnTop', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'Margins', box(8, 4, 8, 4),
		}, {
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
							  parent:SetText(context.control:GetRolloverText())
				end,
			}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	group = "GedControls",
	id = "GedToolbarSection",
	PlaceObj('XTemplateWindow', {
		'IdNode', true,
		'Margins', box(2, 2, 2, 2),
		'BorderWidth', 1,
		'LayoutMethod', "VList",
		'LayoutVSpacing', 2,
		'BorderColor', RGBA(160, 160, 160, 255),
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XLabel",
			'Id', "idSectionName",
			'HAlign', "center",
			'VAlign', "center",
			'Text', "Name",
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "divider",
			'MinHeight', 1,
			'Background', RGBA(160, 160, 160, 255),
		}),
		PlaceObj('XTemplateWindow', {
			'Id', "idActionContainer",
			'LayoutMethod', "HWrap",
			'LayoutHSpacing', 2,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "SetName(self, name)",
			'func', function (self, name)
						self.idSectionName:SetText(name)
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "GetContainer(self)",
			'func', function (self)
						return self.idActionContainer
			end,
		}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "GedApp",
	group = "GedApps",
	id = "PresetEditTemplate",
	PlaceObj('XTemplateWindow', {
		'__class', "GedApp",
		'Translate', true,
		'Title', "<PresetClass> Editor<opt(u(EditorShortcut),' (',')')>",
	}, {
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "root" end,
			'__class', "GedTreePanel",
			'Id', "idPresets",
			'Title', "Items",
			'TitleFormatFunc', "GedFormatPresets",
			'SearchHistory', 20,
			'SearchValuesAvailable', true,
			'PersistentSearch', true,
			'ActionsClass', "Preset",
			'Delete', "GedOpPresetDelete",
			'Cut', "GedOpPresetCut",
			'Copy', "GedOpPresetCopy",
			'Paste', "GedOpPresetPaste",
			'Duplicate', "GedOpPresetDuplicate",
			'ActionContext', "PresetsPanelAction",
			'SearchActionContexts', {
				"PresetsPanelAction",
				"PresetsChildAction",
			},
			'FormatFunc', "GedPresetTree",
			'Format', "<if(mod)>[<u('ModItem')>] </if><if(IsReadOnly)><color 150 150 150></if><EditorView><if(IsReadOnly)></color></if>",
			'FilterName', "PresetFilter",
			'SelectionBind', "SelectedPreset,SelectedObject",
			'MultipleSelection', true,
			'ItemClass', function (gedapp) return gedapp.PresetClass end,
			'RootActionContext', "PresetsPanelAction",
			'ChildActionContext', "PresetsChildAction",
		}, {
			PlaceObj('XTemplateWindow', {
				'comment', "bookmarks",
				'__context', function (parent, context) return "bookmarks" end,
				'__class', "GedTreePanel",
				'Id', "idBookmarks",
				'Dock', "bottom",
				'MaxHeight', 350,
				'Collapsible', true,
				'StartsExpanded', true,
				'ExpandedMessage', "(press F2 to cycle)",
				'EmptyMessage', "(press Ctrl-F2 to bookmark)",
				'Title', "Bookmarks",
				'EnableSearch', false,
				'FormatFunc', "GedBookmarksTree",
				'Format', "<EditorView>",
				'SelectionBind', "SelectedPreset,SelectedObject,SelectedBookmark",
				'EmptyText', "Add a bookmark here by pressing Ctrl-F2.",
				'ChildActionContext', "BookmarksChildAction",
				'ShowToolbarButtons', false,
			}, {
				PlaceObj('XTemplateFunc', {
					'name', "Open(self, ...)",
					'func', function (self, ...)
						self.expanded = true
						GedTreePanel.Open(self, ...)
						self.connection:Send("rfnBindBookmarks", self.context, self.app.PresetClass)
					end,
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "RemoveBookmark",
					'ActionTranslate', false,
					'ActionName', "Remove Bookmark",
					'OnAction', function (self, host, source, ...)
						host:Send("GedToggleBookmark", "SelectedBookmark", host.PresetClass)
					end,
					'ActionContexts', {
						"BookmarksChildAction",
					},
				}),
				PlaceObj('XTemplateAction', {
					'ActionId', "NextBookmark",
					'ActionTranslate', false,
					'ActionName', "Next Bookmark",
					'ActionShortcut', "F2",
					'OnAction', function (self, host, source, ...)
						local tree = host.idPresets.idBookmarks.idContainer
						local selection = tree:GetSelection()
						if not selection then
							tree:SetSelection{ 1 }
						else
							tree:OnShortcut("Down")
							local new_selection = tree:GetSelection() -- get first value returned
							if ValueToLuaCode(selection) == ValueToLuaCode(new_selection) then
								tree:SetSelection{ 1 }
							end
						end
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'comment', "preset filter panel",
				'__context', function (parent, context) return "PresetFilter" end,
				'__class', "GedPropPanel",
				'Dock', "bottom",
				'Visible', false,
				'FoldWhenHidden', true,
				'Collapsible', true,
				'Title', "<FilterName>",
				'EnableSearch', false,
				'DisplayWarnings', false,
				'EnableUndo', false,
				'EnableCollapseDefault', false,
				'EnableShowInternalNames', false,
				'EnableCollapseCategories', false,
				'HideFirstCategory', true,
			}),
			PlaceObj('XTemplateTemplate', {
				'__template', "GedStatusBar",
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "File",
			'ActionName', T(598810390625, --[[XTemplate PresetEditTemplate ActionName]] "File"),
			'ActionMenubar', "main",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "idNews",
				'ActionName', T(906571769768, --[[XTemplate PresetEditTemplate ActionName]] "New"),
				'ActionIcon', "CommonAssets/UI/Ged/new.tga",
				'ActionToolbar', "main",
				'OnActionEffect', "popup",
			}, {
				PlaceObj('XTemplateForEach', {
					'array', function (parent, context) return context.Classes end,
					'run_after', function (child, context, item, i, n, last)
						child.ActionId = "New" .. item
						child.ActionName = "New " .. item
						child.ActionTranslate = false
						child.OnAction = function(self, host)
							host:Op("GedOpNewPreset", "root", host.idPresets:GetSelection(), item)
						end
					end,
				}, {
					PlaceObj('XTemplateAction', {
						'ActionIcon', "CommonAssets/UI/Ged/new.tga",
						'ActionContexts', {
							"PresetsPanelAction",
						},
					}),
					}),
				}),
			PlaceObj('XTemplateCode', {
				'comment', '-- If single "new" action, move to top level',
				'run', function (self, parent, context)
					local newAction = parent:ActionById("idNews")
					local subitemActions = table.ifilter(parent:GetActions(), function(k, action) return action.ActionMenubar == "idNews" end)
					if #subitemActions == 1 then
						subitemActions[1]:SetActionMenubar(newAction.ActionMenubar)
						subitemActions[1]:SetActionToolbar("main")
						parent:RemoveAction(newAction)
					end
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SavePreset",
				'ActionName', T(589705960708, --[[XTemplate PresetEditTemplate ActionName]] "Save"),
				'ActionIcon', "CommonAssets/UI/Ged/save.tga",
				'ActionToolbar', "main",
				'ActionToolbarSplit', true,
				'ActionShortcut', "Ctrl-S",
				'OnAction', function (self, host, source, ...)
					host:OnSaving()
					host:Send("GedPresetSave", "SelectedPreset", host.PresetClass)
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SavePresetForce",
				'ActionName', T(120290275043, --[[XTemplate PresetEditTemplate ActionName]] "Force Save All"),
				'ActionIcon', "CommonAssets/UI/Ged/save.tga",
				'ActionShortcut', "Ctrl-Shift-S",
				'OnAction', function (self, host, source, ...)
					host:OnSaving()
					host:Send("GedPresetSave", "SelectedPreset", host.PresetClass, "force_save_all")
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SVNShowLog",
				'ActionTranslate', false,
				'ActionName', "SVN Show Log",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpSVNShowLog", "SelectedPreset")
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SVNShowDiff",
				'ActionTranslate', false,
				'ActionName', "SVN Diff",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpSVNShowDiff", "SelectedPreset")
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "SVNShowBlame",
				'ActionTranslate', false,
				'ActionName', "SVN Blame",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpSVNShowBlame", "SelectedPreset")
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "LocatePreset",
				'ActionTranslate', false,
				'ActionName', "Find preset references",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpLocatePreset", "SelectedPreset")
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "GoToNext",
				'ActionTranslate', false,
				'ActionName', "Next reference",
				'ActionShortcut', "Ctrl-G",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpGoToNext", "SelectedPreset")
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "AddRemoveBookmark",
				'ActionTranslate', false,
				'ActionName', "Add / Remove Bookmark",
				'ActionIcon', "CommonAssets/UI/Ged/bookmark_icon",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-F2",
				'OnAction', function (self, host, source, ...)
					host:Send("GedToggleBookmark", "SelectedPreset", host.PresetClass)
				end,
				'ActionContexts', {
					"PresetsChildAction",
				},
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "ToggleDisplayWarnings",
				'ActionTranslate', false,
				'ActionName', "Toggle Display Warnings",
				'ActionIcon', "CommonAssets/UI/Ged/exclamation.tga",
				'ActionToolbar', "main",
				'ActionToolbarSplit', true,
				'ActionShortcut', "Ctrl-W",
				'ActionToggle', true,
				'ActionToggled', function (self, host)
					return host.actions_toggled["ToggleDisplayWarnings"]
				end,
				'OnAction', function (self, host, source, ...)
					host:SetActionToggled("ToggleDisplayWarnings", not host.actions_toggled["ToggleDisplayWarnings"])
					
					for _, panel in ipairs(host.all_panels) do
						if IsKindOf(panel, "GedPropPanel") or IsValid(panel) then
							local display_warnings = not host.actions_toggled["ToggleDisplayWarnings"]
							panel:SetDisplayWarnings(display_warnings)
							
							if not display_warnings then
								panel:UnbindView("warning")
								-- Hide existing warnings
								panel.idWarningText:SetVisible(false)
							else
								panel:BindView("warning", "GedGetWarning")
							end
						end
					end	
				end,
			}),
			}),
		PlaceObj('XTemplateCode', {
			'comment', "-- Custom Editor Actions",
			'run', function (self, parent, context)
				local has_toggle_actions = false
				
				for func_name, data in sorted_pairs(context.EditorCustomActions or empty_table) do
					if type(func_name) ~= "string" then func_name = data.FuncName end
					if type(func_name) ~= "string" or func_name == "" then func_name = false end
					
					local action = XAction:new({
						ActionId = data.Name,
						ActionName = data.Name or "Unnamed",
						ActionTranslate = false,
						ActionToggle = data.IsToggledFuncName,
						ActionShortcut = data.Shortcut or "",
						ActionMenubar = data.Menubar,
						ActionToolbar = data.Toolbar or "",
						ActionToolbarSplit = data.Split,
						ActionIcon = data.Icon or "CommonAssets/UI/Ged/cog.tga",
						ActionSortKey = data.SortKey or "10000",
						RolloverText = data.Rollover,
					}, parent)
					if func_name then
						action.OnAction = function(self, host)
							if data.IsToggledFuncName then
								parent.actions_toggled[data.Name] = not parent.actions_toggled[data.Name]
							end
							host:Send("GedCustomEditorAction", "SelectedPreset", func_name)
						end
					else
						action.OnActionEffect = "popup"
					end
					if data.IsToggledFuncName then
						has_toggle_actions = true
						action.ActionToggled = function(self, host)
							return host.actions_toggled[data.Name]
						end
					end
				end
				
				if has_toggle_actions then
					CreateRealTimeThread(function()
						for _, data in sorted_pairs(context.EditorCustomActions or empty_table) do
							if data.IsToggledFuncName then
								parent.actions_toggled[data.Name] = parent:Call("GedGetToggledActionState", data.IsToggledFuncName)
							end
						end
						parent:ActionsUpdated()
					end)
				end
			end,
		}),
		PlaceObj('XTemplateCode', {
			'comment', "-- Setup preset filter, alt format",
			'run', function (self, parent, context)
				parent.idPresets.FilterClass = parent.FilterClass
				parent.idPresets.AltFormat = parent.AltFormat
			end,
		}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XToolBar",
	group = "GedControls",
	id = "GedToolBar",
	PlaceObj('XTemplateWindow', {
		'__class', "XToolBar",
		'RolloverTemplate', "XRolloverWindow",
		'RolloverAnchor', "bottom",
		'Id', "idToolbar",
		'Margins', box(0, 1, 0, 1),
		'Padding', box(1, 1, 1, 1),
		'Dock', "top",
		'Toolbar', "main",
		'Show', "icon",
		'ButtonTemplate', "GedToolbarButton",
		'ToggleButtonTemplate', "GedToolbarToggleButton",
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XToggleButton",
	group = "GedControls",
	id = "GedToolbarToggleButton",
	PlaceObj('XTemplateWindow', {
		'__class', "XToggleButton",
		'RolloverTemplate', "GedToolbarRollover",
		'RolloverAnchor', "bottom",
		'BorderWidth', 1,
		'Padding', box(1, 1, 1, 1),
		'MaxWidth', 38,
		'MaxHeight', 38,
		'BorderColor', RGBA(0, 0, 0, 0),
		'Background', RGBA(0, 0, 0, 0),
		'RolloverBackground', RGBA(204, 232, 255, 255),
		'RolloverBorderColor', RGBA(38, 146, 227, 255),
		'PressedBackground', RGBA(121, 189, 241, 255),
		'PressedBorderColor', RGBA(38, 146, 227, 255),
		'Image', "CommonAssets/UI/round-frame-20.tga",
		'ImageScale', point(500, 500),
		'FrameBox', box(9, 9, 9, 9),
		'DisabledIconColor', RGBA(255, 255, 255, 64),
		'ToggledBackground', RGBA(24, 123, 197, 255),
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XTextButton",
	group = "GedControls",
	id = "GedToolbarButtonSmall",
	PlaceObj('XTemplateWindow', {
		'__class', "XTextButton",
		'RolloverTemplate', "GedToolbarRollover",
		'RolloverAnchor', "bottom",
		'Padding', box(2, 1, 2, 1),
		'Dock', "right",
		'FoldWhenHidden', true,
		'Background', RGBA(0, 0, 0, 0),
		'RolloverBackground', RGBA(204, 232, 255, 255),
		'PressedBackground', RGBA(121, 189, 241, 255),
		'IconScale', point(700, 700),
		'DisabledIconColor', RGBA(255, 255, 255, 64),
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XTextButton",
	group = "GedControls",
	id = "GedToolbarButton",
	PlaceObj('XTemplateWindow', {
		'__class', "XTextButton",
		'RolloverTemplate', "GedToolbarRollover",
		'RolloverAnchor', "bottom",
		'BorderWidth', 1,
		'Padding', box(1, 1, 1, 1),
		'MaxWidth', 38,
		'MaxHeight', 38,
		'BorderColor', RGBA(0, 0, 0, 0),
		'Background', RGBA(0, 0, 0, 0),
		'RolloverBackground', RGBA(204, 232, 255, 255),
		'RolloverBorderColor', RGBA(38, 146, 227, 255),
		'PressedBackground', RGBA(121, 189, 241, 255),
		'PressedBorderColor', RGBA(38, 146, 227, 255),
		'Image', "CommonAssets/UI/round-frame-20.tga",
		'ImageScale', point(500, 500),
		'FrameBox', box(9, 9, 9, 9),
		'DisabledIconColor', RGBA(255, 255, 255, 64),
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XRolloverWindow",
	group = "GedControls",
	id = "GedToolbarRollover",
	PlaceObj('XTemplateWindow', {
		'__class', "XRolloverWindow",
		'MaxWidth', 400,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'Margins', box(8, 4, 8, 4),
		}, {
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
							  local rollover = context.control:GetRolloverText()
							  parent:SetTranslate(IsT(rollover))
							  parent:SetText(rollover)
				end,
			}),
			}),
		}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XToggleButton",
	group = "GedControls",
	id = "GedToolbarToggleButtonSmall",
	PlaceObj('XTemplateWindow', {
		'__class', "XToggleButton",
		'RolloverTemplate', "GedToolbarRollover",
		'RolloverAnchor', "bottom",
		'BorderWidth', 1,
		'Padding', box(1, 1, 1, 1),
		'Dock', "right",
		'BorderColor', RGBA(0, 0, 0, 0),
		'Background', RGBA(0, 0, 0, 0),
		'RolloverBackground', RGBA(204, 232, 255, 255),
		'RolloverBorderColor', RGBA(38, 146, 227, 255),
		'PressedBackground', RGBA(121, 189, 241, 255),
		'PressedBorderColor', RGBA(38, 146, 227, 255),
		'Image', "CommonAssets/UI/round-frame-20.tga",
		'ImageScale', point(500, 500),
		'FrameBox', box(9, 9, 9, 9),
		'IconScale', point(700, 700),
		'DisabledIconColor', RGBA(255, 255, 255, 64),
		'ToggledBackground', RGBA(24, 123, 197, 255),
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XTextButton",
	group = "GedControls",
	id = "GedPropertyButton",
	PlaceObj('XTemplateWindow', {
		'__class', "XTextButton",
		'BorderWidth', 1,
		'Background', RGBA(200, 200, 200, 255),
		'RolloverBorderColor', RGBA(0, 0, 0, 255),
		'PressedBackground', RGBA(220, 220, 255, 255),
		'PressedBorderColor', RGBA(0, 0, 0, 255),
	}),
})
PlaceObj('XTemplate', {
	__is_kind_of = "XDarkModeAwareDialog",
	group = "Editor",
	id = "XEditorStatusbar",
	PlaceObj('XTemplateWindow', {
		'__class', "XDarkModeAwareDialog",
		'ZOrder', -1,
		'Dock', "bottom",
		'MaxHeight', 35,
		'FoldWhenHidden', true,
		'Background', RGBA(0, 0, 0, 255),
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'BorderWidth', 1,
			'Dock', "top",
			'MinHeight', 1,
			'MaxHeight', 1,
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "undo queue",
			'__class', "XCombo",
			'Margins', box(5, 0, 0, 0),
			'Dock', "left",
			'VAlign', "center",
			'MinWidth', 240,
			'MaxWidth', 240,
			'FoldWhenHidden', true,
			'OnContextUpdate', function (self, context, ...)
				local open = self:IsPopupOpen()
				if open then
				  self:CloseCombo()
				end
				self.Items = XEditorUndo:GetOpNames()
				self:SetValue(self.Items[XEditorUndo:GetCurrentOpNameIdx()] or self.Items[1])
				local opsDone = self.Items[1] ~= "No recent operations" or #self.Items > 1
				self:SetEnabled(opsDone)
				if open then
				  self:OpenCombo("select")
				end
			end,
			'Items', function (self)
				return XEditorUndo:GetOpNames()
			end,
			'ArbitraryValue', false,
			'ListItemTemplate', "XComboXTextListItemLight",
			'OnValueChanged', function (self, value)
				XEditorUndo:RollToOpIndex(table.find(self.Items, value))
				self.Items = XEditorUndo:GetOpNames()
				self:SetValue(self.Items[XEditorUndo:GetCurrentOpNameIdx()])
			end,
		}),
		PlaceObj('XTemplateTemplate', {
			'__template', "XEditorToolbarButton",
			'RolloverAnchor', "right",
			'RolloverText', T(579167267085, --[[XTemplate XEditorStatusbar RolloverText]] "Create/apply patch"),
			'Dock', "left",
			'VAlign', "center",
			'OnPressEffect', "action",
			'OnPressParam', "PatchPopup",
			'Icon', "CommonAssets/UI/Editor/Tools/Patch",
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "PatchPopup",
			'ActionTranslate', false,
			'OnAction', function (self, host, source, ...)
				  local menu = XPopupMenu:new({
					MenuEntries = self.ActionId,
					Anchor = IsKindOf(source, "XWindow") and source.box,
					AnchorType = "top",
					GetActionsHost = function(self)
					  return host
					end,
					DrawOnTop = true,
					popup_parent = self
				  }, terminal.desktop)
				  menu:Open()
				  Msg("XWindowRecreated", menu)
			end,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "CreatePatch",
				'ActionTranslate', false,
				'ActionName', "Create patch",
				'OnAction', function (self, host, source, ...)
					if XEditorUndo:GetCurrentOpNameIdx() == 1 then
					  CreateMessageBox(nil, Untranslated("No Map Changes"), Untranslated("There are no map changes to store as a patch."))
					  return
					end
					CreateRealTimeThread(function()
					  local default_name = string.format("%s %s.mappatch", GetMapName(), os.date("!%Y-%m-%d"))
					  local os_path = ConvertToOSPath("svnAssets/Bin/win32/Bin")
					  local file_path = OpenBrowseDialog(os_path, "Map patches|*.mappatch", false, false, default_name)
					  if file_path then
						XEditorCreateMapPatch(file_path)
					  end
					end)
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "ApplyPatch",
				'ActionTranslate', false,
				'ActionName', "Apply patch",
				'OnAction', function (self, host, source, ...)
					CreateRealTimeThread(function()
					  local os_path = ConvertToOSPath("svnAssets/Bin/win32/Bin")
					  local file_path = OpenBrowseDialog(os_path, "Map patches|*.mappatch", true)
					  if file_path then
						XEditorApplyMapPatch(file_path)
					  end
					end)
				end,
			}),
			}),
		PlaceObj('XTemplateTemplate', {
			'__template', "XEditorToolbarButton",
			'RolloverAnchor', "right",
			'RolloverText', T(531095426765, --[[XTemplate XEditorStatusbar RolloverText]] "Undo (Ctrl-Z)"),
			'Dock', "left",
			'VAlign', "center",
			'OnPressEffect', "action",
			'OnPress', function (self, gamepad)
				XEditorUndo:UndoRedo("undo")
			end,
			'Icon', "Mod/Chapi_MapEditor/UI/Editor/Tools/Undo.png",
		}),
		PlaceObj('XTemplateTemplate', {
			'__template', "XEditorToolbarButton",
			'RolloverAnchor', "right",
			'RolloverText', T(666266741793, --[[XTemplate XEditorStatusbar RolloverText]] "Redo (Ctrl-Y)"),
			'Dock', "left",
			'VAlign', "center",
			'OnPressEffect', "action",
			'OnPress', function (self, gamepad)
				XEditorUndo:UndoRedo("redo")
			end,
			'Icon', "Mod/Chapi_MapEditor/UI/Editor/Tools/Redo.png",
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XToolBar",
			'RolloverAnchor', "top",
			'Margins', box(3, 0, 3, 0),
			'Dock', "right",
			'Toolbar', "EditorStatusbar",
			'Show', "icon",
			'ButtonTemplate', "GedToolbarButton",
			'ToggleButtonTemplate', "XEditorToolbarToggleButton",
			'ToolbarSectionTemplate', "XEditorToolbarSection",
		}, {
			PlaceObj('XTemplateFunc', {
				'name', "GetActionsHost(self)",
				'func', function (self)
					return XShortcutsTarget
				end,
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'Margins', box(0, 4, 0, 4),
			'BorderWidth', 1,
			'Dock', "right",
			'MinWidth', 2,
			'MaxWidth', 2,
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "groups",
			'__class', "XCheckButtonCombo",
			'Margins', box(4, 0, 4, 0),
			'Dock', "right",
			'VAlign', "center",
			'MinWidth', 185,
			'MaxWidth', 185,
			'FoldWhenHidden', true,
			'OnContextUpdate', function (self, context, ...)
				local groups = XEditorGroupsComboItems(editor.GetSel())
				local count, group = 0, false
				for _, item in ipairs(groups) do
				  if item.value ~= false then
					count = count + 1
					group = item.id
				  end
				end
				self:SetText(count == 0 and "No groups" or count == 1 and group or "Multiple groups")
				self:SetEditable(#editor.GetSel() > 0)
			end,
			'Editable', true,
			'Items', function (self)
				return XEditorGroupsComboItems(editor.GetSel())
			end,
			'OnCheckButtonChanged', function (self, id, value)
				for _, obj in ipairs(editor.GetSel()) do
				  if value then
					obj:AddToGroup(id)
				  else
					obj:RemoveFromGroup(id)
				  end
				end
				self:OnContextUpdate()
			end,
			'OnTextChanged', function (self, value)
				if value == "No groups" or value == "Multiple groups" then
				  return
				end
				if Groups[value] then
				  local groups = {value}
				  for _, obj in ipairs(editor.GetSel()) do
					obj:SetGroups(groups)
				  end
				  self:SetFocus(false)
				  return
				end
				CreateRealTimeThread(function()
				  if WaitQuestion(terminal.desktop, Untranslated("Warning"), Untranslated(string.format("No such group '%s'. Create a new group?", value)), Untranslated("Yes"), Untranslated("No")) == "ok" then
					local groups = {value}
					for _, obj in ipairs(editor.GetSel()) do
					  obj:SetGroups(groups)
					end
					self:SetFocus(false)
				  end
				end)
			end,
			'OnComboOpened', function (self, popup)
				for _, checkbox in ipairs(popup.idContainer) do
				  XImage:new({
					Image = "CommonAssets/UI/Icons/eye outline.png",
					ImageFit = "scale-down",
					Dock = "right",
					MaxHeight = 24,
					HandleMouse = true,
					Background = 0,
					OnSetRollover = function(image, value)
					  local color = GetDarkModeSetting() and RGB(102, 102, 102) or RGB(200, 200, 200)
					  image:SetBackground(value and color or 0)
					  XEditorShowObjects(Groups[checkbox.Id], value)
					end,
					OnMouseButtonDown = function(image, pt, button)
					  if button == "L" then
						XEditorShowObjects(Groups[checkbox.Id], "select_permanently")
						self:CloseCombo()
					  end
					  return "break"
					end
				  }, checkbox)
				  checkbox:SetChildrenHandleMouse(true)
				end
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'Margins', box(0, 4, 0, 4),
			'BorderWidth', 1,
			'Dock', "right",
			'MinWidth', 2,
			'MaxWidth', 2,
		}),
		PlaceObj('XTemplateWindow', {
			'Dock', "right",
			'FoldWhenHidden', true,
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XText",
				'HAlign', "center",
				'VAlign', "center",
				'ContextUpdateOnOpen', true,
				'OnContextUpdate', function (self, context, ...)
					local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
					local class_name = dialog and dialog:GetHelperClass() or XSelectObjectsTool:GetHelperClass()
					self.parent:SetVisible(dialog)
					if class_name then
					  local parent = self.parent
					  parent[1]:SetVisible(not g_Classes[class_name].HasSnapSetting)
					  parent[2]:SetVisible(g_Classes[class_name].HasSnapSetting)
					end
					self:SetText(self.Text)
					XContextControl.OnContextUpdate(self, context)
				end,
				'Text', "(tool does not support snapping)",
			}),
			PlaceObj('XTemplateWindow', {
				'LayoutMethod', "HList",
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XCombo",
					'Margins', box(5, 0, 0, 0),
					'VAlign', "center",
					'MinWidth', 105,
					'MaxWidth', 105,
					'OnContextUpdate', function (self, context, ...)
						self:SetValue(XEditorSettings:GetSnapMode())
					end,
					'Items', function (self)
						return XEditorSettings:GetSnapModes()
					end,
					'ArbitraryValue', false,
					'OnValueChanged', function (self, value)
						XEditorSettings:SetSnapMode(value)
						local parent = self.parent
						for i = 1, #parent do
						  if parent[i] ~= self then
							parent[i]:SetEnabled(value == "Custom")
						  end
						end
						if GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool") then
						  XEditorSettings:OnEditorSetProperty("SnapMode")
						end
						XEditorUpdateToolbars()
					end,
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnShortcut(self, shortcut, source, ...)",
						'func', function (self, shortcut, source, ...)
							if shortcut == "Escape" then
							  terminal.desktop:RemoveKeyboardFocus(self, true)
							else
							  XCombo.OnShortcut(self, shortcut, source, ...)
							end
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(10, 0, 0, 0),
					'VAlign', "center",
					'Text', "XY:",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "snapping XY edit",
					'__class', "XEdit",
					'VAlign', "center",
					'MinWidth', 40,
					'MaxWidth', 40,
					'OnContextUpdate', function (self, context, ...)
						LocalStorage.SnapXY = LocalStorage.SnapXY or 0
						local text = XEditorSettings:GetSnapMode() == "Custom" and tostring(1.0 * LocalStorage.SnapXY / guim) or tostring(1.0 * XEditorSettings:GetSnapXY() / guim)
						self:SetText(text)
					end,
					'OnTextChanged', function (self)
						local value = tonumber(self:GetText())
						value = value or 0
						value = floatfloor(value * guim)
						XEditorSettings:SetSnapXY(value)
						LocalStorage.SnapXY = XEditorSettings:GetSnapMode() == "Custom" and value or LocalStorage.SnapXY or 0
					end,
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnShortcut(self, shortcut, source, ...)",
						'func', function (self, shortcut, source, ...)
							if shortcut == "Escape" then
							  terminal.desktop:RemoveKeyboardFocus(self, true)
							else
							  XEdit.OnShortcut(self, shortcut, source, ...)
							end
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'VAlign', "center",
					'Text', "m",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(6, 0, 0, 0),
					'VAlign', "center",
					'Text', "Z:",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "snapping Z edit",
					'__class', "XEdit",
					'VAlign', "center",
					'MinWidth', 40,
					'MaxWidth', 40,
					'OnContextUpdate', function (self, context, ...)
						LocalStorage.SnapZ = LocalStorage.SnapZ or 0
						local text = XEditorSettings:GetSnapMode() == "Custom" and tostring(1.0 * LocalStorage.SnapZ / guim) or tostring(1.0 * XEditorSettings:GetSnapZ() / guim)
						self:SetText(text)
					end,
					'OnTextChanged', function (self)
						local value = tonumber(self:GetText())
						value = value or 0
						value = floatfloor(value * guim)
						XEditorSettings:SetSnapZ(value)
						LocalStorage.SnapZ = XEditorSettings:GetSnapMode() == "Custom" and value or LocalStorage.SnapZ or 0
					end,
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnShortcut(self, shortcut, source, ...)",
						'func', function (self, shortcut, source, ...)
							if shortcut == "Escape" then
							  terminal.desktop:RemoveKeyboardFocus(self, true)
							else
							  XEdit.OnShortcut(self, shortcut, source, ...)
							end
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'VAlign', "center",
					'Text', "m",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Margins', box(6, 0, 0, 0),
					'VAlign', "center",
					'Text', "A",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "snapping angle edit",
					'__class', "XEdit",
					'VAlign', "center",
					'MinWidth', 40,
					'MaxWidth', 40,
					'OnContextUpdate', function (self, context, ...)
						LocalStorage.SnapAngle = LocalStorage.SnapAngle or 0
						local text = XEditorSettings:GetSnapMode() == "Custom" and tostring(1.0 * LocalStorage.SnapAngle / 60) or tostring(1.0 * XEditorSettings:GetSnapAngle() / 60)
						self:SetText(text)
					end,
					'OnTextChanged', function (self)
						local value = tonumber(self:GetText())
						value = value or 0
						value = floatfloor(value * 60)
						XEditorSettings:SetSnapAngle(value)
						LocalStorage.SnapAngle = XEditorSettings:GetSnapMode() == "Custom" and value or LocalStorage.SnapAngle or 0
					end,
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnShortcut(self, shortcut, source, ...)",
						'func', function (self, shortcut, source, ...)
							if shortcut == "Escape" then
							  terminal.desktop:RemoveKeyboardFocus(self, true)
							else
							  XEdit.OnShortcut(self, shortcut, source, ...)
							end
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'VAlign', "center",
					'Text', "°",
				}),
				}),
			}),
		PlaceObj('XTemplateWindow', {
			'__class', "XCheckButton",
			'Margins', box(5, 0, 5, 0),
			'Dock', "right",
			'FoldWhenHidden', true,
			'OnContextUpdate', function (self, context, ...)
				local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
				local class_name = dialog and dialog:GetHelperClass() or XSelectObjectsTool:GetHelperClass()
				self:SetVisible(dialog)
				if class_name then
				  self:SetEnabled(g_Classes[class_name].HasSnapSetting)
				end
				if self:GetEnabled() then
				  local row = XEditorSettings:GetSnapEnabled() and 2 or 1
				  self:SetIconRow(row)
				  self:OnRowChange(row)
				end
				self:SetText(self.Text)
				XContextControl.OnContextUpdate(self, context)
			end,
			'OnPress', function (self, gamepad)
				XEditorSettings:SetSnapEnabled(not XEditorSettings:GetSnapEnabled())
				XEditorUpdateToolbars()
				local row = XEditorSettings:GetSnapEnabled() and 2 or 1
				self:SetIconRow(row)
				self:OnRowChange(row)
			end,
			'Text', "Snap",
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XCheckButton",
			'Margins', box(5, 0, 5, 0),
			'Dock', "right",
			'FoldWhenHidden', true,
			'OnContextUpdate', function (self, context, ...)
				local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
				local class_name = dialog and dialog:GetHelperClass() or XSelectObjectsTool:GetHelperClass()
				self:SetVisible(dialog)
				if class_name then
				  self:SetEnabled(g_Classes[class_name].HasLocalCSSetting)
				end
				if self:GetEnabled() then
				  local row = GetLocalCS() and 2 or 1
				  self:SetIconRow(row)
				  self:OnRowChange(row)
				end
				self:SetText(self.Text)
				XContextControl.OnContextUpdate(self, context)
			end,
			'OnPress', function (self, gamepad)
				SetLocalCS(not GetLocalCS())
				XEditorUpdateToolbars()
				local row = GetLocalCS() and 2 or 1
				self:SetIconRow(row)
				self:OnRowChange(row)
			end,
			'Text', "Local CS",
		}),
		PlaceObj('XTemplateWindow', {
			'Margins', box(0, 4, 0, 4),
			'BorderWidth', 1,
			'Dock', "right",
			'MinWidth', 2,
			'MaxWidth', 2,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XToolBar",
			'RolloverAnchor', "top",
			'Margins', box(3, 0, 3, 0),
			'Dock', "right",
			'Toolbar', "XEditorStatusbar",
			'Show', "icon",
			'ButtonTemplate', "GedToolbarButton",
			'ToggleButtonTemplate', "XEditorToolbarToggleButton",
			'ToolbarSectionTemplate', "XEditorToolbarSection",
		}, {
			PlaceObj('XTemplateFunc', {
				'name', "GetActionsHost(self)",
				'func', function (self)
					return XShortcutsTarget
				end,
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'Margins', box(5, 0, 5, 0),
			'Dock', "box",
			'VAlign', "center",
			'Background', RGBA(0, 0, 0, 255),
			'OnContextUpdate', function (self, context, ...)
				local text = {}
				local sel = selo()
				if sel then
				  local info = sel.class
				  local editor_info = table.fget(sel, "EditorGetText", "(", ",", ":", ")")
				  if editor_info and editor_info ~= info then
					info = info .. ": " .. editor_info
					local max_len = 70
					if max_len < #info then
					  info = string.sub(info, 1, max_len)
					end
				  end
				  text[#text + 1] = info .. (1 < #editor.GetSel() and ", ..." or "")
				end
				if 1 < #editor.GetSel() then
				  local col_num = editor.GetSelUniqueCollections()
				  if col_num == 0 then
					text[#text + 1] = string.format("(%d objects)", #editor.GetSel())
				  else
					text[#text + 1] = string.format("(%d objects, %d collections)", #editor.GetSel(), col_num)
				  end
				end
				self.Text = table.concat(text, " ")
				self:SetText(self.Text)
				XContextControl.OnContextUpdate(self, context)
			end,
			'WordWrap', false,
			'Shorten', true,
		}),
		}),
})


PlaceObj('XTemplateAction', {
    'comment', "Toggle Camera Type (Ctrl-Shift-W)",
    'RolloverText', "Toggle Camera Type (Ctrl-Shift-W)",
    'ActionId', "E_CameraChange",
    'ActionTranslate', false,
    'ActionName', "Toggle Camera Type",
    'ActionIcon', "CommonAssets/UI/Menu/CameraToggle.tga",
    'ActionShortcut', "Ctrl-Shift-W",
    'OnAction', function (self, host, source, ...)
        if cameraRTS.IsActive() then
            cameraFly.Activate(1)
        elseif cameraFly.IsActive() then
            cameraMax.Activate(1)
        else
            cameraRTS.Activate(1)
        end
    end,
    'replace_matching_id', true,
})

function MapDataPreset:GetEditorViewPresetPrefix()
	return ""
end
MapDataPreset.EditorViewPresetPostfix = ""

-- Unlocking the Options inside Map Data
function MapDataPreset:IsReadOnly()
	return
end

-- Unlocking the Options inside Presets
function Preset:IsReadOnly()
	return
end


function ChangeMapData()
    --function OnMsg.ClassesPreprocess()
        local hide = {
            Author = true,
            Status = true,
            ScriptingAuthor = true,
            ScriptingStatus = true,
            SoundsStatus = true,
            
            DisplayName = true,
            Description = true,
            MapType = true,
            GameLogic = true,
            NoTerrain = true,
            DisablePassability = true,
            ModEditor = true,
            
            CameraUseBorderArea = true,
            CameraType = true,
            
            IsPrefabMap = true,
            IsRandomMap = true,
            Terrain = true,
            ZOrder = true,
            OrthoTop = true,
            OrthoBottom = true,
            PassBorder = true,
            PassBorderTiles = true,
            TerrainTreeRows = true,
            
            Playlist = true,
            BlacklistStr = true,
            LockMarkerChanges = true,
            PublishRevision = true,
            CreateRevisionOld = true,
            ForcePackOld = true,
            StartupEnable = true,
            StartupCam = true,
            StartupEditor = true,
            LuaRevision = true,
            OrgLuaRevision = true,
            AssetsRevision = true,
            NetHash = true,
            ObjectsHash = true,
            TerrainHash = true,
            SaveEntityList = true,
            InternalTesting = true,
            
            BiomeGroup = true,
            HeightMin = true, 
            HeightMax = true, 
            WetMin = true,    
            WetMax = true,    
            SeaLevel = true,  
            SeaPreset = true, 
            SeaMinDist = true,
            MapGenSeed = true,
            PersistedPrefabsPreview = true,
        }
        for _, prop in ipairs(MapDataPreset.properties) do
            if hide[prop.id] then
                prop.no_edit = true
            end
        end
    end


if FirstLoad then
    l_editor_boxes = false
end

function PlaceEditorBoxes(obj, new_selection, old_selection, parent)
    if new_selection[obj] or obj.editor_ignore then return end
    local propagate
    local mesh = old_selection[obj]
    if not mesh then
        local ebox = obj:GetEntityBBox()
        if obj:GetGameFlags(const.gofMirrored) ~= 0 then
            local x1, y1, z1, x2, y2, z2 = ebox:xyzxyz()
            ebox = box(x1, -y2, z1, x2, -y1, z2)
        end
        mesh = Mesh:new()
        mesh:SetShader(ProceduralMeshShaders.default_polyline)
        PlaceBox(ebox, parent and 0xcccccc00 or 0xcccccccc, mesh, true)
        mesh.editor_ignore = true
        mesh:ClearMeshFlags(const.mfWorldSpace)
        obj:Attach(mesh)
        propagate = true
    end
    new_selection[obj] = mesh
    if propagate then
        obj:ForEachAttach(PlaceEditorBoxes, new_selection, old_selection, obj)
    end
end

function UpdateEditorBoxes(selection)
    local new_selection = setmetatable({}, weak_keys_meta)
    local old_selection = l_editor_boxes or empty_table
    l_editor_boxes = new_selection
    for i=1,#(selection or "") do
        PlaceEditorBoxes(selection[i], new_selection, old_selection)
    end
    for obj, mesh in pairs(old_selection or empty_table) do
        if not new_selection[obj] then
           DoneObject(mesh)
        end
    end
end

function OnMsg.EditorSelectionChanged(selection)
    UpdateEditorBoxes(selection)
end

function OnMsg.GameEnterEditor()
    UpdateEditorBoxes(editor.GetSel())
end

function OnMsg.GameExitEditor()
    UpdateEditorBoxes()
end

function OnMsg.ChangeMap()
    UpdateEditorBoxes()
end

function OnMsg.SaveGameStart()
    UpdateEditorBoxes()
end

function LuaModEnv(env)
	return
end