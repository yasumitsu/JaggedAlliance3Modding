local LegaleseText = ""

local function PlayInitialLoadingScreen(fadeInTime, fadeOutTime, time)
	local dlg = XTemplateSpawn("SplashScreenLoading", terminal.desktop,
							{ text = LegaleseText, FadeInTime = fadeInTime, FadeOutTime = fadeOutTime, Time = time})
	dlg:Open()
	return dlg
end

--- Plays the initial movies and loading screen for the splash screen.
---
--- This function is responsible for displaying the initial logos and loading screen
--- when the game is first launched. It plays the THQN and HM logos in sequence,
--- followed by a loading screen.
---
--- @param fadeInTime number The fade-in time for the loading screen, in milliseconds.
--- @param fadeOutTime number The fade-out time for the loading screen, in milliseconds.
--- @param time number The duration of the loading screen, in milliseconds.
--- @return table The dialog object representing the loading screen.
function PlayInitialMovies()
	SplashImage("UI/Logos/SplashScreen_Logo_THQN", 800, 800, 3000):Wait()
	SplashImage("UI/Logos/SplashScreen_Logo_HM", 800, 800, 3000):Wait()
	
	PlayInitialLoadingScreen(0, 0, 0):Wait()
end