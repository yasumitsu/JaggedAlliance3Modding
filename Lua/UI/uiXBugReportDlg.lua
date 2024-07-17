local oldCreateXBugReportDlg = CreateXBugReportDlg

---
--- Creates a new X bug report dialog.
---
--- @param summary string The summary of the bug report.
--- @param descr string The description of the bug report.
--- @param files table A table of file paths to attach to the bug report.
--- @param params table A table of additional parameters to pass to the bug report dialog.
--- @return table The bug report dialog instance.
---
function CreateXBugReportDlg(summary, descr, files, params)
	if Platform.steamdeck then
		return
	end
	
	local endUserVersion = not not Platform.goldmaster
	if Platform.steam and endUserVersion then
		local steam_beta, steam_branch = SteamGetCurrentBetaName()
		endUserVersion = not steam_beta or steam_branch == ""
	end
	
	local minimalVersion = not insideHG() and endUserVersion
	
	params = params or {}
	params.no_priority = not insideHG
	params.no_platform_tags = not insideHG
	params.force_save_check = "save as extra_info"
	
	if minimalVersion then
		table.set(params, "no_platform_tags", true)
		table.set(params, "no_game_tags", true)
		table.set(params, "no_header_combos", true)
		table.set(params, "no_attach_auto_save", true)
		table.set(params, "no_api_token",true)
	end
	
	table.set(params, "mod", LastEditedMod)
	table.set(params, "mod_related", AreModdingToolsActive())
	
	return oldCreateXBugReportDlg(summary, descr, files, params)
end
