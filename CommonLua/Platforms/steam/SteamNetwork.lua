if FirstLoad then
	threadSteamGetAppTicket = false
end

config.NetCheckUpdates = false

--- Returns the name of the authentication provider.
---
--- This function returns the name of the authentication provider, which is "steam" in this case.
---
--- @return string The name of the authentication provider.
function ProviderName()
	return "steam"
end

--- Returns the authentication provider information for the current Steam user.
---
--- This function checks if the current user is logged in to Steam, and if so, retrieves the user's display name and an authentication token (app ticket) from Steam. It returns the authentication provider name, the authentication data, and the user's display name.
---
--- @param official_connection boolean Whether this is an official connection (e.g. from the main game client)
--- @return string|nil, string, string|nil, string|nil The error message (if any), the authentication provider name, the authentication data, and the user's display name
function PlatformGetProviderLogin(official_connection)
	local err, auth_provider, auth_provider_data, display_name
	
	if not IsSteamLoggedIn() then
		DebugPrint("IsSteamLoggedIn() failed\n")
		return "steam-auth"
	end

	auth_provider = "steam"
	display_name = SteamGetPersonaName()
	if not display_name then
		DebugPrint("SteamGetPersonaName() failed\n")
		return "steam-auth"
	end
	while threadSteamGetAppTicket do -- wait any other calls to AsyncSteamGetAppTicket
		Sleep(10)
	end
	threadSteamGetAppTicket = CurrentThread() or true
	err, auth_provider_data = AsyncSteamGetAppTicket(tostring(display_name))
	assert(threadSteamGetAppTicket == (CurrentThread() or true))
	threadSteamGetAppTicket = false

	if err then 
		DebugPrint("AsyncSteamGetAppTicket() failed: " .. err .. "\n")
		return "steam-auth" 
	end
	
	return err, auth_provider, auth_provider_data, display_name
end