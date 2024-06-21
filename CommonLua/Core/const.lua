--- Initializes the `const` table with the `const.` prefix.
---
--- This code is executed only on the first load of the script. It sets up the `const` table
--- with a metatable that tracks reads and writes to the constants, and ensures that constants
--- are not read before they are defined.
---
--- @function SetupVarTable
--- @param const table The `const` table to initialize.
--- @param prefix string The prefix to use for the `const` table.
if FirstLoad then
    SetupVarTable(const, "const.")
end

----- track const use before definition
--[[
const_read = {}
AllowConstRead = true
function OnMsg.ReloadLua()
	AllowConstRead = false
end
if FirstLoad then
	local function get_caller_info()
		local info = debug.getinfo(3, "Sl")
		if info.short_src == "CommonLua/Core/ConstDef.lua" then -- DefineConst function
			info = debug.getinfo(4, "Sl")
		end
		return string.format("%s(%d)", info.short_src or "???", info.currentline or 0)
	end
	local function const_eq(c1, c2)
		if type(c2) ~= "table" then
			return c1 == c2
		end
		local s1, s2 = pstr("", 1024), pstr("", 1024)
		s1:appendv(c1)
		s2:appendv(c2)
		return s1 == s2 or s1 == "nil" and s2 == "{}"
	end

	local org_const = const
	local engine_const = { SlabSizeX = true, SlabSizeY = true, SlabSizeZ = true }
	const = setmetatable({}, {
		__index = function (_, key)
			const_read[key] = get_caller_info()
			if not AllowConstRead and not engine_const[key] then
				print("Const read before consts are ready", const_read[key])
			end
			return org_const[key]
		end,
		__newindex = function (_, key, value)
			if const_read[key] then
				local info = get_caller_info()
				if const_read[key] == info then
					-- print("Read-write of const", key, info)
					const_read[key] = nil -- remove the read, this was a read-write (default value)
				elseif not const_eq(org_const[key], value) then
					print("const", key, "last used at", const_read[key], "changed at", info)
				end
			end
			org_const[key] = value
		end
	})
end
--]]

--- The default fallback size for various UI elements.
const.FallbackSize = 64

--- Checks if the application is running in command-line mode.
-- If the application is running in command-line mode, this function will return and skip the rest of the code.
-- @return true if the application is running in command-line mode, false otherwise.
if Platform.cmdline then
    return
end

--- Defines a set of common scale factors used throughout the codebase.
-- The scale factors are defined as follows:
-- - `m`: Meters, the base unit of length.
-- - `cm`: Centimeters, 1/100th of a meter.
-- - `voxelSizeX`: The size of a voxel in the X dimension.
-- - `deg`: Degrees, a unit of angle measurement.
-- - `sec`: Seconds, a unit of time measurement.
-- - `%`: Percentage, a unit of relative measurement.
-- - `‰`: Per mille, a unit of relative measurement.
const.Scale = {m=guim, cm=guic, voxelSizeX=const.SlabSizeX, deg=60, sec=1000, ["%"]=1, ["‰"]=1}

--- The maximum index value for game objects in a collection.
-- This constant represents the maximum index value that can be used to reference a game object in a collection.
-- It is defined as 0x0fff, which is a hexadecimal value of 4095 in decimal.
-- This limit is likely in place to ensure efficient indexing and storage of game objects in collections.
const.GameObjectMaxCollectionIndex = 0x0fff
--- The maximum radius for game objects in the game world.
-- This constant represents the maximum radius that a game object can have in the game world.
-- It is defined as 60 meters, which is a common unit of measurement used in the game.
-- This limit is likely in place to ensure efficient collision detection and other game mechanics that rely on the size of game objects.
const.GameObjectMaxRadius = 60 * guim

--- The default mouse cursor image to use.
-- This constant specifies the file path to the default mouse cursor image that should be used in the application.
-- The cursor image is located at "CommonAssets/UI/cursor.tga".
const.DefaultMouseCursor = "CommonAssets/UI/cursor.tga"

--- Defines a set of common RGB color constants used throughout the codebase.
-- @field red The color red, represented as an RGB value of (255, 0, 0).
-- @field green The color green, represented as an RGB value of (0, 255, 0).
-- @field blue The color blue, represented as an RGB value of (0, 0, 255).
-- @field black The color black, represented as an RGB value of (0, 0, 0).
-- @field white The color white, represented as an RGB value of (255, 255, 255).
-- @field yellow The color yellow, represented as an RGB value of (255, 255, 0).
-- @field purple The color purple, represented as an RGB value of (128, 0, 128).
-- @field magenta The color magenta, represented as an RGB value of (255, 0, 255).
-- @field orange The color orange, represented as an RGB value of (255, 165, 0).
-- @field cyan The color cyan, represented as an RGB value of (0, 255, 255).
red = RGB(255, 0, 0)
green = RGB(0, 255, 0)
blue = RGB(0, 0, 255)
black = RGB(0, 0, 0)
white = RGB(255, 255, 255)
yellow = RGB(255, 255, 0)
purple = RGB(128, 0, 128)
magenta = RGB(255, 0, 255)
orange = RGB(255, 165, 0)
cyan = RGB(0, 255, 255)

--- Defines a table of colors to be used for hyperlinks.
-- This table is currently empty, but can be used to store color values for hyperlinks throughout the codebase.
const.HyperlinkColors = {}

--- Defines a table of predefined scene actors.
-- This table is currently empty, but can be used to store references to predefined scene actors that can be used throughout the codebase.
const.PredefinedSceneActors = {}

--- The default sharpness value used for the camera editor.
-- This constant specifies the default sharpness value that should be used for the camera editor feature.
-- The sharpness value affects the visual clarity and focus of the camera view in the editor.
-- This default value of 10 can be overridden by the user or other parts of the codebase as needed.
const.CameraEditorDefaultSharpness = 10

--- The duration in milliseconds for interface animations.
-- This constant specifies the default duration in milliseconds for interface animations throughout the application.
-- This value can be used to ensure consistent animation timing across different UI elements and interactions.
const.InterfaceAnimDuration = 100

-- cutscene light model overrides
--- The near Z-plane value used for cutscene cameras.
-- This constant specifies the near Z-plane value that should be used for cutscene cameras in the application.
-- The near Z-plane value determines the minimum distance from the camera that objects will be rendered.
-- Setting this value to 20 ensures that objects close to the camera are properly rendered during cutscenes.
const.CutsceneNearZ = 20

-- Camera Shake System
--- Defines constants related to camera shake behavior in the application.
--
-- @field CameraClipExtendRadius The radius around the camera that should be used to extend the camera clip plane when the camera is shaking.
-- @field CameraShakeFOV The field of view angle (in degrees) that should be used for the camera when it is shaking.
-- @field ShakeRadiusInSight The maximum distance from the camera shake origin that the camera will shake if the origin is visible (in front of the camera).
-- @field ShakeRadiusOutOfSight The maximum distance from the camera shake origin that the camera will shake if the origin is not visible (behind the camera).
-- @field MaxShakeOffset The maximum offset (in units) that the camera can be shaken.
-- @field MaxShakeRoll The maximum roll (in degrees) that the camera can be shaken.
-- @field MaxShakeDuration The maximum duration (in milliseconds) of the camera shake effect at maximum power.
-- @field MinShakeDuration The minimum duration (in milliseconds) of the camera shake effect at minimum power.
-- @field ShakeTick The frequency (in milliseconds) at which the camera shake waves are updated.
-- @field MaxShakePower The maximum power of the camera shake effect.
const.CameraClipExtendRadius = 20 * guic
const.CameraShakeFOV = 120 * 60
const.ShakeRadiusInSight = 30 * guim -- the max dist the camera would shake if the shake origin is visible(in front of camera)
const.ShakeRadiusOutOfSight = 10 * guim -- the max dist the camera would shake if the shake origin is not visible(behind the camera)
const.MaxShakeOffset = 3 * guic -- the shake offset at max power
const.MaxShakeRoll = 15 -- the shake roll at max power
const.MaxShakeDuration = 700 -- the duration of the shake effect at max power
const.MinShakeDuration = 300 -- the duration of the shake effect at min power
const.ShakeTick = 25 -- the frequency of the shake waves, in ms
const.MaxShakePower = 1000

--- The radius (in meters) around particle handles that should be toggled when the particle handles are toggled on or off.
-- This constant is used to determine the area of effect for the particle handle toggle functionality.
const.ParticleHandlesToggleRadius = 10
const.ParticleHandlesToggleRadius = 10 -- in meters

--- The distance (in meters) from the near plane that the animation moments tool object should be positioned.
-- This constant is used to ensure that the animation moments tool object is positioned at the appropriate distance from the camera's near plane, providing a clear view of the object during animation editing.
const.AnimMomentsToolObjDistToNearPlane = 8
const.AnimMomentsToolObjDistToNearPlane = 8 -- in meters

--- The default time factor used for time-based calculations and animations throughout the application.
-- This constant specifies the default time factor, which is used to scale the passage of time for various time-based operations. A value of 1000 means that 1 second of real-time corresponds to 1000 milliseconds of game time.
--
-- @field DefaultTimeFactor The default time factor value.
--
--- The minimum allowed time factor value.
-- This constant specifies the minimum value that the time factor can be set to. This helps prevent the game from running too slowly or becoming unresponsive.
--
-- @field MinTimeFactor The minimum allowed time factor value.
--
--- The maximum allowed time factor value.
-- This constant specifies the maximum value that the time factor can be set to. This helps prevent the game from running too quickly and becoming uncontrollable.
--
-- @field MaxTimeFactor The maximum allowed time factor value.
--
--- The maximum "sane" time factor value.
-- This constant specifies the maximum time factor value that is considered "sane" or reasonable for normal gameplay. Values higher than this may cause issues or unintended behavior.
--
-- @field MaxSaneTimeFactor The maximum "sane" time factor value.
const.DefaultTimeFactor = 1000
const.MinTimeFactor = 10
const.MaxTimeFactor = 1000000
const.MaxSaneTimeFactor = 100000

-- in ms * 0.001
--- The time interval (in seconds) at which the camera controller state is updated.
-- This constant specifies the frequency at which the camera controller state is updated, which affects the responsiveness and smoothness of camera movements.
--
--- Determines whether the mouse can be used to rotate the camera.
-- If this constant is set to `true`, the mouse can be used to rotate the camera. If set to `false`, the mouse cannot be used to rotate the camera.
const.CameraControllerStateUpdateTime = "0.5"
const.mouse_rotates_camera = false

--- A table of vendor IDs for common hardware vendors.
-- This table maps vendor names to their corresponding vendor IDs, which can be used to identify the hardware vendor of a device.
--
-- @field Intel The vendor ID for Intel hardware.
-- @field AMD The vendor ID for AMD hardware.
-- @field NVidia The vendor ID for NVidia hardware.
const.VendorIds = {Intel=8086, AMD=1002, NVidia=4318}

--- The maximum possible value for a Z coordinate.
-- This constant represents the maximum possible value for a Z coordinate, which is the largest signed 32-bit integer value (2^31 - 1). It is typically used as a sentinel value to indicate an invalid or unset Z coordinate.
const.InvalidZ = 2147483647

--- A table of common color constants used throughout the application.
-- These constants define a set of commonly used colors, represented as RGB values, that can be used to consistently style and theme various UI elements and graphics.
--
-- @field clrBlack The color black, represented as RGB(0, 0, 0).
-- @field clrWhite The color white, represented as RGB(255, 255, 255).
-- @field clrRed The color red, represented as RGB(255, 0, 0).
-- @field clrGreen The color green, represented as RGB(0, 255, 0).
-- @field clrCyan The color cyan, represented as RGB(0, 255, 255).
-- @field clrBlue The color blue, represented as RGB(0, 0, 255).
-- @field clrPaleBlue A pale blue color, represented as RGB(127, 159, 255).
-- @field clrPink A pink color, represented as RGB(255, 127, 127).
-- @field clrYellow The color yellow, represented as RGB(255, 255, 0).
-- @field clrPaleYellow A pale yellow color, represented as RGB(255, 255, 127).
-- @field clrGray A gray color, represented as RGB(190, 190, 190).
-- @field clrStoneGray A stone gray color, represented as RGB(191, 191, 207).
-- @field clrSilverGray A silver gray color, represented as RGB(192, 192, 192).
-- @field clrDarkGray A dark gray color, represented as RGB(169, 169, 169).
-- @field clrNoModifier A color used for no modifier, represented as RGB(100, 100, 100).
-- @field clrOrange The color orange, represented as RGB(255, 165, 0).
-- @field clrMagenta The color magenta, represented as RGB(255, 0, 255).
const.clrBlack = RGB(0, 0, 0)
const.clrWhite = RGB(255, 255, 255)
const.clrRed = RGB(255, 0, 0)
const.clrGreen = RGB(0, 255, 0)
const.clrCyan = RGB(0, 255, 255)
const.clrBlue = RGB(0, 0, 255)
const.clrPaleBlue = RGB(127, 159, 255)
const.clrPink = RGB(255, 127, 127)
const.clrYellow = RGB(255, 255, 0)
const.clrPaleYellow = RGB(255, 255, 127)
const.clrGray = RGB(190, 190, 190)
const.clrStoneGray = RGB(191, 191, 207)
const.clrSilverGray = RGB(192, 192, 192)
const.clrDarkGray = RGB(169, 169, 169)
const.clrNoModifier = RGB(100, 100, 100)
const.clrOrange = RGB(255, 165, 0)
const.clrMagenta = RGB(255, 0, 255)

--- The time in milliseconds that a rollover UI element should be displayed.
-- @field RolloverTime The time in milliseconds that a rollover UI element should be displayed.
-- @field RolloverDestroyTime The time in milliseconds after which the rollover UI element should be destroyed.
const.RolloverTime = 150
const.RolloverDestroyTime = const.RolloverTime

--- The distance at which a rollover UI element should be refreshed.
-- @field RolloverRefreshDistance The distance at which a rollover UI element should be refreshed.
const.RolloverRefreshDistance = 75
const.RolloverWidth = 300
const.alignLeft = 1
const.alignRight = 2
const.alignTop = 3
const.alignBottom = 4

-- terrain type/biome brush
--- The vertical texture z-axis threshold value.
-- This value is used to determine the visibility of textures on vertical surfaces.
-- @field VerticalTextureZThreshold The vertical texture z-axis threshold value.
const.VerticalTextureZThreshold = "0.7"
const.BiomeSlopeAngleThreshold = 5 * 60

--- The interval in milliseconds for keyboard auto-repeat.
const.KbdAutoRepeatInterval = 400
const.RepeatButtonStart = 300
const.RepeatButtonInterval = 250

--Generic unit states; these represent logical behaviour states, and are only loosely connected to the animation states
--- Generic unit states. These represent logical behaviour states, and are only loosely connected to the animation states.
-- @field gsIdle The idle state.
-- @field gsWalk The walking state.
-- @field gsRun The running state.
-- @field gsAttack The attacking state.
-- @field gsDeflect The deflecting state.
-- @field gsDeflectIdle The deflecting idle state.
-- @field gsDie The dying state.
--	Currently applied only for heroes.
const.gsIdle = 1
const.gsWalk = 2
const.gsRun = 3
const.gsAttack = 4
const.gsDeflect = 5
const.gsDeflectIdle = 6
const.gsDie = 7

-- Console history max size
--- The maximum size of the console history.
-- This constant determines the maximum number of entries that can be stored in the console history.
const.nConsoleHistoryMaxSize = 20

--- The maximum number of destlocks around a target object.
-- This constant defines the maximum number of destlocks (destination locks) that can be placed around a target object.
const.MaxDestsAroundObject = 16
const.MaxDestsAroundObject = 16 -- the maximum destlocks around target object

--- The distance at which tracks should start fading out.
-- @field TracksFadeOutDist The distance at which tracks should start fading out.
const.TracksFadeOutDist = 3 * guim

-- Obstacle collision surface hit type
--- Obstacle collision surface hit types.
-- @field surfNoCollision No collision surface.
-- @field surfImpassableVolume Impassable volume surface.
-- @field surfImpassableTerrain Impassable terrain surface.
-- @field surfWalkableSurface Walkable surface.
-- @field surfPassableTerrain Passable terrain surface.
const.surfNoCollision = 0
const.surfImpassableVolume = 1
const.surfImpassableTerrain = 2
const.surfWalkableSurface = 3
const.surfPassableTerrain = 4

--- The maximum radius for walkable areas.
-- This constant defines the maximum radius for walkable areas in the game world.
const.WalkableMaxRadius = 30 * guim

--- The default delay between sequences.
-- This constant defines the default delay in seconds between sequences when playing animations.
const.SequenceDefaultLoopDelay = 1573

--- A table that maps color constants to their string representations.
-- This table provides a mapping between the color constants defined in the `const` table and their corresponding string names.
-- The keys in this table are the color constants, and the values are the string names for those colors.
-- This table is primarily used for displaying color information in the game's user interface or other textual representations.
const.CustomGameColors = {[const.clrBlack]="black", [const.clrWhite]="white", [const.clrRed]="red",
    [const.clrCyan]="cyan", [const.clrGreen]="green", [const.clrBlue]="blue", [const.clrPaleBlue]="pale blue",
    [const.clrPink]="pink", [const.clrYellow]="yellow", [const.clrOrange]="orange", [const.clrPaleYellow]="pale yellow",
    [const.clrStoneGray]="stone gray"}
--- A table that defines a list of color constants.
-- This table contains a list of color constants that are commonly used in the game or application.
-- The keys in this table are the color constants, and the values are the string names for those colors.
-- This table is primarily used for displaying color information in the game's user interface or other textual representations.
const.ColorList = {const.clrGreen, const.clrBlue, const.clrRed, const.clrWhite, const.clrCyan, const.clrYellow,
    const.clrPink, const.clrOrange, const.clrPaleBlue, const.clrPaleYellow, const.clrStoneGray, const.clrBlack}

if Platform.editor then
	const.ebtNull			 		= 20
	
	const.ErodeIterations = 3
	const.ErodeAmount = 50
	const.ErodePersist = 5
	const.ErodeThreshold = 50
	const.ErodeCoefDiag = 500
	const.ErodeCoefRect = 1000

	-- move gizmo constants
	const.RenderGizmoScreenDist	= "20.0"	-- use predefined metrics as if the gizmo is that many units from the camera

	const.AxisCylinderRadius = "0.10"
	const.AxisCylinderHeight = "4.0"
	const.AxisCylinderSlices = 10

	const.AxisConusRadius = "0.45"
	const.AxisConusHeight = "1.0"
	const.AxisConusSlices = 10

	const.PlaneLineRadius = "0.05"
	const.PlaneLineHeight = "2.5"
	const.PlaneLineSlices = 10

	const.XAxisColor = RGB(192, 0, 0)
	const.YAxisColor = RGB(0, 192, 0)
	const.ZAxisColor = RGB(0, 0, 192)
	const.XAxisColorSelected = RGB(255, 255, 0)
	const.YAxisColorSelected = RGB(255, 255, 0)
	const.ZAxisColorSelected = RGB(255, 255, 0)

	const.PlaneColor = RGBA(255, 255, 0, 200)

	-- scale gizmo constants
	const.MaxSingleScale = "3.0"		-- what is the max scale for a single operation

	const.PyramidSize = "1.5"
	const.PyramidSideRadius = "0.10"
	const.PyramidSideSlices = 10

	const.PyramidColor = RGB(0, 192, 192)
	const.SelectedSideColor = RGBA(255, 255, 0, 200)

	-- rotate gizmo constants
	const.MapDirections = 8

	const.AxisRadius = "0.05"
	const.AxisLength = "1.5"
	const.AxisSlices = 5

	const.TorusRadius1 = "2.30"
	const.TorusRadius2 = "0.15"
	const.TorusRings = 15
	const.TorusSlices = 10

	const.TangentRadius = "0.1"
	const.TangentLength = "2.5"
	const.TangentSlices = 5
	const.TangentColor = RGB(255, 0, 255)
	const.TangentConusHeight = "0.50"
	const.TangentConusRadius = "0.30"
	const.BigTorusColor = RGB(0, 192, 192)
	const.BigTorusColorSelected = RGB(255, 255, 0)
	const.SphereColor = RGBA(128, 128, 128, 100)

	const.SphereRings = 15
	const.SphereSlices = 15
	const.BigTorusRadius = "3.5"
	const.BigTorusRadius2 = "0.15"
	const.BigTorusRings = 15
	const.BigTorusSlices = 10

	-- snapping parameters
	const.SnapRadius = 20 -- in meters
	const.SnapBoxSize = "0.1"
	const.SnapDistXYTolerance = 10
	const.SnapDistZTolerance = 2
	const.SnapScaleTolerance = 200
	const.SnapAngleTolerance = 720
	-- let dDistXY, dDistZ, dAngle, dScale and dAxisAngle are the differences between params for two snap spots and
	-- differences above the specified tollerances ignores matching of the two snap spots
	-- let dNorm = SnapDistXYCoef + SnapDistZCoef + SnapAngleCoef + SnapScaleCoef
	-- fitness function for the two spots is 
	-- (dDist * SnapDistCoef + dAngle * SnapAngleCoef + dScale * SnapScaleCoef) / dNorm
	-- The snap spots with smallest fitness function are taken as matching snap spots
	const.SnapDistXYCoef = 1
	const.SnapDistZCoef = 3
	const.SnapAngleCoef = 3
	const.SnapScaleCoef = 2
	const.SnapDrawWarningFitnessTreshold = 4000 -- warning which only draws line segment between the closest snap spots

	const.MinBrushDensity = 30
	const.MaxBrushDensity = 97
end

-- Camera obstruct view params
--- Defines constants related to obstructing the camera view.
---
--- @field ObstructOpacity number The transparency of objects that obstruct the view.
--- @field ObstructOpacityFadeOutTime number The time in milliseconds to blend to transparent mode for objects obstructing the view.
--- @field ObstructOpacityFadeInTime number The time in milliseconds to blend to normal mode for objects obstructing the view.
--- @field ObstructViewRefreshTime number The time in milliseconds for refreshing the obstructing objects.
--- @field ObstructOpacityRefreshTime number The time in milliseconds for refreshing the translucency of the fading objects.
--- @field ObstructViewMaxObjectSize number The maximum size of objects that can obstruct the view.
const.ObstructOpacity = 0 -- transparency of objects that obstruct the view
const.ObstructOpacityFadeOutTime = 300 -- time to blend to transparent mode for objects obstructing the view
const.ObstructOpacityFadeInTime = 300 -- time to blend to normal mode for objects obstructing the view
const.ObstructViewRefreshTime = 50 -- time for refreshing the obstructing objects
const.ObstructOpacityRefreshTime = 20 -- time for refreshing the translucency of the fading objects
const.ObstructViewMaxObjectSize = 9000 -- enum distance

-- easing types

--- Returns a combo table with the default value and text, followed by all the easing names.
---
--- @param def_value boolean The default value for the combo.
--- @param def_text string The default text for the combo.
--- @return table The combo table with the default value and text, followed by all the easing names.
function GetEasingCombo(def_value, def_text)
    def_value = def_value or false
    def_text = def_text or ""
    local combo = {{value=def_value, text=def_text}}
    for i, name in ipairs(GetEasingNames()) do
        combo[#combo + 1] = {value=i - 1, text=name}
    end
    return combo
end

-- the string values below are used in C, the reference below prevent the values to be constantly created and then garbage collected
--- A table of string references used throughout the codebase.
---
--- This table contains references to various strings used in the interpolation, collections, luaLib, luaQuery, and luaXInput systems.
---
--- @field type string A reference to the "type" string.
--- @field easing string A reference to the "easing" string.
--- @field flags string A reference to the "flags" string.
--- @field start string A reference to the "start" string.
--- @field duration string A reference to the "duration" string.
--- @field originalRect string A reference to the "originalRect" string.
--- @field targetRect string A reference to the "targetRect" string.
--- @field startValue string A reference to the "startValue" string.
--- @field endValue string A reference to the "endValue" string.
--- @field center string A reference to the "center" string.
--- @field startAngle string A reference to the "startAngle" string.
--- @field endAngle string A reference to the "endAngle" string.
--- @field child string A reference to the "child" string.
--- @field sub string A reference to the "sub" string.
--- @field n string A reference to the "n" string.
--- @field hex string A reference to the "hex" string.
--- @field rand string A reference to the "rand" string.
--- @field detached string A reference to the "detached" string.
--- @field map string A reference to the "map" string.
--- @field attached string A reference to the "attached" string.
--- @field object_circles string A reference to the "object_circles" string.
--- @field CObject string A reference to the "CObject" string.
--- @field collected string A reference to the "collected" string.
--- @field collection string A reference to the "collection" string.
--- @field shuffle string A reference to the "shuffle" string.
--- @field DPadLeft string A reference to the "DPadLeft" string.
--- @field DPadRight string A reference to the "DPadRight" string.
--- @field DPadUp string A reference to the "DPadUp" string.
--- @field DPadDown string A reference to the "DPadDown" string.
--- @field ButtonA string A reference to the "ButtonA" string.
--- @field ButtonB string A reference to the "ButtonB" string.
--- @field ButtonX string A reference to the "ButtonX" string.
--- @field ButtonY string A reference to the "ButtonY" string.
--- @field LeftThumbClick string A reference to the "LeftThumbClick" string.
--- @field RightThumbClick string A reference to the "RightThumbClick" string.
--- @field Start string A reference to the "Start" string.
--- @field Back string A reference to the "Back" string.
--- @field LeftShoulder string A reference to the "LeftShoulder" string.
--- @field RightShoulder string A reference to the "RightShoulder" string.
--- @field LeftTrigger string A reference to the "LeftTrigger" string.
--- @field RightTrigger string A reference to the "RightTrigger" string.
--- @field LeftThumb string A reference to the "LeftThumb" string.
--- @field RightThumb string A reference to the "RightThumb" string.
--- @field TouchPadClick string A reference to the "TouchPadClick" string.
const.__string_reference = { -- Interpolation
"type", "easing", "flags", "start", "duration", "originalRect", "targetRect", "startValue", "endValue", "center",
    "startAngle", "endAngle", -- Collections
    "child", "sub", -- luaLib
    "n", -- luaQuery
    "hex", "rand", "detached", "map", "attached", "object_circles", "CObject", "collected", "collection", "shuffle",
    -- luaXInput
    "DPadLeft", "DPadRight", "DPadUp", "DPadDown", "ButtonA", "ButtonB", "ButtonX", "ButtonY", "LeftThumbClick",
    "RightThumbClick", "Start", "Back", "LeftShoulder", "RightShoulder", "LeftTrigger", "RightTrigger", "LeftThumb",
    "RightThumb", "TouchPadClick"}

--- @class const
--- @field VoiceChatForcedSampleRate integer The forced sample rate for voice chat audio.
--- @field VoiceChatSoundType string The sound type for voice chat audio.
--- @field VoiceChatMaxSilence integer The maximum allowed silence duration for voice chat audio.
--- @field VoiceChatFadeTime integer The fade time for voice chat audio.
const.VoiceChatForcedSampleRate = 11025
const.VoiceChatSoundType = "VoiceChat"
const.VoiceChatMaxSilence = 10000
const.VoiceChatFadeTime = 300

-------- UI Scale constants
--- @field MinUserUIScale integer The minimum allowed user UI scale.
--- @field MaxUserUIScaleLowRes integer The maximum allowed user UI scale for low resolution displays.
--- @field MaxUserUIScaleHighRes integer The maximum allowed user UI scale for high resolution displays.
--- @field ControllerUIScale integer The additional scale applied when using a gamepad or controller.
const.MinUserUIScale = 65
const.MaxUserUIScaleLowRes = 110
const.MaxUserUIScaleHighRes = 135
const.ControllerUIScale = const.ControllerUIScale or 111 -- additional scale applied when using gamepad/controller

-------- Display Area Margin constants
--- @field MinDisplayAreaMargin integer The minimum allowed display area margin.
--- @field MaxDisplayAreaMargin integer The maximum allowed display area margin.
const.MinDisplayAreaMargin = 0
const.MaxDisplayAreaMargin = 10

--- @field UIScaleDAMDependant boolean
--- Indicates whether the UI scale is dependent on the display area margin.
const.UIScaleDAMDependant = false

--[[
-- The following code measures the resolving of constants between two sequential calls to dump_const_use().
-- Sample use - CreateGameTimeThread(function () dump_const_use() Sleep(10000) dump_const_use() end)

local org_const = const
const = {}
const_access_count = 0
const_access = {}
setmetatable(const, {
	__index = function (t, k)
		const_access_count = const_access_count + 1
		const_access[k] = (const_access[k] or 0) + 1
		return org_const[k]
	end,
	__newindex = function (t, k, v)
		org_const[k] = v
	end,
})
function dump_const_use()
	print("")
	print("total const access count " .. const_access_count)
	local t = {}
	for k,v in pairs(const_access) do
		table.insert(t, {key = k, value = v})
	end
	table.sort(t, function (a, b) return a.value > b.value end)
	for i = 1, #t do
		print(t[i].key .. " " .. t[i].value)
	end
	const_access = {}
	const_access_count = 0
end
--]]

-- Destroyable
--- @class const
--- Defines various constants used throughout the codebase.

--- The volume of a small entity, calculated as the cube of the game unit measurement `guim`.
const.EntityVolumeSmall = guim * guim * guim
const.EntityVolumeMedium = 3 * const.EntityVolumeSmall

-- Wind
--- The maximum strength of the wind in the game world.
const.WindMaxStrength = 4096
const.WindMarkerMaxRange = 50 * guim
const.WindMarkerAttenuationRange = 80 * guim
const.StrongWindThreshold = 100 -- percent of max wind
--- Defines a set of combo items for wind modifier masks.
---
--- The `WindModifierMaskComboItems` table contains a list of combo items that can be used to select a wind modifier mask. Each combo item has a `text` field that represents the display text for the item, and a `value` field that represents the corresponding numeric value for the mask.
---
--- The first item in the table represents "None", with a value of 0, indicating that no wind modifier mask is applied.
--- The second item in the table represents "All", with a value of -1, indicating that all wind modifier masks are applied.
---
--- This table is likely used in a user interface or configuration setting to allow the player to select the desired wind modifier mask.
const.WindModifierMaskComboItems = {{text="None", value=0}, {text="All", value=-1}}

-- Water
--- The minimum offset in the Z-axis for water effects.
const.FXWaterMinOffsetZ = -guim / 10
const.FXWaterMaxOffsetZ = guim / 10
const.FXDecalMinOffsetZ = -guim / 10
const.FXDecalMaxOffsetZ = guim / 10
const.FXShallowWaterOffsetZ = 0

--------------------------------------------------------------------------------------------------------------------
