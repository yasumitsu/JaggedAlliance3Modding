-- Large Data Transfers (Hogs)
-- There is one hog per socket which is progressivelly transfered. Starting another transfer operation cancels the previous one.
-- Other rfn can be called while the hog is being transfered.
-- The transfer is initiated with SendHog(hog) and cancelled with SendHogCancel().
-- The send status can be checked with SendHogStatus() which returns hog, confirmed_transfer.
-- The status of the receive hog is obtained with ReceiveHogStatus() which returns hog, total_hog_size. Note that during the transfer
-- the hog returned is a table whith the hog chunks. hog.size contains the total length of the received chunks
-- Since the size of these hogs can be excessive, SendHogCancel is called immediatelly after the send callback.
-- Therefore only rfn calls made in the callback can rely on the hog being present and complete on the receiving end.
-- Note that calling SendHogCancel clears the remote hog as well.

HogChunksInAdvance = 4
HogChunkSize = 32 * 1024
HogChunkTimeout = 10000 -- chunk confirm timeout 

DefineClass.DataSocket = {
	__parents = { "MessageSocket" },

	hog_download = false,
	hog_download_total = -1,
	hog_download_signal = false,
	hog_download_data = false,
	hog_download_thread = false,
	hog_download_timeout = false,
	hog_download_monitor = false,
	
	hog_upload = false,
	hog_upload_confirmed = -1,
	hog_upload_callback = false,
	hog_upload_signal = false,
	hog_upload_thread = false,
	hog_upload_data = false,
	hog_upload_timeout = false,
	hog_upload_monitor = false,
}

---
--- Constructs a new `DataSocket` object, which is a subclass of `MessageSocket`.
--- The `DataSocket` object has additional properties for managing large data transfers ("hogs").
---
--- @param object table The object to initialize as a `DataSocket`.
--- @return table The initialized `DataSocket` object.
---
function DataSocket:new(object)
	object = MessageSocket.new(self, object)
	
	object.hog_download_signal = {}
	object.hog_upload_signal = {}
	
	return object
end

---
--- Sends a large data "hog" over the network connection.
---
--- @param hog string The data to send as a "hog".
--- @param sent_callback function|boolean Optional callback function to call when the hog has been sent successfully.
--- @return boolean True if the hog send was started successfully, false otherwise.
---
function DataSocket:SendHog(hog, sent_callback)
	if self.hog_upload then
		assert(false, "Hog sending still in progress!")
		return
	end
	if type(hog) ~= "string" then
		assert(false, "Trying to send a hog of type " .. type(hog))
		return
	end
	self:Log("Uploading hog size", #hog)
	self.hog_upload = hog
	self.hog_upload_confirmed = 0
	self.hog_upload_callback = sent_callback or false
	self:Send("rfnHogStart", #hog)
	for i = 0, HogChunksInAdvance - 1 do
		if i * HogChunkSize <= #hog then
			self:Send("rfnHogData", string.sub(hog, 1 + i * HogChunkSize, (i + 1) * HogChunkSize))
		end
	end
	
	DeleteThread(self.hog_upload_monitor)
	self.hog_upload_monitor = CreateRealTimeThread(function()
		self.hog_upload_timeout = RealTime() + HogChunkTimeout
		while self.hog_upload do
			local timout_after = self.hog_upload_timeout - RealTime()
			if timout_after <= 0 then
				self:StopUpload("timeout")
				break
			end
			Sleep(timout_after)
		end
	end)
	return true
end

---
--- Cancels the upload of a large data "hog" over the network connection.
---
--- @param dont_notify boolean Optional flag to prevent sending a notification to the other side.
---
function DataSocket:SendHogCancel(dont_notify)
	if self.hog_upload then
		self:Log("Hog upload stopped")
		self.hog_upload = false
		self.hog_upload_confirmed = -1
		self.hog_upload_callback = false
		if not dont_notify then
			self:Send("rfnSendHogCancel")
		end
	end
end

---
--- Cancels the download of a large data "hog" over the network connection.
---
--- @param dont_notify boolean Optional flag to prevent sending a notification to the other side.
---
function DataSocket:ReceiveHogCancel(dont_notify)
	if self.hog_download then
		self:Log("Hog download stopped")
		self.hog_download = false
		self.hog_download_total = -1
		if not dont_notify then
			self:Send("rfnReceiveHogCancel")
		end
	end
end

---
--- Returns the current status of the "hog" upload.
---
--- @return boolean hog_upload The current state of the "hog" upload.
--- @return number hog_upload_confirmed The number of bytes confirmed to have been uploaded.
---
function DataSocket:SendHogStatus()
	return self.hog_upload, self.hog_upload_confirmed
end

---
--- Returns the current status of the "hog" download.
---
--- @return boolean hog_download The current state of the "hog" download.
--- @return number hog_download_total The total size of the "hog" download in bytes.
---
function DataSocket:ReceiveHogStatus()
	return self.hog_download, self.hog_download_total
end

---
--- Confirms the receipt of a chunk of data for a "hog" upload.
---
--- @param size number The total number of bytes confirmed to have been uploaded.
---
function DataSocket:rfnHogConfirm(size)
	if not self.hog_upload then
		return
	end
	self.hog_upload_timeout = RealTime() + HogChunkTimeout
	assert(self.hog_upload_confirmed + HogChunkSize == size or #self.hog_upload == size)
	local delta = HogChunkSize * HogChunksInAdvance
	if self.hog_upload_confirmed + delta < #self.hog_upload then
		self:Send("rfnHogData", string.sub(self.hog_upload, 1 + self.hog_upload_confirmed + delta, size + delta))
	end
	self.hog_upload_confirmed = size
	if self.hog_upload_confirmed == #self.hog_upload then
		if self.hog_upload_callback then
			self.hog_upload_callback(self, self)
		end
		self:SendHogCancel()
	end
end

---
--- Starts a "hog" download with the specified size.
---
--- @param size number The total size of the "hog" download in bytes.
---
function DataSocket:rfnHogStart(size)
	self:Log("Hog download started", size)
	self.hog_download = { size = 0 }
	self.hog_download_total = size
	
	DeleteThread(self.hog_download_monitor)
	self.hog_download_monitor = CreateRealTimeThread(function()
		self.hog_download_timeout = RealTime() + HogChunkTimeout
		while self.hog_download do
			local timout_after = self.hog_download_timeout - RealTime()
			if timout_after <= 0 then
				self:StopDownload("timeout")
				break
			end
			Sleep(timout_after)
		end
	end)
end

---
--- Receives a chunk of data for a "hog" download and processes it.
---
--- @param data string The chunk of data received.
---
function DataSocket:rfnHogData(data)
	local hog = self.hog_download
	if type(hog) ~= "table" then
		return
	end
	self.hog_download_timeout = RealTime() + HogChunkTimeout
	hog[#hog + 1] = data
	hog.size = hog.size + #data
	self:Send("rfnHogConfirm", hog.size)
	if hog.size == self.hog_download_total then
		self.hog_download = table.concat(hog)
		assert(#self.hog_download == self.hog_download_total)
	end
end

---
--- Cancels a "hog" download that is currently in progress.
---
function DataSocket:rfnSendHogCancel()
	self:StopDownload("cancelled")
end

---
--- Cancels a "hog" upload that is currently in progress.
---
function DataSocket:rfnReceiveHogCancel()
	self:StopUpload("cancelled")
end

-- HOG UPLOAD HELPERS ------------------------------------------------------------------------

---
--- Waits for an upload to complete and returns the result.
---
--- @param data string The data to be uploaded.
--- @param upload_server_handler string The name of the server-side handler for the upload.
--- @param ... any Additional parameters to pass to the server-side handler.
--- @return string|any The result of the upload, or an error message if the upload failed.
---
function DataSocket:WaitUpload(data, upload_server_handler, ...)
	if not self:IsConnected() then
		return "disconnected"
	end
	if IsValidThread(self.hog_upload_thread) then
		assert(false, "another upload in progress!")
		return "busy"
	end
	self.hog_upload_data = false
	self.hog_upload_thread = CurrentThread()
	local handler_params = pack_params(...)
	local started = self:SendHog(data, function()
		self:Send("rfnHogUploadEnd", upload_server_handler, unpack_params(handler_params))
	end)
	if not started then
		assert(false, "Upload not started!")
		return "failed"
	end
	local ok, local_error = WaitMsg(self.hog_upload_signal)
	local upload_result = self.hog_upload_data
	self.hog_upload_data = false
	self.hog_upload_thread = false
	if not upload_result then
		return local_error or "failed"
	end
	return unpack_params(upload_result)
end

---
--- Handles the completion of a "hog" upload.
---
--- @param ... any Additional parameters returned from the server-side upload handler.
---
function DataSocket:rfnHogUploadEnd(...)
	self.hog_upload_data = pack_params(...) or {}
	self:StopUpload()
end

---
--- Stops an ongoing upload and signals the upload thread to stop.
---
--- @param error any An error message to pass to the upload thread, or `false` if the upload was successful.
---
function DataSocket:StopUpload(error)
	self:SendHogCancel(not error)
	Msg(self.hog_upload_signal, error)
end

---
--- Returns the progress of an ongoing upload as a percentage.
---
--- @return number The upload progress as a percentage.
---
function DataSocket:UploadProgress()
	local data, progress = self:SendHogStatus()
	if data or IsValidThread(self.hog_upload_thread) then
		return data and progress * 100 / #data or 100 or 0
	end
end

-- HOG DOWNLOAD HELPERS ------------------------------------------------------------------------

---
--- Waits for a download to complete and returns the downloaded data.
---
--- @param download_server_handler function The server-side handler function for the download.
--- @param ... any Additional parameters to pass to the download handler.
--- @return string|table The downloaded data, or an error message if the download failed.
---
function DataSocket:WaitDownload(download_server_handler, ...)
	if not self:IsConnected() then
		return "disconnected"
	end
	if IsValidThread(self.hog_download_thread) then
		assert(false, "another download in progress!")
		return "busy"
	end
	self.hog_download_thread = CurrentThread()
	self.hog_download_data = false
	local error = self:Call("rfnHogDownloadStart", download_server_handler, ...)
	if error then
		return error
	end
	local ok, error = WaitMsg(self.hog_download_signal)
	local data = self.hog_download_data
	self.hog_download_data = false
	self.hog_download_thread = false
	if not data then
		return error or "failed"
	end
	return unpack_params(data)
end

---
--- Returns the progress of an ongoing download as a percentage.
---
--- @return number The download progress as a percentage.
---
function DataSocket:DownloadProgress()
	local data, total = self:ReceiveHogStatus()
	if data or IsValidThread(self.hog_download_thread) then
		return type(data) == "table" and data.size * 100 / total or type(data) == "string" and 100 or 0
	end
end

---
--- Stops an ongoing download and signals the download completion.
---
--- @param error string|nil An optional error message to signal the download failure.
---
function DataSocket:StopDownload(error)
	self:ReceiveHogCancel(not error)
	Msg(self.hog_download_signal, error)
end

--- Handles the completion of a download initiated by `DataSocket:WaitDownload()`.
---
--- This function is called internally by the `DataSocket` class when a download operation completes.
--- It verifies that the downloaded data matches the expected size, stores the data in the `hog_download_data`
--- field, and stops the download by calling `DataSocket:StopDownload()`.
---
--- @param self DataSocket The `DataSocket` instance that initiated the download.
function DataSocket:rfnHogDownloadEnd()
	local data, size = self:ReceiveHogStatus()
	assert(data and #data == size)
	self.hog_download_data = data
	self:StopDownload()
end

---
--- Handles the disconnection of the DataSocket.
---
--- This function is called when the DataSocket is disconnected. It stops any ongoing upload or download
--- operations and then calls the parent `MessageSocket:OnDisconnect()` function.
---
--- @param self DataSocket The DataSocket instance.
--- @param reason string The reason for the disconnection.
---
function DataSocket:OnDisconnect(reason)
	self:StopUpload("disconnected")
	self:StopDownload("disconnected")
	MessageSocket.OnDisconnect(self, reason)
end