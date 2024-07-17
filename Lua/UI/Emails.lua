GameVar("gv_ReceivedEmails", {})
--[[
	{
		id = "string", 			#id of the email preset
		read = bool,   			#if the email is read
		time = number 			#time when the email is received (Game.CampaignTime)
		uniqueId = number, 	#unique id of the specific email (identify repeatable emails)
		context = {},			#used for the email body T()
	}
	key(preset.id) = value(preset)
]]

-- Emails are sorted by game time

GameVar("gv_DelayedEmails", {})

---
--- Returns a table of all received emails, sorted in reverse chronological order.
--- Emails that no longer have a corresponding preset in the `Emails` table are removed.
---
--- @return table A table of received emails, sorted in reverse chronological order.
---
function GetReceivedEmails()
	local reversedEmails = table.copy(gv_ReceivedEmails)
	table.reverse(reversedEmails)
	for i, email in ripairs(reversedEmails) do
		if not Emails[email.id] then
			table.remove(reversedEmails, i)
		end
	end
	return reversedEmails
end

---
--- Returns a table of all received emails that have not been read.
---
--- @return table A table of received emails that have not been read.
---
function GetUnreadEmails()
	local emails = {}
	for i, email in ipairs(GetReceivedEmails()) do
		if not email.read then
			emails[#emails+1] = email
		end
	end
	return emails
end

---
--- Returns a table of all received emails that have a specific label.
---
--- @param labelId string The label to filter the emails by. Can be "AllMessages" or "Unread" for special cases.
--- @return table A table of received emails that have the specified label.
---
function GetReceivedEmailsWithLabel(labelId)
	local emails = {}
	if labelId == "AllMessages" then -- special case
		emails = GetReceivedEmails()
	elseif labelId == "Unread" then -- special case
		emails = GetUnreadEmails()
	else
		for i, email in ipairs(GetReceivedEmails()) do
			local preset = Emails[email.id]
			if preset and preset.label and preset.label == labelId then
				emails[#emails+1] = email
			end
		end
	end
	return emails
end

---
--- Checks if there are any unread emails with the specified label.
---
--- @param labelId string The label to filter the emails by. Can be "AllMessages" or "Unread" for special cases.
--- @return boolean True if there are any unread emails with the specified label, false otherwise.
---
function AnyUnreadEmails(labelId)
	local emails = GetUnreadEmails()
	
	if not labelId then
		return #emails > 0
	else
		if labelId == "Unread" or labelId == "AllMessages" then
			return #emails > 0
		else
			for i, email in ipairs(emails) do
				local preset = Emails[email.id]
				if preset and preset.label == labelId then
					return true
				end
			end
		end
		
		return false
	end
end

---
--- Receives an email and processes it based on the email's preset and the current game state.
---
--- @param emailId string The ID of the email to receive.
--- @param context table An optional table containing additional context information for the email.
---
function ReceiveEmail(emailId, context)
	local preset = Emails[emailId]
	if not preset or not preset:IsRelatedToCurrentCampaign() then return end
	if g_Combat and preset.delayAfterCombat then
		gv_DelayedEmails[#gv_DelayedEmails+1] = { emailId = emailId, context = context }
		gv_DelayedEmails[emailId] = true
	else
		if not gv_ReceivedEmails[preset.id] or preset.repeatable then
			gv_ReceivedEmails[#gv_ReceivedEmails+1] = {
				id = emailId,
				read = false,
				time = Game.CampaignTime,
				uniqueId = #gv_ReceivedEmails+1,
				context = context
			}
			gv_ReceivedEmails[emailId] = true
			ObjModified(gv_ReceivedEmails)
			EmailNotficationPopup()
		end
	end
end

local nolog = { no_log = true }

---
--- Checks the send conditions for the given email preset and receives the email if the conditions are met.
---
--- @param emailId string The ID of the email to receive.
--- @param context table An optional table containing additional context information for the email.
---
function CheckConditionsAndReceiveEmail(emailId, context)
	local preset = Emails[emailId]
	local check = preset.sendConditions and #preset.sendConditions > 0 and EvalConditionList(preset.sendConditions, preset, nolog)
	if check then
		ReceiveEmail(emailId, context)
	end
end

---
--- Evaluates the send conditions for all email presets in the current campaign and receives any emails whose conditions are met.
---
--- This function is called periodically to check for new emails that should be received.
---
--- @param none
--- @return none
---
function EmailsSendConditionEvaluation()
	local emailPresets = PresetsInCampaignArray("Email")
	local n = #emailPresets
	for i, preset in ipairs(emailPresets) do
		if not gv_ReceivedEmails[preset.id] and not gv_DelayedEmails[preset.id] and preset.sendConditions and #preset.sendConditions > 0 and EvalConditionList(preset.sendConditions, preset, nolog) then
			Sleep(const.EmailWaitTime)
			ReceiveEmail(preset.id)
		end
		
		Sleep((i+1)*1000/n - i*1000/n)
	end
end

-- Send delayed emails
function OnMsg.CombatEnd()
	for i, delayed in ipairs(gv_DelayedEmails) do
		ReceiveEmail(delayed.emailId, delayed.context)
	end
	gv_DelayedEmails = {} 
end

---
--- Periodically evaluates the send conditions for all email presets in the current campaign and receives any emails whose conditions are met.
---
--- This function is called repeatedly at an interval of 1000 milliseconds to check for new emails that should be received.
---
--- @param none
--- @return none
---
MapGameTimeRepeat("EmailsSendConditionEvaluation", 1000, function()
	if mapdata.GameLogic and HasGameSession() and not IsSetpiecePlaying() then
		EmailsSendConditionEvaluation()
	end	
end)

local function lEmailNotificationPopup(emailNotification) 
	emailNotification:DeleteThread("emailNotification")
	emailNotification:CreateThread("emailNotification", function()
		PlayFX("EmailReceived", "start")
		ObjModified("email-notification")
		emailNotification:SetVisible(true)
		Sleep(12000)
		emailNotification:SetVisible(false) -- has FadeOutTime
	end)
end

---
--- Displays an email notification popup when an email is received.
---
--- This function is called from a real-time thread to ensure it is executed even when a setpiece is playing.
---
--- The function first waits for any active setpiece to end, then creates an email notification popup on the satellite UI and the in-game interface dialog.
---
--- @param none
--- @return none
---
function EmailNotficationPopup()
	CreateMapRealTimeThread(function()
		while IsSetpiecePlaying() do
			WaitMsg("SetpieceEnded", 100)
		end
		Sleep(1000)
		local emailNotificationSat = g_SatelliteUI and g_SatelliteUI:ResolveId("idEmailNotification")
		if emailNotificationSat then lEmailNotificationPopup(emailNotificationSat) end
		local igi = GetInGameInterfaceModeDlg()
		local emailNotificationTac = igi and igi:ResolveId("idEmailNotification")
		if emailNotificationTac then lEmailNotificationPopup(emailNotificationTac) end
	end)
end

---
--- Formats the email date as a string in the format "month-day-year".
---
--- @param email table The email object containing the time field.
--- @return string The formatted email date string.
---
function TFormat.EmailDate(email)
	local time = email.time
	return T{768723019691, "<month(time)>-<day(time)>-<year(time)>", time = time}
end

---
--- Formats the email time as a string.
---
--- @param email table The email object containing the time field.
--- @return string The formatted email time string.
---
function TFormat.EmailTime(email)
	local time = email.time
	return T{666424524008, "<time(time)>", time = time}
end

---
--- Retrieves a received email by its unique identifier.
---
--- @param id string|number The unique identifier of the email to retrieve.
--- @return table|nil The email object if found, or nil if not found.
---
function GetReceivedEmail(id)
	local toCheck = type(id) == "string" and "id" or "uniqueId"
	for i, email in ipairs(GetReceivedEmails()) do
		if email[toCheck] == id then
			return email
		end
	end
	return empty_table
end

---
--- Marks an email as read by its unique identifier.
---
--- @param uniqueId string|number The unique identifier of the email to mark as read.
---
function ReadEmail(uniqueId)
	NetSyncEvent("MarkEmailAsRead", uniqueId, true)
end

-- for debug
---
--- Sets all received emails to unread.
---
function UnreadEmails()
	for i, email in ipairs(GetReceivedEmails()) do
		email.read = false
	end
end

DefineClass.PDAEmailsClass = {
	__parents = { "XDialog" },
	
	selectedLabelId = false,
	selectedEmail = false
}

---
--- Opens the PDA emails dialog and selects the appropriate email to display.
---
--- If the `openSpecificOrNewestEmail` context is set to "openNewest", the newest received email will be selected.
--- If the `openSpecificOrNewestEmail` context is set to a specific email, that email will be selected if it exists in the received emails list.
--- Otherwise, the "AllMessages" label will be selected, and no email will be selected.
---
--- @param self PDAEmailsClass The instance of the PDAEmailsClass.
---
function PDAEmailsClass:Open()
	self:SelectLabel("AllMessages")
	
	local openSpecific = GetDialog("PDADialog").context.openSpecificOrNewestEmail
	if openSpecific == "openNewest" then
		self:SelectEmail(gv_ReceivedEmails[#gv_ReceivedEmails])
		GetDialog("PDADialog").context.openSpecificOrNewestEmail = false
	elseif openSpecific then
		-- we could open a non-existing e-mail, if its formatting is correct (the contents would be displayed, but no e-mail selected), but safer this way
		-- we can also open newest e-mail if the one received does not exist?
		local email_exists = table.find(gv_ReceivedEmails, openSpecific)
		if email_exists then
			self:SelectEmail(openSpecific)
		end
		GetDialog("PDADialog").context.openSpecificOrNewestEmail = false
	end

	XDialog.Open(self)
end

---
--- Selects the specified label and updates the email rows and highlighted labels accordingly.
---
--- @param self PDAEmailsClass The instance of the PDAEmailsClass.
--- @param id string The ID of the label to select.
---
function PDAEmailsClass:SelectLabel(id)
	self.selectedLabelId = id
	self.selectedEmail = false
	local emailRows = self:ResolveId("idEmailRows")
	emailRows:SetContext(SubContext(GetReceivedEmailsWithLabel(id), {id}))
	emailRows:SetSelection(false)
	
	self:HighlightLabels()
end

---
--- Highlights the selected label in the label list.
---
--- This function is responsible for updating the visual appearance of the label buttons in the label list to indicate which label is currently selected.
---
--- @param self PDAEmailsClass The instance of the PDAEmailsClass.
---
function PDAEmailsClass:HighlightLabels()
	local labelList = self:ResolveId("idLabelList")
	for i, label in ipairs(labelList) do
		local button = label:ResolveId("idButton")
		if label.context.id == self.selectedLabelId then
			button:SetToggled(true)
			button:SetTextStyle("PDAQuests_LabelInversed")
		else
			button:SetToggled(false)
			button:SetTextStyle("PDAQuests_Label")
		end
	end
end

---
--- Marks an email as read or unread.
---
--- This function is responsible for updating the read status of a received email and notifying the relevant UI elements of the change.
---
--- @param uniqueId string The unique identifier of the email to mark as read or unread.
--- @param val boolean The new read status of the email (true for read, false for unread).
---
function NetSyncEvents.MarkEmailAsRead(uniqueId, val)
	local mail = GetReceivedEmail(uniqueId)
	if mail == empty_table then return end
	local preset = Emails[mail.id]
	mail.read = val
	ObjModified(gv_ReceivedEmails)
	ObjModified(EmailLabels.Unread)
	ObjModified(EmailLabels[preset.label])
	ObjModified(mail)
end

---
--- Triggers the UnreadEmails function.
---
--- This function is responsible for updating the UI to display the number of unread emails.
---
function NetSyncEvents.UnreadEmails()
	UnreadEmails()
end

---
--- Selects an email and updates the UI to display its contents.
---
--- This function is responsible for updating the UI to display the selected email's header, attachments, and body. It also marks the email as read and ensures the selected email is highlighted in the email list.
---
--- @param receivedEmail table The received email to select and display.
---
function PDAEmailsClass:SelectEmail(receivedEmail)
	if self.selectedEmail == receivedEmail then return end

	if receivedEmail then
		NetSyncEvent("MarkEmailAsRead", receivedEmail.uniqueId, true)
	else
		ObjModified(gv_ReceivedEmails)
	end
	self.selectedEmail = receivedEmail
	
	local emailPreset = receivedEmail and Emails[receivedEmail.id]
	
	local emailHeader = self:ResolveId("idEmailHeader")
	emailHeader:SetContext(receivedEmail)
	
	local emailAttachments = self:ResolveId("idAttachments")
	emailAttachments:SetContext(receivedEmail and emailPreset.attachments)
	
	local emailBody = self:ResolveId("idEmailBody")
	emailBody:SetContext(receivedEmail)
	emailBody:ScrollTo(0, 0)
	
	for k, v in pairs(EmailLabels) do
		ObjModified(v)
	end
	self:HighlightLabels()
	
	-- Make sure it is selected in the list
	local emailRows = self:ResolveId("idEmailRows")
	local selectedEmailIndex = table.find(self:ResolveId("idEmailRows"), "context", receivedEmail)
	if selectedEmailIndex then
		emailRows:SetFocus(true)
		emailRows:SetSelection(selectedEmailIndex)
	else
		emailRows:SetFocus(false)
		emailRows:SetSelection(false)
	end
end

---
--- Opens an email attachment window for the currently selected email.
---
--- This function is responsible for spawning and opening a new window to display the attachment for the currently selected email. It retrieves the attachment information from the selected email and passes it to the new window.
---
--- @param attachment table The attachment information for the currently selected email.
---
function PDAEmailsClass:OpenEmailAttachment(attachment)
	if not self.selectedEmail then return end
	local attachmentWindow = XTemplateSpawn("PDAQuestsEmailAttachment", self, attachment)
	attachmentWindow:Open()
end

---
--- Opens an email in the PDA dialog.
---
--- This function is responsible for opening the email tab in the PDA dialog and displaying the specified email. It handles various scenarios, such as closing the full-screen game dialog, opening the PDA dialog if it's not already open, and switching to the email tab if the PDA dialog is already open but on a different tab.
---
--- @param emailOrNewest table|nil The email to open, or nil to open the newest email.
---
function OpenEmail(emailOrNewest)
	local full_screen = GetDialog("FullscreenGameDialogs")
	if full_screen and full_screen.window_state == "open" then
		full_screen:Close()
	end

	local dlg = GetDialog("PDADialog")
	
	-- Not currently in the PDA or quests tab.
	if not dlg or dlg.Mode ~= "quests" then
		OpenDialog("PDADialog", GetInGameInterface(), { Mode = "quests", sub_tab = "email", openSpecificOrNewestEmail = emailOrNewest })
		return
	end
	
	-- Change tab to email if on another tab
	local notesDlg = dlg.idContent.idSubContent
	if notesDlg.Mode ~= "email" then
		notesDlg:SetMode("email", { openSpecificOrNewestEmail = emailOrNewest })
		return
	end
	
	-- Already open. Close it.
	dlg:CloseAction()
end

---
--- Rebuilds the unique IDs for all received emails in the savegame session data.
---
--- This function iterates through the list of received emails in the savegame session data and assigns a unique ID to each email, starting from 1 and incrementing for each email.
---
--- @param data table The savegame session data.
---
function SavegameSessionDataFixups.RebuildEmailUniqueIds2(data)
	local emails = GetGameVarFromSession(data, "gv_ReceivedEmails")
	for i, email in ipairs(emails) do
		email.uniqueId = i
	end
end
