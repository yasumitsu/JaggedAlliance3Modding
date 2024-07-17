DefineClass.PopupNotificationBase = {
	__parents = { "ZuluModalDialog" },
}

---
--- Opens the popup notification dialog.
---
--- If the popup has an associated ID, it will pause the campaign time and notify other clients of the popup being added.
--- If the popup has no associated ID, it will hide the notification image background.
---
--- The popup will display the image specified in the context, or a placeholder image if none is provided.
---
--- Finally, the popup is opened using the ZuluModalDialog:Open() method, and a "PopUp Tutorial Window" FX is played.
---
--- @param self PopupNotificationBase
function PopupNotificationBase:Open()
	if self.context.id then -- Popup mode, otherwise manually opened help menu mode.
		if gv_SatelliteView then PauseCampaignTime(GetUICampaignPauseReason("Popup")) end
		NetSyncEvent("AddPopup", self.context.id, netUniqueId)
	else
		self.idNotificationImageBg:SetVisible(false)
	end
	if #(self.context.image or "") > 0 then
		self.idNotificationImage:SetImage(self.context.image)
	else
		self.idNotificationImage:SetImage("UI/Messages/message_placeholder")
	end
	ZuluModalDialog.Open(self)
	PlayFX("PopUp Tutorial Window")
end

-- Hooked up to delete as we want to call RemovePopup after XDialog:Done 
---
--- Deletes the popup notification dialog.
---
--- If the popup has an associated ID, it will resume the campaign time and notify other clients of the popup being removed.
--- If the popup has no associated ID, it will not perform any additional actions.
---
--- The popup's voice audio, if any, will be stopped.
---
--- Finally, the popup is closed using the ZuluModalDialog:delete() method, and a "Close Popup Tutorial Window" FX is played.
---
--- @param self PopupNotificationBase
--- @param ... Additional arguments passed to the ZuluModalDialog:delete() method
function PopupNotificationBase:delete(...)
	if self.context.voice then
		SetSoundVolume(self.context.voice, -1, 1000)
	end

	local id = self.context and self.context.id
	ZuluModalDialog.delete(self, ...)

	if id then
		ResumeCampaignTime(GetUICampaignPauseReason("Popup"))
		NetSyncEvent("RemovePopup", id, netUniqueId)
	end
	ObjModified("CornerIntelRespawn") -- Workaround with problem with tutorials in deployment
	
	PlayFX("Close Popup Tutorial Window")
end

---
--- Shows a popup notification with the given ID and context.
---
--- If a popup with the given ID is marked as "once only", it will be disabled after being shown.
---
--- The text of the popup will be localized using the provided context. If the game is using gamepad controls, the "GamepadText" field of the popup preset will be used instead of the "Text" field.
---
--- If there is already an open popup notification, the new popup will be added to a queue and shown after the current one is closed.
---
--- @param id string The ID of the popup notification to show.
--- @param context table A table containing context information to be used for localizing the popup text.
--- @return boolean True if the popup was successfully shown, false otherwise.
function ShowPopupNotification(id, context)
	local preset = PopupNotifications[id]
	if not preset then
		print("No popup notification with id:" .. id)
		return false
	end
	
	if preset.OnceOnly then
		gv_DisabledPopups[id] = true
	end
	
	local text = GetUIStyleGamepad() and preset.GamepadText or preset.Text
	local context = {title = preset.Title, text = T{text, context}, id = id, image = preset.Image}
	if GetDialog("PopupNotification") then
		g_PopupQueue[#g_PopupQueue + 1] = context
	else
		OpenPopupNotification(context)
	end
	return true
end

function OnMsg.PreOpenSatelliteView()
	CloseDialog("PopupNotification")
end

function OnMsg.CloseSatelliteView()
	CloseDialog("PopupNotification")
end

---
--- Waits for all open popup notifications to be closed.
---
--- This function will block until all open popup notifications have been closed.
---
--- @return nil
function WaitAllPopupNotifications()
	local openPopupNotifaction = GetDialog("PopupNotification")
	while openPopupNotifaction do
		WaitMsg(openPopupNotifaction)
		openPopupNotifaction = GetDialog("PopupNotification")
	end
end

if FirstLoad then
	g_PopupNetReasons = {}
	g_PopupQueue = {}
end

---
--- Adds a new popup notification to the network sync event queue.
---
--- This function is called when a popup notification needs to be synchronized across the network.
--- It adds the popup notification ID and the player ID to the `g_PopupNetReasons` table, which is used to track which players need to see the popup.
---
--- @param id string The ID of the popup notification to add.
--- @param player_id string The ID of the player who needs to see the popup notification.
---
--- @return nil
function NetSyncEvents.AddPopup(id, player_id)
	g_PopupNetReasons[id] = g_PopupNetReasons[id] or {}
	table.insert_unique(g_PopupNetReasons[id], player_id)
end

---
--- Removes a popup notification from the network sync event queue.
---
--- This function is called when a popup notification needs to be removed from the network sync event queue.
--- It removes the player ID from the `g_PopupNetReasons` table for the given popup notification ID. If there are no more players that need to see the popup, it removes the entry from the `g_PopupNetReasons` table and closes the popup.
--- If there are other popups in the `g_PopupQueue`, it opens the next popup in the queue.
---
--- @param id string The ID of the popup notification to remove.
--- @param player_id string The ID of the player who no longer needs to see the popup notification.
---
--- @return nil
function NetSyncEvents.RemovePopup(id, player_id)
	if g_PopupNetReasons[id] then
		table.remove_value(g_PopupNetReasons[id], player_id)
	end
	if not next(g_PopupNetReasons[id]) then
		g_PopupNetReasons[id] = nil
		Msg("ClosePopup" .. id)
		if next(g_PopupQueue) then
			local context = table.remove(g_PopupQueue, 1)
			OpenPopupNotification(context)
		end
	end
end

function OnMsg.ClassesGenerate(classdefs)
	table.iappend(classdefs.OptionsObject.properties, {
		{ name = T(120515161065, "Show Tutorials"), id = "HintsEnabled", category = "Gameplay", SortKey = -1000, storage = "account", editor = "bool", default = true, help = T(304572420636, "Display tutorial messages.")},
	})
end

---
--- Opens a popup notification dialog.
---
--- This function is responsible for opening a popup notification dialog. It checks if the popup is related to the current campaign, and whether tutorial hints are enabled. If tutorials are disabled, it still runs the logic as if the popup was shown and closed, for quest tracking purposes.
---
--- If the popup is a tutorial and hints are disabled, it adds and removes the popup from the network sync event queue without actually showing the dialog.
---
--- If the popup is enabled, it opens the "PopupNotification" dialog, with the parent dialog being the PDA dialog if it is visible.
---
--- @param context table The context information for the popup notification, including the ID.
---
--- @return nil
function OpenPopupNotification(context)
	local preset = PopupNotifications[context.id]
	if not preset:IsRelatedToCurrentCampaign() then return end
	local tutorial = preset.group == "Tutorial"
	local enabled_option
	if IsInMultiplayerGame() and g_NetHintsEnabled then
		enabled_option = g_NetHintsEnabled == "enabled"
	else
		enabled_option = GetAccountStorageOptionValue("HintsEnabled")
	end
	-- disable all tutorials in mp vs for now
	if IsCompetitiveGame() or IsGameReplayRunning() or g_TestCombat then
		enabled_option = false
	end
	if tutorial and not enabled_option then -- don't show pop-up, but run logic as if it was shown and closed (for quests)
		NetSyncEvent("AddPopup", context.id, netUniqueId)
		NetSyncEvent("RemovePopup", context.id, netUniqueId)
	else
		local parent = false
		local pda = GetDialog("PDADialog") or GetDialog("PDADialogSatellite")
		if pda and pda:IsVisible() then
			parent = pda.idDisplayPopupHost
		end
	
		OpenDialog("PopupNotification", parent, context)
	end
end

---
--- Shows a popup notification only once per campaign.
---
--- This function checks if the game is running and tutorials are not hidden. It then checks if the popup has already been shown for the current campaign by looking up a tracking quest. If the popup has not been shown, it calls `ShowPopupNotification` to display the popup. If the popup is successfully shown, it marks the popup as tracked in the tracking quest.
---
--- @param popup string The ID of the popup notification to show.
--- @return nil
function ShowOncePerCampaignPopup(popup)
	if not Game or Game.HideTutorials then return end

	local trackerQuest = gv_Quests.PopupTracker
	assert(trackerQuest) -- Quest to track popups exists
	if trackerQuest[popup] then return end
	if ShowPopupNotification(popup) then
		trackerQuest[popup] = true
	end
end

local oldShowPopupNotification = ShowPopupNotification

function OnMsg.GameTestsBegin()
	ShowPopupNotification = function(...)
		oldShowPopupNotification(...)
		CreateRealTimeThread( function()
			Sleep(1)
			CloseDialog("PopupNotification")
		end)
	end
end

function OnMsg.GameTestsEnd()
	ShowPopupNotification = oldShowPopupNotification
end

-- tutorial hints enabled in mp - consider host's option
if FirstLoad then
	g_NetHintsEnabled = false
end

function OnMsg.NetPlayerJoin(player)
	if NetIsHost() then
		NetEchoEvent("HintsEnabled", GetAccountStorageOptionValue("HintsEnabled"))
	end
end

---
--- Handles the event for enabling or disabling hints in a multiplayer game.
---
--- When the host of a multiplayer game changes the "HintsEnabled" option, this function is called to update the global `g_NetHintsEnabled` variable to reflect the new state.
---
--- @param enabled boolean Whether hints are enabled or disabled.
---
function NetEvents.HintsEnabled(enabled)
	g_NetHintsEnabled = enabled and "enabled" or "disabled"
end

function OnMsg.NetGameLeft()
	g_NetHintsEnabled = false
end

function OnMsg.GameOptionsChanged(category)
	local hints_enabled = GetAccountStorageOptionValue("HintsEnabled")
	if IsInMultiplayerGame() and NetIsHost() and hints_enabled ~= (g_NetHintsEnabled == "enabled") then
		NetEchoEvent("HintsEnabled", hints_enabled)
	end
end