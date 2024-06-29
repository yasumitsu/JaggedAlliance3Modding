local si_print = CreatePrint{
	Platform.xbox and "signin",
}

if FirstLoad then
	ActiveController = false
	SignInSuspendReasons = {}
end

local next = next
---
--- Checks if sign-in is allowed.
---
--- @return boolean true if sign-in is allowed, false otherwise
function CanSignIn()
	return next(SignInSuspendReasons) == nil
end

---
--- Suspends sign-in checks for the given reason.
---
--- @param reason string|boolean The reason for suspending sign-in checks, or false if no specific reason.
---
function SuspendSigninChecks(reason)
	SignInSuspendReasons[reason or false] = true
end

---
--- Resumes sign-in checks for the given reason.
---
--- @param reason string|boolean The reason for resuming sign-in checks, or false if no specific reason.
---
function ResumeSigninChecks(reason)
	SignInSuspendReasons[reason or false] = nil
	if CanSignIn() then
		RecheckSigninState()
	end
end

---
--- Activates the specified XInput controller.
---
--- @param controller_id string The ID of the controller to activate.
---
function XPlayerActivate(controller_id)
	if not controller_id then return end
	XInput.ControllerEnable("all", false)
	XInput.ControllerEnable(controller_id, true)
	ActiveController = controller_id
	Msg("ActiveControllerUpdated")
end

function RecheckSigninState() end -- pc stub


---
--- Called when the sign-in state changes.
--- This function resets the XPlayers, changes the game state, opens and closes a loading screen, and resets the title state.
---
--- @function OnSigninChange
--- @return nil
function OnSigninChange()
	print("Signin changed!")
	XPlayersReset("force")
	
	--_PrintXPlayers()
	CreateRealTimeThread(function() -- Called from Msg (pcall), must start another thread.
		ChangeGameState("signin_change", true)
		LoadingScreenOpen("idLoadingScreen", "signin change")
		ResetTitleState()
		LoadingScreenClose("idLoadingScreen", "signin change")
		ChangeGameState("signin_change", false)
	end)
end
